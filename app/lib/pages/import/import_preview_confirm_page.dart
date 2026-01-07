import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../providers/transaction_provider.dart';

/// 导入预览确认页面
/// 原型设计 5.12：导入预览确认
/// - 摘要卡片（新记录、已处理疑似、已排除重复）
/// - 交易预览列表（按日期分组）
/// - 筛选功能
/// - 确认导入按钮
class ImportPreviewConfirmPage extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;
  final int newRecords;
  final int processedSuspected;
  final int excludedDuplicates;

  const ImportPreviewConfirmPage({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.newRecords,
    required this.processedSuspected,
    required this.excludedDuplicates,
  });

  @override
  ConsumerState<ImportPreviewConfirmPage> createState() => _ImportPreviewConfirmPageState();
}

class _ImportPreviewConfirmPageState extends ConsumerState<ImportPreviewConfirmPage> {
  bool _isImporting = false;
  String? _filterType;

  // 模拟导入的交易数据
  final List<PreviewTransaction> _previewTransactions = [
    PreviewTransaction(
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: 'food',
      description: '午餐 - 美团外卖',
      amount: -35.00,
      type: TransactionType.expense,
    ),
    PreviewTransaction(
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: 'transport',
      description: '滴滴出行',
      amount: -15.00,
      type: TransactionType.expense,
    ),
    PreviewTransaction(
      date: DateTime.now().subtract(const Duration(days: 2)),
      category: 'shopping',
      description: '盒马鲜生',
      amount: -128.00,
      type: TransactionType.expense,
    ),
    PreviewTransaction(
      date: DateTime.now().subtract(const Duration(days: 2)),
      category: 'salary',
      description: '工资收入',
      amount: 15000.00,
      type: TransactionType.income,
    ),
    PreviewTransaction(
      date: DateTime.now().subtract(const Duration(days: 3)),
      category: 'entertainment',
      description: '电影票',
      amount: -68.00,
      type: TransactionType.expense,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredTransactions = _getFilteredTransactions();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(context, theme),
                    _buildFilterChips(context, theme),
                    _buildTransactionList(context, theme, filteredTransactions),
                  ],
                ),
              ),
            ),
            _buildImportButton(context, theme),
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
              '确认导入',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _showFilterOptions(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.filter_list,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            theme,
            value: widget.newRecords.toString(),
            label: '新记录',
            color: AppColors.success,
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outlineVariant,
          ),
          _buildSummaryItem(
            theme,
            value: widget.processedSuspected.toString(),
            label: '已处理疑似',
            color: Colors.orange,
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.colorScheme.outlineVariant,
          ),
          _buildSummaryItem(
            theme,
            value: widget.excludedDuplicates.toString(),
            label: '已排除重复',
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    ThemeData theme, {
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          _buildFilterChip(theme, null, '全部'),
          _buildFilterChip(theme, 'expense', '支出'),
          _buildFilterChip(theme, 'income', '收入'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(ThemeData theme, String? type, String label) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList(
    BuildContext context,
    ThemeData theme,
    List<PreviewTransaction> transactions,
  ) {
    // 按日期分组
    final grouped = <String, List<PreviewTransaction>>{};
    final dateFormat = DateFormat('M月d日');
    for (final t in transactions) {
      final key = dateFormat.format(t.date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(t);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...entry.value.map((t) => _buildTransactionItem(theme, t)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionItem(ThemeData theme, PreviewTransaction transaction) {
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  DateFormat('HH:mm').format(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? "" : "+"}¥${transaction.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isExpense ? AppColors.error : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isImporting ? null : _confirmImport,
            icon: _isImporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(
              _isImporting ? '导入中...' : '确认导入 ${widget.newRecords} 条记录',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<PreviewTransaction> _getFilteredTransactions() {
    if (_filterType == null) return _previewTransactions;
    if (_filterType == 'expense') {
      return _previewTransactions.where((t) => t.type == TransactionType.expense).toList();
    }
    if (_filterType == 'income') {
      return _previewTransactions.where((t) => t.type == TransactionType.income).toList();
    }
    return _previewTransactions;
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('全部'),
              onTap: () {
                setState(() => _filterType = null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.arrow_downward, color: AppColors.error),
              title: const Text('仅支出'),
              onTap: () {
                setState(() => _filterType = 'expense');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.arrow_upward, color: AppColors.success),
              title: const Text('仅收入'),
              onTap: () {
                setState(() => _filterType = 'income');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmImport() async {
    setState(() => _isImporting = true);

    try {
      // 模拟导入过程
      await Future.delayed(const Duration(seconds: 1));

      // 将预览交易转换为实际交易并保存
      final transactionNotifier = ref.read(transactionProvider.notifier);
      for (final preview in _previewTransactions) {
        final transaction = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString() + preview.description.hashCode.toString(),
          type: preview.type,
          amount: preview.amount.abs(),
          category: preview.category,
          accountId: 'default',
          date: preview.date,
          note: preview.description,
          createdAt: DateTime.now(),
        );
        await transactionNotifier.addTransaction(transaction);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入 ${widget.newRecords} 条记录'),
            backgroundColor: AppColors.success,
          ),
        );

        // 返回导入页面
        Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/import');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }
}

/// 预览交易
class PreviewTransaction {
  final DateTime date;
  final String category;
  final String description;
  final double amount;
  final TransactionType type;

  PreviewTransaction({
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    required this.type,
  });
}
