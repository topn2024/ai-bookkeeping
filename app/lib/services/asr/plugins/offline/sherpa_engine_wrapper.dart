import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Sherpa-ONNX 引擎封装
///
/// 提供本地离线语音识别功能
class SherpaEngineWrapper {
  final SherpaEngineConfig config;
  bool _isInitialized = false;

  SherpaEngineWrapper({SherpaEngineConfig? config})
      : config = config ?? SherpaEngineConfig.defaults();

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化引擎
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('[SherpaEngineWrapper] 开始初始化...');

    // 实际实现需要：
    // 1. 检查模型文件是否存在
    // 2. 通过Platform Channel调用native代码初始化引擎
    // await _channel.invokeMethod('initialize', {
    //   'modelPath': config.modelPath,
    //   'numThreads': config.numThreads,
    //   'sampleRate': config.sampleRate,
    //   'enablePunctuation': config.enablePunctuation,
    // });

    // 模拟初始化
    await Future.delayed(const Duration(milliseconds: 500));
    _isInitialized = true;
    debugPrint('[SherpaEngineWrapper] 初始化完成');
  }

  /// 批量识别
  Future<SherpaResult> transcribe(Uint8List audioData) async {
    if (!_isInitialized) {
      throw StateError('Engine not initialized');
    }

    debugPrint('[SherpaEngineWrapper] 开始识别，音频大小: ${audioData.length} bytes');

    // 实际实现需要：
    // final result = await _channel.invokeMethod('transcribe', {
    //   'audioData': audioData,
    // });
    // return SherpaResult.fromMap(result);

    // 模拟识别
    await Future.delayed(Duration(milliseconds: audioData.length ~/ 32));

    final text = _simulateRecognition(audioData);
    debugPrint('[SherpaEngineWrapper] 识别结果: $text');

    return SherpaResult(
      text: text,
      confidence: 0.85 + (audioData.length % 10) / 100,
      segments: [
        SherpaSegment(
          text: text,
          startTime: 0.0,
          endTime: audioData.length / 32000.0,
          confidence: 0.85,
        ),
      ],
    );
  }

  /// 流式识别
  Stream<SherpaPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    if (!_isInitialized) {
      throw StateError('Engine not initialized');
    }

    debugPrint('[SherpaEngineWrapper] 开始流式识别');

    // 实际实现需要通过EventChannel接收native端的流式结果
    int index = 0;
    final buffer = BytesBuilder();

    await for (final chunk in audioStream) {
      buffer.add(chunk);

      // 每积累约1秒数据进行一次识别
      if (buffer.length >= config.sampleRate * 2) {
        yield SherpaPartialResult(
          text: '识别中...',
          isFinal: false,
          index: index++,
          confidence: 0.7,
        );
      }
    }

    // 最终结果
    final finalData = buffer.toBytes();
    final result = await transcribe(Uint8List.fromList(finalData));

    yield SherpaPartialResult(
      text: result.text,
      isFinal: true,
      index: index,
      confidence: result.confidence,
    );
  }

  /// 模拟识别（开发测试用）
  String _simulateRecognition(Uint8List audioData) {
    final duration = audioData.length / 32000.0;

    if (duration < 2) {
      return '三十块';
    } else if (duration < 4) {
      return '午餐花了三十块';
    } else {
      return '今天午餐在公司食堂花了三十块钱';
    }
  }

  /// 释放资源
  void dispose() {
    // 实际实现：
    // _channel.invokeMethod('dispose');
    _isInitialized = false;
    debugPrint('[SherpaEngineWrapper] 已释放');
  }
}

/// Sherpa引擎配置
class SherpaEngineConfig {
  final String? modelPath;
  final int numThreads;
  final int sampleRate;
  final bool enablePunctuation;
  final bool enableVAD;
  final double vadThreshold;

  const SherpaEngineConfig({
    this.modelPath,
    this.numThreads = 4,
    this.sampleRate = 16000,
    this.enablePunctuation = true,
    this.enableVAD = true,
    this.vadThreshold = 0.5,
  });

  factory SherpaEngineConfig.defaults() {
    return const SherpaEngineConfig();
  }
}

/// Sherpa识别结果
class SherpaResult {
  final String text;
  final double confidence;
  final List<SherpaSegment> segments;

  const SherpaResult({
    required this.text,
    required this.confidence,
    required this.segments,
  });
}

/// Sherpa识别片段
class SherpaSegment {
  final String text;
  final double startTime;
  final double endTime;
  final double confidence;

  const SherpaSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.confidence,
  });
}

/// Sherpa部分结果
class SherpaPartialResult {
  final String text;
  final bool isFinal;
  final int index;
  final double? confidence;

