import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 家庭成员数据
class FamilyMemberData {
  /// 成员ID
  final String memberId;

  /// 成员名称
  final String name;

  /// 头像URL
  final String? avatarUrl;

  /// 总支出
  final double totalExpense;

  /// 总收入
  final double totalIncome;

  /// 分类支出
  final Map<String, double> categoryExpenses;

  /// 颜色
  final Color? color;

  const FamilyMemberData({
    required this.memberId,
    required this.name,
    this.avatarUrl,
    required this.totalExpense,
    this.totalIncome = 0,
    this.categoryExpenses = const {},
    this.color,
  });

  /// 净支出（支出-收入）
  double get netExpense => totalExpense - totalIncome;
}

/// 对比类型
enum ComparisonType {
  /// 总支出对比
  totalExpense,

  /// 总收入对比
  totalIncome,

  /// 净支出对比
  netExpense,

  /// 分类对比
  byCategory,
}

/// 图表类型
enum ComparisonChartType {
  /// 柱状图
  bar,

  /// 环形图
  donut,

  /// 雷达图
  radar,

  /// 堆叠柱状图
  stackedBar,
}

/// 对比图配置
class FamilyComparisonConfig {
  /// 图表类型
  final ComparisonChartType chartType;

  /// 对比类型
  final ComparisonType comparisonType;

  /// 是否显示百分比
  final bool showPercentage;

  /// 是否显示数值
  final bool showValues;

  /// 是否显示图例
  final bool showLegend;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 动画时长
  final Duration animationDuration;

  /// 默认颜色列表
  final List<Color> defaultColors;

  /// 柱状图宽度
  final double barWidth;

  /// 环形图厚度
  final double donutThickness;

  const FamilyComparisonConfig({
    this.chartType = ComparisonChartType.bar,
    this.comparisonType = ComparisonType.totalExpense,
    this.showPercentage = true,
    this.showValues = true,
    this.showLegend = true,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 500),
    this.defaultColors = const [
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFFFF9800),
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF00BCD4),
    ],
    this.barWidth = 24,
    this.donutThickness = 30,
  });
}

/// 家庭成员消费对比可视化组件
///
/// 核心功能：
/// 1. 多种图表类型展示
/// 2. 支出/收入对比
/// 3. 分类消费对比
/// 4. 交互式选择
/// 5. 动画效果
///
/// 对应设计文档：第12.2节 家庭成员消费对比可视化组件
/// 对应前端原型：7.14 家庭消费对比
///
/// 使用示例：
/// ```dart
/// FamilyComparisonChart(
///   members: familyMembers,
///   config: FamilyComparisonConfig(
///     chartType: ComparisonChartType.bar,
///   ),
///   onMemberTap: (member) => showDetails(member),
/// )
/// ```
class FamilyComparisonChart extends StatefulWidget {
  /// 家庭成员数据
  final List<FamilyMemberData> members;

  /// 配置
  final FamilyComparisonConfig config;

  /// 成员点击回调
  final void Function(FamilyMemberData member)? onMemberTap;

  /// 标题
  final String? title;

  /// 副标题
  final String? subtitle;

  /// 选中的分类（用于分类对比）
  final String? selectedCategory;

  const FamilyComparisonChart({
    super.key,
    required this.members,
    this.config = const FamilyComparisonConfig(),
    this.onMemberTap,
    this.title,
    this.subtitle,
    this.selectedCategory,
  });

  @override
  State<FamilyComparisonChart> createState() => _FamilyComparisonChartState();
}

