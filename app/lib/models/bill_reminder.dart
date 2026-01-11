import 'package:flutter/material.dart';

import 'common_types.dart';

/// 账单提醒类型
enum BillReminderType {
  creditCard,     // 信用卡还款
  subscription,   // 订阅服务
  utility,        // 水电煤
  rent,           // 房租
  loan,           // 贷款还款
  insurance,      // 保险
  other,          // 其他
}

/// 提醒周期
enum ReminderFrequency {
  once,           // 一次性
  daily,          // 每日
  weekly,         // 每周
  monthly,        // 每月
  yearly,         // 每年
}

/// 账单提醒模型
class BillReminder {
  final String id;
  final String name;
  final BillReminderType type;
  final double amount;
  final ReminderFrequency frequency;
  final int dayOfMonth;          // 每月几号 (1-28)
  final int? dayOfWeek;          // 每周几 (1-7, 1=周一)
  final DateTime? specificDate;  // 特定日期（一次性提醒）
  final int reminderDaysBefore;  // 提前几天提醒
  final TimeOfDay reminderTime;  // 提醒时间
  final String? linkedAccountId; // 关联账户
  final String? note;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final DateTime? lastRemindedAt;
  final DateTime? nextReminderDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BillReminder({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.frequency,
    this.dayOfMonth = 1,
    this.dayOfWeek,
    this.specificDate,
    this.reminderDaysBefore = 3,
    this.reminderTime = const TimeOfDay(hour: 9, minute: 0),
    this.linkedAccountId,
    this.note,
    required this.icon,
    required this.color,
    this.isEnabled = true,
    this.lastRemindedAt,
    this.nextReminderDate,
    required this.createdAt,
    this.updatedAt,
  });

