/// 学习缓存服务
///
/// 管理意图识别的学习缓存，用于：
/// - 缓存高置信度的LLM识别结果
/// - 加速后续相似请求的识别
/// - 支持用户纠正学习
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 学习模式
///
/// 表示一个已学习的意图模式
class LearnedPattern {
  /// 意图类型名称
  final String intentTypeName;

  /// 提取的实体
  final Map<String, dynamic> entities;

  /// 学习时间
  final DateTime learnedAt;

  /// 命中次数
  final int hitCount;

  /// 是否来自用户纠正
  final bool isUserCorrection;

  LearnedPattern({
    required this.intentTypeName,
    required this.entities,
    required this.learnedAt,
    this.hitCount = 0,
    this.isUserCorrection = false,
  });

  factory LearnedPattern.fromJson(Map<String, dynamic> json) {
    return LearnedPattern(
      intentTypeName: json['intentType'] as String? ?? 'unknown',
      entities: json['entities'] as Map<String, dynamic>? ?? {},
      learnedAt: DateTime.parse(json['learnedAt'] as String),
      hitCount: json['hitCount'] as int? ?? 0,
      isUserCorrection: json['isUserCorrection'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intentType': intentTypeName,
      'entities': entities,
      'learnedAt': learnedAt.toIso8601String(),
      'hitCount': hitCount,
      'isUserCorrection': isUserCorrection,
    };
  }

  /// 创建一个增加命中次数的副本
  LearnedPattern withIncrementedHitCount() {
    return LearnedPattern(
      intentTypeName: intentTypeName,
      entities: entities,
      learnedAt: learnedAt,
      hitCount: hitCount + 1,
      isUserCorrection: isUserCorrection,
    );
  }

  @override
  String toString() => 'LearnedPattern($intentTypeName, hits=$hitCount)';
}

/// 学习缓存匹配结果
class CacheMatchResult {
  /// 匹配的模式
  final LearnedPattern pattern;

  /// 匹配置信度 (0.0 - 1.0)
  final double confidence;

  /// 是否精确匹配
  final bool isExactMatch;

  CacheMatchResult({
    required this.pattern,
    required this.confidence,
    this.isExactMatch = false,
  });
}

/// 学习缓存服务接口
///
/// 定义学习缓存的核心操作契约
abstract class LearningCacheService {
  /// 加载缓存
  ///
  /// 从持久化存储加载已学习的模式
  Future<void> load();

  /// 是否已加载
  bool get isLoaded;

  /// 缓存数量
  int get size;

  /// 精确匹配
  ///
  /// [normalizedInput] 标准化后的输入
  /// 返回匹配结果，未匹配返回 null
  CacheMatchResult? matchExact(String normalizedInput);

  /// 模糊匹配
  ///
  /// [normalizedInput] 标准化后的输入
  /// [similarityThreshold] 相似度阈值，默认0.85
  /// 返回最佳匹配结果，未匹配返回 null
  CacheMatchResult? matchFuzzy(
    String normalizedInput, {
    double similarityThreshold = 0.85,
  });

  /// 学习新模式
  ///
  /// [normalizedInput] 标准化后的输入
  /// [intentTypeName] 意图类型名称
  /// [entities] 提取的实体
  /// [isUserCorrection] 是否来自用户纠正
  Future<void> learn({
    required String normalizedInput,
    required String intentTypeName,
    required Map<String, dynamic> entities,
    bool isUserCorrection = false,
  });

  /// 移除指定模式
  ///
  /// [normalizedInput] 要移除的模式的key
  Future<void> remove(String normalizedInput);

  /// 清除所有缓存
  Future<void> clear();

  /// 获取所有缓存的key
  Iterable<String> get keys;

  /// 根据条件过滤并移除模式
  ///
  /// [predicate] 返回 true 的模式将被移除
  Future<int> removeWhere(bool Function(String key, LearnedPattern pattern) predicate);
}

/// 基于 SharedPreferences 的学习缓存实现
class SharedPreferencesLearningCache implements LearningCacheService {
  /// 存储 key
  static const String _storageKey = 'smart_intent_cache';

  /// 缓存数据
  final Map<String, LearnedPattern> _cache = {};

  /// 是否已加载
  bool _isLoaded = false;

  /// 输入验证器（可选）
  /// 返回 false 的输入将不会被学习
  final bool Function(String input)? inputValidator;

  SharedPreferencesLearningCache({
    this.inputValidator,
  });

  @override
  bool get isLoaded => _isLoaded;

  @override
  int get size => _cache.length;

  @override
  Iterable<String> get keys => _cache.keys;

  @override
  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_storageKey);

