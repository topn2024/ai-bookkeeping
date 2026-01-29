/// Voice Service Orchestrator
///
/// 新的语音服务协调器，作为编排器协调各子协调器。
/// 遵循单一职责原则，仅负责编排，不包含具体业务逻辑。
///
/// 目标：<300行
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../models/transaction.dart' show TransactionType;
import 'voice_recognition_coordinator.dart';
import 'intent_processing_coordinator.dart';
import 'transaction_operation_coordinator.dart';
import 'navigation_coordinator.dart';
import 'conversation_coordinator.dart';
import 'feedback_coordinator.dart';

/// 语音会话状态
enum VoiceSessionState {
  idle,
  listening,
  processing,
  waitingForConfirmation,
  waitingForClarification,
  waitingForMultiIntentConfirmation,
  waitingForAmountSupplement,
  automationRunning,
  error,
  recovering,
}

/// 语音会话状态类型
enum VoiceSessionStatus {
  success,
  error,
  partial,
  waitingForConfirmation,
  waitingForClarification,
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

  factory VoiceSessionResult.waitingForConfirmation(String message, dynamic data) {
    return VoiceSessionResult(
      status: VoiceSessionStatus.waitingForConfirmation,
      message: message,
      data: data,
    );
  }

  bool get isSuccess => status == VoiceSessionStatus.success;
  bool get isError => status == VoiceSessionStatus.error;
}

/// 语音服务编排器
///
/// 职责：
/// - 协调各子协调器
/// - 管理会话状态
/// - 路由请求到正确的协调器
/// - 处理跨协调器的交互
class VoiceServiceOrchestrator extends ChangeNotifier {
  final VoiceRecognitionCoordinator _recognitionCoordinator;
  final IntentProcessingCoordinator _intentCoordinator;
  final TransactionOperationCoordinator _transactionCoordinator;
  final NavigationCoordinator _navigationCoordinator;
  final ConversationCoordinator _conversationCoordinator;
  final FeedbackCoordinator _feedbackCoordinator;

  /// 当前会话状态
  VoiceSessionState _sessionState = VoiceSessionState.idle;

  /// 会话超时计时器
  Timer? _sessionTimeoutTimer;

  /// 会话超时时间
  static const Duration _sessionTimeout = Duration(minutes: 30);

  VoiceServiceOrchestrator({
    required VoiceRecognitionCoordinator recognitionCoordinator,
    required IntentProcessingCoordinator intentCoordinator,
    required TransactionOperationCoordinator transactionCoordinator,
    required NavigationCoordinator navigationCoordinator,
    required ConversationCoordinator conversationCoordinator,
    required FeedbackCoordinator feedbackCoordinator,
  })  : _recognitionCoordinator = recognitionCoordinator,
        _intentCoordinator = intentCoordinator,
        _transactionCoordinator = transactionCoordinator,
        _navigationCoordinator = navigationCoordinator,
        _conversationCoordinator = conversationCoordinator,
        _feedbackCoordinator = feedbackCoordinator;

  /// 当前会话状态
  VoiceSessionState get sessionState => _sessionState;

  /// 是否有活跃会话
  bool get hasActiveSession => _sessionState != VoiceSessionState.idle;

  /// 是否正在等待用户输入
  bool get isWaitingForInput => _conversationCoordinator.isAwaitingInput;

  // ==================== 主要入口方法 ====================

  /// 处理语音命令
  ///
  /// 主入口方法，协调整个处理流程：
  /// 1. 意图识别
  /// 2. 路由到对应协调器
  /// 3. 执行操作
  /// 4. 提供反馈
  Future<VoiceSessionResult> processVoiceCommand(String voiceInput) async {
    if (voiceInput.trim().isEmpty) {
      return VoiceSessionResult.error('输入为空');
    }

    debugPrint('[VoiceServiceOrchestrator] 处理语音命令: "$voiceInput"');
    _updateState(VoiceSessionState.processing);
    _resetSessionTimeout();

    try {
      // 1. 添加到对话历史
      _conversationCoordinator.addUserInput(voiceInput);

      // 2. 检查是否在等待补充信息
      if (_conversationCoordinator.isAwaitingInput) {
        return await _handlePendingInput(voiceInput);
      }

      // 3. 处理意图
      final intentResult = await _intentCoordinator.process(voiceInput);

      if (!intentResult.success || intentResult.intent == null) {
        final errorMsg = intentResult.errorMessage ?? '无法理解您的意图';
        await _feedbackCoordinator.provideErrorFeedback(errorMsg);
        _updateState(VoiceSessionState.idle);
        return VoiceSessionResult.error(errorMsg);
      }

      // 4. 路由到对应协调器
      final result = await _routeToCoordinator(intentResult.intent!);

      // 5. 提供反馈
      if (result.isSuccess) {
        await _feedbackCoordinator.provideSuccessFeedback(result.message ?? '操作成功');
        _conversationCoordinator.addAssistantResponse(result.message ?? '操作成功');
      } else if (result.isError) {
        await _feedbackCoordinator.provideErrorFeedback(result.errorMessage ?? '操作失败');
      }

      _updateState(VoiceSessionState.idle);
      return result;
    } catch (e) {
      debugPrint('[VoiceServiceOrchestrator] 处理失败: $e');
      _updateState(VoiceSessionState.error);
      final errorMsg = '处理语音命令失败: $e';
      await _feedbackCoordinator.provideErrorFeedback(errorMsg);
      return VoiceSessionResult.error(errorMsg);
    }
  }

