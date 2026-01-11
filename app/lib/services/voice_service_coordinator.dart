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
import 'voice_recognition_engine.dart';
import 'tts_service.dart';
import 'voice_navigation_service.dart';
import 'voice_feedback_system.dart';
import 'screen_reader_service.dart';
import 'automation_task_service.dart';

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

  /// 对话上下文管理
  final ConversationContext _conversationContext;

  /// 打断检测器
  final BargeInDetector _bargeInDetector;

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
    ConversationContext? conversationContext,
    BargeInDetector? bargeInDetector,
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
       _conversationContext = conversationContext ?? ConversationContext(),
       _bargeInDetector = bargeInDetector ?? BargeInDetector(),
       _streamingTTSEnabled = enableStreamingTTS {
    // 设置打断检测回调
    _bargeInDetector.onBargeInDetected = _handleBargeIn;
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

      // 记录命令历史
      final command = VoiceCommand(
        input: voiceInput,
        timestamp: DateTime.now(),
      );
      _addToHistory(command);

      // 记录到对话上下文（用于多轮对话和自然响应生成）
      _conversationContext.addUserInput(voiceInput);

      // Step 1: 使用意图路由器分析语音输入
      final contextData = _currentSession != null
          ? VoiceSessionContext(
              intentType: _currentSession!.intentType,
              sessionData: _currentSession!.sessionData ?? {},
              needsContinuation: true,
              createdAt: _currentSession!.createdAt,
            )
          : null;

      final intentResult = await _intentRouter.analyzeIntent(
        voiceInput,
        context: contextData,
      );

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

      final message = '已记录$executedCount笔交易${navigationMessage != null ? '，$navigationMessage' : ''}';
      await _ttsService.speak(message);

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
        debugPrint('执行意图失败: $e');
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
        final message = '已记录消费${transaction.amount.toStringAsFixed(2)}元';
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
      final amount = entities['amount'] as double?;
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
        // 发现潜在重复，提示用户
        final duplicateMessage = '检测到可能的重复记录：${duplicateCheck.duplicateReason}。是否仍要添加？请说"确认"或"取消"。';
        await _ttsService.speak(duplicateMessage);

        // 保存待确认的交易到会话
        _currentSession = VoiceSessionContext(
          intentType: VoiceIntentType.addTransaction,
          sessionData: {'transaction': transaction, 'duplicateCheck': duplicateCheck},
          needsContinuation: true,
          createdAt: DateTime.now(),
        );
        _sessionState = VoiceSessionState.waitingForConfirmation;
        notifyListeners();

        return VoiceSessionResult.success(duplicateMessage, {
          'needsConfirmation': true,
          'duplicateCheck': duplicateCheck,
        });
      }

      await _databaseService.insertTransaction(transaction);

      // 记录交易引用到对话上下文（用于后续代词指代，如"删掉它"）
      final transactionRef = TransactionReference(
        id: transaction.id,
        amount: amount,
        category: category ?? 'other_expense',
        date: DateTime.now(),
      );

      // 使用自然语言响应生成
      final message = ResponseTemplate.recordSuccess(
        amount: amount,
        category: category ?? '',
        useNaturalStyle: true,
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

  /// 处理查询意图
  Future<VoiceSessionResult> _handleQueryIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    try {
      final entities = intentResult.entities;
      final startDate = entities['startDate'] as DateTime?;
      final endDate = entities['endDate'] as DateTime?;
      final category = entities['category'] as String?;

      // 查询交易记录
      final transactions = await _databaseService.queryTransactions(
        startDate: startDate,
        endDate: endDate,
        category: category,
        limit: 10,
      );

      if (transactions.isEmpty) {
        const message = '没有找到符合条件的记录';
        await _ttsService.speak(message);
        return VoiceSessionResult.success(message);
      }

      // 计算总金额
      final totalExpense = transactions
          .where((t) => t.type == model.TransactionType.expense)
          .fold(0.0, (sum, t) => sum + t.amount);
      final totalIncome = transactions
          .where((t) => t.type == model.TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);

      String message;
      if (totalExpense > 0 && totalIncome > 0) {
        message = '共${transactions.length}条记录，支出${totalExpense.toStringAsFixed(2)}元，收入${totalIncome.toStringAsFixed(2)}元';
      } else if (totalExpense > 0) {
        message = '共${transactions.length}条记录，总支出${totalExpense.toStringAsFixed(2)}元';
      } else {
        message = '共${transactions.length}条记录，总收入${totalIncome.toStringAsFixed(2)}元';
      }

      await _ttsService.speak(message);
      _clearSession();
      notifyListeners();
      return VoiceSessionResult.success(message);
    } catch (e) {
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

      String message;
      if (validBills.length == 1) {
        final billInfo = validBills.first;
        message = '已记录${billInfo.typeDisplayName}${billInfo.amount!.toStringAsFixed(2)}元';
      } else {
        message = '已批量记录${validBills.length}笔交易，总金额${totalAmount.toStringAsFixed(2)}元';
      }
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

  /// 处理未知意图
  Future<VoiceSessionResult> _handleUnknownIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
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