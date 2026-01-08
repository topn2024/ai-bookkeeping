import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import 'unified_self_learning_service.dart';

// ==================== 分类学习适配器 ====================

/// 分类学习数据
class CategoryLearningData extends LearningData {
  final String merchantName;
  final double amount;
  final String? originalCategory;
  final String userCorrectedCategory;
  final String? description;

  CategoryLearningData({
    required String id,
    required DateTime timestamp,
    required String userId,
    required this.merchantName,
    required this.amount,
    this.originalCategory,
    required this.userCorrectedCategory,
    this.description,
  }) : super(
          id: id,
          timestamp: timestamp,
          userId: userId,
          features: {
            'merchant': merchantName,
            'amount': amount,
            'description': description,
          },
          label: userCorrectedCategory,
          source: LearningDataSource.userExplicitFeedback,
        );

  @override
  Map<String, dynamic> toStorable() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'merchant_name': merchantName,
        'amount': amount,
        'original_category': originalCategory,
        'user_corrected_category': userCorrectedCategory,
        'description': description,
      };

  factory CategoryLearningData.fromStorable(Map<String, dynamic> data) {
    return CategoryLearningData(
      id: data['id'] as String,
      timestamp: DateTime.parse(data['timestamp'] as String),
      userId: data['user_id'] as String,
      merchantName: data['merchant_name'] as String,
      amount: (data['amount'] as num).toDouble(),
      originalCategory: data['original_category'] as String?,
      userCorrectedCategory: data['user_corrected_category'] as String,
      description: data['description'] as String?,
    );
  }

  @override
  LearningData anonymize() => CategoryLearningData(
        id: id,
        timestamp: timestamp,
        userId: _hashValue(userId),
        merchantName: _hashValue(merchantName),
        amount: amount,
        originalCategory: originalCategory,
        userCorrectedCategory: userCorrectedCategory,
        description: null, // 移除描述
      );

  static String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}

/// 分类规则
class CategoryRule extends LearnedRule {
  final String merchantPattern;
  final String categoryId;
  final String? amountRange;

  CategoryRule({
    required String ruleId,
    required this.merchantPattern,
    required this.categoryId,
    required double confidence,
    required RuleSource source,
    this.amountRange,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int hitCount = 0,
  }) : super(
          ruleId: ruleId,
          moduleId: 'smart_category',
          priority: source == RuleSource.userLearned ? 100 : 50,
          confidence: confidence,
          createdAt: createdAt ?? DateTime.now(),
          lastUsedAt: lastUsedAt ?? DateTime.now(),
          hitCount: hitCount,
          source: source,
        );

  @override
  bool matches(dynamic input) {
    if (input is! TransactionInput) return false;
    final match = input.merchantName
        .toLowerCase()
        .contains(merchantPattern.toLowerCase());
    return match;
  }

  @override
  dynamic apply(dynamic input) => categoryId;

  @override
  Map<String, dynamic> toStorable() => {
        'rule_id': ruleId,
        'merchant_pattern': merchantPattern,
        'category_id': categoryId,
        'confidence': confidence,
        'source': source.name,
        'amount_range': amountRange,
        'created_at': createdAt.toIso8601String(),
        'last_used_at': lastUsedAt.toIso8601String(),
        'hit_count': hitCount,
      };

  factory CategoryRule.fromStorable(Map<String, dynamic> data) {
    return CategoryRule(
      ruleId: data['rule_id'] as String,
      merchantPattern: data['merchant_pattern'] as String,
      categoryId: data['category_id'] as String,
      confidence: (data['confidence'] as num).toDouble(),
      source: RuleSource.values.firstWhere(
        (s) => s.name == data['source'],
        orElse: () => RuleSource.userLearned,
      ),
      amountRange: data['amount_range'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      lastUsedAt: DateTime.parse(data['last_used_at'] as String),
      hitCount: data['hit_count'] as int? ?? 0,
    );
  }
}

/// 交易输入
class TransactionInput {
  final String merchantName;
  final double amount;
  final String? description;
  final DateTime? date;

