import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'financial_health_score_service.dart';

/// 目标类型
enum GoalType {
  /// 钱龄健康
  moneyAgeHealth,

  /// 预算执行
  budgetExecution,

  /// 记账习惯
  recordingHabit,

  /// 储蓄目标
  savingsGoal,
}

extension GoalTypeExtension on GoalType {
  String get displayName {
    switch (this) {
      case GoalType.moneyAgeHealth:
        return '钱龄健康';
      case GoalType.budgetExecution:
        return '预算执行';
      case GoalType.recordingHabit:
        return '记账习惯';
      case GoalType.savingsGoal:
        return '储蓄目标';
    }
  }

  String get description {
    switch (this) {
      case GoalType.moneyAgeHealth:
        return '保持钱龄在健康区间';
      case GoalType.budgetExecution:
        return '控制支出在预算内';
      case GoalType.recordingHabit:
        return '养成每日记账习惯';
      case GoalType.savingsGoal:
        return '达成月度储蓄目标';
    }
  }

  String get iconName {
    switch (this) {
      case GoalType.moneyAgeHealth:
        return 'schedule';
      case GoalType.budgetExecution:
        return 'account_balance_wallet';
      case GoalType.recordingHabit:
        return 'edit_note';
      case GoalType.savingsGoal:
        return 'savings';
    }
  }
}

/// 单个目标的达成情况
class GoalAchievement {
  final GoalType type;
  final double currentValue;
  final double targetValue;
  final double achievementRate;
  final String status;
  final String? tip;
  final DateTime lastUpdated;

  const GoalAchievement({
    required this.type,
    required this.currentValue,
    required this.targetValue,
    required this.achievementRate,
    required this.status,
    this.tip,
    required this.lastUpdated,
  });

  bool get isAchieved => achievementRate >= 1.0;

  String get statusLevel {
    if (achievementRate >= 1.0) return 'excellent';
    if (achievementRate >= 0.8) return 'good';
    if (achievementRate >= 0.6) return 'fair';
    return 'needsWork';
  }
}

/// 总体目标达成概览
class GoalAchievementOverview {
  final double overallRate;
  final int achievedCount;
  final int totalGoals;
  final List<GoalAchievement> goals;
  final int healthScore;
  final int monthlyProgress;
  final DateTime calculatedAt;

  const GoalAchievementOverview({
    required this.overallRate,
    required this.achievedCount,
    required this.totalGoals,
    required this.goals,
    required this.healthScore,
    required this.monthlyProgress,
    required this.calculatedAt,
  });

  String get overallStatus {
    if (overallRate >= 0.9) return '非常出色';
    if (overallRate >= 0.75) return '表现良好';
    if (overallRate >= 0.6) return '继续努力';
    return '需要加油';
  }
}

/// 目标达成服务
///
/// 追踪和计算用户在各个财务目标上的达成情况
class GoalAchievementService {
  final FinancialHealthScoreService _healthService;

  GoalAchievementService(DatabaseService db)
      : _healthService = FinancialHealthScoreService(db);

  /// 获取目标达成概览
  Future<GoalAchievementOverview> getOverview() async {
    final goals = <GoalAchievement>[];

    // 1. 钱龄健康目标
    final moneyAgeGoal = await _calculateMoneyAgeGoal();
    goals.add(moneyAgeGoal);

    // 2. 预算执行目标
    final budgetGoal = await _calculateBudgetGoal();
    goals.add(budgetGoal);

    // 3. 记账习惯目标
    final habitGoal = await _calculateRecordingHabitGoal();
    goals.add(habitGoal);

    // 4. 储蓄目标
    final savingsGoal = await _calculateSavingsGoal();
    goals.add(savingsGoal);

    // 计算总体达成率
    final overallRate = goals.isEmpty
        ? 0.0
        : goals.fold(0.0, (sum, g) => sum + g.achievementRate) / goals.length;

    final achievedCount = goals.where((g) => g.isAchieved).length;

    // 获取健康分数
    final healthScore = await _healthService.calculateScore();

    // 计算月度进展（模拟数据）
    final monthlyProgress = 5; // TODO: 从历史数据计算

    return GoalAchievementOverview(
      overallRate: overallRate.clamp(0.0, 1.0),
      achievedCount: achievedCount,
      totalGoals: goals.length,
      goals: goals,
      healthScore: healthScore.totalScore,
      monthlyProgress: monthlyProgress,
      calculatedAt: DateTime.now(),
    );
  }

