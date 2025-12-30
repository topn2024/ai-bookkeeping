import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_theme.dart';
import '../theme/app_theme.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

enum AppColorTheme {
  blue,
  green,
  orange,
  purple,
  red,
  teal,
  pink,
  indigo,
  custom, // 自定义主题
}

class ColorThemeData {
  final String name;
  final Color primaryColor;
  final Color incomeColor;
  final Color expenseColor;
  final Color transferColor;

  const ColorThemeData({
    required this.name,
    required this.primaryColor,
    required this.incomeColor,
    required this.expenseColor,
    required this.transferColor,
  });
}

class AppColorThemes {
  static const Map<AppColorTheme, ColorThemeData> themes = {
    AppColorTheme.blue: ColorThemeData(
      name: '天空蓝',
      primaryColor: Color(0xFF2196F3),
      incomeColor: Color(0xFF4CAF50),
      expenseColor: Color(0xFFF44336),
      transferColor: Color(0xFFFF9800),
    ),
    AppColorTheme.green: ColorThemeData(
      name: '清新绿',
      primaryColor: Color(0xFF4CAF50),
      incomeColor: Color(0xFF8BC34A),
      expenseColor: Color(0xFFE91E63),
      transferColor: Color(0xFF00BCD4),
    ),
    AppColorTheme.orange: ColorThemeData(
      name: '活力橙',
      primaryColor: Color(0xFFFF9800),
      incomeColor: Color(0xFF4CAF50),
      expenseColor: Color(0xFFF44336),
      transferColor: Color(0xFF2196F3),
    ),
    AppColorTheme.purple: ColorThemeData(
      name: '优雅紫',
      primaryColor: Color(0xFF9C27B0),
      incomeColor: Color(0xFF4CAF50),
      expenseColor: Color(0xFFE91E63),
      transferColor: Color(0xFF03A9F4),
    ),
    AppColorTheme.red: ColorThemeData(
      name: '热情红',
      primaryColor: Color(0xFFF44336),
      incomeColor: Color(0xFF4CAF50),
      expenseColor: Color(0xFFE91E63),
      transferColor: Color(0xFFFF9800),
    ),
    AppColorTheme.teal: ColorThemeData(
      name: '宁静青',
      primaryColor: Color(0xFF009688),
      incomeColor: Color(0xFF8BC34A),
      expenseColor: Color(0xFFF44336),
      transferColor: Color(0xFFFF9800),
    ),
    AppColorTheme.pink: ColorThemeData(
      name: '甜蜜粉',
      primaryColor: Color(0xFFE91E63),
      incomeColor: Color(0xFF4CAF50),
      expenseColor: Color(0xFFFF5252),
      transferColor: Color(0xFF7C4DFF),
    ),
    AppColorTheme.indigo: ColorThemeData(
      name: '深邃靛',
      primaryColor: Color(0xFF3F51B5),
      incomeColor: Color(0xFF4CAF50),
      expenseColor: Color(0xFFF44336),
      transferColor: Color(0xFFFF9800),
    ),
  };

  static ColorThemeData getTheme(AppColorTheme theme) {
    return themes[theme] ?? themes[AppColorTheme.blue]!;
  }
}

class ThemeState {
  final AppThemeMode mode;
  final AppColorTheme colorTheme;
  final CustomTheme? activeCustomTheme;
  final List<CustomTheme> customThemes;
  final bool isMember; // 会员状态

  const ThemeState({
    this.mode = AppThemeMode.system,
    this.colorTheme = AppColorTheme.blue,
    this.activeCustomTheme,
    this.customThemes = const [],
    this.isMember = false,
  });

  ThemeState copyWith({
    AppThemeMode? mode,
    AppColorTheme? colorTheme,
    CustomTheme? activeCustomTheme,
    List<CustomTheme>? customThemes,
    bool? isMember,
    bool clearCustomTheme = false,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      colorTheme: colorTheme ?? this.colorTheme,
      activeCustomTheme: clearCustomTheme ? null : (activeCustomTheme ?? this.activeCustomTheme),
      customThemes: customThemes ?? this.customThemes,
      isMember: isMember ?? this.isMember,
    );
  }

