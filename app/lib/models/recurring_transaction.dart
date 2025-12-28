import 'package:flutter/material.dart';
import 'transaction.dart';

enum RecurringFrequency {
  daily,
  weekly,
  monthly,
  yearly,
}

class RecurringTransaction {
  final String id;
  final String name;
  final TransactionType type;
  final double amount;
  final String category;
  final String? note;
  final String accountId;
  final String? toAccountId;
  final RecurringFrequency frequency;
  final int dayOfWeek; // 1-7 for weekly
  final int dayOfMonth; // 1-31 for monthly
  final int monthOfYear; // 1-12 for yearly
  final DateTime startDate;
  final DateTime? endDate;
  final bool isEnabled;
  final DateTime? lastExecutedAt;
  final DateTime? nextExecuteAt;
  final IconData icon;
  final Color color;
  final DateTime createdAt;

  RecurringTransaction({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.accountId,
    this.toAccountId,
    required this.frequency,
    this.dayOfWeek = 1,
    this.dayOfMonth = 1,
    this.monthOfYear = 1,
    required this.startDate,
    this.endDate,
    this.isEnabled = true,
    this.lastExecutedAt,
    this.nextExecuteAt,
    required this.icon,
    required this.color,
    required this.createdAt,
  });

  RecurringTransaction copyWith({
    String? id,
    String? name,
    TransactionType? type,
    double? amount,
    String? category,
    String? note,
    String? accountId,
    String? toAccountId,
    RecurringFrequency? frequency,
    int? dayOfWeek,
    int? dayOfMonth,
    int? monthOfYear,
    DateTime? startDate,
    DateTime? endDate,
    bool? isEnabled,
    DateTime? lastExecutedAt,
    DateTime? nextExecuteAt,
    IconData? icon,
    Color? color,
    DateTime? createdAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      frequency: frequency ?? this.frequency,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isEnabled: isEnabled ?? this.isEnabled,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      nextExecuteAt: nextExecuteAt ?? this.nextExecuteAt,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get frequencyName {
    switch (frequency) {
      case RecurringFrequency.daily:
        return '每天';
      case RecurringFrequency.weekly:
        return '每周${_weekdayName(dayOfWeek)}';
      case RecurringFrequency.monthly:
        return '每月${dayOfMonth}日';
      case RecurringFrequency.yearly:
        return '每年${monthOfYear}月${dayOfMonth}日';
    }
  }

  String _weekdayName(int day) {
    const names = ['', '一', '二', '三', '四', '五', '六', '日'];
    return names[day];
  }

  String get typeName {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
    }
  }

  // Calculate next execution date
  DateTime calculateNextExecuteDate({DateTime? from}) {
    final now = from ?? DateTime.now();
    DateTime next;

    switch (frequency) {
      case RecurringFrequency.daily:
        next = DateTime(now.year, now.month, now.day + 1);
        break;

      case RecurringFrequency.weekly:
        final daysUntilNext = (dayOfWeek - now.weekday + 7) % 7;
        if (daysUntilNext == 0 && lastExecutedAt != null) {
          next = DateTime(now.year, now.month, now.day + 7);
        } else {
          next = DateTime(now.year, now.month, now.day + (daysUntilNext == 0 ? 7 : daysUntilNext));
        }
        break;

      case RecurringFrequency.monthly:
        if (now.day < dayOfMonth) {
          next = DateTime(now.year, now.month, dayOfMonth);
        } else {
          next = DateTime(now.year, now.month + 1, dayOfMonth);
        }
        break;

      case RecurringFrequency.yearly:
        final thisYearDate = DateTime(now.year, monthOfYear, dayOfMonth);
        if (now.isBefore(thisYearDate)) {
          next = thisYearDate;
        } else {
          next = DateTime(now.year + 1, monthOfYear, dayOfMonth);
        }
        break;
    }

    return next;
  }

  // Check if should execute today
  bool shouldExecuteToday() {
    if (!isEnabled) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if already executed today
    if (lastExecutedAt != null) {
      final lastDate = DateTime(
        lastExecutedAt!.year,
        lastExecutedAt!.month,
        lastExecutedAt!.day,
      );
      if (lastDate == today) return false;
    }

    // Check start date
    if (today.isBefore(startDate)) return false;

    // Check end date
    if (endDate != null && today.isAfter(endDate!)) return false;

    // Check frequency
    switch (frequency) {
      case RecurringFrequency.daily:
        return true;

      case RecurringFrequency.weekly:
        return now.weekday == dayOfWeek;

      case RecurringFrequency.monthly:
        return now.day == dayOfMonth;

      case RecurringFrequency.yearly:
        return now.month == monthOfYear && now.day == dayOfMonth;
    }
  }

  // Create a transaction from this recurring rule
  Transaction toTransaction() {
    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      amount: amount,
      category: category,
      note: note != null ? '$note (自动记账)' : '自动记账',
      date: DateTime.now(),
      accountId: accountId,
      toAccountId: toAccountId,
    );
  }
}
