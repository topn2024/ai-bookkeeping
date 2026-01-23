import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/common_types.dart' show CityTier;

/// 用户画像数据模型
class UserProfile {
  final String userId;
  final BasicAttributes basicAttributes;
  final SpendingBehavior spendingBehavior;
  final FinancialFeatures financialFeatures;
  final PersonalityTraits personalityTraits;
  final LifeStage lifeStage;
  final ConversationPreferences conversationPreferences;
  final DateTime lastUpdated;
  final int dataConfidence; // 0-100, 数据置信度

  const UserProfile({
    required this.userId,
    required this.basicAttributes,
    required this.spendingBehavior,
    required this.financialFeatures,
    required this.personalityTraits,
    required this.lifeStage,
    this.conversationPreferences = const ConversationPreferences(),
    required this.lastUpdated,
    required this.dataConfidence,
  });

  /// 获取画像摘要（用于LLM prompt）
  String toPromptSummary() {
    return '''
[用户画像]
- 消费性格: ${personalityTraits.spendingPersonality.label}
- 财务状态: 储蓄率${financialFeatures.savingsRate}%, 钱龄${financialFeatures.moneyAgeHealth}
- 沟通偏好: ${personalityTraits.communicationStyle.label}
- 敏感话题: ${personalityTraits.sensitiveTacics.join('、')}
- 近期关注: ${lifeStage.currentFocus ?? '无特别关注'}
- 对话风格: ${conversationPreferences.dialogStyle.label}
- 主动对话: ${conversationPreferences.likesProactiveChat ? '喜欢' : '不喜欢'}
''';
  }

  /// 是否数据充足
  bool get hasEnoughData => dataConfidence >= 60;

  /// 是否需要更新
  bool get needsUpdate =>
      DateTime.now().difference(lastUpdated) > const Duration(days: 7);
}

/// 基础属性
class BasicAttributes {
  final int usageDays;           // 使用天数
  final double dailyRecordRate;  // 日均记账频率
  final ActiveTimeSlot peakActiveTime; // 活跃时段
  final String? deviceInfo;
  final int totalTransactions;   // 总交易数
  final DateTime? firstRecordDate; // 首次记账日期

  const BasicAttributes({
    required this.usageDays,
    required this.dailyRecordRate,
    required this.peakActiveTime,
    this.deviceInfo,
    this.totalTransactions = 0,
    this.firstRecordDate,
  });
}

/// 活跃时段
enum ActiveTimeSlot {
  morning,     // 早上 6-9
  midMorning,  // 上午 9-12
  noon,        // 中午 12-14
  afternoon,   // 下午 14-18
  evening,     // 晚上 18-22
  lateNight,   // 深夜 22-6
}

extension ActiveTimeSlotExtension on ActiveTimeSlot {
  String get displayName {
    switch (this) {
      case ActiveTimeSlot.morning:
        return '早上';
      case ActiveTimeSlot.midMorning:
        return '上午';
      case ActiveTimeSlot.noon:
        return '中午';
      case ActiveTimeSlot.afternoon:
        return '下午';
      case ActiveTimeSlot.evening:
        return '晚上';
      case ActiveTimeSlot.lateNight:
        return '深夜';
    }
  }
}

/// 消费行为特征
class SpendingBehavior {
  final double monthlyAverage;      // 月均支出
  final List<String> topCategories; // TOP消费类目
  final SpendingStyle style;        // 消费风格
  final double latteFactorRatio;    // 拿铁因子占比
  final double impulseRatio;        // 冲动消费占比
  final PaymentPreference paymentPreference; // 支付偏好
  final List<String> frequentMerchants; // 常去商家

  const SpendingBehavior({
    required this.monthlyAverage,
    required this.topCategories,
    required this.style,
    required this.latteFactorRatio,
    required this.impulseRatio,
    required this.paymentPreference,
    this.frequentMerchants = const [],
  });
}

/// 消费风格
enum SpendingStyle {
  frugal,     // 节俭型
  balanced,   // 平衡型
  generous,   // 慷慨型
  impulsive,  // 冲动型
}

extension SpendingStyleExtension on SpendingStyle {
  String get label {
    switch (this) {
      case SpendingStyle.frugal:
        return '节俭型';
      case SpendingStyle.balanced:
        return '平衡型';
      case SpendingStyle.generous:
        return '慷慨型';
      case SpendingStyle.impulsive:
        return '冲动型';
    }
  }
}

