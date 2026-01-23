/// 对话式智能体核心
///
/// 统一协调各组件，实现"边聊边做"的智能交互体验
///
/// 核心能力：
/// - 自然语言理解（LLM优先，规则兜底）
/// - 聊天与功能智能路由
/// - 行为执行与参数补全
/// - 上下文感知与指代消解
/// - 自然语言响应生成
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../models/transaction.dart' as model;
import 'action_registry.dart';
import 'action_executor.dart';
import 'action_router.dart';
import 'hybrid_intent_router.dart';
import 'llm_intent_classifier.dart';
import 'chat_engine.dart';
import 'context_manager.dart';
import 'decomposed_intent.dart';
import 'background_task_queue.dart';
import '../conversation_context.dart';
import '../action_feedback_service.dart';
import '../emotional_response_service.dart';
import '../barge_in_detector.dart';
import '../self_learning_service.dart';
import '../knowledge_base_service.dart';
import '../voice_naturalness_service.dart';

/// 智能体响应
class AgentResponse {
  /// 响应文本
  final String text;

  /// 响应类型
  final AgentResponseType type;

  /// 是否应该语音输出
  final bool shouldSpeak;

  /// 附带数据
  final Map<String, dynamic>? data;

  /// 行为执行结果
  final ActionResult? actionResult;

  /// 是否需要用户跟进
  final bool needsFollowUp;

  /// 跟进提示
  final String? followUpPrompt;

  /// 情感标签
  final String? emotion;

  const AgentResponse({
    required this.text,
    required this.type,
    this.shouldSpeak = true,
    this.data,
    this.actionResult,
    this.needsFollowUp = false,
    this.followUpPrompt,
    this.emotion,
  });

  /// 创建聊天响应
  factory AgentResponse.chat(String text, {String? emotion}) {
    return AgentResponse(
      text: text,
      type: AgentResponseType.chat,
      emotion: emotion,
    );
  }

  /// 创建行为响应
  factory AgentResponse.action(ActionResult result) {
    return AgentResponse(
      text: result.responseText ?? '完成',
      type: AgentResponseType.action,
      actionResult: result,
      data: result.data,
      needsFollowUp: result.needsConfirmation || result.needsMoreParams,
      followUpPrompt: result.confirmationMessage ?? result.followUpPrompt,
    );
  }

  /// 创建错误响应
  factory AgentResponse.error(String message) {
    return AgentResponse(
      text: message,
      type: AgentResponseType.error,
    );
  }
}

/// 响应类型
enum AgentResponseType {
  /// 聊天响应
  chat,

  /// 行为响应
  action,

  /// 混合响应（聊天+行为）
  hybrid,

  /// 错误响应
  error,

  /// 未知
  unknown,
}

/// 智能体状态
enum AgentState {
  /// 空闲
  idle,

  /// 处理中
  processing,

  /// 等待输入
  waitingForInput,

  /// 等待确认
  waitingForConfirmation,

  /// 错误
  error,
}

/// 用户输入
class UserInput {
  /// 输入文本
  final String text;

  /// 输入来源
  final InputSource source;

  /// 时间戳
  final DateTime timestamp;

  const UserInput({
    required this.text,
    this.source = InputSource.voice,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _DefaultDateTime();

  /// 从语音创建
  factory UserInput.fromVoice(String text) => UserInput(
        text: text,
        source: InputSource.voice,
        timestamp: DateTime.now(),
      );

  /// 从文字创建
  factory UserInput.fromText(String text) => UserInput(
        text: text,
        source: InputSource.text,
        timestamp: DateTime.now(),
      );
}

/// 输入来源
enum InputSource {
  voice,
  text,
  gesture,
}

/// 默认时间（避免编译时常量问题）
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now();
}

/// 对话式智能体
class ConversationalAgent {
  /// 意图路由器
  final HybridIntentRouter _router;

  /// LLM意图分类器
  final LLMIntentClassifier _llmClassifier;

  /// 聊天引擎
  final ChatEngine _chatEngine;

  /// 行为执行器
  final ActionExecutor _actionExecutor;

  /// 行为路由器
  final ActionRouter _actionRouter;

  /// 上下文管理器
  final ContextManager _contextManager;

  /// 后台任务队列
  final BackgroundTaskQueue _taskQueue;

  /// 情绪响应服务
  final EmotionalResponseService _emotionalService;

  /// 打断检测器
  final BargeInDetector _bargeInDetector;

  /// 自学习服务
  final SelfLearningService _selfLearningService;

  /// 知识库服务
  final KnowledgeBaseService _knowledgeBaseService;

  /// 语音自然度服务
  final VoiceNaturalnessService _naturalnessService;

  /// 反馈服务
  final VoiceActionFeedbackService _feedbackService =
      VoiceActionFeedbackService.instance;

  /// 是否启用多意图分解模式
  bool _enableDecomposedMode = true;

  /// 是否启用情绪感知
  bool _enableEmotionalResponse = true;

  /// 当前状态
  AgentState _state = AgentState.idle;

  /// 状态变化监听器
  final List<void Function(AgentState)> _stateListeners = [];

  /// 响应流控制器
  final StreamController<AgentResponse> _responseController =
      StreamController<AgentResponse>.broadcast();

  /// 后台任务完成通知流
  final StreamController<ActionExecutionResult> _taskCompletionController =
      StreamController<ActionExecutionResult>.broadcast();

  /// 打断事件流控制器
  final StreamController<BargeInEvent> _bargeInController =
      StreamController<BargeInEvent>.broadcast();

  /// 任务队列订阅
  StreamSubscription<ActionExecutionResult>? _taskResultSubscription;

  /// 打断事件订阅
  StreamSubscription<BargeInEvent>? _bargeInSubscription;

  ConversationalAgent({
    HybridIntentRouter? router,
    LLMIntentClassifier? llmClassifier,
    ChatEngine? chatEngine,
    ActionExecutor? actionExecutor,
    ActionRouter? actionRouter,
    ContextManager? contextManager,
    BackgroundTaskQueue? taskQueue,
    EmotionalResponseService? emotionalService,
    BargeInDetector? bargeInDetector,
    SelfLearningService? selfLearningService,
    KnowledgeBaseService? knowledgeBaseService,
    VoiceNaturalnessService? naturalnessService,
  })  : _router = router ?? HybridIntentRouter(),
        _llmClassifier = llmClassifier ?? LLMIntentClassifier(),
        _chatEngine = chatEngine ?? ChatEngine(),
        _actionExecutor = actionExecutor ?? ActionExecutor(),
        _actionRouter = actionRouter ?? ActionRouter(),
        _contextManager = contextManager ?? ContextManager(),
        _taskQueue = taskQueue ?? BackgroundTaskQueue(),
        _emotionalService = emotionalService ?? EmotionalResponseService(),
        _bargeInDetector = bargeInDetector ?? BargeInDetector(),
        _selfLearningService = selfLearningService ?? SelfLearningService(),
        _knowledgeBaseService = knowledgeBaseService ?? KnowledgeBaseService(),
        _naturalnessService = naturalnessService ?? VoiceNaturalnessService() {
    _setupRouter();
    _setupTaskQueue();
    _setupBargeInDetector();
  }

  /// 配置任务队列
  void _setupTaskQueue() {
    _taskResultSubscription = _taskQueue.resultStream.listen(_onTaskCompleted);
  }

  /// 配置打断检测器
  void _setupBargeInDetector() {
    _bargeInSubscription = _bargeInDetector.eventStream.listen(_onBargeInEvent);
    _bargeInDetector.onBargeInDetected = _handleBargeInDetected;
    _bargeInDetector.onKeywordDetected = _handleBargeInKeyword;
  }

  /// 打断事件处理
  void _onBargeInEvent(BargeInEvent event) {
    debugPrint('[Agent] 打断事件: $event');
    _bargeInController.add(event);
  }

