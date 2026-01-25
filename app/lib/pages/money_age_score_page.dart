import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/financial_health_score_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../providers/budget_provider.dart';

// Provider for health score service
final moneyAgeHealthScoreProvider = FutureProvider<FinancialHealthScore>((ref) async {
  final dbService = sl<IDatabaseService>();
  final service = FinancialHealthScoreService(dbService);
  return await service.calculateScore();
});

/// 钱龄评分详情页面
class MoneyAgeScorePage extends ConsumerWidget {
  const MoneyAgeScorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthScoreAsync = ref.watch(moneyAgeHealthScoreProvider);
    final moneyAge = ref.watch(moneyAgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('钱龄评分'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: healthScoreAsync.when(
        data: (healthScore) {
          final moneyAgeComponent = healthScore.components['moneyAge']!;
          return _buildContent(context, moneyAgeComponent, moneyAge.days);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScoreComponent moneyAgeComponent, int moneyAgeDays) {
    final score = moneyAgeComponent.score;
    final maxScore = moneyAgeComponent.maxScore;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前得分卡片
        _buildScoreCard(score, maxScore, moneyAgeComponent.status),

        const SizedBox(height: 24),

        // 钱龄状态
        _buildMoneyAgeStatus(moneyAgeDays),

        const SizedBox(height: 24),

        // 评分规则说明
        _buildScoringRules(),

        const SizedBox(height: 24),

        // 改进建议
        _buildImprovementSuggestions(score, moneyAgeDays),

        const SizedBox(height: 24),

        // 提升钱龄的方法
        _buildImprovementMethods(),
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
            '钱龄得分',
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

  Widget _buildMoneyAgeStatus(int moneyAgeDays) {
    final isNegative = moneyAgeDays < 0;
    final displayDays = moneyAgeDays.abs();
    
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
              Icon(Icons.schedule, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                '当前钱龄状态',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  isNegative ? '透支状态' : '$displayDays天',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: isNegative ? Colors.red : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isNegative 
                    ? '已超支${displayDays}天的收入额度'
                    : '当前余额可支撑${displayDays}天的支出',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
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
                    '钱龄 = 当前余额 ÷ 日均支出，反映资金的时间价值',
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

  Widget _buildScoringRules() {
    final rules = [
      {'range': '60天及以上', 'score': '20分', 'level': '理想', 'desc': '财务状况非常稳健'},
      {'range': '30-59天', 'score': '16分', 'level': '良好', 'desc': '资金周转健康'},
      {'range': '14-29天', 'score': '12分', 'level': '一般', 'desc': '基本满足需求'},
      {'range': '7-13天', 'score': '8分', 'level': '警告', 'desc': '资金偏紧张'},
      {'range': '1-6天', 'score': '按天数评分', 'level': '危险', 'desc': '急需改善'},
      {'range': '负值', 'score': '0分', 'level': '透支', 'desc': '入不敷出状态'},
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
            '钱龄越长，说明资金管理越好，财务越健康：',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...rules.map((rule) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        rule['range']!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
                const SizedBox(height: 4),
                Text(
                  rule['desc']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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
    if (level.contains('理想') || level.contains('良好')) return Colors.green;
    if (level.contains('一般') || level.contains('警告')) return Colors.orange;
    return Colors.red;
  }

  Widget _buildImprovementSuggestions(int score, int moneyAgeDays) {
    final suggestions = <String>[];

    if (moneyAgeDays < 0) {
      suggestions.add('立即削减非必要支出，优先解决透支问题');
      suggestions.add('审视收入来源，考虑增加收入渠道');
    } else if (moneyAgeDays < 7) {
      suggestions.add('紧急建立财务缓冲，至少达到7天钱龄');
      suggestions.add('延迟非必要消费，让资金停留更长时间');
    } else if (moneyAgeDays < 30) {
      suggestions.add('继续积累，目标达到30天钱龄（1个月）');
      suggestions.add('减少冲动消费，提高储蓄比例');
    } else if (moneyAgeDays < 60) {
      suggestions.add('财务状况良好，继续保持并优化');
      suggestions.add('考虑建立应急金储备');
    }

    suggestions.add('使用小金库功能，为不同目标分配资金');
    suggestions.add('定期查看钱龄趋势，及时调整消费');

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

  Widget _buildImprovementMethods() {
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
              Icon(Icons.trending_up, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '提升钱龄的5个方法',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMethodItem(
            '1. 延迟消费',
            '非必要支出延后，让资金在账户中停留更长时间',
          ),
          const SizedBox(height: 12),
          _buildMethodItem(
            '2. 提前储蓄',
            '收入到账后先存储蓄，而不是等月底剩余才存',
          ),
          const SizedBox(height: 12),
          _buildMethodItem(
            '3. 使用旧钱',
            '优先使用账户中时间较长的资金，新收入留作储蓄',
          ),
          const SizedBox(height: 12),
          _buildMethodItem(
            '4. 控制支出',
            '严格控制日常开支，避免超出预算',
          ),
          const SizedBox(height: 12),
          _buildMethodItem(
            '5. 增加收入',
            '开拓额外收入来源，提高总体资金量',
          ),
        ],
      ),
    );
  }

  Widget _buildMethodItem(String title, String description) {
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
        title: const Text('什么是钱龄？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('钱龄是YNAB(You Need A Budget)理财方法的核心概念：'),
            SizedBox(height: 12),
            Text('钱龄 = 当前余额 ÷ 日均支出'),
            SizedBox(height: 12),
            Text('它衡量的是：'),
            SizedBox(height: 8),
            Text('• 你的钱在账户中停留了多久'),
            Text('• 当前余额能支撑多少天的生活'),
            Text('• 财务缓冲能力的强弱'),
            SizedBox(height: 12),
            Text('钱龄越长说明：'),
            SizedBox(height: 8),
            Text('• 资金管理越好'),
            Text('• 财务压力越小'),
            Text('• 应急能力越强'),
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
