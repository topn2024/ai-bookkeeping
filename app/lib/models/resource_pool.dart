import 'dart:math';
import 'package:flutter/material.dart';

/// 钱龄健康等级
/// 定义6个等级，与设计文档第7章保持一致
enum MoneyAgeLevel {
  danger,    // < 7天，危险 - 月光族
  warning,   // 7-14天，警告 - 紧张
  normal,    // 14-30天，正常 - 及格
  good,      // 30-60天，良好 - 健康
  excellent, // 60-90天，优秀 - 优秀
  ideal,     // > 90天，理想 - 财务自由
}

extension MoneyAgeLevelExtension on MoneyAgeLevel {
  /// 获取等级对应的颜色
  Color get color {
    switch (this) {
      case MoneyAgeLevel.danger:
        return Colors.red;
      case MoneyAgeLevel.warning:
        return Colors.orange;
      case MoneyAgeLevel.normal:
        return Colors.yellow.shade700;
      case MoneyAgeLevel.good:
        return Colors.lightGreen;
      case MoneyAgeLevel.excellent:
        return Colors.green;
      case MoneyAgeLevel.ideal:
        return Colors.teal;
    }
  }

  /// 获取等级显示名称
  String get displayName {
    switch (this) {
      case MoneyAgeLevel.danger:
        return '危险';
      case MoneyAgeLevel.warning:
        return '警告';
      case MoneyAgeLevel.normal:
        return '一般';
      case MoneyAgeLevel.good:
        return '良好';
      case MoneyAgeLevel.excellent:
        return '优秀';
      case MoneyAgeLevel.ideal:
        return '理想';
    }
  }

  /// 获取等级描述
  String get description {
    switch (this) {
      case MoneyAgeLevel.danger:
        return '收入即花，没有缓冲';
      case MoneyAgeLevel.warning:
        return '刚过手的钱就花掉';
      case MoneyAgeLevel.normal:
        return '有基本的资金缓冲';
      case MoneyAgeLevel.good:
        return '有一个月以上缓冲';
      case MoneyAgeLevel.excellent:
        return '财务状况非常稳健';
      case MoneyAgeLevel.ideal:
        return '可应对各种意外';
    }
  }

  /// 获取等级对应的图标
  IconData get icon {
    switch (this) {
      case MoneyAgeLevel.danger:
        return Icons.warning;
      case MoneyAgeLevel.warning:
        return Icons.error_outline;
      case MoneyAgeLevel.normal:
        return Icons.info_outline;
      case MoneyAgeLevel.good:
        return Icons.thumb_up_outlined;
      case MoneyAgeLevel.excellent:
        return Icons.star_outline;
      case MoneyAgeLevel.ideal:
        return Icons.diamond_outlined;
    }
  }

  /// 最低天数阈值
  int get minDays {
    switch (this) {
      case MoneyAgeLevel.danger:
        return 0;
      case MoneyAgeLevel.warning:
        return 7;
      case MoneyAgeLevel.normal:
        return 14;
      case MoneyAgeLevel.good:
        return 30;
      case MoneyAgeLevel.excellent:
        return 60;
      case MoneyAgeLevel.ideal:
        return 90;
    }
  }
}

/// 资源池 - 追踪每笔收入的使用情况（FIFO模型核心）
///
/// 每笔收入创建一个资源池，记录原始金额和剩余可用金额。
/// 支出时按FIFO顺序消耗资源池，实现钱龄追踪。
class ResourcePool {
  final String id;
  final String incomeTransactionId;  // 关联的收入交易ID
  final DateTime createdAt;          // 资金进入时间（收入日期）
  final double originalAmount;       // 原始金额
  double remainingAmount;            // 剩余可用金额
  final String? ledgerId;            // 账本ID（可选，用于多账本场景）
  final String? accountId;           // 账户ID（可选，用于按账户追踪）
  final DateTime updatedAt;          // 最后更新时间

