import 'package:flutter/material.dart';
import '../services/category_localization_service.dart';

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isExpense;
  final String? parentId;
  final int sortOrder;
  final bool isCustom;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isExpense,
    this.parentId,
    this.sortOrder = 0,
    this.isCustom = false,
  });

  /// 获取本地化的分类名称
  /// 根据设备区域自动选择语言（中文/英文/日文）
  String get localizedName {
    // 自定义分类使用原始名称
    if (isCustom) return name;
    return CategoryLocalizationService.instance.getCategoryName(id);
  }

  /// 获取指定语言的分类名称
  String getNameForLocale(String locale) {
    if (isCustom) return name;
    return CategoryLocalizationService.instance.getCategoryNameForLocale(id, locale);
  }

  Category copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    bool? isExpense,
    String? parentId,
    int? sortOrder,
    bool? isCustom,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isExpense: isExpense ?? this.isExpense,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}

// Default expense categories
class DefaultCategories {
  // ============ 一级支出分类 ============
  static const List<Category> expenseCategories = [
    Category(
      id: 'food',
      name: '餐饮',
      icon: Icons.restaurant,
      color: Color(0xFFE91E63),
      isExpense: true,
      sortOrder: 1,
    ),
    Category(
      id: 'transport',
      name: '交通',
      icon: Icons.directions_car,
      color: Color(0xFF2196F3),
      isExpense: true,
      sortOrder: 2,
    ),
    Category(
      id: 'shopping',
      name: '购物',
      icon: Icons.shopping_bag,
      color: Color(0xFFFF9800),
      isExpense: true,
      sortOrder: 3,
    ),
    Category(
      id: 'entertainment',
      name: '娱乐',
      icon: Icons.movie,
      color: Color(0xFF9C27B0),
      isExpense: true,
      sortOrder: 4,
    ),
    Category(
      id: 'housing',
      name: '居住',
      icon: Icons.home,
      color: Color(0xFF795548),
      isExpense: true,
      sortOrder: 5,
    ),
    Category(
      id: 'utilities',
      name: '水电燃气',
      icon: Icons.electrical_services,
      color: Color(0xFF607D8B),
      isExpense: true,
      sortOrder: 6,
    ),
    Category(
      id: 'medical',
      name: '医疗',
      icon: Icons.local_hospital,
      color: Color(0xFFF44336),
      isExpense: true,
      sortOrder: 7,
    ),
    Category(
      id: 'education',
      name: '教育',
      icon: Icons.school,
      color: Color(0xFF3F51B5),
      isExpense: true,
      sortOrder: 8,
    ),
    Category(
      id: 'communication',
      name: '通讯',
      icon: Icons.phone_android,
      color: Color(0xFF00BCD4),
      isExpense: true,
      sortOrder: 9,
    ),
    Category(
      id: 'clothing',
      name: '服饰',
      icon: Icons.checkroom,
      color: Color(0xFFE91E63),
      isExpense: true,
      sortOrder: 10,
    ),
    Category(
      id: 'beauty',
      name: '美容',
      icon: Icons.face,
      color: Color(0xFFFF4081),
      isExpense: true,
      sortOrder: 11,
    ),
    // 新增一级分类
    Category(
      id: 'subscription',
      name: '会员订阅',
      icon: Icons.subscriptions,
      color: Color(0xFF673AB7),
      isExpense: true,
      sortOrder: 12,
    ),
    Category(
      id: 'social',
      name: '人情往来',
      icon: Icons.people,
      color: Color(0xFFFF5722),
      isExpense: true,
      sortOrder: 13,
    ),
    Category(
      id: 'finance',
      name: '金融保险',
      icon: Icons.account_balance,
      color: Color(0xFF009688),
      isExpense: true,
      sortOrder: 14,
    ),
    Category(
      id: 'pet',
      name: '宠物',
      icon: Icons.pets,
      color: Color(0xFF8D6E63),
      isExpense: true,
      sortOrder: 15,
    ),
    Category(
      id: 'other_expense',
      name: '其他',
      icon: Icons.more_horiz,
      color: Color(0xFF9E9E9E),
      isExpense: true,
      sortOrder: 99,
    ),
  ];

