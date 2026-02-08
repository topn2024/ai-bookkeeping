import 'dart:async';
import 'package:flutter/material.dart';

import 'drill_down_navigation_service.dart';
import 'filter_state_service.dart';
import 'breadcrumb_state_manager.dart';

/// 数据联动系统入口
/// 对应设计文档第12章：数据联动与可视化
///
/// 核心功能：
/// 1. 统一管理下钻、筛选、面包屑
/// 2. 跨页面状态同步
/// 3. 与2.0核心模块协同
/// 4. 事件总线
///
/// 使用示例：
/// ```dart
/// final linkage = DataLinkageService();
///
/// // 开始下钻
/// linkage.startDrillDown(
///   dimension: DrillDownDimension.category,
///   title: '餐饮',
///   targetPage: CategoryDetailPage(),
/// );
///
/// // 添加筛选
/// linkage.addFilter(FilterCondition(
///   type: FilterType.dateRange,
///   value: DateRange(...),
///   displayLabel: '本月',
/// ));
/// ```
class DataLinkageService extends ChangeNotifier {
  /// 下钻导航服务
  final DrillDownNavigationService drillDownService;

  /// 筛选状态服务
  final FilterStateService filterService;

  /// 面包屑状态管理器
  final BreadcrumbStateManager breadcrumbManager;

  /// 全局导航键（用于跨页面导航）
  final GlobalKey<NavigatorState>? navigatorKey;

  /// 联动事件流
  final StreamController<DataLinkageEvent> _eventController =
      StreamController<DataLinkageEvent>.broadcast();

  /// 页面栈（用于跟踪页面层级）
  final List<String> _pageStack = [];

  /// 服务订阅
  final List<StreamSubscription> _subscriptions = [];

  DataLinkageService({
    DrillDownNavigationService? drillDownService,
    FilterStateService? filterService,
    BreadcrumbStateManager? breadcrumbManager,
    this.navigatorKey,
  })  : drillDownService = drillDownService ?? DrillDownNavigationService(),
        filterService = filterService ?? FilterStateService(),
        breadcrumbManager = breadcrumbManager ??
            BreadcrumbStateManager(
              navigationService: drillDownService ?? DrillDownNavigationService(),
            ) {
    _init();
  }

  /// 初始化
  void _init() {
    // 监听下钻事件
    _subscriptions.add(
      drillDownService.events.listen(_onDrillDownEvent),
    );

    // 监听筛选变化
    _subscriptions.add(
      filterService.stateStream.listen((change) => _onFilterStateChanged(change.newState)),
    );

    // 监听面包屑点击
    _subscriptions.add(
      breadcrumbManager.tapStream.listen(_onBreadcrumbTap),
    );
  }

  /// 联动事件流
  Stream<DataLinkageEvent> get events => _eventController.stream;

  /// 当前下钻路径
  DrillDownPath get currentPath => drillDownService.currentPath;

  /// 当前筛选状态
  FilterState get filterState => filterService.currentState;

  /// 面包屑列表
  List<String> get breadcrumbs => breadcrumbManager.currentState.visibleItems
      .map((item) => item.label)
      .toList();

  /// 是否可以返回
  bool get canGoBack =>
      drillDownService.canGoBack || _pageStack.length > 1;

  // ========== 下钻功能 ==========

  /// 开始新的下钻
  Future<void> startDrillDown({
    required DrillDownDimension dimension,
    required String title,
    Map<String, dynamic>? metadata,
    Widget? targetPage,
    bool pushPage = true,
  }) async {
    drillDownService.startDrillDown(
      dimension: dimension,
      title: title,
      metadata: metadata,
    );

    // 安全地访问navigator state
    final navState = navigatorKey?.currentState;
    if (targetPage != null && pushPage && navState != null) {
      await navState.push(
        MaterialPageRoute(builder: (_) => targetPage),
      );
      _pageStack.add(title);
    }

    _emitEvent(DataLinkageStartEvent(
      dimension: dimension,
      title: title,
    ));

    notifyListeners();
  }

