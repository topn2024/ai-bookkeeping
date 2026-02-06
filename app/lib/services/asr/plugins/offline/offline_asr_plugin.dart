import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/asr_capabilities.dart';
import '../../core/asr_config.dart';
import '../../core/asr_exception.dart';
import '../../core/asr_models.dart';
import '../../core/asr_plugin_interface.dart';
import 'sherpa_engine_wrapper.dart';

/// 离线ASR初始化状态
enum OfflineASRInitState {
  notStarted,
  checkingModel,
  downloadingModel,
  initializingEngine,
  ready,
  error,
}

/// 离线ASR初始化进度
class OfflineASRInitProgress {
  final OfflineASRInitState state;
  final double progress; // 0.0 - 1.0
  final String? message;
  final String? error;

  const OfflineASRInitProgress({
    required this.state,
    this.progress = 0.0,
    this.message,
    this.error,
  });

  factory OfflineASRInitProgress.notStarted() {
    return const OfflineASRInitProgress(state: OfflineASRInitState.notStarted);
  }

  factory OfflineASRInitProgress.checking() {
    return const OfflineASRInitProgress(
      state: OfflineASRInitState.checkingModel,
      progress: 0.1,
      message: '检查模型...',
    );
  }

  factory OfflineASRInitProgress.downloading(double downloadProgress) {
    return OfflineASRInitProgress(
      state: OfflineASRInitState.downloadingModel,
      progress: 0.1 + downloadProgress * 0.7, // 10% - 80%
      message: '下载模型中 ${(downloadProgress * 100).toInt()}%',
    );
  }

  factory OfflineASRInitProgress.initializing() {
    return const OfflineASRInitProgress(
      state: OfflineASRInitState.initializingEngine,
      progress: 0.9,
      message: '初始化引擎...',
    );
  }

  factory OfflineASRInitProgress.ready() {
    return const OfflineASRInitProgress(
      state: OfflineASRInitState.ready,
      progress: 1.0,
      message: '准备就绪',
    );
  }

  factory OfflineASRInitProgress.error(String errorMsg) {
    return OfflineASRInitProgress(
      state: OfflineASRInitState.error,
      progress: 0.0,
      error: errorMsg,
    );
  }
}

/// 离线ASR插件
///
/// 使用Sherpa-ONNX进行本地离线语音识别
/// 支持：
/// - 批量识别
/// - 流式识别
/// - VAD语音活动检测
/// - 多种模型选择
class OfflineASRPlugin extends ASRPluginBase {
  final OfflineModelManager _modelManager;
  OfflineModelType _modelType;
  SherpaEngineWrapper? _engine;
  VADService? _vadService;

  /// 是否已取消
  bool _isCancelled = false;

  /// 当前会话ID
  int _currentSessionId = 0;

  /// 初始化进度流控制器
  final StreamController<OfflineASRInitProgress> _initProgressController =
      StreamController<OfflineASRInitProgress>.broadcast();

  /// 初始化进度流
  Stream<OfflineASRInitProgress> get initProgressStream =>
      _initProgressController.stream;

  /// 当前初始化进度
  OfflineASRInitProgress _currentProgress = OfflineASRInitProgress.notStarted();

  /// 获取当前初始化进度
  OfflineASRInitProgress get currentProgress => _currentProgress;

  /// 是否启用VAD
  bool _enableVAD = true;

  OfflineASRPlugin({
    OfflineModelManager? modelManager,
    OfflineModelType modelType = OfflineModelType.sherpaOnnxZhSmall,
    bool enableVAD = true,
  })  : _modelManager = modelManager ?? OfflineModelManager(),
        _modelType = modelType,
        _enableVAD = enableVAD;

  @override
  String get pluginId => 'offline_sherpa';

  @override
  String get displayName => '离线语音识别';

  @override
  int get priority => 100; // 最低优先级（兜底）

  @override
  ASRCapabilities get capabilities => ASRCapabilities.offline().copyWith(
        supportsStreaming: true,
        supportsBatch: true,
        requiresNetwork: false,
        supportedLanguages: _getSupportedLanguages(),
        maxDurationSeconds: 300,
        supportsHotWords: false,
        supportsPunctuation: true,
        supportsVAD: true,
        estimatedLatencyMs: 100,
      );

  /// 根据模型类型获取支持的语言
  List<String> _getSupportedLanguages() {
    switch (_modelType) {
      case OfflineModelType.sherpaOnnxZhSmall:
      case OfflineModelType.sherpaOnnxZhLarge:
        return ['zh-CN'];
      case OfflineModelType.sherpaOnnxEnSmall:
        return ['en-US'];
      case OfflineModelType.sherpaOnnxMultilingual:
        return ['zh-CN', 'en-US', 'ja-JP', 'ko-KR'];
    }
  }

