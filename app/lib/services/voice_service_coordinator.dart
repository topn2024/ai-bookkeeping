import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/transaction.dart' as model;
import '../services/database_service.dart';
import '../services/database_voice_extension.dart';
import '../services/duplicate_detection_service.dart';
import 'voice/entity_disambiguation_service.dart';
import 'voice/voice_delete_service.dart';
import 'voice/voice_modify_service.dart';
import 'voice/voice_intent_router.dart';
import 'voice/multi_intent_models.dart';
import 'voice_recognition_engine.dart';
import 'tts_service.dart';
import 'voice_navigation_service.dart';
import 'voice_feedback_system.dart';
import 'nlu_engine.dart';

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
  final DatabaseService _databaseService;

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

  VoiceServiceCoordinator({
    VoiceRecognitionEngine? recognitionEngine,
    TTSService? ttsService,
    EntityDisambiguationService? disambiguationService,
    VoiceDeleteService? deleteService,
    VoiceModifyService? modifyService,
    VoiceNavigationService? navigationService,
    VoiceIntentRouter? intentRouter,
    VoiceFeedbackSystem? feedbackSystem,
    DatabaseService? databaseService,
  }) : _recognitionEngine = recognitionEngine ?? VoiceRecognitionEngine(),
       _ttsService = ttsService ?? TTSService(),
       _disambiguationService = disambiguationService ?? EntityDisambiguationService(),
       _deleteService = deleteService ?? VoiceDeleteService(),
       _modifyService = modifyService ?? VoiceModifyService(),
       _navigationService = navigationService ?? VoiceNavigationService(),
       _intentRouter = intentRouter ?? VoiceIntentRouter(),
       _feedbackSystem = feedbackSystem ?? VoiceFeedbackSystem(),
       _databaseService = databaseService ?? DatabaseService();

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
      _sessionState = VoiceSessionState.idle;
      notifyListeners();
      return VoiceSessionResult.error('启动语音识别失败: $e');
    }
  }

  /// 处理单次语音命令
  Future<VoiceSessionResult> processVoiceCommand(String voiceInput) async {
    try {
      _sessionState = VoiceSessionState.processing;
      notifyListeners();

      // 记录命令历史
      final command = VoiceCommand(
        input: voiceInput,
        timestamp: DateTime.now(),
      );
      _addToHistory(command);

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

      case VoiceIntentType.unknown:
      default:
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

      final message = '已记录${executedCount}笔交易${navigationMessage != null ? '，$navigationMessage' : ''}';
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
      default:
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
        // No specific cleanup needed for these types
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
      print('VoiceCoordinator: 开始检查重复交易，金额=${transaction.amount}，分类=${transaction.category}');
      final existingTransactions = await _databaseService.getTransactions();
      print('VoiceCoordinator: 获取到${existingTransactions.length}条现有交易');
      final duplicateCheck = DuplicateDetectionService.checkDuplicate(
        transaction,
        existingTransactions,
      );
      print('VoiceCoordinator: 重复检测结果: hasPotentialDuplicate=${duplicateCheck.hasPotentialDuplicate}, score=${duplicateCheck.similarityScore}');

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

      final message = '已记录${category ?? ""}消费${amount.toStringAsFixed(2)}元';
      await _feedbackSystem.provideOperationFeedback(
        result: OperationResult.success('add', {'amount': amount}),
      );
      await _ttsService.speak(message);

      _clearSession();
      notifyListeners();
      return VoiceSessionResult.success(message);
    } catch (e) {
      final message = '添加记录失败: $e';
      await _ttsService.speak('添加记录失败，请重试');
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
      await _ttsService.speak('查询失败，请重试');
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
        final success = await _databaseService.softDeleteTransaction(record.id);
        if (!success) return false;
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

  /// 清除当前会话
  void _clearSession() {
    _currentSession = null;
    _pendingMultiIntent = null;
    _sessionState = VoiceSessionState.idle;
    _deleteService.cancelDelete();
    _modifyService.clearSession();
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
    _recognitionEngine.dispose();
    _ttsService.dispose();
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
  error,                          // 错误状态
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