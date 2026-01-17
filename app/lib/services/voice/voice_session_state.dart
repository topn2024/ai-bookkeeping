/// 语音会话状态（参考 LiveKit AgentState 设计）
///
/// 4 个核心状态，清晰定义每个阶段的职责
enum VoiceSessionState {
  /// 空闲状态
  ///
  /// 系统未激活，等待用户启动会话
  /// - 录音: OFF
  /// - ASR: OFF
  /// - VAD: OFF
  /// - TTS: OFF
  idle,

  /// 监听状态
  ///
  /// 正在监听用户说话，ASR 实时识别
  /// - 录音: ON
  /// - ASR: ON
  /// - VAD: ON
  /// - TTS: OFF
  listening,

  /// 思考状态
  ///
  /// 用户说完，等待 LLM 处理响应
  /// - 录音: ON（可选，用于检测用户是否继续说话）
  /// - ASR: OFF（节省资源）
  /// - VAD: ON
  /// - TTS: OFF
  thinking,

  /// 说话状态
  ///
  /// TTS 播放中，VAD 监听用户打断
  /// - 录音: ON（用于打断检测）
  /// - ASR: OFF（关键！避免回声问题）
  /// - VAD: ON（检测用户打断）
  /// - TTS: ON
  speaking,
}

/// 用户状态
enum UserState {
  /// 空闲
  idle,

  /// 正在说话
  speaking,

  /// 离开（长时间无响应）
  away,
}

/// VoiceSessionState 扩展方法
extension VoiceSessionStateExtension on VoiceSessionState {
  /// 是否应该运行 ASR
  bool get shouldRunASR => this == VoiceSessionState.listening;

  /// 是否应该运行 VAD
  bool get shouldRunVAD =>
      this == VoiceSessionState.listening ||
      this == VoiceSessionState.thinking ||
      this == VoiceSessionState.speaking;

  /// 是否应该运行录音
  bool get shouldRunRecording => this != VoiceSessionState.idle;

  /// 是否可以被用户打断
  bool get isInterruptible => this == VoiceSessionState.speaking;

  /// 是否正在处理中（不应接收新命令）
  bool get isProcessing =>
      this == VoiceSessionState.thinking || this == VoiceSessionState.speaking;

  /// 中文描述
  String get displayName {
    switch (this) {
      case VoiceSessionState.idle:
        return '空闲';
      case VoiceSessionState.listening:
        return '监听中';
      case VoiceSessionState.thinking:
        return '思考中';
      case VoiceSessionState.speaking:
        return '说话中';
    }
  }
}

/// 状态变化事件
class VoiceSessionStateChange {
  /// 旧状态
  final VoiceSessionState oldState;

  /// 新状态
  final VoiceSessionState newState;

  /// 变化原因
  final String? reason;

  /// 时间戳
  final DateTime timestamp;

  VoiceSessionStateChange({
    required this.oldState,
    required this.newState,
    this.reason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'StateChange($oldState -> $newState${reason != null ? ', reason: $reason' : ''})';
}
