import '../models/budget_vault.dart';
import '../models/transaction.dart';
import 'allocation_service.dart';
import 'localized_budget_service.dart';
import 'smart_budget_service.dart' hide AmountRange;

/// 位置感知预算分配建议
class LocationBasedBudgetSuggestion {
  final Map<String, double> locationPatterns;
  final List<LocationSpendingInsight> insights;
  final double adjustmentFactor;

  const LocationBasedBudgetSuggestion({
    required this.locationPatterns,
    required this.insights,
    required this.adjustmentFactor,
  });
}

/// 位置消费洞察
class LocationSpendingInsight {
  final String location;
  final String categoryId;
  final double averageAmount;
  final int frequency;
  final String suggestion;

  const LocationSpendingInsight({
    required this.location,
    required this.categoryId,
    required this.averageAmount,
    required this.frequency,
    required this.suggestion,
  });
}

/// 完整的预算规划结果
class CompleteBudgetPlan {
  final List<RecommendedCategory> categories;
  final List<BudgetSuggestion> smartSuggestions;
  final Map<String, BudgetAmountSuggestion> categoryAmounts;
  final LocationBasedBudgetSuggestion? locationInsights;
  final double totalIncome;
  final DateTime generatedAt;

  const CompleteBudgetPlan({
    required this.categories,
    required this.smartSuggestions,
    required this.categoryAmounts,
    this.locationInsights,
    required this.totalIncome,
    required this.generatedAt,
  });

  /// 获取某类目的最终建议金额
  /// 综合考虑优先级：智能建议 > 本地化金额 > 类目默认占比
  double getSuggestedAmountForCategory(String categoryName) {
    // 优先使用智能建议（基于用户实际消费）
    final smart = smartSuggestions.where((s) => s.categoryName == categoryName);
    if (smart.isNotEmpty && smart.first.amount > 0) {
      return smart.first.amount;
    }

    // 其次使用本地化金额建议
    final localized = categoryAmounts[categoryName];
    if (localized != null) {
      return localized.suggestedAmount;
    }

    // 最后使用类目默认占比
    final category = categories.where((c) => c.name == categoryName);
    if (category.isNotEmpty) {
      return totalIncome * category.first.suggestedPercentage;
    }

    return 0;
  }

  /// 获取所有类目的最终建议金额
  Map<String, double> getAllSuggestedAmounts() {
    final result = <String, double>{};

    for (final category in categories) {
      result[category.name] = getSuggestedAmountForCategory(category.name);
    }

    return result;
  }

  /// 获取剩余未分配金额
  double get remainingIncome {
    final allocated = getAllSuggestedAmounts().values.fold(0.0, (a, b) => a + b);
    return totalIncome - allocated;
  }

  /// 是否收支平衡
  bool get isBalanced => remainingIncome.abs() < 1;

  /// 获取分配建议的置信度（0-1）
  double get overallConfidence {
    if (smartSuggestions.isEmpty) return 0.5;
    return smartSuggestions.map((s) => s.confidence).reduce((a, b) => a + b) /
        smartSuggestions.length;
  }

  /// 转换为分配建议列表
  List<AllocationSuggestion> toAllocationSuggestions() {
    final amounts = getAllSuggestedAmounts();
    final suggestions = <AllocationSuggestion>[];

    for (final entry in amounts.entries) {
      final categoryName = entry.key;
      final amount = entry.value;

      // 确定优先级和类型
      int priority;
      String reason;
      VaultType vaultType;

      if (categoryName.contains('房租') || categoryName.contains('房贷')) {
        priority = 1;
        reason = '固定支出需要优先保障';
        vaultType = VaultType.fixed;
      } else if (categoryName.contains('储蓄') || categoryName.contains('投资')) {
        priority = 2;
        reason = '先储蓄后消费，提升钱龄';
        vaultType = VaultType.savings;
      } else if (categoryName.contains('餐饮') || categoryName.contains('日用')) {
        priority = 3;
        reason = '日常必需开支';
        vaultType = VaultType.flexible;
      } else {
        priority = 4;
        reason = '弹性支出';
        vaultType = VaultType.flexible;
      }

      suggestions.add(AllocationSuggestion(
        vaultId: categoryName, // 使用类目名作为临时ID
        vaultName: categoryName,
        suggestedAmount: amount,
        reason: reason,
        priority: priority,
        vaultType: vaultType,
      ));
    }

    suggestions.sort((a, b) => a.priority.compareTo(b.priority));
    return suggestions;
  }
}

