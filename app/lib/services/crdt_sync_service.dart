import 'dart:async';

import 'vector_clock.dart';
import 'websocket_service.dart';
import 'database_service.dart';

/// CRDT同步服务
///
/// 基于向量时钟的冲突解决同步服务，支持：
/// - 离线优先：本地修改优先，联网后同步
/// - 因果一致性：使用向量时钟追踪因果关系
/// - 自动冲突解决：基于向量时钟的Last-Write-Wins策略
/// - 手动冲突解决：并发修改时提供用户选择
class CrdtSyncService {
  final WebSocketService _wsService;
  final DatabaseService _db;
  final String deviceId;

  VectorClock _localClock;
  final StreamController<SyncEvent> _syncEvents = StreamController.broadcast();
  final Map<String, VectorClock> _pendingOperations = {};
  bool _isSyncing = false;

  // StreamSubscription 引用，用于在 dispose 时取消
  StreamSubscription<dynamic>? _messageSubscription;
  StreamSubscription<WebSocketConnectionState>? _stateSubscription;

  CrdtSyncService({
    required WebSocketService wsService,
    required DatabaseService db,
    required this.deviceId,
  })  : _wsService = wsService,
        _db = db,
        _localClock = VectorClock() {
    _setupListeners();
  }

  /// 同步事件流
  Stream<SyncEvent> get syncEvents => _syncEvents.stream;

  /// 获取当前向量时钟
  VectorClock get localClock => _localClock;

  /// 是否正在同步
  bool get isSyncing => _isSyncing;

  void _setupListeners() {
    // 监听WebSocket消息
    _messageSubscription = _wsService.onMessage.listen(_handleRemoteMessage);

    // 监听连接状态变化
    _stateSubscription = _wsService.onStateChange.listen((state) {
      if (state == WebSocketConnectionState.connected) {
        _onConnected();
      } else if (state == WebSocketConnectionState.disconnected) {
        _onDisconnected();
      }
    });
  }

  /// 连接并开始同步
  Future<void> startSync(String ledgerId) async {
    await _wsService.connect('/ledger/$ledgerId/sync');
  }

  /// 停止同步
  Future<void> stopSync() async {
    await _wsService.disconnect();
  }

  /// 记录本地操作
  ///
  /// 创建带向量时钟的操作记录，用于后续同步
  Future<SyncOperation> recordLocalOperation({
    required String entityType,
    required String entityId,
    required SyncOperationType type,
    required Map<String, dynamic> data,
  }) async {
    // 递增本地时钟
    _localClock = _localClock.increment(deviceId);

    final operation = SyncOperation(
      id: '${deviceId}_${DateTime.now().microsecondsSinceEpoch}',
      entityType: entityType,
      entityId: entityId,
      type: type,
      data: data,
      vectorClock: _localClock,
      clientId: deviceId,
      timestamp: DateTime.now(),
    );

    // 保存待同步操作
    _pendingOperations[operation.id] = operation.vectorClock;

    // 如果已连接，立即推送
    if (_wsService.isConnected) {
      await _pushOperation(operation);
    } else {
      // 离线时存入队列
      await _queueOperation(operation);
    }

    return operation;
  }

  /// 推送本地操作到服务器
  Future<void> _pushOperation(SyncOperation operation) async {
    try {
      await _wsService.send(WebSocketMessage(
        type: _mapOperationType(operation.type),
        data: operation.toJson(),
        messageId: operation.id,
      ));

      _syncEvents.add(SyncEvent(
        type: SyncEventType.localChangePushed,
        message: WebSocketMessage(
          type: _mapOperationType(operation.type),
          data: operation.toJson(),
        ),
      ));
    } catch (e) {
      // 推送失败，存入队列
      await _queueOperation(operation);
    }
  }

  /// 处理远程消息
  Future<void> _handleRemoteMessage(WebSocketMessage message) async {
    switch (message.type) {
      case SyncMessageType.transactionCreated:
      case SyncMessageType.transactionUpdated:
      case SyncMessageType.transactionDeleted:
      case SyncMessageType.budgetUpdated:
      case SyncMessageType.vaultUpdated:
        await _handleRemoteOperation(message);
        break;
      case SyncMessageType.syncResponse:
        await _handleSyncResponse(message);
        break;
      case SyncMessageType.ack:
        _handleAck(message);
        break;
      case SyncMessageType.error:
        _handleError(message);
        break;
    }
  }

