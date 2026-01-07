import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 对话助手设置页面
///
/// 对应原型设计 14.07 对话助手设置
/// 配置AI对话助手的功能和风格
class ChatAssistantSettingsPage extends ConsumerStatefulWidget {
  const ChatAssistantSettingsPage({super.key});

  @override
  ConsumerState<ChatAssistantSettingsPage> createState() =>
      _ChatAssistantSettingsPageState();
}

class _ChatAssistantSettingsPageState
    extends ConsumerState<ChatAssistantSettingsPage> {
  bool _multiTurnDialog = true;
  bool _smartSuggestions = true;
  bool _rememberContext = true;
  bool _voiceReply = false;
  String _selectedStyle = 'friendly';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('对话助手'),
      ),
      body: ListView(
        children: [
          // 助手形象
          _AssistantAvatar(),

          // 功能设置
          _FunctionSettingsSection(
            multiTurnDialog: _multiTurnDialog,
            smartSuggestions: _smartSuggestions,
            rememberContext: _rememberContext,
            voiceReply: _voiceReply,
            onMultiTurnChanged: (v) => setState(() => _multiTurnDialog = v),
            onSuggestionsChanged: (v) => setState(() => _smartSuggestions = v),
            onContextChanged: (v) => setState(() => _rememberContext = v),
            onVoiceChanged: (v) => setState(() => _voiceReply = v),
          ),

          // 对话风格
          _DialogStyleSection(
            selectedStyle: _selectedStyle,
            onStyleChanged: (style) => setState(() => _selectedStyle = style),
          ),

          // 清除对话按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _showClearConfirmDialog(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('清除对话历史'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除��话历史'),
        content: const Text('确定要清除所有对话历史吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('对话历史已清除')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}

/// 助手头像
class _AssistantAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.purple[400]!],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '小账',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '您的智能记账助手',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 功能设置区域
class _FunctionSettingsSection extends StatelessWidget {
  final bool multiTurnDialog;
  final bool smartSuggestions;
  final bool rememberContext;
  final bool voiceReply;
  final ValueChanged<bool> onMultiTurnChanged;
  final ValueChanged<bool> onSuggestionsChanged;
  final ValueChanged<bool> onContextChanged;
  final ValueChanged<bool> onVoiceChanged;

  const _FunctionSettingsSection({
    required this.multiTurnDialog,
    required this.smartSuggestions,
    required this.rememberContext,
    required this.voiceReply,
    required this.onMultiTurnChanged,
    required this.onSuggestionsChanged,
    required this.onContextChanged,
    required this.onVoiceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '功能设置',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                _SettingItem(
                  icon: Icons.chat,
                  title: '多轮对话',
                  enabled: multiTurnDialog,
                  onChanged: onMultiTurnChanged,
                  showDivider: true,
                ),
                _SettingItem(
                  icon: Icons.lightbulb,
                  title: '智能建议',
                  enabled: smartSuggestions,
                  onChanged: onSuggestionsChanged,
                  showDivider: true,
                ),
                _SettingItem(
                  icon: Icons.history,
                  title: '记住上下文',
                  enabled: rememberContext,
                  onChanged: onContextChanged,
                  showDivider: true,
                ),
                _SettingItem(
                  icon: Icons.volume_up,
                  title: '语音回复',
                  enabled: voiceReply,
                  onChanged: onVoiceChanged,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onChanged,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 52, color: Colors.grey[200]),
      ],
    );
  }
}

/// 对话风格选择
class _DialogStyleSection extends StatelessWidget {
  final String selectedStyle;
  final ValueChanged<String> onStyleChanged;

  const _DialogStyleSection({
    required this.selectedStyle,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '对话风格',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StyleOption(
                  icon: Icons.emoji_emotions,
                  label: '友好',
                  value: 'friendly',
                  selected: selectedStyle == 'friendly',
                  onTap: () => onStyleChanged('friendly'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StyleOption(
                  icon: Icons.psychology,
                  label: '专业',
                  value: 'professional',
                  selected: selectedStyle == 'professional',
                  onTap: () => onStyleChanged('professional'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StyleOption(
                  icon: Icons.speed,
                  label: '简洁',
                  value: 'concise',
                  selected: selectedStyle == 'concise',
                  onTap: () => onStyleChanged('concise'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _StyleOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
