import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../theme/antigravity_shadows.dart';

/// 反重力布局组件 (Antigravity Layout Components)
///
/// 包含：StickyBottomBar、FloatingIslandLayout 等布局组件
/// 设计规范参考：20.2.6.2 布局反重力规范

/// 固定底部操作栏 (Sticky Bottom Bar)
///
/// 表单确认按钮固定在底部，符合拇指热区原则
/// 设计规范参考：20.2.6.2.1 核心操作下沉清单
class StickyBottomBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool showDivider;
  final bool enableGlass;
  final List<BoxShadow>? boxShadow;

  const StickyBottomBar({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.showDivider = true,
    this.enableGlass = false,
    this.boxShadow,
  });

  /// 单按钮模式
  factory StickyBottomBar.singleButton({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    Color? buttonColor,
    EdgeInsetsGeometry? padding,
  }) {
    return StickyBottomBar(
      key: key,
      padding: padding ?? const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }

  /// 双按钮模式（取消 + 确认）
  factory StickyBottomBar.twoButtons({
    Key? key,
    required String cancelLabel,
    required String confirmLabel,
    required VoidCallback? onCancel,
    required VoidCallback? onConfirm,
    bool isLoading = false,
    Color? confirmColor,
    EdgeInsetsGeometry? padding,
  }) {
    return StickyBottomBar(
      key: key,
      padding: padding ?? const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(cancelLabel),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(confirmLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface;

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enableGlass ? bgColor.withValues(alpha: 0.88) : bgColor,
        border: showDivider
            ? Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              )
            : null,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: const Color(0xFF6495ED).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
      ),
      child: SafeArea(
        top: false,
        child: child,
      ),
    );

    if (enableGlass) {
      content = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// 浮岛式布局容器 (Floating Island Layout)
///
/// 每个浮岛有独立的内边距和圆角，浮岛之间保持充足间距
/// 设计规范参考：20.2.6.3.2 浮岛式布局
class FloatingIslandLayout extends StatelessWidget {
  final List<FloatingIsland> islands;
  final EdgeInsetsGeometry? padding;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  const FloatingIslandLayout({
    super.key,
    required this.islands,
    this.padding,
    this.spacing = 16.0,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (int i = 0; i < islands.length; i++) ...[
            islands[i],
            if (i < islands.length - 1) SizedBox(height: spacing),
          ],
        ],
      ),
    );
  }
}

