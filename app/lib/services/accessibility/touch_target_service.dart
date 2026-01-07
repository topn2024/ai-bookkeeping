import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 触控目标尺寸标准
enum TouchTargetStandard {
  /// WCAG 2.1 AA (44x44 CSS像素)
  wcagAA,

  /// WCAG 2.1 AAA (44x44 CSS像素)
  wcagAAA,

  /// Material Design (48x48 dp)
  material,

  /// iOS Human Interface Guidelines (44x44 pt)
  ios,

  /// 自定义
  custom,
}

/// 触控目标分析结果
class TouchTargetAnalysis {
  /// 实际宽度
  final double actualWidth;

  /// 实际高度
  final double actualHeight;

  /// 是否满足最小尺寸
  final bool meetsMinimum;

  /// 是否满足推荐尺寸
  final bool meetsRecommended;

  /// 建议的最小宽度
  final double suggestedWidth;

  /// 建议的最小高度
  final double suggestedHeight;

  /// 问题描述
  final String? issue;

  const TouchTargetAnalysis({
    required this.actualWidth,
    required this.actualHeight,
    required this.meetsMinimum,
    required this.meetsRecommended,
    required this.suggestedWidth,
    required this.suggestedHeight,
    this.issue,
  });
}

/// 触控目标配置
class TouchTargetConfig {
  /// 最小尺寸
  final double minSize;

  /// 推荐尺寸
  final double recommendedSize;

  /// 最小间距
  final double minSpacing;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 触觉反馈类型
  final HapticFeedbackType hapticType;

  const TouchTargetConfig({
    this.minSize = 48.0,
    this.recommendedSize = 56.0,
    this.minSpacing = 8.0,
    this.enableHapticFeedback = true,
    this.hapticType = HapticFeedbackType.light,
  });

  /// WCAG AA 配置
  static const wcagAA = TouchTargetConfig(
    minSize: 44.0,
    recommendedSize: 48.0,
    minSpacing: 8.0,
  );

  /// Material Design 配置
  static const material = TouchTargetConfig(
    minSize: 48.0,
    recommendedSize: 56.0,
    minSpacing: 8.0,
  );

  /// iOS 配置
  static const ios = TouchTargetConfig(
    minSize: 44.0,
    recommendedSize: 44.0,
    minSpacing: 8.0,
  );
}

/// 触觉反馈类型
enum HapticFeedbackType {
  /// 轻触
  light,

  /// 中等
  medium,

  /// 重触
  heavy,

  /// 选择
  selection,

  /// 成功
  success,

  /// 警告
  warning,

  /// 错误
  error,
}

/// 触控目标尺寸服务
/// 确保所有可交互元素满足无障碍触控目标尺寸要求
class TouchTargetService {
  static final TouchTargetService _instance = TouchTargetService._internal();
  factory TouchTargetService() => _instance;
  TouchTargetService._internal();

  /// 当前配置
  TouchTargetConfig _config = const TouchTargetConfig();

  /// 最小触控目标尺寸 (WCAG 2.1 要求 44x44 CSS像素)
  static const double minSize = 48.0;

  /// 推荐触控目标尺寸
  static const double recommendedSize = 56.0;

  /// 获取当前配置
  TouchTargetConfig get config => _config;

  /// 设置配置
  void setConfig(TouchTargetConfig config) {
    _config = config;
  }

  /// 设置标准配置
  void setStandard(TouchTargetStandard standard) {
    switch (standard) {
      case TouchTargetStandard.wcagAA:
      case TouchTargetStandard.wcagAAA:
        _config = TouchTargetConfig.wcagAA;
        break;
      case TouchTargetStandard.material:
        _config = TouchTargetConfig.material;
        break;
      case TouchTargetStandard.ios:
        _config = TouchTargetConfig.ios;
        break;
      case TouchTargetStandard.custom:
        break;
    }
  }

  // ==================== 尺寸检查 ====================

  /// 检查尺寸是否符合标准
  bool isValidSize(double width, double height) {
    return width >= _config.minSize && height >= _config.minSize;
  }

  /// 检查尺寸是否符合推荐标准
  bool isRecommendedSize(double width, double height) {
    return width >= _config.recommendedSize &&
        height >= _config.recommendedSize;
  }

  /// 获取符合标准的最小尺寸
  Size ensureMinSize(Size original) {
    return Size(
      original.width < _config.minSize ? _config.minSize : original.width,
      original.height < _config.minSize ? _config.minSize : original.height,
    );
  }

  /// 获取符合推荐标准的尺寸
  Size ensureRecommendedSize(Size original) {
    return Size(
      original.width < _config.recommendedSize
          ? _config.recommendedSize
          : original.width,
      original.height < _config.recommendedSize
          ? _config.recommendedSize
          : original.height,
    );
  }

  /// 分析触控目标
  TouchTargetAnalysis analyze(double width, double height) {
    final meetsMin = isValidSize(width, height);
    final meetsRec = isRecommendedSize(width, height);

    String? issue;
    if (!meetsMin) {
      if (width < _config.minSize && height < _config.minSize) {
        issue = '宽度和高度都小于最小要求 (${_config.minSize}dp)';
      } else if (width < _config.minSize) {
        issue = '宽度小于最小要求 (${_config.minSize}dp)';
      } else {
        issue = '高度小于最小要求 (${_config.minSize}dp)';
      }
    }

    return TouchTargetAnalysis(
      actualWidth: width,
      actualHeight: height,
      meetsMinimum: meetsMin,
      meetsRecommended: meetsRec,
      suggestedWidth: width < _config.minSize ? _config.minSize : width,
      suggestedHeight: height < _config.minSize ? _config.minSize : height,
      issue: issue,
    );
  }