  /// 获取下一个账单日
  DateTime get nextBillDate {
    final now = DateTime.now();

    switch (frequency) {
      case ReminderFrequency.once:
        return specificDate ?? now;

      case ReminderFrequency.daily:
        return DateTime(now.year, now.month, now.day + 1);

      case ReminderFrequency.weekly:
        final daysUntilNext = (dayOfWeek! - now.weekday + 7) % 7;
        return DateTime(now.year, now.month, now.day + (daysUntilNext == 0 ? 7 : daysUntilNext));

      case ReminderFrequency.monthly:
        var nextDate = DateTime(now.year, now.month, dayOfMonth);
        if (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now)) {
          nextDate = DateTime(now.year, now.month + 1, dayOfMonth);
        }
        return nextDate;

      case ReminderFrequency.yearly:
        var nextDate = DateTime(now.year, now.month, dayOfMonth);
        if (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now)) {
          nextDate = DateTime(now.year + 1, now.month, dayOfMonth);
        }
        return nextDate;
    }
  }

  /// 距离下一个账单日天数
  int get daysUntilBill {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final billDate = DateTime(nextBillDate.year, nextBillDate.month, nextBillDate.day);
    return billDate.difference(today).inDays;
  }

  /// 是否即将到期（在提醒天数内）
  bool get isDueSoon => daysUntilBill <= reminderDaysBefore && daysUntilBill >= 0;

  /// 是否今天到期
  bool get isDueToday => daysUntilBill == 0;

  /// 是否已过期
  bool get isOverdue => daysUntilBill < 0;

  /// 类型显示名称
  String get typeDisplayName {
    switch (type) {
      case BillReminderType.creditCard:
        return '信用卡还款';
      case BillReminderType.subscription:
        return '订阅服务';
      case BillReminderType.utility:
        return '水电煤气';
      case BillReminderType.rent:
        return '房租';
      case BillReminderType.loan:
        return '贷款还款';
      case BillReminderType.insurance:
        return '保险';
      case BillReminderType.other:
        return '其他';
    }
  }

  /// 频率显示名称
  String get frequencyDisplayName {
    switch (frequency) {
      case ReminderFrequency.once:
        return '一次性';
      case ReminderFrequency.daily:
        return '每日';
      case ReminderFrequency.weekly:
        return '每周';
      case ReminderFrequency.monthly:
        return '每月';
      case ReminderFrequency.yearly:
        return '每年';
    }
  }

  BillReminder copyWith({
    String? id,
    String? name,
    BillReminderType? type,
    double? amount,
    ReminderFrequency? frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    DateTime? specificDate,
    int? reminderDaysBefore,
    TimeOfDay? reminderTime,
    String? linkedAccountId,
    String? note,
    IconData? icon,
    Color? color,
    bool? isEnabled,
    DateTime? lastRemindedAt,
    DateTime? nextReminderDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BillReminder(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      specificDate: specificDate ?? this.specificDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderTime: reminderTime ?? this.reminderTime,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      note: note ?? this.note,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isEnabled: isEnabled ?? this.isEnabled,
      lastRemindedAt: lastRemindedAt ?? this.lastRemindedAt,
      nextReminderDate: nextReminderDate ?? this.nextReminderDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'amount': amount,
      'frequency': frequency.name,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
      'specificDate': specificDate?.toIso8601String(),
      'reminderDaysBefore': reminderDaysBefore,
      'reminderTimeHour': reminderTime.hour,
      'reminderTimeMinute': reminderTime.minute,
      'linkedAccountId': linkedAccountId,
      'note': note,
      'iconCode': icon.codePoint,
      'colorValue': color.toARGB32(),
      'isEnabled': isEnabled ? 1 : 0,
      'lastRemindedAt': lastRemindedAt?.toIso8601String(),
      'nextReminderDate': nextReminderDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory BillReminder.fromMap(Map<String, dynamic> map) {
    return BillReminder(
      id: map['id'],
      name: map['name'],
      type: parseEnum(map['type'], BillReminderType.values, BillReminderType.other),
      amount: (map['amount'] as num).toDouble(),
      frequency: parseEnum(map['frequency'], ReminderFrequency.values, ReminderFrequency.monthly),
      dayOfMonth: map['dayOfMonth'],
      dayOfWeek: map['dayOfWeek'],
      specificDate: parseDateTimeOrNull(map['specificDate']),
      reminderDaysBefore: map['reminderDaysBefore'],
      reminderTime: TimeOfDay(
        hour: map['reminderTimeHour'],
        minute: map['reminderTimeMinute'],
      ),
      linkedAccountId: map['linkedAccountId'],
      note: map['note'],
      icon: IconData(map['iconCode'], fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue']),
      isEnabled: map['isEnabled'] == 1,
      lastRemindedAt: parseDateTimeOrNull(map['lastRemindedAt']),
      nextReminderDate: parseDateTimeOrNull(map['nextReminderDate']),
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
    );
  }
}

/// 预设账单类型图标和颜色
class BillReminderPresets {
  static Map<BillReminderType, Map<String, dynamic>> get presets => {
    BillReminderType.creditCard: {
      'icon': Icons.credit_card,
      'color': Colors.blue,
    },
    BillReminderType.subscription: {
      'icon': Icons.subscriptions,
      'color': Colors.purple,
    },
    BillReminderType.utility: {
      'icon': Icons.electrical_services,
      'color': Colors.orange,
    },
    BillReminderType.rent: {
      'icon': Icons.home,
      'color': Colors.brown,
    },
    BillReminderType.loan: {
      'icon': Icons.account_balance,
      'color': Colors.red,
    },
    BillReminderType.insurance: {
      'icon': Icons.security,
      'color': Colors.green,
    },
    BillReminderType.other: {
      'icon': Icons.receipt_long,
      'color': Colors.grey,
    },
  };

  static IconData getIcon(BillReminderType type) =>
      presets[type]!['icon'] as IconData;

  static Color getColor(BillReminderType type) =>
      presets[type]!['color'] as Color;
}

/// 常见订阅服务模板
class SubscriptionTemplates {
  static List<Map<String, dynamic>> get templates => [
    {'name': 'Netflix', 'icon': Icons.movie, 'color': Colors.red},
    {'name': 'Spotify', 'icon': Icons.music_note, 'color': Colors.green},
    {'name': 'iCloud', 'icon': Icons.cloud, 'color': Colors.blue},
    {'name': 'Apple Music', 'icon': Icons.music_note, 'color': Colors.pink},
    {'name': 'YouTube Premium', 'icon': Icons.play_circle, 'color': Colors.red},
    {'name': '爱奇艺', 'icon': Icons.ondemand_video, 'color': Colors.green},
    {'name': '腾讯视频', 'icon': Icons.ondemand_video, 'color': Colors.orange},
    {'name': '优酷', 'icon': Icons.ondemand_video, 'color': Colors.blue},
    {'name': '网易云音乐', 'icon': Icons.music_note, 'color': Colors.red},
    {'name': 'QQ音乐', 'icon': Icons.music_note, 'color': Colors.green},
  ];
}
