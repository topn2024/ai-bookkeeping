import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../theme/antigravity_shadows.dart';

/// 系统日志页面
/// 原型设计 12.03：系统日志
/// - 日志级别筛选（Debug/Info/Warning/Error）
/// - 日志搜索
/// - 时间范围选择
/// - 日志列表（可展开详情）
class SystemLogPage extends ConsumerStatefulWidget {
  const SystemLogPage({super.key});

  @override
  ConsumerState<SystemLogPage> createState() => _SystemLogPageState();
}

class _SystemLogPageState extends ConsumerState<SystemLogPage> {
  String _selectedLevel = 'all';
  String _searchQuery = '';

  final _logs = <_LogEntry>[
    _LogEntry(LogLevel.info, '应用启动', '版本 2.0.5 (Build 125)', DateTime.now().subtract(const Duration(minutes: 5))),
    _LogEntry(LogLevel.debug, '数据同步', '同步完成，更新128条记录', DateTime.now().subtract(const Duration(minutes: 12))),
    _LogEntry(LogLevel.warning, '内存警告', '内存使用达到85%，已触发自动清理', DateTime.now().subtract(const Duration(minutes: 30))),
    _LogEntry(LogLevel.info, '用户操作', '添加交易：餐饮 ¥35', DateTime.now().subtract(const Duration(hours: 1))),
    _LogEntry(LogLevel.error, '网络错误', '同步失败：Connection timeout', DateTime.now().subtract(const Duration(hours: 2))),
    _LogEntry(LogLevel.info, '缓存清理', '释放56MB存储空间', DateTime.now().subtract(const Duration(hours: 3))),
    _LogEntry(LogLevel.debug, 'AI识别', '语音识别完成，置信度92%', DateTime.now().subtract(const Duration(hours: 4))),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredLogs = _logs.where((log) {
      if (_selectedLevel != 'all' && log.level.name != _selectedLevel) return false;
      if (_searchQuery.isNotEmpty) {
        return log.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            log.message.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            _buildSearchBar(context, theme),
            _buildLevelFilter(context, theme),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) => _buildLogItem(context, theme, filteredLogs[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
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
              child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '系统日志',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: _exportLogs,
            icon: const Icon(Icons.download),
            tooltip: '导出日志',
          ),
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_outline),
            tooltip: '清除日志',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索日志...',
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildLevelFilter(BuildContext context, ThemeData theme) {
    final levels = [
      ('all', '全部', null),
      ('debug', 'Debug', Colors.grey),
      ('info', 'Info', AppColors.primary),
      ('warning', 'Warning', AppColors.warning),
      ('error', 'Error', AppColors.expense),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: levels.map((level) {
          final isSelected = _selectedLevel == level.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(level.$2),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedLevel = selected ? level.$1 : 'all');
              },
              avatar: level.$3 != null
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: level.$3,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, ThemeData theme, _LogEntry log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AntigravityShadows.l1,
      ),
      child: ExpansionTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: log.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(log.icon, size: 16, color: log.color),
        ),
        title: Text(
          log.title,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          DateFormat('HH:mm:ss').format(log.time),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: log.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            log.level.name.toUpperCase(),
            style: TextStyle(
              color: log.color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  log.message,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(log.time),
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

  void _exportLogs() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已导出到下载目录')),
    );
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除日志'),
        content: const Text('确定要清除所有日志吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _logs.clear());
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}

enum LogLevel { debug, info, warning, error }

class _LogEntry {
  final LogLevel level;
  final String title;
  final String message;
  final DateTime time;

  _LogEntry(this.level, this.title, this.message, this.time);

  Color get color {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return AppColors.primary;
      case LogLevel.warning:
        return AppColors.warning;
      case LogLevel.error:
        return AppColors.expense;
    }
  }

  IconData get icon {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
    }
  }
}
