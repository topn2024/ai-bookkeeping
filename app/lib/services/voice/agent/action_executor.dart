/// 行为执行器
///
/// 负责执行行为并处理参数补全和确认机制
///
/// 核心职责：
/// - 参数验证：检测缺失参数
/// - 执行控制：调用行为执行
/// - 确认机制：支持4级确认系统（轻量/标准/严格/禁止）
/// - 追问生成：缺少参数时生成追问
///
/// 4级确认系统：
/// - Level 1 (light): 轻量确认 - 语音确认即可
/// - Level 2 (standard): 标准确认 - 语音或屏幕确认
/// - Level 3 (strict): 严格确认 - 必须屏幕点击
/// - Level 4 (voiceProhibited): 禁止语音 - 必须手动操作
library;

import 'package:flutter/foundation.dart';
import 'action_registry.dart';
import '../network_monitor.dart';

/// 执行状态
enum ExecutionState {
  /// 空闲
  idle,

  /// 等待参数补充
  waitingForParams,

  /// 等待确认
  waitingForConfirmation,

  /// 执行中
  executing,

  /// 已完成
  completed,

  /// 失败
  failed,
}

/// 待确认的行为
class PendingAction {
  /// 行为
  final Action action;

  /// 参数
  final Map<String, dynamic> params;

  /// 缺失的参数
  final List<String> missingParams;

  /// 确认消息
  final String? confirmationMessage;

  /// 确认级别（4级确认系统）
  final ActionConfirmLevel confirmLevel;

  /// 是否允许语音确认
  final bool allowVoiceConfirm;

  /// 是否需要屏幕确认
  final bool requireScreenConfirm;

  /// 创建时间
  final DateTime createdAt;

  /// 超时时间（秒）
  final int timeoutSeconds;

  PendingAction({
    required this.action,
    required this.params,
    this.missingParams = const [],
    this.confirmationMessage,
    this.confirmLevel = ActionConfirmLevel.standard,
    this.allowVoiceConfirm = true,
    this.requireScreenConfirm = false,
    int? timeoutSeconds,
  })  : createdAt = DateTime.now(),
        timeoutSeconds = timeoutSeconds ?? 60;

  /// 是否已超时
  bool get isExpired {
    return DateTime.now().difference(createdAt).inSeconds > timeoutSeconds;
  }

  /// 是否等待参数
  bool get isWaitingForParams => missingParams.isNotEmpty;

  /// 是否等待确认
  bool get isWaitingForConfirmation =>
      confirmationMessage != null && missingParams.isEmpty;
}

/// 多意图待确认项
class MultiIntentItem {
  /// 意图
  final IntentResult intent;

  /// 关联的行为
  final Action? action;

  /// 参数
  final Map<String, dynamic> params;

  /// 缺失的参数
  final List<String> missingParams;

  /// 执行状态
  bool executed;

  /// 执行结果
  ActionResult? result;

  MultiIntentItem({
    required this.intent,
    this.action,
    required this.params,
    this.missingParams = const [],
    this.executed = false,
    this.result,
  });

  /// 是否完整（可执行）
  bool get isComplete => missingParams.isEmpty && action != null;

  /// 获取描述
  String get description {
    final amount = params['amount'];
    final categoryName = params['category'] as String?;
    final merchant = params['merchant'] as String?;
    final transactionType = params['transactionType'] as String?;

    // 根据交易类型确定显示文本
    String typeLabel;
    switch (transactionType) {
      case 'income':
        typeLabel = '收入';
        break;
      case 'transfer':
        typeLabel = '转账';
        break;
      case 'expense':
      default:
        typeLabel = '支出';
        break;
    }

    if (amount != null) {
      final amountStr = '${amount}元';
      if (categoryName != null && categoryName.isNotEmpty) {
        return '$typeLabel $amountStr · $categoryName${merchant != null ? ' ($merchant)' : ''}';
      }
      return '$typeLabel $amountStr${merchant != null ? ' ($merchant)' : ''}';
    }
    return intent.rawInput;
  }
}

/// 多意图待确认状态
class MultiIntentPendingAction {
  /// 所有意图项
  final List<MultiIntentItem> items;

  /// 原始输入
  final String rawInput;

  /// 创建时间
  final DateTime createdAt;

  /// 超时时间（秒）
  final int timeoutSeconds;

  MultiIntentPendingAction({
    required this.items,
    required this.rawInput,
    int? timeoutSeconds,
  })  : createdAt = DateTime.now(),
        timeoutSeconds = timeoutSeconds ?? 120;

  /// 是否已超时
  bool get isExpired {
    return DateTime.now().difference(createdAt).inSeconds > timeoutSeconds;
  }

  /// 完整的意图项
  List<MultiIntentItem> get completeItems =>
      items.where((item) => item.isComplete).toList();

  /// 不完整的意图项（需要补充参数）
  List<MultiIntentItem> get incompleteItems =>
      items.where((item) => !item.isComplete).toList();

  /// 是否有不完整的意图
  bool get hasIncomplete => incompleteItems.isNotEmpty;

  /// 总金额
  double get totalAmount {
    double total = 0;
    for (final item in completeItems) {
      final amount = item.params['amount'];
      if (amount is num) {
        total += amount.toDouble();
      }
    }
    return total;
  }

  /// 生成确认提示
  String generatePrompt() {
    final buffer = StringBuffer();

    if (completeItems.isNotEmpty) {
      buffer.writeln('识别到${completeItems.length}条记录：');
      for (var i = 0; i < completeItems.length; i++) {
        buffer.writeln('  ${i + 1}. ${completeItems[i].description}');
      }
      buffer.writeln('共${_formatAmount(totalAmount)}');
    }

    if (incompleteItems.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('以下内容需要补充金额：');
      for (var i = 0; i < incompleteItems.length; i++) {
        buffer.writeln('  ${i + 1}. ${incompleteItems[i].description}');
      }
    }

    if (completeItems.isNotEmpty) {
      buffer.writeln();
      if (incompleteItems.isNotEmpty) {
        buffer.write('请补充金额或说"确认"记录已有内容');
      } else {
        buffer.write('确认记录吗？');
      }
    }

    return buffer.toString();
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return '${amount.round()}元';
    }
    return '${amount.toStringAsFixed(2)}元';
  }
}

