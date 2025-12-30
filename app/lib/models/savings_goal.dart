import 'package:flutter/material.dart';

/// 储蓄目标类型
enum SavingsGoalType {
  savings,      // 存钱目标
  expense,      // 消费控制（月度开支目标）
  debt,         // 还债目标
  investment,   // 投资目标
}

/// 定期存款频率
enum SavingsFrequency {
  daily,        // 每天
  weekly,       // 每周
  biweekly,     // 每两周
  monthly,      // 每月
}

extension SavingsFrequencyExtension on SavingsFrequency {
  String get displayName {
    switch (this) {
      case SavingsFrequency.daily:
        return '每天';
      case SavingsFrequency.weekly:
        return '每周';
      case SavingsFrequency.biweekly:
        return '每两周';
      case SavingsFrequency.monthly:
        return '每月';
    }
  }

  /// 获取下一个存款日期
  DateTime getNextDate(DateTime from) {
    switch (this) {
      case SavingsFrequency.daily:
        return from.add(const Duration(days: 1));
      case SavingsFrequency.weekly:
        return from.add(const Duration(days: 7));
      case SavingsFrequency.biweekly:
        return from.add(const Duration(days: 14));
      case SavingsFrequency.monthly:
        return DateTime(from.year, from.month + 1, from.day);
    }
  }
}

/// 储蓄目标模型
class SavingsGoal {
  final String id;
  final String name;
  final String? description;
  final SavingsGoalType type;
  final double targetAmount;      // 目标金额
  final double currentAmount;     // 当前已存金额
  final DateTime startDate;       // 开始日期
  final DateTime? targetDate;     // 目标日期
  final String? linkedAccountId;  // 关联账户ID
  final IconData icon;
  final Color color;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isArchived;
  final DateTime createdAt;

  // ===== 月度开支目标相关字段 =====
  final String? linkedCategoryId; // 关联分类ID（用于消费控制）
  final double? monthlyExpenseLimit; // 月度开支限额

  // ===== 定期存款目标相关字段 =====
  final SavingsFrequency? recurringFrequency; // 定期存款频率
  final double? recurringAmount;    // 每次存款金额
  final DateTime? nextDepositDate;  // 下次存款日期
  final bool enableReminder;        // 是否启用提醒

  SavingsGoal({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.startDate,
    this.targetDate,
    this.linkedAccountId,
    required this.icon,
    required this.color,
    this.isCompleted = false,
    this.completedAt,
    this.isArchived = false,
    required this.createdAt,
    // 月度开支目标
    this.linkedCategoryId,
    this.monthlyExpenseLimit,
    // 定期存款目标
    this.recurringFrequency,
    this.recurringAmount,
    this.nextDepositDate,
    this.enableReminder = false,
  });

  /// 进度百分比 (0-1)
  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;

