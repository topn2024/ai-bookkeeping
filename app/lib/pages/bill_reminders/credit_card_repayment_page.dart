import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 信用卡还款提醒页面
/// 原型设计 13.03：信用卡还款提醒
/// - 信用卡显示（卡片样式）
/// - 还款选项（全额、最低、分期）
/// - 智能建议
/// - 立即还款按钮
class CreditCardRepaymentPage extends ConsumerStatefulWidget {
  final String cardName;
  final double billAmount;
  final double minimumPayment;
  final DateTime dueDate;
  final double? availableBalance;

  const CreditCardRepaymentPage({
    super.key,
    required this.cardName,
    required this.billAmount,
    required this.minimumPayment,
    required this.dueDate,
    this.availableBalance,
  });

  @override
  ConsumerState<CreditCardRepaymentPage> createState() => _CreditCardRepaymentPageState();
}

class _CreditCardRepaymentPageState extends ConsumerState<CreditCardRepaymentPage> {
  int _selectedOption = 0; // 0: 全额, 1: 最低, 2: 分期

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCreditCardDisplay(theme),
                    const SizedBox(height: 20),
                    _buildRepaymentOptions(theme),
                    const SizedBox(height: 20),
                    _buildSmartSuggestion(theme),
                  ],
                ),
              ),
            ),
            _buildRepaymentButton(context, theme),
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
              '信用卡还款',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 信用卡显示
  Widget _buildCreditCardDisplay(ThemeData theme) {
    final daysUntilDue = widget.dueDate.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE57373), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE57373).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.credit_card, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.cardName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  daysUntilDue <= 0 ? '已到期' : '$daysUntilDue天后到期',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '本期账单',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${widget.billAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCardInfo('还款日', '${widget.dueDate.month}/${widget.dueDate.day}'),
              _buildCardInfo('最低还款', '¥${widget.minimumPayment.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 还款选项
  Widget _buildRepaymentOptions(ThemeData theme) {
    final options = [
      {
        'title': '全额还款',
        'subtitle': '避免利息，保持良好信用',
        'amount': widget.billAmount,
        'icon': Icons.check_circle,
      },
      {
        'title': '最低还款',
        'subtitle': '产生利息，循环信用',
        'amount': widget.minimumPayment,
        'icon': Icons.radio_button_unchecked,
      },
      {
        'title': '分期还款',
        'subtitle': '分3/6/12期，手续费较低',
        'amount': null,
        'icon': Icons.calendar_month,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '还款方式',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
            children: List.generate(options.length, (index) {
              final option = options[index];
              final isSelected = _selectedOption == index;
              return InkWell(
                onTap: () => setState(() => _selectedOption = index),
                borderRadius: index == 0
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : index == options.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(12))
                        : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: index < options.length - 1
                        ? Border(
                            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['title'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              option['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (option['amount'] != null)
                        Text(
                          '¥${(option['amount'] as double).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  /// 智能建议
  Widget _buildSmartSuggestion(ThemeData theme) {
    final canPayFull = widget.availableBalance != null &&
        widget.availableBalance! >= widget.billAmount;
    final interestSaved = widget.billAmount * 0.015; // 假设1.5%利息

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6495ED).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6495ED).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates,
            color: Color(0xFF6495ED),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '智能建议',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6495ED),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canPayFull
                      ? '建议全额还款，您当前储蓄账户余额¥${widget.availableBalance!.toStringAsFixed(0)}足够支付，且可避免约¥${interestSaved.toStringAsFixed(0)}的利息支出。'
                      : '建议尽量多还款以减少利息支出。最低还款虽然方便，但会产生循环利息。',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 还款按钮
  Widget _buildRepaymentButton(BuildContext context, ThemeData theme) {
    final amount = _selectedOption == 0
        ? widget.billAmount
        : _selectedOption == 1
            ? widget.minimumPayment
            : null;

    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _processPayment(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            amount != null
                ? '立即还款 ¥${amount.toStringAsFixed(0)}'
                : '选择分期方案',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  void _processPayment(BuildContext context) {
    if (_selectedOption == 2) {
      // 显示分期选择
      _showInstallmentOptions(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在处理还款...')),
      );
      Navigator.pop(context, true);
    }
  }

  void _showInstallmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _InstallmentOptionsSheet(
        totalAmount: widget.billAmount,
        onSelect: (months) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已选择$months期分期还款')),
          );
          Navigator.pop(context, true);
        },
      ),
    );
  }
}

class _InstallmentOptionsSheet extends StatelessWidget {
  final double totalAmount;
  final Function(int) onSelect;

  const _InstallmentOptionsSheet({
    required this.totalAmount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = [
      {'months': 3, 'rate': 0.006},
      {'months': 6, 'rate': 0.0055},
      {'months': 12, 'rate': 0.005},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            '选择分期期数',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...options.map((option) {
            final months = option['months'] as int;
            final rate = option['rate'] as double;
            final fee = totalAmount * rate * months;
            final monthlyPayment = (totalAmount + fee) / months;

            return InkWell(
              onTap: () => onSelect(months),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '$months期',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '每期 ¥${monthlyPayment.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '手续费 ¥${fee.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
