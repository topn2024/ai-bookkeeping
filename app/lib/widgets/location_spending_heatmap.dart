import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 位置消费数据点
class LocationSpendingPoint {
  /// 纬度
  final double latitude;

  /// 经度
  final double longitude;

  /// 消费金额
  final double amount;

  /// 消费次数
  final int count;

  /// 位置名称
  final String? locationName;

  /// 地址
  final String? address;

  /// 主要消费分类
  final String? mainCategory;

  /// 附加数据
  final Map<String, dynamic>? metadata;

  const LocationSpendingPoint({
    required this.latitude,
    required this.longitude,
    required this.amount,
    this.count = 1,
    this.locationName,
    this.address,
    this.mainCategory,
    this.metadata,
  });
}

/// 地图边界
class MapBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const MapBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  /// 从点列表计算边界
  factory MapBounds.fromPoints(List<LocationSpendingPoint> points) {
    if (points.isEmpty) {
      return const MapBounds(
        minLat: 39.9,
        maxLat: 40.0,
        minLng: 116.3,
        maxLng: 116.5,
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // 添加边距
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return MapBounds(
      minLat: minLat - latPadding,
      maxLat: maxLat + latPadding,
      minLng: minLng - lngPadding,
      maxLng: maxLng + lngPadding,
    );
  }

  double get latRange => maxLat - minLat;
  double get lngRange => maxLng - minLng;
}

/// 位置热力图配置
class LocationHeatmapConfig {
  /// 热力点半径
  final double pointRadius;

  /// 热力点模糊半径
  final double blurRadius;

  /// 最小颜色
  final Color minColor;

  /// 最大颜色
  final Color maxColor;

  /// 是否显示位置标记
  final bool showMarkers;

  /// 是否显示位置名称
  final bool showLabels;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 动画时长
  final Duration animationDuration;

  /// 透明度
  final double opacity;

  /// 是否显示网格
  final bool showGrid;

  /// 网格大小
  final int gridSize;

  const LocationHeatmapConfig({
    this.pointRadius = 30,
    this.blurRadius = 20,
    this.minColor = const Color(0x4000FF00),
    this.maxColor = const Color(0xFFFF0000),
    this.showMarkers = true,
    this.showLabels = false,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 500),
    this.opacity = 0.8,
    this.showGrid = false,
    this.gridSize = 10,
  });
}

/// 位置消费地理热力图组件
///
/// 核心功能：
/// 1. 地图上展示消费热力分布
/// 2. 支持点击查看位置详情
/// 3. 消费金额/次数热力映射
/// 4. 支持缩放和平移
///
/// 对应设计文档：第12.2节 位置消费地理热力图组件
/// 对应前端原型：7.15 位置消费热力图
///
/// 使用示例：
/// ```dart
/// LocationSpendingHeatmap(
///   points: spendingPoints,
///   config: LocationHeatmapConfig(),
///   onPointTap: (point) => showDetails(point),
/// )
/// ```
class LocationSpendingHeatmap extends StatefulWidget {
  /// 消费数据点
  final List<LocationSpendingPoint> points;

  /// 配置
  final LocationHeatmapConfig config;

  /// 点击回调
  final void Function(LocationSpendingPoint point)? onPointTap;

  /// 标题
  final String? title;

  /// 副标题
  final String? subtitle;

  /// 高度
  final double height;

  const LocationSpendingHeatmap({
    super.key,
    required this.points,
    this.config = const LocationHeatmapConfig(),
    this.onPointTap,
    this.title,
    this.subtitle,
    this.height = 300,
  });

  @override
  State<LocationSpendingHeatmap> createState() => _LocationSpendingHeatmapState();
}

