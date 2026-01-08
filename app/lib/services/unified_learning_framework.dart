import 'dart:async';
import 'package:flutter/foundation.dart';

/// 统一自学习框架
///
/// 实现设计文档第18.1.1.8节的统一自学习框架架构
/// 提供可复用的学习能力抽象，支持：
/// - 智能分类自学习
/// - 预算学习
/// - 异常检测学习
/// - 搜索学习
/// - 语音意图学习
///
/// 使用示例：
/// ```dart
/// final categoryLearner = CategoryLearningAdapter();
/// await categoryLearner.collectFeedback(CategoryFeedback(...));
/// await categoryLearner.learn();
/// final metrics = await categoryLearner.evaluate();
/// ```

// ═══════════════════════════════════════════════════════════════
// 抽象学习接口层
// ═══════════════════════════════════════════════════════════════

/// 学习能力抽象接口
///
/// 所有具备自学习能力的模块都应实现此接口
/// TInput: 输入类型
/// TOutput: 输出类型
/// TFeedback: 反馈类型
abstract class ILearnable<TInput, TOutput, TFeedback> {
  /// 预测
  Future<TOutput> predict(TInput input);

  /// 采集反馈
  Future<void> collectFeedback(TFeedback feedback);

  /// 触发学习
  Future<void> learn();

  /// 评估效果
  Future<LearningMetrics> evaluate();
}

/// 学习指标
class LearningMetrics {
  /// 准确率
  final double accuracy;

  /// 召回率
  final double recall;

  /// F1分数
  final double f1Score;

  /// 样本数量
  final int sampleCount;

  /// 规则数量
  final int ruleCount;

  /// 最后学习时间
  final DateTime? lastLearnedAt;

  /// 学习耗时（毫秒）
  final int? learningDurationMs;

  /// 额外指标
  final Map<String, dynamic>? extras;

  const LearningMetrics({
    required this.accuracy,
    required this.recall,
    required this.f1Score,
    required this.sampleCount,
    required this.ruleCount,
    this.lastLearnedAt,
    this.learningDurationMs,
    this.extras,
  });

  @override
  String toString() =>
      'LearningMetrics(accuracy=$accuracy, recall=$recall, f1=$f1Score, samples=$sampleCount)';
}

// ═══════════════════════════════════════════════════════════════
// 核心组件层（可插拔）
// ═══════════════════════════════════════════════════════════════

/// 样本存储接口
abstract class ISampleStore<TSample> {
  /// 添加样本
  Future<void> addSample(TSample sample);

  /// 批量添加样本
  Future<void> addSamples(List<TSample> samples);

  /// 获取样本
  Future<List<TSample>> getSamples({
    int? limit,
    DateTime? since,
    Map<String, dynamic>? filters,
  });

  /// 获取样本数量
  Future<int> getSampleCount();

  /// 更新样本标注
  Future<void> updateLabel(String sampleId, dynamic newLabel);

  /// 删除过期样本
  Future<int> pruneOldSamples(Duration maxAge);

  /// 计算样本质量分数
  Future<double> calculateQualityScore(TSample sample);
}

/// 规则引擎接口
abstract class IRuleEngine<TInput, TOutput> {
  /// 添加规则
  Future<void> addRule(LearningRule<TInput, TOutput> rule);

  /// 移除规则
  Future<void> removeRule(String ruleId);

  /// 匹配规则
  Future<RuleMatchResult<TOutput>?> match(TInput input);

  /// 获取所有规则
  Future<List<LearningRule<TInput, TOutput>>> getRules();

  /// 解决规则冲突
  Future<LearningRule<TInput, TOutput>?> resolveConflict(
    List<LearningRule<TInput, TOutput>> conflictingRules,
    TInput input,
  );

  /// 更新规则优先级
  Future<void> updatePriority(String ruleId, int newPriority);
}

/// 学习规则
class LearningRule<TInput, TOutput> {
  /// 规则ID
  final String id;

  /// 规则名称
  final String name;

  /// 匹配条件
  final bool Function(TInput input) condition;

  /// 输出结果
  final TOutput output;

  /// 优先级（越高越优先）
  final int priority;

  /// 置信度
  final double confidence;

  /// 创建时间
  final DateTime createdAt;

  /// 命中次数
  int hitCount;

  /// 是否启用
  bool enabled;

