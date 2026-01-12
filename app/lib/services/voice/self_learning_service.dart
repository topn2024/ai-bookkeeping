import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 自学习服务
///
/// 实现语音意图识别的自学习能力：
/// 1. 采集用户反馈（确认/修改/取消）
/// 2. 挖掘高频模式
/// 3. 生成个性化规则
/// 4. 评估学习效果
///
/// 对应设计文档：第18.1节 意图识别自学习系统架构
class SelfLearningService extends ChangeNotifier {
  static final SelfLearningService _instance = SelfLearningService._internal();
  factory SelfLearningService() => _instance;
  SelfLearningService._internal();

  /// 样本存储
  final List<LearningSample> _samples = [];

  /// 学习到的规则
  final List<LearnedRule> _learnedRules = [];

  /// 同义词映射（学习发现）
  final Map<String, Set<String>> _synonyms = {};

  /// 学习指标
  LearningMetrics _metrics = LearningMetrics.empty();

  /// 最大样本数
  static const int maxSamples = 1000;

  /// 规则生成的最小样本数
  static const int minSamplesForRuleGeneration = 10;

  /// 模式匹配的最小频率
  static const int minPatternFrequency = 3;

  /// 规则置信度阈值
  static const double ruleConfidenceThreshold = 0.7;

  /// 获取学习指标
  LearningMetrics get metrics => _metrics;

  /// 获取学习到的规则
  List<LearnedRule> get learnedRules => List.unmodifiable(_learnedRules);

  /// 获取样本数量
  int get sampleCount => _samples.length;

  /// 初始化
  Future<void> initialize() async {
    await _loadFromStorage();
    _updateMetrics();
    debugPrint('[SelfLearning] Initialized with ${_samples.length} samples, ${_learnedRules.length} rules');
  }

  // ═══════════════════════════════════════════════════════════════
  // 反馈采集
  // ═══════════════════════════════════════════════════════════════

  /// 记录用户确认（正样本）
  void recordConfirmation({
    required String input,
    required String recognizedIntent,
    required String recognitionSource,
    Map<String, dynamic>? extractedEntities,
  }) {
    final sample = LearningSample(
      input: input,
      recognizedIntent: recognizedIntent,
      recognitionSource: recognitionSource,
      extractedEntities: extractedEntities,
      feedbackType: FeedbackType.confirmed,
      timestamp: DateTime.now(),
      quality: SampleQuality.positive,
    );

    _addSample(sample);
    _updateRuleConfidence(input, recognizedIntent, isPositive: true);
    debugPrint('[SelfLearning] Recorded confirmation: $input -> $recognizedIntent');
  }

  /// 记录用户修改（弱负样本，但包含修正信息）
  void recordModification({
    required String input,
    required String originalIntent,
    required String correctedIntent,
    String? recognitionSource,
    Map<String, dynamic>? originalEntities,
    Map<String, dynamic>? correctedEntities,
  }) {
    final sample = LearningSample(
      input: input,
      recognizedIntent: originalIntent,
      correctedIntent: correctedIntent,
      recognitionSource: recognitionSource,
      extractedEntities: originalEntities,
      correctedEntities: correctedEntities,
      feedbackType: FeedbackType.modified,
      timestamp: DateTime.now(),
      quality: SampleQuality.needsImprovement,
    );

    _addSample(sample);
    _updateRuleConfidence(input, originalIntent, isPositive: false);

    // 记录可能的同义表达
    _learnSynonym(input, correctedIntent);

    debugPrint('[SelfLearning] Recorded modification: $input ($originalIntent -> $correctedIntent)');
  }

  /// 记录用户取消（负样本）
  void recordCancellation({
    required String input,
    required String recognizedIntent,
    String? recognitionSource,
  }) {
    final sample = LearningSample(
      input: input,
      recognizedIntent: recognizedIntent,
      recognitionSource: recognitionSource,
      feedbackType: FeedbackType.cancelled,
      timestamp: DateTime.now(),
      quality: SampleQuality.negative,
    );

    _addSample(sample);
    _updateRuleConfidence(input, recognizedIntent, isPositive: false);
    debugPrint('[SelfLearning] Recorded cancellation: $input');
  }

