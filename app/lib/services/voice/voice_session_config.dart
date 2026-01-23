/// 语音会话配置
///
/// 参考 LiveKit VoicePipelineAgent 参数设计
class VoiceSessionConfig {
  /// 是否允许用户打断 TTS 播放
  ///
  /// LiveKit: allow_interruptions = True
  final bool allowInterruptions;

  /// 打断确认延迟
  ///
  /// 用户说话持续多久才算真正的打断（避免误检）
  /// LiveKit: min_interruption_duration = 0.5s
  final Duration interruptionConfirmDelay;

  /// 假打断超时
  ///
  /// 打断后多久没有有效 ASR 结果算作假打断
  /// LiveKit: false_interruption_timeout = 2.0s
  final Duration falseInterruptionTimeout;

  /// 是否恢复假打断
  ///
  /// 假打断后是否恢复 TTS 播放
  /// LiveKit: resume_false_interruption = True
  final bool resumeFalseInterruption;

  /// 最小静音时间（判定用户说完）
  ///
  /// VAD 检测到静音持续多久才判定用户说完
  /// LiveKit: min_endpointing_delay = 0.5s
  final Duration minEndpointingDelay;

  /// 最大等待时间（强制结束用户输入）
  ///
  /// 用户说话后最多等待多久
  /// LiveKit: max_endpointing_delay = 3.0s
  final Duration maxEndpointingDelay;

  /// 静默超时（触发主动对话）
  ///
  /// 用户开启助手后多久没说话触发主动提示
  final Duration silenceTimeout;

  /// 用户离开超时
  ///
  /// 多久没有任何交互判定用户离开
  /// LiveKit: user_away_timeout = 15.0s
  final Duration userAwayTimeout;

  /// 不可打断时丢弃音频缓冲
  ///
  /// 当 allowInterruptions=false 时，是否丢弃用户音频
  /// LiveKit: discard_audio_if_uninterruptible = True
  final bool discardAudioIfUninterruptible;

  const VoiceSessionConfig({
    this.allowInterruptions = true,
    this.interruptionConfirmDelay = const Duration(milliseconds: 500),
    this.falseInterruptionTimeout = const Duration(seconds: 2),
    this.resumeFalseInterruption = true,
    this.minEndpointingDelay = const Duration(milliseconds: 500),
    this.maxEndpointingDelay = const Duration(seconds: 3),
    this.silenceTimeout = const Duration(seconds: 5),
    this.userAwayTimeout = const Duration(seconds: 15),
    this.discardAudioIfUninterruptible = true,
  });

  /// 默认配置
  static const defaultConfig = VoiceSessionConfig();

  /// 保守配置（减少误打断）
  ///
  /// 适用于嘈杂环境或容易误触发的场景
  static const conservative = VoiceSessionConfig(
    interruptionConfirmDelay: Duration(milliseconds: 800),
    falseInterruptionTimeout: Duration(seconds: 3),
    minEndpointingDelay: Duration(milliseconds: 800),
  );

  /// 灵敏配置（快速响应）
  ///
  /// 适用于安静环境，追求快速响应
  static const sensitive = VoiceSessionConfig(
    interruptionConfirmDelay: Duration(milliseconds: 300),
    falseInterruptionTimeout: Duration(milliseconds: 1500),
    minEndpointingDelay: Duration(milliseconds: 300),
  );

  /// 禁用打断配置
  ///
  /// 不允许用户打断，适用于重要提示播放
  static const noInterruption = VoiceSessionConfig(
    allowInterruptions: false,
  );

  /// 复制并修改配置
  VoiceSessionConfig copyWith({
    bool? allowInterruptions,
    Duration? interruptionConfirmDelay,
    Duration? falseInterruptionTimeout,
    bool? resumeFalseInterruption,
    Duration? minEndpointingDelay,
    Duration? maxEndpointingDelay,
    Duration? silenceTimeout,
    Duration? userAwayTimeout,
    bool? discardAudioIfUninterruptible,
  }) {
    return VoiceSessionConfig(
      allowInterruptions: allowInterruptions ?? this.allowInterruptions,
      interruptionConfirmDelay:
          interruptionConfirmDelay ?? this.interruptionConfirmDelay,
      falseInterruptionTimeout:
          falseInterruptionTimeout ?? this.falseInterruptionTimeout,
      resumeFalseInterruption:
          resumeFalseInterruption ?? this.resumeFalseInterruption,
      minEndpointingDelay: minEndpointingDelay ?? this.minEndpointingDelay,
      maxEndpointingDelay: maxEndpointingDelay ?? this.maxEndpointingDelay,
      silenceTimeout: silenceTimeout ?? this.silenceTimeout,
      userAwayTimeout: userAwayTimeout ?? this.userAwayTimeout,
      discardAudioIfUninterruptible:
          discardAudioIfUninterruptible ?? this.discardAudioIfUninterruptible,
    );
  }

  @override
  String toString() {
    return 'VoiceSessionConfig('
        'allowInterruptions: $allowInterruptions, '
        'interruptionConfirmDelay: ${interruptionConfirmDelay.inMilliseconds}ms, '
        'falseInterruptionTimeout: ${falseInterruptionTimeout.inMilliseconds}ms, '
        'minEndpointingDelay: ${minEndpointingDelay.inMilliseconds}ms'
        ')';
  }
}
