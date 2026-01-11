import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sync.dart';
import '../providers/sync_provider.dart';

class SyncSettingsPage extends ConsumerStatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  ConsumerState<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends ConsumerState<SyncSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据同步'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              icon: Badge(
                label: Text('${syncState.pendingSyncCount}'),
                isLabelVisible: syncState.pendingSyncCount > 0,
                child: Icon(syncState.status.icon),
              ),
              text: '服务器同步',
            ),
            Tab(
              icon: Badge(
                label: Text('${syncState.backups.length}'),
                isLabelVisible: syncState.backups.isNotEmpty,
                child: const Icon(Icons.backup),
              ),
              text: '备份',
            ),
            const Tab(
              icon: Icon(Icons.cleaning_services),
              text: '数据清理',
            ),
            const Tab(
              icon: Icon(Icons.settings),
              text: '设置',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ServerSyncTab(syncState: syncState),
          _BackupTab(syncState: syncState),
          _CleanupTab(syncState: syncState),
          _SettingsTab(syncState: syncState),
        ],
      ),
    );
  }
}

/// 服务器同步Tab
class _ServerSyncTab extends ConsumerWidget {
  final SyncState syncState;

  const _ServerSyncTab({required this.syncState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 同步状态卡片
          _buildStatusCard(context, ref),
          const SizedBox(height: 16),

          // 同步统计
          _buildSyncStats(context),
          const SizedBox(height: 16),

          // 同步操作按钮
          _buildSyncActions(context, ref),
          const SizedBox(height: 16),

          // 离线队列状态
          if (syncState.queuedCount > 0)
            _buildOfflineQueueCard(context, ref),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 状态图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: syncState.status.color.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: syncState.status == SyncStatus.syncing
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: syncState.progress,
                          strokeWidth: 3,
                        ),
                        if (syncState.progress != null)
                          Text(
                            '${(syncState.progress! * 100).toInt()}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    )
                  : Icon(
                      syncState.status.icon,
                      size: 40,
                      color: syncState.status.color,
                    ),
            ),
            const SizedBox(height: 16),

            // 状态文本
            Text(
              syncState.status.displayName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: syncState.status.color,
              ),
            ),

            // 进度消息
            if (syncState.progressMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                syncState.progressMessage!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],

            const SizedBox(height: 4),

            // 上次同步时间
            Text(
              syncState.lastSyncText,
              style: TextStyle(color: Colors.grey[600]),
            ),

