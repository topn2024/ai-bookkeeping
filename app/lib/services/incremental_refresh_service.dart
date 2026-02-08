import 'dart:async';
import 'package:flutter/foundation.dart';

/// 刷新优先级
enum RefreshPriority {
  /// 立即刷新
  immediate,

  /// 高优先级
  high,

  /// 普通优先级
  normal,

  /// 低优先级
  low,

  /// 空闲时刷新
  idle,
}

/// 刷新区域
class RefreshRegion {
  /// 区域ID
  final String id;

  /// 区域名称
  final String name;

  /// 依赖的数据维度
  final Set<String> dependsOnDimensions;

  /// 刷新回调
  final Future<void> Function() refreshCallback;

  /// 优先级
  final RefreshPriority priority;

  /// 是否正在刷新
  bool _isRefreshing = false;

  /// 上次刷新时间
  DateTime? _lastRefreshTime;

  /// 是否需要刷新
  bool _needsRefresh = false;

  /// 脏数据标记
  bool _isDirty = false;

  RefreshRegion({
    required this.id,
    required this.name,
    required this.dependsOnDimensions,
    required this.refreshCallback,
    this.priority = RefreshPriority.normal,
  });

  bool get isRefreshing => _isRefreshing;
  bool get needsRefresh => _needsRefresh;
  bool get isDirty => _isDirty;
  DateTime? get lastRefreshTime => _lastRefreshTime;

  /// 标记需要刷新
  void markNeedsRefresh() {
    _needsRefresh = true;
    _isDirty = true;
  }

  /// 执行刷新
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    try {
      await refreshCallback();
      _needsRefresh = false;
      _isDirty = false;
      _lastRefreshTime = DateTime.now();
    } finally {
      _isRefreshing = false;
    }
  }

  /// 重置状态
  void reset() {
    _needsRefresh = false;
    _isDirty = false;
    _isRefreshing = false;
  }
}

/// 刷新批次
class RefreshBatch {
  /// 批次ID
  final String batchId;

  /// 包含的区域
  final List<RefreshRegion> regions;

  /// 创建时间
  final DateTime createdAt;

  /// 是否已完成
  bool _isCompleted = false;

  RefreshBatch({
    required this.batchId,
    required this.regions,
  }) : createdAt = DateTime.now();

  bool get isCompleted => _isCompleted;

  /// 执行批次刷新
  Future<void> execute() async {
    // 按优先级排序
    regions.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    // 并行执行同优先级的刷新
    final groups = <RefreshPriority, List<RefreshRegion>>{};
    for (final region in regions) {
      groups.putIfAbsent(region.priority, () => []).add(region);
    }

    for (final priority in RefreshPriority.values) {
      final group = groups[priority];
      if (group == null || group.isEmpty) continue;

      await Future.wait(group.map((r) => r.refresh()));
    }

    _isCompleted = true;
  }
}

/// 增量刷新配置
class IncrementalRefreshConfig {
  /// 是否启用批量刷新
  final bool enableBatching;

  /// 批量刷新延迟
  final Duration batchDelay;

  /// 最大并发刷新数
  final int maxConcurrentRefreshes;

  /// 刷新超时时间
  final Duration refreshTimeout;

  /// 是否启用智能调度
  final bool enableSmartScheduling;

  /// 空闲检测延迟
  final Duration idleDetectionDelay;

  const IncrementalRefreshConfig({
    this.enableBatching = true,
    this.batchDelay = const Duration(milliseconds: 100),
    this.maxConcurrentRefreshes = 3,
    this.refreshTimeout = const Duration(seconds: 10),
    this.enableSmartScheduling = true,
    this.idleDetectionDelay = const Duration(milliseconds: 500),
  });
}

/// 可视化组件增量刷新服务
///
/// 核心功能：
/// 1. 基于数据变更的增量刷新
/// 2. 优先级调度
/// 3. 批量合并
/// 4. 并发控制
/// 5. 脏数据标记
///
/// 对应设计文档：第12.6节 可视化组件增量刷新策略
///
/// 使用示例：
/// ```dart
/// final service = IncrementalRefreshService();
///
/// // 注册刷新区域
/// service.registerRegion(RefreshRegion(
///   id: 'pie_chart',
///   name: '分类饼图',
///   dependsOnDimensions: {'category', 'amount'},
///   refreshCallback: () => refreshPieChart(),
/// ));
///
/// // 触发刷新
/// service.triggerRefresh(affectedDimensions: {'category'});
/// ```
class IncrementalRefreshService extends ChangeNotifier {
  /// 配置
  IncrementalRefreshConfig _config;

