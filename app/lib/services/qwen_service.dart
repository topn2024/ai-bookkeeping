import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config.dart';
import '../core/config/config.dart';
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

  // API端点 - 使用集中化配置
  static String get _textApiUrl => ApiEndpoints.qwenTextApi;
  static String get _visionApiUrl => ApiEndpoints.qwenVisionApi;
  static String get _audioApiUrl => ApiEndpoints.qwenAudioApi;

  /// 二级分类提示词 - 用于 AI 精确分类
  static const String _categoryPrompt = '''
【分类规则 - 请返回最精确的分类ID】

支出分类（优先返回二级分类ID，无法确定时返回一级分类ID）：

food(餐饮) - 用于无法确定具体餐饮类型时
  - food_breakfast: 早餐（早点、早饭、包子、豆浆、油条）
  - food_lunch: 午餐（午饭、工作餐、午间、中餐）
  - food_dinner: 晚餐（晚饭、晚餐、夜宵、宵夜）
  - food_snack: 零食（零食、小吃、糖果、薯片、饼干）
  - food_drink: 饮料（咖啡、奶茶、饮料、星巴克、瑞幸、喜茶、奈雪、茶）
  - food_delivery: 外卖（美团外卖、饿了么、外卖）
  - food_fruit: 水果（水果、苹果、香蕉、橙子）

transport(交通) - 用于无法确定具体交通类型时
  - transport_taxi: 打车（滴滴、出租车、网约车、打的、快车、专车）
  - transport_public: 公共交通（地铁、公交、公交卡、地铁卡）
  - transport_fuel: 加油（加油、加油站、中国石化、中国石油、汽油）
  - transport_parking: 停车（停车费、停车场）
  - transport_train: 火车（火车票、高铁、动车、12306）
  - transport_flight: 飞机（机票、飞机票、航班）
  - transport_ship: 轮船（船票、轮渡）

shopping(购物) - 用于无法确定具体购物类型时
  - shopping_daily: 日用品（牙膏、洗发水、纸巾、日用、超市日用）
  - shopping_digital: 数码产品（手机、电脑、数码、电子产品、耳机）
  - shopping_appliance: 家电（冰箱、洗衣机、空调、电视、家电）
  - shopping_furniture: 家居（家具、床、沙发、桌子、椅子）
  - shopping_gift: 礼物（礼物、礼品、送人）

entertainment(娱乐) - 用于无法确定具体娱乐类型时
  - entertainment_movie: 电影（电影票、看电影、影院）
  - entertainment_game: 游戏（游戏充值、游戏、网游）
  - entertainment_travel: 旅游（旅游、景点、门票、酒店住宿）
  - entertainment_sport: 运动（运动、球场、球馆）
  - entertainment_ktv: KTV（KTV、唱歌、卡拉OK）
  - entertainment_party: 聚会（聚会、派对）
  - entertainment_fitness: 健身（健身、健身房、游泳、瑜伽）

housing(居住) - 用于无法确定具体居住类型时
  - housing_rent: 房租（房租、租金、月租）
  - housing_mortgage: 房贷（房贷、按揭、还贷）
  - housing_property: 物业费（物业、物业费）
  - housing_repair: 维修（维修、修理、装修）

utilities(水电燃气) - 用于无法确定具体类型时
  - utilities_electric: 电费（电费、充电费）
  - utilities_water: 水费（水费）
  - utilities_gas: 燃气费（燃气、天然气、煤气）
  - utilities_heating: 暖气费（暖气、供暖）

medical(医疗) - 用于无法确定具体医疗类型时
  - medical_clinic: 门诊（挂号、看病、门诊）
  - medical_medicine: 药品（买药、药店、药品）
  - medical_hospital: 住院（住院）
  - medical_checkup: 体检（体检、健康检查）
  - medical_supplement: 保健品（保健品、维生素）

education(教育) - 用于无法确定具体教育类型时
  - education_tuition: 学费（学费、报名费）
  - education_books: 书籍（买书、书籍、图书）
  - education_training: 培训（培训、课程、网课）
  - education_exam: 考试（考试、报名）

communication(通讯)
  - communication_phone: 话费（话费、充值、手机费）
  - communication_internet: 网费（网费、宽带）

clothing(服饰) - 用于无法确定具体类型时
  - clothing_clothes: 衣服（衣服、上衣、裤子、外套）
  - clothing_shoes: 鞋子（鞋子、运动鞋、皮鞋）
  - clothing_accessories: 配饰（配饰、手表、项链、包）

beauty(美容) - 用于无法确定具体类型时
  - beauty_skincare: 护肤（护肤品、面膜、水乳）
  - beauty_cosmetics: 化妆品（化妆品、口红、粉底）
  - beauty_haircut: 美发（理发、美发、剪头发）
  - beauty_nails: 美甲（美甲、指甲）

subscription(会员订阅)
  - subscription_video: 视频会员（爱奇艺、腾讯视频、优酷、B站、Netflix）
  - subscription_music: 音乐会员（网易云、QQ音乐、Spotify）
  - subscription_cloud: 网盘会员（百度网盘、iCloud）
  - subscription_shopping: 购物会员（88VIP、京东Plus）

social(人情往来) - 用于无法确定具体类型时
  - social_gift_money: 份子钱（份子钱、随份子、红包钱）
  - social_festival: 节日送礼（送礼、过节）
  - social_treat: 请客吃饭（请客、请吃饭）
  - social_redpacket: 红包支出（发红包）
  - social_elder: 孝敬长辈（给父母、孝敬）

finance(金融保险) - 用于无法确定具体类型时
  - finance_life_insurance: 人寿保险（人寿、寿险）
  - finance_medical_insurance: 医疗保险（医保、医疗险）
  - finance_car_insurance: 车险（车险、交强险）
  - finance_fee: 手续费（手续费、转账费）
  - finance_loan_interest: 贷款利息（利息、贷款利息）

pet(宠物)
  - pet_food: 宠物食品（猫粮、狗粮、宠物食品）
  - pet_supplies: 宠物用品（猫砂、宠物玩具）
  - pet_medical: 宠物医疗（宠物医院、宠物看病）

other_expense: 其他支出（无法归类的支出）

收入分类（优先返回二级分类ID）：

salary(工资) - 用于无法确定具体类型时
  - salary_base: 基本工资（工资、月薪、薪资）
  - salary_performance: 绩效奖金（绩效、绩效奖）
  - salary_overtime: 加班费（加班费、加班工资）
  - salary_annual: 年终奖（年终奖、十三薪）

bonus(奖金) - 用于无法确定具体类型时
  - bonus_project: 项目奖金（项目奖、完成奖）
  - bonus_quarterly: 季度奖（季度奖）

investment(投资收益): 投资收益（理财、利息、分红、股票收益）
parttime(兼职): 兼职（兼职、副业、外快）
redpacket(红包): 收到红包（收红包、微信红包）
reimburse(报销): 报销（报销、公司报销）
business(经营所得): 经营收入（生意、店铺、营业）
other_income: 其他收入（无法归类的收入）
''';

  late Dio _dio;
  bool _initialized = false;
  String? _lastApiKey;

  factory QwenService() => _instance;

  QwenService._internal();

  /// 检查LLM服务是否可用（已配置API Key）
  bool get isAvailable => appConfig.qwenApiKey.isNotEmpty;

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

  /// 预热连接（提前建立HTTP连接，减少首次调用延迟）
  ///
  /// 通过发送一个最小化的健康检查请求来预热：
  /// - 初始化Dio客户端
  /// - 建立TCP/SSL连接
  /// - 验证API Key有效性
  ///
  /// 建议在应用启动时调用，可节省300-800ms首次延迟
  /// 返回: true表示预热成功且LLM可用，false表示预热失败或LLM不可用
  Future<bool> warmup() async {
    if (!isAvailable) {
      _logger.info('QwenService: 预热跳过（API Key未配置）');
      return false;
    }

    final startTime = DateTime.now();
    _logger.info('QwenService: 开始预热连接...');

    try {
      _ensureInitialized();

      // 发送一个最小化请求来预热连接
      // 使用 qwen-turbo（最快最轻量的模型）
      final response = await _dio.post(
        _textApiUrl,
        data: {
          'model': 'qwen-turbo',  // 预热使用最轻量的模型
          'input': {
            'messages': [
              {'role': 'user', 'content': 'hi'},
            ],
          },
          'parameters': {
            'max_tokens': 1,  // 最小输出
          },
        },
      );

      final elapsed = DateTime.now().difference(startTime);
      if (response.statusCode == 200) {
        _logger.info('QwenService: 预热成功 (${elapsed.inMilliseconds}ms)');
        return true;
      } else {
        _logger.warning('QwenService: 预热响应异常: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime);
      _logger.warning('QwenService: 预热失败 (${elapsed.inMilliseconds}ms): $e');
      return false;
    }
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

$_categoryPrompt

请返回JSON格式：
{
  "amount": 金额数字,
  "merchant": "商户名称",
  "category": "最精确的分类ID（优先使用二级分类如food_lunch，无法确定时使用一级分类如food）",
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

  /// 批量图片识别 - 识别长图中的多条交易记录
  /// 适用于账单截图、银行流水、支付记录等包含多条交易的长图
  Future<List<QwenRecognitionResult>> recognizeReceiptBatch(File imageFile) async {
    _ensureInitialized();

    if (appConfig.qwenApiKey.isEmpty) {
      _logger.error('Qwen API key is empty');
      return [QwenRecognitionResult.error('图片识别服务未配置，请先登录账号')];
    }

    _logger.info('Batch recognizing receipt: ${imageFile.path}');

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      _logger.debug('Image size: ${bytes.length} bytes');

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
                    'text': '''请分析这张图片，这可能是一张包含多条交易记录的长图（如账单截图、银行流水、支付记录等）。

请识别图片中的所有交易记录，对每条交易提取：
1. 消费金额（数字）
2. 商户名称或交易描述
3. 消费类型
4. 交易日期和时间
5. 交易类型（支出/收入）

$_categoryPrompt

请以JSON数组格式返回所有交易：
{
  "transactions": [
    {
      "amount": 金额数字,
      "merchant": "商户名称或描述",
      "category": "分类ID",
      "date": "YYYY-MM-DD",
      "type": "expense或income",
      "description": "备注说明"
    },
    ...
  ],
  "total_count": 交易总数
}

注意：
- 如果只有一条交易，也返回数组格式
- 按时间顺序排列（最新的在前）
- 如果某项无法识别，设为null
- 忽略余额、总计等非交易信息

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

      return _parseBatchVisionResponse(response.data);
    } on DioException catch (e) {
      _logger.error('Batch receipt recognition failed', error: e);
      return [QwenRecognitionResult.error(_handleDioError(e))];
    } catch (e, stack) {
      _logger.error('Batch receipt recognition failed', error: e, stack: stack);
      return [QwenRecognitionResult.error('批量图片识别失败: $e')];
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

$_categoryPrompt

请返回JSON：
{
  "amount": 金额数字,
  "type": "expense"或"income",
  "category": "最精确的分类ID（优先使用二级分类如food_lunch，无法确定时使用一级分类如food）",
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
  /// 默认使用 qwen-audio-turbo（专业音频模型，识别准确度最高）
  ///
  /// 备选方案: qwen-omni-turbo（全模态模型，稳定性更好）
  /// 可通过配置切换模型
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

$_categoryPrompt

【日期识别规则】
- "今天" → 返回今天的日期
- "昨天" → 返回昨天的日期
- "前天" → 返回前天的日期
- "上周X/上个星期X" → 返回对应日期
- 具体日期如"12月30日"、"1号" → 返回对应日期
- 如果没有提及时间，date字段返回null

请返回JSON：
{
  "transcription": "语音转写文字",
  "amount": 金额数字,
  "type": "expense"或"income",
  "category": "最精确的分类ID（优先使用二级分类如food_lunch，无法确定时使用一级分类如food）",
  "description": "简短描述",
  "date": "YYYY-MM-DD格式日期或null"
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

$_categoryPrompt

【日期识别规则】
- "今天" → 返回今天的日期
- "昨天" → 返回昨天的日期
- "前天" → 返回前天的日期
- "上周X/上个星期X" → 返回对应日期
- 具体日期如"12月30日"、"1号" → 返回对应日期
- 如果没有提及时间，date字段返回null

请返回JSON格式（注意是数组，即使只有一笔也返回数组）：
{
  "transcription": "完整的语音转写文字",
  "transactions": [
    {"type": "expense", "amount": 15.0, "category": "food_drink", "description": "咖啡", "date": null},
    {"type": "expense", "amount": 35.0, "category": "food_lunch", "description": "午餐", "date": "2026-01-01"}
  ]
}

重要：
1. 金额必须是准确的数字
2. 每笔交易单独列出
3. 分类请使用最精确的二级分类ID（如food_lunch而不是food）
4. 只返回JSON，不要其他文字'''
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
        final decoded = jsonDecode(jsonStr);

        // 处理返回值可能是 List 的情况
        // AI 可能返回两种格式：
        // 1. {"transcription": "...", "transactions": [{...}, {...}]}
        // 2. [{...}, {...}] 直接返回交易列表
        if (decoded is List) {
          if (decoded.isEmpty) {
            return MultiRecognitionResult.error('返回的JSON数组为空');
          }

          // 检查第一个元素是否包含 transactions（格式1被包在数组里）
          if (decoded[0] is Map && decoded[0]['transactions'] != null) {
            // 格式: [{"transcription": "...", "transactions": [...]}]
            final data = decoded[0] as Map<String, dynamic>;
            return _parseTransactionsFromData(data);
          }

          // 否则整个列表就是交易列表（格式2）
          _logger.info('Detected direct transaction list format');
          final results = <QwenRecognitionResult>[];
          for (var tx in decoded) {
            if (tx is Map) {
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
          }

          if (results.isEmpty) {
            return MultiRecognitionResult.error('JSON数组元素格式错误');
          }

          _logger.info('Parsed ${results.length} transactions from list format');
          return MultiRecognitionResult(transactions: results);
        } else if (decoded is Map<String, dynamic>) {
          return _parseTransactionsFromData(decoded);
        } else {
          return MultiRecognitionResult.error('JSON格式不正确');
        }
      }

      // JSON提取失败，尝试从纯文本提取
      final fallbackResult = _extractFromPlainText(content);
      return MultiRecognitionResult.single(fallbackResult);
    } catch (e) {
      _logger.error('Extract multi JSON failed', error: e);
      return MultiRecognitionResult.error('JSON解析失败: $e');
    }
  }

  /// 从标准格式数据中解析交易
  MultiRecognitionResult _parseTransactionsFromData(Map<String, dynamic> data) {
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
        date: data['date'] as String?,
        success: true,
        confidence: 0.9,
      );
      return MultiRecognitionResult.single(result);
    }

    return MultiRecognitionResult.error('无法识别交易信息');
  }

  /// 智能分类建议
  ///
  /// 使用完整的分类提示词，支持60+细粒度分类
  /// 返回最精确的分类ID（优先二级分类如 food_lunch）
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
                'content': '''你是一个智能记账分类助手。根据用户描述的消费或收入内容，返回最精确的分类ID。

$_categoryPrompt

重要规则：
1. 优先返回二级分类ID（如 food_lunch 而不是 food）
2. 只有在无法确定具体类型时才返回一级分类ID
3. 只返回分类ID，不要返回中文名称，不要其他文字
4. 分类ID必须是上述列表中的一个'''
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
          final category = content.trim().toLowerCase();
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
      _logger.debug('Vision API response: $response');

      if (response['output'] != null && response['output']['choices'] != null) {
        final choices = response['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'];
          var content = message['content'];

          // 视觉模型返回的content可能是数组或字符串
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

          _logger.info('Vision response text: $textContent');

          if (textContent.isNotEmpty) {
            return _extractJsonResult(textContent);
          }
        }
      }
      return QwenRecognitionResult.error('无法解析响应');
    } catch (e) {
      _logger.error('Parse vision response failed', error: e);
      return QwenRecognitionResult.error('解析响应失败: $e');
    }
  }

  List<QwenRecognitionResult> _parseBatchVisionResponse(Map<String, dynamic> response) {
    try {
      _logger.debug('Batch vision API response: $response');

      if (response['output'] != null && response['output']['choices'] != null) {
        final choices = response['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'];
          var content = message['content'];

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

          _logger.info('Batch vision response text: $textContent');

          if (textContent.isNotEmpty) {
            final jsonStr = _extractJsonString(textContent);
            if (jsonStr != null) {
              final decoded = jsonDecode(jsonStr);
              if (decoded is Map && decoded['transactions'] is List) {
                final txList = decoded['transactions'] as List;
                return txList.map((tx) => QwenRecognitionResult(
                  amount: (tx['amount'] as num?)?.toDouble(),
                  merchant: tx['merchant'] as String?,
                  category: tx['category'] as String?,
                  date: tx['date'] as String?,
                  description: tx['description'] as String?,
                  type: tx['type'] as String? ?? 'expense',
                  success: true,
                  confidence: 0.85,
                )).toList();
              }
            }
          }
        }
      }
      return [QwenRecognitionResult.error('无法解析批量识别响应')];
    } catch (e) {
      _logger.error('Parse batch vision response failed', error: e);
      return [QwenRecognitionResult.error('解析批量识别响应失败: $e')];
    }
  }

  QwenRecognitionResult _parseTextResponse(Map<String, dynamic> response) {
    try {
      _logger.debug('Text API response: $response');

      if (response['output'] != null && response['output']['choices'] != null) {
        final choices = response['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'];
          var content = message['content'];

          // 文本模型返回的content可能是字符串或数组
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

          _logger.info('Text response: $textContent');

          if (textContent.isNotEmpty) {
            return _extractJsonResult(textContent);
          }
        }
      }
      return QwenRecognitionResult.error('无法解析响应');
    } catch (e) {
      _logger.error('Parse text response failed', error: e);
      return QwenRecognitionResult.error('解析响应失败: $e');
    }
  }

  List<QwenRecognitionResult> _parseEmailResponse(Map<String, dynamic> response) {
    try {
      _logger.debug('Email API response: $response');

      if (response['output'] != null && response['output']['choices'] != null) {
        final choices = response['output']['choices'] as List;
        if (choices.isNotEmpty) {
          final message = choices[0]['message'];
          var content = message['content'];

          // 邮件解析返回的content可能是字符串或数组
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

          _logger.info('Email response: $textContent');

          // 提取JSON数组
          final jsonStr = _extractJsonString(textContent);
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
      _logger.error('Parse email response failed', error: e);
      return [QwenRecognitionResult.error('解析账单失败: $e')];
    }
  }

  QwenRecognitionResult _extractJsonResult(String content) {
    try {
      // 尝试提取JSON
      final jsonStr = _extractJsonString(content);
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr);

        // 处理返回值可能是 List 的情况（如 [{...}]）
        Map<String, dynamic> data;
        if (decoded is List) {
          if (decoded.isEmpty) {
            return QwenRecognitionResult.error('返回的JSON数组为空');
          }
          if (decoded[0] is! Map) {
            return QwenRecognitionResult.error('JSON数组元素格式错误');
          }
          data = decoded[0] as Map<String, dynamic>;
        } else if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else {
          return QwenRecognitionResult.error('JSON格式不正确');
        }

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
    } catch (e) {
      debugPrint('[QwenService] JSON validation error: $e');
    }
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

  // ignore: unused_element
  String __getAudioMimeType(String extension) {
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
        final decoded = jsonDecode(jsonStr);

        // 处理返回值可能是 List 的情况（如 [{...}]）
        Map<String, dynamic> data;
        if (decoded is List) {
          if (decoded.isEmpty) {
            return QwenRecognitionResult.error('返回的JSON数组为空');
          }
          if (decoded[0] is! Map) {
            return QwenRecognitionResult.error('JSON数组元素格式错误');
          }
          data = decoded[0] as Map<String, dynamic>;
        } else if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else {
          return QwenRecognitionResult.error('JSON格式不正确');
        }

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
          date: data['date'] as String?,
          success: true,
          confidence: 0.9,
        );
      }
      return QwenRecognitionResult.error('无法提取JSON');
    } catch (e) {
      return QwenRecognitionResult.error('JSON解析失败: $e');
    }
  }

  /// 通用对话接口
  Future<String?> chat(String prompt) async {
    _ensureInitialized();

    if (appConfig.qwenApiKey.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.post(
        _textApiUrl,
        data: {
          'model': _models.textModel,
          'input': {
            'messages': [
              {'role': 'user', 'content': prompt}
            ]
          },
          'parameters': {'result_format': 'message'}
        },
      );

      final content = response.data?['output']?['choices']?[0]?['message']?['content'];
      return content as String?;
    } catch (e) {
      _logger.error('Chat failed', error: e);
      return null;
    }
  }

  /// 快速对话接口（使用 qwen-turbo 模型，响应更快）
  ///
  /// 适用于需要快速响应的场景，如语音意图识别
  /// qwen-turbo 响应时间约 2-3 秒，qwen-max 约 8-12 秒
  Future<String?> chatFast(String prompt) async {
    _ensureInitialized();

    if (appConfig.qwenApiKey.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.post(
        _textApiUrl,
        data: {
          'model': 'qwen-turbo',  // 使用 turbo 模型，速度更快
          'input': {
            'messages': [
              {'role': 'user', 'content': prompt}
            ]
          },
          'parameters': {'result_format': 'message'}
        },
      );

      final content = response.data?['output']?['choices']?[0]?['message']?['content'];
      return content as String?;
    } catch (e) {
      _logger.error('ChatFast failed', error: e);
      return null;
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
        return '网络错误: ${e.message ?? '请稍后重试'}';
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
