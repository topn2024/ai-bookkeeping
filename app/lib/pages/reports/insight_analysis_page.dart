import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../latte_factor_page.dart';
import '../budget_management_page.dart';
import '../trends_page.dart';
import '../subscription_waste_page.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/subscription_detection_provider.dart';
import '../../models/transaction.dart';
import '../../services/category_localization_service.dart';
import '../../services/subscription_tracking_service.dart';
import '../../services/spending_insight_calculator.dart';

/// 洞察分析页面
/// 原型设计 7.02：洞察分析
/// - 拿铁因子分析
/// - 闲置订阅提醒
/// - 消费习惯分析
/// - 预算执行洞察
class InsightAnalysisPage extends ConsumerWidget {
  const InsightAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allTransactions = ref.watch(transactionProvider);
    final categoryExpenses = ref.watch(monthlyExpenseByCategoryProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    final detectedSubscriptions = ref.watch(detectedSubscriptionsProvider);
    final allBudgetUsages = ref.watch(allBudgetUsagesProvider);

    final now = DateTime.now();
    final daysInMonth = now.day;

    // 拿铁因子：本月小额消费（<50元）
    final monthStart = DateTime(now.year, now.month, 1);
    final thisMonthTx = allTransactions.where((t) =>
        t.type == TransactionType.expense &&
        !t.date.isBefore(monthStart) &&
        !t.date.isAfter(now)).toList();
    final latteTx = thisMonthTx.where((t) => t.amount < 50).toList();
    final latteExpense = latteTx.fold<double>(0, (sum, t) => sum + t.amount);
    final dailyLatte = daysInMonth > 0 ? latteExpense / daysInMonth : 0.0;

    // 上月小额消费（用于环比）
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    final lastMonthLatteTx = allTransactions.where((t) =>
        t.type == TransactionType.expense &&
        t.amount < 50 &&
        !t.date.isBefore(lastMonthStart) &&
        !t.date.isAfter(lastMonthEnd)).toList();
    final lastMonthLatteTotal = lastMonthLatteTx.fold<double>(0, (sum, t) => sum + t.amount);

    // 年化预估
    final annualizedLatte = daysInMonth > 0 ? latteExpense / daysInMonth * 365 : 0.0;

    // 拿铁环比
    final latteMoM = lastMonthLatteTotal > 0
        ? (latteExpense - lastMonthLatteTotal) / lastMonthLatteTotal * 100
        : null;

    // 消费习惯：周末占比
    final weekendRatio = SpendingInsightCalculator.weekendRatio(thisMonthTx);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildLatteFactorCard(
                      theme,
                      latteExpense,
                      dailyLatte,
                      latteMoM,
                      annualizedLatte,
                      monthlyExpense,
                    ),
                    const SizedBox(height: 12),
                    _buildSubscriptionAlert(theme, detectedSubscriptions),
                    const SizedBox(height: 12),
                    _buildSpendingPatternCard(
                      theme,
                      monthlyExpense,
                      categoryExpenses,
                      weekendRatio,
                    ),
                    const SizedBox(height: 12),
                    _buildBudgetInsightCard(theme, allBudgetUsages),
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
              'AI洞察',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 拿铁因子卡片（含环比 + 年化）
  Widget _buildLatteFactorCard(
    ThemeData theme,
    double latteExpense,
    double dailyLatte,
    double? latteMoM,
    double annualizedLatte,
    double monthlyExpense,
  ) {
    final hasLatteData = latteExpense > 0;

    // Badge 基于占总支出比
    final latteRatio = monthlyExpense > 0 ? latteExpense / monthlyExpense : 0.0;
    final String badgeText;
    final Color badgeColor;
    if (latteRatio > 0.15) {
      badgeText = '可优化';
      badgeColor = Colors.orange;
    } else if (latteRatio > 0.08) {
      badgeText = '适中';
      badgeColor = Colors.blue;
    } else {
      badgeText = '良好';
      badgeColor = Colors.green;
    }

    String content;
    if (hasLatteData) {
      final momStr = latteMoM != null
          ? '（较上月 ${latteMoM > 0 ? "+" : ""}${latteMoM.toStringAsFixed(0)}%）'
          : '';
      content = '本月小额消费 ¥${latteExpense.toStringAsFixed(0)}$momStr\n'
          '日均 ¥${dailyLatte.toStringAsFixed(1)}，按此频率年累计约 ¥${annualizedLatte.toStringAsFixed(0)}';
    } else {
      content = '暂无小额高频消费数据';
    }

    return _InsightCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.coffee,
      iconColor: const Color(0xFF8D6E63),
      title: '拿铁因子',
      badge: hasLatteData ? _InsightBadge(text: badgeText, color: badgeColor) : null,
      content: content,
      actionText: '查看详情 →',
      actionColor: theme.colorScheme.primary,
      onAction: (context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LatteFactorPage()),
      ),
    );
  }

  /// 闲置订阅提醒
  Widget _buildSubscriptionAlert(ThemeData theme, AsyncValue<List<SubscriptionPattern>> subscriptionsAsync) {
    return subscriptionsAsync.when(
      loading: () => _InsightCard(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.subscriptions,
        iconColor: Colors.red,
        title: '订阅支出',
        badge: null,
        content: '正在分析订阅数据...',
        actionText: null,
        actionColor: null,
        onAction: null,
      ),
      error: (_, _) => _InsightCard(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.subscriptions,
        iconColor: Colors.red,
        title: '订阅支出',
        badge: null,
        content: '订阅分析暂时不可用',
        actionText: null,
        actionColor: null,
        onAction: null,
      ),
      data: (subscriptions) {
        if (subscriptions.isEmpty) {
          return _InsightCard(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.subscriptions,
            iconColor: Colors.red,
            title: '订阅支出',
            badge: _InsightBadge(text: '良好', color: Colors.green),
            content: '未检测到周期性订阅支出',
            actionText: null,
            actionColor: null,
            onAction: null,
          );
        }

        final totalMonthly = subscriptions.fold<double>(0.0, (sum, s) => sum + s.monthlyAmount);
        final count = subscriptions.length;
        final wasted = subscriptions.where((s) => s.usageStatus == UsageStatus.unused || s.usageStatus == UsageStatus.rarelyUsed).toList();

        final badgeText = wasted.isNotEmpty ? '有浪费' : (count >= 5 ? '偏多' : '正常');
        final badgeColor = wasted.isNotEmpty ? Colors.red : (count >= 5 ? Colors.orange : Colors.green);

        final content = wasted.isNotEmpty
            ? '检测到 $count 项订阅（月均 ¥${totalMonthly.toStringAsFixed(0)}），其中 ${wasted.length} 项可能闲置'
            : '检测到 $count 项周期性订阅，月均支出 ¥${totalMonthly.toStringAsFixed(0)}';

        return _InsightCard(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.subscriptions,
          iconColor: Colors.red,
          title: '订阅支出',
          badge: _InsightBadge(text: badgeText, color: badgeColor),
          content: content,
          actionText: '查看详情 →',
          actionColor: Colors.red,
          onAction: (context) => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionWastePage()),
          ),
        );
      },
    );
  }

  /// 消费习惯卡片（TOP3 + HHI + 周末占比）
  Widget _buildSpendingPatternCard(
    ThemeData theme,
    double monthlyExpense,
    Map<String, double> categoryExpenses,
    double weekendRatio,
  ) {
    final now = DateTime.now();
    final daysElapsed = now.day;
    final hasData = monthlyExpense > 0;

    if (!hasData) {
      return _InsightCard(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.trending_up,
        iconColor: Colors.green,
        title: '消费习惯',
        badge: null,
        content: '暂无消费数据，开始记账后可查看分析',
        actionText: '查看趋势 →',
        actionColor: Colors.green,
        onAction: (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrendsPage()),
        ),
      );
    }

    // TOP 3 分类及占比
    final sorted = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).map((e) {
      final name = e.key.localizedCategoryName;
      final pct = (e.value / monthlyExpense * 100).toInt();
      return '$name($pct%)';
    }).join('、');

    // HHI 集中度
    final hhi = SpendingInsightCalculator.concentrationIndex(categoryExpenses);
    final String badgeText;
    final Color badgeColor;
    if (hhi >= 0.25) {
      badgeText = '过于集中';
      badgeColor = Colors.red;
    } else if (hhi >= 0.15) {
      badgeText = '较集中';
      badgeColor = Colors.orange;
    } else {
      badgeText = '均衡';
      badgeColor = Colors.green;
    }

    final dailyAvg = monthlyExpense / daysElapsed;
    final weekendPct = (weekendRatio * 100).toStringAsFixed(0);
    final content = 'TOP3: $top3\n'
        '日均 ¥${dailyAvg.toStringAsFixed(0)}，周末占比 $weekendPct%';

    return _InsightCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.trending_up,
      iconColor: Colors.green,
      title: '消费习惯',
      badge: _InsightBadge(text: badgeText, color: badgeColor),
      content: content,
      actionText: '查看趋势 →',
      actionColor: Colors.green,
      onAction: (context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrendsPage()),
      ),
    );
  }

  /// 预算执行洞察（展示所有预算）
  Widget _buildBudgetInsightCard(ThemeData theme, List<BudgetUsage> usages) {
    if (usages.isEmpty) {
      return _InsightCard(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.account_balance_wallet,
        iconColor: Colors.blue,
        title: '预算执行',
        badge: null,
        content: '暂未设置预算，设置后可查看执行情况',
        actionText: '调整预算 →',
        actionColor: Colors.blue,
        onAction: (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
        ),
      );
    }

    // 统计各预算使用情况
    final overBudgetCount = usages.where((u) => u.isOverBudget).length;
    final nearLimitCount = usages.where((u) => u.isNearLimit).length;

    // 整体使用率
    final totalBudget = usages.fold<double>(0, (s, u) => s + u.budget.amount);
    final totalSpent = usages.fold<double>(0, (s, u) => s + u.spent);
    final overallPct = totalBudget > 0 ? (totalSpent / totalBudget * 100).toInt() : 0;

    // 找出使用率最高的预算项
    final highest = usages.reduce((a, b) => a.percentage > b.percentage ? a : b);
    final highestPct = (highest.percentage * 100).toInt();

    // Badge
    final String badgeText;
    final Color badgeColor;
    if (overBudgetCount > 0) {
      badgeText = '$overBudgetCount项超支';
      badgeColor = Colors.red;
    } else if (nearLimitCount > 0) {
      badgeText = '$nearLimitCount项需关注';
      badgeColor = Colors.orange;
    } else {
      badgeText = '执行良好';
      badgeColor = Colors.green;
    }

    // Content
    String content;
    if (usages.length == 1) {
      final u = usages.first;
      final pct = (u.percentage * 100).toInt();
      if (u.isOverBudget) {
        content = '${u.budget.name}已使用$pct%，超出预算 ¥${(u.spent - u.budget.amount).toStringAsFixed(0)}';
      } else {
        content = '${u.budget.name}已使用$pct%，剩余 ¥${u.remaining.toStringAsFixed(0)}';
      }
    } else {
      final needAttention = overBudgetCount + nearLimitCount;
      content = '${usages.length} 个预算整体使用 $overallPct%，'
          '${highest.budget.name}占比最高（$highestPct%）'
          '${needAttention > 0 ? "，$needAttention 项需关注" : ""}';
    }

    return _InsightCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.account_balance_wallet,
      iconColor: Colors.blue,
      title: '预算执行',
      badge: _InsightBadge(text: badgeText, color: badgeColor),
      content: content,
      actionText: '调整预算 →',
      actionColor: Colors.blue,
      onAction: (context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BudgetManagementPage()),
      ),
    );
  }
}

class _InsightBadge {
  final String text;
  final Color color;

  _InsightBadge({required this.text, required this.color});
}

class _InsightCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final Color iconColor;
  final String title;
  final _InsightBadge? badge;
  final String content;
  final String? actionText;
  final Color? actionColor;
  final void Function(BuildContext)? onAction;

  const _InsightCard({
    required this.gradient,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.badge,
    required this.content,
    this.actionText,
    this.actionColor,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              if (badge != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badge!.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!.text,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: badge!.color,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => onAction!(context),
              child: Text(
                actionText!,
                style: TextStyle(
                  fontSize: 13,
                  color: actionColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
