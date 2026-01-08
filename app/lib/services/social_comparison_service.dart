import 'database_service.dart';

/// 用户画像标签
enum UserProfileTag {
  /// 学生
  student,

  /// 职场新人
  youngProfessional,

  /// 中层白领
  midCareer,

  /// 高收入人群
  highIncome,

  /// 家庭用户
  familyUser,

  /// 自由职业者
  freelancer,

  /// 退休人士
  retired,
}

extension UserProfileTagExtension on UserProfileTag {
  String get displayName {
    switch (this) {
      case UserProfileTag.student:
        return '学生';
      case UserProfileTag.youngProfessional:
        return '职场新人';
      case UserProfileTag.midCareer:
        return '中层白领';
      case UserProfileTag.highIncome:
        return '高收入人群';
      case UserProfileTag.familyUser:
        return '家庭用户';
      case UserProfileTag.freelancer:
        return '自由职业者';
      case UserProfileTag.retired:
        return '退休人士';
    }
  }
}

/// 消费水平
enum SpendingLevel {
  /// 节俭型
  frugal,

  /// 经济型
  economical,

  /// 适中型
  moderate,

  /// 品质型
  quality,

  /// 奢华型
  luxury,
}

extension SpendingLevelExtension on SpendingLevel {
  String get displayName {
    switch (this) {
      case SpendingLevel.frugal:
        return '节俭型';
      case SpendingLevel.economical:
        return '经济型';
      case SpendingLevel.moderate:
        return '适中型';
      case SpendingLevel.quality:
        return '品质型';
      case SpendingLevel.luxury:
        return '奢华型';
    }
  }
}

/// 同类用户基准数据
class PeerBenchmark {
  final UserProfileTag profileTag;
  final String city;
  final double avgMonthlyIncome;
  final double avgMonthlyExpense;
  final double avgSavingsRate;
  final Map<String, double> categoryBenchmarks; // 各类别平均支出
  final double avgMoneyAge;
  final int sampleSize;

  const PeerBenchmark({
    required this.profileTag,
    required this.city,
    required this.avgMonthlyIncome,
    required this.avgMonthlyExpense,
    required this.avgSavingsRate,
    required this.categoryBenchmarks,
    required this.avgMoneyAge,
    required this.sampleSize,
  });
}

/// 用户排名信息
class UserRanking {
  final String dimension; // 排名维度
  final double userValue;
  final double avgValue;
  final double topValue;
  final int percentile; // 百分位（0-100，100表示最优）
  final String description;
  final bool isPositive; // 排名靠前是否为正面

  const UserRanking({
    required this.dimension,
    required this.userValue,
    required this.avgValue,
    required this.topValue,
    required this.percentile,
    required this.description,
    required this.isPositive,
  });

  bool get isBetterThanAverage =>
      isPositive ? userValue > avgValue : userValue < avgValue;
  bool get isTopQuartile => percentile >= 75;
}

/// 对比洞察
class ComparisonInsight {
  final String title;
  final String description;
  final double difference; // 与平均值的差异百分比
  final bool isPositive;
  final String suggestion;
  final String category;

  const ComparisonInsight({
    required this.title,
    required this.description,
    required this.difference,
    required this.isPositive,
    required this.suggestion,
    required this.category,
  });
}

/// 社会认同参照服务
///
/// 利用社会比较心理提供财务激励：
/// - 同类用户消费对比
/// - 匿名排名展示
/// - 正向激励（超过平均水平）
/// - 改善建议（低于平均水平）
class SocialComparisonService {
  final DatabaseService _db;

  SocialComparisonService(this._db);

