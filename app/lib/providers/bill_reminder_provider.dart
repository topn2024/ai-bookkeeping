import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill_reminder.dart';
import '../services/database_service.dart';

class BillReminderNotifier extends Notifier<List<BillReminder>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<BillReminder> build() {
    _loadReminders();
    return [];
  }

  Future<void> _loadReminders() async {
    final reminders = await _db.getBillReminders();
    state = reminders;
  }

  Future<void> addReminder(BillReminder reminder) async {
    await _db.insertBillReminder(reminder);
    state = [...state, reminder];
  }

  Future<void> updateReminder(BillReminder reminder) async {
    await _db.updateBillReminder(reminder);
    state = state.map((r) => r.id == reminder.id ? reminder : r).toList();
  }

  Future<void> deleteReminder(String id) async {
    await _db.deleteBillReminder(id);
    state = state.where((r) => r.id != id).toList();
  }

  Future<void> toggleReminder(String id) async {
    final reminder = state.firstWhere((r) => r.id == id);
    final updated = reminder.copyWith(isEnabled: !reminder.isEnabled);
    await updateReminder(updated);
  }

  /// 标记为已提醒
  Future<void> markAsReminded(String id) async {
    final reminder = state.firstWhere((r) => r.id == id);
    final updated = reminder.copyWith(
      lastRemindedAt: DateTime.now(),
      nextReminderDate: _calculateNextReminderDate(reminder),
    );
    await updateReminder(updated);
  }

  DateTime? _calculateNextReminderDate(BillReminder reminder) {
    if (reminder.frequency == ReminderFrequency.once) {
      return null; // 一次性提醒不再有下一次
    }
    // 根据频率计算下一次提醒日期
    final nextBill = reminder.nextBillDate;
    return nextBill.subtract(Duration(days: reminder.reminderDaysBefore));
  }

  /// 获取启用的提醒
  List<BillReminder> get enabledReminders =>
      state.where((r) => r.isEnabled).toList();

  /// 获取今日到期的账单
  List<BillReminder> get dueTodayReminders =>
      enabledReminders.where((r) => r.isDueToday).toList();

  /// 获取即将到期的账单
  List<BillReminder> get dueSoonReminders =>
      enabledReminders.where((r) => r.isDueSoon && !r.isDueToday).toList();

  /// 获取已过期的账单
  List<BillReminder> get overdueReminders =>
      enabledReminders.where((r) => r.isOverdue).toList();

  /// 获取需要提醒的账单（今天应该发送提醒的）
  List<BillReminder> get remindersToNotify {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return enabledReminders.where((r) {
      if (r.isOverdue) return false;

      final reminderDate = r.nextBillDate.subtract(
        Duration(days: r.reminderDaysBefore),
      );
      final reminderDay = DateTime(reminderDate.year, reminderDate.month, reminderDate.day);

      // 如果今天是提醒日，且今天还没提醒过
      if (reminderDay == today || reminderDay.isBefore(today)) {
        if (r.lastRemindedAt == null) return true;
        final lastRemindedDay = DateTime(
          r.lastRemindedAt!.year,
          r.lastRemindedAt!.month,
          r.lastRemindedAt!.day,
        );
        return lastRemindedDay.isBefore(today);
      }
      return false;
    }).toList();
  }

  /// 按类型分组的账单
  Map<BillReminderType, List<BillReminder>> get remindersByType {
    final result = <BillReminderType, List<BillReminder>>{};
    for (final type in BillReminderType.values) {
      final items = enabledReminders.where((r) => r.type == type).toList();
      if (items.isNotEmpty) {
        result[type] = items;
      }
    }
    return result;
  }

  /// 本月账单总额
  double get monthlyTotal {
    return enabledReminders
        .where((r) => r.frequency == ReminderFrequency.monthly ||
                      r.frequency == ReminderFrequency.weekly)
        .fold(0.0, (sum, r) {
          if (r.frequency == ReminderFrequency.weekly) {
            return sum + (r.amount * 4); // 每周约4次
          }
          return sum + r.amount;
        });
  }

  /// 年度账单总额
  double get yearlyTotal {
    return enabledReminders.fold(0.0, (sum, r) {
      switch (r.frequency) {
        case ReminderFrequency.daily:
          return sum + (r.amount * 365);
        case ReminderFrequency.weekly:
          return sum + (r.amount * 52);
        case ReminderFrequency.monthly:
          return sum + (r.amount * 12);
        case ReminderFrequency.yearly:
          return sum + r.amount;
        case ReminderFrequency.once:
          return sum + r.amount;
      }
    });
  }

  BillReminder? getById(String id) {
    try {
      return state.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }
}

final billReminderProvider =
    NotifierProvider<BillReminderNotifier, List<BillReminder>>(
        BillReminderNotifier.new);

/// 今日到期账单
final dueTodayProvider = Provider<List<BillReminder>>((ref) {
  final notifier = ref.watch(billReminderProvider.notifier);
  return notifier.dueTodayReminders;
});

/// 即将到期账单
final dueSoonProvider = Provider<List<BillReminder>>((ref) {
  final notifier = ref.watch(billReminderProvider.notifier);
  return notifier.dueSoonReminders;
});

/// 账单汇总
class BillReminderSummary {
  final int totalCount;
  final int dueTodayCount;
  final int dueSoonCount;
  final int overdueCount;
  final double monthlyTotal;
  final double yearlyTotal;

  BillReminderSummary({
    required this.totalCount,
    required this.dueTodayCount,
    required this.dueSoonCount,
    required this.overdueCount,
    required this.monthlyTotal,
    required this.yearlyTotal,
  });
}

final billReminderSummaryProvider = Provider<BillReminderSummary>((ref) {
  final reminders = ref.watch(billReminderProvider);
  final notifier = ref.read(billReminderProvider.notifier);
  final enabled = reminders.where((r) => r.isEnabled).toList();

  return BillReminderSummary(
    totalCount: enabled.length,
    dueTodayCount: enabled.where((r) => r.isDueToday).length,
    dueSoonCount: enabled.where((r) => r.isDueSoon && !r.isDueToday).length,
    overdueCount: enabled.where((r) => r.isOverdue).length,
    monthlyTotal: notifier.monthlyTotal,
    yearlyTotal: notifier.yearlyTotal,
  );
});
