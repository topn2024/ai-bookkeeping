import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// 引导遮罩画板
///
/// 绘制半透明遮罩，并在目标区域"挖洞"以高亮显示
class GuideMaskPainter extends CustomPainter {
  /// 目标元素的矩形区域
  final Rect? targetRect;

  /// 圆角半径
  final double borderRadius;

  /// 脉冲动画控制器（用于呼吸效果）
  final Animation<double>? pulseAnimation;

  /// 高亮边框颜色
  final Color highlightColor;

  /// 遮罩颜色
  final Color maskColor;

  GuideMaskPainter({
    required this.targetRect,
    this.borderRadius = 16.0,
    this.pulseAnimation,
    this.highlightColor = const Color(0xFF667EEA),
    this.maskColor = const Color(0xBF000000), // 0.75透明度的黑色
  }) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    if (targetRect == null) return;

    // 保存canvas状态
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    // 1. 绘制半透明背景遮罩
    final maskPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      maskPaint,
    );

    // 2. 使用BlendMode.clear在目标区域"挖洞"
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        targetRect!,
        Radius.circular(borderRadius),
      ),
      clearPaint,
    );

    // 恢复canvas状态
    canvas.restore();

    // 3. 绘制高亮边框（带脉冲效果）
    final pulseValue = pulseAnimation?.value ?? 0.0;
    final scale = 1.0 + (pulseValue * 0.02); // 缩放范围：1.0 ~ 1.02
    final opacity = 0.6 + (pulseValue * 0.4); // 透明度范围：0.6 ~ 1.0

    final borderPaint = Paint()
      ..color = highlightColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // 计算缩放后的矩形
    final scaledRect = Rect.fromCenter(
      center: targetRect!.center,
      width: targetRect!.width * scale,
      height: targetRect!.height * scale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect,
        Radius.circular(borderRadius * scale),
      ),
      borderPaint,
    );

    // 4. 绘制外发光效果
    final glowPaint = Paint()
      ..color = highlightColor.withOpacity(opacity * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect,
        Radius.circular(borderRadius * scale),
      ),
      glowPaint,
    );

    // 5. 绘制内发光效果
    final innerGlowPaint = Paint()
      ..color = highlightColor.withOpacity(opacity * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const ui.MaskFilter.blur(BlurStyle.inner, 8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        scaledRect,
        Radius.circular(borderRadius * scale),
      ),
      innerGlowPaint,
    );
  }

  @override
  bool shouldRepaint(GuideMaskPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.maskColor != maskColor;
  }
}
