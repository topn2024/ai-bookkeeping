import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 账户本地化服务
///
/// 根据设备区域自动选择合适的语言显示账户名称
/// 支持：中文(zh)、英文(en)、日文(ja)、韩文(ko)
class AccountLocalizationService {
  static AccountLocalizationService? _instance;

  /// 当前使用的语言代码
  String _currentLocale = 'zh';

  /// 用户手动选择的语言（null表示使用系统语言）
  String? _userOverrideLocale;

  AccountLocalizationService._();

  static AccountLocalizationService get instance {
    _instance ??= AccountLocalizationService._();
    return _instance!;
  }

  /// 初始化服务，检测设备区域
  void initialize() {
    if (_userOverrideLocale != null) {
      _currentLocale = _userOverrideLocale!;
      return;
    }

    // 获取设备语言设置
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    _currentLocale = _mapLocaleToSupported(deviceLocale.languageCode);
  }

  /// 从BuildContext初始化（在Widget中使用）
  void initializeFromContext(BuildContext context) {
    if (_userOverrideLocale != null) {
      _currentLocale = _userOverrideLocale!;
      return;
    }

    final locale = Localizations.localeOf(context);
    _currentLocale = _mapLocaleToSupported(locale.languageCode);
  }

  /// 将语言代码映射到支持的语言
  String _mapLocaleToSupported(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'zh': // 中文
        return 'zh';
      case 'ja': // 日语
        return 'ja';
      case 'ko': // 韩语
        return 'ko';
      case 'en': // 英语
      default:   // 其他语言默认使用英语
        return 'en';
    }
  }

  /// 获取当前语言代码
  String get currentLocale => _currentLocale;

  /// 手动设置语言
  void setLocale(String? locale) {
    _userOverrideLocale = locale;
    if (locale != null) {
      _currentLocale = _mapLocaleToSupported(locale);
    } else {
      // 恢复系统语言
      initialize();
    }
  }

  /// 判断是否使用了用户自定义语言
  bool get isUserOverride => _userOverrideLocale != null;

  /// 获取账户的本地化名称
  ///
  /// [accountId] 账户ID或英文名称
  /// [originalName] 原始账户名称（用于自定义账户）
  String getAccountName(String accountId, {String? originalName}) {
    // 先尝试通过ID查找
    final translated = _accountTranslations[accountId.toLowerCase()]?[_currentLocale];
    if (translated != null) {
      return translated;
    }

    // 再尝试通过英文名称查找
    final byEnglishName = _englishNameMapping[accountId.toLowerCase()];
    if (byEnglishName != null) {
      final result = _accountTranslations[byEnglishName]?[_currentLocale];
      if (result != null) {
        return result;
      }
    }

    // 如果都找不到，返回原始名称或ID
    return originalName ?? accountId;
  }

  /// 获取指定语言的账户名称
  String getAccountNameForLocale(String accountId, String locale, {String? originalName}) {
    final mappedLocale = _mapLocaleToSupported(locale);
    final translated = _accountTranslations[accountId.toLowerCase()]?[mappedLocale];
    if (translated != null) {
      return translated;
    }

    final byEnglishName = _englishNameMapping[accountId.toLowerCase()];
    if (byEnglishName != null) {
      final result = _accountTranslations[byEnglishName]?[mappedLocale];
      if (result != null) {
        return result;
      }
    }

    return originalName ?? accountId;
  }

  /// 英文名称到ID的映射
  static const Map<String, String> _englishNameMapping = {
    'cash': 'cash',
    'wechat': 'wechat',
    'wechat pay': 'wechat',
    'alipay': 'alipay',
    'bank': 'bank',
    'bank card': 'bank',
    'credit card': 'credit',
    'debit card': 'bank',
    'savings': 'savings',
    'investment': 'investment',
  };

  /// 账户翻译表
  /// 格式: { accountId: { languageCode: translatedName } }
  static const Map<String, Map<String, String>> _accountTranslations = {
    // ============ 基础账户 ============
    'cash': {
      'zh': '现金',
      'en': 'Cash',
      'ja': '現金',
      'ko': '현금',
    },
    'wechat': {
      'zh': '微信',
      'en': 'WeChat Pay',
      'ja': 'WeChat',
      'ko': '위챗페이',
    },
    'alipay': {
      'zh': '支付宝',
      'en': 'Alipay',
      'ja': 'Alipay',
      'ko': '알리페이',
    },
    'bank': {
      'zh': '银行卡',
      'en': 'Bank Card',
      'ja': '銀行カード',
      'ko': '은행카드',
    },

    // ============ 扩展账户类型 ============
    'credit': {
      'zh': '信用卡',
      'en': 'Credit Card',
      'ja': 'クレジットカード',
      'ko': '신용카드',
    },
    'debit': {
      'zh': '储蓄卡',
      'en': 'Debit Card',
      'ja': 'デビットカード',
      'ko': '체크카드',
    },
    'savings': {
      'zh': '储蓄账户',
      'en': 'Savings',
      'ja': '貯蓄口座',
      'ko': '저축계좌',
    },
    'investment': {
      'zh': '投资账户',
      'en': 'Investment',
      'ja': '投資口座',
      'ko': '투자계좌',
    },
    'wallet': {
      'zh': '钱包',
      'en': 'Wallet',
      'ja': '財布',
      'ko': '지갑',
    },

    // ============ 电子钱包 ============
    'paypal': {
      'zh': 'PayPal',
      'en': 'PayPal',
      'ja': 'PayPal',
      'ko': '페이팔',
    },
    'apple_pay': {
      'zh': 'Apple Pay',
      'en': 'Apple Pay',
      'ja': 'Apple Pay',
      'ko': '애플페이',
    },
    'google_pay': {
      'zh': 'Google Pay',
      'en': 'Google Pay',
      'ja': 'Google Pay',
      'ko': '구글페이',
    },

    // ============ 银行名称 ============
    'icbc': {
      'zh': '工商银行',
      'en': 'ICBC',
      'ja': '中国工商銀行',
      'ko': '공상은행',
    },
    'ccb': {
      'zh': '建设银行',
      'en': 'CCB',
      'ja': '中国建設銀行',
      'ko': '건설은행',
    },
    'abc': {
      'zh': '农业银行',
      'en': 'ABC',
      'ja': '中国農業銀行',
      'ko': '농업은행',
    },
    'boc': {
      'zh': '中国银行',
      'en': 'BOC',
      'ja': '中国銀行',
      'ko': '중국은행',
    },
    'cmb': {
      'zh': '招商银行',
      'en': 'CMB',
      'ja': '招商銀行',
      'ko': '초상은행',
    },
    'psbc': {
      'zh': '邮储银行',
      'en': 'PSBC',
      'ja': '中国郵政銀行',
      'ko': '우정저축은행',
    },
  };

  /// 添加自定义账户的翻译
  void addCustomTranslation(String accountId, Map<String, String> translations) {
    _customTranslations[accountId] = translations;
  }

  /// 自定义账户翻译（运行时添加）
  static final Map<String, Map<String, String>> _customTranslations = {};
}

/// 账户名称本地化扩展
extension AccountLocalization on String {
  /// 获取账户ID的本地化名称
  String get localizedAccountName {
    return AccountLocalizationService.instance.getAccountName(this);
  }
}
