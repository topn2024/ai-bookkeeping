/// 行为注册表
///
/// 管理智能体可执行的所有行为，提供统一的行为发现和执行接口
///
/// 设计原则：
/// - 行为只定义接口，不实现业务逻辑
/// - 实际执行由现有 Service 完成
/// - 支持运行时动态注册
library;

import 'package:flutter/foundation.dart';

/// 行为参数定义
class ActionParam {
  /// 参数名称
  final String name;

  /// 参数类型
  final ActionParamType type;

  /// 是否必填
  final bool required;

  /// 默认值
  final dynamic defaultValue;

  /// 参数描述
  final String description;

  /// 验证正则（用于字符串类型）
  final String? validationPattern;

  const ActionParam({
    required this.name,
    required this.type,
    this.required = true,
    this.defaultValue,
    this.description = '',
    this.validationPattern,
  });

  /// 验证参数值
  bool validate(dynamic value) {
    if (value == null) {
      return !required || defaultValue != null;
    }

    switch (type) {
      case ActionParamType.number:
        return value is num;
      case ActionParamType.string:
        if (value is! String) return false;
        if (validationPattern != null) {
          return RegExp(validationPattern!).hasMatch(value);
        }
        return true;
      case ActionParamType.boolean:
        return value is bool;
      case ActionParamType.dateTime:
        return value is DateTime || value is String;
      case ActionParamType.list:
        return value is List;
      case ActionParamType.map:
        return value is Map;
    }
  }
}

/// 参数类型枚举
enum ActionParamType {
  number,
  string,
  boolean,
  dateTime,
  list,
  map,
}

/// 确认级别（用于4级确认系统）
enum ActionConfirmLevel {
  /// 无需确认
  none,

  /// Level 1: 轻量确认（语音确认即可）
  light,

  /// Level 2: 标准确认（语音或屏幕确认）
  standard,

  /// Level 3: 严格确认（必须屏幕点击）
  strict,

  /// Level 4: 禁止语音（必须手动操作）
  voiceProhibited,
}

/// 行为执行结果
class ActionResult {
  /// 是否成功
  final bool success;

  /// 结果数据
  final Map<String, dynamic>? data;

  /// 错误信息
  final String? error;

  /// 是否需要确认
  final bool needsConfirmation;

  /// 确认消息
  final String? confirmationMessage;

  /// 确认级别（4级确认系统）
  final ActionConfirmLevel confirmLevel;

  /// 是否允许语音确认
  final bool allowVoiceConfirm;

  /// 是否需要屏幕确认
  final bool requireScreenConfirm;

  /// 是否被阻止（Level 4）
  final bool isBlocked;

  /// 重定向路由（被阻止时）
  final String? redirectRoute;

  /// 是否需要补充参数
  final bool needsMoreParams;

  /// 缺失的参数列表
  final List<String>? missingParams;

  /// 追问提示
  final String? followUpPrompt;

  /// 执行的行为ID
  final String? actionId;

  /// 响应文本（用于TTS）
  final String? responseText;

  const ActionResult({
    required this.success,
    this.data,
    this.error,
    this.needsConfirmation = false,
    this.confirmationMessage,
    this.confirmLevel = ActionConfirmLevel.none,
    this.allowVoiceConfirm = true,
    this.requireScreenConfirm = false,
    this.isBlocked = false,
    this.redirectRoute,
    this.needsMoreParams = false,
    this.missingParams,
    this.followUpPrompt,
    this.actionId,
    this.responseText,
  });

  /// 成功结果
  factory ActionResult.success({
    Map<String, dynamic>? data,
    String? responseText,
    String? actionId,
  }) {
    return ActionResult(
      success: true,
      data: data,
      responseText: responseText,
      actionId: actionId,
    );
  }

  /// 失败结果
  factory ActionResult.failure(String error, {String? actionId}) {
    return ActionResult(
      success: false,
      error: error,
      actionId: actionId,
    );
  }

  /// 需要确认（基础版，默认Level 2标准确认）
  factory ActionResult.confirmation({
    required String message,
    Map<String, dynamic>? data,
    String? actionId,
  }) {
    return ActionResult(
      success: false,
      needsConfirmation: true,
      confirmationMessage: message,
      confirmLevel: ActionConfirmLevel.standard,
      allowVoiceConfirm: true,
      requireScreenConfirm: true,
      data: data,
      actionId: actionId,
    );
  }