  /// 下钻到下一层
  Future<void> drillDown({
    required String id,
    required String title,
    dynamic filterValue,
    Map<String, dynamic>? metadata,
    Widget? targetPage,
    bool pushPage = true,
  }) async {
    drillDownService.drillDown(
      id: id,
      title: title,
      filterValue: filterValue,
      metadata: metadata,
    );

    // 安全地访问navigator state
    final navState = navigatorKey?.currentState;
    if (targetPage != null && pushPage && navState != null) {
      await navState.push(
        MaterialPageRoute(builder: (_) => targetPage),
      );
      _pageStack.add(title);
    }

    _emitEvent(DataLinkageDownEvent(
      id: id,
      title: title,
    ));

    notifyListeners();
  }

  /// 返回上一级
  bool goBack() {
    final success = drillDownService.goBack();

    if (success) {
      if (_pageStack.isNotEmpty) {
        _pageStack.removeLast();
      }

      // 安全地访问navigator state
      final navState = navigatorKey?.currentState;
      if (navState?.canPop() == true) {
        navState!.pop();
      }

      _emitEvent(DataLinkageBackEvent());
      notifyListeners();
    }

    return success;
  }

  /// 返回到指定层级
  bool goBackTo(int depth) {
    final success = drillDownService.goBackTo(depth);

    if (success) {
      // 计算需要pop的页面数
      final popCount = _pageStack.length - depth - 1;
      // 安全地访问navigator state
      final navState = navigatorKey?.currentState;
      for (int i = 0; i < popCount && navState?.canPop() == true; i++) {
        navState!.pop();
        if (_pageStack.isNotEmpty) {
          _pageStack.removeLast();
        }
      }

      _emitEvent(DataLinkageBackToEvent(depth: depth));
      notifyListeners();
    }

    return success;
  }

  /// 重置下钻
  void resetDrillDown() {
    drillDownService.reset();

    // 返回到根页面
    // 安全地访问navigator state
    final navState = navigatorKey?.currentState;
    while (_pageStack.isNotEmpty && navState?.canPop() == true) {
      navState!.pop();
      _pageStack.removeLast();
    }

    _emitEvent(DataLinkageResetEvent());
    notifyListeners();
  }

  // ========== 筛选功能 ==========

  /// 添加筛选条件
  void addFilter(FilterCondition condition) {
    filterService.addCondition(condition);
    _emitEvent(DataLinkageFilterAddEvent(condition: condition));
    notifyListeners();
  }

  /// 移除筛选条件
  void removeFilter(String key) {
    filterService.removeCondition(key);
    _emitEvent(DataLinkageFilterRemoveEvent(key: key));
    notifyListeners();
  }

  /// 切换筛选条件激活状态
  void toggleFilter(String key) {
    filterService.toggleCondition(key);
    notifyListeners();
  }

  /// 清空所有筛选
  void clearFilters() {
    filterService.clearAll();
    _emitEvent(DataLinkageClearFiltersEvent());
    notifyListeners();
  }

  /// 批量设置筛选
  void setFilters(List<FilterCondition> conditions) {
    filterService.setConditions(conditions);
    notifyListeners();
  }

  // ========== 快捷联动方法 ==========

  /// 点击分类卡片联动
  Future<void> onCategoryCardTap({
    required String categoryId,
    required String categoryName,
    Widget? detailPage,
  }) async {
    await drillDown(
      id: 'category_$categoryId',
      title: categoryName,
      filterValue: {'categoryId': categoryId},
      targetPage: detailPage,
    );
  }

  /// 点击趋势图数据点联动
  Future<void> onTrendPointTap({
    required DateTime date,
    Widget? detailPage,
  }) async {
    await drillDown(
      id: 'date_${date.millisecondsSinceEpoch}',
      title: '${date.month}月${date.day}日',
      filterValue: {'date': date},
      targetPage: detailPage,
    );
  }

  /// 点击账户卡片联动
  Future<void> onAccountCardTap({
    required String accountId,
    required String accountName,
    Widget? detailPage,
  }) async {
    await drillDown(
      id: 'account_$accountId',
      title: accountName,
      filterValue: {'accountId': accountId},
      targetPage: detailPage,
    );
  }

