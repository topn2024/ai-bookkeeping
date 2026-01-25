import 'dart:async';
import 'package:flutter/foundation.dart';

import 'voice_state_machine.dart';
import 'agent/conversational_agent.dart';
import '../profile_driven_dialog_service.dart';
import '../user_profile_service.dart';
import 'memory/conversation_memory.dart' as memory;
import 'proactive_topic_generator.dart';
import 'conversation_end_detector.dart';
import 'voice_naturalness_service.dart';
import 'conversation_learning_service.dart';

/// 实时对话会话状态
///
/// 管理对话流程的状态机，实现自然流畅的语音交互
enum RealtimeSessionState {
  /// 空闲 - 等待用户点击悬浮球开始对话
  idle,

  /// 监听中 - 等待用户开始说话
  listening,

  /// 用户说话中 - VAD检测到语音活动
  userSpeaking,

  /// 思考中 - 用户说完，智能体处理中
  thinkingAfterUser,

  /// 智能体说话中 - TTS播放响应
  agentSpeaking,

  /// 轮次结束停顿 - 等待用户可能的响应（1.5秒）
  turnEndPause,

  /// 等待用户输入 - 停顿期过后仍等待用户
  waitingForInput,

  /// 主动发起话题 - 用户沉默超过5秒，智能体主动说话
  proactive,

  /// 对话结束中 - 检测到结束意图，准备关闭
  ending,

  /// 已结束 - 对话完全关闭
  ended,
}

/// 对话轮次
class ConversationTurn {
  /// 用户输入
  final String userInput;

  /// 智能体响应
  final String agentResponse;

  /// 关联的操作（如果有）
  final AgentResponse? actionResult;

  /// 时间戳
  final DateTime timestamp;

  const ConversationTurn({
    required this.userInput,
    required this.agentResponse,
    this.actionResult,
    required this.timestamp,
  });
}

/// 实时对话会话配置
class RealtimeSessionConfig {
  /// VAD静音判定阈值（毫秒）
  final int vadSilenceThresholdMs;

  /// 轮次结束停顿时间（毫秒）
  final int turnEndPauseMs;

  /// 等待用户输入超时（毫秒）
  final int waitingForInputTimeoutMs;

  /// 主动话题超时（毫秒）
  final int proactiveTimeoutMs;

  /// 最大对话轮次（短期记忆）
  final int maxTurnsInMemory;

  /// 结束对话前等待时间（毫秒）
  final int endingDelayMs;

  const RealtimeSessionConfig({
    this.vadSilenceThresholdMs = 500,
    this.turnEndPauseMs = 1500,
    this.waitingForInputTimeoutMs = 3500,
    this.proactiveTimeoutMs = 5000,
    this.maxTurnsInMemory = 5,
    this.endingDelayMs = 1000,
  });

  static const defaultConfig = RealtimeSessionConfig();
}

/// 实时对话会话
///
/// 管理整个对话流程，包括：
/// - 状态流转控制
/// - 语音输入/输出时机
/// - 主动发起话题
/// - 对话结束检测
/// - 短期记忆管理
/// - 用户画像驱动的个性化对话
class RealtimeConversationSession {
  /// 配置
  final RealtimeSessionConfig config;

  /// 底层状态机
  final VoiceStateMachine _stateMachine;

  /// 对话智能体
  final ConversationalAgent _agent;

  /// 用户ID
  final String? _userId;

  /// 画像驱动对话服务（可选）
  final ProfileDrivenDialogService? _dialogService;

  /// 对话记忆
  final memory.ConversationMemory _conversationMemory;

  /// 主动话题生成器
  final ProactiveTopicGenerator _topicGenerator;

  /// 对话结束检测器
  final ConversationEndDetector _endDetector;

  /// 语音自然度服务
  final VoiceNaturalnessService _naturalnessService;

  /// 对话学习服务
  final ConversationLearningService _learningService;

  /// 用户画像（会话期间缓存）
  UserProfile? _userProfile;

  /// LLM系统提示词（基于画像生成）
  String? _systemPrompt;

  /// 当前会话状态
  RealtimeSessionState _sessionState = RealtimeSessionState.idle;

  /// 对话历史（短期记忆）
  final List<ConversationTurn> _conversationHistory = [];