  /// 处理音频流（流式识别）
  Stream<VoiceSessionResult> processAudioStream(Stream<Uint8List> audioStream) async* {
    _updateState(VoiceSessionState.listening);
    _resetSessionTimeout();

    try {
      await for (final result in _recognitionCoordinator.recognizeStream(audioStream)) {
        if (result.isPartial) {
          yield VoiceSessionResult.partial(result.text);
        } else {
          // 最终结果，进行意图处理
          final voiceResult = await processVoiceCommand(result.text);
          yield voiceResult;
        }
      }
    } catch (e) {
      _updateState(VoiceSessionState.error);
      yield VoiceSessionResult.error('音频流处理失败: $e');
    }
  }

  /// 启动语音会话
  Future<VoiceSessionResult> startVoiceSession() async {
    try {
      _updateState(VoiceSessionState.listening);
      _conversationCoordinator.startSession();
      await _recognitionCoordinator.startSession();
      _resetSessionTimeout();

      debugPrint('[VoiceServiceOrchestrator] 语音会话已启动');
      return VoiceSessionResult.success('语音识别已启动');
    } catch (e) {
      _updateState(VoiceSessionState.idle);
      return VoiceSessionResult.error('启动语音识别失败: $e');
    }
  }

  /// 结束语音会话
  Future<void> endVoiceSession() async {
    debugPrint('[VoiceServiceOrchestrator] 结束语音会话');
    _sessionTimeoutTimer?.cancel();
    await _recognitionCoordinator.endSession();
    _conversationCoordinator.endSession();
    _updateState(VoiceSessionState.idle);
  }

  // ==================== 路由方法 ====================

  /// 路由到对应的协调器
  Future<VoiceSessionResult> _routeToCoordinator(ProcessedIntent intent) async {
    debugPrint('[VoiceServiceOrchestrator] 路由意图: ${intent.type}');

    switch (intent.type) {
      case IntentType.addTransaction:
        return await _handleAddTransaction(intent);

      case IntentType.deleteTransaction:
      case IntentType.modifyTransaction:
        return await _handleTransactionOperation(intent);

      case IntentType.navigation:
        return await _handleNavigation(intent);

      case IntentType.chat:
      case IntentType.greeting:
      case IntentType.farewell:
        return await _handleConversation(intent);

      case IntentType.queryStatistics:
      case IntentType.queryBudget:
      case IntentType.queryAccount:
      case IntentType.queryTransaction:
        return await _handleQuery(intent);

      default:
        return VoiceSessionResult.error('暂不支持此操作');
    }
  }

  /// 处理添加交易
  Future<VoiceSessionResult> _handleAddTransaction(ProcessedIntent intent) async {
    // 检查意图是否完整
    if (!_intentCoordinator.isIntentComplete(intent)) {
      final missing = _intentCoordinator.getMissingEntities(intent);
      return _requestMissingInfo(intent, missing);
    }

    final params = CreateTransactionParams(
      type: _parseTransactionType(intent.getEntity('type')),
      amount: intent.getEntity<double>('amount') ?? 0,
      category: intent.getEntity<String>('category') ?? '其他',
      subcategory: intent.getEntity<String>('subcategory'),
      note: intent.getEntity<String>('note'),
      accountId: intent.getEntity<String>('accountId') ?? 'default',
    );

    final result = await _transactionCoordinator.createTransaction(params);

    if (result.success) {
      return VoiceSessionResult.success(result.message, result.transaction);
    } else {
      return VoiceSessionResult.error(result.message);
    }
  }

