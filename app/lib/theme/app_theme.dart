import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

/// 反重力设计体系颜色 (Antigravity Design System Colors)
///
/// 矢车菊蓝主色系 - 清新优雅，传达轻盈、浪漫、温暖的感觉
/// 设计规范参考：20.2.6 反重力设计体系
class AntigravityColors {
  AntigravityColors._();

  // === 矢车菊蓝主色系 ===
  static const Color primary = Color(0xFF6495ED);           // 矢车菊蓝 - 主色
  static const Color primaryDark = Color(0xFF4169E1);       // 皇家蓝 - 深色
  static const Color primaryLight = Color(0xFF87CEFA);      // 浅天蓝 - 浅色
  static const Color primaryContainer = Color(0xFFEBF3FF);  // 蓝色容器背景

  // === 辅助色 - 薰衣草紫点缀 ===
  static const Color secondary = Color(0xFF7B8AB8);         // 灰蓝紫
  static const Color secondaryContainer = Color(0xFFE8ECF8);
  static const Color tertiary = Color(0xFF9370DB);          // 中紫色点缀

  // === 表面色 ===
  static const Color surface = Color(0xFFF8FAFF);           // 主背景 - 带蓝调的白
  static const Color surfaceVariant = Color(0xFFEDF2FA);    // 卡片背景
  static const Color surfaceElevated = Color(0xFFFFFFFF);   // 提升卡片

  // === 钱龄专用色 ===
  static const Color moneyAgeExcellent = Color(0xFF66BB6A); // 优秀-绿
  static const Color moneyAgeGood = Color(0xFF64B5F6);      // 良好-蓝
  static const Color moneyAgeFair = Color(0xFFFFB74D);      // 一般-橙
  static const Color moneyAgePoor = Color(0xFFE57373);      // 较差-红

  // === 玻璃态效果色 ===
  static Color glassBackground = Colors.white.withValues(alpha: 0.72);
  static Color glassBackgroundStrong = Colors.white.withValues(alpha: 0.88);
  static Color glassBorder = Colors.white.withValues(alpha: 0.3);
}

class AppColors {
  // Primary colors (default blue theme - 矢车菊蓝)
  static const Color primary = Color(0xFF6495ED);
  static const Color primaryDark = Color(0xFF4169E1);
  static const Color primaryLight = Color(0xFF87CEFA);

  // Accent colors
  static const Color accent = Color(0xFF03A9F4);

  // Semantic colors (默认值，实际使用时应通过 ThemeColors 获取)
  static const Color income = Color(0xFF4CAF50);
  static const Color expense = Color(0xFFF44336);
  static const Color transfer = Color(0xFFFF9800);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // Border colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);
}

/// 主题语义颜色 - 用于获取当前主题的收入/支出/转账颜色
class ThemeColors {
  final Color income;
  final Color expense;
  final Color transfer;
  final Color primary;

  const ThemeColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.primary,
  });

  /// 默认颜色
  static const ThemeColors defaults = ThemeColors(
    income: AppColors.income,
    expense: AppColors.expense,
    transfer: AppColors.transfer,
    primary: AppColors.primary,
  );

  /// 从 WidgetRef 获取当前主题颜色（监听变化，主题切换时自动更新）
  static ThemeColors of(WidgetRef ref) {
    // 监听 themeProvider 状态变化
    ref.watch(themeProvider);
    // 从 notifier 读取颜色值
    final notifier = ref.read(themeProvider.notifier);
    return ThemeColors(
      income: notifier.incomeColor,
      expense: notifier.expenseColor,
      transfer: notifier.transferColor,
      primary: notifier.primaryColor,
    );
  }

  /// 从 WidgetRef 读取当前主题颜色（不监听变化）
  static ThemeColors read(WidgetRef ref) {
    final notifier = ref.read(themeProvider.notifier);
    return ThemeColors(
      income: notifier.incomeColor,
      expense: notifier.expenseColor,
      transfer: notifier.transferColor,
      primary: notifier.primaryColor,
    );
  }
}

/// WidgetRef 扩展，方便获取主题颜色
extension ThemeColorsExtension on WidgetRef {
  /// 获取当前主题语义颜色（监听变化）
  ThemeColors get themeColors => ThemeColors.of(this);

