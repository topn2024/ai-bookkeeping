import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/domain/events/events.dart';
import 'package:ai_bookkeeping/infrastructure/events/event_bus.dart';

void main() {
  late EventBus eventBus;

  setUp(() {
    eventBus = EventBus.create();
  });

  tearDown(() {
    eventBus.dispose();
  });

  group('EventBus', () {
    test('publishes event to registered handler', () async {
      var handlerCalled = false;
      final handler = _TestEventHandler((event) async {
        handlerCalled = true;
      });

      eventBus.register<_TestEvent>(handler);
      await eventBus.publish(_TestEvent());

      expect(handlerCalled, isTrue);
    });

    test('publishes event to callback registered with on()', () async {
      var received = false;

      eventBus.on<_TestEvent>((event) async {
        received = true;
      });

      await eventBus.publish(_TestEvent());

      expect(received, isTrue);
    });

    test('does not call handler after unregister', () async {
      var callCount = 0;
      final handler = _TestEventHandler((event) async {
        callCount++;
      });

      eventBus.register<_TestEvent>(handler);
      await eventBus.publish(_TestEvent());
      expect(callCount, 1);

      eventBus.unregister<_TestEvent>(handler);
      await eventBus.publish(_TestEvent());
      expect(callCount, 1);
    });

    test('subscriber receives events', () async {
      var receivedEvents = <DomainEvent>[];
      final subscriber = _TestSubscriber(
        events: [_TestEvent],
        onEvent: (event) async {
          receivedEvents.add(event);
        },
      );

      eventBus.subscribe(subscriber);
      await eventBus.publish(_TestEvent());
      await eventBus.publish(_AnotherTestEvent());

      expect(receivedEvents.length, 1);
      expect(receivedEvents.first, isA<_TestEvent>());
    });

    test('stream emits published events', () async {
      final events = <DomainEvent>[];
      final subscription = eventBus.stream.listen((event) {
        events.add(event);
      });

      await eventBus.publish(_TestEvent());
      await eventBus.publish(_AnotherTestEvent());

      await Future.delayed(Duration(milliseconds: 10));

      expect(events.length, 2);

      await subscription.cancel();
    });

    test('ofType filters events by type', () async {
      final testEvents = <_TestEvent>[];
      final subscription = eventBus.ofType<_TestEvent>().listen((event) {
        testEvents.add(event);
      });

      await eventBus.publish(_TestEvent());
      await eventBus.publish(_AnotherTestEvent());
      await eventBus.publish(_TestEvent());

      await Future.delayed(Duration(milliseconds: 10));

      expect(testEvents.length, 2);

      await subscription.cancel();
    });

    test('publishAll publishes multiple events', () async {
      var count = 0;
      eventBus.on<_TestEvent>((event) async {
        count++;
      });

      await eventBus.publishAll([
        _TestEvent(),
        _TestEvent(),
        _TestEvent(),
      ]);

      expect(count, 3);
    });

    test('clear removes all handlers and subscribers', () async {
      var handlerCalled = false;
      eventBus.on<_TestEvent>((event) async {
        handlerCalled = true;
      });

      eventBus.clear();
      await eventBus.publish(_TestEvent());

      expect(handlerCalled, isFalse);
    });
  });

  group('InMemoryEventStore', () {
    late InMemoryEventStore store;

    setUp(() {
      store = InMemoryEventStore(maxSize: 10);
    });

    test('saves and retrieves events', () async {
      final event = _TestEvent();
      await store.save(event);

      final events = await store.getEventsForAggregate(event.aggregateId!);

      expect(events.length, 1);
      expect(events.first.id, event.id);
    });

    test('retrieves events by type', () async {
      await store.save(_TestEvent());
      await store.save(_AnotherTestEvent());
      await store.save(_TestEvent());

      final events = await store.getEventsByType('TestEvent');

      expect(events.length, 2);
    });

    test('retrieves events by time range', () async {
      final now = DateTime.now();
      await store.save(_TestEvent());

      final events = await store.getEventsByTimeRange(
        now.subtract(Duration(minutes: 1)),
        now.add(Duration(minutes: 1)),
      );

      expect(events.length, 1);
    });

    test('trims events when exceeding max size', () async {
      for (int i = 0; i < 15; i++) {
        await store.save(_TestEvent());
      }

      final events = await store.getEventsByType('TestEvent');

      expect(events.length, 10);
    });
  });
}

class _TestEvent extends DomainEvent {
  _TestEvent()
      : super(
          aggregateId: 'test_aggregate',
          aggregateType: 'Test',
        );

  @override
  String get eventName => 'TestEvent';

  @override
  Map<String, dynamic> get eventData => {'test': true};
}

class _AnotherTestEvent extends DomainEvent {
  @override
  String get eventName => 'AnotherTestEvent';

  @override
  Map<String, dynamic> get eventData => {};
}

class _TestEventHandler implements IEventHandler<_TestEvent> {
  final Future<void> Function(_TestEvent) _callback;

  _TestEventHandler(this._callback);

  @override
  Future<void> handle(_TestEvent event) => _callback(event);

  @override
  bool canHandle(DomainEvent event) => event is _TestEvent;
}

class _TestSubscriber implements IEventSubscriber {
  final List<Type> _events;
  final Future<void> Function(DomainEvent) _onEvent;

  _TestSubscriber({
    required List<Type> events,
    required Future<void> Function(DomainEvent) onEvent,
  })  : _events = events,
        _onEvent = onEvent;

  @override
  List<Type> get subscribedEvents => _events;

  @override
  Future<void> onEvent(DomainEvent event) => _onEvent(event);
}