  /// 状态变化流
  final _stateController = StreamController<RealtimeSessionState>.broadcast();

  /// 响应文本流（供TTS使用）
  final _responseTextController = StreamController<String>.broadcast();

  /// 操作请求流（供执行层使用）
  final _actionRequestController = StreamController<AgentResponse>.broadcast();

  /// 主动话题流
  final _proactiveTopicController = StreamController<String>.broadcast();

  /// 各种定时器
  Timer? _turnEndPauseTimer;
  Timer? _waitingForInputTimer;
  Timer? _proactiveTimer;
  Timer? _endingTimer;

  /// 底层状态机事件订阅
  StreamSubscription? _stateMachineSubscription;

  /// 是否已初始化
  bool _initialized = false;

  /// 待处理的执行结果
  final List<AgentResponse> _pendingResults = [];

  RealtimeConversationSession({
    this.config = RealtimeSessionConfig.defaultConfig,
    VoiceStateMachine? stateMachine,
    ConversationalAgent? agent,
    String? userId,
    ProfileDrivenDialogService? dialogService,
    memory.ConversationMemory? conversationMemory,
    ProactiveTopicGenerator? topicGenerator,
    ConversationEndDetector? endDetector,
    VoiceNaturalnessService? naturalnessService,
    ConversationLearningService? learningService,
  })  : _stateMachine = stateMachine ?? VoiceStateMachine(),
        _agent = agent ?? ConversationalAgent(),
        _userId = userId,
        _dialogService = dialogService,
        _conversationMemory = conversationMemory ?? memory.ConversationMemory(),
        _topicGenerator = topicGenerator ?? ProactiveTopicGenerator(),
        _endDetector = endDetector ?? ConversationEndDetector(),
        _naturalnessService = naturalnessService ?? VoiceNaturalnessService(),
        _learningService = learningService ?? ConversationLearningService();

  // ==================== 公共API ====================

  /// 获取当前会话状态
  RealtimeSessionState get state => _sessionState;

  /// 状态变化流
  Stream<RealtimeSessionState> get stateStream => _stateController.stream;

  /// 响应文本流（供TTS使用）
  Stream<String> get responseTextStream => _responseTextController.stream;

  /// 操作请求流（供执行层使用）
  Stream<AgentResponse> get actionRequestStream =>
      _actionRequestController.stream;

  /// 主动话题流
  Stream<String> get proactiveTopicStream => _proactiveTopicController.stream;

  /// 对话历史
  List<ConversationTurn> get conversationHistory =>
      List.unmodifiable(_conversationHistory);

  /// 底层状态机
  VoiceStateMachine get stateMachine => _stateMachine;

  /// 对话智能体
  ConversationalAgent get agent => _agent;

  /// 是否处于活跃对话中
  bool get isActive =>
      _sessionState != RealtimeSessionState.idle &&
      _sessionState != RealtimeSessionState.ended;

  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;

    await _agent.initialize();

    // 监听底层状态机事件
    _stateMachineSubscription = _stateMachine.eventStream.listen(_handleStateMachineEvent);

    // 启用全双工模式
    _stateMachine.enableFullDuplexMode();

    // 加载用户画像和生成个性化系统提示词
    await _loadUserProfile();

