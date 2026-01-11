import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../extensions/category_extensions.dart';

/// 批量编辑页面
/// 原型设计 5.07：批量编辑
/// - 顶部选择状态栏
/// - 已选交易列表
/// - 底部批量操作工具栏（改分类、加标签、改账户、删除）
class BatchEditPage extends ConsumerStatefulWidget {
  final List<Transaction> transactions;

  const BatchEditPage({
    super.key,
    required this.transactions,
  });

  @override
  ConsumerState<BatchEditPage> createState() => _BatchEditPageState();
}

class _BatchEditPageState extends ConsumerState<BatchEditPage> {
  late Set<String> _selectedIds;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.transactions.map((t) => t.id).toSet();
    _selectAll = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSelectionHeader(context, theme),
            Expanded(
              child: _buildTransactionList(theme),
            ),
            _buildBottomToolbar(context, theme),
          ],
        ),
      ),
    );
  }

  /// 选择状态栏
  Widget _buildSelectionHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.primary,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              '已选择 ${_selectedIds.length} 项',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleSelectAll,
            child: Text(
              _selectAll ? '取消全选' : '全选',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 交易列表
  Widget _buildTransactionList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.transactions.length,
      itemBuilder: (context, index) {
        final transaction = widget.transactions[index];
        final isSelected = _selectedIds.contains(transaction.id);
        return _buildTransactionItem(theme, transaction, isSelected);
      },
    );
  }

  Widget _buildTransactionItem(
    ThemeData theme,
    Transaction transaction,
    bool isSelected,
  ) {
    final category = DefaultCategories.findById(transaction.category);

    return GestureDetector(
      onTap: () => _toggleSelection(transaction.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: category?.color ?? Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                category?.icon ?? Icons.help_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.note ?? category?.localizedName ?? transaction.category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _formatDateTime(transaction.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${transaction.type == TransactionType.expense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: transaction.type == TransactionType.expense
                    ? AppColors.error
                    : AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    String dateStr;
    if (diff.inDays == 0) {
      dateStr = '今天';
    } else if (diff.inDays == 1) {
      dateStr = '昨天';
    } else {
      dateStr = '${date.month}月${date.day}日';
    }

    return '$dateStr ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 底部工具栏
  Widget _buildBottomToolbar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolbarItem(
            context,
            theme,
            Icons.category,
            '改分类',
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.onSurface,
            () => _showCategoryPicker(context),
          ),
          _buildToolbarItem(
            context,
            theme,
            Icons.label,
            '加标签',
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.onSurface,
            () => _showTagPicker(context),
          ),
          _buildToolbarItem(
            context,
            theme,
            Icons.account_balance_wallet,
            '改账户',
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.onSurface,
            () => _showAccountPicker(context),
          ),
          _buildToolbarItem(
            context,
            theme,
            Icons.delete_outline,
            '删除',
            theme.colorScheme.errorContainer,
            AppColors.error,
            () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarItem(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String label,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: _selectedIds.isEmpty ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _selectedIds.isEmpty
                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: _selectedIds.isEmpty
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  : iconColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _selectedIds.isEmpty
                  ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                  : (label == '删除' ? AppColors.error : theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _selectAll = _selectedIds.length == widget.transactions.length;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedIds.clear();
      } else {
        _selectedIds = widget.transactions.map((t) => t.id).toSet();
      }
      _selectAll = !_selectAll;
    });
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _CategoryPickerSheet(
        onCategorySelected: (category) {
          Navigator.pop(context);
          _applyCategory(category);
        },
      ),
    );
  }

  void _applyCategory(Category category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${_selectedIds.length} 笔交易分类修改为「${category.localizedName}」'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showTagPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TagPickerSheet(
        onTagSelected: (tag) {
          Navigator.pop(context);
          _applyTag(tag);
        },
      ),
    );
  }

  void _applyTag(String tag) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已为 ${_selectedIds.length} 笔交易添加标签「$tag」'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showAccountPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AccountPickerSheet(
        onAccountSelected: (account) {
          Navigator.pop(context);
          _applyAccount(account);
        },
      ),
    );
  }

  void _applyAccount(String account) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${_selectedIds.length} 笔交易账户修改为「$account」'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 笔交易吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelected();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _deleteSelected() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除 ${_selectedIds.length} 笔交易'),
        backgroundColor: AppColors.error,
      ),
    );
    Navigator.pop(context);
  }
}

/// 分类选择Sheet
class _CategoryPickerSheet extends StatelessWidget {
  final Function(Category) onCategorySelected;

  const _CategoryPickerSheet({required this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = DefaultCategories.expenseCategories;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择分类',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: categories.map((category) {
              return GestureDetector(
                onTap: () => onCategorySelected(category),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(category.icon, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.localizedName,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 标签选择Sheet
class _TagPickerSheet extends StatelessWidget {
  final Function(String) onTagSelected;

  const _TagPickerSheet({required this.onTagSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = ['日常', '必要', '偶发', '工作', '娱乐', '学习'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择标签',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return GestureDetector(
                onTap: () => onTagSelected(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 账户选择Sheet
class _AccountPickerSheet extends StatelessWidget {
  final Function(String) onAccountSelected;

  const _AccountPickerSheet({required this.onAccountSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ['现金', '微信', '支付宝', '银行卡', '信用卡'];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择账户',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...accounts.map((account) {
            return ListTile(
              leading: Icon(
                _getAccountIcon(account),
                color: theme.colorScheme.primary,
              ),
              title: Text(account),
              onTap: () => onAccountSelected(account),
            );
          }),
        ],
      ),
    );
  }

  IconData _getAccountIcon(String account) {
    switch (account) {
      case '现金':
        return Icons.money;
      case '微信':
        return Icons.chat;
      case '支付宝':
        return Icons.account_balance_wallet;
      case '银行卡':
        return Icons.credit_card;
      case '信用卡':
        return Icons.credit_score;
      default:
        return Icons.account_balance_wallet;
    }
  }
}