  /// 注册的刷新区域
  final Map<String, RefreshRegion> _regions = {};

  /// 待处理的刷新队列
  final List<RefreshRegion> _pendingRefreshes = [];

  /// 正在进行的刷新
  final Set<String> _activeRefreshes = {};

  /// 批量刷新定时器
  Timer? _batchTimer;

  /// 空闲刷新定时器
  Timer? _idleTimer;

  /// 刷新历史
  final List<_RefreshRecord> _refreshHistory = [];

  /// 最大历史记录数
  static const int maxHistorySize = 100;

  /// 当前批次计数器
  int _batchCounter = 0;

  IncrementalRefreshService({
    IncrementalRefreshConfig config = const IncrementalRefreshConfig(),
  }) : _config = config;

  IncrementalRefreshConfig get config => _config;

  /// 更新配置
  void updateConfig(IncrementalRefreshConfig config) {
    _config = config;
  }

  /// 注册刷新区域
  void registerRegion(RefreshRegion region) {
    _regions[region.id] = region;
  }

  /// 取消注册刷新区域
  void unregisterRegion(String regionId) {
    _regions.remove(regionId);
    _pendingRefreshes.removeWhere((r) => r.id == regionId);
  }

  /// 触发刷新
  void triggerRefresh({
    required Set<String> affectedDimensions,
    RefreshPriority priority = RefreshPriority.normal,
  }) {
    // 找到受影响的区域
    final affectedRegions = _regions.values.where((region) {
      return region.dependsOnDimensions
          .any((d) => affectedDimensions.contains(d));
    }).toList();

    if (affectedRegions.isEmpty) return;

    // 标记需要刷新
    for (final region in affectedRegions) {
      region.markNeedsRefresh();

      // 添加到待处理队列（避免重复）
      if (!_pendingRefreshes.any((r) => r.id == region.id)) {
        _pendingRefreshes.add(region);
      }
    }

    // 根据优先级处理
    if (priority == RefreshPriority.immediate) {
      _processPendingRefreshes();
    } else if (_config.enableBatching) {
      _scheduleBatchRefresh();
    } else {
      _processPendingRefreshes();
    }
  }

  /// 刷新特定区域
  Future<void> refreshRegion(String regionId) async {
    final region = _regions[regionId];
    if (region == null) return;

    await _executeRefresh(region);
  }

  /// 刷新所有区域
  Future<void> refreshAll() async {
    for (final region in _regions.values) {
      region.markNeedsRefresh();
    }
    await _processPendingRefreshes();
  }

  /// 调度批量刷新
  void _scheduleBatchRefresh() {
    _batchTimer?.cancel();
    _batchTimer = Timer(_config.batchDelay, _processPendingRefreshes);
  }

  /// 处理待处理的刷新
  Future<void> _processPendingRefreshes() async {
    if (_pendingRefreshes.isEmpty) return;

    // 按优先级排序
    _pendingRefreshes.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    // 创建批次
    final batch = RefreshBatch(
      batchId: 'batch_${++_batchCounter}',
      regions: List.from(_pendingRefreshes),
    );
    _pendingRefreshes.clear();

    // 并发控制
    final semaphore = _Semaphore(_config.maxConcurrentRefreshes);

    await Future.wait(
      batch.regions.map((region) async {
        await semaphore.acquire();
        try {
          await _executeRefresh(region);
        } finally {
          semaphore.release();
        }
      }),
    );

    notifyListeners();
  }