  bool get isUsingCustomTheme => colorTheme == AppColorTheme.custom && activeCustomTheme != null;
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _themeKey = 'app_theme_mode';
  static const String _colorKey = 'app_color_theme';
  static const String _customThemesKey = 'custom_themes';
  static const String _activeCustomThemeKey = 'active_custom_theme';
  static const String _memberKey = 'is_member';

  /// 缓存的 SharedPreferences 实例，避免重复获取
  SharedPreferences? _prefs;

  /// 获取缓存的 SharedPreferences 实例
  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  ThemeState build() {
    _loadTheme();
    return const ThemeState();
  }

  Future<void> _loadTheme() async {
    final prefs = await _sharedPrefs;
    final themeIndex = prefs.getInt(_themeKey) ?? 2; // Default to system
    final colorIndex = prefs.getInt(_colorKey) ?? 0; // Default to blue
    final isMember = prefs.getBool(_memberKey) ?? false;

    // 加载自定义主题列表
    final customThemesJson = prefs.getString(_customThemesKey);
    List<CustomTheme> customThemes = [];
    if (customThemesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(customThemesJson);
        customThemes = decoded.map((e) => CustomTheme.fromMap(e)).toList();
      } catch (e) {
        // 解析失败时使用空列表
      }
    }

    // 加载活动自定义主题
    CustomTheme? activeCustomTheme;
    final activeCustomThemeJson = prefs.getString(_activeCustomThemeKey);
    if (activeCustomThemeJson != null) {
      try {
        activeCustomTheme = CustomTheme.fromMap(jsonDecode(activeCustomThemeJson));
      } catch (e) {
        // 解析失败时使用null
      }
    }

