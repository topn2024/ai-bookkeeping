import 'dart:math';
import 'package:flutter/material.dart';

/// 波浪动画组件
///
/// 用于录音时在悬浮球中显示动态波形
class WaveformAnimation extends StatefulWidget {
  final Color color;
  final double size;
  final int barCount;

  const WaveformAnimation({
    super.key,
    this.color = Colors.white,
    this.size = 24,
    this.barCount = 5,
  });

  @override
  State<WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    // 为每个柱子创建不同相位的动画
    _animations = List.generate(widget.barCount, (index) {
      final delay = index / widget.barCount;
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            delay,
            delay + 0.5 > 1.0 ? 1.0 : delay + 0.5,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _WaveformPainter(
            color: widget.color,
            barCount: widget.barCount,
            amplitudes: List.generate(widget.barCount, (index) {
              // 添加一些随机性使动画更自然
              final baseValue = _animations[index].value;
              final randomFactor = 0.8 + _random.nextDouble() * 0.4;
              return (baseValue * randomFactor).clamp(0.2, 1.0);
            }),
          ),
        );
      },
    );
  }
}

/// 波形绘制器
class _WaveformPainter extends CustomPainter {
  final Color color;
  final int barCount;
  final List<double> amplitudes;

  _WaveformPainter({
    required this.color,
    required this.barCount,
    required this.amplitudes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width / (barCount * 2.5);

    final barWidth = size.width / (barCount * 2 - 1);
    final maxHeight = size.height * 0.8;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth * 2 + barWidth / 2;
      final height = maxHeight * amplitudes[i];

      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes;
  }
}

/// 圆形波浪动画（替代方案）
class CircularWaveAnimation extends StatefulWidget {
  final Color color;
  final double size;

  const CircularWaveAnimation({
    super.key,
    this.color = Colors.white,
    this.size = 40,
  });

  @override
  State<CircularWaveAnimation> createState() => _CircularWaveAnimationState();
}

class _CircularWaveAnimationState extends State<CircularWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CircularWavePainter(
            color: widget.color,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

/// 圆形波浪绘制器
class _CircularWavePainter extends CustomPainter {
  final Color color;
  final double progress;

  _CircularWavePainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 绘制多个扩散波纹
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.6;

      final paint = Paint()
        ..color = color.withValues(alpha:opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }

    // 中心实心圆
    final centerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius * 0.3, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 脉冲动画组件
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Color pulseColor;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.pulseColor = Colors.blue,
    this.maxScale = 1.5,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
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
        return Stack(
          alignment: Alignment.center,
          children: [
            // 脉冲圆环
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.pulseColor.withValues(alpha:_opacityAnimation.value),
                    width: 2,
                  ),
                ),
              ),
            ),
            // 子组件
            widget.child,
          ],
        );
      },
    );
  }
}
