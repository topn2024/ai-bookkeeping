/// Budget Events
///
/// 预算相关的领域事件。
library;

import 'domain_event.dart';

/// 预算超支事件
class BudgetExceededEvent extends DomainEvent {
  /// 预算 ID
  final String budgetId;

  /// 预算名称
  final String? budgetName;

  /// 分类
  final String? category;

  /// 预算金额
  final double budgetAmount;

  /// 已使用金额
  final double usedAmount;

  /// 超支金额
  final double exceededAmount;

  /// 使用百分比
  final double usagePercent;

  /// 预算周期开始日期
  final DateTime? periodStart;

  /// 预算周期结束日期
  final DateTime? periodEnd;

  BudgetExceededEvent({
    required this.budgetId,
    this.budgetName,
    this.category,
    required this.budgetAmount,
    required this.usedAmount,
    this.periodStart,
    this.periodEnd,
    super.metadata,
  })  : exceededAmount = usedAmount - budgetAmount,
        usagePercent = budgetAmount > 0 ? (usedAmount / budgetAmount) * 100 : 0,
        super(
          aggregateId: budgetId,
          aggregateType: 'Budget',
        );

  @override
  String get eventName => 'BudgetExceeded';

  @override
  Map<String, dynamic> get eventData => {
        'budgetId': budgetId,
        'budgetName': budgetName,
        'category': category,
        'budgetAmount': budgetAmount,
        'usedAmount': usedAmount,
        'exceededAmount': exceededAmount,
        'usagePercent': usagePercent,
        'periodStart': periodStart?.toIso8601String(),
        'periodEnd': periodEnd?.toIso8601String(),
      };
}

/// 预算预警事件
class BudgetWarningEvent extends DomainEvent {
  /// 预算 ID
  final String budgetId;

  /// 预算名称
  final String? budgetName;

  /// 分类
  final String? category;

  /// 预算金额
  final double budgetAmount;

  /// 已使用金额
  final double usedAmount;

  /// 使用百分比
  final double usagePercent;

  /// 预警阈值（如 80%）
  final double warningThreshold;

  BudgetWarningEvent({
    required this.budgetId,
    this.budgetName,
    this.category,
    required this.budgetAmount,
    required this.usedAmount,
    required this.warningThreshold,
    super.metadata,
  })  : usagePercent = budgetAmount > 0 ? (usedAmount / budgetAmount) * 100 : 0,
        super(
          aggregateId: budgetId,
          aggregateType: 'Budget',
        );

  @override
  String get eventName => 'BudgetWarning';

  @override
  Map<String, dynamic> get eventData => {
        'budgetId': budgetId,
        'budgetName': budgetName,
        'category': category,
        'budgetAmount': budgetAmount,
        'usedAmount': usedAmount,
        'usagePercent': usagePercent,
        'warningThreshold': warningThreshold,
      };
}

/// 预算创建事件
class BudgetCreatedEvent extends DomainEvent {
  /// 预算 ID
  final String budgetId;

  /// 预算名称
  final String name;

  /// 分类
  final String? category;

  /// 预算金额
  final double amount;

  /// 周期类型 (monthly/weekly/yearly)
  final String periodType;

  BudgetCreatedEvent({
    required this.budgetId,
    required this.name,
    this.category,
    required this.amount,
    required this.periodType,
    super.metadata,
  }) : super(
          aggregateId: budgetId,
          aggregateType: 'Budget',
        );

  @override
  String get eventName => 'BudgetCreated';

  @override
  Map<String, dynamic> get eventData => {
        'budgetId': budgetId,
        'name': name,
        'category': category,
        'amount': amount,
        'periodType': periodType,
      };
}

/// 预算更新事件
class BudgetUpdatedEvent extends DomainEvent {
  /// 预算 ID
  final String budgetId;

  /// 更新的字段
  final Map<String, dynamic> changes;

  BudgetUpdatedEvent({
    required this.budgetId,
    required this.changes,
    super.metadata,
  }) : super(
          aggregateId: budgetId,
          aggregateType: 'Budget',
        );

  @override
  String get eventName => 'BudgetUpdated';

  @override
  Map<String, dynamic> get eventData => {
        'budgetId': budgetId,
        'changes': changes,
      };
}

/// 预算执行更新事件
class BudgetExecutionUpdatedEvent extends DomainEvent {
  /// 预算 ID
  final String budgetId;

  /// 之前使用金额
  final double previousUsed;

  /// 当前使用金额
  final double currentUsed;

  /// 变化金额
  final double changeAmount;

  /// 关联的交易 ID
  final String? transactionId;

  BudgetExecutionUpdatedEvent({
    required this.budgetId,
    required this.previousUsed,
    required this.currentUsed,
    this.transactionId,
    super.metadata,
  })  : changeAmount = currentUsed - previousUsed,
        super(
          aggregateId: budgetId,
          aggregateType: 'Budget',
        );

  @override
  String get eventName => 'BudgetExecutionUpdated';

  @override
  Map<String, dynamic> get eventData => {
        'budgetId': budgetId,
        'previousUsed': previousUsed,
        'currentUsed': currentUsed,
        'changeAmount': changeAmount,
        'transactionId': transactionId,
      };
}
