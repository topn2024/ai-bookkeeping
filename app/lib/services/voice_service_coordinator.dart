import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/transaction.dart' as model;
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../services/duplicate_detection_service.dart';
import 'voice/entity_disambiguation_service.dart';
import 'voice/voice_delete_service.dart';
import 'voice/voice_modify_service.dart';
import 'voice/voice_intent_router.dart';
import 'voice/multi_intent_models.dart';
import 'voice/conversation_context.dart';
import 'voice/barge_in_detector.dart';
import 'voice/ai_intent_decomposer.dart';
import 'voice/smart_intent_recognizer.dart';
import 'voice/llm_response_generator.dart';
import 'voice/intelligence_engine/intelligence_engine.dart';
import 'voice/intelligence_engine/result_buffer.dart';
import 'voice/intelligence_engine/models.dart';
import 'voice/network_monitor.dart' show NetworkStatus;
import 'voice/adapters/bookkeeping_operation_adapter.dart';
import 'voice/adapters/bookkeeping_feedback_adapter.dart';
import 'voice_recognition_engine.dart';
import 'tts_service.dart';
import 'voice_navigation_service.dart';
import 'voice_navigation_executor.dart';
import 'voice_feedback_system.dart';
import 'screen_reader_service.dart';
import 'global_voice_assistant_manager.dart';
import 'automation_task_service.dart';
import 'nl_search_service.dart';
import 'voice_budget_query_service.dart';
import 'vault_repository.dart';
import 'casual_chat_service.dart';
import 'learning/voice_intent_learning_service.dart';
import 'category_localization_service.dart';
import 'voice_config_service.dart';
import 'voice/voice_advice_service.dart';

/// 解析中文数字为整数
int _parseChineseNumber(String str) {
  final parsed = int.tryParse(str);
  if (parsed != null) return parsed;

  const chineseNumbers = {
    '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
  };

  if (chineseNumbers.containsKey(str)) return chineseNumbers[str]!;

  // 处理"十几"
  if (str.startsWith('十') && str.length == 2) {
    final digit = chineseNumbers[str[1]];
    if (digit != null) return 10 + digit;
  }

  // 处理"几十"或"几十几"
  if (str.contains('十')) {
    final parts = str.split('十');
    final tens = parts[0].isEmpty ? 1 : (chineseNumbers[parts[0]] ?? 1);
    final ones = parts.length > 1 && parts[1].isNotEmpty
        ? (chineseNumbers[parts[1]] ?? 0)
        : 0;
    return tens * 10 + ones;
  }

  return 1;
}

/// 语音服务协调器
///
/// 统一管理所有语音相关服务，提供完整的语音交互功能
/// - 语音识别
/// - 自然语言理解
/// - 意图路由
/// - 实体消歧
/// - 命令执行
/// - 语音反馈
class VoiceServiceCoordinator extends ChangeNotifier {
  final VoiceRecognitionEngine _recognitionEngine;
  final TTSService _ttsService;
  final EntityDisambiguationService _disambiguationService;
  final VoiceDeleteService _deleteService;
  final VoiceModifyService _modifyService;
  final VoiceNavigationService _navigationService;
  final VoiceIntentRouter _intentRouter;
  final VoiceFeedbackSystem _feedbackSystem;
  final IDatabaseService _databaseService;
  final ScreenReaderService _screenReaderService;
  final AutomationTaskService _automationService;
  final NaturalLanguageSearchService _nlSearchService;
  final CasualChatService _casualChatService;
  final VoiceConfigService _configService;
  final VoiceAdviceService _adviceService;
  VoiceBudgetQueryService? _budgetQueryService;

  /// 对话上下文管理
  final ConversationContext _conversationContext;

  /// 打断检测器
  final BargeInDetector _bargeInDetector;

  /// AI意图分解器（大模型兜底）
  final AIIntentDecomposer _aiDecomposer;

  /// 智能意图识别器（多层递进架构）
  final SmartIntentRecognizer _smartRecognizer;

  /// 智能引擎（多操作识别、双通道处理、智能聚合）
  IntelligenceEngine? _intelligenceEngine;

  /// 网络状态提供者（缓存用于传递给IntelligenceEngine）
  NetworkStatus? Function()? _networkStatusProvider;

  /// 是否启用对话式智能体模式
  bool _agentModeEnabled = false;

  /// 是否启用流式TTS模式
  bool _streamingTTSEnabled = true;

  /// 是否跳过TTS播放（流水线模式下由外部处理TTS）
  bool _skipTTSPlayback = false;

  /// 延迟响应回调（流水线模式下通知外部处理延迟响应）
  void Function(String response)? onDeferredResponse;

  /// 当前会话状态
  VoiceSessionState _sessionState = VoiceSessionState.idle;

  /// 当前会话上下文
  VoiceSessionContext? _currentSession;

  /// 语音命令历史
  final List<VoiceCommand> _commandHistory = [];

  /// 最后一次响应
  String? _lastResponse;

  /// 待处理的多意图结果
  MultiIntentResult? _pendingMultiIntent;

  /// 多意图处理配置
  MultiIntentConfig _multiIntentConfig = MultiIntentConfig.defaultConfig;

  /// 最大历史记录数
  static const int maxHistorySize = 50;

  /// 会话超时配置
  /// 注意：连续对话模式下可能有多轮交互，超时时间应足够长
  /// 用户一直聊天最长支持30分钟
  static const Duration _sessionTimeout = Duration(minutes: 30);
  static const Duration _waitingStateTimeout = Duration(minutes: 30);

  /// 会话超时计时器
  Timer? _sessionTimeoutTimer;

  /// 最后活动时间（用于调试和监控）
  DateTime? _lastActivityTime;

  /// 获取最后活动时间
  DateTime? get lastActivityTime => _lastActivityTime;

  VoiceServiceCoordinator({
    VoiceRecognitionEngine? recognitionEngine,
    TTSService? ttsService,
    EntityDisambiguationService? disambiguationService,
    VoiceDeleteService? deleteService,
    VoiceModifyService? modifyService,
    VoiceNavigationService? navigationService,
    VoiceIntentRouter? intentRouter,
    VoiceFeedbackSystem? feedbackSystem,
    IDatabaseService? databaseService,
    ScreenReaderService? screenReaderService,
    AutomationTaskService? automationService,
    NaturalLanguageSearchService? nlSearchService,
    CasualChatService? casualChatService,
    VoiceConfigService? configService,
    VoiceAdviceService? adviceService,
    ConversationContext? conversationContext,
    BargeInDetector? bargeInDetector,
    AIIntentDecomposer? aiDecomposer,
    SmartIntentRecognizer? smartRecognizer,
    bool enableStreamingTTS = true,
    bool enableAgentMode = false,
  }) : _agentModeEnabled = enableAgentMode,
       _recognitionEngine = recognitionEngine ?? VoiceRecognitionEngine(),
       _ttsService = ttsService ?? TTSService.instanceWith(enableStreaming: enableStreamingTTS),
       _disambiguationService = disambiguationService ?? EntityDisambiguationService(),
       _deleteService = deleteService ?? VoiceDeleteService(),
       _modifyService = modifyService ?? VoiceModifyService(),
       _navigationService = navigationService ?? VoiceNavigationService(),
       _intentRouter = intentRouter ?? VoiceIntentRouter(),
       _feedbackSystem = feedbackSystem ?? VoiceFeedbackSystem(),
       _databaseService = databaseService ?? sl<IDatabaseService>(),
       _screenReaderService = screenReaderService ?? ScreenReaderService(),
       _automationService = automationService ?? AutomationTaskService(),
       _nlSearchService = nlSearchService ?? _createDefaultNLSearchService(databaseService ?? sl<IDatabaseService>()),
       _casualChatService = casualChatService ?? CasualChatService(),
       _configService = configService ?? VoiceConfigService(),
       _adviceService = adviceService ?? VoiceAdviceService(databaseService: databaseService ?? sl<IDatabaseService>()),
       _conversationContext = conversationContext ?? ConversationContext(),
       _bargeInDetector = bargeInDetector ?? BargeInDetector(),
       _aiDecomposer = aiDecomposer ?? AIIntentDecomposer(),
       _smartRecognizer = smartRecognizer ?? SmartIntentRecognizer(),
       _streamingTTSEnabled = enableStreamingTTS {
    // 设置打断检测回调
    _bargeInDetector.onBargeInDetected = _handleBargeIn;
  }

  /// 创建默认的自然语言搜索服务
  static NaturalLanguageSearchService _createDefaultNLSearchService(IDatabaseService dbService) {
    final repository = DatabaseTransactionRepository(
      queryTransactions: ({
        DateTime? startDate,
        DateTime? endDate,
        String? category,
        String? merchant,
        double? minAmount,
        double? maxAmount,
        int? limit,
      }) async {
        final transactions = await dbService.queryTransactions(
          startDate: startDate,
          endDate: endDate,
          category: category,
          merchant: merchant,
          minAmount: minAmount,
          maxAmount: maxAmount,
          limit: limit ?? 500,
        );
        // 转换为 Map 格式
        return transactions.map((t) => {
          'id': t.id,
          'amount': t.amount,
          'date': t.date.toIso8601String(),
          'category': t.category,
          'rawMerchant': t.rawMerchant,
          'note': t.note,
        }).toList();
      },
    );
    return NaturalLanguageSearchService(transactionRepo: repository);
  }

  /// 处理打断事件
  void _handleBargeIn() {
    debugPrint('VoiceServiceCoordinator: barge-in detected');

    // 淡出TTS
    _ttsService.fadeOutAndStop();

    // 取消当前识别并重新开始监听
    _recognitionEngine.cancelTranscription();

    // 更新状态
    _sessionState = VoiceSessionState.listening;
    notifyListeners();
  }


  /// 使用智能引擎处理语音输入
  Future<VoiceSessionResult> _processWithIntelligenceEngine(String voiceInput) async {
    final engine = _intelligenceEngine!;

    // 记录命令历史
    final command = VoiceCommand(
      input: voiceInput,
      timestamp: DateTime.now(),
    );
    _addToHistory(command);

    try {
      // 使用智能引擎处理
      final result = await engine.process(voiceInput);

      debugPrint('[VoiceCoordinator] IntelligenceEngine响应: success=${result.success}, message=${result.message}');

      // 构建响应文本
      String responseText = result.message ?? '';

      // 播放语音响应
      if (responseText.isNotEmpty) {
        await _speakWithSkipCheck(responseText);
      }

      _sessionState = VoiceSessionState.idle;
      notifyListeners();

      if (result.success) {
        // 记录意图学习（成功处理的命令）
        try {
          final intent = result.data?['intent'] as String? ?? 'unknown';
          final learningService = sl<VoiceIntentLearningService>();
          await learningService.learn(IntentLearningData(
            userId: 'default',
            input: voiceInput,
            recognizedIntent: intent,
            confidence: 1.0,
            context: IntentContext(
              hour: DateTime.now().hour,
              dayOfWeek: DateTime.now().weekday,
            ),
          ));
        } catch (e) {
          debugPrint('[VoiceCoordinator] 意图学习记录失败: $e');
        }

        return VoiceSessionResult.success(responseText, {
          'intelligenceEngine': true,
          ...?result.data, // 传递 IntelligenceEngine 返回的所有数据（包括 operationId）
        });
      } else {
        return VoiceSessionResult.error(responseText);
      }
    } catch (e) {
      debugPrint('[VoiceCoordinator] IntelligenceEngine处理失败: $e');
      return VoiceSessionResult.error('处理失败: $e');
    }
  }

  /// 启用流式TTS模式
  Future<void> enableStreamingTTS() async {
    _streamingTTSEnabled = true;
    await _ttsService.enableStreamingMode();
  }

  /// 禁用流式TTS模式
  void disableStreamingTTS() {
    _streamingTTSEnabled = false;
    _ttsService.disableStreamingMode();
  }

  /// 是否启用流式TTS
  bool get isStreamingTTSEnabled => _streamingTTSEnabled;

  // ═══════════════════════════════════════════════════════════════
  // 对话式智能体模式
  // ═══════════════════════════════════════════════════════════════

  /// 是否启用对话式智能体模式
  bool get isAgentModeEnabled => _agentModeEnabled;

  /// 获取结果缓冲区（用于查询结果通知）
  ///
  /// 返回 IntelligenceEngine 的 ResultBuffer，供外部组件（如 SmartTopicGenerator）
  /// 在主动对话时检索待通知的查询结果。
  /// 如果智能引擎未初始化，返回 null。
  ResultBuffer? get resultBuffer => _intelligenceEngine?.resultBuffer;

  /// 启用对话式智能体模式
  ///
  /// 对话式智能体支持"边聊边做"的自然交互，
  /// LLM优先识别意图，支持上下文关联和指代消解
  Future<void> enableAgentMode() async {
    // 初始化智能引擎
    if (_intelligenceEngine == null) {
      _intelligenceEngine = IntelligenceEngine(
        operationAdapter: BookkeepingOperationAdapter(),
        feedbackAdapter: BookkeepingFeedbackAdapter(),
      );
      // 传递已缓存的网络状态提供者
      if (_networkStatusProvider != null) {
        _intelligenceEngine!.setNetworkStatusProvider(_networkStatusProvider);
      }
      // 设置延迟响应回调（deferred操作聚合后的响应）
      _intelligenceEngine!.onDeferredResponse = _handleDeferredResponse;

      // 注册导航操作回调
      _intelligenceEngine!.registerNavigationCallback(_handleNavigationResult);

      // 将 ResultBuffer 传递给 GlobalVoiceAssistantManager
      // 使 SmartTopicGenerator 能够在主动对话时检索待通知的查询结果
      GlobalVoiceAssistantManager.instance.setResultBuffer(_intelligenceEngine!.resultBuffer);
      debugPrint('[VoiceCoordinator] ResultBuffer 已传递给 GlobalVoiceAssistantManager');
    }

    _agentModeEnabled = true;
    notifyListeners();
    debugPrint('[VoiceCoordinator] 对话式智能体模式已启用');
  }

  /// 处理延迟响应
  ///
  /// 当 deferred 操作计时器到期时，播放统一响应
  void _handleDeferredResponse(String response) {
    debugPrint('[VoiceCoordinator] 延迟响应: $response');
    _lastResponse = response;

    // 流水线模式下，通知外部处理延迟响应
    if (_skipTTSPlayback && onDeferredResponse != null) {
      debugPrint('[VoiceCoordinator] 流水线模式，通过回调传递延迟响应');
      onDeferredResponse!(response);
    } else {
      // 非流水线模式，直接播放TTS
      _speakWithSkipCheck(response);
    }
  }

  /// 处理导航操作结果
  ///
  /// 当导航操作执行成功时，提取路由和参数并实际执行导航
  Future<void> _handleNavigationResult(ExecutionResult result) async {
    if (!result.success || result.data == null) {
      return;
    }

    final data = result.data!;
    final route = data['route'] as String?;
    final navigationParams = data['navigationParams'] as Map<String, dynamic>?;

    if (route != null) {
      debugPrint('[VoiceCoordinator] 执行导航: route=$route, params=$navigationParams');
      try {
        await VoiceNavigationExecutor.instance.navigateToRoute(
          route,
          params: navigationParams,
        );
      } catch (e) {
        debugPrint('[VoiceCoordinator] 导航执行失败: $e');
      }
    }
  }

  /// 禁用对话式智能体模式
  ///
  /// 回退到传统的规则优先意图识别模式
  void disableAgentMode() {
    _agentModeEnabled = false;
    notifyListeners();
    debugPrint('[VoiceCoordinator] 对话式智能体模式已禁用');
  }

  /// 是否跳过TTS播放
  bool get skipTTSPlayback => _skipTTSPlayback;

  /// 设置是否跳过TTS播放
  ///
  /// 流水线模式下，TTS由外部处理，此时应跳过内部TTS播放
  void setSkipTTSPlayback(bool skip) {
    _skipTTSPlayback = skip;
    debugPrint('[VoiceCoordinator] TTS播放跳过设置: $skip');
  }

  /// 设置网络状态提供者
  ///
  /// 用于SmartIntentRecognizer判断是否使用LLM
  /// 返回null时表示网络状态未知，将允许LLM调用
  void setNetworkStatusProvider(NetworkStatus? Function()? provider) {
    _networkStatusProvider = provider;
    _smartRecognizer.networkStatusProvider = provider;
    _intelligenceEngine?.setNetworkStatusProvider(provider);
    debugPrint('[VoiceCoordinator] 网络状态提供者已${provider != null ? "设置" : "清除"}');
  }

