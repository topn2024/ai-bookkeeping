import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'learning_adapters.dart';
import 'unified_self_learning_service.dart';

// ==================== 语音意图类型 ====================

/// 语音意图类型
enum VoiceIntentType {
  addExpense, // 添加支出
  addIncome, // 添加收入
  querySpending, // 查询消费
  queryBudget, // 查询预算
  setBudget, // 设置预算
  viewReport, // 查看报告
  greeting, // 问候
  help, // 帮助
  cancel, // 取消
  confirm, // 确认
  other, // 其他
}

/// 意图来源
enum IntentSource {
  learned, // 自学习规则
  rule, // 静态规则
  similarity, // 相似度匹配
  llm, // LLM识别
  fallback, // 兜底
}

// ==================== 意图识别结果 ====================

/// 意图识别结果
class IntentRecognitionResult {
  final VoiceIntentType intent;
  final double confidence;
  final IntentSource source;
  final Map<String, dynamic> slots;
  final String? rawInput;

  const IntentRecognitionResult({
    required this.intent,
    required this.confidence,
    required this.source,
    this.slots = const {},
    this.rawInput,
  });

  IntentRecognitionResult copyWith({
    VoiceIntentType? intent,
    double? confidence,
    IntentSource? source,
    Map<String, dynamic>? slots,
    String? rawInput,
  }) {
    return IntentRecognitionResult(
      intent: intent ?? this.intent,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      slots: slots ?? this.slots,
      rawInput: rawInput ?? this.rawInput,
    );
  }

  Map<String, dynamic> toJson() => {
        'intent': intent.name,
        'confidence': confidence,
        'source': source.name,
        'slots': slots,
        'raw_input': rawInput,
      };
}

// ==================== 个性化意图模型 ====================

/// 个性化意图模型
class PersonalizedIntentModel {
  final String userId;
  final Map<VoiceIntentType, int> intentFrequency;
  final ExpressionHabits expressionHabits;
  final Map<int, Map<VoiceIntentType, double>> timeSlotPreferences;
  final List<IntentRule> personalRules;
  final DateTime lastUpdated;

  PersonalizedIntentModel({
    required this.userId,
    Map<VoiceIntentType, int>? intentFrequency,
    ExpressionHabits? expressionHabits,
    Map<int, Map<VoiceIntentType, double>>? timeSlotPreferences,
    List<IntentRule>? personalRules,
    DateTime? lastUpdated,
  })  : intentFrequency = intentFrequency ?? {},
        expressionHabits = expressionHabits ?? const ExpressionHabits(),
        timeSlotPreferences = timeSlotPreferences ?? {},
        personalRules = personalRules ?? [],
        lastUpdated = lastUpdated ?? DateTime.now();

  /// 获取意图先验概率
  double getIntentPrior(VoiceIntentType intent) {
    final total = intentFrequency.values.fold(0, (a, b) => a + b);
    if (total == 0) return 1.0;
    return (intentFrequency[intent] ?? 0) / total;
  }

  /// 根据时间调整置信度
  double adjustByTime(VoiceIntentType intent, DateTime time) {
    final hour = time.hour;
    final timeSlot = _getTimeSlot(hour);
    final slotPrefs = timeSlotPreferences[timeSlot];
    if (slotPrefs == null) return 1.0;
    return slotPrefs[intent] ?? 1.0;
  }

  int _getTimeSlot(int hour) {
    if (hour >= 6 && hour < 12) return 0; // 上午
    if (hour >= 12 && hour < 14) return 1; // 午间
    if (hour >= 14 && hour < 18) return 2; // 下午
    if (hour >= 18 && hour < 22) return 3; // 晚间
    return 4; // 深夜
  }

