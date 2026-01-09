import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.15 常驻地点设置页面
/// 设置家庭、公���等常驻位置
class ResidentLocationPage extends ConsumerStatefulWidget {
  const ResidentLocationPage({super.key});

  @override
  ConsumerState<ResidentLocationPage> createState() => _ResidentLocationPageState();
}

class _ResidentLocationPageState extends ConsumerState<ResidentLocationPage> {
  final List<_LocationItem> _locations = [
    _LocationItem(
      id: 'home',
      name: '家庭位置',
      address: '上海市浦东新区陆家嘴环路1000号',
      icon: Icons.home,
      gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
      isSet: true,
    ),
    _LocationItem(
      id: 'work',
      name: '公司位置',
      address: '上海市黄浦区人民广场201号',
      icon: Icons.business,
      gradientColors: [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
      isSet: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.residentLocations,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildInfoCard(),
            ...(_locations.map((loc) => _buildLocationCard(loc))),
            _buildAddButton(),
            _buildStatisticsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '设置后可智能识别通勤消费、家附近消费等场景',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(_LocationItem location) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: location.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(location.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          location.isSet ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: location.isSet
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          location.isSet ? '已设置' : '未设置',
                          style: TextStyle(
                            fontSize: 12,
                            color: location.isSet
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (location.isSet && location.address != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                location.address!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _autoDetectLocation(location),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('自动检测'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _manualSetLocation(location),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('手动设置'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: _addNewLocation,
        icon: const Icon(Icons.add),
        label: const Text('添加其他常驻地点'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(
            color: AppColors.divider,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
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
          Text(
            '本月场景识别',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('45%', '家附近消费', AppColors.primary),
              _buildStatItem('32%', '公司附近', const Color(0xFF4ECDC4)),
              _buildStatItem('23%', '其他区域', AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _autoDetectLocation(_LocationItem location) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在检测${location.name}...'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _manualSetLocation(_LocationItem location) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('即将打开地图选择')),
    );
  }

  void _addNewLocation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加常驻地点'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '地点名称',
                hintText: '如：健身房、父母家',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('地点已添加'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

class _LocationItem {
  final String id;
  final String name;
  final String? address;
  final IconData icon;
  final List<Color> gradientColors;
  bool isSet;

  _LocationItem({
    required this.id,
    required this.name,
    this.address,
    required this.icon,
    required this.gradientColors,
    required this.isSet,
  });
}