/// 浮岛组件 (Floating Island)
///
/// 独立的悬浮内容区块
class FloatingIsland extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final int shadowLevel;
  final Color? backgroundColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const FloatingIsland({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16.0,
    this.shadowLevel = 2,
    this.backgroundColor,
    this.gradient,
    this.onTap,
  });

  /// 玻璃态浮岛
  factory FloatingIsland.glass({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 16.0,
    VoidCallback? onTap,
  }) {
    return _GlassFloatingIsland(
      key: key,
      padding: padding,
      borderRadius: borderRadius,
      onTap: onTap,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface;

    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradient == null ? bgColor : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AntigravityShadows.getLevel(shadowLevel),
      ),
      child: child,
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

class _GlassFloatingIsland extends FloatingIsland {
  const _GlassFloatingIsland({
    super.key,
    required super.child,
    super.padding,
    super.borderRadius = 16.0,
    super.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: AntigravityShadows.L3,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// 气泡上升效果 (Bubble Rise Effect)
///
/// 气泡从底部生成，缓慢上升并逐渐消散
/// 设计规范参考：20.2.6.4.1 气泡/粒子上升
class BubbleRiseEffect extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final int bubbleCount;
  final Color bubbleColor;
  final double maxBubbleSize;
  final double minBubbleSize;

  const BubbleRiseEffect({
    super.key,
    required this.child,
    this.isActive = true,
    this.bubbleCount = 20,
    this.bubbleColor = const Color(0xFF6495ED),
    this.maxBubbleSize = 8.0,
    this.minBubbleSize = 2.0,
  });

  @override
  State<BubbleRiseEffect> createState() => _BubbleRiseEffectState();
}

class _BubbleRiseEffectState extends State<BubbleRiseEffect>
    with TickerProviderStateMixin {
  late List<_Bubble> _bubbles;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _initBubbles();

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  void _initBubbles() {
    final random = math.Random();
    _bubbles = List.generate(widget.bubbleCount, (_) {
      return _Bubble(
        x: random.nextDouble(),
        startY: 1.0 + random.nextDouble() * 0.5,
        size: widget.minBubbleSize +
            random.nextDouble() * (widget.maxBubbleSize - widget.minBubbleSize),
        speed: 0.3 + random.nextDouble() * 0.7,
        wobble: random.nextDouble() * 0.02,
        wobbleSpeed: 1 + random.nextDouble() * 2,
        delay: random.nextDouble(),
      );
    });
  }

  @override
  void didUpdateWidget(BubbleRiseEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isActive)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _BubblePainter(
                      bubbles: _bubbles,
                      color: widget.bubbleColor,
                      time: DateTime.now().millisecondsSinceEpoch / 1000.0,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double wobble;
  final double wobbleSpeed;
  final double delay;

  _Bubble({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.wobble,
    required this.wobbleSpeed,
    required this.delay,
  });
}

class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final Color color;
  final double time;

  _BubblePainter({
    required this.bubbles,
    required this.color,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final adjustedTime = (time - bubble.delay) * bubble.speed;
      if (adjustedTime < 0) continue;

      // 计算Y位置（从底部上升）
      final progress = (adjustedTime % 5) / 5; // 5秒周期
      final y = size.height * (bubble.startY - progress * 1.5);

      if (y < -bubble.size || y > size.height + bubble.size) continue;

      // 计算X位置（左右摇摆）
      final wobbleOffset =
          math.sin(adjustedTime * bubble.wobbleSpeed) * bubble.wobble;
      final x = size.width * (bubble.x + wobbleOffset);

      // 计算透明度（上升时逐渐消散）
      final opacity = (1 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), bubble.size, paint);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => true;
}

/// 悬浮动画控制器 Mixin (Floating Animation Mixin)
///
/// 提供失重状态浮动效果的动画控制
/// 设计规范参考：20.2.6.4.1 悬浮停驻动画
mixin FloatingAnimationMixin<T extends StatefulWidget>
    on TickerProviderStateMixin<T> {
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

  /// 悬浮幅度（默认4-8dp）
  double get floatingAmplitude => 6.0;

  /// 悬浮周期（默认3-4秒）
  Duration get floatingDuration => const Duration(seconds: 3);

  /// 是否启用悬浮动画
  bool get floatingEnabled => true;

  /// 初始化悬浮动画
  void initFloatingAnimation() {
    _floatingController = AnimationController(
      vsync: this,
      duration: floatingDuration,
    );

    _floatingAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOutSine,
    ));

    if (floatingEnabled) {
      _floatingController.repeat(reverse: true);
    }
  }

  /// 获取当前悬浮偏移量
  double get floatingOffset {
    return math.sin(_floatingAnimation.value * math.pi) * floatingAmplitude;
  }

  /// 获取悬浮动画值（0-1）
  double get floatingValue => _floatingAnimation.value;

  /// 构建带悬浮效果的组件
  Widget buildFloatingWidget(Widget child) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, -floatingOffset),
          child: child,
        );
      },
    );
  }

  /// 开始悬浮动画
  void startFloating() {
    if (!_floatingController.isAnimating) {
      _floatingController.repeat(reverse: true);
    }
  }

  /// 停止悬浮动画
  void stopFloating() {
    _floatingController.stop();
  }

  /// 释放悬浮动画资源
  void disposeFloatingAnimation() {
    _floatingController.dispose();
  }
}

/// 拇指热区约束容器 (Thumb Zone Container)
///
/// 确保核心操作位于拇指热区（下半屏45%）
/// 设计规范参考：20.2.6.2.1 拇指热区优先原则
class ThumbZoneContainer extends StatelessWidget {
  final Widget coldZoneContent;
  final Widget warmZoneContent;
  final Widget hotZoneContent;

  /// 冷区高度占比（默认20%）
  final double coldZoneRatio;

  /// 暖区高度占比（默认35%）
  final double warmZoneRatio;

  /// 热区高度占比（默认45%）
  final double hotZoneRatio;

  const ThumbZoneContainer({
    super.key,
    required this.coldZoneContent,
    required this.warmZoneContent,
    required this.hotZoneContent,
    this.coldZoneRatio = 0.20,
    this.warmZoneRatio = 0.35,
    this.hotZoneRatio = 0.45,
  }) : assert(
          (coldZoneRatio + warmZoneRatio + hotZoneRatio - 1.0).abs() < 0.01,
          'Zone ratios must sum to 1.0',
        );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;

        return Column(
          children: [
            // 冷区（顶部20%）- 状态栏、只读信息
            SizedBox(
              height: totalHeight * coldZoneRatio,
              child: coldZoneContent,
            ),
            // 暖区（中部35%）- 筛选器、搜索、Tab切换
            SizedBox(
              height: totalHeight * warmZoneRatio,
              child: warmZoneContent,
            ),
            // 热区（底部45%）- 主导航、核心操作
            SizedBox(
              height: totalHeight * hotZoneRatio,
              child: hotZoneContent,
            ),
          ],
        );
      },
    );
  }
}

/// 反重力页面脚手架 (Antigravity Scaffold)
///
/// 整合反重力设计原则的页面脚手架
class AntigravityScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const AntigravityScaffold({
    super.key,
    required this.body,
    this.bottomBar,
    this.floatingActionButton,
    this.appBar,
    this.backgroundColor,
    this.extendBody = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: body,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
