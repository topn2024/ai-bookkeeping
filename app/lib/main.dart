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
import 'services/voice_token_refresh_service.dart';
import 'core/config.dart';
import 'services/voice_context_route_observer.dart';
import 'core/config/secrets.dart';
import 'services/voice_service_coordinator.dart' show VoiceSessionResult, VoiceSessionStatus;
import 'services/voice/config/feature_flags.dart';
import 'services/voice/events/query_result_event_bus.dart';
import 'providers/voice_coordinator_provider.dart';
import 'providers/transaction_provider.dart';
import 'widgets/global_floating_ball.dart';
import 'models/ledger.dart';
import 'services/voice_navigation_executor.dart';
import 'services/import/category_learning_helper.dart';
import 'services/learning/database_data_stores.dart';

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

  // Initialize AppConfig to load Native keys (must be before voice services)
  try {
    await appConfig.initialize();
    logger.info('AppConfig initialized with Native keys', tag: 'App');
  } catch (e) {
    logger.warning('Failed to initialize AppConfig: $e', tag: 'App');
  }

  // Configure voice token service with automatic token refresh
  // IMPORTANT: This must be done BEFORE multimodal wake-up service and voice assistant
  // 使用动态Token刷新服务，每天自动从阿里云获取新Token
  try {
    await VoiceTokenRefreshService().initialize();
    logger.info('Voice token service configured with auto-refresh', tag: 'App');
  } catch (e) {
    logger.warning('Voice token refresh service init failed: $e', tag: 'App');
    // 降级方案：使用静态Token
    VoiceTokenService().configureDirectMode(
      token: AliyunSpeechConfig.token,
      appKey: AliyunSpeechConfig.appKey,
      asrUrl: AliyunSpeechConfig.asrUrl,
      asrRestUrl: AliyunSpeechConfig.asrRestUrl,
      ttsUrl: AliyunSpeechConfig.ttsUrl,
    );
    logger.info('Voice token service fallback to static token', tag: 'App');
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

  // Initialize learning services (category, intent, anomaly learning)
  try {
    debugPrint('[App] 开始初始化自学习服务...');

    // 1. 初始化分类学习
    await CategoryLearningHelper.instance.initialize();
    debugPrint('[App] 分类学习服务初始化完成');
    logger.info('Category learning helper initialized', tag: 'App');

    // 2. 初始化数据库数据存储表
    await sl<DatabaseIntentDataStore>().ensureTableExists();
    await sl<DatabaseAnomalyDataStore>().ensureTableExists();
    debugPrint('[App] 学习数据存储表初始化完成');
    logger.info('Learning data stores initialized', tag: 'App');

    // 3. 意图学习和异常学习服务已通过 service_locator 懒加载注册
    debugPrint('[App] 自学习服务初始化全部完成');
    logger.info('Learning services registered', tag: 'App');
  } catch (e, stackTrace) {
    debugPrint('[App] 自学习服务初始化失败: $e');
    debugPrint('[App] 堆栈: $stackTrace');
    logger.warning('Failed to initialize learning services: $e', tag: 'App');
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

  // 查询结果事件总线
  final _eventBus = QueryResultEventBus();

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
  /// 交互策略：LLM 优先处理
  /// 1. 收到语音输入后，使用 VoiceServiceCoordinator 处理（内部调用 SmartIntentRecognizer）
  /// 2. VoiceServiceCoordinator 内部会播放 LLM 生成的自然语言响应
  /// 3. 返回空字符串，避免 GlobalVoiceAssistantManager 重复播放 TTS
  void _setupCommandProcessor() {
    final coordinator = ref.read(voiceServiceCoordinatorProvider);

    // 检查是否启用流水线模式
    final isPipelineMode = VoiceFeatureFlags.instance.usePipelineMode;
    debugPrint('[App] 设置命令处理器，流水线模式: $isPipelineMode');

    // 流水线模式下，跳过VoiceServiceCoordinator内部的TTS播放
    // 由流水线的OutputPipeline负责TTS播放
    if (isPipelineMode) {
      coordinator.setSkipTTSPlayback(true);

      // 设置延迟响应回调，将延迟响应传递给GlobalVoiceAssistant的流水线
      coordinator.onDeferredResponse = (String response) {
        debugPrint('[App] 收到延迟响应，传递给流水线: $response');
        GlobalVoiceAssistantManager.instance.handleDeferredResponse(response);
      };
    }

    // 连接网络状态提供者，让SmartIntentRecognizer能感知网络状态
    // 返回null时表示网络状态未初始化，将允许LLM调用
    coordinator.setNetworkStatusProvider(
      () => GlobalVoiceAssistantManager.instance.networkStatus,
    );

    // 预加载用户城市信息（用于LLM推断商户名称，如"深圳地铁"）
    coordinator.preloadUserCity();

    GlobalVoiceAssistantManager.instance.setCommandProcessor((command) async {
      debugPrint('[App] 处理语音命令: $command');

      try {
        // 检查是否可能包含多个意图
        final intentRouter = coordinator.intentRouter;
        final mightBeMultiple = intentRouter.mightContainMultipleIntents(command);
        debugPrint('[App] 是否多意图: $mightBeMultiple');

        VoiceSessionResult result;
        if (mightBeMultiple) {
          result = await coordinator.processMultiIntentCommand(command);
          // 多意图处理后自动确认执行（仅当确实有待确认的多意图时）
          if (result.status == VoiceSessionStatus.success && coordinator.hasPendingMultiIntent) {
            debugPrint('[App] 多意图识别成功，自动确认执行');
            final confirmResult = await coordinator.confirmMultiIntents();
            debugPrint('[App] 多意图执行结果: ${confirmResult.status} - ${confirmResult.message}');
            result = confirmResult;
          }
        } else {
          result = await coordinator.processVoiceCommand(command);
        }

        debugPrint('[App] 处理完成: ${result.status}');

        // 如果是查询操作，订阅事件以接收异步查询结果
        debugPrint('[App] 检查是否有operationId: result.data=${result.data}');
        final operationId = result.data?['operationId'] as String?;
        debugPrint('[App] operationId=$operationId');
        if (operationId != null) {
          debugPrint('[App] 订阅查询事件: $operationId');
          _eventBus.subscribe(operationId, (event) {
            debugPrint('[App] 收到查询结果: ${event.operationId}');
            _handleQueryResult(event);
          });
        } else {
          debugPrint('[App] operationId为null，跳过订阅');
        }

        // 根据处理结果，向聊天记录添加详细反馈
        // 注意：流水线模式下，_handlePipelineProcessInput 已经添加了消息，
        // 所以这里只在非流水线模式下添加消息，避免重复
        if (result.status == VoiceSessionStatus.error) {
          final errorMsg = result.errorMessage ?? '处理时遇到了问题';
          debugPrint('[App] 处理出错: $errorMsg');
          if (!isPipelineMode) {
            GlobalVoiceAssistantManager.instance.addResultMessage('❌ 处理失败：$errorMsg');
          }
        } else if (result.needsConfirmation) {
          debugPrint('[App] 需要确认，等待用户回复...');
          final confirmMsg = result.message ?? '需要您确认';
          if (!isPipelineMode) {
            GlobalVoiceAssistantManager.instance.addResultMessage('⏳ $confirmMsg');
          }
          // 延迟让 TTS 播放完成，然后自动开始录音
          await Future.delayed(const Duration(milliseconds: 2500));
          debugPrint('[App] 自动开始录音等待确认');
          GlobalVoiceAssistantManager.instance.startRecording();
        } else if (result.status == VoiceSessionStatus.success) {
          debugPrint('[App] 处理成功: ${result.message}');

          // 非流水线模式下，生成详细的结果反馈
          // 流水线模式下，_handlePipelineProcessInput 已添加消息，跳过
          if (!isPipelineMode) {
            final resultFeedback = _generateResultFeedback(result, mightBeMultiple);
            if (resultFeedback.isNotEmpty) {
              GlobalVoiceAssistantManager.instance.addResultMessage(resultFeedback);
            }
          }

          // 刷新交易列表，确保 UI 显示最新数据
          debugPrint('[App] 刷新交易列表...');
          await ref.read(transactionProvider.notifier).refresh();
          debugPrint('[App] 交易列表已刷新');

          // 如果结果包含导航路由，执行实际导航
          final data = result.data;
          if (data is Map<String, dynamic> && data.containsKey('route')) {
            final route = data['route'] as String?;
            if (route != null) {
              debugPrint('[App] 执行导航: $route');
              final success = await VoiceNavigationExecutor.instance.navigateToRoute(route);
              debugPrint('[App] 导航结果: $success');
            }
          }
        }

        // 流水线模式：返回实际响应文本，由流水线处理TTS
        // 非流水线模式：返回空字符串，VoiceServiceCoordinator已播放TTS
        if (isPipelineMode) {
          // 错误时使用 errorMessage，成功时使用 message
          final responseText = result.status == VoiceSessionStatus.error
              ? (result.errorMessage ?? '处理时遇到了问题')
              : (result.message ?? '');
          debugPrint('[App] 流水线模式，返回响应: ${responseText.length > 30 ? "${responseText.substring(0, 30)}..." : responseText}');
          return responseText;
        }
      } catch (e) {
        debugPrint('[App] 命令处理失败: $e');
        // 流水线模式下，_handlePipelineProcessInput 会添加消息，这里跳过
        if (!isPipelineMode) {
          GlobalVoiceAssistantManager.instance.addResultMessage('❌ 系统错误，请稍后重试');
        }

        // 流水线模式下返回错误提示
        if (isPipelineMode) {
          return '抱歉，处理失败了，请再试一次';
        }
      }

      // 非流水线模式：返回空字符串，VoiceServiceCoordinator 已经播放了 TTS
      return '';
    });

    logger.info('Command processor setup completed', tag: 'App');
  }

  /// 生成详细的结果反馈
  ///
  /// 根据处理结果生成用户友好的反馈信息，以要点形式呈现
  String _generateResultFeedback(VoiceSessionResult result, bool isMultiIntent) {
    final data = result.data;
    final message = result.message ?? '';
    final buffer = StringBuffer();

    // 检查是否有交易记录信息
    if (data is Map<String, dynamic>) {
      // 多笔交易记录
      if (data.containsKey('transactions') && data['transactions'] is List) {
        final transactions = data['transactions'] as List;
        buffer.writeln('✅ 已成功记录 ${transactions.length} 笔交易：');
        for (var i = 0; i < transactions.length; i++) {
          final tx = transactions[i];
          if (tx is Map<String, dynamic>) {
            final amount = tx['amount'] ?? 0;
            final category = tx['category'] ?? '其他';
            final note = tx['note'] ?? '';
            buffer.writeln('  • $category $amount元${note.isNotEmpty ? " ($note)" : ""}');
          }
        }
        return buffer.toString().trim();
      }

      // 单笔交易记录
      if (data.containsKey('amount')) {
        final amount = data['amount'];
        final category = data['category'] ?? '其他';
        final note = data['note'] ?? '';
        buffer.writeln('✅ 已记录：');
        buffer.writeln('  • $category $amount元${note.isNotEmpty ? " ($note)" : ""}');
        return buffer.toString().trim();
      }

      // 导航操作
      if (data.containsKey('route')) {
        final route = data['route'] as String?;
        final routeName = _getRouteDisplayName(route ?? '');
        return '✅ 已打开：$routeName';
      }

      // 查询结果
      if (data.containsKey('queryResult')) {
        return '✅ 查询完成：${data['queryResult']}';
      }
    }

    // 从消息中提取交易信息（兜底方案）
    if (message.contains('记录') || message.contains('记了')) {
      // 尝试解析消息中的交易信息
      final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:块|元)').firstMatch(message);
      if (amountMatch != null) {
        return '✅ $message';
      }
    }

    // 默认返回原始消息，加上成功标记
    if (message.isNotEmpty) {
      return '✅ $message';
    }

    return '';
  }

  /// 获取路由的显示名称
  String _getRouteDisplayName(String route) {
    final routeNames = {
      '/settings': '设置',
      '/budget': '预算管理',
      '/statistics': '统计报表',
      '/accounts': '账户管理',
      '/categories': '分类管理',
      '/transactions': '交易记录',
      '/savings': '储蓄目标',
      '/': '首页',
    };
    return routeNames[route] ?? route;
  }

  /// 处理查询结果事件
  ///
  /// 当查询操作异步完成后，更新最后一条助手消息的元数据
  void _handleQueryResult(QueryResultEvent event) {
    debugPrint('[App] 处理查询结果事件: ${event.operationId}');

    final cardData = event.result.data?['cardData'];
    final chartData = event.result.data?['chartData'];

    if (cardData != null || chartData != null) {
      GlobalVoiceAssistantManager.instance.updateLastMessageMetadata({
        if (cardData != null) 'cardData': cardData,
        if (chartData != null) 'chartData': chartData,
      });
      debugPrint('[App] 已更新消息元数据');
    } else {
      debugPrint('[App] 查询结果中没有可视化数据');
    }
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
      // 新引导方式：直接进入主页面，使用悬浮引导
      // 功能引导会在 HomePage 中通过 FeatureGuideService 显示
      home: const MainNavigation(),
    );
  }
}