  /// 获取收入颜色（监听变化）
  Color get incomeColor {
    watch(themeProvider);
    return read(themeProvider.notifier).incomeColor;
  }

  /// 获取支出颜色（监听变化）
  Color get expenseColor {
    watch(themeProvider);
    return read(themeProvider.notifier).expenseColor;
  }

  /// 获取转账颜色（监听变化）
  Color get transferColor {
    watch(themeProvider);
    return read(themeProvider.notifier).transferColor;
  }
}

class AppTheme {
  AppTheme._();

  // === 静态颜色访问器 (矢车菊蓝主题) ===

  /// 主色 - 矢车菊蓝
  static Color get primaryColor => AntigravityColors.primary;

  /// 主色深 - 皇家蓝
  static Color get primaryDarkColor => AntigravityColors.primaryDark;

  /// 主色浅 - 浅天蓝
  static Color get primaryLightColor => AntigravityColors.primaryLight;

  /// 表面色 / 背景色
  static Color get surfaceColor => AntigravityColors.surface;

  /// 表面变体色 / 卡片背景
  static Color get surfaceVariantColor => AntigravityColors.surfaceVariant;

  /// 卡片背景色
  static Color get cardColor => AntigravityColors.surfaceElevated;

  /// 主要文本颜色
  static Color get textPrimaryColor => AppColors.textPrimary;

  /// 次要文本颜色
  static Color get textSecondaryColor => AppColors.textSecondary;

  /// 提示文本颜色
  static Color get textHintColor => AppColors.textHint;

  /// 分割线颜色
  static Color get dividerColor => AppColors.divider;

  /// 边框颜色
  static Color get borderColor => AppColors.border;

  /// 成功色 - 绿色
  static Color get successColor => AppColors.success;

  /// 警告色 - 橙色
  static Color get warningColor => AppColors.warning;

  /// 错误色 - 红色
  static Color get errorColor => AppColors.error;

  /// 信息色 - 蓝色
  static Color get infoColor => AppColors.info;

  /// 收入色 - 绿色
  static Color get incomeColor => AppColors.income;

  /// 支出色 - 红色
  static Color get expenseColor => AppColors.expense;

  /// 转账色 - 橙色
  static Color get transferColor => AppColors.transfer;

  /// 背景色
  static Color get backgroundColor => AppColors.background;

  /// 次要色
  static Color get secondaryColor => AntigravityColors.secondary;

  /// 第三色
  static Color get tertiaryColor => AntigravityColors.tertiary;

  /// 白色
  static Color get whiteColor => Colors.white;

  /// 禁用色
  static Color get disabledColor => const Color(0xFFBDBDBD);

  /// 阴影色
  static Color get shadowColor => Colors.black.withValues(alpha: 0.1);

  // === 钱龄专用色 ===

  /// 钱龄优秀 - 绿色
  static Color get moneyAgeExcellentColor => AntigravityColors.moneyAgeExcellent;

  /// 钱龄良好 - 蓝色
  static Color get moneyAgeGoodColor => AntigravityColors.moneyAgeGood;

  /// 钱龄一般 - 橙色
  static Color get moneyAgeFairColor => AntigravityColors.moneyAgeFair;

  /// 钱龄较差 - 红色
  static Color get moneyAgePoorColor => AntigravityColors.moneyAgePoor;

  // === 玻璃态效果色 ===

  /// 玻璃背景色
  static Color get glassBackgroundColor => AntigravityColors.glassBackground;

  /// 玻璃边框色
  static Color get glassBorderColor => AntigravityColors.glassBorder;

  // === 主题数据 ===

  static ThemeData get lightTheme => createLightTheme(AntigravityColors.primary);
  static ThemeData get darkTheme => createDarkTheme(AntigravityColors.primary);

  static ThemeData createLightTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      // 启用 iOS 风格的页面过渡动画，支持滑动返回手势
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: AntigravityColors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  static ThemeData createDarkTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      // 启用 iOS 风格的页面过渡动画，支持滑动返回手势
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3C3C3C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3C3C3C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
