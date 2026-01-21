/// 结果缓冲器
///
/// 暂存后台执行完成的操作结果，供时机判断器决定何时通知用户
///
/// 功能：
/// - 缓存执行结果并标记状态（pending/notified/expired/suppressed）
/// - 根据操作类型和金额计算优先级
/// - 30秒过期清理
/// - 最多缓存10条结果
/// - 提供上下文摘要供 LLM 使用
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// 结果优先级
enum ResultPriority {
  /// 关键优先级（删除操作、大额交易 >1000）
  critical,

  /// 普通优先级
  normal,

  /// 低优先级
  low,
}

/// 结果状态
enum ResultStatus {
  /// 待通知
  pending,

  /// 已通知
  notified,

  /// 已过期
  expired,

  /// 已压制（用户取消等）
  suppressed,
}

/// 缓冲的执行结果
class BufferedResult {
  /// 唯一ID
  final String id;

  /// 执行结果
  final ExecutionResult executionResult;

  /// 优先级
  final ResultPriority priority;

  /// 状态
  ResultStatus status;

  /// 创建时间
  final DateTime createdAt;

  /// 操作描述（用于通知文本生成）
  final String description;

  /// 金额（如果适用）
  final double? amount;

  BufferedResult({
    required this.id,
    required this.executionResult,
    required this.priority,
    required this.description,
    this.amount,
  })  : status = ResultStatus.pending,
        createdAt = DateTime.now();

  /// 是否已过期（超过30秒）
  bool get isExpired {
    final elapsed = DateTime.now().difference(createdAt);
    return elapsed.inSeconds >= 30;
  }

  /// 是否可通知（pending状态且未过期）
  bool get canNotify => status == ResultStatus.pending && !isExpired;

  @override
  String toString() => 'BufferedResult(id: $id, priority: $priority, status: $status, desc: $description)';
}

/// 结果缓冲器
class ResultBuffer {
  /// 缓冲区最大容量
  static const int maxCapacity = 10;

  /// 结果过期时间（秒）
  static const int expirationSeconds = 30;

  /// 缓冲区
  final List<BufferedResult> _buffer = [];

  /// 过期清理计时器
  Timer? _cleanupTimer;

  /// ID计数器
  int _idCounter = 0;

  ResultBuffer() {
    _startCleanupTimer();
  }

  /// 获取待通知结果数量
  int get pendingCount => _buffer.where((r) => r.canNotify).length;

  /// 是否有待通知结果
  bool get hasPendingResults => pendingCount > 0;

  /// 获取所有待通知结果（按优先级排序）
  List<BufferedResult> get pendingResults {
    final pending = _buffer.where((r) => r.canNotify).toList();
    // 按优先级排序：critical > normal > low
    pending.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return pending;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 核心操作
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 添加执行结果到缓冲区
  BufferedResult add({
    required ExecutionResult result,
    required String description,
    double? amount,
    OperationType? operationType,
  }) {
    // 计算优先级
    final priority = _calculatePriority(
      operationType: operationType,
      amount: amount,
    );

    // 创建缓冲结果
    final bufferedResult = BufferedResult(
      id: 'result_${++_idCounter}',
      executionResult: result,
      priority: priority,
      description: description,
      amount: amount,
    );

    // 容量检查：如果已满，移除最旧的已通知/过期结果
    if (_buffer.length >= maxCapacity) {
      _evictOldest();
    }

    _buffer.add(bufferedResult);
    debugPrint('[ResultBuffer] 添加结果: $bufferedResult, 当前数量: ${_buffer.length}');

    return bufferedResult;
  }

  /// 标记结果为已通知
  void markNotified(String id) {
    final result = _findById(id);
    if (result != null) {
      result.status = ResultStatus.notified;
      debugPrint('[ResultBuffer] 标记已通知: $id');
    }
  }

  /// 标记结果为已压制
  void markSuppressed(String id) {
    final result = _findById(id);
    if (result != null) {
      result.status = ResultStatus.suppressed;
      debugPrint('[ResultBuffer] 标记已压制: $id');
    }
  }

  /// 压制所有待通知结果
  void suppressAll() {
    for (final result in _buffer) {
      if (result.status == ResultStatus.pending) {
        result.status = ResultStatus.suppressed;
      }
    }
    debugPrint('[ResultBuffer] 压制所有待通知结果');
  }

  /// 获取上下文摘要（用于 LLM）
  String? getSummaryForContext() {
    final pending = pendingResults;
    if (pending.isEmpty) return null;

    final lines = <String>['【后台执行结果】'];
    for (final result in pending) {
      final amountStr = result.amount != null ? ' ${result.amount}元' : '';
      lines.add('- ${result.description}$amountStr');
    }

    return lines.join('\n');
  }

  /// 清空缓冲区
  void clear() {
    _buffer.clear();
    debugPrint('[ResultBuffer] 缓冲区已清空');
  }

  /// 释放资源
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _buffer.clear();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 内部方法
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// 计算优先级
  ResultPriority _calculatePriority({
    OperationType? operationType,
    double? amount,
  }) {
    // 删除操作 → critical
    if (operationType == OperationType.delete) {
      return ResultPriority.critical;
    }

    // 大额交易（>1000）→ critical
    if (amount != null && amount > 1000) {
      return ResultPriority.critical;
    }

    // 默认 → normal
    return ResultPriority.normal;
  }

  /// 根据ID查找结果
  BufferedResult? _findById(String id) {
    try {
      return _buffer.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 移除最旧的已处理结果
  void _evictOldest() {
    // 优先移除已通知/过期/压制的结果
    final removable = _buffer.where((r) => r.status != ResultStatus.pending).toList();
    if (removable.isNotEmpty) {
      final oldest = removable.first;
      _buffer.remove(oldest);
      debugPrint('[ResultBuffer] 移除旧结果: ${oldest.id}');
      return;
    }

    // 如果没有已处理的，移除最旧的pending（不太可能发生）
    if (_buffer.isNotEmpty) {
      final oldest = _buffer.first;
      _buffer.remove(oldest);
      debugPrint('[ResultBuffer] 强制移除最旧结果: ${oldest.id}');
    }
  }

  /// 启动过期清理计时器
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _cleanupExpired(),
    );
  }

  /// 清理过期结果
  void _cleanupExpired() {
    final expired = _buffer.where((r) => r.isExpired).toList();
    for (final result in expired) {
      result.status = ResultStatus.expired;
    }

    // 移除过期和已通知的结果
    final toRemove = _buffer
        .where((r) => r.status == ResultStatus.expired || r.status == ResultStatus.notified)
        .toList();

    if (toRemove.isNotEmpty) {
      for (final result in toRemove) {
        _buffer.remove(result);
      }
      debugPrint('[ResultBuffer] 清理过期/已通知结果: ${toRemove.length}个');
    }
  }
}
