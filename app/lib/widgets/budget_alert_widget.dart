import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/budget_alert_provider.dart';
import '../theme/app_theme.dart';

/// 预算提醒横幅组件 - 显示在首页
class BudgetAlertBanner extends ConsumerWidget {
  const BudgetAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertState = ref.watch(budgetAlertProvider);

    if (!alertState.showAlerts || !alertState.hasImportantAlerts) {
      return const SizedBox.shrink();
    }

    final dangerAlerts = alertState.dangerAlerts;
    final warningAlerts = alertState.warningAlerts;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // 超支提醒
          if (dangerAlerts.isNotEmpty)
            _buildAlertCard(
              context,
              ref,
              type: BudgetAlertType.danger,
              alerts: dangerAlerts,
              color: AppColors.expense,
              icon: Icons.warning_amber_rounded,
              title: '预算超支提醒',
            ),

          if (dangerAlerts.isNotEmpty && warningAlerts.isNotEmpty)
            const SizedBox(height: 8),

          // 接近上限提醒
          if (warningAlerts.isNotEmpty)
            _buildAlertCard(
              context,
              ref,
              type: BudgetAlertType.warning,
              alerts: warningAlerts,
              color: Colors.orange,
              icon: Icons.info_outline,
              title: '预算预警提醒',
            ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    WidgetRef ref, {
    required BudgetAlertType type,
    required List<BudgetAlert> alerts,
    required Color color,
    required IconData icon,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (alerts.any((a) => !a.isRead))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${alerts.where((a) => !a.isRead).length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: color.withValues(alpha:0.7),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  for (final alert in alerts) {
                    ref.read(budgetAlertProvider.notifier).markAsRead(alert.budgetId);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...alerts.take(3).map((alert) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    alert.message,
                    style: TextStyle(
                      color: color.withValues(alpha:0.9),
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '¥${alert.spent.toStringAsFixed(0)}/${alert.limit.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: color.withValues(alpha:0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )),
          if (alerts.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '还有${alerts.length - 3}项...',
                style: TextStyle(
                  color: color.withValues(alpha:0.6),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 预算提醒图标按钮 - 用于AppBar
class BudgetAlertIconButton extends ConsumerWidget {
  final VoidCallback? onPressed;

  const BudgetAlertIconButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadBudgetAlertCountProvider);
    final hasAlerts = ref.watch(hasImportantBudgetAlertsProvider);

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            hasAlerts ? Icons.notifications_active : Icons.notifications_outlined,
            color: hasAlerts ? Colors.orange : null,
          ),
          onPressed: onPressed ?? () => _showAlertDialog(context, ref),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.expense,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showAlertDialog(BuildContext context, WidgetRef ref) {
    final alertState = ref.read(budgetAlertProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('预算提醒'),
            const Spacer(),
            if (alertState.unreadCount > 0)
              TextButton(
                onPressed: () {
                  ref.read(budgetAlertProvider.notifier).markAllAsRead();
                  Navigator.pop(context);
                },
                child: const Text('全部已读'),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: alertState.alerts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: AppColors.income, size: 48),
                        SizedBox(height: 16),
                        Text('所有预算使用正常'),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: alertState.alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alertState.alerts[index];
                    return _buildAlertListItem(alert);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertListItem(BudgetAlert alert) {
    Color color;
    IconData icon;

    switch (alert.type) {
      case BudgetAlertType.danger:
        color = AppColors.expense;
        icon = Icons.warning_amber_rounded;
        break;
      case BudgetAlertType.warning:
        color = Colors.orange;
        icon = Icons.info_outline;
        break;
      case BudgetAlertType.safe:
        color = AppColors.income;
        icon = Icons.check_circle;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: alert.isRead ? null : Border.all(color: color.withValues(alpha:0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.budgetName,
                  style: TextStyle(
                    fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(alert.percentage * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '¥${alert.spent.toStringAsFixed(0)}/${alert.limit.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 预算进度条组件
class BudgetProgressIndicator extends StatelessWidget {
  final double percentage;
  final Color? color;
  final double height;

  const BudgetProgressIndicator({
    super.key,
    required this.percentage,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    Color progressColor;
    if (percentage >= 1.0) {
      progressColor = AppColors.expense;
    } else if (percentage >= 0.8) {
      progressColor = Colors.orange;
    } else {
      progressColor = color ?? AppColors.income;
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percentage.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: progressColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}
