import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ai_bookkeeping/services/voice/agent/action_auto_registry.dart';
import 'package:ai_bookkeeping/services/voice/agent/action_registry.dart';
import 'package:ai_bookkeeping/core/contracts/i_database_service.dart';
import 'package:ai_bookkeeping/services/voice_navigation_service.dart';

// Mock classes
class MockDatabaseService extends Mock implements IDatabaseService {}
class MockNavigationService extends Mock implements VoiceNavigationService {}

void main() {
  group('ActionDependencies', () {
    late MockDatabaseService mockDb;
    late MockNavigationService mockNav;

    setUp(() {
      mockDb = MockDatabaseService();
      mockNav = MockNavigationService();
    });

    test('should create with required fields', () {
      final deps = ActionDependencies(
        databaseService: mockDb,
        navigationService: mockNav,
      );

      expect(deps.databaseService, mockDb);
      expect(deps.navigationService, mockNav);
      expect(deps.onNavigate, isNull);
      expect(deps.onConfigChange, isNull);
    });

    test('should create with all fields', () {
      void onNav(String route) {}
      Future<void> onConfig(String key, dynamic value) async {}

      final deps = ActionDependencies(
        databaseService: mockDb,
        navigationService: mockNav,
        onNavigate: onNav,
        onConfigChange: onConfig,
      );

      expect(deps.databaseService, mockDb);
      expect(deps.navigationService, mockNav);
      expect(deps.onNavigate, isNotNull);
      expect(deps.onConfigChange, isNotNull);
    });
  });

  group('ActionProviderMeta', () {
    test('should create with required fields', () {
      final meta = ActionProviderMeta(
        id: 'test.action',
        category: 'test',
        description: 'Test action',
        factory: (deps) => _TestAction(),
      );

      expect(meta.id, 'test.action');
      expect(meta.category, 'test');
      expect(meta.description, 'Test action');
      expect(meta.lazy, isFalse);
      expect(meta.dependencies, isEmpty);
    });

    test('should create with all fields', () {
      final meta = ActionProviderMeta(
        id: 'test.action',
        category: 'test',
        description: 'Test action',
        factory: (deps) => _TestAction(),
        lazy: true,
        dependencies: ['other.action'],
      );

      expect(meta.lazy, isTrue);
      expect(meta.dependencies, ['other.action']);
    });
  });

  group('ActionAutoRegistry', () {
    late ActionAutoRegistry registry;
    late MockDatabaseService mockDb;
    late MockNavigationService mockNav;
    late ActionDependencies deps;

    setUp(() {
      registry = ActionAutoRegistry.instance;
      registry.reset(); // Reset for each test

      mockDb = MockDatabaseService();
      mockNav = MockNavigationService();
      deps = ActionDependencies(
        databaseService: mockDb,
        navigationService: mockNav,
      );
    });

    tearDown(() {
      registry.reset();
    });

    test('should be singleton', () {
      final instance1 = ActionAutoRegistry.instance;
      final instance2 = ActionAutoRegistry.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should register provider', () {
      final meta = ActionProviderMeta(
        id: 'test.action',
        category: 'test',
        description: 'Test action',
        factory: (deps) => _TestAction(),
      );

      registry.registerProvider(meta);

      expect(registry.getByCategory('test').length, 1);
      expect(registry.getByCategory('test').first.id, 'test.action');
    });

    test('should skip duplicate providers', () {
      final meta = ActionProviderMeta(
        id: 'test.action',
        category: 'test',
        description: 'Test action',
        factory: (deps) => _TestAction(),
      );

      registry.registerProvider(meta);
      registry.registerProvider(meta); // Duplicate

      expect(registry.getByCategory('test').length, 1);
    });

    test('should register multiple providers', () {
      registry.registerProviders([
        ActionProviderMeta(
          id: 'test.action1',
          category: 'test',
          description: 'Test 1',
          factory: (deps) => _TestAction(),
        ),
        ActionProviderMeta(
          id: 'test.action2',
          category: 'test',
          description: 'Test 2',
          factory: (deps) => _TestAction(),
        ),
        ActionProviderMeta(
          id: 'other.action',
          category: 'other',
          description: 'Other',
          factory: (deps) => _TestAction(),
        ),
      ]);

      expect(registry.getByCategory('test').length, 2);
      expect(registry.getByCategory('other').length, 1);
    });

    test('should return categories', () {
      registry.registerProviders([
        ActionProviderMeta(
          id: 'cat1.action',
          category: 'cat1',
          description: 'Cat 1',
          factory: (deps) => _TestAction(),
        ),
        ActionProviderMeta(
          id: 'cat2.action',
          category: 'cat2',
          description: 'Cat 2',
          factory: (deps) => _TestAction(),
        ),
      ]);

      final categories = registry.categories;
      expect(categories.length, 2);
      expect(categories, contains('cat1'));
      expect(categories, contains('cat2'));
    });

    test('should return statistics', () {
      registry.registerProviders([
        ActionProviderMeta(
          id: 'cat1.action1',
          category: 'cat1',
          description: 'Cat 1-1',
          factory: (deps) => _TestAction(),
        ),
        ActionProviderMeta(
          id: 'cat1.action2',
          category: 'cat1',
          description: 'Cat 1-2',
          factory: (deps) => _TestAction(),
        ),
        ActionProviderMeta(
          id: 'cat2.action',
          category: 'cat2',
          description: 'Cat 2',
          factory: (deps) => _TestAction(),
        ),
      ]);

      final stats = registry.statistics;
      expect(stats['cat1'], 2);
      expect(stats['cat2'], 1);
    });

    test('should register all and create actions', () {
      final actionRegistry = ActionRegistry.instance;

      registry.registerProviders([
        ActionProviderMeta(
          id: 'test.action',
          category: 'test',
          description: 'Test',
          factory: (deps) => _TestAction(),
        ),
      ]);

      registry.registerAll(deps);

      // Verify action was registered in ActionRegistry
      final action = actionRegistry.findById('test.action');
      expect(action, isNotNull);
      expect(action!.id, 'test.action');
    });

    test('should handle dependencies in topological order', () {
      final executionOrder = <String>[];

      registry.registerProviders([
        ActionProviderMeta(
          id: 'child.action',
          category: 'test',
          description: 'Child',
          dependencies: ['parent.action'],
          factory: (deps) {
            executionOrder.add('child');
            return _TestAction(id: 'child.action');
          },
        ),
        ActionProviderMeta(
          id: 'parent.action',
          category: 'test',
          description: 'Parent',
          factory: (deps) {
            executionOrder.add('parent');
            return _TestAction(id: 'parent.action');
          },
        ),
      ]);

      registry.registerAll(deps);

      // Parent should be registered before child
      expect(executionOrder.indexOf('parent'), lessThan(executionOrder.indexOf('child')));
    });

    test('should only register once', () {
      var registerCount = 0;

      registry.registerProviders([
        ActionProviderMeta(
          id: 'test.action',
          category: 'test',
          description: 'Test',
          factory: (deps) {
            registerCount++;
            return _TestAction();
          },
        ),
      ]);

      registry.registerAll(deps);
      registry.registerAll(deps); // Second call should be skipped

      expect(registerCount, 1);
    });

    test('reset should clear all state', () {
      registry.registerProviders([
        ActionProviderMeta(
          id: 'test.action',
          category: 'test',
          description: 'Test',
          factory: (deps) => _TestAction(),
        ),
      ]);

      registry.registerAll(deps);
      registry.reset();

      expect(registry.categories, isEmpty);
      expect(registry.statistics, isEmpty);
    });
  });

  group('Built-in ActionProviders', () {
    test('transactionActionProviders should have correct providers', () {
      expect(transactionActionProviders.length, 5);

      final ids = transactionActionProviders.map((p) => p.id).toList();
      expect(ids, contains('transaction.expense'));
      expect(ids, contains('transaction.income'));
      expect(ids, contains('transaction.query'));
      expect(ids, contains('transaction.modify'));
      expect(ids, contains('transaction.delete'));
    });

    test('navigationActionProviders should have correct providers', () {
      expect(navigationActionProviders.length, 1);
      expect(navigationActionProviders.first.id, 'navigation.page');
    });

    test('all providers should have correct category', () {
      for (final provider in transactionActionProviders) {
        expect(provider.category, 'transaction');
      }

      for (final provider in navigationActionProviders) {
        expect(provider.category, 'navigation');
      }
    });
  });

  group('initializeActionProviders', () {
    setUp(() {
      ActionAutoRegistry.instance.reset();
    });

    tearDown(() {
      ActionAutoRegistry.instance.reset();
    });

    test('should register all built-in providers', () {
      initializeActionProviders();

      final registry = ActionAutoRegistry.instance;
      final stats = registry.statistics;

      expect(stats['transaction'], 5);
      expect(stats['navigation'], 1);
    });
  });
}

/// Test action for unit tests
class _TestAction extends Action {
  final String _id;

  _TestAction({String id = 'test.action'}) : _id = id;

  @override
  String get id => _id;

  @override
  String get name => 'Test Action';

  @override
  String get description => 'A test action';

  @override
  List<String> get triggerPatterns => ['test'];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    return ActionResult.success(
      responseText: 'Test success',
      actionId: id,
    );
  }
}
