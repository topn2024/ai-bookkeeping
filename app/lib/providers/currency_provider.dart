import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';
import '../models/exchange_rate.dart';

/// 货币设置状态
class CurrencyState {
  final CurrencyType defaultCurrency;
  final bool showCurrencySymbol;
  final bool useCompactFormat;
  final Map<String, ExchangeRate> exchangeRates; // 汇率映射
  final DateTime? ratesUpdatedAt;

  const CurrencyState({
    this.defaultCurrency = CurrencyType.cny,
    this.showCurrencySymbol = true,
    this.useCompactFormat = false,
    this.exchangeRates = const {},
    this.ratesUpdatedAt,
  });

  CurrencyState copyWith({
    CurrencyType? defaultCurrency,
    bool? showCurrencySymbol,
    bool? useCompactFormat,
    Map<String, ExchangeRate>? exchangeRates,
    DateTime? ratesUpdatedAt,
  }) {
    return CurrencyState(
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
      useCompactFormat: useCompactFormat ?? this.useCompactFormat,
      exchangeRates: exchangeRates ?? this.exchangeRates,
      ratesUpdatedAt: ratesUpdatedAt ?? this.ratesUpdatedAt,
    );
  }

  /// 当前货币信息
  CurrencyInfo get currency => Currencies.get(defaultCurrency);

  /// 格式化金额
  String format(double amount, {bool? showSymbol, bool? compact}) {
    final symbol = showSymbol ?? showCurrencySymbol;
    final useCompact = compact ?? useCompactFormat;

    if (useCompact) {
      return currency.formatCompact(amount, showSymbol: symbol);
    }
    return currency.format(amount, showSymbol: symbol);
  }

  /// 格式化指定货币的金额
  String formatWithCurrency(double amount, CurrencyType currencyType, {bool? showSymbol, bool? compact}) {
    final info = Currencies.get(currencyType);
    final symbol = showSymbol ?? showCurrencySymbol;
    final useCompact = compact ?? useCompactFormat;

    if (useCompact) {
      return info.formatCompact(amount, showSymbol: symbol);
    }
    return info.format(amount, showSymbol: symbol);
  }
}

/// 货币设置Provider
class CurrencyNotifier extends Notifier<CurrencyState> {
  static const _keyDefaultCurrency = 'default_currency';
  static const _keyShowSymbol = 'show_currency_symbol';
  static const _keyCompactFormat = 'use_compact_format';
  static const _keyExchangeRates = 'exchange_rates';

  @override
  CurrencyState build() {
    _loadSettings();
    return const CurrencyState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final currencyIndex = prefs.getInt(_keyDefaultCurrency) ?? 0;
    final showSymbol = prefs.getBool(_keyShowSymbol) ?? true;
    final compactFormat = prefs.getBool(_keyCompactFormat) ?? false;

    // 加载汇率
    Map<String, ExchangeRate> rates = {};
    final ratesJson = prefs.getString(_keyExchangeRates);
    if (ratesJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(ratesJson);
        rates = decoded.map((key, value) =>
            MapEntry(key, ExchangeRate.fromMap(value as Map<String, dynamic>)));
      } catch (e) {
        // 解析失败，使用默认汇率
        rates = _initializeDefaultRates();
      }
    } else {
      // 初始化默认汇率
      rates = _initializeDefaultRates();
    }

