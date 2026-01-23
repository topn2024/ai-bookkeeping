import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/agent/actions/data_actions.dart';
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

  group('DataExportAction', () {
    late DataExportAction action;

    setUp(() {
      action = DataExportAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'data.export');
      expect(action.name, '导出数据');
      expect(action.triggerPatterns, contains('导出数据'));
    });

    test('should export to CSV format by default', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(amount: 100.0, category: '餐饮'),
        createTestTransaction(amount: 200.0, category: '交通'),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['format'], 'csv');
      expect(result.data?['count'], 2);
    });

    test('should support JSON format', () async {
      mockDb.transactionsToReturn = [createTestTransaction()];

      final result = await action.execute({'format': 'json'});

      expect(result.success, isTrue);
      expect(result.data?['format'], 'json');
    });

    test('should support Excel format', () async {
      mockDb.transactionsToReturn = [createTestTransaction()];

      final result = await action.execute({'format': 'excel'});

      expect(result.success, isTrue);
      expect(result.data?['format'], 'excel');
    });

    test('should filter by date range', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({
        'startDate': DateTime(2026, 1, 1),
        'endDate': DateTime(2026, 1, 31),
      });

      expect(result.success, isTrue);
      expect(mockDb.methodCalls, contains('queryTransactions'));
    });

    test('should handle empty data', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['count'], 0);
    });
  });

  group('DataBackupAction', () {
    late DataBackupAction action;

    setUp(() {
      action = DataBackupAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'data.backup');
      expect(action.name, '备份数据');
      expect(action.triggerPatterns, contains('备份'));
    });

    test('should perform local backup by default', () async {
      mockDb.transactionsToReturn = [createTestTransaction()];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['backupType'], 'local');
    });

    test('should support cloud backup', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({'backupType': 'cloud'});

      expect(result.success, isTrue);
      expect(result.data?['backupType'], 'cloud');
    });

    test('should support auto backup configuration', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({'backupType': 'auto'});

      expect(result.success, isTrue);
      expect(result.data?['backupType'], 'auto');
    });
  });

  group('DataStatisticsAction', () {
    late DataStatisticsAction action;

    setUp(() {
      action = DataStatisticsAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'data.statistics');
      expect(action.name, '数据统计');
      expect(action.triggerPatterns, contains('数据统计'));
    });

    test('should calculate monthly statistics by default', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(amount: 100.0, type: TransactionType.expense),
        createTestTransaction(amount: 200.0, type: TransactionType.expense),
        createTestTransaction(amount: 500.0, type: TransactionType.income),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['period'], '本月'); // Returns Chinese text
      expect(result.data?['totalExpense'], 300.0);
      expect(result.data?['totalIncome'], 500.0);
    });

    test('should support different periods', () async {
      mockDb.transactionsToReturn = [];

      // Week - returns Chinese text
      var result = await action.execute({'period': 'week'});
      expect(result.data?['period'], '本周');

      // Year - returns Chinese text
      result = await action.execute({'period': 'year'});
      expect(result.data?['period'], '今年');
    });

    test('should support category dimension', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(amount: 100.0, category: '餐饮'),
        createTestTransaction(amount: 200.0, category: '餐饮'),
        createTestTransaction(amount: 50.0, category: '交通'),
      ];

      final result = await action.execute({'dimension': 'category'});

      expect(result.success, isTrue);
      expect(result.data?['categoryStats'], isNotNull);
    });

    test('should calculate transaction count', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(),
        createTestTransaction(id: 'tx-2'),
        createTestTransaction(id: 'tx-3'),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['totalTransactions'], 3);
    });

    test('should handle empty transactions', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['totalExpense'], 0.0);
      expect(result.data?['totalIncome'], 0.0);
      expect(result.data?['totalTransactions'], 0);
    });
  });
}
