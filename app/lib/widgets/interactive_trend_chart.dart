import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 趋势数据点
class TrendDataPoint {
  /// X轴值（通常是日期时间戳）
  final double x;

  /// Y轴值（数值）
  final double y;

  /// 标签
  final String? label;

  /// 附加数据
  final Map<String, dynamic>? metadata;

  const TrendDataPoint({
    required this.x,
    required this.y,
    this.label,
    this.metadata,
  });
}

/// 趋势线配置
class TrendLineConfig {
  /// 线条颜色
  final Color lineColor;

  /// 线条宽度
  final double lineWidth;

  /// 填充颜色（渐变起始色）
  final Color? fillColor;

  /// 是否显示数据点
  final bool showDataPoints;

  /// 数据点半径
  final double dataPointRadius;

  /// 是否显示数值标签
  final bool showValueLabels;

  /// 是否平滑曲线
  final bool smoothCurve;

  /// 曲线张力（0-1，值越大越平滑）
  final double curveTension;

  /// 虚线模式
  final List<double>? dashPattern;

  const TrendLineConfig({
    this.lineColor = const Color(0xFF4CAF50),
    this.lineWidth = 2.0,
    this.fillColor,
    this.showDataPoints = true,
    this.dataPointRadius = 4.0,
    this.showValueLabels = false,
    this.smoothCurve = true,
    this.curveTension = 0.4,
    this.dashPattern,
  });
}

/// 趋势图配置
class TrendChartConfig {
  /// 是否显示网格
  final bool showGrid;

  /// 网格颜色
  final Color gridColor;

  /// X轴标签
  final List<String>? xLabels;

  /// Y轴标签数量
  final int yLabelCount;

  /// Y轴格式化
  final String Function(double value)? yFormatter;

  /// X轴格式化
  final String Function(double value)? xFormatter;

  /// 是否启用触摸交互
  final bool enableTouch;

  /// 是否启用缩放
  final bool enableZoom;

  /// 是否启用平移
  final bool enablePan;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 动画时长
  final Duration animationDuration;

  /// 图表内边距
  final EdgeInsets padding;

  /// 是否显示X轴
  final bool showXAxis;

  /// 是否显示Y轴
  final bool showYAxis;

  /// 是否显示图例
  final bool showLegend;

  const TrendChartConfig({
    this.showGrid = true,
    this.gridColor = const Color(0xFFE0E0E0),
    this.xLabels,
    this.yLabelCount = 5,
    this.yFormatter,
    this.xFormatter,
    this.enableTouch = true,
    this.enableZoom = false,
    this.enablePan = false,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 500),
    this.padding = const EdgeInsets.all(24),
    this.showXAxis = true,
    this.showYAxis = true,
    this.showLegend = false,
  });
}

/// 趋势系列数据
class TrendSeries {
  /// 系列名称
  final String name;

  /// 数据点
  final List<TrendDataPoint> data;

  /// 线条配置
  final TrendLineConfig config;

  const TrendSeries({
    required this.name,
    required this.data,
    this.config = const TrendLineConfig(),
  });
}

/// 趋势图交互回调
typedef TrendChartTapCallback = void Function(
  TrendSeries series,
  TrendDataPoint point,
  int index,
);

/// 交互式趋势图组件
///
/// 核心功能：
/// 1. 多系列数据展示
/// 2. 触摸��互（点击、长按、拖拽）
/// 3. 数据点高亮与提示
/// 4. 平滑曲线与动画
/// 5. 支持下钻到具体交易
///
/// 对应设计文档：第12.2节 趋势图组件
/// 对应前端原型：7.03 趋势图
///
/// 使用示例：
/// ```dart
/// InteractiveTrendChart(
///   series: [
///     TrendSeries(
///       name: '支出',
///       data: expenseData,
///       config: TrendLineConfig(lineColor: Colors.red),
///     ),
///     TrendSeries(
///       name: '收入',
///       data: incomeData,
///       config: TrendLineConfig(lineColor: Colors.green),
///     ),
///   ],
///   onTap: (series, point, index) => showDetails(point),
/// )
/// ```
class InteractiveTrendChart extends StatefulWidget {
  /// 数���系列
  final List<TrendSeries> series;

  /// 图表配置
  final TrendChartConfig config;

  /// 点击回调
  final TrendChartTapCallback? onTap;

  /// 长按回调
  final TrendChartTapCallback? onLongPress;

  /// 标题
  final String? title;

  /// 副标题
  final String? subtitle;

  /// 图表高度
  final double height;