    state = CurrencyState(
      defaultCurrency: CurrencyType.values[currencyIndex],
      showCurrencySymbol: showSymbol,
      useCompactFormat: compactFormat,
      exchangeRates: rates,
      ratesUpdatedAt: DateTime.now(),
    );
  }

  Map<String, ExchangeRate> _initializeDefaultRates() {
    final defaultRates = DefaultExchangeRates.getDefaultRates();
    final ratesMap = <String, ExchangeRate>{};
    for (final rate in defaultRates) {
      ratesMap[rate.key] = rate;
      // 同时添加反向汇率
      ratesMap[rate.inverse.key] = rate.inverse;
    }
    return ratesMap;
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultCurrency, state.defaultCurrency.index);
    await prefs.setBool(_keyShowSymbol, state.showCurrencySymbol);
    await prefs.setBool(_keyCompactFormat, state.useCompactFormat);
  }

  Future<void> _saveExchangeRates() async {
    final prefs = await SharedPreferences.getInstance();
    final ratesJson = jsonEncode(
      state.exchangeRates.map((key, value) => MapEntry(key, value.toMap())),
    );
    await prefs.setString(_keyExchangeRates, ratesJson);
  }

  /// 设置默认货币
  Future<void> setDefaultCurrency(CurrencyType currency) async {
    state = state.copyWith(defaultCurrency: currency);
    await _saveSettings();
  }

  /// 设置是否显示货币符号
  Future<void> setShowCurrencySymbol(bool show) async {
    state = state.copyWith(showCurrencySymbol: show);
    await _saveSettings();
  }

  /// 设置是否使用紧凑格式
  Future<void> setUseCompactFormat(bool compact) async {
    state = state.copyWith(useCompactFormat: compact);
    await _saveSettings();
  }

  /// 设置汇率
  Future<void> setExchangeRate(CurrencyType from, CurrencyType to, double rate) async {
    final newRate = ExchangeRate(
      fromCurrency: from,
      toCurrency: to,
      rate: rate,
      updatedAt: DateTime.now(),
      isManual: true,
    );

    final updatedRates = Map<String, ExchangeRate>.from(state.exchangeRates);
    updatedRates[newRate.key] = newRate;
    // 同时更新反向汇率
    updatedRates[newRate.inverse.key] = newRate.inverse;

    state = state.copyWith(
      exchangeRates: updatedRates,
      ratesUpdatedAt: DateTime.now(),
    );
    await _saveExchangeRates();
  }

  /// 批量设置汇率
  Future<void> setExchangeRates(List<ExchangeRate> rates) async {
    final updatedRates = Map<String, ExchangeRate>.from(state.exchangeRates);
    for (final rate in rates) {
      updatedRates[rate.key] = rate;
      updatedRates[rate.inverse.key] = rate.inverse;
    }

    state = state.copyWith(
      exchangeRates: updatedRates,
      ratesUpdatedAt: DateTime.now(),
    );
    await _saveExchangeRates();
  }

  /// 重置为默认汇率
  Future<void> resetToDefaultRates() async {
    final rates = _initializeDefaultRates();
    state = state.copyWith(
      exchangeRates: rates,
      ratesUpdatedAt: DateTime.now(),
    );
    await _saveExchangeRates();
  }

  /// 获取汇率
  double getExchangeRate(CurrencyType from, CurrencyType to) {
    if (from == to) return 1.0;

    final key = '${from.name}_${to.name}';
    if (state.exchangeRates.containsKey(key)) {
      return state.exchangeRates[key]!.rate;
    }

    // 尝试通过默认货币作为中介
    final defaultCurrency = state.defaultCurrency;
    if (from != defaultCurrency && to != defaultCurrency) {
      final fromToDefault = getExchangeRate(from, defaultCurrency);
      final defaultToTo = getExchangeRate(defaultCurrency, to);
      return fromToDefault * defaultToTo;
    }

    // 使用默认汇率
    return DefaultExchangeRates.getRate(from, to) ?? 1.0;
  }

  /// 转换金额
  double convertAmount(double amount, CurrencyType from, CurrencyType to) {
    return amount * getExchangeRate(from, to);
  }

  /// 获取指定货币对的汇率对象
  ExchangeRate? getExchangeRateObject(CurrencyType from, CurrencyType to) {
    final key = '${from.name}_${to.name}';
    return state.exchangeRates[key];
  }

  /// 获取所有汇率列表（以默认货币为基准）
  List<ExchangeRate> getAllRatesFromDefault() {
    final defaultCurrency = state.defaultCurrency;
    final rates = <ExchangeRate>[];

    for (final currency in CurrencyType.values) {
      if (currency == defaultCurrency) continue;
      final key = '${defaultCurrency.name}_${currency.name}';
      if (state.exchangeRates.containsKey(key)) {
        rates.add(state.exchangeRates[key]!);
      } else {
        // 创建一个临时汇率对象
        final rate = DefaultExchangeRates.getRate(defaultCurrency, currency) ?? 1.0;
        rates.add(ExchangeRate(
          fromCurrency: defaultCurrency,
          toCurrency: currency,
          rate: rate,
          updatedAt: DateTime.now(),
          isManual: false,
        ));
      }
    }

    return rates;
  }

  /// 当前货币信息
  CurrencyInfo get currency => state.currency;

  /// 货币符号
  String get symbol => state.currency.symbol;

  /// 格式化金额
  String format(double amount, {bool? showSymbol, bool? compact}) {
    return state.format(amount, showSymbol: showSymbol, compact: compact);
  }

  /// 格式化指定货币的金额
  String formatWithCurrency(double amount, CurrencyType currencyType, {bool? showSymbol, bool? compact}) {
    return state.formatWithCurrency(amount, currencyType, showSymbol: showSymbol, compact: compact);
  }

  /// 将多币种金额转换为默认货币
  double convertToDefault(MultiCurrencyAmount multiAmount) {
    return multiAmount.toSingleCurrency(
      state.defaultCurrency,
      (from, to) => getExchangeRate(from, to),
    );
  }
}

/// Provider
final currencyProvider = NotifierProvider<CurrencyNotifier, CurrencyState>(
  CurrencyNotifier.new,
);

/// 便捷访问当前货币信息
final currentCurrencyProvider = Provider<CurrencyInfo>((ref) {
  return ref.watch(currencyProvider).currency;
});

/// 汇率列表Provider
final exchangeRatesProvider = Provider<List<ExchangeRate>>((ref) {
  return ref.watch(currencyProvider.notifier).getAllRatesFromDefault();
});
