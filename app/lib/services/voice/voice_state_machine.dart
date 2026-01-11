import 'dart:async';

import 'package:flutter/foundation.dart';

/// 语音状态机
///
/// 支持层次化、并发的状态管理：
/// - 顶层: SessionState (active, paused, ended)
/// - 输出层: SpeakingState (idle, speaking, fading)
/// - 输入层: ListeningState (idle, listening, processing)
///
/// 关键特性：
/// - 支持 speaking + listening 并发状态
/// - 事件驱动的状态转换
/// - 打断和恢复支持
class VoiceStateMachine {
  /// 当前会话状态
  SessionState _sessionState = SessionState.idle;
  SessionState get sessionState => _sessionState;

  /// 当前输出状态（说话）
  SpeakingState _speakingState = SpeakingState.idle;
  SpeakingState get speakingState => _speakingState;

  /// 当前输入状态（监听）
  ListeningState _listeningState = ListeningState.idle;
  ListeningState get listeningState => _listeningState;

  /// 是否处于全双工模式（边说边听）
  bool _fullDuplexMode = false;
  bool get isFullDuplexMode => _fullDuplexMode;

  /// 被打断时的上下文（用于恢复）
  InterruptedContext? _interruptedContext;
  InterruptedContext? get interruptedContext => _interruptedContext;

  /// 状态变化事件流
  final _eventController = StreamController<VoiceStateEvent>.broadcast();
  Stream<VoiceStateEvent> get eventStream => _eventController.stream;

  /// 组合状态变化流
  final _stateController = StreamController<VoiceCompositeState>.broadcast();
  Stream<VoiceCompositeState> get stateStream => _stateController.stream;

  VoiceStateMachine();

  // ==================== 会话状态管理 ====================

  /// 开始会话
  void startSession() {
    if (_sessionState != SessionState.idle) return;

    _sessionState = SessionState.active;
    _emitEvent(VoiceStateEvent.sessionStarted);
    _emitState();
    debugPrint('VoiceStateMachine: session started');
  }

  /// 暂停会话
  void pauseSession() {
    if (_sessionState != SessionState.active) return;

    _sessionState = SessionState.paused;
    _emitEvent(VoiceStateEvent.sessionPaused);
    _emitState();
    debugPrint('VoiceStateMachine: session paused');
  }

  /// 恢复会话
  void resumeSession() {
    if (_sessionState != SessionState.paused) return;

    _sessionState = SessionState.active;
    _emitEvent(VoiceStateEvent.sessionResumed);
    _emitState();
    debugPrint('VoiceStateMachine: session resumed');
  }

  /// 结束会话
  void endSession() {
    if (_sessionState == SessionState.idle) return;

    _sessionState = SessionState.idle;
    _speakingState = SpeakingState.idle;
    _listeningState = ListeningState.idle;
    _interruptedContext = null;
    _emitEvent(VoiceStateEvent.sessionEnded);
    _emitState();
    debugPrint('VoiceStateMachine: session ended');
  }

  // ==================== 输入状态管理（监听） ====================

  /// 开始监听
  void startListening() {
    if (_sessionState != SessionState.active) return;

    _listeningState = ListeningState.listening;
    _emitEvent(VoiceStateEvent.userSpeechDetected);
    _emitState();
    debugPrint('VoiceStateMachine: start listening');
  }

  /// 用户说话结束，开始处理
  void processUserInput() {
    if (_listeningState != ListeningState.listening) return;

    _listeningState = ListeningState.processing;
    _emitEvent(VoiceStateEvent.userSpeechEnded);
    _emitState();
    debugPrint('VoiceStateMachine: processing user input');
  }

  /// 处理完成
  void finishProcessing() {
    if (_listeningState != ListeningState.processing) return;

    _listeningState = ListeningState.idle;
    _emitState();
    debugPrint('VoiceStateMachine: processing finished');
  }

  /// 停止监听
  void stopListening() {
    _listeningState = ListeningState.idle;
    _emitState();
    debugPrint('VoiceStateMachine: stop listening');
  }

  // ==================== 输出状态管理（说话） ====================

  /// 开始说话
  void startSpeaking({String? content}) {
    if (_sessionState != SessionState.active) return;

    _speakingState = SpeakingState.speaking;
    _emitEvent(VoiceStateEvent.aiResponseReady);
    _emitState();
    debugPrint('VoiceStateMachine: start speaking');
  }

  /// 淡出（被打断）
  void fadeOutSpeaking({String? pendingContent}) {
    if (_speakingState != SpeakingState.speaking) return;

    _speakingState = SpeakingState.fading;

    // 保存被打断的上下文
    if (pendingContent != null) {
      _interruptedContext = InterruptedContext(
        content: pendingContent,
        timestamp: DateTime.now(),
      );
    }

    _emitEvent(VoiceStateEvent.interruptRequested);
    _emitState();
    debugPrint('VoiceStateMachine: fading out speaking');
  }

  /// 说话完成
  void finishSpeaking() {
    if (_speakingState == SpeakingState.idle) return;

    _speakingState = SpeakingState.idle;
    _emitEvent(VoiceStateEvent.aiPlaybackComplete);
    _emitState();
    debugPrint('VoiceStateMachine: speaking finished');
  }

