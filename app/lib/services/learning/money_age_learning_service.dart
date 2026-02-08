import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart'; // ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'unified_self_learning_service.dart';

// ==================== 钱龄学习数据模型 ====================

/// 钱龄学习样本
class MoneyAgeLearningData extends LearningData {
  /// 当时的平均钱龄
  final int moneyAge;

  /// 当时的钱龄等级
  final MoneyAgeLevel level;

  /// 当天收入
  final double dayIncome;

  /// 当天支出
  final double dayExpense;

  /// 资金流入来源分布
  final Map<String, double> incomeBySource;

  /// 资金流出分类分布
  final Map<String, double> expenseByCategory;

  /// 时段（0-23小时）
  final int hour;

  /// 星期几（1-7）
  final int dayOfWeek;

  /// 是否为发薪日
  final bool isPayday;

  /// 是否为月初
  final bool isMonthStart;

  /// 是否为月末
  final bool isMonthEnd;

  /// 用户对钱龄变化的反馈（正面/负面/中性）
  final MoneyAgeFeedback? feedback;

  MoneyAgeLearningData({
    required super.id,
    required super.timestamp,
    required super.userId,
    required this.moneyAge,
    required this.level,
    required this.dayIncome,
    required this.dayExpense,
    this.incomeBySource = const {},
    this.expenseByCategory = const {},
    required this.hour,
    required this.dayOfWeek,
    this.isPayday = false,
    this.isMonthStart = false,
    this.isMonthEnd = false,
    this.feedback,
  }) : super(
          features: {
            'money_age': moneyAge,
            'level': level.name,
            'day_income': dayIncome,
            'day_expense': dayExpense,
            'hour': hour,
            'day_of_week': dayOfWeek,
            'is_payday': isPayday,
            'is_month_start': isMonthStart,
            'is_month_end': isMonthEnd,
          },
          label: level.name,
          source: feedback != null
              ? LearningDataSource.userExplicitFeedback
              : LearningDataSource.userImplicitBehavior,
        );

  /// 日净流入（收入-支出）
  double get netFlow => dayIncome - dayExpense;

  /// 储蓄率
  double get savingsRate =>
      dayIncome > 0 ? (dayIncome - dayExpense) / dayIncome : 0;

  /// 是否为正向样本（钱龄保持或提升）
  bool get isPositive => netFlow >= 0;

