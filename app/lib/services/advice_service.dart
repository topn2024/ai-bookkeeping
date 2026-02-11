import 'dart:math';
import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/budget_vault.dart';
import '../models/transaction.dart';
import '../models/resource_pool.dart';
import '../pages/actionable_advice_page.dart';
import '../services/spending_insight_calculator.dart';

/// 建议生成服务
///
/// 基于零基预算小金库 + 交易数据，生成全面的理财优化建议。
/// 覆盖场景：超支预警、节流建议、储蓄优化、消费趋势、
/// 预算调拨、应急基金、钱龄提升、记账习惯等。
class AdviceService {
  /// 生成可行建议列表
  List<ActionableAdvice> generateAdvice({
    required List<Budget> budgets,
    required List<Transaction> transactions,
    required List<BudgetVault> vaults,
    required double unallocatedAmount,
    MoneyAgeDashboard? moneyAgeDashboard,
  }) {
    final adviceList = <ActionableAdvice>[];
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;
    final daysRemaining = daysInMonth - daysElapsed;

    final enabledVaults = vaults.where((v) => v.isEnabled).toList();
    final monthExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .toList();
    final totalMonthSpent =
        monthExpenses.fold<double>(0, (sum, t) => sum + t.amount);

    // ====== 1. 小金库超支预警 ======
    _addVaultOverspentAdvice(adviceList, enabledVaults);

    // ====== 2. 小金库即将用完预警 ======
    _addVaultAlmostEmptyAdvice(adviceList, enabledVaults, daysRemaining);

    // ====== 3. 待分配收入提醒 ======
    _addUnallocatedAdvice(adviceList, unallocatedAmount);

    // ====== 4. 消费速度预警 ======
    _addSpendingPaceAdvice(
        adviceList, enabledVaults, totalMonthSpent, daysElapsed, daysInMonth);

    // ====== 5. 小金库调拨建议 ======
    _addReallocationAdvice(adviceList, enabledVaults);

    // ====== 6. 储蓄目标进度 ======
    _addSavingsAdvice(adviceList, enabledVaults);

    // ====== 7. 应急基金建议 ======
    _addEmergencyFundAdvice(
        adviceList, enabledVaults, totalMonthSpent, daysElapsed, daysInMonth);

    // ====== 8. 消费趋势建议 ======
    _addTrendAdvice(adviceList, transactions, now);

    // ====== 9. 小额高频消费提醒 ======
    _addLatteFactorAdvice(adviceList, monthExpenses, totalMonthSpent);

    // ====== 10. 钱龄提升建议 ======
    _addMoneyAgeAdvice(adviceList, moneyAgeDashboard);

    // ====== 11. 记账习惯鼓励 ======
    _addHabitAdvice(adviceList, transactions, now);

    // ====== 12. 周末消费控制 ======
    _addWeekendAdvice(adviceList, monthExpenses, totalMonthSpent);

    return adviceList;
  }

