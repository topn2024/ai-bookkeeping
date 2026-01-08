import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 图表渲染优化服务
///
/// 提供高性能图表渲染，包括数据采样、缓存、增量更新等优化策略
///
/// 对应实施方案：轨道L 测试与质量保障模块

// ==================== 数据采样策略 ====================

/// 数据采样器
class ChartDataSampler {
  /// LTTB 算法（Largest Triangle Three Buckets）
  /// 保持数据可视化特征的高效降采样算法
  static List<ChartDataPoint> downsampleLTTB(
    List<ChartDataPoint> data,
    int threshold,
  ) {
    if (data.length <= threshold) return data;
    if (threshold < 3) return data;

    final sampled = <ChartDataPoint>[];
    final bucketSize = (data.length - 2) / (threshold - 2);

    // 始终保留第一个点
    sampled.add(data.first);

    for (int i = 0; i < threshold - 2; i++) {
      final bucketStart = ((i) * bucketSize).floor() + 1;
      final bucketEnd = ((i + 1) * bucketSize).floor() + 1;

      // 计算下一个桶的平均值
      final nextBucketStart = ((i + 1) * bucketSize).floor() + 1;
      final nextBucketEnd = math.min(
        ((i + 2) * bucketSize).floor() + 1,
        data.length,
      );

      double avgX = 0, avgY = 0;
      int count = 0;
      for (int j = nextBucketStart; j < nextBucketEnd; j++) {
        avgX += data[j].x;
        avgY += data[j].y;
        count++;
      }
      avgX /= count;
      avgY /= count;

      // 在当前桶中找到与三角形面积最大的点
      double maxArea = -1;
      int maxAreaIndex = bucketStart;

      final prevPoint = sampled.last;

      for (int j = bucketStart; j < bucketEnd && j < data.length; j++) {
        final area = ((prevPoint.x - avgX) * (data[j].y - prevPoint.y) -
                (prevPoint.x - data[j].x) * (avgY - prevPoint.y))
            .abs();

        if (area > maxArea) {
          maxArea = area;
          maxAreaIndex = j;
        }
      }

      sampled.add(data[maxAreaIndex]);
    }

    // 始终保留最后一个点
    sampled.add(data.last);

    return sampled;
  }

  /// 简单均匀采样
  static List<ChartDataPoint> downsampleUniform(
    List<ChartDataPoint> data,
    int threshold,
  ) {
    if (data.length <= threshold) return data;

    final sampled = <ChartDataPoint>[];
    final step = data.length / threshold;

    for (int i = 0; i < threshold; i++) {
      final index = (i * step).floor();
      sampled.add(data[index]);
    }

    return sampled;
  }

  /// 最大最小值采样（保留极值）
  static List<ChartDataPoint> downsampleMinMax(
    List<ChartDataPoint> data,
    int threshold,
  ) {
    if (data.length <= threshold) return data;

    final sampled = <ChartDataPoint>[];
    final bucketSize = data.length / (threshold / 2);

    for (int i = 0; i < threshold / 2; i++) {
      final start = (i * bucketSize).floor();
      final end = math.min(((i + 1) * bucketSize).floor(), data.length);

      ChartDataPoint? minPoint, maxPoint;
      for (int j = start; j < end; j++) {
        if (minPoint == null || data[j].y < minPoint.y) {
          minPoint = data[j];
        }
        if (maxPoint == null || data[j].y > maxPoint.y) {
          maxPoint = data[j];
        }
      }

      if (minPoint != null) {
        if (minPoint.x < (maxPoint?.x ?? double.infinity)) {
          sampled.add(minPoint);
          if (maxPoint != null && maxPoint != minPoint) {
            sampled.add(maxPoint);
          }
        } else {
          if (maxPoint != null) sampled.add(maxPoint);
          if (minPoint != maxPoint) sampled.add(minPoint);
        }
      }
    }

    return sampled;
  }
}

/// 图表数据点
class ChartDataPoint {
  final double x;
  final double y;
  final String? label;
  final Color? color;
  final Map<String, dynamic>? metadata;

  const ChartDataPoint({
    required this.x,
    required this.y,
    this.label,
    this.color,
    this.metadata,
  });

