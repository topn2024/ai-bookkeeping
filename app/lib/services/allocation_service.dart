import 'dart:math';

import '../models/budget_vault.dart';
import '../models/transaction.dart';

/// 分配结果状态
enum AllocationResultStatus {
  /// 成功
  success,

  /// 部分成功（有未分配金额）
  partial,

  /// 警告（百分比超过100%等）
  warning,

  /// 无效（输入错误）
  invalid,
}

/// 分配策略
enum AllocationStrategy {
  /// 按优先级（固定支出 > 债务 > 储蓄 > 弹性）
  priority,

  /// 按比例（所有小金库按配置比例分配）
  proportional,

  /// 先满足固定，剩余按比例
  hybridPriorityProportional,
}

/// 单个小金库的分配详情
class VaultAllocationDetail {
  final String vaultId;
  final String vaultName;
  final double amount;
  final AllocationType type;
  final String? note;

  const VaultAllocationDetail({
    required this.vaultId,
    required this.vaultName,
    required this.amount,
    required this.type,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'vaultId': vaultId,
      'vaultName': vaultName,
      'amount': amount,
      'type': type.index,
      'note': note,
    };
  }

  factory VaultAllocationDetail.fromMap(Map<String, dynamic> map) {
    return VaultAllocationDetail(
      vaultId: map['vaultId'] as String,
      vaultName: map['vaultName'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: AllocationType.values[map['type'] as int],
      note: map['note'] as String?,
    );
  }
}

/// 分配结果
class AllocationResult {
  final AllocationResultStatus status;
  final List<VaultAllocationDetail> allocations;
  final double unallocatedAmount;
  final String? message;
  final String? suggestion;

  const AllocationResult({
    required this.status,
    required this.allocations,
    this.unallocatedAmount = 0,
    this.message,
    this.suggestion,
  });

  /// 成功分配
  factory AllocationResult.success({
    required List<VaultAllocationDetail> allocations,
  }) {
    return AllocationResult(
      status: AllocationResultStatus.success,
      allocations: allocations,
    );
  }

  /// 部分分配
  factory AllocationResult.partial({
    required List<VaultAllocationDetail> allocations,
    required double unallocated,
    String? suggestion,
  }) {
    return AllocationResult(
      status: AllocationResultStatus.partial,
      allocations: allocations,
      unallocatedAmount: unallocated,
      message: '有 ¥${unallocated.toStringAsFixed(2)} 未分配',
      suggestion: suggestion,
    );
  }

  /// 警告
  factory AllocationResult.warning({
    required List<VaultAllocationDetail> allocations,
    required String warning,
  }) {
    return AllocationResult(
      status: AllocationResultStatus.warning,
      allocations: allocations,
      message: warning,
    );
  }

  /// 无效
  factory AllocationResult.invalid(String message) {
    return AllocationResult(
      status: AllocationResultStatus.invalid,
      allocations: const [],
      message: message,
    );
  }

  /// 总分配金额
  double get totalAllocated =>
      allocations.fold(0.0, (sum, a) => sum + a.amount);

  /// 是否成功
  bool get isSuccess => status == AllocationResultStatus.success;

  /// 是否有未分配金额
  bool get hasUnallocated => unallocatedAmount > 0.01;
}

/// 分配建议
class AllocationSuggestion {
  final String vaultId;
  final String vaultName;
  final double suggestedAmount;
  final String reason;
  final int priority;
  final VaultType vaultType;
  final double? shortfall; // 距离目标还差多少

  const AllocationSuggestion({
    required this.vaultId,
    required this.vaultName,
    required this.suggestedAmount,
    required this.reason,
    required this.priority,
    required this.vaultType,
    this.shortfall,
  });

  Map<String, dynamic> toMap() {
    return {
      'vaultId': vaultId,
      'vaultName': vaultName,
      'suggestedAmount': suggestedAmount,
      'reason': reason,
      'priority': priority,
      'vaultType': vaultType.index,
      'shortfall': shortfall,
    };
  }
}

/// 预分配预览
class AllocationPreview {
  final List<VaultAllocationDetail> allocations;
  final double totalIncome;
  final double totalAllocated;
  final double remaining;
  final List<String> warnings;
  final Map<VaultType, double> allocationByType;

  const AllocationPreview({
    required this.allocations,
    required this.totalIncome,
    required this.totalAllocated,
    required this.remaining,
    required this.warnings,
    required this.allocationByType,
  });

