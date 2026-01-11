import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../models/import_batch.dart';
import 'import/smart_format_detection_page.dart';
import 'import/import_history_page.dart';

/// 银行账单导入页面
/// 原型设计 5.06：银行账单导入
/// - 银行选择网格（工行、建行、农行、招行等）
/// - 上传文件区域（虚线框，支持CSV/Excel/PDF）
/// - 最近导入记录列表
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  String? _selectedBank;
  bool _isLoading = false;
  List<RecentImport> _recentImports = [];

  @override
  void initState() {
    super.initState();
    _loadRecentImports();
  }

  // 银行列表
  final List<BankInfo> _banks = [
    BankInfo(id: 'icbc', name: '工商银行', shortName: '工行', color: const Color(0xFFE60012)),
    BankInfo(id: 'ccb', name: '建设银行', shortName: '建行', color: const Color(0xFFCC0000)),
    BankInfo(id: 'abc', name: '农业银行', shortName: '农行', color: const Color(0xFFDE2910)),
    BankInfo(id: 'cmb', name: '招商银行', shortName: '招行', color: const Color(0xFF003DA5)),
    BankInfo(id: 'wechat', name: '微信支付', shortName: '微信', color: const Color(0xFF1AAD19)),
    BankInfo(id: 'alipay', name: '支付宝', shortName: '支付宝', color: const Color(0xFF1677FF)),
    BankInfo(id: 'boc', name: '中国银行', shortName: '中行', color: const Color(0xFFC80000)),
    BankInfo(id: 'other', name: '其他银行', shortName: '其他', color: Colors.grey),
  ];

  /// 加载最近导入记录
  Future<void> _loadRecentImports() async {
    try {
      final db = await sl<IDatabaseService>().database;
      final results = await db.query(
        'import_batches',
        orderBy: 'createdAt DESC',
        limit: 3,
      );

      if (mounted) {
        setState(() {
          _recentImports = results.map((row) {
            final batch = ImportBatch.fromMap(row);

            // 根据导入结果确定状态
            ImportStatus status;
            if (batch.failedCount == 0 && batch.skippedCount < batch.totalCount / 2) {
              status = ImportStatus.success;
            } else if (batch.failedCount > 0 || batch.skippedCount >= batch.totalCount / 2) {
              status = ImportStatus.partial;
            } else {
              status = ImportStatus.failed;
            }

            return RecentImport(
              fileName: batch.fileName,
              importDate: batch.createdAt,
              count: batch.importedCount,
              status: status,
            );
          }).toList();
        });
      }
    } catch (e) {
      // 加载失败时保持空列表
      if (mounted) {
        setState(() {
          _recentImports = [];
        });
      }
    }
  }

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
                    _buildBankSelection(context, theme),
                    _buildUploadArea(context, theme),
                    _buildRecentImports(context, theme),
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
              '银行账单导入',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () => _navigateToHistory(context),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.history,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 银行选择网格
  Widget _buildBankSelection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择银行',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: _banks.length,
            itemBuilder: (context, index) {
              final bank = _banks[index];
              final isSelected = _selectedBank == bank.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedBank = bank.id),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: bank.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          bank.shortName.length > 2
                              ? bank.shortName.substring(0, 2)
                              : bank.shortName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bank.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 上传区域
  Widget _buildUploadArea(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _isLoading ? null : _selectFile,
        child: Container(
          width: double.infinity,
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
                      Icons.upload_file,
                      size: 48,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '上传账单文件',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '支持 CSV、Excel、PDF 格式',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 最近导入记录
  Widget _buildRecentImports(BuildContext context, ThemeData theme) {
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
          ...(_recentImports.take(3).map((record) => _buildImportItem(theme, record))),
        ],
      ),
    );
  }

  Widget _buildImportItem(ThemeData theme, RecentImport record) {
    final dateFormat = DateFormat('M月d日');
    final statusColor = record.status == ImportStatus.success
        ? AppColors.success
        : (record.status == ImportStatus.partial ? Colors.orange : AppColors.error);
    final statusIcon = record.status == ImportStatus.success
        ? Icons.check_circle
        : (record.status == ImportStatus.partial ? Icons.warning : Icons.error);

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
          Icon(statusIcon, color: statusColor, size: 24),
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
                  '${dateFormat.format(record.importDate)} · 导入${record.count}笔',
                  style: TextStyle(
                    fontSize: 12,
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

  Future<void> _selectFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx', 'pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (mounted) {
          // 跳转到智能格式检测页面
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SmartFormatDetectionPage(
                filePath: file.path!,
                fileName: file.name,
                selectedBank: _selectedBank,
              ),
            ),
          );
          // 返回后刷新导入记录
          _loadRecentImports();
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

  void _navigateToHistory(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportHistoryPage()),
    );
    // 返回后刷新导入记录
    _loadRecentImports();
  }
}

/// 银行信息
class BankInfo {
  final String id;
  final String name;
  final String shortName;
  final Color color;

  BankInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
  });
}

/// 最近导入记录
class RecentImport {
  final String fileName;
  final DateTime importDate;
  final int count;
  final ImportStatus status;

  RecentImport({
    required this.fileName,
    required this.importDate,
    required this.count,
    required this.status,
  });
}

/// 导入状态
enum ImportStatus {
  success,
  partial,
  failed,
}