  ChartDataPoint copyWith({
    double? x,
    double? y,
    String? label,
    Color? color,
    Map<String, dynamic>? metadata,
  }) {
    return ChartDataPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      label: label ?? this.label,
      color: color ?? this.color,
      metadata: metadata ?? this.metadata,
    );
  }
}

// ==================== 图表缓存管理 ====================

/// 图表渲染缓存
class ChartRenderCache {
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheDuration;
  final int _maxCacheSize;

  ChartRenderCache({
    Duration cacheDuration = const Duration(minutes: 5),
    int maxCacheSize = 20,
  })  : _cacheDuration = cacheDuration,
        _maxCacheSize = maxCacheSize;

  /// 获取缓存的图像
  ui.Image? get(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;

    if (DateTime.now().difference(timestamp) > _cacheDuration) {
      remove(key);
      return null;
    }

    return _imageCache[key];
  }

  /// 缓存图像
  void put(String key, ui.Image image) {
    // 清理过期缓存
    _cleanExpired();

    // 如果超过最大数量，移除最旧的
    if (_imageCache.length >= _maxCacheSize) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      remove(oldestKey);
    }

    _imageCache[key] = image;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// 移除缓存
  void remove(String key) {
    _imageCache[key]?.dispose();
    _imageCache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// 清理过期缓存
  void _cleanExpired() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((e) => now.difference(e.value) > _cacheDuration)
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      remove(key);
    }
  }

  /// 清除所有缓存
  void clear() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
    _cacheTimestamps.clear();
  }

  /// 缓存大小
  int get size => _imageCache.length;
}

// ==================== 优化的图表组件 ====================

/// 优化的折线图
class OptimizedLineChart extends StatefulWidget {
  final List<ChartDataPoint> data;
  final Color lineColor;
  final double lineWidth;
  final bool showPoints;
  final double pointRadius;
  final bool showArea;
  final Color? areaColor;
  final bool animate;
  final Duration animationDuration;
  final int downsampleThreshold;
  final bool enableCache;

  const OptimizedLineChart({
    super.key,
    required this.data,
    this.lineColor = Colors.blue,
    this.lineWidth = 2.0,
    this.showPoints = false,
    this.pointRadius = 4.0,
    this.showArea = false,
    this.areaColor,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.downsampleThreshold = 200,
    this.enableCache = true,
  });

  @override
  State<OptimizedLineChart> createState() => _OptimizedLineChartState();
}

