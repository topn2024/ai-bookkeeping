import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../user_access_service.dart';

/// 功能开关变体类型
enum VariantType {
  /// 布尔类型
  boolean,

  /// 字符串类型
  string,

  /// 数字类型
  number,

  /// JSON 类型
  json,
}

/// 功能开关变体
class FeatureVariant {
  /// 变体名称
  final String name;

  /// 变体值
  final dynamic value;

  /// 变体权重（用于 A/B 测试）
  final int weight;

  const FeatureVariant({
    required this.name,
    required this.value,
    this.weight = 100,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'weight': weight,
  };

  factory FeatureVariant.fromJson(Map<String, dynamic> json) => FeatureVariant(
    name: json['name'] as String,
    value: json['value'],
    weight: json['weight'] as int? ?? 100,
  );
}

/// 功能开关目标规则
class TargetingRule {
  /// 规则ID
  final String id;

  /// 规则条件
  final List<RuleCondition> conditions;

  /// 匹配时的变体
  final String variantName;

  /// 规则优先级
  final int priority;

  const TargetingRule({
    required this.id,
    required this.conditions,
    required this.variantName,
    this.priority = 0,
  });

  /// 评估规则
  bool evaluate(Map<String, dynamic> context) {
    for (final condition in conditions) {
      if (!condition.evaluate(context)) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conditions': conditions.map((c) => c.toJson()).toList(),
    'variantName': variantName,
    'priority': priority,
  };
}

/// 规则条件
class RuleCondition {
  /// 属性名
  final String attribute;

  /// 操作符
  final ConditionOperator operator;

  /// 目标值
  final dynamic targetValue;

  const RuleCondition({
    required this.attribute,
    required this.operator,
    required this.targetValue,
  });

  /// 评估条件
  bool evaluate(Map<String, dynamic> context) {
    final value = context[attribute];
    if (value == null && operator != ConditionOperator.isNull) {
      return false;
    }

    switch (operator) {
      case ConditionOperator.equals:
        return value == targetValue;
      case ConditionOperator.notEquals:
        return value != targetValue;
      case ConditionOperator.contains:
        if (value is String && targetValue is String) {
          return value.contains(targetValue);
        }
        if (value is List) {
          return value.contains(targetValue);
        }
        return false;
      case ConditionOperator.notContains:
        if (value is String && targetValue is String) {
          return !value.contains(targetValue);
        }
        if (value is List) {
          return !value.contains(targetValue);
        }
        return true;
      case ConditionOperator.startsWith:
        if (value is String && targetValue is String) {
          return value.startsWith(targetValue);
        }
        return false;
      case ConditionOperator.endsWith:
        if (value is String && targetValue is String) {
          return value.endsWith(targetValue);
        }
        return false;
      case ConditionOperator.greaterThan:
        if (value is num && targetValue is num) {
          return value > targetValue;
        }
        return false;
      case ConditionOperator.lessThan:
        if (value is num && targetValue is num) {
          return value < targetValue;
        }
        return false;
      case ConditionOperator.greaterThanOrEqual:
        if (value is num && targetValue is num) {
          return value >= targetValue;
        }
        return false;
      case ConditionOperator.lessThanOrEqual:
        if (value is num && targetValue is num) {
          return value <= targetValue;
        }
        return false;
      case ConditionOperator.inList:
        if (targetValue is List) {
          return targetValue.contains(value);
        }
        return false;
      case ConditionOperator.notInList:
        if (targetValue is List) {
          return !targetValue.contains(value);
        }
        return true;
      case ConditionOperator.regex:
        if (value is String && targetValue is String) {
          return RegExp(targetValue).hasMatch(value);
        }
        return false;
      case ConditionOperator.isNull:
        return value == null;
      case ConditionOperator.isNotNull:
        return value != null;
      case ConditionOperator.semverEquals:
        return _compareSemver(value as String?, targetValue as String) == 0;
      case ConditionOperator.semverGreaterThan:
        return _compareSemver(value as String?, targetValue as String) > 0;
      case ConditionOperator.semverLessThan:
        return _compareSemver(value as String?, targetValue as String) < 0;
    }
  }

