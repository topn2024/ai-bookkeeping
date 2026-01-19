import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../streaming_tts_service.dart';
import '../../voice_recognition_engine.dart';
import '../realtime_vad_config.dart';
import '../config/pipeline_config.dart';
import '../detection/barge_in_detector_v2.dart';
import '../tracking/response_tracker.dart';
import 'input_pipeline.dart';
import 'output_pipeline.dart';

/// 流水线状态
enum VoicePipelineState {
  idle,       // 空闲
  listening,  // 监听用户输入
  processing, // 处理用户输入（等待LLM响应）
  speaking,   // 播放响应
  stopping,   // 停止中
}

/// 语音流水线控制器
///
/// 核心职责：
/// - 协调输入、处理、输出三条流水线
/// - 管理会话状态
/// - 处理打断和异常
///
/// 工作流程：
/// 1. 用户点击开始 → 启动输入流水线（监听）
/// 2. 用户说话 → ASR识别 → 获取最终结果
/// 3. 调用外部处理回调（LLM生成）
/// 4. LLM流式输出 → 输出流水线处理 → TTS播放
/// 5. 用户打断 → 停止输出 → 回到监听状态
class VoicePipelineController {
  final VoiceRecognitionEngine _asrEngine;
  final StreamingTTSService _ttsService;
  final RealtimeVADService? _vadService;
  final PipelineConfig _config;

  late final ResponseTracker _responseTracker;
  late final BargeInDetectorV2 _bargeInDetector;
  late final InputPipeline _inputPipeline;
  late final OutputPipeline _outputPipeline;

  VoicePipelineState _state = VoicePipelineState.idle;

  /// 句子聚合缓冲区（用于连续对话）
  final List<String> _sentenceBuffer = [];

  /// 句子聚合计时器
  Timer? _sentenceAggregationTimer;

  /// 句子聚合等待时间（毫秒）
  /// 收到ASR句子结束后等待这么长时间，如果用户继续说话则合并
  /// 优化：从2000ms减少到500ms，参考chat-companion-app的即时处理模式
  /// 过长的延迟会导致用户体验下降
  static const int _sentenceAggregationDelayMs = 500;

  /// 是否正在说话（基于VAD）
  bool _isUserSpeaking = false;

  /// 回调
  /// 处理用户输入，返回LLM响应流
  Future<void> Function(String userInput, void Function(String chunk) onChunk, VoidCallback onComplete)? onProcessInput;

  /// 状态变化回调
  void Function(VoicePipelineState state)? onStateChanged;

  /// ASR中间结果回调（用于UI显示）
  void Function(String text)? onPartialResult;

  /// ASR最终结果回调
  void Function(String text)? onFinalResult;

  /// 打断回调
  void Function(BargeInResult result)? onBargeIn;

  /// 错误回调
  void Function(Object error)? onError;

  /// 需要重启音频录制回调（当ASR超时或流意外结束时触发）
  VoidCallback? onNeedRestartRecording;

  /// 事件流
  final _stateController = StreamController<VoicePipelineState>.broadcast();
  Stream<VoicePipelineState> get stateStream => _stateController.stream;

  VoicePipelineController({
    required VoiceRecognitionEngine asrEngine,
    required StreamingTTSService ttsService,
    RealtimeVADService? vadService,
    PipelineConfig? config,
  })  : _asrEngine = asrEngine,
        _ttsService = ttsService,
        _vadService = vadService,
        _config = config ?? PipelineConfig.defaultConfig {
    _responseTracker = ResponseTracker();
    _bargeInDetector = BargeInDetectorV2(config: _config);

    _inputPipeline = InputPipeline(
      asrEngine: _asrEngine,
      vadService: _vadService,
      bargeInDetector: _bargeInDetector,
    );

    _outputPipeline = OutputPipeline(
      ttsService: _ttsService,
      responseTracker: _responseTracker,
      bargeInDetector: _bargeInDetector,
      config: _config,
    );

    _setupCallbacks();
  }

  /// 当前状态
  VoicePipelineState get state => _state;

  /// 是否正在运行
  bool get isRunning => _state != VoicePipelineState.idle;

