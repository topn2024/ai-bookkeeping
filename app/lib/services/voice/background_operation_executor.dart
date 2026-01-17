import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import 'agent/action_router.dart';
import 'agent/action_executor.dart';
import 'agent/hybrid_intent_router.dart';
import 'conversation_action_bridge.dart';

/// 操作优先级
enum OperationPriority {
  /// 高优先级（删除、修改等需要快速反馈的操作）
  high,

  /// 普通优先级（记账等常规操作）
  normal,

  /// 低优先级（查询等可延迟的操作）
  low,
}

/// 后台操作
class BackgroundOperation {
  /// 操作ID
  final String id;

  /// 意图结果
  final IntentResult intent;

  /// 优先级
  final OperationPriority priority;

  /// 提交时间
  final DateTime submittedAt;

  /// 重试次数
  int retryCount;

  /// 最大重试次数
  final int maxRetries;

  BackgroundOperation({
    required this.id,
    required this.intent,
    this.priority = OperationPriority.normal,
    DateTime? submittedAt,
    this.retryCount = 0,
    this.maxRetries = 3,
  }) : submittedAt = submittedAt ?? DateTime.now();

  /// 是否可以重试
  bool get canRetry => retryCount < maxRetries;
}

/// 后台操作执行器
///
/// 职责：
/// - 管理操作队列（按优先级排序）
/// - 异步执行操作（不阻塞调用方）
/// - 提供执行结果流
/// - 支持重试机制
class BackgroundOperationExecutor {
  /// 操作路由
  final ActionRouter _actionRouter;

  /// 操作执行器
  final ActionExecutor _actionExecutor;

  /// 操作队列（按优先级排序）
  final SplayTreeMap<int, Queue<BackgroundOperation>> _queues = SplayTreeMap();

  /// 执行结果流控制器
  final _resultController = StreamController<OperationResult>.broadcast();

  /// 操作状态流控制器
  final _statusController = StreamController<OperationStatus>.broadcast();

  /// 是否正在处理
  bool _isProcessing = false;

  /// 当前会话ID
  String? _sessionId;

  /// 已完成操作数量
  int _completedCount = 0;

  /// 失败操作数量
  int _failedCount = 0;

  BackgroundOperationExecutor({
    ActionRouter? actionRouter,
    ActionExecutor? actionExecutor,
  })  : _actionRouter = actionRouter ?? ActionRouter(),
        _actionExecutor = actionExecutor ?? ActionExecutor() {
    // 初始化优先级队列
    for (final priority in OperationPriority.values) {
      _queues[priority.index] = Queue<BackgroundOperation>();
    }
  }

  // ==================== 公共API ====================

  /// 执行结果流
  Stream<OperationResult> get resultStream => _resultController.stream;

  /// 操作状态流
  Stream<OperationStatus> get statusStream => _statusController.stream;

  /// 待处理操作总数
  int get pendingCount => _queues.values.fold(0, (sum, q) => sum + q.length);

  /// 是否有待处理操作
  bool get hasPendingOperations => pendingCount > 0;

  /// 已完成数量
  int get completedCount => _completedCount;

  /// 失败数量
  int get failedCount => _failedCount;

  /// 开始新会话
  void startSession(String sessionId) {
    _sessionId = sessionId;
    _clearQueues();
    _completedCount = 0;
    _failedCount = 0;
    debugPrint('[BackgroundExecutor] 会话开始: $sessionId');
  }

  /// 结束会话
  void endSession() {
    _sessionId = null;
    _clearQueues();
    debugPrint('[BackgroundExecutor] 会话结束');
  }

  /// 提交操作到后台执行
  ///
  /// 立即返回，操作在后台异步执行
  String submitOperation(
    IntentResult intent, {
    OperationPriority priority = OperationPriority.normal,
  }) {
    final operationId = _generateOperationId();

    final operation = BackgroundOperation(
      id: operationId,
      intent: intent,
      priority: priority,
    );

    _queues[priority.index]!.add(operation);

    _emitStatus(OperationStatus(
      operationId: operationId,
      status: OperationStatusType.queued,
      message: '操作已加入队列',
    ));

    debugPrint('[BackgroundExecutor] 操作已加入队列: $operationId (${priority.name})');

    // 触发队列处理
    _processQueueAsync();

    return operationId;
  }

  /// 取消指定操作
  bool cancelOperation(String operationId) {
    for (final queue in _queues.values) {
      final operation = queue.where((op) => op.id == operationId).firstOrNull;
      if (operation != null) {
        queue.remove(operation);
        _emitStatus(OperationStatus(
          operationId: operationId,
          status: OperationStatusType.cancelled,
          message: '操作已取消',
        ));
        debugPrint('[BackgroundExecutor] 操作已取消: $operationId');
        return true;
      }
    }
    return false;
  }

