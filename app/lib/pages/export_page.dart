import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/export_service.dart';
import 'pdf_preview_page.dart';

/// 导出账单页面
/// 原型设计 5.04：导出账单
/// - 时间范围 Chip 选择（本月、上月、近3月、自定义）
/// - 交易类型 Chip 选择（全部、支出、收入、转账）
/// - 导出格式 Chip 选择（CSV、Excel、PDF）
/// - 包含内容开关（统计摘要、分类汇总、趋势图表）
/// - 预览卡片（交易数量、文件大小）
/// - 导出按钮 ≥52dp
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  final _exportService = ExportService();

  // 时间范围选项
  int _selectedTimeRange = 0; // 0=本月, 1=上月, 2=近3月, 3=自定义
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();

  // 交易类型
  TransactionType? _typeFilter;

  // 导出格式
  ExportFormat _format = ExportFormat.csv;

  // 包含内容
  bool _includeSummary = true;
  bool _includeCategorySummary = true;
  bool _includeTrendChart = false;

  bool _isExporting = false;
  String? _lastExportPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = ref.watch(transactionProvider);
    final filteredTransactions = _getFilteredTransactions(transactions);

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
                    _buildTimeRangeSection(context, theme),
                    _buildTransactionTypeSection(context, theme),
                    _buildExportFormatSection(context, theme),
                    _buildIncludeOptionsSection(context, theme),
                    _buildPreviewCard(context, theme, filteredTransactions.length),
                  ],
                ),
              ),
            ),
            _buildExportButton(context, theme),
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
              '导出账单',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// 时间范围选择
  Widget _buildTimeRangeSection(BuildContext context, ThemeData theme) {
    final timeRangeOptions = ['本月', '上月', '近3月', '自定义'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '时间范围',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(timeRangeOptions.length, (index) {
              final isSelected = _selectedTimeRange == index;
              return GestureDetector(
                onTap: () {
                  if (index == 3) {
                    _showCustomDatePicker(context);
                  }
                  setState(() => _selectedTimeRange = index);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeRangeOptions[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_selectedTimeRange == 3) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectCustomDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy-MM-dd').format(_customStartDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectCustomDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy-MM-dd').format(_customEndDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 交易类型选择
  Widget _buildTransactionTypeSection(BuildContext context, ThemeData theme) {
    final typeOptions = [
      (null, '全部'),
      (TransactionType.expense, context.l10n.expense),
      (TransactionType.income, context.l10n.income),
      (TransactionType.transfer, context.l10n.transfer),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '交易类型',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: typeOptions.map((option) {
              final isSelected = _typeFilter == option.$1;
              return GestureDetector(
                onTap: () => setState(() => _typeFilter = option.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 导出格式选择
  Widget _buildExportFormatSection(BuildContext context, ThemeData theme) {
    final formatOptions = [
      (ExportFormat.csv, 'CSV'),
      (ExportFormat.excel, 'Excel'),
      (ExportFormat.pdf, 'PDF'),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导出格式',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: formatOptions.map((option) {
              final isSelected = _format == option.$1;
              return GestureDetector(
                onTap: () => setState(() => _format = option.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 包含内容开关
  Widget _buildIncludeOptionsSection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '包含内容',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _buildSwitchItem(
            context,
            theme,
            title: '统计摘要',
            value: _includeSummary,
            onChanged: (v) => setState(() => _includeSummary = v),
          ),
          const SizedBox(height: 8),
          _buildSwitchItem(
            context,
            theme,
            title: '分类汇总',
            value: _includeCategorySummary,
            onChanged: (v) => setState(() => _includeCategorySummary = v),
          ),
          const SizedBox(height: 8),
          _buildSwitchItem(
            context,
            theme,
            title: '趋势图表',
            value: _includeTrendChart,
            onChanged: (v) => setState(() => _includeTrendChart = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 预览卡片
  Widget _buildPreviewCard(BuildContext context, ThemeData theme, int transactionCount) {
    // 估算文件大小（假设每条记录约0.5KB）
    final estimatedSize = (transactionCount * 0.5).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '预计导出',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$transactionCount 笔交易',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '文件大小',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '约 $estimatedSize KB',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 导出按钮
  Widget _buildExportButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : _export,
            icon: _isExporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.file_download),
            label: Text(
              _isExporting ? '导出中...' : '导出文件',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 获取日期范围
  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case 0: // 本月
        return (DateTime(now.year, now.month, 1), now);
      case 1: // 上月
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0);
        return (lastMonth, lastDay);
      case 2: // 近3月
        return (DateTime(now.year, now.month - 2, 1), now);
      case 3: // 自定义
        return (_customStartDate, _customEndDate);
      default:
        return (DateTime(now.year, now.month, 1), now);
    }
  }

  /// 获取筛选后的交易
  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    final (startDate, endDate) = _getDateRange();
    return transactions.where((t) {
      // 日期筛选
      if (t.date.isBefore(startDate) || t.date.isAfter(endDate.add(const Duration(days: 1)))) {
        return false;
      }
      // 类型筛选
      if (_typeFilter != null && t.type != _typeFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showCustomDatePicker(BuildContext context) async {
    await _selectCustomDate(context, true);
  }

  Future<void> _selectCustomDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _customStartDate : _customEndDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _customStartDate = date;
          if (_customStartDate.isAfter(_customEndDate)) {
            _customEndDate = _customStartDate;
          }
        } else {
          _customEndDate = date;
          if (_customEndDate.isBefore(_customStartDate)) {
            _customStartDate = _customEndDate;
          }
        }
      });
    }
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);

    final transactions = ref.read(transactionProvider);
    final filteredTransactions = _getFilteredTransactions(transactions);
    final (startDate, endDate) = _getDateRange();

    final options = ExportOptions(
      startDate: startDate,
      endDate: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
      typeFilter: _typeFilter,
      format: _format,
      includeSummary: _includeSummary,
      includeCategorySummary: _includeCategorySummary,
      includeTrendChart: _includeTrendChart,
    );

    try {
      // PDF 格式跳转预览页面
      if (_format == ExportFormat.pdf) {
        setState(() => _isExporting = false);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfPreviewPage(
                transactions: filteredTransactions,
                startDate: startDate,
                endDate: endDate,
                includeSummary: _includeSummary,
                includeCategorySummary: _includeCategorySummary,
              ),
            ),
          );
        }
        return;
      }

      final result = await _exportService.exportTransactions(filteredTransactions, options);

      setState(() {
        _isExporting = false;
        if (result.success) {
          _lastExportPath = result.filePath;
        }
      });

      if (mounted) {
        if (result.success) {
          _showExportSuccessDialog(context, result);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('导出失败: ${result.error}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showExportSuccessDialog(BuildContext context, ExportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, size: 48, color: AppColors.success),
        title: const Text('导出成功'),
        content: Text('已导出 ${result.recordCount} 条交易记录'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareExport();
            },
            icon: const Icon(Icons.share),
            label: const Text('分享'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareExport() async {
    if (_lastExportPath != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_lastExportPath!)],
          subject: '账单导出',
        ),
      );
    }
  }
}
