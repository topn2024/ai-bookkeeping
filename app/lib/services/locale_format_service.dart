import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

/// 本地化格式化服务
///
/// 提供货币、日期时间、数字的本地化格式化功能
/// 支持中文、英文、日文、韩文
class LocaleFormatService {
  LocaleFormatService._();
  static final LocaleFormatService instance = LocaleFormatService._();

  AppLanguage _currentLanguage = AppLanguage.zhCN;

  /// 获取当前语言
  AppLanguage get currentLanguage => _currentLanguage;

  /// 设置当前语言
  void setLanguage(AppLanguage language) {
    _currentLanguage = language;
  }

  /// 获取当前语言的 Locale 代码
  String get localeCode {
    switch (_currentLanguage) {
      case AppLanguage.zhCN:
        return 'zh_CN';
      case AppLanguage.zhTW:
        return 'zh_TW';
      case AppLanguage.en:
        return 'en_US';
      case AppLanguage.ja:
        return 'ja_JP';
      case AppLanguage.ko:
        return 'ko_KR';
    }
  }

  // ============ 货币格式化 ============

  /// 货币信息
  static const Map<String, CurrencyInfo> _currencies = {
    'CNY': CurrencyInfo(code: 'CNY', symbol: '¥', name: '人民币', namePlural: '元', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'USD': CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', namePlural: 'US dollars', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'EUR': CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro', namePlural: 'euros', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'JPY': CurrencyInfo(code: 'JPY', symbol: '¥', name: '日本円', namePlural: '円', decimalDigits: 0, symbolPosition: SymbolPosition.before),
    'KRW': CurrencyInfo(code: 'KRW', symbol: '₩', name: '원', namePlural: '원', decimalDigits: 0, symbolPosition: SymbolPosition.before),
    'GBP': CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound', namePlural: 'British pounds', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'HKD': CurrencyInfo(code: 'HKD', symbol: 'HK\$', name: '港元', namePlural: '港元', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'TWD': CurrencyInfo(code: 'TWD', symbol: 'NT\$', name: '新臺幣', namePlural: '元', decimalDigits: 0, symbolPosition: SymbolPosition.before),
    'SGD': CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', namePlural: 'Singapore dollars', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'AUD': CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', namePlural: 'Australian dollars', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'CAD': CurrencyInfo(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', namePlural: 'Canadian dollars', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'CHF': CurrencyInfo(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', namePlural: 'Swiss francs', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'INR': CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee', namePlural: 'Indian rupees', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'MYR': CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', namePlural: 'Malaysian ringgits', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'THB': CurrencyInfo(code: 'THB', symbol: '฿', name: 'Thai Baht', namePlural: 'Thai baht', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'VND': CurrencyInfo(code: 'VND', symbol: '₫', name: 'Vietnamese Dong', namePlural: 'Vietnamese dong', decimalDigits: 0, symbolPosition: SymbolPosition.after),
    'PHP': CurrencyInfo(code: 'PHP', symbol: '₱', name: 'Philippine Peso', namePlural: 'Philippine pesos', decimalDigits: 2, symbolPosition: SymbolPosition.before),
    'IDR': CurrencyInfo(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah', namePlural: 'Indonesian rupiahs', decimalDigits: 0, symbolPosition: SymbolPosition.before),
  };

  /// 获取所有支持的货币
  static List<CurrencyInfo> get supportedCurrencies => _currencies.values.toList();

  /// 获取货币信息
  static CurrencyInfo? getCurrencyInfo(String currencyCode) => _currencies[currencyCode];

  /// 根据语言获取默认货币
  String getDefaultCurrencyForLanguage([AppLanguage? language]) {
    final lang = language ?? _currentLanguage;
    switch (lang) {
      case AppLanguage.zhCN:
        return 'CNY';
      case AppLanguage.zhTW:
        return 'TWD';
      case AppLanguage.en:
        return 'USD';
      case AppLanguage.ja:
        return 'JPY';
      case AppLanguage.ko:
        return 'KRW';
    }
  }

  /// 格式化货币金额
  ///
  /// [amount] 金额
  /// [currencyCode] 货币代码，默认使用当前语言的默认货币
  /// [showSymbol] 是否显示货币符号
  /// [compact] 是否使用紧凑格式（如 1K, 1M）
  String formatCurrency(
    double amount, {
    String? currencyCode,
    bool showSymbol = true,
    bool compact = false,
  }) {
    final code = currencyCode ?? getDefaultCurrencyForLanguage();
    final currency = _currencies[code] ?? _currencies['CNY']!;

    String formattedNumber;
    if (compact) {
      formattedNumber = _formatCompactNumber(amount, currency.decimalDigits);
    } else {
      formattedNumber = _formatNumber(amount, currency.decimalDigits);
    }

    if (!showSymbol) {
      return formattedNumber;
    }

    if (currency.symbolPosition == SymbolPosition.before) {
      return '${currency.symbol}$formattedNumber';
    } else {
      return '$formattedNumber${currency.symbol}';
    }
  }

  /// 格式化货币金额（简化版，自动检测货币）
  String formatMoney(double amount, {bool showSymbol = true}) {
    return formatCurrency(amount, showSymbol: showSymbol);
  }

  // ============ 日期时间格式化 ============

  /// 格式化日期
  ///
  /// [date] 日期
  /// [format] 格式类型
  String formatDate(DateTime date, {DateFormatType format = DateFormatType.medium}) {
    final pattern = _getDatePattern(format);
    final formatter = DateFormat(pattern, localeCode);
    return formatter.format(date);
  }

  /// 格式化时间
  ///
  /// [time] 时间
  /// [format] 格式类型
  String formatTime(DateTime time, {TimeFormatType format = TimeFormatType.short}) {
    final pattern = _getTimePattern(format);
    final formatter = DateFormat(pattern, localeCode);
    return formatter.format(time);
  }

  /// 格式化日期时间
  ///
  /// [dateTime] 日期时间
  /// [dateFormat] 日期格式类型
  /// [timeFormat] 时间格式类型
  String formatDateTime(
    DateTime dateTime, {
    DateFormatType dateFormat = DateFormatType.medium,
    TimeFormatType timeFormat = TimeFormatType.short,
  }) {
    final dateStr = formatDate(dateTime, format: dateFormat);
    final timeStr = formatTime(dateTime, format: timeFormat);
    return '$dateStr $timeStr';
  }

  /// 格式化相对时间（如"3分钟前"）
  String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.isNegative) {
      return _formatFutureTime(diff.abs());
    }

    if (diff.inSeconds < 60) {
      return _getRelativeTimeText('just_now');
    } else if (diff.inMinutes < 60) {
      return _getRelativeTimeText('minutes_ago', diff.inMinutes);
    } else if (diff.inHours < 24) {
      return _getRelativeTimeText('hours_ago', diff.inHours);
    } else if (diff.inDays < 7) {
      return _getRelativeTimeText('days_ago', diff.inDays);
    } else if (diff.inDays < 30) {
      return _getRelativeTimeText('weeks_ago', diff.inDays ~/ 7);
    } else if (diff.inDays < 365) {
      return _getRelativeTimeText('months_ago', diff.inDays ~/ 30);
    } else {
      return _getRelativeTimeText('years_ago', diff.inDays ~/ 365);
    }
  }

  String _formatFutureTime(Duration diff) {
    if (diff.inMinutes < 60) {
      return _getRelativeTimeText('in_minutes', diff.inMinutes);
    } else if (diff.inHours < 24) {
      return _getRelativeTimeText('in_hours', diff.inHours);
    } else if (diff.inDays < 7) {
      return _getRelativeTimeText('in_days', diff.inDays);
    } else {
      return _getRelativeTimeText('in_weeks', diff.inDays ~/ 7);
    }
  }

  /// 获取日期格式模式
  String _getDatePattern(DateFormatType format) {
    switch (_currentLanguage) {
      case AppLanguage.zhCN:
      case AppLanguage.zhTW:
        return _zhDatePatterns[format]!;
      case AppLanguage.en:
        return _enDatePatterns[format]!;
      case AppLanguage.ja:
        return _jaDatePatterns[format]!;
      case AppLanguage.ko:
        return _koDatePatterns[format]!;
    }
  }

  /// 获取时间格式模式
  String _getTimePattern(TimeFormatType format) {
    switch (format) {
      case TimeFormatType.short:
        return 'HH:mm';
      case TimeFormatType.medium:
        return 'HH:mm:ss';
      case TimeFormatType.long:
        return 'HH:mm:ss z';
    }
  }

  /// 获取相对时间文本
  String _getRelativeTimeText(String key, [int? value]) {
    final texts = _relativeTimeTexts[_currentLanguage]!;
    final template = texts[key]!;
    if (value != null) {
      return template.replaceAll('{n}', value.toString());
    }
    return template;
  }

  // ============ 数字格式化 ============

  /// 格式化数字
  ///
  /// [number] 数字
  /// [decimalDigits] 小数位数
  String formatNumber(double number, {int decimalDigits = 2}) {
    return _formatNumber(number, decimalDigits);
  }

  /// 格式化整数
  String formatInteger(int number) {
    final formatter = NumberFormat('#,###', localeCode);
    return formatter.format(number);
  }

  /// 格式化百分比
  ///
  /// [value] 百分比值（0-1）
  /// [decimalDigits] 小数位数
  String formatPercentage(double value, {int decimalDigits = 1}) {
    final formatter = NumberFormat.percentPattern(localeCode);
    formatter.minimumFractionDigits = decimalDigits;
    formatter.maximumFractionDigits = decimalDigits;
    return formatter.format(value);
  }

  /// 格式化紧凑数字（如 1.2K, 3.4M）
  String formatCompactNumber(double number) {
    return _formatCompactNumber(number, 1);
  }

  /// 内部：格式化数字
  String _formatNumber(double number, int decimalDigits) {
    final formatter = NumberFormat('#,##0', localeCode);
    if (decimalDigits > 0) {
      formatter.minimumFractionDigits = decimalDigits;
      formatter.maximumFractionDigits = decimalDigits;
    }
    return formatter.format(number);
  }

  /// 内部：格式化紧凑数字
  String _formatCompactNumber(double number, int decimalDigits) {
    final absNumber = number.abs();
    String suffix = '';
    double displayNumber = number;

    if (absNumber >= 1e12) {
      displayNumber = number / 1e12;
      suffix = _getCompactSuffix('trillion');
    } else if (absNumber >= 1e9) {
      displayNumber = number / 1e9;
      suffix = _getCompactSuffix('billion');
    } else if (absNumber >= 1e8 && (_currentLanguage == AppLanguage.zhCN || _currentLanguage == AppLanguage.zhTW || _currentLanguage == AppLanguage.ja)) {
      // 中文和日文使用"亿"
      displayNumber = number / 1e8;
      suffix = _getCompactSuffix('yi');
    } else if (absNumber >= 1e6) {
      displayNumber = number / 1e6;
      suffix = _getCompactSuffix('million');
    } else if (absNumber >= 1e4 && (_currentLanguage == AppLanguage.zhCN || _currentLanguage == AppLanguage.zhTW || _currentLanguage == AppLanguage.ja || _currentLanguage == AppLanguage.ko)) {
      // 东亚语言使用"万"
      displayNumber = number / 1e4;
      suffix = _getCompactSuffix('wan');
    } else if (absNumber >= 1e3) {
      displayNumber = number / 1e3;
      suffix = _getCompactSuffix('thousand');
    }

    final formatter = NumberFormat('#,##0', localeCode);
    if (decimalDigits > 0 && displayNumber != number) {
      formatter.minimumFractionDigits = 0;
      formatter.maximumFractionDigits = decimalDigits;
    }

    return '${formatter.format(displayNumber)}$suffix';
  }

  /// 获取紧凑数字后缀
  String _getCompactSuffix(String key) {
    return _compactSuffixes[_currentLanguage]![key]!;
  }

  // ============ 静态数据 ============

  /// 中文日期格式
  static const Map<DateFormatType, String> _zhDatePatterns = {
    DateFormatType.short: 'M/d',
    DateFormatType.medium: 'yyyy年M月d日',
    DateFormatType.long: 'yyyy年M月d日 EEEE',
    DateFormatType.full: 'yyyy年M月d日 EEEE',
    DateFormatType.monthDay: 'M月d日',
    DateFormatType.yearMonth: 'yyyy年M月',
  };

  /// 英文日期格式
  static const Map<DateFormatType, String> _enDatePatterns = {
    DateFormatType.short: 'M/d',
    DateFormatType.medium: 'MMM d, yyyy',
    DateFormatType.long: 'MMMM d, yyyy',
    DateFormatType.full: 'EEEE, MMMM d, yyyy',
    DateFormatType.monthDay: 'MMM d',
    DateFormatType.yearMonth: 'MMMM yyyy',
  };

  /// 日文日期格式
  static const Map<DateFormatType, String> _jaDatePatterns = {
    DateFormatType.short: 'M/d',
    DateFormatType.medium: 'yyyy年M月d日',
    DateFormatType.long: 'yyyy年M月d日 EEEE',
    DateFormatType.full: 'yyyy年M月d日 EEEE',
    DateFormatType.monthDay: 'M月d日',
    DateFormatType.yearMonth: 'yyyy年M月',
  };

  /// 韩文日期格式
  static const Map<DateFormatType, String> _koDatePatterns = {
    DateFormatType.short: 'M/d',
    DateFormatType.medium: 'yyyy년 M월 d일',
    DateFormatType.long: 'yyyy년 M월 d일 EEEE',
    DateFormatType.full: 'yyyy년 M월 d일 EEEE',
    DateFormatType.monthDay: 'M월 d일',
    DateFormatType.yearMonth: 'yyyy년 M월',
  };

  /// 相对时间文本
  static const Map<AppLanguage, Map<String, String>> _relativeTimeTexts = {
    AppLanguage.zhCN: {
      'just_now': '刚刚',
      'minutes_ago': '{n}分钟前',
      'hours_ago': '{n}小时前',
      'days_ago': '{n}天前',
      'weeks_ago': '{n}周前',
      'months_ago': '{n}个月前',
      'years_ago': '{n}年前',
      'in_minutes': '{n}分钟后',
      'in_hours': '{n}小时后',
      'in_days': '{n}天后',
      'in_weeks': '{n}周后',
    },
    AppLanguage.zhTW: {
      'just_now': '剛剛',
      'minutes_ago': '{n}分鐘前',
      'hours_ago': '{n}小時前',
      'days_ago': '{n}天前',
      'weeks_ago': '{n}週前',
      'months_ago': '{n}個月前',
      'years_ago': '{n}年前',
      'in_minutes': '{n}分鐘後',
      'in_hours': '{n}小時後',
      'in_days': '{n}天後',
      'in_weeks': '{n}週後',
    },
    AppLanguage.en: {
      'just_now': 'Just now',
      'minutes_ago': '{n} minutes ago',
      'hours_ago': '{n} hours ago',
      'days_ago': '{n} days ago',
      'weeks_ago': '{n} weeks ago',
      'months_ago': '{n} months ago',
      'years_ago': '{n} years ago',
      'in_minutes': 'In {n} minutes',
      'in_hours': 'In {n} hours',
      'in_days': 'In {n} days',
      'in_weeks': 'In {n} weeks',
    },
    AppLanguage.ja: {
      'just_now': 'たった今',
      'minutes_ago': '{n}分前',
      'hours_ago': '{n}時間前',
      'days_ago': '{n}日前',
      'weeks_ago': '{n}週間前',
      'months_ago': '{n}ヶ月前',
      'years_ago': '{n}年前',
      'in_minutes': '{n}分後',
      'in_hours': '{n}時間後',
      'in_days': '{n}日後',
      'in_weeks': '{n}週間後',
    },
    AppLanguage.ko: {
      'just_now': '방금',
      'minutes_ago': '{n}분 전',
      'hours_ago': '{n}시간 전',
      'days_ago': '{n}일 전',
      'weeks_ago': '{n}주 전',
      'months_ago': '{n}개월 전',
      'years_ago': '{n}년 전',
      'in_minutes': '{n}분 후',
      'in_hours': '{n}시간 후',
      'in_days': '{n}일 후',
      'in_weeks': '{n}주 후',
    },
  };

  /// 紧凑数字后缀
  static const Map<AppLanguage, Map<String, String>> _compactSuffixes = {
    AppLanguage.zhCN: {
      'thousand': '千',
      'wan': '万',
      'million': '百万',
      'yi': '亿',
      'billion': '十亿',
      'trillion': '万亿',
    },
    AppLanguage.zhTW: {
      'thousand': '千',
      'wan': '萬',
      'million': '百萬',
      'yi': '億',
      'billion': '十億',
      'trillion': '兆',
    },
    AppLanguage.en: {
      'thousand': 'K',
      'wan': '0K',
      'million': 'M',
      'yi': '00M',
      'billion': 'B',
      'trillion': 'T',
    },
    AppLanguage.ja: {
      'thousand': '千',
      'wan': '万',
      'million': '百万',
      'yi': '億',
      'billion': '十億',
      'trillion': '兆',
    },
    AppLanguage.ko: {
      'thousand': '천',
      'wan': '만',
      'million': '백만',
      'yi': '억',
      'billion': '십억',
      'trillion': '조',
    },
  };
}

/// 货币信息
class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final String namePlural;
  final int decimalDigits;
  final SymbolPosition symbolPosition;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.namePlural,
    required this.decimalDigits,
    required this.symbolPosition,
  });

  @override
  String toString() => '$code ($symbol)';
}

/// 货币符号位置
enum SymbolPosition {
  before,
  after,
}

/// 日期格式类型
enum DateFormatType {
  short,      // 短格式: 1/2
  medium,     // 中格式: 2024年1月2日
  long,       // 长格式: 2024年1月2日 星期二
  full,       // 完整格式: 2024年1月2日 星期二
  monthDay,   // 月日格式: 1月2日
  yearMonth,  // 年月格式: 2024年1月
}

/// 时间格式类型
enum TimeFormatType {
  short,      // 短格式: 14:30
  medium,     // 中格式: 14:30:00
  long,       // 长格式: 14:30:00 CST
}
