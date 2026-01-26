import 'package:flutter/material.dart';

import '../models/resource_pool.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';

/// 钱龄影响因素分析组件
///
/// 功能：
/// 1. 展示影响钱龄的主要因素
/// 2. 可视化正向/负向影响
/// 3. 提供改善建议
class MoneyAgeInfluenceAnalysisCard extends StatelessWidget {
  /// 影响因素列表
  final List<MoneyAgeImpactAnalysis> factors;

  /// 是否可展开
  final bool expandable;

  /// 最大显示数量
  final int maxItems;

  const MoneyAgeInfluenceAnalysisCard({
    super.key,
    required this.factors,
    this.expandable = true,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    final sortedFactors = List<MoneyAgeImpactAnalysis>.from(factors)
      ..sort((a, b) => b.impactDays.abs().compareTo(a.impactDays.abs()));

    final displayFactors = sortedFactors.take(maxItems).toList();
    final positiveFactors = displayFactors.where((f) => f.impactDays > 0).toList();
    final negativeFactors = displayFactors.where((f) => f.impactDays < 0).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple.shade700, size: 22),
                const SizedBox(width: 8),
                const Text(
                  '影响因素分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (factors.length > maxItems && expandable)
                  TextButton(
                    onPressed: () => _showAllFactors(context),
                    child: const Text('查看全部'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 正向因素
            if (positiveFactors.isNotEmpty) ...[
              _buildSectionHeader('正向因素', Colors.green),
              const SizedBox(height: 8),
              ...positiveFactors.map((f) => _buildFactorItem(f, isPositive: true)),
              const SizedBox(height: 16),
            ],

            // 负向因素
            if (negativeFactors.isNotEmpty) ...[
              _buildSectionHeader('负向因素', Colors.red),
              const SizedBox(height: 8),
              ...negativeFactors.map((f) => _buildFactorItem(f, isPositive: false)),
            ],

            // 无数据提示
            if (factors.isEmpty) _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFactorItem(MoneyAgeImpactAnalysis factor, {required bool isPositive}) {
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;
    final impactText = isPositive
        ? '+${factor.impactDays.toStringAsFixed(1)}天'
        : '${factor.impactDays.toStringAsFixed(1)}天';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // 分类图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              DefaultCategories.findById(factor.categoryId)?.icon ?? Icons.category,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // 分类信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DefaultCategories.findById(factor.categoryId)?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(factor.categoryName),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${factor.transactionCount}笔',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '¥${factor.totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 影响值
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 2),
                Text(
                  impactText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              '暂无影响因素数据',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllFactors(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '全部影响因素',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: factors.length,
                itemBuilder: (context, index) {
                  final factor = factors[index];
                  return _buildFactorItem(
                    factor,
                    isPositive: factor.impactDays > 0,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 影响因素可视化柱状图
class MoneyAgeInfluenceChart extends StatelessWidget {
  final List<MoneyAgeImpactAnalysis> factors;
  final double height;

  const MoneyAgeInfluenceChart({
    super.key,
    required this.factors,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (factors.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('暂无数据')),
      );
    }

    // 找出最大影响值用于归一化
    final maxImpact = factors
        .map((f) => f.impactDays.abs())
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: factors.map((factor) {
          final normalizedHeight = (factor.impactDays.abs() / maxImpact) * (height - 40);
          final isPositive = factor.impactDays > 0;
          final color = isPositive ? Colors.green : Colors.red;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 数值标签
                  Text(
                    '${isPositive ? '+' : ''}${factor.impactDays.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 柱状图
                  Container(
                    height: normalizedHeight.clamp(20.0, height - 40),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 分类标签
                  SizedBox(
                    height: 16,
                    child: Text(
                      () {
                        final name = DefaultCategories.findById(factor.categoryId)?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(factor.categoryName);
                        return name.length > 4 ? '${name.substring(0, 3)}...' : name;
                      }(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 影响因素饼图
class MoneyAgeInfluencePieChart extends StatelessWidget {
  final List<MoneyAgeImpactAnalysis> factors;
  final double size;

  const MoneyAgeInfluencePieChart({
    super.key,
    required this.factors,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (factors.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: Text('暂无数据')),
      );
    }

    // 分离正负因素
    final positiveSum = factors
        .where((f) => f.impactDays > 0)
        .fold(0.0, (sum, f) => sum + f.impactDays);
    final negativeSum = factors
        .where((f) => f.impactDays < 0)
        .fold(0.0, (sum, f) => sum + f.impactDays.abs());
    final total = positiveSum + negativeSum;

    if (total == 0) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: Text('暂无数据')),
      );
    }

    final positivePercent = positiveSum / total;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PieChartPainter(
          positivePercent: positivePercent,
          positiveColor: Colors.green,
          negativeColor: Colors.red,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(positivePercent * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Text(
                '正向影响',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final double positivePercent;
  final Color positiveColor;
  final Color negativeColor;

  _PieChartPainter({
    required this.positivePercent,
    required this.positiveColor,
    required this.negativeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    // 绘制负向部分（背景）
    paint.color = negativeColor.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius, paint);

    // 绘制正向部分
    paint.color = positiveColor;
    final sweepAngle = 2 * 3.14159 * positivePercent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // 从顶部开始
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return positivePercent != oldDelegate.positivePercent;
  }
}

/// 影响因素趋势对比
class MoneyAgeInfluenceTrend extends StatelessWidget {
  /// 当期影响因素
  final List<MoneyAgeImpactAnalysis> currentPeriod;

  /// 上期影响因素
  final List<MoneyAgeImpactAnalysis> previousPeriod;

  const MoneyAgeInfluenceTrend({
    super.key,
    required this.currentPeriod,
    required this.previousPeriod,
  });

  @override
  Widget build(BuildContext context) {
    // 合并分类
    final allCategories = {
      ...currentPeriod.map((f) => f.categoryName),
      ...previousPeriod.map((f) => f.categoryName),
    };

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '影响因素变化',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...allCategories.map((category) {
              final current = currentPeriod
                  .firstWhere(
                    (f) => f.categoryName == category,
                    orElse: () => MoneyAgeImpactAnalysis(
                      categoryId: '',
                      categoryName: category,
                      impactDays: 0,
                      totalAmount: 0,
                      transactionCount: 0,
                      averageMoneyAge: 0,
                    ),
                  );
              final previous = previousPeriod
                  .firstWhere(
                    (f) => f.categoryName == category,
                    orElse: () => MoneyAgeImpactAnalysis(
                      categoryId: '',
                      categoryName: category,
                      impactDays: 0,
                      totalAmount: 0,
                      transactionCount: 0,
                      averageMoneyAge: 0,
                    ),
                  );

              final change = current.impactDays - previous.impactDays;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        category,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildComparisonBar(
                        previous.impactDays,
                        current.impactDays,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: change > 0
                              ? Colors.green
                              : change < 0
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonBar(double previous, double current) {
    final maxValue = [previous.abs(), current.abs(), 1.0].reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        // 上期
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: previous >= 0 ? Alignment.centerLeft : Alignment.centerRight,
              widthFactor: (previous.abs() / maxValue).clamp(0.05, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: previous >= 0 ? Colors.green.shade300 : Colors.red.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // 本期
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: current >= 0 ? Alignment.centerLeft : Alignment.centerRight,
              widthFactor: (current.abs() / maxValue).clamp(0.05, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: current >= 0 ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