  LearningRule({
    required this.id,
    required this.name,
    required this.condition,
    required this.output,
    this.priority = 0,
    this.confidence = 1.0,
    DateTime? createdAt,
    this.hitCount = 0,
    this.enabled = true,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// 规则匹配结果
class RuleMatchResult<TOutput> {
  /// 匹配的规则ID
  final String ruleId;

  /// 输出结果
  final TOutput output;

  /// 置信度
  final double confidence;

  const RuleMatchResult({
    required this.ruleId,
    required this.output,
    required this.confidence,
  });
}

/// 模式挖掘接口
abstract class IPatternMiner<TSample, TPattern> {
  /// 挖掘模式
  Future<List<TPattern>> minePatterns(List<TSample> samples);

  /// 聚类分析
  Future<List<List<TSample>>> cluster(
    List<TSample> samples, {
    int? numClusters,
  });

  /// 提取模板
  Future<List<TPattern>> extractTemplates(List<TSample> samples);

  /// 发现同义词
  Future<Map<String, List<String>>> discoverSynonyms(List<TSample> samples);
}

/// 模型训练接口
abstract class IModelTrainer<TSample> {
  /// 增量更新
  Future<void> incrementalUpdate(List<TSample> newSamples);

  /// 批量训练
  Future<void> batchTrain(List<TSample> allSamples);

  /// 验证评估
  Future<LearningMetrics> validate(List<TSample> testSamples);

  /// 导出模型
  Future<Map<String, dynamic>> exportModel();

  /// 导入模型
  Future<void> importModel(Map<String, dynamic> modelData);
}

// ═══════════════════════════════════════════════════════════════
// 基础实现
// ═══════════════════════════════════════════════════════════════

/// 内存样本存储
class InMemorySampleStore<TSample> implements ISampleStore<TSample> {
  final List<_StoredSample<TSample>> _samples = [];
  final double Function(TSample)? _qualityScorer;

  InMemorySampleStore({double Function(TSample)? qualityScorer})
      : _qualityScorer = qualityScorer;

  @override
  Future<void> addSample(TSample sample) async {
    _samples.add(_StoredSample(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sample: sample,
      addedAt: DateTime.now(),
    ));
  }

  @override
  Future<void> addSamples(List<TSample> samples) async {
    for (final sample in samples) {
      await addSample(sample);
    }
  }

  @override
  Future<List<TSample>> getSamples({
    int? limit,
    DateTime? since,
    Map<String, dynamic>? filters,
  }) async {
    var result = _samples.where((s) {
      if (since != null && s.addedAt.isBefore(since)) return false;
      return true;
    }).map((s) => s.sample);

    if (limit != null) {
      result = result.take(limit);
    }

    return result.toList();
  }

  @override
  Future<int> getSampleCount() async => _samples.length;

  @override
  Future<void> updateLabel(String sampleId, dynamic newLabel) async {
    final index = _samples.indexWhere((s) => s.id == sampleId);
    if (index >= 0) {
      _samples[index] = _samples[index].copyWith(label: newLabel);
    }
  }

  @override
  Future<int> pruneOldSamples(Duration maxAge) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final before = _samples.length;
    _samples.removeWhere((s) => s.addedAt.isBefore(cutoff));
    return before - _samples.length;
  }

  @override
  Future<double> calculateQualityScore(TSample sample) async {
    return _qualityScorer?.call(sample) ?? 1.0;
  }
}

class _StoredSample<T> {
  final String id;
  final T sample;
  final DateTime addedAt;
  final dynamic label;

  _StoredSample({
    required this.id,
    required this.sample,
    required this.addedAt,
    this.label,
  });

  _StoredSample<T> copyWith({dynamic label}) {
    return _StoredSample(
      id: id,
      sample: sample,
      addedAt: addedAt,
      label: label ?? this.label,
    );
  }
}

/// 简单规则引擎
class SimpleRuleEngine<TInput, TOutput> implements IRuleEngine<TInput, TOutput> {
  final List<LearningRule<TInput, TOutput>> _rules = [];

  @override
  Future<void> addRule(LearningRule<TInput, TOutput> rule) async {
    _rules.add(rule);
    _sortRules();
  }

  @override
  Future<void> removeRule(String ruleId) async {
    _rules.removeWhere((r) => r.id == ruleId);
  }

  @override
  Future<RuleMatchResult<TOutput>?> match(TInput input) async {
    for (final rule in _rules) {
      if (!rule.enabled) continue;
      try {
        if (rule.condition(input)) {
          rule.hitCount++;
          return RuleMatchResult(
            ruleId: rule.id,
            output: rule.output,
            confidence: rule.confidence,
          );
        }
      } catch (e) {
        debugPrint('Rule ${rule.id} evaluation error: $e');
      }
    }
    return null;
  }

  @override
  Future<List<LearningRule<TInput, TOutput>>> getRules() async {
    return List.unmodifiable(_rules);
  }

  @override
  Future<LearningRule<TInput, TOutput>?> resolveConflict(
    List<LearningRule<TInput, TOutput>> conflictingRules,
    TInput input,
  ) async {
    if (conflictingRules.isEmpty) return null;
    // 按优先级和置信度选择
    conflictingRules.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.confidence.compareTo(a.confidence);
    });
    return conflictingRules.first;
  }

  @override
  Future<void> updatePriority(String ruleId, int newPriority) async {
    final index = _rules.indexWhere((r) => r.id == ruleId);
    if (index >= 0) {
      final rule = _rules[index];
      _rules[index] = LearningRule(
        id: rule.id,
        name: rule.name,
        condition: rule.condition,
        output: rule.output,
        priority: newPriority,
        confidence: rule.confidence,
        createdAt: rule.createdAt,
        hitCount: rule.hitCount,
        enabled: rule.enabled,
      );
      _sortRules();
    }
  }

  void _sortRules() {
    _rules.sort((a, b) => b.priority.compareTo(a.priority));
  }
}

// ═══════════════════════════════════════════════════════════════
// 业务适配层 - 智能分类
// ═══════════════════════════════════════════════════════════════

/// 分类学习样本
class CategorySample {
  final String id;
  final String description;
  final double amount;
  final String? merchant;
  final String? predictedCategory;
  final String? actualCategory;
  final bool isCorrect;
  final DateTime timestamp;

  const CategorySample({
    required this.id,
    required this.description,
    required this.amount,
    this.merchant,
    this.predictedCategory,
    this.actualCategory,
    required this.isCorrect,
    required this.timestamp,
  });
}

/// 分类反馈
class CategoryFeedback {
  final String transactionId;
  final String description;
  final double amount;
  final String predictedCategory;
  final String correctedCategory;
  final DateTime timestamp;

  const CategoryFeedback({
    required this.transactionId,
    required this.description,
    required this.amount,
    required this.predictedCategory,
    required this.correctedCategory,
    required this.timestamp,
  });
}

/// 智能分类学习适配器
class CategoryLearningAdapter
    implements ILearnable<String, String, CategoryFeedback> {
  final ISampleStore<CategorySample> _sampleStore;
  final IRuleEngine<String, String> _ruleEngine;

  /// 学习触发阈值
  static const int learningThreshold = 10;

  /// 待处理反馈
  final List<CategoryFeedback> _pendingFeedback = [];

  CategoryLearningAdapter({
    ISampleStore<CategorySample>? sampleStore,
    IRuleEngine<String, String>? ruleEngine,
  })  : _sampleStore = sampleStore ?? InMemorySampleStore<CategorySample>(),
        _ruleEngine = ruleEngine ?? SimpleRuleEngine<String, String>();

  @override
  Future<String> predict(String description) async {
    // 1. 先尝试规则匹配
    final ruleResult = await _ruleEngine.match(description);
    if (ruleResult != null && ruleResult.confidence > 0.8) {
      return ruleResult.output;
    }

    // 2. 默认返回空，由上层模块使用模型预测
    return '';
  }

  @override
  Future<void> collectFeedback(CategoryFeedback feedback) async {
    _pendingFeedback.add(feedback);

    // 存储样本
    await _sampleStore.addSample(CategorySample(
      id: feedback.transactionId,
      description: feedback.description,
      amount: feedback.amount,
      predictedCategory: feedback.predictedCategory,
      actualCategory: feedback.correctedCategory,
      isCorrect: feedback.predictedCategory == feedback.correctedCategory,
      timestamp: feedback.timestamp,
    ));

    // 达到阈值触发学习
    if (_pendingFeedback.length >= learningThreshold) {
      await learn();
    }
  }

  @override
  Future<void> learn() async {
    if (_pendingFeedback.isEmpty) return;

    // 分析反馈模式，生成新规则
    final feedbackGroups = <String, List<CategoryFeedback>>{};
    for (final fb in _pendingFeedback) {
      final key = fb.correctedCategory;
      feedbackGroups.putIfAbsent(key, () => []).add(fb);
    }

    for (final entry in feedbackGroups.entries) {
      final category = entry.key;
      final feedbacks = entry.value;

      // 提取关键词
      final keywords = _extractKeywords(feedbacks.map((f) => f.description));

      for (final keyword in keywords) {
        await _ruleEngine.addRule(LearningRule<String, String>(
          id: 'rule_${DateTime.now().microsecondsSinceEpoch}_$keyword',
          name: '关键词规则: $keyword -> $category',
          condition: (input) => input.contains(keyword),
          output: category,
          priority: feedbacks.length,
          confidence: feedbacks.length / _pendingFeedback.length,
        ));
      }
    }

    _pendingFeedback.clear();
  }

  @override
  Future<LearningMetrics> evaluate() async {
    final samples = await _sampleStore.getSamples();
    if (samples.isEmpty) {
      return const LearningMetrics(
        accuracy: 0,
        recall: 0,
        f1Score: 0,
        sampleCount: 0,
        ruleCount: 0,
      );
    }

    final correctCount = samples.where((s) => s.isCorrect).length;
    final accuracy = correctCount / samples.length;
    final rules = await _ruleEngine.getRules();

    return LearningMetrics(
      accuracy: accuracy,
      recall: accuracy, // 简化处理
      f1Score: accuracy, // 简化处理
      sampleCount: samples.length,
      ruleCount: rules.length,
      lastLearnedAt: DateTime.now(),
    );
  }

  List<String> _extractKeywords(Iterable<String> descriptions) {
    final wordCount = <String, int>{};
    for (final desc in descriptions) {
      final words = desc.split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length >= 2) {
          wordCount[word] = (wordCount[word] ?? 0) + 1;
        }
      }
    }

    // 返回高频词
    final sorted = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }
}