/// 超时事件类型
enum TimeoutEventType {
  /// 参数补充超时
  paramCompletion,

  /// 确认超时
  confirmation,

  /// 多意图确认超时
  multiIntentConfirmation,
}

/// 超时事件
class TimeoutEvent {
  /// 事件类型
  final TimeoutEventType type;

  /// 相关的Action ID
  final String? actionId;

  /// 提示消息
  final String message;

  /// 原始参数
  final Map<String, dynamic>? params;

  const TimeoutEvent({
    required this.type,
    this.actionId,
    required this.message,
    this.params,
  });
}

/// 超时回调类型
typedef TimeoutCallback = void Function(TimeoutEvent event);

/// 行为执行器
class ActionExecutor {
  /// 行为注册表
  final ActionRegistry _registry;

  /// 当前执行状态
  ExecutionState _state = ExecutionState.idle;

  /// 待处理的行为
  PendingAction? _pendingAction;

  /// 多意图待处理
  MultiIntentPendingAction? _multiIntentPending;

  /// 大金额确认阈值
  final double largeAmountThreshold;

  /// 超时回调
  TimeoutCallback? onTimeout;

  /// 需要确认的行为类型
  final Set<String> _confirmRequiredActions = {
    'transaction.delete',
    'config.reset',
    'data.clear',
  };

  /// 意图ID到Action ID的映射表
  /// 用于处理LLM返回的意图格式与实际注册的Action ID不一致的情况
  static const Map<String, String> _intentToActionMapping = {
    // query.* -> transaction.query 或对应的查询Action
    'query.statistics': 'transaction.query',
    'query.trend': 'transaction.query',
    'query.budget': 'config.budget',
    'query.transaction': 'transaction.query',

    // config.budget.* -> config.budget
    'config.budget.monthly': 'config.budget',
    'config.budget.category': 'config.budget',

    // navigation 别名
    'navigation.tab': 'navigation.page',
    'navigation.back': 'navigation.page',
    'navigation.home': 'navigation.page',

    // 会话控制
    'conversation.confirm': 'system.confirm',
    'conversation.cancel': 'system.cancel',

    // 高级功能映射
    'vault.create': 'config.vault',
    'vault.query': 'config.vault',
    'vault.transfer': 'config.vault',
    'vault.budget': 'config.vault',
    'moneyAge.query': 'advanced.moneyAge',
    'moneyAge.reminder': 'advanced.moneyAge',
    'moneyAge.report': 'advanced.moneyAge',
    'habit.query': 'advanced.habit',
    'habit.analysis': 'advanced.habit',
    'habit.reminder': 'advanced.habit',
  };

  /// 意图action到operation的映射
  /// 用于自动推断ConfigAction需要的operation参数
  static const Map<String, String> _actionToOperationMapping = {
    // 通用操作映射
    'add': 'add',
    'create': 'create',
    'modify': 'modify',
    'update': 'modify',
    'delete': 'delete',
    'remove': 'delete',
    'query': 'query',
    'list': 'query',
    'statistics': 'query',

    // 交易类型
    'expense': 'add',
    'income': 'add',
    'transfer': 'add',

    // 配置类型
    'monthly': 'modify',
    'category': 'modify',
    'default': 'modify',
    'daily': 'modify',
    'mode': 'modify',

    // 切换类型
    'switch': 'switch',
    'page': 'navigate',
    'tab': 'navigate',
  };

  ActionExecutor({
    ActionRegistry? registry,
    this.largeAmountThreshold = 500.0,
  }) : _registry = registry ?? ActionRegistry.instance;

  /// 获取当前状态
  ExecutionState get state => _state;

  /// 获取待处理的行为
  PendingAction? get pendingAction => _pendingAction;

  /// 获取多意图待处理
  MultiIntentPendingAction? get multiIntentPending => _multiIntentPending;

  /// 是否有待处理的行为（会检查超时并触发通知）
  bool get hasPendingAction {
    if (_pendingAction == null) return false;

    if (_pendingAction!.isExpired) {
      _handlePendingActionTimeout();
      return false;
    }

    return true;
  }

  /// 是否有多意图待处理（会检查超时并触发通知）
  bool get hasMultiIntentPending {
    if (_multiIntentPending == null) return false;

    if (_multiIntentPending!.isExpired) {
      _handleMultiIntentTimeout();
      return false;
    }

    return true;
  }

  /// 处理待处理行为超时
  void _handlePendingActionTimeout() {
    final pending = _pendingAction;
    if (pending == null) return;

    debugPrint('[ActionExecutor] 待处理行为超时: ${pending.action.id}');

    // 确定超时类型
    final type = pending.isWaitingForParams
        ? TimeoutEventType.paramCompletion
        : TimeoutEventType.confirmation;

    // 生成超时消息
    String message;
    if (pending.isWaitingForParams) {
      message = '操作已超时，请重新告诉我${pending.action.generateMissingParamPrompt(pending.missingParams)}';
    } else {
      message = '确认已超时，操作已取消';
    }

    // 触发回调
    onTimeout?.call(TimeoutEvent(
      type: type,
      actionId: pending.action.id,
      message: message,
      params: pending.params,
    ));

    // 清理状态
    _pendingAction = null;
    _state = ExecutionState.idle;
  }

  /// 处理多意图超时
  void _handleMultiIntentTimeout() {
    final pending = _multiIntentPending;
    if (pending == null) return;

    debugPrint('[ActionExecutor] 多意图操作超时');

    // 生成超时消息
    final completedCount = pending.completeItems.length;
    final message = completedCount > 0
        ? '确认已超时，$completedCount条记录未保存'
        : '操作已超时，请重新输入';

    // 触发回调
    onTimeout?.call(TimeoutEvent(
      type: TimeoutEventType.multiIntentConfirmation,
      message: message,
      params: {'count': pending.items.length, 'totalAmount': pending.totalAmount},
    ));

    // 清理状态
    _multiIntentPending = null;
    _state = ExecutionState.idle;
  }