  /// 打断检测回调
  void _handleBargeInDetected() {
    debugPrint('[Agent] 检测到用户打断');
    // 通知外部停止TTS播放
    _bargeInController.add(BargeInEvent(
      type: BargeInEventType.detected,
      source: BargeInSource.vad,
      timestamp: DateTime.now(),
    ));
  }

  /// 打断关键词回调
  void _handleBargeInKeyword(String keyword) {
    debugPrint('[Agent] 检测到打断关键词: $keyword');
    _bargeInController.add(BargeInEvent(
      type: BargeInEventType.keywordDetected,
      source: BargeInSource.keyword,
      keyword: keyword,
      timestamp: DateTime.now(),
    ));
  }

  /// 任务完成回调
  void _onTaskCompleted(ActionExecutionResult result) {
    debugPrint('[Agent] 后台任务完成: ${result.intent.intentId} - ${result.success ? "成功" : "失败"}');

    // 转发到完成通知流
    _taskCompletionController.add(result);

    // 生成任务完成的响应并发布
    if (result.success && result.responseText != null) {
      final response = AgentResponse(
        text: result.responseText!,
        type: AgentResponseType.action,
        data: result.data,
      );
      _responseController.add(response);
    }
  }

  /// 配置路由器
  void _setupRouter() {
    // 配置LLM分类器
    _router.configure(
      llmClassifier: (input, context) => _llmClassifier.classify(input, context),
      ruleClassifier: (input) => _classifyWithRules(input),
    );

    // 配置网络监控器
    _router.networkMonitor.configure(
      llmAvailabilityChecker: () => _llmClassifier.checkAvailability(),
      llmLatencyMeasurer: () => _llmClassifier.measureLatency(),
      connectionWarmer: () => _llmClassifier.warmup(),
    );
  }

  /// 获取当前状态
  AgentState get state => _state;

  /// 获取响应流
  Stream<AgentResponse> get responseStream => _responseController.stream;

  /// 获取上下文管理器
  ContextManager get contextManager => _contextManager;

  /// 获取聊天引擎
  ChatEngine get chatEngine => _chatEngine;

  /// 获取任务完成通知流
  Stream<ActionExecutionResult> get taskCompletionStream =>
      _taskCompletionController.stream;

  /// 获取后台任务队列
  BackgroundTaskQueue get taskQueue => _taskQueue;

  /// 获取情绪响应服务
  EmotionalResponseService get emotionalService => _emotionalService;

  /// 获取打断检测器
  BargeInDetector get bargeInDetector => _bargeInDetector;

  /// 获取打断事件流
  Stream<BargeInEvent> get bargeInStream => _bargeInController.stream;

  /// 获取当前用户情绪
  UserEmotion get currentEmotion => _emotionalService.currentEmotion;

  /// 获取自学习服务
  SelfLearningService get selfLearningService => _selfLearningService;

  /// 获取知识库服务
  KnowledgeBaseService get knowledgeBaseService => _knowledgeBaseService;

  /// 获取学习指标
  LearningMetrics get learningMetrics => _selfLearningService.metrics;

  /// 获取语音自然度服务
  VoiceNaturalnessService get naturalnessService => _naturalnessService;

  /// 设置是否启用分解模式
  set enableDecomposedMode(bool value) => _enableDecomposedMode = value;

  /// 获取是否启用分解模式
  bool get enableDecomposedMode => _enableDecomposedMode;

  /// 设置是否启用情绪感知
  set enableEmotionalResponse(bool value) => _enableEmotionalResponse = value;

  /// 获取是否启用情绪感知
  bool get enableEmotionalResponse => _enableEmotionalResponse;

  /// 初始化
  Future<void> initialize() async {
    debugPrint('[Agent] 初始化...');

    // 加载持久化的上下文
    await _contextManager.load();

    // 初始化网络监控
    await _router.networkMonitor.initializeOnAppStart();

    // 初始化自学习服务
    await _selfLearningService.initialize();
    debugPrint('[Agent] 自学习服务已初始化，规则数: ${_selfLearningService.learnedRules.length}');

    // 加载知识库未匹配问题
    await _knowledgeBaseService.loadUnmatchedQuestions();
    debugPrint('[Agent] 知识库已初始化，FAQ数: ${_knowledgeBaseService.faqCount}');

    _state = AgentState.idle;
    debugPrint('[Agent] 初始化完成');
  }

  /// 处理用户输入
  ///
  /// [input] 用户输入
  /// Returns 智能体响应
  Future<AgentResponse> process(UserInput input) async {
    if (input.text.trim().isEmpty) {
      return AgentResponse.error('输入为空');
    }

    debugPrint('[Agent] 处理输入: ${input.text}');
    _setState(AgentState.processing);

    try {
      // 0. 分析用户情绪（在处理前）
      if (_enableEmotionalResponse) {
        _emotionalService.analyzeUserInput(input.text, wasSuccessful: true);
        debugPrint('[Agent] 用户情绪: ${_emotionalService.currentEmotion}');
      }

      // 1. 更新上下文
      _contextManager.addUserInput(input.text);

      // 1.1 检查是否是FAQ问题（帮助类问题优先匹配）
      final faqResponse = _tryAnswerFromKnowledgeBase(input.text);
      if (faqResponse != null) {
        debugPrint('[Agent] 从知识库匹配到答案');
        _responseController.add(faqResponse);
        _setState(AgentState.idle);
        return faqResponse;
      }

      // 1.2 尝试使用自学习规则匹配
      final learnedMatch = _selfLearningService.tryMatchLearnedRule(input.text);
      if (learnedMatch != null && learnedMatch.rule.confidence >= 0.8) {
        debugPrint('[Agent] 使用自学习规则: ${learnedMatch.rule.pattern} -> ${learnedMatch.rule.intent}');
        // 标记来源为学习规则，继续常规处理流程
      }

      // 2. 检查是否有待确认操作
      if (_actionExecutor.hasPendingAction) {
        return _handlePendingAction(input);
      }

      // 2.1 检查是否有多意图待确认
      if (_actionExecutor.hasMultiIntentPending) {
        return _handleMultiIntentPending(input);
      }

      // 2.2 检测是否为多意图输入
      if (_isMultiIntentInput(input.text)) {
        final multiResult = await _handleMultiIntentInput(input);
        if (multiResult != null) {
          return multiResult;
        }
      }

      // 3. 如果启用分解模式，使用分解意图处理
      if (_enableDecomposedMode) {
        final decomposedResult = await _processWithDecomposition(input);
        if (decomposedResult != null) {
          return decomposedResult;
        }
        // 如果分解失败，降级到传统模式
        debugPrint('[Agent] 分解模式失败，降级到传统模式');
      }

      // 4. 传统模式：意图路由分析
      final contextSummary = _contextManager.generateSummary();
      final routeResult = await _router.route(input.text, context: contextSummary);

      debugPrint(
          '[Agent] 路由结果: type=${routeResult.type.name}, action=${routeResult.action}, confidence=${routeResult.confidence.toStringAsFixed(2)}');

      // 5. 应用指代消解
      final resolvedIntent = _resolveReferences(routeResult, input.text);

      // 6. 根据路由类型处理
      AgentResponse response;
      switch (resolvedIntent.type) {
        case RouteType.chat:
          response = await _handleChat(input.text, resolvedIntent.emotion);
          break;

        case RouteType.action:
          response = await _handleAction(resolvedIntent);
          break;

        case RouteType.hybrid:
          response = await _handleHybrid(input.text, resolvedIntent);
          break;

        case RouteType.unknown:
          response = await _handleUnknown(input.text);
          break;
      }

      // 7. 应用情绪化响应（如果启用）
      AgentResponse finalResponse = response;
      if (_enableEmotionalResponse && response.type != AgentResponseType.error) {
        final emotionalText = _emotionalService.getEmotionalResponse(response.text);
        finalResponse = AgentResponse(
          text: emotionalText,
          type: response.type,
          shouldSpeak: response.shouldSpeak,
          data: response.data,
          actionResult: response.actionResult,
          needsFollowUp: response.needsFollowUp,
          followUpPrompt: response.followUpPrompt,
          emotion: _emotionalService.currentEmotion.name,
        );
      }

      // 8. 更新上下文
      _contextManager.addAgentResponse(
        finalResponse.text,
        transactionRef: _extractTransactionRef(finalResponse),
      );

      // 9. 更新情绪状态（基于操作结果）
      if (_enableEmotionalResponse && finalResponse.actionResult != null) {
        _emotionalService.analyzeUserInput(
          input.text,
          wasSuccessful: finalResponse.actionResult!.success,
        );
      }

      // 10. 发布响应
      _responseController.add(finalResponse);
      _setState(finalResponse.needsFollowUp
          ? AgentState.waitingForInput
          : AgentState.idle);

      return finalResponse;
    } catch (e) {
      debugPrint('[Agent] 处理异常: $e');
      _setState(AgentState.error);
      return AgentResponse.error('抱歉，处理时遇到了问题');
    }
  }

