import 'package:flutter/material.dart' hide Action;
import '../../../../core/contracts/i_database_service.dart';
import '../../../../models/category.dart' as models;
import '../../../../models/ledger.dart';
import '../action_registry.dart';

/// 分类管理Action
class CategoryConfigAction extends Action {
  final IDatabaseService databaseService;

  CategoryConfigAction(this.databaseService);

  @override
  String get id => 'config.category';

  @override
  String get name => '分类管理';

  @override
  String get description => '管理交易分类，包括添加、修改、删除和查询';

  @override
  List<String> get triggerPatterns => [
    '添加分类', '创建分类', '新建分类',
    '修改分类', '更改分类',
    '删除分类', '移除分类',
    '查询分类', '查看分类', '分类列表',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'operation',
      type: ActionParamType.string,
      description: '操作类型: add/modify/delete/query',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'categoryName',
      type: ActionParamType.string,
      required: false,
      description: '分类名称',
    ),
    const ActionParam(
      name: 'isExpense',
      type: ActionParamType.boolean,
      required: false,
      defaultValue: true,
      description: '是否为支出分类',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;
    final categoryName = params['categoryName'] as String?;

    switch (operation) {
      case 'add':
        if (categoryName == null) {
          return ActionResult.needParams(
            missing: ['categoryName'],
            prompt: '请告诉我要添加的分类名称',
            actionId: id,
          );
        }
        return await _addCategory(categoryName, params);
      case 'modify':
        if (categoryName == null) {
          return ActionResult.needParams(
            missing: ['categoryName'],
            prompt: '请告诉我要修改的分类名称',
            actionId: id,
          );
        }
        return await _modifyCategory(categoryName, params);
      case 'delete':
        if (categoryName == null) {
          return ActionResult.needParams(
            missing: ['categoryName'],
            prompt: '请告诉我要删除的分类名称',
            actionId: id,
          );
        }
        return await _deleteCategory(categoryName);
      case 'query':
        return await _queryCategories();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _addCategory(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final isExpense = params['isExpense'] as bool? ?? true;

      final category = models.Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        icon: Icons.category,
        color: Colors.blue,
        isExpense: isExpense,
      );

      await databaseService.insertCategory(category);

      return ActionResult.success(
        responseText: '已添加分类: $name',
        data: {'categoryId': category.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('添加分类失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _modifyCategory(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final categories = await databaseService.getCategories();
      final category = categories.firstWhere(
        (c) => c.name == name,
        orElse: () => throw Exception('未找到分类: $name'),
      );

      final newName = params['newName'] as String? ?? category.name;

      final updatedCategory = category.copyWith(
        name: newName,
      );

      await databaseService.updateCategory(updatedCategory);

      return ActionResult.success(
        responseText: '已修改分类: $name',
        data: {'categoryId': category.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('修改分类失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _deleteCategory(String name) async {
    try {
      final categories = await databaseService.getCategories();
      final category = categories.firstWhere(
        (c) => c.name == name,
        orElse: () => throw Exception('未找到分类: $name'),
      );

      await databaseService.deleteCategory(category.id);

      return ActionResult.success(
        responseText: '已删除分类: $name',
        data: {'categoryId': category.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('删除分类失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _queryCategories() async {
    try {
      final categories = await databaseService.getCategories();

      return ActionResult.success(
        responseText: '共有${categories.length}个分类',
        data: {
          'categories': categories.map((c) => {
            'id': c.id,
            'name': c.name,
            'isExpense': c.isExpense,
          }).toList(),
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询分类失败: $e', actionId: id);
    }
  }
}

/// 账本管理Action
class LedgerConfigAction extends Action {
  final IDatabaseService databaseService;

  LedgerConfigAction(this.databaseService);

  @override
  String get id => 'config.ledger';

  @override
  String get name => '账本管理';

  @override
  String get description => '管理账本，包括创建、切换和查询';

  @override
  List<String> get triggerPatterns => [
    '创建账本', '新建账本',
    '切换账本', '更换账本',
    '查询账本', '账本列表',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'operation',
      type: ActionParamType.string,
      description: '操作类型: create/switch/query',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'ledgerName',
      type: ActionParamType.string,
      required: false,
      description: '账本名称',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'create':
        final ledgerName = params['ledgerName'] as String?;
        if (ledgerName == null) {
          return ActionResult.needParams(
            missing: ['ledgerName'],
            prompt: '请告诉我要创建的账本名称',
            actionId: id,
          );
        }
        return await _createLedger(ledgerName);
      case 'switch':
        final ledgerName = params['ledgerName'] as String?;
        if (ledgerName == null) {
          return ActionResult.needParams(
            missing: ['ledgerName'],
            prompt: '请告诉我要切换到哪个账本',
            actionId: id,
          );
        }
        return await _switchLedger(ledgerName);
      case 'query':
        return await _queryLedgers();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _createLedger(String name) async {
    try {
      final ledger = Ledger(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        icon: Icons.book,
        color: Colors.blue,
        createdAt: DateTime.now(),
        ownerId: 'current_user',
      );

      await databaseService.insertLedger(ledger);

      return ActionResult.success(
        responseText: '已创建账本: $name',
        data: {'ledgerId': ledger.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('创建账本失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _switchLedger(String name) async {
    try {
      final ledgers = await databaseService.getLedgers();
      final ledger = ledgers.firstWhere(
        (l) => l.name == name,
        orElse: () => throw Exception('未找到账本: $name'),
      );

      return ActionResult.success(
        responseText: '已切换到账本: $name',
        data: {'ledgerId': ledger.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('切换账本失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _queryLedgers() async {
    try {
      final ledgers = await databaseService.getLedgers();

      return ActionResult.success(
        responseText: '共有${ledgers.length}个账本',
        data: {
          'ledgers': ledgers.map((l) => {
            'id': l.id,
            'name': l.name,
            'type': l.type.displayName,
          }).toList(),
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询账本失败: $e', actionId: id);
    }
  }
}

/// 信用卡管理Action
class CreditCardConfigAction extends Action {
  final IDatabaseService databaseService;

  CreditCardConfigAction(this.databaseService);

  @override
  String get id => 'config.creditCard';

  @override
  String get name => '信用卡管理';

  @override
  String get description => '管理信用卡，包括添加、删除和查询';

  @override
  List<String> get triggerPatterns => [
    '添加信用卡', '绑定信用卡',
    '删除信用卡', '移除信用卡',
    '查询信用卡', '信用卡列表',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'operation',
      type: ActionParamType.string,
      description: '操作类型: add/delete/query',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'add':
        return ActionResult.success(
          responseText: '信用卡添加功能待实现',
          actionId: id,
        );
      case 'delete':
        return ActionResult.success(
          responseText: '信用卡删除功能待实现',
          actionId: id,
        );
      case 'query':
        return await _queryCreditCards();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _queryCreditCards() async {
    try {
      final cards = await databaseService.getCreditCards();

      return ActionResult.success(
        responseText: '共有${cards.length}张信用卡',
        data: {'count': cards.length},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询信用卡失败: $e', actionId: id);
    }
  }
}

/// 储蓄目标管理Action
class SavingsGoalConfigAction extends Action {
  final IDatabaseService databaseService;

  SavingsGoalConfigAction(this.databaseService);

  @override
  String get id => 'config.savingsGoal';

  @override
  String get name => '储蓄目标管理';

  @override
  String get description => '管理储蓄目标，包括创建、更新和查询';

  @override
  List<String> get triggerPatterns => [
    '创建储蓄目标', '新建储蓄目标',
    '查询储蓄目标', '储蓄目标列表',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'operation',
      type: ActionParamType.string,
      description: '操作类型: create/query',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'create':
        return ActionResult.success(
          responseText: '储蓄目标创建功能待实现',
          actionId: id,
        );
      case 'query':
        return await _querySavingsGoals();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _querySavingsGoals() async {
    try {
      final goals = await databaseService.getSavingsGoals();

      return ActionResult.success(
        responseText: '共有${goals.length}个储蓄目标',
        data: {'count': goals.length},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询储蓄目标失败: $e', actionId: id);
    }
  }
}

/// 定期交易管理Action
class RecurringTransactionConfigAction extends Action {
  final IDatabaseService databaseService;

  RecurringTransactionConfigAction(this.databaseService);

  @override
  String get id => 'config.recurringTransaction';

  @override
  String get name => '定期交易管理';

  @override
  String get description => '管理定期交易，包括创建、暂停和查询';

  @override
  List<String> get triggerPatterns => [
    '创建定期交易', '新建定期交易',
    '查询定期交易', '定期交易列表',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'operation',
      type: ActionParamType.string,
      description: '操作类型: create/query',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'create':
        return ActionResult.success(
          responseText: '定期交易创建功能待实现',
          actionId: id,
        );
      case 'query':
        return await _queryRecurringTransactions();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _queryRecurringTransactions() async {
    try {
      final transactions = await databaseService.getRecurringTransactions();

      return ActionResult.success(
        responseText: '共有${transactions.length}个定期交易',
        data: {'count': transactions.length},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询定期交易失败: $e', actionId: id);
    }
  }
}

/// 标签管理Action
class TagConfigAction extends Action {
  final IDatabaseService databaseService;

  TagConfigAction(this.databaseService);

  @override
  String get id => 'config.tag';

  @override
  String get name => '标签管理';

  @override
  String get description => '管理交易标签，包括查询和管理';

  @override
  List<String> get triggerPatterns => [
    '查询标签', '标签列表', '所有标签',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'operation',
      type: ActionParamType.string,
      description: '操作类型: query',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'query':
        return await _queryTags();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _queryTags() async {
    try {
      final transactions = await databaseService.getTransactions();
      final tags = <String>{};

      for (final transaction in transactions) {
        if (transaction.tags != null) {
          tags.addAll(transaction.tags!);
        }
      }

      return ActionResult.success(
        responseText: '共有${tags.length}个标签',
        data: {
          'tags': tags.toList(),
          'count': tags.length,
        },
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询标签失败: $e', actionId: id);
    }
  }
}

/// 成员管理Action
class MemberConfigAction extends Action {
  final IDatabaseService databaseService;

  MemberConfigAction(this.databaseService);

  @override
  String get id => 'config.member';

  @override
  String get name => '成员管理';

  @override
  String get description => '管理账本成员，包括添加、移除和查询';

  @override
  List<String> get triggerPatterns => [
    '添加成员', '邀请成员',
    '移除成员', '删除成员',
    '查询成员', '成员列表',
  ];

  @override
  List<ActionParam> get requiredParams => [
    const ActionParam(
      name: 'operation',
      type: ActionParamType.string,
      description: '操作类型: add/remove/query',
    ),
  ];

  @override
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'ledgerId',
      type: ActionParamType.string,
      required: false,
      description: '账本ID',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'add':
        return ActionResult.success(
          responseText: '成员添加功能待实现',
          actionId: id,
        );
      case 'remove':
        return ActionResult.success(
          responseText: '成员移除功能待实现',
          actionId: id,
        );
      case 'query':
        return await _queryMembers(params);
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _queryMembers(Map<String, dynamic> params) async {
    try {
      final ledgerId = params['ledgerId'] as String?;

      if (ledgerId != null) {
        final members = await databaseService.getLedgerMembersForLedger(ledgerId);
        return ActionResult.success(
          responseText: '该账本共有${members.length}个成员',
          data: {'count': members.length},
          actionId: id,
        );
      } else {
        final members = await databaseService.getLedgerMembers();
        return ActionResult.success(
          responseText: '共有${members.length}个成员',
          data: {'count': members.length},
          actionId: id,
        );
      }
    } catch (e) {
      return ActionResult.failure('查询成员失败: $e', actionId: id);
    }
  }
}
