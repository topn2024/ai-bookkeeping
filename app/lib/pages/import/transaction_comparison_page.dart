import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

/// 交易对比页面
/// 原型设计 5.03：交易对比
/// - 相似度显示
/// - 并排对比卡片（待导入 vs 已存在）
/// - 相似度评分明细
/// - 底部操作按钮（跳过/仍然导入）
class TransactionComparisonPage extends ConsumerWidget {
  final ComparisonTransaction newTransaction;
  final ComparisonTransaction existingTransaction;
  final int similarity;

  const TransactionComparisonPage({
    super.key,
    required this.newTransaction,
    required this.existingTransaction,
    required this.similarity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSimilarityScore(theme),
                    _buildComparisonCards(theme),
                    _buildScoreBreakdown(theme),
                  ],
                ),
              ),
            ),
            _buildBottomActions(context, theme),
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
              child: const Icon(Icons.close),
            ),
          ),
          const Expanded(
            child: Text(
              '交易对比',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 相似度显示
  Widget _buildSimilarityScore(ThemeData theme) {
    final color = similarity >= 90
        ? AppColors.error
        : (similarity >= 70 ? Colors.orange : Colors.grey);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '$similarity%',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '相似度',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 并排对比卡片
  Widget _buildComparisonCards(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildTransactionCard(
              theme,
              '待导入',
              newTransaction,
              const Color(0xFFEBF3FF),
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTransactionCard(
              theme,
              '已存在',
              existingTransaction,
              const Color(0xFFFFF3E0),
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    ThemeData theme,
    String label,
    ComparisonTransaction transaction,
    Color bgColor,
    Color labelColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            transaction.merchant,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDateTime(transaction.date),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            transaction.paymentMethod,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 相似度评分明细
  Widget _buildScoreBreakdown(ThemeData theme) {
    // 计算各项相似度
    final amountScore = newTransaction.amount == existingTransaction.amount ? 100 : 0;
    final merchantScore = _calculateMerchantSimilarity();
    final timeScore = _calculateTimeSimilarity();
    final paymentScore = _calculatePaymentSimilarity();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '相似度评分',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildScoreRow(theme, '金额', amountScore),
          const SizedBox(height: 12),
          _buildScoreRow(theme, '商户名称', merchantScore),
          const SizedBox(height: 12),
          _buildScoreRow(theme, '交易时间', timeScore),
          const SizedBox(height: 12),
          _buildScoreRow(theme, '支付方式', paymentScore),
        ],
      ),
    );
  }

  Widget _buildScoreRow(ThemeData theme, String label, int score) {
    final color = score >= 90
        ? AppColors.success
        : (score >= 70 ? Colors.orange : theme.colorScheme.onSurfaceVariant);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          '$score%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  int _calculateMerchantSimilarity() {
    if (newTransaction.merchant == existingTransaction.merchant) return 100;
    if (newTransaction.merchant.contains(existingTransaction.merchant) ||
        existingTransaction.merchant.contains(newTransaction.merchant)) {
      return 95;
    }
    return 70;
  }

  int _calculateTimeSimilarity() {
    final diff = newTransaction.date.difference(existingTransaction.date).abs();
    if (diff.inMinutes <= 5) return 100;
    if (diff.inMinutes <= 30) return 85;
    if (diff.inHours <= 1) return 70;
    return 50;
  }

  int _calculatePaymentSimilarity() {
    if (newTransaction.paymentMethod == existingTransaction.paymentMethod) return 100;
    if (newTransaction.paymentMethod.contains(existingTransaction.paymentMethod) ||
        existingTransaction.paymentMethod.contains(newTransaction.paymentMethod)) {
      return 90;
    }
    return 60;
  }

  /// 底部操作按钮
  Widget _buildBottomActions(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _skipTransaction(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('跳过此条'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _importAnyway(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('仍然导入'),
            ),
          ),
        ],
      ),
    );
  }

  void _skipTransaction(BuildContext context) {
    Navigator.pop(context, 'skip');
  }

  void _importAnyway(BuildContext context) {
    Navigator.pop(context, 'import');
  }
}

/// 对比交易数据
class ComparisonTransaction {
  final String merchant;
  final double amount;
  final DateTime date;
  final String paymentMethod;

  ComparisonTransaction({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.paymentMethod,
  });
}
