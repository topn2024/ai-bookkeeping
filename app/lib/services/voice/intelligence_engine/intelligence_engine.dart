import 'dart:async';

import 'package:flutter/foundation.dart';
import 'models.dart';
import 'multi_operation_recognizer.dart';
import 'dual_channel_processor.dart';
import 'intelligent_aggregator.dart';
import 'adaptive_conversation_agent.dart';
import 'result_buffer.dart';
import 'timing_judge.dart';
import '../input_filter.dart';
import '../smart_intent_recognizer.dart' show MultiOperationResult, Operation, OperationPriority;
import '../adapters/bookkeeping_feedback_adapter.dart';
import '../agent/hybrid_intent_router.dart' show NetworkStatus;

/// 智能语音引擎
///
/// 核心架构：
/// - InputFilter: 输入预过滤器（快速分类 <10ms）
/// - MultiOperationRecognizer: 多操作识别
/// - DualChannelProcessor: 双通道处理（执行+对话）
/// - IntelligentAggregator: 智能聚合
/// - AdaptiveConversationAgent: 自适应对话
/// - ResultBuffer: 结果缓冲器
/// - TimingJudge: 时机判断器
class IntelligenceEngine {
  final OperationAdapter operationAdapter;
  final FeedbackAdapter feedbackAdapter;

  late final InputFilter _inputFilter;
  late final MultiOperationRecognizer _recognizer;
  late final DualChannelProcessor _processor;
  late final IntelligentAggregator _aggregator;
  late final AdaptiveConversationAgent _conversationAgent;
  late final ResultBuffer _resultBuffer;
  late final TimingJudge _timingJudge;

  /// 上一条响应（用于 feedback.repeat）
  String? _lastResponse;

  /// 上一轮是否是操作
  bool _lastRoundWasOperation = false;

  /// 是否检测到负面情绪
  bool _isNegativeEmotion = false;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Deferred 操作缓冲机制
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 待处理的 deferred 操作缓冲区
  final List<_PendingOperation> _pendingDeferredOperations = [];

  /// Deferred 操作聚合计时器
  Timer? _deferredTimer;

  /// Deferred 操作等待时间（毫秒）
  /// 延长到 2500ms 以收集连续记账（如"早餐15，午餐20"）
  static const int _deferredWaitMs = 2500;

  /// Deferred 响应回调
  ///
  /// 当 deferred 操作计时器到期时，通过此回调通知外部
  /// 参数：响应文本
  void Function(String response)? onDeferredResponse;

  IntelligenceEngine({
    required this.operationAdapter,
    required this.feedbackAdapter,
  }) {
    _inputFilter = InputFilter();
    _recognizer = MultiOperationRecognizer();
    _processor = DualChannelProcessor(
      executionChannel: ExecutionChannel(adapter: operationAdapter),
      conversationChannel: ConversationChannel(adapter: feedbackAdapter),
    );
    _aggregator = IntelligentAggregator(
      onTrigger: (operations) async {
        // 聚合触发回调
        debugPrint('[IntelligenceEngine] 聚合触发: ${operations.length}个操作');
      },
    );
    _conversationAgent = AdaptiveConversationAgent();
    _resultBuffer = ResultBuffer();
    _timingJudge = TimingJudge();
  }

  /// 获取结果缓冲器（供外部查询待通知结果）
  ResultBuffer get resultBuffer => _resultBuffer;

  /// 获取时机判断器
  TimingJudge get timingJudge => _timingJudge;

  /// 设置网络状态提供者
  ///
  /// 用于SmartIntentRecognizer判断是否使用LLM
  void setNetworkStatusProvider(NetworkStatus? Function()? provider) {
    _recognizer.setNetworkStatusProvider(provider);
    debugPrint('[IntelligenceEngine] 网络状态提供者已${provider != null ? "设置" : "清除"}');
  }