  /// 使用分解模式处理输入
  ///
  /// 将用户输入分解为聊天意图和操作意图
  /// - 聊天意图：立即响应
  /// - 操作意图：后台队列执行
  Future<AgentResponse?> _processWithDecomposition(UserInput input) async {
    try {
      final contextSummary = _contextManager.generateSummary();
      final decomposed = await _llmClassifier.classifyDecomposed(
        input.text,
        contextSummary,
      );

      if (decomposed == null) {
        debugPrint('[Agent] 分解分类返回null');
        return null;
      }

      debugPrint('[Agent] 分解结果: $decomposed');

      // 如果只有聊天意图，直接处理
      if (decomposed.isChatOnly) {
        return _handleDecomposedChatOnly(decomposed);
      }

      // 如果只有操作意图，直接处理（不用后台）
      if (decomposed.isActionOnly) {
        return _handleDecomposedActionOnly(decomposed);
      }

      // 混合意图：聊天立即响应，操作后台执行
      if (decomposed.isHybrid) {
        return _handleDecomposedHybrid(decomposed);
      }

      // 无法识别
      if (decomposed.isEmpty) {
        return _handleUnknown(input.text);
      }

      return null;
    } catch (e) {
      debugPrint('[Agent] 分解处理异常: $e');
      return null;
    }
  }

  /// 处理纯聊天分解结果
  Future<AgentResponse> _handleDecomposedChatOnly(
    DecomposedIntentResult decomposed,
  ) async {
    debugPrint('[Agent] 处理纯聊天意图');

    final chatIntent = decomposed.chatIntent!;
    String responseText;

    // 如果LLM已经提供了建议响应，直接使用
    if (chatIntent.hasSuggestedResponse) {
      responseText = chatIntent.suggestedResponse!;
    } else {
      // 否则使用聊天引擎生成
      final chatResponse = await _chatEngine.respond(
        chatIntent.text,
        emotion: chatIntent.emotion,
      );
      responseText = chatResponse.text;
    }

    final response = AgentResponse.chat(responseText, emotion: chatIntent.emotion);

    // 更新上下文
    _contextManager.addAgentResponse(responseText);
    _setState(AgentState.idle);

    return response;
  }

  /// 处理纯操作分解结果
  Future<AgentResponse> _handleDecomposedActionOnly(
    DecomposedIntentResult decomposed,
  ) async {
    debugPrint('[Agent] 处理纯操作意图: ${decomposed.actionCount}个');

    // 如果只有一个操作，直接同步执行
    if (decomposed.actionCount == 1) {
      final actionIntent = decomposed.actionIntents.first;
      final intentResult = actionIntent.toIntentResult();
      final result = await _actionRouter.execute(intentResult);

      final response = _createActionResponse(result);
      _contextManager.addAgentResponse(response.text);
      _setState(AgentState.idle);

      return response;
    }

    // 多个操作，加入后台队列
    final taskIds = _taskQueue.enqueueAll(decomposed.actionIntents);
    debugPrint('[Agent] 多个操作已加入队列: $taskIds');

    final response = AgentResponse(
      text: '好的，正在处理${decomposed.actionCount}项操作...',
      type: AgentResponseType.action,
      data: {'taskIds': taskIds},
    );

    _contextManager.addAgentResponse(response.text);
    _setState(AgentState.idle);

    return response;
  }

  /// 处理混合分解结果
  ///
  /// 核心逻辑：聊天立即响应，操作后台执行
  Future<AgentResponse> _handleDecomposedHybrid(
    DecomposedIntentResult decomposed,
  ) async {
    debugPrint('[Agent] 处理混合意图: chat + ${decomposed.actionCount}个操作');

    final chatIntent = decomposed.chatIntent!;

    // 1. 立即生成聊天响应
    String chatResponse;
    if (chatIntent.hasSuggestedResponse) {
      chatResponse = chatIntent.suggestedResponse!;
    } else {
      final response = await _chatEngine.respond(
        chatIntent.text,
        emotion: chatIntent.emotion,
      );
      chatResponse = response.text;
    }

    // 2. 操作加入后台队列（不阻塞）
    final taskIds = _taskQueue.enqueueAll(decomposed.actionIntents);
    debugPrint('[Agent] 操作已加入后台队列: $taskIds');

    // 3. 构建响应（只包含聊天部分，操作完成后会单独通知）
    final response = AgentResponse(
      text: chatResponse,
      type: AgentResponseType.hybrid,
      emotion: chatIntent.emotion,
      data: {
        'taskIds': taskIds,
        'pendingActions': decomposed.actionCount,
      },
    );

    // 更新上下文
    _contextManager.addAgentResponse(response.text);
    _setState(AgentState.idle);

    return response;
  }

  /// 处理待确认操作
  Future<AgentResponse> _handlePendingAction(UserInput input) async {
    debugPrint('[Agent] 处理待确认操作');

    final pending = _actionExecutor.pendingAction;
    if (pending == null) {
      debugPrint('[Agent] 无待处理操作，正常处理');
      return process(input);
    }

    // 1. 检查是否是确认/取消意图
    final isConfirm = _isConfirmInput(input.text);
    final isCancel = _isCancelInput(input.text);

    if (isConfirm || isCancel) {
      // 记录自学习样本（使用action的id和params作为上下文）
      final recognizedIntent = pending.action.id;
      // 从params中尝试获取原始输入
      final originalInput = pending.params['_rawInput'] as String? ?? input.text;

      if (isConfirm) {
        // 记录确认样本（正样本）
        _selfLearningService.recordConfirmation(
          input: originalInput,
          recognizedIntent: recognizedIntent,
          recognitionSource: 'action',
          extractedEntities: pending.params,
        );
      } else {
        // 记录取消样本（负样本）
        _selfLearningService.recordCancellation(
          input: originalInput,
          recognizedIntent: recognizedIntent,
        );
      }

      // 直接传给 ActionExecutor 处理确认/取消
      final intent = IntentResult(
        type: RouteType.action,
        confidence: 1.0,
        rawInput: input.text,
        source: RecognitionSource.rule,
        category: 'system',
        action: isConfirm ? 'confirm' : 'cancel',
      );
      final result = await _actionExecutor.execute(intent);
      return _createActionResponse(result);
    }

    // 2. 如果是等待参数补充，尝试提取新输入中的实体
    if (pending.isWaitingForParams) {
      debugPrint('[Agent] 等待参数补充: ${pending.missingParams}');

      // 从新输入中提取实体
      final extractedEntities = await _extractEntitiesForParams(
        input.text,
        pending.missingParams,
      );

      final intent = IntentResult(
        type: RouteType.action,
        confidence: 1.0,
        rawInput: input.text,
        source: RecognitionSource.rule,
        entities: extractedEntities,
      );

      final result = await _actionExecutor.execute(intent);
      return _createActionResponse(result);
    }

    // 3. 如果是等待确认但用户说了其他内容，可能是新意图
    // 取消当前操作，处理新意图
    debugPrint('[Agent] 非确认/取消输入，可能是新意图');
    _actionExecutor.cancelPending();

    // 重新处理为新意图
    return process(input);
  }

