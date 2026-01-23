import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/voice/realtime_voice_integration.dart';
import '../services/voice/realtime_conversation_session.dart';
import '../services/voice/conversation_action_bridge.dart';

/// 实时语音集成服务 Provider
final realtimeVoiceIntegrationProvider = Provider<RealtimeVoiceIntegration>((ref) {
  final integration = RealtimeVoiceIntegration();

  ref.onDispose(() {
    integration.dispose();
  });

  return integration;
});

/// 实时语音状态 Provider
final realtimeVoiceStateProvider = StreamProvider<RealtimeVoiceState>((ref) {
  final integration = ref.watch(realtimeVoiceIntegrationProvider);
  return integration.stateStream;
});

/// 语音消息流 Provider
final voiceMessageStreamProvider = StreamProvider<VoiceMessage>((ref) {
  final integration = ref.watch(realtimeVoiceIntegrationProvider);
  return integration.messageStream;
});

/// 操作结果流 Provider
final operationResultStreamProvider = StreamProvider<OperationResult>((ref) {
  final integration = ref.watch(realtimeVoiceIntegrationProvider);
  return integration.resultStream;
});

/// 会话状态 Provider
final sessionStateProvider = Provider<RealtimeSessionState>((ref) {
  final integration = ref.watch(realtimeVoiceIntegrationProvider);
  return integration.sessionState;
});

/// 是否有待处理操作 Provider
final hasPendingOperationsProvider = Provider<bool>((ref) {
  final integration = ref.watch(realtimeVoiceIntegrationProvider);
  return integration.hasPendingOperations;
});

/// 实时语音控制器
///
/// 提供更高层次的控制接口，用于UI组件
class RealtimeVoiceController extends ChangeNotifier {
  final RealtimeVoiceIntegration _integration;

  RealtimeVoiceState _currentState = RealtimeVoiceState.idle;
  final List<VoiceMessage> _messages = [];
  StreamSubscription<RealtimeVoiceState>? _stateSubscription;
  StreamSubscription<VoiceMessage>? _messageSubscription;

  RealtimeVoiceController(this._integration) {
    _setupListeners();
  }

  /// 当前状态
  RealtimeVoiceState get currentState => _currentState;

  /// 消息列表
  List<VoiceMessage> get messages => List.unmodifiable(_messages);

  /// 是否处于活动会话中
  bool get isInSession => _currentState != RealtimeVoiceState.idle;

  /// 是否正在录音
  bool get isRecording =>
      _currentState == RealtimeVoiceState.listening ||
      _currentState == RealtimeVoiceState.userSpeaking;

  /// 是否正在处理
  bool get isProcessing => _currentState == RealtimeVoiceState.thinking;

  /// 是否智能体正在说话
  bool get isAgentSpeaking => _currentState == RealtimeVoiceState.agentSpeaking;

  /// 设置监听
  void _setupListeners() {
    _stateSubscription = _integration.stateStream.listen((state) {
      _currentState = state;
      notifyListeners();
    });

    _messageSubscription = _integration.messageStream.listen((message) {
      _messages.add(message);
      // 限制消息数量
      if (_messages.length > 100) {
        _messages.removeAt(0);
      }
      notifyListeners();
    });
  }

  /// 开始会话
  Future<void> startSession() async {
    await _integration.startSession();
  }

  /// 结束会话
  Future<void> endSession() async {
    await _integration.endSession();
  }

  /// 切换会话状态（点击悬浮球时调用）
  Future<void> toggleSession() async {
    if (isInSession) {
      await endSession();
    } else {
      await startSession();
    }
  }

  /// 处理用户输入
  Future<void> processUserInput(String text) async {
    await _integration.processUserInput(text);
  }

  /// 处理应用生命周期变化
  void onAppLifecycleChanged(AppLifecycleState state) {
    _integration.onAppLifecycleChanged(state);
  }