class _FamilyComparisonChartState extends State<FamilyComparisonChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
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
  void didUpdateWidget(FamilyComparisonChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members) {
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

        // 图表
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            switch (widget.config.chartType) {
              case ComparisonChartType.bar:
                return _buildBarChart();
              case ComparisonChartType.donut:
                return _buildDonutChart();
              case ComparisonChartType.radar:
                return _buildRadarChart();
              case ComparisonChartType.stackedBar:
                return _buildStackedBarChart();
            }
          },
        ),

        // 图例
        if (widget.config.showLegend) ...[
          const SizedBox(height: 16),
          _buildLegend(),
        ],

        // 选中信息
        if (_selectedIndex != null) ...[
          const SizedBox(height: 12),
          _buildSelectedInfo(),
        ],
      ],
    );
  }

  /// 获取成员颜色
  Color _getMemberColor(int index) {
    if (widget.members[index].color != null) {
      return widget.members[index].color!;
    }
    return widget.config.defaultColors[index % widget.config.defaultColors.length];
  }

  /// 获取成员数值
  double _getMemberValue(FamilyMemberData member) {
    switch (widget.config.comparisonType) {
      case ComparisonType.totalExpense:
        return member.totalExpense;
      case ComparisonType.totalIncome:
        return member.totalIncome;
      case ComparisonType.netExpense:
        return member.netExpense;
      case ComparisonType.byCategory:
        if (widget.selectedCategory != null) {
          return member.categoryExpenses[widget.selectedCategory!] ?? 0;
        }
        return member.totalExpense;
    }
  }

  /// 构建柱状图
  Widget _buildBarChart() {
    final maxValue = widget.members.map((m) => _getMemberValue(m)).reduce(math.max);
    if (maxValue == 0) return const SizedBox();

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.members.length, (index) {
          final member = widget.members[index];
          final value = _getMemberValue(member);
          final percentage = value / maxValue;
          final isSelected = _selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onMemberTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 数值标签
                  if (widget.config.showValues)
                    Text(
                      '¥${value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  const SizedBox(height: 4),

                  // 柱状条
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: widget.config.barWidth,
                    height: 150 * percentage * _animation.value,
                    decoration: BoxDecoration(
                      color: _getMemberColor(index).withValues(alpha: isSelected ? 1.0 : 0.8),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _getMemberColor(index).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 成员名称
                  Text(
                    member.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? _getMemberColor(index) : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 构建环形图
  Widget _buildDonutChart() {
    final total = widget.members.fold<double>(0, (sum, m) => sum + _getMemberValue(m));
    if (total == 0) return const SizedBox();

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(200, 200),
            painter: _DonutChartPainter(
              values: widget.members.map((m) => _getMemberValue(m)).toList(),
              colors: List.generate(widget.members.length, _getMemberColor),
              animationValue: _animation.value,
              selectedIndex: _selectedIndex,
              thickness: widget.config.donutThickness,
            ),
          ),
          // 中心文字
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '总计',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '¥${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // 触摸检测
          ...List.generate(widget.members.length, (index) {
            return _buildDonutTouchArea(index, total);
          }),
        ],
      ),
    );
  }

  /// 构建环形图触摸区域
  Widget _buildDonutTouchArea(int index, double total) {
    // 简化处理：使用整个区域的点击
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          // 根据点击位置确定选中的部分
          final center = const Offset(100, 100);
          final offset = details.localPosition - center;
          var angle = math.atan2(offset.dy, offset.dx);
          if (angle < -math.pi / 2) {
            angle += 2 * math.pi;
          }
          angle += math.pi / 2;
          if (angle > 2 * math.pi) {
            angle -= 2 * math.pi;
          }

          double cumulative = 0;
          for (int i = 0; i < widget.members.length; i++) {
            final value = _getMemberValue(widget.members[i]);
            final sweepAngle = (value / total) * 2 * math.pi;
            if (angle >= cumulative && angle < cumulative + sweepAngle) {
              _onMemberTap(i);
              break;
            }
            cumulative += sweepAngle;
          }
        },
        child: const SizedBox(),
      ),
    );
  }

  /// 构建雷达图
  Widget _buildRadarChart() {
    // 获取所有分类
    final allCategories = widget.members
        .expand((m) => m.categoryExpenses.keys)
        .toSet()
        .toList();

    if (allCategories.isEmpty) {
      return const Center(child: Text('暂无分类数据'));
    }

    return SizedBox(
      height: 250,
      child: CustomPaint(
        size: const Size(250, 250),
        painter: _RadarChartPainter(
          categories: allCategories,
          members: widget.members,
          colors: List.generate(widget.members.length, _getMemberColor),
          animationValue: _animation.value,
          selectedIndex: _selectedIndex,
        ),
      ),
    );
  }

  /// 构建堆叠柱状图
  Widget _buildStackedBarChart() {
    // 获取所有分类
    final allCategories = widget.members
        .expand((m) => m.categoryExpenses.keys)
        .toSet()
        .toList();

    if (allCategories.isEmpty) {
      return const Center(child: Text('暂无分类数据'));
    }

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.members.length, (index) {
          final member = widget.members[index];
          final isSelected = _selectedIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onMemberTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 堆叠条
                  ...allCategories.asMap().entries.map((entry) {
                    final categoryIndex = entry.key;
                    final category = entry.value;
                    final value = member.categoryExpenses[category] ?? 0;
                    final maxValue = widget.members
                        .map((m) => m.totalExpense)
                        .reduce(math.max);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: widget.config.barWidth,
                      height: (150 * value / maxValue * _animation.value).clamp(0, 150),
                      decoration: BoxDecoration(
                        color: widget.config.defaultColors[
                            categoryIndex % widget.config.defaultColors.length]
                            .withValues(alpha: isSelected ? 1.0 : 0.7),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    member.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 构建图例
  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(widget.members.length, (index) {
        final member = widget.members[index];
        final isSelected = _selectedIndex == index;

        return GestureDetector(
          onTap: () => _onMemberTap(index),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getMemberColor(index),
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _getMemberColor(index).withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                member.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? _getMemberColor(index) : Colors.grey[700],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// 构建选中信息
  Widget _buildSelectedInfo() {
    final member = widget.members[_selectedIndex!];
    final value = _getMemberValue(member);
    final total = widget.members.fold<double>(0, (sum, m) => sum + _getMemberValue(m));
    final percentage = total > 0 ? (value / total * 100).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getMemberColor(_selectedIndex!).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _getMemberColor(_selectedIndex!),
            child: Text(
              member.name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getMemberColor(_selectedIndex!),
                  ),
                ),
                Text(
                  '¥${value.toStringAsFixed(2)} ($percentage%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () {
              widget.onMemberTap?.call(member);
            },
          ),
        ],
      ),
    );
  }

  /// 成员点击处理
  void _onMemberTap(int index) {
    if (widget.config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }
}

/// 环形图绑定器
class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double animationValue;
  final int? selectedIndex;
  final double thickness;

  _DonutChartPainter({
    required this.values,
    required this.colors,
    required this.animationValue,
    this.selectedIndex,
    this.thickness = 30,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - thickness / 2;
    final total = values.fold<double>(0, (sum, v) => sum + v);

    if (total == 0) return;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * math.pi * animationValue;
      final isSelected = selectedIndex == i;

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? thickness + 6 : thickness
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.values != values;
  }
}

/// 雷达图绑定器
class _RadarChartPainter extends CustomPainter {
  final List<String> categories;
  final List<FamilyMemberData> members;
  final List<Color> colors;
  final double animationValue;
  final int? selectedIndex;

  _RadarChartPainter({
    required this.categories,
    required this.members,
    required this.colors,
    required this.animationValue,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 40;
    final angleStep = 2 * math.pi / categories.length;

    // 绘制网格
    _drawGrid(canvas, center, radius, categories.length);

    // 绘制分类标签
    _drawLabels(canvas, center, radius, angleStep);

    // 获取最大值
    double maxValue = 0;
    for (final member in members) {
      for (final value in member.categoryExpenses.values) {
        if (value > maxValue) maxValue = value;
      }
    }
    if (maxValue == 0) maxValue = 1;

    // 绘制每个成员的数据
    for (int mIdx = 0; mIdx < members.length; mIdx++) {
      final member = members[mIdx];
      final isSelected = selectedIndex == mIdx;
      final points = <Offset>[];

      for (int cIdx = 0; cIdx < categories.length; cIdx++) {
        final value = member.categoryExpenses[categories[cIdx]] ?? 0;
        final normalizedValue = value / maxValue * radius * animationValue;
        final angle = -math.pi / 2 + cIdx * angleStep;
        points.add(Offset(
          center.dx + normalizedValue * math.cos(angle),
          center.dy + normalizedValue * math.sin(angle),
        ));
      }

      // 绘制填充区域
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = colors[mIdx].withValues(alpha: isSelected ? 0.4 : 0.2)
          ..style = PaintingStyle.fill,
      );

      // 绘制边框
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[mIdx]
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 3 : 2,
      );

      // 绘制数据点
      for (final point in points) {
        canvas.drawCircle(
          point,
          isSelected ? 5 : 4,
          Paint()..color = colors[mIdx],
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, Offset center, double radius, int sides) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制同心多边形
    for (int level = 1; level <= 4; level++) {
      final r = radius * level / 4;
      final path = Path();
      for (int i = 0; i <= sides; i++) {
        final angle = -math.pi / 2 + i * 2 * math.pi / sides;
        final point = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    // 绘制轴线
    for (int i = 0; i < sides; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / sides;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        paint,
      );
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius, double angleStep) {
    for (int i = 0; i < categories.length; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final labelRadius = radius + 20;
      final point = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      final textSpan = TextSpan(
        text: categories[i],
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
          point.dx - textPainter.width / 2,
          point.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
