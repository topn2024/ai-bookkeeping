import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import '../models/category.dart';

/// 图片识别记账页面
class ImageRecognitionPage extends ConsumerStatefulWidget {
  const ImageRecognitionPage({super.key});

  @override
  ConsumerState<ImageRecognitionPage> createState() => _ImageRecognitionPageState();
}

class _ImageRecognitionPageState extends ConsumerState<ImageRecognitionPage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  AIRecognitionResult? _recognitionResult;
  bool _isProcessing = false;

  @override
  void dispose() {
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

  void _confirmAndCreateTransaction() {
    if (_recognitionResult == null || !_recognitionResult!.success) return;

    // 返回识别结果给上一个页面
    Navigator.pop(context, _recognitionResult);
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                  if (_recognitionResult!.description != null)
                    _buildResultItem('摘要', _recognitionResult!.description!),
                ],
              ),
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
    if (categoryId == null) return '其他';

    // 查找分类名称
    for (final category in DefaultCategories.expenseCategories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    for (final category in DefaultCategories.incomeCategories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }

    // 分类映射
    const categoryNames = {
      'food': '餐饮',
      'transport': '交通',
      'shopping': '购物',
      'entertainment': '娱乐',
      'housing': '住房',
      'medical': '医疗',
      'education': '教育',
      'other': '其他',
    };

    return categoryNames[categoryId] ?? categoryId;
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
