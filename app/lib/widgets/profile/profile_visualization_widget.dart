import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/user_profile_service.dart';

/// 用户画像可视化页面
class UserProfileVisualizationPage extends StatefulWidget {
  final String userId;
  final UserProfileService profileService;

  const UserProfileVisualizationPage({
    super.key,
    required this.userId,
    required this.profileService,
  });

  @override
  State<UserProfileVisualizationPage> createState() =>
      _UserProfileVisualizationPageState();
}

class _UserProfileVisualizationPageState
    extends State<UserProfileVisualizationPage> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await widget.profileService.getProfile(widget.userId);
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的财务画像')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_profile == null || !_profile!.hasEnoughData) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的财务画像')),
        body: const _InsufficientDataView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的财务画像'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
            tooltip: '刷新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PersonalityTagsCard(profile: _profile!),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _SpendingFeatureCard(profile: _profile!)),
                  const SizedBox(width: 16),
                  Expanded(child: _FinancialHealthCard(profile: _profile!)),
                ],
              ),
              const SizedBox(height: 16),
              _AbilityRadarChart(profile: _profile!),
              const SizedBox(height: 16),
              _AICommentCard(profile: _profile!),
              const SizedBox(height: 16),
              _PrivacyControlCard(
                onClear: _clearProfile,
                onDisable: _disablePersonalization,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除画像数据'),
        content: const Text('确定要清除所有画像数据吗？这将重置个性化体验。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 实际清除操作
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像数据已清除')),
      );
      setState(() => _profile = null);
    }
  }

  Future<void> _disablePersonalization() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关闭个性化'),
        content: const Text('关闭后将不再收集和使用个性化数据，但已有数据将保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已关闭个性化功能')),
      );
    }
  }
}

/// 数据不足视图
class _InsufficientDataView extends StatelessWidget {
  const _InsufficientDataView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              '数据收集中',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '继续使用记账功能，我会逐渐了解你的财务习惯，\n为你生成个性化的财务画像。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            _buildProgressIndicator(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(value: 0.3),
        const SizedBox(height: 8),
        Text(
          '预计还需记录约20笔交易',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
        ),
      ],
    );
  }
}

/// 性格标签卡片
class _PersonalityTagsCard extends StatelessWidget {
  final UserProfile profile;

  const _PersonalityTagsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tags = _generateTags();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '财务人格标签',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map((tag) => _buildTagChip(context, tag.label, tag.color))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontSize: 13,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.8),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  List<_TagInfo> _generateTags() {
    final tags = <_TagInfo>[
      _TagInfo(
        label: profile.personalityTraits.spendingPersonality.label,
        color: _getPersonalityColor(profile.personalityTraits.spendingPersonality),
      ),
    ];

    // 储蓄达人
    if (profile.financialFeatures.savingsRate > 20) {
      tags.add(const _TagInfo(label: '储蓄达人', color: Colors.green));
    }

    // 预算执行官
    if (profile.financialFeatures.budgetComplianceRate > 90) {
      tags.add(const _TagInfo(label: '预算执行官', color: Colors.blue));
    }

    // 早起记账族
    if (profile.basicAttributes.peakActiveTime == ActiveTimeSlot.morning) {
      tags.add(const _TagInfo(label: '早起记账族', color: Colors.orange));
    }

    // 夜猫子记账
    if (profile.basicAttributes.peakActiveTime == ActiveTimeSlot.lateNight) {
      tags.add(const _TagInfo(label: '夜猫子理财', color: Colors.indigo));
    }

    // 记账达人
    if (profile.basicAttributes.usageDays > 30 &&
        profile.basicAttributes.dailyRecordRate > 1.5) {
      tags.add(const _TagInfo(label: '记账达人', color: Colors.purple));
    }

    // 月光族风险
    if (profile.financialFeatures.savingsRate < 5 &&
        profile.spendingBehavior.impulseRatio > 0.3) {
      tags.add(const _TagInfo(label: '需注意月光风险', color: Colors.red));
    }

    return tags;
  }

  Color _getPersonalityColor(SpendingPersonality personality) {
    switch (personality) {
      case SpendingPersonality.frugalRational:
        return Colors.teal;
      case SpendingPersonality.enjoymentOriented:
        return Colors.pink;
      case SpendingPersonality.anxiousWorrier:
        return Colors.amber;
      case SpendingPersonality.goalDriven:
        return Colors.blue;
      case SpendingPersonality.casualBuddhist:
        return Colors.grey;
    }
  }
}

class _TagInfo {
  final String label;
  final Color color;

  const _TagInfo({required this.label, required this.color});
}

/// 消费特征卡片
class _SpendingFeatureCard extends StatelessWidget {
  final UserProfile profile;

