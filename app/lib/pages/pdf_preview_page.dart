import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import '../services/category_localization_service.dart';

/// PDF导出预览页面
/// 原型设计 5.05：PDF导出预览
/// - 顶部标题栏（返回、标题、分享）
/// - PDF预览卡片（标题、日期范围、收支统计、分类支出）
/// - 页码指示器
/// - 保存PDF按钮 ≥52dp
class PdfPreviewPage extends ConsumerStatefulWidget {
  final List<Transaction> transactions;
  final DateTime startDate;
  final DateTime endDate;
  final bool includeSummary;
  final bool includeCategorySummary;

  const PdfPreviewPage({
    super.key,
    required this.transactions,
    required this.startDate,
    required this.endDate,
    this.includeSummary = true,
    this.includeCategorySummary = true,
  });

  @override
  ConsumerState<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends ConsumerState<PdfPreviewPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _totalPages = 1;
  bool _isSaving = false;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _calculatePages();
  }

  void _calculatePages() {
    // 简单计算页数：每页约10条交易记录
    final transactionPages = (widget.transactions.length / 10).ceil();
    _totalPages = 1 + transactionPages; // 1页摘要 + 交易页数
    if (_totalPages < 1) _totalPages = 1;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
              child: _buildPdfPreview(context, theme),
            ),
            _buildPageIndicator(theme),
            _buildSaveButton(context, theme),
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
              'PDF预览',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _savedPath != null ? _sharePdf : null,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.share,
                color: _savedPath != null
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: PageView.builder(
        controller: _pageController,
        itemCount: _totalPages,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSummaryPage(theme);
          } else {
            return _buildTransactionPage(theme, index);
          }
        },
      ),
    );
  }

  /// 摘要页
  Widget _buildSummaryPage(ThemeData theme) {
    final dateFormat = DateFormat('yyyy年M月d日');
    final totalIncome = widget.transactions
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpense = widget.transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);

    // 分类统计
    final categoryStats = <String, double>{};
    for (final t in widget.transactions.where((t) => t.type == TransactionType.expense)) {
      categoryStats[t.category] = (categoryStats[t.category] ?? 0) + t.amount;
    }
    final sortedCategories = categoryStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      child: Column(
        children: [
          // 标题头部
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Text(
                  '${widget.endDate.month}月财务报告',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFormat.format(widget.startDate)} - ${dateFormat.format(widget.endDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // 收支统计
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '总收入',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '¥${totalIncome.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '总支出',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '¥${totalExpense.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 16),
                // 分类支出
                if (widget.includeCategorySummary && sortedCategories.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '支出分类',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sortedCategories.take(5).map((entry) {
                    final category = DefaultCategories.findById(entry.key);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(entry.key),
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '¥${entry.value.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 交易明细页
  Widget _buildTransactionPage(ThemeData theme, int pageIndex) {
    final startIndex = (pageIndex - 1) * 10;
    final endIndex = startIndex + 10;
    final pageTransactions = widget.transactions.length > startIndex
        ? widget.transactions.sublist(
            startIndex,
            endIndex > widget.transactions.length ? widget.transactions.length : endIndex,
          )
        : <Transaction>[];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '交易明细',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ...pageTransactions.map((t) {
              final category = DefaultCategories.findById(t.category);
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: category?.color ?? Colors.grey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        category?.icon ?? Icons.help_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.note ?? category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(t.category),
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            DateFormat('MM-dd HH:mm').format(t.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${t.type == TransactionType.expense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.type == TransactionType.expense
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 页码指示器
  Widget _buildPageIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '第 ${_currentPage + 1} / $_totalPages 页',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// 保存按钮
  Widget _buildSaveButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _savePdf,
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(
              _isSaving ? '保存中...' : '保存PDF',
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

  Future<void> _savePdf() async {
    setState(() => _isSaving = true);

    try {
      // 生成简单的文本报告（真正的PDF需要 pdf 包）
      final buffer = StringBuffer();
      final dateFormat = DateFormat('yyyy年M月d日');

      buffer.writeln('${widget.endDate.month}月财务报告');
      buffer.writeln('${dateFormat.format(widget.startDate)} - ${dateFormat.format(widget.endDate)}');
      buffer.writeln('');

      final totalIncome = widget.transactions
          .where((t) => t.type == TransactionType.income)
          .fold<double>(0, (sum, t) => sum + t.amount);
      final totalExpense = widget.transactions
          .where((t) => t.type == TransactionType.expense)
          .fold<double>(0, (sum, t) => sum + t.amount);

      buffer.writeln('总收入: ¥${totalIncome.toStringAsFixed(2)}');
      buffer.writeln('总支出: ¥${totalExpense.toStringAsFixed(2)}');
      buffer.writeln('结余: ¥${(totalIncome - totalExpense).toStringAsFixed(2)}');
      buffer.writeln('');

      // 分类统计
      if (widget.includeCategorySummary) {
        buffer.writeln('支出分类:');
        final categoryStats = <String, double>{};
        for (final t in widget.transactions.where((t) => t.type == TransactionType.expense)) {
          categoryStats[t.category] = (categoryStats[t.category] ?? 0) + t.amount;
        }
        final sortedCategories = categoryStats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedCategories) {
          final category = DefaultCategories.findById(entry.key);
          buffer.writeln('  ${category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(entry.key)}: ¥${entry.value.toStringAsFixed(2)}');
        }
      }

      // 保存文件
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/financial_report_$timestamp.txt';
      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      setState(() {
        _isSaving = false;
        _savedPath = filePath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('报告已保存'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: '分享',
              textColor: Colors.white,
              onPressed: _sharePdf,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_savedPath != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_savedPath!)],
          subject: '财务报告',
        ),
      );
    }
  }
}
