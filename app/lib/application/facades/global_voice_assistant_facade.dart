/// Global Voice Assistant Facade
///
/// 统一的语音助手入口点，封装了新的 Manager 架构。
/// 提供与原有 GlobalVoiceAssistantManager 兼容的接口，
/// 支持通过 FeatureFlags 在新旧实现之间切换。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/feature_flags.dart';
import '../managers/managers.dart';

/// 语音助手状态
enum VoiceAssistantState {
  /// 未初始化
  uninitialized,

  /// 空闲
  idle,

  /// 等待唤醒词
  awaitingWakeWord,

  /// 正在录音
  recording,

  /// 处理中
  processing,

  /// 播放响应
  responding,

  /// 错误
  error,
}

/// 语音助手事件
class VoiceAssistantEvent {
  final String type;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const VoiceAssistantEvent({
    required this.type,
    this.data,
    required this.timestamp,
  });

  factory VoiceAssistantEvent.stateChanged(VoiceAssistantState state) =>
      VoiceAssistantEvent(
        type: 'stateChanged',
        data: {'state': state.name},
        timestamp: DateTime.now(),
      );

  factory VoiceAssistantEvent.transcription(String text) =>
      VoiceAssistantEvent(
        type: 'transcription',
        data: {'text': text},
        timestamp: DateTime.now(),
      );

  factory VoiceAssistantEvent.response(String text) => VoiceAssistantEvent(
        type: 'response',
        data: {'text': text},
        timestamp: DateTime.now(),
      );

  factory VoiceAssistantEvent.error(String message) => VoiceAssistantEvent(
        type: 'error',
        data: {'message': message},
        timestamp: DateTime.now(),
      );
}

/// Global Voice Assistant Facade
///
/// 职责：
/// - 提供统一的语音助手入口
/// - 协调各个 Manager 的工作
/// - 管理语音助手的整体生命周期
/// - 支持新旧实现切换
class GlobalVoiceAssistantFacade extends ChangeNotifier {
  /// Feature Flags
  final FeatureFlags _featureFlags;

  /// 音频录制管理器
  final AudioRecordingManager _audioManager;

  /// VAD 管理器
  final VADManager _vadManager;

  /// 打断检测管理器
  final BargeInManager _bargeInManager;

  /// 对话历史管理器
  final ConversationHistoryManager _historyManager;

  /// TTS 管理器
  final TTSManager _ttsManager;

  /// 网络状态管理器
  final NetworkStatusManager _networkManager;

  /// 流水线管理器
  final PipelineManager _pipelineManager;

  /// 当前状态
  VoiceAssistantState _state = VoiceAssistantState.uninitialized;

  /// 事件流控制器
  final StreamController<VoiceAssistantEvent> _eventController =
      StreamController<VoiceAssistantEvent>.broadcast();

  /// 订阅
  final List<StreamSubscription> _subscriptions = [];

  /// 是否已初始化
  bool _isInitialized = false;

  GlobalVoiceAssistantFacade({
    required FeatureFlags featureFlags,
    required AudioRecordingManager audioManager,
    required VADManager vadManager,
    required BargeInManager bargeInManager,
    required ConversationHistoryManager historyManager,
    required TTSManager ttsManager,
    required NetworkStatusManager networkManager,
    required PipelineManager pipelineManager,
  })  : _featureFlags = featureFlags,
        _audioManager = audioManager,
        _vadManager = vadManager,
        _bargeInManager = bargeInManager,
        _historyManager = historyManager,
        _ttsManager = ttsManager,
        _networkManager = networkManager,
        _pipelineManager = pipelineManager;

  /// 当前状态
  VoiceAssistantState get state => _state;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在录音
  bool get isRecording => _audioManager.isRecording;

  /// 是否正在播放
  bool get isPlaying => _ttsManager.isPlaying;

  /// 是否在线
  bool get isOnline => _networkManager.isOnline;

  /// 事件流
  Stream<VoiceAssistantEvent> get events => _eventController.stream;

  /// 对话历史
  List<ChatMessage> get history => _historyManager.history;

  // ==================== 生命周期 ====================

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('[GlobalVoiceAssistantFacade] 开始初始化...');

    // 初始化各个管理器
    await _networkManager.initialize();
    await _historyManager.initialize();

    // 设置事件监听
    _setupEventListeners();

    _isInitialized = true;
    _updateState(VoiceAssistantState.idle);

