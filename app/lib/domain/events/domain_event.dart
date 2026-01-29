/// Domain Event
///
/// 领域事件基类，用于实现事件驱动架构。
/// 所有领域事件都应该继承此类。
library;

import 'package:uuid/uuid.dart';

/// 领域事件基类
///
/// 职责：
/// - 定义事件的基本属性
/// - 提供事件元数据
abstract class DomainEvent {
  /// 事件 ID
  final String id;

  /// 事件发生时间
  final DateTime occurredAt;

  /// 聚合根 ID（可选）
  final String? aggregateId;

  /// 聚合根类型（可选）
  final String? aggregateType;

  /// 事件版本
  final int version;

  /// 事件元数据
  final Map<String, dynamic> metadata;

  DomainEvent({
    String? id,
    DateTime? occurredAt,
    this.aggregateId,
    this.aggregateType,
    this.version = 1,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        occurredAt = occurredAt ?? DateTime.now(),
        metadata = metadata ?? {};

  /// 事件名称
  String get eventName;

  /// 事件数据
  Map<String, dynamic> get eventData;

  /// 转换为 Map
  Map<String, dynamic> toMap() => {
        'id': id,
        'eventName': eventName,
        'occurredAt': occurredAt.toIso8601String(),
        'aggregateId': aggregateId,
        'aggregateType': aggregateType,
        'version': version,
        'data': eventData,
        'metadata': metadata,
      };

  @override
  String toString() => 'DomainEvent($eventName, id: $id)';
}

/// 事件处理器接口
abstract class IEventHandler<T extends DomainEvent> {
  /// 处理事件
  Future<void> handle(T event);

  /// 是否可以处理该事件
  bool canHandle(DomainEvent event) => event is T;
}

/// 事件订阅者接口
abstract class IEventSubscriber {
  /// 获取订阅的事件类型
  List<Type> get subscribedEvents;

  /// 处理事件
  Future<void> onEvent(DomainEvent event);
}

/// 通用事件处理器
typedef EventCallback<T extends DomainEvent> = Future<void> Function(T event);

/// 事件处理器包装
class EventHandlerWrapper<T extends DomainEvent> implements IEventHandler<T> {
  final EventCallback<T> _callback;

  EventHandlerWrapper(this._callback);

  @override
  Future<void> handle(T event) => _callback(event);

  @override
  bool canHandle(DomainEvent event) => event is T;
}
