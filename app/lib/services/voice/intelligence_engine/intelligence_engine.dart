import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'models.dart';
import 'multi_operation_recognizer.dart';
import 'dual_channel_processor.dart';
import 'result_buffer.dart';
import 'timing_judge.dart';
import '../input_filter.dart';
import '../smart_intent_recognizer.dart' show MultiOperationResult, Operation, OperationPriority, OperationType, RecognitionSource;
import '../adapters/bookkeeping_feedback_adapter.dart';
import '../agent/hybrid_intent_router.dart' show NetworkStatus;

/// 智能语音引擎
///
/// 核心架构：
/// - InputFilter: 输入预过滤器（快速分类 <10ms）
/// - MultiOperationRecognizer: 多操作识别
/// - DualChannelProcessor: 双通道处理（执行+对话）
/// - ResultBuffer: 结果缓冲器
/// - TimingJudge: 时机判断器
class IntelligenceEngine {
  final OperationAdapter operationAdapter;
  final FeedbackAdapter feedbackAdapter;

  late final InputFilter _inputFilter;
  late final MultiOperationRecognizer _recognizer;
  late final DualChannelProcessor _processor;
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

  /// 是否已释放（防止计时器回调在 dispose 后执行）
  bool _isDisposed = false;

  /// 是否正在处理 deferred 操作（防止并发执行）
  bool _isProcessingDeferred = false;

  /// 待处理的 deferred 操作缓冲区
  final List<_PendingOperation> _pendingDeferredOperations = [];

  /// Deferred 操作聚合计时器（滑动窗口）
  Timer? _deferredTimer;

  /// Deferred 操作最大等待计时器（防止无限滑动）
  Timer? _maxDeferredTimer;

  /// Deferred 操作首次缓存时间
  DateTime? _deferredStartTime;

  /// Deferred 操作等待时间（毫秒）
  /// 延长到 2500ms 以收集连续记账（如"早餐15，午餐20"）
  static const int _deferredWaitMs = 2500;

  /// Deferred 操作最大等待时间（毫秒）
  /// 即使用户持续输入，也会在此时间后强制执行
  static const int _maxDeferredWaitMs = 10000;

  /// 网络重试配置
  static const int _maxRetries = 3;
  static const int _initialRetryDelayMs = 100;
  static const int _recognitionTimeoutSeconds = 5;

  /// Deferred 响应回调
  ///
  /// 当 deferred 操作计时器到期时，通过此回调通知外部
  /// 参数：响应文本
  void Function(String response)? onDeferredResponse;

  /// 导航操作回调
  ///
  /// 当导航操作执行成功时，通过此回调通知外部执行实际导航
  /// 参数：ExecutionResult（包含 route 和 navigationParams）
  Future<void> Function(ExecutionResult result)? _navigationCallback;

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
    _resultBuffer = ResultBuffer();
    _timingJudge = TimingJudge();

