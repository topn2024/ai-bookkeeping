import 'package:flutter/material.dart';
import 'currency.dart';

enum AccountType {
  cash,
  bankCard,
  creditCard,
  eWallet,
  investment,
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final IconData icon;
  final Color color;
  final bool isDefault;
  final DateTime createdAt;
  final CurrencyType currency; // 账户货币类型

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.color,
    this.isDefault = false,
    required this.createdAt,
    this.currency = CurrencyType.cny, // 默认人民币
  });

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    IconData? icon,
    Color? color,
    bool? isDefault,
    CurrencyType? currency,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      currency: currency ?? this.currency,
    );
  }

  /// 获取货币信息
  CurrencyInfo get currencyInfo => Currencies.get(currency);

  /// 格式化账户余额
  String get formattedBalance => currencyInfo.format(balance);
}

// Default accounts
class DefaultAccounts {
  static List<Account> get accounts => [
        Account(
          id: 'cash',
          name: '现金',
          type: AccountType.cash,
          balance: 0,
          icon: Icons.account_balance_wallet,
          color: const Color(0xFF4CAF50),
          isDefault: true,
          createdAt: DateTime.now(),
        ),
        Account(
          id: 'wechat',
          name: '微信',
          type: AccountType.eWallet,
          balance: 0,
          icon: Icons.chat,
          color: const Color(0xFF07C160),
          createdAt: DateTime.now(),
        ),
        Account(
          id: 'alipay',
          name: '支付宝',
          type: AccountType.eWallet,
          balance: 0,
          icon: Icons.account_balance,
          color: const Color(0xFF1677FF),
          createdAt: DateTime.now(),
        ),
        Account(
          id: 'bank',
          name: '银行卡',
          type: AccountType.bankCard,
          balance: 0,
          icon: Icons.credit_card,
          color: const Color(0xFF2196F3),
          createdAt: DateTime.now(),
        ),
      ];
}
