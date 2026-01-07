import 'dart:async';

import 'package:flutter/foundation.dart';

import 'user_profile_service.dart';

/// 用户画像实时应用服务
///
/// ��能：
/// 1. 根据用户画像驱动UI个性化
/// 2. 智能推荐（分类、商家、预算）
/// 3. 默认值智能填充
/// 4. 伙伴化文案定制
/// 5. 功能优先级排序
class UserProfileApplicationService {
  final UserProfileProvider _profileProvider;
  final ProfileApplicationCache _cache;

  final _profileStreamController = StreamController<UserProfile>.broadcast();
  UserProfile? _currentProfile;

  UserProfileApplicationService({
    required UserProfileProvider profileProvider,
    ProfileApplicationCache? cache,
  })  : _profileProvider = profileProvider,
        _cache = cache ?? InMemoryProfileApplicationCache();

  /// 用户画像变更流
  Stream<UserProfile> get profileStream => _profileStreamController.stream;

  /// 当前用户画像
  UserProfile? get currentProfile => _currentProfile;

  /// 初始化服务
  Future<void> initialize(String userId) async {
    _currentProfile = await _profileProvider.getProfile(userId);
    if (_currentProfile != null) {
      _profileStreamController.add(_currentProfile!);
    }

    // 监听画像更新
    _profileProvider.onProfileUpdated.listen((profile) {
      _currentProfile = profile;
      _profileStreamController.add(profile);
      _invalidateCache();
    });
  }

  // ==================== UI个性化 ====================

  /// 获取UI个性化配置
  Future<UIPersonalization> getUIPersonalization() async {
    final cached = await _cache.get<UIPersonalization>('ui_personalization');
    if (cached != null) return cached;

    final profile = _currentProfile;
    if (profile == null) return UIPersonalization.defaultConfig();

    final config = _buildUIPersonalization(profile);
    await _cache.set('ui_personalization', config);
    return config;
  }

  UIPersonalization _buildUIPersonalization(UserProfile profile) {
    // 根据沟通风格决定信息密度
    final infoDensity = switch (profile.personalityTraits.communicationStyle) {
      CommunicationStyle.concise => InfoDensity.compact,
      CommunicationStyle.detailed => InfoDensity.detailed,
      CommunicationStyle.emotional => InfoDensity.balanced,
    };

    // 根据消费性格决定图表偏好
    final chartPreference = switch (profile.personalityTraits.spendingPersonality) {
      SpendingPersonality.goalDriven => ChartPreference.progress,
      SpendingPersonality.anxiousWorrier => ChartPreference.simple,
      SpendingPersonality.frugalRational => ChartPreference.detailed,
      _ => ChartPreference.balanced,
    };

    // 根据活跃时段决定提醒时间
    final reminderTime = _getOptimalReminderTime(profile.basicAttributes.peakActiveTime);

    // 根据财务状态决定是否显示敏感信息
    final showSensitiveInfo = profile.financialFeatures.debtLevel != DebtLevel.high;

    return UIPersonalization(
      infoDensity: infoDensity,
      chartPreference: chartPreference,
      defaultReminderTime: reminderTime,
      showSensitiveInfo: showSensitiveInfo,
      preferredColorScheme: _inferColorScheme(profile),
      animationSpeed: _inferAnimationSpeed(profile),
      homeWidgetOrder: _getHomeWidgetOrder(profile),
    );
  }

  TimeOfDay _getOptimalReminderTime(ActiveTimeSlot slot) {
    return switch (slot) {
      ActiveTimeSlot.morning => const TimeOfDay(hour: 8, minute: 0),
      ActiveTimeSlot.midMorning => const TimeOfDay(hour: 10, minute: 0),
      ActiveTimeSlot.noon => const TimeOfDay(hour: 12, minute: 30),
      ActiveTimeSlot.afternoon => const TimeOfDay(hour: 17, minute: 0),
      ActiveTimeSlot.evening => const TimeOfDay(hour: 20, minute: 0),
      ActiveTimeSlot.lateNight => const TimeOfDay(hour: 22, minute: 0),
    };
  }