  /// 处理语音输入
  ///
  /// 两层分类架构：
  /// 1. InputFilter（预处理，<10ms，纯规则）：noise/emotion/feedback/processable
  /// 2. SmartIntentRecognizer（LLM+规则）：operation/chat/clarify/failed
  Future<VoiceSessionResult> process(String input) async {
    debugPrint('[IntelligenceEngine] 处理输入: $input');

    try {
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 第一层：InputFilter 预过滤（<10ms）
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      final filterResult = _inputFilter.filter(input);
      debugPrint('[IntelligenceEngine] InputFilter结果: ${filterResult.category}');

      // 处理 noise：静默忽略
      if (filterResult.category == InputCategory.noise) {
        debugPrint('[IntelligenceEngine] 噪音输入，静默忽略');
        return const VoiceSessionResult(
          success: true,
          message: null, // 静默，不返回消息
        );
      }

      // 处理 emotion：返回情感关怀回复
      if (filterResult.category == InputCategory.emotion) {
        _isNegativeEmotion = filterResult.emotionType == EmotionType.negative ||
            filterResult.emotionType == EmotionType.frustration;
        final response = filterResult.suggestedResponse ?? '有什么需要帮忙的吗？';
        debugPrint('[IntelligenceEngine] 情绪输入: ${filterResult.emotionType}, 回复: $response');
        _lastResponse = response;
        return VoiceSessionResult(
          success: true,
          message: response,
        );
      }

      // 处理 feedback：根据反馈类型处理
      if (filterResult.category == InputCategory.feedback) {
        final result = _handleFeedback(filterResult);
        if (result != null) {
          _lastResponse = result.message;
          return result;
        }
        // 如果 feedback 处理返回 null，继续进入意图识别（例如某些确认需要上下文）
      }

      // 重置情绪状态（processable 输入表示用户继续正常对话）
      _isNegativeEmotion = false;

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 第二层：SmartIntentRecognizer 意图识别
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // 1. 多操作识别（5s超时，给LLM足够时间）
      final recognitionResult = await _recognizer.recognize(input).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[IntelligenceEngine] 识别超时，返回失败结果');
          return MultiOperationResult.error('识别超时');
        },
      );

      debugPrint('[IntelligenceEngine] 识别结果: resultType=${recognitionResult.resultType}, '
          'operations=${recognitionResult.operations.length}, '
          'isChat=${recognitionResult.isChat}, '
          'needsClarify=${recognitionResult.needsClarify}, '
          'isOfflineMode=${recognitionResult.isOfflineMode}');

      // 2. 根据结果类型分别处理
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // 2.1 澄清模式：直接返回澄清问题
      if (recognitionResult.needsClarify) {
        final clarifyQuestion = recognitionResult.clarifyQuestion ?? '请问您具体想要做什么呢？';
        debugPrint('[IntelligenceEngine] 澄清模式: $clarifyQuestion');
        return VoiceSessionResult(
          success: true,
          message: clarifyQuestion,
        );
      }

      // 2.2 闲聊模式：生成闲聊回复
      if (recognitionResult.isChat) {
        debugPrint('[IntelligenceEngine] 闲聊模式, isOfflineMode=${recognitionResult.isOfflineMode}');
        _lastRoundWasOperation = false;

        // 如果是离线模式，直接返回友好提示，不调用 FeedbackAdapter
        if (recognitionResult.isOfflineMode) {
          debugPrint('[IntelligenceEngine] 离线模式闲聊，返回友好提示');
          const offlineResponse = '网络不太好，我现在只能帮你记账。有什么需要记录的吗？';
          _lastResponse = offlineResponse;
          return const VoiceSessionResult(
            success: true,
            message: offlineResponse,
          );
        }

        // 将用户输入传递给FeedbackAdapter
        if (feedbackAdapter is BookkeepingFeedbackAdapter) {
          (feedbackAdapter as BookkeepingFeedbackAdapter).setLastUserInput(input);
        }
        final responseText = await _processor.conversationChannel.generateResponse(ConversationMode.chat);
        debugPrint('[IntelligenceEngine] 闲聊回复: $responseText');
        _lastResponse = responseText;
        return VoiceSessionResult(
          success: true,
          message: responseText,
        );
      }

