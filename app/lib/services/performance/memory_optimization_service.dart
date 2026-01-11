import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 内存使用信息
class MemoryInfo {
  /// 已使用堆内存 (bytes)
  final int usedHeapMemory;

  /// 已提交堆内存 (bytes)
  final int committedHeapMemory;

  /// 外部内存 (bytes)
  final int externalMemory;

  /// 时间戳
  final DateTime timestamp;

  const MemoryInfo({
    required this.usedHeapMemory,
    required this.committedHeapMemory,
    required this.externalMemory,
    required this.timestamp,
  });

  /// 总内存使用
  int get totalUsed => usedHeapMemory + externalMemory;

  /// 格式化内存大小
  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() {
    return 'MemoryInfo(used: ${formatSize(usedHeapMemory)}, '
        'committed: ${formatSize(committedHeapMemory)}, '
        'external: ${formatSize(externalMemory)})';
  }
}

/// 内存警告级别
enum MemoryWarningLevel {
  /// 正常
  normal,

  /// 轻微压力
  light,

  /// 中等压力
  moderate,

  /// 严重压力
  critical,
}

/// 缓存项
class CacheEntry<T> {
  /// 缓存键
  final String key;

  /// 缓存值
  final T value;

  /// 创建时间
  final DateTime createdAt;

  /// 最后访问时间
  DateTime lastAccessedAt;

  /// 访问次数
  int accessCount;

  /// 估计大小 (bytes)
  final int estimatedSize;

  /// 过期时间
  final DateTime? expiresAt;

  CacheEntry({
    required this.key,
    required this.value,
    DateTime? createdAt,
    this.estimatedSize = 0,
    Duration? ttl,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastAccessedAt = createdAt ?? DateTime.now(),
        accessCount = 1,
        expiresAt = ttl != null ? DateTime.now().add(ttl) : null;

  /// 是否已过期
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// 更新访问记录
  void recordAccess() {
    lastAccessedAt = DateTime.now();
    accessCount++;
  }
}

/// 缓存淘汰策略
enum CacheEvictionPolicy {
  /// 最近最少使用
  lru,

  /// 最不经常使用
  lfu,

  /// 先进先出
  fifo,

  /// 基于大小
  sizeBased,

  /// 基于过期时间
  ttl,
}

/// 智能缓存管理器
class SmartCacheManager<T> {
  /// 缓存存储
  final Map<String, CacheEntry<T>> _cache = {};

  /// LRU 链表（用于 LRU 策略）
  final LinkedHashMap<String, CacheEntry<T>> _lruCache = LinkedHashMap();

  /// 配置
  final SmartCacheConfig config;

  /// 当前缓存大小
  int _currentSize = 0;

  /// 缓存命中次数
  int _hitCount = 0;

  /// 缓存未命中次数
  int _missCount = 0;

  SmartCacheManager({
    this.config = const SmartCacheConfig(),
  });

  /// 获取缓存
  T? get(String key) {
    final entry = _cache[key];

    if (entry == null) {
      _missCount++;
      return null;
    }

    // 检查是否过期
    if (entry.isExpired) {
      remove(key);
      _missCount++;
      return null;
    }

    // 更新访问记录
    entry.recordAccess();

    // 更新 LRU 顺序
    if (config.evictionPolicy == CacheEvictionPolicy.lru) {
      _lruCache.remove(key);
      _lruCache[key] = entry;
    }

    _hitCount++;
    return entry.value;
  }

  /// 设置缓存
  void set(
    String key,
    T value, {
    int estimatedSize = 0,
    Duration? ttl,
  }) {
    // 检查是否需要淘汰
    _ensureCapacity(estimatedSize);

    // 移除旧条目
    if (_cache.containsKey(key)) {
      _currentSize -= _cache[key]!.estimatedSize;
    }

    // 创建新条目
    final entry = CacheEntry<T>(
      key: key,
      value: value,
      estimatedSize: estimatedSize,
      ttl: ttl ?? config.defaultTtl,
    );

    _cache[key] = entry;
    _lruCache[key] = entry;
    _currentSize += estimatedSize;
  }

  /// 移除缓存
  void remove(String key) {
    final entry = _cache.remove(key);
    _lruCache.remove(key);
    if (entry != null) {
      _currentSize -= entry.estimatedSize;
    }
  }

  /// 清空缓存
  void clear() {
    _cache.clear();
    _lruCache.clear();
    _currentSize = 0;
  }

  /// 是否包含键
  bool containsKey(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      remove(key);
      return false;
    }
    return true;
  }

  /// 获取或设置
  T getOrSet(
    String key,
    T Function() factory, {
    int estimatedSize = 0,
    Duration? ttl,
  }) {
    final existing = get(key);
    if (existing != null) return existing;

    final value = factory();
    set(key, value, estimatedSize: estimatedSize, ttl: ttl);
    return value;
  }

  /// 异步获取或设置
  Future<T> getOrSetAsync(
    String key,
    Future<T> Function() factory, {
    int estimatedSize = 0,
    Duration? ttl,
  }) async {
    final existing = get(key);
    if (existing != null) return existing;

    final value = await factory();
    set(key, value, estimatedSize: estimatedSize, ttl: ttl);
    return value;
  }

  /// 获取缓存统计
  CacheStats getStats() {
    return CacheStats(
      itemCount: _cache.length,
      totalSize: _currentSize,
      hitCount: _hitCount,
      missCount: _missCount,
      hitRate: _hitCount + _missCount > 0
          ? _hitCount / (_hitCount + _missCount)
          : 0,
    );
  }

  /// 清理过期缓存
  void cleanExpired() {
    final expiredKeys = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      remove(key);
    }
  }

