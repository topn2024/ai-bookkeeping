import 'dart:async';
import 'dart:io';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';

import 'asr/asr.dart';
import 'asr/asr.dart' as asr;
import 'iflytek_rtasr_service.dart';

// 重新导出ASR模块的核心类型，保持向后兼容
export 'asr/core/asr_exception.dart' show ASRException, ASRErrorCode;
export 'asr/core/asr_models.dart'
    show ProcessedAudio, ASRResult, ASRPartialResult, ASRWord, HotWord, AudioSegment;
export 'asr/core/asr_config.dart' show ASRErrorHandlingConfig;
export 'asr/postprocess/asr_postprocessor.dart' show BookkeepingASROptimizer;

/// 语音识别引擎
///
/// 支持在线（讯飞、阿里云）和离线（本地Sherpa-ONNX）三种模式
/// 优先级：讯飞语音听写 > 阿里云 > 本地Whisper
///
/// 此类作为ASROrchestrator的兼容层，保持原有API不变
class VoiceRecognitionEngine {
  final ASROrchestrator _orchestrator;
  final ASRPluginRegistry _registry;
  final IFlytekRTASRService _iflytekRTASR;

  /// 是否禁用实时语音转写大模型（余额不足时自动禁用）
  final bool _rtasrDisabled = true; // 默认禁用，问题太多

  /// 当前是否正在识别
  bool get isRecognizing => _orchestrator.isRecognizing;

  /// 检查是否已取消
  bool get isCancelled => _orchestrator.isCancelled;

  VoiceRecognitionEngine({
    ASROrchestrator? orchestrator,
    ASRPluginRegistry? registry,
    IFlytekRTASRService? iflytekRTASR,
  })  : _registry = registry ?? ASRPluginRegistry(),
        _orchestrator = orchestrator ??
            ASROrchestrator(
              registry: registry ?? ASRPluginRegistry(),
              postprocessor: BookkeepingASROptimizer(),
            ),
        _iflytekRTASR = iflytekRTASR ?? IFlytekRTASRService() {
    // 注册默认插件
    _registerDefaultPlugins();
  }

  /// 注册默认插件
  void _registerDefaultPlugins() {
    // 讯飞语音听写（优先级10）
    if (!_registry.hasPlugin('iflytek_iat')) {
      _registry.register(IFlytekIATPlugin());
    }

    // 阿里云ASR（优先级20）
    if (!_registry.hasPlugin('alicloud_asr')) {
      _registry.register(AliCloudASRPlugin());
    }

    // 离线ASR（优先级100）
    if (!_registry.hasPlugin('offline_sherpa')) {
      _registry.register(OfflineASRPlugin());
    }

    debugPrint('[VoiceRecognitionEngine] 已注册 ${_registry.pluginCount} 个插件');
  }

