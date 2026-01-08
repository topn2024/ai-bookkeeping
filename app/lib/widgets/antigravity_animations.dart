import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 反重力弹性缓动曲线 (Antigravity Elastic Easing)
///
/// 传达漂浮、弹性、轻盈的动态感受
/// 设计规范参考：20.2.6.4.2 弹性与回弹缓动
class AntigravityCurves {
  AntigravityCurves._();

  /// 弹性过冲曲线 - 用于元素弹出、按钮点击
  /// cubic-bezier(0.34, 1.56, 0.64, 1)
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1);

  /// 弹性振荡曲线 - 用于成就解锁、徽章展示
  static const Curve elasticOut = Curves.elasticOut;

  /// 反弹曲线 - 用于落地反弹、通知弹入
  static const Curve bounceOut = Curves.bounceOut;

  /// 漂浮曲线 - 用于悬浮呼吸动画
  /// cubic-bezier(0.25, 0.46, 0.45, 0.94)
  static const Curve float = Cubic(0.25, 0.46, 0.45, 0.94);

  /// 柔和弹性曲线 - 用于页面切换
  static const Curve softElastic = Cubic(0.68, -0.6, 0.32, 1.6);
}

/// 反重力动画时长
class AntigravityDurations {
  AntigravityDurations._();

  /// 快速动画 - 200ms
  static const Duration fast = Duration(milliseconds: 200);

  /// 标准动画 - 300ms
  static const Duration normal = Duration(milliseconds: 300);

  /// 慢速动画 - 500ms
  static const Duration slow = Duration(milliseconds: 500);

  /// 悬浮呼吸周期 - 3s
  static const Duration float = Duration(seconds: 3);

  /// 脉冲周期 - 2s
  static const Duration pulse = Duration(seconds: 2);
}

/// 金额上飘动画 (Amount Float Up Animation)
///
/// 记账成功时金额数字向上飘升效果
/// 设计规范参考：20.2.6.4.3 记账反重力动效编排
class AmountFloatUpAnimation extends StatefulWidget {
  final Widget child;
  final bool animate;
  final VoidCallback? onComplete;

  const AmountFloatUpAnimation({
    super.key,
    required this.child,
    this.animate = true,
    this.onComplete,
  });

  @override
  State<AmountFloatUpAnimation> createState() => _AmountFloatUpAnimationState();
}

class _AmountFloatUpAnimationState extends State<AmountFloatUpAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 上飘位移：从下方40px开始，先过冲到-10px，再回到0
    _translateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 40.0, end: -10.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -10.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    // 缩放：从0.8开始，过冲到1.05，再回到1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    // 透明度：从0到1
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AmountFloatUpAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 列表项上升动画 (List Rise Up Animation)
///
/// 列表新增项从底部依次升入
/// 设计规范参考：20.2.6.4.1 向上飘升动画
class ListRiseUpAnimation extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration staggerDelay;
  final bool animate;

  const ListRiseUpAnimation({
    super.key,
    required this.child,
    this.index = 0,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.animate = true,
  });

  @override
  State<ListRiseUpAnimation> createState() => _ListRiseUpAnimationState();
}

