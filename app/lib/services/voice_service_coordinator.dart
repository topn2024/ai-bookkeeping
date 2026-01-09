import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/transaction.dart' as model;
import '../services/database_service.dart';
import '../services/database_voice_extension.dart';
import 'voice/entity_disambiguation_service.dart';
import 'voice/voice_delete_service.dart';
import 'voice/voice_modify_service.dart';
import 'voice/voice_intent_router.dart';
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
    // TODO: 实现语音添加交易功能
    const message = '语音添加交易功能正在开发中';
    await _ttsService.speak(message);
    return VoiceSessionResult.success(message);
  }

  /// 处理查询意图
  Future<VoiceSessionResult> _handleQueryIntent(
    IntentAnalysisResult intentResult,
    String originalInput,
  ) async {
    // TODO: 实现语音查询功能
    const message = '语音查询功能正在开发中';
    await _ttsService.speak(message);
    return VoiceSessionResult.success(message);
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
    return VoiceSessionResult.success(message);
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
        type: TransactionType.values.firstWhere((e) => e.name == record.type, orElse: () => TransactionType.expense),
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
  idle,                      // 空闲
  listening,                 // 正在听取
  processing,                // 正在处理
  waitingForConfirmation,    // 等待确认
  waitingForClarification,   // 等待澄清
  error,                     // 错误状态
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