import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_recognition_engine.dart';
import 'voice_token_service.dart';
import 'tts_service.dart';
import 'streaming_tts_service.dart';
import 'voice_context_service.dart';
import 'voice/realtime_vad_config.dart';
import 'voice/barge_in_detector.dart';
import 'voice/config/feature_flags.dart';
import 'voice/config/pipeline_config.dart';
import 'voice/pipeline/voice_pipeline_controller.dart';
import 'voice/intelligence_engine/result_buffer.dart';
import 'voice/intelligence_engine/proactive_conversation_manager.dart' show SimpleUserPreferencesProvider, DialogStylePreference, LLMServiceProvider, ConversationContextProvider;
import 'voice/network_monitor.dart' show ProactiveNetworkMonitor, NetworkStatus;
import 'voice/audio_processor_service.dart';
import 'voice/ambient_noise_calibrator.dart';
import 'voice/llm_response_generator.dart';
import 'qwen_service.dart';

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
  speaking,   // TTS播放中，显示喇叭动画
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

/// QwenLLM服务提供者
/// 包装QwenService的chat方法，用于主动话题生成
class QwenLLMServiceProvider implements LLMServiceProvider {
  final QwenService _qwenService;

  QwenLLMServiceProvider(this._qwenService);

  @override
  bool get isAvailable => _qwenService.isAvailable;

  @override
  Future<String?> generateTopic(String prompt) async {
    try {
      return await _qwenService.chat(prompt);
    } catch (e) {
      debugPrint('[QwenLLMServiceProvider] 生成话题失败: $e');
      return null;
    }
  }
}

/// 简单的对话上下文提供者
/// 从聊天历史中提取上下文信息
class SimpleConversationContextProvider implements ConversationContextProvider {
  final List<ChatMessage> Function() _getHistory;

  SimpleConversationContextProvider(this._getHistory);

  @override
  String? getContextSummary() {
    final history = _getHistory();
    if (history.isEmpty) return null;

    // 获取最近3条消息作为上下文
    final recent = history.length > 3 ? history.sublist(history.length - 3) : history;
    if (recent.isEmpty) return null;

    final buffer = StringBuffer();
    for (final msg in recent) {
      final role = msg.type == ChatMessageType.user ? '用户' : '助手';
      buffer.writeln('$role: ${msg.content}');
    }
    return buffer.toString().trim();
  }

