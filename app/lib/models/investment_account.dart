import 'package:flutter/material.dart';

/// 投资类型
enum InvestmentType {
  fund,       // 基金
  stock,      // 股票
  bond,       // 债券
  deposit,    // 定期存款
  crypto,     // 加密货币
  gold,       // 黄金
  realEstate, // 房地产
  other,      // 其他
}

/// 投资账户
class InvestmentAccount {
  final String id;
  final String name;
  final InvestmentType type;
  final double principal;       // 本金（投入金额）
  final double currentValue;    // 当前市值
  final String? platform;       // 平台（如：支付宝、天天基金等）
  final String? code;           // 代码（基金代码、股票代码）
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvestmentAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.principal,
    required this.currentValue,
    this.platform,
    this.code,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 收益金额
  double get profit => currentValue - principal;

  /// 收益率
  double get profitRate => principal > 0 ? (profit / principal) * 100 : 0;

  /// 是否盈利
  bool get isProfitable => profit >= 0;

  InvestmentAccount copyWith({
    String? id,
    String? name,
    InvestmentType? type,
    double? principal,
    double? currentValue,
    String? platform,
    String? code,
    String? note,
    DateTime? updatedAt,
  }) {
    return InvestmentAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      principal: principal ?? this.principal,
      currentValue: currentValue ?? this.currentValue,
      platform: platform ?? this.platform,
      code: code ?? this.code,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'principal': principal,
      'currentValue': currentValue,
      'platform': platform,
      'code': code,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InvestmentAccount.fromJson(Map<String, dynamic> json) {
    return InvestmentAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      type: InvestmentType.values[json['type'] as int],
      principal: (json['principal'] as num).toDouble(),
      currentValue: (json['currentValue'] as num).toDouble(),
      platform: json['platform'] as String?,
      code: json['code'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// 投资类型工具
class InvestmentTypeUtils {
  static String getName(InvestmentType type) {
    switch (type) {
      case InvestmentType.fund:
        return '基金';
      case InvestmentType.stock:
        return '股票';
      case InvestmentType.bond:
        return '债券';
      case InvestmentType.deposit:
        return '定期存款';
      case InvestmentType.crypto:
        return '加密货币';
      case InvestmentType.gold:
        return '黄金';
      case InvestmentType.realEstate:
        return '房地产';
      case InvestmentType.other:
        return '其他';
    }
  }

  static IconData getIcon(InvestmentType type) {
    switch (type) {
      case InvestmentType.fund:
        return Icons.pie_chart;
      case InvestmentType.stock:
        return Icons.candlestick_chart;
      case InvestmentType.bond:
        return Icons.receipt_long;
      case InvestmentType.deposit:
        return Icons.savings;
      case InvestmentType.crypto:
        return Icons.currency_bitcoin;
      case InvestmentType.gold:
        return Icons.brightness_5;
      case InvestmentType.realEstate:
        return Icons.home;
      case InvestmentType.other:
        return Icons.account_balance;
    }
  }

  static Color getColor(InvestmentType type) {
    switch (type) {
      case InvestmentType.fund:
        return const Color(0xFF2196F3);
      case InvestmentType.stock:
        return const Color(0xFFE91E63);
      case InvestmentType.bond:
        return const Color(0xFF9C27B0);
      case InvestmentType.deposit:
        return const Color(0xFF4CAF50);
      case InvestmentType.crypto:
        return const Color(0xFFFF9800);
      case InvestmentType.gold:
        return const Color(0xFFFFEB3B);
      case InvestmentType.realEstate:
        return const Color(0xFF795548);
      case InvestmentType.other:
        return const Color(0xFF607D8B);
    }
  }
}
