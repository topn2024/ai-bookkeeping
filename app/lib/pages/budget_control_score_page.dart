import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/financial_health_score_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../providers/budget_vault_provider.dart';

// Provider for health score service
final budgetHealthScoreProvider = FutureProvider<FinancialHealthScore>((ref) async {
  final dbService = sl<IDatabaseService>();
  final service = FinancialHealthScoreService(dbService);
  return await service.calculateScore();
});

/// 预算控制评分详情页面
class BudgetControlScorePage extends ConsumerWidget {
  const BudgetControlScorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthScoreAsync = ref.watch(budgetHealthScoreProvider);
    final vaultState = ref.watch(budgetVaultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('预算控制评分'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: healthScoreAsync.when(
        data: (healthScore) {
          final budgetComponent = healthScore.components['budget']!;
          return _buildContent(context, budgetComponent, vaultState);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScoreComponent budgetComponent, BudgetVaultState vaultState) {
    final score = budgetComponent.score;
    final maxScore = budgetComponent.maxScore;

    final enabledVaults = vaultState.vaults.where((v) => v.isEnabled).toList();
    
    // 统计预算执行情况
    int overspentCount = 0;
    int warningCount = 0;
    int healthyCount = 0;

    for (final vault in enabledVaults) {
      final remaining = vault.targetAmount - vault.allocatedAmount;
      final remainingPercent = vault.targetAmount > 0
          ? ((remaining / vault.targetAmount) * 100).round()
          : 100;

      if (remaining < 0) {
        overspentCount++;
      } else if (remainingPercent <= 20 && remainingPercent > 0) {
        warningCount++;
      } else {
        healthyCount++;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前得分卡片
        _buildScoreCard(score, maxScore, budgetComponent.status),

        const SizedBox(height: 24),

        // 预算执行概况
        _buildBudgetOverview(enabledVaults.length, healthyCount, warningCount, overspentCount),

        const SizedBox(height: 24),

        // 评分规则说明
        _buildScoringRules(),

        const SizedBox(height: 24),

        // 改进建议
        _buildImprovementSuggestions(score, enabledVaults.length, overspentCount, warningCount),

        const SizedBox(height: 24),

        // 预算管理技巧
        _buildBudgetTips(),
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
            '预算控制得分',
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

  Widget _buildBudgetOverview(int totalVaults, int healthyCount, int warningCount, int overspentCount) {
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
              Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                '预算执行概况',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (totalVaults == 0)
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    '暂未设置小金库预算',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('去设置预算'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusItem('健康', healthyCount, Colors.green, Icons.check_circle),
                    ),
                    Container(width: 1, height: 60, color: Colors.grey[300]),
                    Expanded(
                      child: _buildStatusItem('警告', warningCount, Colors.orange, Icons.warning),
                    ),
                    Container(width: 1, height: 60, color: Colors.grey[300]),
                    Expanded(
                      child: _buildStatusItem('超支', overspentCount, Colors.red, Icons.error),
                    ),
                  ],
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
                      Expanded(
                        child: Text(
                          '共${totalVaults}个小金库，${healthyCount}个执行良好',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
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
            '预算控制评分基于小金库的执行情况：',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildRuleItem('基础分', '未设置预算: 5分\n已设置预算: 20分起评'),
          const SizedBox(height: 12),
          _buildRuleItem('扣分项', '• 每个超支小金库扣3分\n• 每个预算即将用完的小金库扣1分'),
          const SizedBox(height: 12),
          _buildRuleItem('最终得分', '基础分 - 扣分，范围0-20分'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '提示：使用小金库功能为不同支出类别设置预算，有助于更好地控制开支',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String title, String content) {
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
          content,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildImprovementSuggestions(int score, int totalVaults, int overspentCount, int warningCount) {
    final suggestions = <String>[];

    if (totalVaults == 0) {
      suggestions.add('开始使用小金库功能，为不同支出设置预算');
      suggestions.add('建议先为主要支出类别(如餐饮、交通)设置预算');
    } else {
      if (overspentCount > 0) {
        suggestions.add('有${overspentCount}个小金库超支，需要立即调整预算或削减支出');
        suggestions.add('分析超支原因，是预算设置不合理还是支出失控');
      }
      if (warningCount > 0) {
        suggestions.add('有${warningCount}个小金库预算即将用完，注意控制支出');
      }
      if (overspentCount == 0 && warningCount == 0) {
        suggestions.add('预算执行良好，继续保持！');
        suggestions.add('可以考虑为更多支出类别设置预算');
      }
    }

    suggestions.add('定期(如每周)检查预算执行情况');
    suggestions.add('根据实际支出调整预算额度，使预算更加合理');

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

  Widget _buildBudgetTips() {
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
              Icon(Icons.school, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '预算管理技巧',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem(
            '1. 50/30/20法则',
            '50%必需品，30%娱乐，20%储蓄和债务',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            '2. 零基预算',
            '每一块钱都有明确用途，收入-支出=0',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            '3. 留有余地',
            '预算不要设置得过于紧张，留10-15%缓冲',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            '4. 定期调整',
            '每月根据实际情况调整预算额度',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            '5. 优先级排序',
            '先保证必需支出，再分配可选支出',
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
        title: const Text('什么是预算控制？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预算控制是财务管理的重要组成部分：'),
            SizedBox(height: 12),
            Text('核心理念：'),
            SizedBox(height: 8),
            Text('• 为每个支出类别设定预算上限'),
            Text('• 实时追踪预算执行情况'),
            Text('• 防止过度消费和超支'),
            SizedBox(height: 12),
            Text('使用小金库功能：'),
            SizedBox(height: 8),
            Text('• 为不同类别创建预算'),
            Text('• 系统自动追踪预算使用'),
            Text('• 超支时及时预警'),
            SizedBox(height: 12),
            Text(
              '良好的预算控制能帮助您实现财务目标，避免月光。',
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