/// 支付偏好
enum PaymentPreference { online, offline, mixed }

/// 财务特征
class FinancialFeatures {
  final IncomeStability incomeStability;
  final double savingsRate;         // 储蓄率 %
  final String moneyAgeHealth;      // 钱龄健康度
  final double budgetComplianceRate;// 预算达成率
  final double emergencyFundMonths; // 应急金月数
  final DebtLevel debtLevel;

  const FinancialFeatures({
    required this.incomeStability,
    required this.savingsRate,
    required this.moneyAgeHealth,
    required this.budgetComplianceRate,
    required this.emergencyFundMonths,
    required this.debtLevel,
  });
}

/// 收入稳定性
enum IncomeStability { stable, variable, irregular }

extension IncomeStabilityExtension on IncomeStability {
  String get label {
    switch (this) {
      case IncomeStability.stable:
        return '稳定';
      case IncomeStability.variable:
        return '波动';
      case IncomeStability.irregular:
        return '不规律';
    }
  }
}

/// 负债水平
enum DebtLevel { none, low, moderate, high }

extension DebtLevelExtension on DebtLevel {
  String get label {
    switch (this) {
      case DebtLevel.none:
        return '无负债';
      case DebtLevel.low:
        return '低负债';
      case DebtLevel.moderate:
        return '中等负债';
      case DebtLevel.high:
        return '高负债';
    }
  }
}

/// 性格特征（推断）
class PersonalityTraits {
  final SpendingPersonality spendingPersonality;
  final DecisionStyle decisionStyle;
  final EmotionalTendency emotionalTendency;
  final CommunicationStyle communicationStyle;
  final double humorAcceptance;     // 幽默接受度 0-1
  final List<String> sensitiveTacics; // 敏感话题

  const PersonalityTraits({
    required this.spendingPersonality,
    required this.decisionStyle,
    required this.emotionalTendency,
    required this.communicationStyle,
    required this.humorAcceptance,
    required this.sensitiveTacics,
  });
}

/// 消费性格
enum SpendingPersonality {
  frugalRational,     // 节俭理性型
  enjoymentOriented,  // 享乐消费型
  anxiousWorrier,     // 焦虑担忧型
  goalDriven,         // 目标导向型
  casualBuddhist,     // 随性佛系型
}

extension SpendingPersonalityExtension on SpendingPersonality {
  String get label {
    switch (this) {
      case SpendingPersonality.frugalRational:
        return '节俭理性型';
      case SpendingPersonality.enjoymentOriented:
        return '享乐消费型';
      case SpendingPersonality.anxiousWorrier:
        return '焦虑担忧型';
      case SpendingPersonality.goalDriven:
        return '目标导向型';
      case SpendingPersonality.casualBuddhist:
        return '随性佛系型';
    }
  }
}

/// 决策风格
enum DecisionStyle { impulsive, cautious, analytical }

/// 情绪倾向
enum EmotionalTendency { optimistic, neutral, anxious }

/// 沟通风格
enum CommunicationStyle {
  concise,   // 简洁直接
  detailed,  // 详细解释
  emotional, // 情感共鸣
}

extension CommunicationStyleExtension on CommunicationStyle {
  String get label {
    switch (this) {
      case CommunicationStyle.concise:
        return '简洁直接';
      case CommunicationStyle.detailed:
        return '详细解释';
      case CommunicationStyle.emotional:
        return '情感共鸣';
    }
  }
}

/// 生活阶段
class LifeStage {
  final LifePhase phase;
  final FamilyStatus familyStatus;
  final CareerType careerType;
  final CityTier cityTier;
  final String? currentFocus; // 近期关注目标

  const LifeStage({
    required this.phase,
    required this.familyStatus,
    required this.careerType,
    required this.cityTier,
    this.currentFocus,
  });
}

/// 人生阶段
enum LifePhase { student, youngProfessional, midCareer, senior }

/// 家庭状态
enum FamilyStatus { single, married, withChildren, emptyNest }

/// 职业类型
enum CareerType { employed, freelance, entrepreneur, retired }

/// 对话偏好
class ConversationPreferences {
  /// 是否喜欢主动发起对话
  final bool likesProactiveChat;

