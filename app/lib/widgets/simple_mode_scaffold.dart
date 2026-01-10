import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_mode_provider.dart';
import '../services/tts_service.dart';

/// 简易模式页面脚手架
///
/// 为所有简易模式页面提供统一的布局和功能：
/// - 超大返回按钮
/// - 语音按钮
/// - 模式切换按钮
/// - 统一的样式
class SimpleModeScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final Color? backgroundColor;
  final bool showBackButton;
  final bool showVoiceButton;
  final VoidCallback? onVoicePressed;

  const SimpleModeScaffold({
    super.key,
    required this.title,
    required this.body,
    this.backgroundColor,
    this.showBackButton = true,
    this.showVoiceButton = false,
    this.onVoicePressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = TTSService();

    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        toolbarHeight: 80,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, size: 48, color: Colors.white),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  tts.speak('返回');
                  Navigator.pop(context);
                },
              )
            : null,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (showVoiceButton)
            IconButton(
              icon: const Icon(Icons.mic, size: 48, color: Colors.white),
              onPressed: () {
                HapticFeedback.mediumImpact();
                tts.speak('语音助手');
                onVoicePressed?.call();
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings, size: 40, color: Colors.white),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => _ModeSwitchDialog(),
              );
              if (confirmed == true) {
                await ref.read(uiModeProvider.notifier).toggleMode();
              }
            },
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

/// 模式切换对话框
class _ModeSwitchDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '切换到普通模式？',
        style: TextStyle(fontSize: 28),
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            '普通模式提供完整功能和详细信息',
            style: TextStyle(fontSize: 20),
            textAlign: TextAlign.center,
          ),
        ],
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
    );
  }
}
