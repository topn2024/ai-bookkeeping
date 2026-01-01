import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../providers/ai_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/ai_service.dart';
import '../services/qwen_service.dart' show ReceiptItem;
import '../services/source_file_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../widgets/duplicate_transaction_dialog.dart';
import '../services/category_localization_service.dart';
import '../utils/date_utils.dart';

/// 图片识别记账页面
class ImageRecognitionPage extends ConsumerStatefulWidget {
  const ImageRecognitionPage({super.key});

  @override
  ConsumerState<ImageRecognitionPage> createState() => _ImageRecognitionPageState();
}

class _ImageRecognitionPageState extends ConsumerState<ImageRecognitionPage> {
  final ImagePicker _picker = ImagePicker();
  final SourceFileService _sourceFileService = SourceFileService();
  File? _selectedImage;
  AIRecognitionResult? _recognitionResult;
  bool _isProcessing = false;
  DateTime? _recognitionTimestamp;
  // 缓存 ScaffoldMessenger 用于安全清除 SnackBar
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // 清除 SnackBar，避免返回首页后继续显示
    _scaffoldMessenger?.clearSnackBars();
    // 重置AI状态
    ref.read(aiBookkeepingProvider.notifier).reset();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _recognitionResult = null;
        });
        await _recognizeImage();
      }
    } catch (e) {
      _showError('选择图片失败: $e');
    }
  }

  Future<void> _recognizeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Record recognition timestamp
      _recognitionTimestamp = DateTime.now();

      final result = await ref
          .read(aiBookkeepingProvider.notifier)
          .recognizeImage(_selectedImage!);

      setState(() {
        _recognitionResult = result;
        _isProcessing = false;
      });

      if (!result.success) {
        _showError(result.errorMessage ?? '识别失败');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('识别失败: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.expense,
      ),
    );
  }

  /// 解析AI识别的日期字符串
  /// 使用集中的日期解析工具类 AppDateUtils.parseRecognizedDate
  DateTime _parseDate(String? dateStr) {
    return AppDateUtils.parseRecognizedDate(dateStr);
  }

  Future<void> _confirmAndCreateTransaction() async {
    if (_recognitionResult == null || !_recognitionResult!.success) return;

    // Generate transaction ID first
    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

    // Save source image file locally
    String? sourceFileLocalPath;
    String? sourceFileType;
    int? sourceFileSize;

    if (_selectedImage != null) {
      sourceFileLocalPath = await _sourceFileService.saveImageFile(
        _selectedImage!,
        transactionId,
      );

      if (sourceFileLocalPath != null) {
        final file = File(sourceFileLocalPath);
        if (await file.exists()) {
          sourceFileSize = await file.length();
          // Determine MIME type from extension
          final ext = sourceFileLocalPath.split('.').last.toLowerCase();
          sourceFileType = _getMimeType(ext);
        }
      }
    }

    // Prepare raw response data as JSON
    String? recognitionRawData;
    if (_recognitionResult != null) {
      recognitionRawData = jsonEncode({
        'amount': _recognitionResult!.amount,
        'category': _recognitionResult!.category,
        'merchant': _recognitionResult!.merchant,
        'date': _recognitionResult!.date,
        'type': _recognitionResult!.type,
        'description': _recognitionResult!.description,
        'confidence': _recognitionResult!.confidence,
        'timestamp': _recognitionTimestamp?.toIso8601String(),
        'items': _recognitionResult!.items?.map((item) => {
          'name': item.name,
          'price': item.price,
        }).toList(),
      });
    }

    // Calculate expiry date based on user settings
    final expiryDate = await _sourceFileService.calculateExpiryDate();

    // 解析识别出的日期
    final transactionDate = _parseDate(_recognitionResult!.date);

    // 创建交易记录 with source file data
    final transaction = Transaction(
      id: transactionId,
      type: _recognitionResult!.type == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      amount: _recognitionResult!.amount ?? 0,
      category: _recognitionResult!.category ?? 'other',
      note: _recognitionResult!.description ?? _recognitionResult!.merchant,
      date: transactionDate,
      accountId: 'cash',
      // Source file fields
      source: TransactionSource.image,
      aiConfidence: _recognitionResult!.confidence,
      sourceFileLocalPath: sourceFileLocalPath,
      sourceFileType: sourceFileType,
      sourceFileSize: sourceFileSize,
      recognitionRawData: recognitionRawData,
      sourceFileExpiresAt: expiryDate,
    );

    // 使用重复检测保存交易
    final confirmed = await DuplicateTransactionHelper.checkAndConfirm(
      context: context,
      transaction: transaction,
      transactionNotifier: ref.read(transactionProvider.notifier),
    );

    if (!confirmed) return; // 用户取消

    // 返回上一页
    Navigator.pop(context, _recognitionResult);
  }

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照记账'),
        actions: [
          if (_recognitionResult != null && _recognitionResult!.success)
            TextButton(
              onPressed: _confirmAndCreateTransaction,
              child: const Text(
                '确认',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 图片预览区域
          Expanded(
            flex: 2,
            child: _buildImagePreview(),
          ),
          // 识别结果区域
          Expanded(
            flex: 1,
            child: _buildRecognitionResult(),
          ),
          // 底部操作按钮
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: _selectedImage != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
                if (_isProcessing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'AI 识别中...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '请拍摄或上传小票/收据',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRecognitionResult() {
    if (_recognitionResult == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '识别结果将在这里显示',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    if (!_recognitionResult!.success) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.expense, size: 32),
              const SizedBox(height: 8),
              Text(
                _recognitionResult!.errorMessage ?? '识别失败',
                style: const TextStyle(color: AppColors.expense),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _recognizeImage,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showDetailDialog(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
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
                const Icon(Icons.check_circle, color: AppColors.income, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '识别成功',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.income,
                  ),
                ),
                const Spacer(),
                Text(
                  '置信度: ${(_recognitionResult!.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildResultItem('金额', '¥ ${_recognitionResult!.amount?.toStringAsFixed(2) ?? '未识别'}'),
                    _buildResultItem('商户', _recognitionResult!.merchant ?? '未识别'),
                    _buildResultItem('分类', _getCategoryName(_recognitionResult!.category)),
                    _buildResultItem('日期', _recognitionResult!.date ?? '今天'),
                    if (_recognitionResult!.items != null && _recognitionResult!.items!.isNotEmpty)
                      _buildResultItem('明细', '${_recognitionResult!.items!.length}项商品 (点击查看)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示账单详情对话框
  void _showDetailDialog() {
    if (_recognitionResult == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖拽指示器
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      '账单详情',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // 详情内容
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 基本信息卡片
                    _buildDetailCard('基本信息', [
                      _buildDetailRow('总金额', '¥ ${_recognitionResult!.amount?.toStringAsFixed(2) ?? '未识别'}',
                          valueColor: AppColors.expense),
                      _buildDetailRow('商户名称', _recognitionResult!.merchant ?? '未识别'),
                      _buildDetailRow('交易类型', _recognitionResult!.type == 'income' ? '收入' : '支出'),
                      _buildDetailRow('分类', _getCategoryName(_recognitionResult!.category)),
                      _buildDetailRow('交易日期', _recognitionResult!.date ?? '今天'),
                      if (_recognitionResult!.description != null)
                        _buildDetailRow('摘要', _recognitionResult!.description!),
                    ]),
                    const SizedBox(height: 16),
                    // 商品明细列表
                    if (_recognitionResult!.items != null && _recognitionResult!.items!.isNotEmpty) ...[
                      _buildDetailCard('商品明细 (${_recognitionResult!.items!.length}项)', [
                        for (final item in _recognitionResult!.items!)
                          _buildItemRow(item),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ReceiptItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            '¥${item.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) {
      return CategoryLocalizationService.instance.getCategoryName('other_expense');
    }

    // 使用本地化服务获取分类名称
    final category = DefaultCategories.findById(categoryId);
    if (category != null) {
      return category.localizedName;
    }

    // 如果找不到分类，尝试使用本地化服务直接获取
    return CategoryLocalizationService.instance.getCategoryName(categoryId);
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('拍照'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('相册'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