  /// 点击家庭成员卡片联动
  Future<void> onFamilyMemberCardTap({
    required String memberId,
    required String memberName,
    Widget? detailPage,
  }) async {
    await drillDown(
      id: 'member_$memberId',
      title: memberName,
      filterValue: {'memberId': memberId},
      targetPage: detailPage,
    );
  }

  /// 点击位置热力图联动
  Future<void> onLocationHeatmapTap({
    required double latitude,
    required double longitude,
    required String locationName,
    Widget? detailPage,
  }) async {
    await drillDown(
      id: 'location_${latitude}_$longitude',
      title: locationName,
      filterValue: {
        'latitude': latitude,
        'longitude': longitude,
      },
      targetPage: detailPage,
    );
  }

  /// 点击预算卡片联动
  Future<void> onBudgetCardTap({
    required String budgetId,
    required String budgetName,
    Widget? detailPage,
  }) async {
    await drillDown(
      id: 'budget_$budgetId',
      title: budgetName,
      filterValue: {'budgetId': budgetId},
      targetPage: detailPage,
    );
  }

  /// 点击钱龄卡片联动
  Future<void> onMoneyAgeCardTap({
    required String level,
    required String levelName,
    Widget? detailPage,
  }) async {
    await drillDown(
      id: 'moneyage_$level',
      title: levelName,
      filterValue: {'moneyAgeLevel': level},
      targetPage: detailPage,
    );
  }

  /// 点击习惯卡片联动
  Future<void> onHabitCardTap({
    required String habitType,
    required String habitName,
    Widget? detailPage,
  }) async {
    await drillDown(
      id: 'habit_$habitType',
      title: habitName,
      filterValue: {'habitType': habitType},
      targetPage: detailPage,
    );
  }

  // ========== 事件处理 ==========

  void _onDrillDownEvent(DrillDownEvent event) {
    // 下钻事件已经通过 _emitEvent 发送
  }

  void _onFilterStateChanged(FilterState state) {
    _emitEvent(DataLinkageFilterChangedEvent(state: state));
  }

  void _onBreadcrumbTap(BreadcrumbItem item) {
    goBackTo(item.depth);
  }

  void _emitEvent(DataLinkageEvent event) {
    _eventController.add(event);
  }

  // ========== 数据查询辅助 ==========

  /// 获取当前的完整查询参数
  /// 结合下钻路径和筛选条件
  Map<String, dynamic> getQueryParams() {
    final params = <String, dynamic>{};

    // 添加下钻路径的筛选
    params.addAll(drillDownService.currentFilters);

    // 添加显式筛选条件
    for (final condition in filterService.currentState.activeConditions) {
      params[condition.type.name] = condition.value;
    }

    return params;
  }

  /// 获取面包屑路径文本
  String getBreadcrumbPath() {
    return breadcrumbs.join(' > ');
  }

  // ========== 状态持久化 ==========

  /// 保存当前状态（用于跨页面恢复）
  Map<String, dynamic> saveState() {
    return {
      'drillDownPath': currentPath.nodes.map((n) => {
        'id': n.id,
        'title': n.title,
        'dimension': n.dimension.name,
        'depth': n.depth,
        'filterValue': n.filterValue,
      }).toList(),
      'filters': filterService.currentState.conditions.values.map((c) => {
        'type': c.type.name,
        'value': c.value,
        'displayLabel': c.displayLabel,
        'isActive': c.isActive,
      }).toList(),
      'pageStack': _pageStack,
    };
  }

