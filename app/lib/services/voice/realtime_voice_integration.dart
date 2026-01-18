import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'realtime_conversation_session.dart';
import 'conversation_action_bridge.dart';
import 'background_operation_executor.dart';
import 'agent/conversational_agent.dart';
import 'agent/action_registry.dart';
import 'exception_handler.dart';
import 'frequency_limiter.dart';
import 'interrupt_recovery_manager.dart';
import 'realtime_vad_config.dart';
import 'voice_naturalness_service.dart';

/// 实时语音集成服务
///
/// 将所有实时语音组件整合，提供统一的API供悬浮球组件使用
///
/// 职责：
/// - 初始化和管理所有实时语音相关组件
/// - 提供简化的API给UI层
/// - 协调各组件之间的交互
/// - 处理生命周期事件
class RealtimeVoiceIntegration {
  /// 实时对话会话
  late final RealtimeConversationSession _session;

  /// 对话-执行桥接器
  late final ConversationActionBridge _actionBridge;

  /// 后台操作执行器
  late final BackgroundOperationExecutor _operationExecutor;

  /// 异常处理器
  late final VoiceExceptionHandler _exceptionHandler;

  /// 频率限制器
  late final FrequencyLimiter _frequencyLimiter;

  /// 中断恢复管理器
  late final InterruptRecoveryManager _recoveryManager;

  /// 实时VAD服务
  late final RealtimeVADService _vadService;

  /// 语音自然度服务
  late final VoiceNaturalnessService _naturalnessService;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 状态变更流
  final _stateController = StreamController<RealtimeVoiceState>.broadcast();

  /// 消息流（用于UI显示）
  final _messageController = StreamController<VoiceMessage>.broadcast();

  /// 操作结果流
  final _resultController = StreamController<OperationResult>.broadcast();

  // ==================== 公共API ====================

  /// 状态变更流
  Stream<RealtimeVoiceState> get stateStream => _stateController.stream;

  /// 消息流
  Stream<VoiceMessage> get messageStream => _messageController.stream;

  /// 操作结果流
  Stream<OperationResult> get resultStream => _resultController.stream;

  /// 当前会话状态
  RealtimeSessionState get sessionState =>
      _isInitialized ? _session.state : RealtimeSessionState.idle;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否有待处理操作
  bool get hasPendingOperations =>
      _isInitialized && _operationExecutor.hasPendingOperations;

  /// 初始化
  Future<void> initialize({
    RealtimeVADConfig? vadConfig,
    RealtimeSessionConfig? sessionConfig,
  }) async {
    if (_isInitialized) return;

    debugPrint('[RealtimeVoiceIntegration] 初始化中...');

    // 创建组件
    _vadService = RealtimeVADService(config: vadConfig);
    _exceptionHandler = VoiceExceptionHandler();
    _frequencyLimiter = FrequencyLimiter();
    _recoveryManager = InterruptRecoveryManager();
    _actionBridge = ConversationActionBridge();
    _operationExecutor = BackgroundOperationExecutor();
    _naturalnessService = VoiceNaturalnessService();
    _session = RealtimeConversationSession(
      config: sessionConfig ?? RealtimeSessionConfig.defaultConfig,
      naturalnessService: _naturalnessService,
    );

    // 设置监听
    _setupListeners();

    _isInitialized = true;
    debugPrint('[RealtimeVoiceIntegration] 初始化完成');
  }

  /// 开始语音会话
  ///
  /// 用户点击悬浮球时调用
  Future<void> startSession() async {
    if (!_isInitialized) {
      await initialize();
    }

    // 检查是否有可恢复的上下文
    final recoveryAction = _recoveryManager.checkDialogResume();
    if (recoveryAction != null) {
      _handleRecoveryAction(recoveryAction);
      return;
    }

    // 开始新会话
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    await _session.startConversation();
    _actionBridge.startSession(sessionId);
    _operationExecutor.startSession(sessionId);

    _emitState(RealtimeVoiceState.listening);
    _emitMessage(VoiceMessage.system(_naturalnessService.getGreetingResponse()));
  }

  /// 结束语音会话
  ///
  /// 用户再次点击悬浮球或系统检测到结束意图时调用
  Future<void> endSession() async {
    if (!_isInitialized) return;

    await _session.endConversation();
    _actionBridge.endSession();
    _operationExecutor.endSession();

    _emitState(RealtimeVoiceState.idle);
  }

