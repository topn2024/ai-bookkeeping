import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/resource_pool.dart';
import '../services/money_age_level_service.dart';
import '../theme/app_theme.dart';

/// 钱龄详情页
/// 原型设计 2.01：钱龄详情 Money Age Detail
/// - 核心数据区：钱龄数字 + 等级徽章
/// - 统计数据行：本月最高/最低/较上月
/// - 等级进度条（紧凑版）
/// - 趋势迷你图
/// - ���金区：行动按钮
class MoneyAgePage extends ConsumerStatefulWidget {
  const MoneyAgePage({super.key});

  @override
  ConsumerState<MoneyAgePage> createState() => _MoneyAgePageState();
}

class _MoneyAgePageState extends ConsumerState<MoneyAgePage> {
  // TODO: 替换为真实的 provider
  late MoneyAgeStatistics _stats;
  late MoneyAgeLevelService _levelService;
  late StageProgress _stageProgress;
  late LevelDetails _levelDetails;

  @override
  void initState() {
    super.initState();
    _levelService = MoneyAgeLevelService();
    _stats = _getMockStatistics();
    _stageProgress = _levelService.getStageProgress(_stats.averageAge);
    _levelDetails = _levelService.getLevelDetails(_stats.averageAge);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 页面头部
            _buildPageHeader(context, theme),
            // 主内容区
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 核心数据区
                    _buildCoreDataSection(context, theme),
                    // 统计数据行
                    _buildStatsRow(context, theme),
                    // 等级进度条
                    _buildLevelProgressCard(context, theme),
                    // 趋势迷你图
                    _buildTrendMiniChart(context, theme),
                  ],
                ),
              ),
            ),
            // 黄金区：行动按钮
            _buildActionButton(context, theme),
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
  Widget _buildCoreDataSection(BuildContext context, ThemeData theme) {
    final levelColor = _getLevelColor(_levelDetails.level);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            levelColor.withValues(alpha: 0.15),
            levelColor.withValues(alpha: 0.08),
          ],
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
                '${_stats.averageAge}',
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
          // 等级徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: levelColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_getLevelEmoji(_levelDetails.level)} ${_levelDetails.level.displayName} Lv.${_getLevelNumber(_levelDetails.level)}',
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
  Widget _buildStatsRow(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '本月最高',
              value: '${_stats.monthlyMax}天',
              valueColor: AppColors.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '本月最低',
              value: '${_stats.monthlyMin}天',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              context,
              theme,
              label: '较上月',
              value: _stats.monthlyChange >= 0
                  ? '+${_stats.monthlyChange}天'
                  : '${_stats.monthlyChange}天',
              valueColor:
                  _stats.monthlyChange >= 0 ? AppColors.success : AppColors.error,
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
  Widget _buildLevelProgressCard(BuildContext context, ThemeData theme) {
    final nextStage = _stageProgress.nextStage;
    final daysToNext = _stageProgress.daysToNextStage;

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
                onTap: () => _navigateToStageProgress(context),
                child: Text(
                  nextStage != null ? '距Lv.${_getLevelNumber(_levelService.determineLevel(nextStage.minDays))}还需$daysToNext天 →' : '已达最高等级',
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
              final isAchieved = index < _getLevelNumber(_levelDetails.level);
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
  Widget _buildTrendMiniChart(BuildContext context, ThemeData theme) {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _stats.monthlyChange >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: _stats.monthlyChange >= 0 ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _stats.monthlyChange >= 0 ? '稳步上升中' : '有所下降',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 黄金区：行动按钮
  Widget _buildActionButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _navigateToUpgradeGuide(context),
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

  void _navigateToUpgradeGuide(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoneyAgeUpgradePage(
          currentAge: _stats.averageAge,
          levelDetails: _levelDetails,
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

  void _navigateToStageProgress(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MoneyAgeStagePage(
          currentAge: _stats.averageAge,
          stageProgress: _stageProgress,
        ),
      ),
    );
  }

  // Mock 数据
  MoneyAgeStatistics _getMockStatistics() {
    return MoneyAgeStatistics(
      averageAge: 42,
      monthlyMax: 48,
      monthlyMin: 35,
      monthlyChange: 5,
      trendData: [],
    );
  }
}

/// 钱龄统计数据
class MoneyAgeStatistics {
  final int averageAge;
  final int monthlyMax;
  final int monthlyMin;
  final int monthlyChange;
  final List<MoneyAgeTrendPoint> trendData;

  const MoneyAgeStatistics({
    required this.averageAge,
    required this.monthlyMax,
    required this.monthlyMin,
    required this.monthlyChange,
    required this.trendData,
  });
}

class MoneyAgeTrendPoint {
  final DateTime date;
  final int age;

  const MoneyAgeTrendPoint({required this.date, required this.age});
}

// ============================================================
// 钱龄升级引导页 (2.02)
// ============================================================

/// 钱龄升级引导页
/// 原��设计 2.02：钱龄升级引导
class MoneyAgeUpgradePage extends StatelessWidget {
  final int currentAge;
  final LevelDetails levelDetails;

  const MoneyAgeUpgradePage({
    super.key,
    required this.currentAge,
    required this.levelDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextLevel = levelDetails.nextLevel;
    final targetAge = nextLevel?.minDays ?? 90;
    final daysNeeded = targetAge - currentAge;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 页面头部
            _buildPageHeader(context, theme, nextLevel),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 目标展示
                    _buildTargetDisplay(context, theme, targetAge, daysNeeded),
                    const SizedBox(height: 24),
                    // 行动卡片
                    _buildActionCard(
                      context,
                      theme,
                      icon: Icons.savings,
                      iconBgColor: const Color(0xFFE8F5E9),
                      iconColor: AppColors.success,
                      title: '增加应急金储蓄',
                      subtitle: '每月多存¥500',
                      effect: '+5天',
                      effectColor: AppColors.success,
                      progress: 0.0,
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      context,
                      theme,
                      icon: Icons.restaurant,
                      iconBgColor: const Color(0xFFFFF3E0),
                      iconColor: AppColors.warning,
                      title: '减少外卖支出',
                      subtitle: '每周少点2次外卖',
                      effect: '+2天',
                      effectColor: AppColors.warning,
                      progress: 0.3,
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      context,
                      theme,
                      icon: Icons.subscriptions,
                      iconBgColor: const Color(0xFFEBF3FF),
                      iconColor: AppColors.info,
                      title: '取消闲置订阅',
                      subtitle: '发现2个未使用的订阅',
                      effect: '+1天',
                      effectColor: AppColors.info,
                      progress: 0.0,
                    ),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: effectColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  effect,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: effectColor,
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
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: effectColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 钱龄历史趋势页 (2.03)
// ============================================================

/// 钱龄历史趋势页
/// 原型设计 2.03：钱龄历史趋势
class MoneyAgeHistoryPage extends StatefulWidget {
  const MoneyAgeHistoryPage({super.key});

  @override
  State<MoneyAgeHistoryPage> createState() => _MoneyAgeHistoryPageState();
}

class _MoneyAgeHistoryPageState extends State<MoneyAgeHistoryPage> {
  int _selectedPeriod = 1; // 默认近30天
  final List<String> _periods = ['近7天', '近30天', '近3月', '今年'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 页面头部
            _buildPageHeader(context, theme),
            // 周期选择器
            _buildPeriodSelector(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 图表区域
                    _buildChartPlaceholder(context, theme),
                    // 统计摘要
                    _buildStatsSummary(context, theme),
                    // 每日记录
                    _buildDailyRecords(context, theme),
                  ],
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

  Widget _buildChartPlaceholder(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              '钱龄变化趋势图',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary(BuildContext context, ThemeData theme) {
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
          _buildSummaryItem('平均钱龄', '42', AppColors.success),
          _buildSummaryItem('最高', '48', null),
          _buildSummaryItem('最低', '35', null),
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

  Widget _buildDailyRecords(BuildContext context, ThemeData theme) {
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
          _buildDayRecord(theme, '今天', '1月2日', 42, 2),
          _buildDayRecord(theme, '昨天', '1月1日', 40, 0),
          _buildDayRecord(theme, '12月31日', '周二', 40, -3),
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
                  color: change > 0 ? AppColors.success : null,
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF66BB6A), Color(0xFF4CAF50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
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
            '🏆 ${stageProgress.currentStage.name}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '您花的钱平均是$currentAge天前赚的',
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
