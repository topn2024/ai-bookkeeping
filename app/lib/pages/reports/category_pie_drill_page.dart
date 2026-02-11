import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../extensions/category_extensions.dart';
import '../../services/category_localization_service.dart';
import 'drill_navigation_page.dart';

/// 分类饼图下钻页面
/// 原型设计 7.05：分类饼图下钻
/// - 时间选择器（本月、上月、近3月、今年）
/// - 环形图显示总支出
/// - 点击扇区可下钻查看详情
/// - 分类列表（可点击下钻）
class CategoryPieDrillPage extends ConsumerStatefulWidget {
  const CategoryPieDrillPage({super.key});

  @override
  ConsumerState<CategoryPieDrillPage> createState() => _CategoryPieDrillPageState();
}

class _CategoryPieDrillPageState extends ConsumerState<CategoryPieDrillPage> {
  int _selectedPeriod = 0;
  final List<String> _periods = ['本月', '上月', '近3月', '今年'];

  /// 获取当前选择周期的日期范围
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

  /// 根据日期范围过滤交易
  List<Transaction> _filterTransactionsByPeriod(List<Transaction> transactions) {
    final range = _getDateRange();
    return transactions.where((t) {
      return t.date.isAfter(range.start.subtract(const Duration(days: 1))) &&
          t.date.isBefore(range.end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionProvider);

    // 先按周期过滤，再过滤支出交易
    final filteredTransactions = _filterTransactionsByPeriod(allTransactions);
    final expenseTransactions = filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    // 按分类汇总（排除转账和无效分类）
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};
    for (final t in expenseTransactions) {
      // 跳过转账类型（这些交易不应该在支出分析中）
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;

      // 确保分类在定义中存在
      final category = DefaultCategories.findById(t.category);
      if (category == null || !category.isExpense) continue;

      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
      categoryCounts[t.category] = (categoryCounts[t.category] ?? 0) + 1;
    }

    final totalExpense = expenseTransactions.fold<double>(0, (sum, t) => sum + t.amount);

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            _buildPeriodSelector(theme),
            _buildPieChart(theme, sortedCategories, totalExpense),
            Expanded(
              child: _buildCategoryList(theme, sortedCategories, categoryCounts, totalExpense),
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
              '支出分析',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _showFilterOptions(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.filter_list,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 时间选择器
  Widget _buildPeriodSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _periods[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 环形图 - 使用真实数据
  Widget _buildPieChart(
    ThemeData theme,
    List<MapEntry<String, double>> categories,
    double totalExpense,
  ) {
    // 分类颜色
    final colors = [
      const Color(0xFFFF7043),
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFFAB47BC),
      const Color(0xFFFFCA28),
      const Color(0xFF26A69A),
      const Color(0xFFEC407A),
      const Color(0xFF5C6BC0),
    ];

    // 生成饼图扇区数据
    final sections = categories.isEmpty
        ? [
            PieChartSectionData(
              value: 1,
              color: theme.colorScheme.surfaceContainerHighest,
              radius: 24,
              showTitle: false,
            ),
          ]
        : categories.asMap().entries.map((entry) {
            final index = entry.key;
            final categoryEntry = entry.value;
            final percentage = totalExpense > 0
                ? (categoryEntry.value / totalExpense * 100)
                : 0.0;

            return PieChartSectionData(
              value: categoryEntry.value,
              color: colors[index % colors.length],
              radius: 24,
              showTitle: percentage >= 5, // 只显示占比>=5%的标签
              title: '${percentage.toStringAsFixed(0)}%',
              titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                          final index = pieTouchResponse!
                              .touchedSection!.touchedSectionIndex;
                          if (index >= 0 && index < categories.length) {
                            _drillDownCategory(
                              context,
                              categories[index].key,
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
          // 图例（只显示前5个）
          if (categories.isNotEmpty)
            _buildPieLegend(theme, categories.take(5).toList(), colors, totalExpense),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                categories.isEmpty ? '暂无支出数据' : '点击扇区查看详情',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建饼图图例
  Widget _buildPieLegend(
    ThemeData theme,
    List<MapEntry<String, double>> categories,
    List<Color> colors,
    double totalExpense,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final categoryEntry = entry.value;
        final category = DefaultCategories.findById(categoryEntry.key);
        final percentage = totalExpense > 0
            ? (categoryEntry.value / totalExpense * 100)
            : 0.0;

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
              '${category?.localizedName ?? '未知'} ${percentage.toStringAsFixed(0)}%',
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

  /// 分类列表
  Widget _buildCategoryList(
    ThemeData theme,
    List<MapEntry<String, double>> categories,
    Map<String, int> counts,
    double totalExpense,
  ) {
    // 分类颜色映射
    final colors = [
      const Color(0xFFFF7043),
      const Color(0xFF87CEFA),
      const Color(0xFF66BB6A),
      const Color(0xFFAB47BC),
      const Color(0xFFFFCA28),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final entry = categories[index];
        final category = DefaultCategories.findById(entry.key);
        final count = counts[entry.key] ?? 0;
        final percentage = totalExpense > 0
            ? (entry.value / totalExpense * 100).toStringAsFixed(1)
            : '0.0';
        final color = colors[index % colors.length];

        return GestureDetector(
          onTap: () => _drillDownCategory(context, entry.key),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
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
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(entry.key),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
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
                      '¥${entry.value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
      },
    );
  }

  void _showFilterOptions(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打开筛选选项...')),
    );
  }

  void _drillDownCategory(BuildContext context, String categoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownNavigationPage(
          categoryId: categoryId,
          dateRange: _getDateRange(),
          timeRangeLabel: _periods[_selectedPeriod],
        ),
      ),
    );
  }
}
