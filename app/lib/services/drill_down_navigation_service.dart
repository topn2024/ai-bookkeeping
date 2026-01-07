import 'dart:async';
import 'package:flutter/material.dart';

/// 下钻维度类型
/// 对应设计文档12.3.1节定义的下钻维度矩阵
enum DrillDownDimension {
  /// 时间维度: 年→季→月→周→日→时段
  time,

  /// 分类维度: 一级分类→二级分类→交易列表
  category,

  /// 账户维度: 账户类型→具体账户→交易列表
  account,

  /// 标签维度: 标签组→单个标签→交易列表
  tag,

  /// 家庭成员维度: 家庭→成员→分类→交易
  familyMember,

  /// 位置维度: 全国→城市→区域→商家→交易
  location,

  /// 习惯维度: 习惯类型→打卡记录→关联交易
  habit,

  /// 钱龄维度: 健康等级→资源池→交易列表
  moneyAge,

  /// 预算维度: 预算类型→具体预算→交易列表
  budget,
}

extension DrillDownDimensionExtension on DrillDownDimension {
  String get displayName {
    switch (this) {
      case DrillDownDimension.time:
        return '时间';
      case DrillDownDimension.category:
        return '分类';
      case DrillDownDimension.account:
        return '账户';
      case DrillDownDimension.tag:
        return '标签';
      case DrillDownDimension.familyMember:
        return '家庭成员';
      case DrillDownDimension.location:
        return '位置';
      case DrillDownDimension.habit:
        return '习惯';
      case DrillDownDimension.moneyAge:
        return '钱龄';
      case DrillDownDimension.budget:
        return '预算';
    }
  }

  IconData get icon {
    switch (this) {
      case DrillDownDimension.time:
        return Icons.schedule;
      case DrillDownDimension.category:
        return Icons.category;
      case DrillDownDimension.account:
        return Icons.account_balance_wallet;
      case DrillDownDimension.tag:
        return Icons.label;
      case DrillDownDimension.familyMember:
        return Icons.family_restroom;
      case DrillDownDimension.location:
        return Icons.location_on;
      case DrillDownDimension.habit:
        return Icons.repeat;
      case DrillDownDimension.moneyAge:
        return Icons.hourglass_empty;
      case DrillDownDimension.budget:
        return Icons.pie_chart;
    }
  }

  /// 该维度的最大下钻层级
  int get maxDepth {
    switch (this) {
      case DrillDownDimension.time:
        return 6; // 年→季→月→周→日→时段
      case DrillDownDimension.category:
        return 3; // 一级→二级→交易
      case DrillDownDimension.account:
        return 3; // 类型→账户→交易
      case DrillDownDimension.tag:
        return 3; // 组→标签→交易
      case DrillDownDimension.familyMember:
        return 4; // 家庭→成员→分类→交易
      case DrillDownDimension.location:
        return 5; // 全国→城市→区域→商家→交易
      case DrillDownDimension.habit:
        return 3; // 类型→记录→交易
      case DrillDownDimension.moneyAge:
        return 3; // 等级→资源池→交易
      case DrillDownDimension.budget:
        return 3; // 类型→预算→交易
    }
  }
}

/// 下钻层级节点
/// 表示下钻路径中的一个层级
class DrillDownNode {
  /// 唯一标识符
  final String id;

  /// 显示名称
  final String title;

  /// 下钻维度
  final DrillDownDimension dimension;

  /// 当前层级深度（从0开始）
  final int depth;

  /// 筛选条件值
  final dynamic filterValue;

  /// 附加数据（如金额、数量等）
  final Map<String, dynamic>? metadata;

  /// 创建时间戳
  final DateTime timestamp;

