import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/transaction_location.dart';

/// 8.17 位置分析报告页面
/// 展示消费位置分布和热点地图
class LocationAnalysisPage extends ConsumerStatefulWidget {
  const LocationAnalysisPage({super.key});

  @override
  ConsumerState<LocationAnalysisPage> createState() => _LocationAnalysisPageState();
}

class _LocationAnalysisPageState extends ConsumerState<LocationAnalysisPage> {
  String _selectedPeriod = '本月';
  final List<String> _periods = ['本月', '上月', '近3月', '今年'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allTransactions = ref.watch(transactionProvider);
    final dateRange = _getDateRange();

    // 过滤有位置信息的支出交易
    final transactionsWithLocation = allTransactions.where((t) {
      if (t.type != TransactionType.expense) return false;
      if (t.location == null) return false;
      if (!t.date.isAfter(dateRange.start.subtract(const Duration(days: 1)))) return false;
      if (!t.date.isBefore(dateRange.end.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.locationAnalysis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildPeriodSelector(),
            if (transactionsWithLocation.isEmpty)
              _buildEmptyState()
            else ...[
              _buildMapPreview(transactionsWithLocation),
              _buildLocationDistribution(transactionsWithLocation),
              _buildTopLocations(transactionsWithLocation),
              _buildInsights(transactionsWithLocation),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case '本月':
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case '上月':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateTimeRange(start: lastMonth, end: lastMonthEnd);
      case '近3月':
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case '今年':
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year, 12, 31, 23, 59, 59),
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
    }
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: _periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '暂无位置数据',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '记账时添加位置信息后，这里将显示消费热点分析',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview(List<Transaction> transactions) {
    // 按地点分组计算消费金额
    final Map<String, double> placeAmounts = {};
    for (final t in transactions) {
      final placeName = t.location?.shortDisplay ?? '未知位置';
      placeAmounts[placeName] = (placeAmounts[placeName] ?? 0) + t.amount;
    }

    // 找出金额最大的几个地点
    final sortedPlaces = placeAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topPlaces = sortedPlaces.take(4).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // 根据真实数据显示消费点
          if (topPlaces.isNotEmpty) ...[
            for (int i = 0; i < topPlaces.length; i++)
              Positioned(
                left: 60.0 + i * 45.0,
                top: 45.0 + i * 25.0,
                child: _buildMapPoint(
                  24 + (4 - i) * 2.0,
                  _getColorForIndex(i),
                ),
              ),
          ],
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map,
                  size: 32,
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_selectedPeriod消费热点地图',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '共${transactions.length}笔位置记录',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForIndex(int index) {
    const colors = [
      Color(0xFFFF6B6B),
      Color(0xFF4ECDC4),
      Color(0xFFFF9800),
      Color(0xFF66BB6A),
    ];
    return colors[index % colors.length];
  }

  Widget _buildMapPoint(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDistribution(List<Transaction> transactions) {
    // 按位置类型分组统计
    final Map<LocationType, double> typeAmounts = {};
    double totalAmount = 0;

    for (final t in transactions) {
      final locType = t.location?.locationType ?? LocationType.other;
      typeAmounts[locType] = (typeAmounts[locType] ?? 0) + t.amount;
      totalAmount += t.amount;
    }

    // 排序
    final sortedTypes = typeAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 构建显示列表
    final locations = sortedTypes.map((entry) {
      final percent = totalAmount > 0 ? entry.value / totalAmount : 0.0;
      return {
        'name': entry.key.displayName,
        'amount': entry.value,
        'percent': percent,
        'icon': entry.key.icon,
        'color': entry.key.color,
      };
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '消费位置分布',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...locations.map((loc) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          loc['icon'] as IconData,
                          size: 16,
                          color: loc['color'] as Color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc['name'] as String,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          '¥${(loc['amount'] as double).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: loc['percent'] as double,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation(loc['color'] as Color),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTopLocations(List<Transaction> transactions) {
    // 按地点名称分组统计
    final Map<String, Map<String, dynamic>> placeStats = {};

    for (final t in transactions) {
      final placeName = t.location?.placeName ?? t.location?.shortDisplay ?? '未知位置';
      if (!placeStats.containsKey(placeName)) {
        placeStats[placeName] = {'visits': 0, 'amount': 0.0};
      }
      placeStats[placeName]!['visits'] = (placeStats[placeName]!['visits'] as int) + 1;
      placeStats[placeName]!['amount'] = (placeStats[placeName]!['amount'] as double) + t.amount;
    }

    // 按访问次数排序
    final sortedPlaces = placeStats.entries.toList()
      ..sort((a, b) => (b.value['visits'] as int).compareTo(a.value['visits'] as int));

    final topSpots = sortedPlaces.take(10).map((entry) => {
      'name': entry.key,
      'visits': entry.value['visits'] as int,
      'amount': entry.value['amount'] as double,
    }).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '常去地点 TOP',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...topSpots.asMap().entries.map((entry) {
            final index = entry.key;
            final spot = entry.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: index < 3
                      ? AppColors.primary
                      : AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: index < 3 ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              title: Text(
                spot['name'] as String,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                '${spot['visits']}次 · 共消费¥${(spot['amount'] as double).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsights(List<Transaction> transactions) {
    final insights = _generateInsights(transactions);

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFFF57C00), size: 20),
              const SizedBox(width: 8),
              const Text(
                '位置消费洞察',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => _buildInsightItem(insight)),
        ],
      ),
    );
  }

  List<String> _generateInsights(List<Transaction> transactions) {
    final insights = <String>[];

    // 统计位置类型分布
    final Map<LocationType, double> typeAmounts = {};
    double totalAmount = 0;

    for (final t in transactions) {
      final locType = t.location?.locationType ?? LocationType.other;
      typeAmounts[locType] = (typeAmounts[locType] ?? 0) + t.amount;
      totalAmount += t.amount;
    }

    // 找出最大的位置类型
    if (typeAmounts.isNotEmpty) {
      final maxType = typeAmounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      final percent = (maxType.value / totalAmount * 100).toStringAsFixed(0);
      insights.add('${maxType.key.displayName}消费占比最高，达到$percent%');
    }

    // 统计不同地点数量
    final uniquePlaces = transactions
        .map((t) => t.location?.placeName ?? t.location?.shortDisplay)
        .where((p) => p != null)
        .toSet()
        .length;
    if (uniquePlaces > 0) {
      insights.add('$_selectedPeriod共在$uniquePlaces个不同地点消费');
    }

    // 找出访问最多的地点
    final Map<String, int> placeVisits = {};
    for (final t in transactions) {
      final placeName = t.location?.placeName ?? t.location?.shortDisplay;
      if (placeName != null) {
        placeVisits[placeName] = (placeVisits[placeName] ?? 0) + 1;
      }
    }
    if (placeVisits.isNotEmpty) {
      final mostVisited = placeVisits.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (mostVisited.value >= 3) {
        insights.add('${mostVisited.key}是最常去的地点，共${mostVisited.value}次');
      }
    }

    return insights;
  }

  Widget _buildInsightItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.arrow_right,
            size: 16,
            color: Color(0xFFF57C00),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFE65100),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