  ColorSchemePreference _inferColorScheme(UserProfile profile) {
    if (profile.personalityTraits.emotionalTendency == EmotionalTendency.anxious) {
      return ColorSchemePreference.calm; // 舒缓色调
    }
    return ColorSchemePreference.energetic;
  }

  AnimationSpeed _inferAnimationSpeed(UserProfile profile) {
    if (profile.personalityTraits.communicationStyle == CommunicationStyle.concise) {
      return AnimationSpeed.fast;
    }
    return AnimationSpeed.normal;
  }

  List<String> _getHomeWidgetOrder(UserProfile profile) {
    final widgets = <String>[];

    // 根据用户画像决定首页组件顺序
    if (profile.financialFeatures.budgetComplianceRate < 0.7) {
      widgets.add('budget_overview'); // 预算执行差的用户优先看预算
    }

    if (profile.spendingBehavior.impulseRatio > 0.3) {
      widgets.add('impulse_warning'); // 冲动消费高的用户优先看提醒
    }

    widgets.addAll([
      'quick_record',
      'recent_transactions',
      'money_age_summary',
      'spending_trend',
    ]);

    return widgets;
  }

  // ==================== 智能推荐 ====================

  /// 获取推荐分类（基于用户画像）
  Future<List<CategoryRecommendation>> getRecommendedCategories({
    String? contextHint,
    DateTime? date,
    double? amount,
  }) async {
    final profile = _currentProfile;
    if (profile == null) return [];

    final recommendations = <CategoryRecommendation>[];
    final now = date ?? DateTime.now();

    // 1. 基于时间段推荐
    final timeSlot = _getCurrentTimeSlot(now);
    final timeBasedCategories = _getTimeBasedCategories(timeSlot);
    for (final category in timeBasedCategories) {
      recommendations.add(CategoryRecommendation(
        category: category,
        reason: '${timeSlot.displayName}常见消费',
        confidence: 0.6,
        source: RecommendationSource.timePattern,
      ));
    }

    // 2. 基于常用分类推荐
    for (var i = 0; i < profile.spendingBehavior.topCategories.length && i < 3; i++) {
      final category = profile.spendingBehavior.topCategories[i];
      if (!recommendations.any((r) => r.category == category)) {
        recommendations.add(CategoryRecommendation(
          category: category,
          reason: '您的常用分类',
          confidence: 0.8 - i * 0.1,
          source: RecommendationSource.userHistory,
        ));
      }
    }

    // 3. 基于金额推荐
    if (amount != null) {
      final amountBasedCategory = _getAmountBasedCategory(amount, profile);
      if (amountBasedCategory != null &&
          !recommendations.any((r) => r.category == amountBasedCategory)) {
        recommendations.add(CategoryRecommendation(
          category: amountBasedCategory,
          reason: '该金额常见分类',
          confidence: 0.5,
          source: RecommendationSource.amountPattern,
        ));
      }
    }

    // 按置信度排序
    recommendations.sort((a, b) => b.confidence.compareTo(a.confidence));
    return recommendations.take(5).toList();
  }

  ActiveTimeSlot _getCurrentTimeSlot(DateTime time) {
    final hour = time.hour;
    if (hour >= 6 && hour < 9) return ActiveTimeSlot.morning;
    if (hour >= 9 && hour < 12) return ActiveTimeSlot.midMorning;
    if (hour >= 12 && hour < 14) return ActiveTimeSlot.noon;
    if (hour >= 14 && hour < 18) return ActiveTimeSlot.afternoon;
    if (hour >= 18 && hour < 22) return ActiveTimeSlot.evening;
    return ActiveTimeSlot.lateNight;
  }

  List<String> _getTimeBasedCategories(ActiveTimeSlot slot) {
    return switch (slot) {
      ActiveTimeSlot.morning => ['餐饮', '交通'],
      ActiveTimeSlot.midMorning => ['餐饮', '购物', '办公'],
      ActiveTimeSlot.noon => ['餐饮'],
      ActiveTimeSlot.afternoon => ['餐饮', '购物', '娱乐'],
      ActiveTimeSlot.evening => ['餐饮', '娱乐', '购物'],
      ActiveTimeSlot.lateNight => ['娱乐', '餐饮'],
    };
  }

