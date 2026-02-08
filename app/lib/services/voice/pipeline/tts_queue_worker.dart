import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../streaming_tts_service.dart';
import '../config/pipeline_config.dart';
import '../tracking/response_tracker.dart';

/// TTS任务
class _TTSTask {
  final String sentence;
  final int responseId;
  final DateTime createdAt;

  _TTSTask(this.sentence, this.responseId) : createdAt = DateTime.now();

  /// 任务是否过期（超过30秒）
  bool get isExpired =>
      DateTime.now().difference(createdAt) > const Duration(seconds: 30);
}

/// TTS队列状态
enum TTSQueueState {
  idle,       // 空闲
  working,    // 工作中
  paused,     // 暂停
  stopped,    // 已停止
}

/// TTS队列工作器
///
/// 职责：
/// - 管理待合成句子的队列
/// - 调用StreamingTTSService进行合成
/// - 根据响应ID过滤过期任务
/// - 支持打断和重置
class TTSQueueWorker {
  final StreamingTTSService _ttsService;
  final ResponseTracker _responseTracker;
  final PipelineConfig _config;

  final Queue<_TTSTask> _queue = Queue();

  TTSQueueState _state = TTSQueueState.idle;
  bool _isStopped = false;

  /// 当前正在播放的TTS文本（用于回声过滤）
  String _currentTTSText = '';

  /// 已合成的句子累计文本
  String _accumulatedText = '';

  /// 回调
  VoidCallback? onStarted;
  VoidCallback? onCompleted;
  void Function(String sentence)? onSentenceStarted;
  void Function(String sentence)? onSentenceCompleted;
  void Function(Object error)? onError;

  /// 事件流
  final _stateController = StreamController<TTSQueueState>.broadcast();
  Stream<TTSQueueState> get stateStream => _stateController.stream;

  TTSQueueWorker({
    required StreamingTTSService ttsService,
    required ResponseTracker responseTracker,
    PipelineConfig? config,
  })  : _ttsService = ttsService,
        _responseTracker = responseTracker,
        _config = config ?? PipelineConfig.defaultConfig;

  /// 当前状态
  TTSQueueState get state => _state;

  /// 当前正在播放的TTS文本
  String get currentTTSText => _currentTTSText;

  /// 已累计的全部TTS文本
  String get accumulatedText => _accumulatedText;

  /// 队列长度
  int get queueLength => _queue.length;

  /// 是否正在工作
  bool get isWorking => _state == TTSQueueState.working;

  /// 添加句子到队列
  ///
  /// [sentence] 要合成的句子
  /// [responseId] 响应ID，用于过期检查
  void enqueue(String sentence, int responseId) {
    if (_isStopped) {
      debugPrint('[TTSQueueWorker] 已停止，忽略入队: "$sentence"');
      return;
    }

    // 检查队列长度限制
    if (_queue.length >= _config.maxTTSQueueSize) {
      debugPrint('[TTSQueueWorker] 队列已满，丢弃最旧任务');
      _queue.removeFirst();
    }

    _queue.add(_TTSTask(sentence, responseId));
    debugPrint('[TTSQueueWorker] 入队: "$sentence" (队列长度=${_queue.length})');

    _startWorkerIfNeeded();
  }

  /// 启动工作器（如果未运行）
  void _startWorkerIfNeeded() {
    if (_state == TTSQueueState.working || _isStopped) return;

    _state = TTSQueueState.working;
    _stateController.add(_state);
    onStarted?.call();

    _processQueue();
  }

  /// 处理队列
  Future<void> _processQueue() async {
    while (_queue.isNotEmpty && !_isStopped && _state != TTSQueueState.paused) {
      final task = _queue.removeFirst();

      // 检查响应ID是否过期
      if (!_responseTracker.isCurrentResponse(task.responseId)) {
        debugPrint('[TTSQueueWorker] 跳过过期任务: "${task.sentence}"');
        continue;
      }

      // 检查任务是否超时
      if (task.isExpired) {
        debugPrint('[TTSQueueWorker] 跳过超时任务: "${task.sentence}"');
        continue;
      }

      // 更新当前TTS文本（用于回声过滤）
      _currentTTSText = task.sentence;
      _accumulatedText += task.sentence;

      onSentenceStarted?.call(task.sentence);
      debugPrint('[TTSQueueWorker] 开始合成: "${task.sentence}"');

      try {
        // 调用流式TTS服务
        await _ttsService.speak(task.sentence, interrupt: false);

        if (!_isStopped) {
          onSentenceCompleted?.call(task.sentence);
          debugPrint('[TTSQueueWorker] 完成: "${task.sentence}"');
        }
      } catch (e) {
        debugPrint('[TTSQueueWorker] 合成失败: $e');
        onError?.call(e);
        // 继续处理下一个任务，不中断队列
      }

      _currentTTSText = '';
    }

    // 队列处理完成
    if (!_isStopped) {
      _state = TTSQueueState.idle;
      _stateController.add(_state);
      onCompleted?.call();
      debugPrint('[TTSQueueWorker] 队列处理完成');
    }
  }

  /// 停止工作器
  ///
  /// 立即停止当前播放并清空队列
  Future<void> stop() async {
    _isStopped = true;
    _queue.clear();
    _currentTTSText = '';

    await _ttsService.stop();

    _state = TTSQueueState.stopped;
    _stateController.add(_state);
    debugPrint('[TTSQueueWorker] 已停止');
  }

  /// 快速淡出停止（用于打断场景）
  Future<void> fadeOutAndStop() async {
    _isStopped = true;
    _queue.clear();
    _currentTTSText = '';

    await _ttsService.fadeOutAndStop();

    _state = TTSQueueState.stopped;
    _stateController.add(_state);
    debugPrint('[TTSQueueWorker] 淡出停止');
  }

  /// 重置工作器
  ///
  /// 清空队列和状态，准备处理新响应
  void reset() {
    _queue.clear();
    _currentTTSText = '';
    _accumulatedText = '';
    _isStopped = false;
    _state = TTSQueueState.idle;
    _stateController.add(_state);
    debugPrint('[TTSQueueWorker] 已重置');
  }

  /// 暂停工作器
  void pause() {
    if (_state == TTSQueueState.working) {
      _state = TTSQueueState.paused;
      _stateController.add(_state);
      debugPrint('[TTSQueueWorker] 已暂停');
    }
  }

  /// 恢复工作器
  void resume() {
    if (_state == TTSQueueState.paused) {
      _state = TTSQueueState.working;
      _stateController.add(_state);
      _processQueue();
      debugPrint('[TTSQueueWorker] 已恢复');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await stop();
    try {
      await _stateController.close();
    } catch (e) {
      debugPrint('[TTSQueueWorker] 关闭StateController异常: $e');
    }
  }
}
