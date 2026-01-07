import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';

/// 消费热力图页面
/// 原型设计 7.07：消费热力图
/// - 视图切换（日历视图、时段视图）
/// - 月份选择
/// - 热力日历（颜色深浅表示消费多少）
/// - 图例说明
/// - 选中日期详情
class ExpenseHeatmapPage extends ConsumerStatefulWidget {
  const ExpenseHeatmapPage({super.key});

  @override
  ConsumerState<ExpenseHeatmapPage> createState() => _ExpenseHeatmapPageState();
}

class _ExpenseHeatmapPageState extends ConsumerState<ExpenseHeatmapPage> {
  int _viewMode = 0; // 0: 日历视图, 1: 时段视图
  late DateTime _selectedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);

    // 按日期汇总支出
    final dailyExpense = <DateTime, double>{};
    for (final t in transactions) {
      if (t.type == TransactionType.expense &&
          t.date.year == _selectedMonth.year &&
          t.date.month == _selectedMonth.month) {
        final day = DateTime(t.date.year, t.date.month, t.date.day);
        dailyExpense[day] = (dailyExpense[day] ?? 0) + t.amount;
      }
    }

    // 计算最大值用于颜色映射
    final maxExpense = dailyExpense.values.isEmpty
        ? 1.0
        : dailyExpense.values.reduce((a, b) => a > b ? a : b);

    // 选中日期的数据
    final selectedDayExpense = _selectedDate != null ? dailyExpense[_selectedDate] ?? 0.0 : 0.0;
    final avgExpense = dailyExpense.values.isEmpty
        ? 0.0
        : dailyExpense.values.reduce((a, b) => a + b) / dailyExpense.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            _buildViewToggle(theme),
            _buildMonthSelector(theme),
            _buildHeatmapCalendar(theme, dailyExpense, maxExpense),
            _buildLegend(theme),
            if (_selectedDate != null)
              Expanded(
                child: _buildSelectedDateDetail(theme, selectedDayExpense, avgExpense),
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
              '消费热力图',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _showHelp(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.help_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 视图切换
  Widget _buildViewToggle(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _viewMode == 0 ? theme.colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _viewMode == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '日历视图',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _viewMode == 0 ? FontWeight.w500 : FontWeight.normal,
                    fontSize: 14,
                    color: _viewMode == 0
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _viewMode == 1 ? theme.colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _viewMode == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '时段视图',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _viewMode == 1 ? FontWeight.w500 : FontWeight.normal,
                    fontSize: 14,
                    color: _viewMode == 1
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 月份选择器
  Widget _buildMonthSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _previousMonth,
            child: Icon(
              Icons.chevron_left,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            DateFormat('yyyy年M月').format(_selectedMonth),
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _nextMonth,
            child: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 热力日历
  Widget _buildHeatmapCalendar(ThemeData theme, Map<DateTime, double> dailyExpense, double maxExpense) {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0=周日

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 星期标题
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((day) => Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // 日期格子
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: startWeekday + lastDay.day,
            itemBuilder: (context, index) {
              if (index < startWeekday) {
                return const SizedBox();
              }
              final day = index - startWeekday + 1;
              final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
              final expense = dailyExpense[date] ?? 0;
              final intensity = maxExpense > 0 ? expense / maxExpense : 0.0;
              final isSelected = _selectedDate == date;

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: _getHeatmapColor(intensity),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        color: intensity > 0.5 ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getHeatmapColor(double intensity) {
    if (intensity <= 0) return const Color(0xFFF5F5F5);
    if (intensity < 0.2) return const Color(0xFFFFEBEE);
    if (intensity < 0.4) return const Color(0xFFFFCDD2);
    if (intensity < 0.6) return const Color(0xFFEF9A9A);
    if (intensity < 0.8) return const Color(0xFFE57373);
    return const Color(0xFFF44336);
  }

  /// 图例
  Widget _buildLegend(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '少',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          ...[0.0, 0.2, 0.4, 0.6, 0.8].map((intensity) => Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _getHeatmapColor(intensity),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
          const SizedBox(width: 8),
          Text(
            '多',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 选中日期详情
  Widget _buildSelectedDateDetail(ThemeData theme, double expense, double avgExpense) {
    final weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final dateStr = DateFormat('M月d日').format(_selectedDate!);
    final weekday = weekdays[_selectedDate!.weekday % 7];
    final compareAvg = avgExpense > 0 ? ((expense - avgExpense) / avgExpense * 100) : 0.0;
    final isHighSpending = compareAvg > 50;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$dateStr $weekday',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '¥${expense.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isHighSpending
                ? '高消费日 · 超出日均 ${compareAvg.toStringAsFixed(0)}%'
                : '消费正常',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _viewDayDetail(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('查看当日交易明细', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month)) {
      setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
        _selectedDate = null;
      });
    }
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('热力图说明'),
        content: const Text('颜色越深表示当日消费越多。点击日期可查看详细支出信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _viewDayDetail(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('查看 ${DateFormat('M月d日').format(_selectedDate!)} 交易明细...')),
    );
  }
}
