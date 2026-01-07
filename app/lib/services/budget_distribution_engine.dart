import 'dart:math';

import '../models/budget_vault.dart';

/// 分配策略
enum DistributionStrategy {
  /// 按优先级分配：固定支出 > 债务 > 储蓄 > 弹性
  priority,

  /// 按比例分配：根据设定的百分比分配
  proportional,

  /// 混合策略：先满足最低需求，再按比例分配剩余
  hybrid,

  /// 智能分配：基于历史数据和当前状态动态调整
  smart,

  /// 目标导向：优先满足即将到期的储蓄目标
  goalOriented,
}

extension DistributionStrategyExtension on DistributionStrategy {
  String get displayName {
    switch (this) {
      case DistributionStrategy.priority:
        return '按优先级分配';
      case DistributionStrategy.proportional:
        return '按比例分配';
      case DistributionStrategy.hybrid:
        return '混合策略';
      case DistributionStrategy.smart:
        return '智能分配';
      case DistributionStrategy.goalOriented:
        return '目标导向';
    }
  }

  String get description {
    switch (this) {
      case DistributionStrategy.priority:
        return '优先保障固定支出和债务还款';
      case DistributionStrategy.proportional:
        return '按设定比例分配到各小金库';
      case DistributionStrategy.hybrid:
        return '先满足最低需求，再按比例分配剩余';
      case DistributionStrategy.smart:
        return '基于消费习惯智能调整分配';
      case DistributionStrategy.goalOriented:
        return '优先完成即将到期的储蓄目标';
    }
  }
}

/// 单个小金库的分配结果
class VaultAssignment {
  final String vaultId;
  final String vaultName;
  final VaultType vaultType;
  final double requestedAmount;
  final double assignedAmount;
  final double previousBalance;
  final String reason;
  final int priority;

  const VaultAssignment({
    required this.vaultId,
    required this.vaultName,
    required this.vaultType,
    required this.requestedAmount,
    required this.assignedAmount,
    required this.previousBalance,
    required this.reason,
    required this.priority,
  });

  double get fulfillmentRate =>
      requestedAmount > 0 ? assignedAmount / requestedAmount : 1.0;

  bool get isFullyFunded => fulfillmentRate >= 1.0;

  double get shortfall => max(0, requestedAmount - assignedAmount);
}

/// 分配结果
class DistributionResult {
  final List<VaultAssignment> assignments;
  final double totalIncome;
  final double totalAssigned;
  final double remaining;
  final DistributionStrategy strategyUsed;
  final DateTime distributedAt;
  final List<String> warnings;
  final List<String> suggestions;

  const DistributionResult({
    required this.assignments,
    required this.totalIncome,
    required this.totalAssigned,
    required this.remaining,
    required this.strategyUsed,
    required this.distributedAt,
    this.warnings = const [],
    this.suggestions = const [],
  });

  /// 分配完成度
  double get completionRate =>
      totalIncome > 0 ? totalAssigned / totalIncome : 0;

  /// 是否全部分配
  bool get isFullyDistributed => remaining.abs() < 0.01;

  /// 未满足的小金库
  List<VaultAssignment> get underfundedVaults =>
      assignments.where((a) => !a.isFullyFunded).toList();

  /// 按类型汇总
  Map<VaultType, double> get byVaultType {
    final result = <VaultType, double>{};
    for (final assignment in assignments) {
      result[assignment.vaultType] =
          (result[assignment.vaultType] ?? 0) + assignment.assignedAmount;
    }
    return result;
  }

  /// 储蓄率
  double get savingsRate {
    final savingsAmount = assignments
        .where((a) => a.vaultType == VaultType.savings)
        .fold(0.0, (sum, a) => sum + a.assignedAmount);
    return totalIncome > 0 ? savingsAmount / totalIncome : 0;
  }
}

/// 分配配置
class DistributionConfig {
  final double minSavingsRate; // 最低储蓄率
  final double maxFlexibleRate; // 最高弹性支出率
  final bool allowOverAllocation; // 是否允许超额分配
  final bool prioritizeUpcomingDeadlines; // 是否优先即将到期的目标
  final int deadlineWarningDays; // 到期提前警告天数

  const DistributionConfig({
    this.minSavingsRate = 0.1,
    this.maxFlexibleRate = 0.4,
    this.allowOverAllocation = false,
    this.prioritizeUpcomingDeadlines = true,
    this.deadlineWarningDays = 30,
  });
}

