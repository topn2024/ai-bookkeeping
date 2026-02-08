import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

// ==================== 预算偏好数据模型 ====================

/// 用户预算偏好
class UserBudgetPreferences {
  final String userId;
  final double acceptanceRatio;
  final Map<String, double> categoryElasticity;
  final BudgetTightness tightnessPreference;
  final Map<int, double> seasonalAdjustments;
  final Map<String, double> categoryPriorities;
  final DateTime learnedAt;

  const UserBudgetPreferences({
    required this.userId,
    required this.acceptanceRatio,
    required this.categoryElasticity,
    required this.tightnessPreference,
    required this.seasonalAdjustments,
    required this.categoryPriorities,
    required this.learnedAt,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'acceptance_ratio': acceptanceRatio,
        'category_elasticity': categoryElasticity,
        'tightness_preference': tightnessPreference.name,
        'seasonal_adjustments': seasonalAdjustments.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
        'category_priorities': categoryPriorities,
        'learned_at': learnedAt.toIso8601String(),
      };
}

/// 预算紧度偏好
enum BudgetTightness {
  veryTight, // 非常紧凑（低于建议10%+）
  tight, // 偏紧（低于建议5-10%）
  balanced, // 平衡（接近建议）
  loose, // 宽松（高于建议5-10%）
  veryLoose, // 非常宽松（高于建议10%+）
}

/// 预算建议反馈
class BudgetSuggestionFeedback {
  final String id;
  final String userId;
  final String category;
  final double suggestedAmount;
  final double? acceptedAmount;
  final FeedbackAction action;
  final DateTime timestamp;
  final int month;
  final Map<String, dynamic> context;

  const BudgetSuggestionFeedback({
    required this.id,
    required this.userId,
    required this.category,
    required this.suggestedAmount,
    this.acceptedAmount,
    required this.action,
    required this.timestamp,
    required this.month,
    this.context = const {},
  });

  double get adjustmentRatio =>
      acceptedAmount != null ? acceptedAmount! / suggestedAmount : 1.0;
}

/// 反馈行为
enum FeedbackAction {
  accepted, // 接受建议
  increased, // 增加预算
  decreased, // 减少预算
  rejected, // 拒绝建议
  customized, // 自定义金额
}

// ==================== 个性化预算建议 ====================

/// 个性化预算建议
class PersonalizedBudgetSuggestion {
  final String category;
  final double baseAmount;
  final double personalizedAmount;
  final double confidence;
  final List<String> adjustmentReasons;
  final Map<String, double> alternatives;

  const PersonalizedBudgetSuggestion({
    required this.category,
    required this.baseAmount,
    required this.personalizedAmount,
    required this.confidence,
    required this.adjustmentReasons,
    required this.alternatives,
  });

  double get adjustmentPercent =>
      (personalizedAmount - baseAmount) / baseAmount * 100;
}

// ==================== 反馈存储 ====================

/// 预算反馈存储接口
abstract class BudgetFeedbackStore {
  Future<void> saveFeedback(BudgetSuggestionFeedback feedback);
  Future<List<BudgetSuggestionFeedback>> getUserFeedbacks(
    String userId, {
    int? months,
    String? category,
  });
}

/// 内存预算反馈存储
class InMemoryBudgetFeedbackStore implements BudgetFeedbackStore {
  final List<BudgetSuggestionFeedback> _feedbacks = [];

  @override
  Future<void> saveFeedback(BudgetSuggestionFeedback feedback) async {
    _feedbacks.add(feedback);
  }

  @override
  Future<List<BudgetSuggestionFeedback>> getUserFeedbacks(
    String userId, {
    int? months,
    String? category,
  }) async {
    var result = _feedbacks.where((f) => f.userId == userId);

    if (months != null) {
      final cutoff = DateTime.now().subtract(Duration(days: months * 30));
      result = result.where((f) => f.timestamp.isAfter(cutoff));
    }

    if (category != null) {
      result = result.where((f) => f.category == category);
    }

    return result.toList();
  }

  void clear() => _feedbacks.clear();
}

// ==================== 个性化预算学习服务 ====================

/// 个性化预算学习服务
class PersonalizedBudgetLearningService {
  final BudgetFeedbackStore _feedbackStore;
  final Map<String, UserBudgetPreferences> _preferencesCache = {};

  // 学习配置
  static const int _minSamplesForLearning = 5;
  static const double _defaultAcceptanceRatio = 1.0;

  PersonalizedBudgetLearningService({
    BudgetFeedbackStore? feedbackStore,
  }) : _feedbackStore = feedbackStore ?? InMemoryBudgetFeedbackStore();

