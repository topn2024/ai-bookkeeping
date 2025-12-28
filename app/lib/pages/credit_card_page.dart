import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/credit_card.dart';
import '../providers/credit_card_provider.dart';

class CreditCardPage extends ConsumerWidget {
  const CreditCardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(creditCardProvider);
    final summary = ref.watch(creditCardSummaryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('信用卡管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(context, ref),
          ),
        ],
      ),
      body: cards.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(context, summary, theme),
                const SizedBox(height: 16),
                ...cards.map((card) => _buildCreditCardItem(context, ref, card, theme)),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有添加信用卡',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加信用卡'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, CreditCardSummary summary, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '信用卡概览',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${summary.cardCount}张卡',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '总额度',
                    '¥${summary.totalLimit.toStringAsFixed(0)}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '已用额度',
                    '¥${summary.totalUsed.toStringAsFixed(0)}',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '可用额度',
                    '¥${summary.totalAvailable.toStringAsFixed(0)}',
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Usage progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.usageRate,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  summary.usageRate > 0.8
                      ? Colors.red
                      : summary.usageRate > 0.5
                          ? Colors.orange
                          : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '总体额度使用率: ${(summary.usageRate * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (summary.dueSoonCount > 0 || summary.overdueCount > 0) ...[
              const Divider(height: 24),
              Row(
                children: [
                  if (summary.overdueCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning, size: 14, color: Colors.red[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${summary.overdueCount}张已逾期',
                            style: TextStyle(fontSize: 12, color: Colors.red[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (summary.dueSoonCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${summary.dueSoonCount}张即将还款',
                            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCreditCardItem(BuildContext context, WidgetRef ref, CreditCard card, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showCardDetail(context, ref, card),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: card.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(card.icon, color: card.color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                card.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!card.isEnabled)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '已禁用',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                        if (card.bankName != null)
                          Text(
                            card.bankName!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddEditDialog(context, ref, card: card);
                      } else if (value == 'payment') {
                        _showPaymentDialog(context, ref, card);
                      } else if (value == 'toggle') {
                        ref.read(creditCardProvider.notifier).toggleCreditCard(card.id);
                      } else if (value == 'delete') {
                        _confirmDelete(context, ref, card);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(value: 'payment', child: Text('还款')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(card.isEnabled ? '禁用' : '启用'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Credit usage bar
              Row(
                children: [
                  Text(
                    '已用 ¥${card.usedAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    '额度 ¥${card.creditLimit.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: card.usageRate,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    card.isNearLimit ? Colors.red : card.color,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildCardInfoChip(
                    Icons.calendar_today,
                    '账单日: ${card.billDay}日',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildCardInfoChip(
                    Icons.payment,
                    '还款日: ${card.paymentDueDay}日',
                    card.isOverdue
                        ? Colors.red
                        : card.isPaymentDueSoon
                            ? Colors.orange
                            : Colors.green,
                  ),
                ],
              ),
              if (card.isPaymentDueSoon || card.isOverdue) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: card.isOverdue
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        card.isOverdue ? Icons.warning : Icons.notifications_active,
                        size: 16,
                        color: card.isOverdue ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        card.isOverdue
                            ? '已逾期 ${-card.daysUntilPayment} 天'
                            : '${card.daysUntilPayment} 天后还款',
                        style: TextStyle(
                          fontSize: 12,
                          color: card.isOverdue ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  void _showCardDetail(BuildContext context, WidgetRef ref, CreditCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _CreditCardDetailSheet(
          card: card,
          scrollController: scrollController,
          onPayment: () {
            Navigator.pop(context);
            _showPaymentDialog(context, ref, card);
          },
          onEdit: () {
            Navigator.pop(context);
            _showAddEditDialog(context, ref, card: card);
          },
        ),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, WidgetRef ref, {CreditCard? card}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreditCardFormPage(card: card),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, CreditCard card) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('还款 - ${card.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前欠款: ¥${card.usedAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: '还款金额',
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    amountController.text = card.minPayment.toStringAsFixed(2);
                  },
                  child: const Text('最低还款'),
                ),
                TextButton(
                  onPressed: () {
                    amountController.text = card.usedAmount.toStringAsFixed(2);
                  },
                  child: const Text('全额还款'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                ref.read(creditCardProvider.notifier).makePayment(card.id, amount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('成功还款 ¥${amount.toStringAsFixed(2)}')),
                );
              }
            },
            child: const Text('确认还款'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CreditCard card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除信用卡 "${card.displayName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(creditCardProvider.notifier).deleteCreditCard(card.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _CreditCardDetailSheet extends StatelessWidget {
  final CreditCard card;
  final ScrollController scrollController;
  final VoidCallback onPayment;
  final VoidCallback onEdit;

  const _CreditCardDetailSheet({
    required this.card,
    required this.scrollController,
    required this.onPayment,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
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
          // Card header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: card.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(card.icon, color: card.color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (card.bankName != null)
                      Text(
                        card.bankName!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Credit limit card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [card.color, card.color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '可用额度',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${card.availableCredit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCreditInfo('总额度', '¥${card.creditLimit.toStringAsFixed(0)}'),
                    _buildCreditInfo('已用额度', '¥${card.usedAmount.toStringAsFixed(0)}'),
                    _buildCreditInfo('使用率', '${(card.usageRate * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Billing info
          _buildInfoSection('账单信息', [
            _buildInfoRow('账单日', '每月 ${card.billDay} 日'),
            _buildInfoRow('还款日', '每月 ${card.paymentDueDay} 日'),
            _buildInfoRow('下个账单日', _formatDate(card.nextBillDate)),
            _buildInfoRow('下个还款日', _formatDate(card.nextPaymentDueDate)),
            _buildInfoRow('距还款日', '${card.daysUntilPayment} 天'),
          ]),
          const SizedBox(height: 16),
          // Current bill
          _buildInfoSection('当期账单', [
            _buildInfoRow('账单金额', '¥${card.currentBill.toStringAsFixed(2)}'),
            _buildInfoRow('最低还款', '¥${card.minPayment.toStringAsFixed(2)}'),
          ]),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPayment,
                  icon: const Icon(Icons.payment),
                  label: const Text('还款'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

class CreditCardFormPage extends ConsumerStatefulWidget {
  final CreditCard? card;

  const CreditCardFormPage({super.key, this.card});

  @override
  ConsumerState<CreditCardFormPage> createState() => _CreditCardFormPageState();
}

class _CreditCardFormPageState extends ConsumerState<CreditCardFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _limitController;
  late TextEditingController _usedController;
  late TextEditingController _cardNumberController;

  String? _selectedBank;
  int _billDay = 1;
  int _paymentDueDay = 20;
  IconData _selectedIcon = Icons.credit_card;
  Color _selectedColor = Colors.blue;

  bool get isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card?.name ?? '');
    _limitController = TextEditingController(
      text: widget.card?.creditLimit.toStringAsFixed(0) ?? '',
    );
    _usedController = TextEditingController(
      text: widget.card?.usedAmount.toStringAsFixed(0) ?? '0',
    );
    _cardNumberController = TextEditingController(text: widget.card?.cardNumber ?? '');

    if (widget.card != null) {
      _selectedBank = widget.card!.bankName;
      _billDay = widget.card!.billDay;
      _paymentDueDay = widget.card!.paymentDueDay;
      _selectedIcon = widget.card!.icon;
      _selectedColor = widget.card!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    _usedController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑信用卡' : '添加信用卡'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bank selection
            DropdownButtonFormField<String>(
              value: _selectedBank,
              decoration: const InputDecoration(
                labelText: '发卡银行',
                prefixIcon: Icon(Icons.account_balance),
                border: OutlineInputBorder(),
              ),
              items: DefaultBanks.banks.map((bank) {
                return DropdownMenuItem(value: bank, child: Text(bank));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBank = value;
                  if (_nameController.text.isEmpty && value != null) {
                    _nameController.text = '$value信用卡';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            // Card name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '卡片名称',
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入卡片名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Card number (last 4 digits)
            TextFormField(
              controller: _cardNumberController,
              decoration: const InputDecoration(
                labelText: '卡号后四位 (选填)',
                prefixIcon: Icon(Icons.pin),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 16),
            // Credit limit
            TextFormField(
              controller: _limitController,
              decoration: const InputDecoration(
                labelText: '信用额度',
                prefixIcon: Icon(Icons.monetization_on),
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入信用额度';
                }
                if (double.tryParse(value) == null) {
                  return '请输入有效金额';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Used amount
            TextFormField(
              controller: _usedController,
              decoration: const InputDecoration(
                labelText: '已用额度',
                prefixIcon: Icon(Icons.account_balance_wallet),
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            // Bill day and payment due day
            Text(
              '账单周期',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDaySelector(
                    label: '账单日',
                    value: _billDay,
                    onChanged: (value) => setState(() => _billDay = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDaySelector(
                    label: '还款日',
                    value: _paymentDueDay,
                    onChanged: (value) => setState(() => _paymentDueDay = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Icon and color selection
            Text(
              '图标和颜色',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildIconColorSelector(),
            const SizedBox(height: 32),
            // Save button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saveCard,
                child: Text(isEditing ? '保存修改' : '添加信用卡'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            items: List.generate(28, (i) => i + 1).map((day) {
              return DropdownMenuItem(
                value: day,
                child: Text('$day 日'),
              );
            }).toList(),
            onChanged: (v) => onChanged(v!),
          ),
        ),
      ],
    );
  }

  Widget _buildIconColorSelector() {
    final icons = [
      Icons.credit_card,
      Icons.credit_score,
      Icons.payment,
      Icons.account_balance,
      Icons.wallet,
      Icons.attach_money,
    ];

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择图标'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: icons.map((icon) {
              final isSelected = icon == _selectedIcon;
              return InkWell(
                onTap: () => setState(() => _selectedIcon = icon),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? _selectedColor.withOpacity(0.2) : Colors.white,
                    border: Border.all(
                      color: isSelected ? _selectedColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: isSelected ? _selectedColor : Colors.grey),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('选择颜色'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              final isSelected = color == _selectedColor;
              return InkWell(
                onTap: () => setState(() => _selectedColor = color),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _saveCard() {
    if (!_formKey.currentState!.validate()) return;

    final creditLimit = double.parse(_limitController.text);
    final usedAmount = double.tryParse(_usedController.text) ?? 0;

    final card = CreditCard(
      id: widget.card?.id ?? const Uuid().v4(),
      name: _nameController.text,
      creditLimit: creditLimit,
      usedAmount: usedAmount,
      billDay: _billDay,
      paymentDueDay: _paymentDueDay,
      currentBill: widget.card?.currentBill ?? 0,
      minPayment: widget.card?.minPayment ?? 0,
      lastBillDate: widget.card?.lastBillDate,
      icon: _selectedIcon,
      color: _selectedColor,
      bankName: _selectedBank,
      cardNumber: _cardNumberController.text.isNotEmpty ? _cardNumberController.text : null,
      isEnabled: widget.card?.isEnabled ?? true,
      createdAt: widget.card?.createdAt ?? DateTime.now(),
    );

    if (isEditing) {
      ref.read(creditCardProvider.notifier).updateCreditCard(card);
    } else {
      ref.read(creditCardProvider.notifier).addCreditCard(card);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEditing ? '信用卡已更新' : '信用卡已添加')),
    );
  }
}