  /// 进度百分比显示
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  /// 剩余金额
  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, targetAmount);

  /// 是否已达成目标
  bool get hasReachedTarget => currentAmount >= targetAmount;

  /// 距离目标日期天数
  int? get daysRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
    return target.difference(today).inDays;
  }

  /// 是否已过期
  bool get isOverdue {
    if (targetDate == null) return false;
    return daysRemaining != null && daysRemaining! < 0 && !hasReachedTarget;
  }

  /// 建议每日存款金额
  double? get suggestedDailyAmount {
    if (targetDate == null || daysRemaining == null || daysRemaining! <= 0) return null;
    return remainingAmount / daysRemaining!;
  }

  /// 建议每月存款金额
  double? get suggestedMonthlyAmount {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final monthsRemaining = (targetDate!.year - now.year) * 12 + (targetDate!.month - now.month);
    if (monthsRemaining <= 0) return remainingAmount;
    return remainingAmount / monthsRemaining;
  }

  /// 目标类型显示名称
  String get typeDisplayName {
    switch (type) {
      case SavingsGoalType.savings:
        return '存钱目标';
      case SavingsGoalType.expense:
        return '消费控制';
      case SavingsGoalType.debt:
        return '还债目标';
      case SavingsGoalType.investment:
        return '投资目标';
    }
  }

  /// 是否为定期存款目标
  bool get isRecurring => recurringFrequency != null && recurringAmount != null;

  /// 是否为月度开支控制目标
  bool get isExpenseControl => type == SavingsGoalType.expense && linkedCategoryId != null;

  /// 距离下次存款的天数
  int? get daysUntilNextDeposit {
    if (nextDepositDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(nextDepositDate!.year, nextDepositDate!.month, nextDepositDate!.day);
    return next.difference(today).inDays;
  }

  /// 是否需要今日存款
  bool get depositDueToday {
    final days = daysUntilNextDeposit;
    return days != null && days <= 0;
  }

  SavingsGoal copyWith({
    String? id,
    String? name,
    String? description,
    SavingsGoalType? type,
    double? targetAmount,
    double? currentAmount,
    DateTime? startDate,
    DateTime? targetDate,
    String? linkedAccountId,
    IconData? icon,
    Color? color,
    bool? isCompleted,
    DateTime? completedAt,
    bool? isArchived,
    DateTime? createdAt,
    String? linkedCategoryId,
    double? monthlyExpenseLimit,
    SavingsFrequency? recurringFrequency,
    double? recurringAmount,
    DateTime? nextDepositDate,
    bool? enableReminder,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      linkedCategoryId: linkedCategoryId ?? this.linkedCategoryId,
      monthlyExpenseLimit: monthlyExpenseLimit ?? this.monthlyExpenseLimit,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      recurringAmount: recurringAmount ?? this.recurringAmount,
      nextDepositDate: nextDepositDate ?? this.nextDepositDate,
      enableReminder: enableReminder ?? this.enableReminder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.index,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'startDate': startDate.millisecondsSinceEpoch,
      'targetDate': targetDate?.millisecondsSinceEpoch,
      'linkedAccountId': linkedAccountId,
      'iconCode': icon.codePoint,
      'colorValue': color.toARGB32(),
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'isArchived': isArchived ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      // 月度开支目标
      'linkedCategoryId': linkedCategoryId,
      'monthlyExpenseLimit': monthlyExpenseLimit,
      // 定期存款目标
      'recurringFrequency': recurringFrequency?.index,
      'recurringAmount': recurringAmount,
      'nextDepositDate': nextDepositDate?.millisecondsSinceEpoch,
      'enableReminder': enableReminder ? 1 : 0,
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      type: SavingsGoalType.values[map['type']],
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate']),
      targetDate: map['targetDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['targetDate'])
          : null,
      linkedAccountId: map['linkedAccountId'],
      icon: IconData(map['iconCode'], fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue']),
      isCompleted: map['isCompleted'] == 1,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
      isArchived: map['isArchived'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      // 月度开支目标
      linkedCategoryId: map['linkedCategoryId'],
      monthlyExpenseLimit: map['monthlyExpenseLimit'] != null
          ? (map['monthlyExpenseLimit'] as num).toDouble()
          : null,
      // 定期存款目标
      recurringFrequency: map['recurringFrequency'] != null
          ? SavingsFrequency.values[map['recurringFrequency']]
          : null,
      recurringAmount: map['recurringAmount'] != null
          ? (map['recurringAmount'] as num).toDouble()
          : null,
      nextDepositDate: map['nextDepositDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['nextDepositDate'])
          : null,
      enableReminder: map['enableReminder'] == 1,
    );
  }
}

/// 存款记录
class SavingsDeposit {
  final String id;
  final String goalId;
  final double amount;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  SavingsDeposit({
    required this.id,
    required this.goalId,
    required this.amount,
    this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'amount': amount,
      'note': note,
      'date': date.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SavingsDeposit.fromMap(Map<String, dynamic> map) {
    return SavingsDeposit(
      id: map['id'],
      goalId: map['goalId'],
      amount: (map['amount'] as num).toDouble(),
      note: map['note'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}

/// 预设目标模板
class GoalTemplates {
  static List<Map<String, dynamic>> get templates => [
    {
      'name': '应急基金',
      'type': SavingsGoalType.savings,
      'icon': Icons.shield,
      'color': Colors.blue,
      'description': '建立3-6个月生活费的应急储备',
    },
    {
      'name': '旅行基金',
      'type': SavingsGoalType.savings,
      'icon': Icons.flight,
      'color': Colors.teal,
      'description': '为下一次旅行存钱',
    },
    {
      'name': '购物愿望',
      'type': SavingsGoalType.savings,
      'icon': Icons.shopping_bag,
      'color': Colors.pink,
      'description': '存钱购买心仪物品',
    },
    {
      'name': '教育基金',
      'type': SavingsGoalType.savings,
      'icon': Icons.school,
      'color': Colors.purple,
      'description': '为自己或家人的教育储蓄',
    },
    {
      'name': '买房首付',
      'type': SavingsGoalType.savings,
      'icon': Icons.home,
      'color': Colors.orange,
      'description': '为购房首付存钱',
    },
    {
      'name': '还清信用卡',
      'type': SavingsGoalType.debt,
      'icon': Icons.credit_card_off,
      'color': Colors.red,
      'description': '清还信用卡欠款',
    },
    {
      'name': '还清贷款',
      'type': SavingsGoalType.debt,
      'icon': Icons.money_off,
      'color': Colors.deepOrange,
      'description': '偿还各类贷款',
    },
    {
      'name': '投资本金',
      'type': SavingsGoalType.investment,
      'icon': Icons.trending_up,
      'color': Colors.green,
      'description': '积累投资启动资金',
    },
  ];

  /// 月度开支控制模板
  static List<Map<String, dynamic>> get expenseTemplates => [
    {
      'name': '餐饮控制',
      'type': SavingsGoalType.expense,
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'description': '控制每月餐饮开支',
      'isExpenseControl': true,
    },
    {
      'name': '购物限额',
      'type': SavingsGoalType.expense,
      'icon': Icons.shopping_cart,
      'color': Colors.pink,
      'description': '控制每月购物开支',
      'isExpenseControl': true,
    },
    {
      'name': '娱乐开支',
      'type': SavingsGoalType.expense,
      'icon': Icons.sports_esports,
      'color': Colors.purple,
      'description': '控制每月娱乐消费',
      'isExpenseControl': true,
    },
    {
      'name': '交通费用',
      'type': SavingsGoalType.expense,
      'icon': Icons.directions_car,
      'color': Colors.blue,
      'description': '控制每月交通开支',
      'isExpenseControl': true,
    },
  ];

  /// 定期存款模板
  static List<Map<String, dynamic>> get recurringTemplates => [
    {
      'name': '每日存钱',
      'type': SavingsGoalType.savings,
      'icon': Icons.calendar_today,
      'color': Colors.green,
      'description': '养成每日存钱习惯',
      'isRecurring': true,
      'recurringFrequency': SavingsFrequency.daily,
    },
    {
      'name': '周存计划',
      'type': SavingsGoalType.savings,
      'icon': Icons.date_range,
      'color': Colors.blue,
      'description': '每周定期存入一笔钱',
      'isRecurring': true,
      'recurringFrequency': SavingsFrequency.weekly,
    },
    {
      'name': '月度定存',
      'type': SavingsGoalType.savings,
      'icon': Icons.calendar_month,
      'color': Colors.teal,
      'description': '每月工资日自动存款',
      'isRecurring': true,
      'recurringFrequency': SavingsFrequency.monthly,
    },
    {
      'name': '52周存钱法',
      'type': SavingsGoalType.savings,
      'icon': Icons.trending_up,
      'color': Colors.amber,
      'description': '每周递增存款，一年存下大钱',
      'isRecurring': true,
      'recurringFrequency': SavingsFrequency.weekly,
    },
  ];
}
