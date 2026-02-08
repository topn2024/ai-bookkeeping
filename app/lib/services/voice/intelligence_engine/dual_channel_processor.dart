import 'dart:async';
import 'package:flutter/foundation.dart';
import 'engine_config.dart';
import 'engine_error.dart';
import '../smart_intent_recognizer.dart';
import 'intelligence_engine.dart';
import 'models.dart';
import '../events/query_result_event_bus.dart';

/// 双通道处理器
///
/// 包含：
/// - ExecutionChannel: 执行通道（后台处理操作队列）
/// - ConversationChannel: 对话通道（维护对话流）
///
/// 两个通道自动连接：ExecutionChannel 执行完操作后，
/// 结果会自动传递给 ConversationChannel。
class DualChannelProcessor {
  final ExecutionChannel executionChannel;
  final ConversationChannel conversationChannel;

  /// 查询结果事件总线
  final QueryResultEventBus _eventBus = QueryResultEventBus();

  DualChannelProcessor({
    required this.executionChannel,
    required this.conversationChannel,
  }) {
    // 关键：连接两个通道 - 将执行结果自动传递给对话通道
    executionChannel.registerCallback((result) {
      debugPrint('[DualChannelProcessor] 执行结果回调: success=${result.success}');
      conversationChannel.addExecutionResult(result);

      // 如果是查询操作，发布事件
      final operationId = result.data?['operationId'] as String?;
      if (operationId != null) {
        _eventBus.publishResult(operationId, result);
        debugPrint('[DualChannelProcessor] 发布查询结果事件: $operationId');
      }
    });
  }

  /// 处理多操作结果
  Future<void> process(MultiOperationResult result) async {
    debugPrint('[DualChannelProcessor] 处理${result.operations.length}个操作');
    debugPrint('[DualChannelProcessor] operations详情: ${result.operations.map((op) => '${op.type}(${op.priority})').join(', ')}');

    // 将操作分发到执行通道
    for (final operation in result.operations) {
      debugPrint('[DualChannelProcessor] 准备入队操作: ${operation.type}, priority=${operation.priority}');
      await executionChannel.enqueue(operation);
      debugPrint('[DualChannelProcessor] 操作入队完成: ${operation.type}');
    }

    // 确保所有deferred操作也执行完成
    await executionChannel.flush();

    // 将对话内容传递到对话通道
    if (result.chatContent != null) {
      conversationChannel.addChatContent(result.chatContent!);
    }

    debugPrint('[DualChannelProcessor] process()完成');
  }

  /// 释放资源
  void dispose() {
    executionChannel.dispose();
    // ConversationChannel 无需特殊释放，只需清理状态
    conversationChannel.clear();
    debugPrint('[DualChannelProcessor] 已释放资源');
  }
}

/// 执行通道
///
/// 职责：
/// - 优先级队列管理
/// - 操作聚合（2.5秒基础窗口）
/// - 通过 OperationAdapter 执行操作
/// - 执行结果回调
class ExecutionChannel {
  final OperationAdapter adapter;
  final EngineErrorHandler? errorHandler;
  final List<OperationCallback> _callbacks = [];

  /// 组件名称（用于错误日志）
  static const String _componentName = 'ExecutionChannel';

  /// 错误回调（可选，已废弃，推荐使用 errorHandler）
  /// 当回调执行失败时调用，用于外部监控和错误处理
  @Deprecated('Use errorHandler instead')
  void Function(Object error, StackTrace? stackTrace, OperationCallback callback)? onCallbackError;

  // 优先级队列
  final List<Operation> _immediateQueue = [];
  final List<Operation> _normalQueue = [];
  final List<Operation> _deferredQueue = [];

  // 聚合计时器
  Timer? _aggregationTimer;

  // 执行锁状态
  bool _isExecuting = false;

  // 是否已释放
  bool _isDisposed = false;

  // 等待执行的 Completer 队列（异步锁实现）
  // 当有操作正在执行时，后续请求会创建 Completer 并加入队列等待
  final List<Completer<void>> _executionWaitQueue = [];

  ExecutionChannel({
    required this.adapter,
    this.errorHandler,
  });

  /// 注册回调
  void registerCallback(OperationCallback callback) {
    _callbacks.add(callback);
  }

  /// 入队操作
  ///
  /// 根据优先级将操作分发到不同队列：
  /// - immediate: 立即执行
  /// - normal: 快速执行
  /// - deferred/background: 聚合后批量执行
  Future<void> enqueue(Operation operation) async {
    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('[ExecutionChannel] 已释放，忽略入队操作: ${operation.type}');
      return;
    }

