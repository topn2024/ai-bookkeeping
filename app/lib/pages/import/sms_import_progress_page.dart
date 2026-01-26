import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/import/sms_import_service.dart';
import '../../services/import/import_exceptions.dart';
import '../../models/import_candidate.dart';
import 'import_preview_page.dart';
import '../../services/import/batch_import_service.dart';
import '../../services/import/bill_parser.dart';
import '../../services/import/bill_format_detector.dart';

/// 短信导入进度页面
/// 显示读取、解析、检查重复的进度
class SmsImportProgressPage extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final bool useSenderFilter;

  const SmsImportProgressPage({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.useSenderFilter,
  });

  @override
  State<SmsImportProgressPage> createState() => _SmsImportProgressPageState();
}

class _SmsImportProgressPageState extends State<SmsImportProgressPage> {
  final SmsImportService _smsImportService = SmsImportService();
  final BatchImportService _batchImportService = BatchImportService();

  String _currentStage = 'reading';
  String _statusMessage = '正在读取短信...';
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
    return WillPopScope(
      onWillPop: () async {
        if (_isCompleted || _hasError) {
          return true;
        }
        // 正在处理时，询问是否确认退出
        if (!context.mounted) return false;
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
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('短信导入'),
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
              if (_isCompleted && _candidates != null) _buildContinueButton(),
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
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
              child: Icon(
                Icons.check_circle,
                size: 40,
                color: AppColors.income,
              ),
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
              child: Icon(
                Icons.error,
                size: 40,
                color: AppColors.expense,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            _statusMessage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_progressTotal > 0 && !_isCompleted && !_hasError) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progressCurrent / _progressTotal,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              '$_progressCurrent / $_progressTotal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          if (_hasError && _errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: AppColors.expense,
                fontSize: 14,
              ),
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStageItem(
            icon: Icons.sms,
            label: '读取短信',
            stage: 'reading',
          ),
          _buildStageItem(
            icon: Icons.auto_awesome,
            label: 'AI解析',
            stage: 'parsing',
          ),
          _buildStageItem(
            icon: Icons.check_circle_outline,
            label: '检查重复',
            stage: 'checking',
          ),
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
      color = Colors.orange;
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
      case 'reading':
        return 0;
      case 'parsing':
        return 1;
      case 'checking':
        return 2;
      default:
        return -1;
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
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
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
            _currentStage = 'reading';
            _statusMessage = '正在读取短信...';
            _progressCurrent = 0;
            _progressTotal = 0;
          });
          _startImport();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('重试'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _startImport() async {
    try {
      // 检查权限
      final hasPermission = await _smsImportService.checkPermission();
      if (!hasPermission) {
        final granted = await _smsImportService.requestPermission();
        if (!granted) {
          setState(() {
            _hasError = true;
            _errorMessage = '需要短信读取权限才能导入交易记录';
          });

          // 显示权限说明对话框
          if (mounted) {
            _showPermissionDeniedDialog();
          }
          return;
        }
      }

      // 执行导入
      final candidates = await _smsImportService.importSms(
        startDate: widget.startDate,
        endDate: widget.endDate,
        useSenderFilter: widget.useSenderFilter,
        onProgress: (stage, current, total) {
          if (mounted) {
            setState(() {
              _currentStage = stage;
              _progressCurrent = current;
              _progressTotal = total;
              _statusMessage = _getStageMessage(stage, current, total);
            });
          }
        },
      );

      if (mounted) {
        if (candidates.isEmpty) {
          setState(() {
            _hasError = true;
            _errorMessage = '未找到可导入的交易记录';
          });

          // 显示无交易短信的提示
          _showNoTransactionsDialog();
        } else {
          setState(() {
            _isCompleted = true;
            _candidates = candidates;
            _statusMessage = '导入准备完成！共找到 ${candidates.length} 条交易记录';
          });
        }
      }
    } on PermissionException catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '权限错误: ${e.message}';
        });
        _showPermissionDeniedDialog();
      }
    } on NetworkException catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '网络错误: ${e.message}';
        });
        _showNetworkErrorDialog();
      }
    } on AIParseException catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'AI解析失败: ${e.message}';
        });
        _showAIParseErrorDialog(e);
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
      case 'reading':
        return '正在读取短信... ($current/$total)';
      case 'parsing':
        return '正在AI解析... ($current/$total)';
      case 'checking':
        return '正在检查重复... ($current/$total)';
      default:
        return '处理中...';
    }
  }

  void _goToPreview() {
    if (_candidates == null || _candidates!.isEmpty) return;

    // 将candidates设置到BatchImportService中
    _batchImportService.setCandidates(_candidates!, fileName: '短信导入');

    // 创建一个虚拟的格式检测结果（短信导入使用sms类型）
    final dummyFormatResult = BillFormatResult(
      format: BillFileFormat.unknown,
      sourceType: BillSourceType.sms,
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
        // 导入成功，返回到智能导入页面
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('需要短信读取权限'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('短信导入功能需要读取您的短信内容以识别交易记录。'),
            SizedBox(height: 12),
            Text(
              '我们承诺：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 短信内容仅在本地处理'),
            Text('• 不会永久存储短信内容'),
            Text('• 仅用于识别交易记录'),
            SizedBox(height: 12),
            Text(
              '您可以在系统设置中手动授予权限：',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              '设置 → 应用 → AI记账 → 权限 → 短信',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 重新尝试申请权限
              setState(() {
                _hasError = false;
                _errorMessage = null;
              });
              _startImport();
            },
            child: const Text('重新授权'),
          ),
        ],
      ),
    );
  }

  void _showNoTransactionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('未找到交易记录'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('在选定的时间范围内未找到可识别的交易短信。'),
            const SizedBox(height: 12),
            const Text(
              '可能的原因：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• 该时间段内没有支付相关短信'),
            const Text('• 短信已被删除'),
            const Text('• 短信格式无法识别'),
            const SizedBox(height: 12),
            const Text(
              '建议：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• 尝试扩大时间范围'),
            const Text('• 关闭"仅读取支付相关短信"过滤'),
            const Text('• 使用文件导入功能'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // 返回配置页面
            },
            child: const Text('返回重新配置'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context); // 返回智能导入页面
            },
            child: const Text('使用文件导入'),
          ),
        ],
      ),
    );
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('网络连接失败'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('短信解析需要连接到AI服务，但网络连接失败。'),
            SizedBox(height: 12),
            Text(
              '请检查：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 网络连接是否正常'),
            Text('• 是否开启了飞行模式'),
            Text('• 是否限制了应用的网络权限'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 重试
              setState(() {
                _hasError = false;
                _errorMessage = null;
                _currentStage = 'reading';
                _statusMessage = '正在读取短信...';
              });
              _startImport();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _showAIParseErrorDialog(AIParseException e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('AI解析失败'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI服务在解析短信时遇到问题：${e.message}'),
            const SizedBox(height: 12),
            if (e.parsedCount > 0) ...[
              Text(
                '已成功解析 ${e.parsedCount} 条短信，但有 ${e.failedCount} 条解析失败。',
                style: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 12),
              const Text('您可以：'),
              const SizedBox(height: 8),
              const Text('• 继续导入已解析的记录'),
              const Text('• 重试以尝试解析失败的短信'),
            ] else ...[
              const Text(
                '所有短信都解析失败。',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              const Text('建议：'),
              const SizedBox(height: 8),
              const Text('• 检查网络连接'),
              const Text('• 稍后重试'),
              const Text('• 使用文件导入功能'),
            ],
          ],
        ),
        actions: [
          if (e.parsedCount > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 使用部分解析的结果
                if (e.partialCandidates != null && e.partialCandidates!.isNotEmpty) {
                  setState(() {
                    _isCompleted = true;
                    _candidates = e.partialCandidates;
                    _hasError = false;
                    _statusMessage = '部分导入完成！共找到 ${e.partialCandidates!.length} 条交易记录';
                  });
                }
              },
              child: const Text('继续导入'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 重试
              setState(() {
                _hasError = false;
                _errorMessage = null;
                _currentStage = 'reading';
                _statusMessage = '正在读取短信...';
              });
              _startImport();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