  /// 学习用户预算偏好
  Future<UserBudgetPreferences> learnPreferences(String userId) async {
    final samples = await _feedbackStore.getUserFeedbacks(userId, months: 12);

    if (samples.length < _minSamplesForLearning) {
      return _getDefaultPreferences(userId);
    }

    final preferences = UserBudgetPreferences(
      userId: userId,
      acceptanceRatio: _calculateAcceptanceRatio(samples),
      categoryElasticity: _calculateCategoryElasticity(samples),
      tightnessPreference: _calculateTightnessPreference(samples),
      seasonalAdjustments: _calculateSeasonalAdjustments(samples),
      categoryPriorities: _calculateCategoryPriorities(samples),
      learnedAt: DateTime.now(),
    );

    _preferencesCache[userId] = preferences;
    debugPrint('Learned budget preferences for user: $userId');

    return preferences;
  }

  /// 计算接受率
  double _calculateAcceptanceRatio(List<BudgetSuggestionFeedback> samples) {
    final ratios = samples
        .where((s) => s.acceptedAmount != null)
        .map((s) => s.adjustmentRatio)
        .toList();

    if (ratios.isEmpty) return _defaultAcceptanceRatio;

    return ratios.reduce((a, b) => a + b) / ratios.length;
  }

  /// 计算分类弹性（用户对各分类的调整幅度）
  Map<String, double> _calculateCategoryElasticity(
      List<BudgetSuggestionFeedback> samples) {
    final elasticity = <String, double>{};
    final byCategory = groupBy(samples, (s) => s.category);

    for (final entry in byCategory.entries) {
      final adjustments = entry.value
          .where((s) => s.acceptedAmount != null)
          .map((s) => (s.adjustmentRatio - 1.0).abs())
          .toList();

      if (adjustments.isNotEmpty) {
        // 弹性 = 平均调整幅度，弹性高说明用户经常调整该分类
        elasticity[entry.key] =
            adjustments.reduce((a, b) => a + b) / adjustments.length;
      }
    }

    return elasticity;
  }

  /// 计算预算紧度偏好
  BudgetTightness _calculateTightnessPreference(
      List<BudgetSuggestionFeedback> samples) {
    final ratios = samples
        .where((s) => s.acceptedAmount != null)
        .map((s) => s.adjustmentRatio)
        .toList();

    if (ratios.isEmpty) return BudgetTightness.balanced;

    final avgRatio = ratios.reduce((a, b) => a + b) / ratios.length;

    if (avgRatio < 0.9) return BudgetTightness.veryTight;
    if (avgRatio < 0.95) return BudgetTightness.tight;
    if (avgRatio > 1.1) return BudgetTightness.veryLoose;
    if (avgRatio > 1.05) return BudgetTightness.loose;
    return BudgetTightness.balanced;
  }

  /// 计算季节性调整
  Map<int, double> _calculateSeasonalAdjustments(
      List<BudgetSuggestionFeedback> samples) {
    final seasonal = <int, double>{};
    final byMonth = groupBy(samples, (s) => s.month);

    // 计算整体平均比例
    final allRatios = samples
        .where((s) => s.acceptedAmount != null)
        .map((s) => s.adjustmentRatio)
        .toList();
    final overallAvg =
        allRatios.isEmpty ? 1.0 : allRatios.reduce((a, b) => a + b) / allRatios.length;

    // 计算每月相对于整体的调整
    for (final entry in byMonth.entries) {
      final monthRatios = entry.value
          .where((s) => s.acceptedAmount != null)
          .map((s) => s.adjustmentRatio)
          .toList();

      if (monthRatios.isNotEmpty) {
        final monthAvg = monthRatios.reduce((a, b) => a + b) / monthRatios.length;
        seasonal[entry.key] = monthAvg / overallAvg;
      }
    }

    return seasonal;
  }

  /// 计算分类优先级
  Map<String, double> _calculateCategoryPriorities(
      List<BudgetSuggestionFeedback> samples) {
    final priorities = <String, double>{};
    final byCategory = groupBy(samples, (s) => s.category);

    // 基于调整方向计算优先级
    // 增加预算 = 高优先级，减少预算 = 低优先级
    for (final entry in byCategory.entries) {
      double priorityScore = 0.5; // 基准分

      for (final sample in entry.value) {
        switch (sample.action) {
          case FeedbackAction.increased:
            priorityScore += 0.1;
            break;
          case FeedbackAction.decreased:
            priorityScore -= 0.1;
            break;
          case FeedbackAction.rejected:
            priorityScore -= 0.2;
            break;
          default:
            break;
        }
      }

      priorities[entry.key] = priorityScore.clamp(0.0, 1.0);
    }

    return priorities;
  }

  UserBudgetPreferences _getDefaultPreferences(String userId) {
    return UserBudgetPreferences(
      userId: userId,
      acceptanceRatio: 1.0,
      categoryElasticity: {},
      tightnessPreference: BudgetTightness.balanced,
      seasonalAdjustments: {},
      categoryPriorities: {},
      learnedAt: DateTime.now(),
    );
  }

