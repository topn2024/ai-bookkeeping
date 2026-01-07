import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.31 辅助功能设置页面
/// 无障碍功能设置：字体大小、高对比度、屏幕朗读等
class AccessibilitySettingsPage extends ConsumerStatefulWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  ConsumerState<AccessibilitySettingsPage> createState() =>
      _AccessibilitySettingsPageState();
}

class _AccessibilitySettingsPageState
    extends ConsumerState<AccessibilitySettingsPage> {
  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _screenReader = false;
  bool _reduceMotion = false;
  bool _boldText = false;
  bool _largeTouch = false;

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
          l10n?.accessibilitySettings ?? '辅助功能',
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
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildFontSizeSection(l10n),
            const SizedBox(height: 16),
            _buildVisualSection(l10n),
            const SizedBox(height: 16),
            _buildInteractionSection(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.accessibility_new,
            color: AppTheme.primaryColor,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '让每个人都能轻松使用',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '根据您的需求调整界面显示和交互方式',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeSection(AppLocalizations? l10n) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.text_fields, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Text(
                l10n?.fontSize ?? '字体大小',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('A', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _fontScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (v) => setState(() => _fontScale = v),
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 20)),
            ],
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '预览文字 ${(_fontScale * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14 * _fontScale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualSection(AppLocalizations? l10n) {
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
          _buildSwitchTile(
            icon: Icons.contrast,
            title: l10n?.highContrast ?? '高对比度',
            subtitle: '增强文字与背景的对比',
            value: _highContrast,
            onChanged: (v) => setState(() => _highContrast = v),
          ),
          Divider(height: 1, color: AppTheme.dividerColor),
          _buildSwitchTile(
            icon: Icons.format_bold,
            title: l10n?.boldText ?? '粗体文字',
            subtitle: '使用粗体显示所有文字',
            value: _boldText,
            onChanged: (v) => setState(() => _boldText = v),
          ),
          Divider(height: 1, color: AppTheme.dividerColor),
          _buildSwitchTile(
            icon: Icons.animation,
            title: l10n?.reduceMotion ?? '减少动效',
            subtitle: '减少界面动画效果',
            value: _reduceMotion,
            onChanged: (v) => setState(() => _reduceMotion = v),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionSection(AppLocalizations? l10n) {
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
          _buildSwitchTile(
            icon: Icons.record_voice_over,
            title: l10n?.screenReader ?? '屏幕朗读',
            subtitle: '自动朗读屏幕内容',
            value: _screenReader,
            onChanged: (v) => setState(() => _screenReader = v),
          ),
          Divider(height: 1, color: AppTheme.dividerColor),
          _buildSwitchTile(
            icon: Icons.touch_app,
            title: l10n?.largeTouchTarget ?? '大触控区域',
            subtitle: '增大按钮和可点击区域',
            value: _largeTouch,
            onChanged: (v) => setState(() => _largeTouch = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
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
        activeColor: AppTheme.primaryColor,
      ),
    );
  }
}
