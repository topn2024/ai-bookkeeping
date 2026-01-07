import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.16 地理围栏管理页面
/// 管理进入特定区域的预算提醒
class GeofenceManagementPage extends ConsumerStatefulWidget {
  const GeofenceManagementPage({super.key});

  @override
  ConsumerState<GeofenceManagementPage> createState() => _GeofenceManagementPageState();
}

class _GeofenceManagementPageState extends ConsumerState<GeofenceManagementPage> {
  bool _geofenceEnabled = true;

  final List<_GeofenceItem> _systemFences = [
    _GeofenceItem(
      id: 'shopping',
      name: '商圈提醒',
      description: '进入商圈提醒购物预算',
      icon: Icons.shopping_bag,
      gradientColors: [const Color(0xFF6495ED), const Color(0xFF9370DB)],
      enabled: true,
      tags: ['陆家嘴', '南京路', '淮海路'],
    ),
    _GeofenceItem(
      id: 'dining',
      name: '餐饮区提醒',
      description: '餐饮集中区提醒餐饮预算',
      icon: Icons.restaurant,
      gradientColors: [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      enabled: true,
    ),
  ];

  final List<_GeofenceItem> _customFences = [
    _GeofenceItem(
      id: 'custom1',
      name: '高消费区域',
      description: '月均消费¥1,200+',
      icon: Icons.warning,
      gradientColors: [const Color(0xFFFF9800), const Color(0xFFFF9800)],
      enabled: true,
    ),
  ];

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
          l10n?.geofenceReminder ?? '地理围栏提醒',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.primary),
            onPressed: _addCustomFence,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainSwitch(),
            if (_geofenceEnabled) ...[
              _buildSectionHeader('系统围栏'),
              ..._systemFences.map((f) => _buildFenceCard(f)),
              _buildSectionHeader('自定义围栏'),
              ..._customFences.map((f) => _buildFenceCard(f)),
              _buildAddCustomButton(),
              _buildStatisticsCard(),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSwitch() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '进入区域自动提醒',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '进入特定区域时提醒预算余额',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _geofenceEnabled,
            onChanged: (v) => setState(() => _geofenceEnabled = v),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFenceCard(_GeofenceItem fence) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: fence.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(fence.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fence.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      fence.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: fence.enabled,
                onChanged: (v) => setState(() => fence.enabled = v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (fence.tags != null && fence.tags!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: fence.tags!
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddCustomButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: _addCustomFence,
        icon: const Icon(Icons.add_location, size: 18),
        label: const Text('添加自定义围栏'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: BorderSide(
            color: AppColors.divider,
            width: 2,
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('23', '本月提醒次数'),
          _buildStatItem('¥680', '节省消费'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
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
    );
  }

  void _addCustomFence() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '添加自定义围栏',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: '围栏名称',
                hintText: '如：健身房周边',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: '提醒内容',
                hintText: '进入区域时显示的提醒',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('请在地图上选择围栏范围'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('在地图上选择范围'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GeofenceItem {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  bool enabled;
  final List<String>? tags;

  _GeofenceItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.enabled,
    this.tags,
  });
}
