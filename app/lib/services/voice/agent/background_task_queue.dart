/// 后台任务队列
///
/// 异步执行操作意图，不阻塞用户交互
///
/// 核心特性：
/// - 队列管理：按优先级排序执行
/// - 并发控制：限制同时执行的任务数
/// - 结果通知：任务完成后通知订阅者
/// - 失败重试：可配置的重试策略
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'decomposed_intent.dart';
import 'action_router.dart';

/// 任务状态
enum TaskStatus {
  /// 等待执行
  pending,

  /// 执行中
  running,

  /// 已完成
  completed,

  /// 失败
  failed,

  /// 已取消
  cancelled,
}

/// 队列中的任务
class QueuedTask {
  /// 任务ID
  final String id;

  /// 操作意图
  final ActionIntent intent;

  /// 任务状态
  TaskStatus status;

  /// 创建时间
  final DateTime createdAt;

  /// 开始执行时间
  DateTime? startedAt;

  /// 完成时间
  DateTime? completedAt;

  /// 执行结果
  ActionExecutionResult? result;

  /// 重试次数
  int retryCount;

  /// 最大重试次数
  final int maxRetries;

  QueuedTask({
    required this.id,
    required this.intent,
    this.status = TaskStatus.pending,
    DateTime? createdAt,
    this.retryCount = 0,
    this.maxRetries = 2,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 任务优先级（用于排序）
  int get priority => intent.priority;

  /// 等待时间（毫秒）
  int get waitTimeMs => DateTime.now().difference(createdAt).inMilliseconds;

  /// 执行时间（毫秒）
  int get executionTimeMs {
    if (startedAt == null) return 0;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!).inMilliseconds;
  }
}

/// 后台任务队列
class BackgroundTaskQueue {
  /// 任务队列
  final List<QueuedTask> _queue = [];

  /// 正在执行的任务
  final Map<String, QueuedTask> _runningTasks = {};

  /// 已完成的任务（保留最近N个）
  final List<QueuedTask> _completedTasks = [];

  /// 最大并发数
  final int maxConcurrency;

  /// 保留的已完成任务数
  final int maxCompletedTasks;

  /// 任务执行器
  final ActionRouter _actionRouter;

  /// 结果通知流
  final StreamController<ActionExecutionResult> _resultController =
      StreamController<ActionExecutionResult>.broadcast();

  /// 队列状态变化流
  final StreamController<QueueStatus> _statusController =
      StreamController<QueueStatus>.broadcast();

  /// 任务ID计数器
  int _taskIdCounter = 0;

  /// 是否正在处理队列
  bool _isProcessing = false;

  BackgroundTaskQueue({
    this.maxConcurrency = 3,
    this.maxCompletedTasks = 20,
    ActionRouter? actionRouter,
  }) : _actionRouter = actionRouter ?? ActionRouter();

  /// 获取结果流
  Stream<ActionExecutionResult> get resultStream => _resultController.stream;

  /// 获取状态流
  Stream<QueueStatus> get statusStream => _statusController.stream;

  /// 获取队列状态
  QueueStatus get status => QueueStatus(
        pendingCount: _queue.length,
        runningCount: _runningTasks.length,
        completedCount: _completedTasks.length,
      );

  /// 添加任务到队列
  String enqueue(ActionIntent intent) {
    final taskId = 'task_${++_taskIdCounter}_${DateTime.now().millisecondsSinceEpoch}';
    final task = QueuedTask(
      id: taskId,
      intent: intent,
    );

    _queue.add(task);
    // 按优先级排序（优先级数值小的在前）
    _queue.sort((a, b) => a.priority.compareTo(b.priority));

    debugPrint('[TaskQueue] 任务入队: $taskId (${intent.intentId})');
    _notifyStatusChange();

    // 触发队列处理
    _processQueue();

    return taskId;
  }

  /// 批量添加任务
  List<String> enqueueAll(List<ActionIntent> intents) {
    return intents.map((intent) => enqueue(intent)).toList();
  }

  /// 取消任务
  bool cancel(String taskId) {
    // 检查是否在等待队列中
    final queueIndex = _queue.indexWhere((t) => t.id == taskId);
    if (queueIndex >= 0) {
      final task = _queue.removeAt(queueIndex);
      task.status = TaskStatus.cancelled;
      debugPrint('[TaskQueue] 任务取消: $taskId');
      _notifyStatusChange();
      return true;
    }

    // 正在执行的任务无法取消
    if (_runningTasks.containsKey(taskId)) {
      debugPrint('[TaskQueue] 任务正在执行，无法取消: $taskId');
      return false;
    }

    return false;
  }

