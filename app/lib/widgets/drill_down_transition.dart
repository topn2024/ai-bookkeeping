import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 下钻过渡动画类型
enum DrillDownTransitionType {
  /// 缩放展开
  zoomIn,

  /// 淡入淡出
  fade,

  /// 滑动
  slide,

  /// 翻转
  flip,

  /// 缩放+滑动组合
  zoomSlide,

  /// 扇形展开（饼图专用）
  pieExpand,

  /// 涟漪展开
  ripple,
}

/// 下钻过渡配置
class DrillDownTransitionConfig {
  /// 动画类型
  final DrillDownTransitionType type;

  /// 动画时长
  final Duration duration;

  /// 动画曲线
  final Curve curve;

  /// 反向动画曲线
  final Curve reverseCurve;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 起始点（用于缩放/涟漪效果）
  final Offset? originPoint;

  /// 起始颜色（用于颜色过渡）
  final Color? fromColor;

  /// 结束颜色
  final Color? toColor;

  const DrillDownTransitionConfig({
    this.type = DrillDownTransitionType.zoomSlide,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.reverseCurve = Curves.easeInCubic,
    this.enableHapticFeedback = true,
    this.originPoint,
    this.fromColor,
    this.toColor,
  });

  /// 快速过渡预设
  static const quick = DrillDownTransitionConfig(
    duration: Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  /// 流畅过渡预设
  static const smooth = DrillDownTransitionConfig(
    duration: Duration(milliseconds: 500),
    curve: Curves.easeInOutCubic,
  );

  /// 弹性过渡预设
  static const bouncy = DrillDownTransitionConfig(
    duration: Duration(milliseconds: 600),
    curve: Curves.elasticOut,
  );
}

/// 下钻过渡控制器
class DrillDownTransitionController extends ChangeNotifier {
  /// 动画控制器
  AnimationController? _animationController;

  /// 当前配置
  DrillDownTransitionConfig _config;

  /// 是否正在动画
  bool get isAnimating => _animationController?.isAnimating ?? false;

  /// 动画进度
  double get progress => _animationController?.value ?? 0;

  /// 是否是下钻方向（true=下钻，false=返回）
  bool _isDrillDown = true;

  bool get isDrillDown => _isDrillDown;

  DrillDownTransitionController({
    DrillDownTransitionConfig config = const DrillDownTransitionConfig(),
  }) : _config = config;

  DrillDownTransitionConfig get config => _config;

  /// 初始化（需要在 State 中调用）
  void init(TickerProvider vsync) {
    _animationController = AnimationController(
      duration: _config.duration,
      vsync: vsync,
    );
    _animationController!.addListener(() => notifyListeners());
  }

  /// 更新配置
  void updateConfig(DrillDownTransitionConfig config) {
    _config = config;
    _animationController?.duration = config.duration;
  }

  /// 执行下钻动画
  Future<void> drillDown({Offset? fromPoint}) async {
    if (_animationController == null) return;

    _isDrillDown = true;
    if (_config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    _animationController!.reset();
    await _animationController!.forward();
  }

  /// 执行返回动画
  Future<void> goBack({Offset? toPoint}) async {
    if (_animationController == null) return;

    _isDrillDown = false;
    if (_config.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    await _animationController!.reverse();
  }

  /// 获取当前动画值（带曲线）
  double get animatedValue {
    if (_animationController == null) return 0;

    final curve = _isDrillDown ? _config.curve : _config.reverseCurve;
    return curve.transform(_animationController!.value);
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
}

/// 下钻过渡动画组件
///
/// 核心功能：
/// 1. 多种过渡动画效果
/// 2. 可配置动画参数
/// 3. 触觉反馈
/// 4. 支持自定义起点
///
/// 对应设计文档：第12.5节 下钻过渡动画
///
/// 使用示例：
/// ```dart
/// DrillDownTransition(
///   controller: controller,
///   child: DetailView(),
/// )
/// ```
class DrillDownTransition extends StatelessWidget {
  /// 过渡控制器
  final DrillDownTransitionController controller;

  /// 子组件
  final Widget child;

  /// 起始点（用于缩放效果）
  final Offset? originPoint;

  const DrillDownTransition({
    super.key,
    required this.controller,
    required this.child,
    this.originPoint,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.animatedValue;
        final isDrillDown = controller.isDrillDown;

        switch (controller.config.type) {
          case DrillDownTransitionType.zoomIn:
            return _buildZoomTransition(value, isDrillDown);

          case DrillDownTransitionType.fade:
            return _buildFadeTransition(value);

          case DrillDownTransitionType.slide:
            return _buildSlideTransition(value, isDrillDown);

          case DrillDownTransitionType.flip:
            return _buildFlipTransition(value, isDrillDown);

          case DrillDownTransitionType.zoomSlide:
            return _buildZoomSlideTransition(value, isDrillDown);

          case DrillDownTransitionType.pieExpand:
            return _buildPieExpandTransition(value, isDrillDown);

          case DrillDownTransitionType.ripple:
            return _buildRippleTransition(value, isDrillDown, context);
        }
      },
    );
  }

  /// 缩放过渡
  Widget _buildZoomTransition(double value, bool isDrillDown) {
    final scale = isDrillDown ? (0.8 + 0.2 * value) : (1.0 - 0.2 * (1 - value));
    final opacity = value.clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: child,
      ),
    );
  }