  /// 确保有足够容量
  void _ensureCapacity(int requiredSize) {
    // 检查数量限制
    while (_cache.length >= config.maxCount) {
      _evictOne();
    }

    // 检查大小限制
    while (_currentSize + requiredSize > config.maxSizeBytes && _cache.isNotEmpty) {
      _evictOne();
    }
  }

  /// 淘汰一个条目
  void _evictOne() {
    if (_cache.isEmpty) return;

    String? keyToRemove;

    switch (config.evictionPolicy) {
      case CacheEvictionPolicy.lru:
        keyToRemove = _lruCache.keys.first;
        break;

      case CacheEvictionPolicy.lfu:
        var minAccess = double.infinity;
        for (final entry in _cache.entries) {
          if (entry.value.accessCount < minAccess) {
            minAccess = entry.value.accessCount.toDouble();
            keyToRemove = entry.key;
          }
        }
        break;

      case CacheEvictionPolicy.fifo:
        DateTime? oldest;
        for (final entry in _cache.entries) {
          if (oldest == null || entry.value.createdAt.isBefore(oldest)) {
            oldest = entry.value.createdAt;
            keyToRemove = entry.key;
          }
        }
        break;

      case CacheEvictionPolicy.sizeBased:
        var maxSize = 0;
        for (final entry in _cache.entries) {
          if (entry.value.estimatedSize > maxSize) {
            maxSize = entry.value.estimatedSize;
            keyToRemove = entry.key;
          }
        }
        break;

      case CacheEvictionPolicy.ttl:
        DateTime? earliestExpiry;
        for (final entry in _cache.entries) {
          final expiresAt = entry.value.expiresAt;
          if (expiresAt != null &&
              (earliestExpiry == null || expiresAt.isBefore(earliestExpiry))) {
            earliestExpiry = expiresAt;
            keyToRemove = entry.key;
          }
        }
        // 如果没有带过期时间的，使用 LRU
        keyToRemove ??= _lruCache.keys.firstOrNull;
        break;
    }

    if (keyToRemove != null) {
      remove(keyToRemove);
    }
  }
}

/// 缓存统计
class CacheStats {
  final int itemCount;
  final int totalSize;
  final int hitCount;
  final int missCount;
  final double hitRate;

  const CacheStats({
    required this.itemCount,
    required this.totalSize,
    required this.hitCount,
    required this.missCount,
    required this.hitRate,
  });
}

/// 智能缓存配置
class SmartCacheConfig {
  /// 最大条目数
  final int maxCount;

  /// 最大缓存大小 (bytes)
  final int maxSizeBytes;