// ═══════════════════════════════════════════════════════════════
// 业务适配层 - 异常检测
// ═══════════════════════════════════════════════════════════════

/// 异常样本
class AnomalySample {
  final String transactionId;
  final double amount;
  final String category;
  final bool isAnomaly;
  final bool userConfirmed;
  final DateTime timestamp;

  const AnomalySample({
    required this.transactionId,
    required this.amount,
    required this.category,
    required this.isAnomaly,
    required this.userConfirmed,
    required this.timestamp,
  });
}

/// 异常反馈
class AnomalyFeedback {
  final String transactionId;
  final bool isActualAnomaly;
  final String? reason;

  const AnomalyFeedback({
    required this.transactionId,
    required this.isActualAnomaly,
    this.reason,
  });
}

/// 异常检测学习适配器
class AnomalyLearningAdapter
    implements ILearnable<Map<String, dynamic>, bool, AnomalyFeedback> {
  final ISampleStore<AnomalySample> _sampleStore;

  /// 分类消费统计
  final Map<String, _CategoryStats> _categoryStats = {};

  AnomalyLearningAdapter({ISampleStore<AnomalySample>? sampleStore})
      : _sampleStore = sampleStore ?? InMemorySampleStore<AnomalySample>();

  @override
  Future<bool> predict(Map<String, dynamic> input) async {
    final amount = input['amount'] as double;
    final category = input['category'] as String;

    final stats = _categoryStats[category];
    if (stats == null || stats.count < 5) {
      return false; // 数据不足，不判定为异常
    }

    // 超过平均值3倍标准差则判定为异常
    final threshold = stats.mean + 3 * stats.stdDev;
    return amount > threshold;
  }

  @override
  Future<void> collectFeedback(AnomalyFeedback feedback) async {
    // 更新样本标注
    await _sampleStore.updateLabel(feedback.transactionId, feedback.isActualAnomaly);
  }

  @override
  Future<void> learn() async {
    final samples = await _sampleStore.getSamples();

    // 重新计算各分类的统计信息
    final categoryAmounts = <String, List<double>>{};
    for (final sample in samples) {
      if (!sample.isAnomaly || sample.userConfirmed) {
        categoryAmounts.putIfAbsent(sample.category, () => []).add(sample.amount);
      }
    }

    for (final entry in categoryAmounts.entries) {
      final amounts = entry.value;
      if (amounts.isEmpty) continue;

      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance =
          amounts.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) /
              amounts.length;
      final stdDev = variance > 0 ? variance.sqrt() : 0.0;

      _categoryStats[entry.key] = _CategoryStats(
        count: amounts.length,
        mean: mean,
        stdDev: stdDev,
      );
    }
  }

  @override
  Future<LearningMetrics> evaluate() async {
    final samples = await _sampleStore.getSamples();
    final confirmedSamples = samples.where((s) => s.userConfirmed).toList();

    if (confirmedSamples.isEmpty) {
      return const LearningMetrics(
        accuracy: 0,
        recall: 0,
        f1Score: 0,
        sampleCount: 0,
        ruleCount: 0,
      );
    }

    int tp = 0, fp = 0, fn = 0;
    for (final sample in confirmedSamples) {
      final predicted = await predict({
        'amount': sample.amount,
        'category': sample.category,
      });
      if (predicted && sample.isAnomaly) {
        tp++;
      } else if (predicted && !sample.isAnomaly) {
        fp++;
      } else if (!predicted && sample.isAnomaly) {
        fn++;
      }
    }

    final precision = tp + fp > 0 ? tp / (tp + fp) : 0.0;
    final recall = tp + fn > 0 ? tp / (tp + fn) : 0.0;
    final f1 = precision + recall > 0
        ? 2 * precision * recall / (precision + recall)
        : 0.0;

    return LearningMetrics(
      accuracy: precision,
      recall: recall,
      f1Score: f1,
      sampleCount: samples.length,
      ruleCount: _categoryStats.length,
      lastLearnedAt: DateTime.now(),
    );
  }
}

class _CategoryStats {
  final int count;
  final double mean;
  final double stdDev;

  const _CategoryStats({
    required this.count,
    required this.mean,
    required this.stdDev,
  });
}

// ═══════════════════════════════════════════════════════════════
// 业务适配层 - 语音意图学习
// ═══════════════════════════════════════════════════════════════

/// 语音意图样本
class VoiceIntentSample {
  final String id;
  final String utterance;
  final String predictedIntent;
  final String? actualIntent;
  final Map<String, dynamic>? extractedEntities;
  final bool isCorrect;
  final DateTime timestamp;

  const VoiceIntentSample({
    required this.id,
    required this.utterance,
    required this.predictedIntent,
    this.actualIntent,
    this.extractedEntities,
    required this.isCorrect,
    required this.timestamp,
  });
}

/// 语音意图反馈
class VoiceIntentFeedback {
  final String utterance;
  final String predictedIntent;
  final String correctedIntent;
  final Map<String, dynamic>? correctedEntities;

  const VoiceIntentFeedback({
    required this.utterance,
    required this.predictedIntent,
    required this.correctedIntent,
    this.correctedEntities,
  });
}

