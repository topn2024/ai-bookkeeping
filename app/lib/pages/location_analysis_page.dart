import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.17 位置分析报告页面
/// 展示消费位置分布和热点地图
class LocationAnalysisPage extends ConsumerStatefulWidget {
  const LocationAnalysisPage({super.key});

  @override
  ConsumerState<LocationAnalysisPage> createState() => _LocationAnalysisPageState();
}

class _LocationAnalysisPageState extends ConsumerState<LocationAnalysisPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n?.locationAnalysis ?? '位置分析',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: AppColors.textSecondary),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMapPreview(),
            _buildLocationDistribution(),
            _buildTopLocations(),
            _buildInsights(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreview() {
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
          // 模拟消费点
          Positioned(
            left: 60,
            top: 45,
            child: _buildMapPoint(24, AppColors.error),
          ),
          Positioned(
            left: 140,
            top: 72,
            child: _buildMapPoint(32, const Color(0xFF6495ED)),
          ),
          Positioned(
            left: 200,
            top: 108,
            child: _buildMapPoint(20, const Color(0xFFFF9800)),
          ),
          Positioned(
            left: 75,
            top: 117,
            child: _buildMapPoint(28, AppColors.success),
          ),
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
                  '本月消费热点地图',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildLocationDistribution() {
    final locations = [
      {'name': '家附近', 'amount': 2340, 'percent': 0.45, 'icon': Icons.home, 'color': const Color(0xFFFF6B6B)},
      {'name': '公司附近', 'amount': 1680, 'percent': 0.32, 'icon': Icons.business, 'color': const Color(0xFF4ECDC4)},
      {'name': '商圈消费', 'amount': 860, 'percent': 0.16, 'icon': Icons.shopping_bag, 'color': const Color(0xFF6495ED)},
      {'name': '其他区域', 'amount': 340, 'percent': 0.07, 'icon': Icons.place, 'color': const Color(0xFF9E9E9E)},
    ];

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
                          '¥${loc['amount']}',
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

  Widget _buildTopLocations() {
    final topSpots = [
      {'name': '星巴克 陆家嘴店', 'visits': 8, 'amount': 320},
      {'name': '盒马鲜生 浦东店', 'visits': 5, 'amount': 680},
      {'name': '全家便利店', 'visits': 12, 'amount': 156},
      {'name': '海底捞 人民广场', 'visits': 2, 'amount': 560},
    ];

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
                '${spot['visits']}次 · 共消费¥${spot['amount']}',
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

  Widget _buildInsights() {
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
          _buildInsightItem('公司附近的午餐消费占餐饮支出的45%'),
          _buildInsightItem('商圈消费比上月减少了¥280'),
          _buildInsightItem('本月新发现3个消费地点'),
        ],
      ),
    );
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

  void _selectDateRange() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择时间范围',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('本周'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('本月'),
              trailing: Icon(Icons.check, color: AppColors.primary),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('近三个月'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('自定义范围'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