  /// 分配覆盖率
  double get coverageRate =>
      totalIncome > 0 ? totalAllocated / totalIncome : 0;

  /// 是否完全覆盖
  bool get isFullyCovered => remaining < 0.01;
}

/// 零基预算分配服务
///
/// 支持多种分配策略：
/// - 固定金额分配
/// - 百分比分配
/// - 剩余金额分配
/// - 补齐到目标金额
class AllocationService {
  /// 待分配金额计算
  double calculateUnallocatedAmount({
    required double totalIncome,
    required List<BudgetVault> vaults,
  }) {
    final totalAllocated = vaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    return totalIncome - totalAllocated;
  }

  /// 分配收入到小金库
  AllocationResult allocateIncome({
    required double incomeAmount,
    required List<BudgetVault> vaults,
    AllocationStrategy strategy = AllocationStrategy.priority,
  }) {
    // 1. 验证输入
    if (incomeAmount <= 0) {
      return AllocationResult.invalid('收入金额必须大于0');
    }

    if (vaults.isEmpty) {
      return AllocationResult.invalid('请先创建至少一个小金库');
    }

    final enabledVaults = vaults.where((v) => v.isEnabled).toList();
    if (enabledVaults.isEmpty) {
      return AllocationResult.invalid('没有启用的小金库');
    }

    // 2. 按策略分配
    switch (strategy) {
      case AllocationStrategy.priority:
        return _allocateByPriority(incomeAmount, enabledVaults);
      case AllocationStrategy.proportional:
        return _allocateProportionally(incomeAmount, enabledVaults);
      case AllocationStrategy.hybridPriorityProportional:
        return _allocateHybrid(incomeAmount, enabledVaults);
    }
  }

  /// 按优先级分配
  AllocationResult _allocateByPriority(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) {
    final allocations = <VaultAllocationDetail>[];
    var remainingAmount = incomeAmount;

    // 按优先级排序：固定 > 债务 > 储蓄 > 弹性
    // 同类型内按 sortOrder 排序
    final sortedVaults = List<BudgetVault>.from(vaults)
      ..sort((a, b) {
        final priorityCompare =
            a.type.allocationPriority.compareTo(b.type.allocationPriority);
        if (priorityCompare != 0) return priorityCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });

    // 先处理非 remainder 类型
    final nonRemainderVaults =
        sortedVaults.where((v) => v.allocationType != AllocationType.remainder);
    final remainderVaults =
        sortedVaults.where((v) => v.allocationType == AllocationType.remainder);

    for (final vault in nonRemainderVaults) {
      if (remainingAmount <= 0) break;

      final allocationAmount =
          _calculateAllocationAmount(vault, incomeAmount, remainingAmount);

      if (allocationAmount > 0) {
        allocations.add(VaultAllocationDetail(
          vaultId: vault.id,
          vaultName: vault.name,
          amount: allocationAmount,
          type: vault.allocationType,
        ));
        remainingAmount -= allocationAmount;
      }
    }

    // 处理 remainder 类型（分配剩余金额）
    for (final vault in remainderVaults) {
      if (remainingAmount <= 0) break;

      allocations.add(VaultAllocationDetail(
        vaultId: vault.id,
        vaultName: vault.name,
        amount: remainingAmount,
        type: vault.allocationType,
      ));
      remainingAmount = 0;
    }

    return _buildResult(allocations, remainingAmount, vaults);
  }

