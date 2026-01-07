import '../models/budget_vault.dart';
import 'allocation_service.dart';
import 'vault_repository.dart';

/// 钱龄等级
enum MoneyAgeLevel {
  /// 危险 (< 7天)
  danger,

  /// 警告 (7-14天)
  warning,

  /// 正常 (14-30天)
  normal,

  /// 良好 (30-60天)
  good,

  /// 优秀 (60-90天)
  excellent,

  /// 理想 (90+天)
  ideal,
}

extension MoneyAgeLevelExtension on MoneyAgeLevel {
  String get displayName {
    switch (this) {
      case MoneyAgeLevel.danger:
        return '危险';
      case MoneyAgeLevel.warning:
        return '警告';
      case MoneyAgeLevel.normal:
        return '正常';
      case MoneyAgeLevel.good:
        return '良好';
      case MoneyAgeLevel.excellent:
        return '优秀';
      case MoneyAgeLevel.ideal:
        return '理想';
    }
  }

  /// 根据天数判断等级
  static MoneyAgeLevel fromDays(int days) {
    if (days < 7) return MoneyAgeLevel.danger;
    if (days < 14) return MoneyAgeLevel.warning;
    if (days < 30) return MoneyAgeLevel.normal;
    if (days < 60) return MoneyAgeLevel.good;
    if (days < 90) return MoneyAgeLevel.excellent;
    return MoneyAgeLevel.ideal;
  }
}

/// 钱龄数据
class MoneyAge {
  final int days;
  final MoneyAgeLevel level;

  const MoneyAge({required this.days, required this.level});

  factory MoneyAge.fromDays(int days) {
    return MoneyAge(
      days: days,
      level: MoneyAgeLevelExtension.fromDays(days),
    );
  }
}

/// 钱龄影响预测
class MoneyAgeImpactPrediction {
  final int currentAge;
  final int projectedAge;
  final int change;
  final String recommendation;
  final ImpactType impactType;

  const MoneyAgeImpactPrediction({
    required this.currentAge,
    required this.projectedAge,
    required this.change,
    required this.recommendation,
    required this.impactType,
  });

  bool get isPositive => change > 0;
  bool get isNegative => change < 0;
  bool get isNeutral => change == 0;
}

/// 影响类型
enum ImpactType {
  /// 提升
  positive,

  /// 降低
  negative,

  /// 无影响
  neutral,
}

/// 预算调整建议
class BudgetAdjustmentSuggestion {
  final AdjustmentType adjustmentType;
  final double targetPercentage;
  final String reason;
  final List<VaultAdjustment> vaultAdjustments;

  const BudgetAdjustmentSuggestion({
    required this.adjustmentType,
    required this.targetPercentage,
    required this.reason,
    this.vaultAdjustments = const [],
  });

  factory BudgetAdjustmentSuggestion.noChange() {
    return const BudgetAdjustmentSuggestion(
      adjustmentType: AdjustmentType.noChange,
      targetPercentage: 0,
      reason: '当前预算配置合理，无需调整',
    );
  }
}

/// 调整类型
enum AdjustmentType {
  /// 增加储蓄
  increaseSavings,

  /// 减少弹性支出
  reduceFlexible,

  /// 调整债务还款
  adjustDebt,

  /// 无需调整
  noChange,
}

/// 单个小金库的调整建议
class VaultAdjustment {
  final String vaultId;
  final String vaultName;
  final double currentAmount;
  final double suggestedAmount;
  final String reason;

  const VaultAdjustment({
    required this.vaultId,
    required this.vaultName,
    required this.currentAmount,
    required this.suggestedAmount,
    required this.reason,
  });

  double get change => suggestedAmount - currentAmount;
  bool get isIncrease => change > 0;
}

/// 预算执行与钱龄联动服务
///
/// 分析预算分配对钱龄的影响，提供联动建议
class BudgetMoneyAgeIntegration {
  final VaultRepository _vaultRepo;

  // 模拟钱龄计算器接口
  int _currentMoneyAgeDays = 30; // 当前钱龄天数
  double _dailySpending = 200; // 日均消费

  BudgetMoneyAgeIntegration(this._vaultRepo);