  String? _getAmountBasedCategory(double amount, UserProfile profile) {
    // 基于金额范围推断分类
    if (amount < 30) return '餐饮'; // 小额通常是餐饮
    if (amount >= 30 && amount < 100) return '购物';
    if (amount >= 100 && amount < 500) return '购物';
    return null; // 大额��确定
  }

  /// 获取推荐商家
  Future<List<MerchantRecommendation>> getRecommendedMerchants({
    String? category,
    double? amount,
  }) async {
    final profile = _currentProfile;
    if (profile == null) return [];

    final recommendations = <MerchantRecommendation>[];

    for (var i = 0; i < profile.spendingBehavior.frequentMerchants.length && i < 5; i++) {
      final merchant = profile.spendingBehavior.frequentMerchants[i];
      recommendations.add(MerchantRecommendation(
        merchant: merchant,
        reason: '您常去的商家',
        confidence: 0.9 - i * 0.1,
      ));
    }

    return recommendations;
  }

  /// 获取推荐预算金额
  Future<BudgetRecommendation> getRecommendedBudget({
    required String category,
  }) async {
    final profile = _currentProfile;
    if (profile == null) {
      return BudgetRecommendation(
        category: category,
        recommendedAmount: 1000,
        reason: '默认预算',
        confidence: 0.3,
      );
    }

    // 基于月均支出和分类占比计算
    final monthlyAvg = profile.spendingBehavior.monthlyAverage;
    final categoryIndex = profile.spendingBehavior.topCategories.indexOf(category);

    double ratio;
    if (categoryIndex == 0) {
      ratio = 0.35; // 第一大分类
    } else if (categoryIndex == 1) {
      ratio = 0.25;
    } else if (categoryIndex == 2) {
      ratio = 0.15;
    } else {
      ratio = 0.1;
    }

    final recommended = monthlyAvg * ratio;

    return BudgetRecommendation(
      category: category,
      recommendedAmount: recommended,
      reason: '基于您的消费习惯',
      confidence: profile.hasEnoughData ? 0.8 : 0.5,
      minSuggested: recommended * 0.8,
      maxSuggested: recommended * 1.2,
    );
  }

  // ==================== 默认值填充 ====================

  /// 获取交易默认值
  Future<TransactionDefaults> getTransactionDefaults({
    String? inputText,
    DateTime? date,
  }) async {
    final profile = _currentProfile;
    final now = date ?? DateTime.now();

    // 默认分类
    String? defaultCategory;
    final recommendations = await getRecommendedCategories(date: now);
    if (recommendations.isNotEmpty) {
      defaultCategory = recommendations.first.category;
    }

    // 默认金额（基于用户画像）
    double? suggestedAmount;
    if (profile != null) {
      final avgDaily = profile.spendingBehavior.monthlyAverage / 30;
      suggestedAmount = avgDaily;
    }

    return TransactionDefaults(
      category: defaultCategory,
      suggestedAmount: suggestedAmount,
      date: now,
      paymentMethod: profile?.spendingBehavior.paymentPreference == PaymentPreference.online
          ? '支付宝'
          : null,
    );
  }

  /// 获取预算周期默认值
  Future<BudgetPeriodDefaults> getBudgetPeriodDefaults() async {
    final profile = _currentProfile;
    if (profile == null) {
      return BudgetPeriodDefaults(
        period: BudgetPeriod.monthly,
        startDay: 1,
        categories: ['餐饮', '交通', '购物', '娱乐'],
      );
    }

    // 根据收入稳定性决定周期
    final period = profile.financialFeatures.incomeStability == IncomeStability.stable
        ? BudgetPeriod.monthly
        : BudgetPeriod.weekly;

    return BudgetPeriodDefaults(
      period: period,
      startDay: period == BudgetPeriod.monthly ? 1 : null,
      categories: profile.spendingBehavior.topCategories.take(5).toList(),
    );
  }

