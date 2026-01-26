import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/debt.dart';
import '../providers/debt_provider.dart';
import '../utils/amount_validator.dart';
import 'debt_simulator_page.dart';

class DebtManagementPage extends ConsumerWidget {
  const DebtManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtProvider);
    final summary = ref.watch(debtSummaryProvider);
    final activeDebts = debts.where((d) => !d.isCompleted).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('债务管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: activeDebts.isNotEmpty
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DebtSimulatorPage(),
                      ),
                    )
                : null,
            tooltip: '还款模拟器',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showCompletedDebts(context, ref, debts),
            tooltip: '已还清',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDebtDialog(context, ref),
          ),
        ],
      ),
      body: activeDebts.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(context, summary, theme),
                const SizedBox(height: 16),
                _buildStrategySelector(context, ref),
                const SizedBox(height: 16),
                ...activeDebts.map((debt) => _buildDebtCard(context, ref, debt, theme)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDebtDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加债务'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green[400]),
          const SizedBox(height: 16),
          Text(
            '太棒了！没有债务',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '保持良好的财务习惯',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDebtDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('记录债务'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DebtSummary summary, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '债务概览',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '总债务',
                    '¥${summary.totalBalance.toStringAsFixed(0)}',
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '已还金额',
                    '¥${summary.totalPaidAmount.toStringAsFixed(0)}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '月还款额',
                    '¥${summary.totalMinimumPayment.toStringAsFixed(0)}',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.overallProgress,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  summary.overallProgress >= 1 ? Colors.green : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '还款进度: ${(summary.overallProgress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Row(
                  children: [
                    _buildStatChip('进行中', summary.activeCount, Colors.orange),
                    const SizedBox(width: 8),
                    _buildStatChip('已还清', summary.completedCount, Colors.green),
                  ],
                ),
              ],
            ),
            if (summary.totalMonthlyInterest > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      '每月利息: ¥${summary.totalMonthlyInterest.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrategySelector(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _buildStrategyButton(
                context,
                '雪球法',
                '先还最小余额',
                Icons.ac_unit,
                Colors.blue,
                () => _showStrategyInfo(context, RepaymentStrategy.snowball),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStrategyButton(
                context,
                '雪崩法',
                '先还最高利率',
                Icons.trending_down,
                Colors.orange,
                () => _showStrategyInfo(context, RepaymentStrategy.avalanche),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha:0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showStrategyInfo(BuildContext context, RepaymentStrategy strategy) {
    final isSnowball = strategy == RepaymentStrategy.snowball;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSnowball ? Icons.ac_unit : Icons.trending_down,
              color: isSnowball ? Colors.blue : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(isSnowball ? '雪球法' : '雪崩法'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSnowball
                  ? '雪球法优先偿还余额最小的债务，快速减少债务数量，获得心理成就感。'
                  : '雪崩法优先偿还利率最高的债务，可以节省最多的利息支出。',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              '适合人群:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              isSnowball
                  ? '• 需要快速看到还债成果的人\n• 债务数量较多的人\n• 需要心理激励的人'
                  : '• 注重利息节省的人\n• 有高利率债务的人\n• 能坚持长期计划的人',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解了'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
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

  Widget _buildDebtCard(BuildContext context, WidgetRef ref, Debt debt, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDebtDetail(context, ref, debt),
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
                      color: debt.color.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(debt.icon, color: debt.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${debt.typeDisplayName} · 利率 ${debt.interestRateDisplay}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${debt.currentBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        '剩余',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: debt.progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(debt.color),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已还 ${debt.progressPercent}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '月供 ¥${debt.minimumPayment.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              if (debt.daysUntilPayment <= 7) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: debt.daysUntilPayment <= 3
                        ? Colors.red.withValues(alpha:0.1)
                        : Colors.orange.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alarm,
                        size: 14,
                        color: debt.daysUntilPayment <= 3 ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        debt.daysUntilPayment == 0
                            ? '今天还款'
                            : '${debt.daysUntilPayment}天后还款',
                        style: TextStyle(
                          fontSize: 12,
                          color: debt.daysUntilPayment <= 3 ? Colors.red : Colors.orange,
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

  void _showAddDebtDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddDebtSheet(ref: ref),
    );
  }

  void _showDebtDetail(BuildContext context, WidgetRef ref, Debt debt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DebtDetailPage(debtId: debt.id),
      ),
    );
  }

  void _showCompletedDebts(BuildContext context, WidgetRef ref, List<Debt> debts) {
    final completed = debts.where((d) => d.isCompleted).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    '已还清的债务',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: completed.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            '还没有还清的债务',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: completed.length,
                      itemBuilder: (context, index) {
                        final debt = completed[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.check, color: Colors.green),
                            ),
                            title: Text(debt.name),
                            subtitle: Text(
                              '原始金额: ¥${debt.originalAmount.toStringAsFixed(0)}',
                            ),
                            trailing: debt.completedAt != null
                                ? Text(
                                    '${debt.completedAt!.month}/${debt.completedAt!.day}还清',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDebtSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final Debt? editDebt;

  const _AddDebtSheet({required this.ref, this.editDebt});

  @override
  ConsumerState<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<_AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _balanceController = TextEditingController();
  final _interestController = TextEditingController();
  final _minPaymentController = TextEditingController();

  DebtType _selectedType = DebtType.creditCard;
  int _paymentDay = 1;
  IconData _selectedIcon = Icons.credit_card;
  Color _selectedColor = Colors.red;

  @override
  void initState() {
    super.initState();
    if (widget.editDebt != null) {
      final debt = widget.editDebt!;
      _nameController.text = debt.name;
      _amountController.text = debt.originalAmount.toString();
      _balanceController.text = debt.currentBalance.toString();
      _interestController.text = (debt.interestRate * 100).toString();
      _minPaymentController.text = debt.minimumPayment.toString();
      _selectedType = debt.type;
      _paymentDay = debt.paymentDay;
      _selectedIcon = debt.icon;
      _selectedColor = debt.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _balanceController.dispose();
    _interestController.dispose();
    _minPaymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.editDebt == null ? '添加债务' : '编辑债务',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 债务类型选择
              const Text('债务类型', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: DebtTemplates.templates.length,
                  itemBuilder: (context, index) {
                    final template = DebtTemplates.templates[index];
                    final type = template['type'] as DebtType;
                    final isSelected = _selectedType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedType = type;
                            _selectedIcon = template['icon'] as IconData;
                            _selectedColor = template['color'] as Color;
                            if (_nameController.text.isEmpty) {
                              _nameController.text = template['name'] as String;
                            }
                            if (_interestController.text.isEmpty) {
                              _interestController.text =
                                  ((template['interestRate'] as double) * 100).toString();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (template['color'] as Color).withValues(alpha:0.1)
                                : Colors.grey[100],
                            border: Border.all(
                              color: isSelected
                                  ? template['color'] as Color
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                template['icon'] as IconData,
                                color: template['color'] as Color,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                template['name'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 债务名称
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '债务名称',
                  hintText: '例如: 招行信用卡',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),

              // 原始金额和当前余额
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '原始金额',
                        prefixText: '¥ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true) return '请输入金额';
                        return AmountValidator.validateText(value!);
                      },
                      onChanged: (value) {
                        if (_balanceController.text.isEmpty && value.isNotEmpty) {
                          _balanceController.text = value;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _balanceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '当前余额',
                        prefixText: '¥ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true) return '请输入余额';
                        return AmountValidator.validateText(value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 年利率和最低还款
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _interestController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '年利率',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true) return '请输入利率';
                        final rate = double.tryParse(value!);
                        if (rate == null || rate < 0 || rate > 100) {
                          return '请输入0-100之间的利率';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minPaymentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '月还款额',
                        prefixText: '¥ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true) return '请输入还款额';
                        return AmountValidator.validateText(value!, allowZero: true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 还款日
              Row(
                children: [
                  const Text('每月还款日: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _paymentDay,
                    items: List.generate(28, (i) => i + 1)
                        .map((day) => DropdownMenuItem(
                              value: day,
                              child: Text('$day日'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _paymentDay = value);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveDebt,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(widget.editDebt == null ? '添加债务' : '保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveDebt() {
    if (!_formKey.currentState!.validate()) return;

    final debt = Debt(
      id: widget.editDebt?.id ?? const Uuid().v4(),
      name: _nameController.text,
      type: _selectedType,
      originalAmount: double.parse(_amountController.text),
      currentBalance: double.parse(_balanceController.text),
      interestRate: double.parse(_interestController.text) / 100,
      minimumPayment: double.parse(_minPaymentController.text),
      startDate: widget.editDebt?.startDate ?? DateTime.now(),
      paymentDay: _paymentDay,
      icon: _selectedIcon,
      color: _selectedColor,
      createdAt: widget.editDebt?.createdAt ?? DateTime.now(),
    );

    if (widget.editDebt == null) {
      widget.ref.read(debtProvider.notifier).addDebt(debt);
    } else {
      widget.ref.read(debtProvider.notifier).updateDebt(debt);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.editDebt == null ? '债务已添加' : '债务已更新'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// 债务详情页面
class DebtDetailPage extends ConsumerStatefulWidget {
  final String debtId;

  const DebtDetailPage({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailPage> createState() => _DebtDetailPageState();
}

class _DebtDetailPageState extends ConsumerState<DebtDetailPage> {
  List<DebtPayment> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final payments = await ref.read(debtProvider.notifier).getPaymentHistory(widget.debtId);
      if (mounted) {
        setState(() => _payments = payments);
      }
    } catch (e) {
      debugPrint('加载还款记录失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = ref.watch(debtProvider.notifier).getById(widget.debtId);
    if (debt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('债务详情')),
        body: const Center(child: Text('债务不存在')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editDebt(context, debt),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'complete') {
                _markAsCompleted(debt);
              } else if (value == 'delete') {
                _deleteDebt(debt);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('标记为已还清'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除债务'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 债务概览卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: debt.color.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(debt.icon, color: debt.color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '¥${debt.currentBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const Text('剩余待还'),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: debt.progress,
                      minHeight: 12,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(debt.color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已还 ${debt.progressPercent}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 债务信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '债务信息',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('债务类型', debt.typeDisplayName),
                  _buildInfoRow('原始金额', '¥${debt.originalAmount.toStringAsFixed(2)}'),
                  _buildInfoRow('已还金额', '¥${debt.paidAmount.toStringAsFixed(2)}'),
                  _buildInfoRow('年利率', debt.interestRateDisplay),
                  _buildInfoRow('月还款额', '¥${debt.minimumPayment.toStringAsFixed(2)}'),
                  _buildInfoRow('月利息', '¥${debt.monthlyInterest.toStringAsFixed(2)}'),
                  _buildInfoRow('还款日', '每月${debt.paymentDay}日'),
                  if (debt.estimatedPayoffMonths != null)
                    _buildInfoRow('预计还清', '${debt.estimatedPayoffMonths}个月后'),
                  if (debt.totalInterestEstimate != null)
                    _buildInfoRow(
                      '预计总利息',
                      '¥${debt.totalInterestEstimate!.toStringAsFixed(2)}',
                      valueColor: Colors.orange,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 还款记录
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '还款记录',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showPaymentDialog(context, debt),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('记录还款'),
                      ),
                    ],
                  ),
                  if (_payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '暂无还款记录',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    )
                  else
                    ...(_payments.take(5).map((payment) => _buildPaymentItem(payment))),
                  if (_payments.length > 5)
                    TextButton(
                      onPressed: () => _showAllPayments(context),
                      child: Text('查看全部 ${_payments.length} 条记录'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(context, debt),
        icon: const Icon(Icons.payment),
        label: const Text('记录还款'),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(DebtPayment payment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¥${payment.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '本金 ¥${payment.principalPaid.toStringAsFixed(2)} · 利息 ¥${payment.interestPaid.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '${payment.date.month}/${payment.date.day}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _editDebt(BuildContext context, Debt debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddDebtSheet(ref: ref, editDebt: debt),
    );
  }

  void _markAsCompleted(Debt debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认还清'),
        content: Text('确定已还清 ${debt.name}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(debtProvider.notifier).markAsCompleted(debt.id);
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('恭喜！债务已还清！'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _deleteDebt(Debt debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除债务'),
        content: Text('确定要删除 ${debt.name}？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(debtProvider.notifier).deleteDebt(debt.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, Debt debt) {
    final amountController = TextEditingController(
      text: debt.minimumPayment.toString(),
    );
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录还款'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '还款金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final validationError = AmountValidator.validateText(amountController.text);
              if (validationError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(validationError)),
                );
                return;
              }
              final amount = double.parse(amountController.text);
              await ref.read(debtProvider.notifier).makePayment(
                    debt.id,
                    amount,
                    note: noteController.text.isNotEmpty ? noteController.text : null,
                  );
              await _loadPayments();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('还款已记录'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showAllPayments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Text(
                    '全部还款记录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _payments.length,
                itemBuilder: (context, index) => _buildPaymentItem(_payments[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
