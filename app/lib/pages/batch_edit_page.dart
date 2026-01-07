import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';

/// 批量编辑页面
/// 原型设计 5.07：批量编辑
/// - 蓝色选择模式头部（关闭、已选数量、全选）
/// - 选中项目列表
/// - 底部工具栏（改分类、加标签、改账户、删除）
class BatchEditPage extends ConsumerStatefulWidget {
  final List<Transaction> initialSelected;

  const BatchEditPage({
    super.key,
    required this.initialSelected,
  });

  @override
  ConsumerState<BatchEditPage> createState() => _BatchEditPageState();
}

class _BatchEditPageState extends ConsumerState<BatchEditPage> {
  late Set<String> _selectedIds;
  List<Transaction> _allTransactions = [];

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelected.map((t) => t.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _allTransactions = ref.watch(transactionProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSelectionHeader(context, theme),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _allTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = _allTransactions[index];
                  return _buildTransactionItem(context, theme, transaction);
                },
              ),
            ),
            _buildBottomToolbar(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(BuildContext context, ThemeData theme) {
    final isAllSelected = _selectedIds.length == _allTransactions.length;

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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                isAllSelected ? '取消全选' : '全选',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, ThemeData theme, Transaction transaction) {
    final isSelected = _selectedIds.contains(transaction.id);
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;

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
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // 选中状态图标
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            // 分类图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: category?.color ?? Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                category?.icon ?? Icons.help_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // 交易信息
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
                    DateFormat('今天 HH:mm').format(transaction.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 金额
            Text(
              '${isExpense ? "-" : "+"}¥${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isExpense ? AppColors.error : AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildToolbarItem(
              context,
              theme,
              icon: Icons.category,
              label: '改分类',
              onTap: _showCategoryPicker,
            ),
            _buildToolbarItem(
              context,
              theme,
              icon: Icons.label,
              label: '加标签',
              onTap: _showTagPicker,
            ),
            _buildToolbarItem(
              context,
              theme,
              icon: Icons.account_balance_wallet,
              label: '改账户',
              onTap: _showAccountPicker,
            ),
            _buildToolbarItem(
              context,
              theme,
              icon: Icons.delete_outline,
              label: '删除',
              onTap: _showDeleteConfirm,
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarItem(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : theme.colorScheme.onSurface;
    final bgColor = isDestructive
        ? AppColors.error.withValues(alpha: 0.1)
        : theme.colorScheme.surfaceContainerHighest;

    return GestureDetector(
      onTap: _selectedIds.isEmpty ? null : onTap,
      child: Opacity(
        opacity: _selectedIds.isEmpty ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDestructive ? AppColors.error : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _allTransactions.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _allTransactions.map((t) => t.id).toSet();
      }
    });
  }

  void _showCategoryPicker() {
    final categories = DefaultCategories.expenseCategories;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择分类',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: categories.take(12).map((cat) {
                return GestureDetector(
                  onTap: () {
                    _updateCategory(cat.id);
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cat.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(cat.icon, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat.localizedName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTagPicker() {
    final tags = ['工作', '生活', '娱乐', '学习', '重要', '待报销'];
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '添加标签',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return GestureDetector(
                  onTap: () {
                    _addTag(tag);
                    Navigator.pop(context);
                  },
                  child: Chip(
                    label: Text(tag),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAccountPicker() {
    final accounts = ref.read(accountProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择账户',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...accounts.map((account) {
              return ListTile(
                leading: Icon(account.icon, color: account.color),
                title: Text(account.localizedName),
                onTap: () {
                  _updateAccount(account.id);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 条记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteSelected();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCategory(String categoryId) async {
    final notifier = ref.read(transactionProvider.notifier);
    for (final id in _selectedIds) {
      final transaction = _allTransactions.firstWhere((t) => t.id == id);
      await notifier.updateTransaction(transaction.copyWith(category: categoryId));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已更新 ${_selectedIds.length} 条记录的分类'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _addTag(String tag) async {
    final notifier = ref.read(transactionProvider.notifier);
    for (final id in _selectedIds) {
      final transaction = _allTransactions.firstWhere((t) => t.id == id);
      final currentTags = transaction.tags ?? [];
      if (!currentTags.contains(tag)) {
        await notifier.updateTransaction(
          transaction.copyWith(tags: [...currentTags, tag]),
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已为 ${_selectedIds.length} 条记录添加标签'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _updateAccount(String accountId) async {
    final notifier = ref.read(transactionProvider.notifier);
    for (final id in _selectedIds) {
      final transaction = _allTransactions.firstWhere((t) => t.id == id);
      await notifier.updateTransaction(transaction.copyWith(accountId: accountId));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已更新 ${_selectedIds.length} 条记录的账户'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final notifier = ref.read(transactionProvider.notifier);
    for (final id in _selectedIds) {
      await notifier.deleteTransaction(id);
    }
    setState(() => _selectedIds.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 ${_selectedIds.length} 条记录'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }
}
