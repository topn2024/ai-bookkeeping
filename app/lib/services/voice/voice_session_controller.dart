import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'voice_session_state.dart';
import 'voice_session_state_machine.dart';
import 'voice_session_config.dart';
import 'realtime_vad_config.dart';
import '../voice_recognition_engine.dart';
import '../tts_service.dart';

/// 命令处理回调类型
typedef CommandProcessorCallback = Future<String?> Function(String command);

/// 语音会话控制器
///
/// 参考 LiveKit VoicePipelineAgent 设计
///
/// 职责：
/// - 协调各服务（录音、ASR、VAD、TTS）
/// - 处理业务逻辑
/// - 响应状态变化
/// - 实现打断检测和假打断恢复
class VoiceSessionController {
  /// 状态机
  final VoiceSessionStateMachine _stateMachine;

  /// 配置
  final VoiceSessionConfig config;

  /// ASR 服务
  final VoiceRecognitionEngine _asrService;

  /// TTS 服务
  final TTSService _ttsService;

  /// VAD 服务
  final RealtimeVADService _vadService;

  /// 录音器
  final AudioRecorder _audioRecorder;

  /// 命令处理器（外部注入，调用执行层）
  CommandProcessorCallback? commandProcessor;

  /// 音频流控制器
  StreamController<Uint8List>? _audioStreamController;

  /// 音频流订阅
  StreamSubscription<Uint8List>? _audioSubscription;

  /// ASR 结果订阅
  StreamSubscription<ASRPartialResult>? _asrSubscription;

  /// 打断确认计时器
  Timer? _interruptionConfirmTimer;

  /// 假打断检测计时器
  Timer? _falseInterruptionTimer;

  /// 静默超时计时器
  Timer? _silenceTimer;

  /// 用户开始说话时间（用于计算说话时长）
  @visibleForTesting
  DateTime? userSpeechStartTime;

  /// 被打断时的剩余文本（用于假打断恢复）
  String? _interruptedText;

  /// 当前部分识别结果
  String _partialText = '';

  /// 是否已初始化
  bool _isInitialized = false;

  /// 部分识别结果（供 UI 显示）
  String get partialText => _partialText;

  /// 当前状态
  VoiceSessionState get state => _stateMachine.state;

  /// 状态流
  Stream<VoiceSessionStateChange> get stateStream => _stateMachine.stateStream;

  VoiceSessionController({
    VoiceSessionConfig? config,
    VoiceRecognitionEngine? asrService,
    TTSService? ttsService,
    RealtimeVADService? vadService,
    AudioRecorder? audioRecorder,
  })  : config = config ?? VoiceSessionConfig.defaultConfig,
        _stateMachine = VoiceSessionStateMachine(),
        _asrService = asrService ?? VoiceRecognitionEngine(),
        _ttsService = ttsService ?? TTSService.instance, // 使用单例
        _vadService = vadService ?? RealtimeVADService(),
        _audioRecorder = audioRecorder ?? AudioRecorder() {
    _setupListeners();
  }

  /// 设置监听器
  void _setupListeners() {
    // 监听状态变化
    _stateMachine.stateStream.listen(_onStateChanged);

    // 监听 VAD 事件
    _vadService.eventStream.listen(_onVADEvent);
  }

  /// 状态变化处理
  void _onStateChanged(VoiceSessionStateChange change) {
    debugPrint('[Controller] 状态变化: ${change.oldState} -> ${change.newState}');
    _configureServicesForState(change.newState);
  }

  /// 根据状态配置服务
  void _configureServicesForState(VoiceSessionState state) {
    switch (state) {
      case VoiceSessionState.idle:
        _stopAllServices();
        break;

      case VoiceSessionState.listening:
        _ensureRecordingStarted();
        _startASR();
        _startSilenceTimer();
        break;

      case VoiceSessionState.thinking:
        _stopASR(); // 停止 ASR 节省资源
        _cancelSilenceTimer();
        // VAD 继续运行
        break;

      case VoiceSessionState.speaking:
        _stopASR(); // 关键！停止 ASR 避免回声
        _cancelSilenceTimer();
        // VAD 继续运行（检测打断）
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 公开接口
  // ═══════════════════════════════════════════════════════════════

  /// 初始化（延迟初始化）
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _ttsService.initialize();
    _isInitialized = true;
    debugPrint('[Controller] 初始化完成');
  }

  /// 开始会话
  Future<bool> startSession() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_stateMachine.state != VoiceSessionState.idle) {
      debugPrint('[Controller] 会话已在进行中');
      return false;
    }

    final success = _stateMachine.transition(
      VoiceSessionState.listening,
      reason: '用户启动会话',
    );