  const InteractiveTrendChart({
    super.key,
    required this.series,
    this.config = const TrendChartConfig(),
    this.onTap,
    this.onLongPress,
    this.title,
    this.subtitle,
    this.height = 250,
  });

  @override
  State<InteractiveTrendChart> createState() => _InteractiveTrendChartState();
}

class _InteractiveTrendChartState extends State<InteractiveTrendChart>
    with SingleTickerProviderStateMixin {
  /// 动画控制器
  late AnimationController _animationController;
  late Animation<double> _animation;

  /// 选中的数据点
  int? _selectedSeriesIndex;
  int? _selectedPointIndex;

  /// 触摸位置
  Offset? _touchPosition;

  /// 数据范围
  late double _minX, _maxX, _minY, _maxY;

  @override
  void initState() {
    super.initState();
    _calculateDataRange();
    _setupAnimation();
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
  void didUpdateWidget(InteractiveTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) {
      _calculateDataRange();
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 计算数据范围
  void _calculateDataRange() {
    if (widget.series.isEmpty) {
      _minX = 0;
      _maxX = 1;
      _minY = 0;
      _maxY = 1;
      return;
    }

    final allPoints = widget.series.expand((s) => s.data).toList();
    if (allPoints.isEmpty) {
      _minX = 0;
      _maxX = 1;
      _minY = 0;
      _maxY = 1;
      return;
    }

    _minX = allPoints.map((p) => p.x).reduce(math.min);
    _maxX = allPoints.map((p) => p.x).reduce(math.max);
    _minY = allPoints.map((p) => p.y).reduce(math.min);
    _maxY = allPoints.map((p) => p.y).reduce(math.max);

    // 添加边距
    final yRange = _maxY - _minY;
    if (yRange == 0) {
      _minY -= 1;
      _maxY += 1;
    } else {
      _minY -= yRange * 0.1;
      _maxY += yRange * 0.1;
    }

    // 确保Y轴从0开始（如果数据都是正数）
    if (_minY > 0) {
      _minY = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          const SizedBox(height: 16),
        ],

        // 图表主体
        SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return GestureDetector(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onLongPressStart: _onLongPressStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _TrendChartPainter(
                    series: widget.series,
                    config: widget.config,
                    animationValue: _animation.value,
                    minX: _minX,
                    maxX: _maxX,
                    minY: _minY,
                    maxY: _maxY,
                    selectedSeriesIndex: _selectedSeriesIndex,
                    selectedPointIndex: _selectedPointIndex,
                    touchPosition: _touchPosition,
                    context: context,
                  ),
                ),
              );
            },
          ),
        ),

        // 图例
        if (widget.config.showLegend && widget.series.length > 1) ...[
          const SizedBox(height: 16),
          _buildLegend(),
        ],

        // 选中信息
        if (_selectedSeriesIndex != null && _selectedPointIndex != null) ...[
          const SizedBox(height: 12),
          _buildSelectedInfo(),
        ],
      ],
    );
  }

  /// 构建图例
  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: widget.series.map((series) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: series.config.lineColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              series.name,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// 构建选中信息
  Widget _buildSelectedInfo() {
    final series = widget.series[_selectedSeriesIndex!];
    final point = series.data[_selectedPointIndex!];

    final xLabel = widget.config.xFormatter?.call(point.x) ?? point.x.toString();
    final yLabel = widget.config.yFormatter?.call(point.y) ?? '¥${point.y.toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: series.config.lineColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: series.config.lineColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${series.name}: $xLabel - $yLabel',
              style: TextStyle(
                fontSize: 13,
                color: series.config.lineColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (point.label != null)
            Text(
              point.label!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  /// 触摸开始
  void _onTapDown(TapDownDetails details) {
    _touchPosition = details.localPosition;
    _findNearestPoint(details.localPosition);
  }

  /// 触摸结束
  void _onTapUp(TapUpDetails details) {
    if (_selectedSeriesIndex != null && _selectedPointIndex != null) {
      if (widget.config.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      final series = widget.series[_selectedSeriesIndex!];
      final point = series.data[_selectedPointIndex!];
      widget.onTap?.call(series, point, _selectedPointIndex!);
    }
  }

  /// 长按开始
  void _onLongPressStart(LongPressStartDetails details) {
    _touchPosition = details.localPosition;
    _findNearestPoint(details.localPosition);

    if (_selectedSeriesIndex != null && _selectedPointIndex != null) {
      if (widget.config.enableHapticFeedback) {
        HapticFeedback.mediumImpact();
      }

      final series = widget.series[_selectedSeriesIndex!];
      final point = series.data[_selectedPointIndex!];
      widget.onLongPress?.call(series, point, _selectedPointIndex!);
    }
  }

  /// 拖拽更新
  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.config.enableTouch) return;

    setState(() {
      _touchPosition = details.localPosition;
    });
    _findNearestPoint(details.localPosition);
  }

  /// 拖拽结束
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _touchPosition = null;
    });
  }

  /// 查找最近的数据点
  void _findNearestPoint(Offset position) {
    if (widget.series.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final padding = widget.config.padding;
    final chartArea = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );

    if (!chartArea.contains(position)) {
      setState(() {
        _selectedSeriesIndex = null;
        _selectedPointIndex = null;
      });
      return;
    }

    // 将触摸位置转换为数据坐标
    final touchX = _minX +
        ((position.dx - chartArea.left) / chartArea.width) * (_maxX - _minX);

    // 找到最近的数据点
    double minDistance = double.infinity;
    int? nearestSeriesIndex;
    int? nearestPointIndex;

    for (int sIdx = 0; sIdx < widget.series.length; sIdx++) {
      final series = widget.series[sIdx];
      for (int pIdx = 0; pIdx < series.data.length; pIdx++) {
        final point = series.data[pIdx];
        final distance = (point.x - touchX).abs();
        if (distance < minDistance) {
          minDistance = distance;
          nearestSeriesIndex = sIdx;
          nearestPointIndex = pIdx;
        }
      }
    }

    if (nearestSeriesIndex != _selectedSeriesIndex ||
        nearestPointIndex != _selectedPointIndex) {
      setState(() {
        _selectedSeriesIndex = nearestSeriesIndex;
        _selectedPointIndex = nearestPointIndex;
      });

      if (widget.config.enableHapticFeedback) {
        HapticFeedback.selectionClick();
      }
    }
  }
}

