import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../providers/transaction_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/gamification_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../widgets/budget_alert_widget.dart';
import 'transaction_list_page.dart';
import 'add_transaction_page.dart';
import 'today_allowance_page.dart';
import 'money_age_page.dart';

/// 仪表盘首页
/// 原型设计 1.01：仪表盘 Dashboard
/// - 伙伴化设计：温暖问候语（根据时间动态变化）
/// - 本月结余显示（带趋势指示）
/// - 成就庆祝卡片（连续记账达成）
/// - 钱龄卡片
/// - 快速统计（本月收入/支出）
/// - 预算概览
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    final colors = ref.themeColors;
    final balance = monthlyIncome - monthlyExpense;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderGradient(context, theme, balance, colors),
            const BudgetAlertBanner(),
            _buildTodayAllowanceCard(context, theme, monthlyIncome, monthlyExpense),
            _buildCelebrationCard(context, theme),
            _buildMoneyAgeCard(context, theme, ref),
            _buildQuickStats(context, theme, monthlyIncome, monthlyExpense, colors),
            _buildBudgetOverview(context, theme),
            _buildRecentTransactions(context, theme, transactions, colors),
            const SizedBox(height: 100), // 底部导航栏留白
          ],
        ),
      ),
    );
  }

  /// 头部渐变区域
  /// 原型设计：温暖问候语 + 本月结余
  Widget _buildHeaderGradient(
    BuildContext context,
    ThemeData theme,
    double balance,
    ThemeColors colors,
  ) {
    final greeting = _getGreeting();
    final authState = ref.watch(authProvider);
    final userName = authState.user?.nickname ?? authState.user?.email?.split('@').first ?? '';

    // 计算同比增长
    final lastMonthBalance = ref.watch(lastMonthBalanceProvider);
    final growth = balance > 0 && lastMonthBalance > 0
        ? ((balance - lastMonthBalance) / lastMonthBalance * 100)
        : 0.0;
    final isPositiveGrowth = growth >= 0;

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
              // 伙伴化问候语
              Row(
                children: [
                  Text(
                    greeting.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    greeting.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$userName，${greeting.motivation}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // 本月结余
              Center(
                child: Column(
                  children: [
                    Text(
                      '本月结余',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¥${balance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 趋势指示
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPositiveGrowth
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPositiveGrowth
                              ? '太棒了！较上月提升 ${growth.toStringAsFixed(1)}% 💪'
                              : '较上月下降 ${(-growth).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 今日可支出卡片
  /// 原型设计 1.06：快速入口到今日可支出页面
  Widget _buildTodayAllowanceCard(
    BuildContext context,
    ThemeData theme,
    double monthlyIncome,
    double monthlyExpense,
  ) {
    // 计算今日可支出
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysRemaining = lastDay.day - now.day + 1;
    final budgetRemaining = monthlyIncome - monthlyExpense;
    final dailyAllowance = budgetRemaining > 0 ? budgetRemaining / daysRemaining : 0.0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TodayAllowancePage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              AppColors.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.today,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日可支出',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥${dailyAllowance.toStringAsFixed(0)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 成就庆祝卡片
  /// 原型设计：伙伴化设计 - 连续记账达成时显示
  Widget _buildCelebrationCard(BuildContext context, ThemeData theme) {
    final streakStats = ref.watch(gamificationProvider);
    final consecutiveDays = streakStats.currentStreak;

    // 如果没有连续记账，不显示卡片
    if (consecutiveDays == 0) {
      return const SizedBox.shrink();
    }

    return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFF8E1),
                const Color(0xFFFFECB3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '太棒了！连续记账$consecutiveDays天！',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '继续保持！',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }

  /// 钱龄卡片
  /// 原型设计：钱龄数值、等级、趋势
  Widget _buildMoneyAgeCard(BuildContext context, ThemeData theme, WidgetRef ref) {
    final moneyAgeData = ref.watch(moneyAgeProvider);
    final moneyAge = moneyAgeData.days;

    // 根据钱龄天数确定等级
    String level;
    if (moneyAge >= 90) {
      level = '卓越';
    } else if (moneyAge >= 60) {
      level = '优秀';
    } else if (moneyAge >= 30) {
      level = '良好';
    } else if (moneyAge >= 14) {
      level = '及格';
    } else {
      level = '需改善';
    }

    // 趋势（从moneyAgeData获取）
    final trendDays = moneyAgeData.trend == 'up' ? 5 : (moneyAgeData.trend == 'down' ? -5 : 0);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MoneyAgePage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '钱龄',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        level,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$moneyAge',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '天',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '您花的钱平均是$moneyAge天前赚的',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  '较上月提升$trendDays天',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 快速统计卡片
  /// 原型设计：本月收入/支出双列显示
  Widget _buildQuickStats(
    BuildContext context,
    ThemeData theme,
    double income,
    double expense,
    ThemeColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '本月收入',
              value: '¥${income.toStringAsFixed(0)}',
              valueColor: colors.income,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '本月支出',
              value: '¥${expense.toStringAsFixed(0)}',
              valueColor: colors.expense,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 预算概览
  /// 原型设计：预算类目进度条列表
  /// 数据来源：budgetProvider（预算设置）+ monthlyExpenseByCategoryProvider（本月分类支出）
  Widget _buildBudgetOverview(BuildContext context, ThemeData theme) {
    final budgets = ref.watch(budgetProvider);
    final categorySpending = ref.watch(monthlyExpenseByCategoryProvider);

    // 过滤出已启用的分类预算，并按已花费百分比排序（高的在前）
    final activeBudgets = budgets
        .where((b) => b.isEnabled && b.amount > 0 && b.categoryId != null)
        .map((b) {
          final spent = categorySpending[b.categoryId!] ?? 0.0;
          final percent = (spent / b.amount * 100).clamp(0, 999).toInt();
          return (budget: b, spent: spent, percent: percent);
        })
        .toList()
      ..sort((a, b) => b.percent.compareTo(a.percent));

    // 最多显示3个预算
    final displayBudgets = activeBudgets.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '预算概览',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // 跳转到预算中心
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (displayBudgets.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '暂无预算设置',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...displayBudgets.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final categoryId = item.budget.categoryId!;
              final category = DefaultCategories.findById(categoryId);
              final categoryName = category?.localizedName ?? categoryId;

              return Padding(
                padding: EdgeInsets.only(top: index > 0 ? 12 : 0),
                child: _buildBudgetItem(
                  context,
                  theme,
                  name: categoryName,
                  icon: category?.icon ?? Icons.category,
                  iconColor: category?.color ?? Colors.grey,
                  spent: item.spent,
                  budget: item.budget.amount,
                  percent: item.percent,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    ThemeData theme, {
    required String name,
    required IconData icon,
    required Color iconColor,
    required double spent,
    required double budget,
    required int percent,
  }) {
    Color progressColor;
    if (percent >= 80) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.success;
    }

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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '¥${spent.toStringAsFixed(0)} / ¥${budget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  /// 最近交易列表
  Widget _buildRecentTransactions(
    BuildContext context,
    ThemeData theme,
    List<Transaction> transactions,
    ThemeColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.recentTransactions,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionListPage()),
                ),
                child: Text(context.l10n.viewAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.noData,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...transactions.take(5).map((tx) => _buildTransactionItem(
                  context,
                  theme,
                  tx,
                  colors,
                )),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    ThemeData theme,
    Transaction transaction,
    ThemeColors colors,
  ) {
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTransactionPage(transaction: transaction),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
                color: (category?.color ?? Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                category?.icon ?? Icons.help_outline,
                color: category?.color ?? Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.localizedName ?? transaction.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    transaction.note ??
                        DateFormat('MM/dd HH:mm').format(transaction.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isExpense ? colors.expense : colors.income,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取问候语
  _Greeting _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return _Greeting(
        emoji: '☀️',
        text: '早安，美好的一天开始了',
        motivation: '今天也要加油哦！',
      );
    } else if (hour >= 12 && hour < 14) {
      return _Greeting(
        emoji: '🌤️',
        text: '中午好，记得吃午饭',
        motivation: '休息一下再继续！',
      );
    } else if (hour >= 14 && hour < 18) {
      return _Greeting(
        emoji: '⛅',
        text: '下午好，保持好心情',
        motivation: '继续加油！',
      );
    } else if (hour >= 18 && hour < 22) {
      return _Greeting(
        emoji: '🌙',
        text: '晚上好，辛苦了一天',
        motivation: '好好放松一下！',
      );
    } else {
      return _Greeting(
        emoji: '🌟',
        text: '夜深了，注意休息',
        motivation: '早点休息哦！',
      );
    }
  }
}

/// 问候语数据模型
class _Greeting {
  final String emoji;
  final String text;
  final String motivation;

  _Greeting({
    required this.emoji,
    required this.text,
    required this.motivation,
  });
}
