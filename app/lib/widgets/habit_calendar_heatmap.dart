import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 习惯打卡记录
class HabitCheckInRecord {
  /// 日期
  final DateTime date;

  /// 是否已打卡
  final bool checked;

  /// 打卡次数（支持多次打卡）
  final int count;

  /// 习惯完成度（0-1）
  final double completionRate;

  /// 备注
  final String? note;

  /// 附加数据
  final Map<String, dynamic>? metadata;

  const HabitCheckInRecord({
    required this.date,
    this.checked = false,
    this.count = 0,
    this.completionRate = 0,
    this.note,
    this.metadata,
  });

  /// 获取日期键
  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 日历热力图配置
class HabitCalendarConfig {
  /// 单元格大小
  final double cellSize;

  /// 单元格间距
  final double cellGap;

  /// 单元格圆角
  final double cellRadius;

  /// 未打卡颜色
  final Color uncheckedColor;

  /// 已打卡颜色（最低完成度）
  final Color minCheckedColor;

  /// 已打卡颜色（最高完成度）
  final Color maxCheckedColor;

  /// 今日边框颜色
  final Color todayBorderColor;

  /// 是否显示月份标签
  final bool showMonthLabels;

  /// 是否显示星期标签
  final bool showWeekdayLabels;

  /// 是否显示连续天数
  final bool showStreak;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 动画时长
  final Duration animationDuration;

  /// 显示月数
  final int monthsToShow;

  /// 星期标签
  final List<String> weekdayLabels;

  /// 月份标签
  final List<String> monthLabels;

  const HabitCalendarConfig({
    this.cellSize = 14,
    this.cellGap = 3,
    this.cellRadius = 2,
    this.uncheckedColor = const Color(0xFFE8E8E8),
    this.minCheckedColor = const Color(0xFFC8E6C9),
    this.maxCheckedColor = const Color(0xFF2E7D32),
    this.todayBorderColor = const Color(0xFF1976D2),
    this.showMonthLabels = true,
    this.showWeekdayLabels = true,
    this.showStreak = true,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.monthsToShow = 12,
    this.weekdayLabels = const ['日', '一', '二', '三', '四', '五', '六'],
    this.monthLabels = const [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月'
    ],
  });
}

/// 习惯打卡日历热力图组件
///
/// 核心功能：
/// 1. GitHub风格的日历热力图
/// 2. 显示习惯打卡记录
/// 3. 支持点击查看详情
/// 4. 连续打卡天数展示
/// 5. 多种颜色深度表示完成度
///
/// 对应设计文档：第12.2节 习惯打卡日历热力图组件
/// 对应前端原型：7.16 习惯日历热力图
///
/// 使用示例：
/// ```dart
/// HabitCalendarHeatmap(
///   records: checkInRecords,
///   habitName: '记账',
///   onDayTap: (date, record) => showDetails(date, record),
/// )
/// ```
class HabitCalendarHeatmap extends StatefulWidget {
  /// 打卡记录
  final List<HabitCheckInRecord> records;

  /// 习惯名称
  final String? habitName;

  /// 配置
  final HabitCalendarConfig config;

  /// 日期点击回调
  final void Function(DateTime date, HabitCheckInRecord? record)? onDayTap;

  /// 起始日期
  final DateTime? startDate;

  /// 结束日期
  final DateTime? endDate;

  const HabitCalendarHeatmap({
    super.key,
    required this.records,
    this.habitName,
    this.config = const HabitCalendarConfig(),
    this.onDayTap,
    this.startDate,
    this.endDate,
  });

