import 'package:flutter/material.dart';

/// 城市级别
enum CityTier {
  /// 一线城市（北上广深）
  tier1,

  /// 新一线城市（杭州、成都、武汉等）
  newTier1,

  /// 二线城市
  tier2,

  /// 三四线城市
  tier3,

  /// 未知
  unknown,
}

extension CityTierExtension on CityTier {
  String get displayName {
    switch (this) {
      case CityTier.tier1:
        return '一线城市';
      case CityTier.newTier1:
        return '新一线城市';
      case CityTier.tier2:
        return '二线城市';
      case CityTier.tier3:
        return '三四线城市';
      case CityTier.unknown:
        return '未知';
    }
  }
}

/// 城市位置信息
class CityLocation {
  final String city;
  final String? province;
  final CityTier tier;
  final bool isOverseas;
  final String? countryCode;

  const CityLocation({
    required this.city,
    this.province,
    required this.tier,
    this.isOverseas = false,
    this.countryCode,
  });

  /// 一线城市列表
  static const tier1Cities = ['北京', '上海', '广州', '深圳'];

  /// 新一线城市列表
  static const newTier1Cities = [
    '杭州', '成都', '武汉', '重庆', '南京', '天津', '苏州', '西安',
    '长沙', '沈阳', '青岛', '郑州', '大连', '东莞', '宁波',
  ];

  /// 根据城市名推断级别
  factory CityLocation.fromCityName(String city) {
    CityTier tier;
    if (tier1Cities.contains(city)) {
      tier = CityTier.tier1;
    } else if (newTier1Cities.contains(city)) {
      tier = CityTier.newTier1;
    } else {
      tier = CityTier.tier3; // 默认三四线
    }

    return CityLocation(city: city, tier: tier);
  }

  /// 默认城市（未知）
  factory CityLocation.unknown() {
    return const CityLocation(city: '未知', tier: CityTier.unknown);
  }
}

/// 推荐类目
class RecommendedCategory {
  final String name;
  final IconData icon;
  final double suggestedPercentage; // 建议占收入比例（0-1）
  final int priority;
  final String? description;
  final List<String>? subCategories;

  const RecommendedCategory({
    required this.name,
    required this.icon,
    required this.suggestedPercentage,
    required this.priority,
    this.description,
    this.subCategories,
  });

  factory RecommendedCategory.empty() {
    return const RecommendedCategory(
      name: '',
      icon: Icons.help_outline,
      suggestedPercentage: 0,
      priority: 999,
    );
  }
}

/// 本地化预算类目推荐服务
///
/// 根据城市级别推荐适合的预算类目和建议比例
class LocalizedBudgetCategoryService {
  /// 根据城市级别推荐默认预算类目
  List<RecommendedCategory> getRecommendedCategories(CityLocation location) {
    final tier = location.tier;
    final isOverseas = location.isOverseas;

    if (isOverseas) {
      return _getOverseasCategories(location);
    }

    switch (tier) {
      case CityTier.tier1:
        return _getTier1Categories();
      case CityTier.newTier1:
        return _getNewTier1Categories();
      case CityTier.tier2:
        return _getTier2Categories();
      case CityTier.tier3:
      case CityTier.unknown:
        return _getTier3Categories();
    }
  }

  /// 一线城市推荐类目（高房租、高通勤成本）
  List<RecommendedCategory> _getTier1Categories() {
    return [
      const RecommendedCategory(
        name: '房租/房贷',
        icon: Icons.home,
        suggestedPercentage: 0.30, // 收入的30%
        priority: 1,
        description: '一线城市房租占比通常较高',
      ),
      const RecommendedCategory(
        name: '通勤交通',
        icon: Icons.subway,
        suggestedPercentage: 0.08,
        priority: 2,
        description: '地铁/公交/网约车',
        subCategories: ['地铁', '公交', '网约车', '共享单车'],
      ),
      const RecommendedCategory(
        name: '餐饮',
        icon: Icons.restaurant,
        suggestedPercentage: 0.15,
        priority: 3,
        description: '外卖和工作餐成本较高',
      ),
      const RecommendedCategory(
        name: '日用品',
        icon: Icons.shopping_bag,
        suggestedPercentage: 0.05,
        priority: 4,
      ),
      const RecommendedCategory(
        name: '社交娱乐',
        icon: Icons.celebration,
        suggestedPercentage: 0.08,
        priority: 5,
      ),
      const RecommendedCategory(
        name: '储蓄/投资',
        icon: Icons.savings,
        suggestedPercentage: 0.20,
        priority: 6,
        description: '建议优先积累应急金',
      ),
      const RecommendedCategory(
        name: '自我提升',
        icon: Icons.school,
        suggestedPercentage: 0.05,
        priority: 7,
        description: '培训、书籍、课程',
      ),
      const RecommendedCategory(
        name: '其他',
        icon: Icons.more_horiz,
        suggestedPercentage: 0.09,
        priority: 8,
      ),
    ];
  }