  /// 合并新的学习数据
  PersonalizedIntentModel merge(PersonalizedIntentModel other) {
    final mergedFrequency = Map<VoiceIntentType, int>.from(intentFrequency);
    for (final entry in other.intentFrequency.entries) {
      mergedFrequency[entry.key] =
          (mergedFrequency[entry.key] ?? 0) + entry.value;
    }

    return PersonalizedIntentModel(
      userId: userId,
      intentFrequency: mergedFrequency,
      expressionHabits: expressionHabits.merge(other.expressionHabits),
      timeSlotPreferences: {...timeSlotPreferences, ...other.timeSlotPreferences},
      personalRules: [...personalRules, ...other.personalRules],
      lastUpdated: DateTime.now(),
    );
  }
}

/// 表达习惯
class ExpressionHabits {
  final Map<String, String> synonymMappings;
  final List<String> frequentPhrases;
  final double averageInputLength;

  const ExpressionHabits({
    this.synonymMappings = const {},
    this.frequentPhrases = const [],
    this.averageInputLength = 0,
  });

  ExpressionHabits merge(ExpressionHabits other) {
    return ExpressionHabits(
      synonymMappings: {...synonymMappings, ...other.synonymMappings},
      frequentPhrases: <dynamic>{...frequentPhrases, ...other.frequentPhrases}.toList(),
      averageInputLength: (averageInputLength + other.averageInputLength) / 2,
    );
  }
}

// ==================== 规则引擎 ====================

/// 简单规则引擎
class RuleEngine {
  final List<_IntentPattern> _patterns = [];

  RuleEngine() {
    _initDefaultPatterns();
  }

  void _initDefaultPatterns() {
    // 添加支出模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.addExpense,
      keywords: ['花了', '买了', '支出', '消费', '付了', '刷了'],
      confidence: 0.9,
    ));

    // 添加收入模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.addIncome,
      keywords: ['收到', '入账', '工资', '收入', '赚了', '转入'],
      confidence: 0.9,
    ));

    // 查询消费模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.querySpending,
      keywords: ['花了多少', '消费了多少', '支出统计', '查看消费'],
      confidence: 0.85,
    ));

    // 查询预算模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.queryBudget,
      keywords: ['预算', '还剩多少', '余额', '可用额度'],
      confidence: 0.85,
    ));

    // 设置预算模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.setBudget,
      keywords: ['设置预算', '预算设为', '每月预算'],
      confidence: 0.9,
    ));

    // 查看报告模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.viewReport,
      keywords: ['报告', '统计', '分析', '月度报表'],
      confidence: 0.85,
    ));

    // 问候模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.greeting,
      keywords: ['你好', '早上好', '下午好', '晚上好', 'hi', 'hello'],
      confidence: 0.95,
    ));

    // 帮助模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.help,
      keywords: ['帮助', '怎么', '如何', '帮我', '教我'],
      confidence: 0.85,
    ));

    // 确认模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.confirm,
      keywords: ['是', '对', '确认', '好的', '可以', '没问题'],
      confidence: 0.9,
    ));

    // 取消模式
    _patterns.add(_IntentPattern(
      intent: VoiceIntentType.cancel,
      keywords: ['取消', '算了', '不要', '不用了'],
      confidence: 0.9,
    ));
  }

  /// 匹配意图
  Future<IntentRecognitionResult?> match(String input) async {
    final lowerInput = input.toLowerCase();

    for (final pattern in _patterns) {
      if (pattern.matches(lowerInput)) {
        return IntentRecognitionResult(
          intent: pattern.intent,
          confidence: pattern.confidence,
          source: IntentSource.rule,
          rawInput: input,
        );
      }
    }

    return null;
  }
}

class _IntentPattern {
  final VoiceIntentType intent;
  final List<String> keywords;
  final double confidence;

  _IntentPattern({
    required this.intent,
    required this.keywords,
    required this.confidence,
  });

  bool matches(String input) {
    return keywords.any((k) => input.contains(k.toLowerCase()));
  }
}

// ==================== 意图学习服务 ====================

/// 意图学习服务
class IntentLearningService {
  final Map<String, PersonalizedIntentModel> _userModels = {};
  final List<_IntentSample> _samples = [];

