import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/budget_vault_provider.dart';
import '../models/budget_vault.dart';

/// 资金分配页面
/// 原型设计 3.03：资金分配
/// - 待分配金额展示
/// - 分配方案列表
/// - 已分配/剩余金额汇总
/// - 确认分配按钮
class VaultAllocationPage extends ConsumerStatefulWidget {
  final double amountToAllocate;
  final String source;

  const VaultAllocationPage({
    super.key,
    this.amountToAllocate = 3500,
    this.source = '本月工资收入',
  });

  @override
  ConsumerState<VaultAllocationPage> createState() =>
      _VaultAllocationPageState();
}

class _VaultAllocationPageState extends ConsumerState<VaultAllocationPage> {
  final List<_AllocationItem> _allocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllocationsFromVaults();
  }

  void _loadAllocationsFromVaults() {
    // 延迟加载，等待provider初始化
    Future.microtask(() {
      final vaultState = ref.read(budgetVaultProvider);
      final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();

      if (vaults.isEmpty) {
        // 没有小金库时显示空状态
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 根据实际小金库生成分配方案
      double remaining = widget.amountToAllocate;
      final allocations = <_AllocationItem>[];

      for (final vault in vaults) {
        if (remaining <= 0) break;

        // 计算建议分配金额
        double suggestedAmount;
        String strategy;

        if (vault.type == VaultType.savings && vault.targetAmount > 0) {
          // 储蓄类：补足到目标
          final needed = vault.targetAmount - vault.allocatedAmount;
          suggestedAmount = needed.clamp(0, remaining);
          strategy = '补足到 ¥${vault.targetAmount.toStringAsFixed(0)}';
        } else if (vault.type == VaultType.fixed) {
          // 固定支出：按比例分配
          suggestedAmount = (widget.amountToAllocate * 0.3).clamp(0, remaining);
          strategy = '固定支出';
        } else {
          // 其他：平均分配剩余
          suggestedAmount = remaining / (vaults.length - allocations.length);
          strategy = '剩余金额';
        }

        if (suggestedAmount > 0) {
          allocations.add(_AllocationItem(
            vaultId: vault.id,
            name: vault.name,
            icon: _getVaultIcon(vault.type),
            gradientColors: _getVaultColors(vault.type),
            strategy: strategy,
            amount: suggestedAmount,
            percent: (suggestedAmount / widget.amountToAllocate * 100),
          ));
          remaining -= suggestedAmount;
        }
      }

      setState(() {
        _allocations.clear();
        _allocations.addAll(allocations);
        _isLoading = false;
      });
    });
  }

  IconData _getVaultIcon(VaultType type) {
    switch (type) {
      case VaultType.savings:
        return Icons.savings;
      case VaultType.fixed:
        return Icons.home;
      case VaultType.flexible:
        return Icons.restaurant;
      case VaultType.debt:
        return Icons.credit_card;
    }
  }

  List<Color> _getVaultColors(VaultType type) {
    switch (type) {
      case VaultType.savings:
        return [const Color(0xFF4CAF50), const Color(0xFF81C784)];
      case VaultType.fixed:
        return [const Color(0xFFFF6B6B), const Color(0xFFFF8E8E)];
      case VaultType.flexible:
        return [const Color(0xFF2196F3), const Color(0xFF64B5F6)];
      case VaultType.debt:
        return [const Color(0xFFFF9800), const Color(0xFFFFB74D)];
    }
  }

  double get _totalAllocated =>
      _allocations.fold(0.0, (sum, a) => sum + a.amount);
  double get _remaining => widget.amountToAllocate - _totalAllocated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildAmountCard(context, theme),
                          _buildAllocationList(context, theme),
                          if (_allocations.isNotEmpty)
                            _buildSummaryCard(context, theme),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
            if (!_isLoading && _allocations.isNotEmpty)
              _buildConfirmButton(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.close),
            ),
          ),
          const Expanded(
            child: Text(
              '分配收入',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _saveAllocation,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                '保存',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 待分配金额卡片
  Widget _buildAmountCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '待分配金额',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${widget.amountToAllocate.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '来自${widget.source}',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  /// 分配方案列表
  Widget _buildAllocationList(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '分配方案',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (_allocations.isNotEmpty)
                Text(
                  '智能推荐',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_allocations.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无小金库',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请先创建小金库后再进行分配',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._allocations.map((allocation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAllocationItemCard(context, theme, allocation),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAllocationItemCard(
    BuildContext context,
    ThemeData theme,
    _AllocationItem allocation,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: allocation.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(allocation.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allocation.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  allocation.strategy,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${allocation.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${allocation.percent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 汇总卡片
  Widget _buildSummaryCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('已分配'),
              Text(
                '¥${_totalAllocated.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('剩余'),
              Text(
                '¥${_remaining.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _remaining == 0
                      ? AppColors.success
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 确认按钮
  Widget _buildConfirmButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _confirmAllocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '确认分配',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  void _saveAllocation() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分配方案已保存')),
    );
  }

  void _confirmAllocation() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已分配 ¥${_totalAllocated.toStringAsFixed(0)}')),
    );
  }
}

class _AllocationItem {
  final String? vaultId;
  final String name;
  final IconData icon;
  final List<Color> gradientColors;
  final String strategy;
  final double amount;
  final double percent;

  _AllocationItem({
    this.vaultId,
    required this.name,
    required this.icon,
    required this.gradientColors,
    required this.strategy,
    required this.amount,
    required this.percent,
  });
}
