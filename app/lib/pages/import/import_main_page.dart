import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../theme/app_theme.dart';
import '../import_page.dart';
import 'smart_format_detection_page.dart';
import 'import_history_page.dart';
import 'smart_directory_discovery_page.dart';
import 'bill_export_tutorial_page.dart';

/// 导入账单主页
/// 原型设计 5.01：导入账单
/// - 上传区域（点击或拖拽文件）
/// - 快速导入选项（微信、支付宝、银行、通用）
/// - 最近导入记录
class ImportMainPage extends ConsumerStatefulWidget {
  const ImportMainPage({super.key});

  @override
  ConsumerState<ImportMainPage> createState() => _ImportMainPageState();
}

class _ImportMainPageState extends ConsumerState<ImportMainPage> {
  bool _isLoading = false;

  // 快速导入选项
  final List<QuickImportOption> _quickOptions = [
    QuickImportOption(
      id: 'wechat',
      name: '微信账单',
      icon: Icons.chat,
      color: const Color(0xFF07C160),
    ),
    QuickImportOption(
      id: 'alipay',
      name: '支付宝账单',
      icon: Icons.account_balance_wallet,
      color: const Color(0xFF1677FF),
    ),
    QuickImportOption(
      id: 'bank',
      name: '银行账单',
      icon: Icons.account_balance,
      color: const Color(0xFFE53935),
    ),
    QuickImportOption(
      id: 'generic',
      name: '通用格式',
      icon: Icons.description,
      color: const Color(0xFF6495ED),
    ),
  ];

  // 最近导入记录（模拟数据）
  final List<RecentImportRecord> _recentImports = [
    RecentImportRecord(
      fileName: '微信账单_202512.csv',
      importDate: DateTime.now().subtract(const Duration(days: 2)),
      count: 156,
      source: 'wechat',
      status: ImportRecordStatus.success,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUploadArea(context, theme),
                    _buildQuickImportSection(context, theme),
                    _buildRecentImportsSection(context, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back),
            ),
          ),
          const Expanded(
            child: Text(
              '导入账单',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _navigateToSmartDiscovery(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.folder_open,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 上传区域
  Widget _buildUploadArea(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: _isLoading ? null : _selectFile,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Icon(
                    Icons.cloud_upload,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '点击或拖拽文件到此处',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '支持 CSV、Excel、OFX 格式',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 快速导入选项
  Widget _buildQuickImportSection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快速导入',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: _quickOptions.length,
            itemBuilder: (context, index) {
              final option = _quickOptions[index];
              return _buildQuickOptionCard(context, theme, option);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOptionCard(
    BuildContext context,
    ThemeData theme,
    QuickImportOption option,
  ) {
    return GestureDetector(
      onTap: () => _handleQuickImport(context, option),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: option.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              option.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 最近导入记录
  Widget _buildRecentImportsSection(BuildContext context, ThemeData theme) {
    if (_recentImports.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '最近导入',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToHistory(context),
                child: Text(
                  '查看全部',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_recentImports.take(3).map((record) => _buildRecentImportItem(theme, record))),
        ],
      ),
    );
  }

  Widget _buildRecentImportItem(ThemeData theme, RecentImportRecord record) {
    final sourceColors = {
      'wechat': const Color(0xFF07C160),
      'alipay': const Color(0xFF1677FF),
      'bank': const Color(0xFFE53935),
    };
    final sourceIcons = {
      'wechat': Icons.chat,
      'alipay': Icons.account_balance_wallet,
      'bank': Icons.account_balance,
    };

    final color = sourceColors[record.source] ?? theme.colorScheme.primary;
    final icon = sourceIcons[record.source] ?? Icons.description;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '导入 ${record.count} 笔 · ${_formatDate(record.importDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '成功',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  Future<void> _selectFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx', 'ofx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SmartFormatDetectionPage(
                filePath: file.path!,
                fileName: file.name,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleQuickImport(BuildContext context, QuickImportOption option) {
    if (option.id == 'bank') {
      // 跳转到银行账单导入页面
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ImportPage()),
      );
    } else if (option.id == 'wechat' || option.id == 'alipay') {
      // 显示教程
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BillExportTutorialPage(
            initialPlatform: option.id,
          ),
        ),
      );
    } else {
      // 通用格式直接选择文件
      _selectFile();
    }
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportHistoryPage()),
    );
  }

  void _navigateToSmartDiscovery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SmartDirectoryDiscoveryPage()),
    );
  }
}

/// 快速导入选项
class QuickImportOption {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  QuickImportOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// 最近导入记录
class RecentImportRecord {
  final String fileName;
  final DateTime importDate;
  final int count;
  final String source;
  final ImportRecordStatus status;

  RecentImportRecord({
    required this.fileName,
    required this.importDate,
    required this.count,
    required this.source,
    required this.status,
  });
}

/// 导入记录状态
enum ImportRecordStatus {
  success,
  partial,
  failed,
}