  /// 检查是否是确认输入
  bool _isConfirmInput(String input) {
    const confirmKeywords = [
      '确认', '确定', '是的', '好的', '可以', '没问题', '对', 'yes', 'ok',
      '继续', '记', '行', '嗯',
    ];
    final lowerInput = input.toLowerCase().trim();
    return confirmKeywords.any((k) => lowerInput.contains(k));
  }

  /// 检查是否是取消输入
  bool _isCancelInput(String input) {
    const cancelKeywords = [
      '取消', '不要', '算了', '不用了', '不', '错了', 'no', 'cancel',
      '停', '别', '不是',
    ];
    final lowerInput = input.toLowerCase().trim();
    return cancelKeywords.any((k) => lowerInput.contains(k));
  }

  // ==================== 多意图处理 ====================

  /// 检测是否是多意图输入
  bool _isMultiIntentInput(String input) {
    // 检测多意图分隔符
    final separatorPatterns = [
      RegExp(r'[，,；;、]'),           // 标点分隔符
      RegExp(r'还有|另外|再[记加]|以及|和'), // 连接词
      RegExp(r'第[一二三]|首先|然后|最后'),  // 序数词
    ];

    // 至少需要一个分隔符且有足够的长度
    if (input.length < 8) return false;

    // 检查是否有分隔符
    final hasSeparator = separatorPatterns.any((p) => p.hasMatch(input));
    if (!hasSeparator) return false;

    // 检查是否有多个金额（强信号）
    final amountPattern = RegExp(r'\d+(?:\.\d+)?\s*[块元]?');
    final amounts = amountPattern.allMatches(input).length;
    if (amounts >= 2) return true;

    // 检查是否有多个分类关键词
    const categoryKeywords = [
      '午餐', '晚餐', '早餐', '吃饭', '外卖',
      '打车', '地铁', '公交', '交通',
      '超市', '购物', '淘宝',
      '话费', '水电', '房租',
    ];
    var categoryCount = 0;
    for (final keyword in categoryKeywords) {
      if (input.contains(keyword)) categoryCount++;
    }
    if (categoryCount >= 2) return true;

    return false;
  }

  /// 处理多意图输入
  Future<AgentResponse?> _handleMultiIntentInput(UserInput input) async {
    debugPrint('[Agent] 检测到多意图输入: "${input.text}"');

    try {
      // 分句
      final segments = _splitMultiIntentInput(input.text);
      if (segments.length <= 1) return null;

      debugPrint('[Agent] 分句结果: ${segments.length}段');

      // 对每个分句进行意图识别
      final intents = <IntentResult>[];
      for (final segment in segments) {
        if (segment.trim().isEmpty) continue;

        final contextSummary = _contextManager.generateSummary();
        final routeResult = await _router.route(segment, context: contextSummary);

        // 只处理行为意图
        if (routeResult.type == RouteType.action && routeResult.action != null) {
          intents.add(routeResult);
        }
      }

      if (intents.length <= 1) {
        debugPrint('[Agent] 多意图识别后只有${intents.length}个有效意图');
        return null;
      }

      // 使用多意图执行
      final result = await _actionExecutor.executeMultiIntent(intents);
      return _createActionResponse(result);
    } catch (e) {
      debugPrint('[Agent] 多意图处理异常: $e');
      return null;
    }
  }

  /// 分割多意图输入
  List<String> _splitMultiIntentInput(String input) {
    final segments = <String>[];
    var current = input;

    // 按分隔符分割
    final separators = [
      RegExp(r'[，,；;、]'),
      RegExp(r'还有|另外|再记|再加|以及'),
    ];

    for (final sep in separators) {
      final parts = current.split(sep);
      if (parts.length > 1) {
        segments.addAll(parts.where((p) => p.trim().isNotEmpty));
        current = '';
        break;
      }
    }

    if (segments.isEmpty && current.isNotEmpty) {
      segments.add(current);
    }

    return segments;
  }

  /// 处理多意图待确认
  Future<AgentResponse> _handleMultiIntentPending(UserInput input) async {
    debugPrint('[Agent] 处理多意图待确认');

    // 构建意图结果
    final intent = IntentResult(
      type: RouteType.action,
      confidence: 1.0,
      rawInput: input.text,
      source: RecognitionSource.rule,
      entities: _extractBasicEntities(input.text),
    );

    // 交给 ActionExecutor 处理
    final result = await _actionExecutor.handleMultiIntentConfirmation(intent);
    return _createActionResponse(result);
  }

  /// 提取基本实体（用于多意图确认时的参数补充）
  Map<String, dynamic> _extractBasicEntities(String input) {
    final entities = <String, dynamic>{};

    // 提取金额
    final amount = _extractAmount(input);
    if (amount != null) {
      entities['amount'] = amount;
    }

    // 提取分类
    final category = _extractCategory(input);
    if (category != null) {
      entities['category'] = category;
    }

    return entities;
  }

  /// 从输入中提取参数实体
  Future<Map<String, dynamic>> _extractEntitiesForParams(
    String input,
    List<String> missingParams,
  ) async {
    final entities = <String, dynamic>{};

    // 提取金额
    if (missingParams.contains('amount')) {
      final amount = _extractAmount(input);
      if (amount != null) {
        entities['amount'] = amount;
      }
    }

    // 提取分类
    if (missingParams.contains('category')) {
      final category = _extractCategory(input);
      if (category != null) {
        entities['category'] = category;
      }
    }

    // 提取商家
    if (missingParams.contains('merchant')) {
      final merchant = _extractMerchant(input);
      if (merchant != null) {
        entities['merchant'] = merchant;
      }
    }

    // 提取日期
    if (missingParams.contains('date')) {
      final date = _extractDate(input);
      if (date != null) {
        entities['date'] = date;
      }
    }

    // 提取备注
    if (missingParams.contains('note')) {
      final note = _extractNote(input);
      if (note != null) {
        entities['note'] = note;
      }
    }

    // 尝试通过LLM提取（如果可用且还有缺失参数）
    final stillMissing = missingParams.where((p) => !entities.containsKey(p)).toList();
    if (stillMissing.isNotEmpty && await _llmClassifier.checkAvailability()) {
      try {
        final llmResult = await _llmClassifier.classify(
          '用户说"$input"，请提取${stillMissing.join("、")}',
          null,
        );
        final llmEntities = llmResult?.entities;
        if (llmEntities != null && llmEntities.isNotEmpty) {
          // 只补充缺失的参数
          for (final key in stillMissing) {
            if (llmEntities.containsKey(key)) {
              entities[key] = llmEntities[key];
            }
          }
        }
      } catch (e) {
        debugPrint('[Agent] LLM提取参数失败: $e');
      }
    }

    return entities;
  }

  /// 提取金额（支持中文数字）
  double? _extractAmount(String input) {
    // 1. 先尝试阿拉伯数字
    final arabicPatterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*[块元钱]'),  // 35块、50.5元
      RegExp(r'(\d+(?:\.\d+)?)'),              // 纯数字
    ];

    for (final pattern in arabicPatterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        final value = double.tryParse(match.group(1) ?? '');
        if (value != null && value > 0) return value;
      }
    }

