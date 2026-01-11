import '../ai_service.dart';
import '../qwen_service.dart';

/// 分类建议服务
///
/// 负责处理交易分类相关的 AI 功能：
/// - 智能分类建议
/// - 本地分类匹配（离线模式）
/// - 收入/支出类型判断
///
/// 这是从 AIService 中提取的专注于分类建议的服务
class CategorySuggestionService {
  static final CategorySuggestionService _instance = CategorySuggestionService._internal();
  final QwenService _qwenService = QwenService();

  factory CategorySuggestionService() => _instance;
  CategorySuggestionService._internal();

  /// 智能分类建议
  ///
  /// 根据交易描述推荐最可能的分类，使用千问模型
  /// 如果 API 失败，会回退到本地分类
  ///
  /// [description] 交易描述
  /// 返回分类 ID
  Future<String?> suggestCategory(String description) async {
    try {
      final category = await _qwenService.suggestCategory(description);
      if (category != null) {
        final mapped = AIRecognitionResult.categoryMap[category] ?? category.toLowerCase();
        // 处理 'other' 分类，根据描述判断是收入还是支出
        if (mapped == 'other') {
          return isIncomeDescription(description) ? 'other_income' : 'other_expense';
        }
        return mapped;
      }
      return localSuggestCategory(description);
    } catch (e) {
      // 如果 API 失败，回退到本地分类
      return localSuggestCategory(description);
    }
  }