  // ==================== 伙伴化文案定制 ====================

  /// 获取伙伴化文案配置
  Future<CompanionCopyConfig> getCompanionCopyConfig() async {
    final profile = _currentProfile;
    if (profile == null) return CompanionCopyConfig.defaultConfig();

    return CompanionCopyConfig(
      tone: _inferTone(profile),
      humorLevel: (profile.personalityTraits.humorAcceptance * 10).round(),
      encouragementStyle: _inferEncouragementStyle(profile),
      sensitiveTopics: profile.personalityTraits.sensitiveTacics,
      preferredLength: profile.personalityTraits.communicationStyle == CommunicationStyle.concise
          ? CopyLength.short
          : CopyLength.medium,
    );
  }

  CopyTone _inferTone(UserProfile profile) {
    if (profile.personalityTraits.emotionalTendency == EmotionalTendency.anxious) {
      return CopyTone.supportive;
    }
    if (profile.personalityTraits.spendingPersonality == SpendingPersonality.goalDriven) {
      return CopyTone.motivational;
    }
    return CopyTone.friendly;
  }

  EncouragementStyle _inferEncouragementStyle(UserProfile profile) {
    return switch (profile.personalityTraits.spendingPersonality) {
      SpendingPersonality.frugalRational => EncouragementStyle.dataFocused,
      SpendingPersonality.goalDriven => EncouragementStyle.goalOriented,
      SpendingPersonality.anxiousWorrier => EncouragementStyle.reassuring,
      _ => EncouragementStyle.balanced,
    };
  }

  /// 生成个性化文案
  Future<String> generatePersonalizedCopy({
    required CopyScenario scenario,
    Map<String, dynamic>? context,
  }) async {
    final config = await getCompanionCopyConfig();
    final profile = _currentProfile;

    // 根据场景和配置生成文案
    return _generateCopy(scenario, config, profile, context);
  }

  String _generateCopy(
    CopyScenario scenario,
    CompanionCopyConfig config,
    UserProfile? profile,
    Map<String, dynamic>? context,
  ) {
    // 文案模板（实际应使用更复杂的模板系统）
    switch (scenario) {
      case CopyScenario.recordSuccess:
        if (config.tone == CopyTone.supportive) {
          return '记录成功！继续保持这个好习惯哦～';
        }
        return '已记录 ✓';

      case CopyScenario.budgetWarning:
        final remaining = context?['remaining'] as double? ?? 0;
        if (config.tone == CopyTone.supportive) {
          return '还剩 ¥${remaining.toStringAsFixed(0)}，相信你能合理安排的！';
        }
        return '预算剩余 ¥${remaining.toStringAsFixed(0)}';

      case CopyScenario.overBudget:
        if (config.encouragementStyle == EncouragementStyle.reassuring) {
          return '这次超了一点点，没关系，下次注意就好～';
        }
        return '预算已超支，请注意控制';

      case CopyScenario.streakAchievement:
        final days = context?['days'] as int? ?? 0;
        if (config.tone == CopyTone.motivational) {
          return '太棒了！连续记账 $days 天，你是最棒的！🎉';
        }
        return '连续记账 $days 天';

      case CopyScenario.moneyAgeImproved:
        return '钱龄提升了，说明你的理财习惯越来越好！';

      default:
        return '';
    }
  }

  // ==================== 功能优先级排序 ====================