/// 预算规划协调器
///
/// 整合各层预算服务，生成完整的预算规划建议：
/// - SmartBudgetService：基于历史消费的智能建议
/// - LocalizedBudgetCategoryService：基于城市的类目推荐
/// - LocalizedBudgetAmountService：基于城市的金额建议
/// - LocationAwareZeroBudgetService：基于位置模式的分配建议（可选）
class BudgetPlanningCoordinator {
  final SmartBudgetService _smartBudget;
  final LocalizedBudgetCategoryService _localizedCategory;
  final LocalizedBudgetAmountService _localizedAmount;
  final LocationAwareZeroBudgetService? _locationAwareBudget;

  BudgetPlanningCoordinator({
    required SmartBudgetService smartBudget,
    required LocalizedBudgetCategoryService localizedCategory,
    required LocalizedBudgetAmountService localizedAmount,
    LocationAwareZeroBudgetService? locationAwareBudget,
  })  : _smartBudget = smartBudget,
        _localizedCategory = localizedCategory,
        _localizedAmount = localizedAmount,
        _locationAwareBudget = locationAwareBudget;

  /// 生成完整的预算规划建议
  Future<CompleteBudgetPlan> generateBudgetPlan({
    required double monthlyIncome,
    required CityLocation? userCity,
    required List<Transaction> historicalTransactions,
    bool useLocationInsights = false,
  }) async {
    // 1. 获取本地化类目推荐
    List<RecommendedCategory> categories = [];
    if (userCity != null) {
      categories = _localizedCategory.getRecommendedCategories(userCity);
    } else {
      // 使用默认的三四线城市类目
      categories = _localizedCategory.getRecommendedCategories(
        CityLocation.unknown(),
      );
    }

    // 2. 获取智能预算建议（基于历史消费）
    final smartSuggestions = await _smartBudget.generateBudgetSuggestions();

    // 3. 为每个类目计算本地化金额建议
    final categoryAmounts = <String, BudgetAmountSuggestion>{};
    final effectiveCity = userCity ?? CityLocation.unknown();

    for (final category in categories) {
      categoryAmounts[category.name] = _localizedAmount.getSuggestedAmount(
        category: category.name,
        location: effectiveCity,
        monthlyIncome: monthlyIncome,
      );
    }

    // 4. 可选：结合位置洞察优化
    LocationBasedBudgetSuggestion? locationInsights;
    if (useLocationInsights && _locationAwareBudget != null) {
      locationInsights = await _locationAwareBudget.suggestBudgetAllocation(
        monthlyIncome: monthlyIncome,
        historicalTransactions: historicalTransactions,
      );
    }

    // 5. 综合生成最终建议
    return CompleteBudgetPlan(
      categories: categories,
      smartSuggestions: smartSuggestions,
      categoryAmounts: categoryAmounts,
      locationInsights: locationInsights,
      totalIncome: monthlyIncome,
      generatedAt: DateTime.now(),
    );
  }

  /// 快速生成预算建议（仅基于收入和城市）
  Future<CompleteBudgetPlan> generateQuickPlan({
    required double monthlyIncome,
    CityLocation? userCity,
  }) async {
    return generateBudgetPlan(
      monthlyIncome: monthlyIncome,
      userCity: userCity,
      historicalTransactions: [],
      useLocationInsights: false,
    );
  }

