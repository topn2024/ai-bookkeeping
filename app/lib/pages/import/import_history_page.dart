import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/import_batch.dart';
import '../../models/transaction.dart';
import '../../services/import/batch_import_service.dart';
import '../../providers/transaction_provider.dart';

/// Import history page showing past batch imports
class ImportHistoryPage extends ConsumerStatefulWidget {
  const ImportHistoryPage({super.key});

  @override
  ConsumerState<ImportHistoryPage> createState() => _ImportHistoryPageState();
}

class _ImportHistoryPageState extends ConsumerState<ImportHistoryPage> {
  final BatchImportService _importService = BatchImportService();
  List<ImportBatch>? _batches;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final batches = await _importService.getImportHistory();
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载历史失败: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入历史'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_batches == null || _batches!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无导入记录',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _batches!.length,
        itemBuilder: (context, index) {
          return _buildBatchCard(_batches![index]);
        },
      ),
    );
  }

  Widget _buildBatchCard(ImportBatch batch) {
    final isRevoked = batch.status == ImportBatchStatus.revoked;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isRevoked ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isRevoked
                          ? Colors.grey.withValues(alpha: 0.1)
                          : Colors.indigo.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRevoked ? Icons.undo : Icons.upload_file,
                      color: isRevoked ? Colors.grey : Colors.indigo,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(batch.createdAt),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRevoked
                          ? Colors.grey.withValues(alpha: 0.1)
                          : AppColors.income.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isRevoked ? '已撤销' : '已导入',
                      style: TextStyle(
                        color: isRevoked ? Colors.grey : AppColors.income,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('导入', '${batch.importedCount}', AppColors.income),
                  _buildStat('跳过', '${batch.skippedCount}', AppColors.textSecondary),
                  if (batch.failedCount > 0)
                    _buildStat('失败', '${batch.failedCount}', AppColors.expense),
                  _buildStat('总计', '${batch.totalCount}', Colors.indigo),
                ],
              ),
              // Amount summary
              if (batch.totalExpense > 0 || batch.totalIncome > 0) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (batch.totalExpense > 0)
                      Text(
                        '支出 ¥${batch.totalExpense.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.expense,
                          fontSize: 12,
                        ),
                      ),
                    if (batch.totalExpense > 0 && batch.totalIncome > 0)
                      Text(
                        '  |  ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    if (batch.totalIncome > 0)
                      Text(
                        '收入 ¥${batch.totalIncome.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.income,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
              // Date range
              if (batch.dateRangeStart != null && batch.dateRangeEnd != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.date_range, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('MM-dd').format(batch.dateRangeStart!)} ~ ${DateFormat('MM-dd').format(batch.dateRangeEnd!)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              // Actions
              if (!isRevoked) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _viewTransactions(batch),
                      icon: const Icon(Icons.list, size: 18),
                      label: const Text('查看'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmRevoke(batch),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('撤销'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _viewTransactions(ImportBatch batch) async {
    // Show transactions in this batch
    final transactions = await _importService.getTransactionsByBatchId(batch.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${batch.fileName} (${transactions.length}条)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: Text(
                        '没有交易记录',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final t = transactions[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getTypeColor(t.type).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getTypeIcon(t.type),
                              color: _getTypeColor(t.type),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            t.note ?? t.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            DateFormat('MM-dd HH:mm').format(t.date),
                          ),
                          trailing: Text(
                            '${t.type == TransactionType.expense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getTypeColor(t.type),
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

  Future<void> _confirmRevoke(ImportBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销导入'),
        content: Text(
          '确定要撤销 "${batch.fileName}" 的导入吗？\n\n'
          '这将删除该批次导入的 ${batch.importedCount} 条交易记录，此操作不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('撤销'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _importService.revokeImportBatch(batch.id);

      // Refresh transaction list
      ref.invalidate(transactionProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已撤销导入'),
            backgroundColor: AppColors.income,
          ),
        );
      }

      await _loadHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('撤销失败: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.transfer:
        return AppColors.transfer;
    }
  }

  IconData _getTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return Icons.arrow_downward;
      case TransactionType.income:
        return Icons.arrow_upward;
      case TransactionType.transfer:
        return Icons.swap_horiz;
    }
  }
}
