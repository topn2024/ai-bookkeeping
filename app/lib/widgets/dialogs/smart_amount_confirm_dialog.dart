import 'package:flutter/material.dart';

/// 智能金额确认对话框
/// 原型设计 11.07：智能金额确认
/// - 大额消费提醒
/// - 历史消费参考
/// - 选项按钮（确认大额、修改为小额、重新检查）
class SmartAmountConfirmDialog extends StatelessWidget {
  final double inputAmount;
  final double? suggestedAmount;
  final String categoryName;
  final double? maxHistoryAmount;
  final double? avgHistoryAmount;
  final ValueChanged<double>? onConfirm;
  final VoidCallback? onRecheck;

  const SmartAmountConfirmDialog({
    super.key,
    required this.inputAmount,
    this.suggestedAmount,
    required this.categoryName,
    this.maxHistoryAmount,
    this.avgHistoryAmount,
    this.onConfirm,
    this.onRecheck,
  });

  /// 显示智能金额确认对话框
  static Future<double?> show(
    BuildContext context, {
    required double inputAmount,
    double? suggestedAmount,
    required String categoryName,
    double? maxHistoryAmount,
    double? avgHistoryAmount,
  }) {
    return showDialog<double>(
      context: context,
      builder: (context) => SmartAmountConfirmDialog(
        inputAmount: inputAmount,
        suggestedAmount: suggestedAmount,
        categoryName: categoryName,
        maxHistoryAmount: maxHistoryAmount,
        avgHistoryAmount: avgHistoryAmount,
        onConfirm: (amount) => Navigator.pop(context, amount),
        onRecheck: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF9800), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题区
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0B2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb,
                    color: Color(0xFFF57C00),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '这笔金额较大',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFF57C00),
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: '确认是 '),
                            TextSpan(
                              text: _formatAmount(inputAmount),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const TextSpan(text: ' 吗？'),
                            if (suggestedAmount != null) ...[
                              const TextSpan(text: '\n还是想输入 '),
                              TextSpan(
                                text: _formatAmount(suggestedAmount!),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const TextSpan(text: '？'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 历史参考
            if (maxHistoryAmount != null || avgHistoryAmount != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '参考：您的历史消费',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (maxHistoryAmount != null)
                      _buildHistoryItem(
                        theme,
                        '$categoryName单笔最高',
                        _formatAmount(maxHistoryAmount!),
                      ),
                    if (avgHistoryAmount != null)
                      _buildHistoryItem(
                        theme,
                        '$categoryName平均消费',
                        _formatAmount(avgHistoryAmount!),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // 选择按钮
            Column(
              children: [
                // 确认大额
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => onConfirm?.call(inputAmount),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF57C00),
                      side: const BorderSide(color: Color(0xFFF57C00)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('是 ${_formatAmount(inputAmount)}（大额消费）'),
                  ),
                ),
                const SizedBox(height: 8),

                // 修改为小额
                if (suggestedAmount != null)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => onConfirm?.call(suggestedAmount!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('改成 ${_formatAmount(suggestedAmount!)}'),
                    ),
                  ),
                const SizedBox(height: 8),

                // 重新检查
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: onRecheck,
                    style: TextButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('让我再检查一下'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 底部提示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'AI会学习您的消费习惯，提示会越来越精准',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 10000) {
      return '¥${(amount / 10000).toStringAsFixed(amount % 10000 == 0 ? 0 : 1)}万';
    }
    return '¥${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
  }
}

/// 判断是否需要智能金额确认
class SmartAmountValidator {
  final double amount;
  final String categoryId;
  final double? categoryMaxAmount;
  final double? categoryAvgAmount;

  SmartAmountValidator({
    required this.amount,
    required this.categoryId,
    this.categoryMaxAmount,
    this.categoryAvgAmount,
  });

  /// 是否需要确认
  bool get needsConfirmation {
    // 如果金额超过历史最高的3倍，需要确认
    if (categoryMaxAmount != null && amount > categoryMaxAmount! * 3) {
      return true;
    }
    // 如果金额超过平均值的10倍，需要确认
    if (categoryAvgAmount != null && amount > categoryAvgAmount! * 10) {
      return true;
    }
    // 如果金额超过1万，需要确认
    if (amount > 10000) {
      return true;
    }
    return false;
  }

  /// 建议金额（如果输入可能是小数点位置错误）
  double? get suggestedAmount {
    // 检查是否可能少了小数点
    if (amount >= 1000) {
      final suggested = amount / 100;
      if (categoryAvgAmount != null &&
          (suggested - categoryAvgAmount!).abs() < categoryAvgAmount! * 0.5) {
        return suggested;
      }
    }
    return null;
  }
}
