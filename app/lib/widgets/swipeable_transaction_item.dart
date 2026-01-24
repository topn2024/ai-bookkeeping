import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';
import '../theme/app_theme.dart';

/// 可滑入操作按钮的交易条目组件
/// 长按或左滑触发，右侧显示编辑和删除按钮
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
    this.contentBuilder,
  });

  @override
  State<SwipeableTransactionItem> createState() => _SwipeableTransactionItemState();
}

class _SwipeableTransactionItemState extends State<SwipeableTransactionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  static const _buttonsWidth = 128.0; // 两个按钮的总宽度
  static const _buttonWidth = 64.0;
  static const _animationDuration = Duration(milliseconds: 200);
  static const _swipeThreshold = 50.0; // 滑动触发阈值

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
    if (!widget.isActive) {
      HapticFeedback.mediumImpact();
      widget.onLongPress();
    }
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragOffset = 0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isDragging) {
      setState(() {
        _dragOffset += details.delta.dx;
        // 只允许向左滑动（负值），且限制最大滑动距离
        if (!widget.isActive) {
          _dragOffset = _dragOffset.clamp(-_buttonsWidth * 1.2, 0);
        } else {
          // 激活状态下允许向右滑动收起
          _dragOffset = _dragOffset.clamp(-_buttonsWidth * 0.3, _buttonsWidth * 1.2);
        }
      });
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_isDragging) {
      if (!widget.isActive && _dragOffset < -_swipeThreshold) {
        // 向左滑动超过阈值，展开按钮
        HapticFeedback.lightImpact();
        widget.onLongPress();
      } else if (widget.isActive && _dragOffset > _swipeThreshold) {
        // 向右滑动超过阈值，收起按钮
        widget.onDismiss();
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

    return GestureDetector(
      onLongPressStart: _handleLongPressStart,
      onTap: widget.isActive ? widget.onDismiss : widget.onTap,
      onHorizontalDragStart: _handleHorizontalDragStart,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: widget.isActive ? Colors.grey.shade100 : Colors.white,
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // 右侧按钮区域（编辑 + 删除）
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _buttonsWidth * (1 - _slideAnimation.value),
                      0,
                    ),
                    child: Opacity(
                      opacity: _slideAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEditButton(),
                    _buildDeleteButton(),
                  ],
                ),
              ),
            ),
            // 主内容区域
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                // 滑动时的额外偏移
                final dragExtra = _isDragging ? _dragOffset : 0.0;
                return Transform.translate(
                  offset: Offset(
                    -_buttonsWidth * _slideAnimation.value + dragExtra,
                    0,
                  ),
                  child: child,
                );
              },
              child: widget.contentBuilder != null
                  ? widget.contentBuilder!(transaction, widget.themeColors)
                  : _buildDefaultContent(transaction, category, isExpense, isIncome),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultContent(Transaction transaction, Category? category, bool isExpense, bool isIncome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
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
                      _getCategoryDisplayName(transaction, category),
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

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onEdit();
      },
      child: Container(
        width: _buttonWidth,
        color: widget.themeColors.primary,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              '编辑',
              style: TextStyle(
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

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onDelete();
      },
      child: Container(
        width: _buttonWidth,
        color: widget.themeColors.expense,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              '删除',
              style: TextStyle(
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

  /// 获取分类显示名称
  /// 优先使用本地化名称，如果找不到分类定义则尝试本地化服务
  String _getCategoryDisplayName(Transaction transaction, Category? category) {
    // 如果找到了分类定义，使用本地化名称
    if (category != null) {
      return category.localizedName;
    }

    // 如果没找到分类定义，尝试通过本地化服务获取
    // 这样可以处理不规范的分类ID（如大小写不一致、英文名称等）
    final localizedName = transaction.category.localizedCategoryName;

    // 如果本地化服务也无法处理，返回原始值
    // 但至少尝试美化一下（首字母大写）
    if (localizedName == transaction.category.toLowerCase()) {
      return _beautifyCategoryName(transaction.category);
    }

    return localizedName;
  }

  /// 美化分类名称（用于无法识别的分类）
  /// 将 'food' 转换为 'Food'，'food_breakfast' 转换为 'Food Breakfast'
  String _beautifyCategoryName(String category) {
    if (category.isEmpty) return category;

    // 将下划线替换为空格，并将每个单词首字母大写
    return category
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
