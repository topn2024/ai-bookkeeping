import 'package:flutter/material.dart';

/// 同类用户对比数据
class PeerComparisonData {
  /// 用户分组标签
  final String groupLabel;

  /// 用户当前值
  final double userValue;

  /// 同类平均值
  final double peerAverage;

  /// 同类中位数
  final double peerMedian;

  /// 百分位排名 (0-100, 100表示最好)
  final int percentileRank;

  /// 数据类型
  final ComparisonType type;

  /// 时间范围描述
  final String timeRange;

  const PeerComparisonData({
    required this.groupLabel,
    required this.userValue,
    required this.peerAverage,
    required this.peerMedian,
    required this.percentileRank,
    required this.type,
    this.timeRange = '本月',
  });

  /// 用户是否优于平均
  bool get isBetterThanAverage {
    switch (type) {
      case ComparisonType.savingsRate:
      case ComparisonType.moneyAge:
      case ComparisonType.budgetAdherence:
        return userValue > peerAverage;
      case ComparisonType.optionalSpendingRatio:
      case ComparisonType.impulsePurchaseRatio:
        return userValue < peerAverage;
    }
  }

  /// 获取差异百分比
  double get differencePercentage {
    if (peerAverage == 0) return 0;
    return ((userValue - peerAverage) / peerAverage * 100).abs();
  }
}

/// 对比类型
enum ComparisonType {
  /// 储蓄率
  savingsRate,

  /// 钱龄
  moneyAge,

  /// 预算执行率
  budgetAdherence,

  /// 可选消费占比
  optionalSpendingRatio,

  /// 冲动消费比例
  impulsePurchaseRatio,
}

extension ComparisonTypeExtension on ComparisonType {
  String get displayName {
    switch (this) {
      case ComparisonType.savingsRate:
        return '储蓄率';
      case ComparisonType.moneyAge:
        return '钱龄';
      case ComparisonType.budgetAdherence:
        return '预算执行率';
      case ComparisonType.optionalSpendingRatio:
        return '可选消费占比';
      case ComparisonType.impulsePurchaseRatio:
        return '冲动消费比例';
    }
  }

  String get unit {
    switch (this) {
      case ComparisonType.savingsRate:
      case ComparisonType.budgetAdherence:
      case ComparisonType.optionalSpendingRatio:
      case ComparisonType.impulsePurchaseRatio:
        return '%';
      case ComparisonType.moneyAge:
        return '天';
    }
  }

  IconData get icon {
    switch (this) {
      case ComparisonType.savingsRate:
        return Icons.savings;
      case ComparisonType.moneyAge:
        return Icons.hourglass_full;
      case ComparisonType.budgetAdherence:
        return Icons.check_circle;
      case ComparisonType.optionalSpendingRatio:
        return Icons.shopping_bag;
      case ComparisonType.impulsePurchaseRatio:
        return Icons.flash_on;
    }
  }

  /// 高值是否更好
  bool get higherIsBetter {
    switch (this) {
      case ComparisonType.savingsRate:
      case ComparisonType.moneyAge:
      case ComparisonType.budgetAdherence:
        return true;
      case ComparisonType.optionalSpendingRatio:
      case ComparisonType.impulsePurchaseRatio:
        return false;
    }
  }
}

/// 同类用户对比卡片
///
/// 展示用户与同类用户群体的财务行为对比
/// 帮助用户了解自己在群体中的位置
class PeerComparisonCard extends StatelessWidget {
  /// 对比数据
  final PeerComparisonData data;

  /// 是否显示详细信息
  final bool showDetails;

  /// 是否显示百分位排名
  final bool showPercentile;

  /// 点击回调
  final VoidCallback? onTap;

  /// 查看更多回调
  final VoidCallback? onViewMore;

