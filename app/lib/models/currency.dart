import 'package:flutter/material.dart';

/// 支持的货币类型
enum CurrencyType {
  cny, // 人民币
  usd, // 美元
  eur, // 欧元
  hkd, // 港币
  jpy, // 日元
  gbp, // 英镑
  krw, // 韩元
  twd, // 新台币
}

/// 货币信息
class CurrencyInfo {
  final CurrencyType type;
  final String code;      // ISO 4217代码
  final String symbol;    // 货币符号
  final String name;      // 中文名称
  final String nameEn;    // 英文名称
  final int decimalDigits; // 小数位数
  final String flag;      // 国旗emoji

  const CurrencyInfo({
    required this.type,
    required this.code,
    required this.symbol,
    required this.name,
    required this.nameEn,
    this.decimalDigits = 2,
    required this.flag,
  });

  /// 格式化金额
  String format(double amount, {bool showSymbol = true, bool showCode = false}) {
    String formatted;

    if (decimalDigits == 0) {
      formatted = amount.round().toString();
    } else {
      formatted = amount.toStringAsFixed(decimalDigits);
    }

    // 添加千分位分隔符
    final parts = formatted.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    formatted = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;

    if (showCode) {
      return '$code $formatted';
    } else if (showSymbol) {
      return '$symbol$formatted';
    }
    return formatted;
  }

  /// 格式化金额（简化版，大数字显示为万/k/M）
  String formatCompact(double amount, {bool showSymbol = true}) {
    String formatted;

    if (type == CurrencyType.cny || type == CurrencyType.jpy ||
        type == CurrencyType.krw || type == CurrencyType.twd) {
      // 亚洲货币使用"万"
      if (amount.abs() >= 100000000) {
        formatted = '${(amount / 100000000).toStringAsFixed(1)}亿';
      } else if (amount.abs() >= 10000) {
        formatted = '${(amount / 10000).toStringAsFixed(1)}万';
      } else {
        formatted = amount.toStringAsFixed(decimalDigits);
      }
    } else {
      // 西方货币使用K/M
      if (amount.abs() >= 1000000) {
        formatted = '${(amount / 1000000).toStringAsFixed(1)}M';
      } else if (amount.abs() >= 1000) {
        formatted = '${(amount / 1000).toStringAsFixed(1)}K';
      } else {
        formatted = amount.toStringAsFixed(decimalDigits);
      }
    }

    return showSymbol ? '$symbol$formatted' : formatted;
  }
}

/// 货币数据
class Currencies {
  static const Map<CurrencyType, CurrencyInfo> all = {
    CurrencyType.cny: CurrencyInfo(
      type: CurrencyType.cny,
      code: 'CNY',
      symbol: '¥',
      name: '人民币',
      nameEn: 'Chinese Yuan',
      decimalDigits: 2,
      flag: '🇨🇳',
    ),
    CurrencyType.usd: CurrencyInfo(
      type: CurrencyType.usd,
      code: 'USD',
      symbol: '\$',
      name: '美元',
      nameEn: 'US Dollar',
      decimalDigits: 2,
      flag: '🇺🇸',
    ),
    CurrencyType.eur: CurrencyInfo(
      type: CurrencyType.eur,
      code: 'EUR',
      symbol: '€',
      name: '欧元',
      nameEn: 'Euro',
      decimalDigits: 2,
      flag: '🇪🇺',
    ),
    CurrencyType.hkd: CurrencyInfo(
      type: CurrencyType.hkd,
      code: 'HKD',
      symbol: 'HK\$',
      name: '港币',
      nameEn: 'Hong Kong Dollar',
      decimalDigits: 2,
      flag: '🇭🇰',
    ),
    CurrencyType.jpy: CurrencyInfo(
      type: CurrencyType.jpy,
      code: 'JPY',
      symbol: '¥',
      name: '日元',
      nameEn: 'Japanese Yen',
      decimalDigits: 0,
      flag: '🇯🇵',
    ),
    CurrencyType.gbp: CurrencyInfo(
      type: CurrencyType.gbp,
      code: 'GBP',
      symbol: '£',
      name: '英镑',
      nameEn: 'British Pound',
      decimalDigits: 2,
      flag: '🇬🇧',
    ),
    CurrencyType.krw: CurrencyInfo(
      type: CurrencyType.krw,
      code: 'KRW',
      symbol: '₩',
      name: '韩元',
      nameEn: 'South Korean Won',
      decimalDigits: 0,
      flag: '🇰🇷',
    ),
    CurrencyType.twd: CurrencyInfo(
      type: CurrencyType.twd,
      code: 'TWD',
      symbol: 'NT\$',
      name: '新台币',
      nameEn: 'Taiwan Dollar',
      decimalDigits: 0,
      flag: '🇹🇼',
    ),
  };

  static CurrencyInfo get(CurrencyType type) => all[type]!;

  static CurrencyInfo getByCode(String code) {
    return all.values.firstWhere(
      (c) => c.code == code.toUpperCase(),
      orElse: () => all[CurrencyType.cny]!,
    );
  }

  static List<CurrencyInfo> get list => all.values.toList();
}
