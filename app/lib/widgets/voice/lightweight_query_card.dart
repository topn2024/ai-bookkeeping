import 'package:flutter/material.dart';
import '../../services/voice/query/query_models.dart';

/// 轻量查询卡片
///
/// 用于Level 2响应，显示查询结果的轻量级卡片
/// 支持进度条、占比、对比三种类型
/// 3秒后自动淡出
class LightweightQueryCard extends StatefulWidget {
  final QueryCardData cardData;
  final VoidCallback? onDismiss;

  const LightweightQueryCard({
    Key? key,
    required this.cardData,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<LightweightQueryCard> createState() => _LightweightQueryCardState();
}

class _LightweightQueryCardState extends State<LightweightQueryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 创建动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // 淡入淡出动画
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // 淡入
    _controller.forward();

    // 3秒后自动淡出
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildCardContent(),
      ),
    );
  }

  Widget _buildCardContent() {
    switch (widget.cardData.cardType) {
      case CardType.progress:
        return _buildProgressCard();
      case CardType.percentage:
        return _buildPercentageCard();
      case CardType.comparison:
        return _buildComparisonCard();
    }
  }

  /// 构建进度卡片
  Widget _buildProgressCard() {
    final progress = widget.cardData.progress ?? 0.0;
    final primaryValue = widget.cardData.primaryValue;
    final secondaryValue = widget.cardData.secondaryValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已用 ${primaryValue.toStringAsFixed(0)}元',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (secondaryValue != null)
              Text(
                '/ ${secondaryValue.toStringAsFixed(0)}元',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 0.9 ? Colors.red : Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: progress > 0.9 ? Colors.red : Colors.black54,
          ),
        ),
      ],
    );
  }

  /// 构建占比卡片
  Widget _buildPercentageCard() {
    final percentage = widget.cardData.percentage ?? 0.0;
    final primaryValue = widget.cardData.primaryValue;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${primaryValue.toStringAsFixed(0)}元',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '占比 ${(percentage * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: percentage,
                strokeWidth: 6,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              Center(
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建对比卡片
  Widget _buildComparisonCard() {
    final comparison = widget.cardData.comparison;
    if (comparison == null) {
      return const SizedBox.shrink();
    }

    final currentValue = comparison.currentValue;
    final previousValue = comparison.previousValue;
    final changePercentage = comparison.changePercentage;
    final isIncrease = comparison.isIncrease;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本期',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  '${currentValue.toStringAsFixed(0)}元',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '上期',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  '${previousValue.toStringAsFixed(0)}元',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isIncrease
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: isIncrease ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                '${changePercentage.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isIncrease ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
