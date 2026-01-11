import 'package:flutter/material.dart';
import 'account.dart';

/// 信用卡账户模型
class CreditCard {
  final String id;
  final String name;
  final double creditLimit;      // 信用额度
  final double usedAmount;       // 已用额度
  final int billDay;             // 账单日 (1-28)
  final int paymentDueDay;       // 还款日 (1-28)
  final double currentBill;      // 当期账单金额
  final double minPayment;       // 最低还款额
  final DateTime? lastBillDate;  // 上次账单日期
  final IconData icon;
  final Color color;
  final String? bankName;        // 发卡银行
  final String? cardNumber;      // 卡号后四位
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CreditCard({
    required this.id,
    required this.name,
    required this.creditLimit,
    this.usedAmount = 0,
    required this.billDay,
    required this.paymentDueDay,
    this.currentBill = 0,
    this.minPayment = 0,
    this.lastBillDate,
    required this.icon,
    required this.color,
    this.bankName,
    this.cardNumber,
    this.isEnabled = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// 可用额度
  double get availableCredit => creditLimit - usedAmount;

  /// 额度使用率
  double get usageRate => creditLimit > 0 ? usedAmount / creditLimit : 0;

  /// 是否额度紧张 (使用率 > 80%)
  bool get isNearLimit => usageRate > 0.8;

  /// 是否已超额
  bool get isOverLimit => usedAmount > creditLimit;

  /// 下一个账单日
  DateTime get nextBillDate {
    final now = DateTime.now();
    var nextBill = DateTime(now.year, now.month, billDay);
    if (nextBill.isBefore(now) || nextBill.isAtSameMomentAs(now)) {
      nextBill = DateTime(now.year, now.month + 1, billDay);
    }
    return nextBill;
  }

  /// 下一个还款日
  DateTime get nextPaymentDueDate {
    final billDate = nextBillDate;
    // 还款日在账单日之后
    if (paymentDueDay > billDay) {
      return DateTime(billDate.year, billDate.month, paymentDueDay);
    } else {
      return DateTime(billDate.year, billDate.month + 1, paymentDueDay);
    }
  }

  /// 距离还款日天数
  int get daysUntilPayment {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = nextPaymentDueDate;
    return dueDate.difference(today).inDays;
  }

  /// 是否需要还款 (3天内)
  bool get isPaymentDueSoon => daysUntilPayment <= 3 && daysUntilPayment >= 0;

  /// 是否已逾期
  bool get isOverdue => daysUntilPayment < 0 && currentBill > 0;

  /// 显示名称
  String get displayName {
    if (cardNumber != null && cardNumber!.isNotEmpty) {
      return '$name (*$cardNumber)';
    }
    return name;
  }

  CreditCard copyWith({
    String? id,
    String? name,
    double? creditLimit,
    double? usedAmount,
    int? billDay,
    int? paymentDueDay,
    double? currentBill,
    double? minPayment,
    DateTime? lastBillDate,
    IconData? icon,
    Color? color,
    String? bankName,
    String? cardNumber,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditCard(
      id: id ?? this.id,
      name: name ?? this.name,
      creditLimit: creditLimit ?? this.creditLimit,
      usedAmount: usedAmount ?? this.usedAmount,
      billDay: billDay ?? this.billDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      currentBill: currentBill ?? this.currentBill,
      minPayment: minPayment ?? this.minPayment,
      lastBillDate: lastBillDate ?? this.lastBillDate,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      bankName: bankName ?? this.bankName,
      cardNumber: cardNumber ?? this.cardNumber,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'creditLimit': creditLimit,
      'usedAmount': usedAmount,
      'billDay': billDay,
      'paymentDueDay': paymentDueDay,
      'currentBill': currentBill,
      'minPayment': minPayment,
      'lastBillDate': lastBillDate?.millisecondsSinceEpoch,
      'iconCode': icon.codePoint,
      'colorValue': color.toARGB32(),
      'bankName': bankName,
      'cardNumber': cardNumber,
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      id: map['id'],
      name: map['name'],
      creditLimit: (map['creditLimit'] as num).toDouble(),
      usedAmount: (map['usedAmount'] as num).toDouble(),
      billDay: map['billDay'],
      paymentDueDay: map['paymentDueDay'],
      currentBill: (map['currentBill'] as num).toDouble(),
      minPayment: (map['minPayment'] as num).toDouble(),
      lastBillDate: map['lastBillDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastBillDate'])
          : null,
      icon: IconData(map['iconCode'], fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue']),
      bankName: map['bankName'],
      cardNumber: map['cardNumber'],
      isEnabled: map['isEnabled'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
    );
  }

  /// 转换为普通账户（用于记账选择）
  Account toAccount() {
    return Account(
      id: id,
      name: displayName,
      type: AccountType.creditCard,
      balance: -usedAmount, // 信用卡余额为负数表示欠款
      icon: icon,
      color: color,
      createdAt: createdAt,
    );
  }
}

/// 预设银行列表
class DefaultBanks {
  static const List<String> banks = [
    '工商银行',
    '建设银行',
    '农业银行',
    '中国银行',
    '交通银行',
    '招商银行',
    '浦发银行',
    '民生银行',
    '兴业银行',
    '中信银行',
    '光大银行',
    '华夏银行',
    '平安银行',
    '广发银行',
    '邮储银行',
    '其他',
  ];
}
