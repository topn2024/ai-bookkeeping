import '../../models/budget.dart';

/// 预算服务接口
///
/// 定义预算相关操作的抽象接口，包括 CRUD 操作、预算监控、结转等。
abstract class IBudgetService {
  // ==================== CRUD 操作 ====================

  /// 获取所有预算
  Future<List<Budget>> getAll({bool includeDeleted = false});

  /// 根据 ID 获取预算
  Future<Budget?> getById(String id);

  /// 创建预算
  Future<void> create(Budget budget);

  /// 更新预算
  Future<void> update(Budget budget);

  /// 保存预算（创建或更新）
  Future<void> save(Budget budget);

  /// 删除预算（硬删除）
  Future<void> delete(String id);

  /// 软删除预算
  Future<void> softDelete(String id);

  /// 恢复已删除的预算
  Future<void> restore(String id);

  // ==================== 查询操作 ====================

  /// 获取指定月份的预算列表
  Future<List<Budget>> getByMonth(DateTime month);

  /// 根据分类获取预算
  Future<Budget?> getByCategory(String category);

  /// 根据账本 ID 获取预算列表
  Future<List<Budget>> getByLedgerId(String ledgerId);

  // ==================== 预算监控 ====================

  /// 获取预算使用情况
  Future<BudgetUsage> getUsage(String budgetId);

  /// 获取预算使用百分比
  Future<double> getUsagePercentage(String budgetId);

  /// 检查预算是否超支
  Future<bool> isOverBudget(String budgetId);

  /// 获取预算剩余金额
  Future<double> getRemainingAmount(String budgetId);

  // ==================== 预算结转 ====================

  /// 创建预算结转记录
  Future<void> createCarryover(BudgetCarryover carryover);

  /// 获取预算的结转记录
  Future<List<BudgetCarryover>> getCarryovers(String budgetId);

  /// 删除结转记录
  Future<void> deleteCarryover(String id);

  // ==================== 零基预算 ====================

  /// 创建零基预算分配
  Future<void> createAllocation(ZeroBasedAllocation allocation);

  /// 获取预算的零基分配
  Future<List<ZeroBasedAllocation>> getAllocations(String budgetId);

  /// 更新零基分配
  Future<void> updateAllocation(ZeroBasedAllocation allocation);

  /// 删除零基分配
  Future<void> deleteAllocation(String id);
}

/// 预算使用情况
class BudgetUsage {
  final String budgetId;
  final double budgetAmount;
  final double usedAmount;
  final double remainingAmount;
  final double usagePercentage;
  final bool isOverBudget;

  const BudgetUsage({
    required this.budgetId,
    required this.budgetAmount,
    required this.usedAmount,
    required this.remainingAmount,
    required this.usagePercentage,
    required this.isOverBudget,
  });
}