  /// 恢复状态
  void restoreState(Map<String, dynamic> state) {
    try {
      // 1. 恢复下钻路径
      final drillDownPathData = state['drillDownPath'] as List<dynamic>?;
      if (drillDownPathData != null && drillDownPathData.isNotEmpty) {
        // 重置当前路径
        drillDownService.reset();

        // 重建路径节点
        for (final nodeData in drillDownPathData) {
          final nodeMap = nodeData as Map<String, dynamic>;
          final dimensionName = nodeMap['dimension'] as String;
          final dimension = DrillDownDimension.values.firstWhere(
            (d) => d.name == dimensionName,
            orElse: () => DrillDownDimension.category,
          );

          final id = nodeMap['id'] as String;
          final title = nodeMap['title'] as String;
          final filterValue = nodeMap['filterValue'];
          final depth = nodeMap['depth'] as int;

          // 根据深度判断是否是第一个节点
          if (depth == 0) {
            // 第一个节点使用startDrillDown
            drillDownService.startDrillDown(
              dimension: dimension,
              title: title,
              metadata: {'id': id, 'filterValue': filterValue},
            );
          } else {
            // 后续节点使用drillDown
            drillDownService.drillDown(
              id: id,
              title: title,
              filterValue: filterValue,
            );
          }
        }
      }

      // 2. 恢复筛选条件
      final filtersData = state['filters'] as List<dynamic>?;
      if (filtersData != null && filtersData.isNotEmpty) {
        // 清空当前筛选
        filterService.clearAll();

        // 重建筛选条件
        final conditions = <FilterCondition>[];
        for (final filterData in filtersData) {
          final filterMap = filterData as Map<String, dynamic>;
          final typeName = filterMap['type'] as String;
          final filterType = FilterType.values.firstWhere(
            (t) => t.name == typeName,
            orElse: () => FilterType.custom,
          );

          final condition = FilterCondition(
            type: filterType,
            value: filterMap['value'],
            displayLabel: filterMap['displayLabel'] as String,
            isActive: filterMap['isActive'] as bool? ?? true,
          );

          conditions.add(condition);
        }

        // 批量设置筛选条件
        filterService.setConditions(conditions);
      }

      // 3. 恢复页面栈
      final pageStackData = state['pageStack'] as List<dynamic>?;
      if (pageStackData != null) {
        _pageStack.clear();
        _pageStack.addAll(pageStackData.map((e) => e.toString()));
      }

      // 4. 发送恢复完成事件
      _emitEvent(DataLinkageRestoreEvent());
      notifyListeners();
    } catch (e) {
      // 恢复失败时重置状态
      drillDownService.reset();
      filterService.clearAll();
      _pageStack.clear();
      debugPrint('状态恢复失败: $e');
    }
  }

  // ========== 清理 ==========

  @override
  void dispose() {
    _subscriptions.clear();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _eventController.close();
    drillDownService.dispose();
    breadcrumbManager.dispose();
    super.dispose();
  }
}

/// 数据联动事件基类
abstract class DataLinkageEvent {
  final DateTime timestamp;

  DataLinkageEvent() : timestamp = DateTime.now();
}

/// 开始下钻事件
class DataLinkageStartEvent extends DataLinkageEvent {
  final DrillDownDimension dimension;
  final String title;

  DataLinkageStartEvent({
    required this.dimension,
    required this.title,
  });
}

/// 下钻事件
class DataLinkageDownEvent extends DataLinkageEvent {
  final String id;
  final String title;

  DataLinkageDownEvent({
    required this.id,
    required this.title,
  });
}

/// 返回事件
class DataLinkageBackEvent extends DataLinkageEvent {}

/// 返回到指定层级事件
class DataLinkageBackToEvent extends DataLinkageEvent {
  final int depth;

  DataLinkageBackToEvent({required this.depth});
}

/// 重置事件
class DataLinkageResetEvent extends DataLinkageEvent {}

/// 添加筛选事件
class DataLinkageFilterAddEvent extends DataLinkageEvent {
  final FilterCondition condition;

  DataLinkageFilterAddEvent({required this.condition});
}

/// 移除筛选事件
class DataLinkageFilterRemoveEvent extends DataLinkageEvent {
  final String key;

  DataLinkageFilterRemoveEvent({required this.key});
}

/// 筛选变化事件
class DataLinkageFilterChangedEvent extends DataLinkageEvent {
  final FilterState state;

  DataLinkageFilterChangedEvent({required this.state});
}

/// 清空筛选事件
class DataLinkageClearFiltersEvent extends DataLinkageEvent {}

/// 状态恢复事件
class DataLinkageRestoreEvent extends DataLinkageEvent {}
