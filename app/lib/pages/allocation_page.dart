import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_vault.dart';
import '../services/allocation_service.dart';
import '../providers/budget_vault_provider.dart';

/// 资金分配页面
class AllocationPage extends ConsumerStatefulWidget {
  final double? initialAmount;

  const AllocationPage({
    super.key,
    this.initialAmount,
  });

  @override
  ConsumerState<AllocationPage> createState() => _AllocationPageState();
}

class _AllocationPageState extends ConsumerState<AllocationPage> {
  final AllocationService _allocationService = AllocationService();

  List<AllocationSuggestion> _suggestions = [];
  Map<String, double> _allocations = {};
  AllocationStrategy _selectedStrategy = AllocationStrategy.priority;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSuggestions();
    });
  }

  double get _unallocatedAmount {
    if (widget.initialAmount != null) {
      return widget.initialAmount!;
    }
    return ref.read(budgetVaultProvider).unallocatedAmount;
  }

  List<BudgetVault> get _vaults {
    return ref.read(budgetVaultProvider).vaults.where((v) => v.isEnabled).toList();
  }

  void _updateSuggestions() {
    final vaults = _vaults;
    if (vaults.isEmpty) return;

    setState(() {
      _suggestions = _allocationService.getSuggestions(
        unallocatedAmount: _unallocatedAmount,
        vaults: vaults,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider to rebuild when data changes
    final vaultState = ref.watch(budgetVaultProvider);
    final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();
    final unallocatedAmount = widget.initialAmount ?? vaultState.unallocatedAmount;

    if (vaults.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('分配资金')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('暂无小金库', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text('请先创建小金库再进行分配', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('分配资金'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showStrategySelector(context),
            tooltip: '分配策略',
          ),
        ],
      ),
      body: Column(
        children: [
          // 待分配金额卡片
          _UnallocatedAmountCard(
            amount: unallocatedAmount,
            allocated: _allocations.values.fold(0.0, (a, b) => a + b),
          ),

          // 策略选择
          _StrategySelector(
            selected: _selectedStrategy,
            onChanged: (strategy) {
              setState(() {
                _selectedStrategy = strategy;
                _previewAllocation();
              });
            },
          ),

          // 分配建议列表
          Expanded(
            child: _suggestions.isEmpty
                ? Center(
                    child: Text('暂无分配建议', style: TextStyle(color: Colors.grey[600])),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      final vault = vaults.where((v) => v.id == suggestion.vaultId).firstOrNull;
                      if (vault == null) return const SizedBox.shrink();
                      return _SuggestionTile(
                        suggestion: suggestion,
                        vault: vault,
                        currentAllocation: _allocations[suggestion.vaultId] ?? 0,
                        onAllocationChanged: (amount) {
                          setState(() {
                            _allocations[suggestion.vaultId] = amount;
                          });
                        },
                        maxAllocation: _getRemainingForVault(suggestion.vaultId),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomSheet: _AllocationActionBar(
        totalAllocated: _allocations.values.fold(0.0, (a, b) => a + b),
        unallocatedAmount: unallocatedAmount,
        onAutoAllocate: _autoAllocate,
        onConfirm: _confirmAllocation,
        onSkip: () => Navigator.pop(context),
      ),
    );
  }

  double _getRemainingForVault(String vaultId) {
    final totalAllocated = _allocations.entries
        .where((e) => e.key != vaultId)
        .fold(0.0, (sum, e) => sum + e.value);
    return _unallocatedAmount - totalAllocated;
  }

  void _previewAllocation() {
    final vaults = _vaults;
    if (vaults.isEmpty) return;

    final preview = _allocationService.previewAllocation(
      incomeAmount: _unallocatedAmount,
      vaults: vaults,
      strategy: _selectedStrategy,
    );

    setState(() {
      _allocations = {};
      for (final allocation in preview.allocations) {
        _allocations[allocation.vaultId] = allocation.amount;
      }
    });
  }

  void _autoAllocate() {
    final vaults = _vaults;
    if (vaults.isEmpty) return;

    final result = _allocationService.autoAllocate(
      unallocatedAmount: _unallocatedAmount,
      vaults: vaults,
    );

    setState(() {
      _allocations = {};
      for (final allocation in result.allocations) {
        _allocations[allocation.vaultId] = allocation.amount;
      }
    });

    if (result.hasUnallocated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('有 ¥${result.unallocatedAmount.toStringAsFixed(2)} 未分配'),
          action: SnackBarAction(
            label: '查看',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _confirmAllocation() {
    if (_allocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置分配金额')),
      );
      return;
    }

    final vaults = _vaults;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认分配'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即将分配 ¥${_allocations.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            ..._allocations.entries.map((e) {
              final vault = vaults.where((v) => v.id == e.key).firstOrNull;
              return Text('• ${vault?.name ?? "未知"}: ¥${e.value.toStringAsFixed(2)}');
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, _allocations);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分配成功')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showStrategySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择分配策略',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...AllocationStrategy.values.map((strategy) {
              return RadioListTile<AllocationStrategy>(
                title: Text(_getStrategyName(strategy)),
                subtitle: Text(_getStrategyDescription(strategy)),
                value: strategy,
                groupValue: _selectedStrategy,
                onChanged: (value) {
                  setState(() {
                    _selectedStrategy = value!;
                    _previewAllocation();
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getStrategyName(AllocationStrategy strategy) {
    switch (strategy) {
      case AllocationStrategy.priority:
        return '按优先级';
      case AllocationStrategy.proportional:
        return '按比例';
      case AllocationStrategy.hybridPriorityProportional:
        return '混合策略';
    }
  }

  String _getStrategyDescription(AllocationStrategy strategy) {
    switch (strategy) {
      case AllocationStrategy.priority:
        return '固定支出 > 债务 > 储蓄 > 弹性';
      case AllocationStrategy.proportional:
        return '所有小金库按配置比例分配';
      case AllocationStrategy.hybridPriorityProportional:
        return '先满足固定支出，剩余按比例分配';
    }
  }
}

/// 待分配金额卡片
class _UnallocatedAmountCard extends StatelessWidget {
  final double amount;
  final double allocated;

  const _UnallocatedAmountCard({
    required this.amount,
    required this.allocated,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = amount - allocated;
    final progress = amount > 0 ? allocated / amount : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[400]!, Colors.indigo[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '待分配',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '¥${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '剩余',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '¥${remaining.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: remaining > 0 ? Colors.yellowAccent : Colors.greenAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已分配 ${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 策略选择器
class _StrategySelector extends StatelessWidget {
  final AllocationStrategy selected;
  final ValueChanged<AllocationStrategy> onChanged;

  const _StrategySelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: AllocationStrategy.values.map((strategy) {
          final isSelected = strategy == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getShortName(strategy)),
              selected: isSelected,
              onSelected: (_) => onChanged(strategy),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getShortName(AllocationStrategy strategy) {
    switch (strategy) {
      case AllocationStrategy.priority:
        return '按优先级';
      case AllocationStrategy.proportional:
        return '按比例';
      case AllocationStrategy.hybridPriorityProportional:
        return '混合';
    }
  }
}

/// 分配建议项
class _SuggestionTile extends StatelessWidget {
  final AllocationSuggestion suggestion;
  final BudgetVault vault;
  final double currentAllocation;
  final ValueChanged<double> onAllocationChanged;
  final double maxAllocation;

  const _SuggestionTile({
    required this.suggestion,
    required this.vault,
    required this.currentAllocation,
    required this.onAllocationChanged,
    required this.maxAllocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: vault.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(vault.icon, color: vault.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            vault.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PriorityBadge(priority: suggestion.priority),
                        ],
                      ),
                      Text(
                        suggestion.reason,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 当前状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusItem(
                  label: '已分配',
                  value: '¥${vault.allocatedAmount.toStringAsFixed(0)}',
                ),
                _StatusItem(
                  label: '目标',
                  value: '¥${vault.targetAmount.toStringAsFixed(0)}',
                ),
                _StatusItem(
                  label: '差额',
                  value: '¥${(suggestion.shortfall ?? 0).toStringAsFixed(0)}',
                  color: Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 分配金额输入
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本次分配',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${currentAllocation.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // 快捷按钮
                Row(
                  children: [
                    _QuickButton(
                      label: '建议',
                      onTap: () => onAllocationChanged(
                        suggestion.suggestedAmount.clamp(0, maxAllocation),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _QuickButton(
                      label: '补齐',
                      onTap: () {
                        final shortfall = suggestion.shortfall ?? 0;
                        onAllocationChanged(shortfall.clamp(0, maxAllocation));
                      },
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 滑块
            Slider(
              value: currentAllocation.clamp(0, maxAllocation),
              min: 0,
              max: maxAllocation > 0 ? maxAllocation : 1,
              onChanged: (value) => onAllocationChanged(value),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final int priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case 1:
        color = Colors.red;
        break;
      case 2:
        color = Colors.orange;
        break;
      case 3:
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'P$priority',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatusItem({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

/// 底部操作栏
class _AllocationActionBar extends StatelessWidget {
  final double totalAllocated;
  final double unallocatedAmount;
  final VoidCallback onAutoAllocate;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;

  const _AllocationActionBar({
    required this.totalAllocated,
    required this.unallocatedAmount,
    required this.onAutoAllocate,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAutoAllocate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('智能分配'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: totalAllocated > 0 ? onConfirm : null,
                child: Text(
                  '确认分配 ¥${totalAllocated.toStringAsFixed(0)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
