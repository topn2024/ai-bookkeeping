import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_recognition_engine.dart';
import 'tts_service.dart';
import 'voice_context_service.dart';
import 'voice/realtime_vad_config.dart';
import 'voice/barge_in_detector.dart';

/// 麦克风权限状态
enum MicrophonePermissionStatus {
  granted,           // 已授权
  denied,            // 被拒绝（可再次请求）
  permanentlyDenied, // 永久拒绝（需要去设置）
  unknown,           // 未知状态
}

/// 悬浮球状态
enum FloatingBallState {
  idle,       // 默认状态，显示麦克风图标
  recording,  // 录音中，显示波浪动画
  processing, // 处理中，显示加载动画
  success,    // 成功，短暂显示勾号
  error,      // 错误，短暂显示错误图标
  hidden,     // 隐藏状态
}

/// 聊天消息类型
enum ChatMessageType {
  user,
  assistant,
  system,
}

/// 聊天消息
class ChatMessage {
  final String id;
  final ChatMessageType type;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.metadata,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      type: type,
      content: content ?? this.content,
      timestamp: timestamp,
      metadata: metadata ?? this.metadata,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    type: ChatMessageType.values.firstWhere((e) => e.name == json['type']),
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    metadata: json['metadata'],
  );
}

/// 命令处理回调类型
/// 返回处理结果消息，如果返回null则使用内置处理
typedef CommandProcessorCallback = Future<String?> Function(String command);

/// 全局语音助手管理器
///
/// 单例模式，管理：
/// - 悬浮球状态
/// - 语音交互流程
/// - 对话历史
/// - 页面上下文
class GlobalVoiceAssistantManager extends ChangeNotifier {
  // 单例模式
  static GlobalVoiceAssistantManager? _instance;
  static GlobalVoiceAssistantManager get instance {
    _instance ??= GlobalVoiceAssistantManager._internal();
    return _instance!;
  }

  GlobalVoiceAssistantManager._internal();

  /// 用于测试的工厂方法
  @visibleForTesting
  factory GlobalVoiceAssistantManager.forTest() {
    return GlobalVoiceAssistantManager._internal();
  }

  // 核心服务（延迟初始化）
  VoiceRecognitionEngine? _recognitionEngine;
  TTSService? _ttsService;
  VoiceContextService? _contextService;

  // 录音器
  AudioRecorder? _audioRecorder;

  // 状态
  FloatingBallState _ballState = FloatingBallState.idle;
  bool _isVisible = true;
  Offset _position = Offset.zero;
  bool _isInitialized = false;

  // 对话历史
  final List<ChatMessage> _conversationHistory = [];
  static const int _maxHistorySize = 100;

  // 录音相关
  DateTime? _recordingStartTime;

  // 音频振幅 (0.0 - 1.0)
  double _amplitude = 0.0;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // VAD 自动检测语音段落
  RealtimeVADService? _vadService;
  StreamSubscription<VADEvent>? _vadSubscription;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  bool _autoEndEnabled = true;  // 是否启用自动语音段落检测

  // 打断检测器（Barge-in Detection）
  BargeInDetector? _bargeInDetector;
  StreamSubscription<BargeInEvent>? _bargeInSubscription;
  bool _isTTSPlayingWithBargeIn = false;  // TTS播放中，启用打断检测

  // 流式ASR相关
  StreamController<Uint8List>? _audioStreamController;  // 音频流广播控制器
  StreamSubscription<ASRPartialResult>? _asrResultSubscription;  // ASR结果订阅
  String _partialText = '';  // 部分识别结果（用于UI显示）
  bool _isProcessingUtterance = false;  // 是否正在处理一个语音段落

  // 连续对话模式
  bool _continuousMode = false;
  bool _shouldAutoRestart = false;

  // 主动对话模式（TTS播放期间禁止ASR重启）
  bool _isProactiveConversation = false;

  // 命令处理中（TTS播放期间忽略ASR结果）
  bool _isProcessingCommand = false;

  // 权限回调（由 UI 层设置）
  void Function(MicrophonePermissionStatus status)? onPermissionRequired;

  // 命令处理回调（由 UI 层设置，用于集成 VoiceServiceCoordinator）
  CommandProcessorCallback? _commandProcessor;

  /// 设置命令处理回调
  void setCommandProcessor(CommandProcessorCallback? processor) {
    _commandProcessor = processor;
    debugPrint('[GlobalVoiceAssistant] 命令处理器已${processor != null ? "设置" : "清除"}');
  }

  // Getters
  FloatingBallState get ballState => _ballState;
  bool get isVisible => _isVisible;
  Offset get position => _position;
  bool get isInitialized => _isInitialized;
  double get amplitude => _amplitude;
  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  VoiceContextService? get contextService => _contextService;
  bool get isAutoEndEnabled => _autoEndEnabled;
  String get partialText => _partialText;  // 部分识别结果（用于实时显示）

  /// 启用/禁用自动结束检测
  void setAutoEndEnabled(bool enabled) {
    _autoEndEnabled = enabled;
    debugPrint('[GlobalVoiceAssistant] 自动结束检测: $enabled');
  }
  bool get isContinuousMode => _continuousMode;

