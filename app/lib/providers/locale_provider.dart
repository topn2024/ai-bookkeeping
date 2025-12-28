import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

/// 语言设置状态
class LocaleState {
  final AppLanguage? selectedLanguage; // null表示跟随系统
  final AppLanguage effectiveLanguage; // 实际使用的语言

  const LocaleState({
    this.selectedLanguage,
    required this.effectiveLanguage,
  });

  LocaleState copyWith({
    AppLanguage? selectedLanguage,
    AppLanguage? effectiveLanguage,
    bool clearSelection = false,
  }) {
    return LocaleState(
      selectedLanguage: clearSelection ? null : (selectedLanguage ?? this.selectedLanguage),
      effectiveLanguage: effectiveLanguage ?? this.effectiveLanguage,
    );
  }

  /// 是否跟随系统
  bool get followSystem => selectedLanguage == null;

  /// 当前语言信息
  LanguageInfo get languageInfo => AppLanguages.get(effectiveLanguage);

  /// 当前Locale
  Locale get locale => languageInfo.locale;
}

/// 语言设置Provider
class LocaleNotifier extends Notifier<LocaleState> {
  static const _keySelectedLanguage = 'selected_language';

  @override
  LocaleState build() {
    _loadSettings();
    return LocaleState(effectiveLanguage: getSystemLanguage());
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
    } else {
      // 跟随系统
      state = LocaleState(
        selectedLanguage: null,
        effectiveLanguage: getSystemLanguage(),
      );
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

  /// 设置语言
  Future<void> setLanguage(AppLanguage language) async {
    state = LocaleState(
      selectedLanguage: language,
      effectiveLanguage: language,
    );
    await _saveSettings();
  }

  /// 设置跟随系统
  Future<void> setFollowSystem() async {
    state = LocaleState(
      selectedLanguage: null,
      effectiveLanguage: getSystemLanguage(),
    );
    await _saveSettings();
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
