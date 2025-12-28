import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';

/// 货币设置状态
class CurrencyState {
  final CurrencyType defaultCurrency;
  final bool showCurrencySymbol;
  final bool useCompactFormat;

  const CurrencyState({
    this.defaultCurrency = CurrencyType.cny,
    this.showCurrencySymbol = true,
    this.useCompactFormat = false,
  });

  CurrencyState copyWith({
    CurrencyType? defaultCurrency,
    bool? showCurrencySymbol,
    bool? useCompactFormat,
  }) {
    return CurrencyState(
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
      useCompactFormat: useCompactFormat ?? this.useCompactFormat,
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
}

/// 货币设置Provider
class CurrencyNotifier extends Notifier<CurrencyState> {
  static const _keyDefaultCurrency = 'default_currency';
  static const _keyShowSymbol = 'show_currency_symbol';
  static const _keyCompactFormat = 'use_compact_format';

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

    state = CurrencyState(
      defaultCurrency: CurrencyType.values[currencyIndex],
      showCurrencySymbol: showSymbol,
      useCompactFormat: compactFormat,
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultCurrency, state.defaultCurrency.index);
    await prefs.setBool(_keyShowSymbol, state.showCurrencySymbol);
    await prefs.setBool(_keyCompactFormat, state.useCompactFormat);
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

  /// 当前货币信息
  CurrencyInfo get currency => state.currency;

  /// 货币符号
  String get symbol => state.currency.symbol;

  /// 格式化金额
  String format(double amount, {bool? showSymbol, bool? compact}) {
    return state.format(amount, showSymbol: showSymbol, compact: compact);
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
