/// Savings Goal Repository Interface
///
/// 定义储蓄目标实体的仓库接口
library;

import '../../models/savings_goal.dart';
import 'i_repository.dart';

/// 储蓄目标进度
class SavingsGoalProgress {
  final String goalId;
  final double targetAmount;
  final double currentAmount;
  final double remainingAmount;
  final double progressPercentage;
  final int remainingDays;
  final double dailyTargetAmount;
  final bool isOnTrack;

  const SavingsGoalProgress({
    required this.goalId,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingAmount,
    required this.progressPercentage,
    required this.remainingDays,
    required this.dailyTargetAmount,
    required this.isOnTrack,
  });
}

/// 储蓄目标仓库接口
abstract class ISavingsGoalRepository extends IRepository<SavingsGoal, String> {
  /// 获取所有进行中的储蓄目标
  Future<List<SavingsGoal>> findActive();

  /// 获取已完成的储蓄目标
  Future<List<SavingsGoal>> findCompleted();

  /// 获取即将到期的储蓄目标
  Future<List<SavingsGoal>> findDueSoon({int days = 30});

  /// 按优先级排序获取目标
  Future<List<SavingsGoal>> findByPriority();

  /// 获取储蓄目标进度
  Future<SavingsGoalProgress> getProgress(String goalId);

  /// 更新储蓄目标当前金额
  Future<void> updateCurrentAmount(String goalId, double amount);

  /// 向储蓄目标存入金额
  Future<void> deposit(String goalId, double amount);

  /// 从储蓄目标取出金额
  Future<void> withdraw(String goalId, double amount);

  /// 获取总储蓄目标金额
  Future<double> getTotalTargetAmount();

  /// 获取总已存金额
  Future<double> getTotalSavedAmount();

  /// 按分类获取储蓄目标
  Future<List<SavingsGoal>> findByCategory(String category);
}
