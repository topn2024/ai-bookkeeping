import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_vault_provider.dart';
import '../models/transaction.dart';
import '../models/budget_vault.dart';
import 'smart_allocation_page.dart';

/// 零基预算分配页面
///
/// 对应原型设计 3.09 零基预算分配
/// 展示零基预算原则：收入 - 支出 - 储蓄 = 0
class ZeroBasedBudgetPage extends ConsumerStatefulWidget {
  const ZeroBasedBudgetPage({
    super.key,
  });

  @override
  ConsumerState<ZeroBasedBudgetPage> createState() => _ZeroBasedBudgetPageState();
}

class _ZeroBasedBudgetPageState extends ConsumerState<ZeroBasedBudgetPage> {
  // 用于存储每个小金库的分配金额
  final Map<String, double> _vaultAllocations = {};

  @override
  void initState() {
    super.initState();
    // 延迟加载，等待 Provider 初始化完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingAllocations();
    });
  }

  /// 从现有小金库中加载已分配的金额
  void _loadExistingAllocations() {
    final vaultState = ref.read(budgetVaultProvider);
    setState(() {
      _vaultAllocations.clear();
      for (final vault in vaultState.vaults.where((v) => v.isEnabled)) {
        // 优先使用 allocatedAmount，如果为0则使用 targetAmount
        final amount = vault.allocatedAmount > 0
            ? vault.allocatedAmount
            : vault.targetAmount;
        if (amount > 0) {
          _vaultAllocations[vault.id] = amount;
        }
      }
    });
    print('🔍 [零基预算] 已加载现有分配: ${_vaultAllocations.length} 个小金库');
  }

  /// 计算本月实际收入
  double _calculateMonthlyIncome() {
    final transactions = ref.read(transactionProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(monthEnd.add(const Duration(days: 1))))
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  double get _totalAllocated =>
      _vaultAllocations.values.fold(0.0, (sum, amount) => sum + amount);

  double get _remaining => _calculateMonthlyIncome() - _totalAllocated;

  bool get _isBalanced => _remaining.abs() < 0.01;

  /// 创建默认小金库
  Future<void> _createDefaultVaults() async {
    final vaultNotifier = ref.read(budgetVaultProvider.notifier);
    final ledgerId = 'default';

    final defaultVaults = [
      BudgetVault(
        id: 'vault_savings_${DateTime.now().millisecondsSinceEpoch}',
        name: '储蓄优先',
        description: '先存后花，养成储蓄习惯',
        icon: Icons.savings,
        color: Colors.green,
        type: VaultType.savings,
        targetAmount: 0,
        allocatedAmount: 0,
        spentAmount: 0,
        ledgerId: ledgerId,
        isEnabled: true,
        allocationType: AllocationType.fixed,
        targetAllocation: 0,
        targetPercentage: 0.20,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      BudgetVault(
        id: 'vault_fixed_${DateTime.now().millisecondsSinceEpoch + 1}',
        name: '固定支出',
        description: '房租、水电、通讯等',
        icon: Icons.home,
        color: Colors.blue,
        type: VaultType.fixed,
        targetAmount: 0,
        allocatedAmount: 0,
        spentAmount: 0,
        ledgerId: ledgerId,
        isEnabled: true,
        allocationType: AllocationType.fixed,
        targetAllocation: 0,
        targetPercentage: 0.33,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      BudgetVault(
        id: 'vault_living_${DateTime.now().millisecondsSinceEpoch + 2}',
        name: '生活消费',
        description: '餐饮、购物、交通',
        icon: Icons.restaurant,
        color: Colors.orange,
        type: VaultType.flexible,
        targetAmount: 0,
        allocatedAmount: 0,
        spentAmount: 0,
        ledgerId: ledgerId,
        isEnabled: true,
        allocationType: AllocationType.fixed,
        targetAllocation: 0,
        targetPercentage: 0.27,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      BudgetVault(
        id: 'vault_flexible_${DateTime.now().millisecondsSinceEpoch + 3}',
        name: '弹性支出',
        description: '娱乐、社交',
        icon: Icons.celebration,
        color: Colors.purple,
        type: VaultType.flexible,
        targetAmount: 0,
        allocatedAmount: 0,
        spentAmount: 0,
        ledgerId: ledgerId,
        isEnabled: true,
        allocationType: AllocationType.fixed,
        targetAllocation: 0,
        targetPercentage: 0.20,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final vault in defaultVaults) {
      await vaultNotifier.createVault(vault);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 已创建4个默认小金库')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthlyIncome = _calculateMonthlyIncome();
    final vaultState = ref.watch(budgetVaultProvider);

    // 调试信息
    print('🔍 [零基预算] 总小金库数: ${vaultState.vaults.length}');
    print('🔍 [零基预算] 已启用小金库数: ${vaultState.vaults.where((v) => v.isEnabled).length}');
    for (final vault in vaultState.vaults) {
      print('  - ${vault.name}: enabled=${vault.isEnabled}, target=${vault.targetAmount}, allocated=${vault.allocatedAmount}');
    }

    final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('零基预算分配'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clean') {
                _cleanDuplicateVaults();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clean',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20),
                    SizedBox(width: 8),
                    Text('清理重复小金库'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: vaults.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // 可分配收入 - 紧凑版
                      _CompactIncomeCard(totalIncome: monthlyIncome),

                      const SizedBox(height: 10),

                      // 智能分配按钮
                      OutlinedButton.icon(
                        onPressed: () => _navigateToSmartAllocation(monthlyIncome, vaults),
                        icon: const Icon(Icons.psychology, size: 16),
                        label: const Text('智能分配', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 小金库分配列表
                      _VaultAllocationList(
                        vaults: vaults,
                        allocations: _vaultAllocations,
                        onAmountChanged: (vaultId, amount) {
                          setState(() {
                            _vaultAllocations[vaultId] = amount;
                          });
                        },
                      ),

                      const SizedBox(height: 10),

                      // 零基预算结果 - 紧凑版
                      _CompactBalanceResult(
                        remaining: _remaining,
                        isBalanced: _isBalanced,
                      ),
                    ],
                  ),
                ),
                // 底部操作栏
                _BottomActionBar(
                  isBalanced: _isBalanced,
                  onConfirm: _confirmBudget,
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '还没有小金库',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              '零基预算需要先创建小金库',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createDefaultVaults,
              icon: const Icon(Icons.add),
              label: const Text('创建默认小金库'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 跳转到智能分配页面
  void _navigateToSmartAllocation(double income, List<BudgetVault> vaults) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SmartAllocationPage(
          incomeAmount: income,
          incomeSource: '本月收入',
        ),
      ),
    );

    // 如果智能分配返回了数据，应用到当前页面
    if (result != null && result is List<AllocationItem>) {
      try {
        final vaultNotifier = ref.read(budgetVaultProvider.notifier);
        final vaultState = ref.read(budgetVaultProvider);

        setState(() {
          _vaultAllocations.clear();
        });

        print('🔍 [智能分配应用] 开始处理 ${result.length} 个分类');

        // 收集智能分配中所有的分类名称
        final smartAllocationNames = result.map((item) => item.name).toSet();
        print('🔍 [智能分配应用] 智能分配的分类: ${smartAllocationNames.join(", ")}');

        // 1. 删除不在智能分配结果中的小金库
        final vaultsToDelete = vaultState.vaults.where((v) =>
          v.isEnabled && !smartAllocationNames.contains(v.name)
        ).toList();

        print('🔍 [智能分配应用] 准备删除 ${vaultsToDelete.length} 个多余的小金库');
        for (final vault in vaultsToDelete) {
          print('🔍 [智能分配应用] 删除多余小金库: ${vault.name}');
          await vaultNotifier.deleteVault(vault.id);
        }

        // 2. 为智能分配结果创建或更新小金库
        for (final item in result) {
          // 先尝试根据名称匹配现有小金库
          BudgetVault? matchingVault;
          try {
            matchingVault = vaultState.vaults.firstWhere((v) => v.name == item.name && v.isEnabled);
          } catch (e) {
            matchingVault = null;
          }

          if (matchingVault != null) {
            // 找到匹配的小金库，直接分配
            setState(() {
              _vaultAllocations[matchingVault!.id] = item.amount;
            });
            print('🔍 [智能分配应用] 匹配到现有小金库: ${item.name} -> ${matchingVault.id}');
          } else {
            // 没有找到匹配的小金库，自动创建
            print('🔍 [智能分配应用] 创建新小金库: ${item.name}');

            final newVault = BudgetVault(
              id: 'vault_${item.id}_${DateTime.now().millisecondsSinceEpoch}',
              name: item.name,
              description: item.reason,
              icon: item.icon,
              color: item.color,
              type: item.type == AllocationPriorityType.savings
                  ? VaultType.savings
                  : item.type == AllocationPriorityType.fixed
                      ? VaultType.fixed
                      : VaultType.flexible,
              targetAmount: item.amount,
              allocatedAmount: 0,
              spentAmount: 0,
              ledgerId: 'default',
              isEnabled: true,
              allocationType: AllocationType.fixed,
              targetAllocation: item.amount,
              targetPercentage: income > 0 ? item.amount / income : 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await vaultNotifier.createVault(newVault);

            setState(() {
              _vaultAllocations[newVault.id] = item.amount;
            });
            print('🔍 [智能分配应用] 新小金库创建成功: ${item.name} -> ${newVault.id}');
          }
        }

        // 调试信息
        final totalFromSmart = _vaultAllocations.values.fold(0.0, (sum, amount) => sum + amount);
        print('🔍 智能分配返回: 收入=$income, 分配总额=$totalFromSmart, 差额=${income - totalFromSmart}');
        print('🔍 小金库分配明细:');
        final currentVaults = ref.read(budgetVaultProvider).vaults;
        for (final entry in _vaultAllocations.entries) {
          try {
            final vault = currentVaults.firstWhere((v) => v.id == entry.key);
            print('  - ${vault.name}: ¥${entry.value}');
          } catch (e) {
            print('  - 未知小金库 ${entry.key}: ¥${entry.value}');
          }
        }

        // 智能分配完成提示已移除，避免遮挡底部按钮
      } catch (e, stack) {
        print('🔍 智能分配应用失败: $e');
        print('🔍 错误堆栈: $stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('应用智能分配失败: $e')),
          );
        }
      }
    }
  }

  void _confirmBudget() async {
    print('🔍 [确认预算] 开始执行');
    print('🔍 [确认预算] _isBalanced: $_isBalanced, _remaining: $_remaining');
    print('🔍 [确认预算] _vaultAllocations: ${_vaultAllocations.length} 个');

    if (!_isBalanced) {
      print('🔍 [确认预算] 未平衡，还有 $_remaining 未分配');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('还有 ¥${_remaining.toStringAsFixed(0)} 未分配'),
          action: SnackBarAction(
            label: '自动分配',
            onPressed: _autoAllocate,
          ),
        ),
      );
      return;
    }

    try {
      print('🔍 [确认预算] 开始更新小金库');
      final vaultNotifier = ref.read(budgetVaultProvider.notifier);
      final vaultState = ref.read(budgetVaultProvider);

      print('🔍 [确认预算] 当前小金库状态: ${vaultState.vaults.length} 个');

      // 更新每个小金库的目标金额和已分配金额
      for (final entry in _vaultAllocations.entries) {
        final vaultId = entry.key;
        final targetAmount = entry.value;

        print('🔍 [确认预算] 准备更新小金库: $vaultId, 金额: $targetAmount');

        final vault = vaultState.vaults.firstWhere((v) => v.id == vaultId);
        print('🔍 [确认预算] 找到小金库: ${vault.name}');

        final updatedVault = BudgetVault(
          id: vault.id,
          name: vault.name,
          description: vault.description,
          icon: vault.icon,
          color: vault.color,
          type: vault.type,
          targetAmount: targetAmount,  // 设置目标金额
          allocatedAmount: targetAmount,  // 实际分配资金到小金库
          spentAmount: vault.spentAmount,
          ledgerId: vault.ledgerId,
          isEnabled: vault.isEnabled,
          allocationType: vault.allocationType,
          targetAllocation: targetAmount,
          targetPercentage: _calculateMonthlyIncome() > 0
              ? targetAmount / _calculateMonthlyIncome()
              : 0,
          createdAt: vault.createdAt,
          updatedAt: DateTime.now(),
        );

        print('🔍 [确认预算] 调用 updateVault: ${vault.name}, target=$targetAmount, allocated=$targetAmount');
        await vaultNotifier.updateVault(updatedVault);
        print('🔍 [确认预算] 小金库更新完成: ${vault.name}');
      }

      print('🔍 [确认预算] 所有小金库更新完成');

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e, stack) {
      print('🔍 [确认预算] 发生错误: $e');
      print('🔍 [确认预算] 错误堆栈: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 更新小金库失败: $e')),
      );
    }
  }

  void _autoAllocate() {
    // 将剩余金额分配到第一个弹性支出小金库
    setState(() {
      final vaultState = ref.read(budgetVaultProvider);
      final flexibleVault = vaultState.vaults.firstWhere(
        (v) => v.type == VaultType.flexible && v.isEnabled,
        orElse: () => vaultState.vaults.first,
      );
      _vaultAllocations[flexibleVault.id] = (_vaultAllocations[flexibleVault.id] ?? 0) + _remaining;
    });
  }

  /// 清理重复的小金库
  Future<void> _cleanDuplicateVaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理重复小金库'),
        content: const Text('将删除重复的小金库，每个名称只保留最新的一个。\n\n建议操作前先备份数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final vaultNotifier = ref.read(budgetVaultProvider.notifier);
      final vaultState = ref.read(budgetVaultProvider);

      // 按名称分组
      final Map<String, List<BudgetVault>> vaultsByName = {};
      for (final vault in vaultState.vaults) {
        vaultsByName.putIfAbsent(vault.name, () => []).add(vault);
      }

      int deletedCount = 0;
      // 对每个分组，保留最新的，删除其他的
      for (final entry in vaultsByName.entries) {
        final vaults = entry.value;
        if (vaults.length > 1) {
          // 按更新时间排序，保留最新的
          vaults.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final toKeep = vaults.first;
          final toDelete = vaults.skip(1).toList();

          for (final vault in toDelete) {
            await vaultNotifier.deleteVault(vault.id);
            deletedCount++;
          }

          print('🔍 小金库"${entry.key}": 保留 ${toKeep.id}, 删除 ${toDelete.length} 个重复项');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 已清理 $deletedCount 个重复小金库')),
      );

      // 刷新页面
      setState(() {
        _vaultAllocations.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 清理失败: $e')),
      );
    }
  }
}

/// 紧凑版收入卡片
class _CompactIncomeCard extends StatelessWidget {
  final double totalIncome;

  const _CompactIncomeCard({required this.totalIncome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本月可分配',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '收入 - 支出 - 储蓄 = 0',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          Text(
            '¥${totalIncome.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 小金库分配列表
class _VaultAllocationList extends StatelessWidget {
  final List<BudgetVault> vaults;
  final Map<String, double> allocations;
  final Function(String vaultId, double amount) onAmountChanged;

  const _VaultAllocationList({
    required this.vaults,
    required this.allocations,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: vaults.asMap().entries.map((entry) {
          final index = entry.key;
          final vault = entry.value;
          final isLast = index == vaults.length - 1;
          return _VaultAllocationItem(
            key: ValueKey(vault.id),
            vault: vault,
            amount: allocations[vault.id] ?? 0,
            showDivider: !isLast,
            onAmountChanged: (amount) => onAmountChanged(vault.id, amount),
          );
        }).toList(),
      ),
    );
  }
}

/// 小金库分配项
class _VaultAllocationItem extends StatefulWidget {
  final BudgetVault vault;
  final double amount;
  final bool showDivider;
  final ValueChanged<double> onAmountChanged;

  const _VaultAllocationItem({
    super.key,
    required this.vault,
    required this.amount,
    required this.showDivider,
    required this.onAmountChanged,
  });

  @override
  State<_VaultAllocationItem> createState() => _VaultAllocationItemState();
}

class _VaultAllocationItemState extends State<_VaultAllocationItem> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.amount > 0 ? widget.amount.toStringAsFixed(0) : '',
    );
  }

  @override
  void didUpdateWidget(_VaultAllocationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当amount变化时，更新controller的文本
    if (oldWidget.amount != widget.amount) {
      _controller.text = widget.amount > 0
          ? widget.amount.toStringAsFixed(0)
          : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.vault.type == VaultType.savings;

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.green[50] : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.vault.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.vault.icon,
                    color: widget.vault.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                // 名称和描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vault.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.vault.description?.isNotEmpty ?? false)
                        Text(
                          widget.vault.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                // 金额输入
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '¥',
                      border: InputBorder.none,
                      hintText: '0',
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final amount = double.tryParse(value) ?? 0;
                      widget.onAmountChanged(amount);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (widget.showDivider)
            Divider(height: 1, color: Colors.grey[200]),
        ],
      ),
    );
  }
}

/// 紧凑版预算结果
class _CompactBalanceResult extends StatelessWidget {
  final double remaining;
  final bool isBalanced;

  const _CompactBalanceResult({
    required this.remaining,
    required this.isBalanced,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isBalanced ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBalanced ? Colors.green[200]! : Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isBalanced ? Icons.check_circle : Icons.pending_actions,
                color: isBalanced ? Colors.green[700] : Colors.orange[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isBalanced ? '完美平衡' : '待分配',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isBalanced ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ],
          ),
          Text(
            '¥${remaining.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isBalanced ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部操作栏
class _BottomActionBar extends StatelessWidget {
  final bool isBalanced;
  final VoidCallback onConfirm;

  const _BottomActionBar({
    required this.isBalanced,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: isBalanced ? null : Colors.orange,
          ),
          child: Text(isBalanced ? '确认预算方案' : '完成分配'),
        ),
      ),
    );
  }
}

