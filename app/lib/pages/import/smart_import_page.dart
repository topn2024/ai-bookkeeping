import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/import/batch_import_service.dart';
import '../../services/import/bill_format_detector.dart';
import '../../services/import/bill_parser.dart';
import 'import_preview_page.dart';
import 'import_history_page.dart';

/// Smart import page with format detection and deduplication
class SmartImportPage extends ConsumerStatefulWidget {
  const SmartImportPage({super.key});

  @override
  ConsumerState<SmartImportPage> createState() => _SmartImportPageState();
}

class _SmartImportPageState extends ConsumerState<SmartImportPage> {
  final BatchImportService _importService = BatchImportService();

  bool _isLoading = false;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  BillFormatResult? _formatResult;
  BillParseResult? _parseResult;
  String _statusMessage = '';
  int _progressCurrent = 0;
  int _progressTotal = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能导入'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _viewImportHistory,
            tooltip: '导入历史',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildSupportedFormats(),
            const SizedBox(height: 20),
            _buildFileSelector(),
            if (_isLoading) ...[
              const SizedBox(height: 20),
              _buildProgressSection(),
            ],
            if (_formatResult != null && !_isLoading) ...[
              const SizedBox(height: 20),
              _buildFormatResultSection(),
            ],
            if (_parseResult != null && !_isLoading) ...[
              const SizedBox(height: 20),
              _buildParseResultSection(),
            ],
            const SizedBox(height: 20),
            _buildHelpSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade800],
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
              Icons.auto_awesome,
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
                  '智能账单导入',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '自动识别微信、支付宝账单，智能去重',
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

  Widget _buildSupportedFormats() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '支持的账单来源',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSourceBadge('微信支付', Colors.green, Icons.wechat),
              const SizedBox(width: 8),
              _buildSourceBadge('支付宝', Colors.blue, Icons.account_balance_wallet),
              const SizedBox(width: 8),
              _buildSourceBadge('银行账单', Colors.orange, Icons.account_balance),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFormatBadge('CSV'),
              const SizedBox(width: 8),
              _buildFormatBadge('Excel'),
              const SizedBox(width: 8),
              _buildFormatBadge('TSV'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String name, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFileSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择账单文件',
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedFileName != null
                    ? Colors.indigo
                    : AppColors.border,
                width: _selectedFileName != null ? 2 : 1,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _selectedFileName != null
                      ? Icons.check_circle
                      : Icons.cloud_upload_outlined,
                  size: 48,
                  color: _selectedFileName != null
                      ? Colors.indigo
                      : AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedFileName ?? '点击选择账单文件',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedFileName != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: _selectedFileName != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '支持 CSV、Excel、TSV 格式',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          if (_progressTotal > 0) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progressCurrent / _progressTotal,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 4),
            Text(
              '$_progressCurrent / $_progressTotal',
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

  Widget _buildFormatResultSection() {
    final result = _formatResult!;
    final isSuccess = result.isSuccess;

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? AppColors.income : AppColors.expense,
              ),
              const SizedBox(width: 8),
              Text(
                isSuccess ? '格式识别成功' : '格式识别失败',
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
            _buildInfoRow('文件格式', result.formatName),
            _buildInfoRow('账单来源', result.sourceTypeName),
            if (result.recordCount != null)
              _buildInfoRow('记录数量', '${result.recordCount} 条'),
            if (result.headers != null && result.headers!.isNotEmpty)
              _buildInfoRow('识别到的列', result.headers!.take(5).join(', ')),
          ] else ...[
            Text(
              result.errorMessage ?? '无法识别文件格式',
              style: TextStyle(color: AppColors.expense),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParseResultSection() {
    final result = _parseResult!;
    final hasData = result.candidates.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasData ? Icons.list_alt : Icons.warning,
                color: hasData ? Colors.indigo : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                hasData ? '解析完成' : '无可导入数据',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: hasData ? Colors.indigo : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasData) ...[
            // Summary stats
            _buildStatsRow(result),
            const SizedBox(height: 16),
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goToPreview,
                icon: const Icon(Icons.preview),
                label: const Text('预览并确认导入'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else ...[
            Text(
              result.errors.isNotEmpty
                  ? result.errors.first
                  : '文件中没有可识别的交易记录',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (result.errors.isNotEmpty && hasData) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: Text(
                '${result.errors.length} 个解析警告',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                ),
              ),
              tilePadding: EdgeInsets.zero,
              children: result.errors.take(5).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
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

  Widget _buildStatsRow(BillParseResult result) {
    final summary = _importService.getSummary();
    if (summary == null) {
      return Text('共 ${result.candidates.length} 条交易记录');
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            '总计',
            '${summary.totalCount}',
            Colors.indigo,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            '待导入',
            '${summary.toImportCount}',
            AppColors.income,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            '疑似重复',
            '${summary.duplicateCount}',
            Colors.orange,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            '跳过',
            '${summary.toSkipCount}',
            AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
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

  Widget _buildHelpSection() {
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
              Icon(Icons.help_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                '如何导出账单?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            '微信支付',
            '微信 → 我 → 服务 → 钱包 → 账单 → 常见问题 → 下载账单',
          ),
          _buildHelpItem(
            '支付宝',
            '支付宝 → 我的 → 账单 → 右上角⋯ → 开具交易流水证明',
          ),
          _buildHelpItem(
            '银行账单',
            '登录网银/手机银行 → 账户明细 → 导出',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'tsv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.bytes != null) {
          _selectedFileBytes = file.bytes;
          _selectedFileName = file.name;
        } else if (file.path != null) {
          final fileData = await File(file.path!).readAsBytes();
          _selectedFileBytes = fileData;
          _selectedFileName = file.name;
        }

        if (_selectedFileBytes != null) {
          await _processFile();
        }
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
    }
  }

  Future<void> _processFile() async {
    if (_selectedFileBytes == null || _selectedFileName == null) return;

    setState(() {
      _isLoading = true;
      _formatResult = null;
      _parseResult = null;
      _statusMessage = '正在识别文件格式...';
      _progressCurrent = 0;
      _progressTotal = 0;
    });

    try {
      // Detect format
      _formatResult = await _importService.detectFormatFromBytes(
        _selectedFileBytes!,
        _selectedFileName!,
      );

      setState(() {});

      if (_formatResult == null || !_formatResult!.isSuccess) {
        setState(() => _isLoading = false);
        return;
      }

      // Parse file
      _parseResult = await _importService.parseBytes(
        _selectedFileBytes!,
        _selectedFileName!,
        onProgress: (stage, current, total, message) {
          setState(() {
            _progressCurrent = current;
            _progressTotal = total;
            _statusMessage = message ?? _getStageMessage(stage);
          });
        },
      );

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('处理文件失败: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getStageMessage(ImportStage stage) {
    switch (stage) {
      case ImportStage.detecting:
        return '正在识别文件格式...';
      case ImportStage.parsing:
        return '正在解析账单数据...';
      case ImportStage.categorizing:
        return '正在自动分类...';
      case ImportStage.deduplicating:
        return '正在检查重复交易...';
      case ImportStage.importing:
        return '正在导入交易...';
      case ImportStage.completed:
        return '处理完成';
    }
  }

  void _goToPreview() {
    if (_parseResult == null || _parseResult!.candidates.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportPreviewPage(
          importService: _importService,
          formatResult: _formatResult!,
          parseResult: _parseResult!,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Import was successful, clear state
        setState(() {
          _selectedFileName = null;
          _selectedFileBytes = null;
          _formatResult = null;
          _parseResult = null;
        });
        _importService.clearCache();
      }
    });
  }

  void _viewImportHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImportHistoryPage()),
    );
  }
}