    debugPrint('[GlobalVoiceAssistantFacade] 初始化完成');
  }

  /// 释放资源
  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _eventController.close();
    // Dispose child managers
    _audioManager.dispose();
    _vadManager.dispose();
    _bargeInManager.dispose();
    _historyManager.dispose();
    _ttsManager.dispose();
    _networkManager.dispose();
    _pipelineManager.dispose();
    super.dispose();
  }

  // ==================== 核心功能 ====================

  /// 开始监听（等待唤醒词或直接开始录音）
  Future<void> startListening({bool awaitWakeWord = false}) async {
    if (!_isInitialized) {
      debugPrint('[GlobalVoiceAssistantFacade] 未初始化，无法开始监听');
      return;
    }

    if (!_networkManager.isOnline) {
      _emitEvent(VoiceAssistantEvent.error('网络不可用'));
      return;
    }

    if (awaitWakeWord) {
      _updateState(VoiceAssistantState.awaitingWakeWord);
      await _pipelineManager.start(
        initialStage: PipelineStage.awaitingWakeWord,
      );
    } else {
      await startRecording();
    }
  }

  /// 开始录音
  Future<void> startRecording() async {
    if (!_isInitialized) return;

    final permissionStatus = await _audioManager.requestPermission();
    if (permissionStatus != MicrophonePermissionStatus.granted) {
      _emitEvent(VoiceAssistantEvent.error('没有麦克风权限'));
      return;
    }

    _updateState(VoiceAssistantState.recording);
    final started = await _audioManager.startRecording();
    if (started && _audioManager.audioStream != null) {
      _vadManager.startListening(_audioManager.audioStream!);
    }
  }

  /// 停止录音并处理
  Future<void> stopRecording() async {
    if (!isRecording) return;

    await _vadManager.stopListening();
    await _audioManager.stopRecording();

    _updateState(VoiceAssistantState.processing);
    // 实际处理将由外部协调器完成
    _emitEvent(VoiceAssistantEvent(
      type: 'audioReady',
      data: {},
      timestamp: DateTime.now(),
    ));
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    if (!isRecording) return;

    await _vadManager.stopListening();
    await _audioManager.stopRecording();
    _updateState(VoiceAssistantState.idle);
  }

  /// 播放响应
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    _updateState(VoiceAssistantState.responding);
    _historyManager.addAssistantMessage(text);
    _emitEvent(VoiceAssistantEvent.response(text));

    // 启用打断检测（如果有音频流）
    if (_audioManager.audioStream != null) {
      _bargeInManager.enable(_audioManager.audioStream!);
    }

    await _ttsManager.speak(text);

    _bargeInManager.disable();
    _updateState(VoiceAssistantState.idle);
  }

  /// 停止播放
  Future<void> stopSpeaking() async {
    await _ttsManager.stop();
    _bargeInManager.disable();
    _updateState(VoiceAssistantState.idle);
  }

  /// 添加用户消息
  void addUserMessage(String text) {
    _historyManager.addUserMessage(text);
    _emitEvent(VoiceAssistantEvent.transcription(text));
  }

  /// 清空对话历史
  void clearHistory() {
    _historyManager.clear();
  }

  // ==================== 状态查询 ====================

  /// 获取对话上下文摘要
  String getContextSummary({int maxMessages = 5}) {
    return _historyManager.getContextSummary(maxMessages: maxMessages);
  }

  /// 检查是否可以开始录音
  bool canStartRecording() {
    return _isInitialized &&
        _networkManager.isOnline &&
        !isRecording &&
        !isPlaying;
  }

  // ==================== 私有方法 ====================

  /// 设置事件监听
  void _setupEventListeners() {
    // 监听 VAD 事件
    _subscriptions.add(_vadManager.events.listen((event) {
      if (event.type == VADEventType.speechEnd && isRecording) {
        // 检测到语音结束，自动停止录音
        stopRecording();
      }
    }));

    // 监听打断事件
    _subscriptions.add(_bargeInManager.events.listen((event) {
      if (event.type == BargeInEventType.confirmed && isPlaying) {
        // 检测到打断并确认，停止播放并开始录音
        stopSpeaking().then((_) => startRecording());
      }
    }));

    // 监听网络状态
    _subscriptions.add(_networkManager.events.listen((event) {
      if (event.becameOffline) {
        _emitEvent(VoiceAssistantEvent.error('网络连接已断开'));
        if (isRecording) {
          cancelRecording();
        }
      }
    }));

    // 监听流水线事件
    _subscriptions.add(_pipelineManager.events.listen((event) {
      switch (event.type) {
        case PipelineEventType.stageChanged:
          _syncStateFromPipeline(event.stage);
          break;
        case PipelineEventType.error:
          _updateState(VoiceAssistantState.error);
          _emitEvent(VoiceAssistantEvent.error(event.message ?? '未知错误'));
          break;
        case PipelineEventType.completed:
          _updateState(VoiceAssistantState.idle);
          break;
        default:
          break;
      }
    }));
  }

  /// 从流水线同步状态
  void _syncStateFromPipeline(PipelineStage? stage) {
    if (stage == null) return;

    switch (stage) {
      case PipelineStage.idle:
        _updateState(VoiceAssistantState.idle);
        break;
      case PipelineStage.awaitingWakeWord:
        _updateState(VoiceAssistantState.awaitingWakeWord);
        break;
      case PipelineStage.recording:
      case PipelineStage.recognizing:
        _updateState(VoiceAssistantState.recording);
        break;
      case PipelineStage.processing:
      case PipelineStage.executing:
        _updateState(VoiceAssistantState.processing);
        break;
      case PipelineStage.responding:
      case PipelineStage.playing:
        _updateState(VoiceAssistantState.responding);
        break;
      case PipelineStage.error:
        _updateState(VoiceAssistantState.error);
        break;
      case PipelineStage.completed:
        _updateState(VoiceAssistantState.idle);
        break;
    }
  }

  /// 更新状态
  void _updateState(VoiceAssistantState newState) {
    if (_state != newState) {
      _state = newState;
      _emitEvent(VoiceAssistantEvent.stateChanged(newState));
      notifyListeners();
    }
  }

  /// 发送事件
  void _emitEvent(VoiceAssistantEvent event) {
    _eventController.add(event);
  }
}