  /// 按比例分配
  AllocationResult _allocateProportionally(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) {
    final allocations = <VaultAllocationDetail>[];
    var remainingAmount = incomeAmount;

    // 计算百分比总和
    final percentageVaults =
        vaults.where((v) => v.allocationType == AllocationType.percentage);
    final totalPercentage = percentageVaults.fold(
      0.0,
      (sum, v) => sum + (v.targetPercentage ?? 0),
    );

    // 按比例分配
    for (final vault in percentageVaults) {
      if (remainingAmount <= 0) break;

      double percentage = vault.targetPercentage ?? 0;

      // 如果百分比总和超过100%，按比例缩放
      if (totalPercentage > 1.0) {
        percentage = percentage / totalPercentage;
      }

      final allocationAmount = min(incomeAmount * percentage, remainingAmount);

      if (allocationAmount > 0) {
        allocations.add(VaultAllocationDetail(
          vaultId: vault.id,
          vaultName: vault.name,
          amount: allocationAmount,
          type: vault.allocationType,
        ));
        remainingAmount -= allocationAmount;
      }
    }

    // 处理固定金额和其他类型
    final otherVaults =
        vaults.where((v) => v.allocationType != AllocationType.percentage);
    for (final vault in otherVaults) {
      if (remainingAmount <= 0) break;

      final allocationAmount =
          _calculateAllocationAmount(vault, incomeAmount, remainingAmount);

      if (allocationAmount > 0) {
        allocations.add(VaultAllocationDetail(
          vaultId: vault.id,
          vaultName: vault.name,
          amount: allocationAmount,
          type: vault.allocationType,
        ));
        remainingAmount -= allocationAmount;
      }
    }

    return _buildResult(allocations, remainingAmount, vaults);
  }

  /// 混合策略：先满足固定支出，剩余按比例
  AllocationResult _allocateHybrid(
    double incomeAmount,
    List<BudgetVault> vaults,
  ) {
    final allocations = <VaultAllocationDetail>[];
    var remainingAmount = incomeAmount;

    // 1. 先处理固定支出和债务（高优先级）
    final highPriorityVaults = vaults.where(
      (v) => v.type == VaultType.fixed || v.type == VaultType.debt,
    );

    for (final vault in highPriorityVaults) {
      if (remainingAmount <= 0) break;

      final allocationAmount =
          _calculateAllocationAmount(vault, incomeAmount, remainingAmount);

      if (allocationAmount > 0) {
        allocations.add(VaultAllocationDetail(
          vaultId: vault.id,
          vaultName: vault.name,
          amount: allocationAmount,
          type: vault.allocationType,
        ));
        remainingAmount -= allocationAmount;
      }
    }

    // 2. 剩余部分按比例分配给储蓄和弹性支出
    final lowPriorityVaults = vaults.where(
      (v) => v.type == VaultType.savings || v.type == VaultType.flexible,
    );

    // 计算低优先级小金库的百分比总和
    final totalPercentage = lowPriorityVaults
        .where((v) => v.allocationType == AllocationType.percentage)
        .fold(0.0, (sum, v) => sum + (v.targetPercentage ?? 0));

    for (final vault in lowPriorityVaults) {
      if (remainingAmount <= 0) break;

      double allocationAmount;

      if (vault.allocationType == AllocationType.percentage) {
        double percentage = vault.targetPercentage ?? 0;
        if (totalPercentage > 0) {
          // 基于剩余金额按比例分配
          percentage = percentage / max(totalPercentage, 1.0);
        }
        allocationAmount = remainingAmount * percentage;
      } else {
        allocationAmount =
            _calculateAllocationAmount(vault, incomeAmount, remainingAmount);
      }

      if (allocationAmount > 0) {
        allocations.add(VaultAllocationDetail(
          vaultId: vault.id,
          vaultName: vault.name,
          amount: allocationAmount,
          type: vault.allocationType,
        ));
        remainingAmount -= allocationAmount;
      }
    }

    return _buildResult(allocations, remainingAmount, vaults);
  }

  /// 计算单个小金库的分配金额
  double _calculateAllocationAmount(
    BudgetVault vault,
    double totalIncome,
    double remainingAmount,
  ) {
    switch (vault.allocationType) {
      case AllocationType.fixed:
        // 固定金额
        return min(vault.targetAllocation ?? 0, remainingAmount);

      case AllocationType.percentage:
        // 百分比（基于总收入）
        final percentageAmount = totalIncome * (vault.targetPercentage ?? 0);
        return min(percentageAmount, remainingAmount);

      case AllocationType.remainder:
        // 剩余金额
        return remainingAmount;

      case AllocationType.topUp:
        // 补足到目标金额
        final needed = vault.targetAmount - vault.currentAmount;
        return min(max(needed, 0), remainingAmount);
    }
  }