  /// 沉默容忍度（秒），超过这个时间智能体可以主动说话
  final int silenceToleranceSeconds;

  /// 感兴趣的话题
  final List<String> favoriteTopics;

  /// 是否喜欢快速确认（简短回复）
  final bool prefersQuickConfirm;

  /// 对话风格
  final VoiceDialogStyle dialogStyle;

  /// 打断敏感度（0-1，越高越容易被打断）
  final double interruptSensitivity;

  const ConversationPreferences({
    this.likesProactiveChat = true,
    this.silenceToleranceSeconds = 5,
    this.favoriteTopics = const [],
    this.prefersQuickConfirm = true,
    this.dialogStyle = VoiceDialogStyle.neutral,
    this.interruptSensitivity = 0.5,
  });
}

/// 语音对话风格
enum VoiceDialogStyle {
  professional,  // 专业简洁
  playful,       // 活泼有趣
  supportive,    // 温暖支持
  dataFocused,   // 数据导向
  casual,        // 随意轻松
  neutral,       // 中性平衡
}

extension VoiceDialogStyleExtension on VoiceDialogStyle {
  String get label {
    switch (this) {
      case VoiceDialogStyle.professional:
        return '专业简洁';
      case VoiceDialogStyle.playful:
        return '活泼有趣';
      case VoiceDialogStyle.supportive:
        return '温暖支持';
      case VoiceDialogStyle.dataFocused:
        return '数据导向';
      case VoiceDialogStyle.casual:
        return '随意轻松';
      case VoiceDialogStyle.neutral:
        return '中性平衡';
    }
  }
}

// ==================== 用户画像分析引擎 ====================

/// 用户画像分析引擎
class UserProfileAnalyzer {
  final TransactionDataSource _transactions;
  final BudgetDataSource _budgets;
  final UserActivityDataSource _activityLogger;

  UserProfileAnalyzer({
    required TransactionDataSource transactions,
    required BudgetDataSource budgets,
    required UserActivityDataSource activityLogger,
  })  : _transactions = transactions,
        _budgets = budgets,
        _activityLogger = activityLogger;

  /// 构建完整用户画像
  Future<UserProfile> buildProfile(String userId) async {
    final transactions = await _transactions.getAll(userId);
    final budgets = await _budgets.getAll(userId);
    final activities = await _activityLogger.getActivities(userId);

    // 并行分析各维度
    final results = await Future.wait([
      _analyzeBasicAttributes(activities, transactions),
      _analyzeSpendingBehavior(transactions),
      _analyzeFinancialFeatures(transactions, budgets),
      _inferPersonalityTraits(transactions, activities),
      _inferLifeStage(transactions),
    ]);

    return UserProfile(
      userId: userId,
      basicAttributes: results[0] as BasicAttributes,
      spendingBehavior: results[1] as SpendingBehavior,
      financialFeatures: results[2] as FinancialFeatures,
      personalityTraits: results[3] as PersonalityTraits,
      lifeStage: results[4] as LifeStage,
      lastUpdated: DateTime.now(),
      dataConfidence: _calculateConfidence(transactions.length),
    );
  }

  /// 分析基础属性
  Future<BasicAttributes> _analyzeBasicAttributes(
    List<UserActivity> activities,
    List<TransactionData> transactions,
  ) async {
    final now = DateTime.now();
    DateTime? firstDate;

    for (final tx in transactions) {
      if (firstDate == null || tx.date.isBefore(firstDate)) {
        firstDate = tx.date;
      }
    }

    final usageDays = firstDate != null
        ? now.difference(firstDate).inDays
        : 0;

    final dailyRate = usageDays > 0
        ? transactions.length / usageDays
        : 0.0;

    // 分析活跃时段
    final hourCounts = List.filled(24, 0);
    for (final activity in activities) {
      hourCounts[activity.timestamp.hour]++;
    }

    int peakHour = 0;
    int maxCount = 0;
    for (int i = 0; i < 24; i++) {
      if (hourCounts[i] > maxCount) {
        maxCount = hourCounts[i];
        peakHour = i;
      }
    }

    return BasicAttributes(
      usageDays: usageDays,
      dailyRecordRate: dailyRate,
      peakActiveTime: _hourToTimeSlot(peakHour),
      totalTransactions: transactions.length,
      firstRecordDate: firstDate,
    );
  }