  // ============ 二级支出子分类 ============
  static const List<Category> expenseSubCategories = [
    // 餐饮子分类
    Category(id: 'food_breakfast', name: '早餐', icon: Icons.free_breakfast, color: Color(0xFFE91E63), isExpense: true, parentId: 'food', sortOrder: 1),
    Category(id: 'food_lunch', name: '午餐', icon: Icons.lunch_dining, color: Color(0xFFE91E63), isExpense: true, parentId: 'food', sortOrder: 2),
    Category(id: 'food_dinner', name: '晚餐', icon: Icons.dinner_dining, color: Color(0xFFE91E63), isExpense: true, parentId: 'food', sortOrder: 3),
    Category(id: 'food_snack', name: '零食', icon: Icons.cookie, color: Color(0xFFE91E63), isExpense: true, parentId: 'food', sortOrder: 4),
    Category(id: 'food_drink', name: '饮料', icon: Icons.local_cafe, color: Color(0xFFE91E63), isExpense: true, parentId: 'food', sortOrder: 5),
    Category(id: 'food_delivery', name: '外卖', icon: Icons.delivery_dining, color: Color(0xFFE91E63), isExpense: true, parentId: 'food', sortOrder: 6),
    Category(id: 'food_fruit', name: '水果', icon: Icons.apple, color: Color(0xFFE91E63), isExpense: true, parentId: 'food', sortOrder: 7),

    // 交通子分类
    Category(id: 'transport_public', name: '公交地铁', icon: Icons.directions_subway, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 1),
    Category(id: 'transport_taxi', name: '打车', icon: Icons.local_taxi, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 2),
    Category(id: 'transport_fuel', name: '加油', icon: Icons.local_gas_station, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 3),
    Category(id: 'transport_parking', name: '停车', icon: Icons.local_parking, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 4),
    Category(id: 'transport_train', name: '火车', icon: Icons.train, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 5),
    Category(id: 'transport_flight', name: '飞机', icon: Icons.flight, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 6),
    Category(id: 'transport_ship', name: '轮船', icon: Icons.directions_boat, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 7),

    // 购物子分类
    Category(id: 'shopping_daily', name: '日用品', icon: Icons.shopping_cart, color: Color(0xFFFF9800), isExpense: true, parentId: 'shopping', sortOrder: 1),
    Category(id: 'shopping_digital', name: '数码产品', icon: Icons.devices, color: Color(0xFFFF9800), isExpense: true, parentId: 'shopping', sortOrder: 2),
    Category(id: 'shopping_appliance', name: '家电', icon: Icons.kitchen, color: Color(0xFFFF9800), isExpense: true, parentId: 'shopping', sortOrder: 3),
    Category(id: 'shopping_furniture', name: '家居', icon: Icons.chair, color: Color(0xFFFF9800), isExpense: true, parentId: 'shopping', sortOrder: 4),
    Category(id: 'shopping_gift', name: '礼物', icon: Icons.card_giftcard, color: Color(0xFFFF9800), isExpense: true, parentId: 'shopping', sortOrder: 5),

    // 娱乐子分类
    Category(id: 'entertainment_movie', name: '电影', icon: Icons.movie_creation, color: Color(0xFF9C27B0), isExpense: true, parentId: 'entertainment', sortOrder: 1),
    Category(id: 'entertainment_game', name: '游戏', icon: Icons.sports_esports, color: Color(0xFF9C27B0), isExpense: true, parentId: 'entertainment', sortOrder: 2),
    Category(id: 'entertainment_travel', name: '旅游', icon: Icons.flight_takeoff, color: Color(0xFF9C27B0), isExpense: true, parentId: 'entertainment', sortOrder: 3),
    Category(id: 'entertainment_sport', name: '运动', icon: Icons.sports_basketball, color: Color(0xFF9C27B0), isExpense: true, parentId: 'entertainment', sortOrder: 4),
    Category(id: 'entertainment_ktv', name: 'KTV', icon: Icons.mic, color: Color(0xFF9C27B0), isExpense: true, parentId: 'entertainment', sortOrder: 5),
    Category(id: 'entertainment_party', name: '聚会', icon: Icons.celebration, color: Color(0xFF9C27B0), isExpense: true, parentId: 'entertainment', sortOrder: 6),
    Category(id: 'entertainment_fitness', name: '健身', icon: Icons.fitness_center, color: Color(0xFF9C27B0), isExpense: true, parentId: 'entertainment', sortOrder: 7),

    // 居住子分类
    Category(id: 'housing_rent', name: '房租', icon: Icons.house, color: Color(0xFF795548), isExpense: true, parentId: 'housing', sortOrder: 1),
    Category(id: 'housing_mortgage', name: '房贷', icon: Icons.account_balance, color: Color(0xFF795548), isExpense: true, parentId: 'housing', sortOrder: 2),
    Category(id: 'housing_property', name: '物业费', icon: Icons.apartment, color: Color(0xFF795548), isExpense: true, parentId: 'housing', sortOrder: 3),
    Category(id: 'housing_repair', name: '维修', icon: Icons.build, color: Color(0xFF795548), isExpense: true, parentId: 'housing', sortOrder: 4),

    // 水电燃气子分类
    Category(id: 'utilities_electric', name: '电费', icon: Icons.bolt, color: Color(0xFF607D8B), isExpense: true, parentId: 'utilities', sortOrder: 1),
    Category(id: 'utilities_water', name: '水费', icon: Icons.water_drop, color: Color(0xFF607D8B), isExpense: true, parentId: 'utilities', sortOrder: 2),
    Category(id: 'utilities_gas', name: '燃气费', icon: Icons.local_fire_department, color: Color(0xFF607D8B), isExpense: true, parentId: 'utilities', sortOrder: 3),
    Category(id: 'utilities_heating', name: '暖气费', icon: Icons.thermostat, color: Color(0xFF607D8B), isExpense: true, parentId: 'utilities', sortOrder: 4),

    // 医疗子分类
    Category(id: 'medical_clinic', name: '门诊', icon: Icons.medical_services, color: Color(0xFFF44336), isExpense: true, parentId: 'medical', sortOrder: 1),
    Category(id: 'medical_medicine', name: '药品', icon: Icons.medication, color: Color(0xFFF44336), isExpense: true, parentId: 'medical', sortOrder: 2),
    Category(id: 'medical_hospital', name: '住院', icon: Icons.local_hospital, color: Color(0xFFF44336), isExpense: true, parentId: 'medical', sortOrder: 3),
    Category(id: 'medical_checkup', name: '体检', icon: Icons.health_and_safety, color: Color(0xFFF44336), isExpense: true, parentId: 'medical', sortOrder: 4),
    Category(id: 'medical_supplement', name: '保健品', icon: Icons.medical_information, color: Color(0xFFF44336), isExpense: true, parentId: 'medical', sortOrder: 5),

    // 教育子分类
    Category(id: 'education_tuition', name: '学费', icon: Icons.school, color: Color(0xFF3F51B5), isExpense: true, parentId: 'education', sortOrder: 1),
    Category(id: 'education_books', name: '书籍', icon: Icons.menu_book, color: Color(0xFF3F51B5), isExpense: true, parentId: 'education', sortOrder: 2),
    Category(id: 'education_training', name: '培训', icon: Icons.psychology, color: Color(0xFF3F51B5), isExpense: true, parentId: 'education', sortOrder: 3),
    Category(id: 'education_exam', name: '考试', icon: Icons.quiz, color: Color(0xFF3F51B5), isExpense: true, parentId: 'education', sortOrder: 4),

    // 通讯子分类
    Category(id: 'communication_phone', name: '话费', icon: Icons.phone, color: Color(0xFF00BCD4), isExpense: true, parentId: 'communication', sortOrder: 1),
    Category(id: 'communication_internet', name: '网费', icon: Icons.wifi, color: Color(0xFF00BCD4), isExpense: true, parentId: 'communication', sortOrder: 2),

    // 服饰子分类
    Category(id: 'clothing_clothes', name: '衣服', icon: Icons.checkroom, color: Color(0xFFE91E63), isExpense: true, parentId: 'clothing', sortOrder: 1),
    Category(id: 'clothing_shoes', name: '鞋子', icon: Icons.ice_skating, color: Color(0xFFE91E63), isExpense: true, parentId: 'clothing', sortOrder: 2),
    Category(id: 'clothing_accessories', name: '配饰', icon: Icons.watch, color: Color(0xFFE91E63), isExpense: true, parentId: 'clothing', sortOrder: 3),

    // 美容子分类
    Category(id: 'beauty_skincare', name: '护肤', icon: Icons.spa, color: Color(0xFFFF4081), isExpense: true, parentId: 'beauty', sortOrder: 1),
    Category(id: 'beauty_cosmetics', name: '化妆品', icon: Icons.brush, color: Color(0xFFFF4081), isExpense: true, parentId: 'beauty', sortOrder: 2),
    Category(id: 'beauty_haircut', name: '美发', icon: Icons.content_cut, color: Color(0xFFFF4081), isExpense: true, parentId: 'beauty', sortOrder: 3),
    Category(id: 'beauty_nails', name: '美甲', icon: Icons.back_hand, color: Color(0xFFFF4081), isExpense: true, parentId: 'beauty', sortOrder: 4),

    // 会员订阅子分类
    Category(id: 'subscription_video', name: '视频会员', icon: Icons.live_tv, color: Color(0xFF673AB7), isExpense: true, parentId: 'subscription', sortOrder: 1),
    Category(id: 'subscription_music', name: '音乐会员', icon: Icons.music_note, color: Color(0xFF673AB7), isExpense: true, parentId: 'subscription', sortOrder: 2),
    Category(id: 'subscription_cloud', name: '网盘会员', icon: Icons.cloud, color: Color(0xFF673AB7), isExpense: true, parentId: 'subscription', sortOrder: 3),
    Category(id: 'subscription_office', name: '办公会员', icon: Icons.description, color: Color(0xFF673AB7), isExpense: true, parentId: 'subscription', sortOrder: 4),
    Category(id: 'subscription_shopping', name: '购物会员', icon: Icons.shopping_bag, color: Color(0xFF673AB7), isExpense: true, parentId: 'subscription', sortOrder: 5),
    Category(id: 'subscription_reading', name: '阅读会员', icon: Icons.auto_stories, color: Color(0xFF673AB7), isExpense: true, parentId: 'subscription', sortOrder: 6),
    Category(id: 'subscription_game', name: '游戏会员', icon: Icons.sports_esports, color: Color(0xFF673AB7), isExpense: true, parentId: 'subscription', sortOrder: 7),
    Category(id: 'subscription_tool', name: '工具订阅', icon: Icons.build_circle, color: Color(0xFF673AB7), isExpense: true, parentId: 'subscription', sortOrder: 8),

    // 人情往来子分类
    Category(id: 'social_gift_money', name: '份子钱', icon: Icons.money, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 1),
    Category(id: 'social_festival', name: '节日送礼', icon: Icons.card_giftcard, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 2),
    Category(id: 'social_treat', name: '请客吃饭', icon: Icons.restaurant, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 3),
    Category(id: 'social_redpacket', name: '红包支出', icon: Icons.redeem, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 4),
    Category(id: 'social_visit', name: '探病慰问', icon: Icons.favorite, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 5),
    Category(id: 'social_thanks', name: '感谢答谢', icon: Icons.volunteer_activism, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 6),
    Category(id: 'social_elder', name: '孝敬长辈', icon: Icons.elderly, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 7),
    Category(id: 'social_repay', name: '还人钱物', icon: Icons.currency_exchange, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 8),
    Category(id: 'social_charity', name: '慈善捐助', icon: Icons.volunteer_activism, color: Color(0xFFFF5722), isExpense: true, parentId: 'social', sortOrder: 9),

    // 金融保险子分类
    Category(id: 'finance_life_insurance', name: '人寿保险', icon: Icons.health_and_safety, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 1),
    Category(id: 'finance_medical_insurance', name: '医疗保险', icon: Icons.local_hospital, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 2),
    Category(id: 'finance_car_insurance', name: '车险', icon: Icons.directions_car, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 3),
    Category(id: 'finance_property_insurance', name: '财产保险', icon: Icons.home, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 4),
    Category(id: 'finance_accident_insurance', name: '意外险', icon: Icons.emergency, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 5),
    Category(id: 'finance_loan_interest', name: '贷款利息', icon: Icons.percent, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 6),
    Category(id: 'finance_fee', name: '手续费', icon: Icons.receipt, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 7),
    Category(id: 'finance_penalty', name: '罚款滞纳金', icon: Icons.gavel, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 8),
    Category(id: 'finance_investment_loss', name: '投资亏损', icon: Icons.trending_down, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 9),
    Category(id: 'finance_mortgage', name: '按揭还款', icon: Icons.account_balance, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 10),
    Category(id: 'finance_tax', name: '消费税收', icon: Icons.receipt_long, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 11),
    Category(id: 'finance_lost', name: '意外丢失', icon: Icons.report_problem, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 12),
    Category(id: 'finance_bad_debt', name: '烂账损失', icon: Icons.money_off, color: Color(0xFF009688), isExpense: true, parentId: 'finance', sortOrder: 13),

    // 宠物子分类
    Category(id: 'pet_food', name: '宠物食品', icon: Icons.set_meal, color: Color(0xFF8D6E63), isExpense: true, parentId: 'pet', sortOrder: 1),
    Category(id: 'pet_supplies', name: '宠物用品', icon: Icons.inventory_2, color: Color(0xFF8D6E63), isExpense: true, parentId: 'pet', sortOrder: 2),
    Category(id: 'pet_medical', name: '宠物医疗', icon: Icons.local_hospital, color: Color(0xFF8D6E63), isExpense: true, parentId: 'pet', sortOrder: 3),
    Category(id: 'pet_grooming', name: '宠物美容', icon: Icons.content_cut, color: Color(0xFF8D6E63), isExpense: true, parentId: 'pet', sortOrder: 4),
    Category(id: 'pet_boarding', name: '宠物寄养', icon: Icons.house, color: Color(0xFF8D6E63), isExpense: true, parentId: 'pet', sortOrder: 5),
    Category(id: 'pet_insurance', name: '宠物保险', icon: Icons.verified_user, color: Color(0xFF8D6E63), isExpense: true, parentId: 'pet', sortOrder: 6),
  ];

