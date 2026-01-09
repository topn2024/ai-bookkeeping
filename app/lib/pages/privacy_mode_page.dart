import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.23 隐私模式设置页面
/// 隐藏敏感金额信息、截屏保护等
class PrivacyModePage extends ConsumerStatefulWidget {
  const PrivacyModePage({super.key});

  @override
  ConsumerState<PrivacyModePage> createState() => _PrivacyModePageState();
}

class _PrivacyModePageState extends ConsumerState<PrivacyModePage> {
  bool _privacyModeEnabled = true;
  bool _hideOnScreenshot = true;
  bool _blurInRecents = true;
  bool _preventScreenshot = false;
  bool _autoHideAfterIdle = false;

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
          l10n.privacyMode,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainSwitch(),
            if (_privacyModeEnabled) ...[
              _buildPreviewCard(),
              _buildSectionHeader('详细设置'),
              _buildSettingsCard(),
              _buildSectionHeader('数据访问'),
              _buildAccessCard(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSwitch() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, const Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.visibility_off,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '隐私模式',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '隐藏所有敏感金额信息',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _privacyModeEnabled,
            onChanged: (v) => setState(() => _privacyModeEnabled = v),
            thumbColor: WidgetStateProperty.all(Colors.white),
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '预览效果',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
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
          child: Column(
            children: [
              _buildPreviewRow('账户余额', '****'),
              const Divider(height: 24),
              _buildPreviewRow('本月支出', '****', isExpense: true),
              const Divider(height: 24),
              _buildPreviewRow('账户名称', '招**行'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool isExpense = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isExpense ? AppColors.error : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          _buildSwitchTile(
            title: '截图时隐藏金额',
            subtitle: '截屏时自动隐藏敏感信息',
            value: _hideOnScreenshot,
            onChanged: (v) => setState(() => _hideOnScreenshot = v),
          ),
          Divider(height: 1, indent: 16, color: AppColors.divider),
          _buildSwitchTile(
            title: '在最近任务中模糊',
            subtitle: '任务切换时模糊显示界面',
            value: _blurInRecents,
            onChanged: (v) => setState(() => _blurInRecents = v),
          ),
          Divider(height: 1, indent: 16, color: AppColors.divider),
          _buildSwitchTile(
            title: '禁止截屏',
            subtitle: '完全禁止应用内截屏',
            value: _preventScreenshot,
            onChanged: (v) => setState(() => _preventScreenshot = v),
          ),
          Divider(height: 1, indent: 16, color: AppColors.divider),
          _buildSwitchTile(
            title: '空闲后自动隐藏',
            subtitle: '30秒无操作后自动启用隐私模式',
            value: _autoHideAfterIdle,
            onChanged: (v) => setState(() => _autoHideAfterIdle = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
    );
  }

  Widget _buildAccessCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.apps, color: AppColors.primary),
            ),
            title: const Text(
              '第三方应用权限',
              style: TextStyle(fontSize: 15),
            ),
            subtitle: Text(
              '管理数据访问授权',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('即将打开权限管理')),
              );
            },
          ),
          Divider(height: 1, indent: 72, color: AppColors.divider),
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_forever, color: AppColors.error),
            ),
            title: const Text(
              '清除访问记录',
              style: TextStyle(fontSize: 15),
            ),
            subtitle: Text(
              '删除所有第三方访问日志',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: _showClearLogsDialog,
          ),
        ],
      ),
    );
  }

  void _showClearLogsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除访问记录'),
        content: const Text('确定要清除所有第三方访问日志吗？此操作不可撤销。'),
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
                  content: const Text('访问记录已清除'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }
}