  /// 检查并处理所有超时（供外部定期调用）
  ///
  /// 返回是否有超时事件发生
  bool checkTimeouts() {
    bool hasTimeout = false;

    if (_pendingAction != null && _pendingAction!.isExpired) {
      _handlePendingActionTimeout();
      hasTimeout = true;
    }

    if (_multiIntentPending != null && _multiIntentPending!.isExpired) {
      _handleMultiIntentTimeout();
      hasTimeout = true;
    }

    return hasTimeout;
  }

  /// 获取剩余超时时间（秒）
  ///
  /// 返回 null 表示没有待处理的行为
  int? get remainingTimeoutSeconds {
    if (_pendingAction != null && !_pendingAction!.isExpired) {
      final elapsed = DateTime.now().difference(_pendingAction!.createdAt).inSeconds;
      return _pendingAction!.timeoutSeconds - elapsed;
    }

    if (_multiIntentPending != null && !_multiIntentPending!.isExpired) {
      final elapsed = DateTime.now().difference(_multiIntentPending!.createdAt).inSeconds;
      return _multiIntentPending!.timeoutSeconds - elapsed;
    }

    return null;
  }

  /// 执行意图
  ///
  /// [intent] 意图结果
  /// Returns 执行结果
  Future<ActionResult> execute(IntentResult intent) async {
    // 检查是否有待处理的行为
    if (hasPendingAction) {
      return _handlePendingAction(intent);
    }

    // 查找对应的行为
    final action = _findAction(intent);
    if (action == null) {
      debugPrint('[ActionExecutor] 未找到Action: intentId=${intent.intentId}, category=${intent.category}, action=${intent.action}');
      return ActionResult.unsupported(intent.intentId ?? 'unknown');
    }

    // 自动补全参数（如operation）
    final enrichedParams = _enrichParams(intent, intent.entities);

    // 执行新行为
    return _executeAction(action, enrichedParams);
  }

  /// 查找行为
  Action? _findAction(IntentResult intent) {
    final intentId = intent.intentId;

    // 1. 优先通过映射表查找（处理命名不一致的情况）
    if (intentId != null && _intentToActionMapping.containsKey(intentId)) {
      final mappedActionId = _intentToActionMapping[intentId]!;
      debugPrint('[ActionExecutor] 意图映射: $intentId -> $mappedActionId');
      final action = _registry.findById(mappedActionId);
      if (action != null) return action;
    }

    // 2. 通过完整意图ID直接查找
    if (intentId != null) {
      final action = _registry.findByIntent(intentId);
      if (action != null) return action;

      // 也尝试直接用intentId作为actionId查找
      final directAction = _registry.findById(intentId);
      if (directAction != null) return directAction;
    }

    // 3. 尝试通过 category.action 组合查找
    if (intent.category != null && intent.action != null) {
      final actionId = '${intent.category}.${intent.action}';
      final action = _registry.findById(actionId);
      if (action != null) return action;

      // 尝试只用category查找（某些Action只用category作为ID）
      final categoryAction = _registry.findById(intent.category!);
      if (categoryAction != null) return categoryAction;
    }

    // 4. 尝试通过触发词查找
    final actions = _registry.findByTrigger(intent.rawInput);
    if (actions.isNotEmpty) return actions.first;

    return null;
  }

  /// 根据意图自动补全缺失的参数
  ///
  /// 主要用于：
  /// - 自动推断 ConfigAction 需要的 operation 参数
  /// - 根据 action 字段设置交易类型
  Map<String, dynamic> _enrichParams(IntentResult intent, Map<String, dynamic> params) {
    final enriched = Map<String, dynamic>.from(params);

    // 1. 自动推断 operation 参数（如果缺失）
    if (!enriched.containsKey('operation') || enriched['operation'] == null) {
      final action = intent.action;
      if (action != null) {
        // 先尝试直接映射
        if (_actionToOperationMapping.containsKey(action)) {
          enriched['operation'] = _actionToOperationMapping[action];
          debugPrint('[ActionExecutor] 自动推断operation: $action -> ${enriched['operation']}');
        } else {
          // 尝试从action中提取（如 budget.monthly -> monthly -> modify）
          final parts = action.split('.');
          for (final part in parts.reversed) {
            if (_actionToOperationMapping.containsKey(part)) {
              enriched['operation'] = _actionToOperationMapping[part];
              debugPrint('[ActionExecutor] 自动推断operation(部分匹配): $part -> ${enriched['operation']}');
              break;
            }
          }
        }
      }

      // 如果还是没有，根据category设置默认值
      if (!enriched.containsKey('operation') || enriched['operation'] == null) {
        switch (intent.category) {
          case 'query':
            enriched['operation'] = 'query';
            break;
          case 'navigation':
            enriched['operation'] = 'navigate';
            break;
          case 'config':
            // 根据是否有configValue判断是修改还是查询
            enriched['operation'] = enriched.containsKey('configValue') ? 'modify' : 'query';
            break;
        }
      }
    }

    // 2. 设置交易类型（用于区分支出/收入/转账）
    if (intent.category == 'transaction' && !enriched.containsKey('transactionType')) {
      switch (intent.action) {
        case 'expense':
          enriched['transactionType'] = 'expense';
          break;
        case 'income':
          enriched['transactionType'] = 'income';
          break;
        case 'transfer':
          enriched['transactionType'] = 'transfer';
          break;
      }
    }

    return enriched;
  }

