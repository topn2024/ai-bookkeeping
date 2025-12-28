import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_target.dart';
import '../providers/expense_target_provider.dart';
import '../providers/category_provider.dart';
import '../providers/ledger_provider.dart';

/// 月度开支目标页面
class ExpenseTargetPage extends ConsumerStatefulWidget {
  const ExpenseTargetPage({super.key});

  @override
  ConsumerState<ExpenseTargetPage> createState() => _ExpenseTargetPageState();
}

class _ExpenseTargetPageState extends ConsumerState<ExpenseTargetPage> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(monthlyExpenseTargetsProvider(
      (year: _selectedYear, month: _selectedMonth),
    ));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('月度开支目标'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTargetDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 月份选择器
          _buildMonthSelector(context),
          // 汇总卡片
          _buildSummaryCard(context),
          // 目标列表
          Expanded(
            child: targets.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: targets.length,
                    itemBuilder: (context, index) {
                      return _buildTargetCard(context, targets[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth--;
                if (_selectedMonth < 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                }
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          GestureDetector(
            onTap: () => _showMonthPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '$_selectedYear年$_selectedMonth月',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth++;
                if (_selectedMonth > 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                }
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final summaryAsync = ref.watch(expenseTargetSummaryProvider(
      (bookId: null, year: _selectedYear, month: _selectedMonth),
    ));
    final theme = Theme.of(context);

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      context,
                      '总额度',
                      '¥${summary.totalLimit.toStringAsFixed(0)}',
                      Colors.blue,
                    ),
                    _buildSummaryItem(
                      context,
                      '已消费',
                      '¥${summary.totalSpent.toStringAsFixed(0)}',
                      summary.statusColor,
                    ),
                    _buildSummaryItem(
                      context,
                      '剩余',
                      '¥${summary.totalRemaining.toStringAsFixed(0)}',
                      summary.totalRemaining >= 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (summary.overallPercentage / 100).clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(summary.statusColor),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${summary.overallPercentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        if (summary.exceededCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${summary.exceededCount}项超支',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (summary.nearLimitCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${summary.nearLimitCount}项接近上限',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange,
                              ),
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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSummaryItem(
      BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.savings_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无开支目标',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角添加月度开支目标',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddTargetDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('添加开支目标'),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetCard(BuildContext context, ExpenseTarget target) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTargetDetails(context, target),
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
                      color: target.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(target.icon, color: target.color),
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
                                target.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: target.statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                target.statusText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: target.statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (target.categoryName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            target.categoryName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditTargetDialog(context, target);
                      } else if (value == 'copy') {
                        _copyToNextMonth(context, target);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(context, target);
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
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy),
                            SizedBox(width: 8),
                            Text('复制到下月'),
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
                    '已消费 ¥${target.currentSpent.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: target.progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '额度 ¥${target.maxAmount.toStringAsFixed(2)}',
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
                  value: (target.percentage / 100).clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(target.progressColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${target.percentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: target.progressColor,
                    ),
                  ),
                  Text(
                    target.remaining >= 0
                        ? '剩余 ¥${target.remaining.toStringAsFixed(2)}'
                        : '超支 ¥${(-target.remaining).toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: target.remaining >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择月份'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.5,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected =
                  _selectedYear == DateTime.now().year && month == _selectedMonth;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedMonth = month;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$month月',
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddTargetDialog(BuildContext context) {
    _showTargetFormDialog(context, null);
  }

  void _showEditTargetDialog(BuildContext context, ExpenseTarget target) {
    _showTargetFormDialog(context, target);
  }

  void _showTargetFormDialog(BuildContext context, ExpenseTarget? target) {
    final isEditing = target != null;
    final nameController = TextEditingController(text: target?.name ?? '');
    final amountController = TextEditingController(
        text: target?.maxAmount.toStringAsFixed(0) ?? '');
    final descController = TextEditingController(text: target?.description ?? '');
    String? selectedCategoryId = target?.categoryId;
    int alertThreshold = target?.alertThreshold ?? 80;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final categories = ref.read(categoryProvider);

          return AlertDialog(
            title: Text(isEditing ? '编辑开支目标' : '添加开支目标'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '目标名称',
                      hintText: '例如：月度餐饮',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '最高额度',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: '关联分类（可选）',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('总开支（不限分类）'),
                      ),
                      ...categories
                          .where((c) => c.isExpense) // 只显示支出分类
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '描述（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('预警阈值: $alertThreshold%'),
                  Slider(
                    value: alertThreshold.toDouble(),
                    min: 50,
                    max: 100,
                    divisions: 10,
                    label: '$alertThreshold%',
                    onChanged: (value) {
                      setState(() {
                        alertThreshold = value.round();
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final amountText = amountController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入目标名称')),
                    );
                    return;
                  }

                  final amount = double.tryParse(amountText);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入有效的额度')),
                    );
                    return;
                  }

                  final notifier = ref.read(expenseTargetProvider.notifier);
                  final currentLedger = ref.read(currentLedgerProvider);

                  try {
                    if (isEditing) {
                      await notifier.updateTarget(
                        target.id,
                        name: name,
                        description: descController.text.trim(),
                        maxAmount: amount,
                        alertThreshold: alertThreshold,
                      );
                    } else {
                      await notifier.addTarget(
                        bookId: currentLedger?.id ?? '',
                        name: name,
                        description: descController.text.trim(),
                        maxAmount: amount,
                        categoryId: selectedCategoryId,
                        year: _selectedYear,
                        month: _selectedMonth,
                        alertThreshold: alertThreshold,
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('操作失败: $e')),
                      );
                    }
                  }
                },
                child: Text(isEditing ? '保存' : '添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTargetDetails(BuildContext context, ExpenseTarget target) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          return Container(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: target.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(target.icon, color: target.color, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            target.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            target.monthDisplay,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow('最高额度', '¥${target.maxAmount.toStringAsFixed(2)}'),
                _buildDetailRow('已消费', '¥${target.currentSpent.toStringAsFixed(2)}',
                    color: target.progressColor),
                _buildDetailRow(
                    target.remaining >= 0 ? '剩余' : '超支',
                    '¥${target.remaining.abs().toStringAsFixed(2)}',
                    color: target.remaining >= 0 ? Colors.green : Colors.red),
                _buildDetailRow('消费进度', '${target.percentage.toStringAsFixed(1)}%'),
                _buildDetailRow('预警阈值', '${target.alertThreshold}%'),
                if (target.categoryName != null)
                  _buildDetailRow('关联分类', target.categoryName!),
                if (target.description != null && target.description!.isNotEmpty)
                  _buildDetailRow('描述', target.description!),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditTargetDialog(context, target);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('编辑'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _copyToNextMonth(context, target);
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制到下月'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToNextMonth(BuildContext context, ExpenseTarget target) async {
    try {
      await ref.read(expenseTargetProvider.notifier).copyToNextMonth(target.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制到下个月')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('复制失败: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, ExpenseTarget target) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${target.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(expenseTargetProvider.notifier)
                    .deleteTarget(target.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
