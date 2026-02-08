import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 限流级别
enum RateLimitLevel {
  /// 全局级别
  global,

  /// API级别
  api,

  /// 用户级别
  user,

  /// IP级别
  ip,
}

/// 限流结果
class RateLimitResult {
  /// 是否允许请求
  final bool allowed;

  /// 剩余令牌数
  final int remainingTokens;

  /// 重试等待时间（毫秒）
  final int retryAfterMs;

  /// 限流级别
  final RateLimitLevel? limitLevel;

  /// 限流原因
  final String? reason;

  const RateLimitResult({
    required this.allowed,
    this.remainingTokens = 0,
    this.retryAfterMs = 0,
    this.limitLevel,
    this.reason,
  });

  factory RateLimitResult.allowed({int remainingTokens = 0}) {
    return RateLimitResult(
      allowed: true,
      remainingTokens: remainingTokens,
    );
  }

  factory RateLimitResult.denied({
    required RateLimitLevel level,
    required int retryAfterMs,
    String? reason,
  }) {
    return RateLimitResult(
      allowed: false,
      remainingTokens: 0,
      retryAfterMs: retryAfterMs,
      limitLevel: level,
      reason: reason,
    );
  }
}

/// 限流异常
class RateLimitExceededException implements Exception {
  final RateLimitLevel level;
  final int retryAfterMs;
  final String? reason;

  RateLimitExceededException({
    required this.level,
    required this.retryAfterMs,
    this.reason,
  });

  @override
  String toString() {
    return 'RateLimitExceededException: Rate limit exceeded at ${level.name} level. '
        'Retry after ${retryAfterMs}ms. ${reason ?? ""}';
  }
}

/// 令牌桶配置
class TokenBucketConfig {
  /// 桶容量（最大令牌数）
  final int capacity;

  /// 每秒填充令牌数
  final double refillRate;

  /// 初始令牌数
  final int initialTokens;

  const TokenBucketConfig({
    required this.capacity,
    required this.refillRate,
    int? initialTokens,
  }) : initialTokens = initialTokens ?? capacity;
}

/// 令牌桶实现
class TokenBucket {
  final TokenBucketConfig config;

  double _tokens;
  DateTime _lastRefill;

  TokenBucket({required this.config})
      : _tokens = config.initialTokens.toDouble(),
        _lastRefill = DateTime.now();

  /// 当前令牌数
  int get tokens {
    _refill();
    return _tokens.floor();
  }

  /// 尝试获取令牌
  bool tryAcquire([int count = 1]) {
    _refill();

    if (_tokens >= count) {
      _tokens -= count;
      return true;
    }
    return false;
  }

  /// 获取等待时间（毫秒）
  int getWaitTimeMs([int count = 1]) {
    _refill();

    if (_tokens >= count) return 0;

    final needed = count - _tokens;
    final waitSeconds = needed / config.refillRate;
    return (waitSeconds * 1000).ceil();
  }

  /// 填充令牌
  void _refill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill).inMilliseconds / 1000.0;

    if (elapsed > 0) {
      _tokens = min(
        config.capacity.toDouble(),
        _tokens + (elapsed * config.refillRate),
      );
      _lastRefill = now;
    }
  }

  /// 重置令牌桶
  void reset() {
    _tokens = config.capacity.toDouble();
    _lastRefill = DateTime.now();
  }
}

/// 滑动窗口限流器
class SlidingWindowLimiter {
  final int maxRequests;
  final Duration windowSize;

  final Queue<DateTime> _requestTimes = Queue();

  SlidingWindowLimiter({
    required this.maxRequests,
    required this.windowSize,
  });

  /// 尝试请求
  bool tryAcquire() {
    _cleanup();

    if (_requestTimes.length < maxRequests) {
      _requestTimes.add(DateTime.now());
      return true;
    }
    return false;
  }

  /// 剩余配额
  int get remainingQuota {
    _cleanup();
    return maxRequests - _requestTimes.length;
  }

  /// 获取等待时间（毫秒）
  int getWaitTimeMs() {
    _cleanup();

    if (_requestTimes.length < maxRequests) return 0;

    final oldest = _requestTimes.first;
    final windowEnd = oldest.add(windowSize);
    final wait = windowEnd.difference(DateTime.now());

    return wait.isNegative ? 0 : wait.inMilliseconds;
  }