  /// 设置当前钱龄（用于测试和外部数据注入）
  void setCurrentMoneyAge(int days) {
    _currentMoneyAgeDays = days;
  }

  /// 设置日均消费
  void setDailySpending(double amount) {
    _dailySpending = amount;
  }

  /// 获取当前钱龄
  MoneyAge getCurrentMoneyAge() {
    return MoneyAge.fromDays(_currentMoneyAgeDays);
  }

  /// 分析预算分配对钱龄的预期影响
  Future<MoneyAgeImpactPrediction> predictAllocationImpact(
    List<AllocationSuggestion> allocations,
  ) async {
    final currentAge = _currentMoneyAgeDays;

    // 储蓄类小金库分配会提高钱龄
    double savingsImpact = 0;
    double flexibleImpact = 0;

    for (final alloc in allocations) {
      final vault = await _vaultRepo.getById(alloc.vaultId);
      if (vault == null) continue;

      if (vault.type == VaultType.savings) {
        // 储蓄相当于延迟消费，会提高钱龄
        // 每储蓄一天的消费额，钱龄增加约1天
        savingsImpact += alloc.suggestedAmount / _dailySpending;
      } else if (vault.type == VaultType.flexible) {
        // 弹性支出增加可能导致更多消费
        flexibleImpact -= alloc.suggestedAmount / _dailySpending * 0.3;
      }
    }

    final totalImpact = savingsImpact + flexibleImpact;
    final projectedAge = (currentAge + totalImpact).round();

    ImpactType impactType;
    String recommendation;

    if (totalImpact > 1) {
      impactType = ImpactType.positive;
      recommendation = '本次分配将提升钱龄约${totalImpact.round()}天';
    } else if (totalImpact < -1) {
      impactType = ImpactType.negative;
      recommendation = '本次分配可能降低钱龄约${(-totalImpact).round()}天，建议增加储蓄比例';
    } else {
      impactType = ImpactType.neutral;
      recommendation = '本次分配对钱龄无显著影响';
    }

    return MoneyAgeImpactPrediction(
      currentAge: currentAge,
      projectedAge: projectedAge,
      change: totalImpact.round(),
      recommendation: recommendation,
      impactType: impactType,
    );
  }

  /// 根据钱龄状态调整预算建议
  Future<BudgetAdjustmentSuggestion> suggestBudgetAdjustment() async {
    final moneyAge = getCurrentMoneyAge();

    if (moneyAge.level == MoneyAgeLevel.danger) {
      // 钱龄危险：建议增加储蓄预算比例
      return BudgetAdjustmentSuggestion(
        adjustmentType: AdjustmentType.increaseSavings,
        targetPercentage: 0.25, // 建议储蓄25%
        reason: '当前钱龄${moneyAge.days}天，建议提高储蓄比例以建立财务缓冲',
        vaultAdjustments: await _getSavingsAdjustments(0.25),
      );
    }

    if (moneyAge.level == MoneyAgeLevel.warning) {
      // 钱龄警告：建议适度增加储蓄
      return BudgetAdjustmentSuggestion(
        adjustmentType: AdjustmentType.increaseSavings,
        targetPercentage: 0.20,
        reason: '当前钱龄${moneyAge.days}天，建议适当增加储蓄比例',
        vaultAdjustments: await _getSavingsAdjustments(0.20),
      );
    }

    if (moneyAge.level == MoneyAgeLevel.normal) {
      // 钱龄正常：保持或小幅增加
      return BudgetAdjustmentSuggestion(
        adjustmentType: AdjustmentType.noChange,
        targetPercentage: 0.15,
        reason: '当前钱龄${moneyAge.days}天，预算配置合理，可保持或适当增加储蓄',
      );
    }

    // 钱龄良好以上：无需调整
    return BudgetAdjustmentSuggestion.noChange();
  }

  /// 获取储蓄调整建议
  Future<List<VaultAdjustment>> _getSavingsAdjustments(
    double targetSavingsRate,
  ) async {
    final vaults = await _vaultRepo.getEnabled();
    final adjustments = <VaultAdjustment>[];

    // 计算当前总分配
    final totalAllocated =
        vaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);

