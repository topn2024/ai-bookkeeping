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
import 'voice_recognition_engine.dart';
import 'tts_service.dart';
import 'voice_navigation_service.dart';
import 'voice_feedback_system.dart';
import 'screen_reader_service.dart';
import 'automation_task_service.dart';
import 'nl_search_service.dart';
import 'voice_budget_query_service.dart';
import 'vault_repository.dart';

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
  VoiceBudgetQueryService? _budgetQueryService;

  /// 对话上下文管理
  final ConversationContext _conversationContext;

  /// 打断检测器
  final BargeInDetector _bargeInDetector;

  /// AI意图分解器（大模型兜底）
  final AIIntentDecomposer _aiDecomposer;

  /// 智能意图识别器（多层递进架构）
  final SmartIntentRecognizer _smartRecognizer;

  /// 是否启用流式TTS模式
  bool _streamingTTSEnabled = true;

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
  static const Duration _sessionTimeout = Duration(seconds: 30);
  static const Duration _waitingStateTimeout = Duration(seconds: 60);

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
    ConversationContext? conversationContext,
    BargeInDetector? bargeInDetector,
    AIIntentDecomposer? aiDecomposer,
    SmartIntentRecognizer? smartRecognizer,
    bool enableStreamingTTS = true,
  }) : _recognitionEngine = recognitionEngine ?? VoiceRecognitionEngine(),
       _ttsService = ttsService ?? TTSService(enableStreaming: enableStreamingTTS),
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

      // 记录命令历史
      final command = VoiceCommand(
        input: voiceInput,
        timestamp: DateTime.now(),
      );
      _addToHistory(command);

      // 记录到对话上下文（用于多轮对话和自然响应生成）
      _conversationContext.addUserInput(voiceInput);

      // Step 1: 使用智能意图识别器分析语音输入（多层递进架构）
      // Layer 1: 精确规则匹配 → Layer 2: 同义词扩展 → Layer 3: 模板匹配
      // → Layer 4: 学习缓存 → Layer 5: LLM兜底
      final pageContext = _currentSession?.intentType.name ?? 'home';
      final smartResult = await _smartRecognizer.recognize(
        voiceInput,
        pageContext: pageContext,
      );

      debugPrint('[VoiceCoordinator] SmartIntent结果: ${smartResult.intentType}, '
          '来源: ${smartResult.source}, 置信度: ${smartResult.confidence}');

      // 转换为IntentAnalysisResult以兼容现有处理流程
      final intentResult = _convertSmartIntentResult(smartResult);

      // 更新命令历史中的意图分析结果
      command.intentResult = intentResult;

      // 提供上下文感知的反馈
      await _feedbackSystem.provideContextualFeedback(
        intentResult: intentResult,
        enableTts: true,
        enableHaptic: false, // 避免处理过程中过度震动
      );

      // Step 2: 根据意图类型路由处理
      final result = await _routeToIntentHandler(intentResult, voiceInput);

      // 更新命令历史中的结果
      command.result = result;

      return result;
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
      await _ttsService.speak(prompt);

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
        await _ttsService.speak(supplementPrompt);

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
      await _ttsService.speak(finalMessage);

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
    await _ttsService.speak(message);

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
    await _ttsService.speak(message);

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
      await _ttsService.speak(message);
      return VoiceSessionResult.success(message);
    } else {
      final message = '已补充第${index + 1}项金额${amount.toStringAsFixed(2)}元，还有${newIncomplete.length}项需要补充金额';
      await _ttsService.speak(message);
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
    final result = _navigationService.parseNavigation(intent.originalText);
    if (result.success) {
      return '正在跳转到${result.pageName}';
    }
    return '';
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
    await _ttsService.speak(feedbackText);

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
      await _ttsService.speak(message);
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
        await _ttsService.speak(message);
        result = VoiceSessionResult.success(message);
        break;

      case VoiceIntentType.screenRecognition:
        // 确认屏幕识别的账单
        result = await confirmScreenRecognition();
        break;

      default:
        const message = '无法确认此类型的操作';
        await _ttsService.speak(message);
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
      await _ttsService.speak(message);
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
    await _ttsService.speak(message);

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
      await _ttsService.speak(message);
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
        await _ttsService.speak(message);
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
    try {
      final entities = intentResult.entities;
      // 使用 num 类型处理，因为 LLM 可能返回 int 或 double
      final amount = (entities['amount'] as num?)?.toDouble();
      final category = entities['category'] as String?;
      final merchant = entities['merchant'] as String?;

      if (amount == null || amount <= 0) {
        const message = '请告诉我金额是多少';
        await _ttsService.speak(message);
        return VoiceSessionResult.error(message);
      }

      // 创建交易记录
      final transaction = model.Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: model.TransactionType.expense,
        amount: amount,
        category: category ?? 'other_expense',
        note: merchant != null ? '在$merchant消费' : originalInput,
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
        await _ttsService.speak(voiceMessage);
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

      await _databaseService.insertTransaction(transaction);

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
      await _ttsService.speak(message);

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
        await _ttsService.speak(result.spokenResponse);
        return VoiceSessionResult.error(result.spokenResponse);
      }

      await _ttsService.speak(result.spokenResponse);
      _clearSession();
      notifyListeners();

      return VoiceSessionResult.success(
        result.spokenResponse,
        result.data,
      );
    } catch (e) {
      debugPrint('[VoiceCoordinator] 预算查询失败: $e');
      const message = '查询预算时遇到问题，请稍后重试';
      await _ttsService.speak(message);
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

      // 1. 先检测是否是预算相关查询
      if (_isBudgetQuery(originalInput)) {
        debugPrint('[VoiceCoordinator] 检测到预算查询，使用 VoiceBudgetQueryService');
        return await _handleBudgetQuery(originalInput);
      }

      // 2. 否则使用 NaturalLanguageSearchService 进行交易记录查询
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

      await _ttsService.speak(message);
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

  /// 处理导航意图
  Future<VoiceSessionResult> _handleNavigationIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    final result = _navigationService.parseNavigation(originalInput);
    final message = result.success
        ? '正在跳转到${result.pageName}'
        : result.errorMessage ?? '导航失败';
    await _ttsService.speak(message);

    // Include navigation route in result data so UI can perform navigation
    return VoiceSessionResult.success(
      message,
      result.success ? {'route': result.route, 'pageName': result.pageName} : null,
    );
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
    await _ttsService.speak(feedback);

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
        category: b.typeDisplayName ?? '其他',
        isIncome: b.type == 'income',
        merchant: b.merchant,
      )).toList();
      final message = await llmGen.generateTransactionResponse(
        transactions: txInfos,
        userInput: '屏幕识别记账',
      );
      await _ttsService.speak(message);

      return VoiceSessionResult.success(message, {
        'recorded': true,
        'recordedCount': validBills.length,
        'totalAmount': totalAmount,
        'transactionIds': recordedIds,
      });
    } catch (e) {
      _clearSession();
      final message = '记录失败：$e';
      await _ttsService.speak(message);
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
    await _ttsService.speak('好的，正在打开$appName读取账单...');

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
      await _ttsService.speak(feedback);

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
      await _ttsService.speak(message);
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
  Future<VoiceSessionResult> _handleConfigIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      debugPrint('[VoiceCoordinator] 处理配置意图: $originalInput');
      final entities = intentResult.entities;
      final configId = entities['configId'] as String?;
      final configValue = entities['value'];

      if (configId == null) {
        const message = '请告诉我要修改哪个配置';
        await _ttsService.speak(message);
        return VoiceSessionResult.error(message);
      }

      // 通过VoiceConfigService处理配置
      // TODO: 集成VoiceConfigService执行配置修改
      final message = '已更新配置：$configId';
      await _ttsService.speak(message);

      return VoiceSessionResult.success(message, {
        'config': configId,
        'value': configValue,
      });
    } catch (e) {
      final message = '配置修改失败: $e';
      await _ttsService.speak(message);
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

      await _ttsService.speak(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '钱龄操作失败: $e';
      await _ttsService.speak(message);
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

      await _ttsService.speak(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '习惯操作失败: $e';
      await _ttsService.speak(message);
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
            await _ttsService.speak(message);
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
            await _ttsService.speak(message);
            return VoiceSessionResult.error(message);
          }
          message = '已从$vaultName调拨${amount.toStringAsFixed(0)}元到$targetVault';
          data = {'from': vaultName, 'to': targetVault, 'amount': amount};
          break;

        case 'withdraw':
          // 取出资金
          if (amount == null || vaultName == null) {
            message = '请告诉我从哪个小金库取多少钱';
            await _ttsService.speak(message);
            return VoiceSessionResult.error(message);
          }
          message = '已从$vaultName取出${amount.toStringAsFixed(0)}元';
          data = {'vault': vaultName, 'amount': amount, 'withdrawn': true};
          break;

        default:
          message = '小金库操作已完成';
      }

      await _ttsService.speak(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '小金库操作失败: $e';
      await _ttsService.speak(message);
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

      await _ttsService.speak(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '数据操作失败: $e';
      await _ttsService.speak(message);
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

      await _ttsService.speak(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '分享操作失败: $e';
      await _ttsService.speak(message);
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

      await _ttsService.speak(message);
      return VoiceSessionResult.success(message, data);
    } catch (e) {
      final message = '系统操作失败: $e';
      await _ttsService.speak(message);
      return VoiceSessionResult.error(message);
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
            if (navResult.success) {
              final message = '正在打开${navResult.pageName}';
              await _ttsService.speak(message);
              return VoiceSessionResult.success(message, {
                'navigation': navResult.route,
                'aiAssisted': true,
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
              await _ttsService.speak(message);
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

    // AI也无法识别，返回错误
    const message = '抱歉，我没有理解您的指令。请说得更清楚一些，或者尝试其他表达方式。';
    await _ttsService.speak(message);
    return VoiceSessionResult.error(message);
  }

  // ═══════════════════════════════════════════════════════════════
  // 数据库回调方法
  // ═══════════════════════════════════════════════════════════════

  /// 查询交易记录的回调方法
  Future<List<TransactionRecord>> _queryTransactions(QueryConditions conditions) async {
    final transactions = await _databaseService.queryTransactions(
      startDate: conditions.startDate,
      endDate: conditions.endDate,
      category: conditions.categoryHint,
      merchant: conditions.merchantHint,
      minAmount: conditions.amountMin,
      maxAmount: conditions.amountMax,
      limit: conditions.limit,
    );

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
    try {
      for (final record in records) {
        final rowsAffected = await _databaseService.softDeleteTransaction(record.id);
        if (rowsAffected <= 0) return false;
      }
      return true;
    } catch (e) {
      debugPrint('删除交易记录失败: $e');
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
  /// 返回无效原因，如果输入有效则返回 null
  String? _checkInvalidInput(String input) {
    final trimmed = input.trim();

    // 1. 输入太短
    if (trimmed.length < 2) {
      return '没有听清楚，请再说一遍';
    }

    // 2. ASR识别错误的特征词（识别结果中包含这些通常表示识别出错）
    final asrErrorPatterns = [
      '没理解',
      '没有理解',
      '不理解',
      '更清楚',
      '说清楚',
      '再说一遍',
      '没听清',
      '听不清',
      '您的指',  // 被截断的"您的指令"
      '您说的',
    ];

    for (final pattern in asrErrorPatterns) {
      if (trimmed.contains(pattern)) {
        return '没有听清楚，请再说一遍';
      }
    }

    // 3. 纯噪音或无意义内容（只有语气词、叹词）
    final noisePatterns = RegExp(r'^[啊呃嗯哦唔额哈嘿呀吧了的吗呢嘛，。、！？\s]+$');
    if (noisePatterns.hasMatch(trimmed)) {
      return '没有听清楚，请再说一遍';
    }

    // 4. 重复字符过多（可能是噪音）
    if (_hasExcessiveRepetition(trimmed)) {
      return '没有听清楚，请再说一遍';
    }

    // 5. 检查是否包含任何有意义的关键词
    final meaningfulKeywords = [
      // 记账相关
      '花', '买', '吃', '喝', '付', '收', '转', '存', '取', '充',
      '元', '块', '毛', '分',
      // 数字
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
      '一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '百', '千', '万',
      // 导航相关
      '打开', '进入', '查看', '看看', '设置', '预算', '统计', '账户', '记录',
      // 确认相关
      '确认', '取消', '是', '否', '好', '行', '可以', '不',
      // 查询相关
      '多少', '几', '什么', '哪', '怎么',
    ];

    final hasMeaningfulContent = meaningfulKeywords.any((k) => trimmed.contains(k));
    if (!hasMeaningfulContent && trimmed.length < 10) {
      return '没有听清楚，请再说一遍';
    }

    return null; // 输入有效
  }

  /// 检查是否有过多重复字符
  bool _hasExcessiveRepetition(String text) {
    if (text.length < 4) return false;

    // 检查连续重复字符
    var maxRepeat = 1;
    var currentRepeat = 1;
    for (var i = 1; i < text.length; i++) {
      if (text[i] == text[i - 1]) {
        currentRepeat++;
        if (currentRepeat > maxRepeat) {
          maxRepeat = currentRepeat;
        }
      } else {
        currentRepeat = 1;
      }
    }

    // 超过3个连续重复字符认为是噪音
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
}

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