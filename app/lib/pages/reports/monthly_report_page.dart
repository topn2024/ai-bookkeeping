import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../providers/transaction_provider.dart';
import '../../extensions/category_extensions.dart';
import '../category_detail_page.dart';

/// 月度报告页面
/// 原型设计 7.01：月度报告
/// - 收支汇总卡片（收入、支出、结余）
/// - 日消费趋势图
/// - 支出分类列表
/// - 钱龄表现卡片
class MonthlyReportPage extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const MonthlyReportPage({super.key, this.initialDate});

  @override
  ConsumerState<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends ConsumerState<MonthlyReportPage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final monthTransactions = _filterByMonth(transactions);

    final totalIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpense = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final balance = totalIncome - totalExpense;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSummaryCard(theme, totalIncome, totalExpense, balance),
                    _buildTrendChart(theme, monthTransactions),
                    _buildCategoryBreakdown(theme, monthTransactions),
                    _buildMoneyAgeCard(theme, monthTransactions),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Transaction> _filterByMonth(List<Transaction> transactions) {
    return transactions.where((t) =>
        t.date.year == _selectedMonth.year &&
        t.date.month == _selectedMonth.month).toList();
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
          Expanded(
            child: GestureDetector(
              onTap: () => _selectMonth(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('M月财务报告').format(_selectedMonth),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _shareReport(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.share,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 收支汇总卡片
  Widget _buildSummaryCard(
    ThemeData theme,
    double income,
    double expense,
    double balance,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('收入', income),
          _buildSummaryItem('支出', expense),
          _buildSummaryItem('结余', balance),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¥${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 日消费趋势图 - 使用真实数据
  Widget _buildTrendChart(ThemeData theme, List<Transaction> transactions) {
    // 按日期汇总支出
    final expenseByDay = <int, double>{};
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    // 初始化所有日期为0
    for (int i = 1; i <= daysInMonth; i++) {
      expenseByDay[i] = 0;
    }

    // 汇总每日支出
    for (final t in transactions.where((t) => t.type == TransactionType.expense)) {
      expenseByDay[t.date.day] = (expenseByDay[t.date.day] ?? 0) + t.amount;
    }

    // 找出最大值用于Y轴
    final maxExpense = expenseByDay.values.isEmpty
        ? 100.0
        : expenseByDay.values.reduce((a, b) => a > b ? a : b);
    final yMax = maxExpense > 0 ? maxExpense * 1.2 : 100.0;

    // 生成柱状图数据
    final barGroups = expenseByDay.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: theme.colorScheme.primary,
            width: daysInMonth > 20 ? 6 : 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      height: 180,
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
            '日消费趋势',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: expenseByDay.values.every((v) => v == 0)
                ? Center(
                    child: Text(
                      '本月暂无支出记录',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: yMax,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${group.x}日\n¥${rod.toY.toStringAsFixed(0)}',
                              TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // 只显示部分日期标签
                              if (value.toInt() % 5 == 1 || value.toInt() == daysInMonth) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${value.toInt()}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            reservedSize: 20,
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups: barGroups,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 支出分类列表
  Widget _buildCategoryBreakdown(ThemeData theme, List<Transaction> transactions) {
    final expenseTransactions = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    final categoryTotals = <String, double>{};
    for (final t in expenseTransactions) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = expenseTransactions.fold<double>(0, (sum, t) => sum + t.amount);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '支出分类',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedCategories.take(5).map((entry) {
            final category = DefaultCategories.findById(entry.key);
            final percentage = totalExpense > 0
                ? (entry.value / totalExpense * 100).toStringAsFixed(1)
                : '0.0';
            return _buildCategoryItem(
              context,
              theme,
              entry.key,
              category?.icon ?? Icons.help_outline,
              category?.color ?? Colors.grey,
              category?.localizedName ?? entry.key,
              entry.value,
              percentage,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    ThemeData theme,
    String categoryId,
    IconData icon,
    Color color,
    String name,
    double amount,
    String percentage,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryDetailPage(categoryId: categoryId),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
        ),
      ),
    );
  }

  /// 钱龄表现卡片 - 使用真实数据
  /// 钱龄：从收入到支出的平均时间差
  Widget _buildMoneyAgeCard(ThemeData theme, List<Transaction> transactions) {
    // 计算本月平均钱龄
    // 简化算法：用月初到每笔支出的天数的平均值
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final expenseTransactions = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    double avgMoneyAge = 0;
    if (expenseTransactions.isNotEmpty) {
      final totalDays = expenseTransactions.fold<int>(0, (sum, t) {
        return sum + t.date.difference(monthStart).inDays;
      });
      avgMoneyAge = totalDays / expenseTransactions.length;
    }

    final moneyAgeDays = avgMoneyAge.round();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                '钱龄表现',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('月均钱龄'),
              Text(
                expenseTransactions.isEmpty ? '--' : '$moneyAgeDays天',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('支出笔数'),
              Text(
                '${expenseTransactions.length}笔',
                style: TextStyle(color: Colors.green[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _shareReport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享报告...')),
    );
  }
}
