import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/transaction_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/money_age_provider.dart';
import '../extensions/category_extensions.dart';
import '../theme/app_theme.dart';

/// 钱龄预算联动页面
/// 原型设计 2.08：钱龄 × 预算
/// - 钱龄影响预测卡片
/// - 各预算项对钱龄的影响分析
/// - AI建议提升钱龄
/// - 调整预算操作按钮
class MoneyAgeBudgetPage extends ConsumerWidget {
  const MoneyAgeBudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPredictionCard(context, theme, ref),
                    _buildBudgetImpactList(context, theme, ref),
                    _buildAISuggestion(context, theme, ref),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildActionButton(context, theme),
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
              '钱龄 × 预算',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 钱龄影响预测卡片
  Widget _buildPredictionCard(BuildContext context, ThemeData theme, WidgetRef ref) {
    final dashboardAsync = ref.watch(moneyAgeDashboardProvider);

    return dashboardAsync.when(
      data: (dashboard) {
        final currentAge = dashboard?.averageMoneyAge ?? 0;
        // 简单预测：假设按当前预算执行，每月可增加5-10天
        final predictedGain = (currentAge * 0.15).round().clamp(3, 15);
        final predictedAge = currentAge + predictedGain;

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Column(
                children: [
                  Text(
                    '按当前预算执行',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '月末预计钱龄',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        '$currentAge天',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '当前',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.arrow_forward,
                      color: AppColors.success,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '$predictedAge天',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                      Text(
                        '+$predictedGain天 ↑',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('暂无钱龄数据')),
      ),
    );
  }

  /// 各预算项对钱龄的影响分析
  Widget _buildBudgetImpactList(BuildContext context, ThemeData theme, WidgetRef ref) {
    final budgets = ref.watch(budgetProvider);
    final transactions = ref.watch(transactionProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 本月按分类汇总支出
    final monthlyExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
        t.date.isBefore(now.add(const Duration(days: 1)))).toList();

    final categorySpent = <String, double>{};
    for (final t in monthlyExpenses) {
      categorySpent[t.category] = (categorySpent[t.category] ?? 0) + t.amount;
    }

    // 获取有效预算并计算影响
    final activeBudgets = budgets.where((b) => b.isEnabled && b.amount > 0).toList();

    if (activeBudgets.isEmpty && categorySpent.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '各预算项对钱龄的影响',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('暂无预算数据')),
            ),
          ],
        ),
      );
    }

    // 构建预算影响项目
    final impactItems = <Widget>[];

    for (final budget in activeBudgets.take(5)) {
      final categoryId = budget.categoryId;
      if (categoryId == null) continue;

      final spent = categorySpent[categoryId] ?? 0;
      final category = DefaultCategories.findById(categoryId);
      final progress = budget.amount > 0 ? spent / budget.amount : 0.0;

      // 计算对钱龄的影响（简化算法：超支越多，负面影响越大）
      int impact;
      bool isPositive;
      if (progress <= 0.5) {
        impact = ((1 - progress) * 10).round();
        isPositive = true;
      } else if (progress <= 0.8) {
        impact = ((progress - 0.5) * -6).round();
        isPositive = false;
      } else {
        impact = ((progress - 0.8) * -15).round() - 3;
        isPositive = false;
      }

      Color progressColor;
      if (progress <= 0.5) {
        progressColor = AppColors.success;
      } else if (progress <= 0.8) {
        progressColor = AppColors.warning;
      } else {
        progressColor = AppColors.error;
      }

      final emoji = _getCategoryEmoji(categoryId);

      impactItems.add(_buildBudgetImpactItem(
        context,
        theme,
        emoji: emoji,
        name: '${category?.localizedName ?? categoryId}预算',
        current: spent,
        budget: budget.amount,
        impact: impact,
        isPositive: isPositive,
        progressPercent: progress.clamp(0.0, 1.0),
        progressColor: progressColor,
      ));
      impactItems.add(const SizedBox(height: 8));
    }

    // 移除最后一个SizedBox
    if (impactItems.isNotEmpty) {
      impactItems.removeLast();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '各预算项对钱龄的影响',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...impactItems,
        ],
      ),
    );
  }

  String _getCategoryEmoji(String categoryId) {
    final emojiMap = {
      'food': '🍜',
      'transport': '🚗',
      'shopping': '🛒',
      'entertainment': '🎮',
      'medical': '💊',
      'education': '📚',
      'housing': '🏠',
      'utilities': '💡',
      'communication': '📱',
      'saving': '💰',
      'other': '📋',
    };
    return emojiMap[categoryId] ?? '📋';
  }

  Widget _buildBudgetImpactItem(
    BuildContext context,
    ThemeData theme, {
    required String emoji,
    required String name,
    required double current,
    required double budget,
    required int impact,
    required bool isPositive,
    required double progressPercent,
    required Color progressColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '¥${current.toStringAsFixed(0)} / ¥${budget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}$impact天',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                  ),
                  Text(
                    isPositive ? '贡献' : '影响',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercent,
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AI建议
  Widget _buildAISuggestion(BuildContext context, ThemeData theme, WidgetRef ref) {
    final budgets = ref.watch(budgetProvider);
    final transactions = ref.watch(transactionProvider);
    final dashboardAsync = ref.watch(moneyAgeDashboardProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 本月按分类汇总支出
    final monthlyExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
        t.date.isBefore(now.add(const Duration(days: 1)))).toList();

    final categorySpent = <String, double>{};
    for (final t in monthlyExpenses) {
      categorySpent[t.category] = (categorySpent[t.category] ?? 0) + t.amount;
    }

    // 找出超支最多的预算
    String suggestion = '合理规划预算，可以有效提升您的钱龄水平';

    final activeBudgets = budgets.where((b) => b.isEnabled && b.amount > 0 && b.categoryId != null).toList();

    if (activeBudgets.isNotEmpty) {
      // 找出进度最高（即最接近超支）的预算
      double maxProgress = 0;
      String? targetCategoryId;
      double targetBudget = 0;

      for (final budget in activeBudgets) {
        final spent = categorySpent[budget.categoryId!] ?? 0;
        final progress = spent / budget.amount;
        if (progress > maxProgress && progress > 0.6) {
          maxProgress = progress;
          targetCategoryId = budget.categoryId;
          targetBudget = budget.amount;
        }
      }

      if (targetCategoryId != null) {
        final category = DefaultCategories.findById(targetCategoryId);
        final categoryName = category?.localizedName ?? targetCategoryId;
        final reducedBudget = (targetBudget * 0.8).round();
        final savings = (targetBudget - reducedBudget).round();

        // 获取当前钱龄
        final currentAge = dashboardAsync.when(
          data: (d) => d?.averageMoneyAge ?? 30,
          loading: () => 30,
          error: (_, __) => 30,
        );
        final predictedAge = currentAge + (savings / 100).round();

        suggestion = '将$categoryName预算从¥${targetBudget.toStringAsFixed(0)}降至¥$reducedBudget，每月可额外储蓄¥$savings，预计可将钱龄提升至$predictedAge天（+${predictedAge - currentAge}天）';
      }
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '提升钱龄建议',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
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

  /// 操作按钮
  Widget _buildActionButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              // 调整预算以提升钱龄
            },
            icon: const Icon(Icons.tune),
            label: const Text('调整预算以提升钱龄'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
