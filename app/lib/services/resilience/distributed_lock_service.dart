import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// 锁状态
enum LockStatus {
  /// 未获取
  notAcquired,

  /// 已获取
  acquired,

  /// 已释放
  released,

  /// 已过期
  expired,

  /// 获取失败
  failed,
}

/// 分布式锁信息
class DistributedLock {
  /// 锁资源名称
  final String resource;

  /// 锁持有者ID
  final String ownerId;

  /// 获取时间
  final DateTime acquiredAt;

  /// 过期时间
  final DateTime expiresAt;

  /// 状态
  LockStatus status;

  /// 续期次数
  int renewCount;

  /// 等待队列位置（用于公平锁）
  final int? queuePosition;

  DistributedLock({
    required this.resource,
    required this.ownerId,
    required this.acquiredAt,
    required this.expiresAt,
    this.status = LockStatus.acquired,
    this.renewCount = 0,
    this.queuePosition,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeToLive => expiresAt.difference(DateTime.now());

  bool get isValid => status == LockStatus.acquired && !isExpired;

  Map<String, dynamic> toJson() {
    return {
      'resource': resource,
      'ownerId': ownerId,
      'acquiredAt': acquiredAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'status': status.name,
      'renewCount': renewCount,
    };
  }
}

/// 锁获取选项
class LockOptions {
  /// 锁超时时间
  final Duration ttl;

  /// 等待超时时间
  final Duration waitTimeout;

  /// 是否自动续期
  final bool autoRenew;

  /// 续期间隔
  final Duration renewInterval;

  /// 最大续期次数
  final int maxRenewCount;

  /// 重试次数
  final int retryCount;

  /// 重试延迟
  final Duration retryDelay;

  /// 是否使用公平锁
  final bool fairLock;

  const LockOptions({
    this.ttl = const Duration(seconds: 30),
    this.waitTimeout = const Duration(seconds: 10),
    this.autoRenew = true,
    this.renewInterval = const Duration(seconds: 10),
    this.maxRenewCount = 10,
    this.retryCount = 3,
    this.retryDelay = const Duration(milliseconds: 100),
    this.fairLock = false,
  });
}

/// 锁获取结果
class LockAcquireResult {
  /// 是否成功
  final bool success;

  /// 锁实例
  final DistributedLock? lock;

  /// 错误信息
  final String? error;

  /// 等待时间
  final Duration? waitTime;

  const LockAcquireResult({
    required this.success,
    this.lock,
    this.error,
    this.waitTime,
  });

  factory LockAcquireResult.succeeded(DistributedLock lock, {Duration? waitTime}) {
    return LockAcquireResult(
      success: true,
      lock: lock,
      waitTime: waitTime,
    );
  }

  factory LockAcquireResult.failed(String error) {
    return LockAcquireResult(
      success: false,
      error: error,
    );
  }
}

/// 分布式锁节点（模拟多Redis节点）
class LockNode {
  final String nodeId;
  final Map<String, DistributedLock> _locks = {};
  bool _available = true;

  LockNode({required this.nodeId});

  bool get isAvailable => _available;

  void setAvailable(bool available) {
    _available = available;
  }

  /// 尝试获取锁
  bool tryAcquire(String resource, String ownerId, Duration ttl) {
    if (!_available) return false;

    final existing = _locks[resource];
    if (existing != null && !existing.isExpired) {
      return false;
    }

    _locks[resource] = DistributedLock(
      resource: resource,
      ownerId: ownerId,
      acquiredAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl),
    );
    return true;
  }

  /// 释放锁
  bool release(String resource, String ownerId) {
    if (!_available) return false;

    final existing = _locks[resource];
    if (existing == null || existing.ownerId != ownerId) {
      return false;
    }

    _locks.remove(resource);
    return true;
  }

  /// 续期
  bool renew(String resource, String ownerId, Duration ttl) {
    if (!_available) return false;

    final existing = _locks[resource];
    if (existing == null || existing.ownerId != ownerId) {
      return false;
    }

    _locks[resource] = DistributedLock(
      resource: resource,
      ownerId: ownerId,
      acquiredAt: existing.acquiredAt,
      expiresAt: DateTime.now().add(ttl),
      renewCount: existing.renewCount + 1,
    );
    return true;
  }

  /// 清理过期锁
  void cleanup() {
    final expiredKeys = _locks.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
    for (final key in expiredKeys) {
      _locks.remove(key);
    }
  }
}

/// 分布式锁配置
class DistributedLockConfig {
  /// 节点数量（RedLock需要奇数个节点）
  final int nodeCount;

