import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../pages/voice_chat_page.dart';
import '../providers/global_voice_assistant_provider.dart';
import '../services/global_voice_assistant_manager.dart';
import '../theme/app_theme.dart';
import 'waveform_animation.dart';

/// 全局悬浮球组件
///
/// 特性：
/// - 始终显示在所有页面之上
/// - 可拖动定位
/// - 拖动结束后自动吸附到屏幕边缘
/// - 点击开始/停止录音
/// - 长按打开聊天界面
/// - 根据状态显示不同视觉效果
class GlobalFloatingBall extends ConsumerStatefulWidget {
  final VoidCallback? onOpenChat;

  const GlobalFloatingBall({
    super.key,
    this.onOpenChat,
  });

  @override
  ConsumerState<GlobalFloatingBall> createState() => _GlobalFloatingBallState();
}

class _GlobalFloatingBallState extends ConsumerState<GlobalFloatingBall>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  late AnimationController _snapController;
  Animation<Offset>? _snapAnimation;

  // 悬浮球尺寸
  static const double _ballSize = 50.0;
  static const double _ballSizeExpanded = 60.0;
  static const double _edgePadding = 16.0;
  static const double _bottomSafeArea = 100.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapController.addListener(() {
      if (_snapAnimation != null) {
        ref.read(floatingBallPositionProvider.notifier).updatePosition(_snapAnimation!.value);
      }
    });

    // 设置权限回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = ref.read(globalVoiceAssistantProvider);
      manager.onPermissionRequired = _handlePermissionRequired;
    });
  }

  @override
  void dispose() {
    // 清理权限回调
    ref.read(globalVoiceAssistantProvider).onPermissionRequired = null;
    _snapController.dispose();
    super.dispose();
  }

  /// 处理权限请求
  void _handlePermissionRequired(MicrophonePermissionStatus status) {
    if (!mounted) return;

    if (status == MicrophonePermissionStatus.permanentlyDenied) {
      _showPermanentlyDeniedDialog();
    }
  }

  /// 显示永久拒绝权限的对话框
  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic_off, color: Colors.red),
            SizedBox(width: 8),
            Text('麦克风权限'),
          ],
        ),
        content: const Text(
          '语音助手需要麦克风权限才能使用。\n\n请在系统设置中开启麦克风权限。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(globalVoiceAssistantProvider);
    final position = ref.watch(floatingBallPositionProvider);
    final settings = ref.watch(floatingBallSettingsProvider);
    final shouldHide = ref.watch(shouldHideFloatingBallProvider);

    // 初始化位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final positionNotifier = ref.read(floatingBallPositionProvider.notifier);
      if (!positionNotifier.isInitialized) {
        final screenSize = MediaQuery.of(context).size;
        positionNotifier.initializePosition(screenSize);
      }
    });

    if (shouldHide || !settings.enabled) {
      return const SizedBox.shrink();
    }

    final currentSize = manager.ballState == FloatingBallState.recording
        ? _ballSizeExpanded
        : _ballSize;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        onPanStart: _handleDragStart,
        onPanUpdate: _handleDragUpdate,
        onPanEnd: _handleDragEnd,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: settings.opacity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: currentSize,
            height: currentSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getBallColors(manager.ballState),
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getShadowColor(manager.ballState),
                  blurRadius: _isDragging ? 16 : 12,
                  offset: Offset(0, _isDragging ? 6 : 4),
                ),
              ],
            ),
            child: Center(
              child: _buildBallContent(manager.ballState),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取悬浮球颜色
  List<Color> _getBallColors(FloatingBallState state) {
    switch (state) {
      case FloatingBallState.idle:
        return [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha:0.8)];
      case FloatingBallState.recording:
        return [Colors.red, Colors.red.shade400];
      case FloatingBallState.processing:
        return [Colors.orange, Colors.orange.shade400];
      case FloatingBallState.success:
        return [Colors.green, Colors.green.shade400];
      case FloatingBallState.error:
        return [Colors.red.shade700, Colors.red.shade500];
      case FloatingBallState.hidden:
        return [Colors.transparent, Colors.transparent];
    }
  }

  /// 获取阴影颜色
  Color _getShadowColor(FloatingBallState state) {
    switch (state) {
      case FloatingBallState.idle:
        return AppTheme.primaryColor.withValues(alpha:0.4);
      case FloatingBallState.recording:
        return Colors.red.withValues(alpha:0.5);
      case FloatingBallState.processing:
        return Colors.orange.withValues(alpha:0.4);
      case FloatingBallState.success:
        return Colors.green.withValues(alpha:0.4);
      case FloatingBallState.error:
        return Colors.red.withValues(alpha:0.4);
      case FloatingBallState.hidden:
        return Colors.transparent;
    }
  }

  /// 构建悬浮球内容
  Widget _buildBallContent(FloatingBallState state) {
    switch (state) {
      case FloatingBallState.idle:
        return const Icon(
          Icons.mic,
          color: Colors.white,
          size: 24,
        );

      case FloatingBallState.recording:
        return const WaveformAnimation(
          color: Colors.white,
          size: 28,
          barCount: 5,
        );

      case FloatingBallState.processing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );

      case FloatingBallState.success:
        return const Icon(
          Icons.check,
          color: Colors.white,
          size: 28,
        );

      case FloatingBallState.error:
        return const Icon(
          Icons.error_outline,
          color: Colors.white,
          size: 24,
        );

      case FloatingBallState.hidden:
        return const SizedBox.shrink();
    }
  }

  /// 处理点击
  void _handleTap() {
    final manager = ref.read(globalVoiceAssistantProvider);

    if (manager.ballState == FloatingBallState.idle) {
      manager.startRecording();
    } else if (manager.ballState == FloatingBallState.recording) {
      manager.stopRecording();
    }
  }

  /// 处理长按
  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onOpenChat?.call();
  }

  /// 开始拖动
  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    _snapController.stop();
  }

  /// 拖动更新
  void _handleDragUpdate(DragUpdateDetails details) {
    final screenSize = MediaQuery.of(context).size;
    final currentPosition = ref.read(floatingBallPositionProvider);
    final currentSize = ref.read(globalVoiceAssistantProvider).ballState == FloatingBallState.recording
        ? _ballSizeExpanded
        : _ballSize;

    final newX = (currentPosition.dx + details.delta.dx).clamp(
      0.0,
      screenSize.width - currentSize,
    );
    final newY = (currentPosition.dy + details.delta.dy).clamp(
      MediaQuery.of(context).padding.top,
      screenSize.height - currentSize - _bottomSafeArea,
    );

    ref.read(floatingBallPositionProvider.notifier).updatePosition(Offset(newX, newY));
  }

  /// 结束拖动
  void _handleDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    _snapToEdge();
  }

  /// 吸附到边缘
  void _snapToEdge() {
    final screenSize = MediaQuery.of(context).size;
    final currentPosition = ref.read(floatingBallPositionProvider);
    final currentSize = ref.read(globalVoiceAssistantProvider).ballState == FloatingBallState.recording
        ? _ballSizeExpanded
        : _ballSize;

    final centerX = currentPosition.dx + currentSize / 2;
    final screenCenterX = screenSize.width / 2;

    // 确定吸附到左边还是右边
    double targetX;
    if (centerX < screenCenterX) {
      targetX = _edgePadding;
    } else {
      targetX = screenSize.width - currentSize - _edgePadding;
    }

    // Y 轴保持在安全范围内
    final minY = MediaQuery.of(context).padding.top + _edgePadding;
    final maxY = screenSize.height - currentSize - _bottomSafeArea;
    final targetY = currentPosition.dy.clamp(minY, maxY);

    // 动画吸附
    _snapAnimation = Tween<Offset>(
      begin: currentPosition,
      end: Offset(targetX, targetY),
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutBack,
    ));

    _snapController.forward(from: 0);
  }
}

/// 全局悬浮球覆盖层
///
/// 使用 Overlay 确保悬浮球始终在最顶层
class GlobalFloatingBallOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalFloatingBallOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalFloatingBallOverlay> createState() => _GlobalFloatingBallOverlayState();
}

class _GlobalFloatingBallOverlayState extends ConsumerState<GlobalFloatingBallOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        GlobalFloatingBall(
          onOpenChat: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VoiceChatPage()),
            );
          },
        ),
      ],
    );
  }
}
