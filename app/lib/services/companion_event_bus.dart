import 'dart:async';

import 'package:flutter/foundation.dart';

import 'companion_copywriting_service.dart';

/// 伙伴化事件总线
///
/// 功能：
/// 1. 统一事件分发与订阅
/// 2. 消息频率控制（每日≤3条）
/// 3. 优先级队列管理
/// 4. 事件去重与合并
class CompanionEventBus {
  static final CompanionEventBus _instance = CompanionEventBus._internal();
  factory CompanionEventBus() => _instance;
  CompanionEventBus._internal();

  final _eventController = StreamController<CompanionEvent>.broadcast();
  final _messageController = StreamController<CompanionMessage>.broadcast();
  final MessageFrequencyController _frequencyController = MessageFrequencyController();
  final _pendingEvents = <CompanionEvent>[];
  final _eventHandlers = <CompanionTrigger, List<EventHandler>>{};

  bool _isProcessing = false;

  /// 事件流
  Stream<CompanionEvent> get eventStream => _eventController.stream;

  /// 消息流（已过滤和处理）
  Stream<CompanionMessage> get messageStream => _messageController.stream;

  /// 发布事件
  Future<void> publish(CompanionEvent event) async {
    debugPrint('CompanionEventBus: Publishing event ${event.trigger}');

    // 添加到待处理队列
    _pendingEvents.add(event);

    // 按优先级排序
    _pendingEvents.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    // 处理事件
    await _processEvents();
  }

  /// 批量发布事件
  Future<void> publishAll(List<CompanionEvent> events) async {
    _pendingEvents.addAll(events);
    _pendingEvents.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    await _processEvents();
  }

  /// 注册事件处理器
  void registerHandler(CompanionTrigger trigger, EventHandler handler) {
    _eventHandlers.putIfAbsent(trigger, () => []).add(handler);
  }

  /// 移除事件处理器
  void unregisterHandler(CompanionTrigger trigger, EventHandler handler) {
    _eventHandlers[trigger]?.remove(handler);
  }

  /// 处理事件队列
  Future<void> _processEvents() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_pendingEvents.isNotEmpty) {
        final event = _pendingEvents.removeAt(0);

        // 检查频率限制
        if (!await _frequencyController.canSendMessage(event.userId)) {
          debugPrint('CompanionEventBus: Frequency limit reached for ${event.userId}');
          continue;
        }

        // 发送到事件流
        _eventController.add(event);

        // 调用注册的处理器
        final handlers = _eventHandlers[event.trigger] ?? [];
        for (final handler in handlers) {
          try {
            final message = await handler(event);
            if (message != null) {
              // 记录消息发送
              await _frequencyController.recordMessage(event.userId, message);
              // 发送到消息流
              _messageController.add(message);
            }
          } catch (e) {
            debugPrint('CompanionEventBus: Handler error: $e');
          }
        }

        // 短暂延迟避免消息堆积
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// 清空待处理事件
  void clearPendingEvents() {
    _pendingEvents.clear();
  }

  /// 释放资源
  void dispose() {
    _eventController.close();
    _messageController.close();
    _pendingEvents.clear();
    _eventHandlers.clear();
  }
}

/// 事件处理器类型
typedef EventHandler = Future<CompanionMessage?> Function(CompanionEvent event);

/// 伙伴化事件
class CompanionEvent {
  final String id;
  final CompanionTrigger trigger;
  final Map<String, dynamic>? data;
  final String? userId;
  final DateTime timestamp;
  final MessagePriority priority;

  CompanionEvent({
    String? id,
    required this.trigger,
    this.data,
    this.userId,
    DateTime? timestamp,
    this.priority = MessagePriority.medium,
  })  : id = id ?? '${trigger.name}_${DateTime.now().millisecondsSinceEpoch}',
        timestamp = timestamp ?? DateTime.now();
}

// ==================== 消息频率控制器 ====================

/// 消息频率控制器
class MessageFrequencyController {
  final int maxDailyMessages;
  final int maxHourlyMessages;
  final Duration minInterval;

  final Map<String, _UserMessageHistory> _history = {};

  MessageFrequencyController({
    this.maxDailyMessages = 3,
    this.maxHourlyMessages = 2,
    this.minInterval = const Duration(minutes: 30),
  });

  /// 检查是否可以发送消息
  Future<bool> canSendMessage(String? userId) async {
    final history = _getOrCreateHistory(userId);
    final now = DateTime.now();

    // 清理过期记录
    history.cleanExpired(now);

    // 检查每日限制
    if (history.dailyCount >= maxDailyMessages) {
      debugPrint('FrequencyController: Daily limit reached ($maxDailyMessages)');
      return false;
    }

    // 检查每小时限制
    if (history.hourlyCount >= maxHourlyMessages) {
      debugPrint('FrequencyController: Hourly limit reached ($maxHourlyMessages)');
      return false;
    }

    // 检查最小间隔
    if (history.lastMessageTime != null) {
      final elapsed = now.difference(history.lastMessageTime!);
      if (elapsed < minInterval) {
        debugPrint('FrequencyController: Min interval not met');
        return false;
      }
    }

    return true;
  }

  /// 记录消息发送
  Future<void> recordMessage(String? userId, CompanionMessage message) async {
    final history = _getOrCreateHistory(userId);
    history.addMessage(message);
  }

  /// 获取今日剩余消息数
  int getRemainingDailyMessages(String? userId) {
    final history = _getOrCreateHistory(userId);
    history.cleanExpired(DateTime.now());
    return maxDailyMessages - history.dailyCount;
  }

  /// 重置用户历史
  void resetHistory(String? userId) {
    final key = userId ?? '_default';
    _history.remove(key);
  }

  _UserMessageHistory _getOrCreateHistory(String? userId) {
    final key = userId ?? '_default';
    return _history.putIfAbsent(key, () => _UserMessageHistory());
  }
}

class _UserMessageHistory {
  final List<_MessageRecord> _records = [];
  DateTime? lastMessageTime;

  int get dailyCount {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return _records.where((r) => r.timestamp.isAfter(startOfDay)).length;
  }

  int get hourlyCount {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return _records.where((r) => r.timestamp.isAfter(oneHourAgo)).length;
  }

  void addMessage(CompanionMessage message) {
    _records.add(_MessageRecord(
      messageId: message.id,
      timestamp: DateTime.now(),
      trigger: message.trigger,
    ));
    lastMessageTime = DateTime.now();
  }

  void cleanExpired(DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    _records.removeWhere((r) => r.timestamp.isBefore(yesterday));
  }
}

class _MessageRecord {
  final String messageId;
  final DateTime timestamp;
  final CompanionTrigger trigger;

  _MessageRecord({
    required this.messageId,
    required this.timestamp,
    required this.trigger,
  });
}
