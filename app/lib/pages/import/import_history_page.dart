import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/import_batch.dart';
import '../../core/di/service_locator.dart';
import '../../core/contracts/i_database_service.dart';

/// 导入历史Provider - 从数据库获取真实数据
final importBatchesProvider = FutureProvider<List<ImportBatch>>((ref) async {
  final db = sl<IDatabaseService>();
  return await db.getImportBatches();
});

/// 导入历史页面
/// 原型设计 5.08：导入历史
/// - 统计卡片（渐变背景，总导入次数、导入交易数）
/// - 历史记录列表（状态图标、文件名、日期、导入数量）
/// 数据来源：importBatchesProvider（从数据库获取真实导入批次）
class ImportHistoryPage extends ConsumerStatefulWidget {
  const ImportHistoryPage({super.key});

  @override
  ConsumerState<ImportHistoryPage> createState() => _ImportHistoryPageState();
}

class _ImportHistoryPageState extends ConsumerState<ImportHistoryPage> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshHistory() async {
    // ignore: unused_result
    ref.refresh(importBatchesProvider);
  }

  /// 将ImportBatch转换为显示用的ImportHistoryItem
  List<ImportHistoryItem> _convertBatchesToHistoryItems(List<ImportBatch> batches) {
    return batches.map((batch) {
      ImportHistoryStatus status;
      if (batch.failedCount > 0 && batch.importedCount == 0) {
        status = ImportHistoryStatus.failed;
      } else if (batch.failedCount > 0 || batch.skippedCount > 0) {
        status = ImportHistoryStatus.partial;
      } else {
        status = ImportHistoryStatus.success;
      }

      return ImportHistoryItem(
        fileName: batch.fileName,
        importDate: batch.createdAt,
        importedCount: batch.importedCount,
        duplicateCount: batch.skippedCount,
        totalCount: batch.totalCount,
        status: status,
        errorMessage: batch.errorLog,
      );
    }).toList();
  }

  /// 计算统计数据
  ({int totalImports, int totalTransactions}) _calculateStats(List<ImportBatch> batches) {
    final totalImports = batches.length;
    final totalTransactions = batches.fold<int>(0, (sum, batch) => sum + batch.importedCount);
    return (totalImports: totalImports, totalTransactions: totalTransactions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batchesAsync = ref.watch(importBatchesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPageHeader(context, theme),
            Expanded(
              child: batchesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('加载失败: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshHistory,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
                data: (batches) {
                  final stats = _calculateStats(batches);
                  final historyItems = _convertBatchesToHistoryItems(batches);

                  return RefreshIndicator(
                    onRefresh: _refreshHistory,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          _buildStatsCard(context, theme, stats.totalImports, stats.totalTransactions),
                          _buildHistoryList(context, theme, historyItems),
                        ],
                      ),
                    ),
                  );
                },
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

  Widget _buildStatsCard(BuildContext context, ThemeData theme, int totalImports, int totalTransactions) {
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
                '$totalImports',
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
                '$totalTransactions',
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

  Widget _buildHistoryList(BuildContext context, ThemeData theme, List<ImportHistoryItem> historyItems) {
    if (historyItems.isEmpty) {
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
        children: historyItems.map((item) => _buildHistoryItem(theme, item)).toList(),
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
