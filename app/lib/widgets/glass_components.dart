import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/antigravity_shadows.dart';

/// 玻璃态效果组件 (Glassmorphism Components)
///
/// 半透明毛玻璃效果，增强层次感
/// 设计规范参考：20.2.6.3.1 玻璃态效果

/// 玻璃态卡片 (Glass Card)
///
/// 带有毛玻璃背景的悬浮卡片
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurStrength;
  final double opacity;
  final Color? backgroundColor;
  final Color? borderColor;
  final int shadowLevel;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.blurStrength = 20.0,
    this.opacity = 0.72,
    this.backgroundColor,
    this.borderColor,
    this.shadowLevel = 2,
    this.onTap,
  });

  /// 强玻璃效果
  const GlassCard.strong({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.onTap,
  })  : blurStrength = 40.0,
        opacity = 0.88,
        backgroundColor = null,
        borderColor = null,
        shadowLevel = 3;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.white.withValues(alpha: opacity);
    final border = borderColor ?? Colors.white.withValues(alpha: 0.3);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurStrength,
          sigmaY: blurStrength,
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border, width: 1),
            boxShadow: AntigravityShadows.getLevel(shadowLevel),
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}

/// 玻璃态底部导航栏 (Glass Bottom Navigation)
///
/// 带有毛玻璃效果的底部导航栏
class GlassBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final List<GlassBottomNavItem> items;
  final ValueChanged<int>? onTap;
  final double height;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;

  const GlassBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.items,
    this.onTap,
    this.height = 80,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? Colors.white.withValues(alpha: 0.88);
    final selected = selectedColor ?? theme.colorScheme.primary;
    final unselected = unselectedColor ?? theme.colorScheme.onSurfaceVariant;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6495ED).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;
                return _GlassNavItem(
                  item: item,
                  isSelected: isSelected,
                  selectedColor: selected,
                  unselectedColor: unselected,
                  onTap: () => onTap?.call(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  final GlassBottomNavItem item;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback? onTap;

  const _GlassNavItem({
    required this.item,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 占位项（给FAB留空间）
    if (item.icon == null || item.isPlaceholder) {
      return const SizedBox(width: 56);  // FAB宽度的占位
    }

    final color = isSelected ? selectedColor : unselectedColor;
    final icon = isSelected ? (item.activeIcon ?? item.icon) : item.icon;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 16 : 0,
                vertical: isSelected ? 4 : 0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected ? AntigravityShadows.l2 : null,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玻璃态导航项数据
class GlassBottomNavItem {
  final IconData? icon;
  final IconData? activeIcon;
  final String label;
  final bool isPlaceholder;  // 是否是占位项（给FAB留空间）

  const GlassBottomNavItem({
    this.icon,
    this.activeIcon,
    required this.label,
    this.isPlaceholder = false,
  });
}

/// 玻璃态FAB按钮 (Glass FAB)
///
/// 带有毛玻璃效果和L4阴影的FAB
class GlassFab extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double size;
  final bool enableBreathe;

  const GlassFab({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.size = 56,
    this.enableBreathe = true,
  });

  @override
  State<GlassFab> createState() => _GlassFabState();
}

class _GlassFabState extends State<GlassFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    if (widget.enableBreathe) {
      _breatheController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _breatheController,
      builder: (context, child) {
        final offset = widget.enableBreathe
            ? -6.0 * _breatheController.value
            : 0.0;

        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bgColor,
                bgColor.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AntigravityShadows.l4,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

/// 悬浮卡片 (Floating Card)
///
/// 带有L3阴影和悬浮效果的卡片
class FloatingCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final int shadowLevel;
  final bool enableHover;
  final VoidCallback? onTap;

  const FloatingCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.shadowLevel = 2,
    this.enableHover = true,
    this.onTap,
  });

  @override
  State<FloatingCard> createState() => _FloatingCardState();
}

class _FloatingCardState extends State<FloatingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currentLevel = _isHovered && widget.enableHover
        ? widget.shadowLevel + 1
        : widget.shadowLevel;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: widget.padding ?? const EdgeInsets.all(16),
      transform: Matrix4.translationValues(
        0,
        _isHovered ? -2 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: AntigravityShadows.getLevel(currentLevel),
      ),
      child: widget.child,
    );

    if (widget.margin != null) {
      card = Padding(padding: widget.margin!, child: card);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: card,
      ),
    );
  }
}

