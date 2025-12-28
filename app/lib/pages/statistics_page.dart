import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../models/category.dart';
import '../models/transaction.dart';

enum StatsPeriod { day, week, month, year }

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _touchedIndex = -1;
  StatsPeriod _selectedPeriod = StatsPeriod.month;
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计报表'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '收入'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatsView(transactions, true),
                _buildStatsView(transactions, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: StatsPeriod.values.map((period) {
          final isSelected = _selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(_getPeriodLabel(period)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedPeriod = period;
                    _currentDate = DateTime.now();
                  });
                }
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getPeriodLabel(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.day:
        return '日';
      case StatsPeriod.week:
        return '周';
      case StatsPeriod.month:
        return '月';
      case StatsPeriod.year:
        return '年';
    }
  }

  Widget _buildStatsView(List<Transaction> allTransactions, bool isExpense) {
    final filteredTransactions = _filterTransactionsByPeriod(
      allTransactions.where((t) => isExpense
          ? t.type == TransactionType.expense
          : t.type == TransactionType.income).toList(),
    );

    final total = filteredTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final byCategory = _groupByCategory(filteredTransactions);

    // 计算环比数据
    final prevPeriodTransactions = _getPreviousPeriodTransactions(allTransactions, isExpense);
    final prevTotal = prevPeriodTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final momChange = _calculateChangePercent(total, prevTotal);

    // 计算同比数据
    final yoyPeriodTransactions = _getYoYPeriodTransactions(allTransactions, isExpense);
    final yoyTotal = yoyPeriodTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final yoyChange = _calculateChangePercent(total, yoyTotal);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSummaryHeader(
            total,
            isExpense,
            momChange: momChange,
            yoyChange: _selectedPeriod != StatsPeriod.year ? yoyChange : null,
            prevTotal: prevTotal,
            yoyTotal: yoyTotal,
          ),
          if (filteredTransactions.isNotEmpty) ...[
            _buildComparisonCard(
              isExpense,
              currentTotal: total,
              prevTotal: prevTotal,
              yoyTotal: yoyTotal,
              momChange: momChange,
              yoyChange: yoyChange,
            ),
            _buildTrendChart(allTransactions, isExpense),
            if (byCategory.isNotEmpty) ...[
              _buildPieChart(byCategory),
              _buildCategoryList(byCategory),
            ],
          ] else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
    bool isExpense, {
    required double currentTotal,
    required double prevTotal,
    required double yoyTotal,
    required double momChange,
    required double yoyChange,
  }) {
    final color = isExpense ? AppColors.expense : AppColors.income;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '对比分析',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // 环比
              Expanded(
                child: _buildComparisonItem(
                  label: _getMoMLabel(),
                  currentValue: currentTotal,
                  previousValue: prevTotal,
                  changePercent: momChange,
                  isExpense: isExpense,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppColors.divider,
              ),
              // 同比
              if (_selectedPeriod != StatsPeriod.year)
                Expanded(
                  child: _buildComparisonItem(
                    label: _getYoYLabel(),
                    currentValue: currentTotal,
                    previousValue: yoyTotal,
                    changePercent: yoyChange,
                    isExpense: isExpense,
                  ),
                ),
              if (_selectedPeriod == StatsPeriod.year)
                const Expanded(
                  child: Center(
                    child: Text(
                      '年度视图无同比数据',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem({
    required String label,
    required double currentValue,
    required double previousValue,
    required double changePercent,
    required bool isExpense,
  }) {
    final isIncrease = changePercent > 0;

    // 对于支出，减少是好事；对于收入，增加是好事
    Color changeColor;
    if (changePercent == 0) {
      changeColor = AppColors.textSecondary;
    } else if (isExpense) {
      changeColor = isIncrease ? AppColors.expense : AppColors.income;
    } else {
      changeColor = isIncrease ? AppColors.income : AppColors.expense;
    }

    IconData changeIcon;
    if (changePercent == 0) {
      changeIcon = Icons.remove;
    } else {
      changeIcon = isIncrease ? Icons.arrow_upward : Icons.arrow_downward;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(changeIcon, color: changeColor, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${changePercent.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '上期: ¥${previousValue.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  List<Transaction> _filterTransactionsByPeriod(List<Transaction> transactions) {
    switch (_selectedPeriod) {
      case StatsPeriod.day:
        return transactions.where((t) =>
            t.date.year == _currentDate.year &&
            t.date.month == _currentDate.month &&
            t.date.day == _currentDate.day).toList();
      case StatsPeriod.week:
        final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return transactions.where((t) =>
            t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(weekEnd)).toList();
      case StatsPeriod.month:
        return transactions.where((t) =>
            t.date.year == _currentDate.year &&
            t.date.month == _currentDate.month).toList();
      case StatsPeriod.year:
        return transactions.where((t) =>
            t.date.year == _currentDate.year).toList();
    }
  }

  Map<String, double> _groupByCategory(List<Transaction> transactions) {
    final map = <String, double>{};
    for (final t in transactions) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  String _getPeriodTitle() {
    switch (_selectedPeriod) {
      case StatsPeriod.day:
        return DateFormat('yyyy年MM月dd日').format(_currentDate);
      case StatsPeriod.week:
        final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return '${DateFormat("MM/dd").format(weekStart)} - ${DateFormat("MM/dd").format(weekEnd)}';
      case StatsPeriod.month:
        return DateFormat('yyyy年MM月').format(_currentDate);
      case StatsPeriod.year:
        return '${_currentDate.year}年';
    }
  }

  /// 获取上一个周期的交易（环比）
  List<Transaction> _getPreviousPeriodTransactions(
    List<Transaction> allTransactions,
    bool isExpense,
  ) {
    final type = isExpense ? TransactionType.expense : TransactionType.income;
    final typeFiltered = allTransactions.where((t) => t.type == type).toList();

    switch (_selectedPeriod) {
      case StatsPeriod.day:
        final prevDate = _currentDate.subtract(const Duration(days: 1));
        return typeFiltered.where((t) =>
            t.date.year == prevDate.year &&
            t.date.month == prevDate.month &&
            t.date.day == prevDate.day).toList();
      case StatsPeriod.week:
        final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1 + 7));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return typeFiltered.where((t) =>
            t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(weekEnd)).toList();
      case StatsPeriod.month:
        final prevMonth = DateTime(_currentDate.year, _currentDate.month - 1, 1);
        return typeFiltered.where((t) =>
            t.date.year == prevMonth.year &&
            t.date.month == prevMonth.month).toList();
      case StatsPeriod.year:
        return typeFiltered.where((t) =>
            t.date.year == _currentDate.year - 1).toList();
    }
  }

  /// 获取去年同期的交易（同比）
  List<Transaction> _getYoYPeriodTransactions(
    List<Transaction> allTransactions,
    bool isExpense,
  ) {
    final type = isExpense ? TransactionType.expense : TransactionType.income;
    final typeFiltered = allTransactions.where((t) => t.type == type).toList();

    switch (_selectedPeriod) {
      case StatsPeriod.day:
        final lastYearDate = DateTime(_currentDate.year - 1, _currentDate.month, _currentDate.day);
        return typeFiltered.where((t) =>
            t.date.year == lastYearDate.year &&
            t.date.month == lastYearDate.month &&
            t.date.day == lastYearDate.day).toList();
      case StatsPeriod.week:
        // 去年同一周（按周数计算）
        final lastYearDate = DateTime(_currentDate.year - 1, _currentDate.month, _currentDate.day);
        final weekStart = lastYearDate.subtract(Duration(days: lastYearDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return typeFiltered.where((t) =>
            t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(weekEnd)).toList();
      case StatsPeriod.month:
        final lastYearMonth = DateTime(_currentDate.year - 1, _currentDate.month, 1);
        return typeFiltered.where((t) =>
            t.date.year == lastYearMonth.year &&
            t.date.month == lastYearMonth.month).toList();
      case StatsPeriod.year:
        // 年度视图没有同比，只有环比（上一年）
        return [];
    }
  }

  /// 计算变化百分比
  double _calculateChangePercent(double current, double previous) {
    if (previous == 0) {
      return current > 0 ? 100 : 0;
    }
    return ((current - previous) / previous) * 100;
  }

  /// 获取环比标签
  String _getMoMLabel() {
    switch (_selectedPeriod) {
      case StatsPeriod.day:
        return '日环比';
      case StatsPeriod.week:
        return '周环比';
      case StatsPeriod.month:
        return '月环比';
      case StatsPeriod.year:
        return '年环比';
    }
  }

  /// 获取同比标签
  String _getYoYLabel() {
    switch (_selectedPeriod) {
      case StatsPeriod.day:
        return '日同比';
      case StatsPeriod.week:
        return '周同比';
      case StatsPeriod.month:
        return '月同比';
      case StatsPeriod.year:
        return ''; // 年度视图没有同比
    }
  }

  void _previousPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case StatsPeriod.day:
          _currentDate = _currentDate.subtract(const Duration(days: 1));
          break;
        case StatsPeriod.week:
          _currentDate = _currentDate.subtract(const Duration(days: 7));
          break;
        case StatsPeriod.month:
          _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
          break;
        case StatsPeriod.year:
          _currentDate = DateTime(_currentDate.year - 1, 1, 1);
          break;
      }
    });
  }

  void _nextPeriod() {
    final now = DateTime.now();
    setState(() {
      switch (_selectedPeriod) {
        case StatsPeriod.day:
          if (_currentDate.isBefore(now)) {
            _currentDate = _currentDate.add(const Duration(days: 1));
          }
          break;
        case StatsPeriod.week:
          if (_currentDate.isBefore(now)) {
            _currentDate = _currentDate.add(const Duration(days: 7));
          }
          break;
        case StatsPeriod.month:
          if (_currentDate.year < now.year ||
              (_currentDate.year == now.year && _currentDate.month < now.month)) {
            _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
          }
          break;
        case StatsPeriod.year:
          if (_currentDate.year < now.year) {
            _currentDate = DateTime(_currentDate.year + 1, 1, 1);
          }
          break;
      }
    });
  }

  Widget _buildSummaryHeader(
    double amount,
    bool isExpense, {
    double momChange = 0,
    double? yoyChange,
    double prevTotal = 0,
    double yoyTotal = 0,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousPeriod,
              ),
              Text(
                _getPeriodTitle(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextPeriod,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isExpense ? '总支出' : '总收入',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isExpense ? AppColors.expense : AppColors.income,
            ),
          ),
          // 快速对比指示器
          if (amount > 0 || prevTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMiniChangeIndicator(
                    label: _getMoMLabel(),
                    change: momChange,
                    isExpense: isExpense,
                  ),
                  if (yoyChange != null) ...[
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: AppColors.divider,
                    ),
                    _buildMiniChangeIndicator(
                      label: _getYoYLabel(),
                      change: yoyChange,
                      isExpense: isExpense,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniChangeIndicator({
    required String label,
    required double change,
    required bool isExpense,
  }) {
    final isIncrease = change > 0;

    Color changeColor;
    if (change == 0) {
      changeColor = AppColors.textSecondary;
    } else if (isExpense) {
      changeColor = isIncrease ? AppColors.expense : AppColors.income;
    } else {
      changeColor = isIncrease ? AppColors.income : AppColors.expense;
    }

    IconData changeIcon;
    if (change == 0) {
      changeIcon = Icons.remove;
    } else {
      changeIcon = isIncrease ? Icons.trending_up : Icons.trending_down;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Icon(changeIcon, color: changeColor, size: 14),
        Text(
          ' ${change.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            color: changeColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart(List<Transaction> allTransactions, bool isExpense) {
    final data = _getTrendData(allTransactions, isExpense);
    if (data.isEmpty) return const SizedBox();

    final maxValue = data.values.reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '趋势图',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '¥${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(color: Colors.white),
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
                        final labels = data.keys.toList();
                        if (value.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: data.entries.toList().asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value,
                        color: isExpense ? AppColors.expense : AppColors.income,
                        width: _selectedPeriod == StatsPeriod.year ? 20 : 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _getTrendData(List<Transaction> transactions, bool isExpense) {
    final filtered = transactions.where((t) => isExpense
        ? t.type == TransactionType.expense
        : t.type == TransactionType.income).toList();

    switch (_selectedPeriod) {
      case StatsPeriod.day:
        // 显示最近7天
        final map = <String, double>{};
        for (int i = 6; i >= 0; i--) {
          final date = _currentDate.subtract(Duration(days: i));
          final dayTotal = filtered
              .where((t) =>
                  t.date.year == date.year &&
                  t.date.month == date.month &&
                  t.date.day == date.day)
              .fold(0.0, (sum, t) => sum + t.amount);
          map[DateFormat('MM/dd').format(date)] = dayTotal;
        }
        return map;
      case StatsPeriod.week:
        // 显示最近4周
        final map = <String, double>{};
        for (int i = 3; i >= 0; i--) {
          final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1 + i * 7));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final weekTotal = filtered
              .where((t) =>
                  t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                  t.date.isBefore(weekEnd))
              .fold(0.0, (sum, t) => sum + t.amount);
          map['第${4 - i}周'] = weekTotal;
        }
        return map;
      case StatsPeriod.month:
        // 显示当月每周
        final map = <String, double>{};
        final firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
        final lastDay = DateTime(_currentDate.year, _currentDate.month + 1, 0);
        int week = 1;
        DateTime current = firstDay;
        while (current.isBefore(lastDay) || current.isAtSameMomentAs(lastDay)) {
          final weekEnd = current.add(const Duration(days: 7));
          final weekTotal = filtered
              .where((t) =>
                  t.date.year == _currentDate.year &&
                  t.date.month == _currentDate.month &&
                  t.date.isAfter(current.subtract(const Duration(days: 1))) &&
                  t.date.isBefore(weekEnd))
              .fold(0.0, (sum, t) => sum + t.amount);
          map['第${week}周'] = weekTotal;
          week++;
          current = weekEnd;
        }
        return map;
      case StatsPeriod.year:
        // 显示12个月
        final map = <String, double>{};
        for (int month = 1; month <= 12; month++) {
          final monthTotal = filtered
              .where((t) =>
                  t.date.year == _currentDate.year && t.date.month == month)
              .fold(0.0, (sum, t) => sum + t.amount);
          map['${month}月'] = monthTotal;
        }
        return map;
    }
  }

  Widget _buildPieChart(Map<String, double> data) {
    final total = data.values.fold(0.0, (sum, v) => sum + v);
    final entries = data.entries.toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '分类占比',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final categoryId = entry.value.key;
                  final amount = entry.value.value;
                  final category = DefaultCategories.findById(categoryId);
                  final isTouched = index == _touchedIndex;
                  final percentage = (amount / total * 100).toStringAsFixed(1);

                  return PieChartSectionData(
                    color: category?.color ?? Colors.grey,
                    value: amount,
                    title: isTouched ? '$percentage%' : '',
                    radius: isTouched ? 60 : 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(Map<String, double> data) {
    final total = data.values.fold(0.0, (sum, v) => sum + v);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '分类明细',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...sortedEntries.map((entry) {
            final category = DefaultCategories.findById(entry.key);
            final percentage = entry.value / total;

            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (category?.color ?? Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  category?.icon ?? Icons.help_outline,
                  color: category?.color ?? Colors.grey,
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      category?.name ?? entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${(percentage * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        category?.color ?? Colors.grey,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
              trailing: Text(
                '¥${entry.value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          SizedBox(height: 16),
          Text(
            '暂无数据',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '开始记账后这里会显示统计图表',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
