import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../services/locale_format_service.dart';

export '../../l10n/app_localizations.dart' show AppLanguage;
export '../../services/locale_format_service.dart' show
    CurrencyInfo,
    SymbolPosition,
    DateFormatType,
    TimeFormatType;

/// 统一格式化服务
///
/// 提供货币、日期时间、数字、百分比的本地化格式化功能。
/// 这是对 LocaleFormatService 的门面封装，提供更简洁的 API。
///
/// 使用方式：
/// ```dart
/// // 单例访问
/// final formatted = FormattingService.instance.formatCurrency(1234.56);
///
/// // 扩展方法
/// final amount = 99.9.toCurrency();
/// ```
class FormattingService {
  FormattingService._();

  /// 单例实例
  static final FormattingService instance = FormattingService._();

  /// 获取底层的 LocaleFormatService
  LocaleFormatService get _delegate => LocaleFormatService.instance;

  /// 设置当前语言
  void setLocale(AppLanguage language) {
    _delegate.setLanguage(language);
  }

  /// 获取当前语言
  AppLanguage get currentLocale => _delegate.currentLanguage;

  // ============ 货币格式化 ============

  /// 格式化货币金额
  ///
  /// [amount] 金额
  /// [currencyCode] 货币代码（如 'CNY', 'USD'），默认使用当前语言的默认货币
  /// [showSymbol] 是否显示货币符号，默认 true
  /// [decimalPlaces] 小数位数，null 表示使用货币默认值
  ///
  /// 示例：
  /// ```dart
  /// formatCurrency(1234.56) // "¥1,234.56"
  /// formatCurrency(1234.56, currencyCode: 'USD') // "$1,234.56"
  /// formatCurrency(1234.56, showSymbol: false) // "1,234.56"
  /// formatCurrency(1234.56, decimalPlaces: 0) // "¥1,235"
  /// ```
  String formatCurrency(
    double amount, {
    String? currencyCode,
    bool showSymbol = true,
    int? decimalPlaces,
  }) {
    if (decimalPlaces != null) {
      // 使用自定义小数位数
      final code = currencyCode ?? _delegate.getDefaultCurrencyForLanguage();
      final currency = LocaleFormatService.getCurrencyInfo(code) ??
          LocaleFormatService.getCurrencyInfo('CNY');

      // 四舍五入到指定小数位
      final roundedAmount = _roundToDecimalPlaces(amount, decimalPlaces);
      final formattedNumber = _formatNumberWithDecimals(roundedAmount, decimalPlaces);

      if (!showSymbol || currency == null) {
        return formattedNumber;
      }

      if (currency.symbolPosition == SymbolPosition.before) {
        return '${currency.symbol}$formattedNumber';
      } else {
        return '$formattedNumber${currency.symbol}';
      }
    }

    return _delegate.formatCurrency(
      amount,
      currencyCode: currencyCode,
      showSymbol: showSymbol,
    );
  }

  /// 格式化货币（紧凑格式）
  ///
  /// 用于显示大金额，如 "1.2万" 或 "1.2M"
  String formatCurrencyCompact(
    double amount, {
    String? currencyCode,
    bool showSymbol = true,
  }) {
    return _delegate.formatCurrency(
      amount,
      currencyCode: currencyCode,
      showSymbol: showSymbol,
      compact: true,
    );
  }

  // ============ 数字格式化 ============

  /// 格式化数字（带千位分隔符）
  ///
  /// [number] 数字
  /// [decimalPlaces] 小数位数，默认 2
  ///
  /// 示例：
  /// ```dart
  /// formatNumber(1234567.89) // "1,234,567.89"
  /// formatNumber(1234567.89, decimalPlaces: 0) // "1,234,568"
  /// ```
  String formatNumber(double number, {int decimalPlaces = 2}) {
    return _delegate.formatNumber(number, decimalDigits: decimalPlaces);
  }

  /// 格式化整数（带千位分隔符）
  String formatInteger(int number) {
    return _delegate.formatInteger(number);
  }

  /// 格式化紧凑数字
  ///
  /// 用于显示大数字，如 "1.2K" 或 "1.2万"
  String formatNumberCompact(double number) {
    return _delegate.formatCompactNumber(number);
  }

  // ============ 百分比格式化 ============

  /// 格式化百分比
  ///
  /// [value] 比例值（0-1 之间）
  /// [decimalPlaces] 小数位数，默认 1
  ///
  /// 示例：
  /// ```dart
  /// formatPercentage(0.1234) // "12.3%"
  /// formatPercentage(0.1234, decimalPlaces: 2) // "12.34%"
  /// ```
  String formatPercentage(double value, {int decimalPlaces = 1}) {
    return _delegate.formatPercentage(value, decimalDigits: decimalPlaces);
  }

  // ============ 日期时间格式化 ============

  /// 格式化日期
  ///
  /// [date] 日期
  /// [format] 格式类型，默认 medium
  ///
  /// 示例：
  /// ```dart
  /// formatDate(DateTime(2024, 1, 15)) // "2024年1月15日"
  /// formatDate(DateTime(2024, 1, 15), format: DateFormatType.short) // "1/15"
  /// ```
  String formatDate(DateTime date, {DateFormatType format = DateFormatType.medium}) {
    return _delegate.formatDate(date, format: format);
  }