  DrillDownNode({
    required this.id,
    required this.title,
    required this.dimension,
    required this.depth,
    this.filterValue,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 创建根节点
  factory DrillDownNode.root({
    required String title,
    required DrillDownDimension dimension,
  }) {
    return DrillDownNode(
      id: 'root_${dimension.name}',
      title: title,
      dimension: dimension,
      depth: 0,
    );
  }

  /// 创建子节点
  DrillDownNode createChild({
    required String id,
    required String title,
    dynamic filterValue,
    Map<String, dynamic>? metadata,
  }) {
    return DrillDownNode(
      id: id,
      title: title,
      dimension: dimension,
      depth: depth + 1,
      filterValue: filterValue,
      metadata: metadata,
    );
  }

  /// 是否为叶子节点（最深层级）
  bool get isLeaf => depth >= dimension.maxDepth - 1;

  /// 是否为根节点
  bool get isRoot => depth == 0;

  @override
  String toString() => 'DrillDownNode($title, depth=$depth)';
}

/// 下钻路径
/// 表示从根节点到当前节点的完整路径
class DrillDownPath {
  final List<DrillDownNode> _nodes;

  DrillDownPath([List<DrillDownNode>? nodes]) : _nodes = nodes ?? [];

  /// 路径中的所有节点
  List<DrillDownNode> get nodes => List.unmodifiable(_nodes);

  /// 当前节点（路径末尾）
  DrillDownNode? get current => _nodes.isNotEmpty ? _nodes.last : null;

  /// 路径深度
  int get depth => _nodes.length;

  /// 是否为空路径
  bool get isEmpty => _nodes.isEmpty;

  /// 是否可以继续下钻
  bool get canDrillDown => current != null && !current!.isLeaf;

  /// 是否可以返回上级
  bool get canGoBack => _nodes.length > 1;

  /// 获取面包屑显示文本
  List<String> get breadcrumbs => _nodes.map((n) => n.title).toList();

  /// 添加节点到路径
  DrillDownPath push(DrillDownNode node) {
    return DrillDownPath([..._nodes, node]);
  }

  /// 移除最后一个节点
  DrillDownPath pop() {
    if (_nodes.isEmpty) return this;
    return DrillDownPath(_nodes.sublist(0, _nodes.length - 1));
  }

  /// 返回到指定层级
  DrillDownPath popTo(int depth) {
    if (depth < 0 || depth >= _nodes.length) return this;
    return DrillDownPath(_nodes.sublist(0, depth + 1));
  }

  /// 返回到指定节点
  DrillDownPath popToNode(String nodeId) {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return this;
    return DrillDownPath(_nodes.sublist(0, index + 1));
  }

  /// 清空路径
  DrillDownPath clear() => DrillDownPath([]);

  /// 获取当前的筛选条件链
  Map<String, dynamic> get filterChain {
    final filters = <String, dynamic>{};
    for (final node in _nodes) {
      if (node.filterValue != null) {
        filters['${node.dimension.name}_${node.depth}'] = node.filterValue;
      }
    }
    return filters;
  }
}

/// 下钻导航事件
abstract class DrillDownEvent {
  final DrillDownPath path;
  final DateTime timestamp;

  DrillDownEvent(this.path) : timestamp = DateTime.now();
}

/// 下钻进入事件
class DrillDownEnterEvent extends DrillDownEvent {
  final DrillDownNode node;
  DrillDownEnterEvent(DrillDownPath path, this.node) : super(path);
}

/// 下钻返回事件
class DrillDownBackEvent extends DrillDownEvent {
  final DrillDownNode? fromNode;
  final DrillDownNode? toNode;
  DrillDownBackEvent(DrillDownPath path, this.fromNode, this.toNode) : super(path);
}

/// 下钻重置事件
class DrillDownResetEvent extends DrillDownEvent {
  DrillDownResetEvent(DrillDownPath path) : super(path);
}

/// 数据下钻导航服务
///
/// 核心功能：
/// 1. 管理下钻路径栈
/// 2. 支持多维度下钻（时间、分类、账户等）
/// 3. 提供面包屑导航数据
/// 4. 筛选条件自动继承
/// 5. 下钻事件流
///
/// 对应设计文档：第12章 数据联动与可视化
///
/// 使用示例：
/// ```dart
/// final service = DrillDownNavigationService();
///
/// // 开始时间维度下钻
/// service.startDrillDown(
///   dimension: DrillDownDimension.time,
///   title: '2024年',
/// );
///
/// // 继续下钻到月份
/// service.drillDown(
///   id: 'month_1',
///   title: '1月',
///   filterValue: {'year': 2024, 'month': 1},
/// );
///
/// // 返回上一级
/// service.goBack();
///
/// // 返回到指定层级
/// service.goBackTo(0);
/// ```
class DrillDownNavigationService {
  /// 当前下钻路径
  DrillDownPath _currentPath = DrillDownPath();

  /// 下钻事件流控制器
  final StreamController<DrillDownEvent> _eventController =
      StreamController<DrillDownEvent>.broadcast();

  /// 路径变化流控制器
  final StreamController<DrillDownPath> _pathController =
      StreamController<DrillDownPath>.broadcast();

  /// 下钻历史记录（支持前进/后退）
  final List<DrillDownPath> _history = [];
  int _historyIndex = -1;

  /// 最大历史记录数
  static const int maxHistorySize = 50;

  DrillDownNavigationService();

  /// 获取当前下钻路径
  DrillDownPath get currentPath => _currentPath;

  /// 获取当前节点
  DrillDownNode? get currentNode => _currentPath.current;

  /// 获取面包屑列表
  List<String> get breadcrumbs => _currentPath.breadcrumbs;

  /// 获取当前筛选条件
  Map<String, dynamic> get currentFilters => _currentPath.filterChain;

  /// 下钻事件流
  Stream<DrillDownEvent> get events => _eventController.stream;

  /// 路径变化流
  Stream<DrillDownPath> get pathChanges => _pathController.stream;

  /// 是否可以返回
  bool get canGoBack => _currentPath.canGoBack;

  /// 是否可以继续下钻
  bool get canDrillDown => _currentPath.canDrillDown;

  /// 是否可以前进（历史中有后续记录）
  bool get canGoForward => _historyIndex < _history.length - 1;

  /// 是否可以后退（历史中有前序记录）
  bool get canGoBackward => _historyIndex > 0;

  /// 开始新的下钻（从根节点开始）
  void startDrillDown({
    required DrillDownDimension dimension,
    required String title,
    Map<String, dynamic>? metadata,
  }) {
    final rootNode = DrillDownNode.root(
      title: title,
      dimension: dimension,
    );

    _currentPath = DrillDownPath([rootNode]);
    _addToHistory(_currentPath);
    _emitEvent(DrillDownEnterEvent(_currentPath, rootNode));
  }

  /// 下钻到下一层级
  void drillDown({
    required String id,
    required String title,
    dynamic filterValue,
    Map<String, dynamic>? metadata,
  }) {
    final current = _currentPath.current;
    if (current == null) {
      throw StateError('Cannot drill down without starting a drill down first');
    }

    if (current.isLeaf) {
      throw StateError('Cannot drill down from a leaf node');
    }

    final childNode = current.createChild(
      id: id,
      title: title,
      filterValue: filterValue,
      metadata: metadata,
    );

    _currentPath = _currentPath.push(childNode);
    _addToHistory(_currentPath);
    _emitEvent(DrillDownEnterEvent(_currentPath, childNode));
  }

  /// 返回上一层级
  bool goBack() {
    if (!_currentPath.canGoBack) return false;

    final fromNode = _currentPath.current;
    _currentPath = _currentPath.pop();
    final toNode = _currentPath.current;

    _addToHistory(_currentPath);
    _emitEvent(DrillDownBackEvent(_currentPath, fromNode, toNode));
    return true;
  }

  /// 返回到指定层级
  bool goBackTo(int depth) {
    if (depth < 0 || depth >= _currentPath.depth) return false;

    final fromNode = _currentPath.current;
    _currentPath = _currentPath.popTo(depth);
    final toNode = _currentPath.current;

    _addToHistory(_currentPath);
    _emitEvent(DrillDownBackEvent(_currentPath, fromNode, toNode));
    return true;
  }

  /// 返回到指定节点
  bool goBackToNode(String nodeId) {
    final newPath = _currentPath.popToNode(nodeId);
    if (newPath.depth == _currentPath.depth) return false;

    final fromNode = _currentPath.current;
    _currentPath = newPath;
    final toNode = _currentPath.current;

    _addToHistory(_currentPath);
    _emitEvent(DrillDownBackEvent(_currentPath, fromNode, toNode));
    return true;
  }

  /// 重置下钻（清空路径）
  void reset() {
    _currentPath = DrillDownPath();
    _addToHistory(_currentPath);
    _emitEvent(DrillDownResetEvent(_currentPath));
  }

  /// 历史前进
  bool forward() {
    if (!canGoForward) return false;

    _historyIndex++;
    _currentPath = _history[_historyIndex];
    _pathController.add(_currentPath);
    return true;
  }

  /// 历史后退
  bool backward() {
    if (!canGoBackward) return false;

    _historyIndex--;
    _currentPath = _history[_historyIndex];
    _pathController.add(_currentPath);
    return true;
  }

  /// 获取指定层级的节点
  DrillDownNode? getNodeAt(int depth) {
    if (depth < 0 || depth >= _currentPath.depth) return null;
    return _currentPath.nodes[depth];
  }

  /// 添加到历史记录
  void _addToHistory(DrillDownPath path) {
    // 如果当前不在历史末尾，截断后续历史
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(path);
    _historyIndex = _history.length - 1;

    // 限制历史记录大小
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  /// 发送事件
  void _emitEvent(DrillDownEvent event) {
    _eventController.add(event);
    _pathController.add(_currentPath);
  }

  /// 清理历史记录
  void clearHistory() {
    _history.clear();
    _historyIndex = -1;
  }

  /// 释放资源
  void dispose() {
    _eventController.close();
    _pathController.close();
    _history.clear();
  }
}

/// 下钻导航服务工厂
/// 支持多实例管理（如不同页面独立的下钻状态）
class DrillDownNavigationServiceFactory {
  final Map<String, DrillDownNavigationService> _instances = {};

  /// 获取或创建指定key的服务实例
  DrillDownNavigationService getInstance(String key) {
    return _instances.putIfAbsent(key, () => DrillDownNavigationService());
  }

  /// 移除指定key的服务实例
  void removeInstance(String key) {
    _instances[key]?.dispose();
    _instances.remove(key);
  }

  /// 清理所有实例
  void clear() {
    for (final service in _instances.values) {
      service.dispose();
    }
    _instances.clear();
  }

  /// 获取所有实例的key
  List<String> get keys => _instances.keys.toList();
}