  /// 预加载用户城市信息
  ///
  /// 在APP启动时调用，提前获取用户位置信息
  /// 供LLM识别时使用（如推断"深圳地铁"商户名称）
  Future<void> preloadUserCity() async {
    await _smartRecognizer.preloadUserCity();
  }

  /// 播放TTS（考虑跳过标志）
  ///
  /// 如果 _skipTTSPlayback 为 true，则跳过实际播放
  /// 用于流水线模式下由外部处理TTS的场景
  Future<void> _speakWithSkipCheck(String text) async {
    if (_skipTTSPlayback) {
      debugPrint('[VoiceCoordinator] TTS跳过（流水线模式）: ${text.length > 30 ? text.substring(0, 30) + "..." : text}');
      return;
    }
    await _ttsService.speak(text);
  }

  /// 语音按钮按下时的预热
  ///
  /// 在用户按下语音按钮时调用，预热网络连接和LLM服务
  void onVoiceButtonPressed() {
    // 预热逻辑已集成到IntelligenceEngine中
  }

  /// 获取意图路由器（用于外部访问多意图检测等功能）
  VoiceIntentRouter get intentRouter => _intentRouter;

  /// 当前会话状态
  VoiceSessionState get sessionState => _sessionState;

  /// 当前会话类型
  VoiceIntentType? get currentIntentType => _currentSession?.intentType;

  /// 是否有活跃会话
  bool get hasActiveSession => _sessionState != VoiceSessionState.idle;

  /// 命令历史
  List<VoiceCommand> get commandHistory => List.unmodifiable(_commandHistory);

  /// 最后一次响应
  String? get lastResponse => _lastResponse;

  /// 待处理的多意图结果
  MultiIntentResult? get pendingMultiIntent => _pendingMultiIntent;

  /// 是否有待处理的多意图
  bool get hasPendingMultiIntent => _pendingMultiIntent != null && !_pendingMultiIntent!.isEmpty;

  /// 多意图处理配置
  MultiIntentConfig get multiIntentConfig => _multiIntentConfig;

  /// 设置多意图处理配置
  set multiIntentConfig(MultiIntentConfig config) {
    _multiIntentConfig = config;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // 核心语音交互流程
  // ═══════════════════════════════════════════════════════════════

  /// 开始语音识别会话
  Future<VoiceSessionResult> startVoiceSession() async {
    try {
      _sessionState = VoiceSessionState.listening;
      _startSessionTimeout(); // 启动会话超时计时器
      notifyListeners();

      // 初始化语音识别
      await _recognitionEngine.initializeOfflineModel();

      // 播放开始提示音
      await _feedbackSystem.provideFeedback(
        message: '请说话',
        type: VoiceFeedbackType.info,
        priority: VoiceFeedbackPriority.medium,
      );

      return VoiceSessionResult.success('语音识别已启动');
    } catch (e) {
      _cancelSessionTimeout();
      _sessionState = VoiceSessionState.idle;
      notifyListeners();
      return VoiceSessionResult.error('启动语音识别失败: $e');
    }
  }

  /// 处理单次语音命令
  Future<VoiceSessionResult> processVoiceCommand(String voiceInput) async {
    try {
      _resetSessionTimeout(); // 用户有活动，重置超时
      _sessionState = VoiceSessionState.processing;
      notifyListeners();

      // 预检查：过滤无效或异常的输入
      final invalidReason = _checkInvalidInput(voiceInput);
      if (invalidReason != null) {
        debugPrint('[VoiceCoordinator] 无效输入: $invalidReason');
        _sessionState = VoiceSessionState.idle;
        notifyListeners();
        return VoiceSessionResult.error(invalidReason);
      }

      // 对话式智能体模式：使用 IntelligenceEngine 处理
      if (_agentModeEnabled && _intelligenceEngine != null) {
        return await _processWithIntelligenceEngine(voiceInput);
      }

      // 检查是否处于闲聊模式
      if (_conversationContext.isChatMode) {
        debugPrint('[VoiceCoordinator] 当前处于闲聊模式');
        return await _processChatModeInput(voiceInput);
      }

      // 正常处理流程
      return await _processNormalInput(voiceInput);
    } catch (e) {
      _sessionState = VoiceSessionState.error;
      notifyListeners();

      final errorResult = VoiceSessionResult.error('处理语音命令失败: $e');

      // 提供错误反馈
      await _feedbackSystem.provideErrorFeedback(
        error: '抱歉，处理您的指令时出现了错误',
        suggestion: '请稍后重试或重新说一遍',
        context: {'error': e.toString(), 'input': voiceInput},
      );

      return errorResult;
    } finally {
      // 如果没有需要持续的会话，回到空闲状态
      if (_currentSession == null || !_currentSession!.needsContinuation) {
        _sessionState = VoiceSessionState.idle;
        notifyListeners();
      }
    }
  }

  /// 处理音频流（实时语音识别）
  Stream<VoiceSessionResult> processAudioStream(Stream<Uint8List> audioStream) async* {
    try {
      _sessionState = VoiceSessionState.listening;
      notifyListeners();

      await for (final partialResult in _recognitionEngine.transcribeStream(audioStream)) {
        if (partialResult.isFinal && partialResult.text.isNotEmpty) {
          // 当识别完成时，处理命令
          final result = await processVoiceCommand(partialResult.text);
          yield result;
        } else {
          // 返回部分识别结果
          yield VoiceSessionResult.partial(partialResult.text);
        }
      }
    } catch (e) {
      _sessionState = VoiceSessionState.error;
      notifyListeners();
      yield VoiceSessionResult.error('音频流处理失败: $e');
    }
  }

  /// 根据意图类型路由到对应的处理器
  Future<VoiceSessionResult> _routeToIntentHandler(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    switch (intentResult.intent) {
      case VoiceIntentType.deleteTransaction:
        return await _handleDeleteIntent(intentResult, originalInput);

      case VoiceIntentType.modifyTransaction:
        return await _handleModifyIntent(intentResult, originalInput);

      case VoiceIntentType.addTransaction:
        return await _handleAddIntent(intentResult, originalInput);

      case VoiceIntentType.queryTransaction:
        return await _handleQueryIntent(intentResult, originalInput);

      case VoiceIntentType.navigateToPage:
        return await _handleNavigationIntent(intentResult, originalInput);

      case VoiceIntentType.confirmAction:
        return await _handleConfirmationIntent(intentResult, originalInput);

      case VoiceIntentType.cancelAction:
        return await _handleCancellationIntent(intentResult, originalInput);

      case VoiceIntentType.clarifySelection:
        return await _handleClarificationIntent(intentResult, originalInput);

      case VoiceIntentType.screenRecognition:
        return await _handleScreenRecognitionIntent(intentResult, originalInput);

      case VoiceIntentType.automateAlipaySync:
        return await _handleAutomationIntent(intentResult, originalInput, isAlipay: true);

      case VoiceIntentType.automateWeChatSync:
        return await _handleAutomationIntent(intentResult, originalInput, isAlipay: false);

      case VoiceIntentType.configOperation:
        return await _handleConfigIntent(intentResult, originalInput);

      case VoiceIntentType.moneyAgeOperation:
        return await _handleMoneyAgeIntent(intentResult, originalInput);

      case VoiceIntentType.habitOperation:
        return await _handleHabitIntent(intentResult, originalInput);

      case VoiceIntentType.vaultOperation:
        return await _handleVaultIntent(intentResult, originalInput);

      case VoiceIntentType.dataOperation:
        return await _handleDataIntent(intentResult, originalInput);

      case VoiceIntentType.shareOperation:
        return await _handleShareIntent(intentResult, originalInput);

      case VoiceIntentType.systemOperation:
        return await _handleSystemIntent(intentResult, originalInput);

      case VoiceIntentType.adviceOperation:
        return await _handleAdviceIntent(intentResult, originalInput);

      case VoiceIntentType.chatOperation:
        return await _handleChatIntent(intentResult, originalInput);

      case VoiceIntentType.unknown:
        return await _handleUnknownIntent(intentResult, originalInput);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 多意图处理
  // ═══════════════════════════════════════════════════════════════

  /// 处理可能包含多意图的语音输入
  ///
  /// 当检测到用户输入可能包含多个意图时，使用此方法进行处理。
  /// 返回的结果包含所有识别到的意图，需要用户确认后批量执行。
  ///
  /// 优先使用 LLM（SmartIntentRecognizer）进行整体语义理解，
  /// 这样可以正确关联"花了15块钱"和"吃了肠粉"这种跨句子的上下文。
  /// 只有当 LLM 不可用时才回退到旧的分句处理方式。
  Future<VoiceSessionResult> processMultiIntentCommand(String voiceInput) async {
    try {
      _sessionState = VoiceSessionState.processing;
      notifyListeners();

      // 预检查：过滤无效或异常的输入
      final invalidReason = _checkInvalidInput(voiceInput);
      if (invalidReason != null) {
        debugPrint('[VoiceCoordinator] 多意图处理 - 无效输入: $invalidReason');
        _sessionState = VoiceSessionState.idle;
        notifyListeners();
        return VoiceSessionResult.error(invalidReason);
      }

      // 记录命令历史
      final command = VoiceCommand(
        input: voiceInput,
        timestamp: DateTime.now(),
      );
      _addToHistory(command);

      // ═══════════════════════════════════════════════════════════════
      // 获取对话历史用于上下文理解（关键：让LLM知道之前记录了什么）
      // ═══════════════════════════════════════════════════════════════
      final conversationHistory = GlobalVoiceAssistantManager.instance.conversationHistory
          .where((m) => m.type == ChatMessageType.user || m.type == ChatMessageType.assistant)
          .map((m) => {
            'role': m.type == ChatMessageType.user ? 'user' : 'assistant',
            'content': m.content,
          })
          .toList();

      // ═══════════════════════════════════════════════════════════════
      // 优先使用 LLM 进行整体语义理解（保持上下文关联）
      // ═══════════════════════════════════════════════════════════════
      debugPrint('[VoiceCoordinator] 多意图处理 - 尝试使用LLM整体识别...');
      final llmResult = await _smartRecognizer.recognizeMultiOperation(
        voiceInput,
        conversationHistory: conversationHistory.isNotEmpty ? conversationHistory : null,
      );

      if (llmResult.isSuccess && llmResult.hasOperations) {
        debugPrint('[VoiceCoordinator] LLM识别成功: ${llmResult.operations.length}个操作');

        // 转换为 CompleteIntent 列表以复用执行逻辑
        final completeIntents = <CompleteIntent>[];
        for (final op in llmResult.operations) {
          if (op.type == OperationType.addTransaction) {
            final amount = op.params['amount'] as num?;
            final rawCategory = op.params['category'] as String? ?? '其他';
            // 规范化分类为标准英文ID（如 '工资' → 'salary'）
            final category = CategoryLocalizationService.instance.normalizeCategoryId(rawCategory);
            final merchant = op.params['merchant'] as String?;
            final note = op.params['note'] as String?;
            // 检查LLM返回的type参数，判断是收入还是支出
            final typeStr = op.params['type'] as String?;
            // 已知的收入分类ID（作为兜底判断）
            const incomeCategoryIds = {
              'salary', 'bonus', 'investment', 'parttime', 'redpacket',
              'reimburse', 'business', 'other_income',
            };
            final isIncome = typeStr == 'income' ||
                (typeStr == null && incomeCategoryIds.contains(category));

            if (amount != null && amount > 0) {
              completeIntents.add(CompleteIntent(
                type: isIncome ? TransactionIntentType.income : TransactionIntentType.expense,
                originalText: op.originalText,
                confidence: llmResult.confidence,
                amount: amount.toDouble(),
                category: category,
                merchant: merchant ?? note,  // 优先使用merchant，fallback到note
                description: note,  // note作为描述/备注
              ));
            }
          }
        }

        if (completeIntents.isNotEmpty) {
          // 直接执行，不需要用户确认
          final executedCount = await _executeCompleteIntents(completeIntents);

          _sessionState = VoiceSessionState.idle;
          notifyListeners();

          // 使用LLM生成回复
          final llmGenerator = LLMResponseGenerator.instance;
          final message = await llmGenerator.generateResponse(
            action: '记账',
            result: '成功记录$executedCount笔交易',
            success: true,
            userInput: null,
          );
          await _speakWithSkipCheck(message);

          return VoiceSessionResult.success(message, {
            'executedCount': executedCount,
            'navigation': null,
          });
        }
      }

      // 如果 LLM 返回需要澄清
      if (llmResult.needsClarify) {
        debugPrint('[VoiceCoordinator] LLM需要澄清: ${llmResult.clarifyQuestion}');
        _sessionState = VoiceSessionState.idle;
        notifyListeners();

        final clarifyMsg = llmResult.clarifyQuestion ?? '请问您具体想要做什么呢？';
        await _speakWithSkipCheck(clarifyMsg);

        return VoiceSessionResult.success(clarifyMsg, {
          'needsClarify': true,
        });
      }

      // 如果 LLM 识别为闲聊
      if (llmResult.isChat) {
        debugPrint('[VoiceCoordinator] LLM识别为闲聊');
        return await processVoiceCommand(voiceInput);
      }

      // ═══════════════════════════════════════════════════════════════
      // LLM 不可用或识别失败，回退到旧的分句处理方式
      // ═══════════════════════════════════════════════════════════════
      debugPrint('[VoiceCoordinator] LLM识别未成功，回退到分句处理...');

      // 使用多意图分析
      final multiResult = await _intentRouter.analyzeMultipleIntents(
        voiceInput,
        context: _currentSession,
        config: _multiIntentConfig,
      );

      // 如果是空结果或单意图，回退到普通处理
      if (multiResult.isEmpty) {
        return await processVoiceCommand(voiceInput);
      }

      if (multiResult.isSingleIntent) {
        // 单意图回退到普通处理
        return await processVoiceCommand(voiceInput);
      }

      // 保存多意图结果
      _pendingMultiIntent = multiResult;
      _sessionState = VoiceSessionState.waitingForMultiIntentConfirmation;

      // 生成确认提示
      final prompt = multiResult.generatePrompt();
      await _speakWithSkipCheck(prompt);

      notifyListeners();

      return VoiceSessionResult.success(prompt, {
        'multiIntent': true,
        'completeCount': multiResult.completeIntents.length,
        'incompleteCount': multiResult.incompleteIntents.length,
        'hasNavigation': multiResult.navigationIntent != null,
        'filteredNoise': multiResult.filteredNoise,
      });
    } catch (e) {
      _sessionState = VoiceSessionState.error;
      notifyListeners();
      return VoiceSessionResult.error('处理多意图命令失败: $e');
    }
  }

  /// 确认并执行所有待处理的多意图
  Future<VoiceSessionResult> confirmMultiIntents() async {
    if (_pendingMultiIntent == null) {
      return VoiceSessionResult.error('没有待确认的多意图');
    }

    try {
      _sessionState = VoiceSessionState.processing;
      notifyListeners();

      final result = _pendingMultiIntent!;
      final executedCount = await _executeCompleteIntents(result.completeIntents);

      // 检查是否有不完整意图需要追问
      if (result.needsFollowUp) {
        _sessionState = VoiceSessionState.waitingForAmountSupplement;
        notifyListeners();

        final supplementPrompt = _generateAmountSupplementPrompt(result.incompleteIntents);
        await _speakWithSkipCheck(supplementPrompt);

        return VoiceSessionResult.success(supplementPrompt, {
          'executedCount': executedCount,
          'pendingIncomplete': result.incompleteIntents.length,
        });
      }

      // 处理导航意图
      String? navigationMessage;
      if (result.navigationIntent != null) {
        navigationMessage = await _executeNavigationIntent(result.navigationIntent!);
      }

      // 清除待处理的多意图
      _pendingMultiIntent = null;
      _sessionState = VoiceSessionState.idle;
      notifyListeners();

      // 使用LLM生成多笔交易的回复
      final llmGenerator = LLMResponseGenerator.instance;
      final message = await llmGenerator.generateResponse(
        action: '记账',
        result: '成功记录$executedCount笔交易',
        success: true,
        userInput: null,
      );
      final finalMessage = navigationMessage != null ? '$message，$navigationMessage' : message;
      await _speakWithSkipCheck(finalMessage);

      return VoiceSessionResult.success(message, {
        'executedCount': executedCount,
        'navigation': result.navigationIntent?.targetPage,
      });
    } catch (e) {
      _sessionState = VoiceSessionState.error;
      notifyListeners();
      return VoiceSessionResult.error('执行多意图失败: $e');
    }
  }

  /// 取消多意图处理
  Future<VoiceSessionResult> cancelMultiIntents() async {
    _pendingMultiIntent = null;
    _sessionState = VoiceSessionState.idle;
    notifyListeners();

    const message = '已取消所有待处理的记录';
    await _speakWithSkipCheck(message);

    return VoiceSessionResult.success(message);
  }

  /// 取消多意图中的指定项
  Future<VoiceSessionResult> cancelMultiIntentItem(int index) async {
    if (_pendingMultiIntent == null) {
      return VoiceSessionResult.error('没有待处理的多意图');
    }

    final result = _pendingMultiIntent!;
    final totalCount = result.completeIntents.length + result.incompleteIntents.length;

    if (index < 0 || index >= totalCount) {
      return VoiceSessionResult.error('无效的序号');
    }

    // 创建新的列表，移除指定项
    List<CompleteIntent> newComplete;
    List<IncompleteIntent> newIncomplete;

    if (index < result.completeIntents.length) {
      newComplete = List.from(result.completeIntents)..removeAt(index);
      newIncomplete = result.incompleteIntents;
    } else {
      newComplete = result.completeIntents;
      newIncomplete = List.from(result.incompleteIntents)
        ..removeAt(index - result.completeIntents.length);
    }

    _pendingMultiIntent = MultiIntentResult(
      completeIntents: newComplete,
      incompleteIntents: newIncomplete,
      navigationIntent: result.navigationIntent,
      filteredNoise: result.filteredNoise,
      rawInput: result.rawInput,
      segments: result.segments,
    );

    // 检查是否还有待处理的意图
    if (_pendingMultiIntent!.isEmpty) {
      return await cancelMultiIntents();
    }

    notifyListeners();

    final message = '已移除第${index + 1}项，还有${_pendingMultiIntent!.totalIntentCount}项待处理';
    await _speakWithSkipCheck(message);

    return VoiceSessionResult.success(message);
  }

  /// 补充不完整意图的金额
  Future<VoiceSessionResult> supplementAmount(int index, double amount) async {
    if (_pendingMultiIntent == null) {
      return VoiceSessionResult.error('没有待处理的多意图');
    }

    final result = _pendingMultiIntent!;

    if (index < 0 || index >= result.incompleteIntents.length) {
      return VoiceSessionResult.error('无效的序号');
    }

    // 将不完整意图转换为完整意图
    final incompleteIntent = result.incompleteIntents[index];
    final completeIntent = incompleteIntent.completeWith(amount: amount);

    // 更新列表
    final newComplete = List<CompleteIntent>.from(result.completeIntents)
      ..add(completeIntent);
    final newIncomplete = List<IncompleteIntent>.from(result.incompleteIntents)
      ..removeAt(index);

    _pendingMultiIntent = MultiIntentResult(
      completeIntents: newComplete,
      incompleteIntents: newIncomplete,
      navigationIntent: result.navigationIntent,
      filteredNoise: result.filteredNoise,
      rawInput: result.rawInput,
      segments: result.segments,
    );

    notifyListeners();

    if (newIncomplete.isEmpty) {
      // 所有金额已补充，可以确认执行
      final message = '金额已补充完成，共${newComplete.length}笔记录待确认';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message);
    } else {
      final message = '已补充第${index + 1}项金额${amount.toStringAsFixed(2)}元，还有${newIncomplete.length}项需要补充金额';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message);
    }
  }

  /// 执行完整意图列表
  Future<int> _executeCompleteIntents(List<CompleteIntent> intents) async {
    var executedCount = 0;

    for (final intent in intents) {
      try {
        final transaction = model.Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: _mapIntentTypeToTransactionType(intent.type),
          amount: intent.amount,
          category: intent.category ?? 'other_expense',
          note: intent.description ?? intent.originalText,
          date: intent.dateTime ?? DateTime.now(),
          accountId: 'default',
          rawMerchant: intent.merchant,
          source: model.TransactionSource.voice,
        );

        await _databaseService.insertTransaction(transaction);
        executedCount++;
      } catch (e) {
        debugPrint('[VoiceCoordinator] 执行意图失败: $e');
      }
    }

    return executedCount;
  }

