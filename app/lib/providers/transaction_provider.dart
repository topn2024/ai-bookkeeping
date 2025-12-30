import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../utils/aggregations.dart';
import '../utils/date_utils.dart';
import '../services/duplicate_detection_service.dart';
import 'base/crud_notifier.dart';
import 'account_provider.dart';

/// 交易管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，使用工具类简化聚合和日期操作
class TransactionNotifier extends SimpleCrudNotifier<Transaction, String> {
  @override
  String get tableName => 'transactions';

  @override
  String getId(Transaction entity) => entity.id;

  @override
  Future<List<Transaction>> fetchAll() => db.getTransactions();

  @override
  Future<void> insertOne(Transaction entity) => db.insertTransaction(entity);

  @override
  Future<void> updateOne(Transaction entity) => db.updateTransaction(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteTransaction(id);

  // ==================== 账户余额同步逻辑 ====================

  /// 更新账户余额（记账时调用）
  /// [isReverse] 为 true 时表示撤销操作（删除交易或更新前恢复原余额）
  Future<void> _updateAccountBalance(Transaction transaction, {bool isReverse = false}) async {
    final accountNotifier = ref.read(accountProvider.notifier);
    final accountId = transaction.accountId;

    // 转账类型需要特殊处理
    if (transaction.type == TransactionType.transfer) {
      final toAccountId = transaction.toAccountId;
      if (toAccountId != null) {
        if (isReverse) {
          // 撤销转账：从目标账户扣回，转入源账户
          await accountNotifier.updateBalance(toAccountId, transaction.amount, true);
          await accountNotifier.updateBalance(accountId, transaction.amount, false);
        } else {
          // 正向转账：从源账户扣除，转入目标账户
          await accountNotifier.updateBalance(accountId, transaction.amount, true);
          await accountNotifier.updateBalance(toAccountId, transaction.amount, false);
        }
      }
      return;
    }

    // 普通收支
    final isExpense = transaction.type == TransactionType.expense;
    if (isReverse) {
      // 撤销：支出恢复余额，收入扣除余额
      await accountNotifier.updateBalance(accountId, transaction.amount, !isExpense);
    } else {
      // 正向：支出扣除余额，收入增加余额
      await accountNotifier.updateBalance(accountId, transaction.amount, isExpense);
    }
  }

  // ==================== 业务特有方法（保留原有接口）====================

  /// 添加交易（保持原有方法名兼容）
  Future<void> addTransaction(Transaction transaction) async {
    await add(transaction);
    // 新交易放在列表前面
    state = [transaction, ...state.where((t) => t.id != transaction.id)];
    // 更新账户余额
    await _updateAccountBalance(transaction);
  }

  /// 更新交易（保持原有方法名兼容）
  Future<void> updateTransaction(Transaction transaction) async {
    // 先获取旧交易，恢复旧余额
    final oldTransaction = state.firstWhere(
      (t) => t.id == transaction.id,
      orElse: () => transaction,
    );
    if (oldTransaction.id == transaction.id && oldTransaction != transaction) {
      await _updateAccountBalance(oldTransaction, isReverse: true);
    }
    // 执行更新
    await update(transaction);
    // 应用新余额
    await _updateAccountBalance(transaction);
  }

  /// 删除交易（保持原有方法名兼容）
  Future<void> deleteTransaction(String id) async {
    // 先获取交易，恢复余额
    final transaction = state.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Transaction not found: $id'),
    );
    await _updateAccountBalance(transaction, isReverse: true);
    // 执行删除
    await delete(id);
  }

  // ==================== 重复检测方法 ====================

  /// 检查交易是否重复
  DuplicateCheckResult checkDuplicate(Transaction transaction) {
    return DuplicateDetectionService.checkDuplicate(transaction, state);
  }

  /// 快速检查是否需要详细的重复检测
  bool needsDuplicateCheck(Transaction transaction) {
    return DuplicateDetectionService.needsDetailedCheck(transaction, state);
  }

  /// 添加交易（带重复检测）
  /// 返回检测结果，UI层根据结果决定是否显示确认对话框
  Future<DuplicateCheckResult> addTransactionWithCheck(Transaction transaction) async {
    final checkResult = checkDuplicate(transaction);
    if (!checkResult.hasPotentialDuplicate) {
      await addTransaction(transaction);
    }
    return checkResult;
  }

