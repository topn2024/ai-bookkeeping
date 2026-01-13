/// 行为执行器
///
/// 负责执行行为并处理参数补全和确认机制
///
/// 核心职责：
/// - 参数验证：检测缺失参数
/// - 执行控制：调用行为执行
/// - 确认机制：敏感操作需要确认
/// - 追问生成：缺少参数时生成追问
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

  /// 创建时间
  final DateTime createdAt;

  /// 超时时间（秒）
  final int timeoutSeconds;

  PendingAction({
    required this.action,
    required this.params,
    this.missingParams = const [],
    this.confirmationMessage,
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

/// 行为执行器
class ActionExecutor {
  /// 行为注册表
  final ActionRegistry _registry;

  /// 当前执行状态
  ExecutionState _state = ExecutionState.idle;

  /// 待处理的行为
  PendingAction? _pendingAction;

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

  /// 是否有待处理的行为
  bool get hasPendingAction =>
      _pendingAction != null && !_pendingAction!.isExpired;

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

      // 2. 确认检查
      if (_needsConfirmation(action, params)) {
        final confirmMsg = _generateConfirmationMessage(action, params);
        _setPendingAction(action, params, [], confirmMsg);
        _state = ExecutionState.waitingForConfirmation;

        return ActionResult.confirmation(
          message: confirmMsg,
          data: params,
          actionId: action.id,
        );
      }

      // 3. 执行行为
      final result = await action.execute(params);

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
    debugPrint('[ActionExecutor] 处理确认');

    // 检查是否是确认意图
    final isConfirm = _isConfirmIntent(intent);
    final isCancel = _isCancelIntent(intent);

    if (isConfirm) {
      _clearPendingAction();
      return _forceExecuteAction(pending.action, pending.params);
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
  ]) {
    _pendingAction = PendingAction(
      action: action,
      params: params,
      missingParams: missingParams,
      confirmationMessage: confirmationMessage,
    );
  }

  /// 清除待处理行为
  void _clearPendingAction() {
    _pendingAction = null;
    _state = ExecutionState.idle;
  }

  /// 取消当前待处理行为
  void cancelPending() {
    _clearPendingAction();
  }

  /// 重置状态
  void reset() {
    _clearPendingAction();
    _state = ExecutionState.idle;
  }
}