  const PeerComparisonCard({
    super.key,
    required this.data,
    this.showDetails = true,
    this.showPercentile = true,
    this.onTap,
    this.onViewMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBetter = data.isBetterThanAverage;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            _buildHeader(theme),
            const SizedBox(height: 20),

            // 主要对比区域
            _buildMainComparison(theme, isBetter),
            const SizedBox(height: 20),

            // 百分位排名
            if (showPercentile) ...[
              _buildPercentileRank(theme),
              const SizedBox(height: 16),
            ],

            // 详细数据
            if (showDetails) _buildDetailsRow(theme),

            // 底部操作
            if (onViewMore != null) ...[
              const SizedBox(height: 16),
              _buildFooter(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            data.type.icon,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.type.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${data.timeRange} · ${data.groupLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        // 对比标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: data.isBetterThanAverage
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                data.isBetterThanAverage
                    ? Icons.trending_up
                    : Icons.trending_down,
                size: 14,
                color: data.isBetterThanAverage ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                data.isBetterThanAverage ? '优于平均' : '低于平均',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      data.isBetterThanAverage ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainComparison(ThemeData theme, bool isBetter) {
    final userColor = isBetter ? Colors.green : Colors.orange;

    return Row(
      children: [
        // 用户数值
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你的${data.type.displayName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatValue(data.userValue),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: userColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(
                      data.type.unit,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: userColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // VS 分隔
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              'VS',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),

        // 同类平均
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '同类平均',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatValue(data.peerAverage),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(
                      data.type.unit,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPercentileRank(ThemeData theme) {
    final rank = data.percentileRank;
    final color = _getPercentileColor(rank);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 排名圆环
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              children: [
                // 背景圆环
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 6,
                    backgroundColor: color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.2)),
                  ),
                ),
                // 进度圆环
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: rank / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                // 中心文字
                Center(
                  child: Text(
                    '$rank',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 描述文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getPercentileDescription(rank),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '你超越了$rank%的同类用户',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),

          // 奖章图标
          if (rank >= 80)
            Icon(
              rank >= 90 ? Icons.emoji_events : Icons.star,
              color: color,
              size: 28,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsRow(ThemeData theme) {
    return Row(
      children: [
        // 同类中位数
        Expanded(
          child: _buildDetailItem(
            theme,
            label: '同类中位数',
            value: '${_formatValue(data.peerMedian)}${data.type.unit}',
          ),
        ),
        Container(
          height: 30,
          width: 1,
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        // 差异
        Expanded(
          child: _buildDetailItem(
            theme,
            label: '与平均差异',
            value:
                '${data.isBetterThanAverage ? '+' : '-'}${data.differencePercentage.toStringAsFixed(1)}%',
            valueColor:
                data.isBetterThanAverage ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return TextButton(
      onPressed: onViewMore,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '查看详细对比分析',
            style: TextStyle(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  String _formatValue(double value) {
    if (value >= 100) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  Color _getPercentileColor(int rank) {
    if (rank >= 90) return Colors.amber[700]!;
    if (rank >= 75) return Colors.green;
    if (rank >= 50) return Colors.blue;
    if (rank >= 25) return Colors.orange;
    return Colors.grey;
  }

  String _getPercentileDescription(int rank) {
    if (rank >= 90) return '财务精英 🏆';
    if (rank >= 75) return '表现优秀 ⭐';
    if (rank >= 50) return '稳健发展 👍';
    if (rank >= 25) return '需要加油 💪';
    return '还有很大提升空间';
  }
}

/// 多维度对比概览
class PeerComparisonOverview extends StatelessWidget {
  /// 多个维度的对比数据
  final List<PeerComparisonData> comparisons;

  /// 点击单个维度的回调
  final Function(PeerComparisonData)? onItemTap;

  const PeerComparisonOverview({
    super.key,
    required this.comparisons,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 计算综合排名
    final avgPercentile = comparisons.isNotEmpty
        ? comparisons.fold(0, (sum, c) => sum + c.percentileRank) ~/
            comparisons.length
        : 50;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                Icons.people_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '同类用户对比',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '综合排名 Top $avgPercentile%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 雷达图风格的概览
          ...comparisons.map((comparison) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildComparisonItem(theme, comparison),
              )),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(ThemeData theme, PeerComparisonData data) {
    final isBetter = data.isBetterThanAverage;

    return GestureDetector(
      onTap: () => onItemTap?.call(data),
      child: Row(
        children: [
          // 图标
          Icon(
            data.type.icon,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          // 名称
          Expanded(
            flex: 2,
            child: Text(
              data.type.displayName,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          // 进度条
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // 背景
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // 用户进度
                FractionallySizedBox(
                  widthFactor: data.percentileRank / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: isBetter ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // 平均线标记 (50%位置)
                Align(
                  alignment: const Alignment(0, 0), // 50%位置对应alignment.x = 0
                  child: Container(
                    width: 2,
                    height: 8,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 排名
          Text(
            'Top ${data.percentileRank}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isBetter ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
