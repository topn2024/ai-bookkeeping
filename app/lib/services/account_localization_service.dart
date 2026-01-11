import '../core/base/base_localization_service.dart';

/// 账户本地化服务
///
/// 根据设备区域自动选择合适的语言显示账户名称
/// 支持：中文(zh)、英文(en)、日文(ja)、韩文(ko)
class AccountLocalizationService extends BaseLocalizationService<String> {
  static AccountLocalizationService? _instance;

  AccountLocalizationService._();

  static AccountLocalizationService get instance {
    _instance ??= AccountLocalizationService._();
    return _instance!;
  }

  @override
  Map<String, Map<String, String>> get translations => _accountTranslations;

  /// 自定义账户翻译（运行时添加）
  static final Map<String, Map<String, String>> _customTranslations = {};

  @override
  void addCustomTranslation(String id, Map<String, String> localeTranslations) {
    _customTranslations[id] = localeTranslations;
  }

  /// 获取账户的本地化名称
  ///
  /// [accountId] 账户ID或英文名称
  /// [originalName] 原始账户名称（用于自定义账户）
  String getAccountName(String accountId, {String? originalName}) {
    // 先尝试通过ID查找
    final translated = getLocalizedName(accountId);
    if (translated != accountId) {
      return translated;
    }

    // 再尝试通过英文名称查找
    final byEnglishName = _englishNameMapping[accountId.toLowerCase()];
    if (byEnglishName != null) {
      final result = getLocalizedName(byEnglishName);
      if (result != byEnglishName) {
        return result;
      }
    }

    // 检查自定义翻译
    final custom = _customTranslations[accountId.toLowerCase()]?[currentLocale];
    if (custom != null) {
      return custom;
    }

    // 如果都找不到，返回原始名称或ID
    return originalName ?? accountId;
  }

  /// 获取指定语言的账户名称
  String getAccountNameForLocale(String accountId, String locale, {String? originalName}) {
    final translated = getLocalizedNameForLocale(accountId, locale);
    if (translated != accountId) {
      return translated;
    }

    final byEnglishName = _englishNameMapping[accountId.toLowerCase()];
    if (byEnglishName != null) {
      final result = getLocalizedNameForLocale(byEnglishName, locale);
      if (result != byEnglishName) {
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
}

/// 账户名称本地化扩展
extension AccountLocalization on String {
  /// 获取账户ID的本地化名称
  String get localizedAccountName {
    return AccountLocalizationService.instance.getAccountName(this);
  }
}
