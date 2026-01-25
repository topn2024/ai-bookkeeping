import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_vault.dart';
import '../models/transaction.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../services/allocation_service.dart';
import '../services/category_localization_service.dart';
import 'transaction_provider.dart';

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
  late final IDatabaseService _db;
  late final AllocationService _allocationService;

  String _currentLedgerId = 'default';

  @override
  BudgetVaultState build() {
    // 通过服务定位器获取数据库服务
    _db = sl<IDatabaseService>();
    _allocationService = AllocationService();

    // 初始加载（带错误处理）
    Future.microtask(() => refresh().catchError((e) {
      state = state.copyWith(
        isLoading: false,
        error: '初始化失败: $e',
      );
    }));

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

      // 使用transaction provider的收入数据，确保与UI显示一致
      final totalIncome = ref.read(monthlyIncomeProvider);

      // 计算待分配金额
      final unallocated = _allocationService.calculateUnallocatedAmount(
        totalIncome: totalIncome,
        vaults: vaults,
      );

      // 自动同步小金库支出（从交易记录计算）
      final updatedVaults = await _syncVaultSpending(vaults);

      state = state.copyWith(
        vaults: updatedVaults,
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

  /// 从交易记录同步小金库的支出金额
  Future<List<BudgetVault>> _syncVaultSpending(List<BudgetVault> vaults) async {
    try {
      // 获取本月的所有支出交易
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final transactions = await _db.queryTransactions(
        startDate: startOfMonth,
        endDate: endOfMonth,
        limit: 100000, // 设置足够大的limit以获取所有交易
      );

      // 按分类统计支出
      final spendingByCategory = <String, double>{};

      for (final tx in transactions) {
        // 跳过收入和转账
        if (tx.type == TransactionType.income ||
            tx.category.contains('转账') ||
            tx.category == 'transfer') {
          continue;
        }

        if (tx.type == TransactionType.expense) {
          // 将分类ID转换成中文显示名称
          final categoryName = CategoryLocalizationService.instance.getCategoryName(tx.category);
          spendingByCategory[categoryName] = (spendingByCategory[categoryName] ?? 0) + tx.amount;
        }
      }

      // 更新每个小金库的spentAmount
      final updatedVaults = <BudgetVault>[];
      for (final vault in vaults) {
        // 根据小金库名称匹配分类支出
        double totalSpent = 0;
        final matchedCategories = <String>[];

        // 1. 完全匹配
        if (spendingByCategory.containsKey(vault.name)) {
          totalSpent = spendingByCategory[vault.name]!;
          matchedCategories.add(vault.name);
        }

        // 2. 模糊匹配：根据语义关联匹配相关分类
        for (final entry in spendingByCategory.entries) {
          final category = entry.key;
          final amount = entry.value;

          // 已经完全匹配过的跳过
          if (matchedCategories.contains(category)) continue;

          // 餐饮类：匹配"餐饮"、"外卖"、"饮品"、"食品"等
          if (vault.name == '餐饮' &&
              (category.contains('餐') || category.contains('饮') ||
               category.contains('外卖') || category.contains('食品') ||
               category.contains('早餐') || category.contains('午餐') || category.contains('晚餐'))) {
            totalSpent += amount;
            matchedCategories.add(category);
          }
          // 交通类：匹配"交通"、"打车"、"公交"、"地铁"、"停车"等
          else if (vault.name == '交通' &&
                   (category.contains('交通') || category.contains('打车') ||
                    category.contains('公交') || category.contains('地铁') ||
                    category.contains('停车') || category.contains('出行'))) {
            totalSpent += amount;
            matchedCategories.add(category);
          }
          // 购物类：匹配"购物"、"网购"、"数码"等
          else if (vault.name == '购物' &&
                   (category.contains('购物') || category.contains('数码') ||
                    category.contains('服饰') || category.contains('日用'))) {
            totalSpent += amount;
            matchedCategories.add(category);
          }
          // 娱乐类：匹配"娱乐"、"电影"、"游戏"、"订阅"、"会员"等
          else if (vault.name == '娱乐' &&
                   (category.contains('娱乐') || category.contains('电影') ||
                    category.contains('游戏') || category.contains('订阅') ||
                    category.contains('会员') || category.contains('视频'))) {
            totalSpent += amount;
            matchedCategories.add(category);
          }
          // 通用匹配：分类名包含小金库名，或小金库名包含分类名
          else if (category.contains(vault.name) || vault.name.contains(category)) {
            totalSpent += amount;
            matchedCategories.add(category);
          }
        }

        if (totalSpent != vault.spentAmount) {
          // 更新数据库
          final updatedVault = vault.copyWith(spentAmount: totalSpent);
          await _db.updateBudgetVault(updatedVault);
          updatedVaults.add(updatedVault);
        } else {
          updatedVaults.add(vault);
        }
      }

      return updatedVaults;
    } catch (e) {
      // 同步失败时返回原始数据，不影响其他功能
      return vaults;
    }
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

/// 应急基金 Provider - 查找名为"应急基金"或"应急金"的储蓄小金库
final emergencyFundVaultProvider = Provider<BudgetVault?>((ref) {
  final vaults = ref.watch(budgetVaultProvider).vaults;
  try {
    return vaults.firstWhere(
      (v) => v.isEnabled && v.type == VaultType.savings &&
             (v.name.contains('应急') || v.name.toLowerCase().contains('emergency')),
    );
  } catch (_) {
    return null;
  }
});
