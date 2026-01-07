import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'resident_location_page.dart';
import 'geofence_management_page.dart';
import 'location_analysis_page.dart';

/// 8.14 位置服务设置页面
/// 精确位置服务开关及相关功能入口
class LocationServiceSettingsPage extends ConsumerStatefulWidget {
  const LocationServiceSettingsPage({super.key});

  @override
  ConsumerState<LocationServiceSettingsPage> createState() =>
      _LocationServiceSettingsPageState();
}

class _LocationServiceSettingsPageState
    extends ConsumerState<LocationServiceSettingsPage> {
  bool _preciseLocation = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n?.locationServices ?? '位置服务',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildLocationToggleCard(l10n),
            _buildLocationOptions(l10n),
            _buildSecurityNotice(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationToggleCard(AppLocalizations? l10n) {
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.preciseLocationService ?? '精确位置服务',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _preciseLocation,
                onChanged: (v) => setState(() => _preciseLocation = v),
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '开启后可获得：',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildFeatureItem('智能消费场景识别（家/公司/商圈）'),
          _buildFeatureItem('地理围栏预算提醒'),
          _buildFeatureItem('POI商户自动匹配'),
          _buildFeatureItem('本地化省钱推荐'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: AppTheme.successColor,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationOptions(AppLocalizations? l10n) {
    final options = [
      {
        'icon': Icons.home,
        'title': l10n?.residentLocations ?? '常驻地点设置',
        'subtitle': '家庭、公司位置',
      },
      {
        'icon': Icons.fence,
        'title': l10n?.geofenceReminder ?? '地理围栏提醒',
        'subtitle': '进入商圈自动提醒预算',
      },
      {
        'icon': Icons.map,
        'title': l10n?.locationAnalysisReport ?? '位置分析报告',
        'subtitle': '查看消费地图与统计',
      },
      {
        'icon': Icons.flight,
        'title': l10n?.remoteSpendingRecord ?? '异地消费记录',
        'subtitle': '旅行/出差消费自动分离',
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isLast = index == options.length - 1;

          return InkWell(
            onTap: () => _handleOptionTap(index),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: !isLast
                    ? Border(
                        bottom: BorderSide(
                          color: AppTheme.dividerColor,
                          width: 0.5,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    option['icon'] as IconData,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option['title'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          option['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondaryColor,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSecurityNotice(AppLocalizations? l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.dataSecurityGuarantee ?? '数据安全保障',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '✓ 位置数据本地加密存储\n✓ 不上传原始坐标到云端\n✓ 30天自动清理历史轨迹',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('查看详情', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _showClearDataDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                    foregroundColor: AppTheme.errorColor,
                    minimumSize: const Size(0, 36),
                    elevation: 0,
                  ),
                  child: const Text('清除数据', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleOptionTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ResidentLocationPage()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GeofenceManagementPage()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LocationAnalysisPage()),
        );
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('异地消费记录页面即将推出')),
        );
        break;
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除位置数据'),
        content: const Text('确定要清除所有位置历史数据吗？此操作不可恢复。'),
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
                  content: const Text('位置数据已清除'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }
}