  /// 是否正在监听
  bool get isListening => _state == VoicePipelineState.listening;

  /// 是否正在播放
  bool get isSpeaking => _state == VoicePipelineState.speaking;

  /// 响应追踪器（供外部查询）
  ResponseTracker get responseTracker => _responseTracker;

  /// 设置回调
  void _setupCallbacks() {
    // 输入流水线回调
    _inputPipeline.onPartialResult = _handlePartialResult;
    _inputPipeline.onFinalResult = _handleFinalResult;
    _inputPipeline.onBargeIn = _handleBargeIn;
    _inputPipeline.onError = _handleInputError;  // ASR错误处理
    _inputPipeline.onSpeechStart = _handleSpeechStart;
    _inputPipeline.onSpeechEnd = _handleSpeechEnd;

    // 输出流水线回调
    _outputPipeline.onCompleted = _handleOutputCompleted;
  }

  /// 处理语音开始（VAD检测）
  void _handleSpeechStart() {
    _isUserSpeaking = true;
    debugPrint('[VoicePipelineController] VAD: 用户开始说话');
  }

  /// 处理语音结束（VAD检测）
  void _handleSpeechEnd() {
    _isUserSpeaking = false;
    debugPrint('[VoicePipelineController] VAD: 用户停止说话');

    // 如果有缓存的句子且用户已停止说话，快速处理
    // 优化：从1000ms减少到300ms，参考chat-companion-app的即时响应模式
    if (_sentenceBuffer.isNotEmpty) {
      debugPrint('[VoicePipelineController] VAD检测到静音，缓冲区有${_sentenceBuffer.length}个句子，延迟300ms处理');
      _sentenceAggregationTimer?.cancel();
      _sentenceAggregationTimer = Timer(
        const Duration(milliseconds: 300),
        () => _processAggregatedSentences(),
      );
    }
  }

  /// 是否正在重启输入流水线（防止重复重启）
  bool _isRestartingInput = false;

  /// 处理输入流水线错误（ASR错误/流结束）
  Future<void> _handleInputError(Object error) async {
    debugPrint('[VoicePipelineController] 输入错误: $error');

    // 如果已经在重启中，忽略后续错误（防止重复重启循环）
    if (_isRestartingInput) {
      debugPrint('[VoicePipelineController] 已在重启中，忽略此错误');
      return;
    }

    // 如果正在监听状态，尝试重启ASR
    if (_state == VoicePipelineState.listening) {
      await _restartInputPipeline();
    } else if (_state == VoicePipelineState.processing) {
      // 如果正在处理中遇到错误，等待处理完成后重启
      debugPrint('[VoicePipelineController] 处理中遇到ASR错误，等待处理完成');
    } else {
      debugPrint('[VoicePipelineController] 当前状态=$_state，忽略错误');
    }
  }

  /// 重启输入流水线
  Future<void> _restartInputPipeline() async {
    if (_isRestartingInput) {
      debugPrint('[VoicePipelineController] 已在重启中，忽略重复调用');
      return;
    }

    _isRestartingInput = true;
    debugPrint('[VoicePipelineController] ===== 开始重启输入流水线 =====');
    debugPrint('[VoicePipelineController] 当前状态: controller=$_state, input=${_inputPipeline.state}');

    try {
      debugPrint('[VoicePipelineController] 调用 stop()...');
      await _inputPipeline.stop();
      debugPrint('[VoicePipelineController] stop() 完成，状态: ${_inputPipeline.state}');

      debugPrint('[VoicePipelineController] 调用 reset()...');
      _inputPipeline.reset();
      debugPrint('[VoicePipelineController] reset() 完成，状态: ${_inputPipeline.state}');

      // 先启动输入流水线，确保音频流控制器已创建
      debugPrint('[VoicePipelineController] 调用 start()...');
      await _inputPipeline.start();
      debugPrint('[VoicePipelineController] start() 完成，状态: ${_inputPipeline.state}');

      // 再通知外部重启音频录制（此时音频流控制器已就绪，可以接收数据）
      // 注意：顺序很重要！必须先创建控制器再重启录制，否则会丢失音频数据
      debugPrint('[VoicePipelineController] 通知外部重启音频录制...');
      onNeedRestartRecording?.call();

      debugPrint('[VoicePipelineController] ===== 输入流水线重启成功，准备接收音频 =====');
      debugPrint('[VoicePipelineController] 最终状态: controller=$_state, input=${_inputPipeline.state}');
    } catch (e, stack) {
      debugPrint('[VoicePipelineController] !!!!! 重启输入流水线失败 !!!!!');
      debugPrint('[VoicePipelineController] 错误: $e');
      debugPrint('[VoicePipelineController] 堆栈: $stack');
      onError?.call(e);

      // 重启失败时，仍然尝试重置到listening状态
      if (_state != VoicePipelineState.listening) {
        _setState(VoicePipelineState.listening);
      }
    } finally {
      _isRestartingInput = false;
      debugPrint('[VoicePipelineController] _isRestartingInput 已重置为 false');
    }
  }