  /// 预定义的基准数据（基于城市和用户类型）
  /// 实际应用中可从服务端获取
  static final Map<String, Map<UserProfileTag, PeerBenchmark>> _benchmarkData = {
    '一线城市': {
      UserProfileTag.student: PeerBenchmark(
        profileTag: UserProfileTag.student,
        city: '一线城市',
        avgMonthlyIncome: 2000,
        avgMonthlyExpense: 1800,
        avgSavingsRate: 0.1,
        categoryBenchmarks: {
          'food': 800,
          'transport': 200,
          'entertainment': 300,
          'shopping': 300,
          'education': 200,
        },
        avgMoneyAge: 5,
        sampleSize: 10000,
      ),
      UserProfileTag.youngProfessional: PeerBenchmark(
        profileTag: UserProfileTag.youngProfessional,
        city: '一线城市',
        avgMonthlyIncome: 12000,
        avgMonthlyExpense: 8000,
        avgSavingsRate: 0.33,
        categoryBenchmarks: {
          'food': 2500,
          'transport': 800,
          'entertainment': 1000,
          'shopping': 1500,
          'housing': 2200,
        },
        avgMoneyAge: 12,
        sampleSize: 50000,
      ),
      UserProfileTag.midCareer: PeerBenchmark(
        profileTag: UserProfileTag.midCareer,
        city: '一线城市',
        avgMonthlyIncome: 25000,
        avgMonthlyExpense: 15000,
        avgSavingsRate: 0.4,
        categoryBenchmarks: {
          'food': 4000,
          'transport': 1500,
          'entertainment': 2000,
          'shopping': 3000,
          'housing': 4500,
        },
        avgMoneyAge: 18,
        sampleSize: 30000,
      ),
    },
    '二线城市': {
      UserProfileTag.student: PeerBenchmark(
        profileTag: UserProfileTag.student,
        city: '二线城市',
        avgMonthlyIncome: 1500,
        avgMonthlyExpense: 1300,
        avgSavingsRate: 0.13,
        categoryBenchmarks: {
          'food': 600,
          'transport': 150,
          'entertainment': 200,
          'shopping': 200,
          'education': 150,
        },
        avgMoneyAge: 6,
        sampleSize: 8000,
      ),
      UserProfileTag.youngProfessional: PeerBenchmark(
        profileTag: UserProfileTag.youngProfessional,
        city: '二线城市',
        avgMonthlyIncome: 8000,
        avgMonthlyExpense: 5000,
        avgSavingsRate: 0.375,
        categoryBenchmarks: {
          'food': 1800,
          'transport': 500,
          'entertainment': 600,
          'shopping': 1000,
          'housing': 1100,
        },
        avgMoneyAge: 15,
        sampleSize: 40000,
      ),
    },
  };

  /// 获取用户画像标签
  Future<UserProfileTag> inferUserProfile() async {
    // 基于用户消费数据推断画像
    final monthlyStats = await _getMonthlyStats(months: 3);

    if (monthlyStats['avgIncome'] == null) {
      return UserProfileTag.youngProfessional; // 默认值
    }

    final avgIncome = monthlyStats['avgIncome'] as double;
    final avgExpense = monthlyStats['avgExpense'] as double;

    // 简单的画像推断逻辑
    if (avgIncome < 3000) {
      return UserProfileTag.student;
    } else if (avgIncome < 15000) {
      return UserProfileTag.youngProfessional;
    } else if (avgIncome < 30000) {
      return UserProfileTag.midCareer;
    } else {
      return UserProfileTag.highIncome;
    }
  }

  /// 获取同类用户基准
  Future<PeerBenchmark?> getPeerBenchmark({
    String? city,
    UserProfileTag? profileTag,
  }) async {
    final profile = profileTag ?? await inferUserProfile();
    final userCity = city ?? '一线城市'; // 默认或从用户设置获取

    final cityData = _benchmarkData[userCity] ?? _benchmarkData['一线城市'];
    return cityData?[profile];
  }

  /// 获取用户排名
  Future<List<UserRanking>> getUserRankings() async {
    final rankings = <UserRanking>[];
    final benchmark = await getPeerBenchmark();
    if (benchmark == null) return rankings;

    final userStats = await _getMonthlyStats(months: 3);

    // 1. 储蓄率排名
    final userSavingsRate = userStats['savingsRate'] as double? ?? 0;
    rankings.add(UserRanking(
      dimension: '储蓄率',
      userValue: userSavingsRate * 100,
      avgValue: benchmark.avgSavingsRate * 100,
      topValue: 50, // 假设前10%储蓄率为50%
      percentile: _calculatePercentile(
        userSavingsRate,
        benchmark.avgSavingsRate,
        0.5,
        true,
      ),
      description: '您的储蓄率${(userSavingsRate * 100).toStringAsFixed(1)}%',
      isPositive: true,
    ));

    // 2. 钱龄排名
    final userMoneyAge = userStats['avgMoneyAge'] as double? ?? 0;
    rankings.add(UserRanking(
      dimension: '平均钱龄',
      userValue: userMoneyAge,
      avgValue: benchmark.avgMoneyAge,
      topValue: 30,
      percentile: _calculatePercentile(
        userMoneyAge,
        benchmark.avgMoneyAge,
        30,
        true,
      ),
      description: '您的平均钱龄${userMoneyAge.toStringAsFixed(1)}天',
      isPositive: true,
    ));

    // 3. 餐饮支出排名（越低越好）
    final userFoodExpense = userStats['foodExpense'] as double? ?? 0;
    final avgFoodExpense = benchmark.categoryBenchmarks['food'] ?? 0;
    rankings.add(UserRanking(
      dimension: '餐饮支出',
      userValue: userFoodExpense,
      avgValue: avgFoodExpense,
      topValue: avgFoodExpense * 0.6,
      percentile: _calculatePercentile(
        userFoodExpense,
        avgFoodExpense,
        avgFoodExpense * 0.6,
        false,
      ),
      description: '您的餐饮支出￥${userFoodExpense.toStringAsFixed(0)}',
      isPositive: false,
    ));

    // 4. 记账连续性排名
    final recordingDays = userStats['recordingDays'] as int? ?? 0;
    rankings.add(UserRanking(
      dimension: '记账坚持',
      userValue: recordingDays.toDouble(),
      avgValue: 15,
      topValue: 28,
      percentile: _calculatePercentile(recordingDays.toDouble(), 15, 28, true),
      description: '本月记账$recordingDays天',
      isPositive: true,
    ));

    return rankings;
  }

