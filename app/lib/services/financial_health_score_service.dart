import 'database_service.dart';

/// 得分组成部分
class ScoreComponent {
  final String name;
  final int score;
  final int maxScore;
  final String status;
  final String? tip;

  const ScoreComponent({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.status,
    this.tip,
  });

  double get percentage => maxScore > 0 ? score / maxScore : 0;

  Map<String, dynamic> toMap() => {
    'name': name,
    'score': score,
    'maxScore': maxScore,
    'status': status,
    'tip': tip,
  };
}

/// 财务健康等级
enum FinancialHealthLevel {
  /// 财务预警 (0-39分)
  warning,

  /// 需要努力 (40-59分)
  needsWork,

  /// 财务及格 (60-74分)
  passing,

  /// 财务良好 (75-89分)
  good,

  /// 财务优等生 (90-100分)
  excellent,
}

extension FinancialHealthLevelExtension on FinancialHealthLevel {
  String get displayName {
    switch (this) {
      case FinancialHealthLevel.warning:
        return '财务预警';
      case FinancialHealthLevel.needsWork:
        return '需要努力';
      case FinancialHealthLevel.passing:
        return '财务及格';
      case FinancialHealthLevel.good:
        return '财务良好';
      case FinancialHealthLevel.excellent:
        return '财务优等生';
    }
  }

  String get emoji {
    switch (this) {
      case FinancialHealthLevel.warning:
        return '🚨';
      case FinancialHealthLevel.needsWork:
        return '💪';
      case FinancialHealthLevel.passing:
        return '👍';
      case FinancialHealthLevel.good:
        return '🌟';
      case FinancialHealthLevel.excellent:
        return '🏆';
    }
  }

  String get color {
    switch (this) {
      case FinancialHealthLevel.warning:
        return '#F44336'; // Red
      case FinancialHealthLevel.needsWork:
        return '#FF9800'; // Orange
      case FinancialHealthLevel.passing:
        return '#FFC107'; // Amber
      case FinancialHealthLevel.good:
        return '#8BC34A'; // Light Green
      case FinancialHealthLevel.excellent:
        return '#4CAF50'; // Green
    }
  }
}

/// 财务健康评分
class FinancialHealthScore {
  final int totalScore;
  final int maxScore;
  final double percentage;
  final FinancialHealthLevel level;
  final Map<String, ScoreComponent> components;
  final ScoreComponent? primaryImprovementArea;
  final int comparisonToLastMonth;
  final DateTime calculatedAt;

  const FinancialHealthScore({
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.level,
    required this.components,
    this.primaryImprovementArea,
    this.comparisonToLastMonth = 0,
    required this.calculatedAt,
  });

  Map<String, dynamic> toMap() => {
    'totalScore': totalScore,
    'maxScore': maxScore,
    'percentage': percentage,
    'level': level.index,
    'components': components.map((k, v) => MapEntry(k, v.toMap())),
    'primaryImprovementArea': primaryImprovementArea?.toMap(),
    'comparisonToLastMonth': comparisonToLastMonth,
    'calculatedAt': calculatedAt.millisecondsSinceEpoch,
  };
}

/// 财务健康评分服务
///
/// 计算用户的综合财务健康分数（满分100分），包含五个维度：
/// - 钱龄得分（0-20分）：反映资金的时间价值管理能力
/// - 预算控制得分（0-20分）：反映预算执行力
/// - 应急金得分（0-20分）：反映财务抗风险能力
/// - 消费结构得分（0-20分）：反映消费合理性
/// - 记账习惯得分（0-20分）：反映财务管理习惯
class FinancialHealthScoreService {
  final DatabaseService _db;

  FinancialHealthScoreService(this._db);

