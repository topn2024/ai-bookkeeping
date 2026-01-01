import 'package:flutter/material.dart';
import '../models/transaction.dart';

/// 日期时间工具类
///
/// 提供常用的日期计算和范围操作，消除代码中重复的日期逻辑
class AppDateUtils {
  // ==================== 时区处理 ====================

  /// 北京时区偏移（UTC+8）
  static const Duration beijingOffset = Duration(hours: 8);

  /// 解析服务器返回的日期时间（北京时间）为本地时间
  ///
  /// 服务器使用北京时间存储和返回日期，此方法将其转换为用户本地时间
  static DateTime parseServerDateTime(String? dateStr, [String? timeStr]) {
    if (dateStr == null || dateStr.isEmpty) return DateTime.now();

    try {
      DateTime date;
      if (dateStr.contains('T')) {
        // ISO 8601 format with time
        date = DateTime.parse(dateStr);
      } else {
        // Date only format (YYYY-MM-DD)
        date = DateTime.parse(dateStr);
      }

      // Apply time if provided
      if (timeStr != null && timeStr.isNotEmpty) {
        final timeParts = timeStr.split(':');
        if (timeParts.length >= 2) {
          date = DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
            timeParts.length > 2 ? int.parse(timeParts[2].split('.')[0]) : 0,
          );
        }
      }

      // Server time is Beijing time (UTC+8)
      // Convert to UTC first, then to local
      final utcTime = date.subtract(beijingOffset);
      return utcTime.toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }

  /// 将本地时间转换为服务器时间（北京时间）格式
  static String toServerDateString(DateTime localDateTime) {
    // Convert local time to UTC, then to Beijing time
    final utcTime = localDateTime.toUtc();
    final beijingTime = utcTime.add(beijingOffset);
    return '${beijingTime.year}-${beijingTime.month.toString().padLeft(2, '0')}-${beijingTime.day.toString().padLeft(2, '0')}';
  }

  /// 将本地时间转换为服务器时间格式（时间部分）
  static String toServerTimeString(DateTime localDateTime) {
    final utcTime = localDateTime.toUtc();
    final beijingTime = utcTime.add(beijingOffset);
    return '${beijingTime.hour.toString().padLeft(2, '0')}:${beijingTime.minute.toString().padLeft(2, '0')}:${beijingTime.second.toString().padLeft(2, '0')}';
  }

  // ==================== AI识别日期解析 ====================