  /// 取消所有待处理操作
  void cancelAll() {
    for (final queue in _queues.values) {
      for (final op in queue) {
        _emitStatus(OperationStatus(
          operationId: op.id,
          status: OperationStatusType.cancelled,
          message: '操作已取消',
        ));
      }
      queue.clear();
    }
    debugPrint('[BackgroundExecutor] 所有操作已取消');
  }

  /// 释放资源
  void dispose() {
    _resultController.close();
    _statusController.close();
    _clearQueues();
  }

  // ==================== 内部方法 ====================

  /// 异步处理队列
  void _processQueueAsync() {
    // 不等待，立即返回
    _processQueue();
  }

  /// 处理操作队列
  Future<void> _processQueue() async {
    if (_isProcessing) return;

    _isProcessing = true;

    while (_hasOperations()) {
      final operation = _dequeueNext();
      if (operation == null) break;

      // 检查会话是否仍然有效
      if (_sessionId == null) {
        debugPrint('[BackgroundExecutor] 会话已结束，跳过操作');
        break;
      }

      await _executeOperation(operation);
    }

    _isProcessing = false;
  }

  /// 执行单个操作
  Future<void> _executeOperation(BackgroundOperation operation) async {
    _emitStatus(OperationStatus(
      operationId: operation.id,
      status: OperationStatusType.executing,
      message: '正在执行',
    ));

    try {
      final result = await _actionRouter.execute(operation.intent);

      if (result.success) {
        _completedCount++;
        _emitStatus(OperationStatus(
          operationId: operation.id,
          status: OperationStatusType.completed,
          message: '执行成功',
        ));
        _emitResult(OperationResult.success(
          operationType: operation.intent.action ?? 'unknown',
          description: result.responseText ?? '完成',
          data: result.data,
        ));
        debugPrint('[BackgroundExecutor] 操作完成: ${operation.id}');
      } else {
        _handleOperationFailure(operation, result.error ?? '未知错误');
      }
    } catch (e) {
      _handleOperationFailure(operation, e.toString());
    }
  }

  /// 处理操作失败
  void _handleOperationFailure(BackgroundOperation operation, String error) {
    debugPrint('[BackgroundExecutor] 操作失败: ${operation.id}, 错误: $error');

    if (operation.canRetry) {
      operation.retryCount++;
      _queues[operation.priority.index]!.addFirst(operation);

      _emitStatus(OperationStatus(
        operationId: operation.id,
        status: OperationStatusType.retrying,
        message: '重试中 (${operation.retryCount}/${operation.maxRetries})',
      ));

      debugPrint('[BackgroundExecutor] 操作将重试: ${operation.id}');
    } else {
      _failedCount++;
      _emitStatus(OperationStatus(
        operationId: operation.id,
        status: OperationStatusType.failed,
        message: error,
      ));
      _emitResult(OperationResult.failure(
        operationType: operation.intent.action ?? 'unknown',
        error: error,
      ));
    }
  }

  /// 检查是否有待处理操作
  bool _hasOperations() {
    return _queues.values.any((q) => q.isNotEmpty);
  }

  /// 按优先级出队下一个操作
  BackgroundOperation? _dequeueNext() {
    // 按优先级顺序（高->普通->低）检查队列
    for (final priority in OperationPriority.values) {
      final queue = _queues[priority.index]!;
      if (queue.isNotEmpty) {
        return queue.removeFirst();
      }
    }
    return null;
  }

  /// 生成操作ID
  String _generateOperationId() {
    return 'op_${DateTime.now().millisecondsSinceEpoch}_${_completedCount + _failedCount + pendingCount}';
  }

  /// 清空队列
  void _clearQueues() {
    for (final queue in _queues.values) {
      queue.clear();
    }
  }

  /// 发送执行结果
  void _emitResult(OperationResult result) {
    _resultController.add(result);
  }

  /// 发送操作状态
  void _emitStatus(OperationStatus status) {
    _statusController.add(status);
  }
}

/// 操作状态类型
enum OperationStatusType {
  /// 已加入队列
  queued,

  /// 正在执行
  executing,

  /// 重试中
  retrying,

  /// 已完成
  completed,

  /// 已失败
  failed,

  /// 已取消
  cancelled,
}

/// 操作状态
class OperationStatus {
  /// 操作ID
  final String operationId;

  /// 状态类型
  final OperationStatusType status;

  /// 状态消息
  final String message;

  /// 时间戳
  final DateTime timestamp;

  OperationStatus({
    required this.operationId,
    required this.status,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