  /// 比较语义化版本
  int _compareSemver(String? a, String b) {
    if (a == null) return -1;

    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (partsA.length < 3) {
      partsA.add(0);
    }
    while (partsB.length < 3) {
      partsB.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (partsA[i] > partsB[i]) return 1;
      if (partsA[i] < partsB[i]) return -1;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'attribute': attribute,
    'operator': operator.name,
    'targetValue': targetValue,
  };
}

/// 条件操作符
enum ConditionOperator {
  equals,
  notEquals,
  contains,
  notContains,
  startsWith,
  endsWith,
  greaterThan,
  lessThan,
  greaterThanOrEqual,
  lessThanOrEqual,
  inList,
  notInList,
  regex,
  isNull,
  isNotNull,
  semverEquals,
  semverGreaterThan,
  semverLessThan,
}

/// 功能开关定义
class FeatureFlag {
  /// 功能键名
  final String key;

  /// 功能名称
  final String name;

  /// 描述
  final String? description;

  /// 是否启用
  final bool enabled;

  /// 变体类型
  final VariantType type;

  /// 默认变体
  final FeatureVariant defaultVariant;

  /// 可选变体列表
  final List<FeatureVariant> variants;

  /// 目标规则
  final List<TargetingRule> rules;

  /// 百分比灰度
  final double rolloutPercentage;

  /// 开始时间
  final DateTime? startTime;

  /// 结束时间
  final DateTime? endTime;

  /// 元数据
  final Map<String, dynamic>? metadata;

  const FeatureFlag({
    required this.key,
    required this.name,
    this.description,
    this.enabled = true,
    this.type = VariantType.boolean,
    required this.defaultVariant,
    this.variants = const [],
    this.rules = const [],
    this.rolloutPercentage = 100,
    this.startTime,
    this.endTime,
    this.metadata,
  });

  /// 评估功能开关
  FeatureVariant evaluate(Map<String, dynamic> context) {
    // 检查是否启用
    if (!enabled) {
      return defaultVariant;
    }

    // 检查时间范围
    final now = DateTime.now();
    if (startTime != null && now.isBefore(startTime!)) {
      return defaultVariant;
    }
    if (endTime != null && now.isAfter(endTime!)) {
      return defaultVariant;
    }

    // 检查灰度百分比
    if (rolloutPercentage < 100) {
      final userId = context['userId'] as String?;
      if (userId != null) {
        final hash = userId.hashCode.abs() % 100;
        if (hash >= rolloutPercentage) {
          return defaultVariant;
        }
      }
    }

    // 评估目标规则
    final sortedRules = List<TargetingRule>.from(rules)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in sortedRules) {
      if (rule.evaluate(context)) {
        final variant = variants.firstWhere(
          (v) => v.name == rule.variantName,
          orElse: () => defaultVariant,
        );
        return variant;
      }
    }

    // 返回默认变体
    return defaultVariant;
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    if (description != null) 'description': description,
    'enabled': enabled,
    'type': type.name,
    'defaultVariant': defaultVariant.toJson(),
    'variants': variants.map((v) => v.toJson()).toList(),
    'rules': rules.map((r) => r.toJson()).toList(),
    'rolloutPercentage': rolloutPercentage,
    if (startTime != null) 'startTime': startTime!.toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toIso8601String(),
    if (metadata != null) 'metadata': metadata,
  };
}

/// 功能开关服务
///
/// 核心功能：
/// 1. 功能开关管理
/// 2. A/B 测试支持
/// 3. 灰度发布
/// 4. 目标规则
/// 5. 用户权限集成（第35章）
///
/// 对应设计文档：第24章 可扩展性与演进架构、第35章 用户体系与权限设计
/// 对应实施方案：轨道L 容错与扩展模块、轨道N 用户体系与权限
class FeatureFlagService extends ChangeNotifier {
  static final FeatureFlagService _instance = FeatureFlagService._();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._();

