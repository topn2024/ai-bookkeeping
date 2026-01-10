import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// 焦点区域类型
enum FocusRegion {
  /// 导航栏
  navigation,

  /// 内容区域
  content,

  /// 操作区域
  actions,

  /// 表单区域
  form,

  /// 对话框
  dialog,

  /// 底部导航
  bottomNav,

  /// 悬浮按钮
  fab,

  /// 侧边栏
  sidebar,

  /// 搜索区域
  search,

  /// 筛选区域
  filter,
}

/// 焦点陷阱配置
class FocusTrapConfig {
  /// 是否启用焦点陷阱
  final bool enabled;

  /// 首个焦点节点
  final FocusNode? firstFocus;

  /// 末尾焦点节点
  final FocusNode? lastFocus;

  /// 是否自动聚焦首个元素
  final bool autoFocusFirst;

  /// 退出时恢复的焦点
  final FocusNode? restoreFocus;

  const FocusTrapConfig({
    this.enabled = true,
    this.firstFocus,
    this.lastFocus,
    this.autoFocusFirst = true,
    this.restoreFocus,
  });
}

/// 焦点历史记录
class FocusHistoryEntry {
  /// 焦点节点
  final FocusNode node;

  /// 区域类型
  final FocusRegion region;

  /// 时间戳
  final DateTime timestamp;

  /// 上下文标识
  final String? contextId;

