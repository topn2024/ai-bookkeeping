import 'package:flutter/material.dart';
import '../services/scenario_timing_service.dart';

/// Scenario timing display widget (第23章场景化耗时统计展示)
class ScenarioTimingWidget extends StatelessWidget {
  final Map<TransactionScenario, ScenarioTimingStats> stats;
  final TransactionScenario? fastestScenario;
  final Duration? totalTimeSaved;
  final VoidCallback? onViewDetails;

  const ScenarioTimingWidget({
    super.key,
    required this.stats,
    this.fastestScenario,
    this.totalTimeSaved,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '记账效率',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onViewDetails != null)
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text('详情'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Time saved highlight
          if (totalTimeSaved != null && totalTimeSaved!.inSeconds > 0)
            _buildTimeSavedCard(theme),

          const SizedBox(height: 16),

          // Scenario comparison
          ...stats.entries
              .where((e) => e.value.sampleSize > 0)
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildScenarioRow(theme, e.key, e.value),
                  )),

          // Fastest scenario badge
          if (fastestScenario != null) _buildFastestBadge(theme),
        ],
      ),
    );
  }

  Widget _buildTimeSavedCard(ThemeData theme) {
    final minutes = totalTimeSaved!.inMinutes;
    final displayTime = minutes >= 60
        ? '${(minutes / 60).toStringAsFixed(1)} 小时'
        : '$minutes 分钟';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.timer,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '累计节省时间',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  displayTime,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioRow(
    ThemeData theme,
    TransactionScenario scenario,
    ScenarioTimingStats stat,
  ) {
    final isFastest = scenario == fastestScenario;
    final avgSeconds = stat.averageDuration.inSeconds;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFastest
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: isFastest
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            _getScenarioIcon(scenario),
            size: 24,
            color: isFastest
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      scenario.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isFastest) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.bolt,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                Text(
                  '${stat.sampleSize} 次记录',
                  style: theme.textTheme.bodySmall?.copyWith(
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
                '${avgSeconds}s',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isFastest ? theme.colorScheme.primary : null,
                ),
              ),
              Text(
                '平均耗时',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFastestBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events,
            color: Colors.green.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${fastestScenario!.displayName} 是您最高效的记账方式',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getScenarioIcon(TransactionScenario scenario) {
    switch (scenario) {
      case TransactionScenario.voice:
        return Icons.mic;
      case TransactionScenario.camera:
        return Icons.camera_alt;
      case TransactionScenario.manual:
        return Icons.edit;
      case TransactionScenario.template:
        return Icons.bookmark;
      case TransactionScenario.import_:
        return Icons.file_upload;
    }
  }
}

/// Weekly timing trend chart
class WeeklyTimingTrendWidget extends StatelessWidget {
  final List<DailyTimingSummary> weeklyData;

  const WeeklyTimingTrendWidget({
    super.key,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本周记账趋势',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyData.map((day) => _buildDayBar(theme, day)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBar(ThemeData theme, DailyTimingSummary day) {
    final maxHeight = 80.0;
    final maxCount = weeklyData
        .map((d) => d.totalTransactions)
        .fold(1, (a, b) => a > b ? a : b);
    final height = (day.totalTransactions / maxCount * maxHeight).clamp(4.0, maxHeight);

    final dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    final dayName = dayNames[day.date.weekday - 1];

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${day.totalTransactions}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: day.date.day == DateTime.now().day
                ? theme.colorScheme.primary
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dayName,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Efficiency recommendations widget
class EfficiencyRecommendationsWidget extends StatelessWidget {
  final List<String> recommendations;

  const EfficiencyRecommendationsWidget({
    super.key,
    required this.recommendations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                size: 20,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                '效率建议',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: theme.colorScheme.tertiary)),
                Expanded(
                  child: Text(
                    r,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