  /// 执行行为
  Future<ActionResult> _executeAction(
    Action action,
    Map<String, dynamic> params,
  ) async {
    debugPrint('[ActionExecutor] 执行行为: ${action.id}');
    _state = ExecutionState.executing;

    try {
      // 1. 参数验证
      final validation = action.validateParams(params);
      if (!validation.isValid) {
        if (validation.missingParams.isNotEmpty) {
          // 缺少参数，设置待处理状态
          _setPendingAction(action, params, validation.missingParams);
          _state = ExecutionState.waitingForParams;

          final prompt = action.generateMissingParamPrompt(validation.missingParams);
          return ActionResult.needParams(
            missing: validation.missingParams,
            prompt: prompt,
            actionId: action.id,
          );
        }

        if (validation.invalidParams.isNotEmpty) {
          _state = ExecutionState.failed;
          return ActionResult.failure(
            '参数格式错误: ${validation.invalidParams.join(", ")}',
            actionId: action.id,
          );
        }
      }

      // 2. 执行行为（Action会返回带确认级别的结果）
      final result = await action.execute(params);

      // 3. 如果Action返回需要确认，设置待处理状态
      if (result.needsConfirmation) {
        _setPendingAction(
          action,
          result.data ?? params,
          [],
          result.confirmationMessage,
          result.confirmLevel,
          result.allowVoiceConfirm,
          result.requireScreenConfirm,
        );
        _state = ExecutionState.waitingForConfirmation;
        return result;
      }

      // 4. 如果Action返回被阻止，直接返回
      if (result.isBlocked) {
        _state = ExecutionState.failed;
        return result;
      }

      _state = result.success ? ExecutionState.completed : ExecutionState.failed;
      _clearPendingAction();

      return result;
    } catch (e) {
      debugPrint('[ActionExecutor] 执行异常: $e');
      _state = ExecutionState.failed;
      _clearPendingAction();

      return ActionResult.failure(
        '执行失败: ${e.toString()}',
        actionId: action.id,
      );
    }
  }

  /// 处理待处理的行为
  Future<ActionResult> _handlePendingAction(IntentResult intent) async {
    if (_pendingAction == null || _pendingAction!.isExpired) {
      _clearPendingAction();
      return execute(intent); // 重新执行新意图
    }

    final pending = _pendingAction!;

    // 等待参数补充
    if (pending.isWaitingForParams) {
      return _handleParamCompletion(pending, intent);
    }

    // 等待确认
    if (pending.isWaitingForConfirmation) {
      return _handleConfirmation(pending, intent);
    }

    return ActionResult.failure('未知的待处理状态');
  }

  /// 处理参数补充
  ///
  /// 智能判断用户输入是参数补充还是新意图：
  /// 1. 检查新意图是否提供了我们需要的参数
  /// 2. 如果是完全不同的操作意图，则放弃当前待处理，执行新意图
  /// 3. 如果是聊天或确认/取消，按相应逻辑处理
  Future<ActionResult> _handleParamCompletion(
    PendingAction pending,
    IntentResult intent,
  ) async {
    debugPrint('[ActionExecutor] 处理参数补充, 缺失参数: ${pending.missingParams}');
    debugPrint('[ActionExecutor] 新意图: type=${intent.type}, category=${intent.category}, entities=${intent.entities}');

    // 1. 检查是否是确认或取消（用户可能想取消当前操作）
    if (_isCancelIntent(intent)) {
      _clearPendingAction();
      return ActionResult(
        success: true,
        responseText: '好的，已取消',
        actionId: pending.action.id,
      );
    }

    // 2. 检查是否是完全不同的操作意图
    //    如果新意图有明确的category且与当前pending action不同，视为新意图
    if (_isNewOperationIntent(pending, intent)) {
      debugPrint('[ActionExecutor] 检测到新操作意图，放弃当前参数补充');
      _clearPendingAction();
      return execute(intent);
    }

    // 3. 提取新意图中与缺失参数相关的实体
    final relevantEntities = _extractRelevantEntities(pending.missingParams, intent);

    // 4. 如果没有提供任何相关参数，检查是否是纯数字输入（可能是金额）
    if (relevantEntities.isEmpty) {
      final extractedFromRaw = _tryExtractFromRawInput(pending.missingParams, intent.rawInput);
      relevantEntities.addAll(extractedFromRaw);
    }

    // 5. 如果仍然没有有效参数，且不是聊天类型，可能是无关输入
    if (relevantEntities.isEmpty && intent.type != RouteType.chat) {
      debugPrint('[ActionExecutor] 未提取到相关参数，继续等待');
      final prompt = pending.action.generateMissingParamPrompt(pending.missingParams);
      return ActionResult.needParams(
        missing: pending.missingParams,
        prompt: '没听清楚，$prompt',
        actionId: pending.action.id,
      );
    }

    // 6. 合并参数（只合并相关的实体，保留原有参数）
    final updatedParams = {...pending.params};
    for (final entry in relevantEntities.entries) {
      if (entry.value != null) {
        updatedParams[entry.key] = entry.value;
      }
    }

    // 7. 检查是否还有缺失参数
    final stillMissing = pending.missingParams.where((param) {
      return !updatedParams.containsKey(param) || updatedParams[param] == null;
    }).toList();

    if (stillMissing.isNotEmpty) {
      // 仍有缺失参数，继续追问
      _setPendingAction(pending.action, updatedParams, stillMissing);

      final prompt = pending.action.generateMissingParamPrompt(stillMissing);
      return ActionResult.needParams(
        missing: stillMissing,
        prompt: prompt,
        actionId: pending.action.id,
      );
    }

    // 8. 参数完整，执行行为
    _clearPendingAction();
    return _executeAction(pending.action, updatedParams);
  }

  /// 判断是否是新的操作意图（而非参数补充）
  bool _isNewOperationIntent(PendingAction pending, IntentResult intent) {
    // 如果没有明确的操作类型，不是新意图
    if (intent.category == null || intent.action == null) {
      return false;
    }

    // 系统类意图（confirm/cancel）不算新操作意图
    if (intent.category == 'system' || intent.category == 'conversation') {
      return false;
    }

    // 聊天类意图不算新操作意图
    if (intent.type == RouteType.chat) {
      return false;
    }

    // 获取pending action的category
    final pendingCategory = pending.action.id.split('.').first;

    // 如果category不同，是新意图
    if (intent.category != pendingCategory) {
      debugPrint('[ActionExecutor] category不同: pending=$pendingCategory, new=${intent.category}');
      return true;
    }

    // 如果是同一category但有不同的entities（如不同的商家/分类），可能是新意图
    // 但如果entities包含我们需要的参数，则不是新意图
    final hasRelevantParams = pending.missingParams.any(
      (param) => intent.entities.containsKey(param) && intent.entities[param] != null,
    );

    if (!hasRelevantParams && intent.entities.isNotEmpty) {
      // 有entities但不是我们需要的参数，可能是新意图
      // 例如：等待金额时用户说"午餐"（只有category没有amount）
      // 但这种情况可能是用户在补充分类，所以要谨慎判断
      // 只有当新意图有完整的关键参数时才认为是新意图
      if (intent.entities.containsKey('amount') && intent.entities['amount'] != null) {
        debugPrint('[ActionExecutor] 新意图有完整参数，视为新操作');
        return true;
      }
    }

    return false;
  }