  /// 时钟漂移因子
  final double clockDriftFactor;

  /// 默认锁选项
  final LockOptions defaultOptions;

  /// 清理间隔
  final Duration cleanupInterval;

  const DistributedLockConfig({
    this.nodeCount = 5,
    this.clockDriftFactor = 0.01,
    this.defaultOptions = const LockOptions(),
    this.cleanupInterval = const Duration(minutes: 1),
  });

  /// 计算多数节点数
  int get quorum => (nodeCount ~/ 2) + 1;
}

/// 分布式锁服务
///
/// 实现RedLock算法：
/// 1. 多节点锁定（容错）
/// 2. 自动续期
/// 3. 死锁预防
/// 4. 公平锁支持
///
/// 对应设计文档：第33章 分布式一致性设计
/// 代码块：435
class DistributedLockService extends ChangeNotifier {
  static final DistributedLockService _instance = DistributedLockService._();
  factory DistributedLockService() => _instance;
  DistributedLockService._();

  DistributedLockConfig _config = const DistributedLockConfig();
  bool _initialized = false;
  final Uuid _uuid = const Uuid();

  // 锁节点（模拟多Redis实例）
  final List<LockNode> _nodes = [];

  // 当前持有的锁
  final Map<String, DistributedLock> _heldLocks = {};

  // 续期定时器
  final Map<String, Timer> _renewTimers = {};

  // 等待队列（公平锁）
  final Map<String, List<_LockWaiter>> _waitQueues = {};

  // 统计信息
  int _totalAcquires = 0;
  int _successfulAcquires = 0;
  int _failedAcquires = 0;
  int _releases = 0;
  int _renewals = 0;
  int _timeouts = 0;

  Timer? _cleanupTimer;

  /// 初始化服务
  Future<void> initialize({DistributedLockConfig? config}) async {
    if (_initialized) return;

    _config = config ?? const DistributedLockConfig();

    // 初始化锁节点
    for (var i = 0; i < _config.nodeCount; i++) {
      _nodes.add(LockNode(nodeId: 'node_$i'));
    }

    // 启动定期清理
    _cleanupTimer = Timer.periodic(
      _config.cleanupInterval,
      (_) => _cleanup(),
    );

    _initialized = true;

    if (kDebugMode) {
      debugPrint('DistributedLockService initialized with ${_config.nodeCount} nodes');
    }
  }

  /// 获取锁
  Future<LockAcquireResult> acquire(
    String resource, {
    LockOptions? options,
    String? ownerId,
  }) async {
    final effectiveOptions = options ?? _config.defaultOptions;
    final effectiveOwnerId = ownerId ?? _uuid.v4();
    final startTime = DateTime.now();

    _totalAcquires++;

    // 公平锁处理
    if (effectiveOptions.fairLock) {
      return _acquireFair(resource, effectiveOwnerId, effectiveOptions);
    }

    // 重试循环
    for (var attempt = 0; attempt <= effectiveOptions.retryCount; attempt++) {
      final result = await _tryAcquireRedLock(
        resource,
        effectiveOwnerId,
        effectiveOptions,
      );

      if (result.success) {
        _successfulAcquires++;

        // 设置自动续期
        if (effectiveOptions.autoRenew && result.lock != null) {
          _setupAutoRenew(result.lock!, effectiveOptions);
        }

        return LockAcquireResult.succeeded(
          result.lock!,
          waitTime: DateTime.now().difference(startTime),
        );
      }

      // 检查等待超时
      if (DateTime.now().difference(startTime) >= effectiveOptions.waitTimeout) {
        _failedAcquires++;
        _timeouts++;
        return LockAcquireResult.failed('Wait timeout exceeded');
      }

      // 重试延迟（加入抖动）
      if (attempt < effectiveOptions.retryCount) {
        final jitter = Random().nextInt(50);
        await Future.delayed(
          effectiveOptions.retryDelay + Duration(milliseconds: jitter),
        );
      }
    }

    _failedAcquires++;
    return LockAcquireResult.failed('Max retry count exceeded');
  }

  /// 释放锁
  Future<bool> release(String resource, {String? ownerId}) async {
    final lock = _heldLocks[resource];
    if (lock == null) {
      return false;
    }

    if (ownerId != null && lock.ownerId != ownerId) {
      return false;
    }

    // 取消续期
    _cancelAutoRenew(resource);

    // 在所有节点释放
    var releaseCount = 0;
    for (final node in _nodes) {
      if (node.release(resource, lock.ownerId)) {
        releaseCount++;
      }
    }

    _heldLocks.remove(resource);
    lock.status = LockStatus.released;
    _releases++;

    // 通知等待队列
    _notifyWaiters(resource);

    notifyListeners();

    return releaseCount > 0;
  }

