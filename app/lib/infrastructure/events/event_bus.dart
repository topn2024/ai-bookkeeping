/// Event Bus
///
/// 事件总线实现，提供发布/订阅机制。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/events/domain_event.dart';

/// 事件总线
///
/// 职责：
/// - 管理事件订阅者
/// - 发布事件到订阅者
/// - 支持同步和异步事件处理
class EventBus {
  /// 单例实例
  static EventBus? _instance;
  static EventBus get instance => _instance ??= EventBus._();

  EventBus._();

  /// 允许创建新实例（用于测试）
  factory EventBus.create() => EventBus._();

  /// 事件处理器映射
  /// Key: 事件类型名称
  /// Value: 处理器列表
  final Map<String, List<IEventHandler>> _handlers = {};

  /// 通用订阅者（订阅所有事件）
  final List<IEventSubscriber> _subscribers = [];

  /// 事件流控制器
  final StreamController<DomainEvent> _streamController =
      StreamController<DomainEvent>.broadcast();

  /// 事件流
  Stream<DomainEvent> get stream => _streamController.stream;

  /// 是否启用日志
  bool enableLogging = false;

  // ==================== 订阅管理 ====================

  /// 注册事件处理器
  void register<T extends DomainEvent>(IEventHandler<T> handler) {
    final eventType = T.toString();
    _handlers.putIfAbsent(eventType, () => []);
    _handlers[eventType]!.add(handler);
    _log('注册处理器: $eventType');
  }

  /// 注册事件回调
  void on<T extends DomainEvent>(EventCallback<T> callback) {
    register<T>(EventHandlerWrapper<T>(callback));
  }

  /// 注销事件处理器
  void unregister<T extends DomainEvent>(IEventHandler<T> handler) {
    final eventType = T.toString();
    _handlers[eventType]?.remove(handler);
    _log('注销处理器: $eventType');
  }

  /// 注册订阅者
  void subscribe(IEventSubscriber subscriber) {
    _subscribers.add(subscriber);
    _log('注册订阅者: ${subscriber.runtimeType}');
  }

  /// 注销订阅者
  void unsubscribe(IEventSubscriber subscriber) {
    _subscribers.remove(subscriber);
    _log('注销订阅者: ${subscriber.runtimeType}');
  }

  /// 清除所有处理器和订阅者
  void clear() {
    _handlers.clear();
    _subscribers.clear();
    _log('已清除所有处理器和订阅者');
  }

  // ==================== 事件发布 ====================

  /// 发布事件
  Future<void> publish(DomainEvent event) async {
    _log('发布事件: ${event.eventName} (${event.id})');

    // 添加到事件流
    _streamController.add(event);

    // 调用特定类型的处理器
    await _invokeHandlers(event);

    // 调用通用订阅者
    await _invokeSubscribers(event);
  }

  /// 同步发布事件（不等待处理完成）
  void publishSync(DomainEvent event) {
    _log('同步发布事件: ${event.eventName} (${event.id})');

    // 添加到事件流
    _streamController.add(event);

    // 异步调用处理器（不等待）
    _invokeHandlers(event);
    _invokeSubscribers(event);
  }

  /// 批量发布事件
  Future<void> publishAll(List<DomainEvent> events) async {
    for (final event in events) {
      await publish(event);
    }
  }

  // ==================== 事件流订阅 ====================

  /// 订阅特定类型的事件流
  Stream<T> ofType<T extends DomainEvent>() {
    return stream.where((event) => event is T).cast<T>();
  }

  /// 订阅事件流并添加处理器
  StreamSubscription<T> listen<T extends DomainEvent>(
    void Function(T event) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return ofType<T>().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  // ==================== 私有方法 ====================

  /// 调用事件处理器
  Future<void> _invokeHandlers(DomainEvent event) async {
    final eventType = event.runtimeType.toString();
    final handlers = _handlers[eventType];

    if (handlers == null || handlers.isEmpty) {
      _log('没有找到处理器: $eventType');
      return;
    }

    for (final handler in handlers) {
      try {
        if (handler.canHandle(event)) {
          await handler.handle(event);
          _log('处理器执行完成: ${handler.runtimeType}');
        }
      } catch (e, stackTrace) {
        _logError('处理器执行失败: ${handler.runtimeType}', e, stackTrace);
      }
    }
  }

  /// 调用订阅者
  Future<void> _invokeSubscribers(DomainEvent event) async {
    for (final subscriber in _subscribers) {
      try {
        if (subscriber.subscribedEvents.contains(event.runtimeType) ||
            subscriber.subscribedEvents.isEmpty) {
          await subscriber.onEvent(event);
          _log('订阅者处理完成: ${subscriber.runtimeType}');
        }
      } catch (e, stackTrace) {
        _logError('订阅者处理失败: ${subscriber.runtimeType}', e, stackTrace);
      }
    }
  }

  /// 记录日志
  void _log(String message) {
    if (enableLogging) {
      debugPrint('[EventBus] $message');
    }
  }

  /// 记录错误日志
  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('[EventBus] 错误: $message');
    debugPrint('[EventBus] $error');
    debugPrint('[EventBus] $stackTrace');
  }

  /// 释放资源
  void dispose() {
    _streamController.close();
    clear();
  }
}

/// 事件存储接口
abstract class IEventStore {
  /// 保存事件
  Future<void> save(DomainEvent event);

  /// 获取聚合根的所有事件
  Future<List<DomainEvent>> getEventsForAggregate(String aggregateId);

  /// 获取指定时间范围的事件
  Future<List<DomainEvent>> getEventsByTimeRange(DateTime start, DateTime end);

  /// 获取指定类型的事件
  Future<List<DomainEvent>> getEventsByType(String eventName);
}

/// 内存事件存储（用于开发和测试）
class InMemoryEventStore implements IEventStore {
  final List<DomainEvent> _events = [];
  final int _maxSize;

  InMemoryEventStore({int maxSize = 1000}) : _maxSize = maxSize;

  @override
  Future<void> save(DomainEvent event) async {
    _events.add(event);
    _trimEvents();
  }

  @override
  Future<List<DomainEvent>> getEventsForAggregate(String aggregateId) async {
    return _events.where((e) => e.aggregateId == aggregateId).toList();
  }

  @override
  Future<List<DomainEvent>> getEventsByTimeRange(
    DateTime start,
    DateTime end,
  ) async {
    return _events
        .where((e) =>
            e.occurredAt.isAfter(start) && e.occurredAt.isBefore(end))
        .toList();
  }

  @override
  Future<List<DomainEvent>> getEventsByType(String eventName) async {
    return _events.where((e) => e.eventName == eventName).toList();
  }

  void _trimEvents() {
    while (_events.length > _maxSize) {
      _events.removeAt(0);
    }
  }

  void clear() {
    _events.clear();
  }
}

/// 事件持久化装饰器
class PersistentEventBus {
  final EventBus _eventBus;
  final IEventStore _eventStore;

  PersistentEventBus({
    EventBus? eventBus,
    required IEventStore eventStore,
  })  : _eventBus = eventBus ?? EventBus.instance,
        _eventStore = eventStore;

  /// 发布并持久化事件
  Future<void> publish(DomainEvent event) async {
    await _eventStore.save(event);
    await _eventBus.publish(event);
  }

  /// 获取事件总线
  EventBus get eventBus => _eventBus;

  /// 获取事件存储
  IEventStore get eventStore => _eventStore;
}
