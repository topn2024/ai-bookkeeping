import 'currency.dart';

/// 汇率数据
class ExchangeRate {
  final CurrencyType fromCurrency;
  final CurrencyType toCurrency;
  final double rate;
  final DateTime updatedAt;
  final bool isManual; // 是否手动设置

  const ExchangeRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.updatedAt,
    this.isManual = true,
  });

  ExchangeRate copyWith({
    CurrencyType? fromCurrency,
    CurrencyType? toCurrency,
    double? rate,
    DateTime? updatedAt,
    bool? isManual,
  }) {
    return ExchangeRate(
      fromCurrency: fromCurrency ?? this.fromCurrency,
      toCurrency: toCurrency ?? this.toCurrency,
      rate: rate ?? this.rate,
      updatedAt: updatedAt ?? DateTime.now(),
      isManual: isManual ?? this.isManual,
    );
  }

  /// 生成汇率对的唯一键
  String get key => '${fromCurrency.name}_${toCurrency.name}';

  /// 反向汇率
  ExchangeRate get inverse => ExchangeRate(
        fromCurrency: toCurrency,
        toCurrency: fromCurrency,
        rate: 1 / rate,
        updatedAt: updatedAt,
        isManual: isManual,
      );

  /// 转换金额
  double convert(double amount) => amount * rate;

  Map<String, dynamic> toMap() {
    return {
      'fromCurrency': fromCurrency.index,
      'toCurrency': toCurrency.index,
      'rate': rate,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isManual': isManual,
    };
  }

  factory ExchangeRate.fromMap(Map<String, dynamic> map) {
    return ExchangeRate(
      fromCurrency: CurrencyType.values[map['fromCurrency'] as int],
      toCurrency: CurrencyType.values[map['toCurrency'] as int],
      rate: (map['rate'] as num).toDouble(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      isManual: map['isManual'] as bool? ?? true,
    );
  }
}

/// 默认汇率（以人民币为基准，参考汇率）
/// 这些是参考值，用户可以手动修改
class DefaultExchangeRates {
  static final Map<String, double> _ratesFromCNY = {
    'CNY_USD': 0.14,    // 1 CNY = 0.14 USD
    'CNY_EUR': 0.13,    // 1 CNY = 0.13 EUR
    'CNY_HKD': 1.09,    // 1 CNY = 1.09 HKD
    'CNY_JPY': 21.0,    // 1 CNY = 21 JPY
    'CNY_GBP': 0.11,    // 1 CNY = 0.11 GBP
    'CNY_KRW': 185.0,   // 1 CNY = 185 KRW
    'CNY_TWD': 4.4,     // 1 CNY = 4.4 TWD
  };

  /// 获取默认汇率列表（以CNY为基准）
  static List<ExchangeRate> getDefaultRates() {
    final now = DateTime.now();
    final rates = <ExchangeRate>[];

    // CNY 到其他货币
    for (final entry in _ratesFromCNY.entries) {
      final parts = entry.key.split('_');
      final from = CurrencyType.values.firstWhere(
        (c) => c.name.toUpperCase() == parts[0],
      );
      final to = CurrencyType.values.firstWhere(
        (c) => c.name.toUpperCase() == parts[1],
      );
      rates.add(ExchangeRate(
        fromCurrency: from,
        toCurrency: to,
        rate: entry.value,
        updatedAt: now,
        isManual: false,
      ));
    }

    return rates;
  }

  /// 获取两种货币之间的默认汇率
  static double? getRate(CurrencyType from, CurrencyType to) {
    if (from == to) return 1.0;

    final key = '${from.name.toUpperCase()}_${to.name.toUpperCase()}';
    if (_ratesFromCNY.containsKey(key)) {
      return _ratesFromCNY[key];
    }

    // 尝试反向查找
    final reverseKey = '${to.name.toUpperCase()}_${from.name.toUpperCase()}';
    if (_ratesFromCNY.containsKey(reverseKey)) {
      return 1 / _ratesFromCNY[reverseKey]!;
    }

    // 通过CNY作为中介计算
    if (from != CurrencyType.cny && to != CurrencyType.cny) {
      final fromToCny = getRate(from, CurrencyType.cny);
      final cnyToTo = getRate(CurrencyType.cny, to);
      if (fromToCny != null && cnyToTo != null) {
        return fromToCny * cnyToTo;
      }
    }

    return null;
  }
}

/// 多币种金额汇总
class MultiCurrencyAmount {
  final Map<CurrencyType, double> amounts;

  const MultiCurrencyAmount(this.amounts);

  /// 空金额
  static const empty = MultiCurrencyAmount({});

  /// 添加金额
  MultiCurrencyAmount add(CurrencyType currency, double amount) {
    final newAmounts = Map<CurrencyType, double>.from(amounts);
    newAmounts[currency] = (newAmounts[currency] ?? 0) + amount;
    return MultiCurrencyAmount(newAmounts);
  }

  /// 获取某货币的金额
  double getAmount(CurrencyType currency) => amounts[currency] ?? 0;

  /// 获取所有涉及的货币
  List<CurrencyType> get currencies => amounts.keys.toList();

  /// 是否只有单一货币
  bool get isSingleCurrency => amounts.length <= 1;

  /// 转换为单一货币（需要汇率）
  double toSingleCurrency(
    CurrencyType targetCurrency,
    double Function(CurrencyType from, CurrencyType to) getRate,
  ) {
    double total = 0;
    for (final entry in amounts.entries) {
      if (entry.key == targetCurrency) {
        total += entry.value;
      } else {
        total += entry.value * getRate(entry.key, targetCurrency);
      }
    }
    return total;
  }

  /// 格式化显示（显示所有货币金额）
  String format() {
    if (amounts.isEmpty) return '¥0.00';
    return amounts.entries.map((e) {
      final info = Currencies.get(e.key);
      return info.format(e.value);
    }).join(' + ');
  }
}
