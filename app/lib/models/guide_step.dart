import 'package:flutter/material.dart';

/// 引导提示卡片位置
enum GuidePosition {
  /// 在目标元素上方
  top,

  /// 在目标元素下方
  bottom,

  /// 在目标元素左侧
  left,

  /// 在目标元素右侧
  right,

  /// 屏幕中央（用于整体区域引导）
  center,

  /// 自定义位置
  custom,
}

/// 引导步骤模型
class GuideStep {
  /// 步骤唯一标识（用于记录是否已显示）
  final String id;

  /// 目标元素的GlobalKey
  final GlobalKey targetKey;

  /// 引导标题
  final String title;

  /// 引导说明文字
  final String description;

  /// 提示卡片位置
  final GuidePosition position;

  /// 自定义偏移量（用于微调卡片位置）
  final Offset? customOffset;

  /// 高亮区域的padding（增加高亮范围）
  final double targetPadding;

  /// 是否显示脉冲动画
  final bool enablePulse;

  /// 高亮区域的圆角
  final double borderRadius;

  const GuideStep({
    required this.id,
    required this.targetKey,
    required this.title,
    required this.description,
    this.position = GuidePosition.bottom,
    this.customOffset,
    this.targetPadding = 8.0,
    this.enablePulse = true,
    this.borderRadius = 16.0,
  });

  /// 复制并修改部分属性
  GuideStep copyWith({
    String? id,
    GlobalKey? targetKey,
    String? title,
    String? description,
    GuidePosition? position,
    Offset? customOffset,
    double? targetPadding,
    bool? enablePulse,
    double? borderRadius,
  }) {
    return GuideStep(
      id: id ?? this.id,
      targetKey: targetKey ?? this.targetKey,
      title: title ?? this.title,
      description: description ?? this.description,
      position: position ?? this.position,
      customOffset: customOffset ?? this.customOffset,
      targetPadding: targetPadding ?? this.targetPadding,
      enablePulse: enablePulse ?? this.enablePulse,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}
