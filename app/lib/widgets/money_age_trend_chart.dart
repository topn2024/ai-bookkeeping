import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/resource_pool.dart';
import '../services/money_age_level_service.dart';

/// 钱龄趋势图组件
///
/// 功能：
/// 1. 显示钱龄历史趋势
/// 2. 支持点击下钻查看详情
/// 3. 显示等级分区背景
/// 4. 支持缩放和平移
class MoneyAgeTrendChart extends StatefulWidget {
  /// 每日钱龄数据
  final List<DailyMoneyAge> data;

  /// 日期点击回调
  final Function(DateTime date)? onDateTap;

  /// 图表高度
  final double height;

  /// 是否显示等级区域
  final bool showLevelZones;

  /// 是否显示网格线
  final bool showGrid;

  /// 是否显示数据点
  final bool showDataPoints;

  /// 时间范围（天）
  final int? visibleDays;

  const MoneyAgeTrendChart({
    super.key,
    required this.data,
    this.onDateTap,
    this.height = 200,
    this.showLevelZones = true,
    this.showGrid = true,
    this.showDataPoints = true,
    this.visibleDays,
  });

  @override
  State<MoneyAgeTrendChart> createState() => _MoneyAgeTrendChartState();
}

class _MoneyAgeTrendChartState extends State<MoneyAgeTrendChart> {
  int? _selectedIndex;
  final _dateFormat = DateFormat('MM/dd');

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            '暂无趋势数据',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选中信息显示
        if (_selectedIndex != null) _buildSelectedInfo(),

