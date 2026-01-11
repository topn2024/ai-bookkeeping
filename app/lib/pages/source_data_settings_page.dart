import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/source_file_service.dart';

/// Settings page for source data management.
///
/// Features:
/// - Configure retention period (1 week, 2 weeks, 1 month)
/// - View storage usage statistics
/// - Manual cleanup option
/// - WiFi sync toggle
class SourceDataSettingsPage extends StatefulWidget {
  const SourceDataSettingsPage({super.key});

  @override
  State<SourceDataSettingsPage> createState() => _SourceDataSettingsPageState();
}

class _SourceDataSettingsPageState extends State<SourceDataSettingsPage> {
  final SourceFileService _fileService = SourceFileService();

  int _retentionDays = 7;
  bool _wifiSyncEnabled = true;
  SourceFileStorageInfo? _storageInfo;
  bool _isLoading = true;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final retentionDays = await _fileService.getRetentionDays();
      final wifiSyncEnabled = await _fileService.isWifiSyncEnabled();
      final storageInfo = await _fileService.getStorageInfo();

      setState(() {
        _retentionDays = retentionDays;
        _wifiSyncEnabled = wifiSyncEnabled;
        _storageInfo = storageInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载设置失败: $e')),
        );
      }
    }
  }

  Future<void> _updateRetentionDays(int days) async {
    try {
      await _fileService.setRetentionDays(days);
      setState(() => _retentionDays = days);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存设置失败: $e')),
        );
      }
    }
  }

  Future<void> _updateWifiSync(bool enabled) async {
    try {
      await _fileService.setWifiSyncEnabled(enabled);
      setState(() => _wifiSyncEnabled = enabled);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存设置失败: $e')),
        );
      }
    }
  }

  Future<void> _cleanupExpiredFiles() async {
    setState(() => _isCleaning = true);

    try {
      final deletedCount = await _fileService.cleanupExpiredFiles();
      final storageInfo = await _fileService.getStorageInfo();

      setState(() {
        _storageInfo = storageInfo;
        _isCleaning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deletedCount > 0
                ? '已清理 $deletedCount 个过期文件'
                : '没有需要清理的文件'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCleaning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清理失败: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearAllFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有原始来源文件吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isCleaning = true);

      try {
        final deletedCount = await _fileService.deleteAllFiles();
        final storageInfo = await _fileService.getStorageInfo();

        setState(() {
          _storageInfo = storageInfo;
          _isCleaning = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已清空 $deletedCount 个文件')),
          );
        }
      } catch (e) {
        setState(() => _isCleaning = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清空失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('来源数据管理'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Storage info section
                _buildStorageSection(),
                const Divider(height: 1),

                // Retention period section
                _buildRetentionSection(),
                const Divider(height: 1),

                // WiFi sync section
                _buildWifiSyncSection(),
                const Divider(height: 1),

                // Cleanup section
                _buildCleanupSection(),
              ],
            ),
    );
  }

  Widget _buildStorageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '存储空间',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStorageCard(
                  icon: Icons.image,
                  label: '图片',
                  count: _storageInfo?.imageCount ?? 0,
                  size: _storageInfo?.formattedImageSize ?? '0 B',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStorageCard(
                  icon: Icons.mic,
                  label: '录音',
                  count: _storageInfo?.audioCount ?? 0,
                  size: _storageInfo?.formattedAudioSize ?? '0 B',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('总占用空间'),
                Text(
                  _storageInfo?.formattedTotalSize ?? '0 B',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCard({
    required IconData icon,
    required String label,
    required int count,
    required String size,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            '$count 个',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            size,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '保留时间',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '超过保留时间的原始文件将被自动清理',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildRetentionOption(7, '1周'),
              const SizedBox(width: 12),
              _buildRetentionOption(14, '2周'),
              const SizedBox(width: 12),
              _buildRetentionOption(30, '1个月'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionOption(int days, String label) {
    final isSelected = _retentionDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateRetentionDays(days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWifiSyncSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WiFi同步',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '连接WiFi时自动同步原始文件到服务器',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _wifiSyncEnabled,
            onChanged: _updateWifiSync,
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '清理',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCleaning ? null : _cleanupExpiredFiles,
              icon: _isCleaning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cleaning_services),
              label: Text(_isCleaning ? '清理中...' : '清理过期文件'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCleaning ? null : _confirmClearAllFiles,
              icon: const Icon(Icons.delete_forever, color: AppColors.expense),
              label: const Text('清空所有文件',
                  style: TextStyle(color: AppColors.expense)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.expense),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
