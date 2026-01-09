import 'dart:convert';
import 'package:flutter/material.dart';

/// 小金库类型
enum VaultType {
  /// 固定支出 - 每月必须支付（房租、水电、保险）
  fixed,

  /// 弹性支出 - 可调整（餐饮、娱乐、购物）
  flexible,

  /// 储蓄目标 - 长期积累（旅行基金、应急金、购房）
  savings,

  /// 债务还款 - 信用卡、贷款
  debt,
}

extension VaultTypeExtension on VaultType {
  String get displayName {
    switch (this) {
      case VaultType.fixed:
        return '固定支出';
      case VaultType.flexible:
        return '弹性支出';
      case VaultType.savings:
        return '储蓄目标';
      case VaultType.debt:
        return '债务还款';
    }
  }

  String get description {
    switch (this) {
      case VaultType.fixed:
        return '每月必须支付的固定开支';
      case VaultType.flexible:
        return '可根据情况调整的弹性消费';
      case VaultType.savings:
        return '长期积累的储蓄目标';
      case VaultType.debt:
        return '信用卡和贷款还款';
    }
  }

  IconData get defaultIcon {
    switch (this) {
      case VaultType.fixed:
        return Icons.home;
      case VaultType.flexible:
        return Icons.shopping_bag;
      case VaultType.savings:
        return Icons.savings;
      case VaultType.debt:
        return Icons.credit_card;
    }
  }

  Color get defaultColor {
    switch (this) {
      case VaultType.fixed:
        return Colors.blue;
      case VaultType.flexible:
        return Colors.orange;
      case VaultType.savings:
        return Colors.green;
      case VaultType.debt:
        return Colors.red;
    }
  }

  /// 分配优先级（数字越小优先级越高）
  int get allocationPriority {
    switch (this) {
      case VaultType.fixed:
        return 1;  // 固定支出优先
      case VaultType.debt:
        return 2;  // 债务其次
      case VaultType.savings:
        return 3;  // 储蓄第三
      case VaultType.flexible:
        return 4;  // 弹性最后
    }
  }
}

/// 分配类型枚举
enum AllocationType {
  /// 固定金额分配
  fixed,

  /// 按百分比分配
  percentage,

  /// 分配剩余金额
  remainder,

  /// 补齐到目标金额
  topUp,
}

extension AllocationTypeExtension on AllocationType {
  String get displayName {
    switch (this) {
      case AllocationType.fixed:
        return '固定金额';
      case AllocationType.percentage:
        return '按百分比';
      case AllocationType.remainder:
        return '分配剩余';
      case AllocationType.topUp:
        return '补齐目标';
    }
  }

  String get description {
    switch (this) {
      case AllocationType.fixed:
        return '每次分配固定金额到此小金库';
      case AllocationType.percentage:
        return '按收入的百分比分配';
      case AllocationType.remainder:
        return '其他小金库分配后的剩余金额';
      case AllocationType.topUp:
        return '补充到目标金额';
    }
  }
}

/// 小金库状态
enum VaultStatus {
  /// 健康 - 资金充足
  healthy,

  /// 资金不足 - 未达到目标
  underfunded,

  /// 即将用完 - 使用率超过90%
  almostEmpty,

  /// 已超支
  overSpent,
}

extension VaultStatusExtension on VaultStatus {
  String get displayName {
    switch (this) {
      case VaultStatus.healthy:
        return '健康';
      case VaultStatus.underfunded:
        return '资金不足';
      case VaultStatus.almostEmpty:
        return '即将用完';
      case VaultStatus.overSpent:
        return '已超支';
    }
  }

  Color get color {
    switch (this) {
      case VaultStatus.healthy:
        return Colors.green;
      case VaultStatus.underfunded:
        return Colors.orange;
      case VaultStatus.almostEmpty:
        return Colors.amber;
      case VaultStatus.overSpent:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case VaultStatus.healthy:
        return Icons.check_circle;
      case VaultStatus.underfunded:
        return Icons.warning;
      case VaultStatus.almostEmpty:
        return Icons.error_outline;
      case VaultStatus.overSpent:
        return Icons.dangerous;
    }
  }
}