  /// 获取用户个性化模型
  Future<PersonalizedIntentModel?> getPersonalizedModel(String userId) async {
    return _userModels[userId];
  }

  /// 记录意图样本
  Future<void> recordSample(
    String userId,
    String input,
    IntentRecognitionResult result,
  ) async {
    _samples.add(_IntentSample(
      userId: userId,
      input: input,
      intent: result.intent,
      confidence: result.confidence,
      source: result.source,
      timestamp: DateTime.now(),
    ));
  }

  /// 训练用户模型
  Future<void> trainUserModel(String userId) async {
    final userSamples = _samples.where((s) => s.userId == userId).toList();
    if (userSamples.isEmpty) return;

    // 统计意图频率
    final intentFrequency = <VoiceIntentType, int>{};
    for (final sample in userSamples) {
      intentFrequency[sample.intent] =
          (intentFrequency[sample.intent] ?? 0) + 1;
    }

    // 统计时段偏好
    final timeSlotPreferences = <int, Map<VoiceIntentType, double>>{};
    for (final sample in userSamples) {
      final timeSlot = _getTimeSlot(sample.timestamp.hour);
      timeSlotPreferences.putIfAbsent(timeSlot, () => {});
      timeSlotPreferences[timeSlot]![sample.intent] =
          (timeSlotPreferences[timeSlot]![sample.intent] ?? 0) + 1;
    }

    // 归一化时段偏好
    for (final slotEntry in timeSlotPreferences.entries) {
      final total = slotEntry.value.values.fold(0.0, (a, b) => a + b);
      if (total > 0) {
        for (final intentEntry in slotEntry.value.entries) {
          timeSlotPreferences[slotEntry.key]![intentEntry.key] =
              intentEntry.value / total;
        }
      }
    }

    // 提取表达习惯
    final expressionHabits = _extractExpressionHabits(userSamples);

    // 提取个人规则
    final personalRules = _extractPersonalRules(userSamples);

    _userModels[userId] = PersonalizedIntentModel(
      userId: userId,
      intentFrequency: intentFrequency,
      expressionHabits: expressionHabits,
      timeSlotPreferences: timeSlotPreferences,
      personalRules: personalRules,
      lastUpdated: DateTime.now(),
    );

    debugPrint('Trained intent model for user: $userId');
  }

  ExpressionHabits _extractExpressionHabits(List<_IntentSample> samples) {
    // 提取同义词映射
    final synonymMappings = <String, String>{};
    // 简化实现：这里应该基于样本分析

    // 提取高频短语
    final phraseCounts = <String, int>{};
    for (final sample in samples) {
      final words = sample.input.split(RegExp(r'\s+'));
      for (int i = 0; i < words.length - 1; i++) {
        final phrase = '${words[i]} ${words[i + 1]}';
        phraseCounts[phrase] = (phraseCounts[phrase] ?? 0) + 1;
      }
    }
    final frequentPhrases = phraseCounts.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .take(10)
        .toList();

    // 计算平均输入长度
    final avgLength = samples.isEmpty
        ? 0.0
        : samples.map((s) => s.input.length).reduce((a, b) => a + b) /
            samples.length;

    return ExpressionHabits(
      synonymMappings: synonymMappings,
      frequentPhrases: frequentPhrases,
      averageInputLength: avgLength,
    );
  }

  List<IntentRule> _extractPersonalRules(List<_IntentSample> samples) {
    final rules = <IntentRule>[];

    // 按意图分组
    final byIntent = groupBy(samples, (s) => s.intent);

    for (final entry in byIntent.entries) {
      if (entry.value.length >= 3) {
        // 提取关键词
        final keywords = _extractKeywords(entry.value.map((s) => s.input).toList());

        if (keywords.isNotEmpty) {
          rules.add(IntentRule(
            ruleId: 'personal_${entry.key.name}_${DateTime.now().millisecondsSinceEpoch}',
            pattern: entry.key.name,
            intentId: entry.key.name,
            keywords: keywords,
            confidence: entry.value.length / samples.length,
            source: RuleSource.userLearned,
          ));
        }
      }
    }

    return rules;
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

    final threshold = inputs.length * 0.3;
    return wordFreq.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .take(5)
        .toList();
  }