  final Map<String, FeatureFlag> _flags = {};
  final Map<String, dynamic> _globalContext = {};
  final Map<String, FeatureVariant> _evaluationCache = {};

  bool _initialized = false;
  Timer? _refreshTimer;

  /// 用户访问服务引用
  UserAccessService? _userAccessService;

  /// 远程配置加载器
  Future<Map<String, FeatureFlag>> Function()? _remoteLoader;

  /// 初始化服务
  Future<void> initialize({
    Map<String, FeatureFlag>? defaultFlags,
    Future<Map<String, FeatureFlag>> Function()? remoteLoader,
    Duration refreshInterval = const Duration(minutes: 5),
    Map<String, dynamic>? globalContext,
    UserAccessService? userAccessService,
  }) async {
    if (_initialized) return;

    // 设置用户访问服务
    _userAccessService = userAccessService ?? UserAccessService();

    // 加载默认配置
    if (defaultFlags != null) {
      _flags.addAll(defaultFlags);
    }

    // 设置全局上下文
    if (globalContext != null) {
      _globalContext.addAll(globalContext);
    }

    // 设置远程加载器
    _remoteLoader = remoteLoader;

    // 从远程加载配置
    if (_remoteLoader != null) {
      try {
        final remoteFlags = await _remoteLoader!();
        _flags.addAll(remoteFlags);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to load remote feature flags: $e');
        }
      }

      // 启动定期刷新
      _refreshTimer = Timer.periodic(refreshInterval, (_) => refresh());
    }

    _initialized = true;
  }

  /// 设置全局上下文
  void setGlobalContext(Map<String, dynamic> context) {
    _globalContext.clear();
    _globalContext.addAll(context);
    _evaluationCache.clear();
    notifyListeners();
  }

  /// 更新全局上下文
  void updateGlobalContext(String key, dynamic value) {
    _globalContext[key] = value;
    _evaluationCache.clear();
    notifyListeners();
  }

  /// 检查功能是否启用
  bool isEnabled(String key, {Map<String, dynamic>? context}) {
    final flag = _flags[key];
    if (flag == null) return false;

    final mergedContext = {..._globalContext, ...?context};
    final variant = flag.evaluate(mergedContext);

    if (flag.type == VariantType.boolean) {
      return variant.value == true;
    }

    return flag.enabled;
  }

  /// 检查功能是否可用（综合功能开关 + 用户权限）
  ///
  /// 此方法同时检查：
  /// 1. 功能开关是否启用
  /// 2. 当前用户是否有权限访问该功能
  ///
  /// 对应设计文档：第35章 用户体系与权限设计
  FeatureAvailabilityResult isFeatureAvailable(
    String featureId, {
    Map<String, dynamic>? context,
  }) {
    // 1. 检查功能开关
    final flagEnabled = isEnabled(featureId, context: context);
    if (!flagEnabled) {
      return FeatureAvailabilityResult(
        available: false,
        reason: FeatureUnavailableReason.featureFlagDisabled,
        message: '功能暂未开放',
      );
    }

    // 2. 检查用户权限
    if (_userAccessService != null) {
      final accessResult = _userAccessService!.checkFeatureAccess(featureId);
      if (!accessResult.canAccess) {
        return FeatureAvailabilityResult(
          available: false,
          reason: FeatureUnavailableReason.userPermissionDenied,
          message: accessResult.deniedReason ?? '需要登录后才能使用此功能',
          requiredUserType: accessResult.requiredUserType,
        );
      }
    }

    return FeatureAvailabilityResult(available: true);
  }

  /// 检查AI功能是否可用（快捷方法）
  ///
  /// AI功能需要登录用户才能使用
  bool canUseAIFeature(String featureId) {
    final result = isFeatureAvailable(featureId);
    return result.available;
  }

  /// 获取功能不可用的原因
  FeatureAvailabilityResult getFeatureAvailability(String featureId) {
    return isFeatureAvailable(featureId);
  }

  /// 设置用户访问服务
  void setUserAccessService(UserAccessService service) {
    _userAccessService = service;
    _evaluationCache.clear();
    notifyListeners();
  }

