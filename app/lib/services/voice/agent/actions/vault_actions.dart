import 'package:flutter/material.dart' hide Action;
import '../../../../core/contracts/i_database_service.dart';
import '../../../../models/budget_vault.dart';
import '../action_registry.dart';

/// 小金库查询Action
class VaultQueryAction extends Action {
  final IDatabaseService databaseService;

  VaultQueryAction(this.databaseService);

  @override
  String get id => 'vault.query';

  @override
  String get name => '查询小金库';

  @override
  String get description => '查询小金库余额和详情';

  @override
  List<String> get triggerPatterns => [
    '查询小金库', '小金库余额', '查看小金库',
    '我的小金库', '小金库有多少钱',
  ];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'vaultName',
      type: ActionParamType.string,
      required: false,
      description: '小金库名称',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    try {
      final vaults = await databaseService.getBudgetVaults();

      if (vaults.isEmpty) {
        return ActionResult.success(
          responseText: '暂无小金库',
          data: {'count': 0},
          actionId: id,
        );
      }

      final totalAllocated = vaults.fold(0.0, (sum, v) => sum + v.allocatedAmount);
      final totalSpent = vaults.fold(0.0, (sum, v) => sum + v.spentAmount);
      final totalRemaining = totalAllocated - totalSpent;

      return ActionResult.success(
        responseText: '共有${vaults.length}个小金库，总预算: ${totalAllocated.toStringAsFixed(2)}元，已使用: ${totalSpent.toStringAsFixed(2)}元，剩余: ${totalRemaining.toStringAsFixed(2)}元',
        data: {
          'count': vaults.length,
          'totalAllocated': totalAllocated,
          'totalSpent': totalSpent,
          'totalRemaining': totalRemaining,
          'vaults': vaults.map((v) => {
            'id': v.id,
            'name': v.name,
            'allocated': v.allocatedAmount,
            'spent': v.spentAmount,
            'remaining': v.allocatedAmount - v.spentAmount,
          }).toList(),
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询小金库失败: $e', actionId: id);
    }
  }
}

/// 小金库创建Action
class VaultCreateAction extends Action {
  final IDatabaseService databaseService;

  VaultCreateAction(this.databaseService);

  @override
  String get id => 'vault.create';

  @override
  String get name => '创建小金库';

  @override
  String get description => '创建新的小金库';