  /// 获取新用户引导的预算建议
  Future<NewUserBudgetGuide> getNewUserGuide({
    required double monthlyIncome,
    required CityLocation userCity,
  }) async {
    final plan = await generateQuickPlan(
      monthlyIncome: monthlyIncome,
      userCity: userCity,
    );

    // 生成简化版建议（只显示主要类目）
    final mainCategories = plan.categories.where((c) => c.priority <= 5).toList();

    return NewUserBudgetGuide(
      income: monthlyIncome,
      city: userCity,
      suggestedCategories: mainCategories,
      suggestedAmounts: plan.getAllSuggestedAmounts(),
      tips: _generateNewUserTips(userCity, monthlyIncome),
    );
  }

  /// 调整现有预算计划
  Future<CompleteBudgetPlan> adjustPlan({
    required CompleteBudgetPlan currentPlan,
    required Map<String, double> userAdjustments,
  }) async {
    // 应用用户调整
    final adjustedAmounts = Map<String, BudgetAmountSuggestion>.from(
      currentPlan.categoryAmounts,
    );

    for (final entry in userAdjustments.entries) {
      if (adjustedAmounts.containsKey(entry.key)) {
        final original = adjustedAmounts[entry.key]!;
        adjustedAmounts[entry.key] = BudgetAmountSuggestion(
          category: original.category,
          suggestedAmount: entry.value,
          nationalAverage: original.nationalAverage,
          localAverage: original.localAverage,
          reasoning: '用户自定义金额',
          range: AmountRange(min: entry.value * 0.5, max: entry.value * 1.5),
        );
      }
    }

    return CompleteBudgetPlan(
      categories: currentPlan.categories,
      smartSuggestions: currentPlan.smartSuggestions,
      categoryAmounts: adjustedAmounts,
      locationInsights: currentPlan.locationInsights,
      totalIncome: currentPlan.totalIncome,
      generatedAt: DateTime.now(),
    );
  }

  /// 验证预算计划
  BudgetPlanValidation validatePlan(CompleteBudgetPlan plan) {
    final issues = <String>[];
    final warnings = <String>[];

    final totalAllocated = plan.getAllSuggestedAmounts().values.fold(0.0, (a, b) => a + b);

    // 检查是否超预算
    if (totalAllocated > plan.totalIncome) {
      issues.add('总预算 ¥${totalAllocated.toStringAsFixed(0)} 超过月收入 ¥${plan.totalIncome.toStringAsFixed(0)}');
    }

    // 检查储蓄比例
    final savingsAmount = plan.getSuggestedAmountForCategory('储蓄/投资');
    final savingsRate = savingsAmount / plan.totalIncome;
    if (savingsRate < 0.1) {
      warnings.add('储蓄比例仅 ${(savingsRate * 100).toStringAsFixed(1)}%，建议至少 10%');
    }

    // 检查固定支出占比
    final housingAmount = plan.getSuggestedAmountForCategory('房租/房贷');
    final housingRate = housingAmount / plan.totalIncome;
    if (housingRate > 0.4) {
      warnings.add('住房支出占比 ${(housingRate * 100).toStringAsFixed(1)}%，压力较大');
    }

    // 检查是否有剩余
    final remaining = plan.totalIncome - totalAllocated;
    if (remaining > plan.totalIncome * 0.1) {
      warnings.add('有 ¥${remaining.toStringAsFixed(0)} 未分配，建议合理规划');
    }

    return BudgetPlanValidation(
      isValid: issues.isEmpty,
      issues: issues,
      warnings: warnings,
      totalAllocated: totalAllocated,
      remaining: remaining,
    );
  }

  /// 生成新用户提示
  List<String> _generateNewUserTips(CityLocation city, double income) {
    final tips = <String>[];

    switch (city.tier) {
      case CityTier.tier1:
        tips.add('一线城市生活成本较高，建议优先保障房租和通勤预算');
        tips.add('尽量利用公共交通，控制出行成本');
        break;
      case CityTier.newTier1:
        tips.add('新一线城市生活成本适中，是积累储蓄的好机会');
        break;
      case CityTier.tier2:
        tips.add('二线城市生活压力较小，可以适当增加储蓄比例');
        break;
      case CityTier.tier3:
      case CityTier.tier4Plus:
      case CityTier.unknown:
        tips.add('生活成本较低，建议多储蓄为未来做准备');
        break;
      case CityTier.overseas:
        tips.add('海外生活成本因地区差异较大，建议根据当地实际情况调整');
        break;
    }

    // 根据收入给出建议
    if (income < 8000) {
      tips.add('收入有限时，建议优先保障必需开支，减少非必要消费');
    } else if (income > 20000) {
      tips.add('收入较好时，建议提高储蓄率到 25% 以上');
    }

    tips.add('建议先建立 3-6 个月生活费的应急金');

    return tips;
  }
}

