import 'dart:typed_data';

/// ASR数据模型
///
/// 定义ASR服务的统一数据模型

/// 处理后的音频数据
class ProcessedAudio {
  /// 原始音频数据（PCM格式）
  final Uint8List data;

  /// 音频片段列表
  final List<AudioSegment> segments;

  /// 音频时长
  final Duration duration;

  /// 采样率（默认16000Hz）
  final int sampleRate;

  /// 位深度（默认16bit）
  final int bitDepth;

  /// 声道数（默认单声道）
  final int channels;

  const ProcessedAudio({
    required this.data,
    required this.segments,
    required this.duration,
    this.sampleRate = 16000,
    this.bitDepth = 16,
    this.channels = 1,
  });

  /// 计算音频时长（毫秒）
  int get durationMs => duration.inMilliseconds;

  /// 计算每毫秒的字节数
  int get bytesPerMs => (sampleRate * bitDepth * channels) ~/ 8000;

  /// 从字节数估算时长
  static Duration estimateDuration(
    int bytes, {
    int sampleRate = 16000,
    int bitDepth = 16,
    int channels = 1,
  }) {
    final bytesPerSecond = (sampleRate * bitDepth * channels) ~/ 8;
    final ms = (bytes * 1000) ~/ bytesPerSecond;
    return Duration(milliseconds: ms);
  }

  /// 检查音频是否有效（非静音）
  bool get hasContent {
    if (data.isEmpty) return false;

    int sum = 0;
    for (int i = 0; i < data.length - 1; i += 2) {
      int sample = data[i] | (data[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      sum += sample.abs();
    }
    final avgAmplitude = sum ~/ (data.length ~/ 2);
    return avgAmplitude > 100; // 静音阈值约100
  }

  ProcessedAudio copyWith({
    Uint8List? data,
    List<AudioSegment>? segments,
    Duration? duration,
    int? sampleRate,
    int? bitDepth,
    int? channels,
  }) {
    return ProcessedAudio(
      data: data ?? this.data,
      segments: segments ?? this.segments,
      duration: duration ?? this.duration,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      channels: channels ?? this.channels,
    );
  }
}

/// 音频片段
class AudioSegment {
  /// 开始时间（毫秒）
  final int startMs;

  /// 结束时间（毫秒）
  final int endMs;

  /// 是否为语音
  final bool isSpeech;

  const AudioSegment({
    required this.startMs,
    required this.endMs,
    required this.isSpeech,
  });

  Duration get duration => Duration(milliseconds: endMs - startMs);
}

/// ASR识别结果
class ASRResult {
  /// 识别文本
  final String text;

  /// 置信度（0-1）
  final double confidence;

  /// 单词级别结果
  final List<ASRWord> words;

  /// 音频时长
  final Duration duration;

  /// 是否为离线识别
  final bool isOffline;

  /// 使用的插件ID
  final String? pluginId;

  /// 识别耗时
  final Duration? processingTime;

  const ASRResult({
    required this.text,
    required this.confidence,
    required this.words,
    required this.duration,
    this.isOffline = false,
    this.pluginId,
    this.processingTime,
  });

  /// 创建空结果
  factory ASRResult.empty({Duration? duration}) {
    return ASRResult(
      text: '',
      confidence: 0,
      words: const [],
      duration: duration ?? Duration.zero,
    );
  }

  /// 结果是否为空
  bool get isEmpty => text.trim().isEmpty;

  ASRResult copyWith({
    String? text,
    double? confidence,
    List<ASRWord>? words,
    Duration? duration,
    bool? isOffline,
    String? pluginId,
    Duration? processingTime,
  }) {
    return ASRResult(
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      words: words ?? this.words,
      duration: duration ?? this.duration,
      isOffline: isOffline ?? this.isOffline,
      pluginId: pluginId ?? this.pluginId,
      processingTime: processingTime ?? this.processingTime,
    );
  }
}

/// ASR单词级结果
class ASRWord {
  /// 单词文本
  final String word;

  /// 开始时间（毫秒）
  final int startMs;

  /// 结束时间（毫秒）
  final int endMs;

  /// 置信度
  final double confidence;

  const ASRWord({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.confidence,
  });
}

/// ASR部分结果（流式）
class ASRPartialResult {
  /// 识别文本
  final String text;

  /// 是否为最终结果
  final bool isFinal;

  /// 结果索引
  final int index;

  /// 置信度
  final double? confidence;

  /// 使用的插件ID
  final String? pluginId;

  const ASRPartialResult({
    required this.text,
    required this.isFinal,
    required this.index,
    this.confidence,
    this.pluginId,
  });

  /// 创建空结果
  factory ASRPartialResult.empty({int index = 0}) {
    return ASRPartialResult(
      text: '',
      isFinal: false,
      index: index,
    );
  }
}

/// 热词
class HotWord {
  /// 热词文本
  final String word;

  /// 权重（1.0-5.0）
  final double weight;

  const HotWord(this.word, {this.weight = 1.0});

  Map<String, dynamic> toJson() => {
        'word': word,
        'weight': weight,
      };
}

/// ASR可用性状态
class ASRAvailability {
  /// 是否可用
  final bool isAvailable;

  /// 不可用原因
  final String? reason;

  /// 预计恢复时间
  final DateTime? estimatedRecoveryTime;

  const ASRAvailability({
    required this.isAvailable,
    this.reason,
    this.estimatedRecoveryTime,
  });

  /// 可用状态
  factory ASRAvailability.available() {
    return const ASRAvailability(isAvailable: true);
  }

  /// 不可用状态
  factory ASRAvailability.unavailable(String reason,
      {DateTime? estimatedRecoveryTime}) {
    return ASRAvailability(
      isAvailable: false,
      reason: reason,
      estimatedRecoveryTime: estimatedRecoveryTime,
    );
  }
}
