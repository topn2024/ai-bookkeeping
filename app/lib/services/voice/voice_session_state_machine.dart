import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_session_state.dart';

/// 语音会话状态机
///
/// 参考 LiveKit AgentState 设计，职责：
/// - 管理状态转换
/// - 验证转换合法性
/// - 发送状态变化事件
///
/// 状态转换图:
/// ```
///              用户启动
///                 │
///                 ▼
/// idle ──────► listening ◄─────────────────┐
///                 │                         │
///                 │ ASR 最终结果            │
///                 ▼                         │
///             thinking                      │
///                 │                         │
///                 │ LLM 响应就绪            │
///                 ▼                         │
///             speaking ─────────────────────┘
///                       TTS 完成/用户打断
/// ```
class VoiceSessionStateMachine {
  /// 当前状态
  VoiceSessionState _state = VoiceSessionState.idle;

  /// 获取当前状态
  VoiceSessionState get state => _state;

  /// 状态变化流控制器
  final _stateController = StreamController<VoiceSessionStateChange>.broadcast();

  /// 状态变化流
  Stream<VoiceSessionStateChange> get stateStream => _stateController.stream;

  /// 状态转换验证表
  ///
  /// 定义每个状态允许转换到哪些状态
  static const Map<VoiceSessionState, Set<VoiceSessionState>> _validTransitions = {
    VoiceSessionState.idle: {
      VoiceSessionState.listening,
    },
    VoiceSessionState.listening: {
      VoiceSessionState.thinking,   // ASR 最终结果
      VoiceSessionState.speaking,   // 主动对话（静默超时）
      VoiceSessionState.idle,       // 用户停止
    },
    VoiceSessionState.thinking: {
      VoiceSessionState.speaking,   // LLM 响应就绪
      VoiceSessionState.listening,  // 处理失败/无响应
      VoiceSessionState.idle,       // 用户停止
    },
    VoiceSessionState.speaking: {
      VoiceSessionState.listening,  // TTS 完成 或 用户打断
      VoiceSessionState.idle,       // 用户停止
    },
  };

  /// 尝试转换状态
  ///
  /// 返回是否转换成功
  /// [newState] 目标状态
  /// [reason] 转换原因（用于调试日志）
  bool transition(VoiceSessionState newState, {String? reason}) {
    // 检查是否允许转换
    if (!canTransition(newState)) {
      debugPrint(
          '[StateMachine] ❌ 非法转换: $_state -> $newState (reason: $reason)');
      return false;
    }

    final oldState = _state;
    _state = newState;

    debugPrint(
        '[StateMachine] ✓ 状态转换: $oldState -> $newState (reason: $reason)');

    // 发送状态变化事件
    if (!_stateController.isClosed) {
      _stateController.add(VoiceSessionStateChange(
        oldState: oldState,
        newState: newState,
        reason: reason,
      ));
    }

    return true;
  }

  /// 检查是否可以转换到目标状态
  bool canTransition(VoiceSessionState newState) {
    // 允许转换到相同状态（无操作）
    if (_state == newState) {
      return true;
    }

    return _validTransitions[_state]?.contains(newState) ?? false;
  }

  /// 强制设置状态（仅用于重置，跳过验证）
  void forceState(VoiceSessionState newState, {String? reason}) {
    final oldState = _state;
    _state = newState;

    debugPrint(
        '[StateMachine] ⚠ 强制设置: $oldState -> $newState (reason: $reason)');

    if (!_stateController.isClosed) {
      _stateController.add(VoiceSessionStateChange(
        oldState: oldState,
        newState: newState,
        reason: reason ?? 'force reset',
      ));
    }
  }

  /// 重置到初始状态
  void reset() {
    forceState(VoiceSessionState.idle, reason: 'reset');
  }

  // ═══════════════════════════════════════════════════════════════
  // 辅助属性（直接委托给状态扩展方法）
  // ═══════════════════════════════════════════════════════════════

  /// 是否应该运行 ASR
  bool get shouldRunASR => _state.shouldRunASR;

  /// 是否应该运行 VAD
  bool get shouldRunVAD => _state.shouldRunVAD;

  /// 是否应该运行录音
  bool get shouldRunRecording => _state.shouldRunRecording;

  /// 是否可以被打断
  bool get isInterruptible => _state.isInterruptible;

  /// 是否正在处理中
  bool get isProcessing => _state.isProcessing;

  /// 是否空闲
  bool get isIdle => _state == VoiceSessionState.idle;

  /// 是否正在监听
  bool get isListening => _state == VoiceSessionState.listening;

  /// 是否正在思考
  bool get isThinking => _state == VoiceSessionState.thinking;

  /// 是否正在说话
  bool get isSpeaking => _state == VoiceSessionState.speaking;

  /// 释放资源
  Future<void> dispose() async {
    await _stateController.close();
  }
}