    return success;
  }

  /// 停止会话
  Future<void> stopSession() async {
    _stateMachine.transition(
      VoiceSessionState.idle,
      reason: '用户停止会话',
    );
  }

  /// 强制重置
  void forceReset() {
    debugPrint('[Controller] 强制重置');
    _cancelAllTimers();
    _stopAllServices();
    _stateMachine.reset();
    _partialText = '';
    _interruptedText = null;
  }

  // ═══════════════════════════════════════════════════════════════
  // 音频流管理
  // ═══════════════════════════════════════════════════════════════

  /// 确保录音已启动
  Future<void> _ensureRecordingStarted() async {
    if (_audioStreamController != null) return;

    debugPrint('[Controller] 启动录音流');

    _audioStreamController = StreamController<Uint8List>.broadcast();

    const recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    );

    final audioStream = await _audioRecorder.startStream(recordConfig);

    _audioSubscription = audioStream.listen((data) {
      final audioData = Uint8List.fromList(data);

      // 传递给 ASR（仅在 listening 状态）
      if (_stateMachine.shouldRunASR &&
          _audioStreamController != null &&
          !_audioStreamController!.isClosed) {
        _audioStreamController!.add(audioData);
      }

      // 始终传递给 VAD（用于打断检测）
      if (_stateMachine.shouldRunVAD) {
        _vadService.processAudioFrame(audioData);
      }
    });
  }

  /// 停止录音
  Future<void> _stopRecording() async {
    debugPrint('[Controller] 停止录音流');

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _audioStreamController?.close();
    _audioStreamController = null;

    await _audioRecorder.stop();
  }

  // ═══════════════════════════════════════════════════════════════
  // ASR 管理
  // ═══════════════════════════════════════════════════════════════

  /// 启动 ASR
  void _startASR() {
    if (_audioStreamController == null) return;

    debugPrint('[Controller] 启动 ASR');

    _asrSubscription?.cancel();
    _asrSubscription = _asrService
        .transcribeStream(_audioStreamController!.stream)
        .listen(
          _onASRResult,
          onError: (e) {
            debugPrint('[Controller] ASR 错误: $e');
          },
          onDone: () {
            debugPrint('[Controller] ASR 流结束');
          },
        );
  }

  /// 停止 ASR
  void _stopASR() {
    debugPrint('[Controller] 停止 ASR');
    _asrSubscription?.cancel();
    _asrSubscription = null;
  }

  /// 处理 ASR 结果
  void _onASRResult(ASRPartialResult result) {
    // 只在 listening 状态处理
    if (_stateMachine.state != VoiceSessionState.listening) {
      debugPrint('[Controller] 非 listening 状态，忽略 ASR 结果');
      return;
    }

    if (result.isFinal && result.text.isNotEmpty) {
      debugPrint('[Controller] ASR 最终结果: ${result.text}');
      _partialText = '';

      // 取消假打断计时器（有有效语音）
      _cancelFalseInterruptionTimer();

      // 处理最终结果
      _processFinalResult(result.text);
    } else {
      // 部分结果
      _partialText = result.text;
    }
  }

  /// 处理最终识别结果
  Future<void> _processFinalResult(String text) async {
    // 转换到 thinking 状态
    _stateMachine.transition(
      VoiceSessionState.thinking,
      reason: 'ASR 最终结果',
    );

    // 调用命令处理器（执行层）
    String? response;
    try {
      if (commandProcessor != null) {
        response = await commandProcessor!(text);
      }
    } catch (e) {
      debugPrint('[Controller] 命令处理失败: $e');
      response = '抱歉，处理时出错了';
    }

    // 处理响应
    if (response != null && response.isNotEmpty) {
      await _speak(response);
    } else {
      // 无响应，回到 listening
      _stateMachine.transition(
        VoiceSessionState.listening,
        reason: '无响应',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TTS 播放
  // ═══════════════════════════════════════════════════════════════

  /// 播放 TTS（带打断支持）
  Future<void> _speak(String text) async {
    _interruptedText = text;

    // 转换到 speaking 状态
    _stateMachine.transition(
      VoiceSessionState.speaking,
      reason: '开始 TTS',
    );

    try {
      debugPrint('[Controller] 开始 TTS: $text');
      await _ttsService.speak(text);
      debugPrint('[Controller] TTS 完成');

      // TTS 正常完成，回到 listening（无延迟！）
      if (_stateMachine.state == VoiceSessionState.speaking) {
        _interruptedText = null;
        _stateMachine.transition(
          VoiceSessionState.listening,
          reason: 'TTS 完成',
        );
      }
    } catch (e) {
      debugPrint('[Controller] TTS 失败: $e');
      _stateMachine.transition(
        VoiceSessionState.listening,
        reason: 'TTS 失败',
      );
    }
  }

  /// 主动播放（用于主动对话）
  Future<void> speakProactively(String text) async {
    if (_stateMachine.state != VoiceSessionState.listening) {
      return;
    }

    await _speak(text);
  }

  // ═══════════════════════════════════════════════════════════════
  // VAD 和打断检测
  // ═══════════════════════════════════════════════════════════════

  /// 处理 VAD 事件
  void _onVADEvent(VADEvent event) {
    switch (event.type) {
      case VADEventType.speechStart:
        _onUserSpeechStart();
        break;

      case VADEventType.speechEnd:
        _onUserSpeechEnd();
        break;

      case VADEventType.silenceTimeout:
        _onSilenceTimeout();
        break;

      default:
        break;
    }
  }

  /// 用户开始说话
  void _onUserSpeechStart() {
    userSpeechStartTime = DateTime.now();
    _resetSilenceTimer();

    // 只在 speaking 状态检测打断
    if (_stateMachine.state != VoiceSessionState.speaking) {
      return;
    }

    if (!config.allowInterruptions) {
      debugPrint('[Controller] 打断已禁用');
      return;
    }

    // 启动打断确认计时器
    _interruptionConfirmTimer?.cancel();
    _interruptionConfirmTimer = Timer(
      config.interruptionConfirmDelay,
      _confirmInterruption,
    );

    debugPrint('[Controller] 检测到用户说话，等待确认打断...');
  }

  /// 用户停止说话
  void _onUserSpeechEnd() {
    // 取消打断确认（说话时间不够）
    if (_interruptionConfirmTimer != null) {
      debugPrint('[Controller] 用户说话结束，取消打断确认');
      _interruptionConfirmTimer?.cancel();
      _interruptionConfirmTimer = null;
    }
    userSpeechStartTime = null;
  }

  /// 确认打断
  void _confirmInterruption() {
    _interruptionConfirmTimer = null;

    debugPrint('[Controller] ✓ 用户打断确认');

    // 停止 TTS
    _ttsService.stop();

    // 转换到 listening 状态
    _stateMachine.transition(
      VoiceSessionState.listening,
      reason: '用户打断',
    );

    // 重启 ASR
    _startASR();

    // 启动假打断检测
    _startFalseInterruptionTimer();
  }

  /// 启动假打断检测计时器
  void _startFalseInterruptionTimer() {
    _falseInterruptionTimer?.cancel();
    _falseInterruptionTimer = Timer(
      config.falseInterruptionTimeout,
      _onFalseInterruption,
    );
    debugPrint('[Controller] 启动假打断检测 (${config.falseInterruptionTimeout.inSeconds}s)');
  }

  /// 取消假打断计时器
  void _cancelFalseInterruptionTimer() {
    if (_falseInterruptionTimer != null) {
      debugPrint('[Controller] 取消假打断检测（有有效语音）');
      _falseInterruptionTimer?.cancel();
      _falseInterruptionTimer = null;
      _interruptedText = null;
    }
  }

  /// 处理假打断（超时无有效 ASR 结果）
  void _onFalseInterruption() {
    _falseInterruptionTimer = null;

    if (!config.resumeFalseInterruption) {
      debugPrint('[Controller] 假打断恢复已禁用');
      _interruptedText = null;
      return;
    }

    if (_interruptedText == null) {
      return;
    }

    if (_stateMachine.state != VoiceSessionState.listening) {
      return;
    }

    debugPrint('[Controller] 假打断，恢复 TTS 播放');

    // 恢复播放
    _speak(_interruptedText!);
  }

  // ═══════════════════════════════════════════════════════════════
  // 静默超时（主动对话）
  // ═══════════════════════════════════════════════════════════════

  /// 启动静默超时计时器
  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(config.silenceTimeout, _onSilenceTimeout);
  }

  /// 重置静默超时计时器
  void _resetSilenceTimer() {
    if (_stateMachine.state == VoiceSessionState.listening) {
      _startSilenceTimer();
    }
  }

  /// 取消静默超时计时器
  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// 静默超时处理
  void _onSilenceTimeout() {
    _silenceTimer = null;

    // 只在 listening 状态且无部分结果时触发
    if (_stateMachine.state != VoiceSessionState.listening) {
      return;
    }

    if (_partialText.trim().isNotEmpty) {
      debugPrint('[Controller] 有部分识别结果，跳过主动对话');
      return;
    }

    debugPrint('[Controller] 静默超时，触发主动对话');

    // 触发主动对话（外部可以监听状态变化来处理）
    speakProactively('有什么可以帮你的吗？');
  }

  // ═══════════════════════════════════════════════════════════════
  // 清理
  // ═══════════════════════════════════════════════════════════════

  /// 取消所有计时器
  void _cancelAllTimers() {
    _interruptionConfirmTimer?.cancel();
    _interruptionConfirmTimer = null;
    _falseInterruptionTimer?.cancel();
    _falseInterruptionTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// 停止所有服务
  void _stopAllServices() {
    _cancelAllTimers();
    _stopASR();
    _stopRecording();
    _ttsService.stop();
    _vadService.reset();
    _partialText = '';
  }

  /// 释放资源
  ///
  /// 注意：不释放 TTS 单例，因为它是共享资源
  void dispose() {
    _stopAllServices();
    _stateMachine.dispose();
    _vadService.dispose();
    // 不释放 TTSService 单例 - 它是全局共享资源
  }
}