  /// 应用个性化调整
  Future<PersonalizedBudgetSuggestion> applyPersonalization({
    required String userId,
    required String category,
    required double baseSuggestion,
    int? month,
  }) async {
    var preferences = _preferencesCache[userId];
    preferences ??= await learnPreferences(userId);

    double personalizedAmount = baseSuggestion;
    final reasons = <String>[];
    final alternatives = <String, double>{};

    // 1. 应用整体接受率
    personalizedAmount *= preferences.acceptanceRatio;
    if ((preferences.acceptanceRatio - 1.0).abs() > 0.05) {
      reasons.add('基于您的历史偏好调整');
    }

    // 2. 应用分类弹性
    final elasticity = preferences.categoryElasticity[category];
    if (elasticity != null && elasticity > 0.1) {
      // 高弹性分类，提供更宽的建议范围
      alternatives['保守'] = personalizedAmount * 0.9;
      alternatives['宽松'] = personalizedAmount * 1.1;
      reasons.add('$category是您经常调整的分类');
    }

    // 3. 应用季节性调整
    final currentMonth = month ?? DateTime.now().month;
    final seasonalAdj = preferences.seasonalAdjustments[currentMonth];
    if (seasonalAdj != null && (seasonalAdj - 1.0).abs() > 0.05) {
      personalizedAmount *= seasonalAdj;
      if (seasonalAdj > 1.0) {
        reasons.add('根据您$currentMonth月的消费习惯上调');
      } else {
        reasons.add('根据您$currentMonth月的消费习惯下调');
      }
    }

    // 4. 应用紧度偏好
    switch (preferences.tightnessPreference) {
      case BudgetTightness.veryTight:
        personalizedAmount *= 0.9;
        reasons.add('您偏好紧凑的预算');
        break;
      case BudgetTightness.tight:
        personalizedAmount *= 0.95;
        break;
      case BudgetTightness.loose:
        personalizedAmount *= 1.05;
        break;
      case BudgetTightness.veryLoose:
        personalizedAmount *= 1.1;
        reasons.add('您偏好宽松的预算');
        break;
      default:
        break;
    }

    // 计算置信度
    final confidence = _calculateConfidence(preferences, category);

    return PersonalizedBudgetSuggestion(
      category: category,
      baseAmount: baseSuggestion,
      personalizedAmount: personalizedAmount,
      confidence: confidence,
      adjustmentReasons: reasons,
      alternatives: alternatives,
    );
  }

  double _calculateConfidence(
    UserBudgetPreferences preferences,
    String category,
  ) {
    double confidence = 0.5;

    // 有分类弹性数据增加置信度
    if (preferences.categoryElasticity.containsKey(category)) {
      confidence += 0.2;
    }

    // 有季节性数据增加置信度
    if (preferences.seasonalAdjustments.isNotEmpty) {
      confidence += 0.1;
    }

    // 有分类优先级增加置信度
    if (preferences.categoryPriorities.containsKey(category)) {
      confidence += 0.1;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// 记录用户反馈
  Future<void> recordFeedback(BudgetSuggestionFeedback feedback) async {
    await _feedbackStore.saveFeedback(feedback);

    // 检查是否需要更新偏好
    final preferences = _preferencesCache[feedback.userId];
    if (preferences != null) {
      final hoursSinceLearning =
          DateTime.now().difference(preferences.learnedAt).inHours;
      if (hoursSinceLearning >= 24) {
        // 超过24小时重新学习
        await learnPreferences(feedback.userId);
      }
    }
  }

  /// 获取分类建议优先级
  Future<List<CategoryBudgetPriority>> getCategoryPriorities(
      String userId) async {
    var preferences = _preferencesCache[userId];
    preferences ??= await learnPreferences(userId);

    return preferences.categoryPriorities.entries
        .map((e) => CategoryBudgetPriority(
              category: e.key,
              priority: e.value,
              elasticity: preferences!.categoryElasticity[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// 获取学习统计
  Future<BudgetLearningStats> getStats(String userId) async {
    final samples = await _feedbackStore.getUserFeedbacks(userId, months: 12);
    final preferences = _preferencesCache[userId];

    return BudgetLearningStats(
      totalSamples: samples.length,
      categoriesLearned: preferences?.categoryElasticity.keys.length ?? 0,
      hasSeasonalData: preferences?.seasonalAdjustments.isNotEmpty ?? false,
      tightnessPreference: preferences?.tightnessPreference,
      lastLearnedAt: preferences?.learnedAt,
    );
  }
}

/// 分类预算优先级
class CategoryBudgetPriority {
  final String category;
  final double priority;
  final double elasticity;

  const CategoryBudgetPriority({
    required this.category,
    required this.priority,
    required this.elasticity,
  });
}

/// 预算学习统计
class BudgetLearningStats {
  final int totalSamples;
  final int categoriesLearned;
  final bool hasSeasonalData;
  final BudgetTightness? tightnessPreference;
  final DateTime? lastLearnedAt;

  const BudgetLearningStats({
    required this.totalSamples,
    required this.categoriesLearned,
    required this.hasSeasonalData,
    this.tightnessPreference,
    this.lastLearnedAt,
  });
}
