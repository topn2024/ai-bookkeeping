import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/antigravity_shadows.dart';

/// 语音撤销页面
/// 原型设计 6.14：语音撤销
/// - 最近操作列表
/// - 语音撤销确认
/// - 批量撤销
class VoiceUndoPage extends ConsumerStatefulWidget {
  const VoiceUndoPage({super.key});

  @override
  ConsumerState<VoiceUndoPage> createState() => _VoiceUndoPageState();
}

class _VoiceUndoPageState extends ConsumerState<VoiceUndoPage> {
  final Set<int> _selectedIndices = {};
  bool _isListening = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final operations = <_UndoableOperation>[
      _UndoableOperation(
        '添加交易',
        '午餐 35元',
        DateTime.now().subtract(const Duration(minutes: 2)),
        OperationType.add,
      ),
      _UndoableOperation(
        '添加交易',
        '咖啡 28元',
        DateTime.now().subtract(const Duration(minutes: 5)),
        OperationType.add,
      ),
      _UndoableOperation(
        '修改交易',
        '交通 18元 → 打车 18元',
        DateTime.now().subtract(const Duration(minutes: 10)),
        OperationType.modify,
      ),
      _UndoableOperation(
        '删除交易',
        '水果 15元',
        DateTime.now().subtract(const Duration(minutes: 15)),
        OperationType.delete,
      ),
      _UndoableOperation(
        '修改分类',
        '餐饮 → 交通',
        DateTime.now().subtract(const Duration(minutes: 20)),
        OperationType.modify,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            _buildVoiceHint(context, theme),
            Expanded(
              child: _buildOperationList(context, theme, operations),
            ),
            if (_selectedIndices.isNotEmpty)
              _buildBatchUndoBar(context, theme),
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
            '撤销操作',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (_selectedIndices.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selectedIndices.clear()),
              child: const Text('取消选择'),
            )
          else
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('全选功能开发中')),
                );
              },
              child: const Text('全选'),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceHint(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isListening = true),
      onTapUp: (_) => setState(() => _isListening = false),
      onTapCancel: () => setState(() => _isListening = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isListening
              ? AppColors.expense.withValues(alpha: 0.1)
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isListening
                ? AppColors.expense.withValues(alpha: 0.5)
                : theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isListening
                    ? AppColors.expense.withValues(alpha: 0.2)
                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic,
                color: _isListening ? AppColors.expense : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isListening ? '正在聆听...' : '语音撤销',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _isListening ? AppColors.expense : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _isListening
                        ? '说出要撤销的内容'
                        : '按住说话，如"撤销刚才那笔"、"撤销午餐"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationList(
    BuildContext context,
    ThemeData theme,
    List<_UndoableOperation> operations,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: operations.length,
      itemBuilder: (context, index) {
        final operation = operations[index];
        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIndices.remove(index);
              } else {
                _selectedIndices.add(index);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: AntigravityShadows.l2,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: operation.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(operation.icon, size: 20, color: operation.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        operation.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        operation.detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _formatTime(operation.time),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outlineVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showUndoConfirm(context, theme, operation),
                  icon: Icon(
                    Icons.undo,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchUndoBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: AntigravityShadows.l3,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              '已选择 ${_selectedIndices.length} 项',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已撤销 ${_selectedIndices.length} 项操作')),
                  );
                  setState(() => _selectedIndices.clear());
                },
                icon: const Icon(Icons.undo),
                label: const Text('批量撤销'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.expense,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUndoConfirm(BuildContext context, ThemeData theme, _UndoableOperation operation) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.undo, size: 32, color: AppColors.warning),
            ),
            const SizedBox(height: 16),
            Text(
              '确认撤销？',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${operation.title}：${operation.detail}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已撤销')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('确认撤销'),
                  ),
                ),
              ],
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
    return DateFormat('MM-dd HH:mm').format(time);
  }
}

enum OperationType { add, modify, delete }

class _UndoableOperation {
  final String title;
  final String detail;
  final DateTime time;
  final OperationType type;

  _UndoableOperation(this.title, this.detail, this.time, this.type);

  Color get color {
    switch (type) {
      case OperationType.add:
        return AppColors.income;
      case OperationType.modify:
        return AppColors.primary;
      case OperationType.delete:
        return AppColors.expense;
    }
  }

  IconData get icon {
    switch (type) {
      case OperationType.add:
        return Icons.add_circle;
      case OperationType.modify:
        return Icons.edit;
      case OperationType.delete:
        return Icons.delete;
    }
  }
}