    // 注册执行结果回调，监听导航操作
    _processor.executionChannel.registerCallback(_handleExecutionResult);
  }

  /// 处理执行结果
  ///
  /// 检查是否为导航操作，如果是则调用导航回调
  void _handleExecutionResult(ExecutionResult result) {
    if (result.success && result.data != null) {
      final data = result.data!;
      // 检查是否为导航操作（包含 route 字段）
      if (data.containsKey('route') && _navigationCallback != null) {
        debugPrint('[IntelligenceEngine] 检测到导航操作，触发回调');
        _navigationCallback!(result);
      }
    }
  }

  /// 注册导航操作回调
  ///
  /// 当导航操作执行成功时，会调用此回调
  void registerNavigationCallback(Future<void> Function(ExecutionResult result) callback) {
    _navigationCallback = callback;
    debugPrint('[IntelligenceEngine] 导航回调已注册');
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
    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('[IntelligenceEngine] 已释放，忽略输入（长度: ${input.length}）');
      return const VoiceSessionResult(
        success: false,
        message: null,
      );
    }

    // 注意：不在日志中打印完整输入，避免泄露用户隐私（金额、交易对方等）
    debugPrint('[IntelligenceEngine] 处理输入，长度: ${input.length}');

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
      // 第二层：SmartIntentRecognizer 意图识别（带重试机制）
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      // 1. 多操作识别（带重试机制）
      final recognitionResult = await _recognizeWithRetry(input);

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
        debugPrint('[IntelligenceEngine] ===== 开始为查询操作生成operationId =====');
        debugPrint('[IntelligenceEngine] recognitionResult.operations.length=${recognitionResult.operations.length}');

        // 为查询操作生成 operationId（在执行前）
        final enhancedOperations = recognitionResult.operations.map((op) {
          debugPrint('[IntelligenceEngine] 处理操作: type=${op.type}, isQuery=${op.type == OperationType.query}');
          if (op.type == OperationType.query) {
            final operationId = 'query_${DateTime.now().millisecondsSinceEpoch}_${op.hashCode}';
            debugPrint('[IntelligenceEngine] [立即模式] 生成查询operationId: $operationId');
            return Operation(
              type: op.type,
              priority: op.priority,
              params: {
                ...op.params,
                'operationId': operationId,
              },
              originalText: op.originalText,
            );
          }
          debugPrint('[IntelligenceEngine] 非查询操作，跳过');
          return op;
        }).toList();

        debugPrint('[IntelligenceEngine] enhancedOperations.length=${enhancedOperations.length}');

        // 创建增强后的 recognitionResult
        final enhancedRecognitionResult = MultiOperationResult(
          resultType: recognitionResult.resultType,
          operations: enhancedOperations,
          chatContent: recognitionResult.chatContent,
          confidence: recognitionResult.confidence,
          source: recognitionResult.source,
          originalInput: recognitionResult.originalInput,
          isOfflineMode: recognitionResult.isOfflineMode,
        );

        // 执行所有操作
        _executeOperationsAsync(enhancedRecognitionResult, input);

        // 生成响应
        final quickAck = _generateQuickAcknowledgment(operations.length);
        _lastRoundWasOperation = true;
        _lastResponse = quickAck;

        // 提取第一个查询操作的 operationId（如果有）
        String? operationId;
        for (final op in enhancedOperations) {
          if (op.type == OperationType.query) {
            operationId = op.params['operationId'] as String?;
            break;
          }
        }

        return VoiceSessionResult(
          success: true,
          message: quickAck,
          data: operationId != null ? {'operationId': operationId} : null,
        );
      }

      // 只有 deferred 操作：缓存并等待
      debugPrint('[IntelligenceEngine] 只有延迟操作，缓存并等待${_deferredWaitMs}ms');

      // 再次检查是否已释放（防止在异步处理期间被 dispose）
      if (_isDisposed) {
        debugPrint('[IntelligenceEngine] 已释放，跳过延迟操作缓存');
        return const VoiceSessionResult(success: false, message: null);
      }

      // 记录首次缓存时间（用于最大等待时间计算）
      _deferredStartTime ??= DateTime.now();

      // 缓存操作
      for (final op in deferredOps) {
        _pendingDeferredOperations.add(_PendingOperation(
          operation: op,
          recognitionResult: recognitionResult,
          input: input,
        ));
      }

      // 滑动窗口计时器（每次新输入重置）
      // 注意：在创建计时器前检查 disposed，避免 dispose 后仍创建计时器
      _deferredTimer?.cancel();
      if (!_isDisposed) {
        _deferredTimer = Timer(
          Duration(milliseconds: _deferredWaitMs),
          () => _safeTriggerDeferredProcessing('滑动窗口计时器'),
        );
      }

      // 最大等待计时器（只在首次创建，不重置）
      // 确保即使用户持续输入，也会在最大等待时间后强制执行
      if (_maxDeferredTimer == null && !_isDisposed) {
        _maxDeferredTimer = Timer(
          Duration(milliseconds: _maxDeferredWaitMs),
          () => _safeTriggerDeferredProcessing('最大等待计时器'),
        );
      }

      final elapsed = DateTime.now().difference(_deferredStartTime!).inMilliseconds;
      debugPrint('[IntelligenceEngine] 已缓存${_pendingDeferredOperations.length}个操作，已等待${elapsed}ms，等待更多指令');

      // 更新状态但不响应（返回 null 消息表示暂不播放语音）
      _lastRoundWasOperation = true;

      return const VoiceSessionResult(
        success: true,
        message: null, // 暂不响应，等待更多指令
      );
    } catch (e, stack) {
      debugPrint('[IntelligenceEngine] 处理失败: $e\n$stack');

      // 根据错误类型返回更具体的用户友好消息
      String userMessage;
      if (e is TimeoutException) {
        userMessage = '网络响应太慢，请稍后重试';
      } else if (e is SocketException) {
        userMessage = '网络连接失败，请检查网络后重试';
      } else {
        userMessage = '抱歉，处理您的请求时出现了问题';
      }

      return VoiceSessionResult(
        success: false,
        message: userMessage,
      );
    }
  }

  /// 带重试机制的识别方法
  ///
  /// 使用指数退避策略，最多重试 [_maxRetries] 次
  /// 只对网络相关错误进行重试，业务错误直接返回
  Future<MultiOperationResult> _recognizeWithRetry(String input) async {
    int attempt = 0;
    int delayMs = _initialRetryDelayMs;
    Object? lastError;

    while (attempt < _maxRetries) {
      try {
        final result = await _recognizer.recognize(input).timeout(
          const Duration(seconds: _recognitionTimeoutSeconds),
        );
        return result;
      } on TimeoutException {
        attempt++;
        lastError = TimeoutException('识别超时');
        debugPrint('[IntelligenceEngine] 识别超时，重试 $attempt/$_maxRetries');

        if (attempt >= _maxRetries) {
          debugPrint('[IntelligenceEngine] 重试次数耗尽，降级到本地处理');
          return _fallbackToLocalRecognition(input);
        }

        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2; // 指数退避
      } on SocketException catch (e) {
        // 网络错误，重试
        attempt++;
        lastError = e;
        debugPrint('[IntelligenceEngine] 网络错误: $e，重试 $attempt/$_maxRetries');

        if (attempt >= _maxRetries) {
          debugPrint('[IntelligenceEngine] 网络重试耗尽，降级到本地处理');
          return _fallbackToLocalRecognition(input);
        }

        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2;
      } catch (e, stackTrace) {
        // 其他错误（可能是业务错误），不重试
        debugPrint('[IntelligenceEngine] 识别错误（不重试）: $e');
        debugPrint('[IntelligenceEngine] 堆栈: $stackTrace');
        // 不暴露内部错误详情给用户
        return MultiOperationResult.error('处理请求时遇到问题，请重试');
      }
    }

    // 理论上不会到达这里，但为了类型安全
    debugPrint('[IntelligenceEngine] 重试循环异常退出，最后错误: $lastError');
    return _fallbackToLocalRecognition(input);
  }

  /// 降级到本地规则识别
  ///
  /// 当网络识别失败时，使用本地规则进行基本识别
  MultiOperationResult _fallbackToLocalRecognition(String input) {
    debugPrint('[IntelligenceEngine] 使用本地降级识别: $input');

    // 尝试使用简单的正则提取金额
    final amountPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(?:元|块|块钱)?');
    final match = amountPattern.firstMatch(input);

    if (match != null) {
      final amountStr = match.group(1);
      final amount = double.tryParse(amountStr ?? '');

      if (amount != null && amount > 0) {
        debugPrint('[IntelligenceEngine] 本地识别到金额: $amount');

        // 创建一个基本的记账操作
        final operation = Operation(
          type: OperationType.addTransaction,
          priority: OperationPriority.deferred,
          params: {
            'amount': amount,
            'note': input,
            'isOfflineRecognition': true,
          },
          originalText: input,
        );

        return MultiOperationResult(
          resultType: RecognitionResultType.operation,
          operations: [operation],
          chatContent: null,
          confidence: 0.6, // 本地降级识别置信度较低
          source: RecognitionSource.exactRule,
          originalInput: input,
          isOfflineMode: true,
        );
      }
    }

    // 无法识别，返回需要澄清的结果
    return MultiOperationResult(
      resultType: RecognitionResultType.clarify,
      operations: [],
      chatContent: null,
      confidence: 0.3,
      source: RecognitionSource.error,
      originalInput: input,
      clarifyQuestion: '网络不太好，没听清楚。能再说一遍吗？',
      isOfflineMode: true,
    );
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
  /// 返回操作执行报告，便于外部获取详细的执行状态
  Future<OperationExecutionReport> _executeOperationsAsync(
    MultiOperationResult recognitionResult,
    String input,
  ) async {
    debugPrint('[IntelligenceEngine] 开始异步执行${recognitionResult.operations.length}个操作');

    final reportItems = <OperationResultItem>[];

    // 将用户输入传递给FeedbackAdapter
    if (feedbackAdapter is BookkeepingFeedbackAdapter) {
      (feedbackAdapter as BookkeepingFeedbackAdapter).setLastUserInput(input);
    }

    debugPrint('[IntelligenceEngine] ===== 准备进入for循环，operations.length=${recognitionResult.operations.length} =====');

    // 逐个执行操作，记录每个操作的结果
    for (int i = 0; i < recognitionResult.operations.length; i++) {
      final operation = recognitionResult.operations[i];
      final description = _generateOperationDescription(operation);
      final amount = _safeParseAmount(operation.params['amount']);

      debugPrint('[IntelligenceEngine] 处理操作 $i: type=${operation.type}, priority=${operation.priority}');

      try {
        // 如果是查询操作，确保有operationId（如果已存在则使用现有的，否则生成新的）
        final Operation enhancedOperation;
        debugPrint('[IntelligenceEngine] 检查是否为查询操作: ${operation.type} == ${OperationType.query} ? ${operation.type == OperationType.query}');
        if (operation.type == OperationType.query) {
          // 检查是否已有operationId（在立即执行路径中已生成）
          final existingOperationId = operation.params['operationId'] as String?;
          if (existingOperationId != null) {
            debugPrint('[IntelligenceEngine] 使用已有的查询operationId: $existingOperationId');
            enhancedOperation = operation;
          } else {
            // 如果没有，生成新的（兜底逻辑）
            final operationId = 'query_${DateTime.now().millisecondsSinceEpoch}_${operation.hashCode}';
            enhancedOperation = Operation(
              type: operation.type,
              priority: operation.priority,
              params: {
                ...operation.params,
                'operationId': operationId,
              },
              originalText: operation.originalText,
            );
            debugPrint('[IntelligenceEngine] 生成新的查询operationId: $operationId');
          }
        } else {
          enhancedOperation = operation;
        }

        // 创建单操作的 MultiOperationResult 进行处理
        final singleOpResult = MultiOperationResult(
          resultType: recognitionResult.resultType,
          operations: [enhancedOperation],
          chatContent: i == 0 ? recognitionResult.chatContent : null,
          confidence: recognitionResult.confidence,
          source: recognitionResult.source,
          originalInput: recognitionResult.originalInput,
          isOfflineMode: recognitionResult.isOfflineMode,
        );

        // 双通道处理
        await _processor.process(singleOpResult);

        // 从 ConversationChannel 获取执行结果
        final results = _processor.conversationChannel.getRecentResults();
        final ExecutionResult executionResult;
        if (results.isNotEmpty) {
          executionResult = results.last;
        } else {
          // 未获取到结果时，不应假设成功，而应标记为未知状态
          debugPrint('[IntelligenceEngine] 警告: 操作 $i 执行后未获取到结果，标记为失败');
          executionResult = ExecutionResult.failure('未获取到执行结果');
        }

        // 记录到报告
        reportItems.add(OperationResultItem(
          index: i,
          description: description,
          isSuccess: executionResult.success,
          errorMessage: executionResult.error,
          amount: amount,
          operationType: operation.type,
        ));

        // 添加到结果缓冲器
        _resultBuffer.add(
          result: executionResult,
          description: description,
          amount: amount,
          operationType: operation.type,
        );

        debugPrint('[IntelligenceEngine] 操作 $i 执行${executionResult.success ? "成功" : "失败"}: $description');
      } catch (e, stack) {
        debugPrint('[IntelligenceEngine] 操作 $i 执行异常: $e');
        debugPrint('[IntelligenceEngine] 堆栈: $stack');

        // 记录失败到报告
        reportItems.add(OperationResultItem(
          index: i,
          description: description,
          isSuccess: false,
          errorMessage: e.toString(),
          amount: amount,
          operationType: operation.type,
        ));

        // 添加失败记录到缓冲器（不暴露内部错误给用户）
        _resultBuffer.add(
          result: ExecutionResult.failure('操作执行失败'),
          description: description,
          amount: amount,
          operationType: operation.type,
        );
      }
    }

    final report = OperationExecutionReport(reportItems);
    debugPrint('[IntelligenceEngine] 执行报告: $report');

    return report;
  }

  /// 安全地解析金额
  ///
  /// 处理各种类型的输入：num、String、null等
  /// 返回有效的有限正数金额，过滤 infinity、NaN 和负数
  double? _safeParseAmount(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      final doubleValue = value.toDouble();
      // 过滤 infinity、NaN 和非正数
      if (!doubleValue.isFinite || doubleValue <= 0) {
        debugPrint('[IntelligenceEngine] 金额无效（非有限正数）: $value');
        return null;
      }
      return doubleValue;
    }

    if (value is String) {
      // 尝试解析字符串
      double? parsed = double.tryParse(value);
      if (parsed == null) {
        // 尝试移除常见的货币符号后解析
        final cleaned = value.replaceAll(RegExp(r'[¥￥$元块]'), '').trim();
        parsed = double.tryParse(cleaned);
      }
      // 过滤 infinity、NaN 和非正数
      if (parsed != null && parsed.isFinite && parsed > 0) {
        return parsed;
      }
      if (parsed != null) {
        debugPrint('[IntelligenceEngine] 金额无效（非有限正数）: $value -> $parsed');
      }
      return null;
    }

    debugPrint('[IntelligenceEngine] 无法解析金额，类型: ${value.runtimeType}, 值: $value');
    return null;
  }

  /// 生成操作描述
  String _generateOperationDescription(Operation operation) {
    final params = operation.params;
    final category = params['category'] as String? ?? '';
    final amount = _safeParseAmount(params['amount']);

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
    // 首先标记为已释放，防止计时器回调执行
    _isDisposed = true;

    _deferredTimer?.cancel();
    _deferredTimer = null;
    _maxDeferredTimer?.cancel();
    _maxDeferredTimer = null;
    _deferredStartTime = null;
    _pendingDeferredOperations.clear();
    _resultBuffer.dispose();
    _processor.dispose();
    debugPrint('[IntelligenceEngine] 已释放资源');
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Deferred 操作处理
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 安全触发 deferred 操作处理
  ///
  /// 解决的问题：
  /// 1. Timer 回调不能直接 await Future，需要包装处理
  /// 2. 防止滑动窗口计时器和最大等待计时器同时触发导致的并发执行
  /// 3. 捕获并记录异步执行中的异常，避免静默失败
  void _safeTriggerDeferredProcessing(String source) {
    debugPrint('[IntelligenceEngine] $source 触发');

    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('[IntelligenceEngine] 已释放，跳过 $source 触发的处理');
      return;
    }

    // 检查是否正在处理中（防止并发）
    if (_isProcessingDeferred) {
      debugPrint('[IntelligenceEngine] 已有处理在进行中，跳过 $source 触发的重复处理');
      return;
    }

    // 立即设置标志，消除检查和执行之间的竞态窗口
    _isProcessingDeferred = true;

    // 异步执行并捕获错误（fire-and-forget 模式，但记录错误）
    _processDeferredOperations().catchError((error, stackTrace) {
      debugPrint('[IntelligenceEngine] $source 触发的处理失败: $error');
      debugPrint('[IntelligenceEngine] 堆栈: $stackTrace');
      return OperationExecutionReport([]); // 返回空报告
    });
  }

  /// 处理缓存的 deferred 操作
  ///
  /// 计时器到期时调用，统一处理所有缓存的操作
  /// 返回操作执行报告
  ///
  /// 注意：使用 try-finally 确保状态始终被正确清理
  /// _isProcessingDeferred 已在 _safeTriggerDeferredProcessing 中设置
  Future<OperationExecutionReport> _processDeferredOperations() async {
    try {
      // 检查是否已释放（计时器回调可能在 dispose 后仍被触发）
      if (_isDisposed) {
        debugPrint('[IntelligenceEngine] 已释放，跳过延迟操作处理');
        return OperationExecutionReport([]);
      }

      // 注意：_isProcessingDeferred 已在调用方设置，无需重复设置
      // 清理所有计时器（无论后续操作是否成功）
      _deferredTimer?.cancel();
      _deferredTimer = null;
      _maxDeferredTimer?.cancel();
      _maxDeferredTimer = null;

      // 记录等待时间（用于调试）
      final waitTime = _deferredStartTime != null
          ? DateTime.now().difference(_deferredStartTime!).inMilliseconds
          : 0;
      _deferredStartTime = null;

      if (_pendingDeferredOperations.isEmpty) {
        debugPrint('[IntelligenceEngine] 无待处理的延迟操作');
        return OperationExecutionReport([]);
      }

      // 先取出所有待处理操作的快照，然后立即清空
      // 这样即使执行过程中发生异常，状态也已被清理
      final pendingOperationsSnapshot = List<_PendingOperation>.from(_pendingDeferredOperations);
      _pendingDeferredOperations.clear();

      final operationCount = pendingOperationsSnapshot.length;
      debugPrint('[IntelligenceEngine] 处理${operationCount}个延迟操作，等待了${waitTime}ms');

      final reportItems = <OperationResultItem>[];

      // 执行所有缓存的操作，逐个记录结果
      for (int i = 0; i < pendingOperationsSnapshot.length; i++) {
        final pending = pendingOperationsSnapshot[i];
        final description = _generateOperationDescription(pending.operation);
        final amount = _safeParseAmount(pending.operation.params['amount']);

        try {
          // 将用户输入传递给FeedbackAdapter（在处理前设置，确保上下文正确）
          if (feedbackAdapter is BookkeepingFeedbackAdapter) {
            (feedbackAdapter as BookkeepingFeedbackAdapter).setLastUserInput(pending.input);
          }

          // 如果是查询操作，生成operationId
          final Operation enhancedOperation;
          if (pending.operation.type == OperationType.query) {
            final operationId = 'query_${DateTime.now().millisecondsSinceEpoch}_${pending.operation.hashCode}';
            enhancedOperation = Operation(
              type: pending.operation.type,
              priority: pending.operation.priority,
              params: {
                ...pending.operation.params,
                'operationId': operationId,
              },
              originalText: pending.operation.originalText,
            );
            debugPrint('[IntelligenceEngine] 生成延迟查询operationId: $operationId');
          } else {
            enhancedOperation = pending.operation;
          }

          // 创建增强后的 MultiOperationResult
          final enhancedResult = MultiOperationResult(
            resultType: pending.recognitionResult.resultType,
            operations: [enhancedOperation],
            chatContent: pending.recognitionResult.chatContent,
            confidence: pending.recognitionResult.confidence,
            source: pending.recognitionResult.source,
            originalInput: pending.recognitionResult.originalInput,
            isOfflineMode: pending.recognitionResult.isOfflineMode,
          );

          await _processor.process(enhancedResult);

          // 获取执行结果
          final results = _processor.conversationChannel.getRecentResults();
          final ExecutionResult executionResult;
          if (results.isNotEmpty) {
            executionResult = results.last;
          } else {
            // 未获取到结果时，不应假设成功，而应标记为未知状态
            debugPrint('[IntelligenceEngine] 警告: 延迟操作 $i 执行后未获取到结果，标记为失败');
            executionResult = ExecutionResult.failure('未获取到执行结果');
          }

          // 记录到报告
          reportItems.add(OperationResultItem(
            index: i,
            description: description,
            isSuccess: executionResult.success,
            errorMessage: executionResult.error,
            amount: amount,
            operationType: pending.operation.type,
          ));

          _resultBuffer.add(
            result: executionResult,
            description: description,
            amount: amount,
            operationType: pending.operation.type,
          );

          debugPrint('[IntelligenceEngine] 延迟操作 $i 执行${executionResult.success ? "成功" : "失败"}: $description');
        } catch (e, stack) {
          debugPrint('[IntelligenceEngine] 延迟操作 $i 执行异常: $e');
          debugPrint('[IntelligenceEngine] 堆栈: $stack');

          // 记录失败到报告
          reportItems.add(OperationResultItem(
            index: i,
            description: description,
            isSuccess: false,
            errorMessage: e.toString(),
            amount: amount,
            operationType: pending.operation.type,
          ));

          // 不暴露内部错误给用户
          _resultBuffer.add(
            result: ExecutionResult.failure('操作执行失败'),
            description: description,
            amount: amount,
            operationType: pending.operation.type,
          );
        }
      }

      // 生成执行报告
      final report = OperationExecutionReport(reportItems);
      debugPrint('[IntelligenceEngine] 延迟操作执行报告: $report');

      // 生成用户友好的响应消息
      final responseMessage = report.toUserFriendlyMessage();
      _lastResponse = responseMessage;

      // 通过回调通知外部（再次检查 _isDisposed，因为异步执行期间状态可能已改变）
      if (!_isDisposed) {
        debugPrint('[IntelligenceEngine] 延迟操作处理完成，通知外部: $responseMessage');
        // 保护回调异常不影响内部状态
        try {
          onDeferredResponse?.call(responseMessage);
        } catch (e) {
          debugPrint('[IntelligenceEngine] 延迟响应回调异常: $e');
        }
      } else {
        debugPrint('[IntelligenceEngine] 已释放，跳过延迟响应通知');
      }

      return report;
    } finally {
      // 无论成功还是失败，都要清除处理中标志
      _isProcessingDeferred = false;
    }
  }

  /// 取消待处理的 deferred 操作
  ///
  /// 当用户说"取消"时调用
  ///
  /// 注意：如果已有操作正在处理中（_isProcessingDeferred=true），
  /// 本方法仍会清理计时器和待处理列表，但正在执行的操作会继续完成
  /// （因为它们已经取了快照）。这是预期行为，避免中断正在执行的数据库操作。
  void cancelPendingDeferredOperations() {
    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('[IntelligenceEngine] 已释放，跳过取消操作');
      return;
    }

    // 如果正在处理中，记录警告（但仍清理待处理队列，防止后续操作）
    if (_isProcessingDeferred) {
      debugPrint('[IntelligenceEngine] 警告: 有操作正在执行中，将清理待处理队列但不影响正在执行的操作');
    }

    _deferredTimer?.cancel();
    _deferredTimer = null;
    _maxDeferredTimer?.cancel();
    _maxDeferredTimer = null;
    _deferredStartTime = null;
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
  final Map<String, dynamic>? data;

  const VoiceSessionResult({
    required this.success,
    this.message,
    this.data,
  });
}
