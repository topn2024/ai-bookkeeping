import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ui_mode_provider.dart';

/// 响应式文本组件
///
/// 根据UI模式自动调整字体大小
class ResponsiveText extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSimple = ref.watch(isSimpleModeProvider);
    final baseStyle = style ?? const TextStyle();

    // 简易模式下字体放大1.5倍
    final fontSize = (baseStyle.fontSize ?? 14) * (isSimple ? 1.5 : 1.0);

    return Text(
      text,
      style: baseStyle.copyWith(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 响应式按钮组件
///
/// 根据UI模式自动调整按钮大小
class ResponsiveButton extends ConsumerWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;

  const ResponsiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSimple = ref.watch(isSimpleModeProvider);

    // 简易模式：更大的按钮，更大的字体
    final buttonHeight = isSimple ? 64.0 : 48.0;
    final fontSize = isSimple ? 20.0 : 16.0;
    final iconSize = isSimple ? 32.0 : 24.0;

    return SizedBox(
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(
            horizontal: isSimple ? 32 : 24,
            vertical: isSimple ? 16 : 12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: iconSize),
              SizedBox(width: isSimple ? 12 : 8),
            ],
            Text(
              text,
              style: TextStyle(fontSize: fontSize),
            ),
          ],
        ),
      ),
    );
  }
}

/// 响应式输入框组件
class ResponsiveTextField extends ConsumerWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const ResponsiveTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSimple = ref.watch(isSimpleModeProvider);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(fontSize: isSimple ? 24 : 16),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(fontSize: isSimple ? 20 : 16),
        hintStyle: TextStyle(fontSize: isSimple ? 20 : 14),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSimple ? 20 : 16,
          vertical: isSimple ? 20 : 16,
        ),
      ),
    );
  }
}

/// 响应式间距
class ResponsiveSpacing {
  final WidgetRef ref;

  ResponsiveSpacing(this.ref);

  bool get isSimple => ref.watch(isSimpleModeProvider);

  double get small => isSimple ? 12 : 8;
  double get medium => isSimple ? 24 : 16;
  double get large => isSimple ? 36 : 24;
  double get xlarge => isSimple ? 48 : 32;
}

/// 响应式布局辅助类
class ResponsiveLayout {
  final WidgetRef ref;

  ResponsiveLayout(this.ref);

  bool get isSimple => ref.watch(isSimpleModeProvider);

  /// 获取响应式字体大小
  double fontSize(double baseSize) => baseSize * (isSimple ? 1.5 : 1.0);

  /// 获取响应式图标大小
  double iconSize(double baseSize) => baseSize * (isSimple ? 1.3 : 1.0);

  /// 获取响应式间距
  double spacing(double baseSpacing) => baseSpacing * (isSimple ? 1.5 : 1.0);

  /// 获取响应式按钮高度
  double buttonHeight() => isSimple ? 64.0 : 48.0;

  /// 获取响应式卡片内边距
  EdgeInsets cardPadding() => EdgeInsets.all(isSimple ? 20 : 16);
}
