import 'dart:math';
import 'package:flutter/material.dart';

/// 高对比度模式类型
enum HighContrastMode {
  /// 关闭
  off,

  /// 自动（跟随系统设置）
  auto,

  /// 高对比度亮色
  light,

  /// 高对比度暗色
  dark,

  /// 黄色背景黑色文字（适合弱视用户）
  yellowOnBlack,

  /// 反转色彩
  inverted,
}

/// 高对比度主题配置
class HighContrastThemeConfig {
  /// 前景色（文字）
  final Color foregroundColor;

  /// 背景色
  final Color backgroundColor;

  /// 主要强调色
  final Color primaryColor;

  /// 次要强调色
  final Color secondaryColor;

  /// 错误色
  final Color errorColor;

  /// 成功色
  final Color successColor;

  /// 警告色
  final Color warningColor;

  /// 边框色
  final Color borderColor;

  /// 禁用色
  final Color disabledColor;

  /// 链接色
  final Color linkColor;

  /// 选中色
  final Color selectedColor;

  /// 聚焦指示器色
  final Color focusColor;

  const HighContrastThemeConfig({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.errorColor,
    required this.successColor,
    required this.warningColor,
    required this.borderColor,
    required this.disabledColor,
    required this.linkColor,
    required this.selectedColor,
    required this.focusColor,
  });

  /// 高对比度亮色主题
  static const light = HighContrastThemeConfig(
    foregroundColor: Colors.black,
    backgroundColor: Colors.white,
    primaryColor: Color(0xFF0000EE), // 深蓝色
    secondaryColor: Color(0xFF551A8B), // 深紫色
    errorColor: Color(0xFFCC0000), // 深红色
    successColor: Color(0xFF006600), // 深绿色
    warningColor: Color(0xFFCC6600), // 深橙色
    borderColor: Colors.black,
    disabledColor: Color(0xFF666666),
    linkColor: Color(0xFF0000EE),
    selectedColor: Color(0xFFCCCCFF),
    focusColor: Color(0xFF0066FF),
  );

  /// 高对比度暗色主题
  static const dark = HighContrastThemeConfig(
    foregroundColor: Colors.white,
    backgroundColor: Colors.black,
    primaryColor: Color(0xFF00CCFF), // 青色
    secondaryColor: Color(0xFFFF99FF), // 粉紫色
    errorColor: Color(0xFFFF6666), // 浅红色
    successColor: Color(0xFF66FF66), // 浅绿色
    warningColor: Color(0xFFFFCC00), // 黄色
    borderColor: Colors.white,
    disabledColor: Color(0xFF999999),
    linkColor: Color(0xFF00CCFF),
    selectedColor: Color(0xFF333366),
    focusColor: Color(0xFFFFFF00),
  );

  /// 黄色背景黑色文字主题（适合弱视用户）
  static const yellowOnBlack = HighContrastThemeConfig(
    foregroundColor: Color(0xFFFFFF00), // 黄色文字
    backgroundColor: Colors.black,
    primaryColor: Color(0xFFFFFF00),
    secondaryColor: Color(0xFFFFCC00),
    errorColor: Color(0xFFFF6666),
    successColor: Color(0xFF66FF66),
    warningColor: Color(0xFFFFCC00),
    borderColor: Color(0xFFFFFF00),
    disabledColor: Color(0xFF999900),
    linkColor: Color(0xFF00FFFF),
    selectedColor: Color(0xFF333300),
    focusColor: Color(0xFF00FFFF),
  );

  /// 反转色彩主题
  static const inverted = HighContrastThemeConfig(
    foregroundColor: Colors.white,
    backgroundColor: Color(0xFF121212),
    primaryColor: Color(0xFF90CAF9),
    secondaryColor: Color(0xFFCE93D8),
    errorColor: Color(0xFFEF9A9A),
    successColor: Color(0xFFA5D6A7),
    warningColor: Color(0xFFFFCC80),
    borderColor: Colors.white70,
    disabledColor: Color(0xFF757575),
    linkColor: Color(0xFF90CAF9),
    selectedColor: Color(0xFF1E3A5F),
    focusColor: Color(0xFFFFEB3B),
  );
}

/// 高对比度模式服务
/// 提供高对比度模式支持，确保视力障碍用户能够清晰看到界面元素
class HighContrastService {
  static final HighContrastService _instance = HighContrastService._internal();
  factory HighContrastService() => _instance;
  HighContrastService._internal();

  /// 当前模式
  HighContrastMode _currentMode = HighContrastMode.auto;

  /// 当前主题配置
  HighContrastThemeConfig? _currentThemeConfig;

  /// 模式变更监听器
  final List<void Function(HighContrastMode, HighContrastThemeConfig?)>
      _listeners = [];

  /// 系统高对比度设置
  bool _systemHighContrastEnabled = false;

  /// 系统暗色模式
  bool _systemDarkModeEnabled = false;

  /// 获取当前模式
  HighContrastMode get currentMode => _currentMode;