/// 趋势图绑定器
class _TrendChartPainter extends CustomPainter {
  final List<TrendSeries> series;
  final TrendChartConfig config;
  final double animationValue;
  final double minX, maxX, minY, maxY;
  final int? selectedSeriesIndex;
  final int? selectedPointIndex;
  final Offset? touchPosition;
  final BuildContext context;

  _TrendChartPainter({
    required this.series,
    required this.config,
    required this.animationValue,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.selectedSeriesIndex,
    required this.selectedPointIndex,
    required this.touchPosition,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartArea = Rect.fromLTWH(
      config.padding.left,
      config.padding.top,
      size.width - config.padding.horizontal,
      size.height - config.padding.vertical,
    );

    // 绘制网格
    if (config.showGrid) {
      _drawGrid(canvas, chartArea);
    }

    // 绘制坐标轴
    if (config.showXAxis || config.showYAxis) {
      _drawAxes(canvas, chartArea);
    }

    // 绘制数据线
    for (int i = 0; i < series.length; i++) {
      _drawSeries(canvas, chartArea, series[i], i);
    }

    // 绘制选中指示器
    if (touchPosition != null && selectedSeriesIndex != null) {
      _drawTouchIndicator(canvas, chartArea);
    }
  }

  /// 绘制网格
  void _drawGrid(Canvas canvas, Rect chartArea) {
    final paint = Paint()
      ..color = config.gridColor
      ..strokeWidth = 0.5;

    // 水平网格线
    for (int i = 0; i <= config.yLabelCount; i++) {
      final y = chartArea.top +
          (chartArea.height * i / config.yLabelCount);
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        paint,
      );
    }

    // 垂直网格线（按数据点数量）
    if (series.isNotEmpty && series.first.data.isNotEmpty) {
      final pointCount = series.first.data.length;
      for (int i = 0; i < pointCount; i++) {
        final x = chartArea.left +
            (chartArea.width * i / (pointCount - 1).clamp(1, double.infinity));
        canvas.drawLine(
          Offset(x, chartArea.top),
          Offset(x, chartArea.bottom),
          paint..color = config.gridColor.withValues(alpha: 0.3),
        );
      }
    }
  }

  /// 绘制坐标轴
  void _drawAxes(Canvas canvas, Rect chartArea) {
    final textStyle = TextStyle(
      fontSize: 10,
      color: Colors.grey[600],
    );

    // Y轴标签
    if (config.showYAxis) {
      for (int i = 0; i <= config.yLabelCount; i++) {
        final value = maxY - (maxY - minY) * i / config.yLabelCount;
        final label = config.yFormatter?.call(value) ??
            value.toStringAsFixed(0);
        final y = chartArea.top + (chartArea.height * i / config.yLabelCount);

        final textSpan = TextSpan(text: label, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            chartArea.left - textPainter.width - 8,
            y - textPainter.height / 2,
          ),
        );
      }
    }

