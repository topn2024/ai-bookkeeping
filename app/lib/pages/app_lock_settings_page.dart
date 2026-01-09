import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'pin_settings_page.dart';

/// 8.21 应用锁设置页面
/// 设置应用密码锁
class AppLockSettingsPage extends ConsumerStatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  ConsumerState<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends ConsumerState<AppLockSettingsPage> {
  bool _appLockEnabled = true;
  String _lockType = 'pin';
  int _autoLockDelay = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.appLockSettings,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainSwitch(),
            if (_appLockEnabled) ...[
              const SizedBox(height: 16),
              _buildLockTypeSection(),
              const SizedBox(height: 16),
              _buildAutoLockSection(),
              const SizedBox(height: 16),
              _buildOptionsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.lock, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '启用应用锁',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '每次打开应用需要验证身份',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _appLockEnabled,
            onChanged: (v) => setState(() => _appLockEnabled = v),
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildLockTypeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '解锁方式',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _buildLockTypeOption(
            icon: Icons.pin,
            title: 'PIN码',
            subtitle: '6位数字密码',
            value: 'pin',
          ),
          Divider(height: 1, indent: 56, color: AppColors.divider),
          _buildLockTypeOption(
            icon: Icons.fingerprint,
            title: '指纹识别',
            subtitle: '使用指纹解锁',
            value: 'fingerprint',
          ),
          Divider(height: 1, indent: 56, color: AppColors.divider),
          _buildLockTypeOption(
            icon: Icons.face,
            title: '面容识别',
            subtitle: '使用Face ID解锁',
            value: 'face',
          ),
        ],
      ),
    );
  }

  Widget _buildLockTypeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = _lockType == value;
    return InkWell(
      onTap: () => setState(() => _lockType = value),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoLockSection() {
    final options = [
      {'value': 0, 'label': '立即'},
      {'value': 30, 'label': '30秒后'},
      {'value': 60, 'label': '1分钟后'},
      {'value': 300, 'label': '5分钟后'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '自动锁定',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isLast = index == options.length - 1;
            final isSelected = _autoLockDelay == option['value'];

            return Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _autoLockDelay = option['value'] as int),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option['label'] as String,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(height: 1, indent: 16, color: AppColors.divider),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.edit, color: AppColors.primary),
            title: const Text('修改PIN码'),
            trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PinSettingsPage()),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: AppColors.divider),
          ListTile(
            leading: Icon(Icons.restore, color: AppColors.primary),
            title: const Text('忘记密码'),
            trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () {
              _showResetPasswordDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置密码'),
        content: const Text('重置密码需要验证您的身份。将发送验证邮件到您注册的邮箱。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('验证邮件已发送'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('发送验证'),
          ),
        ],
      ),
    );
  }
}