  /// 处理用户语音输入
  ///
  /// 当ASR返回识别结果时调用
  Future<void> processUserInput(String text) async {
    if (!_isInitialized) return;

    // 如果会话正在结束或已结束，忽略用户输入
    if (_session.state == RealtimeSessionState.ending ||
        _session.state == RealtimeSessionState.ended) {
      debugPrint('[RealtimeVoiceIntegration] 会话结束中，忽略用户输入: $text');
      return;
    }

    debugPrint('[RealtimeVoiceIntegration] 处理用户输入: $text');

    // 频率检查
    final freqCheck = _frequencyLimiter.checkAll(text);
    if (!freqCheck.isOk) {
      _emitMessage(VoiceMessage.assistant(freqCheck.response ?? ''));
      return;
    }

    // 标记用户已响应
    _recoveryManager.markUserResponded();

    // 显示用户消息
    _emitMessage(VoiceMessage.user(text));

    // 处理输入
    try {
      await _session.onUserSpeechEnd(text);
      // 响应通过 responseTextStream 流获取，已在 _setupListeners 中设置监听
    } on ASRException catch (e) {
      final response = _exceptionHandler.handleASRException(e);
      _emitMessage(VoiceMessage.assistant(response.text));
    } on NLUException catch (e) {
      final response = _exceptionHandler.handleNLUException(e);
      _emitMessage(VoiceMessage.assistant(response.text));
    } on OperationException catch (e) {
      final response = _exceptionHandler.handleOperationException(e);
      _emitMessage(VoiceMessage.assistant(response.text));
    }
  }