  @override
  String? getRecentActionDescription() {
    final history = _getHistory();
    if (history.isEmpty) return null;

    // 查找最近一条助手消息中的操作描述
    for (int i = history.length - 1; i >= 0; i--) {
      final msg = history[i];
      if (msg.type == ChatMessageType.assistant && msg.metadata != null) {
        // 检查是否有操作信息
        final actionType = msg.metadata!['actionType'] as String?;
        if (actionType != null) {
          final amount = msg.metadata!['amount'];
          final category = msg.metadata!['category'] as String?;
          if (amount != null && category != null) {
            return '刚刚记录了一笔$category消费$amount元';
          }
        }
      }
    }
    return null;
  }
}

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

  // 流水线模式服务（新架构，当前唯一的语音处理模式）
  StreamingTTSService? _streamingTtsService;
  VoicePipelineController? _pipelineController;
  StreamSubscription<VoicePipelineState>? _pipelineStateSubscription;

  // 网络监控器
  ProactiveNetworkMonitor? _networkMonitor;

  // 录音器
  AudioRecorder? _audioRecorder;

  // 状态
  FloatingBallState _ballState = FloatingBallState.idle;
  bool _isVisible = true;
  Offset _position = Offset.zero;
  bool _isInitialized = false;

  // 预加载状态
  bool _isPreloading = false;
  bool _isPreloaded = false;
  DateTime? _preloadStartTime;

  // 对话历史
  final List<ChatMessage> _conversationHistory = [];
  // 减少历史记录大小以降低内存压力，避免潜在的崩溃问题
  static const int _maxHistorySize = 50;

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

  // 主动话题计时器（5秒静默触发）
  Timer? _proactiveTopicTimer;
  static const int _proactiveTopicTimeoutMs = 5000; // 5秒

  // 强制结束计时器（30秒静默触发）
  Timer? _forceEndTimer;
  static const int _forceEndTimeoutMs = 30000; // 30秒

  // 连续无响应计数器（最多3次主动话题）
  int _consecutiveNoResponseCount = 0;
  static const int _maxConsecutiveNoResponse = 3;

  // 用户偏好提供者（用于主动对话个性化）
  SimpleUserPreferencesProvider? _userPreferencesProvider;

  // LLM服务提供者（用于智能主动话题生成）
  QwenLLMServiceProvider? _llmServiceProvider;

  // 对话上下文提供者（用于给LLM提供对话背景）
  SimpleConversationContextProvider? _conversationContextProvider;

  // 命令处理中（TTS播放期间忽略ASR结果）
  bool _isProcessingCommand = false;

  // ASR输入静音（TTS播放期间停止向ASR发送音频，防止回声）
  bool _isMutingASRInput = false;

  // 上次LLM可用性检测结果（用于减少日志）
  bool? _lastLlmAvailability;

  // 权限回调（由 UI 层设置）
  void Function(MicrophonePermissionStatus status)? onPermissionRequired;

  // 命令处理回调（由 UI 层设置，用于集成 VoiceServiceCoordinator）
  CommandProcessorCallback? _commandProcessor;

  /// 设置命令处理回调
  void setCommandProcessor(CommandProcessorCallback? processor) {
    _commandProcessor = processor;
    debugPrint('[GlobalVoiceAssistant] 命令处理器已${processor != null ? "设置" : "清除"}');
  }

  /// 清除所有回调，防止内存泄漏
  /// 应在 widget dispose 时调用
  void clearCallbacks() {
    onPermissionRequired = null;
    _commandProcessor = null;
    debugPrint('[GlobalVoiceAssistant] 所有回调已清除');
  }

  // 结果缓冲区（用于查询结果通知）
  ResultBuffer? _resultBuffer;

  /// 设置结果缓冲区
  ///
  /// 当 VoiceServiceCoordinator 的 IntelligenceEngine 初始化后，
  /// 通过此方法将 ResultBuffer 传递给流水线，使 SmartTopicGenerator
  /// 能够在主动对话时检索待通知的查询结果。
  void setResultBuffer(ResultBuffer? buffer) {
    _resultBuffer = buffer;
    debugPrint('[GlobalVoiceAssistant] ResultBuffer已${buffer != null ? "设置" : "清除"}');

    // 如果流水线已初始化，需要重新创建以使用新的 ResultBuffer
    // 这种情况发生在：先初始化流水线，后启用智能引擎模式
    if (_pipelineController != null && buffer != null) {
      debugPrint('[GlobalVoiceAssistant] 流水线已存在，标记需要重新初始化');
      _needsReinitializePipeline = true;
    }
  }

  // 是否需要重新初始化流水线（当 ResultBuffer 变化时）
  bool _needsReinitializePipeline = false;

  /// 处理延迟响应（流水线模式）
  ///
  /// 当VoiceServiceCoordinator的延迟操作完成后，通过此方法将响应传递给流水线播放
  void handleDeferredResponse(String response) {
    debugPrint('[GlobalVoiceAssistant] 收到延迟响应: $response');

    // 检查流水线是否可用且处于listening状态
    if (_pipelineController == null) {
      debugPrint('[GlobalVoiceAssistant] ⚠️ 流水线控制器未初始化，无法播放延迟响应');
      return;
    }

    final pipelineState = _pipelineController!.state;
    if (pipelineState != VoicePipelineState.listening) {
      debugPrint('[GlobalVoiceAssistant] ⚠️ 流水线状态为$pipelineState，无法播放延迟响应');
      return;
    }

    // 注意：不在这里添加消息，triggerProactiveMessage 会通过 onProactiveMessage 回调添加
    // 避免重复添加消息

    // 通过流水线的主动消息机制播放响应
    // isUserResponse=true表示这是对用户输入的延迟响应，不计入主动对话次数
    debugPrint('[GlobalVoiceAssistant] 通过主动消息机制播放延迟响应');
    _pipelineController!.triggerProactiveMessage(response, isUserResponse: true);
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
  bool get isPipelineMode => true;  // 流水线模式始终启用

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
    // 停止主动话题计时器
    _stopProactiveTimers();
    _consecutiveNoResponseCount = 0;
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

    // 停止主动话题和强制结束计时器
    _stopProactiveTimers();
    _consecutiveNoResponseCount = 0;

    // 重置打断检测器
    _bargeInDetector?.reset();

    // 重置流水线控制器
    _pipelineController?.reset();

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
    _streamingTtsService?.stop().catchError((e) {
      debugPrint('[GlobalVoiceAssistant] 强制停止流式TTS失败: $e');
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
      // 加载特性开关配置
      await VoiceFeatureFlags.instance.load();
      debugPrint('[GlobalVoiceAssistant] 特性开关已加载: ${VoiceFeatureFlags.instance}');

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

      // 在后台异步预加载语音服务，不阻塞初始化
      _schedulePreload();
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 初始化失败: $e');
      rethrow;
    }
  }

  /// 调度预加载（延迟执行，避免影响应用启动）
  void _schedulePreload() {
    // 立即开始环境噪声校准（3秒）
    // 校准完成后会自动应用参数到 AudioProcessorService
    debugPrint('[GlobalVoiceAssistant] 开始环境噪声校准...');
    _startAmbientNoiseCalibration();

    // 延迟3秒后开始预加载，给应用启动留出时间
    Future.delayed(const Duration(seconds: 3), () async {
      debugPrint('[GlobalVoiceAssistant] 开始后台预加载...');
      await preload();
    });
  }

  /// 开始环境噪声校准
  void _startAmbientNoiseCalibration() {
    AmbientNoiseCalibrator.instance.startCalibration().then((result) {
      debugPrint('[GlobalVoiceAssistant] 噪声校准完成: $result');

      // 如果环境非常嘈杂，通知用户
      if (result.level == NoiseLevel.veryNoisy) {
        _addSystemMessage('当前环境较嘈杂，建议移至安静处使用语音助手');
        notifyListeners();
      }
    }).catchError((e) {
      debugPrint('[GlobalVoiceAssistant] 噪声校准失败: $e，将使用默认值');
    });
  }

  /// 预加载语音服务（在后台提前初始化，避免首次使用时的延迟）
  ///
  /// 预加载内容：
  /// - 语音服务Token（需要网络请求）
  /// - TTS服务初始化
  /// - 音频播放器初始化
  /// - 麦克风权限检查（不弹窗）
  ///
  /// 调用时机：
  /// - 应用启动后在后台调用
  /// - 用户进入可能使用语音的页面时
  /// - 悬浮球显示时
  ///
  /// 返回值：预加载是否成功完成
  Future<bool> preload() async {
    // 避免重复预加载
    if (_isPreloading) {
      debugPrint('[GlobalVoiceAssistant] 预加载进行中，跳过');
      return false;
    }
    if (_isPreloaded) {
      debugPrint('[GlobalVoiceAssistant] 已预加载，跳过');
      return true;
    }

    _isPreloading = true;
    _preloadStartTime = DateTime.now();
    debugPrint('[GlobalVoiceAssistant] ===== 开始预加载语音服务 =====');

    try {
      // 0. 初始化网络监控器
      debugPrint('[GlobalVoiceAssistant] [预加载] 0/5 初始化网络监控...');
      _networkMonitor = ProactiveNetworkMonitor();

      // 配置LLM可用性检测回调
      _networkMonitor!.configure(
        llmAvailabilityChecker: _checkLLMAvailability,
      );

      await _networkMonitor!.initializeOnAppStart();
      final networkStatus = _networkMonitor!.cachedStatus;
      debugPrint('[GlobalVoiceAssistant] [预加载] 0/5 网络监控已初始化: online=${networkStatus.isOnline}, llm=${networkStatus.llmAvailable}');

      // 1. 预加载语音Token（最耗时的网络请求）
      debugPrint('[GlobalVoiceAssistant] [预加载] 1/5 获取语音Token...');
      try {
        await VoiceTokenService().getToken();
        debugPrint('[GlobalVoiceAssistant] [预加载] 1/5 语音Token已获取');
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] [预加载] 1/5 Token获取失败（将在使用时重试）: $e');
      }

      // 2. 预初始化TTS服务
      debugPrint('[GlobalVoiceAssistant] [预加载] 2/5 初始化TTS服务...');
      _ttsService = TTSService.instance;
      await _ttsService!.initialize();
      // 不在这里启用streaming mode，避免创建重复的StreamingTTSService
      debugPrint('[GlobalVoiceAssistant] [预加载] 2/5 TTS服务已初始化');

      // 3. 预初始化流式TTS服务和音频播放器（用于流水线模式）
      debugPrint('[GlobalVoiceAssistant] [预加载] 3/9 初始化流式TTS服务...');
      _streamingTtsService = StreamingTTSService();
      await _streamingTtsService!.initialize();
      debugPrint('[GlobalVoiceAssistant] [预加载] 3/9 流式TTS服务已初始化');

      // 4. 检查麦克风权限（不弹窗请求）
      debugPrint('[GlobalVoiceAssistant] [预加载] 4/9 检查麦克风权限...');
      final permissionStatus = await Permission.microphone.status;
      debugPrint('[GlobalVoiceAssistant] [预加载] 4/9 麦克风权限状态: $permissionStatus');

      // 5. 预初始化 WebRTC APM 音频处理器
      debugPrint('[GlobalVoiceAssistant] [预加载] 5/9 初始化 WebRTC APM...');
      await AudioProcessorService.instance.initialize();
      debugPrint('[GlobalVoiceAssistant] [预加载] 5/9 WebRTC APM 已初始化');

      // 6. 预创建 AudioRecorder 实例
      debugPrint('[GlobalVoiceAssistant] [预加载] 6/9 创建录音器实例...');
      _audioRecorder ??= AudioRecorder();
      debugPrint('[GlobalVoiceAssistant] [预加载] 6/9 录音器实例已创建');

      // 7. 预初始化 VAD 和识别引擎（不需要权限）
      debugPrint('[GlobalVoiceAssistant] [预加载] 7/9 初始化 VAD 和识别引擎...');
      _recognitionEngine ??= VoiceRecognitionEngine();
      if (_vadService == null) {
        // 创建VAD服务，能量阈值作为降级方案的配置
        _vadService = RealtimeVADService(
          config: RealtimeVADConfig.defaultConfig().copyWith(
            speechEndThresholdMs: 1200,
            // 降级时使用的能量阈值配置
            energyThreshold: 0.001,
            minEnergyThreshold: 0.0003,
            maxEnergyThreshold: 0.01,
          ),
        );
        // 初始化Silero VAD（本地模型，约0.8秒）
        await _vadService!.initializeSileroVAD();
        debugPrint('[GlobalVoiceAssistant] VAD模式: ${_vadService!.isUsingSileroVAD ? "Silero神经网络" : "能量检测"}');
        _vadSubscription = _vadService!.eventStream.listen(_handleVADEvent);
      }
      debugPrint('[GlobalVoiceAssistant] [预加载] 7/9 VAD 和识别引擎已初始化');

      // 8. 预热TTS连接（提前建立HTTP连接，减少首次合成延迟）
      debugPrint('[GlobalVoiceAssistant] [预加载] 8/9 预热TTS连接...');
      try {
        await _streamingTtsService!.warmup();
        debugPrint('[GlobalVoiceAssistant] [预加载] 8/9 TTS连接预热完成');
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] [预加载] 8/9 TTS预热失败（不影响后续使用）: $e');
      }

      // 9. 预热ASR连接（在后台提前建立WebSocket连接）
      // 注：LLM连接已在步骤0的 _checkLLMAvailability() 中预热
      debugPrint('[GlobalVoiceAssistant] [预加载] 9/9 预热ASR连接...');
      try {
        _recognitionEngine?.warmupConnection();
        debugPrint('[GlobalVoiceAssistant] [预加载] 9/9 ASR连接预热已启动');
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] [预加载] 9/9 ASR预热失败（不影响后续使用）: $e');
      }

      final elapsed = DateTime.now().difference(_preloadStartTime!);
      _isPreloaded = true;
      debugPrint('[GlobalVoiceAssistant] ===== 预加载完成 (耗时${elapsed.inMilliseconds}ms) =====');

      // 通知监听者预加载完成，以便UI可以更新网络状态等
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 预加载失败: $e');
      return false;
    } finally {
      _isPreloading = false;
    }
  }

  /// 是否已预加载
  bool get isPreloaded => _isPreloaded;

  /// 获取网络状态
  NetworkStatus? get networkStatus => _networkMonitor?.cachedStatus;

  /// 获取网络状态变化流
  Stream<NetworkStatus>? get networkStatusStream => _networkMonitor?.statusStream;

  /// 主动检查LLM可用性（用户点击悬浮球时调用）
  Future<bool> checkLLMAvailability() async {
    if (_networkMonitor == null) {
      debugPrint('[GlobalVoiceAssistant] 网络监控器未初始化');
      return false;
    }
    return await _networkMonitor!.checkLLMAvailability();
  }

  /// LLM是否可用
  bool get isLLMAvailable => _networkMonitor?.cachedStatus.llmAvailable ?? false;

  /// 检测LLM服务是否可用（内部回调方法）
  ///
  /// 检测逻辑：
  /// 1. 检查API Key是否已配置
  /// 2. 尝试连接LLM服务（轻量级请求）
  Future<bool> _checkLLMAvailability() async {
    try {
      final qwenService = QwenService();

      // 1. 检查API Key是否配置
      if (!qwenService.isAvailable) {
        final isAvailable = false;
        if (_lastLlmAvailability != isAvailable) {
          debugPrint('[GlobalVoiceAssistant] LLM可用性检测: $isAvailable (API Key未配置)');
          _lastLlmAvailability = isAvailable;
        }
        return false;
      }

      // 2. 尝试一个轻量级的LLM请求来验证连接
      // 使用简单的聊天请求，超时时间短
      final result = await qwenService.chat('hi').timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      final isAvailable = result != null && result.isNotEmpty;
      // 只在状态变化时记录日志
      if (_lastLlmAvailability != isAvailable) {
        debugPrint('[GlobalVoiceAssistant] LLM可用性检测: $isAvailable');
        _lastLlmAvailability = isAvailable;
      }
      return isAvailable;
    } catch (e) {
      final isAvailable = false;
      // 只在状态变化时记录日志
      if (_lastLlmAvailability != isAvailable) {
        debugPrint('[GlobalVoiceAssistant] LLM可用性检测失败: $e');
        _lastLlmAvailability = isAvailable;
      }
      return false;
    }
  }

  /// 确保语音服务已初始化
  Future<void> _ensureVoiceServicesInitialized() async {
    // 检查核心服务是否已初始化（可能在预加载中完成）
    final alreadyInitialized = _audioRecorder != null && _pipelineController != null;
    if (alreadyInitialized) {
      debugPrint('[GlobalVoiceAssistant] 语音服务已预加载完成，跳过初始化');
      return;
    }

    final startTime = DateTime.now();
    debugPrint('[GlobalVoiceAssistant] 开始初始化语音服务 (已预加载=$_isPreloaded)...');

    // 录音器和识别引擎（如果预加载已创建则跳过）
    _audioRecorder ??= AudioRecorder();
    _recognitionEngine ??= VoiceRecognitionEngine();

    // TTS服务（如果预加载已初始化则跳过）
    if (_ttsService == null) {
      _ttsService = TTSService.instance;
      await _ttsService!.initialize();
      await _ttsService!.enableStreamingMode();
      debugPrint('[GlobalVoiceAssistant] TTS服务初始化完成');
    } else {
      debugPrint('[GlobalVoiceAssistant] TTS服务已预加载，跳过初始化');
    }

    // 初始化VAD服务（如果预加载已创建则跳过）
    // speechEndThresholdMs权衡：太短会截断用户思考，太长会响应迟钝
    // 800ms: 反应快但易截断 | 1200ms: 折中 | 1500ms: 安全但迟钝
    if (_vadService == null) {
      // 创建VAD服务，能量阈值作为降级方案的配置
      _vadService = RealtimeVADService(
        config: RealtimeVADConfig.defaultConfig().copyWith(
          speechEndThresholdMs: 1200,  // 静音1.2秒判定说完（折中方案）
          // 降级时使用的能量阈值配置
          energyThreshold: 0.001,
          minEnergyThreshold: 0.0003,
          maxEnergyThreshold: 0.01,
        ),
      );
      // 初始化Silero VAD（优先使用神经网络检测，失败时自动降级到能量检测）
      await _vadService!.initializeSileroVAD();
      debugPrint('[GlobalVoiceAssistant] VAD模式: ${_vadService!.isUsingSileroVAD ? "Silero神经网络" : "能量检测"}');
      // 订阅VAD事件
      _vadSubscription = _vadService!.eventStream.listen(_handleVADEvent);
    } else {
      debugPrint('[GlobalVoiceAssistant] VAD服务已预加载，跳过初始化');
    }

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

    // 初始化流水线模式（当前唯一的语音处理模式）
    await _initializePipelineMode();

    final elapsed = DateTime.now().difference(startTime);
    debugPrint('[GlobalVoiceAssistant] 语音服务初始化完成，耗时=${elapsed.inMilliseconds}ms (已预加载=$_isPreloaded, VAD+BargeIn已启用)');
  }

  /// 初始化流水线模式
  Future<void> _initializePipelineMode() async {
    debugPrint('[GlobalVoiceAssistant] 初始化流水线模式...');

    // 流式TTS服务（如果预加载已初始化则跳过）
    if (_streamingTtsService == null) {
      _streamingTtsService = StreamingTTSService();
      await _streamingTtsService!.initialize();
      debugPrint('[GlobalVoiceAssistant] 流式TTS服务初始化完成');
    } else {
      debugPrint('[GlobalVoiceAssistant] 流式TTS服务已预加载，跳过初始化');
    }

    // 创建用户偏好提供者（如果尚未创建）
    _userPreferencesProvider ??= SimpleUserPreferencesProvider();

    // 创建LLM服务提供者（用于智能主动话题生成）
    _llmServiceProvider ??= QwenLLMServiceProvider(QwenService());

    // 创建对话上下文提供者（用于给LLM提供对话背景）
    _conversationContextProvider ??= SimpleConversationContextProvider(
      () => _conversationHistory,
    );

    // 创建流水线控制器
    // 传入 ResultBuffer 使 SmartTopicGenerator 能够检索查询结果
    // 传入 UserPreferencesProvider 使主动对话能够根据用户偏好个性化
    // 传入 LLMServiceProvider 使主动对话能够智能生成话题
    // 传入 ConversationContextProvider 使LLM能够了解对话背景
    _pipelineController = VoicePipelineController(
      asrEngine: _recognitionEngine!,
      ttsService: _streamingTtsService!,
      vadService: _vadService,
      config: PipelineConfig.defaultConfig,
      resultBuffer: _resultBuffer,
      userPreferencesProvider: _userPreferencesProvider,
      llmServiceProvider: _llmServiceProvider,
      conversationContextProvider: _conversationContextProvider,
    );

    // 重置重新初始化标记
    _needsReinitializePipeline = false;

    // 设置流水线回调
    _setupPipelineCallbacks();

    debugPrint('[GlobalVoiceAssistant] 流水线控制器已创建');
  }

  /// 重新初始化流水线（当 ResultBuffer 变化时）
  ///
  /// 保留现有的 TTS 服务和 VAD 服务，只重建流水线控制器
  Future<void> _reinitializePipeline() async {
    debugPrint('[GlobalVoiceAssistant] 重新初始化流水线...');

    // 先停止并释放旧的流水线控制器
    if (_pipelineController != null) {
      _pipelineStateSubscription?.cancel();
      _pipelineStateSubscription = null;
      await _pipelineController!.dispose();
      _pipelineController = null;
    }

    // 重新创建流水线控制器（传入新的 ResultBuffer 和服务提供者）
    _pipelineController = VoicePipelineController(
      asrEngine: _recognitionEngine!,
      ttsService: _streamingTtsService!,
      vadService: _vadService,
      config: PipelineConfig.defaultConfig,
      resultBuffer: _resultBuffer,
      userPreferencesProvider: _userPreferencesProvider,
      llmServiceProvider: _llmServiceProvider,
      conversationContextProvider: _conversationContextProvider,
    );

    // 重新设置回调
    _setupPipelineCallbacks();

    // 重置标记
    _needsReinitializePipeline = false;

    debugPrint('[GlobalVoiceAssistant] 流水线重新初始化完成');
  }

  /// 设置流水线回调
  void _setupPipelineCallbacks() {
    if (_pipelineController == null) return;

    // 状态变化回调
    _pipelineController!.onStateChanged = (state) {
      debugPrint('[GlobalVoiceAssistant] 流水线状态: $state');
      _handlePipelineStateChanged(state);
    };

    // 中间结果回调（实时显示用户说的话）
    _pipelineController!.onPartialResult = (text) {
      _partialText = text;

      // 在对话记录中实时显示识别中的文字（临时消息）
      if (text.trim().isNotEmpty) {
        _updateOrCreateTemporaryUserMessage(text);
      }

      notifyListeners();
    };

    // 最终结果回调（将临时消息转为正式消息）
    _pipelineController!.onFinalResult = (text) {
      debugPrint('[GlobalVoiceAssistant] [PIPELINE] onFinalResult 收到: "$text"');
      _partialText = '';

      // 将临时消息转为正式消息
      _finalizeTemporaryUserMessage(text);

      notifyListeners();
    };

    // 处理用户输入回调（连接到命令处理器）
    _pipelineController!.onProcessInput = _handlePipelineProcessInput;

    // 打断回调
    _pipelineController!.onBargeIn = (result) {
      debugPrint('[GlobalVoiceAssistant] 流水线打断: $result');
      _addAssistantMessage('好的，请继续~');
    };

    // 错误回调
    _pipelineController!.onError = (error) {
      debugPrint('[GlobalVoiceAssistant] 流水线错误: $error');
      _handleError('语音处理出错');
    };

    // 需要重启音频录制回调（当ASR超时或流意外结束时）
    _pipelineController!.onNeedRestartRecording = () {
      debugPrint('[GlobalVoiceAssistant] 收到重启音频录制请求');
      _restartNativeAudioRecording();
    };

    // 主动对话消息回调（添加到聊天历史）
    _pipelineController!.onProactiveMessage = (message) {
      debugPrint('[GlobalVoiceAssistant] 主动对话消息: $message');
      _addAssistantMessage(message);
      notifyListeners();
    };

    // 会话超时回调（ProactiveConversationManager 触发）
    // 统一的会话超时处理：连续3次无回应 或 30秒总计无响应
    _pipelineController!.onSessionTimeout = () {
      debugPrint('[GlobalVoiceAssistant] 收到会话超时通知（ProactiveConversationManager）');
      _handleProactiveSessionTimeout();
    };
  }

  /// 处理主动对话会话超时
  ///
  /// 由 ProactiveConversationManager 触发，统一管理会话超时：
  /// - 连续3次主动话题无回应
  /// - 或30秒总计无响应
  ///
  /// 流程：先播放告别消息，然后再停止流水线（确保时序正确）
  Future<void> _handleProactiveSessionTimeout() async {
    debugPrint('[GlobalVoiceAssistant] 处理主动对话会话超时');

    // 使用LLM生成告别消息
    final farewell = await LLMResponseGenerator.instance.generateFarewellResponse(
      farewellType: 'sessionTimeout',
    );
    _addAssistantMessage(farewell);

    // 播放告别消息
    try {
      await _streamingTtsService?.speak(farewell);
      debugPrint('[GlobalVoiceAssistant] 告别消息播放完成');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 播放告别消息失败: $e');
    }

    // 重置状态
    _isProcessingCommand = false;
    _consecutiveNoResponseCount = 0;

    // 告别消息播放完成后，通知流水线完成停止
    // 这确保了正确的时序：先播放告别 → 再变成 idle
    await _pipelineController?.stopAfterFarewell();

    // 停止音频录制和清理资源
    await _cleanupAudioRecording();

    notifyListeners();
  }

  /// 清理音频录制资源（不调用 VoicePipelineController.stop()）
  ///
  /// 用于会话超时时的清理，此时 VoicePipelineController.stop() 已经被调用
  Future<void> _cleanupAudioRecording() async {
    debugPrint('[GlobalVoiceAssistant] 清理音频录制资源');

    // 关闭音频流控制器
    await _audioStreamController?.close();
    _audioStreamController = null;

    // 停止音频流订阅
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    // 停止录音器
    await _audioRecorder?.stop();

    // 重置状态
    _partialText = '';
    _amplitude = 0.0;

    setBallState(FloatingBallState.idle);
    debugPrint('[GlobalVoiceAssistant] 音频录制资源已清理');
  }

  /// 处理流水线状态变化
  ///
  /// 注意：会话超时管理已统一由 VoicePipelineController 中的 ProactiveConversationManager 处理
  /// 这里不再管理 VAD 的 silenceTimeout 计时器
  void _handlePipelineStateChanged(VoicePipelineState pipelineState) {
    switch (pipelineState) {
      case VoicePipelineState.idle:
        setBallState(FloatingBallState.idle);
        // 通知 WebRTC APM TTS 停止
        AudioProcessorService.instance.setTTSPlaying(false);
        break;
      case VoicePipelineState.listening:
        setBallState(FloatingBallState.recording);
        // 通知 WebRTC APM TTS 停止
        AudioProcessorService.instance.setTTSPlaying(false);
        // 注意：会话超时由 ProactiveConversationManager 在 VoicePipelineController 中管理
        // 不再在这里调用 _vadService?.startSilenceTimeoutDetection()
        break;
      case VoicePipelineState.processing:
        setBallState(FloatingBallState.processing);
        break;
      case VoicePipelineState.speaking:
        setBallState(FloatingBallState.speaking);  // TTS播放时显示播放状态
        // 通知 WebRTC APM TTS 开始播放，增强 AEC
        AudioProcessorService.instance.setTTSPlaying(true);
        break;
      case VoicePipelineState.stopping:
        // 保持当前状态
        break;
    }
  }

  /// 处理流水线的用户输入（连接到命令处理器）
  Future<void> _handlePipelineProcessInput(
    String userInput,
    void Function(String chunk) onChunk,
    VoidCallback onComplete,
  ) async {
    debugPrint('[GlobalVoiceAssistant] 流水线处理输入: $userInput');

    // 首先检查是否为结束命令
    if (_isVoiceEndCommand(userInput)) {
      debugPrint('[GlobalVoiceAssistant] 检测到结束命令: $userInput');
      // 使用LLM生成告别语
      final farewell = await LLMResponseGenerator.instance.generateFarewellResponse(
        farewellType: 'userEnd',
      );
      _addAssistantMessage(farewell);
      onChunk(farewell);
      onComplete();

      // 延迟后停止流水线，让告别语有时间播放
      Future.delayed(const Duration(milliseconds: 2000), () {
        _stopRecordingWithPipeline();
      });
      return;
    }

    if (_commandProcessor != null) {
      try {
        final response = await _commandProcessor!(userInput);
        if (response != null && response.isNotEmpty) {
          // 添加助手消息
          _addAssistantMessage(response);

          // 将响应发送给流水线播放
          onChunk(response);
          onComplete();
        } else {
          onComplete();
        }
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 命令处理器错误: $e');
        const errorMsg = '抱歉，处理失败了';
        _addAssistantMessage(errorMsg);
        onChunk(errorMsg);
        onComplete();
      }
    } else {
      // 没有外部处理器，使用本地即时反馈
      final response = _getImmediateResponse(userInput);
      _addAssistantMessage(response);
      onChunk(response);
      onComplete();
    }
  }

  /// 使用流水线模式开始录音
  Future<void> _startRecordingWithPipeline() async {
    debugPrint('[GlobalVoiceAssistant] 使用流水线模式开始录音');

    // 重置状态
    _partialText = '';
    _isProcessingUtterance = false;

    // 重置VAD服务，取消之前的静默超时计时器
    _vadService?.reset();

    // 获取环境噪声校准结果
    // 如果校准还没完成，取消并使用已有数据或默认值
    final calibrationResult = AmbientNoiseCalibrator.instance.cancelAndGetResult();
    debugPrint('[GlobalVoiceAssistant] [0/6] 环境噪声校准: $calibrationResult');

    // 初始化 WebRTC APM 软件音频处理（AEC/NS/AGC）
    // 如果已在预加载中初始化则跳过
    if (!AudioProcessorService.instance.isInitialized) {
      debugPrint('[GlobalVoiceAssistant] [1/6] 初始化 WebRTC APM...');
      await AudioProcessorService.instance.initialize();
    } else {
      debugPrint('[GlobalVoiceAssistant] [1/6] WebRTC APM 已预加载，跳过初始化');
    }

    // 应用校准结果到音频处理器
    await AudioProcessorService.instance.applyCalibration(calibrationResult);
    debugPrint('[GlobalVoiceAssistant] [2/6] WebRTC APM 校准参数已应用');

    // 启动流水线控制器
    debugPrint('[GlobalVoiceAssistant] [3/6] 启动流水线控制器...');
    await _pipelineController!.start();
    debugPrint('[GlobalVoiceAssistant] [4/6] 流水线控制器已启动');

    // 创建音频流广播控制器
    _audioStreamController = StreamController<Uint8List>.broadcast();
    debugPrint('[GlobalVoiceAssistant] [5/6] 音频流控制器已创建');

    // 录音配置 - 禁用硬件级音频处理，只使用 WebRTC APM 软件处理
    // 避免双重 3A 处理导致音频失真
    final config = RecordConfig(
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

    // 开始流式录音
    debugPrint('[GlobalVoiceAssistant] [6/6] 开始调用startStream...');
    final audioStream = await _audioRecorder!.startStream(config);
    debugPrint('[GlobalVoiceAssistant] startStream返回成功，开始处理音频流');

    // 音频数据计数器（使用实例变量以便在重启后重置）
    _pipelineAudioDataCount = 0;

    // 订阅音频流，通过 WebRTC APM 处理后传输给流水线控制器
    _audioStreamSubscription = audioStream.listen(
      (data) async {
        final rawAudioData = Uint8List.fromList(data);
        _pipelineAudioDataCount++;

        // 计算原始音频振幅（用于调试）
        int rawMaxAmplitude = 0;
        for (int i = 0; i < rawAudioData.length - 1; i += 2) {
          int sample = rawAudioData[i] | (rawAudioData[i + 1] << 8);
          if (sample > 32767) sample -= 65536;
          final absValue = sample.abs();
          if (absValue > rawMaxAmplitude) rawMaxAmplitude = absValue;
        }

        // 通过 WebRTC APM 软件处理（AEC/NS/AGC）
        final processedAudioData = await AudioProcessorService.instance.processAudio(rawAudioData);

        // 计算处理后音频振幅（用于调试）
        int processedMaxAmplitude = 0;
        for (int i = 0; i < processedAudioData.length - 1; i += 2) {
          int sample = processedAudioData[i] | (processedAudioData[i + 1] << 8);
          if (sample > 32767) sample -= 65536;
          final absValue = sample.abs();
          if (absValue > processedMaxAmplitude) processedMaxAmplitude = absValue;
        }

        // 前10次每次都打印，之后每100次打印一次（约3秒一次）
        if (_pipelineAudioDataCount <= 10 || _pipelineAudioDataCount % 100 == 0) {
          final pipelineState = _pipelineController?.state;
          debugPrint('[GlobalVoiceAssistant] 音频数据 #$_pipelineAudioDataCount, ballState=$_ballState, pipelineState=$pipelineState, 原始振幅=$rawMaxAmplitude, 处理后振幅=$processedMaxAmplitude');
        }

        // 发送处理后的音频到流水线控制器
        _pipelineController?.feedAudioData(processedAudioData);

        // 计算振幅用于UI显示（使用处理后的数据）
        _updateAmplitudeFromPCM(processedAudioData);
      },
      onError: (error) {
        debugPrint('[GlobalVoiceAssistant] 音频流错误: $error');
        // 音频流出错，尝试重新启动
        _handleAudioStreamError(error);
      },
      onDone: () {
        debugPrint('[GlobalVoiceAssistant] 音频流结束(onDone), ballState=$_ballState, continuousMode=$_continuousMode');
        // 如果仍在录音状态，说明音频流意外结束，需要重启
        if (_ballState == FloatingBallState.recording && _continuousMode) {
          debugPrint('[GlobalVoiceAssistant] 音频流意外结束，尝试重新启动');
          _restartPipelineRecording();
        }
      },
    );

    _recordingStartTime = DateTime.now();
    setBallState(FloatingBallState.recording);

    debugPrint('[GlobalVoiceAssistant] 流水线模式录音已启动');
  }

  /// 音频数据计数器（流水线模式）
  int _pipelineAudioDataCount = 0;

  /// 处理音频流错误
  void _handleAudioStreamError(Object error) {
    debugPrint('[GlobalVoiceAssistant] 处理音频流错误: $error');

    // 如果仍在连续对话模式，尝试重新启动
    if (_continuousMode && _ballState == FloatingBallState.recording) {
      _restartPipelineRecording();
    } else {
      _handleError('音频录制出错');
    }
  }

  /// 重启原生音频录制（由流水线控制器请求时调用）
  ///
  /// 这是一个同步版本，用于在流水线重启过程中调用
  Future<void> _restartNativeAudioRecording() async {
    debugPrint('[GlobalVoiceAssistant] 重启原生音频录制...');

    try {
      // 停止当前录音订阅
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // 停止当前录音器
      await _audioRecorder?.stop();

      // 等待音频设备完全释放（避免音频饱和问题）
      await Future.delayed(const Duration(milliseconds: 100));

      // 重新开始录音 - 禁用硬件级 3A，只使用 WebRTC APM
      final config = RecordConfig(
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

      final audioStream = await _audioRecorder!.startStream(config);
      _pipelineAudioDataCount = 0;

      _audioStreamSubscription = audioStream.listen(
        (data) async {
          final rawAudioData = Uint8List.fromList(data);
          _pipelineAudioDataCount++;

          // 通过 WebRTC APM 软件处理
          final processedAudioData = await AudioProcessorService.instance.processAudio(rawAudioData);

          if (_pipelineAudioDataCount <= 10 || _pipelineAudioDataCount % 100 == 0) {
            final pipelineState = _pipelineController?.state;
            debugPrint('[GlobalVoiceAssistant] 重启后音频数据 #$_pipelineAudioDataCount, ballState=$_ballState, pipelineState=$pipelineState');
          }

          _pipelineController?.feedAudioData(processedAudioData);
          _updateAmplitudeFromPCM(processedAudioData);
        },
        onError: (error) {
          debugPrint('[GlobalVoiceAssistant] 重启后音频流错误: $error');
        },
        onDone: () {
          debugPrint('[GlobalVoiceAssistant] 重启后音频流结束(onDone)');
        },
      );

      debugPrint('[GlobalVoiceAssistant] 原生音频录制重启成功 (硬件AEC + WebRTC APM)');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 重启原生音频录制失败: $e');
    }
  }

  /// 重新启动流水线录音
  Future<void> _restartPipelineRecording() async {
    debugPrint('[GlobalVoiceAssistant] 重新启动流水线录音...');

    try {
      // 停止当前录音订阅
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // 重新开始录音 - 禁用硬件级 3A，只使用 WebRTC APM
      final config = RecordConfig(
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

      final audioStream = await _audioRecorder!.startStream(config);
      _pipelineAudioDataCount = 0;

      _audioStreamSubscription = audioStream.listen(
        (data) async {
          final rawAudioData = Uint8List.fromList(data);
          _pipelineAudioDataCount++;

          // 通过 WebRTC APM 软件处理
          final processedAudioData = await AudioProcessorService.instance.processAudio(rawAudioData);

          if (_pipelineAudioDataCount <= 10 || _pipelineAudioDataCount % 100 == 0) {
            final pipelineState = _pipelineController?.state;
            debugPrint('[GlobalVoiceAssistant] 重启后音频数据 #$_pipelineAudioDataCount, ballState=$_ballState, pipelineState=$pipelineState');
          }

          _pipelineController?.feedAudioData(processedAudioData);
          _updateAmplitudeFromPCM(processedAudioData);
        },
        onError: (error) {
          debugPrint('[GlobalVoiceAssistant] 重启后音频流错误: $error');
        },
        onDone: () {
          debugPrint('[GlobalVoiceAssistant] 重启后音频流结束');
        },
      );

      debugPrint('[GlobalVoiceAssistant] 流水线录音重新启动成功 (硬件AEC + WebRTC APM)');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 重新启动流水线录音失败: $e');
      _handleError('无法重新启动录音');
    }
  }

  /// 使用流水线模式停止录音
  Future<void> _stopRecordingWithPipeline() async {
    debugPrint('[GlobalVoiceAssistant] 使用流水线模式停止录音');

    // 停止流水线控制器
    await _pipelineController?.stop();

    // 关闭音频流控制器
    await _audioStreamController?.close();
    _audioStreamController = null;

    // 停止音频流订阅
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    // 停止录音器
    await _audioRecorder?.stop();

    // 重置状态
    _partialText = '';
    _amplitude = 0.0;

    // 清理未完成的临时消息
    _conversationHistory.removeWhere((msg) => msg.id == _temporaryUserMessageId);

    setBallState(FloatingBallState.idle);
    debugPrint('[GlobalVoiceAssistant] 流水线模式录音已停止');
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
        // 用户开始说话，重置主动话题计时器和无响应计数
        _resetProactiveState();
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

    // 3. 恢复ASR输入（关键！之前漏了这一步）
    _isMutingASRInput = false;
    debugPrint('[GlobalVoiceAssistant] ASR输入已恢复');

    // 4. 重启ASR监听用户新输入
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
  /// 预热ASR连接（可在startRecording前调用，节省100-300ms）
  ///
  /// 应在用户点击麦克风按钮时立即调用
  /// 不需要等待完成，可以fire-and-forget
  /// 调用此方法后再调用startRecording，可以更快开始识别
  Future<void> warmupASRConnection() async {
    debugPrint('[GlobalVoiceAssistant] 预热ASR连接...');

    // 确保服务已初始化
    if (_pipelineController == null) {
      try {
        await _ensureVoiceServicesInitialized();
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 预热失败(服务未初始化): $e');
        return;
      }
    }

    // 调用流水线的预热方法
    await _pipelineController?.warmup();
  }

  /// 4. 收到最终结果时处理命令
  /// 5. 录音流持续活跃，继续监听
  Future<void> startRecording() async {
    debugPrint('[GlobalVoiceAssistant] startRecording() 被调用，当前状态: $_ballState');
    if (_ballState == FloatingBallState.recording) {
      debugPrint('[GlobalVoiceAssistant] 已经在录音中，跳过');
      return;
    }

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

      // 流水线模式（当前唯一的语音处理模式）
      if (_pipelineController != null) {
        // 检查是否需要重新初始化流水线（ResultBuffer 变化时）
        if (_needsReinitializePipeline && _resultBuffer != null) {
          debugPrint('[GlobalVoiceAssistant] ResultBuffer已更新，重新初始化流水线');
          await _reinitializePipeline();
        }
        await _startRecordingWithPipeline();
        return;
      }

      // 降级模式：流水线控制器未初始化时使用传统逻辑
      debugPrint('[GlobalVoiceAssistant] 警告: 流水线控制器未初始化，使用降级模式');
      // 重置状态
      _partialText = '';
      _isProcessingUtterance = false;
      _vadService?.reset();

      // 创建音频流广播控制器（用于传递给流式ASR）
      _audioStreamController = StreamController<Uint8List>.broadcast();

      // 录音配置 - 禁用硬件级 3A，只使用 WebRTC APM
      final config = RecordConfig(
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

      // 开始流式录音
      debugPrint('[GlobalVoiceAssistant] 开始流式录音+实时ASR (仅WebRTC APM)');
      final audioStream = await _audioRecorder!.startStream(config);

      // 订阅音频流，同时传输给VAD、ASR和打断检测器
      _audioStreamSubscription = audioStream.listen((data) {
        final audioData = Uint8List.fromList(data);

        // 1. 传输给流式ASR
        // 关键：TTS播放时不发送音频给ASR，避免回声被识别
        if (_audioStreamController != null && !_audioStreamController!.isClosed) {
          if (!_isMutingASRInput) {
            _audioStreamController!.add(audioData);
          }
          // TTS播放时不发送，避免回声
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

      _recordingStartTime = DateTime.now();
      setBallState(FloatingBallState.recording);

      debugPrint('[GlobalVoiceAssistant] 流式语音处理已启动');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 开始录音失败: $e');
      _handleError('无法开始录音，请检查麦克风权限');
    }
  }

  /// 启动流式ASR识别
  void _startStreamingASR() {
    if (_audioStreamController == null || _recognitionEngine == null) return;

    // 警告：流水线模式下不应该调用此方法
    if (_pipelineController != null) {
      debugPrint('[GlobalVoiceAssistant] ⚠️ 警告: 流水线模式下调用了 _startStreamingASR，这可能导致重复消息！');
      // 打印调用堆栈帮助定位问题
      debugPrint(StackTrace.current.toString().split('\n').take(10).join('\n'));
    }

    debugPrint('[GlobalVoiceAssistant] [LEGACY] 启动流式ASR');

    // 订阅流式ASR结果
    _asrResultSubscription = _recognitionEngine!
        .transcribeStream(_audioStreamController!.stream)
        .listen(
      (result) {
        // 检查是否为结束命令（即使在TTS播放中也要响应）
        if (result.isFinal && _isVoiceEndCommand(result.text)) {
          debugPrint('[GlobalVoiceAssistant] 检测到结束命令: "${result.text}"');
          _handleVoiceEndCommand();
          return;
        }

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

      // 检查是否应该自动重启ASR
      // 如果正在静音ASR输入（TTS播放期间），不要重启，因为会创建空闲的WebSocket连接导致超时
      if (_isMutingASRInput) {
        debugPrint('[GlobalVoiceAssistant] ASR输入静音中，跳过自动重启');
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
    // 警告：流水线模式下不应该调用此方法
    if (_pipelineController != null) {
      debugPrint('[GlobalVoiceAssistant] ⚠️ 警告: 流水线模式下调用了 _handleFinalASRResult，这可能导致重复消息！');
      debugPrint('[GlobalVoiceAssistant] 调用堆栈:');
      debugPrint(StackTrace.current.toString().split('\n').take(15).join('\n'));
      // 继续执行以便观察问题
    }

    debugPrint('[GlobalVoiceAssistant] [LEGACY] 处理最终识别结果: $recognizedText');

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
        // 关键：停止向ASR发送音频，防止TTS回声被录入
        _isMutingASRInput = true;
        debugPrint('[GlobalVoiceAssistant] ASR输入已静音（防止回声）');

        // 取消当前ASR会话（清除已缓冲的数据）
        await _recognitionEngine?.cancelTranscription();
        _asrResultSubscription?.cancel();
        _asrResultSubscription = null;
        debugPrint('[GlobalVoiceAssistant] ASR会话已取消');

        final response = await _commandProcessor!(recognizedText);
        if (response != null && response.isNotEmpty) {
          _addAssistantMessage(response);

          // 启用打断检测模式（录音继续，VAD运行，用于检测用户打断）
          _enableBargeInDetection();

          // 由GlobalVoiceAssistantManager自己播放TTS，确保_isProcessingCommand
          // 在TTS播放完成前保持为true，防止回声被当作用户输入
          if (_streamingTtsService != null) {
            debugPrint('[GlobalVoiceAssistant] 开始播放TTS响应: $response');
            try {
              await _streamingTtsService!.speak(response);
              debugPrint('[GlobalVoiceAssistant] TTS播放完成');
            } catch (ttsError) {
              debugPrint('[GlobalVoiceAssistant] TTS播放失败: $ttsError');
            }
          }

          // TTS播放完成，禁用打断检测
          _disableBargeInDetection();
        }

        // 等待回声消散
        debugPrint('[GlobalVoiceAssistant] 等待回声消散...');
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('[GlobalVoiceAssistant] 回声等待完成');

        // 恢复ASR输入
        _isMutingASRInput = false;
        debugPrint('[GlobalVoiceAssistant] ASR输入已恢复');

        // 重新启动ASR会话（全新会话，无残留数据）
        if (_ballState == FloatingBallState.recording) {
          _startStreamingASR();
          debugPrint('[GlobalVoiceAssistant] ASR会话已重启');

          // 连续对话模式下，启动主动话题计时器
          if (_continuousMode) {
            _startProactiveTimers();
          }
        }
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 命令处理器错误: $e');
        // 出错时也要恢复ASR
        _isMutingASRInput = false;
        if (_ballState == FloatingBallState.recording) {
          _startStreamingASR();
          // 连续对话模式下，启动主动话题计时器
          if (_continuousMode) {
            _startProactiveTimers();
          }
        }
      } finally {
        // 命令处理完成，清除处理中标志
        _isProcessingCommand = false;
      }
    } else {
      // 没有外部处理器时，使用本地即时反馈
      final immediateResponse = _getImmediateResponse(recognizedText);
      _addAssistantMessage(immediateResponse);

      try {
        // 关键：停止向ASR发送音频，防止TTS回声被录入
        _isMutingASRInput = true;
        debugPrint('[GlobalVoiceAssistant] ASR输入已静音（防止回声）');

        // 取消当前ASR会话（清除已缓冲的数据）
        await _recognitionEngine?.cancelTranscription();
        _asrResultSubscription?.cancel();
        _asrResultSubscription = null;
        debugPrint('[GlobalVoiceAssistant] ASR会话已取消');

        // 启用打断检测模式
        _enableBargeInDetection();

        // 播放即时反馈
        if (_streamingTtsService != null) {
          try {
            await _streamingTtsService!.speak(immediateResponse);
          } catch (ttsError) {
            debugPrint('[GlobalVoiceAssistant] TTS播报失败: $ttsError');
          }
        }

        // TTS播放完成，禁用打断检测
        _disableBargeInDetection();

        // 等待回声消散
        debugPrint('[GlobalVoiceAssistant] TTS播放完成，等待回声消散...');
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('[GlobalVoiceAssistant] 回声等待完成');

        // 恢复ASR输入
        _isMutingASRInput = false;
        debugPrint('[GlobalVoiceAssistant] ASR输入已恢复');

        // 重新启动ASR会话（全新会话，无残留数据）
        if (_ballState == FloatingBallState.recording) {
          _startStreamingASR();
          debugPrint('[GlobalVoiceAssistant] ASR会话已重启');

          // 连续对话模式下，启动主动话题计时器
          if (_continuousMode) {
            _startProactiveTimers();
          }
        }
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 本地响应处理错误: $e');
        // 出错时也要恢复ASR
        _isMutingASRInput = false;
        if (_ballState == FloatingBallState.recording) {
          _startStreamingASR();
          // 连续对话模式下，启动主动话题计时器
          if (_continuousMode) {
            _startProactiveTimers();
          }
        }
      } finally {
        _isProcessingCommand = false;
      }
    }

    notifyListeners();
  }

  /// 检测是否为语音结束命令
  ///
  /// 支持的结束词："结束"、"停止"、"好了"、"谢谢"、"拜拜"、"再见"、"没了"
  bool _isVoiceEndCommand(String text) {
    if (text.isEmpty) return false;

    // 结束命令关键词（精确匹配或包含）
    const endKeywords = [
      '结束',
      '停止',
      '好了',
      '谢谢',
      '拜拜',
      '再见',
      '没了',
      '退出',
      '关闭',
    ];

    final normalizedText = text.replaceAll(RegExp(r'[。，！？,.!?]'), '').trim();

    // 检查是否以结束词结尾或完全匹配
    for (final keyword in endKeywords) {
      if (normalizedText == keyword ||
          normalizedText.endsWith(keyword) ||
          (normalizedText.length <= keyword.length + 2 && normalizedText.contains(keyword))) {
        return true;
      }
    }

    return false;
  }

  /// 处理语音结束命令
  ///
  /// 停止TTS播放，结束连续对话
  Future<void> _handleVoiceEndCommand() async {
    debugPrint('[GlobalVoiceAssistant] 处理语音结束命令');

    // 1. 立即停止TTS
    try {
      await _ttsService?.stop();
      debugPrint('[GlobalVoiceAssistant] TTS已停止');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 停止TTS失败: $e');
    }

    // 2. 清除处理中标志
    _isProcessingCommand = false;

    // 3. 使用LLM生成告别消息并播放
    final farewell = await LLMResponseGenerator.instance.generateFarewellResponse(
      farewellType: 'userEnd',
    );
    _addAssistantMessage(farewell);

    // 4. 播放告别语
    try {
      await _streamingTtsService?.speak(farewell);
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 播放告别语失败: $e');
    }

    // 5. 停止录音
    await stopRecording();

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

  /// 暂停ASR订阅（TTS播放期间避免回声）
  void _pauseASRSubscription() {
    if (_asrResultSubscription != null && !_asrResultSubscription!.isPaused) {
      debugPrint('[GlobalVoiceAssistant] 暂停ASR订阅（防止回声）');
      _asrResultSubscription!.pause();
    }
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

    // 归一化到0-1范围，并放大以便UI显示
    final avgAmplitude = sum / numSamples;
    // 放大振幅值（乘以3），使波浪更明显
    // 因为正常说话时的平均振幅通常在0.02-0.1之间
    _amplitude = ((avgAmplitude / 32768) * 3).clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 停止录音（手动触发）
  ///
  /// 停止流式语音处理，清理资源
  Future<void> stopRecording() async {
    debugPrint('[GlobalVoiceAssistant] stopRecording called (手动), state=$_ballState');
    if (_ballState != FloatingBallState.recording &&
        _ballState != FloatingBallState.processing) {
      debugPrint('[GlobalVoiceAssistant] 状态不是recording/processing，忽略');
      return;
    }

    try {
      // 停止连续对话模式
      _continuousMode = false;
      _shouldAutoRestart = false;
      _isRestartingASR = false;  // 重置重启标志
      _isProactiveConversation = false;  // 重置主动对话标志

      // 停止主动话题计时器
      _stopProactiveTimers();
      _consecutiveNoResponseCount = 0;

      // 流水线模式（当前唯一的语音处理模式）
      if (_pipelineController != null) {
        await _stopRecordingWithPipeline();
        return;
      }

      // 降级模式：流水线控制器未初始化时使用传统停止逻辑
      debugPrint('[GlobalVoiceAssistant] 警告: 使用降级模式停止录音');

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

    // 暂停ASR订阅，防止TTS回声被识别
    _pauseASRSubscription();

    // 启用打断检测模式（录音继续运行，VAD检测用户打断）
    _enableBargeInDetection();

    // 播放TTS（打断检测模式下，用户说话会触发打断）
    if (_streamingTtsService != null) {
      try {
        debugPrint('[GlobalVoiceAssistant] 主动对话TTS开始播放（支持打断）: $proactiveMessage');
        await _streamingTtsService!.speak(proactiveMessage);
        debugPrint('[GlobalVoiceAssistant] 主动对话TTS播放完成');
      } catch (e) {
        debugPrint('[GlobalVoiceAssistant] 主动对话TTS失败: $e');
      }
    }

    // 禁用打断检测模式
    _disableBargeInDetection();

    // 等待回声消散
    debugPrint('[GlobalVoiceAssistant] 主动对话TTS完成，等待回声消散...');
    await Future.delayed(const Duration(milliseconds: 1500));

    // 清除主动对话模式和处理中标志
    _isProactiveConversation = false;
    _isProcessingCommand = false;

    // TTS播放完成后，恢复或重启ASR继续监听
    if (_ballState == FloatingBallState.recording &&
        _audioStreamController != null &&
        !_audioStreamController!.isClosed) {
      debugPrint('[GlobalVoiceAssistant] TTS完成，重启ASR');
      _startStreamingASR();

      // 重启5秒主动话题计时器（30秒计时器继续运行）
      if (_continuousMode) {
        _proactiveTopicTimer?.cancel();
        _proactiveTopicTimer = Timer(
          Duration(milliseconds: _proactiveTopicTimeoutMs),
          _handleProactiveTopicTimeout,
        );
        debugPrint('[GlobalVoiceAssistant] 5秒主动话题计时器已重启');
      }
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

  /// 启动主动话题计时器（5秒）和强制结束计时器（30秒）
  ///
  /// 在TTS播放完成后或用户停止说话后调用
  void _startProactiveTimers() {
    // 先停止现有计时器
    _stopProactiveTimers();

    debugPrint('[GlobalVoiceAssistant] 启动主动话题计时器（5秒）和强制结束计时器（30秒）');

    // 5秒主动话题计时器
    _proactiveTopicTimer = Timer(
      Duration(milliseconds: _proactiveTopicTimeoutMs),
      _handleProactiveTopicTimeout,
    );

    // 30秒强制结束计时器
    _forceEndTimer = Timer(
      Duration(milliseconds: _forceEndTimeoutMs),
      _handleForceEndTimeout,
    );
  }

  /// 停止所有主动话题相关计时器
  void _stopProactiveTimers() {
    if (_proactiveTopicTimer != null) {
      _proactiveTopicTimer!.cancel();
      _proactiveTopicTimer = null;
      debugPrint('[GlobalVoiceAssistant] 5秒主动话题计时器已停止');
    }

    if (_forceEndTimer != null) {
      _forceEndTimer!.cancel();
      _forceEndTimer = null;
      debugPrint('[GlobalVoiceAssistant] 30秒强制结束计时器已停止');
    }
  }

  /// 处理5秒主动话题超时
  ///
  /// 用户5秒内没有说话，触发主动话题
  void _handleProactiveTopicTimeout() {
    debugPrint('[GlobalVoiceAssistant] 5秒静默超时，触发主动话题 (无响应计数: $_consecutiveNoResponseCount/$_maxConsecutiveNoResponse)');

    // 增加无响应计数
    _consecutiveNoResponseCount++;

    // 检查是否达到最大无响应次数
    if (_consecutiveNoResponseCount >= _maxConsecutiveNoResponse) {
      debugPrint('[GlobalVoiceAssistant] 连续$_maxConsecutiveNoResponse次无响应，结束对话');
      _handleForceEndTimeout();
      return;
    }

    // 触发主动话题（5秒计时器会在TTS播放完成后重启）
    final context = _contextService?.currentContext;
    _initiateProactiveConversation(context);
  }

  /// 处理30秒强制结束超时
  ///
  /// 用户30秒内没有任何响应，强制结束对话
  Future<void> _handleForceEndTimeout() async {
    debugPrint('[GlobalVoiceAssistant] 30秒静默超时，强制结束对话');

    // 停止所有计时器
    _stopProactiveTimers();

    // 重置无响应计数
    _consecutiveNoResponseCount = 0;

    // 使用LLM生成告别消息
    final farewell = await LLMResponseGenerator.instance.generateFarewellResponse(
      farewellType: 'sessionTimeout',
    );
    _addAssistantMessage(farewell);

    // 播放告别消息
    try {
      await _streamingTtsService?.speak(farewell);
      debugPrint('[GlobalVoiceAssistant] 告别消息播放完成');
    } catch (e) {
      debugPrint('[GlobalVoiceAssistant] 播放告别消息失败: $e');
    }

    // 停止录音并结束对话
    if (_ballState == FloatingBallState.recording) {
      stopRecording();
    }

    // 停止连续对话模式
    _continuousMode = false;
    _shouldAutoRestart = false;

    setBallState(FloatingBallState.idle);
    notifyListeners();
  }

  /// 用户开始说话时重置计时器和计数
  void _resetProactiveState() {
    debugPrint('[GlobalVoiceAssistant] 用户开始说话，重置主动话题状态');
    _stopProactiveTimers();
    _consecutiveNoResponseCount = 0;
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

  /// 临时用户消息的固定ID
  static const String _temporaryUserMessageId = '__temporary_user_message__';

  /// 更新或创建临时用户消息（用于实时显示ASR识别中的文字）
  void _updateOrCreateTemporaryUserMessage(String content) {
    if (content.trim().isEmpty) return;

    // 查找是否已存在临时消息
    final existingIndex = _conversationHistory.indexWhere(
      (msg) => msg.id == _temporaryUserMessageId,
    );

    if (existingIndex != -1) {
      // 更新现有临时消息
      _conversationHistory[existingIndex] = ChatMessage(
        id: _temporaryUserMessageId,
        type: ChatMessageType.user,
        content: content,
        timestamp: _conversationHistory[existingIndex].timestamp,
        isLoading: true, // 标记为临时消息
      );
    } else {
      // 创建新的临时消息
      _conversationHistory.add(ChatMessage(
        id: _temporaryUserMessageId,
        type: ChatMessageType.user,
        content: content,
        timestamp: DateTime.now(),
        isLoading: true, // 标记为临时消息
      ));
    }
  }

  /// 将临时用户消息转为正式消息
  void _finalizeTemporaryUserMessage(String content) {
    if (content.trim().isEmpty) return;

    // 移除临时消息
    _conversationHistory.removeWhere((msg) => msg.id == _temporaryUserMessageId);

    // 添加正式消息
    _addUserMessage(content);
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

  /// 更新最后一条助手消息的元数据
  ///
  /// 用于在查询操作异步完成后，更新消息的可视化数据（cardData, chartData等）
  void updateLastMessageMetadata(Map<String, dynamic> metadata) {
    final lastAssistantMessage = _findLastAssistantMessage();

    if (lastAssistantMessage != null) {
      // 创建新的消息对象（不可变模式）
      final updatedMessage = lastAssistantMessage.copyWith(
        metadata: {
          ...?lastAssistantMessage.metadata,
          ...metadata,
        },
      );

      // 替换消息
      final index = _conversationHistory.indexOf(lastAssistantMessage);
      _conversationHistory[index] = updatedMessage;

      // 通知 UI 更新
      notifyListeners();

      debugPrint('[GlobalVoiceAssistant] 已更新消息元数据: ${metadata.keys.join(", ")}');
    } else {
      debugPrint('[GlobalVoiceAssistant] 未找到助手消息，无法更新元数据');
    }
  }

  /// 查找最后一条助手消息
  ChatMessage? _findLastAssistantMessage() {
    for (int i = _conversationHistory.length - 1; i >= 0; i--) {
      if (_conversationHistory[i].type == ChatMessageType.assistant) {
        return _conversationHistory[i];
      }
    }
    return null;
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
    // 调试：追踪消息来源，打印调用堆栈
    debugPrint('[GlobalVoiceAssistant] 添加消息: type=${message.type}, content="${message.content}"');

    // 检查是否有重复消息（5秒内相同类型和内容的消息）
    final recentDuplicate = _conversationHistory.where((m) =>
        m.type == message.type &&
        m.content == message.content &&
        DateTime.now().difference(m.timestamp).inSeconds < 5).toList();
    if (recentDuplicate.isNotEmpty) {
      debugPrint('[GlobalVoiceAssistant] ⚠️ 检测到5秒内的重复消息，已阻止！');
      debugPrint('[GlobalVoiceAssistant] 已有消息时间: ${recentDuplicate.map((m) => m.timestamp).join(", ")}');
      return; // 阻止重复消息
    }

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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 用户偏好设置
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 设置是否喜欢主动对话
  ///
  /// 当设置为 false 时，除非有待通知的查询结果，否则系统不会主动发起对话
  void setLikesProactiveChat(bool value) {
    _userPreferencesProvider ??= SimpleUserPreferencesProvider();
    _userPreferencesProvider!.setLikesProactiveChat(value);
    debugPrint('[GlobalVoiceAssistant] 设置主动对话偏好: $value');
  }

  /// 设置对话风格
  ///
  /// 影响主动对话的话术风格：
  /// - professional: 专业简洁
  /// - playful: 活泼有趣
  /// - supportive: 温暖支持
  /// - casual: 随意轻松
  /// - neutral: 中性平衡
  void setDialogStyle(DialogStylePreference style) {
    _userPreferencesProvider ??= SimpleUserPreferencesProvider();
    _userPreferencesProvider!.setDialogStyle(style);
    debugPrint('[GlobalVoiceAssistant] 设置对话风格: $style');
  }

  /// 获取当前对话风格
  DialogStylePreference get dialogStyle {
    return _userPreferencesProvider?.getPreferences()?.dialogStyle
        ?? DialogStylePreference.neutral;
  }

  /// 获取是否喜欢主动对话
  bool get likesProactiveChat {
    return _userPreferencesProvider?.getPreferences()?.likesProactiveChat ?? true;
  }

  // ==================== 应用生命周期 ====================

  /// 应用进入后台时调用
  ///
  /// 暂停网络监控等后台任务，节省电量
  void onAppPaused() {
    debugPrint('[GlobalVoiceAssistant] 应用进入后台，暂停后台任务');
    _networkMonitor?.pause();
  }

  /// 应用回到前台时调用
  ///
  /// 恢复网络监控等后台任务
  void onAppResumed() {
    debugPrint('[GlobalVoiceAssistant] 应用回到前台，恢复后台任务');
    _networkMonitor?.resume();
  }

  @override
  void dispose() {
    // 清除回调，防止内存泄漏
    clearCallbacks();

    // 流水线相关
    _pipelineStateSubscription?.cancel();
    _pipelineController?.dispose();
    _streamingTtsService?.dispose();

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

    // 不释放 TTSService 单例 - 它是全局共享资源

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
