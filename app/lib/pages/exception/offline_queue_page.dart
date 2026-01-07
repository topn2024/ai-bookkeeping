import 'package:flutter/material.dart';

/// 离线操作队列页面
/// 原型设计 11.04：离线操作队列
/// - 离线状态横幅
/// - 队列统计（待创建、待更新、待删除）
/// - 操作队列列表
/// - 说明信息
class OfflineQueuePage extends StatelessWidget {
  final List<PendingOperation> operations;
  final bool isOnline;

  const OfflineQueuePage({
    super.key,
    required this.operations,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final createCount = operations.where((o) => o.type == OperationType.create).length;
    final updateCount = operations.where((o) => o.type == OperationType.update).length;
    final deleteCount = operations.where((o) => o.type == OperationType.delete).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!isOnline) _buildOfflineBanner(),
            _buildHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQueueStats(theme, createCount, updateCount, deleteCount),
                    const SizedBox(height: 16),
                    _buildOperationsList(theme),
                    const SizedBox(height: 16),
                    _buildInfoNote(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 离线状态横幅
  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFFEF3C7),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '离线模式 · 恢复网络后自动同步',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
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
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '待同步操作',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6495ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${operations.length}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 队列统计
  Widget _buildQueueStats(
    ThemeData theme,
    int createCount,
    int updateCount,
    int deleteCount,
  ) {
    return Row(
      children: [
        _buildStatCard(theme, '待创建', createCount, theme.colorScheme.primary),
        const SizedBox(width: 8),
        _buildStatCard(theme, '待更新', updateCount, const Color(0xFFFFB74D)),
        const SizedBox(width: 8),
        _buildStatCard(theme, '待删除', deleteCount, theme.colorScheme.error),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 操作列表
  Widget _buildOperationsList(ThemeData theme) {
    if (operations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.cloud_done,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '所有数据已同步',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: operations.map((op) => _buildOperationItem(theme, op)).toList(),
      ),
    );
  }

  Widget _buildOperationItem(ThemeData theme, PendingOperation operation) {
    final iconData = _getOperationIcon(operation.type);
    final iconColor = _getOperationColor(operation.type, theme);
    final bgColor = iconColor.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getOperationTitle(operation.type),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${operation.description} · ${operation.timeAgo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.schedule,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  IconData _getOperationIcon(OperationType type) {
    switch (type) {
      case OperationType.create:
        return Icons.add_circle;
      case OperationType.update:
        return Icons.edit;
      case OperationType.delete:
        return Icons.delete;
    }
  }

  Color _getOperationColor(OperationType type, ThemeData theme) {
    switch (type) {
      case OperationType.create:
        return const Color(0xFF4DB6AC);
      case OperationType.update:
        return const Color(0xFFFFB74D);
      case OperationType.delete:
        return theme.colorScheme.error;
    }
  }

  String _getOperationTitle(OperationType type) {
    switch (type) {
      case OperationType.create:
        return '新增交易';
      case OperationType.update:
        return '修改交易';
      case OperationType.delete:
        return '删除交易';
    }
  }

  /// 信息提示
  Widget _buildInfoNote(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info,
            color: theme.colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '所有操作已保存在本地，连接网络后将自动同步',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 操作类型
enum OperationType {
  create,
  update,
  delete,
}

/// 待处理操作
class PendingOperation {
  final String id;
  final OperationType type;
  final String description;
  final String timeAgo;
  final DateTime createdAt;

  PendingOperation({
    required this.id,
    required this.type,
    required this.description,
    required this.timeAgo,
    required this.createdAt,
  });
}
