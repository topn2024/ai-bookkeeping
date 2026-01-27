import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../streaming_tts_service.dart';
import '../../voice_recognition_engine.dart';
import '../realtime_vad_config.dart';
import '../config/pipeline_config.dart';
import '../detection/barge_in_detector_v2.dart';
import '../dynamic_aggregation_window.dart';
import '../intelligence_engine/proactive_conversation_manager.dart';
import '../intelligence_engine/result_buffer.dart';
import '../tracking/response_tracker.dart';
import 'input_pipeline.dart';
import 'output_pipeline.dart';

/// 流水线状态
enum VoicePipelineState {
  idle, // 空闲
  listening, // 监听用户输入
  processing, // 处理用户输入（等待LLM响应）
  speaking, // 播放响应
  stopping, // 停止中
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

  /// 动态聚合窗口
  late final DynamicAggregationWindow _dynamicWindow;

  /// 句子聚合缓冲区（用于连续对话）
  final List<String> _sentenceBuffer = [];

  /// 句子聚合计时器
  Timer? _sentenceAggregationTimer;

  /// 聚合计时器ID（用于防止竞态条件）
  int _aggregationTimerId = 0;

  /// 最大等待计时器（5秒兜底）
  Timer? _maxWaitTimer;

  /// 累计等待时间（毫秒）- 用于最大等待时间兜底
  int _cumulativeWaitMs = 0;

  /// 上次语音结束时间 - 用于计算停顿时长
  DateTime? _lastSpeechEndTime;

  /// 是否正在说话（基于VAD）
  bool _isUserSpeaking = false;

  /// 主动对话管理器
  late final ProactiveConversationManager _proactiveManager;

  /// 主动话题生成器
  late final ProactiveTopicGenerator _topicGenerator;

  /// 回调
  /// 处理用户输入，返回LLM响应流
  Future<void> Function(
    String userInput,
    void Function(String chunk) onChunk,
    VoidCallback onComplete,
  )?
  onProcessInput;

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

  /// 主动对话消息回调（当系统主动发起对话时触发）
  void Function(String message)? onProactiveMessage;

  /// 会话超时回调（连续3次无回应或30秒无响应时触发）
  VoidCallback? onSessionTimeout;

  /// 事件流
  final _stateController = StreamController<VoicePipelineState>.broadcast();
  Stream<VoicePipelineState> get stateStream => _stateController.stream;