class _LocationSpendingHeatmapState extends State<LocationSpendingHeatmap>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  LocationSpendingPoint? _selectedPoint;
  late MapBounds _bounds;
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _bounds = MapBounds.fromPoints(widget.points);
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
  void didUpdateWidget(LocationSpendingHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _bounds = MapBounds.fromPoints(widget.points);
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

        // 热力图
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onScaleUpdate: _onScaleUpdate,
              onTapDown: _onTapDown,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _LocationHeatmapPainter(
                      points: widget.points,
                      config: widget.config,
                      bounds: _bounds,
                      animationValue: _animation.value,
                      selectedPoint: _selectedPoint,
                      scale: _scale,
                      offset: _offset,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // 图例
        const SizedBox(height: 12),
        _buildLegend(),

        // 选中信息
        if (_selectedPoint != null) ...[
          const SizedBox(height: 12),
          _buildSelectedInfo(),
        ],
      ],
    );
  }

  /// 构建图例
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '少',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 12,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.config.minColor,
                widget.config.maxColor,
              ],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '多',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  /// 构建选中信息
  Widget _buildSelectedInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPoint!.locationName ?? '未知位置',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  '消费 ¥${_selectedPoint!.amount.toStringAsFixed(2)} · ${_selectedPoint!.count}次',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (_selectedPoint!.mainCategory != null)
                  Text(
                    '主要消费: ${_selectedPoint!.mainCategory}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () {
              widget.onPointTap?.call(_selectedPoint!);
            },
          ),
        ],
      ),
    );
  }

  /// 缩放处理
  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_scale * details.scale).clamp(0.5, 3.0);
      _offset += details.focalPointDelta;
    });
  }

  /// 点击处理
  void _onTapDown(TapDownDetails details) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final tapPosition = details.localPosition;

    // 查找最近的数据点
    LocationSpendingPoint? nearestPoint;
    double minDistance = double.infinity;

    for (final point in widget.points) {
      final screenPos = _latLngToScreen(point.latitude, point.longitude, size);
      final distance = (screenPos - tapPosition).distance;

      if (distance < widget.config.pointRadius * 2 && distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }

    if (nearestPoint != null) {
      if (widget.config.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      setState(() {
        _selectedPoint = nearestPoint;
      });
    }
  }

  /// 经纬度转屏幕坐标
  Offset _latLngToScreen(double lat, double lng, Size size) {
    final x = (lng - _bounds.minLng) / _bounds.lngRange * size.width;
    final y = (1 - (lat - _bounds.minLat) / _bounds.latRange) * size.height;
    return Offset(x * _scale + _offset.dx, y * _scale + _offset.dy);
  }
}

/// 位置热力图绑定器
class _LocationHeatmapPainter extends CustomPainter {
  final List<LocationSpendingPoint> points;
  final LocationHeatmapConfig config;
  final MapBounds bounds;
  final double animationValue;
  final LocationSpendingPoint? selectedPoint;
  final double scale;
  final Offset offset;

  _LocationHeatmapPainter({
    required this.points,
    required this.config,
    required this.bounds,
    required this.animationValue,
    this.selectedPoint,
    this.scale = 1.0,
    this.offset = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制网格背景
    if (config.showGrid) {
      _drawGrid(canvas, size);
    }

    // 获取最大金额
    final maxAmount = points.isEmpty
        ? 1.0
        : points.map((p) => p.amount).reduce(math.max);

    // 绘制热力点
    for (final point in points) {
      final screenPos = _latLngToScreen(point.latitude, point.longitude, size);
      final normalizedValue = point.amount / maxAmount;
      final isSelected = selectedPoint == point;

      // 热力渐变
      final gradient = RadialGradient(
        colors: [
          Color.lerp(config.minColor, config.maxColor, normalizedValue)!
              .withValues(alpha: config.opacity * animationValue),
          Color.lerp(config.minColor, config.maxColor, normalizedValue)!
              .withValues(alpha: 0),
        ],
      );

      final radius = config.pointRadius * (1 + normalizedValue * 0.5) * animationValue;

      // 绘制热力圆
      canvas.drawCircle(
        screenPos,
        radius,
        Paint()
          ..shader = gradient.createShader(
            Rect.fromCircle(center: screenPos, radius: radius),
          ),
      );

      // 选中状态
      if (isSelected) {
        canvas.drawCircle(
          screenPos,
          radius + 4,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }

      // 标记点
      if (config.showMarkers) {
        canvas.drawCircle(
          screenPos,
          6,
          Paint()
            ..color = Color.lerp(config.minColor, config.maxColor, normalizedValue)!
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          screenPos,
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      // 标签
      if (config.showLabels && point.locationName != null) {
        final textSpan = TextSpan(
          text: point.locationName,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[700],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            screenPos.dx - textPainter.width / 2,
            screenPos.dy + 12,
          ),
        );
      }
    }
  }

  /// 绘制网格
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    final cellWidth = size.width / config.gridSize;
    final cellHeight = size.height / config.gridSize;

    for (int i = 0; i <= config.gridSize; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        paint,
      );
    }
  }

  /// 经纬度转屏幕坐标
  Offset _latLngToScreen(double lat, double lng, Size size) {
    final x = (lng - bounds.minLng) / bounds.lngRange * size.width;
    final y = (1 - (lat - bounds.minLat) / bounds.latRange) * size.height;
    return Offset(x * scale + offset.dx, y * scale + offset.dy);
  }

  @override
  bool shouldRepaint(covariant _LocationHeatmapPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.selectedPoint != selectedPoint ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset;
  }
}
