import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class TransactionNotifier extends Notifier<List<Transaction>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<Transaction> build() {
    _loadTransactions();
    return [];
  }

  Future<void> _loadTransactions() async {
    final transactions = await _db.getTransactions();
    state = List<Transaction>.from(transactions);
  }

  Future<void> addTransaction(Transaction transaction) async {
    await _db.insertTransaction(transaction);
    state = [transaction, ...state];
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _db.updateTransaction(transaction);
    state = state.map((t) => t.id == transaction.id ? transaction : t).toList();
  }

  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
    state = state.where((t) => t.id != id).toList();
  }

  double get totalExpense {
    return state
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalIncome {
    return state
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlyExpense {
    final now = DateTime.now();
    return state
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get monthlyIncome {
    final now = DateTime.now();
    return state
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> get expenseByCategory {
    final map = <String, double>{};
    for (final t in state.where((t) => t.type == TransactionType.expense)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  Map<String, double> get monthlyExpenseByCategory {
    final now = DateTime.now();
    final map = <String, double>{};
    for (final t in state.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == now.year &&
        t.date.month == now.month)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  List<Transaction> getTransactionsByDate(DateTime date) {
    return state
        .where((t) =>
            t.date.year == date.year &&
            t.date.month == date.month &&
            t.date.day == date.day)
        .toList();
  }

  List<Transaction> getTransactionsByMonth(int year, int month) {
    return state
        .where((t) => t.date.year == year && t.date.month == month)
        .toList();
  }

  List<Transaction> getTransactionsByYear(int year) {
    return state.where((t) => t.date.year == year).toList();
  }

  List<Transaction> getTransactionsByWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return state
        .where((t) =>
            t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(weekEnd))
        .toList();
  }

  // 获取日支出数据
  Map<DateTime, double> getDailyExpenses(int year, int month) {
    final map = <DateTime, double>{};
    for (final t in state.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == year &&
        t.date.month == month)) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      map[date] = (map[date] ?? 0) + t.amount;
    }
    return map;
  }

  // 获取周支出数据
  Map<int, double> getWeeklyExpenses(int year) {
    final map = <int, double>{};
    for (final t in state.where((t) =>
        t.type == TransactionType.expense && t.date.year == year)) {
      final weekOfYear = _getWeekOfYear(t.date);
      map[weekOfYear] = (map[weekOfYear] ?? 0) + t.amount;
    }
    return map;
  }

  // 获取月支出数据
  Map<int, double> getMonthlyExpenses(int year) {
    final map = <int, double>{};
    for (final t in state.where((t) =>
        t.type == TransactionType.expense && t.date.year == year)) {
      map[t.date.month] = (map[t.date.month] ?? 0) + t.amount;
    }
    return map;
  }

  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDayOfYear).inDays;
    return (daysDiff / 7).ceil() + 1;
  }
}

final transactionProvider =
    NotifierProvider<TransactionNotifier, List<Transaction>>(
        TransactionNotifier.new);

// Derived providers
final monthlyExpenseProvider = Provider<double>((ref) {
  return ref.watch(transactionProvider.notifier).monthlyExpense;
});

final monthlyIncomeProvider = Provider<double>((ref) {
  return ref.watch(transactionProvider.notifier).monthlyIncome;
});

final expenseByCategoryProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(transactionProvider.notifier).expenseByCategory;
});

final monthlyExpenseByCategoryProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(transactionProvider.notifier).monthlyExpenseByCategory;
});

// ============== 报销相关 Provider ==============

