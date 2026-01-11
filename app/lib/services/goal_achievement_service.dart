import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/contracts/i_database_service.dart';
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
  final IDatabaseService _dbService;
  final FinancialHealthScoreService _healthService;

  GoalAchievementService(IDatabaseService db)
      : _dbService = db,
        _healthService = FinancialHealthScoreService(db);

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

    // 计算月度进展（比较本月与上月的达成率）
    int monthlyProgress = 0;
    try {
      final lastMonthRate = await _getLastMonthAchievementRate();
      if (lastMonthRate != null) {
        final improvement = ((overallRate - lastMonthRate) * 100).round();
        monthlyProgress = improvement.clamp(-100, 100);
      }
    } catch (e) {
      debugPrint('Calculate monthly progress error: $e');
    }

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
      const targetDays = 30.0;

      final db = await _dbService.database;

      // 查询所有有剩余金额的资源池
      final results = await db.query(
        'resource_pools',
        where: 'remainingAmount > 0',
        orderBy: 'createdAt DESC',
      );

      if (results.isEmpty) {
        return GoalAchievement(
          type: GoalType.moneyAgeHealth,
          currentValue: 0,
          targetValue: targetDays,
          achievementRate: 0,
          status: '暂无数据',
          tip: '开始记录收入以追踪钱龄',
          lastUpdated: DateTime.now(),
        );
      }

      // 计算加权平均钱龄（按剩余金额加权）
      double totalWeightedAge = 0;
      double totalRemaining = 0;

      for (var row in results) {
        final createdAt = DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int);
        final remaining = (row['remainingAmount'] as num).toDouble();
        final age = DateTime.now().difference(createdAt).inDays;

        totalWeightedAge += age * remaining;
        totalRemaining += remaining;
      }

      final currentAge = totalRemaining > 0 ? totalWeightedAge / totalRemaining : 0.0;
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
      final db = await _dbService.database;

      // 获取当前月份的所有启用的小金库
      final vaultResults = await db.query(
        'budget_vaults',
        where: 'isEnabled = 1',
      );

      if (vaultResults.isEmpty) {
        return GoalAchievement(
          type: GoalType.budgetExecution,
          currentValue: 0,
          targetValue: 1,
          achievementRate: 0,
          status: '暂无预算',
          tip: '创建小金库开始预算管理',
          lastUpdated: DateTime.now(),
        );
      }

      int total = vaultResults.length;
      int withinBudget = 0;

      // 检查每个小金库是否在预算内
      for (var row in vaultResults) {
        final allocated = (row['allocatedAmount'] as num?)?.toDouble() ?? 0;
        final spent = (row['spentAmount'] as num?)?.toDouble() ?? 0;

        // 如果已花费金额不超过已分配金额，则视为达标
        if (spent <= allocated) {
          withinBudget++;
        }
      }

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
        achievementRate: 0,
        status: '暂无预算',
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 计算记账习惯目标
  Future<GoalAchievement> _calculateRecordingHabitGoal() async {
    try {
      const targetStreak = 21.0;

      final db = await _dbService.database;

      // 获取最近30天的交易记录，按日期分组
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final results = await db.rawQuery('''
        SELECT DATE(datetime / 1000, 'unixepoch', 'localtime') as date
        FROM transactions
        WHERE datetime >= ?
        GROUP BY date
        ORDER BY date DESC
      ''', [thirtyDaysAgo.millisecondsSinceEpoch]);

      if (results.isEmpty) {
        return GoalAchievement(
          type: GoalType.recordingHabit,
          currentValue: 0,
          targetValue: targetStreak,
          achievementRate: 0,
          status: '开始记账',
          tip: '开始每日记账吧',
          lastUpdated: DateTime.now(),
        );
      }

      // 计算连续记账天数
      int currentStreak = 0;
      DateTime checkDate = DateTime(now.year, now.month, now.day);

      for (var row in results) {
        final dateStr = row['date'] as String;
        final recordDate = DateTime.parse(dateStr);

        // 检查是否是连续的日期
        if (recordDate.year == checkDate.year &&
            recordDate.month == checkDate.month &&
            recordDate.day == checkDate.day) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      final rate = (currentStreak / targetStreak).clamp(0.0, 1.5);

      String status;
      String? tip;
      if (currentStreak >= targetStreak) {
        status = '已达成';
      } else {
        status = '连续$currentStreak天';
        if (currentStreak < 7) {
          tip = '坚持每日记账，培养好习惯';
        } else {
          tip = '再坚持${(targetStreak - currentStreak).toInt()}天即可达成';
        }
      }

      return GoalAchievement(
        type: GoalType.recordingHabit,
        currentValue: currentStreak.toDouble(),
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
      final db = await _dbService.database;

      // 获取当前活跃的储蓄目标
      final results = await db.query(
        'savings_goals',
        where: 'status = ?',
        whereArgs: ['active'],
        orderBy: 'targetDate ASC',
        limit: 1,
      );

      if (results.isEmpty) {
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

      final goal = results.first;
      final targetAmount = (goal['targetAmount'] as num).toDouble();
      final currentAmount = (goal['currentAmount'] as num?)?.toDouble() ?? 0;

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

  /// 获取上月的总体达成率（用于计算月度进展）
  Future<double?> _getLastMonthAchievementRate() async {
    try {
      // 简化实现：返回null表示没有历史数据
      // 完整实现需要存储每日/每月的达成率快照
      return null;
    } catch (e) {
      debugPrint('Get last month achievement rate error: $e');
      return null;
    }
  }
}
