import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'pages/main_navigation.dart';
import 'pages/onboarding_flow_page.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/onboarding_provider.dart';
import 'l10n/app_localizations.dart';
import 'l10n/generated/app_localizations.dart' as gen;
import 'core/logger.dart';
import 'services/cleanup_scheduler.dart';
import 'services/app_config_service.dart';
import 'services/http_service.dart';
import 'services/app_upgrade_service.dart';
import 'services/auto_sync_service.dart';
import 'services/multimodal_wakeup_service.dart';

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

  // Initialize app configuration from server
  try {
    await AppConfigService().initialize();
    logger.info('App config service initialized', tag: 'App');
    // Reinitialize HTTP service with new config
    HttpService().reinitialize();
    logger.info('HTTP service reinitialized with server config', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize app config: $e', tag: 'App');
  }

  // Initialize HTTP service (load auth token from secure storage)
  try {
    await HttpService().initialize();
    logger.info('HTTP service initialized with auth token', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize HTTP service: $e', tag: 'App');
  }

  // Initialize cleanup scheduler for source files
  try {
    await CleanupScheduler().initialize();
    logger.info('Cleanup scheduler initialized', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize cleanup scheduler: $e', tag: 'App');
  }

  // Initialize auto-sync service
  try {
    await AutoSyncService().initialize();
    logger.info('Auto-sync service initialized', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize auto-sync service: $e', tag: 'App');
  }

  // Initialize multimodal wake-up service
  try {
    await MultimodalWakeUpService().initialize();
    logger.info('Multimodal wake-up service initialized', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize multimodal wake-up service: $e', tag: 'App');
  }

  // Check for app updates (non-blocking)
  AppUpgradeService().checkUpdate().then((result) {
    if (result.hasUpdate) {
      logger.info(
        'App update available: ${result.latestVersion?.versionName ?? "unknown"}, '
        'force=${result.isForceUpdate}',
        tag: 'App',
      );
    }
  }).catchError((e) {
    logger.warning('Failed to check for updates: $e', tag: 'App');
  });

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
    final onboardingState = ref.watch(onboardingProvider);

    // 根据是否使用自定义主题选择对应的 ThemeData
    final lightTheme = themeState.isUsingCustomTheme
        ? themeNotifier.getLightTheme()
        : AppTheme.createLightTheme(themeNotifier.primaryColor);
    final darkTheme = themeState.isUsingCustomTheme
        ? themeNotifier.getDarkTheme()
        : AppTheme.createDarkTheme(themeNotifier.primaryColor);

    // Show loading screen while checking onboarding status
    if (onboardingState.isLoading) {
      return MaterialApp(
        title: l10n.appName,
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeNotifier.themeMode,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeNotifier.themeMode,
      locale: localeState.locale,
      supportedLocales: gen.S.supportedLocales,
      localizationsDelegates: [
        gen.S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizationsDelegate(localeState.effectiveLanguage),
      ],
      home: onboardingState.isCompleted
          ? const MainNavigation()
          : const OnboardingFlowPage(),
    );
  }
}
