import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../core/build_info.dart';
import '../core/logger.dart';
import '../providers/app_info_provider.dart';
import '../providers/upgrade_provider.dart';
import '../services/app_upgrade_service.dart';
import '../widgets/app_update_dialog.dart';
import 'agreement_page.dart';
import 'help_page.dart';

/// 关于我们页面
class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  int _cacheSize = 0;
  bool _loadingCache = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    setState(() => _loadingCache = true);
    try {
      final size = await AppUpgradeService().getDownloadCacheSize();
      if (mounted) {
        setState(() {
          _cacheSize = size;
          _loadingCache = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCache = false);
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final appInfo = ref.watch(appInfoSyncProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.about),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // App Logo and Info
            _buildAppHeader(context),
            const SizedBox(height: 24),

            // Menu Items
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.system_update,
                    iconColor: AppColors.primary,
                    title: context.l10n.checkUpdateTitle,
                    subtitle: context.l10n.currentVersionLabel(BuildInfo.displayVersion),
                    onTap: () => _checkForUpdate(context),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.cleaning_services,
                    iconColor: const Color(0xFFFF9800),
                    title: context.l10n.cleanDownloadCache,
                    subtitle: _loadingCache
                        ? context.l10n.calculating
                        : (_cacheSize > 0 ? context.l10n.cachedSize(_formatSize(_cacheSize)) : context.l10n.noCache),
                    onTap: () => _showDownloadCacheDialog(context),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    iconColor: const Color(0xFF2196F3),
                    title: context.l10n.helpAndFeedback,
                    subtitle: context.l10n.helpAndFeedbackDesc,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HelpPage()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Version Info Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Column(
                children: [
                  _buildInfoItem(context.l10n.versionNumber, BuildInfo.fullVersion),
                  _buildDivider(),
                  _buildInfoItem(context.l10n.buildTime, BuildInfo.buildTimeFormatted),
                  _buildDivider(),
                  _buildInfoItem(context.l10n.packageName, appInfo.packageName),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Other Links
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.description,
                    iconColor: AppColors.textSecondary,
                    title: context.l10n.userAgreement,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AgreementPage(
                          type: AgreementType.userAgreement,
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.privacy_tip,
                    iconColor: AppColors.textSecondary,
                    title: context.l10n.privacyPolicy,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AgreementPage(
                          type: AgreementType.privacyPolicy,
                        ),
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.bug_report,
                    iconColor: const Color(0xFF795548),
                    title: context.l10n.logManagement,
                    subtitle: context.l10n.logManagementDesc,
                    onTap: () => _showLogManagementDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Copyright
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.copyrightText(DateTime.now().year),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.appName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v${BuildInfo.version}',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.smartFinanceAssistant,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 56,
      color: AppColors.divider,
    );
  }

  // ignore: unused_element
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature 功能即将上线')),
    );
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await ref.read(upgradeProvider.notifier).checkUpdate(force: true);

    if (context.mounted) {
      Navigator.pop(context); // 关闭加载对话框

      if (result != null && result.hasUpdate && result.latestVersion != null) {
        await AppUpdateDialog.show(
          context,
          versionInfo: result.latestVersion!,
          isForceUpdate: result.isForceUpdate,
        );
      } else {
        // 检查是否有错误信息
        final errorMsg = result?.message;
        final isError = errorMsg != null && errorMsg.contains('失败');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isError ? errorMsg : context.l10n.alreadyLatest),
            backgroundColor: isError ? Colors.red : Colors.green,
          ),
        );
      }
    }
  }

  void _showDownloadCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DownloadCacheDialog(
        onCacheCleared: () {
          _loadCacheSize();
        },
      ),
    );
  }

  void _showLogManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _LogManagementDialog(),
    );
  }
}

/// Download cache management dialog
class _DownloadCacheDialog extends StatefulWidget {
  final VoidCallback? onCacheCleared;

  const _DownloadCacheDialog({this.onCacheCleared});

  @override
  State<_DownloadCacheDialog> createState() => _DownloadCacheDialogState();
}

