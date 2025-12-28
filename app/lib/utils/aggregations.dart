import '../models/transaction.dart';

/// 通用数据聚合工具类
///
/// 提供常用的聚合计算方法，消除代码中重复的 fold/map/where 操作
class Aggregations {
  /// 按字段分组求和
  ///
  /// 示例:
  /// ```dart
  /// final expenseByCategory = Aggregations.sumBy<Transaction, String>(
  ///   transactions,
  ///   (t) => t.category,
  ///   (t) => t.amount,
  /// );
  /// ```
  static Map<K, double> sumBy<T, K>(
    Iterable<T> items,
    K Function(T) keySelector,
    double Function(T) valueSelector,
  ) {
    final result = <K, double>{};
    for (final item in items) {
      final key = keySelector(item);
      result[key] = (result[key] ?? 0) + valueSelector(item);
    }
    return result;
  }

  /// 按字段分组计数
  static Map<K, int> countBy<T, K>(
    Iterable<T> items,
    K Function(T) keySelector,
  ) {
    final result = <K, int>{};
    for (final item in items) {
      final key = keySelector(item);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  /// 按字段分组
  static Map<K, List<T>> groupBy<T, K>(
    Iterable<T> items,
    K Function(T) keySelector,
  ) {
    final result = <K, List<T>>{};
    for (final item in items) {
      final key = keySelector(item);
      result.putIfAbsent(key, () => []).add(item);
    }
    return result;
  }

  /// 计算总和
  static double sum<T>(
    Iterable<T> items,
    double Function(T) selector,
  ) {
    return items.fold(0.0, (sum, item) => sum + selector(item));
  }

  /// 带条件的总和
  static double sumWhere<T>(
    Iterable<T> items,
    bool Function(T) predicate,
    double Function(T) selector,
  ) {
    return items.where(predicate).fold(0.0, (sum, item) => sum + selector(item));
  }

  /// 计算平均值
  static double average<T>(
    Iterable<T> items,
    double Function(T) selector,
  ) {
    if (items.isEmpty) return 0;
    return sum(items, selector) / items.length;
  }

  /// 查找最大值
  static T? maxBy<T>(
    Iterable<T> items,
    double Function(T) selector,
  ) {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => selector(a) >= selector(b) ? a : b);
  }

  /// 查找最小值
  static T? minBy<T>(
    Iterable<T> items,
    double Function(T) selector,
  ) {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => selector(a) <= selector(b) ? a : b);
  }

  /// 获取前N个（按数值降序）
  static List<T> topN<T>(
    Iterable<T> items,
    double Function(T) selector,
    int n,
  ) {
    final sorted = items.toList()..sort((a, b) => selector(b).compareTo(selector(a)));
    return sorted.take(n).toList();
  }

  /// 计算百分比分布
  static Map<K, double> percentageBy<T, K>(
    Iterable<T> items,
    K Function(T) keySelector,
    double Function(T) valueSelector,
  ) {
    final totals = sumBy(items, keySelector, valueSelector);
    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);
    if (grandTotal == 0) return {};

    return totals.map((key, value) => MapEntry(key, value / grandTotal * 100));
  }
}

/// Transaction 专用聚合扩展方法
extension TransactionAggregations on Iterable<Transaction> {
  /// 支出总额
  double get totalExpense => Aggregations.sumWhere(
        this,
        (t) => t.type == TransactionType.expense,
        (t) => t.amount,
      );

  /// 收入总额
  double get totalIncome => Aggregations.sumWhere(
        this,
        (t) => t.type == TransactionType.income,
        (t) => t.amount,
      );

  /// 净收入（收入 - 支出）
  double get netIncome => totalIncome - totalExpense;

  /// 转账总额
  double get totalTransfer => Aggregations.sumWhere(
        this,
        (t) => t.type == TransactionType.transfer,
        (t) => t.amount,
      );

  /// 按分类汇总支出
  Map<String, double> get expenseByCategory => Aggregations.sumBy(
        where((t) => t.type == TransactionType.expense),
        (t) => t.category,
        (t) => t.amount,
      );

  /// 按分类汇总收入
  Map<String, double> get incomeByCategory => Aggregations.sumBy(
        where((t) => t.type == TransactionType.income),
        (t) => t.category,
        (t) => t.amount,
      );

  /// 按账户汇总支出
  Map<String, double> get expenseByAccount => Aggregations.sumBy(
        where((t) => t.type == TransactionType.expense),
        (t) => t.accountId,
        (t) => t.amount,
      );

  /// 按月份汇总
  Map<DateTime, double> get expenseByMonth => Aggregations.sumBy(
        where((t) => t.type == TransactionType.expense),
        (t) => DateTime(t.date.year, t.date.month),
        (t) => t.amount,
      );

  /// 按标签汇总
  Map<String, double> get expenseByTag {
    final result = <String, double>{};
    for (final t in where((t) => t.type == TransactionType.expense)) {
      if (t.tags != null) {
        for (final tag in t.tags!) {
          result[tag] = (result[tag] ?? 0) + t.amount;
        }
      }
    }
    return result;
  }

  /// 可报销金额
  double get reimbursableAmount => Aggregations.sumWhere(
        this,
        (t) => t.isReimbursable && !t.isReimbursed,
        (t) => t.amount,
      );

  /// 已报销金额
  double get reimbursedAmount => Aggregations.sumWhere(
        this,
        (t) => t.isReimbursable && t.isReimbursed,
        (t) => t.amount,
      );

  /// 待报销金额
  double get pendingReimbursement => Aggregations.sumWhere(
        this,
        (t) => t.isReimbursable && !t.isReimbursed,
        (t) => t.amount,
      );

  /// 支出分类百分比
  Map<String, double> get expenseCategoryPercentage => Aggregations.percentageBy(
        where((t) => t.type == TransactionType.expense),
        (t) => t.category,
        (t) => t.amount,
      );

  /// 按交易类型分组
  Map<TransactionType, List<Transaction>> get byType => Aggregations.groupBy(
        this,
        (t) => t.type,
      );

  /// 支出交易列表
  Iterable<Transaction> get expenses => where((t) => t.type == TransactionType.expense);

  /// 收入交易列表
  Iterable<Transaction> get incomes => where((t) => t.type == TransactionType.income);

  /// 转账交易列表
  Iterable<Transaction> get transfers => where((t) => t.type == TransactionType.transfer);

  /// 交易数量统计
  Map<TransactionType, int> get countByType => Aggregations.countBy(this, (t) => t.type);
}

/// 数值列表扩展
extension NumericListExtensions on Iterable<double> {
  double get sum => fold(0.0, (a, b) => a + b);
  double get average => isEmpty ? 0 : sum / length;
  double get max => isEmpty ? 0 : reduce((a, b) => a >= b ? a : b);
  double get min => isEmpty ? 0 : reduce((a, b) => a <= b ? a : b);
}
