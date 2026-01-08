import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.07 通知设置页面
/// 推送���知、记账提醒、账单提醒、预算超支提醒
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool _pushNotification = true;
  bool _dailyReminder = true;
  bool _billReminder = true;
  bool _budgetAlert = true;
  bool _weeklyReport = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.notificationSettings,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildNotificationItem(
              icon: Icons.notifications,
              title: l10n.pushNotification,
              subtitle: '接收账单提醒和重要通知',
              value: _pushNotification,
              onChanged: (v) => setState(() => _pushNotification = v),
            ),
            const SizedBox(height: 8),
            _buildNotificationItem(
              icon: Icons.access_alarm,
              title: l10n.dailyReminder,
              subtitle: '每天 ${_formatTime(_reminderTime)} 提醒记账',
              value: _dailyReminder,
              onChanged: (v) => setState(() => _dailyReminder = v),
              onTap: _dailyReminder ? _selectReminderTime : null,
            ),
            const SizedBox(height: 8),
            _buildNotificationItem(
              icon: Icons.payments,
              title: l10n.billDueReminder,
              subtitle: '信用卡、房租等账单提醒',
              value: _billReminder,
              onChanged: (v) => setState(() => _billReminder = v),
            ),
            const SizedBox(height: 8),
            _buildNotificationItem(
              icon: Icons.pie_chart,
              title: l10n.budgetOverspentAlert,
              subtitle: '预算使用超过80%时提醒',
              value: _budgetAlert,
              onChanged: (v) => setState(() => _budgetAlert = v),
            ),
            const SizedBox(height: 8),
            _buildNotificationItem(
              icon: Icons.summarize,
              title: l10n.weeklyReport,
              subtitle: '每周一发送财务周报',
              value: _weeklyReport,
              onChanged: (v) => setState(() => _weeklyReport = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppTheme.primaryColor,
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _reminderTime = time);
    }
  }
}
