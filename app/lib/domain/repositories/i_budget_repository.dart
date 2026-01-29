/// Budget Repository Interface
///
/// 定义预算实体的仓库接口
library;

import '../../models/budget.dart';
import 'i_repository.dart';

/// 预算执行情况
class BudgetExecution {
  /// 预算 ID
  final String budgetId;

  /// 预算金额
  final double budgetAmount;

  /// 已使用金额
  final double usedAmount;

  /// 剩余金额
  final double remainingAmount;

  /// 使用比例 (0-1)
  final double usageRatio;

  /// 是否超支
  final bool isOverBudget;

  const BudgetExecution({
    required this.budgetId,
    required this.budgetAmount,
    required this.usedAmount,
    required this.remainingAmount,
    required this.usageRatio,
    required this.isOverBudget,
  });

  factory BudgetExecution.calculate({
    required String budgetId,
    required double budgetAmount,
    required double usedAmount,
  }) {
    final remaining = budgetAmount - usedAmount;
    return BudgetExecution(
      budgetId: budgetId,
      budgetAmount: budgetAmount,
      usedAmount: usedAmount,
      remainingAmount: remaining,
      usageRatio: budgetAmount > 0 ? usedAmount / budgetAmount : 0,
      isOverBudget: remaining < 0,
    );
  }
}

/// 预算仓库接口
abstract class IBudgetRepository extends IRepository<Budget, String> {
  /// 按分类查询预算
  Future<Budget?> findByCategory(String category);

  /// 按周期查询预算
  Future<List<Budget>> findByPeriod(BudgetPeriod period);

  /// 按类型查询预算（传统/零基）
  Future<List<Budget>> findByType(BudgetType type);

  /// 获取当前活跃的预算
  Future<List<Budget>> findActive();

  /// 获取指定月份的预算
  Future<List<Budget>> findByMonth(int year, int month);

  /// 获取预算执行情况
  Future<BudgetExecution> getExecution(String budgetId, {int? year, int? month});

  /// 获取所有预算的执行情况
  Future<List<BudgetExecution>> getAllExecutions({int? year, int? month});

  /// 获取预算结转记录
  Future<List<BudgetCarryover>> getCarryovers(String budgetId);

  /// 添加预算结转
  Future<int> addCarryover(BudgetCarryover carryover);

  /// 获取零基预算分配记录
  Future<List<ZeroBasedAllocation>> getAllocations(String budgetId);

  /// 添加零基预算分配
  Future<int> addAllocation(ZeroBasedAllocation allocation);

  /// 获取总预算金额
  Future<double> getTotalBudgetAmount({BudgetPeriod? period});

  /// 获取预算使用预警（接近或超过阈值的预算）
  Future<List<Budget>> findNearingLimit({double threshold = 0.8});
}
