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
    _tabController = TabController(length: 3, vsync: this);
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
          tabs: [
            Tab(
              icon: Icon(syncState.status.icon),
              text: '同步',
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
              icon: Icon(Icons.settings),
              text: '设置',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SyncTab(syncState: syncState),
          _BackupTab(syncState: syncState),
          _SettingsTab(syncState: syncState),
        ],
      ),
    );
  }
}

class _SyncTab extends ConsumerWidget {
  final SyncState syncState;

  const _SyncTab({required this.syncState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 同步状态卡片
          _buildStatusCard(context, ref),
          const SizedBox(height: 16),

          // 快速操作
          _buildQuickActions(context, ref),
          const SizedBox(height: 16),

          // 同步历史
          _buildSyncHistory(context),
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
                color: syncState.status.color.withOpacity(0.1),
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
                  color: Colors.red.withOpacity(0.1),
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

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快速操作',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.cloud_upload,
                    label: '上传',
                    color: Colors.blue,
                    enabled: syncState.canSync,
                    onTap: () => ref
                        .read(syncProvider.notifier)
                        .sync(direction: SyncDirection.upload),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.cloud_download,
                    label: '下载',
                    color: Colors.green,
                    enabled: syncState.canSync,
                    onTap: () => ref
                        .read(syncProvider.notifier)
                        .sync(direction: SyncDirection.download),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.sync,
                    label: '双向同步',
                    color: Colors.purple,
                    enabled: syncState.canSync,
                    onTap: () => ref.read(syncProvider.notifier).sync(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncHistory(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '同步历史',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${syncState.history.length}条记录',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (syncState.history.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        '暂无同步记录',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...syncState.history.take(5).map((record) => _SyncRecordTile(
                    record: record,
                  )),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: enabled ? color : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncRecordTile extends StatelessWidget {
  final SyncRecord record;

  const _SyncRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: record.status.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              record.direction.icon,
              size: 18,
              color: record.status.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.direction.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${record.itemsUploaded}上传 / ${record.itemsDownloaded}下载',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(record.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                '${record.duration.inSeconds}秒',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
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
            Text('确定要恢复这个备份吗？'),
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
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
      await ref.read(syncProvider.notifier).deleteBackup(backup.id);
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
                    color: Colors.blue.withOpacity(0.1),
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
                subtitle: const Text('使用默认策略自动处理冲突'),
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
