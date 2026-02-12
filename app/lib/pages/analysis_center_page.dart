import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/ledger_context_provider.dart';
import '../services/category_localization_service.dart';
import '../extensions/category_extensions.dart';

// 趋势分析相关
import 'reports/trend_drill_page.dart';
import 'reports/expense_heatmap_page.dart';

// 分类分析相关
import 'reports/category_pie_drill_page.dart';
import 'reports/drill_navigation_page.dart';
import 'tag_statistics_page.dart';
import 'wants_needs_insight_page.dart';

// 统计对比相关
import 'period_comparison_page.dart';
import 'member_comparison_page.dart';
import 'peer_comparison_page.dart';

// 报告中心相关
import 'reports/monthly_report_page.dart';
import 'annual_report_page.dart';
import 'reports/annual_summary_page.dart';
import 'reports/budget_report_page.dart';
import 'custom_report_page.dart';

// 洞察发现相关
import 'ai/spending_prediction_page.dart';
import 'actionable_advice_page.dart';
import 'latte_factor_page.dart';
import 'subscription_waste_page.dart';
import 'trends_page.dart';
import 'vault_overview_page.dart';

// 专项分析相关
import 'money_age_page.dart';
import 'money_age_influence_page.dart';
import 'money_age_progress_page.dart';
import 'money_age_resource_pool_page.dart';
import 'financial_health_dashboard_page.dart';
import 'goal_achievement_dashboard_page.dart';
import 'budget_health_page.dart';
import 'vault_health_page.dart';
import 'location_analysis_page.dart';
import 'asset_overview_page.dart';
import 'ai/ai_learning_report_page.dart';
import 'ai_learning_curve_page.dart';
import 'family_leaderboard_page.dart';
import 'user_profile_visualization_page.dart';

/// 数据分析中心页面
///
/// 整合所有分析类页面的统一入口
/// 原型设计：数据分析中心
///
/// 结构：
/// - Tab 1: 趋势分析 - 消费趋势、热力图
/// - Tab 2: 分类分析 - 分类占比、标签统计
/// - Tab 3: 统计对比 - 同环比、成员对比、同类对比
/// - Tab 4: 报告中心 - 月报、年报、预算报告、自定义报告
/// - Tab 5: 洞察发现 - AI洞察、拿铁因子、订阅浪费、消费预测
/// - Tab 6: 专项分析 - 钱龄、健康评估、位置分析、资产概览
class AnalysisCenterPage extends ConsumerStatefulWidget {
  const AnalysisCenterPage({super.key});

  @override
  ConsumerState<AnalysisCenterPage> createState() => _AnalysisCenterPageState();
}

class _AnalysisCenterPageState extends ConsumerState<AnalysisCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPeriod = 0;

  final List<String> _periods = ['本月', '上月', '近3月', '今年'];
  final List<_TabItem> _tabs = [
    _TabItem(icon: Icons.trending_up, label: '趋势'),
    _TabItem(icon: Icons.pie_chart, label: '分类'),
    _TabItem(icon: Icons.compare_arrows, label: '对比'),
    _TabItem(icon: Icons.description, label: '报告'),
    _TabItem(icon: Icons.lightbulb, label: '洞察'),
    _TabItem(icon: Icons.analytics, label: '专项'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // 顶部标题栏 - 使用主题色背景
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            child: SafeArea(
              bottom: false,
              child: _buildHeader(context, theme),
            ),
          ),
          // 期间选择器和标签栏 - 使用默认背景
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                _buildPeriodSelector(context, theme),
                _buildTabBar(context, theme),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TrendAnalysisTab(selectedPeriod: _selectedPeriod),
                _CategoryAnalysisTab(selectedPeriod: _selectedPeriod),
                _ComparisonTab(selectedPeriod: _selectedPeriod),
                _ReportCenterTab(),
                _InsightTab(),
                _SpecialAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            '数据分析',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,  // 白色文字
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),  // 白色图标
            onPressed: () {
              _showFilterSheet(context, theme);
            },
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择分析时段', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...List.generate(_periods.length, (index) {
                return ListTile(
                  title: Text(_periods[index]),
                  trailing: _selectedPeriod == index ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                  onTap: () {
                    setState(() => _selectedPeriod = index);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_periods[index]),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedPeriod = index);
                }
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, ThemeData theme) {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: _tabs.map((tab) => Tab(
        icon: Icon(tab.icon, size: 20),
        text: tab.label,
      )).toList(),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;

  _TabItem({required this.icon, required this.label});
}

