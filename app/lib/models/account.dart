import 'package:flutter/material.dart';
import 'currency.dart';
import '../services/account_localization_service.dart';

/// Color扩展：支持十六进制颜色转换
extension HexColor on Color {
  /// 转换为十六进制字符串
  String toHex() => '#${toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// 从十六进制字符串创建Color
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

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
  final bool isActive;
  final DateTime createdAt;
  final CurrencyType currency; // 账户货币类型
  final bool isCustom; // 是否为用户自定义账户

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    this.currency = CurrencyType.cny, // 默认人民币
    this.isCustom = false,
  });

  /// 获取本地化的账户名称
  ///
  /// 对于系统默认账户，返回当前语言的翻译
  /// 对于用户自定义账户，返回原始名称
  String get localizedName {
    if (isCustom) return name;
    return AccountLocalizationService.instance.getAccountName(id, originalName: name);
  }

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    IconData? icon,
    Color? color,
    bool? isDefault,
    bool? isActive,
    CurrencyType? currency,
    bool? isCustom,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      currency: currency ?? this.currency,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  /// 获取货币信息
  CurrencyInfo get currencyInfo => Currencies.get(currency);

  /// 格式化账户余额
  String get formattedBalance => currencyInfo.format(balance);

  /// 转换为Map用于序列化
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'balance': balance,
      'icon': icon.codePoint,
      'color': color.toHex(),
      'isDefault': isDefault ? 1 : 0,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'currency': currency.name,
      'isCustom': isCustom ? 1 : 0,
    };
  }

  /// 从Map创建Account
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AccountType.values[map['type'] as int],
      balance: (map['balance'] as num).toDouble(),
      icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      color: HexColor.fromHex(map['color'] as String),
      isDefault: map['isDefault'] == 1,
      isActive: map['isActive'] == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      currency: CurrencyType.values.firstWhere(
        (e) => e.name == map['currency'],
        orElse: () => CurrencyType.cny,
      ),
      isCustom: map['isCustom'] == 1,
    );
  }
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