  // ============ 一级收入分类 ============
  static const List<Category> incomeCategories = [
    Category(
      id: 'salary',
      name: '工资',
      icon: Icons.work,
      color: Color(0xFF4CAF50),
      isExpense: false,
      sortOrder: 1,
    ),
    Category(
      id: 'bonus',
      name: '奖金',
      icon: Icons.card_giftcard,
      color: Color(0xFF8BC34A),
      isExpense: false,
      sortOrder: 2,
    ),
    Category(
      id: 'investment',
      name: '投资收益',
      icon: Icons.trending_up,
      color: Color(0xFF00BCD4),
      isExpense: false,
      sortOrder: 3,
    ),
    Category(
      id: 'parttime',
      name: '兼职',
      icon: Icons.access_time,
      color: Color(0xFF03A9F4),
      isExpense: false,
      sortOrder: 4,
    ),
    Category(
      id: 'redpacket',
      name: '红包',
      icon: Icons.redeem,
      color: Color(0xFFF44336),
      isExpense: false,
      sortOrder: 5,
    ),
    Category(
      id: 'reimburse',
      name: '报销',
      icon: Icons.receipt_long,
      color: Color(0xFF673AB7),
      isExpense: false,
      sortOrder: 6,
    ),
    Category(
      id: 'business',
      name: '经营所得',
      icon: Icons.storefront,
      color: Color(0xFFFF9800),
      isExpense: false,
      sortOrder: 7,
    ),
    Category(
      id: 'other_income',
      name: '其他',
      icon: Icons.more_horiz,
      color: Color(0xFF9E9E9E),
      isExpense: false,
      sortOrder: 99,
    ),
  ];

