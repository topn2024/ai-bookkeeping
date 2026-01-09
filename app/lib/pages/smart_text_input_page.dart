import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 6.15 智能文字输入页面
/// 支持自然语言输入记账，AI自动解析金额、分类等信息
class SmartTextInputPage extends ConsumerStatefulWidget {
  const SmartTextInputPage({super.key});

  @override
  ConsumerState<SmartTextInputPage> createState() => _SmartTextInputPageState();
}

class _SmartTextInputPageState extends ConsumerState<SmartTextInputPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isProcessing = false;
  Map<String, dynamic>? _parsedResult;

  // 示例文本
  final List<String> _examples = [
    '午餐35块',
    '打车去公司20元',
    '买了两杯咖啡花了68',
    '收到工资8000',
    '交房租2500',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.smartTextInput,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_parsedResult != null)
            TextButton(
              onPressed: _confirmTransaction,
              child: Text(
                l10n.confirm,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 输入区域
          _buildInputArea(l10n),
          // 解析结果
          if (_parsedResult != null) _buildParsedResult(l10n),
          // 示例
          if (_parsedResult == null) _buildExamples(l10n),
          const Spacer(),
          // 底部操作
          _buildBottomAction(l10n),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.naturalLanguageInput,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLines: 3,
            style: const TextStyle(
              fontSize: 18,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '例如：午餐35块',
              hintStyle: TextStyle(
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: _onTextChanged,
          ),
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.analyzing,
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
    );
  }

  Widget _buildParsedResult(AppLocalizations l10n) {
    final amount = _parsedResult!['amount'] as double?;
    final category = _parsedResult!['category'] as String?;
    final note = _parsedResult!['note'] as String?;
    final isExpense = _parsedResult!['isExpense'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.recognitionResult,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.successColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '置信度 95%',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 金额
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.amount,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              Text(
                '${isExpense ? "-" : "+"}¥${amount?.toStringAsFixed(2) ?? "0.00"}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          // 分类
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.category,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  category ?? '其他',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 备注
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.note,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              Text(
                note ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamples(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.examples,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _examples.map((example) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _textController.text = example;
                    _onTextChanged(example);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.dividerColor,
                      ),
                    ),
                    child: Text(
                      example,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 语音输入按钮
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.mic,
                  color: AppTheme.textSecondaryColor,
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/voice-recognition');
                },
              ),
            ),
            const SizedBox(width: 12),
            // 确认按钮
            Expanded(
              child: ElevatedButton(
                onPressed: _parsedResult != null ? _confirmTransaction : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
                child: Text(
                  _parsedResult != null
                      ? '${l10n.confirmBookkeeping} ¥${(_parsedResult!['amount'] as double?)?.toStringAsFixed(2) ?? "0.00"}'
                      : l10n.inputToBookkeep,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) {
      setState(() {
        _parsedResult = null;
        _isProcessing = false;
      });
      return;
    }

    setState(() => _isProcessing = true);

    // 模拟解析延迟
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _parsedResult = _parseText(text);
        });
      }
    });
  }

  Map<String, dynamic>? _parseText(String text) {
    // 简单的解析逻辑
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:块|元)?').firstMatch(text);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!) ?? 0;
    if (amount <= 0) return null;

    String category = '其他';
    bool isExpense = true;

    // 分类识别
    if (text.contains('餐') || text.contains('饭') || text.contains('吃') || text.contains('咖啡')) {
      category = '🍜 餐饮';
    } else if (text.contains('车') || text.contains('打车') || text.contains('地铁') || text.contains('公交')) {
      category = '🚗 交通';
    } else if (text.contains('买') || text.contains('购')) {
      category = '🛒 购物';
    } else if (text.contains('房租') || text.contains('水电')) {
      category = '🏠 住房';
    } else if (text.contains('工资') || text.contains('收入') || text.contains('到账')) {
      category = '💰 工资';
      isExpense = false;
    }

    // 提取备注
    String note = text.replaceAll(RegExp(r'\d+(?:\.\d+)?'), '').trim();
    note = note.replaceAll(RegExp(r'[块元]'), '').trim();

    return {
      'amount': amount,
      'category': category,
      'note': note.isNotEmpty ? note : text,
      'isExpense': isExpense,
    };
  }

  void _confirmTransaction() {
    if (_parsedResult == null) return;

    Navigator.pop(context, _parsedResult);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已记账 ¥${(_parsedResult!['amount'] as double?)?.toStringAsFixed(2) ?? "0.00"}',
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