  /// 从意图中提取与缺失参数相关的实体
  ///
  /// 添加类型验证，确保提取的值类型正确
  Map<String, dynamic> _extractRelevantEntities(
    List<String> missingParams,
    IntentResult intent,
  ) {
    final relevant = <String, dynamic>{};

    for (final param in missingParams) {
      if (intent.entities.containsKey(param) && intent.entities[param] != null) {
        final value = intent.entities[param];
        // 类型验证
        final validatedValue = _validateParamType(param, value);
        if (validatedValue != null) {
          relevant[param] = validatedValue;
        }
      }

      // 处理参数别名
      switch (param) {
        case 'amount':
          // amount 可能来自 configValue
          if (!relevant.containsKey('amount') &&
              intent.entities.containsKey('configValue')) {
            final value = intent.entities['configValue'];
            final validated = _validateParamType('amount', value);
            if (validated != null) {
              relevant['amount'] = validated;
            }
          }
          break;
        case 'category':
          // category 可能来自 merchant 或 description
          if (!relevant.containsKey('category')) {
            if (intent.entities.containsKey('merchant')) {
              final value = intent.entities['merchant'];
              if (value is String && value.isNotEmpty) {
                relevant['category'] = value;
              }
            } else if (intent.entities.containsKey('description')) {
              final value = intent.entities['description'];
              if (value is String && value.isNotEmpty) {
                relevant['category'] = value;
              }
            }
          }
          break;
      }
    }

    return relevant;
  }

  /// 验证参数类型
  ///
  /// 确保参数值类型正确，必要时进行转换
  dynamic _validateParamType(String paramName, dynamic value) {
    if (value == null) return null;

    switch (paramName) {
      case 'amount':
        // 金额必须是数字
        if (value is num) {
          final doubleVal = value.toDouble();
          // 金额必须为正数且在合理范围内
          if (doubleVal > 0 && doubleVal <= 10000000) {
            return doubleVal;
          }
        }
        if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null && parsed > 0 && parsed <= 10000000) {
            return parsed;
          }
        }
        return null;

      case 'category':
      case 'merchant':
      case 'note':
      case 'description':
      case 'account':
      case 'transactionType':
        // 字符串类型参数
        if (value is String && value.trim().isNotEmpty) {
          // 限制长度防止异常输入
          final trimmed = value.trim();
          return trimmed.length <= 100 ? trimmed : trimmed.substring(0, 100);
        }
        return null;

      case 'date':
        // 日期类型
        if (value is DateTime) return value;
        if (value is String) {
          return DateTime.tryParse(value);
        }
        return null;

      case 'transactionId':
        // ID类型
        if (value is String && value.isNotEmpty && value.length <= 64) {
          return value;
        }
        return null;

