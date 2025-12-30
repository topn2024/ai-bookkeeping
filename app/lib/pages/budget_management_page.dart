import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/budget.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/ledger_provider.dart';

class BudgetManagementPage extends ConsumerStatefulWidget {
  const BudgetManagementPage({super.key});

  @override
  ConsumerState<BudgetManagementPage> createState() => _BudgetManagementPageState();
}

class _BudgetManagementPageState extends ConsumerState<BudgetManagementPage> {
  @override
  Widget build(BuildContext context) {
    final budgetUsages = ref.watch(allBudgetUsagesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('预算管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showBudgetDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 钱龄卡片
          _buildMoneyAgeCard(context),
          // 预算列表
          Expanded(
            child: budgetUsages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无预算',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击右上角添加预算',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: budgetUsages.length,
                    itemBuilder: (context, index) {
                      final usage = budgetUsages[index];
                      return _buildBudgetCard(context, usage);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyAgeCard(BuildContext context) {
    final moneyAge = ref.watch(moneyAgeProvider);
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    switch (moneyAge.status) {
      case MoneyAgeStatus.excellent:
        statusColor = Colors.green;
        statusIcon = Icons.sentiment_very_satisfied;
      case MoneyAgeStatus.good:
        statusColor = Colors.blue;
        statusIcon = Icons.sentiment_satisfied;
      case MoneyAgeStatus.fair:
        statusColor = Colors.orange;
        statusIcon = Icons.sentiment_neutral;
      case MoneyAgeStatus.poor:
        statusColor = Colors.red;
        statusIcon = Icons.sentiment_dissatisfied;
    }

    IconData? trendIcon;
    Color? trendColor;
    if (moneyAge.trend == 'up') {
      trendIcon = Icons.trending_up;
      trendColor = Colors.green;
    } else if (moneyAge.trend == 'down') {
      trendIcon = Icons.trending_down;
      trendColor = Colors.red;
    } else if (moneyAge.trend == 'stable') {
      trendIcon = Icons.trending_flat;
      trendColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: InkWell(
        onTap: () => _showMoneyAgeDetails(context, moneyAge),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha:0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '钱龄',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            moneyAge.statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (trendIcon != null) ...[
                          const SizedBox(width: 8),
                          Icon(trendIcon, color: trendColor, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${moneyAge.days} 天',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      moneyAge.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoneyAgeDetails(BuildContext context, MoneyAge moneyAge) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    '什么是钱龄？',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '钱龄（Age of Money）是YNAB预算法的核心指标之一。它表示您当前花费的钱是多少天前赚到的。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _buildMoneyAgeInfoRow(
                '优秀',
                '≥ 30天',
                '资金周转非常健康',
                Colors.green,
              ),
              _buildMoneyAgeInfoRow(
                '良好',
                '14-29天',
                '资金周转较好',
                Colors.blue,
              ),
              _buildMoneyAgeInfoRow(
                '一般',
                '7-13天',
                '建议增加储蓄缓冲',
                Colors.orange,
              ),
              _buildMoneyAgeInfoRow(
                '需改善',
                '< 7天',
                '可能在花费刚收到的钱',
                Colors.red,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '提高钱龄的方法：控制支出、增加收入、建立应急储蓄',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoneyAgeInfoRow(
      String status, String range, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            range,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(BuildContext context, BudgetUsage usage) {
    final theme = Theme.of(context);
    final budget = usage.budget;

    Color progressColor;
    if (usage.isOverBudget) {
      progressColor = Colors.red;
    } else if (usage.isNearLimit) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: budget.color.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(budget.icon, color: budget.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Text(
                            budget.periodName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          if (budget.budgetType == BudgetType.zeroBased) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '零基',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
                          if (budget.enableCarryover) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '结转',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showBudgetDialog(context, budget: budget);
                    } else if (value == 'delete') {
                      _confirmDelete(context, budget);
                    } else if (value == 'toggle') {
                      ref.read(budgetProvider.notifier).toggleBudget(budget.id);
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
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(budget.isEnabled ? Icons.pause : Icons.play_arrow),
                          const SizedBox(width: 8),
                          Text(budget.isEnabled ? '暂停' : '启用'),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已使用 ¥${usage.spent.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '预算 ¥${budget.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usage.percentage.clamp(0, 1),
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(usage.percentage * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  usage.remaining >= 0
                      ? '剩余 ¥${usage.remaining.toStringAsFixed(2)}'
                      : '超支 ¥${(-usage.remaining).toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: usage.remaining >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Budget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除预算"${budget.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(budgetProvider.notifier).deleteBudget(budget.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, {Budget? budget}) {
    showDialog(
      context: context,
      builder: (context) => _BudgetDialog(budget: budget),
    );
  }
}

class _BudgetDialog extends ConsumerStatefulWidget {
  final Budget? budget;

  const _BudgetDialog({this.budget});

  @override
  ConsumerState<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends ConsumerState<_BudgetDialog> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late BudgetPeriod _selectedPeriod;
  String? _selectedCategoryId;
  late Color _selectedColor;
  late IconData _selectedIcon;
  late bool _enableCarryover;
  late bool _carryoverSurplusOnly;
  late BudgetType _budgetType;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  final List<IconData> _icons = [
    Icons.account_balance_wallet,
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.directions_car,
    Icons.home,
    Icons.local_hospital,
    Icons.school,
    Icons.sports_esports,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.budget?.name ?? '');
    _amountController = TextEditingController(
      text: widget.budget?.amount.toString() ?? '',
    );
    _selectedPeriod = widget.budget?.period ?? BudgetPeriod.monthly;
    _selectedCategoryId = widget.budget?.categoryId;
    _selectedColor = widget.budget?.color ?? Colors.blue;
    _selectedIcon = widget.budget?.icon ?? Icons.account_balance_wallet;
    _enableCarryover = widget.budget?.enableCarryover ?? false;
    _carryoverSurplusOnly = widget.budget?.carryoverSurplusOnly ?? true;
    _budgetType = widget.budget?.budgetType ?? BudgetType.traditional;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final expenseCategories = categories.where((c) => c.isExpense).toList();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.budget == null ? '添加预算' : '编辑预算'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '预算名称',
                hintText: '例如：月度总预算',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '预算金额',
                prefixText: '¥ ',
              ),
            ),
            const SizedBox(height: 16),
            Text('预算周期', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: BudgetPeriod.values.map((period) {
                final isSelected = _selectedPeriod == period;
                String label;
                switch (period) {
                  case BudgetPeriod.daily:
                    label = '每日';
                  case BudgetPeriod.weekly:
                    label = '每周';
                  case BudgetPeriod.monthly:
                    label = '每月';
                  case BudgetPeriod.yearly:
                    label = '每年';
                }
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPeriod = period);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('预算类型', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: BudgetType.values.map((type) {
                final isSelected = _budgetType == type;
                String label;
                String hint;
                switch (type) {
                  case BudgetType.traditional:
                    label = '传统预算';
                    hint = '设定固定预算额度';
                  case BudgetType.zeroBased:
                    label = '零基预算';
                    hint = 'YNAB式，为每一分钱分配用途';
                }
                return Tooltip(
                  message: hint,
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _budgetType = type);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('关联分类（可选）', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                hintText: '全部分类',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('全部分类'),
                ),
                ...expenseCategories.map((category) => DropdownMenuItem(
                  value: category.id,
                  child: Row(
                    children: [
                      Icon(category.icon, size: 20, color: category.color),
                      const SizedBox(width: 8),
                      Text(category.localizedName),
                    ],
                  ),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedCategoryId = value);
              },
            ),
            const SizedBox(height: 16),
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
                      color: isSelected ? _selectedColor : theme.colorScheme.outline,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text('预算结转', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _enableCarryover,
              onChanged: (value) {
                setState(() => _enableCarryover = value);
              },
              title: const Text('启用预算结转'),
              subtitle: const Text('将剩余/超支金额结转至下一周期'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_enableCarryover) ...[
              const SizedBox(height: 8),
              Text('结转模式', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              RadioListTile<bool>(
                value: true,
                groupValue: _carryoverSurplusOnly,
                onChanged: (value) {
                  setState(() => _carryoverSurplusOnly = value!);
                },
                title: const Text('仅结转剩余'),
                subtitle: const Text('只有剩余金额会结转，超支不累计'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: _carryoverSurplusOnly,
                onChanged: (value) {
                  setState(() => _carryoverSurplusOnly = value!);
                },
                title: const Text('结转所有'),
                subtitle: const Text('剩余和超支金额都会结转'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _saveBudget,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _saveBudget() {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入预算名称')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的预算金额')),
      );
      return;
    }

    final currentLedgerId = ref.read(ledgerProvider.notifier).currentLedgerId;

    final budget = Budget(
      id: widget.budget?.id ?? const Uuid().v4(),
      name: name,
      amount: amount,
      period: _selectedPeriod,
      categoryId: _selectedCategoryId,
      ledgerId: currentLedgerId,
      icon: _selectedIcon,
      color: _selectedColor,
      isEnabled: widget.budget?.isEnabled ?? true,
      createdAt: widget.budget?.createdAt ?? DateTime.now(),
      budgetType: _budgetType,
      enableCarryover: _enableCarryover,
      carryoverSurplusOnly: _carryoverSurplusOnly,
    );

    if (widget.budget == null) {
      ref.read(budgetProvider.notifier).addBudget(budget);
    } else {
      ref.read(budgetProvider.notifier).updateBudget(budget);
    }

    Navigator.pop(context);
  }
}