      // 2.3 失败模式：返回错误信息
      if (!recognitionResult.isSuccess) {
        debugPrint('[IntelligenceEngine] 识别失败: ${recognitionResult.errorMessage}');
        return VoiceSessionResult(
          success: false,
          message: recognitionResult.errorMessage ?? '抱歉，我没有理解您的意思',
        );
      }

      // 2.4 操作模式：根据优先级决定响应策略
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      final operations = recognitionResult.operations;
      debugPrint('[IntelligenceEngine] 操作模式: ${operations.length} 个操作');

      // 分类操作：immediate/normal 需要立即响应，deferred/background 可以等待
      final immediateOps = operations.where((op) =>
          op.priority == OperationPriority.immediate ||
          op.priority == OperationPriority.normal).toList();
      final deferredOps = operations.where((op) =>
          op.priority == OperationPriority.deferred ||
          op.priority == OperationPriority.background).toList();

      debugPrint('[IntelligenceEngine] 立即操作: ${immediateOps.length}, 延迟操作: ${deferredOps.length}');

      // 如果有立即操作，立即响应
      if (immediateOps.isNotEmpty) {
        debugPrint('[IntelligenceEngine] 有立即操作，立即响应');

        // 执行所有操作
        _executeOperationsAsync(recognitionResult, input);

        // 生成响应
        final quickAck = _generateQuickAcknowledgment(operations.length);
        _lastRoundWasOperation = true;
        _lastResponse = quickAck;

        return VoiceSessionResult(
          success: true,
          message: quickAck,
        );
      }

      // 只有 deferred 操作：缓存并等待 1.5 秒
      debugPrint('[IntelligenceEngine] 只有延迟操作，缓存并等待${_deferredWaitMs}ms');

      // 缓存操作
      for (final op in deferredOps) {
        _pendingDeferredOperations.add(_PendingOperation(
          operation: op,
          recognitionResult: recognitionResult,
          input: input,
        ));
      }

      // 重置计时器（滑动窗口）
      _deferredTimer?.cancel();
      _deferredTimer = Timer(
        Duration(milliseconds: _deferredWaitMs),
        _processDeferredOperations,
      );

      debugPrint('[IntelligenceEngine] 已缓存${_pendingDeferredOperations.length}个操作，等待更多指令');

      // 更新状态但不响应（返回 null 消息表示暂不播放语音）
      _lastRoundWasOperation = true;