  /// 启动流水线
  Future<void> start() async {
    if (_state != VoicePipelineState.idle) {
      debugPrint('[VoicePipelineController] 已在运行中');
      return;
    }

    try {
      _setState(VoicePipelineState.listening);

      // 确保 InputPipeline 处于 idle 状态，否则先重置
      // 这解决了停止后重新启动时状态为 stopped 的问题
      if (_inputPipeline.state != InputPipelineState.idle) {
        debugPrint('[VoicePipelineController] InputPipeline状态为${_inputPipeline.state}，先重置');
        _inputPipeline.reset();
      }

      await _inputPipeline.start();
      debugPrint('[VoicePipelineController] 已启动');
    } catch (e) {
      debugPrint('[VoicePipelineController] 启动失败: $e');
      _setState(VoicePipelineState.idle);
      onError?.call(e);
      rethrow;
    }
  }

  /// 停止流水线
  Future<void> stop() async {
    if (_state == VoicePipelineState.idle) return;

    _setState(VoicePipelineState.stopping);

    try {
      // 取消句子聚合计时器
      _sentenceAggregationTimer?.cancel();
      _sentenceAggregationTimer = null;
      _sentenceBuffer.clear();
      _isUserSpeaking = false;

      await _inputPipeline.stop();
      await _outputPipeline.stop();
      _responseTracker.reset();
      _bargeInDetector.reset();
    } finally {
      _setState(VoicePipelineState.idle);
      debugPrint('[VoicePipelineController] 已停止');
    }
  }

  /// 处理ASR中间结果
  void _handlePartialResult(String text) {
    onPartialResult?.call(text);
  }

  /// 处理ASR最终结果
  ///
  /// 使用句子聚合机制 + VAD辅助判断：
  /// 1. 收到ASR句子结束时，先缓存句子
  /// 2. 如果VAD显示用户仍在说话，只缓存不启动计时器
  /// 3. 如果VAD显示用户停止说话，启动短延迟（500ms）后处理
  /// 4. 保险机制：无论VAD状态，2秒后强制处理（防止VAD失灵）
  Future<void> _handleFinalResult(String text) async {
    if (text.trim().isEmpty) return;

    debugPrint('[VoicePipelineController] 收到ASR句子: "$text", VAD说话中=$_isUserSpeaking');

    // 将句子加入缓冲区
    _sentenceBuffer.add(text);
    debugPrint('[VoicePipelineController] 句子缓冲区: $_sentenceBuffer');

    // 通知外部（用于UI显示当前识别的内容）
    onFinalResult?.call(text);

    // 取消之前的计时器
    _sentenceAggregationTimer?.cancel();

    if (_isUserSpeaking) {
      // VAD显示用户仍在说话，启动保险计时器
      // 优化：从2000ms减少到500ms
      debugPrint('[VoicePipelineController] 用户仍在说话，启动保险计时器 (${_sentenceAggregationDelayMs}ms)');
      _sentenceAggregationTimer = Timer(
        Duration(milliseconds: _sentenceAggregationDelayMs),
        () {
          debugPrint('[VoicePipelineController] 保险计时器触发，处理');
          _processAggregatedSentences();
        },
      );
    } else {
      // VAD显示用户已停止说话，快速处理
      // 优化：从1500ms减少到400ms，参考chat-companion-app的即时响应
      debugPrint('[VoicePipelineController] 用户已停止说话，启动快速处理 (400ms)');
      _sentenceAggregationTimer = Timer(
        const Duration(milliseconds: 400),
        () => _processAggregatedSentences(),
      );
    }
  }