  int _getTimeSlot(int hour) {
    if (hour >= 6 && hour < 12) return 0;
    if (hour >= 12 && hour < 14) return 1;
    if (hour >= 14 && hour < 18) return 2;
    if (hour >= 18 && hour < 22) return 3;
    return 4;
  }
}

class _IntentSample {
  final String userId;
  final String input;
  final VoiceIntentType intent;
  final double confidence;
  final IntentSource source;
  final DateTime timestamp;

  _IntentSample({
    required this.userId,
    required this.input,
    required this.intent,
    required this.confidence,
    required this.source,
    required this.timestamp,
  });
}

// ==================== 数据收集器 ====================

/// 意图数据收集器
class IntentDataCollector {
  final List<_CollectedIntentData> _data = [];

  Future<void> collect(
    String input,
    IntentRecognitionResult result,
    IntentSource source,
  ) async {
    _data.add(_CollectedIntentData(
      input: input,
      result: result,
      source: source,
      timestamp: DateTime.now(),
    ));

    // 保持数据量在合理范围
    if (_data.length > 10000) {
      _data.removeRange(0, _data.length - 10000);
    }
  }

  List<_CollectedIntentData> getRecentData({int limit = 100}) {
    return _data.reversed.take(limit).toList();
  }
}

class _CollectedIntentData {
  final String input;
  final IntentRecognitionResult result;
  final IntentSource source;
  final DateTime timestamp;

  _CollectedIntentData({
    required this.input,
    required this.result,
    required this.source,
    required this.timestamp,
  });
}

// ==================== LLM服务接口 ====================

/// LLM服务接口（简化实现）
abstract class LLMService {
  Future<IntentRecognitionResult> recognizeIntent(
    String input,
    String prompt,
  );
}

/// 模拟LLM服务
class MockLLMService implements LLMService {
  @override
  Future<IntentRecognitionResult> recognizeIntent(
    String input,
    String prompt,
  ) async {
    // 模拟LLM响应延迟
    await Future.delayed(const Duration(milliseconds: 100));

    // 简单的关键词匹配作为模拟
    final lowerInput = input.toLowerCase();

    if (lowerInput.contains('花') || lowerInput.contains('买')) {
      return IntentRecognitionResult(
        intent: VoiceIntentType.addExpense,
        confidence: 0.7,
        source: IntentSource.llm,
        rawInput: input,
      );
    }

    if (lowerInput.contains('收入') || lowerInput.contains('工资')) {
      return IntentRecognitionResult(
        intent: VoiceIntentType.addIncome,
        confidence: 0.7,
        source: IntentSource.llm,
        rawInput: input,
      );
    }

    return IntentRecognitionResult(
      intent: VoiceIntentType.other,
      confidence: 0.5,
      source: IntentSource.llm,
      rawInput: input,
    );
  }
}

// ==================== 增强意图识别服务 ====================

/// 带自学习增强的意图识别服务
class EnhancedIntentRecognitionService {
  final RuleEngine _ruleEngine;
  final IntentLearningService _learningService;
  final LLMService _llmService;
  final IntentDataCollector _dataCollector;
  final String Function()? _userIdProvider;

  EnhancedIntentRecognitionService({
    RuleEngine? ruleEngine,
    IntentLearningService? learningService,
    LLMService? llmService,
    IntentDataCollector? dataCollector,
    String Function()? userIdProvider,
  })  : _ruleEngine = ruleEngine ?? RuleEngine(),
        _learningService = learningService ?? IntentLearningService(),
        _llmService = llmService ?? MockLLMService(),
        _dataCollector = dataCollector ?? IntentDataCollector(),
        _userIdProvider = userIdProvider;

  String _getCurrentUserId() {
    return _userIdProvider?.call() ?? 'default_user';
  }