  /// 新一线城市推荐类目
  List<RecommendedCategory> _getNewTier1Categories() {
    return [
      const RecommendedCategory(
        name: '房租/房贷',
        icon: Icons.home,
        suggestedPercentage: 0.25, // 略低于一线
        priority: 1,
        description: '新一线城市房租相对适中',
      ),
      const RecommendedCategory(
        name: '通勤交通',
        icon: Icons.directions_bus,
        suggestedPercentage: 0.06,
        priority: 2,
        description: '公共交通为主',
        subCategories: ['地铁', '公交', '共享单车', '网约车'],
      ),
      const RecommendedCategory(
        name: '餐饮',
        icon: Icons.restaurant,
        suggestedPercentage: 0.18,
        priority: 3,
        description: '本地餐饮价格适中',
      ),
      const RecommendedCategory(
        name: '日用品',
        icon: Icons.shopping_bag,
        suggestedPercentage: 0.05,
        priority: 4,
      ),
      const RecommendedCategory(
        name: '休闲娱乐',
        icon: Icons.sports_esports,
        suggestedPercentage: 0.10,
        priority: 5,
        description: '本地娱乐消费',
      ),
      const RecommendedCategory(
        name: '储蓄/投资',
        icon: Icons.savings,
        suggestedPercentage: 0.22,
        priority: 6,
        description: '生活成本较低，可多储蓄',
      ),
      const RecommendedCategory(
        name: '自我提升',
        icon: Icons.school,
        suggestedPercentage: 0.05,
        priority: 7,
      ),
      const RecommendedCategory(
        name: '其他',
        icon: Icons.more_horiz,
        suggestedPercentage: 0.09,
        priority: 8,
      ),
    ];
  }

  /// 二线城市推荐类目
  List<RecommendedCategory> _getTier2Categories() {
    return [
      const RecommendedCategory(
        name: '房租/房贷',
        icon: Icons.home,
        suggestedPercentage: 0.20,
        priority: 1,
        description: '二线城市住房成本较低',
      ),
      const RecommendedCategory(
        name: '餐饮',
        icon: Icons.restaurant,
        suggestedPercentage: 0.18,
        priority: 2,
        description: '日常餐饮开支',
      ),
      const RecommendedCategory(
        name: '交通出行',
        icon: Icons.directions_car,
        suggestedPercentage: 0.08,
        priority: 3,
        description: '公交/电动车/私家车',
        subCategories: ['公交', '打车', '加油', '停车'],
      ),
      const RecommendedCategory(
        name: '日用品',
        icon: Icons.shopping_cart,
        suggestedPercentage: 0.06,
        priority: 4,
      ),
      const RecommendedCategory(
        name: '休闲娱乐',
        icon: Icons.movie,
        suggestedPercentage: 0.10,
        priority: 5,
      ),
      const RecommendedCategory(
        name: '人情往来',
        icon: Icons.card_giftcard,
        suggestedPercentage: 0.06,
        priority: 6,
        description: '红包、礼品',
      ),
      const RecommendedCategory(
        name: '储蓄/投资',
        icon: Icons.savings,
        suggestedPercentage: 0.22,
        priority: 7,
      ),
      const RecommendedCategory(
        name: '其他',
        icon: Icons.more_horiz,
        suggestedPercentage: 0.10,
        priority: 8,
      ),
    ];
  }

  /// 三四线城市推荐类目（低房租、高餐饮社交）
  List<RecommendedCategory> _getTier3Categories() {
    return [
      const RecommendedCategory(
        name: '房租/房贷',
        icon: Icons.home,
        suggestedPercentage: 0.15, // 占比较低
        priority: 1,
      ),
      const RecommendedCategory(
        name: '餐饮',
        icon: Icons.restaurant,
        suggestedPercentage: 0.20, // 占比较高
        priority: 2,
        description: '家常菜馆、本地特色',
      ),
      const RecommendedCategory(
        name: '交通出行',
        icon: Icons.directions_car,
        suggestedPercentage: 0.10,
        priority: 3,
        description: '私家车/电动车为主',
        subCategories: ['加油', '停车', '保养', '电动车充电'],
      ),
      const RecommendedCategory(
        name: '休闲娱乐',
        icon: Icons.sports_esports,
        suggestedPercentage: 0.12, // 本地娱乐占比高
        priority: 4,
        description: '本地休闲场所',
      ),
      const RecommendedCategory(
        name: '人情往来',
        icon: Icons.card_giftcard,
        suggestedPercentage: 0.08,
        priority: 5,
        description: '红包、礼金、礼品',
      ),
      const RecommendedCategory(
        name: '储蓄/投资',
        icon: Icons.savings,
        suggestedPercentage: 0.25, // 生活成本低，储蓄空间大
        priority: 6,
      ),
      const RecommendedCategory(
        name: '其他',
        icon: Icons.more_horiz,
        suggestedPercentage: 0.10,
        priority: 7,
      ),
    ];
  }

