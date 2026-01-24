import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../extensions/extensions.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';
import 'add_transaction_page.dart';

/// 交易详情页面
/// 原型设计 4.03：交易详情
/// - 大额显示（图标、金额、分类名）
/// - 详情卡片（分类、账户、时间、商户、备注）
/// - 钱龄信息卡片
/// - 底部操作按钮（删除、编辑）≥48dp触控目标
class TransactionDetailPage extends ConsumerWidget {
  final Transaction transaction;

  const TransactionDetailPage({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.transactionDetails),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context, ref),
            tooltip: '编辑',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildAmountDisplay(context, theme, category, isExpense, isIncome),
                  _buildDetailsCard(context, theme, category, ref),
                  if (transaction.hasMoneyAge && isExpense)
                    _buildMoneyAgeCard(context, theme),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildActionButtons(context, theme, ref),
        ],
      ),
    );
  }

  /// 金额显示区域
  Widget _buildAmountDisplay(
    BuildContext context,
    ThemeData theme,
    Category? category,
    bool isExpense,
    bool isIncome,
  ) {
    Color amountColor;
    String amountPrefix;
    if (isExpense) {
      amountColor = AppColors.error;
      amountPrefix = '-';
    } else if (isIncome) {
      amountColor = AppColors.success;
      amountPrefix = '+';
    } else {
      amountColor = AppColors.transfer;
      amountPrefix = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          // 分类图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: category?.color ?? Colors.grey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              category?.icon ?? Icons.help_outline,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          // 金额
          Text(
            '$amountPrefix¥${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
          const SizedBox(height: 8),
          // 备注或分类名
          Text(
            transaction.note ?? category?.localizedName ?? transaction.category,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 详情卡片
  Widget _buildDetailsCard(
    BuildContext context,
    ThemeData theme,
    Category? category,
    WidgetRef ref,
  ) {
    final accountName = _getAccountName(ref, transaction.accountId);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;

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
          _buildDetailRow(
            context,
            theme,
            label: context.l10n.category,
            value: category?.localizedName ?? transaction.category,
          ),
          _buildDivider(theme),
          _buildDetailRow(
            context,
            theme,
            label: context.l10n.account,
            value: accountName,
          ),
          _buildDivider(theme),
          _buildDetailRow(
            context,
            theme,
            label: context.l10n.time,
            value: DateFormat('yyyy-MM-dd HH:mm').format(transaction.date),
          ),
          if (transaction.note != null && transaction.note!.isNotEmpty) ...[
            _buildDivider(theme),
            _buildDetailRow(
              context,
              theme,
              label: '商户',
              value: transaction.rawMerchant ?? transaction.note!,
            ),
          ],
          if (transaction.note != null && transaction.rawMerchant != null) ...[
            _buildDivider(theme),
            _buildDetailRow(
              context,
              theme,
              label: context.l10n.note,
              value: transaction.note!,
            ),
          ],
          _buildDivider(theme),
          _buildDetailRow(
            context,
            theme,
            label: '类型',
            value: isExpense
                ? context.l10n.expense
                : (isIncome ? context.l10n.income : context.l10n.transfer),
          ),
          if (transaction.vaultId != null) ...[
            _buildDivider(theme),
            _buildDetailRow(
              context,
              theme,
              label: '关联小金库',
              value: transaction.vaultId!,
            ),
          ],
          if (transaction.tags != null && transaction.tags!.isNotEmpty) ...[
            _buildDivider(theme),
            _buildTagsRow(context, theme),
          ],
          // 数据来源
          _buildDivider(theme),
          _buildDetailRow(
            context,
            theme,
            label: '数据来源',
            value: _getSourceDisplayName(transaction.source),
          ),
          // AI置信度（仅非手动录入时显示）
          if (transaction.source != TransactionSource.manual &&
              transaction.aiConfidence != null) ...[
            _buildDivider(theme),
            _buildDetailRow(
              context,
              theme,
              label: 'AI置信度',
              value: '${(transaction.aiConfidence! * 100).toStringAsFixed(0)}%',
            ),
          ],
        ],
      ),
    );
  }

  /// 获取数据来源显示名称
  String _getSourceDisplayName(TransactionSource source) {
    switch (source) {
      case TransactionSource.manual:
        return '手动录入';
      case TransactionSource.image:
        return '图片识别';
      case TransactionSource.voice:
        return '语音记账';
      case TransactionSource.email:
        return '邮件解析';
      case TransactionSource.import_:
        return '批量导入';
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              maxLines: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsRow(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '标签',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: transaction.tags!.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      color: theme.colorScheme.outlineVariant,
    );
  }

  /// 钱龄信息卡片
  Widget _buildMoneyAgeCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              const Text(
                '钱龄信息',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                const TextSpan(text: '这笔支出使用的是 '),
                TextSpan(
                  text: '${transaction.moneyAge ?? 0}天前',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' 的收入'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部操作按钮
  Widget _buildActionButtons(BuildContext context, ThemeData theme, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteConfirmDialog(context, ref),
                icon: Icon(Icons.delete, color: AppColors.error),
                label: Text(context.l10n.delete, style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToEdit(context, ref),
                icon: const Icon(Icons.edit),
                label: Text(context.l10n.edit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
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

  String _getAccountName(WidgetRef ref, String accountId) {
    final accounts = ref.read(accountProvider);
    final account = accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => DefaultAccounts.accounts.firstWhere(
        (a) => a.id == accountId,
        orElse: () => Account(
          id: accountId,
          name: accountId,
          type: AccountType.cash,
          balance: 0,
          icon: Icons.account_balance_wallet,
          color: Colors.grey,
          createdAt: DateTime.now(),
        ),
      ),
    );
    return account.localizedName;
  }

  void _navigateToEdit(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(transaction: transaction),
      ),
    ).then((_) {
      // 返回后可能需要刷新详情
      ref.read(transactionProvider.notifier).refresh();
    });
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
          title: Text(context.l10n.confirmDelete),
          content: Text(context.l10n.confirmDeleteRecord),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(transactionProvider.notifier).deleteTransaction(transaction.id);
                Navigator.pop(context); // 关闭对话框
                Navigator.pop(context); // 返回列表页
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.transactionDeleted)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(0, 48),
              ),
              child: Text(context.l10n.confirmDelete),
            ),
          ],
        );
      },
    );
  }
}