  /// 识别意图（四级策略 + 自学习增强）
  Future<IntentRecognitionResult> recognizeIntent(
    String input, {
    Map<String, dynamic>? context,
  }) async {
    final normalizedInput = _normalize(input);
    final userId = _getCurrentUserId();

    // 获取用户个性化模型
    final personalModel = await _learningService.getPersonalizedModel(userId);

    // Level 1: 用户个性化规则（自学习生成，最高优先级）
    final personalResult =
        await _matchPersonalRules(normalizedInput, personalModel);
    if (personalResult != null && personalResult.confidence >= 0.95) {
      await _collectSample(input, personalResult, IntentSource.learned);
      return personalResult;
    }

    // Level 2: 全局规则匹配
    final ruleResult = await _ruleEngine.match(normalizedInput);
    if (ruleResult != null && ruleResult.confidence >= 0.9) {
      final adjustedConfidence = _adjustWithPrior(
        ruleResult.confidence,
        ruleResult.intent,
        personalModel,
      );
      await _collectSample(input, ruleResult, IntentSource.rule);
      return ruleResult.copyWith(confidence: adjustedConfidence);
    }

    // Level 3: 相似度匹配（基于学习到的表达模式）
    final similarResult =
        await _matchSimilarPatterns(normalizedInput, personalModel);
    if (similarResult != null && similarResult.confidence >= 0.85) {
      await _collectSample(input, similarResult, IntentSource.learned);
      return similarResult;
    }

    // Level 4: LLM 兜底（带个性化 Prompt 增强）
    final llmResult = await _llmRecognize(
      input,
      personalModel: personalModel,
      context: context,
    );
    await _collectSample(input, llmResult, IntentSource.llm);
    return llmResult;
  }

  String _normalize(String input) {
    return input.trim().toLowerCase();
  }

  /// 匹配个性化规则
  Future<IntentRecognitionResult?> _matchPersonalRules(
    String input,
    PersonalizedIntentModel? model,
  ) async {
    if (model == null || model.personalRules.isEmpty) return null;

    for (final rule in model.personalRules) {
      if (rule.matches(input)) {
        final intentType = VoiceIntentType.values.firstWhere(
          (t) => t.name == rule.intentId,
          orElse: () => VoiceIntentType.other,
        );

        return IntentRecognitionResult(
          intent: intentType,
          confidence: rule.confidence,
          source: IntentSource.learned,
          rawInput: input,
        );
      }
    }

    return null;
  }

  /// 匹配相似模式
  Future<IntentRecognitionResult?> _matchSimilarPatterns(
    String input,
    PersonalizedIntentModel? model,
  ) async {
    if (model == null) return null;

    // 检查同义词映射
    String processedInput = input;
    for (final entry in model.expressionHabits.synonymMappings.entries) {
      processedInput = processedInput.replaceAll(entry.key, entry.value);
    }

    // 如果同义词替换后与原输入不同，尝试重新匹配规则
    if (processedInput != input) {
      final ruleResult = await _ruleEngine.match(processedInput);
      if (ruleResult != null) {
        return ruleResult.copyWith(
          confidence: ruleResult.confidence * 0.9,
          source: IntentSource.similarity,
        );
      }
    }

    // 检查高频短语匹配
    for (final phrase in model.expressionHabits.frequentPhrases) {
      if (input.contains(phrase)) {
        // 找出该短语关联的意图
        final topIntent = model.intentFrequency.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

        return IntentRecognitionResult(
          intent: topIntent,
          confidence: 0.85,
          source: IntentSource.similarity,
          rawInput: input,
        );
      }
    }

    return null;
  }

  /// LLM识别
  Future<IntentRecognitionResult> _llmRecognize(
    String input, {
    PersonalizedIntentModel? personalModel,
    Map<String, dynamic>? context,
  }) async {
    final prompt = _buildPersonalizedPrompt(input, personalModel, context);
    return _llmService.recognizeIntent(input, prompt);
  }

