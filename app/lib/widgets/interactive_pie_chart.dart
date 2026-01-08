import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/drill_down_navigation_service.dart';

/// 饼图扇区数据
class PieChartSection {
  /// 唯一标识
  final String id;

  /// 显示标题
  final String title;

  /// 数值
  final double value;

  /// 颜色
  final Color color;

  /// 图标（可选）
  final IconData? icon;

  /// 附加数据（用于下钻）
  final Map<String, dynamic>? metadata;

  /// 子分类数据（用于二级下钻）
  final List<PieChartSection>? children;

  const PieChartSection({
    required this.id,
    required this.title,
    required this.value,
    required this.color,
    this.icon,
    this.metadata,
    this.children,
  });

  /// 计算百分比
  double percentage(double total) => total > 0 ? (value / total) * 100 : 0;

  /// 是否有子分类
  bool get hasChildren => children != null && children!.isNotEmpty;
}

/// 饼图交互回调
typedef OnPieSectionTap = void Function(PieChartSection section);
typedef OnPieSectionLongPress = void Function(PieChartSection section);
typedef OnPieSectionDoubleTap = void Function(PieChartSection section);

/// 饼图配置
class InteractivePieChartConfig {
  /// 是否显示中心空白（环形图）
  final bool showHole;

  /// 中心空白半径比例 (0.0 - 1.0)
  final double holeRadius;

  /// 是否显示标签
  final bool showLabels;

  /// 是否显示百分比
  final bool showPercentage;

  /// 是否显示金额
  final bool showValue;

  /// 选中时的放大比例
  final double selectedScale;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 动画时长
  final Duration animationDuration;

  /// 最小可见百分比（低于此值合并为"其他"）
  final double minVisiblePercentage;

  /// 是否支持下钻
  final bool enableDrillDown;

  /// 中心显示内容类型
  final PieChartCenterContent centerContent;

  const InteractivePieChartConfig({
    this.showHole = true,
    this.holeRadius = 0.5,
    this.showLabels = true,
    this.showPercentage = true,
    this.showValue = true,
    this.selectedScale = 1.05,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.minVisiblePercentage = 3.0,
    this.enableDrillDown = true,
    this.centerContent = PieChartCenterContent.total,
  });
}

/// 中心内容类型
enum PieChartCenterContent {
  /// 显示总额
  total,

  /// 显示选中项信息
  selected,

  /// 自定义内容
  custom,

  /// 不显示
  none,
}

/// 交互式可下钻饼图组件
///
/// 核心功能：
/// 1. 支持点击扇区下钻到详情
/// 2. 支持长按显示操作菜单
/// 3. 支持选中高亮动画
/// 4. 触觉反馈
/// 5. 与下钻导航服务集成
///
/// 对应设计文档：第12.2.2节 可下钻饼图组件
/// 对应前端原型：7.05 分类饼图下钻
///
/// 使用示例：
/// ```dart
/// InteractivePieChart(
///   sections: [
///     PieChartSection(id: 'food', title: '餐饮', value: 1580, color: Colors.orange),
///     PieChartSection(id: 'transport', title: '交通', value: 680, color: Colors.blue),
///   ],
///   onSectionTap: (section) => drillDown(section),
///   config: InteractivePieChartConfig(
///     showHole: true,
///     enableDrillDown: true,
///   ),
/// )
/// ```
class InteractivePieChart extends StatefulWidget {
  /// 扇区数据
  final List<PieChartSection> sections;

  /// 配置
  final InteractivePieChartConfig config;

  /// 点击回调
  final OnPieSectionTap? onSectionTap;

  /// 长按回调
  final OnPieSectionLongPress? onSectionLongPress;

  /// 双击回调
  final OnPieSectionDoubleTap? onSectionDoubleTap;

  /// 下钻导航服务（可选）
  final DrillDownNavigationService? navigationService;

  /// 中心自定义Widget
  final Widget? centerWidget;

  /// 总金额标签
  final String totalLabel;

  /// 货币符号
  final String currencySymbol;

  const InteractivePieChart({
    super.key,
    required this.sections,
    this.config = const InteractivePieChartConfig(),
    this.onSectionTap,
    this.onSectionLongPress,
    this.onSectionDoubleTap,
    this.navigationService,
    this.centerWidget,
    this.totalLabel = '总支出',
    this.currencySymbol = '¥',
  });