    // 2. 尝试中文数字
    final chineseAmount = _parseChineseNumber(input);
    if (chineseAmount != null) return chineseAmount;

    return null;
  }

  /// 解析中文数字
  double? _parseChineseNumber(String input) {
    const chineseDigits = {
      '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
    };
    const units = {'十': 10, '百': 100, '千': 1000, '万': 10000};

    // 匹配中文数字模式
    final pattern = RegExp(r'([零一二两三四五六七八九十百千万]+)\s*[块元钱]');
    final match = pattern.firstMatch(input);
    if (match == null) return null;

    final chineseStr = match.group(1)!;
    double result = 0;
    double current = 0;
    double lastUnit = 1;

    for (int i = 0; i < chineseStr.length; i++) {
      final char = chineseStr[i];

      if (chineseDigits.containsKey(char)) {
        final digit = chineseDigits[char]!;
        if (char == '十' && current == 0) {
          current = 10; // "十块" = 10
        } else {
          current = digit.toDouble();
        }
      }

      if (units.containsKey(char)) {
        final unit = units[char]!;
        if (current == 0) current = 1; // "十块" = 10
        result += current * unit;
        current = 0;
        lastUnit = unit.toDouble();
      }
    }

    // 处理最后的数字
    if (current > 0) {
      if (lastUnit >= 10 && current < 10) {
        result += current; // "二十三" = 23
      } else {
        result += current;
      }
    }

    return result > 0 ? result : null;
  }

  /// 提取分类
  String? _extractCategory(String input) {
    // 常见支出分类（扩展版）
    const categories = {
      '餐饮': ['吃饭', '午餐', '晚餐', '早餐', '外卖', '餐厅', '饭', '咖啡', '奶茶', '水果', '零食', '饮料', '烧烤', '火锅'],
      '交通': ['打车', '滴滴', '公交', '地铁', '出租', '加油', '停车', '高铁', '火车', '飞机', '机票'],
      '购物': ['买', '购物', '超市', '商场', '淘宝', '京东', '拼多多', '衣服', '鞋子'],
      '娱乐': ['电影', '游戏', '唱歌', 'KTV', '酒吧', '按摩', '健身'],
      '医疗': ['医院', '看病', '药', '医疗', '体检', '挂号'],
      '教育': ['学费', '培训', '课程', '书', '网课'],
      '通讯': ['话费', '充值', '流量', '宽带'],
      '住房': ['房租', '水电', '物业', '燃气', '暖气'],
      '生活': ['理发', '美容', '洗衣', '快递'],
    };

    for (final entry in categories.entries) {
      for (final keyword in entry.value) {
        if (input.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// 提取商家
  String? _extractMerchant(String input) {
    // 常见商家关键词
    final merchantPatterns = [
      // 外卖平台
      RegExp(r'(美团|饿了么|肯德基|麦当劳|必胜客|星巴克)'),
      // 支付平台
      RegExp(r'(支付宝|微信|淘宝|京东|拼多多)'),
      // 超市
      RegExp(r'(沃尔玛|家乐福|永辉|盒马|711|全家|罗森)'),
      // 出行
      RegExp(r'(滴滴|高德|花小猪|曹操)'),
    ];

    for (final pattern in merchantPatterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        return match.group(1);
      }
    }

    // 如果输入不包含数字且长度适中，可能是商家名
    if (!RegExp(r'\d').hasMatch(input) && input.length >= 2 && input.length <= 10) {
      return input.trim();
    }

    return null;
  }

  /// 提取日期
  DateTime? _extractDate(String input) {
    final now = DateTime.now();

    // 相对日期
    if (input.contains('今天') || input.contains('今日')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (input.contains('昨天') || input.contains('昨日')) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (input.contains('前天')) {
      return DateTime(now.year, now.month, now.day - 2);
    }
    if (input.contains('明天') || input.contains('明日')) {
      return DateTime(now.year, now.month, now.day + 1);
    }

    // 星期几
    final weekdayMatch = RegExp(r'(上|下)?周([一二三四五六日天])').firstMatch(input);
    if (weekdayMatch != null) {
      final prefix = weekdayMatch.group(1);
      final weekdayStr = weekdayMatch.group(2)!;
      const weekdays = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7, '天': 7};
      final targetWeekday = weekdays[weekdayStr]!;
      var diff = targetWeekday - now.weekday;

      if (prefix == '上') {
        diff -= 7;
      } else if (prefix == '下') {
        diff += 7;
      } else {
        // 默认本周
        if (diff < 0) diff += 7;
      }

      return DateTime(now.year, now.month, now.day + diff);
    }

    // 月日格式：X月X日/号
    final dateMatch = RegExp(r'(\d{1,2})月(\d{1,2})[日号]?').firstMatch(input);
    if (dateMatch != null) {
      final month = int.parse(dateMatch.group(1)!);
      final day = int.parse(dateMatch.group(2)!);
      return DateTime(now.year, month, day);
    }

    return null;
  }

  /// 提取备注
  String? _extractNote(String input) {
    // 常见备注引导词
    final notePatterns = [
      RegExp(r'备注[：:]?\s*(.+)'),
      RegExp(r'说明[：:]?\s*(.+)'),
      RegExp(r'注[：:]?\s*(.+)'),
    ];

    for (final pattern in notePatterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }

  /// 处理聊天意图
  Future<AgentResponse> _handleChat(String input, String? emotion) async {
    debugPrint('[Agent] 处理聊天');

    final contextSummary = _contextManager.generateSummary();
    final chatResponse = await _chatEngine.respond(
      input,
      context: contextSummary,
      emotion: emotion,
    );

    return AgentResponse.chat(chatResponse.text, emotion: emotion);
  }

  /// 处理行为意图
  Future<AgentResponse> _handleAction(IntentResult intent) async {
    debugPrint('[Agent] 处理行为: ${intent.intentId}');

    // 使用行为路由器执行
    final result = await _actionRouter.execute(intent);

    // 更新用户画像
    if (result.success && result.data != null) {
      _contextManager.updateUserProfile(
        category: result.data!['category'] as String?,
        amount: (result.data!['amount'] as num?)?.toDouble(),
        merchant: result.data!['merchant'] as String?,
      );
    }

    return _createActionResponse(result);
  }

  /// 处理混合意图
  Future<AgentResponse> _handleHybrid(
    String input,
    IntentResult intent,
  ) async {
    debugPrint('[Agent] 处理混合意图');

    // 先执行行为
    final actionResult = await _actionRouter.execute(intent);

    // 生成带聊天风格的响应
    String responseText;
    if (actionResult.success) {
      // 如果有聊天响应，合并使用
      if (intent.chatResponse != null && intent.chatResponse!.isNotEmpty) {
        responseText = '${intent.chatResponse} ${actionResult.responseText ?? ""}';
      } else {
        responseText = actionResult.responseText ?? '好的，完成了';
      }
    } else {
      responseText = actionResult.error ?? '操作失败';
    }

    return AgentResponse(
      text: responseText.trim(),
      type: AgentResponseType.hybrid,
      actionResult: actionResult,
      data: actionResult.data,
      emotion: intent.emotion,
    );
  }

  /// 处理未知意图
  Future<AgentResponse> _handleUnknown(String input) async {
    debugPrint('[Agent] 处理未知意图');

    // 尝试使用聊天引擎生成友好响应
    final chatResponse = await _chatEngine.respond(input);

    return AgentResponse(
      text: chatResponse.text,
      type: AgentResponseType.unknown,
    );
  }

  /// 应用指代消解
  IntentResult _resolveReferences(IntentResult intent, String input) {
    final resolved = _contextManager.resolveReference(input);
    if (resolved == null) return intent;

    final updatedEntities = Map<String, dynamic>.from(intent.entities);

    switch (resolved.type) {
      case ReferenceType.transaction:
        if (resolved.value is TransactionReference) {
          updatedEntities['transactionId'] =
              (resolved.value as TransactionReference).id;
        } else if (resolved.value is String) {
          updatedEntities['transactionId'] = resolved.value;
        }
        break;

      case ReferenceType.time:
        if (resolved.value is TimeRange) {
          final range = resolved.value as TimeRange;
          updatedEntities['startDate'] = range.start;
          updatedEntities['endDate'] = range.end;
        }
        break;

      case ReferenceType.category:
        updatedEntities['category'] = resolved.value;
        break;

      case ReferenceType.account:
        updatedEntities['accountName'] = resolved.value;
        break;

      case ReferenceType.unknown:
        break;
    }

    return IntentResult(
      type: intent.type,
      confidence: intent.confidence,
      category: intent.category,
      action: intent.action,
      entities: updatedEntities,
      emotion: intent.emotion,
      chatResponse: intent.chatResponse,
      rawInput: intent.rawInput,
      source: intent.source,
    );
  }

  /// 创建行为响应
  AgentResponse _createActionResponse(ActionResult result) {
    if (result.needsConfirmation) {
      _setState(AgentState.waitingForConfirmation);
      return AgentResponse(
        text: result.confirmationMessage ?? '确定要执行吗？',
        type: AgentResponseType.action,
        actionResult: result,
        needsFollowUp: true,
      );
    }

    if (result.needsMoreParams) {
      _setState(AgentState.waitingForInput);
      return AgentResponse(
        text: result.followUpPrompt ?? '请提供更多信息',
        type: AgentResponseType.action,
        actionResult: result,
        needsFollowUp: true,
        followUpPrompt: result.followUpPrompt,
      );
    }

    // 使用反馈服务生成详细反馈
    final feedbackText = _generateDetailedFeedback(result);

    return AgentResponse(
      text: feedbackText,
      type: AgentResponseType.action,
      actionResult: result,
      data: result.data,
    );
  }

  /// 生成详细反馈
  String _generateDetailedFeedback(ActionResult result) {
    // 如果已有响应文本且不是通用的，直接使用
    if (result.responseText != null &&
        result.responseText!.isNotEmpty &&
        !_isGenericResponse(result.responseText!)) {
      return result.responseText!;
    }

    // 根据 actionId 生成特定反馈
    final actionId = result.actionId ?? '';
    final data = result.data ?? {};

    if (result.success) {
      // 记账成功
      if (actionId.contains('transaction.add') || actionId.contains('add')) {
        return _feedbackService.generateTransactionFeedback([
          TransactionResult(
            success: true,
            amount: (data['amount'] as num?)?.toDouble() ?? 0,
            type: data['type'] ?? model.TransactionType.expense,
            category: data['category'] as String?,
            merchant: data['merchant'] as String?,
            description: data['description'] as String?,
          ),
        ]);
      }

      // 删除成功
      if (actionId.contains('delete')) {
        return _feedbackService.generateDeleteFeedback(
          success: true,
          deletedCount: data['deletedCount'] as int?,
          deletedInfo: data['deletedInfo'] as String?,
        );
      }

      // 修改成功
      if (actionId.contains('modify') || actionId.contains('update')) {
        return _feedbackService.generateModifyFeedback(
          success: true,
          originalInfo: data['originalInfo'] as String?,
          modifiedInfo: data['modifiedInfo'] as String?,
        );
      }

      // 导航成功
      if (actionId.contains('navigation') || actionId.contains('navigate')) {
        return _feedbackService.generateNavigationFeedback(
          success: true,
          targetPage: data['targetPage'] as String?,
        );
      }

      // 多意图批量操作
      if (data['multiIntent'] == true) {
        final successCount = data['successCount'] as int? ?? 0;
        final failCount = data['failCount'] as int? ?? 0;
        return _feedbackService.generateBatchFeedback(
          totalCount: successCount + failCount,
          successCount: successCount,
          failureCount: failCount,
          operationType: '记录',
        );
      }

      // 通用成功响应
      return result.responseText ?? '✓ 操作成功';
    } else {
      // 失败响应
      if (actionId.contains('delete')) {
        return _feedbackService.generateDeleteFeedback(
          success: false,
          errorMessage: result.error,
        );
      }

      if (actionId.contains('modify')) {
        return _feedbackService.generateModifyFeedback(
          success: false,
          errorMessage: result.error,
        );
      }

      return result.error ?? '✗ 操作失败';
    }
  }

  /// 检查是否是通用响应
  bool _isGenericResponse(String text) {
    const genericResponses = ['好的', '完成', '已完成', 'OK', 'ok', '成功', '操作成功'];
    return genericResponses.any((r) => text == r);
  }

  /// 提取交易引用
  TransactionReference? _extractTransactionRef(AgentResponse response) {
    if (response.data == null) return null;

    final data = response.data!;
    if (data.containsKey('transactionId') && data.containsKey('amount')) {
      return TransactionReference(
        id: data['transactionId'] as String,
        amount: (data['amount'] as num).toDouble(),
        category: data['category'] as String? ?? '其他',
        date: DateTime.now(),
      );
    }

    return null;
  }

  /// 使用规则分类
  Future<IntentResult?> _classifyWithRules(String input) async {
    // 简单的规则分类实现
    // 实际使用时会复用 SmartIntentRecognizer 的规则

    // 先尝试从复杂句子中提取简单指令
    final extractedCommand = _extractSimpleCommand(input);
    final processInput = extractedCommand ?? input;

    // 检查记账意图（支持"XX15块"这种简单模式）
    final expenseResult = _checkExpenseIntent(processInput);
    if (expenseResult != null) {
      return expenseResult;
    }

    if (_containsIncomeKeywords(processInput)) {
      final amount = _extractAmount(processInput);
      return IntentResult(
        type: RouteType.action,
        confidence: amount != null ? 0.85 : 0.6,
        category: IntentCategory.transaction,
        action: 'income',
        entities: amount != null ? {'amount': amount} : {},
        rawInput: input,
        source: RecognitionSource.rule,
      );
    }

    // 检查导航意图
    if (_containsNavigationKeywords(processInput)) {
      return IntentResult(
        type: RouteType.action,
        confidence: 0.8,
        category: IntentCategory.navigation,
        action: 'page',
        entities: {'targetPage': _extractTargetPage(processInput)},
        rawInput: input,
        source: RecognitionSource.rule,
      );
    }

    // 检查查询意图
    if (_containsQueryKeywords(processInput)) {
      return IntentResult(
        type: RouteType.action,
        confidence: 0.8,
        category: IntentCategory.query,
        action: 'statistics',
        rawInput: input,
        source: RecognitionSource.rule,
      );
    }

    // 默认返回未知
    return IntentResult(
      type: RouteType.unknown,
      confidence: 0.3,
      rawInput: input,
      source: RecognitionSource.rule,
    );
  }

  /// 从复杂句子中提取简单指令
  /// 例如："现在可以聊天了吗？能说话吗？打车15块。" -> "打车15块"
  String? _extractSimpleCommand(String input) {
    // 按句号、问号、感叹号分割
    final sentences = input.split(RegExp(r'[。？！?!，,]'));

    for (final sentence in sentences.reversed) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      // 检查是否包含金额模式（最可能是记账指令）
      if (RegExp(r'\d+\s*[元块钱]?').hasMatch(trimmed)) {
        debugPrint('[Agent] 从复杂句子提取指令: $trimmed');
        return trimmed;
      }
    }

    return null;
  }

  /// 检查支出意图（增强版）
  IntentResult? _checkExpenseIntent(String input) {
    // 方式1：传统关键词匹配
    if (_containsExpenseKeywords(input)) {
      final amount = _extractAmount(input);
      final category = _extractCategory(input);
      return IntentResult(
        type: RouteType.action,
        confidence: amount != null ? 0.85 : 0.6,
        category: IntentCategory.transaction,
        action: 'expense',
        entities: {
          if (amount != null) 'amount': amount,
          if (category != null) 'category': category,
        },
        rawInput: input,
        source: RecognitionSource.rule,
      );
    }

    // 方式2：简单模式 "XX + 金额"（如"打车15块"、"午餐30元"、"咖啡25"）
    final simpleExpenseMatch = RegExp(
      r'^(.+?)(\d+(?:\.\d+)?)\s*[元块钱]?[。.，,]?$',
    ).firstMatch(input);

    if (simpleExpenseMatch != null) {
      final description = simpleExpenseMatch.group(1)?.trim();
      final amountStr = simpleExpenseMatch.group(2);
      final amount = double.tryParse(amountStr ?? '');

      if (amount != null && description != null && description.isNotEmpty) {
        // 排除问句
        if (!description.contains('?') && !description.contains('？') &&
            !description.contains('吗') && !description.contains('呢')) {
          final category = _extractCategory(description);
          debugPrint('[Agent] 识别简单支出模式: $description $amount');
          return IntentResult(
            type: RouteType.action,
            confidence: 0.85,
            category: IntentCategory.transaction,
            action: 'expense',
            entities: {
              'amount': amount,
              'description': description,
              if (category != null) 'category': category,
            },
            rawInput: input,
            source: RecognitionSource.rule,
          );
        }
      }
    }

    // 方式3：纯金额（如"15块"、"30元"）- 作为待补全的支出
    final pureAmountMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*[元块钱]?[。.，,]?$').firstMatch(input);
    if (pureAmountMatch != null) {
      final amount = double.tryParse(pureAmountMatch.group(1) ?? '');
      if (amount != null) {
        return IntentResult(
          type: RouteType.action,
          confidence: 0.7,
          category: IntentCategory.transaction,
          action: 'expense',
          entities: {'amount': amount},
          rawInput: input,
          source: RecognitionSource.rule,
        );
      }
    }

    return null;
  }

  bool _containsExpenseKeywords(String input) {
    const keywords = ['花了', '买了', '付了', '消费', '支出', '吃了', '喝了', '花费', '付款', '支付'];
    return keywords.any((k) => input.contains(k));
  }

  bool _containsIncomeKeywords(String input) {
    const keywords = ['收入', '赚了', '进账', '收到', '工资', '奖金', '红包'];
    return keywords.any((k) => input.contains(k));
  }

  bool _containsNavigationKeywords(String input) {
    const keywords = ['打开', '去', '跳转', '进入'];
    return keywords.any((k) => input.contains(k));
  }

  bool _containsQueryKeywords(String input) {
    const keywords = ['多少', '统计', '查询', '花了多少', '总共'];
    return keywords.any((k) => input.contains(k));
  }

  String? _extractTargetPage(String input) {
    const pageKeywords = {
      '首页': 'home',
      '统计': 'statistics',
      '预算': 'budget',
      '设置': 'settings',
      '账本': 'ledger',
    };

    for (final entry in pageKeywords.entries) {
      if (input.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// 设置状态
  void _setState(AgentState newState) {
    if (_state != newState) {
      _state = newState;
      for (final listener in _stateListeners) {
        listener(newState);
      }
    }
  }

  /// 添加状态监听器
  void addStateListener(void Function(AgentState) listener) {
    _stateListeners.add(listener);
  }

  /// 移除状态监听器
  void removeStateListener(void Function(AgentState) listener) {
    _stateListeners.remove(listener);
  }

  /// 取消当前操作
  void cancel() {
    _actionExecutor.cancelPending();
    _setState(AgentState.idle);
  }

  /// 重置智能体
  void reset() {
    _actionExecutor.reset();
    _contextManager.startSession();
    _setState(AgentState.idle);
  }

  /// 开始新会话
  void startSession() {
    _contextManager.startSession();
    _setState(AgentState.idle);
  }

  /// 结束会话
  Future<void> endSession() async {
    _contextManager.endSession();
    await _contextManager.save();
    _setState(AgentState.idle);
  }

  // ═══════════════════════════════════════════════════════════════
  // 情绪感知相关方法
  // ═══════════════════════════════════════════════════════════════

  /// 分析用户输入的情绪
  ///
  /// 在处理用户输入前调用，更新情绪状态
  void analyzeUserEmotion(String input, {bool wasSuccessful = true}) {
    if (!_enableEmotionalResponse) return;
    _emotionalService.analyzeUserInput(input, wasSuccessful: wasSuccessful);
    debugPrint('[Agent] 当前用户情绪: ${_emotionalService.currentEmotion}');
  }

  /// 获取情绪化的响应文本
  ///
  /// 根据当前用户情绪调整响应文本
  String getEmotionalResponse(String baseMessage) {
    if (!_enableEmotionalResponse) return baseMessage;
    return _emotionalService.getEmotionalResponse(baseMessage);
  }

  /// 获取情绪化的TTS参数
  ///
  /// 返回适配当前用户情绪的TTS参数（语速、音调、音量）
  TTSParameters getEmotionalTTSParameters() {
    return _emotionalService.getTTSParameters();
  }

  /// 获取时段问候语
  ///
  /// 根据当前时间段返回合适的问候语
  String getTimeBasedGreeting() {
    return _emotionalService.getTimeBasedGreeting();
  }

  /// 获取成功记账的情绪化响应
  String getSuccessResponse({required double amount, String? category}) {
    if (!_enableEmotionalResponse) {
      return '已记录${category ?? "消费"}${amount.toStringAsFixed(0)}元';
    }
    return _emotionalService.getSuccessResponse(amount: amount, category: category);
  }

  /// 获取错误提示的情绪化响应
  String getErrorResponse(String errorType) {
    if (!_enableEmotionalResponse) {
      return '操作失败，请重试';
    }
    return _emotionalService.getErrorResponse(errorType);
  }

  /// 重置情绪状态
  void resetEmotion() {
    _emotionalService.reset();
  }

  // ═══════════════════════════════════════════════════════════════
  // 打断检测相关方法
  // ═══════════════════════════════════════════════════════════════

  /// 启动打断检测
  void startBargeInDetection() {
    _bargeInDetector.start();
    debugPrint('[Agent] 打断检测已启动');
  }

  /// 停止打断检测
  void stopBargeInDetection() {
    _bargeInDetector.stop();
    debugPrint('[Agent] 打断检测已停止');
  }

  /// 通知TTS开始播放
  ///
  /// 在TTS开始播放时调用，启用打断监控
  void notifyTTSStarted({double estimatedVolume = 0.5}) {
    _bargeInDetector.notifyTTSStarted(estimatedVolume: estimatedVolume);
  }

  /// 通知TTS停止播放
  ///
  /// 在TTS停止播放时调用，停止打断监控
  void notifyTTSStopped() {
    _bargeInDetector.notifyTTSStopped();
  }

  /// 处理音频数据（用于打断检测）
  ///
  /// 在TTS播放期间持续接收麦克风音频数据
  void processAudioForBargeIn(Float32List audioData) {
    _bargeInDetector.processAudioData(audioData);
  }

  /// 处理VAD结果（用于打断检测）
  ///
  /// 接收VAD检测结果
  void processVADForBargeIn(bool isSpeaking) {
    _bargeInDetector.processVADResult(isSpeaking);
  }

  /// 处理ASR结果（用于打断关键词检测）
  ///
  /// 接收流式ASR结果，检测打断关键词
  void processASRForBargeIn(String text) {
    _bargeInDetector.processASRResult(text);
  }

  /// 重置打断检测器
  void resetBargeInDetector() {
    _bargeInDetector.reset();
  }

  /// 获取打断检测状态
  BargeInState get bargeInState => _bargeInDetector.state;

  /// 检查打断检测器是否启用
  bool get isBargeInEnabled => _bargeInDetector.isEnabled;

  // ═══════════════════════════════════════════════════════════════
  // 自学习系统相关方法
  // ═══════════════════════════════════════════════════════════════

  /// 记录用户确认操作（正样本）
  ///
  /// 当用户确认一个识别结果时调用
  void recordConfirmation({
    required String input,
    required String recognizedIntent,
    String recognitionSource = 'mixed',
    Map<String, dynamic>? extractedEntities,
  }) {
    _selfLearningService.recordConfirmation(
      input: input,
      recognizedIntent: recognizedIntent,
      recognitionSource: recognitionSource,
      extractedEntities: extractedEntities,
    );
    debugPrint('[Agent] 记录确认样本: $input -> $recognizedIntent');
  }

  /// 记录用户修改操作（弱负样本）
  ///
  /// 当用户修改一个识别结果时调用
  void recordModification({
    required String input,
    required String originalIntent,
    required String correctedIntent,
    Map<String, dynamic>? originalEntities,
    Map<String, dynamic>? correctedEntities,
  }) {
    _selfLearningService.recordModification(
      input: input,
      originalIntent: originalIntent,
      correctedIntent: correctedIntent,
      originalEntities: originalEntities,
      correctedEntities: correctedEntities,
    );
    debugPrint('[Agent] 记录修改样本: $input ($originalIntent -> $correctedIntent)');
  }

  /// 记录用户取消操作（负样本）
  ///
  /// 当用户取消一个识别结果时调用
  void recordCancellation({
    required String input,
    required String recognizedIntent,
  }) {
    _selfLearningService.recordCancellation(
      input: input,
      recognizedIntent: recognizedIntent,
    );
    debugPrint('[Agent] 记录取消样本: $input');
  }

  /// 记录执行成功（弱正样本）
  ///
  /// 当操作执行成功时调用
  void recordExecutionSuccess({
    required String input,
    required String executedIntent,
  }) {
    _selfLearningService.recordSuccess(
      input: input,
      executedIntent: executedIntent,
    );
  }

  /// 触发学习过程
  ///
  /// 手动触发或在适当时机自动触发
  Future<LearningResult> triggerLearning() async {
    final result = await _selfLearningService.triggerLearning();
    debugPrint('[Agent] 学习完成: ${result.message}, 新规则数: ${result.newRulesCount}');
    return result;
  }

  // ═══════════════════════════════════════════════════════════════
  // 知识库相关方法
  // ═══════════════════════════════════════════════════════════════

  /// 尝试从知识库回答问题
  ///
  /// 检测是否是帮助类问题，如果是则直接从FAQ回答
  AgentResponse? _tryAnswerFromKnowledgeBase(String input) {
    // 检测是否可能是帮助类问题
    final helpKeywords = [
      '怎么', '如何', '什么是', '是什么', '能不能', '可以吗',
      '帮助', '教我', '告诉我', '介绍', '说明',
    ];

    final isHelpQuestion = helpKeywords.any((k) => input.contains(k));
    if (!isHelpQuestion) return null;

    // 尝试从FAQ匹配
    final faqEntry = _knowledgeBaseService.getBestAnswer(input);
    if (faqEntry == null) return null;

    // 获取语音友好的回答
    final voiceAnswer = faqEntry.voiceGuide ?? faqEntry.answer;

    return AgentResponse(
      text: voiceAnswer,
      type: AgentResponseType.chat,
      data: {
        'source': 'faq',
        'faqId': faqEntry.id,
        'category': faqEntry.category.displayName,
      },
    );
  }

  /// 获取FAQ语音回答
  ///
  /// 直接查询FAQ并返回语音友好的回答
  String getVoiceAnswerFromFAQ(String query) {
    return _knowledgeBaseService.getVoiceAnswer(query);
  }

  /// 获取功能帮助
  ///
  /// 获取特定功能的详细帮助信息
  FeatureHelp? getFeatureHelp(String featureId) {
    return _knowledgeBaseService.getFeatureHelp(featureId);
  }

  /// 获取操作指引语音
  ///
  /// 获取特定功能的语音友好操作指引
  String getOperationGuide(String featureId) {
    return _knowledgeBaseService.getOperationGuide(featureId);
  }

  /// 搜索FAQ
  ///
  /// 返回匹配的FAQ列表
  List<FAQSearchResult> searchFAQ(String query) {
    return _knowledgeBaseService.searchFAQ(query);
  }

  /// 保存知识库数据
  Future<void> saveKnowledgeBaseData() async {
    await _knowledgeBaseService.saveUnmatchedQuestions();
  }

  // ═══════════════════════════════════════════════════════════════
  // 语音自然度相关方法
  // ═══════════════════════════════════════════════════════════════

  /// 获取自然的成功响应
  ///
  /// 避免机械重复，返回变化的成功确认语
  String getNaturalSuccessResponse() {
    return _naturalnessService.getSuccessResponse();
  }

  /// 获取自然的记账成功响应
  ///
  /// 根据金额大小添加适当评价
  String getNaturalBookkeepingResponse({
    double? amount,
    String? category,
    bool isExpense = true,
  }) {
    return _naturalnessService.getBookkeepingSuccessResponse(
      amount: amount,
      category: category,
      isExpense: isExpense,
    );
  }

  /// 获取自然的查询响应前缀
  String getNaturalQueryResponse() {
    return _naturalnessService.getQueryResponse();
  }

  /// 获取自然的确认询问
  String getNaturalConfirmResponse(String content) {
    return _naturalnessService.getConfirmResponse(content);
  }

  /// 获取自然的错误响应
  String getNaturalErrorResponse() {
    return _naturalnessService.getErrorResponse();
  }

  /// 获取自然的没听清响应
  String getNaturalUnclearResponse() {
    return _naturalnessService.getUnclearResponse();
  }

  /// 获取自然的继续引导响应
  String getNaturalContinueResponse() {
    return _naturalnessService.getContinueResponse();
  }

  /// 获取自然的结束语
  String getNaturalGoodbyeResponse() {
    return _naturalnessService.getGoodbyeResponse();
  }

  /// 获取时段问候语
  String getNaturalGreetingResponse() {
    return _naturalnessService.getGreetingResponse();
  }

  /// 为响应添加自然语气
  ///
  /// 根据类型添加适当的语气词
  String addNaturalTone(String response, NaturalToneType type) {
    return _naturalnessService.addNaturalTone(response, type);
  }

  /// 根据情感调整响应
  ///
  /// 根据用户情感上下文调整响应风格
  String adjustResponseForEmotion(String response, EmotionalContext emotion) {
    return _naturalnessService.adjustForEmotion(response, emotion);
  }

  /// 获取TTS情感参数
  ///
  /// 根据响应类型返回适当的TTS参数
  TTSEmotionParams getTTSEmotionParams(ResponseEmotionType type) {
    return TTSEmotionParams.fromResponseType(type);
  }

  /// 清除自然度服务历史
  ///
  /// 重置响应变体计数，允许重复使用
  void clearNaturalnessHistory() {
    _naturalnessService.clearHistory();
  }

  // ═══════════════════════════════════════════════════════════════
  // 生命周期方法
  // ═══════════════════════════════════════════════════════════════

  /// 释放资源
  void dispose() {
    _router.dispose();
    _taskResultSubscription?.cancel();
    _bargeInSubscription?.cancel();
    _taskQueue.dispose();
    _bargeInDetector.dispose();
    _responseController.close();
    _taskCompletionController.close();
    _bargeInController.close();
    _stateListeners.clear();
  }

  /// 语音按钮按下时预热
  Future<void> onVoiceButtonPressed() async {
    await _router.networkMonitor.checkOnVoiceButtonPressed();
  }
}
