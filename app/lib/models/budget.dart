import 'package:flutter/material.dart';

enum BudgetPeriod {
  daily,
  weekly,
  monthly,
  yearly,
}

/// 预算类型
enum BudgetType {
  traditional, // 传统预算
  zeroBased, // 零基预算(YNAB式)
}

/// 预算结转记录
class BudgetCarryover {
  final String id;
  final String budgetId;
  final int year;
  final int month;
  final double carryoverAmount; // 结转金额（正数为剩余结转，负数为超支结转）
  final DateTime createdAt;

  BudgetCarryover({
    required this.id,
    required this.budgetId,
    required this.year,
    required this.month,
    required this.carryoverAmount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'budgetId': budgetId,
      'year': year,
      'month': month,
      'carryoverAmount': carryoverAmount,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BudgetCarryover.fromMap(Map<String, dynamic> map) {
    return BudgetCarryover(
      id: map['id'] as String,
      budgetId: map['budgetId'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      carryoverAmount: (map['carryoverAmount'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// 零基预算分配记录
class ZeroBasedAllocation {
  final String id;
  final String budgetId;
  final double allocatedAmount; // 本期分配金额
  final int year;
  final int month;
  final DateTime createdAt;

  ZeroBasedAllocation({
    required this.id,
    required this.budgetId,
    required this.allocatedAmount,
    required this.year,
    required this.month,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'budgetId': budgetId,
      'allocatedAmount': allocatedAmount,
      'year': year,
      'month': month,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ZeroBasedAllocation.fromMap(Map<String, dynamic> map) {
    return ZeroBasedAllocation(
      id: map['id'] as String,
      budgetId: map['budgetId'] as String,
      allocatedAmount: (map['allocatedAmount'] as num).toDouble(),
      year: map['year'] as int,
      month: map['month'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

class Budget {
  final String id;
  final String name;
  final double amount;
  final BudgetPeriod period;
  final String? categoryId; // null means total budget
  final String ledgerId;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  // 新增：预算类型
  final BudgetType budgetType;
  // 新增：是否启用预算结转
  final bool enableCarryover;
  // 新增：结转模式（true: 仅结转剩余, false: 包括超支）
  final bool carryoverSurplusOnly;

  Budget({
    required this.id,
    required this.name,
    required this.amount,
    required this.period,
    this.categoryId,
    required this.ledgerId,
    required this.icon,
    required this.color,
    this.isEnabled = true,
    required this.createdAt,
    this.updatedAt,
    this.budgetType = BudgetType.traditional,
    this.enableCarryover = false,
    this.carryoverSurplusOnly = true,
  });

  Budget copyWith({
    String? id,
    String? name,
    double? amount,
    BudgetPeriod? period,
    String? categoryId,
    String? ledgerId,
    IconData? icon,
    Color? color,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    BudgetType? budgetType,
    bool? enableCarryover,
    bool? carryoverSurplusOnly,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      categoryId: categoryId ?? this.categoryId,
      ledgerId: ledgerId ?? this.ledgerId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      budgetType: budgetType ?? this.budgetType,
      enableCarryover: enableCarryover ?? this.enableCarryover,
      carryoverSurplusOnly: carryoverSurplusOnly ?? this.carryoverSurplusOnly,
    );
  }

  String get periodName {
    switch (period) {
      case BudgetPeriod.daily:
        return '每日';
      case BudgetPeriod.weekly:
        return '每周';
      case BudgetPeriod.monthly:
        return '每月';
      case BudgetPeriod.yearly:
        return '每年';
    }
  }

  // Get the start date of the current budget period
  DateTime get periodStartDate {
    final now = DateTime.now();
    switch (period) {
      case BudgetPeriod.daily:
        return DateTime(now.year, now.month, now.day);
      case BudgetPeriod.weekly:
        final weekday = now.weekday;
        return DateTime(now.year, now.month, now.day - weekday + 1);
      case BudgetPeriod.monthly:
        return DateTime(now.year, now.month, 1);
      case BudgetPeriod.yearly:
        return DateTime(now.year, 1, 1);
    }
  }

  // Get the end date of the current budget period
  DateTime get periodEndDate {
    final now = DateTime.now();
    switch (period) {
      case BudgetPeriod.daily:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case BudgetPeriod.weekly:
        final weekday = now.weekday;
        return DateTime(now.year, now.month, now.day + (7 - weekday), 23, 59, 59);
      case BudgetPeriod.monthly:
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        return DateTime(nextYear, nextMonth, 1).subtract(const Duration(seconds: 1));
      case BudgetPeriod.yearly:
        return DateTime(now.year, 12, 31, 23, 59, 59);
    }
  }

  // 获取上一周期的开始日期
  DateTime get previousPeriodStartDate {
    final now = DateTime.now();
    switch (period) {
      case BudgetPeriod.daily:
        return DateTime(now.year, now.month, now.day - 1);
      case BudgetPeriod.weekly:
        final weekday = now.weekday;
        return DateTime(now.year, now.month, now.day - weekday + 1 - 7);
      case BudgetPeriod.monthly:
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        return DateTime(prevYear, prevMonth, 1);
      case BudgetPeriod.yearly:
        return DateTime(now.year - 1, 1, 1);
    }
  }

  // 获取上一周期的结束日期
  DateTime get previousPeriodEndDate {
    final now = DateTime.now();
    switch (period) {
      case BudgetPeriod.daily:
        return DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
      case BudgetPeriod.weekly:
        final weekday = now.weekday;
        return DateTime(now.year, now.month, now.day - weekday, 23, 59, 59);
      case BudgetPeriod.monthly:
        return DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
      case BudgetPeriod.yearly:
        return DateTime(now.year - 1, 12, 31, 23, 59, 59);
    }
  }

  // 获取预算类型名称
  String get budgetTypeName {
    switch (budgetType) {
      case BudgetType.traditional:
        return '传统预算';
      case BudgetType.zeroBased:
        return '零基预算';
    }
  }

  /// 转换为Map用于序列化
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'period': period.index,
      'categoryId': categoryId,
      'ledgerId': ledgerId,
      'icon': icon.codePoint,
      'color': color.toARGB32(),
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'budgetType': budgetType.index,
      'enableCarryover': enableCarryover ? 1 : 0,
      'carryoverSurplusOnly': carryoverSurplusOnly ? 1 : 0,
    };
  }

  /// 从Map创建Budget
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      period: BudgetPeriod.values[map['period'] as int],
      categoryId: map['categoryId'] as String?,
      ledgerId: map['ledgerId'] as String,
      icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['color'] as int),
      isEnabled: map['isEnabled'] == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
      budgetType: map['budgetType'] != null
          ? BudgetType.values[map['budgetType'] as int]
          : BudgetType.traditional,
      enableCarryover: map['enableCarryover'] == 1,
      carryoverSurplusOnly: map['carryoverSurplusOnly'] != 0,
    );
  }
}

/// 钱龄数据模型
/// 钱龄(Age of Money)是YNAB的核心指标之一
/// 表示当前花费的钱是多少天前收到的
class MoneyAge {
  final int days; // 钱龄天数
  final DateTime calculatedAt; // 计算时间
  final double totalBalance; // 总余额
  final String? trend; // 趋势: 'up', 'down', 'stable'

  MoneyAge({
    required this.days,
    required this.calculatedAt,
    required this.totalBalance,
    this.trend,
  });

  // 钱龄健康状态
  MoneyAgeStatus get status {
    if (days >= 30) return MoneyAgeStatus.excellent;
    if (days >= 14) return MoneyAgeStatus.good;
    if (days >= 7) return MoneyAgeStatus.fair;
    return MoneyAgeStatus.poor;
  }

  String get statusText {
    switch (status) {
      case MoneyAgeStatus.excellent:
        return '优秀';
      case MoneyAgeStatus.good:
        return '良好';
      case MoneyAgeStatus.fair:
        return '一般';
      case MoneyAgeStatus.poor:
        return '需改善';
    }
  }

  String get description {
    // 处理负数钱龄（已透支状态）
    if (days < 0) {
      final absDays = days.abs();
      if (absDays >= 9999) {
        return '严重透支！存在异常大额支出，建议检查并删除错误记录';
      } else if (absDays >= 365) {
        return '已严重透支超过一年的收入，财务状况需要立即改善';
      } else if (absDays >= 30) {
        return '已严重透支，相当于提前消费了${absDays}天的收入，需要立即改善';
      } else if (absDays >= 14) {
        return '已透支${absDays}天的收入，建议减少支出并增加收入';
      } else {
        return '已透支${absDays}天的收入，需要关注财务状况';
      }
    } else if (days == 0 && totalBalance <= 0) {
      return '当前已经入不敷出，需要尽快改善财务状况';
    } else if (days == 0 && totalBalance > 0) {
      return '最近30天没有支出记录，暂无法计算钱龄';
    } else if (days >= 30) {
      return '您的资金周转非常健康，可以应对一个月的开支';
    } else if (days >= 14) {
      return '您的资金周转较好，可以应对两周的开支';
    } else if (days >= 7) {
      return '您的资金周转尚可，建议增加储蓄缓冲';
    } else {
      return '您的资金储备较少，建议增加储蓄以应对突发情况';
    }
  }
}

enum MoneyAgeStatus {
  excellent, // >= 30天
  good, // 14-29天
  fair, // 7-13天
  poor, // < 7天
}
