import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 滑动关闭方向
enum SwipeDismissDirection {
  /// 水平方向（左右滑动）
  horizontal,

  /// 垂直方向（上下滑动）
  vertical,

  /// 任意方向
  both,
}

/// 可滑动关闭的对话框包装组件
///
/// 支持通过滑动手势关闭对话框，提供流畅的动画和触觉反馈。
///
/// 使用方式：
/// ```dart
/// // 方式1：使用静态方法
/// await SwipeableDismissDialog.show(
///   context,
///   builder: (context) => YourDialogContent(),
/// );
///
/// // 方式2：包装现有对话框
/// showDialog(
///   context: context,
///   builder: (context) => SwipeableDismissDialog(
///     child: YourExistingDialog(),
///   ),
/// );
/// ```
class SwipeableDismissDialog extends StatefulWidget {
  /// 子组件（对话框内容）
  final Widget child;

  /// 关闭回调
  final VoidCallback? onDismiss;

  /// 滑动方向
  final SwipeDismissDirection direction;

  /// 触发关闭的滑动距离阈值
  final double dismissThreshold;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 动画时长
  final Duration animationDuration;

  const SwipeableDismissDialog({
    super.key,
    required this.child,
    this.onDismiss,
    this.direction = SwipeDismissDirection.horizontal,
    this.dismissThreshold = 100.0,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  /// 显示可滑动关闭的对话框
  ///
  /// 返回对话框结果，如果通过滑动关闭则返回 null
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    SwipeDismissDirection direction = SwipeDismissDirection.horizontal,
    double dismissThreshold = 100.0,
    bool enableHapticFeedback = true,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      builder: (context) => SwipeableDismissDialog(
        direction: direction,
        dismissThreshold: dismissThreshold,
        enableHapticFeedback: enableHapticFeedback,
        child: builder(context),
      ),
    );
  }

  @override
  State<SwipeableDismissDialog> createState() => _SwipeableDismissDialogState();
}

class _SwipeableDismissDialogState extends State<SwipeableDismissDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // 滑动偏移量
  Offset _dragOffset = Offset.zero;

  // 是否正在拖动
  bool _isDragging = false;

  // 是否已触发触觉反馈（开始拖动时）
  bool _hasTriggeredStartHaptic = false;

  // 是否已触发阈值触觉反馈
  bool _hasTriggeredThresholdHaptic = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 计算当前滑动距离
  double get _currentDragDistance {
    switch (widget.direction) {
      case SwipeDismissDirection.horizontal:
        return _dragOffset.dx.abs();
      case SwipeDismissDirection.vertical:
        return _dragOffset.dy.abs();
      case SwipeDismissDirection.both:
        return _dragOffset.distance;
    }
  }

  /// 计算透明度（基于滑动距离）
  double get _opacity {
    final progress = (_currentDragDistance / widget.dismissThreshold).clamp(0.0, 1.0);
    return 1.0 - (progress * 0.5); // 最低透明度为 0.5
  }

  /// 是否超过关闭阈值
  bool get _isOverThreshold => _currentDragDistance >= widget.dismissThreshold;

  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _hasTriggeredStartHaptic = false;
    _hasTriggeredThresholdHaptic = false;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      // 根据方向限制滑动
      switch (widget.direction) {
        case SwipeDismissDirection.horizontal:
          _dragOffset = Offset(
            _dragOffset.dx + details.delta.dx,
            0,
          );
          break;
        case SwipeDismissDirection.vertical:
          _dragOffset = Offset(
            0,
            _dragOffset.dy + details.delta.dy,
          );
          break;
        case SwipeDismissDirection.both:
          _dragOffset = _dragOffset + details.delta;
          break;
      }
    });

    // 触发开始拖动的触觉反馈
    if (!_hasTriggeredStartHaptic && _currentDragDistance > 10) {
      _hasTriggeredStartHaptic = true;
      if (widget.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }
    }

    // 触发超过阈值的触觉反馈
    if (!_hasTriggeredThresholdHaptic && _isOverThreshold) {
      _hasTriggeredThresholdHaptic = true;
      if (widget.enableHapticFeedback) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    if (_isOverThreshold) {
      // 超过阈值，执行关闭动画
      _animateDismiss();
    } else {
      // 未超过阈值，回弹
      _animateBounceBack();
    }
  }

  /// 执行关闭动画
  void _animateDismiss() {
    // 计算滑动方向的终点
    final direction = _dragOffset.dx != 0 || _dragOffset.dy != 0
        ? _dragOffset / _dragOffset.distance
        : const Offset(1, 0);

    final targetOffset = direction * 300; // 滑出屏幕的距离

    _animationController.forward();

    // 使用动画平滑过渡到最终位置
    final startOffset = _dragOffset;

    _animationController.addListener(() {
      if (mounted) {
        setState(() {
          final progress = _animationController.value;
          _dragOffset = Offset.lerp(startOffset, targetOffset, progress)!;
        });
      }
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss?.call();
        Navigator.of(context).pop();
      }
    });
  }

  /// 执行回弹动画
  void _animateBounceBack() {
    final startOffset = _dragOffset;

    final bounceController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    final bounceAnimation = CurvedAnimation(
      parent: bounceController,
      curve: Curves.elasticOut,
    );

    bounceAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.lerp(startOffset, Offset.zero, bounceAnimation.value)!;
        });
      }
    });

    bounceAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        bounceController.dispose();
      }
    });

    bounceController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: _dragOffset,
            child: Transform.scale(
              scale: 1.0 - (_animationController.value * 0.1),
              child: Opacity(
                opacity: _opacity * (1.0 - _animationController.value * 0.5),
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