  /// 停止说话
  void stopSpeaking() {
    _speakingState = SpeakingState.idle;
    _emitState();
    debugPrint('VoiceStateMachine: stop speaking');
  }

  // ==================== 全双工模式 ====================

  /// 启用全双工模式（边说边听）
  void enableFullDuplexMode() {
    _fullDuplexMode = true;
    debugPrint('VoiceStateMachine: full duplex mode enabled');
  }

  /// 禁用全双工模式
  void disableFullDuplexMode() {
    _fullDuplexMode = false;
    debugPrint('VoiceStateMachine: full duplex mode disabled');
  }

  /// 检查是否可以同时监听
  bool canListenWhileSpeaking() {
    return _fullDuplexMode && _sessionState == SessionState.active;
  }

  // ==================== 打断处理 ====================

  /// 请求打断
  ///
  /// 当用户在AI说话时开始说话，触发打断
  void requestInterrupt() {
    if (_speakingState == SpeakingState.speaking) {
      fadeOutSpeaking();
    }

    if (_listeningState == ListeningState.idle && _sessionState == SessionState.active) {
      startListening();
    }

    _emitEvent(VoiceStateEvent.interruptRequested);
    debugPrint('VoiceStateMachine: interrupt requested');
  }

  /// 清除打断上下文
  void clearInterruptedContext() {
    _interruptedContext = null;
    debugPrint('VoiceStateMachine: interrupted context cleared');
  }

  /// 恢复被打断的内容
  bool resumeInterruptedContent() {
    if (_interruptedContext == null) return false;

    // 只有在一定时间内才允许恢复
    final elapsed = DateTime.now().difference(_interruptedContext!.timestamp);
    if (elapsed.inSeconds > 30) {
      clearInterruptedContext();
      return false;
    }

    return true;
  }

  // ==================== 便捷状态查询 ====================

  /// 是否正在说话
  bool get isSpeaking => _speakingState == SpeakingState.speaking;

  /// 是否正在淡出
  bool get isFading => _speakingState == SpeakingState.fading;

  /// 是否正在监听
  bool get isListening => _listeningState == ListeningState.listening;

  /// 是否正在处理
  bool get isProcessing => _listeningState == ListeningState.processing;

  /// 会话是否活跃
  bool get isSessionActive => _sessionState == SessionState.active;

  /// 是否空闲（可以开始新交互）
  bool get isIdle =>
      _speakingState == SpeakingState.idle &&
      _listeningState == ListeningState.idle &&
      _sessionState == SessionState.active;

  /// 获取当前组合状态
  VoiceCompositeState get currentState => VoiceCompositeState(
        session: _sessionState,
        speaking: _speakingState,
        listening: _listeningState,
        fullDuplex: _fullDuplexMode,
        hasInterruptedContext: _interruptedContext != null,
      );

  // ==================== 事件发射 ====================

  void _emitEvent(VoiceStateEvent event) {
    _eventController.add(event);
  }

  void _emitState() {
    _stateController.add(currentState);
  }

  /// 释放资源
  void dispose() {
    _eventController.close();
    _stateController.close();
  }
}

// ==================== 状态定义 ====================

/// 会话状态
enum SessionState {
  idle,    // 空闲（未开始）
  active,  // 活跃
  paused,  // 暂停
}

/// 说话状态
enum SpeakingState {
  idle,     // 空闲
  speaking, // 正在说话
  fading,   // 淡出中（被打断）
}

/// 监听状态
enum ListeningState {
  idle,       // 空闲
  listening,  // 正在监听
  processing, // 处理中
}

/// 语音状态事件
enum VoiceStateEvent {
  sessionStarted,       // 会话开始
  sessionPaused,        // 会话暂停
  sessionResumed,       // 会话恢复
  sessionEnded,         // 会话结束
  userSpeechDetected,   // 检测到用户说话
  userSpeechEnded,      // 用户说话结束
  aiResponseReady,      // AI响应就绪
  aiPlaybackComplete,   // AI播放完成
  interruptRequested,   // 请求打断
}

/// 组合状态
class VoiceCompositeState {
  final SessionState session;
  final SpeakingState speaking;
  final ListeningState listening;
  final bool fullDuplex;
  final bool hasInterruptedContext;

  const VoiceCompositeState({
    required this.session,
    required this.speaking,
    required this.listening,
    required this.fullDuplex,
    required this.hasInterruptedContext,
  });

  /// 是否处于并发状态（说话+监听）
  bool get isConcurrent =>
      speaking == SpeakingState.speaking && listening == ListeningState.listening;

  @override
  String toString() {
    return 'VoiceCompositeState(session: $session, speaking: $speaking, listening: $listening, fullDuplex: $fullDuplex)';
  }
}

/// 被打断的上下文
class InterruptedContext {
  final String content;
  final DateTime timestamp;

  InterruptedContext({
    required this.content,
    required this.timestamp,
  });
}

/// 状态机配置
class VoiceStateMachineConfig {
  /// 打断后上下文保留时间
  final Duration interruptedContextRetention;

  /// 是否默认启用全双工
  final bool defaultFullDuplex;

  const VoiceStateMachineConfig({
    this.interruptedContextRetention = const Duration(seconds: 30),
    this.defaultFullDuplex = true,
  });

  static const defaultConfig = VoiceStateMachineConfig();
}