  // ---------- 1. 小金库超支 ----------
  void _addVaultOverspentAdvice(
      List<ActionableAdvice> list, List<BudgetVault> vaults) {
    final overspent = vaults.where((v) => v.isOverSpent).toList();
    for (final vault in overspent) {
      list.add(ActionableAdvice(
        id: 'vault_overspent_${vault.id}',
        type: AdviceType.budgetWarning,
        title: '「${vault.name}」已超支',
        description:
            '超支 ¥${vault.overspentAmount.toStringAsFixed(0)}，建议从其他小金库调拨资金补充，或控制后续支出。',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFE53935),
        bgColor: const Color(0xFFFFEBEE),
        primaryAction: '去调拨',
        secondaryAction: '忽略',
        metadata: {
          'vault_id': vault.id,
          'overspent': vault.overspentAmount,
        },
      ));
    }
  }

  // ---------- 2. 即将用完 ----------
  void _addVaultAlmostEmptyAdvice(
      List<ActionableAdvice> list, List<BudgetVault> vaults, int daysRemaining) {
    if (daysRemaining <= 0) return;
    final almostEmpty = vaults.where((v) =>
        v.isAlmostEmpty &&
        !v.isOverSpent &&
        v.type != VaultType.savings).toList();
    for (final vault in almostEmpty) {
      final dailyBudget = vault.available / daysRemaining;
      list.add(ActionableAdvice(
        id: 'vault_low_${vault.id}',
        type: AdviceType.budgetWarning,
        title: '「${vault.name}」余额不足',
        description:
            '仅剩 ¥${vault.available.toStringAsFixed(0)}，还有$daysRemaining天，'
            '日均可用 ¥${dailyBudget.toStringAsFixed(0)}。建议减少该类支出或调拨补充。',
        icon: Icons.account_balance_wallet,
        color: const Color(0xFFF57C00),
        bgColor: const Color(0xFFFFF3E0),
        primaryAction: '调整预算',
        secondaryAction: '已知晓',
        metadata: {
          'vault_id': vault.id,
          'remaining': vault.available,
          'daily_budget': dailyBudget,
        },
      ));
    }
  }

  // ---------- 3. 待分配收入 ----------
  void _addUnallocatedAdvice(
      List<ActionableAdvice> list, double unallocatedAmount) {
    if (unallocatedAmount > 10) {
      list.add(ActionableAdvice(
        id: 'unallocated_income',
        type: AdviceType.budgetWarning,
        title: '有 ¥${unallocatedAmount.toStringAsFixed(0)} 待分配',
        description:
            '零基预算的核心是"每一分钱都有去处"。尽快将这笔收入分配到各小金库，避免无计划消费。',
        icon: Icons.account_balance,
        color: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
        primaryAction: '去分配',
        secondaryAction: '稍后',
      ));
    }
  }

  // ---------- 4. 消费速度预警 ----------
  void _addSpendingPaceAdvice(
      List<ActionableAdvice> list,
      List<BudgetVault> vaults,
      double totalMonthSpent,
      int daysElapsed,
      int daysInMonth) {
    if (daysElapsed < 5) return; // 月初数据不足

    final totalAllocated = vaults
        .where((v) => v.type != VaultType.savings)
        .fold<double>(0, (sum, v) => sum + v.allocatedAmount);
    if (totalAllocated <= 0) return;

    final dailyAvg = totalMonthSpent / daysElapsed;
    final projectedTotal = dailyAvg * daysInMonth;
    final overRate = projectedTotal / totalAllocated;

    if (overRate > 1.15) {
      final overAmount = (projectedTotal - totalAllocated).round();
      list.add(ActionableAdvice(
        id: 'spending_pace',
        type: AdviceType.overspending,
        title: '消费速度偏快',
        description:
            '按当前节奏，本月预计支出 ¥${projectedTotal.toStringAsFixed(0)}，'
            '超出预算约 ¥$overAmount。建议接下来几天控制非必要开支。',
        icon: Icons.speed,
        color: const Color(0xFFE53935),
        bgColor: const Color(0xFFFFEBEE),
        primaryAction: '查看明细',
        secondaryAction: '忽略',
        metadata: {
          'projected': projectedTotal,
          'allocated': totalAllocated,
          'over_amount': overAmount,
        },
      ));
    } else if (overRate < 0.7 && daysElapsed > 15) {
      final savedAmount = (totalAllocated - projectedTotal).round();
      list.add(ActionableAdvice(
        id: 'spending_pace_good',
        type: AdviceType.achievement,
        title: '消费控制得很好',
        description:
            '本月预计可节省 ¥$savedAmount，可以考虑将结余转入储蓄目标，让钱更有价值。',
        icon: Icons.thumb_up,
        color: const Color(0xFF43A047),
        bgColor: const Color(0xFFE8F5E9),
        primaryAction: '转入储蓄',
        secondaryAction: '继续保持',
      ));
    }
  }

  // ---------- 5. 调拨建议 ----------
  void _addReallocationAdvice(
      List<ActionableAdvice> list, List<BudgetVault> vaults) {
    final overspent = vaults.where((v) => v.isOverSpent).toList();
    final surplus = vaults
        .where((v) =>
            !v.isOverSpent &&
            !v.isAlmostEmpty &&
            v.type == VaultType.flexible &&
            v.available > 100)
        .toList()
      ..sort((a, b) => b.available.compareTo(a.available));

    if (overspent.isNotEmpty && surplus.isNotEmpty) {
      final from = surplus.first;
      final to = overspent.first;
      final amount =
          min(from.available * 0.5, to.overspentAmount).round();
      if (amount > 0) {
        list.add(ActionableAdvice(
          id: 'realloc_${from.id}_${to.id}',
          type: AdviceType.overspending,
          title: '建议调拨资金',
          description:
              '「${from.name}」还有 ¥${from.available.toStringAsFixed(0)} 余额，'
              '可调拨 ¥$amount 到「${to.name}」补充超支。',
          icon: Icons.swap_horiz,
          color: const Color(0xFF1565C0),
          bgColor: const Color(0xFFE3F2FD),
          primaryAction: '立即调拨',
          secondaryAction: '忽略',
          metadata: {
            'from_vault': from.id,
            'to_vault': to.id,
            'amount': amount,
          },
        ));
      }
    }
  }

  // ---------- 6. 储蓄目标进度 ----------
  void _addSavingsAdvice(
      List<ActionableAdvice> list, List<BudgetVault> vaults) {
    final savingsVaults = vaults
        .where((v) => v.type == VaultType.savings && v.targetAmount > 0)
        .toList();

    for (final vault in savingsVaults) {
      final progress = vault.progress;
      if (progress >= 1.0) {
        list.add(ActionableAdvice(
          id: 'savings_done_${vault.id}',
          type: AdviceType.achievement,
          title: '🎉「${vault.name}」目标达成！',
          description:
              '已攒够 ¥${vault.allocatedAmount.toStringAsFixed(0)}，'
              '达到目标 ¥${vault.targetAmount.toStringAsFixed(0)}。可以设定新的储蓄目标了。',
          icon: Icons.emoji_events,
          color: const Color(0xFF8E24AA),
          bgColor: const Color(0xFFF3E5F5),
        ));
      } else if (progress >= 0.8) {
        final remaining =
            (vault.targetAmount - vault.allocatedAmount).round();
        list.add(ActionableAdvice(
          id: 'savings_almost_${vault.id}',
          type: AdviceType.achievement,
          title: '「${vault.name}」即将达成',
          description:
              '已完成 ${(progress * 100).toStringAsFixed(0)}%，'
              '还差 ¥$remaining 就达标了，加油！',
          icon: Icons.flag,
          color: const Color(0xFF43A047),
          bgColor: const Color(0xFFE8F5E9),
        ));
      } else if (progress < 0.3 && vault.allocatedAmount > 0) {
        list.add(ActionableAdvice(
          id: 'savings_slow_${vault.id}',
          type: AdviceType.moneyAge,
          title: '「${vault.name}」进度偏慢',
          description:
              '目标 ¥${vault.targetAmount.toStringAsFixed(0)}，'
              '当前仅 ${(progress * 100).toStringAsFixed(0)}%。'
              '建议每月固定存入一笔，积少成多。',
          icon: Icons.savings,
          color: const Color(0xFFF57C00),
          bgColor: const Color(0xFFFFF3E0),
          primaryAction: '存入',
          secondaryAction: '已知晓',
        ));
      }
    }
  }

  // ---------- 7. 应急基金 ----------
  void _addEmergencyFundAdvice(
      List<ActionableAdvice> list,
      List<BudgetVault> vaults,
      double totalMonthSpent,
      int daysElapsed,
      int daysInMonth) {
    final emergencyVault = vaults
        .where((v) =>
            v.type == VaultType.savings &&
            (v.name.contains('应急') || v.name.contains('备用')))
        .toList();

    if (emergencyVault.isEmpty) {
      // 没有应急基金
      list.add(ActionableAdvice(
        id: 'no_emergency_fund',
        type: AdviceType.moneyAge,
        title: '建议设立应急基金',
        description:
            '应急基金是财务安全的基石，建议储备3~6个月的生活费。'
            '可以创建一个"应急基金"小金库开始积累。',
        icon: Icons.shield,
        color: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
        primaryAction: '去创建',
        secondaryAction: '暂不需要',
      ));
    } else {
      // 检查应急基金是否充足
      final fund = emergencyVault.first;
      final monthlyExpense = daysElapsed > 0
          ? (totalMonthSpent / daysElapsed) * daysInMonth
          : 0.0;
      if (monthlyExpense > 0) {
        final months = fund.allocatedAmount / monthlyExpense;
        if (months < 3) {
          list.add(ActionableAdvice(
            id: 'emergency_low',
            type: AdviceType.moneyAge,
            title: '应急基金不足',
            description:
                '当前应急基金 ¥${fund.allocatedAmount.toStringAsFixed(0)}，'
                '仅够 ${months.toStringAsFixed(1)} 个月开支。'
                '建议补充到至少3个月（约 ¥${(monthlyExpense * 3).toStringAsFixed(0)}）。',
            icon: Icons.shield,
            color: const Color(0xFFF57C00),
            bgColor: const Color(0xFFFFF3E0),
            primaryAction: '去存入',
            secondaryAction: '已知晓',
          ));
        }
      }
    }
  }

  // ---------- 8. 消费趋势 ----------
  void _addTrendAdvice(
      List<ActionableAdvice> list, List<Transaction> transactions, DateTime now) {
    final history =
        SpendingInsightCalculator.getMonthlyHistory(transactions, 6);
    final nonZero = history.where((h) => h.total > 0).toList();
    if (nonZero.length < 3) return;

    // 检查连续上涨
    final recent3 = nonZero.length >= 3
        ? nonZero.sublist(nonZero.length - 3)
        : nonZero;
    bool isRising = recent3.length >= 3 &&
        recent3[2].total > recent3[1].total &&
        recent3[1].total > recent3[0].total;

    if (isRising) {
      final increaseRate =
          ((recent3[2].total - recent3[0].total) / recent3[0].total * 100)
              .round();
      list.add(ActionableAdvice(
        id: 'trend_rising',
        type: AdviceType.overspending,
        title: '消费连续上涨',
        description:
            '近3个月消费持续增长约 $increaseRate%，建议审视是否有可削减的开支。',
        icon: Icons.trending_up,
        color: const Color(0xFFE53935),
        bgColor: const Color(0xFFFFEBEE),
        primaryAction: '查看趋势',
        secondaryAction: '已知晓',
      ));
    }

    // 检查连续下降（正面反馈）
    bool isFalling = recent3.length >= 3 &&
        recent3[2].total < recent3[1].total &&
        recent3[1].total < recent3[0].total;
    if (isFalling) {
      list.add(ActionableAdvice(
        id: 'trend_falling',
        type: AdviceType.achievement,
        title: '消费持续下降',
        description: '近3个月消费逐月减少，节流效果明显，继续保持！',
        icon: Icons.trending_down,
        color: const Color(0xFF43A047),
        bgColor: const Color(0xFFE8F5E9),
      ));
    }

    // 季节性提醒
    final nextMonth = (now.month % 12) + 1;
    final factor = SpendingInsightCalculator.seasonalFactor(nextMonth);
    final eventName = SpendingInsightCalculator.seasonalEventName(nextMonth);
    if (eventName != null && factor > 1.05) {
      list.add(ActionableAdvice(
        id: 'seasonal_$nextMonth',
        type: AdviceType.budgetWarning,
        title: '下月$eventName消费高峰',
        description:
            '历史数据显示$eventName期间消费通常上涨 ${((factor - 1) * 100).toStringAsFixed(0)}%，'
            '建议提前预留额外预算。',
        icon: Icons.event,
        color: const Color(0xFFF57C00),
        bgColor: const Color(0xFFFFF3E0),
        primaryAction: '调整预算',
        secondaryAction: '已知晓',
      ));
    }
  }

  // ---------- 9. 拿铁因子 ----------
  void _addLatteFactorAdvice(List<ActionableAdvice> list,
      List<Transaction> monthExpenses, double totalMonthSpent) {
    if (totalMonthSpent <= 0) return;

    final smallExpenses = monthExpenses.where((t) => t.amount < 30).toList();
    final smallTotal =
        smallExpenses.fold<double>(0, (sum, t) => sum + t.amount);
    final smallRatio = smallTotal / totalMonthSpent;

    if (smallRatio > 0.15 && smallExpenses.length >= 10) {
      list.add(ActionableAdvice(
        id: 'latte_factor',
        type: AdviceType.overspending,
        title: '小额消费累积可观',
        description:
            '本月 ${smallExpenses.length} 笔30元以下消费，'
            '累计 ¥${smallTotal.toStringAsFixed(0)}，'
            '占总支出 ${(smallRatio * 100).toStringAsFixed(0)}%。'
            '每天少一杯奶茶，一年可省 ¥${(smallTotal / DateTime.now().day * 365).toStringAsFixed(0)}。',
        icon: Icons.coffee,
        color: const Color(0xFF795548),
        bgColor: const Color(0xFFEFEBE9),
        primaryAction: '查看详情',
        secondaryAction: '已知晓',
      ));
    }
  }

  // ---------- 10. 钱龄 ----------
  void _addMoneyAgeAdvice(
      List<ActionableAdvice> list, MoneyAgeDashboard? dashboard) {
    if (dashboard == null) return;

    final avgAge = dashboard.avgMoneyAge.round();
    if (avgAge < 30) {
      final targetAge = ((avgAge / 5).ceil() + 1) * 5;
      list.add(ActionableAdvice(
        id: 'money_age',
        type: AdviceType.moneyAge,
        title: '钱龄提升空间',
        description:
            '平均钱龄 $avgAge 天，目标 $targetAge 天。'
            '延迟非必要消费、增加储蓄可以有效提升钱龄。',
        icon: Icons.schedule,
        color: const Color(0xFF43A047),
        bgColor: const Color(0xFFE8F5E9),
        primaryAction: '查看详情',
        secondaryAction: '已知晓',
      ));
    } else if (avgAge >= 60) {
      list.add(ActionableAdvice(
        id: 'money_age_great',
        type: AdviceType.achievement,
        title: '钱龄表现优秀',
        description: '平均钱龄 $avgAge 天，说明你的资金管理很有耐心，继续保持！',
        icon: Icons.timer,
        color: const Color(0xFF8E24AA),
        bgColor: const Color(0xFFF3E5F5),
      ));
    }
  }

  // ---------- 11. 记账习惯 ----------
  void _addHabitAdvice(
      List<ActionableAdvice> list, List<Transaction> transactions, DateTime now) {
    final monthTx = transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();

    if (monthTx.length >= 20) {
      list.add(ActionableAdvice(
        id: 'habit_great',
        type: AdviceType.achievement,
        title: '本月记账 ${monthTx.length} 笔',
        description: '记账习惯很棒，数据越完整，分析和预测就越准确。',
        icon: Icons.emoji_events,
        color: const Color(0xFF8E24AA),
        bgColor: const Color(0xFFF3E5F5),
      ));
    } else if (monthTx.isEmpty && now.day > 5) {
      list.add(ActionableAdvice(
        id: 'habit_remind',
        type: AdviceType.budgetWarning,
        title: '本月还没有记账',
        description: '已经${now.day}号了，记得记录消费哦。坚持记账是理财的第一步。',
        icon: Icons.edit_note,
        color: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
        primaryAction: '去记账',
      ));
    }

    // 连续记账天数
    if (monthTx.length >= 7) {
      final days = <int>{};
      for (final t in monthTx) {
        days.add(t.date.day);
      }
      if (days.length >= 7) {
        // 检查最近7天是否连续
        int streak = 0;
        for (int d = now.day; d >= 1; d--) {
          if (days.contains(d)) {
            streak++;
          } else {
            break;
          }
        }
        if (streak >= 7) {
          list.add(ActionableAdvice(
            id: 'habit_streak',
            type: AdviceType.achievement,
            title: '连续记账 $streak 天',
            description: '坚持就是胜利，你的财务数据越来越完整了！',
            icon: Icons.local_fire_department,
            color: const Color(0xFFE65100),
            bgColor: const Color(0xFFFFF3E0),
          ));
        }
      }
    }
  }

  // ---------- 12. 周末消费 ----------
  void _addWeekendAdvice(List<ActionableAdvice> list,
      List<Transaction> monthExpenses, double totalMonthSpent) {
    if (totalMonthSpent <= 0) return;

    final weekendSpent = monthExpenses
        .where((t) => t.date.weekday >= 6)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final weekendRatio = weekendSpent / totalMonthSpent;

    if (weekendRatio > 0.45) {
      list.add(ActionableAdvice(
        id: 'weekend_spending',
        type: AdviceType.overspending,
        title: '周末消费占比偏高',
        description:
            '周末消费占总支出 ${(weekendRatio * 100).toStringAsFixed(0)}%'
            '（¥${weekendSpent.toStringAsFixed(0)}），'
            '建议周末出行前设定消费上限。',
        icon: Icons.weekend,
        color: const Color(0xFFF57C00),
        bgColor: const Color(0xFFFFF3E0),
        primaryAction: '查看详情',
        secondaryAction: '已知晓',
      ));
    }
  }
}
