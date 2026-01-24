import 'dart:typed_data';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart';
import 'bill_format_detector.dart';

/// Result of bill parsing
class BillParseResult {
  final List<ImportCandidate> candidates;
  final int successCount;
  final int failedCount;
  final List<String> errors;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final Map<String, dynamic>? metadata;

  BillParseResult({
    required this.candidates,
    required this.successCount,
    required this.failedCount,
    this.errors = const [],
    this.dateRangeStart,
    this.dateRangeEnd,
    this.metadata,
  });

  bool get isSuccess => failedCount == 0 && candidates.isNotEmpty;
  bool get hasPartialSuccess => successCount > 0;
}

/// Base class for bill parsers
abstract class BillParser {
  /// Parse the bill file and return candidates
  Future<BillParseResult> parse(Uint8List bytes);

  /// Get the source type this parser handles
  BillSourceType get sourceType;

  /// Get the external source for this parser
  ExternalSource get externalSource;

  /// Infer category from merchant name and note
  String inferCategory(String? merchant, String? note, TransactionType type) {
    final text = '${merchant ?? ''} ${note ?? ''}'.toLowerCase();

    if (type == TransactionType.income) {
      // Income categories - 使用标准分类ID
      if (text.contains('工资') || text.contains('薪资') || text.contains('salary')) {
        return 'salary';
      }
      if (text.contains('奖金') || text.contains('bonus')) {
        return 'bonus';
      }
      if (text.contains('红包')) {
        return 'redpacket';
      }
      if (text.contains('退款') || text.contains('refund') || text.contains('报销')) {
        return 'reimburse';
      }
      if (text.contains('利息') || text.contains('理财') || text.contains('收益')) {
        return 'investment';
      }
      return 'other_income';
    }

    // Expense categories - 使用标准分类ID
    // 优先级：具体规则 > 一般规则

    // Transportation - 加油站和加油卡充值（优先识别，避免被游戏充值误判）
    if (text.contains('中石油') || text.contains('中石化') || text.contains('壳牌') ||
        text.contains('加油站') || text.contains('加油') || text.contains('油费') ||
        text.contains('gas') || text.contains('fuel') || text.contains('petro') ||
        text.contains('昆仑e卡') || text.contains('加油卡') || text.contains('油卡充值')) {
      return 'transport_fuel';
    }

    // Transportation - 洗车服务
    if (text.contains('洗车') || text.contains('car wash') || text.contains('洗车机') ||
        text.contains('汽车清洗') || text.contains('车辆清洗')) {
      return 'transport';
    }

    // Transportation - 汽车维修保养
    if (text.contains('汽车维修') || text.contains('保养') || text.contains('4s店') ||
        text.contains('修车') || text.contains('换油') || text.contains('轮胎') ||
        text.contains('汽修') || text.contains('车辆维修')) {
      return 'transport';
    }

    // Entertainment - 住宿（优先识别，避免被其他分类）
    if (text.contains('酒店') || text.contains('hotel') || text.contains('宾馆') ||
        text.contains('民宿') || text.contains('airbnb') || text.contains('客栈') ||
        text.contains('大床房') || text.contains('标准间') || text.contains('套房') ||
        text.contains('住宿') || text.contains('入住') || text.contains('booking')) {
      return 'entertainment_travel';
    }

    // Food & Dining - 具体餐饮类型（优先识别）
    if (text.contains('寿司') || text.contains('sushi') || text.contains('日料') || text.contains('日本料理')) {
      return 'food';
    }
    if (text.contains('火锅') || text.contains('hotpot') || text.contains('海底捞') || text.contains('呷哺')) {
      return 'food';
    }
    if (text.contains('烧烤') || text.contains('bbq') || text.contains('烤肉')) {
      return 'food';
    }
    if (text.contains('面馆') || text.contains('面条') || text.contains('拉面') || text.contains('noodle')) {
      return 'food';
    }
    if (text.contains('粥') || text.contains('包子') || text.contains('饺子') || text.contains('馄饨')) {
      return 'food';
    }
    if (text.contains('西餐') || text.contains('牛排') || text.contains('披萨') || text.contains('pizza')) {
      return 'food';
    }
    if (text.contains('韩餐') || text.contains('韩国料理') || text.contains('石锅拌饭') || text.contains('烤肉')) {
      return 'food';
    }
    if (text.contains('川菜') || text.contains('湘菜') || text.contains('粤菜') || text.contains('东北菜')) {
      return 'food';
    }

    // Food & Dining - 时段餐饮
    if (text.contains('早餐') || text.contains('早点') || text.contains('breakfast')) {
      return 'food_breakfast';
    }
    if (text.contains('午餐') || text.contains('午饭') || text.contains('lunch')) {
      return 'food_lunch';
    }
    if (text.contains('晚餐') || text.contains('晚饭') || text.contains('dinner') || text.contains('夜宵')) {
      return 'food_dinner';
    }

    // Food & Dining - 外卖和饮品
    if (text.contains('外卖') || text.contains('美团') || text.contains('饿了么') || text.contains('delivery')) {
      return 'food_delivery';
    }
    if (text.contains('咖啡') || text.contains('星巴克') || text.contains('瑞幸') || text.contains('coffee') ||
        text.contains('奶茶') || text.contains('喜茶') || text.contains('茶百道') || text.contains('coco') ||
        text.contains('一点点') || text.contains('茶颜悦色')) {
      return 'food_drink';
    }
    if (text.contains('水果') || text.contains('fruit') || text.contains('果园') || text.contains('水果店')) {
      return 'food_fruit';
    }
    if (text.contains('零食') || text.contains('snack') || text.contains('小吃') || text.contains('糕点')) {
      return 'food_snack';
    }

    // Food & Dining - 餐饮品牌和通用关键词
    if (text.contains('麦当劳') || text.contains('肯德基') || text.contains('必胜客') ||
        text.contains('汉堡王') || text.contains('德克士') || text.contains('subway')) {
      return 'food';
    }
    if (text.contains('餐厅') || text.contains('饭店') || text.contains('酒楼') || text.contains('食府') ||
        text.contains('餐') || text.contains('饭') || text.contains('食') || text.contains('吃') ||
        text.contains('restaurant') || text.contains('食堂') || text.contains('美食')) {
      return 'food';
    }

    // Transportation - 出行方式
    if (text.contains('滴滴') || text.contains('打车') || text.contains('出租') || text.contains('taxi') ||
        text.contains('网约车') || text.contains('曹操') || text.contains('首汽') || text.contains('uber')) {
      return 'transport_taxi';
    }
    if (text.contains('地铁') || text.contains('公交') || text.contains('公共交通') || text.contains('metro') ||
        text.contains('bus') || text.contains('一卡通') || text.contains('交通卡')) {
      return 'transport_public';
    }
    if (text.contains('停车') || text.contains('parking') || text.contains('停车费')) {
      return 'transport_parking';
    }
    if (text.contains('高铁') || text.contains('火车') || text.contains('12306') || text.contains('train') ||
        text.contains('动车') || text.contains('铁路')) {
      return 'transport_train';
    }
    if (text.contains('飞机') || text.contains('机票') || text.contains('航班') || text.contains('flight') ||
        text.contains('航空') || text.contains('airport')) {
      return 'transport_flight';
    }
    if (text.contains('交通') || text.contains('transport')) {
      return 'transport';
    }

    // Shopping - 电商平台
    if (text.contains('淘宝') || text.contains('天猫') || text.contains('京东') || text.contains('拼多多') ||
        text.contains('电商') || text.contains('网购') || text.contains('唯品会') || text.contains('苏宁')) {
      return 'shopping_digital';
    }

    // Shopping - 超市便利店
    if (text.contains('超市') || text.contains('便利店') || text.contains('7-11') || text.contains('全家') ||
        text.contains('罗森') || text.contains('沃尔玛') || text.contains('永辉') || text.contains('家乐福') ||
        text.contains('大润发') || text.contains('华联') || text.contains('物美')) {
      return 'shopping_daily';
    }

    // Shopping - 家电家居
    if (text.contains('家电') || text.contains('appliance') || text.contains('冰箱') || text.contains('洗衣机') ||
        text.contains('空调') || text.contains('电视')) {
      return 'shopping_appliance';
    }
    if (text.contains('家居') || text.contains('furniture') || text.contains('沙发') || text.contains('床') ||
        text.contains('桌子') || text.contains('椅子') || text.contains('宜家') || text.contains('ikea')) {
      return 'shopping_furniture';
    }
    if (text.contains('礼物') || text.contains('gift') || text.contains('送礼')) {
      return 'shopping_gift';
    }

    // Clothing - 服装鞋帽
    if (text.contains('鞋') || text.contains('shoes') || text.contains('运动鞋') || text.contains('皮鞋') ||
        text.contains('nike') || text.contains('adidas') || text.contains('new balance')) {
      return 'clothing_shoes';
    }
    if (text.contains('手表') || text.contains('watch') || text.contains('包') || text.contains('bag') ||
        text.contains('配饰') || text.contains('accessories') || text.contains('首饰') || text.contains('jewelry')) {
      return 'clothing_accessories';
    }
    if (text.contains('服装') || text.contains('衣服') || text.contains('clothes') ||
        text.contains('优衣库') || text.contains('zara') || text.contains('hm') || text.contains('uniqlo')) {
      return 'clothing_clothes';
    }

    // Shopping - 数码电子
    if (text.contains('数码') || text.contains('电子') || text.contains('手机') || text.contains('电脑') ||
        text.contains('苹果专卖') || text.contains('apple store') || text.contains('华为专卖')) {
      return 'shopping_digital';
    }

    // Shopping - 通用购物
    if (text.contains('购物') || text.contains('shopping') || text.contains('商城') || text.contains('百货') ||
        text.contains('商场') || text.contains('mall')) {
      return 'shopping';
    }

    // Entertainment - 游戏（更精确的识别）
    if (text.contains('游戏充值') || text.contains('腾讯游戏') || text.contains('网易游戏') ||
        text.contains('steam') || text.contains('playstation') || text.contains('xbox') ||
        text.contains('王者荣耀') || text.contains('和平精英') || text.contains('原神') ||
        (text.contains('游戏') && text.contains('充值'))) {
      return 'entertainment_game';
    }

    // Entertainment - 影音娱乐
    if (text.contains('电影') || text.contains('cinema') || text.contains('movie') || text.contains('影院') ||
        text.contains('万达影城') || text.contains('cgv')) {
      return 'entertainment_movie';
    }
    if (text.contains('视频会员') || text.contains('爱奇艺') || text.contains('腾讯视频') ||
        text.contains('优酷') || text.contains('bilibili') || text.contains('netflix')) {
      return 'subscription_video';
    }
    if (text.contains('音乐会员') || text.contains('spotify') || text.contains('apple music') ||
        text.contains('qq音乐') || text.contains('网易云音乐')) {
      return 'subscription_music';
    }

    // Entertainment - 旅游休闲
    if (text.contains('旅游') || text.contains('景区') || text.contains('门票') || text.contains('travel') ||
        text.contains('旅行社') || text.contains('导游') || text.contains('观光')) {
      return 'entertainment_travel';
    }
    if (text.contains('ktv') || text.contains('唱歌') || text.contains('卡拉ok')) {
      return 'entertainment_ktv';
    }
    if (text.contains('酒吧') || text.contains('bar') || text.contains('夜店') || text.contains('club') ||
        text.contains('聚会') || text.contains('party')) {
      return 'entertainment_party';
    }
    if (text.contains('健身') || text.contains('gym') || text.contains('瑜伽')) {
      return 'entertainment_fitness';
    }
    if (text.contains('运动') || text.contains('球馆') || text.contains('游泳') || text.contains('羽毛球') ||
        text.contains('篮球') || text.contains('足球') || text.contains('网球') || text.contains('乒乓球')) {
      return 'entertainment_sport';
    }

    // Health & Medical
    if (text.contains('住院') || text.contains('hospitalization') || text.contains('入院')) {
      return 'medical_hospital';
    }
    if (text.contains('体检') || text.contains('checkup') || text.contains('健康检查')) {
      return 'medical_checkup';
    }
    if (text.contains('保健品') || text.contains('supplement') || text.contains('维生素')) {
      return 'medical_supplement';
    }
    if (text.contains('医院') || text.contains('诊所') || text.contains('看病') || text.contains('挂号') ||
        text.contains('hospital') || text.contains('medical')) {
      return 'medical_clinic';
    }
    if (text.contains('药') || text.contains('药店') || text.contains('pharmacy') || text.contains('药房')) {
      return 'medical_medicine';
    }

    // Education
    if (text.contains('学费') || text.contains('tuition')) {
      return 'education_tuition';
    }
    if (text.contains('培训') || text.contains('training') || text.contains('辅导班')) {
      return 'education_training';
    }
    if (text.contains('考试') || text.contains('exam') || text.contains('报名费')) {
      return 'education_exam';
    }
    if (text.contains('书') || text.contains('book') || text.contains('图书') || text.contains('书店')) {
      return 'education_books';
    }
    if (text.contains('教育') || text.contains('课程') || text.contains('education') || text.contains('course')) {
      return 'education';
    }

    // Housing & Utilities
    if (text.contains('房租') || text.contains('租金') || text.contains('rent')) {
      return 'housing_rent';
    }
    if (text.contains('房贷') || text.contains('按揭') || text.contains('mortgage')) {
      return 'housing_mortgage';
    }
    if (text.contains('物业费') || text.contains('物业') || text.contains('property fee')) {
      return 'housing_property';
    }
    if (text.contains('房屋维修') || text.contains('装修') || text.contains('repair')) {
      return 'housing_repair';
    }
    if (text.contains('电费') || text.contains('electricity')) {
      return 'utilities_electric';
    }
    if (text.contains('水费') || text.contains('water bill')) {
      return 'utilities_water';
    }
    if (text.contains('燃气费') || text.contains('燃气') || text.contains('gas bill')) {
      return 'utilities_gas';
    }
    if (text.contains('暖气费') || text.contains('暖气') || text.contains('heating')) {
      return 'utilities_heating';
    }
    if (text.contains('utility')) {
      return 'utilities';
    }

    // Communication
    if (text.contains('宽带') || text.contains('网费') || text.contains('internet') || text.contains('broadband')) {
      return 'communication_internet';
    }
    if (text.contains('话费充值') || text.contains('手机充值') || text.contains('流量充值') ||
        text.contains('话费') || text.contains('流量') || text.contains('mobile') ||
        text.contains('联通') || text.contains('移动') || text.contains('电信')) {
      return 'communication_phone';
    }
    if (text.contains('通讯')) {
      return 'communication';
    }

    // Beauty & Personal Care
    if (text.contains('护肤') || text.contains('skincare') || text.contains('面膜') || text.contains('精华')) {
      return 'beauty_skincare';
    }
    if (text.contains('化妆品') || text.contains('cosmetics') || text.contains('口红') || text.contains('粉底')) {
      return 'beauty_cosmetics';
    }
    if (text.contains('理发') || text.contains('美发') || text.contains('haircut') || text.contains('发型')) {
      return 'beauty_haircut';
    }
    if (text.contains('美甲') || text.contains('nail') || text.contains('指甲')) {
      return 'beauty_nails';
    }
    if (text.contains('美容') || text.contains('化妆') || text.contains('salon') || text.contains('spa')) {
      return 'beauty';
    }

    // Pet - 宠物相关
    if (text.contains('猫粮') || text.contains('狗粮') || text.contains('宠物食品') || text.contains('pet food')) {
      return 'pet_food';
    }
    if (text.contains('宠物用品') || text.contains('pet supplies') || text.contains('猫砂') || text.contains('狗窝')) {
      return 'pet_supplies';
    }
    if (text.contains('宠物医院') || text.contains('pet hospital') || text.contains('兽医')) {
      return 'pet_medical';
    }
    if (text.contains('宠物美容') || text.contains('pet grooming') || text.contains('宠物洗澡')) {
      return 'pet_grooming';
    }
    if (text.contains('宠物寄养') || text.contains('pet boarding') || text.contains('宠物托管')) {
      return 'pet_boarding';
    }
    if (text.contains('宠物保险') || text.contains('pet insurance')) {
      return 'pet_insurance';
    }
    if (text.contains('宠物') || text.contains('pet')) {
      return 'pet';
    }

    // Subscription - 会员订阅（细分类别）
    if (text.contains('网盘') || text.contains('cloud storage') || text.contains('百度网盘') ||
        text.contains('阿里云盘') || text.contains('icloud')) {
      return 'subscription_cloud';
    }
    if (text.contains('办公软件') || text.contains('office') || text.contains('wps') || text.contains('microsoft 365')) {
      return 'subscription_office';
    }
    if (text.contains('购物会员') || text.contains('88vip') || text.contains('plus会员') || text.contains('京东plus')) {
      return 'subscription_shopping';
    }
    if (text.contains('阅读') || text.contains('reading') || text.contains('kindle') || text.contains('微信读书')) {
      return 'subscription_reading';
    }
    if (text.contains('游戏会员') || text.contains('game pass') || text.contains('psn') || text.contains('switch online')) {
      return 'subscription_game';
    }
    if (text.contains('工具订阅') || text.contains('软件订阅') || text.contains('tool subscription')) {
      return 'subscription_tool';
    }
    if (text.contains('会员') || text.contains('订阅') || text.contains('membership') ||
        text.contains('vip') || text.contains('premium')) {
      return 'subscription';
    }

    // Social - 人情往来
    if (text.contains('份子钱') || text.contains('礼金') || text.contains('wedding gift')) {
      return 'social_gift_money';
    }
    if (text.contains('节日送礼') || text.contains('festival gift') || text.contains('春节') || text.contains('中秋')) {
      return 'social_festival';
    }
    if (text.contains('请客') || text.contains('treat') || text.contains('请吃饭')) {
      return 'social_treat';
    }
    if (text.contains('红包支出') || text.contains('发红包') || text.contains('send red packet')) {
      return 'social_redpacket';
    }
    if (text.contains('探病') || text.contains('慰问') || text.contains('visit')) {
      return 'social_visit';
    }
    if (text.contains('感谢') || text.contains('答谢') || text.contains('thanks')) {
      return 'social_thanks';
    }
    if (text.contains('孝敬') || text.contains('长辈') || text.contains('父母') || text.contains('elder')) {
      return 'social_elder';
    }
    if (text.contains('还钱') || text.contains('还款') || text.contains('repay')) {
      return 'social_repay';
    }
    if (text.contains('捐款') || text.contains('慈善') || text.contains('donation') || text.contains('charity')) {
      return 'social_charity';
    }

    // Finance - 金融保险
    if (text.contains('人寿保险') || text.contains('life insurance') || text.contains('寿险')) {
      return 'finance_life_insurance';
    }
    if (text.contains('医疗保险') || text.contains('medical insurance') || text.contains('医保')) {
      return 'finance_medical_insurance';
    }
    if (text.contains('车险') || text.contains('car insurance') || text.contains('交强险')) {
      return 'finance_car_insurance';
    }
    if (text.contains('财产保险') || text.contains('property insurance')) {
      return 'finance_property_insurance';
    }
    if (text.contains('意外险') || text.contains('accident insurance')) {
      return 'finance_accident_insurance';
    }
    if (text.contains('贷款利息') || text.contains('loan interest') || text.contains('利息')) {
      return 'finance_loan_interest';
    }
    if (text.contains('手续费') || text.contains('service fee') || text.contains('fee')) {
      return 'finance_fee';
    }
    if (text.contains('罚款') || text.contains('滞纳金') || text.contains('penalty') || text.contains('fine')) {
      return 'finance_penalty';
    }
    if (text.contains('投资亏损') || text.contains('investment loss') || text.contains('亏损')) {
      return 'finance_investment_loss';
    }
    if (text.contains('按揭还款') || text.contains('mortgage payment')) {
      return 'finance_mortgage';
    }
    if (text.contains('税') || text.contains('tax') || text.contains('税收')) {
      return 'finance_tax';
    }
    if (text.contains('丢失') || text.contains('lost') || text.contains('遗失')) {
      return 'finance_lost';
    }
    if (text.contains('烂账') || text.contains('bad debt') || text.contains('坏账')) {
      return 'finance_bad_debt';
    }
    if (text.contains('保险') || text.contains('insurance')) {
      return 'finance';
    }

    // Transfer - not expense
    if (text.contains('转账') || text.contains('transfer')) {
      return 'transfer';
    }

    return 'other_expense';
  }