  // ============ 二级收入子分类 ============
  static const List<Category> incomeSubCategories = [
    // 工资子分类
    Category(id: 'salary_base', name: '基本工资', icon: Icons.attach_money, color: Color(0xFF4CAF50), isExpense: false, parentId: 'salary', sortOrder: 1),
    Category(id: 'salary_performance', name: '绩效奖金', icon: Icons.trending_up, color: Color(0xFF4CAF50), isExpense: false, parentId: 'salary', sortOrder: 2),
    Category(id: 'salary_overtime', name: '加班费', icon: Icons.access_time, color: Color(0xFF4CAF50), isExpense: false, parentId: 'salary', sortOrder: 3),
    Category(id: 'salary_annual', name: '年终奖', icon: Icons.celebration, color: Color(0xFF4CAF50), isExpense: false, parentId: 'salary', sortOrder: 4),

    // 奖金子分类
    Category(id: 'bonus_project', name: '项目奖金', icon: Icons.work, color: Color(0xFF8BC34A), isExpense: false, parentId: 'bonus', sortOrder: 1),
    Category(id: 'bonus_quarterly', name: '季度奖', icon: Icons.calendar_today, color: Color(0xFF8BC34A), isExpense: false, parentId: 'bonus', sortOrder: 2),
    Category(id: 'bonus_attendance', name: '全勤奖', icon: Icons.check_circle, color: Color(0xFF8BC34A), isExpense: false, parentId: 'bonus', sortOrder: 3),
    Category(id: 'bonus_other', name: '其他奖励', icon: Icons.stars, color: Color(0xFF8BC34A), isExpense: false, parentId: 'bonus', sortOrder: 4),

    // 投资收益子分类
    Category(id: 'investment_stock', name: '股票收益', icon: Icons.show_chart, color: Color(0xFF00BCD4), isExpense: false, parentId: 'investment', sortOrder: 1),
    Category(id: 'investment_fund', name: '基金收益', icon: Icons.pie_chart, color: Color(0xFF00BCD4), isExpense: false, parentId: 'investment', sortOrder: 2),
    Category(id: 'investment_interest', name: '理财利息', icon: Icons.savings, color: Color(0xFF00BCD4), isExpense: false, parentId: 'investment', sortOrder: 3),
    Category(id: 'investment_dividend', name: '分红', icon: Icons.account_balance, color: Color(0xFF00BCD4), isExpense: false, parentId: 'investment', sortOrder: 4),
    Category(id: 'investment_rental', name: '房租收入', icon: Icons.house, color: Color(0xFF00BCD4), isExpense: false, parentId: 'investment', sortOrder: 5),
    Category(id: 'investment_lottery', name: '中奖', icon: Icons.emoji_events, color: Color(0xFF00BCD4), isExpense: false, parentId: 'investment', sortOrder: 6),
    Category(id: 'investment_windfall', name: '意外来钱', icon: Icons.auto_awesome, color: Color(0xFF00BCD4), isExpense: false, parentId: 'investment', sortOrder: 7),

    // 兼职子分类
    Category(id: 'parttime_salary', name: '兼职工资', icon: Icons.work_outline, color: Color(0xFF03A9F4), isExpense: false, parentId: 'parttime', sortOrder: 1),
    Category(id: 'parttime_freelance', name: '自由职业', icon: Icons.computer, color: Color(0xFF03A9F4), isExpense: false, parentId: 'parttime', sortOrder: 2),
    Category(id: 'parttime_manuscript', name: '稿费', icon: Icons.edit, color: Color(0xFF03A9F4), isExpense: false, parentId: 'parttime', sortOrder: 3),
    Category(id: 'parttime_consulting', name: '咨询费', icon: Icons.support_agent, color: Color(0xFF03A9F4), isExpense: false, parentId: 'parttime', sortOrder: 4),

    // 红包子分类
    Category(id: 'redpacket_wechat', name: '微信红包', icon: Icons.chat_bubble, color: Color(0xFFF44336), isExpense: false, parentId: 'redpacket', sortOrder: 1),
    Category(id: 'redpacket_alipay', name: '支付宝红包', icon: Icons.payment, color: Color(0xFFF44336), isExpense: false, parentId: 'redpacket', sortOrder: 2),
    Category(id: 'redpacket_festival', name: '节日红包', icon: Icons.celebration, color: Color(0xFFF44336), isExpense: false, parentId: 'redpacket', sortOrder: 3),
    Category(id: 'redpacket_gift', name: '礼金收入', icon: Icons.card_giftcard, color: Color(0xFFF44336), isExpense: false, parentId: 'redpacket', sortOrder: 4),

    // 报销子分类
    Category(id: 'reimburse_transport', name: '交通报销', icon: Icons.directions_car, color: Color(0xFF673AB7), isExpense: false, parentId: 'reimburse', sortOrder: 1),
    Category(id: 'reimburse_food', name: '餐饮报销', icon: Icons.restaurant, color: Color(0xFF673AB7), isExpense: false, parentId: 'reimburse', sortOrder: 2),
    Category(id: 'reimburse_travel', name: '差旅报销', icon: Icons.flight, color: Color(0xFF673AB7), isExpense: false, parentId: 'reimburse', sortOrder: 3),
    Category(id: 'reimburse_medical', name: '医疗报销', icon: Icons.local_hospital, color: Color(0xFF673AB7), isExpense: false, parentId: 'reimburse', sortOrder: 4),

    // 经营所得子分类
    Category(id: 'business_sales', name: '营业收入', icon: Icons.point_of_sale, color: Color(0xFFFF9800), isExpense: false, parentId: 'business', sortOrder: 1),
    Category(id: 'business_service', name: '服务收入', icon: Icons.handyman, color: Color(0xFFFF9800), isExpense: false, parentId: 'business', sortOrder: 2),
    Category(id: 'business_commission', name: '佣金提成', icon: Icons.percent, color: Color(0xFFFF9800), isExpense: false, parentId: 'business', sortOrder: 3),
    Category(id: 'business_resale', name: '代购收入', icon: Icons.shopping_cart, color: Color(0xFFFF9800), isExpense: false, parentId: 'business', sortOrder: 4),
    Category(id: 'business_rental', name: '租赁收入', icon: Icons.house, color: Color(0xFFFF9800), isExpense: false, parentId: 'business', sortOrder: 5),
    Category(id: 'business_knowledge', name: '知识付费', icon: Icons.school, color: Color(0xFFFF9800), isExpense: false, parentId: 'business', sortOrder: 6),
    Category(id: 'business_ad', name: '广告收入', icon: Icons.campaign, color: Color(0xFFFF9800), isExpense: false, parentId: 'business', sortOrder: 7),
    Category(id: 'business_refund', name: '退税返现', icon: Icons.money, color: Color(0xFFFF9800), isExpense: false, parentId: 'business', sortOrder: 8),
  ];

