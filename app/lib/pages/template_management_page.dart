import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../providers/template_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../services/category_localization_service.dart';
import '../extensions/extensions.dart';
import '../theme/app_theme.dart';

class TemplateManagementPage extends ConsumerWidget {
  const TemplateManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('模板管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showTemplateDialog(context, ref),
          ),
        ],
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无模板',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showTemplateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('创建模板'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return _buildTemplateItem(context, ref, template);
              },
            ),
    );
  }

  Widget _buildTemplateItem(
    BuildContext context,
    WidgetRef ref,
    TransactionTemplate template,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: template.color.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(template.icon, color: template.color),
        ),
        title: Text(
          template.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${template.typeName} · ${template.category.localizedCategoryName}',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
            if (template.useCount > 0)
              Text(
                '已使用 ${template.useCount} 次',
                style: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (template.amount != null)
              Text(
                '¥${template.amount!.toStringAsFixed(2)}',
                style: TextStyle(
                  color: template.type == TransactionType.income
                      ? AppColors.income
                      : AppColors.expense,
                  fontWeight: FontWeight.bold,
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showTemplateDialog(context, ref, template: template);
                } else if (value == 'delete') {
                  _confirmDelete(context, ref, template);
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
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionTemplate template,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除模板"${template.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(templateProvider.notifier).deleteTemplate(template.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTemplateDialog(
    BuildContext context,
    WidgetRef ref, {
    TransactionTemplate? template,
  }) {
    showDialog(
      context: context,
      builder: (context) => _TemplateDialog(template: template),
    );
  }
}

class _TemplateDialog extends ConsumerStatefulWidget {
  final TransactionTemplate? template;

  const _TemplateDialog({this.template});

  @override
  ConsumerState<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<_TemplateDialog> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late TransactionType _selectedType;
  String? _selectedCategory;
  String? _selectedAccountId;
  late Color _selectedColor;
  late IconData _selectedIcon;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.brown,
  ];

  final List<IconData> _icons = [
    Icons.restaurant,
    Icons.coffee,
    Icons.shopping_cart,
    Icons.directions_bus,
    Icons.subway,
    Icons.local_taxi,
    Icons.home,
    Icons.movie,
    Icons.sports_esports,
    Icons.fitness_center,
    Icons.medical_services,
    Icons.school,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _amountController = TextEditingController(
      text: widget.template?.amount?.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.template?.note ?? '');
    _selectedType = widget.template?.type ?? TransactionType.expense;
    _selectedCategory = widget.template?.category;
    _selectedAccountId = widget.template?.accountId;
    _selectedColor = widget.template?.color ?? Colors.blue;
    _selectedIcon = widget.template?.icon ?? Icons.receipt;
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
      title: Text(widget.template == null ? '创建模板' : '编辑模板'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '模板名称',
                hintText: '例如：早餐',
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
                  _selectedCategory = null; // Reset category
                });
              },
            ),
            const SizedBox(height: 16),

            // Amount (optional)
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '默认金额（可选）',
                prefixText: '¥ ',
                hintText: '留空则每次输入',
              ),
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: '分类',
              ),
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
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 16),

            // Account
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
              decoration: const InputDecoration(
                labelText: '账户',
              ),
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
              onChanged: (value) {
                setState(() => _selectedAccountId = value);
              },
            ),
            const SizedBox(height: 16),

            // Note
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
              ),
            ),
            const SizedBox(height: 16),

            // Color
            Text('颜色', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: color, blurRadius: 8)]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Icon
            Text('图标', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((icon) {
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withValues(alpha:0.2)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: _selectedColor, width: 2)
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? _selectedColor
                          : theme.colorScheme.outline,
                    ),
                  ),
                );
              }).toList(),
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
          onPressed: _saveTemplate,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _saveTemplate() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入模板名称')),
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

    final amountText = _amountController.text.trim();
    double? amount;
    if (amountText.isNotEmpty) {
      amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入有效的金额')),
        );
        return;
      }
    }

    final template = TransactionTemplate(
      id: widget.template?.id ?? const Uuid().v4(),
      name: name,
      type: _selectedType,
      amount: amount,
      category: _selectedCategory!,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      accountId: _selectedAccountId!,
      icon: _selectedIcon,
      color: _selectedColor,
      useCount: widget.template?.useCount ?? 0,
      createdAt: widget.template?.createdAt ?? DateTime.now(),
      lastUsedAt: widget.template?.lastUsedAt,
    );

    if (widget.template == null) {
      ref.read(templateProvider.notifier).addTemplate(template);
    } else {
      ref.read(templateProvider.notifier).updateTemplate(template);
    }

    Navigator.pop(context);
  }
}
