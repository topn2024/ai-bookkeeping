import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/global_voice_assistant_manager.dart';
import '../services/voice_context_service.dart';

/// 全局语音助手管理器 Provider
final globalVoiceAssistantProvider = ChangeNotifierProvider<GlobalVoiceAssistantManager>((ref) {
  return GlobalVoiceAssistantManager.instance;
});

/// 悬浮球状态 Provider
final floatingBallStateProvider = Provider<FloatingBallState>((ref) {
  final manager = ref.watch(globalVoiceAssistantProvider);
  return manager.ballState;
});

/// 悬浮球可见性 Provider
final floatingBallVisibilityProvider = StateProvider<bool>((ref) {
  return true;
});

/// 悬浮球位置 Provider
final floatingBallPositionProvider = StateNotifierProvider<FloatingBallPositionNotifier, Offset>((ref) {
  return FloatingBallPositionNotifier();
});

/// 悬浮球位置状态管理
class FloatingBallPositionNotifier extends StateNotifier<Offset> {
  FloatingBallPositionNotifier() : super(Offset.zero);

  /// 是否已初始化位置
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 初始化默认位置
  void initializePosition(Size screenSize) {
    if (_isInitialized) return;

    // 默认位置：右下角，距离边缘16px，高于底部导航栏
    state = Offset(
      screenSize.width - 66, // 50 (球大小) + 16 (边距)
      screenSize.height - 200, // 留出底部导航栏和FAB空间
    );
    _isInitialized = true;
  }

  /// 更新位置
  void updatePosition(Offset newPosition) {
    state = newPosition;
  }

  /// 吸附到边缘
  void snapToEdge(Size screenSize) {
    const ballSize = 50.0;
    const padding = 16.0;

    final centerX = state.dx + ballSize / 2;
    final screenCenterX = screenSize.width / 2;

    double targetX;
    if (centerX < screenCenterX) {
      targetX = padding;
    } else {
      targetX = screenSize.width - ballSize - padding;
    }

    // Y 轴限制在安全范围内
    final minY = padding + 50; // 状态栏高度
    final maxY = screenSize.height - ballSize - 100; // 底部导航栏
    final targetY = state.dy.clamp(minY, maxY);

    state = Offset(targetX, targetY);
  }
}

/// 对话历史 Provider
final conversationHistoryProvider = Provider<List<ChatMessage>>((ref) {
  final manager = ref.watch(globalVoiceAssistantProvider);
  return manager.conversationHistory;
});

/// 语音上下文服务 Provider
final voiceContextServiceProvider = ChangeNotifierProvider<VoiceContextService>((ref) {
  final manager = ref.watch(globalVoiceAssistantProvider);
  return manager.contextService ?? VoiceContextService();
});

/// 当前页面上下文 Provider
final currentPageContextProvider = Provider<PageContext?>((ref) {
  final contextService = ref.watch(voiceContextServiceProvider);
  return contextService.currentContext;
});

/// 是否应隐藏悬浮球 Provider
final shouldHideFloatingBallProvider = Provider<bool>((ref) {
  final contextService = ref.watch(voiceContextServiceProvider);
  final visibility = ref.watch(floatingBallVisibilityProvider);
  return !visibility || contextService.shouldHideFloatingBall;
});

/// 悬浮球设置 Provider
final floatingBallSettingsProvider = StateNotifierProvider<FloatingBallSettingsNotifier, FloatingBallSettings>((ref) {
  return FloatingBallSettingsNotifier();
});

/// 悬浮球设置
class FloatingBallSettings {
  final bool enabled;
  final double size;
  final double opacity;

  const FloatingBallSettings({
    this.enabled = true,
    this.size = 50.0,
    this.opacity = 1.0,
  });

  FloatingBallSettings copyWith({
    bool? enabled,
    double? size,
    double? opacity,
  }) {
    return FloatingBallSettings(
      enabled: enabled ?? this.enabled,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// 悬浮球设置状态管理
class FloatingBallSettingsNotifier extends StateNotifier<FloatingBallSettings> {
  FloatingBallSettingsNotifier() : super(const FloatingBallSettings());

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  void setSize(double size) {
    state = state.copyWith(size: size.clamp(40.0, 80.0));
  }

  void setOpacity(double opacity) {
    state = state.copyWith(opacity: opacity.clamp(0.5, 1.0));
  }
}