    // X轴标签
    if (config.showXAxis && config.xLabels != null) {
      final labels = config.xLabels!;
      for (int i = 0; i < labels.length; i++) {
        final x = chartArea.left +
            (chartArea.width * i / (labels.length - 1).clamp(1, double.infinity));

        final textSpan = TextSpan(text: labels[i], style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            x - textPainter.width / 2,
            chartArea.bottom + 8,
          ),
        );
      }
    }
  }

  /// 绘制数据系列
  void _drawSeries(Canvas canvas, Rect chartArea, TrendSeries s, int seriesIndex) {
    if (s.data.isEmpty) return;

    final linePaint = Paint()
      ..color = s.config.lineColor
      ..strokeWidth = s.config.lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 计算数据点在画布上的位置
    final points = s.data.map((p) {
      final x = chartArea.left +
          ((p.x - minX) / (maxX - minX)) * chartArea.width;
      final y = chartArea.bottom -
          ((p.y - minY) / (maxY - minY)) * chartArea.height * animationValue;
      return Offset(x, y);
    }).toList();

    // 绘制填充区域
    if (s.config.fillColor != null) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, chartArea.bottom);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, chartArea.bottom);
      fillPath.close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          s.config.fillColor!.withValues(alpha: 0.4),
          s.config.fillColor!.withValues(alpha: 0.0),
        ],
      );

      final fillPaint = Paint()
        ..shader = gradient.createShader(chartArea);
      canvas.drawPath(fillPath, fillPaint);
    }

    // 绘制线条
    final linePath = Path();
    if (s.config.smoothCurve && points.length > 2) {
      _drawSmoothCurve(linePath, points, s.config.curveTension);
    } else {
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
    }

    if (s.config.dashPattern != null) {
      // 虚线
      _drawDashedPath(canvas, linePath, linePaint, s.config.dashPattern!);
    } else {
      canvas.drawPath(linePath, linePaint);
    }

    // 绘制数据点
    if (s.config.showDataPoints) {
      final pointPaint = Paint()
        ..color = s.config.lineColor
        ..style = PaintingStyle.fill;

      final pointBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      for (int i = 0; i < points.length; i++) {
        final isSelected = seriesIndex == selectedSeriesIndex &&
            i == selectedPointIndex;
        final radius = isSelected
            ? s.config.dataPointRadius * 1.5
            : s.config.dataPointRadius;

        // 白色边框
        canvas.drawCircle(points[i], radius + 2, pointBorderPaint);
        // 颜色填充
        canvas.drawCircle(points[i], radius, pointPaint);
      }
    }
  }

  /// 绘制平滑曲线
  void _drawSmoothCurve(Path path, List<Offset> points, double tension) {
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      final cp1x = p1.dx + (p2.dx - p0.dx) * tension / 3;
      final cp1y = p1.dy + (p2.dy - p0.dy) * tension / 3;
      final cp2x = p2.dx - (p3.dx - p1.dx) * tension / 3;
      final cp2y = p2.dy - (p3.dy - p1.dy) * tension / 3;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
  }

  /// 绘制虚线路径
  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> pattern,
  ) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      int patternIndex = 0;
      bool draw = true;

      while (distance < metric.length) {
        final length = pattern[patternIndex % pattern.length];
        if (draw) {
          final extractPath = metric.extractPath(
            distance,
            math.min(distance + length, metric.length),
          );
          canvas.drawPath(extractPath, paint);
        }
        distance += length;
        patternIndex++;
        draw = !draw;
      }
    }
  }

  /// 绘制触摸指示器
  void _drawTouchIndicator(Canvas canvas, Rect chartArea) {
    if (selectedSeriesIndex == null || selectedPointIndex == null) return;

    final s = series[selectedSeriesIndex!];
    final point = s.data[selectedPointIndex!];

    final x = chartArea.left +
        ((point.x - minX) / (maxX - minX)) * chartArea.width;
    final y = chartArea.bottom -
        ((point.y - minY) / (maxY - minY)) * chartArea.height;

    // 垂直指示线
    final linePaint = Paint()
      ..color = s.config.lineColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(x, chartArea.top),
      Offset(x, chartArea.bottom),
      linePaint,
    );

    // 选中点高亮
    final highlightPaint = Paint()
      ..color = s.config.lineColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 20, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.selectedSeriesIndex != selectedSeriesIndex ||
        oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.touchPosition != touchPosition ||
        oldDelegate.series != series;
  }
}
