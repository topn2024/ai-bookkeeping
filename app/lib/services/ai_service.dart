import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'http_service.dart';

/// AI识别结果模型
class AIRecognitionResult {
  final double? amount;
  final String? merchant;
  final String? category;
  final String? date;
  final String? description;
  final String? type; // expense/income
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
    this.confidence = 0.0,
    this.success = true,
    this.errorMessage,
  });

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

  @override
  String toString() {
    return 'AIRecognitionResult(amount: $amount, merchant: $merchant, category: $category, type: $type, confidence: $confidence)';
  }
}

/// AI服务类
class AIService {
  static final AIService _instance = AIService._internal();
  final HttpService _http = HttpService();

  factory AIService() => _instance;

  AIService._internal();

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

  /// 图片识别记账
  /// 上传小票/收据图片，AI自动识别交易信息
  Future<AIRecognitionResult> recognizeImage(File imageFile) async {
    try {
      // 将图片转为Base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _http.post('/ai/recognize-image', data: {
        'image_base64': base64Image,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return AIRecognitionResult(
          amount: data['amount']?.toDouble(),
          merchant: data['merchant'],
          category: _mapCategory(data['category']),
          date: data['date'],
          description: data['summary'] ?? data['description'],
          type: 'expense', // 图片识别主要是消费小票
          confidence: (data['confidence'] ?? 0.85).toDouble(),
          success: true,
        );
      } else {
        return AIRecognitionResult.error('识别失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return AIRecognitionResult.error(_handleDioError(e));
    } catch (e) {
      return AIRecognitionResult.error('识别失败: $e');
    }
  }

  /// 语音识别记账
  /// 解析语音转文本结果，提取交易信息
  Future<AIRecognitionResult> recognizeVoice(String transcribedText) async {
    try {
      final response = await _http.post('/ai/recognize-voice', data: {
        'text': transcribedText,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return AIRecognitionResult(
          amount: data['amount']?.toDouble(),
          category: _mapCategory(data['category']),
          type: data['type'] ?? 'expense',
          description: data['note'] ?? data['description'],
          confidence: (data['confidence'] ?? 0.85).toDouble(),
          success: true,
        );
      } else {
        return AIRecognitionResult.error('识别失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return AIRecognitionResult.error(_handleDioError(e));
    } catch (e) {
      return AIRecognitionResult.error('识别失败: $e');
    }
  }

  /// 文本解析记账
  /// 从自然语言描述中提取交易信息
  Future<AIRecognitionResult> parseText(String text) async {
    try {
      final response = await _http.post('/ai/parse-text', data: {
        'text': text,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        return AIRecognitionResult(
          amount: data['amount']?.toDouble(),
          category: _mapCategory(data['category']),
          type: data['type'] ?? 'expense',
          description: data['note'] ?? data['description'],
          confidence: (data['confidence'] ?? 0.85).toDouble(),
          success: true,
        );
      } else {
        return AIRecognitionResult.error('解析失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return AIRecognitionResult.error(_handleDioError(e));
    } catch (e) {
      return AIRecognitionResult.error('解析失败: $e');
    }
  }

  /// 智能分类建议
  /// 根据交易描述推荐最可能的分类
  Future<String?> suggestCategory(String description) async {
    try {
      final result = await parseText(description);
      if (result.success && result.category != null) {
        return result.category;
      }
      return null;
    } catch (e) {
      return null;
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

  String _mapCategory(String? category) {
    if (category == null) return 'other';
    return categoryMap[category] ?? category.toLowerCase();
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时，请稍后重试';
      case DioExceptionType.receiveTimeout:
        return '接收超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查服务器是否运行';
      case DioExceptionType.badResponse:
        return '服务器响应错误: ${e.response?.statusCode}';
      default:
        return '网络错误: ${e.message}';
    }
  }
}