  @override
  Map<String, dynamic> toStorable() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'money_age': moneyAge,
        'level': level.name,
        'day_income': dayIncome,
        'day_expense': dayExpense,
        'income_by_source': incomeBySource,
        'expense_by_category': expenseByCategory,
        'hour': hour,
        'day_of_week': dayOfWeek,
        'is_payday': isPayday,
        'is_month_start': isMonthStart,
        'is_month_end': isMonthEnd,
        'feedback': feedback?.name,
      };

  factory MoneyAgeLearningData.fromStorable(Map<String, dynamic> data) {
    return MoneyAgeLearningData(
      id: data['id'] as String,
      timestamp: DateTime.parse(data['timestamp'] as String),
      userId: data['user_id'] as String,
      moneyAge: data['money_age'] as int,
      level: MoneyAgeLevel.values.firstWhere(
        (l) => l.name == data['level'],
        orElse: () => MoneyAgeLevel.normal,
      ),
      dayIncome: (data['day_income'] as num).toDouble(),
      dayExpense: (data['day_expense'] as num).toDouble(),
      incomeBySource: Map<String, double>.from(
        (data['income_by_source'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
      expenseByCategory: Map<String, double>.from(
        (data['expense_by_category'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
      hour: data['hour'] as int,
      dayOfWeek: data['day_of_week'] as int,
      isPayday: data['is_payday'] as bool? ?? false,
      isMonthStart: data['is_month_start'] as bool? ?? false,
      isMonthEnd: data['is_month_end'] as bool? ?? false,
      feedback: data['feedback'] != null
          ? MoneyAgeFeedback.values.firstWhere(
              (f) => f.name == data['feedback'],
              orElse: () => MoneyAgeFeedback.neutral,
            )
          : null,
    );
  }

  @override
  LearningData anonymize() => MoneyAgeLearningData(
        id: id,
        timestamp: timestamp,
        userId: _hashValue(userId),
        moneyAge: _anonymizeAge(moneyAge),
        level: level,
        dayIncome: _anonymizeAmount(dayIncome),
        dayExpense: _anonymizeAmount(dayExpense),
        incomeBySource: {},
        expenseByCategory: {},
        hour: hour,
        dayOfWeek: dayOfWeek,
        isPayday: isPayday,
        isMonthStart: isMonthStart,
        isMonthEnd: isMonthEnd,
        feedback: feedback,
      );

  static String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 钱龄区间化（保护隐私）
  static int _anonymizeAge(int age) {
    if (age < 7) return 5;
    if (age < 14) return 10;
    if (age < 30) return 20;
    if (age < 60) return 45;
    if (age < 90) return 75;
    return 100;
  }

  /// 金额区间化（保护隐私）
  static double _anonymizeAmount(double amount) {
    if (amount < 100) return 50;
    if (amount < 500) return 300;
    if (amount < 1000) return 750;
    if (amount < 5000) return 3000;
    if (amount < 10000) return 7500;
    return 15000;
  }
}

/// 钱龄反馈类型
enum MoneyAgeFeedback {
  positive, // 用户满意钱龄状态
  negative, // 用户不满意
  neutral, // 中性
}

/// 钱龄等级
enum MoneyAgeLevel {
  danger, // 危险 < 7天
  warning, // 警告 7-14天
  normal, // 正常 14-30天
  good, // 良好 30-60天
  excellent, // 优秀 60-90天
  ideal, // 理想 > 90天
}

extension MoneyAgeLevelExtension on MoneyAgeLevel {
  int get minDays {
    switch (this) {
      case MoneyAgeLevel.danger:
        return 0;
      case MoneyAgeLevel.warning:
        return 7;
      case MoneyAgeLevel.normal:
        return 14;
      case MoneyAgeLevel.good:
        return 30;
      case MoneyAgeLevel.excellent:
        return 60;
      case MoneyAgeLevel.ideal:
        return 90;
    }
  }

  String get displayName {
    switch (this) {
      case MoneyAgeLevel.danger:
        return '危险';
      case MoneyAgeLevel.warning:
        return '警告';
      case MoneyAgeLevel.normal:
        return '正常';
      case MoneyAgeLevel.good:
        return '良好';
      case MoneyAgeLevel.excellent:
        return '优秀';
      case MoneyAgeLevel.ideal:
        return '理想';
    }
  }
}

// ==================== 钱龄学习规则 ====================

/// 钱龄优化规则
class MoneyAgeRule extends LearnedRule {
  /// 规则类型
  final MoneyAgeRuleType ruleType;

  /// 触发条件
  final Map<String, dynamic> conditions;

  /// 预测的钱龄变化
  final int predictedAgeChange;

  /// 建议动作
  final String? suggestedAction;

  /// 适用的时段（可选）
  final List<int>? applicableHours;

  /// 适用的星期（可选）
  final List<int>? applicableDays;

  MoneyAgeRule({
    required super.ruleId,
    required this.ruleType,
    required this.conditions,
    required this.predictedAgeChange,
    this.suggestedAction,
    this.applicableHours,
    this.applicableDays,
    required super.confidence,
    required super.source,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    super.hitCount,
  }) : super(
          moduleId: 'money_age_learning',
          priority: source == RuleSource.userLearned ? 100 : 50,
          createdAt: createdAt ?? DateTime.now(),
          lastUsedAt: lastUsedAt ?? DateTime.now(),
        );

  @override
  bool matches(dynamic input) {
    if (input is! MoneyAgeLearningData) return false;

    // 检查时段条件
    if (applicableHours != null && !applicableHours!.contains(input.hour)) {
      return false;
    }

    // 检查星期条件
    if (applicableDays != null && !applicableDays!.contains(input.dayOfWeek)) {
      return false;
    }

    // 检查具体条件
    for (final entry in conditions.entries) {
      switch (entry.key) {
        case 'level':
          if (input.level.name != entry.value) return false;
          break;
        case 'min_expense':
          if (input.dayExpense < (entry.value as num)) return false;
          break;
        case 'max_expense':
          if (input.dayExpense > (entry.value as num)) return false;
          break;
        case 'is_payday':
          if (input.isPayday != entry.value) return false;
          break;
        case 'is_month_end':
          if (input.isMonthEnd != entry.value) return false;
          break;
        case 'savings_rate_min':
          if (input.savingsRate < (entry.value as num)) return false;
          break;
      }
    }

    return true;
  }

  @override
  dynamic apply(dynamic input) => MoneyAgeRuleResult(
        predictedAgeChange: predictedAgeChange,
        suggestedAction: suggestedAction,
        confidence: confidence,
      );

  @override
  Map<String, dynamic> toStorable() => {
        'rule_id': ruleId,
        'rule_type': ruleType.name,
        'conditions': conditions,
        'predicted_age_change': predictedAgeChange,
        'suggested_action': suggestedAction,
        'applicable_hours': applicableHours,
        'applicable_days': applicableDays,
        'confidence': confidence,
        'source': source.name,
        'created_at': createdAt.toIso8601String(),
        'last_used_at': lastUsedAt.toIso8601String(),
        'hit_count': hitCount,
      };

  factory MoneyAgeRule.fromStorable(Map<String, dynamic> data) {
    return MoneyAgeRule(
      ruleId: data['rule_id'] as String,
      ruleType: MoneyAgeRuleType.values.firstWhere(
        (t) => t.name == data['rule_type'],
        orElse: () => MoneyAgeRuleType.consumptionPattern,
      ),
      conditions: Map<String, dynamic>.from(data['conditions'] as Map),
      predictedAgeChange: data['predicted_age_change'] as int,
      suggestedAction: data['suggested_action'] as String?,
      applicableHours: (data['applicable_hours'] as List?)?.cast<int>(),
      applicableDays: (data['applicable_days'] as List?)?.cast<int>(),
      confidence: (data['confidence'] as num).toDouble(),
      source: RuleSource.values.firstWhere(
        (s) => s.name == data['source'],
        orElse: () => RuleSource.userLearned,
      ),
      createdAt: DateTime.parse(data['created_at'] as String),
      lastUsedAt: DateTime.parse(data['last_used_at'] as String),
      hitCount: data['hit_count'] as int? ?? 0,
    );
  }
}

/// 钱龄规则类型
enum MoneyAgeRuleType {
  consumptionPattern, // 消费模式规则
  incomePattern, // 收入模式规则
  periodicPattern, // 周期性模式规则
  seasonalPattern, // 季节性模式规则
  behaviorSuggestion, // 行为建议规则
}

/// 钱龄规则应用结果
class MoneyAgeRuleResult {
  final int predictedAgeChange;
  final String? suggestedAction;
  final double confidence;

  const MoneyAgeRuleResult({
    required this.predictedAgeChange,
    this.suggestedAction,
    required this.confidence,
  });
}

// ==================== 钱龄自学习适配器 ====================

/// 钱龄自学习适配器
class MoneyAgeLearningAdapter
    implements ISelfLearningModule<MoneyAgeLearningData, MoneyAgeRule> {
  @override
  String get moduleId => 'money_age_learning';

  @override
  String get moduleName => '钱龄学习';

  // 存储
  final List<MoneyAgeLearningData> _samples = [];
  final List<MoneyAgeRule> _rules = [];
  final List<_PredictionRecord> _predictionHistory = [];

  // 统计数据
  final Map<int, _DayOfWeekStats> _dayOfWeekStats = {};
  final Map<int, _HourStats> _hourStats = {};
  final Map<String, _CategoryStats> _categoryExpenseStats = {};

  // 配置
  static const int _minSamplesForRule = 5;
  // ignore: unused_field
  static const double _minConfidenceThreshold = 0.6;

  // 状态
  final bool _isEnabled = true;
  DateTime? _lastTrainingTime;
  LearningStage _stage = LearningStage.coldStart;

  @override
  Future<void> collectSample(MoneyAgeLearningData data) async {
    _samples.add(data);
    _updateStats(data);
    _updateStage();
    debugPrint(
        'Collected money age sample: age=${data.moneyAge}, level=${data.level.name}');
  }

  @override
  Future<void> collectSamples(List<MoneyAgeLearningData> dataList) async {
    for (final data in dataList) {
      await collectSample(data);
    }
  }

  void _updateStats(MoneyAgeLearningData data) {
    // 更新星期统计
    _dayOfWeekStats.putIfAbsent(data.dayOfWeek, () => _DayOfWeekStats());
    _dayOfWeekStats[data.dayOfWeek]!.addSample(data);

    // 更新小时统计
    _hourStats.putIfAbsent(data.hour, () => _HourStats());
    _hourStats[data.hour]!.addSample(data);

    // 更新分类支出统计
    for (final entry in data.expenseByCategory.entries) {
      _categoryExpenseStats.putIfAbsent(entry.key, () => _CategoryStats());
      _categoryExpenseStats[entry.key]!.addAmount(entry.value);
    }
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

      final newRules = <MoneyAgeRule>[];

      // 1. 学习消费模式规则
      newRules.addAll(_learnConsumptionPatterns(samples));

      // 2. 学习周期性模式规则
      newRules.addAll(_learnPeriodicPatterns(samples));

      // 3. 学习行为建议规则
      newRules.addAll(_learnBehaviorSuggestions(samples));

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

  /// 学习消费模式规则
  List<MoneyAgeRule> _learnConsumptionPatterns(
      List<MoneyAgeLearningData> samples) {
    final rules = <MoneyAgeRule>[];

    // 按钱龄等级分组分析
    final byLevel = groupBy(samples, (s) => s.level);

    for (final entry in byLevel.entries) {
      if (entry.value.length < _minSamplesForRule) continue;

      // 计算该等级的平均支出
      final avgExpense =
          entry.value.map((s) => s.dayExpense).reduce((a, b) => a + b) /
              entry.value.length;

      // 计算平均钱龄变化（通过相邻样本）
      final avgAgeChange = _calculateAverageAgeChange(entry.value);

      // 生成规则
      rules.add(MoneyAgeRule(
        ruleId:
            'consumption_${entry.key.name}_${DateTime.now().millisecondsSinceEpoch}',
        ruleType: MoneyAgeRuleType.consumptionPattern,
        conditions: {
          'level': entry.key.name,
          'max_expense': avgExpense * 1.5,
        },
        predictedAgeChange: avgAgeChange.round(),
        suggestedAction: _generateConsumptionSuggestion(entry.key, avgExpense),
        confidence: entry.value.length / samples.length,
        source: RuleSource.userLearned,
      ));
    }

    return rules;
  }

  /// 学习周期性模式规则
  List<MoneyAgeRule> _learnPeriodicPatterns(
      List<MoneyAgeLearningData> samples) {
    final rules = <MoneyAgeRule>[];

    // 分析发薪日模式
    final paydaySamples = samples.where((s) => s.isPayday).toList();
    if (paydaySamples.length >= 3) {
      final avgIncomeOnPayday =
          paydaySamples.map((s) => s.dayIncome).reduce((a, b) => a + b) /
              paydaySamples.length;

      rules.add(MoneyAgeRule(
        ruleId: 'payday_pattern_${DateTime.now().millisecondsSinceEpoch}',
        ruleType: MoneyAgeRuleType.incomePattern,
        conditions: {'is_payday': true},
        predictedAgeChange: _estimateAgeChangeFromIncome(avgIncomeOnPayday),
        suggestedAction: '发薪日，建议先划拨预算和储蓄',
        confidence: paydaySamples.length / samples.length,
        source: RuleSource.userLearned,
      ));
    }

    // 分析月末模式
    final monthEndSamples = samples.where((s) => s.isMonthEnd).toList();
    if (monthEndSamples.length >= 3) {
      final avgExpenseAtMonthEnd =
          monthEndSamples.map((s) => s.dayExpense).reduce((a, b) => a + b) /
              monthEndSamples.length;

      rules.add(MoneyAgeRule(
        ruleId: 'month_end_pattern_${DateTime.now().millisecondsSinceEpoch}',
        ruleType: MoneyAgeRuleType.periodicPattern,
        conditions: {'is_month_end': true},
        predictedAgeChange: -_estimateAgeChangeFromExpense(avgExpenseAtMonthEnd),
        suggestedAction: '月末消费高峰期，注意控制支出',
        confidence: monthEndSamples.length / samples.length,
        source: RuleSource.userLearned,
      ));
    }

    // 分析星期模式
    for (final entry in _dayOfWeekStats.entries) {
      if (entry.value.sampleCount >= _minSamplesForRule) {
        final avgNetFlow = entry.value.avgNetFlow;
        if (avgNetFlow.abs() > 100) {
          // 显著的资金流动
          rules.add(MoneyAgeRule(
            ruleId:
                'weekday_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
            ruleType: MoneyAgeRuleType.periodicPattern,
            conditions: {},
            applicableDays: [entry.key],
            predictedAgeChange: (avgNetFlow / 100).round(),
            suggestedAction: avgNetFlow > 0
                ? '周${_weekdayName(entry.key)}通常有正向资金流入'
                : '周${_weekdayName(entry.key)}支出较多，注意预算',
            confidence: 0.7,
            source: RuleSource.userLearned,
          ));
        }
      }
    }

    return rules;
  }

  /// 学习行为建议规则
  List<MoneyAgeRule> _learnBehaviorSuggestions(
      List<MoneyAgeLearningData> samples) {
    final rules = <MoneyAgeRule>[];

    // 分析高储蓄率样本
    final highSavingsSamples =
        samples.where((s) => s.savingsRate > 0.3).toList();
    if (highSavingsSamples.length >= _minSamplesForRule) {
      rules.add(MoneyAgeRule(
        ruleId: 'high_savings_suggestion_${DateTime.now().millisecondsSinceEpoch}',
        ruleType: MoneyAgeRuleType.behaviorSuggestion,
        conditions: {'savings_rate_min': 0.3},
        predictedAgeChange: 3,
        suggestedAction: '保持当前储蓄习惯，钱龄将持续改善',
        confidence: highSavingsSamples.length / samples.length,
        source: RuleSource.userLearned,
      ));
    }

    // 分析危险等级样本
    final dangerSamples =
        samples.where((s) => s.level == MoneyAgeLevel.danger).toList();
    if (dangerSamples.length >= 3) {
      final avgExpense =
          dangerSamples.map((s) => s.dayExpense).reduce((a, b) => a + b) /
              dangerSamples.length;

      rules.add(MoneyAgeRule(
        ruleId: 'danger_alert_${DateTime.now().millisecondsSinceEpoch}',
        ruleType: MoneyAgeRuleType.behaviorSuggestion,
        conditions: {'level': 'danger'},
        predictedAgeChange: -2,
        suggestedAction: '钱龄处于危险水平，建议将日支出控制在${(avgExpense * 0.7).toStringAsFixed(0)}元以内',
        confidence: 0.8,
        source: RuleSource.userLearned,
      ));
    }

    return rules;
  }

  double _calculateAverageAgeChange(List<MoneyAgeLearningData> samples) {
    if (samples.length < 2) return 0;

    final sorted = samples.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalChange = 0;
    int count = 0;

    for (var i = 1; i < sorted.length; i++) {
      totalChange += sorted[i].moneyAge - sorted[i - 1].moneyAge;
      count++;
    }

    return count > 0 ? totalChange / count : 0;
  }

  String _generateConsumptionSuggestion(MoneyAgeLevel level, double avgExpense) {
    switch (level) {
      case MoneyAgeLevel.danger:
        return '建议将日均支出控制在${(avgExpense * 0.5).toStringAsFixed(0)}元以内以改善钱龄';
      case MoneyAgeLevel.warning:
        return '建议适当减少非必要支出，目标日均${(avgExpense * 0.7).toStringAsFixed(0)}元';
      case MoneyAgeLevel.normal:
        return '消费水平适中，保持当前习惯';
      case MoneyAgeLevel.good:
        return '消费习惯良好，继续保持';
      case MoneyAgeLevel.excellent:
        return '财务状况优秀，可适当犒劳自己';
      case MoneyAgeLevel.ideal:
        return '理想的财务状态，资金储备充足';
    }
  }

  int _estimateAgeChangeFromIncome(double income) {
    // 简化估算：每1000元收入约增加1天钱龄
    return (income / 1000).round().clamp(1, 30);
  }

  int _estimateAgeChangeFromExpense(double expense) {
    // 简化估算：每500元支出约减少1天钱龄
    return (expense / 500).round().clamp(1, 15);
  }

  String _weekdayName(int day) {
    const names = ['', '一', '二', '三', '四', '五', '六', '日'];
    return names[day.clamp(1, 7)];
  }

  void _upsertRule(MoneyAgeRule newRule) {
    final existingIndex = _rules.indexWhere((r) => r.ruleId == newRule.ruleId);

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
  Future<PredictionResult<MoneyAgeRule>> predict(dynamic input) async {
    final data = input as MoneyAgeLearningData;

    // 按优先级排序规则
    final sortedRules = _rules.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in sortedRules) {
      if (rule.matches(data)) {
        rule.recordHit();
        final result = rule.apply(data) as MoneyAgeRuleResult;

        _recordPrediction(data, result, true);

        return PredictionResult(
          matched: true,
          matchedRule: rule,
          result: result,
          confidence: rule.confidence,
          source: rule.source == RuleSource.userLearned
              ? PredictionSource.learnedRule
              : PredictionSource.fallback,
        );
      }
    }

    _recordPrediction(data, null, false);

    return PredictionResult(
      matched: false,
      confidence: 0,
      source: PredictionSource.fallback,
    );
  }

  void _recordPrediction(
      MoneyAgeLearningData data, MoneyAgeRuleResult? result, bool matched) {
    _predictionHistory.add(_PredictionRecord(
      timestamp: DateTime.now(),
      moneyAge: data.moneyAge,
      level: data.level,
      predictedChange: result?.predictedAgeChange,
      matched: matched,
    ));

    if (_predictionHistory.length > 1000) {
      _predictionHistory.removeRange(0, _predictionHistory.length - 1000);
    }
  }

  @override
  Future<LearningMetrics> getMetrics() async {
    final recentPredictions = _predictionHistory
        .where((p) =>
            p.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
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
      precision: accuracy,
      recall: accuracy,
      f1Score: accuracy,
      avgResponseTime: 3.0,
      customMetrics: {
        'user_rules': _rules.where((r) => r.source == RuleSource.userLearned).length,
        'collaborative_rules':
            _rules.where((r) => r.source == RuleSource.collaborative).length,
        'avg_money_age': _samples.isEmpty
            ? 0
            : _samples.map((s) => s.moneyAge).reduce((a, b) => a + b) /
                _samples.length,
      },
    );
  }

  @override
  Future<List<MoneyAgeRule>> getRules({RuleSource? source, int? limit}) async {
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
      final rule = MoneyAgeRule.fromStorable(ruleData);
      _upsertRule(rule);
    }
    _updateStage();
  }

  @override
  Future<void> clearData({bool keepRules = true}) async {
    _samples.clear();
    _predictionHistory.clear();
    _dayOfWeekStats.clear();
    _hourStats.clear();
    _categoryExpenseStats.clear();
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

  /// 获取钱龄改善建议
  Future<List<MoneyAgeImproveAdvice>> getImproveAdvice(
      MoneyAgeLearningData currentData) async {
    final advice = <MoneyAgeImproveAdvice>[];

    // 基于规则生成建议
    for (final rule in _rules) {
      if (rule.ruleType == MoneyAgeRuleType.behaviorSuggestion &&
          rule.matches(currentData)) {
        if (rule.suggestedAction != null) {
          advice.add(MoneyAgeImproveAdvice(
            title: '行为建议',
            description: rule.suggestedAction!,
            expectedAgeChange: rule.predictedAgeChange,
            confidence: rule.confidence,
            source: AdviceSource.learned,
          ));
        }
      }
    }

    // 基于统计数据生成建议
    if (currentData.level.index <= MoneyAgeLevel.warning.index) {
      // 找出支出最高的分类
      if (_categoryExpenseStats.isNotEmpty) {
        final topCategory = _categoryExpenseStats.entries
            .reduce((a, b) => a.value.totalAmount > b.value.totalAmount ? a : b);

        advice.add(MoneyAgeImproveAdvice(
          title: '支出分析',
          description: '${topCategory.key}类支出最高，考虑适当控制',
          expectedAgeChange: 2,
          confidence: 0.6,
          source: AdviceSource.statistics,
        ));
      }
    }

    return advice;
  }
}

class _PredictionRecord {
  final DateTime timestamp;
  final int moneyAge;
  final MoneyAgeLevel level;
  final int? predictedChange;
  final bool matched;
  /// 实际钱龄变化（用于未来预测准确度评估）
  int? actualChange; // ignore: unused_element_parameter

  _PredictionRecord({
    required this.timestamp,
    required this.moneyAge,
    required this.level,
    this.predictedChange,
    required this.matched,
  });
}

class _DayOfWeekStats {
  final List<MoneyAgeLearningData> _samples = [];

  void addSample(MoneyAgeLearningData data) => _samples.add(data);

  int get sampleCount => _samples.length;

  double get avgNetFlow {
    if (_samples.isEmpty) return 0;
    return _samples.map((s) => s.netFlow).reduce((a, b) => a + b) /
        _samples.length;
  }

  double get avgMoneyAge {
    if (_samples.isEmpty) return 0;
    return _samples.map((s) => s.moneyAge).reduce((a, b) => a + b) /
        _samples.length;
  }
}

class _HourStats {
  final List<MoneyAgeLearningData> _samples = [];

  void addSample(MoneyAgeLearningData data) => _samples.add(data);

  int get sampleCount => _samples.length;

  double get avgExpense {
    if (_samples.isEmpty) return 0;
    return _samples.map((s) => s.dayExpense).reduce((a, b) => a + b) /
        _samples.length;
  }
}

class _CategoryStats {
  double totalAmount = 0;
  int count = 0;

  void addAmount(double amount) {
    totalAmount += amount;
    count++;
  }

  double get avgAmount => count > 0 ? totalAmount / count : 0;
}

/// 钱龄改善建议
class MoneyAgeImproveAdvice {
  final String title;
  final String description;
  final int expectedAgeChange;
  final double confidence;
  final AdviceSource source;

  const MoneyAgeImproveAdvice({
    required this.title,
    required this.description,
    required this.expectedAgeChange,
    required this.confidence,
    required this.source,
  });
}

enum AdviceSource {
  learned, // 学习生成
  statistics, // 统计分析
  collaborative, // 协同学习
}

// ==================== 脱敏数据模型（协同学习） ====================

/// 脱敏后的钱龄模式
class SanitizedMoneyAgePattern {
  /// 钱龄区间
  final int ageRange;

  /// 钱龄等级
  final MoneyAgeLevel level;

  /// 储蓄率区间
  final String savingsRateRange;

  /// 消费模式（高/中/低）
  final String consumptionPattern;

  /// 收入频率模式
  final String incomeFrequency;

  /// 时段偏好
  final int? peakSpendingHour;

  /// 用户哈希
  final String userHash;

  /// 时间戳
  final DateTime timestamp;

  const SanitizedMoneyAgePattern({
    required this.ageRange,
    required this.level,
    required this.savingsRateRange,
    required this.consumptionPattern,
    required this.incomeFrequency,
    this.peakSpendingHour,
    required this.userHash,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'age_range': ageRange,
        'level': level.name,
        'savings_rate_range': savingsRateRange,
        'consumption_pattern': consumptionPattern,
        'income_frequency': incomeFrequency,
        'peak_spending_hour': peakSpendingHour,
        'user_hash': userHash,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SanitizedMoneyAgePattern.fromJson(Map<String, dynamic> json) {
    return SanitizedMoneyAgePattern(
      ageRange: json['age_range'] as int,
      level: MoneyAgeLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => MoneyAgeLevel.normal,
      ),
      savingsRateRange: json['savings_rate_range'] as String,
      consumptionPattern: json['consumption_pattern'] as String,
      incomeFrequency: json['income_frequency'] as String,
      peakSpendingHour: json['peak_spending_hour'] as int?,
      userHash: json['user_hash'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

// ==================== 全局钱龄洞察 ====================

/// 全局钱龄洞察
class GlobalMoneyAgeInsights {
  /// 各等级用户分布
  final Map<MoneyAgeLevel, double> levelDistribution;

  /// 平均钱龄
  final double averageMoneyAge;

  /// 各储蓄率区间分布
  final Map<String, double> savingsRateDistribution;

  /// 消费模式分布
  final Map<String, double> consumptionPatternDistribution;

  /// 最佳实践建议
  final List<GlobalBestPractice> bestPractices;

  /// 同等级用户的平均指标
  final Map<MoneyAgeLevel, LevelBenchmark> levelBenchmarks;

  /// 生成时间
  final DateTime generatedAt;

  const GlobalMoneyAgeInsights({
    required this.levelDistribution,
    required this.averageMoneyAge,
    required this.savingsRateDistribution,
    required this.consumptionPatternDistribution,
    required this.bestPractices,
    required this.levelBenchmarks,
    required this.generatedAt,
  });
}

/// 全局最佳实践
class GlobalBestPractice {
  final String title;
  final String description;
  final double adoptionRate;
  final int avgAgeImprovement;

  const GlobalBestPractice({
    required this.title,
    required this.description,
    required this.adoptionRate,
    required this.avgAgeImprovement,
  });
}

/// 等级基准指标
class LevelBenchmark {
  final MoneyAgeLevel level;
  final double avgSavingsRate;
  final double avgDailyExpense;
  final int avgDaysToNextLevel;

  const LevelBenchmark({
    required this.level,
    required this.avgSavingsRate,
    required this.avgDailyExpense,
    required this.avgDaysToNextLevel,
  });
}

// ==================== 钱龄协同学习服务 ====================

/// 钱龄协同学习服务
class MoneyAgeCollaborativeLearningService {
  final GlobalMoneyAgeInsightsAggregator _aggregator;
  final MoneyAgePatternReporter _reporter;
  final String _currentUserId;

  // 本地缓存
  GlobalMoneyAgeInsights? _insightsCache;
  DateTime? _lastInsightsUpdate;

  // 配置
  static const Duration _cacheExpiry = Duration(hours: 24);
  // ignore: unused_field
  static const double _privacyEpsilon = 0.1;

  MoneyAgeCollaborativeLearningService({
    GlobalMoneyAgeInsightsAggregator? aggregator,
    MoneyAgePatternReporter? reporter,
    String? currentUserId,
  })  : _aggregator = aggregator ?? GlobalMoneyAgeInsightsAggregator(),
        _reporter = reporter ?? InMemoryMoneyAgePatternReporter(),
        _currentUserId = currentUserId ?? 'anonymous';

  /// 上报钱龄模式（隐私保护）
  Future<void> reportMoneyAgePattern(MoneyAgeLearningData sample) async {
    // 脱敏处理
    final pattern = SanitizedMoneyAgePattern(
      ageRange: MoneyAgeLearningData._anonymizeAge(sample.moneyAge),
      level: sample.level,
      savingsRateRange: _getSavingsRateRange(sample.savingsRate),
      consumptionPattern: _getConsumptionPattern(sample.dayExpense),
      incomeFrequency: sample.isPayday ? 'payday' : 'regular',
      peakSpendingHour: sample.hour,
      userHash: _hashValue(_currentUserId),
      timestamp: DateTime.now(),
    );

    await _reporter.report(pattern);
    debugPrint('Reported money age pattern: level=${pattern.level.name}');
  }

  String _getSavingsRateRange(double rate) {
    if (rate < 0) return 'negative';
    if (rate < 0.1) return '0-10%';
    if (rate < 0.2) return '10-20%';
    if (rate < 0.3) return '20-30%';
    if (rate < 0.5) return '30-50%';
    return '50%+';
  }

  String _getConsumptionPattern(double expense) {
    if (expense < 100) return 'low';
    if (expense < 500) return 'medium';
    if (expense < 1000) return 'high';
    return 'very_high';
  }

  String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 获取全局钱龄洞察
  Future<GlobalMoneyAgeInsights> getGlobalInsights(
      {bool forceRefresh = false}) async {
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

  /// 获取同等级用户对比
  Future<LevelComparison> compareToPeers(
      MoneyAgeLevel level, double savingsRate) async {
    final insights = await getGlobalInsights();
    final benchmark = insights.levelBenchmarks[level];

    if (benchmark == null) {
      return LevelComparison(
        level: level,
        userSavingsRate: savingsRate,
        peerAvgSavingsRate: 0.15,
        percentile: 50,
        recommendation: '数据不足，无法对比',
      );
    }

    // 计算百分位
    final percentile = _calculatePercentile(savingsRate, benchmark.avgSavingsRate);

    String recommendation;
    if (percentile >= 75) {
      recommendation = '您的储蓄率高于同等级75%的用户，表现优秀！';
    } else if (percentile >= 50) {
      recommendation = '您的储蓄率处于同等级中等水平，还有提升空间';
    } else {
      recommendation = '建议提高储蓄率至${(benchmark.avgSavingsRate * 100).toStringAsFixed(0)}%以上';
    }

    return LevelComparison(
      level: level,
      userSavingsRate: savingsRate,
      peerAvgSavingsRate: benchmark.avgSavingsRate,
      percentile: percentile,
      recommendation: recommendation,
    );
  }

  int _calculatePercentile(double userValue, double avgValue) {
    // 简化计算：基于与平均值的比较
    final ratio = userValue / (avgValue > 0 ? avgValue : 0.15);
    if (ratio >= 1.5) return 90;
    if (ratio >= 1.2) return 75;
    if (ratio >= 1.0) return 60;
    if (ratio >= 0.8) return 40;
    if (ratio >= 0.5) return 25;
    return 10;
  }

  /// 获取钱龄改善最佳实践
  Future<List<GlobalBestPractice>> getBestPractices() async {
    final insights = await getGlobalInsights();
    return insights.bestPractices;
  }

  /// 批量上报
  Future<void> reportBatch(List<MoneyAgeLearningData> samples) async {
    for (final sample in samples) {
      await reportMoneyAgePattern(sample);
    }
  }
}

/// 等级对比结果
class LevelComparison {
  final MoneyAgeLevel level;
  final double userSavingsRate;
  final double peerAvgSavingsRate;
  final int percentile;
  final String recommendation;

  const LevelComparison({
    required this.level,
    required this.userSavingsRate,
    required this.peerAvgSavingsRate,
    required this.percentile,
    required this.recommendation,
  });
}

// ==================== 模式上报器 ====================

/// 钱龄模式上报器接口
abstract class MoneyAgePatternReporter {
  Future<void> report(SanitizedMoneyAgePattern pattern);
  Future<List<SanitizedMoneyAgePattern>> getAllPatterns();
}

/// 内存钱龄模式上报器
class InMemoryMoneyAgePatternReporter implements MoneyAgePatternReporter {
  final List<SanitizedMoneyAgePattern> _patterns = [];

  @override
  Future<void> report(SanitizedMoneyAgePattern pattern) async {
    _patterns.add(pattern);
  }

  @override
  Future<List<SanitizedMoneyAgePattern>> getAllPatterns() async {
    return List.unmodifiable(_patterns);
  }

  void clear() => _patterns.clear();
}

// ==================== 全局钱龄洞察聚合 ====================

/// 全局钱龄洞察聚合器
class GlobalMoneyAgeInsightsAggregator {
  final MoneyAgePatternReporter _db;

  GlobalMoneyAgeInsightsAggregator({MoneyAgePatternReporter? db})
      : _db = db ?? InMemoryMoneyAgePatternReporter();

  Future<GlobalMoneyAgeInsights> aggregate() async {
    final patterns = await _db.getAllPatterns();

    return GlobalMoneyAgeInsights(
      levelDistribution: _aggregateLevelDistribution(patterns),
      averageMoneyAge: _calculateAverageAge(patterns),
      savingsRateDistribution: _aggregateSavingsRateDistribution(patterns),
      consumptionPatternDistribution:
          _aggregateConsumptionPatternDistribution(patterns),
      bestPractices: _generateBestPractices(patterns),
      levelBenchmarks: _calculateLevelBenchmarks(patterns),
      generatedAt: DateTime.now(),
    );
  }

  Map<MoneyAgeLevel, double> _aggregateLevelDistribution(
      List<SanitizedMoneyAgePattern> patterns) {
    if (patterns.isEmpty) return _getDefaultLevelDistribution();

    final counts = <MoneyAgeLevel, int>{};
    for (final p in patterns) {
      counts[p.level] = (counts[p.level] ?? 0) + 1;
    }

    final total = patterns.length;
    return counts.map((k, v) => MapEntry(k, v / total));
  }

  Map<MoneyAgeLevel, double> _getDefaultLevelDistribution() {
    return {
      MoneyAgeLevel.danger: 0.05,
      MoneyAgeLevel.warning: 0.15,
      MoneyAgeLevel.normal: 0.35,
      MoneyAgeLevel.good: 0.25,
      MoneyAgeLevel.excellent: 0.15,
      MoneyAgeLevel.ideal: 0.05,
    };
  }

  double _calculateAverageAge(List<SanitizedMoneyAgePattern> patterns) {
    if (patterns.isEmpty) return 30.0;
    return patterns.map((p) => p.ageRange).reduce((a, b) => a + b) /
        patterns.length;
  }

  Map<String, double> _aggregateSavingsRateDistribution(
      List<SanitizedMoneyAgePattern> patterns) {
    if (patterns.isEmpty) {
      return {
        'negative': 0.1,
        '0-10%': 0.25,
        '10-20%': 0.30,
        '20-30%': 0.20,
        '30-50%': 0.10,
        '50%+': 0.05,
      };
    }

    final counts = <String, int>{};
    for (final p in patterns) {
      counts[p.savingsRateRange] = (counts[p.savingsRateRange] ?? 0) + 1;
    }

    final total = patterns.length;
    return counts.map((k, v) => MapEntry(k, v / total));
  }

  Map<String, double> _aggregateConsumptionPatternDistribution(
      List<SanitizedMoneyAgePattern> patterns) {
    if (patterns.isEmpty) {
      return {
        'low': 0.20,
        'medium': 0.45,
        'high': 0.25,
        'very_high': 0.10,
      };
    }

    final counts = <String, int>{};
    for (final p in patterns) {
      counts[p.consumptionPattern] = (counts[p.consumptionPattern] ?? 0) + 1;
    }

    final total = patterns.length;
    return counts.map((k, v) => MapEntry(k, v / total));
  }

  List<GlobalBestPractice> _generateBestPractices(
      List<SanitizedMoneyAgePattern> patterns) {
    // 分析高储蓄率用户的共同特征
    final highSaversPatterns = patterns
        .where((p) => p.savingsRateRange == '30-50%' || p.savingsRateRange == '50%+')
        .toList();

    final bestPractices = <GlobalBestPractice>[
      const GlobalBestPractice(
        title: '固定储蓄日',
        description: '每月发薪日固定转入储蓄账户20-30%',
        adoptionRate: 0.45,
        avgAgeImprovement: 15,
      ),
      const GlobalBestPractice(
        title: '消费冷静期',
        description: '大额消费前等待24小时再决定',
        adoptionRate: 0.32,
        avgAgeImprovement: 8,
      ),
      const GlobalBestPractice(
        title: '周预算制',
        description: '将月预算分解为周预算，更易控制',
        adoptionRate: 0.28,
        avgAgeImprovement: 10,
      ),
    ];

    // 如果有足够数据，添加数据驱动的建议
    if (highSaversPatterns.length >= 10) {
      // 分析高储蓄者的消费时段
      final hourCounts = <int, int>{};
      for (final p in highSaversPatterns) {
        if (p.peakSpendingHour != null) {
          hourCounts[p.peakSpendingHour!] =
              (hourCounts[p.peakSpendingHour!] ?? 0) + 1;
        }
      }

      if (hourCounts.isNotEmpty) {
        final peakHour = hourCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

        bestPractices.add(GlobalBestPractice(
          title: '合理消费时段',
          description: '高储蓄率用户多在$peakHour点左右集中消费，避免冲动购物',
          adoptionRate: highSaversPatterns.length / max(1, patterns.length),
          avgAgeImprovement: 5,
        ));
      }
    }

    return bestPractices;
  }

  Map<MoneyAgeLevel, LevelBenchmark> _calculateLevelBenchmarks(
      List<SanitizedMoneyAgePattern> patterns) {
    final benchmarks = <MoneyAgeLevel, LevelBenchmark>{};

    final byLevel = groupBy(patterns, (p) => p.level);

    for (final entry in byLevel.entries) {
      if (entry.value.isEmpty) continue;

      // 计算平均储蓄率（基于区间估算）
      double totalSavingsRate = 0;
      for (final p in entry.value) {
        totalSavingsRate += _estimateSavingsRateFromRange(p.savingsRateRange);
      }
      final avgSavingsRate = totalSavingsRate / entry.value.length;

      // 估算平均日消费
      double totalExpense = 0;
      for (final p in entry.value) {
        totalExpense += _estimateExpenseFromPattern(p.consumptionPattern);
      }
      final avgExpense = totalExpense / entry.value.length;

      // 估算达到下一等级的天数
      final nextLevel = _getNextLevel(entry.key);
      final avgDaysToNext = nextLevel != null
          ? ((nextLevel.minDays - entry.key.minDays) / max(0.1, avgSavingsRate))
              .round()
          : 0;

      benchmarks[entry.key] = LevelBenchmark(
        level: entry.key,
        avgSavingsRate: avgSavingsRate,
        avgDailyExpense: avgExpense,
        avgDaysToNextLevel: avgDaysToNext.clamp(0, 365),
      );
    }

    // 添加默认基准
    _addDefaultBenchmarks(benchmarks);

    return benchmarks;
  }

  double _estimateSavingsRateFromRange(String range) {
    switch (range) {
      case 'negative':
        return -0.1;
      case '0-10%':
        return 0.05;
      case '10-20%':
        return 0.15;
      case '20-30%':
        return 0.25;
      case '30-50%':
        return 0.40;
      case '50%+':
        return 0.55;
      default:
        return 0.15;
    }
  }

  double _estimateExpenseFromPattern(String pattern) {
    switch (pattern) {
      case 'low':
        return 50;
      case 'medium':
        return 300;
      case 'high':
        return 750;
      case 'very_high':
        return 1500;
      default:
        return 300;
    }
  }

  MoneyAgeLevel? _getNextLevel(MoneyAgeLevel current) {
    final index = MoneyAgeLevel.values.indexOf(current);
    if (index < MoneyAgeLevel.values.length - 1) {
      return MoneyAgeLevel.values[index + 1];
    }
    return null;
  }

  void _addDefaultBenchmarks(Map<MoneyAgeLevel, LevelBenchmark> benchmarks) {
    final defaults = {
      MoneyAgeLevel.danger: const LevelBenchmark(
        level: MoneyAgeLevel.danger,
        avgSavingsRate: 0.05,
        avgDailyExpense: 500,
        avgDaysToNextLevel: 30,
      ),
      MoneyAgeLevel.warning: const LevelBenchmark(
        level: MoneyAgeLevel.warning,
        avgSavingsRate: 0.10,
        avgDailyExpense: 400,
        avgDaysToNextLevel: 45,
      ),
      MoneyAgeLevel.normal: const LevelBenchmark(
        level: MoneyAgeLevel.normal,
        avgSavingsRate: 0.15,
        avgDailyExpense: 350,
        avgDaysToNextLevel: 60,
      ),
      MoneyAgeLevel.good: const LevelBenchmark(
        level: MoneyAgeLevel.good,
        avgSavingsRate: 0.20,
        avgDailyExpense: 300,
        avgDaysToNextLevel: 90,
      ),
      MoneyAgeLevel.excellent: const LevelBenchmark(
        level: MoneyAgeLevel.excellent,
        avgSavingsRate: 0.25,
        avgDailyExpense: 250,
        avgDaysToNextLevel: 120,
      ),
      MoneyAgeLevel.ideal: const LevelBenchmark(
        level: MoneyAgeLevel.ideal,
        avgSavingsRate: 0.30,
        avgDailyExpense: 200,
        avgDaysToNextLevel: 0,
      ),
    };

    for (final entry in defaults.entries) {
      benchmarks.putIfAbsent(entry.key, () => entry.value);
    }
  }
}

// ==================== 钱龄学习整合服务 ====================

/// 钱龄学习整合服务（整合本地学习与协同学习）
class MoneyAgeLearningIntegrationService {
  final MoneyAgeLearningAdapter _localAdapter;
  final MoneyAgeCollaborativeLearningService _collaborativeService;

  MoneyAgeLearningIntegrationService({
    MoneyAgeLearningAdapter? localAdapter,
    MoneyAgeCollaborativeLearningService? collaborativeService,
  })  : _localAdapter = localAdapter ?? MoneyAgeLearningAdapter(),
        _collaborativeService =
            collaborativeService ?? MoneyAgeCollaborativeLearningService();

  /// 记录钱龄样本
  Future<void> recordSample(MoneyAgeLearningData sample) async {
    // 本地学习
    await _localAdapter.collectSample(sample);

    // 上报协同学习
    await _collaborativeService.reportMoneyAgePattern(sample);
  }

  /// 获取钱龄预测
  Future<MoneyAgePredictionResult> predict(MoneyAgeLearningData current) async {
    // 本地预测
    final localPrediction = await _localAdapter.predict(current);

    // 获取同等级对比
    final comparison = await _collaborativeService.compareToPeers(
      current.level,
      current.savingsRate,
    );

    // 获取改善建议
    final localAdvice = await _localAdapter.getImproveAdvice(current);
    final globalBestPractices = await _collaborativeService.getBestPractices();

    return MoneyAgePredictionResult(
      localPrediction: localPrediction.matched
          ? localPrediction.result as MoneyAgeRuleResult?
          : null,
      peerComparison: comparison,
      localAdvice: localAdvice,
      globalBestPractices: globalBestPractices,
      confidence: localPrediction.confidence,
    );
  }

  /// 触发训练
  Future<TrainingResult> triggerTraining() async {
    return _localAdapter.train();
  }

  /// 获取统计信息
  Future<LearningMetrics> getMetrics() async {
    return _localAdapter.getMetrics();
  }

  /// 获取学习状态
  Future<LearningStatus> getStatus() async {
    return _localAdapter.getStatus();
  }

  /// 获取全局洞察
  Future<GlobalMoneyAgeInsights> getGlobalInsights() async {
    return _collaborativeService.getGlobalInsights();
  }
}

/// 钱龄预测结果
class MoneyAgePredictionResult {
  final MoneyAgeRuleResult? localPrediction;
  final LevelComparison peerComparison;
  final List<MoneyAgeImproveAdvice> localAdvice;
  final List<GlobalBestPractice> globalBestPractices;
  final double confidence;

  const MoneyAgePredictionResult({
    this.localPrediction,
    required this.peerComparison,
    required this.localAdvice,
    required this.globalBestPractices,
    required this.confidence,
  });

  /// 获取所有建议（本地+全局）
  List<String> getAllSuggestions() {
    final suggestions = <String>[];

    // 添加本地建议
    for (final advice in localAdvice) {
      suggestions.add(advice.description);
    }

    // 添加同伴对比建议
    suggestions.add(peerComparison.recommendation);

    // 添加全局最佳实践
    for (final practice in globalBestPractices.take(2)) {
      suggestions.add('${practice.title}: ${practice.description}');
    }

    return suggestions;
  }
}
