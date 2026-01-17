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
import 'hybrid_intent_router.dart';

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
    final category = params['category'] ?? '支出';
    final merchant = params['merchant'];

    if (amount != null) {
      final desc = '$category ${amount}元';
      return merchant != null ? '$desc ($merchant)' : desc;
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

  /// 需要确认的行为类型
  final Set<String> _confirmRequiredActions = {
    'transaction.delete',
    'config.reset',
    'data.clear',
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

  /// 是否有待处理的行为
  bool get hasPendingAction =>
      _pendingAction != null && !_pendingAction!.isExpired;

  /// 是否有多意图待处理
  bool get hasMultiIntentPending =>
      _multiIntentPending != null && !_multiIntentPending!.isExpired;

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
      return ActionResult.unsupported(intent.intentId ?? 'unknown');
    }

    // 执行新行为
    return _executeAction(action, intent.entities);
  }

  /// 查找行为
  Action? _findAction(IntentResult intent) {
    // 优先通过完整意图ID查找
    if (intent.intentId != null) {
      final action = _registry.findByIntent(intent.intentId!);
      if (action != null) return action;
    }

    // 尝试通过 category.action 组合查找
    if (intent.category != null && intent.action != null) {
      final actionId = '${intent.category}.${intent.action}';
      final action = _registry.findById(actionId);
      if (action != null) return action;
    }

    // 尝试通过触发词查找
    final actions = _registry.findByTrigger(intent.rawInput);
    if (actions.isNotEmpty) return actions.first;

    return null;
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
  Future<ActionResult> _handleParamCompletion(
    PendingAction pending,
    IntentResult intent,
  ) async {
    debugPrint('[ActionExecutor] 处理参数补充');

    // 合并新的实体到现有参数
    final updatedParams = {...pending.params, ...intent.entities};

    // 检查是否还有缺失参数
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

    // 参数完整，执行行为
    _clearPendingAction();
    return _executeAction(pending.action, updatedParams);
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
      final category = params['category'] ?? '支出';
      return '确定要记录$category${amount}元吗？这笔金额比较大。';
    }

    return '确定要执行此操作吗？';
  }

  /// 检查是否是确认意图
  bool _isConfirmIntent(IntentResult intent) {
    if (intent.category == 'system' && intent.action == 'confirm') {
      return true;
    }

    final input = intent.rawInput.toLowerCase();
    const confirmKeywords = [
      '确认',
      '确定',
      '是的',
      '好的',
      '可以',
      '没问题',
      '对',
      'yes',
      'ok',
    ];

    return confirmKeywords.any((k) => input.contains(k));
  }

  /// 检查是否是取消意图
  bool _isCancelIntent(IntentResult intent) {
    if (intent.category == 'system' && intent.action == 'cancel') {
      return true;
    }

    final input = intent.rawInput.toLowerCase();
    const cancelKeywords = [
      '取消',
      '不要',
      '算了',
      '不用了',
      '不',
      '错了',
      'no',
      'cancel',
    ];

    return cancelKeywords.any((k) => input.contains(k));
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
      final missingParams = <String>[];

      if (action != null) {
        final validation = action.validateParams(intent.entities);
        if (!validation.isValid) {
          missingParams.addAll(validation.missingParams);
        }
      }

      items.add(MultiIntentItem(
        intent: intent,
        action: action,
        params: Map.from(intent.entities),
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