  /// Parse amount string to double
  double parseAmount(String amountStr) {
    // Remove currency symbols and whitespace
    final cleaned = amountStr
        .replaceAll(RegExp(r'[¥￥$€£₹元]'), '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();

    // Handle negative amounts
    if (cleaned.startsWith('-') || cleaned.startsWith('−')) {
      return double.tryParse(cleaned.substring(1)) ?? 0.0;
    }
    if (cleaned.startsWith('+')) {
      return double.tryParse(cleaned.substring(1)) ?? 0.0;
    }

    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Parse date string to DateTime
  DateTime? parseDate(String dateStr) {
    // Common date formats
    final formats = [
      // 2024-01-15 14:30:00
      RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})'),
      // 2024-01-15 14:30
      RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})'),
      // 2024/01/15 14:30:00
      RegExp(r'(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2}):(\d{2})'),
      // 2024/01/15 14:30
      RegExp(r'(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2})'),
      // 2024-01-15
      RegExp(r'(\d{4})-(\d{2})-(\d{2})'),
      // 2024/01/15
      RegExp(r'(\d{4})/(\d{2})/(\d{2})'),
      // 01-15-2024
      RegExp(r'(\d{2})-(\d{2})-(\d{4})'),
    ];

    for (final format in formats) {
      final match = format.firstMatch(dateStr.trim());
      if (match != null) {
        try {
          int year, month, day, hour = 0, minute = 0, second = 0;

          if (match.groupCount >= 3) {
            if (match.group(3)!.length == 4) {
              // MM-DD-YYYY format
              month = int.parse(match.group(1)!);
              day = int.parse(match.group(2)!);
              year = int.parse(match.group(3)!);
            } else {
              // YYYY-MM-DD format
              year = int.parse(match.group(1)!);
              month = int.parse(match.group(2)!);
              day = int.parse(match.group(3)!);
            }

            if (match.groupCount >= 5) {
              hour = int.parse(match.group(4)!);
              minute = int.parse(match.group(5)!);
            }
            if (match.groupCount >= 6) {
              second = int.parse(match.group(6)!);
            }

            return DateTime(year, month, day, hour, minute, second);
          }
        } catch (e) {
          continue;
        }
      }
    }

    // Try ISO 8601
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }
}