  /// 获取对比洞察
  Future<List<ComparisonInsight>> getComparisonInsights() async {
    final insights = <ComparisonInsight>[];
    final benchmark = await getPeerBenchmark();
    if (benchmark == null) return insights;

    final userStats = await _getMonthlyStats(months: 1);

    // 分析各类别支出
    for (final entry in benchmark.categoryBenchmarks.entries) {
      final category = entry.key;
      final avgAmount = entry.value;
      final userAmount = userStats['${category}Expense'] as double? ?? 0;

      if (userAmount == 0) continue;

      final difference = (userAmount - avgAmount) / avgAmount;

      if (difference.abs() > 0.2) {
        // 差异超过20%才生成洞察
        insights.add(ComparisonInsight(
          title: _getCategoryDisplayName(category),
          description: difference > 0
              ? '您的${_getCategoryDisplayName(category)}支出比同类用户高${(difference * 100).toStringAsFixed(0)}%'
              : '您的${_getCategoryDisplayName(category)}支出比同类用户低${(-difference * 100).toStringAsFixed(0)}%',
          difference: difference,
          isPositive: difference < 0,
          suggestion: difference > 0
              ? '可以关注同类型消费的优化空间'
              : '继续保持良好的消费习惯',
          category: category,
        ));
      }
    }

    // 按差异绝对值排序
    insights.sort((a, b) => b.difference.abs().compareTo(a.difference.abs()));

    return insights.take(5).toList();
  }

  /// 获取消费水平评估
  Future<SpendingLevel> getSpendingLevel() async {
    final benchmark = await getPeerBenchmark();
    if (benchmark == null) return SpendingLevel.moderate;

    final userStats = await _getMonthlyStats(months: 3);
    final userExpense = userStats['avgExpense'] as double? ?? 0;
    final avgExpense = benchmark.avgMonthlyExpense;

    final ratio = userExpense / avgExpense;

    if (ratio < 0.6) {
      return SpendingLevel.frugal;
    } else if (ratio < 0.85) {
      return SpendingLevel.economical;
    } else if (ratio < 1.15) {
      return SpendingLevel.moderate;
    } else if (ratio < 1.5) {
      return SpendingLevel.quality;
    } else {
      return SpendingLevel.luxury;
    }
  }

  /// 获取正向激励消息
  Future<List<String>> getPositiveMessages() async {
    final messages = <String>[];
    final rankings = await getUserRankings();

    for (final ranking in rankings) {
      if (ranking.isTopQuartile) {
        messages.add(_generatePositiveMessage(ranking));
      }
    }

    // 如果没有特别突出的排名，给出鼓励消息
    if (messages.isEmpty) {
      messages.add('您正在养成良好的记账习惯，继续坚持！');
    }

    return messages;
  }

  /// 获取改善建议
  Future<List<String>> getImprovementSuggestions() async {
    final suggestions = <String>[];
    final insights = await getComparisonInsights();

    for (final insight in insights) {
      if (!insight.isPositive) {
        suggestions.add(insight.suggestion);
      }
    }

    return suggestions;
  }