  /// 清理过期记录
  void _cleanup() {
    final cutoff = DateTime.now().subtract(windowSize);

    while (_requestTimes.isNotEmpty && _requestTimes.first.isBefore(cutoff)) {
      _requestTimes.removeFirst();
    }
  }

  /// 重置
  void reset() {
    _requestTimes.clear();
  }
}

/// 限流配置
class RateLimiterConfig {
  /// 全局限流配置（每秒请求数）
  final TokenBucketConfig globalConfig;

  /// API级别限流配置
  final Map<String, TokenBucketConfig> apiConfigs;

  /// 用户级别默认配置
  final TokenBucketConfig userDefaultConfig;

  /// IP级别默认配置
  final TokenBucketConfig ipDefaultConfig;

  /// 是否启用滑动窗口限流
  final bool enableSlidingWindow;

  /// 滑动窗口大小
  final Duration slidingWindowSize;

  /// 滑动窗口最大请求数
  final int slidingWindowMaxRequests;

  /// 白名单用户（不限流）
  final Set<String> whitelistUsers;

  /// 白名单IP（不限流）
  final Set<String> whitelistIPs;

  const RateLimiterConfig({
    this.globalConfig = const TokenBucketConfig(
      capacity: 10000,
      refillRate: 5000, // 每秒5000个请求
    ),
    this.apiConfigs = const {},
    this.userDefaultConfig = const TokenBucketConfig(
      capacity: 100,
      refillRate: 50, // 每秒50个请求
    ),
    this.ipDefaultConfig = const TokenBucketConfig(
      capacity: 200,
      refillRate: 100, // 每秒100个请求
    ),
    this.enableSlidingWindow = true,
    this.slidingWindowSize = const Duration(minutes: 1),
    this.slidingWindowMaxRequests = 1000,
    this.whitelistUsers = const {},
    this.whitelistIPs = const {},
  });

  /// 10万DAU默认配置
  static const defaultFor100kDAU = RateLimiterConfig(
    globalConfig: TokenBucketConfig(
      capacity: 10000,
      refillRate: 5000,
    ),
    userDefaultConfig: TokenBucketConfig(
      capacity: 100,
      refillRate: 50,
    ),
    ipDefaultConfig: TokenBucketConfig(
      capacity: 200,
      refillRate: 100,
    ),
    slidingWindowMaxRequests: 1000,
  );

  /// 获取API配置
  TokenBucketConfig getApiConfig(String apiPath) {
    // 精确匹配
    if (apiConfigs.containsKey(apiPath)) {
      return apiConfigs[apiPath]!;
    }

    // 前缀匹配
    for (final entry in apiConfigs.entries) {
      if (apiPath.startsWith(entry.key)) {
        return entry.value;
      }
    }

    // 默认配置
    return const TokenBucketConfig(
      capacity: 500,
      refillRate: 200,
    );
  }
}

/// 多级限流服务
///
/// 实现4层限流策略：
/// 1. 全局级别 - 系统整体保护
/// 2. API级别 - 单接口保护
/// 3. 用户级别 - 防止单用户滥用
/// 4. IP级别 - 防止恶意攻击
///
/// 对应设计文档：第32章 高可用架构设计
/// 代码块：427
class RateLimiterService extends ChangeNotifier {
  static final RateLimiterService _instance = RateLimiterService._();
  factory RateLimiterService() => _instance;
  RateLimiterService._();

  RateLimiterConfig _config = const RateLimiterConfig();
  bool _initialized = false;
  bool _enabled = true;

  // 全局限流器
  late TokenBucket _globalBucket;

  // API级别限流器
  final Map<String, TokenBucket> _apiBuckets = {};

  // 用户级别限流器
  final Map<String, TokenBucket> _userBuckets = {};

  // IP级别限流器
  final Map<String, TokenBucket> _ipBuckets = {};

  // 滑动窗口限流器（用于突发检测）
  final Map<String, SlidingWindowLimiter> _slidingWindows = {};

  // 统计信息
  int _totalRequests = 0;
  int _allowedRequests = 0;
  int _deniedRequests = 0;
  final Map<RateLimitLevel, int> _denialsByLevel = {};

  // 清理定时器
  Timer? _cleanupTimer;

  /// 初始化服务
  Future<void> initialize({RateLimiterConfig? config}) async {
    if (_initialized) return;

    _config = config ?? const RateLimiterConfig();
    _globalBucket = TokenBucket(config: _config.globalConfig);

    // 启动定期清理
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanup(),
    );

    _initialized = true;

