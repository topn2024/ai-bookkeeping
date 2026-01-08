import 'package:flutter/material.dart';
import '../services/accuracy_growth_service.dart';

/// Accuracy growth curve visualization widget (第23章准确率成长曲线可视化)
class AccuracyGrowthWidget extends StatelessWidget {
  final AccuracyGrowthCurve curve;
  final VoidCallback? onViewDetails;

  const AccuracyGrowthWidget({
    super.key,
    required this.curve,
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
                '识别准确率',
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

          // Current accuracy display
          _buildCurrentAccuracy(theme),
          const SizedBox(height: 16),

          // Growth phase indicator
          _buildGrowthPhase(theme),
          const SizedBox(height: 16),

          // Mini chart
          if (curve.dataPoints.isNotEmpty) ...[
            SizedBox(
              height: 80,
              child: _buildMiniChart(theme),
            ),
            const SizedBox(height: 8),
          ],

          // Projection
          if (curve.projectedDaysToTarget != null && curve.currentAccuracy < 0.95)
            _buildProjection(theme),
        ],
      ),
    );
  }

  Widget _buildCurrentAccuracy(ThemeData theme) {
    final percentage = (curve.currentAccuracy * 100).toStringAsFixed(1);
    final color = _getAccuracyColor(curve.currentAccuracy);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$percentage%',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '当前准确率',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrowthPhase(ThemeData theme) {
    final phase = curve.growthPhase;
    final color = _getPhaseColor(phase);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getPhaseIcon(phase),
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  phase.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChart(ThemeData theme) {
    return CustomPaint(
      size: const Size(double.infinity, 80),
      painter: AccuracyChartPainter(
        dataPoints: curve.dataPoints,
        lineColor: theme.colorScheme.primary,
        fillColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        gridColor: theme.dividerColor,
      ),
    );
  }

  Widget _buildProjection(ThemeData theme) {
    final days = curve.projectedDaysToTarget!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              days > 0
                  ? '预计 $days 天后达到95%目标'
                  : '已达到目标准确率',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.95) return Colors.green;
    if (accuracy >= 0.90) return Colors.lightGreen;
    if (accuracy >= 0.85) return Colors.amber;
    if (accuracy >= 0.80) return Colors.orange;
    return Colors.red;
  }

  Color _getPhaseColor(GrowthPhase phase) {
    switch (phase) {
      case GrowthPhase.learning:
        return Colors.orange;
      case GrowthPhase.developing:
        return Colors.amber;
      case GrowthPhase.improving:
        return Colors.lightGreen;
      case GrowthPhase.proficient:
        return Colors.green;
      case GrowthPhase.mastery:
        return Colors.teal;
    }
  }

  IconData _getPhaseIcon(GrowthPhase phase) {
    switch (phase) {
      case GrowthPhase.learning:
        return Icons.school;
      case GrowthPhase.developing:
        return Icons.trending_up;
      case GrowthPhase.improving:
        return Icons.rocket_launch;
      case GrowthPhase.proficient:
        return Icons.star;
      case GrowthPhase.mastery:
        return Icons.emoji_events;
    }
  }
}

/// Accuracy chart painter
class AccuracyChartPainter extends CustomPainter {
  final List<AccuracyDataPoint> dataPoints;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  AccuracyChartPainter({
    required this.dataPoints,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Horizontal grid lines at 70%, 80%, 90%, 100%
    for (final threshold in [0.7, 0.8, 0.9, 1.0]) {
      final y = size.height - (size.height * (threshold - 0.6) / 0.4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Calculate points
    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * size.width / (dataPoints.length - 1);
      final y = size.height - (size.height * (dataPoints[i].accuracy - 0.6) / 0.4);
      points.add(Offset(x, y.clamp(0, size.height)));
    }

    // Draw fill
    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, size.height);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw current point
    if (points.isNotEmpty) {
      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points.last, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AccuracyChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints;
  }
}

/// Accuracy by type breakdown widget
class AccuracyByTypeWidget extends StatelessWidget {
  final Map<RecognitionType, double> accuracyByType;

  const AccuracyByTypeWidget({
    super.key,
    required this.accuracyByType,
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
            '各场景准确率',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          ...accuracyByType.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildTypeRow(theme, entry.key, entry.value),
          )),
        ],
      ),
    );
  }

  Widget _buildTypeRow(ThemeData theme, RecognitionType type, double accuracy) {
    final percentage = (accuracy * 100).toStringAsFixed(0);

    return Row(
      children: [
        Icon(
          _getTypeIcon(type),
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(type.displayName),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: LinearProgressIndicator(
            value: accuracy,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              accuracy >= 0.9 ? Colors.green :
              accuracy >= 0.8 ? Colors.amber : Colors.orange,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$percentage%',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getTypeIcon(RecognitionType type) {
    switch (type) {
      case RecognitionType.voice:
        return Icons.mic;
      case RecognitionType.camera:
        return Icons.camera_alt;
      case RecognitionType.manual:
        return Icons.edit;
      case RecognitionType.import_:
        return Icons.file_upload;
    }
  }
}

/// Milestone celebration widget
class MilestoneCelebrationWidget extends StatelessWidget {
  final AccuracyMilestone milestone;
  final VoidCallback? onDismiss;

  const MilestoneCelebrationWidget({
    super.key,
    required this.milestone,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.celebration,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            '恭喜达成新里程碑!',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            milestone.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (onDismiss != null)
            FilledButton(
              onPressed: onDismiss,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
              ),
              child: const Text('太棒了'),
            ),
        ],
      ),
    );
  }
}
