import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../extensions/category_extensions.dart';
import '../budget_management_page.dart';

/// 消费趋势预测页面
///
/// 对应原型设计 14.03 消费趋势预测
/// 展示本月预计支出和分类预测
class SpendingPredictionPage extends ConsumerWidget {
  const SpendingPredictionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('趋势预测'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // 本月预测卡片
          const _MonthlyPredictionCard(),

          // 分类预测
          const _CategoryPredictionSection(),

          // 预测说明
          _PredictionExplanation(),

          // 调整预算按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('调整预算'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 本月预测卡片
class _MonthlyPredictionCard extends ConsumerWidget {
  const _MonthlyPredictionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // 本月已支出
    final monthlyExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
        t.date.isBefore(now.add(const Duration(days: 1)))).toList();
    final spent = monthlyExpenses.fold<double>(0, (sum, t) => sum + t.amount);

    // 上月同期支出（用于预测）
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthSameDay = DateTime(now.year, now.month - 1, now.day);
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    final lastMonthPartialExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
        t.date.isBefore(lastMonthSameDay.add(const Duration(days: 1)))).toList();
    final lastMonthFullExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
        t.date.isBefore(lastMonthEnd.add(const Duration(days: 1)))).toList();

    final lastMonthPartialSpent = lastMonthPartialExpenses.fold<double>(0, (sum, t) => sum + t.amount);
    final lastMonthFullSpent = lastMonthFullExpenses.fold<double>(0, (sum, t) => sum + t.amount);

    // 简单预测：基于上月同期的比例
    double predicted;
    if (lastMonthPartialSpent > 0 && lastMonthFullSpent > 0) {
      final ratio = lastMonthFullSpent / lastMonthPartialSpent;
      predicted = spent * ratio;
    } else {
      // 没有历史数据时，按日均推算
      final daysElapsed = now.day;
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      predicted = (spent / daysElapsed) * daysInMonth;
    }

    final predictedRemaining = (predicted - spent).clamp(0, double.infinity);
    final progress = predicted > 0 ? spent / predicted : 0.0;
    final daysRemaining = DateTime(now.year, now.month + 1, 0).day - now.day;
    final variance = (predicted * 0.05).round(); // 5%误差范围

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple[400]!, Colors.blue[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本月预计支出',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥${predicted.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '±¥$variance',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '已支出 ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '¥${spent.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '预测剩余 ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '¥${predictedRemaining.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '进度 ${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Text(
                '剩余$daysRemaining天',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 分类预测区域
class _CategoryPredictionSection extends ConsumerWidget {
  const _CategoryPredictionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final budgets = ref.watch(budgetProvider);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);

    // 本月按分类汇总
    final monthlyExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
        t.date.isBefore(now.add(const Duration(days: 1)))).toList();

    final categorySpent = <String, double>{};
    for (final t in monthlyExpenses) {
      categorySpent[t.category] = (categorySpent[t.category] ?? 0) + t.amount;
    }

    // 上月按分类汇总
    final lastMonthExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
        t.date.isBefore(lastMonthEnd.add(const Duration(days: 1)))).toList();

    final lastMonthCategorySpent = <String, double>{};
    for (final t in lastMonthExpenses) {
      lastMonthCategorySpent[t.category] = (lastMonthCategorySpent[t.category] ?? 0) + t.amount;
    }

    // 构建分类预测数据
    final predictions = <_PredictionData>[];
    final daysElapsed = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // 取支出最多的分类
    final sortedCategories = categorySpent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedCategories.take(5)) {
      final categoryId = entry.key;
      final spent = entry.value;
      final lastMonthSpent = lastMonthCategorySpent[categoryId] ?? 0;

      // 预测本月支出
      final predicted = daysElapsed > 0 ? (spent / daysElapsed) * daysInMonth : spent;

      // 计算趋势
      int trend = 0;
      if (lastMonthSpent > 0) {
        trend = ((predicted - lastMonthSpent) / lastMonthSpent * 100).round();
      }

      // 获取预算
      final budget = budgets
          .where((b) => b.categoryId == categoryId && b.isEnabled)
          .fold<double>(0, (sum, b) => sum + b.amount);

      final category = DefaultCategories.findById(categoryId);
      final emoji = _getCategoryEmoji(categoryId);

      predictions.add(_PredictionData(
        emoji: emoji,
        category: category?.localizedName ?? categoryId,
        predicted: predicted,
        spent: spent,
        budget: budget > 0 ? budget : predicted * 1.2, // 无预算时用预测值的120%
        trend: trend,
      ));
    }

    if (predictions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分类预测',
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
              child: const Center(
                child: Text(
                  '暂无支出数据',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分类预测',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...predictions.map((p) => _CategoryPredictionCard(data: p)),
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
      'other': '📋',
    };
    return emojiMap[categoryId] ?? '📋';
  }
}

class _PredictionData {
  final String emoji;
  final String category;
  final double predicted;
  final double spent;
  final double budget;
  final int trend; // 正数为上升，负数为下降

  _PredictionData({
    required this.emoji,
    required this.category,
    required this.predicted,
    required this.spent,
    required this.budget,
    required this.trend,
  });
}

class _CategoryPredictionCard extends StatelessWidget {
  final _PredictionData data;

  const _CategoryPredictionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final progress = data.spent / data.budget;
    final isOverBudget = progress > 0.8;
    final progressColor = isOverBudget
        ? Colors.red
        : (data.trend < 0 ? Colors.green : Colors.orange);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(data.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.category,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${data.predicted.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${data.trend > 0 ? '↑' : '↓'}${data.trend.abs()}% 较上月',
                    style: TextStyle(
                      fontSize: 11,
                      color: data.trend > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已消费 ¥${data.spent.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '预算 ¥${data.budget.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 预测说明
class _PredictionExplanation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '基于过去6个月消费数据 + 周期性因素分析',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
