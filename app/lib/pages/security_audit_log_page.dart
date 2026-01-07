import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// 8.25 安全审计日志页面
/// 查看安全事件和登录记录
class SecurityAuditLogPage extends ConsumerStatefulWidget {
  const SecurityAuditLogPage({super.key});

  @override
  ConsumerState<SecurityAuditLogPage> createState() => _SecurityAuditLogPageState();
}

class _SecurityAuditLogPageState extends ConsumerState<SecurityAuditLogPage> {
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
          l10n?.securityLog ?? '安全日志',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: AppColors.textSecondary),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecurityStatusCard(),
            _buildLogSection('今天', _todayLogs),
            _buildLogSection('昨天', _yesterdayLogs),
            _buildLogSection('更早', _olderLogs),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4DB6AC), Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '安全状态良好',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '过去30天无异常活动',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('23', '登录次数'),
              _buildStatItem('5', '备份创建'),
              _buildStatItem('0', '异常事件'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSection(String title, List<_LogItem> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
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
            children: logs.asMap().entries.map((entry) {
              final index = entry.key;
              final log = entry.value;
              final isLast = index == logs.length - 1;
              return Column(
                children: [
                  _buildLogItem(log),
                  if (!isLast)
                    Divider(height: 1, indent: 60, color: AppColors.divider),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(_LogItem log) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: log.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(log.icon, color: log.color, size: 18),
      ),
      title: Text(
        log.title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${log.description} · ${log.time}',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '筛选日志类型',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('全部', true),
                _buildFilterChip('登录', false),
                _buildFilterChip('备份', false),
                _buildFilterChip('设置变更', false),
                _buildFilterChip('异常', false),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => Navigator.pop(context),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  List<_LogItem> get _todayLogs => [
        _LogItem(
          icon: Icons.login,
          title: '应用解锁',
          description: '使用指纹解锁',
          time: '09:41',
          color: AppColors.primary,
        ),
        _LogItem(
          icon: Icons.backup,
          title: '创建备份',
          description: '自动备份完成',
          time: '09:30',
          color: AppColors.success,
        ),
        _LogItem(
          icon: Icons.login,
          title: '应用解锁',
          description: '使用PIN码解锁',
          time: '08:15',
          color: AppColors.primary,
        ),
      ];

  List<_LogItem> get _yesterdayLogs => [
        _LogItem(
          icon: Icons.settings,
          title: '设置变更',
          description: '修改了通知设置',
          time: '18:30',
          color: const Color(0xFFFF9800),
        ),
        _LogItem(
          icon: Icons.login,
          title: '应用解锁',
          description: '使用指纹解锁',
          time: '14:22',
          color: AppColors.primary,
        ),
        _LogItem(
          icon: Icons.cloud_download,
          title: '数据恢复',
          description: '从云端恢复数据',
          time: '10:15',
          color: const Color(0xFF2196F3),
        ),
      ];

  List<_LogItem> get _olderLogs => [
        _LogItem(
          icon: Icons.password,
          title: 'PIN码变更',
          description: '修改了PIN码',
          time: '3天前',
          color: const Color(0xFF9C27B0),
        ),
        _LogItem(
          icon: Icons.devices,
          title: '新设备登录',
          description: 'iPhone 15 Pro',
          time: '5天前',
          color: const Color(0xFF607D8B),
        ),
      ];
}

class _LogItem {
  final IconData icon;
  final String title;
  final String description;
  final String time;
  final Color color;

  _LogItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.time,
    required this.color,
  });
}
