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

    // 交通子分类
    Category(id: 'transport_public', name: '公交地铁', icon: Icons.directions_subway, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 1),
    Category(id: 'transport_taxi', name: '打车', icon: Icons.local_taxi, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 2),
    Category(id: 'transport_fuel', name: '加油', icon: Icons.local_gas_station, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 3),
    Category(id: 'transport_parking', name: '停车', icon: Icons.local_parking, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 4),
    Category(id: 'transport_train', name: '火车', icon: Icons.train, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 5),
    Category(id: 'transport_flight', name: '飞机', icon: Icons.flight, color: Color(0xFF2196F3), isExpense: true, parentId: 'transport', sortOrder: 6),

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
    Category(id: 'medical_supplement', name: '保健品', icon: Icons.fitness_center, color: Color(0xFFF44336), isExpense: true, parentId: 'medical', sortOrder: 5),

    // 教育子分类
    Category(id: 'education_tuition', name: '学费', icon: Icons.school, color: Color(0xFF3F51B5), isExpense: true, parentId: 'education', sortOrder: 1),
    Category(id: 'education_books', name: '书籍', icon: Icons.menu_book, color: Color(0xFF3F51B5), isExpense: true, parentId: 'education', sortOrder: 2),
    Category(id: 'education_training', name: '培训', icon: Icons.psychology, color: Color(0xFF3F51B5), isExpense: true, parentId: 'education', sortOrder: 3),
    Category(id: 'education_exam', name: '考试', icon: Icons.quiz, color: Color(0xFF3F51B5), isExpense: true, parentId: 'education', sortOrder: 4),

    // 通讯子分类
    Category(id: 'communication_phone', name: '话费', icon: Icons.phone, color: Color(0xFF00BCD4), isExpense: true, parentId: 'communication', sortOrder: 1),
    Category(id: 'communication_internet', name: '网费', icon: Icons.wifi, color: Color(0xFF00BCD4), isExpense: true, parentId: 'communication', sortOrder: 2),
    Category(id: 'communication_subscription', name: '会员订阅', icon: Icons.subscriptions, color: Color(0xFF00BCD4), isExpense: true, parentId: 'communication', sortOrder: 3),

    // 服饰子分类
    Category(id: 'clothing_clothes', name: '衣服', icon: Icons.checkroom, color: Color(0xFFE91E63), isExpense: true, parentId: 'clothing', sortOrder: 1),
    Category(id: 'clothing_shoes', name: '鞋子', icon: Icons.ice_skating, color: Color(0xFFE91E63), isExpense: true, parentId: 'clothing', sortOrder: 2),
    Category(id: 'clothing_accessories', name: '配饰', icon: Icons.watch, color: Color(0xFFE91E63), isExpense: true, parentId: 'clothing', sortOrder: 3),

    // 美容子分类
    Category(id: 'beauty_skincare', name: '护肤', icon: Icons.spa, color: Color(0xFFFF4081), isExpense: true, parentId: 'beauty', sortOrder: 1),
    Category(id: 'beauty_cosmetics', name: '化妆品', icon: Icons.brush, color: Color(0xFFFF4081), isExpense: true, parentId: 'beauty', sortOrder: 2),
    Category(id: 'beauty_haircut', name: '美发', icon: Icons.content_cut, color: Color(0xFFFF4081), isExpense: true, parentId: 'beauty', sortOrder: 3),
    Category(id: 'beauty_nails', name: '美甲', icon: Icons.back_hand, color: Color(0xFFFF4081), isExpense: true, parentId: 'beauty', sortOrder: 4),
  ];

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
      id: 'other_income',
      name: '其他',
      icon: Icons.more_horiz,
      color: Color(0xFF9E9E9E),
      isExpense: false,
      sortOrder: 99,
    ),
  ];

  /// 获取所有分类（包含一级和二级）
  static List<Category> get allCategories => [
    ...expenseCategories,
    ...expenseSubCategories,
    ...incomeCategories,
  ];

  /// 获取所有支出分类（包含一级和二级）
  static List<Category> get allExpenseCategories => [
    ...expenseCategories,
    ...expenseSubCategories,
  ];

  /// 根据ID查找分类（包含子分类）
  static Category? findById(String id) {
    try {
      return allCategories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 获取指定父分类的所有子分类
  static List<Category> getSubCategories(String parentId) {
    return expenseSubCategories
        .where((c) => c.parentId == parentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 判断分类是否有子分类
  static bool hasSubCategories(String categoryId) {
    return expenseSubCategories.any((c) => c.parentId == categoryId);
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
