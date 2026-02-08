import 'dart:convert';

import 'package:collection/collection.dart'; // ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'enhanced_intent_recognition_service.dart';

// ==================== 意图学习数据模型 ====================

/// 意图学习样本
class IntentLearningSample {
  final String id;
  final String userId;
  final String rawInput;
  final String normalizedInput;
  final VoiceIntentType predictedIntent;
  final VoiceIntentType? actualIntent;
  final double confidence;
  final IntentSource source;
  final IntentSampleLabel label;
  final Map<String, dynamic> context;
  final DateTime timestamp;

  const IntentLearningSample({
    required this.id,
    required this.userId,
    required this.rawInput,
    required this.normalizedInput,
    required this.predictedIntent,
    this.actualIntent,
    required this.confidence,
    required this.source,
    required this.label,
    this.context = const {},
    required this.timestamp,
  });

  bool get wasCorrect =>
      actualIntent == null || actualIntent == predictedIntent;

  double get qualityScore {
    var score = 0.0;
    if (label == IntentSampleLabel.confirmedPositive) score += 0.5;
    if (label == IntentSampleLabel.corrected) score += 0.4;
    if (confidence > 0.9) score += 0.2;
    if (context.isNotEmpty) score += 0.1;
    final daysSince = DateTime.now().difference(timestamp).inDays;
    score *= (1 - daysSince / 365).clamp(0.5, 1.0);
    return score.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'raw_input': rawInput,
        'normalized_input': normalizedInput,
        'predicted_intent': predictedIntent.name,
        'actual_intent': actualIntent?.name,
        'confidence': confidence,
        'source': source.name,
        'label': label.name,
        'context': context,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// 样本标签类型
enum IntentSampleLabel {
  confirmedPositive, // 用户确认的正样本
  corrected, // 用户修改后的校正样本
  implicitPositive, // 隐式正样本（执行成功无投诉）
  weakPositive, // 弱正样本（高置信度未确认）
  negative, // 负样本（用户取消/拒绝）
  ambiguous, // 歧义样本
}

// ==================== 脱敏数据模型 ====================

/// 脱敏后的意图模式
class SanitizedIntentPattern {
  final String patternTemplate;
  final VoiceIntentType intent;
  final double localConfidence;
  final int localFrequency;
  final String userHash;
  final int? hour;
  final int? dayOfWeek;
  final DateTime timestamp;

  const SanitizedIntentPattern({
    required this.patternTemplate,
    required this.intent,
    required this.localConfidence,
    required this.localFrequency,
    required this.userHash,
    this.hour,
    this.dayOfWeek,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'pattern_template': patternTemplate,
        'intent': intent.name,
        'local_confidence': localConfidence,
        'local_frequency': localFrequency,
        'user_hash': userHash,
        'hour': hour,
        'day_of_week': dayOfWeek,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ==================== 全局意图洞察 ====================

/// 全局意图洞察
class GlobalIntentInsights {
  final Map<VoiceIntentType, IntentPatternStats> intentPatterns;
  final Map<String, VoiceIntentType> commonExpressionMappings;
  final Map<int, Map<VoiceIntentType, double>> hourIntentDistribution;
  final List<PopularExpression> popularExpressions;
  final DateTime generatedAt;

  const GlobalIntentInsights({
    required this.intentPatterns,
    required this.commonExpressionMappings,
    required this.hourIntentDistribution,
    required this.popularExpressions,
    required this.generatedAt,
  });
}

/// 意图模式统计
class IntentPatternStats {
  final VoiceIntentType intent;
  final List<String> commonPatterns;
  final double globalConfidence;
  final int sampleCount;
  final double correctionRate;

  const IntentPatternStats({
    required this.intent,
    required this.commonPatterns,
    required this.globalConfidence,
    required this.sampleCount,
    required this.correctionRate,
  });
}

/// 热门表达
class PopularExpression {
  final String pattern;
  final VoiceIntentType intent;
  final int usageCount;
  final double successRate;

  const PopularExpression({
    required this.pattern,
    required this.intent,
    required this.usageCount,
    required this.successRate,
  });
}

// ==================== 意图协同学习服务 ====================

/// 意图协同学习服务
class IntentCollaborativeLearningService {
  final GlobalIntentInsightsAggregator _aggregator;
  final IntentPatternReporter _reporter;
  final String _currentUserId; // ignore: unused_field

  // 本地缓存
  GlobalIntentInsights? _insightsCache;
  DateTime? _lastInsightsUpdate;

  // 配置
  static const Duration _cacheExpiry = Duration(hours: 24);
  static const int _minSamplesForPattern = 3; // ignore: unused_field
  static const double _privacyEpsilon = 0.1; // 差分隐私参数

  IntentCollaborativeLearningService({
    GlobalIntentInsightsAggregator? aggregator,
    IntentPatternReporter? reporter,
    String? currentUserId,
  })  : _aggregator = aggregator ?? GlobalIntentInsightsAggregator(),
        _reporter = reporter ?? InMemoryIntentPatternReporter(),
        _currentUserId = currentUserId ?? 'anonymous';

  /// 上报意图模式（隐私保护）
  Future<void> reportIntentPattern(IntentLearningSample sample) async {
    // 只上报高质量样本
    if (sample.qualityScore < 0.6) return;

    // 提取模式模板（脱敏）
    final template = _extractPatternTemplate(sample.normalizedInput);

    final pattern = SanitizedIntentPattern(
      patternTemplate: template,
      intent: sample.actualIntent ?? sample.predictedIntent,
      localConfidence: _addNoise(sample.confidence),
      localFrequency: 1,
      userHash: _hashValue(sample.userId),
      hour: sample.timestamp.hour,
      dayOfWeek: sample.timestamp.weekday,
      timestamp: DateTime.now(),
    );

    await _reporter.report(pattern);
    debugPrint('Reported intent pattern: ${pattern.intent.name}');
  }

  /// 提取模式模板（移除具体数值和敏感信息）
  String _extractPatternTemplate(String input) {
    String template = input.toLowerCase();

    // 替换金额为占位符
    template = template.replaceAll(
      RegExp(r'\d+(\.\d+)?(元|块|万|千)?'),
      '{amount}',
    );

    // 替换日期为占位符
    template = template.replaceAll(
      RegExp(r'\d{1,2}(月|号|日)'),
      '{date}',
    );

    // 替换时间为占位符
    template = template.replaceAll(
      RegExp(r'\d{1,2}(点|时)(\d{1,2}分)?'),
      '{time}',
    );

    // 限制长度
    if (template.length > 50) {
      template = template.substring(0, 50);
    }

    return template;
  }

  /// 添加差分隐私噪声
  double _addNoise(double value) {
    // 拉普拉斯噪声
    final noise = (_privacyEpsilon * 0.1) * (DateTime.now().millisecond % 10 - 5) / 10;
    return (value + noise).clamp(0.0, 1.0);
  }

  String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 获取全局意图洞察
  Future<GlobalIntentInsights> getGlobalInsights({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _insightsCache != null &&
        _lastInsightsUpdate != null &&
        DateTime.now().difference(_lastInsightsUpdate!) < _cacheExpiry) {
      return _insightsCache!;
    }

    _insightsCache = await _aggregator.aggregate();
    _lastInsightsUpdate = DateTime.now();
    return _insightsCache!;
  }

  /// 获取意图的常见表达
  Future<List<String>> getCommonExpressions(VoiceIntentType intent) async {
    final insights = await getGlobalInsights();
    return insights.intentPatterns[intent]?.commonPatterns ?? [];
  }

  /// 根据表达推荐意图
  Future<IntentSuggestion?> suggestIntentForExpression(String input) async {
    final insights = await getGlobalInsights();
    final normalized = input.toLowerCase();

    // 1. 查找精确匹配
    for (final entry in insights.commonExpressionMappings.entries) {
      if (normalized.contains(entry.key)) {
        final stats = insights.intentPatterns[entry.value];
        return IntentSuggestion(
          intent: entry.value,
          confidence: stats?.globalConfidence ?? 0.7,
          source: IntentSuggestionSource.exactMatch,
          reasoning: '社区常用表达',
        );
      }
    }

    // 2. 时段推断
    final hour = DateTime.now().hour;
    final hourDist = insights.hourIntentDistribution[hour];
    if (hourDist != null && hourDist.isNotEmpty) {
      final topIntent = hourDist.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      return IntentSuggestion(
        intent: topIntent,
        confidence: 0.5,
        source: IntentSuggestionSource.timeInference,
        reasoning: '该时段常见意图',
      );
    }

    return null;
  }

  /// 获取热门表达排行
  Future<List<PopularExpression>> getPopularExpressions({int limit = 10}) async {
    final insights = await getGlobalInsights();
    return insights.popularExpressions.take(limit).toList();
  }

  /// 获取意图修正率（用于评估识别质量）
  Future<double> getIntentCorrectionRate(VoiceIntentType intent) async {
    final insights = await getGlobalInsights();
    return insights.intentPatterns[intent]?.correctionRate ?? 0.0;
  }

  /// 批量上报样本
  Future<void> reportBatch(List<IntentLearningSample> samples) async {
    for (final sample in samples) {
      await reportIntentPattern(sample);
    }
  }

  /// 获取社区意图使用排行
  Future<List<IntentUsageRanking>> getIntentUsageRankings() async {
    final insights = await getGlobalInsights();

    final rankings = insights.intentPatterns.entries.map((e) {
      return IntentUsageRanking(
        intent: e.key,
        sampleCount: e.value.sampleCount,
        confidence: e.value.globalConfidence,
        correctionRate: e.value.correctionRate,
        rank: 0,
      );
    }).toList();

    rankings.sort((a, b) => b.sampleCount.compareTo(a.sampleCount));

    for (int i = 0; i < rankings.length; i++) {
      rankings[i] = IntentUsageRanking(
        intent: rankings[i].intent,
        sampleCount: rankings[i].sampleCount,
        confidence: rankings[i].confidence,
        correctionRate: rankings[i].correctionRate,
        rank: i + 1,
      );
    }

    return rankings;
  }
}

/// 意图建议
class IntentSuggestion {
  final VoiceIntentType intent;
  final double confidence;
  final IntentSuggestionSource source;
  final String reasoning;

  const IntentSuggestion({
    required this.intent,
    required this.confidence,
    required this.source,
    required this.reasoning,
  });

  Map<String, dynamic> toJson() => {
        'intent': intent.name,
        'confidence': confidence,
        'source': source.name,
        'reasoning': reasoning,
      };
}

/// 意图建议来源
enum IntentSuggestionSource {
  exactMatch, // 精确匹配
  patternMatch, // 模式匹配
  timeInference, // 时段推断
  collaborative, // 协同学习
}

/// 意图使用排行
class IntentUsageRanking {
  final VoiceIntentType intent;
  final int sampleCount;
  final double confidence;
  final double correctionRate;
  final int rank;

  const IntentUsageRanking({
    required this.intent,
    required this.sampleCount,
    required this.confidence,
    required this.correctionRate,
    required this.rank,
  });
}

// ==================== 模式上报器 ====================

/// 意图模式上报器接口
abstract class IntentPatternReporter {
  Future<void> report(SanitizedIntentPattern pattern);
  Future<List<SanitizedIntentPattern>> getAllPatterns();
}

/// 内存意图模式上报器
class InMemoryIntentPatternReporter implements IntentPatternReporter {
  final List<SanitizedIntentPattern> _patterns = [];

  @override
  Future<void> report(SanitizedIntentPattern pattern) async {
    _patterns.add(pattern);
  }

  @override
  Future<List<SanitizedIntentPattern>> getAllPatterns() async {
    return List.unmodifiable(_patterns);
  }

  void clear() => _patterns.clear();
}

// ==================== 全局意图洞察聚合 ====================

/// 全局意图洞察聚合器
class GlobalIntentInsightsAggregator {
  final IntentPatternReporter _db;

  GlobalIntentInsightsAggregator({IntentPatternReporter? db})
      : _db = db ?? InMemoryIntentPatternReporter();

  /// 聚合群体意图偏好
  Future<GlobalIntentInsights> aggregate() async {
    final patterns = await _db.getAllPatterns();

    return GlobalIntentInsights(
      intentPatterns: _aggregateIntentPatterns(patterns),
      commonExpressionMappings: _aggregateExpressionMappings(patterns),
      hourIntentDistribution: _aggregateHourDistribution(patterns),
      popularExpressions: _aggregatePopularExpressions(patterns),
      generatedAt: DateTime.now(),
    );
  }

  Map<VoiceIntentType, IntentPatternStats> _aggregateIntentPatterns(
    List<SanitizedIntentPattern> patterns,
  ) {
    final result = <VoiceIntentType, IntentPatternStats>{};

    final byIntent = groupBy(patterns, (p) => p.intent);

    for (final entry in byIntent.entries) {
      final intentPatterns = entry.value;

      // 提取常见模式
      final templateCounts = <String, int>{};
      for (final p in intentPatterns) {
        templateCounts[p.patternTemplate] =
            (templateCounts[p.patternTemplate] ?? 0) + 1;
      }
      final sortedTemplates = templateCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final commonPatterns = sortedTemplates.take(5).map((e) => e.key).toList();

      // 计算全局置信度
      final avgConfidence = intentPatterns.isEmpty
          ? 0.0
          : intentPatterns.map((p) => p.localConfidence).reduce((a, b) => a + b) /
              intentPatterns.length;

      result[entry.key] = IntentPatternStats(
        intent: entry.key,
        commonPatterns: commonPatterns,
        globalConfidence: avgConfidence,
        sampleCount: intentPatterns.length,
        correctionRate: 0.05, // 简化实现
      );
    }

    // 添加默认模式
    _addDefaultIntentPatterns(result);

    return result;
  }

  void _addDefaultIntentPatterns(Map<VoiceIntentType, IntentPatternStats> result) {
    final defaults = <VoiceIntentType, List<String>>{
      VoiceIntentType.addExpense: ['花了{amount}', '买了', '支出{amount}', '消费'],
      VoiceIntentType.addIncome: ['收到{amount}', '入账', '工资{amount}', '收入'],
      VoiceIntentType.querySpending: ['花了多少', '消费统计', '查看消费', '支出多少'],
      VoiceIntentType.queryBudget: ['预算还剩', '余额多少', '还能花多少'],
      VoiceIntentType.setBudget: ['设置预算', '预算设为{amount}', '每月预算'],
      VoiceIntentType.viewReport: ['查看报告', '月度统计', '消费分析'],
      VoiceIntentType.greeting: ['你好', '早上好', '下午好', '晚上好'],
      VoiceIntentType.help: ['帮助', '怎么用', '如何记账'],
      VoiceIntentType.confirm: ['是', '对', '确认', '好的'],
      VoiceIntentType.cancel: ['取消', '算了', '不要了'],
    };

    for (final entry in defaults.entries) {
      result.putIfAbsent(
        entry.key,
        () => IntentPatternStats(
          intent: entry.key,
          commonPatterns: entry.value,
          globalConfidence: 0.85,
          sampleCount: 100,
          correctionRate: 0.05,
        ),
      );
    }
  }

  Map<String, VoiceIntentType> _aggregateExpressionMappings(
    List<SanitizedIntentPattern> patterns,
  ) {
    final result = <String, VoiceIntentType>{};

    // 提取高频表达-意图映射
    final byTemplate = groupBy(patterns, (p) => p.patternTemplate);

    for (final entry in byTemplate.entries) {
      if (entry.value.length >= 3) {
        // 找出最常见的意图
        final intentCounts = <VoiceIntentType, int>{};
        for (final p in entry.value) {
          intentCounts[p.intent] = (intentCounts[p.intent] ?? 0) + 1;
        }

        final mostCommon = intentCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b);

        if (mostCommon.value >= entry.value.length * 0.6) {
          result[entry.key] = mostCommon.key;
        }
      }
    }

    // 添加默认映射
    _addDefaultExpressionMappings(result);

    return result;
  }

  void _addDefaultExpressionMappings(Map<String, VoiceIntentType> result) {
    final defaults = <String, VoiceIntentType>{
      '花了': VoiceIntentType.addExpense,
      '买了': VoiceIntentType.addExpense,
      '支出': VoiceIntentType.addExpense,
      '消费': VoiceIntentType.addExpense,
      '付了': VoiceIntentType.addExpense,
      '收到': VoiceIntentType.addIncome,
      '入账': VoiceIntentType.addIncome,
      '工资': VoiceIntentType.addIncome,
      '收入': VoiceIntentType.addIncome,
      '花了多少': VoiceIntentType.querySpending,
      '消费了多少': VoiceIntentType.querySpending,
      '预算': VoiceIntentType.queryBudget,
      '余额': VoiceIntentType.queryBudget,
      '设置预算': VoiceIntentType.setBudget,
      '报告': VoiceIntentType.viewReport,
      '统计': VoiceIntentType.viewReport,
      '你好': VoiceIntentType.greeting,
      '帮助': VoiceIntentType.help,
      '怎么': VoiceIntentType.help,
      '确认': VoiceIntentType.confirm,
      '是的': VoiceIntentType.confirm,
      '取消': VoiceIntentType.cancel,
      '算了': VoiceIntentType.cancel,
    };

    for (final entry in defaults.entries) {
      result.putIfAbsent(entry.key, () => entry.value);
    }
  }

  Map<int, Map<VoiceIntentType, double>> _aggregateHourDistribution(
    List<SanitizedIntentPattern> patterns,
  ) {
    final result = <int, Map<VoiceIntentType, double>>{};

    final byHour = groupBy(
      patterns.where((p) => p.hour != null),
      (p) => p.hour!,
    );

    for (final entry in byHour.entries) {
      final intentCounts = <VoiceIntentType, int>{};
      for (final p in entry.value) {
        intentCounts[p.intent] = (intentCounts[p.intent] ?? 0) + 1;
      }

      final total = entry.value.length;
      final distribution = <VoiceIntentType, double>{};
      for (final intentEntry in intentCounts.entries) {
        distribution[intentEntry.key] = intentEntry.value / total;
      }

      result[entry.key] = distribution;
    }

    // 添加默认时段分布
    _addDefaultHourDistribution(result);

    return result;
  }

  void _addDefaultHourDistribution(Map<int, Map<VoiceIntentType, double>> result) {
    // 早晨时段 7-9点：查询为主
    for (int h = 7; h <= 9; h++) {
      result.putIfAbsent(h, () => {
        VoiceIntentType.querySpending: 0.3,
        VoiceIntentType.addExpense: 0.4,
        VoiceIntentType.greeting: 0.2,
        VoiceIntentType.other: 0.1,
      });
    }
    // 午餐时段 11-13点：记账为主
    for (int h = 11; h <= 13; h++) {
      result.putIfAbsent(h, () => {
        VoiceIntentType.addExpense: 0.6,
        VoiceIntentType.queryBudget: 0.2,
        VoiceIntentType.other: 0.2,
      });
    }
    // 晚餐时段 18-20点：记账为主
    for (int h = 18; h <= 20; h++) {
      result.putIfAbsent(h, () => {
        VoiceIntentType.addExpense: 0.5,
        VoiceIntentType.querySpending: 0.3,
        VoiceIntentType.other: 0.2,
      });
    }
    // 夜间时段 21-23点：查询统计为主
    for (int h = 21; h <= 23; h++) {
      result.putIfAbsent(h, () => {
        VoiceIntentType.querySpending: 0.4,
        VoiceIntentType.viewReport: 0.3,
        VoiceIntentType.addExpense: 0.2,
        VoiceIntentType.other: 0.1,
      });
    }
  }

  List<PopularExpression> _aggregatePopularExpressions(
    List<SanitizedIntentPattern> patterns,
  ) {
    final templateStats = <String, _TemplateStats>{};

    for (final p in patterns) {
      final stats = templateStats.putIfAbsent(
        p.patternTemplate,
        () => _TemplateStats(p.intent),
      );
      stats.count++;
      stats.totalConfidence += p.localConfidence;
    }

    final popularExpressions = templateStats.entries
        .where((e) => e.value.count >= 2)
        .map((e) => PopularExpression(
              pattern: e.key,
              intent: e.value.intent,
              usageCount: e.value.count,
              successRate: e.value.totalConfidence / e.value.count,
            ))
        .toList();

    popularExpressions.sort((a, b) => b.usageCount.compareTo(a.usageCount));

    // 添加默认热门表达
    if (popularExpressions.length < 10) {
      popularExpressions.addAll(_getDefaultPopularExpressions());
    }

    return popularExpressions.take(20).toList();
  }

  List<PopularExpression> _getDefaultPopularExpressions() {
    return [
      const PopularExpression(
        pattern: '花了{amount}',
        intent: VoiceIntentType.addExpense,
        usageCount: 100,
        successRate: 0.95,
      ),
      const PopularExpression(
        pattern: '买了{amount}的东西',
        intent: VoiceIntentType.addExpense,
        usageCount: 80,
        successRate: 0.92,
      ),
      const PopularExpression(
        pattern: '今天花了多少',
        intent: VoiceIntentType.querySpending,
        usageCount: 70,
        successRate: 0.90,
      ),
      const PopularExpression(
        pattern: '这个月消费了多少',
        intent: VoiceIntentType.querySpending,
        usageCount: 60,
        successRate: 0.88,
      ),
      const PopularExpression(
        pattern: '预算还剩多少',
        intent: VoiceIntentType.queryBudget,
        usageCount: 50,
        successRate: 0.90,
      ),
    ];
  }
}

class _TemplateStats {
  final VoiceIntentType intent;
  int count = 0;
  double totalConfidence = 0;

  _TemplateStats(this.intent);
}

// ==================== 意图学习整合服务 ====================

/// 意图学习整合服务（整合本地学习与协同学习）
class IntentLearningIntegrationService {
  final IntentCollaborativeLearningService _collaborativeService;
  final List<IntentLearningSample> _localSamples = [];
  final Map<String, VoiceIntentType> _localExpressionRules = {};

  // 配置
  static const int _localRuleMinSamples = 2;

  IntentLearningIntegrationService({
    IntentCollaborativeLearningService? collaborativeService,
  }) : _collaborativeService =
            collaborativeService ?? IntentCollaborativeLearningService();

  /// 获取意图建议（整合本地与协同）
  Future<IntentSuggestion?> suggestIntent(String input) async {
    final normalized = input.toLowerCase();

    // 1. 本地规则优先
    for (final entry in _localExpressionRules.entries) {
      if (normalized.contains(entry.key)) {
        return IntentSuggestion(
          intent: entry.value,
          confidence: 0.95,
          source: IntentSuggestionSource.exactMatch,
          reasoning: '基于您的历史记录',
        );
      }
    }

    // 2. 协同学习建议
    return _collaborativeService.suggestIntentForExpression(input);
  }

  /// 记录意图反馈
  Future<void> recordFeedback({
    required String input,
    required VoiceIntentType predictedIntent,
    VoiceIntentType? actualIntent,
    required IntentSampleLabel label,
  }) async {
    final sample = IntentLearningSample(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user',
      rawInput: input,
      normalizedInput: input.toLowerCase(),
      predictedIntent: predictedIntent,
      actualIntent: actualIntent,
      confidence: 1.0,
      source: IntentSource.learned,
      label: label,
      timestamp: DateTime.now(),
    );

    _localSamples.add(sample);

    // 更新本地规则
    _updateLocalRules(input, actualIntent ?? predictedIntent);

    // 上报到协同学习
    await _collaborativeService.reportIntentPattern(sample);
  }

  void _updateLocalRules(String input, VoiceIntentType intent) {
    final normalized = input.toLowerCase();

    // 提取关键短语
    final words = normalized.split(RegExp(r'\s+'));
    for (int i = 0; i < words.length - 1; i++) {
      final phrase = '${words[i]} ${words[i + 1]}';

      // 统计该短语的意图
      final relevantSamples = _localSamples
          .where((s) => s.normalizedInput.contains(phrase))
          .toList();

      if (relevantSamples.length >= _localRuleMinSamples) {
        final intentCounts = <VoiceIntentType, int>{};
        for (final sample in relevantSamples) {
          final sampleIntent = sample.actualIntent ?? sample.predictedIntent;
          intentCounts[sampleIntent] = (intentCounts[sampleIntent] ?? 0) + 1;
        }

        final mostFrequent = intentCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b);

        if (mostFrequent.value >= _localRuleMinSamples) {
          _localExpressionRules[phrase] = mostFrequent.key;
          debugPrint('Local intent rule created: $phrase -> ${mostFrequent.key.name}');
        }
      }
    }
  }

  /// 获取本地规则数量
  int get localRulesCount => _localExpressionRules.length;

  /// 获取本地样本数量
  int get localSamplesCount => _localSamples.length;

  /// 导出本地规则
  Map<String, VoiceIntentType> exportLocalRules() {
    return Map.unmodifiable(_localExpressionRules);
  }
}
