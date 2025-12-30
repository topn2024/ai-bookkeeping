/// 统计汇总基类
///
/// 提供通用的统计计算模式，减少各 Provider 中的重复代码
abstract class BaseSummary {
  const BaseSummary();

  /// 活跃项目数量
  int get activeCount;

  /// 已完成项目数量
  int get completedCount;

  /// 总项目数量
  int get totalCount => activeCount + completedCount;

  /// 是否为空
  bool get isEmpty => totalCount == 0;

  /// 是否非空
  bool get isNotEmpty => totalCount > 0;
}

/// 金额统计汇总
///
/// 适用于有目标金额和当前金额的场景（如储蓄目标、债务等）
abstract class AmountSummary extends BaseSummary {
  /// 目标总金额
  double get targetAmount;

  /// 当前金额
  double get currentAmount;

  /// 剩余金额
  double get remainingAmount => targetAmount - currentAmount;

  /// 完成进度 (0.0 - 1.0)
  double get progress => targetAmount > 0 ? currentAmount / targetAmount : 0.0;

  /// 完成百分比 (0 - 100)
  double get progressPercent => progress * 100;

  /// 是否已完成
  bool get isCompleted => currentAmount >= targetAmount;
}

/// 通用统计汇总实现
class GenericSummary extends BaseSummary {
  @override
  final int activeCount;

  @override
  final int completedCount;

  final double totalAmount;

  const GenericSummary({
    required this.activeCount,
    required this.completedCount,
    required this.totalAmount,
  });

  static final empty = GenericSummary(
    activeCount: 0,
    completedCount: 0,
    totalAmount: 0,
  );
}

/// 聚合工具类
///
/// 提供常用的列表聚合方法
class Aggregations {
  /// 按字段求和
  static double sumBy<T>(List<T> items, double Function(T) selector) {
    return items.fold(0.0, (sum, item) => sum + selector(item));
  }

  /// 按条件求和
  static double sumWhere<T>(
    List<T> items,
    bool Function(T) test,
    double Function(T) selector,
  ) {
    return items.where(test).fold(0.0, (sum, item) => sum + selector(item));
  }

  /// 按字段分组求和
  static Map<K, double> groupSum<T, K>(
    List<T> items,
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

  /// 计数
  static int countWhere<T>(List<T> items, bool Function(T) test) {
    return items.where(test).length;
  }

  /// 计算平均值
  static double average<T>(List<T> items, double Function(T) selector) {
    if (items.isEmpty) return 0.0;
    return sumBy(items, selector) / items.length;
  }

  /// 查找最大值
  static T? maxBy<T>(List<T> items, double Function(T) selector) {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => selector(a) > selector(b) ? a : b);
  }

  /// 查找最小值
  static T? minBy<T>(List<T> items, double Function(T) selector) {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => selector(a) < selector(b) ? a : b);
  }
}

/// 日期工具扩展
extension DateRangeExtension on DateTime {
  /// 获取当月开始日期
  DateTime get monthStart => DateTime(year, month, 1);

  /// 获取当月结束日期
  DateTime get monthEnd => DateTime(year, month + 1, 0, 23, 59, 59);

  /// 获取当周开始日期（周一）
  DateTime get weekStart => subtract(Duration(days: weekday - 1));

  /// 获取当周结束日期（周日）
  DateTime get weekEnd => add(Duration(days: 7 - weekday));

  /// 获取当年开始日期
  DateTime get yearStart => DateTime(year, 1, 1);

  /// 获取当年结束日期
  DateTime get yearEnd => DateTime(year, 12, 31, 23, 59, 59);

  /// 是否在指定日期范围内
  bool isInRange(DateTime start, DateTime end) {
    return !isBefore(start) && !isAfter(end);
  }

  /// 是否是同一天
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// 是否是同一月
  bool isSameMonth(DateTime other) {
    return year == other.year && month == other.month;
  }
}

/// 列表过滤扩展
extension ListFilterExtension<T> on List<T> {
  /// 获取满足条件的第一个元素，不存在返回 null
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  /// 按字段求和
  double sumBy(double Function(T) selector) => Aggregations.sumBy(this, selector);

  /// 按字段分组
  Map<K, List<T>> groupBy<K>(K Function(T) keySelector) {
    final result = <K, List<T>>{};
    for (final item in this) {
      final key = keySelector(item);
      result.putIfAbsent(key, () => []).add(item);
    }
    return result;
  }
}
