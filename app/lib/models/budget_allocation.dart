/// 预算分配策略
enum BudgetAllocationStrategy {
  /// 统一预算 - 家庭共用一个预算池
  unified,
  /// 成员配额 - 每个成员有独立配额
  perMember,
  /// 分类负责 - 不同成员负责不同分类
  perCategory,
  /// 混合模式 - 部分统一+部分独立
  hybrid,
}

extension BudgetAllocationStrategyExtension on BudgetAllocationStrategy {
  String get displayName {
    switch (this) {
      case BudgetAllocationStrategy.unified:
        return '统一预算';
      case BudgetAllocationStrategy.perMember:
        return '成员配额';
      case BudgetAllocationStrategy.perCategory:
        return '分类负责';
      case BudgetAllocationStrategy.hybrid:
        return '混合模式';
    }
  }

  String get description {
    switch (this) {
      case BudgetAllocationStrategy.unified:
        return '全家共享一个预算池，最简单';
      case BudgetAllocationStrategy.perMember:
        return '每个成员有独立的消费配额';
      case BudgetAllocationStrategy.perCategory:
        return '不同成员负责不同消费分类';
      case BudgetAllocationStrategy.hybrid:
        return '部分预算统一，部分独立';
    }
  }
}

/// 预算告警类型
enum BudgetAlertType {
  /// 达到阈值
  threshold,
  /// 超支
  exceeded,
  /// 大额支出
  largeExpense,
}

/// 预算告警
class BudgetAlert {
  final String id;
  final String ledgerId;
  final BudgetAlertType type;
  final double threshold;
  final double currentValue;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const BudgetAlert({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.threshold,
    required this.currentValue,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });
}

/// 预算规则配置
class BudgetRules {
  final bool allowOverspend;
  final double? overspendLimit;
  final bool requireApprovalForLarge;
  final double? largeExpenseThreshold;
  final List<int> alertThresholds;

  const BudgetRules({
    this.allowOverspend = false,
    this.overspendLimit,
    this.requireApprovalForLarge = false,
    this.largeExpenseThreshold,
    this.alertThresholds = const [50, 80, 100],
  });
}
