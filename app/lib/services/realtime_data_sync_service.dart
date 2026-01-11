import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

/// 数据变更类型
enum DataChangeType {
  /// 交易数据变更
  transaction,

  /// 分类数据变更
  category,

  /// 账户数据变更
  account,

  /// 预算数据变更
  budget,

  /// 家庭数据变更
  family,

  /// 钱龄数据变更
  moneyAge,

  /// 习惯数据变更
  habit,

  /// 位置数据变更
  location,

  /// 配置变更
  settings,
}

/// 数据变更操作
enum DataChangeOperation {
  /// 插入
  insert,

  /// 更新
  update,

  /// 删除
  delete,

  /// 批量操作
  batch,
}

/// 数据变更事件
class DataChangeEvent {
  /// 变更类型
  final DataChangeType type;

  /// 操作类型
  final DataChangeOperation operation;

  /// 受影响的ID列表
  final List<String> affectedIds;

  /// 变更时间
  final DateTime timestamp;

  /// 附加数据
  final Map<String, dynamic>? metadata;

  DataChangeEvent({
    required this.type,
    required this.operation,
    required this.affectedIds,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'DataChangeEvent($type, $operation, ids=${affectedIds.length})';
}

/// 数据订阅配置
class DataSubscriptionConfig {
  /// 订阅的数据类型
  final Set<DataChangeType> types;

  /// 是否启用节流（避免频繁更新）
  final bool enableThrottle;

  /// 节流时间（毫秒）
  final int throttleMs;

  /// 是否启用批处理
  final bool enableBatching;

  /// 批处理窗口期（毫秒）
  final int batchWindowMs;

  /// 最大批处理数量
  final int maxBatchSize;

  const DataSubscriptionConfig({
    this.types = const {},
    this.enableThrottle = true,
    this.throttleMs = 500,
    this.enableBatching = true,
    this.batchWindowMs = 300,
    this.maxBatchSize = 50,
  });
}

/// 实时数据同步服务
///
/// 核心功能：
/// 1. 监听数据库变更
/// 2. 发送数据变更事件
/// 3. 支持增量刷新
/// 4. 节流和批处理优化
///
/// 对应设计文档：第12.6节 实时数据联动
///
/// 使用示例：
/// ```dart
/// final syncService = RealtimeDataSyncService();
///
/// // 订阅交易数据变更
/// syncService.subscribe(
///   types: {DataChangeType.transaction},
///   onDataChanged: (event) {
///     print('交易数据变更: ${event.affectedIds}');
///     // 刷新UI
///   },
/// );
///
/// // 发送变更通知
/// syncService.notifyChange(DataChangeEvent(
///   type: DataChangeType.transaction,
///   operation: DataChangeOperation.insert,
///   affectedIds: ['tx123'],
/// ));
/// ```
class RealtimeDataSyncService extends ChangeNotifier {
  /// 数据库服务
  final IDatabaseService _db;

  /// 变更事件流控制器
  final StreamController<DataChangeEvent> _changeController =
      StreamController<DataChangeEvent>.broadcast();

  /// 订阅者映射（订阅ID -> 配置）
  final Map<String, DataSubscriptionConfig> _subscriptions = {};

  /// 订阅者回调映射
  final Map<String, void Function(DataChangeEvent)> _callbacks = {};

  /// 节流定时器映射
  final Map<String, Timer> _throttleTimers = {};

  /// 批处理缓冲区
  final Map<String, List<DataChangeEvent>> _batchBuffers = {};

  /// 批处理定时器
  final Map<String, Timer> _batchTimers = {};

  /// 最后处理时间映射（用于节流）
  final Map<String, DateTime> _lastProcessedTime = {};

  /// 变更序列号（用于跟踪变更顺序）
  int _changeSequence = 0;

  RealtimeDataSyncService({
    IDatabaseService? databaseService,
  }) : _db = databaseService ?? sl<IDatabaseService>();

  /// 获取变更事件流
  Stream<DataChangeEvent> get changeStream => _changeController.stream;

  /// 订阅数据变更
  String subscribe({
    required Set<DataChangeType> types,
    required void Function(DataChangeEvent) onDataChanged,
    DataSubscriptionConfig? config,
  }) {
    final subscriptionId = DateTime.now().millisecondsSinceEpoch.toString();

    _subscriptions[subscriptionId] = config ?? const DataSubscriptionConfig(types: {});
    _callbacks[subscriptionId] = onDataChanged;

    // 监听变更流
    _changeController.stream.listen((event) {
      _handleChangeForSubscription(subscriptionId, event);
    });

    return subscriptionId;
  }

  /// 取消订阅
  void unsubscribe(String subscriptionId) {
    _subscriptions.remove(subscriptionId);
    _callbacks.remove(subscriptionId);
    _throttleTimers[subscriptionId]?.cancel();
    _throttleTimers.remove(subscriptionId);
    _batchTimers[subscriptionId]?.cancel();
    _batchTimers.remove(subscriptionId);
    _batchBuffers.remove(subscriptionId);
    _lastProcessedTime.remove(subscriptionId);
  }

  /// 发送数据变更通知
  void notifyChange(DataChangeEvent event) {
    _changeSequence++;
    _changeController.add(event);
    notifyListeners();
  }

  /// 批量发送变更通知
  void notifyBatchChanges(List<DataChangeEvent> events) {
    for (final event in events) {
      _changeSequence++;
      _changeController.add(event);
    }
    notifyListeners();
  }

  /// 处理订阅的变更事件
  void _handleChangeForSubscription(String subscriptionId, DataChangeEvent event) {
    final config = _subscriptions[subscriptionId];
    if (config == null) return;

    // 检查订阅类型
    if (config.types.isNotEmpty && !config.types.contains(event.type)) {
      return;
    }

    // 启用批处理
    if (config.enableBatching) {
      _addToBatch(subscriptionId, event);
      return;
    }

    // 启用节流
    if (config.enableThrottle) {
      _throttleEvent(subscriptionId, event, config.throttleMs);
      return;
    }

    // 直接调用回调
    _executeCallback(subscriptionId, event);
  }

  /// 添加到批处理缓冲区
  void _addToBatch(String subscriptionId, DataChangeEvent event) {
    final config = _subscriptions[subscriptionId]!;

    // 初始化缓冲区
    _batchBuffers.putIfAbsent(subscriptionId, () => []);
    _batchBuffers[subscriptionId]!.add(event);

    // 检查是否达到最大批处理数量
    if (_batchBuffers[subscriptionId]!.length >= config.maxBatchSize) {
      _flushBatch(subscriptionId);
      return;
    }

    // 设置批处理定时器
    _batchTimers[subscriptionId]?.cancel();
    _batchTimers[subscriptionId] = Timer(
      Duration(milliseconds: config.batchWindowMs),
      () => _flushBatch(subscriptionId),
    );
  }

  /// 刷新批处理缓冲区
  void _flushBatch(String subscriptionId) {
    final events = _batchBuffers[subscriptionId];
    if (events == null || events.isEmpty) return;

    // 合并相同类型的事件
    final merged = _mergeBatchEvents(events);

    // 执行回调
    for (final event in merged) {
      _executeCallback(subscriptionId, event);
    }

    // 清空缓冲区
    _batchBuffers[subscriptionId]!.clear();
    _batchTimers[subscriptionId]?.cancel();
  }

  /// 合并批处理事件
  List<DataChangeEvent> _mergeBatchEvents(List<DataChangeEvent> events) {
    final merged = <DataChangeType, DataChangeEvent>{};

    for (final event in events) {
      if (merged.containsKey(event.type)) {
        // 合并相同类型的事件
        final existing = merged[event.type]!;
        final allIds = {...existing.affectedIds, ...event.affectedIds};

        merged[event.type] = DataChangeEvent(
          type: event.type,
          operation: DataChangeOperation.batch,
          affectedIds: allIds.toList(),
          timestamp: event.timestamp,
        );
      } else {
        merged[event.type] = event;
      }
    }

    return merged.values.toList();
  }

  /// 节流处理事件
  void _throttleEvent(String subscriptionId, DataChangeEvent event, int throttleMs) {
    final now = DateTime.now();
    final lastTime = _lastProcessedTime[subscriptionId];

    if (lastTime != null) {
      final diff = now.difference(lastTime).inMilliseconds;
      if (diff < throttleMs) {
        // 在节流期内，设置定时器延迟执行
        _throttleTimers[subscriptionId]?.cancel();
        _throttleTimers[subscriptionId] = Timer(
          Duration(milliseconds: throttleMs - diff),
          () => _executeCallback(subscriptionId, event),
        );
        return;
      }
    }

    // 可以立即执行
    _executeCallback(subscriptionId, event);
    _lastProcessedTime[subscriptionId] = now;
  }

  /// 执行回调
  void _executeCallback(String subscriptionId, DataChangeEvent event) {
    final callback = _callbacks[subscriptionId];
    if (callback != null) {
      try {
        callback(event);
      } catch (e) {
        debugPrint('数据变更回调执行失败: $e');
      }
    }
  }

  // ========== 便捷方法 ==========

  /// 交易数据变更通知
  void notifyTransactionChanged({
    required DataChangeOperation operation,
    required List<String> transactionIds,
  }) {
    notifyChange(DataChangeEvent(
      type: DataChangeType.transaction,
      operation: operation,
      affectedIds: transactionIds,
    ));
  }

  /// 分类数据变更通知
  void notifyCategoryChanged({
    required DataChangeOperation operation,
    required List<String> categoryIds,
  }) {
    notifyChange(DataChangeEvent(
      type: DataChangeType.category,
      operation: operation,
      affectedIds: categoryIds,
    ));
  }

  /// 账户数据变更通知
  void notifyAccountChanged({
    required DataChangeOperation operation,
    required List<String> accountIds,
  }) {
    notifyChange(DataChangeEvent(
      type: DataChangeType.account,
      operation: operation,
      affectedIds: accountIds,
    ));
  }

  /// 预算数据变更通知
  void notifyBudgetChanged({
    required DataChangeOperation operation,
    required List<String> budgetIds,
  }) {
    notifyChange(DataChangeEvent(
      type: DataChangeType.budget,
      operation: operation,
      affectedIds: budgetIds,
    ));
  }

  /// 家庭数据变更通知
  void notifyFamilyChanged({
    required DataChangeOperation operation,
    required List<String> memberIds,
  }) {
    notifyChange(DataChangeEvent(
      type: DataChangeType.family,
      operation: operation,
      affectedIds: memberIds,
    ));
  }

  /// 钱龄数据变更通知
  void notifyMoneyAgeChanged({
    required DataChangeOperation operation,
    required List<String> transactionIds,
  }) {
    notifyChange(DataChangeEvent(
      type: DataChangeType.moneyAge,
      operation: operation,
      affectedIds: transactionIds,
    ));
  }

  /// 习惯数据变更通知
  void notifyHabitChanged({
    required DataChangeOperation operation,
    required List<String> habitIds,
  }) {
    notifyChange(DataChangeEvent(
      type: DataChangeType.habit,
      operation: operation,
      affectedIds: habitIds,
    ));
  }

  /// 位置数据变更通知
  void notifyLocationChanged({
    required DataChangeOperation operation,
    required List<String> locationIds,
  }) {
    notifyChange(DataChangeEvent(
      type: DataChangeType.location,
      operation: operation,
      affectedIds: locationIds,
    ));
  }

  // ========== 统计信息 ==========

  /// 获取订阅者数量
  int get subscriptionCount => _subscriptions.length;

  /// 获取变更序列号
  int get changeSequence => _changeSequence;

  /// 获取所有订阅信息
  Map<String, Map<String, dynamic>> getSubscriptionInfo() {
    final info = <String, Map<String, dynamic>>{};

    for (final entry in _subscriptions.entries) {
      final id = entry.key;
      final config = entry.value;

      info[id] = {
        'types': config.types.map((t) => t.name).toList(),
        'enableThrottle': config.enableThrottle,
        'throttleMs': config.throttleMs,
        'enableBatching': config.enableBatching,
        'batchWindowMs': config.batchWindowMs,
        'maxBatchSize': config.maxBatchSize,
        'batchBufferSize': _batchBuffers[id]?.length ?? 0,
        'lastProcessedTime': _lastProcessedTime[id]?.toIso8601String(),
      };
    }

    return info;
  }

  // ========== 清理 ==========

  @override
  void dispose() {
    // 取消所有定时器
    for (final timer in _throttleTimers.values) {
      timer.cancel();
    }
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }

    // 清理资源
    _changeController.close();
    _subscriptions.clear();
    _callbacks.clear();
    _throttleTimers.clear();
    _batchBuffers.clear();
    _batchTimers.clear();
    _lastProcessedTime.clear();

    super.dispose();
  }
}

/// 增量刷新策略
enum IncrementalRefreshStrategy {
  /// 全量刷新
  full,