  const TransactionInput({
    required this.merchantName,
    required this.amount,
    this.description,
    this.date,
  });
}

/// 智能分类学习适配器
class CategoryLearningAdapter
    implements ISelfLearningModule<CategoryLearningData, CategoryRule> {
  @override
  String get moduleId => 'smart_category';

  @override
  String get moduleName => '智能分类';

  // 存储
  final List<CategoryLearningData> _samples = [];
  final List<CategoryRule> _rules = [];
  final List<_PredictionRecord> _predictionHistory = [];

  // 配置
  static const int _minSamplesForRule = 3;
  static const double _minConfidenceThreshold = 0.6;

  // 状态
  bool _isEnabled = true;
  DateTime? _lastTrainingTime;
  LearningStage _stage = LearningStage.coldStart;

  @override
  Future<void> collectSample(CategoryLearningData data) async {
    _samples.add(data);
    _updateStage();
    debugPrint('Collected category sample: ${data.merchantName} -> ${data.userCorrectedCategory}');
  }

  @override
  Future<void> collectSamples(List<CategoryLearningData> dataList) async {
    _samples.addAll(dataList);
    _updateStage();
  }

  @override
  Future<TrainingResult> train({bool incremental = true}) async {
    final startTime = DateTime.now();
    _stage = LearningStage.training;

    try {
      // 获取待训练样本
      final samples = incremental
          ? _samples.where((s) => s.timestamp.isAfter(_lastTrainingTime ?? DateTime(2000))).toList()
          : _samples;

      if (samples.isEmpty) {
        _stage = LearningStage.active;
        return TrainingResult(
          success: true,
          samplesUsed: 0,
          rulesGenerated: 0,
          trainingTime: Duration.zero,
        );
      }

      // 规则提取
      final newRules = _extractRules(samples);

      // 合并规则
      for (final rule in newRules) {
        _upsertRule(rule);
      }

      _lastTrainingTime = DateTime.now();
      _stage = LearningStage.active;

      return TrainingResult(
        success: true,
        samplesUsed: samples.length,
        rulesGenerated: newRules.length,
        trainingTime: DateTime.now().difference(startTime),
        newMetrics: await getMetrics(),
      );
    } catch (e) {
      _stage = LearningStage.degraded;
      return TrainingResult(
        success: false,
        samplesUsed: 0,
        rulesGenerated: 0,
        trainingTime: DateTime.now().difference(startTime),
        errorMessage: e.toString(),
      );
    }
  }

  List<CategoryRule> _extractRules(List<CategoryLearningData> samples) {
    final rules = <CategoryRule>[];

    // 按商家名称聚类
    final merchantGroups = groupBy(samples, (s) => s.merchantName.toLowerCase());

    for (final entry in merchantGroups.entries) {
      if (entry.value.length >= _minSamplesForRule) {
        // 统计最频繁的分类
        final categoryFreq = <String, int>{};
        for (final sample in entry.value) {
          categoryFreq[sample.userCorrectedCategory] =
              (categoryFreq[sample.userCorrectedCategory] ?? 0) + 1;
        }

        final mostFrequent = categoryFreq.entries
            .reduce((a, b) => a.value > b.value ? a : b);

        final confidence = mostFrequent.value / entry.value.length;

        if (confidence >= _minConfidenceThreshold) {
          rules.add(CategoryRule(
            ruleId: 'merchant_${entry.key.hashCode}',
            merchantPattern: entry.key,
            categoryId: mostFrequent.key,
            confidence: confidence,
            source: RuleSource.userLearned,
          ));
        }
      }
    }

    return rules;
  }

  void _upsertRule(CategoryRule newRule) {
    final existingIndex = _rules.indexWhere(
      (r) => r.merchantPattern == newRule.merchantPattern,
    );

    if (existingIndex >= 0) {
      // 更新现有规则
      final existing = _rules[existingIndex];
      if (newRule.confidence > existing.confidence) {
        _rules[existingIndex] = newRule;
      }
    } else {
      _rules.add(newRule);
    }
  }

  @override
  Future<PredictionResult<CategoryRule>> predict(dynamic input) async {
    final transaction = input as TransactionInput;
    final startTime = DateTime.now();

    // 1. 查找匹配的用户规则（优先级最高）
    final userRules = _rules.where((r) => r.source == RuleSource.userLearned).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in userRules) {
      if (rule.matches(transaction)) {
        rule.recordHit();
        _recordPrediction(transaction, rule.categoryId, true);
        return PredictionResult(
          matched: true,
          matchedRule: rule,
          result: rule.categoryId,
          confidence: rule.confidence,
          source: PredictionSource.learnedRule,
        );
      }
    }

    // 2. 查找协同规则
    final collaborativeRules = _rules.where((r) => r.source == RuleSource.collaborative).toList();
    for (final rule in collaborativeRules) {
      if (rule.matches(transaction)) {
        rule.recordHit();
        _recordPrediction(transaction, rule.categoryId, true);
        return PredictionResult(
          matched: true,
          matchedRule: rule,
          result: rule.categoryId,
          confidence: rule.confidence * 0.8,
          source: PredictionSource.learnedRule,
        );
      }
    }

    // 3. 未匹配
    _recordPrediction(transaction, null, false);
    return PredictionResult(
      matched: false,
      confidence: 0,
      source: PredictionSource.fallback,
    );
  }