  /// 获取功能优先级排序
  Future<List<FeaturePriority>> getFeaturePriorities() async {
    final profile = _currentProfile;
    if (profile == null) return _getDefaultFeaturePriorities();

    final priorities = <FeaturePriority>[];

    // 根据用户特征决定功能优先级
    if (profile.spendingBehavior.impulseRatio > 0.3) {
      priorities.add(const FeaturePriority(
        feature: 'impulse_control',
        priority: 1,
        reason: '您有冲动消费倾向',
      ));
    }

    if (profile.financialFeatures.budgetComplianceRate < 0.7) {
      priorities.add(const FeaturePriority(
        feature: 'budget_tracking',
        priority: 2,
        reason: '帮助您更好地控制预算',
      ));
    }

    if (profile.financialFeatures.emergencyFundMonths < 3) {
      priorities.add(const FeaturePriority(
        feature: 'emergency_fund',
        priority: 3,
        reason: '建立财务安全垫',
      ));
    }

    if (profile.spendingBehavior.latteFactorRatio > 0.15) {
      priorities.add(const FeaturePriority(
        feature: 'latte_factor',
        priority: 4,
        reason: '发现小额消费积累',
      ));
    }

    // 添加默认功能
    priorities.addAll([
      const FeaturePriority(feature: 'quick_record', priority: 5, reason: '快速记账'),
      const FeaturePriority(feature: 'money_age', priority: 6, reason: '钱龄分析'),
      const FeaturePriority(feature: 'reports', priority: 7, reason: '报表分析'),
    ]);

    return priorities;
  }

  List<FeaturePriority> _getDefaultFeaturePriorities() {
    return const [
      FeaturePriority(feature: 'quick_record', priority: 1, reason: '快速记账'),
      FeaturePriority(feature: 'budget_tracking', priority: 2, reason: '预算追踪'),
      FeaturePriority(feature: 'money_age', priority: 3, reason: '钱龄分析'),
      FeaturePriority(feature: 'reports', priority: 4, reason: '报表分析'),
    ];
  }

  /// 清除缓存
  void _invalidateCache() {
    _cache.clear();
  }

  void dispose() {
    _profileStreamController.close();
  }
}

// ==================== 数据模型 ====================

/// UI个性化配置
class UIPersonalization {
  final InfoDensity infoDensity;
  final ChartPreference chartPreference;
  final TimeOfDay defaultReminderTime;
  final bool showSensitiveInfo;
  final ColorSchemePreference preferredColorScheme;
  final AnimationSpeed animationSpeed;
  final List<String> homeWidgetOrder;

  const UIPersonalization({
    required this.infoDensity,
    required this.chartPreference,
    required this.defaultReminderTime,
    required this.showSensitiveInfo,
    required this.preferredColorScheme,
    required this.animationSpeed,
    required this.homeWidgetOrder,
  });

  factory UIPersonalization.defaultConfig() {
    return const UIPersonalization(
      infoDensity: InfoDensity.balanced,
      chartPreference: ChartPreference.balanced,
      defaultReminderTime: TimeOfDay(hour: 20, minute: 0),
      showSensitiveInfo: true,
      preferredColorScheme: ColorSchemePreference.energetic,
      animationSpeed: AnimationSpeed.normal,
      homeWidgetOrder: ['quick_record', 'recent_transactions', 'budget_overview'],
    );
  }
}

enum InfoDensity { compact, balanced, detailed }
enum ChartPreference { simple, balanced, detailed, progress }
enum ColorSchemePreference { calm, energetic, professional }
enum AnimationSpeed { fast, normal, slow }

/// 时间点
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});
}

/// 分类推荐
class CategoryRecommendation {
  final String category;
  final String reason;
  final double confidence;
  final RecommendationSource source;

  const CategoryRecommendation({
    required this.category,
    required this.reason,
    required this.confidence,
    required this.source,
  });
}

enum RecommendationSource { userHistory, timePattern, amountPattern, location, contextual }

/// 商家推荐
class MerchantRecommendation {
  final String merchant;
  final String reason;
  final double confidence;

  const MerchantRecommendation({
    required this.merchant,
    required this.reason,
    required this.confidence,
  });
}

/// 预算推荐
class BudgetRecommendation {
  final String category;
  final double recommendedAmount;
  final String reason;
  final double confidence;
  final double? minSuggested;
  final double? maxSuggested;

  const BudgetRecommendation({
    required this.category,
    required this.recommendedAmount,
    required this.reason,
    required this.confidence,
    this.minSuggested,
    this.maxSuggested,
  });
}

/// 交易默认值
class TransactionDefaults {
  final String? category;
  final double? suggestedAmount;
  final DateTime date;
  final String? paymentMethod;

