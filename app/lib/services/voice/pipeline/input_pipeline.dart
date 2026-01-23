import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../voice_recognition_engine.dart';
import '../realtime_vad_config.dart';
import '../detection/barge_in_detector_v2.dart';

/// 输入流水线状态
enum InputPipelineState {
  idle,       // 空闲
  listening,  // 监听中
  processing, // 处理中（等待最终结果）
  stopped,    // 已停止
}

/// 输入流水线
///
/// 职责：
/// - 管理VAD和ASR的输入流
/// - 检测语音活动和静音
/// - 提供中间结果和最终结果回调
/// - 与打断检测器协作
class InputPipeline {
  final VoiceRecognitionEngine _asrEngine;
  final RealtimeVADService? _vadService;
  final BargeInDetectorV2 _bargeInDetector;

  InputPipelineState _state = InputPipelineState.idle;

  /// 订阅
  StreamSubscription<ASRPartialResult>? _asrSubscription;
  StreamSubscription<VADEvent>? _vadSubscription;

  /// 回调
  void Function(String text)? onPartialResult;
  void Function(String text)? onFinalResult;
  VoidCallback? onSpeechStart;
  VoidCallback? onSpeechEnd;
  void Function(BargeInResult result)? onBargeIn;
  void Function(Object error)? onError;  // ASR错误回调

  /// 事件流
  final _stateController = StreamController<InputPipelineState>.broadcast();
  Stream<InputPipelineState> get stateStream => _stateController.stream;

  /// 当前中间结果
  String _currentPartialText = '';

  /// 音频流控制器（用于发送音频数据到ASR）
  StreamController<Uint8List>? _audioStreamController;

  /// 是否正在主动停止（用于区分主动停止和意外结束）
  bool _isStopping = false;

  InputPipeline({
    required VoiceRecognitionEngine asrEngine,
    RealtimeVADService? vadService,
    required BargeInDetectorV2 bargeInDetector,
  })  : _asrEngine = asrEngine,
        _vadService = vadService,
        _bargeInDetector = bargeInDetector {
    // 设置打断回调
    _bargeInDetector.onBargeIn = _handleBargeIn;
  }

  /// 当前状态
  InputPipelineState get state => _state;

  /// 是否正在监听
  bool get isListening => _state == InputPipelineState.listening;

  /// 当前中间结果
  String get currentPartialText => _currentPartialText;

  /// 启动输入流水线
  Future<void> start() async {
    debugPrint('[InputPipeline] ===== start() 被调用 =====');
    debugPrint('[InputPipeline] 当前状态: $_state, 控制器=${_audioStreamController != null ? "存在" : "null"}');

    // 防御性检查：如果状态是listening但控制器为null，说明状态异常
    // 这种情况下强制重置后再启动
    if (_state == InputPipelineState.listening && _audioStreamController == null) {
      debugPrint('[InputPipeline] 检测到状态异常(listening但控制器null)，强制重置');
      _state = InputPipelineState.idle;
    }

    if (_state != InputPipelineState.idle) {
      debugPrint('[InputPipeline] 状态不是idle($_state)，忽略启动请求');
      return;
    }

    _state = InputPipelineState.listening;
    _stateController.add(_state);
    _currentPartialText = '';
    debugPrint('[InputPipeline] 状态已设置为 listening');

    // 创建音频流控制器
    _audioStreamController = StreamController<Uint8List>();
    debugPrint('[InputPipeline] 音频流控制器已创建');

    // 启动ASR流式识别并订阅结果
    debugPrint('[InputPipeline] 开始订阅ASR流...');
    _asrSubscription = _asrEngine
        .transcribeStream(_audioStreamController!.stream)
        .listen(
      _handleASRResult,
      onError: (e) {
        debugPrint('[InputPipeline] ASR错误: $e');
        onError?.call(e);  // 通知控制器
      },
      onDone: () {
        debugPrint('[InputPipeline] ASR流结束(onDone), isStopping=$_isStopping');
        // 只有在非主动停止时才通知错误（需要重启）
        if (!_isStopping) {
          onError?.call(StateError('ASR流意外结束'));
        }
      },
    );
    debugPrint('[InputPipeline] ASR订阅已建立');

    // 订阅VAD事件
    if (_vadService != null) {
      _vadSubscription = _vadService.eventStream.listen(
        _handleVADEvent,
        onError: (e) => debugPrint('[InputPipeline] VAD错误: $e'),
      );
      debugPrint('[InputPipeline] VAD订阅已建立');
    }

    debugPrint('[InputPipeline] ===== 启动完成 =====');
  }