  /// 构建分配结果
  AllocationResult _buildResult(
    List<VaultAllocationDetail> allocations,
    double remainingAmount,
    List<BudgetVault> vaults,
  ) {
    // 检查百分比总和
    final percentageVaults =
        vaults.where((v) => v.allocationType == AllocationType.percentage);
    final totalPercentage = percentageVaults.fold(
      0.0,
      (sum, v) => sum + (v.targetPercentage ?? 0),
    );

    if (totalPercentage > 1.0) {
      return AllocationResult.warning(
        allocations: allocations,
        warning: '百分比总和超过100%（${(totalPercentage * 100).toStringAsFixed(1)}%），实际按比例调整',
      );
    }

    if (remainingAmount > 0.01) {
      return AllocationResult.partial(
        allocations: allocations,
        unallocated: remainingAmount,
        suggestion: '建议创建"机动资金"小金库来接收剩余金额',
      );
    }

    return AllocationResult.success(allocations: allocations);
  }

  /// 获取智能分配建议
  List<AllocationSuggestion> getSuggestions({
    required double unallocatedAmount,
    required List<BudgetVault> vaults,
  }) {
    if (unallocatedAmount <= 0) return [];

    final suggestions = <AllocationSuggestion>[];
    final enabledVaults = vaults.where((v) => v.isEnabled).toList();

    // 1. 优先满足固定支出
    for (final vault in enabledVaults.where((v) => v.type == VaultType.fixed)) {
      final shortfall = vault.targetAmount - vault.allocatedAmount;
      if (shortfall > 0) {
        suggestions.add(AllocationSuggestion(
          vaultId: vault.id,
          vaultName: vault.name,
          suggestedAmount: min(shortfall, unallocatedAmount),
          reason: '固定支出需要优先保障',
          priority: 1,
          vaultType: vault.type,
          shortfall: shortfall,
        ));
      }
    }

    // 2. 债务还款
    for (final vault in enabledVaults.where((v) => v.type == VaultType.debt)) {
      final shortfall = vault.targetAmount - vault.allocatedAmount;
      if (shortfall > 0) {
        suggestions.add(AllocationSuggestion(
          vaultId: vault.id,
          vaultName: vault.name,
          suggestedAmount: min(shortfall, unallocatedAmount),
          reason: '按时还款避免利息和信用影响',
          priority: 2,
          vaultType: vault.type,
          shortfall: shortfall,
        ));
      }
    }

    // 3. 储蓄目标
    for (final vault
        in enabledVaults.where((v) => v.type == VaultType.savings)) {
      final shortfall = vault.targetAmount - vault.allocatedAmount;
      if (shortfall > 0) {
        // 储蓄建议分配一定比例
        final suggestedAmount = min(
          shortfall,
          unallocatedAmount * 0.3, // 建议储蓄30%
        );
        suggestions.add(AllocationSuggestion(
          vaultId: vault.id,
          vaultName: vault.name,
          suggestedAmount: suggestedAmount,
          reason: '建立财务缓冲，提高钱龄',
          priority: 3,
          vaultType: vault.type,
          shortfall: shortfall,
        ));
      }
    }

    // 4. 弹性支出
    for (final vault
        in enabledVaults.where((v) => v.type == VaultType.flexible)) {
      final shortfall = vault.targetAmount - vault.allocatedAmount;
      if (shortfall > 0) {
        suggestions.add(AllocationSuggestion(
          vaultId: vault.id,
          vaultName: vault.name,
          suggestedAmount: min(shortfall, unallocatedAmount),
          reason: '满足日常弹性消费需求',
          priority: 4,
          vaultType: vault.type,
          shortfall: shortfall,
        ));
      }
    }

    // 按优先级排序
    suggestions.sort((a, b) => a.priority.compareTo(b.priority));

    return suggestions;
  }

  /// 生成分配预览（不实际执行）
  AllocationPreview previewAllocation({
    required double incomeAmount,
    required List<BudgetVault> vaults,
    AllocationStrategy strategy = AllocationStrategy.priority,
  }) {
    final result = allocateIncome(
      incomeAmount: incomeAmount,
      vaults: vaults,
      strategy: strategy,
    );

    // 按类型汇总
    final allocationByType = <VaultType, double>{};
    for (final allocation in result.allocations) {
      final vault = vaults.firstWhere((v) => v.id == allocation.vaultId);
      allocationByType[vault.type] =
          (allocationByType[vault.type] ?? 0) + allocation.amount;
    }

    // 生成警告
    final warnings = <String>[];
    if (result.message != null &&
        result.status != AllocationResultStatus.success) {
      warnings.add(result.message!);
    }

    // 检查是否有固定支出未满足
    for (final vault in vaults.where((v) => v.type == VaultType.fixed)) {
      final allocation = result.allocations
          .where((a) => a.vaultId == vault.id)
          .fold(0.0, (sum, a) => sum + a.amount);
      final total = vault.allocatedAmount + allocation;
      if (total < vault.targetAmount) {
        warnings.add('${vault.name}未能满足目标金额');
      }
    }

    return AllocationPreview(
      allocations: result.allocations,
      totalIncome: incomeAmount,
      totalAllocated: result.totalAllocated,
      remaining: result.unallocatedAmount,
      warnings: warnings,
      allocationByType: allocationByType,
    );
  }

