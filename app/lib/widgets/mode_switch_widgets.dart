import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_mode_provider.dart';

/// 模式切换动画组件
///
/// 提供平滑的过渡动画，保持用户上下文
class ModeSwitchTransition extends ConsumerStatefulWidget {
  final Widget child;

  const ModeSwitchTransition({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ModeSwitchTransition> createState() => _ModeSwitchTransitionState();
}

class _ModeSwitchTransitionState extends ConsumerState<ModeSwitchTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  UIMode? _previousMode;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(uiModeProvider).mode;

    // 检测模式变化
    if (_previousMode != null && _previousMode != currentMode) {
      _playTransition();
    }
    _previousMode = currentMode;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 1.0 - _fadeAnimation.value,
          child: Transform.scale(
            scale: 1.0 - (_scaleAnimation.value * 0.05),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }

  void _playTransition() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
  }
}

/// 模式切换按钮
class ModeSwitchButton extends ConsumerWidget {
  final bool showLabel;

  const ModeSwitchButton({
    super.key,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiMode = ref.watch(uiModeProvider);
    final isSimple = uiMode.isSimpleMode;

    return IconButton(
      icon: Icon(
        isSimple ? Icons.accessibility_new : Icons.dashboard,
        size: isSimple ? 32 : 24, // 简易模式下图标更大
      ),
      tooltip: isSimple ? '切换到普通模式' : '切换到简易模式',
      onPressed: () async {
        // 显示切换确认对话框
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => _ModeSwitchDialog(isSimple: isSimple),
        );

        if (confirmed == true) {
          await ref.read(uiModeProvider.notifier).toggleMode();

          // 显示切换成功提示
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isSimple ? '已切换到普通模式' : '已切换到简易模式',
                  style: TextStyle(fontSize: isSimple ? 18 : 16),
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }
}

/// 模式切换确认对话框
class _ModeSwitchDialog extends StatelessWidget {
  final bool isSimple;

  const _ModeSwitchDialog({required this.isSimple});

  @override
  Widget build(BuildContext context) {
    final targetMode = isSimple ? '普通模式' : '简易模式';
    final description = isSimple
        ? '普通模式提供完整功能，适合熟悉应用的用户'
        : '简易模式使用大字体和简化操作，更容易使用';

    return AlertDialog(
      title: Text(
        '切换到$targetMode？',
        style: TextStyle(fontSize: isSimple ? 24 : 20),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: TextStyle(fontSize: isSimple ? 18 : 16),
          ),
          const SizedBox(height: 16),
          if (!isSimple) ...[
            const Icon(Icons.accessibility_new, size: 48, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              '• 更大的字体和按钮\n• 简化的操作流程\n• 更清晰的提示',
              style: TextStyle(fontSize: isSimple ? 18 : 16),
            ),
          ] else ...[
            const Icon(Icons.dashboard, size: 48, color: Colors.green),
            const SizedBox(height: 8),
            Text(
              '• 完整的功能\n• 详细的统计\n• 高级设置',
              style: TextStyle(fontSize: isSimple ? 18 : 16),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            '取消',
            style: TextStyle(fontSize: isSimple ? 20 : 16),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            '切换',
            style: TextStyle(fontSize: isSimple ? 20 : 16),
          ),
        ),
      ],
    );
  }
}

/// 首次启动模式选择对话框
class FirstLaunchModeDialog extends ConsumerWidget {
  const FirstLaunchModeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text(
        '选择显示模式',
        style: TextStyle(fontSize: 24),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '请选择适合您的显示模式',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 简易模式选项
          _ModeOption(
            icon: Icons.accessibility_new,
            title: '简易模式',
            description: '大字体、简化操作\n适合初次使用',
            color: Colors.blue,
            onTap: () async {
              await ref.read(uiModeProvider.notifier).switchToSimpleMode();
              await ref.read(uiModeProvider.notifier).completeFirstLaunch();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),

          const SizedBox(height: 16),

          // 普通模式选项
          _ModeOption(
            icon: Icons.dashboard,
            title: '普通模式',
            description: '完整功能\n适合熟悉应用',
            color: Colors.green,
            onTap: () async {
              await ref.read(uiModeProvider.notifier).switchToNormalMode();
              await ref.read(uiModeProvider.notifier).completeFirstLaunch();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
