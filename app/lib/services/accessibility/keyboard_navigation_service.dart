import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 键盘快捷键类型
enum ShortcutType {
  /// 导航
  navigation,

  /// 操作
  action,

  /// 编辑
  edit,

  /// 选择
  selection,

  /// 辅助功能
  accessibility,

  /// 自定义
  custom,
}

/// 键盘快捷键配置
class KeyboardShortcut {
  /// 快捷键标识
  final String id;

  /// 显示名称
  final String label;

  /// 描述
  final String description;

  /// 按键组合
  final LogicalKeySet keySet;

  /// 快捷键类型
  final ShortcutType type;

  /// 是否启用
  final bool enabled;

  /// 执行回调
  final VoidCallback? onActivate;

  const KeyboardShortcut({
    required this.id,
    required this.label,
    required this.description,
    required this.keySet,
    this.type = ShortcutType.custom,
    this.enabled = true,
    this.onActivate,
  });

  KeyboardShortcut copyWith({
    String? id,
    String? label,
    String? description,
    LogicalKeySet? keySet,
    ShortcutType? type,
    bool? enabled,
    VoidCallback? onActivate,
  }) {
    return KeyboardShortcut(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      keySet: keySet ?? this.keySet,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      onActivate: onActivate ?? this.onActivate,
    );
  }

  /// 获取按键显示文本
  String get keyDisplay {
    final keys = <String>[];

    if (keySet.keys.any((k) =>
        k == LogicalKeyboardKey.control ||
        k == LogicalKeyboardKey.controlLeft ||
        k == LogicalKeyboardKey.controlRight)) {
      keys.add('Ctrl');
    }
    if (keySet.keys.any((k) =>
        k == LogicalKeyboardKey.alt ||
        k == LogicalKeyboardKey.altLeft ||
        k == LogicalKeyboardKey.altRight)) {
      keys.add('Alt');
    }
    if (keySet.keys.any((k) =>
        k == LogicalKeyboardKey.shift ||
        k == LogicalKeyboardKey.shiftLeft ||
        k == LogicalKeyboardKey.shiftRight)) {
      keys.add('Shift');
    }
    if (keySet.keys.any((k) =>
        k == LogicalKeyboardKey.meta ||
        k == LogicalKeyboardKey.metaLeft ||
        k == LogicalKeyboardKey.metaRight)) {
      keys.add('⌘');
    }

    // 添加非修饰键
    for (final key in keySet.keys) {
      if (!_isModifierKey(key)) {
        keys.add(_getKeyLabel(key));
      }
    }

    return keys.join('+');
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  String _getKeyLabel(LogicalKeyboardKey key) {
    final keyLabel = key.keyLabel;
    if (keyLabel.isNotEmpty) {
      return keyLabel.toUpperCase();
    }

    // 特殊按键
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.home) return 'Home';
    if (key == LogicalKeyboardKey.end) return 'End';
    if (key == LogicalKeyboardKey.pageUp) return 'Page Up';
    if (key == LogicalKeyboardKey.pageDown) return 'Page Down';

    // F键
    if (key == LogicalKeyboardKey.f1) return 'F1';
    if (key == LogicalKeyboardKey.f2) return 'F2';
    if (key == LogicalKeyboardKey.f3) return 'F3';
    if (key == LogicalKeyboardKey.f4) return 'F4';
    if (key == LogicalKeyboardKey.f5) return 'F5';
    if (key == LogicalKeyboardKey.f6) return 'F6';
    if (key == LogicalKeyboardKey.f7) return 'F7';
    if (key == LogicalKeyboardKey.f8) return 'F8';
    if (key == LogicalKeyboardKey.f9) return 'F9';
    if (key == LogicalKeyboardKey.f10) return 'F10';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.f12) return 'F12';

    return key.debugName ?? 'Unknown';
  }
}

/// 键盘导航服务
/// 提供完整的键盘导航支持，让用户能够仅使用键盘完成所有操作
class KeyboardNavigationService {
  static final KeyboardNavigationService _instance =
      KeyboardNavigationService._internal();
  factory KeyboardNavigationService() => _instance;
  KeyboardNavigationService._internal();