class _DownloadCacheDialogState extends State<_DownloadCacheDialog> {
  int _cacheSize = 0;
  List<Map<String, dynamic>> _cacheFiles = [];
  bool _loading = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    setState(() => _loading = true);
    try {
      final upgradeService = AppUpgradeService();
      final size = await upgradeService.getDownloadCacheSize();
      final files = await upgradeService.getDownloadCacheFiles();

      final fileInfos = <Map<String, dynamic>>[];
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          fileInfos.add({
            'path': file.path,
            'name': file.path.split('/').last,
            'size': stat.size,
            'modified': stat.modified,
          });
        }
      }

      fileInfos.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));

      setState(() {
        _cacheSize = size;
        _cacheFiles = fileInfos;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmDelete),
        content: Text(context.l10n.confirmClearCache),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.cleanupText, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _clearing = true);
      final deletedSize = await AppUpgradeService().clearDownloadCache();
      await _loadCacheInfo();
      widget.onCacheCleared?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清理 ${_formatSize(deletedSize)}')),
        );
        setState(() => _clearing = false);
      }
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        await _loadCacheInfo();
        widget.onCacheCleared?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件已删除')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cleaning_services, color: Color(0xFFFF9800)),
          const SizedBox(width: 8),
          Text(context.l10n.downloadCacheManagement),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_cacheFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.folder_open, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text(context.l10n.noCacheFiles, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storage, color: Color(0xFFFF9800), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '总大小: ${_formatSize(_cacheSize)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${_cacheFiles.length} 个文件',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.cacheFileList,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _cacheFiles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = _cacheFiles[index];
                    final name = file['name'] as String;
                    final size = file['size'] as int;
                    final modified = file['modified'] as DateTime;
                    final path = file['path'] as String;

                    IconData icon = Icons.insert_drive_file;
                    Color iconColor = AppColors.textSecondary;
                    if (name.endsWith('.apk')) {
                      icon = Icons.android;
                      iconColor = const Color(0xFF4CAF50);
                    } else if (name.endsWith('.tmp')) {
                      icon = Icons.hourglass_empty;
                      iconColor = const Color(0xFFFF9800);
                    } else if (name.endsWith('.patch')) {
                      icon = Icons.difference;
                      iconColor = const Color(0xFF2196F3);
                    }

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon, color: iconColor, size: 24),
                      title: Text(
                        name,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_formatSize(size)} • ${_formatDate(modified)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () => _deleteFile(path),
                        tooltip: context.l10n.delete,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_cacheFiles.isNotEmpty)
          TextButton.icon(
            onPressed: _clearing ? null : _clearAllCache,
            icon: _clearing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
            label: Text(
              _clearing ? context.l10n.clearingCache : context.l10n.clearAllCache,
              style: TextStyle(color: _clearing ? AppColors.textSecondary : Colors.red),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}

/// Log management dialog
class _LogManagementDialog extends StatefulWidget {
  const _LogManagementDialog();

  @override
  State<_LogManagementDialog> createState() => _LogManagementDialogState();
}

class _LogManagementDialogState extends State<_LogManagementDialog> {
  int _logSize = 0;
  int _fileCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogInfo();
  }

  Future<void> _loadLogInfo() async {
    setState(() => _loading = true);
    try {
      final size = await logger.getLogSize();
      final files = await logger.getLogFiles();
      setState(() {
        _logSize = size;
        _fileCount = files.length;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清理'),
        content: const Text('确定要清理所有日志文件吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清理', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await logger.clearAllLogs();
      await _loadLogInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已清理')),
        );
      }
    }
  }

  Future<void> _exportLogs() async {
    try {
      final file = await logger.exportLogs();
      if (file != null && mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'AI记账日志导出',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('日志管理'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            ListTile(
              leading: const Icon(Icons.storage, color: AppColors.primary),
              title: const Text('日志大小'),
              subtitle: Text(_formatSize(_logSize)),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppColors.income),
              title: const Text('日志文件数'),
              subtitle: Text('$_fileCount 个文件'),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const Text(
              '日志自动清理策略：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 保留最近 7 天的日志\n'
              '• 单个文件最大 5MB\n'
              '• 总大小上限 50MB',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _loading ? null : _exportLogs,
          icon: const Icon(Icons.share, size: 18),
          label: const Text('导出'),
        ),
        TextButton.icon(
          onPressed: _loading ? null : _clearLogs,
          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
          label: const Text('清理', style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