  /// 分析消费行为
  Future<SpendingBehavior> _analyzeSpendingBehavior(
    List<TransactionData> txs,
  ) async {
    final expenses = txs.where((t) => t.type == 'expense').toList();
    final monthlyAverage = _calculateMonthlyAverage(expenses);

    // 分析TOP类目
    final categoryStats = <String, double>{};
    for (final tx in expenses) {
      categoryStats[tx.category] =
          (categoryStats[tx.category] ?? 0) + tx.amount;
    }
    final sortedCategories = categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories
        .take(3)
        .map((e) => e.key)
        .toList();

    // 分析拿铁因子（小额高频消费）
    final smallExpenses = expenses.where((t) => t.amount < 50).length;
    final latteFactorRatio =
        expenses.isEmpty ? 0.0 : smallExpenses / expenses.length;

    // 分析冲动消费（晚上和周末的非必要消费）
    final impulseRatio = _calculateImpulseRatio(expenses);
    final style = _inferSpendingStyle(
      monthlyAverage,
      latteFactorRatio,
      impulseRatio,
    );

    // 常去商家
    final merchantCounts = <String, int>{};
    for (final tx in expenses) {
      if (tx.merchant != null && tx.merchant!.isNotEmpty) {
        merchantCounts[tx.merchant!] =
            (merchantCounts[tx.merchant!] ?? 0) + 1;
      }
    }
    final frequentMerchants = merchantCounts.entries
        .where((e) => e.value >= 3)
        .map((e) => e.key)
        .take(5)
        .toList();

    return SpendingBehavior(
      monthlyAverage: monthlyAverage,
      topCategories: topCategories,
      style: style,
      latteFactorRatio: latteFactorRatio,
      impulseRatio: impulseRatio,
      paymentPreference: PaymentPreference.mixed,
      frequentMerchants: frequentMerchants,
    );
  }

  /// 分析财务特征
  Future<FinancialFeatures> _analyzeFinancialFeatures(
    List<TransactionData> txs,
    List<BudgetData> budgets,
  ) async {
    final incomes = txs.where((t) => t.type == 'income').toList();
    final expenses = txs.where((t) => t.type == 'expense').toList();

    // 收入稳定性
    final incomeStability = _analyzeIncomeStability(incomes);

    // 储蓄率
    final totalIncome = incomes.fold(0.0, (sum, tx) => sum + tx.amount);
    final totalExpense = expenses.fold(0.0, (sum, tx) => sum + tx.amount);
    final savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome * 100).clamp(0.0, 100.0)
        : 0.0;

    // 钱龄健康度（简化）
    final moneyAgeHealth = savingsRate > 30
        ? '优秀'
        : savingsRate > 10
            ? '良好'
            : '需改善';

    // 预算达成率
    double budgetComplianceRate = 0;
    if (budgets.isNotEmpty) {
      int compliantBudgets = 0;
      for (final budget in budgets) {
        final spent = expenses
            .where((tx) =>
                tx.category == budget.category &&
                tx.date.month == budget.month &&
                tx.date.year == budget.year)
            .fold(0.0, (sum, tx) => sum + tx.amount);
        if (spent <= budget.amount) {
          compliantBudgets++;
        }
      }
      budgetComplianceRate = compliantBudgets / budgets.length * 100;
    }