/// 新用户预算引导
class NewUserBudgetGuide {
  final double income;
  final CityLocation city;
  final List<RecommendedCategory> suggestedCategories;
  final Map<String, double> suggestedAmounts;
  final List<String> tips;

  const NewUserBudgetGuide({
    required this.income,
    required this.city,
    required this.suggestedCategories,
    required this.suggestedAmounts,
    required this.tips,
  });
}

/// 预算计划验证结果
class BudgetPlanValidation {
  final bool isValid;
  final List<String> issues;
  final List<String> warnings;
  final double totalAllocated;
  final double remaining;

  const BudgetPlanValidation({
    required this.isValid,
    required this.issues,
    required this.warnings,
    required this.totalAllocated,
    required this.remaining,
  });
}

/// 位置感知零基预算服务（第4层服务）
///
/// 基于GPS位置模式的预算分配建议
class LocationAwareZeroBudgetService {
  /// 根据历史消费位置模式生成分配建议
  Future<LocationBasedBudgetSuggestion> suggestBudgetAllocation({
    required double monthlyIncome,
    required List<Transaction> historicalTransactions,
  }) async {
    // 分析位置消费模式
    final locationPatterns = _analyzeLocationPatterns(historicalTransactions);
    final insights = _generateLocationInsights(locationPatterns);
    final adjustmentFactor = _calculateAdjustmentFactor(locationPatterns);

    return LocationBasedBudgetSuggestion(
      locationPatterns: locationPatterns,
      insights: insights,
      adjustmentFactor: adjustmentFactor,
    );
  }

  /// 分析位置消费模式
  Map<String, double> _analyzeLocationPatterns(List<Transaction> transactions) {
    final patterns = <String, double>{};

    for (final tx in transactions) {
      final location = tx.location?.placeName ?? tx.location?.address ?? '未知';
      patterns[location] = (patterns[location] ?? 0) + tx.amount;
    }

    return patterns;
  }

  /// 生成位置消费洞察
  List<LocationSpendingInsight> _generateLocationInsights(
    Map<String, double> patterns,
  ) {
    final insights = <LocationSpendingInsight>[];

    // 找出高消费区域
    final sortedLocations = patterns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i < sortedLocations.length && i < 5; i++) {
      final entry = sortedLocations[i];
      insights.add(LocationSpendingInsight(
        location: entry.key,
        categoryId: 'general',
        averageAmount: entry.value,
        frequency: 1,
        suggestion: '在${entry.key}消费较多，建议关注该区域的支出',
      ));
    }

    return insights;
  }

  /// 计算调整因子
  double _calculateAdjustmentFactor(Map<String, double> patterns) {
    if (patterns.isEmpty) return 1.0;

    // 如果有多个高消费区域，可能需要更多预算
    final highSpendingLocations = patterns.values.where((v) => v > 1000).length;
    if (highSpendingLocations > 3) {
      return 1.1; // 增加 10% 预算
    }

    return 1.0;
  }

  /// 获取某位置的消费预测
  Future<double> predictSpendingAtLocation({
    required String location,
    required List<Transaction> historicalTransactions,
  }) async {
    final locationTx = historicalTransactions
        .where((tx) => tx.location?.placeName == location || tx.location?.address == location)
        .toList();

    if (locationTx.isEmpty) return 0;

    return locationTx.map((tx) => tx.amount).reduce((a, b) => a + b) /
        locationTx.length;
  }
}
