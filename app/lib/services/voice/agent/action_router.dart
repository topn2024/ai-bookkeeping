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
import '../entity_disambiguation_service.dart';
import '../unified_intent_type.dart';
import 'action_registry.dart';
import 'actions/config_actions.dart';
import 'actions/conversation_actions.dart';
import 'actions/data_actions.dart';
import 'actions/habit_actions.dart';
import 'actions/money_age_actions.dart';
import 'actions/navigation_actions.dart';
import 'actions/share_actions.dart';
import 'actions/system_actions.dart';
import 'actions/automation_actions.dart';
import 'actions/vault_actions.dart';
import '../network_monitor.dart';
import 'safety_confirmation_service.dart';
import 'action_auto_registry.dart';

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

  /// 实体消歧服务
  final EntityDisambiguationService _disambiguationService;

  /// 页面导航回调
  void Function(String route)? onNavigate;

  /// 配置修改回调
  Future<void> Function(String key, dynamic value)? onConfigChange;

  /// 是否使用自动注册
  final bool _useAutoRegistry;

  ActionRouter({
    IDatabaseService? databaseService,
    VoiceNavigationService? navigationService,
    ActionRegistry? registry,
    EntityDisambiguationService? disambiguationService,
    bool useAutoRegistry = false,
  })  : _databaseService = databaseService ?? sl<IDatabaseService>(),
        _navigationService = navigationService ?? VoiceNavigationService(),
        _registry = registry ?? ActionRegistry.instance,
        _disambiguationService = disambiguationService ?? EntityDisambiguationService(),
        _useAutoRegistry = useAutoRegistry {
    // 注册所有内置行为
    _registerBuiltInActions();
  }

  /// 使用自动注册创建ActionRouter
  ///
  /// 这是推荐的创建方式，利用声明式的Action注册机制
  factory ActionRouter.withAutoRegistry({
    IDatabaseService? databaseService,
    VoiceNavigationService? navigationService,
    void Function(String route)? onNavigate,
    Future<void> Function(String key, dynamic value)? onConfigChange,
  }) {
    final db = databaseService ?? sl<IDatabaseService>();
    final nav = navigationService ?? VoiceNavigationService();

    // 初始化ActionProvider
    initializeActionProviders();

    // 创建依赖容器
    final deps = ActionDependencies(
      databaseService: db,
      navigationService: nav,
      onNavigate: onNavigate,
      onConfigChange: onConfigChange,
    );

    // 执行自动注册
    ActionAutoRegistry.instance.registerAll(deps);

    // 创建Router（跳过手动注册）
    final router = ActionRouter(
      databaseService: db,
      navigationService: nav,
      useAutoRegistry: true,
    );
    router.onNavigate = onNavigate;
    router.onConfigChange = onConfigChange;

    return router;
  }

  /// 注册内置行为
  void _registerBuiltInActions() {
    // 如果使用自动注册，跳过手动注册
    if (_useAutoRegistry) {
      debugPrint('[ActionRouter] 使用自动注册，跳过手动注册');
      return;
    }

    // 交易行为
    _registry.registerAll([
      _TransactionAddAction(_databaseService),
      _TransactionModifyAction(_databaseService),
      _TransactionDeleteAction(_databaseService),
      _TransactionQueryAction(_databaseService),
    ]);

    // 导航行为
    _registry.register(_NavigationAction(_navigationService, onNavigate));

    // 查询行为已整合到 data_actions.dart 中
    // - DataStatisticsAction (data.statistics)
    // - 预算查询通过 config.budget 的 query 操作实现

    // 配置行为
    _registry.registerAll([
      _BudgetConfigAction(onConfigChange),
      _AccountConfigAction(onConfigChange),
      _ReminderConfigAction(onConfigChange),
      _ThemeConfigAction(onConfigChange),
      // 新增配置操作
      CategoryConfigAction(_databaseService),
      TagConfigAction(_databaseService),
      LedgerConfigAction(_databaseService),
      MemberConfigAction(_databaseService),
      CreditCardConfigAction(_databaseService),
      SavingsGoalConfigAction(_databaseService),
      RecurringTransactionConfigAction(_databaseService),
    ]);

    // 高级功能行为
    _registry.registerAll([
      // 小金库操作
      VaultQueryAction(_databaseService),
      VaultCreateAction(_databaseService),
      VaultTransferAction(_databaseService),
      VaultBudgetAction(_databaseService),
      // 钱龄操作
      MoneyAgeQueryAction(_databaseService),
      MoneyAgeReminderAction(_databaseService),
      MoneyAgeReportAction(_databaseService),
      // 数据操作
      DataExportAction(_databaseService),
      DataBackupAction(_databaseService),
      DataStatisticsAction(_databaseService),
      DataReportAction(_databaseService),
      // 习惯操作
      HabitQueryAction(_databaseService),
      HabitAnalysisAction(_databaseService),
      HabitReminderAction(_databaseService),
      // 分享操作
      ShareTransactionAction(_databaseService),
      ShareReportAction(_databaseService),
      ShareBudgetAction(_databaseService),
    ]);

    // 导航行为
    _registry.registerAll([
      NavigationBackAction(),
      NavigationHomeAction(),
    ]);

    // 会话控制行为
    _registry.registerAll([
      ConversationConfirmAction(),
      ConversationCancelAction(),
      ConversationClarifyAction(),
      ConversationGreetingAction(),
      ConversationHelpAction(),
      UnknownIntentAction(),
    ]);

    // 系统操作
    // 注：system.help 改为 conversation.help，由 ConversationHelpAction 处理
    _registry.registerAll([
      SystemSettingsAction(_databaseService),
      SystemAboutAction(),
      SystemFeedbackAction(),
    ]);

    // 自动化操作
    _registry.registerAll([
      ScreenRecognitionAction(_databaseService),
      AlipayBillSyncAction(_databaseService),
      WeChatBillSyncAction(_databaseService),
      BankBillSyncAction(_databaseService),
      EmailBillParseAction(_databaseService),
      ScheduledBookkeepingAction(_databaseService),
    ]);

    // 注册意图映射：LLM输出的意图ID → 实际的ActionID
    // 这解决了LLM使用 query.* 而实际Action使用 data.* 的命名不一致问题
    _registry.mapIntents({
      'query.statistics': 'data.statistics',  // 统计查询（今天/本月花了多少）
      'query.trend': 'data.statistics',       // 趋势查询
      'query.transaction': 'transaction.query', // 交易记录查询
      'query.budget': 'config.budget',        // 预算查询
    });

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

    // 对于需要目标记录的操作（删除、修改），使用消歧服务解析指代
    var entities = Map<String, dynamic>.from(intent.entities);
    if (_needsDisambiguation(action.id, entities)) {
      debugPrint('[ActionRouter] 需要消歧: ${action.id}');
      final disambiguationResult = await _disambiguateTargetWithResult(intent.rawInput, entities);

      if (disambiguationResult.success) {
        entities = disambiguationResult.entities!;
      } else {
        // 消歧失败，返回需要澄清的结果
        debugPrint('[ActionRouter] 消歧失败: ${disambiguationResult.prompt}');
        return ActionResult.needParams(
          missing: ['transactionId'],
          prompt: disambiguationResult.prompt ?? '要操作哪笔记录？',
          actionId: action.id,
        );
      }
    }

    // 执行行为
    try {
      return await action.execute(entities);
    } catch (e) {
      debugPrint('[ActionRouter] 执行失败: $e');
      return ActionResult.failure(
        '执行失败: ${e.toString()}',
        actionId: action.id,
      );
    }
  }

  /// 使用统一意图类型执行
  ///
  /// 提供基于 [UnifiedIntentType] 的执行入口，支持新的统一意图系统
  Future<ActionResult> executeByIntentType(
    UnifiedIntentType intentType, {
    Map<String, dynamic> params = const {},
    String? rawInput,
  }) async {
    debugPrint('[ActionRouter] 使用统一意图类型执行: ${intentType.id}');

    // 通过意图ID查找对应的Action
    final action = _registry.findById(intentType.id);

    if (action == null) {
      debugPrint('[ActionRouter] 未找到对应的Action: ${intentType.id}');
      return ActionResult.unsupported(intentType.id);
    }

    // 合并参数
    final entities = Map<String, dynamic>.from(params);
    if (rawInput != null) {
      entities['_rawInput'] = rawInput;
    }

    // 对于需要目标记录的操作，使用消歧服务解析指代
    if (_needsDisambiguation(action.id, entities) && rawInput != null) {
      debugPrint('[ActionRouter] 需要消歧: ${action.id}');
      final disambiguationResult = await _disambiguateTargetWithResult(rawInput, entities);

      if (disambiguationResult.success) {
        return await action.execute(disambiguationResult.entities!);
      } else {
        return ActionResult.needParams(
          missing: ['transactionId'],
          prompt: disambiguationResult.prompt ?? '要操作哪笔记录？',
          actionId: action.id,
        );
      }
    }

    // 执行行为
    try {
      return await action.execute(entities);
    } catch (e) {
      debugPrint('[ActionRouter] 执行失败: $e');
      return ActionResult.failure(
        '执行失败: ${e.toString()}',
        actionId: action.id,
      );
    }
  }

  /// 根据统一意图结果执行
  ///
  /// 接收 [UnifiedIntentResult] 并执行对应的行为
  Future<ActionResult> executeUnifiedIntent(UnifiedIntentResult intentResult) async {
    return executeByIntentType(
      intentResult.intentType,
      params: intentResult.slots,
      rawInput: intentResult.rawInput,
    );
  }

  /// 检查是否需要消歧
  bool _needsDisambiguation(String actionId, Map<String, dynamic> entities) {
    // 删除和修改操作需要 transactionId
    const needsTargetActions = ['transaction.delete', 'transaction.modify'];
    if (!needsTargetActions.contains(actionId)) {
      return false;
    }
    // 如果已经有 transactionId，不需要消歧
    if (entities['transactionId'] != null) {
      return false;
    }
    return true;
  }

  /// 消歧结果（带提示信息）
  Future<_DisambiguationResultWithPrompt> _disambiguateTargetWithResult(
    String userInput,
    Map<String, dynamic> entities,
  ) async {
    debugPrint('[ActionRouter] 开始消歧: "$userInput"');

    try {
      final result = await _disambiguationService.disambiguate(
        userInput,
        queryCallback: (conditions) async {
          return await _queryTransactions(conditions);
        },
      );

      debugPrint('[ActionRouter] 消歧结果: ${result.status}');

      switch (result.status) {
        case DisambiguationStatus.resolved:
          final resolvedRecord = result.resolvedRecord;
          if (resolvedRecord != null) {
            debugPrint('[ActionRouter] 消歧成功: transactionId=${resolvedRecord.id}');
            return _DisambiguationResultWithPrompt.success({
              ...entities,
              'transactionId': resolvedRecord.id,
              '_resolvedRecord': resolvedRecord,
            });
          }
          return _DisambiguationResultWithPrompt.failure('找不到匹配的记录');

        case DisambiguationStatus.needClarification:
          // 需要追问澄清，使用消歧服务返回的提示
          final prompt = result.clarificationPrompt ?? '你说的是哪一笔？';
          debugPrint('[ActionRouter] 需要澄清: $prompt');
          return _DisambiguationResultWithPrompt.failure(prompt);

        case DisambiguationStatus.needMoreInfo:
          return _DisambiguationResultWithPrompt.failure('请说得更具体一些，比如"昨天那笔"或"午餐35块那笔"');

        case DisambiguationStatus.noMatch:
          return _DisambiguationResultWithPrompt.failure('没有找到这笔记录，请确认后重试');

        case DisambiguationStatus.noReference:
          // 没有指代词，尝试获取最近的记录
          debugPrint('[ActionRouter] 没有指代词，尝试获取最近记录');
          final recentRecord = await _getRecentRecord();
          if (recentRecord != null) {
            debugPrint('[ActionRouter] 使用最近记录: transactionId=${recentRecord.id}');
            return _DisambiguationResultWithPrompt.success({
              ...entities,
              'transactionId': recentRecord.id,
              '_resolvedRecord': recentRecord,
            });
          }
          return _DisambiguationResultWithPrompt.failure('没有最近的记录可以操作');
      }
    } catch (e) {
      debugPrint('[ActionRouter] 消歧错误: $e');
      return _DisambiguationResultWithPrompt.failure('查询记录时出错');
    }
  }

  /// 查询候选交易记录
  Future<List<TransactionRecord>> _queryTransactions(QueryConditions conditions) async {
    try {
      final transactions = await _databaseService.queryTransactions(
        startDate: conditions.startDate,
        endDate: conditions.endDate,
        category: conditions.categoryHint,
        merchant: conditions.merchantHint,
        minAmount: conditions.amountMin,
        maxAmount: conditions.amountMax,
        limit: 20,
      );

      // 转换为消歧服务使用的记录格式
      return transactions.map((t) => TransactionRecord(
        id: t.id,
        amount: t.amount,
        category: t.category,
        description: t.note,
        merchant: t.rawMerchant,
        date: t.date,
        type: t.type.name,
      )).toList();
    } catch (e) {
      debugPrint('[ActionRouter] 查询交易失败: $e');
      return [];
    }
  }

  /// 获取最近一条记录
  Future<TransactionRecord?> _getRecentRecord() async {
    try {
      final now = DateTime.now();
      final transactions = await _databaseService.queryTransactions(
        startDate: now.subtract(const Duration(hours: 24)),
        endDate: now,
        limit: 10,
      );

      if (transactions.isEmpty) {
        return null;
      }

      // 按创建时间排序，取最近的一条
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final t = transactions.first;

      return TransactionRecord(
        id: t.id,
        amount: t.amount,
        category: t.category,
        description: t.note,
        merchant: t.rawMerchant,
        date: t.date,
        type: t.type.name,
      );
    } catch (e) {
      debugPrint('[ActionRouter] 获取最近记录失败: $e');
      return null;
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

/// 添加交易行为（统一支持支出/收入/转账）
///
/// 通过 transactionType 参数区分交易类型：
/// - expense: 支出（默认）
/// - income: 收入
/// - transfer: 转账
class _TransactionAddAction extends Action {
  final IDatabaseService _db;

  _TransactionAddAction(this._db);

  @override
  String get id => 'transaction.add';

  @override
  String get name => '添加交易';

  @override
  String get description => '记录一笔交易（支出/收入/转账）';

  @override
  List<String> get triggerPatterns => [
    // 支出关键词
    '花了', '买了', '付了', '消费', '支出',
    // 收入关键词
    '收入', '赚了', '进账', '收到', '工资', '奖金', '红包', '退款', '返现',
    // 通用关键词
    '记账', '记录',
  ];

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
      name: 'transactionType',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'expense',
      description: '交易类型: expense/income/transfer',
    ),
    const ActionParam(
      name: 'category',
      type: ActionParamType.string,
      required: false,
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
    const ActionParam(
      name: 'accountId',
      type: ActionParamType.string,
      required: false,
      defaultValue: 'default',
      description: '账户ID',
    ),
    const ActionParam(
      name: 'toAccountId',
      type: ActionParamType.string,
      required: false,
      description: '目标账户ID（转账时使用）',
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

    // 解析交易类型
    final typeStr = params['transactionType'] as String? ?? 'expense';
    TransactionType transactionType;
    String defaultCategory;

    switch (typeStr.toLowerCase()) {
      case 'income':
        transactionType = TransactionType.income;
        defaultCategory = '收入';
        break;
      case 'transfer':
        transactionType = TransactionType.transfer;
        defaultCategory = '转账';
        break;
      case 'expense':
      default:
        transactionType = TransactionType.expense;
        defaultCategory = '其他';
        break;
    }

    final category = params['category'] as String? ?? defaultCategory;
    final merchant = params['merchant'] as String?;
    final note = params['note'] as String?;
    final accountId = params['accountId'] as String? ?? 'default';
    final toAccountId = params['toAccountId'] as String?;

    try {
      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: transactionType,
        category: category,
        rawMerchant: merchant,
        note: note,
        date: DateTime.now(),
        accountId: accountId,
        toAccountId: toAccountId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.insertTransaction(transaction);

      // 根据类型生成响应文本
      String responseText;
      switch (transactionType) {
        case TransactionType.income:
          responseText = '好的，已记录收入${amount.toStringAsFixed(0)}元';
          break;
        case TransactionType.transfer:
          responseText = '好的，已记录转账${amount.toStringAsFixed(0)}元';
          break;
        case TransactionType.expense:
        default:
          responseText = '好的，已记录$category${amount.toStringAsFixed(0)}元';
          break;
      }

      return ActionResult.success(
        data: {
          'transactionId': transaction.id,
          'amount': amount,
          'category': category,
          'transactionType': typeStr,
        },
        responseText: responseText,
        actionId: id,
      );
    } catch (e) {
      return ActionResult.failure('记录失败: $e', actionId: id);
    }
  }
}

/// 修改交易行为（支持8字段修改）
///
/// 支持的字段：
/// 1. amount - 金额
/// 2. category - 分类
/// 3. subCategory - 子分类
/// 4. description/note - 备注
/// 5. date - 日期
/// 6. account - 账户
/// 7. tags - 标签
/// 8. transactionType/type - 交易类型（支出/收入/转账）
class _TransactionModifyAction extends Action {
  final IDatabaseService _db;
  final SafetyConfirmationService _safetyService;

  _TransactionModifyAction(this._db)
      : _safetyService = SafetyConfirmationService();

  @override
  String get id => 'transaction.modify';

  @override
  String get name => '修改交易';

  @override
  String get description => '修改一笔交易记录，支持8个字段的修改';

  @override
  List<String> get triggerPatterns => [
        '改成',
        '修改',
        '更新',
        '改为',
        '换成',
        '调整',
      ];

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
        // 1. 金额
        const ActionParam(
          name: 'amount',
          type: ActionParamType.number,
          required: false,
          description: '新金额',
        ),
        // 2. 分类
        const ActionParam(
          name: 'category',
          type: ActionParamType.string,
          required: false,
          description: '新分类',
        ),
        // 3. 子分类
        const ActionParam(
          name: 'subCategory',
          type: ActionParamType.string,
          required: false,
          description: '新子分类（如：早餐、午餐、晚餐）',
        ),
        // 4. 备注/描述
        const ActionParam(
          name: 'description',
          type: ActionParamType.string,
          required: false,
          description: '新备注/描述',
        ),
        const ActionParam(
          name: 'note',
          type: ActionParamType.string,
          required: false,
          description: '新备注（同description）',
        ),
        // 5. 日期
        const ActionParam(
          name: 'date',
          type: ActionParamType.dateTime,
          required: false,
          description: '新日期',
        ),
        // 6. 账户
        const ActionParam(
          name: 'account',
          type: ActionParamType.string,
          required: false,
          description: '新账户',
        ),
        // 7. 标签
        const ActionParam(
          name: 'tags',
          type: ActionParamType.list,
          required: false,
          description: '新标签列表',
        ),
        const ActionParam(
          name: 'addTag',
          type: ActionParamType.string,
          required: false,
          description: '添加标签',
        ),
        const ActionParam(
          name: 'removeTag',
          type: ActionParamType.string,
          required: false,
          description: '移除标签',
        ),
        // 8. 交易类型
        const ActionParam(
          name: 'transactionType',
          type: ActionParamType.string,
          required: false,
          description: '新交易类型（expense/income/transfer）',
        ),
        const ActionParam(
          name: 'type',
          type: ActionParamType.string,
          required: false,
          description: '新类型（同transactionType）',
        ),
        // 内部参数
        const ActionParam(
          name: '_skipConfirmation',
          type: ActionParamType.boolean,
          required: false,
          description: '跳过确认（已经确认过）',
        ),
      ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final transactionId = params['transactionId'] as String?;
    final skipConfirmation = params['_skipConfirmation'] as bool? ?? false;

    debugPrint('[ModifyAction] 执行修改，transactionId: $transactionId');

    if (transactionId == null) {
      return ActionResult.needParams(
        missing: ['transactionId'],
        prompt: '要修改哪笔记录？',
        actionId: id,
      );
    }

    try {
      // 1. 查找交易记录
      final transactions = await _db.getTransactions();
      final transaction = transactions.where((t) => t.id == transactionId).firstOrNull;
      if (transaction == null) {
        return ActionResult.failure('找不到这笔记录', actionId: id);
      }

      // 2. 收集修改字段
      final modifications = <String, dynamic>{};

      // 金额
      if (params.containsKey('amount') && params['amount'] != null) {
        modifications['amount'] = params['amount'];
      }

      // 分类
      if (params.containsKey('category') && params['category'] != null) {
        modifications['category'] = params['category'];
      }

      // 子分类
      if (params.containsKey('subCategory') && params['subCategory'] != null) {
        modifications['subCategory'] = params['subCategory'];
      }

      // 备注/描述
      final note = params['description'] ?? params['note'];
      if (note != null) {
        modifications['note'] = note;
      }

      // 日期
      if (params.containsKey('date') && params['date'] != null) {
        var dateValue = params['date'];
        if (dateValue is String) {
          dateValue = DateTime.tryParse(dateValue) ?? _parseRelativeDate(dateValue);
        }
        if (dateValue != null) {
          modifications['date'] = dateValue;
        }
      }

      // 账户
      if (params.containsKey('account') && params['account'] != null) {
        modifications['account'] = params['account'];
      }

      // 标签
      if (params.containsKey('tags') && params['tags'] != null) {
        modifications['tags'] = params['tags'];
      }
      if (params.containsKey('addTag') && params['addTag'] != null) {
        modifications['addTag'] = params['addTag'];
      }
      if (params.containsKey('removeTag') && params['removeTag'] != null) {
        modifications['removeTag'] = params['removeTag'];
      }

      // 交易类型
      final newType = params['transactionType'] ?? params['type'];
      if (newType != null) {
        modifications['transactionType'] = newType;
      }

      if (modifications.isEmpty) {
        return ActionResult.needParams(
          missing: ['amount', 'category', 'note'],
          prompt: '要修改什么？可以修改金额、分类、备注、日期、账户、标签或类型',
          actionId: id,
        );
      }

      debugPrint('[ModifyAction] 修改字段: ${modifications.keys.join(", ")}');

      // 3. 转换为消歧服务使用的记录格式
      final record = TransactionRecord(
        id: transaction.id,
        amount: transaction.amount,
        category: transaction.category,
        description: transaction.note,
        merchant: transaction.rawMerchant,
        date: transaction.date,
        type: transaction.type.name,
      );

      // 4. 评估确认级别
      final safetyResult = _safetyService.evaluateModifyConfirmation(record, modifications);
      debugPrint('[ModifyAction] 确认级别: ${safetyResult.level}');

      // 5. 如果需要确认且未跳过确认
      if (!skipConfirmation && safetyResult.level != ConfirmationLevel.none) {
        switch (safetyResult.level) {
          case ConfirmationLevel.light:
            return ActionResult.lightConfirmation(
              message: safetyResult.confirmPrompt,
              data: {
                ...modifications,
                'transactionId': transactionId,
              },
              actionId: id,
            );

          case ConfirmationLevel.standard:
            return ActionResult.standardConfirmation(
              message: safetyResult.confirmPrompt,
              data: {
                ...modifications,
                'transactionId': transactionId,
              },
              actionId: id,
            );

          case ConfirmationLevel.strict:
            return ActionResult.strictConfirmation(
              message: safetyResult.confirmPrompt,
              data: {
                ...modifications,
                'transactionId': transactionId,
              },
              actionId: id,
            );

          case ConfirmationLevel.voiceProhibited:
            return ActionResult.blocked(
              reason: safetyResult.blockReason ?? '此操作需要手动确认',
              redirectRoute: '/transaction/$transactionId',
              actionId: id,
            );

          case ConfirmationLevel.none:
            break;
        }
      }

      // 6. 执行修改
      var updated = transaction;

      if (modifications.containsKey('amount')) {
        updated = updated.copyWith(amount: (modifications['amount'] as num).toDouble());
      }
      if (modifications.containsKey('category')) {
        updated = updated.copyWith(category: modifications['category'] as String);
      }
      if (modifications.containsKey('note')) {
        updated = updated.copyWith(note: modifications['note'] as String);
      }
      if (modifications.containsKey('date')) {
        updated = updated.copyWith(date: modifications['date'] as DateTime);
      }
      if (modifications.containsKey('transactionType')) {
        final typeStr = modifications['transactionType'] as String;
        TransactionType? type;
        if (typeStr.contains('支出') || typeStr == 'expense') {
          type = TransactionType.expense;
        } else if (typeStr.contains('收入') || typeStr == 'income') {
          type = TransactionType.income;
        } else if (typeStr.contains('转账') || typeStr == 'transfer') {
          type = TransactionType.transfer;
        }
        if (type != null) {
          updated = updated.copyWith(type: type);
        }
      }

      await _db.updateTransaction(updated);

      // 7. 生成响应
      final changedFields = modifications.keys.where((k) => !k.startsWith('_')).toList();
      final responseText = changedFields.length == 1
          ? '好的，已将${_getFieldName(changedFields.first)}改为${_formatValue(changedFields.first, modifications[changedFields.first])}'
          : '好的，已修改${changedFields.length}个字段';

      return ActionResult.success(
        data: {
          'transactionId': transactionId,
          'modifications': modifications,
        },
        responseText: responseText,
        actionId: id,
      );
    } catch (e) {
      debugPrint('[ModifyAction] 修改失败: $e');
      return ActionResult.failure('修改失败: $e', actionId: id);
    }
  }

  /// 解析相对日期
  DateTime? _parseRelativeDate(String text) {
    final now = DateTime.now();

    if (text.contains('今天')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (text.contains('昨天')) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (text.contains('前天')) {
      return DateTime(now.year, now.month, now.day - 2);
    }

    // 解析 "X月X日" 格式
    final dateMatch = RegExp(r'(\d+)月(\d+)[日号]').firstMatch(text);
    if (dateMatch != null) {
      final month = int.tryParse(dateMatch.group(1) ?? '');
      final day = int.tryParse(dateMatch.group(2) ?? '');
      if (month != null && day != null) {
        return DateTime(now.year, month, day);
      }
    }

    return null;
  }

  /// 获取字段中文名
  String _getFieldName(String field) {
    const fieldNames = {
      'amount': '金额',
      'category': '分类',
      'subCategory': '子分类',
      'description': '备注',
      'note': '备注',
      'date': '日期',
      'account': '账户',
      'tags': '标签',
      'addTag': '标签',
      'removeTag': '标签',
      'transactionType': '类型',
      'type': '类型',
    };
    return fieldNames[field] ?? field;
  }

  /// 格式化值显示
  String _formatValue(String field, dynamic value) {
    if (field == 'amount' && value is num) {
      return '¥${value.toStringAsFixed(2)}';
    }
    if (field == 'date' && value is DateTime) {
      return '${value.month}月${value.day}日';
    }
    return value.toString();
  }
}

/// 删除交易行为（支持4级确认系统）
///
/// 确认级别：
/// - Level 1: 轻量确认（单笔小额<100元，24小时内）
/// - Level 2: 标准确认（大额≥100元或历史记录）
/// - Level 3: 严格确认（批量删除≥2笔）
/// - Level 4: 禁止语音（清空回收站、删除账本等高风险操作）
class _TransactionDeleteAction extends Action {
  final IDatabaseService _db;
  final SafetyConfirmationService _safetyService;

  _TransactionDeleteAction(this._db)
      : _safetyService = SafetyConfirmationService();

  @override
  String get id => 'transaction.delete';

  @override
  String get name => '删除交易';

  @override
  String get description => '删除一笔或多笔交易记录，支持4级确认系统';

  @override
  List<String> get triggerPatterns => [
        '删除',
        '删掉',
        '去掉',
        '移除',
        '清空',
        '批量删除',
      ];

  @override
  bool get requiresConfirmation => true;

  @override
  List<ActionParam> get requiredParams => [
        const ActionParam(
          name: 'transactionId',
          type: ActionParamType.string,
          description: '交易ID（单笔删除）或多个ID用逗号分隔',
        ),
      ];

  @override
  List<ActionParam> get optionalParams => [
        const ActionParam(
          name: '_rawInput',
          type: ActionParamType.string,
          required: false,
          description: '原始用户输入（用于检测高风险操作）',
        ),
        const ActionParam(
          name: '_resolvedRecord',
          type: ActionParamType.map,
          required: false,
          description: '消歧后的记录对象',
        ),
        const ActionParam(
          name: '_skipConfirmation',
          type: ActionParamType.boolean,
          required: false,
          description: '跳过确认（已经确认过）',
        ),
      ];

  @override
  Future<ActionResult> execute(Map<String, dynamic> params) async {
    final rawInput = params['_rawInput'] as String? ?? '';
    final skipConfirmation = params['_skipConfirmation'] as bool? ?? false;

    debugPrint('[DeleteAction] 执行删除，rawInput: $rawInput, skipConfirmation: $skipConfirmation');

    // 1. 检查高风险操作
    final confirmResult = _safetyService.evaluateDeleteConfirmation(rawInput, []);
    if (confirmResult.isBlocked) {
      debugPrint('[DeleteAction] 高风险操作被阻止');
      return ActionResult.blocked(
        reason: confirmResult.blockReason ?? '此操作无法通过语音完成',
        redirectRoute: confirmResult.redirectRoute ?? '/settings',
        actionId: id,
      );
    }

    // 2. 获取目标记录
    final transactionId = params['transactionId'] as String?;
    if (transactionId == null) {
      return ActionResult.needParams(
        missing: ['transactionId'],
        prompt: '要删除哪笔记录？',
        actionId: id,
      );
    }

    try {
      // 查找交易记录
      final transactions = await _db.getTransactions();

      // 支持多个ID（用逗号分隔）
      final ids = transactionId.split(',').map((s) => s.trim()).toList();
      final targetTransactions = transactions.where((t) => ids.contains(t.id)).toList();

      if (targetTransactions.isEmpty) {
        return ActionResult.failure('找不到要删除的记录', actionId: id);
      }

      // 转换为消歧服务使用的记录格式
      final records = targetTransactions.map((t) => TransactionRecord(
        id: t.id,
        amount: t.amount,
        category: t.category,
        description: t.note,
        merchant: t.rawMerchant,
        date: t.date,
        type: t.type.name,
      )).toList();

      // 3. 评估确认级别
      final safetyResult = _safetyService.evaluateDeleteConfirmation(rawInput, records);
      debugPrint('[DeleteAction] 确认级别: ${safetyResult.level}');

      // 4. 如果需要确认且未跳过确认
      if (!skipConfirmation && safetyResult.level != ConfirmationLevel.none) {
        // 返回需要确认的结果
        switch (safetyResult.level) {
          case ConfirmationLevel.light:
            return ActionResult.lightConfirmation(
              message: safetyResult.confirmPrompt,
              data: {
                ...?safetyResult.data,
                'transactionId': transactionId,
                '_rawInput': rawInput,
              },
              actionId: id,
            );

          case ConfirmationLevel.standard:
            return ActionResult.standardConfirmation(
              message: safetyResult.confirmPrompt,
              data: {
                ...?safetyResult.data,
                'transactionId': transactionId,
                '_rawInput': rawInput,
              },
              actionId: id,
            );

          case ConfirmationLevel.strict:
            return ActionResult.strictConfirmation(
              message: safetyResult.confirmPrompt,
              data: {
                ...?safetyResult.data,
                'transactionId': transactionId,
                '_rawInput': rawInput,
              },
              actionId: id,
            );

          case ConfirmationLevel.voiceProhibited:
            return ActionResult.blocked(
              reason: safetyResult.blockReason ?? '此操作无法通过语音完成',
              redirectRoute: safetyResult.redirectRoute ?? '/settings',
              actionId: id,
            );

          case ConfirmationLevel.none:
            break;
        }
      }

      // 5. 执行删除
      for (final t in targetTransactions) {
        await _db.deleteTransaction(t.id);
      }

      // 生成响应
      final count = targetTransactions.length;
      final totalAmount = targetTransactions.fold<double>(0, (sum, t) => sum + t.amount);
      final responseText = count == 1
          ? '好的，已删除，可在回收站恢复'
          : '已删除${count}笔记录，共¥${totalAmount.toStringAsFixed(2)}，可在回收站恢复';

      return ActionResult.success(
        data: {
          'transactionIds': ids,
          'count': count,
          'totalAmount': totalAmount,
          'canRecover': true,
        },
        responseText: responseText,
        actionId: id,
      );
    } catch (e) {
      debugPrint('[DeleteAction] 删除失败: $e');
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
// 配置行为实现
// 注：查询行为已整合到 data_actions.dart (DataStatisticsAction, DataReportAction)
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

// ═══════════════════════════════════════════════════════════════════════════
// 内部辅助类
// ═══════════════════════════════════════════════════════════════════════════

/// 消歧结果（带提示信息）
class _DisambiguationResultWithPrompt {
  /// 是否成功
  final bool success;

  /// 解析后的实体（成功时有值）
  final Map<String, dynamic>? entities;

  /// 提示信息（失败时有值）
  final String? prompt;

  _DisambiguationResultWithPrompt._({
    required this.success,
    this.entities,
    this.prompt,
  });

  /// 创建成功结果
  factory _DisambiguationResultWithPrompt.success(Map<String, dynamic> entities) {
    return _DisambiguationResultWithPrompt._(
      success: true,
      entities: entities,
    );
  }

  /// 创建失败结果
  factory _DisambiguationResultWithPrompt.failure(String prompt) {
    return _DisambiguationResultWithPrompt._(
      success: false,
      prompt: prompt,
    );
  }
}