    // 找出储蓄类小金库
    final savingsVaults = vaults.where((v) => v.type == VaultType.savings);

    // 当前储蓄占比
    final currentSavings =
        savingsVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    final currentSavingsRate =
        totalAllocated > 0 ? currentSavings / totalAllocated : 0;

    if (currentSavingsRate < targetSavingsRate && savingsVaults.isNotEmpty) {
      // 需要增加储蓄
      final additionalSavings =
          totalAllocated * (targetSavingsRate - currentSavingsRate);
      final perVaultIncrease = additionalSavings / savingsVaults.length;

      for (final vault in savingsVaults) {
        adjustments.add(VaultAdjustment(
          vaultId: vault.id,
          vaultName: vault.name,
          currentAmount: vault.allocatedAmount,
          suggestedAmount: vault.allocatedAmount + perVaultIncrease,
          reason: '建议增加储蓄以提升钱龄',
        ));
      }

      // 从弹性支出中减少
      final flexibleVaults = vaults.where((v) => v.type == VaultType.flexible);
      if (flexibleVaults.isNotEmpty) {
        final perVaultDecrease = additionalSavings / flexibleVaults.length;

        for (final vault in flexibleVaults) {
          final newAmount = (vault.allocatedAmount - perVaultDecrease)
              .clamp(vault.spentAmount, vault.allocatedAmount);

          if (newAmount < vault.allocatedAmount) {
            adjustments.add(VaultAdjustment(
              vaultId: vault.id,
              vaultName: vault.name,
              currentAmount: vault.allocatedAmount,
              suggestedAmount: newAmount,
              reason: '建议适当减少弹性支出',
            ));
          }
        }
      }
    }

    return adjustments;
  }

  /// 计算消费对钱龄的影响
  MoneyAgeImpactPrediction predictExpenseImpact(double expenseAmount) {
    final currentAge = _currentMoneyAgeDays;

    // 消费会降低钱龄
    // 假设每消费一天的平均消费额，钱龄降低约0.5天
    final impact = -(expenseAmount / _dailySpending * 0.5);
    final projectedAge = (currentAge + impact).round().clamp(0, 365);

    String recommendation;
    ImpactType impactType;

    if (impact < -3) {
      impactType = ImpactType.negative;
      recommendation = '这笔消费较大，将显著降低钱龄';
    } else if (impact < -1) {
      impactType = ImpactType.negative;
      recommendation = '这笔消费会略微降低钱龄';
    } else {
      impactType = ImpactType.neutral;
      recommendation = '对钱龄影响较小';
    }

    return MoneyAgeImpactPrediction(
      currentAge: currentAge,
      projectedAge: projectedAge,
      change: impact.round(),
      recommendation: recommendation,
      impactType: impactType,
    );
  }

  /// 获取钱龄优化建议
  Future<List<String>> getOptimizationTips() async {
    final tips = <String>[];
    final moneyAge = getCurrentMoneyAge();
    final vaults = await _vaultRepo.getEnabled();

    // 根据钱龄等级给出建议
    switch (moneyAge.level) {
      case MoneyAgeLevel.danger:
        tips.add('紧急：钱龄处于危险水平，建议立即增加储蓄');
        tips.add('考虑减少非必要支出');
        tips.add('检查是否有大额固定支出可以优化');
        break;
      case MoneyAgeLevel.warning:
        tips.add('警告：钱龄较低，建议关注支出结构');
        tips.add('尝试建立应急基金');
        break;
      case MoneyAgeLevel.normal:
        tips.add('钱龄正常，保持当前储蓄习惯');
        tips.add('可以考虑逐步增加储蓄比例');
        break;
      case MoneyAgeLevel.good:
      case MoneyAgeLevel.excellent:
      case MoneyAgeLevel.ideal:
        tips.add('钱龄健康，继续保持');
        tips.add('可以考虑长期投资');
        break;
    }

    // 检查小金库状态
    final overspentVaults = vaults.where((v) => v.isOverSpent);
    if (overspentVaults.isNotEmpty) {
      tips.add('有${overspentVaults.length}个小金库超支，建议及时调整');
    }

    return tips;
  }
}