  /// 海外用户特殊类目
  List<RecommendedCategory> _getOverseasCategories(CityLocation location) {
    final base = List<RecommendedCategory>.from(_getTier1Categories());

    // 添加海外特有类目
    base.addAll([
      const RecommendedCategory(
        name: '税费',
        icon: Icons.receipt_long,
        suggestedPercentage: 0.05,
        priority: 9,
        description: '消费税、服务费等',
      ),
      const RecommendedCategory(
        name: '小费',
        icon: Icons.volunteer_activism,
        suggestedPercentage: 0.03,
        priority: 10,
        description: '服务行业小费',
      ),
      const RecommendedCategory(
        name: '汇率损失',
        icon: Icons.currency_exchange,
        suggestedPercentage: 0.02,
        priority: 11,
        description: '跨境支付汇率差',
      ),
    ]);

    return base;
  }

  /// 获取类目描述
  String getCategoryDescription(String categoryName, CityTier tier) {
    final categories = getRecommendedCategories(
      CityLocation(city: '', tier: tier),
    );

    try {
      final category = categories.firstWhere((c) => c.name == categoryName);
      return category.description ?? '';
    } catch (_) {
      return '';
    }
  }
}

/// 预算金额建议
class BudgetAmountSuggestion {
  final String category;
  final double suggestedAmount;
  final double nationalAverage;
  final double localAverage;
  final String reasoning;
  final AmountRange range;

  const BudgetAmountSuggestion({
    required this.category,
    required this.suggestedAmount,
    required this.nationalAverage,
    required this.localAverage,
    required this.reasoning,
    required this.range,
  });
}

/// 金额范围
class AmountRange {
  final double min;
  final double max;

  const AmountRange({required this.min, required this.max});
}

/// 本地化预算金额建议服务
///
/// 根据城市消费水平提供金额建议
class LocalizedBudgetAmountService {
  /// 城市消费水平系数（以全国平均为1.0）
  static const Map<CityTier, double> costOfLivingIndex = {
    CityTier.tier1: 1.8, // 一线城市消费水平是全国1.8倍
    CityTier.newTier1: 1.4, // 新一线
    CityTier.tier2: 1.1, // 二线
    CityTier.tier3: 0.8, // 三四线
    CityTier.unknown: 1.0,
  };

  /// 各类目的全国平均月支出（元）
  static const Map<String, double> nationalAverageSpending = {
    '房租/房贷': 2000,
    '餐饮': 1500,
    '通勤交通': 400,
    '交通出行': 600,
    '日用品': 300,
    '社交娱乐': 500,
    '休闲娱乐': 400,
    '人情往来': 300,
    '自我提升': 200,
    '储蓄/投资': 1500,
    '其他': 400,
  };

  /// 各类目在不同收入水平下的占比调整
  static const Map<String, Map<String, double>> incomeAdjustments = {
    '房租/房贷': {
      'low': 0.35, // 低收入者住房占比更高
      'mid': 0.25,
      'high': 0.20,
    },
    '储蓄/投资': {
      'low': 0.10,
      'mid': 0.20,
      'high': 0.30, // 高收入者储蓄占比更高
    },
    '餐饮': {
      'low': 0.20,
      'mid': 0.15,
      'high': 0.12,
    },
  };

  /// 计算本地化预算建议金额
  BudgetAmountSuggestion getSuggestedAmount({
    required String category,
    required CityLocation location,
    required double monthlyIncome,
  }) {
    final coefficient = costOfLivingIndex[location.tier] ?? 1.0;
    final nationalAvg = nationalAverageSpending[category] ?? 500;

    // 基于城市系数的调整金额
    final adjustedAmount = nationalAvg * coefficient;

    // 基于收入的推荐占比
    final percentageBasedAmount = _getPercentageBasedAmount(
      category,
      monthlyIncome,
      location.tier,
    );

    // 取两者的加权平均（城市系数权重60%，收入占比权重40%）
    final suggestedAmount = adjustedAmount * 0.6 + percentageBasedAmount * 0.4;

    return BudgetAmountSuggestion(
      category: category,
      suggestedAmount: suggestedAmount.roundToDouble(),
      nationalAverage: nationalAvg,
      localAverage: adjustedAmount.roundToDouble(),
      reasoning: _generateReasoning(category, location, suggestedAmount),
      range: AmountRange(
        min: suggestedAmount * 0.7,
        max: suggestedAmount * 1.3,
      ),
    );
  }