class _ListRiseUpAnimationState extends State<ListRiseUpAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _translateAnimation = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AntigravityCurves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    if (widget.animate) {
      Future.delayed(widget.staggerDelay * widget.index, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Toast上升动画 (Toast Rise Animation)
///
/// 从底部升起的Toast提示
/// 设计规范参考：20.2.6.4.1 向上飘升动画
class ToastRiseAnimation extends StatefulWidget {
  final Widget child;
  final bool show;
  final VoidCallback? onDismiss;

  const ToastRiseAnimation({
    super.key,
    required this.child,
    this.show = true,
    this.onDismiss,
  });

  @override
  State<ToastRiseAnimation> createState() => _ToastRiseAnimationState();
}

class _ToastRiseAnimationState extends State<ToastRiseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AntigravityCurves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    if (widget.show) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ToastRiseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _controller.forward();
    } else if (!widget.show && oldWidget.show) {
      _controller.reverse().then((_) {
        widget.onDismiss?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 悬浮呼吸动画 (Float Breathe Animation)
///
/// 元素保持轻微上下浮动，如同失重状态
/// 设计规范参考：20.2.6.4.1 悬浮停驻动画
class FloatBreatheAnimation extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;
  final bool enabled;

  const FloatBreatheAnimation({
    super.key,
    required this.child,
    this.amplitude = 6.0,
    this.period = const Duration(seconds: 3),
    this.enabled = true,
  });

  @override
  State<FloatBreatheAnimation> createState() => _FloatBreatheAnimationState();
}

class _FloatBreatheAnimationState extends State<FloatBreatheAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    );

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(FloatBreatheAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
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
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = math.sin(_controller.value * math.pi) * widget.amplitude;
        return Transform.translate(
          offset: Offset(0, -value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 脉冲呼吸效果 (Pulse Glow Animation)
///
/// 缓慢脉动的外发光，用于引导高亮
/// 设计规范参考：20.2.6.3.1 呼吸光晕效果
class PulseGlowAnimation extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxSpread;
  final Duration period;
  final bool enabled;

  const PulseGlowAnimation({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF6495ED),
    this.maxSpread = 20.0,
    this.period = const Duration(seconds: 2),
    this.enabled = true,
  });

  @override
  State<PulseGlowAnimation> createState() => _PulseGlowAnimationState();
}

class _PulseGlowAnimationState extends State<PulseGlowAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    );

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseGlowAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
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
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final spread = _controller.value * widget.maxSpread;
        final opacity = 0.4 - (_controller.value * 0.2);
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: opacity),
                blurRadius: spread,
                spreadRadius: spread / 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 成功打勾动画 (Success Check Animation)
///
/// 弹性旋转入场的成功勾选效果
/// 设计规范参考：20.2.6.4.3 阶段1按钮响应
class SuccessCheckAnimation extends StatefulWidget {
  final double size;
  final Color color;
  final bool animate;
  final VoidCallback? onComplete;

  const SuccessCheckAnimation({
    super.key,
    this.size = 48.0,
    this.color = const Color(0xFF66BB6A),
    this.animate = true,
    this.onComplete,
  });

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: AntigravityCurves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _rotateAnimation = Tween<double>(begin: -0.785, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SuccessCheckAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotateAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Icon(
                Icons.check_circle,
                size: widget.size,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// FAB展开菜单动画 (FAB Expand Animation)
///
/// 主按钮旋转45°，子按钮扇形展开
/// 设计规范参考：20.2.6.2.3 FAB展开菜单
class FabExpandAnimation extends StatefulWidget {
  final bool isExpanded;
  final List<Widget> children;
  final Widget mainButton;
  final double spacing;

  const FabExpandAnimation({
    super.key,
    required this.isExpanded,
    required this.children,
    required this.mainButton,
    this.spacing = 16.0,
  });

  @override
  State<FabExpandAnimation> createState() => _FabExpandAnimationState();
}

class _FabExpandAnimationState extends State<FabExpandAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.785).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AntigravityCurves.easeOutBack,
      ),
    );

    if (widget.isExpanded) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(FabExpandAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && !oldWidget.isExpanded) {
      _controller.forward();
    } else if (!widget.isExpanded && oldWidget.isExpanded) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 子按钮
        ...List.generate(widget.children.length, (index) {
          final reverseIndex = widget.children.length - 1 - index;
          return _buildChildButton(reverseIndex, widget.children[index]);
        }),
        // 主按钮
        AnimatedBuilder(
          animation: _rotateAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotateAnimation.value,
              child: child,
            );
          },
          child: widget.mainButton,
        ),
      ],
    );
  }

  Widget _buildChildButton(int index, Widget child) {
    final delay = index * 0.1;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay,
        delay + 0.6,
        curve: AntigravityCurves.easeOutBack,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, (1 - animation.value) * 20),
          child: Opacity(
            opacity: animation.value,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.spacing),
              child: Transform.scale(
                scale: animation.value,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 摇晃动画 (Shake Animation)
///
/// 用于提醒/警告的摇晃效果
class ShakeAnimation extends StatefulWidget {
  final Widget child;
  final bool shake;
  final double intensity;
  final VoidCallback? onComplete;

  const ShakeAnimation({
    super.key,
    required this.child,
    this.shake = false,
    this.intensity = 8.0,
    this.onComplete,
  });

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.shake) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        double offset = 0;
        if (progress < 0.2) {
          offset = -widget.intensity * (progress / 0.2);
        } else if (progress < 0.4) {
          offset = widget.intensity * ((progress - 0.2) / 0.2 * 2 - 1);
        } else if (progress < 0.6) {
          offset = -widget.intensity * ((progress - 0.4) / 0.2 * 2 - 1);
        } else if (progress < 0.8) {
          offset = widget.intensity * ((progress - 0.6) / 0.2 * 2 - 1);
        } else {
          offset = -widget.intensity * (1 - (progress - 0.8) / 0.2);
        }
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
