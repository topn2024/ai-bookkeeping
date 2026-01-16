import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../streaming_tts_service.dart';
import '../config/pipeline_config.dart';
import '../detection/barge_in_detector_v2.dart';
import '../detection/echo_filter.dart';
import '../tracking/response_tracker.dart';
import 'sentence_buffer.dart';
import 'tts_queue_worker.dart';

/// 输出流水线状态
enum OutputPipelineState {
  idle,       // 空闲
  buffering,  // 缓冲中（等待句子）
  speaking,   // 播放中
  fading,     // 淡出中
  stopped,    // 已停止
}

/// 输出流水线
///
/// 职责：
/// - 接收LLM流式输出
/// - 通过SentenceBuffer分割句子
/// - 通过TTSQueueWorker合成和播放
/// - 与EchoFilter和BargeInDetector协作
class OutputPipeline {
  final StreamingTTSService _ttsService;
  final ResponseTracker _responseTracker;
  final BargeInDetectorV2 _bargeInDetector;
  final PipelineConfig _config;

  late final SentenceBuffer _sentenceBuffer;
  late final TTSQueueWorker _ttsQueueWorker;
  late final EchoFilter _echoFilter;

  OutputPipelineState _state = OutputPipelineState.idle;
  int _currentResponseId = 0;

  /// 统计
  int _totalChunks = 0;
  int _totalSentences = 0;
  DateTime? _firstChunkTime;
  DateTime? _firstAudioTime;

  /// 回调
  VoidCallback? onStarted;
  VoidCallback? onCompleted;
  VoidCallback? onStopped;
  void Function(String sentence)? onSentenceStarted;
  void Function(String sentence)? onSentenceCompleted;

  /// 事件流
  final _stateController = StreamController<OutputPipelineState>.broadcast();
  Stream<OutputPipelineState> get stateStream => _stateController.stream;

  OutputPipeline({
    required StreamingTTSService ttsService,
    required ResponseTracker responseTracker,
    required BargeInDetectorV2 bargeInDetector,
    PipelineConfig? config,
  })  : _ttsService = ttsService,
        _responseTracker = responseTracker,
        _bargeInDetector = bargeInDetector,
        _config = config ?? PipelineConfig.defaultConfig {
    _sentenceBuffer = SentenceBuffer(config: _config);
    _echoFilter = EchoFilter(config: _config);
    _ttsQueueWorker = TTSQueueWorker(
      ttsService: _ttsService,
      responseTracker: _responseTracker,
      config: _config,
    );

    // 设置TTS队列回调
    _ttsQueueWorker.onStarted = _onTTSStarted;
    _ttsQueueWorker.onCompleted = _onTTSCompleted;
    _ttsQueueWorker.onSentenceStarted = _onSentenceStarted;
    _ttsQueueWorker.onSentenceCompleted = _onSentenceCompleted;
  }

  /// 当前状态
  OutputPipelineState get state => _state;

  /// 是否正在播放
  bool get isSpeaking => _state == OutputPipelineState.speaking;

  /// 当前TTS文本
  String get currentTTSText => _ttsQueueWorker.currentTTSText;

  /// 已累计的全部TTS文本
  String get accumulatedText => _ttsQueueWorker.accumulatedText;

  /// 首块延迟（毫秒）
  int? get firstChunkLatencyMs {
    if (_firstChunkTime == null || _firstAudioTime == null) return null;
    return _firstAudioTime!.difference(_firstChunkTime!).inMilliseconds;
  }

  /// 启动输出流水线
  ///
  /// [responseId] 响应ID，用于过期检查
  void start(int responseId) {
    _currentResponseId = responseId;
    _state = OutputPipelineState.buffering;
    _stateController.add(_state);

    _sentenceBuffer.clear();
    _ttsQueueWorker.reset();
    _echoFilter.reset();

    _totalChunks = 0;
    _totalSentences = 0;
    _firstChunkTime = null;
    _firstAudioTime = null;

    onStarted?.call();
    debugPrint('[OutputPipeline] 已启动，响应ID=$responseId');
  }

