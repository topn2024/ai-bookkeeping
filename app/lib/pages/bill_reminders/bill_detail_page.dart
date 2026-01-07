import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/bill_reminder.dart';

/// 到期通知详情页面
/// 原型设计 13.04：到期通知详情
/// - 账单状态（图标、名称、金额、到期状态）
/// - 账单信息（到期日期、重复周期、付款账户、分类）
/// - 历史付款记录
/// - 操作按钮（编辑、标记已付）
class BillDetailPage extends ConsumerStatefulWidget {
  final BillReminder reminder;

  const BillDetailPage({super.key, required this.reminder});

  @override
  ConsumerState<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends ConsumerState<BillDetailPage> {
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
                    _buildBillStatus(theme),
                    const SizedBox(height: 20),
                    _buildBillInfo(theme),
                    const SizedBox(height: 20),
                    _buildPaymentHistory(theme),
                  ],
                ),
              ),
            ),
            _buildActionButtons(context, theme),
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
              '账单详情',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _showMoreOptions(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 账单状态
  Widget _buildBillStatus(ThemeData theme) {
    final daysUntilDue = widget.reminder.daysUntilBill;
    final statusColor = daysUntilDue <= 0
        ? Colors.red
        : daysUntilDue <= 3
            ? const Color(0xFFFFB74D)
            : const Color(0xFF66BB6A);
    final statusText = daysUntilDue <= 0
        ? '已过期'
        : daysUntilDue == 1
            ? '明天到期'
            : '$daysUntilDue天后到期';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.reminder.color.withValues(alpha: 0.8),
                  widget.reminder.color,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(
              widget.reminder.icon,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.reminder.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${widget.reminder.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 账单信息
  Widget _buildBillInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账单信息',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
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
            children: [
              _buildInfoItem(
                theme,
                '到期日期',
                DateFormat('yyyy年M月d日 (E)', 'zh_CN').format(widget.reminder.nextBillDate),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              _buildInfoItem(
                theme,
                '重复周期',
                _getFrequencyText(),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              _buildInfoItem(
                theme,
                '付款账户',
                '默认账户',
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              _buildInfoItem(
                theme,
                '分类',
                widget.reminder.typeDisplayName,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyText() {
    switch (widget.reminder.frequency) {
      case ReminderFrequency.daily:
        return '每日';
      case ReminderFrequency.weekly:
        final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        return '每${weekdays[(widget.reminder.dayOfWeek ?? 1) - 1]}';
      case ReminderFrequency.monthly:
        return '每月${widget.reminder.dayOfMonth}号';
      case ReminderFrequency.yearly:
        return '每年${widget.reminder.dayOfMonth}号';
      case ReminderFrequency.once:
        return '一次性';
    }
  }

  /// 历史付款记录
  Widget _buildPaymentHistory(ThemeData theme) {
    // 模拟历史记录
    final history = _generateMockHistory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '历史付款',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
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
            children: List.generate(history.length, (index) {
              final item = history[index];
              return Column(
                children: [
                  _buildHistoryItem(theme, item),
                  if (index < history.length - 1)
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _generateMockHistory() {
    final now = DateTime.now();
    return List.generate(3, (index) {
      final month = now.month - index - 1;
      final year = month <= 0 ? now.year - 1 : now.year;
      final adjustedMonth = month <= 0 ? month + 12 : month;
      return {
        'date': '$year年$adjustedMonth月',
        'amount': widget.reminder.amount,
        'paid': true,
      };
    });
  }

  Widget _buildHistoryItem(ThemeData theme, Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item['date'] as String,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Row(
            children: [
              Text(
                '¥${(item['amount'] as double).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item['paid'] as bool ? '已付' : '未付',
                style: TextStyle(
                  fontSize: 11,
                  color: item['paid'] as bool
                      ? const Color(0xFF66BB6A)
                      : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _editBill(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('编辑'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _markAsPaid(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('标记已付'),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('编辑账单'),
            onTap: () {
              Navigator.pop(context);
              _editBill(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_off),
            title: const Text('暂停提醒'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已暂停提醒')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('删除账单', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _editBill(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打开编辑页面...')),
    );
  }

  void _markAsPaid(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已标记为已付款')),
    );
    Navigator.pop(context, true);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除账单 "${widget.reminder.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, 'deleted');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