  VoicePipelineController({
    required VoiceRecognitionEngine asrEngine,
    required StreamingTTSService ttsService,
    RealtimeVADService? vadService,
    PipelineConfig? config,
    ResultBuffer? resultBuffer,
    UserPreferencesProvider? userPreferencesProvider,
  }) : _asrEngine = asrEngine,
       _ttsService = ttsService,
       _vadService = vadService,
       _config = config ?? PipelineConfig.defaultConfig {
    _dynamicWindow = DynamicAggregationWindow();
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

    // 初始化主动对话管理器
    // 如果提供了 ResultBuffer，使用 SmartTopicGenerator 以支持查询结果通知
    // 否则降级使用 SimpleTopicGenerator
    _topicGenerator = resultBuffer != null
        ? SmartTopicGenerator(
            resultBuffer: resultBuffer,
            preferencesProvider: userPreferencesProvider,
          )
        : SimpleTopicGenerator();
    _proactiveManager = ProactiveConversationManager(
      topicGenerator: _topicGenerator,
      onProactiveMessage: _handleProactiveMessage,
      onSessionEnd: _handleSessionTimeout,
      isSoundPlaying: () => _isUserSpeaking || _outputPipeline.isSpeaking,
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
    _inputPipeline.onError = _handleInputError; // ASR错误处理
    _inputPipeline.onSpeechStart = _handleSpeechStart;
    _inputPipeline.onSpeechEnd = _handleSpeechEnd;

    // 输出流水线回调
    _outputPipeline.onCompleted = _handleOutputCompleted;
  }

  /// 处理语音开始（VAD检测）
  void _handleSpeechStart() {
    _isUserSpeaking = true;
    debugPrint('[VoicePipelineController] VAD: 用户开始说话，停止主动对话监听');

    // 用户开始说话，取消最大等待计时器
    // 因为用户还在说，不应该强制处理
    if (_maxWaitTimer != null) {
      debugPrint('[VoicePipelineController] 用户继续说话，取消最大等待计时器');
      _maxWaitTimer?.cancel();
      _maxWaitTimer = null;
    }

    // 用户开始说话时停止主动对话监听（不是重置）
    // 等用户说完后再根据情况决定是否重启
    _proactiveManager.stopMonitoring();
  }

  /// 处理语音结束（VAD检测）
  void _handleSpeechEnd() {
    _isUserSpeaking = false;
    _lastSpeechEndTime = DateTime.now();
    debugPrint(
      '[VoicePipelineController] VAD: 用户停止说话，缓冲区=${_sentenceBuffer.length}句',
    );

    if (_sentenceBuffer.isNotEmpty) {
      // 有缓存句子，启动聚合计时器
      _startDynamicAggregationTimer();

      // 用户停止说话后，启动最大等待计时器（基于语音结束时间）
      _startMaxWaitTimerFromSpeechEnd();
    }

    // 用户停止说话，尝试启动静默监听
    // 如果TTS正在播放，startSilenceMonitoring会自动跳过
    debugPrint('[VoicePipelineController] 用户停止说话，尝试启动静默监听');
    _proactiveManager.startSilenceMonitoring();
  }

  /// 是否正在重启输入流水线（防止重复重启）
  bool _isRestartingInput = false;

  /// 是否已释放（防止 dispose 后回调仍被触发）
  bool _isDisposed = false;

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
    debugPrint(
      '[VoicePipelineController] 当前状态: controller=$_state, input=${_inputPipeline.state}',
    );

    try {
      debugPrint('[VoicePipelineController] 调用 stop()...');
      await _inputPipeline.stop();
      debugPrint(
        '[VoicePipelineController] stop() 完成，状态: ${_inputPipeline.state}',
      );

      debugPrint('[VoicePipelineController] 调用 reset()...');
      _inputPipeline.reset();
      debugPrint(
        '[VoicePipelineController] reset() 完成，状态: ${_inputPipeline.state}',
      );

      // 先启动输入流水线，确保音频流控制器已创建
      debugPrint('[VoicePipelineController] 调用 start()...');
      await _inputPipeline.start();
      debugPrint(
        '[VoicePipelineController] start() 完成，状态: ${_inputPipeline.state}',
      );

      // 再通知外部重启音频录制（此时音频流控制器已就绪，可以接收数据）
      // 注意：顺序很重要！必须先创建控制器再重启录制，否则会丢失音频数据
      debugPrint('[VoicePipelineController] 通知外部重启音频录制...');
      onNeedRestartRecording?.call();

      debugPrint('[VoicePipelineController] ===== 输入流水线重启成功，准备接收音频 =====');
      debugPrint(
        '[VoicePipelineController] 最终状态: controller=$_state, input=${_inputPipeline.state}',
      );
    } catch (e, stack) {
      debugPrint('[VoicePipelineController] !!!!! 重启输入流水线失败 !!!!!');
      debugPrint('[VoicePipelineController] 错误: $e');
      debugPrint('[VoicePipelineController] 堆栈: $stack');
      onError?.call(e);

      // 重启失败时，先清理 InputPipeline 状态，再重置控制器状态
      // 这样确保 InputPipeline 不会处于不一致的中间状态
      try {
        debugPrint('[VoicePipelineController] 尝试清理失败的 InputPipeline...');
        await _inputPipeline.stop();
        _inputPipeline.reset();
        debugPrint('[VoicePipelineController] InputPipeline 清理完成');
      } catch (cleanupError) {
        debugPrint(
          '[VoicePipelineController] InputPipeline 清理也失败: $cleanupError',
        );
      }

      // 然后重置控制器状态
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
        debugPrint(
          '[VoicePipelineController] InputPipeline状态为${_inputPipeline.state}，先重置',
        );
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
    debugPrint('[VoicePipelineController] stop() 被调用, 当前状态=$_state');
    if (_state == VoicePipelineState.idle) {
      debugPrint('[VoicePipelineController] 状态已经是idle，直接返回');
      return;
    }

    _setState(VoicePipelineState.stopping);
    debugPrint('[VoicePipelineController] 状态已设置为stopping');

    try {
      // 取消所有计时器
      _sentenceAggregationTimer?.cancel();
      _sentenceAggregationTimer = null;
      _maxWaitTimer?.cancel();
      _maxWaitTimer = null;

      // 重要：停止前先处理缓冲区中未处理的句子
      // 这样用户说完话后即使流水线停止，内容也不会丢失
      if (_sentenceBuffer.isNotEmpty) {
        debugPrint('[VoicePipelineController] 停止前处理缓冲区: $_sentenceBuffer');
        await _processAggregatedSentences();
      }

      _cumulativeWaitMs = 0;
      _lastSpeechEndTime = null;
      _isUserSpeaking = false;
      debugPrint('[VoicePipelineController] 聚合计时器已清理');

      debugPrint('[VoicePipelineController] 开始停止InputPipeline...');
      await _inputPipeline.stop();
      debugPrint('[VoicePipelineController] InputPipeline已停止');

      debugPrint('[VoicePipelineController] 开始停止OutputPipeline...');
      await _outputPipeline.stop();
      debugPrint('[VoicePipelineController] OutputPipeline已停止');

      _responseTracker.reset();
      _bargeInDetector.reset();
      debugPrint('[VoicePipelineController] 追踪器和检测器已重置');
    } finally {
      _setState(VoicePipelineState.idle);
      debugPrint('[VoicePipelineController] 已停止，状态设置为idle');
    }
  }

  /// 触发主动消息（用于延迟响应等场景）
  ///
  /// 外部调用此方法可以在流水线listening状态下播放消息
  /// [isUserResponse] 为true时表示这是对用户输入的响应（延迟响应），不计入主动对话次数
  void triggerProactiveMessage(String message, {bool isUserResponse = false}) {
    debugPrint(
      '[VoicePipelineController] 触发主动消息: $message (isUserResponse=$isUserResponse)',
    );
    _handleProactiveMessage(message, isUserResponse: isUserResponse);
  }

  /// 处理ASR中间结果
  ///
  /// 中间结果表示用户仍在说话，需要：
  /// 1. 暂停主动对话监听（防止用户说话时被打断）
  /// 2. 重置聚合计时器（滑动窗口机制）
  void _handlePartialResult(String text) {
    onPartialResult?.call(text);

    // 收到中间结果说明用户正在说话，暂停主动对话监听
    // 这是 VAD speechStart 的补充机制，确保即使 VAD 没检测到也能正确暂停
    _proactiveManager.stopMonitoring();

    // 如果有聚合计时器在运行且缓冲区有内容，收到中间结果说明用户还在说话
    // 重置计时器，等待用户说完（滑动窗口机制的关键）
    if (_sentenceAggregationTimer != null && _sentenceBuffer.isNotEmpty) {
      debugPrint('[VoicePipelineController] 收到中间结果"$text"，重置聚合计时器');
      _sentenceAggregationTimer?.cancel();
      // 传入中间结果文本，用于连接词检测
      _startDynamicAggregationTimer(pendingPartialText: text);
    }
  }

  /// 处理ASR最终结果
  ///
  /// 使用滑动窗口 + 动态等待时间：
  /// 1. 收到ASR句子结束时，先缓存句子
  /// 2. 取消旧计时器，启动新计时器（滑动窗口机制）
  /// 3. 动态计算等待时间（根据语义分析）
  /// 4. 最大等待时间兜底（5秒）
  Future<void> _handleFinalResult(String text) async {
    if (text.trim().isEmpty) return;

    debugPrint(
      '[VoicePipelineController] 收到ASR句子: "$text", VAD说话中=$_isUserSpeaking',
    );


    // 将句子加入缓冲区
    _sentenceBuffer.add(text);
    debugPrint('[VoicePipelineController] 句子缓冲区: $_sentenceBuffer');

    // 通知外部（用于UI显示当前识别的内容）
    onFinalResult?.call(text);

    // 滑动窗口机制：取消之前的计时器，启动新计时器
    _sentenceAggregationTimer?.cancel();

    // 启动动态聚合计时器
    _startDynamicAggregationTimer();

    // 注意：最大等待计时器改为在 _handleSpeechEnd() 中启动
    // 这样确保只有在用户停止说话后才开始计算最大等待时间
    // 避免用户说话中被强制打断
  }

  /// 启动动态聚合计时器
  ///
  /// [pendingPartialText] 可选的中间结果文本，用于检测连接词
  /// 当收到中间结果时传入，帮助判断用户是否还要继续说
  void _startDynamicAggregationTimer({String? pendingPartialText}) {
    // 计算自上次语音结束的时间
    int? msSinceLastSpeechEnd;
    if (_lastSpeechEndTime != null) {
      msSinceLastSpeechEnd = DateTime.now()
          .difference(_lastSpeechEndTime!)
          .inMilliseconds;
    }

    // 合并所有缓存的句子用于语义分析
    // 如果有中间结果，也要加入分析（用于检测连接词）
    String aggregatedText = _sentenceBuffer.join('');
    if (pendingPartialText != null && pendingPartialText.isNotEmpty) {
      aggregatedText += pendingPartialText;
      debugPrint('[VoicePipelineController] 包含中间结果进行语义分析: "$aggregatedText"');
    }

    // 创建聚合上下文
    final context = AggregationContext(
      text: aggregatedText,
      isUserSpeaking: _isUserSpeaking,
      msSinceLastSpeechEnd: msSinceLastSpeechEnd,
      bufferedSentenceCount: _sentenceBuffer.length,
      cumulativeWaitMs: _cumulativeWaitMs,
    );

    // 计算动态等待时间
    final waitResult = _dynamicWindow.calculateWaitTime(context);
    debugPrint('[VoicePipelineController] 动态等待: $waitResult');

    // 如果强制处理，立即处理
    if (waitResult.forceProcess) {
      debugPrint('[VoicePipelineController] 强制处理（超过最大等待时间）');
      _processAggregatedSentences();
      return;
    }

    // 递增计时器ID，用于防止竞态条件
    // 当旧计时器的回调在取消后仍然执行时，通过ID检查可以忽略它
    final currentTimerId = ++_aggregationTimerId;

    // 启动聚合计时器
    _sentenceAggregationTimer = Timer(
      Duration(milliseconds: waitResult.waitTimeMs),
      () {
        // 竞态条件防护：检查此回调是否来自当前有效的计时器
        // 如果计时器ID不匹配，说明这是一个被"取消"但仍执行的旧回调
        if (_aggregationTimerId != currentTimerId) {
          debugPrint(
            '[VoicePipelineController] 忽略过期的聚合计时器回调 (id=$currentTimerId, active=$_aggregationTimerId)',
          );
          return;
        }
        _cumulativeWaitMs += waitResult.waitTimeMs;
        debugPrint(
          '[VoicePipelineController] 聚合计时器触发 (累计${_cumulativeWaitMs}ms, timerId=$currentTimerId)',
        );
        _processAggregatedSentences();
      },
    );
  }

  /// 启动最大等待计时器（基于语音结束时间）
  ///
  /// 设计说明：
  /// - 只在用户停止说话（VAD speechEnd）后才启动
  /// - 用户继续说话（VAD speechStart）时会取消此计时器
  /// - 这样确保不会在用户说话中强制处理
  void _startMaxWaitTimerFromSpeechEnd() {
    // 取消之前的计时器，重新计时
    _maxWaitTimer?.cancel();

    debugPrint(
      '[VoicePipelineController] 启动最大等待计时器（${AggregationTiming.maxWaitMs}ms，基于语音结束时间）',
    );

    _maxWaitTimer = Timer(
      Duration(milliseconds: AggregationTiming.maxWaitMs),
      () {
        // 再次检查用户是否在说话（双重保险）
        if (_isUserSpeaking) {
          debugPrint('[VoicePipelineController] 最大等待触发时用户正在说话，跳过');
          return;
        }
        debugPrint(
          '[VoicePipelineController] 最大等待计时器触发（${AggregationTiming.maxWaitMs}ms，基于语音结束）',
        );
        _processAggregatedSentences();
      },
    );
  }

  /// 处理聚合后的句子
  Future<void> _processAggregatedSentences() async {
    if (_sentenceBuffer.isEmpty) return;

    // 取消所有计时器
    _sentenceAggregationTimer?.cancel();
    _sentenceAggregationTimer = null;
    _maxWaitTimer?.cancel();
    _maxWaitTimer = null;

    // 重置累计等待时间
    _cumulativeWaitMs = 0;

    // 合并所有缓存的句子
    final aggregatedText = _sentenceBuffer.join('');
    _sentenceBuffer.clear();

    debugPrint('[VoicePipelineController] 句子聚合完成，开始处理: "$aggregatedText"');

    // 用户有输入，重置主动对话计时器和计数
    _proactiveManager.resetTimer();

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
          debugPrint(
            '[VoicePipelineController] onProcessInput完成后状态仍为processing，手动切换到listening',
          );
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
  ///
  /// 使用 try-finally 确保状态始终恢复，即使过程中发生异常
  Future<void> _handleBargeIn(BargeInResult result) async {
    debugPrint('[VoicePipelineController] 处理打断: $result');

    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('[VoicePipelineController] 已释放，忽略打断处理');
      return;
    }

    try {
      // 通知外部回调（保护回调异常不影响后续流程）
      try {
        onBargeIn?.call(result);
      } catch (e) {
        debugPrint('[VoicePipelineController] 打断回调异常: $e');
      }

      // 停止输出
      await _outputPipeline.fadeOutAndStop();

      // 取消当前响应
      _responseTracker.cancelCurrentResponse();
    } finally {
      // 无论成功还是失败，都要回到监听状态（除非已释放）
      if (!_isDisposed && _state != VoicePipelineState.idle) {
        _setState(VoicePipelineState.listening);
      }
    }
  }

  /// 处理输出完成
  ///
  /// 注意：使用 _isDisposed 检查防止竞态条件
  /// 在 await _restartInputPipeline() 期间，stop() 可能被调用
  Future<void> _handleOutputCompleted() async {
    debugPrint('[VoicePipelineController] ========== 输出完成回调 ==========');
    debugPrint(
      '[VoicePipelineController] 当前状态: $_state, feedDataCount=$_feedDataCount',
    );

    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('[VoicePipelineController] 已释放，跳过输出完成处理');
      return;
    }

    // 输出完成后回到监听状态
    if (_state == VoicePipelineState.speaking ||
        _state == VoicePipelineState.processing) {
      debugPrint('[VoicePipelineController] 状态符合条件，准备切换到listening并重启输入');

      // 先切换到listening状态，确保音频数据可以继续流入
      _setState(VoicePipelineState.listening);

      // 重置feedDataCount，以便重新开始日志计数
      _feedDataCount = 0;
      debugPrint('[VoicePipelineController] feedDataCount已重置');

      // 再次检查 _isDisposed（状态切换期间可能被 dispose）
      if (_isDisposed) {
        debugPrint('[VoicePipelineController] 状态切换后发现已释放，跳过重启');
        return;
      }

      // 输出完成后重启输入流水线（确保ASR正常运行）
      await _restartInputPipeline();

      // TTS播放完成，尝试启动静默监听
      // 如果用户正在说话，startSilenceMonitoring会自动跳过
      debugPrint('[VoicePipelineController] TTS播放完成，尝试启动静默监听');
      _proactiveManager.startSilenceMonitoring();

      debugPrint('[VoicePipelineController] ========== 输出完成处理结束 ==========');
    } else {
      debugPrint('[VoicePipelineController] 状态不符合条件($_state)，跳过重启');
    }
  }