/// 周期规则
class RecurrenceRule {
  final RecurrenceFrequency frequency;
  final int interval;           // 间隔（如每2周的2）
  final int? dayOfWeek;         // 周几（1-7，用于weekly）
  final int? dayOfMonth;        // 几号（1-31，用于monthly）
  final int? monthOfYear;       // 几月（1-12，用于yearly）
  final DateTime? startDate;    // 开始日期
  final DateTime? endDate;      // 结束日期

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency.index,
      'interval': interval,
      'dayOfWeek': dayOfWeek,
      'dayOfMonth': dayOfMonth,
      'monthOfYear': monthOfYear,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
    };
  }

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    return RecurrenceRule(
      frequency: RecurrenceFrequency.values[map['frequency'] as int],
      interval: map['interval'] as int? ?? 1,
      dayOfWeek: map['dayOfWeek'] as int?,
      dayOfMonth: map['dayOfMonth'] as int?,
      monthOfYear: map['monthOfYear'] as int?,
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int)
          : null,
    );
  }

  /// 获取下一个执行日期
  DateTime? getNextOccurrence(DateTime from) {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return from.add(Duration(days: interval));
      case RecurrenceFrequency.weekly:
        return from.add(Duration(days: 7 * interval));
      case RecurrenceFrequency.biweekly:
        return from.add(Duration(days: 14 * interval));
      case RecurrenceFrequency.monthly:
        return DateTime(from.year, from.month + interval, dayOfMonth ?? from.day);
      case RecurrenceFrequency.yearly:
        return DateTime(from.year + interval, monthOfYear ?? from.month, dayOfMonth ?? from.day);
    }
  }
}

/// 周期频率
enum RecurrenceFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  yearly,
}

extension RecurrenceFrequencyExtension on RecurrenceFrequency {
  String get displayName {
    switch (this) {
      case RecurrenceFrequency.daily:
        return '每天';
      case RecurrenceFrequency.weekly:
        return '每周';
      case RecurrenceFrequency.biweekly:
        return '每两周';
      case RecurrenceFrequency.monthly:
        return '每月';
      case RecurrenceFrequency.yearly:
        return '每年';
    }
  }
}

/// 小金库模型
///
/// 小金库是零基预算的核心概念，每个小金库代表一个预算类别或储蓄目标。
/// 收入进来后分配到各个小金库，支出时从对应的小金库扣减。
class BudgetVault {
  final String id;
  final String name;
  final String? description;
  final IconData icon;
  final Color color;
  final VaultType type;
  final double targetAmount;        // 目标金额（预算上限或储蓄目标）
  final double allocatedAmount;     // 已分配金额
  final double spentAmount;         // 已花费金额
  final DateTime? dueDate;          // 到期日（用于账单类）
  final bool isRecurring;           // 是否周期性
  final RecurrenceRule? recurrence; // 周期规则
  final String? linkedCategoryId;   // 关联的消费分类ID
  final List<String>? linkedCategoryIds; // 关联的多个分类ID
  final String ledgerId;            // 所属账本ID
  final bool isEnabled;             // 是否启用
  final int sortOrder;              // 排序顺序
  final DateTime createdAt;
  final DateTime updatedAt;

  // 分配策略相关属性
  final AllocationType allocationType;  // 分配类型
  final double? targetAllocation;       // 固定分配金额（用于fixed类型）
  final double? targetPercentage;       // 分配百分比（用于percentage类型，0-1）

