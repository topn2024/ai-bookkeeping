import 'package:flutter/material.dart';

import '../../models/email_account.dart';
import '../../models/import_candidate.dart';
import '../../services/import/email/email_bill_dispatcher.dart';
import '../../services/import/import_exceptions.dart';
import '../../services/import/batch_import_service.dart';
import '../../services/import/bill_parser.dart';
import '../../services/import/bill_format_detector.dart';
import '../../theme/app_theme.dart';
import 'import_preview_page.dart';

/// 邮箱导入进度页面
/// 参照 SmsImportProgressPage 的结构，显示5个阶段的进度
class EmailImportProgressPage extends StatefulWidget {
  final EmailAccount account;
  final DateTime startDate;
  final DateTime endDate;
  final List<String>? senderFilter;
  final String? zipPassword;

  const EmailImportProgressPage({
    super.key,
    required this.account,
    required this.startDate,
    required this.endDate,
    this.senderFilter,
    this.zipPassword,
  });

  @override
  State<EmailImportProgressPage> createState() => _EmailImportProgressPageState();
}

class _EmailImportProgressPageState extends State<EmailImportProgressPage> {
  final EmailBillDispatcher _dispatcher = EmailBillDispatcher();
  final BatchImportService _batchImportService = BatchImportService();

  String _currentStage = 'connecting';
  String _statusMessage = '正在连接邮箱服务器...';
  int _progressCurrent = 0;
  int _progressTotal = 0;
  bool _isCompleted = false;
  bool _hasError = false;
  String? _errorMessage;
  List<ImportCandidate>? _candidates;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isCompleted || _hasError,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认退出'),
            content: const Text('导入正在进行中，确定要退出吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续导入'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('退出'),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('邮箱导入'),
          automaticallyImplyLeading: _isCompleted || _hasError,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressCard(),
              const SizedBox(height: 20),
              _buildStageIndicators(),
              const Spacer(),
              if (_isCompleted && _candidates != null && _candidates!.isNotEmpty)
                _buildContinueButton(),
              if (_isCompleted && (_candidates == null || _candidates!.isEmpty))
                _buildNoResultButton(),
              if (_hasError) _buildRetryButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          if (!_isCompleted && !_hasError) ...[
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
              ),
            ),
            const SizedBox(height: 20),
          ] else if (_isCompleted) ...[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 40, color: AppColors.income),
            ),
            const SizedBox(height: 20),
          ] else if (_hasError) ...[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error, size: 40, color: AppColors.expense),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            _statusMessage,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          if (_progressTotal > 0 && !_isCompleted && !_hasError) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progressCurrent / _progressTotal,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
            ),
            const SizedBox(height: 8),
            Text(
              '$_progressCurrent / $_progressTotal',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
          if (_hasError && _errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.expense, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageIndicators() {
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
            '处理阶段',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStageItem(icon: Icons.wifi, label: '连接服务器', stage: 'connecting'),
          _buildStageItem(icon: Icons.search, label: '搜索邮件', stage: 'searching'),
          _buildStageItem(icon: Icons.download, label: '下载邮件', stage: 'fetching'),
          _buildStageItem(icon: Icons.auto_awesome, label: '解析账单', stage: 'parsing'),
          _buildStageItem(icon: Icons.check_circle_outline, label: '检查重复', stage: 'checking'),
        ],
      ),
    );
  }

  Widget _buildStageItem({
    required IconData icon,
    required String label,
    required String stage,
  }) {
    final isActive = _currentStage == stage;
    final isPassed = _getStageIndex(_currentStage) > _getStageIndex(stage);
    final isCompleted = _isCompleted && isPassed;

    Color color;
    if (isCompleted || isPassed) {
      color = AppColors.income;
    } else if (isActive) {
      color = const Color(0xFF7C4DFF);
    } else {
      color = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted || isPassed ? Icons.check : icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isActive && !_isCompleted && !_hasError) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _getStageIndex(String stage) {
    switch (stage) {
      case 'connecting': return 0;
      case 'searching': return 1;
      case 'fetching': return 2;
      case 'parsing': return 3;
      case 'checking': return 4;
      default: return -1;
    }
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _goToPreview,
        icon: const Icon(Icons.preview),
        label: Text('预览并确认导入 (${_candidates!.length}条)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNoResultButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        label: const Text('返回重新配置'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _hasError = false;
            _errorMessage = null;
            _isCompleted = false;
            _currentStage = 'connecting';
            _statusMessage = '正在连接邮箱服务器...';
            _progressCurrent = 0;
            _progressTotal = 0;
          });
          _startImport();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('重试'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _startImport() async {
    try {
      final result = await _dispatcher.importFromEmail(
        account: widget.account,
        startDate: widget.startDate,
        endDate: widget.endDate,
        senderFilter: widget.senderFilter,
        zipPassword: widget.zipPassword,
        onProgress: (stage, current, total, message) {
          if (mounted) {
            setState(() {
              _currentStage = stage;
              _progressCurrent = current;
              _progressTotal = total;
              _statusMessage = message ?? _getStageMessage(stage, current, total);
            });
          }
        },
      );

      if (mounted) {
        if (result.candidates.isEmpty) {
          setState(() {
            _isCompleted = true;
            _candidates = [];
            _statusMessage = '未找到可导入的账单记录\n共搜索 ${result.totalEmailsFound} 封邮件';
          });
        } else {
          setState(() {
            _isCompleted = true;
            _candidates = result.candidates;
            _statusMessage = '导入准备完成！\n共找到 ${result.candidates.length} 条交易记录';
          });
        }
      }
    } on EmailAuthException catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '认证失败: ${e.message}';
        });
      }
    } on EmailConnectionException catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '连接失败: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '导入失败: $e';
        });
      }
    }
  }

  String _getStageMessage(String stage, int current, int total) {
    switch (stage) {
      case 'connecting': return '正在连接邮箱服务器...';
      case 'searching': return '正在搜索账单邮件...';
      case 'fetching': return '正在下载邮件... ($current/$total)';
      case 'parsing': return '正在解析账单... ($current/$total)';
      case 'checking': return '正在检查重复... ($current/$total)';
      default: return '处理中...';
    }
  }

  void _goToPreview() {
    if (_candidates == null || _candidates!.isEmpty) return;

    _batchImportService.setCandidates(_candidates!, fileName: '邮箱账单导入');

    final dummyFormatResult = BillFormatResult(
      format: BillFileFormat.unknown,
      sourceType: BillSourceType.email,
      estimatedRecordCount: _candidates!.length,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportPreviewPage(
          importService: _batchImportService,
          formatResult: dummyFormatResult,
          parseResult: BillParseResult(
            candidates: _candidates!,
            successCount: _candidates!.length,
            failedCount: 0,
          ),
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }
}