  FocusHistoryEntry({
    required this.node,
    required this.region,
    DateTime? timestamp,
    this.contextId,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 焦点管理服务
/// 提供完善的焦点导航支持，确保键盘和屏幕阅读器用户能够顺畅操作
class FocusManagementService {
  static final FocusManagementService _instance =
      FocusManagementService._internal();
  factory FocusManagementService() => _instance;
  FocusManagementService._internal();

  /// 当前活动的焦点区域
  FocusRegion _currentRegion = FocusRegion.content;

  /// 区域焦点节点映射
  final Map<FocusRegion, List<FocusNode>> _regionNodes = {};

  /// 焦点历史栈
  final List<FocusHistoryEntry> _focusHistory = [];

  /// 最大历史记录数
  static const int _maxHistorySize = 50;

  /// 焦点陷阱栈
  final List<FocusTrapConfig> _focusTrapStack = [];

  /// 跳过链接焦点节点
  FocusNode? _skipLinkNode;

  /// 当前区域变更回调
  final List<void Function(FocusRegion)> _regionChangeListeners = [];

  // ==================== 区域管理 ====================

  /// 获取当前焦点区域
  FocusRegion get currentRegion => _currentRegion;

  /// 注册焦点节点到区域
  void registerNode(FocusNode node, FocusRegion region) {
    _regionNodes.putIfAbsent(region, () => []);
    if (!_regionNodes[region]!.contains(node)) {
      _regionNodes[region]!.add(node);
    }

    // 监听节点销毁
    node.addListener(() {
      if (!node.hasFocus && !node.canRequestFocus) {
        unregisterNode(node, region);
      }
    });
  }

  /// 注销焦点节点
  void unregisterNode(FocusNode node, FocusRegion region) {
    _regionNodes[region]?.remove(node);
  }

  /// 设置当前区域
  void setCurrentRegion(FocusRegion region) {
    if (_currentRegion != region) {
      _currentRegion = region;
      for (final listener in _regionChangeListeners) {
        listener(region);
      }
    }
  }

  /// 添加区域变更监听
  void addRegionChangeListener(void Function(FocusRegion) listener) {
    _regionChangeListeners.add(listener);
  }

  /// 移除区域变更监听
  void removeRegionChangeListener(void Function(FocusRegion) listener) {
    _regionChangeListeners.remove(listener);
  }

  /// 获取区域内的焦点节点
  List<FocusNode> getNodesInRegion(FocusRegion region) {
    return List.unmodifiable(_regionNodes[region] ?? []);
  }

  /// 清空区域节点
  void clearRegion(FocusRegion region) {
    _regionNodes[region]?.clear();
  }

  // ==================== 焦点导航 ====================

  /// 移动焦点到区域首个元素
  bool focusFirstInRegion(FocusRegion region) {
    final nodes = _regionNodes[region];
    if (nodes != null && nodes.isNotEmpty) {
      final firstNode = nodes.firstWhere(
        (n) => n.canRequestFocus,
        orElse: () => nodes.first,
      );
      if (firstNode.canRequestFocus) {
        _recordFocusChange(firstNode, region);
        firstNode.requestFocus();
        setCurrentRegion(region);
        return true;
      }
    }
    return false;
  }

  /// 移动焦点到区域末尾元素
  bool focusLastInRegion(FocusRegion region) {
    final nodes = _regionNodes[region];
    if (nodes != null && nodes.isNotEmpty) {
      final lastNode = nodes.lastWhere(
        (n) => n.canRequestFocus,
        orElse: () => nodes.last,
      );
      if (lastNode.canRequestFocus) {
        _recordFocusChange(lastNode, region);
        lastNode.requestFocus();
        setCurrentRegion(region);
        return true;
      }
    }
    return false;
  }

  /// 移动焦点到下一个区域
  bool focusNextRegion() {
    final regions = FocusRegion.values;
    final currentIndex = regions.indexOf(_currentRegion);
    for (int i = 1; i < regions.length; i++) {
      final nextIndex = (currentIndex + i) % regions.length;
      if (focusFirstInRegion(regions[nextIndex])) {
        return true;
      }
    }
    return false;
  }

  /// 移动焦点到上一个区域
  bool focusPreviousRegion() {
    final regions = FocusRegion.values;
    final currentIndex = regions.indexOf(_currentRegion);
    for (int i = 1; i < regions.length; i++) {
      final prevIndex = (currentIndex - i + regions.length) % regions.length;
      if (focusFirstInRegion(regions[prevIndex])) {
        return true;
      }
    }
    return false;
  }

  /// 移动焦点到下一个元素
  bool focusNext() {
    final currentNode = FocusManager.instance.primaryFocus;
    if (currentNode == null) {
      return focusFirstInRegion(_currentRegion);
    }

    final nodes = _regionNodes[_currentRegion];
    if (nodes == null || nodes.isEmpty) {
      return focusNextRegion();
    }

    final currentIndex = nodes.indexOf(currentNode);
    if (currentIndex == -1) {
      return focusFirstInRegion(_currentRegion);
    }

    // 在当前区域内找下一个
    for (int i = currentIndex + 1; i < nodes.length; i++) {
      if (nodes[i].canRequestFocus) {
        _recordFocusChange(nodes[i], _currentRegion);
        nodes[i].requestFocus();
        return true;
      }
    }

    // 区域内没有下一个，移动到下一区域
    return focusNextRegion();
  }

  /// 移动焦点到上一个元素
  bool focusPrevious() {
    final currentNode = FocusManager.instance.primaryFocus;
    if (currentNode == null) {
      return focusLastInRegion(_currentRegion);
    }

    final nodes = _regionNodes[_currentRegion];
    if (nodes == null || nodes.isEmpty) {
      return focusPreviousRegion();
    }

    final currentIndex = nodes.indexOf(currentNode);
    if (currentIndex == -1) {
      return focusLastInRegion(_currentRegion);
    }

    // 在当前区域内找上一个
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (nodes[i].canRequestFocus) {
        _recordFocusChange(nodes[i], _currentRegion);
        nodes[i].requestFocus();
        return true;
      }
    }

    // 区域内没有上一个，移动到上一区域
    return focusPreviousRegion();
  }

  // ==================== 焦点历史 ====================

  /// 记录焦点变更
  void _recordFocusChange(FocusNode node, FocusRegion region, {String? contextId}) {
    if (_focusHistory.length >= _maxHistorySize) {
      _focusHistory.removeAt(0);
    }
    _focusHistory.add(FocusHistoryEntry(
      node: node,
      region: region,
      contextId: contextId,
    ));
  }

  /// 保存当前焦点状态
  void saveFocusState({String? contextId}) {
    final currentNode = FocusManager.instance.primaryFocus;
    if (currentNode != null) {
      _recordFocusChange(currentNode, _currentRegion, contextId: contextId);
    }
  }

  /// 恢复焦点状态
  bool restoreFocusState({String? contextId}) {
    FocusHistoryEntry? entry;

    if (contextId != null) {
      // 查找特定上下文的焦点
      entry = _focusHistory.reversed.firstWhere(
        (e) => e.contextId == contextId,
        orElse: () => _focusHistory.last,
      );
    } else if (_focusHistory.isNotEmpty) {
      entry = _focusHistory.last;
    }

    if (entry != null && entry.node.canRequestFocus) {
      entry.node.requestFocus();
      setCurrentRegion(entry.region);
      return true;
    }
    return false;
  }

  /// 返回上一个焦点
  bool focusBack() {
    if (_focusHistory.length < 2) {
      return false;
    }

    // 移除当前焦点记录
    _focusHistory.removeLast();

    // 获取上一个焦点
    final previousEntry = _focusHistory.last;
    if (previousEntry.node.canRequestFocus) {
      previousEntry.node.requestFocus();
      setCurrentRegion(previousEntry.region);
      return true;
    }

    return focusBack(); // 递归查找可用的上一个焦点
  }

  /// 清空焦点历史
  void clearHistory() {
    _focusHistory.clear();
  }

  // ==================== 焦点陷阱 ====================

  /// 进入焦点陷阱
  void enterFocusTrap(FocusTrapConfig config) {
    // 保存当前焦点以便退出时恢复
    saveFocusState(contextId: 'focus_trap_${_focusTrapStack.length}');
    _focusTrapStack.add(config);

    if (config.autoFocusFirst && config.firstFocus != null) {
      config.firstFocus!.requestFocus();
    }
  }

  /// 退出焦点陷阱
  void exitFocusTrap() {
    if (_focusTrapStack.isEmpty) return;

    final config = _focusTrapStack.removeLast();

    // 恢复之前的焦点
    if (config.restoreFocus != null && config.restoreFocus!.canRequestFocus) {
      config.restoreFocus!.requestFocus();
    } else {
      restoreFocusState(contextId: 'focus_trap_${_focusTrapStack.length}');
    }
  }

  /// 是否在焦点陷阱中
  bool get isInFocusTrap => _focusTrapStack.isNotEmpty;

  /// 处理焦点陷阱内的Tab导航
  bool handleFocusTrapNavigation(bool forward) {
    if (_focusTrapStack.isEmpty) return false;

    final config = _focusTrapStack.last;
    if (!config.enabled) return false;

    final currentNode = FocusManager.instance.primaryFocus;

    if (forward) {
      // Tab: 从末尾跳到开头
      if (currentNode == config.lastFocus && config.firstFocus != null) {
        config.firstFocus!.requestFocus();
        return true;
      }
    } else {
      // Shift+Tab: 从开头跳到末尾
      if (currentNode == config.firstFocus && config.lastFocus != null) {
        config.lastFocus!.requestFocus();
        return true;
      }
    }

    return false;
  }

  // ==================== 跳过链接 ====================

  /// 设置跳过链接节点
  void setSkipLinkNode(FocusNode node) {
    _skipLinkNode = node;
  }

  /// 激活跳过链接（跳转到主内容）
  bool activateSkipLink() {
    return focusFirstInRegion(FocusRegion.content);
  }

  /// 聚焦到跳过链接
  bool focusSkipLink() {
    if (_skipLinkNode != null && _skipLinkNode!.canRequestFocus) {
      _skipLinkNode!.requestFocus();
      return true;
    }
    return false;
  }

  // ==================== 键盘快捷键支持 ====================

  /// 处理键盘导航事件
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // F6: 在区域间导航
    if (event.logicalKey == LogicalKeyboardKey.f6) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return focusPreviousRegion()
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      }
      return focusNextRegion()
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    // Escape: 退出焦点陷阱或返回上一个焦点
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (isInFocusTrap) {
        exitFocusTrap();
        return KeyEventResult.handled;
      }
      return focusBack() ? KeyEventResult.handled : KeyEventResult.ignored;
    }

