import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// 缓存一致性策略
enum CacheConsistencyStrategy {
  /// Cache-Aside（旁路缓存）
  cacheAside,

  /// Write-Through（直写）
  writeThrough,

  /// Write-Behind（异步写）
  writeBehind,

  /// Read-Through（直读）
  readThrough,
}

/// 缓存条目
class CacheEntry<T> {
  /// 缓存键
  final String key;

  /// 缓存值
  final T value;

  /// 创建时间
  final DateTime createdAt;

  /// 过期时间
  final DateTime expiresAt;

  /// 最后访问时间
  DateTime lastAccessedAt;

  /// 版本号
  final int version;

  /// 数据哈希（用于一致性检查）
  final String? dataHash;

  /// 访问计数
  int accessCount;

  CacheEntry({
    required this.key,
    required this.value,
    required this.createdAt,
    required this.expiresAt,
    DateTime? lastAccessedAt,
    this.version = 1,
    this.dataHash,
    this.accessCount = 0,
  }) : lastAccessedAt = lastAccessedAt ?? createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeToLive => expiresAt.difference(DateTime.now());

  CacheEntry<T> touch() {
    lastAccessedAt = DateTime.now();
    accessCount++;
    return this;
  }
}

/// 延迟删除任务
class DelayedDeleteTask {
  final String key;
  final DateTime scheduledAt;
  final Duration delay;
  Timer? timer;

  DelayedDeleteTask({
    required this.key,
    required this.scheduledAt,
    required this.delay,
  });

  DateTime get executeAt => scheduledAt.add(delay);
}

/// 缓存写入选项
class CacheWriteOptions {
  /// 过期时间
  final Duration? ttl;

  /// 是否启用延迟双删
  final bool enableDelayedDoubleDelete;

  /// 延迟删除延迟时间
  final Duration delayedDeleteDelay;

  /// 是否等待数据库写入成功
  final bool waitForPersistence;

  const CacheWriteOptions({
    this.ttl,
    this.enableDelayedDoubleDelete = true,
    this.delayedDeleteDelay = const Duration(milliseconds: 500),
    this.waitForPersistence = true,
  });
}

/// 缓存一致性配置
class CacheConsistencyConfig {
  /// 默认过期时间
  final Duration defaultTtl;

  /// 最大缓存条目数
  final int maxEntries;

  /// 一致性策略
  final CacheConsistencyStrategy strategy;

  /// 是否启用版本控制
  final bool enableVersioning;

  /// 是否启用数据哈希验证
  final bool enableDataHash;

  /// 延迟双删默认延迟
  final Duration defaultDelayedDeleteDelay;

  /// 清理间隔
  final Duration cleanupInterval;

  /// 写入超时
  final Duration writeTimeout;

  /// 读取超时
  final Duration readTimeout;

  const CacheConsistencyConfig({
    this.defaultTtl = const Duration(minutes: 30),
    this.maxEntries = 10000,
    this.strategy = CacheConsistencyStrategy.cacheAside,
    this.enableVersioning = true,
    this.enableDataHash = true,
    this.defaultDelayedDeleteDelay = const Duration(milliseconds: 500),
    this.cleanupInterval = const Duration(minutes: 5),
    this.writeTimeout = const Duration(seconds: 5),
    this.readTimeout = const Duration(seconds: 3),
  });
}

/// 缓存一致性服务
///
/// 实现缓存一致性策略：
/// 1. Cache-Aside模式
/// 2. 延迟双删机制
/// 3. 版本控制
/// 4. 数据哈希验证
///
/// 对应设计文档：第33章 分布式一致性设计
/// 代码块：434
class CacheConsistencyService extends ChangeNotifier {
  static final CacheConsistencyService _instance = CacheConsistencyService._();
  factory CacheConsistencyService() => _instance;
  CacheConsistencyService._();

  CacheConsistencyConfig _config = const CacheConsistencyConfig();
  bool _initialized = false;

  // 缓存存储
  final Map<String, CacheEntry> _cache = {};

  // 版本映射
  final Map<String, int> _versions = {};

  // 延迟删除任务
  final Map<String, DelayedDeleteTask> _delayedDeleteTasks = {};

  // 写入缓冲区（用于Write-Behind策略）
  final Queue<_WriteBufferEntry> _writeBuffer = Queue();

  // 统计信息
  int _hits = 0;
  int _misses = 0;
  int _writes = 0;
  int _deletes = 0;
  int _evictions = 0;
  int _consistencyErrors = 0;

  Timer? _cleanupTimer;
  Timer? _writeBufferTimer;

  /// 初始化服务
  Future<void> initialize({CacheConsistencyConfig? config}) async {
    if (_initialized) return;

    _config = config ?? const CacheConsistencyConfig();

    // 启动定期清理
    _cleanupTimer = Timer.periodic(
      _config.cleanupInterval,
      (_) => _cleanup(),
    );

    // 如果是Write-Behind策略，启动写入缓冲处理
    if (_config.strategy == CacheConsistencyStrategy.writeBehind) {
      _writeBufferTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _flushWriteBuffer(),
      );
    }