  /// 取消所有任务
  void cancelAll() {
    for (final task in _queue) {
      task.status = TaskStatus.cancelled;
    }
    _queue.clear();
    debugPrint('[TaskQueue] 已取消所有等待中的任务');
    _notifyStatusChange();
  }

  /// 获取任务状态
  TaskStatus? getTaskStatus(String taskId) {
    // 检查等待队列
    final queuedTask = _queue.firstWhereOrNull((t) => t.id == taskId);
    if (queuedTask != null) return queuedTask.status;

    // 检查运行中
    final runningTask = _runningTasks[taskId];
    if (runningTask != null) return runningTask.status;

    // 检查已完成
    final completedTask = _completedTasks.firstWhereOrNull((t) => t.id == taskId);
    if (completedTask != null) return completedTask.status;

    return null;
  }

  /// 获取任务结果
  ActionExecutionResult? getTaskResult(String taskId) {
    final completedTask = _completedTasks.firstWhereOrNull((t) => t.id == taskId);
    return completedTask?.result;
  }

  /// 处理队列
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_queue.isNotEmpty && _runningTasks.length < maxConcurrency) {
        final task = _queue.removeAt(0);
        _executeTask(task);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// 执行单个任务
  Future<void> _executeTask(QueuedTask task) async {
    task.status = TaskStatus.running;
    task.startedAt = DateTime.now();
    _runningTasks[task.id] = task;

    debugPrint('[TaskQueue] 开始执行任务: ${task.id} (${task.intent.intentId})');
    _notifyStatusChange();

    final stopwatch = Stopwatch()..start();

    try {
      // 将 ActionIntent 转换为 IntentResult 执行
      final intentResult = task.intent.toIntentResult();
      final actionResult = await _actionRouter.execute(intentResult);

      stopwatch.stop();

      task.result = ActionExecutionResult(
        intent: task.intent,
        success: actionResult.success,
        responseText: actionResult.responseText,
        error: actionResult.error,
        data: actionResult.data,
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );

      if (actionResult.success) {
        task.status = TaskStatus.completed;
        debugPrint('[TaskQueue] 任务完成: ${task.id} (${stopwatch.elapsedMilliseconds}ms)');
      } else {
        // 检查是否需要重试
        if (task.retryCount < task.maxRetries) {
          task.retryCount++;
          task.status = TaskStatus.pending;
          _queue.add(task);
          debugPrint('[TaskQueue] 任务失败，重试 ${task.retryCount}/${task.maxRetries}: ${task.id}');
        } else {
          task.status = TaskStatus.failed;
          debugPrint('[TaskQueue] 任务失败（已达最大重试次数）: ${task.id}');
        }
      }
    } catch (e) {
      stopwatch.stop();

      task.result = ActionExecutionResult.failure(
        task.intent,
        error: e.toString(),
        executionTimeMs: stopwatch.elapsedMilliseconds,
      );

      // 检查是否需要重试
      if (task.retryCount < task.maxRetries) {
        task.retryCount++;
        task.status = TaskStatus.pending;
        _queue.add(task);
        debugPrint('[TaskQueue] 任务异常，重试 ${task.retryCount}/${task.maxRetries}: ${task.id}');
      } else {
        task.status = TaskStatus.failed;
        debugPrint('[TaskQueue] 任务异常（已达最大重试次数）: ${task.id} - $e');
      }
    }

    // 从运行中移除
    _runningTasks.remove(task.id);
    task.completedAt = DateTime.now();

    // 添加到已完成列表
    if (task.status == TaskStatus.completed || task.status == TaskStatus.failed) {
      _completedTasks.add(task);
      if (_completedTasks.length > maxCompletedTasks) {
        _completedTasks.removeAt(0);
      }

      // 通知结果
      if (task.result != null) {
        _resultController.add(task.result!);
      }
    }

    _notifyStatusChange();

    // 继续处理队列
    _processQueue();
  }

  /// 通知状态变化
  void _notifyStatusChange() {
    _statusController.add(status);
  }

  /// 释放资源
  void dispose() {
    _resultController.close();
    _statusController.close();
    _queue.clear();
    _runningTasks.clear();
    _completedTasks.clear();
  }
}

/// 队列状态
class QueueStatus {
  /// 等待中的任务数
  final int pendingCount;

  /// 运行中的任务数
  final int runningCount;

  /// 已完成的任务数
  final int completedCount;

  const QueueStatus({
    required this.pendingCount,
    required this.runningCount,
    required this.completedCount,
  });

  /// 是否空闲
  bool get isIdle => pendingCount == 0 && runningCount == 0;

  /// 总任务数
  int get totalCount => pendingCount + runningCount + completedCount;

  @override
  String toString() =>
      'QueueStatus(pending: $pendingCount, running: $runningCount, completed: $completedCount)';
}

/// List 扩展
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
