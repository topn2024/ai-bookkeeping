import 'asr_models.dart';

/// ASR配置模块
///
/// 定义ASR插件的配置类

/// ASR插件配置
class ASRPluginConfig {
  /// 默认超时时间（秒）
  final int timeoutSeconds;

  /// 最大重试次数
  final int maxRetries;

  /// 重试基础延迟（毫秒）
  final int baseRetryDelayMs;

  /// 最大识别时间（秒）
  final int maxRecognitionSeconds;

  /// 静音超时时间（秒）
  final int silenceTimeoutSeconds;

  /// 采样率
  final int sampleRate;

  /// 是否启用标点预测
  final bool enablePunctuation;

  /// 是否启用数字逆转换
  final bool enableInverseTextNormalization;

  /// 热词列表
  final List<HotWord> hotWords;

  /// 语言
  final String language;

  /// 自定义参数
  final Map<String, dynamic> customParams;

  const ASRPluginConfig({
    this.timeoutSeconds = 10,
    this.maxRetries = 3,
    this.baseRetryDelayMs = 500,
    this.maxRecognitionSeconds = 60,
    this.silenceTimeoutSeconds = 3,
    this.sampleRate = 16000,
    this.enablePunctuation = true,
    this.enableInverseTextNormalization = true,
    this.hotWords = const [],
    this.language = 'zh-CN',
    this.customParams = const {},
  });

  /// 默认配置
  factory ASRPluginConfig.defaults() {
    return const ASRPluginConfig();
  }

  ASRPluginConfig copyWith({
    int? timeoutSeconds,
    int? maxRetries,
    int? baseRetryDelayMs,
    int? maxRecognitionSeconds,
    int? silenceTimeoutSeconds,
    int? sampleRate,
    bool? enablePunctuation,
    bool? enableInverseTextNormalization,
    List<HotWord>? hotWords,
    String? language,
    Map<String, dynamic>? customParams,
  }) {
    return ASRPluginConfig(
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      maxRetries: maxRetries ?? this.maxRetries,
      baseRetryDelayMs: baseRetryDelayMs ?? this.baseRetryDelayMs,
      maxRecognitionSeconds:
          maxRecognitionSeconds ?? this.maxRecognitionSeconds,
      silenceTimeoutSeconds:
          silenceTimeoutSeconds ?? this.silenceTimeoutSeconds,
      sampleRate: sampleRate ?? this.sampleRate,
      enablePunctuation: enablePunctuation ?? this.enablePunctuation,
      enableInverseTextNormalization:
          enableInverseTextNormalization ?? this.enableInverseTextNormalization,
      hotWords: hotWords ?? this.hotWords,
      language: language ?? this.language,
      customParams: customParams ?? this.customParams,
    );
  }
}

/// 错误处理配置
class ASRErrorHandlingConfig {
  /// 默认超时时间（秒）
  static const int defaultTimeoutSeconds = 10;

  /// 最大重试次数
  static const int maxRetries = 3;

  /// 重试基础延迟（毫秒）
  static const int baseRetryDelayMs = 500;

  /// 最大识别时间（秒）
  static const int maxRecognitionSeconds = 60;

  /// 静音超时时间（秒）
  static const int silenceTimeoutSeconds = 3;

  const ASRErrorHandlingConfig._();
}
