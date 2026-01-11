import 'dart:async';

import 'package:flutter/foundation.dart';

import 'voice_state_machine.dart';

/// 并发语音处理管道
///
/// 实现三个并行处理流：
/// 1. 输入流: VAD检测 → ASR识别 → 意图解析
/// 2. 处理流: AI生成响应
/// 3. 输出流: TTS合成 → 音频播放
///
/// 关键特性：
/// - 输入流始终保持活跃（全双工支持）
/// - 支持打断和取消
/// - 流程状态追踪
class ConcurrentVoicePipeline {
  final VoiceStateMachine _stateMachine;

  /// 三个并行处理流的控制器
  StreamController<InputEvent>? _inputController;
  StreamController<ProcessEvent>? _processController;
  StreamController<OutputEvent>? _outputController;

  /// 当前正在进行的任务
  Future<void>? _currentInputTask;
  Future<void>? _currentProcessTask;
  Future<void>? _currentOutputTask;

  /// 取消标记
  bool _isCancelled = false;

  /// 管道事件流
  final _eventController = StreamController<PipelineEvent>.broadcast();
  Stream<PipelineEvent> get eventStream => _eventController.stream;

  /// 外部处理器（由调用者提供）
  InputProcessor? inputProcessor;
  ResponseProcessor? responseProcessor;
  OutputProcessor? outputProcessor;

  /// 打断回调
  void Function()? onInterrupt;

  ConcurrentVoicePipeline({VoiceStateMachine? stateMachine})
      : _stateMachine = stateMachine ?? VoiceStateMachine();

  VoiceStateMachine get stateMachine => _stateMachine;

  /// 初始化管道
  void initialize() {
    _inputController = StreamController<InputEvent>.broadcast();
    _processController = StreamController<ProcessEvent>.broadcast();
    _outputController = StreamController<OutputEvent>.broadcast();

    // 监听状态机事件
    _stateMachine.eventStream.listen(_handleStateEvent);

    // 启用全双工模式
    _stateMachine.enableFullDuplexMode();

    debugPrint('ConcurrentVoicePipeline: initialized');
  }

  /// 启动会话
  void startSession() {
    _isCancelled = false;
    _stateMachine.startSession();
    _startInputFlow();
    _emitEvent(PipelineEvent.sessionStarted);
    debugPrint('ConcurrentVoicePipeline: session started');
  }

  /// 结束会话
  void endSession() {
    _isCancelled = true;
    _stateMachine.endSession();
    _stopAllFlows();
    _emitEvent(PipelineEvent.sessionEnded);
    debugPrint('ConcurrentVoicePipeline: session ended');
  }

  // ==================== 输入流 ====================

  /// 启动输入流（持续监听）
  void _startInputFlow() {
    if (_inputController == null || _inputController!.isClosed) return;

    _currentInputTask = _runInputFlow();
  }

