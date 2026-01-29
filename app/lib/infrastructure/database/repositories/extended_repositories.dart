/// Extended Repository Implementations
///
/// 扩展仓库实现，包含：
/// - TemplateRepository
/// - RecurringTransactionRepository
/// - CreditCardRepository
/// - SavingsGoalRepository
/// - BillReminderRepository
/// - DebtRepository
/// - InvestmentRepository
/// - VaultRepository
/// - ImportBatchRepository
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../domain/repositories/repositories.dart';
import '../../../models/template.dart';
import '../../../models/recurring_transaction.dart';
import '../../../models/credit_card.dart';
import '../../../models/savings_goal.dart';
import '../../../models/bill_reminder.dart';
import '../../../models/debt.dart' hide DebtPayment;
import '../../../models/investment_account.dart';
import '../../../models/budget_vault.dart';
import '../../../models/import_batch.dart';

// ==================== Template Repository ====================

/// 交易模板仓库实现
class TemplateRepository implements ITemplateRepository {
  final Future<Database> Function() _databaseProvider;

  TemplateRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<TransactionTemplate?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('templates', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return TransactionTemplate.fromMap(maps.first);
  }

  @override
  Future<List<TransactionTemplate>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('templates', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => TransactionTemplate.fromMap(m)).toList();
  }

  @override
  Future<int> insert(TransactionTemplate entity) async {
    final db = await _db;
    return await db.insert('templates', entity.toMap());
  }

  @override
  Future<void> insertAll(List<TransactionTemplate> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('templates', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(TransactionTemplate entity) async {
    final db = await _db;
    return await db.update('templates', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('templates', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('templates', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM templates WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM templates WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<List<TransactionTemplate>> findByCategory(String category) async {
    final db = await _db;
    final maps = await db.query('templates', where: 'category = ? AND isDeleted = 0', whereArgs: [category]);
    return maps.map((m) => TransactionTemplate.fromMap(m)).toList();
  }

  @override
  Future<List<TransactionTemplate>> findByType(String type) async {
    final db = await _db;
    final maps = await db.query('templates', where: 'type = ? AND isDeleted = 0', whereArgs: [type]);
    return maps.map((m) => TransactionTemplate.fromMap(m)).toList();
  }

  @override
  Future<List<TransactionTemplate>> findFrequentlyUsed({int limit = 10}) async {
    final db = await _db;
    final maps = await db.query('templates', where: 'isDeleted = 0', orderBy: 'usageCount DESC', limit: limit);
    return maps.map((m) => TransactionTemplate.fromMap(m)).toList();
  }

  @override
  Future<List<TransactionTemplate>> search(String keyword) async {
    final db = await _db;
    final maps = await db.query('templates', where: 'name LIKE ? AND isDeleted = 0', whereArgs: ['%$keyword%']);
    return maps.map((m) => TransactionTemplate.fromMap(m)).toList();
  }

  @override
  Future<int> incrementUsageCount(String templateId) async {
    final db = await _db;
    return await db.rawUpdate('UPDATE templates SET usageCount = usageCount + 1 WHERE id = ?', [templateId]);
  }

  @override
  Future<List<TransactionTemplate>> findByLedger(String ledgerId) async {
    final db = await _db;
    final maps = await db.query('templates', where: 'ledgerId = ? AND isDeleted = 0', whereArgs: [ledgerId]);
    return maps.map((m) => TransactionTemplate.fromMap(m)).toList();
  }

  @override
  Future<List<TransactionTemplate>> findEnabled() async {
    final db = await _db;
    final maps = await db.query('templates', where: 'isEnabled = 1 AND isDeleted = 0');
    return maps.map((m) => TransactionTemplate.fromMap(m)).toList();
  }
}

// ==================== Recurring Transaction Repository ====================

/// 循环交易仓库实现
class RecurringTransactionRepository implements IRecurringTransactionRepository {
  final Future<Database> Function() _databaseProvider;

  RecurringTransactionRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<RecurringTransaction?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('recurring_transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return RecurringTransaction.fromMap(maps.first);
  }

  @override
  Future<List<RecurringTransaction>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('recurring_transactions', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  @override
  Future<int> insert(RecurringTransaction entity) async {
    final db = await _db;
    return await db.insert('recurring_transactions', entity.toMap());
  }

  @override
  Future<void> insertAll(List<RecurringTransaction> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('recurring_transactions', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(RecurringTransaction entity) async {
    final db = await _db;
    return await db.update('recurring_transactions', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('recurring_transactions', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('recurring_transactions', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM recurring_transactions WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM recurring_transactions WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<List<RecurringTransaction>> findPending() async {
    final db = await _db;
    final maps = await db.query('recurring_transactions', where: 'isEnabled = 1 AND isDeleted = 0');
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  @override
  Future<List<RecurringTransaction>> findDueInRange(DateTime start, DateTime end) async {
    final db = await _db;
    final maps = await db.query(
      'recurring_transactions',
      where: 'nextExecutionDate >= ? AND nextExecutionDate <= ? AND isEnabled = 1 AND isDeleted = 0',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  @override
  Future<List<RecurringTransaction>> findByFrequency(RecurringFrequency frequency) async {
    final db = await _db;
    final maps = await db.query('recurring_transactions', where: 'frequency = ? AND isDeleted = 0', whereArgs: [frequency.index]);
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  @override
  Future<List<RecurringTransaction>> findByAccount(String accountId) async {
    final db = await _db;
    final maps = await db.query('recurring_transactions', where: 'accountId = ? AND isDeleted = 0', whereArgs: [accountId]);
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  @override
  Future<List<RecurringTransaction>> findByCategory(String category) async {
    final db = await _db;
    final maps = await db.query('recurring_transactions', where: 'category = ? AND isDeleted = 0', whereArgs: [category]);
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  @override
  Future<List<RecurringTransaction>> findActive() async => findPending();

  @override
  Future<int> updateNextExecutionDate(String id, DateTime nextDate) async {
    final db = await _db;
    return await db.update('recurring_transactions', {'nextExecutionDate': nextDate.millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> pause(String id) async {
    final db = await _db;
    return await db.update('recurring_transactions', {'isEnabled': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> resume(String id) async {
    final db = await _db;
    return await db.update('recurring_transactions', {'isEnabled': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<RecurringTransaction>> findUpcoming({int days = 7}) async {
    final now = DateTime.now();
    final end = now.add(Duration(days: days));
    return findDueInRange(now, end);
  }
}

// ==================== Credit Card Repository ====================

/// 信用卡仓库实现
class CreditCardRepository implements ICreditCardRepository {
  final Future<Database> Function() _databaseProvider;

  CreditCardRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<CreditCard?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('credit_cards', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return CreditCard.fromMap(maps.first);
  }

  @override
  Future<List<CreditCard>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('credit_cards', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => CreditCard.fromMap(m)).toList();
  }

  @override
  Future<int> insert(CreditCard entity) async {
    final db = await _db;
    return await db.insert('credit_cards', entity.toMap());
  }

  @override
  Future<void> insertAll(List<CreditCard> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('credit_cards', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(CreditCard entity) async {
    final db = await _db;
    return await db.update('credit_cards', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('credit_cards', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('credit_cards', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('credit_cards', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM credit_cards WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM credit_cards WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<CreditCard?> findByAccountId(String accountId) async {
    final db = await _db;
    final maps = await db.query('credit_cards', where: 'accountId = ? AND isDeleted = 0', whereArgs: [accountId], limit: 1);
    if (maps.isEmpty) return null;
    return CreditCard.fromMap(maps.first);
  }

  @override
  Future<List<CreditCard>> findAllSortedByDueDate() async {
    final db = await _db;
    final maps = await db.query('credit_cards', where: 'isDeleted = 0', orderBy: 'dueDay ASC');
    return maps.map((m) => CreditCard.fromMap(m)).toList();
  }

  @override
  Future<List<CreditCard>> findDueSoon({int days = 7}) async {
    return findAll();
  }

  @override
  Future<List<CreditCard>> findOverdue() async {
    return [];
  }

  @override
  Future<int> updateBalance(String id, double balance) async {
    final db = await _db;
    return await db.update('credit_cards', {'currentBalance': balance}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> updateUsedCredit(String id, double usedAmount) async {
    final db = await _db;
    return await db.update('credit_cards', {'usedCredit': usedAmount}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<double> getTotalCreditLimit() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COALESCE(SUM(creditLimit), 0) as t FROM credit_cards WHERE isDeleted = 0');
    return (r.first['t'] as num).toDouble();
  }

  @override
  Future<double> getTotalUsedCredit() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COALESCE(SUM(usedCredit), 0) as t FROM credit_cards WHERE isDeleted = 0');
    return (r.first['t'] as num).toDouble();
  }

  @override
  Future<List<CreditCard>> findByBillingDay(int day) async {
    final db = await _db;
    final maps = await db.query('credit_cards', where: 'billingDay = ? AND isDeleted = 0', whereArgs: [day]);
    return maps.map((m) => CreditCard.fromMap(m)).toList();
  }

  @override
  Future<List<CreditCard>> findByDueDay(int day) async {
    final db = await _db;
    final maps = await db.query('credit_cards', where: 'dueDay = ? AND isDeleted = 0', whereArgs: [day]);
    return maps.map((m) => CreditCard.fromMap(m)).toList();
  }
}

// ==================== Savings Goal Repository ====================

/// 储蓄目标仓库实现
class SavingsGoalRepository implements ISavingsGoalRepository {
  final Future<Database> Function() _databaseProvider;

  SavingsGoalRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<SavingsGoal?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('savings_goals', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return SavingsGoal.fromMap(maps.first);
  }

  @override
  Future<List<SavingsGoal>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('savings_goals', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }

  @override
  Future<int> insert(SavingsGoal entity) async {
    final db = await _db;
    return await db.insert('savings_goals', entity.toMap());
  }

  @override
  Future<void> insertAll(List<SavingsGoal> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('savings_goals', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(SavingsGoal entity) async {
    final db = await _db;
    return await db.update('savings_goals', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('savings_goals', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('savings_goals', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM savings_goals WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM savings_goals WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<List<SavingsGoal>> findActive() async {
    final db = await _db;
    final maps = await db.query('savings_goals', where: 'isCompleted = 0 AND isDeleted = 0');
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }

  @override
  Future<List<SavingsGoal>> findCompleted() async {
    final db = await _db;
    final maps = await db.query('savings_goals', where: 'isCompleted = 1 AND isDeleted = 0');
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }

  @override
  Future<List<SavingsGoal>> findDueSoon({int days = 30}) async {
    final deadline = DateTime.now().add(Duration(days: days));
    final db = await _db;
    final maps = await db.query(
      'savings_goals',
      where: 'targetDate <= ? AND isCompleted = 0 AND isDeleted = 0',
      whereArgs: [deadline.millisecondsSinceEpoch],
    );
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }

  @override
  Future<List<SavingsGoal>> findByPriority() async {
    final db = await _db;
    final maps = await db.query('savings_goals', where: 'isDeleted = 0', orderBy: 'priority DESC');
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }

  @override
  Future<SavingsGoalProgress> getProgress(String goalId) async {
    final goal = await findById(goalId);
    if (goal == null) {
      return SavingsGoalProgress(
        goalId: goalId,
        targetAmount: 0,
        currentAmount: 0,
        remainingAmount: 0,
        progressPercentage: 0,
        remainingDays: 0,
        dailyTargetAmount: 0,
        isOnTrack: false,
      );
    }

    final percentage = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0.0;
    final remaining = goal.targetAmount - goal.currentAmount;
    final now = DateTime.now();
    final daysRemaining = goal.targetDate?.difference(now).inDays ?? 0;
    final dailyTarget = daysRemaining > 0 ? remaining / daysRemaining : remaining;

    return SavingsGoalProgress(
      goalId: goalId,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      remainingAmount: remaining,
      progressPercentage: percentage,
      remainingDays: daysRemaining,
      dailyTargetAmount: dailyTarget,
      isOnTrack: dailyTarget <= (goal.targetAmount / 30),
    );
  }

  @override
  Future<void> updateCurrentAmount(String goalId, double amount) async {
    final db = await _db;
    await db.update('savings_goals', {'currentAmount': amount}, where: 'id = ?', whereArgs: [goalId]);
  }

  @override
  Future<void> deposit(String goalId, double amount) async {
    final db = await _db;
    await db.rawUpdate('UPDATE savings_goals SET currentAmount = currentAmount + ? WHERE id = ?', [amount, goalId]);
  }

  @override
  Future<void> withdraw(String goalId, double amount) async {
    final db = await _db;
    await db.rawUpdate('UPDATE savings_goals SET currentAmount = currentAmount - ? WHERE id = ?', [amount, goalId]);
  }

  @override
  Future<double> getTotalTargetAmount() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COALESCE(SUM(targetAmount), 0) as t FROM savings_goals WHERE isDeleted = 0');
    return (r.first['t'] as num).toDouble();
  }

  @override
  Future<double> getTotalSavedAmount() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COALESCE(SUM(currentAmount), 0) as t FROM savings_goals WHERE isDeleted = 0');
    return (r.first['t'] as num).toDouble();
  }

  @override
  Future<List<SavingsGoal>> findByCategory(String category) async {
    final db = await _db;
    final maps = await db.query('savings_goals', where: 'category = ? AND isDeleted = 0', whereArgs: [category]);
    return maps.map((m) => SavingsGoal.fromMap(m)).toList();
  }
}

// ==================== Bill Reminder Repository ====================

/// 账单提醒仓库实现
class BillReminderRepository implements IBillReminderRepository {
  final Future<Database> Function() _databaseProvider;

  BillReminderRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<BillReminder?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('bill_reminders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return BillReminder.fromMap(maps.first);
  }

  @override
  Future<List<BillReminder>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('bill_reminders', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => BillReminder.fromMap(m)).toList();
  }

  @override
  Future<int> insert(BillReminder entity) async {
    final db = await _db;
    return await db.insert('bill_reminders', entity.toMap());
  }

  @override
  Future<void> insertAll(List<BillReminder> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('bill_reminders', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(BillReminder entity) async {
    final db = await _db;
    return await db.update('bill_reminders', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('bill_reminders', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('bill_reminders', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('bill_reminders', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM bill_reminders WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM bill_reminders WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<List<BillReminder>> findPending() async {
    final db = await _db;
    final maps = await db.query('bill_reminders', where: 'isPaid = 0 AND isDeleted = 0');
    return maps.map((m) => BillReminder.fromMap(m)).toList();
  }

  @override
  Future<List<BillReminder>> findInDateRange(DateTime start, DateTime end) async {
    final db = await _db;
    final maps = await db.query(
      'bill_reminders',
      where: 'dueDate >= ? AND dueDate <= ? AND isDeleted = 0',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return maps.map((m) => BillReminder.fromMap(m)).toList();
  }

  @override
  Future<List<BillReminder>> findDueToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return findInDateRange(today, tomorrow);
  }

  @override
  Future<List<BillReminder>> findUpcoming({int days = 7}) async {
    final now = DateTime.now();
    final end = now.add(Duration(days: days));
    return findInDateRange(now, end);
  }

  @override
  Future<List<BillReminder>> findOverdue() async {
    final now = DateTime.now();
    final db = await _db;
    final maps = await db.query(
      'bill_reminders',
      where: 'dueDate < ? AND isPaid = 0 AND isDeleted = 0',
      whereArgs: [now.millisecondsSinceEpoch],
    );
    return maps.map((m) => BillReminder.fromMap(m)).toList();
  }

  @override
  Future<List<BillReminder>> findByCategory(String category) async {
    final db = await _db;
    final maps = await db.query('bill_reminders', where: 'category = ? AND isDeleted = 0', whereArgs: [category]);
    return maps.map((m) => BillReminder.fromMap(m)).toList();
  }

  @override
  Future<int> markAsPaid(String id, {DateTime? paidDate}) async {
    final db = await _db;
    return await db.update(
      'bill_reminders',
      {'isPaid': 1, 'paidDate': (paidDate ?? DateTime.now()).millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> postpone(String id, DateTime newDueDate) async {
    final db = await _db;
    return await db.update('bill_reminders', {'dueDate': newDueDate.millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<BillReminder>> findEnabled() async {
    final db = await _db;
    final maps = await db.query('bill_reminders', where: 'isEnabled = 1 AND isDeleted = 0');
    return maps.map((m) => BillReminder.fromMap(m)).toList();
  }

  @override
  Future<List<BillReminder>> findByAccount(String accountId) async {
    final db = await _db;
    final maps = await db.query('bill_reminders', where: 'accountId = ? AND isDeleted = 0', whereArgs: [accountId]);
    return maps.map((m) => BillReminder.fromMap(m)).toList();
  }

  @override
  Future<double> getMonthlyTotal({int? year, int? month}) async {
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    final start = DateTime(y, m, 1);
    final end = DateTime(y, m + 1, 0, 23, 59, 59);

    final db = await _db;
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as t FROM bill_reminders WHERE dueDate >= ? AND dueDate <= ? AND isDeleted = 0',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return (r.first['t'] as num).toDouble();
  }
}

// ==================== Debt Repository ====================

/// 债务仓库实现
class DebtRepository implements IDebtRepository {
  final Future<Database> Function() _databaseProvider;

  DebtRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<Debt?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('debts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Debt.fromMap(maps.first);
  }

  @override
  Future<List<Debt>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('debts', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  @override
  Future<int> insert(Debt entity) async {
    final db = await _db;
    return await db.insert('debts', entity.toMap());
  }

  @override
  Future<void> insertAll(List<Debt> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('debts', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(Debt entity) async {
    final db = await _db;
    return await db.update('debts', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('debts', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('debts', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM debts WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM debts WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<List<Debt>> findMyDebts() async {
    final db = await _db;
    final maps = await db.query('debts', where: 'isOwedByMe = 1 AND isDeleted = 0');
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  @override
  Future<List<Debt>> findOwedToMe() async {
    final db = await _db;
    final maps = await db.query('debts', where: 'isOwedByMe = 0 AND isDeleted = 0');
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  @override
  Future<List<Debt>> findByPerson(String personName) async {
    final db = await _db;
    final maps = await db.query('debts', where: 'personName = ? AND isDeleted = 0', whereArgs: [personName]);
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  @override
  Future<List<Debt>> findDueSoon({int days = 30}) async {
    final deadline = DateTime.now().add(Duration(days: days));
    final db = await _db;
    final maps = await db.query(
      'debts',
      where: 'dueDate <= ? AND isSettled = 0 AND isDeleted = 0',
      whereArgs: [deadline.millisecondsSinceEpoch],
    );
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  @override
  Future<List<Debt>> findOverdue() async {
    final now = DateTime.now();
    final db = await _db;
    final maps = await db.query(
      'debts',
      where: 'dueDate < ? AND isSettled = 0 AND isDeleted = 0',
      whereArgs: [now.millisecondsSinceEpoch],
    );
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  @override
  Future<DebtStatistics> getStatistics() async {
    final db = await _db;
    final myDebts = await db.rawQuery('SELECT COUNT(*) as c, COALESCE(SUM(remainingAmount), 0) as t FROM debts WHERE isOwedByMe = 1 AND isSettled = 0 AND isDeleted = 0');
    final owedToMe = await db.rawQuery('SELECT COUNT(*) as c, COALESCE(SUM(remainingAmount), 0) as t FROM debts WHERE isOwedByMe = 0 AND isSettled = 0 AND isDeleted = 0');

    final totalDebt = (myDebts.first['t'] as num).toDouble();
    final totalOwed = (owedToMe.first['t'] as num).toDouble();
    final debtCount = myDebts.first['c'] as int;
    final owedCount = owedToMe.first['c'] as int;

    return DebtStatistics(
      totalDebt: totalDebt,
      totalOwed: totalOwed,
      netDebt: totalDebt - totalOwed,
      debtCount: debtCount,
      owedCount: owedCount,
    );
  }

  @override
  Future<void> recordPayment(String debtId, double amount, {String? note}) async {
    final db = await _db;
    await db.rawUpdate('UPDATE debts SET remainingAmount = remainingAmount - ? WHERE id = ?', [amount, debtId]);
    // Record the payment in payment history
    await db.insert('debt_payments', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'debtId': debtId,
      'amount': amount,
      'paymentDate': DateTime.now().millisecondsSinceEpoch,
      'note': note,
    });
  }

  @override
  Future<List<DebtPayment>> getPaymentHistory(String debtId) async {
    final db = await _db;
    final maps = await db.query('debt_payments', where: 'debtId = ?', whereArgs: [debtId], orderBy: 'paymentDate DESC');
    return maps.map((m) => DebtPayment(
      id: m['id'] as String,
      debtId: m['debtId'] as String,
      amount: (m['amount'] as num).toDouble(),
      paymentDate: DateTime.fromMillisecondsSinceEpoch(m['paymentDate'] as int),
      note: m['note'] as String?,
    )).toList();
  }

  @override
  Future<void> markAsSettled(String debtId) async {
    final db = await _db;
    await db.update('debts', {'isSettled': 1, 'remainingAmount': 0}, where: 'id = ?', whereArgs: [debtId]);
  }

  @override
  Future<List<Debt>> findUnsettled() async {
    final db = await _db;
    final maps = await db.query('debts', where: 'isSettled = 0 AND isDeleted = 0');
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  @override
  Future<double> getTotalDebt() async {
    final stats = await getStatistics();
    return stats.totalDebt;
  }

  @override
  Future<double> getTotalOwed() async {
    final stats = await getStatistics();
    return stats.totalOwed;
  }
}

// ==================== Investment Repository ====================

/// 投资仓库实现
class InvestmentRepository implements IInvestmentRepository {
  final Future<Database> Function() _databaseProvider;

  InvestmentRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<InvestmentAccount?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('investments', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return InvestmentAccount.fromJson(maps.first);
  }

  @override
  Future<List<InvestmentAccount>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('investments', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => InvestmentAccount.fromJson(m)).toList();
  }

  @override
  Future<int> insert(InvestmentAccount entity) async {
    final db = await _db;
    return await db.insert('investments', entity.toJson());
  }

  @override
  Future<void> insertAll(List<InvestmentAccount> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('investments', e.toJson());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(InvestmentAccount entity) async {
    final db = await _db;
    return await db.update('investments', entity.toJson(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('investments', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('investments', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('investments', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM investments WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM investments WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<List<InvestmentAccount>> findByType(InvestmentType type) async {
    final db = await _db;
    final maps = await db.query('investments', where: 'type = ? AND isDeleted = 0', whereArgs: [type.index]);
    return maps.map((m) => InvestmentAccount.fromJson(m)).toList();
  }

  @override
  Future<List<InvestmentAccount>> findActive() async {
    final db = await _db;
    final maps = await db.query('investments', where: 'isDeleted = 0');
    return maps.map((m) => InvestmentAccount.fromJson(m)).toList();
  }

  @override
  Future<InvestmentStatistics> getStatistics() async {
    final db = await _db;
    final invested = await db.rawQuery('SELECT COALESCE(SUM(principal), 0) as t FROM investments WHERE isDeleted = 0');
    final current = await db.rawQuery('SELECT COALESCE(SUM(currentValue), 0) as t FROM investments WHERE isDeleted = 0');

    final totalInvested = (invested.first['t'] as num).toDouble();
    final totalCurrent = (current.first['t'] as num).toDouble();

    final allocationByType = <String, double>{};
    final typeResult = await db.rawQuery('''
      SELECT type, COALESCE(SUM(currentValue), 0) as total
      FROM investments WHERE isDeleted = 0 GROUP BY type
    ''');
    for (final row in typeResult) {
      final typeIndex = row['type'] as int;
      final typeName = InvestmentType.values[typeIndex].name;
      allocationByType[typeName] = (row['total'] as num).toDouble();
    }

    return InvestmentStatistics(
      totalInvested: totalInvested,
      currentValue: totalCurrent,
      totalReturn: totalCurrent - totalInvested,
      returnRate: totalInvested > 0 ? (totalCurrent - totalInvested) / totalInvested : 0,
      allocationByType: allocationByType,
    );
  }

  @override
  Future<void> updateCurrentValue(String id, double value) async {
    final db = await _db;
    await db.update('investments', {'currentValue': value}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> recordTransaction(String investmentId, InvestmentTransactionType type, double amount,
      {double? price, double? quantity, String? note}) async {
    final db = await _db;
    await db.insert('investment_transactions', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'investmentId': investmentId,
      'type': type.index,
      'amount': amount,
      'price': price,
      'quantity': quantity,
      'note': note,
      'transactionDate': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<InvestmentTransaction>> getTransactionHistory(String investmentId) async {
    final db = await _db;
    final maps = await db.query('investment_transactions', where: 'investmentId = ?', whereArgs: [investmentId], orderBy: 'transactionDate DESC');
    return maps.map((m) => InvestmentTransaction(
      id: m['id'] as String,
      investmentId: m['investmentId'] as String,
      type: InvestmentTransactionType.values[m['type'] as int],
      amount: (m['amount'] as num).toDouble(),
      price: (m['price'] as num?)?.toDouble(),
      quantity: (m['quantity'] as num?)?.toDouble(),
      transactionDate: DateTime.parse(m['transactionDate'] as String),
      note: m['note'] as String?,
    )).toList();
  }

  @override
  Future<double> getTotalInvested() async {
    final stats = await getStatistics();
    return stats.totalInvested;
  }

  @override
  Future<double> getTotalCurrentValue() async {
    final stats = await getStatistics();
    return stats.currentValue;
  }

  @override
  Future<double> getTotalReturn() async {
    final stats = await getStatistics();
    return stats.totalReturn;
  }

  @override
  Future<List<InvestmentAccount>> findSortedByReturn({bool descending = true}) async {
    final db = await _db;
    final order = descending ? 'DESC' : 'ASC';
    final maps = await db.query('investments', where: 'isDeleted = 0', orderBy: '(currentValue - principal) $order');
    return maps.map((m) => InvestmentAccount.fromJson(m)).toList();
  }

  @override
  Future<List<InvestmentAccount>> findLosing() async {
    final db = await _db;
    final maps = await db.query('investments', where: 'currentValue < principal AND isDeleted = 0');
    return maps.map((m) => InvestmentAccount.fromJson(m)).toList();
  }

  @override
  Future<List<InvestmentAccount>> findProfitable() async {
    final db = await _db;
    final maps = await db.query('investments', where: 'currentValue > principal AND isDeleted = 0');
    return maps.map((m) => InvestmentAccount.fromJson(m)).toList();
  }
}

// ==================== Vault Repository ====================

/// 小金库仓库实现
class VaultRepository implements IVaultRepository {
  final Future<Database> Function() _databaseProvider;

  VaultRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<BudgetVault?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('vaults', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return BudgetVault.fromMap(maps.first);
  }

  @override
  Future<List<BudgetVault>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('vaults', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => BudgetVault.fromMap(m)).toList();
  }

  @override
  Future<int> insert(BudgetVault entity) async {
    final db = await _db;
    return await db.insert('vaults', entity.toMap());
  }

  @override
  Future<void> insertAll(List<BudgetVault> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('vaults', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(BudgetVault entity) async {
    final db = await _db;
    return await db.update('vaults', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('vaults', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('vaults', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('vaults', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM vaults WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM vaults WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<List<BudgetVault>> findActive() async {
    final db = await _db;
    final maps = await db.query('vaults', where: 'isEnabled = 1 AND isDeleted = 0');
    return maps.map((m) => BudgetVault.fromMap(m)).toList();
  }

  @override
  Future<List<BudgetVault>> findByCategory(String category) async {
    final db = await _db;
    final maps = await db.query('vaults', where: 'linkedCategoryId = ? AND isDeleted = 0', whereArgs: [category]);
    return maps.map((m) => BudgetVault.fromMap(m)).toList();
  }

  @override
  Future<List<BudgetVault>> findByLedger(String ledgerId) async {
    final db = await _db;
    final maps = await db.query('vaults', where: 'ledgerId = ? AND isDeleted = 0', whereArgs: [ledgerId]);
    return maps.map((m) => BudgetVault.fromMap(m)).toList();
  }

  @override
  Future<VaultStatistics> getStatistics() async {
    final db = await _db;
    final allocated = await db.rawQuery('SELECT COALESCE(SUM(allocatedAmount), 0) as t FROM vaults WHERE isDeleted = 0');
    final spent = await db.rawQuery('SELECT COALESCE(SUM(spentAmount), 0) as t FROM vaults WHERE isDeleted = 0');
    final target = await db.rawQuery('SELECT COALESCE(SUM(targetAmount), 0) as t FROM vaults WHERE isDeleted = 0');
    final cnt = await db.rawQuery('SELECT COUNT(*) as c FROM vaults WHERE isDeleted = 0');

    final totalAllocated = (allocated.first['t'] as num).toDouble();
    final totalSpent = (spent.first['t'] as num).toDouble();
    final totalTarget = (target.first['t'] as num).toDouble();
    final vaultCount = cnt.first['c'] as int;

    return VaultStatistics(
      totalBalance: totalAllocated - totalSpent,
      totalBudget: totalTarget,
      totalSpent: totalSpent,
      vaultCount: vaultCount,
      averageUsageRate: totalAllocated > 0 ? totalSpent / totalAllocated : 0,
    );
  }

  @override
  Future<void> deposit(String vaultId, double amount, {String? note}) async {
    final db = await _db;
    await db.rawUpdate('UPDATE vaults SET allocatedAmount = allocatedAmount + ? WHERE id = ?', [amount, vaultId]);
  }

  @override
  Future<void> spend(String vaultId, double amount, {String? note}) async {
    final db = await _db;
    await db.rawUpdate('UPDATE vaults SET spentAmount = spentAmount + ? WHERE id = ?', [amount, vaultId]);
  }

  @override
  Future<double> getBalance(String vaultId) async {
    final vault = await findById(vaultId);
    return vault?.currentAmount ?? 0;
  }

  @override
  Future<double> getUsageRate(String vaultId) async {
    final vault = await findById(vaultId);
    if (vault == null || vault.allocatedAmount <= 0) return 0;
    return vault.spentAmount / vault.allocatedAmount;
  }

  @override
  Future<List<BudgetVault>> findNearingLimit({double threshold = 0.8}) async {
    final vaults = await findActive();
    return vaults.where((v) {
      if (v.allocatedAmount <= 0) return false;
      final rate = v.spentAmount / v.allocatedAmount;
      return rate >= threshold && rate < 1.0;
    }).toList();
  }

  @override
  Future<List<BudgetVault>> findOverBudget() async {
    final vaults = await findActive();
    return vaults.where((v) => v.spentAmount > v.allocatedAmount).toList();
  }

  @override
  Future<void> resetPeriod(String vaultId) async {
    final db = await _db;
    await db.update('vaults', {'spentAmount': 0}, where: 'id = ?', whereArgs: [vaultId]);
  }

  @override
  Future<List<VaultTransaction>> getTransactionHistory(String vaultId, {DateTime? start, DateTime? end}) async {
    final db = await _db;
    String where = 'vaultId = ?';
    final whereArgs = <dynamic>[vaultId];

    if (start != null) {
      where += ' AND transactionDate >= ?';
      whereArgs.add(start.toIso8601String());
    }
    if (end != null) {
      where += ' AND transactionDate <= ?';
      whereArgs.add(end.toIso8601String());
    }

    final maps = await db.query('vault_transactions', where: where, whereArgs: whereArgs, orderBy: 'transactionDate DESC');
    return maps.map((m) => VaultTransaction(
      id: m['id'] as String,
      vaultId: m['vaultId'] as String,
      type: VaultTransactionType.values[m['type'] as int],
      amount: (m['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(m['transactionDate'] as String),
      note: m['note'] as String?,
      relatedTransactionId: m['relatedTransactionId'] as String?,
    )).toList();
  }
}

// ==================== Import Batch Repository ====================

/// 导入批次仓库实现
class ImportBatchRepository implements IImportBatchRepository {
  final Future<Database> Function() _databaseProvider;

  ImportBatchRepository(this._databaseProvider);

  Future<Database> get _db => _databaseProvider();

  @override
  Future<ImportBatch?> findById(String id) async {
    final db = await _db;
    final maps = await db.query('import_batches', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return ImportBatch.fromMap(maps.first);
  }

  @override
  Future<List<ImportBatch>> findAll({bool includeDeleted = false}) async {
    final db = await _db;
    final maps = await db.query('import_batches', where: includeDeleted ? null : 'isDeleted = 0');
    return maps.map((m) => ImportBatch.fromMap(m)).toList();
  }

  @override
  Future<int> insert(ImportBatch entity) async {
    final db = await _db;
    return await db.insert('import_batches', entity.toMap());
  }

  @override
  Future<void> insertAll(List<ImportBatch> entities) async {
    final db = await _db;
    final batch = db.batch();
    for (final e in entities) {
      batch.insert('import_batches', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> update(ImportBatch entity) async {
    final db = await _db;
    return await db.update('import_batches', entity.toMap(), where: 'id = ?', whereArgs: [entity.id]);
  }

  @override
  Future<int> delete(String id) async {
    final db = await _db;
    return await db.delete('import_batches', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> softDelete(String id) async {
    final db = await _db;
    return await db.update('import_batches', {'isDeleted': 1}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> restore(String id) async {
    final db = await _db;
    return await db.update('import_batches', {'isDeleted': 0}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<bool> exists(String id) async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM import_batches WHERE id = ?', [id]);
    return (r.first['c'] as int) > 0;
  }

  @override
  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM import_batches WHERE isDeleted = 0');
    return r.first['c'] as int;
  }

  @override
  Future<List<ImportBatch>> findBySource(String source) async {
    final db = await _db;
    final maps = await db.query('import_batches', where: 'fileFormat = ? AND isDeleted = 0', whereArgs: [source]);
    return maps.map((m) => ImportBatch.fromMap(m)).toList();
  }

  @override
  Future<List<ImportBatch>> findByStatus(ImportStatus status) async {
    final db = await _db;
    final maps = await db.query('import_batches', where: 'status = ? AND isDeleted = 0', whereArgs: [status.index]);
    return maps.map((m) => ImportBatch.fromMap(m)).toList();
  }

  @override
  Future<List<ImportBatch>> findByDateRange(DateTime start, DateTime end) async {
    final db = await _db;
    final maps = await db.query(
      'import_batches',
      where: 'createdAt >= ? AND createdAt <= ? AND isDeleted = 0',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return maps.map((m) => ImportBatch.fromMap(m)).toList();
  }

  @override
  Future<List<ImportBatch>> findRecent({int limit = 10}) async {
    final db = await _db;
    final maps = await db.query('import_batches', where: 'isDeleted = 0', orderBy: 'createdAt DESC', limit: limit);
    return maps.map((m) => ImportBatch.fromMap(m)).toList();
  }

  @override
  Future<ImportStatistics> getStatistics() async {
    final db = await _db;
    final batches = await db.rawQuery('SELECT COUNT(*) as c FROM import_batches WHERE isDeleted = 0');
    final records = await db.rawQuery('SELECT COALESCE(SUM(totalCount), 0) as t FROM import_batches WHERE isDeleted = 0');
    final success = await db.rawQuery('SELECT COALESCE(SUM(importedCount), 0) as t FROM import_batches WHERE isDeleted = 0');
    final failed = await db.rawQuery('SELECT COALESCE(SUM(failedCount), 0) as t FROM import_batches WHERE isDeleted = 0');
    final duplicate = await db.rawQuery('SELECT COALESCE(SUM(skippedCount), 0) as t FROM import_batches WHERE isDeleted = 0');

    return ImportStatistics(
      totalBatches: batches.first['c'] as int,
      totalRecords: (records.first['t'] as num).toInt(),
      successfulRecords: (success.first['t'] as num).toInt(),
      failedRecords: (failed.first['t'] as num).toInt(),
      duplicateRecords: (duplicate.first['t'] as num).toInt(),
    );
  }

  @override
  Future<void> updateStatus(String batchId, ImportStatus status) async {
    final db = await _db;
    await db.update('import_batches', {'status': status.index}, where: 'id = ?', whereArgs: [batchId]);
  }

  @override
  Future<void> updateProgress(String batchId, {int? processedCount, int? successCount, int? failedCount, int? duplicateCount}) async {
    final db = await _db;
    final updates = <String, dynamic>{};
    if (processedCount != null) updates['processedCount'] = processedCount;
    if (successCount != null) updates['importedCount'] = successCount;
    if (failedCount != null) updates['failedCount'] = failedCount;
    if (duplicateCount != null) updates['skippedCount'] = duplicateCount;
    if (updates.isEmpty) return;
    await db.update('import_batches', updates, where: 'id = ?', whereArgs: [batchId]);
  }

  @override
  Future<List<ImportRecord>> getRecords(String batchId) async {
    final db = await _db;
    final maps = await db.query('import_records', where: 'batchId = ?', whereArgs: [batchId]);
    return maps.map((m) => _importRecordFromMap(m)).toList();
  }

  @override
  Future<void> addRecord(String batchId, ImportRecord record) async {
    final db = await _db;
    await db.insert('import_records', _importRecordToMap(record));
  }

  @override
  Future<List<ImportRecord>> getFailedRecords(String batchId) async {
    final db = await _db;
    final maps = await db.query('import_records', where: 'batchId = ? AND status = ?', whereArgs: [batchId, ImportRecordStatus.failed.index]);
    return maps.map((m) => _importRecordFromMap(m)).toList();
  }

  @override
  Future<List<ImportRecord>> getDuplicateRecords(String batchId) async {
    final db = await _db;
    final maps = await db.query('import_records', where: 'batchId = ? AND status = ?', whereArgs: [batchId, ImportRecordStatus.duplicate.index]);
    return maps.map((m) => _importRecordFromMap(m)).toList();
  }

  @override
  Future<void> retryFailed(String batchId) async {
    // Simplified: do nothing
  }

  @override
  Future<void> cancel(String batchId) async {
    await updateStatus(batchId, ImportStatus.cancelled);
  }

  ImportRecord _importRecordFromMap(Map<String, dynamic> map) {
    return ImportRecord(
      id: map['id'] as String,
      batchId: map['batchId'] as String,
      rawData: map['rawData'] != null ? jsonDecode(map['rawData'] as String) as Map<String, dynamic> : {},
      status: ImportRecordStatus.values[map['status'] as int? ?? 0],
      errorMessage: map['errorMessage'] as String?,
      transactionId: map['transactionId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  Map<String, dynamic> _importRecordToMap(ImportRecord record) {
    return {
      'id': record.id,
      'batchId': record.batchId,
      'rawData': jsonEncode(record.rawData),
      'status': record.status.index,
      'errorMessage': record.errorMessage,
      'transactionId': record.transactionId,
      'createdAt': record.createdAt.millisecondsSinceEpoch,
    };
  }
}
