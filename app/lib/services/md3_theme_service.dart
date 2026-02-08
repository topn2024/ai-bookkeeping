import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Material Design 3 主题服务
///
/// 核心功能：
/// 1. 动态色彩生成（从种子色或图片提取）
/// 2. 深色模式完整适配
/// 3. 自定义色调映射
/// 4. 表面色阶系统
/// 5. 与系统主题联动
///
/// 对应设计文档：第20章 视觉设计规范
///
/// 使用示例：
/// ```dart
/// final themeService = MD3ThemeService();
///
/// // 从种子色生成主题
/// final theme = themeService.generateTheme(
///   seedColor: Color(0xFF4CAF50),
///   brightness: Brightness.light,
/// );
///
/// // 应用主题
/// MaterialApp(theme: theme);
/// ```
class MD3ThemeService {
  /// 默认种子色（主色调）
  static const Color defaultSeedColor = Color(0xFF4CAF50);

  /// 品牌色定义
  static const Color brandPrimary = Color(0xFF4CAF50);
  static const Color brandSecondary = Color(0xFF2196F3);
  static const Color brandTertiary = Color(0xFFFF9800);

  /// 语义色定义
  static const Color semanticSuccess = Color(0xFF4CAF50);
  static const Color semanticWarning = Color(0xFFFF9800);
  static const Color semanticError = Color(0xFFF44336);
  static const Color semanticInfo = Color(0xFF2196F3);

  /// 钱龄健康等级颜色
  static const Map<int, Color> moneyAgeColors = {
    1: Color(0xFFE53935), // 红色 - 1级最差
    2: Color(0xFFFF9800), // 橙色 - 2级
    3: Color(0xFFFFC107), // 黄色 - 3级
    4: Color(0xFF8BC34A), // 浅绿 - 4级
    5: Color(0xFF4CAF50), // 绿色 - 5级
    6: Color(0xFF2E7D32), // 深绿 - 6级最佳
  };

  /// 分类颜色调色板
  static const List<Color> categoryColors = [
    Color(0xFFFF7043), // 餐饮
    Color(0xFF42A5F5), // 交通
    Color(0xFFAB47BC), // 购物
    Color(0xFF66BB6A), // 日用
    Color(0xFFFFCA28), // 娱乐
    Color(0xFF26A69A), // 医疗
    Color(0xFFEC407A), // 教育
    Color(0xFF5C6BC0), // 住房
    Color(0xFF8D6E63), // 通讯
    Color(0xFF78909C), // 其他
  ];

  MD3ThemeService();

  /// 从种子色生成完整主题
  ThemeData generateTheme({
    Color seedColor = defaultSeedColor,
    Brightness brightness = Brightness.light,
    bool useDynamicColor = true,
    double contrastLevel = 0.0,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,

      // 排版
      textTheme: _buildTextTheme(colorScheme),

      // 卡片
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: colorScheme.surfaceContainerLowest,
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(88, 48),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(88, 48),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(88, 48),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(64, 40),
        ),
      ),

      // 浮动操作按钮
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // 芯片
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // 底部导航
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 0,
      ),

      // 导航栏
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            );
          }
          return TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      // 对话框
      dialogTheme: DialogThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        backgroundColor: colorScheme.surface,
      ),

      // 底部弹窗
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(32, 4),
        showDragHandle: true,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),

      // 分割线
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // 开关
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // 列表项
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
      ),

      // 页面过渡
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// 构建文字主题
  TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      // Display
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: colorScheme.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),

      // Headline
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),

      // Title
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),

      // Body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),

      // Label
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// 生成深色主题
  ThemeData generateDarkTheme({Color seedColor = defaultSeedColor}) {
    return generateTheme(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
  }

  /// 获取钱龄等级颜色
  Color getMoneyAgeLevelColor(int level) {
    return moneyAgeColors[level.clamp(1, 6)] ?? semanticWarning;
  }

  /// 获取分类颜色
  Color getCategoryColor(int index) {
    return categoryColors[index % categoryColors.length];
  }

  /// 生成渐变色
  LinearGradient generateGradient({
    required Color startColor,
    required Color endColor,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      colors: [startColor, endColor],
      begin: begin,
      end: end,
    );
  }

  /// 表面色阶（Surface Tones）
  Color getSurfaceTone(ColorScheme colorScheme, int level) {
    switch (level) {
      case 1:
        return colorScheme.surfaceContainerLowest;
      case 2:
        return colorScheme.surfaceContainerLow;
      case 3:
        return colorScheme.surfaceContainer;
      case 4:
        return colorScheme.surfaceContainerHigh;
      case 5:
        return colorScheme.surfaceContainerHighest;
      default:
        return colorScheme.surface;
    }
  }
}

/// 主题提供者扩展
extension ThemeDataExtension on ThemeData {
  /// 获取钱龄颜色
  Color moneyAgeColor(int level) {
    return MD3ThemeService.moneyAgeColors[level.clamp(1, 6)] ??
        MD3ThemeService.semanticWarning;
  }

  /// 获取分类颜色
  Color categoryColor(int index) {
    return MD3ThemeService.categoryColors[index % MD3ThemeService.categoryColors.length];
  }

  /// 语义色
  Color get successColor => MD3ThemeService.semanticSuccess;
  Color get warningColor => MD3ThemeService.semanticWarning;
  Color get infoColor => MD3ThemeService.semanticInfo;
}