  /// 发送音频数据到ASR
  ///
  /// 计数器用于采样日志，避免日志过多
  int _feedDataCount = 0;

  void feedAudioData(Uint8List audioData) {
    _feedDataCount++;
    // 前10次每次都打印，之后每50次打印一次（更频繁的日志以便调试）
    final shouldLog = _feedDataCount <= 10 || _feedDataCount % 50 == 0;

    if (shouldLog) {
      final hasController = _audioStreamController != null;
      final controllerClosed = _audioStreamController?.isClosed ?? true;

      // 计算音频振幅（16位PCM格式）
      int maxAmplitude = 0;
      int sumAmplitude = 0;
      if (audioData.length >= 2) {
        for (int i = 0; i < audioData.length - 1; i += 2) {
          // 16位小端序
          int sample = audioData[i] | (audioData[i + 1] << 8);
          // 转换为有符号数
          if (sample > 32767) sample -= 65536;
          final absValue = sample.abs();
          if (absValue > maxAmplitude) maxAmplitude = absValue;
          sumAmplitude += absValue;
        }
      }
      final avgAmplitude = audioData.length > 2 ? sumAmplitude ~/ (audioData.length ~/ 2) : 0;

      debugPrint('[InputPipeline] feedAudioData #$_feedDataCount, 状态=$_state, 控制器=${hasController ? (controllerClosed ? "已关闭" : "活跃") : "null"}, 音频: ${audioData.length}字节, 最大振幅=$maxAmplitude, 平均振幅=$avgAmplitude');
    }

    // 只有在控制器存在且未关闭时才添加数据
    if (_audioStreamController != null && !_audioStreamController!.isClosed) {
      _audioStreamController!.add(audioData);
    } else if (shouldLog) {
      debugPrint('[InputPipeline] 跳过音频数据：控制器${_audioStreamController == null ? "不存在" : "已关闭"}');
    }

    // 同时发送给VAD处理
    _vadService?.processAudioFrame(audioData);
  }

  /// 仅发送音频数据到VAD（不发送给ASR）
  ///
  /// 用于speaking状态下的打断检测：
  /// - TTS播放时不需要ASR识别（避免回声被识别）
  /// - 但仍需要VAD检测用户是否在说话（打断检测）
  void feedAudioToVADOnly(Uint8List audioData) {
    // 只发送给VAD处理，不发送给ASR
    _vadService?.processAudioFrame(audioData);
  }

  /// 处理ASR结果
  void _handleASRResult(ASRPartialResult result) {
    // 注意：不在日志中打印完整识别结果，避免泄露用户隐私
    debugPrint('[InputPipeline] 收到ASR结果，长度: ${result.text.length} (isFinal=${result.isFinal})');

    if (result.isFinal) {
      // 最终结果
      _handleFinalResult(result.text);
    } else {
      // 中间结果
      _handlePartialResult(result.text);
    }
  }

  /// 处理ASR中间结果
  ///
  /// 注意：回声消除由硬件级 AEC 在音频层处理，不再在文本层做回声过滤
  void _handlePartialResult(String text) {
    // 传递给打断检测器（打断检测器基于 VAD 判断是否打断）
    _bargeInDetector.handlePartialResult(text);

    _currentPartialText = text;
    onPartialResult?.call(text);
  }