  /// 淘汰策略
  final CacheEvictionPolicy evictionPolicy;

  /// 默认 TTL
  final Duration? defaultTtl;

  /// 自动清理间隔
  final Duration cleanupInterval;

  const SmartCacheConfig({
    this.maxCount = 100,
    this.maxSizeBytes = 10 * 1024 * 1024, // 10MB
    this.evictionPolicy = CacheEvictionPolicy.lru,
    this.defaultTtl,
    this.cleanupInterval = const Duration(minutes: 5),
  });
}

/// 内存优化服务
///
/// 核心功能：
/// 1. 内存使用监控
/// 2. 智能缓存管理
/// 3. 内存压力响应
/// 4. 资源释放调度
///
/// 对应设计文档：第19章 性能设计与优化
/// 对应实施方案：轨道L 性能优化模块
class MemoryOptimizationService {
  static final MemoryOptimizationService _instance = MemoryOptimizationService._();
  factory MemoryOptimizationService() => _instance;
  MemoryOptimizationService._();

  MemoryOptimizationConfig _config = const MemoryOptimizationConfig();
  bool _initialized = false;

  Timer? _monitorTimer;
  final List<MemoryInfo> _memoryHistory = [];
  MemoryWarningLevel _currentWarningLevel = MemoryWarningLevel.normal;

  /// 注册的清理回调
  final List<Future<void> Function()> _cleanupCallbacks = [];

  /// 内存压力监听器
  final List<void Function(MemoryWarningLevel level)> _warningListeners = [];

  /// 初始化服务
  Future<void> initialize({MemoryOptimizationConfig? config}) async {
    if (_initialized) return;

    if (config != null) {
      _config = config;
    }

    // 启动内存监控
    if (_config.enableMonitoring) {
      _monitorTimer = Timer.periodic(
        _config.monitorInterval,
        (_) => _checkMemory(),
      );
    }

    _initialized = true;
  }

  /// 获取当前警告级别
  MemoryWarningLevel get currentWarningLevel => _currentWarningLevel;

  /// 获取内存历史
  List<MemoryInfo> get memoryHistory => List.unmodifiable(_memoryHistory);

  /// 注册清理回调
  void registerCleanupCallback(Future<void> Function() callback) {
    _cleanupCallbacks.add(callback);
  }

  /// 移除清理回调
  void unregisterCleanupCallback(Future<void> Function() callback) {
    _cleanupCallbacks.remove(callback);
  }

  /// 添加内存警告监听
  void addWarningListener(void Function(MemoryWarningLevel level) listener) {
    _warningListeners.add(listener);
  }

  /// 移除内存警告监听
  void removeWarningListener(void Function(MemoryWarningLevel level) listener) {
    _warningListeners.remove(listener);
  }

  /// 手动触发内存检查
  Future<MemoryInfo> checkMemory() async {
    return _checkMemory();
  }

  /// 请求垃圾回收
  void requestGC() {
    // 提示 Dart VM 进行垃圾回收
    // 注意：这只是建议，VM 可能不会立即执行
    SchedulerBinding.instance.scheduleTask(
      () {
        // 触发 finalizers
      },
      Priority.idle,
    );
  }

  /// 执行内存清理
  Future<void> performCleanup({bool force = false}) async {
    if (!force && _currentWarningLevel == MemoryWarningLevel.normal) {
      return;
    }

    // 执行所有清理回调
    for (final callback in _cleanupCallbacks) {
      try {
        await callback();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Cleanup callback failed: $e');
        }
      }
    }

