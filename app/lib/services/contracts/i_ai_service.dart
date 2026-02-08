import 'dart:io';

/// 图像识别结果
class ImageRecognitionResult {
  final double amount;
  final String? category;
  final String? merchant;
  final String? description;
  final DateTime? date;
  final double confidence;
  final String? rawText;

  const ImageRecognitionResult({
    required this.amount,
    this.category,
    this.merchant,
    this.description,
    this.date,
    required this.confidence,
    this.rawText,
  });
}

/// 文本解析结果
class TextParseResult {
  final double? amount;
  final String? category;
  final String? description;
  final DateTime? date;
  final String? merchant;
  final double confidence;

  const TextParseResult({
    this.amount,
    this.category,
    this.description,
    this.date,
    this.merchant,
    required this.confidence,
  });
}

/// 分类建议
class CategorySuggestion {
  final String category;
  final double confidence;
  final String? reason;

  const CategorySuggestion({
    required this.category,
    required this.confidence,
    this.reason,
  });
}

/// AI 服务接口
///
/// 定义 AI 相关操作的抽象接口，包括图像识别、文本解析、分类建议等。
abstract class IAIService {
  // ==================== 图像识别 ====================

  /// 识别图像中的交易信息
  Future<ImageRecognitionResult> recognizeImage(File image);

  /// 识别 Base64 编码的图像
  Future<ImageRecognitionResult> recognizeBase64Image(String base64Image);

  // ==================== 文本解析 ====================

  /// 解析文本中的交易信息
  Future<TextParseResult> parseText(String text);

  /// 解析语音转文本的结果
  Future<TextParseResult> parseVoiceText(String voiceText);

  // ==================== 分类建议 ====================

  /// 根据描述建议分类
  Future<List<CategorySuggestion>> suggestCategories(String description);

  /// 根据商户名称建议分类
  Future<CategorySuggestion?> suggestCategoryByMerchant(String merchant);

  /// 根据历史记录学习并建议分类
  Future<CategorySuggestion?> suggestCategoryByHistory({
    required String description,
    double? amount,
    String? merchant,
  });

  // ==================== 预算建议 ====================

  /// 优化预算分配
  Future<Map<String, double>> optimizeBudget({
    required double monthlyIncome,
    required Map<String, double> historicalExpenses,
  });

  /// 生成储蓄建议
  Future<String> generateSavingsAdvice({
    required double targetAmount,
    required double currentAmount,
    required DateTime deadline,
  });

  // ==================== 智能建议 ====================

  /// 生成财务建议
  Future<String> generateFinancialAdvice(Map<String, dynamic> context);

  /// 分析消费趋势
  Future<String> analyzeTrend(List<Map<String, dynamic>> transactions);

  /// 检测异常消费
  Future<List<String>> detectAnomalies(List<Map<String, dynamic>> transactions);
}
