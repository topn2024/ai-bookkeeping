import 'dart:async';
import 'package:flutter/foundation.dart';

/// 筛选条件类型
enum FilterType {
  /// 时间范围
  dateRange,

  /// 分类
  category,

  /// 账户
  account,

  /// 金额范围
  amountRange,

  /// 标签
  tag,

  /// 家庭成员
  familyMember,

  /// 位置
  location,

  /// 钱龄等级
  moneyAgeLevel,

  /// 预算
  budget,

  /// 交易类型（收入/支出）
  transactionType,

  /// 关键词搜索
  keyword,

  /// 自定义
  custom,
}

/// 筛选条件
class FilterCondition {
  /// 筛选类型
  final FilterType type;

  /// 筛选值
  final dynamic value;

  /// 显示标签
  final String displayLabel;

  /// 是否激活
  final bool isActive;

  /// 创建时间
  final DateTime createdAt;

  /// 元数据
  final Map<String, dynamic>? metadata;

  const FilterCondition({
    required this.type,
    required this.value,
    required this.displayLabel,
    this.isActive = true,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? const _ConstDateTime();

  FilterCondition copyWith({
    FilterType? type,
    dynamic value,
    String? displayLabel,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return FilterCondition(
      type: type ?? this.type,
      value: value ?? this.value,
      displayLabel: displayLabel ?? this.displayLabel,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 生成唯一键
  String get key => '${type.name}_${value.hashCode}';

  @override
  String toString() => 'FilterCondition($type: $displayLabel)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterCondition && other.type == type && other.value == value;
  }

  @override
  int get hashCode => type.hashCode ^ value.hashCode;
}

/// 常量日期时间（用于const构造函数）
class _ConstDateTime implements DateTime {
  const _ConstDateTime();

  @override
  DateTime add(Duration duration) => DateTime.now().add(duration);

  @override
  int compareTo(DateTime other) => DateTime.now().compareTo(other);

  @override
  int get day => DateTime.now().day;

  @override
  Duration difference(DateTime other) => DateTime.now().difference(other);

  @override
  int get hour => DateTime.now().hour;

  @override
  bool isAfter(DateTime other) => DateTime.now().isAfter(other);

  @override
  bool isAtSameMomentAs(DateTime other) => DateTime.now().isAtSameMomentAs(other);

  @override
  bool isBefore(DateTime other) => DateTime.now().isBefore(other);

  @override
  bool get isUtc => false;

  @override
  int get microsecond => DateTime.now().microsecond;

  @override
  int get microsecondsSinceEpoch => DateTime.now().microsecondsSinceEpoch;

  @override
  int get millisecond => DateTime.now().millisecond;

  @override
  int get millisecondsSinceEpoch => DateTime.now().millisecondsSinceEpoch;

  @override
  int get minute => DateTime.now().minute;

  @override
  int get month => DateTime.now().month;

  @override
  int get second => DateTime.now().second;

  @override
  DateTime subtract(Duration duration) => DateTime.now().subtract(duration);

  @override
  String get timeZoneName => DateTime.now().timeZoneName;

  @override
  Duration get timeZoneOffset => DateTime.now().timeZoneOffset;

  @override
  String toIso8601String() => DateTime.now().toIso8601String();

  @override
  DateTime toLocal() => DateTime.now().toLocal();

  @override
  DateTime toUtc() => DateTime.now().toUtc();

  @override
  int get weekday => DateTime.now().weekday;

  @override
  int get year => DateTime.now().year;
}

/// 筛选状态
class FilterState {
  /// 所有筛选条件
  final Map<String, FilterCondition> conditions;

  /// 是否有任何激活的筛选
  bool get hasActiveFilters => conditions.values.any((c) => c.isActive);

  /// 激活的筛选条件数量
  int get activeFilterCount => conditions.values.where((c) => c.isActive).length;

  /// 获取激活的筛选条件列表
  List<FilterCondition> get activeConditions =>
      conditions.values.where((c) => c.isActive).toList();

  /// 最后更新时间
  final DateTime lastUpdated;

  FilterState({
    Map<String, FilterCondition>? conditions,
    DateTime? lastUpdated,
  })  : conditions = conditions ?? {},
        lastUpdated = lastUpdated ?? DateTime.now();

  FilterState copyWith({
    Map<String, FilterCondition>? conditions,
  }) {
    return FilterState(
      conditions: conditions ?? Map.from(this.conditions),
      lastUpdated: DateTime.now(),
    );
  }

  /// 添加筛选条件
  FilterState addCondition(FilterCondition condition) {
    final newConditions = Map<String, FilterCondition>.from(conditions);
    newConditions[condition.key] = condition;
    return copyWith(conditions: newConditions);
  }

  /// 移除筛选条件
  FilterState removeCondition(String key) {
    final newConditions = Map<String, FilterCondition>.from(conditions);
    newConditions.remove(key);
    return copyWith(conditions: newConditions);
  }

  /// 切换筛选条件激活状态
  FilterState toggleCondition(String key) {
    final condition = conditions[key];
    if (condition == null) return this;

    return addCondition(condition.copyWith(isActive: !condition.isActive));
  }

  /// 清除所有筛选条件
  FilterState clear() {
    return FilterState();
  }

  /// 清除指定类型的筛选条件
  FilterState clearByType(FilterType type) {
    final newConditions = Map<String, FilterCondition>.from(conditions);
    newConditions.removeWhere((_, c) => c.type == type);
    return copyWith(conditions: newConditions);
  }

  /// 获取指定类型的筛选条件
  List<FilterCondition> getByType(FilterType type) {
    return conditions.values.where((c) => c.type == type).toList();
  }

  /// 转换为查询参数
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    for (final condition in activeConditions) {
      params[condition.type.name] = condition.value;
    }
    return params;
  }
}

/// 页面筛选配置
class PageFilterConfig {
  /// 页面标识
  final String pageId;

  /// 支持的筛选类型
  final Set<FilterType> supportedTypes;

  /// 默认筛选条件
  final List<FilterCondition> defaultConditions;

  /// 是否持久化
  final bool persist;

  /// 是否与其他页面共享
  final bool shareWithPages;

  /// 共享的页面ID列表
  final Set<String>? sharedPageIds;

  const PageFilterConfig({
    required this.pageId,
    required this.supportedTypes,
    this.defaultConditions = const [],
    this.persist = true,
    this.shareWithPages = false,
    this.sharedPageIds,
  });
}

/// 跨页面筛选条件状态保持服务
///
/// 核心功能：
/// 1. 跨页面保持筛选条件
/// 2. 支持多种筛选类型
/// 3. 筛选条件持久化
/// 4. 页面间筛选共享
/// 5. 状态变化通知
///
/// 对应设计文档：第12.4.2节 跨页面状态保持
///
/// 使用示例：
/// ```dart
/// final service = FilterStateService();
///
/// // 配置页面筛选
/// service.configurePage(PageFilterConfig(
///   pageId: 'transaction_list',
///   supportedTypes: {FilterType.dateRange, FilterType.category},
/// ));
///
/// // 添加筛选条件
/// service.addFilter(
///   pageId: 'transaction_list',
///   condition: FilterCondition(
///     type: FilterType.category,
///     value: 'food',
///     displayLabel: '餐饮',
///   ),
/// );
///
/// // 获取筛选状态
/// final state = service.getState('transaction_list');
/// ```
class FilterStateService {
  /// 页面筛选状态
  final Map<String, FilterState> _pageStates = {};

  /// 页面配置
  final Map<String, PageFilterConfig> _pageConfigs = {};

  /// 全局筛选状态（跨页面共享）
  FilterState _globalState = FilterState();

  /// 状态变化流控制器
  final StreamController<FilterStateChange> _stateController =
      StreamController<FilterStateChange>.broadcast();

  FilterStateService();

  /// 状态变化流
  Stream<FilterStateChange> get stateChanges => _stateController.stream;

  /// 状态变化流（别名，用于兼容）
  Stream<FilterStateChange> get stateStream => _stateController.stream;

  /// 获取全局筛选状态
  FilterState get globalState => _globalState;

  /// 获取当前状态（返回全局状态）
  FilterState get currentState => _globalState;

  /// 直接添加条件到全局状态
  void addCondition(FilterCondition condition) {
    _globalState = _globalState.addCondition(condition);
    _emitChange(FilterStateChange(
      pageId: 'global',
      changeType: FilterChangeType.add,
      condition: condition,
      newState: _globalState,
    ));
  }

  /// 直接从全局状态移除条件
  void removeCondition(String key) {
    _globalState = _globalState.removeCondition(key);
    _emitChange(FilterStateChange(
      pageId: 'global',
      changeType: FilterChangeType.remove,
      conditionKey: key,
      newState: _globalState,
    ));
  }

  /// 切换全局状态中的条件
  void toggleCondition(String key) {
    _globalState = _globalState.toggleCondition(key);
    _emitChange(FilterStateChange(
      pageId: 'global',
      changeType: FilterChangeType.toggle,
      conditionKey: key,
      newState: _globalState,
    ));
  }

  /// 清除全局状态所有条件
  void clearAll() {
    _globalState = FilterState();
    _emitChange(FilterStateChange(
      pageId: 'global',
      changeType: FilterChangeType.clear,
      newState: _globalState,
    ));
  }

  /// 设置全局状态条件
  void setConditions(List<FilterCondition> conditions) {
    _globalState = FilterState();
    for (final condition in conditions) {
      _globalState = _globalState.addCondition(condition);
    }
    _emitChange(FilterStateChange(
      pageId: 'global',
      changeType: FilterChangeType.sync,
      newState: _globalState,
    ));
  }

  /// 配置页面
  void configurePage(PageFilterConfig config) {
    _pageConfigs[config.pageId] = config;

    // 初始化页面状态
    if (!_pageStates.containsKey(config.pageId)) {
      var state = FilterState();

      // 应用默认筛选条件
      for (final condition in config.defaultConditions) {
        state = state.addCondition(condition);
      }

      _pageStates[config.pageId] = state;
    }
  }

  /// 获取页面筛选状态
  FilterState getState(String pageId) {
    return _pageStates[pageId] ?? FilterState();
  }

  /// 添加筛选条件
  void addFilter({
    required String pageId,
    required FilterCondition condition,
    bool shareToGlobal = false,
  }) {
    final config = _pageConfigs[pageId];

    // 检查是否支持该筛选类型
    if (config != null && !config.supportedTypes.contains(condition.type)) {
      debugPrint('Filter type ${condition.type} not supported for page $pageId');
      return;
    }

    // 更新页面状态
    final oldState = getState(pageId);
    final newState = oldState.addCondition(condition);
    _pageStates[pageId] = newState;

    // 如果需要共享到全局
    if (shareToGlobal) {
      _globalState = _globalState.addCondition(condition);
    }

    // 共享到其他页面
    if (config?.shareWithPages == true && config?.sharedPageIds != null) {
      for (final sharedPageId in config!.sharedPageIds!) {
        final sharedState = getState(sharedPageId);
        _pageStates[sharedPageId] = sharedState.addCondition(condition);
      }
    }

    // 发送状态变化事件
    _emitChange(FilterStateChange(
      pageId: pageId,
      changeType: FilterChangeType.add,
      condition: condition,
      newState: newState,
    ));
  }

  /// 移除筛选条件
  void removeFilter({
    required String pageId,
    required String conditionKey,
  }) {
    final oldState = getState(pageId);
    final newState = oldState.removeCondition(conditionKey);
    _pageStates[pageId] = newState;

    _emitChange(FilterStateChange(
      pageId: pageId,
      changeType: FilterChangeType.remove,
      conditionKey: conditionKey,
      newState: newState,
    ));
  }

  /// 切换筛选条件
  void toggleFilter({
    required String pageId,
    required String conditionKey,
  }) {
    final oldState = getState(pageId);
    final newState = oldState.toggleCondition(conditionKey);
    _pageStates[pageId] = newState;

    _emitChange(FilterStateChange(
      pageId: pageId,
      changeType: FilterChangeType.toggle,
      conditionKey: conditionKey,
      newState: newState,
    ));
  }

  /// 清除页面筛选
  void clearFilters(String pageId, {FilterType? type}) {
    final oldState = getState(pageId);
    final newState = type != null ? oldState.clearByType(type) : oldState.clear();
    _pageStates[pageId] = newState;

    _emitChange(FilterStateChange(
      pageId: pageId,
      changeType: FilterChangeType.clear,
      newState: newState,
    ));
  }

  /// 同步到全局状态
  void syncToGlobal(String pageId) {
    final pageState = getState(pageId);
    for (final condition in pageState.activeConditions) {
      _globalState = _globalState.addCondition(condition);
    }
  }

  /// 从全局状态同步
  void syncFromGlobal(String pageId) {
    final config = _pageConfigs[pageId];
    if (config == null) return;

    var pageState = getState(pageId);
    for (final condition in _globalState.activeConditions) {
      if (config.supportedTypes.contains(condition.type)) {
        pageState = pageState.addCondition(condition);
      }
    }
    _pageStates[pageId] = pageState;
  }

  /// 发送状态变化事件
  void _emitChange(FilterStateChange change) {
    _stateController.add(change);
  }

  /// 释放资源
  void dispose() {
    _stateController.close();
  }
}

/// 筛选状态变化类型
enum FilterChangeType {
  add,
  remove,
  toggle,
  clear,
  sync,
}

/// 筛选状态变化事件
class FilterStateChange {
  final String pageId;
  final FilterChangeType changeType;
  final FilterCondition? condition;
  final String? conditionKey;
  final FilterState newState;
  final DateTime timestamp;

  FilterStateChange({
    required this.pageId,
    required this.changeType,
    this.condition,
    this.conditionKey,
    required this.newState,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
