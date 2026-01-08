import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'field_mapping_page.dart';
import 'deduplication_page.dart';

/// 智能格式检测页面
/// 原型设计 5.09：智能格式检测
/// - 文件信息卡片
/// - 检测步骤列表（编码、分隔符、特征、解析器）
/// - 识别到的数据源
/// - 数据预览
/// - 下一步按钮
class SmartFormatDetectionPage extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;
  final String? selectedBank;

  const SmartFormatDetectionPage({
    super.key,
    required this.filePath,
    required this.fileName,
    this.selectedBank,
  });

  @override
  ConsumerState<SmartFormatDetectionPage> createState() => _SmartFormatDetectionPageState();
}

class _SmartFormatDetectionPageState extends ConsumerState<SmartFormatDetectionPage> {
  bool _isDetecting = true;
  String? _encoding;
  // ignore: unused_field - 用于后续扩展
  String? _delimiter;
  String? _detectedSource;
  double _confidence = 0;
  List<Map<String, String>> _previewData = [];
  bool _needsFieldMapping = false;
  String? _errorMessage;

  // 检测步骤状态
  final List<DetectionStep> _steps = [
    DetectionStep(title: '编码检测', description: '检测文件编码...', status: StepStatus.pending),
    DetectionStep(title: '分隔符检测', description: '检测数据分隔符...', status: StepStatus.pending),
    DetectionStep(title: '特征匹配', description: '分析文件特征...', status: StepStatus.pending),
    DetectionStep(title: '解析器匹配', description: '匹配最佳解析器...', status: StepStatus.pending),
  ];

  @override
  void initState() {
    super.initState();
    _startDetection();
  }