  /// 获取当前主题配置
  HighContrastThemeConfig? get currentThemeConfig => _currentThemeConfig;

  /// 是否启用高对比度
  bool get isHighContrastEnabled =>
      _currentMode != HighContrastMode.off &&
      _currentMode != HighContrastMode.auto;

  /// 是否有效启用（包括自动模式下系统启用）
  bool get isEffectivelyEnabled {
    if (_currentMode == HighContrastMode.off) return false;
    if (_currentMode == HighContrastMode.auto) {
      return _systemHighContrastEnabled;
    }
    return true;
  }

  /// 初始化服务
  void initialize(BuildContext context) {
    _updateSystemSettings(context);
    _applyMode(_currentMode);
  }

  /// 更新系统设置
  void _updateSystemSettings(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _systemHighContrastEnabled = mediaQuery.highContrast;
    _systemDarkModeEnabled =
        mediaQuery.platformBrightness == Brightness.dark;
  }

  /// 设置高对比度模式
  void setMode(HighContrastMode mode) {
    if (_currentMode == mode) return;
    _currentMode = mode;
    _applyMode(mode);
    _notifyListeners();
  }

  /// 应用模式
  void _applyMode(HighContrastMode mode) {
    switch (mode) {
      case HighContrastMode.off:
        _currentThemeConfig = null;
        break;
      case HighContrastMode.auto:
        if (_systemHighContrastEnabled) {
          _currentThemeConfig = _systemDarkModeEnabled
              ? HighContrastThemeConfig.dark
              : HighContrastThemeConfig.light;
        } else {
          _currentThemeConfig = null;
        }
        break;
      case HighContrastMode.light:
        _currentThemeConfig = HighContrastThemeConfig.light;
        break;
      case HighContrastMode.dark:
        _currentThemeConfig = HighContrastThemeConfig.dark;
        break;
      case HighContrastMode.yellowOnBlack:
        _currentThemeConfig = HighContrastThemeConfig.yellowOnBlack;
        break;
      case HighContrastMode.inverted:
        _currentThemeConfig = HighContrastThemeConfig.inverted;
        break;
    }
  }

  /// 切换高对比度模式
  void toggle() {
    if (_currentMode == HighContrastMode.off) {
      setMode(_systemDarkModeEnabled
          ? HighContrastMode.dark
          : HighContrastMode.light);
    } else {
      setMode(HighContrastMode.off);
    }
  }

  /// 循环切换模式
  void cycleMode() {
    final modes = HighContrastMode.values;
    final currentIndex = modes.indexOf(_currentMode);
    final nextIndex = (currentIndex + 1) % modes.length;
    setMode(modes[nextIndex]);
  }

