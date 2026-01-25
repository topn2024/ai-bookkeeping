import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../providers/transaction_provider.dart';
import '../../extensions/category_extensions.dart';
import '../transaction_detail_page.dart';

/// 趋势图下钻页面
/// 原型设计 7.06：趋势图下钻
/// - 数据概览（日均支出、最高日、最低日）
/// - 折线图区域（可点击数据点）
/// - 选中日期的交易列表
class TrendDrillPage extends ConsumerStatefulWidget {
  /// 日期范围，为 null 时显示所有数据
  final DateTimeRange? dateRange;

  const TrendDrillPage({
    super.key,
    this.dateRange,
  });

  @override
  ConsumerState<TrendDrillPage> createState() => _TrendDrillPageState();
}

class _TrendDrillPageState extends ConsumerState<TrendDrillPage> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionProvider);

    // 根据日期范围过滤交易
    final filteredTransactions = widget.dateRange != null
        ? allTransactions.where((t) =>
            !t.date.isBefore(widget.dateRange!.start) &&
            !t.date.isAfter(widget.dateRange!.end))
        .toList()
        : allTransactions;

    // 计算统计数据
    final expenseTransactions = filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    final dailyTotals = <DateTime, double>{};
    for (final t in expenseTransactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      dailyTotals[day] = (dailyTotals[day] ?? 0) + t.amount;
    }

    final totalExpense = expenseTransactions.fold<double>(0, (sum, t) => sum + t.amount);
    final dayCount = dailyTotals.length;
    final dailyAvg = dayCount > 0 ? totalExpense / dayCount : 0.0;
    final maxDaily = dailyTotals.values.isEmpty
        ? 0.0
        : dailyTotals.values.reduce((a, b) => a > b ? a : b);
    final minDaily = dailyTotals.values.isEmpty
        ? 0.0
        : dailyTotals.values.reduce((a, b) => a < b ? a : b);

    // 获取选中日期的交易
    final selectedTransactions = _selectedDate != null
        ? expenseTransactions.where((t) =>
            t.date.year == _selectedDate!.year &&
            t.date.month == _selectedDate!.month &&
            t.date.day == _selectedDate!.day).toList()
        : <Transaction>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            _buildDataOverview(theme, dailyAvg, maxDaily, minDaily),
            _buildChartArea(theme, dailyTotals),
            if (_selectedDate != null)
              Expanded(
                child: _buildTransactionList(theme, selectedTransactions),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    '点击数据点查看当日交易',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
              '消费趋势',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _selectDateRange(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.date_range,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 数据概览
  Widget _buildDataOverview(
    ThemeData theme,
    double dailyAvg,
    double maxDaily,
    double minDaily,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildOverviewItem(theme, '日均支出', '¥${dailyAvg.toStringAsFixed(0)}', null),
          Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
          _buildOverviewItem(theme, '最高日', '¥${maxDaily.toStringAsFixed(0)}', Colors.red),
          Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
          _buildOverviewItem(theme, '最低日', '¥${minDaily.toStringAsFixed(0)}', Colors.green),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(ThemeData theme, String label, String value, Color? color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// 折线图区域 - 使用真实数据
  Widget _buildChartArea(ThemeData theme, Map<DateTime, double> dailyTotals) {
    // 按日期排序
    final sortedDays = dailyTotals.keys.toList()..sort();

    if (sortedDays.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        height: 200,
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
        child: Center(
          child: Text(
            '暂无支出数据',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // 生成折线图数据点
    final spots = sortedDays.asMap().entries.map((entry) {
      final index = entry.key;
      final date = entry.value;
      return FlSpot(index.toDouble(), dailyTotals[date] ?? 0);
    }).toList();

    // 计算Y轴最大值
    final maxY = dailyTotals.values.isEmpty
        ? 100.0
        : dailyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      height: 220,
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
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isSelected = _selectedDate != null &&
                            index < sortedDays.length &&
                            sortedDays[index].year == _selectedDate!.year &&
                            sortedDays[index].month == _selectedDate!.month &&
                            sortedDays[index].day == _selectedDate!.day;
                        return FlDotCirclePainter(
                          radius: isSelected ? 6 : 4,
                          color: isSelected
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedDays.length) {
                          return const SizedBox.shrink();
                        }
                        // 只显示部分日期
                        if (sortedDays.length <= 7 ||
                            index == 0 ||
                            index == sortedDays.length - 1 ||
                            index % (sortedDays.length ~/ 5) == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('M/d').format(sortedDays[index]),
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 22,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: maxY / 4,
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
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (event is FlTapUpEvent &&
                        response?.lineBarSpots != null &&
                        response!.lineBarSpots!.isNotEmpty) {
                      final spotIndex = response.lineBarSpots!.first.spotIndex;
                      if (spotIndex >= 0 && spotIndex < sortedDays.length) {
                        setState(() {
                          _selectedDate = sortedDays[spotIndex];
                        });
                      }
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final index = spot.spotIndex;
                        if (index < 0 || index >= sortedDays.length) {
                          return null;
                        }
                        return LineTooltipItem(
                          '${DateFormat('M月d日').format(sortedDays[index])}\n¥${spot.y.toStringAsFixed(0)}',
                          TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: 0,
                maxY: maxY,
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                '点击数据点查看当日交易',
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

  /// 选中日期的交易列表
  Widget _buildTransactionList(ThemeData theme, List<Transaction> transactions) {
    final dateStr = _selectedDate != null
        ? DateFormat('M月d日').format(_selectedDate!)
        : '';
    final totalAmount = transactions.fold<double>(0, (sum, t) => sum + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dateStr 交易明细',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${transactions.length}笔 · ¥${totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: transactions.isEmpty
              ? Center(
                  child: Text(
                    '当日无交易记录',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final category = DefaultCategories.findById(t.category);
                    return _buildTransactionItem(context, theme, t, category);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(BuildContext context, ThemeData theme, Transaction t, Category? category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(transaction: t),
          ),
        );
      },
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
              color: category?.color ?? Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              category?.icon ?? Icons.help_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.note ?? category?.localizedName ?? t.category,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${category?.localizedName ?? t.category} · ${DateFormat('HH:mm').format(t.date)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-¥${t.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _selectDateRange(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('选择日期范围...')),
    );
  }
}
