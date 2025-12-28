import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeState = ref.watch(localeProvider);
    final localeNotifier = ref.read(localeProvider.notifier);
    final l10n = localeNotifier.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.languageSettings),
      ),
      body: ListView(
        children: [
          // 跟随系统选项
          RadioListTile<bool>(
            title: Text(l10n.followSystem),
            subtitle: Text(_getSystemLanguageName()),
            secondary: const Icon(Icons.phone_android),
            value: true,
            groupValue: localeState.followSystem,
            onChanged: (value) {
              if (value == true) {
                localeNotifier.setFollowSystem();
              }
            },
          ),
          const Divider(),
          // 语言列表
          ...AppLanguages.list.map((lang) => RadioListTile<AppLanguage>(
            title: Row(
              children: [
                Text(lang.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Text(lang.name),
              ],
            ),
            subtitle: Text(lang.nameEn),
            value: lang.language,
            groupValue: localeState.followSystem ? null : localeState.effectiveLanguage,
            onChanged: (value) {
              if (value != null) {
                localeNotifier.setLanguage(value);
              }
            },
          )),
        ],
      ),
    );
  }

  String _getSystemLanguageName() {
    final systemLang = LocaleNotifier.getSystemLanguage();
    return AppLanguages.get(systemLang).name;
  }
}
