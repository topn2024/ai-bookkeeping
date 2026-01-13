/// 行为路由器
///
/// 将意图映射到现有服务，实现意图识别与业务执行的分离
///
/// 设计原则：
/// - 只做路由，不实现业务逻辑
/// - 复用现有 Service（TransactionService, BudgetService 等）
/// - 支持动态扩展
library;

import 'package:flutter/foundation.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/contracts/i_database_service.dart';
import '../../../models/transaction.dart';
import '../../voice_navigation_service.dart';
import '../../voice_navigation_executor.dart';
import 'action_registry.dart';
import 'hybrid_intent_router.dart';

/// 行为路由器
///
/// 核心职责：
/// - 将 LLM 识别的意图路由到正确的 Service
/// - 不实现业务逻辑，只做转发
/// - 支持 136+ 配置项
class ActionRouter {
  /// 数据库服务
  final IDatabaseService _databaseService;

  /// 导航服务
  final VoiceNavigationService _navigationService;

  /// 行为注册表
  final ActionRegistry _registry;

  /// 页面导航回调
  void Function(String route)? onNavigate;

  /// 配置修改回调
  Future<void> Function(String key, dynamic value)? onConfigChange;

  ActionRouter({
    IDatabaseService? databaseService,
    VoiceNavigationService? navigationService,
    ActionRegistry? registry,
  })  : _databaseService = databaseService ?? sl<IDatabaseService>(),
        _navigationService = navigationService ?? VoiceNavigationService(),
        _registry = registry ?? ActionRegistry.instance {
    // 注册所有内置行为
    _registerBuiltInActions();
  }

  /// 注册内置行为
  void _registerBuiltInActions() {
    // 交易行为
    _registry.registerAll([
      _TransactionExpenseAction(_databaseService),
      _TransactionIncomeAction(_databaseService),
      _TransactionModifyAction(_databaseService),
      _TransactionDeleteAction(_databaseService),
      _TransactionQueryAction(_databaseService),
    ]);

    // 导航行为
    _registry.register(_NavigationAction(_navigationService, onNavigate));

    // 查询行为
    _registry.registerAll([
      _StatisticsQueryAction(_databaseService),
      _BudgetQueryAction(),
    ]);

    // 配置行为
    _registry.registerAll([
      _BudgetConfigAction(onConfigChange),
      _AccountConfigAction(onConfigChange),
      _ReminderConfigAction(onConfigChange),
      _ThemeConfigAction(onConfigChange),
    ]);

    debugPrint('[ActionRouter] 注册了 ${_registry.allActionIds.length} 个内置行为');
  }

  /// 执行意图
  Future<ActionResult> execute(IntentResult intent) async {
    debugPrint('[ActionRouter] 执行意图: ${intent.intentId}');

    // 查找对应的行为
    Action? action;

    // 1. 尝试通过完整意图ID查找
    if (intent.intentId != null) {
      action = _registry.findByIntent(intent.intentId!);
    }

    // 2. 尝试组合查找
    if (action == null && intent.category != null && intent.action != null) {
      final actionId = '${intent.category}.${intent.action}';
      action = _registry.findById(actionId);
    }

    // 3. 尝试触发词匹配
    if (action == null) {
      final actions = _registry.findByTrigger(intent.rawInput);
      if (actions.isNotEmpty) {
        action = actions.first;
      }
    }

    if (action == null) {
      return ActionResult.unsupported(intent.intentId ?? 'unknown');
    }

    // 执行行为
    try {
      return await action.execute(intent.entities);
    } catch (e) {
      debugPrint('[ActionRouter] 执行失败: $e');
      return ActionResult.failure(
        '执行失败: ${e.toString()}',
        actionId: action.id,
      );
    }
  }

  /// 获取支持的行为列表
  List<String> get supportedActions => _registry.allActionIds;

  /// 获取行为统计
  Map<String, int> get actionStats => _registry.getStats();
}