  /// 淡入淡出过渡
  Widget _buildFadeTransition(double value) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: child,
    );
  }

  /// 滑动过渡
  Widget _buildSlideTransition(double value, bool isDrillDown) {
    final offset = isDrillDown
        ? Offset(1.0 - value, 0)
        : Offset(value - 1.0, 0);

    return FractionalTranslation(
      translation: offset,
      child: child,
    );
  }

  /// 翻转过渡
  Widget _buildFlipTransition(double value, bool isDrillDown) {
    final angle = isDrillDown
        ? (1.0 - value) * math.pi / 2
        : (value - 1.0) * math.pi / 2;

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle),
      alignment: Alignment.center,
      child: Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: child,
      ),
    );
  }

  /// 缩放+滑动组合过渡
  Widget _buildZoomSlideTransition(double value, bool isDrillDown) {
    final scale = isDrillDown
        ? (0.9 + 0.1 * value)
        : (1.0 - 0.1 * (1 - value));
    final offset = isDrillDown
        ? Offset(0.3 * (1 - value), 0)
        : Offset(-0.3 * value, 0);
    final opacity = value.clamp(0.0, 1.0);

    return FractionalTranslation(
      translation: offset,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Opacity(
          opacity: opacity,
          child: child,
        ),
      ),
    );
  }

  /// 扇形展开过渡（饼图专用）
  Widget _buildPieExpandTransition(double value, bool isDrillDown) {
    return ClipPath(
      clipper: _PieExpandClipper(
        progress: value,
        origin: originPoint ?? const Offset(0.5, 0.5),
      ),
      child: child,
    );
  }

  /// 涟漪展开过渡
  Widget _buildRippleTransition(double value, bool isDrillDown, BuildContext context) {
    return ClipPath(
      clipper: _RippleClipper(
        progress: value,
        origin: originPoint ?? const Offset(0.5, 0.5),
      ),
      child: child,
    );
  }
}

/// 扇形裁剪器
class _PieExpandClipper extends CustomClipper<Path> {
  final double progress;
  final Offset origin;

  _PieExpandClipper({
    required this.progress,
    required this.origin,
  });

  @override
  Path getClip(Size size) {
    final center = Offset(size.width * origin.dx, size.height * origin.dy);
    final maxRadius = math.sqrt(
      math.pow(size.width, 2) + math.pow(size.height, 2),
    );
    final currentRadius = maxRadius * progress;

    final path = Path();
    path.addOval(Rect.fromCircle(center: center, radius: currentRadius));
    return path;
  }

  @override
  bool shouldReclip(covariant _PieExpandClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.origin != origin;
  }
}

/// 涟漪裁剪器
class _RippleClipper extends CustomClipper<Path> {
  final double progress;
  final Offset origin;

  _RippleClipper({
    required this.progress,
    required this.origin,
  });

  @override
  Path getClip(Size size) {
    final center = Offset(size.width * origin.dx, size.height * origin.dy);
    final maxRadius = math.sqrt(
      math.pow(math.max(center.dx, size.width - center.dx), 2) +
      math.pow(math.max(center.dy, size.height - center.dy), 2),
    ) * 1.2;
    final currentRadius = maxRadius * progress;

    final path = Path();
    path.addOval(Rect.fromCircle(center: center, radius: currentRadius));
    return path;
  }

  @override
  bool shouldReclip(covariant _RippleClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.origin != origin;
  }
}

/// 下钻页面路由
class DrillDownPageRoute<T> extends PageRouteBuilder<T> {
  /// 过渡配置
  final DrillDownTransitionConfig config;

  /// 起始点
  final Offset? originPoint;

  DrillDownPageRoute({
    required Widget page,
    this.config = const DrillDownTransitionConfig(),
    this.originPoint,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: config.duration,
          reverseTransitionDuration: config.duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(
              animation: animation,
              config: config,
              originPoint: originPoint,
              child: child,
            );
          },
        );

  static Widget _buildTransition({
    required Animation<double> animation,
    required DrillDownTransitionConfig config,
    required Widget child,
    Offset? originPoint,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: config.curve,
      reverseCurve: config.reverseCurve,
    );

    switch (config.type) {
      case DrillDownTransitionType.zoomIn:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );

      case DrillDownTransitionType.fade:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );

      case DrillDownTransitionType.slide:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case DrillDownTransitionType.flip:
        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, _) {
            final angle = (1.0 - curvedAnimation.value) * math.pi / 2;
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: Opacity(
                opacity: curvedAnimation.value,
                child: child,
              ),
            );
          },
        );

      case DrillDownTransitionType.zoomSlide:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          ),
        );

      case DrillDownTransitionType.pieExpand:
      case DrillDownTransitionType.ripple:
        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, _) {
            return ClipPath(
              clipper: _RippleClipper(
                progress: curvedAnimation.value,
                origin: originPoint ?? const Offset(0.5, 0.5),
              ),
              child: child,
            );
          },
        );
    }
  }
}

/// 下钻英雄动画包装器
class DrillDownHero extends StatelessWidget {
  /// 英雄标签
  final Object tag;

  /// 子组件
  final Widget child;

  /// 是否启用
  final bool enabled;

  const DrillDownHero({
    super.key,
    required this.tag,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Material(
              color: Colors.transparent,
              child: child,
            );
          },
        );
      },
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }
}