      return const VoiceSessionResult(
        success: true,
        message: null, // 暂不响应，等待更多指令
      );
    } catch (e, stack) {
      debugPrint('[IntelligenceEngine] 处理失败: $e\n$stack');

      return VoiceSessionResult(
        success: false,
        message: '抱歉，处理您的请求时出现了问题',
      );
    }
  }

  /// 处理用户反馈
  ///
  /// 返回 null 表示需要继续进入意图识别
  VoiceSessionResult? _handleFeedback(InputFilterResult filterResult) {
    final feedbackType = filterResult.feedbackType;
    if (feedbackType == null) return null;

    switch (feedbackType) {
      case FeedbackType.confirm:
        // 确认：检查是否有待确认的操作
        // 如果没有待确认操作，返回 null 继续进入意图识别
        // 这里简单返回确认消息，实际可能需要更复杂的逻辑
        debugPrint('[IntelligenceEngine] 用户确认');
        // 暂时返回 null，让系统继续处理（因为单独的"好的"可能是用户的其他意图）
        return null;

      case FeedbackType.cancel:
        // 取消：清除待处理的操作
        debugPrint('[IntelligenceEngine] 用户取消');
        cancelPendingDeferredOperations(); // 取消待处理的 deferred 操作
        _resultBuffer.suppressAll(); // 压制所有待通知结果
        return VoiceSessionResult(
          success: true,
          message: filterResult.suggestedResponse ?? '好的，取消了',
        );

      case FeedbackType.hesitate:
        // 犹豫：等待用户继续
        debugPrint('[IntelligenceEngine] 用户犹豫');
        return VoiceSessionResult(
          success: true,
          message: filterResult.suggestedResponse ?? '好的，想好了告诉我',
        );

      case FeedbackType.repeat:
        // 重复：返回上一条响应
        debugPrint('[IntelligenceEngine] 用户请求重复');
        if (_lastResponse != null) {
          return VoiceSessionResult(
            success: true,
            message: _lastResponse,
          );
        } else {
          return const VoiceSessionResult(
            success: true,
            message: '刚才我还没说什么呢',
          );
        }
    }
  }

  /// 生成简短确认
  ///
  /// 根据操作数量生成不同的确认语：
  /// - 1笔：好的
  /// - 多笔：好的，N笔
  String _generateQuickAcknowledgment(int operationCount) {
    if (operationCount <= 1) {
      return '好的';
    } else {
      return '好的，$operationCount笔';
    }
  }

  /// 异步执行操作
  ///
  /// 在后台执行操作，完成后将结果加入 ResultBuffer
  Future<void> _executeOperationsAsync(
    MultiOperationResult recognitionResult,
    String input,
  ) async {
    debugPrint('[IntelligenceEngine] 开始异步执行${recognitionResult.operations.length}个操作');

    try {
      // 双通道处理
      await _processor.process(recognitionResult);

      // 将用户输入传递给FeedbackAdapter
      if (feedbackAdapter is BookkeepingFeedbackAdapter) {
        (feedbackAdapter as BookkeepingFeedbackAdapter).setLastUserInput(input);
      }

      // 为每个操作创建结果记录
      for (final operation in recognitionResult.operations) {
        // 从 ConversationChannel 获取执行结果
        final results = _processor.conversationChannel.getRecentResults();
        final executionResult = results.isNotEmpty
            ? results.last
            : ExecutionResult.success();

        // 生成操作描述
        final description = _generateOperationDescription(operation);

        // 添加到结果缓冲器
        _resultBuffer.add(
          result: executionResult,
          description: description,
          amount: (operation.params['amount'] as num?)?.toDouble(),
          operationType: operation.type,
        );

        debugPrint('[IntelligenceEngine] 操作执行完成并加入缓冲: $description');
      }
    } catch (e, stack) {
      debugPrint('[IntelligenceEngine] 异步执行失败: $e\n$stack');

      // 即使失败也要记录到缓冲器
      _resultBuffer.add(
        result: ExecutionResult.failure('执行失败: $e'),
        description: '操作执行失败',
      );
    }
  }

  /// 生成操作描述
  String _generateOperationDescription(Operation operation) {
    final params = operation.params;
    final category = params['category'] as String? ?? '';
    final amount = (params['amount'] as num?)?.toDouble();

    if (category.isNotEmpty && amount != null) {
      return '$category${amount.toStringAsFixed(0)}元';
    } else if (category.isNotEmpty) {
      return category;
    } else if (amount != null) {
      return '${amount.toStringAsFixed(0)}元';
    } else {
      return '记账';
    }
  }

  /// 获取时机判断上下文
  TimingContext getTimingContext({
    String? userInput,
    bool isUserSpeaking = false,
    int silenceDurationMs = 0,
  }) {
    final pendingResults = _resultBuffer.pendingResults;
    return TimingContext(
      userInput: userInput,
      isUserSpeaking: isUserSpeaking,
      silenceDurationMs: silenceDurationMs,
      isNegativeEmotion: _isNegativeEmotion,
      isInChat: !_lastRoundWasOperation,
      lastRoundWasOperation: _lastRoundWasOperation,
      pendingResultCount: pendingResults.length,
      highestPriority: pendingResults.isNotEmpty ? pendingResults.first.priority : null,
    );
  }

  /// 释放资源
  void dispose() {
    _deferredTimer?.cancel();
    _deferredTimer = null;
    _pendingDeferredOperations.clear();
    _resultBuffer.dispose();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Deferred 操作处理
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 处理缓存的 deferred 操作
  ///
  /// 计时器到期时调用，统一处理所有缓存的操作
  Future<void> _processDeferredOperations() async {
    if (_pendingDeferredOperations.isEmpty) {
      debugPrint('[IntelligenceEngine] 无待处理的延迟操作');
      return;
    }

    final operationCount = _pendingDeferredOperations.length;
    debugPrint('[IntelligenceEngine] 处理${operationCount}个延迟操作');

    // 生成统一响应
    final quickAck = _generateQuickAcknowledgment(operationCount);
    _lastResponse = quickAck;

    // 执行所有缓存的操作
    for (final pending in _pendingDeferredOperations) {
      try {
        await _processor.process(pending.recognitionResult);

        // 将用户输入传递给FeedbackAdapter
        if (feedbackAdapter is BookkeepingFeedbackAdapter) {
          (feedbackAdapter as BookkeepingFeedbackAdapter).setLastUserInput(pending.input);
        }

        // 生成操作描述并加入缓冲
        final description = _generateOperationDescription(pending.operation);
        final results = _processor.conversationChannel.getRecentResults();
        final executionResult = results.isNotEmpty
            ? results.last
            : ExecutionResult.success();

        _resultBuffer.add(
          result: executionResult,
          description: description,
          amount: (pending.operation.params['amount'] as num?)?.toDouble(),
          operationType: pending.operation.type,
        );

        debugPrint('[IntelligenceEngine] 延迟操作执行完成: $description');
      } catch (e) {
        debugPrint('[IntelligenceEngine] 延迟操作执行失败: $e');
        _resultBuffer.add(
          result: ExecutionResult.failure('执行失败: $e'),
          description: '操作执行失败',
        );
      }
    }

    // 清空缓冲区
    _pendingDeferredOperations.clear();

    // 通过回调通知外部
    debugPrint('[IntelligenceEngine] 延迟操作处理完成，通知外部: $quickAck');
    onDeferredResponse?.call(quickAck);
  }

  /// 取消待处理的 deferred 操作
  ///
  /// 当用户说"取消"时调用
  void cancelPendingDeferredOperations() {
    _deferredTimer?.cancel();
    _deferredTimer = null;
    final count = _pendingDeferredOperations.length;
    _pendingDeferredOperations.clear();
    debugPrint('[IntelligenceEngine] 取消了${count}个待处理的延迟操作');
  }

  /// 是否有待处理的 deferred 操作
  bool get hasPendingDeferredOperations => _pendingDeferredOperations.isNotEmpty;

  /// 待处理的 deferred 操作数量
  int get pendingDeferredOperationCount => _pendingDeferredOperations.length;
}