// ═══════════════════════════════════════════════════════════════════════════
// 交易行为实现
// ═══════════════════════════════════════════════════════════════════════════

/// 添加支出行为
class _TransactionExpenseAction extends Action {
  final IDatabaseService _db;

  _TransactionExpenseAction(this._db);

  @override
  String get id => 'transaction.expense';

  @override
  String get name => '添加支出';

  @override
  String get description => '记录一笔支出';

  @override
  List<String> get triggerPatterns => ['花了', '买了', '付了', '消费', '支出'];

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'amount',
          type: ActionParamType.number,
          description: '金额',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [
        const ActionParam(
          name: 'category',
          type: ActionParamType.string,
          required: false,
          defaultValue: '其他',
          description: '分类',
        ),
        const ActionParam(
          name: 'merchant',
          type: ActionParamType.string,
          required: false,
          description: '商家',
        ),
        const ActionParam(
          name: 'note',
          type: ActionParamType.string,
          required: false,
          description: '备注',
        ),
      ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final amount = (params['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) {
      return ActionResult.needParams(
        missing: ['amount'],
        prompt: '请告诉我金额',
        actionId: id,
      );
    }

    final category = params['category'] as String? ?? '其他';
    final merchant = params['merchant'] as String?;
    final note = params['note'] as String?;

    try {
      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: TransactionType.expense,
        category: category,
        rawMerchant: merchant,
        note: note,
        date: DateTime.now(),
        accountId: 'default',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.insertTransaction(transaction);

      return ActionResult.success(
        data: {
          'transactionId': transaction.id,
          'amount': amount,
          'category': category,
        },
        responseText: '好的，已记录${category}${amount.toStringAsFixed(0)}元',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('记录失败: $e', actionId: id);
    }
  }
}

/// 添加收入行为
class _TransactionIncomeAction extends Action {
  final IDatabaseService _db;

  _TransactionIncomeAction(this._db);

  @override
  String get id => 'transaction.income';

  @override
  String get name => '添加收入';

  @override
  String get description => '记录一笔收入';

  @override
  List<String> get triggerPatterns =>
      ['收入', '赚了', '进账', '收到', '工资', '奖金', '红包', '退款', '返现'];

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'amount',
          type: ActionParamType.number,
          description: '金额',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [
        const ActionParam(
          name: 'category',
          type: ActionParamType.string,
          required: false,
          defaultValue: '收入',
          description: '分类',
        ),
      ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final amount = (params['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) {
      return ActionResult.needParams(
        missing: ['amount'],
        prompt: '请告诉我收入金额',
        actionId: id,
      );
    }

    final category = params['category'] as String? ?? '收入';

    try {
      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: TransactionType.income,
        category: category,
        date: DateTime.now(),
        accountId: 'default',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.insertTransaction(transaction);

      return ActionResult.success(
        data: {
          'transactionId': transaction.id,
          'amount': amount,
          'category': category,
        },
        responseText: '好的，已记录收入${amount.toStringAsFixed(0)}元',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('记录失败: $e', actionId: id);
    }
  }
}

/// 修改交易行为
class _TransactionModifyAction extends Action {
  final IDatabaseService _db;

  _TransactionModifyAction(this._db);

  @override
  String get id => 'transaction.modify';

  @override
  String get name => '修改交易';

  @override
  String get description => '修改一笔交易记录';

  @override
  List<String> get triggerPatterns => ['改成', '修改', '更新', '改为'];

  @override
  bool get requiresConfirmation => true;

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'transactionId',
          type: ActionParamType.string,
          description: '交易ID',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [
        const ActionParam(
          name: 'amount',
          type: ActionParamType.number,
          required: false,
          description: '新金额',
        ),
        const ActionParam(
          name: 'category',
          type: ActionParamType.string,
          required: false,
          description: '新分类',
        ),
      ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final transactionId = params['transactionId'] as String?;
    if (transactionId == null) {
      return ActionResult.needParams(
        missing: ['transactionId'],
        prompt: '要修改哪笔记录？',
        actionId: id,
      );
    }

    try {
      // 通过 ID 查找交易记录
      final transactions = await _db.getTransactions();
      final transaction = transactions.where((t) => t.id == transactionId).firstOrNull;
      if (transaction == null) {
        return ActionResult.failure('找不到这笔记录', actionId: id);
      }

      final newAmount = params['amount'] as num?;
      final newCategory = params['category'] as String?;

      final updated = transaction.copyWith(
        amount: newAmount?.toDouble() ?? transaction.amount,
        category: newCategory ?? transaction.category,
      );

      await _db.updateTransaction(updated);

      return ActionResult.success(
        data: {'transactionId': transactionId},
        responseText: '好的，已修改',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('修改失败: $e', actionId: id);
    }
  }
}

/// 删除交易行为
class _TransactionDeleteAction extends Action {
  final IDatabaseService _db;

  _TransactionDeleteAction(this._db);

  @override
  String get id => 'transaction.delete';

  @override
  String get name => '删除交易';

  @override
  String get description => '删除一笔交易记录';

  @override
  List<String> get triggerPatterns => ['删除', '删掉', '去掉', '移除'];

  @override
  bool get requiresConfirmation => true;

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'transactionId',
          type: ActionParamType.string,
          description: '交易ID',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final transactionId = params['transactionId'] as String?;
    if (transactionId == null) {
      return ActionResult.needParams(
        missing: ['transactionId'],
        prompt: '要删除哪笔记录？',
        actionId: id,
      );
    }

    try {
      await _db.deleteTransaction(transactionId);

      return ActionResult.success(
        data: {'transactionId': transactionId},
        responseText: '好的，已删除',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('删除失败: $e', actionId: id);
    }
  }
}

/// 查询交易行为
class _TransactionQueryAction extends Action {
  final IDatabaseService _db;

  _TransactionQueryAction(this._db);

  @override
  String get id => 'transaction.query';

  @override
  String get name => '查询交易';

  @override
  String get description => '查询交易记录';

  @override
  List<String> get triggerPatterns => ['查询', '查看', '看看', '最近'];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
        const ActionParam(
          name: 'limit',
          type: ActionParamType.number,
          required: false,
          defaultValue: 10,
          description: '数量限制',
        ),
      ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final limit = (params['limit'] as num?)?.toInt() ?? 10;

    try {
      final transactions = await _db.queryTransactions(limit: limit);

      return ActionResult.success(
        data: {
          'count': transactions.length,
          'transactions': transactions.map((t) => {
                'id': t.id,
                'amount': t.amount,
                'category': t.category,
                'date': t.date.toIso8601String(),
              }).toList(),
        },
        responseText: '找到${transactions.length}笔记录',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('查询失败: $e', actionId: id);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 导航行为实现
// ═══════════════════════════════════════════════════════════════════════════

/// 页面导航行为
class _NavigationAction extends Action {
  final VoiceNavigationService _navService;
  final void Function(String route)? _onNavigate;

  _NavigationAction(this._navService, this._onNavigate);

  @override
  String get id => 'navigation.page';

  @override
  String get name => '页面导航';

  @override
  String get description => '导航到指定页面';

  @override
  List<String> get triggerPatterns => ['打开', '去', '跳转', '进入'];

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'targetPage',
          type: ActionParamType.string,
          description: '目标页面',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final targetPage = params['targetPage'] as String?;
    if (targetPage == null) {
      return ActionResult.needParams(
        missing: ['targetPage'],
        prompt: '想打开哪个页面？',
        actionId: id,
      );
    }

    debugPrint('[_NavigationAction] 执行导航: targetPage=$targetPage');
    final result = _navService.parseNavigation('打开$targetPage');
    if (result.success && result.route != null) {
      debugPrint('[_NavigationAction] 解析成功: route=${result.route}, pageName=${result.pageName}');

      // 直接调用导航执行器进行实际导航
      final executed = await VoiceNavigationExecutor.instance.navigateToRoute(result.route!);
      debugPrint('[_NavigationAction] 导航执行结果: $executed');

      // 同时调用回调（如果设置了）
      _onNavigate?.call(result.route!);

      if (executed) {
        return ActionResult.success(
          data: {'route': result.route, 'executed': true},
          responseText: '好的，正在打开${result.pageName ?? targetPage}',
          actionId: id,
        );
      } else {
        return ActionResult.failure('暂时无法打开${result.pageName ?? targetPage}', actionId: id);
      }
    }

    debugPrint('[_NavigationAction] 解析失败: ${result.errorMessage}');
    return ActionResult.failure('找不到这个页面', actionId: id);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 查询行为实现
// ═══════════════════════════════════════════════════════════════════════════

/// 统计查询行为
class _StatisticsQueryAction extends Action {
  final IDatabaseService _db;

  _StatisticsQueryAction(this._db);

  @override
  String get id => 'query.statistics';

  @override
  String get name => '统计查询';

  @override
  String get description => '查询统计数据';

  @override
  List<String> get triggerPatterns => ['多少', '统计', '总共', '花了多少'];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [
        const ActionParam(
          name: 'startDate',
          type: ActionParamType.dateTime,
          required: false,
          description: '开始日期',
        ),
        const ActionParam(
          name: 'endDate',
          type: ActionParamType.dateTime,
          required: false,
          description: '结束日期',
        ),
      ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // 解析时间范围
    if (params.containsKey('startDate')) {
      startDate = params['startDate'] is DateTime
          ? params['startDate']
          : DateTime.parse(params['startDate'].toString());
    } else {
      // 默认本月
      startDate = DateTime(now.year, now.month, 1);
    }

    if (params.containsKey('endDate')) {
      endDate = params['endDate'] is DateTime
          ? params['endDate']
          : DateTime.parse(params['endDate'].toString());
    } else {
      endDate = now;
    }

    try {
      final transactions = await _db.queryTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      double totalExpense = 0;
      double totalIncome = 0;
      int count = 0;

      for (final t in transactions) {
        if (t.type == TransactionType.expense) {
          totalExpense += t.amount;
        } else if (t.type == TransactionType.income) {
          totalIncome += t.amount;
        }
        count++;
      }

      return ActionResult.success(
        data: {
          'totalExpense': totalExpense,
          'totalIncome': totalIncome,
          'count': count,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
        },
        responseText:
            '这个月共支出${totalExpense.toStringAsFixed(0)}元，收入${totalIncome.toStringAsFixed(0)}元，共$count笔记录',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('统计失败: $e', actionId: id);
    }
  }
}

/// 预算查询行为
class _BudgetQueryAction extends Action {
  @override
  String get id => 'query.budget';

  @override
  String get name => '预算查询';

  @override
  String get description => '查询预算使用情况';

  @override
  List<String> get triggerPatterns => ['预算', '剩余', '还能花'];

  @override
  List<ActionParam> get requiredParams => [];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    // TODO: 集成实际的预算服务
    return ActionResult.success(
      data: {'message': '预算查询功能待实现'},
      responseText: '预算查询功能正在开发中',
      actionId: id,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 配置行为实现
// ═══════════════════════════════════════════════════════════════════════════

/// 预算配置行为
class _BudgetConfigAction extends Action {
  final Future<void> Function(String key, dynamic value)? _onConfigChange;

  _BudgetConfigAction(this._onConfigChange);

  @override
  String get id => 'config.budget';

  @override
  String get name => '预算设置';

  @override
  String get description => '设置预算';

  @override
  List<String> get triggerPatterns => ['预算', '限额', '预算设为'];

  @override
  bool get requiresConfirmation => true;

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
          name: 'category',
          type: ActionParamType.string,
          required: false,
          description: '分类（可选，不填为总预算）',
        ),
      ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final amount = (params['amount'] as num?)?.toDouble();
    if (amount == null) {
      return ActionResult.needParams(
        missing: ['amount'],
        prompt: '预算设为多少？',
        actionId: id,
      );
    }

    final category = params['category'] as String?;
    final configKey = category != null ? 'budget.category.$category' : 'budget.monthly';

    try {
      await _onConfigChange?.call(configKey, amount);

      final message = category != null
          ? '已将${category}预算设为${amount.toStringAsFixed(0)}元'
          : '已将月度预算设为${amount.toStringAsFixed(0)}元';

      return ActionResult.success(
        data: {'configKey': configKey, 'value': amount},
        responseText: message,
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('设置失败: $e', actionId: id);
    }
  }
}

/// 账户配置行为
class _AccountConfigAction extends Action {
  final Future<void> Function(String key, dynamic value)? _onConfigChange;

  _AccountConfigAction(this._onConfigChange);

  @override
  String get id => 'config.account';

  @override
  String get name => '账户设置';

  @override
  String get description => '设置默认账户';

  @override
  List<String> get triggerPatterns => ['默认账户', '设为默认'];

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'accountName',
          type: ActionParamType.string,
          description: '账户名称',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final accountName = params['accountName'] as String?;
    if (accountName == null) {
      return ActionResult.needParams(
        missing: ['accountName'],
        prompt: '设置哪个账户为默认？',
        actionId: id,
      );
    }

    try {
      await _onConfigChange?.call('account.default', accountName);

      return ActionResult.success(
        data: {'accountName': accountName},
        responseText: '已将$accountName设为默认账户',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('设置失败: $e', actionId: id);
    }
  }
}

/// 提醒配置行为
class _ReminderConfigAction extends Action {
  final Future<void> Function(String key, dynamic value)? _onConfigChange;

  _ReminderConfigAction(this._onConfigChange);

  @override
  String get id => 'config.reminder';

  @override
  String get name => '提醒设置';

  @override
  String get description => '设置记账提醒';

  @override
  List<String> get triggerPatterns => ['提醒', '闹钟', '通知'];

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'time',
          type: ActionParamType.string,
          description: '提醒时间',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final time = params['time'] as String?;
    if (time == null) {
      return ActionResult.needParams(
        missing: ['time'],
        prompt: '什么时间提醒？',
        actionId: id,
      );
    }

    try {
      await _onConfigChange?.call('reminder.daily', time);

      return ActionResult.success(
        data: {'time': time},
        responseText: '好的，已设置每天$time提醒记账',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('设置失败: $e', actionId: id);
    }
  }
}

/// 主题配置行为
class _ThemeConfigAction extends Action {
  final Future<void> Function(String key, dynamic value)? _onConfigChange;

  _ThemeConfigAction(this._onConfigChange);

  @override
  String get id => 'config.theme';

  @override
  String get name => '主题设置';

  @override
  String get description => '切换主题模式';

  @override
  List<String> get triggerPatterns => ['主题', '深色', '浅色', '暗黑模式'];

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'mode',
          type: ActionParamType.string,
          description: '主题模式 (dark/light)',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final mode = params['mode'] as String?;
    if (mode == null) {
      return ActionResult.needParams(
        missing: ['mode'],
        prompt: '切换到深色还是浅色模式？',
        actionId: id,
      );
    }

    final isDark = mode.contains('dark') || mode.contains('深色') || mode.contains('暗');

    try {
      await _onConfigChange?.call('theme.mode', isDark ? 'dark' : 'light');

      return ActionResult.success(
        data: {'mode': isDark ? 'dark' : 'light'},
        responseText: '已切换到${isDark ? "深色" : "浅色"}模式',
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('切换失败: $e', actionId: id);
    }
  }
}
