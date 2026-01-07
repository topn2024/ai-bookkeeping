import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 离线语音识别服务
///
/// 功能：
/// 1. 本地Sherpa-ONNX语音识别引擎
/// 2. 模型下载与管理
/// 3. 多语言支持（中文/英文）
/// 4. 流式识别与批量识别
/// 5. VAD（语音活动检测）
class OfflineASRService {
  final OfflineASRConfig _config;
  final ModelManager _modelManager;
  SherpaOnnxEngine? _engine;
  bool _isInitialized = false;
  bool _isInitializing = false;

  final _initStateController = StreamController<ASRInitState>.broadcast();

  OfflineASRService({
    OfflineASRConfig? config,
    ModelManager? modelManager,
  })  : _config = config ?? OfflineASRConfig.defaultConfig(),
        _modelManager = modelManager ?? ModelManager();

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化状态流
  Stream<ASRInitState> get initStateStream => _initStateController.stream;

  /// 初始化离线识别引擎
  Future<void> initialize({bool forceDownload = false}) async {
    if (_isInitialized) return;
    if (_isInitializing) return;

    _isInitializing = true;
    _initStateController.add(ASRInitState.checking);

    try {
      // 1. 检查模型是否存在
      final modelPath = await _modelManager.getModelPath(_config.modelType);

      if (modelPath == null || forceDownload) {
        // 2. 下载模型
        _initStateController.add(ASRInitState.downloading);
        await _modelManager.downloadModel(
          _config.modelType,
          onProgress: (progress) {
            _initStateController.add(ASRInitState.downloading);
          },
        );
      }

      // 3. 加载模型
      _initStateController.add(ASRInitState.loading);
      final finalModelPath = await _modelManager.getModelPath(_config.modelType);
      if (finalModelPath == null) {
        throw ASRInitException('Model not found after download');
      }

      _engine = SherpaOnnxEngine(
        modelPath: finalModelPath,
        config: _config,
      );
      await _engine!.initialize();

      _isInitialized = true;
      _initStateController.add(ASRInitState.ready);
      debugPrint('Offline ASR initialized with model: ${_config.modelType.name}');
    } catch (e) {
      _initStateController.add(ASRInitState.error);
      debugPrint('Offline ASR initialization failed: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// 批量识别（完整音频）
  Future<OfflineASRResult> transcribe(Uint8List audioData) async {
    if (!_isInitialized) {
      await initialize();
    }

    final stopwatch = Stopwatch()..start();

    try {
      final result = await _engine!.transcribe(audioData);
      stopwatch.stop();

      return OfflineASRResult(
        text: result.text,
        confidence: result.confidence,
        segments: result.segments,
        processingTime: stopwatch.elapsed,
        isOffline: true,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Offline transcription failed: $e');
      rethrow;
    }
  }

  /// 流式识别
  Stream<OfflineASRPartialResult> transcribeStream(
    Stream<Uint8List> audioStream,
  ) async* {
    if (!_isInitialized) {
      await initialize();
    }

    await for (final result in _engine!.transcribeStream(audioStream)) {
      yield result;
    }
  }

  /// 获取模型信息
  Future<ModelInfo?> getModelInfo() async {
    return await _modelManager.getModelInfo(_config.modelType);
  }

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded() async {
    final path = await _modelManager.getModelPath(_config.modelType);
    return path != null;
  }

  /// 删除模型
  Future<void> deleteModel() async {
    if (_isInitialized) {
      _engine?.dispose();
      _engine = null;
      _isInitialized = false;
    }
    await _modelManager.deleteModel(_config.modelType);
  }

  /// 获取模型大小
  Future<int> getModelSize() async {
    return _modelManager.getModelSize(_config.modelType);
  }

  /// 释放资源
  void dispose() {
    _engine?.dispose();
    _initStateController.close();
  }
}

// ==================== Sherpa-ONNX 引擎 ====================

/// Sherpa-ONNX 本地识别引擎
class SherpaOnnxEngine {
  final String modelPath;
  final OfflineASRConfig config;
  bool _isInitialized = false;

  // 实际实现需要通过Platform Channel调用native代码
  // 这里提供完整的接口定义

  SherpaOnnxEngine({
    required this.modelPath,
    required this.config,
  });

  /// 初始化引擎
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 实际实现：
    // await _channel.invokeMethod('initialize', {
    //   'modelPath': modelPath,
    //   'numThreads': config.numThreads,
    //   'sampleRate': config.sampleRate,
    //   'enablePunctuation': config.enablePunctuation,
    // });

    // 模拟初始化
    await Future.delayed(const Duration(milliseconds: 500));
    _isInitialized = true;
    debugPrint('SherpaOnnxEngine initialized: $modelPath');
  }

  /// 批量识别
  Future<SherpaResult> transcribe(Uint8List audioData) async {
    if (!_isInitialized) {
      throw ASRException('Engine not initialized');
    }

    // 实际实现：
    // final result = await _channel.invokeMethod('transcribe', {
    //   'audioData': audioData,
    // });
    // return SherpaResult.fromMap(result);

    // 模拟识别（实际使用时替换为native调用）
    await Future.delayed(Duration(milliseconds: audioData.length ~/ 32));

    return SherpaResult(
      text: _simulateRecognition(audioData),
      confidence: 0.85 + (audioData.length % 10) / 100,
      segments: [
        SherpaSegment(
          text: '识别结果',
          startTime: 0.0,
          endTime: audioData.length / 32000.0,
          confidence: 0.85,
        ),
      ],
    );
  }

  /// 流式识别
  Stream<OfflineASRPartialResult> transcribeStream(
    Stream<Uint8List> audioStream,
  ) async* {
    if (!_isInitialized) {
      throw ASRException('Engine not initialized');
    }

    // 实际实现需要通过EventChannel接收native端的流式结果
    int index = 0;
    final buffer = BytesBuilder();

    await for (final chunk in audioStream) {
      buffer.add(chunk);

      // 每积累一定数据量进行一次识别
      if (buffer.length >= config.sampleRate * 2) { // 1秒数据
        // 模拟部分识别结果
        yield OfflineASRPartialResult(
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

    yield OfflineASRPartialResult(
      text: result.text,
      isFinal: true,
      index: index,
      confidence: result.confidence,
    );
  }

  /// 模拟识别（开发测试用）
  String _simulateRecognition(Uint8List audioData) {
    // 根据音频长度模拟不同结果
    final duration = audioData.length / 32000.0; // 假设16kHz单声道

    if (duration < 2) {
      return '三十块';
    } else if (duration < 4) {
      return '午餐花了三十块';
    } else {
      return '今天午餐在公司食堂花了三十块钱';
    }
  }

  void dispose() {
    // 实际实现：
    // _channel.invokeMethod('dispose');
    _isInitialized = false;
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

// ==================== 模型管理器 ====================

/// 模型管理器
class ModelManager {
  static const String _modelDir = 'asr_models';

  /// 模型下载源
  static const Map<OfflineModelType, ModelDownloadInfo> _modelSources = {
    OfflineModelType.sherpaOnnxZhSmall: ModelDownloadInfo(
      url: 'https://example.com/models/sherpa-onnx-streaming-zipformer-zh-14M.tar.bz2',
      size: 14 * 1024 * 1024, // 14MB
      checksum: 'sha256:...',
      version: '1.0.0',
    ),
    OfflineModelType.sherpaOnnxZhLarge: ModelDownloadInfo(
      url: 'https://example.com/models/sherpa-onnx-streaming-zipformer-zh-44M.tar.bz2',
      size: 44 * 1024 * 1024, // 44MB
      checksum: 'sha256:...',
      version: '1.0.0',
    ),
    OfflineModelType.sherpaOnnxEnSmall: ModelDownloadInfo(
      url: 'https://example.com/models/sherpa-onnx-streaming-zipformer-en-20M.tar.bz2',
      size: 20 * 1024 * 1024, // 20MB
      checksum: 'sha256:...',
      version: '1.0.0',
    ),
    OfflineModelType.sherpaOnnxMultilingual: ModelDownloadInfo(
      url: 'https://example.com/models/sherpa-onnx-whisper-tiny.tar.bz2',
      size: 75 * 1024 * 1024, // 75MB
      checksum: 'sha256:...',
      version: '1.0.0',
    ),
  };

  /// 获取模型存储路径
  Future<String?> getModelPath(OfflineModelType type) async {
    final dir = await _getModelDir();
    final modelDir = Directory('${dir.path}/${type.name}');

    if (await modelDir.exists()) {
      // 检查模型文件是否完整
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
      throw ModelException('Unknown model type: $type');
    }

    final dir = await _getModelDir();
    final modelDir = Directory('${dir.path}/${type.name}');

    // 创建目录
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    // 实际实现需要：
    // 1. 下载压缩包
    // 2. 校验checksum
    // 3. 解压到目标目录

    // 模拟下载过程
    for (var i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress?.call(i / 100);
    }

    // 创建模拟模型文件
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

    debugPrint('Model downloaded: ${type.name}');
  }

  /// 获取模型信息
  Future<ModelInfo?> getModelInfo(OfflineModelType type) async {
    final modelPath = await getModelPath(type);
    if (modelPath == null) return null;

    final metaFile = File('$modelPath/meta.json');
    if (!await metaFile.exists()) return null;

    // 解析元信息
    final downloadInfo = _modelSources[type];

    return ModelInfo(
      type: type,
      path: modelPath,
      version: downloadInfo?.version ?? 'unknown',
      size: downloadInfo?.size ?? 0,
      isDownloaded: true,
    );
  }

  /// 删除模型
  Future<void> deleteModel(OfflineModelType type) async {
    final modelPath = await getModelPath(type);
    if (modelPath != null) {
      final dir = Directory(modelPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('Model deleted: ${type.name}');
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

  /// 获取模型目录
  Future<Directory> _getModelDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_modelDir');
  }
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

// ==================== 数据模型 ====================

/// 离线ASR配置
class OfflineASRConfig {
  final OfflineModelType modelType;
  final int sampleRate;
  final int numThreads;
  final bool enablePunctuation;
  final bool enableVAD;
  final double vadThreshold;

  const OfflineASRConfig({
    required this.modelType,
    this.sampleRate = 16000,
    this.numThreads = 4,
    this.enablePunctuation = true,
    this.enableVAD = true,
    this.vadThreshold = 0.5,
  });

  factory OfflineASRConfig.defaultConfig() {
    return const OfflineASRConfig(
      modelType: OfflineModelType.sherpaOnnxZhSmall,
    );
  }

  OfflineASRConfig copyWith({
    OfflineModelType? modelType,
    int? sampleRate,
    int? numThreads,
    bool? enablePunctuation,
    bool? enableVAD,
    double? vadThreshold,
  }) {
    return OfflineASRConfig(
      modelType: modelType ?? this.modelType,
      sampleRate: sampleRate ?? this.sampleRate,
      numThreads: numThreads ?? this.numThreads,
      enablePunctuation: enablePunctuation ?? this.enablePunctuation,
      enableVAD: enableVAD ?? this.enableVAD,
      vadThreshold: vadThreshold ?? this.vadThreshold,
    );
  }
}

/// 离线模型类型
enum OfflineModelType {
  sherpaOnnxZhSmall,     // 中文小模型 ~14MB
  sherpaOnnxZhLarge,     // 中文大模型 ~44MB
  sherpaOnnxEnSmall,     // 英文小模型 ~20MB
  sherpaOnnxMultilingual, // 多语言模型 ~75MB
}

/// 离线ASR结果
class OfflineASRResult {
  final String text;
  final double confidence;
  final List<SherpaSegment> segments;
  final Duration processingTime;
  final bool isOffline;

  const OfflineASRResult({
    required this.text,
    required this.confidence,
    required this.segments,
    required this.processingTime,
    this.isOffline = true,
  });
}

/// 离线ASR部分结果
class OfflineASRPartialResult {
  final String text;
  final bool isFinal;
  final int index;
  final double? confidence;

  const OfflineASRPartialResult({
    required this.text,
    required this.isFinal,
    required this.index,
    this.confidence,
  });
}

/// ASR初始化状态
enum ASRInitState {
  checking,    // 检查模型
  downloading, // 下载模型
  loading,     // 加载模型
  ready,       // 准备就绪
  error,       // 初始化失败
}

/// ASR异常
class ASRException implements Exception {
  final String message;
  ASRException(this.message);

  @override
  String toString() => 'ASRException: $message';
}

/// ASR初始化异常
class ASRInitException implements Exception {
  final String message;
  ASRInitException(this.message);

  @override
  String toString() => 'ASRInitException: $message';
}

/// 模型异常
class ModelException implements Exception {
  final String message;
  ModelException(this.message);

  @override
  String toString() => 'ModelException: $message';
}

// ==================== VAD 语音活动检测 ====================

/// 语音活动检测服务
class VADService {
  final double threshold;
  final int minSpeechDuration;
  final int minSilenceDuration;

  VADService({
    this.threshold = 0.5,
    this.minSpeechDuration = 300,  // ms
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
      final energy = _calculateFrameEnergy(
        audioData.sublist(frameStart, frameStart + frameSize * 2),
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

// ==================== 离线ASR管理器 ====================

/// 离线ASR管理器（单例）
class OfflineASRManager {
  static final OfflineASRManager _instance = OfflineASRManager._internal();
  factory OfflineASRManager() => _instance;
  OfflineASRManager._internal();

  OfflineASRService? _service;
  final _modelManager = ModelManager();

  /// 获取服务实例
  OfflineASRService getService({OfflineASRConfig? config}) {
    _service ??= OfflineASRService(
      config: config,
      modelManager: _modelManager,
    );
    return _service!;
  }

  /// 预初始化（在后台下载和加载模型）
  Future<void> preInitialize({
    OfflineModelType modelType = OfflineModelType.sherpaOnnxZhSmall,
    void Function(double progress)? onProgress,
  }) async {
    final service = getService(
      config: OfflineASRConfig(modelType: modelType),
    );

    // 检查是否已下载
    if (!await service.isModelDownloaded()) {
      // 下载模型
      await _modelManager.downloadModel(
        modelType,
        onProgress: onProgress,
      );
    }

    // 初始化引擎
    await service.initialize();
  }

  /// 获取推荐模型
  OfflineModelType getRecommendedModel() {
    // 根据设备性能选择模型
    // 实际实现应检测设备RAM和CPU
    return OfflineModelType.sherpaOnnxZhSmall;
  }

  /// 获取所有可用模型
  List<OfflineModelType> getAvailableModels() {
    return OfflineModelType.values;
  }

  /// 释放资源
  void dispose() {
    _service?.dispose();
    _service = null;
  }
}
