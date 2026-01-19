import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/agent/actions/vault_actions.dart';
import 'package:ai_bookkeeping/models/budget_vault.dart';

import 'mock_database_service.dart';

// Test helpers
BudgetVault createTestVault({
  String id = 'vault-1',
  String name = '旅行基金',
  double allocatedAmount = 5000.0,
  double spentAmount = 1000.0,
  bool isEnabled = true,
}) {
  return BudgetVault(
    id: id,
    name: name,
    type: VaultType.flexible,
    allocationType: AllocationType.fixed,
    targetAmount: allocatedAmount,
    allocatedAmount: allocatedAmount,
    spentAmount: spentAmount,
    icon: Icons.savings,
    color: Colors.blue,
    ledgerId: 'ledger-1',
    isEnabled: isEnabled,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late MockDatabaseService mockDb;

  setUp(() {
    mockDb = MockDatabaseService();
  });

  group('VaultQueryAction', () {
    late VaultQueryAction action;

    setUp(() {
      action = VaultQueryAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'vault.query');
      expect(action.name, '查询小金库');
      expect(action.triggerPatterns, contains('查询小金库'));
      expect(action.triggerPatterns, contains('小金库余额'));
    });

    test('should return empty message when no vaults', () async {
      mockDb.budgetVaultsToReturn = [];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.responseText, contains('暂无'));
      expect(result.data?['count'], 0);
    });

    test('should return vault summary', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(
          id: 'vault-1',
          name: '旅行基金',
          allocatedAmount: 5000.0,
          spentAmount: 1000.0,
        ),
        createTestVault(
          id: 'vault-2',
          name: '购物基金',
          allocatedAmount: 3000.0,
          spentAmount: 500.0,
        ),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['count'], 2);
      expect(result.data?['totalAllocated'], 8000.0);
      expect(result.data?['totalSpent'], 1500.0);
      expect(result.data?['totalRemaining'], 6500.0);
    });

    test('should include vault details in data', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(
          name: '紧急储备',
          allocatedAmount: 10000.0,
          spentAmount: 0.0,
        ),
      ];

      final result = await action.execute({});

      expect(result.success, isTrue);
      expect(result.data?['vaults'], isA<List>());
      expect((result.data?['vaults'] as List).length, 1);
    });
  });

  group('VaultCreateAction', () {
    late VaultCreateAction action;

    setUp(() {
      action = VaultCreateAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'vault.create');
      expect(action.name, '创建小金库');
      expect(action.triggerPatterns, contains('创建小金库'));
      expect(action.triggerPatterns, contains('新建小金库'));
    });

    test('should require name', () async {
      final result = await action.execute({});

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
      expect(result.followUpPrompt, contains('名称'));
    });

    test('should create vault with name only', () async {
      final result = await action.execute({
        'name': '储蓄基金',
      });

      expect(result.success, isTrue);
      expect(result.responseText, contains('储蓄基金'));
      expect(result.data?['vaultId'], isNotNull);
      expect(mockDb.methodCalls, contains('insertBudgetVault'));
    });

    test('should create vault with name and amount', () async {
      final result = await action.execute({
        'name': '旅行基金',
        'amount': 5000.0,
      });

      expect(result.success, isTrue);
      expect(result.responseText, contains('旅行基金'));
      expect(result.responseText, contains('5000'));
    });

    test('should handle zero amount', () async {
      final result = await action.execute({
        'name': '新基金',
        'amount': 0,
      });

      expect(result.success, isTrue);
    });
  });

  group('VaultTransferAction', () {
    late VaultTransferAction action;

    setUp(() {
      action = VaultTransferAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'vault.transfer');
      expect(action.name, '小金库转账');
      expect(action.triggerPatterns, contains('小金库转账'));
    });

    test('should require amount', () async {
      final result = await action.execute({
        'fromVault': '旅行基金',
        'toVault': '购物基金',
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
      expect(result.followUpPrompt, contains('金额'));
    });

    test('should require vault specification', () async {
      final result = await action.execute({
        'amount': 500.0,
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
    });

    test('should transfer between vaults', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(
          id: 'vault-1',
          name: '旅行基金',
          allocatedAmount: 5000.0,
          spentAmount: 1000.0,
        ),
        createTestVault(
          id: 'vault-2',
          name: '购物基金',
          allocatedAmount: 3000.0,
          spentAmount: 500.0,
        ),
      ];

      final result = await action.execute({
        'amount': 500.0,
        'fromVault': '旅行基金',
        'toVault': '购物基金',
      });

      expect(result.success, isTrue);
      expect(result.data?['amount'], 500.0);
      expect(result.data?['fromVault'], '旅行基金');
      expect(result.data?['toVault'], '购物基金');
      expect(mockDb.methodCalls.where((c) => c == 'updateBudgetVault').length, 2);
    });

    test('should fail when source vault not found', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(name: '购物基金'),
      ];

      final result = await action.execute({
        'amount': 500.0,
        'fromVault': '不存在的基金',
        'toVault': '购物基金',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('找不到'));
    });

    test('should fail when insufficient balance', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(
          name: '旅行基金',
          allocatedAmount: 1000.0,
          spentAmount: 800.0, // Only 200 available
        ),
        createTestVault(name: '购物基金'),
      ];

      final result = await action.execute({
        'amount': 500.0,
        'fromVault': '旅行基金',
        'toVault': '购物基金',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('余额不足'));
    });

    test('should transfer from vault to main account', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(
          name: '旅行基金',
          allocatedAmount: 5000.0,
          spentAmount: 1000.0,
        ),
      ];

      final result = await action.execute({
        'amount': 500.0,
        'fromVault': '旅行基金',
      });

      expect(result.success, isTrue);
      expect(result.data?['toVault'], '主账户');
    });
  });

  group('VaultBudgetAction', () {
    late VaultBudgetAction action;

    setUp(() {
      action = VaultBudgetAction(mockDb);
    });

    test('should have correct metadata', () {
      expect(action.id, 'vault.budget');
      expect(action.name, '小金库预算设置');
      expect(action.triggerPatterns, contains('小金库预算'));
      expect(action.triggerPatterns, contains('设置小金库预算'));
    });

    test('should require amount', () async {
      final result = await action.execute({
        'vaultName': '旅行基金',
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
      expect(result.followUpPrompt, contains('金额'));
    });

    test('should fail when no vaults exist', () async {
      mockDb.budgetVaultsToReturn = [];

      final result = await action.execute({
        'amount': 5000.0,
      });

      expect(result.success, isFalse);
      expect(result.error, contains('暂无'));
    });

    test('should require vault name when multiple vaults exist', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(name: '旅行基金'),
        createTestVault(id: 'vault-2', name: '购物基金'),
      ];

      final result = await action.execute({
        'amount': 5000.0,
      });

      expect(result.success, isFalse);
      expect(result.needsMoreParams, isTrue);
    });

    test('should use only vault when single vault exists', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(name: '旅行基金'),
      ];

      final result = await action.execute({
        'amount': 8000.0,
      });

      expect(result.success, isTrue);
      expect(result.data?['newBudget'], 8000.0);
      expect(mockDb.methodCalls, contains('updateBudgetVault'));
    });

    test('should set budget by vault name', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(name: '旅行基金', allocatedAmount: 5000.0),
        createTestVault(id: 'vault-2', name: '购物基金'),
      ];

      final result = await action.execute({
        'amount': 10000.0,
        'vaultName': '旅行基金',
      });

      expect(result.success, isTrue);
      expect(result.responseText, contains('旅行基金'));
      expect(result.data?['newBudget'], 10000.0);
      expect(result.data?['previousBudget'], 5000.0);
    });

    test('should set budget by vault id', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(id: 'target-vault', name: '旅行基金'),
      ];

      final result = await action.execute({
        'amount': 7500.0,
        'vaultId': 'target-vault',
      });

      expect(result.success, isTrue);
      expect(result.data?['vaultId'], 'target-vault');
    });

    test('should fail when vault not found by name', () async {
      mockDb.budgetVaultsToReturn = [
        createTestVault(name: '旅行基金'),
      ];

      final result = await action.execute({
        'amount': 5000.0,
        'vaultName': '不存在的基金',
      });

      expect(result.success, isFalse);
      expect(result.error, contains('找不到'));
    });
  });
}