  /// 解析AI识别的日期字符串（支持相对日期和绝对日期）
  ///
  /// 支持的格式：
  /// - 相对日期：今天、昨天、前天、大前天、明天、后天、today、yesterday、tomorrow
  /// - 完整日期：YYYY-MM-DD、YYYY/MM/DD、YYYY年MM月DD日
  /// - 短日期：MM-DD、MM/DD、MM月DD日（使用当前年份）
  static DateTime parseRecognizedDate(String? dateStr) {
    final now = DateTime.now();
    if (dateStr == null || dateStr.isEmpty) return now;

    final trimmedStr = dateStr.trim();
    final lowerStr = trimmedStr.toLowerCase();

    // 相对日期（中文和英文）
    if (lowerStr == '今天' || lowerStr == 'today') return now;
    if (lowerStr == '昨天' || lowerStr == 'yesterday') {
      return now.subtract(const Duration(days: 1));
    }
    if (lowerStr == '前天') return now.subtract(const Duration(days: 2));
    if (lowerStr == '大前天') return now.subtract(const Duration(days: 3));
    if (lowerStr == '明天' || lowerStr == 'tomorrow') {
      return now.add(const Duration(days: 1));
    }
    if (lowerStr == '后天') return now.add(const Duration(days: 2));

    // 日期格式正则表达式列表（按优先级排序）
    final patterns = [
      // 完整日期格式
      (RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$'), true),  // YYYY-MM-DD or YYYY/MM/DD
      (RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日?$'), true),   // YYYY年MM月DD日
      // 短日期格式（使用当前年份）
      (RegExp(r'^(\d{1,2})[-/](\d{1,2})$'), false),            // MM-DD or MM/DD
      (RegExp(r'^(\d{1,2})月(\d{1,2})日?$'), false),           // MM月DD日
    ];

    for (final (pattern, hasYear) in patterns) {
      final match = pattern.firstMatch(trimmedStr);
      if (match != null) {
        try {
          if (hasYear) {
            return DateTime(
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
              int.parse(match.group(3)!),
            );
          } else {
            return DateTime(
              now.year,
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
            );
          }
        } catch (_) {
          continue;
        }
      }
    }

    // 尝试标准 DateTime.parse
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return now;
    }
  }
  // ==================== 月份计算 ====================

  /// 获取月份起始日期
  static DateTime monthStart(int year, int month) {
    return DateTime(year, month, 1);
  }

  /// 获取月份结束日期（当月最后一天 23:59:59）
  static DateTime monthEnd(int year, int month) {
    return DateTime(year, month + 1, 0, 23, 59, 59);
  }

  /// 获取当月时间范围
  static DateTimeRange currentMonth() {
    final now = DateTime.now();
    return DateTimeRange(
      start: monthStart(now.year, now.month),
      end: monthEnd(now.year, now.month),
    );
  }

  /// 获取指定月份的时间范围
  static DateTimeRange monthRange(int year, int month) {
    return DateTimeRange(
      start: monthStart(year, month),
      end: monthEnd(year, month),
    );
  }

  /// 获取上个月的时间范围
  static DateTimeRange previousMonth() {
    final now = DateTime.now();
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    return monthRange(prevYear, prevMonth);
  }

  // ==================== 周计算 ====================

  /// 获取周起止日期（周一到周日）
  static DateTimeRange weekRange(DateTime date) {
    final weekday = date.weekday;
    final start = DateTime(date.year, date.month, date.day - weekday + 1);
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateTimeRange(start: start, end: end);
  }

  /// 获取本周时间范围
  static DateTimeRange currentWeek() {
    return weekRange(DateTime.now());
  }

  /// 获取上周时间范围
  static DateTimeRange previousWeek() {
    return weekRange(DateTime.now().subtract(const Duration(days: 7)));
  }

  /// 计算日期是一年中的第几周
  static int weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDayOfYear).inDays;
    return (daysDiff / 7).ceil() + 1;
  }

  // ==================== 年度计算 ====================

  /// 获取年度起始日期
  static DateTime yearStart(int year) {
    return DateTime(year, 1, 1);
  }

  /// 获取年度结束日期
  static DateTime yearEnd(int year) {
    return DateTime(year, 12, 31, 23, 59, 59);
  }

  /// 获取本年度时间范围
  static DateTimeRange currentYear() {
    final now = DateTime.now();
    return DateTimeRange(
      start: yearStart(now.year),
      end: yearEnd(now.year),
    );
  }

  // ==================== 日期比较 ====================

  /// 判断是否在日期范围内
  static bool isInRange(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && !date.isAfter(end);
  }

  /// 判断是否在 DateTimeRange 内
  static bool isInDateTimeRange(DateTime date, DateTimeRange range) {
    return isInRange(date, range.start, range.end);
  }

  /// 判断是否同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 判断是否同一月
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  /// 判断是否同一年
  static bool isSameYear(DateTime a, DateTime b) {
    return a.year == b.year;
  }

  /// 判断是否是今天
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// 判断是否是本月
  static bool isCurrentMonth(DateTime date) {
    return isSameMonth(date, DateTime.now());
  }

  /// 判断是否是本年
  static bool isCurrentYear(DateTime date) {
    return isSameYear(date, DateTime.now());
  }

  // ==================== 日期格式化 ====================

  /// 获取月份名称
  static String monthName(int month, {bool short = false}) {
    const fullNames = [
      '',
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月'
    ];
    const shortNames = ['', '1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    return short ? shortNames[month] : fullNames[month];
  }

  /// 获取星期名称
  static String weekdayName(int weekday, {bool short = false}) {
    const fullNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    const shortNames = ['', '一', '二', '三', '四', '五', '六', '日'];
    return short ? shortNames[weekday] : fullNames[weekday];
  }

  // ==================== 日期计算 ====================

  /// 获取两个日期之间的天数
  static int daysBetween(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return bDate.difference(aDate).inDays.abs();
  }

  /// 获取两个日期之间的月数
  static int monthsBetween(DateTime a, DateTime b) {
    return (b.year - a.year) * 12 + b.month - a.month;
  }

  /// 添加月份
  static DateTime addMonths(DateTime date, int months) {
    var newMonth = date.month + months;
    var newYear = date.year;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear--;
    }

    final lastDayOfMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;

    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
  }

  /// 获取月份的天数
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// 生成日期范围内的所有日期
  static List<DateTime> generateDateRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  /// 生成月份范围内的所有月份
  static List<DateTime> generateMonthRange(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var current = DateTime(start.year, start.month);
    final endMonth = DateTime(end.year, end.month);

    while (!current.isAfter(endMonth)) {
      months.add(current);
      current = addMonths(current, 1);
    }
    return months;
  }
}