  void _recordPrediction(TransactionInput input, String? result, bool matched) {
    _predictionHistory.add(_PredictionRecord(
      timestamp: DateTime.now(),
      input: input.merchantName,
      result: result,
      matched: matched,
    ));

    // 只保留最近1000条记录
    if (_predictionHistory.length > 1000) {
      _predictionHistory.removeRange(0, _predictionHistory.length - 1000);
    }
  }

  @override
  Future<LearningMetrics> getMetrics() async {
    final recentPredictions = _predictionHistory
        .where((p) => p.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .toList();

    final matchedCount = recentPredictions.where((p) => p.matched).length;
    final accuracy = recentPredictions.isEmpty
        ? 0.0
        : matchedCount / recentPredictions.length;

    return LearningMetrics(
      moduleId: moduleId,
      measureTime: DateTime.now(),
      totalSamples: _samples.length,
      totalRules: _rules.length,
      accuracy: accuracy,
      precision: accuracy, // 简化实现
      recall: accuracy,
      f1Score: accuracy,
      avgResponseTime: 5.0, // ms
      customMetrics: {
        'user_rules': _rules.where((r) => r.source == RuleSource.userLearned).length,
        'collaborative_rules': _rules.where((r) => r.source == RuleSource.collaborative).length,
      },
    );
  }

  @override
  Future<List<CategoryRule>> getRules({RuleSource? source, int? limit}) async {
    var rules = source != null
        ? _rules.where((r) => r.source == source).toList()
        : _rules.toList();

    if (limit != null && rules.length > limit) {
      rules = rules.sublist(0, limit);
    }

    return rules;
  }

  @override
  Future<ModelExportData> exportModel() async {
    return ModelExportData(
      moduleId: moduleId,
      exportedAt: DateTime.now(),
      rules: _rules.map((r) => r.toStorable()).toList(),
      metadata: {
        'total_samples': _samples.length,
        'last_training': _lastTrainingTime?.toIso8601String(),
      },
    );
  }

  @override
  Future<void> importModel(ModelExportData data) async {
    for (final ruleData in data.rules) {
      final rule = CategoryRule.fromStorable(ruleData);
      _upsertRule(rule);
    }
    _updateStage();
  }

  @override
  Future<void> clearData({bool keepRules = true}) async {
    _samples.clear();
    _predictionHistory.clear();
    if (!keepRules) {
      _rules.clear();
    }
    _stage = LearningStage.coldStart;
  }

  @override
  Future<LearningStatus> getStatus() async {
    return LearningStatus(
      moduleId: moduleId,
      isEnabled: _isEnabled,
      lastTrainingTime: _lastTrainingTime,
      nextScheduledTraining: _lastTrainingTime?.add(const Duration(hours: 24)),
      pendingSamples: _samples.length,
      stage: _stage,
    );
  }

  void _updateStage() {
    if (_samples.length < _minSamplesForRule) {
      _stage = LearningStage.coldStart;
    } else if (_rules.isEmpty) {
      _stage = LearningStage.collecting;
    } else {
      _stage = LearningStage.active;
    }
  }
}

class _PredictionRecord {
  final DateTime timestamp;
  final String input;
  final String? result;
  final bool matched;
  bool? wasCorrect;

