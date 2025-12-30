import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'pages/main_navigation.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'core/logger.dart';
import 'services/cleanup_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging system
  await logger.init(
    config: LogConfig(
      maxFileSize: 5 * 1024 * 1024, // 5MB per file
      retentionDays: 7, // Keep logs for 7 days
      maxTotalSize: 50 * 1024 * 1024, // 50MB total max
      persistToFile: true,
      fileLogLevel: kDebugMode ? LogLevel.debug : LogLevel.info,
    ),
  );

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Log app startup
  logger.info('Application started', tag: 'App');

  // Initialize cleanup scheduler for source files
  try {
    await CleanupScheduler().initialize();
    logger.info('Cleanup scheduler initialized', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize cleanup scheduler: $e', tag: 'App');
  }

  runApp(const ProviderScope(child: MyApp()));
}

/// Root application widget with lifecycle observer
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    logger.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Trigger log cleanup check when app resumes from background
      logger.onAppResumed();
      logger.debug('App resumed from background', tag: 'App');
    } else if (state == AppLifecycleState.paused) {
      logger.debug('App paused (entering background)', tag: 'App');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听主题状态变化，确保主题切换时 UI 会重建
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final localeState = ref.watch(localeProvider);
    final l10n = ref.watch(localeProvider.notifier).l10n;

    // 根据是否使用自定义主题选择对应的 ThemeData
    final lightTheme = themeState.isUsingCustomTheme
        ? themeNotifier.getLightTheme()
        : AppTheme.createLightTheme(themeNotifier.primaryColor);
    final darkTheme = themeState.isUsingCustomTheme
        ? themeNotifier.getDarkTheme()
        : AppTheme.createDarkTheme(themeNotifier.primaryColor);

    return MaterialApp(
      title: l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeNotifier.themeMode,
      locale: localeState.locale,
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizationsDelegate(localeState.effectiveLanguage),
      ],
      home: const MainNavigation(),
    );
  }
}