    return FinancialFeatures(
      incomeStability: incomeStability,
      savingsRate: savingsRate,
      moneyAgeHealth: moneyAgeHealth,
      budgetComplianceRate: budgetComplianceRate,
      emergencyFundMonths: savingsRate > 20 ? 3 : 1,
      debtLevel: DebtLevel.low,
    );
  }

  /// 推断性格特征
  Future<PersonalityTraits> _inferPersonalityTraits(
    List<TransactionData> txs,
    List<UserActivity> activities,
  ) async {
    final behavior = await _analyzeSpendingBehavior(txs);

    // 推断消费性格
    SpendingPersonality personality;
    if (behavior.latteFactorRatio < 0.1 && behavior.impulseRatio < 0.1) {
      personality = SpendingPersonality.frugalRational;
    } else if (behavior.impulseRatio > 0.3) {
      personality = SpendingPersonality.enjoymentOriented;
    } else if (behavior.monthlyAverage > 10000 && behavior.impulseRatio < 0.15) {
      personality = SpendingPersonality.goalDriven;
    } else {
      personality = SpendingPersonality.casualBuddhist;
    }

    // 推断沟通风格（基于使用习惯）
    final avgSessionTime = _calculateAvgSessionTime(activities);
    final communicationStyle = avgSessionTime < 60
        ? CommunicationStyle.concise
        : CommunicationStyle.detailed;

    // 敏感话题
    final sensitiveTacics = <String>[];
    if (behavior.monthlyAverage > 10000) {
      sensitiveTacics.add('大额支出');
    }
    if (behavior.impulseRatio > 0.3) {
      sensitiveTacics.add('冲动消费');
    }

    return PersonalityTraits(
      spendingPersonality: personality,
      decisionStyle: behavior.impulseRatio > 0.2
          ? DecisionStyle.impulsive
          : DecisionStyle.cautious,
      emotionalTendency: EmotionalTendency.neutral,
      communicationStyle: communicationStyle,
      humorAcceptance: 0.7,
      sensitiveTacics: sensitiveTacics,
    );
  }

  /// 推断生活阶段
  Future<LifeStage> _inferLifeStage(List<TransactionData> txs) async {
    // 基于消费类目推断
    final categoryAmounts = <String, double>{};
    for (final tx in txs.where((t) => t.type == 'expense')) {
      categoryAmounts[tx.category] =
          (categoryAmounts[tx.category] ?? 0) + tx.amount;
    }

    // 推断人生阶段
    LifePhase phase = LifePhase.youngProfessional;
    if (categoryAmounts['教育'] != null &&
        categoryAmounts['教育']! > categoryAmounts.values.reduce((a, b) => a + b) * 0.2) {
      phase = LifePhase.student;
    }

    // 推断家庭状态
    FamilyStatus familyStatus = FamilyStatus.single;
    if (categoryAmounts['母婴'] != null || categoryAmounts['儿童'] != null) {
      familyStatus = FamilyStatus.withChildren;
    }

    return LifeStage(
      phase: phase,
      familyStatus: familyStatus,
      careerType: CareerType.employed,
      cityTier: CityTier.tier2,
    );
  }

  // ==================== 辅助方法 ====================

  ActiveTimeSlot _hourToTimeSlot(int hour) {
    if (hour >= 6 && hour < 9) return ActiveTimeSlot.morning;
    if (hour >= 9 && hour < 12) return ActiveTimeSlot.midMorning;
    if (hour >= 12 && hour < 14) return ActiveTimeSlot.noon;
    if (hour >= 14 && hour < 18) return ActiveTimeSlot.afternoon;
    if (hour >= 18 && hour < 22) return ActiveTimeSlot.evening;
    return ActiveTimeSlot.lateNight;
  }

  double _calculateMonthlyAverage(List<TransactionData> expenses) {
    if (expenses.isEmpty) return 0;

    final monthlyTotals = <String, double>{};
    for (final tx in expenses) {
      final key = '${tx.date.year}-${tx.date.month}';
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + tx.amount;
    }

    if (monthlyTotals.isEmpty) return 0;
    return monthlyTotals.values.reduce((a, b) => a + b) / monthlyTotals.length;
  }

  double _calculateImpulseRatio(List<TransactionData> expenses) {
    if (expenses.isEmpty) return 0;

    final impulseCategories = ['娱乐', '购物', '美容', '游戏'];
    int impulseCount = 0;

    for (final tx in expenses) {
      final isWeekend = tx.date.weekday >= 6;
      final isNight = tx.date.hour >= 20 || tx.date.hour < 6;
      final isImpulseCategory = impulseCategories.contains(tx.category);

      if ((isWeekend || isNight) && isImpulseCategory) {
        impulseCount++;
      }
    }

    return impulseCount / expenses.length;
  }

  SpendingStyle _inferSpendingStyle(
    double monthlyAverage,
    double latteFactorRatio,
    double impulseRatio,
  ) {
    if (latteFactorRatio < 0.1 && impulseRatio < 0.1) {
      return SpendingStyle.frugal;
    }
    if (impulseRatio > 0.3) {
      return SpendingStyle.impulsive;
    }
    if (monthlyAverage > 15000) {
      return SpendingStyle.generous;
    }
    return SpendingStyle.balanced;
  }

  IncomeStability _analyzeIncomeStability(List<TransactionData> incomes) {
    if (incomes.length < 3) return IncomeStability.irregular;

    // 按月统计收入
    final monthlyIncomes = <double>[];
    final monthlyMap = <String, double>{};

    for (final tx in incomes) {
      final key = '${tx.date.year}-${tx.date.month}';
      monthlyMap[key] = (monthlyMap[key] ?? 0) + tx.amount;
    }

    monthlyIncomes.addAll(monthlyMap.values);

    if (monthlyIncomes.length < 2) return IncomeStability.irregular;

    // 计算变异系数
    final mean = monthlyIncomes.reduce((a, b) => a + b) / monthlyIncomes.length;
    final variance = monthlyIncomes
            .map((x) => (x - mean) * (x - mean))
            .reduce((a, b) => a + b) /
        monthlyIncomes.length;
    final stdDev = variance > 0 ? variance : 0;
    final cv = mean > 0 ? stdDev / mean : 0;

    if (cv < 0.15) return IncomeStability.stable;
    if (cv < 0.35) return IncomeStability.variable;
    return IncomeStability.irregular;
  }

  double _calculateAvgSessionTime(List<UserActivity> activities) {
    if (activities.isEmpty) return 0;
    final totalDuration = activities.fold<int>(
      0,
      (sum, a) => sum + (a.durationSeconds ?? 0),
    );
    return totalDuration / activities.length;
  }

  int _calculateConfidence(int transactionCount) {
    if (transactionCount < 30) return 30;
    if (transactionCount < 100) return 60;
    if (transactionCount < 300) return 80;
    return 95;
  }
}

