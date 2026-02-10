import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../pages/voice_chat_page.dart';
import '../providers/global_voice_assistant_provider.dart';
import '../providers/voice_coordinator_provider.dart';
import '../services/global_voice_assistant_manager.dart';
import '../services/voice/network_monitor.dart' show NetworkStatus;
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

  /// LLM是否可用
  bool _isLLMAvailable = true;

  /// 网络状态订阅
  StreamSubscription<NetworkStatus>? _networkStatusSubscription;

  /// 是否正在检查LLM状态
  bool _isCheckingLLM = false;

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
      if (!mounted) return;
      final manager = ref.read(globalVoiceAssistantProvider);
      manager.onPermissionRequired = _handlePermissionRequired;

      // 尝试订阅网络状态（如果预加载已完成）
      _trySubscribeNetworkStatus(manager);
    });
  }

  /// 尝试订阅网络状态流
  void _trySubscribeNetworkStatus(GlobalVoiceAssistantManager manager) {
    // 已经订阅过了，跳过
    if (_networkStatusSubscription != null) return;

    // 尝试订阅网络状态变化
    final stream = manager.networkStatusStream;
    if (stream != null) {
      // 获取当前LLM状态并更新UI
      final currentStatus = manager.isLLMAvailable;
      if (_isLLMAvailable != currentStatus) {
        setState(() {
          _isLLMAvailable = currentStatus;
        });
        debugPrint('[GlobalFloatingBall] 初始LLM状态: $_isLLMAvailable');
      }

      // 订阅后续状态变化
      _networkStatusSubscription = stream.listen((status) {
        if (mounted) {
          setState(() {
            _isLLMAvailable = status.llmAvailable;
          });
          debugPrint('[GlobalFloatingBall] LLM状态变化: $_isLLMAvailable');
        }
      });
      debugPrint('[GlobalFloatingBall] 已订阅网络状态流');
    }
  }

  @override
  void dispose() {
    // 清理权限回调和网络状态订阅
    try {
      ref.read(globalVoiceAssistantProvider).onPermissionRequired = null;
    } catch (_) {
      // Provider可能已被销毁，忽略清理错误
    }
    _networkStatusSubscription?.cancel();
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
    // 性能优化：先检查设置，如果悬浮球被禁用，不要 watch 其他 provider
    final settings = ref.watch(floatingBallSettingsProvider);
    final shouldHide = ref.watch(shouldHideFloatingBallProvider);

    if (shouldHide || !settings.enabled) {
      // 悬浮球隐藏时不 watch 其他 provider，避免不必要的 rebuild
      return const SizedBox.shrink();
    }

    // 只有悬浮球显示时才 watch 这些 provider
    final manager = ref.watch(globalVoiceAssistantProvider);
    final position = ref.watch(floatingBallPositionProvider);

    // 初始化位置和网络状态订阅
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final positionNotifier = ref.read(floatingBallPositionProvider.notifier);
      if (!positionNotifier.isInitialized) {
        final screenSize = MediaQuery.of(context).size;
        positionNotifier.initializePosition(screenSize);
      }
      // 预加载完成后尝试订阅网络状态
      _trySubscribeNetworkStatus(manager);
    });

    debugPrint('[GlobalFloatingBall] 悬浮球显示中');

    final currentSize = (manager.ballState == FloatingBallState.recording ||
            manager.ballState == FloatingBallState.speaking)
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 主内容
                Center(
                  child: _buildBallContent(manager.ballState, manager),
                ),
                // LLM不可用时的指示器
                if (!_isLLMAvailable && manager.ballState == FloatingBallState.idle)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.wifi_off,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // 检查LLM状态时的加载指示器
                if (_isCheckingLLM)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
      case FloatingBallState.speaking:
        // TTS播放状态使用蓝色主题
        return [const Color(0xFF4A90D9), const Color(0xFF357ABD)];
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
      case FloatingBallState.speaking:
        return const Color(0xFF4A90D9).withValues(alpha:0.4);
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

      case FloatingBallState.speaking:
        // TTS播放状态：显示喇叭图标
        return const Icon(
          Icons.volume_up,
          color: Colors.white,
          size: 28,
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

    // 如果正在检查LLM状态，忽略点击
    if (_isCheckingLLM) {
      debugPrint('[GlobalFloatingBall] 正在检查LLM状态，忽略点击');
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

      // 立即开始预热ASR连接（fire-and-forget，不等待）
      // 这样在检查LLM期间，WebSocket连接可以并行建立，节省100-300ms
      manager.warmupASRConnection();

      // 主动检查LLM可用性
      setState(() => _isCheckingLLM = true);
      final llmAvailable = await manager.checkLLMAvailability();
      if (!mounted) return;
      setState(() {
        _isCheckingLLM = false;
        _isLLMAvailable = llmAvailable;
      });

      // 如果LLM不可用，显示提示并进入简洁模式
      if (!llmAvailable) {
        debugPrint('[GlobalFloatingBall] LLM不可用，显示提示');
        _showLLMUnavailableHint();
      }

      // 无论LLM是否可用，都开始录音（规则模式仍然可用）
      HapticFeedback.mediumImpact();
      manager.setContinuousMode(true);
      debugPrint('[GlobalFloatingBall] 开始连续对话 (LLM可用: $llmAvailable)');

      // 立即开始录音，不等待其他初始化
      manager.startRecording();

      // 异步初始化对话式智能体（不阻塞录音）
      if (!coordinator.isAgentModeEnabled) {
        debugPrint('[GlobalFloatingBall] 异步启用对话式智能体模式');
        coordinator.enableAgentMode().then((_) {
          // 传递 ResultBuffer 给 GlobalVoiceAssistantManager
          // 这样 SmartTopicGenerator 可以在主动对话时检索查询结果
          final resultBuffer = coordinator.resultBuffer;
          if (resultBuffer != null) {
            debugPrint('[GlobalFloatingBall] 传递 ResultBuffer 给语音助手');
            manager.setResultBuffer(resultBuffer);
          }
          // 预热LLM连接（在agent初始化完成后）
          coordinator.onVoiceButtonPressed();
        });
      } else {
        // 如果已启用，确保 ResultBuffer 已传递
        final resultBuffer = coordinator.resultBuffer;
        if (resultBuffer != null) {
          manager.setResultBuffer(resultBuffer);
        }
        // 直接触发预热
        coordinator.onVoiceButtonPressed();
      }
    }
  }

  /// 显示LLM不可用提示
  void _showLLMUnavailableHint() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '网络不太稳定，已切换到简洁模式\n记账功能正常，闲聊功能暂时不可用',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
