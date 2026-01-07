import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../providers/transaction_provider.dart';

/// 下钻导航页面
/// 原型设计 7.08：下钻导航
/// - 面包屑导航
/// - 当前筛选条件标签
/// - 统计摘要
/// - 交易列表
class DrillDownNavigationPage extends ConsumerWidget {
  final String categoryId;
  final String? subCategoryId;
  final String? timeRange;

  const DrillDownNavigationPage({
    super.key,
    required this.categoryId,
    this.subCategoryId,
    this.timeRange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final category = DefaultCategories.findById(categoryId);
    final subCategory = subCategoryId != null
        ? DefaultCategories.findById(subCategoryId!)
        : null;

    // 过滤交易
    final filteredTransactions = transactions.where((t) {
      if (t.type != TransactionType.expense) return false;
      if (subCategoryId != null) {
        return t.category == subCategoryId;
      }
      final cat = DefaultCategories.findById(t.category);
      if (cat == null) return false;
      return cat.id == categoryId || cat.parentId == categoryId;
    }).toList();

    final totalExpense = filteredTransactions.fold<double>(0, (sum, t) => sum + t.amount);
    final transactionCount = filteredTransactions.length;
    final avgAmount = transactionCount > 0 ? totalExpense / transactionCount : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme, category, subCategory),
            _buildBreadcrumb(context, theme, category, subCategory),
            _buildFilterTags(theme),
            _buildStatsSummary(theme, totalExpense, transactionCount, avgAmount),
            Expanded(
              child: _buildTransactionList(theme, filteredTransactions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(
    BuildContext context,
    ThemeData theme,
    Category? category,
    Category? subCategory,
  ) {
    final title = subCategory != null
        ? '${category?.localizedName ?? categoryId} - ${subCategory.localizedName}'
        : category?.localizedName ?? categoryId;

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
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _showMoreOptions(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 面包屑导航
  Widget _buildBreadcrumb(
    BuildContext context,
    ThemeData theme,
    Category? category,
    Category? subCategory,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: Text(
                '首页',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            _buildBreadcrumbArrow(theme),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                '支出分析',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            _buildBreadcrumbArrow(theme),
            if (subCategory != null) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  category?.localizedName ?? categoryId,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              _buildBreadcrumbArrow(theme),
              Text(
                subCategory.localizedName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ] else
              Text(
                category?.localizedName ?? categoryId,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbArrow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// 筛选条件标签
  Widget _buildFilterTags(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildFilterTag(theme, '12月'),
          _buildFilterTag(theme, DefaultCategories.findById(categoryId)?.localizedName ?? categoryId),
          if (subCategoryId != null)
            _buildFilterTag(theme, DefaultCategories.findById(subCategoryId!)?.localizedName ?? subCategoryId!),
        ],
      ),
    );
  }

  Widget _buildFilterTag(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.close,
            size: 14,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }

  /// 统计摘要
  Widget _buildStatsSummary(
    ThemeData theme,
    double totalExpense,
    int count,
    double avgAmount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${subCategoryId != null ? "子分类" : "分类"}支出',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '¥${totalExpense.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '占比',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '43%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 24, color: theme.colorScheme.outlineVariant),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(theme, '$count', '笔交易'),
              _buildStatItem(theme, '¥${avgAmount.toStringAsFixed(0)}', '平均单价'),
              _buildStatItem(theme, '+12%', '环比上月', isHighlight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String value, String label, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isHighlight ? Colors.red[700] : theme.colorScheme.onSurface,
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
    );
  }

  /// 交易列表
  Widget _buildTransactionList(ThemeData theme, List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无交易记录',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final t = transactions[index];
        final category = DefaultCategories.findById(t.category);
        return _buildTransactionItem(theme, t, category);
      },
    );
  }

  Widget _buildTransactionItem(ThemeData theme, Transaction t, Category? category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                  t.note ?? category?.localizedName ?? t.category,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  DateFormat('M月d日 HH:mm').format(t.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-¥${t.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.filter_list),
              title: const Text('筛选条件'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导出'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