    // Tab: 处理焦点陷阱内的导航
    if (event.logicalKey == LogicalKeyboardKey.tab && isInFocusTrap) {
      final forward = !HardwareKeyboard.instance.isShiftPressed;
      if (handleFocusTrapNavigation(forward)) {
        return KeyEventResult.handled;
      }
    }

    // Alt+1~9: 快速跳转到指定区域
    if (HardwareKeyboard.instance.isAltPressed) {
      final key = event.logicalKey;
      FocusRegion? targetRegion;

      if (key == LogicalKeyboardKey.digit1) {
        targetRegion = FocusRegion.navigation;
      } else if (key == LogicalKeyboardKey.digit2) {
        targetRegion = FocusRegion.content;
      } else if (key == LogicalKeyboardKey.digit3) {
        targetRegion = FocusRegion.actions;
      } else if (key == LogicalKeyboardKey.digit4) {
        targetRegion = FocusRegion.form;
      } else if (key == LogicalKeyboardKey.digit5) {
        targetRegion = FocusRegion.bottomNav;
      } else if (key == LogicalKeyboardKey.digit6) {
        targetRegion = FocusRegion.sidebar;
      } else if (key == LogicalKeyboardKey.digit7) {
        targetRegion = FocusRegion.search;
      } else if (key == LogicalKeyboardKey.digit8) {
        targetRegion = FocusRegion.filter;
      } else if (key == LogicalKeyboardKey.digit0) {
        targetRegion = FocusRegion.fab;
      }

      if (targetRegion != null) {
        return focusFirstInRegion(targetRegion)
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      }
    }

