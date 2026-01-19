import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/agent/actions/money_age_actions.dart';
import 'package:ai_bookkeeping/models/transaction.dart' as model;

import 'mock_database_service.dart';

// Test helpers
model.Transaction createTestTransaction({
  String id = 'tx-123',
  double amount = 100.0,
  model.TransactionType type = model.TransactionType.expense,
  String category = '餐饮',
  DateTime? date,
  int? moneyAge,
}) {
  return model.Transaction(
    id: id,
    amount: amount,
    type: type,
    category: category,
    date: date ?? DateTime.now(),
    accountId: 'account-1',
    moneyAge: moneyAge,
  );
}

void main() {
  late MockDatabaseService mockDb;

  setUp(() {
    mockDb = MockDatabaseService();
  });

  group('MoneyAgeQueryAction', () {
    late MoneyAgeQueryAction action;

    setUp(() {
      action = MoneyAgeQueryAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'moneyAge.query');
      expect(action.name, '查询钱龄');
      expect(action.triggerPatterns, contains('查询钱龄'));
      expect(action.triggerPatterns, contains('钱龄健康度'));
    });

    test('should return empty message when no money age data', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: null),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.responseText, contains('暂无'));
      expect(result.data?['averageMoneyAge'], 0);
    });

    test('should calculate average money age', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 10),
        createTestTransaction(id: 'tx-2', moneyAge: 20),
        createTestTransaction(id: 'tx-3', moneyAge: 30),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['averageMoneyAge'], 20.0);
      expect(result.data?['transactionCount'], 3);
    });

    test('should return healthy level for low money age', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 10),
        createTestTransaction(id: 'tx-2', moneyAge: 15),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['healthLevel'], 'health');
    });

    test('should return warning level for medium money age', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 35),
        createTestTransaction(id: 'tx-2', moneyAge: 45),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['healthLevel'], 'warning');
    });

    test('should return danger level for high money age', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 70),
        createTestTransaction(id: 'tx-2', moneyAge: 80),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['healthLevel'], 'danger');
    });

    test('should ignore income transactions', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 10),
        createTestTransaction(
          id: 'tx-income',
          type: model.TransactionType.income,
          moneyAge: 100,
        ),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['transactionCount'], 1);
      expect(result.data?['averageMoneyAge'], 10.0);
    });
  });

  group('MoneyAgeReminderAction', () {
    late MoneyAgeReminderAction action;

    setUp(() {
      action = MoneyAgeReminderAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'moneyAge.reminder');
      expect(action.name, '钱龄提醒');
      expect(action.triggerPatterns, contains('设置钱龄提醒'));
      expect(action.triggerPatterns, contains('钱龄预警'));
    });

    test('should set default threshold when no params', () async {
      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['enabled'], isTrue);
      expect(result.data?['threshold'], 30);
    });

    test('should set custom threshold', () async {
      final result = await action.execute({
        'threshold': 45,
      });

      expect(result.success, isTrue);
      expect(result.data?['threshold'], 45);
      expect(result.responseText, contains('45'));
    });

    test('should disable reminder when enabled is false', () async {
      final result = await action.execute({
        'enabled': false,
      });

      expect(result.success, isTrue);
      expect(result.data?['enabled'], isFalse);
      expect(result.responseText, contains('关闭'));
    });

    test('should set threshold and enable', () async {
      final result = await action.execute({
        'threshold': 60,
        'enabled': true,
      });

      expect(result.success, isTrue);
      expect(result.data?['threshold'], 60);
      expect(result.data?['enabled'], isTrue);
    });
  });

  group('MoneyAgeReportAction', () {
    late MoneyAgeReportAction action;

    setUp(() {
      action = MoneyAgeReportAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'moneyAge.report');
      expect(action.name, '钱龄报告');
      expect(action.triggerPatterns, contains('钱龄报告'));
      expect(action.triggerPatterns, contains('钱龄分析'));
    });

    test('should return empty message when no transactions', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['hasData'], isFalse);
      expect(result.responseText, contains('暂无'));
    });

    test('should generate report with distribution', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 10, category: '餐饮'),    // healthy
        createTestTransaction(id: 'tx-2', moneyAge: 15, category: '餐饮'),    // healthy
        createTestTransaction(id: 'tx-3', moneyAge: 40, category: '购物'),    // warning
        createTestTransaction(id: 'tx-4', moneyAge: 70, category: '娱乐'),    // danger
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['hasData'], isTrue);
      expect(result.data?['distribution']['healthy'], 2);
      expect(result.data?['distribution']['warning'], 1);
      expect(result.data?['distribution']['danger'], 1);
    });

    test('should calculate average money age', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 20),
        createTestTransaction(id: 'tx-2', moneyAge: 30),
        createTestTransaction(id: 'tx-3', moneyAge: 40),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['averageMoneyAge'], 30.0);
    });

    test('should identify health level excellent', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 10),
        createTestTransaction(id: 'tx-2', moneyAge: 15),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['healthLevel'], 'excellent');
      expect(result.data?['healthDescription'], '优秀');
    });

    test('should identify health level healthy', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 25),
        createTestTransaction(id: 'tx-2', moneyAge: 28),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['healthLevel'], 'healthy');
      expect(result.data?['healthDescription'], '健康');
    });

    test('should identify health level warning', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 35),
        createTestTransaction(id: 'tx-2', moneyAge: 40),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['healthLevel'], 'warning');
      expect(result.data?['healthDescription'], '需关注');
    });

    test('should identify health level danger', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 50),
        createTestTransaction(id: 'tx-2', moneyAge: 60),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['healthLevel'], 'danger');
      expect(result.data?['healthDescription'], '需改善');
    });

    test('should analyze by category', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 10, category: '餐饮'),
        createTestTransaction(id: 'tx-2', moneyAge: 20, category: '餐饮'),
        createTestTransaction(id: 'tx-3', moneyAge: 50, category: '购物'),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['categoryAnalysis'], isNotNull);
      expect(result.data?['worstCategory'], '购物');
    });

    test('should use custom days parameter', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 20),
      ];

      final result = await action.execute({'days': 7});

      expect(result.success, isTrue);
      expect(result.data?['days'], 7);
    });

    test('should handle transactions without money age', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 20),
        createTestTransaction(id: 'tx-2', moneyAge: null),
        createTestTransaction(id: 'tx-3', moneyAge: 30),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['distribution']['noData'], 1);
      expect(result.data?['validTransactions'], 2);
    });

    test('should generate suggestions', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(moneyAge: 50, category: '娱乐'),
        createTestTransaction(id: 'tx-2', moneyAge: 60, category: '娱乐'),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['suggestions'], isA<List>());
      expect((result.data?['suggestions'] as List).isNotEmpty, isTrue);
    });
  });
}
