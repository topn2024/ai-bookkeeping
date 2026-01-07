import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bill_reminder.dart';
import '../../providers/bill_reminder_provider.dart';

/// 账单日历视图页面
/// 原型设计 13.06：账单日历视图
/// - 月份选择器
/// - 日历网格（带账单指示器）
/// - 选中日期的账单列表
/// - 图例
class BillCalendarPage extends ConsumerStatefulWidget {
  const BillCalendarPage({super.key});

  @override
  ConsumerState<BillCalendarPage> createState() => _BillCalendarPageState();
}

class _BillCalendarPageState extends ConsumerState<BillCalendarPage> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminders = ref.watch(billReminderProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            _buildMonthSelector(theme),
            _buildCalendarGrid(theme, reminders),
            if (_selectedDate != null)
              Expanded(
                child: _buildSelectedDateBills(theme, reminders),
              ),
            _buildLegend(theme),
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
              '账单日历',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _goToToday(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.today,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 月份选择器
  Widget _buildMonthSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _changeMonth(-1),
            child: Icon(
              Icons.chevron_left,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${_currentMonth.year}年${_currentMonth.month}月',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: () => _changeMonth(1),
            child: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
      _selectedDate = DateTime.now();
    });
  }

  /// 日历网格
  Widget _buildCalendarGrid(ThemeData theme, List<BillReminder> reminders) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = lastDayOfMonth.day;

    // 获取每天的账单
    final billsByDay = <int, List<BillReminder>>{};
    for (final reminder in reminders) {
      if (reminder.frequency == ReminderFrequency.monthly) {
        if (reminder.dayOfMonth <= daysInMonth) {
          billsByDay.putIfAbsent(reminder.dayOfMonth, () => []).add(reminder);
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 星期标题
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 42, // 6 rows x 7 days
            itemBuilder: (context, index) {
              final dayOffset = index - firstWeekday;
              final day = dayOffset + 1;

              if (day < 1 || day > daysInMonth) {
                // 上月或下月的日期
                return const SizedBox();
              }

              final bills = billsByDay[day] ?? [];
              final isToday = _isToday(day);
              final isSelected = _isSelected(day);

              return _buildDayCell(theme, day, bills, isToday, isSelected);
            },
          ),
        ],
      ),
    );
  }

  bool _isToday(int day) {
    final now = DateTime.now();
    return _currentMonth.year == now.year &&
        _currentMonth.month == now.month &&
        day == now.day;
  }

  bool _isSelected(int day) {
    if (_selectedDate == null) return false;
    return _currentMonth.year == _selectedDate!.year &&
        _currentMonth.month == _selectedDate!.month &&
        day == _selectedDate!.day;
  }

  Widget _buildDayCell(
    ThemeData theme,
    int day,
    List<BillReminder> bills,
    bool isToday,
    bool isSelected,
  ) {
    final hasBills = bills.isNotEmpty;
    final urgentBill = bills.any((b) => b.daysUntilBill <= 0);
    final soonBill = bills.any((b) => b.daysUntilBill <= 3 && b.daysUntilBill > 0);

    Color? backgroundColor;
    Color? textColor;

    if (isSelected) {
      backgroundColor = theme.colorScheme.primary;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = theme.colorScheme.primary;
      textColor = Colors.white;
    } else if (urgentBill) {
      backgroundColor = const Color(0xFFE57373).withValues(alpha: 0.2);
    } else if (soonBill) {
      backgroundColor = const Color(0xFFFFB74D).withValues(alpha: 0.2);
    } else if (hasBills) {
      backgroundColor = const Color(0xFF6495ED).withValues(alpha: 0.2);
    }

    return GestureDetector(
      onTap: () => setState(() {
        _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, day);
      }),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor ?? theme.colorScheme.onSurface,
              ),
            ),
            if (hasBills) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: bills.take(2).map((bill) {
                  Color dotColor;
                  if (bill.daysUntilBill <= 0) {
                    dotColor = const Color(0xFFE57373);
                  } else if (bill.daysUntilBill <= 3) {
                    dotColor = const Color(0xFFFFB74D);
                  } else {
                    dotColor = const Color(0xFF6495ED);
                  }
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 选中日期的账单
  Widget _buildSelectedDateBills(ThemeData theme, List<BillReminder> reminders) {
    final selectedDay = _selectedDate!.day;
    final bills = reminders.where((r) {
      if (r.frequency == ReminderFrequency.monthly) {
        return r.dayOfMonth == selectedDay;
      }
      return false;
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedDate!.month}月${_selectedDate!.day}日 账单',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: bills.isEmpty
                ? Center(
                    child: Text(
                      '当日无账单',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return _buildBillItem(theme, bill);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillItem(ThemeData theme, BillReminder bill) {
    return Container(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  bill.color.withValues(alpha: 0.8),
                  bill.color,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              bill.icon,
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
                  bill.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  bill.typeDisplayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: bill.daysUntilBill <= 0
                        ? const Color(0xFFE57373)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${bill.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 图例
  Widget _buildLegend(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(const Color(0xFFE57373), '紧急'),
          const SizedBox(width: 16),
          _buildLegendItem(const Color(0xFFFFB74D), '即将到期'),
          const SizedBox(width: 16),
          _buildLegendItem(const Color(0xFF6495ED), '正常'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
