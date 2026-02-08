import 'dart:math';
import 'package:flutter/material.dart';

/// WCAG 对比度等级
enum ContrastLevel {
  /// AA级 - 普通文本4.5:1，大文本3:1
  aa,

  /// AAA级 - 普通文本7:1，大文本4.5:1
  aaa,
}

/// 色盲类型
enum ColorBlindnessType {
  /// 正常视觉
  normal,

  /// 红色盲 (Protanopia)
  protanopia,

  /// 绿色盲 (Deuteranopia)
  deuteranopia,

  /// 蓝色盲 (Tritanopia)
  tritanopia,

  /// 红色弱 (Protanomaly)
  protanomaly,

  /// 绿色弱 (Deuteranomaly)
  deuteranomaly,

  /// 蓝色弱 (Tritanomaly)
  tritanomaly,

  /// 全色盲 (Achromatopsia)
  achromatopsia,
}

/// 色彩建议结果
class ColorSuggestion {
  /// 建议的前景色
  final Color foregroundColor;

  /// 建议的背景色
  final Color backgroundColor;

  /// 对比度
  final double contrastRatio;

  /// 是否满足AA级
  final bool meetsAA;

  /// 是否满足AAA级
  final bool meetsAAA;

  /// 是否大文本
  final bool isLargeText;

  const ColorSuggestion({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.contrastRatio,
    required this.meetsAA,
    required this.meetsAAA,
    required this.isLargeText,
  });
}

/// 色彩无障碍分析结果
class ColorAccessibilityResult {
  /// 原始前景色
  final Color originalForeground;

  /// 原始背景色
  final Color originalBackground;

  /// 对比度
  final double contrastRatio;

  /// 是否满足AA级
  final bool meetsAA;

  /// 是否满足AAA级
  final bool meetsAAA;

  /// 各类色盲下的可见性评分（0-1）
  final Map<ColorBlindnessType, double> colorBlindnessScores;

  /// 改进建议
  final List<ColorSuggestion> suggestions;

  const ColorAccessibilityResult({
    required this.originalForeground,
    required this.originalBackground,
    required this.contrastRatio,
    required this.meetsAA,
    required this.meetsAAA,
    required this.colorBlindnessScores,
    required this.suggestions,
  });

  /// 总体评分（0-100）
  int get overallScore {
    int score = 0;

    // 对比度评分（最高50分）
    if (meetsAAA) {
      score += 50;
    } else if (meetsAA) {
      score += 35;
    } else if (contrastRatio >= 3.0) {
      score += 20;
    }

    // 色盲友好评分（最高50分）
    final avgColorBlindScore = colorBlindnessScores.values.isEmpty
        ? 0.0
        : colorBlindnessScores.values.reduce((a, b) => a + b) /
            colorBlindnessScores.length;
    score += (avgColorBlindScore * 50).round();

    return score;
  }
}

/// 色彩对比度服务
/// 提供WCAG合规的色彩对比度检测和建议，支持色盲友好模式
class AccessibleColorService {
  static final AccessibleColorService _instance =
      AccessibleColorService._internal();
  factory AccessibleColorService() => _instance;
  AccessibleColorService._internal();

  /// 当前模拟的色盲类型
  ColorBlindnessType _simulatedColorBlindness = ColorBlindnessType.normal;

  /// 是否启用色盲模拟
  bool _colorBlindnessSimulationEnabled = false;

  /// 获取当前模拟的色盲类型
  ColorBlindnessType get simulatedColorBlindness => _simulatedColorBlindness;

  /// 获取是否启用色盲模拟
  bool get colorBlindnessSimulationEnabled => _colorBlindnessSimulationEnabled;

  /// 设置色盲模拟
  void setColorBlindnessSimulation(ColorBlindnessType type, {bool enabled = true}) {
    _simulatedColorBlindness = type;
    _colorBlindnessSimulationEnabled = enabled && type != ColorBlindnessType.normal;
  }

  // ==================== 对比度计算 ====================