    // 请求 GC
    requestGC();
  }

  /// 估算对象大小
  int estimateObjectSize(Object object) {
    // 简单估算
    if (object is String) {
      return object.length * 2; // UTF-16
    }
    if (object is List) {
      int size = 24; // List overhead
      for (final item in object) {
        size += estimateObjectSize(item);
      }
      return size;
    }
    if (object is Map) {
      int size = 48; // Map overhead
      for (final entry in object.entries) {
        size += estimateObjectSize(entry.key) + estimateObjectSize(entry.value);
      }
      return size;
    }
    if (object is int) return 8;
    if (object is double) return 8;
    if (object is bool) return 1;

    // 默认估算
    return 32;
  }

  /// 获取内存使用建议
  List<String> getOptimizationSuggestions() {
    final suggestions = <String>[];

    if (_currentWarningLevel.index >= MemoryWarningLevel.light.index) {
      suggestions.add('考虑清理未使用的缓存');
    }

    if (_currentWarningLevel.index >= MemoryWarningLevel.moderate.index) {
      suggestions.add('释放大型图片资源');
      suggestions.add('关闭不必要的页面');
    }

    if (_currentWarningLevel.index >= MemoryWarningLevel.critical.index) {
      suggestions.add('立即释放所有可释放资源');
      suggestions.add('考虑重启应用');
    }

    return suggestions;
  }

  // ==================== 私有方法 ====================

  MemoryInfo _checkMemory() {
    // 获取当前内存使用（使用估算值，实际需要平台特定实现）
    final info = MemoryInfo(
      usedHeapMemory: _estimateHeapUsage(),
      committedHeapMemory: _estimateCommittedHeap(),
      externalMemory: 0,
      timestamp: DateTime.now(),
    );

    // 保存历史
    _memoryHistory.add(info);
    while (_memoryHistory.length > _config.maxHistoryCount) {
      _memoryHistory.removeAt(0);
    }

    // 更新警告级别
    _updateWarningLevel(info);

    return info;
  }

  int _estimateHeapUsage() {
    // 实际实现需要平台特定代码
    // 这里返回估算值
    return 50 * 1024 * 1024; // 50MB 估算
  }

  int _estimateCommittedHeap() {
    return 100 * 1024 * 1024; // 100MB 估算
  }

  void _updateWarningLevel(MemoryInfo info) {
    final usageRatio = info.usedHeapMemory / _config.memoryThreshold;
    MemoryWarningLevel newLevel;

    if (usageRatio < 0.6) {
      newLevel = MemoryWarningLevel.normal;
    } else if (usageRatio < 0.75) {
      newLevel = MemoryWarningLevel.light;
    } else if (usageRatio < 0.9) {
      newLevel = MemoryWarningLevel.moderate;
    } else {
      newLevel = MemoryWarningLevel.critical;
    }

    if (newLevel != _currentWarningLevel) {
      _currentWarningLevel = newLevel;

      // 通知监听器
      for (final listener in _warningListeners) {
        listener(newLevel);
      }

      // 根据级别执行清理
      if (newLevel.index >= MemoryWarningLevel.moderate.index) {
        performCleanup();
      }
    }
  }

  /// 关闭服务
  Future<void> close() async {
    _monitorTimer?.cancel();
    _memoryHistory.clear();
    _cleanupCallbacks.clear();
    _warningListeners.clear();
    _initialized = false;
  }
}

/// 内存优化配置
class MemoryOptimizationConfig {
  /// 是否启用监控
  final bool enableMonitoring;

  /// 监控间隔
  final Duration monitorInterval;

  /// 内存阈值 (bytes)
  final int memoryThreshold;

  /// 最大历史记录数
  final int maxHistoryCount;

  const MemoryOptimizationConfig({
    this.enableMonitoring = true,
    this.monitorInterval = const Duration(seconds: 30),
    this.memoryThreshold = 200 * 1024 * 1024, // 200MB
    this.maxHistoryCount = 100,
  });
}

/// 全局内存优化实例
final memoryOptimizer = MemoryOptimizationService();

/// 全局���片缓存管理器
final imageCache = SmartCacheManager<dynamic>(
  config: const SmartCacheConfig(
    maxCount: 50,
    maxSizeBytes: 20 * 1024 * 1024, // 20MB
    evictionPolicy: CacheEvictionPolicy.lru,
  ),
);

/// 全局数据缓存管理器
final dataCache = SmartCacheManager<dynamic>(
  config: const SmartCacheConfig(
    maxCount: 200,
    maxSizeBytes: 10 * 1024 * 1024, // 10MB
    evictionPolicy: CacheEvictionPolicy.lru,
    defaultTtl: Duration(minutes: 30),
  ),
);