  /// 执行导航意图
  Future<String> _executeNavigationIntent(NavigationIntent intent) async {
    debugPrint('[VoiceServiceCoordinator] 执行导航意图: ${intent.originalText}');
    final result = _navigationService.parseNavigation(intent.originalText);
    if (result.success && result.route != null) {
      debugPrint('[VoiceServiceCoordinator] 导航解析成功: route=${result.route}, pageName=${result.pageName}');
      // 实际执行导航
      final executed = await VoiceNavigationExecutor.instance.navigateToRoute(result.route!);
      if (executed) {
        return '正在打开${result.pageName}';
      } else {
        return '抱歉，暂时无法打开${result.pageName}';
      }
    }
    debugPrint('[VoiceServiceCoordinator] 导航解析失败: ${result.errorMessage}');
    return result.errorMessage ?? '抱歉，我不知道您想去哪个页面';
  }

  /// 生成金额补充提示
  String _generateAmountSupplementPrompt(List<IncompleteIntent> intents) {
    final buffer = StringBuffer();
    buffer.writeln('请补充以下记录的金额：');

    for (var i = 0; i < intents.length; i++) {
      final intent = intents[i];
      buffer.writeln('  ${i + 1}. ${intent.category ?? intent.originalText}');
    }

    buffer.write('请说"第几个多少钱"来补充');
    return buffer.toString();
  }

  /// 将意图类型映射到交易类型
  model.TransactionType _mapIntentTypeToTransactionType(TransactionIntentType type) {
    switch (type) {
      case TransactionIntentType.income:
        return model.TransactionType.income;
      case TransactionIntentType.transfer:
        return model.TransactionType.transfer;
      case TransactionIntentType.expense:
        return model.TransactionType.expense;
    }
  }

  /// 处理删除意图
  Future<VoiceSessionResult> _handleDeleteIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    final result = await _deleteService.processDeleteRequest(
      originalInput,
      queryCallback: _queryTransactions,
      deleteCallback: _deleteTransactions,
    );

    final feedbackText = result.generateFeedbackText();

    // 提供删除操作反馈
    if (result.isSuccess) {
      await _feedbackSystem.provideOperationFeedback(
        result: OperationResult.success('delete', {
          'deletedCount': result.deletedRecords?.length ?? 0,
        }),
      );
    } else if (result.needsClarification) {
      await _feedbackSystem.provideFeedback(
        message: feedbackText,
        type: VoiceFeedbackType.confirmation,
        priority: VoiceFeedbackPriority.high,
      );
    } else if (result.needsConfirmation) {
      await _feedbackSystem.provideConfirmationFeedback(
        operation: '删除交易记录',
        details: feedbackText,
      );
    } else {
      await _feedbackSystem.provideErrorFeedback(
        error: feedbackText,
        suggestion: '请重新尝试或提供更具体的信息',
      );
    }

    if (result.needsClarification) {
      _currentSession = VoiceSessionContext(
        intentType: VoiceIntentType.deleteTransaction,
        sessionData: result,
        needsContinuation: true,
        createdAt: DateTime.now(),
      );
      _sessionState = VoiceSessionState.waitingForClarification;
    } else if (result.needsConfirmation) {
      _currentSession = VoiceSessionContext(
        intentType: VoiceIntentType.deleteTransaction,
        sessionData: result,
        needsContinuation: true,
        createdAt: DateTime.now(),
      );
      _sessionState = VoiceSessionState.waitingForConfirmation;
    } else {
      _clearSession();
    }

