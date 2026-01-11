import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 本地化服务基类
///
/// 提供所有本地化服务的共享实现，包括：
/// - 语言检测和设置
/// - 用户语言偏好覆盖
/// - 语言代码映射
///
/// 子类需要实现 [translations] 和 [getLocalizedName] 方法
abstract class BaseLocalizationService<T> {
  /// 当前使用的语言代码
  String _currentLocale = 'zh';

  /// 用户手动选择的语言（null表示使用系统语言）
  String? _userOverrideLocale;

  /// 支持的语言列表
  static const List<String> supportedLocales = ['zh', 'en', 'ja', 'ko'];

  /// 默认语言
  static const String defaultLocale = 'en';

  /// 获取当前语言代码
  String get currentLocale => _currentLocale;

  /// 判断是否使用了用户自定义语言
  bool get isUserOverride => _userOverrideLocale != null;

  /// 获取翻译表（子类实现）
  ///
  /// 返回格式: { id: { languageCode: translatedName } }
  Map<String, Map<String, String>> get translations;

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
    final lowerCode = languageCode.toLowerCase();
    if (supportedLocales.contains(lowerCode)) {
      return lowerCode;
    }
    // 其他语言默认使用英语
    return defaultLocale;
  }

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

  /// 获取本地化名称
  ///
  /// [id] 标识符（如账户ID或分类ID）
  /// [fallback] 找不到时的回退值，默认返回 id 本身
  String getLocalizedName(String id, {String? fallback}) {
    final translated = translations[id.toLowerCase()]?[_currentLocale];
    if (translated != null) {
      return translated;
    }

    // 尝试英文作为回退
    final englishTranslation = translations[id.toLowerCase()]?['en'];
    if (englishTranslation != null) {
      return englishTranslation;
    }

    return fallback ?? id;
  }

  /// 获取指定语言的本地化名称
  String getLocalizedNameForLocale(String id, String locale, {String? fallback}) {
    final mappedLocale = _mapLocaleToSupported(locale);
    final translated = translations[id.toLowerCase()]?[mappedLocale];
    if (translated != null) {
      return translated;
    }

    // 尝试英文作为回退
    final englishTranslation = translations[id.toLowerCase()]?['en'];
    if (englishTranslation != null) {
      return englishTranslation;
    }

    return fallback ?? id;
  }

  /// 添加自定义翻译（运行时添加）
  void addCustomTranslation(String id, Map<String, String> localeTranslations);
}
