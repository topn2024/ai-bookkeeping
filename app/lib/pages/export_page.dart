import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/export_service.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  final _exportService = ExportService();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  TransactionType? _typeFilter;
  ExportFormat _format = ExportFormat.csv;
  bool _isExporting = false;
  String? _lastExportPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据导出'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildDateRangeSection(),
            const SizedBox(height: 20),
            _buildFilterSection(),
            const SizedBox(height: 20),
            _buildFormatSection(),
            const SizedBox(height: 20),
            _buildQuickExportSection(),
            const SizedBox(height: 32),
            _buildExportButton(),
            if (_lastExportPath != null) ...[
              const SizedBox(height: 16),
              _buildLastExportInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final transactions = ref.watch(transactionProvider);
    final expenseCount = transactions.where((t) => t.type == TransactionType.expense).length;
    final incomeCount = transactions.where((t) => t.type == TransactionType.income).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '数据导出',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 ${transactions.length} 条记录 (支出$expenseCount / 收入$incomeCount)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return _buildSection(
      title: '时间范围',
      child: Row(
        children: [
          Expanded(
            child: _buildDateButton(
              label: '开始日期',
              date: _startDate,
              onTap: () => _selectDate(true),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward, color: AppColors.textSecondary),
          ),
          Expanded(
            child: _buildDateButton(
              label: '结束日期',
              date: _endDate,
              onTap: () => _selectDate(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return _buildSection(
      title: '类型筛选',
      child: Wrap(
        spacing: 12,
        children: [
          _buildFilterChip(
            label: '全部',
            isSelected: _typeFilter == null,
            onTap: () => setState(() => _typeFilter = null),
          ),
          _buildFilterChip(
            label: '支出',
            isSelected: _typeFilter == TransactionType.expense,
            onTap: () => setState(() => _typeFilter = TransactionType.expense),
            color: AppColors.expense,
          ),
          _buildFilterChip(
            label: '收入',
            isSelected: _typeFilter == TransactionType.income,
            onTap: () => setState(() => _typeFilter = TransactionType.income),
            color: AppColors.income,
          ),
          _buildFilterChip(
            label: '转账',
            isSelected: _typeFilter == TransactionType.transfer,
            onTap: () => setState(() => _typeFilter = TransactionType.transfer),
            color: AppColors.transfer,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha:0.2) : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: chipColor, width: 2) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipColor : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFormatSection() {
    return _buildSection(
      title: '导出格式',
      child: Row(
        children: [
          Expanded(
            child: _buildFormatOption(
              format: ExportFormat.csv,
              title: 'CSV',
              subtitle: '通用表格格式',
              icon: Icons.table_chart,
            ),
          ),
          // 未来可以添加Excel格式
          // const SizedBox(width: 12),
          // Expanded(
          //   child: _buildFormatOption(
          //     format: ExportFormat.excel,
          //     title: 'Excel',
          //     subtitle: '需要安装Excel',
          //     icon: Icons.grid_on,
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildFormatOption({
    required ExportFormat format,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _format == format;
    return InkWell(
      onTap: () => setState(() => _format = format),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha:0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickExportSection() {
    return _buildSection(
      title: '快捷导出',
      child: Row(
        children: [
          Expanded(
            child: _buildQuickExportButton(
              label: '本月',
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _startDate = DateTime(now.year, now.month, 1);
                  _endDate = now;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickExportButton(
              label: '上月',
              onTap: () {
                final now = DateTime.now();
                final lastMonth = DateTime(now.year, now.month - 1, 1);
                final lastDay = DateTime(now.year, now.month, 0);
                setState(() {
                  _startDate = lastMonth;
                  _endDate = lastDay;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickExportButton(
              label: '今年',
              onTap: () {
                final now = DateTime.now();
                setState(() {
                  _startDate = DateTime(now.year, 1, 1);
                  _endDate = now;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickExportButton(
              label: '全部',
              onTap: () {
                setState(() {
                  _startDate = DateTime(2020, 1, 1);
                  _endDate = DateTime.now();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickExportButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isExporting ? null : _export,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isExporting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download),
                  SizedBox(width: 8),
                  Text('导出数据', style: TextStyle(fontSize: 16)),
                ],
              ),
      ),
    );
  }

  Widget _buildLastExportInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.income.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.income.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.income),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '导出成功',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.income,
                  ),
                ),
                Text(
                  _lastExportPath!.split('/').last,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _shareExport,
            icon: const Icon(Icons.share),
            label: const Text('分享'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
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
          _startDate = date;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = date;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);

    final transactions = ref.read(transactionProvider);
    final options = ExportOptions(
      startDate: _startDate,
      endDate: DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59),
      typeFilter: _typeFilter,
      format: _format,
    );

    final result = await _exportService.exportTransactions(transactions, options);

    setState(() {
      _isExporting = false;
      if (result.success) {
        _lastExportPath = result.filePath;
      }
    });

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功: ${result.recordCount} 条记录'),
            backgroundColor: AppColors.income,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: ${result.error}'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
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
