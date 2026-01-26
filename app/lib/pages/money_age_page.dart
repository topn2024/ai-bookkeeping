import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../models/resource_pool.dart';
import '../services/money_age_level_service.dart';
import '../services/actionable_insight_service.dart';
import '../services/subscription_tracking_service.dart';
import '../services/latte_factor_analyzer.dart';
import '../theme/app_theme.dart';
import '../providers/money_age_provider.dart';
import '../providers/ledger_context_provider.dart';
import '../providers/budget_provider.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../services/database_service.dart';
import '../models/budget.dart' as budget_model;

/// 钱龄详情页
/// 原型设计 2.01：钱龄详情 Money Age Detail
/// - 核心数据区：钱龄数字 + 等级徽章
/// - 统计数据行：本月最高/最低/较上月
/// - 等级进度条（紧凑版）
/// - 趋势迷你图
/// - ���金区：行动按钮
class MoneyAgePage extends ConsumerWidget {
  const MoneyAgePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ledgerContext = ref.watch(ledgerContextProvider);
    final bookId = ledgerContext.currentLedger?.id;

    if (bookId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('钱龄分析')),
        body: const Center(child: Text('请先选择账本')),
      );
    }

    final dashboardAsync = ref.watch(moneyAgeDashboardProvider(bookId));
    // 本地钱龄数据作为备用
    final localMoneyAge = ref.watch(moneyAgeProvider);
    final moneyAgeHistory = ref.watch(moneyAgeHistoryProvider);

    return dashboardAsync.when(
      data: (dashboard) {
        // 如果 API 返回 null，使用本地计算的钱龄数据
        final effectiveDashboard = dashboard ?? _createDashboardFromLocal(localMoneyAge, moneyAgeHistory);
        return _buildContent(context, theme, effectiveDashboard, ref);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('钱龄分析')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('钱龄分析')),
        body: Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, MoneyAgeDashboard dashboard, WidgetRef ref) {
    final levelService = MoneyAgeLevelService();
    final averageAge = dashboard.avgMoneyAge.round();
    final stageProgress = levelService.getStageProgress(averageAge);
    final levelDetails = levelService.getLevelDetails(averageAge);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCoreDataSection(context, theme, averageAge, levelDetails),
                    _buildStatsRow(context, theme, dashboard),
                    _buildLevelProgressCard(context, theme, averageAge, stageProgress, levelDetails, levelService),
                    _buildTrendMiniChart(context, theme, dashboard),
                  ],
                ),
              ),
            ),
            _buildActionButton(context, theme, averageAge, levelDetails),
          ],
        ),
      ),
    );
  }

  /// 页面头部
  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '钱龄分析',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showHelpDialog(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.help_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 核心数据区：钱龄数字
  Widget _buildCoreDataSection(BuildContext context, ThemeData theme, int averageAge, LevelDetails levelDetails) {
    // 负钱龄使用红色
    final isNegative = averageAge < 0;
    final levelColor = isNegative ? const Color(0xFFE57373) : _getLevelColor(levelDetails.level);
    final gradientColors = isNegative
        ? [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)]
        : [levelColor.withValues(alpha: 0.15), levelColor.withValues(alpha: 0.08)];

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 核心数字
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$averageAge',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: levelColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '天',
                style: TextStyle(
                  fontSize: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 等级徽章（负钱龄显示"透支"）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: levelColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isNegative
                  ? '⚠️ 透支 已超支${-averageAge}天'
                  : '${_getLevelEmoji(levelDetails.level)} ${levelDetails.level.displayName} Lv.${_getLevelNumber(levelDetails.level)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 统计数据行
  Widget _buildStatsRow(BuildContext context, ThemeData theme, MoneyAgeDashboard dashboard) {
    // Calculate stats from trend data if available
    int monthlyMax = dashboard.avgMoneyAge.round();
    int monthlyMin = dashboard.avgMoneyAge.round();
    int monthlyChange = 0;

    if (dashboard.trendData.isNotEmpty) {
      // 允许负值，不再过滤 > 0
      final ages = dashboard.trendData.map((d) => (d['avg_age'] as num?)?.toInt() ?? 0).toList();
      if (ages.isNotEmpty) {
        monthlyMax = ages.reduce((a, b) => a > b ? a : b);
        monthlyMin = ages.reduce((a, b) => a < b ? a : b);
        if (ages.length > 1) {
          monthlyChange = ages.first - ages.last;
        }
      }
    }

    // 根据值正负决定颜色
    final maxColor = monthlyMax >= 0 ? AppColors.success : AppColors.error;
    final minColor = monthlyMin >= 0 ? null : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '本月最高',
              value: '$monthlyMax天',
              valueColor: maxColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '本月最低',
              value: '$monthlyMin天',
              valueColor: minColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '较上月',
              value: monthlyChange >= 0
                  ? '+$monthlyChange天'
                  : '$monthlyChange天',
              valueColor:
                  monthlyChange >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 等级进度条（紧凑版）
  Widget _buildLevelProgressCard(BuildContext context, ThemeData theme, int averageAge, StageProgress stageProgress, LevelDetails levelDetails, MoneyAgeLevelService levelService) {
    final nextStage = stageProgress.nextStage;
    final daysToNext = stageProgress.daysToNextStage;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '等级进度',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToStageProgress(context, averageAge, stageProgress),
                child: Text(
                  nextStage != null ? '距Lv.${_getLevelNumber(levelService.determineLevel(nextStage.minDays))}还需$daysToNext天 →' : '已达最高等级',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 6段式进度条
          Row(
            children: List.generate(6, (index) {
              final isAchieved = index < _getLevelNumber(levelDetails.level);
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: index < 5 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: isAchieved
                        ? AppColors.success
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 趋势迷你图
  Widget _buildTrendMiniChart(BuildContext context, ThemeData theme, MoneyAgeDashboard dashboard) {
    if (dashboard.trendData.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(12),
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '近30天趋势',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () => _navigateToHistory(context),
                  child: Text(
                    '查看详情 →',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '暂无趋势数据',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 获取近30天数据
    final recentData = dashboard.trendData.take(30).toList();
    final ages = recentData.map((d) => (d['avg_age'] as num?)?.toInt() ?? 0).toList();

    // 计算变化趋势
    int monthlyChange = 0;
    if (ages.length > 1) {
      monthlyChange = ages.last - ages.first;
    }

    // 生成折线图数据点
    final spots = <FlSpot>[];
    for (int i = 0; i < ages.length; i++) {
      spots.add(FlSpot(i.toDouble(), ages[i].toDouble()));
    }

    // 计算Y轴范围
    final minAge = ages.reduce((a, b) => a < b ? a : b);
    final maxAge = ages.reduce((a, b) => a > b ? a : b);
    final yMin = (minAge - 2).toDouble();
    final yMax = (maxAge + 2).toDouble();
    final yRange = yMax - yMin;

    // 根据是否有负值决定颜色
    final hasNegative = minAge < 0;
    final lineColor = hasNegative ? AppColors.warning : AppColors.success;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    '近30天趋势',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Icon(
                        monthlyChange >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: monthlyChange >= 0 ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        monthlyChange >= 0 ? '+$monthlyChange天' : '$monthlyChange天',
                        style: TextStyle(
                          fontSize: 11,
                          color: monthlyChange >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _navigateToHistory(context),
                child: Text(
                  '查看详情 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            padding: const EdgeInsets.only(right: 4, top: 8, bottom: 4, left: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yRange > 0 ? yRange / 3 : 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: yRange > 0 ? yRange / 3 : 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: (spots.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= recentData.length) {
                          return const SizedBox.shrink();
                        }
                        final dateStr = recentData[index]['date'] as String?;
                        if (dateStr == null) return const SizedBox.shrink();

                        try {
                          final date = DateTime.parse(dateStr);
                          return Text(
                            '${date.month}/${date.day}',
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        } catch (_) {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: yRange > 0 ? yMin : -10,
                maxY: yRange > 0 ? yMax : 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: spots.length <= 7),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index < 0 || index >= recentData.length) return null;
                        final dateStr = recentData[index]['date'] as String?;
                        if (dateStr == null) return null;

                        try {
                          final date = DateTime.parse(dateStr);
                          return LineTooltipItem(
                            '${date.month}/${date.day}\n${spot.y.toInt()}天',
                            const TextStyle(color: Colors.white, fontSize: 11),
                          );
                        } catch (_) {
                          return null;
                        }
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 黄金区：行动按钮
  Widget _buildActionButton(BuildContext context, ThemeData theme, int averageAge, LevelDetails levelDetails) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _navigateToUpgradeGuide(context, averageAge, levelDetails),
          icon: const Icon(Icons.lightbulb, size: 20),
          label: const Text(
            '查看提升建议',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  // ========== 辅助方法 ==========

  /// 从本地 MoneyAge 创建 MoneyAgeDashboard
  /// 用于 API 返回 null 时的降级方案
  MoneyAgeDashboard _createDashboardFromLocal(
    budget_model.MoneyAge localMoneyAge,
    List<MapEntry<DateTime, int>> historyData,
  ) {
    final days = localMoneyAge.days;
    final healthLevel = days >= 30 ? 'good' : (days >= 14 ? 'normal' : (days >= 7 ? 'warning' : 'danger'));

    // 从历史数据生成 trendData
    final trendData = historyData.map((entry) {
      return {
        'date': entry.key.toIso8601String(),
        'avg_age': entry.value,
      };
    }).toList();

    return MoneyAgeDashboard(
      avgMoneyAge: days.toDouble(),
      medianMoneyAge: days,
      currentHealthLevel: healthLevel,
      healthCount: days >= 14 ? 1 : 0,
      warningCount: days >= 7 && days < 14 ? 1 : 0,
      dangerCount: days < 7 ? 1 : 0,
      totalResourcePools: 1,
      activeResourcePools: 1,
      totalRemainingAmount: localMoneyAge.totalBalance,
      trendData: trendData,
    );
  }

  Color _getLevelColor(MoneyAgeLevel level) {
    switch (level) {
      case MoneyAgeLevel.danger:
        return const Color(0xFFE57373);
      case MoneyAgeLevel.warning:
        return const Color(0xFFFFB74D);
      case MoneyAgeLevel.normal:
        return const Color(0xFFFFD54F);
      case MoneyAgeLevel.good:
        return const Color(0xFF64B5F6);
      case MoneyAgeLevel.excellent:
        return const Color(0xFF66BB6A);
      case MoneyAgeLevel.ideal:
        return const Color(0xFF66BB6A);
    }
  }

  String _getLevelEmoji(MoneyAgeLevel level) {
    switch (level) {
      case MoneyAgeLevel.danger:
        return '⚠️';
      case MoneyAgeLevel.warning:
        return '🟠';
      case MoneyAgeLevel.normal:
        return '🟡';
      case MoneyAgeLevel.good:
        return '🟢';
      case MoneyAgeLevel.excellent:
        return '🏆';
      case MoneyAgeLevel.ideal:
        return '💎';
    }
  }

  int _getLevelNumber(MoneyAgeLevel level) {
    return level.index + 1;
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('什么是钱龄？'),
        content: const Text(
          '钱龄是指您花出去的钱，平均是多少天前赚到的。\n\n'
          '• 钱龄越高，说明您的财务缓冲越充足\n'
          '• 钱龄30天以上表示您有一个月的缓冲\n'
          '• 基于FIFO（先进先出）原则计算\n\n'
          '提高钱龄的方法：\n'
          '1. 增加收入或储蓄\n'
          '2. 减少非必要支出\n'
          '3. 建立应急基金',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _navigateToUpgradeGuide(BuildContext context, int averageAge, LevelDetails levelDetails) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoneyAgeUpgradePage(
          currentAge: averageAge,
          levelDetails: levelDetails,
        ),
      ),
    );
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MoneyAgeHistoryPage()),
    );
  }

  void _navigateToStageProgress(BuildContext context, int averageAge, StageProgress stageProgress) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoneyAgeStagePage(
          currentAge: averageAge,
          stageProgress: stageProgress,
        ),
      ),
    );
  }
}

// ============================================================
// 钱龄升级引导页 (2.02)
// ============================================================

/// 钱龄升级引导页
/// 原��设计 2.02：钱龄升级引导
class MoneyAgeUpgradePage extends ConsumerStatefulWidget {
  final int currentAge;
  final LevelDetails levelDetails;

  const MoneyAgeUpgradePage({
    super.key,
    required this.currentAge,
    required this.levelDetails,
  });

  @override
  ConsumerState<MoneyAgeUpgradePage> createState() => _MoneyAgeUpgradePageState();
}

/// 建议卡片数据
class _ActionSuggestion {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String effect;
  final Color effectColor;
  final double progress;
  final List<String>? details;

  const _ActionSuggestion({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.effect,
    required this.effectColor,
    required this.progress,
    this.details,
  });
}

class _MoneyAgeUpgradePageState extends ConsumerState<MoneyAgeUpgradePage> {
  final List<_ActionSuggestion> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final db = sl<IDatabaseService>() as DatabaseService;

      // 使用现有的 ActionableInsightService
      final insightService = ActionableInsightService(
        db,
        SubscriptionTrackingService(db),
        LatteFactorAnalyzer(db),
      );

      // 生成所有洞察
      final insights = await insightService.generateInsights();
      debugPrint('[MoneyAgeUpgradePage] 生成了 ${insights.length} 条洞察');

      // 转换为建议卡片
      final suggestions = <_ActionSuggestion>[];
      for (final actionableInsight in insights) {
        debugPrint('[MoneyAgeUpgradePage] 洞察类型: ${actionableInsight.insight.type}');
        debugPrint('[MoneyAgeUpgradePage] 标题: ${actionableInsight.insight.title}');
        debugPrint('[MoneyAgeUpgradePage] 描述: ${actionableInsight.insight.description}');
        debugPrint('[MoneyAgeUpgradePage] 潜在节省: ${actionableInsight.insight.potentialSavings}');
        final suggestion = _convertInsightToSuggestion(actionableInsight);
        if (suggestion != null) {
          suggestions.add(suggestion);
        }
      }

      debugPrint('[MoneyAgeUpgradePage] 转换后有 ${suggestions.length} 条建议');

      if (mounted) {
        setState(() {
          _suggestions.clear();
          _suggestions.addAll(suggestions);
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[MoneyAgeUpgradePage] 加载建议失败: $e');
      debugPrint('[MoneyAgeUpgradePage] 堆栈: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 将洞察转换为建议卡片
  _ActionSuggestion? _convertInsightToSuggestion(ActionableInsight actionableInsight) {
    final insight = actionableInsight.insight;

    // 根据洞察类型生成不同的建议卡片
    switch (insight.type) {
      case InsightType.subscriptionOverload:
        return _ActionSuggestion(
          icon: Icons.subscriptions,
          iconBgColor: const Color(0xFFEBF3FF),
          iconColor: AppColors.info,
          title: insight.title,
          subtitle: insight.description,
          effect: insight.potentialSavings != null
              ? '+${(insight.potentialSavings! / 1000).ceil()}天'
              : '+1天',
          effectColor: AppColors.info,
          progress: 0.0,
          details: actionableInsight.actionGuides.map((g) => g.title).toList().cast<String>(),
        );

      case InsightType.latteFactor:
      case InsightType.recurringExpenseOptimization:
        return _ActionSuggestion(
          icon: Icons.restaurant,
          iconBgColor: const Color(0xFFFFF3E0),
          iconColor: AppColors.warning,
          title: insight.title,
          subtitle: insight.description,
          effect: insight.potentialSavings != null
              ? '+${(insight.potentialSavings! / 1000).ceil()}天'
              : '+2天',
          effectColor: AppColors.warning,
          progress: 0.3,
          details: actionableInsight.actionGuides.map((g) => g.title).toList().cast<String>(),
        );

      case InsightType.budgetOverrunRisk:
      case InsightType.savingsOpportunity:
        return _ActionSuggestion(
          icon: Icons.savings,
          iconBgColor: const Color(0xFFE8F5E9),
          iconColor: AppColors.success,
          title: insight.title,
          subtitle: insight.description,
          effect: insight.potentialSavings != null
              ? '+${(insight.potentialSavings! / 500).ceil()}天'
              : '+5天',
          effectColor: AppColors.success,
          progress: 0.0,
          details: actionableInsight.actionGuides.map((g) => g.title).toList().cast<String>(),
        );

      default:
        // 其他类型的洞察暂不显示
        return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextLevel = widget.levelDetails.nextLevel;
    final targetAge = nextLevel?.minDays ?? 90;
    final daysNeeded = targetAge - widget.currentAge;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 页面头部
            _buildPageHeader(context, theme, nextLevel),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // 目标展示
                          _buildTargetDisplay(context, theme, targetAge, daysNeeded),
                          const SizedBox(height: 24),
                          // 动态生成的行动卡片
                          if (_suggestions.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  '暂无可优化项，继续保持良好的财务习惯！',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            ...List.generate(_suggestions.length, (index) {
                              final suggestion = _suggestions[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < _suggestions.length - 1 ? 12 : 0,
                                ),
                                child: _buildActionCard(
                                  context,
                                  theme,
                                  icon: suggestion.icon,
                                  iconBgColor: suggestion.iconBgColor,
                                  iconColor: suggestion.iconColor,
                                  title: suggestion.title,
                                  subtitle: suggestion.subtitle,
                                  effect: suggestion.effect,
                                  effectColor: suggestion.effectColor,
                                  progress: suggestion.progress,
                                  details: suggestion.details,
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
            ),
            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 开始执行计划
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '开始执行计划',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme, MoneyAgeLevel? nextLevel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              nextLevel != null ? '升级到 Lv.${nextLevel.index + 1}' : '保持当前等级',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTargetDisplay(BuildContext context, ThemeData theme, int targetAge, int daysNeeded) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, const Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$targetAge',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Text(
                '天',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '目标钱龄',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '还需提升$daysNeeded天',
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String effect,
    required Color effectColor,
    required double progress,
    List<String>? details, // 可选的详细信息列表
  }) {
    return _ExpandableActionCard(
      icon: icon,
      iconBgColor: iconBgColor,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      effect: effect,
      effectColor: effectColor,
      progress: progress,
      details: details,
    );
  }
}

/// 可展开的行动卡片
class _ExpandableActionCard extends StatefulWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String effect;
  final Color effectColor;
  final double progress;
  final List<String>? details;

  const _ExpandableActionCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.effect,
    required this.effectColor,
    required this.progress,
    this.details,
  });

  @override
  State<_ExpandableActionCard> createState() => _ExpandableActionCardState();
}

class _ExpandableActionCardState extends State<_ExpandableActionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDetails = widget.details != null && widget.details!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasDetails
              ? () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.iconBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(widget.icon, color: widget.iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (hasDetails)
                                Icon(
                                  _isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.effectColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.effect,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.effectColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 进度条
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.effectColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // 展开的详细信息
                if (_isExpanded && hasDetails) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.iconBgColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.details!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final detail = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < widget.details!.length - 1 ? 8 : 0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: widget.iconColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  detail,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 钱龄历史趋势页 (2.03)
// ============================================================

/// 钱龄历史趋势页
/// 原型设计 2.03：钱龄历史趋势
class MoneyAgeHistoryPage extends ConsumerStatefulWidget {
  const MoneyAgeHistoryPage({super.key});

  @override
  ConsumerState<MoneyAgeHistoryPage> createState() => _MoneyAgeHistoryPageState();
}

class _MoneyAgeHistoryPageState extends ConsumerState<MoneyAgeHistoryPage> {
  int _selectedPeriod = 1; // 默认近30天
  final List<String> _periods = ['近7天', '近30天', '近3月', '今年'];

  /// 根据选择的周期获取天数
  int _getDaysForPeriod() {
    switch (_selectedPeriod) {
      case 0: return 7;
      case 1: return 30;
      case 2: return 90;
      case 3: return 365;
      default: return 30;
    }
  }

  /// 从 dashboard.trendData 生成 DailyMoneyAge 列表
  List<DailyMoneyAge> _getTrendData(MoneyAgeDashboard? dashboard) {
    if (dashboard == null || dashboard.trendData.isEmpty) {
      return [];
    }

    final days = _getDaysForPeriod();
    final levelService = MoneyAgeLevelService();
    final result = <DailyMoneyAge>[];

    // 计算日期范围
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    for (final item in dashboard.trendData) {
      final dateStr = item['date'] as String?;
      final avgAge = (item['avg_age'] as num?)?.toInt() ?? 0;

      // 允许负值钱龄
      if (dateStr != null) {
        try {
          final date = DateTime.parse(dateStr);
          // 根据日期范围过滤数据
          if (date.isAfter(startDate) || date.isAtSameMomentAs(startDate)) {
            final level = levelService.determineLevel(avgAge);
            result.add(DailyMoneyAge(date: date, averageAge: avgAge, level: level));
          }
        } catch (_) {
          // 跳过无效日期
        }
      }
    }

    // 按日期排序（从旧到新）
    result.sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ledgerContext = ref.watch(ledgerContextProvider);
    final bookId = ledgerContext.currentLedger?.id;

    // 获取钱龄数据
    final dashboardAsync = bookId != null
        ? ref.watch(moneyAgeDashboardProvider(bookId))
        : const AsyncValue<MoneyAgeDashboard?>.data(null);

    // 本地历史数据作为备用
    final localMoneyAge = ref.watch(moneyAgeProvider);
    final moneyAgeHistory = ref.watch(moneyAgeHistoryProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 页面头部
            _buildPageHeader(context, theme),
            // 周期选择器
            _buildPeriodSelector(context, theme),
            Expanded(
              child: dashboardAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('加载失败: $error')),
                data: (dashboard) {
                  // 如果 API 返回的 trendData 为空，使用本地历史数据
                  final effectiveDashboard = (dashboard != null && dashboard.trendData.isNotEmpty)
                      ? dashboard
                      : _createDashboardFromLocal(localMoneyAge, moneyAgeHistory);

                  final trendData = _getTrendData(effectiveDashboard);
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // 图表区域
                        _buildTrendChart(context, theme, trendData),
                        // 统计摘要
                        _buildStatsSummary(context, theme, trendData),
                        // 每日记录
                        _buildDailyRecords(context, theme, trendData),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 从本地数据创建 Dashboard（与 MoneyAgePage 保持一致）
  MoneyAgeDashboard _createDashboardFromLocal(
    budget_model.MoneyAge localMoneyAge,
    List<MapEntry<DateTime, int>> historyData,
  ) {
    final days = localMoneyAge.days;
    final healthLevel = days >= 30 ? 'good' : (days >= 14 ? 'normal' : (days >= 7 ? 'warning' : 'danger'));

    // 从历史数据生成 trendData
    final trendData = historyData.map((entry) {
      return {
        'date': entry.key.toIso8601String(),
        'avg_age': entry.value,
      };
    }).toList();

    return MoneyAgeDashboard(
      avgMoneyAge: days.toDouble(),
      medianMoneyAge: days,
      currentHealthLevel: healthLevel,
      healthCount: days >= 14 ? 1 : 0,
      warningCount: days >= 7 && days < 14 ? 1 : 0,
      dangerCount: days < 7 ? 1 : 0,
      totalResourcePools: 1,
      activeResourcePools: 1,
      totalRemainingAmount: localMoneyAge.totalBalance,
      trendData: trendData,
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: Text(
              '钱龄历史',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _periods[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 真实的钱龄趋势图
  Widget _buildTrendChart(BuildContext context, ThemeData theme, List<DailyMoneyAge> trendData) {
    if (trendData.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            '暂无趋势数据',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // 按日期排序（旧到新）
    final sortedData = List<DailyMoneyAge>.from(trendData)
      ..sort((a, b) => a.date.compareTo(b.date));

    // 生成折线图数据点
    final spots = sortedData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.averageAge.toDouble());
    }).toList();

    // 计算Y轴范围（允许负值）
    final ages = sortedData.map((d) => d.averageAge).toList();
    final minAge = ages.reduce((a, b) => a < b ? a : b);
    final maxAge = ages.reduce((a, b) => a > b ? a : b);
    final yMin = (minAge - 5).toDouble(); // 不再限制为0
    final yMax = (maxAge + 10).toDouble();

    // 根据是否有负值决定颜色
    final hasNegative = minAge < 0;
    final lineColor = hasNegative ? AppColors.warning : AppColors.success;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      height: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '钱龄变化趋势',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (hasNegative) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '有透支',
                    style: TextStyle(fontSize: 10, color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: sortedData.length <= 15,
                      getDotPainter: (spot, percent, barData, index) {
                        // 根据值正负决定点的颜色
                        final dotColor = spot.y >= 0 ? AppColors.success : AppColors.error;
                        return FlDotCirclePainter(
                          radius: 3,
                          color: dotColor,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedData.length) {
                          return const SizedBox.shrink();
                        }
                        // 只显示部分日期
                        if (sortedData.length <= 7 ||
                            index == 0 ||
                            index == sortedData.length - 1 ||
                            index % (sortedData.length ~/ 4) == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('M/d').format(sortedData[index].date),
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 22,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (yMax - yMin) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final index = spot.spotIndex;
                        if (index < 0 || index >= sortedData.length) {
                          return null;
                        }
                        return LineTooltipItem(
                          '${DateFormat('M月d日').format(sortedData[index].date)}\n${spot.y.toInt()}天',
                          TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: yMin,
                maxY: yMax,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(BuildContext context, ThemeData theme, List<DailyMoneyAge> trendData) {
    // 计算真实统计数据
    int avgAge = 0;
    int maxAge = 0;
    int minAge = 0;

    if (trendData.isNotEmpty) {
      final ages = trendData.map((d) => d.averageAge).toList();
      avgAge = (ages.reduce((a, b) => a + b) / ages.length).round();
      maxAge = ages.reduce((a, b) => a > b ? a : b);
      minAge = ages.reduce((a, b) => a < b ? a : b);
    }

    // 根据值正负决定颜色
    final avgColor = avgAge >= 0 ? AppColors.success : AppColors.error;
    final maxColor = maxAge >= 0 ? AppColors.success : AppColors.error;
    final minColor = minAge >= 0 ? null : AppColors.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('平均钱龄', trendData.isEmpty ? '--' : '$avgAge', avgColor),
          _buildSummaryItem('最高', trendData.isEmpty ? '--' : '$maxAge', maxColor),
          _buildSummaryItem('最低', trendData.isEmpty ? '--' : '$minAge', minColor),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color? valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDailyRecords(BuildContext context, ThemeData theme, List<DailyMoneyAge> trendData) {
    if (trendData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            '暂无每日记录',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // 按日期降序排列（最新的在前）
    final sortedData = List<DailyMoneyAge>.from(trendData)
      ..sort((a, b) => b.date.compareTo(a.date));

    // 只显示最近10条
    final displayData = sortedData.take(10).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每日记录',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...displayData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final dataDate = DateTime(data.date.year, data.date.month, data.date.day);

            String title;
            String subtitle;

            if (dataDate == today) {
              title = '今天';
              subtitle = DateFormat('M月d日').format(data.date);
            } else if (dataDate == yesterday) {
              title = '昨天';
              subtitle = DateFormat('M月d日').format(data.date);
            } else {
              title = DateFormat('M月d日').format(data.date);
              subtitle = DateFormat('EEEE', 'zh_CN').format(data.date);
            }

            // 计算与前一天的变化
            int change = 0;
            if (index < displayData.length - 1) {
              change = data.averageAge - displayData[index + 1].averageAge;
            }

            return _buildDayRecord(theme, title, subtitle, data.averageAge, change);
          }),
        ],
      ),
    );
  }

  Widget _buildDayRecord(ThemeData theme, String title, String subtitle, int age, int change) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$age天',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  // 负值显示红色，正值且上升显示绿色
                  color: age < 0 ? AppColors.error : (change > 0 ? AppColors.success : null),
                ),
              ),
              Text(
                change > 0
                    ? '↑ $change天'
                    : change < 0
                        ? '↓ ${change.abs()}天'
                        : '- 0天',
                style: TextStyle(
                  fontSize: 12,
                  color: change > 0
                      ? AppColors.success
                      : change < 0
                          ? AppColors.error
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 钱龄阶段进度页 (2.05)
// ============================================================

/// 钱龄阶段进度页
/// 原型设计 2.05：钱龄阶段进度
class MoneyAgeStagePage extends StatelessWidget {
  final int currentAge;
  final StageProgress stageProgress;

  const MoneyAgeStagePage({
    super.key,
    required this.currentAge,
    required this.stageProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 页面头部
            _buildPageHeader(context, theme),
            // 当前阶段展示
            _buildCurrentStageDisplay(context, theme),
            // 6级阶段进度
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildStageItem(context, theme, 1, '起步', 7, '🔴', true),
                  _buildStageItem(context, theme, 2, '警醒', 14, '🟠', currentAge >= 7),
                  _buildStageItem(context, theme, 3, '稳健', 30, '🟡', currentAge >= 14),
                  _buildStageItem(context, theme, 4, '良好', 60, '🟢', currentAge >= 30, isCurrent: currentAge >= 30 && currentAge < 60),
                  _buildStageItem(context, theme, 5, '优秀', 90, '🔵', currentAge >= 60),
                  _buildStageItem(context, theme, 6, '财务自由', null, '💎', currentAge >= 90),
                ],
              ),
            ),
            // 底部按钮
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.rocket_launch, size: 20),
                  label: const Text('开始升级挑战'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: Text(
              '我的财务阶段',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildCurrentStageDisplay(BuildContext context, ThemeData theme) {
    // 负钱龄使用红色
    final isNegative = currentAge < 0;
    final gradientColors = isNegative
        ? [const Color(0xFFE57373), const Color(0xFFEF5350)]
        : [const Color(0xFF66BB6A), const Color(0xFF4CAF50)];
    final shadowColor = isNegative
        ? const Color(0xFFC62828).withValues(alpha: 0.3)
        : const Color(0xFF2E7D32).withValues(alpha: 0.3);
    final labelColor = isNegative ? AppColors.error : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$currentAge',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  '天',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isNegative ? '⚠️ 透支状态' : '🏆 ${stageProgress.currentStage.name}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isNegative
                ? '已透支${-currentAge}天的收入额度'
                : '您花的钱平均是$currentAge天前赚的',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageItem(
    BuildContext context,
    ThemeData theme,
    int level,
    String name,
    int? minDays,
    String emoji,
    bool isAchieved, {
    bool isCurrent = false,
  }) {
    Color bgColor;
    Color borderColor;
    Widget leadingWidget;

    if (isCurrent) {
      bgColor = const Color(0xFFEBF3FF);
      borderColor = theme.colorScheme.primary;
      leadingWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$currentAge',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (isAchieved) {
      bgColor = const Color(0xFFE8F5E9);
      borderColor = AppColors.success;
      leadingWidget = Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 20),
      );
    } else {
      bgColor = theme.colorScheme.surfaceContainerHighest;
      borderColor = theme.colorScheme.outline;
      leadingWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.outline,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock, color: Colors.white, size: 20),
      );
    }

    String subtitle;
    if (isCurrent && stageProgress.nextStage != null) {
      final daysToNext = stageProgress.daysToNextStage ?? 0;
      subtitle = '钱龄 ${minDays ?? 0}-${stageProgress.nextStage!.minDays}天 · 还需$daysToNext天升级';
    } else if (minDays != null) {
      subtitle = '钱龄 > $minDays天';
    } else {
      subtitle = '钱龄 > 90天';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          leadingWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Lv.$level $name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isAchieved && !isCurrent)
                      Text(
                        '已达成',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                        ),
                      ),
                    if (isCurrent)
                      Text(
                        '当前',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(emoji, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