    _initialized = true;

    if (kDebugMode) {
      debugPrint('CacheConsistencyService initialized with strategy: ${_config.strategy}');
    }
  }

  /// 获取缓存值（Cache-Aside模式）
  Future<T?> get<T>(
    String key, {
    Future<T?> Function()? loader,
    Duration? ttl,
  }) async {
    // 1. 先从缓存读取
    final entry = _cache[key];

    if (entry != null && !entry.isExpired) {
      _hits++;
      entry.touch();
      return entry.value as T;
    }

    _misses++;

    // 2. 缓存未命中，从数据源加载
    if (loader != null) {
      final value = await loader();
      if (value != null) {
        await set(key, value, ttl: ttl);
      }
      return value;
    }

    return null;
  }

  /// 设置缓存值
  Future<void> set<T>(
    String key,
    T value, {
    Duration? ttl,
  }) async {
    final effectiveTtl = ttl ?? _config.defaultTtl;

    // 检查缓存大小
    if (_cache.length >= _config.maxEntries) {
      _evict();
    }

    // 增加版本号
    final version = _getNextVersion(key);

    // 计算数据哈希
    String? dataHash;
    if (_config.enableDataHash) {
      dataHash = _computeHash(value);
    }

    final entry = CacheEntry<T>(
      key: key,
      value: value,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(effectiveTtl),
      version: version,
      dataHash: dataHash,
    );

    _cache[key] = entry;
    _writes++;

    notifyListeners();
  }

  /// 更新缓存（带一致性保证）
  ///
  /// 使用延迟双删策略确保缓存一致性：
  /// 1. 先删除缓存
  /// 2. 更新数据库
  /// 3. 延迟后再次删除缓存
  Future<void> updateWithConsistency<T>({
    required String key,
    required Future<T> Function() dbOperation,
    CacheWriteOptions? options,
  }) async {
    final effectiveOptions = options ?? const CacheWriteOptions();

    // 1. 先删除缓存
    await delete(key);

    // 2. 执行数据库操作
    final result = await dbOperation().timeout(_config.writeTimeout);

    // 3. 如果启用延迟双删，安排延迟删除
    if (effectiveOptions.enableDelayedDoubleDelete) {
      _scheduleDelayedDelete(key, effectiveOptions.delayedDeleteDelay);
    }

    // 4. 可选：更新缓存
    if (result != null) {
      await set(key, result, ttl: effectiveOptions.ttl);
    }
  }

  /// 删除缓存
  Future<void> delete(String key) async {
    _cache.remove(key);
    _deletes++;

    // 取消相关的延迟删除任务
    _cancelDelayedDelete(key);

    notifyListeners();
  }

  /// 批量删除
  Future<void> deleteMany(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }

  /// 删除匹配前缀的缓存
  Future<void> deleteByPrefix(String prefix) async {
    final keysToDelete = _cache.keys
        .where((k) => k.startsWith(prefix))
        .toList();

    for (final key in keysToDelete) {
      await delete(key);
    }
  }

  /// 验证缓存一致性
  Future<bool> validateConsistency<T>(
    String key,
    Future<T?> Function() dbLoader,
  ) async {
    final entry = _cache[key];
    if (entry == null) return true;

    final dbValue = await dbLoader();
    if (dbValue == null) {
      // 数据库中不存在，删除缓存
      await delete(key);
      return false;
    }

    if (_config.enableDataHash) {
      final dbHash = _computeHash(dbValue);
      if (entry.dataHash != dbHash) {
        _consistencyErrors++;
        await delete(key);
        return false;
      }
    }

    return true;
  }

  /// 获取缓存条目信息
  CacheEntry? getEntry(String key) => _cache[key];

  /// 检查缓存是否存在
  bool has(String key) {
    final entry = _cache[key];
    return entry != null && !entry.isExpired;
  }

  /// 获取当前版本
  int getVersion(String key) => _versions[key] ?? 0;

  /// 获取统计信息
  CacheStats getStats() {
    return CacheStats(
      hits: _hits,
      misses: _misses,
      writes: _writes,
      deletes: _deletes,
      evictions: _evictions,
      consistencyErrors: _consistencyErrors,
      entryCount: _cache.length,
      pendingDeletes: _delayedDeleteTasks.length,
    );
  }

  /// 清除所有缓存
  void clear() {
    _cache.clear();
    _versions.clear();
    _cancelAllDelayedDeletes();
    notifyListeners();
  }

  // ==================== 私有方法 ====================

  int _getNextVersion(String key) {
    final current = _versions[key] ?? 0;
    _versions[key] = current + 1;
    return current + 1;
  }

  String _computeHash(dynamic value) {
    final jsonString = jsonEncode(value);
    final bytes = utf8.encode(jsonString);
    return md5.convert(bytes).toString();
  }

  void _scheduleDelayedDelete(String key, Duration delay) {
    // 取消已存在的任务
    _cancelDelayedDelete(key);

    final task = DelayedDeleteTask(
      key: key,
      scheduledAt: DateTime.now(),
      delay: delay,
    );

    task.timer = Timer(delay, () {
      _executeDelayedDelete(key);
    });

    _delayedDeleteTasks[key] = task;

    if (kDebugMode) {
      debugPrint('Scheduled delayed delete for key: $key in ${delay.inMilliseconds}ms');
    }
  }

  void _executeDelayedDelete(String key) {
    _cache.remove(key);
    _delayedDeleteTasks.remove(key);
    _deletes++;

    if (kDebugMode) {
      debugPrint('Executed delayed delete for key: $key');
    }

    notifyListeners();
  }

  void _cancelDelayedDelete(String key) {
    final task = _delayedDeleteTasks.remove(key);
    task?.timer?.cancel();
  }

  void _cancelAllDelayedDeletes() {
    for (final task in _delayedDeleteTasks.values) {
      task.timer?.cancel();
    }
    _delayedDeleteTasks.clear();
  }

  /// 缓存淘汰（LRU策略）
  void _evict() {
    if (_cache.isEmpty) return;

    // 找到最久未访问的条目
    String? lruKey;
    DateTime? lruTime;

    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        _cache.remove(entry.key);
        _evictions++;
        return;
      }

      if (lruTime == null || entry.value.lastAccessedAt.isBefore(lruTime)) {
        lruKey = entry.key;
        lruTime = entry.value.lastAccessedAt;
      }
    }

    if (lruKey != null) {
      _cache.remove(lruKey);
      _evictions++;
    }
  }

  void _cleanup() {
    final expiredKeys = _cache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    if (expiredKeys.isNotEmpty && kDebugMode) {
      debugPrint('CacheConsistencyService: Cleaned up ${expiredKeys.length} expired entries');
    }
  }

  void _flushWriteBuffer() {
    // Write-Behind策略：异步批量写入数据库
    while (_writeBuffer.isNotEmpty) {
      final entry = _writeBuffer.removeFirst();
      // 实际实现中这里会调用数据库写入
      if (kDebugMode) {
        debugPrint('Flushing write buffer entry: ${entry.key}');
      }
    }
  }

  /// 关闭服务
  Future<void> close() async {
    _cleanupTimer?.cancel();
    _writeBufferTimer?.cancel();
    _cancelAllDelayedDeletes();
    _cache.clear();
    _versions.clear();
    _writeBuffer.clear();
    _initialized = false;
  }
}