  /// ASR服务选择策略
  /// 优先级：讯飞 > 阿里云 > 本地Whisper
  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    debugPrint(
        '[VoiceRecognitionEngine] transcribe开始，音频大小: ${audio.data.length} bytes');
    return await _orchestrator.transcribe(audio);
  }

  /// 流式识别（实时转写）
  ///
  /// 如果已有识别进行中，会先取消之前的识别
  Stream<ASRPartialResult> transcribeStream(
      Stream<Uint8List> audioStream) async* {
    debugPrint('[VoiceRecognitionEngine] transcribeStream 开始');

    // 注意：讯飞实时语音转写大模型已禁用（问题太多）
    // 直接使用Orchestrator进行流式识别
    await for (final partial in _orchestrator.transcribeStream(audioStream)) {
      yield partial;
    }

    debugPrint('[VoiceRecognitionEngine] transcribeStream 结束');
  }

  /// 取消当前识别
  ///
  /// 立即停止当前的流式识别任务（用于TTS播放前暂停等场景）
  Future<void> cancelTranscription() async {
    await _orchestrator.cancelTranscription();

    // 同时取消RTASR（如果有）
    await _iflytekRTASR.cancelTranscription();

    debugPrint('VoiceRecognitionEngine: transcription cancelled');
  }

  /// 重置取消状态
  void resetCancelState() {
    // Orchestrator内部会自动管理状态
  }

  /// 预热ASR连接（提前建立WebSocket连接）
  ///
  /// 在用户点击麦克风按钮时调用，可节省100-300ms连接延迟
  Future<void> warmupConnection() async {
    debugPrint('[VoiceRecognitionEngine] 预热ASR连接...');

    // 只预热RTASR（如果未被禁用）
    if (!_rtasrDisabled) {
      await _iflytekRTASR.warmupConnection();
    }

    // 也可以预热Orchestrator
    await _orchestrator.warmupConnection();
  }

  /// 是否有预热的连接可用
  bool get hasWarmupConnection =>
      (!_rtasrDisabled && _iflytekRTASR.hasValidWarmup) ||
      _orchestrator.hasWarmupConnection;

  /// 初始化离线模型
  Future<void> initializeOfflineModel() async {
    final offlinePlugin =
        _registry.getPlugin('offline_sherpa') as OfflineASRPlugin?;
    if (offlinePlugin != null) {
      await offlinePlugin.initialize();
    }
  }

  /// 设置热词表（用于提高特定词汇的识别准确率）
  void setHotWords(List<HotWord> hotWords) {
    _orchestrator.setHotWords(hotWords);
  }

  /// 添加用户自定义热词
  void addUserHotWords(List<String> words, {double weight = 1.5}) {
    final hotWords = words.map((w) => HotWord(w, weight: weight)).toList();
    _orchestrator.addHotWords(hotWords);
  }

  /// 从文件识别语音
  Future<FileRecognitionResult> recognizeFromFile(File file) async {
    try {
      debugPrint('[VoiceRecognitionEngine] recognizeFromFile: ${file.path}');

      // 读取音频文件
      final bytes = await file.readAsBytes();
      debugPrint('[VoiceRecognitionEngine] 文件大小: ${bytes.length} bytes');

      // 如果是WAV文件，需要跳过WAV头部获取纯PCM数据
      Uint8List pcmData;
      if (file.path.toLowerCase().endsWith('.wav') && bytes.length > 44) {
        // WAV文件头部是44字节，跳过它获取纯PCM数据
        final riff = String.fromCharCodes(bytes.sublist(0, 4));
        final wave = String.fromCharCodes(bytes.sublist(8, 12));
        if (riff == 'RIFF' && wave == 'WAVE') {
          // 找到data chunk的位置
          int dataOffset = 12;
          while (dataOffset < bytes.length - 8) {
            final chunkId =
                String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
            final chunkSize = bytes.buffer
                .asByteData()
                .getUint32(dataOffset + 4, Endian.little);
            if (chunkId == 'data') {
              dataOffset += 8;
              pcmData = bytes.sublist(
                  dataOffset, min(dataOffset + chunkSize, bytes.length));
              debugPrint(
                  '[VoiceRecognitionEngine] WAV文件，提取PCM数据: ${pcmData.length} bytes');
              break;
            }
            dataOffset += 8 + chunkSize;
          }
          pcmData = bytes.sublist(44); // 降级方案
        } else {
          pcmData = bytes;
        }
      } else {
        pcmData = bytes;
      }

      // 计算音频时长（16000Hz, 16bit, 单声道）
      final durationMs = (pcmData.length / 32).round();
      debugPrint('[VoiceRecognitionEngine] 估算时长: ${durationMs}ms');

      // 创建ProcessedAudio对象
      final audio = ProcessedAudio(
        data: pcmData,
        segments: [],
        duration: Duration(milliseconds: durationMs),
      );

      // 使用现有的transcribe方法
      final result = await transcribe(audio);
      debugPrint('[VoiceRecognitionEngine] 识别结果: ${result.text}');

      return FileRecognitionResult(
        isSuccess: true,
        text: result.text,
        confidence: result.confidence,
      );
    } catch (e) {
      debugPrint('[VoiceRecognitionEngine] 识别失败: $e');
      return FileRecognitionResult(
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// 开始实时识别
  Stream<RealtimeRecognitionResult> startRealtimeRecognition() async* {
    yield RealtimeRecognitionResult(
      text: '',
      isFinal: false,
    );
  }

  /// 停止实时识别
  Future<void> stopRealtimeRecognition() async {
    await cancelTranscription();
  }

  /// 获取注册中心（用于高级配置）
  ASRPluginRegistry get registry => _registry;

  /// 获取调度器（用于高级配置）
  ASROrchestrator get orchestrator => _orchestrator;

  /// 释放资源
  void dispose() {
    _orchestrator.dispose();
    _registry.disposeAll();
  }
}

/// 文件识别结果
class FileRecognitionResult {
  final bool isSuccess;
  final String text;
  final double confidence;
  final String? error;

  FileRecognitionResult({
    required this.isSuccess,
    this.text = '',
    this.confidence = 0.0,
    this.error,
  });
}

/// 实时识别结果
class RealtimeRecognitionResult {
  final String text;
  final bool isFinal;

  RealtimeRecognitionResult({
    required this.text,
    required this.isFinal,
  });
}

/// 网络检测器（向后兼容导出）
/// 实际实现已移至 asr/utils/network_checker.dart
class NetworkChecker {
  final asr.NetworkChecker _checker = asr.NetworkChecker();

  Future<bool> isOnline() => _checker.isOnline();

  Stream<bool> get onConnectivityChanged => _checker.onConnectivityChanged;
}

/// 本地Whisper服务（向后兼容）
/// 实际实现已移至 OfflineASRPlugin
class LocalWhisperService {
  final OfflineASRPlugin _plugin = OfflineASRPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _plugin.initialize();
    _isInitialized = true;
    debugPrint('Local Sherpa-ONNX model initialized');
  }

  Future<ASRResult> transcribe(ProcessedAudio audio) async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _plugin.transcribe(audio);
  }

  void dispose() {
    _plugin.dispose();
    _isInitialized = false;
  }
}

/// 音频环形缓冲区（向后兼容导出）
/// 实际实现已移至 asr/utils/audio_buffer.dart
class AudioCircularBuffer {
  final asr.AudioCircularBuffer _buffer;

  AudioCircularBuffer({int maxSize = 32000})
      : _buffer = asr.AudioCircularBuffer(maxSize: maxSize);

  int get available => _buffer.available;
  bool get isFull => _buffer.isFull;
  bool get isEmpty => _buffer.isEmpty;

  void write(Uint8List data) => _buffer.write(data);
  Uint8List read(int length) => _buffer.read(length);
  Uint8List peek(int length) => _buffer.peek(length);
  void clear() => _buffer.clear();
  Uint8List readAll() => _buffer.readAll();
}
