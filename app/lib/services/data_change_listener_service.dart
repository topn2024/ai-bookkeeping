import 'dart:async';
import 'package:flutter/foundation.dart';

/// 数据变更类型
enum DataChangeType {
  /// 新增
  insert,

  /// 更新
  update,

  /// 删除
  delete,

  /// 批量变更
  batch,

  /// 重置
  reset,
}

/// 数据实体类型
enum DataEntityType {
  /// 交易
  transaction,

  /// 分类
  category,

  /// 账户
  account,

  /// 预算
  budget,

  /// 小金库
  vault,

  /// 资源池
  resourcePool,

  /// 习惯
  habit,

  /// 标签
  tag,

  /// 家庭成员
  familyMember,

  /// 账本
  ledger,
}

/// 数据变更事件
class DataChangeEvent {
  /// 变更类型
  final DataChangeType changeType;

  /// 实体类型
  final DataEntityType entityType;

  /// 变更的实体ID列表
  final List<String> entityIds;

  /// 变更前的数据（用于撤销）
  final Map<String, dynamic>? previousData;

  /// 变更后的数据
  final Map<String, dynamic>? currentData;

  /// 变更时间戳
  final DateTime timestamp;

  /// 变更来源
  final String? source;

  /// 是否需要刷新UI
  final bool requiresRefresh;

  /// 影响的维度（用于增量刷新）
  final Set<String> affectedDimensions;

  DataChangeEvent({
    required this.changeType,
    required this.entityType,
    required this.entityIds,
    this.previousData,
    this.currentData,
    DateTime? timestamp,
    this.source,
    this.requiresRefresh = true,
    Set<String>? affectedDimensions,
  })  : timestamp = timestamp ?? DateTime.now(),
        affectedDimensions = affectedDimensions ?? _calculateAffectedDimensions(entityType);

  /// 计算影响的维度
  static Set<String> _calculateAffectedDimensions(DataEntityType entityType) {
    switch (entityType) {
      case DataEntityType.transaction:
        return {'time', 'category', 'account', 'amount', 'moneyAge', 'budget', 'location'};
      case DataEntityType.category:
        return {'category'};
      case DataEntityType.account:
        return {'account', 'amount'};
      case DataEntityType.budget:
        return {'budget', 'category'};
      case DataEntityType.vault:
        return {'vault', 'budget'};
      case DataEntityType.resourcePool:
        return {'moneyAge', 'amount'};
      case DataEntityType.habit:
        return {'habit'};
      case DataEntityType.tag:
        return {'tag'};
      case DataEntityType.familyMember:
        return {'family', 'member'};
      case DataEntityType.ledger:
        return {'ledger'};
    }
  }

  /// 是否影响指定维度
  bool affectsDimension(String dimension) {
    return affectedDimensions.contains(dimension);
  }

  @override
  String toString() =>
      'DataChangeEvent($changeType, $entityType, ids=${entityIds.length})';
}

/// 数据变更监听器
typedef DataChangeCallback = void Function(DataChangeEvent event);

/// 数据变更过滤器
typedef DataChangeFilter = bool Function(DataChangeEvent event);

/// 监听器注册信息
class _ListenerRegistration {
  final String id;
  final DataChangeCallback callback;
  final DataChangeFilter? filter;
  final Set<DataEntityType>? entityTypes;
  final Set<DataChangeType>? changeTypes;
  final Set<String>? dimensions;

  _ListenerRegistration({
    required this.id,
    required this.callback,
    this.filter,
    this.entityTypes,
    this.changeTypes,
    this.dimensions,
  });

  bool shouldNotify(DataChangeEvent event) {
    // 检查实体类型过滤
    if (entityTypes != null && !entityTypes!.contains(event.entityType)) {
      return false;
    }

    // 检查变更类型过滤
    if (changeTypes != null && !changeTypes!.contains(event.changeType)) {
      return false;
    }

    // 检查维度过滤
    if (dimensions != null && !dimensions!.any((d) => event.affectsDimension(d))) {
      return false;
    }

    // 检查自定义过滤器
    if (filter != null && !filter!(event)) {
      return false;
    }

    return true;
  }
}

/// 数据变更实时监听服务
///
/// 核心功能：
/// 1. 统一的数据变更事件分发
/// 2. 支持多维度订阅过滤
/// 3. 批量变更合并
/// 4. 防抖与节流
/// 5. 变更日志记录
///
/// 对应设计文档：第12.6.1节 数据变更监听
///
/// 使用示例：
/// ```dart
/// final service = DataChangeListenerService();
///
/// // 监听交易变更
/// service.addListener(
///   id: 'chart_refresh',
///   callback: (event) => refreshChart(),
///   entityTypes: {DataEntityType.transaction},
/// );
///
/// // 发送变更事件
/// service.notifyChange(DataChangeEvent(
///   changeType: DataChangeType.insert,
///   entityType: DataEntityType.transaction,
///   entityIds: ['tx_123'],
/// ));
/// ```
class DataChangeListenerService {
  /// 监听器列表
  final Map<String, _ListenerRegistration> _listeners = {};

  /// 事件流控制器
  final StreamController<DataChangeEvent> _eventController =
      StreamController<DataChangeEvent>.broadcast();

  /// 待处理事件队列（用于批量合并）
  final List<DataChangeEvent> _pendingEvents = [];

  /// 批量处理定时器
  Timer? _batchTimer;

