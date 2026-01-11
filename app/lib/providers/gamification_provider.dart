import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gamification_service.dart';
import 'transaction_provider.dart';

/// 游戏化统计 Provider
/// 从交易数据计算连续记账天数等统计信息
final gamificationProvider = Provider<StreakStats>((ref) {
  final transactions = ref.watch(transactionProvider);

  if (transactions.isEmpty) {
    return const StreakStats(
      currentStreak: 0,
      longestStreak: 0,
      totalDaysRecorded: 0,
      isActiveToday: false,
    );
  }

  // 获取所有有交易的日期（去重）
  final recordedDates = transactions
      .map((t) => _dateOnly(t.date))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a)); // 降序排列

  if (recordedDates.isEmpty) {
    return const StreakStats(
      currentStreak: 0,
      longestStreak: 0,
      totalDaysRecorded: 0,
      isActiveToday: false,
    );
  }

  final today = _dateOnly(DateTime.now());
  final lastDate = recordedDates.first;
  final isActiveToday = lastDate == today;

  // 计算当前连续天数
  int currentStreak = 0;
  var checkDate = isActiveToday ? today : today.subtract(const Duration(days: 1));

  for (final date in recordedDates) {
    if (date == checkDate) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else if (date.isBefore(checkDate)) {
      // 日期不连续，停止计数
      break;
    }
  }

  // 计算最长连续天数
  int longestStreak = 0;
  int tempStreak = 1;

  for (int i = 0; i < recordedDates.length - 1; i++) {
    final diff = recordedDates[i].difference(recordedDates[i + 1]).inDays;
    if (diff == 1) {
      tempStreak++;
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
      }
    } else {
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
      }
      tempStreak = 1;
    }
  }

  // 确保至少等于当前连续天数
  if (longestStreak < currentStreak) {
    longestStreak = currentStreak;
  }

  return StreakStats(
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    lastRecordDate: lastDate,
    totalDaysRecorded: recordedDates.length,
    isActiveToday: isActiveToday,
  );
});

/// 辅助函数：获取日期的零点时间
DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
