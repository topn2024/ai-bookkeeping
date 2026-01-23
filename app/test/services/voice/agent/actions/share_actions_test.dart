import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/agent/actions/share_actions.dart';
import 'package:ai_bookkeeping/models/transaction.dart';
import 'package:ai_bookkeeping/models/budget.dart';

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

Budget createTestBudget({
  String id = 'budget-1',
  String name = '月度预算',
  double amount = 5000.0,
  String? categoryId,
}) {
  return Budget(
    id: id,
    name: name,
    amount: amount,
    period: BudgetPeriod.monthly,
    categoryId: categoryId,
    ledgerId: 'ledger-1',
    icon: Icons.account_balance_wallet,
    color: Colors.blue,
    createdAt: DateTime.now(),
  );
}

void main() {
  late MockDatabaseService mockDb;

  setUp(() {
    mockDb = MockDatabaseService();
  });

  group('ShareTransactionAction', () {
    late ShareTransactionAction action;

    setUp(() {
      action = ShareTransactionAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'share.transaction');
      expect(action.name, '分享交易记录');
      expect(action.triggerPatterns, contains('分享这笔'));
      expect(action.triggerPatterns, contains('分享交易'));
    });

    test('should share specific transaction by id', () async {
      final testTransaction = createTestTransaction(
        id: 'tx-123',
        amount: 100.0,
        category: '餐饮',
        note: '午饭',
      );

      mockDb.transactionsToReturn = [testTransaction];

      final result = await action.execute({
        'transactionId': 'tx-123',
        'shareType': 'text',
      });

      expect(result.success, isTrue);
      expect(result.data?['transactionId'], 'tx-123');
      expect(result.data?['ready'], isTrue);
    });

    test('should share most recent transaction when no id specified', () async {
      final testTransaction = createTestTransaction(id: 'tx-recent');

      mockDb.transactionsToReturn = [testTransaction];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['transactionId'], 'tx-recent');
    });

    test('should return failure when no transaction found', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({});

      expect(result.success, isFalse);
      expect(result.error, contains('没有找到'));
    });
  });

  group('ShareReportAction', () {
    late ShareReportAction action;

    setUp(() {
      action = ShareReportAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'share.report');
      expect(action.name, '分享统计报告');
      expect(action.triggerPatterns, contains('分享报告'));
    });

    test('should generate monthly report by default', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(amount: 100.0, type: TransactionType.expense),
        createTestTransaction(amount: 200.0, type: TransactionType.expense),
        createTestTransaction(amount: 500.0, type: TransactionType.income),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['period'], 'month');
      expect(result.data?['periodText'], '本月');
      expect(result.data?['totalExpense'], 300.0);
      expect(result.data?['totalIncome'], 500.0);
      expect(result.data?['transactionCount'], 3);
    });

    test('should support different periods', () async {
      mockDb.transactionsToReturn = [];

      // Week
      var result = await action.execute({'period': 'week'});
      expect(result.data?['periodText'], '本周');

      // Year
      result = await action.execute({'period': 'year'});
      expect(result.data?['periodText'], '今年');
    });

    test('should identify top category', () async {
      mockDb.transactionsToReturn = [
        createTestTransaction(amount: 100.0, category: '餐饮'),
        createTestTransaction(amount: 500.0, category: '购物'),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['topCategory'], '购物');
      expect(result.data?['topCategoryAmount'], 500.0);
    });
  });

  group('ShareBudgetAction', () {
    late ShareBudgetAction action;

    setUp(() {
      action = ShareBudgetAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'share.budget');
      expect(action.name, '分享预算信息');
      expect(action.triggerPatterns, contains('分享预算'));
    });

    test('should return no budget message when empty', () async {
      mockDb.budgetsToReturn = [];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['hasBudget'], isFalse);
      expect(result.responseText, contains('暂未设置预算'));
    });

    test('should calculate budget usage', () async {
      mockDb.budgetsToReturn = [createTestBudget(amount: 5000.0)];
      mockDb.transactionsToReturn = [
        createTestTransaction(amount: 1000.0),
        createTestTransaction(amount: 500.0),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['totalBudget'], 5000.0);
      expect(result.data?['totalSpent'], 1500.0);
      expect(result.data?['remaining'], 3500.0);
      expect(result.data?['usagePercent'], 30.0);
    });
  });
}
