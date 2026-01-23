import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'voice_session_state.dart';
import 'voice_session_state_machine.dart';
import 'voice_session_config.dart';
import 'realtime_vad_config.dart';
import '../voice_recognition_engine.dart';
import '../tts_service.dart';

/// 命令处理回调类型（简单版，仅返回响应文本）
typedef CommandProcessorCallback = Future<String?> Function(String command);

/// 命令处理结果
///
/// 包含执行层返回的丰富信息，供UI层使用
class CommandProcessorResult {
  /// 是否成功
  final bool success;

  /// 响应文本（用于TTS播放）
  final String? responseText;

  /// 是否需要确认
  final bool needsConfirmation;

  /// 确认消息
  final String? confirmationMessage;

  /// 是否允许语音确认
  final bool allowVoiceConfirm;

  /// 是否需要屏幕确认按钮
  final bool requireScreenConfirm;

  /// 是否需要补充参数
  final bool needsMoreParams;

  /// 缺失的参数列表
  final List<String>? missingParams;

  /// 追问提示
  final String? followUpPrompt;

  /// 是否被阻止（高风险操作）
  final bool isBlocked;

  /// 重定向路由（被阻止时）
  final String? redirectRoute;

  /// 附加数据
  final Map<String, dynamic>? data;

  /// 错误信息
  final String? error;

  const CommandProcessorResult({
    required this.success,
    this.responseText,
    this.needsConfirmation = false,
    this.confirmationMessage,
    this.allowVoiceConfirm = true,
    this.requireScreenConfirm = false,
    this.needsMoreParams = false,
    this.missingParams,
    this.followUpPrompt,
    this.isBlocked = false,
    this.redirectRoute,
    this.data,
    this.error,
  });

  /// 简单成功结果
  factory CommandProcessorResult.success({String? responseText}) {
    return CommandProcessorResult(
      success: true,
      responseText: responseText,
    );
  }

  /// 简单失败结果
  factory CommandProcessorResult.failure(String error) {
    return CommandProcessorResult(
      success: false,
      error: error,
      responseText: error,
    );
  }

  /// 获取用于TTS的文本
  String? get textForTTS {
    if (needsConfirmation) return confirmationMessage;
    if (needsMoreParams) return followUpPrompt;
    if (isBlocked) return confirmationMessage;
    return responseText;
  }

  /// 是否需要等待用户响应
  bool get needsUserResponse => needsConfirmation || needsMoreParams;
}

/// 增强的命令处理回调类型（返回结构化结果）
typedef EnhancedCommandProcessorCallback = Future<CommandProcessorResult> Function(String command);