  // ==================== 间距检查 ====================

  /// 检查两个触控目标之间的间距是否足够
  bool hasAdequateSpacing(Rect target1, Rect target2) {
    final horizontalGap = (target1.left - target2.right).abs();
    final verticalGap = (target1.top - target2.bottom).abs();

    // 检查是否有重叠
    if (target1.overlaps(target2)) {
      return false;
    }

    // 检查间距
    if (horizontalGap < _config.minSpacing &&
        verticalGap < _config.minSpacing) {
      return false;
    }

    return true;
  }

  /// 计算两个触控目标之间的最小间距
  double calculateSpacing(Rect target1, Rect target2) {
    if (target1.overlaps(target2)) {
      return 0;
    }

    final horizontalGap = target1.left > target2.right
        ? target1.left - target2.right
        : target2.left - target1.right;

    final verticalGap = target1.top > target2.bottom
        ? target1.top - target2.bottom
        : target2.top - target1.bottom;

    if (horizontalGap > 0 && verticalGap > 0) {
      return horizontalGap < verticalGap ? horizontalGap : verticalGap;
    }

    return horizontalGap > 0 ? horizontalGap : verticalGap;
  }

  // ==================== 触觉反馈 ====================

  /// 触发触觉反馈
  Future<void> triggerHapticFeedback([HapticFeedbackType? type]) async {
    if (!_config.enableHapticFeedback) return;

    final feedbackType = type ?? _config.hapticType;

    switch (feedbackType) {
      case HapticFeedbackType.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        await HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.success:
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.warning:
        await HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.error:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        break;
    }
  }

  // ==================== 辅助方法 ====================

  /// 获取标准名称
  String getStandardName(TouchTargetStandard standard) {
    switch (standard) {
      case TouchTargetStandard.wcagAA:
        return 'WCAG 2.1 AA';
      case TouchTargetStandard.wcagAAA:
        return 'WCAG 2.1 AAA';
      case TouchTargetStandard.material:
        return 'Material Design';
      case TouchTargetStandard.ios:
        return 'iOS HIG';
      case TouchTargetStandard.custom:
        return '自定义';
    }
  }

  /// 获取当前最小尺寸
  double get currentMinSize => _config.minSize;

  /// 获取当前推荐尺寸
  double get currentRecommendedSize => _config.recommendedSize;

  /// 获取当前最小间距
  double get currentMinSpacing => _config.minSpacing;
}

/// 触控目标包装组件
class TouchTargetWrapper extends StatelessWidget {
  final Widget child;
  final double? minWidth;
  final double? minHeight;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableHapticFeedback;
  final HapticFeedbackType hapticType;
  final String? semanticLabel;

  const TouchTargetWrapper({
    super.key,
    required this.child,
    this.minWidth,
    this.minHeight,
    this.onTap,
    this.onLongPress,
    this.enableHapticFeedback = true,
    this.hapticType = HapticFeedbackType.light,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final service = TouchTargetService();
    final effectiveMinWidth = minWidth ?? service.currentMinSize;
    final effectiveMinHeight = minHeight ?? service.currentMinSize;

    Widget result = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: effectiveMinWidth,
        minHeight: effectiveMinHeight,
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      result = GestureDetector(
        onTap: () {
          if (enableHapticFeedback) {
            service.triggerHapticFeedback(hapticType);
          }
          onTap?.call();
        },
        onLongPress: () {
          if (enableHapticFeedback) {
            service.triggerHapticFeedback(HapticFeedbackType.heavy);
          }
          onLongPress?.call();
        },
        child: result,
      );
    }

    if (semanticLabel != null) {
      result = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: result,
      );
    }

    return result;
  }
}

/// 可访问按钮组件
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final String? semanticHint;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;

  const AccessibleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.semanticHint,
    this.enabled = true,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final service = TouchTargetService();
    final theme = Theme.of(context);

    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      enabled: enabled,
      child: Material(
        color: backgroundColor ?? theme.colorScheme.primary,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled
              ? () {
                  service.triggerHapticFeedback(HapticFeedbackType.light);
                  onPressed?.call();
                }
              : null,
          onLongPress: enabled
              ? () {
                  service.triggerHapticFeedback(HapticFeedbackType.heavy);
                  onLongPress?.call();
                }
              : null,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: service.currentMinSize,
              minHeight: service.currentMinSize,
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: foregroundColor ?? theme.colorScheme.onPrimary,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: foregroundColor ?? theme.colorScheme.onPrimary,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 可访问图标按钮组件
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double? size;
  final Color? color;
  final Color? backgroundColor;
  final bool enabled;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.size,
    this.color,
    this.backgroundColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final service = TouchTargetService();
    final theme = Theme.of(context);
    final iconSize = size ?? 24.0;

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled
              ? () {
                  service.triggerHapticFeedback(HapticFeedbackType.light);
                  onPressed?.call();
                }
              : null,
          customBorder: const CircleBorder(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: service.currentMinSize,
              minHeight: service.currentMinSize,
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: enabled
                    ? (color ?? theme.iconTheme.color)
                    : theme.disabledColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