// ==================== Tab 1: 趋势分析 ====================

class _TrendAnalysisTab extends ConsumerWidget {
  final int selectedPeriod;

  const _TrendAnalysisTab({required this.selectedPeriod});

  /// 根据选中的周期获取日期范围
  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case 0: // 本月
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case 1: // 上月
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: lastMonth, end: lastMonthEnd);
      case 2: // 近3月
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: now,
        );
      case 3: // 今年
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    }
  }

  /// 获取周期标签
  String _getPeriodLabel() {
    const periods = ['本月', '上月', '近3月', '今年'];
    return periods[selectedPeriod];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);

    // 根据选中的周期过滤交易
    final range = _getDateRange();
    final transactions = allTransactions.where((t) {
      return t.date.isAfter(range.start.subtract(const Duration(days: 1))) &&
             t.date.isBefore(range.end.add(const Duration(days: 1)));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 趋势图表卡片
        _buildTrendChartCard(context, theme, transactions, monthlyExpense),
        const SizedBox(height: 16),

        // 统计卡片
        _buildStatisticsRow(context, theme, transactions),
        const SizedBox(height: 16),

        // 快捷入口
        _buildQuickAccess(context, theme),
        const SizedBox(height: 16),

        // TOP分类
        _buildTopCategories(context, theme, transactions),
      ],
    );
  }

  Widget _buildTrendChartCard(BuildContext context, ThemeData theme,
      List<Transaction> transactions, double monthlyExpense) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TrendDrillPage(dateRange: _getDateRange())),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('消费趋势', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
                ],
              ),
              const SizedBox(height: 16),
              // 消费趋势图表
              _buildMiniTrendChart(context, theme, transactions),
              const SizedBox(height: 12),
              Text(
                '本月支出 ¥${monthlyExpense.toStringAsFixed(0)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建迷你趋势图表
  Widget _buildMiniTrendChart(BuildContext context, ThemeData theme, List<Transaction> transactions) {
    // 计算每日支出
    final expenseByDay = <String, double>{};

    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        final key = '${tx.date.year}-${tx.date.month}-${tx.date.day}';
        expenseByDay[key] = (expenseByDay[key] ?? 0) + tx.amount;
      }
    }

    if (expenseByDay.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: theme.hintColor),
              const SizedBox(height: 8),
              Text('暂无消费数据', style: TextStyle(color: theme.hintColor)),
            ],
          ),
        ),
      );
    }

    // 按日期排序
    final sortedEntries = expenseByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // 准备图表数据点
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedEntries[i].value));
    }

    // 计算最大值用于Y轴
    final maxY = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 100,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: maxY > 0 ? maxY / 4 : 100,
                getTitlesWidget: (value, meta) {
                  if (value < 0) return const SizedBox.shrink();
                  return Text(
                    value >= 1000
                        ? '${(value / 1000).toStringAsFixed(1)}k'
                        : '${value.toInt()}',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (sortedEntries.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedEntries.length) {
                    return const SizedBox.shrink();
                  }
                  // 解析日期 "2024-1-25"
                  final dateKey = sortedEntries[index].key;
                  final parts = dateKey.split('-');
                  if (parts.length != 3) return const SizedBox.shrink();

                  return Text(
                    '${parts[1]}/${parts[2]}',
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: theme.colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: spots.length <= 7),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < 0 || index >= sortedEntries.length) return null;
                  final dateKey = sortedEntries[index].key;
                  final parts = dateKey.split('-');
                  if (parts.length != 3) return null;

                  return LineTooltipItem(
                    '${parts[1]}/${parts[2]}\n¥${spot.y.toStringAsFixed(0)}',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsRow(BuildContext context, ThemeData theme,
      List<Transaction> transactions) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    final days = DateTime.now().day;
    // 修复：添加days > 0检查，避免除零
    final dailyAvg = expenses.isEmpty || days <= 0 ? 0.0 :
        expenses.fold<double>(0, (sum, t) => sum + t.amount) / days;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_today,
            label: '日均支出',
            value: '¥${dailyAvg.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.arrow_upward,
            label: '最高单日',
            value: '¥${_getMaxDaily(expenses).toStringAsFixed(0)}',
          ),
        ),
      ],
    );
  }

  double _getMaxDaily(List<Transaction> expenses) {
    if (expenses.isEmpty) return 0;
    final dailyTotals = <String, double>{};
    for (final t in expenses) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      dailyTotals[key] = (dailyTotals[key] ?? 0) + t.amount;
    }
    return dailyTotals.values.isEmpty ? 0 : dailyTotals.values.reduce((a, b) => a > b ? a : b);
  }

  Widget _buildQuickAccess(BuildContext context, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快捷分析', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAccessItem(
                    icon: Icons.grid_on,
                    label: '消费热力图',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExpenseHeatmapPage()),
                    ),
                  ),
                ),
                Expanded(
                  child: _QuickAccessItem(
                    icon: Icons.zoom_in,
                    label: '趋势下钻',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TrendDrillPage(dateRange: _getDateRange())),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategories(BuildContext context, ThemeData theme,
      List<Transaction> transactions) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    final categoryTotals = <String, double>{};
    for (final t in expenses) {
      // 跳过转账和无效分类
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;
      final category = DefaultCategories.findById(t.category);
      if (category == null || !category.isExpense) continue;

      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TOP分类', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...top5.map((e) => _CategoryItem(
              category: e.key,
              amount: e.value,
              total: expenses.fold<double>(0, (sum, t) => sum + t.amount),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DrillDownNavigationPage(
                    categoryId: e.key,
                    dateRange: _getDateRange(),
                    timeRangeLabel: _getPeriodLabel(),
                  ),
                ),
              ),
            )),
            if (top5.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('暂无数据', style: TextStyle(color: theme.hintColor)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== Tab 2: 分类分析 ====================

class _CategoryAnalysisTab extends ConsumerWidget {
  final int selectedPeriod;

  const _CategoryAnalysisTab({required this.selectedPeriod});

  /// 根据选中的周期获取日期范围
  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case 0: // 本月
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case 1: // 上月
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: lastMonth, end: lastMonthEnd);
      case 2: // 近3月
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: now,
        );
      case 3: // 今年
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    }
  }

  /// 获取周期标签
  String _getPeriodLabel() {
    const periods = ['本月', '上月', '近3月', '今年'];
    return periods[selectedPeriod];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionProvider);

    // 根据选中的周期过滤交易
    final range = _getDateRange();
    final transactions = allTransactions.where((t) {
      return t.date.isAfter(range.start.subtract(const Duration(days: 1))) &&
             t.date.isBefore(range.end.add(const Duration(days: 1)));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 分类饼图卡片
        _buildPieChartCard(context, theme, transactions),
        const SizedBox(height: 16),

        // 快捷入口
        _buildQuickAccess(context, theme),
        const SizedBox(height: 16),

        // 分类列表
        _buildCategoryList(context, theme, transactions),
      ],
    );
  }

  Widget _buildPieChartCard(BuildContext context, ThemeData theme,
      List<Transaction> transactions) {
    // 计算分类统计数据
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    final categoryTotals = <String, double>{};
    for (final t in expenses) {
      // 跳过转账和无效分类
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;
      final category = DefaultCategories.findById(t.category);
      if (category == null || !category.isExpense) continue;

      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }
    final totalExpense = categoryTotals.values.fold<double>(0, (sum, v) => sum + v);
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 只取前5个分类
    final top5Categories = sortedCategories.take(5).toList();

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CategoryPieDrillPage()),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('分类占比', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 16, color: theme.hintColor),
                ],
              ),
              const SizedBox(height: 16),
              _buildMiniPieChart(context, theme, top5Categories, totalExpense),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建迷你饼图
  Widget _buildMiniPieChart(BuildContext context, ThemeData theme,
      List<MapEntry<String, double>> categories, double totalExpense) {
    if (categories.isEmpty || totalExpense == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart, size: 48, color: theme.hintColor),
              const SizedBox(height: 8),
              Text('暂无消费数据', style: TextStyle(color: theme.hintColor)),
            ],
          ),
        ),
      );
    }

    // 分类颜色
    final colors = [
      const Color(0xFFFF7043),
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFFAB47BC),
      const Color(0xFFFFCA28),
    ];

    // 生成饼图扇区数据
    final sections = categories.asMap().entries.map((entry) {
      final index = entry.key;
      final categoryEntry = entry.value;
      final percentage = (categoryEntry.value / totalExpense * 100);

      return PieChartSectionData(
        value: categoryEntry.value,
        color: colors[index % colors.length],
        radius: 60,
        showTitle: percentage >= 5,
        title: '${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 饼图
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 50,
                    sectionsSpace: 2,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '总支出',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor,
                      ),
                    ),
                    Text(
                      '¥${totalExpense.toStringAsFixed(0)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 图例
          _buildPieLegend(context, theme, categories, colors, totalExpense),
        ],
      ),
    );
  }

  /// 构建饼图图例
  Widget _buildPieLegend(BuildContext context, ThemeData theme,
      List<MapEntry<String, double>> categories,
      List<Color> colors,
      double totalExpense) {
    final locService = CategoryLocalizationService.instance;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final categoryEntry = entry.value;
        final percentage = (categoryEntry.value / totalExpense * 100);
        final categoryName = locService.getCategoryName(categoryEntry.key);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$categoryName ${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildQuickAccess(BuildContext context, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('分类工具', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAccessItem(
                    icon: Icons.local_offer,
                    label: '标签统计',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TagStatisticsPage()),
                    ),
                  ),
                ),
                Expanded(
                  child: _QuickAccessItem(
                    icon: Icons.category,
                    label: '消费分类洞察',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WantsNeedsInsightPage()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, ThemeData theme,
      List<Transaction> transactions) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    final categoryTotals = <String, double>{};
    for (final t in expenses) {
      // 跳过转账和无效分类
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;
      final category = DefaultCategories.findById(t.category);
      if (category == null || !category.isExpense) continue;

      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = categoryTotals.values.fold<double>(0, (sum, v) => sum + v);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('全部分类', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...sorted.map((e) => _CategoryItem(
              category: e.key,
              amount: e.value,
              total: total,
              showPercentage: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DrillDownNavigationPage(
                    categoryId: e.key,
                    dateRange: _getDateRange(),
                    timeRangeLabel: _getPeriodLabel(),
                  ),
                ),
              ),
            )),
            if (sorted.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('暂无数据', style: TextStyle(color: theme.hintColor)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== Tab 3: 统计对比 ====================

class _ComparisonTab extends ConsumerWidget {
  final int selectedPeriod;

  const _ComparisonTab({required this.selectedPeriod});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ledgerContext = ref.watch(ledgerContextProvider);
    final currentLedger = ledgerContext.currentLedger;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 同环比分析入口
        _buildComparisonCard(
          context, theme,
          icon: Icons.compare_arrows,
          title: '期间对比',
          subtitle: '同比、环比分析，查看消费变化趋势',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PeriodComparisonPage()),
          ),
        ),
        const SizedBox(height: 12),

        // 成员对比入口
        _buildComparisonCard(
          context, theme,
          icon: Icons.people,
          title: '成员对比',
          subtitle: currentLedger != null ? '家庭成员消费对比分析' : '需要先加入家庭账本',
          enabled: currentLedger != null,
          onTap: () {
            if (currentLedger != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MemberComparisonPage(
                  ledgerId: currentLedger.id,
                  ledgerName: currentLedger.name,
                )),
              );
            }
          },
        ),
        const SizedBox(height: 12),

        // 同类对比入口
        _buildComparisonCard(
          context, theme,
          icon: Icons.groups,
          title: '同类用户对比',
          subtitle: '与相似用户匿名对比，了解消费水平',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PeerComparisonPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCard(BuildContext context, ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: enabled
              ? theme.colorScheme.primaryContainer
              : theme.disabledColor.withAlpha(30),
          child: Icon(icon, color: enabled
              ? theme.colorScheme.primary
              : theme.disabledColor),
        ),
        title: Text(title, style: TextStyle(
          color: enabled ? null : theme.disabledColor,
        )),
        subtitle: Text(subtitle),
        trailing: enabled
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

// ==================== Tab 4: 报告中心 ====================

class _ReportCenterTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReportSection(context, theme, '定期报告', [
          _ReportItem(
            icon: Icons.calendar_month,
            title: '月度报告',
            subtitle: '本月财务总结与分析',
            page: const MonthlyReportPage(),
          ),
          _ReportItem(
            icon: Icons.calendar_today,
            title: '年度报告',
            subtitle: '全年财务回顾与展望',
            page: const AnnualReportPage(),
          ),
          _ReportItem(
            icon: Icons.summarize,
            title: '年度总结',
            subtitle: '年度数据汇总与亮点',
            page: const AnnualSummaryPage(),
          ),
        ]),
        const SizedBox(height: 16),

        _buildReportSection(context, theme, '专项报告', [
          _ReportItem(
            icon: Icons.account_balance_wallet,
            title: '预算报告',
            subtitle: '预算执行情况分析',
            page: const BudgetReportPage(),
          ),
          _ReportItem(
            icon: Icons.tune,
            title: '自定义报告',
            subtitle: '按需定制分析报告',
            page: const CustomReportPage(),
          ),
        ]),
        const SizedBox(height: 16),

        // 家庭报告 - 需要先选择家庭账本
        _buildFamilyReportSection(context, theme),
      ],
    );
  }

  Widget _buildReportSection(BuildContext context, ThemeData theme,
      String title, List<_ReportItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(item.icon, color: theme.colorScheme.secondary, size: 20),
              ),
              title: Text(item.title),
              subtitle: Text(item.subtitle, style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => item.page),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyReportSection(BuildContext context, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('家庭报告', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.tertiaryContainer,
                child: Icon(Icons.family_restroom, color: theme.colorScheme.tertiary, size: 20),
              ),
              title: const Text('家庭年度回顾'),
              subtitle: Text('家庭成员消费对比与总结', style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // 显示选择家庭和年份的对话框
                _showFamilyReportDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFamilyReportDialog(BuildContext context) {
    final currentYear = DateTime.now().year;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('家庭年度回顾'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请先在设置中创建或加入家庭账本，然后即可生成家庭年度回顾报告。'),
            const SizedBox(height: 16),
            Text('将生成 $currentYear 年的回顾报告',
              style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _ReportItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  _ReportItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });
}

// ==================== Tab 5: 洞察发现 ====================

class _InsightTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 拿铁因子
        _buildInsightCard(
          context, theme,
          icon: Icons.coffee,
          title: '拿铁因子',
          subtitle: '发现隐藏的小额高频消费',
          color: Colors.brown,
          page: const LatteFactorPage(),
        ),
        const SizedBox(height: 12),

        // 订阅支出
        _buildInsightCard(
          context, theme,
          icon: Icons.subscriptions,
          title: '订阅支出',
          subtitle: '检测闲置订阅，减少浪费',
          color: Colors.deepPurple,
          page: const SubscriptionWastePage(),
        ),
        const SizedBox(height: 12),

        // 消费习惯
        _buildInsightCard(
          context, theme,
          icon: Icons.insights,
          title: '消费习惯',
          subtitle: '分析消费模式与行为趋势',
          color: Colors.orange,
          page: const TrendsPage(),
        ),
        const SizedBox(height: 12),

        // 预算执行
        _buildInsightCard(
          context, theme,
          icon: Icons.account_balance_wallet,
          title: '预算执行',
          subtitle: '零基预算小金库使用情况',
          color: Colors.teal,
          page: const VaultOverviewPage(),
        ),
        const SizedBox(height: 12),

        // 消费趋势预测
        _buildInsightCard(
          context, theme,
          icon: Icons.timeline,
          title: '消费趋势预测',
          subtitle: 'AI预测未来消费走势',
          color: Colors.blue,
          page: const SpendingPredictionPage(),
        ),
        const SizedBox(height: 12),

        // 可行建议
        _buildInsightCard(
          context, theme,
          icon: Icons.tips_and_updates,
          title: '可行建议',
          subtitle: '个性化理财优化建议',
          color: Colors.green,
          page: const ActionableAdvicePage(),
        ),
      ],
    );
  }

  Widget _buildInsightCard(BuildContext context, ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget page,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ),
      ),
    );
  }
}

