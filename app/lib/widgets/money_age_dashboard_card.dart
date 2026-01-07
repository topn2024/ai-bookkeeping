import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/resource_pool.dart';
import '../services/money_age_level_service.dart';

/// 钱龄仪表盘卡片
///
/// 显示内容：
/// 1. 当前平均钱龄（大数字）
/// 2. 健康等级标签
/// 3. 趋势迷你图
/// 4. 阶段进度条
/// 5. 点击跳转到详情页
class MoneyAgeDashboardCard extends StatelessWidget {
  /// 钱龄统计数据
  final MoneyAgeStatistics stats;

  /// 点击回调
  final VoidCallback? onTap;

  /// 是否显示迷你趋势图
  final bool showTrendChart;

  /// 是否显示阶段进度
  final bool showStageProgress;

  const MoneyAgeDashboardCard({
    super.key,
    required this.stats,
    this.onTap,
    this.showTrendChart = true,
    this.showStageProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelService = MoneyAgeLevelService();
    final levelDetails = levelService.getLevelDetails(stats.averageAge);
    final stageProgress = levelService.getStageProgress(stats.averageAge);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap ?? () => _navigateToDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题行
              _buildHeader(context, levelDetails),
              const SizedBox(height: 16),

              // 核心数字
              _buildMainNumber(context, levelDetails),
              const SizedBox(height: 12),

              // 趋势迷你图
              if (showTrendChart && stats.trend.isNotEmpty) ...[
                MoneyAgeTrendMiniChart(data: stats.trend),
                const SizedBox(height: 12),
              ],

              // 阶段进度条
              if (showStageProgress) ...[
                _buildStageProgress(context, stageProgress),
                const SizedBox(height: 8),
              ],

              // 点击提示
              _buildFooter(context, levelDetails),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题行
  Widget _buildHeader(BuildContext context, LevelDetails levelDetails) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '钱龄',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        _buildHealthBadge(levelDetails.level),
      ],
    );
  }

  /// 构建健康等级标签
  Widget _buildHealthBadge(MoneyAgeLevel level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: level.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            level.icon,
            size: 14,
            color: level.color,
          ),
          const SizedBox(width: 4),
          Text(
            level.displayName,
            style: TextStyle(
              color: level.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建核心数字
  Widget _buildMainNumber(BuildContext context, LevelDetails levelDetails) {
    final trendIcon = _getTrendIcon(stats.trendDirection);
    final trendColor = _getTrendColor(stats.trendDirection);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${stats.averageAge}',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: levelDetails.level.color,
            height: 1,
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '天',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (trendIcon != null)
              Row(
                children: [
                  Icon(trendIcon, size: 14, color: trendColor),
                  const SizedBox(width: 2),
                  Text(
                    stats.trendDirection == 'up'
                        ? '上升'
                        : stats.trendDirection == 'down'
                            ? '下降'
                            : '稳定',
                    style: TextStyle(
                      fontSize: 11,
                      color: trendColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const Spacer(),
        // 资源池信息
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${stats.activePoolCount}个资源池',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            Text(
              '¥${stats.totalResourcePoolBalance.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建阶段进度条
  Widget _buildStageProgress(BuildContext context, StageProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              progress.currentStage.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: progress.currentStage.color,
              ),
            ),
            if (progress.nextStage != null)
              Text(
                '→ ${progress.nextStage!.name}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.progressInStage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(progress.currentStage.color),
            minHeight: 6,
          ),
        ),
        if (progress.daysToNextStage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '距离下一阶段还需 ${progress.daysToNextStage} 天',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ),
      ],
    );
  }

  /// 构建底部
  Widget _buildFooter(BuildContext context, LevelDetails levelDetails) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            levelDetails.healthStatus,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          children: [
            Text(
              '查看详情',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }

  IconData? _getTrendIcon(String direction) {
    switch (direction) {
      case 'up':
        return Icons.trending_up;
      case 'down':
        return Icons.trending_down;
      case 'stable':
        return Icons.trending_flat;
      default:
        return null;
    }
  }

  Color _getTrendColor(String direction) {
    switch (direction) {
      case 'up':
        return Colors.green;
      case 'down':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.pushNamed(context, '/money-age');
  }
}

/// 钱龄趋势迷你图
class MoneyAgeTrendMiniChart extends StatelessWidget {
  final List<DailyMoneyAge> data;
  final double height;

  const MoneyAgeTrendMiniChart({
    super.key,
    required this.data,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(height: height);
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendChartPainter(
          data: data,
          lineColor: Theme.of(context).colorScheme.primary,
          fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ),
    );
  }
}

/// 趋势图绘制器
class _TrendChartPainter extends CustomPainter {
  final List<DailyMoneyAge> data;
  final Color lineColor;
  final Color fillColor;

  _TrendChartPainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // 计算数据范围
    final ages = data.map((d) => d.averageAge.toDouble()).toList();
    final minAge = ages.reduce((a, b) => a < b ? a : b);
    final maxAge = ages.reduce((a, b) => a > b ? a : b);
    final range = maxAge - minAge;
    final effectiveRange = range > 0 ? range : 1;

    // 构建路径
    final linePath = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);
    final paddingY = 4.0;
    final chartHeight = size.height - paddingY * 2;

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = (data[i].averageAge - minAge) / effectiveRange;
      final y = paddingY + chartHeight * (1 - normalizedY);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // 完成填充路径
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // 绘制
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    // 绘制最后一个点
    if (data.isNotEmpty) {
      final lastX = (data.length - 1) * stepX;
      final normalizedY = (data.last.averageAge - minAge) / effectiveRange;
      final lastY = paddingY + chartHeight * (1 - normalizedY);

      canvas.drawCircle(
        Offset(lastX, lastY),
        4,
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return data != oldDelegate.data ||
        lineColor != oldDelegate.lineColor ||
        fillColor != oldDelegate.fillColor;
  }
}

/// 钱龄简洁卡片（用于列表等场景）
class MoneyAgeCompactCard extends StatelessWidget {
  final int moneyAge;
  final VoidCallback? onTap;

  const MoneyAgeCompactCard({
    super.key,
    required this.moneyAge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final levelService = MoneyAgeLevelService();
    final level = levelService.determineLevel(moneyAge);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: level.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: level.color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 16,
              color: level.color,
            ),
            const SizedBox(width: 6),
            Text(
              '$moneyAge天',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: level.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 钱龄状态指示器（用于交易列表项）
class MoneyAgeIndicator extends StatelessWidget {
  final int moneyAge;
  final double size;

  const MoneyAgeIndicator({
    super.key,
    required this.moneyAge,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final levelService = MoneyAgeLevelService();
    final level = levelService.determineLevel(moneyAge);

    return Tooltip(
      message: '钱龄: $moneyAge天 (${level.displayName})',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: level.color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            moneyAge > 99 ? '99+' : '$moneyAge',
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
              color: level.color,
            ),
          ),
        ),
      ),
    );
  }
}