/// 预算分配引擎
///
/// 支持多种分配策略，智能分配收入到各个小金库：
/// - 优先级分配：固定支出 > 债务 > 储蓄 > 弹性
/// - 比例分配：按预设百分比分配
/// - 混合策略：先满足最低需求，再按比例分配
/// - 智能分配：基于历史数据动态调整
/// - 目标导向：优先完成即将到期的储蓄目标
class BudgetDistributionEngine {
  final DistributionConfig _config;

  BudgetDistributionEngine([DistributionConfig? config])
      : _config = config ?? const DistributionConfig();

  /// 智能分配收入到各个小金库
  Future<DistributionResult> distributeIncome(
    double incomeAmount,
    List<BudgetVault> vaults,
    DistributionStrategy strategy,
  ) async {
    if (vaults.isEmpty) {
      return DistributionResult(
        assignments: [],
        totalIncome: incomeAmount,
        totalAssigned: 0,
        remaining: incomeAmount,
        strategyUsed: strategy,
        distributedAt: DateTime.now(),
        suggestions: ['请先创建小金库'],
      );
    }

    switch (strategy) {
      case DistributionStrategy.priority:
        return _distributePriority(incomeAmount, vaults);
      case DistributionStrategy.proportional:
        return _distributeProportional(incomeAmount, vaults);
      case DistributionStrategy.hybrid:
        return _distributeHybrid(incomeAmount, vaults);
      case DistributionStrategy.smart:
        return _distributeSmart(incomeAmount, vaults);
      case DistributionStrategy.goalOriented:
        return _distributeGoalOriented(incomeAmount, vaults);
    }
  }