  /// 格式化时间
  String formatTime(DateTime time, {TimeFormatType format = TimeFormatType.short}) {
    return _delegate.formatTime(time, format: format);
  }

  /// 格式化日期时间
  String formatDateTime(
    DateTime dateTime, {
    DateFormatType dateFormat = DateFormatType.medium,
    TimeFormatType timeFormat = TimeFormatType.short,
  }) {
    return _delegate.formatDateTime(
      dateTime,
      dateFormat: dateFormat,
      timeFormat: timeFormat,
    );
  }

  /// 格式化相对时间
  ///
  /// [dateTime] 日期时间
  ///
  /// 示例：
  /// ```dart
  /// formatRelativeTime(DateTime.now().subtract(Duration(minutes: 5))) // "5分钟前"
  /// ```
  String formatRelativeTime(DateTime dateTime) {
    return _delegate.formatRelativeTime(dateTime);
  }

  // ============ 工具方法 ============

  /// 获取货币信息
  CurrencyInfo? getCurrencyInfo(String currencyCode) {
    return LocaleFormatService.getCurrencyInfo(currencyCode);
  }

  /// 获取所有支持的货币
  List<CurrencyInfo> get supportedCurrencies => LocaleFormatService.supportedCurrencies;

  /// 获取当前语言的默认货币
  String get defaultCurrencyCode => _delegate.getDefaultCurrencyForLanguage();

  // ============ 私有方法 ============

  /// 四舍五入到指定小数位
  double _roundToDecimalPlaces(double value, int decimalPlaces) {
    final factor = _pow10(decimalPlaces);
    return (value * factor).round() / factor;
  }

  /// 计算 10 的幂
  double _pow10(int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  /// 格式化数字到指定小数位
  String _formatNumberWithDecimals(double number, int decimalPlaces) {
    final formatter = NumberFormat('#,##0', _delegate.localeCode);
    if (decimalPlaces > 0) {
      formatter.minimumFractionDigits = decimalPlaces;
      formatter.maximumFractionDigits = decimalPlaces;
    }
    return formatter.format(number);
  }
}

// ============ 扩展方法 ============

/// double 类型的格式化扩展
extension DoubleFormattingExtension on double {
  /// 格式化为货币
  ///
  /// [currencyCode] 货币代码
  /// [showSymbol] 是否显示货币符号
  ///
  /// 示例：
  /// ```dart
  /// 99.9.toCurrency() // "¥99.90"
  /// 99.9.toCurrency(currencyCode: 'USD') // "$99.90"
  /// ```
  String toCurrency({String? currencyCode, bool showSymbol = true}) {
    return FormattingService.instance.formatCurrency(
      this,
      currencyCode: currencyCode,
      showSymbol: showSymbol,
    );
  }

  /// 格式化为带千位分隔符的数字
  ///
  /// [decimalPlaces] 小数位数
  ///
  /// 示例：
  /// ```dart
  /// 1234567.89.toFormattedNumber() // "1,234,567.89"
  /// ```
  String toFormattedNumber({int decimalPlaces = 2}) {
    return FormattingService.instance.formatNumber(this, decimalPlaces: decimalPlaces);
  }

  /// 格式化为百分比
  ///
  /// [decimalPlaces] 小数位数
  ///
  /// 示例：
  /// ```dart
  /// 0.1234.toPercentage() // "12.3%"
  /// ```
  String toPercentage({int decimalPlaces = 1}) {
    return FormattingService.instance.formatPercentage(this, decimalPlaces: decimalPlaces);
  }

  /// 格式化为紧凑数字
  ///
  /// 示例：
  /// ```dart
  /// 1234567.0.toCompactNumber() // "123.5万" 或 "1.2M"
  /// ```
  String toCompactNumber() {
    return FormattingService.instance.formatNumberCompact(this);
  }
}

/// int 类型的格式化扩展
extension IntFormattingExtension on int {
  /// 格式化为货币
  String toCurrency({String? currencyCode, bool showSymbol = true}) {
    return toDouble().toCurrency(currencyCode: currencyCode, showSymbol: showSymbol);
  }

  /// 格式化为带千位分隔符的整数
  String toFormattedNumber() {
    return FormattingService.instance.formatInteger(this);
  }

  /// 格式化为紧凑数字
  String toCompactNumber() {
    return toDouble().toCompactNumber();
  }
}

/// DateTime 类型的格式化扩展
extension DateTimeFormattingExtension on DateTime {
  /// 格式化日期
  String toFormattedDate({DateFormatType format = DateFormatType.medium}) {
    return FormattingService.instance.formatDate(this, format: format);
  }

  /// 格式化时间
  String toFormattedTime({TimeFormatType format = TimeFormatType.short}) {
    return FormattingService.instance.formatTime(this, format: format);
  }

  /// 格式化日期时间
  String toFormattedDateTime({
    DateFormatType dateFormat = DateFormatType.medium,
    TimeFormatType timeFormat = TimeFormatType.short,
  }) {
    return FormattingService.instance.formatDateTime(
      this,
      dateFormat: dateFormat,
      timeFormat: timeFormat,
    );
  }

  /// 格式化为相对时间
  String toRelativeTime() {
    return FormattingService.instance.formatRelativeTime(this);
  }
}
