import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/financial_health_score_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../providers/budget_provider.dart';

// Provider for health score service
final emergencyHealthScoreProvider = FutureProvider<FinancialHealthScore>((ref) async {
  final dbService = sl<IDatabaseService>();
  final service = FinancialHealthScoreService(dbService);
  return await service.calculateScore();
});

/// 应急金评分详情页面
///
/// 展示应急金储备情况、评分规则和改进建议
class EmergencyFundScorePage extends ConsumerWidget {
  const EmergencyFundScorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthScoreAsync = ref.watch(emergencyHealthScoreProvider);
    final moneyAge = ref.watch(moneyAgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('应急金评分'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: healthScoreAsync.when(
        data: (healthScore) {
          final emergencyComponent = healthScore.components['emergency']!;
          return _buildContent(context, emergencyComponent, moneyAge.days);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScoreComponent emergencyComponent, int moneyAgeDays) {
    final score = emergencyComponent.score;
    final maxScore = emergencyComponent.maxScore;

    // 根据钱龄天数估算应急金月数
    final monthsCovered = (moneyAgeDays / 30).toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前得分卡片
        _buildScoreCard(score, maxScore, emergencyComponent.status),

        const SizedBox(height: 24),

        // 应急金储备情况
        _buildReserveStatus(moneyAgeDays, monthsCovered),

        const SizedBox(height: 24),

        // 评分规则说明
        _buildScoringRules(),

        const SizedBox(height: 24),

        // 改进建议
        _buildImprovementSuggestions(score, moneyAgeDays),

        const SizedBox(height: 24),

        // 行动指南
        _buildActionGuide(moneyAgeDays),
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
            '应急金得分',
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

  Widget _buildReserveStatus(int moneyAgeDays, String monthsCovered) {
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
              Icon(Icons.shield, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                '当前储备情况',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('钱龄天数', '$moneyAgeDays天', Icons.calendar_today),
          const SizedBox(height: 12),
          _buildInfoRow('可覆盖月数', '约${monthsCovered}个月', Icons.date_range),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '应急金基于您的钱龄计算，钱龄越长，应急储备能力越强',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildScoringRules() {
    final rules = [
      {'range': '6个月以上', 'score': '20分', 'level': '优秀'},
      {'range': '4-6个月', 'score': '18分', 'level': '良好'},
      {'range': '3-4个月', 'score': '16分', 'level': '基本达标'},
      {'range': '2-3个月', 'score': '12分', 'level': '需改进'},
      {'range': '1-2个月', 'score': '8分', 'level': '偏低'},
      {'range': '半个月-1个月', 'score': '5分', 'level': '不足'},
      {'range': '少于半个月', 'score': '2分', 'level': '危险'},
    ];

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
            '应急金应该能够覆盖3-6个月的日常支出，以应对失业、疾病等突发情况：',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...rules.map((rule) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    rule['range']!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    rule['score']!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getLevelColor(rule['level']!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rule['level']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getLevelColor(rule['level']!),
                      ),
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

  Color _getLevelColor(String level) {
    if (level.contains('优秀') || level.contains('良好')) return Colors.green;
    if (level.contains('基本') || level.contains('需改进')) return Colors.orange;
    return Colors.red;
  }

  Widget _buildImprovementSuggestions(int score, int moneyAgeDays) {
    final suggestions = <String>[];

    if (moneyAgeDays < 90) {
      suggestions.add('增加储蓄比例，每月至少存入收入的10-20%');
    }
    if (moneyAgeDays < 60) {
      suggestions.add('减少非必要支出，优先建立应急金储备');
    }
    if (moneyAgeDays < 30) {
      suggestions.add('设置紧急情况专用账户，避免随意支取');
    }

    suggestions.add('使用小金库功能，为应急金设置独立预算');
    suggestions.add('定期检查和调整应急金目标');

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

  Widget _buildActionGuide(int moneyAgeDays) {
    final targetMonths = moneyAgeDays < 90 ? 3 : 6;
    final currentMonths = (moneyAgeDays / 30).toStringAsFixed(1);

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
              Icon(Icons.flag, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '行动指南',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionItem(
            '短期目标（1-3个月）',
            '建立至少1个月的应急金储备\n当前：$currentMonths个月',
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            '中期目标（3-6个月）',
            '达到${targetMonths}个月的应急金储备\n目标：覆盖基本生活开支',
          ),
          const SizedBox(height: 12),
          _buildActionItem(
            '长期目标（6个月以上）',
            '保持充足的应急储备\n定期评估和调整目标',
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('什么是应急金？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('应急金是用于应对突发情况的专项储备金，例如：'),
            SizedBox(height: 8),
            Text('• 失业或收入减少'),
            Text('• 重大疾病或意外'),
            Text('• 家庭紧急开支'),
            Text('• 其他不可预见的情况'),
            SizedBox(height: 12),
            Text('建议：'),
            Text('• 储备3-6个月的生活费用'),
            Text('• 放在流动性好的账户'),
            Text('• 不要轻易动用'),
            SizedBox(height: 12),
            Text(
              '本应用通过钱龄来衡量您的应急储备能力。',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
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
