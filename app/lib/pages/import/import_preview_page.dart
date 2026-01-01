import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import '../../services/import/batch_import_service.dart';
import '../../services/import/bill_format_detector.dart';
import '../../services/import/bill_parser.dart';
import '../../providers/transaction_provider.dart';

/// Import preview page for reviewing and confirming candidates
class ImportPreviewPage extends ConsumerStatefulWidget {
  final BatchImportService importService;
  final BillFormatResult formatResult;
  final BillParseResult parseResult;

  const ImportPreviewPage({
    super.key,
    required this.importService,
    required this.formatResult,
    required this.parseResult,
  });

  @override
  ConsumerState<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends ConsumerState<ImportPreviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isImporting = false;
  String _filterType = 'all'; // all, import, skip, duplicate
  ImportCandidateSummary? _summary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _updateSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateSummary() {
    setState(() {
      _summary = widget.importService.getSummary();
    });
  }

  List<ImportCandidate> get _candidates =>
      widget.importService.lastCandidates ?? [];

  List<ImportCandidate> get _filteredCandidates {
    switch (_filterType) {
      case 'import':
        return _candidates.where((c) => c.action == ImportAction.import_).toList();
      case 'skip':
        return _candidates.where((c) => c.action == ImportAction.skip).toList();
      case 'duplicate':
        return _candidates.where((c) => c.isDuplicate).toList();
      default:
        return _candidates;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('预览导入'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'smart',
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high, size: 20),
                    SizedBox(width: 8),
                    Text('智能选择'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_all',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text('全部导入'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'skip_duplicates',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20),
                    const SizedBox(width: 8),
                    const Text('跳过所有重复'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '待导入'),
            Tab(text: '重复检测'),
          ],
          onTap: (index) {
            setState(() {
              switch (index) {
                case 0:
                  _filterType = 'all';
                  break;
                case 1:
                  _filterType = 'import';
                  break;
                case 2:
                  _filterType = 'duplicate';
                  break;
              }
            });
          },
        ),
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          Expanded(
            child: _buildCandidateList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSummaryBar() {
    if (_summary == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('总计', _summary!.totalCount, Colors.indigo),
          _buildSummaryItem('导入', _summary!.toImportCount, AppColors.income),
          _buildSummaryItem('重复', _summary!.duplicateCount, Colors.orange),
          _buildSummaryItem('跳过', _summary!.toSkipCount, AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCandidateList() {
    final candidates = _filteredCandidates;

    if (candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '没有符合筛选条件的记录',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        return _buildCandidateCard(candidates[index]);
      },
    );
  }

  Widget _buildCandidateCard(ImportCandidate candidate) {
    final isSkipped = candidate.action == ImportAction.skip;
    final hasDuplicate = candidate.duplicateResult != null &&
        candidate.duplicateResult!.level != DuplicateLevel.none;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showCandidateDetail(candidate),
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isSkipped ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Type icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getTypeColor(candidate.type).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getTypeIcon(candidate.type),
                        color: _getTypeColor(candidate.type),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.note ?? candidate.rawMerchant ?? '未知',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(candidate.date),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Amount
                    Text(
                      '${candidate.type == TransactionType.expense ? '-' : '+'}¥${candidate.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _getTypeColor(candidate.type),
                      ),
                    ),
                  ],
                ),
                // Duplicate warning
                if (hasDuplicate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getDuplicateLevelColor(candidate.duplicateResult!.level)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: _getDuplicateLevelColor(candidate.duplicateResult!.level),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_getDuplicateLevelName(candidate.duplicateResult!.level)} (${candidate.duplicateResult!.score}分)',
                                style: TextStyle(
                                  color: _getDuplicateLevelColor(candidate.duplicateResult!.level),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                candidate.duplicateResult!.reason,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Action buttons
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (candidate.category != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          candidate.category!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    // Toggle button
                    TextButton.icon(
                      onPressed: () => _toggleCandidateAction(candidate),
                      icon: Icon(
                        isSkipped ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        size: 18,
                      ),
                      label: Text(isSkipped ? '导入' : '跳过'),
                      style: TextButton.styleFrom(
                        foregroundColor: isSkipped ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final importCount = _summary?.toImportCount ?? 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Summary
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '将导入 $importCount 条记录',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (_summary != null)
                  Text(
                    '支出 ¥${_summary!.totalExpense.toStringAsFixed(0)}  收入 ¥${_summary!.totalIncome.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // Import button
          ElevatedButton(
            onPressed: importCount > 0 && !_isImporting ? _executeImport : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('确认导入'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'smart':
        widget.importService.applySmartActions();
        break;
      case 'import_all':
        widget.importService.importAll();
        break;
      case 'skip_duplicates':
        widget.importService.skipAllDuplicates();
        break;
    }
    _updateSummary();
  }

  void _toggleCandidateAction(ImportCandidate candidate) {
    final newAction = candidate.action == ImportAction.import_
        ? ImportAction.skip
        : ImportAction.import_;
    widget.importService.updateCandidateAction(candidate.index, newAction);
    _updateSummary();
  }

  void _showCandidateDetail(ImportCandidate candidate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CandidateDetailSheet(
        candidate: candidate,
        onActionChanged: (action) {
          widget.importService.updateCandidateAction(candidate.index, action);
          _updateSummary();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _executeImport() async {
    setState(() => _isImporting = true);

    try {
      final result = await widget.importService.executeImport(
        onProgress: (stage, current, total, message) {
          // Could show progress dialog here
        },
      );

      if (mounted) {
        if (result.isSuccess) {
          // Refresh transaction list
          ref.invalidate(transactionProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功导入 ${result.successCount} 条记录'),
              backgroundColor: AppColors.income,
            ),
          );

          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errors.isNotEmpty
                    ? result.errors.first
                    : '导入失败',
              ),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
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

  Color _getDuplicateLevelColor(DuplicateLevel level) {
    switch (level) {
      case DuplicateLevel.exact:
        return Colors.red;
      case DuplicateLevel.high:
        return Colors.orange;
      case DuplicateLevel.medium:
        return Colors.amber;
      case DuplicateLevel.low:
        return Colors.grey;
      case DuplicateLevel.none:
        return Colors.grey;
    }
  }

  String _getDuplicateLevelName(DuplicateLevel level) {
    switch (level) {
      case DuplicateLevel.exact:
        return '完全重复';
      case DuplicateLevel.high:
        return '高度相似';
      case DuplicateLevel.medium:
        return '可能重复';
      case DuplicateLevel.low:
        return '轻微相似';
      case DuplicateLevel.none:
        return '无重复';
    }
  }
}

/// Detail sheet for a candidate
class _CandidateDetailSheet extends StatelessWidget {
  final ImportCandidate candidate;
  final ValueChanged<ImportAction> onActionChanged;

  const _CandidateDetailSheet({
    required this.candidate,
    required this.onActionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          const Text(
            '交易详情',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Details
          _buildDetailRow('日期', DateFormat('yyyy-MM-dd HH:mm').format(candidate.date)),
          _buildDetailRow('金额', '¥${candidate.amount.toStringAsFixed(2)}'),
          _buildDetailRow('类型', _getTypeName(candidate.type)),
          if (candidate.note != null)
            _buildDetailRow('备注', candidate.note!),
          if (candidate.rawMerchant != null)
            _buildDetailRow('商户', candidate.rawMerchant!),
          if (candidate.category != null)
            _buildDetailRow('分类', candidate.category!),
          if (candidate.externalId != null)
            _buildDetailRow('交易号', candidate.externalId!),
          // Duplicate info
          if (candidate.duplicateResult != null &&
              candidate.duplicateResult!.level != DuplicateLevel.none) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              '重复检测',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDuplicateInfo(candidate.duplicateResult!),
          ],
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onActionChanged(ImportAction.skip),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('跳过'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onActionChanged(ImportAction.import_),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('导入'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateInfo(DuplicateCheckResult result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                '相似度: ${result.score}分',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.reason,
            style: const TextStyle(fontSize: 13),
          ),
          if (result.matchedTransaction != null) ...[
            const SizedBox(height: 8),
            Text(
              '匹配交易: ${result.matchedTransaction!.note ?? ''} (${DateFormat('MM-dd').format(result.matchedTransaction!.date)})',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTypeName(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
    }
  }
}
