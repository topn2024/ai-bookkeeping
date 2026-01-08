import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 热力图数据点
class HeatmapDataPoint {
  /// X轴索引（如时段、日期）
  final int x;

  /// Y轴索引（如星期几）
  final int y;

  /// 数值
  final double value;

  /// 标签
  final String? label;

  /// 附加数据
  final Map<String, dynamic>? metadata;

  const HeatmapDataPoint({
    required this.x,
    required this.y,
    required this.value,
    this.label,
    this.metadata,
  });
}

/// 热力图配置
class HeatmapConfig {
  /// 单元格大小
  final double cellSize;

  /// 单元格间距
  final double cellGap;

  /// 单元格圆角
  final double cellRadius;

  /// 最小颜色（值为0时）
  final Color minColor;

  /// 最大颜色（值最大时）
  final Color maxColor;

  /// 空值颜色
  final Color emptyColor;

  /// 是否显示数值
  final bool showValues;

  /// 是否显示X轴标签
  final bool showXLabels;

  /// 是否显示Y轴标签
  final bool showYLabels;

  /// X轴标签
  final List<String>? xLabels;

  /// Y轴标签
  final List<String>? yLabels;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 动画时长
  final Duration animationDuration;

  const HeatmapConfig({
    this.cellSize = 32,
    this.cellGap = 4,
    this.cellRadius = 4,
    this.minColor = const Color(0xFFE8F5E9),
    this.maxColor = const Color(0xFF2E7D32),
    this.emptyColor = const Color(0xFFF5F5F5),
    this.showValues = false,
    this.showXLabels = true,
    this.showYLabels = true,
    this.xLabels,
    this.yLabels,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  /// 消费热力图预设（按时段）
  static HeatmapConfig consumptionByHour({
    Color minColor = const Color(0xFFE3F2FD),
    Color maxColor = const Color(0xFF1565C0),
  }) {
    return HeatmapConfig(
      cellSize: 24,
      cellGap: 2,
      minColor: minColor,
      maxColor: maxColor,
      showXLabels: true,
      showYLabels: true,
      xLabels: List.generate(24, (i) => '$i时'),
      yLabels: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
    );
  }

  /// 日历热力图预设（按日期）
  static HeatmapConfig calendar({
    Color minColor = const Color(0xFFE8F5E9),
    Color maxColor = const Color(0xFF2E7D32),
  }) {
    return HeatmapConfig(
      cellSize = 14,
      cellGap: 3,
      cellRadius: 2,
      minColor: minColor,
      maxColor: maxColor,
      showXLabels: true,
      showYLabels: true,
      yLabels: ['日', '一', '二', '三', '四', '五', '六'],
    );
  }
}

/// 消费热力图组件
///
/// 核心功能：
/// 1. 按时段/日期展示消费分布
/// 2. 颜色深浅表示消费强度
/// 3. 支持点击查看详情
/// 4. 支持下钻到具体交易
///
/// 对应设计文档：第12.2节 消费热力图组件
/// 对应前端原型：7.07 消费热力图
///
/// 使用示例：
/// ```dart
/// ConsumptionHeatmap(
///   data: heatmapData,
///   config: HeatmapConfig.consumptionByHour(),
///   onCellTap: (point) => showDetails(point),
/// )
/// ```
class ConsumptionHeatmap extends StatefulWidget {
  /// 热力图数据
  final List<HeatmapDataPoint> data;

  /// 配置
  final HeatmapConfig config;

  /// 单元格点击回调
  final void Function(HeatmapDataPoint point)? onCellTap;

  /// 单元格长按回调
  final void Function(HeatmapDataPoint point)? onCellLongPress;

  /// 标题
  final String? title;

  /// 副标题
  final String? subtitle;

  const ConsumptionHeatmap({
    super.key,
    required this.data,
    this.config = const HeatmapConfig(),
    this.onCellTap,
    this.onCellLongPress,
    this.title,
    this.subtitle,
  });

  @override
  State<ConsumptionHeatmap> createState() => _ConsumptionHeatmapState();
}

class _ConsumptionHeatmapState extends State<ConsumptionHeatmap>
    with SingleTickerProviderStateMixin {
  /// 选中的单元格
  HeatmapDataPoint? _selectedPoint;

  /// 数据范围
  late double _minValue;
  late double _maxValue;

  @override
  void initState() {
    super.initState();
    _calculateRange();
  }

  @override
  void didUpdateWidget(ConsumptionHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _calculateRange();
    }
  }

  /// 计算数据范围
  void _calculateRange() {
    if (widget.data.isEmpty) {
      _minValue = 0;
      _maxValue = 1;
      return;
    }

    _minValue = widget.data.map((p) => p.value).reduce(math.min);
    _maxValue = widget.data.map((p) => p.value).reduce(math.max);

    // 避免除零
    if (_maxValue == _minValue) {
      _maxValue = _minValue + 1;
    }
  }

  /// 获取单元格颜色
  Color _getCellColor(double? value) {
    if (value == null || value == 0) {
      return widget.config.emptyColor;
    }

    final normalized = (value - _minValue) / (_maxValue - _minValue);
    return Color.lerp(
      widget.config.minColor,
      widget.config.maxColor,
      normalized,
    )!;
  }

  /// 获取数据点
  HeatmapDataPoint? _getDataPoint(int x, int y) {
    try {
      return widget.data.firstWhere((p) => p.x == x && p.y == y);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final yCount = widget.config.yLabels?.length ?? 7;
    final xCount = widget.config.xLabels?.length ?? 24;

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

        // 热力图主体
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Y轴标签
            if (widget.config.showYLabels && widget.config.yLabels != null)
              Column(
                children: [
                  if (widget.config.showXLabels) SizedBox(height: 20),
                  ...widget.config.yLabels!.map((label) => Container(
                        height: widget.config.cellSize + widget.config.cellGap,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      )),
                ],
              ),

            // 热力图网格
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // X轴标签
                  if (widget.config.showXLabels && widget.config.xLabels != null)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.config.xLabels!.asMap().entries.map((e) {
                          // 只显示部分标签避免拥挤
                          final showLabel = e.key % 4 == 0;
                          return SizedBox(
                            width: widget.config.cellSize + widget.config.cellGap,
                            height: 20,
                            child: showLabel
                                ? Center(
                                    child: Text(
                                      e.value,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        }).toList(),
                      ),
                    ),

                  // 热力图单元格
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      children: List.generate(yCount, (y) {
                        return Row(
                          children: List.generate(xCount, (x) {
                            final point = _getDataPoint(x, y);
                            final isSelected = _selectedPoint != null &&
                                _selectedPoint!.x == x &&
                                _selectedPoint!.y == y;

                            return GestureDetector(
                              onTap: () => _onCellTap(x, y, point),
                              onLongPress: () => _onCellLongPress(x, y, point),
                              child: AnimatedContainer(
                                duration: widget.config.animationDuration,
                                width: widget.config.cellSize,
                                height: widget.config.cellSize,
                                margin: EdgeInsets.all(widget.config.cellGap / 2),
                                decoration: BoxDecoration(
                                  color: _getCellColor(point?.value),
                                  borderRadius:
                                      BorderRadius.circular(widget.config.cellRadius),
                                  border: isSelected
                                      ? Border.all(
                                          color: Theme.of(context).primaryColor,
                                          width: 2,
                                        )
                                      : null,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: widget.config.showValues && point != null
                                    ? Center(
                                        child: Text(
                                          _formatValue(point.value),
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: _getTextColor(point.value),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // 图例
        const SizedBox(height: 16),
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
        ...List.generate(5, (i) {
          final color = Color.lerp(
            widget.config.minColor,
            widget.config.maxColor,
            i / 4,
          );
          return Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
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
    if (_selectedPoint == null) return const SizedBox();

    final xLabel = widget.config.xLabels?[_selectedPoint!.x] ?? '${_selectedPoint!.x}';
    final yLabel = widget.config.yLabels?[_selectedPoint!.y] ?? '${_selectedPoint!.y}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            '$yLabel $xLabel: ¥${_selectedPoint!.value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_selectedPoint!.label != null) ...[
            const SizedBox(width: 8),
            Text(
              '(${_selectedPoint!.label})',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 单元格点击
  void _onCellTap(int x, int y, HeatmapDataPoint? point) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      if (_selectedPoint?.x == x && _selectedPoint?.y == y) {
        _selectedPoint = null;
      } else {
        _selectedPoint = point ??
            HeatmapDataPoint(
              x: x,
              y: y,
              value: 0,
              label: '无数据',
            );
      }
    });

    if (point != null) {
      widget.onCellTap?.call(point);
    }
  }

  /// 单元格长按
  void _onCellLongPress(int x, int y, HeatmapDataPoint? point) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    if (point != null) {
      widget.onCellLongPress?.call(point);
    }
  }

  /// 格式化数值
  String _formatValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  /// 获取文字颜色（根据背景色深浅）
  Color _getTextColor(double value) {
    final normalized = (value - _minValue) / (_maxValue - _minValue);
    return normalized > 0.5 ? Colors.white : Colors.black87;
  }
}