  const TransactionDefaults({
    this.category,
    this.suggestedAmount,
    required this.date,
    this.paymentMethod,
  });
}

/// 预算周期默认值
class BudgetPeriodDefaults {
  final BudgetPeriod period;
  final int? startDay;
  final List<String> categories;

  const BudgetPeriodDefaults({
    required this.period,
    this.startDay,
    required this.categories,
  });
}

enum BudgetPeriod { weekly, biweekly, monthly }

/// 伙伴化文案配置
class CompanionCopyConfig {
  final CopyTone tone;
  final int humorLevel; // 0-10
  final EncouragementStyle encouragementStyle;
  final List<String> sensitiveTopics;
  final CopyLength preferredLength;

  const CompanionCopyConfig({
    required this.tone,
    required this.humorLevel,
    required this.encouragementStyle,
    required this.sensitiveTopics,
    required this.preferredLength,
  });

  factory CompanionCopyConfig.defaultConfig() {
    return const CompanionCopyConfig(
      tone: CopyTone.friendly,
      humorLevel: 5,
      encouragementStyle: EncouragementStyle.balanced,
      sensitiveTopics: [],
      preferredLength: CopyLength.medium,
    );
  }
}

enum CopyTone { formal, friendly, supportive, motivational }
enum EncouragementStyle { dataFocused, goalOriented, reassuring, balanced }
enum CopyLength { short, medium, long }

/// 文案场景
enum CopyScenario {
  recordSuccess,
  budgetWarning,
  overBudget,
  streakAchievement,
  moneyAgeImproved,
  welcomeBack,
  idle,
}

/// 功能优先级
class FeaturePriority {
  final String feature;
  final int priority;
  final String reason;

  const FeaturePriority({
    required this.feature,
    required this.priority,
    required this.reason,
  });
}

// ==================== 接口定义 ====================

/// 用户画像提供者接口
abstract class UserProfileProvider {
  Future<UserProfile?> getProfile(String userId);
  Stream<UserProfile> get onProfileUpdated;
}

/// 缓存接口
abstract class ProfileApplicationCache {
  Future<T?> get<T>(String key);
  Future<void> set<T>(String key, T value);
  void clear();
}

/// 内存缓存实现
class InMemoryProfileApplicationCache implements ProfileApplicationCache {
  final Map<String, dynamic> _cache = {};

  @override
  Future<T?> get<T>(String key) async {
    return _cache[key] as T?;
  }

  @override
  Future<void> set<T>(String key, T value) async {
    _cache[key] = value;
  }

  @override
  void clear() {
    _cache.clear();
  }
}

// ==================== 全局单例 ====================

/// 用户画像应用管理器（单例）
class UserProfileApplicationManager {
  static UserProfileApplicationManager? _instance;

  final UserProfileApplicationService _service;

  UserProfileApplicationManager._(this._service);

  static UserProfileApplicationManager get instance {
    if (_instance == null) {
      throw StateError('UserProfileApplicationManager not initialized');
    }
    return _instance!;
  }

  static Future<void> initialize({
    required UserProfileProvider profileProvider,
    required String userId,
  }) async {
    if (_instance != null) return;

    final service = UserProfileApplicationService(
      profileProvider: profileProvider,
    );

    await service.initialize(userId);
    _instance = UserProfileApplicationManager._(service);
  }

  UserProfileApplicationService get service => _service;

  /// 便捷方法：获取推荐分类
  Future<List<CategoryRecommendation>> getRecommendedCategories() =>
      _service.getRecommendedCategories();

  /// 便捷方法：获取交易默认值
  Future<TransactionDefaults> getTransactionDefaults() =>
      _service.getTransactionDefaults();

  /// 便捷方法：获取伙伴化文案
  Future<String> getCopy(CopyScenario scenario, {Map<String, dynamic>? context}) =>
      _service.generatePersonalizedCopy(scenario: scenario, context: context);

  void dispose() {
    _service.dispose();
    _instance = null;
  }
}
