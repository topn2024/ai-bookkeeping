import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/antigravity_shadows.dart';

/// 应用健康状态页面
/// 原型设计 12.01：应用健康状态
/// - 整体健康评分（0-100分）
/// - 各项指标状态卡片（性能、存储、网络、电池）
/// - 最近异常事件列表
/// - 一键诊断按钮
class AppHealthPage extends ConsumerWidget {
  const AppHealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHealthScore(context, theme),
                    _buildMetricsGrid(context, theme),
                    _buildRecentEvents(context, theme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildDiagnoseButton(context, theme),
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
            '应用健康',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScore(BuildContext context, ThemeData theme) {
    const score = 92;
    final scoreColor = score >= 80
        ? AppColors.income
        : (score >= 60 ? AppColors.warning : AppColors.expense);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scoreColor, scoreColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AntigravityShadows.L4,
      ),
      child: Column(
        children: [
          const Text(
            '健康评分',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '/100',
                  style: TextStyle(color: Colors.white70, fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '状态良好',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, ThemeData theme) {
    final metrics = [
      _Metric('性能', Icons.speed, '良好', 0.88, AppColors.income),
      _Metric('存储', Icons.storage, '78%', 0.78, AppColors.primary),
      _Metric('网络', Icons.wifi, '稳定', 0.95, AppColors.income),
      _Metric('电池', Icons.battery_charging_full, '优化', 0.92, AppColors.income),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
        ),
        itemCount: metrics.length,
        itemBuilder: (context, index) {
          final metric = metrics[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AntigravityShadows.L2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(metric.icon, size: 20, color: metric.color),
                    const SizedBox(width: 8),
                    Text(
                      metric.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  metric.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: metric.color,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: metric.progress,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(metric.color),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentEvents(BuildContext context, ThemeData theme) {
    final events = [
      _Event('内存使用峰值', '达到85%后自动清理', DateTime.now().subtract(const Duration(hours: 2)), EventType.warning),
      _Event('数据同步完成', '成功同步128条记录', DateTime.now().subtract(const Duration(hours: 5)), EventType.success),
      _Event('缓存清理', '释放56MB存储空间', DateTime.now().subtract(const Duration(days: 1)), EventType.info),
    ];

    return Container(
      margin: const EdgeInsets.all(16),
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
              '最近事件',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ...events.map((event) => ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: event.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(event.icon, size: 18, color: event.color),
            ),
            title: Text(event.title, style: theme.textTheme.bodyMedium),
            subtitle: Text(
              event.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Text(
              _formatTime(event.time),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDiagnoseButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: AntigravityShadows.L3,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.search),
            label: const Text('一键诊断'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
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

class _Metric {
  final String name;
  final IconData icon;
  final String value;
  final double progress;
  final Color color;

  _Metric(this.name, this.icon, this.value, this.progress, this.color);
}

enum EventType { success, warning, error, info }

class _Event {
  final String title;
  final String description;
  final DateTime time;
  final EventType type;

  _Event(this.title, this.description, this.time, this.type);

  Color get color {
    switch (type) {
      case EventType.success:
        return AppColors.income;
      case EventType.warning:
        return AppColors.warning;
      case EventType.error:
        return AppColors.expense;
      case EventType.info:
        return AppColors.primary;
    }
  }

  IconData get icon {
    switch (type) {
      case EventType.success:
        return Icons.check_circle;
      case EventType.warning:
        return Icons.warning;
      case EventType.error:
        return Icons.error;
      case EventType.info:
        return Icons.info;
    }
  }
}
