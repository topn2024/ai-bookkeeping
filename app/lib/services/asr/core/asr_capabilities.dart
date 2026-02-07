/// ASR能力描述
///
/// 描述ASR插件支持的功能特性

/// ASR能力描述
class ASRCapabilities {
  /// 是否支持流式识别
  final bool supportsStreaming;

  /// 是否支持批量识别
  final bool supportsBatch;

  /// 是否需要网络
  final bool requiresNetwork;

  /// 支持的语言列表
  final List<String> supportedLanguages;

  /// 支持的音频格式
  final List<String> supportedFormats;

  /// 最大音频时长（秒）
  final int maxDurationSeconds;

  /// 最大音频大小（字节）
  final int maxAudioSizeBytes;

  /// 支持的采样率列表
  final List<int> supportedSampleRates;

  /// 是否支持热词
  final bool supportsHotWords;

  /// 是否支持标点预测
  final bool supportsPunctuation;

  /// 是否支持语音活动检测
  final bool supportsVAD;

  /// 是否支持说话人分离
  final bool supportsSpeakerDiarization;

  /// 是否支持情感识别
  final bool supportsEmotionDetection;

  /// 预计延迟（毫秒）
  final int estimatedLatencyMs;

  const ASRCapabilities({
    this.supportsStreaming = true,
    this.supportsBatch = true,
    this.requiresNetwork = true,
    this.supportedLanguages = const ['zh-CN'],
    this.supportedFormats = const ['pcm', 'wav'],
    this.maxDurationSeconds = 60,
    this.maxAudioSizeBytes = 10 * 1024 * 1024, // 10MB
    this.supportedSampleRates = const [16000],
    this.supportsHotWords = false,
    this.supportsPunctuation = true,
    this.supportsVAD = false,
    this.supportsSpeakerDiarization = false,
    this.supportsEmotionDetection = false,
    this.estimatedLatencyMs = 500,
  });

  /// 检查是否支持指定语言
  bool supportsLanguage(String language) {
    return supportedLanguages.contains(language);
  }

  /// 检查是否支持指定采样率
  bool supportsSampleRate(int sampleRate) {
    return supportedSampleRates.contains(sampleRate);
  }

  /// 检查音频是否在限制范围内
  bool isAudioAcceptable({
    required int durationSeconds,
    required int sizeBytes,
  }) {
    return durationSeconds <= maxDurationSeconds &&
        sizeBytes <= maxAudioSizeBytes;
  }

  /// 在线ASR默认能力
  factory ASRCapabilities.online() {
    return const ASRCapabilities(
      supportsStreaming: true,
      supportsBatch: true,
      requiresNetwork: true,
      supportedLanguages: ['zh-CN', 'en-US'],
      supportedFormats: ['pcm', 'wav'],
      maxDurationSeconds: 60,
      supportedSampleRates: [16000],
      supportsHotWords: true,
      supportsPunctuation: true,
      supportsVAD: true,
      estimatedLatencyMs: 300,
    );
  }

  /// 离线ASR默认能力
  factory ASRCapabilities.offline() {
    return const ASRCapabilities(
      supportsStreaming: true,
      supportsBatch: true,
      requiresNetwork: false,
      supportedLanguages: ['zh-CN'],
      supportedFormats: ['pcm', 'wav'],
      maxDurationSeconds: 300, // 离线可以更长
      supportedSampleRates: [16000],
      supportsHotWords: false,
      supportsPunctuation: true,
      supportsVAD: true,
      estimatedLatencyMs: 100,
    );
  }

  ASRCapabilities copyWith({
    bool? supportsStreaming,
    bool? supportsBatch,
    bool? requiresNetwork,
    List<String>? supportedLanguages,
    List<String>? supportedFormats,
    int? maxDurationSeconds,
    int? maxAudioSizeBytes,
    List<int>? supportedSampleRates,
    bool? supportsHotWords,
    bool? supportsPunctuation,
    bool? supportsVAD,
    bool? supportsSpeakerDiarization,
    bool? supportsEmotionDetection,
    int? estimatedLatencyMs,
  }) {
    return ASRCapabilities(
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      supportsBatch: supportsBatch ?? this.supportsBatch,
      requiresNetwork: requiresNetwork ?? this.requiresNetwork,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      supportedFormats: supportedFormats ?? this.supportedFormats,
      maxDurationSeconds: maxDurationSeconds ?? this.maxDurationSeconds,
      maxAudioSizeBytes: maxAudioSizeBytes ?? this.maxAudioSizeBytes,
      supportedSampleRates: supportedSampleRates ?? this.supportedSampleRates,
      supportsHotWords: supportsHotWords ?? this.supportsHotWords,
      supportsPunctuation: supportsPunctuation ?? this.supportsPunctuation,
      supportsVAD: supportsVAD ?? this.supportsVAD,
      supportsSpeakerDiarization:
          supportsSpeakerDiarization ?? this.supportsSpeakerDiarization,
      supportsEmotionDetection:
          supportsEmotionDetection ?? this.supportsEmotionDetection,
      estimatedLatencyMs: estimatedLatencyMs ?? this.estimatedLatencyMs,
    );
  }
}
