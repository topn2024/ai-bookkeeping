import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';

/// 用户画像可视化页面
///
/// 对应原型设计 14.11 用户画像可视化
/// 展示用户画像分析结果，包括消费性格、行为特征、偏好雷达图等
class UserProfileVisualizationPage extends ConsumerStatefulWidget {
  const UserProfileVisualizationPage({super.key});

  @override
  ConsumerState<UserProfileVisualizationPage> createState() =>
      _UserProfileVisualizationPageState();
}

class _UserProfileVisualizationPageState
    extends ConsumerState<UserProfileVisualizationPage> {
  @override
  void initState() {
    super.initState();
  }

  UserProfileDisplayData _calculateProfileData() {
    final transactions = ref.watch(transactionProvider);
    final budgets = ref.watch(budgetProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 筛选本月交易
    final monthlyTransactions = transactions.where((t) =>
        t.date.isAfter(monthStart.subtract(const Duration(days: 1)))).toList();

    final expenses = monthlyTransactions.where((t) => t.type == TransactionType.expense).toList();
    final incomes = monthlyTransactions.where((t) => t.type == TransactionType.income).toList();

    final totalExpense = expenses.fold<double>(0, (sum, t) => sum + t.amount);
    final totalIncome = incomes.fold<double>(0, (sum, t) => sum + t.amount);

    // 计算储蓄率
    final savingsRate = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100).clamp(0, 100) : 0;

    // 计算预算遵守度
    final enabledBudgets = budgets.where((b) => b.isEnabled).toList();
    double budgetCompliance = 100;
    if (enabledBudgets.isNotEmpty) {
      final categorySpent = <String, double>{};
      for (final t in expenses) {
        categorySpent[t.category] = (categorySpent[t.category] ?? 0) + t.amount;
      }
      int withinBudget = 0;
      for (final budget in enabledBudgets) {
        final categoryId = budget.categoryId;
        if (categoryId == null) continue;
        final spent = categorySpent[categoryId] ?? 0;
        if (spent <= budget.amount) withinBudget++;
      }
      budgetCompliance = enabledBudgets.isNotEmpty
          ? (withinBudget / enabledBudgets.length * 100)
          : 100;
    }

    // 计算消费行为特征
    final categoryCount = <String, int>{};
    for (final t in expenses) {
      categoryCount[t.category] = (categoryCount[t.category] ?? 0) + 1;
    }

    final behaviors = <BehaviorItem>[];
    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedCategories.take(6)) {
      final category = DefaultCategories.findById(entry.key);
      final frequency = _getFrequencyLabel(entry.value);
      behaviors.add(BehaviorItem(
        name: category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(entry.key),
        frequency: frequency,
        icon: category?.icon ?? Icons.category,
      ));
    }

    // 如果没有数据，显示默认行为
    if (behaviors.isEmpty) {
      behaviors.addAll(const [
        BehaviorItem(name: '餐饮', frequency: '无数据', icon: Icons.restaurant),
        BehaviorItem(name: '交通', frequency: '无数据', icon: Icons.directions_car),
        BehaviorItem(name: '购物', frequency: '无数据', icon: Icons.shopping_bag),
      ]);
    }

    // 计算能力雷达图数据
    final recordingHabit = transactions.isNotEmpty ? 0.5 + (transactions.length / 100).clamp(0, 0.5) : 0.0;
    final planningAbility = budgetCompliance / 100;
    final savingsAwareness = savingsRate / 100;
    final riskControl = budgetCompliance > 80 ? 0.8 : budgetCompliance / 100;
    final rationalSpending = totalExpense > 0 && totalIncome > 0
        ? (1 - (totalExpense / totalIncome)).clamp(0, 1)
        : 0.5;

    // 确定用户类型
    String personaType;
    String personaDescription;
    if (savingsRate > 30 && budgetCompliance > 80) {
      personaType = '目标导向型';
      personaDescription = '理性消费，注重规划';
    } else if (savingsRate > 20) {
      personaType = '稳健型';
      personaDescription = '收支平衡，稳步积累';
    } else if (transactions.isEmpty) {
      personaType = '新用户';
      personaDescription = '开始记录，了解自己';
    } else {
      personaType = '探索型';
      personaDescription = '积极尝试，寻找平衡';
    }

    // 生成推荐
    final recommendations = <String>[];
    if (savingsRate < 20 && totalIncome > 0) {
      recommendations.add('您的储蓄率偏低，建议关注非必要支出');
    }
    if (budgetCompliance < 80 && enabledBudgets.isNotEmpty) {
      recommendations.add('部分预算超支，建议调整消费计划');
    }
    if (sortedCategories.isNotEmpty) {
      final topCategory = DefaultCategories.findById(sortedCategories.first.key);
      recommendations.add('您在${topCategory?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(sortedCategories.first.key)}类目消费较多，可关注相关优惠');
    }
    if (recommendations.isEmpty) {
      recommendations.add('继续保持良好的记账习惯');
    }

    return UserProfileDisplayData(
      personaType: personaType,
      personaDescription: personaDescription,
      avatarColor: AppTheme.primaryColor,
      demographics: const [
        DemographicTag(label: '用户', icon: Icons.person),
      ],
      behaviors: behaviors,
      radarData: RadarChartData(
        labels: const ['理性消费', '规划能力', '储蓄意识', '风险控制', '记账习惯'],
        values: [rationalSpending.toDouble(), planningAbility.toDouble(), savingsAwareness.toDouble(), riskControl.toDouble(), recordingHabit.toDouble()],
      ),
      healthIndicators: [
        HealthIndicator(
          name: '储蓄率',
          value: savingsRate.round(),
          unit: '%',
          status: savingsRate >= 30 ? IndicatorStatus.excellent
              : savingsRate >= 20 ? IndicatorStatus.good
              : savingsRate >= 10 ? IndicatorStatus.fair
              : IndicatorStatus.poor,
        ),
        HealthIndicator(
          name: '预算遵守度',
          value: budgetCompliance.round(),
          unit: '%',
          status: budgetCompliance >= 90 ? IndicatorStatus.excellent
              : budgetCompliance >= 70 ? IndicatorStatus.good
              : budgetCompliance >= 50 ? IndicatorStatus.fair
              : IndicatorStatus.poor,
        ),
        HealthIndicator(
          name: '记录笔数',
          value: monthlyTransactions.length,
          unit: '笔',
          status: monthlyTransactions.length >= 30 ? IndicatorStatus.excellent
              : monthlyTransactions.length >= 15 ? IndicatorStatus.good
              : monthlyTransactions.length >= 5 ? IndicatorStatus.fair
              : IndicatorStatus.poor,
        ),
      ],
      recommendations: recommendations,
    );
  }

  String _getFrequencyLabel(int count) {
    if (count >= 20) return '高频';
    if (count >= 10) return '中频';
    if (count >= 5) return '低频';
    return '偶发';
  }

  @override
  Widget build(BuildContext context) {
    final profileData = _calculateProfileData();
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的画像'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户头像与人格类型
          _PersonaCard(data: profileData),

          const SizedBox(height: 20),

          // 人口统计学标签
          _DemographicsSection(tags: profileData.demographics),

          const SizedBox(height: 20),

          // 消费行为特征网格
          _BehaviorGrid(behaviors: profileData.behaviors),

          const SizedBox(height: 20),

          // 偏好雷达图
          _PreferenceRadarChart(data: profileData.radarData),

          const SizedBox(height: 20),

          // 财务健康指标
          _HealthIndicatorsSection(indicators: profileData.healthIndicators),

          const SizedBox(height: 20),

          // 个性化推荐
          _RecommendationsSection(recommendations: profileData.recommendations),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('用户画像说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户画像基于您的记账数据分析生成，包括：'),
            SizedBox(height: 12),
            Text('• 消费性格：根据消费行为推断的性格类型'),
            Text('• 行为特征：各消费类目的使用频率'),
            Text('• 偏好雷达图：多维度财务能力展示'),
            Text('• 健康指标：关键财务健康数值'),
            SizedBox(height: 12),
            Text('所有数据仅存储在本地，用于个性化推荐。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// 人格类型卡片
class _PersonaCard extends StatelessWidget {
  final UserProfileDisplayData data;

  const _PersonaCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.avatarColor,
            data.avatarColor.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: data.avatarColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data.personaType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.personaDescription,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 人口统计学标签区域
class _DemographicsSection extends StatelessWidget {
  final List<DemographicTag> tags;

  const _DemographicsSection({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '基础特征',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tags.map((tag) => _buildTag(tag)).toList(),
        ),
      ],
    );
  }

  Widget _buildTag(DemographicTag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            tag.label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// 消费行为网格
class _BehaviorGrid extends StatelessWidget {
  final List<BehaviorItem> behaviors;

  const _BehaviorGrid({required this.behaviors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '消费行为特征',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: behaviors.length,
          itemBuilder: (context, index) => _buildBehaviorItem(behaviors[index]),
        ),
      ],
    );
  }

  Widget _buildBehaviorItem(BehaviorItem item) {
    final color = _getFrequencyColor(item.frequency);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.frequency,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getFrequencyColor(String frequency) {
    switch (frequency) {
      case '高频':
        return const Color(0xFFEF5350);
      case '中频':
        return const Color(0xFFFFB74D);
      case '低频':
        return const Color(0xFF66BB6A);
      case '偶发':
        return const Color(0xFF9E9E9E);
      default:
        return Colors.grey;
    }
  }
}

/// 偏好雷达图
class _PreferenceRadarChart extends StatelessWidget {
  final RadarChartData data;

  const _PreferenceRadarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '能力画像',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _RadarChartPainter(data: data),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

/// 雷达图绘制器
class _RadarChartPainter extends CustomPainter {
  final RadarChartData data;

  _RadarChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 40;
    final angleStep = (2 * math.pi) / data.labels.length;

    // 绘制背景网格
    _drawGrid(canvas, center, radius, data.labels.length);

    // 绘制数据区域
    _drawDataArea(canvas, center, radius, angleStep);

    // 绘制标签
    _drawLabels(canvas, center, radius + 25, angleStep);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius, int sides) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final angleStep = (2 * math.pi) / sides;

    // 绘制同心圆
    for (int i = 1; i <= 4; i++) {
      final r = radius * i / 4;
      final path = Path();
      for (int j = 0; j < sides; j++) {
        final angle = -math.pi / 2 + j * angleStep;
        final point = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (j == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 绘制放射线
    for (int i = 0; i < sides; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, endPoint, gridPaint);
    }
  }

  void _drawDataArea(
      Canvas canvas, Offset center, double radius, double angleStep) {
    final fillPaint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    for (int i = 0; i < data.values.length; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final value = data.values[i].clamp(0.0, 1.0);
      final point = Offset(
        center.dx + radius * value * math.cos(angle),
        center.dy + radius * value * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // 绘制数据点
    final dotPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.values.length; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final value = data.values[i].clamp(0.0, 1.0);
      final point = Offset(
        center.dx + radius * value * math.cos(angle),
        center.dy + radius * value * math.sin(angle),
      );
      canvas.drawCircle(point, 5, dotPaint);
    }
  }

  void _drawLabels(
      Canvas canvas, Offset center, double labelRadius, double angleStep) {
    for (int i = 0; i < data.labels.length; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final labelPoint = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      final textSpan = TextSpan(
        text: data.labels[i],
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final offset = Offset(
        labelPoint.dx - textPainter.width / 2,
        labelPoint.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(_RadarChartPainter oldDelegate) =>
      oldDelegate.data != data;
}

/// 健康指标区域
class _HealthIndicatorsSection extends StatelessWidget {
  final List<HealthIndicator> indicators;

  const _HealthIndicatorsSection({required this.indicators});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '财务健康指标',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: indicators
                .map((indicator) => _buildIndicator(indicator))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(HealthIndicator indicator) {
    final color = _getStatusColor(indicator.status);

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Text(
              '${indicator.value}${indicator.unit}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          indicator.name,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(IndicatorStatus status) {
    switch (status) {
      case IndicatorStatus.excellent:
        return const Color(0xFF4CAF50);
      case IndicatorStatus.good:
        return const Color(0xFF8BC34A);
      case IndicatorStatus.fair:
        return const Color(0xFFFFB74D);
      case IndicatorStatus.poor:
        return const Color(0xFFFF7043);
    }
  }
}

/// 个性化推荐区域
class _RecommendationsSection extends StatelessWidget {
  final List<String> recommendations;

  const _RecommendationsSection({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '个性化推荐',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rec,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

// ==================== 数据模型 ====================

/// 用户画像展示数据
class UserProfileDisplayData {
  final String personaType;
  final String personaDescription;
  final Color avatarColor;
  final List<DemographicTag> demographics;
  final List<BehaviorItem> behaviors;
  final RadarChartData radarData;
  final List<HealthIndicator> healthIndicators;
  final List<String> recommendations;

  const UserProfileDisplayData({
    required this.personaType,
    required this.personaDescription,
    required this.avatarColor,
    required this.demographics,
    required this.behaviors,
    required this.radarData,
    required this.healthIndicators,
    required this.recommendations,
  });
}

/// 人口统计学标签
class DemographicTag {
  final String label;
  final IconData icon;

  const DemographicTag({required this.label, required this.icon});
}

/// 消费行为项
class BehaviorItem {
  final String name;
  final String frequency;
  final IconData icon;

  const BehaviorItem({
    required this.name,
    required this.frequency,
    required this.icon,
  });
}

/// 雷达图数据
class RadarChartData {
  final List<String> labels;
  final List<double> values;

  const RadarChartData({required this.labels, required this.values});
}

/// 健康指标
class HealthIndicator {
  final String name;
  final int value;
  final String unit;
  final IndicatorStatus status;

  const HealthIndicator({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
  });
}

/// 指标状态
enum IndicatorStatus { excellent, good, fair, poor }