  /// 记录执行成功（弱正样本）
  void recordSuccess({
    required String input,
    required String executedIntent,
    String? recognitionSource,
  }) {
    final sample = LearningSample(
      input: input,
      recognizedIntent: executedIntent,
      recognitionSource: recognitionSource,
      feedbackType: FeedbackType.executionSuccess,
      timestamp: DateTime.now(),
      quality: SampleQuality.weakPositive,
    );

    _addSample(sample);
    _updateRuleConfidence(input, executedIntent, isPositive: true);
  }

  // ═══════════════════════════════════════════════════════════════
  // 模式挖掘
  // ═══════════════════════════════════════════════════════════════

  /// 触发学习（可手动或定时调用）
  Future<LearningResult> triggerLearning() async {
    if (_samples.length < minSamplesForRuleGeneration) {
      return LearningResult(
        success: false,
        message: '样本数量不足（当前${_samples.length}，需要$minSamplesForRuleGeneration）',
        newRulesCount: 0,
      );
    }

    debugPrint('[SelfLearning] Starting learning process with ${_samples.length} samples');

    int newRulesCount = 0;

    // 1. 挖掘高频模式
    final patterns = _mineFrequentPatterns();
    debugPrint('[SelfLearning] Found ${patterns.length} frequent patterns');

    // 2. 为高频模式生成规则
    for (final pattern in patterns) {
      final rule = _generateRuleFromPattern(pattern);
      if (rule != null && !_isDuplicateRule(rule)) {
        _learnedRules.add(rule);
        newRulesCount++;
      }
    }

    // 3. 分析修改样本，发现同义表达
    _analyzeModifications();

    // 4. 更新指标
    _updateMetrics();

    // 5. 持久化
    await _saveToStorage();

    debugPrint('[SelfLearning] Learning complete: $newRulesCount new rules');

    return LearningResult(
      success: true,
      message: '学习完成',
      newRulesCount: newRulesCount,
      totalRulesCount: _learnedRules.length,
    );
  }

  /// 挖掘高频模式
  List<PatternCandidate> _mineFrequentPatterns() {
    final patternCounts = <String, PatternCandidate>{};

    // 统计确认样本中的输入模式
    final confirmedSamples = _samples.where(
      (s) => s.feedbackType == FeedbackType.confirmed || s.feedbackType == FeedbackType.executionSuccess,
    );

    for (final sample in confirmedSamples) {
      // 简化输入，提取模式
      final pattern = _extractPattern(sample.input);
      final intent = sample.recognizedIntent;

      final key = '$pattern|$intent';
      if (patternCounts.containsKey(key)) {
        patternCounts[key]!.frequency++;
        patternCounts[key]!.examples.add(sample.input);
      } else {
        patternCounts[key] = PatternCandidate(
          pattern: pattern,
          intent: intent,
          frequency: 1,
          examples: [sample.input],
        );
      }
    }

    // 返回频率超过阈值的模式
    return patternCounts.values
        .where((p) => p.frequency >= minPatternFrequency)
        .toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
  }

  /// 提取模式（简化输入，替换具体值为占位符）
  String _extractPattern(String input) {
    var pattern = input;

    // 替换数字为占位符
    pattern = pattern.replaceAll(RegExp(r'\d+\.?\d*'), '{NUM}');

    // 替换常见分类名
    final categories = ['餐饮', '交通', '购物', '娱乐', '居住', '医疗', '教育', '通讯'];
    for (final cat in categories) {
      pattern = pattern.replaceAll(cat, '{CATEGORY}');
    }

    // 替换时间词
    pattern = pattern.replaceAll(RegExp(r'(今天|昨天|前天|上周|本周|本月|上月)'), '{TIME}');

    return pattern;
  }

