import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';

/// 预算中心页面
/// 原型设计 1.04：预算中心 Budget
/// - 收入池头部（本月收入、已分配、待分配）
/// - 小金库卡片列表
/// - 伙伴化提醒（温馨提示）
/// - 预算类目列表
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
    final monthlyExpense = ref.watch(monthlyExpenseProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIncomePoolHeader(context, theme, monthlyIncome),
            _buildVaultsSection(context, theme),
            _buildComfortMessage(context, theme),
            _buildBudgetCategories(context, theme, monthlyExpense),
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
  ) {
    // 模拟数据：已分配金额
    final allocated = 15000.0;
    final unallocated = monthlyIncome - allocated;
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
              Text(
                '¥${monthlyIncome.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
  Widget _buildVaultsSection(BuildContext context, ThemeData theme) {
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
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新建'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildVaultCard(
            context,
            theme,
            name: '应急金储备',
            balance: 25000,
            target: 50000,
            percent: 50,
            gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
            icon: Icons.savings,
          ),
          const SizedBox(height: 12),
          _buildVaultCard(
            context,
            theme,
            name: '旅行基金',
            balance: 8500,
            target: 10000,
            percent: 85,
            gradient: const [Color(0xFF4CAF50), Color(0xFF81C784)],
            icon: Icons.flight,
          ),
          const SizedBox(height: 12),
          _buildVaultCard(
            context,
            theme,
            name: '数码基金',
            balance: 3200,
            target: 10000,
            percent: 32,
            gradient: const [Color(0xFF2196F3), Color(0xFF64B5F6)],
            icon: Icons.computer,
          ),
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
    required int percent,
    required List<Color> gradient,
    required IconData icon,
  }) {
    Color progressColor;
    if (percent >= 80) {
      progressColor = AppColors.success;
    } else if (percent >= 50) {
      progressColor = AppColors.warning;
    } else {
      progressColor = theme.colorScheme.primary;
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
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¥${balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
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
                    widthFactor: percent / 100,
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
                  '目标 ¥${target.toStringAsFixed(0)} · 已达成$percent%',
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

  /// 伙伴化提醒
  /// 原型设计：预算即将超支时的温馨提醒
  Widget _buildComfortMessage(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('💭', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '餐饮预算还剩 ¥420',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '这10天平均每天可用 ¥42，您可以的！',
                  style: TextStyle(
                    fontSize: 12,
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

  /// 预算类目列表
  Widget _buildBudgetCategories(
    BuildContext context,
    ThemeData theme,
    double monthlyExpense,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '预算类目',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildBudgetItem(
            context,
            theme,
            name: '餐饮',
            icon: Icons.restaurant,
            iconColor: const Color(0xFFFF7043),
            spent: 1580,
            budget: 2000,
            percent: 79,
            daysLeft: 10,
          ),
          // 伙伴化设计：鼓励消息
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('👍', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '交通预算控制得很好，继续保持！已节省 ¥180',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单个预算项
  Widget _buildBudgetItem(
    BuildContext context,
    ThemeData theme, {
    required String name,
    required IconData icon,
    required Color iconColor,
    required double spent,
    required double budget,
    required int percent,
    required int daysLeft,
  }) {
    Color progressColor;
    if (percent >= 80) {
      progressColor = AppColors.warning;
    } else if (percent >= 100) {
      progressColor = AppColors.expense;
    } else {
      progressColor = AppColors.success;
    }

    final remaining = budget - spent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${spent.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '/ ¥${budget.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 进度条
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percent / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '剩余 ¥${remaining.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '还剩${daysLeft}天',
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
}