    state = ThemeState(
      mode: AppThemeMode.values[themeIndex],
      colorTheme: colorIndex < AppColorTheme.values.length
          ? AppColorTheme.values[colorIndex]
          : AppColorTheme.blue,
      customThemes: customThemes,
      activeCustomTheme: activeCustomTheme,
      isMember: isMember,
    );
  }

  /// 设置主题模式（立即更新 UI，后台保存）
  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(mode: mode);
    // 后台保存，不阻塞 UI
    _saveThemeMode(mode);
  }

  Future<void> _saveThemeMode(AppThemeMode mode) async {
    final prefs = await _sharedPrefs;
    await prefs.setInt(_themeKey, mode.index);
  }

  /// 设置颜色主题（立即更新 UI，后台保存）
  void setColorTheme(AppColorTheme colorTheme) {
    state = state.copyWith(
      colorTheme: colorTheme,
      clearCustomTheme: colorTheme != AppColorTheme.custom,
    );
    // 后台保存，不阻塞 UI
    _saveColorTheme(colorTheme);
  }

  Future<void> _saveColorTheme(AppColorTheme colorTheme) async {
    final prefs = await _sharedPrefs;
    await prefs.setInt(_colorKey, colorTheme.index);
  }

  /// 设置会员状态（立即更新 UI，后台保存）
  void setMemberStatus(bool isMember) {
    state = state.copyWith(isMember: isMember);
    // 后台保存，不阻塞 UI
    _saveMemberStatus(isMember);
  }

  Future<void> _saveMemberStatus(bool isMember) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(_memberKey, isMember);
  }

  /// 创建新的自定义主题
  Future<CustomTheme> createCustomTheme({
    required String name,
    CustomTheme? baseTheme,
  }) async {
    final theme = baseTheme?.copyWith(
          id: const Uuid().v4(),
          name: name,
        ) ??
        CustomTheme.defaultLight(
          id: const Uuid().v4(),
          name: name,
        );

    final updatedThemes = [...state.customThemes, theme];
    state = state.copyWith(customThemes: updatedThemes);
    await _saveCustomThemes();

    return theme;
  }

  /// 更新自定义主题
  Future<void> updateCustomTheme(CustomTheme theme) async {
    final updatedThemes = state.customThemes.map((t) {
      return t.id == theme.id ? theme : t;
    }).toList();

    state = state.copyWith(
      customThemes: updatedThemes,
      activeCustomTheme: state.activeCustomTheme?.id == theme.id
          ? theme
          : state.activeCustomTheme,
    );

    await _saveCustomThemes();
    if (state.activeCustomTheme?.id == theme.id) {
      await _saveActiveCustomTheme();
    }
  }

  /// 删除自定义主题
  void deleteCustomTheme(String themeId) {
    final updatedThemes = state.customThemes.where((t) => t.id != themeId).toList();

    // 如果删除的是当前激活的主题，切换到默认主题
    if (state.activeCustomTheme?.id == themeId) {
      state = state.copyWith(
        customThemes: updatedThemes,
        colorTheme: AppColorTheme.blue,
        clearCustomTheme: true,
      );
      // 后台保存
      _deleteActiveCustomTheme();
    } else {
      state = state.copyWith(customThemes: updatedThemes);
    }

    _saveCustomThemes();
  }

  Future<void> _deleteActiveCustomTheme() async {
    final prefs = await _sharedPrefs;
    await prefs.setInt(_colorKey, AppColorTheme.blue.index);
    await prefs.remove(_activeCustomThemeKey);
  }

  /// 应用自定义主题（立即更新 UI，后台保存）
  void applyCustomTheme(CustomTheme theme) {
    state = state.copyWith(
      colorTheme: AppColorTheme.custom,
      activeCustomTheme: theme,
    );

    // 后台保存，不阻塞 UI
    _applyCustomThemeToPrefs(theme);
  }

  Future<void> _applyCustomThemeToPrefs(CustomTheme theme) async {
    final prefs = await _sharedPrefs;
    await prefs.setInt(_colorKey, AppColorTheme.custom.index);
    await _saveActiveCustomTheme();
  }

  /// 从预设创建自定义主题
  Future<CustomTheme> createFromPreset(CustomTheme preset, String name) async {
    final theme = preset.copyWith(
      id: const Uuid().v4(),
      name: name,
    );

    final updatedThemes = [...state.customThemes, theme];
    state = state.copyWith(customThemes: updatedThemes);
    await _saveCustomThemes();

    return theme;
  }

  Future<void> _saveCustomThemes() async {
    final prefs = await _sharedPrefs;
    final themesJson = jsonEncode(state.customThemes.map((t) => t.toMap()).toList());
    await prefs.setString(_customThemesKey, themesJson);
  }

  Future<void> _saveActiveCustomTheme() async {
    final prefs = await _sharedPrefs;
    if (state.activeCustomTheme != null) {
      await prefs.setString(
        _activeCustomThemeKey,
        jsonEncode(state.activeCustomTheme!.toMap()),
      );
    } else {
      await prefs.remove(_activeCustomThemeKey);
    }
  }

  void toggleTheme() {
    if (state.mode == AppThemeMode.light) {
      setThemeMode(AppThemeMode.dark);
    } else {
      setThemeMode(AppThemeMode.light);
    }
  }

  ThemeMode get themeMode {
    switch (state.mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  String get themeName {
    switch (state.mode) {
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }

  IconData get themeIcon {
    switch (state.mode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  ColorThemeData get currentColorTheme {
    if (state.isUsingCustomTheme) {
      final custom = state.activeCustomTheme!;
      return ColorThemeData(
        name: custom.name,
        primaryColor: custom.primaryColor,
        incomeColor: custom.incomeColor,
        expenseColor: custom.expenseColor,
        transferColor: custom.transferColor,
      );
    }
    return AppColorThemes.getTheme(state.colorTheme);
  }

  Color get primaryColor => currentColorTheme.primaryColor;
  Color get incomeColor => currentColorTheme.incomeColor;
  Color get expenseColor => currentColorTheme.expenseColor;
  Color get transferColor => currentColorTheme.transferColor;

  /// 获取完整的自定义主题数据（用于构建 ThemeData）
  ThemeData getLightTheme() {
    if (state.isUsingCustomTheme) {
      return _buildCustomLightTheme(state.activeCustomTheme!);
    }
    return AppTheme.createLightTheme(primaryColor);
  }

  ThemeData getDarkTheme() {
    if (state.isUsingCustomTheme) {
      return _buildCustomDarkTheme(state.activeCustomTheme!);
    }
    return AppTheme.createDarkTheme(primaryColor);
  }

  ThemeData _buildCustomLightTheme(CustomTheme theme) {
    return ThemeData(
      useMaterial3: theme.useMaterial3,
      colorScheme: ColorScheme.fromSeed(
        seedColor: theme.primaryColor,
        brightness: Brightness.light,
        primary: theme.primaryColor,
        secondary: theme.secondaryColor,
        surface: theme.surfaceColor,
      ),
      scaffoldBackgroundColor: theme.backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: theme.cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(theme.cardBorderRadius)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.cardColor,
        selectedItemColor: theme.primaryColor,
        unselectedItemColor: theme.textSecondaryColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: DividerThemeData(
        color: theme.dividerColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.buttonBorderRadius),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.buttonBorderRadius),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.buttonBorderRadius),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.buttonBorderRadius),
          ),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: theme.textPrimaryColor),
        bodyMedium: TextStyle(color: theme.textPrimaryColor),
        bodySmall: TextStyle(color: theme.textSecondaryColor),
        titleLarge: TextStyle(color: theme.textPrimaryColor),
        titleMedium: TextStyle(color: theme.textPrimaryColor),
        titleSmall: TextStyle(color: theme.textSecondaryColor),
      ),
    );
  }

  ThemeData _buildCustomDarkTheme(CustomTheme theme) {
    // 对于深色主题，如果自定义主题是浅色的，我们需要调整
    final isDarkTheme = theme.backgroundColor.computeLuminance() < 0.5;

    if (isDarkTheme) {
      return ThemeData(
        useMaterial3: theme.useMaterial3,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.primaryColor,
          brightness: Brightness.dark,
          primary: theme.primaryColor,
          secondary: theme.secondaryColor,
          surface: theme.surfaceColor,
        ),
        scaffoldBackgroundColor: theme.backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: theme.surfaceColor,
          foregroundColor: theme.textPrimaryColor,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: theme.cardColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(theme.cardBorderRadius)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: theme.surfaceColor,
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: theme.textSecondaryColor,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dividerTheme: DividerThemeData(
          color: theme.dividerColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: theme.surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(theme.buttonBorderRadius),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(theme.buttonBorderRadius),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(theme.buttonBorderRadius),
            borderSide: BorderSide(color: theme.primaryColor, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.buttonBorderRadius),
            ),
          ),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: theme.textPrimaryColor),
          bodyMedium: TextStyle(color: theme.textPrimaryColor),
          bodySmall: TextStyle(color: theme.textSecondaryColor),
          titleLarge: TextStyle(color: theme.textPrimaryColor),
          titleMedium: TextStyle(color: theme.textPrimaryColor),
          titleSmall: TextStyle(color: theme.textSecondaryColor),
        ),
      );
    } else {
      // 如果是浅色主题，使用默认深色配置
      return AppTheme.createDarkTheme(theme.primaryColor);
    }
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);

// Convenience provider for current color theme
final colorThemeProvider = Provider<ColorThemeData>((ref) {
  return ref.watch(themeProvider.notifier).currentColorTheme;
});

// Provider for checking if user can use custom themes
final canUseCustomThemeProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).isMember;
});

// Provider for custom themes list
final customThemesProvider = Provider<List<CustomTheme>>((ref) {
  return ref.watch(themeProvider).customThemes;
});

// Provider for active custom theme
final activeCustomThemeProvider = Provider<CustomTheme?>((ref) {
  return ref.watch(themeProvider).activeCustomTheme;
});
