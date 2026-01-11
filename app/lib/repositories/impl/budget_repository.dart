import '../../models/budget.dart';
import '../../core/contracts/i_database_service.dart';
import '../contracts/i_budget_repository.dart';

/// 预算 Repository 实现
///
/// 封装所有预算相关的数据库操作。
class BudgetRepository implements IBudgetRepository {
  final IDatabaseService _db;

  BudgetRepository(this._db);

  // ==================== IRepository 基础操作 ====================

  @override
  Future<List<Budget>> findAll() => _db.getBudgets();

  @override
  Future<Budget?> findById(String id) => _db.getBudget(id);

  @override
  Future<void> insert(Budget entity) => _db.insertBudget(entity);

  @override
  Future<void> update(Budget entity) => _db.updateBudget(entity);

  @override
  Future<void> delete(String id) => _db.deleteBudget(id);

  @override
  Future<bool> exists(String id) async {
    final budget = await findById(id);
    return budget != null;
  }

  @override
  Future<int> count() async {
    final budgets = await _db.getBudgets();
    return budgets.length;
  }

  // ==================== ISoftDeleteRepository 操作 ====================

  @override
  Future<List<Budget>> findAllIncludingDeleted() =>
      _db.getBudgets(includeDeleted: true);

  @override
  Future<void> softDelete(String id) => _db.softDeleteBudget(id);

  @override
  Future<void> restore(String id) => _db.restoreBudget(id);

  @override
  Future<void> purge(String id) => _db.deleteBudget(id);

  @override
  Future<List<Budget>> findDeleted() async {
    final all = await _db.getBudgets(includeDeleted: true);
    final active = await _db.getBudgets(includeDeleted: false);
    final activeIds = active.map((b) => b.id).toSet();
    return all.where((b) => !activeIds.contains(b.id)).toList();
  }

  // ==================== 查询操作 ====================

  @override
  Future<List<Budget>> findByMonth(DateTime month) =>
      _db.getBudgetsForMonth(month);

  @override
  Future<Budget?> findByCategory(String category) async {
    final budgets = await _db.getBudgets();
    try {
      return budgets.firstWhere((b) => b.categoryId == category);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Budget>> findByLedgerId(String ledgerId) async {
    final budgets = await _db.getBudgets();
    return budgets.where((b) => b.ledgerId == ledgerId).toList();
  }

  @override
  Future<List<Budget>> findByType(BudgetType type) async {
    final budgets = await _db.getBudgets();
    return budgets.where((b) => b.budgetType == type).toList();
  }

  // ==================== 结转操作 ====================

  @override
  Future<void> insertCarryover(BudgetCarryover carryover) =>
      _db.insertBudgetCarryover(carryover);

  @override
  Future<List<BudgetCarryover>> findCarryoversByBudgetId(String budgetId) =>
      _db.getBudgetCarryovers(budgetId);

  @override
  Future<void> deleteCarryover(String id) => _db.deleteBudgetCarryover(id);

  // ==================== 零基预算分配 ====================

  @override
  Future<void> insertAllocation(ZeroBasedAllocation allocation) =>
      _db.insertZeroBasedAllocation(allocation);

  @override
  Future<List<ZeroBasedAllocation>> findAllocationsByBudgetId(String budgetId) =>
      _db.getZeroBasedAllocations(budgetId);

  @override
  Future<void> updateAllocation(ZeroBasedAllocation allocation) =>
      _db.updateZeroBasedAllocation(allocation);

  @override
  Future<void> deleteAllocation(String id) =>
      _db.deleteZeroBasedAllocation(id);
}
