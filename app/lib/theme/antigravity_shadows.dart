import 'package:flutter/material.dart';

/// 反重力阴影系统 (Antigravity Shadow System)
///
/// L0-L5六级悬浮层级，蓝色调阴影传达轻盈感
/// 设计规范参考：20.2.6.3.1 悬浮卡片系统
class AntigravityShadows {
  AntigravityShadows._();

  /// 矢车菊蓝主色（用于阴影色调）
  static const Color _shadowColor = Color(0xFF6495ED);

  /// L0 - 无阴影（平铺内容）
  static const List<BoxShadow> l0 = [];

  /// L2的零影版本（用于动画过渡，避免负blur radius问题）
  /// 与L2结构相同但完全透明，用于AnimatedContainer动画
  static List<BoxShadow> get l2Zero => [
    const BoxShadow(
      color: Colors.transparent,
      blurRadius: 0,
      spreadRadius: 0,
      offset: Offset.zero,
    ),
    const BoxShadow(
      color: Colors.transparent,
      blurRadius: 0,
      spreadRadius: 0,
      offset: Offset.zero,
    ),
  ];

  /// L1 - 轻微阴影（分割线卡片）
  /// elevation: 1-2dp, blur: 3
  static List<BoxShadow> get l1 => [
    BoxShadow(
      color: _shadowColor.withValues(alpha: 0.08),
      blurRadius: 3,
      spreadRadius: 0,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 2,
      spreadRadius: 0,
      offset: const Offset(0, 1),
    ),
  ];

  /// L2 - 普通阴影（普通卡片）
  /// elevation: 3-4dp, blur: 6
  static List<BoxShadow> get l2 => [
    BoxShadow(
      color: _shadowColor.withValues(alpha: 0.12),
      blurRadius: 6,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 4,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  /// L3 - 中等阴影（悬浮卡片）
  /// elevation: 6-8dp, blur: 12
  static List<BoxShadow> get l3 => [
    BoxShadow(
      color: _shadowColor.withValues(alpha: 0.16),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  /// L4 - 强烈阴影（弹窗/对话框/FAB）
  /// elevation: 12-16dp, blur: 24
  static List<BoxShadow> get l4 => [
    BoxShadow(
      color: _shadowColor.withValues(alpha: 0.20),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 6),
    ),
  ];

  /// L5 - 最强阴影（全屏覆盖层）
  /// elevation: 24dp+, blur: 32
  static List<BoxShadow> get l5 => [
    BoxShadow(
      color: _shadowColor.withValues(alpha: 0.24),
      blurRadius: 48,
      spreadRadius: 4,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      spreadRadius: 0,
      offset: const Offset(0, 12),
    ),
  ];

  /// 根据层级获取阴影
  static List<BoxShadow> getLevel(int level) {
    switch (level) {
      case 0:
        return l0;
      case 1:
        return l1;
      case 2:
        return l2;
      case 3:
        return l3;
      case 4:
        return l4;
      case 5:
        return l5;
      default:
        return l2;
    }
  }
}

/// 反重力阴影装饰器扩展
extension AntigravityShadowDecoration on BoxDecoration {
  /// 应用L1阴影
  BoxDecoration withShadowL1() => copyWith(boxShadow: AntigravityShadows.l1);

  /// 应用L2阴影
  BoxDecoration withShadowL2() => copyWith(boxShadow: AntigravityShadows.l2);

  /// 应用L3阴影
  BoxDecoration withShadowL3() => copyWith(boxShadow: AntigravityShadows.l3);

  /// 应用L4阴影
  BoxDecoration withShadowL4() => copyWith(boxShadow: AntigravityShadows.l4);

  /// 应用L5阴影
  BoxDecoration withShadowL5() => copyWith(boxShadow: AntigravityShadows.l5);
}
