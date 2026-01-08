import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

// ==================== 意图学习数据模型 ====================

/// 意图学习数据
class IntentLearningData {
  final String userId;
  final String input;
  final String recognizedIntent;
  final String? correctedIntent;
  final double confidence;
  final IntentContext context;
  final DateTime timestamp;

  IntentLearningData({
    required this.userId,
    required this.input,
    required this.recognizedIntent,
    this.correctedIntent,
    required this.confidence,
    this.context = const IntentContext(),
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get wasCorrect =>
      correctedIntent == null || correctedIntent == recognizedIntent;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'input': input,
        'recognized_intent': recognizedIntent,
        'corrected_intent': correctedIntent,
        'confidence': confidence,
        'context': context.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };
}

/// 意图上下文
class IntentContext {
  final int? hour;
  final int? dayOfWeek;
  final String? previousIntent;
  final String? currentPage;
  final Map<String, dynamic> extra;

  const IntentContext({
    this.hour,
    this.dayOfWeek,
    this.previousIntent,
    this.currentPage,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'day_of_week': dayOfWeek,
        'previous_intent': previousIntent,
        'current_page': currentPage,
        ...extra,
      };
}

/// 规则来源
enum IntentRuleSource {
  userLearned, // 从用户行为学习
  systemDefault, // 系统默认规则
}

/// 预测来源
enum IntentPredictionSource {
  learnedRule, // 学习规则命中
  profileInference, // 画像推理
  fallback, // 兜底策略
}

/// 学习阶段
enum IntentLearningStage {
  coldStart, // 冷启动
  collecting, // 样本收集中
  active, // 正常运行
}

/// 意图规则
class VoiceIntentRule {
  final String ruleId;
  final String pattern;
  final double confidence;
  final IntentRuleSource source;
  final String targetIntent;
  final List<String> triggerKeywords;
  final Map<int, double> hourPreferences;
  final int sampleCount;

  VoiceIntentRule({
    required this.ruleId,
    required this.pattern,
    required this.confidence,
    required this.source,
    required this.targetIntent,
    this.triggerKeywords = const [],
    this.hourPreferences = const {},
    this.sampleCount = 0,
  });

  bool matches(String input) {
    final lowerInput = input.toLowerCase();
    return triggerKeywords.any((k) => lowerInput.contains(k.toLowerCase()));
  }

  double getHourBoost(int hour) {
    return hourPreferences[hour] ?? 1.0;
  }

  VoiceIntentRule copyWith({
    double? confidence,
    List<String>? triggerKeywords,
    int? sampleCount,
  }) {
    return VoiceIntentRule(
      ruleId: ruleId,
      pattern: pattern,
      confidence: confidence ?? this.confidence,
      source: source,
      targetIntent: targetIntent,
      triggerKeywords: triggerKeywords ?? this.triggerKeywords,
      hourPreferences: hourPreferences,
      sampleCount: sampleCount ?? this.sampleCount,
    );
  }
}

// ==================== 用户意图画像 ====================

/// 用户意图画像
class UserIntentProfile {
  final String userId;
  final Map<String, int> intentFrequency;
  final Map<String, List<String>> intentKeywords;
  final Map<int, Map<String, double>> hourIntentDistribution;
  final List<String> frequentPhrases;
  final DateTime lastUpdated;