      default:
        // 其他参数原样返回
        return value;
    }
  }

  /// 尝试从原始输入中提取参数
  ///
  /// 用于处理用户直接说数字的情况，如："15"、"二十块"
  Map<String, dynamic> _tryExtractFromRawInput(
    List<String> missingParams,
    String rawInput,
  ) {
    final extracted = <String, dynamic>{};
    final input = rawInput.trim();

    // 如果缺少金额，尝试从输入中提取数字
    if (missingParams.contains('amount')) {
      final amount = _tryParseAmount(input);
      if (amount != null) {
        extracted['amount'] = amount;
      }
    }

    return extracted;
  }

  /// 尝试解析金额
  double? _tryParseAmount(String input) {
    // 移除常见的金额单位
    final cleaned = input
        .replaceAll(RegExp(r'[元块钱圆角分]'), '')
        .replaceAll(RegExp(r'[，,]'), '')
        .trim();

    // 尝试直接解析数字
    final directParse = double.tryParse(cleaned);
    if (directParse != null) {
      return directParse;
    }

    // 尝试解析中文数字
    final chineseAmount = _parseChineseNumber(cleaned);
    if (chineseAmount != null) {
      return chineseAmount;
    }

    // 尝试从混合文本中提取数字
    final numberMatch = RegExp(r'(\d+\.?\d*)').firstMatch(input);
    if (numberMatch != null) {
      return double.tryParse(numberMatch.group(1)!);
    }

    return null;
  }

  /// 解析中文数字
  double? _parseChineseNumber(String input) {
    const chineseDigits = {
      '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
      '百': 100, '千': 1000, '万': 10000,
    };

    // 简单的中文数字解析（处理常见情况）
    if (chineseDigits.containsKey(input)) {
      return chineseDigits[input]!.toDouble();
    }

    // 处理"十几"、"几十"的情况
    if (input.length == 2) {
      final first = chineseDigits[input[0]];
      final second = chineseDigits[input[1]];
      if (first != null && second != null) {
        if (first == 10) {
          // 十几
          return (10 + second).toDouble();
        } else if (second == 10) {
          // 几十
          return (first * 10).toDouble();
        }
      }
    }

    // 处理"几十几"的情况
    if (input.length == 3 && input[1] == '十') {
      final tens = chineseDigits[input[0]];
      final ones = chineseDigits[input[2]];
      if (tens != null && ones != null) {
        return (tens * 10 + ones).toDouble();
      }
    }

    return null;
  }

  /// 处理确认
  Future<ActionResult> _handleConfirmation(
    PendingAction pending,
    IntentResult intent,
  ) async {
    debugPrint('[ActionExecutor] 处理确认，确认级别: ${pending.confirmLevel}');

    // 检查是否是确认意图
    final isConfirm = _isConfirmIntent(intent);
    final isCancel = _isCancelIntent(intent);

    if (isConfirm) {
      // 检查确认级别是否允许语音确认
      if (pending.confirmLevel == ActionConfirmLevel.strict) {
        // Level 3: 严格确认，不允许语音确认
        debugPrint('[ActionExecutor] 严格确认级别，语音确认被拒绝');
        return ActionResult.strictConfirmation(
          message: '此操作需要在屏幕上点击确认按钮',
          data: pending.params,
          actionId: pending.action.id,
        );
      }

      if (pending.confirmLevel == ActionConfirmLevel.voiceProhibited) {
        // Level 4: 禁止语音执行
        debugPrint('[ActionExecutor] 禁止语音级别，操作被阻止');
        return ActionResult.blocked(
          reason: '此操作无法通过语音完成，请在设置中手动操作',
          redirectRoute: pending.params['_redirectRoute'] as String? ?? '/settings',
          actionId: pending.action.id,
        );
      }

      // Level 1/2: 允许语音确认
      _clearPendingAction();
      final paramsWithSkip = {...pending.params, '_skipConfirmation': true};
      return _forceExecuteAction(pending.action, paramsWithSkip);
    }

    if (isCancel) {
      _clearPendingAction();
      _state = ExecutionState.idle;
      return ActionResult(
        success: true,
        responseText: '好的，已取消',
        actionId: pending.action.id,
      );
    }

    // 不是确认也不是取消，可能是新意图
    // 取消当前待处理，执行新意图
    _clearPendingAction();
    return execute(intent);
  }

  /// 处理屏幕确认（点击确认按钮）
  Future<ActionResult> handleScreenConfirmation() async {
    if (_pendingAction == null || _pendingAction!.isExpired) {
      return ActionResult.failure('没有待确认的操作');
    }

    final pending = _pendingAction!;
    _clearPendingAction();

    // 屏幕确认可以绕过所有确认级别（除了Level 4）
    if (pending.confirmLevel == ActionConfirmLevel.voiceProhibited) {
      return ActionResult.blocked(
        reason: '此操作需要在设置中手动完成',
        redirectRoute: pending.params['_redirectRoute'] as String? ?? '/settings',
        actionId: pending.action.id,
      );
    }

    final paramsWithSkip = {...pending.params, '_skipConfirmation': true};
    return _forceExecuteAction(pending.action, paramsWithSkip);
  }

  /// 强制执行（跳过确认）
  Future<ActionResult> _forceExecuteAction(
    Action action,
    Map<String, dynamic> params,
  ) async {
    _state = ExecutionState.executing;
    try {
      final result = await action.execute(params);
      _state = result.success ? ExecutionState.completed : ExecutionState.failed;
      return result;
    } catch (e) {
      _state = ExecutionState.failed;
      return ActionResult.failure('执行失败: ${e.toString()}', actionId: action.id);
    }
  }

  /// 检查是否需要确认
  bool _needsConfirmation(Action action, Map<String, dynamic> params) {
    // 行为本身要求确认
    if (action.requiresConfirmation) return true;

    // 特定行为类型需要确认
    if (_confirmRequiredActions.contains(action.id)) return true;

    // 大金额交易需要确认
    if (params.containsKey('amount')) {
      final amount = params['amount'];
      if (amount is num && amount > largeAmountThreshold) {
        return true;
      }
    }

    // 行为有确认阈值
    if (action.confirmationThreshold != null && params.containsKey('amount')) {
      final amount = params['amount'];
      if (amount is num && amount > action.confirmationThreshold!) {
        return true;
      }
    }

    return false;
  }

  /// 生成确认消息
  String _generateConfirmationMessage(
    Action action,
    Map<String, dynamic> params,
  ) {
    if (action.id.startsWith('transaction.delete')) {
      return '确定要删除这笔记录吗？';
    }

    if (action.id.startsWith('config.')) {
      final configKey = params['configKey'] ?? action.name;
      final configValue = params['configValue'] ?? params['amount'];
      return '确定要将$configKey修改为$configValue吗？';
    }

    if (params.containsKey('amount')) {
      final amount = params['amount'];
      final categoryName = params['category'] as String?;
      final transactionType = params['transactionType'] as String?;

      // 根据交易类型确定显示文本
      String typeLabel;
      switch (transactionType) {
        case 'income':
          typeLabel = '收入';
          break;
        case 'transfer':
          typeLabel = '转账';
          break;
        case 'expense':
        default:
          typeLabel = '支出';
          break;
      }

      final categoryStr = categoryName != null ? '($categoryName)' : '';
      return '确定要记录$typeLabel${amount}元$categoryStr吗？这笔金额比较大。';
    }

    return '确定要执行此操作吗？';
  }

  /// 检查是否是确认意图
  ///
  /// 采用严格匹配策略，避免误判：
  /// 1. 优先信任LLM的分类结果
  /// 2. 如果LLM识别为action类型，则不是确认意图
  /// 3. 检查输入是否为纯确认语（无其他有意义内容）
  bool _isConfirmIntent(IntentResult intent) {
    // 1. LLM明确分类为确认
    if (intent.category == 'system' && intent.action == 'confirm') {
      return true;
    }
    if (intent.category == 'conversation' && intent.action == 'confirm') {
      return true;
    }

    // 2. 如果LLM识别为具体操作意图，优先信任LLM（不是确认）
    if (intent.type == RouteType.action && intent.category != null) {
      // 有明确的操作意图（如transaction、config等），不是确认
      if (intent.category != 'system' && intent.category != 'conversation') {
        debugPrint('[ActionExecutor] 检测到操作意图，跳过确认判断: ${intent.category}.${intent.action}');
        return false;
      }
    }

    // 3. 严格的关键词匹配
    final input = intent.rawInput.trim();
    final normalizedInput = input.toLowerCase();

    // 纯确认短语（完整匹配或只有这些词）
    const pureConfirmPhrases = [
      '确认',
      '确定',
      '是的',
      '好的',
      '好',
      '可以',
      '没问题',
      '对',
      '对的',
      '嗯',
      '行',
      'yes',
      'ok',
      'okay',
    ];

    // 完全匹配纯确认短语
    if (pureConfirmPhrases.contains(normalizedInput)) {
      return true;
    }

    // 检查是否是"好的/可以 + 语气词"的模式，但后面没有实质内容
    // 例如："好的呀"、"可以的"、"没问题啊"
    final confirmWithSuffixPattern = RegExp(
      r'^(确认|确定|是的|好的|好|可以|没问题|对|对的|嗯|行|yes|ok|okay)[啊呀的吧呢哦嘛哈噢诶]?[!！。.，,]?$',
      caseSensitive: false,
    );
    if (confirmWithSuffixPattern.hasMatch(normalizedInput)) {
      return true;
    }

    // 如果输入较长（超过6个字符）且包含确认词，可能是新意图而非确认
    // 例如："好的，帮我记一下午餐"
    if (input.length > 6) {
      // 检查确认词后面是否有实质内容
      for (final keyword in ['好的', '可以', '没问题', '是的', '确定']) {
        if (normalizedInput.startsWith(keyword)) {
          final rest = normalizedInput.substring(keyword.length).trim();
          // 去除标点和语气词后，如果还有内容，则不是纯确认
          final cleanRest = rest.replaceAll(RegExp(r'^[，,。.!！？?、\s]+'), '');
          if (cleanRest.isNotEmpty && cleanRest.length > 2) {
            debugPrint('[ActionExecutor] 确认词后有实质内容，判定为新意图: "$cleanRest"');
            return false;
          }
        }
      }
    }

    return false;
  }

  /// 检查是否是取消意图
  ///
  /// 采用严格匹配策略，避免误判
  bool _isCancelIntent(IntentResult intent) {
    // 1. LLM明确分类为取消
    if (intent.category == 'system' && intent.action == 'cancel') {
      return true;
    }
    if (intent.category == 'conversation' && intent.action == 'cancel') {
      return true;
    }

    // 2. 如果LLM识别为具体操作意图，优先信任LLM
    if (intent.type == RouteType.action && intent.category != null) {
      if (intent.category != 'system' && intent.category != 'conversation') {
        return false;
      }
    }

    // 3. 严格的关键词匹配
    final input = intent.rawInput.trim();
    final normalizedInput = input.toLowerCase();

    // 纯取消短语
    const pureCancelPhrases = [
      '取消',
      '不要',
      '不要了',
      '算了',
      '不用',
      '不用了',
      '不',
      '不了',
      '错了',
      '不对',
      'no',
      'cancel',
      '停',
      '停止',
    ];

    // 完全匹配纯取消短语
    if (pureCancelPhrases.contains(normalizedInput)) {
      return true;
    }

    // 检查是否是"取消 + 语气词"的模式
    final cancelWithSuffixPattern = RegExp(
      r'^(取消|不要|不要了|算了|不用|不用了|不|不了|错了|不对|no|cancel|停|停止)[啊呀的吧呢哦嘛哈噢诶]?[!！。.，,]?$',
      caseSensitive: false,
    );
    if (cancelWithSuffixPattern.hasMatch(normalizedInput)) {
      return true;
    }

    // 如果输入较长且包含取消词，检查是否有其他意图
    if (input.length > 6) {
      for (final keyword in ['算了', '不要', '取消', '不用']) {
        if (normalizedInput.startsWith(keyword)) {
          final rest = normalizedInput.substring(keyword.length).trim();
          final cleanRest = rest.replaceAll(RegExp(r'^[，,。.!！？?、\s]+'), '');
          if (cleanRest.isNotEmpty && cleanRest.length > 2) {
            debugPrint('[ActionExecutor] 取消词后有实质内容，判定为新意图: "$cleanRest"');
            return false;
          }
        }
      }
    }

    return false;
  }

  /// 设置待处理行为
  void _setPendingAction(
    Action action,
    Map<String, dynamic> params,
    List<String> missingParams, [
    String? confirmationMessage,
    ActionConfirmLevel confirmLevel = ActionConfirmLevel.standard,
    bool allowVoiceConfirm = true,
    bool requireScreenConfirm = false,
  ]) {
    _pendingAction = PendingAction(
      action: action,
      params: params,
      missingParams: missingParams,
      confirmationMessage: confirmationMessage,
      confirmLevel: confirmLevel,
      allowVoiceConfirm: allowVoiceConfirm,
      requireScreenConfirm: requireScreenConfirm,
    );
  }

  /// 清除待处理行为
  void _clearPendingAction() {
    _pendingAction = null;
    _state = ExecutionState.idle;
  }

  /// 清除多意图待处理
  void _clearMultiIntentPending() {
    _multiIntentPending = null;
    _state = ExecutionState.idle;
  }

  /// 取消当前待处理行为
  void cancelPending() {
    _clearPendingAction();
    _clearMultiIntentPending();
  }

  /// 重置状态
  void reset() {
    _clearPendingAction();
    _clearMultiIntentPending();
    _state = ExecutionState.idle;
  }

  // ==================== 多意图处理 ====================

  /// 执行多意图
  ///
  /// [intents] 多个意图结果
  /// [autoExecute] 是否自动执行（不需要确认）
  /// Returns 执行结果
  Future<ActionResult> executeMultiIntent(
    List<IntentResult> intents, {
    bool autoExecute = true,
  }) async {
    if (intents.isEmpty) {
      return ActionResult.failure('没有意图需要执行');
    }

    if (intents.length == 1) {
      return execute(intents.first);
    }

    debugPrint('[ActionExecutor] 执行多意图: ${intents.length}个');

    // 构建多意图项
    final items = <MultiIntentItem>[];
    for (final intent in intents) {
      final action = _findAction(intent);
      // 自动补全参数（包括operation和transactionType）
      final enrichedParams = _enrichParams(intent, intent.entities);
      final missingParams = <String>[];

      if (action != null) {
        final validation = action.validateParams(enrichedParams);
        if (!validation.isValid) {
          missingParams.addAll(validation.missingParams);
        }
      }

      items.add(MultiIntentItem(
        intent: intent,
        action: action,
        params: Map.from(enrichedParams),
        missingParams: missingParams,
      ));
    }

    // 创建多意图待处理对象
    _multiIntentPending = MultiIntentPendingAction(
      items: items,
      rawInput: intents.map((i) => i.rawInput).join('；'),
    );

    // 检查是否所有项都完整且不需要特殊确认
    final allComplete = _multiIntentPending!.incompleteItems.isEmpty;
    final needsConfirmation = _checkMultiIntentNeedsConfirmation(_multiIntentPending!);

    // 如果所有项完整且允许自动执行且不需要特殊确认，直接执行
    if (autoExecute && allComplete && !needsConfirmation) {
      debugPrint('[ActionExecutor] 多意图自动执行，无需确认');
      return _executeMultiIntentBatch(_multiIntentPending!);
    }

    // 否则要求确认
    _state = ExecutionState.waitingForConfirmation;

    // 返回确认提示
    return ActionResult.confirmation(
      message: _multiIntentPending!.generatePrompt(),
      data: {
        'multiIntent': true,
        'count': items.length,
        'totalAmount': _multiIntentPending!.totalAmount,
        'hasIncomplete': _multiIntentPending!.hasIncomplete,
      },
    );
  }

  /// 检查多意图是否需要确认
  bool _checkMultiIntentNeedsConfirmation(MultiIntentPendingAction pending) {
    // 检查总金额是否超过阈值
    if (pending.totalAmount > largeAmountThreshold) {
      debugPrint('[ActionExecutor] 多意图总金额${pending.totalAmount}超过阈值$largeAmountThreshold，需要确认');
      return true;
    }

    // 检查是否有需要确认的行为类型
    for (final item in pending.completeItems) {
      if (item.action != null && _confirmRequiredActions.contains(item.action!.id)) {
        debugPrint('[ActionExecutor] 多意图包含需要确认的行为: ${item.action!.id}');
        return true;
      }
    }

    return false;
  }

  /// 处理多意图确认
  Future<ActionResult> handleMultiIntentConfirmation(IntentResult intent) async {
    if (_multiIntentPending == null || _multiIntentPending!.isExpired) {
      _clearMultiIntentPending();
      return execute(intent);
    }

    final pending = _multiIntentPending!;

    // 检查是否是确认意图
    final isConfirm = _isConfirmIntent(intent);
    final isCancel = _isCancelIntent(intent);

    if (isConfirm) {
      return _executeMultiIntentBatch(pending);
    }

    if (isCancel) {
      _clearMultiIntentPending();
      return ActionResult(
        success: true,
        responseText: '好的，已取消全部',
      );
    }

    // 不是确认也不是取消，可能是补充参数或新意图
    // 尝试补充参数
    final supplemented = _trySupplementMultiIntentParams(pending, intent);
    if (supplemented) {
      // 参数已补充，更新提示
      return ActionResult.confirmation(
        message: pending.generatePrompt(),
        data: {
          'multiIntent': true,
          'count': pending.items.length,
          'totalAmount': pending.totalAmount,
          'hasIncomplete': pending.hasIncomplete,
        },
      );
    }

    // 无法补充，视为新意图，取消当前多意图
    _clearMultiIntentPending();
    return execute(intent);
  }

  /// 尝试补充多意图参数
  bool _trySupplementMultiIntentParams(
    MultiIntentPendingAction pending,
    IntentResult intent,
  ) {
    // 检查是否有可补充的参数
    final entities = intent.entities;
    if (entities.isEmpty) return false;

    // 尝试补充不完整的意图项
    for (final item in pending.incompleteItems) {
      for (final param in item.missingParams.toList()) {
        if (entities.containsKey(param)) {
          item.params[param] = entities[param];
          item.missingParams.remove(param);
        }
      }
    }

    // 如果提供了金额但没有明确目标，尝试补充到第一个缺金额的项
    if (entities.containsKey('amount')) {
      for (final item in pending.incompleteItems) {
        if (item.missingParams.contains('amount')) {
          item.params['amount'] = entities['amount'];
          item.missingParams.remove('amount');
          return true;
        }
      }
    }

    return pending.incompleteItems.length < pending.items.length;
  }

  /// 批量执行多意图
  Future<ActionResult> _executeMultiIntentBatch(
    MultiIntentPendingAction pending,
  ) async {
    debugPrint('[ActionExecutor] 批量执行多意图: ${pending.completeItems.length}个');
    _state = ExecutionState.executing;

    final results = <ActionResult>[];
    var successCount = 0;
    var failCount = 0;

    for (final item in pending.completeItems) {
      if (item.action == null) {
        item.executed = true;
        item.result = ActionResult.failure('未找到对应行为');
        failCount++;
        continue;
      }

      try {
        final result = await item.action!.execute(item.params);
        item.executed = true;
        item.result = result;
        results.add(result);

        if (result.success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        item.executed = true;
        item.result = ActionResult.failure('执行失败: $e');
        failCount++;
      }
    }

    _clearMultiIntentPending();
    _state = ExecutionState.completed;

    // 生成汇总响应
    if (failCount == 0) {
      return ActionResult(
        success: true,
        responseText: '已记录$successCount笔，共${_formatAmount(pending.totalAmount)}',
        data: {
          'multiIntent': true,
          'successCount': successCount,
          'totalAmount': pending.totalAmount,
        },
      );
    } else if (successCount == 0) {
      return ActionResult.failure('记录失败，请重试');
    } else {
      return ActionResult(
        success: true,
        responseText: '已记录$successCount笔，${failCount}笔失败',
        data: {
          'multiIntent': true,
          'successCount': successCount,
          'failCount': failCount,
        },
      );
    }
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return '${amount.round()}元';
    }
    return '${amount.toStringAsFixed(2)}元';
  }
}