  /// 计算综合财务健康分
  Future<FinancialHealthScore> calculateScore() async {
    final scores = <String, ScoreComponent>{};

    // 1. 钱龄得分（0-20分）
    final moneyAge = await _getCurrentMoneyAge();
    scores['moneyAge'] = ScoreComponent(
      name: '钱龄',
      score: _scoreMoneyAge(moneyAge),
      maxScore: 20,
      status: _getMoneyAgeStatus(moneyAge),
      tip: _getMoneyAgeTip(moneyAge),
    );

    // 2. 预算控制得分（0-20分）
    final budgetAdherence = await _getBudgetAdherence();
    scores['budget'] = ScoreComponent(
      name: '预算控制',
      score: _scoreBudgetAdherence(budgetAdherence),
      maxScore: 20,
      status: budgetAdherence > 0.9 ? '优秀' : budgetAdherence > 0.7 ? '良好' : '需改进',
      tip: budgetAdherence < 0.7 ? '建议审视超支分类，调整预算或消费习惯' : null,
    );

    // 3. 应急金得分（0-20分）
    final emergencyProgress = await _getEmergencyFundProgress();
    scores['emergency'] = ScoreComponent(
      name: '应急金',
      score: (emergencyProgress * 20).round().clamp(0, 20),
      maxScore: 20,
      status: emergencyProgress >= 1 ? '达标' : '建设中',
      tip: emergencyProgress < 0.5 ? '建议优先积累应急金' : null,
    );

    // 4. 消费结构得分（0-20分）
    final structureScore = await _getSpendingStructureScore();
    scores['structure'] = ScoreComponent(
      name: '消费结构',
      score: structureScore.score,
      maxScore: 20,
      status: structureScore.score > 16 ? '健康' : '待优化',
      tip: structureScore.tip,
    );

    // 5. 记账习惯得分（0-20分）
    final habitScore = await _getRecordingHabitScore();
    scores['habit'] = ScoreComponent(
      name: '记账习惯',
      score: habitScore.score,
      maxScore: 20,
      status: habitScore.score >= 16 ? '坚持中' : '需加油',
      tip: habitScore.tip,
    );

    // 计算总分
    final totalScore = scores.values.fold(0, (sum, c) => sum + c.score);
    final maxScore = scores.values.fold(0, (sum, c) => sum + c.maxScore);

    // 找出最弱的领域
    final weakestArea = _findWeakestArea(scores);

    // 与上月对比
    final comparison = await _compareToLastMonth(totalScore);

    return FinancialHealthScore(
      totalScore: totalScore,
      maxScore: maxScore,
      percentage: maxScore > 0 ? totalScore / maxScore : 0,
      level: _getLevel(totalScore),
      components: scores,
      primaryImprovementArea: weakestArea,
      comparisonToLastMonth: comparison,
      calculatedAt: DateTime.now(),
    );
  }

  /// 获取当前钱龄（天）
  Future<int> _getCurrentMoneyAge() async {
    try {
      final result = await _db.rawQuery('''
        SELECT AVG(money_age_days) as avg_age
        FROM money_age_daily
        WHERE date >= date('now', '-30 days')
      ''');

      if (result.isNotEmpty && result.first['avg_age'] != null) {
        return (result.first['avg_age'] as num).round();
      }
    } catch (e) {
      // 表可能不存在
    }
    return 0;
  }

  /// 钱龄评分
  int _scoreMoneyAge(int days) {
    if (days >= 60) return 20;
    if (days >= 30) return 16;
    if (days >= 14) return 12;
    if (days >= 7) return 8;
    return (days * 8 / 7).round().clamp(0, 8);
  }

  /// 获取钱龄状态描述
  String _getMoneyAgeStatus(int days) {
    if (days >= 60) return '理想';
    if (days >= 30) return '良好';
    if (days >= 14) return '一般';
    if (days >= 7) return '警告';
    return '危险';
  }

  /// 获取钱龄改进建议
  String? _getMoneyAgeTip(int days) {
    if (days >= 30) return null;
    if (days >= 14) return '继续保持，距离良好状态还需${30 - days}天';
    if (days >= 7) return '建议控制支出，提升钱龄';
    return '钱龄过短，需要优先建立财务缓冲';
  }

  /// 获取预算执行率
  Future<double> _getBudgetAdherence() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final result = await _db.rawQuery('''
        SELECT
          SUM(CASE WHEN spent <= amount THEN 1 ELSE 0 END) as within_budget,
          COUNT(*) as total
        FROM budget_vaults
        WHERE is_active = 1
          AND period_start <= ?
          AND period_end >= ?
      ''', [now.millisecondsSinceEpoch, monthStart.millisecondsSinceEpoch]);