  /// 本地智能分类（离线模式）
  ///
  /// 使用关键词匹配进行分类推荐，优先返回二级分类
  ///
  /// [description] 交易描述
  String localSuggestCategory(String description) {
    final text = description.toLowerCase();

    // ========== 交通分类（优先级高）==========
    if (_containsAny(text, ['打车', '滴滴', '出租车', '高德打车', 'T3', '曹操', '首汽', '网约车', '快车', '专车'])) {
      return 'transport_taxi';
    }
    if (_containsAny(text, ['地铁', '公交', '公交卡', '地铁卡', '公共交通'])) {
      return 'transport_public';
    }
    if (_containsAny(text, ['高铁', '火车', '12306', '铁路', '动车'])) {
      return 'transport_train';
    }
    if (_containsAny(text, ['飞机', '机票', '航班', '航空'])) {
      return 'transport_flight';
    }
    if (_containsAny(text, ['加油', '中国石化', '中国石油', '壳牌', '加油站', '汽油'])) {
      return 'transport_fuel';
    }
    if (_containsAny(text, ['停车', '停车费', '停车场'])) {
      return 'transport_parking';
    }
    if (_containsAny(text, ['过路费', 'ETC', '高速', '哈啰', '美团单车', '共享单车', '车费', '路费', '交通'])) {
      return 'transport';
    }

    // ========== 餐饮分类 ==========
    if (_containsAny(text, ['早餐', '早饭', '早点', '包子', '豆浆', '油条'])) {
      return 'food_breakfast';
    }
    if (_containsAny(text, ['午餐', '午饭', '中餐', '工作餐', '午间'])) {
      return 'food_lunch';
    }
    if (_containsAny(text, ['晚餐', '晚饭', '夜宵', '宵夜'])) {
      return 'food_dinner';
    }
    if (_containsAny(text, ['咖啡', '星巴克', '瑞幸', '奶茶', '喜茶', '奈雪', '蜜雪', '茶百道', '饮料', '茶'])) {
      return 'food_drink';
    }
    if (_containsAny(text, ['外卖', '美团外卖', '饿了么'])) {
      return 'food_delivery';
    }
    if (_containsAny(text, ['水果', '苹果', '香蕉', '橙子', '果汁'])) {
      return 'food_fruit';
    }
    if (_containsAny(text, ['零食', '小吃', '糖果', '薯片', '饼干'])) {
      return 'food_snack';
    }
    if (_containsAny(text, ['饭', '菜', '餐', '吃', '喝', '麦当劳', '肯德基', '必胜客', '火锅', '烧烤', '快餐'])) {
      return 'food';
    }

    // ========== 购物分类 ==========
    if (_containsAny(text, ['日用品', '牙膏', '洗发水', '纸巾', '生活用品'])) {
      return 'shopping_daily';
    }
    if (_containsAny(text, ['手机', '电脑', '数码', '电子产品', '耳机'])) {
      return 'shopping_digital';
    }
    if (_containsAny(text, ['冰箱', '洗衣机', '空调', '电视', '家电'])) {
      return 'shopping_appliance';
    }
    if (_containsAny(text, ['家具', '床', '沙发', '桌子', '椅子', '宜家'])) {
      return 'shopping_furniture';
    }
    if (_containsAny(text, ['礼物', '礼品', '送人'])) {
      return 'shopping_gift';
    }
    if (_containsAny(text, ['淘宝', '天猫', '京东', '拼多多', '超市', '商场', '购物', '网购', '买'])) {
      return 'shopping';
    }

    // ========== 娱乐分类 ==========
    if (_containsAny(text, ['电影', '猫眼', '淘票票', '影院'])) {
      return 'entertainment_movie';
    }
    if (_containsAny(text, ['游戏', '王者荣耀', '和平精英', '原神'])) {
      return 'entertainment_game';
    }
    if (_containsAny(text, ['旅游', '景点', '门票', '酒店'])) {
      return 'entertainment_travel';
    }
    if (_containsAny(text, ['健身', '健身房', '游泳', '瑜伽', 'Keep'])) {
      return 'entertainment_fitness';
    }
    if (_containsAny(text, ['娱乐', 'KTV', '唱歌', '演唱会'])) {
      return 'entertainment';
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
    if (_containsAny(text, ['房', '租', '装修', '家具'])) {
      return 'housing';
    }

    // ========== 水电燃气 ==========
    if (_containsAny(text, ['电费', '充电'])) {
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

    // ========== 医疗分类 ==========
    if (_containsAny(text, ['挂号', '看病', '门诊'])) {
      return 'medical_clinic';
    }
    if (_containsAny(text, ['买药', '药店', '药品'])) {
      return 'medical_medicine';
    }
    if (_containsAny(text, ['体检', '健康检查'])) {
      return 'medical_checkup';
    }
    if (_containsAny(text, ['医', '药', '病', '医院'])) {
      return 'medical';
    }

    // ========== 教育分类 ==========
    if (_containsAny(text, ['学费', '报名费'])) {
      return 'education_tuition';
    }
    if (_containsAny(text, ['买书', '书籍', '图书'])) {
      return 'education_books';
    }
    if (_containsAny(text, ['培训', '课程', '网课'])) {
      return 'education_training';
    }
    if (_containsAny(text, ['教育', '学习'])) {
      return 'education';
    }

    // ========== 通讯分类 ==========
    if (_containsAny(text, ['话费', '充值', '手机费'])) {
      return 'communication_phone';
    }
    if (_containsAny(text, ['网费', '宽带'])) {
      return 'communication_internet';
    }

    // ========== 服饰分类 ==========
    if (_containsAny(text, ['衣服', '上衣', '裤子', '外套'])) {
      return 'clothing_clothes';
    }
    if (_containsAny(text, ['鞋子', '运动鞋', '皮鞋'])) {
      return 'clothing_shoes';
    }
    if (_containsAny(text, ['配饰', '手表', '项链', '包'])) {
      return 'clothing_accessories';
    }

    // ========== 收入分类 ==========
    if (_containsAny(text, ['基本工资', '底薪'])) {
      return 'salary_base';
    }
    if (_containsAny(text, ['绩效', '绩效奖'])) {
      return 'salary_performance';
    }
    if (_containsAny(text, ['年终奖', '十三薪'])) {
      return 'salary_annual';
    }
    if (_containsAny(text, ['工资', '薪水', '月薪', '发工资', '薪资'])) {
      return 'salary';
    }
    if (_containsAny(text, ['奖金', '提成'])) {
      return 'bonus';
    }
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
    if (_containsAny(text, ['收入', '到账', '进账', '返现', '收到'])) {
      return 'other_income';
    }

    return 'other_expense'; // 默认为支出的其他分类
  }

  /// 判断是否是收入类型描述
  ///
  /// [description] 交易描述
  bool isIncomeDescription(String description) {
    final text = description.toLowerCase();
    return _containsAny(text, [
      '工资', '薪水', '奖金', '红包', '收入', '到账',
      '进账', '报销', '利息', '返现', '收到', '赚'
    ]);
  }

  /// 批量分类建议
  ///
  /// 为多个描述提供分类建议
  ///
  /// [descriptions] 交易描述列表
  Future<Map<String, String>> suggestCategories(List<String> descriptions) async {
    final results = <String, String>{};
    for (final desc in descriptions) {
      final category = await suggestCategory(desc);
      if (category != null) {
        results[desc] = category;
      }
    }
    return results;
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
