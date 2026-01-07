import 'dart:async';
import 'package:flutter/material.dart';
import 'drill_down_navigation_service.dart';

/// 面包屑项
/// 表示面包屑导航中的一个可点击项
class BreadcrumbItem {
  /// 唯一标识符
  final String id;

  /// 显示文本
  final String label;

  /// 图标（可选）
  final IconData? icon;

  /// 下钻深度
  final int depth;

  /// 是否为当前项
  final bool isCurrent;

  /// 是否可点击
  final bool isClickable;

  /// 附加数据
  final Map<String, dynamic>? metadata;

  const BreadcrumbItem({
    required this.id,
    required this.label,
    this.icon,
    required this.depth,
    this.isCurrent = false,
    this.isClickable = true,
    this.metadata,
  });

  /// 创建当前项副本
  BreadcrumbItem copyWith({
    String? id,
    String? label,
    IconData? icon,
    int? depth,
    bool? isCurrent,
    bool? isClickable,
    Map<String, dynamic>? metadata,
  }) {
    return BreadcrumbItem(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      depth: depth ?? this.depth,
      isCurrent: isCurrent ?? this.isCurrent,
      isClickable: isClickable ?? this.isClickable,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'BreadcrumbItem($label, depth=$depth, current=$isCurrent)';
}

/// 面包屑显示样式
enum BreadcrumbStyle {
  /// 完整显示所有层级
  full,

  /// 折叠中间层级（显示首尾+省略号）
  collapsed,

  /// 仅显示当前和上一级
  minimal,

  /// 自适应（根据宽度自动选择）
  adaptive,
}

/// 面包屑分隔符样式
enum BreadcrumbSeparator {
  /// 箭头 >
  arrow,

  /// 斜杠 /
  slash,

  /// 圆点 •
  dot,

  /// 横线 -
  dash,

  /// 自定义图标
  chevron,
}

extension BreadcrumbSeparatorExtension on BreadcrumbSeparator {
  String get text {
    switch (this) {
      case BreadcrumbSeparator.arrow:
        return ' > ';
      case BreadcrumbSeparator.slash:
        return ' / ';
      case BreadcrumbSeparator.dot:
        return ' • ';
      case BreadcrumbSeparator.dash:
        return ' - ';
      case BreadcrumbSeparator.chevron:
        return ''; // 使用图标
    }
  }

  IconData? get icon {
    switch (this) {
      case BreadcrumbSeparator.chevron:
        return Icons.chevron_right;
      default:
        return null;
    }
  }
}

/// 面包屑配置
class BreadcrumbConfig {
  /// 显示样式
  final BreadcrumbStyle style;

  /// 分隔符
  final BreadcrumbSeparator separator;

  /// 最大显示层级数（超过则折叠）
  final int maxVisibleItems;

  /// 是否显示首页图标
  final bool showHomeIcon;

  /// 首页图标
  final IconData homeIcon;

  /// 首页文本
  final String homeLabel;

  /// 是否显示当前项图标
  final bool showCurrentIcon;

  /// 省略号文本
  final String ellipsisText;

  /// 是否启用动画
  final bool enableAnimation;

  /// 动画时长
  final Duration animationDuration;

  const BreadcrumbConfig({
    this.style = BreadcrumbStyle.adaptive,
    this.separator = BreadcrumbSeparator.chevron,
    this.maxVisibleItems = 4,
    this.showHomeIcon = true,
    this.homeIcon = Icons.home,
    this.homeLabel = '首页',
    this.showCurrentIcon = false,
    this.ellipsisText = '...',
    this.enableAnimation = true,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  BreadcrumbConfig copyWith({
    BreadcrumbStyle? style,
    BreadcrumbSeparator? separator,
    int? maxVisibleItems,
    bool? showHomeIcon,
    IconData? homeIcon,
    String? homeLabel,
    bool? showCurrentIcon,
    String? ellipsisText,
    bool? enableAnimation,
    Duration? animationDuration,
  }) {
    return BreadcrumbConfig(
      style: style ?? this.style,
      separator: separator ?? this.separator,
      maxVisibleItems: maxVisibleItems ?? this.maxVisibleItems,
      showHomeIcon: showHomeIcon ?? this.showHomeIcon,
      homeIcon: homeIcon ?? this.homeIcon,
      homeLabel: homeLabel ?? this.homeLabel,
      showCurrentIcon: showCurrentIcon ?? this.showCurrentIcon,
      ellipsisText: ellipsisText ?? this.ellipsisText,
      enableAnimation: enableAnimation ?? this.enableAnimation,
      animationDuration: animationDuration ?? this.animationDuration,
    );
  }
}

/// 面包屑状态
class BreadcrumbState {
  /// 所有面包屑项
  final List<BreadcrumbItem> items;

  /// 可见的面包屑项（根据配置可能被折叠）
  final List<BreadcrumbItem> visibleItems;

  /// 是否有折叠的项
  final bool hasCollapsed;

  /// 折叠的项数量
  final int collapsedCount;

  /// 当前配置
  final BreadcrumbConfig config;

  const BreadcrumbState({
    required this.items,
    required this.visibleItems,
    this.hasCollapsed = false,
    this.collapsedCount = 0,
    required this.config,
  });

  /// 是否为空
  bool get isEmpty => items.isEmpty;

  /// 项目数量
  int get length => items.length;

  /// 当前项
  BreadcrumbItem? get current => items.isNotEmpty ? items.last : null;

  /// 根项
  BreadcrumbItem? get root => items.isNotEmpty ? items.first : null;
}

/// 面包屑状态管理器
///
/// 核心功能：
/// 1. 与 DrillDownNavigationService 联动
/// 2. 管理面包屑显示状态
/// 3. 支持多种显示样式
/// 4. 提供点击回调
/// 5. 支持动画过渡
///
/// 对应设计文档：第12.5.2节 面包屑导航组件
///
/// 使用示例：
/// ```dart
/// final manager = BreadcrumbStateManager(
///   navigationService: drillDownService,
///   config: BreadcrumbConfig(
///     style: BreadcrumbStyle.adaptive,
///     maxVisibleItems: 4,
///   ),
/// );
///
/// // 监听状态变化
/// manager.stateStream.listen((state) {
///   print('面包屑更新: ${state.visibleItems.map((i) => i.label)}');
/// });
///
/// // 处理点击
/// manager.onItemTap(item);
/// ```
class BreadcrumbStateManager {
  /// 下钻导航服务
  final DrillDownNavigationService navigationService;

  /// 面包屑配置
  BreadcrumbConfig _config;

  /// 当前状态
  BreadcrumbState _currentState;

  /// 状态流控制器
  final StreamController<BreadcrumbState> _stateController =
      StreamController<BreadcrumbState>.broadcast();

  /// 点击事件流控制器
  final StreamController<BreadcrumbItem> _tapController =
      StreamController<BreadcrumbItem>.broadcast();

  /// 导航服务订阅
  StreamSubscription<DrillDownPath>? _navigationSubscription;

  /// 可用宽度（用于自适应样式）
  double? _availableWidth;

  /// 每个字符的估算宽度
  static const double _charWidth = 12.0;

  /// 分隔符宽度
  static const double _separatorWidth = 24.0;

  /// 图标宽度
  static const double _iconWidth = 24.0;

  BreadcrumbStateManager({
    required this.navigationService,
    BreadcrumbConfig? config,
  })  : _config = config ?? const BreadcrumbConfig(),
        _currentState = BreadcrumbState(
          items: [],
          visibleItems: [],
          config: config ?? const BreadcrumbConfig(),
        ) {
    _init();
  }

  /// 初始化
  void _init() {
    // 监听导航服务的路径变化
    _navigationSubscription = navigationService.pathChanges.listen(_onPathChanged);

    // 初始化状态
    _updateState(navigationService.currentPath);
  }

  /// 获取当前状态
  BreadcrumbState get currentState => _currentState;

  /// 获取配置
  BreadcrumbConfig get config => _config;

  /// 状态变化流
  Stream<BreadcrumbState> get stateStream => _stateController.stream;

  /// 点击事件流
  Stream<BreadcrumbItem> get tapStream => _tapController.stream;

  /// 更新配置
  void updateConfig(BreadcrumbConfig config) {
    _config = config;
    _updateState(navigationService.currentPath);
  }

  /// 设置可用宽度（用于自适应样式）
  void setAvailableWidth(double width) {
    _availableWidth = width;
    if (_config.style == BreadcrumbStyle.adaptive) {
      _updateState(navigationService.currentPath);
    }
  }

  /// 路径变化处理
  void _onPathChanged(DrillDownPath path) {
    _updateState(path);
  }

  /// 更新状态
  void _updateState(DrillDownPath path) {
    // 转换路径节点为面包屑项
    final items = _convertToItems(path);

    // 根据样式计算可见项
    final visibleItems = _calculateVisibleItems(items);

    // 计算折叠信息
    final hasCollapsed = visibleItems.length < items.length;
    final collapsedCount = items.length - visibleItems.length;

    _currentState = BreadcrumbState(
      items: items,
      visibleItems: visibleItems,
      hasCollapsed: hasCollapsed,
      collapsedCount: collapsedCount,
      config: _config,
    );

    _stateController.add(_currentState);
  }

  /// 转换路径节点为面包屑项
  List<BreadcrumbItem> _convertToItems(DrillDownPath path) {
    if (path.isEmpty) return [];

    final items = <BreadcrumbItem>[];

    for (int i = 0; i < path.nodes.length; i++) {
      final node = path.nodes[i];
      final isLast = i == path.nodes.length - 1;

      items.add(BreadcrumbItem(
        id: node.id,
        label: node.title,
        icon: i == 0 && _config.showHomeIcon
            ? _config.homeIcon
            : (isLast && _config.showCurrentIcon ? node.dimension.icon : null),
        depth: node.depth,
        isCurrent: isLast,
        isClickable: !isLast,
        metadata: node.metadata,
      ));
    }

    return items;
  }

  /// 计算可见项（根据样式）
  List<BreadcrumbItem> _calculateVisibleItems(List<BreadcrumbItem> items) {
    if (items.isEmpty) return [];

    switch (_config.style) {
      case BreadcrumbStyle.full:
        return items;

      case BreadcrumbStyle.collapsed:
        return _collapseItems(items, _config.maxVisibleItems);

      case BreadcrumbStyle.minimal:
        return _minimalItems(items);

      case BreadcrumbStyle.adaptive:
        return _adaptiveItems(items);
    }
  }

  /// 折叠模式：保留首尾，中间折叠
  List<BreadcrumbItem> _collapseItems(List<BreadcrumbItem> items, int maxVisible) {
    if (items.length <= maxVisible) return items;

    final result = <BreadcrumbItem>[];

    // 首项
    result.add(items.first);

    // 省略号项
    result.add(BreadcrumbItem(
      id: '_ellipsis_',
      label: _config.ellipsisText,
      depth: -1,
      isClickable: true, // 点击展开
      metadata: {'collapsed_items': items.sublist(1, items.length - maxVisible + 2)},
    ));

    // 最后几项
    result.addAll(items.sublist(items.length - maxVisible + 2));

    return result;
  }

  /// 最简模式：仅显示上一级和当前
  List<BreadcrumbItem> _minimalItems(List<BreadcrumbItem> items) {
    if (items.length <= 2) return items;

    final result = <BreadcrumbItem>[];

    // 首项（带省略号）
    result.add(items.first.copyWith(
      label: '${items.first.label} ${_config.ellipsisText}',
    ));

    // 上一级
    if (items.length > 2) {
      result.add(items[items.length - 2]);
    }

    // 当前项
    result.add(items.last);

    return result;
  }

  /// 自适应模式：根据宽度动态调整
  List<BreadcrumbItem> _adaptiveItems(List<BreadcrumbItem> items) {
    if (_availableWidth == null || items.isEmpty) {
      return _collapseItems(items, _config.maxVisibleItems);
    }

    // 计算完整显示所需宽度
    double totalWidth = 0;
    for (int i = 0; i < items.length; i++) {
      totalWidth += items[i].label.length * _charWidth;
      if (items[i].icon != null) {
        totalWidth += _iconWidth;
      }
      if (i < items.length - 1) {
        totalWidth += _separatorWidth;
      }
    }

    // 如果能完整显示，返回全部
    if (totalWidth <= _availableWidth!) {
      return items;
    }

    // 否则逐步减少显示项
    for (int maxVisible = items.length - 1; maxVisible >= 2; maxVisible--) {
      final collapsed = _collapseItems(items, maxVisible);
      double collapsedWidth = 0;

      for (int i = 0; i < collapsed.length; i++) {
        collapsedWidth += collapsed[i].label.length * _charWidth;
        if (collapsed[i].icon != null) {
          collapsedWidth += _iconWidth;
        }
        if (i < collapsed.length - 1) {
          collapsedWidth += _separatorWidth;
        }
      }

      if (collapsedWidth <= _availableWidth!) {
        return collapsed;
      }
    }

    // 最后返回最简模式
    return _minimalItems(items);
  }

  /// 处理项点击
  void onItemTap(BreadcrumbItem item) {
    if (!item.isClickable) return;

    // 发送点击事件
    _tapController.add(item);

    // 处理省略号点击
    if (item.id == '_ellipsis_') {
      // TODO: 展开折叠的项
      return;
    }

    // 导航到对应层级
    navigationService.goBackTo(item.depth);
  }

  /// 返回首页
  void goHome() {
    navigationService.goBackTo(0);
  }

  /// 返回上一级
  void goBack() {
    navigationService.goBack();
  }

  /// 释放资源
  void dispose() {
    _navigationSubscription?.cancel();
    _stateController.close();
    _tapController.close();
  }
}

/// 面包屑状态管理器工厂
/// 支持多实例管理
class BreadcrumbStateManagerFactory {
  final DrillDownNavigationServiceFactory _navFactory;
  final Map<String, BreadcrumbStateManager> _instances = {};

  BreadcrumbStateManagerFactory(this._navFactory);

  /// 获取或创建指定key的管理器实例
  BreadcrumbStateManager getInstance(String key, {BreadcrumbConfig? config}) {
    return _instances.putIfAbsent(
      key,
      () => BreadcrumbStateManager(
        navigationService: _navFactory.getInstance(key),
        config: config,
      ),
    );
  }

  /// 移除指定key的管理器实例
  void removeInstance(String key) {
    _instances[key]?.dispose();
    _instances.remove(key);
  }

  /// 清理所有实例
  void clear() {
    for (final manager in _instances.values) {
      manager.dispose();
    }
    _instances.clear();
  }
}
