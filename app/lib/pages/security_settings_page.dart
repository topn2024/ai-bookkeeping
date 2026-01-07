import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'app_lock_settings_page.dart';
import 'pin_settings_page.dart';
import 'privacy_mode_page.dart';
import 'security_audit_log_page.dart';

/// 8.13 安全设置页面
/// 生物识别解锁、应用锁、隐藏金额、禁止截屏
class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() =>
      _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  bool _fingerprintUnlock = true;
  bool _faceIdUnlock = false;
  bool _hideAmount = false;
  bool _preventScreenshot = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n?.securitySettings ?? '安全设置',
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
            _buildSecurityItem(
              icon: Icons.fingerprint,
              title: l10n?.fingerprintUnlock ?? '指纹解锁',
              subtitle: '使用指纹快速解锁应用',
              value: _fingerprintUnlock,
              onChanged: (v) => setState(() => _fingerprintUnlock = v),
            ),
            const SizedBox(height: 8),
            _buildSecurityItem(
              icon: Icons.face,
              title: l10n?.faceIdUnlock ?? '面容解锁',
              subtitle: '使用面容ID解锁',
              value: _faceIdUnlock,
              onChanged: (v) => setState(() => _faceIdUnlock = v),
            ),
            const SizedBox(height: 8),
            _buildNavigationItem(
              icon: Icons.pin,
              title: l10n?.appLock ?? '应用锁',
              subtitle: '设置6位数字密码',
              onTap: () => _navigateToAppLockSettings(),
            ),
            const SizedBox(height: 8),
            _buildSecurityItem(
              icon: Icons.visibility_off,
              title: l10n?.hideAmount ?? '隐藏金额',
              subtitle: '首页金额显示为***',
              value: _hideAmount,
              onChanged: (v) => setState(() => _hideAmount = v),
            ),
            const SizedBox(height: 8),
            _buildSecurityItem(
              icon: Icons.screenshot,
              title: l10n?.preventScreenshot ?? '禁止截屏',
              subtitle: '防止敏感信息泄露',
              value: _preventScreenshot,
              onChanged: (v) => setState(() => _preventScreenshot = v),
            ),
            const SizedBox(height: 16),
            _buildNavigationItem(
              icon: Icons.visibility_off,
              title: '隐私模式',
              subtitle: '隐藏所有敏感金额信息',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyModePage()),
              ),
            ),
            const SizedBox(height: 8),
            _buildNavigationItem(
              icon: Icons.history,
              title: '安全日志',
              subtitle: '查看安全事件记录',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecurityAuditLogPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
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
        leading: Icon(icon, color: AppColors.primary),
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
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
        leading: Icon(icon, color: AppColors.primary),
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
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

  void _navigateToAppLockSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppLockSettingsPage()),
    );
  }
}
