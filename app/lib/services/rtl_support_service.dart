import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// RTL（从右到左）布局支持服务
///
/// 提供 RTL 语言的布局适配功能
/// 目前支持的 RTL 语言: 阿拉伯语(ar)、希伯来语(he)、波斯语(fa)、乌尔都语(ur)
class RTLSupportService {
  RTLSupportService._();
  static final RTLSupportService instance = RTLSupportService._();

  /// RTL 语言代码列表
  static const Set<String> rtlLanguageCodes = {
    'ar', // 阿拉伯语
    'he', // 希伯来语
    'fa', // 波斯语
    'ur', // 乌尔都语
    'yi', // 意第绪语
    'ps', // 普什图语
    'sd', // 信德语
    'ug', // 维吾尔语
  };

  /// 检查语言是否是 RTL 语言
  static bool isRTLLanguage(AppLanguage language) {
    // 当前支持的语言都是 LTR
    // 为将来扩展预留
    return false;
  }

  /// 检查 Locale 是否是 RTL
  static bool isRTLLocale(Locale locale) {
    return rtlLanguageCodes.contains(locale.languageCode);
  }

  /// 获取文本方向
  static TextDirection getTextDirection(AppLanguage language) {
    return isRTLLanguage(language) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// 获取 Locale 的文本方向
  static TextDirection getTextDirectionForLocale(Locale locale) {
    return isRTLLocale(locale) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// 根据 RTL 状态翻转水平方向
  static double flipHorizontal(double value, bool isRTL) {
    return isRTL ? -value : value;
  }

  /// 根据 RTL 状态获取开始边距
  static EdgeInsetsDirectional paddingStart(double value) {
    return EdgeInsetsDirectional.only(start: value);
  }

  /// 根据 RTL 状态获取结束边距
  static EdgeInsetsDirectional paddingEnd(double value) {
    return EdgeInsetsDirectional.only(end: value);
  }

  /// 根据 RTL 状态获取水平边距
  static EdgeInsetsDirectional paddingHorizontal(double start, double end) {
    return EdgeInsetsDirectional.only(start: start, end: end);
  }

  /// 获取对齐方式 - 开始
  static AlignmentDirectional get alignStart => AlignmentDirectional.centerStart;

  /// 获取对齐方式 - 结束
  static AlignmentDirectional get alignEnd => AlignmentDirectional.centerEnd;
}

/// RTL 感知的组件扩展
extension RTLAwareContext on BuildContext {
  /// 当前是否为 RTL 布局
  bool get isRTL => Directionality.of(this) == TextDirection.rtl;

  /// 获取当前文本方向
  TextDirection get textDirection => Directionality.of(this);

  /// 根据 RTL 状态获取开始方向图标
  IconData get startIcon => isRTL ? Icons.arrow_forward : Icons.arrow_back;

  /// 根据 RTL 状态获取结束方向图标
  IconData get endIcon => isRTL ? Icons.arrow_back : Icons.arrow_forward;

  /// 根据 RTL 状态获取左边方向图标
  IconData get leftArrowIcon =>
      isRTL ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_left;

  /// 根据 RTL 状态获取右边方向图标
  IconData get rightArrowIcon =>
      isRTL ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_right;
}

/// RTL 感知的 Row 组件
class DirectionalRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const DirectionalRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      textDirection: Directionality.of(context),
      children: children,
    );
  }
}

/// RTL 感知的 Padding 组件
class DirectionalPadding extends StatelessWidget {
  final Widget child;
  final double start;
  final double end;
  final double top;
  final double bottom;

  const DirectionalPadding({
    super.key,
    required this.child,
    this.start = 0,
    this.end = 0,
    this.top = 0,
    this.bottom = 0,
  });

  factory DirectionalPadding.horizontal({
    Key? key,
    required Widget child,
    required double start,
    required double end,
  }) {
    return DirectionalPadding(
      key: key,
      start: start,
      end: end,
      child: child,
    );
  }

  factory DirectionalPadding.symmetric({
    Key? key,
    required Widget child,
    double horizontal = 0,
    double vertical = 0,
  }) {
    return DirectionalPadding(
      key: key,
      start: horizontal,
      end: horizontal,
      top: vertical,
      bottom: vertical,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: start,
        end: end,
        top: top,
        bottom: bottom,
      ),
      child: child,
    );
  }
}

/// RTL 感知的 Container 组件
class DirectionalContainer extends StatelessWidget {
  final Widget? child;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;
  final double? width;
  final double? height;
  final Color? color;

  const DirectionalContainer({
    super.key,
    this.child,
    this.alignment,
    this.padding,
    this.margin,
    this.decoration,
    this.width,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: padding,
      margin: margin,
      decoration: decoration,
      width: width,
      height: height,
      color: color,
      child: child,
    );
  }
}

/// RTL 感知的 Positioned 组件
class DirectionalPositioned extends StatelessWidget {
  final Widget child;
  final double? start;
  final double? end;
  final double? top;
  final double? bottom;
  final double? width;
  final double? height;

  const DirectionalPositioned({
    super.key,
    required this.child,
    this.start,
    this.end,
    this.top,
    this.bottom,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: start,
      end: end,
      top: top,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );
  }
}

/// RTL 感知的图标翻转组件
class DirectionalIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final bool flipInRTL;

  const DirectionalIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.flipInRTL = false,
  });

  @override
  Widget build(BuildContext context) {
    final isRTL = context.isRTL;

    Widget iconWidget = Icon(
      icon,
      size: size,
      color: color,
    );

    if (flipInRTL && isRTL) {
      iconWidget = Transform.scale(
        scaleX: -1,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}

/// 使 ListTile 支持 RTL
class DirectionalListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool selected;
  final EdgeInsetsGeometry? contentPadding;

  const DirectionalListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.selected = false,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      enabled: enabled,
      selected: selected,
      contentPadding: contentPadding,
    );
  }
}