  const _SpendingFeatureCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  '消费特征',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              context,
              '月均支出',
              '¥${profile.spendingBehavior.monthlyAverage.toStringAsFixed(0)}',
              Icons.calendar_month,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              context,
              '消费风格',
              profile.spendingBehavior.style.label,
              Icons.style,
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              context,
              '拿铁因子',
              '${(profile.spendingBehavior.latteFactorRatio * 100).toStringAsFixed(0)}%',
              Icons.coffee,
            ),
            if (profile.spendingBehavior.topCategories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'TOP消费类目',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: profile.spendingBehavior.topCategories
                    .take(3)
                    .map((c) => Chip(
                          label: Text(c, style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// 财务健康卡片
class _FinancialHealthCard extends StatelessWidget {
  final UserProfile profile;

  const _FinancialHealthCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '财务健康',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHealthItem(
              context,
              '储蓄率',
              '${profile.financialFeatures.savingsRate.toStringAsFixed(1)}%',
              _getSavingsRateColor(profile.financialFeatures.savingsRate),
            ),
            const SizedBox(height: 12),
            _buildHealthItem(
              context,
              '钱龄健康',
              profile.financialFeatures.moneyAgeHealth,
              _getMoneyAgeColor(profile.financialFeatures.moneyAgeHealth),
            ),
            const SizedBox(height: 12),
            _buildHealthItem(
              context,
              '预算达成',
              '${profile.financialFeatures.budgetComplianceRate.toStringAsFixed(0)}%',
              _getBudgetComplianceColor(
                  profile.financialFeatures.budgetComplianceRate),
            ),
            const SizedBox(height: 12),
            _buildHealthItem(
              context,
              '收入稳定性',
              profile.financialFeatures.incomeStability.label,
              _getIncomeStabilityColor(
                  profile.financialFeatures.incomeStability),
            ),
            const SizedBox(height: 12),
            _buildHealthItem(
              context,
              '负债水平',
              profile.financialFeatures.debtLevel.label,
              _getDebtLevelColor(profile.financialFeatures.debtLevel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ],
    );
  }

  Color _getSavingsRateColor(double rate) {
    if (rate >= 30) return Colors.green;
    if (rate >= 15) return Colors.orange;
    return Colors.red;
  }

  Color _getMoneyAgeColor(String health) {
    switch (health) {
      case '优秀':
        return Colors.green;
      case '良好':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Color _getBudgetComplianceColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getIncomeStabilityColor(IncomeStability stability) {
    switch (stability) {
      case IncomeStability.stable:
        return Colors.green;
      case IncomeStability.variable:
        return Colors.orange;
      case IncomeStability.irregular:
        return Colors.red;
    }
  }

  Color _getDebtLevelColor(DebtLevel level) {
    switch (level) {
      case DebtLevel.none:
        return Colors.green;
      case DebtLevel.low:
        return Colors.blue;
      case DebtLevel.moderate:
        return Colors.orange;
      case DebtLevel.high:
        return Colors.red;
    }
  }
}

/// 能力雷达图
class _AbilityRadarChart extends StatelessWidget {
  final UserProfile profile;

  const _AbilityRadarChart({required this.profile});

  @override
  Widget build(BuildContext context) {
    final abilities = _calculateAbilities();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.radar,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  '财务能力画像',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: CustomPaint(
                size: const Size(double.infinity, 220),
                painter: _RadarChartPainter(
                  abilities: abilities,
                  primaryColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: abilities.entries
                  .map((e) => _buildLegendItem(context, e.key, e.value))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 4),
        Text(
          '${(value * 100).toInt()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }

  Map<String, double> _calculateAbilities() {
    return {
      '记账习惯': _normalizeValue(profile.basicAttributes.dailyRecordRate, 0, 3),
      '储蓄能力': _normalizeValue(profile.financialFeatures.savingsRate, 0, 50),
      '预算执行':
          _normalizeValue(profile.financialFeatures.budgetComplianceRate, 0, 100),
      '消费控制': 1 - profile.spendingBehavior.impulseRatio,
      '财务规划': _normalizeValue(
          profile.financialFeatures.emergencyFundMonths, 0, 6),
    };
  }

  double _normalizeValue(double value, double min, double max) {
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }
}

/// 雷达图绘制器
class _RadarChartPainter extends CustomPainter {
  final Map<String, double> abilities;
  final Color primaryColor;

  _RadarChartPainter({
    required this.abilities,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 30;
    final count = abilities.length;
    final angle = 2 * math.pi / count;

    // 绘制背景网格
    _drawGrid(canvas, center, radius, count, angle);

    // 绘制数据区域
    _drawDataArea(canvas, center, radius, count, angle);

    // 绘制标签
    _drawLabels(canvas, center, radius, count, angle, size);
  }

  void _drawGrid(
    Canvas canvas,
    Offset center,
    double radius,
    int count,
    double angle,
  ) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制5层同心多边形
    for (int level = 1; level <= 5; level++) {
      final r = radius * level / 5;
      final path = Path();

      for (int i = 0; i <= count; i++) {
        final a = -math.pi / 2 + angle * i;
        final point = Offset(
          center.dx + r * math.cos(a),
          center.dy + r * math.sin(a),
        );

        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }

      canvas.drawPath(path, gridPaint);
    }

    // 绘制辐射线
    for (int i = 0; i < count; i++) {
      final a = -math.pi / 2 + angle * i;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(a),
          center.dy + radius * math.sin(a),
        ),
        gridPaint,
      );
    }
  }

  void _drawDataArea(
    Canvas canvas,
    Offset center,
    double radius,
    int count,
    double angle,
  ) {
    final fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    final values = abilities.values.toList();

    for (int i = 0; i <= count; i++) {
      final a = -math.pi / 2 + angle * (i % count);
      final r = radius * values[i % count];
      final point = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // 绘制数据点
    final dotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final a = -math.pi / 2 + angle * i;
      final r = radius * values[i];
      final point = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  void _drawLabels(
    Canvas canvas,
    Offset center,
    double radius,
    int count,
    double angle,
    Size size,
  ) {
    final labels = abilities.keys.toList();
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < count; i++) {
      final a = -math.pi / 2 + angle * i;
      final labelRadius = radius + 20;
      final point = Offset(
        center.dx + labelRadius * math.cos(a),
        center.dy + labelRadius * math.sin(a),
      );

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
        ),
      );
      textPainter.layout();

      final offset = Offset(
        point.dx - textPainter.width / 2,
        point.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// AI评语卡片
class _AICommentCard extends StatelessWidget {
  final UserProfile profile;

  const _AICommentCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final comment = _generateAIComment();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI小助手怎么看你',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.smart_toy,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      comment,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateAIComment() {
    final personality = profile.personalityTraits.spendingPersonality;
    final topCategory = profile.spendingBehavior.topCategories.isNotEmpty
        ? profile.spendingBehavior.topCategories.first
        : '日常消费';
    final savingsRate = profile.financialFeatures.savingsRate;
    final budgetRate = profile.financialFeatures.budgetComplianceRate;

    switch (personality) {
      case SpendingPersonality.frugalRational:
        return '你是一个非常有规划的人！每月都能按时记账，预算执行得很棒（$budgetRate%达成率）。'
            '在$topCategory方面有固定偏好，消费很有节制。继续保持，你的储蓄率$savingsRate%已经很优秀了！';

      case SpendingPersonality.goalDriven:
        return '你是一个目标明确的人！从你的消费习惯可以看出，你在为某个目标努力存钱。'
            '储蓄率达到$savingsRate%，说明你有很强的自控力。记住，每一笔节省都是向目标迈进的一步！';

      case SpendingPersonality.enjoymentOriented:
        return '你是一个懂得享受生活的人~在$topCategory上的消费较多，生活品质很重要嘛！'
            '不过也要适当注意一下储蓄哦，目前储蓄率是$savingsRate%，可以考虑设个小目标。';

      case SpendingPersonality.anxiousWorrier:
        return '看得出你对财务状况比较关注，这是很好的习惯！目前储蓄率$savingsRate%，'
            '预算达成率$budgetRate%，整体还不错。不用太焦虑，按部就班就好~';

      case SpendingPersonality.casualBuddhist:
        return '你的消费习惯比较随性自然，这也挺好的！主要消费在$topCategory上，生活需要一点弹性。'
            '如果想要更好地了解自己的财务状况，可以试着多记几笔账哦~';
    }
  }
}

/// 隐私控制卡片
class _PrivacyControlCard extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onDisable;

  const _PrivacyControlCard({
    required this.onClear,
    required this.onDisable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '隐私控制',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '你的画像数据仅存储在本地设备，用于提供个性化服务。你可以随时清除或关闭。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDisable,
                    icon: const Icon(Icons.toggle_off_outlined, size: 18),
                    label: const Text('关闭个性化'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清除数据'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 简化版画像卡片（用于其他页面嵌入）
class ProfileSummaryCard extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback? onTap;

  const ProfileSummaryCard({
    super.key,
    required this.profile,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: Icon(Icons.person_outline, color: Colors.grey[400]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '财务画像生成中...',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '继续使用以生成个性化画像',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  _getPersonalityIcon(
                      profile!.personalityTraits.spendingPersonality),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile!.personalityTraits.spendingPersonality.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '储蓄率 ${profile!.financialFeatures.savingsRate.toStringAsFixed(1)}% | '
                      '钱龄 ${profile!.financialFeatures.moneyAgeHealth}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPersonalityIcon(SpendingPersonality personality) {
    switch (personality) {
      case SpendingPersonality.frugalRational:
        return Icons.savings;
      case SpendingPersonality.enjoymentOriented:
        return Icons.celebration;
      case SpendingPersonality.anxiousWorrier:
        return Icons.shield;
      case SpendingPersonality.goalDriven:
        return Icons.flag;
      case SpendingPersonality.casualBuddhist:
        return Icons.spa;
    }
  }
}