  Future<void> _runInputFlow() async {
    while (!_isCancelled && _stateMachine.isSessionActive) {
      try {
        // 等待可以开始监听
        if (!_canStartListening()) {
          await Future.delayed(const Duration(milliseconds: 50));
          continue;
        }

        _stateMachine.startListening();
        _emitEvent(PipelineEvent.listeningStarted);

        // 执行输入处理（VAD + ASR）
        final inputResult = await _processInput();

        if (inputResult != null && !_isCancelled) {
          _stateMachine.processUserInput();

          // 将结果传递给处理流
          _startProcessFlow(inputResult);
        }

        _stateMachine.finishProcessing();

      } catch (e) {
        debugPrint('ConcurrentVoicePipeline: input flow error - $e');
        _emitEvent(PipelineEvent.error);
      }

      // 短暂延迟避免CPU过载
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  bool _canStartListening() {
    // 全双工模式下，可以在说话时监听
    if (_stateMachine.isFullDuplexMode) {
      return _stateMachine.listeningState == ListeningState.idle;
    }

    // 半双工模式下，需要等待说话完成
    return _stateMachine.listeningState == ListeningState.idle &&
        _stateMachine.speakingState == SpeakingState.idle;
  }

  Future<String?> _processInput() async {
    if (inputProcessor == null) return null;

    try {
      final result = await inputProcessor!.process();
      return result;
    } catch (e) {
      debugPrint('ConcurrentVoicePipeline: input processing error - $e');
      return null;
    }
  }

  // ==================== 处理流 ====================

  /// 启动处理流
  void _startProcessFlow(String userInput) {
    _currentProcessTask = _runProcessFlow(userInput);
  }

  Future<void> _runProcessFlow(String userInput) async {
    if (_isCancelled) return;

    try {
      _emitEvent(PipelineEvent.processingStarted);

      // 执行AI响应生成
      final response = await _processResponse(userInput);

      if (response != null && !_isCancelled) {
        // 将结果传递给输出流
        _startOutputFlow(response);
      }

      _emitEvent(PipelineEvent.processingCompleted);

    } catch (e) {
      debugPrint('ConcurrentVoicePipeline: process flow error - $e');
      _emitEvent(PipelineEvent.error);
    }
  }

  Future<String?> _processResponse(String userInput) async {
    if (responseProcessor == null) return null;

    try {
      final result = await responseProcessor!.process(userInput);
      return result;
    } catch (e) {
      debugPrint('ConcurrentVoicePipeline: response processing error - $e');
      return null;
    }
  }

  // ==================== 输出流 ====================

  /// 启动输出流
  void _startOutputFlow(String response) {
    _currentOutputTask = _runOutputFlow(response);
  }

  Future<void> _runOutputFlow(String response) async {
    if (_isCancelled) return;

    try {
      _stateMachine.startSpeaking(content: response);
      _emitEvent(PipelineEvent.speakingStarted);

      // 执行TTS输出
      await _processOutput(response);

      if (!_isCancelled) {
        _stateMachine.finishSpeaking();
        _emitEvent(PipelineEvent.speakingCompleted);
      }

    } catch (e) {
      debugPrint('ConcurrentVoicePipeline: output flow error - $e');
      _stateMachine.stopSpeaking();
      _emitEvent(PipelineEvent.error);
    }
  }

  Future<void> _processOutput(String response) async {
    if (outputProcessor == null) return;

    try {
      await outputProcessor!.process(response);
    } catch (e) {
      debugPrint('ConcurrentVoicePipeline: output processing error - $e');
      rethrow;
    }
  }

  // ==================== 打断处理 ====================

  /// 请求打断当前输出
  Future<void> interrupt() async {
    debugPrint('ConcurrentVoicePipeline: interrupt requested');

    // 通知状态机
    _stateMachine.requestInterrupt();

    // 停止输出流
    await _stopOutputFlow();

    // 触发回调
    onInterrupt?.call();

    _emitEvent(PipelineEvent.interrupted);
  }

  /// 停止输出流
  Future<void> _stopOutputFlow() async {
    if (outputProcessor != null) {
      await outputProcessor!.cancel();
    }
    _stateMachine.stopSpeaking();
  }

  /// 停止所有流
  void _stopAllFlows() {
    _isCancelled = true;
    _stateMachine.stopListening();
    _stateMachine.stopSpeaking();

    inputProcessor?.cancel();
    responseProcessor?.cancel();
    outputProcessor?.cancel();
  }

  // ==================== 事件处理 ====================

  void _handleStateEvent(VoiceStateEvent event) {
    // 根据状态机事件执行相应动作
    switch (event) {
      case VoiceStateEvent.interruptRequested:
        // 打断请求已通过状态机处理
        break;
      default:
        break;
    }
  }

  void _emitEvent(PipelineEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  // ==================== 便捷方法 ====================

  /// 发送用户输入（手动触发处理）
  Future<void> sendUserInput(String input) async {
    _startProcessFlow(input);
  }

  /// 发送AI响应（手动触发输出）
  Future<void> sendResponse(String response) async {
    _startOutputFlow(response);
  }

  /// 释放资源
  void dispose() {
    _isCancelled = true;
    _inputController?.close();
    _processController?.close();
    _outputController?.close();
    _eventController.close();
    _stateMachine.dispose();
  }
}

// ==================== 处理器接口 ====================

/// 输入处理器
abstract class InputProcessor {
  /// 处理输入（VAD + ASR）
  Future<String?> process();

  /// 取消处理
  Future<void> cancel();
}

/// 响应处理器
abstract class ResponseProcessor {
  /// 处理用户输入，生成AI响应
  Future<String?> process(String userInput);

  /// 取消处理
  Future<void> cancel();
}

/// 输出处理器
abstract class OutputProcessor {
  /// 处理输出（TTS + 播放）
  Future<void> process(String response);

  /// 取消处理（淡出）
  Future<void> cancel();
}

// ==================== 事件定义 ====================

/// 输入流事件
class InputEvent {
  final InputEventType type;
  final String? data;

  InputEvent(this.type, {this.data});
}

enum InputEventType {
  vadStart,
  vadEnd,
  asrResult,
  intentParsed,
}

/// 处理流事件
class ProcessEvent {
  final ProcessEventType type;
  final String? data;

  ProcessEvent(this.type, {this.data});
}

enum ProcessEventType {
  started,
  completed,
  error,
}

/// 输出流事件
class OutputEvent {
  final OutputEventType type;
  final String? data;

  OutputEvent(this.type, {this.data});
}

enum OutputEventType {
  ttsStarted,
  ttsCompleted,
  playbackStarted,
  playbackCompleted,
  interrupted,
}

/// 管道事件
enum PipelineEvent {
  sessionStarted,
  sessionEnded,
  listeningStarted,
  processingStarted,
  processingCompleted,
  speakingStarted,
  speakingCompleted,
  interrupted,
  error,
}

// ==================== 管道配置 ====================

/// 管道配置
class PipelineConfig {
  /// 是否启用全双工模式
  final bool fullDuplexMode;

  /// 输入流轮询间隔
  final Duration inputPollInterval;

  /// 打断后的恢复延迟
  final Duration interruptRecoveryDelay;

  const PipelineConfig({
    this.fullDuplexMode = true,
    this.inputPollInterval = const Duration(milliseconds: 50),
    this.interruptRecoveryDelay = const Duration(milliseconds: 200),
  });

  static const defaultConfig = PipelineConfig();
}
