import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/realtime_voice_provider.dart';
import '../providers/global_voice_assistant_provider.dart';
import 'waveform_animation.dart';

/// 实时对话悬浮球组件
///
/// 基于实时对话系统的新悬浮球，特性：
/// - 点击开始/结束实时对话会话
/// - 自动语音检测（无需手动停止录音）
/// - 根据对话状态显示不同视觉效果
/// - 支持智能体说话时的可视化
/// - 长按打开聊天界面
class RealtimeFloatingBall extends ConsumerStatefulWidget {
  final VoidCallback? onOpenChat;

  const RealtimeFloatingBall({
    super.key,
    this.onOpenChat,
  });

  @override
  ConsumerState<RealtimeFloatingBall> createState() => _RealtimeFloatingBallState();
}

class _RealtimeFloatingBallState extends ConsumerState<RealtimeFloatingBall>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapController.addListener(() {
      if (_snapAnimation != null) {
        ref.read(floatingBallPositionProvider.notifier).updatePosition(_snapAnimation!.value);
      }
    });

    // 初始化实时语音服务
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRealtimeVoice();
    });
  }

  Future<void> _initializeRealtimeVoice() async {
    final integration = ref.read(realtimeVoiceIntegrationProvider);
    if (!integration.isInitialized) {
      await integration.initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 将Flutter的AppLifecycleState转换为我们定义的类型
    final controller = ref.read(realtimeVoiceControllerProvider);
    controller.onAppLifecycleChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(floatingBallPositionProvider);
    final settings = ref.watch(floatingBallSettingsProvider);
    final shouldHide = ref.watch(shouldHideFloatingBallProvider);
    final ballState = ref.watch(realtimeBallStateProvider);
    final colorConfig = ref.watch(ballColorConfigProvider);

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

    final isExpanded = ballState == RealtimeBallState.userSpeaking ||
        ballState == RealtimeBallState.agentSpeaking;
    final currentSize = isExpanded ? _ballSizeExpanded : _ballSize;

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
                colors: colorConfig.gradientColors,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorConfig.shadowColor,
                  blurRadius: _isDragging ? 16 : 12,
                  offset: Offset(0, _isDragging ? 6 : 4),
                ),
              ],
            ),
            child: Center(
              child: _buildBallContent(ballState),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建悬浮球内容
  Widget _buildBallContent(RealtimeBallState state) {
    switch (state) {
      case RealtimeBallState.idle:
        return const Text(
          '🦊',
          style: TextStyle(fontSize: 28),
        );

      case RealtimeBallState.listening:
        // 监听状态：绿色脉冲效果
        return _PulsingIndicator(
          color: Colors.white,
          size: 24,
        );

      case RealtimeBallState.userSpeaking:
        // 用户说话：红色波形动画
        return const WaveformAnimation(
          color: Colors.red,
          size: 28,
          amplitude: 0.5,
        );

      case RealtimeBallState.processing:
        // 处理中：加载动画
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );

      case RealtimeBallState.agentSpeaking:
        // 智能体说话：蓝色波形动画
        return const WaveformAnimation(
          color: Colors.white,
          size: 28,
          amplitude: 0.6,
        );

      case RealtimeBallState.success:
        return const Icon(
          Icons.check,
          color: Colors.white,
          size: 28,
        );

      case RealtimeBallState.error:
        return const Icon(
          Icons.error_outline,
          color: Colors.white,
          size: 24,
        );
    }
  }

  /// 处理点击
  void _handleTap() async {
    HapticFeedback.lightImpact();

    final controller = ref.read(realtimeVoiceControllerProvider);
    await controller.toggleSession();
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
    final ballState = ref.read(realtimeBallStateProvider);
    final isExpanded = ballState == RealtimeBallState.userSpeaking ||
        ballState == RealtimeBallState.agentSpeaking;
    final currentSize = isExpanded ? _ballSizeExpanded : _ballSize;

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
    final ballState = ref.read(realtimeBallStateProvider);
    final isExpanded = ballState == RealtimeBallState.userSpeaking ||
        ballState == RealtimeBallState.agentSpeaking;
    final currentSize = isExpanded ? _ballSizeExpanded : _ballSize;

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

/// 脉冲指示器
class _PulsingIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingIndicator({
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size * _animation.value,
          height: widget.size * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.8),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 8 * _animation.value,
              ),
            ],
          ),
          child: Icon(
            Icons.mic,
            color: Colors.green.shade700,
            size: widget.size * 0.6,
          ),
        );
      },
    );
  }
}

/// 实时悬浮球覆盖层
///
/// 使用 Stack 确保悬浮球始终在最顶层
class RealtimeFloatingBallOverlay extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onOpenChat;

  const RealtimeFloatingBallOverlay({
    super.key,
    required this.child,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        child,
        RealtimeFloatingBall(
          onOpenChat: onOpenChat,
        ),
      ],
    );
  }
}