  /// 构建个性化 Prompt
  String _buildPersonalizedPrompt(
    String input,
    PersonalizedIntentModel? model,
    Map<String, dynamic>? context,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('请识别以下语音输入的意图：');
    buffer.writeln('输入："$input"');

    if (model != null) {
      buffer.writeln('\n用户习惯参考：');
      // 高频意图
      final topIntents = model.intentFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (topIntents.isNotEmpty) {
        buffer.writeln(
            '- 常用意图：${topIntents.take(5).map((e) => e.key.name).join('、')}');
      }
      // 同义词映射
      if (model.expressionHabits.synonymMappings.isNotEmpty) {
        buffer.writeln('- 用户同义词：');
        for (final entry
            in model.expressionHabits.synonymMappings.entries.take(5)) {
          buffer.writeln('  "${entry.key}" -> "${entry.value}"');
        }
      }
    }

    if (context != null && context.isNotEmpty) {
      buffer.writeln('\n上下文信息：');
      for (final entry in context.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
    }

    buffer.writeln('\n请返回最可能的意图类型。');
    return buffer.toString();
  }

  /// 应用先验概率调整置信度（贝叶斯）
  double _adjustWithPrior(
    double confidence,
    VoiceIntentType intent,
    PersonalizedIntentModel? model,
  ) {
    if (model == null) return confidence;
    final prior = model.getIntentPrior(intent);
    final timeAdjust = model.adjustByTime(intent, DateTime.now());

    // 贝叶斯调整：结合先验和时间因素
    final adjusted = confidence * (0.7 + 0.3 * prior) * (0.8 + 0.2 * timeAdjust);
    return adjusted.clamp(0.0, 1.0);
  }

  /// 收集样本
  Future<void> _collectSample(
    String input,
    IntentRecognitionResult result,
    IntentSource source,
  ) async {
    await _dataCollector.collect(input, result, source);
    await _learningService.recordSample(_getCurrentUserId(), input, result);
  }

  /// 用户反馈：修正意图
  Future<void> correctIntent(
    String input,
    VoiceIntentType correctedIntent,
  ) async {
    final result = IntentRecognitionResult(
      intent: correctedIntent,
      confidence: 1.0,
      source: IntentSource.learned,
      rawInput: input,
    );

    await _learningService.recordSample(_getCurrentUserId(), input, result);
    debugPrint('Intent corrected: $input -> ${correctedIntent.name}');
  }

  /// 触发训练
  Future<void> triggerTraining() async {
    await _learningService.trainUserModel(_getCurrentUserId());
  }

  /// 获取识别统计
  Future<IntentRecognitionStats> getStats() async {
    final recentData = _dataCollector.getRecentData(limit: 100);

    if (recentData.isEmpty) {
      return const IntentRecognitionStats(
        totalRecognitions: 0,
        averageConfidence: 0,
        sourceDistribution: {},
        intentDistribution: {},
      );
    }

    final sourceDistribution = <IntentSource, int>{};
    final intentDistribution = <VoiceIntentType, int>{};
    double totalConfidence = 0;

    for (final data in recentData) {
      sourceDistribution[data.source] =
          (sourceDistribution[data.source] ?? 0) + 1;
      intentDistribution[data.result.intent] =
          (intentDistribution[data.result.intent] ?? 0) + 1;
      totalConfidence += data.result.confidence;
    }

    return IntentRecognitionStats(
      totalRecognitions: recentData.length,
      averageConfidence: totalConfidence / recentData.length,
      sourceDistribution: sourceDistribution,
      intentDistribution: intentDistribution,
    );
  }
}

/// 识别统计
class IntentRecognitionStats {
  final int totalRecognitions;
  final double averageConfidence;
  final Map<IntentSource, int> sourceDistribution;
  final Map<VoiceIntentType, int> intentDistribution;

  const IntentRecognitionStats({
    required this.totalRecognitions,
    required this.averageConfidence,
    required this.sourceDistribution,
    required this.intentDistribution,
  });
}