  /// 获取当前用户类型
  UserType? get currentUserType => _userAccessService?.userType;

  /// 是否是访客
  bool get isGuest => _userAccessService?.isGuest ?? true;

  /// 是否已登录
  bool get isLoggedIn => _userAccessService?.isLoggedIn ?? false;

  /// 获取功能变体值
  T? getValue<T>(String key, {Map<String, dynamic>? context}) {
    final flag = _flags[key];
    if (flag == null) return null;

    final cacheKey = '$key-${context?.hashCode ?? 0}';

    // 检查缓存
    if (_evaluationCache.containsKey(cacheKey)) {
      return _evaluationCache[cacheKey]!.value as T?;
    }

    final mergedContext = {..._globalContext, ...?context};
    final variant = flag.evaluate(mergedContext);

    _evaluationCache[cacheKey] = variant;

    return variant.value as T?;
  }

  /// 获取功能变体
  FeatureVariant? getVariant(String key, {Map<String, dynamic>? context}) {
    final flag = _flags[key];
    if (flag == null) return null;

    final mergedContext = {..._globalContext, ...?context};
    return flag.evaluate(mergedContext);
  }

  /// 获取所有功能开关
  Map<String, FeatureFlag> getAllFlags() {
    return Map.unmodifiable(_flags);
  }

  /// 获取功能开关
  FeatureFlag? getFlag(String key) {
    return _flags[key];
  }

  /// 注册功能开关
  void registerFlag(FeatureFlag flag) {
    _flags[flag.key] = flag;
    _evaluationCache.clear();
    notifyListeners();
  }

  /// 批量注册功能开关
  void registerFlags(List<FeatureFlag> flags) {
    for (final flag in flags) {
      _flags[flag.key] = flag;
    }
    _evaluationCache.clear();
    notifyListeners();
  }

  /// 移除功能开关
  void removeFlag(String key) {
    _flags.remove(key);
    _evaluationCache.clear();
    notifyListeners();
  }

  /// 刷新远程配置
  Future<void> refresh() async {
    if (_remoteLoader == null) return;

    try {
      final remoteFlags = await _remoteLoader!();
      _flags.addAll(remoteFlags);
      _evaluationCache.clear();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to refresh feature flags: $e');
      }
    }
  }

  /// 导出配置为 JSON
  String exportToJson() {
    final data = _flags.map((key, flag) => MapEntry(key, flag.toJson()));
    return jsonEncode(data);
  }

  /// 从 JSON 导入配置
  void importFromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    for (final entry in data.entries) {
      // 简化导入，实际需要完整的 fromJson 实现
      final flagData = entry.value as Map<String, dynamic>;
      final flag = FeatureFlag(
        key: entry.key,
        name: flagData['name'] as String,
        description: flagData['description'] as String?,
        enabled: flagData['enabled'] as bool? ?? true,
        defaultVariant: FeatureVariant.fromJson(
          flagData['defaultVariant'] as Map<String, dynamic>,
        ),
        rolloutPercentage: (flagData['rolloutPercentage'] as num?)?.toDouble() ?? 100,
      );
      _flags[entry.key] = flag;
    }
    _evaluationCache.clear();
    notifyListeners();
  }

  /// 关闭服务
  Future<void> close() async {
    _refreshTimer?.cancel();
    _flags.clear();
    _evaluationCache.clear();
    _initialized = false;
  }
}

/// 预定义功能开关
class AppFeatureFlags {
  AppFeatureFlags._();

  /// 钱龄功能
  static const moneyAge = FeatureFlag(
    key: 'money_age',
    name: '钱龄分析',
    description: '启用钱龄分析功能',
    enabled: true,
    defaultVariant: FeatureVariant(name: 'enabled', value: true),
  );

  /// 零基预算
  static const zeroBudget = FeatureFlag(
    key: 'zero_based_budget',
    name: '零基预算',
    description: '启用零基预算功能',
    enabled: true,
    defaultVariant: FeatureVariant(name: 'enabled', value: true),
  );