  /// 按优先级分配
  Future<DistributionResult> _distributePriority(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) async {
    final assignments = <VaultAssignment>[];
    var remaining = incomeAmount;
    final warnings = <String>[];
    final suggestions = <String>[];

    // 按类型优先级排序：固定 > 债务 > 储蓄 > 弹性
    final priorityOrder = {
      VaultType.fixed: 1,
      VaultType.debt: 2,
      VaultType.savings: 3,
      VaultType.flexible: 4,
    };

    final sortedVaults = List<BudgetVault>.from(vaults)
      ..sort((a, b) {
        final priorityA = priorityOrder[a.type] ?? 99;
        final priorityB = priorityOrder[b.type] ?? 99;
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        // 同优先级按目标金额排序
        return b.targetAmount.compareTo(a.targetAmount);
      });

    for (final vault in sortedVaults) {
      final needed = _calculateNeededAmount(vault);
      final assigned = min(needed, remaining);

      assignments.add(VaultAssignment(
        vaultId: vault.id,
        vaultName: vault.name,
        vaultType: vault.type,
        requestedAmount: needed,
        assignedAmount: assigned,
        previousBalance: vault.allocatedAmount,
        reason: _getAssignmentReason(vault, assigned, needed),
        priority: priorityOrder[vault.type] ?? 99,
      ));

      remaining -= assigned;

      if (assigned < needed && vault.type == VaultType.fixed) {
        warnings.add('${vault.name}资金不足，缺口¥${(needed - assigned).toStringAsFixed(0)}');
      }
    }

    if (remaining > 0) {
      suggestions.add('还有¥${remaining.toStringAsFixed(0)}未分配，建议增加储蓄');
    }

    return DistributionResult(
      assignments: assignments,
      totalIncome: incomeAmount,
      totalAssigned: incomeAmount - remaining,
      remaining: remaining,
      strategyUsed: DistributionStrategy.priority,
      distributedAt: DateTime.now(),
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// 按比例分配
  Future<DistributionResult> _distributeProportional(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) async {
    final assignments = <VaultAssignment>[];
    var remaining = incomeAmount;
    final warnings = <String>[];
    final suggestions = <String>[];

    // 计算总目标金额
    final totalTarget = vaults.fold(0.0, (sum, v) => sum + v.targetAmount);

    for (final vault in vaults) {
      // 按目标金额占比分配
      double proportion = totalTarget > 0 ? vault.targetAmount / totalTarget : 0;

      // 如果小金库设置了固定百分比，优先使用
      if (vault.allocationType == AllocationType.percentage &&
          vault.targetPercentage != null) {
        proportion = vault.targetPercentage!;
      }

      final assigned = incomeAmount * proportion;

      assignments.add(VaultAssignment(
        vaultId: vault.id,
        vaultName: vault.name,
        vaultType: vault.type,
        requestedAmount: vault.targetAmount - vault.allocatedAmount,
        assignedAmount: assigned,
        previousBalance: vault.allocatedAmount,
        reason: '按${(proportion * 100).toStringAsFixed(1)}%比例分配',
        priority: vault.type == VaultType.fixed ? 1 : 3,
      ));

      remaining -= assigned;
    }

    // 处理舍入误差
    if (remaining.abs() < 1 && assignments.isNotEmpty) {
      // 把误差加到最后一个弹性小金库
      final flexibleVault = assignments.lastWhere(
        (a) => a.vaultType == VaultType.flexible,
        orElse: () => assignments.last,
      );
      final index = assignments.indexOf(flexibleVault);
      assignments[index] = VaultAssignment(
        vaultId: flexibleVault.vaultId,
        vaultName: flexibleVault.vaultName,
        vaultType: flexibleVault.vaultType,
        requestedAmount: flexibleVault.requestedAmount,
        assignedAmount: flexibleVault.assignedAmount + remaining,
        previousBalance: flexibleVault.previousBalance,
        reason: flexibleVault.reason,
        priority: flexibleVault.priority,
      );
      remaining = 0;
    }

    return DistributionResult(
      assignments: assignments,
      totalIncome: incomeAmount,
      totalAssigned: incomeAmount - remaining,
      remaining: remaining,
      strategyUsed: DistributionStrategy.proportional,
      distributedAt: DateTime.now(),
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// 混合策略：先满足最低需求，再按比例分配剩余
  Future<DistributionResult> _distributeHybrid(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) async {
    final assignments = <VaultAssignment>[];
    var remaining = incomeAmount;
    final warnings = <String>[];
    final suggestions = <String>[];

    // 第一轮：满足固定支出和债务的最低需求
    final mustPayVaults = vaults.where(
      (v) => v.type == VaultType.fixed || v.type == VaultType.debt,
    );

    for (final vault in mustPayVaults) {
      final needed = _calculateNeededAmount(vault);
      final assigned = min(needed, remaining);

      assignments.add(VaultAssignment(
        vaultId: vault.id,
        vaultName: vault.name,
        vaultType: vault.type,
        requestedAmount: needed,
        assignedAmount: assigned,
        previousBalance: vault.allocatedAmount,
        reason: '必要支出',
        priority: 1,
      ));

      remaining -= assigned;
    }

    // 第二轮：确保最低储蓄率
    final savingsVaults = vaults.where((v) => v.type == VaultType.savings);
    final minSavings = incomeAmount * _config.minSavingsRate;
    var currentSavings = 0.0;

    for (final vault in savingsVaults) {
      if (remaining <= 0) break;

      final needed = min(
        _calculateNeededAmount(vault),
        minSavings - currentSavings,
      );
      if (needed <= 0) continue;

      final assigned = min(needed, remaining);

      assignments.add(VaultAssignment(
        vaultId: vault.id,
        vaultName: vault.name,
        vaultType: vault.type,
        requestedAmount: _calculateNeededAmount(vault),
        assignedAmount: assigned,
        previousBalance: vault.allocatedAmount,
        reason: '保障${(_config.minSavingsRate * 100).toStringAsFixed(0)}%最低储蓄',
        priority: 2,
      ));

      remaining -= assigned;
      currentSavings += assigned;
    }

    // 第三轮：按比例分配剩余金额
    final flexibleVaults = vaults.where((v) => v.type == VaultType.flexible);
    final totalFlexibleTarget = flexibleVaults.fold(
      0.0,
      (sum, v) => sum + (v.targetAmount - v.allocatedAmount),
    );

    for (final vault in flexibleVaults) {
      if (remaining <= 0) break;

      final proportion = totalFlexibleTarget > 0
          ? (vault.targetAmount - vault.allocatedAmount) / totalFlexibleTarget
          : 1.0 / flexibleVaults.length;

      final assigned = min(remaining * proportion, remaining);

      assignments.add(VaultAssignment(
        vaultId: vault.id,
        vaultName: vault.name,
        vaultType: vault.type,
        requestedAmount: vault.targetAmount - vault.allocatedAmount,
        assignedAmount: assigned,
        previousBalance: vault.allocatedAmount,
        reason: '弹性分配',
        priority: 3,
      ));

      remaining -= assigned;
    }

    // 第四轮：剩余资金追加到储蓄
    if (remaining > 0 && savingsVaults.isNotEmpty) {
      final primarySavings = savingsVaults.first;
      final existingAssignment = assignments.firstWhere(
        (a) => a.vaultId == primarySavings.id,
        orElse: () => VaultAssignment(
          vaultId: primarySavings.id,
          vaultName: primarySavings.name,
          vaultType: VaultType.savings,
          requestedAmount: 0,
          assignedAmount: 0,
          previousBalance: primarySavings.allocatedAmount,
          reason: '追加储蓄',
          priority: 2,
        ),
      );

      final index = assignments.indexOf(existingAssignment);
      if (index >= 0) {
        assignments[index] = VaultAssignment(
          vaultId: existingAssignment.vaultId,
          vaultName: existingAssignment.vaultName,
          vaultType: existingAssignment.vaultType,
          requestedAmount: existingAssignment.requestedAmount,
          assignedAmount: existingAssignment.assignedAmount + remaining,
          previousBalance: existingAssignment.previousBalance,
          reason: '${existingAssignment.reason}+追加',
          priority: existingAssignment.priority,
        );
      } else {
        assignments.add(VaultAssignment(
          vaultId: primarySavings.id,
          vaultName: primarySavings.name,
          vaultType: VaultType.savings,
          requestedAmount: remaining,
          assignedAmount: remaining,
          previousBalance: primarySavings.allocatedAmount,
          reason: '追加储蓄',
          priority: 2,
        ));
      }

      suggestions.add('追加¥${remaining.toStringAsFixed(0)}到${primarySavings.name}');
      remaining = 0;
    }

    return DistributionResult(
      assignments: assignments,
      totalIncome: incomeAmount,
      totalAssigned: incomeAmount - remaining,
      remaining: remaining,
      strategyUsed: DistributionStrategy.hybrid,
      distributedAt: DateTime.now(),
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// 智能分配：基于历史数据动态调整
  Future<DistributionResult> _distributeSmart(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) async {
    final assignments = <VaultAssignment>[];
    var remaining = incomeAmount;
    final warnings = <String>[];
    final suggestions = <String>[];

    // 分析各小金库的历史执行情况
    for (final vault in vaults) {
      double smartAmount;
      String reason;

      // 根据使用率动态调整
      if (vault.usageRate > 0.9 && vault.type == VaultType.flexible) {
        // 经常超支的弹性小金库，增加预算
        smartAmount = vault.targetAmount * 1.15;
        reason = '历史经常超支，增加15%预算';
      } else if (vault.usageRate < 0.5 && vault.type == VaultType.flexible) {
        // 经常剩余的弹性小金库，减少预算
        smartAmount = vault.targetAmount * 0.85;
        reason = '历史结余较多，减少15%预算';
      } else if (vault.type == VaultType.savings && vault.progress < 0.5) {
        // 储蓄进度落后，加速
        smartAmount = (vault.targetAmount - vault.allocatedAmount) * 0.3;
        reason = '储蓄进度落后，加速储蓄';
      } else {
        smartAmount = _calculateNeededAmount(vault);
        reason = '按目标分配';
      }

      final assigned = min(smartAmount, remaining);

      assignments.add(VaultAssignment(
        vaultId: vault.id,
        vaultName: vault.name,
        vaultType: vault.type,
        requestedAmount: smartAmount,
        assignedAmount: assigned,
        previousBalance: vault.allocatedAmount,
        reason: reason,
        priority: vault.type == VaultType.fixed ? 1 : 3,
      ));

      remaining -= assigned;
    }

    return DistributionResult(
      assignments: assignments,
      totalIncome: incomeAmount,
      totalAssigned: incomeAmount - remaining,
      remaining: remaining,
      strategyUsed: DistributionStrategy.smart,
      distributedAt: DateTime.now(),
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// 目标导向：优先完成即将到期的储蓄目标
  Future<DistributionResult> _distributeGoalOriented(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) async {
    final assignments = <VaultAssignment>[];
    var remaining = incomeAmount;
    final warnings = <String>[];
    final suggestions = <String>[];

    // 先处理有截止日期的储蓄目标
    final deadlineVaults = vaults
        .where((v) =>
            v.type == VaultType.savings &&
            v.dueDate != null &&
            v.dueDate!.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    for (final vault in deadlineVaults) {
      final daysRemaining = vault.dueDate!.difference(DateTime.now()).inDays;
      final amountNeeded = vault.targetAmount - vault.allocatedAmount;

      double urgencyFactor;
      String reason;

      if (daysRemaining <= _config.deadlineWarningDays) {
        // 即将到期，优先分配
        urgencyFactor = 0.5; // 优先分配50%的剩余资金
        reason = '目标即将在${daysRemaining}天后到期，加速储蓄';
        warnings.add('${vault.name}将在${daysRemaining}天后到期');
      } else {
        // 按月均分配
        final monthsRemaining = max(1, daysRemaining ~/ 30);
        urgencyFactor = 1.0 / monthsRemaining;
        reason = '按月度均摊分配';
      }

      final targetAssignment = min(amountNeeded * urgencyFactor, remaining);
      final assigned = min(targetAssignment, remaining);

      assignments.add(VaultAssignment(
        vaultId: vault.id,
        vaultName: vault.name,
        vaultType: vault.type,
        requestedAmount: amountNeeded,
        assignedAmount: assigned,
        previousBalance: vault.allocatedAmount,
        reason: reason,
        priority: 1,
      ));

      remaining -= assigned;
    }

    // 处理其他小金库（使用混合策略）
    final otherVaults = vaults.where((v) =>
        !(v.type == VaultType.savings &&
            v.dueDate != null &&
            v.dueDate!.isAfter(DateTime.now())));

    final otherResult = await _distributeHybrid(remaining, otherVaults.toList());

    assignments.addAll(otherResult.assignments);
    remaining = otherResult.remaining;

    return DistributionResult(
      assignments: assignments,
      totalIncome: incomeAmount,
      totalAssigned: incomeAmount - remaining,
      remaining: remaining,
      strategyUsed: DistributionStrategy.goalOriented,
      distributedAt: DateTime.now(),
      warnings: [...warnings, ...otherResult.warnings],
      suggestions: [...suggestions, ...otherResult.suggestions],
    );
  }

  // ==================== 辅助方法 ====================

  /// 计算小金库所需金额
  double _calculateNeededAmount(BudgetVault vault) {
    switch (vault.allocationType) {
      case AllocationType.fixed:
        return vault.targetAllocation ?? vault.targetAmount;
      case AllocationType.topUp:
        return max(0, vault.targetAmount - vault.currentAmount);
      default:
        return max(0, vault.targetAmount - vault.allocatedAmount);
    }
  }

  /// 获取分配原因说明
  String _getAssignmentReason(BudgetVault vault, double assigned, double needed) {
    if (assigned >= needed) {
      return '完全满足目标需求';
    } else if (assigned > 0) {
      return '部分满足（${(assigned / needed * 100).toStringAsFixed(0)}%）';
    } else {
      return '资金不足，无法分配';
    }
  }

  /// 预览分配结果（不实际执行）
  Future<DistributionResult> previewDistribution(
    double incomeAmount,
    List<BudgetVault> vaults,
    DistributionStrategy strategy,
  ) async {
    return distributeIncome(incomeAmount, vaults, strategy);
  }

  /// 比较不同策略的分配结果
  Future<Map<DistributionStrategy, DistributionResult>> compareStrategies(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) async {
    final results = <DistributionStrategy, DistributionResult>{};

    for (final strategy in DistributionStrategy.values) {
      results[strategy] = await distributeIncome(incomeAmount, vaults, strategy);
    }

    return results;
  }

  /// 获取最优策略建议
  Future<DistributionStrategy> recommendStrategy(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) async {
    // 检查是否有即将到期的目标
    final hasUpcomingDeadlines = vaults.any((v) =>
        v.type == VaultType.savings &&
        v.dueDate != null &&
        v.dueDate!.difference(DateTime.now()).inDays <= _config.deadlineWarningDays);

    if (hasUpcomingDeadlines) {
      return DistributionStrategy.goalOriented;
    }

    // 检查是否有超支历史
    final hasOverspentHistory = vaults.any((v) =>
        v.type == VaultType.flexible && v.usageRate > 0.95);

    if (hasOverspentHistory) {
      return DistributionStrategy.smart;
    }

    // 检查固定支出占比
    final fixedAmount = vaults
        .where((v) => v.type == VaultType.fixed)
        .fold(0.0, (sum, v) => sum + v.targetAmount);

    if (fixedAmount > incomeAmount * 0.5) {
      // 固定支出占比高，优先保障
      return DistributionStrategy.priority;
    }

    // 默认使用混合策略
    return DistributionStrategy.hybrid;
  }
}