  /// 生成社交分享内容
  Future<Map<String, dynamic>> generateShareContent() async {
    final rankings = await getUserRankings();
    final bestRanking = rankings.isEmpty
        ? null
        : rankings.reduce((a, b) => a.percentile > b.percentile ? a : b);

    final profile = await inferUserProfile();
    final level = await getSpendingLevel();

    return {
      'title': '我的财务健康报告',
      'subtitle': '${profile.displayName} · ${level.displayName}消费者',
      'highlight': bestRanking != null
          ? '${bestRanking.dimension}超过${bestRanking.percentile}%的同类用户'
          : '正在培养良好的财务习惯',
      'rankings': rankings.map((r) => {
            'dimension': r.dimension,
            'percentile': r.percentile,
            'value': r.userValue,
          }).toList(),
      'encouragement': _getShareEncouragement(bestRanking?.percentile ?? 50),
    };
  }

  // 私有方法

  Future<Map<String, dynamic>> _getMonthlyStats({int months = 1}) async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month - months + 1, 1);

    // 获取收入
    final incomeResult = await _db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE date >= ? AND type = 'income'
    ''', [since.millisecondsSinceEpoch]);
    final totalIncome = (incomeResult.first['total'] as num?)?.toDouble() ?? 0;

    // 获取支出
    final expenseResult = await _db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE date >= ? AND type = 'expense'
    ''', [since.millisecondsSinceEpoch]);
    final totalExpense = (expenseResult.first['total'] as num?)?.toDouble() ?? 0;

    // 获取餐饮支出
    final foodResult = await _db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE date >= ? AND type = 'expense' AND categoryId LIKE '%food%'
    ''', [since.millisecondsSinceEpoch]);
    final foodExpense = (foodResult.first['total'] as num?)?.toDouble() ?? 0;

    // 获取平均钱龄
    final moneyAgeResult = await _db.rawQuery('''
      SELECT AVG(moneyAge) as avg FROM transactions
      WHERE date >= ? AND type = 'expense' AND moneyAge > 0
    ''', [since.millisecondsSinceEpoch]);
    final avgMoneyAge = (moneyAgeResult.first['avg'] as num?)?.toDouble() ?? 0;

    // 获取记账天数
    final recordingDaysResult = await _db.rawQuery('''
      SELECT COUNT(DISTINCT date(date/1000, 'unixepoch')) as days
      FROM transactions WHERE date >= ?
    ''', [since.millisecondsSinceEpoch]);
    final recordingDays = (recordingDaysResult.first['days'] as int?) ?? 0;

    final avgIncome = totalIncome / months;
    final avgExpense = totalExpense / months;
    final savingsRate = avgIncome > 0 ? (avgIncome - avgExpense) / avgIncome : 0;

    return {
      'avgIncome': avgIncome,
      'avgExpense': avgExpense,
      'savingsRate': savingsRate.clamp(0, 1),
      'foodExpense': foodExpense / months,
      'avgMoneyAge': avgMoneyAge,
      'recordingDays': recordingDays,
    };
  }

  int _calculatePercentile(
    double userValue,
    double avgValue,
    double topValue,
    bool higherIsBetter,
  ) {
    if (higherIsBetter) {
      if (userValue >= topValue) return 95;
      if (userValue >= avgValue) {
        return 50 + ((userValue - avgValue) / (topValue - avgValue) * 45).round();
      }
      return (userValue / avgValue * 50).round().clamp(5, 50);
    } else {
      if (userValue <= topValue) return 95;
      if (userValue <= avgValue) {
        return 50 + ((avgValue - userValue) / (avgValue - topValue) * 45).round();
      }
      return (avgValue / userValue * 50).round().clamp(5, 50);
    }
  }

  String _getCategoryDisplayName(String category) {
    const names = {
      'food': '餐饮',
      'transport': '交通',
      'entertainment': '娱乐',
      'shopping': '购物',
      'housing': '居住',
      'education': '教育',
    };
    return names[category] ?? category;
  }

  String _generatePositiveMessage(UserRanking ranking) {
    if (ranking.percentile >= 90) {
      return '太棒了！您的${ranking.dimension}超过了${ranking.percentile}%的同类用户，堪称理财达人！';
    } else if (ranking.percentile >= 75) {
      return '做得很好！您的${ranking.dimension}优于${ranking.percentile}%的同类用户';
    }
    return '您的${ranking.dimension}表现不错，继续保持！';
  }

  String _getShareEncouragement(int percentile) {
    if (percentile >= 90) {
      return '理财达人，值得学习！';
    } else if (percentile >= 75) {
      return '财务健康，继续保持！';
    } else if (percentile >= 50) {
      return '稳步前进，未来可期！';
    }
    return '正在努力，一起加油！';
  }
}
