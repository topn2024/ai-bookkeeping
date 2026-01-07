import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 微交互动画类型
enum MicroAnimationType {
  /// 涟漪效果
  ripple,

  /// 缩放效果
  scale,

  /// 弹跳效果
  bounce,

  /// 淡入淡出
  fade,

  /// 滑动
  slide,

  /// 旋转
  rotate,

  /// 摇晃
  shake,

  /// 脉冲
  pulse,

  /// 心跳
  heartbeat,

  /// 成功勾选
  checkmark,

  /// 庆祝撒花
  confetti,
}

/// 微交互配置
class MicroAnimationConfig {
  /// 动画时长
  final Duration duration;

  /// 动画曲线
  final Curve curve;

  /// 是否启用触觉反馈
  final bool hapticFeedback;

  /// 触觉反馈类型
  final HapticFeedbackType hapticType;

  /// 延迟启动
  final Duration delay;

  /// 是否自动反向播放
  final bool autoReverse;

  /// 重复次数（0表示无限）
  final int repeatCount;

  const MicroAnimationConfig({
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.hapticFeedback = true,
    this.hapticType = HapticFeedbackType.light,
    this.delay = Duration.zero,
    this.autoReverse = false,
    this.repeatCount = 1,
  });

  /// 快速动画
  static const fast = MicroAnimationConfig(
    duration: Duration(milliseconds: 150),
    curve: Curves.easeOut,
  );

  /// 标准动画
  static const standard = MicroAnimationConfig(
    duration: Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  /// 缓慢动画
  static const slow = MicroAnimationConfig(
    duration: Duration(milliseconds: 500),
    curve: Curves.easeInOutCubic,
  );

  /// 弹性动画
  static const bouncy = MicroAnimationConfig(
    duration: Duration(milliseconds: 400),
    curve: Curves.elasticOut,
  );
}

/// 触觉反馈类型
enum HapticFeedbackType {
  /// 轻微反馈
  light,

  /// 中等反馈
  medium,

  /// 重度反馈
  heavy,

  /// 选择反馈
  selection,

  /// 成功反馈
  success,

  /// 警告反馈
  warning,

  /// 错误反馈
  error,
}

/// 微交互动画服务
///
/// 核心功能：
/// 1. 提供统一的微交互动画API
/// 2. 内置多种常用动画效果
/// 3. 触觉反馈集成
/// 4. 可配置的动画参数
/// 5. 支持组合动画
///
/// 对应设计文档：第21章 交互体验设计
///
/// 使用示例：
/// ```dart
/// // 按钮点击动画
/// MicroAnimationService.playTapAnimation(context, widget);
///
/// // 成功动画
/// MicroAnimationService.playSuccessAnimation(context);
///
/// // 自定义动画
/// MicroAnimationService.playAnimation(
///   type: MicroAnimationType.bounce,
///   config: MicroAnimationConfig.bouncy,
/// );
/// ```
class MicroAnimationService {
  MicroAnimationService._();

  /// 执行触觉反馈
  static Future<void> haptic(HapticFeedbackType type) async {
    switch (type) {
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
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.warning:
        await HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.error:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        break;
    }
  }

  /// 创建缩放动画控制器
  static AnimationController createScaleController(
    TickerProvider vsync, {
    Duration duration = const Duration(milliseconds: 150),
    double lowerBound = 0.95,
    double upperBound = 1.0,
  }) {
    return AnimationController(
      vsync: vsync,
      duration: duration,
      lowerBound: lowerBound,
      upperBound: upperBound,
      value: upperBound,
    );
  }

  /// 创建弹跳动画
  static Animation<double> createBounceAnimation(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 0.95).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(controller);
  }

  /// 创建摇晃动画
  static Animation<double> createShakeAnimation(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 1),
    ]).animate(controller);
  }

  /// 创建脉冲动画
  static Animation<double> createPulseAnimation(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.1).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(controller);
  }

  /// 创建心跳动画
  static Animation<double> createHeartbeatAnimation(AnimationController controller) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 60),
    ]).animate(controller);
  }
}

/// 可点击缩放包装器
/// 为任意Widget添加点击缩放效果
class TapScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final Duration duration;
  final bool enableHaptic;

  const TapScaleWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.enableHaptic = true,
  });

  @override
  State<TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<TapScaleWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 成功勾选动画组件
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  const AnimatedCheckmark({
    super.key,
    this.size = 48,
    this.color = Colors.green,
    this.duration = const Duration(milliseconds: 500),
    this.onComplete,
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });

    // 触觉反馈
    MicroAnimationService.haptic(HapticFeedbackType.success);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CheckmarkPainter(
            progress: _animation.value,
            color: widget.color,
            strokeWidth: widget.size / 10,
          ),
        );
      },
    );
  }
}

/// 勾选绘制器
class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 勾选路径点
    final start = Offset(size.width * 0.2, size.height * 0.5);
    final mid = Offset(size.width * 0.4, size.height * 0.7);
    final end = Offset(size.width * 0.8, size.height * 0.3);

    final path = Path();

    if (progress <= 0.5) {
      // 第一段：从start到mid
      final t = progress * 2;
      final currentX = start.dx + (mid.dx - start.dx) * t;
      final currentY = start.dy + (mid.dy - start.dy) * t;
      path.moveTo(start.dx, start.dy);
      path.lineTo(currentX, currentY);
    } else {
      // 第一段完成
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);

      // 第二段：从mid到end
      final t = (progress - 0.5) * 2;
      final currentX = mid.dx + (end.dx - mid.dx) * t;
      final currentY = mid.dy + (end.dy - mid.dy) * t;
      path.lineTo(currentX, currentY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 加载指示器动画组件
class PulsingDot extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const PulsingDot({
    super.key,
    this.size = 12,
    this.color = Colors.blue,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _animation = MicroAnimationService.createPulseAnimation(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// 涟漪效果动画
class RippleEffect extends StatefulWidget {
  final Widget child;
  final Color rippleColor;
  final double maxRadius;
  final Duration duration;

  const RippleEffect({
    super.key,
    required this.child,
    this.rippleColor = Colors.blue,
    this.maxRadius = 100,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      child: Stack(
        children: [
          widget.child,
          if (_tapPosition != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RipplePainter(
                      center: _tapPosition!,
                      progress: _controller.value,
                      maxRadius: widget.maxRadius,
                      color: widget.rippleColor,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 涟漪绘制器
class _RipplePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final double maxRadius;
  final Color color;

  _RipplePainter({
    required this.center,
    required this.progress,
    required this.maxRadius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity((1 - progress) * 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius * progress, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
