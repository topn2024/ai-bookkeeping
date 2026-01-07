import 'dart:async';

/// 熔断器状态
enum CircuitState {
  /// 闭合状态 - 正常工作
  closed,

  /// 打开状态 - 拒绝所有请求
  open,

  /// 半开状态 - 允许部分请求尝试
  halfOpen,
}

/// 熔断器打开异常
class CircuitBreakerOpenException implements Exception {
  final String serviceName;
  final DateTime? openedAt;
  final Duration? remainingTime;

  CircuitBreakerOpenException(
    this.serviceName, {
    this.openedAt,
    this.remainingTime,
  });

  @override
  String toString() {
    final remaining = remainingTime?.inSeconds ?? 0;
    return 'CircuitBreakerOpenException: Service "$serviceName" is unavailable. '
        'Circuit breaker is open. Retry in ${remaining}s.';
  }
}

/// 熔断器实现
///
/// 熔断器模式用于防止系统持续调用一个可能失败的服务，
/// 给予服务恢复时���，同时快速失败以提升用户体验。
class CircuitBreaker {
  final String serviceName;
  final int failureThreshold;
  final Duration resetTimeout;
  final Duration? halfOpenTimeout;
  final int halfOpenMaxAttempts;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  int _halfOpenAttempts = 0;
  DateTime? _lastFailure;
  DateTime? _openedAt;

  /// 状态变更回调
  final List<void Function(CircuitState oldState, CircuitState newState)>
      _stateListeners = [];

  CircuitBreaker({
    required this.serviceName,
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(minutes: 1),
    this.halfOpenTimeout,
    this.halfOpenMaxAttempts = 3,
  });

  /// 获取当前状态
  CircuitState get state => _state;

  /// 获取失败次数
  int get failureCount => _failureCount;

  /// 是否可用
  bool get isAvailable => _state != CircuitState.open || _shouldAttemptReset();

  /// 添加状态变更监听
  void addStateListener(
      void Function(CircuitState oldState, CircuitState newState) listener) {
    _stateListeners.add(listener);
  }

  /// 移除状态变更监听
  void removeStateListener(
      void Function(CircuitState oldState, CircuitState newState) listener) {
    _stateListeners.remove(listener);
  }

  /// 执行带熔断保护的操作
  Future<T> execute<T>(Future<T> Function() operation) async {
    // 检查熔断器状态
    if (_state == CircuitState.open) {
      if (_shouldAttemptReset()) {
        _transitionTo(CircuitState.halfOpen);
      } else {
        throw CircuitBreakerOpenException(
          serviceName,
          openedAt: _openedAt,
          remainingTime: _getRemainingResetTime(),
        );
      }
    }

    // 半开状态下限制尝试次数
    if (_state == CircuitState.halfOpen) {
      if (_halfOpenAttempts >= halfOpenMaxAttempts) {
        _transitionTo(CircuitState.open);
        throw CircuitBreakerOpenException(
          serviceName,
          openedAt: _openedAt,
          remainingTime: _getRemainingResetTime(),
        );
      }
      _halfOpenAttempts++;
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  /// 执行带熔断保护的操作（带超时）
  Future<T> executeWithTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
  }) async {
    return execute(() => operation().timeout(timeout));
  }

  /// 执行带熔断保护的操作（带降级）
  Future<T> executeWithFallback<T>(
    Future<T> Function() operation, {
    required T Function() fallback,
  }) async {
    try {
      return await execute(operation);
    } on CircuitBreakerOpenException {
      return fallback();
    }
  }

  /// 手动重置熔断器
  void reset() {
    _failureCount = 0;
    _halfOpenAttempts = 0;
    _lastFailure = null;
    _openedAt = null;
    _transitionTo(CircuitState.closed);
  }

  /// 手动打开熔断器
  void trip() {
    _openedAt = DateTime.now();
    _transitionTo(CircuitState.open);
  }

  void _onSuccess() {
    _failureCount = 0;
    _halfOpenAttempts = 0;
    if (_state == CircuitState.halfOpen) {
      _transitionTo(CircuitState.closed);
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailure = DateTime.now();

    if (_state == CircuitState.halfOpen) {
      // 半开状态下任何失败都立即打开熔断器
      _openedAt = DateTime.now();
      _transitionTo(CircuitState.open);
    } else if (_failureCount >= failureThreshold) {
      _openedAt = DateTime.now();
      _transitionTo(CircuitState.open);
    }
  }

  bool _shouldAttemptReset() {
    if (_openedAt == null) return true;
    return DateTime.now().difference(_openedAt!) >= resetTimeout;
  }

  Duration? _getRemainingResetTime() {
    if (_openedAt == null) return null;
    final elapsed = DateTime.now().difference(_openedAt!);
    if (elapsed >= resetTimeout) return Duration.zero;
    return resetTimeout - elapsed;
  }

  void _transitionTo(CircuitState newState) {
    if (_state == newState) return;
    final oldState = _state;
    _state = newState;

    if (newState == CircuitState.halfOpen) {
      _halfOpenAttempts = 0;
    }

    for (final listener in _stateListeners) {
      listener(oldState, newState);
    }
  }
}

/// 熔断器注册表 - 管理多个服务的熔断器
class CircuitBreakerRegistry {
  final Map<String, CircuitBreaker> _breakers = {};

  final int defaultFailureThreshold;
  final Duration defaultResetTimeout;

  CircuitBreakerRegistry({
    this.defaultFailureThreshold = 5,
    this.defaultResetTimeout = const Duration(minutes: 1),
  });

  /// 获取或创建熔断器
  CircuitBreaker getOrCreate(
    String serviceName, {
    int? failureThreshold,
    Duration? resetTimeout,
  }) {
    return _breakers.putIfAbsent(
      serviceName,
      () => CircuitBreaker(
        serviceName: serviceName,
        failureThreshold: failureThreshold ?? defaultFailureThreshold,
        resetTimeout: resetTimeout ?? defaultResetTimeout,
      ),
    );
  }

  /// 获取熔断器（如果存在）
  CircuitBreaker? get(String serviceName) => _breakers[serviceName];

  /// 获取所有熔断器状态
  Map<String, CircuitState> getAllStates() {
    return _breakers.map((key, value) => MapEntry(key, value.state));
  }

  /// 获取所有打开的熔断器
  List<String> getOpenBreakers() {
    return _breakers.entries
        .where((e) => e.value.state == CircuitState.open)
        .map((e) => e.key)
        .toList();
  }

  /// 重置所有熔断器
  void resetAll() {
    for (final breaker in _breakers.values) {
      breaker.reset();
    }
  }

  /// 重置指定服务的熔断器
  void resetService(String serviceName) {
    _breakers[serviceName]?.reset();
  }
}

/// 全局熔断器注册表
final circuitBreakerRegistry = CircuitBreakerRegistry();