  /// 批量处理延迟
  final Duration batchDelay;

  /// 是否启用批量处理
  final bool enableBatching;

  /// 变更日志（最近N条）
  final List<DataChangeEvent> _changeLog = [];

  /// 最大日志条数
  static const int maxLogSize = 100;

  /// ID计数器
  int _idCounter = 0;

  DataChangeListenerService({
    this.batchDelay = const Duration(milliseconds: 100),
    this.enableBatching = true,
  });

  /// 事件流
  Stream<DataChangeEvent> get eventStream => _eventController.stream;

  /// 获取变更日志
  List<DataChangeEvent> get changeLog => List.unmodifiable(_changeLog);

  /// 添加监听器
  String addListener({
    String? id,
    required DataChangeCallback callback,
    DataChangeFilter? filter,
    Set<DataEntityType>? entityTypes,
    Set<DataChangeType>? changeTypes,
    Set<String>? dimensions,
  }) {
    final listenerId = id ?? 'listener_${++_idCounter}';

    _listeners[listenerId] = _ListenerRegistration(
      id: listenerId,
      callback: callback,
      filter: filter,
      entityTypes: entityTypes,
      changeTypes: changeTypes,
      dimensions: dimensions,
    );

    return listenerId;
  }

  /// 移除监听器
  void removeListener(String id) {
    _listeners.remove(id);
  }

  /// 发送变更通知
  void notifyChange(DataChangeEvent event) {
    // 记录日志
    _addToLog(event);

    if (enableBatching) {
      // 添加到待处理队列
      _pendingEvents.add(event);

      // 重置批量处理定时器
      _batchTimer?.cancel();
      _batchTimer = Timer(batchDelay, _processBatch);
    } else {
      // 立即处理
      _dispatchEvent(event);
    }
  }

  /// 批量发送变更通知
  void notifyBatchChange(List<DataChangeEvent> events) {
    if (events.isEmpty) return;

    // 合并为批量事件
    final batchEvent = DataChangeEvent(
      changeType: DataChangeType.batch,
      entityType: events.first.entityType,
      entityIds: events.expand((e) => e.entityIds).toList(),
      affectedDimensions: events.expand((e) => e.affectedDimensions).toSet(),
    );

    _addToLog(batchEvent);
    _dispatchEvent(batchEvent);
  }

  /// 处理批量事件
  void _processBatch() {
    if (_pendingEvents.isEmpty) return;

    // 按实体类型分组
    final groupedEvents = <DataEntityType, List<DataChangeEvent>>{};
    for (final event in _pendingEvents) {
      groupedEvents.putIfAbsent(event.entityType, () => []).add(event);
    }

    // 合并并分发
    for (final entry in groupedEvents.entries) {
      if (entry.value.length == 1) {
        _dispatchEvent(entry.value.first);
      } else {
        final batchEvent = DataChangeEvent(
          changeType: DataChangeType.batch,
          entityType: entry.key,
          entityIds: entry.value.expand((e) => e.entityIds).toList(),
          affectedDimensions: entry.value.expand((e) => e.affectedDimensions).toSet(),
        );
        _dispatchEvent(batchEvent);
      }
    }

    _pendingEvents.clear();
  }

  /// 分发事件
  void _dispatchEvent(DataChangeEvent event) {
    // 发送到事件流
    _eventController.add(event);

    // 通知监听器
    for (final listener in _listeners.values) {
      if (listener.shouldNotify(event)) {
        try {
          listener.callback(event);
        } catch (e) {
          debugPrint('DataChangeListener error: $e');
        }
      }
    }
  }

  /// 添加到日志
  void _addToLog(DataChangeEvent event) {
    _changeLog.add(event);
    if (_changeLog.length > maxLogSize) {
      _changeLog.removeAt(0);
    }
  }

  /// 获取指定实体类型的最近变更
  List<DataChangeEvent> getRecentChanges({
    DataEntityType? entityType,
    int limit = 10,
  }) {
    var logs = _changeLog.reversed;
    if (entityType != null) {
      logs = logs.where((e) => e.entityType == entityType);
    }
    return logs.take(limit).toList();
  }

  /// 清除日志
  void clearLog() {
    _changeLog.clear();
  }

  /// 暂停批量处理
  void pauseBatching() {
    _batchTimer?.cancel();
    _processBatch(); // 处理已有的待处理事件
  }

  /// 释放资源
  void dispose() {
    _batchTimer?.cancel();
    _eventController.close();
    _listeners.clear();
    _pendingEvents.clear();
    _changeLog.clear();
  }
}

/// 数据变更监听Mixin
/// 方便在Widget中使用
mixin DataChangeListenerMixin {
  DataChangeListenerService? _dataChangeService;
  String? _listenerId;

  /// 初始化监听
  void initDataChangeListener({
    required DataChangeListenerService service,
    required DataChangeCallback onDataChange,
    Set<DataEntityType>? entityTypes,
    Set<DataChangeType>? changeTypes,
    Set<String>? dimensions,
  }) {
    _dataChangeService = service;
    _listenerId = service.addListener(
      callback: onDataChange,
      entityTypes: entityTypes,
      changeTypes: changeTypes,
      dimensions: dimensions,
    );
  }

  /// 移除监听
  void disposeDataChangeListener() {
    if (_listenerId != null && _dataChangeService != null) {
      _dataChangeService!.removeListener(_listenerId!);
    }
  }
}
