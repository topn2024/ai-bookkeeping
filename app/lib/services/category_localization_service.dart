import '../core/base/base_localization_service.dart';

/// 分类本地化服务
///
/// 根据设备区域自动选择合适的语言显示分类名称
/// 支持：中文(zh)、英文(en)、日文(ja)、韩文(ko)
class CategoryLocalizationService extends BaseLocalizationService<String> {
  static CategoryLocalizationService? _instance;

  CategoryLocalizationService._();

  static CategoryLocalizationService get instance {
    _instance ??= CategoryLocalizationService._();
    return _instance!;
  }

  @override
  Map<String, Map<String, String>> get translations => _categoryTranslations;

  /// 自定义分类翻译（运行时添加）
  static final Map<String, Map<String, String>> _customTranslations = {};

  @override
  void addCustomTranslation(String id, Map<String, String> localeTranslations) {
    _customTranslations[id] = localeTranslations;
  }

  /// 获取分类的本地化名称
  String getCategoryName(String categoryId) {
    // 先检查自定义翻译
    final custom = _customTranslations[categoryId]?[currentLocale];
    if (custom != null) {
      return custom;
    }

    return getLocalizedName(categoryId);
  }

  /// 获取指定语言的分类名称
  String getCategoryNameForLocale(String categoryId, String locale) {
    return getLocalizedNameForLocale(categoryId, locale);
  }

