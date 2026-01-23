import 'package:flutter/material.dart' hide Action;
import '../../../../core/contracts/i_database_service.dart';
import '../../../../models/category.dart' as models;
import '../../../../models/credit_card.dart';
import '../../../../models/ledger.dart';
import '../../../../models/member.dart';
import '../../../../models/recurring_transaction.dart';
import '../../../../models/savings_goal.dart';
import '../../../../models/transaction.dart';
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
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'cardName',
      type: ActionParamType.string,
      required: false,
      description: '信用卡名称',
    ),
    const ActionParam(
      name: 'bankName',
      type: ActionParamType.string,
      required: false,
      description: '发卡银行',
    ),
    const ActionParam(
      name: 'creditLimit',
      type: ActionParamType.number,
      required: false,
      description: '信用额度',
    ),
    const ActionParam(
      name: 'billDay',
      type: ActionParamType.number,
      required: false,
      defaultValue: 1,
      description: '账单日(1-28)',
    ),
    const ActionParam(
      name: 'paymentDueDay',
      type: ActionParamType.number,
      required: false,
      defaultValue: 20,
      description: '还款日(1-28)',
    ),
    const ActionParam(
      name: 'cardNumber',
      type: ActionParamType.string,
      required: false,
      description: '卡号后四位',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'add':
        return await _addCreditCard(params);
      case 'delete':
        return await _deleteCreditCard(params);
      case 'query':
        return await _queryCreditCards();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _addCreditCard(Map<String, dynamic> params) async {
    final cardName = params['cardName'] as String?;
    final creditLimit = (params['creditLimit'] as num?)?.toDouble();

    if (cardName == null) {
      return ActionResult.needParams(
        missing: ['cardName'],
        prompt: '请告诉我信用卡名称，比如"招商银行信用卡"',
        actionId: id,
      );
    }

    if (creditLimit == null) {
      return ActionResult.needParams(
        missing: ['creditLimit'],
        prompt: '请告诉我信用额度',
        actionId: id,
      );
    }

    try {
      final bankName = params['bankName'] as String?;
      final billDay = (params['billDay'] as num?)?.toInt() ?? 1;
      final paymentDueDay = (params['paymentDueDay'] as num?)?.toInt() ?? 20;
      final cardNumber = params['cardNumber'] as String?;

      final card = CreditCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: cardName,
        creditLimit: creditLimit,
        billDay: billDay.clamp(1, 28),
        paymentDueDay: paymentDueDay.clamp(1, 28),
        bankName: bankName,
        cardNumber: cardNumber,
        icon: Icons.credit_card,
        color: Colors.blue,
        createdAt: DateTime.now(),
      );

      await databaseService.insertCreditCard(card);

      return ActionResult.success(
        responseText: '已添加信用卡: $cardName，额度${creditLimit.toStringAsFixed(0)}元',
        data: {'cardId': card.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('添加信用卡失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _deleteCreditCard(Map<String, dynamic> params) async {
    final cardName = params['cardName'] as String?;

    if (cardName == null) {
      return ActionResult.needParams(
        missing: ['cardName'],
        prompt: '请告诉我要删除的信用卡名称',
        actionId: id,
      );
    }

    try {
      final cards = await databaseService.getCreditCards();
      final card = cards.where((c) =>
        c.name.contains(cardName) || cardName.contains(c.name)
      ).firstOrNull;

      if (card == null) {
        return ActionResult.failure('未找到信用卡: $cardName', actionId: id);
      }

      await databaseService.deleteCreditCard(card.id);

      return ActionResult.success(
        responseText: '已删除信用卡: ${card.name}',
        data: {'cardId': card.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('删除信用卡失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _queryCreditCards() async {
    try {
      final cards = await databaseService.getCreditCards();

      if (cards.isEmpty) {
        return ActionResult.success(
          responseText: '还没有添加信用卡',
          data: {'count': 0, 'cards': []},
          actionId: id,
        );
      }

      final cardList = cards.map((c) => {
        'id': c.id,
        'name': c.name,
        'creditLimit': c.creditLimit,
        'usedAmount': c.usedAmount,
        'availableCredit': c.availableCredit,
        'billDay': c.billDay,
        'paymentDueDay': c.paymentDueDay,
      }).toList();

      return ActionResult.success(
        responseText: '共有${cards.length}张信用卡',
        data: {'count': cards.length, 'cards': cardList},
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
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'goalName',
      type: ActionParamType.string,
      required: false,
      description: '目标名称',
    ),
    const ActionParam(
      name: 'targetAmount',
      type: ActionParamType.number,
      required: false,
      description: '目标金额',
    ),
    const ActionParam(
      name: 'targetDate',
      type: ActionParamType.dateTime,
      required: false,
      description: '目标日期',
    ),
    const ActionParam(
      name: 'description',
      type: ActionParamType.string,
      required: false,
      description: '目标描述',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'create':
        return await _createSavingsGoal(params);
      case 'query':
        return await _querySavingsGoals();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _createSavingsGoal(Map<String, dynamic> params) async {
    final goalName = params['goalName'] as String?;
    final targetAmount = (params['targetAmount'] as num?)?.toDouble();

    if (goalName == null) {
      return ActionResult.needParams(
        missing: ['goalName'],
        prompt: '请告诉我储蓄目标名称，比如"旅行基金"',
        actionId: id,
      );
    }

    if (targetAmount == null) {
      return ActionResult.needParams(
        missing: ['targetAmount'],
        prompt: '请告诉我目标金额',
        actionId: id,
      );
    }

    try {
      final description = params['description'] as String?;
      DateTime? targetDate;
      if (params['targetDate'] != null) {
        if (params['targetDate'] is DateTime) {
          targetDate = params['targetDate'] as DateTime;
        } else if (params['targetDate'] is String) {
          targetDate = DateTime.tryParse(params['targetDate'] as String);
        }
      }

      final goal = SavingsGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: goalName,
        description: description,
        type: SavingsGoalType.savings,
        targetAmount: targetAmount,
        startDate: DateTime.now(),
        targetDate: targetDate,
        icon: Icons.savings,
        color: Colors.green,
        createdAt: DateTime.now(),
      );

      await databaseService.insertSavingsGoal(goal);

      final dateInfo = targetDate != null
          ? '，目标日期${targetDate.month}月${targetDate.day}日'
          : '';
      return ActionResult.success(
        responseText: '已创建储蓄目标: $goalName，目标${targetAmount.toStringAsFixed(0)}元$dateInfo',
        data: {'goalId': goal.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('创建储蓄目标失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _querySavingsGoals() async {
    try {
      final goals = await databaseService.getSavingsGoals();

      if (goals.isEmpty) {
        return ActionResult.success(
          responseText: '还没有设置储蓄目标',
          data: {'count': 0, 'goals': []},
          actionId: id,
        );
      }

      final goalList = goals.map((g) => {
        'id': g.id,
        'name': g.name,
        'targetAmount': g.targetAmount,
        'currentAmount': g.currentAmount,
        'progress': g.progress,
        'progressPercent': g.progressPercent,
      }).toList();

      // 计算总体进度
      final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
      final totalCurrent = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
      final overallProgress = totalTarget > 0 ? (totalCurrent / totalTarget * 100).toStringAsFixed(1) : '0';

      return ActionResult.success(
        responseText: '共有${goals.length}个储蓄目标，总体进度$overallProgress%',
        data: {'count': goals.length, 'goals': goalList},
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
  String get id => 'config.recurring';

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
  List<ActionParam> get optionalParams => [
    const ActionParam(
      name: 'name',
      type: ActionParamType.string,
      required: false,
      description: '定期交易名称',
    ),
    const ActionParam(
      name: 'amount',
      type: ActionParamType.number,
      required: false,
      description: '金额',
    ),
    const ActionParam(
      name: 'category',
      type: ActionParamType.string,
      required: false,
      description: '分类',
    ),
    const ActionParam(
      name: 'frequency',
      type: ActionParamType.string,
      required: false,
      description: '频率: daily/weekly/monthly/yearly',
    ),
    const ActionParam(
      name: 'dayOfMonth',
      type: ActionParamType.number,
      required: false,
      description: '每月几号(1-31)',
    ),
    const ActionParam(
      name: 'transactionType',
      type: ActionParamType.string,
      required: false,
      description: '交易类型: expense/income',
    ),
  ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final operation = params['operation'] as String?;

    switch (operation) {
      case 'create':
        return await _createRecurringTransaction(params);
      case 'query':
        return await _queryRecurringTransactions();
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _createRecurringTransaction(Map<String, dynamic> params) async {
    final name = params['name'] as String?;
    final amount = (params['amount'] as num?)?.toDouble();

    if (name == null) {
      return ActionResult.needParams(
        missing: ['name'],
        prompt: '请告诉我定期交易名称，比如"房租"或"工资"',
        actionId: id,
      );
    }

    if (amount == null) {
      return ActionResult.needParams(
        missing: ['amount'],
        prompt: '请告诉我金额',
        actionId: id,
      );
    }

    try {
      final category = params['category'] as String? ?? '其他';
      final frequencyStr = params['frequency'] as String? ?? 'monthly';
      final dayOfMonth = (params['dayOfMonth'] as num?)?.toInt() ?? 1;
      final typeStr = params['transactionType'] as String? ?? 'expense';

      // 解析频率
      RecurringFrequency frequency;
      switch (frequencyStr.toLowerCase()) {
        case 'daily':
          frequency = RecurringFrequency.daily;
          break;
        case 'weekly':
          frequency = RecurringFrequency.weekly;
          break;
        case 'yearly':
          frequency = RecurringFrequency.yearly;
          break;
        case 'monthly':
        default:
          frequency = RecurringFrequency.monthly;
      }

      // 解析交易类型
      TransactionType type;
      if (typeStr.contains('收入') || typeStr == 'income') {
        type = TransactionType.income;
      } else {
        type = TransactionType.expense;
      }

      final recurring = RecurringTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        type: type,
        amount: amount,
        category: category,
        accountId: 'default',
        frequency: frequency,
        dayOfMonth: dayOfMonth.clamp(1, 28),
        startDate: DateTime.now(),
        icon: Icons.repeat,
        color: Colors.orange,
        createdAt: DateTime.now(),
      );

      await databaseService.insertRecurringTransaction(recurring);

      return ActionResult.success(
        responseText: '已创建定期交易: $name，${recurring.frequencyName}${amount.toStringAsFixed(0)}元',
        data: {'recurringId': recurring.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('创建定期交易失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _queryRecurringTransactions() async {
    try {
      final transactions = await databaseService.getRecurringTransactions();

      if (transactions.isEmpty) {
        return ActionResult.success(
          responseText: '还没有设置定期交易',
          data: {'count': 0, 'transactions': []},
          actionId: id,
        );
      }

      final transList = transactions.map((t) => {
        'id': t.id,
        'name': t.name,
        'amount': t.amount,
        'frequency': t.frequencyName,
        'type': t.typeName,
        'isEnabled': t.isEnabled,
      }).toList();

      final activeCount = transactions.where((t) => t.isEnabled).length;
      return ActionResult.success(
        responseText: '共有${transactions.length}个定期交易，${activeCount}个启用中',
        data: {'count': transactions.length, 'transactions': transList},
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
        return await _addMember(params);
      case 'remove':
        return await _removeMember(params);
      case 'query':
        return await _queryMembers(params);
      default:
        return ActionResult.failure('不支持的操作: $operation', actionId: id);
    }
  }

  Future<ActionResult> _addMember(Map<String, dynamic> params) async {
    final memberName = params['memberName'] as String?;
    final ledgerId = params['ledgerId'] as String?;

    if (memberName == null) {
      return ActionResult.needParams(
        missing: ['memberName'],
        prompt: '请告诉我要添加的成员名称',
        actionId: id,
      );
    }

    try {
      // 获取默认账本或指定账本
      String targetLedgerId = ledgerId ?? '';
      String ledgerName = '';
      if (ledgerId == null) {
        final defaultLedger = await databaseService.getDefaultLedger();
        if (defaultLedger == null) {
          return ActionResult.failure('请先选择一个账本', actionId: id);
        }
        targetLedgerId = defaultLedger.id;
        ledgerName = defaultLedger.name;
      } else {
        final ledgers = await databaseService.getLedgers();
        final ledger = ledgers.where((l) => l.id == ledgerId).firstOrNull;
        ledgerName = ledger?.name ?? '账本';
      }

      final roleStr = params['role'] as String? ?? 'editor';
      MemberRole role;
      switch (roleStr.toLowerCase()) {
        case 'admin':
          role = MemberRole.admin;
          break;
        case 'viewer':
          role = MemberRole.viewer;
          break;
        case 'editor':
        default:
          role = MemberRole.editor;
      }

      final member = LedgerMember(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ledgerId: targetLedgerId,
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        userName: memberName,
        role: role,
        joinedAt: DateTime.now(),
      );

      await databaseService.insertLedgerMember(member);

      return ActionResult.success(
        responseText: '已将$memberName添加到$ledgerName，角色为${role.displayName}',
        data: {'memberId': member.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('添加成员失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _removeMember(Map<String, dynamic> params) async {
    final memberName = params['memberName'] as String?;
    final ledgerId = params['ledgerId'] as String?;

    if (memberName == null) {
      return ActionResult.needParams(
        missing: ['memberName'],
        prompt: '请告诉我要移除的成员名称',
        actionId: id,
      );
    }

    try {
      List<LedgerMember> members;
      if (ledgerId != null) {
        members = await databaseService.getLedgerMembersForLedger(ledgerId);
      } else {
        members = await databaseService.getLedgerMembers();
      }

      final member = members.where((m) =>
        m.userName.contains(memberName) ||
        memberName.contains(m.userName) ||
        m.displayName.contains(memberName)
      ).firstOrNull;

      if (member == null) {
        return ActionResult.failure('未找到成员: $memberName', actionId: id);
      }

      // 不允许移除所有者
      if (member.role == MemberRole.owner) {
        return ActionResult.failure('无法移除账本所有者', actionId: id);
      }

      await databaseService.deleteLedgerMember(member.id);

      return ActionResult.success(
        responseText: '已移除成员: ${member.displayName}',
        data: {'memberId': member.id},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('移除成员失败: $e', actionId: id);
    }
  }

  Future<ActionResult> _queryMembers(Map<String, dynamic> params) async {
    try {
      final ledgerId = params['ledgerId'] as String?;

      List<LedgerMember> members;
      String context;
      if (ledgerId != null) {
        members = await databaseService.getLedgerMembersForLedger(ledgerId);
        context = '该账本';
      } else {
        members = await databaseService.getLedgerMembers();
        context = '';
      }

      if (members.isEmpty) {
        return ActionResult.success(
          responseText: '${context}还没有成员',
          data: {'count': 0, 'members': []},
          actionId: id,
        );
      }

      final memberList = members.map((m) => {
        'id': m.id,
        'name': m.displayName,
        'role': m.role.displayName,
        'isActive': m.isActive,
      }).toList();

      return ActionResult.success(
        responseText: '${context}共有${members.length}个成员',
        data: {'count': members.length, 'members': memberList},
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询成员失败: $e', actionId: id);
    }
  }
}
