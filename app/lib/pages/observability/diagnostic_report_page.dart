import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../theme/antigravity_shadows.dart';

/// 诊断报告页面
/// 原型设计 12.06：诊断报告
/// - 整体诊断结果
/// - 各项检测结果列表
/// - 问题详情与修复建议
/// - 一键修复按钮
class DiagnosticReportPage extends ConsumerWidget {
  const DiagnosticReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final diagnosticResults = <_DiagnosticItem>[
      _DiagnosticItem('数据完整性', DiagnosticStatus.passed, '所有数据记录完整，无丢失'),
      _DiagnosticItem('缓存状态', DiagnosticStatus.warning, '缓存占用较高（256MB），建议清理'),
      _DiagnosticItem('网络连接', DiagnosticStatus.passed, '网络连接正常，延迟12ms'),
      _DiagnosticItem('同步状态', DiagnosticStatus.passed, '数据已同步，最后同步时间5分钟前'),
      _DiagnosticItem('存储空间', DiagnosticStatus.warning, '可用空间不足20%，建议清理'),
      _DiagnosticItem('权限检查', DiagnosticStatus.passed, '所有必要权限已授予'),
      _DiagnosticItem('AI服务', DiagnosticStatus.passed, 'AI服务运行正常'),
      _DiagnosticItem('数据库优化', DiagnosticStatus.failed, '数据库需要优化，查询性能下降'),
    ];

    final passedCount = diagnosticResults.where((d) => d.status == DiagnosticStatus.passed).length;
    final warningCount = diagnosticResults.where((d) => d.status == DiagnosticStatus.warning).length;
    final failedCount = diagnosticResults.where((d) => d.status == DiagnosticStatus.failed).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildOverallResult(context, theme, passedCount, warningCount, failedCount, diagnosticResults.length),
                    _buildResultSummary(context, theme, passedCount, warningCount, failedCount),
                    _buildDiagnosticList(context, theme, diagnosticResults),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (warningCount > 0 || failedCount > 0)
              _buildFixButton(context, theme, warningCount + failedCount),
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
            '诊断报告',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share),
            tooltip: '分享报告',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh),
            tooltip: '重新诊断',
          ),
        ],
      ),
    );
  }

  Widget _buildOverallResult(
    BuildContext context,
    ThemeData theme,
    int passed,
    int warning,
    int failed,
    int total,
  ) {
    final score = ((passed * 100 + warning * 50) / total).round();
    final statusColor = failed > 0
        ? AppColors.expense
        : (warning > 0 ? AppColors.warning : AppColors.income);
    final statusText = failed > 0 ? '需要修复' : (warning > 0 ? '建议优化' : '状态良好');
    final statusIcon = failed > 0
        ? Icons.error
        : (warning > 0 ? Icons.warning : Icons.check_circle);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [statusColor, statusColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AntigravityShadows.L4,
      ),
      child: Column(
        children: [
          Icon(statusIcon, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '健康评分 $score/100',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '诊断时间：${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummary(
    BuildContext context,
    ThemeData theme,
    int passed,
    int warning,
    int failed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(theme, '通过', passed, AppColors.income),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(theme, '警告', warning, AppColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(theme, '失败', failed, AppColors.expense),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AntigravityShadows.L2,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
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
      ),
    );
  }

  Widget _buildDiagnosticList(BuildContext context, ThemeData theme, List<_DiagnosticItem> items) {
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
              '诊断项目',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 64,
              color: theme.colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) => _buildDiagnosticItem(context, theme, items[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(BuildContext context, ThemeData theme, _DiagnosticItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon, size: 20, color: item.color),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.statusLabel,
              style: TextStyle(
                color: item.color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          item.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: item.status != DiagnosticStatus.passed
          ? Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: item.status != DiagnosticStatus.passed
          ? () => _showFixSuggestion(context, theme, item)
          : null,
    );
  }

  void _showFixSuggestion(BuildContext context, ThemeData theme, _DiagnosticItem item) {
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
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.statusLabel,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '问题描述',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(item.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text(
              '修复建议',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _getFixSuggestion(item.name),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('立即修复'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFixSuggestion(String name) {
    switch (name) {
      case '缓存状态':
        return '清理应用缓存可以释放存储空间并提升应用性能。建议定期清理不常用的缓存数据。';
      case '存储空间':
        return '存储空间不足可能导致应用运行缓慢。建议删除不必要的文件或将数据备份到云端。';
      case '数据库优化':
        return '数据库碎片过多会影响查询性能。建议进行数据库压缩和索引重建以提升性能。';
      default:
        return '请联系技术支持获取帮助。';
    }
  }

  Widget _buildFixButton(BuildContext context, ThemeData theme, int issueCount) {
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
            icon: const Icon(Icons.build),
            label: Text('一键修复 $issueCount 个问题'),
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
}

enum DiagnosticStatus { passed, warning, failed }

class _DiagnosticItem {
  final String name;
  final DiagnosticStatus status;
  final String description;

  _DiagnosticItem(this.name, this.status, this.description);

  Color get color {
    switch (status) {
      case DiagnosticStatus.passed:
        return AppColors.income;
      case DiagnosticStatus.warning:
        return AppColors.warning;
      case DiagnosticStatus.failed:
        return AppColors.expense;
    }
  }

  IconData get icon {
    switch (status) {
      case DiagnosticStatus.passed:
        return Icons.check_circle;
      case DiagnosticStatus.warning:
        return Icons.warning;
      case DiagnosticStatus.failed:
        return Icons.error;
    }
  }

  String get statusLabel {
    switch (status) {
      case DiagnosticStatus.passed:
        return '通过';
      case DiagnosticStatus.warning:
        return '警告';
      case DiagnosticStatus.failed:
        return '失败';
    }
  }
}