  /// 从模式生成规则
  LearnedRule? _generateRuleFromPattern(PatternCandidate pattern) {
    if (pattern.examples.length < minPatternFrequency) return null;

    // 计算置信度
    final totalSamplesWithPattern = _samples.where((s) {
      final p = _extractPattern(s.input);
      return p == pattern.pattern;
    }).length;

    final positiveCount = _samples.where((s) {
      final p = _extractPattern(s.input);
      return p == pattern.pattern &&
          (s.feedbackType == FeedbackType.confirmed || s.feedbackType == FeedbackType.executionSuccess);
    }).length;

    final confidence = totalSamplesWithPattern > 0 ? positiveCount / totalSamplesWithPattern : 0.0;

    if (confidence < ruleConfidenceThreshold) return null;

    return LearnedRule(
      id: 'learned_${DateTime.now().millisecondsSinceEpoch}',
      pattern: pattern.pattern,
      intent: pattern.intent,
      confidence: confidence,
      frequency: pattern.frequency,
      examples: pattern.examples.take(5).toList(),
      createdAt: DateTime.now(),
    );
  }

  /// 检查是否重复规则
  bool _isDuplicateRule(LearnedRule rule) {
    return _learnedRules.any((r) => r.pattern == rule.pattern && r.intent == rule.intent);
  }

  /// 分析修改样本
  void _analyzeModifications() {
    final modifications = _samples.where((s) => s.feedbackType == FeedbackType.modified);

    for (final sample in modifications) {
      if (sample.correctedIntent != null) {
        _learnSynonym(sample.input, sample.correctedIntent!);
      }
    }
  }

  /// 学习同义表达
  void _learnSynonym(String input, String intent) {
    // 简单的同义词学习：记录输入到意图的映射
    if (!_synonyms.containsKey(intent)) {
      _synonyms[intent] = {};
    }
    _synonyms[intent]!.add(input.toLowerCase());
  }

  // ═══════════════════════════════════════════════════════════════
  // 规则应用
  // ═══════════════════════════════════════════════════════════════

  /// 尝试使用学习规则匹配
  LearnedRuleMatch? tryMatchLearnedRule(String input) {
    final inputPattern = _extractPattern(input);

    for (final rule in _learnedRules) {
      if (rule.pattern == inputPattern) {
        return LearnedRuleMatch(
          rule: rule,
          input: input,
          matchedPattern: inputPattern,
        );
      }
    }

    return null;
  }

  /// 获取同义表达
  Set<String>? getSynonyms(String intent) {
    return _synonyms[intent];
  }

  // ═══════════════════════════════════════════════════════════════
  // 指标更新
  // ═══════════════════════════════════════════════════════════════

  void _updateRuleConfidence(String input, String intent, {required bool isPositive}) {
    final inputPattern = _extractPattern(input);

    for (var i = 0; i < _learnedRules.length; i++) {
      if (_learnedRules[i].pattern == inputPattern && _learnedRules[i].intent == intent) {
        final rule = _learnedRules[i];
        final newConfidence = isPositive
            ? (rule.confidence * 0.9 + 0.1) // 增加置信度
            : (rule.confidence * 0.9); // 降低置信度

        _learnedRules[i] = rule.copyWith(
          confidence: newConfidence.clamp(0.0, 1.0),
          frequency: rule.frequency + 1,
        );
        break;
      }
    }
  }