  /// 添加LLM输出块
  ///
  /// 返回生成的句子数量
  int addChunk(String chunk) {
    if (!_responseTracker.isCurrentResponse(_currentResponseId)) {
      debugPrint('[OutputPipeline] 响应已过期，忽略块');
      return 0;
    }

    _totalChunks++;
    if (_firstChunkTime == null) {
      _firstChunkTime = DateTime.now();
    }

    // 通过句子缓冲区分割
    final sentences = _sentenceBuffer.addChunk(chunk);

    // 将句子加入TTS队列
    for (final sentence in sentences) {
      _ttsQueueWorker.enqueue(sentence, _currentResponseId);
      _totalSentences++;
    }

    return sentences.length;
  }

  /// 完成LLM输出
  ///
  /// 刷新缓冲区中剩余的内容
  void complete() {
    final isCurrentResponse = _responseTracker.isCurrentResponse(_currentResponseId);

    if (!isCurrentResponse) {
      // 响应已过期，但仍然需要触发完成回调以确保状态机正确转换
      debugPrint('[OutputPipeline] 响应已过期（ID=$_currentResponseId），直接触发完成回调');
      _state = OutputPipelineState.idle;
      _stateController.add(_state);
      onCompleted?.call();
      return;
    }

    // 刷新剩余内容
    final remaining = _sentenceBuffer.flush();
    if (remaining.isNotEmpty) {
      _ttsQueueWorker.enqueue(remaining, _currentResponseId);
      _totalSentences++;
    }

    debugPrint('[OutputPipeline] LLM输出完成，共$_totalChunks块，$_totalSentences句');

    // 如果没有任何内容被播放，直接触发完成回调
    // 否则等待TTS播放完成后触发
    if (_totalSentences == 0) {
      debugPrint('[OutputPipeline] 无内容播放，直接完成');
      _state = OutputPipelineState.idle;
      _stateController.add(_state);
      onCompleted?.call();
    }
  }

  /// 停止输出流水线
  Future<void> stop() async {
    _state = OutputPipelineState.stopped;
    _stateController.add(_state);

    await _ttsQueueWorker.stop();
    _sentenceBuffer.clear();

    // 更新打断检测器
    _bargeInDetector.updateTTSState(isPlaying: false, currentText: '');

    onStopped?.call();
    debugPrint('[OutputPipeline] 已停止');
  }

  /// 快速淡出停止（用于打断）
  Future<void> fadeOutAndStop() async {
    _state = OutputPipelineState.fading;
    _stateController.add(_state);

    await _ttsQueueWorker.fadeOutAndStop();
    _sentenceBuffer.clear();

    _state = OutputPipelineState.stopped;
    _stateController.add(_state);

    // 更新打断检测器
    _bargeInDetector.updateTTSState(isPlaying: false, currentText: '');

    onStopped?.call();
    debugPrint('[OutputPipeline] 淡出停止');
  }

  /// TTS开始播放回调
  void _onTTSStarted() {
    if (_firstAudioTime == null) {
      _firstAudioTime = DateTime.now();
      final latency = firstChunkLatencyMs;
      debugPrint('[OutputPipeline] 首字延迟: ${latency}ms');
    }

    _state = OutputPipelineState.speaking;
    _stateController.add(_state);

    // 更新打断检测器
    _bargeInDetector.updateTTSState(
      isPlaying: true,
      currentText: _ttsQueueWorker.accumulatedText,
    );
  }

  /// TTS播放完成回调
  void _onTTSCompleted() {
    _state = OutputPipelineState.idle;
    _stateController.add(_state);

    // 更新打断检测器
    _bargeInDetector.updateTTSState(isPlaying: false, currentText: '');

    onCompleted?.call();
    debugPrint('[OutputPipeline] 播放完成');
  }

  /// 句子开始播放回调
  void _onSentenceStarted(String sentence) {
    // 更新回声过滤器
    _echoFilter.onTTSStarted(sentence);

    // 更新打断检测器的TTS文本
    _bargeInDetector.appendTTSText(sentence);

    onSentenceStarted?.call(sentence);
  }

  /// 句子播放完成回调
  void _onSentenceCompleted(String sentence) {
    onSentenceCompleted?.call(sentence);
  }

  /// 重置输出流水线
  void reset() {
    _sentenceBuffer.clear();
    _ttsQueueWorker.reset();
    _echoFilter.reset();
    _currentResponseId = 0;

    if (_state != OutputPipelineState.idle) {
      _state = OutputPipelineState.idle;
      _stateController.add(_state);
    }
  }

  /// 释放资源
  void dispose() {
    stop();
    _ttsQueueWorker.dispose();
    _stateController.close();
  }
}