  const SherpaPartialResult({
    required this.text,
    required this.isFinal,
    required this.index,
    this.confidence,
  });
}

// ==================== 模型管理器 ====================

/// 离线模型类型
enum OfflineModelType {
  sherpaOnnxZhSmall, // 中文小模型 ~14MB
  sherpaOnnxZhLarge, // 中文大模型 ~44MB
  sherpaOnnxEnSmall, // 英文小模型 ~20MB
  sherpaOnnxMultilingual, // 多语言模型 ~75MB
}

/// 模型下载信息
class ModelDownloadInfo {
  final String url;
  final int size;
  final String checksum;
  final String version;

  const ModelDownloadInfo({
    required this.url,
    required this.size,
    required this.checksum,
    required this.version,
  });
}

/// 模型信息
class ModelInfo {
  final OfflineModelType type;
  final String path;
  final String version;
  final int size;
  final bool isDownloaded;

  const ModelInfo({
    required this.type,
    required this.path,
    required this.version,
    required this.size,
    required this.isDownloaded,
  });

  String get displayName {
    switch (type) {
      case OfflineModelType.sherpaOnnxZhSmall:
        return '中文小模型 (14MB)';
      case OfflineModelType.sherpaOnnxZhLarge:
        return '中文大模型 (44MB)';
      case OfflineModelType.sherpaOnnxEnSmall:
        return '英文小模型 (20MB)';
      case OfflineModelType.sherpaOnnxMultilingual:
        return '多语言模型 (75MB)';
    }
  }

  String get sizeDisplay {
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 模型管理器
class OfflineModelManager {
  static const String _modelDir = 'asr_models';

  /// 模型下载源
  static const Map<OfflineModelType, ModelDownloadInfo> _modelSources = {
    OfflineModelType.sherpaOnnxZhSmall: ModelDownloadInfo(
      url:
          'https://example.com/models/sherpa-onnx-streaming-zipformer-zh-14M.tar.bz2',
      size: 14 * 1024 * 1024,
      checksum: 'sha256:...',
      version: '1.0.0',
    ),
    OfflineModelType.sherpaOnnxZhLarge: ModelDownloadInfo(
      url:
          'https://example.com/models/sherpa-onnx-streaming-zipformer-zh-44M.tar.bz2',
      size: 44 * 1024 * 1024,
      checksum: 'sha256:...',
      version: '1.0.0',
    ),
    OfflineModelType.sherpaOnnxEnSmall: ModelDownloadInfo(
      url:
          'https://example.com/models/sherpa-onnx-streaming-zipformer-en-20M.tar.bz2',
      size: 20 * 1024 * 1024,
      checksum: 'sha256:...',
      version: '1.0.0',
    ),
    OfflineModelType.sherpaOnnxMultilingual: ModelDownloadInfo(
      url: 'https://example.com/models/sherpa-onnx-whisper-tiny.tar.bz2',
      size: 75 * 1024 * 1024,
      checksum: 'sha256:...',
      version: '1.0.0',
    ),
  };

  /// 获取模型存储路径
  Future<String?> getModelPath(OfflineModelType type) async {
    final dir = await _getModelDir();
    final modelDir = Directory('${dir.path}/${type.name}');

    if (await modelDir.exists()) {
      final encoderFile = File('${modelDir.path}/encoder.onnx');
      final decoderFile = File('${modelDir.path}/decoder.onnx');

      if (await encoderFile.exists() && await decoderFile.exists()) {
        return modelDir.path;
      }
    }

    return null;
  }

  /// 下载模型
  Future<void> downloadModel(
    OfflineModelType type, {
    void Function(double progress)? onProgress,
  }) async {
    final info = _modelSources[type];
    if (info == null) {
      throw OfflineModelException('Unknown model type: $type');
    }

    final dir = await _getModelDir();
    final modelDir = Directory('${dir.path}/${type.name}');

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    // 实际实现需要：
    // 1. 下载压缩包
    // 2. 校验checksum
    // 3. 解压到目标目录

    // 模拟下载
    for (var i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress?.call(i / 100);
    }

    // 创建模拟文件
    await File('${modelDir.path}/encoder.onnx').writeAsString('mock');
    await File('${modelDir.path}/decoder.onnx').writeAsString('mock');
    await File('${modelDir.path}/tokens.txt').writeAsString('mock');

    // 保存模型元信息
    final metaFile = File('${modelDir.path}/meta.json');
    await metaFile.writeAsString('''
{
  "type": "${type.name}",
  "version": "${info.version}",
  "downloadedAt": "${DateTime.now().toIso8601String()}",
  "size": ${info.size}
}
''');

    debugPrint('[OfflineModelManager] 模型下载完成: ${type.name}');
  }

  /// 获取模型信息
  Future<ModelInfo?> getModelInfo(OfflineModelType type) async {
    final modelPath = await getModelPath(type);
    if (modelPath == null) return null;

    final downloadInfo = _modelSources[type];

    return ModelInfo(
      type: type,
      path: modelPath,
      version: downloadInfo?.version ?? 'unknown',
      size: downloadInfo?.size ?? 0,
      isDownloaded: true,
    );
  }

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded(OfflineModelType type) async {
    final path = await getModelPath(type);
    return path != null;
  }

  /// 删除模型
  Future<void> deleteModel(OfflineModelType type) async {
    final modelPath = await getModelPath(type);
    if (modelPath != null) {
      final dir = Directory(modelPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('[OfflineModelManager] 模型已删除: ${type.name}');
      }
    }
  }

  /// 获取模型大小
  int getModelSize(OfflineModelType type) {
    return _modelSources[type]?.size ?? 0;
  }

  /// 获取所有已下载模型
  Future<List<ModelInfo>> getDownloadedModels() async {
    final models = <ModelInfo>[];

    for (final type in OfflineModelType.values) {
      final info = await getModelInfo(type);
      if (info != null) {
        models.add(info);
      }
    }

    return models;
  }

  Future<Directory> _getModelDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_modelDir');
  }
}

// ==================== VAD 语音活动检测 ====================

/// 语音活动检测服务
class VADService {
  final double threshold;
  final int minSpeechDuration;
  final int minSilenceDuration;