  /// 处理应用生命周期变化
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.paused) {
      _recoveryManager.handleAppBackgrounded();
      // 会话状态由 recoveryManager 管理，不需要显式暂停
    } else if (state == AppLifecycleState.resumed) {
      final recoveryAction = _recoveryManager.handleAppResumed();
      if (recoveryAction != null) {
        _handleRecoveryAction(recoveryAction);
      }
    }
  }

  /// 确认恢复上下文
  void confirmResume() {
    _recoveryManager.confirmResume();
  }

  /// 拒绝恢复上下文
  void declineResume() {
    _recoveryManager.declineResume();
  }

  /// 释放资源
  void dispose() {
    _session.dispose();
    _actionBridge.dispose();
    _operationExecutor.dispose();
    _vadService.dispose();
    _recoveryManager.dispose();
    _stateController.close();
    _messageController.close();
    _resultController.close();
  }

  // ==================== 内部方法 ====================

  /// 设置监听
  void _setupListeners() {
    // 监听会话状态变化
    _session.stateStream.listen((state) {
      _emitState(_mapSessionStateToVoiceState(state));
    });

    // 监听会话响应文本
    _session.responseTextStream.listen((message) {
      _emitMessage(VoiceMessage.assistant(message));
    });

    // 监听操作执行结果
    _operationExecutor.resultStream.listen((result) {
      _resultController.add(result);
      // 如果用户仍在会话中，反馈执行结果
      if (_session.state != RealtimeSessionState.ended) {
        // 将 OperationResult 转换为 AgentResponse 以便注入会话上下文
        final agentResponse = AgentResponse(
          text: result.success ? result.description : (result.error ?? '操作失败'),
          type: result.success ? AgentResponseType.action : AgentResponseType.error,
          actionResult: ActionResult(
            success: result.success,
            data: result.data,
            error: result.error,
            responseText: result.description,
            actionId: result.operationType,
          ),
        );
        _session.injectExecutionResult(agentResponse);
      }
    });

    // 监听VAD事件
    _vadService.eventStream.listen((event) {
      _handleVADEvent(event);
    });

    // 监听中断恢复的放弃检测
    // 当会话需要追问时启动放弃检测
  }

  /// 处理VAD事件
  void _handleVADEvent(VADEvent event) {
    // 如果会话正在结束或已结束，忽略 VAD 事件
    if (_session.state == RealtimeSessionState.ending ||
        _session.state == RealtimeSessionState.ended) {
      debugPrint('[RealtimeVoiceIntegration] 会话结束中，忽略VAD事件: ${event.type}');
      return;
    }

    switch (event.type) {
      case VADEventType.speechStart:
        _session.onUserSpeechStart();
        _emitState(RealtimeVoiceState.userSpeaking);
        break;

      case VADEventType.speechEnd:
        // VAD检测到语音结束，等待ASR返回识别结果
        // 实际的onUserSpeechEnd调用在processUserInput中
        _emitState(RealtimeVoiceState.thinking);
        break;

      case VADEventType.turnEndPauseTimeout:
        // 轮次结束停顿超时由 session 内部定时器处理
        _session.onAgentSpeechEnd();
        break;

      case VADEventType.silenceTimeout:
        // 静音超时由 session 内部定时器处理
        break;

      default:
        break;
    }
  }

  /// 处理恢复动作
  void _handleRecoveryAction(RecoveryAction action) {
    switch (action.type) {
      case RecoveryActionType.resume:
        _emitMessage(VoiceMessage.assistant(action.promptText ?? ''));
        // 恢复会话 - 如果会话未活跃则重新开始
        if (!_session.isActive) {
          _session.startConversation();
        }
        _emitState(RealtimeVoiceState.listening);
        break;

      case RecoveryActionType.lightPrompt:
        _emitMessage(VoiceMessage.system(action.promptText ?? ''));
        break;

      case RecoveryActionType.askResume:
        _emitMessage(VoiceMessage.assistant(action.promptText ?? ''));
        _emitState(RealtimeVoiceState.waitingConfirm);
        break;

      case RecoveryActionType.reset:
        startSession();
        break;

      case RecoveryActionType.saved:
        break;
    }
  }

  /// 映射会话状态到语音状态
  RealtimeVoiceState _mapSessionStateToVoiceState(RealtimeSessionState state) {
    switch (state) {
      case RealtimeSessionState.idle:
        return RealtimeVoiceState.idle;
      case RealtimeSessionState.listening:
        return RealtimeVoiceState.listening;
      case RealtimeSessionState.userSpeaking:
        return RealtimeVoiceState.userSpeaking;
      case RealtimeSessionState.thinkingAfterUser:
        return RealtimeVoiceState.thinking;
      case RealtimeSessionState.agentSpeaking:
        return RealtimeVoiceState.agentSpeaking;
      case RealtimeSessionState.turnEndPause:
        return RealtimeVoiceState.listening;
      case RealtimeSessionState.waitingForInput:
        return RealtimeVoiceState.listening;
      case RealtimeSessionState.proactive:
        return RealtimeVoiceState.agentSpeaking;
      case RealtimeSessionState.ending:
        return RealtimeVoiceState.ending;
      case RealtimeSessionState.ended:
        return RealtimeVoiceState.idle;
    }
  }

  /// 发送状态
  void _emitState(RealtimeVoiceState state) {
    _stateController.add(state);
  }

  /// 发送消息
  void _emitMessage(VoiceMessage message) {
    _messageController.add(message);
  }
}

/// 实时语音状态（简化版，供UI使用）
enum RealtimeVoiceState {
  /// 空闲
  idle,

  /// 监听中
  listening,

  /// 用户说话中
  userSpeaking,

  /// 思考中
  thinking,

  /// 智能体说话中
  agentSpeaking,

  /// 等待用户确认
  waitingConfirm,

  /// 结束中
  ending,
}

/// 语音消息
class VoiceMessage {
  /// 消息类型
  final VoiceMessageType type;

  /// 消息文本
  final String text;

  /// 时间戳
  final DateTime timestamp;

  const VoiceMessage._({
    required this.type,
    required this.text,
    required this.timestamp,
  });

  factory VoiceMessage.user(String text) => VoiceMessage._(
        type: VoiceMessageType.user,
        text: text,
        timestamp: DateTime.now(),
      );

  factory VoiceMessage.assistant(String text) => VoiceMessage._(
        type: VoiceMessageType.assistant,
        text: text,
        timestamp: DateTime.now(),
      );

  factory VoiceMessage.system(String text) => VoiceMessage._(
        type: VoiceMessageType.system,
        text: text,
        timestamp: DateTime.now(),
      );
}

/// 消息类型
enum VoiceMessageType {
  user,
  assistant,
  system,
}
