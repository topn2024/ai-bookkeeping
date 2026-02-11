import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../providers/recurring_provider.dart';
import '../providers/category_provider.dart';
import '../services/category_localization_service.dart';
import '../providers/account_provider.dart';
import '../extensions/extensions.dart';
import '../theme/app_theme.dart';

class RecurringManagementPage extends ConsumerWidget {
  const RecurringManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurrings = ref.watch(recurringProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('定时记账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showRecurringDialog(context, ref),
          ),
        ],
      ),
      body: recurrings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无定时记账',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '添加定时任务，自动记录周期性账目',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => _showRecurringDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('添加定时记账'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recurrings.length,
              itemBuilder: (context, index) {
                return _buildRecurringItem(context, ref, recurrings[index]);
              },
            ),
    );
  }

  Widget _buildRecurringItem(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction recurring,
  ) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: recurring.color.withValues(alpha:recurring.isEnabled ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    recurring.icon,
                    color: recurring.isEnabled
                        ? recurring.color
                        : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            recurring.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: recurring.isEnabled
                                  ? null
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          if (!recurring.isEnabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '已暂停',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${recurring.typeName} · ${recurring.category.localizedCategoryName}',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '¥${recurring.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: recurring.type == TransactionType.income
                        ? AppColors.income
                        : AppColors.expense,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.repeat,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  recurring.frequencyName,
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                if (recurring.nextExecuteAt != null) ...[
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '下次: ${dateFormat.format(recurring.nextExecuteAt!)}',
                    style: TextStyle(
                      color: theme.colorScheme.outline,
                      fontSize: 13,
                    ),
                  ),
                ],
                const Spacer(),
                Switch(
                  value: recurring.isEnabled,
                  onChanged: (value) {
                    ref.read(recurringProvider.notifier).toggleRecurring(recurring.id);
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showRecurringDialog(context, ref, recurring: recurring);
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref, recurring);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction recurring,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除定时任务"${recurring.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(recurringProvider.notifier).deleteRecurring(recurring.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRecurringDialog(
    BuildContext context,
    WidgetRef ref, {
    RecurringTransaction? recurring,
  }) {
    showDialog(
      context: context,
      builder: (context) => _RecurringDialog(recurring: recurring),
    );
  }
}

class _RecurringDialog extends ConsumerStatefulWidget {
  final RecurringTransaction? recurring;

  const _RecurringDialog({this.recurring});

  @override
  ConsumerState<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends ConsumerState<_RecurringDialog> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late TransactionType _selectedType;
  String? _selectedCategory;
  String? _selectedAccountId;
  late RecurringFrequency _selectedFrequency;
  late int _dayOfWeek;
  late int _dayOfMonth;
  late int _monthOfYear;
  late DateTime _startDate;
  DateTime? _endDate;
  late Color _selectedColor;
  late IconData _selectedIcon;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
  ];


  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.recurring?.name ?? '');
    _amountController = TextEditingController(
      text: widget.recurring?.amount.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.recurring?.note ?? '');
    _selectedType = widget.recurring?.type ?? TransactionType.expense;
    _selectedCategory = widget.recurring?.category;
    _selectedAccountId = widget.recurring?.accountId;
    _selectedFrequency = widget.recurring?.frequency ?? RecurringFrequency.monthly;
    _dayOfWeek = widget.recurring?.dayOfWeek ?? 1;
    _dayOfMonth = widget.recurring?.dayOfMonth ?? DateTime.now().day;
    _monthOfYear = widget.recurring?.monthOfYear ?? DateTime.now().month;
    _startDate = widget.recurring?.startDate ?? DateTime.now();
    _endDate = widget.recurring?.endDate;
    _selectedColor = widget.recurring?.color ?? Colors.blue;
    _selectedIcon = widget.recurring?.icon ?? Icons.repeat;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final accounts = ref.watch(accountProvider);
    final theme = Theme.of(context);

    final filteredCategories = categories
        .where((c) => _selectedType == TransactionType.expense
            ? c.isExpense
            : !c.isExpense)
        .toList();

    return AlertDialog(
      title: Text(widget.recurring == null ? '添加定时记账' : '编辑定时记账'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：房租、工资',
              ),
            ),
            const SizedBox(height: 16),

            // Type
            Text('交易类型', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('支出'),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('收入'),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedType = selected.first;
                  _selectedCategory = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
              ),
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: '分类'),
              items: filteredCategories.map((category) {
                return DropdownMenuItem(
                  value: category.name,
                  child: Row(
                    children: [
                      Icon(category.icon, size: 20, color: category.color),
                      const SizedBox(width: 8),
                      Text(category.localizedName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 16),

            // Account
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
              decoration: const InputDecoration(labelText: '账户'),
              items: accounts.map((account) {
                return DropdownMenuItem(
                  value: account.id,
                  child: Row(
                    children: [
                      Icon(account.icon, size: 20, color: account.color),
                      const SizedBox(width: 8),
                      Text(account.localizedName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedAccountId = value),
            ),
            const SizedBox(height: 16),

            // Frequency
            Text('重复周期', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<RecurringFrequency>(
              initialValue: _selectedFrequency,
              items: RecurringFrequency.values.map((freq) {
                String label;
                switch (freq) {
                  case RecurringFrequency.daily:
                    label = '每天';
                  case RecurringFrequency.weekly:
                    label = '每周';
                  case RecurringFrequency.monthly:
                    label = '每月';
                  case RecurringFrequency.yearly:
                    label = '每年';
                }
                return DropdownMenuItem(value: freq, child: Text(label));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedFrequency = value);
              },
            ),
            const SizedBox(height: 16),

            // Day selection based on frequency
            if (_selectedFrequency == RecurringFrequency.weekly) ...[
              Text('每周几', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final names = ['一', '二', '三', '四', '五', '六', '日'];
                  return ChoiceChip(
                    label: Text(names[index]),
                    selected: _dayOfWeek == day,
                    onSelected: (selected) {
                      if (selected) setState(() => _dayOfWeek = day);
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedFrequency == RecurringFrequency.monthly) ...[
              Text('每月几号', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _dayOfMonth,
                items: List.generate(31, (index) {
                  return DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1}日'),
                  );
                }),
                onChanged: (value) {
                  if (value != null) setState(() => _dayOfMonth = value);
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedFrequency == RecurringFrequency.yearly) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _monthOfYear,
                      decoration: const InputDecoration(labelText: '月份'),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}月'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) setState(() => _monthOfYear = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _dayOfMonth,
                      decoration: const InputDecoration(labelText: '日期'),
                      items: List.generate(31, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}日'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) setState(() => _dayOfMonth = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Note
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
            ),
            const SizedBox(height: 16),

            // Color & Icon
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('颜色', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _colors.map((color) {
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: _selectedColor == color
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                                boxShadow: _selectedColor == color
                                    ? [BoxShadow(color: color, blurRadius: 4)]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _saveRecurring,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _saveRecurring() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入名称')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择账户')),
      );
      return;
    }

    final recurring = RecurringTransaction(
      id: widget.recurring?.id ?? const Uuid().v4(),
      name: name,
      type: _selectedType,
      amount: amount,
      category: _selectedCategory!,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      accountId: _selectedAccountId!,
      frequency: _selectedFrequency,
      dayOfWeek: _dayOfWeek,
      dayOfMonth: _dayOfMonth,
      monthOfYear: _monthOfYear,
      startDate: _startDate,
      endDate: _endDate,
      isEnabled: widget.recurring?.isEnabled ?? true,
      lastExecutedAt: widget.recurring?.lastExecutedAt,
      icon: _selectedIcon,
      color: _selectedColor,
      createdAt: widget.recurring?.createdAt ?? DateTime.now(),
    );

    if (widget.recurring == null) {
      ref.read(recurringProvider.notifier).addRecurring(recurring);
    } else {
      ref.read(recurringProvider.notifier).updateRecurring(recurring);
    }

    Navigator.pop(context);
  }
}
