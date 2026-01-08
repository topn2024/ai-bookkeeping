import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/antigravity_shadows.dart';

/// 语音编辑记录页面
/// 原型设计 6.13：语音编辑记录
/// - 语音指令编辑历史
/// - 编辑结果对比
/// - 撤销/重做操作
class VoiceEditRecordPage extends ConsumerWidget {
  const VoiceEditRecordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final editRecords = <_EditRecord>[
      _EditRecord(
        '修改午餐金额为40',
        '午餐 35元',
        '午餐 40元',
        DateTime.now().subtract(const Duration(minutes: 5)),
        EditType.modify,
      ),
      _EditRecord(
        '删除咖啡这笔',
        '咖啡 28元',
        '已删除',
        DateTime.now().subtract(const Duration(minutes: 15)),
        EditType.delete,
      ),
      _EditRecord(
        '把交通改成打车',
        '交通 18元',
        '打车 18元',
        DateTime.now().subtract(const Duration(hours: 1)),
        EditType.modify,
      ),
      _EditRecord(
        '添加备注：团队聚餐',
        '午餐 120元',
        '午餐 120元（团队聚餐）',
        DateTime.now().subtract(const Duration(hours: 2)),
        EditType.addNote,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            _buildStatistics(context, theme, editRecords),
            Expanded(
              child: _buildEditList(context, theme, editRecords),
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
            '语音编辑记录',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空记录',
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(BuildContext context, ThemeData theme, List<_EditRecord> records) {
    final modifyCount = records.where((r) => r.type == EditType.modify).length;
    final deleteCount = records.where((r) => r.type == EditType.delete).length;
    final addNoteCount = records.where((r) => r.type == EditType.addNote).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, '总编辑', '${records.length}', Icons.edit),
          _buildStatItem(theme, '修改', '$modifyCount', Icons.edit_note),
          _buildStatItem(theme, '删除', '$deleteCount', Icons.delete),
          _buildStatItem(theme, '添加备注', '$addNoteCount', Icons.note_add),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildEditList(BuildContext context, ThemeData theme, List<_EditRecord> records) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无编辑记录',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: records.length,
      itemBuilder: (context, index) => _buildEditItem(context, theme, records[index]),
    );
  }

  Widget _buildEditItem(BuildContext context, ThemeData theme, _EditRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: record.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(record.icon, size: 18, color: record.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mic,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '"${record.voiceCommand}"',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTime(record.time),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'undo', child: Text('撤销此操作')),
                  const PopupMenuItem(value: 'detail', child: Text('查看详情')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '修改前',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.before,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '修改后',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.after,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: record.type == EditType.delete
                              ? AppColors.expense
                              : AppColors.income,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return DateFormat('MM-dd HH:mm').format(time);
  }
}

enum EditType { modify, delete, addNote }

class _EditRecord {
  final String voiceCommand;
  final String before;
  final String after;
  final DateTime time;
  final EditType type;

  _EditRecord(this.voiceCommand, this.before, this.after, this.time, this.type);

  Color get color {
    switch (type) {
      case EditType.modify:
        return AppColors.primary;
      case EditType.delete:
        return AppColors.expense;
      case EditType.addNote:
        return AppColors.income;
    }
  }

  IconData get icon {
    switch (type) {
      case EditType.modify:
        return Icons.edit;
      case EditType.delete:
        return Icons.delete;
      case EditType.addNote:
        return Icons.note_add;
    }
  }
}
