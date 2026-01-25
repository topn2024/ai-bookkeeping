import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/financial_health_score_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../providers/transaction_provider.dart';

// Provider for health score service
final habitHealthScoreProvider = FutureProvider<FinancialHealthScore>((ref) async {
  final dbService = sl<IDatabaseService>();
  final service = FinancialHealthScoreService(dbService);
  return await service.calculateScore();
});

/// 记账习惯评分详情页面
class RecordingHabitScorePage extends ConsumerWidget {
  const RecordingHabitScorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthScoreAsync = ref.watch(habitHealthScoreProvider);
    final transactions = ref.watch(transactionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记账习惯评分'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: healthScoreAsync.when(
        data: (healthScore) {
          final habitComponent = healthScore.components['habit']!;
          return _buildContent(context, habitComponent, transactions);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScoreComponent habitComponent, List transactions) {
    final score = habitComponent.score;
    final maxScore = habitComponent.maxScore;

    // 分析记账统计
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final recentTransactions = transactions.where((t) => t.date.isAfter(last30Days)).toList();

    // 按日期分组
    final dayGroups = <String, int>{};
    for (final t in recentTransactions) {
      final dateKey = '${t.date.year}-${t.date.month}-${t.date.day}';
      dayGroups[dateKey] = (dayGroups[dateKey] ?? 0) + 1;
    }

    final recordedDays = dayGroups.length;
    final totalRecords = recentTransactions.length;
    final averagePerDay = recordedDays > 0 ? (totalRecords / recordedDays).toStringAsFixed(1) : '0';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前得分卡片
        _buildScoreCard(score, maxScore, habitComponent.status),

        const SizedBox(height: 24),

        // 记账统计
        _buildRecordingStats(recordedDays, totalRecords, averagePerDay),

        const SizedBox(height: 24),

        // 评分规则说明
        _buildScoringRules(),

        const SizedBox(height: 24),

        // 改进建议
        _buildImprovementSuggestions(score, recordedDays),

        const SizedBox(height: 24),

        // 养成习惯的方法
        _buildHabitBuildingTips(),
      ],
    );
  }

  Widget _buildScoreCard(int score, int maxScore, String status) {
    final percentage = score / maxScore;
    final color = percentage >= 0.75 ? Colors.green : (percentage >= 0.5 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '记账习惯得分',
            style: TextStyle(color: Colors.white, fontSize: 14),
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
                ),
              ),
              Text(
                '/$maxScore',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingStats(int recordedDays, int totalRecords, String averagePerDay) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                '近30天记账统计',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('记账天数', '$recordedDays天', Icons.calendar_month, AppTheme.primaryColor),
              ),
              Container(width: 1, height: 60, color: Colors.grey[300]),
              Expanded(
                child: _buildStatItem('总记录数', '$totalRecords笔', Icons.receipt_long, Colors.orange),
              ),
              Container(width: 1, height: 60, color: Colors.grey[300]),
              Expanded(
                child: _buildStatItem('日均记录', '$averagePerDay笔', Icons.trending_up, Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: recordedDays / 30,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '已记账 $recordedDays / 30 天 (${(recordedDays / 30 * 100).toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildScoringRules() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                '评分规则',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '记账习惯得分基于近30天的记账天数评估：',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildRuleRow('25-30天', '20分', '优秀', Colors.green),
          _buildRuleRow('20-24天', '18分', '良好', Colors.green[300]!),
          _buildRuleRow('15-19天', '15分', '尚可', Colors.orange),
          _buildRuleRow('10-14天', '12分', '需加强', Colors.orange[700]!),
          _buildRuleRow('5-9天', '8分', '偏低', Colors.red[300]!),
          _buildRuleRow('0-4天', '5分', '不足', Colors.red),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String range, String score, String level, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              range,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              score,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                level,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementSuggestions(int score, int recordedDays) {
    final suggestions = <String>[];

    if (recordedDays < 25) {
      suggestions.add('养成每日记账的习惯，不要遗漏任何开支');
    }
    if (recordedDays < 20) {
      suggestions.add('设置记账提醒，在每天固定时间记录当日消费');
    }
    if (recordedDays < 15) {
      suggestions.add('使用语音记账功能，让记账更加便捷');
    }
    if (recordedDays < 10) {
      suggestions.add('可以先从记录大额消费开始，逐步养成习惯');
    }

    suggestions.add('坚持记账21天，可以初步养成习惯');
    suggestions.add('保存消费凭证，方便后续补录和核对');

    return Container(
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
              const Icon(Icons.lightbulb, color: Color(0xFFF57C00), size: 20),
              const SizedBox(width: 8),
              const Text(
                '改进建议',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFFF57C00), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildHabitBuildingTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '养成记账习惯的方法',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem(
            '1. 设定固定时间',
            '每天睡前或早起后记录前一天的消费',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            '2. 使用便捷工具',
            '利用语音记账、照片识别等功能快速记录',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            '3. 设置提醒',
            '在手机上设置每日记账提醒',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            '4. 记录奖励',
            '连续记账7天、30天等里程碑给自己小奖励',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            '5. 及时记录',
            '消费后立即记录，避免遗忘',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('为什么要养成记账习惯？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('良好的记账习惯是财务管理的基础：'),
            SizedBox(height: 12),
            Text('• 清楚了解资金流向'),
            Text('• 发现不合理的开支'),
            Text('• 更好地控制预算'),
            Text('• 培养理财意识'),
            SizedBox(height: 12),
            Text('研究表明：'),
            SizedBox(height: 8),
            Text('• 坚持记账21天可初步养成习惯'),
            Text('• 坚持记账90天可巩固习惯'),
            Text('• 长期记账者储蓄率平均提高30%'),
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