  /// 执行带锁保护的操作
  Future<T> withLock<T>(
    String resource,
    Future<T> Function() operation, {
    LockOptions? options,
  }) async {
    final result = await acquire(resource, options: options);

    if (!result.success) {
      throw LockAcquireException(resource, result.error ?? 'Unknown error');
    }

    try {
      return await operation();
    } finally {
      await release(resource, ownerId: result.lock!.ownerId);
    }
  }

  /// 尝试执行带锁保护的操作（不等待）
  Future<T?> tryWithLock<T>(
    String resource,
    Future<T> Function() operation, {
    Duration? ttl,
  }) async {
    final result = await acquire(
      resource,
      options: LockOptions(
        ttl: ttl ?? const Duration(seconds: 30),
        waitTimeout: Duration.zero,
        retryCount: 0,
      ),
    );

    if (!result.success) {
      return null;
    }

    try {
      return await operation();
    } finally {
      await release(resource, ownerId: result.lock!.ownerId);
    }
  }

  /// 检查锁是否被持有
  bool isLocked(String resource) {
    final lock = _heldLocks[resource];
    return lock != null && lock.isValid;
  }

  /// 获取当前持有的锁信息
  DistributedLock? getLockInfo(String resource) => _heldLocks[resource];

  /// 获取统计信息
  LockStats getStats() {
    return LockStats(
      totalAcquires: _totalAcquires,
      successfulAcquires: _successfulAcquires,
      failedAcquires: _failedAcquires,
      releases: _releases,
      renewals: _renewals,
      timeouts: _timeouts,
      currentlyHeld: _heldLocks.length,
      waitingCount: _waitQueues.values.fold(0, (sum, q) => sum + q.length),
    );
  }

  // ==================== RedLock实现 ====================

  Future<LockAcquireResult> _tryAcquireRedLock(
    String resource,
    String ownerId,
    LockOptions options,
  ) async {
    final startTime = DateTime.now();
    final ttl = options.ttl;

    // 尝试在所有节点获取锁
    var successCount = 0;
    for (final node in _nodes) {
      if (node.tryAcquire(resource, ownerId, ttl)) {
        successCount++;
      }
    }

    // 计算有效性
    final elapsedTime = DateTime.now().difference(startTime);
    final drift = Duration(
      milliseconds: (ttl.inMilliseconds * _config.clockDriftFactor).toInt() + 2,
    );
    final validity = ttl - elapsedTime - drift;

    // 检查是否获得多数节点
    if (successCount >= _config.quorum && validity.isNegative == false) {
      final lock = DistributedLock(
        resource: resource,
        ownerId: ownerId,
        acquiredAt: DateTime.now(),
        expiresAt: DateTime.now().add(validity),
      );

      _heldLocks[resource] = lock;
      return LockAcquireResult.succeeded(lock);
    }

    // 获取失败，释放已获取的锁
    for (final node in _nodes) {
      node.release(resource, ownerId);
    }

    return LockAcquireResult.failed(
      'Failed to acquire lock on quorum nodes (got $successCount/${_config.quorum})',
    );
  }

  Future<LockAcquireResult> _acquireFair(
    String resource,
    String ownerId,
    LockOptions options,
  ) async {
    // 加入等待队列
    final waiter = _LockWaiter(
      ownerId: ownerId,
      addedAt: DateTime.now(),
      completer: Completer<LockAcquireResult>(),
    );

    _waitQueues.putIfAbsent(resource, () => []).add(waiter);

    // 如果是队列第一个，尝试获取
    if (_waitQueues[resource]!.first.ownerId == ownerId) {
      _processWaitQueue(resource, options);
    }

    // 等待结果或超时
    try {
      return await waiter.completer.future.timeout(options.waitTimeout);
    } on TimeoutException {
      // 从队列移除
      _waitQueues[resource]?.removeWhere((w) => w.ownerId == ownerId);
      _timeouts++;
      return LockAcquireResult.failed('Wait timeout exceeded');
    }
  }

