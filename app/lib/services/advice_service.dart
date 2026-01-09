import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../models/resource_pool.dart';
import '../pages/actionable_advice_page.dart';

/// 建议生成服务
class AdviceService {
  /// 生成可行建议列表
  List<ActionableAdvice> generateAdvice({
    required List<Budget> budgets,
    required List<Transaction> transactions,
    MoneyAgeDashboard? moneyAgeDashboard,
  }) {
    final adviceList = <ActionableAdvice>[];
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day;

    // 1. 预算预警建议
    for (final budget in budgets) {
      if (budget.period == BudgetPeriod.monthly && daysRemaining > 0) {
        final spent = _calculateSpent(transactions, budget.category, now.month);
        final remaining = budget.amount - spent;
        final dailyAverage = remaining / daysRemaining;

        if (remaining > 0 && remaining < budget.amount * 0.3) {
          adviceList.add(ActionableAdvice(
            id: 'budget_${budget.id}',
            type: AdviceType.budgetWarning,
            title: '${budget.category}预算预警',
            description: '${budget.category}还剩 ¥${remaining.toStringAsFixed(0)}/$daysRemaining天，平均每天${dailyAverage.toStringAsFixed(0)}元。建议控制支出以避免超支。',
            icon: _getCategoryIcon(budget.category),
            color: const Color(0xFFF57C00),
            bgColor: const Color(0xFFFFF3E0),
            primaryAction: '设置提醒',
            secondaryAction: '忽略',
            metadata: {
              'remaining': remaining,
              'days': daysRemaining,
              'daily_average': dailyAverage,
              'category': budget.category,
            },
          ));
        }

        // 超支建议
        if (remaining < 0) {
          final overspent = -remaining;
          final otherBudget = _findAvailableBudget(budgets, transactions, budget.category, now.month);

          if (otherBudget != null) {
            adviceList.add(ActionableAdvice(
              id: 'overspend_${budget.id}',
              type: AdviceType.overspending,
              title: '超支处理方案',
              description: '${budget.category}超支 ¥${overspent.toStringAsFixed(0)}。可以从${otherBudget.category}预算（还剩¥${otherBudget.remaining.toStringAsFixed(0)}）调拨，要帮你设置吗？',
              icon: Icons.trending_up,
              color: const Color(0xFFE53935),
              bgColor: const Color(0xFFFFEBEE),
              primaryAction: '立即调拨',
              secondaryAction: '下月补上',
              metadata: {
                'overspent': overspent,
                'source': budget.category,
                'available_from': otherBudget.category,
                'available_amount': otherBudget.remaining,
              },
            ));
          }
        }
      }
    }

    // 2. 钱龄提升建议
    if (moneyAgeDashboard != null) {
      final avgAge = moneyAgeDashboard.avgMoneyAge.round();
      if (avgAge < 30) {
        final targetAge = ((avgAge / 5).ceil() + 1) * 5;
        adviceList.add(ActionableAdvice(
          id: 'money_age_1',
          type: AdviceType.moneyAge,
          title: '钱龄提升机会',
          description: '钱龄目前 $avgAge天，离目标${targetAge}天还差${targetAge - avgAge}天。减少非必要支出可以提升钱龄。',
          icon: Icons.schedule,
          color: const Color(0xFF43A047),
          bgColor: const Color(0xFFE8F5E9),
          primaryAction: '查看详情',
          secondaryAction: '已知晓',
          metadata: {
            'current_age': avgAge,
            'target_age': targetAge,
          },
        ));
      }
    }

    // 3. 成就建议
    final monthTransactions = transactions.where((t) =>
      t.date.year == now.year && t.date.month == now.month
    ).toList();

    if (monthTransactions.length >= 7) {
      final budgetExecution = _calculateBudgetExecution(budgets, transactions, now.month);
      adviceList.add(ActionableAdvice(
        id: 'achievement_1',
        type: AdviceType.achievement,
        title: '本月记账${monthTransactions.length}笔！',
        description: '本月预算执行率${budgetExecution.toStringAsFixed(0)}%，继续保持这个好习惯！',
        icon: Icons.emoji_events,
        color: const Color(0xFF8E24AA),
        bgColor: const Color(0xFFF3E5F5),
        metadata: {
          'transaction_count': monthTransactions.length,
          'budget_execution': budgetExecution,
        },
      ));
    }

    return adviceList;
  }

  double _calculateSpent(List<Transaction> transactions, String category, int month) {
    return transactions
        .where((t) =>
          t.category == category &&
          t.type == TransactionType.expense &&
          t.date.month == month
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  _BudgetWithRemaining? _findAvailableBudget(
    List<Budget> budgets,
    List<Transaction> transactions,
    String excludeCategory,
    int month,
  ) {
    for (final budget in budgets) {
      if (budget.category != excludeCategory && budget.period == BudgetPeriod.monthly) {
        final spent = _calculateSpent(transactions, budget.category, month);
        final remaining = budget.amount - spent;
        if (remaining > 100) {
          return _BudgetWithRemaining(budget, remaining);
        }
      }
    }
    return null;
  }

  double _calculateBudgetExecution(List<Budget> budgets, List<Transaction> transactions, int month) {
    if (budgets.isEmpty) return 0;

    double totalBudget = 0;
    double totalSpent = 0;

    for (final budget in budgets) {
      if (budget.period == BudgetPeriod.monthly) {
        totalBudget += budget.amount;
        totalSpent += _calculateSpent(transactions, budget.category, month);
      }
    }

    return totalBudget > 0 ? (totalSpent / totalBudget * 100).clamp(0, 100) : 0;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case '餐饮':
        return Icons.restaurant;
      case 'shopping':
      case '购物':
        return Icons.shopping_bag;
      case 'transport':
      case '交通':
        return Icons.directions_car;
      case 'entertainment':
      case '娱乐':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }
}

class _BudgetWithRemaining {
  final Budget budget;
  final double remaining;

  _BudgetWithRemaining(this.budget, this.remaining);

  String get category => budget.category;
}
