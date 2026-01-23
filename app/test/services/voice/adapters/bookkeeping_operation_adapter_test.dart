import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/adapters/bookkeeping_operation_adapter.dart';
import 'package:ai_bookkeeping/services/voice/smart_intent_recognizer.dart';
import 'package:ai_bookkeeping/services/voice_navigation_service.dart';
import 'package:ai_bookkeeping/models/transaction.dart' as model;

import '../agent/actions/mock_database_service.dart';

// Mock VoiceNavigationService
class MockVoiceNavigationService extends VoiceNavigationService {
  NavigationResult? mockResult;
  final List<String> methodCalls = [];

  @override
  NavigationResult parseNavigation(String text) {
    methodCalls.add('parseNavigation:$text');
    return mockResult ?? NavigationResult.failure('Mock未配置');
  }
}

// Test helpers
model.Transaction createTestTransaction({
  String id = 'tx-123',
  double amount = 100.0,
  model.TransactionType type = model.TransactionType.expense,
  String category = '餐饮',
  DateTime? date,
  String? note,
}) {
  return model.Transaction(
    id: id,
    amount: amount,
    type: type,
    category: category,
    date: date ?? DateTime.now(),
    accountId: 'account-1',
    note: note,
  );
}

Operation createOperation({
  required OperationType type,
  Map<String, dynamic>? params,
}) {
  return Operation(
    type: type,
    priority: OperationPriority.normal,
    params: params ?? {},
    originalText: 'test',
  );
}