  /// 基于收入水平的金额计算
  double _getPercentageBasedAmount(
    String category,
    double monthlyIncome,
    CityTier tier,
  ) {
    // 确定收入等级
    String incomeLevel;
    if (monthlyIncome < 8000) {
      incomeLevel = 'low';
    } else if (monthlyIncome < 20000) {
      incomeLevel = 'mid';
    } else {
      incomeLevel = 'high';
    }

    // 获取该类目在该收入等级的建议占比
    final adjustments = incomeAdjustments[category];
    if (adjustments != null && adjustments.containsKey(incomeLevel)) {
      return monthlyIncome * adjustments[incomeLevel]!;
    }

    // 使用默认占比
    final categoryService = LocalizedBudgetCategoryService();
    final categories = categoryService.getRecommendedCategories(
      CityLocation(city: '', tier: tier),
    );

    try {
      final cat = categories.firstWhere((c) => c.name == category);
      return monthlyIncome * cat.suggestedPercentage;
    } catch (_) {
      return monthlyIncome * 0.1; // 默认10%
    }
  }

  /// 生成解释文案
  String _generateReasoning(
    String category,
    CityLocation location,
    double amount,
  ) {
    final coefficient = costOfLivingIndex[location.tier] ?? 1.0;

    switch (category) {
      case '房租/房贷':
        return '${location.city}的房租水平约为全国${(coefficient * 100).toInt()}%，'
            '建议预留 ¥${amount.toStringAsFixed(0)}/月';
      case '餐饮':
        return '${location.city}餐饮人均消费约 ¥${(amount / 30).toStringAsFixed(0)}/天';
      case '通勤交通':
        return '${location.city}日均通勤成本约 ¥${(amount / 22).toStringAsFixed(0)}';
      case '储蓄/投资':
        return '建议每月储蓄 ¥${amount.toStringAsFixed(0)}，优先积累3-6个月生活费';
      default:
        return '基于${location.city}消费水平推荐';
    }
  }

  /// 获取所有类目的建议金额
  Map<String, BudgetAmountSuggestion> getAllSuggestedAmounts({
    required CityLocation location,
    required double monthlyIncome,
  }) {
    final results = <String, BudgetAmountSuggestion>{};
    final categoryService = LocalizedBudgetCategoryService();
    final categories = categoryService.getRecommendedCategories(location);

    for (final category in categories) {
      results[category.name] = getSuggestedAmount(
        category: category.name,
        location: location,
        monthlyIncome: monthlyIncome,
      );
    }

    return results;
  }

  /// 计算总预算建议
  double getTotalSuggestedBudget({
    required CityLocation location,
    required double monthlyIncome,
  }) {
    final suggestions = getAllSuggestedAmounts(
      location: location,
      monthlyIncome: monthlyIncome,
    );

    return suggestions.values
        .fold(0.0, (sum, s) => sum + s.suggestedAmount);
  }

  /// 验证预算是否合理
  BudgetValidationResult validateBudget({
    required Map<String, double> budgets,
    required CityLocation location,
    required double monthlyIncome,
  }) {
    final suggestions = getAllSuggestedAmounts(
      location: location,
      monthlyIncome: monthlyIncome,
    );

    final warnings = <String>[];
    final recommendations = <String>[];

    for (final entry in budgets.entries) {
      final category = entry.key;
      final amount = entry.value;
      final suggestion = suggestions[category];

      if (suggestion == null) continue;

      // 检查是否过高
      if (amount > suggestion.range.max * 1.5) {
        warnings.add('$category预算偏高，建议不超过 ¥${suggestion.range.max.toStringAsFixed(0)}');
      }

      // 检查是否过低（非弹性类目）
      if (category == '储蓄/投资' && amount < suggestion.range.min) {
        recommendations.add('建议增加储蓄预算至 ¥${suggestion.range.min.toStringAsFixed(0)}');
      }
    }

    // 检查总预算
    final totalBudget = budgets.values.fold(0.0, (a, b) => a + b);
    if (totalBudget > monthlyIncome) {
      warnings.add('总预算超过月收入，请调整');
    }

    return BudgetValidationResult(
      isValid: warnings.isEmpty,
      warnings: warnings,
      recommendations: recommendations,
      totalBudget: totalBudget,
      remainingIncome: monthlyIncome - totalBudget,
    );
  }
}

/// 预算验证结果
class BudgetValidationResult {
  final bool isValid;
  final List<String> warnings;
  final List<String> recommendations;
  final double totalBudget;
  final double remainingIncome;

  const BudgetValidationResult({
    required this.isValid,
    required this.warnings,
    required this.recommendations,
    required this.totalBudget,
    required this.remainingIncome,
  });
}
