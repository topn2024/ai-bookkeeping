import 'package:flutter/material.dart';
import 'transaction.dart';

class TransactionTemplate {
  final String id;
  final String name;
  final TransactionType type;
  final double? amount; // null means user needs to input
  final String category;
  final String? note;
  final String accountId;
  final String? toAccountId; // for transfer
  final IconData icon;
  final Color color;
  final int useCount;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  TransactionTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.amount,
    required this.category,
    this.note,
    required this.accountId,
    this.toAccountId,
    required this.icon,
    required this.color,
    this.useCount = 0,
    required this.createdAt,
    this.lastUsedAt,
  });

  TransactionTemplate copyWith({
    String? id,
    String? name,
    TransactionType? type,
    double? amount,
    String? category,
    String? note,
    String? accountId,
    String? toAccountId,
    IconData? icon,
    Color? color,
    int? useCount,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return TransactionTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  // Create a transaction from this template
  Transaction toTransaction({double? overrideAmount}) {
    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      amount: overrideAmount ?? amount ?? 0,
      category: category,
      note: note,
      date: DateTime.now(),
      accountId: accountId,
      toAccountId: toAccountId,
    );
  }

  String get typeName {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
    }
  }
}

// Default templates for common transactions
class DefaultTemplates {
  static List<TransactionTemplate> get templates => [
    TransactionTemplate(
      id: 'template_breakfast',
      name: '早餐',
      type: TransactionType.expense,
      amount: 15,
      category: '餐饮',
      accountId: 'wechat',
      icon: Icons.free_breakfast,
      color: Colors.orange,
      createdAt: DateTime.now(),
    ),
    TransactionTemplate(
      id: 'template_lunch',
      name: '午餐',
      type: TransactionType.expense,
      amount: 25,
      category: '餐饮',
      accountId: 'alipay',
      icon: Icons.lunch_dining,
      color: Colors.deepOrange,
      createdAt: DateTime.now(),
    ),
    TransactionTemplate(
      id: 'template_dinner',
      name: '晚餐',
      type: TransactionType.expense,
      amount: 30,
      category: '餐饮',
      accountId: 'alipay',
      icon: Icons.dinner_dining,
      color: Colors.red,
      createdAt: DateTime.now(),
    ),
    TransactionTemplate(
      id: 'template_coffee',
      name: '咖啡',
      type: TransactionType.expense,
      amount: 20,
      category: '餐饮',
      accountId: 'wechat',
      icon: Icons.coffee,
      color: Colors.brown,
      createdAt: DateTime.now(),
    ),
    TransactionTemplate(
      id: 'template_subway',
      name: '地铁',
      type: TransactionType.expense,
      amount: 5,
      category: '交通',
      accountId: 'alipay',
      icon: Icons.subway,
      color: Colors.blue,
      createdAt: DateTime.now(),
    ),
    TransactionTemplate(
      id: 'template_bus',
      name: '公交',
      type: TransactionType.expense,
      amount: 2,
      category: '交通',
      accountId: 'wechat',
      icon: Icons.directions_bus,
      color: Colors.green,
      createdAt: DateTime.now(),
    ),
  ];
}