/// Transaction 日期过滤扩展方法
extension TransactionDateFilter on Iterable<Transaction> {
  /// 过滤指定日期的交易
  Iterable<Transaction> forDate(DateTime date) {
    return where((t) => AppDateUtils.isSameDay(t.date, date));
  }

  /// 过滤指定月份的交易
  Iterable<Transaction> forMonth(int year, int month) {
    return where((t) => t.date.year == year && t.date.month == month);
  }

  /// 过滤指定年份的交易
  Iterable<Transaction> forYear(int year) {
    return where((t) => t.date.year == year);
  }

  /// 过滤日期范围内的交易
  Iterable<Transaction> inRange(DateTime start, DateTime end) {
    return where((t) => AppDateUtils.isInRange(t.date, start, end));
  }

  /// 过滤 DateTimeRange 内的交易
  Iterable<Transaction> inDateTimeRange(DateTimeRange range) {
    return where((t) => AppDateUtils.isInDateTimeRange(t.date, range));
  }

  /// 当日交易
  Iterable<Transaction> get today {
    return where((t) => AppDateUtils.isToday(t.date));
  }

  /// 当月交易
  Iterable<Transaction> get currentMonth {
    final now = DateTime.now();
    return forMonth(now.year, now.month);
  }

  /// 当年交易
  Iterable<Transaction> get currentYear {
    return forYear(DateTime.now().year);
  }

  /// 本周交易
  Iterable<Transaction> get currentWeek {
    final range = AppDateUtils.currentWeek();
    return inDateTimeRange(range);
  }

  /// 上周交易
  Iterable<Transaction> get previousWeek {
    final range = AppDateUtils.previousWeek();
    return inDateTimeRange(range);
  }

  /// 上月交易
  Iterable<Transaction> get previousMonth {
    final range = AppDateUtils.previousMonth();
    return inDateTimeRange(range);
  }

  /// 最近N天的交易
  Iterable<Transaction> lastDays(int days) {
    final start = DateTime.now().subtract(Duration(days: days));
    return where((t) => t.date.isAfter(start));
  }

  /// 按日期分组
  Map<DateTime, List<Transaction>> get byDate {
    final result = <DateTime, List<Transaction>>{};
    for (final t in this) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      result.putIfAbsent(key, () => []).add(t);
    }
    return result;
  }

  /// 按月份分组
  Map<DateTime, List<Transaction>> get byMonth {
    final result = <DateTime, List<Transaction>>{};
    for (final t in this) {
      final key = DateTime(t.date.year, t.date.month);
      result.putIfAbsent(key, () => []).add(t);
    }
    return result;
  }

  /// 按年份分组
  Map<int, List<Transaction>> get byYear {
    final result = <int, List<Transaction>>{};
    for (final t in this) {
      result.putIfAbsent(t.date.year, () => []).add(t);
    }
    return result;
  }

  /// 按日期排序（最新在前）
  List<Transaction> get sortedByDateDesc {
    return toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 按日期排序（最早在前）
  List<Transaction> get sortedByDateAsc {
    return toList()..sort((a, b) => a.date.compareTo(b.date));
  }
}