class _WriteBufferEntry {
  final String key;
  final dynamic value;
  final DateTime timestamp;

  _WriteBufferEntry({
    required this.key,
    required this.value,
    required this.timestamp,
  });
}

/// 缓存统计信息
class CacheStats {
  final int hits;
  final int misses;
  final int writes;
  final int deletes;
  final int evictions;
  final int consistencyErrors;
  final int entryCount;
  final int pendingDeletes;

  const CacheStats({
    required this.hits,
    required this.misses,
    required this.writes,
    required this.deletes,
    required this.evictions,
    required this.consistencyErrors,
    required this.entryCount,
    required this.pendingDeletes,
  });

  double get hitRate {
    final total = hits + misses;
    return total > 0 ? hits / total : 0.0;
  }

  double get missRate {
    final total = hits + misses;
    return total > 0 ? misses / total : 0.0;
  }
}

/// 带缓存的数据访问装饰器
class CachedDataAccess<T> {
  final CacheConsistencyService _cache;
  final String _keyPrefix;
  final Duration _ttl;
  final Future<T?> Function(String id) _loader;
  final Future<void> Function(String id, T value) _saver;
  final Future<void> Function(String id) _deleter;

  CachedDataAccess({
    required CacheConsistencyService cache,
    required String keyPrefix,
    required Duration ttl,
    required Future<T?> Function(String id) loader,
    required Future<void> Function(String id, T value) saver,
    required Future<void> Function(String id) deleter,
  })  : _cache = cache,
        _keyPrefix = keyPrefix,
        _ttl = ttl,
        _loader = loader,
        _saver = saver,
        _deleter = deleter;

  String _getKey(String id) => '$_keyPrefix:$id';

  Future<T?> get(String id) async {
    return _cache.get<T>(
      _getKey(id),
      loader: () => _loader(id),
      ttl: _ttl,
    );
  }

  Future<void> save(String id, T value) async {
    await _cache.updateWithConsistency<T>(
      key: _getKey(id),
      dbOperation: () async {
        await _saver(id, value);
        return value;
      },
    );
  }

  Future<void> delete(String id) async {
    await _cache.updateWithConsistency<void>(
      key: _getKey(id),
      dbOperation: () async {
        await _deleter(id);
      },
    );
  }
}

/// 全局缓存一致性服务实例
final cacheConsistency = CacheConsistencyService();