// ==================== 用户画像服务 ====================

/// 用户画像服务接口
class UserProfileService {
  final UserProfileAnalyzer _analyzer;
  final UserProfileRepository _repository;
  final Map<String, UserProfile> _cache = {};

  static const _cacheDuration = Duration(hours: 1);

  UserProfileService({
    required UserProfileAnalyzer analyzer,
    required UserProfileRepository repository,
  })  : _analyzer = analyzer,
        _repository = repository;

  /// 获取用户画像
  Future<UserProfile?> getProfile(String userId) async {
    // 检查缓存
    if (_cache.containsKey(userId)) {
      final cached = _cache[userId]!;
      if (DateTime.now().difference(cached.lastUpdated) < _cacheDuration) {
        return cached;
      }
    }

    // 从存储加载
    var profile = await _repository.get(userId);

    // 检查是否需要更新
    if (profile == null || profile.needsUpdate) {
      profile = await rebuildProfile(userId);
    }

    if (profile != null) {
      _cache[userId] = profile;
    }

    return profile;
  }

  /// 获取画像摘要
  Future<String> getProfileSummary(String userId) async {
    final profile = await getProfile(userId);
    return profile?.toPromptSummary() ?? '暂无用户画像数据';
  }

  /// 重建用户画像
  Future<UserProfile?> rebuildProfile(String userId) async {
    try {
      final profile = await _analyzer.buildProfile(userId);
      await _repository.save(profile);
      _cache[userId] = profile;
      return profile;
    } catch (e) {
      debugPrint('Failed to build user profile: $e');
      return null;
    }
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
  }
}

// ==================== 数据源接口 ====================

/// 交易数据
class TransactionData {
  final String id;
  final String type; // 'income', 'expense', 'transfer'
  final double amount;
  final String category;
  final String? merchant;
  final DateTime date;

  const TransactionData({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.merchant,
    required this.date,
  });
}

/// 预算数据
class BudgetData {
  final String id;
  final String category;
  final double amount;
  final int month;
  final int year;

  const BudgetData({
    required this.id,
    required this.category,
    required this.amount,
    required this.month,
    required this.year,
  });
}

/// 用户活动
class UserActivity {
  final String type;
  final DateTime timestamp;
  final int? durationSeconds;

  const UserActivity({
    required this.type,
    required this.timestamp,
    this.durationSeconds,
  });
}

/// 数据源接口
abstract class TransactionDataSource {
  Future<List<TransactionData>> getAll(String userId);
}

abstract class BudgetDataSource {
  Future<List<BudgetData>> getAll(String userId);
}

abstract class UserActivityDataSource {
  Future<List<UserActivity>> getActivities(String userId);
}

abstract class UserProfileRepository {
  Future<UserProfile?> get(String userId);
  Future<void> save(UserProfile profile);
}