/// 层叠卡片组 (Stacked Cards)
///
/// 多张卡片层叠展示，支持点击切换
/// 设计规范参考：20.2.6.3.2 层叠卡片组
class StackedCards extends StatefulWidget {
  final List<Widget> cards;
  final int initialIndex;
  final ValueChanged<int>? onCardSelected;
  final double stackOffset;

  const StackedCards({
    super.key,
    required this.cards,
    this.initialIndex = 0,
    this.onCardSelected,
    this.stackOffset = 8.0,
  });

  @override
  State<StackedCards> createState() => _StackedCardsState();
}

class _StackedCardsState extends State<StackedCards> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _selectCard(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      widget.onCardSelected?.call(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(widget.cards.length, (index) {
        final reverseIndex = widget.cards.length - 1 - index;
        final isTop = reverseIndex == _currentIndex;
        final offsetFromTop = _getOffsetFromTop(reverseIndex);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: offsetFromTop * widget.stackOffset,
          left: offsetFromTop * widget.stackOffset,
          right: offsetFromTop * widget.stackOffset,
          child: GestureDetector(
            onTap: () => _selectCard(reverseIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: AntigravityShadows.getLevel(isTop ? 3 : 1),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isTop ? 1.0 : 0.6 - (offsetFromTop * 0.15),
                child: widget.cards[reverseIndex],
              ),
            ),
          ),
        );
      }),
    );
  }

  int _getOffsetFromTop(int index) {
    if (index == _currentIndex) return 0;
    if (index < _currentIndex) {
      return _currentIndex - index;
    } else {
      return widget.cards.length - index + _currentIndex;
    }
  }
}

/// 反重力底部弹窗 (Antigravity Bottom Sheet)
///
/// 三档高度: Mini(25%) · Half(50%) · Full(90%)
/// 设计规范参考：20.2.6.2.2 底部优先交互模式
class AntigravityBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool expand;
  final VoidCallback? onClose;

  const AntigravityBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.9,
    this.expand = true,
    this.onClose,
  });

  /// Mini弹窗 (25%)
  const AntigravityBottomSheet.mini({
    super.key,
    required this.child,
    this.title,
    this.onClose,
  })  : initialChildSize = 0.25,
        minChildSize = 0.15,
        maxChildSize = 0.5,
        expand = false;

  /// Half弹窗 (50%)
  const AntigravityBottomSheet.half({
    super.key,
    required this.child,
    this.title,
    this.onClose,
  })  : initialChildSize = 0.5,
        minChildSize = 0.25,
        maxChildSize = 0.75,
        expand = true;

  /// Full弹窗 (90%)
  const AntigravityBottomSheet.full({
    super.key,
    required this.child,
    this.title,
    this.onClose,
  })  : initialChildSize = 0.9,
        minChildSize = 0.5,
        maxChildSize = 0.95,
        expand = true;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: expand,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AntigravityShadows.l5,
          ),
          child: Column(
            children: [
              // 拖动条
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (onClose != null)
                        GestureDetector(
                          onTap: onClose,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              // 内容区
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示底部弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    double initialChildSize = 0.5,
    double minChildSize = 0.25,
    double maxChildSize = 0.9,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => AntigravityBottomSheet(
        title: title,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        onClose: () => Navigator.of(context).pop(),
        child: child,
      ),
    );
  }
}

/// 反重力Toast (Antigravity Toast)
///
/// 从底部升起的轻量级提示
class AntigravityToast {
  /// 显示Toast
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    ToastType type = ToastType.normal,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        message: message,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        type: type,
        onDismiss: () => entry.remove(),
        duration: duration,
      ),
    );

    overlay.insert(entry);
  }
}

enum ToastType { normal, success, warning, error }

class _ToastOverlay extends StatefulWidget {
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ToastType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const _ToastOverlay({
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    required this.type,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
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
      curve: const Cubic(0.34, 1.56, 0.64, 1),
    ));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xF02E7D32);
      case ToastType.warning:
        return const Color(0xF0E67E22);
      case ToastType.error:
        return const Color(0xF0C0392B);
      case ToastType.normal:
        return const Color(0xF01E2A3B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AntigravityShadows.l4,
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null)
                      GestureDetector(
                        onTap: () {
                          widget.onAction?.call();
                          _controller.reverse().then((_) => widget.onDismiss());
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: const TextStyle(
                              color: Color(0xFF87CEFA),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