  VADService({
    this.threshold = 0.5,
    this.minSpeechDuration = 300, // ms
    this.minSilenceDuration = 500, // ms
  });

  /// 检测语音活动
  List<VADSegment> detect(Uint8List audioData, {int sampleRate = 16000}) {
    final segments = <VADSegment>[];

    // 简化的能量基VAD
    // 实际实现应使用更复杂的算法（如WebRTC VAD或Silero VAD）

    const frameSize = 480; // 30ms at 16kHz
    final numFrames = audioData.length ~/ (frameSize * 2); // 16-bit audio

    bool inSpeech = false;
    int speechStart = 0;
    int silenceCount = 0;

    for (var i = 0; i < numFrames; i++) {
      final frameStart = i * frameSize * 2;
      final frameEnd = frameStart + frameSize * 2;
      if (frameEnd > audioData.length) break;

      final energy = _calculateFrameEnergy(
        audioData.sublist(frameStart, frameEnd),
      );

      final isSpeech = energy > threshold;

      if (isSpeech && !inSpeech) {
        // 语音开始
        inSpeech = true;
        speechStart = i * 30;
        silenceCount = 0;
      } else if (!isSpeech && inSpeech) {
        silenceCount++;
        if (silenceCount * 30 >= minSilenceDuration) {
          // 语音结束
          inSpeech = false;
          final speechEnd = (i - silenceCount) * 30;
          if (speechEnd - speechStart >= minSpeechDuration) {
            segments.add(VADSegment(
              startMs: speechStart,
              endMs: speechEnd,
              isSpeech: true,
            ));
          }
        }
      }
    }

    // 处理最后一个语音段
    if (inSpeech) {
      final speechEnd = numFrames * 30;
      if (speechEnd - speechStart >= minSpeechDuration) {
        segments.add(VADSegment(
          startMs: speechStart,
          endMs: speechEnd,
          isSpeech: true,
        ));
      }
    }

    return segments;
  }

  /// 计算帧能量
  double _calculateFrameEnergy(Uint8List frame) {
    double energy = 0;
    for (var i = 0; i < frame.length - 1; i += 2) {
      final sample = (frame[i + 1] << 8) | frame[i];
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      energy += signedSample * signedSample;
    }
    return energy / (frame.length / 2);
  }
}

/// VAD片段
class VADSegment {
  final int startMs;
  final int endMs;
  final bool isSpeech;

  const VADSegment({
    required this.startMs,
    required this.endMs,
    required this.isSpeech,
  });

  Duration get duration => Duration(milliseconds: endMs - startMs);
}

// ==================== 异常类 ====================

/// 离线模型异常
class OfflineModelException implements Exception {
  final String message;
  OfflineModelException(this.message);

  @override
  String toString() => 'OfflineModelException: $message';
}

/// 离线ASR初始化异常
class OfflineASRInitException implements Exception {
  final String message;
  OfflineASRInitException(this.message);

  @override
  String toString() => 'OfflineASRInitException: $message';
}