  BudgetVault({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    required this.type,
    required this.targetAmount,
    this.allocatedAmount = 0,
    this.spentAmount = 0,
    this.dueDate,
    this.isRecurring = false,
    this.recurrence,
    this.linkedCategoryId,
    this.linkedCategoryIds,
    required this.ledgerId,
    this.isEnabled = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.allocationType = AllocationType.fixed,
    this.targetAllocation,
    this.targetPercentage,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 当前金额（已分配 - 已花费）
  double get currentAmount => allocatedAmount - spentAmount;

  /// 剩余可用金额（别名）
  double get available => currentAmount;

  /// 完成度（用于储蓄目标）
  double get progress =>
      targetAmount > 0 ? (allocatedAmount / targetAmount).clamp(0.0, 1.0) : 0;

  /// 使用率（用于预算控制）
  double get usageRate =>
      allocatedAmount > 0 ? (spentAmount / allocatedAmount).clamp(0.0, double.infinity) : 0;

  /// 剩余预算比例
  double get remainingRate => 1.0 - usageRate.clamp(0.0, 1.0);

  /// 状态
  VaultStatus get status {
    if (available < 0) return VaultStatus.overSpent;
    if (usageRate > 0.9) return VaultStatus.almostEmpty;
    if (progress < 1.0 && type == VaultType.savings) return VaultStatus.underfunded;
    if (allocatedAmount < targetAmount && type == VaultType.fixed) return VaultStatus.underfunded;
    return VaultStatus.healthy;
  }

  /// 是否超支
  bool get isOverSpent => available < 0;

  /// 是否接近用完（使用率>80%）
  bool get isAlmostEmpty => usageRate > 0.8 && !isOverSpent;

  /// 距离到期日的天数
  int? get daysUntilDue {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.difference(today).inDays;
  }

  /// 是否即将到期（3天内）
  bool get isDueSoon => daysUntilDue != null && daysUntilDue! <= 3 && daysUntilDue! >= 0;

  /// 是否已过期
  bool get isOverdue => daysUntilDue != null && daysUntilDue! < 0;

  /// 超支金额（如果超支）
  double get overspentAmount => isOverSpent ? -available : 0;

  BudgetVault copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    Color? color,
    VaultType? type,
    double? targetAmount,
    double? allocatedAmount,
    double? spentAmount,
    DateTime? dueDate,
    bool? isRecurring,
    RecurrenceRule? recurrence,
    String? linkedCategoryId,
    List<String>? linkedCategoryIds,
    String? ledgerId,
    bool? isEnabled,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    AllocationType? allocationType,
    double? targetAllocation,
    double? targetPercentage,
  }) {
    return BudgetVault(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      dueDate: dueDate ?? this.dueDate,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrence: recurrence ?? this.recurrence,
      linkedCategoryId: linkedCategoryId ?? this.linkedCategoryId,
      linkedCategoryIds: linkedCategoryIds ?? this.linkedCategoryIds,
      ledgerId: ledgerId ?? this.ledgerId,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      allocationType: allocationType ?? this.allocationType,
      targetAllocation: targetAllocation ?? this.targetAllocation,
      targetPercentage: targetPercentage ?? this.targetPercentage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconCode': icon.codePoint,
      'colorValue': color.toARGB32(),
      'type': type.index,
      'targetAmount': targetAmount,
      'allocatedAmount': allocatedAmount,
      'spentAmount': spentAmount,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'isRecurring': isRecurring ? 1 : 0,
      'recurrenceJson': recurrence != null ? jsonEncode(recurrence!.toMap()) : null,
      'linkedCategoryId': linkedCategoryId,
      'linkedCategoryIds': linkedCategoryIds?.join(','),
      'ledgerId': ledgerId,
      'isEnabled': isEnabled ? 1 : 0,
      'sortOrder': sortOrder,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'allocationType': allocationType.index,
      'targetAllocation': targetAllocation,
      'targetPercentage': targetPercentage,
    };
  }

  factory BudgetVault.fromMap(Map<String, dynamic> map) {
    return BudgetVault(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] as int),
      type: VaultType.values[map['type'] as int],
      targetAmount: (map['targetAmount'] as num).toDouble(),
      allocatedAmount: (map['allocatedAmount'] as num?)?.toDouble() ?? 0,
      spentAmount: (map['spentAmount'] as num?)?.toDouble() ?? 0,
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
          : null,
      isRecurring: map['isRecurring'] == 1,
      recurrence: map['recurrenceJson'] != null
          ? RecurrenceRule.fromMap(jsonDecode(map['recurrenceJson'] as String))
          : null,
      linkedCategoryId: map['linkedCategoryId'] as String?,
      linkedCategoryIds: map['linkedCategoryIds'] != null
          ? (map['linkedCategoryIds'] as String).split(',')
          : null,
      ledgerId: map['ledgerId'] as String,
      isEnabled: map['isEnabled'] != 0,
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
      allocationType: AllocationType.values[map['allocationType'] as int? ?? 0],
      targetAllocation: (map['targetAllocation'] as num?)?.toDouble(),
      targetPercentage: (map['targetPercentage'] as num?)?.toDouble(),
    );
  }
}

/// 小金库分配记录
///
/// 记录每次收入分配到小金库的详情
class VaultAllocation {
  final String id;
  final String vaultId;
  final String? incomeTransactionId;  // 关联的收入交易（可为null表示手动分配）
  final double amount;
  final String? note;
  final DateTime allocatedAt;

  const VaultAllocation({
    required this.id,
    required this.vaultId,
    this.incomeTransactionId,
    required this.amount,
    this.note,
    required this.allocatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vaultId': vaultId,
      'incomeTransactionId': incomeTransactionId,
      'amount': amount,
      'note': note,
      'allocatedAt': allocatedAt.millisecondsSinceEpoch,
    };
  }

  factory VaultAllocation.fromMap(Map<String, dynamic> map) {
    return VaultAllocation(
      id: map['id'] as String,
      vaultId: map['vaultId'] as String,
      incomeTransactionId: map['incomeTransactionId'] as String?,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      allocatedAt: DateTime.fromMillisecondsSinceEpoch(map['allocatedAt'] as int),
    );
  }
}

/// 小金库调拨记录
///
/// 记录小金库之间的资金转移
class VaultTransfer {
  final String id;
  final String fromVaultId;
  final String toVaultId;
  final double amount;
  final String? note;
  final DateTime transferredAt;

