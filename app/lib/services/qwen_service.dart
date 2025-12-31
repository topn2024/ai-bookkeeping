import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/config.dart';
import '../core/logger.dart';
import 'app_config_service.dart';

/// 千问API服务
/// 使用阿里云通义千问模型进行图片识别、文本解析和音频识别
class QwenService {
  static final QwenService _instance = QwenService._internal();
  static final _logger = Logger.getLogger('QwenService');
  final AppConfigService _configService = AppConfigService();

  /// 获取 AI 模型配置
  AIModelConfig get _models => _configService.config.aiModels;

  // API端点
  static const String _textApiUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation';
  static const String _visionApiUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';
  static const String _audioApiUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';

  late Dio _dio;
  bool _initialized = false;
  String? _lastApiKey;

  factory QwenService() => _instance;

  QwenService._internal();

  /// Initialize the service with API key from config
  /// Re-initializes if API key has changed (e.g., after login)
  void _ensureInitialized() {
    final apiKey = appConfig.qwenApiKey;

    // Check if API key changed (e.g., after user login)
    if (_initialized && _lastApiKey == apiKey) {
      return;
    }

    if (apiKey.isEmpty) {
      _logger.warning('Qwen API key not configured - please login first');
    } else {
      _logger.info('Qwen API key available: ${apiKey.substring(0, 8)}...');
    }

    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    ));
    _lastApiKey = apiKey;
    _initialized = true;
    _logger.info('QwenService initialized/reinitialized');
  }

  /// Force reinitialize with new API key (call after login)
  void reinitialize() {
    final apiKey = appConfig.qwenApiKey;
    _logger.info('QwenService.reinitialize() called, apiKey=${apiKey.isNotEmpty ? "[SET:${apiKey.substring(0, 8)}...]" : "[EMPTY]"}');
    _initialized = false;
    _lastApiKey = null;
    _ensureInitialized();
  }

  /// 图片识别 - 识别小票/收据
  /// 使用 qwen-vl-plus 视觉模型
  Future<QwenRecognitionResult> recognizeReceipt(File imageFile) async {
    _ensureInitialized();

    // Check if API key is available
    if (appConfig.qwenApiKey.isEmpty) {
      _logger.error('Qwen API key is empty');
      return QwenRecognitionResult.error('图片识别服务未配置，请先登录账号');
    }

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
          'model': _models.visionModel,
          'input': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'image': 'data:$mimeType;base64,$base64Image',
                  },
                  {
                    'text': '''请仔细分析这张小票/收据图片，综合商户名称、商品明细、支付方式等信息，准确提取记账信息。

【分类规则 - 请严格按照以下规则分类】

支出分类：
- food(餐饮): 餐厅、外卖、咖啡店、奶茶店、快餐、便利店食品、超市食品、水果店、面包店、火锅、烧烤、小吃
  常见商户：美团外卖、饿了么、麦当劳、肯德基、星巴克、瑞幸、喜茶、奈雪、盒马、永辉、沃尔玛（食品类）
- transport(交通): 打车、地铁、公交、加油、停车费、过路费、高铁、火车票、机票、共享单车、网约车
  常见商户：滴滴出行、高德打车、T3出行、中国石化、中国石油、铁路12306、航空公司、美团单车、哈啰出行
- shopping(购物): 服装、鞋包、电子产品、日用品、化妆品、家居用品、网购商品
  常见商户：淘宝、天猫、京东、拼多多、唯品会、优衣库、ZARA、苹果商店、小米、华为
- entertainment(娱乐): 电影、游戏充值、KTV、景点门票、演出、健身、运动、会员订阅
  常见商户：猫眼电影、淘票票、腾讯游戏、网易游戏、爱奇艺、腾讯视频、优酷、Keep、各景区
- housing(住房): 房租、水费、电费、燃气费、物业费、网费、宽带、装修、家具、家电
  常见商户：物业公司、水务公司、电力公司、燃气公司、中国移动/联通/电信、京东家电
- medical(医疗): 挂号费、药品、体检、医疗器械、牙科、眼科
  常见商户：医院、药店（大参林、益丰、老百姓）、美年大健康、爱康国宾
- education(教育): 学费、培训费、书籍、文具、课程、考试费
  常见商户：培训机构、书店、学校、网课平台

收入分类：
- salary(工资): 月薪、工资收入
- bonus(奖金): 年终奖、绩效奖金、提成
- parttime(兼职): 兼职收入、副业收入
- investment(投资收益): 理财收益、股票分红、利息

请返回JSON格式：
{
  "amount": 金额数字,
  "merchant": "商户名称",
  "category": "分类ID（如food/transport/shopping等）",
  "type": "expense或income",
  "date": "YYYY-MM-DD或null",
  "items": [{"name": "商品名", "price": 价格}],
  "description": "一句话描述"
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
          'model': _models.textModel,
          'input': {
            'messages': [
              {
                'role': 'system',
                'content': '''你是一个智能记账助手。根据用户描述的消费或收入，综合分析商户、商品、场景等信息，准确分类。

【分类规则 - 请严格按照以下规则分类】

支出分类（使用英文ID）：
- food: 餐饮相关（吃饭、外卖、咖啡、奶茶、水果、零食、超市买菜、便利店食品）
- transport: 交通出行（打车、地铁、公交、加油、停车、高铁、机票、共享单车）
- shopping: 购物消费（买衣服、日用品、电子产品、化妆品、网购）
- entertainment: 娱乐休闲（电影、游戏、KTV、旅游、景点、健身、视频会员）
- housing: 住房相关（房租、水电燃气、物业费、网费、家具家电）
- medical: 医疗健康（看病、买药、体检、牙科）
- education: 教育学习（学费、培训、买书、课程）
- other: 其他支出（无法归类的支出）

收入分类（使用英文ID）：
- salary: 工资收入
- bonus: 奖金（年终奖、绩效、提成）
- parttime: 兼职副业
- investment: 投资理财收益
- other: 其他收入

【关键词示例】
- 打车/滴滴/出租车/高德 → transport
- 午饭/晚饭/外卖/美团/饿了么/咖啡/奶茶 → food
- 淘宝/京东/买了/购买 → shopping（除非是食品）
- 电影/游戏/充值/会员 → entertainment
- 房租/水电/物业 → housing
- 医院/药/体检 → medical
- 工资/薪水/到账 → salary (income)

请返回JSON：
{
  "amount": 金额数字,
  "type": "expense"或"income",
  "category": "分类ID",
  "description": "简短描述",
  "date": "YYYY-MM-DD或null"
}

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
  /// 使用 qwen-omni-turbo 全模态模型（支持音频理解）
  ///
  /// 注意: qwen-audio-turbo 为体验版本，免费额度用完后不可用
  /// 推荐使用 qwen-omni-turbo 作为生产级替代方案
  Future<QwenRecognitionResult> recognizeAudio(Uint8List audioData,
      {String format = 'wav'}) async {
    _ensureInitialized();

    // Check if API key is available
    if (appConfig.qwenApiKey.isEmpty) {
      _logger.error('Qwen API key is empty');
      return QwenRecognitionResult.error('语音识别服务未配置，请先登录账号');
    }

    _logger.info('Recognizing audio: ${audioData.length} bytes, format: $format');

    try {
      // 将音频数据转为Base64
      final base64Audio = base64Encode(audioData);

      final response = await _dio.post(
        _audioApiUrl,
        data: {
          'model': _models.audioModel,  // 使用全模态模型，支持音频理解
          'input': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'audio': 'data:audio/$format;base64,$base64Audio',
                  },
                  {
                    'text': '''请仔细听这段语音，准确转写并提取记账信息。

【分类规则 - 请根据语音内容准确分类】

支出分类（使用英文ID）：
- food: 吃饭、外卖、咖啡、奶茶、水果、零食、买菜、餐厅
- transport: 打车、滴滴、地铁、公交、加油、停车、高铁、机票
- shopping: 买东西、购物、淘宝、京东、衣服、日用品
- entertainment: 电影、游戏、KTV、旅游、景点、健身、会员
- housing: 房租、水电、物业、网费、家具
- medical: 看病、买药、体检、医院
- education: 学费、培训、买书、课程
- other: 其他支出

收入分类（使用英文ID）：
- salary: 工资、薪水
- bonus: 奖金、年终奖、提成
- parttime: 兼职、副业
- investment: 理财、利息、分红
- other: 其他收入

【常见表达对应分类】
- "打车花了XX" → transport
- "吃饭/午饭/晚饭花了XX" → food
- "买了XX东西" → shopping
- "看电影/充游戏" → entertainment
- "交房租/水电费" → housing
- "发工资了" → salary (income)

请返回JSON：
{
  "transcription": "语音转写文字",
  "amount": 金额数字,
  "type": "expense"或"income",
  "category": "分类ID",
  "description": "简短描述"
}

重要：金额必须是准确的数字。只返回JSON。'''
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

  /// 音频识别记账 - 支持多笔交易
  /// 一次语音输入可以识别多笔消费/收入
  Future<MultiRecognitionResult> recognizeAudioMulti(Uint8List audioData,
      {String format = 'wav'}) async {
    _ensureInitialized();

    // Check if API key is available
    if (appConfig.qwenApiKey.isEmpty) {
      _logger.error('Qwen API key is empty');
      return MultiRecognitionResult.error('语音识别服务未配置，请先登录账号');
    }

    _logger.info('Recognizing audio (multi): ${audioData.length} bytes, format: $format');

    try {
      // 将音频数据转为Base64
      final base64Audio = base64Encode(audioData);

      final response = await _dio.post(
        _audioApiUrl,
        data: {
          'model': _models.audioModel,
          'input': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'audio': 'data:audio/$format;base64,$base64Audio',
                  },
                  {
                    'text': '''请仔细听这段语音，识别其中提到的所有消费或收入记录。
用户可能在一段语音中提到多笔交易，请全部提取出来。

【分类规则 - 请根据语音内容准确分类】

支出分类（使用英文ID）：
- food: 吃饭、外卖、咖啡、奶茶、水果、零食、买菜、餐厅
- transport: 打车、滴滴、地铁、公交、加油、停车、高铁、机票
- shopping: 买东西、购物、淘宝、京东、衣服、日用品
- entertainment: 电影、游戏、KTV、旅游、景点、健身、会员
- housing: 房租、水电、物业、网费、家具
- medical: 看病、买药、体检、医院
- education: 学费、培训、买书、课程
- other: 其他支出

收入分类（使用英文ID）：
- salary: 工资、薪水
- bonus: 奖金、年终奖、提成
- parttime: 兼职、副业
- investment: 理财、利息、分红
- other: 其他收入

请返回JSON格式（注意是数组，即使只有一笔也返回数组）：
{
  "transcription": "完整的语音转写文字",
  "transactions": [
    {"type": "expense", "amount": 15.0, "category": "food", "description": "咖啡"},
    {"type": "expense", "amount": 35.0, "category": "food", "description": "午餐"}
  ]
}

重要：
1. 金额必须是准确的数字
2. 每笔交易单独列出
3. 只返回JSON，不要其他文字'''
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

      return _parseAudioMultiResponse(response.data);
    } on DioException catch (e) {
      _logger.error('Audio recognition (multi) failed', error: e);
      return MultiRecognitionResult.error(_handleDioError(e));
    } catch (e, stack) {
      _logger.error('Audio recognition (multi) failed', error: e, stack: stack);
      return MultiRecognitionResult.error('音频识别失败: $e');
    }
  }

  /// 解析多笔交易音频响应
  MultiRecognitionResult _parseAudioMultiResponse(Map<String, dynamic> response) {
    try {
      _logger.debug('Audio API response (multi): $response');

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

          _logger.info('Audio response text (multi): $textContent');

          if (textContent.isNotEmpty) {
            return _extractMultiJsonResult(textContent);
          }
        }
      }
      return MultiRecognitionResult.error('无法解析音频响应');
    } catch (e) {
      _logger.error('Parse audio response (multi) failed', error: e);
      return MultiRecognitionResult.error('解析音频响应失败: $e');
    }
  }

  /// 从响应中提取多笔交易
  MultiRecognitionResult _extractMultiJsonResult(String content) {
    try {
      final jsonStr = _extractJsonString(content);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr);

        // 检查转写内容
        final transcription = data['transcription'] as String?;

        // 如果有 transactions 数组
        if (data['transactions'] != null && data['transactions'] is List) {
          final txList = data['transactions'] as List;

          if (txList.isEmpty) {
            // 没有识别到交易，可能是麦克风问题
            if (transcription == null || transcription.isEmpty) {
              return MultiRecognitionResult.error('未检测到语音内容，请确保麦克风正常工作并清晰说话');
            }
            return MultiRecognitionResult.error('未能从语音中识别出交易信息，请重试');
          }

          final results = <QwenRecognitionResult>[];
          for (var tx in txList) {
            results.add(QwenRecognitionResult(
              amount: (tx['amount'] as num?)?.toDouble(),
              category: tx['category'] as String?,
              description: tx['description'] as String?,
              type: tx['type'] as String? ?? 'expense',
              date: tx['date'] as String?,
              success: true,
              confidence: 0.9,
            ));
          }

          _logger.info('Parsed ${results.length} transactions from audio');
          return MultiRecognitionResult(transactions: results);
        }

        // 兼容旧格式（单笔交易）
        if (data['amount'] != null) {
          final result = QwenRecognitionResult(
            amount: (data['amount'] as num?)?.toDouble(),
            category: data['category'] as String?,
            description: data['description'] as String? ?? transcription,
            type: data['type'] as String? ?? 'expense',
            success: true,
            confidence: 0.9,
          );
          return MultiRecognitionResult.single(result);
        }

        return MultiRecognitionResult.error('无法识别交易信息');
      }

      // JSON提取失败，尝试从纯文本提取
      final fallbackResult = _extractFromPlainText(content);
      return MultiRecognitionResult.single(fallbackResult);
    } catch (e) {
      _logger.error('Extract multi JSON failed', error: e);
      return MultiRecognitionResult.error('JSON解析失败: $e');
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
          'model': _models.categoryModel,
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
          'model': _models.billModel,
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
      _logger.debug('Audio API response: $response');

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

          _logger.info('Audio response text: $textContent');

          if (textContent.isNotEmpty) {
            // 先尝试 JSON 解析
            final jsonResult = _extractAudioJsonResult(textContent);

            // 如果 JSON 解析返回了明确的错误（如空转写），直接返回该错误
            if (!jsonResult.success) {
              return jsonResult;
            }

            // JSON 解析成功且有金额，返回结果
            if (jsonResult.amount != null) {
              return jsonResult;
            }

            // JSON 解析成功但无金额，尝试从文本中提取信息
            return _extractFromPlainText(textContent);
          }
        }
      }
      return QwenRecognitionResult.error('无法解析音频响应');
    } catch (e) {
      _logger.error('Parse audio response failed', error: e);
      return QwenRecognitionResult.error('解析音频响应失败: $e');
    }
  }

  /// 从纯文本中提取记账信息（当模型没有返回 JSON 时的备用方案）
  QwenRecognitionResult _extractFromPlainText(String text) {
    _logger.info('Trying to extract from plain text: $text');

    // 提取金额 - 匹配各种金额格式
    double? amount;
    final amountPatterns = [
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*[元块]'),  // 35元, 35.5块
      RegExp(r'[¥￥]\s*(\d+(?:\.\d{1,2})?)'),    // ¥35, ￥35.5
      RegExp(r'金额[是为：:]\s*(\d+(?:\.\d{1,2})?)'),  // 金额是35
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:块钱|人民币)'),  // 35块钱
      RegExp(r'花了?\s*(\d+(?:\.\d{1,2})?)'),   // 花了35
      RegExp(r'(\d+(?:\.\d{1,2})?)'),           // 最后尝试匹配任意数字
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!);
        if (parsed != null && parsed > 0) {
          amount = parsed;
          break;
        }
      }
    }

    // 判断收入/支出
    String type = 'expense';
    if (text.contains(RegExp(r'收入|工资|奖金|收到|进账|到账|薪水|月薪|发工资'))) {
      type = 'income';
    }

    // 提取分类 - 使用英文ID，按优先级排序（更具体的在前）
    String category = 'other';

    // 收入分类优先判断
    if (type == 'income') {
      final incomePatterns = {
        'salary': RegExp(r'工资|薪水|月薪|薪资|发工资'),
        'bonus': RegExp(r'奖金|年终奖|提成|年终|绩效'),
        'parttime': RegExp(r'兼职|副业|外快'),
        'investment': RegExp(r'理财|投资|收益|利息|分红|股票|基金'),
      };
      for (final entry in incomePatterns.entries) {
        if (entry.value.hasMatch(text)) {
          category = entry.key;
          break;
        }
      }
    } else {
      // 支出分类 - 按优先级排序
      final expensePatterns = [
        // 交通（优先级高，避免被其他分类误判）
        MapEntry('transport', RegExp(r'打车|滴滴|出租车|高德打车|T3出行|曹操出行|地铁|公交|加油|中国石[化油]|停车|高铁|火车票|12306|机票|飞机|共享单车|哈啰|美团单车|青桔|车费|路费|过路费')),
        // 餐饮（常见商户和关键词）
        MapEntry('food', RegExp(r'餐饮|吃饭|午饭|晚饭|早饭|午餐|晚餐|早餐|夜宵|外卖|美团外卖|饿了么|咖啡|星巴克|瑞幸|奶茶|喜茶|奈雪|蜜雪|麦当劳|肯德基|必胜客|海底捞|火锅|烧烤|小吃|面包|蛋糕|水果|零食|超市食品|盒马|永辉|沃尔玛|便利店|全家|711|罗森')),
        // 购物
        MapEntry('shopping', RegExp(r'购物|淘宝|天猫|京东|拼多多|唯品会|网购|买衣服|买鞋|买包|优衣库|ZARA|HM|苹果|小米|华为|电子产品|日用品|化妆品|护肤品')),
        // 娱乐
        MapEntry('entertainment', RegExp(r'娱乐|电影|猫眼|淘票票|游戏|充值|腾讯游戏|网易游戏|王者|吃鸡|KTV|唱歌|旅游|景点|门票|演出|演唱会|健身|Keep|会员|爱奇艺|腾讯视频|优酷|B站|Netflix')),
        // 住房
        MapEntry('housing', RegExp(r'住房|房租|租金|水费|电费|燃气|物业费|网费|宽带|中国移动|中国联通|中国电信|装修|家具|家电|京东家电|苏宁')),
        // 医疗
        MapEntry('medical', RegExp(r'医疗|医院|挂号|药|药店|大参林|益丰|老百姓|看病|体检|美年|爱康|牙科|眼科|门诊')),
        // 教育
        MapEntry('education', RegExp(r'教育|学费|培训|书|课程|考试|补习|网课|学习')),
      ];

      for (final entry in expensePatterns) {
        if (entry.value.hasMatch(text)) {
          category = entry.key;
          break;
        }
      }
    }

    if (amount != null) {
      return QwenRecognitionResult(
        amount: amount,
        category: category,
        description: text.length > 50 ? text.substring(0, 50) : text,
        type: type,
        success: true,
        confidence: 0.7,  // 纯文本提取置信度较低
      );
    }

    // 无法提取金额，返回错误
    return QwenRecognitionResult.error('无法从语音中识别金额，请重试或手动输入');
  }

  QwenRecognitionResult _extractAudioJsonResult(String content) {
    try {
      final jsonStr = _extractJsonString(content);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr);

        // 检查转写内容是否为空（可能是麦克风问题或静音）
        final transcription = data['transcription'] as String?;
        final description = data['description'] as String?;
        final amount = (data['amount'] as num?)?.toDouble();

        // 如果转写为空且没有金额，说明可能是麦克风问题
        if ((transcription == null || transcription.isEmpty) &&
            (description == null || description.isEmpty) &&
            amount == null) {
          _logger.warning('Audio transcription is empty - possible microphone issue');
          return QwenRecognitionResult.error('未检测到语音内容，请确保麦克风正常工作并清晰说话');
        }

        return QwenRecognitionResult(
          amount: amount,
          category: data['category'] as String?,
          description: description ?? transcription,
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

/// 多笔交易识别结果
class MultiRecognitionResult {
  final List<QwenRecognitionResult> transactions;
  final bool success;
  final String? errorMessage;

  MultiRecognitionResult({
    required this.transactions,
    this.success = true,
    this.errorMessage,
  });

  /// 是否包含多笔交易
  bool get isMultiple => transactions.length > 1;

  /// 交易数量
  int get count => transactions.length;

  /// 总金额
  double get totalAmount => transactions.fold(
        0.0,
        (sum, tx) => sum + (tx.amount ?? 0),
      );

  factory MultiRecognitionResult.error(String message) {
    return MultiRecognitionResult(
      transactions: [],
      success: false,
      errorMessage: message,
    );
  }

  factory MultiRecognitionResult.single(QwenRecognitionResult result) {
    return MultiRecognitionResult(
      transactions: [result],
      success: result.success,
      errorMessage: result.errorMessage,
    );
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
