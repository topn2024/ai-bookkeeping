import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/budget_vault_provider.dart';
import '../models/budget_vault.dart';
import '../services/allocation_service.dart';

/// 智能分配建议页面
/// 原型设计 3.05：智能分配建议
/// - 待分配金额展示
/// - 分配优先级说明
/// - 按优先级排列的分配建议（P1固定支出 → P2债务还款 → P3储蓄目标 → P4弹性支出）
/// - 一键应用智能方案
class VaultSmartAllocationPage extends ConsumerWidget {
  final double? amountToAllocate;

  const VaultSmartAllocationPage({
    super.key,
    this.amountToAllocate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vaultState = ref.watch(budgetVaultProvider);
    final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();
    final unallocatedAmount = amountToAllocate ?? vaultState.unallocatedAmount;

    // Generate smart allocation suggestions
    final allocationService = AllocationService();
    final suggestions = allocationService.getSuggestions(
      unallocatedAmount: unallocatedAmount,
      vaults: vaults,
    );

    // Calculate total suggested allocation
    final totalSuggested = suggestions.fold(0.0, (sum, s) => sum + s.suggestedAmount);
    final remaining = unallocatedAmount - totalSuggested;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildAmountCard(context, theme, unallocatedAmount),
                    _buildPriorityHint(context, theme),
                    _buildAllocationList(context, theme, suggestions, vaults),
                    _buildUnallocatedCard(context, theme, remaining),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildApplyButton(context, theme),
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
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '智能分配建议',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.help_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 待分配金额卡片
  Widget _buildAmountCard(BuildContext context, ThemeData theme, double amount) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
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
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount > 0 ? '系统已为您智能规划分配方案' : '暂无待分配金额',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  /// 优先级提示
  Widget _buildPriorityHint(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '分配顺序：固定支出 → 债务还款 → 储蓄目标 → 弹性支出',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 分配建议列表
  Widget _buildAllocationList(
    BuildContext context,
    ThemeData theme,
    List<AllocationSuggestion> suggestions,
    List<BudgetVault> vaults,
  ) {
    if (suggestions.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '暂无分配建议，请先创建小金库',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: suggestions.map((suggestion) {
          final vault = vaults.where((v) => v.id == suggestion.vaultId).firstOrNull;
          if (vault == null) return const SizedBox.shrink();

          final priorityInfo = _getPriorityInfo(suggestion.priority);
          final allocation = _SmartAllocation(
            priority: 'P${suggestion.priority}',
            priorityColor: priorityInfo.color,
            priorityBgColor: priorityInfo.bgColor,
            name: vault.name,
            amount: suggestion.suggestedAmount,
            icon: vault.icon,
            description: suggestion.reason,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildAllocationCard(context, theme, allocation),
          );
        }).toList(),
      ),
    );
  }

  ({Color color, Color bgColor}) _getPriorityInfo(int priority) {
    switch (priority) {
      case 1:
        return (color: const Color(0xFFF44336), bgColor: const Color(0xFFFFEBEE));
      case 2:
        return (color: const Color(0xFFFF9800), bgColor: const Color(0xFFFFF3E0));
      case 3:
        return (color: AppColors.success, bgColor: const Color(0xFFE8F5E9));
      default:
        return (color: const Color(0xFF2196F3), bgColor: const Color(0xFFE3F2FD));
    }
  }

  Widget _buildAllocationCard(
    BuildContext context,
    ThemeData theme,
    _SmartAllocation allocation,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: allocation.priorityColor, width: 4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: allocation.priorityBgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  allocation.priority,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: allocation.priorityColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                allocation.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '¥${allocation.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                allocation.icon,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                allocation.description,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 未分配卡片
  Widget _buildUnallocatedCard(BuildContext context, ThemeData theme, double remaining) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '剩余未分配',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${remaining.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: remaining > 0 ? AppColors.success : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 应用按钮
  Widget _buildApplyButton(BuildContext context, ThemeData theme) {
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
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('智能方案已应用')),
              );
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('一键应用智能方案'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartAllocation {
  final String priority;
  final Color priorityColor;
  final Color priorityBgColor;
  final String name;
  final double amount;
  final IconData icon;
  final String description;

  _SmartAllocation({
    required this.priority,
    required this.priorityColor,
    required this.priorityBgColor,
    required this.name,
    required this.amount,
    required this.icon,
    required this.description,
  });
}