  void _processWaitQueue(String resource, LockOptions options) async {
    final queue = _waitQueues[resource];
    if (queue == null || queue.isEmpty) return;

    final waiter = queue.first;

    final result = await _tryAcquireRedLock(resource, waiter.ownerId, options);

    if (result.success) {
      queue.removeAt(0);
      waiter.completer.complete(result);

      if (options.autoRenew && result.lock != null) {
        _setupAutoRenew(result.lock!, options);
      }

      _successfulAcquires++;
    } else {
      // 延迟重试
      await Future.delayed(options.retryDelay);
      if (!waiter.completer.isCompleted) {
        _processWaitQueue(resource, options);
      }
    }
  }

  void _notifyWaiters(String resource) {
    final queue = _waitQueues[resource];
    if (queue != null && queue.isNotEmpty) {
      // 处理下一个等待者
      _processWaitQueue(resource, _config.defaultOptions);
    }
  }

  // ==================== 自动续期 ====================

  void _setupAutoRenew(DistributedLock lock, LockOptions options) {
    _renewTimers[lock.resource]?.cancel();

    _renewTimers[lock.resource] = Timer.periodic(
      options.renewInterval,
      (_) => _renewLock(lock, options),
    );
  }

  void _cancelAutoRenew(String resource) {
    _renewTimers[resource]?.cancel();
    _renewTimers.remove(resource);
  }

  void _renewLock(DistributedLock lock, LockOptions options) {
    if (!_heldLocks.containsKey(lock.resource)) {
      _cancelAutoRenew(lock.resource);
      return;
    }

    if (lock.renewCount >= options.maxRenewCount) {
      _cancelAutoRenew(lock.resource);
      if (kDebugMode) {
        debugPrint('Lock ${lock.resource} max renew count reached');
      }
      return;
    }

    var renewCount = 0;
    for (final node in _nodes) {
      if (node.renew(lock.resource, lock.ownerId, options.ttl)) {
        renewCount++;
      }
    }

    if (renewCount >= _config.quorum) {
      lock.renewCount++;
      _renewals++;
      if (kDebugMode) {
        debugPrint('Lock ${lock.resource} renewed (${lock.renewCount}/${options.maxRenewCount})');
      }
    } else {
      // 续期失败，锁可能已丢失
      _heldLocks.remove(lock.resource);
      lock.status = LockStatus.expired;
      _cancelAutoRenew(lock.resource);

      if (kDebugMode) {
        debugPrint('Lock ${lock.resource} renewal failed');
      }
    }
  }

  void _cleanup() {
    // 清理各节点过期锁
    for (final node in _nodes) {
      node.cleanup();
    }

    // 清理本地过期锁
    final expiredLocks = _heldLocks.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final resource in expiredLocks) {
      _heldLocks.remove(resource);
      _cancelAutoRenew(resource);
    }
  }

  /// 关闭服务
  Future<void> close() async {
    _cleanupTimer?.cancel();

    // 释放所有锁
    for (final resource in _heldLocks.keys.toList()) {
      await release(resource);
    }

    // 取消所有续期定时器
    for (final timer in _renewTimers.values) {
      timer.cancel();
    }
    _renewTimers.clear();

    // 清理等待队列
    for (final queue in _waitQueues.values) {
      for (final waiter in queue) {
        if (!waiter.completer.isCompleted) {
          waiter.completer.complete(LockAcquireResult.failed('Service closing'));
        }
      }
    }
    _waitQueues.clear();

    _nodes.clear();
    _heldLocks.clear();
    _initialized = false;
  }
}

class _LockWaiter {
  final String ownerId;
  final DateTime addedAt;
  final Completer<LockAcquireResult> completer;

  _LockWaiter({
    required this.ownerId,
    required this.addedAt,
    required this.completer,
  });
}

/// 锁统计信息
class LockStats {
  final int totalAcquires;
  final int successfulAcquires;
  final int failedAcquires;
  final int releases;
  final int renewals;
  final int timeouts;
  final int currentlyHeld;
  final int waitingCount;

  const LockStats({
    required this.totalAcquires,
    required this.successfulAcquires,
    required this.failedAcquires,
    required this.releases,
    required this.renewals,
    required this.timeouts,
    required this.currentlyHeld,
    required this.waitingCount,
  });

  double get successRate =>
      totalAcquires > 0 ? successfulAcquires / totalAcquires : 0.0;
}

/// 锁获取异常
class LockAcquireException implements Exception {
  final String resource;
  final String message;

  LockAcquireException(this.resource, this.message);

  @override
  String toString() =>
      'LockAcquireException: Failed to acquire lock on "$resource": $message';
}

/// 全局分布式锁服务实例
final distributedLock = DistributedLockService();