  /// 增量刷新（仅刷新变更的数据）
  incremental,

  /// 智能刷新（根据变更范围自动选择）
  smart,
}

/// 增量刷新管理器
class IncrementalRefreshManager {
  /// 数据版本映射（用于跟踪数据变更）
  final Map<String, int> _dataVersions = {};

  /// 刷新策略
  IncrementalRefreshStrategy strategy;

  /// 智能刷新的阈值（变更数量）
  int smartRefreshThreshold;

  IncrementalRefreshManager({
    this.strategy = IncrementalRefreshStrategy.smart,
    this.smartRefreshThreshold = 10,
  });

  /// 判断是否需要刷新
  bool shouldRefresh(String dataKey, int currentVersion) {
    final lastVersion = _dataVersions[dataKey];
    if (lastVersion == null) return true;

    return currentVersion > lastVersion;
  }

  /// 更新数据版本
  void updateVersion(String dataKey, int version) {
    _dataVersions[dataKey] = version;
  }

  /// 决定刷新策略
  IncrementalRefreshStrategy decideStrategy(int changeCount) {
    if (strategy != IncrementalRefreshStrategy.smart) {
      return strategy;
    }

    // 变更数量超过阈值，使用全量刷新
    if (changeCount >= smartRefreshThreshold) {
      return IncrementalRefreshStrategy.full;
    }

    return IncrementalRefreshStrategy.incremental;
  }

  /// 清除版本信息
  void clear() {
    _dataVersions.clear();
  }
}
