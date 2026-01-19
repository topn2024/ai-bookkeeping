import 'dart:async';
import 'package:flutter/foundation.dart';
import '../smart_intent_recognizer.dart';
import 'intelligence_engine.dart';
import 'models.dart';

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

  DualChannelProcessor({
    required this.executionChannel,
    required this.conversationChannel,
  }) {
    // 关键：连接两个通道 - 将执行结果自动传递给对话通道
    executionChannel.registerCallback((result) {
      debugPrint('[DualChannelProcessor] 执行结果回调: success=${result.success}');
      conversationChannel.addExecutionResult(result);
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
}

/// 执行通道
///
/// 职责：
/// - 优先级队列管理
/// - 操作聚合（1.5秒基础窗口）
/// - 通过 OperationAdapter 执行操作
/// - 执行结果回调
class ExecutionChannel {
  final OperationAdapter adapter;
  final List<OperationCallback> _callbacks = [];

  // 优先级队列
  final List<Operation> _immediateQueue = [];
  final List<Operation> _normalQueue = [];
  final List<Operation> _deferredQueue = [];

  // 聚合计时器
  Timer? _aggregationTimer;

  // 队列容量限制
  static const int _maxQueueSize = 10;

  // 聚合窗口时间（毫秒）
  static const int _aggregationWindowMs = 1500;

  ExecutionChannel({
    required this.adapter,
  });

  /// 注册回调
  void registerCallback(OperationCallback callback) {
    _callbacks.add(callback);
  }

  /// 入队操作
  Future<void> enqueue(Operation operation) async {
    debugPrint('[ExecutionChannel] 入队操作: ${operation.type}, 优先级: ${operation.priority}');

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
        // deferred 操作进入聚合队列
        _deferredQueue.add(operation);
        _startAggregationTimer();

        // 检查队列容量
        if (_deferredQueue.length >= _maxQueueSize) {
          debugPrint('[ExecutionChannel] 队列已满，提前执行');
          await _executeDeferredQueue();
        }
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

    // 执行 immediate 操作
    final result = await adapter.execute(operation);
    _notifyCallbacks(result);
  }

  /// 执行 normal 队列
  Future<void> _executeNormalQueue() async {
    if (_normalQueue.isEmpty) return;

    debugPrint('[ExecutionChannel] 执行 normal 队列: ${_normalQueue.length}个操作');

    final operations = List<Operation>.from(_normalQueue);
    _normalQueue.clear();

    for (final operation in operations) {
      final result = await adapter.execute(operation);
      _notifyCallbacks(result);
    }
  }

  /// 执行 deferred 队列
  Future<void> _executeDeferredQueue() async {
    if (_deferredQueue.isEmpty) return;

    // 取消聚合计时器
    _aggregationTimer?.cancel();
    _aggregationTimer = null;

    debugPrint('[ExecutionChannel] 批量执行 deferred 队列: ${_deferredQueue.length}个操作');

    final operations = List<Operation>.from(_deferredQueue);
    _deferredQueue.clear();

    // 批量执行
    for (final operation in operations) {
      final result = await adapter.execute(operation);
      _notifyCallbacks(result);
    }
  }

  /// 启动聚合计时器
  void _startAggregationTimer() {
    // 如果计时器已存在，不重新启动
    if (_aggregationTimer != null && _aggregationTimer!.isActive) {
      return;
    }

    debugPrint('[ExecutionChannel] 启动聚合计时器: ${_aggregationWindowMs}ms');

    _aggregationTimer = Timer(
      Duration(milliseconds: _aggregationWindowMs),
      () async {
        debugPrint('[ExecutionChannel] 聚合计时器触发');
        await _executeDeferredQueue();
      },
    );
  }

  /// 通知所有回调
  void _notifyCallbacks(ExecutionResult result) {
    for (final callback in _callbacks) {
      try {
        callback(result);
      } catch (e) {
        debugPrint('[ExecutionChannel] 回调执行失败: $e');
      }
    }
  }

  /// 刷新队列，确保所有待执行操作都完成
  Future<void> flush() async {
    debugPrint('[ExecutionChannel] flush(): 执行所有待处理操作');

    // 执行所有deferred操作
    if (_deferredQueue.isNotEmpty) {
      await _executeDeferredQueue();
    }

    debugPrint('[ExecutionChannel] flush()完成');
  }

  /// 清理资源
  void dispose() {
    _aggregationTimer?.cancel();
    _callbacks.clear();
    _immediateQueue.clear();
    _normalQueue.clear();
    _deferredQueue.clear();
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
  final List<ExecutionResult> _executionResults = [];
  String? _chatContent;

  ConversationChannel({
    required this.adapter,
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
  Future<String> generateResponse(ConversationMode mode) async {
    debugPrint('[ConversationChannel] 生成响应, 模式: $mode');
    debugPrint('[ConversationChannel] 当前执行结果数量: ${_executionResults.length}');
    debugPrint('[ConversationChannel] 执行结果详情: ${_executionResults.map((r) => 'success=${r.success}').join(', ')}');

    final response = await adapter.generateFeedback(
      mode,
      _executionResults,
      _chatContent,
    );

    debugPrint('[ConversationChannel] 生成的响应: $response');

    // 清空状态
    _executionResults.clear();
    _chatContent = null;

    return response;
  }

  /// 获取最近的执行结果
  List<ExecutionResult> getRecentResults({int limit = 10}) {
    if (_executionResults.length <= limit) {
      return List.from(_executionResults);
    }
    return _executionResults.sublist(_executionResults.length - limit);
  }
}

/// 操作回调类型
typedef OperationCallback = void Function(ExecutionResult result);
