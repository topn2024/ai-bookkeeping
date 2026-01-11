import 'package:flutter/material.dart';

/// Batch confirmation widget for multi-transaction split (第23章多笔拆分记账批量确认)
class BatchTransactionConfirmWidget extends StatefulWidget {
  final List<SplitTransaction> transactions;
  final ValueChanged<List<SplitTransaction>> onTransactionsChanged;
  final VoidCallback onConfirmAll;
  final VoidCallback? onCancel;

  const BatchTransactionConfirmWidget({
    super.key,
    required this.transactions,
    required this.onTransactionsChanged,
    required this.onConfirmAll,
    this.onCancel,
  });

  @override
  State<BatchTransactionConfirmWidget> createState() => _BatchTransactionConfirmWidgetState();
}

class _BatchTransactionConfirmWidgetState extends State<BatchTransactionConfirmWidget> {
  late List<SplitTransaction> _transactions;
  Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
    // Select all by default
    _selectedIndices = Set.from(List.generate(_transactions.length, (i) => i));
  }

  // ignore: unused_element
  double get _totalAmount =>
      _transactions.fold(0.0, (sum, t) => sum + t.amount);

  double get _selectedAmount =>
      _selectedIndices.fold(0.0, (sum, i) => sum + _transactions[i].amount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildHeader(theme),
          ),

          // Transaction list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                return _buildTransactionItem(theme, index);
              },
            ),
          ),

          // Summary and actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFooter(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '拆分记账确认',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '共 ${_transactions.length} 笔交易，已选 ${_selectedIndices.length} 笔',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              if (_selectedIndices.length == _transactions.length) {
                _selectedIndices.clear();
              } else {
                _selectedIndices = Set.from(List.generate(_transactions.length, (i) => i));
              }
            });
          },
          child: Text(
            _selectedIndices.length == _transactions.length ? '取消全选' : '全选',
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(ThemeData theme, int index) {
    final transaction = _transactions[index];
    final isSelected = _selectedIndices.contains(index);

    return Dismissible(
      key: ValueKey('transaction_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() {
          _transactions.removeAt(index);
          _selectedIndices.remove(index);
          // Update indices after removal
          _selectedIndices = _selectedIndices
              .map((i) => i > index ? i - 1 : i)
              .toSet();
        });
        widget.onTransactionsChanged(_transactions);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIndices.remove(index);
              } else {
                _selectedIndices.add(index);
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedIndices.add(index);
                      } else {
                        _selectedIndices.remove(index);
                      }
                    });
                  },
                ),

                // Category icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(transaction.category),
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            transaction.category,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildEditableCategory(theme, index),
                        ],
                      ),
                      if (transaction.description != null)
                        Text(
                          transaction.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Amount
                _buildEditableAmount(theme, index),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableCategory(ThemeData theme, int index) {
    return GestureDetector(
      onTap: () => _showCategoryPicker(index),
      child: Icon(
        Icons.edit,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildEditableAmount(ThemeData theme, int index) {
    final transaction = _transactions[index];

    return GestureDetector(
      onTap: () => _showAmountEditor(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¥${transaction.amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: transaction.isExpense ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        // Summary row
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已选金额',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '¥${_selectedAmount.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action buttons
        Row(
          children: [
            if (widget.onCancel != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: const Text('取消'),
                ),
              ),
            if (widget.onCancel != null) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _selectedIndices.isNotEmpty
                    ? () {
                        // Only confirm selected transactions
                        final selected = _selectedIndices
                            .map((i) => _transactions[i])
                            .toList();
                        widget.onTransactionsChanged(selected);
                        widget.onConfirmAll();
                      }
                    : null,
                icon: const Icon(Icons.check_circle),
                label: Text('确认 ${_selectedIndices.length} 笔'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCategoryPicker(int index) {
    final categories = [
      '餐饮', '交通', '购物', '娱乐', '住房',
      '医疗', '教育', '通讯', '其他',
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '选择分类',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((category) {
                  return ChoiceChip(
                    label: Text(category),
                    selected: _transactions[index].category == category,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _transactions[index] = _transactions[index].copyWith(
                            category: category,
                          );
                        });
                        widget.onTransactionsChanged(_transactions);
                        Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showAmountEditor(int index) {
    final controller = TextEditingController(
      text: _transactions[index].amount.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '¥ ',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final amount = double.tryParse(controller.text);
                      if (amount != null && amount > 0) {
                        setState(() {
                          _transactions[index] = _transactions[index].copyWith(
                            amount: amount,
                          );
                        });
                        widget.onTransactionsChanged(_transactions);
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    final iconMap = {
      '餐饮': Icons.restaurant,
      '交通': Icons.directions_car,
      '购物': Icons.shopping_bag,
      '娱乐': Icons.movie,
      '住房': Icons.home,
      '医疗': Icons.medical_services,
      '教育': Icons.school,
      '通讯': Icons.phone,
      '其他': Icons.category,
    };
    return iconMap[category] ?? Icons.category;
  }
}

/// Split transaction model
class SplitTransaction {
  final String id;
  final double amount;
  final bool isExpense;
  final String category;
  final String? description;
  final DateTime date;

  SplitTransaction({
    required this.id,
    required this.amount,
    required this.isExpense,
    required this.category,
    this.description,
    required this.date,
  });

  SplitTransaction copyWith({
    String? id,
    double? amount,
    bool? isExpense,
    String? category,
    String? description,
    DateTime? date,
  }) {
    return SplitTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      isExpense: isExpense ?? this.isExpense,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }
}

/// Add transaction FAB for batch mode
class AddTransactionFAB extends StatelessWidget {
  final VoidCallback onTap;
  final int currentCount;

  const AddTransactionFAB({
    super.key,
    required this.onTap,
    required this.currentCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloatingActionButton.extended(
      onPressed: onTap,
      icon: const Icon(Icons.add),
      label: Text('添加第 ${currentCount + 1} 笔'),
      backgroundColor: theme.colorScheme.secondaryContainer,
      foregroundColor: theme.colorScheme.onSecondaryContainer,
    );
  }
}
