import 'package:flutter/material.dart';

/// 月度开支目标模型
/// 用于控制特定月份或分类的消费上限
class ExpenseTarget {
  final String id;
  final String userId;
  final String bookId;
  final String name;
  final String? description;
  final double maxAmount;  // 最高开支额度
  final String? categoryId;  // 关联分类（null表示总开支）
  final String? categoryName;  // 分类名称
  final int year;
  final int month;
  final IconData icon;
  final Color color;
  final int alertThreshold;  // 预警阈值（百分比）
  final bool enableNotifications;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 计算字段
  final double currentSpent;  // 当前已消费
  final double remaining;  // 剩余额度
  final double percentage;  // 消费百分比
  final bool isExceeded;  // 是否超支
  final bool isNearLimit;  // 是否接近上限

  ExpenseTarget({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.name,
    this.description,
    required this.maxAmount,
    this.categoryId,
    this.categoryName,
    required this.year,
    required this.month,
    required this.icon,
    required this.color,
    this.alertThreshold = 80,
    this.enableNotifications = true,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.currentSpent = 0,
    this.remaining = 0,
    this.percentage = 0,
    this.isExceeded = false,
    this.isNearLimit = false,
  });

  /// 目标月份显示
  String get monthDisplay => '$year年$month月';

  /// 状态颜色
  Color get statusColor {
    if (isExceeded) return Colors.red;
    if (isNearLimit) return Colors.orange;
    return Colors.green;
  }

  /// 状态文字
  String get statusText {
    if (isExceeded) return '已超支';
    if (isNearLimit) return '接近上限';
    return '正常';
  }

  /// 进度条颜色
  Color get progressColor {
    if (percentage >= 100) return Colors.red;
    if (percentage >= alertThreshold) return Colors.orange;
    if (percentage >= 50) return Colors.amber;
    return Colors.green;
  }

  /// 是否为总开支目标（不限分类）
  bool get isTotalTarget => categoryId == null;

  ExpenseTarget copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? name,
    String? description,
    double? maxAmount,
    String? categoryId,
    String? categoryName,
    int? year,
    int? month,
    IconData? icon,
    Color? color,
    int? alertThreshold,
    bool? enableNotifications,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? currentSpent,
    double? remaining,
    double? percentage,
    bool? isExceeded,
    bool? isNearLimit,
  }) {
    return ExpenseTarget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      description: description ?? this.description,
      maxAmount: maxAmount ?? this.maxAmount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      year: year ?? this.year,
      month: month ?? this.month,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      currentSpent: currentSpent ?? this.currentSpent,
      remaining: remaining ?? this.remaining,
      percentage: percentage ?? this.percentage,
      isExceeded: isExceeded ?? this.isExceeded,
      isNearLimit: isNearLimit ?? this.isNearLimit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'name': name,
      'description': description,
      'max_amount': maxAmount,
      'category_id': categoryId,
      'category_name': categoryName,
      'year': year,
      'month': month,
      'icon_code': icon.codePoint,
      'color_value': color.value,
      'alert_threshold': alertThreshold,
      'enable_notifications': enableNotifications,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'current_spent': currentSpent,
      'remaining': remaining,
      'percentage': percentage,
      'is_exceeded': isExceeded,
      'is_near_limit': isNearLimit,
    };
  }

  factory ExpenseTarget.fromMap(Map<String, dynamic> map) {
    return ExpenseTarget(
      id: map['id'],
      userId: map['user_id'],
      bookId: map['book_id'],
      name: map['name'],
      description: map['description'],
      maxAmount: (map['max_amount'] as num).toDouble(),
      categoryId: map['category_id'],
      categoryName: map['category_name'],
      year: map['year'],
      month: map['month'],
      icon: IconData(map['icon_code'] ?? 0xe8d4, fontFamily: 'MaterialIcons'),
      color: Color(map['color_value'] ?? 0xFF4CAF50),
      alertThreshold: map['alert_threshold'] ?? 80,
      enableNotifications: map['enable_notifications'] ?? true,
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      currentSpent: (map['current_spent'] as num?)?.toDouble() ?? 0,
      remaining: (map['remaining'] as num?)?.toDouble() ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
      isExceeded: map['is_exceeded'] ?? false,
      isNearLimit: map['is_near_limit'] ?? false,
    );
  }
}

/// 月度开支目标汇总
class ExpenseTargetSummary {
  final double totalLimit;
  final double totalSpent;
  final double totalRemaining;
  final double overallPercentage;
  final int activeCount;
  final int exceededCount;
  final int nearLimitCount;

  ExpenseTargetSummary({
    required this.totalLimit,
    required this.totalSpent,
    required this.totalRemaining,
    required this.overallPercentage,
    required this.activeCount,
    required this.exceededCount,
    required this.nearLimitCount,
  });

  factory ExpenseTargetSummary.fromMap(Map<String, dynamic> map) {
    return ExpenseTargetSummary(
      totalLimit: (map['total_limit'] as num).toDouble(),
      totalSpent: (map['total_spent'] as num).toDouble(),
      totalRemaining: (map['total_remaining'] as num).toDouble(),
      overallPercentage: (map['overall_percentage'] as num).toDouble(),
      activeCount: map['active_count'],
      exceededCount: map['exceeded_count'],
      nearLimitCount: map['near_limit_count'],
    );
  }

  /// 整体状态颜色
  Color get statusColor {
    if (exceededCount > 0) return Colors.red;
    if (nearLimitCount > 0) return Colors.orange;
    return Colors.green;
  }
}

/// 常用开支目标模板
class ExpenseTargetTemplates {
  static List<Map<String, dynamic>> get templates => [
    {
      'name': '月度总开支',
      'description': '控制每月总体消费',
      'icon': Icons.account_balance_wallet,
      'color': Colors.blue,
      'categoryId': null,
    },
    {
      'name': '餐饮开支',
      'description': '控制餐饮消费',
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'categoryName': '餐饮',
    },
    {
      'name': '购物开支',
      'description': '控制购物消费',
      'icon': Icons.shopping_bag,
      'color': Colors.pink,
      'categoryName': '购物',
    },
    {
      'name': '娱乐开支',
      'description': '控制娱乐消费',
      'icon': Icons.celebration,
      'color': Colors.purple,
      'categoryName': '娱乐',
    },
    {
      'name': '交通开支',
      'description': '控制交通消费',
      'icon': Icons.directions_car,
      'color': Colors.teal,
      'categoryName': '交通',
    },
  ];
}