// ==================== Tab 6: 专项分析 ====================

class _SpecialAnalysisTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 钱龄分析
        _buildAnalysisSection(context, theme, '钱龄分析', Icons.monetization_on, Colors.amber, [
          _AnalysisItem(title: '钱龄详情', page: const MoneyAgePage()),
          _AnalysisItem(title: '影响因素', page: const MoneyAgeInfluencePage()),
          _AnalysisItem(title: '钱龄进阶', page: const MoneyAgeProgressPage()),
          _AnalysisItem(title: 'FIFO资源池', page: const MoneyAgeResourcePoolPage()),
        ]),
        const SizedBox(height: 16),

        // 健康评估
        _buildAnalysisSection(context, theme, '健康评估', Icons.favorite, Colors.red, [
          _AnalysisItem(title: '财务健康仪表盘', page: const FinancialHealthDashboardPage()),
          _AnalysisItem(title: '目标达成', page: const GoalAchievementDashboardPage()),
          _AnalysisItem(title: '预算健康', page: const BudgetHealthPage()),
          _AnalysisItem(title: '小金库健康', page: const VaultHealthPage()),
        ]),
        const SizedBox(height: 16),

        // 其他专项
        _buildAnalysisSection(context, theme, '更多分析', Icons.analytics, Colors.indigo, [
          _AnalysisItem(title: '我的画像', page: const UserProfileVisualizationPage()),
          _AnalysisItem(title: '位置分析', page: const LocationAnalysisPage()),
          _AnalysisItem(title: '资产概览', page: const AssetOverviewPage()),
          _AnalysisItem(title: 'AI学习报告', page: const AILearningReportPage()),
          _AnalysisItem(title: 'AI学习曲线', page: const AILearningCurvePage()),
          _AnalysisItem(title: '家庭排行榜', page: const FamilyLeaderboardPage()),
        ]),
      ],
    );
  }

  Widget _buildAnalysisSection(BuildContext context, ThemeData theme,
      String title, IconData icon, Color color, List<_AnalysisItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) => ActionChip(
                label: Text(item.title),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => item.page),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisItem {
  final String title;
  final Widget page;

  _AnalysisItem({required this.title, required this.page});
}

// ==================== 通用组件 ====================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: theme.hintColor),
                const SizedBox(width: 4),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            )),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String category;
  final double amount;
  final double total;
  final bool showPercentage;
  final VoidCallback? onTap;

  const _CategoryItem({
    required this.category,
    required this.amount,
    required this.total,
    this.showPercentage = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = total > 0 ? (amount / total * 100) : 0.0;
    final categoryData = DefaultCategories.findById(category);
    final categoryColor = categoryData?.color ?? theme.colorScheme.primary;
    final categoryIcon = categoryData?.icon ?? Icons.category;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: categoryColor.withAlpha(30),
        child: Icon(
          categoryIcon,
          color: categoryColor,
          size: 20,
        ),
      ),
      title: Text(categoryData?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(category)),
      subtitle: showPercentage
        ? LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          )
        : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('¥${amount.toStringAsFixed(0)}', style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
          if (showPercentage)
            Text('${percentage.toStringAsFixed(1)}%', style: theme.textTheme.bodySmall),
        ],
      ),
      onTap: onTap,
    );
  }
}