  /// 获取所有分类（包含一级和二级）
  static List<Category> get allCategories => [
    ...expenseCategories,
    ...expenseSubCategories,
    ...incomeCategories,
    ...incomeSubCategories,
  ];

  /// 获取所有分类ID集合（用于AI分类验证等场景）
  /// 这是分类ID的唯一来源，其他地方应引用此集合
  static Set<String> get allCategoryIds => allCategories.map((c) => c.id).toSet();

  /// 获取所有支出分类（包含一级和二级）
  static List<Category> get allExpenseCategories => [
    ...expenseCategories,
    ...expenseSubCategories,
  ];

  /// 获取所有收入分类（包含一级和二级）
  static List<Category> get allIncomeCategories => [
    ...incomeCategories,
    ...incomeSubCategories,
  ];

  /// 根据ID或名称查找分类（包含子分类）
  /// 优先按ID匹配，如果找不到则按名称匹配
  static Category? findById(String idOrName) {
    try {
      // 首先尝试按ID精确匹配
      return allCategories.firstWhere((c) => c.id == idOrName);
    } catch (e) {
      // 如果ID找不到，尝试按名称匹配
      try {
        return allCategories.firstWhere((c) => c.name == idOrName);
      } catch (e) {
        return null;
      }
    }
  }

  /// 根据名称查找分类
  static Category? findByName(String name) {
    try {
      return allCategories.firstWhere((c) => c.name == name);
    } catch (e) {
      return null;
    }
  }

  /// 获取指定父分类的所有子分类（支持支出和收入）
  static List<Category> getSubCategories(String parentId) {
    final allSubs = [...expenseSubCategories, ...incomeSubCategories];
    return allSubs
        .where((c) => c.parentId == parentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 判断分类是否有子分类
  static bool hasSubCategories(String categoryId) {
    final allSubs = [...expenseSubCategories, ...incomeSubCategories];
    return allSubs.any((c) => c.parentId == categoryId);
  }

  /// 获取分类的父分类
  static Category? getParentCategory(String categoryId) {
    final category = findById(categoryId);
    if (category?.parentId == null) return null;
    return findById(category!.parentId!);
  }

  /// 获取分类的完整路径名称（如：餐饮 > 早餐）
  static String getFullPath(String categoryId) {
    final category = findById(categoryId);
    if (category == null) return categoryId;

    final parent = getParentCategory(categoryId);
    if (parent != null) {
      return '${parent.localizedName} > ${category.localizedName}';
    }
    return category.localizedName;
  }
}