  ResourcePool({
    required this.id,
    required this.incomeTransactionId,
    required this.createdAt,
    required this.originalAmount,
    required this.remainingAmount,
    this.ledgerId,
    this.accountId,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// 计算当前钱龄（天）
  int get ageInDays => DateTime.now().difference(createdAt).inDays;

  /// 已消耗金额
  double get consumedAmount => originalAmount - remainingAmount;

  /// 消耗比例 (0-1)
  double get consumptionRate =>
      originalAmount > 0 ? consumedAmount / originalAmount : 0;

  /// 是否已完全消耗
  bool get isFullyConsumed => remainingAmount <= 0;

  /// 是否有剩余可用
  bool get hasRemaining => remainingAmount > 0;

  /// 使用资金（消耗资源池）
  /// 返回 ResourceConsumption 记录本次消费详情
  ResourceConsumption consume(double amount, String transactionId) {
    final consumed = min(amount, remainingAmount);
    remainingAmount -= consumed;
    return ResourceConsumption(
      id: '${id}_${transactionId}_${DateTime.now().millisecondsSinceEpoch}',
      resourcePoolId: id,
      expenseTransactionId: transactionId,
      amount: consumed,
      moneyAge: ageInDays,
      consumedAt: DateTime.now(),
    );
  }

  ResourcePool copyWith({
    String? id,
    String? incomeTransactionId,
    DateTime? createdAt,
    double? originalAmount,
    double? remainingAmount,
    String? ledgerId,
    String? accountId,
    DateTime? updatedAt,
  }) {
    return ResourcePool(
      id: id ?? this.id,
      incomeTransactionId: incomeTransactionId ?? this.incomeTransactionId,
      createdAt: createdAt ?? this.createdAt,
      originalAmount: originalAmount ?? this.originalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      ledgerId: ledgerId ?? this.ledgerId,
      accountId: accountId ?? this.accountId,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incomeTransactionId': incomeTransactionId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'originalAmount': originalAmount,
      'remainingAmount': remainingAmount,
      'ledgerId': ledgerId,
      'accountId': accountId,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ResourcePool.fromMap(Map<String, dynamic> map) {
    return ResourcePool(
      id: map['id'] as String,
      incomeTransactionId: map['incomeTransactionId'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      originalAmount: (map['originalAmount'] as num).toDouble(),
      remainingAmount: (map['remainingAmount'] as num).toDouble(),
      ledgerId: map['ledgerId'] as String?,
      accountId: map['accountId'] as String?,
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
    );
  }

  factory ResourcePool.fromJson(Map<String, dynamic> json) => ResourcePool.fromMap(json);
}

/// 资源消费记录 - 记录每次支出对资源池的消耗
///
/// 一笔支出可能消耗多个资源池（当金额较大时），
/// 每次消耗生成一条 ResourceConsumption 记录。
class ResourceConsumption {
  final String id;
  final String resourcePoolId;        // 消耗的资源池ID
  final String expenseTransactionId;  // 关联的支出交易ID
  final double amount;                // 消耗金额
  final int moneyAge;                 // 消耗时的钱龄（天）
  final DateTime consumedAt;          // 消耗时间

  const ResourceConsumption({
    required this.id,
    required this.resourcePoolId,
    required this.expenseTransactionId,
    required this.amount,
    required this.moneyAge,
    required this.consumedAt,
  });

  /// 是否为有效消费（金额大于0）
  bool get isValid => amount > 0;

  ResourceConsumption copyWith({
    String? id,
    String? resourcePoolId,
    String? expenseTransactionId,
    double? amount,
    int? moneyAge,
    DateTime? consumedAt,
  }) {
    return ResourceConsumption(
      id: id ?? this.id,
      resourcePoolId: resourcePoolId ?? this.resourcePoolId,
      expenseTransactionId: expenseTransactionId ?? this.expenseTransactionId,
      amount: amount ?? this.amount,
      moneyAge: moneyAge ?? this.moneyAge,
      consumedAt: consumedAt ?? this.consumedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'resourcePoolId': resourcePoolId,
      'expenseTransactionId': expenseTransactionId,
      'amount': amount,
      'moneyAge': moneyAge,
      'consumedAt': consumedAt.millisecondsSinceEpoch,
    };
  }

  factory ResourceConsumption.fromMap(Map<String, dynamic> map) {
    return ResourceConsumption(
      id: map['id'] as String,
      resourcePoolId: map['resourcePoolId'] as String,
      expenseTransactionId: map['expenseTransactionId'] as String,
      amount: (map['amount'] as num).toDouble(),
      moneyAge: map['moneyAge'] as int,
      consumedAt: DateTime.fromMillisecondsSinceEpoch(map['consumedAt'] as int),
    );
  }
}

/// 单笔消费的钱龄计算结果
class MoneyAgeResult {
  final String transactionId;
  final int moneyAge;                         // 该笔消费的加权平均钱龄（天）
  final List<ResourceConsumption> consumptions; // 资源消耗详情列表
  final double totalAmount;                   // 总消费金额
  final double coveredAmount;                 // 被资源池覆盖的金额
  final double uncoveredAmount;               // 未被覆盖的金额（资源池不足时）

  const MoneyAgeResult({
    required this.transactionId,
    required this.moneyAge,
    required this.consumptions,
    required this.totalAmount,
    required this.coveredAmount,
    required this.uncoveredAmount,
  });

  /// 是否有未覆盖金额（资源池不足）
  bool get hasUncovered => uncoveredAmount > 0;

  /// 覆盖率 (0-1)
  double get coverageRate =>
      totalAmount > 0 ? coveredAmount / totalAmount : 1.0;

  /// 获取健康等级
  MoneyAgeLevel get level {
    if (moneyAge < 7) return MoneyAgeLevel.danger;
    if (moneyAge < 14) return MoneyAgeLevel.warning;
    if (moneyAge < 30) return MoneyAgeLevel.normal;
    if (moneyAge < 60) return MoneyAgeLevel.good;
    if (moneyAge < 90) return MoneyAgeLevel.excellent;
    return MoneyAgeLevel.ideal;
  }

  factory MoneyAgeResult.empty(String transactionId) {
    return MoneyAgeResult(
      transactionId: transactionId,
      moneyAge: 0,
      consumptions: const [],
      totalAmount: 0,
      coveredAmount: 0,
      uncoveredAmount: 0,
    );
  }
}

/// 钱龄核心模型（用于展示）
class MoneyAge {
  final int days;

  const MoneyAge({required this.days});

  /// 钱龄描述
  String get description {
    if (days >= 90) return '可应对各种意外，财务非常自由';
    if (days >= 60) return '财务状况非常稳健';
    if (days >= 30) return '资金周转非常健康，可以应对一个月的开支';
    if (days >= 14) return '资金周转较好，可以应对两周的开支';
    if (days >= 7) return '资金周转尚可，建议增加储蓄缓冲';
    return '您可能在花费刚收到的钱，建议建立更多储蓄';
  }

  /// 健康等级
  MoneyAgeLevel get level {
    if (days < 7) return MoneyAgeLevel.danger;
    if (days < 14) return MoneyAgeLevel.warning;
    if (days < 30) return MoneyAgeLevel.normal;
    if (days < 60) return MoneyAgeLevel.good;
    if (days < 90) return MoneyAgeLevel.excellent;
    return MoneyAgeLevel.ideal;
  }

  /// 是否健康（>=14天视为健康）
  bool get isHealthy => days >= 14;

  /// 是否处于危险状态
  bool get isDanger => days < 7;

  /// 是否处于警告状态
  bool get isWarning => days >= 7 && days < 14;

  /// 改善建议列表
  List<String> get suggestions {
    switch (level) {
      case MoneyAgeLevel.danger:
        return [
          '建议设置紧急储备金目标',
          '检查是否有可削减的非必要支出',
          '考虑增加收入来源',
        ];
      case MoneyAgeLevel.warning:
        return [
          '继续保持储蓄习惯',
          '避免大额冲动消费',
          '为下个月的大额支出提前规划',
        ];
      case MoneyAgeLevel.normal:
        return [
          '您的财务状况正在改善',
          '尝试每月额外储蓄10%',
          '建立应急基金目标',
        ];
      case MoneyAgeLevel.good:
        return [
          '保持良好的财务习惯',
          '可以考虑增加投资配置',
          '设立更长期的财务目标',
        ];
      case MoneyAgeLevel.excellent:
        return [
          '您的财务状况非常优秀',
          '可以考虑多元化投资',
          '帮助家人建立良好财务习惯',
        ];
      case MoneyAgeLevel.ideal:
        return [
          '恭喜！您已达到理想的财务状态',
          '继续保持这一优秀习惯',
          '可以考虑财务传承规划',
        ];
    }
  }

  factory MoneyAge.fromResult(MoneyAgeResult result) {
    return MoneyAge(days: result.moneyAge);
  }

  factory MoneyAge.fromDays(int days) {
    return MoneyAge(days: days);
  }
}

/// 每日钱龄数据（用于趋势图）
class DailyMoneyAge {
  final DateTime date;
  final int averageAge;
  final MoneyAgeLevel level;

  const DailyMoneyAge({
    required this.date,
    required this.averageAge,
    required this.level,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.millisecondsSinceEpoch,
      'averageAge': averageAge,
      'level': level.index,
    };
  }

  factory DailyMoneyAge.fromMap(Map<String, dynamic> map) {
    return DailyMoneyAge(
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      averageAge: map['averageAge'] as int,
      level: MoneyAgeLevel.values[map['level'] as int],
    );
  }
}

/// 钱龄统计汇总
class MoneyAgeStatistics {
  final int averageAge;                    // 当前平均钱龄
  final List<DailyMoneyAge> trend;         // 钱龄趋势（最近30天）
  final Map<String, int> ageByCategory;    // 按分类的钱龄分布
  final Map<String, int> ageByAccount;     // 按账户的钱龄分布
  final double totalResourcePoolBalance;   // 资源池总余额
  final int activePoolCount;               // 活跃资源池数量
  final DateTime calculatedAt;             // 统计计算时间

  const MoneyAgeStatistics({
    required this.averageAge,
    required this.trend,
    required this.ageByCategory,
    required this.ageByAccount,
    required this.totalResourcePoolBalance,
    required this.activePoolCount,
    required this.calculatedAt,
  });

  /// 健康等级
  MoneyAgeLevel get healthLevel {
    if (averageAge < 7) return MoneyAgeLevel.danger;
    if (averageAge < 14) return MoneyAgeLevel.warning;
    if (averageAge < 30) return MoneyAgeLevel.normal;
    if (averageAge < 60) return MoneyAgeLevel.good;
    if (averageAge < 90) return MoneyAgeLevel.excellent;
    return MoneyAgeLevel.ideal;
  }

  /// 趋势方向：up, down, stable
  String get trendDirection {
    if (trend.length < 2) return 'stable';
    final recent = trend.take(7).map((e) => e.averageAge).toList();
    final older = trend.skip(7).take(7).map((e) => e.averageAge).toList();
    if (recent.isEmpty || older.isEmpty) return 'stable';

    // 修复：虽然有isEmpty检查，但为了安全起见，再次确认列表不为空
    if (recent.isEmpty || older.isEmpty) return 'stable';

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;

    final diff = recentAvg - olderAvg;
    if (diff > 3) return 'up';
    if (diff < -3) return 'down';
    return 'stable';
  }

  /// 改善建议
  List<String> get suggestions {
    return MoneyAge(days: averageAge).suggestions;
  }

  factory MoneyAgeStatistics.empty() {
    return MoneyAgeStatistics(
      averageAge: 0,
      trend: const [],
      ageByCategory: const {},
      ageByAccount: const {},
      totalResourcePoolBalance: 0,
      activePoolCount: 0,
      calculatedAt: DateTime.now(),
    );
  }
}

/// 钱龄影响因素分析结果
class MoneyAgeImpactAnalysis {
  final String categoryId;
  final String categoryName;
  final double impactDays;        // 对钱龄的影响天数（负数表示拉低）
  final double totalAmount;       // 该分类的总支出金额
  final int transactionCount;     // 交易笔数
  final double averageMoneyAge;   // 该分类消费的平均钱龄

  const MoneyAgeImpactAnalysis({
    required this.categoryId,
    required this.categoryName,
    required this.impactDays,
    required this.totalAmount,
    required this.transactionCount,
    required this.averageMoneyAge,
  });

  /// 是否对钱龄有负面影响
  bool get hasNegativeImpact => impactDays < 0;

  /// 影响程度描述
  String get impactDescription {
    final absImpact = impactDays.abs();
    if (absImpact < 1) return '影响较小';
    if (absImpact < 3) return '影响适中';
    if (absImpact < 7) return '影响较大';
    return '影响显著';
  }
}

/// 钱龄仪表盘数据（从后端API获取）
class MoneyAgeDashboard {
  final double avgMoneyAge;
  final int medianMoneyAge;
  final String currentHealthLevel;
  final int healthCount;
  final int warningCount;
  final int dangerCount;
  final int totalResourcePools;
  final int activeResourcePools;
  final double totalRemainingAmount;
  final List<Map<String, dynamic>> trendData;

  const MoneyAgeDashboard({
    required this.avgMoneyAge,
    required this.medianMoneyAge,
    required this.currentHealthLevel,
    required this.healthCount,
    required this.warningCount,
    required this.dangerCount,
    required this.totalResourcePools,
    required this.activeResourcePools,
    required this.totalRemainingAmount,
    required this.trendData,
  });

  factory MoneyAgeDashboard.fromJson(Map<String, dynamic> json) {
    return MoneyAgeDashboard(
      avgMoneyAge: (json['avg_money_age'] as num?)?.toDouble() ?? 0.0,
      medianMoneyAge: json['median_money_age'] as int? ?? 0,
      currentHealthLevel: json['current_health_level'] as String? ?? 'normal',
      healthCount: json['health_count'] as int? ?? 0,
      warningCount: json['warning_count'] as int? ?? 0,
      dangerCount: json['danger_count'] as int? ?? 0,
      totalResourcePools: json['total_resource_pools'] as int? ?? 0,
      activeResourcePools: json['active_resource_pools'] as int? ?? 0,
      totalRemainingAmount: (json['total_remaining_amount'] as num?)?.toDouble() ?? 0.0,
      trendData: (json['trend_data'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }
}