  /// 获取所有支持的语言
  static const List<LocaleOption> supportedLocaleOptions = [
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
    // ============ 新增一级支出分类 ============
    'subscription': {
      'zh': '会员订阅',
      'en': 'Subscription',
      'ja': 'サブスク',
      'ko': '구독',
    },
    'social': {
      'zh': '人情往来',
      'en': 'Social',
      'ja': '交際費',
      'ko': '경조사',
    },
    'finance': {
      'zh': '金融保险',
      'en': 'Finance & Insurance',
      'ja': '金融保険',
      'ko': '금융보험',
    },
    'pet': {
      'zh': '宠物',
      'en': 'Pet',
      'ja': 'ペット',
      'ko': '반려동물',
    },
    'other_expense': {
      'zh': '其他',
      'en': 'Other',
      'ja': 'その他',
      'ko': '기타',
    },
    // 兼容AI返回的 'other' 分类
    'other': {
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
    'food_fruit': {
      'zh': '水果',
      'en': 'Fruits',
      'ja': '果物',
      'ko': '과일',
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
    'transport_ship': {
      'zh': '轮船',
      'en': 'Ship',
      'ja': '船',
      'ko': '선박',
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
    'entertainment_fitness': {
      'zh': '健身',
      'en': 'Fitness',
      'ja': 'フィットネス',
      'ko': '헬스',
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

    // ============ 会员订阅子分类 ============
    'subscription_video': {
      'zh': '视频会员',
      'en': 'Video Streaming',
      'ja': '動画配信',
      'ko': '영상 구독',
    },
    'subscription_music': {
      'zh': '音乐会员',
      'en': 'Music Streaming',
      'ja': '音楽配信',
      'ko': '음악 구독',
    },
    'subscription_cloud': {
      'zh': '网盘会员',
      'en': 'Cloud Storage',
      'ja': 'クラウド',
      'ko': '클라우드',
    },
    'subscription_office': {
      'zh': '办公会员',
      'en': 'Office Suite',
      'ja': 'オフィス',
      'ko': '오피스',
    },
    'subscription_shopping': {
      'zh': '购物会员',
      'en': 'Shopping Membership',
      'ja': 'ショッピング',
      'ko': '쇼핑 멤버십',
    },
    'subscription_reading': {
      'zh': '阅读会员',
      'en': 'Reading',
      'ja': '読書',
      'ko': '독서',
    },
    'subscription_game': {
      'zh': '游戏会员',
      'en': 'Gaming',
      'ja': 'ゲーム',
      'ko': '게임',
    },
    'subscription_tool': {
      'zh': '工具订阅',
      'en': 'Tools & Apps',
      'ja': 'ツール',
      'ko': '도구',
    },

    // ============ 人情往来子分类 ============
    'social_gift_money': {
      'zh': '份子钱',
      'en': 'Gift Money',
      'ja': 'ご祝儀',
      'ko': '축의금',
    },
    'social_festival': {
      'zh': '节日送礼',
      'en': 'Festival Gifts',
      'ja': '贈り物',
      'ko': '명절 선물',
    },
    'social_treat': {
      'zh': '请客吃饭',
      'en': 'Treat Others',
      'ja': '食事会',
      'ko': '식사 대접',
    },
    'social_redpacket': {
      'zh': '红包支出',
      'en': 'Red Envelope',
      'ja': '紅包',
      'ko': '세뱃돈',
    },
    'social_visit': {
      'zh': '探病慰问',
      'en': 'Visit & Condolence',
      'ja': 'お見舞い',
      'ko': '병문안',
    },
    'social_thanks': {
      'zh': '感谢答谢',
      'en': 'Thank You Gifts',
      'ja': 'お礼',
      'ko': '감사 선물',
    },
    'social_elder': {
      'zh': '孝敬长辈',
      'en': 'Support Parents',
      'ja': '親孝行',
      'ko': '부모님 용돈',
    },
    'social_repay': {
      'zh': '还人钱物',
      'en': 'Repay Debts',
      'ja': '返済',
      'ko': '빚 갚기',
    },
    'social_charity': {
      'zh': '慈善捐助',
      'en': 'Charity',
      'ja': '寄付',
      'ko': '기부',
    },

    // ============ 金融保险子分类 ============
    'finance_life_insurance': {
      'zh': '人寿保险',
      'en': 'Life Insurance',
      'ja': '生命保険',
      'ko': '생명보험',
    },
    'finance_medical_insurance': {
      'zh': '医疗保险',
      'en': 'Health Insurance',
      'ja': '医療保険',
      'ko': '의료보험',
    },
    'finance_car_insurance': {
      'zh': '车险',
      'en': 'Auto Insurance',
      'ja': '自動車保険',
      'ko': '자동차보험',
    },
    'finance_property_insurance': {
      'zh': '财产保险',
      'en': 'Property Insurance',
      'ja': '財産保険',
      'ko': '재산보험',
    },
    'finance_accident_insurance': {
      'zh': '意外险',
      'en': 'Accident Insurance',
      'ja': '傷害保険',
      'ko': '상해보험',
    },
    'finance_loan_interest': {
      'zh': '贷款利息',
      'en': 'Loan Interest',
      'ja': 'ローン利息',
      'ko': '대출이자',
    },
    'finance_fee': {
      'zh': '手续费',
      'en': 'Service Fee',
      'ja': '手数料',
      'ko': '수수료',
    },
    'finance_penalty': {
      'zh': '罚款滞纳金',
      'en': 'Penalty & Late Fee',
      'ja': '罰金',
      'ko': '벌금',
    },
    'finance_investment_loss': {
      'zh': '投资亏损',
      'en': 'Investment Loss',
      'ja': '投資損失',
      'ko': '투자손실',
    },
    'finance_mortgage': {
      'zh': '按揭还款',
      'en': 'Mortgage Payment',
      'ja': '住宅ローン返済',
      'ko': '담보대출상환',
    },
    'finance_tax': {
      'zh': '消费税收',
      'en': 'Taxes',
      'ja': '税金',
      'ko': '세금',
    },
    'finance_lost': {
      'zh': '意外丢失',
      'en': 'Lost & Stolen',
      'ja': '紛失',
      'ko': '분실',
    },
    'finance_bad_debt': {
      'zh': '烂账损失',
      'en': 'Bad Debt',
      'ja': '不良債権',
      'ko': '대손',
    },

    // ============ 宠物子分类 ============
    'pet_food': {
      'zh': '宠物食品',
      'en': 'Pet Food',
      'ja': 'ペットフード',
      'ko': '펫푸드',
    },
    'pet_supplies': {
      'zh': '宠物用品',
      'en': 'Pet Supplies',
      'ja': 'ペット用品',
      'ko': '펫용품',
    },
    'pet_medical': {
      'zh': '宠物医疗',
      'en': 'Pet Medical',
      'ja': 'ペット病院',
      'ko': '동물병원',
    },
    'pet_grooming': {
      'zh': '宠物美容',
      'en': 'Pet Grooming',
      'ja': 'ペット美容',
      'ko': '펫미용',
    },
    'pet_boarding': {
      'zh': '宠物寄养',
      'en': 'Pet Boarding',
      'ja': 'ペットホテル',
      'ko': '펫호텔',
    },
    'pet_insurance': {
      'zh': '宠物保险',
      'en': 'Pet Insurance',
      'ja': 'ペット保険',
      'ko': '펫보험',
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
    'business': {
      'zh': '经营所得',
      'en': 'Business Income',
      'ja': '事業収入',
      'ko': '사업소득',
    },
    'other_income': {
      'zh': '其他',
      'en': 'Other',
      'ja': 'その他',
      'ko': '기타',
    },

    // ============ 工资子分类 ============
    'salary_base': {
      'zh': '基本工资',
      'en': 'Base Salary',
      'ja': '基本給',
      'ko': '기본급',
    },
    'salary_performance': {
      'zh': '绩效奖金',
      'en': 'Performance Bonus',
      'ja': '業績賞与',
      'ko': '성과급',
    },
    'salary_overtime': {
      'zh': '加班费',
      'en': 'Overtime Pay',
      'ja': '残業代',
      'ko': '야근수당',
    },
    'salary_annual': {
      'zh': '年终奖',
      'en': 'Year-end Bonus',
      'ja': '年末賞与',
      'ko': '연말 보너스',
    },

    // ============ 奖金子分类 ============
    'bonus_project': {
      'zh': '项目奖金',
      'en': 'Project Bonus',
      'ja': 'プロジェクト賞与',
      'ko': '프로젝트 보너스',
    },
    'bonus_quarterly': {
      'zh': '季度奖',
      'en': 'Quarterly Bonus',
      'ja': '四半期賞与',
      'ko': '분기 보너스',
    },
    'bonus_attendance': {
      'zh': '全勤奖',
      'en': 'Attendance Bonus',
      'ja': '皆勤賞',
      'ko': '개근 수당',
    },
    'bonus_other': {
      'zh': '其他奖励',
      'en': 'Other Bonus',
      'ja': 'その他賞与',
      'ko': '기타 보너스',
    },

    // ============ 投资收益子分类 ============
    'investment_stock': {
      'zh': '股票收益',
      'en': 'Stock Returns',
      'ja': '株式収益',
      'ko': '주식수익',
    },
    'investment_fund': {
      'zh': '基金收益',
      'en': 'Fund Returns',
      'ja': 'ファンド収益',
      'ko': '펀드수익',
    },
    'investment_interest': {
      'zh': '理财利息',
      'en': 'Interest Income',
      'ja': '利息収入',
      'ko': '이자수익',
    },
    'investment_dividend': {
      'zh': '分红',
      'en': 'Dividends',
      'ja': '配当金',
      'ko': '배당금',
    },
    'investment_rental': {
      'zh': '房租收入',
      'en': 'Rental Income',
      'ja': '家賃収入',
      'ko': '임대수익',
    },
    'investment_lottery': {
      'zh': '中奖',
      'en': 'Lottery',
      'ja': '当選金',
      'ko': '복권당첨',
    },
    'investment_windfall': {
      'zh': '意外来钱',
      'en': 'Windfall',
      'ja': '臨時収入',
      'ko': '횡재',
    },

    // ============ 兼职子分类 ============
    'parttime_salary': {
      'zh': '兼职工资',
      'en': 'Part-time Salary',
      'ja': 'アルバイト代',
      'ko': '아르바이트비',
    },
    'parttime_freelance': {
      'zh': '自由职业',
      'en': 'Freelance',
      'ja': 'フリーランス',
      'ko': '프리랜서',
    },
    'parttime_manuscript': {
      'zh': '稿费',
      'en': 'Writing Fee',
      'ja': '原稿料',
      'ko': '원고료',
    },
    'parttime_consulting': {
      'zh': '咨询费',
      'en': 'Consulting Fee',
      'ja': 'コンサルティング',
      'ko': '컨설팅비',
    },

    // ============ 红包子分类 ============
    'redpacket_wechat': {
      'zh': '微信红包',
      'en': 'WeChat Red Packet',
      'ja': 'WeChatお年玉',
      'ko': '위챗 세뱃돈',
    },
    'redpacket_alipay': {
      'zh': '支付宝红包',
      'en': 'Alipay Red Packet',
      'ja': 'Alipayお年玉',
      'ko': '알리페이 세뱃돈',
    },
    'redpacket_festival': {
      'zh': '节日红包',
      'en': 'Festival Red Packet',
      'ja': '祝日お年玉',
      'ko': '명절 세뱃돈',
    },
    'redpacket_gift': {
      'zh': '礼金收入',
      'en': 'Gift Money',
      'ja': 'ご祝儀',
      'ko': '축의금',
    },

    // ============ 报销子分类 ============
    'reimburse_transport': {
      'zh': '交通报销',
      'en': 'Transport Reimbursement',
      'ja': '交通費精算',
      'ko': '교통비 환급',
    },
    'reimburse_food': {
      'zh': '餐饮报销',
      'en': 'Meal Reimbursement',
      'ja': '食費精算',
      'ko': '식비 환급',
    },
    'reimburse_travel': {
      'zh': '差旅报销',
      'en': 'Travel Reimbursement',
      'ja': '出張精算',
      'ko': '출장비 환급',
    },
    'reimburse_medical': {
      'zh': '医疗报销',
      'en': 'Medical Reimbursement',
      'ja': '医療費精算',
      'ko': '의료비 환급',
    },

    // ============ 经营所得子分类 ============
    'business_sales': {
      'zh': '营业收入',
      'en': 'Sales Revenue',
      'ja': '売上収入',
      'ko': '매출수익',
    },
    'business_service': {
      'zh': '服务收入',
      'en': 'Service Income',
      'ja': 'サービス収入',
      'ko': '서비스수익',
    },
    'business_commission': {
      'zh': '佣金提成',
      'en': 'Commission',
      'ja': '手数料収入',
      'ko': '커미션',
    },
    'business_resale': {
      'zh': '代购收入',
      'en': 'Resale Income',
      'ja': '代購収入',
      'ko': '대리구매',
    },
    'business_rental': {
      'zh': '租赁收入',
      'en': 'Rental Income',
      'ja': 'レンタル収入',
      'ko': '임대수익',
    },
    'business_knowledge': {
      'zh': '知识付费',
      'en': 'Content Monetization',
      'ja': '知識課金',
      'ko': '지식판매',
    },
    'business_ad': {
      'zh': '广告收入',
      'en': 'Ad Revenue',
      'ja': '広告収入',
      'ko': '광고수익',
    },
    'business_refund': {
      'zh': '退税返现',
      'en': 'Tax Refund',
      'ja': '税還付',
      'ko': '세금환급',
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
