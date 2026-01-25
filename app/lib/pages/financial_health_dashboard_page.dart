import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'money_age_score_page.dart';
import 'budget_control_score_page.dart';
import 'emergency_fund_score_page.dart';
import 'spending_structure_score_page.dart';
import 'recording_habit_score_page.dart';
import '../services/financial_health_score_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

// Provider for FinancialHealthScoreService
final healthScoreServiceProvider = Provider<FinancialHealthScoreService>((ref) {
  final dbService = sl<IDatabaseService>();
  return FinancialHealthScoreService(dbService);
});

// Provider for health score (async)
final healthScoreProvider = FutureProvider<FinancialHealthScore>((ref) async {
  final service = ref.watch(healthScoreServiceProvider);
  return await service.calculateScore();
});

/// 财务健康仪表盘页面
///
/// 对应原型设计 10.01 财务健康仪表盘
/// 展示用户的财务健康综合评分和5个维度分析
class FinancialHealthDashboardPage extends ConsumerWidget {
  const FinancialHealthDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthScoreAsync = ref.watch(healthScoreProvider);

    return healthScoreAsync.when(
      data: (healthScore) => _buildContent(context, healthScore),
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('财务健康'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('财务健康'),
        ),
        body: Center(
          child: Text('加载失败: $error'),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FinancialHealthScore healthScore) {
    final moneyAgeComponent = healthScore.components['moneyAge']!;
    final budgetComponent = healthScore.components['budget']!;
    final emergencyComponent = healthScore.components['emergency']!;
    final structureComponent = healthScore.components['structure']!;
    final habitComponent = healthScore.components['habit']!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('财务健康'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 总分展示
          _HealthScoreCard(
            score: healthScore.totalScore,
            status: healthScore.level.displayName,
            change: healthScore.comparisonToLastMonth,
          ),

          // 5维度得分
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              '健康维度分析',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 钱龄得分
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MoneyAgeScorePage()),
            ),
            child: _DimensionCard(
              icon: Icons.schedule,
              iconColor: AppTheme.primaryColor,
              iconBgColor: const Color(0xFFEBF3FF),
              title: '钱龄',
              score: moneyAgeComponent.score,
              maxScore: moneyAgeComponent.maxScore,
              status: moneyAgeComponent.status,
              statusColor: _getColorFromScore(moneyAgeComponent.score, moneyAgeComponent.maxScore),
            ),
          ),

          // 预算控制
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetControlScorePage()),
            ),
            child: _DimensionCard(
              icon: Icons.account_balance_wallet,
              iconColor: const Color(0xFFFFB74D),
              iconBgColor: const Color(0xFFFFF3E0),
              title: '预算控制',
              score: budgetComponent.score,
              maxScore: budgetComponent.maxScore,
              status: budgetComponent.status,
              statusColor: _getColorFromScore(budgetComponent.score, budgetComponent.maxScore),
            ),
          ),

          // 应急金
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencyFundScorePage()),
            ),
            child: _DimensionCard(
              icon: Icons.shield,
              iconColor: const Color(0xFF66BB6A),
              iconBgColor: const Color(0xFFE8F5E9),
              title: '应急金',
              score: emergencyComponent.score,
              maxScore: emergencyComponent.maxScore,
              status: emergencyComponent.status,
              statusColor: _getColorFromScore(emergencyComponent.score, emergencyComponent.maxScore),
            ),
          ),

          // 消费结构
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SpendingStructureScorePage()),
            ),
            child: _DimensionCard(
              icon: Icons.pie_chart,
              iconColor: const Color(0xFF7B1FA2),
              iconBgColor: const Color(0xFFF3E5F5),
              title: '消费结构',
              score: structureComponent.score,
              maxScore: structureComponent.maxScore,
              status: structureComponent.status,
              statusColor: _getColorFromScore(structureComponent.score, structureComponent.maxScore),
            ),
          ),

          // 记账习惯
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordingHabitScorePage()),
            ),
            child: _DimensionCard(
              icon: Icons.edit_note,
              iconColor: const Color(0xFF26A69A),
              iconBgColor: const Color(0xFFE0F2F1),
              title: '记账习惯',
              score: habitComponent.score,
              maxScore: habitComponent.maxScore,
              status: habitComponent.status,
              statusColor: _getColorFromScore(habitComponent.score, habitComponent.maxScore),
            ),
          ),

          // 改进建议
          if (healthScore.primaryImprovementArea != null)
            _ImprovementSuggestion(
              area: healthScore.primaryImprovementArea!.name,
              suggestion: healthScore.primaryImprovementArea!.tip ?? '继续保持良好的财务习惯',
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color _getColorFromScore(int score, int maxScore) {
    final percentage = score / maxScore;
    if (percentage >= 0.75) return Colors.green;
    if (percentage >= 0.5) return Colors.orange;
    return Colors.red;
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('财务健康指数说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('财务健康指数由5个维度综合计算：'),
            SizedBox(height: 12),
            Text('• 钱龄：资金持有时间'),
            Text('• 预算控制：预算执行情况'),
            Text('• 应急金：紧急备用金储备'),
            Text('• 消费结构：必要vs非必要支出'),
            Text('• 记账习惯：记账频率和完整度'),
            SizedBox(height: 12),
            Text('每个维度满分20分，总分100分。'),
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

/// 健康分数卡片
class _HealthScoreCard extends StatelessWidget {
  final int score;
  final String status;
  final int change;

  const _HealthScoreCard({
    required this.score,
    required this.status,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '财务健康综合分',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                score.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/100',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (change != 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 维度分数卡片
class _DimensionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final int score;
  final int maxScore;
  final String status;
  final Color statusColor;

  const _DimensionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = score / maxScore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      score.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '/$maxScore',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 改进建议卡片
class _ImprovementSuggestion extends StatelessWidget {
  final String area;
  final String suggestion;

  const _ImprovementSuggestion({
    required this.area,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.orange[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '改进建议',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$area：$suggestion',
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange[900],
            ),
          ),
        ],
      ),
    );
  }
}
