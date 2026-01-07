import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget_vault.dart';
import '../providers/budget_vault_provider.dart';
import '../theme/app_theme.dart';
import 'vault_detail_page.dart';
import 'vault_create_page.dart';
import 'vault_allocation_page.dart';
import 'vault_health_page.dart';

/// 小金库概览页面
/// 原型设计 3.01：小金库概览
/// - 渐变总额卡片（总额、本月存入、本月支出）
/// - 小金库列表（进度条、目标金额）
/// - 底部快捷操作按钮（存入/取出）
class VaultOverviewPage extends ConsumerWidget {
  const VaultOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vaultState = ref.watch(budgetVaultProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme, ref),
            Expanded(
              child: vaultState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : vaultState.error != null
                      ? _buildErrorState(context, theme, vaultState.error!, ref)
                      : RefreshIndicator(
                          onRefresh: () =>
                              ref.read(budgetVaultProvider.notifier).refresh(),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                _buildTotalCard(context, theme, vaultState),
                                if (vaultState.hasUnallocated)
                                  _buildUnallocatedBanner(
                                      context, theme, vaultState),
                                _buildVaultList(context, theme, vaultState),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
            ),
            _buildQuickActions(context, theme, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme, WidgetRef ref) {
    final overspentCount = ref.watch(overspentVaultsProvider).length;

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
              '小金库',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          // 健康状态按钮（有警告时显示红点）
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VaultHealthPage()),
            ),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Stack(
                children: [
                  Icon(Icons.monitor_heart_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                  if (overspentCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _navigateToCreate(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(Icons.add, color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, ThemeData theme, String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(budgetVaultProvider.notifier).refresh(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 总额卡片
  Widget _buildTotalCard(
      BuildContext context, ThemeData theme, BudgetVaultState state) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '小金库总额',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${state.totalAvailable.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('已分配', '¥${state.totalAllocated.toStringAsFixed(0)}'),
              const SizedBox(width: 24),
              _buildStatItem('已花费', '¥${state.totalSpent.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 待分配提示
  Widget _buildUnallocatedBanner(
      BuildContext context, ThemeData theme, BudgetVaultState state) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VaultAllocationPage(
            amountToAllocate: state.unallocatedAmount,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '有待分配的收入',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '¥${state.unallocatedAmount.toStringAsFixed(0)} 等待分配',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '去分配',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 小金库列表
  Widget _buildVaultList(
      BuildContext context, ThemeData theme, BudgetVaultState state) {
    final vaults = state.vaults.where((v) => v.isEnabled).toList();

    if (vaults.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.savings_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '还没有小金库',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _navigateToCreate(context),
              child: const Text('创建第一个小金库'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: vaults.map((vault) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildVaultCard(context, theme, vault),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVaultCard(
      BuildContext context, ThemeData theme, BudgetVault vault) {
    final progress = vault.progress;
    final progressPercent = (progress * 100).round();

    Color badgeColor;
    Color badgeBgColor;
    if (vault.isOverSpent) {
      badgeColor = AppColors.error;
      badgeBgColor = const Color(0xFFFFEBEE);
    } else if (vault.isAlmostEmpty) {
      badgeColor = AppColors.warning;
      badgeBgColor = const Color(0xFFFFF3E0);
    } else if (progressPercent >= 80) {
      badgeColor = AppColors.success;
      badgeBgColor = const Color(0xFFE8F5E9);
    } else if (progressPercent >= 50) {
      badgeColor = AppColors.warning;
      badgeBgColor = const Color(0xFFFFF3E0);
    } else {
      badgeColor = const Color(0xFF2196F3);
      badgeBgColor = const Color(0xFFE3F2FD);
    }

    return GestureDetector(
      onTap: () => _navigateToDetail(context, vault),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    vault.color,
                    vault.color.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(vault.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        vault.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          vault.isOverSpent
                              ? '超支'
                              : '$progressPercent%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${vault.available.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: vault.isOverSpent ? AppColors.error : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 进度条
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '目标 ¥${vault.targetAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 底部快捷操作
  Widget _buildQuickActions(
      BuildContext context, ThemeData theme, WidgetRef ref) {
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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showDepositDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('存入'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showWithdrawDialog(context, ref),
                icon: const Icon(Icons.remove),
                label: const Text('取出'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, BudgetVault vault) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VaultDetailPage(vault: vault),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VaultCreatePage(),
      ),
    );
  }

  void _showDepositDialog(BuildContext context, WidgetRef ref) {
    final vaults = ref.read(budgetVaultProvider).vaults;
    if (vaults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建小金库')),
      );
      return;
    }

    // TODO: 显示存入对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('存入功能开发中')),
    );
  }

  void _showWithdrawDialog(BuildContext context, WidgetRef ref) {
    final vaults = ref.read(budgetVaultProvider).vaults;
    if (vaults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建小金库')),
      );
      return;
    }

    // TODO: 显示取出对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('取出功能开发中')),
    );
  }
}