      if (result.isNotEmpty && result.first['total'] != null) {
        final total = (result.first['total'] as num).toInt();
        if (total > 0) {
          final withinBudget = (result.first['within_budget'] as num?)?.toInt() ?? 0;
          return withinBudget / total;
        }
      }
    } catch (e) {
      // 表可能不存在
    }
    return 0.8; // 默认值
  }

  /// 预算执行率评分
  int _scoreBudgetAdherence(double adherence) {
    if (adherence >= 0.95) return 20;
    if (adherence >= 0.9) return 18;
    if (adherence >= 0.8) return 15;
    if (adherence >= 0.7) return 12;
    if (adherence >= 0.6) return 8;
    return (adherence * 13).round().clamp(0, 8);
  }

  /// 获取应急金进度
  Future<double> _getEmergencyFundProgress() async {
    try {
      final result = await _db.rawQuery('''
        SELECT
          current_amount,
          target_amount
        FROM financial_buffers
        WHERE buffer_type = 'emergency'
          AND is_active = 1
        ORDER BY created_at DESC
        LIMIT 1
      ''');

      if (result.isNotEmpty) {
        final current = (result.first['current_amount'] as num?)?.toDouble() ?? 0;
        final target = (result.first['target_amount'] as num?)?.toDouble() ?? 1;
        if (target > 0) {
          return (current / target).clamp(0.0, 1.5); // 最多1.5倍
        }
      }
    } catch (e) {
      // 表可能不存在
    }
    return 0;
  }

  /// 获取消费结构得分
  Future<({int score, String? tip})> _getSpendingStructureScore() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      // 分析必要消费 vs 可选消费比例
      final result = await _db.rawQuery('''
        SELECT
          SUM(CASE WHEN c.is_essential = 1 THEN t.amount ELSE 0 END) as essential,
          SUM(CASE WHEN c.is_essential = 0 THEN t.amount ELSE 0 END) as optional,
          SUM(t.amount) as total
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.type = 'expense'
          AND t.transaction_date >= ?
      ''', [monthStart.millisecondsSinceEpoch]);

      if (result.isNotEmpty && result.first['total'] != null) {
        final total = (result.first['total'] as num).toDouble();
        if (total > 0) {
          final optional = (result.first['optional'] as num?)?.toDouble() ?? 0;
          final optionalRatio = optional / total;

          // 可选消费比例评分：30%以下=20分，30-50%=15分，50-70%=10分，70%以上=5分
          if (optionalRatio <= 0.3) {
            return (score: 20, tip: null);
          } else if (optionalRatio <= 0.5) {
            return (score: 15, tip: '可选消费占比${(optionalRatio * 100).toStringAsFixed(0)}%，建议控制在30%以内');
          } else if (optionalRatio <= 0.7) {
            return (score: 10, tip: '可选消费占比较高，建议优化消费结构');
          } else {
            return (score: 5, tip: '可选消费占比过高，需要重点改善');
          }
        }
      }
    } catch (e) {
      // 表可能不存在或字段不存在
    }

    // 默认基于交易分类的估算
    return (score: 12, tip: null);
  }

  /// 获取记账习惯得分
  Future<({int score, String? tip})> _getRecordingHabitScore() async {
    try {
      // 获取连续记账天数
      final streakResult = await _db.rawQuery('''
        SELECT current_streak, longest_streak
        FROM user_streaks
        ORDER BY updated_at DESC
        LIMIT 1
      ''');

      int currentStreak = 0;
      if (streakResult.isNotEmpty) {
        currentStreak = (streakResult.first['current_streak'] as num?)?.toInt() ?? 0;
      }

      // 获取最近30天的记账天数
      final consistencyResult = await _db.rawQuery('''
        SELECT COUNT(DISTINCT date(transaction_date / 1000, 'unixepoch')) as days
        FROM transactions
        WHERE transaction_date >= ?
      ''', [DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch]);

      int recordingDays = 0;
      if (consistencyResult.isNotEmpty) {
        recordingDays = (consistencyResult.first['days'] as num?)?.toInt() ?? 0;
      }

      // 综合评分：连续天数(60%) + 30天覆盖率(40%)
      final streakScore = _scoreStreak(currentStreak) * 0.6;
      final consistencyScore = (recordingDays / 30 * 20).clamp(0.0, 20.0) * 0.4;
      final totalHabitScore = (streakScore + consistencyScore).round().clamp(0, 20);

      String? tip;
      if (currentStreak < 7) {
        tip = '养成每日记账习惯是财务管理的基础';
      } else if (currentStreak < 30) {
        tip = '继续保持，连续记账$currentStreak天';
      }

      return (score: totalHabitScore, tip: tip);
    } catch (e) {
      // 表可能不存在
    }
    return (score: 10, tip: '开始养成记账习惯吧');
  }

  /// 连续记账评分
  int _scoreStreak(int days) {
    if (days >= 100) return 20;
    if (days >= 30) return 18;
    if (days >= 14) return 14;
    if (days >= 7) return 10;
    if (days >= 3) return 6;
    return days * 2;
  }

  /// 获取财务健康等级
  FinancialHealthLevel _getLevel(int score) {
    if (score >= 90) return FinancialHealthLevel.excellent;
    if (score >= 75) return FinancialHealthLevel.good;
    if (score >= 60) return FinancialHealthLevel.passing;
    if (score >= 40) return FinancialHealthLevel.needsWork;
    return FinancialHealthLevel.warning;
  }

  /// 找出最弱的领域
  ScoreComponent? _findWeakestArea(Map<String, ScoreComponent> scores) {
    if (scores.isEmpty) return null;

    ScoreComponent? weakest;
    double lowestPercentage = 1.0;

    for (final component in scores.values) {
      final percentage = component.percentage;
      if (percentage < lowestPercentage) {
        lowestPercentage = percentage;
        weakest = component;
      }
    }

    // 只有在得分低于80%时才返回改进建议
    if (lowestPercentage < 0.8) {
      return weakest;
    }
    return null;
  }

  /// 与上月对比
  Future<int> _compareToLastMonth(int currentScore) async {
    try {
      final lastMonth = DateTime.now().subtract(const Duration(days: 30));
      final result = await _db.rawQuery('''
        SELECT total_score
        FROM financial_health_history
        WHERE calculated_at >= ? AND calculated_at < ?
        ORDER BY calculated_at DESC
        LIMIT 1
      ''', [
        DateTime(lastMonth.year, lastMonth.month, 1).millisecondsSinceEpoch,
        DateTime(lastMonth.year, lastMonth.month + 1, 1).millisecondsSinceEpoch,
      ]);

      if (result.isNotEmpty && result.first['total_score'] != null) {
        final lastScore = (result.first['total_score'] as num).toInt();
        return currentScore - lastScore;
      }
    } catch (e) {
      // 表可能不存在
    }
    return 0;
  }

  /// 保存评分历史
  Future<void> saveScoreHistory(FinancialHealthScore score) async {
    await _db.rawInsert('''
      INSERT INTO financial_health_history (
        total_score, max_score, level, calculated_at
      ) VALUES (?, ?, ?, ?)
    ''', [
      score.totalScore,
      score.maxScore,
      score.level.index,
      score.calculatedAt.millisecondsSinceEpoch,
    ]);
  }

  /// 获取历史评分趋势
  Future<List<({DateTime date, int score})>> getScoreHistory({
    int months = 6,
  }) async {
    final results = <({DateTime date, int score})>[];

    try {
      final startDate = DateTime.now().subtract(Duration(days: months * 30));
      final queryResult = await _db.rawQuery('''
        SELECT total_score, calculated_at
        FROM financial_health_history
        WHERE calculated_at >= ?
        ORDER BY calculated_at ASC
      ''', [startDate.millisecondsSinceEpoch]);

      for (final row in queryResult) {
        results.add((
          date: DateTime.fromMillisecondsSinceEpoch(row['calculated_at'] as int),
          score: (row['total_score'] as num).toInt(),
        ));
      }
    } catch (e) {
      // 表可能不存在
    }

    return results;
  }

  /// 获取改进建议列表
  Future<List<String>> getImprovementSuggestions(FinancialHealthScore score) async {
    final suggestions = <String>[];

    for (final component in score.components.values) {
      if (component.percentage < 0.6 && component.tip != null) {
        suggestions.add('${component.name}：${component.tip}');
      }
    }

    // 添加基于等级的通用建议
    switch (score.level) {
      case FinancialHealthLevel.warning:
        suggestions.add('建议立即建立应急金，控制非必要支出');
        break;
      case FinancialHealthLevel.needsWork:
        suggestions.add('持续记账并关注预算执行情况');
        break;
      case FinancialHealthLevel.passing:
        suggestions.add('财务状况良好，可以开始考虑中长期财务目标');
        break;
      case FinancialHealthLevel.good:
      case FinancialHealthLevel.excellent:
        // 无需额外建议
        break;
    }

    return suggestions;
  }
}