/// 待处理的操作
class _PendingOperation {
  final Operation operation;
  final MultiOperationResult recognitionResult;
  final String input;

  _PendingOperation({
    required this.operation,
    required this.recognitionResult,
    required this.input,
  });
}

/// 操作适配器接口
abstract class OperationAdapter {
  /// 执行操作
  Future<ExecutionResult> execute(Operation operation);

  /// 是否支持该操作类型
  bool canHandle(OperationType type);

  /// 适配器名称
  String get adapterName;
}

/// 反馈适配器接口
abstract class FeedbackAdapter {
  /// 生成反馈
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  );

  /// 是否支持该对话模式
  bool supportsMode(ConversationMode mode);

  /// 适配器名称
  String get adapterName;
}

/// 对话模式
enum ConversationMode {
  chat,              // 闲聊：默认1-2句，用户要求时可展开（讲故事等）
  chatWithIntent,    // 有诉求的闲聊：详细回答
  quickBookkeeping,  // 快速记账：极简"✓ 2笔"
  mixed,             // 混合：简短确认+操作反馈
  clarify,           // 澄清：反问用户获取更多信息
}

/// 语音会话结果（临时占位，后续会完善）
class VoiceSessionResult {
  final bool success;
  final String? message;

  const VoiceSessionResult({
    required this.success,
    this.message,
  });
}
