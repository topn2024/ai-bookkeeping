import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';

/// 导入历史页面
/// 原型设计 5.08：导入历史
/// - 统计卡片（渐变背景，总导入次数、导入交易数）
/// - 历史记录列表（状态图标、文件名、日期、导入数量）
class ImportHistoryPage extends ConsumerStatefulWidget {
  const ImportHistoryPage({super.key});

  @override
  ConsumerState<ImportHistoryPage> createState() => _ImportHistoryPageState();
}

class _ImportHistoryPageState extends ConsumerState<ImportHistoryPage> {
  bool _isLoading = true;

  // 模拟统计数据
  final int _totalImports = 12;
  final int _totalTransactions = 856;

  // 模拟历史记录
  final List<ImportHistoryItem> _historyItems = [
    ImportHistoryItem(
      fileName: '微信账单_202412.csv',
      importDate: DateTime.now().subtract(const Duration(days: 2)),
      importedCount: 126,
      duplicateCount: 3,
      status: ImportHistoryStatus.success,
    ),
    ImportHistoryItem(
      fileName: '支付宝账单_202412.csv',
      importDate: DateTime.now().subtract(const Duration(days: 5)),
      importedCount: 89,
      duplicateCount: 1,
      status: ImportHistoryStatus.success,
    ),
    ImportHistoryItem(
      fileName: '工行账单.pdf',
      importDate: DateTime.now().subtract(const Duration(days: 8)),
      importedCount: 56,
      duplicateCount: 4,
      totalCount: 60,
      status: ImportHistoryStatus.partial,
    ),
    ImportHistoryItem(
      fileName: '建行账单_202411.csv',
      importDate: DateTime.now().subtract(const Duration(days: 15)),
      importedCount: 78,
      duplicateCount: 0,
      status: ImportHistoryStatus.success,
    ),
    ImportHistoryItem(
      fileName: '招行账单.xlsx',
      importDate: DateTime.now().subtract(const Duration(days: 20)),
      importedCount: 0,
      duplicateCount: 0,
      status: ImportHistoryStatus.failed,
      errorMessage: '文件格式不支持',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildStatsCard(context, theme),
                            _buildHistoryList(context, theme),
                          ],
                        ),
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
              '导入历史',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '$_totalImports',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '总导入次数',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Column(
            children: [
              Text(
                '$_totalTransactions',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '导入交易数',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, ThemeData theme) {
    if (_historyItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无导入记录',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _historyItems.map((item) => _buildHistoryItem(theme, item)).toList(),
      ),
    );
  }

  Widget _buildHistoryItem(ThemeData theme, ImportHistoryItem item) {
    final dateFormat = DateFormat('M月d日 HH:mm');

    Color statusColor;
    IconData statusIcon;
    String statusText;
    String countText;

    switch (item.status) {
      case ImportHistoryStatus.success:
        statusColor = AppColors.success;
        statusIcon = Icons.check;
        statusText = '+${item.importedCount}笔';
        countText = item.duplicateCount > 0 ? '重复${item.duplicateCount}笔' : '';
        break;
      case ImportHistoryStatus.partial:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusText = '部分成功';
        countText = '${item.importedCount}/${item.totalCount ?? item.importedCount}笔';
        break;
      case ImportHistoryStatus.failed:
        statusColor = AppColors.error;
        statusIcon = Icons.error;
        statusText = '导入失败';
        countText = item.errorMessage ?? '';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(statusIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dateFormat.format(item.importDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
              if (countText.isNotEmpty)
                Text(
                  countText,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 导入历史记录项
class ImportHistoryItem {
  final String fileName;
  final DateTime importDate;
  final int importedCount;
  final int duplicateCount;
  final int? totalCount;
  final ImportHistoryStatus status;
  final String? errorMessage;

  ImportHistoryItem({
    required this.fileName,
    required this.importDate,
    required this.importedCount,
    required this.duplicateCount,
    this.totalCount,
    required this.status,
    this.errorMessage,
  });
}

/// 导入历史状态
enum ImportHistoryStatus {
  success,
  partial,
  failed,
}
