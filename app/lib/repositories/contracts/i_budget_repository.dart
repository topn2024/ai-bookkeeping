import '../../models/budget.dart';
import 'i_repository.dart';

/// 预算 Repository 接口
///
/// 定义预算数据访问操作，继承软删除能力。
abstract class IBudgetRepository implements ISoftDeleteRepository<Budget, String> {
  // ==================== 查询操作 ====================

  /// 根据月份查询预算
  Future<List<Budget>> findByMonth(DateTime month);

  /// 根据分类查询预算
  Future<Budget?> findByCategory(String category);

  /// 根据账本 ID 查询预算
  Future<List<Budget>> findByLedgerId(String ledgerId);

  /// 根据预算类型查询
  Future<List<Budget>> findByType(BudgetType type);

  // ==================== 结转操作 ====================

  /// 插入预算结转
  Future<void> insertCarryover(BudgetCarryover carryover);

  /// 获取预算的结转记录
  Future<List<BudgetCarryover>> findCarryoversByBudgetId(String budgetId);

  /// 删除结转记录
  Future<void> deleteCarryover(String id);

  // ==================== 零基预算分配 ====================

  /// 插入零基分配
  Future<void> insertAllocation(ZeroBasedAllocation allocation);

  /// 获取预算的零基分配
  Future<List<ZeroBasedAllocation>> findAllocationsByBudgetId(String budgetId);

  /// 更新零基分配
  Future<void> updateAllocation(ZeroBasedAllocation allocation);

  /// 删除零基分配
  Future<void> deleteAllocation(String id);
}