      if (cacheJson != null) {
        final cacheMap = jsonDecode(cacheJson) as Map<String, dynamic>;
        int skippedCount = 0;

        for (final entry in cacheMap.entries) {
          // 如果有验证器，跳过无效输入
          if (inputValidator != null && !inputValidator!(entry.key)) {
            skippedCount++;
            continue;
          }
          _cache[entry.key] = LearnedPattern.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }

        if (skippedCount > 0) {
          debugPrint('[LearningCache] 跳过了 $skippedCount 个无效模式');
          await _save();
        }

        debugPrint('[LearningCache] 加载了 ${_cache.length} 个学习模式');
      }
    } catch (e) {
      debugPrint('[LearningCache] 加载缓存失败: $e');
    }

    _isLoaded = true;
  }

  @override
  CacheMatchResult? matchExact(String normalizedInput) {
    final pattern = _cache[normalizedInput];
    if (pattern == null) return null;

    return CacheMatchResult(
      pattern: pattern,
      confidence: 0.9,
      isExactMatch: true,
    );
  }

  @override
  CacheMatchResult? matchFuzzy(
    String normalizedInput, {
    double similarityThreshold = 0.85,
  }) {
    CacheMatchResult? bestMatch;
    double bestSimilarity = 0;

    for (final entry in _cache.entries) {
      final distance = _levenshteinDistance(normalizedInput, entry.key);
      final maxLen = normalizedInput.length.clamp(1, 100);
      final similarity = 1 - (distance / maxLen);

      if (similarity >= similarityThreshold && similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatch = CacheMatchResult(
          pattern: entry.value,
          confidence: similarity * 0.95,
          isExactMatch: false,
        );
      }
    }

    return bestMatch;
  }

  @override
  Future<void> learn({
    required String normalizedInput,
    required String intentTypeName,
    required Map<String, dynamic> entities,
    bool isUserCorrection = false,
  }) async {
    // 验证输入
    if (inputValidator != null && !inputValidator!(normalizedInput)) {
      debugPrint('[LearningCache] 跳过学习无效输入: $normalizedInput');
      return;
    }

    final pattern = LearnedPattern(
      intentTypeName: intentTypeName,
      entities: entities,
      learnedAt: DateTime.now(),
      hitCount: 1,
      isUserCorrection: isUserCorrection,
    );

    _cache[normalizedInput] = pattern;
    await _save();

    debugPrint('[LearningCache] 学习新模式: $normalizedInput → $intentTypeName');
  }

  @override
  Future<void> remove(String normalizedInput) async {
    if (_cache.remove(normalizedInput) != null) {
      await _save();
      debugPrint('[LearningCache] 移除模式: $normalizedInput');
    }
  }

  @override
  Future<void> clear() async {
    _cache.clear();
    await _save();
    debugPrint('[LearningCache] 缓存已清空');
  }

  @override
  Future<int> removeWhere(
    bool Function(String key, LearnedPattern pattern) predicate,
  ) async {
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (predicate(entry.key, entry.value)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      await _save();
      debugPrint('[LearningCache] 移除了 ${keysToRemove.length} 个模式');
    }

    return keysToRemove.length;
  }

  /// 保存缓存到持久化存储
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMap = _cache.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_storageKey, jsonEncode(cacheMap));
    } catch (e) {
      debugPrint('[LearningCache] 保存缓存失败: $e');
    }
  }

  /// 计算 Levenshtein 编辑距离
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        final cost = s1[i] == s2[j] ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }

      final temp = v0;
      v0 = v1;
      v1 = temp;
    }

    return v0[s2.length];
  }
}

/// 内存学习缓存（用于测试）
class InMemoryLearningCache implements LearningCacheService {
  final Map<String, LearnedPattern> _cache = {};
  bool _isLoaded = false;

  @override
  bool get isLoaded => _isLoaded;

  @override
  int get size => _cache.length;

  @override
  Iterable<String> get keys => _cache.keys;

  @override
  Future<void> load() async {
    _isLoaded = true;
  }

  @override
  CacheMatchResult? matchExact(String normalizedInput) {
    final pattern = _cache[normalizedInput];
    if (pattern == null) return null;

    return CacheMatchResult(
      pattern: pattern,
      confidence: 0.9,
      isExactMatch: true,
    );
  }

  @override
  CacheMatchResult? matchFuzzy(
    String normalizedInput, {
    double similarityThreshold = 0.85,
  }) {
    // 简化实现，只做精确匹配
    return matchExact(normalizedInput);
  }

  @override
  Future<void> learn({
    required String normalizedInput,
    required String intentTypeName,
    required Map<String, dynamic> entities,
    bool isUserCorrection = false,
  }) async {
    _cache[normalizedInput] = LearnedPattern(
      intentTypeName: intentTypeName,
      entities: entities,
      learnedAt: DateTime.now(),
      hitCount: 1,
      isUserCorrection: isUserCorrection,
    );
  }

  @override
  Future<void> remove(String normalizedInput) async {
    _cache.remove(normalizedInput);
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  @override
  Future<int> removeWhere(
    bool Function(String key, LearnedPattern pattern) predicate,
  ) async {
    final keysToRemove = _cache.entries
        .where((e) => predicate(e.key, e.value))
        .map((e) => e.key)
        .toList();

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    return keysToRemove.length;
  }
}