    debugPrint('[ExecutionChannel] 入队操作: ${operation.type}, 优先级: ${operation.priority}');

    // 根据优先级直接处理，执行锁保证串行执行
    switch (operation.priority) {
      case OperationPriority.immediate:
        // immediate 操作立即执行
        await _executeImmediate(operation);
        break;

      case OperationPriority.normal:
        // normal 操作快速执行
        _normalQueue.add(operation);
        await _executeNormalQueue();
        break;

      case OperationPriority.deferred:
        // 先检查队列容量，如果已满则先执行再添加
        // 这样可以保证队列不会超出限制
        if (_deferredQueue.length >= EngineConfig.maxQueueSize) {
          debugPrint('[ExecutionChannel] 队列已满($EngineConfig.maxQueueSize)，先执行现有操作');
          await _executeDeferredQueue();
        }

        // deferred 操作进入聚合队列
        _deferredQueue.add(operation);
        _startAggregationTimer();
        break;

      case OperationPriority.background:
        // background 操作异步执行
        _deferredQueue.add(operation);
        _startAggregationTimer();
        break;
    }
  }

  /// 执行 immediate 操作
  Future<void> _executeImmediate(Operation operation) async {
    debugPrint('[ExecutionChannel] 立即执行: ${operation.type}');

    // 如果有 deferred 操作在等待，先执行它们
    if (_deferredQueue.isNotEmpty) {
      await _executeDeferredQueue();
    }

    // 获取执行锁（异步等待，保证串行）
    final acquired = await _acquireExecutionLock();
    if (!acquired) {
      debugPrint('[ExecutionChannel] 无法获取锁，跳过执行: ${operation.type}');
      return;
    }

    try {
      // 执行 immediate 操作
      final result = await adapter.execute(operation);
      _notifyCallbacks(result);
    } finally {
      _releaseExecutionLock();
    }
  }

  /// 执行 normal 队列
  Future<void> _executeNormalQueue() async {
    if (_normalQueue.isEmpty) return;

    debugPrint('[ExecutionChannel] 执行 normal 队列: ${_normalQueue.length}个操作');

    // 获取执行锁（异步等待，保证串行）
    final acquired = await _acquireExecutionLock();
    if (!acquired) {
      debugPrint('[ExecutionChannel] 无法获取锁，跳过 normal 队列执行');
      return;
    }

    try {
      final operations = List<Operation>.from(_normalQueue);
      _normalQueue.clear();

      for (final operation in operations) {
        // 检查是否已释放
        if (_isDisposed) break;
        final result = await adapter.execute(operation);
        _notifyCallbacks(result);
      }
    } finally {
      _releaseExecutionLock();
    }
  }

  /// 执行 deferred 队列
  Future<void> _executeDeferredQueue() async {
    if (_deferredQueue.isEmpty) return;

    // 取消聚合计时器
    _aggregationTimer?.cancel();
    _aggregationTimer = null;

    debugPrint('[ExecutionChannel] 批量执行 deferred 队列: ${_deferredQueue.length}个操作');

    // 获取执行锁（异步等待，保证串行）
    final acquired = await _acquireExecutionLock();
    if (!acquired) {
      debugPrint('[ExecutionChannel] 无法获取锁，跳过 deferred 队列执行');
      return;
    }

    try {
      final operations = List<Operation>.from(_deferredQueue);
      _deferredQueue.clear();

      // 批量执行
      for (final operation in operations) {
        // 检查是否已释放
        if (_isDisposed) break;
        final result = await adapter.execute(operation);
        _notifyCallbacks(result);
      }
    } finally {
      _releaseExecutionLock();
    }
  }


  /// 获取执行锁（异步队列实现，保证严格串行）
  ///
  /// 使用 Completer 队列代替自旋等待：
  /// - 如果当前无锁，直接获取
  /// - 如果有锁，创建 Completer 加入队列等待
  /// - 前一个操作完成后会唤醒队列中下一个等待者
  ///
  /// 优点：
  /// - 无繁忙等待，不消耗 CPU
  /// - 严格保证串行执行顺序
  /// - 超时保护防止永久挂起
  ///
  /// 返回值：
  /// - true: 成功获取锁
  /// - false: 已释放、超时或无法获取锁
  Future<bool> _acquireExecutionLock() async {
    // 检查是否已释放
    if (_isDisposed) {
      debugPrint('[ExecutionChannel] 已释放，无法获取执行锁');
      return false;
    }

    if (!_isExecuting) {
      // 无锁，直接获取
      _isExecuting = true;
      debugPrint('[ExecutionChannel] 获取执行锁');
      return true;
    }

    // 有锁，创建 Completer 加入等待队列
    final completer = Completer<void>();
    _executionWaitQueue.add(completer);
    debugPrint('[ExecutionChannel] 等待执行锁，队列长度: ${_executionWaitQueue.length}');

    // 等待被唤醒（带超时保护）
    try {
      await completer.future.timeout(
        Duration(seconds: EngineConfig.lockTimeoutSeconds),
      );
    } on TimeoutException {
      debugPrint('[ExecutionChannel] 等待执行锁超时（${EngineConfig.lockTimeoutSeconds}秒）');

      // 从队列中移除自己（如果还在队列中）
      // 注意：可能在超时瞬间被 _releaseExecutionLock 移除并完成
      final removed = _executionWaitQueue.remove(completer);
      if (!removed) {
        // 我们已被移除并获得了锁，直接返回true继续使用锁
        debugPrint('[ExecutionChannel] 超时但已获得锁，继续使用');
        return true;
      }
      return false;
    }

    // 再次检查是否已释放（等待期间可能被 dispose）
    if (_isDisposed) {
      debugPrint('[ExecutionChannel] 等待期间被释放，放弃获取锁');
      // 重要：我们已经继承了锁（_isExecuting=true），必须释放
      _releaseExecutionLock();
      return false;
    }

    // 注意：_isExecuting 已经是 true（从前一个持有者继承），无需再次设置
    debugPrint('[ExecutionChannel] 从队列继承执行锁');
    return true;
  }

  /// 释放执行锁
  ///
  /// 如果有等待者，唤醒队列中的第一个（保持锁状态，由下一个等待者继承）
  /// 如果无等待者，才真正释放锁
  ///
  /// 注意：
  /// - 添加 isCompleted 检查防止双重 complete
  /// - 使用循环而非递归，防止多个超时 Completer 导致栈溢出
  void _releaseExecutionLock() {
    // 循环查找第一个未完成的等待者
    while (_executionWaitQueue.isNotEmpty) {
      final nextCompleter = _executionWaitQueue.removeAt(0);
      debugPrint('[ExecutionChannel] 尝试传递锁，剩余等待者: ${_executionWaitQueue.length}');

      // 检查是否已完成（超时可能已 complete 此 Completer）
      if (!nextCompleter.isCompleted) {
        // 有等待者：保持 _isExecuting = true，让下一个等待者继承锁
        nextCompleter.complete();
        debugPrint('[ExecutionChannel] 锁已传递给等待者');
        return;
      } else {
        debugPrint('[ExecutionChannel] Completer 已完成（可能超时），跳过');
        // 继续循环查找下一个等待者
      }
    }

    // 无等待者或所有等待者都已超时：真正释放锁
    _isExecuting = false;
    debugPrint('[ExecutionChannel] 释放执行锁，无有效等待者');
  }

  /// 启动聚合计时器
  void _startAggregationTimer() {
    // 如果计时器已存在，不重新启动
    if (_aggregationTimer != null && _aggregationTimer!.isActive) {
      return;
    }

    debugPrint('[ExecutionChannel] 启动聚合计时器: ${EngineConfig.aggregationWindowMs}ms');

    _aggregationTimer = Timer(
      Duration(milliseconds: EngineConfig.aggregationWindowMs),
      () async {
        // 检查是否已释放（计时器回调可能在 dispose 后触发）
        if (_isDisposed) {
          debugPrint('[ExecutionChannel] 已释放，跳过聚合计时器处理');
          return;
        }
        debugPrint('[ExecutionChannel] 聚合计时器触发');
        await _executeDeferredQueue();
      },
    );
  }

  /// 通知所有回调
  ///
  /// 注意：检查 _isDisposed 防止释放后触发回调
  void _notifyCallbacks(ExecutionResult result) {
    // 释放后不再触发回调
    if (_isDisposed) {
      debugPrint('[$_componentName] 已释放，跳过回调通知');
      return;
    }

    for (final callback in _callbacks) {
      // 每次回调前再次检查（回调执行可能较慢，期间可能被 dispose）
      if (_isDisposed) {
        debugPrint('[$_componentName] 回调期间被释放，停止后续回调');
        break;
      }

      try {
        callback(result);
      } catch (e, stackTrace) {
        // 使用统一错误处理器
        errorHandler?.handleCallbackError(
          message: '回调执行失败: $e',
          component: _componentName,
          callbackName: 'OperationCallback',
          originalError: e,
          stackTrace: stackTrace,
        );

        // 兼容旧的错误回调（已废弃）
        if (!_isDisposed) {
          try {
            // ignore: deprecated_member_use_from_same_package
            onCallbackError?.call(e, stackTrace, callback);
          } catch (callbackError) {
            // 防止错误回调本身抛出异常
            debugPrint('[$_componentName] 错误回调处理器执行失败: $callbackError');
          }
        }
      }
    }
  }

  /// 刷新队列，确保所有待执行操作都完成
  Future<void> flush() async {
    debugPrint('[ExecutionChannel] flush(): 执行所有待处理操作');

    // 执行所有 normal 操作
    if (_normalQueue.isNotEmpty) {
      await _executeNormalQueue();
    }

    // 执行所有 deferred 操作
    if (_deferredQueue.isNotEmpty) {
      await _executeDeferredQueue();
    }

    debugPrint('[ExecutionChannel] flush()完成');
  }

  /// 清理资源
  void dispose() {
    // 首先标记为已释放，防止新操作入队
    _isDisposed = true;

    _aggregationTimer?.cancel();
    _aggregationTimer = null;
    _callbacks.clear();
    _immediateQueue.clear();
    _normalQueue.clear();
    _deferredQueue.clear();
    _isExecuting = false;

    // 完成所有等待中的 Completer，避免永久等待
    for (final completer in _executionWaitQueue) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _executionWaitQueue.clear();

    debugPrint('[ExecutionChannel] 已释放资源');
  }
}