void main() {
  late MockDatabaseService mockDb;
  late MockVoiceNavigationService mockNav;
  late BookkeepingOperationAdapter adapter;

  setUp(() {
    mockDb = MockDatabaseService();
    mockNav = MockVoiceNavigationService();
    adapter = BookkeepingOperationAdapter(
      databaseService: mockDb,
      navigationService: mockNav,
    );
  });

  group('BookkeepingOperationAdapter', () {
    test('should have correct adapter name', () {
      expect(adapter.adapterName, 'BookkeepingOperationAdapter');
    });

    group('canHandle', () {
      test('should handle addTransaction', () {
        expect(adapter.canHandle(OperationType.addTransaction), isTrue);
      });

      test('should handle query', () {
        expect(adapter.canHandle(OperationType.query), isTrue);
      });

      test('should handle navigate', () {
        expect(adapter.canHandle(OperationType.navigate), isTrue);
      });

      test('should handle delete', () {
        expect(adapter.canHandle(OperationType.delete), isTrue);
      });

      test('should handle modify', () {
        expect(adapter.canHandle(OperationType.modify), isTrue);
      });

      test('should not handle unknown', () {
        expect(adapter.canHandle(OperationType.unknown), isFalse);
      });
    });

    group('addTransaction', () {
      test('should add expense transaction successfully', () async {
        final operation = createOperation(
          type: OperationType.addTransaction,
          params: {
            'amount': 50.0,
            'category': '餐饮',
            'type': 'expense',
            'note': '午饭',
          },
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['amount'], 50.0);
        expect(result.data?['category'], '餐饮');
        expect(mockDb.methodCalls, contains('insertTransaction'));
      });

      test('should add income transaction successfully', () async {
        final operation = createOperation(
          type: OperationType.addTransaction,
          params: {
            'amount': 5000.0,
            'category': '工资',
            'type': 'income',
          },
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['type'], 'income');
      });

      test('should add transfer transaction successfully', () async {
        final operation = createOperation(
          type: OperationType.addTransaction,
          params: {
            'amount': 1000.0,
            'type': 'transfer',
          },
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
      });

      test('should fail with invalid amount', () async {
        final operation = createOperation(
          type: OperationType.addTransaction,
          params: {'amount': 0},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
        expect(result.error, contains('金额'));
      });

      test('should fail with null amount', () async {
        final operation = createOperation(
          type: OperationType.addTransaction,
          params: {'category': '餐饮'},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
      });

      test('should use default category when not provided', () async {
        final operation = createOperation(
          type: OperationType.addTransaction,
          params: {'amount': 100.0},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['category'], '其他');
      });
    });

    group('query', () {
      test('should return summary by default', () async {
        mockDb.transactionsToReturn = [
          createTestTransaction(amount: 100.0, type: model.TransactionType.expense),
          createTestTransaction(id: 'tx-2', amount: 200.0, type: model.TransactionType.expense),
          createTestTransaction(id: 'tx-3', amount: 1000.0, type: model.TransactionType.income),
        ];

        final operation = createOperation(
          type: OperationType.query,
          params: {},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['queryType'], 'summary');
        expect(result.data?['totalExpense'], 300.0);
        expect(result.data?['totalIncome'], 1000.0);
        expect(result.data?['balance'], 700.0);
        expect(result.data?['transactionCount'], 3);
      });

      test('should return recent transactions', () async {
        mockDb.transactionsToReturn = [
          createTestTransaction(id: 'tx-1'),
          createTestTransaction(id: 'tx-2'),
        ];

        final operation = createOperation(
          type: OperationType.query,
          params: {'queryType': 'recent'},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['queryType'], 'recent');
        expect(result.data?['transactions'], isA<List>());
      });

      test('should handle empty transactions', () async {
        mockDb.transactionsToReturn = [];

        final operation = createOperation(
          type: OperationType.query,
          params: {},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['totalExpense'], 0.0);
        expect(result.data?['totalIncome'], 0.0);
        expect(result.data?['transactionCount'], 0);
      });
    });

    group('navigate', () {
      test('should navigate with explicit route', () async {
        final operation = createOperation(
          type: OperationType.navigate,
          params: {
            'route': '/statistics',
            'targetPage': '统计页面',
          },
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['route'], '/statistics');
      });

      test('should use navigation service when no route provided', () async {
        mockNav.mockResult = NavigationResult.success(
          const PageConfig(
            route: '/money-age',
            name: '钱龄分析',
            module: 'features',
            aliases: ['钱龄'],
            voiceAdaptation: VoiceAdaptation.high,
          ),
          confidence: 0.9,
        );

        final operation = createOperation(
          type: OperationType.navigate,
          params: {'targetPage': '钱龄分析'},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['route'], '/money-age');
        expect(mockNav.methodCalls, contains('parseNavigation:钱龄分析'));
      });

      test('should fail when navigation target not specified', () async {
        final operation = createOperation(
          type: OperationType.navigate,
          params: {},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
        expect(result.error, contains('目标'));
      });

      test('should fail when navigation service fails', () async {
        mockNav.mockResult = NavigationResult.failure('未找到页面');

        final operation = createOperation(
          type: OperationType.navigate,
          params: {'targetPage': '不存在的页面'},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
      });
    });

    group('delete', () {
      test('should delete transaction successfully', () async {
        final operation = createOperation(
          type: OperationType.delete,
          params: {'transactionId': 'tx-123'},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['deleted'], isTrue);
        expect(result.data?['transactionId'], 'tx-123');
      });

      test('should fail when transactionId not specified', () async {
        final operation = createOperation(
          type: OperationType.delete,
          params: {},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
        expect(result.error, contains('ID'));
      });

      test('should fail when transactionId is empty', () async {
        final operation = createOperation(
          type: OperationType.delete,
          params: {'transactionId': ''},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
      });
    });

    group('modify', () {
      test('should modify transaction amount', () async {
        mockDb.transactionsToReturn = [
          createTestTransaction(id: 'tx-123', amount: 100.0),
        ];

        final operation = createOperation(
          type: OperationType.modify,
          params: {
            'transactionId': 'tx-123',
            'amount': 150.0,
          },
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
        expect(result.data?['modified'], isTrue);
      });

      test('should modify transaction category', () async {
        mockDb.transactionsToReturn = [
          createTestTransaction(id: 'tx-123', category: '餐饮'),
        ];

        final operation = createOperation(
          type: OperationType.modify,
          params: {
            'transactionId': 'tx-123',
            'category': '交通',
          },
        );

        final result = await adapter.execute(operation);

        expect(result.success, isTrue);
      });

      test('should fail when transactionId not specified', () async {
        final operation = createOperation(
          type: OperationType.modify,
          params: {'amount': 200.0},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
        expect(result.error, contains('ID'));
      });

      test('should fail when transaction not found', () async {
        mockDb.transactionsToReturn = [];

        final operation = createOperation(
          type: OperationType.modify,
          params: {'transactionId': 'tx-not-found'},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
        expect(result.error, contains('修改失败'));
      });
    });

    group('unsupported operation', () {
      test('should return unsupported for unknown operation type', () async {
        final operation = createOperation(
          type: OperationType.unknown,
          params: {},
        );

        final result = await adapter.execute(operation);

        expect(result.success, isFalse);
        expect(result.error, contains('不支持'));
      });
    });
  });
}
