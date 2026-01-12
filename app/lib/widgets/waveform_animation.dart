import 'dart:math';
import 'package:flutter/material.dart';

/// 波浪动画组件
///
/// 用于录音时在悬浮球中显示动态波形
/// - 无声音时显示水平直线
/// - 有声音时显示流动的正弦波，振幅根据音量变化
class WaveformAnimation extends StatefulWidget {
  final Color color;
  final double size;
  /// 真实振幅值 (0.0 - 1.0)
  final double? amplitude;

  const WaveformAnimation({
    super.key,
    this.color = Colors.white,
    this.size = 24,
    this.amplitude,
  });

  @override
  State<WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<WaveformAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 动画控制器，用于波浪流动效果
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
          painter: _WaveformPainter(
            color: widget.color,
            amplitude: widget.amplitude ?? 0.0,
            phase: _controller.value * 2 * pi, // 相位随时间变化，产生流动效果
          ),
        );
      },
    );
  }
}

/// 波形绘制器
class _WaveformPainter extends CustomPainter {
  final Color color;
  final double amplitude; // 0.0 - 1.0
  final double phase; // 动画相位

  _WaveformPainter({
    required this.color,
    required this.amplitude,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final maxAmplitude = size.height * 0.38; // 最大振幅高度

    // 检查是否有声音（振幅是否足够大）
    final hasSound = amplitude > 0.1;

    if (!hasSound) {
      // 无声音：画一条水平直线
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        paint,
      );
    } else {
      // 有声音：画流动的正弦波
      final path = Path();
      final waveCount = 2.0; // 波浪数量
      final points = 50; // 采样点数量

      for (int i = 0; i <= points; i++) {
        final x = (i / points) * size.width;
        final progress = i / points;

        // 使用正弦函数创建波浪，phase 使波浪流动
        final sineValue = sin(progress * waveCount * 2 * pi + phase);
        // 振幅随位置变化（中间大，两端小），乘以实际音量振幅
        final envelopeValue = sin(progress * pi);
        final y = centerY + sineValue * amplitude * maxAmplitude * envelopeValue;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude || oldDelegate.phase != phase;
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