  /// 强制添加交易（跳过重复检测）
  Future<void> forceAddTransaction(Transaction transaction) async {
    await addTransaction(transaction);
  }

  // ==================== 使用工具类简化的聚合方法 ====================

  /// 总支出（使用扩展方法）
  double get totalExpense => state.totalExpense;

  /// 总收入（使用扩展方法）
  double get totalIncome => state.totalIncome;

  /// 当月支出（使用扩展方法）
  double get monthlyExpense => state.currentMonth.totalExpense;

  /// 当月收入（使用扩展方法）
  double get monthlyIncome => state.currentMonth.totalIncome;

  /// 按分类汇总支出（使用扩展方法）
  Map<String, double> get expenseByCategory => state.expenseByCategory;

  /// 当月按分类汇总支出
  Map<String, double> get monthlyExpenseByCategory => state.currentMonth.toList().expenseByCategory;

  // ==================== 使用日期工具类简化的过滤方法 ====================

  /// 获取指定日期的交易
  List<Transaction> getTransactionsByDate(DateTime date) =>
      state.forDate(date).toList();

  /// 获取指定月份的交易
  List<Transaction> getTransactionsByMonth(int year, int month) =>
      state.forMonth(year, month).toList();

  /// 获取指定年份的交易
  List<Transaction> getTransactionsByYear(int year) =>
      state.forYear(year).toList();

  /// 获取指定周的交易
  List<Transaction> getTransactionsByWeek(DateTime weekStart) {
    final range = AppDateUtils.weekRange(weekStart);
    return state.inDateTimeRange(range).toList();
  }

  // ==================== 统计方法 ====================

  /// 获取日支出数据
  Map<DateTime, double> getDailyExpenses(int year, int month) {
    return Aggregations.sumBy(
      state.forMonth(year, month).expenses,
      (t) => DateTime(t.date.year, t.date.month, t.date.day),
      (t) => t.amount,
    );
  }

  /// 获取周支出数据
  Map<int, double> getWeeklyExpenses(int year) {
    return Aggregations.sumBy(
      state.forYear(year).expenses,
      (t) => AppDateUtils.weekOfYear(t.date),
      (t) => t.amount,
    );
  }

  /// 获取月支出数据
  Map<int, double> getMonthlyExpenses(int year) {
    return Aggregations.sumBy(
      state.forYear(year).expenses,
      (t) => t.date.month,
      (t) => t.amount,
    );
  }
}

final transactionProvider =
    NotifierProvider<TransactionNotifier, List<Transaction>>(
        TransactionNotifier.new);

// ==================== 派生 Providers（使用扩展方法简化）====================

final monthlyExpenseProvider = Provider<double>((ref) {
  return ref.watch(transactionProvider).currentMonth.totalExpense;
});

final monthlyIncomeProvider = Provider<double>((ref) {
  return ref.watch(transactionProvider).currentMonth.totalIncome;
});

final expenseByCategoryProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(transactionProvider).expenseByCategory;
});

final monthlyExpenseByCategoryProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(transactionProvider).currentMonth.toList().expenseByCategory;
});

// ============== 报销相关 Provider ==============

/// 报销统计数据
class ReimbursementStats {
  final double totalReimbursable;
  final double totalReimbursed;
  final double pendingReimbursement;
  final int reimbursableCount;
  final int reimbursedCount;
  final int pendingCount;
  final List<Transaction> pendingTransactions;
  final List<Transaction> reimbursedTransactions;

  ReimbursementStats({
    required this.totalReimbursable,
    required this.totalReimbursed,
    required this.pendingReimbursement,
    required this.reimbursableCount,
    required this.reimbursedCount,
    required this.pendingCount,
    required this.pendingTransactions,
    required this.reimbursedTransactions,
  });

  double get reimbursementRate =>
      totalReimbursable > 0 ? totalReimbursed / totalReimbursable : 0;
}

