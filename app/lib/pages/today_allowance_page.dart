import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/antigravity_shadows.dart';
import '../widgets/glass_components.dart';
import '../widgets/antigravity_animations.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import 'budget_center_page.dart';

/// 今日可支出页面
/// 原型设计 1.06：今日可支出
/// - 醒目的今日可支出金额（大字体居中）
/// - 预算剩余进度条
/// - 本日已花费列表
/// - 智能建议卡片
/// 借鉴 Spendee 的日常可支出额度设计
class TodayAllowancePage extends ConsumerStatefulWidget {
  const TodayAllowancePage({super.key});

  @override
  ConsumerState<TodayAllowancePage> createState() => _TodayAllowancePageState();
}

class _TodayAllowancePageState extends ConsumerState<TodayAllowancePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayExpense = ref.watch(todayExpenseProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    final daysRemaining = _getDaysRemainingInMonth();

    // 计算今日可支出额度（使用本月收入作为基准）
    final budgetRemaining = monthlyIncome - monthlyExpense;
    final dailyAllowance = budgetRemaining > 0
        ? budgetRemaining / daysRemaining
        : 0.0;
    final todayRemaining = dailyAllowance - todayExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日可支出'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showAllowanceSettings,
            tooltip: '设置',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAllowanceCard(context, theme, todayRemaining, dailyAllowance),
            _buildProgressSection(context, theme, budgetRemaining, monthlyIncome, daysRemaining),
            _buildTodayExpenseList(context, theme, todayExpense),
            _buildSmartSuggestions(context, theme, todayRemaining),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 核心卡片：今日可支出金额
  Widget _buildAllowanceCard(
    BuildContext context,
    ThemeData theme,
    double todayRemaining,
    double dailyAllowance,
  ) {
    final isOverBudget = todayRemaining < 0;
    final statusColor = isOverBudget
        ? AppColors.expense
        : (todayRemaining < dailyAllowance * 0.3
            ? AppColors.warning
            : AppColors.income);

    final statusText = isOverBudget
        ? '已超支'
        : (todayRemaining < dailyAllowance * 0.3
            ? '即将用完'
            : '状态良好');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AntigravityShadows.l4,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '今天还能花',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          AmountFloatUpAnimation(
            animate: true,
            child: Text(
              '¥${todayRemaining.abs().toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w700,
                height: 1.1,
                decoration: isOverBudget ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (isOverBudget) ...[
            const SizedBox(height: 8),
            Text(
              '已超出预算 ¥${todayRemaining.abs().toStringAsFixed(0)}',
              style: TextStyle(
                color: AppColors.expense,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '日均预算 ¥${dailyAllowance.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 预算进度区域
  Widget _buildProgressSection(
    BuildContext context,
    ThemeData theme,
    double budgetRemaining,
    double monthlyIncome,
    int daysRemaining,
  ) {
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    final progress = monthlyIncome > 0
        ? monthlyExpense / monthlyIncome
        : 0.0;
    final progressColor = progress > 0.9
        ? AppColors.expense
        : (progress > 0.7 ? AppColors.warning : AppColors.income);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AntigravityShadows.l2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '本月收支',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '剩余 $daysRemaining 天',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已支出 ¥${monthlyExpense.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '收入 ¥${monthlyIncome.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 今日已花费列表
  Widget _buildTodayExpenseList(
    BuildContext context,
    ThemeData theme,
    double todayExpense,
  ) {
    final todayTransactions = ref.watch(todayTransactionsProvider);
    final expenses = todayTransactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AntigravityShadows.l2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '今日已花费',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '¥${todayExpense.toStringAsFixed(0)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 48,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '今天还没有支出',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '继续保持！',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expenses.length.clamp(0, 5),
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 56,
                color: theme.colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final expense = expenses[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(expense.category).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getCategoryIcon(expense.category),
                      color: _getCategoryColor(expense.category),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    expense.note ?? expense.category,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    DateFormat('HH:mm').format(expense.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    '-¥${expense.amount.toStringAsFixed(0)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          if (expenses.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextButton(
                onPressed: () {
                  // 跳转到完整列表
                },
                child: Text('查看全部 ${expenses.length} 笔'),
              ),
            ),
        ],
      ),
    );
  }

  /// 智能建议卡片
  Widget _buildSmartSuggestions(
    BuildContext context,
    ThemeData theme,
    double todayRemaining,
  ) {
    final suggestions = _generateSuggestions(todayRemaining);
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '智能建议',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  suggestion.icon,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion.text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  int _getDaysRemainingInMonth() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return lastDay.day - now.day + 1;
  }

  List<_Suggestion> _generateSuggestions(double todayRemaining) {
    final suggestions = <_Suggestion>[];

    if (todayRemaining < 0) {
      suggestions.add(_Suggestion(
        Icons.warning_amber,
        '今日已超支，建议减少非必要消费，明天注意控制支出',
      ));
    } else if (todayRemaining < 50) {
      suggestions.add(_Suggestion(
        Icons.savings,
        '今日预算即将用完，可以考虑自带午餐或步行替代打车',
      ));
    } else if (todayRemaining > 200) {
      suggestions.add(_Suggestion(
        Icons.thumb_up,
        '今日预算充足，可以适当犒劳自己，但别忘了储蓄目标',
      ));
    }

    // 添加通用建议
    if (DateTime.now().weekday == DateTime.friday) {
      suggestions.add(_Suggestion(
        Icons.weekend,
        '周末将至，记得预留周末的娱乐开支',
      ));
    }

    return suggestions;
  }

  void _showAllowanceSettings() {
    AntigravityBottomSheet.show(
      context: context,
      title: '可支出设置',
      initialChildSize: 0.4,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('查看预算详情'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetCenterPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('计算周期'),
            subtitle: const Text('按月'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('选择计算周期'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile(
                        title: const Text('按日'),
                        value: 'daily',
                        groupValue: 'monthly',
                        onChanged: (v) => Navigator.pop(context),
                      ),
                      RadioListTile(
                        title: const Text('按周'),
                        value: 'weekly',
                        groupValue: 'monthly',
                        onChanged: (v) => Navigator.pop(context),
                      ),
                      RadioListTile(
                        title: const Text('按月'),
                        value: 'monthly',
                        groupValue: 'monthly',
                        onChanged: (v) => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('预算来源'),
            subtitle: const Text('月度总预算'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('选择预算来源'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile(
                        title: const Text('月度总预算'),
                        value: 'total',
                        groupValue: 'total',
                        onChanged: (v) => Navigator.pop(context),
                      ),
                      RadioListTile(
                        title: const Text('指定小金库'),
                        value: 'vault',
                        groupValue: 'total',
                        onChanged: (v) => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('超支提醒'),
            trailing: Switch(
              value: true,
              onChanged: (v) {},
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String categoryName) {
    // 简化的分类颜色映射
    final colors = {
      '餐饮': const Color(0xFFFF7043),
      '交通': const Color(0xFF42A5F5),
      '购物': const Color(0xFFAB47BC),
      '娱乐': const Color(0xFF66BB6A),
    };
    return colors[categoryName] ?? AppColors.primary;
  }

  IconData _getCategoryIcon(String categoryName) {
    // 简化的分类图标映射
    final icons = {
      '餐饮': Icons.restaurant,
      '交通': Icons.directions_car,
      '购物': Icons.shopping_bag,
      '娱乐': Icons.sports_esports,
    };
    return icons[categoryName] ?? Icons.category;
  }
}

class _Suggestion {
  final IconData icon;
  final String text;

  _Suggestion(this.icon, this.text);
}