  /// 设置状态
  void _setState(VoicePipelineState newState) {
    if (_state == newState) return;

    final oldState = _state;
    _state = newState;

    // 检查 StreamController 是否已关闭，避免 dispose 后写入异常
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }

    // 通知外部状态变更（保护回调异常不影响内部状态管理）
    try {
      onStateChanged?.call(_state);
    } catch (e) {
      debugPrint('[VoicePipelineController] 状态变更回调异常: $e');
    }

    debugPrint('[VoicePipelineController] 状态变更: $oldState → $newState');

    // 主动对话状态管理（必须执行，确保内部状态一致）
    _updateProactiveMonitoring(oldState, newState);
  }

  /// 更新主动对话监听状态
  ///
  /// 静默计时器现在基于声音状态自动管理：
  /// - 有声音（用户说话 OR TTS播放）→ 自动停止
  /// - 没有声音 → 自动启动
  /// 这里只需要在状态变化时尝试启动/停止，具体是否执行由 ProactiveConversationManager 判断
  void _updateProactiveMonitoring(
    VoicePipelineState oldState,
    VoicePipelineState newState,
  ) {
    // 进入 listening 状态：尝试启动静默监听
    // 如果有声音在播放，startSilenceMonitoring会自动跳过
    if (newState == VoicePipelineState.listening) {
      debugPrint('[VoicePipelineController] 进入listening，尝试启动主动对话监听');
      _proactiveManager.startSilenceMonitoring();
    }
    // 进入 idle 状态：重置会话
    if (newState == VoicePipelineState.idle) {
      debugPrint('[VoicePipelineController] 进入idle，重置主动对话会话');
      _proactiveManager.resetForNewSession();
    }
  }

  /// 发送音频数据
  ///
  /// 将麦克风采集的音频数据发送到输入流水线
  ///
  /// 注意：
  /// - listening: 发送给ASR+VAD，正常识别用户输入
  /// - speaking: 只发送给VAD（不发给ASR），用于打断检测
  ///   - 不发给ASR的原因：TTS播放时麦克风会录入TTS声音，即使有AEC也可能有残留
  ///   - 打断后会重启InputPipeline，届时再发给ASR识别用户的真实输入
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
      debugPrint(
        '[VoicePipelineController] feedAudioData #$_feedDataCount, 状态=$_state, inputState=$inputState',
      );
    }

    // listening 状态：发送给ASR+VAD进行识别
    // speaking 状态：只发送给VAD用于打断检测（不发给ASR，避免TTS被识别为用户输入）
    if (_state == VoicePipelineState.listening) {
      _inputPipeline.feedAudioData(audioData);
    } else if (_state == VoicePipelineState.speaking) {
      // speaking状态只发给VAD，用于打断检测
      // 不发给ASR，因为TTS播放时会被麦克风录入，即使有AEC也可能有残留
      _inputPipeline.feedAudioToVADOnly(audioData);

      // speaking 状态下检测高振幅打断
      _checkAmplitudeBargeIn(audioData);
    } else if (shouldLog) {
      debugPrint(
        '[VoicePipelineController] 状态=$_state，跳过feedAudioData（等待状态变为listening或speaking）',
      );
    }
  }

  /// 检测基于振幅的打断
  /// 如果在TTS播放期间检测到连续的高振幅音频，说明用户在大声说话，触发打断
  void _checkAmplitudeBargeIn(Uint8List audioData) {
    // TTS正在播放时跳过振幅打断检测
    // 因为麦克风可能录入TTS的声音，导致误触发打断
    if (_outputPipeline.isSpeaking) {
      _highAmplitudeFrameCount = 0; // 重置计数器
      return;
    }

    // 计算平均振幅
    int sumAmplitude = 0;
    if (audioData.length >= 2) {
      for (int i = 0; i < audioData.length - 1; i += 2) {
        int sample = audioData[i] | (audioData[i + 1] << 8);
        if (sample > 32767) sample -= 65536;
        sumAmplitude += sample.abs();
      }
    }
    final avgAmplitude = audioData.length > 2
        ? sumAmplitude ~/ (audioData.length ~/ 2)
        : 0;

    // 检查是否超过阈值
    if (avgAmplitude > _bargeInAmplitudeThreshold) {
      _highAmplitudeFrameCount++;
      if (_highAmplitudeFrameCount >= _bargeInFrameThreshold) {
        debugPrint(
          '[VoicePipelineController] 检测到高振幅打断: 平均振幅=$avgAmplitude, 连续帧=$_highAmplitudeFrameCount',
        );
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
      layer: BargeInLayer.vadBased,
      text: '[振幅打断]',
      reason: '持续高振幅检测',
    );

    _handleBargeIn(result);
  }

  /// 手动触发处理（用于测试或非语音输入）
  Future<void> processManualInput(String text) async {
    await _handleFinalResult(text);
  }

  /// 重置流水线
  void reset() {
    // 取消所有计时器
    _sentenceAggregationTimer?.cancel();
    _sentenceAggregationTimer = null;
    _maxWaitTimer?.cancel();
    _maxWaitTimer = null;
    _sentenceBuffer.clear();
    _cumulativeWaitMs = 0;
    _lastSpeechEndTime = null;
    _isUserSpeaking = false;

    _inputPipeline.reset();
    _outputPipeline.reset();
    _responseTracker.reset();
    _bargeInDetector.reset();

    if (_state != VoicePipelineState.idle) {
      _setState(VoicePipelineState.idle);
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 主动对话
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 处理主动对话消息
  ///
  /// 当用户30秒无操作时，系统主动发起对话
  void _handleProactiveMessage(String message, {bool isUserResponse = false}) {
    debugPrint(
      '[VoicePipelineController] 收到主动对话消息: $message (isUserResponse=$isUserResponse)',
    );

    // 检查是否已释放或状态不对
    if (_isDisposed) {
      debugPrint('[VoicePipelineController] 已释放，忽略主动消息');
      return;
    }

    if (_state != VoicePipelineState.listening) {
      debugPrint('[VoicePipelineController] 非listening状态，忽略主动消息');
      return;
    }

    // 通知外部回调（保护回调异常不影响后续流程）
    try {
      onProactiveMessage?.call(message);
    } catch (e) {
      debugPrint('[VoicePipelineController] 主动消息回调异常: $e');
    }

    // 启动新响应
    final responseId = _responseTracker.startNewResponse();
    _outputPipeline.start(responseId);

    // 切换到 speaking 状态
    _setState(VoicePipelineState.speaking);

    // 通过输出流水线播放消息
    _outputPipeline.addChunk(message);
    _outputPipeline.complete();

    debugPrint('[VoicePipelineController] 主动对话消息已发送到TTS');
  }

  /// 处理会话超时（连续3次无回应或30秒无响应）
  ///
  /// 注意：先启动 stop() 再触发回调，确保：
  /// 1. 状态同步更新为 stopping（stop() 开始时立即设置）
  /// 2. 回调触发时外部可以正确读取状态
  /// 3. 清理工作在后台继续进行
  void _handleSessionTimeout() {
    debugPrint('[VoicePipelineController] 会话超时，自动结束');

    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('[VoicePipelineController] 已释放，忽略会话超时');
      return;
    }

    // 先启动停止流程（同步设置状态为 stopping）
    // 使用 fire-and-forget 模式，清理在后台进行
    stop().catchError((e, s) {
      debugPrint('[VoicePipelineController] 超时停止时出错: $e');
    });

    // 状态已更新，通知外部（保护回调异常不影响内部流程）
    try {
      onSessionTimeout?.call();
    } catch (e) {
      debugPrint('[VoicePipelineController] 会话超时回调异常: $e');
    }
  }

  /// 禁用主动对话
  void disableProactiveConversation() {
    _proactiveManager.disable();
  }

  /// 启用主动对话
  void enableProactiveConversation() {
    _proactiveManager.enable();
  }

  /// 主动对话是否已禁用
  bool get isProactiveDisabled => _proactiveManager.isDisabled;

  /// 释放资源
  /// 释放资源
  ///
  /// 注意：异步方法，确保 stop() 完成后再释放资源
  Future<void> dispose() async {
    // 先标记为已释放，阻止新的回调
    _isDisposed = true;

    // 等待停止完成
    await stop().catchError((e) {
      debugPrint('[VoicePipelineController] dispose 中 stop 失败: $e');
    });

    _proactiveManager.dispose();
    // 等待子流水线释放完成
    await _inputPipeline.dispose();
    await _outputPipeline.dispose();
    await _stateController.close();
  }
}
