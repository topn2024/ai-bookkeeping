import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 零基预算分类数据模型
class ZeroBasedBudgetCategory {
  final String id;
  final String name;
  final String iconCodePoint;
  final int colorValue;
  final double amount;
  final double percentage;
  final String hint;
  final bool isHighlighted;

  ZeroBasedBudgetCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.amount,
    required this.percentage,
    required this.hint,
    this.isHighlighted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'amount': amount,
      'percentage': percentage,
      'hint': hint,
      'isHighlighted': isHighlighted,
    };
  }

  factory ZeroBasedBudgetCategory.fromJson(Map<String, dynamic> json) {
    return ZeroBasedBudgetCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as String,
      colorValue: json['colorValue'] as int,
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      hint: json['hint'] as String,
      isHighlighted: json['isHighlighted'] as bool? ?? false,
    );
  }

  IconData get icon {
    final codePoint = int.tryParse(iconCodePoint);
    return IconData(codePoint ?? 0xe24d, fontFamily: 'MaterialIcons');
  }

  Color get color => Color(colorValue);
}

/// 零基预算 Provider
class ZeroBasedBudgetNotifier extends StateNotifier<List<ZeroBasedBudgetCategory>> {
  static const String _storageKey = 'zero_based_budget_categories';

  ZeroBasedBudgetNotifier() : super([]) {
    _loadCategories();
  }

  /// 加载保存的预算分配
  Future<void> _loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        state = jsonList
            .map((json) => ZeroBasedBudgetCategory.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[ZeroBasedBudgetProvider] 加载预算分配失败: $e');
    }
  }

  /// 保存预算分配
  Future<void> saveCategories(List<ZeroBasedBudgetCategory> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(categories.map((c) => c.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
      state = categories;
      debugPrint('[ZeroBasedBudgetProvider] 已保存 ${categories.length} 个预算分类');
    } catch (e) {
      debugPrint('[ZeroBasedBudgetProvider] 保存预算分配失败: $e');
    }
  }

  /// 清除预算分配
  Future<void> clearCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      state = [];
      debugPrint('[ZeroBasedBudgetProvider] 已清除预算分配');
    } catch (e) {
      debugPrint('[ZeroBasedBudgetProvider] 清除预算分配失败: $e');
    }
  }
}

/// 零基预算 Provider 实例
final zeroBasedBudgetProvider = StateNotifierProvider<ZeroBasedBudgetNotifier, List<ZeroBasedBudgetCategory>>((ref) {
  return ZeroBasedBudgetNotifier();
});
