import 'package:flutter/material.dart';

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

  static Category? findById(String id) {
    try {
      return [...expenseCategories, ...incomeCategories]
          .firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }
}
