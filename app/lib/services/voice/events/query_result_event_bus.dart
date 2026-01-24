/// 查询结果事件总线
///
/// 职责：
/// - 发布查询完成事件
/// - 管理事件订阅者
/// - 解耦查询执行和UI更新
///
/// 架构优势：
/// - 单一职责：专注于事件通知
/// - 开闭原则：不修改现有组件
/// - 关注点分离：事件通知独立于业务逻辑
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../intelligence_engine/models.dart';

// ═══════════════════════════════════════════════════════════════
// 事件定义
// ═══════════════════════════════════════════════════════════════

/// 查询结果事件
class QueryResultEvent {
  /// 操作ID（用于关联请求和响应）
  final String operationId;

  /// 执行结果
  final ExecutionResult result;

  /// 事件时间
  final DateTime timestamp;

  QueryResultEvent({
    required this.operationId,
    required this.result,
  }) : timestamp = DateTime.now();

  @override
  String toString() => 'QueryResultEvent(operationId: $operationId, success: ${result.success})';
}

// ═══════════════════════════════════════════════════════════════
// 事件总线
// ═══════════════════════════════════════════════════════════════

/// 查询结果事件监听器
typedef QueryResultListener = void Function(QueryResultEvent event);

/// 查询结果事件总线
///
/// 使用发布-订阅模式实现查询结果的异步通知
class QueryResultEventBus {
  /// 单例实例
  static final QueryResultEventBus _instance = QueryResultEventBus._internal();
  factory QueryResultEventBus() => _instance;
  QueryResultEventBus._internal();

  /// 全局监听器（订阅所有事件）
  final List<QueryResultListener> _globalListeners = [];

  /// 特定操作ID的监听器（一次性订阅）
  final Map<String, List<QueryResultListener>> _operationListeners = {};

  /// 监听器超时管理
  final Map<String, Timer> _timeouts = {};

  /// 监听器超时时间（秒）
  static const int listenerTimeoutSeconds = 30;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 订阅管理
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 订阅全局事件（持久订阅）
  ///
  /// 用于需要监听所有查询结果的场景（如日志、监控）
  void subscribeGlobal(QueryResultListener listener) {
    _globalListeners.add(listener);
    debugPrint('[QueryResultEventBus] 添加全局监听器，当前数量: ${_globalListeners.length}');
  }

  /// 取消全局订阅
  void unsubscribeGlobal(QueryResultListener listener) {
    _globalListeners.remove(listener);
    debugPrint('[QueryResultEventBus] 移除全局监听器，剩余数量: ${_globalListeners.length}');
  }

  /// 订阅特定操作的事件（一次性订阅）
  ///
  /// 用于UI层等待特定查询完成的场景
  /// - 事件触发后自动取消订阅
  /// - 30秒后自动超时清理
  void subscribe(String operationId, QueryResultListener listener) {
    _operationListeners.putIfAbsent(operationId, () => []).add(listener);

    // 设置超时清理
    _timeouts[operationId]?.cancel();
    _timeouts[operationId] = Timer(
      Duration(seconds: listenerTimeoutSeconds),
      () {
        _cleanupOperation(operationId);
        debugPrint('[QueryResultEventBus] 监听器超时清理: $operationId');
      },
    );

    debugPrint('[QueryResultEventBus] 订阅操作: $operationId, 监听器数量: ${_operationListeners[operationId]?.length}');
  }

  /// 取消特定操作的订阅
  void unsubscribe(String operationId) {
    _cleanupOperation(operationId);
    debugPrint('[QueryResultEventBus] 取消订阅: $operationId');
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 事件发布
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 发布查询结果事件
  void publish(QueryResultEvent event) {
    debugPrint('[QueryResultEventBus] 发布事件: ${event.operationId}');

    // 通知全局监听器
    for (final listener in _globalListeners) {
      _safeInvoke(listener, event);
    }

    // 通知特定操作的监听器
    final operationListeners = _operationListeners[event.operationId];
    if (operationListeners != null) {
      debugPrint('[QueryResultEventBus] 通知${operationListeners.length}个操作监听器');
      for (final listener in operationListeners) {
        _safeInvoke(listener, event);
      }

      // 一次性订阅，通知后清理
      _cleanupOperation(event.operationId);
    }
  }

  /// 发布查询结果（便捷方法）
  void publishResult(String operationId, ExecutionResult result) {
    publish(QueryResultEvent(
      operationId: operationId,
      result: result,
    ));
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 内部方法
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 安全调用监听器（异常隔离）
  void _safeInvoke(QueryResultListener listener, QueryResultEvent event) {
    try {
      listener(event);
    } catch (e, stackTrace) {
      debugPrint('[QueryResultEventBus] 监听器回调异常: $e');
      debugPrint('[QueryResultEventBus] 堆栈: $stackTrace');
    }
  }

  /// 清理特定操作的监听器
  void _cleanupOperation(String operationId) {
    _operationListeners.remove(operationId);
    _timeouts[operationId]?.cancel();
    _timeouts.remove(operationId);
  }

  /// 清理所有监听器
  void clear() {
    _globalListeners.clear();
    _operationListeners.clear();
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _timeouts.clear();
    debugPrint('[QueryResultEventBus] 已清理所有监听器');
  }

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    return {
      'globalListeners': _globalListeners.length,
      'operationListeners': _operationListeners.length,
      'activeTimeouts': _timeouts.length,
    };
  }
}