  /// 处理聚合后的句子
  Future<void> _processAggregatedSentences() async {
    if (_sentenceBuffer.isEmpty) return;

    // 合并所有缓存的句子
    final aggregatedText = _sentenceBuffer.join('');
    _sentenceBuffer.clear();

    debugPrint('[VoicePipelineController] 句子聚合完成，开始处理: "$aggregatedText"');

    // 开始处理
    _setState(VoicePipelineState.processing);

    // 启动新响应
    final responseId = _responseTracker.startNewResponse();
    _outputPipeline.start(responseId);

    // 调用外部处理
    if (onProcessInput != null) {
      try {
        await onProcessInput!(
          aggregatedText,
          (chunk) {
            // LLM输出块 → 输出流水线
            _outputPipeline.addChunk(chunk);

            // 首次收到输出，切换到speaking状态
            if (_state == VoicePipelineState.processing) {
              _setState(VoicePipelineState.speaking);
            }
          },
          () {
            // LLM输出完成
            _outputPipeline.complete();
          },
        );

        // 安全检查：如果 onProcessInput 完成后状态仍然是 processing
        // 说明 onChunk 回调没有被调用（可能响应为空），需要手动转换状态
        if (_state == VoicePipelineState.processing) {
          debugPrint('[VoicePipelineController] onProcessInput完成后状态仍为processing，手动切换到listening');
          _setState(VoicePipelineState.listening);
        }
      } catch (e) {
        debugPrint('[VoicePipelineController] 处理失败: $e');
        onError?.call(e);
        _setState(VoicePipelineState.listening);
      }
    } else {
      debugPrint('[VoicePipelineController] 未设置onProcessInput回调');
      _setState(VoicePipelineState.listening);
    }
  }

  /// 处理打断
  Future<void> _handleBargeIn(BargeInResult result) async {
    debugPrint('[VoicePipelineController] 处理打断: $result');

    onBargeIn?.call(result);

    // 停止输出
    await _outputPipeline.fadeOutAndStop();

    // 取消当前响应
    _responseTracker.cancelCurrentResponse();

    // 回到监听状态
    _setState(VoicePipelineState.listening);
  }

  /// 处理输出完成
  Future<void> _handleOutputCompleted() async {
    debugPrint('[VoicePipelineController] ========== 输出完成回调 ==========');
    debugPrint('[VoicePipelineController] 当前状态: $_state, feedDataCount=$_feedDataCount');

    // 输出完成后回到监听状态
    if (_state == VoicePipelineState.speaking ||
        _state == VoicePipelineState.processing) {
      debugPrint('[VoicePipelineController] 状态符合条件，准备切换到listening并重启输入');

      // 先切换到listening状态，确保音频数据可以继续流入
      _setState(VoicePipelineState.listening);

      // 重置feedDataCount，以便重新开始日志计数
      _feedDataCount = 0;
      debugPrint('[VoicePipelineController] feedDataCount已重置');

      // 输出完成后重启输入流水线（确保ASR正常运行）
      await _restartInputPipeline();
      debugPrint('[VoicePipelineController] ========== 输出完成处理结束 ==========');
    } else {
      debugPrint('[VoicePipelineController] 状态不符合条件($_state)，跳过重启');
    }
  }

  /// 设置状态
  void _setState(VoicePipelineState newState) {
    if (_state == newState) return;

    _state = newState;
    _stateController.add(_state);
    onStateChanged?.call(_state);

    debugPrint('[VoicePipelineController] 状态变更: $newState');
  }

  /// 发送音频数据
  ///
  /// 将麦克风采集的音频数据发送到输入流水线
  ///
  /// 注意：listening 和 speaking 状态都需要传递音频
  /// - listening: 正常识别用户输入
  /// - speaking: 支持打断检测（BargeInDetector + EchoFilter 会过滤回声）
  int _feedDataCount = 0;

