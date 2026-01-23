import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/agent/actions/habit_actions.dart';
import 'package:ai_bookkeeping/models/transaction.dart';

import 'mock_database_service.dart';

// Test helpers
Transaction createTestTransaction({
  String id = 'tx-123',
  double amount = 100.0,
  TransactionType type = TransactionType.expense,
  String category = '餐饮',
  DateTime? date,
  String? note,
}) {
  return Transaction(
    id: id,
    amount: amount,
    type: type,
    category: category,
    date: date ?? DateTime.now(),
    accountId: 'account-1',
    note: note,
  );
}

void main() {
  late MockDatabaseService mockDb;

  setUp(() {
    mockDb = MockDatabaseService();
  });

  group('HabitQueryAction', () {
    late HabitQueryAction action;

    setUp(() {
      action = HabitQueryAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'habit.query');
      expect(action.name, '查询消费习惯');
      expect(action.triggerPatterns, contains('消费习惯'));
      expect(action.triggerPatterns, contains('花钱习惯'));
    });

    test('should analyze spending patterns by category', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(amount: 100.0, category: '餐饮'),
        createTestTransaction(amount: 200.0, category: '餐饮'),
        createTestTransaction(amount: 50.0, category: '交通'),
        createTestTransaction(amount: 500.0, category: '购物'),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['transactionCount'], 4);
      expect(result.data?['totalAmount'], 850.0);
    });

    test('should identify top spending category by count', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(amount: 100.0, category: '餐饮'),
        createTestTransaction(amount: 50.0, category: '餐饮'),
        createTestTransaction(amount: 500.0, category: '购物'),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      // 餐饮 has 2 transactions vs 购物 has 1, so 餐饮 is top by count
      expect(result.data?['topCategory'], '餐饮');
    });

    test('should support custom days parameter', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({'days': 7});

      expect(result.success, isTrue);
    });

    test('should handle empty transactions', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['transactionCount'], 0);
    });
  });

  group('HabitAnalysisAction', () {
    late HabitAnalysisAction action;

    setUp(() {
      action = HabitAnalysisAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'habit.analysis');
      expect(action.name, '习惯深度分析');
      expect(action.triggerPatterns, contains('分析习惯'));
    });

    test('should provide spending analysis', () async {
      final now = DateTime.now();
      mockDb.transactionsToReturn = [
        createTestTransaction(
          amount: 30.0,
          category: '餐饮',
          date: DateTime(now.year, now.month, now.day, 8, 0),
        ),
        createTestTransaction(
          amount: 50.0,
          category: '餐饮',
          date: DateTime(now.year, now.month, now.day, 12, 0),
        ),
        createTestTransaction(
          amount: 100.0,
          category: '购物',
          date: DateTime(now.year, now.month, now.day, 20, 0),
        ),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['hasData'], isTrue);
    });

    test('should handle empty transactions', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['hasData'], isFalse);
    });
  });

  group('HabitReminderAction', () {
    late HabitReminderAction action;

    setUp(() {
      action = HabitReminderAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'habit.reminder');
      expect(action.name, '习惯提醒');
      expect(action.triggerPatterns, contains('习惯提醒'));
    });

    test('should set overspend reminder by default', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['reminderType'], 'overspend');
      expect(result.data?['enabled'], isTrue);
    });

    test('should set overspend reminder with custom threshold', () async {
      final result = await action.execute({
        'reminderType': 'overspend',
        'threshold': 1000,
      });

      expect(result.success, isTrue);
      expect(result.data?['reminderType'], 'overspend');
      expect(result.data?['threshold'], 1000.0);
    });

    test('should set periodic reminder', () async {
      final result = await action.execute({
        'reminderType': 'periodic',
      });

      expect(result.success, isTrue);
      expect(result.data?['reminderType'], 'periodic');
      expect(result.data?['frequency'], 'weekly');
    });

    test('should set saving reminder', () async {
      final result = await action.execute({
        'reminderType': 'saving',
        'threshold': 2000,
      });

      expect(result.success, isTrue);
      expect(result.data?['reminderType'], 'saving');
      expect(result.data?['target'], 2000.0);
    });

    test('should enable reminder', () async {
      final result = await action.execute({
        'reminderType': 'overspend',
      });

      expect(result.success, isTrue);
      expect(result.data?['enabled'], isTrue);
    });
  });
}
