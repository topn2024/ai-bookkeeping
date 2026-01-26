import '../models/transaction.dart';

/// 本地钱龄计算器
/// 使用FIFO算法计算每日钱龄
class LocalMoneyAgeCalculator {
  /// 资源池（收入）
  final List<_ResourcePool> _pools = [];

  /// 每日钱龄记录
  final Map<DateTime, List<double>> _dailyMoneyAges = {};

  /// 计算交易列表的每日钱龄
  /// 返回 Map<日期, 平均钱龄>
  Map<DateTime, int> calculateDailyMoneyAge(List<Transaction> transactions) {
    // 清空之前的数据
    _pools.clear();
    _dailyMoneyAges.clear();

    // 按日期排序
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // 处理每笔交易
    for (final transaction in sortedTransactions) {
      if (transaction.type == TransactionType.income) {
        _addIncome(transaction);
      } else if (transaction.type == TransactionType.expense) {
        _processExpense(transaction);
      }
    }

    // 计算每日平均钱龄
    final result = <DateTime, int>{};
    for (final entry in _dailyMoneyAges.entries) {
      final date = entry.key;
      final moneyAges = entry.value;
      if (moneyAges.isNotEmpty) {
        final avgAge = moneyAges.reduce((a, b) => a + b) / moneyAges.length;
        result[date] = avgAge.round();
      }
    }

    return result;
  }

  /// 添加收入（创建资源池）
  void _addIncome(Transaction transaction) {
    _pools.add(_ResourcePool(
      date: transaction.date,
      amount: transaction.amount,
      remaining: transaction.amount,
    ));
  }

  /// 处理支出（消耗资源池）
  void _processExpense(Transaction transaction) {
    double remainingExpense = transaction.amount;
    double totalWeightedAge = 0;

    // 移除已完全消耗的资源池
    _pools.removeWhere((pool) => pool.remaining <= 0.01);

    // 按FIFO顺序消耗资源池
    for (final pool in _pools) {
      if (remainingExpense <= 0.01) break;

      final consumeAmount = remainingExpense < pool.remaining
          ? remainingExpense
          : pool.remaining;

      // 计算这部分消费的钱龄（天数）
      final ageInDays = transaction.date.difference(pool.date).inDays;
      totalWeightedAge += consumeAmount * ageInDays;

      pool.remaining -= consumeAmount;
      remainingExpense -= consumeAmount;
    }

    // 计算这笔支出的加权平均钱龄
    if (transaction.amount > 0.01) {
      final moneyAge = totalWeightedAge / transaction.amount;

      // 记录到当天
      final dateKey = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      if (!_dailyMoneyAges.containsKey(dateKey)) {
        _dailyMoneyAges[dateKey] = [];
      }
      _dailyMoneyAges[dateKey]!.add(moneyAge);
    }
  }

  /// 获取指定日期范围的钱龄数据
  List<MapEntry<DateTime, int>> getDailyMoneyAgeInRange(
    List<Transaction> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    final allDailyData = calculateDailyMoneyAge(transactions);
    final result = <MapEntry<DateTime, int>>[];

    // 过滤日期范围
    for (final entry in allDailyData.entries) {
      if (entry.key.isAfter(startDate.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(endDate.add(const Duration(days: 1)))) {
        result.add(entry);
      }
    }

    // 按日期排序
    result.sort((a, b) => a.key.compareTo(b.key));

    return result;
  }

  /// 获取最近N天的钱龄数据
  List<MapEntry<DateTime, int>> getRecentDailyMoneyAge(
    List<Transaction> transactions,
    int days,
  ) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    return getDailyMoneyAgeInRange(transactions, startDate, now);
  }
}

/// 资源池（内部使用）
class _ResourcePool {
  final DateTime date;
  final double amount;
  double remaining;

  _ResourcePool({
    required this.date,
    required this.amount,
    required this.remaining,
  });
}