  /// 启用/禁用连续对话模式
  void setContinuousMode(bool enabled) {
    _continuousMode = enabled;
    _shouldAutoRestart = enabled;
    debugPrint('[GlobalVoiceAssistant] 连续对话模式: $enabled');
    notifyListeners();
  }

  /// 停止连续对话
  void stopContinuousMode() {
    _continuousMode = false;
    _shouldAutoRestart = false;
    if (_ballState == FloatingBallState.recording) {
      stopRecording();
    }
    setBallState(FloatingBallState.idle);
    debugPrint('[GlobalVoiceAssistant] 连续对话已停止');
  }

  /// 强制重置所有状态（用于处理卡死情况）
  void forceReset() {
    debugPrint('[GlobalVoiceAssistant] 强制重置所有状态');

    // 停止连续对话模式
    _continuousMode = false;
    _shouldAutoRestart = false;
    _isProactiveConversation = false;
    _isRestartingASR = false;
    _isProcessingCommand = false;
    _isTTSPlayingWithBargeIn = false;

    // 重置打断检测器
    _bargeInDetector?.reset();

    // 停止录音（如果正在录音）
    _audioRecorder?.stop().catchError((e) {
      debugPrint('[GlobalVoiceAssistant] 强制停止录音失败: $e');
      return null;
    });

    // 停止振幅监听
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _amplitude = 0.0;

    // 停止TTS播放
    _ttsService?.stop().catchError((e) {
      debugPrint('[GlobalVoiceAssistant] 强制停止TTS失败: $e');
      return;
    });

    // 重置状态
    _ballState = FloatingBallState.idle;

    debugPrint('[GlobalVoiceAssistant] 强制重置完成');
    notifyListeners();
  }