  /// 是否启用键盘导航
  bool _enabled = true;

  /// 快捷键注册表
  final Map<String, KeyboardShortcut> _shortcuts = {};

  /// 快捷键组映射（按类型分组）
  final Map<ShortcutType, List<String>> _shortcutGroups = {};

  /// 按键监听器
  final List<bool Function(KeyEvent)> _keyListeners = [];

  /// 是否显示快捷键提示
  bool showShortcutHints = true;

  /// 是否启用
  bool enabled = true;

  /// 初始化默认快捷键
  void initializeDefaultShortcuts() {
    // 导航快捷键
    registerShortcut(KeyboardShortcut(
      id: 'nav_home',
      label: '返回首页',
      description: '导航到首页',
      keySet: LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyH),
      type: ShortcutType.navigation,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'nav_back',
      label: '返回上一页',
      description: '导航到上一页',
      keySet: LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowLeft),
      type: ShortcutType.navigation,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'nav_search',
      label: '搜索',
      description: '打开搜索',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF),
      type: ShortcutType.navigation,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'nav_skip_to_content',
      label: '跳转到主内容',
      description: '跳过导航，直接到主内容区域',
      keySet: LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit1),
      type: ShortcutType.navigation,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'nav_next_region',
      label: '下一区域',
      description: '跳转到下一个页面区域',
      keySet: LogicalKeySet(LogicalKeyboardKey.f6),
      type: ShortcutType.navigation,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'nav_prev_region',
      label: '上一区域',
      description: '跳转到上一个页面区域',
      keySet: LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.f6),
      type: ShortcutType.navigation,
    ));

    // 操作快捷键
    registerShortcut(KeyboardShortcut(
      id: 'action_new_transaction',
      label: '新建交易',
      description: '快速新建一笔交易记录',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN),
      type: ShortcutType.action,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'action_save',
      label: '保存',
      description: '保存当前内容',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS),
      type: ShortcutType.action,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'action_delete',
      label: '删除',
      description: '删除选中项',
      keySet: LogicalKeySet(LogicalKeyboardKey.delete),
      type: ShortcutType.action,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'action_refresh',
      label: '刷新',
      description: '刷新当前页面',
      keySet: LogicalKeySet(LogicalKeyboardKey.f5),
      type: ShortcutType.action,
    ));

    // 编辑快捷键
    registerShortcut(KeyboardShortcut(
      id: 'edit_undo',
      label: '撤销',
      description: '撤销上一步操作',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ),
      type: ShortcutType.edit,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'edit_redo',
      label: '重做',
      description: '重做上一步撤销的操作',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY),
      type: ShortcutType.edit,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'edit_copy',
      label: '复制',
      description: '复制选中内容',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC),
      type: ShortcutType.edit,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'edit_paste',
      label: '粘贴',
      description: '粘贴剪贴板内容',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV),
      type: ShortcutType.edit,
    ));

    // 选择快捷键
    registerShortcut(KeyboardShortcut(
      id: 'select_all',
      label: '全选',
      description: '选择所有内容',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA),
      type: ShortcutType.selection,
    ));

    // 辅助功能快捷键
    registerShortcut(KeyboardShortcut(
      id: 'a11y_shortcuts_help',
      label: '快捷键帮助',
      description: '显示所有可用的快捷键',
      keySet: LogicalKeySet(LogicalKeyboardKey.f1),
      type: ShortcutType.accessibility,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'a11y_toggle_high_contrast',
      label: '切换高对比度',
      description: '切换高对比度模式',
      keySet: LogicalKeySet(
          LogicalKeyboardKey.alt, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyH),
      type: ShortcutType.accessibility,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'a11y_increase_font',
      label: '增大字体',
      description: '增大字体大小',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.equal),
      type: ShortcutType.accessibility,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'a11y_decrease_font',
      label: '减小字体',
      description: '减小字体大小',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.minus),
      type: ShortcutType.accessibility,
    ));

    registerShortcut(KeyboardShortcut(
      id: 'a11y_reset_font',
      label: '重置字体',
      description: '重置字体大小为默认值',
      keySet: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit0),
      type: ShortcutType.accessibility,
    ));
  }

  // ==================== 快捷键管理 ====================

  /// 注册快捷键
  void registerShortcut(KeyboardShortcut shortcut) {
    _shortcuts[shortcut.id] = shortcut;

    // 添加到分组
    _shortcutGroups.putIfAbsent(shortcut.type, () => []);
    if (!_shortcutGroups[shortcut.type]!.contains(shortcut.id)) {
      _shortcutGroups[shortcut.type]!.add(shortcut.id);
    }
  }

  /// 注销快捷键
  void unregisterShortcut(String id) {
    final shortcut = _shortcuts.remove(id);
    if (shortcut != null) {
      _shortcutGroups[shortcut.type]?.remove(id);
    }
  }

  /// 更新快捷键
  void updateShortcut(String id, KeyboardShortcut shortcut) {
    if (_shortcuts.containsKey(id)) {
      unregisterShortcut(id);
    }
    registerShortcut(shortcut);
  }

  /// 获取快捷键
  KeyboardShortcut? getShortcut(String id) {
    return _shortcuts[id];
  }

  /// 获取所有快捷键
  List<KeyboardShortcut> getAllShortcuts() {
    return _shortcuts.values.toList();
  }

  /// 获取按类型分组的快捷键
  Map<ShortcutType, List<KeyboardShortcut>> getShortcutsByType() {
    final result = <ShortcutType, List<KeyboardShortcut>>{};
    for (final type in ShortcutType.values) {
      final ids = _shortcutGroups[type] ?? [];
      result[type] = ids
          .map((id) => _shortcuts[id])
          .whereType<KeyboardShortcut>()
          .where((s) => s.enabled)
          .toList();
    }
    return result;
  }

  /// 启用/禁用快捷键
  void setShortcutEnabled(String id, bool enabled) {
    final shortcut = _shortcuts[id];
    if (shortcut != null) {
      _shortcuts[id] = shortcut.copyWith(enabled: enabled);
    }
  }

  /// 绑定回调
  void bindCallback(String id, VoidCallback callback) {
    final shortcut = _shortcuts[id];
    if (shortcut != null) {
      _shortcuts[id] = shortcut.copyWith(onActivate: callback);
    }
  }

  // ==================== 按键处理 ====================

  /// 添加按键监听器
  void addKeyListener(bool Function(KeyEvent) listener) {
    _keyListeners.add(listener);
  }

  /// 移除按键监听器
  void removeKeyListener(bool Function(KeyEvent) listener) {
    _keyListeners.remove(listener);
  }

  /// 处理按键事件
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (!_enabled) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // 先让自定义监听器处理
    for (final listener in _keyListeners) {
      if (listener(event)) {
        return KeyEventResult.handled;
      }
    }

    // 检查注册的快捷键
    for (final shortcut in _shortcuts.values) {
      if (!shortcut.enabled) continue;

      if (_matchesKeySet(event, shortcut.keySet)) {
        if (shortcut.onActivate != null) {
          shortcut.onActivate!();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  /// 检查按键是否匹配快捷键组合
  bool _matchesKeySet(KeyEvent event, LogicalKeySet keySet) {
    final keyboard = HardwareKeyboard.instance;

    // 检查修饰键
    final hasControl = keySet.keys.any((k) =>
        k == LogicalKeyboardKey.control ||
        k == LogicalKeyboardKey.controlLeft ||
        k == LogicalKeyboardKey.controlRight);
    final hasAlt = keySet.keys.any((k) =>
        k == LogicalKeyboardKey.alt ||
        k == LogicalKeyboardKey.altLeft ||
        k == LogicalKeyboardKey.altRight);
    final hasShift = keySet.keys.any((k) =>
        k == LogicalKeyboardKey.shift ||
        k == LogicalKeyboardKey.shiftLeft ||
        k == LogicalKeyboardKey.shiftRight);
    final hasMeta = keySet.keys.any((k) =>
        k == LogicalKeyboardKey.meta ||
        k == LogicalKeyboardKey.metaLeft ||
        k == LogicalKeyboardKey.metaRight);

    if (hasControl != keyboard.isControlPressed) return false;
    if (hasAlt != keyboard.isAltPressed) return false;
    if (hasShift != keyboard.isShiftPressed) return false;
    if (hasMeta != keyboard.isMetaPressed) return false;

    // 检查主键
    final mainKeys = keySet.keys.where((k) => !_isModifier(k));
    for (final mainKey in mainKeys) {
      if (event.logicalKey == mainKey) {
        return true;
      }
    }

    return false;
  }

  bool _isModifier(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  // ==================== 导航辅助 ====================

  /// 处理列表项导航
  bool handleListNavigation(
    KeyEvent event, {
    required int currentIndex,
    required int itemCount,
    required void Function(int) onIndexChanged,
    bool wrap = true,
  }) {
    if (event is! KeyDownEvent) return false;

    int newIndex = currentIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.keyJ) {
      newIndex = currentIndex + 1;
      if (newIndex >= itemCount) {
        newIndex = wrap ? 0 : itemCount - 1;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyK) {
      newIndex = currentIndex - 1;
      if (newIndex < 0) {
        newIndex = wrap ? itemCount - 1 : 0;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      newIndex = 0;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      newIndex = itemCount - 1;
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      newIndex = (currentIndex + 10).clamp(0, itemCount - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      newIndex = (currentIndex - 10).clamp(0, itemCount - 1);
    } else {
      return false;
    }

    if (newIndex != currentIndex) {
      onIndexChanged(newIndex);
      return true;
    }

    return false;
  }

  /// 处理网格导航
  bool handleGridNavigation(
    KeyEvent event, {
    required int currentIndex,
    required int columnCount,
    required int itemCount,
    required void Function(int) onIndexChanged,
    bool wrap = false,
  }) {
    if (event is! KeyDownEvent) return false;

    int newIndex = currentIndex;
    final currentRow = currentIndex ~/ columnCount;
    final currentCol = currentIndex % columnCount;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final newCol = currentCol + 1;
      if (newCol < columnCount) {
        newIndex = currentRow * columnCount + newCol;
        if (newIndex >= itemCount) newIndex = currentIndex;
      } else if (wrap) {
        newIndex = currentRow * columnCount;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final newCol = currentCol - 1;
      if (newCol >= 0) {
        newIndex = currentRow * columnCount + newCol;
      } else if (wrap) {
        newIndex = currentRow * columnCount + columnCount - 1;
        if (newIndex >= itemCount) newIndex = itemCount - 1;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      newIndex = currentIndex + columnCount;
      if (newIndex >= itemCount) {
        newIndex = wrap ? currentCol : currentIndex;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      newIndex = currentIndex - columnCount;
      if (newIndex < 0) {
        if (wrap) {
          final lastRowStart =
              (itemCount ~/ columnCount) * columnCount;
          newIndex = lastRowStart + currentCol;
          if (newIndex >= itemCount) newIndex = itemCount - 1;
        } else {
          newIndex = currentIndex;
        }
      }
    } else {
      return false;
    }

    if (newIndex != currentIndex && newIndex >= 0 && newIndex < itemCount) {
      onIndexChanged(newIndex);
      return true;
    }

    return false;
  }

  /// 获取类型显示名称
  String getTypeDisplayName(ShortcutType type) {
    switch (type) {
      case ShortcutType.navigation:
        return '导航';
      case ShortcutType.action:
        return '操作';
      case ShortcutType.edit:
        return '编辑';
      case ShortcutType.selection:
        return '选择';
      case ShortcutType.accessibility:
        return '辅助功能';
      case ShortcutType.custom:
        return '自定义';
    }
  }
}

/// 键盘导航包装组件
class KeyboardNavigationWrapper extends StatefulWidget {
  final Widget child;
  final bool autofocus;

  const KeyboardNavigationWrapper({
    super.key,
    required this.child,
    this.autofocus = false,
  });

  @override
  State<KeyboardNavigationWrapper> createState() =>
      _KeyboardNavigationWrapperState();
}

class _KeyboardNavigationWrapperState extends State<KeyboardNavigationWrapper> {
  final _focusNode = FocusNode();
  final _navService = KeyboardNavigationService();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) => _navService.handleKeyEvent(event),
      child: widget.child,
    );
  }
}