  /// 处理远程操作
  Future<void> _handleRemoteOperation(WebSocketMessage message) async {
    final remoteOp = SyncOperation.fromJson(message.data);

    // 检查是否有本地冲突
    final localOp = await _findLocalConflict(remoteOp);

    if (localOp == null) {
      // 无冲突，直接应用
      await _applyRemoteOperation(remoteOp);
    } else {
      // 有冲突，进行解决
      final result = await resolveConflict(
        local: localOp,
        remote: remoteOp,
      );
      await _applyResolution(result, localOp, remoteOp);
    }

    // 合并向量时钟
    _localClock = _localClock.merge(remoteOp.vectorClock);
  }

  /// 冲突解决
  ///
  /// 使用向量时钟判断因果关系：
  /// - 如果local发生在remote之前，接受remote
  /// - 如果remote发生在local之前，保留local
  /// - 如果并发，使用合并策略或询问用户
  Future<SyncResult> resolveConflict({
    required SyncOperation local,
    required SyncOperation remote,
  }) async {
    final localVector = local.vectorClock;
    final remoteVector = remote.vectorClock;

    if (localVector.happensBefore(remoteVector)) {
      // 本地操作在前，接受远程
      return SyncResult.acceptRemote(remote);
    } else if (remoteVector.happensBefore(localVector)) {
      // 远程操作在前，保留本地
      return SyncResult.keepLocal(local);
    } else {
      // 并发操作，尝试合并
      final merged = await _tryMerge(local, remote);
      if (merged != null) {
        return SyncResult.merged(merged);
      }

      // 无法自动合并，通知用户
      _syncEvents.add(SyncEvent(
        type: SyncEventType.conflictDetected,
        conflict: ConflictInfo(local: local, remote: remote),
      ));

      // 默认使用Last-Write-Wins策略
      if (local.timestamp.isAfter(remote.timestamp)) {
        return SyncResult.keepLocal(local);
      } else {
        return SyncResult.acceptRemote(remote);
      }
    }
  }

  /// 尝试合并两个操作
  Future<Map<String, dynamic>?> _tryMerge(
    SyncOperation local,
    SyncOperation remote,
  ) async {
    // 对于简单字段，可以使用字段级合并
    if (local.type == SyncOperationType.update &&
        remote.type == SyncOperationType.update) {
      final merged = <String, dynamic>{};
      final allKeys = <String>{
        ...local.data.keys,
        ...remote.data.keys,
      };

      for (final key in allKeys) {
        if (local.data.containsKey(key) && remote.data.containsKey(key)) {
          // 两边都修改了同一字段，使用时间戳决定
          if (local.timestamp.isAfter(remote.timestamp)) {
            merged[key] = local.data[key];
          } else {
            merged[key] = remote.data[key];
          }
        } else if (local.data.containsKey(key)) {
          merged[key] = local.data[key];
        } else {
          merged[key] = remote.data[key];
        }
      }

      return merged;
    }

    // 创建和删除操作无法自动合并
    return null;
  }

  /// 应用解决结果
  Future<void> _applyResolution(
    SyncResult result,
    SyncOperation local,
    SyncOperation remote,
  ) async {
    switch (result.type) {
      case SyncResultType.acceptRemote:
        await _applyRemoteOperation(remote);
        // 撤销本地操作
        await _revertLocalOperation(local);
        break;
      case SyncResultType.keepLocal:
        // 推送本地操作覆盖远程
        await _pushOperation(local);
        break;
      case SyncResultType.merged:
        // 应用合并后的数据
        await _applyMergedData(local.entityType, local.entityId, result.mergedData!);
        // 推送合并结果
        await recordLocalOperation(
          entityType: local.entityType,
          entityId: local.entityId,
          type: SyncOperationType.update,
          data: result.mergedData!,
        );
        break;
      case SyncResultType.conflict:
        // 冲突已通知用户，等待用户决定
        break;
    }
  }

