import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

// ==================== 其他意图学习数据模型 ====================

/// 其他意图学习数据
class OtherIntentLearningData {
  final String userId;
  final String input;
  final String? resolvedIntent;
  final ResolutionMethod resolutionMethod;
  final UserAction userAction;
  final Map<String, dynamic> context;
  final DateTime timestamp;

  OtherIntentLearningData({
    required this.userId,
    required this.input,
    this.resolvedIntent,
    required this.resolutionMethod,
    required this.userAction,
    this.context = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'input': input,
        'resolved_intent': resolvedIntent,
        'resolution_method': resolutionMethod.name,
        'user_action': userAction.name,
        'context': context,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// 解析方式
enum ResolutionMethod {
  userSelected, // 用户从选项中选择
  userTyped, // 用户手动输入
  contextInferred, // 上下文推断
  abandoned, // 放弃
}

/// 用户动作
enum UserAction {
  selected, // 选择了建议
  reworded, // 重新表述
  clarified, // 澄清意图
  canceled, // 取消操作
  completed, // 完成操作
}

/// 规则来源
enum OtherIntentRuleSource {
  userLearned, // 从用户行为学习
  systemDefault, // 系统默认规则
}

/// 学习阶段
enum OtherIntentLearningStage {
  coldStart, // 冷启动
  collecting, // 样本收集中
  active, // 正常运行
}

/// 预测来源
enum OtherIntentPredictionSource {
  learnedRule, // 学习规则命中
  fallback, // 兜底策略
}

/// 其他意图规则
class OtherIntentRule {
  final String ruleId;
  final String pattern;
  final double confidence;
  final OtherIntentRuleSource source;
  final List<String> triggerPatterns;
  final String suggestedIntent;
  final List<String> clarificationPrompts;
  final int successCount;
  final int totalCount;

  OtherIntentRule({
    required this.ruleId,
    required this.pattern,
    required this.confidence,
    required this.source,
    required this.triggerPatterns,
    required this.suggestedIntent,
    this.clarificationPrompts = const [],
    this.successCount = 0,
    this.totalCount = 0,
  });

  bool matches(String input) {
    final lowerInput = input.toLowerCase();
    return triggerPatterns.any((p) => lowerInput.contains(p.toLowerCase()));
  }

  double get successRate => totalCount > 0 ? successCount / totalCount : 0;

  OtherIntentRule copyWith({
    double? confidence,
    int? successCount,
    int? totalCount,
    List<String>? clarificationPrompts,
  }) {
    return OtherIntentRule(
      ruleId: ruleId,
      pattern: pattern,
      confidence: confidence ?? this.confidence,
      source: source,
      triggerPatterns: triggerPatterns,
      suggestedIntent: suggestedIntent,
      clarificationPrompts: clarificationPrompts ?? this.clarificationPrompts,
      successCount: successCount ?? this.successCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

// ==================== 歧义解析建议 ====================

/// 歧义解析建议
class AmbiguityResolution {
  final String originalInput;
  final List<IntentSuggestion> suggestions;
  final String? clarificationQuestion;
  final double ambiguityScore;

  const AmbiguityResolution({
    required this.originalInput,
    required this.suggestions,
    this.clarificationQuestion,
    required this.ambiguityScore,
  });
}

/// 意图建议
class IntentSuggestion {
  final String intent;
  final String displayText;
  final double confidence;
  final String? example;

  const IntentSuggestion({
    required this.intent,
    required this.displayText,
    required this.confidence,
    this.example,
  });
}

/// 预测结果
class OtherIntentPredictionResult {
  final OtherIntentRule? rule;
  final double confidence;
  final OtherIntentPredictionSource source;

  const OtherIntentPredictionResult({
    this.rule,
    required this.confidence,
    required this.source,
  });
}

// ==================== 其他意图学习服务 ====================

/// 其他意图学习服务（处理未识别/歧义意图）
class OtherIntentLearningService {
  final OtherIntentDataStore _dataStore;
  final List<OtherIntentRule> _learnedRules = [];
  final Map<String, List<String>> _userClarificationHistory = {};

  // 配置
  static const int _minSamplesForPattern = 3;
  static const double _minSuccessRateForRule = 0.6;

  String get moduleId => 'other_intent_learning';
  OtherIntentLearningStage stage = OtherIntentLearningStage.coldStart;
  double accuracy = 0.0;

  OtherIntentLearningService({
    OtherIntentDataStore? dataStore,
  }) : _dataStore = dataStore ?? InMemoryOtherIntentDataStore();

  /// 学习其他意图数据
  Future<void> learn(OtherIntentLearningData data) async {
    await _dataStore.saveData(data);

    // 记录用户澄清历史
    if (data.resolutionMethod == ResolutionMethod.userSelected ||
        data.resolutionMethod == ResolutionMethod.userTyped) {
      _userClarificationHistory.putIfAbsent(data.userId, () => []);
      _userClarificationHistory[data.userId]!.add(data.input);
    }

    // 检查学习阶段
    final sampleCount = await _dataStore.getDataCount();
    if (sampleCount >= _minSamplesForPattern * 2 &&
        stage == OtherIntentLearningStage.coldStart) {
      stage = OtherIntentLearningStage.collecting;
    }

    if (sampleCount >= _minSamplesForPattern * 5) {
      await _triggerPatternMining();
      stage = OtherIntentLearningStage.active;
    }
  }

  /// 触发模式挖掘
  Future<void> _triggerPatternMining() async {
    final allData = await _dataStore.getAllData(months: 6);

    // 找出成功解析的样本
    final successfulResolutions = allData.where((d) =>
        d.resolvedIntent != null &&
        (d.resolutionMethod == ResolutionMethod.userSelected ||
            d.resolutionMethod == ResolutionMethod.contextInferred));

    // 按解析意图分组
    final byIntent = groupBy(successfulResolutions, (d) => d.resolvedIntent!);

    _learnedRules.clear();

    for (final entry in byIntent.entries) {
      if (entry.value.length >= _minSamplesForPattern) {
        // 提取触发模式
        final inputs = entry.value.map((d) => d.input).toList();
        final patterns = _extractPatterns(inputs);

        if (patterns.isNotEmpty) {
          // 计算成功率
          final totalWithIntent = allData
              .where((d) => patterns.any((p) => d.input.toLowerCase().contains(p)))
              .toList();
          final successWithIntent = totalWithIntent
              .where((d) => d.resolvedIntent == entry.key)
              .length;

          final successRate = totalWithIntent.isEmpty
              ? 0.0
              : successWithIntent / totalWithIntent.length;

          if (successRate >= _minSuccessRateForRule) {
            // 生成澄清提示
            final clarificationPrompts = _generateClarificationPrompts(
              entry.key,
              entry.value,
            );

            final rule = OtherIntentRule(
              ruleId: 'other_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
              pattern: patterns.join('|'),
              confidence: successRate,
              source: OtherIntentRuleSource.userLearned,
              triggerPatterns: patterns,
              suggestedIntent: entry.key,
              clarificationPrompts: clarificationPrompts,
              successCount: successWithIntent,
              totalCount: totalWithIntent.length,
            );

            _learnedRules.add(rule);
          }
        }
      }
    }

    debugPrint('Mined ${_learnedRules.length} other intent patterns');
  }

  /// 提取模式
  List<String> _extractPatterns(List<String> inputs) {
    final wordFreq = <String, int>{};

    for (final input in inputs) {
      final words = input.toLowerCase().split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length >= 2) {
          wordFreq[word] = (wordFreq[word] ?? 0) + 1;
        }
      }

      // 也考虑二元组
      for (int i = 0; i < words.length - 1; i++) {
        final bigram = '${words[i]} ${words[i + 1]}';
        wordFreq[bigram] = (wordFreq[bigram] ?? 0) + 1;
      }
    }

    final threshold = (inputs.length * 0.3).ceil();
    return wordFreq.entries
        .where((e) => e.value >= threshold)
        .map((e) => e.key)
        .take(5)
        .toList();
  }

  /// 生成澄清提示
  List<String> _generateClarificationPrompts(
    String intent,
    List<OtherIntentLearningData> samples,
  ) {
    final prompts = <String>[];

    // 基于意图类型生成提示
    switch (intent) {
      case 'add_expense':
        prompts.add('您是要记录一笔支出吗？');
        break;
      case 'add_income':
        prompts.add('您是要记录一笔收入吗？');
        break;
      case 'query_spending':
        prompts.add('您是想查看消费记录吗？');
        break;
      case 'set_budget':
        prompts.add('您是想设置预算吗？');
        break;
      default:
        // 从样本中提取常见表述
        final expressions = samples.take(3).map((s) => s.input).toList();
        if (expressions.isNotEmpty) {
          prompts.add('您是想说"${expressions.first}"这类的意思吗？');
        }
    }

    return prompts;
  }

  /// 预测意图
  Future<OtherIntentPredictionResult> predict(String input) async {
    // 匹配学习的规则
    for (final rule in _learnedRules) {
      if (rule.matches(input)) {
        return OtherIntentPredictionResult(
          rule: rule,
          confidence: rule.confidence,
          source: OtherIntentPredictionSource.learnedRule,
        );
      }
    }

    // 没有匹配的规则
    return const OtherIntentPredictionResult(
      rule: null,
      confidence: 0.0,
      source: OtherIntentPredictionSource.fallback,
    );
  }

  /// 获取歧义解析建议
  Future<AmbiguityResolution> getAmbiguityResolution(String input) async {
    final suggestions = <IntentSuggestion>[];
    double maxConfidence = 0;

    for (final rule in _learnedRules) {
      if (rule.matches(input)) {
        suggestions.add(IntentSuggestion(
          intent: rule.suggestedIntent,
          displayText: _getIntentDisplayText(rule.suggestedIntent),
          confidence: rule.confidence,
          example: rule.clarificationPrompts.isNotEmpty
              ? rule.clarificationPrompts.first
              : null,
        ));

        if (rule.confidence > maxConfidence) {
          maxConfidence = rule.confidence;
        }
      }
    }

    // 计算歧义分数
    double ambiguityScore = 0.5;
    if (suggestions.isEmpty) {
      ambiguityScore = 1.0; // 完全未知
    } else if (suggestions.length == 1 && maxConfidence > 0.8) {
      ambiguityScore = 0.2; // 较为明确
    } else if (suggestions.length > 2) {
      ambiguityScore = 0.8; // 高歧义
    }

    // 生成澄清问题
    String? clarificationQuestion;
    if (ambiguityScore > 0.5) {
      clarificationQuestion = _generateClarificationQuestion(input, suggestions);
    }

    return AmbiguityResolution(
      originalInput: input,
      suggestions: suggestions,
      clarificationQuestion: clarificationQuestion,
      ambiguityScore: ambiguityScore,
    );
  }

  String _getIntentDisplayText(String intent) {
    final displayTexts = {
      'add_expense': '记录支出',
      'add_income': '记录收入',
      'query_spending': '查看消费',
      'query_budget': '查看预算',
      'set_budget': '设置预算',
      'view_report': '查看报告',
      'help': '获取帮助',
    };
    return displayTexts[intent] ?? intent;
  }

  String _generateClarificationQuestion(
    String input,
    List<IntentSuggestion> suggestions,
  ) {
    if (suggestions.isEmpty) {
      return '抱歉，我不太理解您的意思。您可以告诉我您想做什么吗？';
    }

    if (suggestions.length == 1) {
      return suggestions.first.example ?? '您是想${suggestions.first.displayText}吗？';
    }

    final options = suggestions.take(3).map((s) => s.displayText).join('、');
    return '您是想$options，还是其他操作呢？';
  }

  /// 用户反馈
  Future<void> feedback(OtherIntentLearningData data, bool positive) async {
    // 更新规则成功率
    for (int i = 0; i < _learnedRules.length; i++) {
      if (_learnedRules[i].matches(data.input)) {
        final rule = _learnedRules[i];
        _learnedRules[i] = rule.copyWith(
          totalCount: rule.totalCount + 1,
          successCount: positive ? rule.successCount + 1 : rule.successCount,
          confidence: (rule.successCount + (positive ? 1 : 0)) /
              (rule.totalCount + 1),
        );
      }
    }

    // 更新准确率
    await _updateAccuracy();
  }

  Future<void> _updateAccuracy() async {
    final recentData = await _dataStore.getRecentData(limit: 100);
    if (recentData.isEmpty) return;

    final successful = recentData.where((d) =>
        d.resolvedIntent != null && d.userAction != UserAction.canceled);

    accuracy = successful.length / recentData.length;
  }

  /// 导出规则
  Future<List<OtherIntentRule>> exportRules() async {
    return List.unmodifiable(_learnedRules);
  }

  /// 获取统计信息
  Future<OtherIntentLearningStats> getStats() async {
    return OtherIntentLearningStats(
      moduleId: moduleId,
      stage: stage,
      accuracy: accuracy,
      rulesCount: _learnedRules.length,
      totalClarifications:
          _userClarificationHistory.values.fold(0, (a, b) => a + b.length),
    );
  }

  /// 获取用户的歧义解析历史
  Future<List<String>> getUserClarificationHistory(String userId) async {
    return _userClarificationHistory[userId] ?? [];
  }

  /// 分析常见歧义模式
  Future<List<AmbiguityPattern>> analyzeCommonAmbiguities() async {
    final allData = await _dataStore.getAllData(months: 3);
    final patterns = <AmbiguityPattern>[];

    // 找出被多次解析为不同意图的输入模式
    final inputGroups = groupBy(allData, (d) => d.input.toLowerCase().trim());

    for (final entry in inputGroups.entries) {
      if (entry.value.length >= 2) {
        final resolvedIntents = entry.value
            .where((d) => d.resolvedIntent != null)
            .map((d) => d.resolvedIntent!)
            .toSet();

        if (resolvedIntents.length >= 2) {
          // 这是一个歧义模式
          patterns.add(AmbiguityPattern(
            inputPattern: entry.key,
            possibleIntents: resolvedIntents.toList(),
            occurrenceCount: entry.value.length,
          ));
        }
      }
    }

    patterns.sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));
    return patterns;
  }
}

/// 其他意图学习统计
class OtherIntentLearningStats {
  final String moduleId;
  final OtherIntentLearningStage stage;
  final double accuracy;
  final int rulesCount;
  final int totalClarifications;

  const OtherIntentLearningStats({
    required this.moduleId,
    required this.stage,
    required this.accuracy,
    required this.rulesCount,
    required this.totalClarifications,
  });
}

/// 歧义模式
class AmbiguityPattern {
  final String inputPattern;
  final List<String> possibleIntents;
  final int occurrenceCount;

  const AmbiguityPattern({
    required this.inputPattern,
    required this.possibleIntents,
    required this.occurrenceCount,
  });
}

// ==================== 数据存储 ====================

/// 其他意图数据存储接口
abstract class OtherIntentDataStore {
  Future<void> saveData(OtherIntentLearningData data);
  Future<List<OtherIntentLearningData>> getAllData({int? months});
  Future<List<OtherIntentLearningData>> getRecentData({int limit = 100});
  Future<int> getDataCount();
}

/// 内存其他意图数据存储
class InMemoryOtherIntentDataStore implements OtherIntentDataStore {
  final List<OtherIntentLearningData> _data = [];

  @override
  Future<void> saveData(OtherIntentLearningData data) async {
    _data.add(data);
  }

  @override
  Future<List<OtherIntentLearningData>> getAllData({int? months}) async {
    if (months == null) return List.unmodifiable(_data);

    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    return _data.where((d) => d.timestamp.isAfter(cutoff)).toList();
  }

  @override
  Future<List<OtherIntentLearningData>> getRecentData({int limit = 100}) async {
    final sorted = _data.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<int> getDataCount() async {
    return _data.length;
  }

  void clear() => _data.clear();
}
