import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../theme/antigravity_shadows.dart';

/// 告警历史页面
/// 原型设计 12.04：告警历史
/// - 告警统计卡片
/// - 告警级别分布
/// - 告警历史列表（按时间倒序）
/// - 告警详情和处理操作
class AlertHistoryPage extends ConsumerWidget {
  const AlertHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final alerts = <_Alert>[
      _Alert(AlertType.critical, '数据同步失败', '连续3次同步失败，请检查网络连接', DateTime.now().subtract(const Duration(hours: 1)), false),
      _Alert(AlertType.warning, '内存使用过高', '内存使用达到85%', DateTime.now().subtract(const Duration(hours: 3)), true),
      _Alert(AlertType.info, '新版本可用', '版本 2.0.6 已发布', DateTime.now().subtract(const Duration(hours: 6)), false),
      _Alert(AlertType.warning, '预算即将超支', '餐饮预算已使用90%', DateTime.now().subtract(const Duration(days: 1)), true),
      _Alert(AlertType.critical, 'AI服务异常', 'LLM服务响应超时', DateTime.now().subtract(const Duration(days: 2)), true),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildStatsCard(context, theme, alerts),
                    _buildAlertList(context, theme, alerts),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '告警历史',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings),
            tooltip: '告警设置',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, ThemeData theme, List<_Alert> alerts) {
    final critical = alerts.where((a) => a.type == AlertType.critical).length;
    final warning = alerts.where((a) => a.type == AlertType.warning).length;
    final info = alerts.where((a) => a.type == AlertType.info).length;
    final unresolved = alerts.where((a) => !a.resolved).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AntigravityShadows.L2,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(theme, '严重', '$critical', AppColors.expense),
              _buildStatItem(theme, '警告', '$warning', AppColors.warning),
              _buildStatItem(theme, '通知', '$info', AppColors.primary),
              _buildStatItem(theme, '未处理', '$unresolved', theme.colorScheme.onSurface),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: critical,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.expense,
                    borderRadius: BorderRadius.horizontal(left: const Radius.circular(4)),
                  ),
                ),
              ),
              Expanded(
                flex: warning,
                child: Container(height: 8, color: AppColors.warning),
              ),
              Expanded(
                flex: info,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.horizontal(right: const Radius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertList(BuildContext context, ThemeData theme, List<_Alert> alerts) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AntigravityShadows.L2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '告警记录',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 64,
              color: theme.colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) => _buildAlertItem(context, theme, alerts[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, ThemeData theme, _Alert alert) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: alert.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(alert.icon, size: 20, color: alert.color),
          ),
          if (!alert.resolved)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.expense,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              alert.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: alert.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              alert.typeLabel,
              style: TextStyle(
                color: alert.color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatTime(alert.time),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              if (alert.resolved) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.check_circle,
                  size: 12,
                  color: AppColors.income,
                ),
                const SizedBox(width: 4),
                Text(
                  '已处理',
                  style: TextStyle(
                    color: AppColors.income,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      onTap: () => _showAlertDetail(context, theme, alert),
    );
  }

  void _showAlertDetail(BuildContext context, ThemeData theme, _Alert alert) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: alert.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(alert.icon, color: alert.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(alert.time),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(alert.message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            if (!alert.resolved)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('标记为已处理'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}

enum AlertType { critical, warning, info }

class _Alert {
  final AlertType type;
  final String title;
  final String message;
  final DateTime time;
  final bool resolved;

  _Alert(this.type, this.title, this.message, this.time, this.resolved);

  Color get color {
    switch (type) {
      case AlertType.critical:
        return AppColors.expense;
      case AlertType.warning:
        return AppColors.warning;
      case AlertType.info:
        return AppColors.primary;
    }
  }

  IconData get icon {
    switch (type) {
      case AlertType.critical:
        return Icons.error;
      case AlertType.warning:
        return Icons.warning;
      case AlertType.info:
        return Icons.info;
    }
  }

  String get typeLabel {
    switch (type) {
      case AlertType.critical:
        return '严重';
      case AlertType.warning:
        return '警告';
      case AlertType.info:
        return '通知';
    }
  }
}
