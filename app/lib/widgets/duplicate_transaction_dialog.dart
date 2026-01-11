import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/duplicate_detection_service.dart';
import '../theme/app_theme.dart';

/// 重复交易确认对话框
///
/// 当检测到疑似重复交易时显示此对话框，让用户确认是否继续添加
class DuplicateTransactionDialog extends StatelessWidget {
  /// 新交易
  final Transaction newTransaction;

  /// 重复检测结果
  final DuplicateCheckResult checkResult;

  const DuplicateTransactionDialog({
    super.key,
    required this.newTransaction,
    required this.checkResult,
  });

  /// 显示重复确认对话框
  ///
  /// 返回 true 表示用户确认继续添加
  /// 返回 false 或 null 表示用户取消
  static Future<bool?> show(
    BuildContext context, {
    required Transaction newTransaction,
    required DuplicateCheckResult checkResult,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DuplicateTransactionDialog(
        newTransaction: newTransaction,
        checkResult: checkResult,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange[700],
            size: 28,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '疑似重复交易',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      checkResult.duplicateReason ?? '发现相似的交易记录',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 新交易信息
            _buildTransactionCard(
              context,
              title: '当前输入',
              transaction: newTransaction,
              isNew: true,
            ),
            const SizedBox(height: 12),

            // 相似交易列表
            Text(
              '相似的历史记录 (${checkResult.potentialDuplicates.length}条)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            // 显示最多3条相似记录
            ...checkResult.potentialDuplicates.take(3).map((tx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildTransactionCard(
                  context,
                  title: '历史记录',
                  transaction: tx,
                  isNew: false,
                ),
              );
            }),

            if (checkResult.potentialDuplicates.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '还有 ${checkResult.potentialDuplicates.length - 3} 条相似记录...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        // 继续添加按钮
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('仍然添加'),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(
    BuildContext context, {
    required String title,
    required Transaction transaction,
    required bool isNew,
  }) {
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;
    final dateFormat = DateFormat('MM/dd HH:mm');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNew ? Colors.blue[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNew ? Colors.blue[200]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: isNew ? Colors.blue[700] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                dateFormat.format(transaction.date),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 金额和分类行
          Row(
            children: [
              // 分类图标
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (category?.color ?? Colors.grey).withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  category?.icon ?? Icons.help_outline,
                  color: category?.color ?? Colors.grey,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              // 分类名称
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.localizedName ?? transaction.category,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (transaction.note != null && transaction.note!.isNotEmpty)
                      Text(
                        transaction.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // 金额
              Text(
                '${isExpense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? AppColors.expense : AppColors.income,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 便捷的重复检测和确认流程
///
/// 使用示例:
/// ```dart
/// final confirmed = await DuplicateTransactionHelper.checkAndConfirm(
///   context: context,
///   transaction: newTransaction,
///   transactionNotifier: ref.read(transactionProvider.notifier),
/// );
/// if (confirmed) {
///   // 交易已添加或用户确认添加
/// }
/// ```
class DuplicateTransactionHelper {
  /// 检查重复并在需要时请求确认
  ///
  /// 返回 true 表示交易已成功添加（无重复或用户确认添加）
  /// 返回 false 表示用户取消了添加
  static Future<bool> checkAndConfirm({
    required BuildContext context,
    required Transaction transaction,
    required dynamic transactionNotifier, // TransactionNotifier
    bool showSuccessMessage = true,
  }) async {
    // 先检查是否有重复
    final checkResult = transactionNotifier.checkDuplicate(transaction);

    if (!checkResult.hasPotentialDuplicate) {
      // 没有重复，直接添加
      await transactionNotifier.addTransaction(transaction);
      if (showSuccessMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已记录: ¥${transaction.amount.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    }

    // 有疑似重复，显示确认对话框
    final confirmed = await DuplicateTransactionDialog.show(
      context,
      newTransaction: transaction,
      checkResult: checkResult,
    );

    if (confirmed == true) {
      // 用户确认添加
      await transactionNotifier.forceAddTransaction(transaction);
      if (showSuccessMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已记录: ¥${transaction.amount.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    }

    // 用户取消
    return false;
  }
}
