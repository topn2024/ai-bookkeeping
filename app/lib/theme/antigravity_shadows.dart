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
  static const List<BoxShadow> L0 = [];

  /// L1 - 轻微阴影（分割线卡片）
  /// elevation: 1-2dp, blur: 3
  static List<BoxShadow> get L1 => [
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
  static List<BoxShadow> get L2 => [
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
  static List<BoxShadow> get L3 => [
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
  static List<BoxShadow> get L4 => [
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
  static List<BoxShadow> get L5 => [
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
        return L0;
      case 1:
        return L1;
      case 2:
        return L2;
      case 3:
        return L3;
      case 4:
        return L4;
      case 5:
        return L5;
      default:
        return L2;
    }
  }
}

/// 反重力阴影装饰器扩展
extension AntigravityShadowDecoration on BoxDecoration {
  /// 应用L1阴影
  BoxDecoration withShadowL1() => copyWith(boxShadow: AntigravityShadows.L1);

  /// 应用L2阴影
  BoxDecoration withShadowL2() => copyWith(boxShadow: AntigravityShadows.L2);

  /// 应用L3阴影
  BoxDecoration withShadowL3() => copyWith(boxShadow: AntigravityShadows.L3);

  /// 应用L4阴影
  BoxDecoration withShadowL4() => copyWith(boxShadow: AntigravityShadows.L4);

  /// 应用L5阴影
  BoxDecoration withShadowL5() => copyWith(boxShadow: AntigravityShadows.L5);
}
