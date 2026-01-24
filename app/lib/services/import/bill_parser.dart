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
        return 'bonus';  // 修复：从 income_bonus 改为 bonus
      }
      if (text.contains('红包')) {
        return 'redpacket';  // 修复：从 income_redpacket 改为 redpacket
      }
      if (text.contains('退款') || text.contains('refund') || text.contains('报销')) {
        return 'reimburse';  // 修复：从 income_refund 改为 reimburse
      }
      if (text.contains('利息') || text.contains('理财') || text.contains('收益')) {
        return 'investment';  // 修复：从 income_investment 改为 investment
      }
      return 'other_income';  // 修复：从 income_other 改为 other_income
    }

    // Expense categories - 使用标准分类ID
    // Food & Dining
    if (text.contains('早餐') || text.contains('早点') || text.contains('breakfast')) {
      return 'food_breakfast';
    }
    if (text.contains('午餐') || text.contains('午饭') || text.contains('lunch')) {
      return 'food_lunch';
    }
    if (text.contains('晚餐') || text.contains('晚饭') || text.contains('dinner') || text.contains('夜宵')) {
      return 'food_dinner';
    }
    if (text.contains('外卖') || text.contains('美团') || text.contains('饿了么') || text.contains('delivery')) {
      return 'food_delivery';
    }
    if (text.contains('咖啡') || text.contains('星巴克') || text.contains('瑞幸') || text.contains('coffee') ||
        text.contains('奶茶') || text.contains('喜茶') || text.contains('茶')) {
      return 'food_drink';
    }
    if (text.contains('水果') || text.contains('fruit')) {
      return 'food_fruit';
    }
    if (text.contains('零食') || text.contains('snack') || text.contains('小吃')) {
      return 'food_snack';
    }
    if (text.contains('餐') || text.contains('饭') || text.contains('食') || text.contains('吃') ||
        text.contains('restaurant') || text.contains('食堂') || text.contains('麦当劳') ||
        text.contains('肯德基') || text.contains('必胜客')) {
      return 'food';
    }

    // Transportation
    if (text.contains('滴滴') || text.contains('打车') || text.contains('出租') || text.contains('taxi') ||
        text.contains('网约车') || text.contains('曹操') || text.contains('首汽')) {
      return 'transport_taxi';
    }
    if (text.contains('地铁') || text.contains('公交') || text.contains('公共交通') || text.contains('metro') ||
        text.contains('bus') || text.contains('一卡通')) {
      return 'transport_public';
    }
    if (text.contains('加油') || text.contains('油费') || text.contains('gas') || text.contains('fuel')) {
      return 'transport_fuel';
    }
    if (text.contains('停车') || text.contains('parking')) {
      return 'transport_parking';
    }
    if (text.contains('高铁') || text.contains('火车') || text.contains('12306') || text.contains('train')) {
      return 'transport_train';
    }
    if (text.contains('飞机') || text.contains('机票') || text.contains('航班') || text.contains('flight')) {
      return 'transport_flight';
    }
    if (text.contains('交通') || text.contains('transport')) {
      return 'transport';
    }

    // Shopping
    if (text.contains('淘宝') || text.contains('天猫') || text.contains('京东') || text.contains('拼多多') ||
        text.contains('电商') || text.contains('网购')) {
      return 'shopping_digital';  // 修复：从 shopping_online 改为 shopping_digital
    }
    if (text.contains('超市') || text.contains('便利店') || text.contains('7-11') || text.contains('全家') ||
        text.contains('罗森') || text.contains('沃尔玛') || text.contains('永辉')) {
      return 'shopping_daily';  // 修复：从 shopping_grocery 改为 shopping_daily
    }
    if (text.contains('服装') || text.contains('衣服') || text.contains('鞋') || text.contains('clothes') ||
        text.contains('优衣库') || text.contains('zara') || text.contains('hm')) {
      return 'clothing_clothes';  // 修复：从 shopping_clothes 改为 clothing_clothes
    }
    if (text.contains('数码') || text.contains('电子') || text.contains('手机') || text.contains('电脑') ||
        text.contains('苹果') || text.contains('apple') || text.contains('华为')) {
      return 'shopping_digital';  // 修复：从 shopping_electronics 改为 shopping_digital
    }
    if (text.contains('购物') || text.contains('shopping') || text.contains('商城') || text.contains('百货')) {
      return 'shopping';
    }

    // Entertainment
    if (text.contains('电影') || text.contains('cinema') || text.contains('movie') || text.contains('影院')) {
      return 'entertainment_movie';
    }
    if (text.contains('游戏') || text.contains('game') || text.contains('充值')) {
      return 'entertainment_game';
    }
    if (text.contains('旅游') || text.contains('景区') || text.contains('门票') || text.contains('travel')) {
      return 'entertainment_travel';
    }
    if (text.contains('ktv') || text.contains('唱歌') || text.contains('酒吧') || text.contains('娱乐')) {
      return 'entertainment';
    }

    // Health & Medical
    if (text.contains('医院') || text.contains('诊所') || text.contains('看病') || text.contains('挂号') ||
        text.contains('hospital') || text.contains('medical')) {
      return 'medical_clinic';  // 修复：从 health_medical 改为 medical_clinic
    }
    if (text.contains('药') || text.contains('药店') || text.contains('pharmacy')) {
      return 'medical_medicine';  // 修复：从 health_medicine 改为 medical_medicine
    }
    if (text.contains('健身') || text.contains('gym') || text.contains('运动') || text.contains('瑜伽')) {
      return 'entertainment_fitness';  // 修复：从 health_fitness 改为 entertainment_fitness
    }

    // Education
    if (text.contains('教育') || text.contains('培训') || text.contains('课程') || text.contains('学费') ||
        text.contains('education') || text.contains('course')) {
      return 'education';
    }
    if (text.contains('书') || text.contains('book') || text.contains('图书')) {
      return 'education_books';
    }

    // Living
    if (text.contains('房租') || text.contains('租金') || text.contains('rent')) {
      return 'housing_rent';  // 修复：从 living_rent 改为 housing_rent
    }
    if (text.contains('水费') || text.contains('电费') || text.contains('燃气') || text.contains('物业') ||
        text.contains('utility')) {
      return 'utilities';  // 修复：从 living_utilities 改为 utilities（一级分类）
    }
    if (text.contains('通讯') || text.contains('话费') || text.contains('流量') || text.contains('宽带') ||
        text.contains('mobile') || text.contains('联通') || text.contains('移动') || text.contains('电信')) {
      return 'communication_phone';  // 修复：从 living_phone 改为 communication_phone
    }

    // Personal
    if (text.contains('美容') || text.contains('理发') || text.contains('化妆') || text.contains('护肤')) {
      return 'beauty';  // 修复：从 personal_beauty 改为 beauty（一级分类）
    }

    // Transfer - not expense
    if (text.contains('转账') || text.contains('transfer')) {
      return 'transfer';
    }

    return 'other_expense';  // 修复：从 'other' 改为 'other_expense'
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
