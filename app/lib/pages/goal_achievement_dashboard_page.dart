import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../services/goal_achievement_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

/// 目标达成服务 Provider
final goalAchievementServiceProvider = Provider<GoalAchievementService>((ref) {
  // 通过服务定位器获取数据库服务实例
  final dbService = sl<IDatabaseService>();
  return GoalAchievementService(dbService);
});

/// 目标达成概览 Provider
final goalAchievementOverviewProvider =
    FutureProvider<GoalAchievementOverview>((ref) async {
  final service = ref.watch(goalAchievementServiceProvider);
  return service.getOverview();
});

/// 目标达成仪表盘页面
///
/// 对应原型设计 7.14 目标达成仪表盘
/// 展示用户在各财务目标上的达成情况和综合健康分
class GoalAchievementDashboardPage extends ConsumerWidget {
  const GoalAchievementDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(goalAchievementOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('目标达成'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(goalAchievementOverviewProvider),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: overviewAsync.when(
        data: (overview) => _buildContent(context, overview),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(goalAchievementOverviewProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, GoalAchievementOverview overview) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 总体达成率环形图
        _OverallAchievementCard(overview: overview),

        const SizedBox(height: 20),

        // 目标分类标题
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '目标分类',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // 四大目标卡片
        ...overview.goals.map((goal) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GoalCard(goal: goal),
            )),

        const SizedBox(height: 20),

        // 财务健康综合分
        _HealthScoreSummary(
          score: overview.healthScore,
          progress: overview.monthlyProgress,
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目标达成说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('目标达成仪表盘帮助您追踪四个核心财务目标：'),
            SizedBox(height: 12),
            Text('• 钱龄健康：资金持有时间达到30天'),
            Text('• 预算执行：各项支出控制在预算内'),
            Text('• 记账习惯：连续21天每日记账'),
            Text('• 储蓄目标：月度储蓄达成率'),
            SizedBox(height: 12),
            Text('坚持完成这些目标，将显著提升您的财务健康水平。'),
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

/// 总体达成率卡片（含环形图）
class _OverallAchievementCard extends StatelessWidget {
  final GoalAchievementOverview overview;

  const _OverallAchievementCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    final rate = overview.overallRate;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 环形进度图
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: rate,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                progressColor: Colors.white,
                strokeWidth: 12,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(rate * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      '整体达成率',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 状态描述
          Text(
            overview.overallStatus,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          // 达成数量
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '已达成 ${overview.achievedCount}/${overview.totalGoals} 项目标',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个目标卡片
class _GoalCard extends StatelessWidget {
  final GoalAchievement goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconData(goal.type.iconName);
    final color = _getStatusColor(goal.statusLevel);

    return Container(
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
          // 头部：图标、标题、状态
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.type.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.type.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  goal.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.achievementRate.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 8),

          // 进度数值和提示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(goal.achievementRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              if (goal.tip != null)
                Expanded(
                  child: Text(
                    goal.tip!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'schedule':
        return Icons.schedule;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'edit_note':
        return Icons.edit_note;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.flag;
    }
  }

  Color _getStatusColor(String level) {
    switch (level) {
      case 'excellent':
        return const Color(0xFF4CAF50);
      case 'good':
        return const Color(0xFF8BC34A);
      case 'fair':
        return const Color(0xFFFFB74D);
      case 'needsWork':
        return const Color(0xFFFF7043);
      default:
        return Colors.grey;
    }
  }
}

/// 财务健康评分摘要
class _HealthScoreSummary extends StatelessWidget {
  final int score;
  final int progress;

  const _HealthScoreSummary({
    required this.score,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    String scoreLabel;

    if (score >= 90) {
      scoreColor = const Color(0xFF4CAF50);
      scoreLabel = '优秀';
    } else if (score >= 75) {
      scoreColor = const Color(0xFF8BC34A);
      scoreLabel = '良好';
    } else if (score >= 60) {
      scoreColor = const Color(0xFFFFB74D);
      scoreLabel = '及格';
    } else {
      scoreColor = const Color(0xFFFF7043);
      scoreLabel = '需改进';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // 分数圆形指示器
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withValues(alpha: 0.12),
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 文字描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '财务健康综合分',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        scoreLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: scoreColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (progress != 0)
                      Row(
                        children: [
                          Icon(
                            progress > 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 14,
                            color:
                                progress > 0 ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${progress > 0 ? '+' : ''}$progress分',
                            style: TextStyle(
                              fontSize: 12,
                              color: progress > 0
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 查看详情按钮
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              // 跳转到财务健康详情页
              Navigator.pushNamed(context, '/financial-health');
            },
          ),
        ],
      ),
    );
  }
}

/// 环形进度绘制器
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景圆
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 进度弧
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
