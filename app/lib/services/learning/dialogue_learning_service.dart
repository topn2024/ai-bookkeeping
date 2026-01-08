import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'unified_self_learning_service.dart';

// ==================== 对话学习数据模型 ====================

/// 对话意图类型
enum DialogueIntentType {
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

/// 对话上下文
class DialogueContext {
  final String userMessage;
  final String sessionId;
  final int turnNumber;
  final DialogueIntentType? previousIntent;
  final Map<String, dynamic> slots;
  final DateTime timestamp;

  const DialogueContext({
    required this.userMessage,
    required this.sessionId,
    required this.turnNumber,
    this.previousIntent,
    this.slots = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'user_message': userMessage,
        'session_id': sessionId,
        'turn_number': turnNumber,
        'previous_intent': previousIntent?.name,
        'slots': slots,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// 对话意图
class DialogueIntent {
  final DialogueIntentType type;
  final double confidence;
  final Map<String, dynamic> parameters;

  const DialogueIntent({
    required this.type,
    this.confidence = 0.5,
    this.parameters = const {},
  });

  DialogueIntent copyWith({
    DialogueIntentType? type,
    double? confidence,
    Map<String, dynamic>? parameters,
  }) {
    return DialogueIntent(
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      parameters: parameters ?? this.parameters,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'confidence': confidence,
        'parameters': parameters,
      };
}

// ==================== 对话学习数据 ====================

/// 对话学习数据
class DialogueLearningData extends LearningData {
  final DialogueContext context;
  final DialogueIntent predictedIntent;
  final DialogueIntent? actualIntent;
  final String? systemResponse;
  final bool taskCompleted;
  final int totalTurns;
  final bool isFirstTurn;
  final bool userAbandoned;

  DialogueLearningData({
    required String id,
    required DateTime timestamp,
    required String userId,
    required this.context,
    required this.predictedIntent,
    this.actualIntent,
    this.systemResponse,
    this.taskCompleted = false,
    this.totalTurns = 1,
    this.isFirstTurn = true,
    this.userAbandoned = false,
  }) : super(
          id: id,
          timestamp: timestamp,
          userId: userId,
          features: {
            'message': context.userMessage,
            'turn': context.turnNumber,
          },
          label: actualIntent ?? predictedIntent,
          source: actualIntent != null
              ? LearningDataSource.userExplicitFeedback
              : LearningDataSource.userImplicitBehavior,
        );

  @override
  double get qualityScore {
    var score = 0.0;
    // 任务完成
    if (taskCompleted) score += 0.5;
    // 有明确的意图修正
    if (actualIntent != null) score += 0.3;
    // 对话轮数少（效率高）
    if (totalTurns <= 3) score += 0.2;
    // 用户未放弃
    if (!userAbandoned) score += 0.1;
    return score.clamp(0.0, 1.0);
  }

  @override
  Map<String, dynamic> toStorable() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'context': context.toJson(),
        'predicted_intent': predictedIntent.toJson(),
        'actual_intent': actualIntent?.toJson(),
        'system_response': systemResponse,
        'task_completed': taskCompleted,
        'total_turns': totalTurns,
        'is_first_turn': isFirstTurn,
        'user_abandoned': userAbandoned,
      };

  @override
  LearningData anonymize() => DialogueLearningData(
        id: id,
        timestamp: timestamp,
        userId: _hashValue(userId),
        context: context,
        predictedIntent: predictedIntent,
        actualIntent: actualIntent,
        taskCompleted: taskCompleted,
        totalTurns: totalTurns,
        isFirstTurn: isFirstTurn,
        userAbandoned: userAbandoned,
      );

  static String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}

/// 对话规则
class DialogueRule extends LearnedRule {
  final String greetingPattern;
  final DialogueIntentType intentType;
  final List<String> keywords;
  final int expectedTurns;

  DialogueRule({
    required String ruleId,
    required this.greetingPattern,
    required this.intentType,
    required double confidence,
    required RuleSource source,
    this.keywords = const [],
    this.expectedTurns = 2,
    DateTime? createdAt,
    int hitCount = 0,
  }) : super(
          ruleId: ruleId,
          moduleId: 'dialogue_learning',
          priority: source == RuleSource.userLearned ? 100 : 50,
          confidence: confidence,
          createdAt: createdAt ?? DateTime.now(),
          lastUsedAt: DateTime.now(),
          hitCount: hitCount,
          source: source,
        );

  @override
  bool matches(dynamic input) {
    if (input is! DialogueContext) return false;
    final message = input.userMessage.toLowerCase();
    return keywords.any((k) => message.contains(k.toLowerCase()));
  }

  @override
  dynamic apply(dynamic input) {
    return DialogueIntent(
      type: intentType,
      confidence: confidence,
    );
  }

  @override
  Map<String, dynamic> toStorable() => {
        'rule_id': ruleId,
        'greeting_pattern': greetingPattern,
        'intent_type': intentType.name,
        'confidence': confidence,
        'source': source.name,
        'keywords': keywords,
        'expected_turns': expectedTurns,
        'created_at': createdAt.toIso8601String(),
        'hit_count': hitCount,
      };

  factory DialogueRule.fromStorable(Map<String, dynamic> data) {
    return DialogueRule(
      ruleId: data['rule_id'] as String,
      greetingPattern: data['greeting_pattern'] as String,
      intentType: DialogueIntentType.values.firstWhere(
        (t) => t.name == data['intent_type'],
        orElse: () => DialogueIntentType.other,
      ),
      confidence: (data['confidence'] as num).toDouble(),
      source: RuleSource.values.firstWhere(
        (s) => s.name == data['source'],
        orElse: () => RuleSource.userLearned,
      ),
      keywords: List<String>.from(data['keywords'] ?? []),
      expectedTurns: data['expected_turns'] as int? ?? 2,
      createdAt: DateTime.parse(data['created_at'] as String),
      hitCount: data['hit_count'] as int? ?? 0,
    );
  }
}

// ==================== 用户对话偏好 ====================

/// 用户对话偏好
class UserDialoguePreferences {
  final Map<String, DialogueIntent> greetingIntentMappings;
  final VerbosityLevel verbosityLevel;
  final ConfirmationStyle confirmationStyle;
  final double averageTurns;
  final List<String> preferredExpressions;

  const UserDialoguePreferences({
    this.greetingIntentMappings = const {},
    this.verbosityLevel = VerbosityLevel.normal,
    this.confirmationStyle = ConfirmationStyle.explicit,
    this.averageTurns = 2.0,
    this.preferredExpressions = const [],
  });
}

/// 表达详细程度
enum VerbosityLevel {
  concise, // 简洁
  normal, // 普通
  detailed, // 详细
}

/// 确认风格
enum ConfirmationStyle {
  explicit, // 明确确认
  implicit, // 隐式确认
  none, // 无需确认
}

// ==================== 对话学习服务 ====================

/// 对话学习服务
class DialogueLearningService
    implements ISelfLearningModule<DialogueLearningData, DialogueRule> {
  @override
  String get moduleId => 'dialogue_learning';

  @override
  String get moduleName => '对话学习';

  // 存储
  final List<DialogueLearningData> _samples = [];
  final List<DialogueRule> _rules = [];
  final Map<String, UserDialoguePreferences> _userPreferences = {};

  // 配置
  static const int _minSamplesForRule = 3;
  static const double _minConfidenceThreshold = 0.6;

  // 状态
  bool _isEnabled = true;
  DateTime? _lastTrainingTime;
  LearningStage _stage = LearningStage.coldStart;

  @override
  Future<void> collectSample(DialogueLearningData data) async {
    _samples.add(data);
    _updateStage();
    debugPrint('Collected dialogue sample: ${data.context.userMessage}');
  }

  @override
  Future<void> collectSamples(List<DialogueLearningData> dataList) async {
    _samples.addAll(dataList);
    _updateStage();
  }

  @override
  Future<TrainingResult> train({bool incremental = true}) async {
    final startTime = DateTime.now();
    _stage = LearningStage.training;

    try {
      final samples = incremental
          ? _samples
              .where((s) =>
                  s.timestamp.isAfter(_lastTrainingTime ?? DateTime(2000)))
              .toList()
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

      // 1. 提取对话规则
      final newRules = _extractDialogueRules(samples);

      // 2. 更新用户偏好
      await _updateUserPreferences(samples);

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

  List<DialogueRule> _extractDialogueRules(List<DialogueLearningData> samples) {
    final rules = <DialogueRule>[];

    // 只处理首轮对话且任务完成的样本
    final firstTurnSamples =
        samples.where((s) => s.isFirstTurn && s.taskCompleted).toList();

    // 按意图分组
    final intentGroups = groupBy(
      firstTurnSamples,
      (s) => (s.actualIntent ?? s.predictedIntent).type,
    );

    for (final entry in intentGroups.entries) {
      if (entry.value.length >= _minSamplesForRule) {
        // 提取开场关键词
        final keywords = _extractOpeningKeywords(
          entry.value.map((s) => s.context.userMessage),
        );

        if (keywords.isNotEmpty) {
          // 计算平均轮数
          final avgTurns =
              entry.value.map((s) => s.totalTurns).reduce((a, b) => a + b) /
                  entry.value.length;

          rules.add(DialogueRule(
            ruleId: 'dialogue_${entry.key.name}_${keywords.first.hashCode}',
            greetingPattern: keywords.first,
            intentType: entry.key,
            confidence: entry.value.length / firstTurnSamples.length,
            source: RuleSource.userLearned,
            keywords: keywords,
            expectedTurns: avgTurns.round(),
          ));
        }
      }
    }

    return rules;
  }

  List<String> _extractOpeningKeywords(Iterable<String> messages) {
    final wordFreq = <String, int>{};

    for (final message in messages) {
      final opening = _extractOpening(message);
      if (opening.isNotEmpty) {
        wordFreq[opening] = (wordFreq[opening] ?? 0) + 1;
      }
    }

    // 返回频率最高的开场词
    final sorted = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }

  String _extractOpening(String message) {
    final words = message.split(RegExp(r'\s+'));
    if (words.isEmpty) return '';

    // 取前几个词作为开场
    return words.take(3).join(' ').toLowerCase();
  }

  Future<void> _updateUserPreferences(
      List<DialogueLearningData> samples) async {
    final userGroups = groupBy(samples, (s) => s.userId);

    for (final entry in userGroups.entries) {
      final userId = entry.key;
      final userSamples = entry.value;

      final prefs = await learnDialoguePreferences(userId, userSamples);
      _userPreferences[userId] = prefs;
    }
  }

  /// 学习用户对话偏好
  Future<UserDialoguePreferences> learnDialoguePreferences(
    String userId,
    List<DialogueLearningData> samples,
  ) async {
    // 构建开场-意图映射
    final greetingMappings = <String, DialogueIntent>{};
    for (final sample in samples) {
      if (sample.isFirstTurn && sample.taskCompleted) {
        final opening = _extractOpening(sample.context.userMessage);
        greetingMappings[opening] = sample.actualIntent ?? sample.predictedIntent;
      }
    }

    // 计算表达详细度
    final verbosityLevel = _calculateVerbosityLevel(samples);

    // 计算确认风格
    final confirmationStyle = _inferConfirmationStyle(samples);

    // 计算平均轮数
    final avgTurns = samples.isEmpty
        ? 2.0
        : samples.map((s) => s.totalTurns).reduce((a, b) => a + b) /
            samples.length;

    return UserDialoguePreferences(
      greetingIntentMappings: greetingMappings,
      verbosityLevel: verbosityLevel,
      confirmationStyle: confirmationStyle,
      averageTurns: avgTurns,
    );
  }

  VerbosityLevel _calculateVerbosityLevel(List<DialogueLearningData> samples) {
    if (samples.isEmpty) return VerbosityLevel.normal;

    final avgLength = samples
            .map((s) => s.context.userMessage.length)
            .reduce((a, b) => a + b) /
        samples.length;

    if (avgLength < 10) return VerbosityLevel.concise;
    if (avgLength > 30) return VerbosityLevel.detailed;
    return VerbosityLevel.normal;
  }

  ConfirmationStyle _inferConfirmationStyle(List<DialogueLearningData> samples) {
    final completedSamples = samples.where((s) => s.taskCompleted).toList();
    if (completedSamples.isEmpty) return ConfirmationStyle.explicit;

    final avgTurns = completedSamples
            .map((s) => s.totalTurns)
            .reduce((a, b) => a + b) /
        completedSamples.length;

    if (avgTurns <= 1.5) return ConfirmationStyle.none;
    if (avgTurns <= 2.5) return ConfirmationStyle.implicit;
    return ConfirmationStyle.explicit;
  }

  void _upsertRule(DialogueRule newRule) {
    final existingIndex = _rules.indexWhere(
      (r) =>
          r.greetingPattern == newRule.greetingPattern &&
          r.intentType == newRule.intentType,
    );

    if (existingIndex >= 0) {
      final existing = _rules[existingIndex];
      if (newRule.confidence > existing.confidence) {
        _rules[existingIndex] = newRule;
      }
    } else {
      _rules.add(newRule);
    }
  }

  @override
  Future<PredictionResult<DialogueRule>> predict(dynamic input) async {
    final context = input as DialogueContext;

    // 1. 检查学习的规则
    for (final rule in _rules) {
      if (rule.matches(context)) {
        rule.recordHit();
        return PredictionResult(
          matched: true,
          matchedRule: rule,
          result: rule.apply(context),
          confidence: rule.confidence,
          source: PredictionSource.learnedRule,
        );
      }
    }

    // 2. 使用默认规则
    final defaultIntent = _inferDefaultIntent(context);
    return PredictionResult(
      matched: defaultIntent != null,
      result: defaultIntent,
      confidence: defaultIntent != null ? 0.5 : 0,
      source: PredictionSource.fallback,
    );
  }

  DialogueIntent? _inferDefaultIntent(DialogueContext context) {
    final message = context.userMessage.toLowerCase();

    // 问候
    if (_matchesAny(message, ['你好', '早上好', '下午好', '晚上好', 'hi', 'hello'])) {
      return const DialogueIntent(
          type: DialogueIntentType.greeting, confidence: 0.8);
    }

    // 记账
    if (_matchesAny(message, ['记', '花了', '买了', '支出', '消费'])) {
      return const DialogueIntent(
          type: DialogueIntentType.addExpense, confidence: 0.7);
    }

    // 收入
    if (_matchesAny(message, ['收到', '入账', '工资', '收入'])) {
      return const DialogueIntent(
          type: DialogueIntentType.addIncome, confidence: 0.7);
    }

    // 查询
    if (_matchesAny(message, ['查', '看看', '多少', '花了'])) {
      return const DialogueIntent(
          type: DialogueIntentType.querySpending, confidence: 0.6);
    }

    // 预算
    if (_matchesAny(message, ['预算', '设置', '限额'])) {
      return const DialogueIntent(
          type: DialogueIntentType.queryBudget, confidence: 0.6);
    }

    // 帮助
    if (_matchesAny(message, ['帮助', '怎么', '如何', '帮我'])) {
      return const DialogueIntent(type: DialogueIntentType.help, confidence: 0.6);
    }

    // 确认
    if (_matchesAny(message, ['是', '对', '确认', '好的', '可以'])) {
      return const DialogueIntent(
          type: DialogueIntentType.confirm, confidence: 0.7);
    }

    // 取消
    if (_matchesAny(message, ['取消', '算了', '不要'])) {
      return const DialogueIntent(
          type: DialogueIntentType.cancel, confidence: 0.7);
    }

    return null;
  }

  bool _matchesAny(String message, List<String> patterns) {
    return patterns.any((p) => message.contains(p));
  }

  @override
  Future<LearningMetrics> getMetrics() async {
    final completedSamples = _samples.where((s) => s.taskCompleted).length;
    final accuracy =
        _samples.isEmpty ? 0.0 : completedSamples / _samples.length;

    final abandonedSamples = _samples.where((s) => s.userAbandoned).length;
    final abandonmentRate =
        _samples.isEmpty ? 0.0 : abandonedSamples / _samples.length;

    return LearningMetrics(
      moduleId: moduleId,
      measureTime: DateTime.now(),
      totalSamples: _samples.length,
      totalRules: _rules.length,
      accuracy: accuracy,
      precision: accuracy,
      recall: accuracy,
      f1Score: accuracy,
      avgResponseTime: 3.0,
      customMetrics: {
        'completion_rate': accuracy,
        'abandonment_rate': abandonmentRate,
        'avg_turns': _calculateAverageTurns(),
        'user_preferences_count': _userPreferences.length,
      },
    );
  }

  double _calculateAverageTurns() {
    if (_samples.isEmpty) return 0;
    return _samples.map((s) => s.totalTurns).reduce((a, b) => a + b) /
        _samples.length;
  }

  @override
  Future<List<DialogueRule>> getRules({RuleSource? source, int? limit}) async {
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
        'user_preferences_count': _userPreferences.length,
      },
    );
  }

  @override
  Future<void> importModel(ModelExportData data) async {
    for (final ruleData in data.rules) {
      final rule = DialogueRule.fromStorable(ruleData);
      _upsertRule(rule);
    }
    _updateStage();
  }

  @override
  Future<void> clearData({bool keepRules = true}) async {
    _samples.clear();
    _userPreferences.clear();
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

// ==================== 对话失败分析 ====================

/// 对话失败分析服务
class DialogueFailureAnalyzer {
  final DialogueLearningService _learningService;

  DialogueFailureAnalyzer(this._learningService);

  /// 分析对话失败原因
  Future<DialogueFailureAnalysis> analyzeFailures(String userId) async {
    final status = await _learningService.getStatus();
    // 这里应该从服务获取失败样本，简化实现
    return DialogueFailureAnalysis(
      commonFailurePoints: [],
      abandonmentTurn: 3,
      problematicIntents: [],
    );
  }
}

/// 对话失败分析结果
class DialogueFailureAnalysis {
  final List<FailurePoint> commonFailurePoints;
  final int abandonmentTurn;
  final List<DialogueIntentType> problematicIntents;

  const DialogueFailureAnalysis({
    required this.commonFailurePoints,
    required this.abandonmentTurn,
    required this.problematicIntents,
  });
}

/// 失败点
class FailurePoint {
  final String description;
  final int frequency;
  final DialogueIntentType? relatedIntent;

  const FailurePoint({
    required this.description,
    required this.frequency,
    this.relatedIntent,
  });
}

// ==================== 对话协同学习服务 ====================

/// 对话协同学习服务
class DialogueCollaborativeLearningService {
  final DialogueLearningService _learningService;

  DialogueCollaborativeLearningService(this._learningService);

  /// 上报成功对话模式（隐私保护）
  Future<void> reportSuccessfulDialogue(DialogueRule rule) async {
    if (rule.confidence < 0.8) return;

    final sanitizedPattern = SanitizedDialoguePattern(
      intentType: rule.intentType,
      keywords: rule.keywords,
      expectedTurns: rule.expectedTurns,
      confidence: rule.confidence,
    );

    // 实际实现会上报到服务端
    debugPrint('Reporting dialogue pattern: ${sanitizedPattern.toJson()}');
  }

  /// 下载协同规则
  Future<List<DialogueRule>> downloadCollaborativeRules() async {
    // 实际实现会从服务端下载
    return [];
  }
}

/// 脱敏后的对话模式
class SanitizedDialoguePattern {
  final DialogueIntentType intentType;
  final List<String> keywords;
  final int expectedTurns;
  final double confidence;

  const SanitizedDialoguePattern({
    required this.intentType,
    required this.keywords,
    required this.expectedTurns,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'intent_type': intentType.name,
        'keywords': keywords,
        'expected_turns': expectedTurns,
        'confidence': confidence,
      };
}