  /// 一键智能分配
  AllocationResult autoAllocate({
    required double unallocatedAmount,
    required List<BudgetVault> vaults,
  }) {
    final suggestions = getSuggestions(
      unallocatedAmount: unallocatedAmount,
      vaults: vaults,
    );

    if (suggestions.isEmpty) {
      return AllocationResult.invalid('没有需要分配的小金库');
    }

    var remaining = unallocatedAmount;
    final allocations = <VaultAllocationDetail>[];

    for (final suggestion in suggestions) {
      if (remaining <= 0) break;

      final amount = min(suggestion.suggestedAmount, remaining);
      final vault = vaults.firstWhere((v) => v.id == suggestion.vaultId);

      allocations.add(VaultAllocationDetail(
        vaultId: suggestion.vaultId,
        vaultName: suggestion.vaultName,
        amount: amount,
        type: vault.allocationType,
        note: suggestion.reason,
      ));
      remaining -= amount;
    }

    if (remaining > 0.01) {
      return AllocationResult.partial(
        allocations: allocations,
        unallocated: remaining,
        suggestion: '有 ¥${remaining.toStringAsFixed(2)} 未分配',
      );
    }

    return AllocationResult.success(allocations: allocations);
  }

  /// 验证分配配置
  List<String> validateAllocationConfig(List<BudgetVault> vaults) {
    final errors = <String>[];

    // 检查百分比总和
    final percentageVaults =
        vaults.where((v) => v.allocationType == AllocationType.percentage);
    final totalPercentage = percentageVaults.fold(
      0.0,
      (sum, v) => sum + (v.targetPercentage ?? 0),
    );

    if (totalPercentage > 1.0) {
      errors.add('百分比分配总和超过100%（当前${(totalPercentage * 100).toStringAsFixed(1)}%）');
    }

    // 检查是否有多个 remainder 类型
    final remainderCount =
        vaults.where((v) => v.allocationType == AllocationType.remainder).length;
    if (remainderCount > 1) {
      errors.add('只能有一个"分配剩余"类型的小金库');
    }

    // 检查固定金额配置
    for (final vault
        in vaults.where((v) => v.allocationType == AllocationType.fixed)) {
      if (vault.targetAllocation == null || vault.targetAllocation! <= 0) {
        errors.add('${vault.name}：固定金额分配需要设置分配金额');
      }
    }

    // 检查百分比配置
    for (final vault
        in vaults.where((v) => v.allocationType == AllocationType.percentage)) {
      if (vault.targetPercentage == null ||
          vault.targetPercentage! <= 0 ||
          vault.targetPercentage! > 1) {
        errors.add('${vault.name}：百分比分配需要设置有效的百分比（0-100%）');
      }
    }

    return errors;
  }

  /// 计算需要多少收入才能满足所有小金库目标
  double calculateRequiredIncome(List<BudgetVault> vaults) {
    double fixedTotal = 0;
    double percentageTotal = 0;

    for (final vault in vaults.where((v) => v.isEnabled)) {
      switch (vault.allocationType) {
        case AllocationType.fixed:
          fixedTotal += vault.targetAllocation ?? 0;
          break;
        case AllocationType.percentage:
          percentageTotal += vault.targetPercentage ?? 0;
          break;
        case AllocationType.topUp:
          final needed = vault.targetAmount - vault.currentAmount;
          if (needed > 0) fixedTotal += needed;
          break;
        case AllocationType.remainder:
          // remainder 不影响所需收入
          break;
      }
    }

    // 如果百分比总和 >= 100%，无法满足
    if (percentageTotal >= 1.0) {
      return double.infinity;
    }

    // 固定金额 / (1 - 百分比总和)
    return fixedTotal / (1 - percentageTotal);
  }
}
