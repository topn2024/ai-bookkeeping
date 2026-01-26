import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';
import 'category_detail_page.dart';

/// 对比模式
enum ComparisonMode {
  month, // 月对比
  quarter, // 季对比
  year, // 年对比
}

/// 时间对比页面
/// 对比不同时间段的收支情况，提供直观的数据变化分析
class PeriodComparisonPage extends ConsumerStatefulWidget {
  final ComparisonMode initialMode;

  const PeriodComparisonPage({
    super.key,
    this.initialMode = ComparisonMode.month,
  });

  @override
  ConsumerState<PeriodComparisonPage> createState() => _PeriodComparisonPageState();
}

class _PeriodComparisonPageState extends ConsumerState<PeriodComparisonPage> {
  late ThemeColors _themeColors;
  late ComparisonMode _mode;
  late DateTime _currentPeriod;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _currentPeriod = DateTime.now();
  }

  /// 获取当前期间的时间范围
  DateTimeRange _getCurrentPeriodRange() {
    switch (_mode) {
      case ComparisonMode.month:
        return DateTimeRange(
          start: DateTime(_currentPeriod.year, _currentPeriod.month, 1),
          end: DateTime(_currentPeriod.year, _currentPeriod.month + 1, 0),
        );
      case ComparisonMode.quarter:
        final quarter = ((_currentPeriod.month - 1) / 3).floor();
        return DateTimeRange(
          start: DateTime(_currentPeriod.year, quarter * 3 + 1, 1),
          end: DateTime(_currentPeriod.year, (quarter + 1) * 3 + 1, 0),
        );
      case ComparisonMode.year:
        return DateTimeRange(
          start: DateTime(_currentPeriod.year, 1, 1),
          end: DateTime(_currentPeriod.year, 12, 31),
        );
    }
  }

  /// 获取上期的时间范围
  DateTimeRange _getPreviousPeriodRange() {
    switch (_mode) {
      case ComparisonMode.month:
        final prevMonth = DateTime(_currentPeriod.year, _currentPeriod.month - 1, 1);
        return DateTimeRange(
          start: prevMonth,
          end: DateTime(prevMonth.year, prevMonth.month + 1, 0),
        );
      case ComparisonMode.quarter:
        final quarter = ((_currentPeriod.month - 1) / 3).floor();
        final prevQuarterStart = DateTime(_currentPeriod.year, (quarter - 1) * 3 + 1, 1);
        return DateTimeRange(
          start: prevQuarterStart.month < 1
              ? DateTime(_currentPeriod.year - 1, prevQuarterStart.month + 12, 1)
              : prevQuarterStart,
          end: DateTime(
            prevQuarterStart.month < 1 ? _currentPeriod.year - 1 : _currentPeriod.year,
            quarter * 3 + 1,
            0,
          ),
        );
      case ComparisonMode.year:
        return DateTimeRange(
          start: DateTime(_currentPeriod.year - 1, 1, 1),
          end: DateTime(_currentPeriod.year - 1, 12, 31),
        );
    }
  }

  /// 获取期间内的交易
  List<Transaction> _getTransactionsInRange(
      List<Transaction> all, DateTimeRange range) {
    return all.where((t) {
      return !t.date.isBefore(range.start) &&
          t.date.isBefore(range.end.add(const Duration(days: 1)));
    }).toList();
  }

  /// 计算期间统计
  Map<String, double> _calculatePeriodStats(List<Transaction> transactions) {
    double income = 0;
    double expense = 0;

    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else if (t.type == TransactionType.expense) {
        expense += t.amount;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }

  /// 按分类汇总支出
  Map<String, double> _getExpenseByCategory(List<Transaction> transactions) {
    final map = <String, double>{};
    for (final t in transactions.where((t) => t.type == TransactionType.expense)) {
      // 获取一级分类
      final category = DefaultCategories.findById(t.category);
      final parentId = category?.parentId ?? t.category;
      map[parentId] = (map[parentId] ?? 0) + t.amount;
    }
    return map;
  }

  String _getPeriodLabel(DateTimeRange range) {
    switch (_mode) {
      case ComparisonMode.month:
        return DateFormat('yyyy年MM月').format(range.start);
      case ComparisonMode.quarter:
        final quarter = ((range.start.month - 1) / 3).floor() + 1;
        return '${range.start.year}年Q$quarter';
      case ComparisonMode.year:
        return '${range.start.year}年';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionProvider);
    _themeColors = ref.themeColors;

    final currentRange = _getCurrentPeriodRange();
    final previousRange = _getPreviousPeriodRange();

    final currentTransactions = _getTransactionsInRange(allTransactions, currentRange);
    final previousTransactions = _getTransactionsInRange(allTransactions, previousRange);

    final currentStats = _calculatePeriodStats(currentTransactions);
    final previousStats = _calculatePeriodStats(previousTransactions);

    final currentExpenseByCategory = _getExpenseByCategory(currentTransactions);
    final previousExpenseByCategory = _getExpenseByCategory(previousTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('时间对比'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 模式切换
            _buildModeSelector(),
            // 期间切换
            _buildPeriodSelector(currentRange, previousRange),
            // 对比卡片
            _buildComparisonCards(currentStats, previousStats, currentRange, previousRange),
            // 收支对比图表
            _buildComparisonChart(currentStats, previousStats),
            // 分类对比列表
            _buildCategoryComparison(
              currentExpenseByCategory,
              previousExpenseByCategory,
              currentRange,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildModeTab('月对比', ComparisonMode.month),
          _buildModeTab('季对比', ComparisonMode.quarter),
          _buildModeTab('年对比', ComparisonMode.year),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, ComparisonMode mode) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = mode;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? _themeColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(DateTimeRange current, DateTimeRange previous) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousPeriod,
          ),
          Text(
            _getPeriodLabel(current),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            ' vs ',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            _getPeriodLabel(previous),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _canGoNext() ? _nextPeriod : null,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCards(
    Map<String, double> current,
    Map<String, double> previous,
    DateTimeRange currentRange,
    DateTimeRange previousRange,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 当前期间卡片
          Expanded(
            child: _buildPeriodCard(
              label: '当前',
              period: _getPeriodLabel(currentRange),
              expense: current['expense']!,
              income: current['income']!,
              isCurrent: true,
            ),
          ),
          const SizedBox(width: 12),
          // 上期卡片
          Expanded(
            child: _buildPeriodCard(
              label: '上期',
              period: _getPeriodLabel(previousRange),
              expense: previous['expense']!,
              income: previous['income']!,
              isCurrent: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard({
    required String label,
    required String period,
    required double expense,
    required double income,
    required bool isCurrent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: _themeColors.primary, width: 2)
            : null,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? _themeColors.primary.withValues(alpha: 0.1)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrent ? _themeColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 支出
          Text(
            '支出',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '¥${expense.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _themeColors.expense,
            ),
          ),
          const SizedBox(height: 8),
          // 收入
          Text(
            '收入',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '¥${income.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _themeColors.income,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonChart(
    Map<String, double> current,
    Map<String, double> previous,
  ) {
    final expenseChange = previous['expense']! > 0
        ? ((current['expense']! - previous['expense']!) / previous['expense']! * 100)
        : (current['expense']! > 0 ? 100.0 : 0.0);
    final incomeChange = previous['income']! > 0
        ? ((current['income']! - previous['income']!) / previous['income']! * 100)
        : (current['income']! > 0 ? 100.0 : 0.0);

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
          const Text(
            '收支对比',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          // 支出对比条
          _buildComparisonBar(
            label: '支出',
            currentValue: current['expense']!,
            previousValue: previous['expense']!,
            change: expenseChange,
            color: _themeColors.expense,
          ),
          const SizedBox(height: 16),
          // 收入对比条
          _buildComparisonBar(
            label: '收入',
            currentValue: current['income']!,
            previousValue: previous['income']!,
            change: incomeChange,
            color: _themeColors.income,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar({
    required String label,
    required double currentValue,
    required double previousValue,
    required double change,
    required Color color,
  }) {
    final maxValue = currentValue > previousValue ? currentValue : previousValue;
    final currentRatio = maxValue > 0 ? currentValue / maxValue : 0.0;
    final previousRatio = maxValue > 0 ? previousValue / maxValue : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              change > 0
                  ? Icons.trending_up
                  : (change < 0 ? Icons.trending_down : Icons.remove),
              size: 16,
              color: change > 0
                  ? (label == '支出' ? _themeColors.expense : _themeColors.income)
                  : (change < 0
                      ? (label == '支出' ? _themeColors.income : _themeColors.expense)
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 4),
            Text(
              '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: change > 0
                    ? (label == '支出' ? _themeColors.expense : _themeColors.income)
                    : (change < 0
                        ? (label == '支出' ? _themeColors.income : _themeColors.expense)
                        : AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 当前期间条
        Row(
          children: [
            const SizedBox(
              width: 40,
              child: Text(
                '当前',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: currentRatio,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: Text(
                '¥${currentValue.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 上期条
        Row(
          children: [
            const SizedBox(
              width: 40,
              child: Text(
                '上期',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: previousRatio,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: Text(
                '¥${previousValue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryComparison(
    Map<String, double> current,
    Map<String, double> previous,
    DateTimeRange currentRange,
  ) {
    // 合并所有分类
    final allCategories = {...current.keys, ...previous.keys}.toList();

    // 按当前期间金额排序
    allCategories.sort((a, b) {
      final aValue = current[a] ?? 0;
      final bValue = current[b] ?? 0;
      return bValue.compareTo(aValue);
    });

    if (allCategories.isEmpty) {
      return const SizedBox();
    }

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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '分类对比',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ...allCategories.take(10).map((categoryId) {
            return _buildCategoryItem(
              categoryId: categoryId,
              currentAmount: current[categoryId] ?? 0,
              previousAmount: previous[categoryId] ?? 0,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryItem({
    required String categoryId,
    required double currentAmount,
    required double previousAmount,
  }) {
    final category = DefaultCategories.findById(categoryId);
    final change = previousAmount > 0
        ? ((currentAmount - previousAmount) / previousAmount * 100)
        : (currentAmount > 0 ? 100.0 : 0.0);
    final diff = currentAmount - previousAmount;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailPage(
              categoryId: categoryId,
              selectedMonth: _currentPeriod,
              isExpense: true,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 分类图标
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
            // 分类名称和金额
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(categoryId),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '当前 ¥${currentAmount.toStringAsFixed(0)} / 上期 ¥${previousAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // 变化
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      diff > 0
                          ? Icons.arrow_upward
                          : (diff < 0 ? Icons.arrow_downward : Icons.remove),
                      size: 14,
                      color: diff > 0
                          ? _themeColors.expense
                          : (diff < 0 ? _themeColors.income : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '¥${diff.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: diff > 0
                            ? _themeColors.expense
                            : (diff < 0 ? _themeColors.income : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: diff > 0
                        ? _themeColors.expense
                        : (diff < 0 ? _themeColors.income : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  void _previousPeriod() {
    setState(() {
      switch (_mode) {
        case ComparisonMode.month:
          _currentPeriod = DateTime(_currentPeriod.year, _currentPeriod.month - 1, 1);
          break;
        case ComparisonMode.quarter:
          _currentPeriod = DateTime(_currentPeriod.year, _currentPeriod.month - 3, 1);
          break;
        case ComparisonMode.year:
          _currentPeriod = DateTime(_currentPeriod.year - 1, _currentPeriod.month, 1);
          break;
      }
    });
  }

  void _nextPeriod() {
    if (!_canGoNext()) return;
    setState(() {
      switch (_mode) {
        case ComparisonMode.month:
          _currentPeriod = DateTime(_currentPeriod.year, _currentPeriod.month + 1, 1);
          break;
        case ComparisonMode.quarter:
          _currentPeriod = DateTime(_currentPeriod.year, _currentPeriod.month + 3, 1);
          break;
        case ComparisonMode.year:
          _currentPeriod = DateTime(_currentPeriod.year + 1, _currentPeriod.month, 1);
          break;
      }
    });
  }

  bool _canGoNext() {
    final now = DateTime.now();
    switch (_mode) {
      case ComparisonMode.month:
        return _currentPeriod.year < now.year ||
            (_currentPeriod.year == now.year && _currentPeriod.month < now.month);
      case ComparisonMode.quarter:
        final currentQuarter = ((_currentPeriod.month - 1) / 3).floor();
        final nowQuarter = ((now.month - 1) / 3).floor();
        return _currentPeriod.year < now.year ||
            (_currentPeriod.year == now.year && currentQuarter < nowQuarter);
      case ComparisonMode.year:
        return _currentPeriod.year < now.year;
    }
  }
}