            // 错误信息
            if (syncState.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  syncState.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 网络状态
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  syncState.isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: syncState.isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  syncState.isOnline
                      ? (syncState.isWifi ? 'WiFi已连接' : '移动网络')
                      : '无网络',
                  style: TextStyle(
                    fontSize: 12,
                    color: syncState.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStats(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '同步统计',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.pending_actions,
                    label: '待同步',
                    value: '${syncState.pendingSyncCount}',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.cloud_done,
                    label: '已同步',
                    value: '${syncState.syncedCount}',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.queue,
                    label: '队列中',
                    value: '${syncState.queuedCount}',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncActions(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '同步操作',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: syncState.canSync
                    ? () => ref.read(syncProvider.notifier).syncToServer()
                    : null,
                icon: const Icon(Icons.sync),
                label: const Text('立即同步到服务器'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: syncState.canSync
                        ? () => ref.read(syncProvider.notifier).refreshStats()
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新状态'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineQueueCard(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_queue, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '离线操作队列',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${syncState.queuedCount}条待处理',
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '您有未同步的操作，连接网络后将自动同步',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref.read(syncProvider.notifier).retryFailedItems(),
                    child: const Text('重试失败项'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmClearQueue(context, ref),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('清空队列'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearQueue(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空队列'),
        content: const Text('确定要清空离线队列吗？未同步的操作将丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(syncProvider.notifier).clearQueue();
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

/// 数据清理Tab
class _CleanupTab extends ConsumerWidget {
  final SyncState syncState;

  const _CleanupTab({required this.syncState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 清理说明
          _buildInfoCard(context),
          const SizedBox(height: 16),

          // 清理设置
          _buildCleanupSettings(context, ref),
          const SizedBox(height: 16),

          // 清理预览
          if (syncState.cleanupPreview != null)
            _buildCleanupPreview(context, ref),

          // 清理操作
          _buildCleanupActions(context, ref),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '关于数据清理',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• 只清理已同步到服务器的数据\n'
              '• 服务器作为数据主存储，本地清理后仍可从服务器恢复\n'
              '• 建议定期清理以节省手机存储空间\n'
              '• 账户、分类、预算等基础数据不会被清理',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupSettings(BuildContext context, WidgetRef ref) {
    final settings = syncState.cleanupSettings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '清理设置',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('保留数据时长'),
              subtitle: Text('保留最近${settings.retentionDays}天的交易记录'),
              trailing: DropdownButton<int>(
                value: settings.retentionDays,
                items: [7, 14, 30, 60, 90, 180].map((days) {
                  String label;
                  if (days < 30) {
                    label = '$days天';
                  } else if (days < 365) {
                    label = '${days ~/ 30}个月';
                  } else {
                    label = '${days ~/ 365}年';
                  }
                  return DropdownMenuItem(
                    value: days,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(syncProvider.notifier).updateCleanupSettings(
                          settings.copyWith(retentionDays: value),
                        );
                  }
                },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('同步后自动清理'),
              subtitle: const Text('每次同步成功后自动执行清理'),
              value: settings.autoCleanup,
              onChanged: (value) {
                ref.read(syncProvider.notifier).updateCleanupSettings(
                      settings.copyWith(autoCleanup: value),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupPreview(BuildContext context, WidgetRef ref) {
    final preview = syncState.cleanupPreview!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '清理预览',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '共${preview.totalCount}条',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (preview.transactionCount > 0)
              _CleanupPreviewItem(
                icon: Icons.receipt_long,
                label: '交易记录',
                count: preview.transactionCount,
              ),
            if (preview.totalCount == 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 48, color: Colors.green[400]),
                      const SizedBox(height: 8),
                      Text(
                        '没有需要清理的数据',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupActions(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(syncProvider.notifier).getCleanupPreview(),
                icon: const Icon(Icons.preview),
                label: const Text('预览待清理数据'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: syncState.cleanupPreview?.totalCount != null &&
                        syncState.cleanupPreview!.totalCount > 0
                    ? () => _confirmCleanup(context, ref)
                    : null,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('执行清理'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCleanup(BuildContext context, WidgetRef ref) async {
    final preview = syncState.cleanupPreview;
    if (preview == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('将清理${preview.totalCount}条记录：'),
            const SizedBox(height: 8),
            if (preview.transactionCount > 0)
              Text('• 交易记录：${preview.transactionCount}条'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '这些数据已同步到服务器，可随时恢复',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final result = await ref.read(syncProvider.notifier).performCleanup();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已清理${result.deletedCount}条记录')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('清理失败：$e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _CleanupPreviewItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _CleanupPreviewItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            '$count条',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BackupTab extends ConsumerWidget {
  final SyncState syncState;

  const _BackupTab({required this.syncState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // 创建备份按钮
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: syncState.status != SyncStatus.syncing
                  ? () => _createBackup(context, ref)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('创建新备份'),
            ),
          ),
        ),

        // 备份列表
        Expanded(
          child: syncState.backups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.backup, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '暂无备份',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击上方按钮创建第一个备份',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: syncState.backups.length,
                  itemBuilder: (context, index) {
                    final backup = syncState.backups[index];
                    return _BackupCard(
                      backup: backup,
                      onRestore: () => _restoreBackup(context, ref, backup),
                      onDelete: () => _deleteBackup(context, ref, backup),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    final backup = await ref.read(syncProvider.notifier).createBackup();
    if (backup != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('备份创建成功 (${backup.totalRecords}条记录)')),
      );
    }
  }

  Future<void> _restoreBackup(
      BuildContext context, WidgetRef ref, BackupData backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复备份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要恢复这个备份吗？'),
            const SizedBox(height: 12),
            Text(
              '备份时间: ${_formatDate(backup.createdAt)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            Text(
              '记录数: ${backup.totalRecords}条',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '恢复将覆盖当前数据，建议先创建备份',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success =
          await ref.read(syncProvider.notifier).restoreBackup(backup.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '备份恢复成功' : '备份恢复失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBackup(
      BuildContext context, WidgetRef ref, BackupData backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除备份'),
        content: Text('确定要删除 ${_formatDate(backup.createdAt)} 的备份吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(syncProvider.notifier).deleteBackup(backup.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除备份失败: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _BackupCard extends StatelessWidget {
  final BackupData backup;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _BackupCard({
    required this.backup,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.backup, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(backup.createdAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        backup.deviceName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') {
                      onRestore();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore),
                          SizedBox(width: 8),
                          Text('恢复'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatItem(
                  icon: Icons.receipt_long,
                  label: '交易',
                  value: '${backup.transactionCount}',
                ),
                _StatItem(
                  icon: Icons.account_balance_wallet,
                  label: '账户',
                  value: '${backup.accountCount}',
                ),
                _StatItem(
                  icon: Icons.category,
                  label: '分类',
                  value: '${backup.categoryCount}',
                ),
                _StatItem(
                  icon: Icons.pie_chart,
                  label: '预算',
                  value: '${backup.budgetCount}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  final SyncState syncState;

  const _SettingsTab({required this.syncState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = syncState.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 同步开关
        Card(
          child: SwitchListTile(
            title: const Text('启用云同步'),
            subtitle: Text(settings.enabled ? '已启用' : '未启用'),
            secondary: Icon(
              settings.enabled ? Icons.cloud_done : Icons.cloud_off,
              color: settings.enabled ? Colors.green : Colors.grey,
            ),
            value: settings.enabled,
            onChanged: (value) {
              ref.read(syncProvider.notifier).updateSettings(
                    settings.copyWith(enabled: value),
                  );
            },
          ),
        ),
        const SizedBox(height: 16),

        // 云服务提供商
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '云服务',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...CloudProvider.values.map((provider) => RadioListTile<CloudProvider>(
                    title: Row(
                      children: [
                        Icon(provider.icon, size: 20),
                        const SizedBox(width: 12),
                        Text(provider.displayName),
                      ],
                    ),
                    subtitle: provider.isAvailable
                        ? null
                        : const Text('即将支持', style: TextStyle(fontSize: 12)),
                    value: provider,
                    groupValue: settings.provider,
                    onChanged: provider.isAvailable
                        ? (value) {
                            if (value != null) {
                              ref.read(syncProvider.notifier).updateSettings(
                                    settings.copyWith(provider: value),
                                  );
                            }
                          }
                        : null,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 同步频率
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '同步频率',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...SyncFrequency.values.map((freq) => RadioListTile<SyncFrequency>(
                    title: Text(freq.displayName),
                    value: freq,
                    groupValue: settings.frequency,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(syncProvider.notifier).updateSettings(
                              settings.copyWith(frequency: value),
                            );
                      }
                    },
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 其他设置
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('仅WiFi同步'),
                subtitle: const Text('仅在WiFi网络下进行同步'),
                value: settings.wifiOnly,
                onChanged: (value) {
                  ref.read(syncProvider.notifier).updateSettings(
                        settings.copyWith(wifiOnly: value),
                      );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('同步前备份'),
                subtitle: const Text('每次同步前自动创建备份'),
                value: settings.backupBeforeSync,
                onChanged: (value) {
                  ref.read(syncProvider.notifier).updateSettings(
                        settings.copyWith(backupBeforeSync: value),
                      );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('自动解决冲突'),
                subtitle: const Text('使用本地优先策略自动处理冲突'),
                value: settings.autoResolveConflicts,
                onChanged: (value) {
                  ref.read(syncProvider.notifier).updateSettings(
                        settings.copyWith(autoResolveConflicts: value),
                      );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('最大备份数'),
                subtitle: Text('保留最近${settings.maxBackupCount}个备份'),
                trailing: DropdownButton<int>(
                  value: settings.maxBackupCount,
                  items: [3, 5, 10, 20].map((count) {
                    return DropdownMenuItem(
                      value: count,
                      child: Text('$count'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(syncProvider.notifier).updateSettings(
                            settings.copyWith(maxBackupCount: value),
                          );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