  @override
  State<HabitCalendarHeatmap> createState() => _HabitCalendarHeatmapState();
}

class _HabitCalendarHeatmapState extends State<HabitCalendarHeatmap>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  DateTime? _selectedDate;
  late Map<String, HabitCheckInRecord> _recordMap;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _setupDates();
    _buildRecordMap();
    _setupAnimation();
  }

  void _setupDates() {
    final now = DateTime.now();
    _endDate = widget.endDate ?? now;
    _startDate = widget.startDate ??
        DateTime(now.year, now.month - widget.config.monthsToShow + 1, 1);
  }

  void _buildRecordMap() {
    _recordMap = {};
    for (final record in widget.records) {
      _recordMap[record.dateKey] = record;
    }
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: widget.config.animationDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(HabitCalendarHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records) {
      _buildRecordMap();
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 获取日期记录
  HabitCheckInRecord? _getRecord(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _recordMap[key];
  }

  /// 获取单元格颜色
  Color _getCellColor(DateTime date) {
    final record = _getRecord(date);
    if (record == null || !record.checked) {
      return widget.config.uncheckedColor;
    }

    return Color.lerp(
      widget.config.minCheckedColor,
      widget.config.maxCheckedColor,
      record.completionRate.clamp(0.0, 1.0),
    )!;
  }

  /// 计算连续打卡天数
  int _calculateStreak() {
    int streak = 0;
    var date = DateTime.now();

    // 如果今天还没打卡，从昨天开始算
    final todayRecord = _getRecord(date);
    if (todayRecord == null || !todayRecord.checked) {
      date = date.subtract(const Duration(days: 1));
    }

    while (true) {
      final record = _getRecord(date);
      if (record != null && record.checked) {
        streak++;
        date = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// 计算总打卡天数
  int _calculateTotalCheckedDays() {
    return widget.records.where((r) => r.checked).length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题和统计
        if (widget.habitName != null) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.habitName!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '累计 ${_calculateTotalCheckedDays()} 天',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.config.showStreak)
                _buildStreakBadge(),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // 日历热力图
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 星期标签
                  if (widget.config.showWeekdayLabels)
                    Column(
                      children: [
                        SizedBox(
                            height: widget.config.showMonthLabels ? 20 : 0),
                        ...List.generate(7, (index) {
                          // 只显示部分标签避免拥挤
                          final showLabel = index % 2 == 1;
                          return Container(
                            height: widget.config.cellSize +
                                widget.config.cellGap,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 4),
                            child: showLabel
                                ? Text(
                                    widget.config.weekdayLabels[index],
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                : null,
                          );
                        }),
                      ],
                    ),

                  // 日历网格
                  _buildCalendarGrid(),
                ],
              ),
            );
          },
        ),

        // 图例
        const SizedBox(height: 12),
        _buildLegend(),

        // 选中信息
        if (_selectedDate != null) ...[
          const SizedBox(height: 12),
          _buildSelectedInfo(),
        ],
      ],
    );
  }

  /// 构建连续打卡徽章
  Widget _buildStreakBadge() {
    final streak = _calculateStreak();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: streak > 0
            ? widget.config.maxCheckedColor.withValues(alpha: 0.1)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            size: 16,
            color: streak > 0 ? widget.config.maxCheckedColor : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            '连续 $streak 天',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: streak > 0 ? widget.config.maxCheckedColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建日历网格
  Widget _buildCalendarGrid() {
    final weeks = <List<DateTime?>>[];
    var currentDate = _startDate;

    // 找到第一个周日
    while (currentDate.weekday != DateTime.sunday) {
      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    // 生成周数据
    while (currentDate.isBefore(_endDate) ||
        currentDate.isAtSameMomentAs(_endDate)) {
      final week = <DateTime?>[];
      for (int i = 0; i < 7; i++) {
        if (currentDate.isBefore(_startDate) || currentDate.isAfter(_endDate)) {
          week.add(null);
        } else {
          week.add(currentDate);
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 月份标签
        if (widget.config.showMonthLabels)
          SizedBox(
            height: 20,
            child: Row(
              children: _buildMonthLabels(weeks),
            ),
          ),

        // 日历格子
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: weeks.map((week) {
            return Column(
              children: week.map((date) {
                return _buildDayCell(date);
              }).toList(),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 构建月份标签
  List<Widget> _buildMonthLabels(List<List<DateTime?>> weeks) {
    final labels = <Widget>[];
    int? lastMonth;

    for (int weekIndex = 0; weekIndex < weeks.length; weekIndex++) {
      final week = weeks[weekIndex];
      final firstValidDate = week.firstWhere((d) => d != null, orElse: () => null);

      if (firstValidDate != null && firstValidDate.month != lastMonth) {
        labels.add(SizedBox(
          width: widget.config.cellSize + widget.config.cellGap,
          child: Text(
            widget.config.monthLabels[firstValidDate.month - 1],
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
        ));
        lastMonth = firstValidDate.month;
      } else {
        labels.add(SizedBox(
          width: widget.config.cellSize + widget.config.cellGap,
        ));
      }
    }

    return labels;
  }

  /// 构建日期单元格
  Widget _buildDayCell(DateTime? date) {
    if (date == null) {
      return SizedBox(
        width: widget.config.cellSize + widget.config.cellGap,
        height: widget.config.cellSize + widget.config.cellGap,
      );
    }

    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isSelected = _selectedDate != null &&
        date.year == _selectedDate!.year &&
        date.month == _selectedDate!.month &&
        date.day == _selectedDate!.day;

    return GestureDetector(
      onTap: () => _onDayTap(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.config.cellSize,
        height: widget.config.cellSize,
        margin: EdgeInsets.all(widget.config.cellGap / 2),
        decoration: BoxDecoration(
          color: _getCellColor(date).withValues(alpha: _animation.value),
          borderRadius: BorderRadius.circular(widget.config.cellRadius),
          border: isToday
              ? Border.all(
                  color: widget.config.todayBorderColor,
                  width: 2,
                )
              : isSelected
                  ? Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    )
                  : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  /// 构建图例
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '少',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(width: 4),
        ...List.generate(5, (i) {
          final color = i == 0
              ? widget.config.uncheckedColor
              : Color.lerp(
                  widget.config.minCheckedColor,
                  widget.config.maxCheckedColor,
                  i / 4,
                );
          return Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          '多',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// 构建选中信息
  Widget _buildSelectedInfo() {
    final record = _getRecord(_selectedDate!);
    final dateStr =
        '${_selectedDate!.year}年${_selectedDate!.month}月${_selectedDate!.day}日';
    final weekday = widget.config.weekdayLabels[_selectedDate!.weekday % 7];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: record?.checked == true
            ? widget.config.maxCheckedColor.withValues(alpha: 0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            record?.checked == true
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 24,
            color: record?.checked == true
                ? widget.config.maxCheckedColor
                : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateStr 周$weekday',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  record?.checked == true
                      ? '已打卡 · 完成度 ${(record!.completionRate * 100).toStringAsFixed(0)}%'
                      : '未打卡',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (record?.note != null)
                  Text(
                    record!.note!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 日期点击处理
  void _onDayTap(DateTime date) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _selectedDate = _selectedDate == date ? null : date;
    });

    widget.onDayTap?.call(date, _getRecord(date));
  }
}
