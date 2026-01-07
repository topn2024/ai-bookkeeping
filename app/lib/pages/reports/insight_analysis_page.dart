import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                    _buildLatteFactorCard(theme),
                    const SizedBox(height: 12),
                    _buildSubscriptionAlert(theme),
                    const SizedBox(height: 12),
                    _buildSpendingPatternCard(theme),
                    const SizedBox(height: 12),
                    _buildBudgetInsightCard(theme),
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
  Widget _buildLatteFactorCard(ThemeData theme) {
    return _InsightCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.coffee,
      iconColor: const Color(0xFF8D6E63),
      title: '拿铁因子',
      badge: _InsightBadge(text: '可优化', color: Colors.orange),
      content: '本月咖啡支出 ¥456，日均 ¥15.2',
      actionText: '查看详情 →',
      actionColor: theme.colorScheme.primary,
      onAction: () {},
    );
  }

  /// 闲置订阅提醒
  Widget _buildSubscriptionAlert(ThemeData theme) {
    return _InsightCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.subscriptions,
      iconColor: Colors.red,
      title: '闲置订阅',
      badge: _InsightBadge(text: '需关注', color: Colors.red),
      content: '发现2个超过30天未使用的订阅，月支出 ¥58',
      actionText: '立即处理 →',
      actionColor: Colors.red,
      onAction: () {},
    );
  }

  /// 消费习惯卡片
  Widget _buildSpendingPatternCard(ThemeData theme) {
    return _InsightCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.trending_up,
      iconColor: Colors.green,
      title: '消费习惯',
      badge: _InsightBadge(text: '良好', color: Colors.green),
      content: '周末消费占比下降至28%，较上月减少12%',
      onAction: null,
    );
  }

  /// 预算执行洞察
  Widget _buildBudgetInsightCard(ThemeData theme) {
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
      content: '餐饮类目已使用79%，按当前速度月底将超支¥180',
      actionText: '调整预算 →',
      actionColor: Colors.blue,
      onAction: () {},
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
  final VoidCallback? onAction;

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
              onTap: onAction,
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
