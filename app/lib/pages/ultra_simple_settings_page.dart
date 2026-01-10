import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/simple_mode_scaffold.dart';
import '../services/tts_service.dart';
import '../providers/ui_mode_provider.dart';

/// 超简易设置页面
///
/// 只显示最常用的5个设置项，每个都是超大按钮
class UltraSimpleSettingsPage extends ConsumerWidget {
  const UltraSimpleSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight = (screenHeight - 200) / 5; // 5个按钮平分

    return SimpleModeScaffold(
      title: '设置',
      body: Column(
        children: [
          _buildSettingButton(
            context: context,
            height: buttonHeight,
            icon: Icons.accessibility_new,
            text: '切换模式',
            color: Colors.blue,
            onTap: () => _switchMode(context, ref),
          ),
          const Divider(height: 1, thickness: 2),
          _buildSettingButton(
            context: context,
            height: buttonHeight,
            icon: Icons.account_balance_wallet,
            text: '账户管理',
            color: Colors.green,
            onTap: () => _showComingSoon(context, '账户管理'),
          ),
          const Divider(height: 1, thickness: 2),
          _buildSettingButton(
            context: context,
            height: buttonHeight,
            icon: Icons.backup,
            text: '备份数据',
            color: Colors.orange,
            onTap: () => _showComingSoon(context, '备份数据'),
          ),
          const Divider(height: 1, thickness: 2),
          _buildSettingButton(
            context: context,
            height: buttonHeight,
            icon: Icons.help,
            text: '帮助',
            color: Colors.purple,
            onTap: () => _showHelp(context),
          ),
          const Divider(height: 1, thickness: 2),
          _buildSettingButton(
            context: context,
            height: buttonHeight,
            icon: Icons.info,
            text: '关于',
            color: Colors.teal,
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton({
    required BuildContext context,
    required double height,
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    final tts = TTSService();

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.heavyImpact();
          tts.speak(text);
          onTap();
        },
        child: Container(
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 100, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchMode(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('切换到普通模式？', style: TextStyle(fontSize: 28)),
        content: const Text(
          '普通模式提供更多功能和详细设置',
          style: TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(fontSize: 24)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('切换', style: TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(uiModeProvider.notifier).toggleMode();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature, style: const TextStyle(fontSize: 28)),
        content: const Text(
          '此功能即将推出',
          style: TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的', style: TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用帮助', style: TextStyle(fontSize: 28)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• 点击"花钱"记录支出', style: TextStyle(fontSize: 20)),
              SizedBox(height: 12),
              Text('• 点击"收钱"记录收入', style: TextStyle(fontSize: 20)),
              SizedBox(height: 12),
              Text('• 点击"查看"查看今天的记录', style: TextStyle(fontSize: 20)),
              SizedBox(height: 12),
              Text('• 所有按钮都有语音提示', style: TextStyle(fontSize: 20)),
              SizedBox(height: 12),
              Text('• 可以随时切换到普通模式', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了', style: TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于', style: TextStyle(fontSize: 28)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet, size: 80, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'AI记账助手',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('版本 1.0.0', style: TextStyle(fontSize: 20)),
            SizedBox(height: 16),
            Text(
              '让记账变得简单',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(fontSize: 24)),
          ),
        ],
      ),
    );
  }
}
