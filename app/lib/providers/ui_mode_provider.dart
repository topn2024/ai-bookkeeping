import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI模式枚举
enum UIMode {
  normal,   // 普通模式：完整功能
  simple,   // 简易模式：大字体、简化操作
  auto,     // 自动模式：根据使用习惯切换
}

/// UI模式状态
class UIModeState {
  final UIMode mode;
  final bool isFirstLaunch;
  final int operationCount; // 操作计数，用于智能建议

  const UIModeState({
    this.mode = UIMode.normal,
    this.isFirstLaunch = true,
    this.operationCount = 0,
  });

  UIModeState copyWith({
    UIMode? mode,
    bool? isFirstLaunch,
    int? operationCount,
  }) {
    return UIModeState(
      mode: mode ?? this.mode,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      operationCount: operationCount ?? this.operationCount,
    );
  }

  /// 是否使用简易模式
  bool get isSimpleMode => mode == UIMode.simple;

  /// 是否使用普通模式
  bool get isNormalMode => mode == UIMode.normal;

  /// 是否自动模式
  bool get isAutoMode => mode == UIMode.auto;
}

/// UI模式管理器
class UIModeNotifier extends StateNotifier<UIModeState> {
  static const String _modeKey = 'ui_mode';
  static const String _firstLaunchKey = 'is_first_launch';
  static const String _operationCountKey = 'operation_count';

  UIModeNotifier() : super(const UIModeState()) {
    _loadMode();
  }

  /// 加载保存的模式
  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_modeKey) ?? 0;
    final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;
    final operationCount = prefs.getInt(_operationCountKey) ?? 0;

    state = UIModeState(
      mode: UIMode.values[modeIndex],
      isFirstLaunch: isFirstLaunch,
      operationCount: operationCount,
    );
  }

  /// 切换到简易模式
  Future<void> switchToSimpleMode() async {
    await _saveMode(UIMode.simple);
    state = state.copyWith(mode: UIMode.simple);
  }

  /// 切换到普通模式
  Future<void> switchToNormalMode() async {
    await _saveMode(UIMode.normal);
    state = state.copyWith(mode: UIMode.normal);
  }

  /// 切换到自动模式
  Future<void> switchToAutoMode() async {
    await _saveMode(UIMode.auto);
    state = state.copyWith(mode: UIMode.auto);
  }

  /// 切换模式（在简易和普通之间）
  Future<void> toggleMode() async {
    final newMode = state.isSimpleMode ? UIMode.normal : UIMode.simple;
    await _saveMode(newMode);
    state = state.copyWith(mode: newMode);
  }

  /// 保存模式
  Future<void> _saveMode(UIMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }

  /// 标记首次启动完成
  Future<void> completeFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
    state = state.copyWith(isFirstLaunch: false);
  }

  /// 增加操作计数（用于智能建议）
  Future<void> incrementOperationCount() async {
    final newCount = state.operationCount + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_operationCountKey, newCount);
    state = state.copyWith(operationCount: newCount);

    // 智能建议：如果用户操作困难（频繁取消、错误），建议切换
    if (state.isAutoMode && newCount % 10 == 0) {
      _evaluateModeSuggestion();
    }
  }

  /// 评估是否建议切换模式
  void _evaluateModeSuggestion() {
    // TODO: 基于用户行为模式分析，建议切换模式
    // 例如：频繁的操作取消、长时间停留、错误率高等
  }
}

/// UI模式Provider
final uiModeProvider = StateNotifierProvider<UIModeNotifier, UIModeState>((ref) {
  return UIModeNotifier();
});

/// 便捷访问：是否简易模式
final isSimpleModeProvider = Provider<bool>((ref) {
  return ref.watch(uiModeProvider).isSimpleMode;
});

/// 便捷访问：是否普通模式
final isNormalModeProvider = Provider<bool>((ref) {
  return ref.watch(uiModeProvider).isNormalMode;
});