  /// 添加监听器
  void addListener(
      void Function(HighContrastMode, HighContrastThemeConfig?) listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(
      void Function(HighContrastMode, HighContrastThemeConfig?) listener) {
    _listeners.remove(listener);
  }

  /// 通知监听器
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_currentMode, _currentThemeConfig);
    }
  }

  // ==================== 主题生成 ====================

  /// 生成高对比度 ThemeData
  ThemeData generateThemeData({
    required bool isDark,
    HighContrastThemeConfig? config,
  }) {
    final themeConfig = config ?? _currentThemeConfig;
    if (themeConfig == null) {
      return isDark ? ThemeData.dark() : ThemeData.light();
    }

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: themeConfig.primaryColor,
        onPrimary: themeConfig.backgroundColor,
        secondary: themeConfig.secondaryColor,
        onSecondary: themeConfig.backgroundColor,
        error: themeConfig.errorColor,
        onError: themeConfig.backgroundColor,
        surface: themeConfig.backgroundColor,
        onSurface: themeConfig.foregroundColor,
      ),
      scaffoldBackgroundColor: themeConfig.backgroundColor,
      textTheme: _buildTextTheme(themeConfig),
      iconTheme: IconThemeData(color: themeConfig.foregroundColor),
      appBarTheme: AppBarTheme(
        backgroundColor: themeConfig.backgroundColor,
        foregroundColor: themeConfig.foregroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: themeConfig.backgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: themeConfig.borderColor, width: 2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: themeConfig.borderColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: themeConfig.borderColor, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: themeConfig.focusColor, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: themeConfig.errorColor, width: 2),
        ),
        labelStyle: TextStyle(color: themeConfig.foregroundColor),
        hintStyle: TextStyle(color: themeConfig.disabledColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeConfig.primaryColor,
          foregroundColor: themeConfig.backgroundColor,
          side: BorderSide(color: themeConfig.borderColor, width: 2),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: themeConfig.primaryColor,
          side: BorderSide(color: themeConfig.primaryColor, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: themeConfig.linkColor,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return themeConfig.primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(themeConfig.backgroundColor),
        side: BorderSide(color: themeConfig.borderColor, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return themeConfig.primaryColor;
          }
          return themeConfig.borderColor;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return themeConfig.primaryColor;
          }
          return themeConfig.disabledColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return themeConfig.primaryColor.withValues(alpha: 0.5);
          }
          return themeConfig.disabledColor.withValues(alpha: 0.3);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: themeConfig.borderColor,
        thickness: 1,
      ),
      focusColor: themeConfig.focusColor,
      hoverColor: themeConfig.selectedColor,
    );
  }

  /// 构建文字主题
  TextTheme _buildTextTheme(HighContrastThemeConfig config) {
    return TextTheme(
      displayLarge: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: config.foregroundColor),
      bodyMedium: TextStyle(color: config.foregroundColor),
      bodySmall: TextStyle(color: config.foregroundColor),
      labelLarge: TextStyle(
        color: config.foregroundColor,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(color: config.foregroundColor),
      labelSmall: TextStyle(color: config.foregroundColor),
    );
  }

  // ==================== 颜色工具 ====================

  /// 获取适合当前模式的前景色
  Color getForegroundColor(BuildContext context) {
    return _currentThemeConfig?.foregroundColor ??
        Theme.of(context).colorScheme.onSurface;
  }

  /// 获取适合当前模式的背景色
  Color getBackgroundColor(BuildContext context) {
    return _currentThemeConfig?.backgroundColor ??
        Theme.of(context).colorScheme.surface;
  }

  /// 获取适合当前模式的主要色
  Color getPrimaryColor(BuildContext context) {
    return _currentThemeConfig?.primaryColor ??
        Theme.of(context).colorScheme.primary;
  }

  /// 确保颜色满足对比度要求
  Color ensureContrast(
    Color foreground,
    Color background, {
    double minRatio = 4.5,
  }) {
    final ratio = _calculateContrastRatio(foreground, background);
    if (ratio >= minRatio) {
      return foreground;
    }

    // 如果对比度不够，调整前景色
    final bgLuminance = _relativeLuminance(background);
    if (bgLuminance > 0.5) {
      // 背景较亮，使用更深的前景色
      return _darkenUntilContrast(foreground, background, minRatio);
    } else {
      // 背景较暗，使用更亮的前景色
      return _lightenUntilContrast(foreground, background, minRatio);
    }
  }

  /// 计算对比度
  double _calculateContrastRatio(Color fg, Color bg) {
    final l1 = _relativeLuminance(fg);
    final l2 = _relativeLuminance(bg);
    final lighter = max(l1, l2);
    final darker = min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 计算相对亮度
  double _relativeLuminance(Color color) {
    double r = color.red / 255;
    double g = color.green / 255;
    double b = color.blue / 255;

    r = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4).toDouble();
    g = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4).toDouble();
    b = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 加深颜色直到达到对比度要求
  Color _darkenUntilContrast(Color color, Color background, double minRatio) {
    Color current = color;
    for (int i = 0; i < 100; i++) {
      if (_calculateContrastRatio(current, background) >= minRatio) {
        return current;
      }
      current = Color.fromARGB(
        current.alpha,
        (current.red * 0.9).round().clamp(0, 255),
        (current.green * 0.9).round().clamp(0, 255),
        (current.blue * 0.9).round().clamp(0, 255),
      );
    }
    return Colors.black;
  }

  /// 变亮颜色直到达到对比度要求
  Color _lightenUntilContrast(Color color, Color background, double minRatio) {
    Color current = color;
    for (int i = 0; i < 100; i++) {
      if (_calculateContrastRatio(current, background) >= minRatio) {
        return current;
      }
      current = Color.fromARGB(
        current.alpha,
        (current.red + (255 - current.red) * 0.1).round().clamp(0, 255),
        (current.green + (255 - current.green) * 0.1).round().clamp(0, 255),
        (current.blue + (255 - current.blue) * 0.1).round().clamp(0, 255),
      );
    }
    return Colors.white;
  }

  /// 获取模式的显示名称
  String getModeDisplayName(HighContrastMode mode) {
    switch (mode) {
      case HighContrastMode.off:
        return '关闭';
      case HighContrastMode.auto:
        return '跟随系统';
      case HighContrastMode.light:
        return '高对比度亮色';
      case HighContrastMode.dark:
        return '高对比度暗色';
      case HighContrastMode.yellowOnBlack:
        return '黄底黑字';
      case HighContrastMode.inverted:
        return '反转色彩';
    }
  }
}

/// 高对比度模式包装组件
class HighContrastWrapper extends StatefulWidget {
  final Widget child;

  const HighContrastWrapper({
    super.key,
    required this.child,
  });

  @override
  State<HighContrastWrapper> createState() => _HighContrastWrapperState();
}

class _HighContrastWrapperState extends State<HighContrastWrapper> {
  final _service = HighContrastService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onModeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service.initialize(context);
  }

  @override
  void dispose() {
    _service.removeListener(_onModeChanged);
    super.dispose();
  }

  void _onModeChanged(HighContrastMode mode, HighContrastThemeConfig? config) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