  /// Level 1: 轻量确认（语音确认即可）
  factory ActionResult.lightConfirmation({
    required String message,
    Map<String, dynamic>? data,
    String? actionId,
  }) {
    return ActionResult(
      success: false,
      needsConfirmation: true,
      confirmationMessage: message,
      confirmLevel: ActionConfirmLevel.light,
      allowVoiceConfirm: true,
      requireScreenConfirm: false,
      data: data,
      actionId: actionId,
    );
  }

  /// Level 2: 标准确认（语音或屏幕确认）
  factory ActionResult.standardConfirmation({
    required String message,
    Map<String, dynamic>? data,
    String? actionId,
  }) {
    return ActionResult(
      success: false,
      needsConfirmation: true,
      confirmationMessage: message,
      confirmLevel: ActionConfirmLevel.standard,
      allowVoiceConfirm: true,
      requireScreenConfirm: true,
      data: data,
      actionId: actionId,
    );
  }

  /// Level 3: 严格确认（必须屏幕点击）
  factory ActionResult.strictConfirmation({
    required String message,
    Map<String, dynamic>? data,
    String? actionId,
  }) {
    return ActionResult(
      success: false,
      needsConfirmation: true,
      confirmationMessage: message,
      confirmLevel: ActionConfirmLevel.strict,
      allowVoiceConfirm: false,
      requireScreenConfirm: true,
      data: data,
      actionId: actionId,
    );
  }

  /// Level 4: 禁止语音执行（高风险操作）
  factory ActionResult.blocked({
    required String reason,
    required String redirectRoute,
    String? actionId,
  }) {
    return ActionResult(
      success: false,
      needsConfirmation: false,
      confirmationMessage: reason,
      confirmLevel: ActionConfirmLevel.voiceProhibited,
      allowVoiceConfirm: false,
      requireScreenConfirm: false,
      isBlocked: true,
      redirectRoute: redirectRoute,
      actionId: actionId,
    );
  }

  /// 需要补充参数
  factory ActionResult.needParams({
    required List<String> missing,
    required String prompt,
    String? actionId,
  }) {
    return ActionResult(
      success: false,
      needsMoreParams: true,
      missingParams: missing,
      followUpPrompt: prompt,
      actionId: actionId,
    );
  }

  /// 不支持的行为
  factory ActionResult.unsupported(String actionId) {
    return ActionResult(
      success: false,
      error: '不支持的操作: $actionId',
      actionId: actionId,
    );
  }
}

/// 行为基类
///
/// 所有可执行行为的抽象定义
abstract class Action {
  /// 行为唯一标识符
  ///
  /// 格式: category.subcategory.action
  /// 例如: transaction.expense, config.budget.monthly
  String get id;

  /// 行为名称（显示用）
  String get name;

  /// 行为描述
  String get description;

  /// 触发关键词/模式
  ///
  /// 用于规则引擎快速匹配
  List<String> get triggerPatterns;

  /// 必填参数列表
  List<ActionParam> get requiredParams;

  /// 可选参数列表
  List<ActionParam> get optionalParams;

  /// 是否需要确认
  ///
  /// 用于敏感操作（删除、大金额修改等）
  bool get requiresConfirmation => false;

  /// 确认阈值（如金额超过此值需要确认）
  double? get confirmationThreshold => null;

  /// 执行行为
  ///
  /// [params] 行为参数
  /// Returns 执行结果
  Future<ActionResult> execute(Map<String, dynamic> params);

  /// 验证参数完整性
  ValidationResult validateParams(Map<String, dynamic> params) {
    final missing = <String>[];
    final invalid = <String>[];

    for (final param in requiredParams) {
      if (!params.containsKey(param.name) || params[param.name] == null) {
        if (param.defaultValue == null) {
          missing.add(param.name);
        }
      } else if (!param.validate(params[param.name])) {
        invalid.add(param.name);
      }
    }

    for (final param in optionalParams) {
      if (params.containsKey(param.name) &&
          params[param.name] != null &&
          !param.validate(params[param.name])) {
        invalid.add(param.name);
      }
    }

    return ValidationResult(
      isValid: missing.isEmpty && invalid.isEmpty,
      missingParams: missing,
      invalidParams: invalid,
    );
  }

