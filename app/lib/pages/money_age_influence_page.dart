import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';

/// 钱龄影响因素分析页面
/// 原型设计 2.04：影响因素分析
/// - 本月钱龄变化进度
/// - 正面影响因素列表
/// - 负面影响因素列表
/// - AI洞察建议
class MoneyAgeInfluencePage extends ConsumerWidget {
  const MoneyAgeInfluencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 获取本月收入（正面因素）
    final monthlyIncomes = transactions
        .where((t) => t.type == TransactionType.income && t.date.isAfter(monthStart))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // 获取本月大额支出（负面因素）
    final monthlyExpenses = transactions
        .where((t) => t.type == TransactionType.expense && t.date.isAfter(monthStart))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // 计算本月收入总额和支出总额
    final totalIncome = monthlyIncomes.fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = monthlyExpenses.fold(0.0, (sum, t) => sum + t.amount);

    // 简化的钱龄变化估算（收入增加钱龄，支出减少钱龄）
    final netChange = ((totalIncome - totalExpense) / 1000).round(); // 每1000元约1天

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMonthlyChangeCard(context, theme, netChange),
                    _buildPositiveFactors(context, theme, monthlyIncomes.take(3).toList()),
                    _buildNegativeFactors(context, theme, monthlyExpenses.take(3).toList()),
                    _buildAIInsight(context, theme, totalIncome, totalExpense),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '钱龄影响分析',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 本月钱龄变化
  Widget _buildMonthlyChangeCard(BuildContext context, ThemeData theme, int netChange) {
    final isPositive = netChange >= 0;
    final changeText = isPositive ? '+$netChange天' : '$netChange天';
    final baseAge = 30; // 基准钱龄
    final currentAge = baseAge + netChange;
    final progress = (currentAge / 60).clamp(0.0, 1.0); // 60天为满分

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '本月钱龄变化',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                changeText,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 进度条
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.success, theme.colorScheme.primary],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '月初 $baseAge天',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '当前 $currentAge天',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 正面影响因素
  Widget _buildPositiveFactors(BuildContext context, ThemeData theme, List<Transaction> incomes) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                '正面影响因素',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (incomes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '本月暂无收入记录',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...incomes.map((t) {
              final effect = '+${(t.amount / 1000).round()}天';
              final dateStr = '${t.date.month}月${t.date.day}日';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildFactorItem(
                  theme,
                  emoji: '💰',
                  title: t.category,
                  subtitle: '$dateStr ¥${t.amount.toStringAsFixed(0)}',
                  effect: effect,
                  isPositive: true,
                ),
              );
            }),
        ],
      ),
    );
  }

  /// 负面影响因素
  Widget _buildNegativeFactors(BuildContext context, ThemeData theme, List<Transaction> expenses) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_down, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                '负面影响因素',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '本月暂无大额支出',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...expenses.map((t) {
              final effect = '-${(t.amount / 1000).round()}天';
              final dateStr = '${t.date.month}月${t.date.day}日';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildFactorItem(
                  theme,
                  emoji: _getCategoryEmoji(t.category),
                  title: t.category,
                  subtitle: '$dateStr ¥${t.amount.toStringAsFixed(0)}',
                  effect: effect,
                  isPositive: false,
                ),
              );
            }),
        ],
      ),
    );
  }

  String _getCategoryEmoji(String? category) {
    switch (category) {
      case '餐饮':
      case '吃饭':
        return '🍜';
      case '购物':
        return '🛒';
      case '交通':
        return '🚗';
      case '娱乐':
        return '🎮';
      case '数码':
        return '📱';
      default:
        return '💸';
    }
  }

  Widget _buildFactorItem(
    ThemeData theme, {
    required String emoji,
    required String title,
    required String subtitle,
    required String effect,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPositive
                  ? AppColors.success.withValues(alpha: 0.15)
                  : const Color(0xFFFFCDD2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              effect,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPositive ? AppColors.success : const Color(0xFFEF5350),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AI洞察
  Widget _buildAIInsight(BuildContext context, ThemeData theme, double totalIncome, double totalExpense) {
    String insightText;
    if (totalIncome == 0 && totalExpense == 0) {
      insightText = '开始记录收支后，AI将为您分析钱龄影响因素并提供优化建议。';
    } else if (totalExpense > totalIncome) {
      final overspend = totalExpense - totalIncome;
      insightText = '本月支出超过收入¥${overspend.toStringAsFixed(0)}，建议控制非必要支出以提升钱龄。';
    } else if (totalExpense > totalIncome * 0.8) {
      insightText = '本月支出占收入${(totalExpense / totalIncome * 100).toStringAsFixed(0)}%，建议适当控制支出以保持健康的钱龄。';
    } else {
      insightText = '本月收支比例健康，继续保持良好的消费习惯，钱龄将稳步提升。';
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEBF3FF), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 洞察',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insightText,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
