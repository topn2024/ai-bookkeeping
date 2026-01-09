import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_vault.dart';
import '../services/database_service.dart';
import '../services/allocation_service.dart';

/// 小金库状态
class BudgetVaultState {
  final List<BudgetVault> vaults;
  final bool isLoading;
  final String? error;
  final double unallocatedAmount;
  final VaultSummary? summary;
  final DateTime? lastUpdated;

  const BudgetVaultState({
    this.vaults = const [],
    this.isLoading = false,
    this.error,
    this.unallocatedAmount = 0,
    this.summary,
    this.lastUpdated,
  });

  BudgetVaultState copyWith({
    List<BudgetVault>? vaults,
    bool? isLoading,
    String? error,
    double? unallocatedAmount,
    VaultSummary? summary,
    DateTime? lastUpdated,
  }) {
    return BudgetVaultState(
      vaults: vaults ?? this.vaults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unallocatedAmount: unallocatedAmount ?? this.unallocatedAmount,
      summary: summary ?? this.summary,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// 按类型筛选
  List<BudgetVault> getByType(VaultType type) {
    return vaults.where((v) => v.type == type && v.isEnabled).toList();
  }

  /// 获取超支的小金库
  List<BudgetVault> get overspentVaults {
    return vaults.where((v) => v.isEnabled && v.isOverSpent).toList();
  }

  /// 获取即将用完的小金库
  List<BudgetVault> get almostEmptyVaults {
    return vaults.where((v) => v.isEnabled && v.isAlmostEmpty).toList();
  }

  /// 获取健康的小金库
  List<BudgetVault> get healthyVaults {
    return vaults.where((v) => v.isEnabled && v.status == VaultStatus.healthy).toList();
  }

  /// 是否有待分配金额
  bool get hasUnallocated => unallocatedAmount > 0.01;

  /// 总可用金额
  double get totalAvailable {
    return vaults
        .where((v) => v.isEnabled)
        .fold(0.0, (sum, v) => sum + v.available);
  }

  /// 总已分配金额
  double get totalAllocated {
    return vaults
        .where((v) => v.isEnabled)
        .fold(0.0, (sum, v) => sum + v.allocatedAmount);
  }

  /// 总已花费金额
  double get totalSpent {
    return vaults
        .where((v) => v.isEnabled)
        .fold(0.0, (sum, v) => sum + v.spentAmount);
  }
}

/// 小金库状态管理 Provider
class BudgetVaultNotifier extends Notifier<BudgetVaultState> {
  late final DatabaseService _db;
  late final AllocationService _allocationService;

  String _currentLedgerId = 'default';

  @override
  BudgetVaultState build() {
    _db = DatabaseService();
    _allocationService = AllocationService();

    // 初始加载
    Future.microtask(() => refresh());

    return const BudgetVaultState(isLoading: true);
  }

  /// 设置当前账本
  void setLedger(String ledgerId) {
    _currentLedgerId = ledgerId;
    refresh();
  }

  /// 刷新小金库列表
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final vaults = await _db.getBudgetVaults(ledgerId: _currentLedgerId);

      // 计算待分配金额（需要获取总收入）
      final unallocated = _allocationService.calculateUnallocatedAmount(
        totalIncome: await _getTotalIncome(),
        vaults: vaults,
      );

      state = state.copyWith(
        vaults: vaults,
        isLoading: false,
        unallocatedAmount: unallocated,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 获取总收入（当月）
  Future<double> _getTotalIncome() async {
    final now = DateTime.now();
    return await _db.getMonthlyIncomeTotal(
      year: now.year,
      month: now.month,
      ledgerId: _currentLedgerId,
    );
  }

  /// 创建小金库
  Future<void> createVault(BudgetVault vault) async {
    try {
      await _db.insertBudgetVault(vault);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 更新小金库
  Future<void> updateVault(BudgetVault vault) async {
    try {
      await _db.updateBudgetVault(vault);

      // 乐观更新
      final updatedVaults = state.vaults.map((v) {
        return v.id == vault.id ? vault : v;
      }).toList();

      state = state.copyWith(
        vaults: updatedVaults,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      await refresh();
    }
  }

  /// 删除小金库
  Future<void> deleteVault(String vaultId) async {
    try {
      await _db.deleteBudgetVault(vaultId);

      // 乐观更新
      final updatedVaults = state.vaults.where((v) => v.id != vaultId).toList();
      state = state.copyWith(
        vaults: updatedVaults,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      await refresh();
    }
  }

  /// 分配资金到小金库
  Future<void> allocateToVault(String vaultId, double amount) async {
    if (amount <= 0) return;

    try {
      // 记录分配
      final allocation = VaultAllocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        vaultId: vaultId,
        amount: amount,
        allocatedAt: DateTime.now(),
      );
      await _db.insertVaultAllocation(allocation);

      // 更新小金库金额
      await _db.updateVaultAllocatedAmount(vaultId, amount);

      // 刷新状态
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 一键智能分配
  Future<AllocationResult> autoAllocate() async {
    final result = _allocationService.autoAllocate(
      unallocatedAmount: state.unallocatedAmount,
      vaults: state.vaults,
    );

    if (result.isSuccess || result.status == AllocationResultStatus.partial) {
      // 执行分配
      for (final allocation in result.allocations) {
        await allocateToVault(allocation.vaultId, allocation.amount);
      }
    }

    return result;
  }

  /// 获取分配建议
  List<AllocationSuggestion> getSuggestions() {
    return _allocationService.getSuggestions(
      unallocatedAmount: state.unallocatedAmount,
      vaults: state.vaults,
    );
  }

  /// 预览分配结果
  AllocationPreview previewAllocation(double amount) {
    return _allocationService.previewAllocation(
      incomeAmount: amount,
      vaults: state.vaults,
    );
  }

  /// 小金库间调拨
  Future<void> transferBetweenVaults({
    required String fromVaultId,
    required String toVaultId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) return;

    try {
      final transfer = VaultTransfer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fromVaultId: fromVaultId,
        toVaultId: toVaultId,
        amount: amount,
        note: note,
        transferredAt: DateTime.now(),
      );

      await _db.insertVaultTransfer(transfer);

      // 更新金额
      await _db.updateVaultAllocatedAmount(fromVaultId, -amount);
      await _db.updateVaultAllocatedAmount(toVaultId, amount);

      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 记录支出（从小金库扣减）
  Future<void> recordExpense(String vaultId, double amount) async {
    if (amount <= 0) return;

    try {
      await _db.updateVaultSpentAmount(vaultId, amount);

      // 乐观更新
      final updatedVaults = state.vaults.map((v) {
        if (v.id == vaultId) {
          return v.copyWith(
            spentAmount: v.spentAmount + amount,
            updatedAt: DateTime.now(),
          );
        }
        return v;
      }).toList();

      state = state.copyWith(
        vaults: updatedVaults,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      await refresh();
    }
  }

  /// 撤销支出（恢复小金库金额）
  Future<void> revertExpense(String vaultId, double amount) async {
    if (amount <= 0) return;

    try {
      await _db.updateVaultSpentAmount(vaultId, -amount);

      // 乐观更新
      final updatedVaults = state.vaults.map((v) {
        if (v.id == vaultId) {
          return v.copyWith(
            spentAmount: v.spentAmount - amount,
            updatedAt: DateTime.now(),
          );
        }
        return v;
      }).toList();

      state = state.copyWith(
        vaults: updatedVaults,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      await refresh();
    }
  }

  /// 根据分类获取关联的小金库
  Future<BudgetVault?> getVaultByCategory(String categoryId) async {
    return await _db.getBudgetVaultByCategory(categoryId);
  }

  /// 从模板批量创建小金库
  Future<void> createFromTemplates(List<Map<String, dynamic>> templates) async {
    try {
      for (final template in templates) {
        final vault = BudgetVault(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: template['name'] as String,
          description: template['description'] as String?,
          icon: template['icon'],
          color: template['color'],
          type: template['type'] as VaultType,
          targetAmount: template['targetAmount'] as double? ?? 0,
          ledgerId: _currentLedgerId,
        );
        await _db.insertBudgetVault(vault);
      }
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 重置月度数据（周期结转）
  Future<void> resetMonthlyData({bool carryOverSavings = true}) async {
    try {
      for (final vault in state.vaults) {
        if (vault.type == VaultType.savings && carryOverSavings) {
          // 储蓄类小金库：保留余额，只重置花费
          await _db.updateBudgetVault(vault.copyWith(
            spentAmount: 0,
            updatedAt: DateTime.now(),
          ));
        } else {
          // 其他类型：重置分配和花费
          await _db.updateBudgetVault(vault.copyWith(
            allocatedAmount: 0,
            spentAmount: 0,
            updatedAt: DateTime.now(),
          ));
        }
      }
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 验证分配配置
  List<String> validateConfig() {
    return _allocationService.validateAllocationConfig(state.vaults);
  }

  /// 计算满足所有目标所需的收入
  double calculateRequiredIncome() {
    return _allocationService.calculateRequiredIncome(state.vaults);
  }
}

/// 小金库 Provider
final budgetVaultProvider =
    NotifierProvider<BudgetVaultNotifier, BudgetVaultState>(
  BudgetVaultNotifier.new,
);

/// 待分配金额 Provider
final unallocatedAmountProvider = Provider<double>((ref) {
  return ref.watch(budgetVaultProvider).unallocatedAmount;
});

/// 超支小金库 Provider
final overspentVaultsProvider = Provider<List<BudgetVault>>((ref) {
  return ref.watch(budgetVaultProvider).overspentVaults;
});

/// 分配建议 Provider
final allocationSuggestionsProvider = Provider<List<AllocationSuggestion>>((ref) {
  final notifier = ref.watch(budgetVaultProvider.notifier);
  return notifier.getSuggestions();
});

/// 按类型筛选的小金库 Provider
final vaultsByTypeProvider = Provider.family<List<BudgetVault>, VaultType>((ref, type) {
  return ref.watch(budgetVaultProvider).getByType(type);
});

/// 单个小金库 Provider
final singleVaultProvider = Provider.family<BudgetVault?, String>((ref, vaultId) {
  final vaults = ref.watch(budgetVaultProvider).vaults;
  try {
    return vaults.firstWhere((v) => v.id == vaultId);
  } catch (_) {
    return null;
  }
});

/// 小金库统计摘要 Provider
final vaultSummaryProvider = Provider<VaultSummary?>((ref) {
  return ref.watch(budgetVaultProvider).summary;
});