/// UI交互回调
///
/// 用于通知UI层显示确认按钮等交互元素
typedef UIInteractionCallback = void Function(CommandProcessorResult result);

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
  /// 简单版，仅返回响应文本
  CommandProcessorCallback? commandProcessor;

  /// 增强的命令处理器（返回结构化结果）
  /// 优先使用此回调，如果设置了的话
  EnhancedCommandProcessorCallback? enhancedCommandProcessor;

  /// UI交互回调
  /// 当需要显示确认按钮等UI元素时调用
  UIInteractionCallback? onUIInteractionNeeded;

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

  /// 状态版本号（用于处理竞态条件）
  int _stateVersion = 0;

  /// 是否正在处理结果（防止并发处理）
  bool _isProcessingResult = false;

  /// 是否正在录音（防止重复启动和资源泄漏）
  bool _isRecording = false;

  /// 录音启动锁（防止并发启动导致竞态）
  /// 当正在启动录音时，其他调用会等待这个 Completer
  Completer<void>? _recordingStartLock;

  /// 状态机状态流订阅（用于清理时取消）
  StreamSubscription<VoiceSessionStateChange>? _stateMachineSubscription;

  /// VAD 事件流订阅（用于清理时取消）
  StreamSubscription<VADEvent>? _vadSubscription;

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
    // 监听状态变化（保存订阅以便清理时取消）
    _stateMachineSubscription = _stateMachine.stateStream.listen(_onStateChanged);

    // 监听 VAD 事件（保存订阅以便清理时取消）
    _vadSubscription = _vadService.eventStream.listen(_onVADEvent);
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
    // 注意：不重置 _stateVersion，保持递增确保跨会话版本号唯一
    // 这样可以防止旧的异步操作在新会话中误认为状态有效
    _isProcessingResult = false;
    _isRecording = false;

    // 释放录音启动锁（如果有等待的协程）
    // 使用 isCompleted 检查防止重复 complete（异常安全）
    if (_recordingStartLock != null && !_recordingStartLock!.isCompleted) {
      _recordingStartLock!.complete();
    }
    _recordingStartLock = null;
  }

  // ═══════════════════════════════════════════════════════════════
  // 音频流管理
  // ═══════════════════════════════════════════════════════════════

  /// 确保录音已启动
  ///
  /// 使用锁机制防止并发启动导致的竞态问题：
  /// - 如果已在录音，直接返回
  /// - 如果正在启动中，等待启动完成
  /// - 否则获取锁并启动
  Future<void> _ensureRecordingStarted() async {
    // 循环等待直到：要么录音已启动，要么我们成功获取锁
    while (true) {
      // 快速检查：已在录音则直接返回
      if (_isRecording) {
        debugPrint('[Controller] 录音已在进行中，跳过重复启动');
        return;
      }

      // 检查是否有其他协程正在启动录音
      if (_recordingStartLock != null) {
        debugPrint('[Controller] 等待其他协程完成录音启动...');
        await _recordingStartLock!.future;
        // 等待完成后继续循环检查（可能需要再次等待新的锁）
        continue;
      }

      // 尝试获取锁（此时 _recordingStartLock == null）
      _recordingStartLock = Completer<void>();

      // 再次检查状态（双重检查锁定模式）
      if (_isRecording || _audioStreamController != null) {
        debugPrint('[Controller] 双重检查：录音已存在，跳过');
        // 统一使用 isCompleted 检查模式，保持代码一致性
        if (!_recordingStartLock!.isCompleted) {
          _recordingStartLock!.complete();
        }
        _recordingStartLock = null;
        return;
      }

      // 成功获取锁，跳出循环开始录音
      break;
    }

    debugPrint('[Controller] 启动录音流');

    try {
      // 先设置标志，防止其他协程进入
      _isRecording = true;

      _audioStreamController = StreamController<Uint8List>.broadcast();

      // 禁用硬件级 3A，只使用 WebRTC APM 软件处理
      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: false,
        autoGain: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,  // 使用语音识别源，避免系统自动应用 NS
          audioManagerMode: AudioManagerMode.modeInCommunication,
        ),
      );

      final audioStream = await _audioRecorder.startStream(recordConfig);

      _audioSubscription = audioStream.listen(
        (data) {
          final audioData = Uint8List.fromList(data);

          // 传递给 ASR（仅在 listening 状态）
          // 使用 try-catch 防止检查和写入之间 StreamController 被关闭的竞态条件
          if (_stateMachine.shouldRunASR &&
              _audioStreamController != null &&
              !_audioStreamController!.isClosed) {
            try {
              _audioStreamController!.add(audioData);
            } catch (e) {
              // StreamController 可能在检查后被关闭，静默忽略
              debugPrint('[Controller] 音频流写入失败（可能已关闭）: $e');
            }
          }

          // 始终传递给 VAD（用于打断检测）
          if (_stateMachine.shouldRunVAD) {
            _vadService.processAudioFrame(audioData);
          }
        },
        onError: (error, stackTrace) {
          debugPrint('[Controller] 音频流错误: $error');
          debugPrint('[Controller] 堆栈: $stackTrace');
          // 发生错误时清理资源
          _cleanupRecordingResources();
        },
        onDone: () {
          debugPrint('[Controller] 音频流结束');
        },
      );

      debugPrint('[Controller] 录音流启动成功');
    } catch (e, stackTrace) {
      debugPrint('[Controller] 启动录音失败: $e');
      debugPrint('[Controller] 堆栈: $stackTrace');
      // 启动失败时清理资源
      _cleanupRecordingResources();
      rethrow;
    } finally {
      // 释放锁，唤醒等待的协程
      // 使用 isCompleted 检查防止重复 complete（可能被 forceReset 提前完成）
      if (_recordingStartLock != null && !_recordingStartLock!.isCompleted) {
        _recordingStartLock!.complete();
      }
      _recordingStartLock = null;
    }
  }

  /// 清理录音相关资源（内部方法）
  Future<void> _cleanupRecordingResources() async {
    debugPrint('[Controller] 清理录音资源');

    _isRecording = false;

    // 取消音频流订阅
    try {
      await _audioSubscription?.cancel();
    } catch (e) {
      debugPrint('[Controller] 取消音频订阅失败: $e');
    }
    _audioSubscription = null;

    // 关闭音频流控制器
    try {
      await _audioStreamController?.close();
    } catch (e) {
      debugPrint('[Controller] 关闭音频流控制器失败: $e');
    }
    _audioStreamController = null;

    // 停止录音器
    try {
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('[Controller] 停止录音器失败: $e');
    }
  }

  /// 停止录音
  Future<void> _stopRecording() async {
    if (!_isRecording && _audioStreamController == null) {
      debugPrint('[Controller] 录音未启动，无需停止');
      return;
    }

    debugPrint('[Controller] 停止录音流');
    await _cleanupRecordingResources();
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
    // 防止并发处理（竞态保护）
    if (_isProcessingResult) {
      debugPrint('[Controller] 已有处理中，忽略重复的 ASR 结果: $text');
      return;
    }
    _isProcessingResult = true;

    // 记录当前状态版本
    final currentVersion = ++_stateVersion;

    try {
      // 转换到 thinking 状态
      _stateMachine.transition(
        VoiceSessionState.thinking,
        reason: 'ASR 最终结果',
      );

      // 调用命令处理器（执行层）
      CommandProcessorResult? result;
      String? response;

      try {
        // 优先使用增强的命令处理器
        if (enhancedCommandProcessor != null) {
          result = await enhancedCommandProcessor!(text);
          response = result.textForTTS;

          // 通知UI层需要交互（如显示确认按钮）
          if (result.needsUserResponse && onUIInteractionNeeded != null) {
            onUIInteractionNeeded!(result);
          }
        } else if (commandProcessor != null) {
          // 降级使用简单的命令处理器
          response = await commandProcessor!(text);
        }
      } catch (e) {
        debugPrint('[Controller] 命令处理失败: $e');
        response = '抱歉，处理时出错了';
      }

      // 检查状态版本是否已过期（异步处理期间状态可能已变化）
      if (_stateVersion != currentVersion) {
        debugPrint('[Controller] 状态版本已过期 (当前: $_stateVersion, 预期: $currentVersion)，跳过状态更新');
        return;
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
    } finally {
      _isProcessingResult = false;
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

    // 停止 TTS（fire-and-forget，不阻塞状态转换）
    _ttsService.stop().catchError((e) {
      debugPrint('[Controller] 停止TTS时出错: $e');
    });

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

    // 检查是否启用假打断恢复
    if (!config.resumeFalseInterruption) {
      debugPrint('[Controller] 假打断恢复已禁用');
      _interruptedText = null;
      return;
    }

    // 检查是否有有效的被打断文本（非空且非空字符串）
    final textToResume = _interruptedText;
    if (textToResume == null || textToResume.trim().isEmpty) {
      debugPrint('[Controller] 无有效的被打断文本，跳过恢复');
      _interruptedText = null;
      return;
    }

    // 检查当前状态是否适合恢复播放
    if (_stateMachine.state != VoiceSessionState.listening) {
      debugPrint('[Controller] 非listening状态(${_stateMachine.state})，跳过假打断恢复');
      _interruptedText = null;  // 清空，避免内存悬空
      return;
    }

    debugPrint('[Controller] 假打断，恢复 TTS 播放: $textToResume');

    // 恢复播放（使用局部变量，避免并发修改问题）
    _speak(textToResume);
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
  /// 停止所有服务（同步版本，用于快速停止）
  ///
  /// 注意：异步操作使用 fire-and-forget 模式，不等待完成
  void _stopAllServices() {
    _cancelAllTimers();
    _stopASR();
    // 异步停止录音，不等待
    _stopRecording().catchError((e) {
      debugPrint('[Controller] 停止录音时出错: $e');
    });
    // 异步停止 TTS，不等待（fire-and-forget）
    _ttsService.stop().catchError((e) {
      debugPrint('[Controller] 停止TTS时出错: $e');
    });
    _vadService.reset();
    _partialText = '';
  }

  /// 停止所有服务（异步版本，等待录音完全停止）
  Future<void> _stopAllServicesAsync() async {
    _cancelAllTimers();
    _stopASR();
    await _stopRecording();
    await _ttsService.stop();
    _vadService.reset();
    _partialText = '';
  }

  /// 释放资源
  ///
  /// 注意：
  /// - 不释放 TTS 单例，因为它是共享资源
  /// - 等待录音完全停止后再释放 AudioRecorder，避免资源冲突
  Future<void> dispose() async {
    // 取消流订阅，防止内存泄漏
    await _stateMachineSubscription?.cancel();
    _stateMachineSubscription = null;
    await _vadSubscription?.cancel();
    _vadSubscription = null;

    await _stopAllServicesAsync();
    await _stateMachine.dispose();
    _vadService.dispose();
    _audioRecorder.dispose();
    // 不释放 TTSService 单例 - 它是全局共享资源
  }
}