  @override
  State<InteractivePieChart> createState() => _InteractivePieChartState();
}

class _InteractivePieChartState extends State<InteractivePieChart>
    with SingleTickerProviderStateMixin {
  /// 选中的扇区索引
  int? _selectedIndex;

  /// 动画控制器
  late AnimationController _animationController;

  /// 选中动画
  late Animation<double> _scaleAnimation;

  /// 当前触摸位置
  Offset? _touchPosition;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.config.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.config.selectedScale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 计算总值
  double get _total => widget.sections.fold(0, (sum, s) => sum + s.value);

  /// 处理扇区数据（合并小扇区）
  List<PieChartSection> get _processedSections {
    final total = _total;
    if (total == 0) return [];

    final visible = <PieChartSection>[];
    double otherValue = 0;

    for (final section in widget.sections) {
      final percentage = section.percentage(total);
      if (percentage >= widget.config.minVisiblePercentage) {
        visible.add(section);
      } else {
        otherValue += section.value;
      }
    }

    // 添加"其他"分类
    if (otherValue > 0) {
      visible.add(PieChartSection(
        id: '_other_',
        title: '其他',
        value: otherValue,
        color: Colors.grey,
      ));
    }

    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _processedSections;
    final total = _total;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size / 2, size / 2);
        final radius = size / 2 - 20;

        return GestureDetector(
          onTapDown: (details) => _onTapDown(details, center, radius, sections),
          onTap: () => _onTap(sections),
          onLongPress: () => _onLongPress(sections),
          onDoubleTap: () => _onDoubleTap(sections),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 饼图主体
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(size, size),
                      painter: _PieChartPainter(
                        sections: sections,
                        total: total,
                        selectedIndex: _selectedIndex,
                        selectedScale: _scaleAnimation.value,
                        showHole: widget.config.showHole,
                        holeRadius: widget.config.holeRadius,
                      ),
                    );
                  },
                ),

                // 中心内容
                if (widget.config.showHole) _buildCenterContent(total),

                // 标签
                if (widget.config.showLabels)
                  ..._buildLabels(sections, total, center, radius),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建中心内容
  Widget _buildCenterContent(double total) {
    switch (widget.config.centerContent) {
      case PieChartCenterContent.total:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.totalLabel,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.currencySymbol}${_formatNumber(total)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case PieChartCenterContent.selected:
        if (_selectedIndex == null) {
          return _buildCenterContent(total);
        }
        final section = _processedSections[_selectedIndex!];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              section.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: section.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.currencySymbol}${_formatNumber(section.value)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${section.percentage(total).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        );

      case PieChartCenterContent.custom:
        return widget.centerWidget ?? const SizedBox();

      case PieChartCenterContent.none:
        return const SizedBox();
    }
  }

  /// 构建标签
  List<Widget> _buildLabels(
    List<PieChartSection> sections,
    double total,
    Offset center,
    double radius,
  ) {
    final labels = <Widget>[];
    double startAngle = -math.pi / 2;

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      final sweepAngle = (section.value / total) * 2 * math.pi;
      final midAngle = startAngle + sweepAngle / 2;

      // 标签位置（外圈）
      final labelRadius = radius * 1.15;
      final labelX = center.dx + labelRadius * math.cos(midAngle);
      final labelY = center.dy + labelRadius * math.sin(midAngle);

      labels.add(
        Positioned(
          left: labelX - 40,
          top: labelY - 20,
          child: SizedBox(
            width: 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 11,
                    color: section.color,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.config.showPercentage)
                  Text(
                    '${section.percentage(total).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      startAngle += sweepAngle;
    }

    return labels;
  }

  /// 处理触摸位置
  void _onTapDown(
    TapDownDetails details,
    Offset center,
    double radius,
    List<PieChartSection> sections,
  ) {
    _touchPosition = details.localPosition;

    // 计算触摸点相对于中心的角度
    final dx = _touchPosition!.dx - center.dx;
    final dy = _touchPosition!.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // 检查是否在饼图范围内
    final innerRadius = widget.config.showHole ? radius * widget.config.holeRadius : 0;
    if (distance < innerRadius || distance > radius) {
      _selectedIndex = null;
      _animationController.reverse();
      return;
    }

    // 计算角度并找到对应扇区
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    final total = _total;
    double startAngle = 0;

    for (int i = 0; i < sections.length; i++) {
      final sweepAngle = (sections[i].value / total) * 2 * math.pi;
      if (angle >= startAngle && angle < startAngle + sweepAngle) {
        setState(() {
          _selectedIndex = i;
        });
        _animationController.forward();

        // 触觉反馈
        if (widget.config.enableHapticFeedback) {
          HapticFeedback.lightImpact();
        }
        return;
      }
      startAngle += sweepAngle;
    }
  }

  /// 处理点击
  void _onTap(List<PieChartSection> sections) {
    if (_selectedIndex == null) return;

    final section = sections[_selectedIndex!];

    // 调用回调
    widget.onSectionTap?.call(section);

    // 如果启用下钻，执行下钻导航
    if (widget.config.enableDrillDown && widget.navigationService != null) {
      widget.navigationService!.drillDown(
        id: section.id,
        title: section.title,
        filterValue: {'category_id': section.id},
        metadata: {
          'value': section.value,
          'percentage': section.percentage(_total),
          ...?section.metadata,
        },
      );
    }
  }

  /// 处理长按
  void _onLongPress(List<PieChartSection> sections) {
    if (_selectedIndex == null) return;

    final section = sections[_selectedIndex!];

    // 触觉反馈
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    widget.onSectionLongPress?.call(section);
  }

  /// 处理双击
  void _onDoubleTap(List<PieChartSection> sections) {
    if (_selectedIndex == null) return;

    final section = sections[_selectedIndex!];
    widget.onSectionDoubleTap?.call(section);
  }

  /// 格式化数字
  String _formatNumber(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return value.toStringAsFixed(0);
  }
}

/// 饼图绘制器
class _PieChartPainter extends CustomPainter {
  final List<PieChartSection> sections;
  final double total;
  final int? selectedIndex;
  final double selectedScale;
  final bool showHole;
  final double holeRadius;

  _PieChartPainter({
    required this.sections,
    required this.total,
    this.selectedIndex,
    this.selectedScale = 1.0,
    this.showHole = true,
    this.holeRadius = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (sections.isEmpty || total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final innerRadius = showHole ? radius * holeRadius : 0.0;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      final sweepAngle = (section.value / total) * 2 * math.pi;

      // 选中状态处理
      final isSelected = i == selectedIndex;
      final scale = isSelected ? selectedScale : 1.0;
      final currentRadius = radius * scale;

      // 绘制扇区
      final paint = Paint()
        ..color = isSelected ? section.color : section.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      // 计算扇区路径
      final path = Path();

      if (showHole) {
        // 环形图
        path.moveTo(
          center.dx + innerRadius * math.cos(startAngle),
          center.dy + innerRadius * math.sin(startAngle),
        );
        path.lineTo(
          center.dx + currentRadius * math.cos(startAngle),
          center.dy + currentRadius * math.sin(startAngle),
        );
        path.arcTo(
          Rect.fromCircle(center: center, radius: currentRadius),
          startAngle,
          sweepAngle,
          false,
        );
        path.lineTo(
          center.dx + innerRadius * math.cos(startAngle + sweepAngle),
          center.dy + innerRadius * math.sin(startAngle + sweepAngle),
        );
        path.arcTo(
          Rect.fromCircle(center: center, radius: innerRadius),
          startAngle + sweepAngle,
          -sweepAngle,
          false,
        );
      } else {
        // 实心饼图
        path.moveTo(center.dx, center.dy);
        path.lineTo(
          center.dx + currentRadius * math.cos(startAngle),
          center.dy + currentRadius * math.sin(startAngle),
        );
        path.arcTo(
          Rect.fromCircle(center: center, radius: currentRadius),
          startAngle,
          sweepAngle,
          false,
        );
        path.close();
      }

      canvas.drawPath(path, paint);

      // 绘制边框
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, borderPaint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.selectedScale != selectedScale ||
        oldDelegate.sections != sections;
  }
}
