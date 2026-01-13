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

  /// 是否启用多意图分解模式
  bool _enableDecomposedMode = true;

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

  /// 任务队列订阅
  StreamSubscription<ActionExecutionResult>? _taskResultSubscription;

  ConversationalAgent({
    HybridIntentRouter? router,
    LLMIntentClassifier? llmClassifier,
    ChatEngine? chatEngine,
    ActionExecutor? actionExecutor,
    ActionRouter? actionRouter,
    ContextManager? contextManager,
    BackgroundTaskQueue? taskQueue,
  })  : _router = router ?? HybridIntentRouter(),
        _llmClassifier = llmClassifier ?? LLMIntentClassifier(),
        _chatEngine = chatEngine ?? ChatEngine(),
        _actionExecutor = actionExecutor ?? ActionExecutor(),
        _actionRouter = actionRouter ?? ActionRouter(),
        _contextManager = contextManager ?? ContextManager(),
        _taskQueue = taskQueue ?? BackgroundTaskQueue() {
    _setupRouter();
    _setupTaskQueue();
  }

  /// 配置任务队列
  void _setupTaskQueue() {
    _taskResultSubscription = _taskQueue.resultStream.listen(_onTaskCompleted);
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

  /// 设置是否启用分解模式
  set enableDecomposedMode(bool value) => _enableDecomposedMode = value;

  /// 获取是否启用分解模式
  bool get enableDecomposedMode => _enableDecomposedMode;

  /// 初始化
  Future<void> initialize() async {
    debugPrint('[Agent] 初始化...');

    // 加载持久化的上下文
    await _contextManager.load();

    // 初始化网络监控
    await _router.networkMonitor.initializeOnAppStart();

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
      // 1. 更新上下文
      _contextManager.addUserInput(input.text);

      // 2. 检查是否有待确认操作
      if (_actionExecutor.hasPendingAction) {
        return _handlePendingAction(input);
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

      // 7. 更新上下文
      _contextManager.addAgentResponse(
        response.text,
        transactionRef: _extractTransactionRef(response),
      );

      // 8. 发布响应
      _responseController.add(response);
      _setState(response.needsFollowUp
          ? AgentState.waitingForInput
          : AgentState.idle);

      return response;
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

    // 构造一个简单的意图结果用于处理确认/取消
    final intent = IntentResult(
      type: RouteType.action,
      confidence: 1.0,
      rawInput: input.text,
      source: RecognitionSource.rule,
    );

    final result = await _actionExecutor.execute(intent);
    return _createActionResponse(result);
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

    return AgentResponse.action(result);
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

  /// 提取分类
  String? _extractCategory(String input) {
    const categoryKeywords = {
      '打车': '交通',
      '出租': '交通',
      '滴滴': '交通',
      '地铁': '交通',
      '公交': '交通',
      '加油': '交通',
      '停车': '交通',
      '午餐': '餐饮',
      '晚餐': '餐饮',
      '早餐': '餐饮',
      '吃饭': '餐饮',
      '外卖': '餐饮',
      '饭': '餐饮',
      '咖啡': '餐饮',
      '奶茶': '餐饮',
      '水果': '餐饮',
      '零食': '餐饮',
      '超市': '购物',
      '淘宝': '购物',
      '京东': '购物',
      '购物': '购物',
      '衣服': '购物',
      '电影': '娱乐',
      '游戏': '娱乐',
      '话费': '通讯',
      '充值': '通讯',
      '房租': '住房',
      '水电': '住房',
      '物业': '住房',
    };

    for (final entry in categoryKeywords.entries) {
      if (input.contains(entry.key)) {
        return entry.value;
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

  double? _extractAmount(String input) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*[元块钱]?').firstMatch(input);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
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

  /// 释放资源
  void dispose() {
    _router.dispose();
    _taskResultSubscription?.cancel();
    _taskQueue.dispose();
    _responseController.close();
    _taskCompletionController.close();
    _stateListeners.clear();
  }

  /// 语音按钮按下时预热
  Future<void> onVoiceButtonPressed() async {
    await _router.networkMonitor.checkOnVoiceButtonPressed();
  }
}
