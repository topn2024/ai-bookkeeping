import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 识别结果数据
class RecognitionResultData {
  final double? amount;
  final String? category;
  final String? note;
  final double confidence;
  final String? rawText;
  final List<String>? suggestions;

  RecognitionResultData({
    this.amount,
    this.category,
    this.note,
    required this.confidence,
    this.rawText,
    this.suggestions,
  });
}

/// 6.10 低置信度确认对话框
/// 当AI识别置信度较低时显示，让用户确认或修正结果
class LowConfidenceDialog extends StatefulWidget {
  final RecognitionResultData result;
  final VoidCallback? onRetry;
  final Function(RecognitionResultData)? onConfirm;
  final VoidCallback? onCancel;

  const LowConfidenceDialog({
    super.key,
    required this.result,
    this.onRetry,
    this.onConfirm,
    this.onCancel,
  });

  /// 显示低置信度确认对话框
  static Future<RecognitionResultData?> show(
    BuildContext context, {
    required RecognitionResultData result,
    VoidCallback? onRetry,
  }) {
    return showModalBottomSheet<RecognitionResultData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LowConfidenceDialog(
        result: result,
        onRetry: onRetry,
      ),
    );
  }

  @override
  State<LowConfidenceDialog> createState() => _LowConfidenceDialogState();
}

class _LowConfidenceDialogState extends State<LowConfidenceDialog> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  String _selectedCategory = '其他';
  final List<String> _categories = [
    '餐饮',
    '交通',
    '购物',
    '娱乐',
    '住房',
    '医疗',
    '教育',
    '其他',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.result.amount?.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(
      text: widget.result.note ?? '',
    );
    _selectedCategory = widget.result.category ?? '其他';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final confidencePercent = (widget.result.confidence * 100).toInt();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖动条
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 警告提示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.lowConfidenceTitle ?? '识别结果需要确认',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l10n?.confidenceLevel ?? "置信度"}: $confidencePercent%',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 原始识别文本
            if (widget.result.rawText != null) ...[
              Text(
                l10n?.originalText ?? '原始语音',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${widget.result.rawText}"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 金额输入
            Text(
              l10n?.amount ?? '金额',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                prefixText: '¥ ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
                filled: true,
                fillColor: _amountController.text.isEmpty
                    ? AppTheme.errorColor.withValues(alpha: 0.1)
                    : AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 16),

            // 分类选择
            Text(
              l10n?.category ?? '分类',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                          fontWeight:
                              isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 备注输入
            Text(
              l10n?.note ?? '备注',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: l10n?.addNote ?? '添加备注...',
              ),
            ),
            const SizedBox(height: 24),

            // 操作按钮
            Row(
              children: [
                // 重新录制按钮
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onRetry?.call();
                    },
                    icon: const Icon(Icons.mic),
                    label: Text(l10n?.retry ?? '重录'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 确认按钮
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _confirmResult,
                    icon: const Icon(Icons.check),
                    label: Text(l10n?.confirm ?? '确认'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResult() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    final result = RecognitionResultData(
      amount: amount,
      category: _selectedCategory,
      note: _noteController.text,
      confidence: 1.0, // 用户确认后置信度为1
      rawText: widget.result.rawText,
    );

    Navigator.pop(context, result);
    widget.onConfirm?.call(result);
  }
}
