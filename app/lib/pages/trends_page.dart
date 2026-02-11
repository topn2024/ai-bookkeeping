import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';
import '../services/spending_insight_calculator.dart';
import 'reports/trend_drill_page.dart';
import 'reports/drill_navigation_page.dart';

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

  /// 根据选中的周期获取日期范围
  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
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
    return periods[_selectedPeriod];
  }

  /// 过滤指定周期的交易
  List<Transaction> _filterTransactionsByPeriod(List<Transaction> transactions) {
    final range = _getDateRange();
    return transactions.where((t) {
      return !t.date.isBefore(range.start) && !t.date.isAfter(range.end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionProvider);
    final transactions = _filterTransactionsByPeriod(allTransactions);
    final budgets = ref.watch(budgetProvider);

    // 计算过滤后的支出总额
    final periodExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

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
                  _buildTrendContent(context, theme, transactions, periodExpense),
                  _buildCategoryContent(context, theme, transactions),
                  _buildInsightContent(context, theme, transactions, allTransactions, budgets),
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
    double periodExpense,
  ) {
    // 计算周期天数
    final range = _getDateRange();
    final dayCount = range.end.difference(range.start).inDays + 1;
    final dailyAvg = dayCount > 0 ? periodExpense / dayCount : 0.0;

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
          // 消费趋势折线图
          _buildTrendChart(context, theme, expenseByDay),
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

  /// 消费趋势折线图
  Widget _buildTrendChart(
    BuildContext context,
    ThemeData theme,
    Map<String, double> expenseByDay,
  ) {
    // 按日期排序
    final sortedEntries = expenseByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedEntries.isEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TrendDrillPage(dateRange: _getDateRange())),
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
                  '暂无消费数据',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 准备图表数据点
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedEntries[i].value));
    }

    // 计算最大值用于Y轴
    final maxY = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final yMax = maxY > 0 ? maxY * 1.2 : 100.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TrendDrillPage(dateRange: _getDateRange())),
      ),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yMax / 4,
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
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(
                      '¥${value.toInt()}',
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
                  reservedSize: 22,
                  interval: sortedEntries.length > 7 ? (sortedEntries.length / 5).ceil().toDouble() : 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= sortedEntries.length) {
                      return const SizedBox.shrink();
                    }
                    // 提取日期的日部分
                    final dateParts = sortedEntries[index].key.split('-');
                    final day = dateParts.length >= 3 ? dateParts[2] : '';
                    return Text(
                      day,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (sortedEntries.length - 1).toDouble(),
            minY: 0,
            maxY: yMax,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: theme.colorScheme.primary,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: sortedEntries.length <= 15,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: theme.colorScheme.primary,
                      strokeWidth: 1,
                      strokeColor: theme.colorScheme.surface,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) => theme.colorScheme.inverseSurface,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    final date = index < sortedEntries.length ? sortedEntries[index].key : '';
                    return LineTooltipItem(
                      '$date\n¥${spot.y.toStringAsFixed(0)}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
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
                builder: (context) => DrillDownNavigationPage(
                  categoryId: entry.key,
                  dateRange: _getDateRange(),
                  timeRangeLabel: _getPeriodLabel(),
                ),
              ),
            ),
            child: _buildCategoryItem(
              context,
              theme,
              icon: category?.icon ?? Icons.help_outline,
              iconColor: category?.color ?? Colors.grey,
              name: category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(entry.key),
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

  /// 分类占比颜色
  static const _pieColors = [
    Color(0xFFFF7043),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFFFCA28),
    Color(0xFF26A69A),
    Color(0xFFEC407A),
    Color(0xFF5C6BC0),
  ];

  /// 分类占比内容
  Widget _buildCategoryContent(
    BuildContext context,
    ThemeData theme,
    List<Transaction> transactions,
  ) {
    // 按分类汇总支出
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      if (t.category == 'transfer') continue;
      final category = DefaultCategories.findById(t.category);
      if (category == null || !category.isExpense) continue;
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
      categoryCounts[t.category] = (categoryCounts[t.category] ?? 0) + 1;
    }
    final totalExpense = categoryTotals.values.fold<double>(0, (a, b) => a + b);
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 饼图扇区
    final sections = sortedCategories.isEmpty
        ? [
            PieChartSectionData(
              value: 1,
              color: theme.colorScheme.surfaceContainerHighest,
              radius: 24,
              showTitle: false,
            ),
          ]
        : sortedCategories.asMap().entries.map((entry) {
            final index = entry.key;
            final catEntry = entry.value;
            final pct = totalExpense > 0 ? catEntry.value / totalExpense * 100 : 0.0;
            return PieChartSectionData(
              value: catEntry.value,
              color: _pieColors[index % _pieColors.length],
              radius: 24,
              showTitle: pct >= 5,
              title: '${pct.toStringAsFixed(0)}%',
              titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 环形图
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 70,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlTapUpEvent &&
                            pieTouchResponse?.touchedSection != null) {
                          final idx = pieTouchResponse!
                              .touchedSection!.touchedSectionIndex;
                          if (idx >= 0 && idx < sortedCategories.length) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DrillDownNavigationPage(
                                  categoryId: sortedCategories[idx].key,
                                  dateRange: _getDateRange(),
                                  timeRangeLabel: _getPeriodLabel(),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '总支出',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '¥${totalExpense.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 图例（前5个分类）
          if (sortedCategories.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: sortedCategories.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final catEntry = entry.value;
                final category = DefaultCategories.findById(catEntry.key);
                final pct = totalExpense > 0
                    ? (catEntry.value / totalExpense * 100).toStringAsFixed(0)
                    : '0';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _pieColors[index % _pieColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(catEntry.key)} $pct%',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          if (sortedCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '暂无支出数据',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 24),
          // 分类列表
          ...sortedCategories.asMap().entries.map((entry) {
            final index = entry.key;
            final catEntry = entry.value;
            final category = DefaultCategories.findById(catEntry.key);
            final count = categoryCounts[catEntry.key] ?? 0;
            final pct = totalExpense > 0
                ? (catEntry.value / totalExpense * 100).toStringAsFixed(1)
                : '0.0';

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DrillDownNavigationPage(
                    categoryId: catEntry.key,
                    dateRange: _getDateRange(),
                    timeRangeLabel: _getPeriodLabel(),
                  ),
                ),
              ),
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
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _pieColors[index % _pieColors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (category?.color ?? Colors.grey).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        category?.icon ?? Icons.help_outline,
                        color: category?.color ?? Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(catEntry.key),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${catEntry.value.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.expense,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 洞察内容
  Widget _buildInsightContent(
    BuildContext context,
    ThemeData theme,
    List<Transaction> transactions,
    List<Transaction> allTransactions,
    List<Budget> budgets,
  ) {
    final range = _getDateRange();
    final expenseTx =
        transactions.where((t) => t.type == TransactionType.expense).toList();

    if (expenseTx.isEmpty) {
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
              '暂无消费数据，无法生成洞察',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // 环比变化
    final pop = SpendingInsightCalculator.periodOverPeriodChange(allTransactions, range);

    // 星期消费分布
    final weekdayDist = SpendingInsightCalculator.weekdayDistribution(expenseTx);
    final maxWeekday = weekdayDist.values.reduce((a, b) => a > b ? a : b);
    final weekendPct = (SpendingInsightCalculator.weekendRatio(expenseTx) * 100);

    // 动态洞察
    final insights = SpendingInsightCalculator.generatePeriodInsights(
      transactions,
      allTransactions,
      range,
      budgets,
    );

    const weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 环比变化摘要卡片
          if (pop != null)
            Container(
              width: double.infinity,
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
              child: Row(
                children: [
                  Icon(
                    pop > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    color: pop > 0 ? Colors.red : Colors.green,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '环比变化',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pop > 0 ? "+" : ""}${pop.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: pop > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    pop > 0 ? '支出增长' : '支出下降',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (pop != null) const SizedBox(height: 16),

          // 星期消费分布柱状图
          Container(
            width: double.infinity,
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
                  '星期消费分布',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxWeekday > 0 ? maxWeekday * 1.2 : 100,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${weekdayNames[group.x + 1]}\n¥${rod.toY.toStringAsFixed(0)}',
                              TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt() + 1;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  weekdayNames[idx],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: idx >= 6 ? FontWeight.w600 : FontWeight.normal,
                                    color: idx >= 6
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (i) {
                        final day = i + 1;
                        final isWeekend = day >= 6;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: weekdayDist[day] ?? 0,
                              color: isWeekend
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.4),
                              width: 24,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '周末消费占比 ${weekendPct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 动态洞察卡片列表
          if (insights.isNotEmpty) ...[
            Text(
              '智能洞察',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...insights.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (item.badgeColor ?? theme.colorScheme.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.badgeColor ?? theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (item.badgeText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (item.badgeColor ?? Colors.grey)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.badgeText!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: item.badgeColor ?? Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
