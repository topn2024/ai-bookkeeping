import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/financial_health_score_service.dart';
import '../services/category_localization_service.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';

// Provider for health score service
final structureHealthScoreProvider = FutureProvider<FinancialHealthScore>((ref) async {
  final dbService = sl<IDatabaseService>();
  final service = FinancialHealthScoreService(dbService);
  return await service.calculateScore();
});

/// 消费结构评分详情页面
class SpendingStructureScorePage extends ConsumerWidget {
  const SpendingStructureScorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthScoreAsync = ref.watch(structureHealthScoreProvider);
    final transactions = ref.watch(transactionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消费结构评分'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: healthScoreAsync.when(
        data: (healthScore) {
          final structureComponent = healthScore.components['structure']!;
          return _buildContent(context, structureComponent, transactions);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScoreComponent structureComponent, List transactions) {
    final score = structureComponent.score;
    final maxScore = structureComponent.maxScore;

    // 分析本月消费结构
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final monthTransactions = transactions.where((t) =>
      t.type == TransactionType.expense &&
      t.date.isAfter(currentMonth.subtract(const Duration(days: 1)))
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 当前得分卡片
        _buildScoreCard(score, maxScore, structureComponent.status),

        const SizedBox(height: 24),

        // 消费分布分析
        _buildSpendingDistribution(monthTransactions),

        const SizedBox(height: 24),

        // 评分规则说明
        _buildScoringRules(),

        const SizedBox(height: 24),

        // 改进建议
        _buildImprovementSuggestions(score, monthTransactions),

        const SizedBox(height: 24),

        // 优化建议
        _buildOptimizationTips(),
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
            '消费结构得分',
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

  Widget _buildSpendingDistribution(List monthTransactions) {
    final Map<String, double> categoryAmounts = {};
    double totalAmount = 0;

    for (final t in monthTransactions) {
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;
      categoryAmounts[t.category] = (categoryAmounts[t.category] ?? 0) + t.amount;
      totalAmount += t.amount;
    }

    final sortedCategories = categoryAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(5).toList();

    final categoryCount = categoryAmounts.length;
    final maxCategoryPercent = totalAmount > 0 && sortedCategories.isNotEmpty
        ? (sortedCategories.first.value / totalAmount * 100).toStringAsFixed(1)
        : '0';

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
              Icon(Icons.pie_chart, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                '本月消费分布',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('分类数量', '$categoryCount个', Icons.category),
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              Expanded(
                child: _buildSummaryItem('最高占比', '$maxCategoryPercent%', Icons.trending_up),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'TOP 5 消费分类',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (topCategories.isEmpty)
            const Text(
              '本月暂无消费记录',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...topCategories.map((entry) {
              final category = DefaultCategories.findById(entry.key);
              final percentage = (entry.value / totalAmount * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(category?.icon ?? Icons.category, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(entry.key),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '¥${entry.value.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$percentage%',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: entry.value / totalAmount,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
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
            '消费结构评分考察支出的合理性和多样性：',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildRuleItem('单一分类占比', [
            '≤ 30%: 结构健康，20分',
            '30-40%: 略微集中，扣3分',
            '40-50%: 过于集中，扣5分',
            '> 50%: 结构失衡，扣5分',
          ]),
          const SizedBox(height: 12),
          _buildRuleItem('消费分类多样性', [
            '≥ 5个分类: 多样性好，满分',
            '3-4个分类: 分类较少，扣2分',
            '< 3个分类: 分类太少，扣5分',
          ]),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String title, List<String> rules) {
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
        const SizedBox(height: 8),
        ...rules.map((rule) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Text(
                  rule,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildImprovementSuggestions(int score, List monthTransactions) {
    final suggestions = <String>[];

    final Map<String, double> categoryAmounts = {};
    double totalAmount = 0;

    for (final t in monthTransactions) {
      if (t.category == 'transfer' || t.type == TransactionType.transfer) continue;
      categoryAmounts[t.category] = (categoryAmounts[t.category] ?? 0) + t.amount;
      totalAmount += t.amount;
    }

    // 检查是否有单一分类占比过高
    if (totalAmount > 0 && categoryAmounts.isNotEmpty) {
      final maxCategory = categoryAmounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      final maxPercent = maxCategory.value / totalAmount;
      
      if (maxPercent > 0.5) {
        final category = DefaultCategories.findById(maxCategory.key);
        suggestions.add('${category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(maxCategory.key)}占比过高(${(maxPercent * 100).toStringAsFixed(0)}%)，建议优化消费结构');
      } else if (maxPercent > 0.4) {
        suggestions.add('注意控制主要支出分类的占比，避免过度集中');
      }
    }

    // 检查分类多样性
    if (categoryAmounts.length < 3) {
      suggestions.add('消费分类较少，建议细化记账分类，便于更好地管理支出');
    } else if (categoryAmounts.length < 5) {
      suggestions.add('可以进一步细化支出分类，更精准地追踪开支');
    }

    if (suggestions.isEmpty) {
      suggestions.add('您的消费结构较为合理，继续保持！');
    }

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

  Widget _buildOptimizationTips() {
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
              Icon(Icons.tips_and_updates, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                '优化建议',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem('定期审视', '每月检查主要支出分类，识别可优化的项目'),
          const SizedBox(height: 12),
          _buildTipItem('分散风险', '避免单一分类占比过高，保持支出多样性'),
          const SizedBox(height: 12),
          _buildTipItem('细化分类', '使用子分类功能，更精准地追踪每笔开支'),
          const SizedBox(height: 12),
          _buildTipItem('设置预算', '为主要分类设置预算上限，控制支出'),
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
        title: const Text('什么是消费结构？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('消费结构反映您的支出分布是否合理：'),
            SizedBox(height: 12),
            Text('健康的消费结构应该：'),
            SizedBox(height: 8),
            Text('• 避免单一分类占比过高'),
            Text('• 保持支出的多样性'),
            Text('• 分类明确，易于追踪'),
            SizedBox(height: 12),
            Text('通过优化消费结构，您可以：'),
            SizedBox(height: 8),
            Text('• 更好地控制支出'),
            Text('• 识别不合理的开支'),
            Text('• 提高财务管理效率'),
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