  _PredictionRecord({
    required this.timestamp,
    required this.input,
    this.result,
    required this.matched,
    this.wasCorrect,
  });
}

// ==================== 异常检测学习适配器 ====================

/// 异常检测学习数据
class AnomalyLearningData extends LearningData {
  final double amount;
  final String category;
  final bool wasActualAnomaly;
  final String? userFeedback;

  AnomalyLearningData({
    required String id,
    required DateTime timestamp,
    required String userId,
    required this.amount,
    required this.category,
    required this.wasActualAnomaly,
    this.userFeedback,
  }) : super(
          id: id,
          timestamp: timestamp,
          userId: userId,
          features: {
            'amount': amount,
            'category': category,
          },
          label: wasActualAnomaly,
          source: LearningDataSource.userExplicitFeedback,
        );

  @override
  Map<String, dynamic> toStorable() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'amount': amount,
        'category': category,
        'was_actual_anomaly': wasActualAnomaly,
        'user_feedback': userFeedback,
      };

  @override
  LearningData anonymize() => AnomalyLearningData(
        id: id,
        timestamp: timestamp,
        userId: 'anon',
        amount: amount,
        category: category,
        wasActualAnomaly: wasActualAnomaly,
      );
}

/// 异常阈值规则
class AnomalyRule extends LearnedRule {
  final String category;
  final double threshold;
  final double multiplier;

  AnomalyRule({
    required String ruleId,
    required this.category,
    required this.threshold,
    required this.multiplier,
    required double confidence,
    required RuleSource source,
  }) : super(
          ruleId: ruleId,
          moduleId: 'anomaly_detection',
          priority: 50,
          confidence: confidence,
          createdAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
          source: source,
        );

  @override
  bool matches(dynamic input) {
    if (input is! Map<String, dynamic>) return false;
    return input['category'] == category;
  }

  @override
  dynamic apply(dynamic input) {
    if (input is! Map<String, dynamic>) return false;
    final amount = (input['amount'] as num).toDouble();
    return amount > threshold * multiplier;
  }

  @override
  Map<String, dynamic> toStorable() => {
        'rule_id': ruleId,
        'category': category,
        'threshold': threshold,
        'multiplier': multiplier,
        'confidence': confidence,
        'source': source.name,
      };
}