  /// 确认恢复
  void confirmResume() {
    _integration.confirmResume();
  }

  /// 拒绝恢复
  void declineResume() {
    _integration.declineResume();
  }

  /// 清除消息
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }
}

/// 实时语音控制器 Provider
final realtimeVoiceControllerProvider = ChangeNotifierProvider<RealtimeVoiceController>((ref) {
  final integration = ref.watch(realtimeVoiceIntegrationProvider);
  return RealtimeVoiceController(integration);
});

/// 悬浮球显示状态 Provider（基于实时语音状态）
///
/// 将 RealtimeVoiceState 映射到悬浮球UI状态
final realtimeBallStateProvider = Provider<RealtimeBallState>((ref) {
  final state = ref.watch(realtimeVoiceStateProvider);

  return state.when(
    data: (voiceState) => _mapToRealtimeBallState(voiceState),
    loading: () => RealtimeBallState.idle,
    error: (_, __) => RealtimeBallState.error,
  );
});

/// 悬浮球UI状态
enum RealtimeBallState {
  /// 空闲
  idle,

  /// 监听中
  listening,

  /// 用户说话中
  userSpeaking,

  /// 处理中
  processing,

  /// 智能体说话中
  agentSpeaking,

  /// 成功
  success,

  /// 错误
  error,
}

/// 将语音状态映射到悬浮球状态
RealtimeBallState _mapToRealtimeBallState(RealtimeVoiceState voiceState) {
  switch (voiceState) {
    case RealtimeVoiceState.idle:
      return RealtimeBallState.idle;
    case RealtimeVoiceState.listening:
      return RealtimeBallState.listening;
    case RealtimeVoiceState.userSpeaking:
      return RealtimeBallState.userSpeaking;
    case RealtimeVoiceState.thinking:
      return RealtimeBallState.processing;
    case RealtimeVoiceState.agentSpeaking:
      return RealtimeBallState.agentSpeaking;
    case RealtimeVoiceState.waitingConfirm:
      return RealtimeBallState.listening;
    case RealtimeVoiceState.ending:
      return RealtimeBallState.success;
  }
}

/// 悬浮球颜色配置
class BallColorConfig {
  final List<Color> gradientColors;
  final Color shadowColor;

  const BallColorConfig({
    required this.gradientColors,
    required this.shadowColor,
  });

  /// 根据状态获取颜色配置
  static BallColorConfig fromState(RealtimeBallState state) {
    switch (state) {
      case RealtimeBallState.idle:
        return const BallColorConfig(
          gradientColors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
          shadowColor: Color(0x66FF8C00),
        );
      case RealtimeBallState.listening:
        return const BallColorConfig(
          gradientColors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
          shadowColor: Color(0x664CAF50),
        );
      case RealtimeBallState.userSpeaking:
        return const BallColorConfig(
          gradientColors: [Colors.white, Color(0xFFF5F5F5)],
          shadowColor: Color(0x80F44336),
        );
      case RealtimeBallState.processing:
        return const BallColorConfig(
          gradientColors: [Color(0xFFFF9800), Color(0xFFF57C00)],
          shadowColor: Color(0x66FF9800),
        );
      case RealtimeBallState.agentSpeaking:
        return const BallColorConfig(
          gradientColors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          shadowColor: Color(0x662196F3),
        );
      case RealtimeBallState.success:
        return const BallColorConfig(
          gradientColors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
          shadowColor: Color(0x664CAF50),
        );
      case RealtimeBallState.error:
        return const BallColorConfig(
          gradientColors: [Color(0xFFF44336), Color(0xFFD32F2F)],
          shadowColor: Color(0x66F44336),
        );
    }
  }
}

/// 悬浮球颜色配置 Provider
final ballColorConfigProvider = Provider<BallColorConfig>((ref) {
  final state = ref.watch(realtimeBallStateProvider);
  return BallColorConfig.fromState(state);
});
