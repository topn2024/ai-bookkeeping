import 'package:flutter/material.dart';

/// 骨架屏加载组件
/// 原型设计 11.09：骨架屏加载状态
/// - 闪烁动画效果
/// - 交易列表骨架
/// - 卡片骨架
/// - 进度信息
class SkeletonLoading extends StatefulWidget {
  const SkeletonLoading({super.key});

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期分组骨架
        _buildShimmerBox(width: 80, height: 14),
        const SizedBox(height: 12),

        // 交易列表骨架
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(3, (index) => _buildTransactionSkeleton(theme, index)),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSkeleton(ThemeData theme, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: index < 2
            ? Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          // 图标骨架
          _buildShimmerBox(width: 44, height: 44, borderRadius: 12),
          const SizedBox(width: 12),
          // 内容骨架
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(width: double.infinity * 0.6, height: 14),
                const SizedBox(height: 8),
                _buildShimmerBox(width: double.infinity * 0.4, height: 12),
              ],
            ),
          ),
          // 金额骨架
          _buildShimmerBox(width: 60, height: 16),
        ],
      ),
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    double borderRadius = 4,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _animation.value, 0),
              end: Alignment(1 + 2 * _animation.value, 0),
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 卡片骨架
class CardSkeleton extends StatefulWidget {
  final double height;

  const CardSkeleton({super.key, this.height = 120});

  @override
  State<CardSkeleton> createState() => _CardSkeletonState();
}

class _CardSkeletonState extends State<CardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _animation.value, 0),
              end: Alignment(1 + 2 * _animation.value, 0),
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 列表项骨架
class ListItemSkeleton extends StatefulWidget {
  final bool showAvatar;
  final bool showSubtitle;

  const ListItemSkeleton({
    super.key,
    this.showAvatar = true,
    this.showSubtitle = true,
  });

  @override
  State<ListItemSkeleton> createState() => _ListItemSkeletonState();
}

class _ListItemSkeletonState extends State<ListItemSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (widget.showAvatar) ...[
            _buildShimmerCircle(40),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(width: 120, height: 14),
                if (widget.showSubtitle) ...[
                  const SizedBox(height: 6),
                  _buildShimmerBox(width: 80, height: 12),
                ],
              ],
            ),
          ),
          _buildShimmerBox(width: 50, height: 14),
        ],
      ),
    );
  }

  Widget _buildShimmerBox({required double width, required double height}) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _animation.value, 0),
              end: Alignment(1 + 2 * _animation.value, 0),
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerCircle(double size) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _animation.value, 0),
              end: Alignment(1 + 2 * _animation.value, 0),
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 加载进度横幅
class LoadingProgressBanner extends StatelessWidget {
  final String message;
  final int current;
  final int total;

  const LoadingProgressBanner({
    super.key,
    required this.message,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total > 0 ? current / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已加载 $current/$total 条',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  '加载更多',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFC8E6C9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 虚拟滚动提示
class VirtualScrollHint extends StatelessWidget {
  const VirtualScrollHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speed,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '虚拟滚动已启用 · 仅渲染可见区域',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