  const VaultTransfer({
    required this.id,
    required this.fromVaultId,
    required this.toVaultId,
    required this.amount,
    this.note,
    required this.transferredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromVaultId': fromVaultId,
      'toVaultId': toVaultId,
      'amount': amount,
      'note': note,
      'transferredAt': transferredAt.millisecondsSinceEpoch,
    };
  }

  factory VaultTransfer.fromMap(Map<String, dynamic> map) {
    return VaultTransfer(
      id: map['id'] as String,
      fromVaultId: map['fromVaultId'] as String,
      toVaultId: map['toVaultId'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      transferredAt: DateTime.fromMillisecondsSinceEpoch(map['transferredAt'] as int),
    );
  }
}

/// 小金库统计摘要
class VaultSummary {
  final int totalVaults;
  final double totalAllocated;
  final double totalSpent;
  final double totalAvailable;
  final int healthyCount;
  final int underfundedCount;
  final int almostEmptyCount;
  final int overSpentCount;
  final Map<VaultType, double> allocationByType;
  final Map<VaultType, double> spentByType;

  const VaultSummary({
    required this.totalVaults,
    required this.totalAllocated,
    required this.totalSpent,
    required this.totalAvailable,
    required this.healthyCount,
    required this.underfundedCount,
    required this.almostEmptyCount,
    required this.overSpentCount,
    required this.allocationByType,
    required this.spentByType,
  });

  /// 总体使用率
  double get overallUsageRate =>
      totalAllocated > 0 ? totalSpent / totalAllocated : 0;

  /// 健康小金库比例
  double get healthyRate =>
      totalVaults > 0 ? healthyCount / totalVaults : 0;

  factory VaultSummary.empty() {
    return const VaultSummary(
      totalVaults: 0,
      totalAllocated: 0,
      totalSpent: 0,
      totalAvailable: 0,
      healthyCount: 0,
      underfundedCount: 0,
      almostEmptyCount: 0,
      overSpentCount: 0,
      allocationByType: {},
      spentByType: {},
    );
  }
}

/// 小金库模板
class VaultTemplates {
  static List<Map<String, dynamic>> get templates => [
    // 固定支出模板
    {
      'name': '房租/房贷',
      'type': VaultType.fixed,
      'icon': Icons.home,
      'color': Colors.blue,
      'description': '每月固定住房支出',
    },
    {
      'name': '水电燃气',
      'type': VaultType.fixed,
      'icon': Icons.bolt,
      'color': Colors.amber,
      'description': '每月水电燃气费用',
    },
    {
      'name': '通讯费',
      'type': VaultType.fixed,
      'icon': Icons.phone_android,
      'color': Colors.purple,
      'description': '手机、宽带等通讯费用',
    },
    {
      'name': '保险费',
      'type': VaultType.fixed,
      'icon': Icons.shield,
      'color': Colors.teal,
      'description': '各类保险费用',
    },

    // 弹性支出模板
    {
      'name': '餐饮',
      'type': VaultType.flexible,
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'description': '日常餐饮开支',
    },
    {
      'name': '购物',
      'type': VaultType.flexible,
      'icon': Icons.shopping_bag,
      'color': Colors.pink,
      'description': '购物消费预算',
    },
    {
      'name': '交通出行',
      'type': VaultType.flexible,
      'icon': Icons.directions_car,
      'color': Colors.indigo,
      'description': '日常交通费用',
    },
    {
      'name': '娱乐',
      'type': VaultType.flexible,
      'icon': Icons.sports_esports,
      'color': Colors.deepPurple,
      'description': '休闲娱乐消费',
    },

    // 储蓄目标模板
    {
      'name': '应急基金',
      'type': VaultType.savings,
      'icon': Icons.savings,
      'color': Colors.green,
      'description': '3-6个月生活费储备',
    },
    {
      'name': '旅行基金',
      'type': VaultType.savings,
      'icon': Icons.flight,
      'color': Colors.cyan,
      'description': '下一次旅行的费用',
    },
    {
      'name': '购物愿望',
      'type': VaultType.savings,
      'icon': Icons.card_giftcard,
      'color': Colors.pinkAccent,
      'description': '想买的大件物品',
    },

    // 债务还款模板
    {
      'name': '信用卡还款',
      'type': VaultType.debt,
      'icon': Icons.credit_card,
      'color': Colors.red,
      'description': '信用卡账单还款',
    },
    {
      'name': '贷款还款',
      'type': VaultType.debt,
      'icon': Icons.account_balance,
      'color': Colors.deepOrange,
      'description': '各类贷款还款',
    },
  ];
}
