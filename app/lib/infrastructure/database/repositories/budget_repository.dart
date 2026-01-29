/// Budget Repository Implementation
///
/// 实现 IBudgetRepository 接口，封装预算相关的数据库操作。
library;

import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../../models/budget.dart';
import '../../../domain/repositories/i_budget_repository.dart';

/// 预算仓库实现
class BudgetRepository implements IBudgetRepository {
  final Future<Database> Function() _databaseProvider;

  BudgetRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  // ==================== IRepository 基础实现 ====================

  @override
  Future<Budget?> findById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  @override
  Future<List<Budget>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Budget.fromMap(m)).toList();
  }

  @override
  Future<int> insert(Budget entity) async {
    debugPrint('[BudgetRepository] 插入预算: id=${entity.id}');
    final db = await _db;
    return await db.insert('budgets', entity.toMap());
  }

  @override
  Future<void> insertAll(List<Budget> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final entity in entities) {
      batch.insert('budgets', entity.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(Budget entity) async {
    final db = await _db;
    return await db.update(
      'budgets',
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update(
      'budgets',
      {'isDeleted': 1, 'deletedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update(
      'budgets',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM budgets WHERE id = ?',
      [id],
    );
    return (result.first['count'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM budgets WHERE isDeleted = 0',
    );
    return result.first['count'] as int;
  }

  // ==================== IBudgetRepository 特定实现 ====================

  @override
  Future<Budget?> findByCategory(String category) async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'categoryId = ? AND isDeleted = 0',
      whereArgs: [category],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  @override
  Future<List<Budget>> findByPeriod(BudgetPeriod period) async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'period = ? AND isDeleted = 0',
      whereArgs: [period.index],
    );
    return maps.map((m) => Budget.fromMap(m)).toList();
  }

  @override
  Future<List<Budget>> findByType(BudgetType type) async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'budgetType = ? AND isDeleted = 0',
      whereArgs: [type.index],
    );
    return maps.map((m) => Budget.fromMap(m)).toList();
  }

  @override
  Future<List<Budget>> findActive() async {
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'isEnabled = 1 AND isDeleted = 0',
    );
    return maps.map((m) => Budget.fromMap(m)).toList();
  }

  @override
  Future<List<Budget>> findByMonth(int year, int month) async {
    // 获取指定月份活跃的月度预算
    final db = await _db;
    final maps = await db.query(
      'budgets',
      where: 'period = ? AND isEnabled = 1 AND isDeleted = 0',
      whereArgs: [BudgetPeriod.monthly.index],
    );
    return maps.map((m) => Budget.fromMap(m)).toList();
  }

  @override
  Future<BudgetExecution> getExecution(String budgetId, {int? year, int? month}) async {
    final budget = await findById(budgetId);
    if (budget == null) {
      return BudgetExecution.calculate(
        budgetId: budgetId,
        budgetAmount: 0,
        usedAmount: 0,
      );
    }

    final db = await _db;

    // 根据预算周期确定日期范围
    DateTime startDate;
    DateTime endDate;

    if (year != null && month != null) {
      // 使用指定的年月
      startDate = DateTime(year, month, 1);
      endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    } else {
      // 使用预算的当前周期
      startDate = budget.periodStartDate;
      endDate = budget.periodEndDate;
    }

    // 计算该预算周期内的支出
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as spent
      FROM transactions
      WHERE category = ? AND type = 0 AND isDeleted = 0
        AND date >= ? AND date <= ?
    ''', [
      budget.categoryId,
      startDate.millisecondsSinceEpoch,
      endDate.millisecondsSinceEpoch,
    ]);

    final spent = (result.first['spent'] as num).toDouble();

    return BudgetExecution.calculate(
      budgetId: budgetId,
      budgetAmount: budget.amount,
      usedAmount: spent,
    );
  }

  @override
  Future<List<BudgetExecution>> getAllExecutions({int? year, int? month}) async {
    final budgets = await findActive();
    final executions = <BudgetExecution>[];

    for (final budget in budgets) {
      executions.add(await getExecution(budget.id, year: year, month: month));
    }

    return executions;
  }

  @override
  Future<List<BudgetCarryover>> getCarryovers(String budgetId) async {
    final db = await _db;
    final maps = await db.query(
      'budget_carryovers',
      where: 'budgetId = ?',
      whereArgs: [budgetId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => BudgetCarryover.fromMap(m)).toList();
  }

  @override
  Future<int> addCarryover(BudgetCarryover carryover) async {
    final db = await _db;
    return await db.insert('budget_carryovers', carryover.toMap());
  }

  @override
  Future<List<ZeroBasedAllocation>> getAllocations(String budgetId) async {
    final db = await _db;
    final maps = await db.query(
      'zero_based_allocations',
      where: 'budgetId = ?',
      whereArgs: [budgetId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => ZeroBasedAllocation.fromMap(m)).toList();
  }

  @override
  Future<int> addAllocation(ZeroBasedAllocation allocation) async {
    final db = await _db;
    return await db.insert('zero_based_allocations', allocation.toMap());
  }

  @override
  Future<double> getTotalBudgetAmount({BudgetPeriod? period}) async {
    final db = await _db;
    String query = 'SELECT COALESCE(SUM(amount), 0) as total FROM budgets WHERE isDeleted = 0';
    List<dynamic>? args;

    if (period != null) {
      query += ' AND period = ?';
      args = [period.index];
    }

    final result = await db.rawQuery(query, args);
    return (result.first['total'] as num).toDouble();
  }

  @override
  Future<List<Budget>> findNearingLimit({double threshold = 0.8}) async {
    final executions = await getAllExecutions();
    final nearingLimit = <Budget>[];

    for (final exec in executions) {
      if (exec.usageRatio >= threshold && !exec.isOverBudget) {
        final budget = await findById(exec.budgetId);
        if (budget != null) {
          nearingLimit.add(budget);
        }
      }
    }

    return nearingLimit;
  }
}
