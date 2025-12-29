import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/config.dart';
import '../core/logger.dart';

/// 千问API服务
/// 使用阿里云通义千问模型进行图片识别、文本解析和音频识别
class QwenService {
  static final QwenService _instance = QwenService._internal();
  static final _logger = Logger.getLogger('QwenService');

  // API端点
  static const String _textApiUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation';
  static const String _visionApiUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';
  static const String _audioApiUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';

  late final Dio _dio;
  bool _initialized = false;

  factory QwenService() => _instance;

  QwenService._internal();

  /// Initialize the service with API key from config
  void _ensureInitialized() {
    if (_initialized) return;

    final apiKey = appConfig.qwenApiKey;
    if (apiKey.isEmpty) {
      _logger.warning('Qwen API key not configured');
    }

    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    ));
    _initialized = true;
    _logger.info('QwenService initialized');
  }

  /// 图片识别 - 识别小票/收据
  /// 使用 qwen-vl-plus 视觉模型
  Future<QwenRecognitionResult> recognizeReceipt(File imageFile) async {
    _ensureInitialized();
    _logger.info('Recognizing receipt: ${imageFile.path}');

    try {
      // 读取图片并转为Base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      _logger.debug('Image size: ${bytes.length} bytes');

      // 获取图片MIME类型
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);

      final response = await _dio.post(
        _visionApiUrl,
        data: {
          'model': 'qwen-vl-plus',
          'input': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'image': 'data:$mimeType;base64,$base64Image',
                  },
                  {
                    'text': '''请分析这张小票/收据图片，提取以下信息并以JSON格式返回：
1. amount: 金额（数字，单位元）
2. merchant: 商家名称
3. category: 消费类别（餐饮/交通/购物/娱乐/住房/医疗/教育/其他）
4. date: 日期（格式：YYYY-MM-DD，如无法识别则返回null）
5. items: 商品列表（数组，每项包含name和price）
6. description: 简短描述（一句话总结这笔消费）

只返回JSON，不要其他文字。如果无法识别某项，该字段返回null。
示例格式：
{"amount": 35.5, "merchant": "星巴克", "category": "餐饮", "date": "2025-01-15", "items": [{"name": "拿铁", "price": 35.5}], "description": "星巴克咖啡消费"}'''
                  }
                ]
              }
            ]
          },
          'parameters': {
            'result_format': 'message',
          }
        },
      );

      return _parseVisionResponse(response.data);
    } on DioException catch (e) {
      _logger.error('Receipt recognition failed', error: e);
      return QwenRecognitionResult.error(_handleDioError(e));
    } catch (e, stack) {
      _logger.error('Receipt recognition failed', error: e, stack: stack);
      return QwenRecognitionResult.error('图片识别失败: $e');
    }
  }

  /// 文本解析 - 从自然语言提取记账信息
  /// 使用 qwen-turbo 文本模型
  Future<QwenRecognitionResult> parseBookkeepingText(String text) async {
    _ensureInitialized();
    _logger.info('Parsing bookkeeping text: ${text.length} chars');

    try {
      final response = await _dio.post(
        _textApiUrl,
        data: {
          'model': 'qwen-turbo',
          'input': {
            'messages': [
              {
                'role': 'system',
                'content': '''你是一个智能记账助手。用户会用自然语言描述一笔消费或收入，你需要提取关键信息。

请以JSON格式返回以下字段：
1. amount: 金额（数字）
2. type: 类型（expense表示支出，income表示收入）
3. category: 分类（支出分类：餐饮/交通/购物/娱乐/住房/医疗/教育/其他；收入分类：工资/奖金/兼职/理财/其他）
4. description: 简短描述
5. date: 日期（如提到"今天"、"昨天"等，转换为具体日期YYYY-MM-DD格式，否则返回null）

只返回JSON，不要其他文字。'''
              },
              {
                'role': 'user',
                'content': text,
              }
            ]
          },
          'parameters': {
            'result_format': 'message',
          }
        },
      );

      return _parseTextResponse(response.data);
    } on DioException catch (e) {
      _logger.error('Text parsing failed', error: e);
      return QwenRecognitionResult.error(_handleDioError(e));
    } catch (e, stack) {
      _logger.error('Text parsing failed', error: e, stack: stack);
      return QwenRecognitionResult.error('文本解析失败: $e');
    }
  }

  /// 音频识别记账 - 直接从音频中提取记账信息
  /// 使用 qwen-audio-turbo 音频模型
  Future<QwenRecognitionResult> recognizeAudio(Uint8List audioData,
      {String format = 'wav'}) async {
    _ensureInitialized();
    _logger.info('Recognizing audio: ${audioData.length} bytes, format: $format');

    try {
      // 将音频数据转为Base64
      final base64Audio = base64Encode(audioData);

      // 获取音频MIME类型
      final mimeType = _getAudioMimeType(format);

      final response = await _dio.post(
        _audioApiUrl,
        data: {
          'model': 'qwen-audio-turbo',
          'input': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'audio': 'data:$mimeType;base64,$base64Audio',
                  },
                  {
                    'text': '''请分析这段语音，提取记账信息。

请识别语音内容，并提取：
1. amount: 金额（数字）
2. type: 类型（expense表示支出，income表示收入）
3. category: 消费分类（餐饮/交通/购物/娱乐/住房/医疗/教育/其他）或收入分类（工资/奖金/兼职/理财/其他）
4. description: 备注描述

请以JSON格式返回：
{
    "transcription": "语音转写文本",
    "amount": 金额数字,
    "type": "expense或income",
    "category": "分类",
    "description": "备注"
}

只返回JSON，不要其他文字。'''
                  }
                ]
              }
            ]
          },
          'parameters': {
            'result_format': 'message',
          }
        },
      );

      return _parseAudioResponse(response.data);
    } on DioException catch (e) {
      _logger.error('Audio recognition failed', error: e);
      return QwenRecognitionResult.error(_handleDioError(e));
    } catch (e, stack) {
      _logger.error('Audio recognition failed', error: e, stack: stack);
      return QwenRecognitionResult.error('音频识别失败: $e');
    }
  }

  /// 从音频文件识别记账信息
  Future<QwenRecognitionResult> recognizeAudioFile(File audioFile) async {
    _logger.info('Recognizing audio file: ${audioFile.path}');
    try {
      final bytes = await audioFile.readAsBytes();
      final extension = audioFile.path.split('.').last.toLowerCase();
      return recognizeAudio(bytes, format: extension);
    } catch (e, stack) {
      _logger.error('Read audio file failed', error: e, stack: stack);
      return QwenRecognitionResult.error('读取音频文件失败: $e');
    }
  }

  /// 智能分类建议
  Future<String?> suggestCategory(String description) async {
    _ensureInitialized();
    _logger.debug('Suggesting category for: $description');

    try {
      final response = await _dio.post(
        _textApiUrl,
        data: {
          'model': 'qwen-turbo',
          'input': {
            'messages': [
              {
                'role': 'system',
                'content': '''你是一个消费分类助手。根据用户描述的消费内容，返回最合适的分类。
可选分类：餐饮、交通、购物、娱乐、住房、医疗、教育、其他
只返回分类名称，不要其他文字。'''
              },
              {
                'role': 'user',
                'content': description,
              }
            ]
          },
          'parameters': {
            'result_format': 'message',
          }
        },
      );

      final result = response.data;
      if (result['output'] != null && result['output']['choices'] != null) {
        final choices = result['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String;
          final category = content.trim();
          _logger.debug('Suggested category: $category');
          return category;
        }
      }
      return null;
    } catch (e, stack) {
      _logger.warning('Category suggestion failed', error: e, stack: stack);
      return null;
    }
  }

  /// 邮箱账单解析
  Future<List<QwenRecognitionResult>> parseEmailBill(String emailContent) async {
    _ensureInitialized();
    _logger.info('Parsing email bill: ${emailContent.length} chars');

    try {
      final response = await _dio.post(
        _textApiUrl,
        data: {
          'model': 'qwen-plus',
          'input': {
            'messages': [
              {
                'role': 'system',
                'content': '''你是一个账单解析助手。用户会提供信用卡账单或消费通知邮件的内容，你需要提取所有交易记录。

请以JSON数组格式返回，每条记录包含：
1. amount: 金额（数字）
2. merchant: 商家名称
3. category: 分类（餐饮/交通/购物/娱乐/住房/医疗/教育/其他）
4. date: 交易日期（YYYY-MM-DD格式）
5. description: 交易描述

只返回JSON数组，不要其他文字。如果只有一条记录，也要返回数组格式。'''
              },
              {
                'role': 'user',
                'content': emailContent,
              }
            ]
          },
          'parameters': {
            'result_format': 'message',
          }
        },
      );

      final results = _parseEmailResponse(response.data);
      _logger.info('Parsed ${results.length} transactions from email');
      return results;
    } on DioException catch (e) {
      _logger.error('Email bill parsing failed', error: e);
      return [QwenRecognitionResult.error(_handleDioError(e))];
    } catch (e, stack) {
      _logger.error('Email bill parsing failed', error: e, stack: stack);
      return [QwenRecognitionResult.error('账单解析失败: $e')];
    }
  }

  QwenRecognitionResult _parseVisionResponse(Map<String, dynamic> response) {
    try {
      if (response['output'] != null && response['output']['choices'] != null) {
        final choices = response['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as List;
          // 视觉模型返回的content是数组
          String textContent = '';
          for (final item in content) {
            if (item is Map && item['text'] != null) {
              textContent = item['text'];
              break;
            }
          }

          if (textContent.isNotEmpty) {
            return _extractJsonResult(textContent);
          }
        }
      }
      return QwenRecognitionResult.error('无法解析响应');
    } catch (e) {
      return QwenRecognitionResult.error('解析响应失败: $e');
    }
  }

  QwenRecognitionResult _parseTextResponse(Map<String, dynamic> response) {
    try {
      if (response['output'] != null && response['output']['choices'] != null) {
        final choices = response['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String;
          return _extractJsonResult(content);
        }
      }
      return QwenRecognitionResult.error('无法解析响应');
    } catch (e) {
      return QwenRecognitionResult.error('解析响应失败: $e');
    }
  }

  List<QwenRecognitionResult> _parseEmailResponse(Map<String, dynamic> response) {
    try {
      if (response['output'] != null && response['output']['choices'] != null) {
        final choices = response['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String;

          // 提取JSON数组
          final jsonStr = _extractJsonString(content);
          if (jsonStr != null) {
            final decoded = jsonDecode(jsonStr);
            if (decoded is List) {
              return decoded.map((item) {
                return QwenRecognitionResult(
                  amount: (item['amount'] as num?)?.toDouble(),
                  merchant: item['merchant'] as String?,
                  category: item['category'] as String?,
                  date: item['date'] as String?,
                  description: item['description'] as String?,
                  type: 'expense',
                  success: true,
                  confidence: 0.85,
                );
              }).toList();
            }
          }
        }
      }
      return [QwenRecognitionResult.error('无法解析账单')];
    } catch (e) {
      return [QwenRecognitionResult.error('解析账单失败: $e')];
    }
  }

  QwenRecognitionResult _extractJsonResult(String content) {
    try {
      // 尝试提取JSON
      final jsonStr = _extractJsonString(content);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr);
        return QwenRecognitionResult(
          amount: (data['amount'] as num?)?.toDouble(),
          merchant: data['merchant'] as String?,
          category: data['category'] as String?,
          date: data['date'] as String?,
          description: data['description'] as String?,
          items: data['items'] != null
              ? (data['items'] as List).map((e) => ReceiptItem.fromJson(e)).toList()
              : null,
          type: data['type'] as String? ?? 'expense',
          success: true,
          confidence: 0.9,
        );
      }
      return QwenRecognitionResult.error('无法提取JSON');
    } catch (e) {
      return QwenRecognitionResult.error('JSON解析失败: $e');
    }
  }

  String? _extractJsonString(String content) {
    // 尝试直接解析
    try {
      jsonDecode(content);
      return content;
    } catch (_) {}

    // 尝试提取 {...} 或 [...]
    final jsonMatch = RegExp(r'[\{\[][\s\S]*[\}\]]').firstMatch(content);
    if (jsonMatch != null) {
      return jsonMatch.group(0);
    }

    return null;
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _getAudioMimeType(String extension) {
    switch (extension) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/m4a';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/wav';
    }
  }

  QwenRecognitionResult _parseAudioResponse(Map<String, dynamic> response) {
    try {
      if (response['output'] != null && response['output']['choices'] != null) {
        final choices = response['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'];
          var content = message['content'];

          // 音频模型可能返回字符串或数组
          String textContent = '';
          if (content is String) {
            textContent = content;
          } else if (content is List) {
            for (final item in content) {
              if (item is Map && item['text'] != null) {
                textContent = item['text'];
                break;
              }
            }
          }

          if (textContent.isNotEmpty) {
            return _extractAudioJsonResult(textContent);
          }
        }
      }
      return QwenRecognitionResult.error('无法解析音频响应');
    } catch (e) {
      return QwenRecognitionResult.error('解析音频响应失败: $e');
    }
  }

  QwenRecognitionResult _extractAudioJsonResult(String content) {
    try {
      final jsonStr = _extractJsonString(content);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr);
        return QwenRecognitionResult(
          amount: (data['amount'] as num?)?.toDouble(),
          category: data['category'] as String?,
          description: data['description'] as String? ?? data['transcription'] as String?,
          type: data['type'] as String? ?? 'expense',
          success: true,
          confidence: 0.9,
        );
      }
      return QwenRecognitionResult.error('无法提取JSON');
    } catch (e) {
      return QwenRecognitionResult.error('JSON解析失败: $e');
    }
  }

  String _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return 'API错误: ${data['message']}';
      }
      return 'API错误: ${e.response?.statusCode}';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时，请稍后重试';
      case DioExceptionType.receiveTimeout:
        return '接收超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '网络连接失败';
      default:
        return '网络错误: ${e.message}';
    }
  }
}

/// 千问识别结果
class QwenRecognitionResult {
  final double? amount;
  final String? merchant;
  final String? category;
  final String? date;
  final String? description;
  final String? type;
  final List<ReceiptItem>? items;
  final double confidence;
  final bool success;
  final String? errorMessage;

  QwenRecognitionResult({
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

  factory QwenRecognitionResult.error(String message) {
    return QwenRecognitionResult(
      success: false,
      errorMessage: message,
      confidence: 0.0,
    );
  }

  @override
  String toString() {
    return 'QwenRecognitionResult(amount: $amount, merchant: $merchant, category: $category, type: $type, success: $success)';
  }
}

/// 小票商品项
class ReceiptItem {
  final String name;
  final double price;

  ReceiptItem({required this.name, required this.price});

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'price': price};
}
