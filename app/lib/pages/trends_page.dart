import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import 'category_detail_page.dart';
import 'reports/trend_drill_page.dart';

/// 趋势分析页面
/// 原型设计 1.02：趋势分析 Trends
/// - 周期选择器（本月、上月、近3月、今年）
/// - Tab切换（消费趋势、分类占比、洞察）
/// - 图表区域
/// - 统计卡片（日均支出、最高单日）
/// - 消费TOP分类列表
class TrendsPage extends ConsumerStatefulWidget {
  const TrendsPage({super.key});

  @override
  ConsumerState<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends ConsumerState<TrendsPage>
    with SingleTickerProviderStateMixin {
  int _selectedPeriod = 0;
  late TabController _tabController;

  final List<String> _periods = ['本月', '上月', '近3月', '今年'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            _buildPeriodSelector(context, theme),
            _buildTabBar(context, theme),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTrendContent(context, theme, transactions, monthlyExpense),
                  _buildCategoryContent(context, theme, transactions),
                  _buildInsightContent(context, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 页面标题
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            context.l10n.trends,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 周期选择器
  /// 原型设计：本月、上月、近3月、今年
  Widget _buildPeriodSelector(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => setState(() => _selectedPeriod = index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _periods[index],
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Tab 切换栏
  /// 原型设计：消费趋势、分类占比、洞察
  Widget _buildTabBar(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: theme.colorScheme.onSurface,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '消费趋势'),
          Tab(text: '分类占比'),
          Tab(text: '洞察'),
        ],
      ),
    );
  }

  /// 消费趋势内容
  Widget _buildTrendContent(
    BuildContext context,
    ThemeData theme,
    List<Transaction> transactions,
    double monthlyExpense,
  ) {
    final dayCount = DateTime.now().day;
    final dailyAvg = dayCount > 0 ? monthlyExpense / dayCount : 0.0;

    // 计算最高单日支出
    final expenseByDay = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        final key = '${tx.date.year}-${tx.date.month}-${tx.date.day}';
        expenseByDay[key] = (expenseByDay[key] ?? 0) + tx.amount;
      }
    }
    final maxDaily = expenseByDay.values.isEmpty
        ? 0.0
        : expenseByDay.values.reduce((a, b) => a > b ? a : b);

    // 获取支出分类统计
    final categoryExpense = <String, double>{};
    final categoryCount = <String, int>{};
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        categoryExpense[tx.category] =
            (categoryExpense[tx.category] ?? 0) + tx.amount;
        categoryCount[tx.category] = (categoryCount[tx.category] ?? 0) + 1;
      }
    }

    // 排序获取TOP分类
    final sortedCategories = categoryExpense.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图表占位区域
          _buildChartPlaceholder(context, theme),
          const SizedBox(height: 16),
          // 统计卡片
          _buildSummaryCards(context, theme, dailyAvg, maxDaily),
          const SizedBox(height: 24),
          // TOP分类列表
          _buildTopCategories(
              context, theme, sortedCategories, categoryCount),
        ],
      ),
    );
  }

  /// 图表占位区域
  Widget _buildChartPlaceholder(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrendDrillPage()),
      ),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                '消费趋势折线图',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '点击可下钻查看详情',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 统计卡片
  /// 原型设计：日均支出、最高单日
  Widget _buildSummaryCards(
    BuildContext context,
    ThemeData theme,
    double dailyAvg,
    double maxDaily,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            theme,
            label: '日均支出',
            value: '¥${dailyAvg.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            theme,
            label: '最高单日',
            value: '¥${maxDaily.toStringAsFixed(0)}',
            valueColor: AppColors.expense,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
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
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 消费TOP分类
  Widget _buildTopCategories(
    BuildContext context,
    ThemeData theme,
    List<MapEntry<String, double>> categories,
    Map<String, int> categoryCount,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.noData,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '消费TOP分类',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...categories.take(5).map((entry) {
          final category = DefaultCategories.findById(entry.key);
          final count = categoryCount[entry.key] ?? 0;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryDetailPage(
                  categoryId: entry.key,
                  isExpense: true,
                ),
              ),
            ),
            child: _buildCategoryItem(
              context,
              theme,
              icon: category?.icon ?? Icons.help_outline,
              iconColor: category?.color ?? Colors.grey,
              name: category?.localizedName ?? entry.key,
              count: count,
              amount: entry.value,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String name,
    required int count,
    required double amount,
  }) {
    return Container(
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$count笔交易',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }

  /// 分类占比内容
  Widget _buildCategoryContent(
    BuildContext context,
    ThemeData theme,
    List<Transaction> transactions,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '分类占比饼图',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 洞察内容
  Widget _buildInsightContent(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'AI 消费洞察',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