        // 图表主体
        SizedBox(
          height: widget.height,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TrendChartPainter(
                data: _getVisibleData(),
                selectedIndex: _selectedIndex,
                showLevelZones: widget.showLevelZones,
                showGrid: widget.showGrid,
                showDataPoints: widget.showDataPoints,
                primaryColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),

        // X轴日期标签
        const SizedBox(height: 8),
        _buildXAxisLabels(),
      ],
    );
  }

  List<DailyMoneyAge> _getVisibleData() {
    if (widget.visibleDays == null) return widget.data;
    return widget.data.take(widget.visibleDays!).toList();
  }

  Widget _buildSelectedInfo() {
    final data = _getVisibleData();
    if (_selectedIndex == null || _selectedIndex! >= data.length) {
      return const SizedBox.shrink();
    }

    final selected = data[_selectedIndex!];
    final levelService = MoneyAgeLevelService();
    final level = levelService.determineLevel(selected.averageAge);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: level.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(level.icon, color: level.color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('yyyy年MM月dd日').format(selected.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${selected.averageAge}天',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: level.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: level.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        level.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: level.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _selectedIndex = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildXAxisLabels() {
    final data = _getVisibleData();
    if (data.isEmpty) return const SizedBox.shrink();

    // 显示5个标签点
    final labelCount = 5;
    final step = (data.length - 1) / (labelCount - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(labelCount, (index) {
        final dataIndex = (index * step).round().clamp(0, data.length - 1);
        return Text(
          _dateFormat.format(data[dataIndex].date),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        );
      }),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    final data = _getVisibleData();
    if (data.isEmpty) return;

    final box = context.findRenderObject() as RenderBox;
    final localPosition = details.localPosition;
    final width = box.size.width;

    // 计算点击位置对应的数据索引
    final padding = 16.0; // 左右内边距
    final chartWidth = width - padding * 2;
    final x = localPosition.dx - padding;
    final stepX = chartWidth / (data.length - 1);
    final index = (x / stepX).round().clamp(0, data.length - 1);

    setState(() {
      _selectedIndex = index;
    });

    // 触发外部回调
    widget.onDateTap?.call(data[index].date);
  }
}

/// 趋势图绘制器
class _TrendChartPainter extends CustomPainter {
  final List<DailyMoneyAge> data;
  final int? selectedIndex;
  final bool showLevelZones;
  final bool showGrid;
  final bool showDataPoints;
  final Color primaryColor;

  _TrendChartPainter({
    required this.data,
    this.selectedIndex,
    required this.showLevelZones,
    required this.showGrid,
    required this.showDataPoints,
    required this.primaryColor,
  });

  static const _padding = EdgeInsets.only(
    left: 40, // Y轴标签空间
    right: 16,
    top: 16,
    bottom: 8,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartRect = Rect.fromLTWH(
      _padding.left,
      _padding.top,
      size.width - _padding.horizontal,
      size.height - _padding.vertical,
    );

    // 计算数据范围
    final ages = data.map((d) => d.averageAge).toList();
    final minAge = ages.reduce((a, b) => a < b ? a : b);
    final maxAge = ages.reduce((a, b) => a > b ? a : b);

    // 调整范围以显示完整的等级区域
    final yMin = (minAge - 5).clamp(0, 1000);
    final yMax = maxAge + 10;

    // 绘制等级区域背景
    if (showLevelZones) {
      _drawLevelZones(canvas, chartRect, yMin.toDouble(), yMax.toDouble());
    }

    // 绘制网格
    if (showGrid) {
      _drawGrid(canvas, chartRect, yMin.toDouble(), yMax.toDouble());
    }

    // 绘制Y轴标签
    _drawYAxisLabels(canvas, chartRect, yMin.toDouble(), yMax.toDouble());

    // 绘制折线和数据点
    _drawLine(canvas, chartRect, yMin.toDouble(), yMax.toDouble());

    // 绘制选中点
    if (selectedIndex != null) {
      _drawSelectedPoint(canvas, chartRect, yMin.toDouble(), yMax.toDouble());
    }
  }

  void _drawLevelZones(Canvas canvas, Rect rect, double yMin, double yMax) {
    final levelZones = [
      (0, 7, Colors.red.withValues(alpha: 0.1)),
      (7, 14, Colors.orange.withValues(alpha: 0.1)),
      (14, 30, Colors.yellow.withValues(alpha: 0.1)),
      (30, 60, Colors.lightGreen.withValues(alpha: 0.1)),
      (60, 90, Colors.green.withValues(alpha: 0.1)),
      (90, yMax.toInt() + 10, Colors.teal.withValues(alpha: 0.1)),
    ];

    for (final zone in levelZones) {
      final zoneMin = zone.$1.toDouble().clamp(yMin, yMax);
      final zoneMax = zone.$2.toDouble().clamp(yMin, yMax);

      if (zoneMax <= yMin || zoneMin >= yMax) continue;

      final top = rect.bottom - ((zoneMax - yMin) / (yMax - yMin)) * rect.height;
      final bottom = rect.bottom - ((zoneMin - yMin) / (yMax - yMin)) * rect.height;

      canvas.drawRect(
        Rect.fromLTRB(rect.left, top, rect.right, bottom),
        Paint()..color = zone.$3,
      );
    }
  }

  void _drawGrid(Canvas canvas, Rect rect, double yMin, double yMax) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;

    // 水平网格线
    final yStep = ((yMax - yMin) / 4).ceilToDouble();
    for (var y = yMin; y <= yMax; y += yStep) {
      final yPos = rect.bottom - ((y - yMin) / (yMax - yMin)) * rect.height;
      canvas.drawLine(
        Offset(rect.left, yPos),
        Offset(rect.right, yPos),
        gridPaint,
      );
    }

    // 垂直网格线
    final xStep = rect.width / 4;
    for (var i = 0; i <= 4; i++) {
      final xPos = rect.left + xStep * i;
      canvas.drawLine(
        Offset(xPos, rect.top),
        Offset(xPos, rect.bottom),
        gridPaint,
      );
    }
  }

  void _drawYAxisLabels(Canvas canvas, Rect rect, double yMin, double yMax) {
    final textStyle = TextStyle(
      fontSize: 10,
      color: Colors.grey.shade600,
    );

    final yStep = ((yMax - yMin) / 4).ceilToDouble();
    for (var y = yMin; y <= yMax; y += yStep) {
      final yPos = rect.bottom - ((y - yMin) / (yMax - yMin)) * rect.height;

      final textSpan = TextSpan(text: '${y.toInt()}', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(rect.left - textPainter.width - 8, yPos - textPainter.height / 2),
      );
    }
  }

  void _drawLine(Canvas canvas, Rect rect, double yMin, double yMax) {
    if (data.length < 2) return;

    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = rect.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = rect.left + stepX * i;
      final normalizedY = (data[i].averageAge - yMin) / (yMax - yMin);
      final y = rect.bottom - normalizedY * rect.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, rect.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(rect.right, rect.bottom);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // 绘制数据点
    if (showDataPoints && data.length <= 30) {
      final pointPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;

      for (var i = 0; i < data.length; i++) {
        final x = rect.left + stepX * i;
        final normalizedY = (data[i].averageAge - yMin) / (yMax - yMin);
        final y = rect.bottom - normalizedY * rect.height;

        canvas.drawCircle(Offset(x, y), 3, pointPaint);
      }
    }
  }

  void _drawSelectedPoint(Canvas canvas, Rect rect, double yMin, double yMax) {
    if (selectedIndex == null || selectedIndex! >= data.length) return;

    final stepX = rect.width / (data.length - 1);
    final x = rect.left + stepX * selectedIndex!;
    final normalizedY = (data[selectedIndex!].averageAge - yMin) / (yMax - yMin);
    final y = rect.bottom - normalizedY * rect.height;

    // 垂直辅助线
    canvas.drawLine(
      Offset(x, rect.top),
      Offset(x, rect.bottom),
      Paint()
        ..color = primaryColor.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );

    // 选中点
    canvas.drawCircle(
      Offset(x, y),
      6,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(x, y),
      5,
      Paint()..color = primaryColor,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return data != oldDelegate.data ||
        selectedIndex != oldDelegate.selectedIndex ||
        showLevelZones != oldDelegate.showLevelZones ||
        showGrid != oldDelegate.showGrid ||
        showDataPoints != oldDelegate.showDataPoints ||
        primaryColor != oldDelegate.primaryColor;
  }
}

/// 钱龄趋势对比图
class MoneyAgeTrendComparisonChart extends StatelessWidget {
  /// 当前周期数据
  final List<DailyMoneyAge> currentData;

  /// 上一周期数据（用于对比）
  final List<DailyMoneyAge> previousData;

  /// 图表高度
  final double height;

  const MoneyAgeTrendComparisonChart({
    super.key,
    required this.currentData,
    required this.previousData,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _ComparisonChartPainter(
          currentData: currentData,
          previousData: previousData,
          currentColor: Theme.of(context).colorScheme.primary,
          previousColor: Colors.grey,
        ),
      ),
    );
  }
}

class _ComparisonChartPainter extends CustomPainter {
  final List<DailyMoneyAge> currentData;
  final List<DailyMoneyAge> previousData;
  final Color currentColor;
  final Color previousColor;

  _ComparisonChartPainter({
    required this.currentData,
    required this.previousData,
    required this.currentColor,
    required this.previousColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final allAges = [
      ...currentData.map((d) => d.averageAge),
      ...previousData.map((d) => d.averageAge),
    ];

    if (allAges.isEmpty) return;

    final minAge = allAges.reduce((a, b) => a < b ? a : b);
    final maxAge = allAges.reduce((a, b) => a > b ? a : b);

    final padding = const EdgeInsets.all(16);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );

    // 绘制上一周期（虚线）
    _drawDataLine(
      canvas,
      chartRect,
      previousData,
      minAge.toDouble(),
      maxAge.toDouble(),
      previousColor,
      isDashed: true,
    );

    // 绘制当前周期（实线）
    _drawDataLine(
      canvas,
      chartRect,
      currentData,
      minAge.toDouble(),
      maxAge.toDouble(),
      currentColor,
      isDashed: false,
    );
  }

  void _drawDataLine(
    Canvas canvas,
    Rect rect,
    List<DailyMoneyAge> data,
    double yMin,
    double yMax,
    Color color, {
    required bool isDashed,
  }) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = rect.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = rect.left + stepX * i;
      final normalizedY = (data[i].averageAge - yMin) / (yMax - yMin);
      final y = rect.bottom - normalizedY * rect.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (isDashed) {
      // 简化的虚线绘制
      final dashPath = Path();
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final segment = metric.extractPath(distance, distance + 5);
          dashPath.addPath(segment, Offset.zero);
          distance += 10;
        }
      }
      canvas.drawPath(dashPath, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ComparisonChartPainter oldDelegate) {
    return currentData != oldDelegate.currentData ||
        previousData != oldDelegate.previousData;
  }
}
