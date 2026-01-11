import '../../models/transaction.dart';
import '../../models/transaction_split.dart';
import '../../core/contracts/i_database_service.dart';
import '../contracts/i_transaction_repository.dart';

/// 交易 Repository 实现
///
/// 封装所有交易相关的数据库操作。
class TransactionRepository implements ITransactionRepository {
  final IDatabaseService _db;

  TransactionRepository(this._db);

  // ==================== IRepository 基础操作 ====================

  @override
  Future<List<Transaction>> findAll() => _db.getTransactions();

  @override
  Future<Transaction?> findById(String id) async {
    final transactions = await _db.getTransactions();
    try {
      return transactions.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insert(Transaction entity) => _db.insertTransaction(entity);

  @override
  Future<void> update(Transaction entity) => _db.updateTransaction(entity);

  @override
  Future<void> delete(String id) => _db.deleteTransaction(id);

  @override
  Future<bool> exists(String id) async {
    final transaction = await findById(id);
    return transaction != null;
  }

  @override
  Future<int> count() => _db.getTransactionCount();

  // ==================== ISoftDeleteRepository 操作 ====================

  @override
  Future<List<Transaction>> findAllIncludingDeleted() =>
      _db.getTransactions(includeDeleted: true);

  @override
  Future<void> softDelete(String id) => _db.softDeleteTransaction(id);

  @override
  Future<void> restore(String id) => _db.restoreTransaction(id);

  @override
  Future<void> purge(String id) => _db.deleteTransaction(id);

  @override
  Future<List<Transaction>> findDeleted() async {
    final all = await _db.getTransactions(includeDeleted: true);
    final active = await _db.getTransactions(includeDeleted: false);
    final activeIds = active.map((t) => t.id).toSet();
    return all.where((t) => !activeIds.contains(t.id)).toList();
  }

  // ==================== IBatchRepository 操作 ====================

  @override
  Future<void> insertAll(List<Transaction> entities) =>
      _db.batchInsertTransactions(entities);

  @override
  Future<void> updateAll(List<Transaction> entities) async {
    for (final entity in entities) {
      await _db.updateTransaction(entity);
    }
  }

  @override
  Future<void> deleteAll(List<String> ids) async {
    for (final id in ids) {
      await _db.deleteTransaction(id);
    }
  }

  // ==================== 查询操作 ====================

  @override
  Future<List<Transaction>> findByDateRange(DateTime start, DateTime end) async {
    final transactions = await _db.getTransactions();
    return transactions.where((t) {
      return t.date.isAfter(start.subtract(const Duration(days: 1))) &&
          t.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Future<List<Transaction>> findByAccountId(String accountId) async {
    final transactions = await _db.getTransactions();
    return transactions.where((t) => t.accountId == accountId).toList();
  }

  @override
  Future<List<Transaction>> findByCategory(String category) async {
    final transactions = await _db.getTransactions();
    return transactions.where((t) => t.category == category).toList();
  }

  @override
  Future<List<Transaction>> findByLedgerId(String ledgerId) async {
    // Transaction 模型当前通过数据库 ledgerId 字段关联 Ledger
    // 由于 Transaction 模型不包含 ledgerId 属性，需要通过 rawQuery 查询
    // 然后使用 getTransactions 获取完整对象
    // TODO: 优化为直接从数据库结果构建 Transaction 对象
    final all = await _db.getTransactions();
    // 临时实现：返回所有交易
    return all;
  }

  @override
  Future<List<Transaction>> findByType(TransactionType type) async {
    final transactions = await _db.getTransactions();
    return transactions.where((t) => t.type == type).toList();
  }

  @override
  Future<List<Transaction>> findByBatchId(String batchId) =>
      _db.getTransactionsByBatchId(batchId);

  @override
  Future<Transaction?> findFirst() => _db.getFirstTransaction();

  // ==================== 统计操作 ====================

  @override
  Future<double> sumExpenseByDateRange(DateTime start, DateTime end) async {
    final transactions = await findByDateRange(start, end);
    double total = 0.0;
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        total += t.amount;
      }
    }
    return total;
  }

  @override
  Future<double> sumIncomeByDateRange(DateTime start, DateTime end) async {
    final transactions = await findByDateRange(start, end);
    double total = 0.0;
    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        total += t.amount;
      }
    }
    return total;
  }

  @override
  Future<double> sumByCategory(
      String category, DateTime start, DateTime end) async {
    final transactions = await findByDateRange(start, end);
    double total = 0.0;
    for (final t in transactions) {
      if (t.category == category) {
        total += t.amount;
      }
    }
    return total;
  }

  // ==================== 拆分交易 ====================

  @override
  Future<void> insertSplit(TransactionSplit split) =>
      _db.insertTransactionSplit(split);

  @override
  Future<List<TransactionSplit>> findSplitsByTransactionId(
          String transactionId) =>
      _db.getTransactionSplits(transactionId);

  @override
  Future<void> deleteSplitsByTransactionId(String transactionId) =>
      _db.deleteTransactionSplits(transactionId);
}