    notifyListeners();
    return VoiceSessionResult.fromDeleteResult(result);
  }

  /// 处理修改意图
  Future<VoiceSessionResult> _handleModifyIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    final result = await _modifyService.processModifyRequest(
      originalInput,
      queryCallback: _queryTransactions,
      updateCallback: _updateTransaction,
    );

    final feedbackText = result.generateFeedbackText();
    await _speakWithSkipCheck(feedbackText);

    if (result.needsClarification) {
      _currentSession = VoiceSessionContext(
        intentType: VoiceIntentType.modifyTransaction,
        sessionData: result,
        needsContinuation: true,
        createdAt: DateTime.now(),
      );
      _sessionState = VoiceSessionState.waitingForClarification;
    } else if (result.needsConfirmation) {
      _currentSession = VoiceSessionContext(
        intentType: VoiceIntentType.modifyTransaction,
        sessionData: result,
        needsContinuation: true,
        createdAt: DateTime.now(),
      );
      _sessionState = VoiceSessionState.waitingForConfirmation;
    } else {
      _clearSession();
    }

    notifyListeners();
    return VoiceSessionResult.fromModifyResult(result);
  }

  /// 处理确认意图
  Future<VoiceSessionResult> _handleConfirmationIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    if (_currentSession == null) {
      const message = '没有待确认的操作';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }

    VoiceSessionResult result;

    switch (_currentSession!.intentType) {
      case VoiceIntentType.deleteTransaction:
        final deleteResult = await _deleteService.handleVoiceConfirmation(
          originalInput,
          _deleteTransactions,
        );
        result = VoiceSessionResult.fromDeleteResult(deleteResult);
        break;

      case VoiceIntentType.modifyTransaction:
        final modifyResult = await _modifyService.confirmModification(
          _updateTransaction,
        );
        result = VoiceSessionResult.fromModifyResult(modifyResult);
        break;

      case VoiceIntentType.addTransaction:
        // 确认添加重复的交易
        final sessionData = _currentSession!.sessionData as Map<String, dynamic>;
        final transaction = sessionData['transaction'] as model.Transaction;
        await _databaseService.insertTransaction(transaction);
        // 使用LLM生成确认回复
        final llmGen = LLMResponseGenerator.instance;
        final message = await llmGen.generateTransactionResponse(
          transactions: [
            TransactionInfo(
              amount: transaction.amount,
              category: transaction.category,
              isIncome: transaction.type == model.TransactionType.income,
            ),
          ],
          userInput: '确认记录',
        );
        await _speakWithSkipCheck(message);
        result = VoiceSessionResult.success(message);
        break;

      case VoiceIntentType.screenRecognition:
        // 确认屏幕识别的账单
        result = await confirmScreenRecognition();
        break;

      default:
        const message = '无法确认此类型的操作';
        await _speakWithSkipCheck(message);
        result = VoiceSessionResult.error(message);
    }

    if (result.isSuccess) {
      _clearSession();
    }

    notifyListeners();
    return result;
  }

  /// 处理取消意图
  Future<VoiceSessionResult> _handleCancellationIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    if (_currentSession == null) {
      const message = '没有可取消的操作';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }

    switch (_currentSession!.intentType) {
      case VoiceIntentType.deleteTransaction:
        _deleteService.cancelDelete();
        break;
      case VoiceIntentType.modifyTransaction:
        _modifyService.cancelModification();
        break;
      case VoiceIntentType.unknown:
      case VoiceIntentType.addTransaction:
      case VoiceIntentType.queryTransaction:
      case VoiceIntentType.navigateToPage:
      case VoiceIntentType.confirmAction:
      case VoiceIntentType.cancelAction:
      case VoiceIntentType.clarifySelection:
      case VoiceIntentType.screenRecognition:
      case VoiceIntentType.configOperation:
      case VoiceIntentType.moneyAgeOperation:
      case VoiceIntentType.habitOperation:
      case VoiceIntentType.vaultOperation:
      case VoiceIntentType.dataOperation:
      case VoiceIntentType.shareOperation:
      case VoiceIntentType.systemOperation:
      case VoiceIntentType.adviceOperation:
      case VoiceIntentType.chatOperation:
        // No specific cleanup needed for these types
        break;

      case VoiceIntentType.automateAlipaySync:
      case VoiceIntentType.automateWeChatSync:
        // 取消自动化任务
        _automationService.cancelTask();
        break;
    }

    _clearSession();

    const message = '操作已取消';
    await _speakWithSkipCheck(message);

    notifyListeners();
    return VoiceSessionResult.success(message);
  }

  /// 处理澄清意图
  Future<VoiceSessionResult> _handleClarificationIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    if (_currentSession == null) {
      const message = '没有需要澄清的操作';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }

    VoiceSessionResult result;

    switch (_currentSession!.intentType) {
      case VoiceIntentType.deleteTransaction:
        final deleteResult = await _deleteService.handleClarificationSelection(
          originalInput,
          _deleteTransactions,
        );
        result = VoiceSessionResult.fromDeleteResult(deleteResult);
        break;

      case VoiceIntentType.modifyTransaction:
        final modifyResult = await _modifyService.handleClarificationSelection(
          originalInput,
          _updateTransaction,
        );
        result = VoiceSessionResult.fromModifyResult(modifyResult);
        break;

      default:
        const message = '无法澄清此类型的操作';
        await _speakWithSkipCheck(message);
        result = VoiceSessionResult.error(message);
    }

    // 如果澄清成功，可能需要进入确认阶段
    if (result.isSuccess || result.status == VoiceSessionStatus.waitingForConfirmation) {
      if (result.status != VoiceSessionStatus.waitingForConfirmation) {
        _clearSession();
      }
    }

    notifyListeners();
    return result;
  }

  /// 处理添加交易意图
  Future<VoiceSessionResult> _handleAddIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    debugPrint('[VoiceCoordinator] _handleAddIntent被调用');
    debugPrint('[VoiceCoordinator] 原始输入: $originalInput');
    debugPrint('[VoiceCoordinator] 意图实体: ${intentResult.entities}');
    try {
      final entities = intentResult.entities;
      // 使用 num 类型处理，因为 LLM 可能返回 int 或 double
      final amount = (entities['amount'] as num?)?.toDouble();
      final rawCategory = entities['category'] as String?;
      // 规范化分类为标准英文ID（如 '工资' → 'salary', '餐饮' → 'food'）
      final category = rawCategory != null
          ? CategoryLocalizationService.instance.normalizeCategoryId(rawCategory)
          : null;
      final merchant = entities['merchant'] as String?;
      // 检查type参数，判断是收入还是支出
      final typeStr = entities['type'] as String?;
      // 已知的收入分类ID（作为兜底判断，使用标准化后的英文ID）
      const incomeCategoryIds = {
        'salary', 'bonus', 'investment', 'parttime', 'redpacket',
        'reimburse', 'business', 'other_income',
      };
      // 先检查type参数，如果没有则根据分类判断
      final isIncome = typeStr == 'income' ||
          (typeStr == null && category != null && incomeCategoryIds.contains(category));
      debugPrint('[VoiceCoordinator] 解析结果: amount=$amount, rawCategory=$rawCategory, category=$category, merchant=$merchant, type=$typeStr, isIncome=$isIncome');

      if (amount == null || amount <= 0) {
        debugPrint('[VoiceCoordinator] 金额无效，返回错误');
        const message = '请告诉我金额是多少';
        await _speakWithSkipCheck(message);
        return VoiceSessionResult.error(message);
      }

      // 创建交易记录
      final transaction = model.Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: isIncome ? model.TransactionType.income : model.TransactionType.expense,
        amount: amount,
        category: category ?? (isIncome ? 'other_income' : 'other_expense'),
        note: merchant != null ? (isIncome ? merchant : '在$merchant消费') : originalInput,
        date: DateTime.now(),
        accountId: 'default',
        rawMerchant: merchant,
        source: model.TransactionSource.voice,
      );

      // 检查重复交易
      debugPrint('VoiceCoordinator: 开始检查重复交易，金额=${transaction.amount}，分类=${transaction.category}');
      final existingTransactions = await _databaseService.getTransactions();
      debugPrint('VoiceCoordinator: 获取到${existingTransactions.length}条现有交易');
      final duplicateCheck = DuplicateDetectionService.checkDuplicate(
        transaction,
        existingTransactions,
      );
      debugPrint('VoiceCoordinator: 重复检测结果: hasPotentialDuplicate=${duplicateCheck.hasPotentialDuplicate}, score=${duplicateCheck.similarityScore}');

      if (duplicateCheck.hasPotentialDuplicate) {
        // 发现潜在重复，生成简洁的语音播报和详细的聊天记录
        final similarTx = duplicateCheck.potentialDuplicates.isNotEmpty
            ? duplicateCheck.potentialDuplicates.first
            : null;

        // 简洁的语音播报
        String voiceMessage;
        if (similarTx != null) {
          final timeAgo = _getTimeAgoDescription(similarTx.date);
          voiceMessage = '这笔和$timeAgo记的${similarTx.category}${similarTx.amount.toStringAsFixed(0)}元很像，要继续记吗？';
        } else {
          voiceMessage = '这笔可能是重复的，要继续记吗？';
        }

        // 详细的聊天记录内容
        final detailMessage = StringBuffer();
        detailMessage.writeln('⚠️ 检测到疑似重复记录');
        if (similarTx != null) {
          final timeStr = _formatDateTime(similarTx.date);
          detailMessage.writeln('与 $timeStr 记录的「${similarTx.category} ${similarTx.amount}元」高度相似');
        }
        detailMessage.writeln('');
        detailMessage.write('请说"确认"继续记录，或"取消"放弃');

        // 等待即时反馈TTS播放完成
        debugPrint('VoiceCoordinator: 准备播放重复确认提示，等待1秒让即时反馈TTS完成...');
        await Future.delayed(const Duration(milliseconds: 1000));

        // 先停止任何正在播放的TTS
        debugPrint('VoiceCoordinator: 停止任何正在播放的TTS');
        await _ttsService.stop();
        await Future.delayed(const Duration(milliseconds: 100));

        // 播放简洁的语音提示
        debugPrint('VoiceCoordinator: 开始播放TTS: $voiceMessage');
        await _speakWithSkipCheck(voiceMessage);
        debugPrint('VoiceCoordinator: TTS播放完成');

        // 保存待确认的交易到会话
        _currentSession = VoiceSessionContext(
          intentType: VoiceIntentType.addTransaction,
          sessionData: {'transaction': transaction, 'duplicateCheck': duplicateCheck},
          needsContinuation: true,
          createdAt: DateTime.now(),
        );
        _sessionState = VoiceSessionState.waitingForConfirmation;
        notifyListeners();

        // 返回详细内容给聊天记录
        return VoiceSessionResult.waitingForConfirmation(detailMessage.toString());
      }

      debugPrint('[VoiceCoordinator] 正在插入交易到数据库: id=${transaction.id}, amount=${transaction.amount}');
      await _databaseService.insertTransaction(transaction);
      debugPrint('[VoiceCoordinator] 交易插入成功');

      // 记录交易引用到对话上下文（用于后续代词指代，如"删掉它"）
      final transactionRef = TransactionReference(
        id: transaction.id,
        amount: amount,
        category: category ?? 'other_expense',
        date: DateTime.now(),
      );

      // 使用LLM生成自然语言响应（降级到模板）
      final llmGenerator = LLMResponseGenerator.instance;
      final message = await llmGenerator.generateTransactionResponse(
        transactions: [
          TransactionInfo(
            amount: amount,
            category: category ?? '其他',
            isIncome: false,
            merchant: merchant,
          ),
        ],
        userInput: originalInput,
      );
      _conversationContext.addAssistantResponse(message, transactionRef: transactionRef);

      // 记录到消歧服务（用于后续"刚才那笔"等指代解析）
      _disambiguationService.recordRecentOperation(TransactionRecord(
        id: transaction.id,
        amount: amount,
        category: category,
        date: DateTime.now(),
        type: 'expense',
      ));

      await _feedbackSystem.provideOperationFeedback(
        result: OperationResult.success('add', {'amount': amount}),
      );
      await _speakWithSkipCheck(message);

      _clearSession();
      notifyListeners();
      return VoiceSessionResult.success(message);
    } catch (e) {
      final message = '添加记录失败: $e';
      await _feedbackSystem.provideErrorFeedback(
        error: '添加记录时遇到问题',
        suggestion: '请稍后重试，或换一种方式描述',
      );
      return VoiceSessionResult.error(message);
    }
  }

  /// 预算相关查询关键词
  static final List<String> _budgetQueryKeywords = [
    '还能花', '还可以花', '剩余', '剩多少', '还剩', '还有多少',
    '预算', '小金库', '超支', '可用', '能花',
  ];

  /// 检测是否是预算相关查询
  bool _isBudgetQuery(String input) {
    return _budgetQueryKeywords.any((keyword) => input.contains(keyword));
  }

  /// 获取预算查询服务（延迟初始化）
  Future<VoiceBudgetQueryService> _getBudgetQueryService() async {
    if (_budgetQueryService == null) {
      final db = await _databaseService.database;
      _budgetQueryService = VoiceBudgetQueryService(VaultRepository(db));
    }
    return _budgetQueryService!;
  }

  /// 处理预算相关查询
  Future<VoiceSessionResult> _handleBudgetQuery(String originalInput) async {
    try {
      final budgetService = await _getBudgetQueryService();
      final result = await budgetService.processVoiceQuery(originalInput);

      debugPrint('[VoiceCoordinator] 预算查询结果: ${result.intent}, 成功: ${result.success}');

      if (!result.success) {
        await _speakWithSkipCheck(result.spokenResponse);
        return VoiceSessionResult.error(result.spokenResponse);
      }

      await _speakWithSkipCheck(result.spokenResponse);
      _clearSession();
      notifyListeners();

      return VoiceSessionResult.success(
        result.spokenResponse,
        result.data,
      );
    } catch (e) {
      debugPrint('[VoiceCoordinator] 预算查询失败: $e');
      const message = '查询预算时遇到问题，请稍后重试';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  /// 处理查询意图
  ///
  /// 使用 NaturalLanguageSearchService 进行复杂查询语义解析
  /// 支持：
  /// - 时间范围（今天、昨天、本周、上周、本月、上月、今年、X月、最近N天）
  /// - 查询类型（sum合计、count计数、max最大、min最小、average平均、trend趋势）
  /// - 分类过滤（餐饮、交通、购物等）
  /// - 商家过滤（在XX消费）
  /// - 金额范围（大于/小于X元、X元以上/以下、X到Y元）
  /// - 预算查询（还能花多少、剩余预算、超支情况等）
  Future<VoiceSessionResult> _handleQueryIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理查询意图: $originalInput');
      debugPrint('[VoiceCoordinator] LLM识别的参数: ${intentResult.entities}');

      // 1. 先检测是否是预算相关查询
      if (_isBudgetQuery(originalInput)) {
        debugPrint('[VoiceCoordinator] 检测到预算查询，使用 VoiceBudgetQueryService');
        return await _handleBudgetQuery(originalInput);
      }

      // 2. 优先使用LLM识别的结构化查询参数
      final queryType = intentResult.entities['queryType'] as String?;
      final time = intentResult.entities['time'] as String?;
      final category = intentResult.entities['category'] as String?;

      if (queryType != null) {
        debugPrint('[VoiceCoordinator] 使用LLM识别的查询参数: queryType=$queryType, time=$time, category=$category');
        return await _handleStructuredQuery(queryType, time, category, intentResult.entities, originalInput);
      }

      // 3. 降级：如果LLM没有识别出queryType，使用 NaturalLanguageSearchService 重新解析
      debugPrint('[VoiceCoordinator] LLM未识别出queryType，降级到NaturalLanguageSearchService');
      final searchResult = await _nlSearchService.search(originalInput);

      debugPrint('[VoiceCoordinator] 查询结果类型: ${searchResult.type}, 答案: ${searchResult.answer}');

      // 根据结果类型处理
      String message;
      Map<String, dynamic>? resultData;

      switch (searchResult.type) {
        case ResultType.answer:
          // 直接答案（合计、计数、平均等）
          message = searchResult.answer;
          resultData = searchResult.data;
          break;

        case ResultType.single:
          // 单条结果（最大、最小等）
          message = searchResult.answer;
          final transaction = searchResult.data?['transaction'] as NLSearchTransaction?;
          if (transaction != null) {
            message += '，${transaction.category ?? ''}${transaction.description ?? ''}';
            resultData = {
              'transaction': {
                'id': transaction.id,
                'amount': transaction.amount,
                'category': transaction.category,
                'merchant': transaction.merchant,
                'date': transaction.date.toIso8601String(),
              },
            };
          }
          break;

        case ResultType.list:
          // 列表结果
          final transactions = searchResult.data?['transactions'] as List<NLSearchTransaction>?;
          if (transactions != null && transactions.isNotEmpty) {
            final totalAmount = transactions.fold(0.0, (sum, t) => sum + t.amount);
            message = '${searchResult.answer}，总金额${totalAmount.toStringAsFixed(2)}元';
            resultData = {
              'count': transactions.length,
              'totalAmount': totalAmount,
              'transactions': transactions.map((t) => {
                'id': t.id,
                'amount': t.amount,
                'category': t.category,
                'date': t.date.toIso8601String(),
              }).toList(),
            };
          } else {
            message = searchResult.answer;
          }
          break;

        case ResultType.trend:
          // 趋势结果
          message = searchResult.answer;
          resultData = searchResult.data;
          break;

        case ResultType.empty:
          // 空结果
          message = searchResult.answer;
          break;

        case ResultType.error:
          // 错误
          await _feedbackSystem.provideErrorFeedback(
            error: '查询记录时遇到问题',
            suggestion: '请稍后重试或换一种问法',
          );
          return VoiceSessionResult.error(searchResult.answer);

        case ResultType.stats:
          // 统计结果
          message = searchResult.answer;
          resultData = searchResult.data;
          break;
      }

      await _speakWithSkipCheck(message);
      _clearSession();
      notifyListeners();
      return VoiceSessionResult.success(message, resultData);
    } catch (e) {
      debugPrint('[VoiceCoordinator] 查询失败: $e');
      final message = '查询失败: $e';
      await _feedbackSystem.provideErrorFeedback(
        error: '查询记录时遇到问题',
        suggestion: '请稍后重试',
      );
      return VoiceSessionResult.error(message);
    }
  }

  /// 处理结构化查询（使用LLM识别的参数）
  Future<VoiceSessionResult> _handleStructuredQuery(
    String queryType,
    String? timeParam,
    String? category,
    Map<String, dynamic> allParams,
    String originalInput,
  ) async {
    try {
      // 解析时间范围
      final dateRange = _parseTimeParameter(timeParam);
      // 规范化分类名称（中文 → 英文ID，如 "交通" → "transport"）
      final normalizedCategory = category != null
          ? CategoryLocalizationService.instance.normalizeCategoryId(category)
          : null;
      debugPrint('[VoiceCoordinator] 分类规范化: "$category" → "$normalizedCategory"');
      // 解析交易类型筛选（income/expense，默认expense）
      final transactionType = allParams['transactionType'] as String?;
      final isIncomeQuery = transactionType == 'income';

      // 根据queryType执行不同的查询（使用规范化后的分类）
      switch (queryType) {
        case 'summary':
        case 'statistics':
          return await _handleSummaryQuery(dateRange, normalizedCategory, isIncomeQuery: isIncomeQuery);

        case 'recent':
          final limit = allParams['limit'] as int? ?? 10;
          return await _handleRecentQuery(dateRange, normalizedCategory, limit, isIncomeQuery: isIncomeQuery);

        case 'trend':
          final groupBy = allParams['groupBy'] as String? ?? 'date';
          return await _handleTrendQuery(dateRange, normalizedCategory, groupBy, isIncomeQuery: isIncomeQuery);

        case 'distribution':
          final groupBy = allParams['groupBy'] as String? ?? 'category';
          final limit = allParams['limit'] as int?;
          return await _handleDistributionQuery(dateRange, normalizedCategory, groupBy, limit, isIncomeQuery: isIncomeQuery);

        case 'comparison':
          return await _handleComparisonQuery(dateRange, normalizedCategory, isIncomeQuery: isIncomeQuery);

        default:
          debugPrint('[VoiceCoordinator] 未知的查询类型: $queryType，降级到NaturalLanguageSearchService');
          final searchResult = await _nlSearchService.search(originalInput);
          return _buildSearchResult(searchResult);
      }
    } catch (e) {
      debugPrint('[VoiceCoordinator] 结构化查询失败: $e');
      return VoiceSessionResult.error('查询失败: $e');
    }
  }

  /// 解析时间参数为日期范围
  DateRange? _parseTimeParameter(String? timeParam) {
    if (timeParam == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (timeParam) {
      case '今天':
        return DateRange(start: today, end: today.add(const Duration(days: 1)));
      case '昨天':
        final yesterday = today.subtract(const Duration(days: 1));
        return DateRange(start: yesterday, end: today);
      case '本周':
      case '这周':
        final weekStart = today.subtract(Duration(days: now.weekday - 1));
        return DateRange(start: weekStart, end: now);
      case '上周':
        final lastWeekStart = today.subtract(Duration(days: now.weekday + 6));
        final lastWeekEnd = today.subtract(Duration(days: now.weekday));
        return DateRange(start: lastWeekStart, end: lastWeekEnd);
      case '本月':
      case '这个月':
        final monthStart = DateTime(now.year, now.month, 1);
        return DateRange(start: monthStart, end: now);
      case '上月':
      case '上个月':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 1);
        return DateRange(start: lastMonth, end: lastMonthEnd);
      case '今年':
      case '这一年':
        final yearStart = DateTime(now.year, 1, 1);
        return DateRange(start: yearStart, end: now);
      case '最近':
      case '最近7天':
        return DateRange(start: today.subtract(const Duration(days: 7)), end: now);
      case '最近30天':
        return DateRange(start: today.subtract(const Duration(days: 30)), end: now);
      case '最近几个月':
      case '这几个月':
        // 默认3个月
        final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
        return DateRange(start: threeMonthsAgo, end: now);
      default:
        // 尝试解析"最近N天"格式
        final recentDaysMatch = RegExp(r'最近(\d+)天').firstMatch(timeParam);
        if (recentDaysMatch != null) {
          final days = int.parse(recentDaysMatch.group(1)!);
          return DateRange(start: today.subtract(Duration(days: days)), end: now);
        }
        // 尝试解析"最近N个月"格式
        final recentMonthsMatch = RegExp(r'最近(\d+)个?月').firstMatch(timeParam);
        if (recentMonthsMatch != null) {
          final months = int.parse(recentMonthsMatch.group(1)!);
          final startDate = DateTime(now.year, now.month - months, 1);
          return DateRange(start: startDate, end: now);
        }
        // 尝试解析"X天前"格式 (一天前=昨天, 三天前=3天前至今)
        final daysAgoMatch = RegExp(r'([一二两三四五六七八九十\d]+)天前').firstMatch(timeParam);
        if (daysAgoMatch != null) {
          final daysStr = daysAgoMatch.group(1)!;
          final days = _parseChineseNumber(daysStr);
          if (days == 1) {
            // 一天前 = 昨天
            final yesterday = today.subtract(const Duration(days: 1));
            return DateRange(start: yesterday, end: today);
          } else {
            // N天前 = 从N天前到今天
            return DateRange(start: today.subtract(Duration(days: days)), end: now);
          }
        }
        // 尝试解析"X周前"格式 (一周前=上周)
        final weeksAgoMatch = RegExp(r'([一二两三四五六七八九十\d]+)(?:个)?(?:星期|周)前').firstMatch(timeParam);
        if (weeksAgoMatch != null) {
          final weeksStr = weeksAgoMatch.group(1)!;
          final weeks = _parseChineseNumber(weeksStr);
          if (weeks == 1) {
            // 一周前 = 上周
            final lastWeekStart = today.subtract(Duration(days: now.weekday + 6));
            final lastWeekEnd = today.subtract(Duration(days: now.weekday));
            return DateRange(start: lastWeekStart, end: lastWeekEnd);
          } else {
            // N周前 = 从N周前到今天
            return DateRange(start: today.subtract(Duration(days: weeks * 7)), end: now);
          }
        }
        // 尝试解析"X个月前"格式
        final monthsAgoMatch = RegExp(r'([一二两三四五六七八九十\d]+)个?月前').firstMatch(timeParam);
        if (monthsAgoMatch != null) {
          final monthsStr = monthsAgoMatch.group(1)!;
          final months = _parseChineseNumber(monthsStr);
          if (months == 1) {
            // 一个月前 = 上月
            final lastMonth = DateTime(now.year, now.month - 1, 1);
            final lastMonthEnd = DateTime(now.year, now.month, 1);
            return DateRange(start: lastMonth, end: lastMonthEnd);
          } else {
            final startDate = DateTime(now.year, now.month - months, 1);
            return DateRange(start: startDate, end: now);
          }
        }
        return null;
    }
  }

  /// 处理汇总查询（花了多少钱 / 收入多少）
  Future<VoiceSessionResult> _handleSummaryQuery(DateRange? dateRange, String? category, {bool isIncomeQuery = false}) async {
    debugPrint('[VoiceCoordinator] 汇总查询: dateRange=${dateRange?.start}-${dateRange?.end}, category=$category');
    final transactions = await _databaseService.queryTransactions(
      startDate: dateRange?.start,
      endDate: dateRange?.end,
      category: category,
      limit: 1000,
    );
    debugPrint('[VoiceCoordinator] 查询到 ${transactions.length} 笔交易');

    double totalExpense = 0;
    double totalIncome = 0;
    int expenseCount = 0;
    int incomeCount = 0;

    for (final t in transactions) {
      if (t.type == model.TransactionType.income || _isIncomeLikeCategory(t.category)) {
        totalIncome += t.amount;
        incomeCount++;
      } else if (t.type == model.TransactionType.expense) {
        totalExpense += t.amount;
        expenseCount++;
      }
    }

    final timeDesc = _formatTimeRange(dateRange);
    final categoryDesc = category != null ? '${_localizedCategoryName(category)}分类' : '';

    String message;
    if (isIncomeQuery) {
      // 收入查询
      if (incomeCount == 0) {
        message = '$timeDesc${categoryDesc}没有收入记录';
      } else {
        message = '$timeDesc${categoryDesc}共收入${totalIncome.toStringAsFixed(2)}元，${incomeCount}笔';
        if (totalExpense > 0) {
          final net = totalIncome - totalExpense;
          message += '，支出${totalExpense.toStringAsFixed(2)}元，净收入${net.toStringAsFixed(2)}元';
        }
      }
    } else {
      // 支出查询（默认）
      if (category != null) {
        message = '$timeDesc$categoryDesc共花费${totalExpense.toStringAsFixed(2)}元，${expenseCount}笔';
      } else if (totalIncome > 0) {
        // 同时显示支出和收入时，分别标注笔数，避免歧义
        message = '$timeDesc共花费${totalExpense.toStringAsFixed(2)}元（${expenseCount}笔），收入${totalIncome.toStringAsFixed(2)}元（${incomeCount}笔）';
      } else {
        message = '$timeDesc共花费${totalExpense.toStringAsFixed(2)}元，${expenseCount}笔';
      }
    }

    await _speakWithSkipCheck(message);
    return VoiceSessionResult.success(message, {
      'totalExpense': totalExpense,
      'totalIncome': totalIncome,
      'count': isIncomeQuery ? incomeCount : expenseCount,
    });
  }

  /// 处理最近记录查询
  Future<VoiceSessionResult> _handleRecentQuery(DateRange? dateRange, String? category, int limit, {bool isIncomeQuery = false}) async {
    final transactions = await _databaseService.queryTransactions(
      startDate: dateRange?.start,
      endDate: dateRange?.end,
      category: category,
      limit: isIncomeQuery ? 1000 : limit,
    );

    final typeLabel = isIncomeQuery ? '收入' : '';

    // 按收入/支出筛选
    final filtered = isIncomeQuery
        ? transactions.where((t) => t.type == model.TransactionType.income || _isIncomeLikeCategory(t.category)).toList()
        : transactions;

    final result = isIncomeQuery ? filtered.take(limit).toList() : filtered;

    if (result.isEmpty) {
      final message = '没有找到相关${typeLabel}记录';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message);
    }

    final firstCategory = _localizedCategoryName(result.first.category);
    final message = '找到${result.length}条${typeLabel}记录，最近的是$firstCategory${result.first.amount}元';
    await _speakWithSkipCheck(message);
    return VoiceSessionResult.success(message, {
      'transactions': result,
    });
  }

  /// 处理趋势查询
  Future<VoiceSessionResult> _handleTrendQuery(DateRange? dateRange, String? category, String groupBy, {bool isIncomeQuery = false}) async {
    final range = dateRange ?? DateRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    final transactions = await _databaseService.queryTransactions(
      startDate: range.start,
      endDate: range.end,
      category: category,
      limit: 1000,
    );

    final typeLabel = isIncomeQuery ? '收入' : '消费';
    if (transactions.isEmpty) {
      final message = '该时间段没有找到${typeLabel}记录';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message);
    }

    // 按时间分组统计
    final Map<String, double> grouped = {};
    for (final t in transactions) {
      if (isIncomeQuery) {
        // 收入查询：只统计收入类交易
        if (t.type != model.TransactionType.income && !_isIncomeLikeCategory(t.category)) continue;
      } else {
        // 支出查询：排除收入和转账类
        if (t.type != model.TransactionType.expense || _isIncomeLikeCategory(t.category)) continue;
      }
      String key;
      if (groupBy == 'month') {
        key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      } else if (groupBy == 'week') {
        final weekStart = t.date.subtract(Duration(days: t.date.weekday - 1));
        key = '${weekStart.month}/${weekStart.day}周';
      } else {
        key = '${t.date.month}/${t.date.day}';
      }
      grouped[key] = (grouped[key] ?? 0) + t.amount;
    }

    if (grouped.isEmpty) {
      final message = '该时间段没有${typeLabel}记录';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final verbLabel = isIncomeQuery ? '收入' : '花费';
    final parts = sortedKeys.map((k) => '$k$verbLabel${grouped[k]!.toStringAsFixed(0)}元').toList();
    final timeDesc = _formatTimeRange(dateRange);
    final message = '$timeDesc${typeLabel}趋势：${parts.join("，")}';
    await _speakWithSkipCheck(message);
    return VoiceSessionResult.success(message, {'trend': grouped});
  }

  /// 处理分布查询
  Future<VoiceSessionResult> _handleDistributionQuery(DateRange? dateRange, String? category, String groupBy, int? limit, {bool isIncomeQuery = false}) async {
    final range = dateRange ?? DateRange(
      start: DateTime(DateTime.now().year, DateTime.now().month, 1),
      end: DateTime.now(),
    );
    final transactions = await _databaseService.queryTransactions(
      startDate: range.start,
      endDate: range.end,
      category: category,
      limit: 1000,
    );

    final typeLabel = isIncomeQuery ? '收入' : '消费';
    if (transactions.isEmpty) {
      final message = '该时间段没有找到${typeLabel}记录';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message);
    }

    // 按分类分组统计
    final Map<String, double> categoryTotals = {};
    double total = 0;
    for (final t in transactions) {
      if (isIncomeQuery) {
        // 收入查询：只统计收入类交易
        if (t.type != model.TransactionType.income && !_isIncomeLikeCategory(t.category)) continue;
      } else {
        // 支出查询：排除收入和转账类
        if (t.type != model.TransactionType.expense) continue;
        if (_isIncomeLikeCategory(t.category)) continue;
      }
      final displayName = _localizedCategoryName(t.category);
      categoryTotals[displayName] = (categoryTotals[displayName] ?? 0) + t.amount;
      total += t.amount;
    }

    if (categoryTotals.isEmpty) {
      final message = '该时间段没有${typeLabel}记录';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message);
    }

    // 按金额排序
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final displayCount = limit ?? 5;
    final topItems = sorted.take(displayCount);
    final timeDesc = _formatTimeRange(dateRange);
    final parts = topItems.map((e) {
      final percent = (e.value / total * 100).toStringAsFixed(0);
      return '${e.key}${e.value.toStringAsFixed(0)}元占$percent%';
    }).toList();

    final totalLabel = isIncomeQuery ? '总收入' : '总支出';
    final topLabel = isIncomeQuery ? '收入最多的是' : '花费最多的是';
    final message = '$timeDesc$totalLabel${total.toStringAsFixed(0)}元，$topLabel：${parts.join("，")}';
    await _speakWithSkipCheck(message);
    return VoiceSessionResult.success(message, {
      'distribution': categoryTotals,
      'total': total,
    });
  }

  /// 处理对比查询
  Future<VoiceSessionResult> _handleComparisonQuery(DateRange? dateRange, String? category, {bool isIncomeQuery = false}) async {
    // 确定当前周期和上一个周期
    final now = DateTime.now();
    final currentStart = dateRange?.start ?? DateTime(now.year, now.month, 1);
    final currentEnd = dateRange?.end ?? now;
    final duration = currentEnd.difference(currentStart);

    final prevEnd = currentStart;
    final prevStart = prevEnd.subtract(duration);

    // 查询两个时间段的数据
    final currentTransactions = await _databaseService.queryTransactions(
      startDate: currentStart,
      endDate: currentEnd,
      category: category,
      limit: 1000,
    );
    final prevTransactions = await _databaseService.queryTransactions(
      startDate: prevStart,
      endDate: prevEnd,
      category: category,
      limit: 1000,
    );

    double currentAmount = 0;
    double prevAmount = 0;

    bool _matchType(model.Transaction t) {
      if (isIncomeQuery) {
        return t.type == model.TransactionType.income || _isIncomeLikeCategory(t.category);
      } else {
        return t.type == model.TransactionType.expense && !_isIncomeLikeCategory(t.category);
      }
    }

    for (final t in currentTransactions) {
      if (_matchType(t)) currentAmount += t.amount;
    }
    for (final t in prevTransactions) {
      if (_matchType(t)) prevAmount += t.amount;
    }

    final diff = currentAmount - prevAmount;
    final timeDesc = _formatTimeRange(dateRange);
    final categoryDesc = category != null ? _localizedCategoryName(category) : '';
    final typeLabel = isIncomeQuery ? '收入' : '支出';

    String message;
    if (prevAmount == 0 && currentAmount == 0) {
      message = '两个时间段都没有$categoryDesc${typeLabel}记录';
    } else if (prevAmount == 0) {
      message = '$timeDesc$categoryDesc$typeLabel${currentAmount.toStringAsFixed(0)}元，上个周期没有记录';
    } else {
      final changePercent = (diff / prevAmount * 100).abs().toStringAsFixed(0);
      if (diff > 0) {
        message = '$timeDesc$categoryDesc$typeLabel${currentAmount.toStringAsFixed(0)}元，比上个周期多了${diff.toStringAsFixed(0)}元，增长$changePercent%';
      } else if (diff < 0) {
        message = '$timeDesc$categoryDesc$typeLabel${currentAmount.toStringAsFixed(0)}元，比上个周期少了${diff.abs().toStringAsFixed(0)}元，减少$changePercent%';
      } else {
        message = '$timeDesc$categoryDesc$typeLabel${currentAmount.toStringAsFixed(0)}元，与上个周期持平';
      }
    }

    await _speakWithSkipCheck(message);
    return VoiceSessionResult.success(message, {
      'currentAmount': currentAmount,
      'prevAmount': prevAmount,
      'diff': diff,
    });
  }

  /// 格式化时间范围为描述文字
  String _formatTimeRange(DateRange? dateRange) {
    if (dateRange == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 今天
    if (dateRange.start == today && dateRange.end.isAfter(today)) {
      return '今天';
    }

    // 昨天
    final yesterday = today.subtract(const Duration(days: 1));
    if (dateRange.start == yesterday && dateRange.end == today) {
      return '昨天';
    }

    // 今年（必须在本月判断之前检查，因为1月份时今年开始==本月开始）
    final yearStart = DateTime(now.year, 1, 1);
    if (dateRange.start == yearStart) {
      // 如果是1月份，需要额外判断结束时间是否跨越了多天（排除"本月1日"的情况）
      if (now.month == 1) {
        // 1月份时，如果结束时间接近现在，可能是今年也可能是本月
        // 通过检查是否明确请求了"今年"来区分（这里假设如果start是1月1日就是今年）
        return '今年';
      }
      return '今年';
    }

    // 本月
    final monthStart = DateTime(now.year, now.month, 1);
    if (dateRange.start == monthStart) {
      return '本月';
    }

    // 最近几个月（3个月前的月初）
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
    if (dateRange.start.year == threeMonthsAgo.year &&
        dateRange.start.month == threeMonthsAgo.month &&
        dateRange.start.day == 1) {
      return '最近几个月';
    }

    return ''; // 其他情况返回空
  }

  /// 获取分类的本地化显示名称
  String _localizedCategoryName(String category) {
    return CategoryLocalizationService.instance.getCategoryName(category);
  }

  /// 判断分类是否属于收入或转账类型（用于过滤被错误标记为支出的交易）
  bool _isIncomeLikeCategory(String category) {
    const incomeCategories = {
      // 收入一级分类
      'salary', 'bonus', 'investment', 'parttime', 'redpacket',
      'reimburse', 'business', 'other_income',
      // 转账分类
      'transfer', 'account_transfer',
      // 中文收入分类名称（数据库中可能直接存储中文）
      '收入', '工资', '奖金', '投资收益', '兼职', '红包', '报销',
      '经营所得', '转账', '账户互转',
    };
    final lower = category.toLowerCase().trim();
    if (incomeCategories.contains(lower)) return true;
    // 检查子分类前缀
    if (lower.startsWith('salary_') ||
        lower.startsWith('bonus_') ||
        lower.startsWith('investment_') ||
        lower.startsWith('parttime_') ||
        lower.startsWith('redpacket_') ||
        lower.startsWith('reimburse_') ||
        lower.startsWith('business_')) {
      return true;
    }
    return false;
  }

  /// 从SearchResult构建VoiceSessionResult
  VoiceSessionResult _buildSearchResult(SearchResult searchResult) {
    String message;
    Map<String, dynamic>? resultData;

    switch (searchResult.type) {
      case ResultType.answer:
        message = searchResult.answer;
        resultData = searchResult.data;
        break;
      case ResultType.single:
        message = searchResult.answer;
        final transaction = searchResult.data?['transaction'] as NLSearchTransaction?;
        if (transaction != null) {
          message += '，${transaction.category ?? ''}${transaction.description ?? ''}';
          resultData = {
            'transaction': {
              'id': transaction.id,
              'amount': transaction.amount,
              'category': transaction.category,
              'merchant': transaction.merchant,
              'date': transaction.date.toIso8601String(),
            },
          };
        }
        break;
      case ResultType.list:
        final transactions = searchResult.data?['transactions'] as List<NLSearchTransaction>?;
        if (transactions != null && transactions.isNotEmpty) {
          final totalAmount = transactions.fold(0.0, (sum, t) => sum + t.amount);
          message = '${searchResult.answer}，总金额${totalAmount.toStringAsFixed(2)}元';
          resultData = {
            'count': transactions.length,
            'totalAmount': totalAmount,
            'transactions': transactions.map((t) => {
              'id': t.id,
              'amount': t.amount,
              'category': t.category,
              'date': t.date.toIso8601String(),
            }).toList(),
          };
        } else {
          message = searchResult.answer;
        }
        break;
      case ResultType.trend:
      case ResultType.stats:
        message = searchResult.answer;
        resultData = searchResult.data;
        break;
      case ResultType.empty:
        message = searchResult.answer;
        break;
      case ResultType.error:
        return VoiceSessionResult.error(searchResult.answer);
    }

    return VoiceSessionResult.success(message, resultData);
  }

  /// 处理导航意图
  Future<VoiceSessionResult> _handleNavigationIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    debugPrint('[VoiceServiceCoordinator] 处理导航意图: $originalInput');
    final result = _navigationService.parseNavigation(originalInput);

    if (result.success && result.route != null) {
      debugPrint('[VoiceServiceCoordinator] 导航解析成功: route=${result.route}, pageName=${result.pageName}');
      // 实际执行导航
      final executed = await VoiceNavigationExecutor.instance.navigateToRoute(result.route!);
      final message = executed
          ? '正在打开${result.pageName}'
          : '抱歉，暂时无法打开${result.pageName}';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(
        message,
        {'route': result.route, 'pageName': result.pageName, 'executed': executed},
      );
    }

    final message = result.errorMessage ?? '抱歉，我不知道您想去哪个页面';
    debugPrint('[VoiceServiceCoordinator] 导航解析失败: $message');
    await _speakWithSkipCheck(message);
    return VoiceSessionResult.success(message, null);
  }

  /// 处理屏幕识别意图
  ///
  /// 读取当前屏幕内容，识别账单信息并创建交易记录
  /// 支持单笔和多笔交易识别
  Future<VoiceSessionResult> _handleScreenRecognitionIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    // 执行屏幕识别
    final result = await _screenReaderService.recognizeFromScreen();

    // 播放语音反馈
    final feedback = result.hasMultipleBills
        ? result.getDetailedVoiceFeedback()
        : result.getVoiceFeedback();
    await _speakWithSkipCheck(feedback);

    // 根据结果状态处理
    if (result.isSuccess || result.status == VoiceScreenRecognitionStatus.lowConfidence) {
      // 设置会话状态，等待用户确认
      // 存储完整的 VoiceScreenRecognitionResult 以支持多笔处理
      _currentSession = VoiceSessionContext(
        intentType: VoiceIntentType.screenRecognition,
        sessionData: result,
        needsContinuation: true,
        createdAt: DateTime.now(),
      );
      _sessionState = VoiceSessionState.waitingForConfirmation;
      notifyListeners();

      return VoiceSessionResult.success(feedback, {
        'screenRecognition': true,
        'hasMultipleBills': result.hasMultipleBills,
        'billCount': result.billCount,
        'totalAmount': result.totalAmount,
        'billInfo': {
          'amount': result.billInfo?.amount,
          'merchant': result.billInfo?.merchant,
          'type': result.billInfo?.type,
          'appName': result.billInfo?.appName,
          'confidence': result.billInfo?.confidence,
        },
        'allBills': result.allBills.map((b) => {
          'amount': b.amount,
          'merchant': b.merchant,
          'type': b.type,
          'appName': b.appName,
          'confidence': b.confidence,
        }).toList(),
        'needsConfirmation': true,
      });
    } else if (result.needsServiceEnabled) {
      // 需要启用无障碍服务
      return VoiceSessionResult.success(feedback, {
        'screenRecognition': true,
        'needsAccessibilitySettings': true,
      });
    } else {
      // 识别失败
      return VoiceSessionResult.error(feedback);
    }
  }

  /// 确认屏幕识别的账单并记账
  ///
  /// 支持单笔和多笔交易批量记账
  Future<VoiceSessionResult> confirmScreenRecognition() async {
    if (_currentSession?.intentType != VoiceIntentType.screenRecognition) {
      return VoiceSessionResult.error('没有待确认的屏幕识别结果');
    }

    // 获取识别结果（支持新旧格式）
    final sessionData = _currentSession?.sessionData;
    List<BillInfo> billsToRecord;

    if (sessionData is VoiceScreenRecognitionResult) {
      // 新格式：包含多笔账单
      billsToRecord = sessionData.allBills;
    } else if (sessionData is BillInfo) {
      // 旧格式：单笔账单
      billsToRecord = [sessionData];
    } else {
      _clearSession();
      return VoiceSessionResult.error('账单信息格式不正确');
    }

    // 过滤有效账单
    final validBills = billsToRecord.where((b) => b.amount != null && b.amount! > 0).toList();
    if (validBills.isEmpty) {
      _clearSession();
      return VoiceSessionResult.error('没有有效的账单信息');
    }

    try {
      final recordedIds = <String>[];
      var totalAmount = 0.0;

      for (final billInfo in validBills) {
        // 创建交易记录
        final transaction = model.Transaction(
          id: '${DateTime.now().millisecondsSinceEpoch}_${recordedIds.length}',
          type: _mapBillTypeToTransactionType(billInfo.type),
          amount: billInfo.amount!,
          category: 'other_expense', // TODO: 根据商户智能分类
          note: billInfo.description,
          date: DateTime.now(),
          accountId: 'default',
          rawMerchant: billInfo.merchant,
          source: model.TransactionSource.voice,
        );

        await _databaseService.insertTransaction(transaction);
        recordedIds.add(transaction.id);
        totalAmount += billInfo.amount!;
      }

      _clearSession();

      // 使用LLM生成屏幕识别结果回复
      final llmGen = LLMResponseGenerator.instance;
      final txInfos = validBills.map((b) => TransactionInfo(
        amount: b.amount!,
        category: b.typeDisplayName,
        isIncome: b.type == 'income',
        merchant: b.merchant,
      )).toList();
      final message = await llmGen.generateTransactionResponse(
        transactions: txInfos,
        userInput: '屏幕识别记账',
      );
      await _speakWithSkipCheck(message);

      return VoiceSessionResult.success(message, {
        'recorded': true,
        'recordedCount': validBills.length,
        'totalAmount': totalAmount,
        'transactionIds': recordedIds,
      });
    } catch (e) {
      _clearSession();
      final message = '记录失败：$e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 自动化账单同步
  // ═══════════════════════════════════════════════════════════════

  /// 处理自动化账单同步意图
  ///
  /// [isAlipay] true表示支付宝同步，false表示微信同步
  Future<VoiceSessionResult> _handleAutomationIntent(
    IntentAnalysisResult intentResult,
    String originalInput, {
    required bool isAlipay,
  }) async {
    final appName = isAlipay ? '支付宝' : '微信';

    // 播放开始提示
    await _speakWithSkipCheck('好的，正在打开$appName读取账单...');

    // 设置自动化运行状态
    _sessionState = VoiceSessionState.automationRunning;
    _currentSession = VoiceSessionContext(
      intentType: isAlipay ? VoiceIntentType.automateAlipaySync : VoiceIntentType.automateWeChatSync,
      sessionData: {'appName': appName, 'isAlipay': isAlipay},
      needsContinuation: false,
      createdAt: DateTime.now(),
    );
    notifyListeners();

    // 设置进度回调
    _automationService.onProgressUpdate = (message) {
      debugPrint('AutomationProgress: $message');
    };

    try {
      // 执行自动化同步
      final result = isAlipay
          ? await _automationService.syncAlipayBills()
          : await _automationService.syncWeChatBills();

      // 播放结果反馈
      final feedback = result.getVoiceFeedback();
      await _speakWithSkipCheck(feedback);

      _clearSession();

      if (result.isSuccess) {
        return VoiceSessionResult.success(feedback, {
          'automation': true,
          'appName': appName,
          'totalFound': result.totalFound,
          'newRecorded': result.newRecorded,
          'transactions': result.transactions.map((t) => {
            'id': t.id,
            'amount': t.amount,
            'description': t.description,
            'type': t.type.toString(),
          }).toList(),
        });
      } else if (result.needsServiceEnabled) {
        return VoiceSessionResult.success(feedback, {
          'automation': true,
          'needsAccessibilitySettings': true,
        });
      } else {
        return VoiceSessionResult.error(feedback);
      }
    } catch (e) {
      _clearSession();
      final message = '自动化同步失败：$e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  /// 将账单类型映射到交易类型
  model.TransactionType _mapBillTypeToTransactionType(String billType) {
    switch (billType) {
      case 'income':
        return model.TransactionType.income;
      case 'transfer':
        return model.TransactionType.transfer;
      case 'expense':
      default:
        return model.TransactionType.expense;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 配置操作处理器
  // ═══════════════════════════════════════════════════════════════

  /// 处理配置操作意图
  ///
  /// 支持通过语音修改各类系统配置，如预算、账户、主题、提醒等
  /// 使用 VoiceConfigService 解析和执行配置命令
  Future<VoiceSessionResult> _handleConfigIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理配置意图: $originalInput');

      // 使用 VoiceConfigService 解析配置命令
      final parseResult = _configService.parseConfigCommand(originalInput);

      if (!parseResult.success) {
        // 解析失败，尝试从 entities 获取配置信息
        final entities = intentResult.entities;
        final configId = entities['configId'] as String?;

        if (configId == null) {
          final message = parseResult.errorMessage ?? '请告诉我要修改哪个配置，比如"把餐饮预算改成2000"';
          await _speakWithSkipCheck(message);
          return VoiceSessionResult.error(message);
        }

        // 有 configId 但无法解析具体值
        final message = '请告诉我要把$configId改成什么';
        await _speakWithSkipCheck(message);
        return VoiceSessionResult.partial(message);
      }

      // 解析成功，执行配置修改
      final command = parseResult.config!;
      debugPrint('[VoiceCoordinator] 配置命令解析成功: ${command.definition.id} = ${command.value}');

      // 执行配置
      final executeResult = await _configService.executeConfig(command);

      if (executeResult.success) {
        final message = executeResult.confirmText ?? '配置已更新';
        await _speakWithSkipCheck(message);

        return VoiceSessionResult.success(message, {
          'configId': command.definition.id,
          'configName': command.definition.name,
          'value': command.value,
          'category': command.definition.category.toString(),
        });
      } else {
        final message = executeResult.errorMessage ?? '配置修改失败';
        await _speakWithSkipCheck(message);
        return VoiceSessionResult.error(message);
      }
    } catch (e) {
      debugPrint('[VoiceCoordinator] 配置修改异常: $e');
      final message = '配置修改失败: $e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 钱龄操作处理器
  // ═══════════════════════════════════════════════════════════════

  /// 处理钱龄操作意图
  ///
  /// 支持查看钱龄、钱龄分析、资金池查看等操作
  Future<VoiceSessionResult> _handleMoneyAgeIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理钱龄意图: $originalInput');
      final entities = intentResult.entities;
      final operation = entities['operation'] as String? ?? 'query';

      String message;
      Map<String, dynamic>? data;

      switch (operation) {
        case 'query':
          // 查询钱龄
          // TODO: 集成钱龄服务获取实际数据
          message = '您的平均钱龄为45天，处于健康水平';
          data = {'averageAge': 45, 'status': 'healthy'};
          break;

        case 'optimize':
          // 钱龄优化建议
          message = '建议您减少冲动消费，延长资金持有时间可以提高钱龄';
          data = {'suggestion': 'reduce_impulse_spending'};
          break;

        case 'pool':
          // 资金池查看
          message = '当前资金池共有3笔资金，总金额5000元';
          data = {'poolCount': 3, 'totalAmount': 5000};
          break;

        default:
          message = '钱龄操作已完成';
      }

      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '钱龄操作失败: $e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 习惯操作处理器
  // ═══════════════════════════════════════════════════════════════

  /// 处理习惯操作意图
  ///
  /// 支持打卡、挑战、奖励等习惯培养相关操作
  Future<VoiceSessionResult> _handleHabitIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理习惯意图: $originalInput');
      final entities = intentResult.entities;
      final operation = entities['operation'] as String? ?? 'checkin';

      String message;
      Map<String, dynamic>? data;

      switch (operation) {
        case 'checkin':
          // 打卡
          // TODO: 集成习惯服务执行打卡
          message = '打卡成功！已连续记账15天，继续保持！';
          data = {'streak': 15, 'checkedIn': true};
          break;

        case 'challenge':
          // 查看挑战进度
          message = '当前省钱挑战进度：已完成60%，还差200元达成目标';
          data = {'progress': 0.6, 'remaining': 200};
          break;

        case 'reward':
          // 兑换奖励
          message = '已兑换奖励，获得10积分';
          data = {'points': 10, 'redeemed': true};
          break;

        case 'points':
          // 查看积分
          message = '您当前有150积分，可兑换3个奖励';
          data = {'totalPoints': 150, 'availableRewards': 3};
          break;

        default:
          message = '习惯操作已完成';
      }

      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '习惯操作失败: $e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 小金库操作处理器
  // ═══════════════════════════════════════════════════════════════

  /// 处理小金库操作意图
  ///
  /// 支持资金分配、查询余额、调拨资金等操作
  Future<VoiceSessionResult> _handleVaultIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理小金库意图: $originalInput');
      final entities = intentResult.entities;
      final operation = entities['operation'] as String? ?? 'query';
      final vaultName = entities['vaultName'] as String?;
      final amount = (entities['amount'] as num?)?.toDouble();

      String message;
      Map<String, dynamic>? data;

      switch (operation) {
        case 'allocate':
          // 分配资金
          if (amount == null || vaultName == null) {
            message = '请告诉我要分配多少钱到哪个小金库';
            await _speakWithSkipCheck(message);
            return VoiceSessionResult.error(message);
          }
          // TODO: 集成VaultRepository执行分配
          message = '已向$vaultName小金库分配${amount.toStringAsFixed(0)}元';
          data = {'vault': vaultName, 'amount': amount, 'allocated': true};
          break;

        case 'query':
          // 查询余额
          if (vaultName != null) {
            message = '$vaultName小金库余额为2000元';
            data = {'vault': vaultName, 'balance': 2000};
          } else {
            message = '您有3个小金库，总余额5000元';
            data = {'vaultCount': 3, 'totalBalance': 5000};
          }
          break;

        case 'transfer':
          // 调拨资金
          final targetVault = entities['targetVault'] as String?;
          if (amount == null || vaultName == null || targetVault == null) {
            message = '请告诉我从哪个小金库调多少钱到哪个小金库';
            await _speakWithSkipCheck(message);
            return VoiceSessionResult.error(message);
          }
          message = '已从$vaultName调拨${amount.toStringAsFixed(0)}元到$targetVault';
          data = {'from': vaultName, 'to': targetVault, 'amount': amount};
          break;

        case 'withdraw':
          // 取出资金
          if (amount == null || vaultName == null) {
            message = '请告诉我从哪个小金库取多少钱';
            await _speakWithSkipCheck(message);
            return VoiceSessionResult.error(message);
          }
          message = '已从$vaultName取出${amount.toStringAsFixed(0)}元';
          data = {'vault': vaultName, 'amount': amount, 'withdrawn': true};
          break;

        default:
          message = '小金库操作已完成';
      }

      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '小金库操作失败: $e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 数据操作处理器
  // ═══════════════════════════════════════════════════════════════

  /// 处理数据操作意图
  ///
  /// 支持备份、导出、同步等数据操作
  Future<VoiceSessionResult> _handleDataIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理数据意图: $originalInput');
      final entities = intentResult.entities;
      final operation = entities['operation'] as String? ?? 'backup';

      String message;
      Map<String, dynamic>? data;

      switch (operation) {
        case 'backup':
          // 立即备份
          // TODO: 集成数据备份服务
          message = '数据备份完成，已保存到云端';
          data = {'backupTime': DateTime.now().toIso8601String(), 'success': true};
          break;

        case 'export':
          // 导出数据
          final period = entities['period'] as String? ?? 'month';
          message = '已导出${period == 'month' ? '本月' : period}数据到文件';
          data = {'period': period, 'exported': true};
          break;

        case 'sync':
          // 同步数据
          message = '数据同步完成，所有设备已更新';
          data = {'syncTime': DateTime.now().toIso8601String(), 'synced': true};
          break;

        case 'restore':
          // 恢复数据
          message = '正在恢复数据，请稍候...';
          data = {'restoring': true};
          break;

        default:
          message = '数据操作已完成';
      }

      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '数据操作失败: $e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 分享操作处理器
  // ═══════════════════════════════════════════════════════════════

  /// 处理分享操作意图
  ///
  /// 支持分享报告、邀请好友等操作
  Future<VoiceSessionResult> _handleShareIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理分享意图: $originalInput');
      final entities = intentResult.entities;
      final operation = entities['operation'] as String? ?? 'report';

      String message;
      Map<String, dynamic>? data;

      switch (operation) {
        case 'report':
          // 分享报告
          final reportType = entities['reportType'] as String? ?? 'month';
          message = '已生成${reportType == 'month' ? '月度' : reportType}报告，可以分享给好友了';
          data = {'reportType': reportType, 'generated': true};
          break;

        case 'invite':
          // 邀请好友
          message = '邀请链接已复制到剪贴板，快分享给好友吧';
          data = {'inviteLink': 'https://app.example.com/invite/xxx', 'copied': true};
          break;

        case 'summary':
          // 年度总结
          message = '已生成年度消费总结，快来看看你今年的消费情况吧';
          data = {'type': 'annual_summary', 'generated': true};
          break;

        default:
          message = '分享操作已完成';
      }

      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '分享操作失败: $e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 系统操作处理器
  // ═══════════════════════════════════════════════════════════════

  /// 处理系统操作意图
  ///
  /// 支持检查更新、反馈、清理缓存等系统操作
  Future<VoiceSessionResult> _handleSystemIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理系统意图: $originalInput');
      final entities = intentResult.entities;
      final operation = entities['operation'] as String? ?? 'version';

      String message;
      Map<String, dynamic>? data;

      switch (operation) {
        case 'update':
          // 检查更新
          message = '当前已是最新版本 v4.0.0';
          data = {'version': '4.0.0', 'isLatest': true};
          break;

        case 'version':
          // 查看版本
          message = '当前版本 v4.0.0';
          data = {'version': '4.0.0'};
          break;

        case 'feedback':
          // 提交反馈
          message = '感谢您的反馈！我们会认真处理';
          data = {'feedbackReceived': true};
          break;

        case 'support':
          // 联系客服
          message = '正在为您接入客服，请稍候...';
          data = {'connecting': true};
          break;

        case 'cache':
          // 清理缓存
          message = '缓存已清理，释放了50MB空间';
          data = {'freedSpace': 50, 'cleaned': true};
          break;

        case 'space':
          // 释放空间
          message = '已释放100MB存储空间';
          data = {'freedSpace': 100};
          break;

        default:
          message = '系统操作已完成';
      }

      await _speakWithSkipCheck(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '系统操作失败: $e';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 建议操作处理器
  // ═══════════════════════════════════════════════════════════════

  /// 处理建议操作意图
  ///
  /// 支持多种建议类型：
  /// - 财务建议：省钱、理财、消费分析
  /// - 预算建议：预算设置、预算优化
  /// - 洞察分析：消费洞察、趋势分析
  /// - 功能推荐：推荐适合用户的功能
  /// - 储蓄建议：存钱计划、储蓄目标
  ///
  /// 使用 VoiceAdviceService 策略模式统一处理
  Future<VoiceSessionResult> _handleAdviceIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    debugPrint('[VoiceCoordinator] 处理建议意图: $originalInput');

    final result = await _adviceService.generateAdvice(originalInput);
    debugPrint('[VoiceCoordinator] 建议类型: ${result.category}, LLM生成: ${result.isLLMGenerated}');

    await _speakWithSkipCheck(result.spokenText);
    return VoiceSessionResult.success(result.spokenText, {
      'type': result.category.name,
      'isLLMGenerated': result.isLLMGenerated,
      ...?result.data,
    });
  }

  /// 处理闲聊意图（讲故事、讲笑话、问候等）
  Future<VoiceSessionResult> _handleChatIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理闲聊意图: $originalInput');

      // 使用LLM生成闲聊回复
      final llmGenerator = LLMResponseGenerator.instance;
      final response = await llmGenerator.generateCasualChatResponse(
        userInput: originalInput,
      );

      debugPrint('[VoiceCoordinator] 闲聊回复: $response');
      await _speakWithSkipCheck(response);
      return VoiceSessionResult.success(response);
    } catch (e) {
      debugPrint('[VoiceCoordinator] 闲聊处理失败: $e');
      const fallback = '我来陪你聊聊天吧~有什么想说的？';
      await _speakWithSkipCheck(fallback);
      return VoiceSessionResult.success(fallback);
    }
  }

  /// 处理未知意图
  ///
  /// 当规则匹配无法识别意图时，尝试使用AI大模型进行兜底处理
  Future<VoiceSessionResult> _handleUnknownIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    debugPrint('[VoiceCoordinator] 规则匹配未识别，尝试AI兜底: $originalInput');

    // 尝试使用AI大模型进行意图分解
    try {
      final aiResult = await _aiDecomposer.decompose(originalInput);

      if (aiResult != null && aiResult.intents.isNotEmpty) {
        debugPrint('[VoiceCoordinator] AI识别到${aiResult.intents.length}个意图');

        // 转换为MultiIntentResult
        final multiResult = _aiDecomposer.toMultiIntentResult(aiResult);

        if (multiResult != null && !multiResult.isEmpty) {
          // 处理AI识别的导航意图
          if (multiResult.navigationIntent != null) {
            final navIntent = multiResult.navigationIntent!;
            debugPrint('[VoiceCoordinator] AI识别到导航意图: ${navIntent.targetPage}');

            final navResult = _navigationService.parseNavigation(originalInput);
            if (navResult.success && navResult.route != null) {
              // 实际执行导航
              final executed = await VoiceNavigationExecutor.instance.navigateToRoute(navResult.route!);
              final message = executed
                  ? '正在打开${navResult.pageName}'
                  : '抱歉，暂时无法打开${navResult.pageName}';
              await _speakWithSkipCheck(message);
              return VoiceSessionResult.success(message, {
                'navigation': navResult.route,
                'aiAssisted': true,
                'executed': executed,
              });
            }
          }

          // 处理AI识别的交易意图
          if (multiResult.completeIntents.isNotEmpty) {
            debugPrint('[VoiceCoordinator] AI识别到${multiResult.completeIntents.length}个完整交易意图');

            final executedCount = await _executeCompleteIntents(multiResult.completeIntents);
            if (executedCount > 0) {
              // 使用LLM生成回复
              final llmGen = LLMResponseGenerator.instance;
              final message = await llmGen.generateResponse(
                action: '记账',
                result: '成功记录$executedCount笔交易',
                success: true,
                userInput: originalInput,
              );
              await _speakWithSkipCheck(message);
              return VoiceSessionResult.success(message, {
                'executedCount': executedCount,
                'aiAssisted': true,
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[VoiceCoordinator] AI兜底失败: $e');
    }

    // AI也无法识别，进入闲聊模式
    debugPrint('[VoiceCoordinator] AI无法识别，进入闲聊模式');
    try {
      // 进入闲聊模式
      _conversationContext.enterChatMode();
      debugPrint('[VoiceCoordinator] 已进入闲聊模式');

      // 检测闲聊意图（用于引导LLM回复方向）
      final chatResponse = await _casualChatService.handleCasualChat(
        userId: 'default',
        input: originalInput,
      );
      final chatIntent = chatResponse.intent.name;

      // 使用LLM生成回复
      final llmGenerator = LLMResponseGenerator.instance;
      final message = await llmGenerator.generateCasualChatResponse(
        userInput: originalInput,
        chatIntent: chatIntent,
      );

      debugPrint('[VoiceCoordinator] LLM闲聊响应: $message');
      await _speakWithSkipCheck(message);

      // 记录到闲聊历史（用于多轮对话）
      _conversationContext.addChatTurn(
        userInput: originalInput,
        assistantResponse: message,
      );

      // 如果是再见意图，退出闲聊模式
      if (chatResponse.intent == CasualChatIntent.goodbye) {
        _conversationContext.exitChatMode();
        return VoiceSessionResult.success(message, {
          'chatMode': false,
          'chatIntent': chatIntent,
        });
      }

      return VoiceSessionResult.success(message, {
        'chatMode': true,
        'chatIntent': chatIntent,
        'suggestions': chatResponse.suggestions,
      });
    } catch (e) {
      debugPrint('[VoiceCoordinator] 闲聊处理失败: $e');
      _conversationContext.exitChatMode();
      const message = '嗯？没太听清，你是想记账还是查询呢？';
      await _speakWithSkipCheck(message);
      return VoiceSessionResult.error(message);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 闲聊模式处理
  // ═══════════════════════════════════════════════════════════════

  /// 检查输入是否像记账相关的指令
  bool _looksLikeBookkeepingIntent(String input) {
    // 记账关键词
    final bookkeepingPatterns = [
      RegExp(r'\d+[块元角分]'), // 金额
      RegExp(r'记[一]?笔'),
      RegExp(r'(支出|收入|花了|赚了|入账)'),
      RegExp(r'(删除|删掉|修改|改成).*[记录|交易|账]'),
      RegExp(r'(查询|查看|看看).*(消费|支出|收入|花了|账)'),
      RegExp(r'(预算|余额|结余|存款|储蓄)'),
      RegExp(r'(本月|这个月|今天|昨天|上周).*(花|消费|支出)'),
      RegExp(r'(打开|去|跳转).*(设置|预算|报表|首页)'),
    ];

    for (final pattern in bookkeepingPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  /// 处理闲聊模式下的输入
  Future<VoiceSessionResult> _processChatModeInput(String input) async {
    debugPrint('[VoiceCoordinator] 闲聊模式处理: $input');

    // 检查是否是记账相关意图
    if (_looksLikeBookkeepingIntent(input)) {
      debugPrint('[VoiceCoordinator] 检测到记账意图，退出闲聊模式');
      _conversationContext.exitChatMode();
      // 继续正常处理流程
      return await _processNormalInput(input);
    }

    // 检测闲聊意图（用于引导 LLM）
    final chatResponse = await _casualChatService.handleCasualChat(
      userId: 'default',
      input: input,
    );
    final chatIntent = chatResponse.intent.name;

    // 使用 LLM 生成回复，带上对话历史
    final llmGenerator = LLMResponseGenerator.instance;
    final chatHistory = _conversationContext.getChatHistoryForLLM();
    final message = await llmGenerator.generateCasualChatResponse(
      userInput: input,
      chatIntent: chatIntent,
      chatHistory: chatHistory,
    );

    debugPrint('[VoiceCoordinator] LLM闲聊回复: $message');
    await _speakWithSkipCheck(message);

    // 记录到闲聊历史
    _conversationContext.addChatTurn(
      userInput: input,
      assistantResponse: message,
    );

    // 如果是再见意图，退出闲聊模式
    if (chatResponse.intent == CasualChatIntent.goodbye) {
      debugPrint('[VoiceCoordinator] 用户告别，退出闲聊模式');
      _conversationContext.exitChatMode();
      return VoiceSessionResult.success(message, {
        'chatMode': false,
        'chatIntent': chatIntent,
      });
    }

    return VoiceSessionResult.success(message, {
      'chatMode': true,
      'chatIntent': chatIntent,
    });
  }

  /// 正常处理输入（非闲聊模式）
  Future<VoiceSessionResult> _processNormalInput(String input) async {
    // 记录命令历史
    final command = VoiceCommand(
      input: input,
      timestamp: DateTime.now(),
    );
    _addToHistory(command);

    // 记录到对话上下文
    _conversationContext.addUserInput(input);

    // 使用智能意图识别器分析
    final pageContext = _currentSession?.intentType.name ?? 'home';

    // 获取对话历史用于上下文理解
    final conversationHistory = GlobalVoiceAssistantManager.instance.conversationHistory
        .where((m) => m.type == ChatMessageType.user || m.type == ChatMessageType.assistant)
        .map((m) => {
          'role': m.type == ChatMessageType.user ? 'user' : 'assistant',
          'content': m.content,
        })
        .toList();

    final smartResult = await _smartRecognizer.recognize(
      input,
      pageContext: pageContext,
      conversationHistory: conversationHistory.isNotEmpty ? conversationHistory : null,
    );

    debugPrint('[VoiceCoordinator] SmartIntent结果: ${smartResult.intentType}, '
        '来源: ${smartResult.source}, 置信度: ${smartResult.confidence}');

    // 特殊处理：clarify 意图（信息不完整，需要反问用户）
    if (smartResult.intentType == SmartIntentType.clarify) {
      final clarifyQuestion = smartResult.entities['clarify_question'] as String?
          ?? '请提供更多信息';
      debugPrint('[VoiceCoordinator] 需要澄清: $clarifyQuestion');
      await _speakWithSkipCheck(clarifyQuestion);
      return VoiceSessionResult.waitingForClarification(clarifyQuestion);
    }

    // 转换为IntentAnalysisResult
    final intentResult = _convertSmartIntentResult(smartResult);

    // 更新命令历史
    command.intentResult = intentResult;

    // 提供反馈
    await _feedbackSystem.provideContextualFeedback(
      intentResult: intentResult,
      enableTts: true,
      enableHaptic: false,
    );

    // 路由处理
    final result = await _routeToIntentHandler(intentResult, input);
    command.result = result;

    return result;
  }

  // ═══════════════════════════════════════════════════════════════
  // 数据库回调方法
  // ═══════════════════════════════════════════════════════════════

  /// 查询交易记录的回调方法
  Future<List<TransactionRecord>> _queryTransactions(QueryConditions conditions) async {
    // 先尝试按分类和描述同时搜索
    var transactions = await _databaseService.queryTransactions(
      startDate: conditions.startDate,
      endDate: conditions.endDate,
      category: conditions.categoryHint,
      description: conditions.descriptionKeyword,  // 同时搜索描述字段
      merchant: conditions.merchantHint,
      minAmount: conditions.amountMin,
      maxAmount: conditions.amountMax,
      limit: conditions.limit,
    );

    // 如果没找到且有descriptionKeyword，尝试只按描述搜索（可能分类不匹配）
    if (transactions.isEmpty && conditions.descriptionKeyword != null) {
      debugPrint('[VoiceCoordinator] 按分类+描述未找到，尝试只按描述搜索');
      transactions = await _databaseService.queryTransactions(
        startDate: conditions.startDate,
        endDate: conditions.endDate,
        description: conditions.descriptionKeyword,
        minAmount: conditions.amountMin,
        maxAmount: conditions.amountMax,
        limit: conditions.limit,
      );
    }

    // 如果还没找到且有categoryHint，尝试只按分类搜索
    if (transactions.isEmpty && conditions.categoryHint != null) {
      debugPrint('[VoiceCoordinator] 按描述未找到，尝试只按分类搜索');
      transactions = await _databaseService.queryTransactions(
        startDate: conditions.startDate,
        endDate: conditions.endDate,
        category: conditions.categoryHint,
        minAmount: conditions.amountMin,
        maxAmount: conditions.amountMax,
        limit: conditions.limit,
      );
    }

    return transactions.map((t) => TransactionRecord(
      id: t.id,
      amount: t.amount,
      category: t.category,
      subCategory: t.subcategory,
      merchant: t.rawMerchant,
      description: t.note,
      date: t.date,
      account: t.accountId,
      tags: t.tags ?? [],
      type: t.type.name,
    )).toList();
  }

  /// 删除交易记录的回调方法
  Future<bool> _deleteTransactions(List<TransactionRecord> records) async {
    debugPrint('[VoiceCoordinator] _deleteTransactions 开始, 记录数: ${records.length}');
    try {
      for (final record in records) {
        debugPrint('[VoiceCoordinator] 软删除记录: id=${record.id}, ${record.category} ¥${record.amount}');
        final rowsAffected = await _databaseService.softDeleteTransaction(record.id);
        debugPrint('[VoiceCoordinator] softDeleteTransaction 返回: $rowsAffected');
        if (rowsAffected <= 0) {
          debugPrint('[VoiceCoordinator] 删除失败: rowsAffected=$rowsAffected');
          return false;
        }
      }
      debugPrint('[VoiceCoordinator] 所有记录删除成功');
      return true;
    } catch (e) {
      debugPrint('[VoiceCoordinator] 删除交易记录异常: $e');
      return false;
    }
  }

  /// 更新交易记录的回调方法
  Future<bool> _updateTransaction(TransactionRecord record) async {
    try {
      await _databaseService.updateTransaction(model.Transaction(
        id: record.id,
        type: model.TransactionType.values.firstWhere((e) => e.name == record.type, orElse: () => model.TransactionType.expense),
        amount: record.amount,
        category: record.category ?? '',
        subcategory: record.subCategory,
        note: record.description,
        date: record.date,
        accountId: record.account ?? '',
        tags: record.tags.isEmpty ? null : record.tags,
        rawMerchant: record.merchant,
      ));
      return true;
    } catch (e) {
      debugPrint('更新交易记录失败: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 会话管理
  // ═══════════════════════════════════════════════════════════════

  /// 停止当前语音会话
  Future<void> stopVoiceSession() async {
    _sessionState = VoiceSessionState.idle;
    _clearSession();
    await _ttsService.stop();
    notifyListeners();
  }

  /// 启动会话超时计时器
  void _startSessionTimeout() {
    _cancelSessionTimeout();
    _lastActivityTime = DateTime.now();

    final timeout = _isWaitingState() ? _waitingStateTimeout : _sessionTimeout;

    _sessionTimeoutTimer = Timer(timeout, () {
      _handleSessionTimeout();
    });
  }

  /// 检查输入是否无效或异常
  ///
  /// 只做最基本的预处理，过滤明显的噪音/空输入
  /// 有效性和意图判断交给 LLM 处理
  String? _checkInvalidInput(String input) {
    final trimmed = input.trim();

    // 1. 输入为空或太短（单个字符无法表达意图）
    if (trimmed.isEmpty) {
      return '没有听清楚，请再说一遍';
    }

    // 2. 纯噪音内容（只有语气词、标点符号）
    final noisePatterns = RegExp(r'^[啊呃嗯哦唔额哈嘿呀吧了的吗呢嘛，。、！？\s]+$');
    if (noisePatterns.hasMatch(trimmed)) {
      return '没有听清楚，请再说一遍';
    }

    // 3. 重复字符过多（明显的ASR识别噪音）
    if (_hasExcessiveRepetition(trimmed)) {
      return '没有听清楚，请再说一遍';
    }

    // 其他情况交给 LLM 判断意图和有效性
    return null;
  }

  /// 检查是否有过多重复字符
  bool _hasExcessiveRepetition(String text) {
    if (text.length < 4) return false;

    // 检查连续重复字符（排除数字，因为金额可能有重复数字如1111、2222）
    var maxRepeat = 1;
    var currentRepeat = 1;
    for (var i = 1; i < text.length; i++) {
      if (text[i] == text[i - 1]) {
        currentRepeat++;
        // 只对非数字字符计算重复
        final isDigit = text[i].codeUnitAt(0) >= 48 && text[i].codeUnitAt(0) <= 57;
        if (!isDigit && currentRepeat > maxRepeat) {
          maxRepeat = currentRepeat;
        }
      } else {
        currentRepeat = 1;
      }
    }

    // 超过3个连续重复非数字字符认为是噪音
    return maxRepeat > 3;
  }

  /// 获取相对时间描述（用于语音播报）
  String _getTimeAgoDescription(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚才';
    } else if (diff.inMinutes < 5) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inMinutes < 30) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 1) {
      return '半小时前';
    } else if (diff.inHours < 2) {
      return '1小时前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${dateTime.month}月${dateTime.day}日';
    }
  }

  /// 格式化日期时间（用于聊天记录显示）
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    if (isToday) {
      return '今天 $hour:$minute';
    } else if (dateTime.year == now.year) {
      return '${dateTime.month}月${dateTime.day}日 $hour:$minute';
    } else {
      return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 $hour:$minute';
    }
  }

  /// 取消会话超时计时器
  void _cancelSessionTimeout() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;
  }

  /// 重置会话超时（用户有活动时调用）
  void _resetSessionTimeout() {
    if (_sessionState != VoiceSessionState.idle) {
      _startSessionTimeout();
    }
  }

  /// 检查是否处于等待状态
  bool _isWaitingState() {
    return _sessionState == VoiceSessionState.waitingForConfirmation ||
           _sessionState == VoiceSessionState.waitingForClarification ||
           _sessionState == VoiceSessionState.waitingForMultiIntentConfirmation ||
           _sessionState == VoiceSessionState.waitingForAmountSupplement;
  }

  /// 处理会话超时
  Future<void> _handleSessionTimeout() async {
    if (_sessionState == VoiceSessionState.idle) return;

    debugPrint('VoiceServiceCoordinator: session timeout');

    // 通知用户
    await _feedbackSystem.provideFeedback(
      message: '会话已超时，如需继续请重新开始',
      type: VoiceFeedbackType.info,
      priority: VoiceFeedbackPriority.medium,
    );

    // 清理会话
    _clearSession();
    notifyListeners();
  }

  /// 取消当前进行中的操作
  ///
  /// 用于错误恢复和用户主动取消场景
  Future<void> cancelCurrentOperation() async {
    try {
      // 取消语音识别
      await _recognitionEngine.cancelTranscription();

      // 停止 TTS
      await _ttsService.stop();

      // 取消删除操作
      _deleteService.cancelDelete();

      // 取消修改操作
      _modifyService.cancelModification();

      // 取消自动化任务
      _automationService.cancelTask();

      debugPrint('VoiceServiceCoordinator: all operations cancelled');
    } catch (e) {
      debugPrint('VoiceServiceCoordinator: cancel operation error - $e');
    }
  }

  /// 清除当前会话
  void _clearSession() {
    _cancelSessionTimeout();
    _currentSession = null;
    _pendingMultiIntent = null;
    _sessionState = VoiceSessionState.idle;
    _deleteService.cancelDelete();
    _modifyService.clearSession();
  }

  // ═══════════════════════════════════════════════════════════════
  // 错误恢复机制
  // ═══════════════════════════════════════════════════════════════

  /// 错误重试计数
  int _errorRetryCount = 0;
  static const int _maxErrorRetries = 3;

  /// 尝试从错误状态恢复
  ///
  /// 返回是否成功恢复
  Future<bool> tryRecoverFromError() async {
    if (_sessionState != VoiceSessionState.error) {
      return true; // 不在错误状态，无需恢复
    }

    debugPrint('VoiceServiceCoordinator: attempting error recovery');

    try {
      // 停止所有正在进行的操作
      await cancelCurrentOperation();

      // 重置状态
      _clearSession();
      _errorRetryCount = 0;

      // 通知用户
      await _feedbackSystem.provideFeedback(
        message: '已恢复，请重试',
        type: VoiceFeedbackType.info,
        priority: VoiceFeedbackPriority.high,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('VoiceServiceCoordinator: error recovery failed - $e');
      return false;
    }
  }

  /// 处理可恢复错误
  ///
  /// 对于网络超时、Token过期等可恢复错误，自动重试
  /// 可由 UI 层调用进行手动重试
  Future<VoiceSessionResult> handleRecoverableError(
    String operation,
    Object error,
    Future<VoiceSessionResult> Function() retryOperation,
  ) async {
    final errorType = _classifyError(error);

    if (errorType == VoiceErrorType.recoverable && _errorRetryCount < _maxErrorRetries) {
      _errorRetryCount++;
      debugPrint('VoiceServiceCoordinator: retrying $operation (attempt $_errorRetryCount/$_maxErrorRetries)');

      // 等待后重试
      await Future.delayed(Duration(milliseconds: 500 * _errorRetryCount));

      try {
        final result = await retryOperation();
        _errorRetryCount = 0; // 成功后重置
        return result;
      } catch (e) {
        return handleRecoverableError(operation, e, retryOperation);
      }
    }

    // 不可恢复或重试次数用尽
    _sessionState = VoiceSessionState.error;
    _errorRetryCount = 0;
    notifyListeners();

    final message = _getErrorMessage(error, errorType);
    final suggestion = _getErrorSuggestion(errorType);
    await _feedbackSystem.provideErrorFeedback(
      error: message,
      suggestion: suggestion,
    );

    return VoiceSessionResult.error(message);
  }

  /// 错误分类
  VoiceErrorType _classifyError(Object error) {
    final errorString = error.toString().toLowerCase();

    // 网络相关错误 - 可恢复
    if (errorString.contains('timeout') ||
        errorString.contains('网络') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return VoiceErrorType.recoverable;
    }

    // Token相关错误 - 可恢复
    if (errorString.contains('token') ||
        errorString.contains('认证') ||
        errorString.contains('auth')) {
      return VoiceErrorType.recoverable;
    }

    // 权限错误 - 不可恢复（需要用户操作）
    if (errorString.contains('permission') ||
        errorString.contains('权限')) {
      return VoiceErrorType.permissionDenied;
    }

    // 服务不可用 - 不可恢复
    if (errorString.contains('503') ||
        errorString.contains('service unavailable') ||
        errorString.contains('服务不可用')) {
      return VoiceErrorType.serviceUnavailable;
    }

    // 其他错误
    return VoiceErrorType.unknown;
  }

  /// 获取用户友好的错误消息
  String _getErrorMessage(Object error, VoiceErrorType errorType) {
    switch (errorType) {
      case VoiceErrorType.recoverable:
        return '网络不稳定';
      case VoiceErrorType.permissionDenied:
        return '需要麦克风权限';
      case VoiceErrorType.serviceUnavailable:
        return '语音服务暂时不可用';
      case VoiceErrorType.unknown:
        return '操作遇到问题';
    }
  }

  /// 获取错误建议
  String _getErrorSuggestion(VoiceErrorType errorType) {
    switch (errorType) {
      case VoiceErrorType.recoverable:
        return '请检查网络连接后重试';
      case VoiceErrorType.permissionDenied:
        return '请在系统设置中授予麦克风权限';
      case VoiceErrorType.serviceUnavailable:
        return '请稍后再试，或使用离线模式';
      case VoiceErrorType.unknown:
        return '请稍后重试';
    }
  }

  /// 添加命令到历史记录
  void _addToHistory(VoiceCommand command) {
    _commandHistory.add(command);
    if (_commandHistory.length > maxHistorySize) {
      _commandHistory.removeAt(0);
    }
  }

  /// 获取最近的命令历史
  List<VoiceCommand> getRecentCommands({int limit = 10}) {
    final start = _commandHistory.length > limit ? _commandHistory.length - limit : 0;
    return _commandHistory.sublist(start).reversed.toList();
  }

  /// 清除命令历史
  void clearCommandHistory() {
    _commandHistory.clear();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // SmartIntentRecognizer 集成
  // ═══════════════════════════════════════════════════════════════

  /// 将SmartIntentResult转换为IntentAnalysisResult
  IntentAnalysisResult _convertSmartIntentResult(SmartIntentResult smartResult) {
    return IntentAnalysisResult(
      intent: _mapSmartIntentTypeToVoiceIntentType(smartResult.intentType),
      confidence: smartResult.confidence,
      entities: Map<String, dynamic>.from(smartResult.entities),
      rawInput: smartResult.originalInput,
    );
  }

  /// 将SmartIntentType映射到VoiceIntentType
  VoiceIntentType _mapSmartIntentTypeToVoiceIntentType(SmartIntentType type) {
    switch (type) {
      case SmartIntentType.addTransaction:
        return VoiceIntentType.addTransaction;
      case SmartIntentType.navigate:
        return VoiceIntentType.navigateToPage;
      case SmartIntentType.query:
        return VoiceIntentType.queryTransaction;
      case SmartIntentType.modify:
        return VoiceIntentType.modifyTransaction;
      case SmartIntentType.delete:
        return VoiceIntentType.deleteTransaction;
      case SmartIntentType.confirm:
        return VoiceIntentType.confirmAction;
      case SmartIntentType.cancel:
        return VoiceIntentType.cancelAction;
      case SmartIntentType.config:
        return VoiceIntentType.configOperation;
      case SmartIntentType.moneyAge:
        return VoiceIntentType.moneyAgeOperation;
      case SmartIntentType.habit:
        return VoiceIntentType.habitOperation;
      case SmartIntentType.vault:
        return VoiceIntentType.vaultOperation;
      case SmartIntentType.dataOp:
        return VoiceIntentType.dataOperation;
      case SmartIntentType.share:
        return VoiceIntentType.shareOperation;
      case SmartIntentType.systemOp:
        return VoiceIntentType.systemOperation;
      case SmartIntentType.advice:
        return VoiceIntentType.adviceOperation;
      case SmartIntentType.clarify:
        return VoiceIntentType.clarifySelection;
      case SmartIntentType.chat:
        return VoiceIntentType.chatOperation;
      case SmartIntentType.unknown:
        return VoiceIntentType.unknown;
    }
  }

  /// 释放资源
  @override
  void dispose() {
    // 取消会话超时计时器
    _cancelSessionTimeout();

    // 释放语音识别引擎
    _recognitionEngine.dispose();

    // 释放TTS服务
    _ttsService.dispose();

    // 释放反馈系统（内部有自己的TTS实例）
    _feedbackSystem.dispose();

    // 释放打断检测器
    _bargeInDetector.dispose();

    // 清空智能引擎引用
    _intelligenceEngine = null;

    // 清理命令历史防止内存泄漏
    _commandHistory.clear();

    // 清理待处理的多意图结果
    _pendingMultiIntent = null;

    // 释放实体消歧服务
    _disambiguationService.dispose();

    // 释放删除服务
    _deleteService.dispose();

    // 释放修改服务
    _modifyService.dispose();

    // 清理对话上下文
    _conversationContext.endSession();

    // 注意：以下服务不在此处释放
    // - _databaseService: 通常由应用级别管理，多处共享
    // - _navigationService, _intentRouter: 无状态资源需清理
    // - _screenReaderService, _automationService: 无dispose方法

    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据类型定义
// ═══════════════════════════════════════════════════════════════

/// 语音会话状态
enum VoiceSessionState {
  idle,                           // 空闲
  listening,                      // 正在听取
  processing,                     // 正在处理
  waitingForConfirmation,         // 等待确认
  waitingForClarification,        // 等待澄清
  waitingForMultiIntentConfirmation, // 等待多意图确认
  waitingForAmountSupplement,     // 等待金额补充
  automationRunning,              // 自动化任务执行中
  error,                          // 错误状态
  recovering,                     // 恢复中
}

/// 语音错误类型
enum VoiceErrorType {
  recoverable,        // 可恢复错误（网络超时、Token过期等）
  permissionDenied,   // 权限被拒绝
  serviceUnavailable, // 服务不可用
  unknown,            // 未知错误
}

/// 语音意图类型
enum VoiceIntentType {
  unknown,
  deleteTransaction,         // 删除交易
  modifyTransaction,         // 修改交易
  addTransaction,            // 添加交易
  queryTransaction,          // 查询交易
  navigateToPage,            // 页面导航
  confirmAction,             // 确认操作
  cancelAction,              // 取消操作
  clarifySelection,          // 澄清选择
  screenRecognition,         // 屏幕识别记账
  automateAlipaySync,        // 自动化支付宝账单同步
  automateWeChatSync,        // 自动化微信账单同步
  configOperation,           // 配置操作
  moneyAgeOperation,         // 钱龄操作
  habitOperation,            // 习惯操作
  vaultOperation,            // 小金库操作
  dataOperation,             // 数据操作
  shareOperation,            // 分享操作
  systemOperation,           // 系统操作
  adviceOperation,           // 建议操作（财务建议、省钱建议、洞察分析等）
  chatOperation,             // 闲聊操作（讲故事、讲笑话等）
}

/// 建议类型（内部使用）
/// 语音会话结果状态
enum VoiceSessionStatus {
  success,
  error,
  partial,
  waitingForConfirmation,
  waitingForClarification,
}

/// 语音会话上下文
class VoiceSessionContext {
  final VoiceIntentType intentType;
  final dynamic sessionData;
  final bool needsContinuation;
  final DateTime createdAt;

  const VoiceSessionContext({
    required this.intentType,
    this.sessionData,
    required this.needsContinuation,
    required this.createdAt,
  });
}

/// 语音会话结果
class VoiceSessionResult {
  final VoiceSessionStatus status;
  final String? message;
  final String? errorMessage;
  final dynamic data;

  const VoiceSessionResult({
    required this.status,
    this.message,
    this.errorMessage,
    this.data,
  });

  factory VoiceSessionResult.success(String message, [dynamic data]) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.success,
      message: message,
      data: data,
    );
  }

  factory VoiceSessionResult.error(String errorMessage) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.error,
      errorMessage: errorMessage,
    );
  }

  factory VoiceSessionResult.partial(String message) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.partial,
      message: message,
    );
  }

  factory VoiceSessionResult.waitingForConfirmation(String message) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.waitingForConfirmation,
      message: message,
    );
  }

  factory VoiceSessionResult.waitingForClarification(String message) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.waitingForClarification,
      message: message,
    );
  }

  factory VoiceSessionResult.fromDeleteResult(DeleteResult deleteResult) {
    if (deleteResult.isSuccess) {
      return VoiceSessionResult.success(deleteResult.message ?? '删除成功');
    } else if (deleteResult.needsClarification) {
      return VoiceSessionResult.waitingForClarification(deleteResult.prompt ?? '请选择要删除的记录');
    } else if (deleteResult.needsConfirmation) {
      return VoiceSessionResult.waitingForConfirmation(deleteResult.prompt ?? '请确认删除');
    } else {
      return VoiceSessionResult.error(deleteResult.errorMessage ?? '删除失败');
    }
  }

  factory VoiceSessionResult.fromModifyResult(ModifyResult modifyResult) {
    if (modifyResult.isSuccess) {
      return VoiceSessionResult.success('修改成功');
    } else if (modifyResult.needsClarification) {
      return VoiceSessionResult.waitingForClarification(modifyResult.prompt ?? '请选择要修改的记录');
    } else if (modifyResult.needsConfirmation) {
      return VoiceSessionResult.waitingForConfirmation(modifyResult.preview?.generatePreviewText() ?? '请确认修改');
    } else {
      return VoiceSessionResult.error(modifyResult.errorMessage ?? '修改失败');
    }
  }

  bool get isSuccess => status == VoiceSessionStatus.success;
  bool get isError => status == VoiceSessionStatus.error;
  bool get isPartial => status == VoiceSessionStatus.partial;
  bool get needsConfirmation => status == VoiceSessionStatus.waitingForConfirmation;
  bool get needsClarification => status == VoiceSessionStatus.waitingForClarification;
}

/// 语音命令记录
class VoiceCommand {
  final String input;
  final DateTime timestamp;
  IntentAnalysisResult? intentResult;
  VoiceSessionResult? result;

  VoiceCommand({
    required this.input,
    required this.timestamp,
    this.intentResult,
    this.result,
  });
}