/// 语音意图学习适配器
class VoiceIntentLearningAdapter
    implements ILearnable<String, String, VoiceIntentFeedback> {
  final ISampleStore<VoiceIntentSample> _sampleStore;
  final IRuleEngine<String, String> _ruleEngine;

  VoiceIntentLearningAdapter({
    ISampleStore<VoiceIntentSample>? sampleStore,
    IRuleEngine<String, String>? ruleEngine,
  })  : _sampleStore = sampleStore ?? InMemorySampleStore<VoiceIntentSample>(),
        _ruleEngine = ruleEngine ?? SimpleRuleEngine<String, String>();

  @override
  Future<String> predict(String utterance) async {
    final result = await _ruleEngine.match(utterance);
    return result?.output ?? 'unknown';
  }

  @override
  Future<void> collectFeedback(VoiceIntentFeedback feedback) async {
    await _sampleStore.addSample(VoiceIntentSample(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      utterance: feedback.utterance,
      predictedIntent: feedback.predictedIntent,
      actualIntent: feedback.correctedIntent,
      isCorrect: feedback.predictedIntent == feedback.correctedIntent,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> learn() async {
    final samples = await _sampleStore.getSamples();
    final incorrectSamples = samples.where((s) => !s.isCorrect).toList();

    // 按实际意图分组
    final intentGroups = <String, List<VoiceIntentSample>>{};
    for (final sample in incorrectSamples) {
      if (sample.actualIntent != null) {
        intentGroups
            .putIfAbsent(sample.actualIntent!, () => [])
            .add(sample);
      }
    }

    // 生成规则
    for (final entry in intentGroups.entries) {
      final intent = entry.key;
      final samples = entry.value;

      // 提取共同模式
      final patterns = _extractPatterns(samples.map((s) => s.utterance));

      for (final pattern in patterns) {
        await _ruleEngine.addRule(LearningRule<String, String>(
          id: 'voice_rule_${DateTime.now().microsecondsSinceEpoch}_$pattern',
          name: '语音规则: $pattern -> $intent',
          condition: (input) => input.contains(pattern),
          output: intent,
          priority: samples.length,
          confidence: samples.length / incorrectSamples.length,
        ));
      }
    }
  }

  @override
  Future<LearningMetrics> evaluate() async {
    final samples = await _sampleStore.getSamples();
    if (samples.isEmpty) {
      return const LearningMetrics(
        accuracy: 0,
        recall: 0,
        f1Score: 0,
        sampleCount: 0,
        ruleCount: 0,
      );
    }

    final correctCount = samples.where((s) => s.isCorrect).length;
    final accuracy = correctCount / samples.length;
    final rules = await _ruleEngine.getRules();

    return LearningMetrics(
      accuracy: accuracy,
      recall: accuracy,
      f1Score: accuracy,
      sampleCount: samples.length,
      ruleCount: rules.length,
      lastLearnedAt: DateTime.now(),
    );
  }

  List<String> _extractPatterns(Iterable<String> utterances) {
    // 简化实现：提取高频词组
    final patterns = <String, int>{};
    for (final utterance in utterances) {
      // 2-gram
      final words = utterance.split('');
      for (var i = 0; i < words.length - 1; i++) {
        final bigram = words.sublist(i, i + 2).join();
        if (bigram.length >= 2) {
          patterns[bigram] = (patterns[bigram] ?? 0) + 1;
        }
      }
    }

    final sorted = patterns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(3).map((e) => e.key).toList();
  }
}

// ═══════════════════════════════════════════════════════════════
// 统一学习管理器
// ═══════════════════════════════════════════════════════════════

/// 统一学习管理器
///
/// 管理所有学习适配器，提供统一的学习触发和监控
class UnifiedLearningManager extends ChangeNotifier {
  /// 分类学习适配器
  final CategoryLearningAdapter categoryLearner;

  /// 异常检测学习适配器
  final AnomalyLearningAdapter anomalyLearner;

  /// 语音意图学习适配器
  final VoiceIntentLearningAdapter voiceLearner;

  /// 学习状态
  bool _isLearning = false;

  /// 最后学习时间
  DateTime? _lastLearnedAt;

  /// 学习定时器
  Timer? _learningTimer;

  UnifiedLearningManager({
    CategoryLearningAdapter? categoryLearner,
    AnomalyLearningAdapter? anomalyLearner,
    VoiceIntentLearningAdapter? voiceLearner,
  })  : categoryLearner = categoryLearner ?? CategoryLearningAdapter(),
        anomalyLearner = anomalyLearner ?? AnomalyLearningAdapter(),
        voiceLearner = voiceLearner ?? VoiceIntentLearningAdapter();

  bool get isLearning => _isLearning;
  DateTime? get lastLearnedAt => _lastLearnedAt;

  /// 启动定时学习
  void startPeriodicLearning({Duration interval = const Duration(hours: 1)}) {
    _learningTimer?.cancel();
    _learningTimer = Timer.periodic(interval, (_) => triggerLearning());
  }

  /// 停止定时学习
  void stopPeriodicLearning() {
    _learningTimer?.cancel();
    _learningTimer = null;
  }

  /// 触发全部学习
  Future<Map<String, LearningMetrics>> triggerLearning() async {
    if (_isLearning) {
      return {};
    }

    _isLearning = true;
    notifyListeners();

    final results = <String, LearningMetrics>{};

    try {
      // 分类学习
      await categoryLearner.learn();
      results['category'] = await categoryLearner.evaluate();

      // 异常检测学习
      await anomalyLearner.learn();
      results['anomaly'] = await anomalyLearner.evaluate();

      // 语音意图学习
      await voiceLearner.learn();
      results['voice'] = await voiceLearner.evaluate();

      _lastLearnedAt = DateTime.now();
    } finally {
      _isLearning = false;
      notifyListeners();
    }

    return results;
  }

  /// 获取所有学习指标
  Future<Map<String, LearningMetrics>> getAllMetrics() async {
    return {
      'category': await categoryLearner.evaluate(),
      'anomaly': await anomalyLearner.evaluate(),
      'voice': await voiceLearner.evaluate(),
    };
  }

  @override
  void dispose() {
    _learningTimer?.cancel();
    super.dispose();
  }
}

/// 扩展方法
extension DoubleExtension on double {
  double sqrt() {
    if (this < 0) return 0;
    var guess = this / 2;
    for (var i = 0; i < 10; i++) {
      guess = (guess + this / guess) / 2;
    }
    return guess;
  }
}

// ═══════════════════════════════════════════════════════════════
// 模式挖掘具体实现
// ═══════════════════════════════════════════════════════════════

/// 文本模式
class TextPattern {
  /// 模式ID
  final String id;

  /// 模式文本
  final String pattern;

  /// 支持度（出现频率）
  final double support;

  /// 置信度
  final double confidence;

  /// 关联的类别
  final String? associatedCategory;

  /// 发现时间
  final DateTime discoveredAt;

  const TextPattern({
    required this.id,
    required this.pattern,
    required this.support,
    required this.confidence,
    this.associatedCategory,
    required this.discoveredAt,
  });

  @override
  String toString() => 'TextPattern($pattern, support=$support)';
}

/// 文本模式挖掘器
///
/// 实现设计文档第18.1.1.8节的模式挖掘能力
/// 支持：
/// - N-gram模式挖掘
/// - K-means聚类分析
/// - 模板提取
/// - 同义词发现
class TextPatternMiner implements IPatternMiner<VoiceIntentSample, TextPattern> {
  /// 最小支持度阈值
  final double minSupport;

  /// 最小置信度阈值
  final double minConfidence;

  /// N-gram范围
  final int minNgram;
  final int maxNgram;

  TextPatternMiner({
    this.minSupport = 0.05,
    this.minConfidence = 0.6,
    this.minNgram = 2,
    this.maxNgram = 4,
  });

  @override
  Future<List<TextPattern>> minePatterns(List<VoiceIntentSample> samples) async {
    if (samples.isEmpty) return [];

    final patterns = <TextPattern>[];
    final ngramCounts = <String, int>{};
    final ngramCategories = <String, Map<String, int>>{};

    // 提取所有N-gram
    for (final sample in samples) {
      final text = sample.utterance;
      final ngrams = _extractNgrams(text);

      for (final ngram in ngrams) {
        ngramCounts[ngram] = (ngramCounts[ngram] ?? 0) + 1;

        // 统计N-gram与类别的关联
        final category = sample.actualIntent ?? sample.predictedIntent;
        ngramCategories.putIfAbsent(ngram, () => {});
        ngramCategories[ngram]![category] =
            (ngramCategories[ngram]![category] ?? 0) + 1;
      }
    }

    // 过滤低频模式，计算支持度和置信度
    final totalSamples = samples.length;
    for (final entry in ngramCounts.entries) {
      final ngram = entry.key;
      final count = entry.value;
      final support = count / totalSamples;

      if (support < minSupport) continue;

      // 计算置信度（最常见类别的占比）
      final categoryDist = ngramCategories[ngram]!;
      final maxCategoryCount = categoryDist.values.reduce((a, b) => a > b ? a : b);
      final confidence = maxCategoryCount / count;

      if (confidence < minConfidence) continue;

      // 找到最关联的类别
      final bestCategory = categoryDist.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      patterns.add(TextPattern(
        id: 'pattern_${DateTime.now().microsecondsSinceEpoch}_$ngram',
        pattern: ngram,
        support: support,
        confidence: confidence,
        associatedCategory: bestCategory,
        discoveredAt: DateTime.now(),
      ));
    }

    // 按支持度排序
    patterns.sort((a, b) => b.support.compareTo(a.support));

    return patterns;
  }

  @override
  Future<List<List<VoiceIntentSample>>> cluster(
    List<VoiceIntentSample> samples, {
    int? numClusters,
  }) async {
    if (samples.isEmpty) return [];

    final k = numClusters ?? _estimateOptimalK(samples.length);
    if (k <= 0) return [samples];

    // 简化的K-means实现
    // 1. 将文本转换为特征向量（词频向量）
    final vocabulary = <String>{};
    final sampleVectors = <List<double>>[];

    for (final sample in samples) {
      final words = sample.utterance.split('');
      vocabulary.addAll(words);
    }

    final vocabList = vocabulary.toList();
    for (final sample in samples) {
      final words = sample.utterance.split('');
      final wordCount = <String, int>{};
      for (final word in words) {
        wordCount[word] = (wordCount[word] ?? 0) + 1;
      }

      final vector = vocabList.map((v) => (wordCount[v] ?? 0).toDouble()).toList();
      sampleVectors.add(vector);
    }

    // 2. 初始化聚类中心（随机选择K个样本）
    final random = DateTime.now().millisecondsSinceEpoch;
    final centroids = <List<double>>[];
    final usedIndices = <int>{};

    for (var i = 0; i < k && i < samples.length; i++) {
      var idx = (random + i * 7) % samples.length;
      while (usedIndices.contains(idx)) {
        idx = (idx + 1) % samples.length;
      }
      usedIndices.add(idx);
      centroids.add(List.from(sampleVectors[idx]));
    }

    // 3. 迭代聚类
    var assignments = List<int>.filled(samples.length, 0);
    for (var iteration = 0; iteration < 10; iteration++) {
      // 分配样本到最近的聚类中心
      for (var i = 0; i < samples.length; i++) {
        var minDist = double.infinity;
        var bestCluster = 0;

        for (var j = 0; j < centroids.length; j++) {
          final dist = _euclideanDistance(sampleVectors[i], centroids[j]);
          if (dist < minDist) {
            minDist = dist;
            bestCluster = j;
          }
        }
        assignments[i] = bestCluster;
      }

      // 更新聚类中心
      for (var j = 0; j < centroids.length; j++) {
        final clusterSamples = <List<double>>[];
        for (var i = 0; i < samples.length; i++) {
          if (assignments[i] == j) {
            clusterSamples.add(sampleVectors[i]);
          }
        }

        if (clusterSamples.isNotEmpty) {
          centroids[j] = _computeCentroid(clusterSamples);
        }
      }
    }

    // 4. 构建结果
    final clusters = List<List<VoiceIntentSample>>.generate(k, (_) => []);
    for (var i = 0; i < samples.length; i++) {
      clusters[assignments[i]].add(samples[i]);
    }

    // 过滤空聚类
    return clusters.where((c) => c.isNotEmpty).toList();
  }

  @override
  Future<List<TextPattern>> extractTemplates(List<VoiceIntentSample> samples) async {
    if (samples.isEmpty) return [];

    // 按意图分组
    final intentGroups = <String, List<String>>{};
    for (final sample in samples) {
      final intent = sample.actualIntent ?? sample.predictedIntent;
      intentGroups.putIfAbsent(intent, () => []).add(sample.utterance);
    }

    final templates = <TextPattern>[];

    for (final entry in intentGroups.entries) {
      final intent = entry.key;
      final utterances = entry.value;

      if (utterances.length < 3) continue;

      // 提取共同前缀和后缀作为模板
      final commonPrefixes = _extractCommonPrefixes(utterances);
      final commonSuffixes = _extractCommonSuffixes(utterances);

      for (final prefix in commonPrefixes) {
        if (prefix.length >= 2) {
          templates.add(TextPattern(
            id: 'template_prefix_${DateTime.now().microsecondsSinceEpoch}_$prefix',
            pattern: '$prefix*',
            support: commonPrefixes.length / utterances.length,
            confidence: 0.8,
            associatedCategory: intent,
            discoveredAt: DateTime.now(),
          ));
        }
      }

      for (final suffix in commonSuffixes) {
        if (suffix.length >= 2) {
          templates.add(TextPattern(
            id: 'template_suffix_${DateTime.now().microsecondsSinceEpoch}_$suffix',
            pattern: '*$suffix',
            support: commonSuffixes.length / utterances.length,
            confidence: 0.8,
            associatedCategory: intent,
            discoveredAt: DateTime.now(),
          ));
        }
      }
    }

    return templates;
  }

  @override
  Future<Map<String, List<String>>> discoverSynonyms(
    List<VoiceIntentSample> samples,
  ) async {
    if (samples.isEmpty) return {};

    // 同义词发现：基于上下文相似性
    // 如果两个词经常出现在相同的上下文中，它们可能是同义词

    final wordContexts = <String, Set<String>>{};

    for (final sample in samples) {
      final chars = sample.utterance.split('');
      for (var i = 0; i < chars.length; i++) {
        final word = chars[i];
        final context = <String>{};

        // 收集上下文（前后各2个字符）
        if (i > 0) context.add(chars[i - 1]);
        if (i > 1) context.add(chars[i - 2]);
        if (i < chars.length - 1) context.add(chars[i + 1]);
        if (i < chars.length - 2) context.add(chars[i + 2]);

        wordContexts.putIfAbsent(word, () => {}).addAll(context);
      }
    }

    // 计算上下文相似度，找出同义词
    final synonyms = <String, List<String>>{};
    final words = wordContexts.keys.toList();

    for (var i = 0; i < words.length; i++) {
      final word1 = words[i];
      final context1 = wordContexts[word1]!;
      final similarWords = <String>[];

      for (var j = i + 1; j < words.length; j++) {
        final word2 = words[j];
        final context2 = wordContexts[word2]!;

        // Jaccard相似度
        final intersection = context1.intersection(context2).length;
        final union = context1.union(context2).length;
        final similarity = union > 0 ? intersection / union : 0.0;

        if (similarity > 0.5) {
          similarWords.add(word2);
        }
      }

      if (similarWords.isNotEmpty) {
        synonyms[word1] = similarWords;
      }
    }

    // 预定义的同义词组（财务领域）
    const predefinedSynonyms = {
      '花': ['消费', '支出', '付'],
      '赚': ['收入', '入账', '进账'],
      '买': ['购买', '购入', '采购'],
      '吃': ['餐饮', '饮食', '用餐'],
      '打车': ['叫车', '出租车', '网约车'],
      '工资': ['薪水', '薪资', '月薪'],
    };

    // 合并预定义和发现的同义词
    for (final entry in predefinedSynonyms.entries) {
      synonyms.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }

    return synonyms;
  }

  // 辅助方法

  List<String> _extractNgrams(String text) {
    final ngrams = <String>[];
    final chars = text.split('');

    for (var n = minNgram; n <= maxNgram && n <= chars.length; n++) {
      for (var i = 0; i <= chars.length - n; i++) {
        ngrams.add(chars.sublist(i, i + n).join());
      }
    }

    return ngrams;
  }

  int _estimateOptimalK(int sampleCount) {
    // 简单的肘部法则估计
    return (sampleCount / 10).clamp(2, 10).toInt();
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sum.sqrt();
  }

  List<double> _computeCentroid(List<List<double>> vectors) {
    if (vectors.isEmpty) return [];

    final dim = vectors.first.length;
    final centroid = List<double>.filled(dim, 0);

    for (final vector in vectors) {
      for (var i = 0; i < dim; i++) {
        centroid[i] += vector[i];
      }
    }

    for (var i = 0; i < dim; i++) {
      centroid[i] /= vectors.length;
    }

    return centroid;
  }

  List<String> _extractCommonPrefixes(List<String> texts) {
    if (texts.isEmpty) return [];

    final prefixes = <String, int>{};
    for (final text in texts) {
      for (var len = 2; len <= text.length && len <= 6; len++) {
        final prefix = text.substring(0, len);
        prefixes[prefix] = (prefixes[prefix] ?? 0) + 1;
      }
    }

    // 返回出现次数超过半数的前缀
    final threshold = texts.length / 2;
    return prefixes.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toList();
  }

  List<String> _extractCommonSuffixes(List<String> texts) {
    if (texts.isEmpty) return [];

    final suffixes = <String, int>{};
    for (final text in texts) {
      for (var len = 2; len <= text.length && len <= 6; len++) {
        final suffix = text.substring(text.length - len);
        suffixes[suffix] = (suffixes[suffix] ?? 0) + 1;
      }
    }

    final threshold = texts.length / 2;
    return suffixes.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════════
// 模型训练具体实现
// ═══════════════════════════════════════════════════════════════

/// 轻量级本地模型训练器
///
/// 实现设计文档第18.1.1.8节的模型训练能力
/// 支持：
/// - 朴素贝叶斯分类器训练
/// - 增量更新
/// - 模型导入导出
class LocalModelTrainer implements IModelTrainer<VoiceIntentSample> {
  /// 类别先验概率
  final Map<String, double> _classPriors = {};

  /// 特征条件概率 P(feature|class)
  final Map<String, Map<String, double>> _featureLikelihoods = {};

  /// 词汇表
  final Set<String> _vocabulary = {};

  /// 训练样本数
  int _trainedSampleCount = 0;

  /// 最后训练时间
  DateTime? _lastTrainedAt;

  /// 平滑参数（拉普拉斯平滑）
  final double smoothingAlpha;

  LocalModelTrainer({this.smoothingAlpha = 1.0});

  @override
  Future<void> incrementalUpdate(List<VoiceIntentSample> newSamples) async {
    if (newSamples.isEmpty) return;

    // 增量更新词汇表和计数
    final classCounts = <String, int>{};
    final featureCounts = <String, Map<String, int>>{};

    // 先加载现有统计
    for (final cls in _classPriors.keys) {
      classCounts[cls] = (_classPriors[cls]! * _trainedSampleCount).round();
    }

    for (final sample in newSamples) {
      final cls = sample.actualIntent ?? sample.predictedIntent;
      classCounts[cls] = (classCounts[cls] ?? 0) + 1;

      // 提取特征（字符级）
      final features = _extractFeatures(sample.utterance);
      _vocabulary.addAll(features);

      featureCounts.putIfAbsent(cls, () => {});
      for (final feature in features) {
        featureCounts[cls]![feature] = (featureCounts[cls]![feature] ?? 0) + 1;
      }
    }

    // 更新先验概率
    final totalSamples = _trainedSampleCount + newSamples.length;
    for (final entry in classCounts.entries) {
      _classPriors[entry.key] = entry.value / totalSamples;
    }

    // 更新特征似然概率
    for (final clsEntry in featureCounts.entries) {
      final cls = clsEntry.key;
      final features = clsEntry.value;
      final totalFeatures = features.values.fold(0, (a, b) => a + b);

      _featureLikelihoods.putIfAbsent(cls, () => {});
      for (final featEntry in features.entries) {
        // 拉普拉斯平滑
        _featureLikelihoods[cls]![featEntry.key] =
            (featEntry.value + smoothingAlpha) /
            (totalFeatures + smoothingAlpha * _vocabulary.length);
      }
    }

    _trainedSampleCount = totalSamples;
    _lastTrainedAt = DateTime.now();
  }

  @override
  Future<void> batchTrain(List<VoiceIntentSample> allSamples) async {
    // 清除现有模型
    _classPriors.clear();
    _featureLikelihoods.clear();
    _vocabulary.clear();
    _trainedSampleCount = 0;

    if (allSamples.isEmpty) return;

    // 统计类别
    final classCounts = <String, int>{};
    final classFeatureCounts = <String, Map<String, int>>{};

    for (final sample in allSamples) {
      final cls = sample.actualIntent ?? sample.predictedIntent;
      classCounts[cls] = (classCounts[cls] ?? 0) + 1;

      final features = _extractFeatures(sample.utterance);
      _vocabulary.addAll(features);

      classFeatureCounts.putIfAbsent(cls, () => {});
      for (final feature in features) {
        classFeatureCounts[cls]![feature] =
            (classFeatureCounts[cls]![feature] ?? 0) + 1;
      }
    }

    // 计算先验概率
    for (final entry in classCounts.entries) {
      _classPriors[entry.key] = entry.value / allSamples.length;
    }

    // 计算特征似然概率
    for (final clsEntry in classFeatureCounts.entries) {
      final cls = clsEntry.key;
      final features = clsEntry.value;
      final totalFeatures = features.values.fold(0, (a, b) => a + b);

      _featureLikelihoods[cls] = {};
      for (final featEntry in features.entries) {
        _featureLikelihoods[cls]![featEntry.key] =
            (featEntry.value + smoothingAlpha) /
            (totalFeatures + smoothingAlpha * _vocabulary.length);
      }
    }

    _trainedSampleCount = allSamples.length;
    _lastTrainedAt = DateTime.now();
  }

  @override
  Future<LearningMetrics> validate(List<VoiceIntentSample> testSamples) async {
    if (testSamples.isEmpty || _classPriors.isEmpty) {
      return const LearningMetrics(
        accuracy: 0,
        recall: 0,
        f1Score: 0,
        sampleCount: 0,
        ruleCount: 0,
      );
    }

    int correct = 0;
    final classTP = <String, int>{};
    final classFP = <String, int>{};
    final classFN = <String, int>{};

    for (final sample in testSamples) {
      final actual = sample.actualIntent ?? sample.predictedIntent;
      final predicted = predict(sample.utterance);

      if (predicted == actual) {
        correct++;
        classTP[actual] = (classTP[actual] ?? 0) + 1;
      } else {
        classFP[predicted] = (classFP[predicted] ?? 0) + 1;
        classFN[actual] = (classFN[actual] ?? 0) + 1;
      }
    }

    final accuracy = correct / testSamples.length;

    // 计算宏平均精确率和召回率
    double totalPrecision = 0;
    double totalRecall = 0;
    int classCount = 0;

    for (final cls in _classPriors.keys) {
      final tp = classTP[cls] ?? 0;
      final fp = classFP[cls] ?? 0;
      final fn = classFN[cls] ?? 0;

      if (tp + fp > 0) {
        totalPrecision += tp / (tp + fp);
        classCount++;
      }
      if (tp + fn > 0) {
        totalRecall += tp / (tp + fn);
      }
    }

    final precision = classCount > 0 ? totalPrecision / classCount : 0.0;
    final recall = classCount > 0 ? totalRecall / classCount : 0.0;
    final f1 = precision + recall > 0
        ? 2 * precision * recall / (precision + recall)
        : 0.0;

    return LearningMetrics(
      accuracy: accuracy,
      recall: recall,
      f1Score: f1,
      sampleCount: testSamples.length,
      ruleCount: _vocabulary.length,
      lastLearnedAt: _lastTrainedAt,
    );
  }

  @override
  Future<Map<String, dynamic>> exportModel() async {
    return {
      'version': '1.0',
      'type': 'naive_bayes',
      'vocabulary': _vocabulary.toList(),
      'classPriors': _classPriors,
      'featureLikelihoods': _featureLikelihoods.map(
        (k, v) => MapEntry(k, v),
      ),
      'trainedSampleCount': _trainedSampleCount,
      'lastTrainedAt': _lastTrainedAt?.toIso8601String(),
      'smoothingAlpha': smoothingAlpha,
    };
  }

  @override
  Future<void> importModel(Map<String, dynamic> modelData) async {
    if (modelData['version'] != '1.0' || modelData['type'] != 'naive_bayes') {
      throw Exception('Unsupported model format');
    }

    _vocabulary.clear();
    _vocabulary.addAll((modelData['vocabulary'] as List).cast<String>());

    _classPriors.clear();
    _classPriors.addAll((modelData['classPriors'] as Map).cast<String, double>());

    _featureLikelihoods.clear();
    final likelihoods = modelData['featureLikelihoods'] as Map;
    for (final entry in likelihoods.entries) {
      _featureLikelihoods[entry.key as String] =
          (entry.value as Map).cast<String, double>();
    }

    _trainedSampleCount = modelData['trainedSampleCount'] as int;
    final lastTrainedStr = modelData['lastTrainedAt'] as String?;
    _lastTrainedAt = lastTrainedStr != null ? DateTime.parse(lastTrainedStr) : null;
  }

  /// 预测类别
  String predict(String text) {
    if (_classPriors.isEmpty) return 'unknown';

    final features = _extractFeatures(text);
    String bestClass = _classPriors.keys.first;
    double bestScore = double.negativeInfinity;

    for (final cls in _classPriors.keys) {
      // 对数概率避免下溢
      double score = (_classPriors[cls]! > 0)
          ? _log(_classPriors[cls]!)
          : -100;

      for (final feature in features) {
        final likelihood = _featureLikelihoods[cls]?[feature];
        if (likelihood != null && likelihood > 0) {
          score += _log(likelihood);
        } else {
          // 未见特征使用平滑概率
          score += _log(smoothingAlpha / (_vocabulary.length * smoothingAlpha));
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestClass = cls;
      }
    }

    return bestClass;
  }

  /// 获取预测概率分布
  Map<String, double> predictProbabilities(String text) {
    if (_classPriors.isEmpty) return {};

    final features = _extractFeatures(text);
    final scores = <String, double>{};

    for (final cls in _classPriors.keys) {
      double score = _log(_classPriors[cls]!);

      for (final feature in features) {
        final likelihood = _featureLikelihoods[cls]?[feature];
        if (likelihood != null && likelihood > 0) {
          score += _log(likelihood);
        } else {
          score += _log(smoothingAlpha / (_vocabulary.length * smoothingAlpha));
        }
      }

      scores[cls] = score;
    }

    // 转换为概率（softmax）
    final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
    final expScores = scores.map((k, v) => MapEntry(k, _exp(v - maxScore)));
    final sumExp = expScores.values.reduce((a, b) => a + b);

    return expScores.map((k, v) => MapEntry(k, v / sumExp));
  }

  // 辅助方法

  List<String> _extractFeatures(String text) {
    final features = <String>[];

    // 字符级别特征（1-gram和2-gram）
    final chars = text.split('');
    features.addAll(chars);

    for (var i = 0; i < chars.length - 1; i++) {
      features.add(chars.sublist(i, i + 2).join());
    }

    return features;
  }

  double _log(double x) {
    if (x <= 0) return -100;
    // 简单的自然对数实现
    if (x == 1) return 0;
    if (x > 1) {
      var result = 0.0;
      var temp = x;
      while (temp > 2) {
        temp /= 2.718281828;
        result += 1;
      }
      return result + _logSmall(temp);
    }
    return -_log(1 / x);
  }

  double _logSmall(double x) {
    // 泰勒展开 ln(x) for x close to 1
    final y = (x - 1) / (x + 1);
    var result = y;
    var term = y;
    for (var i = 3; i <= 15; i += 2) {
      term *= y * y;
      result += term / i;
    }
    return 2 * result;
  }

  double _exp(double x) {
    if (x > 100) return double.maxFinite;
    if (x < -100) return 0;

    // 泰勒展开
    double result = 1;
    double term = 1;
    for (var i = 1; i <= 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }
}

// ═══════════════════════════════════════════════════════════════
// 协同学习服务
// ═══════════════════════════════════════════════════════════════

/// 协同学习配置
class CollaborativeLearningConfig {
  /// 是否启用
  final bool enabled;

  /// 最小本地样本数（达到后才上传）
  final int minLocalSamples;

  /// 上传间隔
  final Duration uploadInterval;

  /// 是否匿名化
  final bool anonymize;

  /// 差分隐私噪声级别
  final double privacyNoiseLevel;

  const CollaborativeLearningConfig({
    this.enabled = false,
    this.minLocalSamples = 50,
    this.uploadInterval = const Duration(days: 1),
    this.anonymize = true,
    this.privacyNoiseLevel = 0.1,
  });
}

/// 协同学习服务
///
/// 实现设计文档第18.1.1.6节的协同学习能力
/// 支持：
/// - 本地学习结果聚合
/// - 差分隐私保护
/// - 联邦学习模型同步
class CollaborativeLearningService extends ChangeNotifier {
  /// 配置
  CollaborativeLearningConfig _config;

  /// 本地模型训练器
  final LocalModelTrainer _localTrainer;

  /// 待上传的学习增量
  final List<Map<String, dynamic>> _pendingUpdates = [];

  /// 上次同步时间
  DateTime? _lastSyncAt;

  CollaborativeLearningService({
    CollaborativeLearningConfig? config,
    LocalModelTrainer? localTrainer,
  })  : _config = config ?? const CollaborativeLearningConfig(),
        _localTrainer = localTrainer ?? LocalModelTrainer();

  CollaborativeLearningConfig get config => _config;
  DateTime? get lastSyncAt => _lastSyncAt;
  bool get hasPendingUpdates => _pendingUpdates.isNotEmpty;

  /// 更新配置
  void updateConfig(CollaborativeLearningConfig config) {
    _config = config;
    notifyListeners();
  }

  /// 提交本地学习结果
  Future<void> submitLocalLearning(List<VoiceIntentSample> samples) async {
    if (!_config.enabled || samples.length < _config.minLocalSamples) {
      return;
    }

    // 导出本地模型参数
    final modelData = await _localTrainer.exportModel();

    // 应用差分隐私
    if (_config.anonymize) {
      _applyDifferentialPrivacy(modelData);
    }

    _pendingUpdates.add({
      'timestamp': DateTime.now().toIso8601String(),
      'sampleCount': samples.length,
      'modelDelta': modelData,
    });

    notifyListeners();
  }

  /// 同步全局模型
  Future<bool> syncGlobalModel() async {
    if (!_config.enabled) return false;

    try {
      // 这里应该调用后端API
      // 目前是占位实现
      debugPrint('CollaborativeLearningService: Syncing global model...');

      // 上传本地更新
      if (_pendingUpdates.isNotEmpty) {
        // await _uploadUpdates(_pendingUpdates);
        _pendingUpdates.clear();
      }

      // 下载全局模型更新
      // final globalUpdate = await _downloadGlobalUpdate();
      // if (globalUpdate != null) {
      //   await _localTrainer.importModel(globalUpdate);
      // }

      _lastSyncAt = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CollaborativeLearningService sync error: $e');
      return false;
    }
  }

  /// 应用差分隐私
  void _applyDifferentialPrivacy(Map<String, dynamic> modelData) {
    // 对模型参数添加拉普拉斯噪声
    final likelihoods = modelData['featureLikelihoods'] as Map?;
    if (likelihoods == null) return;

    final random = DateTime.now().microsecondsSinceEpoch;
    for (final classEntry in likelihoods.entries) {
      final features = classEntry.value as Map;
      for (final featKey in features.keys.toList()) {
        final originalValue = features[featKey] as double;
        // 添加拉普拉斯噪声
        final noise = _laplacianNoise(random, _config.privacyNoiseLevel);
        features[featKey] = (originalValue + noise).clamp(0.0, 1.0);
      }
    }
  }

  /// 生成拉普拉斯噪声
  double _laplacianNoise(int seed, double scale) {
    // 简化的拉普拉斯分布采样
    final u = ((seed % 1000) / 1000.0) - 0.5;
    if (u == 0) return 0;
    final sign = u >= 0 ? 1.0 : -1.0;
    return -scale * sign * (u.abs() * 2).clamp(0.001, 1.0);
  }

  /// 获取学习统计
  Map<String, dynamic> getStatistics() {
    return {
      'enabled': _config.enabled,
      'pendingUpdates': _pendingUpdates.length,
      'lastSyncAt': _lastSyncAt?.toIso8601String(),
      'privacyLevel': _config.privacyNoiseLevel,
    };
  }
}