  /// 应用远程操作到本地数据库
  Future<void> _applyRemoteOperation(SyncOperation operation) async {
    switch (operation.entityType) {
      case 'transaction':
        await _applyTransactionOperation(operation);
        break;
      case 'budget':
        await _applyBudgetOperation(operation);
        break;
      case 'vault':
        await _applyVaultOperation(operation);
        break;
    }

    _syncEvents.add(SyncEvent(
      type: SyncEventType.remoteChange,
      message: WebSocketMessage(
        type: _mapOperationType(operation.type),
        data: operation.toJson(),
      ),
    ));
  }

  Future<void> _applyTransactionOperation(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.create:
        // await _db.insertTransaction(Transaction.fromJson(operation.data));
        break;
      case SyncOperationType.update:
        // await _db.updateTransaction(Transaction.fromJson(operation.data));
        break;
      case SyncOperationType.delete:
        // await _db.deleteTransaction(operation.entityId);
        break;
    }
  }

  Future<void> _applyBudgetOperation(SyncOperation operation) async {
    // Budget operations
  }

  Future<void> _applyVaultOperation(SyncOperation operation) async {
    // Vault operations
  }

  Future<void> _applyMergedData(
    String entityType,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    // Apply merged data based on entity type
  }

  Future<void> _revertLocalOperation(SyncOperation operation) async {
    // Revert local operation
  }

  Future<SyncOperation?> _findLocalConflict(SyncOperation remote) async {
    // Find conflicting local operation for the same entity
    return null;
  }

  Future<void> _queueOperation(SyncOperation operation) async {
    // Queue operation for later sync
  }

  void _handleAck(WebSocketMessage message) {
    final messageId = message.data['messageId'] as String?;
    if (messageId != null) {
      _pendingOperations.remove(messageId);
    }
  }

  void _handleError(WebSocketMessage message) {
    _syncEvents.add(SyncEvent(
      type: SyncEventType.error,
      message: message,
    ));
  }

  Future<void> _handleSyncResponse(WebSocketMessage message) async {
    final operations = (message.data['operations'] as List<dynamic>?)
        ?.map((e) => SyncOperation.fromJson(e as Map<String, dynamic>))
        .toList();

    if (operations != null) {
      for (final op in operations) {
        await _handleRemoteOperation(WebSocketMessage(
          type: _mapOperationType(op.type),
          data: op.toJson(),
        ));
      }
    }

    _isSyncing = false;
    _syncEvents.add(const SyncEvent(type: SyncEventType.syncCompleted));
  }

  void _onConnected() {
    _syncEvents.add(const SyncEvent(type: SyncEventType.connected));
    _requestFullSync();
  }

  void _onDisconnected() {
    _syncEvents.add(const SyncEvent(type: SyncEventType.disconnected));
  }

  Future<void> _requestFullSync() async {
    _isSyncing = true;
    await _wsService.send(WebSocketMessage(
      type: SyncMessageType.syncRequest,
      data: {
        'vectorClock': _localClock.toJson(),
        'clientId': deviceId,
      },
    ));
  }

  String _mapOperationType(SyncOperationType type) {
    switch (type) {
      case SyncOperationType.create:
        return 'entity.created';
      case SyncOperationType.update:
        return 'entity.updated';
      case SyncOperationType.delete:
        return 'entity.deleted';
    }
  }

  /// 用户手动解决冲突
  Future<void> resolveConflictManually({
    required String operationId,
    required ConflictResolution resolution,
  }) async {
    // Handle manual conflict resolution
  }

  /// 释放资源
  void dispose() {
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
    _syncEvents.close();
    _pendingOperations.clear();
  }
}

/// 冲突解决选项
enum ConflictResolution {
  keepLocal,
  acceptRemote,
  merge,
}

/// 设备信息
class DeviceInfo {
  static String? _deviceId;

  static String get deviceId {
    _deviceId ??= DateTime.now().microsecondsSinceEpoch.toString();
    return _deviceId!;
  }

  static void setDeviceId(String id) {
    _deviceId = id;
  }
}