    return KeyEventResult.ignored;
  }

  // ==================== 焦点指示器 ====================

  /// 获取焦点指示器装饰
  BoxDecoration getFocusIndicatorDecoration({
    Color? color,
    double width = 2.0,
    double offset = 2.0,
  }) {
    return BoxDecoration(
      border: Border.all(
        color: color ?? Colors.blue,
        width: width,
      ),
      borderRadius: BorderRadius.circular(4),
    );
  }

  /// 播报焦点变化（用于屏幕阅读器）
  void announceFocusChange(String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  // ==================== 清理 ====================

  /// 清理所有资源
  void dispose() {
    _regionNodes.clear();
    _focusHistory.clear();
    _focusTrapStack.clear();
    _regionChangeListeners.clear();
    _skipLinkNode = null;
  }
}

/// 焦点区域包装组件
class FocusRegionWrapper extends StatefulWidget {
  final FocusRegion region;
  final Widget child;
  final String? label;

  const FocusRegionWrapper({
    super.key,
    required this.region,
    required this.child,
    this.label,
  });

  @override
  State<FocusRegionWrapper> createState() => _FocusRegionWrapperState();
}

class _FocusRegionWrapperState extends State<FocusRegionWrapper> {
  final _focusService = FocusManagementService();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.label ?? _getRegionLabel(widget.region),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            _focusService.setCurrentRegion(widget.region);
          }
        },
        child: widget.child,
      ),
    );
  }

  String _getRegionLabel(FocusRegion region) {
    switch (region) {
      case FocusRegion.navigation:
        return '导航区域';
      case FocusRegion.content:
        return '主内容区域';
      case FocusRegion.actions:
        return '操作区域';
      case FocusRegion.form:
        return '表单区域';
      case FocusRegion.dialog:
        return '对话框区域';
      case FocusRegion.bottomNav:
        return '底部导航区域';
      case FocusRegion.fab:
        return '快捷操作按钮';
      case FocusRegion.sidebar:
        return '侧边栏区域';
      case FocusRegion.search:
        return '搜索区域';
      case FocusRegion.filter:
        return '筛选区域';
    }
  }
}

/// 焦点陷阱包装组件
class FocusTrapWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final bool autoFocus;
  final FocusNode? firstFocusNode;
  final FocusNode? lastFocusNode;

  const FocusTrapWrapper({
    super.key,
    required this.child,
    this.enabled = true,
    this.autoFocus = true,
    this.firstFocusNode,
    this.lastFocusNode,
  });

  @override
  State<FocusTrapWrapper> createState() => _FocusTrapWrapperState();
}

class _FocusTrapWrapperState extends State<FocusTrapWrapper> {
  final _focusService = FocusManagementService();
  late FocusNode _restoreFocusNode;

  @override
  void initState() {
    super.initState();
    _restoreFocusNode = FocusManager.instance.primaryFocus ?? FocusNode();

    if (widget.enabled) {
      _focusService.enterFocusTrap(FocusTrapConfig(
        enabled: widget.enabled,
        firstFocus: widget.firstFocusNode,
        lastFocus: widget.lastFocusNode,
        autoFocusFirst: widget.autoFocus,
        restoreFocus: _restoreFocusNode,
      ));
    }
  }

  @override
  void dispose() {
    if (widget.enabled) {
      _focusService.exitFocusTrap();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