  /// 获取当前模型类型
  OfflineModelType get modelType => _modelType;

  /// 设置模型类型（需要重新初始化）
  Future<void> setModelType(OfflineModelType type) async {
    if (type == _modelType && _engine != null) {
      return;
    }

    // 释放当前引擎
    if (_engine != null) {
      _engine!.dispose();
      _engine = null;
    }

    _modelType = type;
    state = ASRPluginState.uninitialized;

    debugPrint('[OfflineASRPlugin] 模型类型已切换为: ${type.name}');
  }

  /// 是否启用VAD
  bool get enableVAD => _enableVAD;

  /// 设置是否启用VAD
  set enableVAD(bool value) {
    _enableVAD = value;
    if (value && _vadService == null) {
      _vadService = VADService();
    }
  }

  @override
  Future<void> doInitialize({ASRPluginConfig? config}) async {
    debugPrint('[OfflineASRPlugin] 开始初始化...');

    _emitProgress(OfflineASRInitProgress.checking());

    try {
      // 检查模型是否已下载
      final modelPath = await _modelManager.getModelPath(_modelType);
      if (modelPath == null) {
        debugPrint('[OfflineASRPlugin] 模型未下载，开始下载...');

        await _modelManager.downloadModel(
          _modelType,
          onProgress: (progress) {
            _emitProgress(OfflineASRInitProgress.downloading(progress));
            debugPrint(
                '[OfflineASRPlugin] 下载进度: ${(progress * 100).toInt()}%');
          },
        );
      }

      _emitProgress(OfflineASRInitProgress.initializing());

      // 获取模型路径
      final finalModelPath = await _modelManager.getModelPath(_modelType);
      if (finalModelPath == null) {
        throw OfflineASRInitException('模型下载失败');
      }

      // 初始化引擎
      _engine = SherpaEngineWrapper(
        config: SherpaEngineConfig(
          modelPath: finalModelPath,
          numThreads: 4,
          sampleRate: 16000,
          enablePunctuation: true,
          enableVAD: _enableVAD,
        ),
      );
      await _engine!.initialize();

      // 初始化VAD服务
      if (_enableVAD) {
        _vadService = VADService(
          threshold: 0.5,
          minSpeechDuration: 300,
          minSilenceDuration: 500,
        );
      }

      _emitProgress(OfflineASRInitProgress.ready());
      debugPrint('[OfflineASRPlugin] 初始化完成');
    } catch (e) {
      _emitProgress(OfflineASRInitProgress.error(e.toString()));

      if (e is OfflineASRInitException) {
        throw ASRException(
          e.message,
          errorCode: ASRErrorCode.configurationError,
        );
      }
      if (e is OfflineModelException) {
        throw ASRException(
          e.message,
          errorCode: ASRErrorCode.configurationError,
        );
      }
      rethrow;
    }
  }

  /// 发送初始化进度
  void _emitProgress(OfflineASRInitProgress progress) {
    _currentProgress = progress;
    if (!_initProgressController.isClosed) {
      _initProgressController.add(progress);
    }
  }

  @override
  Future<ASRAvailability> checkAvailability() async {
    // 检查模型是否存在
    final modelPath = await _modelManager.getModelPath(_modelType);
    if (modelPath == null) {
      return ASRAvailability.unavailable('离线模型未下载');
    }

    // 检查引擎是否初始化
    if (_engine == null || !_engine!.isInitialized) {
      return ASRAvailability.unavailable('离线引擎未初始化');
    }

    return ASRAvailability.available();
  }

  @override
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    debugPrint(
        '[OfflineASRPlugin] transcribe开始，音频数据: ${audio.data.length} bytes');

