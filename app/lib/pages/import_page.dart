import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/import_service.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final _importService = ImportService();

  String? _selectedFilePath;
  String? _selectedFileName;
  List<ImportPreviewItem> _previewItems = [];
  bool _isLoading = false;
  bool _isImporting = false;
  ImportResult? _importResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据导入'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildFileSelector(),
            if (_previewItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildPreviewSection(),
            ],
            if (_importResult != null) ...[
              const SizedBox(height: 20),
              _buildResultSection(),
            ],
            const SizedBox(height: 20),
            _buildFormatHelpSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
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
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.upload_file,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '数据导入',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '支持CSV格式，可从其他记账应用导入',
                  style: TextStyle(
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

  Widget _buildFileSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择文件',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _isLoading ? null : _selectFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedFilePath != null
                    ? AppColors.primary
                    : AppColors.border,
                width: _selectedFilePath != null ? 2 : 1,
                style: BorderStyle.solid,
              ),
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Column(
                    children: [
                      Icon(
                        _selectedFilePath != null
                            ? Icons.check_circle
                            : Icons.cloud_upload_outlined,
                        size: 48,
                        color: _selectedFilePath != null
                            ? AppColors.income
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFileName ?? '点击选择CSV文件',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedFilePath != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: _selectedFilePath != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (_selectedFilePath != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${_previewItems.length} 条记录待导入',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    final validCount = _previewItems.where((p) => p.isValid).length;
    final invalidCount = _previewItems.where((p) => !p.isValid).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '数据预览',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                _buildCountBadge('有效', validCount, AppColors.income),
                const SizedBox(width: 8),
                if (invalidCount > 0)
                  _buildCountBadge('错误', invalidCount, AppColors.expense),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 表头
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 30, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('日期', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(child: Text('类型', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(child: Text('金额', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(width: 30),
                  ],
                ),
              ),
              // 数据行（只显示前10条）
              ...(_previewItems.take(10).map((item) => _buildPreviewRow(item))),
              if (_previewItems.length > 10)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '还有 ${_previewItems.length - 10} 条记录...',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: validCount > 0 && !_isImporting ? _importData : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isImporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload),
                      const SizedBox(width: 8),
                      Text('导入 $validCount 条记录', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPreviewRow(ImportPreviewItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
        color: item.isValid ? null : Colors.red.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${item.rowNumber}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.date != null
                  ? DateFormat('MM-dd HH:mm').format(item.date!)
                  : '-',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              _getTypeName(item.type),
              style: TextStyle(
                fontSize: 13,
                color: _getTypeColor(item.type),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.amount != null ? '¥${item.amount!.toStringAsFixed(0)}' : '-',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _getTypeColor(item.type),
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: item.isValid
                ? const Icon(Icons.check_circle, color: AppColors.income, size: 18)
                : Tooltip(
                    message: item.error ?? '错误',
                    child: const Icon(Icons.error, color: AppColors.expense, size: 18),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final result = _importResult!;
    final isSuccess = result.success && result.successCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess
            ? AppColors.income.withValues(alpha: 0.1)
            : AppColors.expense.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess
              ? AppColors.income.withValues(alpha: 0.3)
              : AppColors.expense.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? AppColors.income : AppColors.expense,
              ),
              const SizedBox(width: 12),
              Text(
                isSuccess ? '导入成功' : '导入失败',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSuccess ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isSuccess) ...[
            Text('成功导入 ${result.successCount} 条记录'),
            if (result.failedCount > 0)
              Text(
                '${result.failedCount} 条记录导入失败',
                style: const TextStyle(color: AppColors.expense),
              ),
          ] else ...[
            Text(
              result.error ?? '未知错误',
              style: const TextStyle(color: AppColors.expense),
            ),
          ],
          if (result.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('查看错误详情'),
              tilePadding: EdgeInsets.zero,
              children: result.errors.take(5).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatHelpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'CSV格式说明',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '文件格式要求：',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _buildFormatItem('表头：日期,类型,分类,金额,账户,备注'),
          _buildFormatItem('日期格式：yyyy-MM-dd 或 yyyy-MM-dd HH:mm:ss'),
          _buildFormatItem('类型：支出 / 收入 / 转账'),
          _buildFormatItem('金额：数字，支出可为负数'),
          const SizedBox(height: 12),
          const Text(
            '示例：',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '2025-12-28,支出,餐饮,-50,现金,午餐',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeName(TransactionType? type) {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
      case null:
        return '-';
    }
  }

  Color _getTypeColor(TransactionType? type) {
    switch (type) {
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.transfer:
        return AppColors.transfer;
      case null:
        return AppColors.textSecondary;
    }
  }

  Future<void> _selectFile() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _selectedFilePath = file.path;
        _selectedFileName = file.name;

        if (_selectedFilePath != null) {
          _previewItems = await _importService.previewCSV(_selectedFilePath!);
        }

        setState(() {
          _importResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importData() async {
    if (_selectedFilePath == null) return;

    setState(() => _isImporting = true);

    try {
      final result = await _importService.importTransactions(_selectedFilePath!);

      if (result.success && result.transactions.isNotEmpty) {
        // 添加到交易记录
        final transactionNotifier = ref.read(transactionProvider.notifier);
        for (final transaction in result.transactions) {
          await transactionNotifier.addTransaction(transaction);
        }
      }

      setState(() {
        _importResult = result;
        if (result.success) {
          _previewItems = [];
          _selectedFilePath = null;
          _selectedFileName = null;
        }
      });

      if (mounted && result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入 ${result.successCount} 条记录'),
            backgroundColor: AppColors.income,
          ),
        );
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
      setState(() => _isImporting = false);
    }
  }
}