    if (kDebugMode) {
      debugPrint('RateLimiterService initialized with config: '
          'global=${_config.globalConfig.capacity}/${_config.globalConfig.refillRate}/s');
    }
  }

  /// 是否启用
  bool get isEnabled => _enabled;

  /// 启用/禁用限流
  void setEnabled(bool enabled) {
    _enabled = enabled;
    notifyListeners();
  }

  /// 检查请求是否被允许
  RateLimitResult checkRequest({
    required String apiPath,
    String? userId,
    String? ipAddress,
  }) {
    if (!_enabled) {
      return RateLimitResult.allowed(remainingTokens: -1);
    }

    _totalRequests++;

    // 1. 检查白名单
    if (userId != null && _config.whitelistUsers.contains(userId)) {
      _allowedRequests++;
      return RateLimitResult.allowed(remainingTokens: -1);
    }
    if (ipAddress != null && _config.whitelistIPs.contains(ipAddress)) {
      _allowedRequests++;
      return RateLimitResult.allowed(remainingTokens: -1);
    }

    // 2. 全局限流检查
    if (!_globalBucket.tryAcquire()) {
      _recordDenial(RateLimitLevel.global);
      return RateLimitResult.denied(
        level: RateLimitLevel.global,
        retryAfterMs: _globalBucket.getWaitTimeMs(),
        reason: 'System is busy, please try again later',
      );
    }

    // 3. API级别限流检查
    final apiBucket = _getOrCreateApiBucket(apiPath);
    if (!apiBucket.tryAcquire()) {
      _recordDenial(RateLimitLevel.api);
      return RateLimitResult.denied(
        level: RateLimitLevel.api,
        retryAfterMs: apiBucket.getWaitTimeMs(),
        reason: 'API rate limit exceeded for $apiPath',
      );
    }

    // 4. 用户级别限流检查
    if (userId != null) {
      final userBucket = _getOrCreateUserBucket(userId);
      if (!userBucket.tryAcquire()) {
        _recordDenial(RateLimitLevel.user);
        return RateLimitResult.denied(
          level: RateLimitLevel.user,
          retryAfterMs: userBucket.getWaitTimeMs(),
          reason: 'User rate limit exceeded',
        );
      }
    }

    // 5. IP级别限流检查
    if (ipAddress != null) {
      final ipBucket = _getOrCreateIpBucket(ipAddress);
      if (!ipBucket.tryAcquire()) {
        _recordDenial(RateLimitLevel.ip);
        return RateLimitResult.denied(
          level: RateLimitLevel.ip,
          retryAfterMs: ipBucket.getWaitTimeMs(),
          reason: 'IP rate limit exceeded',
        );
      }
    }

    // 6. 滑动窗口突发检测（可选）
    if (_config.enableSlidingWindow && userId != null) {
      final window = _getOrCreateSlidingWindow(userId);
      if (!window.tryAcquire()) {
        _recordDenial(RateLimitLevel.user);
        return RateLimitResult.denied(
          level: RateLimitLevel.user,
          retryAfterMs: window.getWaitTimeMs(),
          reason: 'Request burst detected',
        );
      }
    }

    _allowedRequests++;
    return RateLimitResult.allowed(
      remainingTokens: _globalBucket.tokens,
    );
  }

  /// 执行带限流保护的操作
  Future<T> execute<T>({
    required String apiPath,
    required Future<T> Function() operation,
    String? userId,
    String? ipAddress,
    bool throwOnLimit = true,
    T Function()? fallback,
  }) async {
    final result = checkRequest(
      apiPath: apiPath,
      userId: userId,
      ipAddress: ipAddress,
    );

    if (!result.allowed) {
      if (throwOnLimit) {
        throw RateLimitExceededException(
          level: result.limitLevel!,
          retryAfterMs: result.retryAfterMs,
          reason: result.reason,
        );
      }

      if (fallback != null) {
        return fallback();
      }

      // 等待后重试
      await Future.delayed(Duration(milliseconds: result.retryAfterMs));
      return execute(
        apiPath: apiPath,
        operation: operation,
        userId: userId,
        ipAddress: ipAddress,
        throwOnLimit: true,
      );
    }

    return operation();
  }

  /// 获取用户剩余配额
  int getUserRemainingQuota(String userId) {
    final bucket = _userBuckets[userId];
    return bucket?.tokens ?? _config.userDefaultConfig.capacity;
  }

  /// 获取API剩余配额
  int getApiRemainingQuota(String apiPath) {
    final bucket = _apiBuckets[apiPath];
    return bucket?.tokens ?? _config.getApiConfig(apiPath).capacity;
  }

  /// 获取统计信息
  RateLimitStats getStats() {
    return RateLimitStats(
      totalRequests: _totalRequests,
      allowedRequests: _allowedRequests,
      deniedRequests: _deniedRequests,
      denialsByLevel: Map.from(_denialsByLevel),
      activeUserBuckets: _userBuckets.length,
      activeIpBuckets: _ipBuckets.length,
      activeApiBuckets: _apiBuckets.length,
    );
  }

  /// 重置用户限流
  void resetUserLimit(String userId) {
    _userBuckets[userId]?.reset();
    _slidingWindows[userId]?.reset();
  }

  /// 重置所有限流
  void resetAll() {
    _globalBucket.reset();
    for (final bucket in _apiBuckets.values) {
      bucket.reset();
    }
    for (final bucket in _userBuckets.values) {
      bucket.reset();
    }
    for (final bucket in _ipBuckets.values) {
      bucket.reset();
    }
    for (final window in _slidingWindows.values) {
      window.reset();
    }

    _totalRequests = 0;
    _allowedRequests = 0;
    _deniedRequests = 0;
    _denialsByLevel.clear();
  }

  // ==================== 私有方法 ====================

  TokenBucket _getOrCreateApiBucket(String apiPath) {
    return _apiBuckets.putIfAbsent(
      apiPath,
      () => TokenBucket(config: _config.getApiConfig(apiPath)),
    );
  }

  TokenBucket _getOrCreateUserBucket(String userId) {
    return _userBuckets.putIfAbsent(
      userId,
      () => TokenBucket(config: _config.userDefaultConfig),
    );
  }

  TokenBucket _getOrCreateIpBucket(String ipAddress) {
    return _ipBuckets.putIfAbsent(
      ipAddress,
      () => TokenBucket(config: _config.ipDefaultConfig),
    );
  }

  SlidingWindowLimiter _getOrCreateSlidingWindow(String key) {
    return _slidingWindows.putIfAbsent(
      key,
      () => SlidingWindowLimiter(
        maxRequests: _config.slidingWindowMaxRequests,
        windowSize: _config.slidingWindowSize,
      ),
    );
  }

  void _recordDenial(RateLimitLevel level) {
    _deniedRequests++;
    _denialsByLevel[level] = (_denialsByLevel[level] ?? 0) + 1;
    notifyListeners();
  }

  /// 清理长时间未使用的限流器
  void _cleanup() {
    // 保留最近活跃的用户/IP限流器，避免内存泄漏
    // 实际生产中可能需要更复杂的LRU策略
    if (_userBuckets.length > 10000) {
      final toRemove = _userBuckets.keys.take(_userBuckets.length - 5000).toList();
      for (final key in toRemove) {
        _userBuckets.remove(key);
      }
    }

    if (_ipBuckets.length > 5000) {
      final toRemove = _ipBuckets.keys.take(_ipBuckets.length - 2500).toList();
      for (final key in toRemove) {
        _ipBuckets.remove(key);
      }
    }

    if (_slidingWindows.length > 10000) {
      final toRemove = _slidingWindows.keys.take(_slidingWindows.length - 5000).toList();
      for (final key in toRemove) {
        _slidingWindows.remove(key);
      }
    }
  }

  /// 关闭服务
  Future<void> close() async {
    _cleanupTimer?.cancel();
    _apiBuckets.clear();
    _userBuckets.clear();
    _ipBuckets.clear();
    _slidingWindows.clear();
    _initialized = false;
  }
}

/// 限流统计信息
class RateLimitStats {
  final int totalRequests;
  final int allowedRequests;
  final int deniedRequests;
  final Map<RateLimitLevel, int> denialsByLevel;
  final int activeUserBuckets;
  final int activeIpBuckets;
  final int activeApiBuckets;

  const RateLimitStats({
    required this.totalRequests,
    required this.allowedRequests,
    required this.deniedRequests,
    required this.denialsByLevel,
    required this.activeUserBuckets,
    required this.activeIpBuckets,
    required this.activeApiBuckets,
  });

  double get allowanceRate =>
      totalRequests > 0 ? allowedRequests / totalRequests : 1.0;

  double get denialRate =>
      totalRequests > 0 ? deniedRequests / totalRequests : 0.0;
}

/// 全局限流服务实例
final rateLimiter = RateLimiterService();
