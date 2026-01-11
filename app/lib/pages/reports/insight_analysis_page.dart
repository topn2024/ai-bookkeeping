import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../latte_factor_page.dart';
import '../budget_management_page.dart';
import '../trends_page.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';

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
    final categoryExpenses = ref.watch(monthlyExpenseByCategoryProvider);
    final monthlyExpense = ref.watch(monthlyExpenseProvider);
    final budgets = ref.watch(budgetProvider);
    final totalMonthlyBudget = ref.watch(monthlyBudgetProvider);

    // 计算拿铁因子（小额高频消费，如咖啡、奶茶等）
    final latteCategories = ['咖啡', '奶茶', '饮料', '零食'];
    double latteExpense = 0;
    for (final cat in latteCategories) {
      latteExpense += categoryExpenses[cat] ?? 0;
    }
    final now = DateTime.now();
    final daysInMonth = now.day;
    final dailyLatte = daysInMonth > 0 ? latteExpense / daysInMonth : 0.0;

    // 计算餐饮预算使用情况
    final foodExpense = categoryExpenses['餐饮'] ?? categoryExpenses['吃饭'] ?? 0;
    // 从预算列表中查找餐饮类预算
    final foodBudgetItem = budgets.where((b) =>
        b.categoryId == '餐饮' || b.categoryId == '吃饭').firstOrNull;
    final foodBudget = foodBudgetItem?.amount ??
        (totalMonthlyBudget > 0 ? totalMonthlyBudget * 0.3 : 0); // 默认30%
    final foodUsagePercent = foodBudget > 0 ? (foodExpense / foodBudget * 100) : 0.0;
    final projectedOverspend = foodBudget > 0 && now.day > 0
        ? (foodExpense / now.day * DateTime(now.year, now.month + 1, 0).day - foodBudget)
        : 0.0;

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
                    _buildLatteFactorCard(theme, latteExpense, dailyLatte),
                    const SizedBox(height: 12),
                    _buildSubscriptionAlert(theme),
                    const SizedBox(height: 12),
                    _buildSpendingPatternCard(theme, monthlyExpense),
                    const SizedBox(height: 12),
                    _buildBudgetInsightCard(theme, foodUsagePercent, projectedOverspend),
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

  /// 拿铁因子卡片
  Widget _buildLatteFactorCard(ThemeData theme, double latteExpense, double dailyLatte) {
    final hasLatteData = latteExpense > 0;
    final badgeText = dailyLatte > 20 ? '可优化' : (dailyLatte > 10 ? '适中' : '良好');
    final badgeColor = dailyLatte > 20 ? Colors.orange : (dailyLatte > 10 ? Colors.blue : Colors.green);

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
      content: hasLatteData
          ? '本月小额消费 ¥${latteExpense.toStringAsFixed(0)}，日均 ¥${dailyLatte.toStringAsFixed(1)}'
          : '暂无小额高频消费数据',
      actionText: '查看详情 →',
      actionColor: theme.colorScheme.primary,
      onAction: (context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LatteFactorPage()),
      ),
    );
  }

  /// 闲置订阅提醒
  Widget _buildSubscriptionAlert(ThemeData theme) {
    // TODO: 从实际订阅数据中计算闲置订阅
    // 暂时显示空状态提示
    return _InsightCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.subscriptions,
      iconColor: Colors.red,
      title: '闲置订阅',
      badge: null,
      content: '暂无订阅数据，添加订阅后可自动检测闲置情况',
      actionText: null,
      actionColor: null,
      onAction: null,
    );
  }

  /// 消费习惯卡片
  Widget _buildSpendingPatternCard(ThemeData theme, double monthlyExpense) {
    final now = DateTime.now();
    final daysElapsed = now.day;
    final dailyAvg = daysElapsed > 0 ? monthlyExpense / daysElapsed : 0;
    final hasData = monthlyExpense > 0;

    return _InsightCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.trending_up,
      iconColor: Colors.green,
      title: '消费习惯',
      badge: hasData ? _InsightBadge(text: '分析中', color: Colors.green) : null,
      content: hasData
          ? '本月已支出 ¥${monthlyExpense.toStringAsFixed(0)}，日均 ¥${dailyAvg.toStringAsFixed(0)}'
          : '暂无消费数据，开始记账后可查看分析',
      actionText: '查看趋势 →',
      actionColor: Colors.green,
      onAction: (context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrendsPage()),
      ),
    );
  }

  /// 预算执行洞察
  Widget _buildBudgetInsightCard(ThemeData theme, double usagePercent, double projectedOverspend) {
    final usageInt = usagePercent.toInt();
    final isOverBudget = projectedOverspend > 0;
    final badgeText = usageInt >= 90 ? '需关注' : (usageInt >= 70 ? '适中' : '良好');
    final badgeColor = usageInt >= 90 ? Colors.red : (usageInt >= 70 ? Colors.orange : Colors.green);

    String content;
    if (usagePercent == 0) {
      content = '暂未设置预算，设置后可查看执行情况';
    } else if (isOverBudget) {
      content = '餐饮类目已使用$usageInt%，按当前速度月底将超支¥${projectedOverspend.toStringAsFixed(0)}';
    } else {
      content = '餐饮类目已使用$usageInt%，预算执行良好';
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
      badge: usagePercent > 0 ? _InsightBadge(text: badgeText, color: badgeColor) : null,
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
