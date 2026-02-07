import 'dart:math' show Random;

import '../core/asr_exception.dart';

/// 重试策略
///
/// 提供指数退避重试机制
class RetryPolicy {
  /// 最大重试次数
  final int maxRetries;

  /// 基础延迟（毫秒）
  final int baseDelayMs;

  /// 最大延迟（毫秒）
  final int maxDelayMs;

  /// 是否添加抖动
  final bool addJitter;

  /// 判断异常是否可重试的函数
  final bool Function(Object error)? isRetryable;

  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelayMs = 500,
    this.maxDelayMs = 30000,
    this.addJitter = true,
    this.isRetryable,
  });

  /// 默认策略
  factory RetryPolicy.defaults() {
    return const RetryPolicy();
  }

  /// 无重试策略
  factory RetryPolicy.none() {
    return const RetryPolicy(maxRetries: 0);
  }

  /// 激进重试策略（用于重要操作）
  factory RetryPolicy.aggressive() {
    return const RetryPolicy(
      maxRetries: 5,
      baseDelayMs: 200,
      maxDelayMs: 60000,
    );
  }

  /// 计算指定重试次数的延迟
  int calculateDelay(int retryCount) {
    if (retryCount <= 0) return 0;

    // 指数退避：base * 2^(retryCount-1)
    var delay = baseDelayMs * (1 << (retryCount - 1));

    // 限制最大延迟
    delay = delay.clamp(0, maxDelayMs);

    // 添加随机抖动（0-25%）
    if (addJitter) {
      final jitter = (delay * 0.25 * Random().nextDouble()).round();
      delay += jitter;
    }

    return delay;
  }

  /// 检查是否应该重试
  bool shouldRetry(int currentRetry, Object error) {
    if (currentRetry >= maxRetries) return false;

    if (isRetryable != null) {
      return isRetryable!(error);
    }

    // 默认可重试的异常类型
    if (error is ASRException) {
      return error.isRetryable;
    }

    return true;
  }

  /// 执行带重试的操作
  Future<T> execute<T>(Future<T> Function() operation) async {
    int retryCount = 0;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;

        if (!shouldRetry(retryCount, e)) {
          rethrow;
        }

        final delay = calculateDelay(retryCount);
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
  }
}

/// 重试执行器
///
/// 提供更灵活的重试控制
class RetryExecutor {
  final RetryPolicy policy;

  /// 当前重试次数
  int _retryCount = 0;

  /// 上次错误
  Object? _lastError;

  RetryExecutor({RetryPolicy? policy})
      : policy = policy ?? RetryPolicy.defaults();

  /// 当前重试次数
  int get retryCount => _retryCount;

  /// 上次错误
  Object? get lastError => _lastError;

  /// 是否还可以重试
  bool get canRetry => _retryCount < policy.maxRetries;

  /// 重置重试状态
  void reset() {
    _retryCount = 0;
    _lastError = null;
  }

  /// 记录错误并检查是否可以重试
  bool recordErrorAndCheckRetry(Object error) {
    _lastError = error;
    _retryCount++;
    return policy.shouldRetry(_retryCount, error);
  }

  /// 获取当前延迟时间
  Duration get currentDelay {
    return Duration(milliseconds: policy.calculateDelay(_retryCount));
  }

  /// 等待重试延迟
  Future<void> waitForRetry() async {
    await Future.delayed(currentDelay);
  }

  /// 执行带重试的操作
  Future<T> execute<T>(
    Future<T> Function() operation, {
    void Function(int retryCount, Object error, Duration delay)? onRetry,
  }) async {
    reset();

    while (true) {
      try {
        final result = await operation();
        reset();
        return result;
      } catch (e) {
        if (!recordErrorAndCheckRetry(e)) {
          rethrow;
        }

        final delay = currentDelay;
        onRetry?.call(_retryCount, e, delay);
        await Future.delayed(delay);
      }
    }
  }
}