  /// 计算相对亮度
  double relativeLuminance(Color color) {
    double r = color.red / 255;
    double g = color.green / 255;
    double b = color.blue / 255;

    r = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4).toDouble();
    g = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4).toDouble();
    b = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 计算对比度
  double contrastRatio(Color foreground, Color background) {
    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);
    final lighter = max(l1, l2);
    final darker = min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 检查是否满足WCAG标准
  bool meetsWCAG(
    Color foreground,
    Color background, {
    bool isLargeText = false,
    ContrastLevel level = ContrastLevel.aa,
  }) {
    final ratio = contrastRatio(foreground, background);

    if (level == ContrastLevel.aaa) {
      return isLargeText ? ratio >= 4.5 : ratio >= 7.0;
    }
    return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
  }

  /// 获取WCAG合规所需的最小对比度
  double getMinimumContrastRatio({
    bool isLargeText = false,
    ContrastLevel level = ContrastLevel.aa,
  }) {
    if (level == ContrastLevel.aaa) {
      return isLargeText ? 4.5 : 7.0;
    }
    return isLargeText ? 3.0 : 4.5;
  }

  // ==================== 色彩建议 ====================

  /// 调整颜色以满足对比度要求
  Color adjustForContrast(
    Color foreground,
    Color background, {
    double minRatio = 4.5,
    bool preferDarker = true,
  }) {
    final currentRatio = contrastRatio(foreground, background);
    if (currentRatio >= minRatio) {
      return foreground;
    }

    final bgLuminance = relativeLuminance(background);

    // 根据背景亮度决定调整方向
    if (bgLuminance > 0.5) {
      // 背景较亮，使前景更深
      return _darkenUntilContrast(foreground, background, minRatio);
    } else {
      // 背景较暗，使前景更亮
      return _lightenUntilContrast(foreground, background, minRatio);
    }
  }

  /// 加深颜色直到达到对比度要求
  Color _darkenUntilContrast(Color color, Color background, double minRatio) {
    Color current = color;
    for (int i = 0; i < 100; i++) {
      if (contrastRatio(current, background) >= minRatio) {
        return current;
      }
      current = Color.fromARGB(
        current.alpha,
        (current.red * 0.95).round().clamp(0, 255),
        (current.green * 0.95).round().clamp(0, 255),
        (current.blue * 0.95).round().clamp(0, 255),
      );
    }
    return Colors.black;
  }

  /// 变亮颜色直到达到对比度要求
  Color _lightenUntilContrast(Color color, Color background, double minRatio) {
    Color current = color;
    for (int i = 0; i < 100; i++) {
      if (contrastRatio(current, background) >= minRatio) {
        return current;
      }
      current = Color.fromARGB(
        current.alpha,
        (current.red + (255 - current.red) * 0.05).round().clamp(0, 255),
        (current.green + (255 - current.green) * 0.05).round().clamp(0, 255),
        (current.blue + (255 - current.blue) * 0.05).round().clamp(0, 255),
      );
    }
    return Colors.white;
  }

  /// 获取最佳前景色（黑色或白色）
  Color getBestForegroundColor(Color background) {
    final luminance = relativeLuminance(background);
    return luminance > 0.179 ? Colors.black : Colors.white;
  }

  /// 生成满足对比度的颜色组合
  List<ColorSuggestion> generateAccessiblePalette(
    Color baseColor, {
    int count = 5,
    bool isLargeText = false,
  }) {
    final suggestions = <ColorSuggestion>[];
    final minRatioAA = isLargeText ? 3.0 : 4.5;
    final minRatioAAA = isLargeText ? 4.5 : 7.0;

    // 白色背景
    final onWhite = adjustForContrast(baseColor, Colors.white, minRatio: minRatioAA);
    final whiteRatio = contrastRatio(onWhite, Colors.white);
    suggestions.add(ColorSuggestion(
      foregroundColor: onWhite,
      backgroundColor: Colors.white,
      contrastRatio: whiteRatio,
      meetsAA: whiteRatio >= minRatioAA,
      meetsAAA: whiteRatio >= minRatioAAA,
      isLargeText: isLargeText,
    ));

    // 黑色背景
    final onBlack = adjustForContrast(baseColor, Colors.black, minRatio: minRatioAA);
    final blackRatio = contrastRatio(onBlack, Colors.black);
    suggestions.add(ColorSuggestion(
      foregroundColor: onBlack,
      backgroundColor: Colors.black,
      contrastRatio: blackRatio,
      meetsAA: blackRatio >= minRatioAA,
      meetsAAA: blackRatio >= minRatioAAA,
      isLargeText: isLargeText,
    ));

    // 浅灰背景
    const lightGray = Color(0xFFF5F5F5);
    final onLightGray = adjustForContrast(baseColor, lightGray, minRatio: minRatioAA);
    final lightGrayRatio = contrastRatio(onLightGray, lightGray);
    suggestions.add(ColorSuggestion(
      foregroundColor: onLightGray,
      backgroundColor: lightGray,
      contrastRatio: lightGrayRatio,
      meetsAA: lightGrayRatio >= minRatioAA,
      meetsAAA: lightGrayRatio >= minRatioAAA,
      isLargeText: isLargeText,
    ));

    // 深灰背景
    const darkGray = Color(0xFF212121);
    final onDarkGray = adjustForContrast(baseColor, darkGray, minRatio: minRatioAA);
    final darkGrayRatio = contrastRatio(onDarkGray, darkGray);
    suggestions.add(ColorSuggestion(
      foregroundColor: onDarkGray,
      backgroundColor: darkGray,
      contrastRatio: darkGrayRatio,
      meetsAA: darkGrayRatio >= minRatioAA,
      meetsAAA: darkGrayRatio >= minRatioAAA,
      isLargeText: isLargeText,
    ));

    // 基色作为背景
    final onBase = getBestForegroundColor(baseColor);
    final baseRatio = contrastRatio(onBase, baseColor);
    suggestions.add(ColorSuggestion(
      foregroundColor: onBase,
      backgroundColor: baseColor,
      contrastRatio: baseRatio,
      meetsAA: baseRatio >= minRatioAA,
      meetsAAA: baseRatio >= minRatioAAA,
      isLargeText: isLargeText,
    ));

    return suggestions;
  }

  // ==================== 色盲模拟 ====================

  /// 模拟色盲视觉
  Color simulateColorBlindness(Color color, ColorBlindnessType type) {
    if (type == ColorBlindnessType.normal) {
      return color;
    }

    // 将RGB转换为线性空间
    double r = color.red / 255;
    double g = color.green / 255;
    double b = color.blue / 255;

    // 应用色盲转换矩阵
    final matrix = _getColorBlindnessMatrix(type);
    final newR = (matrix[0][0] * r + matrix[0][1] * g + matrix[0][2] * b).clamp(0.0, 1.0);
    final newG = (matrix[1][0] * r + matrix[1][1] * g + matrix[1][2] * b).clamp(0.0, 1.0);
    final newB = (matrix[2][0] * r + matrix[2][1] * g + matrix[2][2] * b).clamp(0.0, 1.0);

    return Color.fromARGB(
      color.alpha,
      (newR * 255).round(),
      (newG * 255).round(),
      (newB * 255).round(),
    );
  }

  /// 获取色盲转换矩阵
  List<List<double>> _getColorBlindnessMatrix(ColorBlindnessType type) {
    switch (type) {
      case ColorBlindnessType.protanopia:
        return [
          [0.567, 0.433, 0.0],
          [0.558, 0.442, 0.0],
          [0.0, 0.242, 0.758],
        ];
      case ColorBlindnessType.deuteranopia:
        return [
          [0.625, 0.375, 0.0],
          [0.7, 0.3, 0.0],
          [0.0, 0.3, 0.7],
        ];
      case ColorBlindnessType.tritanopia:
        return [
          [0.95, 0.05, 0.0],
          [0.0, 0.433, 0.567],
          [0.0, 0.475, 0.525],
        ];
      case ColorBlindnessType.protanomaly:
        return [
          [0.817, 0.183, 0.0],
          [0.333, 0.667, 0.0],
          [0.0, 0.125, 0.875],
        ];
      case ColorBlindnessType.deuteranomaly:
        return [
          [0.8, 0.2, 0.0],
          [0.258, 0.742, 0.0],
          [0.0, 0.142, 0.858],
        ];
      case ColorBlindnessType.tritanomaly:
        return [
          [0.967, 0.033, 0.0],
          [0.0, 0.733, 0.267],
          [0.0, 0.183, 0.817],
        ];
      case ColorBlindnessType.achromatopsia:
        return [
          [0.299, 0.587, 0.114],
          [0.299, 0.587, 0.114],
          [0.299, 0.587, 0.114],
        ];
      case ColorBlindnessType.normal:
        return [
          [1.0, 0.0, 0.0],
          [0.0, 1.0, 0.0],
          [0.0, 0.0, 1.0],
        ];
    }
  }

  /// 评估颜色对色盲用户的可见性
  double evaluateColorBlindnessVisibility(
    Color foreground,
    Color background,
    ColorBlindnessType type,
  ) {
    final simFg = simulateColorBlindness(foreground, type);
    final simBg = simulateColorBlindness(background, type);
    final ratio = contrastRatio(simFg, simBg);

    // 归一化为0-1的评分
    if (ratio >= 7.0) return 1.0;
    if (ratio >= 4.5) return 0.8;
    if (ratio >= 3.0) return 0.6;
    if (ratio >= 2.0) return 0.4;
    return ratio / 5.0;
  }

  // ==================== 完整分析 ====================

  /// 执行完整的色彩无障碍分析
  ColorAccessibilityResult analyzeColors(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final ratio = contrastRatio(foreground, background);
    final minAA = isLargeText ? 3.0 : 4.5;
    final minAAA = isLargeText ? 4.5 : 7.0;

    // 评估色盲可见性
    final colorBlindnessScores = <ColorBlindnessType, double>{};
    for (final type in ColorBlindnessType.values) {
      if (type != ColorBlindnessType.normal) {
        colorBlindnessScores[type] =
            evaluateColorBlindnessVisibility(foreground, background, type);
      }
    }

    // 生成建议
    final suggestions = <ColorSuggestion>[];
    if (ratio < minAA) {
      final adjusted = adjustForContrast(foreground, background, minRatio: minAA);
      final adjustedRatio = contrastRatio(adjusted, background);
      suggestions.add(ColorSuggestion(
        foregroundColor: adjusted,
        backgroundColor: background,
        contrastRatio: adjustedRatio,
        meetsAA: adjustedRatio >= minAA,
        meetsAAA: adjustedRatio >= minAAA,
        isLargeText: isLargeText,
      ));
    }

    return ColorAccessibilityResult(
      originalForeground: foreground,
      originalBackground: background,
      contrastRatio: ratio,
      meetsAA: ratio >= minAA,
      meetsAAA: ratio >= minAAA,
      colorBlindnessScores: colorBlindnessScores,
      suggestions: suggestions,
    );
  }

  // ==================== 辅助方法 ====================

  /// 获取色盲类型名称
  String getColorBlindnessName(ColorBlindnessType type) {
    switch (type) {
      case ColorBlindnessType.normal:
        return '正常视觉';
      case ColorBlindnessType.protanopia:
        return '红色盲';
      case ColorBlindnessType.deuteranopia:
        return '绿色盲';
      case ColorBlindnessType.tritanopia:
        return '蓝色盲';
      case ColorBlindnessType.protanomaly:
        return '红色弱';
      case ColorBlindnessType.deuteranomaly:
        return '绿色弱';
      case ColorBlindnessType.tritanomaly:
        return '蓝色弱';
      case ColorBlindnessType.achromatopsia:
        return '全色盲';
    }
  }

  /// 获取对比度评级
  String getContrastRating(double ratio, {bool isLargeText = false}) {
    final minAA = isLargeText ? 3.0 : 4.5;
    final minAAA = isLargeText ? 4.5 : 7.0;

    if (ratio >= minAAA) {
      return 'AAA (${ratio.toStringAsFixed(2)}:1)';
    } else if (ratio >= minAA) {
      return 'AA (${ratio.toStringAsFixed(2)}:1)';
    } else if (ratio >= 3.0) {
      return '大文本AA (${ratio.toStringAsFixed(2)}:1)';
    } else {
      return '不合规 (${ratio.toStringAsFixed(2)}:1)';
    }
  }
}

/// 色盲模拟滤镜组件
class ColorBlindnessFilter extends StatelessWidget {
  final Widget child;
  final ColorBlindnessType type;

  const ColorBlindnessFilter({
    super.key,
    required this.child,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    if (type == ColorBlindnessType.normal) {
      return child;
    }

    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_getFilterMatrix(type)),
      child: child,
    );
  }

  List<double> _getFilterMatrix(ColorBlindnessType type) {
    final service = AccessibleColorService();
    final matrix = service._getColorBlindnessMatrix(type);

    return [
      matrix[0][0], matrix[0][1], matrix[0][2], 0, 0,
      matrix[1][0], matrix[1][1], matrix[1][2], 0, 0,
      matrix[2][0], matrix[2][1], matrix[2][2], 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}
