import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../pages/voice_chat_page.dart';
import '../providers/global_voice_assistant_provider.dart';
import '../providers/voice_coordinator_provider.dart';
import '../services/global_voice_assistant_manager.dart';
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
        onLongPress: () => _showForceEndMenu(context, position),
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
              child: _buildBallContent(manager.ballState, manager),
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
        // 小狐狸橙色主题
        return [const Color(0xFFFF8C00), const Color(0xFFFF6B00)];
      case FloatingBallState.recording:
        // 录音状态使用浅色背景，便于波浪形动画显示
        return [Colors.white, const Color(0xFFF5F5F5)];
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
        // 小狐狸橙色阴影
        return const Color(0xFFFF8C00).withValues(alpha: 0.4);
      case FloatingBallState.recording:
        // 录音状态使用红色阴影，增强视觉效果
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
  Widget _buildBallContent(FloatingBallState state, GlobalVoiceAssistantManager manager) {
    switch (state) {
      case FloatingBallState.idle:
        return const Text(
          '🦊',
          style: TextStyle(fontSize: 28),
        );

      case FloatingBallState.recording:
        // 录音状态：红色流动波浪线
        // 无声音时显示直线，有声音时波浪流动，振幅随音量变化
        return WaveformAnimation(
          color: Colors.red,
          size: 28,
          amplitude: manager.amplitude,
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

  /// 处理点击 - 切换对话模式
  void _handleTap() async {
    final manager = ref.read(globalVoiceAssistantProvider);
    final coordinator = ref.read(voiceServiceCoordinatorProvider);
    final currentState = manager.ballState;

    // 如果正在处理中，忽略点击
    if (currentState == FloatingBallState.processing) {
      debugPrint('[GlobalFloatingBall] 正在处理中，忽略点击');
      return;
    }

    // 如果已经在连续对话模式中，单击停止整个对话
    if (manager.isContinuousMode) {
      debugPrint('[GlobalFloatingBall] 单击结束连续对话，当前状态: $currentState');
      manager.stopContinuousMode();
      HapticFeedback.mediumImpact();
      return;
    }

    // 否则，开始新的连续对话
    if (currentState == FloatingBallState.idle ||
        currentState == FloatingBallState.success ||
        currentState == FloatingBallState.error) {
      // 先给用户反馈和启动录音，再做异步初始化
      // 这样可以避免用户说话时录音还没开始的问题
      HapticFeedback.mediumImpact();
      manager.setContinuousMode(true);
      debugPrint('[GlobalFloatingBall] 开始连续对话');

      // 立即开始录音，不等待其他初始化
      manager.startRecording();

      // 异步初始化对话式智能体（不阻塞录音）
      if (!coordinator.isAgentModeEnabled) {
        debugPrint('[GlobalFloatingBall] 异步启用对话式智能体模式');
        coordinator.enableAgentMode().then((_) {
          // 预热LLM连接（在agent初始化完成后）
          coordinator.onVoiceButtonPressed();
        });
      } else {
        // 如果已启用，直接触发预热
        coordinator.onVoiceButtonPressed();
      }
    }
  }

  /// 显示强制结束菜单
  void _showForceEndMenu(BuildContext context, Offset position) {
    HapticFeedback.mediumImpact();

    final manager = ref.read(globalVoiceAssistantProvider);
    final isActive = manager.isContinuousMode ||
                     manager.ballState != FloatingBallState.idle;

    // 计算菜单位置（在悬浮球旁边）
    final screenSize = MediaQuery.of(context).size;
    final isOnLeft = position.dx < screenSize.width / 2;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        isOnLeft ? position.dx + 60 : position.dx - 120,
        position.dy,
        isOnLeft ? screenSize.width - position.dx - 60 : position.dx + 60,
        screenSize.height - position.dy - 50,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'force_end',
          enabled: isActive,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.stop_circle_outlined,
                color: isActive ? Colors.red : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '强制结束',
                style: TextStyle(
                  color: isActive ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'open_chat',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 20),
              SizedBox(width: 8),
              Text('打开对话'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'force_end') {
        _forceEndConversation();
      } else if (value == 'open_chat') {
        widget.onOpenChat?.call();
      }
    });
  }

  /// 强制结束对话（重置所有状态）
  void _forceEndConversation() {
    final manager = ref.read(globalVoiceAssistantProvider);
    debugPrint('[GlobalFloatingBall] 强制结束对话');

    // 停止所有活动
    manager.forceReset();

    HapticFeedback.heavyImpact();

    // 显示提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('语音对话已强制结束'),
          duration: Duration(seconds: 1),
        ),
      );
    }
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
