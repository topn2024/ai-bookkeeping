import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/budget_vault_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/budget_vault.dart';

/// 零基预算分配页面
/// 原型设计 3.09：零基预算分配
/// - 本月可分配收入
/// - 零基预算原则说明
/// - 预算分配列表（储蓄优先、固定支出、生活消费、弹性支出）
/// - 收入 - 支出 - 储蓄 = 0 验证
class VaultZeroBasedPage extends ConsumerWidget {
  const VaultZeroBasedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vaultState = ref.watch(budgetVaultProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();

    // Calculate total allocated
    final totalAllocated = vaultState.totalAllocated;
    final balance = monthlyIncome - totalAllocated;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildIncomeCard(context, theme, monthlyIncome),
                    const SizedBox(height: 16),
                    _buildPrincipleHint(context, theme),
                    const SizedBox(height: 16),
                    _buildAllocationList(context, theme, vaults, monthlyIncome),
                    const SizedBox(height: 16),
                    _buildBalanceCard(context, theme, balance),
                  ],
                ),
              ),
            ),
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
              '零基预算分配',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 收入卡片
  Widget _buildIncomeCard(BuildContext context, ThemeData theme, double totalIncome) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6495ED), Color(0xFF87CEFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本月可分配收入',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${totalIncome.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalIncome > 0 ? '本月总收入' : '暂无收入记录',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// 零基预算原则说明
  Widget _buildPrincipleHint(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB3CFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: theme.colorScheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                children: const [
                  TextSpan(
                    text: '零基预算原则：',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: '每分钱都有去处，收入 - 支出 - 储蓄 = 0'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 预算分配列表
  Widget _buildAllocationList(
    BuildContext context,
    ThemeData theme,
    List<BudgetVault> vaults,
    double totalIncome,
  ) {
    // Group vaults by type
    final savingsVaults = vaults.where((v) => v.type == VaultType.savings).toList();
    final fixedVaults = vaults.where((v) => v.type == VaultType.fixed).toList();
    final flexibleVaults = vaults.where((v) => v.type == VaultType.flexible).toList();
    final debtVaults = vaults.where((v) => v.type == VaultType.debt).toList();

    // Calculate totals by type
    double savingsTotal = savingsVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    double fixedTotal = fixedVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    double flexibleTotal = flexibleVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
    double debtTotal = debtVaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);

    final allocations = <_ZeroBasedItem>[];

    if (savingsTotal > 0 || savingsVaults.isNotEmpty) {
      allocations.add(_ZeroBasedItem(
        icon: Icons.savings,
        iconColor: Colors.white,
        iconBgColor: const Color(0xFF66BB6A),
        name: '储蓄优先',
        subtitle: savingsVaults.map((v) => v.name).join('、'),
        amount: savingsTotal,
        percent: totalIncome > 0 ? (savingsTotal / totalIncome * 100).round() : 0,
        isHighlighted: true,
      ));
    }

    if (fixedTotal > 0 || fixedVaults.isNotEmpty) {
      allocations.add(_ZeroBasedItem(
        icon: Icons.home,
        iconColor: theme.colorScheme.primary,
        iconBgColor: theme.colorScheme.surfaceContainerHighest,
        name: '固定支出',
        subtitle: fixedVaults.map((v) => v.name).join('、'),
        amount: fixedTotal,
        percent: totalIncome > 0 ? (fixedTotal / totalIncome * 100).round() : 0,
      ));
    }

    if (debtTotal > 0 || debtVaults.isNotEmpty) {
      allocations.add(_ZeroBasedItem(
        icon: Icons.credit_card,
        iconColor: theme.colorScheme.primary,
        iconBgColor: theme.colorScheme.surfaceContainerHighest,
        name: '债务还款',
        subtitle: debtVaults.map((v) => v.name).join('、'),
        amount: debtTotal,
        percent: totalIncome > 0 ? (debtTotal / totalIncome * 100).round() : 0,
      ));
    }

    if (flexibleTotal > 0 || flexibleVaults.isNotEmpty) {
      allocations.add(_ZeroBasedItem(
        icon: Icons.restaurant,
        iconColor: theme.colorScheme.primary,
        iconBgColor: theme.colorScheme.surfaceContainerHighest,
        name: '弹性支出',
        subtitle: flexibleVaults.map((v) => v.name).join('、'),
        amount: flexibleTotal,
        percent: totalIncome > 0 ? (flexibleTotal / totalIncome * 100).round() : 0,
      ));
    }

    if (allocations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '暂无预算分配，请先创建小金库',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '预算分配',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: allocations.map((item) {
              final isLast = item == allocations.last;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: item.isHighlighted
                      ? const Color(0xFFE8F5E9).withValues(alpha: 0.5)
                      : null,
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            item.subtitle.isNotEmpty ? item.subtitle : '暂无',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${item.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${item.percent}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isHighlighted
                                ? const Color(0xFF66BB6A)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 结余卡片
  Widget _buildBalanceCard(BuildContext context, ThemeData theme, double balance) {
    final isBalanced = balance.abs() < 0.01;
    final isPositive = balance > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '收入 - 支出 - 储蓄',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '= ¥${balance.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isBalanced ? AppColors.success : (isPositive ? AppColors.warning : AppColors.expense),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBalanced ? Icons.check : (isPositive ? Icons.info : Icons.warning),
                size: 14,
                color: isBalanced ? AppColors.success : (isPositive ? AppColors.warning : AppColors.expense),
              ),
              const SizedBox(width: 4),
              Text(
                isBalanced ? '完美的零基预算' : (isPositive ? '还有 ¥${balance.toStringAsFixed(0)} 待分配' : '超支 ¥${(-balance).toStringAsFixed(0)}'),
                style: TextStyle(
                  fontSize: 12,
                  color: isBalanced ? AppColors.success : (isPositive ? AppColors.warning : AppColors.expense),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZeroBasedItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String name;
  final String subtitle;
  final double amount;
  final int percent;
  final bool isHighlighted;

  _ZeroBasedItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.percent,
    this.isHighlighted = false,
  });
}
