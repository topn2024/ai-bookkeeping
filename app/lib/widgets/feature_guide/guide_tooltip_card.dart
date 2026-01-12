import 'package:flutter/material.dart';
import '../../models/guide_step.dart';

/// 引导提示卡片
///
/// 显示引导标题和说明文字
class GuideTooltipCard extends StatelessWidget {
  /// 引导标题
  final String title;

  /// 引导说明
  final String description;

  /// 卡片位置（用于决定箭头方向）
  final GuidePosition position;

  const GuideTooltipCard({
    super.key,
    required this.title,
    required this.description,
    this.position = GuidePosition.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 300,
        minWidth: 200,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // 说明文字
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// 带箭头的引导提示卡片
///
/// 在卡片边缘添加箭头指向目标元素
class GuideTooltipCardWithArrow extends StatelessWidget {
  /// 引导标题
  final String title;

  /// 引导说明
  final String description;

  /// 箭头位置
  final GuidePosition arrowPosition;

  const GuideTooltipCardWithArrow({
    super.key,
    required this.title,
    required this.description,
    this.arrowPosition = GuidePosition.top,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 卡片主体
        GuideTooltipCard(
          title: title,
          description: description,
          position: arrowPosition,
        ),

        // 箭头
        if (arrowPosition != GuidePosition.center) _buildArrow(),
      ],
    );
  }

  /// 构建箭头
  Widget _buildArrow() {
    return Positioned(
      top: arrowPosition == GuidePosition.bottom ? -10 : null,
      bottom: arrowPosition == GuidePosition.top ? -10 : null,
      left: arrowPosition == GuidePosition.right ? -10 : null,
      right: arrowPosition == GuidePosition.left ? -10 : null,
      child: CustomPaint(
        size: const Size(20, 10),
        painter: _ArrowPainter(
          direction: arrowPosition,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 箭头画板
class _ArrowPainter extends CustomPainter {
  final GuidePosition direction;
  final Color color;

  _ArrowPainter({
    required this.direction,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    switch (direction) {
      case GuidePosition.top:
        // 箭头指向下方
        path.moveTo(size.width / 2, size.height);
        path.lineTo(0, 0);
        path.lineTo(size.width, 0);
        path.close();
        break;

      case GuidePosition.bottom:
        // 箭头指向上方
        path.moveTo(size.width / 2, 0);
        path.lineTo(0, size.height);
        path.lineTo(size.width, size.height);
        path.close();
        break;

      case GuidePosition.left:
        // 箭头指向右方
        path.moveTo(size.width, size.height / 2);
        path.lineTo(0, 0);
        path.lineTo(0, size.height);
        path.close();
        break;

      case GuidePosition.right:
        // 箭头指向左方
        path.moveTo(0, size.height / 2);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
        path.close();
        break;

      case GuidePosition.center:
      case GuidePosition.custom:
        // 不绘制箭头
        break;
    }

    canvas.drawPath(path, paint);

    // 绘制阴影
    canvas.drawShadow(
      path,
      Colors.black.withOpacity(0.1),
      4.0,
      false,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return oldDelegate.direction != direction || oldDelegate.color != color;
  }
}