  /// 小金库
  static const budgetVault = FeatureFlag(
    key: 'budget_vault',
    name: '小金库',
    description: '启用小金库功能',
    enabled: true,
    defaultVariant: FeatureVariant(name: 'enabled', value: true),
  );

  /// 财务习惯
  static const financialHabit = FeatureFlag(
    key: 'financial_habit',
    name: '财务习惯',
    description: '启用财务习惯追踪功能',
    enabled: true,
    defaultVariant: FeatureVariant(name: 'enabled', value: true),
  );

  /// AI 识别
  static const aiRecognition = FeatureFlag(
    key: 'ai_recognition',
    name: 'AI识别',
    description: '启用AI智能识别功能',
    enabled: true,
    defaultVariant: FeatureVariant(name: 'enabled', value: true),
  );

  /// 地理位置
  static const geoLocation = FeatureFlag(
    key: 'geo_location',
    name: '地理位置',
    description: '启用地理位置功能',
    enabled: true,
    defaultVariant: FeatureVariant(name: 'enabled', value: true),
  );

  /// 离线同步
  static const offlineSync = FeatureFlag(
    key: 'offline_sync',
    name: '离线同步',
    description: '启用离线同步功能',
    enabled: true,
    defaultVariant: FeatureVariant(name: 'enabled', value: true),
  );

  /// 协作预算（2.1版本）
  static const collaborativeBudget = FeatureFlag(
    key: 'collaborative_budget',
    name: '协作预算',
    description: '启用协作预算功能（2.1版本）',
    enabled: false,
    defaultVariant: FeatureVariant(name: 'disabled', value: false),
  );

  /// 智能投资（2.2版本）
  static const smartInvestment = FeatureFlag(
    key: 'smart_investment',
    name: '智能投资',
    description: '启用智能投资功能（2.2版本）',
    enabled: false,
    defaultVariant: FeatureVariant(name: 'disabled', value: false),
  );

  /// 获取所有默认功能开关
  static Map<String, FeatureFlag> get defaults => {
    'money_age': moneyAge,
    'zero_based_budget': zeroBudget,
    'budget_vault': budgetVault,
    'financial_habit': financialHabit,
    'ai_recognition': aiRecognition,
    'geo_location': geoLocation,
    'offline_sync': offlineSync,
    'collaborative_budget': collaborativeBudget,
    'smart_investment': smartInvestment,
  };
}

/// 功能不可用原因
enum FeatureUnavailableReason {
  /// 功能开关已禁用
  featureFlagDisabled,

  /// 用户权限不足
  userPermissionDenied,

  /// 灰度发布未覆盖
  rolloutNotIncluded,

  /// 时间范围外
  outsideTimeRange,
}

/// 功能可用性检查结果
class FeatureAvailabilityResult {
  /// 功能是否可用
  final bool available;

  /// 不可用原因
  final FeatureUnavailableReason? reason;

  /// 提示消息
  final String? message;

  /// 所需用户类型
  final UserType? requiredUserType;

  const FeatureAvailabilityResult({
    required this.available,
    this.reason,
    this.message,
    this.requiredUserType,
  });

  /// 功能可用
  factory FeatureAvailabilityResult.available() {
    return const FeatureAvailabilityResult(available: true);
  }

  /// 功能不可用 - 需要登录
  factory FeatureAvailabilityResult.loginRequired({String? message}) {
    return FeatureAvailabilityResult(
      available: false,
      reason: FeatureUnavailableReason.userPermissionDenied,
      message: message ?? '此功能需要登录后才能使用',
      requiredUserType: UserType.loggedIn,
    );
  }

  /// 功能不可用 - 功能未开放
  factory FeatureAvailabilityResult.disabled({String? message}) {
    return FeatureAvailabilityResult(
      available: false,
      reason: FeatureUnavailableReason.featureFlagDisabled,
      message: message ?? '功能暂未开放',
    );
  }

  /// 是否需要登录
  bool get needsLogin =>
      !available && reason == FeatureUnavailableReason.userPermissionDenied;
}

/// 全局功能开关实例
final featureFlags = FeatureFlagService();