  /// 执行刷新
  Future<void> _executeRefresh(RefreshRegion region) async {
    if (region.isRefreshing || _activeRefreshes.contains(region.id)) {
      return;
    }

    _activeRefreshes.add(region.id);
    final startTime = DateTime.now();

    try {
      await region.refresh().timeout(_config.refreshTimeout);

      // 记录历史
      _addToHistory(_RefreshRecord(
        regionId: region.id,
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        success: true,
      ));
    } catch (e) {
      debugPrint('Refresh failed for region ${region.id}: $e');

      _addToHistory(_RefreshRecord(
        regionId: region.id,
        timestamp: startTime,
        duration: DateTime.now().difference(startTime),
        success: false,
        error: e.toString(),
      ));
    } finally {
      _activeRefreshes.remove(region.id);
    }
  }

  /// 添加到历史记录
  void _addToHistory(_RefreshRecord record) {
    _refreshHistory.add(record);
    if (_refreshHistory.length > maxHistorySize) {
      _refreshHistory.removeAt(0);
    }
  }

  /// 调度空闲刷新
  void scheduleIdleRefresh(RefreshRegion region) {
    region.markNeedsRefresh();

    _idleTimer?.cancel();
    _idleTimer = Timer(_config.idleDetectionDelay, () {
      if (region.needsRefresh && !region.isRefreshing) {
        _executeRefresh(region);
      }
    });
  }

  /// 获取区域刷新统计
  Map<String, dynamic> getRegionStats(String regionId) {
    final region = _regions[regionId];
    if (region == null) return {};

    final regionHistory = _refreshHistory.where((r) => r.regionId == regionId);
    final successCount = regionHistory.where((r) => r.success).length;
    final totalCount = regionHistory.length;
    final avgDuration = totalCount > 0
        ? regionHistory.fold<int>(0, (sum, r) => sum + r.duration.inMilliseconds) /
            totalCount
        : 0;

    return {
      'lastRefreshTime': region.lastRefreshTime,
      'isRefreshing': region.isRefreshing,
      'needsRefresh': region.needsRefresh,
      'isDirty': region.isDirty,
      'successRate': totalCount > 0 ? successCount / totalCount : 0,
      'avgDuration': avgDuration,
      'totalRefreshes': totalCount,
    };
  }

  /// 获取所有脏区域
  List<RefreshRegion> getDirtyRegions() {
    return _regions.values.where((r) => r.isDirty).toList();
  }

  /// 重置所有区域状态
  void resetAll() {
    for (final region in _regions.values) {
      region.reset();
    }
    _pendingRefreshes.clear();
    _activeRefreshes.clear();
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    _batchTimer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }
}

/// 刷新记录
class _RefreshRecord {
  final String regionId;
  final DateTime timestamp;
  final Duration duration;
  final bool success;
  final String? error;

  _RefreshRecord({
    required this.regionId,
    required this.timestamp,
    required this.duration,
    required this.success,
    this.error,
  });
}

/// 简单信号量实现
class _Semaphore {
  final int maxConcurrent;
  int _current = 0;
  final List<Completer<void>> _waiters = [];

  _Semaphore(this.maxConcurrent);

  Future<void> acquire() async {
    if (_current < maxConcurrent) {
      _current++;
      return;
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      waiter.complete();
    } else {
      _current--;
    }
  }
}

/// 增量刷新Mixin
/// 方便在Widget中使用
mixin IncrementalRefreshMixin {
  IncrementalRefreshService? _refreshService;
  RefreshRegion? _region;

  /// 初始化增量刷新
  void initIncrementalRefresh({
    required IncrementalRefreshService service,
    required String regionId,
    required String regionName,
    required Set<String> dependsOnDimensions,
    required Future<void> Function() refreshCallback,
    RefreshPriority priority = RefreshPriority.normal,
  }) {
    _refreshService = service;
    _region = RefreshRegion(
      id: regionId,
      name: regionName,
      dependsOnDimensions: dependsOnDimensions,
      refreshCallback: refreshCallback,
      priority: priority,
    );
    service.registerRegion(_region!);
  }

  /// 请求刷新
  void requestRefresh() {
    _region?.markNeedsRefresh();
    if (_region != null && _refreshService != null) {
      _refreshService!.triggerRefresh(
        affectedDimensions: _region!.dependsOnDimensions,
      );
    }
  }

  /// 释放增量刷新
  void disposeIncrementalRefresh() {
    if (_region != null && _refreshService != null) {
      _refreshService!.unregisterRegion(_region!.id);
    }
  }
}