  UserIntentProfile({
    required this.userId,
    required this.intentFrequency,
    required this.intentKeywords,
    required this.hourIntentDistribution,
    required this.frequentPhrases,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// 获取意图先验概率
  double getIntentPrior(String intent) {
    final total = intentFrequency.values.fold(0, (a, b) => a + b);
    if (total == 0) return 0.1;
    return (intentFrequency[intent] ?? 0) / total;
  }

  /// 获取当前时段的意图偏好
  String? getPreferredIntentForHour(int hour) {
    final distribution = hourIntentDistribution[hour];
    if (distribution == null || distribution.isEmpty) return null;

    return distribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

/// 预测结果
class IntentPredictionResult {
  final VoiceIntentRule? rule;
  final double confidence;
  final IntentPredictionSource source;

  const IntentPredictionResult({
    this.rule,
    required this.confidence,
    required this.source,
  });
}

// ==================== 意图学习服务 ====================

/// 意图学习服务
class VoiceIntentLearningService {
  final IntentDataStore _dataStore;
  final Map<String, UserIntentProfile> _profileCache = {};
  final List<VoiceIntentRule> _learnedRules = [];

  // 配置
  static const int _minSamplesForLearning = 10;
  static const double _keywordThreshold = 0.3;

  String get moduleId => 'voice_intent_learning';
  IntentLearningStage stage = IntentLearningStage.coldStart;
  double accuracy = 0.0;

  VoiceIntentLearningService({
    IntentDataStore? dataStore,
  }) : _dataStore = dataStore ?? InMemoryIntentDataStore();

  /// 学习意图数据
  Future<void> learn(IntentLearningData data) async {
    await _dataStore.saveData(data);

    // 更新用户画像
    await _updateUserProfile(data.userId);

    // 检查学习阶段
    final sampleCount = await _dataStore.getDataCount(userId: data.userId);
    if (sampleCount >= _minSamplesForLearning &&
        stage == IntentLearningStage.coldStart) {
      stage = IntentLearningStage.collecting;
    }

    if (sampleCount >= _minSamplesForLearning * 2) {
      await _triggerRuleLearning(data.userId);
      stage = IntentLearningStage.active;
    }
  }

  /// 更新用户画像
  Future<void> _updateUserProfile(String userId) async {
    final allData = await _dataStore.getUserData(userId, months: 6);
    if (allData.isEmpty) return;

    // 统计意图频率
    final intentFrequency = <String, int>{};
    for (final d in allData) {
      final intent = d.correctedIntent ?? d.recognizedIntent;
      intentFrequency[intent] = (intentFrequency[intent] ?? 0) + 1;
    }

    // 提取意图关键词
    final intentKeywords = <String, List<String>>{};
    final byIntent =
        groupBy(allData, (d) => d.correctedIntent ?? d.recognizedIntent);
    for (final entry in byIntent.entries) {
      intentKeywords[entry.key] = _extractKeywords(
        entry.value.map((d) => d.input).toList(),
      );
    }

    // 统计时段意图分布
    final hourIntentDistribution = <int, Map<String, double>>{};
    for (final d in allData) {
      final hour = d.context.hour ?? d.timestamp.hour;
      final intent = d.correctedIntent ?? d.recognizedIntent;

      hourIntentDistribution.putIfAbsent(hour, () => {});
      hourIntentDistribution[hour]![intent] =
          (hourIntentDistribution[hour]![intent] ?? 0) + 1;
    }

    // 归一化时段分布
    for (final hourEntry in hourIntentDistribution.entries) {
      final total = hourEntry.value.values.fold(0.0, (a, b) => a + b);
      if (total > 0) {
        for (final intent in hourEntry.value.keys) {
          hourIntentDistribution[hourEntry.key]![intent] =
              hourIntentDistribution[hourEntry.key]![intent]! / total;
        }
      }
    }

    // 提取高频短语
    final allInputs = allData.map((d) => d.input).toList();
    final frequentPhrases = _extractFrequentPhrases(allInputs);

    _profileCache[userId] = UserIntentProfile(
      userId: userId,
      intentFrequency: intentFrequency,
      intentKeywords: intentKeywords,
      hourIntentDistribution: hourIntentDistribution,
      frequentPhrases: frequentPhrases,
    );
  }

  List<String> _extractKeywords(List<String> inputs) {
    final wordFreq = <String, int>{};
    for (final input in inputs) {
      final words = input.toLowerCase().split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length >= 2) {
          wordFreq[word] = (wordFreq[word] ?? 0) + 1;
        }
      }
    }

    final threshold = (inputs.length * _keywordThreshold).ceil();
    return wordFreq.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .take(10)
        .toList();
  }

  List<String> _extractFrequentPhrases(List<String> inputs) {
    final phraseCounts = <String, int>{};
    for (final input in inputs) {
      final words = input.split(RegExp(r'\s+'));
      for (int i = 0; i < words.length - 1; i++) {
        final phrase = '${words[i]} ${words[i + 1]}';
        phraseCounts[phrase] = (phraseCounts[phrase] ?? 0) + 1;
      }
    }

    return phraseCounts.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .take(20)
        .toList();
  }

  /// 触发规则学习
  Future<void> _triggerRuleLearning(String userId) async {
    final profile = _profileCache[userId];
    if (profile == null) return;

    _learnedRules.clear();

    // 为每个意图生成规则
    for (final entry in profile.intentKeywords.entries) {
      if (entry.value.isNotEmpty) {
        final rule = VoiceIntentRule(
          ruleId: '${userId}_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
          pattern: entry.value.join('|'),
          confidence: _calculateRuleConfidence(entry.key, profile),
          source: IntentRuleSource.userLearned,
          targetIntent: entry.key,
          triggerKeywords: entry.value,
          hourPreferences: _getHourPreferences(entry.key, profile),
          sampleCount: profile.intentFrequency[entry.key] ?? 0,
        );

        _learnedRules.add(rule);
      }
    }

    debugPrint('Learned ${_learnedRules.length} intent rules for user: $userId');
  }

  double _calculateRuleConfidence(String intent, UserIntentProfile profile) {
    final prior = profile.getIntentPrior(intent);
    final sampleCount = profile.intentFrequency[intent] ?? 0;
    double confidence = 0.5 + prior * 0.3;
    if (sampleCount >= 10) confidence += 0.1;
    if (sampleCount >= 20) confidence += 0.1;
    return confidence.clamp(0.0, 1.0);
  }

  Map<int, double> _getHourPreferences(String intent, UserIntentProfile profile) {
    final prefs = <int, double>{};
    for (final hourEntry in profile.hourIntentDistribution.entries) {
      final intentPref = hourEntry.value[intent];
      if (intentPref != null) {
        prefs[hourEntry.key] = intentPref;
      }
    }
    return prefs;
  }

  /// 预测意图
  Future<IntentPredictionResult> predict(
    String input, {
    String? userId,
    int? hour,
  }) async {
    final effectiveHour = hour ?? DateTime.now().hour;

    // 1. 匹配学习的规则
    VoiceIntentRule? bestRule;
    double bestConfidence = 0;

    for (final rule in _learnedRules) {
      if (rule.matches(input)) {
        final hourBoost = rule.getHourBoost(effectiveHour);
        final adjustedConfidence = rule.confidence * hourBoost;

        if (adjustedConfidence > bestConfidence) {
          bestConfidence = adjustedConfidence;
          bestRule = rule;
        }
      }
    }

    if (bestRule != null && bestConfidence >= 0.7) {
      return IntentPredictionResult(
        rule: bestRule,
        confidence: bestConfidence,
        source: IntentPredictionSource.learnedRule,
      );
    }

    // 2. 使用用户画像推断
    if (userId != null) {
      final profile = _profileCache[userId];
      if (profile != null) {
        final preferredIntent = profile.getPreferredIntentForHour(effectiveHour);
        if (preferredIntent != null) {
          return IntentPredictionResult(
            rule: VoiceIntentRule(
              ruleId: 'profile_infer',
              pattern: 'hour_preference',
              confidence: 0.6,
              source: IntentRuleSource.userLearned,
              targetIntent: preferredIntent,
            ),
            confidence: 0.6,
            source: IntentPredictionSource.profileInference,
          );
        }
      }
    }

    // 3. 兜底
    return const IntentPredictionResult(
      rule: null,
      confidence: 0.0,
      source: IntentPredictionSource.fallback,
    );
  }

  /// 用户反馈
  Future<void> feedback(IntentLearningData data, bool positive) async {
    if (!positive && data.correctedIntent != null) {
      final correctedData = IntentLearningData(
        userId: data.userId,
        input: data.input,
        recognizedIntent: data.recognizedIntent,
        correctedIntent: data.correctedIntent,
        confidence: 1.0,
        context: data.context,
        timestamp: DateTime.now(),
      );

      await _dataStore.saveData(correctedData);

      // 更新相关规则的置信度
      for (int i = 0; i < _learnedRules.length; i++) {
        if (_learnedRules[i].targetIntent == data.recognizedIntent) {
          _learnedRules[i] = _learnedRules[i].copyWith(
            confidence: _learnedRules[i].confidence * 0.9,
          );
        }
      }
    }

    await _updateAccuracy(data.userId);
  }

  Future<void> _updateAccuracy(String userId) async {
    final recentData = await _dataStore.getUserData(userId, months: 1);
    if (recentData.isEmpty) return;

    final correct = recentData.where((d) => d.wasCorrect).length;
    accuracy = correct / recentData.length;
  }

  /// 导出规则
  Future<List<VoiceIntentRule>> exportRules() async {
    return List.unmodifiable(_learnedRules);
  }

  /// 获取统计信息
  Future<IntentLearningStats> getStats() async {
    return IntentLearningStats(
      moduleId: moduleId,
      stage: stage,
      accuracy: accuracy,
      rulesCount: _learnedRules.length,
      profilesCached: _profileCache.length,
    );
  }

  /// 获取用户画像
  Future<UserIntentProfile?> getUserProfile(String userId) async {
    return _profileCache[userId];
  }
}

/// 意图学习统计
class IntentLearningStats {
  final String moduleId;
  final IntentLearningStage stage;
  final double accuracy;
  final int rulesCount;
  final int profilesCached;

  const IntentLearningStats({
    required this.moduleId,
    required this.stage,
    required this.accuracy,
    required this.rulesCount,
    required this.profilesCached,
  });
}

// ==================== 数据存储 ====================

/// 意图数据存储接口
abstract class IntentDataStore {
  Future<void> saveData(IntentLearningData data);
  Future<List<IntentLearningData>> getUserData(String userId, {int? months});
  Future<int> getDataCount({String? userId});
}

/// 内存意图数据存储
class InMemoryIntentDataStore implements IntentDataStore {
  final List<IntentLearningData> _data = [];

  @override
  Future<void> saveData(IntentLearningData data) async {
    _data.add(data);
  }

  @override
  Future<List<IntentLearningData>> getUserData(
    String userId, {
    int? months,
  }) async {
    var result = _data.where((d) => d.userId == userId);

    if (months != null) {
      final cutoff = DateTime.now().subtract(Duration(days: months * 30));
      result = result.where((d) => d.timestamp.isAfter(cutoff));
    }

    return result.toList();
  }

  @override
  Future<int> getDataCount({String? userId}) async {
    if (userId == null) return _data.length;
    return _data.where((d) => d.userId == userId).length;
  }

  void clear() => _data.clear();
}
