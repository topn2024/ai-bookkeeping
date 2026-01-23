import 'dart:async';
import 'package:flutter/foundation.dart';
import '../smart_intent_recognizer.dart';

/// 智能聚合器
///
/// 职责：
/// - 基础等待：1.5秒聚合窗口
/// - VAD触发：检测到1秒静音后300ms内触发
/// - 话题感知：检测话题切换立即执行前序操作
class IntelligentAggregator {
  final ExecutionTriggerCallback onTrigger;

  // 聚合队列
  final List<Operation> _queue = [];

  // 聚合计时器
  Timer? _aggregationTimer;

  // 状态
  AggregatorState _state = AggregatorState.idle;

  // 配置
  static const int _baseWindowMs = 1500;
  static const int _vadBufferMs = 300;
  static const int _maxQueueSize = 10;

  IntelligentAggregator({
    required this.onTrigger,
  });

  /// 添加操作到聚合队列
  void addOperation(Operation operation) {
    debugPrint('[IntelligentAggregator] 添加操作: ${operation.type}, 当前状态: $_state');

    // 检查话题切换
    if (_queue.isNotEmpty && _isTopicSwitch(operation)) {
      debugPrint('[IntelligentAggregator] 检测到话题切换，立即执行前序操作');
      _triggerExecution();
    }

    // 添加到队列
    _queue.add(operation);
    _state = AggregatorState.collecting;

    // 检查队列容量
    if (_queue.length >= _maxQueueSize) {
      debugPrint('[IntelligentAggregator] 队列已满，立即执行');
      _triggerExecution();
      return;
    }

    // 启动基础等待计时器
    _startBaseTimer();
  }

  /// 检测话题切换
  bool _isTopicSwitch(Operation newOperation) {
    if (_queue.isEmpty) return false;

    final lastOperation = _queue.last;

    // 检查操作类型变化
    if (newOperation.type != lastOperation.type) {
      return true;
    }

    // 检查优先级变化
    if (newOperation.priority != lastOperation.priority) {
      return true;
    }

    return false;
  }

  /// 启动基础等待计时器
  void _startBaseTimer() {
    // 如果计时器已存在，不重新启动
    if (_aggregationTimer != null && _aggregationTimer!.isActive) {
      return;
    }

    debugPrint('[IntelligentAggregator] 启动基础等待计时器: ${_baseWindowMs}ms');
    _state = AggregatorState.waiting;

    _aggregationTimer = Timer(
      Duration(milliseconds: _baseWindowMs),
      () {
        debugPrint('[IntelligentAggregator] 基础等待计时器触发');
        _triggerExecution();
      },
    );
  }

  /// VAD静音触发（由外部调用）
  void onVADSilenceDetected() {
    if (_queue.isEmpty) return;

    debugPrint('[IntelligentAggregator] VAD检测到静音，${_vadBufferMs}ms后触发');

    // 取消现有计时器
    _aggregationTimer?.cancel();

    // 启动VAD缓冲计时器
    _aggregationTimer = Timer(
      Duration(milliseconds: _vadBufferMs),
      () {
        debugPrint('[IntelligentAggregator] VAD缓冲计时器触发');
        _triggerExecution();
      },
    );
  }

  /// 触发执行
  void _triggerExecution() {
    if (_queue.isEmpty) {
      _state = AggregatorState.idle;
      return;
    }

    _state = AggregatorState.executing;

    // 取消计时器
    _aggregationTimer?.cancel();
    _aggregationTimer = null;

    // 复制队列并清空
    final operations = List<Operation>.from(_queue);
    _queue.clear();

    debugPrint('[IntelligentAggregator] 触发执行: ${operations.length}个操作');

    // 回调通知
    onTrigger(operations);

    _state = AggregatorState.idle;
  }

  /// 清空队列
  void clear() {
    _aggregationTimer?.cancel();
    _aggregationTimer = null;
    _queue.clear();
    _state = AggregatorState.idle;
  }

  /// 获取当前状态
  AggregatorState get state => _state;

  /// 获取队列长度
  int get queueLength => _queue.length;

  /// 清理资源
  void dispose() {
    _aggregationTimer?.cancel();
    _queue.clear();
  }
}

/// 聚合器状态
enum AggregatorState {
  idle,       // 空闲
  collecting, // 收集中
  waiting,    // 等待中
  executing,  // 执行中
}

/// 执行触发回调
typedef ExecutionTriggerCallback = void Function(List<Operation> operations);
