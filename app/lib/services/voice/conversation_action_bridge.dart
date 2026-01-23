import 'dart:async';
import 'package:flutter/foundation.dart';

import 'agent/conversational_agent.dart';
import 'agent/action_registry.dart';
import 'agent/action_router.dart';
import 'agent/action_executor.dart';

/// 操作执行结果
class OperationResult {
  /// 是否成功
  final bool success;

  /// 操作类型
  final String operationType;

  /// 结果描述
  final String description;

  /// 关联数据
  final Map<String, dynamic>? data;

  /// 错误信息
  final String? error;

  /// 时间戳
  final DateTime timestamp;

  const OperationResult({
    required this.success,
    required this.operationType,
    required this.description,
    this.data,
    this.error,
    required this.timestamp,
  });

  factory OperationResult.success({
    required String operationType,
    required String description,
    Map<String, dynamic>? data,
  }) {
    return OperationResult(
      success: true,
      operationType: operationType,
      description: description,
      data: data,
      timestamp: DateTime.now(),
    );
  }

  factory OperationResult.failure({
    required String operationType,
    required String error,
  }) {
    return OperationResult(
      success: false,
      operationType: operationType,
      description: '',
      error: error,
      timestamp: DateTime.now(),
    );
  }
}

/// 对话与执行桥接器
///
/// 职责：
/// - 接收对话层的操作请求
/// - 异步发送到执行层（不阻塞对话）
/// - 监听执行结果
/// - 将结果反馈到对话上下文
class ConversationActionBridge {
  /// 执行层操作路由
  final ActionRouter _actionRouter;

  /// 执行层操作执行器
  final ActionExecutor _actionExecutor;

  /// 操作队列
  final List<_PendingOperation> _operationQueue = [];

  /// 执行结果流控制器
  final _resultController = StreamController<OperationResult>.broadcast();

  /// 是否正在处理队列
  bool _isProcessing = false;

  /// 当前会话ID
  String? _sessionId;

  ConversationActionBridge({
    ActionRouter? actionRouter,
    ActionExecutor? actionExecutor,
  })  : _actionRouter = actionRouter ?? ActionRouter(),
        _actionExecutor = actionExecutor ?? ActionExecutor();

  // ==================== 公共API ====================

  /// 执行结果流
  Stream<OperationResult> get resultStream => _resultController.stream;

  /// 队列中待处理操作数量
  int get pendingCount => _operationQueue.length;

  /// 是否有待处理操作
  bool get hasPendingOperations => _operationQueue.isNotEmpty;

  /// 开始新会话
  void startSession(String sessionId) {
    _sessionId = sessionId;
    _operationQueue.clear();
    debugPrint('[ActionBridge] 会话开始: $sessionId');
  }

  /// 结束会话
  void endSession() {
    _sessionId = null;
    _operationQueue.clear();
    debugPrint('[ActionBridge] 会话结束');
  }

  /// 提交操作（非阻塞）
  ///
  /// 将操作添加到队列，立即返回
  /// 操作会在后台异步执行
  void submitAction(AgentResponse response) {
    if (_sessionId == null) {
      debugPrint('[ActionBridge] 警告：会话未开始，忽略操作');
      return;
    }

    if (response.actionResult == null) {
      debugPrint('[ActionBridge] 警告：响应无操作结果');
      return;
    }

    final operation = _PendingOperation(
      sessionId: _sessionId!,
      response: response,
      submittedAt: DateTime.now(),
    );

    _operationQueue.add(operation);
    debugPrint('[ActionBridge] 操作已加入队列: ${response.type.name}');

    // 触发队列处理
    _processQueue();
  }

  /// 取消所有待处理操作
  void cancelAll() {
    _operationQueue.clear();
    debugPrint('[ActionBridge] 所有待处理操作已取消');
  }

  /// 释放资源
  void dispose() {
    _resultController.close();
    _operationQueue.clear();
  }

  // ==================== 内部方法 ====================

  /// 处理操作队列
  void _processQueue() async {
    if (_isProcessing) return;
    if (_operationQueue.isEmpty) return;

    _isProcessing = true;

    while (_operationQueue.isNotEmpty) {
      final operation = _operationQueue.removeAt(0);

      // 检查操作是否仍属于当前会话
      if (operation.sessionId != _sessionId) {
        debugPrint('[ActionBridge] 操作已过期，跳过');
        continue;
      }

      try {
        final result = await _executeOperation(operation);
        _resultController.add(result);
      } catch (e) {
        debugPrint('[ActionBridge] 操作执行异常: $e');
        _resultController.add(OperationResult.failure(
          operationType: 'unknown',
          error: e.toString(),
        ));
      }
    }

    _isProcessing = false;
  }

  /// 执行单个操作
  Future<OperationResult> _executeOperation(_PendingOperation operation) async {
    final response = operation.response;
    final actionResult = response.actionResult!;

    debugPrint('[ActionBridge] 执行操作: ${actionResult.actionId}');

    // 根据操作类型执行
    switch (actionResult.actionId) {
      case 'expense':
      case 'income':
        return _executeTransaction(actionResult);
      case 'modify':
        return _executeModify(actionResult);
      case 'delete':
        return _executeDelete(actionResult);
      case 'query':
        return _executeQuery(actionResult);
      default:
        return OperationResult.success(
          operationType: actionResult.actionId ?? 'unknown',
          description: response.text,
          data: actionResult.data,
        );
    }
  }

  /// 执行记账操作
  Future<OperationResult> _executeTransaction(ActionResult actionResult) async {
    final data = actionResult.data;
    if (data == null) {
      return OperationResult.failure(
        operationType: actionResult.actionId ?? 'transaction',
        error: '缺少记账数据',
      );
    }

    // 这里实际调用记账服务
    // 目前返回模拟结果
    return OperationResult.success(
      operationType: actionResult.actionId ?? 'transaction',
      description: '记账成功',
      data: {
        ...data,
        'transactionId': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  /// 执行修改操作
  Future<OperationResult> _executeModify(ActionResult actionResult) async {
    final data = actionResult.data;
    if (data == null || !data.containsKey('transactionId')) {
      return OperationResult.failure(
        operationType: 'modify',
        error: '缺少修改目标',
      );
    }

    return OperationResult.success(
      operationType: 'modify',
      description: '修改成功',
      data: data,
    );
  }

  /// 执行删除操作
  Future<OperationResult> _executeDelete(ActionResult actionResult) async {
    final data = actionResult.data;
    if (data == null || !data.containsKey('transactionId')) {
      return OperationResult.failure(
        operationType: 'delete',
        error: '缺少删除目标',
      );
    }

    return OperationResult.success(
      operationType: 'delete',
      description: '删除成功',
      data: data,
    );
  }

  /// 执行查询操作
  Future<OperationResult> _executeQuery(ActionResult actionResult) async {
    return OperationResult.success(
      operationType: 'query',
      description: '查询完成',
      data: actionResult.data,
    );
  }
}

/// 待处理操作
class _PendingOperation {
  final String sessionId;
  final AgentResponse response;
  final DateTime submittedAt;

  const _PendingOperation({
    required this.sessionId,
    required this.response,
    required this.submittedAt,
  });
}