    if (_engine == null || !_engine!.isInitialized) {
      await doInitialize();
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 可选：使用VAD检测语音片段
      List<AudioSegment> segments = audio.segments;
      if (_enableVAD && _vadService != null && segments.isEmpty) {
        final vadSegments = _vadService!.detect(audio.data);
        segments = vadSegments
            .where((s) => s.isSpeech)
            .map((s) => AudioSegment(
                  startMs: s.startMs,
                  endMs: s.endMs,
                  isSpeech: s.isSpeech,
                ))
            .toList();
        debugPrint('[OfflineASRPlugin] VAD检测到 ${segments.length} 个语音片段');
      }

      final result = await _engine!.transcribe(audio.data);
      stopwatch.stop();

      debugPrint('[OfflineASRPlugin] 识别完成: ${result.text}');

      // 转换词级别信息
      final words = result.segments
          .map((seg) => ASRWord(
                word: seg.text,
                startMs: (seg.startTime * 1000).round(),
                endMs: (seg.endTime * 1000).round(),
                confidence: seg.confidence,
              ))
          .toList();

      return ASRResult(
        text: result.text,
        confidence: result.confidence,
        words: words,
        duration: audio.duration,
        isOffline: true,
        pluginId: pluginId,
        processingTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[OfflineASRPlugin] 识别失败: $e');

      if (e is ASRException) {
        rethrow;
      }

      throw ASRException(
        '离线识别失败: $e',
        errorCode: ASRErrorCode.unknown,
      );
    }
  }

  @override
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    debugPrint('[OfflineASRPlugin] transcribeStream 开始');

    if (_engine == null || !_engine!.isInitialized) {
      await doInitialize();
    }

    _currentSessionId++;
    final sessionId = _currentSessionId;
    state = ASRPluginState.recognizing;
    _isCancelled = false;

    int index = 0;

    try {
      await for (final partial in _engine!.transcribeStream(audioStream)) {
        if (_isCancelled || sessionId != _currentSessionId) {
          debugPrint('[OfflineASRPlugin] 识别已取消');
          break;
        }

        yield ASRPartialResult(
          text: partial.text,
          isFinal: partial.isFinal,
          index: index++,
          confidence: partial.confidence,
          pluginId: pluginId,
        );
      }
    } catch (e) {
      debugPrint('[OfflineASRPlugin] 流式识别错误: $e');

      if (e is ASRException) {
        rethrow;
      }

      throw ASRException(
        '离线流式识别失败: $e',
        errorCode: ASRErrorCode.unknown,
      );
    } finally {
      state = ASRPluginState.idle;
      debugPrint('[OfflineASRPlugin] transcribeStream 结束');
    }
  }

  @override
  Future<void> cancelTranscription() async {
    debugPrint('[OfflineASRPlugin] cancelTranscription');
    _isCancelled = true;
    _currentSessionId++;
    state = ASRPluginState.idle;
  }

  // ==================== 模型管理 ====================

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded([OfflineModelType? type]) async {
    return await _modelManager.isModelDownloaded(type ?? _modelType);
  }

  /// 下载模型
  Future<void> downloadModel({
    OfflineModelType? type,
    void Function(double progress)? onProgress,
  }) async {
    await _modelManager.downloadModel(
      type ?? _modelType,
      onProgress: onProgress,
    );
  }

  /// 删除模型
  Future<void> deleteModel([OfflineModelType? type]) async {
    final targetType = type ?? _modelType;

    // 如果是当前模型，先释放引擎
    if (targetType == _modelType && _engine != null) {
      _engine!.dispose();
      _engine = null;
      state = ASRPluginState.uninitialized;
    }

    await _modelManager.deleteModel(targetType);
  }

  /// 获取模型大小
  int getModelSize([OfflineModelType? type]) {
    return _modelManager.getModelSize(type ?? _modelType);
  }

  /// 获取模型信息
  Future<ModelInfo?> getModelInfo([OfflineModelType? type]) async {
    return await _modelManager.getModelInfo(type ?? _modelType);
  }

  /// 获取所有已下载的模型
  Future<List<ModelInfo>> getDownloadedModels() async {
    return await _modelManager.getDownloadedModels();
  }

  /// 获取所有可用的模型类型
  List<OfflineModelType> get availableModelTypes => OfflineModelType.values;

  // ==================== VAD功能 ====================

  /// 使用VAD检测语音片段
  List<VADSegment> detectVoiceActivity(Uint8List audioData,
      {int sampleRate = 16000}) {
    if (_vadService == null) {
      _vadService = VADService();
    }
    return _vadService!.detect(audioData, sampleRate: sampleRate);
  }

  /// 获取音频中的语音片段
  List<AudioSegment> getVoiceSegments(Uint8List audioData,
      {int sampleRate = 16000}) {
    final vadSegments = detectVoiceActivity(audioData, sampleRate: sampleRate);
    return vadSegments
        .where((s) => s.isSpeech)
        .map((s) => AudioSegment(
              startMs: s.startMs,
              endMs: s.endMs,
              isSpeech: s.isSpeech,
            ))
        .toList();
  }

  @override
  Future<void> doDispose() async {
    await cancelTranscription();
    _engine?.dispose();
    _engine = null;
    _vadService = null;
    await _initProgressController.close();
  }
}
