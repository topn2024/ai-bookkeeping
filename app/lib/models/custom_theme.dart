import 'package:flutter/material.dart';

/// 自定义主题配置
class CustomTheme {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color incomeColor;
  final Color expenseColor;
  final Color transferColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color cardColor;
  final Color dividerColor;
  final double cardBorderRadius;
  final double buttonBorderRadius;
  final bool useMaterial3;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomTheme({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.incomeColor,
    required this.expenseColor,
    required this.transferColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.cardColor,
    required this.dividerColor,
    this.cardBorderRadius = 12.0,
    this.buttonBorderRadius = 8.0,
    this.useMaterial3 = true,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomTheme copyWith({
    String? id,
    String? name,
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? surfaceColor,
    Color? incomeColor,
    Color? expenseColor,
    Color? transferColor,
    Color? textPrimaryColor,
    Color? textSecondaryColor,
    Color? cardColor,
    Color? dividerColor,
    double? cardBorderRadius,
    double? buttonBorderRadius,
    bool? useMaterial3,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      incomeColor: incomeColor ?? this.incomeColor,
      expenseColor: expenseColor ?? this.expenseColor,
      transferColor: transferColor ?? this.transferColor,
      textPrimaryColor: textPrimaryColor ?? this.textPrimaryColor,
      textSecondaryColor: textSecondaryColor ?? this.textSecondaryColor,
      cardColor: cardColor ?? this.cardColor,
      dividerColor: dividerColor ?? this.dividerColor,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      buttonBorderRadius: buttonBorderRadius ?? this.buttonBorderRadius,
      useMaterial3: useMaterial3 ?? this.useMaterial3,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
      'backgroundColor': backgroundColor.toARGB32(),
      'surfaceColor': surfaceColor.toARGB32(),
      'incomeColor': incomeColor.toARGB32(),
      'expenseColor': expenseColor.toARGB32(),
      'transferColor': transferColor.toARGB32(),
      'textPrimaryColor': textPrimaryColor.toARGB32(),
      'textSecondaryColor': textSecondaryColor.toARGB32(),
      'cardColor': cardColor.toARGB32(),
      'dividerColor': dividerColor.toARGB32(),
      'cardBorderRadius': cardBorderRadius,
      'buttonBorderRadius': buttonBorderRadius,
      'useMaterial3': useMaterial3,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CustomTheme.fromMap(Map<String, dynamic> map) {
    return CustomTheme(
      id: map['id'] as String,
      name: map['name'] as String,
      primaryColor: Color(map['primaryColor'] as int),
      secondaryColor: Color(map['secondaryColor'] as int),
      backgroundColor: Color(map['backgroundColor'] as int),
      surfaceColor: Color(map['surfaceColor'] as int),
      incomeColor: Color(map['incomeColor'] as int),
      expenseColor: Color(map['expenseColor'] as int),
      transferColor: Color(map['transferColor'] as int),
      textPrimaryColor: Color(map['textPrimaryColor'] as int),
      textSecondaryColor: Color(map['textSecondaryColor'] as int),
      cardColor: Color(map['cardColor'] as int),
      dividerColor: Color(map['dividerColor'] as int),
      cardBorderRadius: (map['cardBorderRadius'] as num?)?.toDouble() ?? 12.0,
      buttonBorderRadius: (map['buttonBorderRadius'] as num?)?.toDouble() ?? 8.0,
      useMaterial3: map['useMaterial3'] as bool? ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  /// 默认浅色主题模板
  static CustomTheme defaultLight({required String id, String name = '自定义浅色'}) {
    final now = DateTime.now();
    return CustomTheme(
      id: id,
      name: name,
      primaryColor: const Color(0xFF2196F3),
      secondaryColor: const Color(0xFF03A9F4),
      backgroundColor: const Color(0xFFF5F5F5),
      surfaceColor: Colors.white,
      incomeColor: const Color(0xFF4CAF50),
      expenseColor: const Color(0xFFF44336),
      transferColor: const Color(0xFFFF9800),
      textPrimaryColor: const Color(0xFF212121),
      textSecondaryColor: const Color(0xFF757575),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE0E0E0),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 默认深色主题模板
  static CustomTheme defaultDark({required String id, String name = '自定义深色'}) {
    final now = DateTime.now();
    return CustomTheme(
      id: id,
      name: name,
      primaryColor: const Color(0xFF64B5F6),
      secondaryColor: const Color(0xFF4FC3F7),
      backgroundColor: const Color(0xFF121212),
      surfaceColor: const Color(0xFF1E1E1E),
      incomeColor: const Color(0xFF81C784),
      expenseColor: const Color(0xFFE57373),
      transferColor: const Color(0xFFFFB74D),
      textPrimaryColor: const Color(0xFFFFFFFF),
      textSecondaryColor: const Color(0xFFB0B0B0),
      cardColor: const Color(0xFF1E1E1E),
      dividerColor: const Color(0xFF3C3C3C),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 预设主题：森林绿
  static CustomTheme forestGreen({required String id}) {
    final now = DateTime.now();
    return CustomTheme(
      id: id,
      name: '森林绿',
      primaryColor: const Color(0xFF2E7D32),
      secondaryColor: const Color(0xFF66BB6A),
      backgroundColor: const Color(0xFFF1F8E9),
      surfaceColor: Colors.white,
      incomeColor: const Color(0xFF43A047),
      expenseColor: const Color(0xFFD32F2F),
      transferColor: const Color(0xFFFFA000),
      textPrimaryColor: const Color(0xFF1B5E20),
      textSecondaryColor: const Color(0xFF558B2F),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFC8E6C9),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 预设主题：樱花粉
  static CustomTheme sakuraPink({required String id}) {
    final now = DateTime.now();
    return CustomTheme(
      id: id,
      name: '樱花粉',
      primaryColor: const Color(0xFFEC407A),
      secondaryColor: const Color(0xFFF48FB1),
      backgroundColor: const Color(0xFFFCE4EC),
      surfaceColor: Colors.white,
      incomeColor: const Color(0xFF66BB6A),
      expenseColor: const Color(0xFFE91E63),
      transferColor: const Color(0xFF9C27B0),
      textPrimaryColor: const Color(0xFF880E4F),
      textSecondaryColor: const Color(0xFFAD1457),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFF8BBD0),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 预设主题：海洋蓝
  static CustomTheme oceanBlue({required String id}) {
    final now = DateTime.now();
    return CustomTheme(
      id: id,
      name: '海洋蓝',
      primaryColor: const Color(0xFF0277BD),
      secondaryColor: const Color(0xFF4FC3F7),
      backgroundColor: const Color(0xFFE1F5FE),
      surfaceColor: Colors.white,
      incomeColor: const Color(0xFF00897B),
      expenseColor: const Color(0xFFE53935),
      transferColor: const Color(0xFFFFB300),
      textPrimaryColor: const Color(0xFF01579B),
      textSecondaryColor: const Color(0xFF0288D1),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFB3E5FC),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 预设主题：暗夜紫
  static CustomTheme nightPurple({required String id}) {
    final now = DateTime.now();
    return CustomTheme(
      id: id,
      name: '暗夜紫',
      primaryColor: const Color(0xFF7C4DFF),
      secondaryColor: const Color(0xFFB388FF),
      backgroundColor: const Color(0xFF1A1A2E),
      surfaceColor: const Color(0xFF16213E),
      incomeColor: const Color(0xFF00E676),
      expenseColor: const Color(0xFFFF5252),
      transferColor: const Color(0xFFFFD740),
      textPrimaryColor: const Color(0xFFE0E0E0),
      textSecondaryColor: const Color(0xFFB0B0B0),
      cardColor: const Color(0xFF16213E),
      dividerColor: const Color(0xFF0F3460),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 预设主题：日落橙
  static CustomTheme sunsetOrange({required String id}) {
    final now = DateTime.now();
    return CustomTheme(
      id: id,
      name: '日落橙',
      primaryColor: const Color(0xFFFF6F00),
      secondaryColor: const Color(0xFFFFAB00),
      backgroundColor: const Color(0xFFFFF3E0),
      surfaceColor: Colors.white,
      incomeColor: const Color(0xFF00C853),
      expenseColor: const Color(0xFFDD2C00),
      transferColor: const Color(0xFF6200EA),
      textPrimaryColor: const Color(0xFFE65100),
      textSecondaryColor: const Color(0xFFF57C00),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFFFE0B2),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 获取所有预设主题
  static List<CustomTheme> getPresetThemes() {
    return [
      defaultLight(id: 'preset_light'),
      defaultDark(id: 'preset_dark'),
      forestGreen(id: 'preset_forest'),
      sakuraPink(id: 'preset_sakura'),
      oceanBlue(id: 'preset_ocean'),
      nightPurple(id: 'preset_night'),
      sunsetOrange(id: 'preset_sunset'),
    ];
  }
}

/// 可编辑的颜色项
enum ThemeColorType {
  primary,
  secondary,
  background,
  surface,
  income,
  expense,
  transfer,
  textPrimary,
  textSecondary,
  card,
  divider,
}

extension ThemeColorTypeExtension on ThemeColorType {
  String get displayName {
    switch (this) {
      case ThemeColorType.primary:
        return '主色调';
      case ThemeColorType.secondary:
        return '次要色';
      case ThemeColorType.background:
        return '背景色';
      case ThemeColorType.surface:
        return '表面色';
      case ThemeColorType.income:
        return '收入色';
      case ThemeColorType.expense:
        return '支出色';
      case ThemeColorType.transfer:
        return '转账色';
      case ThemeColorType.textPrimary:
        return '主要文字';
      case ThemeColorType.textSecondary:
        return '次要文字';
      case ThemeColorType.card:
        return '卡片背景';
      case ThemeColorType.divider:
        return '分隔线';
    }
  }

  String get description {
    switch (this) {
      case ThemeColorType.primary:
        return '按钮、链接、选中状态的主要颜色';
      case ThemeColorType.secondary:
        return '次要按钮、标签的颜色';
      case ThemeColorType.background:
        return '页面整体背景颜色';
      case ThemeColorType.surface:
        return '卡片、弹窗等表面颜色';
      case ThemeColorType.income:
        return '收入金额显示颜色';
      case ThemeColorType.expense:
        return '支出金额显示颜色';
      case ThemeColorType.transfer:
        return '转账金额显示颜色';
      case ThemeColorType.textPrimary:
        return '标题、重要文字颜色';
      case ThemeColorType.textSecondary:
        return '描述、次要文字颜色';
      case ThemeColorType.card:
        return '卡片组件背景颜色';
      case ThemeColorType.divider:
        return '分隔线、边框颜色';
    }
  }

  Color getColor(CustomTheme theme) {
    switch (this) {
      case ThemeColorType.primary:
        return theme.primaryColor;
      case ThemeColorType.secondary:
        return theme.secondaryColor;
      case ThemeColorType.background:
        return theme.backgroundColor;
      case ThemeColorType.surface:
        return theme.surfaceColor;
      case ThemeColorType.income:
        return theme.incomeColor;
      case ThemeColorType.expense:
        return theme.expenseColor;
      case ThemeColorType.transfer:
        return theme.transferColor;
      case ThemeColorType.textPrimary:
        return theme.textPrimaryColor;
      case ThemeColorType.textSecondary:
        return theme.textSecondaryColor;
      case ThemeColorType.card:
        return theme.cardColor;
      case ThemeColorType.divider:
        return theme.dividerColor;
    }
  }
}