/// 从交易列表创建报销统计（提取公共逻辑）
ReimbursementStats _createReimbursementStats(Iterable<Transaction> transactions) {
  final reimbursable = transactions.where((t) => t.isReimbursable).toList();
  final reimbursed = reimbursable.where((t) => t.isReimbursed).toList();
  final pending = reimbursable.where((t) => !t.isReimbursed).toList();

  return ReimbursementStats(
    totalReimbursable: Aggregations.sum(reimbursable, (t) => t.amount),
    totalReimbursed: Aggregations.sum(reimbursed, (t) => t.amount),
    pendingReimbursement: Aggregations.sum(pending, (t) => t.amount),
    reimbursableCount: reimbursable.length,
    reimbursedCount: reimbursed.length,
    pendingCount: pending.length,
    pendingTransactions: pending,
    reimbursedTransactions: reimbursed,
  );
}

/// 报销统计 Provider（简化版）
final reimbursementStatsProvider = Provider<ReimbursementStats>((ref) {
  return _createReimbursementStats(ref.watch(transactionProvider));
});

/// 月度报销统计 Provider
final monthlyReimbursementStatsProvider =
    Provider.family<ReimbursementStats, DateTime>((ref, month) {
  final transactions = ref.watch(transactionProvider);
  return _createReimbursementStats(transactions.forMonth(month.year, month.month));
});

/// 按分类的报销统计
final reimbursementByCategoryProvider =
    Provider<Map<String, ReimbursementStats>>((ref) {
  final transactions = ref.watch(transactionProvider);
  final reimbursable = transactions.where((t) => t.isReimbursable);
  final grouped = Aggregations.groupBy(reimbursable, (t) => t.category);

  return grouped.map((category, txList) =>
      MapEntry(category, _createReimbursementStats(txList)));
});

// ============== 标签相关 Provider ==============

/// 标签统计数据
class TagStats {
  final String tag;
  final int transactionCount;
  final double totalAmount;
  final double expenseAmount;
  final double incomeAmount;
  final List<Transaction> transactions;

  TagStats({
    required this.tag,
    required this.transactionCount,
    required this.totalAmount,
    required this.expenseAmount,
    required this.incomeAmount,
    required this.transactions,
  });
}

/// 从交易列表创建标签统计（提取公共逻辑）
TagStats _createTagStats(String tag, List<Transaction> transactions) {
  return TagStats(
    tag: tag,
    transactionCount: transactions.length,
    totalAmount: Aggregations.sum(transactions, (t) => t.amount),
    expenseAmount: transactions.expenses.totalExpense,
    incomeAmount: transactions.incomes.totalIncome,
    transactions: transactions,
  );
}

/// 提取标签分组逻辑
Map<String, List<Transaction>> _groupByTag(Iterable<Transaction> transactions) {
  final tagMap = <String, List<Transaction>>{};
  for (final t in transactions) {
    if (t.tags != null) {
      for (final tag in t.tags!) {
        tagMap.putIfAbsent(tag, () => []).add(t);
      }
    }
  }
  return tagMap;
}

/// 获取所有标签列表
final allTagsProvider = Provider<List<String>>((ref) {
  final transactions = ref.watch(transactionProvider);
  final tagSet = <String>{};
  for (final t in transactions) {
    if (t.tags != null) {
      tagSet.addAll(t.tags!);
    }
  }
  return tagSet.toList()..sort();
});

/// 按标签分组的统计 Provider（简化版）
final tagStatisticsProvider = Provider<Map<String, TagStats>>((ref) {
  final transactions = ref.watch(transactionProvider);
  final tagMap = _groupByTag(transactions);
  return tagMap.map((tag, txList) => MapEntry(tag, _createTagStats(tag, txList)));
});

/// 按标签统计排序（按金额降序）
final tagStatisticsSortedProvider = Provider<List<TagStats>>((ref) {
  final tagStats = ref.watch(tagStatisticsProvider);
  return tagStats.values.toList()
    ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
});

/// 获取特定标签的交易
final transactionsByTagProvider =
    Provider.family<List<Transaction>, String>((ref, tag) {
  return ref
      .watch(transactionProvider)
      .where((t) => t.tags?.contains(tag) ?? false)
      .toList();
});

/// 月度标签统计（简化版）
final monthlyTagStatisticsProvider =
    Provider.family<Map<String, TagStats>, DateTime>((ref, month) {
  final transactions = ref.watch(transactionProvider);
  final monthTx = transactions.forMonth(month.year, month.month);
  final tagMap = _groupByTag(monthTx);
  return tagMap.map((tag, txList) => MapEntry(tag, _createTagStats(tag, txList)));
});