/// 报销统计数据
class ReimbursementStats {
  final double totalReimbursable;    // 总可报销金额
  final double totalReimbursed;      // 已报销金额
  final double pendingReimbursement; // 待报销金额
  final int reimbursableCount;       // 可报销笔数
  final int reimbursedCount;         // 已报销笔数
  final int pendingCount;            // 待报销笔数
  final List<Transaction> pendingTransactions;   // 待报销交易
  final List<Transaction> reimbursedTransactions; // 已报销交易

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

/// 报销统计 Provider
final reimbursementStatsProvider = Provider<ReimbursementStats>((ref) {
  final transactions = ref.watch(transactionProvider);

  final reimbursableTransactions = transactions
      .where((t) => t.isReimbursable)
      .toList();

  final reimbursedTransactions = reimbursableTransactions
      .where((t) => t.isReimbursed)
      .toList();

  final pendingTransactions = reimbursableTransactions
      .where((t) => !t.isReimbursed)
      .toList();

  return ReimbursementStats(
    totalReimbursable: reimbursableTransactions.fold(0.0, (sum, t) => sum + t.amount),
    totalReimbursed: reimbursedTransactions.fold(0.0, (sum, t) => sum + t.amount),
    pendingReimbursement: pendingTransactions.fold(0.0, (sum, t) => sum + t.amount),
    reimbursableCount: reimbursableTransactions.length,
    reimbursedCount: reimbursedTransactions.length,
    pendingCount: pendingTransactions.length,
    pendingTransactions: pendingTransactions,
    reimbursedTransactions: reimbursedTransactions,
  );
});

/// 月度报销统计 Provider
final monthlyReimbursementStatsProvider = Provider.family<ReimbursementStats, DateTime>((ref, month) {
  final transactions = ref.watch(transactionProvider);

  final monthTransactions = transactions.where((t) =>
      t.date.year == month.year && t.date.month == month.month);

  final reimbursableTransactions = monthTransactions
      .where((t) => t.isReimbursable)
      .toList();

  final reimbursedTransactions = reimbursableTransactions
      .where((t) => t.isReimbursed)
      .toList();

  final pendingTransactions = reimbursableTransactions
      .where((t) => !t.isReimbursed)
      .toList();

  return ReimbursementStats(
    totalReimbursable: reimbursableTransactions.fold(0.0, (sum, t) => sum + t.amount),
    totalReimbursed: reimbursedTransactions.fold(0.0, (sum, t) => sum + t.amount),
    pendingReimbursement: pendingTransactions.fold(0.0, (sum, t) => sum + t.amount),
    reimbursableCount: reimbursableTransactions.length,
    reimbursedCount: reimbursedTransactions.length,
    pendingCount: pendingTransactions.length,
    pendingTransactions: pendingTransactions,
    reimbursedTransactions: reimbursedTransactions,
  );
});

/// 按分类的报销统计
final reimbursementByCategoryProvider = Provider<Map<String, ReimbursementStats>>((ref) {
  final transactions = ref.watch(transactionProvider);

  final reimbursableTransactions = transactions.where((t) => t.isReimbursable);

  final categoryMap = <String, List<Transaction>>{};
  for (final t in reimbursableTransactions) {
    categoryMap.putIfAbsent(t.category, () => []);
    categoryMap[t.category]!.add(t);
  }

  return categoryMap.map((category, txList) {
    final reimbursed = txList.where((t) => t.isReimbursed).toList();
    final pending = txList.where((t) => !t.isReimbursed).toList();

    return MapEntry(category, ReimbursementStats(
      totalReimbursable: txList.fold(0.0, (sum, t) => sum + t.amount),
      totalReimbursed: reimbursed.fold(0.0, (sum, t) => sum + t.amount),
      pendingReimbursement: pending.fold(0.0, (sum, t) => sum + t.amount),
      reimbursableCount: txList.length,
      reimbursedCount: reimbursed.length,
      pendingCount: pending.length,
      pendingTransactions: pending,
      reimbursedTransactions: reimbursed,
    ));
  });
});

// ============== 标签相关 Provider ==============

/// 标签统计数据
class TagStats {
  final String tag;
  final int transactionCount;     // 交易笔数
  final double totalAmount;       // 总金额
  final double expenseAmount;     // 支出金额
  final double incomeAmount;      // 收入金额
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

/// 按标签分组的统计 Provider
final tagStatisticsProvider = Provider<Map<String, TagStats>>((ref) {
  final transactions = ref.watch(transactionProvider);

  final tagMap = <String, List<Transaction>>{};

  for (final t in transactions) {
    if (t.tags != null) {
      for (final tag in t.tags!) {
        tagMap.putIfAbsent(tag, () => []);
        tagMap[tag]!.add(t);
      }
    }
  }

  return tagMap.map((tag, txList) {
    final expenses = txList.where((t) => t.type == TransactionType.expense);
    final incomes = txList.where((t) => t.type == TransactionType.income);

    return MapEntry(tag, TagStats(
      tag: tag,
      transactionCount: txList.length,
      totalAmount: txList.fold(0.0, (sum, t) => sum + t.amount),
      expenseAmount: expenses.fold(0.0, (sum, t) => sum + t.amount),
      incomeAmount: incomes.fold(0.0, (sum, t) => sum + t.amount),
      transactions: txList,
    ));
  });
});

/// 按标签统计排序（按金额降序）
final tagStatisticsSortedProvider = Provider<List<TagStats>>((ref) {
  final tagStats = ref.watch(tagStatisticsProvider);
  final statsList = tagStats.values.toList();
  statsList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  return statsList;
});

/// 获取特定标签的交易
final transactionsByTagProvider = Provider.family<List<Transaction>, String>((ref, tag) {
  final transactions = ref.watch(transactionProvider);
  return transactions.where((t) => t.tags?.contains(tag) ?? false).toList();
});

/// 月度标签统计
final monthlyTagStatisticsProvider = Provider.family<Map<String, TagStats>, DateTime>((ref, month) {
  final transactions = ref.watch(transactionProvider);

  final monthTransactions = transactions.where((t) =>
      t.date.year == month.year && t.date.month == month.month);

  final tagMap = <String, List<Transaction>>{};

  for (final t in monthTransactions) {
    if (t.tags != null) {
      for (final tag in t.tags!) {
        tagMap.putIfAbsent(tag, () => []);
        tagMap[tag]!.add(t);
      }
    }
  }

  return tagMap.map((tag, txList) {
    final expenses = txList.where((t) => t.type == TransactionType.expense);
    final incomes = txList.where((t) => t.type == TransactionType.income);

    return MapEntry(tag, TagStats(
      tag: tag,
      transactionCount: txList.length,
      totalAmount: txList.fold(0.0, (sum, t) => sum + t.amount),
      expenseAmount: expenses.fold(0.0, (sum, t) => sum + t.amount),
      incomeAmount: incomes.fold(0.0, (sum, t) => sum + t.amount),
      transactions: txList,
    ));
  });
});