class _OptimizedLineChartState extends State<OptimizedLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<ChartDataPoint> _sampledData = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _prepareData();

    if (widget.animate) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  void _prepareData() {
    if (widget.data.length > widget.downsampleThreshold) {
      _sampledData = ChartDataSampler.downsampleLTTB(
        widget.data,
        widget.downsampleThreshold,
      );
    } else {
      _sampledData = widget.data;
    }
  }

  @override
  void didUpdateWidget(OptimizedLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _prepareData();
      if (widget.animate) {
        _animationController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _LineChartPainter(
            data: _sampledData,
            lineColor: widget.lineColor,
            lineWidth: widget.lineWidth,
            showPoints: widget.showPoints,
            pointRadius: widget.pointRadius,
            showArea: widget.showArea,
            areaColor: widget.areaColor ?? widget.lineColor.withValues(alpha: 0.2),
            progress: _animation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// 折线图绘制器
class _LineChartPainter extends CustomPainter {
  final List<ChartDataPoint> data;
  final Color lineColor;
  final double lineWidth;
  final bool showPoints;
  final double pointRadius;
  final bool showArea;
  final Color areaColor;
  final double progress;

  _LineChartPainter({
    required this.data,
    required this.lineColor,
    required this.lineWidth,
    required this.showPoints,
    required this.pointRadius,
    required this.showArea,
    required this.areaColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 计算数据范围
    double minX = data.first.x, maxX = data.first.x;
    double minY = data.first.y, maxY = data.first.y;

    for (final point in data) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minY = math.min(minY, point.y);
      maxY = math.max(maxY, point.y);
    }

    // 添加 padding
    final padding = 20.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // 坐标转换
    Offset toCanvas(ChartDataPoint point) {
      final x = padding + (point.x - minX) / (maxX - minX) * chartWidth;
      final y = padding + chartHeight - (point.y - minY) / (maxY - minY) * chartHeight;
      return Offset(x, y);
    }

    // 应用进度动画
    final visibleCount = (data.length * progress).ceil();
    final visibleData = data.take(visibleCount).toList();

    if (visibleData.isEmpty) return;

    // 绘制区域
    if (showArea && visibleData.length > 1) {
      final areaPath = Path();
      final firstPoint = toCanvas(visibleData.first);
      areaPath.moveTo(firstPoint.dx, size.height - padding);
      areaPath.lineTo(firstPoint.dx, firstPoint.dy);

      for (int i = 1; i < visibleData.length; i++) {
        final point = toCanvas(visibleData[i]);
        areaPath.lineTo(point.dx, point.dy);
      }

      final lastPoint = toCanvas(visibleData.last);
      areaPath.lineTo(lastPoint.dx, size.height - padding);
      areaPath.close();

      canvas.drawPath(
        areaPath,
        Paint()
          ..color = areaColor
          ..style = PaintingStyle.fill,
      );
    }

    // 绘制线条
    if (visibleData.length > 1) {
      final linePath = Path();
      final firstPoint = toCanvas(visibleData.first);
      linePath.moveTo(firstPoint.dx, firstPoint.dy);

      for (int i = 1; i < visibleData.length; i++) {
        final point = toCanvas(visibleData[i]);
        linePath.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 绘制数据点
    if (showPoints) {
      final pointPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;

      for (final dataPoint in visibleData) {
        final point = toCanvas(dataPoint);
        canvas.drawCircle(point, pointRadius, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor;
  }
}

/// 优化的柱状图
class OptimizedBarChart extends StatefulWidget {
  final List<BarChartData> data;
  final Color barColor;
  final double barWidth;
  final double spacing;
  final bool showValues;
  final bool animate;
  final Duration animationDuration;
  final int maxVisibleBars;

  const OptimizedBarChart({
    super.key,
    required this.data,
    this.barColor = Colors.blue,
    this.barWidth = 20.0,
    this.spacing = 8.0,
    this.showValues = true,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 400),
    this.maxVisibleBars = 50,
  });

  @override
  State<OptimizedBarChart> createState() => _OptimizedBarChartState();
}

class _OptimizedBarChartState extends State<OptimizedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    if (widget.animate) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(OptimizedBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data && widget.animate) {
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 限制显示的柱子数量
    final visibleData = widget.data.length > widget.maxVisibleBars
        ? widget.data.sublist(0, widget.maxVisibleBars)
        : widget.data;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _BarChartPainter(
            data: visibleData,
            barColor: widget.barColor,
            barWidth: widget.barWidth,
            spacing: widget.spacing,
            showValues: widget.showValues,
            progress: _animation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// 柱状图数据
class BarChartData {
  final String label;
  final double value;
  final Color? color;

  const BarChartData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// 柱状图绘制器
class _BarChartPainter extends CustomPainter {
  final List<BarChartData> data;
  final Color barColor;
  final double barWidth;
  final double spacing;
  final bool showValues;
  final double progress;

  _BarChartPainter({
    required this.data,
    required this.barColor,
    required this.barWidth,
    required this.spacing,
    required this.showValues,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.map((d) => d.value).reduce(math.max);
    final padding = 40.0;
    final chartHeight = size.height - padding * 2;
    final totalBarsWidth = data.length * barWidth + (data.length - 1) * spacing;
    final startX = (size.width - totalBarsWidth) / 2;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final barHeight = (item.value / maxValue) * chartHeight * progress;
      final x = startX + i * (barWidth + spacing);
      final y = size.height - padding - barHeight;

      // 绘制柱子
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(
        rect,
        Paint()..color = item.color ?? barColor,
      );

      // 绘制标签
      final textPainter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + (barWidth - textPainter.width) / 2,
          size.height - padding + 4,
        ),
      );

      // 绘制数值
      if (showValues && progress > 0.5) {
        final valueTextPainter = TextPainter(
          text: TextSpan(
            text: item.value.toStringAsFixed(0),
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        valueTextPainter.layout();
        valueTextPainter.paint(
          canvas,
          Offset(
            x + (barWidth - valueTextPainter.width) / 2,
            y - valueTextPainter.height - 4,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.progress != progress;
  }
}

/// 优化的饼图
class OptimizedPieChart extends StatefulWidget {
  final List<PieChartData> data;
  final double radius;
  final double holeRadius;
  final bool showLabels;
  final bool animate;
  final Duration animationDuration;

  const OptimizedPieChart({
    super.key,
    required this.data,
    this.radius = 100.0,
    this.holeRadius = 0.0,
    this.showLabels = true,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  State<OptimizedPieChart> createState() => _OptimizedPieChartState();
}

class _OptimizedPieChartState extends State<OptimizedPieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    if (widget.animate) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(OptimizedPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data && widget.animate) {
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _PieChartPainter(
            data: widget.data,
            radius: widget.radius,
            holeRadius: widget.holeRadius,
            showLabels: widget.showLabels,
            progress: _animation.value,
          ),
          size: Size(widget.radius * 2 + 80, widget.radius * 2 + 80),
        );
      },
    );
  }
}

/// 饼图数据
class PieChartData {
  final String label;
  final double value;
  final Color color;

  const PieChartData({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// 饼图绘制器
class _PieChartPainter extends CustomPainter {
  final List<PieChartData> data;
  final double radius;
  final double holeRadius;
  final bool showLabels;
  final double progress;

  _PieChartPainter({
    required this.data,
    required this.radius,
    required this.holeRadius,
    required this.showLabels,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    var startAngle = -math.pi / 2;

    for (final item in data) {
      final sweepAngle = (item.value / total) * 2 * math.pi * progress;

      // 绘制扇形
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      );
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.fill,
      );

      // 绘制中心空洞
      if (holeRadius > 0) {
        canvas.drawCircle(
          center,
          holeRadius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
      }

      // 绘制标签
      if (showLabels && progress > 0.5) {
        final midAngle = startAngle + sweepAngle / 2;
        final labelRadius = radius + 30;
        final labelX = center.dx + labelRadius * math.cos(midAngle);
        final labelY = center.dy + labelRadius * math.sin(midAngle);

        final percentage = (item.value / total * 100).toStringAsFixed(1);
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$percentage%',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            labelX - textPainter.width / 2,
            labelY - textPainter.height / 2,
          ),
        );
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.progress != progress;
  }
}

// ==================== 图表渲染优化服务 ====================

/// 图表渲染优化服务
class ChartOptimizationService {
  static final ChartOptimizationService _instance =
      ChartOptimizationService._internal();
  factory ChartOptimizationService() => _instance;
  ChartOptimizationService._internal();

  final ChartRenderCache _cache = ChartRenderCache();

  // 配置
  int _downsampleThreshold = 200;
  bool _enableAnimation = true;
  bool _enableCache = true;

  /// 设置降采样阈值
  void setDownsampleThreshold(int threshold) {
    _downsampleThreshold = threshold;
  }

  /// 设置是否启用动画
  void setEnableAnimation(bool enable) {
    _enableAnimation = enable;
  }

  /// 设置是否启用缓存
  void setEnableCache(bool enable) {
    _enableCache = enable;
    if (!enable) {
      _cache.clear();
    }
  }

  /// 获取降采样阈值
  int get downsampleThreshold => _downsampleThreshold;

  /// 是否启用动画
  bool get enableAnimation => _enableAnimation;

  /// 是否启用缓存
  bool get enableCache => _enableCache;

  /// 对数据进行智能降采样
  List<ChartDataPoint> smartDownsample(
    List<ChartDataPoint> data, {
    int? threshold,
  }) {
    final t = threshold ?? _downsampleThreshold;
    if (data.length <= t) return data;

    return ChartDataSampler.downsampleLTTB(data, t);
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
  }

  /// 获取缓存大小
  int get cacheSize => _cache.size;
}

/// 全局图表优化服务实例
final chartOptimizer = ChartOptimizationService();
