import 'dart:io';
import 'dart:typed_data';
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

  /// 有效的分类ID列表
  static const Set<String> validCategoryIds = {
    'food', 'transport', 'shopping', 'entertainment', 'housing',
    'medical', 'education', 'other_expense', 'other_income',
    'salary', 'bonus', 'parttime', 'investment',
  };

  /// 分类映射表 - 精确匹配
  static const Map<String, String> categoryMap = {
    // 支出分类
    '餐饮': 'food',
    '食品': 'food',
    '饮食': 'food',
    '吃饭': 'food',
    '美食': 'food',
    '交通': 'transport',
    '出行': 'transport',
    '打车': 'transport',
    '购物': 'shopping',
    '网购': 'shopping',
    '娱乐': 'entertainment',
    '休闲': 'entertainment',
    '住房': 'housing',
    '房租': 'housing',
    '居住': 'housing',
    '医疗': 'medical',
    '健康': 'medical',
    '看病': 'medical',
    '教育': 'education',
    '学习': 'education',
    '培训': 'education',
    '其他': 'other_expense',  // 默认映射为支出的其他，收入的其他会在_mapCategory中处理
    // 收入分类
    '工资': 'salary',
    '薪水': 'salary',
    '薪资': 'salary',
    '奖金': 'bonus',
    '年终奖': 'bonus',
    '兼职': 'parttime',
    '副业': 'parttime',
    '理财': 'investment',
    '投资': 'investment',
    '收益': 'investment',
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
        final mapped = AIRecognitionResult.categoryMap[category] ?? category.toLowerCase();
        // 处理 'other' 分类，根据描述判断是收入还是支出
        if (mapped == 'other') {
          return isIncomeType(description) ? 'other_income' : 'other_expense';
        }
        return mapped;
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
  /// 使用关键词匹配进行分类推荐，按优先级排序
  String localSuggestCategory(String description) {
    final text = description.toLowerCase();

    // 交通关键词（优先级高，避免被其他分类误判）
    if (_containsAny(text, [
      '打车', '滴滴', '出租车', '高德打车', 'T3', '曹操', '首汽',
      '地铁', '公交', '公共交通',
      '高铁', '火车', '12306', '铁路',
      '飞机', '机票', '航班', '航空',
      '加油', '中国石化', '中国石油', '壳牌', '加油站',
      '停车', '停车费', '过路费', 'ETC', '高速',
      '哈啰', '美团单车', '青桔', '共享单车',
      '车费', '路费', '交通',
    ])) {
      return 'transport';
    }

    // 餐饮关键词（包含常见商户）
    if (_containsAny(text, [
      '早餐', '午餐', '晚餐', '夜宵', '早饭', '午饭', '晚饭',
      '外卖', '美团外卖', '饿了么',
      '饭', '菜', '餐', '吃', '喝',
      '咖啡', '星巴克', '瑞幸', 'Luckin',
      '奶茶', '喜茶', '奈雪', '蜜雪', '茶百道', 'COCO', '一点点',
      '麦当劳', '肯德基', 'KFC', '必胜客', '汉堡王', '德克士',
      '海底捞', '火锅', '烧烤', '小吃', '快餐', '便当',
      '面包', '蛋糕', '烘焙', '甜品',
      '盒马', '永辉', '沃尔玛', '超市食品',
      '便利店', '全家', '711', '罗森', '便利蜂',
      '水果', '零食',
    ])) {
      return 'food';
    }

    // 购物关键词
    if (_containsAny(text, [
      '淘宝', '天猫', '京东', '拼多多', '唯品会', '苏宁', '国美',
      '超市', '商场', '百货',
      '衣服', '服装', '鞋', '包', '帽子',
      '优衣库', 'ZARA', 'HM', 'GAP', '无印良品',
      '化妆品', '护肤', '口红', '丝芙兰', '屈臣氏',
      '日用品', '生活用品',
      '苹果', 'Apple', '小米', '华为', '手机', '电脑', '数码',
      '购物', '网购', '买',
    ])) {
      return 'shopping';
    }

    // 娱乐关键词
    if (_containsAny(text, [
      '电影', '猫眼', '淘票票', '万达影城',
      '游戏', '充值', '王者', '吃鸡', '原神',
      'KTV', 'ktv', '唱歌', '卡拉OK',
      '旅游', '景点', '门票', '酒店',
      '健身', 'Keep', '瑜伽', '游泳', '运动',
      '会员', 'VIP', '爱奇艺', '腾讯视频', '优酷', 'B站',
      '演唱会', '演出', '话剧', '展览',
      '迪士尼', '环球影城', '欢乐谷',
      '娱乐', '休闲',
    ])) {
      return 'entertainment';
    }

    // 住房关键词
    if (_containsAny(text, [
      '房租', '租金', '押金',
      '水电', '水费', '电费', '燃气', '煤气', '暖气',
      '物业', '物业费', '管理费',
      '网费', '宽带', '中国移动', '中国联通', '中国电信',
      '房贷', '按揭',
      '装修', '家具', '家电', '宜家',
    ])) {
      return 'housing';
    }

    // 医疗关键词
    if (_containsAny(text, [
      '医院', '门诊', '住院', '挂号',
      '药', '药店', '大参林', '益丰', '老百姓',
      '看病', '就医', '治疗',
      '体检', '美年', '爱康',
      '牙科', '口腔', '眼科',
      '医疗', '健康',
    ])) {
      return 'medical';
    }

    // 教育关键词
    if (_containsAny(text, [
      '学费', '培训', '课程', '网课',
      '书', '图书', '书店',
      '教育', '学习', '考试', '补习', '辅导',
      '新东方', '学而思', '猿辅导', '作业帮',
      '文具', '笔记本',
    ])) {
      return 'education';
    }

    // 收入关键词（按类型细分）
    if (_containsAny(text, ['工资', '薪水', '月薪', '底薪', '发工资'])) {
      return 'salary';
    }
    if (_containsAny(text, ['奖金', '年终奖', '提成', '绩效'])) {
      return 'bonus';
    }
    if (_containsAny(text, ['兼职', '副业', '外快', '私单'])) {
      return 'parttime';
    }
    if (_containsAny(text, ['理财', '投资', '收益', '利息', '分红', '股票', '基金', '余额宝'])) {
      return 'investment';
    }
    if (_containsAny(text, ['收入', '到账', '进账', '报销', '红包', '返现', '收到'])) {
      return 'salary';  // 默认收入分类
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
