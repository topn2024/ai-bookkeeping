import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'batch_ai_training_page.dart';

/// 8.29 AI学习成长曲线页面
/// 展示AI识别准确率的成长过程
class AILearningCurvePage extends ConsumerStatefulWidget {
  const AILearningCurvePage({super.key});

  @override
  ConsumerState<AILearningCurvePage> createState() => _AILearningCurvePageState();
}

class _AILearningCurvePageState extends ConsumerState<AILearningCurvePage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.aiLearningCurve,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAccuracyCard(),
            _buildGrowthChart(),
            _buildMilestones(),
            _buildTrainingTips(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF9370DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Center(
                  child: Text(
                    '92%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '当前分类准确率',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '较上月提升 5%',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthChart() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '准确率成长曲线',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: _GrowthChartPainter(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('第1周', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('第4周', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('第8周', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('现在', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestones() {
    final milestones = [
      {'level': 'Lv.1', 'name': '新手期', 'accuracy': '60-70%', 'achieved': true},
      {'level': 'Lv.2', 'name': '成长期', 'accuracy': '70-85%', 'achieved': true},
      {'level': 'Lv.3', 'name': '成熟期', 'accuracy': '85-95%', 'achieved': true},
      {'level': 'Lv.4', 'name': '专家级', 'accuracy': '95%+', 'achieved': false},
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI成长里程碑',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...milestones.map((milestone) {
            final achieved = milestone['achieved'] as bool;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: achieved
                    ? AppColors.success.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: achieved
                      ? AppColors.success
                      : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: achieved
                          ? AppColors.success
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: achieved
                          ? const Icon(Icons.check, color: Colors.white)
                          : Text(
                              milestone['level'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              milestone['level'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              milestone['name'] as String,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '准确率 ${milestone['accuracy']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (achieved)
                    Icon(
                      Icons.verified,
                      color: AppColors.success,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrainingTips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: const Color(0xFFF57C00)),
              const SizedBox(width: 8),
              const Text(
                '如何提升AI准确率？',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('1. 及时纠正错误分类'),
          _buildTipItem('2. 添加详细的消费备注'),
          _buildTipItem('3. 保持规律的记账习惯'),
          _buildTipItem('4. 使用批量训练功能'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BatchAITrainingPage()),
              );
            },
            icon: const Icon(Icons.school, size: 18),
            label: const Text('批量训练AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: const Color(0xFFF57C00),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.primaryColor.withValues(alpha: 0.3),
          AppTheme.primaryColor.withValues(alpha: 0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Data points (week, accuracy percentage)
    final dataPoints = [
      Offset(0, size.height * 0.6), // 60%
      Offset(size.width * 0.15, size.height * 0.5), // 70%
      Offset(size.width * 0.3, size.height * 0.35), // 78%
      Offset(size.width * 0.5, size.height * 0.25), // 85%
      Offset(size.width * 0.7, size.height * 0.18), // 88%
      Offset(size.width * 0.85, size.height * 0.12), // 90%
      Offset(size.width, size.height * 0.08), // 92%
    ];

    // Draw fill
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (var point in dataPoints) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePath = Path();
    linePath.moveTo(dataPoints.first.dx, dataPoints.first.dy);
    for (var i = 1; i < dataPoints.length; i++) {
      linePath.lineTo(dataPoints[i].dx, dataPoints[i].dy);
    }
    canvas.drawPath(linePath, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;

    for (var point in dataPoints) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
