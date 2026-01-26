import 'dart:io';
import 'dart:typed_data';
import 'qwen_service.dart';
import '../models/category.dart';

// 拆分后的专注服务（门面模式）
import 'ai/image_recognition_service.dart';
import 'ai/text_parsing_service.dart';
import 'ai/category_suggestion_service.dart';

// 导出拆分的服务，方便直接使用
export 'ai/ai_services.dart';

/// AI识别结果模型
class AIRecognitionResult {
  final double? amount;
  final String? merchant;
  final String? category;
  final String? date;
  final String? description;
  final String? type; // expense/income
  final List<ReceiptItem>? items; // 小票商品列表
  final String? recognizedText; // 语音识别的原始文本
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
    this.recognizedText,
    this.confidence = 0.0,
    this.success = true,
    this.errorMessage,
  });

  factory AIRecognitionResult.fromQwenResult(QwenRecognitionResult qwenResult) {
    return AIRecognitionResult(
      amount: qwenResult.amount,
      merchant: qwenResult.merchant,
      category: _mapCategory(qwenResult.category, qwenResult.type),
      date: qwenResult.date,
      description: qwenResult.description,
      type: qwenResult.type,
      items: qwenResult.items,
      recognizedText: qwenResult.description, // 语音识别的原始文本
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

  /// 分类映射 - 支持多种中文表达方式
  /// [type] 用于确定 'other' 应该映射到 'other_expense' 还是 'other_income'
  static String _mapCategory(String? category, String? type) {
    if (category == null || category.isEmpty) {
      return _getOtherCategory(type);
    }

    // 先尝试精确匹配
    final lowerCategory = category.toLowerCase().trim();
    if (categoryMap.containsKey(category)) {
      return categoryMap[category]!;
    }

    // 如果已经是英文ID，直接返回（处理 other 的特殊情况）
    if (lowerCategory == 'other') {
      return _getOtherCategory(type);
    }
    if (validCategoryIds.contains(lowerCategory)) {
      return lowerCategory;
    }

    // 模糊匹配 - 检查是否包含关键词
    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (category.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return _getOtherCategory(type);
  }

  /// 根据类型返回正确的 "其他" 分类
  static String _getOtherCategory(String? type) {
    if (type == 'income') {
      return 'other_income';
    }
    return 'other_expense';
  }

  /// 有效的分类ID列表（包含一级和二级分类）
  /// 使用 DefaultCategories.allCategoryIds 作为唯一来源
  static Set<String> get validCategoryIds => DefaultCategories.allCategoryIds;

  /// 分类映射表 - 精确匹配（包含所有细粒度分类）
  static const Map<String, String> categoryMap = {
    // ========== 餐饮分类 ==========
    '餐饮': 'food',
    '食品': 'food',
    '饮食': 'food',
    '吃饭': 'food',
    '美食': 'food',
    '早餐': 'food_breakfast',
    '早饭': 'food_breakfast',
    '早点': 'food_breakfast',
    '午餐': 'food_lunch',
    '午饭': 'food_lunch',
    '中餐': 'food_lunch',
    '工作餐': 'food_lunch',
    '晚餐': 'food_dinner',
    '晚饭': 'food_dinner',
    '夜宵': 'food_dinner',
    '宵夜': 'food_dinner',
    '零食': 'food_snack',
    '小吃': 'food_snack',
    '饮料': 'food_drink',
    '饮品': 'food_drink',
    '咖啡': 'food_drink',
    '奶茶': 'food_drink',
    '外卖': 'food_delivery',
    '水果': 'food_fruit',

    // ========== 交通分类 ==========
    '交通': 'transport',
    '出行': 'transport',
    '打车': 'transport_taxi',
    '出租车': 'transport_taxi',
    '网约车': 'transport_taxi',
    '公共交通': 'transport_public',
    '地铁': 'transport_public',
    '公交': 'transport_public',
    '加油': 'transport_fuel',
    '汽油': 'transport_fuel',
    '停车': 'transport_parking',
    '停车费': 'transport_parking',
    '火车': 'transport_train',
    '高铁': 'transport_train',
    '动车': 'transport_train',
    '火车高铁': 'transport_train',
    '飞机': 'transport_flight',
    '机票': 'transport_flight',
    '航班': 'transport_flight',
    '轮船': 'transport_ship',
    '船票': 'transport_ship',

    // ========== 购物分类 ==========
    '购物': 'shopping',
    '网购': 'shopping',
    '日用品': 'shopping_daily',
    '生活用品': 'shopping_daily',
    '数码产品': 'shopping_digital',
    '数码': 'shopping_digital',
    '电子产品': 'shopping_digital',
    '家电': 'shopping_appliance',
    '家具': 'shopping_furniture',
    '家居': 'shopping_furniture',
    '礼物': 'shopping_gift',
    '礼品': 'shopping_gift',

    // ========== 娱乐分类 ==========
    '娱乐': 'entertainment',
    '休闲': 'entertainment',
    '电影': 'entertainment_movie',
    '看电影': 'entertainment_movie',
    '游戏': 'entertainment_game',
    '游戏充值': 'entertainment_game',
    '旅游': 'entertainment_travel',
    '景点': 'entertainment_travel',
    '门票': 'entertainment_travel',
    '运动': 'entertainment_sport',
    'KTV': 'entertainment_ktv',
    '唱歌': 'entertainment_ktv',
    '聚会': 'entertainment_party',
    '健身': 'entertainment_fitness',
    '健身房': 'entertainment_fitness',

    // ========== 居住分类 ==========
    '住房': 'housing',
    '居住': 'housing',
    '房租': 'housing_rent',
    '租金': 'housing_rent',
    '房贷': 'housing_mortgage',
    '按揭': 'housing_mortgage',
    '物业': 'housing_property',
    '物业费': 'housing_property',
    '维修': 'housing_repair',
    '装修': 'housing_repair',

    // ========== 水电燃气 ==========
    '水电燃气': 'utilities',
    '电费': 'utilities_electric',
    '水费': 'utilities_water',
    '燃气费': 'utilities_gas',
    '燃气': 'utilities_gas',
    '天然气': 'utilities_gas',
    '暖气费': 'utilities_heating',
    '暖气': 'utilities_heating',
    '供暖': 'utilities_heating',

    // ========== 医疗分类 ==========
    '医疗': 'medical',
    '健康': 'medical',
    '看病': 'medical',
    '门诊': 'medical_clinic',
    '挂号': 'medical_clinic',
    '药品': 'medical_medicine',
    '买药': 'medical_medicine',
    '住院': 'medical_hospital',
    '体检': 'medical_checkup',
    '健康检查': 'medical_checkup',
    '保健品': 'medical_supplement',

    // ========== 教育分类 ==========
    '教育': 'education',
    '学习': 'education',
    '学费': 'education_tuition',
    '报名费': 'education_tuition',
    '书籍': 'education_books',
    '图书': 'education_books',
    '买书': 'education_books',
    '培训': 'education_training',
    '课程': 'education_training',
    '网课': 'education_training',
    '考试': 'education_exam',

    // ========== 通讯分类 ==========
    '通讯': 'communication',
    '话费': 'communication_phone',
    '手机费': 'communication_phone',
    '充值': 'communication_phone',
    '网费': 'communication_internet',
    '宽带': 'communication_internet',

    // ========== 服饰分类 ==========
    '服饰': 'clothing',
    '衣服': 'clothing_clothes',
    '服装': 'clothing_clothes',
    '鞋子': 'clothing_shoes',
    '鞋': 'clothing_shoes',
    '配饰': 'clothing_accessories',
    '包': 'clothing_accessories',
    '手表': 'clothing_accessories',

    // ========== 美容分类 ==========
    '美容': 'beauty',
    '护肤': 'beauty_skincare',
    '护肤品': 'beauty_skincare',
    '化妆品': 'beauty_cosmetics',
    '口红': 'beauty_cosmetics',
    '理发': 'beauty_haircut',
    '美发': 'beauty_haircut',
    '剪头发': 'beauty_haircut',
    '美甲': 'beauty_nails',

    // ========== 会员订阅 ==========
    '会员订阅': 'subscription',
    '会员': 'subscription',
    '视频会员': 'subscription_video',
    '音乐会员': 'subscription_music',
    '网盘会员': 'subscription_cloud',
    '购物会员': 'subscription_shopping',

    // ========== 人情往来 ==========
    '人情往来': 'social',
    '份子钱': 'social_gift_money',
    '随份子': 'social_gift_money',
    '节日送礼': 'social_festival',
    '送礼': 'social_festival',
    '请客吃饭': 'social_treat',
    '请客': 'social_treat',
    '红包支出': 'social_redpacket',
    '发红包': 'social_redpacket',
    '孝敬长辈': 'social_elder',
    '给父母': 'social_elder',

    // ========== 金融保险 ==========
    '金融保险': 'finance',
    '人寿保险': 'finance_life_insurance',
    '医疗保险': 'finance_medical_insurance',
    '车险': 'finance_car_insurance',
    '手续费': 'finance_fee',
    '转账费': 'finance_fee',
    '贷款利息': 'finance_loan_interest',

    // ========== 宠物 ==========
    '宠物': 'pet',
    '宠物食品': 'pet_food',
    '猫粮': 'pet_food',
    '狗粮': 'pet_food',
    '宠物用品': 'pet_supplies',
    '宠物医疗': 'pet_medical',

    // ========== 其他支出 ==========
    '其他': 'other_expense',
    '其他支出': 'other_expense',

    // ========== 收入分类 ==========
    '工资': 'salary',
    '薪水': 'salary',
    '薪资': 'salary',
    '月薪': 'salary',
    '基本工资': 'salary_base',
    '底薪': 'salary_base',
    '绩效奖金': 'salary_performance',
    '绩效': 'salary_performance',
    '加班费': 'salary_overtime',
    '年终奖': 'salary_annual',
    '十三薪': 'salary_annual',
    '奖金': 'bonus',
    '提成': 'bonus',
    '项目奖金': 'bonus_project',
    '季度奖': 'bonus_quarterly',
    '兼职': 'parttime',
    '副业': 'parttime',
    '外快': 'parttime',
    '投资收益': 'investment',
    '理财': 'investment',
    '投资': 'investment',
    '收益': 'investment',
    '利息': 'investment',
    '分红': 'investment',
    '红包': 'redpacket',
    '收红包': 'redpacket',
    '微信红包': 'redpacket',
    '报销': 'reimburse',
    '公司报销': 'reimburse',
    '经营所得': 'business',
    '生意': 'business',
    '营业收入': 'business',
    '其他收入': 'other_income',
  };

  /// 分类关键词映射 - 用于模糊匹配（包含常见商户名称）
  static const Map<String, List<String>> categoryKeywords = {
    // 餐饮 - 包含各类餐饮商户
    'food': [
      '餐', '饭', '食', '吃', '喝', '咖啡', '奶茶', '外卖', '早餐', '午餐', '晚餐', '夜宵', '零食', '水果',
      '星巴克', '瑞幸', '喜茶', '奈雪', '蜜雪冰城', '茶百道', 'COCO', '一点点',
      '麦当劳', '肯德基', '必胜客', '汉堡王', '德克士', '赛百味',
      '海底捞', '西贝', '外婆家', '绿茶', '太二', '九毛九',
      '美团外卖', '饿了么', '盒马', '永辉', '沃尔玛', '家乐福', '大润发', '物美',
      '便利店', '全家', '711', '罗森', '便利蜂', '美宜佳',
      '面包', '蛋糕', '烘焙', '甜品', '火锅', '烧烤', '小吃', '快餐',
    ],
    // 交通 - 包含各类出行服务
    'transport': [
      '车', '交通', '打车', '出租', '地铁', '公交', '滴滴', '加油', '停车', '高铁', '火车', '飞机', '机票',
      '滴滴出行', '高德打车', 'T3出行', '曹操出行', '首汽约车', '享道出行',
      '哈啰', '美团单车', '青桔', '共享单车', '摩拜',
      '中国石化', '中国石油', '壳牌', '加油站',
      '12306', '铁路', '携程', '去哪儿', '飞猪', '航空',
      '过路费', '高速', 'ETC', '路费', '车费',
    ],
    // 购物 - 包含各类电商和零售
    'shopping': [
      '购', '买', '超市', '商场', '淘宝', '京东', '网购', '衣服', '鞋',
      '天猫', '拼多多', '唯品会', '苏宁', '国美', '当当', '亚马逊',
      '优衣库', 'ZARA', 'HM', 'GAP', '无印良品', 'MUJI',
      '苹果', 'Apple', '小米', '华为', 'OPPO', 'vivo', '三星',
      '化妆品', '护肤', '口红', '香水', '丝芙兰', '屈臣氏',
      '日用品', '生活用品', '家居', '百货',
    ],
    // 娱乐 - 包含各类休闲娱乐
    'entertainment': [
      '娱乐', '电影', '游戏', 'KTV', '唱歌', '旅游', '景点', '门票',
      '猫眼', '淘票票', '万达影城', 'CGV', '金逸',
      '腾讯游戏', '网易游戏', '王者荣耀', '和平精英', '原神',
      '爱奇艺', '腾讯视频', '优酷', 'B站', '芒果TV', 'Netflix', '会员', 'VIP',
      'Keep', '健身', '瑜伽', '游泳', '运动',
      '演唱会', '演出', '话剧', '音乐会', '展览',
      '迪士尼', '环球影城', '欢乐谷', '方特',
    ],
    // 住房 - 包含各类居住相关
    'housing': [
      '房', '租', '水电', '物业', '装修', '家具', '家电',
      '房租', '租金', '押金', '中介费',
      '水费', '电费', '燃气', '煤气', '暖气',
      '物业费', '管理费', '停车位',
      '宽带', '网费', '中国移动', '中国联通', '中国电信',
      '装修', '建材', '红星美凯龙', '居然之家',
      '宜家', '顾家', '全友', '索菲亚',
    ],
    // 医疗 - 包含各类医疗健康
    'medical': [
      '医', '药', '病', '健康', '体检', '牙',
      '医院', '诊所', '门诊', '挂号', '住院',
      '药店', '大参林', '益丰', '老百姓', '海王星辰', '一心堂',
      '美年大健康', '爱康国宾', '慈铭',
      '牙科', '口腔', '眼科', '皮肤科',
      '保健品', '维生素', '钙片',
    ],
    // 教育 - 包含各类学习教育
    'education': [
      '教育', '学', '书', '课', '培训', '考试',
      '学费', '培训费', '补习', '辅导',
      '新东方', '好未来', '学而思', '猿辅导', '作业帮',
      '得到', '知乎', '网课', '慕课', 'Coursera',
      '书店', '当当', '京东图书', '亚马逊图书',
      '文具', '笔记本', '打印',
    ],
    // 收入分类
    'salary': ['工资', '薪', '月薪', '底薪', '基本工资'],
    'bonus': ['奖金', '奖', '年终', '提成', '绩效', '分红'],
    'parttime': ['兼职', '副业', '外快', '私单', '接单'],
    'investment': ['理财', '投资', '收益', '利息', '分红', '股票', '基金', '债券', '余额宝', '零钱通'],
  };

  @override
  String toString() {
    return 'AIRecognitionResult(amount: $amount, merchant: $merchant, category: $category, type: $type, confidence: $confidence)';
  }
}

/// 多笔AI识别结果
class MultiAIRecognitionResult {
  final List<AIRecognitionResult> transactions;
  final bool success;
  final String? errorMessage;

  MultiAIRecognitionResult({
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

  /// 第一笔交易（兼容单笔场景）
  AIRecognitionResult? get first => transactions.isNotEmpty ? transactions.first : null;

  factory MultiAIRecognitionResult.error(String message) {
    return MultiAIRecognitionResult(
      transactions: [],
      success: false,
      errorMessage: message,
    );
  }

  factory MultiAIRecognitionResult.single(AIRecognitionResult result) {
    return MultiAIRecognitionResult(
      transactions: [result],
      success: result.success,
      errorMessage: result.errorMessage,
    );
  }

  factory MultiAIRecognitionResult.fromQwenResult(MultiRecognitionResult qwenResult) {
    if (!qwenResult.success) {
      return MultiAIRecognitionResult.error(qwenResult.errorMessage ?? '识别失败');
    }

    final aiResults = qwenResult.transactions.map((tx) {
      return AIRecognitionResult.fromQwenResult(tx);
    }).toList();

    return MultiAIRecognitionResult(
      transactions: aiResults,
      success: true,
    );
  }
}

/// AI服务类（门面模式）
///
/// 使用阿里云通义千问模型进行智能记账
/// 作为统一入口，内部委托给专注的子服务：
/// - [ImageRecognitionService] - 图片识别
/// - [TextParsingService] - 文本/音频解析
/// - [CategorySuggestionService] - 分类建议
///
/// 可以直接使用此门面类，也可以直接使用拆分后的子服务
class AIService {
  static final AIService _instance = AIService._internal();
  final QwenService _qwenService = QwenService();

  // 拆分后的专注服务
  final ImageRecognitionService _imageService = ImageRecognitionService();
  final TextParsingService _textService = TextParsingService();
  final CategorySuggestionService _categoryService = CategorySuggestionService();

  factory AIService() => _instance;

  AIService._internal();

  /// 获取图片识别服务实例
  ImageRecognitionService get imageRecognition => _imageService;

  /// 获取文本解析服务实例
  TextParsingService get textParsing => _textService;

  /// 获取分类建议服务实例
  CategorySuggestionService get categorySuggestion => _categoryService;

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

  /// 批量图片识别记账
  /// 从长截图（如账单列表、银行流水）中识别多笔交易
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

  /// 语音识别记账（文本方式）
  /// 解析语音转文本结果，使用千问模型提取交易信息
  Future<AIRecognitionResult> recognizeVoice(String transcribedText) async {
    return parseText(transcribedText);
  }

  /// 音频直接识别记账
  /// 直接从音频数据中识别记账信息，使用千问音频模型
  Future<AIRecognitionResult> recognizeAudio(Uint8List audioData, {String format = 'wav'}) async {
    try {
      final qwenResult = await _qwenService.recognizeAudio(audioData, format: format);
      return AIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return AIRecognitionResult.error('音频识别失败: $e');
    }
  }

  /// 从音频文件识别记账
  Future<AIRecognitionResult> recognizeAudioFile(File audioFile) async {
    try {
      final qwenResult = await _qwenService.recognizeAudioFile(audioFile);
      return AIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return AIRecognitionResult.error('音频文件识别失败: $e');
    }
  }

  /// 音频识别记账 - 支持多笔交易
  /// 一次语音输入可以识别多笔消费/收入
  Future<MultiAIRecognitionResult> recognizeAudioMulti(Uint8List audioData, {String format = 'wav'}) async {
    try {
      final qwenResult = await _qwenService.recognizeAudioMulti(audioData, format: format);
      return MultiAIRecognitionResult.fromQwenResult(qwenResult);
    } catch (e) {
      return MultiAIRecognitionResult.error('音频识别失败: $e');
    }
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
  /// 如果 AI 返回粗粒度分类，会尝试用本地规则细化
  Future<String?> suggestCategory(String description) async {
    try {
      final category = await _qwenService.suggestCategory(description);
      if (category != null) {
        // AI 现在直接返回分类ID（如 food_lunch），先尝试直接使用
        String mapped = category.toLowerCase().trim();

        // 如果返回的是中文，尝试映射
        if (AIRecognitionResult.categoryMap.containsKey(category)) {
          mapped = AIRecognitionResult.categoryMap[category]!;
        }

        // 处理 'other' 分类，根据描述判断是收入还是支出
        if (mapped == 'other') {
          return isIncomeType(description) ? 'other_income' : 'other_expense';
        }

        // 如果 AI 返回粗粒度分类（一级分类），尝试用本地规则细化
        if (_isCoarseCategory(mapped)) {
          final refined = _refineWithLocal(mapped, description);
          if (refined != null) {
            return refined;
          }
        }

        return mapped;
      }
      return localSuggestCategory(description);
    } catch (e) {
      // 如果API失败，回退到本地分类
      return localSuggestCategory(description);
    }
  }

  /// 判断是否是粗粒度的一级分类
  bool _isCoarseCategory(String category) {
    const coarseCategories = {
      'food', 'transport', 'shopping', 'entertainment', 'housing',
      'utilities', 'medical', 'education', 'communication', 'clothing',
      'beauty', 'subscription', 'social', 'finance', 'pet',
      'salary', 'bonus',
    };
    return coarseCategories.contains(category);
  }

  /// 用本地规则将粗粒度分类细化为二级分类
  String? _refineWithLocal(String coarseCategory, String description) {
    final text = description.toLowerCase();

    switch (coarseCategory) {
      case 'food':
        if (_containsAny(text, ['早餐', '早饭', '早点', '包子', '豆浆', '油条'])) return 'food_breakfast';
        if (_containsAny(text, ['午餐', '午饭', '中餐', '工作餐', '午间'])) return 'food_lunch';
        if (_containsAny(text, ['晚餐', '晚饭', '夜宵', '宵夜'])) return 'food_dinner';
        if (_containsAny(text, ['咖啡', '星巴克', '瑞幸', '奶茶', '喜茶', '奈雪', '蜜雪', '茶百道', '饮料', '茶'])) return 'food_drink';
        if (_containsAny(text, ['外卖', '美团外卖', '饿了么'])) return 'food_delivery';
        if (_containsAny(text, ['水果', '苹果', '香蕉', '橙子', '果汁'])) return 'food_fruit';
        if (_containsAny(text, ['零食', '小吃', '糖果', '薯片', '饼干'])) return 'food_snack';
        return 'food';

      case 'transport':
        if (_containsAny(text, ['打车', '滴滴', '出租车', '高德打车', 'T3', '曹操', '首汽', '网约车', '快车', '专车'])) return 'transport_taxi';
        if (_containsAny(text, ['地铁', '公交', '公交卡', '地铁卡', '公共交通'])) return 'transport_public';
        if (_containsAny(text, ['高铁', '火车', '12306', '铁路', '动车'])) return 'transport_train';
        if (_containsAny(text, ['飞机', '机票', '航班', '航空'])) return 'transport_flight';
        if (_containsAny(text, ['加油', '中国石化', '中国石油', '壳牌', '加油站', '汽油'])) return 'transport_fuel';
        if (_containsAny(text, ['停车', '停车费', '停车场'])) return 'transport_parking';
        return 'transport';

      case 'shopping':
        if (_containsAny(text, ['日用品', '牙膏', '洗发水', '纸巾', '生活用品'])) return 'shopping_daily';
        if (_containsAny(text, ['手机', '电脑', '数码', '电子产品', '耳机'])) return 'shopping_digital';
        if (_containsAny(text, ['冰箱', '洗衣机', '空调', '电视', '家电'])) return 'shopping_appliance';
        if (_containsAny(text, ['家具', '床', '沙发', '桌子', '椅子', '宜家'])) return 'shopping_furniture';
        if (_containsAny(text, ['礼物', '礼品', '送人'])) return 'shopping_gift';
        return 'shopping';

      case 'entertainment':
        if (_containsAny(text, ['电影', '猫眼', '淘票票', '影院'])) return 'entertainment_movie';
        if (_containsAny(text, ['游戏', '王者荣耀', '和平精英', '原神'])) return 'entertainment_game';
        if (_containsAny(text, ['旅游', '景点', '门票', '酒店'])) return 'entertainment_travel';
        if (_containsAny(text, ['健身', '健身房', '游泳', '瑜伽', 'Keep'])) return 'entertainment_fitness';
        if (_containsAny(text, ['KTV', 'ktv', '唱歌'])) return 'entertainment_ktv';
        if (_containsAny(text, ['运动', '球场', '球馆'])) return 'entertainment_sport';
        if (_containsAny(text, ['聚会', '派对'])) return 'entertainment_party';
        return 'entertainment';

      case 'housing':
        if (_containsAny(text, ['房租', '租金', '月租'])) return 'housing_rent';
        if (_containsAny(text, ['房贷', '按揭', '还贷'])) return 'housing_mortgage';
        if (_containsAny(text, ['物业', '物业费'])) return 'housing_property';
        if (_containsAny(text, ['维修', '修理', '装修'])) return 'housing_repair';
        return 'housing';

      case 'utilities':
        if (_containsAny(text, ['电费', '充电'])) return 'utilities_electric';
        if (_containsAny(text, ['水费'])) return 'utilities_water';
        if (_containsAny(text, ['燃气', '天然气', '煤气'])) return 'utilities_gas';
        if (_containsAny(text, ['暖气', '供暖'])) return 'utilities_heating';
        return 'utilities';

      case 'medical':
        if (_containsAny(text, ['挂号', '看病', '门诊'])) return 'medical_clinic';
        if (_containsAny(text, ['买药', '药店', '药品'])) return 'medical_medicine';
        if (_containsAny(text, ['体检', '健康检查'])) return 'medical_checkup';
        if (_containsAny(text, ['住院'])) return 'medical_hospital';
        if (_containsAny(text, ['保健品', '维生素'])) return 'medical_supplement';
        return 'medical';

      case 'education':
        if (_containsAny(text, ['学费', '报名费'])) return 'education_tuition';
        if (_containsAny(text, ['买书', '书籍', '图书'])) return 'education_books';
        if (_containsAny(text, ['培训', '课程', '网课'])) return 'education_training';
        if (_containsAny(text, ['考试', '报名'])) return 'education_exam';
        return 'education';

      case 'communication':
        if (_containsAny(text, ['话费', '充值', '手机费'])) return 'communication_phone';
        if (_containsAny(text, ['网费', '宽带'])) return 'communication_internet';
        return 'communication';

      case 'clothing':
        if (_containsAny(text, ['衣服', '上衣', '裤子', '外套'])) return 'clothing_clothes';
        if (_containsAny(text, ['鞋子', '运动鞋', '皮鞋'])) return 'clothing_shoes';
        if (_containsAny(text, ['配饰', '手表', '项链', '包'])) return 'clothing_accessories';
        return 'clothing';

      case 'beauty':
        if (_containsAny(text, ['护肤', '面膜', '水乳'])) return 'beauty_skincare';
        if (_containsAny(text, ['化妆品', '口红', '粉底'])) return 'beauty_cosmetics';
        if (_containsAny(text, ['理发', '美发', '剪头发'])) return 'beauty_haircut';
        if (_containsAny(text, ['美甲', '指甲'])) return 'beauty_nails';
        return 'beauty';

      case 'subscription':
        if (_containsAny(text, ['爱奇艺', '腾讯视频', '优酷', 'B站', 'Netflix', '视频会员'])) return 'subscription_video';
        if (_containsAny(text, ['网易云', 'QQ音乐', 'Spotify', '音乐会员'])) return 'subscription_music';
        if (_containsAny(text, ['百度网盘', 'iCloud', '网盘'])) return 'subscription_cloud';
        if (_containsAny(text, ['88VIP', '京东Plus', '购物会员'])) return 'subscription_shopping';
        return 'subscription';

      case 'social':
        if (_containsAny(text, ['份子钱', '随份子', '红包钱'])) return 'social_gift_money';
        if (_containsAny(text, ['送礼', '过节'])) return 'social_festival';
        if (_containsAny(text, ['请客', '请吃饭'])) return 'social_treat';
        if (_containsAny(text, ['发红包'])) return 'social_redpacket';
        if (_containsAny(text, ['给父母', '孝敬'])) return 'social_elder';
        return 'social';

      case 'finance':
        if (_containsAny(text, ['人寿', '寿险'])) return 'finance_life_insurance';
        if (_containsAny(text, ['医保', '医疗险'])) return 'finance_medical_insurance';
        if (_containsAny(text, ['车险', '交强险'])) return 'finance_car_insurance';
        if (_containsAny(text, ['手续费', '转账费'])) return 'finance_fee';
        if (_containsAny(text, ['利息', '贷款利息'])) return 'finance_loan_interest';
        return 'finance';

      case 'pet':
        if (_containsAny(text, ['猫粮', '狗粮', '宠物食品'])) return 'pet_food';
        if (_containsAny(text, ['猫砂', '宠物玩具', '宠物用品'])) return 'pet_supplies';
        if (_containsAny(text, ['宠物医院', '宠物看病'])) return 'pet_medical';
        return 'pet';

      case 'salary':
        if (_containsAny(text, ['基本工资', '底薪'])) return 'salary_base';
        if (_containsAny(text, ['绩效', '绩效奖'])) return 'salary_performance';
        if (_containsAny(text, ['加班费', '加班工资'])) return 'salary_overtime';
        if (_containsAny(text, ['年终奖', '十三薪'])) return 'salary_annual';
        return 'salary';

      case 'bonus':
        if (_containsAny(text, ['项目奖', '完成奖'])) return 'bonus_project';
        if (_containsAny(text, ['季度奖'])) return 'bonus_quarterly';
        return 'bonus';

      default:
        return null;
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

  /// 通用对话接口
  /// 用于需要AI辅助但不适合其他特定方法的场景
  Future<String> chat(String prompt) async {
    try {
      final result = await _qwenService.chat(prompt);
      return result ?? '';
    } catch (e) {
      return '';
    }
  }

  /// 本地智能分类（离线模式）
  /// 使用关键词匹配进行分类推荐，优先返回二级分类
  String localSuggestCategory(String description) {
    final text = description.toLowerCase();

    // ========== 交通分类（优先级高，避免被其他分类误判）==========
    // 打车
    if (_containsAny(text, ['打车', '滴滴', '出租车', '高德打车', 'T3', '曹操', '首汽', '网约车', '快车', '专车'])) {
      return 'transport_taxi';
    }
    // 公共交通
    if (_containsAny(text, ['地铁', '公交', '公交卡', '地铁卡', '公共交通'])) {
      return 'transport_public';
    }
    // 火车
    if (_containsAny(text, ['高铁', '火车', '12306', '铁路', '动车'])) {
      return 'transport_train';
    }
    // 飞机
    if (_containsAny(text, ['飞机', '机票', '航班', '航空'])) {
      return 'transport_flight';
    }
    // 加油
    if (_containsAny(text, ['加油', '中国石化', '中国石油', '壳牌', '加油站', '汽油'])) {
      return 'transport_fuel';
    }
    // 停车
    if (_containsAny(text, ['停车', '停车费', '停车场'])) {
      return 'transport_parking';
    }
    // 轮船
    if (_containsAny(text, ['船票', '轮渡', '轮船'])) {
      return 'transport_ship';
    }
    // 通用交通
    if (_containsAny(text, ['过路费', 'ETC', '高速', '哈啰', '美团单车', '青桔', '共享单车', '车费', '路费', '交通'])) {
      return 'transport';
    }

    // ========== 餐饮分类 ==========
    // 早餐
    if (_containsAny(text, ['早餐', '早饭', '早点', '包子', '豆浆', '油条'])) {
      return 'food_breakfast';
    }
    // 午餐
    if (_containsAny(text, ['午餐', '午饭', '中餐', '工作餐', '午间'])) {
      return 'food_lunch';
    }
    // 晚餐
    if (_containsAny(text, ['晚餐', '晚饭', '夜宵', '宵夜'])) {
      return 'food_dinner';
    }
    // 饮品
    if (_containsAny(text, ['咖啡', '星巴克', '瑞幸', 'Luckin', '奶茶', '喜茶', '奈雪', '蜜雪', '茶百道', 'COCO', '一点点', '饮料', '茶'])) {
      return 'food_drink';
    }
    // 外卖
    if (_containsAny(text, ['外卖', '美团外卖', '饿了么'])) {
      return 'food_delivery';
    }
    // 水果
    if (_containsAny(text, ['水果', '苹果', '香蕉', '橙子', '果汁'])) {
      return 'food_fruit';
    }
    // 零食
    if (_containsAny(text, ['零食', '小吃', '糖果', '薯片', '饼干'])) {
      return 'food_snack';
    }
    // 通用餐饮
    if (_containsAny(text, ['饭', '菜', '餐', '吃', '喝', '麦当劳', '肯德基', 'KFC', '必胜客', '汉堡王', '德克士',
      '海底捞', '火锅', '烧烤', '快餐', '便当', '面包', '蛋糕', '烘焙', '甜品',
      '盒马', '永辉', '沃尔玛', '便利店', '全家', '711', '罗森', '便利蜂'])) {
      return 'food';
    }

    // ========== 购物分类 ==========
    // 日用品
    if (_containsAny(text, ['日用品', '牙膏', '洗发水', '纸巾', '超市日用', '生活用品'])) {
      return 'shopping_daily';
    }
    // 数码产品
    if (_containsAny(text, ['手机', '电脑', '数码', '电子产品', '耳机', '苹果', 'Apple', '小米', '华为'])) {
      return 'shopping_digital';
    }
    // 家电
    if (_containsAny(text, ['冰箱', '洗衣机', '空调', '电视', '家电'])) {
      return 'shopping_appliance';
    }
    // 家具
    if (_containsAny(text, ['家具', '床', '沙发', '桌子', '椅子', '宜家'])) {
      return 'shopping_furniture';
    }
    // 礼物
    if (_containsAny(text, ['礼物', '礼品', '送人'])) {
      return 'shopping_gift';
    }
    // 通用购物
    if (_containsAny(text, ['淘宝', '天猫', '京东', '拼多多', '唯品会', '苏宁', '国美',
      '超市', '商场', '百货', '购物', '网购', '买'])) {
      return 'shopping';
    }

    // ========== 娱乐分类 ==========
    // 电影
    if (_containsAny(text, ['电影', '猫眼', '淘票票', '万达影城', '影院'])) {
      return 'entertainment_movie';
    }
    // 游戏
    if (_containsAny(text, ['游戏', '充值', '王者', '吃鸡', '原神', '游戏充值'])) {
      return 'entertainment_game';
    }
    // KTV
    if (_containsAny(text, ['KTV', 'ktv', '唱歌', '卡拉OK'])) {
      return 'entertainment_ktv';
    }
    // 旅游
    if (_containsAny(text, ['旅游', '景点', '门票', '酒店', '迪士尼', '环球影城', '欢乐谷'])) {
      return 'entertainment_travel';
    }
    // 健身
    if (_containsAny(text, ['健身', 'Keep', '瑜伽', '游泳', '健身房'])) {
      return 'entertainment_fitness';
    }
    // 运动
    if (_containsAny(text, ['运动', '球场', '球馆'])) {
      return 'entertainment_sport';
    }
    // 聚会
    if (_containsAny(text, ['聚会', '派对'])) {
      return 'entertainment_party';
    }
    // 通用娱乐
    if (_containsAny(text, ['演唱会', '演出', '话剧', '展览', '娱乐', '休闲'])) {
      return 'entertainment';
    }

    // ========== 会员订阅 ==========
    if (_containsAny(text, ['爱奇艺', '腾讯视频', '优酷', 'B站', 'Netflix', '视频会员'])) {
      return 'subscription_video';
    }
    if (_containsAny(text, ['网易云', 'QQ音乐', 'Spotify', '音乐会员'])) {
      return 'subscription_music';
    }
    if (_containsAny(text, ['百度网盘', 'iCloud', '网盘'])) {
      return 'subscription_cloud';
    }
    if (_containsAny(text, ['88VIP', '京东Plus', '购物会员'])) {
      return 'subscription_shopping';
    }
    if (_containsAny(text, ['会员', 'VIP'])) {
      return 'subscription';
    }

    // ========== 居住分类 ==========
    if (_containsAny(text, ['房租', '租金', '月租'])) {
      return 'housing_rent';
    }
    if (_containsAny(text, ['房贷', '按揭', '还贷'])) {
      return 'housing_mortgage';
    }
    if (_containsAny(text, ['物业', '物业费'])) {
      return 'housing_property';
    }
    if (_containsAny(text, ['维修', '修理', '装修'])) {
      return 'housing_repair';
    }
    if (_containsAny(text, ['押金'])) {
      return 'housing';
    }

    // ========== 水电燃气 ==========
    if (_containsAny(text, ['电费', '充电费'])) {
      return 'utilities_electric';
    }
    if (_containsAny(text, ['水费'])) {
      return 'utilities_water';
    }
    if (_containsAny(text, ['燃气', '天然气', '煤气'])) {
      return 'utilities_gas';
    }
    if (_containsAny(text, ['暖气', '供暖'])) {
      return 'utilities_heating';
    }
    if (_containsAny(text, ['水电'])) {
      return 'utilities';
    }

    // ========== 通讯 ==========
    if (_containsAny(text, ['话费', '手机费', '充值'])) {
      return 'communication_phone';
    }
    if (_containsAny(text, ['网费', '宽带', '中国移动', '中国联通', '中国电信'])) {
      return 'communication_internet';
    }

    // ========== 医疗分类 ==========
    if (_containsAny(text, ['挂号', '门诊', '看病'])) {
      return 'medical_clinic';
    }
    if (_containsAny(text, ['药', '药店', '大参林', '益丰', '老百姓', '买药'])) {
      return 'medical_medicine';
    }
    if (_containsAny(text, ['住院'])) {
      return 'medical_hospital';
    }
    if (_containsAny(text, ['体检', '美年', '爱康', '健康检查'])) {
      return 'medical_checkup';
    }
    if (_containsAny(text, ['保健品', '维生素'])) {
      return 'medical_supplement';
    }
    if (_containsAny(text, ['医院', '就医', '治疗', '牙科', '口腔', '眼科', '医疗', '健康'])) {
      return 'medical';
    }

    // ========== 教育分类 ==========
    if (_containsAny(text, ['学费', '报名费'])) {
      return 'education_tuition';
    }
    if (_containsAny(text, ['书', '图书', '书店', '买书'])) {
      return 'education_books';
    }
    if (_containsAny(text, ['培训', '课程', '网课', '新东方', '学而思', '猿辅导', '作业帮'])) {
      return 'education_training';
    }
    if (_containsAny(text, ['考试', '报名'])) {
      return 'education_exam';
    }
    if (_containsAny(text, ['教育', '学习', '补习', '辅导', '文具', '笔记本'])) {
      return 'education';
    }

    // ========== 服饰分类 ==========
    if (_containsAny(text, ['衣服', '上衣', '裤子', '外套', '服装', '优衣库', 'ZARA', 'HM', 'GAP'])) {
      return 'clothing_clothes';
    }
    if (_containsAny(text, ['鞋子', '运动鞋', '皮鞋', '鞋'])) {
      return 'clothing_shoes';
    }
    if (_containsAny(text, ['配饰', '手表', '项链', '包', '帽子'])) {
      return 'clothing_accessories';
    }

    // ========== 美容分类 ==========
    if (_containsAny(text, ['护肤', '面膜', '水乳', '护肤品'])) {
      return 'beauty_skincare';
    }
    if (_containsAny(text, ['化妆品', '口红', '粉底', '丝芙兰', '屈臣氏'])) {
      return 'beauty_cosmetics';
    }
    if (_containsAny(text, ['理发', '美发', '剪头发'])) {
      return 'beauty_haircut';
    }
    if (_containsAny(text, ['美甲', '指甲'])) {
      return 'beauty_nails';
    }

    // ========== 人情往来 ==========
    if (_containsAny(text, ['份子钱', '随份子', '红包钱'])) {
      return 'social_gift_money';
    }
    if (_containsAny(text, ['送礼', '过节'])) {
      return 'social_festival';
    }
    if (_containsAny(text, ['请客', '请吃饭'])) {
      return 'social_treat';
    }
    if (_containsAny(text, ['发红包'])) {
      return 'social_redpacket';
    }
    if (_containsAny(text, ['给父母', '孝敬'])) {
      return 'social_elder';
    }

    // ========== 金融保险 ==========
    if (_containsAny(text, ['人寿', '寿险'])) {
      return 'finance_life_insurance';
    }
    if (_containsAny(text, ['医保', '医疗险'])) {
      return 'finance_medical_insurance';
    }
    if (_containsAny(text, ['车险', '交强险'])) {
      return 'finance_car_insurance';
    }
    if (_containsAny(text, ['手续费', '转账费'])) {
      return 'finance_fee';
    }
    if (_containsAny(text, ['利息', '贷款利息'])) {
      return 'finance_loan_interest';
    }

    // ========== 宠物 ==========
    if (_containsAny(text, ['猫粮', '狗粮', '宠物食品'])) {
      return 'pet_food';
    }
    if (_containsAny(text, ['猫砂', '宠物玩具', '宠物用品'])) {
      return 'pet_supplies';
    }
    if (_containsAny(text, ['宠物医院', '宠物看病'])) {
      return 'pet_medical';
    }

    // ========== 收入分类 ==========
    // 工资细分
    if (_containsAny(text, ['基本工资', '底薪'])) {
      return 'salary_base';
    }
    if (_containsAny(text, ['绩效', '绩效奖'])) {
      return 'salary_performance';
    }
    if (_containsAny(text, ['加班费', '加班工资'])) {
      return 'salary_overtime';
    }
    if (_containsAny(text, ['年终奖', '十三薪'])) {
      return 'salary_annual';
    }
    if (_containsAny(text, ['工资', '薪水', '月薪', '发工资', '薪资'])) {
      return 'salary';
    }

    // 奖金细分
    if (_containsAny(text, ['项目奖', '完成奖'])) {
      return 'bonus_project';
    }
    if (_containsAny(text, ['季度奖'])) {
      return 'bonus_quarterly';
    }
    if (_containsAny(text, ['奖金', '提成'])) {
      return 'bonus';
    }

    // 其他收入
    if (_containsAny(text, ['兼职', '副业', '外快', '私单'])) {
      return 'parttime';
    }
    if (_containsAny(text, ['理财', '投资', '收益', '分红', '股票', '基金', '余额宝'])) {
      return 'investment';
    }
    if (_containsAny(text, ['收红包', '微信红包'])) {
      return 'redpacket';
    }
    if (_containsAny(text, ['报销', '公司报销'])) {
      return 'reimburse';
    }
    if (_containsAny(text, ['生意', '店铺', '营业', '经营'])) {
      return 'business';
    }
    if (_containsAny(text, ['收入', '到账', '进账', '返现', '收到'])) {
      return 'other_income';
    }

    return 'other_expense';  // 默认为支出的其他分类
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
