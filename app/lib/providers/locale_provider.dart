import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../services/category_localization_service.dart';
import '../services/account_localization_service.dart';
import '../services/locale_format_service.dart';

/// 语言设置状态
class LocaleState {
  final AppLanguage? selectedLanguage; // null表示跟随系统
  final AppLanguage effectiveLanguage; // 实际使用的语言
  final int _version; // 用于强制刷新UI

  const LocaleState({
    this.selectedLanguage,
    required this.effectiveLanguage,
    int version = 0,
  }) : _version = version;

  LocaleState copyWith({
    AppLanguage? selectedLanguage,
    AppLanguage? effectiveLanguage,
    bool clearSelection = false,
    bool forceRefresh = false,
  }) {
    return LocaleState(
      selectedLanguage: clearSelection ? null : (selectedLanguage ?? this.selectedLanguage),
      effectiveLanguage: effectiveLanguage ?? this.effectiveLanguage,
      version: forceRefresh ? _version + 1 : _version,
    );
  }

  /// 是否跟随系统
  bool get followSystem => selectedLanguage == null;

  /// 当前语言信息
  LanguageInfo get languageInfo => AppLanguages.get(effectiveLanguage);

  /// 当前Locale
  Locale get locale => languageInfo.locale;

  /// 版本号（用于触发UI刷新）
  int get version => _version;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocaleState &&
        other.selectedLanguage == selectedLanguage &&
        other.effectiveLanguage == effectiveLanguage &&
        other._version == _version;
  }

  @override
  int get hashCode => Object.hash(selectedLanguage, effectiveLanguage, _version);
}

/// 语言设置Provider
class LocaleNotifier extends Notifier<LocaleState> {
  static const _keySelectedLanguage = 'selected_language';

  @override
  LocaleState build() {
    _loadSettings();
    // 默认使用简体中文
    return LocaleState(effectiveLanguage: AppLanguage.zhCN);
  }

  /// 获取系统语言
  static AppLanguage getSystemLanguage() {
    final systemLocale = PlatformDispatcher.instance.locale;
    final languageCode = systemLocale.languageCode;
    final countryCode = systemLocale.countryCode;

    if (languageCode == 'zh') {
      if (countryCode == 'TW' || countryCode == 'HK' || countryCode == 'MO') {
        return AppLanguage.zhTW;
      }
      return AppLanguage.zhCN;
    } else if (languageCode == 'en') {
      return AppLanguage.en;
    } else if (languageCode == 'ja') {
      return AppLanguage.ja;
    } else if (languageCode == 'ko') {
      return AppLanguage.ko;
    }

    // 默认返回简体中文
    return AppLanguage.zhCN;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final languageIndex = prefs.getInt(_keySelectedLanguage);

    if (languageIndex != null && languageIndex >= 0 && languageIndex < AppLanguage.values.length) {
      final selected = AppLanguage.values[languageIndex];
      state = LocaleState(
        selectedLanguage: selected,
        effectiveLanguage: selected,
      );
      _syncLocalizationServices(selected);
    } else {
      // 默认使用简体中文（首次启动）
      state = LocaleState(
        selectedLanguage: AppLanguage.zhCN,
        effectiveLanguage: AppLanguage.zhCN,
      );
      _syncLocalizationServices(AppLanguage.zhCN);
      // 保存默认设置
      _saveSettings();
    }
  }

  /// 同步本地化服务
  void _syncLocalizationServices(AppLanguage language) {
    final localeCode = _appLanguageToLocaleCode(language);
    CategoryLocalizationService.instance.setLocale(localeCode);
    AccountLocalizationService.instance.setLocale(localeCode);
    // 同步格式化服务
    LocaleFormatService.instance.setLanguage(language);
  }

  /// 将AppLanguage转换为语言代码
  String _appLanguageToLocaleCode(AppLanguage language) {
    switch (language) {
      case AppLanguage.zhCN:
      case AppLanguage.zhTW:
        return 'zh';
      case AppLanguage.en:
        return 'en';
      case AppLanguage.ja:
        return 'ja';
      case AppLanguage.ko:
        return 'ko';
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (state.selectedLanguage != null) {
      await prefs.setInt(_keySelectedLanguage, state.selectedLanguage!.index);
    } else {
      await prefs.remove(_keySelectedLanguage);
    }
  }

  /// 设置语言（无需重启即可生效）
  ///
  /// 通过更新状态版本号触发整个应用的UI刷新
  Future<void> setLanguage(AppLanguage language) async {
    _syncLocalizationServices(language);
    state = LocaleState(
      selectedLanguage: language,
      effectiveLanguage: language,
      version: state.version + 1, // 强制触发UI刷新
    );
    await _saveSettings();
  }

  /// 设置跟随系统（无需重启即可生效）
  Future<void> setFollowSystem() async {
    final systemLanguage = getSystemLanguage();
    _syncLocalizationServices(systemLanguage);
    state = LocaleState(
      selectedLanguage: null,
      effectiveLanguage: systemLanguage,
      version: state.version + 1, // 强制触发UI刷新
    );
    await _saveSettings();
  }

  /// 刷新语言设置（用于系统语言变化时）
  void refresh() {
    if (state.followSystem) {
      final systemLanguage = getSystemLanguage();
      if (systemLanguage != state.effectiveLanguage) {
        _syncLocalizationServices(systemLanguage);
        state = LocaleState(
          selectedLanguage: null,
          effectiveLanguage: systemLanguage,
          version: state.version + 1,
        );
      }
    }
  }

  /// 获取本地化字符串
  AppLocalizations get l10n => AppLocalizations(state.effectiveLanguage);
}

/// Provider
final localeProvider = NotifierProvider<LocaleNotifier, LocaleState>(
  LocaleNotifier.new,
);

/// 便捷访问本地化字符串
final l10nProvider = Provider<AppLocalizations>((ref) {
  return ref.watch(localeProvider.notifier).l10n;
});