  @override
  List<String> get triggerPatterns => [
    '创建小金库', '新建小金库', '添加小金库',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'name',
      type: ActionParamType.string,
      description: '小金库名称',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'amount',
      type: ActionParamType.number,
      required: false,
      description: '预算金额',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final name = params['name'] as String?;

    if (name == null || name.isEmpty) {
      return ActionResult.needParams(
        missing: ['name'],
        prompt: '请告诉我小金库名称',
        actionId: id,
      );
    }

    try {
      final amount = (params['amount'] as num?)?.toDouble() ?? 0.0;

      final vault = BudgetVault(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        type: VaultType.flexible,
        allocationType: AllocationType.fixed,
        targetAmount: amount,
        allocatedAmount: amount,
        spentAmount: 0.0,
        icon: Icons.savings,
        color: Colors.blue,
        ledgerId: 'default',
        isEnabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await databaseService.insertBudgetVault(vault);

      return ActionResult.success(
        responseText: '已创建小金库: $name，预算: ${amount.toStringAsFixed(2)}元',
        data: {'vaultId': vault.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('创建小金库失败: $e', actionId: id);
    }
  }
}

/// 小金库转账Action
class VaultTransferAction extends Action {
  final IDatabaseService databaseService;

  VaultTransferAction(this.databaseService);

  @override
  String get id => 'vault.transfer';

  @override
  String get name => '小金库转账';

  @override
  String get description => '在小金库之间转账';

  @override
  List<String> get triggerPatterns => [
    '小金库转账', '转账到小金库',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'amount',
      type: ActionParamType.number,
      description: '转账金额',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'fromVault',
      type: ActionParamType.string,
      required: false,
      description: '来源小金库名称',
    ),
    const ActionParam(
      name: 'toVault',
      type: ActionParamType.string,
      required: false,
      description: '目标小金库名称',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final amount = (params['amount'] as num?)?.toDouble();
    final fromVault = params['fromVault'] as String?;
    final toVault = params['toVault'] as String?;

    if (amount == null || amount <= 0) {
      return ActionResult.needParams(
        missing: ['amount'],
        prompt: '请告诉我转账金额',
        actionId: id,
      );
    }

    if (fromVault == null && toVault == null) {
      return ActionResult.needParams(
        missing: ['fromVault', 'toVault'],
        prompt: '请告诉我从哪个小金库转到哪个小金库',
        actionId: id,
      );
    }

    try {
      final vaults = await databaseService.getBudgetVaults();

      // 查找来源和目标小金库
      BudgetVault? source;
      BudgetVault? target;

      for (final vault in vaults) {
        if (fromVault != null && vault.name.contains(fromVault)) {
          source = vault;
        }
        if (toVault != null && vault.name.contains(toVault)) {
          target = vault;
        }
      }

      if (source == null && fromVault != null) {
        return ActionResult.failure('找不到小金库: $fromVault', actionId: id);
      }

      if (target == null && toVault != null) {
        return ActionResult.failure('找不到小金库: $toVault', actionId: id);
      }

      // 检查余额
      if (source != null) {
        final available = source.allocatedAmount - source.spentAmount;
        if (available < amount) {
          return ActionResult.failure(
            '${source.name}余额不足，可用: ${available.toStringAsFixed(2)}元',
            actionId: id,
          );
        }
      }

      // 执行转账
      if (source != null) {
        final updatedSource = source.copyWith(
          spentAmount: source.spentAmount + amount,
          updatedAt: DateTime.now(),
        );
        await databaseService.updateBudgetVault(updatedSource);
      }

      if (target != null) {
        final updatedTarget = target.copyWith(
          allocatedAmount: target.allocatedAmount + amount,
          updatedAt: DateTime.now(),
        );
        await databaseService.updateBudgetVault(updatedTarget);
      }

      final fromName = source?.name ?? '主账户';
      final toName = target?.name ?? '主账户';

      return ActionResult.success(
        responseText: '已从$fromName转账${amount.toStringAsFixed(2)}元到$toName',
        data: {
          'amount': amount,
          'fromVault': fromName,
          'toVault': toName,
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('小金库转账失败: $e', actionId: id);
    }
  }
}

/// 小金库预算设置Action
class VaultBudgetAction extends Action {
  final IDatabaseService databaseService;

  VaultBudgetAction(this.databaseService);

  @override
  String get id => 'vault.budget';

  @override
  String get name => '小金库预算设置';

  @override
  String get description => '设置或修改小金库的预算金额';

  @override
  List<String> get triggerPatterns => [
    '小金库预算', '设置小金库预算', '修改小金库预算',
    '小金库设为', '小金库调整为',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'amount',
      type: ActionParamType.number,
      description: '预算金额',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'vaultName',
      type: ActionParamType.string,
      required: false,
      description: '小金库名称',
    ),
    const ActionParam(
      name: 'vaultId',
      type: ActionParamType.string,
      required: false,
      description: '小金库ID',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final amount = (params['amount'] as num?)?.toDouble();
    final vaultName = params['vaultName'] as String?;
    final vaultId = params['vaultId'] as String?;

    if (amount == null || amount < 0) {
      return ActionResult.needParams(
        missing: ['amount'],
        prompt: '请告诉我要设置的预算金额',
        actionId: id,
      );
    }

    try {
      final vaults = await databaseService.getBudgetVaults();

      if (vaults.isEmpty) {
        return ActionResult.failure('暂无小金库，请先创建', actionId: id);
      }

      // 查找目标小金库
      BudgetVault? targetVault;

      if (vaultId != null) {
        targetVault = vaults.where((v) => v.id == vaultId).firstOrNull;
      } else if (vaultName != null) {
        targetVault = vaults.where((v) => v.name.contains(vaultName)).firstOrNull;
      } else {
        // 如果只有一个小金库，默认使用它
        if (vaults.length == 1) {
          targetVault = vaults.first;
        } else {
          return ActionResult.needParams(
            missing: ['vaultName'],
            prompt: '有多个小金库，请告诉我要设置哪个',
            actionId: id,
          );
        }
      }

      if (targetVault == null) {
        return ActionResult.failure(
          '找不到小金库${vaultName != null ? ": $vaultName" : ""}',
          actionId: id,
        );
      }

      // 更新预算
      final updatedVault = targetVault.copyWith(
        targetAmount: amount,
        allocatedAmount: amount,
        updatedAt: DateTime.now(),
      );

      await databaseService.updateBudgetVault(updatedVault);

      return ActionResult.success(
        responseText: '已将${targetVault.name}的预算设置为${amount.toStringAsFixed(2)}元',
        data: {
          'vaultId': targetVault.id,
          'vaultName': targetVault.name,
          'newBudget': amount,
          'previousBudget': targetVault.allocatedAmount,
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('设置小金库预算失败: $e', actionId: id);
    }
  }
}
