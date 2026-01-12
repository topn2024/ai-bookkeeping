import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/global_voice_assistant_provider.dart';
import 'voice_learning_report_page.dart';

/// 语音助手设置页面
class VoiceAssistantSettingsPage extends ConsumerStatefulWidget {
  const VoiceAssistantSettingsPage({super.key});

  @override
  ConsumerState<VoiceAssistantSettingsPage> createState() => _VoiceAssistantSettingsPageState();
}

class _VoiceAssistantSettingsPageState extends ConsumerState<VoiceAssistantSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(floatingBallSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('语音助手设置'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('悬浮球'),
            _buildSettingsCard(
              children: [
                _buildSwitchItem(
                  icon: Icons.mic,
                  iconColor: AppTheme.primaryColor,
                  title: '显示悬浮球',
                  subtitle: '在所有页面显示语音助手悬浮球',
                  value: settings.enabled,
                  onChanged: (value) {
                    ref.read(floatingBallSettingsProvider.notifier).setEnabled(value);
                  },
                ),
                _buildDivider(),
                _buildSliderItem(
                  icon: Icons.opacity,
                  iconColor: const Color(0xFF2196F3),
                  title: '悬浮球透明度',
                  subtitle: '${(settings.opacity * 100).round()}%',
                  value: settings.opacity,
                  min: 0.5,
                  max: 1.0,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(floatingBallSettingsProvider.notifier).setOpacity(value);
                        }
                      : null,
                ),
                _buildDivider(),
                _buildSliderItem(
                  icon: Icons.photo_size_select_small,
                  iconColor: const Color(0xFF4CAF50),
                  title: '悬浮球大小',
                  subtitle: '${settings.size.round()}',
                  value: settings.size,
                  min: 40.0,
                  max: 80.0,
                  onChanged: settings.enabled
                      ? (value) {
                          ref.read(floatingBallSettingsProvider.notifier).setSize(value);
                        }
                      : null,
                ),
              ],
            ),
            _buildSectionHeader('智能学习'),
            _buildSettingsCard(
              children: [
                _buildMenuItem(
                  icon: Icons.psychology,
                  iconColor: const Color(0xFF9C27B0),
                  title: '学习报告',
                  subtitle: '查看语音助手的学习进度和效果',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VoiceLearningReportPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
            _buildSectionHeader('操作'),
            _buildSettingsCard(
              children: [
                _buildMenuItem(
                  icon: Icons.refresh,
                  iconColor: const Color(0xFFFF9800),
                  title: '重置悬浮球位置',
                  subtitle: '将悬浮球移回默认位置',
                  onTap: () {
                    final screenSize = MediaQuery.of(context).size;
                    ref.read(floatingBallPositionProvider.notifier).initializePosition(screenSize);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('悬浮球位置已重置')),
                    );
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.delete_outline,
                  iconColor: AppColors.expense,
                  title: '清除对话历史',
                  subtitle: '删除所有语音助手对话记录',
                  onTap: () => _confirmClearHistory(),
                ),
              ],
            ),
            _buildSectionHeader('使用说明'),
            _buildHelpCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: Column(children: children),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        activeColor: AppTheme.primaryColor,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    ValueChanged<double>? onChanged,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: onChanged != null ? iconColor : Colors.grey,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 56,
      color: AppColors.divider,
    );
  }

  Widget _buildHelpCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '使用提示',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHelpItem('点击悬浮球', '开始/停止语音录入'),
          _buildHelpItem('长按悬浮球', '打开对话历史'),
          _buildHelpItem('拖动悬浮球', '移动到任意位置，松手自动吸附边缘'),
          _buildHelpItem('说"午餐35块"', '快速记账'),
          _buildHelpItem('说"还剩多少预算"', '查询预算余额（在预算页面）'),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String action, String description) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                children: [
                  TextSpan(
                    text: '$action: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除对话历史'),
        content: const Text('确定要删除所有语音助手对话记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(globalVoiceAssistantProvider).clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('对话历史已清除')),
              );
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
