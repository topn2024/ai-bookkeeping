import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_provider.dart';
import '../providers/recurring_provider.dart';
import '../services/smart_suggestion_engine.dart';

/// 智能预算建议页面
class VaultAISuggestionPage extends ConsumerWidget {
  const VaultAISuggestionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final recurring = ref.watch(recurringProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);

    final engine = SmartSuggestionEngine(
      allTransactions: transactions,
      recurringTransactions: recurring,
      monthlyIncome: monthlyIncome,
    );
    final result = engine.generate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('智能预算建议'),
        centerTitle: true,
      ),
      body: result.suggestions.isEmpty
          ? _buildEmptyState(theme, result)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatsCard(theme, result.stats),
                const SizedBox(height: 16),
                ...result.suggestions.map(
                    (s) => _buildSuggestionCard(theme, s)),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, SuggestionResult result) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无建议',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(
              result.transactionCount < 10
                  ? '记录更多交易后，将为你生成个性化建议'
                  : '当前财务状况良好，暂无需要关注的问题',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, SuggestionStats stats) {
    final confidenceText = stats.dataConfidence >= 0.7
        ? '数据充分' : stats.dataConfidence >= 0.4
        ? '数据积累中' : '数据较少';
    final confidenceColor = stats.dataConfidence >= 0.7
        ? Colors.green : stats.dataConfidence >= 0.4
        ? Colors.orange : Colors.grey;

    final trendText = stats.monthlyExpenseTrend > 0.05
        ? '支出上升${(stats.monthlyExpenseTrend * 100).round()}%'
        : stats.monthlyExpenseTrend < -0.05
        ? '支出下降${(-stats.monthlyExpenseTrend * 100).round()}%'
        : '支出平稳';
    final trendIcon = stats.monthlyExpenseTrend > 0.05
        ? Icons.trending_up : stats.monthlyExpenseTrend < -0.05
        ? Icons.trending_down : Icons.trending_flat;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Icon(Icons.analytics, color: confidenceColor, size: 28),
                const SizedBox(height: 4),
                Text(confidenceText, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: confidenceColor)),
                Text('${stats.totalTransactions}笔交易 · ${stats.monthsAnalyzed}个月',
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Container(width: 1, height: 40,
              color: Colors.black.withValues(alpha: 0.1)),
          Expanded(
            child: Column(
              children: [
                Icon(trendIcon, color: const Color(0xFF3F51B5), size: 28),
                const SizedBox(height: 4),
                Text(trendText, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF3F51B5))),
                const Text('环比上月',
                    style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(ThemeData theme, BudgetSuggestion suggestion) {
    final priorityColor = switch (suggestion.priority) {
      SuggestionPriority.high => Colors.red,
      SuggestionPriority.medium => Colors.orange,
      SuggestionPriority.low => Colors.blue,
    };
    final priorityLabel = switch (suggestion.priority) {
      SuggestionPriority.high => '需要关注',
      SuggestionPriority.medium => '建议关注',
      SuggestionPriority.low => '参考信息',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: priorityColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(suggestion.icon, color: suggestion.color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(suggestion.title, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(priorityLabel, style: TextStyle(
                    fontSize: 10, color: priorityColor,
                    fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(suggestion.description, style: TextStyle(
              fontSize: 13, color: theme.colorScheme.onSurfaceVariant,
              height: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: suggestion.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16,
                    color: suggestion.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(suggestion.actionText, style: TextStyle(
                      fontSize: 12, color: suggestion.color,
                      fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
