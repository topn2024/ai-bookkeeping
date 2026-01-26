import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';
import 'add_transaction_page.dart';
import 'transaction_detail_page.dart';

/// 分类详情页面
/// 显示指定分类的详细支出/收入情况，包括汇总统计、趋势图表和交易明细
class CategoryDetailPage extends ConsumerStatefulWidget {
  final String categoryId;
  final DateTime? selectedMonth;
  final bool? isExpense;

  const CategoryDetailPage({
    super.key,
    required this.categoryId,
    this.selectedMonth,
    this.isExpense,
  });

  @override
  ConsumerState<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends ConsumerState<CategoryDetailPage> {
  late ThemeColors _themeColors;
  late DateTime _currentMonth;
  late Category? _category;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.selectedMonth ?? DateTime.now();
    _category = DefaultCategories.findById(widget.categoryId);
  }

  /// 获取该分类在指定月份的交易
  List<Transaction> _getFilteredTransactions(List<Transaction> allTransactions) {
    return allTransactions.where((t) {
      // 匹配分类（包括子分类）
      bool categoryMatch = t.category == widget.categoryId;
      if (!categoryMatch) {
        // 检查是否是子分类
        final category = DefaultCategories.findById(t.category);
        if (category?.parentId == widget.categoryId) {
          categoryMatch = true;
        }
      }

      // 匹配月份
      final monthMatch = t.date.year == _currentMonth.year &&
          t.date.month == _currentMonth.month;

      // 匹配类型
      bool typeMatch = true;
      if (widget.isExpense != null) {
        typeMatch = widget.isExpense!
            ? t.type == TransactionType.expense
            : t.type == TransactionType.income;
      }

      return categoryMatch && monthMatch && typeMatch;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 获取趋势数据（最近7天或本月每周）
  Map<String, double> _getTrendData(List<Transaction> transactions) {
    final map = <String, double>{};
    final now = DateTime.now();

    // 显示本月每天的数据（最多显示最近7天有数据的）
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final endDay = _currentMonth.year == now.year && _currentMonth.month == now.month
        ? now.day
        : daysInMonth;

    for (int day = 1; day <= endDay; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dayTotal = transactions
          .where((t) =>
              t.date.year == date.year &&
              t.date.month == date.month &&
              t.date.day == date.day)
          .fold(0.0, (sum, t) => sum + t.amount);
      if (dayTotal > 0 || map.length < 7) {
        map[DateFormat('MM/dd').format(date)] = dayTotal;
      }
    }

    // 只保留最后7个数据点
    if (map.length > 7) {
      final keys = map.keys.toList();
      final keysToRemove = keys.sublist(0, keys.length - 7);
      for (final key in keysToRemove) {
        map.remove(key);
      }
    }

    return map;
  }

  /// 获取上月同期数据用于对比
  double _getPreviousMonthTotal(List<Transaction> allTransactions) {
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    return allTransactions.where((t) {
      bool categoryMatch = t.category == widget.categoryId;
      if (!categoryMatch) {
        final category = DefaultCategories.findById(t.category);
        if (category?.parentId == widget.categoryId) {
          categoryMatch = true;
        }
      }
      final monthMatch = t.date.year == prevMonth.year &&
          t.date.month == prevMonth.month;
      bool typeMatch = true;
      if (widget.isExpense != null) {
        typeMatch = widget.isExpense!
            ? t.type == TransactionType.expense
            : t.type == TransactionType.income;
      }
      return categoryMatch && monthMatch && typeMatch;
    }).fold(0.0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionProvider);
    final filteredTransactions = _getFilteredTransactions(allTransactions);
    _themeColors = ref.themeColors;

    final totalAmount = filteredTransactions.fold(0.0, (sum, t) => sum + t.amount);
    final transactionCount = filteredTransactions.length;
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final dailyAverage = transactionCount > 0 ? totalAmount / daysInMonth : 0.0;
    final prevMonthTotal = _getPreviousMonthTotal(allTransactions);
    final monthChange = prevMonthTotal > 0
        ? ((totalAmount - prevMonthTotal) / prevMonthTotal * 100)
        : (totalAmount > 0 ? 100.0 : 0.0);

    final isExpense = widget.isExpense ?? (_category?.isExpense ?? true);
    final categoryColor = _category?.color ?? _themeColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(_category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(widget.categoryId)),
        backgroundColor: categoryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: '选择月份',
          ),
        ],
      ),
      body: filteredTransactions.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildSummaryCard(
                    totalAmount: totalAmount,
                    transactionCount: transactionCount,
                    dailyAverage: dailyAverage,
                    monthChange: monthChange,
                    isExpense: isExpense,
                    categoryColor: categoryColor,
                  ),
                  _buildTrendChart(filteredTransactions, categoryColor),
                  _buildTransactionList(filteredTransactions, isExpense),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required double totalAmount,
    required int transactionCount,
    required double dailyAverage,
    required double monthChange,
    required bool isExpense,
    required Color categoryColor,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [categoryColor, categoryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // 月份切换
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _previousMonth,
              ),
              Text(
                DateFormat('yyyy年MM月').format(_currentMonth),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 总金额
          Text(
            '¥${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 环比变化
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                monthChange > 0
                    ? Icons.trending_up
                    : (monthChange < 0 ? Icons.trending_down : Icons.remove),
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '环比${monthChange >= 0 ? '+' : ''}${monthChange.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 统计项
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('交易笔数', '$transactionCount笔'),
              Container(
                width: 1,
                height: 30,
                color: Colors.white24,
              ),
              _buildStatItem('日均', '¥${dailyAverage.toStringAsFixed(1)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart(List<Transaction> transactions, Color color) {
    final data = _getTrendData(transactions);
    if (data.isEmpty) return const SizedBox();

    final maxValue = data.values.isEmpty
        ? 100.0
        : data.values.reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: color, size: 20),
              const SizedBox(width: 8),
              const Text(
                '消费趋势',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
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
                              labels[value.toInt()].substring(3), // 只显示日
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
                        color: color,
                        width: 16,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
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

  Widget _buildTransactionList(List<Transaction> transactions, bool isExpense) {
    // 按日期分组
    final grouped = <String, List<Transaction>>{};
    for (final t in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(t.date);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(t);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '交易明细',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '共${transactions.length}笔',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...sortedKeys.map((dateKey) {
            final dayTransactions = grouped[dateKey]!;
            final date = DateTime.parse(dateKey);
            final dayTotal = dayTransactions.fold(0.0, (sum, t) => sum + t.amount);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.background,
                  child: Row(
                    children: [
                      Text(
                        _formatDateHeader(date),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '¥${dayTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isExpense ? _themeColors.expense : _themeColors.income,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ...dayTransactions.map((t) => _buildTransactionItem(t, isExpense)),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction, bool isExpense) {
    final category = DefaultCategories.findById(transaction.category);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(transaction: transaction),
          ),
        ).then((_) => ref.read(transactionProvider.notifier).refresh());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    transaction.note ?? category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(transaction.category),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('HH:mm').format(transaction.date),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isExpense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isExpense ? _themeColors.expense : _themeColors.income,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _category?.icon ?? Icons.category,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            '${DateFormat('yyyy年MM月').format(_currentMonth)}暂无数据',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '该分类在当月没有交易记录',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddTransactionPage(),
                ),
              ).then((_) => ref.read(transactionProvider.notifier).refresh());
            },
            icon: const Icon(Icons.add),
            label: const Text('添加一笔'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _category?.color ?? _themeColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return '今天';
    } else if (targetDate == yesterday) {
      return '昨天';
    } else {
      return DateFormat('MM月dd日 E', 'zh_CN').format(date);
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    if (nextMonth.isBefore(DateTime(now.year, now.month + 1, 1))) {
      setState(() {
        _currentMonth = nextMonth;
      });
    }
  }

  Future<void> _selectMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (selected != null) {
      setState(() {
        _currentMonth = DateTime(selected.year, selected.month, 1);
      });
    }
  }
}
