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
import 'core/di/service_locator.dart';
import 'services/cleanup_scheduler.dart';
import 'services/app_config_service.dart';
import 'services/http_service.dart';
import 'services/app_upgrade_service.dart';
import 'services/auto_sync_service.dart';
import 'services/multimodal_wakeup_service.dart';
import 'services/secure_storage_service.dart';
import 'services/database_service.dart';
import 'services/global_voice_assistant_manager.dart';
import 'services/voice_token_service.dart';
import 'services/voice_context_route_observer.dart';
import 'services/voice_service_coordinator.dart' show VoiceServiceCoordinator, VoiceSessionResult, VoiceSessionStatus;
import 'providers/voice_coordinator_provider.dart';
import 'widgets/global_floating_ball.dart';
import 'models/ledger.dart';
import 'services/voice_navigation_executor.dart';

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

  // Initialize service locator (dependency injection)
  try {
    await initServiceLocator();
    logger.info('Service locator initialized', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize service locator: $e', tag: 'App');
  }

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

  // Configure voice token service with Alibaba Cloud credentials
  // IMPORTANT: This must be done BEFORE multimodal wake-up service and voice assistant
  // Note: For production, these should be obtained from backend
  try {
    VoiceTokenService().configureDirectMode(
      token: 'fc1cd8fba41b4dae95b5c88d7290e0a4',
      appKey: 'C8F0dz0ihFmvKH8G',
    );
    logger.info('Voice token service configured with direct mode', tag: 'App');
  } catch (e) {
    logger.warning('Failed to configure voice token service: $e', tag: 'App');
  }

  // Initialize multimodal wake-up service
  try {
    await MultimodalWakeUpService().initialize();
    logger.info('Multimodal wake-up service initialized', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize multimodal wake-up service: $e', tag: 'App');
  }

  // Initialize default ledger for guest/anonymous users
  try {
    await _initializeDefaultLedger();
    logger.info('Default ledger initialized', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize default ledger: $e', tag: 'App');
  }

  // Initialize global voice assistant
  try {
    await GlobalVoiceAssistantManager.instance.initialize();
    logger.info('Global voice assistant initialized', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize global voice assistant: $e', tag: 'App');
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

/// 初始化默认账本（用于未登录用户）
Future<void> _initializeDefaultLedger() async {
  final secureStorage = SecureStorageService();
  final db = await DatabaseService().database;

  // 检查是否已有用户ID（已登录）
  String? userId = await secureStorage.getUserId();

  // 如果没有用户ID，使用guest ID
  if (userId == null || userId.isEmpty) {
    userId = 'guest';
  }

  // 检查是否已有账本
  final existingLedgers = await db.query(
    'ledgers',
    where: 'ownerId = ?',
    whereArgs: [userId],
  );

  // 如果没有账本，创建默认账本
  if (existingLedgers.isEmpty) {
    final defaultLedger = DefaultLedgers.defaultLedger(userId);
    await db.insert('ledgers', defaultLedger.toMap());
    logger.info('Created default ledger for user: $userId', tag: 'App');
  }
}

/// Root application widget with lifecycle observer
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  // 路由观察器
  final _voiceContextRouteObserver = VoiceContextRouteObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 在第一帧之后设置命令处理器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupCommandProcessor();
    });
  }

  /// 设置命令处理器，将 GlobalVoiceAssistantManager 与 VoiceServiceCoordinator 集成
  ///
  /// 交互策略：即时反馈 + 后台处理
  /// 1. 收到语音输入后立即给出自然的回应（如"好的，我来帮你记录..."）
  /// 2. 在后台异步处理实际的记账操作
  /// 3. 处理完成后更新对话历史（不打断用户）
  void _setupCommandProcessor() {
    final coordinator = ref.read(voiceServiceCoordinatorProvider);

    GlobalVoiceAssistantManager.instance.setCommandProcessor((command) async {
      debugPrint('[App] 处理语音命令: $command');

      // 1. 生成即时自然回应（先回复用户，让对话不断开）
      final immediateResponse = _generateImmediateResponse(command);
      debugPrint('[App] 即时反馈: $immediateResponse');

      // 2. 异步处理实际命令（不阻塞对话）
      _processCommandInBackground(coordinator, command);

      // 3. 立即返回自然回应
      return immediateResponse;
    });

    logger.info('Command processor setup completed', tag: 'App');
  }

  /// 生成即时自然回应（让用户感到被理解）
  String _generateImmediateResponse(String command) {
    // 检测命令类型，生成相应的即时回应
    final lowerCommand = command.toLowerCase();

    // 多条记录
    if (command.contains('然后') ||
        command.contains('还有') ||
        command.contains('另外') ||
        command.contains('以及')) {
      return '好的，我来帮你记录这几笔~';
    }

    // 记账相关
    if (lowerCommand.contains('花') ||
        lowerCommand.contains('买') ||
        lowerCommand.contains('吃') ||
        lowerCommand.contains('块') ||
        lowerCommand.contains('元') ||
        RegExp(r'\d+').hasMatch(command)) {
      final responses = [
        '好的，记下来了~',
        '收到，帮你记上~',
        '好嘞，已记录~',
        '明白，记好了~',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }

    // 查询相关
    if (lowerCommand.contains('多少') ||
        lowerCommand.contains('查') ||
        lowerCommand.contains('看看')) {
      return '好的，我帮你查一下...';
    }

    // 导航相关
    if (lowerCommand.contains('打开') ||
        lowerCommand.contains('去') ||
        lowerCommand.contains('跳转')) {
      return '好的，马上~';
    }

    // 默认回应
    return '好的，我来处理~';
  }

  /// 后台处理命令（异步，不阻塞对话）
  Future<void> _processCommandInBackground(
    VoiceServiceCoordinator coordinator,
    String command,
  ) async {
    try {
      // 所有命令统一走 SmartIntentRecognizer 多层架构处理
      // Layer 1: 精确规则匹配 → Layer 2: 同义词扩展 → Layer 3: 模板匹配
      // → Layer 4: 学习缓存 → Layer 5: LLM兜底

      // 检查是否可能包含多个意图
      final intentRouter = coordinator.intentRouter;
      final mightBeMultiple = intentRouter.mightContainMultipleIntents(command);
      debugPrint('[App] 后台处理 - 是否多意图: $mightBeMultiple');

      VoiceSessionResult result;
      if (mightBeMultiple) {
        result = await coordinator.processMultiIntentCommand(command);
        // 多意图处理后自动确认执行
        if (result.status == VoiceSessionStatus.success) {
          debugPrint('[App] 多意图识别成功，自动确认执行');
          final confirmResult = await coordinator.confirmMultiIntents();
          debugPrint('[App] 多意图执行结果: ${confirmResult.status} - ${confirmResult.message}');
          result = confirmResult;
        }
      } else {
        result = await coordinator.processVoiceCommand(command);
      }

      debugPrint('[App] 后台处理完成: ${result.status}');

      // 如果有错误或需要补充信息，追加消息通知用户
      if (result.status == VoiceSessionStatus.error) {
        final errorMsg = result.errorMessage ?? '处理时遇到了问题';
        debugPrint('[App] 处理出错: $errorMsg');
      } else if (result.status == VoiceSessionStatus.success) {
        final detailMsg = result.message;
        if (detailMsg != null && detailMsg.isNotEmpty) {
          debugPrint('[App] 处理成功: $detailMsg');
        }

        // 如果结果包含导航路由，执行实际导航
        final data = result.data;
        if (data is Map<String, dynamic> && data.containsKey('route')) {
          final route = data['route'] as String?;
          if (route != null) {
            debugPrint('[App] 执行导航: $route');
            await VoiceNavigationExecutor.instance.executeNavigation(command);
          }
        }
      }
    } catch (e) {
      debugPrint('[App] 后台处理失败: $e');
    }
  }

  /// 检查是否是导航命令
  bool _isNavigationCommand(String command) {
    final navigationKeywords = [
      '打开', '去', '跳转', '进入', '查看', '看看',
      '想进行', '进行', '管理', '想看', '想去', '帮我打开',
    ];
    final targetKeywords = [
      '设置', '配置', '首页', '主页', '预算', '报表', '统计',
      '储蓄', '钱龄', '分析', '账户', '分类', '交易', '记录',
      '语音', '主题', '通知', '提醒', '备份', '同步', '安全',
      '账本', '习惯', '家庭', '导入', '导出', '搜索',
    ];

    final hasNavigationKeyword = navigationKeywords.any((k) => command.contains(k));
    final hasTargetKeyword = targetKeywords.any((k) => command.contains(k));

    return hasNavigationKeyword && hasTargetKeyword;
  }

  @override
  void dispose() {
    // 清除命令处理器
    GlobalVoiceAssistantManager.instance.setCommandProcessor(null);
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
      navigatorKey: VoiceNavigationExecutor.instance.navigatorKey,
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
      navigatorObservers: [
        _voiceContextRouteObserver,
      ],
      builder: (context, child) {
        // 包装全局悬浮球
        return GlobalFloatingBallOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: onboardingState.isCompleted
          ? const MainNavigation()
          : const OnboardingFlowPage(),
    );
  }
}