/// 对话通道
///
/// 职责：
/// - 维护对话流
/// - 接收执行结果并注入上下文
/// - 通过 FeedbackAdapter 生成响应
class ConversationChannel {
  final FeedbackAdapter adapter;
  final EngineErrorHandler? errorHandler;
  final List<ExecutionResult> _executionResults = [];
  String? _chatContent;

  /// 组件名称（用于错误日志）
  static const String _componentName = 'ConversationChannel';

  ConversationChannel({
    required this.adapter,
    this.errorHandler,
  });

  /// 添加对话内容
  void addChatContent(String content) {
    _chatContent = content;
    debugPrint('[ConversationChannel] 添加对话内容: $content');
  }

  /// 添加执行结果
  void addExecutionResult(ExecutionResult result) {
    _executionResults.add(result);
    debugPrint('[ConversationChannel] 添加执行结果: $result');
  }

  /// 生成响应
  ///
  /// 注意：无论生成是否成功，都会清空状态，防止旧数据污染下次响应
  Future<String> generateResponse(ConversationMode mode) async {
    debugPrint('[ConversationChannel] 生成响应, 模式: $mode');
    debugPrint('[ConversationChannel] 当前执行结果数量: ${_executionResults.length}');
    debugPrint('[ConversationChannel] 执行结果详情: ${_executionResults.map((r) => 'success=${r.success}').join(', ')}');

    // 先保存当前状态的快照，然后立即清空
    // 这样即使 generateFeedback 抛出异常，状态也已被清空
    final resultsSnapshot = List<ExecutionResult>.from(_executionResults);
    final chatContentSnapshot = _chatContent;

    // 立即清空状态，防止异常情况下旧数据残留
    _executionResults.clear();
    _chatContent = null;

    try {
      final response = await adapter.generateFeedback(
        mode,
        resultsSnapshot,
        chatContentSnapshot,
      );

      debugPrint('[$_componentName] 生成的响应: $response');
      return response;
    } catch (e, stackTrace) {
      // 使用统一错误处理器
      final error = EngineError.execution(
        message: '生成响应失败: $e',
        component: _componentName,
        originalError: e,
        stackTrace: stackTrace,
        userMessage: '抱歉，生成响应时遇到了问题',
        context: {'mode': mode.toString()},
      );
      errorHandler?.handleError(error);

      // 返回一个友好的错误提示，而不是让异常传播
      return error.userMessage!;
    }
  }

  /// 获取最近的执行结果
  List<ExecutionResult> getRecentResults({int limit = 10}) {
    if (_executionResults.length <= limit) {
      return List.from(_executionResults);
    }
    return _executionResults.sublist(_executionResults.length - limit);
  }

  /// 清理状态
  void clear() {
    _executionResults.clear();
    _chatContent = null;
    debugPrint('[ConversationChannel] 状态已清理');
  }
}

/// 操作回调类型
typedef OperationCallback = void Function(ExecutionResult result);