  /// 处理ASR最终结果
  ///
  /// 注意：回声消除由硬件级 AEC 在音频层处理，不再在文本层做回声过滤
  void _handleFinalResult(String text) {
    _currentPartialText = '';

    // 跳过空结果
    if (text.trim().isEmpty) {
      debugPrint('[InputPipeline] 跳过空的最终结果');
      return;
    }

    // 如果 TTS 正在播放，检查打断（用于触发打断回调）
    if (_bargeInDetector.isEnabled) {
      final bargeInResult = _bargeInDetector.handleFinalResult(text);
      if (bargeInResult.triggered) {
        debugPrint('[InputPipeline] 检测到打断，传递用户输入: "$text"');
        // 打断已经通过检测器内部的 _triggerBargeIn 触发
        // 继续处理用户输入
      }
    }

    onFinalResult?.call(text);
  }

  /// 处理VAD事件
  void _handleVADEvent(VADEvent event) {
    switch (event.type) {
      case VADEventType.speechStart:
        _bargeInDetector.updateVADState(true);
        onSpeechStart?.call();
        break;
      case VADEventType.speechEnd:
        _bargeInDetector.updateVADState(false);
        onSpeechEnd?.call();
        break;
      case VADEventType.turnEndPauseStart:
        // 轮次结束停顿开始
        break;
      case VADEventType.turnEndPauseTimeout:
        // 轮次结束停顿超时（无用户响应）
        onSpeechEnd?.call();
        break;
      case VADEventType.silenceTimeout:
        // 沉默超时
        onSpeechEnd?.call();
        break;
      case VADEventType.noiseFloorUpdated:
        // 噪音基底更新，忽略
        break;
    }
  }

  /// 处理打断
  void _handleBargeIn(BargeInResult result) {
    debugPrint('[InputPipeline] 打断触发: $result');
    onBargeIn?.call(result);
  }

  /// 停止输入流水线
  Future<void> stop() async {
    debugPrint('[InputPipeline] ===== stop() 被调用 =====');
    debugPrint('[InputPipeline] 当前状态: $_state');

    // 标记正在主动停止（防止onDone触发错误回调）
    _isStopping = true;

    // 先取消ASR识别（停止等待数据）
    debugPrint('[InputPipeline] 取消ASR识别...');
    await _asrEngine.cancelTranscription();

    // 取消订阅（必须在关闭流之前，否则close()会等待onDone完成导致死锁）
    debugPrint('[InputPipeline] 取消订阅...');
    await _asrSubscription?.cancel();
    await _vadSubscription?.cancel();
    _asrSubscription = null;
    _vadSubscription = null;

    // 最后关闭音频流控制器（不等待，避免死锁）
    debugPrint('[InputPipeline] 关闭音频流控制器...');
    final controller = _audioStreamController;
    _audioStreamController = null;
    if (controller != null && !controller.isClosed) {
      controller.close(); // 不await，避免死锁
    }
    debugPrint('[InputPipeline] 音频流控制器已关闭');

    _state = InputPipelineState.stopped;
    _stateController.add(_state);
    _currentPartialText = '';
    _feedDataCount = 0;  // 重置计数器

    debugPrint('[InputPipeline] ===== stop() 完成，状态=$_state =====');
  }

  /// 重置输入流水线
  void reset() {
    debugPrint('[InputPipeline] ===== reset() 被调用 =====');
    debugPrint('[InputPipeline] 当前状态: $_state, 控制器=${_audioStreamController != null ? "存在" : "null"}');

    _currentPartialText = '';
    _bargeInDetector.reset();
    _isStopping = false;  // 重置停止标志

    // 无论当前状态如何，都重置为idle
    // 这解决了状态为listening但控制器为null的死锁问题
    if (_state != InputPipelineState.idle) {
      final oldState = _state;
      _state = InputPipelineState.idle;
      _stateController.add(_state);
      debugPrint('[InputPipeline] 状态从$oldState重置为idle');
    } else {
      debugPrint('[InputPipeline] 状态已是idle');
    }

    debugPrint('[InputPipeline] ===== reset() 完成 =====');
  }

  /// 释放资源
  ///
  /// 注意：异步方法，确保 stop() 完成后再关闭 StreamController
  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }
}