  Future<void> _startDetection() async {
    try {
      // 模拟检测过程
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 1: 编码检测
      setState(() {
        _steps[0].status = StepStatus.completed;
        _steps[0].description = 'UTF-8 编码';
        _encoding = 'UTF-8';
      });
      await Future.delayed(const Duration(milliseconds: 400));

      // Step 2: 分隔符检测
      final extension = widget.fileName.toLowerCase().split('.').last;
      String delimiterDesc;
      if (extension == 'csv') {
        delimiterDesc = '逗号分隔 (CSV)';
        _delimiter = ',';
      } else if (extension == 'xlsx' || extension == 'xls') {
        delimiterDesc = 'Excel 格式';
        _delimiter = 'excel';
      } else {
        delimiterDesc = 'PDF 文档';
        _delimiter = 'pdf';
      }
      setState(() {
        _steps[1].status = StepStatus.completed;
        _steps[1].description = delimiterDesc;
      });
      await Future.delayed(const Duration(milliseconds: 400));

      // Step 3: 特征匹配
      String featureDesc;
      if (widget.fileName.contains('微信')) {
        featureDesc = '检测到"微信支付账单明细"关键词';
        _detectedSource = '微信支付账单';
        _confidence = 0.99;
      } else if (widget.fileName.contains('支付宝')) {
        featureDesc = '检测到"支付宝交易记录"关键词';
        _detectedSource = '支付宝账单';
        _confidence = 0.98;
      } else if (widget.selectedBank != null) {
        final bankNames = {
          'icbc': '工商银行',
          'ccb': '建设银行',
          'abc': '农业银行',
          'cmb': '招商银行',
          'boc': '中国银行',
        };
        _detectedSource = '${bankNames[widget.selectedBank] ?? "银行"}账单';
        featureDesc = '基于选择的银行类型识别';
        _confidence = 0.95;
      } else {
        featureDesc = '未识别到已知格式';
        _detectedSource = '自定义格式';
        _confidence = 0.5;
        _needsFieldMapping = true;
      }
      setState(() {
        _steps[2].status = StepStatus.completed;
        _steps[2].description = featureDesc;
      });
      await Future.delayed(const Duration(milliseconds: 400));

      // Step 4: 解析器匹配
      setState(() {
        _steps[3].status = StepStatus.completed;
        _steps[3].description = _needsFieldMapping ? '需要手动配置字段映射' : '使用$_detectedSource解析器';
      });

      // 生成预览数据（模拟）
      _previewData = [
        {'date': '2024-12-30 12:35', 'amount': '-¥35.00', 'description': '美团外卖 - 午餐'},
        {'date': '2024-12-30 09:15', 'amount': '-¥6.00', 'description': '滴滴出行 - 地铁'},
        {'date': '2024-12-29 18:20', 'amount': '-¥128.00', 'description': '盒马鲜生'},
      ];

      setState(() => _isDetecting = false);
    } catch (e) {
      setState(() {
        _isDetecting = false;
        _errorMessage = e.toString();
      });
    }
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFileInfoCard(context, theme),
                    if (!_isDetecting && _errorMessage == null) ...[
                      _buildDetectionResult(context, theme),
                      _buildDetectionSteps(context, theme),
                      _buildDetectedSource(context, theme),
                      _buildPreviewData(context, theme),
                    ] else if (_errorMessage != null) ...[
                      _buildErrorCard(context, theme),
                    ] else ...[
                      _buildDetectionSteps(context, theme),
                    ],
                  ],
                ),
              ),
            ),
            if (!_isDetecting && _errorMessage == null)
              _buildNextButton(context, theme),
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
              '格式检测',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildFileInfoCard(BuildContext context, ThemeData theme) {
    final file = File(widget.filePath);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final sizeStr = fileSize > 1024 * 1024
        ? '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB'
        : '${(fileSize / 1024).toStringAsFixed(0)} KB';

    return Container(
      margin: const EdgeInsets.all(16),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.description,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$sizeStr · ${_encoding ?? "检测中..."}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionResult(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Text(
            '格式检测完成',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionSteps(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        children: _steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == _steps.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
            ),
            child: Row(
              children: [
                _buildStepIcon(step.status, theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        step.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepIcon(StepStatus status, ThemeData theme) {
    switch (status) {
      case StepStatus.completed:
        return Icon(Icons.check_circle, color: AppColors.success, size: 20);
      case StepStatus.inProgress:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        );
      case StepStatus.failed:
        return Icon(Icons.error, color: AppColors.error, size: 20);
      case StepStatus.pending:
        return Icon(
          Icons.circle_outlined,
          color: theme.colorScheme.outlineVariant,
          size: 20,
        );
    }
  }

  Widget _buildDetectedSource(BuildContext context, ThemeData theme) {
    if (_detectedSource == null) return const SizedBox.shrink();

    final sourceColor = _detectedSource!.contains('微信')
        ? const Color(0xFF1AAD19)
        : (_detectedSource!.contains('支付宝')
            ? const Color(0xFF1677FF)
            : theme.colorScheme.primary);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8F5E9),
            const Color(0xFFC8E6C9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sourceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _detectedSource!.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _detectedSource!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '自动识别 · 置信度 ${(_confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildPreviewData(BuildContext context, ThemeData theme) {
    if (_previewData.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '数据预览（前${_previewData.length}条）',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ..._previewData.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['date'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          item['amount'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['description'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '检测失败: $_errorMessage',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _goToNextStep,
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              _needsFieldMapping ? '下一步：字段映射' : '下一步：去重检测',
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

  void _goToNextStep() {
    if (_needsFieldMapping) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FieldMappingPage(
            filePath: widget.filePath,
            fileName: widget.fileName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeduplicationPage(
            filePath: widget.filePath,
            fileName: widget.fileName,
            detectedSource: _detectedSource,
          ),
        ),
      );
    }
  }
}

/// 检测步骤
class DetectionStep {
  String title;
  String description;
  StepStatus status;

  DetectionStep({
    required this.title,
    required this.description,
    required this.status,
  });
}

/// 步骤状态
enum StepStatus {
  pending,
  inProgress,
  completed,
  failed,
}