  /// 检查麦克风权限状态
  Future<MicrophonePermissionStatus> checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) {
        return MicrophonePermissionStatus.granted;
      } else if (status.isPermanentlyDenied) {
        return MicrophonePermissionStatus.permanentlyDenied;
      } else if (status.isDenied) {
        return MicrophonePermissionStatus.denied;
      }
      return MicrophonePermissionStatus.unknown;
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 检查权限失败: $e');
      return MicrophonePermissionStatus.unknown;
    }
  }

  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    try {
      final result = await Permission.microphone.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 请求权限失败: $e');
      return false;
    }
  }

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 初始化上下文服务
      _contextService = VoiceContextService();

      // 延迟初始化语音服务，首次使用时才创建
      _isInitialized = true;

      // 从本地存储加载对话历史
      await loadHistoryFromStorage();

      // 如果没有历史记录，添加欢迎消息
      if (_conversationHistory.isEmpty) {
        _addSystemMessage('语音助手已就绪，点击悬浮球开始对话');
      }

      notifyListeners();
      debugPrint('[GlobalVoiceAssistant] 初始化完成');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 初始化失败: $e');
      rethrow;
    }
  }

  /// 确保语音服务已初始化
  Future<void> _ensureVoiceServicesInitialized() async {
    if (_audioRecorder != null) return;

    _audioRecorder = AudioRecorder();
    _recognitionEngine = VoiceRecognitionEngine();
    _ttsService = TTSService();
    await _ttsService!.initialize();

    // 初始化VAD服务
    _vadService = RealtimeVADService(
      config: RealtimeVADConfig.defaultConfig().copyWith(
        speechEndThresholdMs: 800,  // 静音800ms判定说完
        silenceTimeoutMs: 5000,     // 5秒无声音触发主动对话
      ),
    );

    // 订阅VAD事件
    _vadSubscription = _vadService!.eventStream.listen(_handleVADEvent);

    // 初始化打断检测器
    _bargeInDetector = BargeInDetector(
      config: const BargeInConfig(
        vadPriority: true,  // VAD优先模式
        confirmationDelay: Duration(milliseconds: 300),  // 300ms确认延迟
        cooldownDuration: Duration(milliseconds: 500),   // 500ms冷却期
      ),
    );

    // 订阅打断事件
    _bargeInSubscription = _bargeInDetector!.eventStream.listen(_handleBargeInEvent);

    debugPrint('[GlobalVoiceAssistant] 语音服务延迟初始化完成 (VAD+BargeIn已启用)');
  }

  /// 处理VAD事件
  ///
  /// 在流式处理模式下，VAD仅用于UI提示和状态跟踪
  /// 不会停止录音，因为流式ASR会持续处理
  void _handleVADEvent(VADEvent event) {
    debugPrint('[GlobalVoiceAssistant] VAD事件: ${event.type}');

    switch (event.type) {
      case VADEventType.speechStart:
        debugPrint('[GlobalVoiceAssistant] VAD: 检测到用户开始说话');
        // 可以在UI上显示"正在听..."的状态
        _isProcessingUtterance = true;
        notifyListeners();
        break;

      case VADEventType.speechEnd:
        debugPrint('[GlobalVoiceAssistant] VAD: 检测到用户说话结束，时长=${event.speechDuration?.inMilliseconds}ms');
        // 流式ASR会自动处理，不需要手动停止
        // 只记录状态，等待ASR返回最终结果
        _isProcessingUtterance = false;
        notifyListeners();
        break;

      case VADEventType.silenceTimeout:
        debugPrint('[GlobalVoiceAssistant] VAD: 用户沉默超时 (ballState=$_ballState, isProcessing=$_isProcessingUtterance, partialText=$_partialText, isProcessingCommand=$_isProcessingCommand)');
        // 检查条件：
        // 1. 正在录音状态
        // 2. 没有有意义的ASR结果（partialText为空或很短，可能是噪音）
        // 3. 不在命令处理中（避免TTS播放期间触发主动对话）
        final hasNoMeaningfulInput = _partialText.trim().isEmpty || _partialText.trim().length < 2;
        if (_ballState == FloatingBallState.recording && hasNoMeaningfulInput && !_isProcessingCommand) {
          debugPrint('[GlobalVoiceAssistant] 满足条件，触发主动对话');
          final context = _contextService?.currentContext;
          _initiateProactiveConversation(context);
        } else {
          debugPrint('[GlobalVoiceAssistant] 条件不满足（有输入内容），跳过主动对话');
        }
        break;

      default:
        break;
    }
  }

  /// 处理打断事件
  ///
  /// 当用户在TTS播放期间说话，触发打断
  void _handleBargeInEvent(BargeInEvent event) {
    debugPrint('[GlobalVoiceAssistant] 打断事件: ${event.type}, 来源: ${event.source}');

    switch (event.type) {
      case BargeInEventType.detected:
        _onBargeInDetected();
        break;

      case BargeInEventType.keywordDetected:
        debugPrint('[GlobalVoiceAssistant] 检测到打断关键词: ${event.keyword}');
        _onBargeInDetected();
        break;

      case BargeInEventType.cancelled:
        debugPrint('[GlobalVoiceAssistant] 打断被取消（误检）');
        break;
    }
  }

  /// 处理确认的打断
  Future<void> _onBargeInDetected() async {
    if (!_isTTSPlayingWithBargeIn) {
      debugPrint('[GlobalVoiceAssistant] 打断忽略：TTS未在打断检测模式');
      return;
    }

    debugPrint('[GlobalVoiceAssistant] ========== 用户打断TTS ==========');

    // 1. 立即停止TTS
    await _ttsService?.stop();
    debugPrint('[GlobalVoiceAssistant] TTS已停止');

    // 2. 重置打断检测状态
    _isTTSPlayingWithBargeIn = false;
    _bargeInDetector?.notifyTTSStopped();
    _isProcessingCommand = false;

    // 3. 重启ASR监听用户新输入
    if (_ballState == FloatingBallState.recording &&
        _audioStreamController != null &&
        !_audioStreamController!.isClosed) {
      debugPrint('[GlobalVoiceAssistant] 重启ASR，等待用户新输入');
      _asrResultSubscription?.cancel();
      _asrResultSubscription = null;
      _startStreamingASR();

      // 添加一条系统消息，让用户知道可以继续说话
      _addAssistantMessage('好的，请说~');
    }

    debugPrint('[GlobalVoiceAssistant] ========== 打断处理完成 ==========');
  }

  /// 设置悬浮球状态
  void setBallState(FloatingBallState state) {
    if (_ballState != state) {
      _ballState = state;
      notifyListeners();
    }
  }

  /// 设置悬浮球可见性
  void setVisible(bool visible) {
    if (_isVisible != visible) {
      _isVisible = visible;
      notifyListeners();
    }
  }

  /// 设置悬浮球位置
  void setPosition(Offset newPosition) {
    if (_position != newPosition) {
      _position = newPosition;
      notifyListeners();
    }
  }

  /// 开始录音（流式处理模式）
  ///
  /// 使用全双工流式处理：
  /// 1. 音频流持续传输给ASR
  /// 2. ASR实时返回识别结果
  /// 3. VAD检测语音段落边界
  /// 4. 收到最终结果时处理命令
  /// 5. 录音流持续活跃，继续监听
  Future<void> startRecording() async {
    if (_ballState == FloatingBallState.recording) return;

    try {
      // 先检查权限状态
      final permissionStatus = await checkMicrophonePermission();

      if (permissionStatus == MicrophonePermissionStatus.permanentlyDenied) {
        // 永久拒绝，通知 UI 层显示引导对话框
        onPermissionRequired?.call(permissionStatus);
        _handleError('麦克风权限被禁用，请在设置中开启');
        return;
      }

      if (permissionStatus == MicrophonePermissionStatus.denied) {
        // 首次请求或被拒绝，通知 UI 层显示权限说明
        onPermissionRequired?.call(permissionStatus);
        // 尝试请求权限
        final granted = await requestMicrophonePermission();
        if (!granted) {
          _handleError('未获得麦克风权限');
          return;
        }
      }

      await _ensureVoiceServicesInitialized();

      // 再次确认权限（通过 AudioRecorder 检查）
      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        _handleError('麦克风权限不可用');
        return;
      }

      // 振动反馈
      HapticFeedback.mediumImpact();

      // 重置状态
      _partialText = '';
      _isProcessingUtterance = false;
      _vadService?.reset();

      // 创建音频流广播控制器（用于传递给流式ASR）
      _audioStreamController = StreamController<Uint8List>.broadcast();

      // 录音配置 - 使用PCM格式
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      // 开始流式录音
      debugPrint('[GlobalVoiceAssistant] 开始流式录音+实时ASR');
      final audioStream = await _audioRecorder!.startStream(config);

      // 订阅音频流，同时传输给VAD、ASR和打断检测器
      _audioStreamSubscription = audioStream.listen((data) {
        final audioData = Uint8List.fromList(data);

        // 1. 传输给流式ASR（TTS播放时跳过，但始终传输给ASR）
        // 注意：即使在TTS播放时也要传输音频给ASR，只是ASR结果会被忽略
        if (_audioStreamController != null && !_audioStreamController!.isClosed) {
          _audioStreamController!.add(audioData);
        }

        // 2. 发送到VAD进行语音活动检测（始终运行，用于打断检测）
        if (_vadService != null) {
          _vadService!.processAudioFrame(audioData);

          // 3. TTS播放时，VAD结果传递给打断检测器
          if (_isTTSPlayingWithBargeIn && _bargeInDetector != null) {
            // 使用VAD的语音活动状态来检测打断
            final isSpeaking = _vadService!.state == VADState.speaking ||
                               _vadService!.state == VADState.possibleSpeech;
            _bargeInDetector!.processVADResult(isSpeaking);
          }
        }

        // 4. 计算振幅用于UI显示
        _updateAmplitudeFromPCM(audioData);
      });

      // 启动流式ASR
      _startStreamingASR();

      // 开始沉默超时检测（用户打开助手但不说话时触发主动对话）
      _vadService?.startSilenceTimeoutDetection();

      _recordingStartTime = DateTime.now();
      setBallState(FloatingBallState.recording);

      debugPrint('[GlobalVoiceAssistant] 流式语音处理已启动（沉默超时检测已开启）');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 开始录音失败: $e');
      _handleError('无法开始录音，请检查麦克风权限');
    }
  }

  /// 启动流式ASR识别
  void _startStreamingASR() {
    if (_audioStreamController == null || _recognitionEngine == null) return;

    debugPrint('[GlobalVoiceAssistant] 启动流式ASR');

    // 订阅流式ASR结果
    _asrResultSubscription = _recognitionEngine!
        .transcribeStream(_audioStreamController!.stream)
        .listen(
      (result) {
        // 命令处理中或TTS播放期间忽略ASR结果（避免回声）
        if (_isProcessingCommand || _ttsService?.isSpeaking == true) {
          debugPrint('[GlobalVoiceAssistant] 处理中/TTS播放中，忽略ASR结果: "${result.text}"');
          return;
        }

        debugPrint('[GlobalVoiceAssistant] ASR结果: "${result.text}" (isFinal: ${result.isFinal})');

        if (result.isFinal && result.text.isNotEmpty) {
          // 收到最终结果，处理命令
          _handleFinalASRResult(result.text);
        } else if (!result.isFinal) {
          // 部分结果，更新UI显示
          _partialText = result.text;
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('[GlobalVoiceAssistant] 流式ASR错误: $error');
        // ASR错误后自动重启（如果仍在录音状态）
        _restartASRIfNeeded();
      },
      onDone: () {
        debugPrint('[GlobalVoiceAssistant] 流式ASR结束');
        // ASR结束后自动重启（如果仍在录音状态）
        _restartASRIfNeeded();
      },
    );
  }

  /// 是否正在重启ASR（防止重复重启）
  bool _isRestartingASR = false;

  /// 如果仍在录音状态，重启ASR
  void _restartASRIfNeeded() {
    // 防止重复重启
    if (_isRestartingASR) {
      debugPrint('[GlobalVoiceAssistant] ASR正在重启中，跳过');
      return;
    }

    // 主动对话模式下不自动重启（TTS正在播放）
    if (_isProactiveConversation) {
      debugPrint('[GlobalVoiceAssistant] 主动对话模式，跳过ASR自动重启');
      return;
    }

    _isRestartingASR = true;

    // 延迟一小段时间再重启，避免频繁重启
    Future.delayed(const Duration(milliseconds: 500), () {
      _isRestartingASR = false;

      // 再次检查主动对话模式
      if (_isProactiveConversation) {
        debugPrint('[GlobalVoiceAssistant] 主动对话模式，跳过ASR自动重启');
        return;
      }

      if (_ballState == FloatingBallState.recording &&
          _audioStreamController != null &&
          !_audioStreamController!.isClosed) {
        debugPrint('[GlobalVoiceAssistant] 自动重启ASR');
        // 先取消之前的订阅
        _asrResultSubscription?.cancel();
        _asrResultSubscription = null;
        _startStreamingASR();
      }
    });
  }

  /// 处理最终ASR结果
  Future<void> _handleFinalASRResult(String recognizedText) async {
    debugPrint('[GlobalVoiceAssistant] 处理最终识别结果: $recognizedText');

    // 设置处理中标志，忽略后续ASR结果（避免TTS回声）
    _isProcessingCommand = true;

    // 清空部分结果
    _partialText = '';

    // 添加用户消息到对话历史
    _addUserMessage(recognizedText);

    // 如果有外部命令处理器，使用它处理
    if (_commandProcessor != null) {
      debugPrint('[GlobalVoiceAssistant] 使用外部命令处理器');
      try {
        final response = await _commandProcessor!(recognizedText);
        if (response != null && response.isNotEmpty) {
          _addAssistantMessage(response);

          // 启用打断检测模式（录音继续，VAD运行，用于检测用户打断）
          _enableBargeInDetection();

          // 由GlobalVoiceAssistantManager自己播放TTS，确保_isProcessingCommand
          // 在TTS播放完成前保持为true，防止回声被当作用户输入
          if (_ttsService != null) {
            debugPrint('[GlobalVoiceAssistant] 开始播放TTS响应: $response');
            try {
              await _ttsService!.speak(response);
              debugPrint('[GlobalVoiceAssistant] TTS播放完成');
            } catch (ttsError) {
              debugPrint('[GlobalVoiceAssistant] TTS播放失败: $ttsError');
            }
          }

          // TTS播放完成，禁用打断检测
          _disableBargeInDetection();

          // 延迟一段时间再清除处理中标志，等待可能的回声最终结果到达
          // ASR的SentenceEnd可能比TTS播放完成晚到达约1秒
          debugPrint('[GlobalVoiceAssistant] TTS播放完成，等待回声消散...');
          await Future.delayed(const Duration(milliseconds: 1500));
          debugPrint('[GlobalVoiceAssistant] 回声等待完成，准备接收新输入');
        }
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 命令处理器错误: $e');
      } finally {
        // 命令处理完成，清除处理中标志
        _isProcessingCommand = false;
      }
    } else {
      // 没有外部处理器时，使用本地即时反馈
      final immediateResponse = _getImmediateResponse(recognizedText);
      _addAssistantMessage(immediateResponse);

      // 启用打断检测模式
      _enableBargeInDetection();

      // 播放即时反馈
      if (_ttsService != null) {
        try {
          await _ttsService!.speak(immediateResponse);
        } catch (ttsError) {
          debugPrint('[GlobalVoiceAssistant] TTS播报失败: $ttsError');
        }
      }

      // TTS播放完成，禁用打断检测
      _disableBargeInDetection();

      // 延迟一段时间再清除处理中标志，等待可能的回声最终结果到达
      debugPrint('[GlobalVoiceAssistant] TTS播放完成，等待回声消散...');
      await Future.delayed(const Duration(milliseconds: 1500));
      debugPrint('[GlobalVoiceAssistant] 回声等待完成，准备接收新输入');
      _isProcessingCommand = false;
    }

    notifyListeners();
  }

  /// 启用打断检测模式
  ///
  /// TTS开始播放时调用，保持录音和VAD运行，用于检测用户打断
  void _enableBargeInDetection() {
    debugPrint('[GlobalVoiceAssistant] 启用打断检测模式');
    _isTTSPlayingWithBargeIn = true;
    _bargeInDetector?.start();
    _bargeInDetector?.notifyTTSStarted();
  }

  /// 禁用打断检测模式
  ///
  /// TTS播放完成或被打断时调用
  void _disableBargeInDetection() {
    debugPrint('[GlobalVoiceAssistant] 禁用打断检测模式');
    _isTTSPlayingWithBargeIn = false;
    _bargeInDetector?.notifyTTSStopped();
    _bargeInDetector?.stop();
  }

  /// 从PCM数据计算振幅
  void _updateAmplitudeFromPCM(Uint8List pcmData) {
    if (pcmData.isEmpty) return;

    double sum = 0;
    final numSamples = pcmData.length ~/ 2;

    for (int i = 0; i < pcmData.length - 1; i += 2) {
      // 16-bit little-endian signed
      int sample = pcmData[i] | (pcmData[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      sum += sample.abs();
    }

    // 归一化到0-1范围
    final avgAmplitude = sum / numSamples;
    _amplitude = (avgAmplitude / 32768).clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 停止录音（手动触发）
  ///
  /// 停止流式语音处理，清理资源
  Future<void> stopRecording() async {
    debugPrint('[GlobalVoiceAssistant] stopRecording called (手动), state=$_ballState');
    if (_ballState != FloatingBallState.recording) {
      debugPrint('[GlobalVoiceAssistant] 状态不是recording，忽略');
      return;
    }

    try {
      // 停止连续对话模式
      _continuousMode = false;
      _shouldAutoRestart = false;
      _isRestartingASR = false;  // 重置重启标志
      _isProactiveConversation = false;  // 重置主动对话标志

      // 记录录音时长
      final duration = DateTime.now().difference(_recordingStartTime!);
      debugPrint('[GlobalVoiceAssistant] 录音时长: ${duration.inMilliseconds}ms');

      // 先取消ASR识别（这会设置_isCancelled标志，停止音频发送）
      await _recognitionEngine?.cancelTranscription();
      debugPrint('[GlobalVoiceAssistant] ASR已取消');

      // 停止流式ASR结果订阅
      await _asrResultSubscription?.cancel();
      _asrResultSubscription = null;

      // 关闭音频流控制器
      await _audioStreamController?.close();
      _audioStreamController = null;

      // 停止音频流订阅
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // 停止录音器
      await _audioRecorder?.stop();

      // 停止振幅订阅
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      _amplitude = 0.0;

      // 重置状态
      _partialText = '';

      setBallState(FloatingBallState.idle);
      debugPrint('[GlobalVoiceAssistant] 流式语音处理已停止');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 停止录音失败: $e');
      _handleError('停止录音失败');
    }
  }

  /// 获取即时反馈（根据输入内容快速生成）
  String _getImmediateResponse(String text) {
    // 确认/取消指令 - 立即响应
    if (text.contains('确认') || text.contains('是的') || text.contains('好的')) {
      return '好的，正在处理~';
    }
    if (text.contains('取消') || text.contains('算了') || text.contains('不要')) {
      return '好的，已取消';
    }

    // 导航指令
    final navKeywords = ['打开', '进入', '查看', '看看', '去'];
    if (navKeywords.any((k) => text.contains(k))) {
      return '好的，马上~';
    }

    // 记账指令（包含金额）
    final hasAmount = RegExp(r'\d+|[一二三四五六七八九十百千万两]+').hasMatch(text);
    if (hasAmount) {
      // 多笔交易
      final amountCount = RegExp(r'\d+(?:\.\d+)?').allMatches(text).length;
      if (amountCount > 1) {
        return '好的，我来帮你记录这几笔~';
      }
      return '好的，我来记一下~';
    }

    // 查询指令
    if (text.contains('多少') || text.contains('查') || text.contains('统计')) {
      return '好的，我帮你看看~';
    }

    // 默认
    return '好的，收到~';
  }

  /// 处理意图
  Future<_IntentResponse> _processIntent(String text, PageContext? context) async {
    // 获取上下文提示，用于增强理解
    final contextHint = _contextService?.getContextHint() ?? '';
    debugPrint('[GlobalVoiceAssistant] 上下文提示: $contextHint');

    // 如果设置了命令处理器，优先使用它（集成 VoiceServiceCoordinator）
    if (_commandProcessor != null) {
      debugPrint('[GlobalVoiceAssistant] 使用外部命令处理器处理: $text');
      try {
        final result = await _commandProcessor!(text);
        if (result != null && result.isNotEmpty) {
          return _IntentResponse(
            message: result,
            shouldSpeak: true,
          );
        }
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 外部命令处理器出错: $e');
        // 出错时继续使用内置处理
      }
    }

    // 根据页面上下文增强处理
    if (context != null) {
      final contextResponse = _handleContextAwareQuery(text, context);
      if (contextResponse != null) {
        return contextResponse;
      }
    }

    // 处理记账意图
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:块|元)?').firstMatch(text);

    if (amountMatch != null) {
      final amount = double.tryParse(amountMatch.group(1)!) ?? 0;
      String category = _inferCategory(text);

      return _IntentResponse(
        message: '已记录 ¥${amount.toStringAsFixed(2)} - $category',
        metadata: {'amount': amount, 'category': category, 'type': 'expense'},
        shouldSpeak: true,
      );
    }

    // 处理查询意图
    if (text.contains('花了多少') || text.contains('支出') || text.contains('今天')) {
      return _IntentResponse(
        message: '今日支出统计功能开发中...',
        shouldSpeak: true,
      );
    }

    // 处理导航意图
    final navigationResponse = _handleNavigationIntent(text);
    if (navigationResponse != null) {
      return navigationResponse;
    }

    return _IntentResponse(
      message: '抱歉，我没有理解您的意思。试试说"午餐35块"或"还剩多少预算"',
      shouldSpeak: true,
    );
  }

  /// 推断分类
  String _inferCategory(String text) {
    if (text.contains('餐') || text.contains('饭') || text.contains('吃') ||
        text.contains('外卖') || text.contains('美团') || text.contains('饿了么')) {
      return '餐饮';
    } else if (text.contains('车') || text.contains('打车') || text.contains('地铁') ||
        text.contains('公交') || text.contains('滴滴') || text.contains('油费')) {
      return '交通';
    } else if (text.contains('买') || text.contains('购') || text.contains('淘宝') ||
        text.contains('京东') || text.contains('拼多多')) {
      return '购物';
    } else if (text.contains('电影') || text.contains('游戏') || text.contains('娱乐')) {
      return '娱乐';
    } else if (text.contains('医') || text.contains('药') || text.contains('病')) {
      return '医疗';
    } else if (text.contains('水') || text.contains('电') || text.contains('燃气') ||
        text.contains('话费') || text.contains('网费')) {
      return '生活缴费';
    }
    return '其他';
  }

  /// 处理上下文感知查询
  _IntentResponse? _handleContextAwareQuery(String text, PageContext context) {
    switch (context.type) {
      case PageContextType.budget:
        // 在预算页面询问预算相关
        if (text.contains('还剩') || text.contains('余额') || text.contains('多少')) {
          final remaining = context.data?['remaining'];
          final category = context.data?['category'] ?? '总预算';
          if (remaining != null) {
            return _IntentResponse(
              message: '$category还剩 ¥$remaining',
              shouldSpeak: true,
            );
          }
          return _IntentResponse(
            message: '让我查一下$category的余额...',
            shouldSpeak: true,
          );
        }
        break;

      case PageContextType.transactionDetail:
        // 在交易详情页修改交易
        if (text.contains('改') || text.contains('修改')) {
          final txId = context.data?['transactionId'];
          final amountMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
          if (amountMatch != null && txId != null) {
            final newAmount = double.tryParse(amountMatch.group(1)!) ?? 0;
            return _IntentResponse(
              message: '已将金额修改为 ¥${newAmount.toStringAsFixed(2)}',
              metadata: {'transactionId': txId, 'newAmount': newAmount, 'action': 'modify'},
              shouldSpeak: true,
            );
          }
        }
        // 删除交易
        if (text.contains('删') || text.contains('删除')) {
          final txId = context.data?['transactionId'];
          if (txId != null) {
            return _IntentResponse(
              message: '确定要删除这笔交易吗？',
              metadata: {'transactionId': txId, 'action': 'delete', 'needConfirm': true},
              shouldSpeak: true,
            );
          }
        }
        break;

      case PageContextType.report:
        // 在报表页查询统计
        if (text.contains('多少') || text.contains('统计') || text.contains('总共')) {
          final dateRange = context.data?['dateRange'] ?? '本月';
          return _IntentResponse(
            message: '$dateRange统计数据加载中...',
            shouldSpeak: true,
          );
        }
        break;

      case PageContextType.savings:
        // 在储蓄页查询进度
        if (text.contains('进度') || text.contains('多少') || text.contains('还差')) {
          final goalName = context.data?['goalName'] ?? '储蓄目标';
          final progress = context.data?['progress'];
          if (progress != null) {
            return _IntentResponse(
              message: '$goalName已完成 $progress%',
              shouldSpeak: true,
            );
          }
        }
        break;

      default:
        break;
    }
    return null;
  }

  /// 主动发起对话（用户没有说话时）
  Future<void> _initiateProactiveConversation(PageContext? context) async {
    debugPrint('[GlobalVoiceAssistant] _initiateProactiveConversation 开始');

    // 设置主动对话模式和处理中标志
    _isProactiveConversation = true;
    _isProcessingCommand = true;

    // 根据上下文选择合适的主动对话内容
    String proactiveMessage;

    if (context != null) {
      switch (context.type) {
        case PageContextType.budget:
          proactiveMessage = '要查看预算情况吗？或者说"记一笔"来快速记账~';
          break;
        case PageContextType.transactionDetail:
          proactiveMessage = '需要修改或删除这笔交易吗？';
          break;
        case PageContextType.report:
          proactiveMessage = '要查看消费统计吗？可以说"本月花了多少"';
          break;
        case PageContextType.savings:
          proactiveMessage = '要查看储蓄进度吗？';
          break;
        default:
          proactiveMessage = '有什么可以帮你的吗？可以说"记一笔午餐35块"来快速记账~';
      }
    } else {
      // 随机选择一个主动对话话题
      final topics = [
        '有什么可以帮你的吗？',
        '要记一笔账吗？直接说金额和类别就行~',
        '需要查看今天的消费吗？',
        '说"记一笔"加上金额，我帮你快速记账~',
      ];
      proactiveMessage = topics[DateTime.now().second % topics.length];
    }

    // 添加助手消息
    _addAssistantMessage(proactiveMessage);

    // 启用打断检测模式（录音继续运行，VAD检测用户打断）
    _enableBargeInDetection();

    // 播放TTS（打断检测模式下，用户说话会触发打断）
    if (_ttsService != null) {
      try {
        debugPrint('[GlobalVoiceAssistant] 主动对话TTS开始播放（支持打断）: $proactiveMessage');
        await _ttsService!.speak(proactiveMessage);
        debugPrint('[GlobalVoiceAssistant] 主动对话TTS播放完成');
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 主动对话TTS失败: $e');
      }
    }

    // 禁用打断检测模式
    _disableBargeInDetection();

    // 清除主动对话模式和处理中标志
    _isProactiveConversation = false;
    _isProcessingCommand = false;

    // TTS播放完成后，重启ASR继续监听
    if (_ballState == FloatingBallState.recording &&
        _audioStreamController != null &&
        !_audioStreamController!.isClosed) {
      debugPrint('[GlobalVoiceAssistant] TTS完成，重启ASR');
      _startStreamingASR();
      // 重启沉默超时检测
      _vadService?.startSilenceTimeoutDetection();
    } else {
      // 设置状态为空闲，等待用户响应
      setBallState(FloatingBallState.idle);

      // 连续对话模式下，等待一段时间后再次监听
      if (_continuousMode && _shouldAutoRestart) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_continuousMode && _shouldAutoRestart && _ballState == FloatingBallState.idle) {
            debugPrint('[GlobalVoiceAssistant] 主动对话后自动开始录音');
            startRecording();
          }
        });
      }
    }

    notifyListeners();
  }

  /// 处理导航意图
  _IntentResponse? _handleNavigationIntent(String text) {
    final navigationKeywords = {
      '首页': '/',
      '主页': '/',
      '预算': '/budget',
      '报表': '/reports',
      '统计': '/reports',
      '设置': '/settings',
      '储蓄': '/savings',
      '钱龄': '/money-age',
    };

    for (final entry in navigationKeywords.entries) {
      if (text.contains(entry.key)) {
        if (text.contains('打开') || text.contains('去') || text.contains('跳转')) {
          return _IntentResponse(
            message: '正在打开${entry.key}页面...',
            metadata: {'action': 'navigate', 'targetPage': entry.value},
            shouldSpeak: true,
          );
        }
      }
    }
    return null;
  }

  /// 处理错误
  void _handleError(String message) {
    setBallState(FloatingBallState.error);
    _addSystemMessage(message);

    Future.delayed(const Duration(seconds: 2), () {
      if (_ballState == FloatingBallState.error) {
        // 连续模式下，错误后也继续录音
        if (_continuousMode && _shouldAutoRestart) {
          debugPrint('[GlobalVoiceAssistant] 连续对话: 错误后自动继续');
          startRecording();
        } else {
          setBallState(FloatingBallState.idle);
        }
      }
    });
  }

  /// 添加用户消息
  void _addUserMessage(String content, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.user,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加助手消息
  void _addAssistantMessage(String content, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.assistant,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加处理结果消息（公开方法，供外部调用）
  ///
  /// 用于在语音命令处理完成后，将实际结果反馈给用户
  void addResultMessage(String content, {Map<String, dynamic>? metadata}) {
    _addAssistantMessage(content, metadata: metadata);
    notifyListeners();
  }

  /// 添加系统消息
  void _addSystemMessage(String content) {
    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ChatMessageType.system,
      content: content,
      timestamp: DateTime.now(),
    ));
  }

  /// 添加消息到历史
  void _addMessage(ChatMessage message) {
    _conversationHistory.add(message);

    // 限制历史记录数量
    while (_conversationHistory.length > _maxHistorySize) {
      _conversationHistory.removeAt(0);
    }

    // 保存到本地存储
    _saveHistoryToStorage();

    notifyListeners();
  }

  /// 清除对话历史
  void clearHistory() {
    _conversationHistory.clear();
    _addSystemMessage('对话历史已清除');
    _saveHistoryToStorage();
    notifyListeners();
  }

  /// 持久化存储的key
  static const String _historyStorageKey = 'voice_assistant_history';

  /// 保存对话历史到本地存储
  Future<void> _saveHistoryToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _conversationHistory.map((m) => m.toJson()).toList();
      await prefs.setString(_historyStorageKey, jsonEncode(historyJson));
      debugPrint('[GlobalVoiceAssistant] 对话历史已保存 (${_conversationHistory.length}条)');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 保存对话历史失败: $e');
    }
  }

  /// 从本地存储加载对话历史
  Future<void> loadHistoryFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_historyStorageKey);
      if (historyString != null && historyString.isNotEmpty) {
        final historyJson = jsonDecode(historyString) as List<dynamic>;
        _conversationHistory.clear();
        for (final item in historyJson) {
          _conversationHistory.add(ChatMessage.fromJson(item as Map<String, dynamic>));
        }
        debugPrint('[GlobalVoiceAssistant] 对话历史已加载 (${_conversationHistory.length}条)');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 加载对话历史失败: $e');
    }
  }

  /// 发送文本消息（非语音）
  Future<void> sendTextMessage(String text) async {
    if (text.isEmpty) return;

    _addUserMessage(text);
    setBallState(FloatingBallState.processing);

    try {
      final context = _contextService?.currentContext;
      final response = await _processIntent(text, context);

      _addAssistantMessage(response.message, metadata: response.metadata);
      setBallState(FloatingBallState.success);

      Future.delayed(const Duration(seconds: 1), () {
        if (_ballState == FloatingBallState.success) {
          setBallState(FloatingBallState.idle);
        }
      });
    } catch (e) {
      _handleError('处理失败');
    }
  }

  @override
  void dispose() {
    // 流式ASR相关
    _asrResultSubscription?.cancel();
    _audioStreamController?.close();

    // VAD相关
    _vadSubscription?.cancel();
    _vadService?.dispose();

    // 打断检测相关
    _bargeInSubscription?.cancel();
    _bargeInDetector?.dispose();

    // 音频相关
    _audioStreamSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder?.dispose();

    // TTS
    _ttsService?.dispose();

    super.dispose();
  }
}

/// 意图响应
class _IntentResponse {
  final String message;
  final Map<String, dynamic>? metadata;
  final bool shouldSpeak;

  _IntentResponse({
    required this.message,
    this.metadata,
    this.shouldSpeak = false,
  });
}