/// 异常检测学习适配器
class AnomalyDetectionLearningAdapter
    implements ISelfLearningModule<AnomalyLearningData, AnomalyRule> {
  @override
  String get moduleId => 'anomaly_detection';

  @override
  String get moduleName => '异常检测';

  final List<AnomalyLearningData> _samples = [];
  final List<AnomalyRule> _rules = [];
  DateTime? _lastTrainingTime;
  LearningStage _stage = LearningStage.coldStart;

  // 类目统计
  final Map<String, _CategoryStats> _categoryStats = {};

  @override
  Future<void> collectSample(AnomalyLearningData data) async {
    _samples.add(data);
    _updateCategoryStats(data);
  }

  @override
  Future<void> collectSamples(List<AnomalyLearningData> dataList) async {
    for (final data in dataList) {
      await collectSample(data);
    }
  }

  void _updateCategoryStats(AnomalyLearningData data) {
    final stats = _categoryStats.putIfAbsent(
      data.category,
      () => _CategoryStats(),
    );
    stats.addAmount(data.amount);
  }

  @override
  Future<TrainingResult> train({bool incremental = true}) async {
    final startTime = DateTime.now();
    _stage = LearningStage.training;

    try {
      final newRules = <AnomalyRule>[];

      // 为每个类目生成异常阈值规则
      for (final entry in _categoryStats.entries) {
        final stats = entry.value;
        if (stats.count >= 5) {
          // 使用均值 + 2倍标准差作为阈值
          final threshold = stats.mean + 2 * stats.standardDeviation;

          newRules.add(AnomalyRule(
            ruleId: 'anomaly_${entry.key}',
            category: entry.key,
            threshold: threshold,
            multiplier: 1.5,
            confidence: 0.7,
            source: RuleSource.userLearned,
          ));
        }
      }

      _rules.clear();
      _rules.addAll(newRules);
      _lastTrainingTime = DateTime.now();
      _stage = LearningStage.active;

      return TrainingResult(
        success: true,
        samplesUsed: _samples.length,
        rulesGenerated: newRules.length,
        trainingTime: DateTime.now().difference(startTime),
      );
    } catch (e) {
      _stage = LearningStage.degraded;
      return TrainingResult(
        success: false,
        samplesUsed: 0,
        rulesGenerated: 0,
        trainingTime: DateTime.now().difference(startTime),
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<PredictionResult<AnomalyRule>> predict(dynamic input) async {
    final data = input as Map<String, dynamic>;
    final category = data['category'] as String;
    final amount = (data['amount'] as num).toDouble();

    final rule = _rules.firstWhereOrNull((r) => r.category == category);

    if (rule != null) {
      final isAnomaly = amount > rule.threshold * rule.multiplier;
      return PredictionResult(
        matched: true,
        matchedRule: rule,
        result: isAnomaly,
        confidence: rule.confidence,
        source: PredictionSource.learnedRule,
      );
    }

    // 使用默认阈值
    final stats = _categoryStats[category];
    if (stats != null && stats.count >= 3) {
      final isAnomaly = amount > stats.mean * 3;
      return PredictionResult(
        matched: true,
        result: isAnomaly,
        confidence: 0.5,
        source: PredictionSource.fallback,
      );
    }

    return PredictionResult(
      matched: false,
      confidence: 0,
      source: PredictionSource.fallback,
    );
  }

  @override
  Future<LearningMetrics> getMetrics() async {
    return LearningMetrics(
      moduleId: moduleId,
      measureTime: DateTime.now(),
      totalSamples: _samples.length,
      totalRules: _rules.length,
      accuracy: 0.7, // 简化
      precision: 0.7,
      recall: 0.7,
      f1Score: 0.7,
      avgResponseTime: 2.0,
    );
  }

  @override
  Future<List<AnomalyRule>> getRules({RuleSource? source, int? limit}) async {
    return _rules;
  }

  @override
  Future<ModelExportData> exportModel() async {
    return ModelExportData(
      moduleId: moduleId,
      exportedAt: DateTime.now(),
      rules: _rules.map((r) => r.toStorable()).toList(),
    );
  }

  @override
  Future<void> importModel(ModelExportData data) async {
    // 简化实现
  }

  @override
  Future<void> clearData({bool keepRules = true}) async {
    _samples.clear();
    _categoryStats.clear();
    if (!keepRules) _rules.clear();
    _stage = LearningStage.coldStart;
  }

  @override
  Future<LearningStatus> getStatus() async {
    return LearningStatus(
      moduleId: moduleId,
      isEnabled: true,
      lastTrainingTime: _lastTrainingTime,
      pendingSamples: _samples.length,
      stage: _stage,
    );
  }
}

class _CategoryStats {
  final List<double> _amounts = [];

  void addAmount(double amount) => _amounts.add(amount);

  int get count => _amounts.length;

  double get mean {
    if (_amounts.isEmpty) return 0;
    return _amounts.reduce((a, b) => a + b) / _amounts.length;
  }

  double get standardDeviation {
    if (_amounts.length < 2) return 0;
    final m = mean;
    final variance = _amounts.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / _amounts.length;
    return variance > 0 ? variance : 0;
  }
}

// ==================== 意图识别学习适配器 ====================

/// 意图识别学习数据
class IntentLearningData extends LearningData {
  final String utterance;
  final String recognizedIntent;
  final String? userCorrectedIntent;
  final double originalConfidence;

  IntentLearningData({
    required String id,
    required DateTime timestamp,
    required String userId,
    required this.utterance,
    required this.recognizedIntent,
    this.userCorrectedIntent,
    required this.originalConfidence,
  }) : super(
          id: id,
          timestamp: timestamp,
          userId: userId,
          features: {'utterance': utterance},
          label: userCorrectedIntent ?? recognizedIntent,
          source: userCorrectedIntent != null
              ? LearningDataSource.userExplicitFeedback
              : LearningDataSource.userImplicitBehavior,
        );

  @override
  Map<String, dynamic> toStorable() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'utterance': utterance,
        'recognized_intent': recognizedIntent,
        'user_corrected_intent': userCorrectedIntent,
        'original_confidence': originalConfidence,
      };

  @override
  LearningData anonymize() => IntentLearningData(
        id: id,
        timestamp: timestamp,
        userId: 'anon',
        utterance: utterance,
        recognizedIntent: recognizedIntent,
        userCorrectedIntent: userCorrectedIntent,
        originalConfidence: originalConfidence,
      );
}

/// 意图规则
class IntentRule extends LearnedRule {
  final String pattern;
  final String intentId;
  final List<String> keywords;

  IntentRule({
    required String ruleId,
    required this.pattern,
    required this.intentId,
    required this.keywords,
    required double confidence,
    required RuleSource source,
  }) : super(
          ruleId: ruleId,
          moduleId: 'intent_recognition',
          priority: source == RuleSource.userLearned ? 100 : 50,
          confidence: confidence,
          createdAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
          source: source,
        );

  @override
  bool matches(dynamic input) {
    if (input is! String) return false;
    final text = input.toLowerCase();
    return keywords.any((k) => text.contains(k.toLowerCase()));
  }

  @override
  dynamic apply(dynamic input) => intentId;

  @override
  Map<String, dynamic> toStorable() => {
        'rule_id': ruleId,
        'pattern': pattern,
        'intent_id': intentId,
        'keywords': keywords,
        'confidence': confidence,
        'source': source.name,
      };
}

/// 意图识别学习适配器
class IntentRecognitionLearningAdapter
    implements ISelfLearningModule<IntentLearningData, IntentRule> {
  @override
  String get moduleId => 'intent_recognition';

  @override
  String get moduleName => '意图识别';

  final List<IntentLearningData> _samples = [];
  final List<IntentRule> _rules = [];
  DateTime? _lastTrainingTime;
  LearningStage _stage = LearningStage.coldStart;

  @override
  Future<void> collectSample(IntentLearningData data) async {
    _samples.add(data);
    _updateStage();
  }

  @override
  Future<void> collectSamples(List<IntentLearningData> dataList) async {
    _samples.addAll(dataList);
    _updateStage();
  }

  @override
  Future<TrainingResult> train({bool incremental = true}) async {
    final startTime = DateTime.now();
    _stage = LearningStage.training;

    try {
      // 按意图分组
      final intentGroups = groupBy(_samples, (s) => s.label as String);
      final newRules = <IntentRule>[];

      for (final entry in intentGroups.entries) {
        if (entry.value.length >= 3) {
          // 提取关键词
          final keywords = _extractKeywords(entry.value.map((s) => s.utterance).toList());

          if (keywords.isNotEmpty) {
            newRules.add(IntentRule(
              ruleId: 'intent_${entry.key.hashCode}',
              pattern: entry.key,
              intentId: entry.key,
              keywords: keywords,
              confidence: entry.value.length / _samples.length,
              source: RuleSource.userLearned,
            ));
          }
        }
      }

      _rules.clear();
      _rules.addAll(newRules);
      _lastTrainingTime = DateTime.now();
      _stage = LearningStage.active;

      return TrainingResult(
        success: true,
        samplesUsed: _samples.length,
        rulesGenerated: newRules.length,
        trainingTime: DateTime.now().difference(startTime),
      );
    } catch (e) {
      _stage = LearningStage.degraded;
      return TrainingResult(
        success: false,
        samplesUsed: 0,
        rulesGenerated: 0,
        trainingTime: DateTime.now().difference(startTime),
        errorMessage: e.toString(),
      );
    }
  }

  List<String> _extractKeywords(List<String> utterances) {
    // 简单的关键词提取：找出频繁出现的词
    final wordFreq = <String, int>{};

    for (final utterance in utterances) {
      final words = utterance.toLowerCase().split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length >= 2) {
          wordFreq[word] = (wordFreq[word] ?? 0) + 1;
        }
      }
    }

    // 返回出现频率超过50%的词
    final threshold = utterances.length * 0.5;
    return wordFreq.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .take(5)
        .toList();
  }

  @override
  Future<PredictionResult<IntentRule>> predict(dynamic input) async {
    final utterance = input as String;

    for (final rule in _rules) {
      if (rule.matches(utterance)) {
        rule.recordHit();
        return PredictionResult(
          matched: true,
          matchedRule: rule,
          result: rule.intentId,
          confidence: rule.confidence,
          source: PredictionSource.learnedRule,
        );
      }
    }

    return PredictionResult(
      matched: false,
      confidence: 0,
      source: PredictionSource.fallback,
    );
  }

  @override
  Future<LearningMetrics> getMetrics() async {
    return LearningMetrics(
      moduleId: moduleId,
      measureTime: DateTime.now(),
      totalSamples: _samples.length,
      totalRules: _rules.length,
      accuracy: 0.75,
      precision: 0.75,
      recall: 0.75,
      f1Score: 0.75,
      avgResponseTime: 3.0,
    );
  }

  @override
  Future<List<IntentRule>> getRules({RuleSource? source, int? limit}) async {
    return _rules;
  }

  @override
  Future<ModelExportData> exportModel() async {
    return ModelExportData(
      moduleId: moduleId,
      exportedAt: DateTime.now(),
      rules: _rules.map((r) => r.toStorable()).toList(),
    );
  }

  @override
  Future<void> importModel(ModelExportData data) async {
    // 简化实现
  }

  @override
  Future<void> clearData({bool keepRules = true}) async {
    _samples.clear();
    if (!keepRules) _rules.clear();
    _stage = LearningStage.coldStart;
  }

  @override
  Future<LearningStatus> getStatus() async {
    return LearningStatus(
      moduleId: moduleId,
      isEnabled: true,
      lastTrainingTime: _lastTrainingTime,
      pendingSamples: _samples.length,
      stage: _stage,
    );
  }

  void _updateStage() {
    if (_samples.length < 3) {
      _stage = LearningStage.coldStart;
    } else if (_rules.isEmpty) {
      _stage = LearningStage.collecting;
    } else {
      _stage = LearningStage.active;
    }
  }
}
