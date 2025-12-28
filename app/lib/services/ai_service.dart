import 'dart:io';
import 'qwen_service.dart';

/// AI识别结果模型
class AIRecognitionResult {
  final double? amount;
  final String? merchant;
  final String? category;
  final String? date;
  final String? description;
  final String? type; // expense/income
  final List<ReceiptItem>? items; // 小票商品列表
  final double confidence;
  final bool success;
  final String? errorMessage;

  AIRecognitionResult({
    this.amount,
    this.merchant,
    this.category,
    this.date,
    this.description,
    this.type,
    this.items,
    this.confidence = 0.0,
    this.success = true,
    this.errorMessage,
  });

  factory AIRecognitionResult.fromQwenResult(QwenRecognitionResult qwenResult) {
    return AIRecognitionResult(
      amount: qwenResult.amount,
      merchant: qwenResult.merchant,
      category: _mapCategory(qwenResult.category),
      date: qwenResult.date,
      description: qwenResult.description,
      type: qwenResult.type,
      items: qwenResult.items,
      confidence: qwenResult.confidence,
      success: qwenResult.success,
      errorMessage: qwenResult.errorMessage,
    );
  }

  factory AIRecognitionResult.fromJson(Map<String, dynamic> json) {
    return AIRecognitionResult(
      amount: json['amount']?.toDouble(),
      merchant: json['merchant'],
      category: json['category'],
      date: json['date'],
      description: json['description'],
      type: json['type'],
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      success: json['success'] ?? true,
      errorMessage: json['error_message'],
    );
  }

  factory AIRecognitionResult.error(String message) {
    return AIRecognitionResult(
      success: false,
      errorMessage: message,
      confidence: 0.0,
    );
  }

  /// 分类映射
  static String _mapCategory(String? category) {
    if (category == null) return 'other';
    return categoryMap[category] ?? category.toLowerCase();
  }

  /// 分类映射表
  static const Map<String, String> categoryMap = {
    '餐饮': 'food',
    '交通': 'transport',
    '购物': 'shopping',
    '娱乐': 'entertainment',
    '住房': 'housing',
    '医疗': 'medical',
    '教育': 'education',
    '其他': 'other',
    '工资': 'salary',
    '奖金': 'bonus',
    '兼职': 'parttime',
    '理财': 'investment',
  };

  @override
  String toString() {
    return 'AIRecognitionResult(amount: $amount, merchant: $merchant, category: $category, type: $type, confidence: $confidence)';
  }
}

/// AI服务类
/// 使用阿里云通义千问模型进行智能记账
class AIService {
  static final AIService _instance = AIService._internal();
  final QwenService _qwenService = QwenService();

  factory AIService() => _instance;

  AIService._internal();

  /// 图片识别记账
  /// 上传小票/收据图片，使用千问视觉模型自动识别交易信息
  Future<AIRecognitionResult> recognizeImage(File imageFile) async {
    try {
      final qwenResult = await _qwenService.recognizeReceipt(imageFile);
      return AIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return AIRecognitionResult.error('图片识别失败: $e');
    }
  }

  /// 语音识别记账
  /// 解析语音转文本结果，使用千问模型提取交易信息
  Future<AIRecognitionResult> recognizeVoice(String transcribedText) async {
    return parseText(transcribedText);
  }

  /// 文本解析记账
  /// 从自然语言描述中提取交易信息，使用千问模型
  Future<AIRecognitionResult> parseText(String text) async {
    try {
      final qwenResult = await _qwenService.parseBookkeepingText(text);
      return AIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return AIRecognitionResult.error('文本解析失败: $e');
    }
  }

  /// 智能分类建议
  /// 根据交易描述推荐最可能的分类，使用千问模型
  Future<String?> suggestCategory(String description) async {
    try {
      final category = await _qwenService.suggestCategory(description);
      if (category != null) {
        return AIRecognitionResult.categoryMap[category] ?? category.toLowerCase();
      }
      return localSuggestCategory(description);
    } catch (e) {
      // 如果API失败，回退到本地分类
      return localSuggestCategory(description);
    }
  }

  /// 邮箱账单解析
  /// 从信用卡账单邮件中提取多条交易记录
  Future<List<AIRecognitionResult>> parseEmailBill(String emailContent) async {
    try {
      final qwenResults = await _qwenService.parseEmailBill(emailContent);
      return qwenResults.map((r) => AIRecognitionResult.fromQwenResult(r)).toList();
    } catch (e) {
      return [AIRecognitionResult.error('账单解析失败: $e')];
    }
  }

  /// 本地智能分类（离线模式）
  /// 使用关键词匹配进行分类推荐
  String localSuggestCategory(String description) {
    final text = description.toLowerCase();

    // 餐饮关键词
    if (_containsAny(text, ['早餐', '午餐', '晚餐', '外卖', '饭', '菜', '餐', '吃', '美团', '饿了么', '奶茶', '咖啡', '火锅', '烧烤', '快餐', '便当'])) {
      return 'food';
    }

    // 交通关键词
    if (_containsAny(text, ['打车', '滴滴', '地铁', '公交', '出租', '高铁', '火车', '飞机', '机票', '加油', '停车', '过路费', '交通'])) {
      return 'transport';
    }

    // 购物关键词
    if (_containsAny(text, ['淘宝', '京东', '拼多多', '超市', '商场', '衣服', '鞋', '包', '化妆品', '日用品', '购物', '买'])) {
      return 'shopping';
    }

    // 娱乐关键词
    if (_containsAny(text, ['电影', '游戏', '唱歌', 'ktv', '旅游', '酒店', '门票', '健身', '运动', '娱乐'])) {
      return 'entertainment';
    }

    // 住房关键词
    if (_containsAny(text, ['房租', '水电', '物业', '燃气', '网费', '电费', '水费', '房贷', '装修'])) {
      return 'housing';
    }

    // 医疗关键词
    if (_containsAny(text, ['医院', '药', '看病', '体检', '挂号', '医疗', '门诊', '住院'])) {
      return 'medical';
    }

    // 教育关键词
    if (_containsAny(text, ['学费', '培训', '课程', '书', '教育', '学习', '考试', '补习'])) {
      return 'education';
    }

    // 收入关键词
    if (_containsAny(text, ['工资', '薪水', '奖金', '红包', '收入', '到账', '进账', '报销', '利息'])) {
      return 'salary';
    }

    return 'other';
  }

  /// 判断是否是收入类型
  bool isIncomeType(String description) {
    final text = description.toLowerCase();
    return _containsAny(text, ['工资', '薪水', '奖金', '红包', '收入', '到账', '进账', '报销', '利息', '返现', '收到', '赚']);
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}