  /// 生成缺失参数的追问提示
  String generateMissingParamPrompt(List<String> missing) {
    if (missing.isEmpty) return '';

    final paramNames = missing.map((p) {
      switch (p) {
        case 'amount':
          return '金额';
        case 'category':
          return '分类';
        case 'accountName':
          return '账户名称';
        case 'time':
          return '时间';
        case 'merchant':
          return '商家';
        default:
          return p;
      }
    }).join('、');

    return '请告诉我$paramNames';
  }
}

/// 参数验证结果
class ValidationResult {
  final bool isValid;
  final List<String> missingParams;
  final List<String> invalidParams;

  const ValidationResult({
    required this.isValid,
    this.missingParams = const [],
    this.invalidParams = const [],
  });
}

/// 行为注册表
///
/// 单例模式，管理所有已注册的行为
class ActionRegistry {
  ActionRegistry._();

  static final ActionRegistry _instance = ActionRegistry._();

  /// 获取单例实例
  static ActionRegistry get instance => _instance;

  /// 已注册的行为
  final Map<String, Action> _actions = {};

  /// 意图ID到行为ID的映射
  final Map<String, String> _intentMapping = {};

  /// 注册行为
  void register(Action action) {
    if (_actions.containsKey(action.id)) {
      debugPrint('[ActionRegistry] 警告: 覆盖已存在的行为 ${action.id}');
    }
    _actions[action.id] = action;
    debugPrint('[ActionRegistry] 注册行为: ${action.id}');
  }

  /// 批量注册行为
  void registerAll(List<Action> actions) {
    for (final action in actions) {
      register(action);
    }
  }

  /// 注销行为
  void unregister(String actionId) {
    _actions.remove(actionId);
    _intentMapping.removeWhere((_, v) => v == actionId);
  }

  /// 注册意图到行为的映射
  void mapIntent(String intentId, String actionId) {
    _intentMapping[intentId] = actionId;
  }

  /// 批量注册意图映射
  void mapIntents(Map<String, String> mapping) {
    _intentMapping.addAll(mapping);
  }

  /// 通过行为ID查找行为
  Action? findById(String actionId) {
    return _actions[actionId];
  }

  /// 通过意图ID查找行为
  Action? findByIntent(String intentId) {
    final actionId = _intentMapping[intentId];
    if (actionId != null) {
      return _actions[actionId];
    }

    // 尝试直接匹配（意图ID就是行为ID的情况）
    return _actions[intentId];
  }

  /// 通过触发词查找行为
  List<Action> findByTrigger(String trigger) {
    final normalizedTrigger = trigger.toLowerCase();
    return _actions.values.where((action) {
      return action.triggerPatterns.any((pattern) {
        return normalizedTrigger.contains(pattern.toLowerCase()) ||
            pattern.toLowerCase().contains(normalizedTrigger);
      });
    }).toList();
  }

  /// 通过分类前缀查找行为
  List<Action> findByCategory(String category) {
    return _actions.values.where((action) {
      return action.id.startsWith('$category.');
    }).toList();
  }

  /// 获取所有已注册的行为
  List<Action> get allActions => _actions.values.toList();

  /// 获取所有行为ID
  List<String> get allActionIds => _actions.keys.toList();

  /// 检查行为是否已注册
  bool isRegistered(String actionId) => _actions.containsKey(actionId);

  /// 清空所有注册
  void clear() {
    _actions.clear();
    _intentMapping.clear();
  }

  /// 获取注册统计信息
  Map<String, int> getStats() {
    final stats = <String, int>{};
    for (final action in _actions.values) {
      final category = action.id.split('.').first;
      stats[category] = (stats[category] ?? 0) + 1;
    }
    return stats;
  }
}

/// 行为分类
class ActionCategory {
  static const String transaction = 'transaction';
  static const String config = 'config';
  static const String query = 'query';
  static const String navigation = 'navigation';
  static const String chat = 'chat';

  /// 获取分类的中文名称
  static String getName(String category) {
    switch (category) {
      case transaction:
        return '交易';
      case config:
        return '配置';
      case query:
        return '查询';
      case navigation:
        return '导航';
      case chat:
        return '聊天';
      default:
        return category;
    }
  }
}
