import 'dart:io';
import '../ai_service.dart';
import '../qwen_service.dart';

/// 图片识别服务
///
/// 负责处理所有图片相关的 AI 识别功能：
/// - 小票/收据识别
/// - 批量图片识别（长截图、账单列表）
///
/// 这是从 AIService 中提取的专注于图片识别的服务
class ImageRecognitionService {
  static final ImageRecognitionService _instance = ImageRecognitionService._internal();
  final QwenService _qwenService = QwenService();

  factory ImageRecognitionService() => _instance;
  ImageRecognitionService._internal();

  /// 识别单张图片
  ///
  /// 上传小票/收据图片，使用千问视觉模型自动识别交易信息
  ///
  /// [imageFile] 图片文件
  /// 返回识别结果 [AIRecognitionResult]
  Future<AIRecognitionResult> recognizeImage(File imageFile) async {
    try {
      final qwenResult = await _qwenService.recognizeReceipt(imageFile);
      return AIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return AIRecognitionResult.error('图片识别失败: $e');
    }
  }

  /// 批量识别图片
  ///
  /// 从长截图（如账单列表、银行流水）中识别多笔交易
  ///
  /// [imageFile] 包含多笔交易的图片文件
  /// 返回多笔交易识别结果 [MultiAIRecognitionResult]
  Future<MultiAIRecognitionResult> recognizeImageBatch(File imageFile) async {
    try {
      final qwenResults = await _qwenService.recognizeReceiptBatch(imageFile);

      if (qwenResults.isEmpty) {
        return MultiAIRecognitionResult.error('未识别到交易记录');
      }

      // 检查是否有错误结果
      if (qwenResults.length == 1 && !qwenResults.first.success) {
        return MultiAIRecognitionResult.error(
          qwenResults.first.errorMessage ?? '图片识别失败'
        );
      }

      final aiResults = qwenResults
          .where((r) => r.success)
          .map((r) => AIRecognitionResult.fromQwenResult(r))
          .toList();

      if (aiResults.isEmpty) {
        return MultiAIRecognitionResult.error('未识别到有效的交易记录');
      }

      return MultiAIRecognitionResult(
        transactions: aiResults,
        success: true,
      );
    } catch (e) {
      return MultiAIRecognitionResult.error('批量图片识别失败: $e');
    }
  }

  /// 判断图片是否可能包含多笔交易
  ///
  /// 通过图片尺寸和内容特征判断是否为长截图
  /// 用于自动选择单张或批量识别模式
  Future<bool> isLikelyBatchImage(File imageFile) async {
    // 简单的启发式判断：文件较大可能是长截图
    final fileSize = await imageFile.length();
    return fileSize > 500 * 1024; // 大于500KB
  }

  /// 智能识别图片
  ///
  /// 自动判断并选择单张或批量识别模式
  Future<MultiAIRecognitionResult> smartRecognize(File imageFile) async {
    if (await isLikelyBatchImage(imageFile)) {
      return recognizeImageBatch(imageFile);
    } else {
      final result = await recognizeImage(imageFile);
      return MultiAIRecognitionResult.single(result);
    }
  }
}
