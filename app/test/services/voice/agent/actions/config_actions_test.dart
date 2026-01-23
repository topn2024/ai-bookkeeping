import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/agent/actions/config_actions.dart';
import 'package:ai_bookkeeping/models/category.dart' as models;
import 'package:ai_bookkeeping/models/ledger.dart';
import 'package:ai_bookkeeping/models/transaction.dart' as model;

import 'mock_database_service.dart';

// Test helpers
models.Category createTestCategory({
  String id = 'cat-1',
  String name = '餐饮',
  bool isExpense = true,
}) {
  return models.Category(
    id: id,
    name: name,
    icon: Icons.restaurant,
    color: Colors.orange,
    isExpense: isExpense,
  );
}

Ledger createTestLedger({
  String id = 'ledger-1',
  String name = '默认账本',
}) {
  return Ledger(
    id: id,
    name: name,
    icon: Icons.book,
    color: Colors.blue,
    createdAt: DateTime.now(),
    ownerId: 'user-1',
  );
}

void main() {
  late MockDatabaseService mockDb;

  setUp(() {
    mockDb = MockDatabaseService();
  });

  group('CategoryConfigAction', () {
    late CategoryConfigAction action;

    setUp(() {
      action = CategoryConfigAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'config.category');
      expect(action.name, '分类管理');
      expect(action.triggerPatterns, contains('添加分类'));
      expect(action.triggerPatterns, contains('修改分类'));
      expect(action.triggerPatterns, contains('删除分类'));
      expect(action.triggerPatterns, contains('查询分类'));
    });

    group('add operation', () {
      test('should require categoryName', () async {
        final result = await action.execute({'operation': 'add'});

        expect(result.success, isFalse);
        expect(result.needsMoreParams, isTrue);
        expect(result.followUpPrompt, contains('分类名称'));
      });

      test('should add category successfully', () async {
        final result = await action.execute({
          'operation': 'add',
          'categoryName': '娱乐',
        });

        expect(result.success, isTrue);
        expect(result.responseText, contains('娱乐'));
        expect(result.data?['categoryId'], isNotNull);
        expect(mockDb.methodCalls, contains('insertCategory'));
      });

      test('should add income category when isExpense is false', () async {
        final result = await action.execute({
          'operation': 'add',
          'categoryName': '工资',
          'isExpense': false,
        });

        expect(result.success, isTrue);
        expect(result.responseText, contains('工资'));
      });
    });

    group('modify operation', () {
      test('should require categoryName', () async {
        final result = await action.execute({'operation': 'modify'});

        expect(result.success, isFalse);
        expect(result.needsMoreParams, isTrue);
      });

      test('should modify existing category', () async {
        mockDb.categoriesToReturn = [createTestCategory(name: '餐饮')];

        final result = await action.execute({
          'operation': 'modify',
          'categoryName': '餐饮',
          'newName': '饮食',
        });

        expect(result.success, isTrue);
        expect(result.responseText, contains('餐饮'));
        expect(mockDb.methodCalls, contains('updateCategory'));
      });

      test('should fail when category not found', () async {
        mockDb.categoriesToReturn = [];

        final result = await action.execute({
          'operation': 'modify',
          'categoryName': '不存在的分类',
        });

        expect(result.success, isFalse);
        expect(result.error, contains('失败'));
      });
    });

    group('delete operation', () {
      test('should require categoryName', () async {
        final result = await action.execute({'operation': 'delete'});

        expect(result.success, isFalse);
        expect(result.needsMoreParams, isTrue);
      });

      test('should delete existing category', () async {
        mockDb.categoriesToReturn = [createTestCategory(id: 'cat-to-delete', name: '临时分类')];

        final result = await action.execute({
          'operation': 'delete',
          'categoryName': '临时分类',
        });

        expect(result.success, isTrue);
        expect(result.responseText, contains('临时分类'));
        expect(mockDb.methodCalls, contains('deleteCategory'));
      });

      test('should fail when category not found', () async {
        mockDb.categoriesToReturn = [];

        final result = await action.execute({
          'operation': 'delete',
          'categoryName': '不存在的分类',
        });

        expect(result.success, isFalse);
      });
    });

    group('query operation', () {
      test('should return categories list', () async {
        mockDb.categoriesToReturn = [
          createTestCategory(id: 'cat-1', name: '餐饮'),
          createTestCategory(id: 'cat-2', name: '交通'),
        ];

        final result = await action.execute({'operation': 'query'});

        expect(result.success, isTrue);
        expect(result.responseText, contains('2'));
      });

      test('should handle empty categories', () async {
        mockDb.categoriesToReturn = [];

        final result = await action.execute({'operation': 'query'});

        expect(result.success, isTrue);
        expect(result.responseText, contains('0'));
      });
    });

    test('should fail on unsupported operation', () async {
      final result = await action.execute({'operation': 'unsupported'});

      expect(result.success, isFalse);
      expect(result.error, contains('不支持'));
    });
  });

  group('LedgerConfigAction', () {
    late LedgerConfigAction action;

    setUp(() {
      action = LedgerConfigAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'config.ledger');
      expect(action.name, '账本管理');
      expect(action.triggerPatterns, contains('创建账本'));
      expect(action.triggerPatterns, contains('切换账本'));
      expect(action.triggerPatterns, contains('查询账本'));
    });

    group('create operation', () {
      test('should require ledgerName', () async {
        final result = await action.execute({'operation': 'create'});

        expect(result.success, isFalse);
        expect(result.needsMoreParams, isTrue);
        expect(result.followUpPrompt, contains('账本名称'));
      });

      test('should create ledger successfully', () async {
        final result = await action.execute({
          'operation': 'create',
          'ledgerName': '旅行账本',
        });

        expect(result.success, isTrue);
        expect(result.responseText, contains('旅行账本'));
        expect(result.data?['ledgerId'], isNotNull);
        expect(mockDb.methodCalls, contains('insertLedger'));
      });
    });

    group('switch operation', () {
      test('should require ledgerName', () async {
        final result = await action.execute({'operation': 'switch'});

        expect(result.success, isFalse);
        expect(result.needsMoreParams, isTrue);
      });

      test('should switch to existing ledger', () async {
        mockDb.ledgersToReturn = [createTestLedger(name: '家庭账本')];

        final result = await action.execute({
          'operation': 'switch',
          'ledgerName': '家庭账本',
        });

        expect(result.success, isTrue);
        expect(result.responseText, contains('家庭账本'));
      });

      test('should fail when ledger not found', () async {
        mockDb.ledgersToReturn = [];

        final result = await action.execute({
          'operation': 'switch',
          'ledgerName': '不存在的账本',
        });

        expect(result.success, isFalse);
      });
    });

    group('query operation', () {
      test('should return ledgers list', () async {
        mockDb.ledgersToReturn = [
          createTestLedger(id: 'ledger-1', name: '默认账本'),
          createTestLedger(id: 'ledger-2', name: '家庭账本'),
        ];

        final result = await action.execute({'operation': 'query'});

        expect(result.success, isTrue);
        expect(result.responseText, contains('2'));
      });

      test('should handle empty ledgers', () async {
        mockDb.ledgersToReturn = [];

        final result = await action.execute({'operation': 'query'});

        expect(result.success, isTrue);
        expect(result.responseText, contains('0'));
      });
    });

    test('should fail on unsupported operation', () async {
      final result = await action.execute({'operation': 'unsupported'});

      expect(result.success, isFalse);
    });
  });

  group('CreditCardConfigAction', () {
    late CreditCardConfigAction action;

    setUp(() {
      action = CreditCardConfigAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'config.creditCard');
      expect(action.name, '信用卡管理');
      expect(action.triggerPatterns, contains('添加信用卡'));
      expect(action.triggerPatterns, contains('删除信用卡'));
      expect(action.triggerPatterns, contains('查询信用卡'));
    });

    test('should return placeholder for add operation', () async {
      final result = await action.execute({'operation': 'add'});

      expect(result.success, isTrue);
      expect(result.responseText, contains('待实现'));
    });

    test('should return placeholder for delete operation', () async {
      final result = await action.execute({'operation': 'delete'});

      expect(result.success, isTrue);
      expect(result.responseText, contains('待实现'));
    });

    test('should query credit cards', () async {
      mockDb.creditCardsToReturn = [];

      final result = await action.execute({'operation': 'query'});

      expect(result.success, isTrue);
      expect(result.data?['count'], 0);
    });

    test('should fail on unsupported operation', () async {
      final result = await action.execute({'operation': 'unsupported'});

      expect(result.success, isFalse);
    });
  });

  group('SavingsGoalConfigAction', () {
    late SavingsGoalConfigAction action;

    setUp(() {
      action = SavingsGoalConfigAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'config.savingsGoal');
      expect(action.name, '储蓄目标管理');
      expect(action.triggerPatterns, contains('创建储蓄目标'));
      expect(action.triggerPatterns, contains('查询储蓄目标'));
    });

    test('should return placeholder for create operation', () async {
      final result = await action.execute({'operation': 'create'});

      expect(result.success, isTrue);
      expect(result.responseText, contains('待实现'));
    });

    test('should query savings goals', () async {
      mockDb.savingsGoalsToReturn = [];

      final result = await action.execute({'operation': 'query'});

      expect(result.success, isTrue);
      expect(result.data?['count'], 0);
    });

    test('should fail on unsupported operation', () async {
      final result = await action.execute({'operation': 'unsupported'});

      expect(result.success, isFalse);
    });
  });

  group('RecurringTransactionConfigAction', () {
    late RecurringTransactionConfigAction action;

    setUp(() {
      action = RecurringTransactionConfigAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'config.recurringTransaction');
      expect(action.name, '定期交易管理');
      expect(action.triggerPatterns, contains('创建定期交易'));
      expect(action.triggerPatterns, contains('查询定期交易'));
    });

    test('should return placeholder for create operation', () async {
      final result = await action.execute({'operation': 'create'});

      expect(result.success, isTrue);
      expect(result.responseText, contains('待实现'));
    });

    test('should query recurring transactions', () async {
      mockDb.recurringTransactionsToReturn = [];

      final result = await action.execute({'operation': 'query'});

      expect(result.success, isTrue);
      expect(result.data?['count'], 0);
    });

    test('should fail on unsupported operation', () async {
      final result = await action.execute({'operation': 'unsupported'});

      expect(result.success, isFalse);
    });
  });

  group('TagConfigAction', () {
    late TagConfigAction action;

    setUp(() {
      action = TagConfigAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'config.tag');
      expect(action.name, '标签管理');
      expect(action.triggerPatterns, contains('查询标签'));
      expect(action.triggerPatterns, contains('标签列表'));
    });

    test('should query tags from transactions', () async {
      mockDb.transactionsToReturn = [
        model.Transaction(
          id: 'tx-1',
          amount: 100.0,
          type: model.TransactionType.expense,
          category: '餐饮',
          date: DateTime.now(),
          accountId: 'account-1',
          tags: ['日常', '午餐'],
        ),
        model.Transaction(
          id: 'tx-2',
          amount: 200.0,
          type: model.TransactionType.expense,
          category: '交通',
          date: DateTime.now(),
          accountId: 'account-1',
          tags: ['日常', '通勤'],
        ),
      ];

      final result = await action.execute({'operation': 'query'});

      expect(result.success, isTrue);
      expect(result.data?['count'], 3); // 日常, 午餐, 通勤
      expect(result.data?['tags'], contains('日常'));
    });

    test('should handle empty tags', () async {
      mockDb.transactionsToReturn = [];

      final result = await action.execute({'operation': 'query'});

      expect(result.success, isTrue);
      expect(result.data?['count'], 0);
    });

    test('should fail on unsupported operation', () async {
      final result = await action.execute({'operation': 'unsupported'});

      expect(result.success, isFalse);
    });
  });

  group('MemberConfigAction', () {
    late MemberConfigAction action;

    setUp(() {
      action = MemberConfigAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'config.member');
      expect(action.name, '成员管理');
      expect(action.triggerPatterns, contains('添加成员'));
      expect(action.triggerPatterns, contains('移除成员'));
      expect(action.triggerPatterns, contains('查询成员'));
    });

    test('should return placeholder for add operation', () async {
      final result = await action.execute({'operation': 'add'});

      expect(result.success, isTrue);
      expect(result.responseText, contains('待实现'));
    });

    test('should return placeholder for remove operation', () async {
      final result = await action.execute({'operation': 'remove'});

      expect(result.success, isTrue);
      expect(result.responseText, contains('待实现'));
    });

    test('should query all members', () async {
      mockDb.ledgerMembersToReturn = [];

      final result = await action.execute({'operation': 'query'});

      expect(result.success, isTrue);
      expect(result.data?['count'], 0);
    });

    test('should query members for specific ledger', () async {
      mockDb.ledgerMembersToReturn = [];

      final result = await action.execute({
        'operation': 'query',
        'ledgerId': 'ledger-1',
      });

      expect(result.success, isTrue);
      expect(mockDb.methodCalls, contains('getLedgerMembersForLedger'));
    });

    test('should fail on unsupported operation', () async {
      final result = await action.execute({'operation': 'unsupported'});

      expect(result.success, isFalse);
    });
  });
}
