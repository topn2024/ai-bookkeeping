import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 分类本地化服务
///
/// 根据设备区域自动选择合适的语言显示分类名称
/// 支持：中文(zh)、英文(en)、日文(ja)
class CategoryLocalizationService {
  static CategoryLocalizationService? _instance;

  /// 当前使用的语言代码
  String _currentLocale = 'zh';

  /// 用户手动选择的语言（null表示使用系统语言）
  String? _userOverrideLocale;

  CategoryLocalizationService._();

  static CategoryLocalizationService get instance {
    _instance ??= CategoryLocalizationService._();
    return _instance!;
  }

  /// 初始化服务，检测设备区域
  void initialize() {
    if (_userOverrideLocale != null) {
      _currentLocale = _userOverrideLocale!;
      return;
    }

    // 获取设备语言设置
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    _currentLocale = _mapLocaleToSupported(deviceLocale.languageCode);
  }

  /// 从BuildContext初始化（在Widget中使用）
  void initializeFromContext(BuildContext context) {
    if (_userOverrideLocale != null) {
      _currentLocale = _userOverrideLocale!;
      return;
    }

    final locale = Localizations.localeOf(context);
    _currentLocale = _mapLocaleToSupported(locale.languageCode);
  }

  /// 将语言代码映射到支持的语言
  String _mapLocaleToSupported(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'zh': // 中文
        return 'zh';
      case 'ja': // 日语
        return 'ja';
      case 'ko': // 韩语
        return 'ko';
      case 'en': // 英语
      default:   // 其他语言默认使用英语
        return 'en';
    }
  }

  /// 获取当前语言代码
  String get currentLocale => _currentLocale;

  /// 手动设置语言
  void setLocale(String? locale) {
    _userOverrideLocale = locale;
    if (locale != null) {
      _currentLocale = _mapLocaleToSupported(locale);
    } else {
      // 恢复系统语言
      initialize();
    }
  }

  /// 判断是否使用了用户自定义语言
  bool get isUserOverride => _userOverrideLocale != null;

  /// 获取分类的本地化名称
  String getCategoryName(String categoryId) {
    return _categoryTranslations[categoryId]?[_currentLocale]
        ?? _categoryTranslations[categoryId]?['en']
        ?? categoryId;
  }

  /// 获取指定语言的分类名称
  String getCategoryNameForLocale(String categoryId, String locale) {
    final mappedLocale = _mapLocaleToSupported(locale);
    return _categoryTranslations[categoryId]?[mappedLocale]
        ?? _categoryTranslations[categoryId]?['en']
        ?? categoryId;
  }

  /// 获取所有支持的语言
  static const List<LocaleOption> supportedLocales = [
    LocaleOption(code: 'zh', name: '中文', nativeName: '中文'),
    LocaleOption(code: 'en', name: 'English', nativeName: 'English'),
    LocaleOption(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    LocaleOption(code: 'ko', name: 'Korean', nativeName: '한국어'),
  ];

  /// 分类翻译表
  /// 格式: { categoryId: { languageCode: translatedName } }
  static const Map<String, Map<String, String>> _categoryTranslations = {
    // ============ 支出分类 ============
    'food': {
      'zh': '餐饮',
      'en': 'Food & Dining',
      'ja': '食費',
      'ko': '식비',
    },
    'transport': {
      'zh': '交通',
      'en': 'Transportation',
      'ja': '交通費',
      'ko': '교통비',
    },
    'shopping': {
      'zh': '购物',
      'en': 'Shopping',
      'ja': '買い物',
      'ko': '쇼핑',
    },
    'entertainment': {
      'zh': '娱乐',
      'en': 'Entertainment',
      'ja': '娯楽',
      'ko': '오락',
    },
    'housing': {
      'zh': '居住',
      'en': 'Housing',
      'ja': '住居費',
      'ko': '주거비',
    },
    'utilities': {
      'zh': '水电燃气',
      'en': 'Utilities',
      'ja': '光熱費',
      'ko': '공과금',
    },
    'medical': {
      'zh': '医疗',
      'en': 'Medical',
      'ja': '医療費',
      'ko': '의료비',
    },
    'education': {
      'zh': '教育',
      'en': 'Education',
      'ja': '教育費',
      'ko': '교육비',
    },
    'communication': {
      'zh': '通讯',
      'en': 'Communication',
      'ja': '通信費',
      'ko': '통신비',
    },
    'clothing': {
      'zh': '服饰',
      'en': 'Clothing',
      'ja': '衣服',
      'ko': '의류',
    },
    'beauty': {
      'zh': '美容',
      'en': 'Beauty',
      'ja': '美容',
      'ko': '뷰티',
    },
    'other_expense': {
      'zh': '其他',
      'en': 'Other',
      'ja': 'その他',
      'ko': '기타',
    },

    // ============ 餐饮子分类 ============
    'food_breakfast': {
      'zh': '早餐',
      'en': 'Breakfast',
      'ja': '朝食',
      'ko': '아침식사',
    },
    'food_lunch': {
      'zh': '午餐',
      'en': 'Lunch',
      'ja': '昼食',
      'ko': '점심식사',
    },
    'food_dinner': {
      'zh': '晚餐',
      'en': 'Dinner',
      'ja': '夕食',
      'ko': '저녁식사',
    },
    'food_snack': {
      'zh': '零食',
      'en': 'Snacks',
      'ja': 'おやつ',
      'ko': '간식',
    },
    'food_drink': {
      'zh': '饮料',
      'en': 'Drinks',
      'ja': '飲み物',
      'ko': '음료',
    },
    'food_delivery': {
      'zh': '外卖',
      'en': 'Delivery',
      'ja': 'デリバリー',
      'ko': '배달음식',
    },

    // ============ 交通子分类 ============
    'transport_public': {
      'zh': '公交地铁',
      'en': 'Public Transit',
      'ja': '公共交通',
      'ko': '대중교통',
    },
    'transport_taxi': {
      'zh': '打车',
      'en': 'Taxi/Rideshare',
      'ja': 'タクシー',
      'ko': '택시',
    },
    'transport_fuel': {
      'zh': '加油',
      'en': 'Gas/Fuel',
      'ja': 'ガソリン',
      'ko': '주유',
    },
    'transport_parking': {
      'zh': '停车',
      'en': 'Parking',
      'ja': '駐車場',
      'ko': '주차',
    },
    'transport_train': {
      'zh': '火车',
      'en': 'Train',
      'ja': '電車',
      'ko': '기차',
    },
    'transport_flight': {
      'zh': '飞机',
      'en': 'Flight',
      'ja': '飛行機',
      'ko': '항공',
    },

    // ============ 购物子分类 ============
    'shopping_daily': {
      'zh': '日用品',
      'en': 'Daily Essentials',
      'ja': '日用品',
      'ko': '생필품',
    },
    'shopping_digital': {
      'zh': '数码产品',
      'en': 'Electronics',
      'ja': 'デジタル製品',
      'ko': '전자제품',
    },
    'shopping_appliance': {
      'zh': '家电',
      'en': 'Appliances',
      'ja': '家電',
      'ko': '가전제품',
    },
    'shopping_furniture': {
      'zh': '家居',
      'en': 'Home & Furniture',
      'ja': '家具',
      'ko': '가구',
    },
    'shopping_gift': {
      'zh': '礼物',
      'en': 'Gifts',
      'ja': 'プレゼント',
      'ko': '선물',
    },

    // ============ 娱乐子分类 ============
    'entertainment_movie': {
      'zh': '电影',
      'en': 'Movies',
      'ja': '映画',
      'ko': '영화',
    },
    'entertainment_game': {
      'zh': '游戏',
      'en': 'Games',
      'ja': 'ゲーム',
      'ko': '게임',
    },
    'entertainment_travel': {
      'zh': '旅游',
      'en': 'Travel',
      'ja': '旅行',
      'ko': '여행',
    },
    'entertainment_sport': {
      'zh': '运动',
      'en': 'Sports',
      'ja': 'スポーツ',
      'ko': '스포츠',
    },
    'entertainment_ktv': {
      'zh': 'KTV',
      'en': 'Karaoke',
      'ja': 'カラオケ',
      'ko': '노래방',
    },
    'entertainment_party': {
      'zh': '聚会',
      'en': 'Party',
      'ja': 'パーティー',
      'ko': '모임',
    },

    // ============ 居住子分类 ============
    'housing_rent': {
      'zh': '房租',
      'en': 'Rent',
      'ja': '家賃',
      'ko': '월세',
    },
    'housing_mortgage': {
      'zh': '房贷',
      'en': 'Mortgage',
      'ja': '住宅ローン',
      'ko': '주택담보대출',
    },
    'housing_property': {
      'zh': '物业费',
      'en': 'Property Fee',
      'ja': '管理費',
      'ko': '관리비',
    },
    'housing_repair': {
      'zh': '维修',
      'en': 'Repairs',
      'ja': '修繕',
      'ko': '수리',
    },

    // ============ 水电燃气子分类 ============
    'utilities_electric': {
      'zh': '电费',
      'en': 'Electricity',
      'ja': '電気代',
      'ko': '전기요금',
    },
    'utilities_water': {
      'zh': '水费',
      'en': 'Water',
      'ja': '水道代',
      'ko': '수도요금',
    },
    'utilities_gas': {
      'zh': '燃气费',
      'en': 'Gas',
      'ja': 'ガス代',
      'ko': '가스요금',
    },
    'utilities_heating': {
      'zh': '暖气费',
      'en': 'Heating',
      'ja': '暖房費',
      'ko': '난방비',
    },

    // ============ 医疗子分类 ============
    'medical_clinic': {
      'zh': '门诊',
      'en': 'Clinic Visit',
      'ja': '外来',
      'ko': '외래진료',
    },
    'medical_medicine': {
      'zh': '药品',
      'en': 'Medicine',
      'ja': '薬',
      'ko': '약품',
    },
    'medical_hospital': {
      'zh': '住院',
      'en': 'Hospital',
      'ja': '入院',
      'ko': '입원',
    },
    'medical_checkup': {
      'zh': '体检',
      'en': 'Checkup',
      'ja': '健康診断',
      'ko': '건강검진',
    },
    'medical_supplement': {
      'zh': '保健品',
      'en': 'Supplements',
      'ja': 'サプリメント',
      'ko': '건강보조식품',
    },

    // ============ 教育子分类 ============
    'education_tuition': {
      'zh': '学费',
      'en': 'Tuition',
      'ja': '学費',
      'ko': '학비',
    },
    'education_books': {
      'zh': '书籍',
      'en': 'Books',
      'ja': '書籍',
      'ko': '도서',
    },
    'education_training': {
      'zh': '培训',
      'en': 'Training',
      'ja': '研修',
      'ko': '교육훈련',
    },
    'education_exam': {
      'zh': '考试',
      'en': 'Exams',
      'ja': '試験',
      'ko': '시험',
    },

    // ============ 通讯子分类 ============
    'communication_phone': {
      'zh': '话费',
      'en': 'Phone Bill',
      'ja': '携帯料金',
      'ko': '휴대폰요금',
    },
    'communication_internet': {
      'zh': '网费',
      'en': 'Internet',
      'ja': 'インターネット',
      'ko': '인터넷요금',
    },
    'communication_subscription': {
      'zh': '会员订阅',
      'en': 'Subscriptions',
      'ja': 'サブスク',
      'ko': '구독서비스',
    },

    // ============ 服饰子分类 ============
    'clothing_clothes': {
      'zh': '衣服',
      'en': 'Clothes',
      'ja': '服',
      'ko': '옷',
    },
    'clothing_shoes': {
      'zh': '鞋子',
      'en': 'Shoes',
      'ja': '靴',
      'ko': '신발',
    },
    'clothing_accessories': {
      'zh': '配饰',
      'en': 'Accessories',
      'ja': 'アクセサリー',
      'ko': '액세서리',
    },

    // ============ 美容子分类 ============
    'beauty_skincare': {
      'zh': '护肤',
      'en': 'Skincare',
      'ja': 'スキンケア',
      'ko': '스킨케어',
    },
    'beauty_cosmetics': {
      'zh': '化妆品',
      'en': 'Cosmetics',
      'ja': '化粧品',
      'ko': '화장품',
    },
    'beauty_haircut': {
      'zh': '美发',
      'en': 'Hair',
      'ja': 'ヘアケア',
      'ko': '미용실',
    },
    'beauty_nails': {
      'zh': '美甲',
      'en': 'Nails',
      'ja': 'ネイル',
      'ko': '네일',
    },

    // ============ 收入分类 ============
    'salary': {
      'zh': '工资',
      'en': 'Salary',
      'ja': '給料',
      'ko': '급여',
    },
    'bonus': {
      'zh': '奖金',
      'en': 'Bonus',
      'ja': 'ボーナス',
      'ko': '보너스',
    },
    'investment': {
      'zh': '投资收益',
      'en': 'Investment',
      'ja': '投資収益',
      'ko': '투자수익',
    },
    'parttime': {
      'zh': '兼职',
      'en': 'Part-time',
      'ja': 'アルバイト',
      'ko': '아르바이트',
    },
    'redpacket': {
      'zh': '红包',
      'en': 'Gift Money',
      'ja': 'お年玉',
      'ko': '세뱃돈',
    },
    'reimburse': {
      'zh': '报销',
      'en': 'Reimbursement',
      'ja': '経費精算',
      'ko': '경비정산',
    },
    'other_income': {
      'zh': '其他',
      'en': 'Other',
      'ja': 'その他',
      'ko': '기타',
    },

    // ============ 转账分类 ============
    'transfer': {
      'zh': '转账',
      'en': 'Transfer',
      'ja': '振込',
      'ko': '이체',
    },
    'account_transfer': {
      'zh': '账户互转',
      'en': 'Account Transfer',
      'ja': '口座間振込',
      'ko': '계좌이체',
    },
  };

  /// 添加自定义分类的翻译
  void addCustomTranslation(String categoryId, Map<String, String> translations) {
    _customTranslations[categoryId] = translations;
  }

  /// 自定义分类翻译（运行时添加）
  static final Map<String, Map<String, String>> _customTranslations = {};
}

/// 语言选项
class LocaleOption {
  final String code;
  final String name;
  final String nativeName;

  const LocaleOption({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

/// Category扩展，便于获取本地化名称
extension CategoryLocalization on String {
  /// 获取分类ID的本地化名称
  String get localizedCategoryName {
    return CategoryLocalizationService.instance.getCategoryName(this);
  }
}
