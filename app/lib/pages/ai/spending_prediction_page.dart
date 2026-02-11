import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../extensions/category_extensions.dart';
import '../../services/category_localization_service.dart';
import '../../services/spending_insight_calculator.dart';
import '../budget_management_page.dart';

/// 消费趋势预测页面
///
/// 使用 WMA + 季节性调整算法进行真正的消费预测，
/// 与 AI 洞察页差异化：洞察=回顾性分析，预测=前瞻性预测
class SpendingPredictionPage extends ConsumerWidget {
  const SpendingPredictionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);
    final now = DateTime.now();

    // 检查是否有足够的历史数据（至少3个月有消费记录）
    final history = SpendingInsightCalculator.getMonthlyHistory(transactions, 6);
    final monthsWithData = history.where((h) => h.total > 0).length;
    final hasEnoughData = monthsWithData >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('趋势预测'),
      ),
      body: !hasEnoughData
          ? _InsufficientDataView(monthsWithData: monthsWithData)
          : ListView(
              children: [
                _MonthlyPredictionCard(
                  transactions: transactions,
                  year: now.year,
                  month: now.month,
                ),
                _HistoryTrendChart(
                  transactions: transactions,
                  year: now.year,
                  month: now.month,
                ),
                _CategoryPredictionSection(
                  transactions: transactions,
                  year: now.year,
                  month: now.month,
                ),
                _PredictionExplanation(
                  transactions: transactions,
                  month: now.month,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BudgetManagementPage()),
                      ),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('调整预算'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

/// 数据不足提示
class _InsufficientDataView extends StatelessWidget {
  final int monthsWithData;

  const _InsufficientDataView({required this.monthsWithData});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              '数据不足',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '趋势预测需要至少3个月的消费记录\n当前仅有 $monthsWithData 个月数据',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text(
              '继续记账，数据积累后将自动开启预测功能',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

/// 本月预测卡片
class _MonthlyPredictionCard extends StatelessWidget {
  final List<Transaction> transactions;
  final int year;
  final int month;

  const _MonthlyPredictionCard({
    required this.transactions,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final predicted = SpendingInsightCalculator.weightedMonthlyPrediction(
        transactions, year, month);
    final bounds = SpendingInsightCalculator.confidenceBounds(
        transactions, predicted);
    final confidence =
        SpendingInsightCalculator.predictionConfidence(transactions);

    // 本月已支出
    final spent = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == year &&
            t.date.month == month)
        .fold<double>(0, (sum, t) => sum + t.amount);

    final predictedRemaining = (predicted - spent).clamp(0.0, double.infinity);
    final progress = predicted > 0 ? spent / predicted : 0.0;
    final daysRemaining = DateTime(year, month + 1, 0).day - now.day;

    // 置信度标签
    String confidenceLabel;
    Color confidenceColor;
    if (confidence > 0.8) {
      confidenceLabel = '高';
      confidenceColor = Colors.greenAccent;
    } else if (confidence > 0.5) {
      confidenceLabel = '中';
      confidenceColor = Colors.amberAccent;
    } else {
      confidenceLabel = '低';
      confidenceColor = Colors.redAccent;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple[400]!, Colors.blue[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本月预计支出',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 12, color: confidenceColor),
                    const SizedBox(width: 4),
                    Text(
                      '置信度: $confidenceLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '¥${predicted.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '¥${bounds.lower.toStringAsFixed(0)} ~ ¥${bounds.upper.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _infoChip('已支出', '¥${spent.toStringAsFixed(0)}'),
              const SizedBox(width: 12),
              _infoChip('预计剩余', '¥${predictedRemaining.toStringAsFixed(0)}'),
              const Spacer(),
              Text(
                '剩余$daysRemaining天',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// 历史趋势折线图
class _HistoryTrendChart extends StatelessWidget {
  final List<Transaction> transactions;
  final int year;
  final int month;

  const _HistoryTrendChart({
    required this.transactions,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final history =
        SpendingInsightCalculator.getMonthlyHistory(transactions, 6);
    final predicted = SpendingInsightCalculator.weightedMonthlyPrediction(
        transactions, year, month);

    // 构建数据点：6个历史月 + 1个当月预测
    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].total));
      if (history[i].total > maxY) maxY = history[i].total;
    }
    // 当月预测点
    final predictSpot = FlSpot(history.length.toDouble(), predicted);
    if (predicted > maxY) maxY = predicted;
    maxY = maxY * 1.15; // 留出顶部空间
    if (maxY == 0) maxY = 1000;

    // 月份标签
    final labels = <String>[];
    for (final h in history) {
      labels.add('${h.month}月');
    }
    labels.add('$month月');

    // 标注季节性月份
    final seasonalIndices = <int>[];
    for (int i = 0; i < history.length; i++) {
      final eventName =
          SpendingInsightCalculator.seasonalEventName(history[i].month);
      if (eventName != null) {
        seasonalIndices.add(i);
      }
    }
    final currentEvent =
        SpendingInsightCalculator.seasonalEventName(month);
    if (currentEvent != null) {
      seasonalIndices.add(history.length);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '历史趋势',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        String label;
                        if (value >= 10000) {
                          label = '${(value / 10000).toStringAsFixed(1)}万';
                        } else {
                          label = '${(value / 1000).toStringAsFixed(0)}k';
                        }
                        return Text(
                          label,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        final isSeasonal =
                            seasonalIndices.contains(idx);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: TextStyle(
                              fontSize: 11,
                              color: isSeasonal
                                  ? Colors.orange[700]
                                  : Colors.grey[600],
                              fontWeight: isSeasonal
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // 历史实线
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.blue[400],
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Colors.blue[400]!,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue[400]!.withValues(alpha: 0.08),
                    ),
                  ),
                  // 预测虚线段（从最后一个实际点到预测点）
                  LineChartBarData(
                    spots: [spots.last, predictSpot],
                    isCurved: false,
                    color: Colors.purple[400],
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) =>
                          spot.x == predictSpot.x,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.purple[400]!,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final isPrediction = idx == history.length;
                        return LineTooltipItem(
                          '${isPrediction ? "预测 " : ""}¥${spot.y.toStringAsFixed(0)}',
                          TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(Colors.blue[400]!, '实际支出', false),
              const SizedBox(width: 20),
              _legendItem(Colors.purple[400]!, '本月预测', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, bool isDashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            border: isDashed
                ? Border(
                    bottom: BorderSide(
                      color: color,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  )
                : null,
          ),
          child: isDashed
              ? CustomPaint(
                  painter: _DashedLinePainter(color: color),
                )
              : null,
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashWidth = 3.0;
    const dashSpace = 2.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 分类预测区域
class _CategoryPredictionSection extends ConsumerWidget {
  final List<Transaction> transactions;
  final int year;
  final int month;

  const _CategoryPredictionSection({
    required this.transactions,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetProvider);
    final predictions = SpendingInsightCalculator.predictCategories(
        transactions, year, month);

    if (predictions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分类预测',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('暂无支出数据',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分类预测',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...predictions.map((p) {
            // 查找该分类的预算
            final budget = budgets
                .where((b) => b.categoryId == p.categoryId && b.isEnabled)
                .fold<double>(0, (sum, b) => sum + b.amount);
            return _CategoryPredictionCard(
              data: p,
              budget: budget > 0 ? budget : null,
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryPredictionCard extends StatelessWidget {
  final CategoryMonthlyPrediction data;
  final double? budget;

  const _CategoryPredictionCard({required this.data, this.budget});

  @override
  Widget build(BuildContext context) {
    final category = DefaultCategories.findById(data.categoryId);
    final categoryName = category?.localizedName ??
        CategoryLocalizationService.instance
            .getCategoryName(data.categoryId);
    final emoji = _getCategoryEmoji(data.categoryId);

    // 进度条用预算或预测值
    final barMax = budget ?? data.predicted;
    final progress = barMax > 0 ? data.currentSpent / barMax : 0.0;
    final isOverBudget = budget != null && data.currentSpent > budget! * 0.8;

    Color progressColor;
    if (isOverBudget) {
      progressColor = Colors.red;
    } else if (data.trendPercent > 10) {
      progressColor = Colors.orange;
    } else if (data.trendPercent < -10) {
      progressColor = Colors.green;
    } else {
      progressColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isOverBudget)
                      Row(
                        children: [
                          Icon(Icons.warning_amber,
                              size: 12, color: Colors.red[400]),
                          const SizedBox(width: 2),
                          Text(
                            '预算预警',
                            style: TextStyle(
                                fontSize: 10, color: Colors.red[400]),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${data.predicted.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (data.lastMonth > 0)
                    Text(
                      '${data.trendPercent > 0 ? '↑' : data.trendPercent < 0 ? '↓' : '→'}${data.trendPercent.abs().toStringAsFixed(0)}% 较上月',
                      style: TextStyle(
                        fontSize: 11,
                        color: data.trendPercent > 5
                            ? Colors.red
                            : data.trendPercent < -5
                                ? Colors.green
                                : Colors.grey,
                      ),
                    )
                  else
                    Text(
                      '无上月数据',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已消费 ¥${data.currentSpent.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                budget != null
                    ? '预算 ¥${budget!.toStringAsFixed(0)}'
                    : '预测 ¥${data.predicted.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryEmoji(String categoryId) {
    const emojiMap = {
      'food': '🍜',
      'transport': '🚗',
      'shopping': '🛒',
      'entertainment': '🎮',
      'medical': '💊',
      'education': '📚',
      'housing': '🏠',
      'utilities': '💡',
      'communication': '📱',
      'clothing': '👔',
      'beauty': '💄',
      'subscription': '📺',
      'social': '🤝',
      'finance': '💰',
      'pet': '🐾',
      'other_expense': '📋',
    };
    return emojiMap[categoryId] ?? '📋';
  }
}

/// 预测说明
class _PredictionExplanation extends StatelessWidget {
  final List<Transaction> transactions;
  final int month;

  const _PredictionExplanation({
    required this.transactions,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final confidence =
        SpendingInsightCalculator.predictionConfidence(transactions);
    final confidencePercent = (confidence * 100).toStringAsFixed(0);
    final factor = SpendingInsightCalculator.seasonalFactor(month);
    final eventName =
        SpendingInsightCalculator.seasonalEventName(month);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '预测说明',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '基于过去6个月消费数据，使用加权移动平均 + 季节性调整算法',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            '置信度: $confidencePercent%（基于历史数据稳定性）',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (eventName != null && factor > 1.05) ...[
            const SizedBox(height: 4),
            Text(
              '本月受$eventName影响，季节性因子 ×${factor.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 12, color: Colors.orange[700]),
            ),
          ],
        ],
      ),
    );
  }
}
