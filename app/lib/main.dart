import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'pages/main_navigation.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.watch(themeProvider.notifier);
    final primaryColor = themeNotifier.primaryColor;
    final localeState = ref.watch(localeProvider);
    final l10n = ref.watch(localeProvider.notifier).l10n;

    return MaterialApp(
      title: l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.createLightTheme(primaryColor),
      darkTheme: AppTheme.createDarkTheme(primaryColor),
      themeMode: themeNotifier.themeMode,
      locale: localeState.locale,
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: [
        AppLocalizationsDelegate(localeState.effectiveLanguage),
      ],
      home: const MainNavigation(),
    );
  }
}
