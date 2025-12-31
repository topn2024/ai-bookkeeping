import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

/// 可滑入操作按钮的交易条目组件
/// 长按触发，左侧滑入编辑按钮，右侧滑入删除按钮
/// 激活状态下可左右滑动触发操作
class SwipeableTransactionItem extends StatefulWidget {
  final Transaction transaction;
  final bool isActive;
  final ThemeColors themeColors;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Widget? sourceIndicator;
  /// 长按触发时间，默认1秒
  final Duration longPressDuration;
  /// 自定义内容构建器（用于首页等不同样式）
  final Widget Function(Transaction transaction, ThemeColors colors)? contentBuilder;

  const SwipeableTransactionItem({
    super.key,
    required this.transaction,
    required this.isActive,
    required this.themeColors,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    required this.onDismiss,
    this.sourceIndicator,
    this.longPressDuration = const Duration(milliseconds: 1000),
    this.contentBuilder,
  });

  @override
  State<SwipeableTransactionItem> createState() => _SwipeableTransactionItemState();
}

class _SwipeableTransactionItemState extends State<SwipeableTransactionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  static const _buttonWidth = 64.0;
  static const _animationDuration = Duration(milliseconds: 200);
  static const _swipeThreshold = 60.0; // 滑动触发阈值

  // 滑动相关
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _slideAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SwipeableTransactionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.reverse();
      _dragOffset = 0;
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    widget.onLongPress();
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    if (widget.isActive) {
      _isDragging = true;
      _dragOffset = 0;
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isDragging && widget.isActive) {
      setState(() {
        _dragOffset += details.delta.dx;
        // 限制拖动范围
        _dragOffset = _dragOffset.clamp(-_swipeThreshold * 1.5, _swipeThreshold * 1.5);
      });
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_isDragging && widget.isActive) {
      if (_dragOffset > _swipeThreshold) {
        // 向右滑动 -> 编辑
        HapticFeedback.lightImpact();
        widget.onEdit();
      } else if (_dragOffset < -_swipeThreshold) {
        // 向左滑动 -> 删除
        HapticFeedback.lightImpact();
        widget.onDelete();
      }
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final category = DefaultCategories.findById(transaction.category);
    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;

    // 计算滑动时的视觉反馈
    final editHighlight = (_dragOffset > 0) ? (_dragOffset / _swipeThreshold).clamp(0.0, 1.0) : 0.0;
    final deleteHighlight = (_dragOffset < 0) ? (-_dragOffset / _swipeThreshold).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onLongPressStart: _handleLongPressStart,
      onTap: widget.isActive ? widget.onDismiss : widget.onTap,
      onHorizontalDragStart: _handleHorizontalDragStart,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: AnimatedScale(
        scale: widget.isActive ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.grey.shade100
                : Colors.white,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // 左侧编辑按钮
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        -_buttonWidth * (1 - _slideAnimation.value),
                        0,
                      ),
                      child: Opacity(
                        opacity: _slideAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildEditButton(editHighlight),
                ),
              ),
              // 右侧删除按钮
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        _buttonWidth * (1 - _slideAnimation.value),
                        0,
                      ),
                      child: Opacity(
                        opacity: _slideAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildDeleteButton(deleteHighlight),
                ),
              ),
              // 中间内容（可滑动）
              AnimatedContainer(
                duration: _animationDuration,
                margin: EdgeInsets.symmetric(
                  horizontal: widget.isActive ? _buttonWidth : 0,
                ),
                child: Transform.translate(
                  offset: Offset(_isDragging ? _dragOffset : 0, 0),
                  child: widget.contentBuilder != null
                      ? widget.contentBuilder!(transaction, widget.themeColors)
                      : _buildDefaultContent(transaction, category, isExpense, isIncome),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultContent(Transaction transaction, Category? category, bool isExpense, bool isIncome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 分类图标
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (category?.color ?? Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              category?.icon ?? Icons.help_outline,
              color: category?.color ?? Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // 分类和备注
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      category?.localizedName ?? transaction.category,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.sourceIndicator != null) ...[
                      const SizedBox(width: 6),
                      widget.sourceIndicator!,
                    ],
                  ],
                ),
                if (transaction.note != null && transaction.note!.isNotEmpty)
                  Text(
                    transaction.note!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // 金额和时间
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? '-' : (isIncome ? '+' : '')}¥${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isExpense
                      ? widget.themeColors.expense
                      : (isIncome
                          ? widget.themeColors.income
                          : widget.themeColors.transfer),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('HH:mm').format(transaction.date),
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton(double highlight) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onEdit();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: _buttonWidth + (highlight * 16), // 高亮时稍微变宽
        decoration: BoxDecoration(
          color: Color.lerp(
            widget.themeColors.primary,
            widget.themeColors.primary.withValues(alpha: 0.8),
            highlight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
          boxShadow: highlight > 0.5
              ? [
                  BoxShadow(
                    color: widget.themeColors.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit,
              color: Colors.white,
              size: 22 + (highlight * 4),
            ),
            const SizedBox(height: 4),
            Text(
              highlight > 0.8 ? '松开编辑' : '编辑',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton(double highlight) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onDelete();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: _buttonWidth + (highlight * 16),
        decoration: BoxDecoration(
          color: Color.lerp(
            widget.themeColors.expense,
            widget.themeColors.expense.withValues(alpha: 0.8),
            highlight,
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          boxShadow: highlight > 0.5
              ? [
                  BoxShadow(
                    color: widget.themeColors.expense.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete,
              color: Colors.white,
              size: 22 + (highlight * 4),
            ),
            const SizedBox(height: 4),
            Text(
              highlight > 0.8 ? '松开删除' : '删除',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
