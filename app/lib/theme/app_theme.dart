import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

class AppColors {
  // Primary colors (default blue theme)
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);

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
  static ThemeData get lightTheme => createLightTheme(AppColors.primary);
  static ThemeData get darkTheme => createDarkTheme(AppColors.primary);

  static ThemeData createLightTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
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