  /// 计算钱龄健康目标
  Future<GoalAchievement> _calculateMoneyAgeGoal() async {
    try {
      // 目标：钱龄达到30天
      const targetDays = 30.0;

      // TODO: 从资源池计算实际钱龄
      // 暂时使用模拟数据
      const currentAge = 25.0;

      final rate = (currentAge / targetDays).clamp(0.0, 1.5);

      String status;
      String? tip;
      if (rate >= 1.0) {
        status = '达标';
      } else if (rate >= 0.5) {
        status = '${currentAge.toStringAsFixed(0)}天';
        tip = '距离目标还需${(targetDays - currentAge).toStringAsFixed(0)}天';
      } else {
        status = '需提升';
        tip = '建议控制支出，延长资金持有时间';
      }

      return GoalAchievement(
        type: GoalType.moneyAgeHealth,
        currentValue: currentAge,
        targetValue: targetDays,
        achievementRate: rate.clamp(0.0, 1.0),
        status: status,
        tip: tip,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Calculate money age goal error: $e');
      return GoalAchievement(
        type: GoalType.moneyAgeHealth,
        currentValue: 0,
        targetValue: 30,
        achievementRate: 0,
        status: '暂无数据',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 计算预算执行目标
  Future<GoalAchievement> _calculateBudgetGoal() async {
    try {
      // TODO: 从预算表计算实际执行情况
      // 暂时使用模拟数据
      const total = 5;
      const withinBudget = 4;

      final rate = total > 0 ? withinBudget / total : 1.0;

      String status;
      String? tip;
      if (rate >= 0.9) {
        status = '${(rate * 100).toStringAsFixed(0)}%达标';
      } else if (rate >= 0.7) {
        status = '$withinBudget/$total项达标';
        tip = '部分预算超支，注意控制';
      } else {
        status = '需改进';
        tip = '建议审视超支项目，调整预算或消费';
      }

      return GoalAchievement(
        type: GoalType.budgetExecution,
        currentValue: withinBudget.toDouble(),
        targetValue: total.toDouble(),
        achievementRate: rate,
        status: status,
        tip: tip,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Calculate budget goal error: $e');
      return GoalAchievement(
        type: GoalType.budgetExecution,
        currentValue: 0,
        targetValue: 1,
        achievementRate: 0.8,
        status: '暂无预算',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 计算记账习惯目标
  Future<GoalAchievement> _calculateRecordingHabitGoal() async {
    try {
      // 目标：连续记账21天
      const targetStreak = 21.0;

      // TODO: 从用户记录获取连续记账天数
      // 暂时使用模拟数据
      const currentStreak = 15.0;

      final rate = (currentStreak / targetStreak).clamp(0.0, 1.5);

      String status;
      String? tip;
      if (currentStreak >= targetStreak) {
        status = '已达成';
      } else {
        status = '连续${currentStreak.toInt()}天';
        if (currentStreak < 7) {
          tip = '坚持每日记账，培养好习惯';
        } else {
          tip = '再坚持${(targetStreak - currentStreak).toInt()}天即可达成';
        }
      }

      return GoalAchievement(
        type: GoalType.recordingHabit,
        currentValue: currentStreak,
        targetValue: targetStreak,
        achievementRate: rate.clamp(0.0, 1.0),
        status: status,
        tip: tip,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Calculate recording habit goal error: $e');
      return GoalAchievement(
        type: GoalType.recordingHabit,
        currentValue: 0,
        targetValue: 21,
        achievementRate: 0,
        status: '开始记账',
        tip: '开始每日记账吧',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 计算储蓄目标
  Future<GoalAchievement> _calculateSavingsGoal() async {
    try {
      // TODO: 从储蓄目标表获取数据
      // 暂时使用模拟数据
      const targetAmount = 5000.0;
      const currentAmount = 3200.0;

      final rate = targetAmount > 0 ? currentAmount / targetAmount : 0.0;

      String status;
      String? tip;
      if (rate >= 1.0) {
        status = '已达成';
      } else if (rate >= 0.5) {
        status = '${(rate * 100).toStringAsFixed(0)}%';
        tip = '继续保持，即将达成';
      } else {
        status = '进行中';
        tip = '建议减少非必要支出，增加储蓄';
      }

      return GoalAchievement(
        type: GoalType.savingsGoal,
        currentValue: currentAmount,
        targetValue: targetAmount,
        achievementRate: rate.clamp(0.0, 1.5),
        status: status,
        tip: tip,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Calculate savings goal error: $e');
      return GoalAchievement(
        type: GoalType.savingsGoal,
        currentValue: 0,
        targetValue: 1000,
        achievementRate: 0,
        status: '设置目标',
        tip: '设置一个储蓄目标开始吧',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 获取目标历史趋势
  Future<List<({DateTime date, double rate})>> getAchievementHistory({
    int days = 30,
  }) async {
    // TODO: 实现历史趋势查询
    return [];
  }
}