  /// 处理交易操作（删除/修改）
  Future<VoiceSessionResult> _handleTransactionOperation(ProcessedIntent intent) async {
    final transactionId = intent.getEntity<String>('transactionId');
    if (transactionId == null) {
      return VoiceSessionResult.error('请指定要操作的交易');
    }

    if (intent.type == IntentType.deleteTransaction) {
      final result = await _transactionCoordinator.deleteTransaction(transactionId);
      return result.success
          ? VoiceSessionResult.success(result.message)
          : VoiceSessionResult.error(result.message);
    }

    // 修改交易暂时返回待实现
    return VoiceSessionResult.error('修改功能开发中');
  }

  /// 处理导航
  Future<VoiceSessionResult> _handleNavigation(ProcessedIntent intent) async {
    final target = intent.getEntity<String>('target');
    if (target == null) {
      final navResult = _navigationCoordinator.parseNavigationIntent(
        intent.originalText,
      );
      if (navResult.success) {
        return VoiceSessionResult.success(navResult.message);
      }
      return VoiceSessionResult.error('无法识别导航目标');
    }

    final result = await _navigationCoordinator.navigate(target);
    return result.success
        ? VoiceSessionResult.success(result.message)
        : VoiceSessionResult.error(result.message);
  }

  /// 处理对话
  Future<VoiceSessionResult> _handleConversation(ProcessedIntent intent) async {
    _conversationCoordinator.enterChatMode();

    // 简单响应
    String response;
    switch (intent.type) {
      case IntentType.greeting:
        response = '你好！有什么可以帮您的吗？';
        break;
      case IntentType.farewell:
        response = '再见，祝您生活愉快！';
        _conversationCoordinator.exitChatMode();
        break;
      default:
        response = '我在听，请继续说。';
    }

    _conversationCoordinator.addAssistantResponse(response);
    return VoiceSessionResult.success(response);
  }

  /// 处理查询
  Future<VoiceSessionResult> _handleQuery(ProcessedIntent intent) async {
    // 查询功能待实现
    return VoiceSessionResult.success('查询功能开发中');
  }

  // ==================== 辅助方法 ====================

  /// 处理待补充的输入
  Future<VoiceSessionResult> _handlePendingInput(String input) async {
    final pending = _conversationCoordinator.pendingIntent;
    if (pending == null) {
      _conversationCoordinator.clearPendingIntent();
      return await processVoiceCommand(input);
    }

    // 根据等待的信息类型处理
    // TODO: 实现金额/分类补充逻辑
    _conversationCoordinator.clearPendingIntent();
    return VoiceSessionResult.success('已收到补充信息');
  }

  /// 请求缺失信息
  VoiceSessionResult _requestMissingInfo(
    ProcessedIntent intent,
    List<String> missing,
  ) {
    String prompt;
    ConversationMode mode;

    if (missing.contains('amount')) {
      prompt = '请问金额是多少？';
      mode = ConversationMode.awaitingAmount;
    } else if (missing.contains('category')) {
      prompt = '请问是什么分类？';
      mode = ConversationMode.awaitingCategory;
    } else {
      prompt = '请提供更多信息';
      mode = ConversationMode.awaitingConfirmation;
    }

    final incomplete = IncompleteIntent(
      intentType: intent.type.name,
      partialEntities: intent.entities,
      missingFields: missing,
      createdAt: DateTime.now(),
      promptMessage: prompt,
    );

    switch (mode) {
      case ConversationMode.awaitingAmount:
        _conversationCoordinator.setAwaitingAmount(incomplete);
        _updateState(VoiceSessionState.waitingForAmountSupplement);
        break;
      case ConversationMode.awaitingCategory:
        _conversationCoordinator.setAwaitingCategory(incomplete);
        _updateState(VoiceSessionState.waitingForClarification);
        break;
      default:
        _conversationCoordinator.setAwaitingConfirmation(incomplete);
        _updateState(VoiceSessionState.waitingForConfirmation);
    }

    return VoiceSessionResult.waitingForConfirmation(prompt, incomplete);
  }

  /// 解析交易类型
  TransactionType _parseTransactionType(dynamic type) {
    if (type is TransactionType) return type;
    if (type is String) {
      switch (type.toLowerCase()) {
        case 'income':
          return TransactionType.income;
        case 'transfer':
          return TransactionType.transfer;
        default:
          return TransactionType.expense;
      }
    }
    return TransactionType.expense;
  }

  /// 更新状态
  void _updateState(VoiceSessionState newState) {
    if (_sessionState != newState) {
      _sessionState = newState;
      notifyListeners();
    }
  }

  /// 重置会话超时
  void _resetSessionTimeout() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = Timer(_sessionTimeout, () {
      debugPrint('[VoiceServiceOrchestrator] 会话超时');
      endVoiceSession();
    });
  }

  @override
  void dispose() {
    _sessionTimeoutTimer?.cancel();
    super.dispose();
  }
}