  void _updateMetrics() {
    final totalSamples = _samples.length;
    final confirmedCount = _samples.where((s) => s.feedbackType == FeedbackType.confirmed).length;
    final modifiedCount = _samples.where((s) => s.feedbackType == FeedbackType.modified).length;
    final cancelledCount = _samples.where((s) => s.feedbackType == FeedbackType.cancelled).length;

    final ruleMatchCount = _samples.where((s) => s.recognitionSource == 'learnedRule').length;

    _metrics = LearningMetrics(
      totalSamples: totalSamples,
      confirmedCount: confirmedCount,
      modifiedCount: modifiedCount,
      cancelledCount: cancelledCount,
      accuracy: totalSamples > 0 ? confirmedCount / totalSamples : 0.0,
      modificationRate: totalSamples > 0 ? modifiedCount / totalSamples : 0.0,
      ruleCount: _learnedRules.length,
      ruleMatchRate: totalSamples > 0 ? ruleMatchCount / totalSamples : 0.0,
      lastLearningTime: DateTime.now(),
    );

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // 存储
  // ═══════════════════════════════════════════════════════════════

  void _addSample(LearningSample sample) {
    _samples.add(sample);
    if (_samples.length > maxSamples) {
      _samples.removeAt(0);
    }
    _updateMetrics();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载样本
      final samplesJson = prefs.getString('self_learning_samples');
      if (samplesJson != null) {
        final List<dynamic> list = jsonDecode(samplesJson);
        _samples.clear();
        _samples.addAll(list.map((e) => LearningSample.fromJson(e)));
      }

      // 加载规则
      final rulesJson = prefs.getString('self_learning_rules');
      if (rulesJson != null) {
        final List<dynamic> list = jsonDecode(rulesJson);
        _learnedRules.clear();
        _learnedRules.addAll(list.map((e) => LearnedRule.fromJson(e)));
      }

      // 加载同义词
      final synonymsJson = prefs.getString('self_learning_synonyms');
      if (synonymsJson != null) {
        final Map<String, dynamic> map = jsonDecode(synonymsJson);
        _synonyms.clear();
        map.forEach((key, value) {
          _synonyms[key] = Set<String>.from(value as List);
        });
      }
    } catch (e) {
      debugPrint('[SelfLearning] Error loading from storage: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存样本（只保留最近的）
      final recentSamples = _samples.take(maxSamples).toList();
      await prefs.setString(
        'self_learning_samples',
        jsonEncode(recentSamples.map((e) => e.toJson()).toList()),
      );

      // 保存规则
      await prefs.setString(
        'self_learning_rules',
        jsonEncode(_learnedRules.map((e) => e.toJson()).toList()),
      );

      // 保存同义词
      final synonymsMap = <String, List<String>>{};
      _synonyms.forEach((key, value) {
        synonymsMap[key] = value.toList();
      });
      await prefs.setString('self_learning_synonyms', jsonEncode(synonymsMap));
    } catch (e) {
      debugPrint('[SelfLearning] Error saving to storage: $e');
    }
  }

  /// 清除所有学习数据
  Future<void> clearAllData() async {
    _samples.clear();
    _learnedRules.clear();
    _synonyms.clear();
    _metrics = LearningMetrics.empty();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('self_learning_samples');
    await prefs.remove('self_learning_rules');
    await prefs.remove('self_learning_synonyms');

    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════════════

/// 反馈类型
enum FeedbackType {
  confirmed, // 用户确认
  modified, // 用户修改
  cancelled, // 用户取消
  executionSuccess, // 执行成功
}

/// 样本质量
enum SampleQuality {
  positive, // 正样本
  weakPositive, // 弱正样本
  negative, // 负样本
  needsImprovement, // 需要改进
}

/// 学习样本
class LearningSample {
  final String input;
  final String recognizedIntent;
  final String? correctedIntent;
  final String? recognitionSource;
  final Map<String, dynamic>? extractedEntities;
  final Map<String, dynamic>? correctedEntities;
  final FeedbackType feedbackType;
  final DateTime timestamp;
  final SampleQuality quality;

  const LearningSample({
    required this.input,
    required this.recognizedIntent,
    this.correctedIntent,
    this.recognitionSource,
    this.extractedEntities,
    this.correctedEntities,
    required this.feedbackType,
    required this.timestamp,
    required this.quality,
  });

  Map<String, dynamic> toJson() => {
        'input': input,
        'recognizedIntent': recognizedIntent,
        'correctedIntent': correctedIntent,
        'recognitionSource': recognitionSource,
        'extractedEntities': extractedEntities,
        'correctedEntities': correctedEntities,
        'feedbackType': feedbackType.index,
        'timestamp': timestamp.toIso8601String(),
        'quality': quality.index,
      };

  factory LearningSample.fromJson(Map<String, dynamic> json) => LearningSample(
        input: json['input'] as String,
        recognizedIntent: json['recognizedIntent'] as String,
        correctedIntent: json['correctedIntent'] as String?,
        recognitionSource: json['recognitionSource'] as String?,
        extractedEntities: json['extractedEntities'] as Map<String, dynamic>?,
        correctedEntities: json['correctedEntities'] as Map<String, dynamic>?,
        feedbackType: FeedbackType.values[json['feedbackType'] as int],
        timestamp: DateTime.parse(json['timestamp'] as String),
        quality: SampleQuality.values[json['quality'] as int],
      );
}

/// 学习到的规则
class LearnedRule {
  final String id;
  final String pattern;
  final String intent;
  final double confidence;
  final int frequency;
  final List<String> examples;
  final DateTime createdAt;

  const LearnedRule({
    required this.id,
    required this.pattern,
    required this.intent,
    required this.confidence,
    required this.frequency,
    required this.examples,
    required this.createdAt,
  });

  LearnedRule copyWith({
    double? confidence,
    int? frequency,
  }) =>
      LearnedRule(
        id: id,
        pattern: pattern,
        intent: intent,
        confidence: confidence ?? this.confidence,
        frequency: frequency ?? this.frequency,
        examples: examples,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pattern': pattern,
        'intent': intent,
        'confidence': confidence,
        'frequency': frequency,
        'examples': examples,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LearnedRule.fromJson(Map<String, dynamic> json) => LearnedRule(
        id: json['id'] as String,
        pattern: json['pattern'] as String,
        intent: json['intent'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        frequency: json['frequency'] as int,
        examples: List<String>.from(json['examples'] as List),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// 模式候选
class PatternCandidate {
  final String pattern;
  final String intent;
  int frequency;
  final List<String> examples;

  PatternCandidate({
    required this.pattern,
    required this.intent,
    required this.frequency,
    required this.examples,
  });
}

/// 学习规则匹配结果
class LearnedRuleMatch {
  final LearnedRule rule;
  final String input;
  final String matchedPattern;

  const LearnedRuleMatch({
    required this.rule,
    required this.input,
    required this.matchedPattern,
  });
}

/// 学习指标
class LearningMetrics {
  final int totalSamples;
  final int confirmedCount;
  final int modifiedCount;
  final int cancelledCount;
  final double accuracy;
  final double modificationRate;
  final int ruleCount;
  final double ruleMatchRate;
  final DateTime? lastLearningTime;

  const LearningMetrics({
    required this.totalSamples,
    required this.confirmedCount,
    required this.modifiedCount,
    required this.cancelledCount,
    required this.accuracy,
    required this.modificationRate,
    required this.ruleCount,
    required this.ruleMatchRate,
    this.lastLearningTime,
  });

  factory LearningMetrics.empty() => const LearningMetrics(
        totalSamples: 0,
        confirmedCount: 0,
        modifiedCount: 0,
        cancelledCount: 0,
        accuracy: 0.0,
        modificationRate: 0.0,
        ruleCount: 0,
        ruleMatchRate: 0.0,
      );
}

/// 学习结果
class LearningResult {
  final bool success;
  final String message;
  final int newRulesCount;
  final int? totalRulesCount;

  const LearningResult({
    required this.success,
    required this.message,
    required this.newRulesCount,
    this.totalRulesCount,
  });
}