  /// 高振幅打断阈值（平均振幅超过此值认为用户在大声说话）
  static const int _bargeInAmplitudeThreshold = 5000;

  /// 高振幅连续帧计数器（需要连续多帧高振幅才触发，避免误触发）
  int _highAmplitudeFrameCount = 0;

  /// 触发打断所需的连续高振幅帧数
  static const int _bargeInFrameThreshold = 3;

  void feedAudioData(Uint8List audioData) {
    _feedDataCount++;
    // 前10次每次都打印，之后每50次打印一次（更频繁的日志以便调试）
    final shouldLog = _feedDataCount <= 10 || _feedDataCount % 50 == 0;

    if (shouldLog) {
      final inputState = _inputPipeline.state;
      debugPrint('[VoicePipelineController] feedAudioData #$_feedDataCount, 状态=$_state, inputState=$inputState');
    }

    // listening 和 speaking 状态都传递音频
    // speaking 状态下的音频用于打断检测
    if (_state == VoicePipelineState.listening || _state == VoicePipelineState.speaking) {
      _inputPipeline.feedAudioData(audioData);

      // speaking 状态下检测高振幅打断
      if (_state == VoicePipelineState.speaking) {
        _checkAmplitudeBargeIn(audioData);
      }
    } else if (shouldLog) {
      debugPrint('[VoicePipelineController] 状态=$_state，跳过feedAudioData（等待状态变为listening或speaking）');
    }
  }

  /// 检测基于振幅的打断
  /// 如果在TTS播放期间检测到连续的高振幅音频，说明用户在大声说话，触发打断
  void _checkAmplitudeBargeIn(Uint8List audioData) {
    // 计算平均振幅
    int sumAmplitude = 0;
    if (audioData.length >= 2) {
      for (int i = 0; i < audioData.length - 1; i += 2) {
        int sample = audioData[i] | (audioData[i + 1] << 8);
        if (sample > 32767) sample -= 65536;
        sumAmplitude += sample.abs();
      }
    }
    final avgAmplitude = audioData.length > 2 ? sumAmplitude ~/ (audioData.length ~/ 2) : 0;

    // 检查是否超过阈值
    if (avgAmplitude > _bargeInAmplitudeThreshold) {
      _highAmplitudeFrameCount++;
      if (_highAmplitudeFrameCount >= _bargeInFrameThreshold) {
        debugPrint('[VoicePipelineController] 检测到高振幅打断: 平均振幅=$avgAmplitude, 连续帧=$_highAmplitudeFrameCount');
        _highAmplitudeFrameCount = 0; // 重置计数器
        _handleAmplitudeBargeIn();
      }
    } else {
      _highAmplitudeFrameCount = 0; // 重置计数器
    }
  }

  /// 处理振幅触发的打断
  void _handleAmplitudeBargeIn() {
    if (_state != VoicePipelineState.speaking) return;

    debugPrint('[VoicePipelineController] 执行振幅打断');

    // 创建一个打断结果
    final result = BargeInResult(
      triggered: true,
      layer: BargeInLayer.layer1VadAsr, // 使用layer1标记
      text: '[振幅打断]',
      similarity: 0.0,
    );

    _handleBargeIn(result);
  }

  /// 手动触发处理（用于测试或非语音输入）
  Future<void> processManualInput(String text) async {
    await _handleFinalResult(text);
  }

  /// 重置流水线
  void reset() {
    // 取消句子聚合计时器
    _sentenceAggregationTimer?.cancel();
    _sentenceAggregationTimer = null;
    _sentenceBuffer.clear();
    _isUserSpeaking = false;

    _inputPipeline.reset();
    _outputPipeline.reset();
    _responseTracker.reset();
    _bargeInDetector.reset();

    if (_state != VoicePipelineState.idle) {
      _setState(VoicePipelineState.idle);
    }
  }

  /// 释放资源
  void dispose() {
    stop();
    _inputPipeline.dispose();
    _outputPipeline.dispose();
    _stateController.close();
  }
}