    _initialized = true;
    debugPrint('[RealtimeSession] 初始化完成');
  }

  /// 加载用户画像
  Future<void> _loadUserProfile() async {
    if (_dialogService == null || _userId == null) return;

    try {
      // 获取个性化系统提示词
      _systemPrompt = await _dialogService.getSystemPrompt(_userId);
      debugPrint('[RealtimeSession] 已加载用户画像，系统提示词已生成');
    } catch (e) {
      debugPrint('[RealtimeSession] 加载用户画像失败: $e');
    }
  }

  /// 开始对话
  ///
  /// 用户点击悬浮球时调用
  Future<void> startConversation() async {
    if (!_initialized) {
      await initialize();
    }

    if (_sessionState != RealtimeSessionState.idle &&
        _sessionState != RealtimeSessionState.ended) {
      debugPrint('[RealtimeSession] 会话已在进行中');
      return;
    }

    // 重置状态
    _clearTimers();
    _conversationHistory.clear();
    _pendingResults.clear();
    _conversationMemory.clear();
    _endDetector.reset();
    _topicGenerator.clearPendingFeedbacks();

    // 启动底层状态机
    _stateMachine.startSession();
    _stateMachine.startListening();

    // 更新状态
    _setState(RealtimeSessionState.listening);

    // 智能体开始新会话
    _agent.startSession();

    debugPrint('[RealtimeSession] 对话开始');
  }

  /// 用户开始说话
  ///
  /// VAD检测到语音活动时调用
  void onUserSpeechStart() {
    if (!isActive) return;

    // 取消所有等待定时器
    _cancelWaitingTimers();

    // 如果智能体正在说话，触发打断
    if (_sessionState == RealtimeSessionState.agentSpeaking) {
      _stateMachine.requestInterrupt();
    }

    _setState(RealtimeSessionState.userSpeaking);
    debugPrint('[RealtimeSession] 用户开始说话');
  }

  /// 用户说话结束
  ///
  /// VAD检测到静音超过阈值时调用
  /// [transcribedText] ASR识别的文本
  Future<void> onUserSpeechEnd(String transcribedText) async {
    if (!isActive) return;

    _setState(RealtimeSessionState.thinkingAfterUser);
    debugPrint('[RealtimeSession] 用户说完: $transcribedText');

    // 使用对话结束检测器检查结束意图
    final endResult = _endDetector.detectEndIntent(transcribedText);
    if (endResult.shouldEnd) {
      debugPrint('[RealtimeSession] 检测到结束意图: ${endResult.keyword}');
      // 使用自然度服务生成多样化的结束语
      _emitResponseText(endResult.suggestedResponse ?? _naturalnessService.getGoodbyeResponse());
      _startAgentSpeaking();
      // 等待响应播放完成后再结束
      _endingTimer = Timer(Duration(milliseconds: config.endingDelayMs + 1500), () {
        _closeSession();
      });
      return;
    }

    // 检查是否是操作指代（如"改成50"、"删掉它"）
    final actionRef = _conversationMemory.resolveActionReference(transcribedText);
    if (actionRef != null) {
      debugPrint('[RealtimeSession] 检测到操作指代: ${actionRef.type}');
      // TODO: 处理操作指代
    }

    // 处理用户输入
    try {
      final response = await _agent.process(UserInput.fromVoice(transcribedText));
      await _handleAgentResponse(response, transcribedText);
    } catch (e) {
      debugPrint('[RealtimeSession] 处理用户输入异常: $e');
      _emitResponseText(_naturalnessService.getUnclearResponse());
      _startAgentSpeaking();
    }
  }

  /// 智能体说话完成
  ///
  /// TTS播放完成时调用
  void onAgentSpeechEnd() {
    if (_sessionState != RealtimeSessionState.agentSpeaking) return;

    debugPrint('[RealtimeSession] 智能体说完');

    // 进入轮次结束停顿
    _setState(RealtimeSessionState.turnEndPause);
    _startTurnEndPauseTimer();
  }

  /// 注入执行结果
  ///
  /// 执行层完成操作后调用
  void injectExecutionResult(AgentResponse result) {
    _pendingResults.add(result);
    debugPrint('[RealtimeSession] 收到执行结果: ${result.text}');

    // 如果当前处于等待状态，可以主动告知用户
    if (_sessionState == RealtimeSessionState.waitingForInput ||
        _sessionState == RealtimeSessionState.turnEndPause) {
      _handlePendingResult();
    }
  }

  /// 结束对话
  ///
  /// 主动结束对话
  Future<void> endConversation() async {
    if (!isActive) return;

    _setState(RealtimeSessionState.ending);
    _emitResponseText(_naturalnessService.getGoodbyeResponse());

    // 等待后关闭
    _endingTimer = Timer(Duration(milliseconds: config.endingDelayMs), () {
      _closeSession();
    });
  }

  /// 释放资源
  void dispose() {
    _clearTimers();
    _stateMachineSubscription?.cancel();
    _stateMachine.dispose();
    _agent.dispose();
    _stateController.close();
    _responseTextController.close();
    _actionRequestController.close();
    _proactiveTopicController.close();
  }

  // ==================== 内部方法 ====================

  /// 处理底层状态机事件
  void _handleStateMachineEvent(VoiceStateEvent event) {
    debugPrint('[RealtimeSession] 状态机事件: $event');

    switch (event) {
      case VoiceStateEvent.interruptRequested:
        _handleInterrupt();
        break;
      case VoiceStateEvent.sessionEnded:
        _closeSession();
        break;
      default:
        break;
    }
  }

  /// 处理打断
  void _handleInterrupt() {
    // 取消当前智能体响应
    _cancelWaitingTimers();

    // 切换到用户说话状态
    _setState(RealtimeSessionState.userSpeaking);
    debugPrint('[RealtimeSession] 打断处理完成');
  }

  /// 处理智能体响应
  Future<void> _handleAgentResponse(
    AgentResponse response,
    String userInput,
  ) async {
    // 创建语音操作（如果有）
    memory.VoiceAction? voiceAction;
    if (response.actionResult != null && response.actionResult!.success) {
      voiceAction = memory.VoiceAction(
        type: response.actionResult!.actionId ?? 'unknown',
        data: {'text': userInput},
        result: memory.ActionResult(
          success: response.actionResult!.success,
          recordId: response.actionResult!.actionId,
          message: response.actionResult!.responseText,
        ),
        timestamp: DateTime.now(),
      );
    }

    // 记录到对话记忆
    _conversationMemory.addTurn(
      userInput: userInput,
      agentResponse: response.text,
      action: voiceAction,
    );

    // 记录对话历史
    _addToHistory(userInput, response.text, response);

    // 如果有操作需要执行，发送到执行层并添加待反馈
    if (response.actionResult != null && response.actionResult!.success) {
      _actionRequestController.add(response);

      // 添加执行结果反馈
      _topicGenerator.addPendingFeedback(PendingFeedback(
        type: FeedbackType.bookkeepingSuccess,
        data: {'text': userInput},
      ));
    }

    // 发送响应文本供TTS播放
    _emitResponseText(response.text);

    // 开始智能体说话
    _startAgentSpeaking();
  }

  /// 开始智能体说话状态
  void _startAgentSpeaking() {
    _setState(RealtimeSessionState.agentSpeaking);
    _stateMachine.startSpeaking();
  }

  /// 启动轮次结束停顿定时器
  void _startTurnEndPauseTimer() {
    _turnEndPauseTimer?.cancel();
    _turnEndPauseTimer = Timer(
      Duration(milliseconds: config.turnEndPauseMs),
      _onTurnEndPauseTimeout,
    );
  }

  /// 轮次结束停顿超时
  void _onTurnEndPauseTimeout() {
    if (_sessionState != RealtimeSessionState.turnEndPause) return;

    // 进入等待用户输入状态
    _setState(RealtimeSessionState.waitingForInput);
    _startWaitingForInputTimer();
  }

  /// 启动等待用户输入定时器
  void _startWaitingForInputTimer() {
    _waitingForInputTimer?.cancel();
    _waitingForInputTimer = Timer(
      Duration(milliseconds: config.waitingForInputTimeoutMs),
      _onWaitingForInputTimeout,
    );
  }

  /// 等待用户输入超时
  void _onWaitingForInputTimeout() {
    if (_sessionState != RealtimeSessionState.waitingForInput) return;

    // 进入主动发起话题状态
    _setState(RealtimeSessionState.proactive);
    _startProactiveTimer();
    _generateProactiveTopic();
  }

  /// 启动主动话题定时器
  void _startProactiveTimer() {
    _proactiveTimer?.cancel();
    _proactiveTimer = Timer(
      Duration(milliseconds: config.proactiveTimeoutMs),
      _onProactiveTimeout,
    );
  }

  /// 主动话题超时（用户仍无响应，结束对话）
  void _onProactiveTimeout() {
    if (_sessionState != RealtimeSessionState.proactive) return;

    // 用户长时间无响应，优雅结束
    endConversation();
  }

  /// 生成主动话题
  Future<void> _generateProactiveTopic() async {
    // 检查是否有待处理的执行结果
    if (_pendingResults.isNotEmpty) {
      _handlePendingResult();
      return;
    }

    // 生成引导性话题
    final topic = await _selectProactiveTopic();
    _proactiveTopicController.add(topic);
    _emitResponseText(topic);
    _startAgentSpeaking();
  }

  /// 选择主动话题
  Future<String> _selectProactiveTopic() async {
    // 使用主动话题生成器
    final topic = await _topicGenerator.generateTopic(
      memory: _conversationMemory,
      timeContext: TimeContext.now(),
    );

    if (topic != null) {
      return _naturalnessService.addNaturalTone(
        topic.text,
        NaturalToneType.agreeing,
      );
    }

    // 降级到简单逻辑，使用自然度服务
    if (_conversationHistory.isEmpty) {
      return _naturalnessService.getGreetingResponse();
    }

    // 检查最近的对话
    final lastTurn = _conversationHistory.last;
    if (lastTurn.actionResult?.actionResult?.success == true) {
      return _naturalnessService.getContinueResponse();
    }

    return _naturalnessService.getContinueResponse();
  }

  /// 处理待处理的执行结果
  void _handlePendingResult() {
    if (_pendingResults.isEmpty) return;

    final result = _pendingResults.removeAt(0);
    final feedbackText = _generateResultFeedback(result);
    _emitResponseText(feedbackText);
    _startAgentSpeaking();
  }

  /// 生成执行结果反馈
  String _generateResultFeedback(AgentResponse result) {
    if (result.actionResult?.success == true) {
      return '刚才那笔已经记好了';
    }
    return result.text;
  }

  /// 关闭会话
  void _closeSession() {
    _clearTimers();
    _stateMachine.endSession();
    _agent.endSession();

    // 从整个会话学习
    _learnFromSession();

    _setState(RealtimeSessionState.ended);
    debugPrint('[RealtimeSession] 对话结束');
  }

  /// 从会话学习
  Future<void> _learnFromSession() async {
    if (_conversationHistory.isEmpty) return;

    // 转换为学习服务需要的格式
    final turns = _conversationHistory.asMap().entries.map((entry) {
      final index = entry.key;
      final turn = entry.value;

      memory.VoiceAction? voiceAction;
      if (turn.actionResult?.actionResult != null) {
        voiceAction = memory.VoiceAction(
          type: turn.actionResult!.actionResult!.actionId ?? 'unknown',
          data: {'text': turn.userInput},
          result: memory.ActionResult(
            success: turn.actionResult!.actionResult!.success,
            message: turn.actionResult!.actionResult!.responseText,
          ),
          timestamp: turn.timestamp,
        );
      }
      return memory.ConversationTurn(
        id: 'turn_$index',
        userInput: turn.userInput,
        agentResponse: turn.agentResponse,
        action: voiceAction,
        timestamp: turn.timestamp,
        isCompleted: true,
      );
    }).toList();

    await _learningService.learnFromSession(turns);

    // 如果有用户ID，持久化学习结果
    if (_userId != null) {
      await _learningService.persistLearning(_userId);
    }
  }

  /// 添加到对话历史
  void _addToHistory(String userInput, String agentResponse, AgentResponse? result) {
    _conversationHistory.add(ConversationTurn(
      userInput: userInput,
      agentResponse: agentResponse,
      actionResult: result,
      timestamp: DateTime.now(),
    ));

    // 保持短期记忆在限制范围内
    while (_conversationHistory.length > config.maxTurnsInMemory) {
      _conversationHistory.removeAt(0);
    }
  }

  /// 发送响应文本
  void _emitResponseText(String text) {
    _responseTextController.add(text);
  }

  /// 设置状态
  void _setState(RealtimeSessionState newState) {
    if (_sessionState != newState) {
      debugPrint('[RealtimeSession] 状态变化: $_sessionState -> $newState');
      _sessionState = newState;
      _stateController.add(newState);
    }
  }

  /// 取消等待定时器
  void _cancelWaitingTimers() {
    _turnEndPauseTimer?.cancel();
    _waitingForInputTimer?.cancel();
    _proactiveTimer?.cancel();
  }

  /// 清除所有定时器
  void _clearTimers() {
    _cancelWaitingTimers();
    _endingTimer?.cancel();
  }

  /// 获取上下文摘要（供LLM使用）
  String getContextForLLM() {
    if (_conversationHistory.isEmpty) return '';

    final buffer = StringBuffer();
    for (final turn in _conversationHistory) {
      buffer.writeln('用户: ${turn.userInput}');
      buffer.writeln('助手: ${turn.agentResponse}');
    }
    return buffer.toString();
  }
}
