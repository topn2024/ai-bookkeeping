import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_vault_provider.dart';
import 'vault_create_page.dart';
import 'vault_detail_page.dart';
import 'reports/budget_report_page.dart';
import 'transaction_list_page.dart';

/// 预算中心页面
/// 原型设计 1.04：预算中心 Budget
/// - 收入池头部（本月收入、已分配、待分配）
/// - 小金库卡片列表
class BudgetCenterPage extends ConsumerStatefulWidget {
  const BudgetCenterPage({super.key});

  @override
  ConsumerState<BudgetCenterPage> createState() => _BudgetCenterPageState();
}

class _BudgetCenterPageState extends ConsumerState<BudgetCenterPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final vaultState = ref.watch(budgetVaultProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIncomePoolHeader(context, theme, monthlyIncome, vaultState),
            _buildVaultsSection(context, theme, vaultState),
            const SizedBox(height: 100), // 底部导航栏留白
          ],
        ),
      ),
    );
  }

  /// 收入池头部
  /// 原型设计：渐变背景、本月收入池、已分配/待分配
  Widget _buildIncomePoolHeader(
    BuildContext context,
    ThemeData theme,
    double monthlyIncome,
    BudgetVaultState vaultState,
  ) {
    final allocated = vaultState.totalAllocated;
    final unallocated = vaultState.unallocatedAmount;
    final allocatedPercent = monthlyIncome > 0 ? (allocated / monthlyIncome * 100) : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            HSLColor.fromColor(theme.colorScheme.primary)
                .withLightness(0.35)
                .toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本月收入池',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionListPage()),
                    ),
                    child: Text(
                      '¥${monthlyIncome.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bar_chart, color: Colors.white),
                    tooltip: '查看预算报告',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BudgetReportPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '已分配',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¥${allocated.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '待分配',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¥${unallocated.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 进度条
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: allocatedPercent / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 小金库区域
  /// 原型设计：小金库卡片列表
  Widget _buildVaultsSection(BuildContext context, ThemeData theme, BudgetVaultState vaultState) {
    final vaults = vaultState.vaults.where((v) => v.isEnabled).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '小金库',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VaultCreatePage(),
                    ),
                  );
                  if (result == true && mounted) {
                    ref.invalidate(budgetVaultProvider);
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (vaults.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '暂无小金库，点击新建开始规划',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...vaults.map((vault) {
              // 显示使用率（已花费/已分配），而不是达成率
              final percent = vault.allocatedAmount > 0
                  ? (vault.spentAmount / vault.allocatedAmount * 100).round()
                  : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VaultDetailPage(vault: vault),
                    ),
                  ),
                  child: _buildVaultCard(
                    context,
                    theme,
                    name: vault.name,
                    balance: vault.allocatedAmount - vault.spentAmount,  // 显示剩余金额
                    target: vault.allocatedAmount,  // 预算总额
                    spent: vault.spentAmount,  // 已花费
                    percent: percent,
                    gradient: [vault.color, vault.color.withValues(alpha: 0.7)],
                    icon: vault.icon,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// 单个小金库卡片
  Widget _buildVaultCard(
    BuildContext context,
    ThemeData theme, {
    required String name,
    required double balance,
    required double target,
    double? spent,
    required int percent,
    required List<Color> gradient,
    required IconData icon,
  }) {
    // 使用率颜色：0-50%健康，50-80%警告，80-100%危险，>100%超支
    Color progressColor;
    if (percent >= 100) {
      progressColor = AppColors.expense;  // 超支 - 红色
    } else if (percent >= 80) {
      progressColor = AppColors.warning;  // 警告 - 橙色
    } else if (percent >= 50) {
      progressColor = Colors.blue;  // 中等使用 - 蓝色
    } else {
      progressColor = AppColors.success;  // 健康 - 绿色
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (percent > 100)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '超支',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.expense,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  balance >= 0 ? '剩余 ¥${balance.toStringAsFixed(0)}' : '超支 ¥${(-balance).toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? theme.colorScheme.onSurface : AppColors.expense,
                  ),
                ),
                const SizedBox(height: 8),
                // 进度条
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (percent / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: progressColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spent != null
                      ? '已花 ¥${spent.toStringAsFixed(0)} / ¥${target.toStringAsFixed(0)} · 使用$percent%'
                      : '预算 ¥${target.toStringAsFixed(0)} · 使用$percent%',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
