import 'package:flutter/material.dart';
import '../../models/guide_step.dart';
import 'guide_mask_painter.dart';
import 'guide_tooltip_card.dart';

/// 引导遮罩层
///
/// 全屏overlay，显示遮罩、高亮目标、提示卡片和操作按钮
class GuideOverlay extends StatefulWidget {
  /// 当前引导步骤
  final GuideStep step;

  /// 当前步骤索引（从0开始）
  final int currentIndex;

  /// 总步骤数
  final int totalSteps;

  /// 下一步回调
  final VoidCallback onNext;

  /// 跳过回调
  final VoidCallback onSkip;

  const GuideOverlay({
    super.key,
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<GuideOverlay>
    with SingleTickerProviderStateMixin {
  // 脉冲动画控制器
  late AnimationController _pulseController;

  // 目标元素的矩形区域
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();

    // 初始化脉冲动画
    if (widget.step.enablePulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
    } else {
      _pulseController = AnimationController(vsync: this);
    }

    // 获取目标元素位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTargetRect();
    });
  }

  @override
  void didUpdateWidget(GuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果步骤改变，重新计算目标位置
    if (oldWidget.step.id != widget.step.id) {
      _calculateTargetRect();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// 计算目标元素的矩形区域
  void _calculateTargetRect() {
    try {
      final RenderBox? renderBox =
          widget.step.targetKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        setState(() {
          _targetRect = Rect.fromLTWH(
            position.dx - widget.step.targetPadding,
            position.dy - widget.step.targetPadding,
            size.width + widget.step.targetPadding * 2,
            size.height + widget.step.targetPadding * 2,
          );
        });
      }
    } catch (e) {
      debugPrint('[GuideOverlay] Error calculating target rect: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. 遮罩层（带挖洞和脉冲效果）
          Positioned.fill(
            child: GestureDetector(
              onTap: () {}, // 阻止点击穿透
              child: CustomPaint(
                painter: GuideMaskPainter(
                  targetRect: _targetRect,
                  borderRadius: widget.step.borderRadius,
                  pulseAnimation: _pulseController,
                ),
              ),
            ),
          ),

          // 2. 提示卡片
          if (_targetRect != null) _buildTooltipCard(),

          // 3. 操作按钮
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// 构建提示卡片
  Widget _buildTooltipCard() {
    final screenSize = MediaQuery.of(context).size;
    final tooltipCard = GuideTooltipCardWithArrow(
      title: widget.step.title,
      description: widget.step.description,
      arrowPosition: widget.step.position,
    );

    // 根据position计算卡片位置
    Offset cardPosition;

    if (widget.step.position == GuidePosition.center) {
      // 居中显示
      cardPosition = Offset(
        screenSize.width / 2 - 150, // 假设卡片宽度约300
        screenSize.height / 2 - 100, // 假设卡片高度约200
      );
    } else {
      cardPosition = _calculateCardPosition(screenSize);
    }

    // 应用自定义偏移
    if (widget.step.customOffset != null) {
      cardPosition = cardPosition + widget.step.customOffset!;
    }

    return Positioned(
      left: cardPosition.dx,
      top: cardPosition.dy,
      child: tooltipCard,
    );
  }

  /// 计算卡片位置
  Offset _calculateCardPosition(Size screenSize) {
    if (_targetRect == null) {
      return Offset(screenSize.width / 2 - 150, screenSize.height / 2 - 100);
    }

    const cardWidth = 300.0;
    const cardHeight = 200.0; // 估计高度
    const spacing = 20.0;

    double left, top;

    switch (widget.step.position) {
      case GuidePosition.top:
        // 卡片在目标上方
        left = _targetRect!.center.dx - cardWidth / 2;
        top = _targetRect!.top - cardHeight - spacing;
        break;

      case GuidePosition.bottom:
        // 卡片在目标下方
        left = _targetRect!.center.dx - cardWidth / 2;
        top = _targetRect!.bottom + spacing;
        break;

      case GuidePosition.left:
        // 卡片在目标左侧
        left = _targetRect!.left - cardWidth - spacing;
        top = _targetRect!.center.dy - cardHeight / 2;
        break;

      case GuidePosition.right:
        // 卡片在目标右侧
        left = _targetRect!.right + spacing;
        top = _targetRect!.center.dy - cardHeight / 2;
        break;

      case GuidePosition.center:
      case GuidePosition.custom:
        left = screenSize.width / 2 - cardWidth / 2;
        top = screenSize.height / 2 - cardHeight / 2;
        break;
    }

    // 确保卡片不会超出屏幕边界
    left = left.clamp(16.0, screenSize.width - cardWidth - 16);
    top = top.clamp(16.0, screenSize.height - cardHeight - 16);

    return Offset(left, top);
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    final isLastStep = widget.currentIndex == widget.totalSteps - 1;

    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 跳过按钮
          TextButton(
            onPressed: widget.onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text(
              '跳过',
              style: TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(width: 20),

          // 下一步/完成按钮
          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
              foregroundColor: const Color(0xFF667EEA),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 4,
            ),
            child: Text(
              isLastStep
                  ? '开始使用'
                  : '下一步 (${widget.currentIndex + 1}/${widget.totalSteps})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
