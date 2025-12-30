import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_reminder.dart';
import '../providers/bill_reminder_provider.dart';

class BillReminderPage extends ConsumerWidget {
  const BillReminderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(billReminderProvider);
    final summary = ref.watch(billReminderSummaryProvider);
    final enabledReminders = reminders.where((r) => r.isEnabled).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账单提醒'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddReminderDialog(context, ref),
          ),
        ],
      ),
      body: reminders.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(context, summary, theme),
                const SizedBox(height: 16),
                if (ref.read(billReminderProvider.notifier).dueTodayReminders.isNotEmpty) ...[
                  _buildUrgentSection(
                    context,
                    ref,
                    '今日到期',
                    ref.read(billReminderProvider.notifier).dueTodayReminders,
                    Colors.red,
                  ),
                  const SizedBox(height: 16),
                ],
                if (ref.read(billReminderProvider.notifier).dueSoonReminders.isNotEmpty) ...[
                  _buildUrgentSection(
                    context,
                    ref,
                    '即将到期',
                    ref.read(billReminderProvider.notifier).dueSoonReminders,
                    Colors.orange,
                  ),
                  const SizedBox(height: 16),
                ],
                _buildSectionHeader('所有账单', enabledReminders.length),
                ...enabledReminders.map((r) => _buildReminderCard(context, ref, r, theme)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加账单'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有账单提醒',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '添加账单提醒，再也不会忘记还款',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddReminderDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加第一个账单'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, BillReminderSummary summary, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '账单概览',
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
                    '账单数量',
                    '${summary.totalCount}',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '月度支出',
                    '¥${summary.monthlyTotal.toStringAsFixed(0)}',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    '年度支出',
                    '¥${summary.yearlyTotal.toStringAsFixed(0)}',
                    Colors.purple,
                  ),
                ),
              ],
            ),
            if (summary.dueTodayCount > 0 || summary.dueSoonCount > 0 || summary.overdueCount > 0) ...[
              const Divider(height: 24),
              Row(
                children: [
                  if (summary.overdueCount > 0) ...[
                    _buildAlertChip('${summary.overdueCount}已过期', Colors.red),
                    const SizedBox(width: 8),
                  ],
                  if (summary.dueTodayCount > 0) ...[
                    _buildAlertChip('${summary.dueTodayCount}今日到期', Colors.red),
                    const SizedBox(width: 8),
                  ],
                  if (summary.dueSoonCount > 0)
                    _buildAlertChip('${summary.dueSoonCount}即将到期', Colors.orange),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
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

  Widget _buildUrgentSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<BillReminder> reminders,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...reminders.map((r) => _buildUrgentItem(context, ref, r, color)),
        ],
      ),
    );
  }

  Widget _buildUrgentItem(BuildContext context, WidgetRef ref, BillReminder reminder, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: reminder.color.withValues(alpha:0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(reminder.icon, color: reminder.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '¥${reminder.amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(billReminderProvider.notifier).markAsReminded(reminder.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已标记为已处理')),
              );
            },
            child: const Text('已处理'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, WidgetRef ref, BillReminder reminder, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showReminderDetail(context, ref, reminder),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: reminder.color.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(reminder.icon, color: reminder.color, size: 28),
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
                            reminder.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '¥${reminder.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: reminder.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          reminder.typeDisplayName,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            reminder.frequencyDisplayName,
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _getNextBillDateText(reminder),
                          style: TextStyle(
                            fontSize: 12,
                            color: reminder.isDueSoon ? Colors.orange : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, ref, reminder, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(reminder.isEnabled ? '禁用' : '启用'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNextBillDateText(BillReminder reminder) {
    final days = reminder.daysUntilBill;
    if (days == 0) return '今天到期';
    if (days < 0) return '已过期 ${-days} 天';
    if (days == 1) return '明天到期';
    return '$days 天后到期 (${reminder.nextBillDate.month}/${reminder.nextBillDate.day})';
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, BillReminder reminder, String action) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BillReminderFormPage(reminder: reminder),
          ),
        );
        break;
      case 'toggle':
        ref.read(billReminderProvider.notifier).toggleReminder(reminder.id);
        break;
      case 'delete':
        _confirmDelete(context, ref, reminder);
        break;
    }
  }

  void _showReminderDetail(BuildContext context, WidgetRef ref, BillReminder reminder) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ReminderDetailSheet(
        reminder: reminder,
        onEdit: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillReminderFormPage(reminder: reminder),
            ),
          );
        },
        onMarkDone: () {
          ref.read(billReminderProvider.notifier).markAsReminded(reminder.id);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已标记为已处理')),
          );
        },
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context, WidgetRef ref) {
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
        builder: (context, scrollController) => _TypeSelectionSheet(
          scrollController: scrollController,
          onSelectType: (type) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BillReminderFormPage(initialType: type),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BillReminder reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除账单提醒 "${reminder.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(billReminderProvider.notifier).deleteReminder(reminder.id);
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

class _ReminderDetailSheet extends StatelessWidget {
  final BillReminder reminder;
  final VoidCallback onEdit;
  final VoidCallback onMarkDone;

  const _ReminderDetailSheet({
    required this.reminder,
    required this.onEdit,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: reminder.color.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(reminder.icon, color: reminder.color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      reminder.typeDisplayName,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Text(
                '¥${reminder.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: reminder.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow(Icons.repeat, '周期', reminder.frequencyDisplayName),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.calendar_today,
            '下次到期',
            '${reminder.nextBillDate.month}月${reminder.nextBillDate.day}日 (${reminder.daysUntilBill}天后)',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.notifications,
            '提前提醒',
            '${reminder.reminderDaysBefore}天',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.access_time,
            '提醒时间',
            '${reminder.reminderTime.hour.toString().padLeft(2, '0')}:${reminder.reminderTime.minute.toString().padLeft(2, '0')}',
          ),
          if (reminder.note != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.note, '备注', reminder.note!),
          ],
          const SizedBox(height: 24),
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
                  onPressed: onMarkDone,
                  icon: const Icon(Icons.check),
                  label: const Text('已处理'),
                  style: ElevatedButton.styleFrom(backgroundColor: reminder.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600])),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TypeSelectionSheet extends StatelessWidget {
  final ScrollController scrollController;
  final Function(BillReminderType) onSelectType;

  const _TypeSelectionSheet({
    required this.scrollController,
    required this.onSelectType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
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
            '选择账单类型',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: BillReminderType.values.map((type) {
                final preset = BillReminderPresets.presets[type]!;
                final icon = preset['icon'] as IconData;
                final color = preset['color'] as Color;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(_getTypeName(type)),
                    subtitle: Text(_getTypeDescription(type)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelectType(type),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeName(BillReminderType type) {
    switch (type) {
      case BillReminderType.creditCard:
        return '信用卡还款';
      case BillReminderType.subscription:
        return '订阅服务';
      case BillReminderType.utility:
        return '水电煤气';
      case BillReminderType.rent:
        return '房租';
      case BillReminderType.loan:
        return '贷款还款';
      case BillReminderType.insurance:
        return '保险';
      case BillReminderType.other:
        return '其他';
    }
  }

  String _getTypeDescription(BillReminderType type) {
    switch (type) {
      case BillReminderType.creditCard:
        return '信用卡账单还款提醒';
      case BillReminderType.subscription:
        return '视频、音乐等订阅服务';
      case BillReminderType.utility:
        return '水费、电费、燃气费';
      case BillReminderType.rent:
        return '房租、物业费';
      case BillReminderType.loan:
        return '房贷、车贷、消费贷';
      case BillReminderType.insurance:
        return '各类保险续费';
      case BillReminderType.other:
        return '其他定期账单';
    }
  }
}

class BillReminderFormPage extends ConsumerStatefulWidget {
  final BillReminder? reminder;
  final BillReminderType? initialType;

  const BillReminderFormPage({super.key, this.reminder, this.initialType});

  @override
  ConsumerState<BillReminderFormPage> createState() => _BillReminderFormPageState();
}

class _BillReminderFormPageState extends ConsumerState<BillReminderFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  late BillReminderType _selectedType;
  ReminderFrequency _frequency = ReminderFrequency.monthly;
  int _dayOfMonth = 1;
  int _dayOfWeek = 1;
  int _reminderDaysBefore = 3;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime? _specificDate;
  IconData _selectedIcon = Icons.receipt_long;
  Color _selectedColor = Colors.blue;

  bool get isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();

    if (widget.reminder != null) {
      _nameController = TextEditingController(text: widget.reminder!.name);
      _amountController = TextEditingController(
        text: widget.reminder!.amount.toStringAsFixed(2),
      );
      _noteController = TextEditingController(text: widget.reminder!.note ?? '');
      _selectedType = widget.reminder!.type;
      _frequency = widget.reminder!.frequency;
      _dayOfMonth = widget.reminder!.dayOfMonth;
      _dayOfWeek = widget.reminder!.dayOfWeek ?? 1;
      _reminderDaysBefore = widget.reminder!.reminderDaysBefore;
      _reminderTime = widget.reminder!.reminderTime;
      _specificDate = widget.reminder!.specificDate;
      _selectedIcon = widget.reminder!.icon;
      _selectedColor = widget.reminder!.color;
    } else {
      _selectedType = widget.initialType ?? BillReminderType.other;
      _nameController = TextEditingController();
      _amountController = TextEditingController();
      _noteController = TextEditingController();

      // 设置默认图标和颜色
      final preset = BillReminderPresets.presets[_selectedType]!;
      _selectedIcon = preset['icon'] as IconData;
      _selectedColor = preset['color'] as Color;
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑账单提醒' : '添加账单提醒'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector
            DropdownButtonFormField<BillReminderType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: '账单类型',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: BillReminderType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeName(type)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  final preset = BillReminderPresets.presets[_selectedType]!;
                  _selectedIcon = preset['icon'] as IconData;
                  _selectedColor = preset['color'] as Color;
                });
              },
            ),
            const SizedBox(height: 16),
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '账单名称',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入账单名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '账单金额',
                prefixIcon: Icon(Icons.monetization_on),
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入账单金额';
                }
                if (double.tryParse(value) == null) {
                  return '请输入有效金额';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Frequency
            Text(
              '账单周期',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ReminderFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.repeat),
                border: OutlineInputBorder(),
              ),
              items: ReminderFrequency.values.map((freq) {
                return DropdownMenuItem(
                  value: freq,
                  child: Text(_getFrequencyName(freq)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _frequency = value!);
              },
            ),
            const SizedBox(height: 16),
            // Day selection based on frequency
            if (_frequency == ReminderFrequency.monthly || _frequency == ReminderFrequency.yearly)
              _buildDayOfMonthSelector(),
            if (_frequency == ReminderFrequency.weekly)
              _buildDayOfWeekSelector(),
            if (_frequency == ReminderFrequency.once)
              _buildSpecificDateSelector(),
            const SizedBox(height: 24),
            // Reminder settings
            Text(
              '提醒设置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildReminderDaysSelector(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildReminderTimeSelector(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Note
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注 (选填)',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            // Icon and color
            _buildIconColorSelector(),
            const SizedBox(height: 32),
            // Save button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saveReminder,
                child: Text(isEditing ? '保存修改' : '添加提醒'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayOfMonthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('账单日'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: _dayOfMonth,
            isExpanded: true,
            underline: const SizedBox(),
            items: List.generate(28, (i) => i + 1).map((day) {
              return DropdownMenuItem(
                value: day,
                child: Text('每月 $day 日'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _dayOfMonth = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildDayOfWeekSelector() {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('每周几'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: _dayOfWeek,
            isExpanded: true,
            underline: const SizedBox(),
            items: List.generate(7, (i) => i + 1).map((day) {
              return DropdownMenuItem(
                value: day,
                child: Text(weekdays[day - 1]),
              );
            }).toList(),
            onChanged: (v) => setState(() => _dayOfWeek = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('具体日期'),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _specificDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              setState(() => _specificDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Text(
                  _specificDate != null
                      ? '${_specificDate!.year}/${_specificDate!.month}/${_specificDate!.day}'
                      : '选择日期',
                  style: TextStyle(
                    color: _specificDate != null ? Colors.black : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderDaysSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('提前提醒'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: _reminderDaysBefore,
            isExpanded: true,
            underline: const SizedBox(),
            items: [0, 1, 2, 3, 5, 7].map((day) {
              return DropdownMenuItem(
                value: day,
                child: Text(day == 0 ? '当天' : '$day天前'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _reminderDaysBefore = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('提醒时间'),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _reminderTime,
            );
            if (picked != null) {
              setState(() => _reminderTime = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconColorSelector() {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.brown,
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

  String _getTypeName(BillReminderType type) {
    switch (type) {
      case BillReminderType.creditCard:
        return '信用卡还款';
      case BillReminderType.subscription:
        return '订阅服务';
      case BillReminderType.utility:
        return '水电煤气';
      case BillReminderType.rent:
        return '房租';
      case BillReminderType.loan:
        return '贷款还款';
      case BillReminderType.insurance:
        return '保险';
      case BillReminderType.other:
        return '其他';
    }
  }

  String _getFrequencyName(ReminderFrequency freq) {
    switch (freq) {
      case ReminderFrequency.once:
        return '一次性';
      case ReminderFrequency.daily:
        return '每日';
      case ReminderFrequency.weekly:
        return '每周';
      case ReminderFrequency.monthly:
        return '每月';
      case ReminderFrequency.yearly:
        return '每年';
    }
  }

  void _saveReminder() {
    if (!_formKey.currentState!.validate()) return;

    if (_frequency == ReminderFrequency.once && _specificDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择具体日期')),
      );
      return;
    }

    final reminder = BillReminder(
      id: widget.reminder?.id ?? const Uuid().v4(),
      name: _nameController.text,
      type: _selectedType,
      amount: double.parse(_amountController.text),
      frequency: _frequency,
      dayOfMonth: _dayOfMonth,
      dayOfWeek: _frequency == ReminderFrequency.weekly ? _dayOfWeek : null,
      specificDate: _frequency == ReminderFrequency.once ? _specificDate : null,
      reminderDaysBefore: _reminderDaysBefore,
      reminderTime: _reminderTime,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      icon: _selectedIcon,
      color: _selectedColor,
      isEnabled: widget.reminder?.isEnabled ?? true,
      lastRemindedAt: widget.reminder?.lastRemindedAt,
      nextReminderDate: widget.reminder?.nextReminderDate,
      createdAt: widget.reminder?.createdAt ?? DateTime.now(),
    );

    if (isEditing) {
      ref.read(billReminderProvider.notifier).updateReminder(reminder);
    } else {
      ref.read(billReminderProvider.notifier).addReminder(reminder);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEditing ? '提醒已更新' : '提醒已添加')),
    );
  }
}
