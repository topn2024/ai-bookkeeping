import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';

import '../models/transaction.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../core/feature_flags.dart';
import '../services/voice/entity_disambiguation_service.dart';
import '../services/voice/voice_delete_service.dart';
import '../services/voice/voice_modify_service.dart';
import '../services/voice/voice_intent_router.dart';
import '../services/voice/prompt_builder.dart';
import '../services/voice_recognition_engine.dart';
import '../services/tts_service.dart';
import '../services/voice_feedback_system.dart';
import '../services/duplicate_detection_service.dart';
import '../services/voice_service_coordinator.dart' as legacy;
import '../application/coordinators/coordinators.dart' hide TransactionType;
import '../application/facades/facades.dart';
import '../application/factories/factories.dart';
import '../domain/repositories/repositories.dart';
import '../domain/events/events.dart';
import '../infrastructure/events/events.dart';

/// 实体消歧服务Provider
final entityDisambiguationServiceProvider = Provider<EntityDisambiguationService>((ref) {
  return EntityDisambiguationService();
});

/// 语音删除服务Provider
final voiceDeleteServiceProvider = Provider<VoiceDeleteService>((ref) {
  final disambiguationService = ref.read(entityDisambiguationServiceProvider);
  return VoiceDeleteService(disambiguationService: disambiguationService);
});

/// 语音修改服务Provider
final voiceModifyServiceProvider = Provider<VoiceModifyService>((ref) {
  final disambiguationService = ref.read(entityDisambiguationServiceProvider);
  return VoiceModifyService(disambiguationService: disambiguationService);
});

/// 语音识别引擎Provider
final voiceRecognitionEngineProvider = Provider<VoiceRecognitionEngine>((ref) {
  return VoiceRecognitionEngine();
});

/// TTS服务Provider
final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService.instance;
});

/// 数据库服务Provider（通过服务定位器获取）
final databaseServiceProvider = Provider<IDatabaseService>((ref) {
  return sl<IDatabaseService>();
});

/// 语音意图路由器Provider
final voiceIntentRouterProvider = Provider<VoiceIntentRouter>((ref) {
  return VoiceIntentRouter();
});

/// 语音反馈系统Provider
final voiceFeedbackSystemProvider = Provider<VoiceFeedbackSystem>((ref) {
  final ttsService = ref.read(ttsServiceProvider);
  return VoiceFeedbackSystem(ttsService: ttsService);
});

// ==================== 新架构 Providers (Phase 1.4) ====================

/// Feature Flags Provider
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags.instance;
});

/// 语音识别协调器 Provider
final voiceRecognitionCoordinatorProvider = Provider<VoiceRecognitionCoordinator>((ref) {
  final engine = ref.read(voiceRecognitionEngineProvider);
  return VoiceRecognitionCoordinator(
    engine: _VoiceRecognitionEngineAdapter(engine),
  );
});

/// 意图处理协调器 Provider
final intentProcessingCoordinatorProvider = Provider<IntentProcessingCoordinator>((ref) {
  // TODO: 注入实际的 recognizer 和 decomposer
  return IntentProcessingCoordinator(
    recognizer: _DefaultIntentRecognizer(),
  );
});

/// 交易操作协调器 Provider
final transactionOperationCoordinatorProvider = Provider<TransactionOperationCoordinator>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  return TransactionOperationCoordinator(
    transactionRepository: _TransactionRepositoryAdapter(dbService),
    accountRepository: _AccountRepositoryAdapter(dbService),
  );
});

/// 导航协调器 Provider
final navigationCoordinatorProvider = Provider<NavigationCoordinator>((ref) {
  return NavigationCoordinator();
});

/// 对话协调器 Provider
final conversationCoordinatorProvider = Provider<ConversationCoordinator>((ref) {
  return ConversationCoordinator();
});

/// 反馈协调器 Provider
final feedbackCoordinatorProvider = Provider<FeedbackCoordinator>((ref) {
  final ttsService = ref.read(ttsServiceProvider);
  return FeedbackCoordinator(
    ttsService: _TTSServiceAdapter(ttsService),
  );
});

/// 语音服务编排器 Provider (新架构)
final voiceServiceOrchestratorProvider = Provider<VoiceServiceOrchestrator>((ref) {
  return VoiceServiceOrchestrator(
    recognitionCoordinator: ref.read(voiceRecognitionCoordinatorProvider),
    intentCoordinator: ref.read(intentProcessingCoordinatorProvider),
    transactionCoordinator: ref.read(transactionOperationCoordinatorProvider),
    navigationCoordinator: ref.read(navigationCoordinatorProvider),
    conversationCoordinator: ref.read(conversationCoordinatorProvider),
    feedbackCoordinator: ref.read(feedbackCoordinatorProvider),
  );
});

/// 旧版语音服务协调器 Provider
final legacyVoiceServiceCoordinatorProvider = Provider<legacy.VoiceServiceCoordinator>((ref) {
  return legacy.VoiceServiceCoordinator();
});

/// 语音服务 Facade Provider (统一入口)
final voiceServiceFacadeProvider = Provider<VoiceServiceFacade>((ref) {
  final featureFlags = ref.read(featureFlagsProvider);
  final modernImpl = ref.read(voiceServiceOrchestratorProvider);
  final legacyImpl = ref.read(legacyVoiceServiceCoordinatorProvider);

  return VoiceServiceFacade(
    modernImpl: modernImpl,
    legacyImpl: legacyImpl,
    featureFlags: featureFlags,
  );
});

// ==================== Phase 3: Command 和 Event Providers ====================

/// Prompt 构建器 Provider
final promptBuilderProvider = Provider<PromptBuilder>((ref) {
  return PromptBuilder();
});

/// 命令工厂 Provider
final commandFactoryProvider = Provider<CommandFactory>((ref) {
  final transactionRepo = ref.read(transactionRepositoryProvider);
  final accountRepo = ref.read(accountRepositoryProvider);

  return CommandFactory(
    transactionRepository: transactionRepo,
    accountRepository: accountRepo,
  );
});

/// 命令执行器 Provider
final commandExecutorProvider = Provider<CommandExecutor>((ref) {
  return CommandExecutor(maxHistorySize: 50);
});

/// 命令流水线 Provider
final commandPipelineProvider = Provider<CommandPipeline>((ref) {
  final executor = ref.read(commandExecutorProvider);
  final pipeline = CommandPipeline(executor: executor);

  // 添加日志拦截器（可选）
  if (FeatureFlags.instance.enableVerboseLogging) {
    pipeline.addPreInterceptor(LoggingInterceptor());
    pipeline.addPostInterceptor(LoggingInterceptor());
  }

  // 添加验证拦截器
  pipeline.addPreInterceptor(ValidationInterceptor());

  return pipeline;
});

/// 事件总线 Provider
final eventBusProvider = Provider<EventBus>((ref) {
  final eventBus = EventBus.instance;
  eventBus.enableLogging = FeatureFlags.instance.enableVerboseLogging;
  return eventBus;
});

/// 预算警报处理器 Provider
final budgetAlertHandlerProvider = Provider<BudgetAlertHandler>((ref) {
  final budgetRepo = ref.read(budgetRepositoryProvider);
  final eventBus = ref.read(eventBusProvider);

  return BudgetAlertHandler(
    budgetRepository: budgetRepo,
    onEventPublish: (event) => eventBus.publish(event),
  );
});

/// 统计更新处理器 Provider
final statisticsUpdateHandlerProvider = Provider<StatisticsUpdateHandler>((ref) {
  return StatisticsUpdateHandler(
    onStatisticsUpdate: (period) async {
      debugPrint('[StatisticsHandler] 更新周期: $period');
      // TODO: 触发统计缓存刷新
    },
  );
});

/// 通知处理器 Provider
final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  return NotificationHandler(
    onNotify: (title, message) async {
      debugPrint('[NotificationHandler] $title: $message');
      // TODO: 显示实际通知
    },
  );
});

/// 事件处理器注册 Provider（初始化时调用）
final eventHandlersInitProvider = Provider<void>((ref) {
  final eventBus = ref.read(eventBusProvider);
  final budgetHandler = ref.read(budgetAlertHandlerProvider);
  final statisticsHandler = ref.read(statisticsUpdateHandlerProvider);
  final notificationHandler = ref.read(notificationHandlerProvider);

  // 注册事件处理器
  eventBus.subscribe(budgetHandler);
  eventBus.subscribe(statisticsHandler);
  eventBus.subscribe(notificationHandler);

  debugPrint('[EventHandlers] 事件处理器已注册');
});

/// 交易仓储 Provider（使用适配器）
final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  return _TransactionRepositoryAdapter(dbService);
});

/// 账户仓储 Provider（使用适配器）
final accountRepositoryProvider = Provider<IAccountRepository>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  return _AccountRepositoryAdapter(dbService);
});

/// 预算仓储 Provider（使用适配器）
final budgetRepositoryProvider = Provider<IBudgetRepository>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  return _BudgetRepositoryAdapter(dbService);
});

// ==================== 适配器类 ====================

/// 语音识别引擎适配器
class _VoiceRecognitionEngineAdapter implements IVoiceRecognitionEngine {
  final VoiceRecognitionEngine _engine;

  _VoiceRecognitionEngineAdapter(this._engine);

  @override
  bool get isRecognizing => _engine.isRecognizing;

  @override
  Future<RecognitionResult> transcribe(Uint8List audioData) async {
    // 适配旧引擎的 transcribe 方法
    // TODO: 实现完整的适配
    return RecognitionResult.empty();
  }

  @override
  Stream<RecognitionResult> transcribeStream(Stream<Uint8List> audioStream) {
    // 适配旧引擎的流式识别
    // TODO: 实现完整的适配
    return Stream.empty();
  }

  @override
  Future<void> cancel() async {
    await _engine.cancelTranscription();
  }
}

/// 默认意图识别器（临时实现）
class _DefaultIntentRecognizer implements IIntentRecognizer {
  @override
  Future<ProcessedIntent> recognize(String input) async {
    // 简单的关键词匹配
    final lowerInput = input.toLowerCase();

    if (lowerInput.contains('删除') || lowerInput.contains('删掉')) {
      return ProcessedIntent(
        type: IntentType.deleteTransaction,
        confidence: 0.8,
        entities: {},
        originalText: input,
      );
    }

    if (lowerInput.contains('修改') || lowerInput.contains('改')) {
      return ProcessedIntent(
        type: IntentType.modifyTransaction,
        confidence: 0.8,
        entities: {},
        originalText: input,
      );
    }

    if (lowerInput.contains('打开') || lowerInput.contains('进入')) {
      return ProcessedIntent(
        type: IntentType.navigation,
        confidence: 0.8,
        entities: {},
        originalText: input,
      );
    }

    // 检测金额 - 可能是记账
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[元块钱]?').firstMatch(input);
    if (amountMatch != null) {
      return ProcessedIntent(
        type: IntentType.addTransaction,
        confidence: 0.7,
        entities: {'amount': double.tryParse(amountMatch.group(1) ?? '0')},
        originalText: input,
      );
    }

    return ProcessedIntent(
      type: IntentType.chat,
      confidence: 0.5,
      entities: {},
      originalText: input,
    );
  }
}

/// 交易仓库适配器
class _TransactionRepositoryAdapter implements ITransactionRepository {
  final IDatabaseService _dbService;

  _TransactionRepositoryAdapter(this._dbService);

  @override
  Future<Transaction?> findById(String id) async {
    final transactions = await _dbService.getTransactions();
    return transactions.where((t) => t.id == id).firstOrNull;
  }

  @override
  Future<List<Transaction>> findAll({bool includeDeleted = false}) async {
    return await _dbService.getTransactions();
  }

  @override
  Future<int> insert(Transaction entity) async {
    return await _dbService.insertTransaction(entity);
  }

  @override
  Future<void> insertAll(List<Transaction> entities) async {
    for (final entity in entities) {
      await _dbService.insertTransaction(entity);
    }
  }

  @override
  Future<int> update(Transaction entity) async {
    return await _dbService.updateTransaction(entity);
  }

  @override
  Future<int> delete(String id) async {
    return await _dbService.deleteTransaction(id);
  }

  @override
  Future<int> softDelete(String id) async {
    return await _dbService.deleteTransaction(id);
  }

  @override
  Future<int> restore(String id) async {
    return 0; // Not implemented in legacy
  }

  @override
  Future<bool> exists(String id) async {
    final t = await findById(id);
    return t != null;
  }

  @override
  Future<int> count() async {
    final list = await findAll();
    return list.length;
  }

  // IDateRangeRepository implementation
  @override
  Future<List<Transaction>> findByDateRange({required DateTime startDate, required DateTime endDate}) async {
    final all = await findAll();
    return all.where((t) => t.date.isAfter(startDate) && t.date.isBefore(endDate)).toList();
  }

  @override
  Future<List<Transaction>> findByCategory(String category) async {
    final all = await findAll();
    return all.where((t) => t.category == category).toList();
  }

  @override
  Future<List<Transaction>> findByAccountId(String accountId) async {
    final all = await findAll();
    return all.where((t) => t.accountId == accountId).toList();
  }

  @override
  Future<List<Transaction>> findByVaultId(String vaultId) async {
    return [];
  }

  @override
  Future<List<Transaction>> findByResourcePoolId(String resourcePoolId) async {
    return [];
  }

  @override
  Future<List<Transaction>> findByType(TransactionType type) async {
    final all = await findAll();
    return all.where((t) => t.type == type).toList();
  }

  @override
  Future<List<Transaction>> findBySource(TransactionSource source) async {
    final all = await findAll();
    return all.where((t) => t.source == source).toList();
  }

  @override
  Future<List<Transaction>> findByImportBatchId(String batchId) async {
    return [];
  }

  @override
  Future<Transaction?> findByExternalId(String externalId, ExternalSource source) async {
    return null;
  }

  @override
  Future<List<Transaction>> findPotentialDuplicates({
    required double amount,
    required DateTime date,
    String? note,
    Duration tolerance = const Duration(days: 1),
  }) async {
    return [];
  }

  @override
  Future<List<Transaction>> findByMemberId(String memberId) async {
    return [];
  }

  @override
  Future<List<Transaction>> query(TransactionQueryParams params) async {
    return await findAll();
  }

  @override
  Future<Transaction?> findFirst() async {
    final all = await findAll();
    return all.isNotEmpty ? all.first : null;
  }

  @override
  Future<TransactionStatistics> getStatistics({DateTime? startDate, DateTime? endDate, String? accountId}) async {
    return TransactionStatistics(
      totalIncome: 0,
      totalExpense: 0,
      netAmount: 0,
      count: 0,
    );
  }

  @override
  Future<Map<String, TransactionStatistics>> getMonthlyStatistics({required int year, String? accountId}) async {
    return {};
  }

  @override
  Future<List<Transaction>> findReimbursable() async {
    return [];
  }

  @override
  Future<List<Transaction>> findReimbursed() async {
    return [];
  }

  @override
  Future<int> markAsReimbursed(String id) async {
    return 0;
  }
}

/// 账户仓库适配器
class _AccountRepositoryAdapter implements IAccountRepository {
  final IDatabaseService _dbService;

  _AccountRepositoryAdapter(this._dbService);

  @override
  Future<int> increaseBalance(String id, double amount) async {
    return 0; // TODO: 实现
  }

  @override
  Future<int> decreaseBalance(String id, double amount) async {
    return 0; // TODO: 实现
  }

  @override
  Future<void> transfer(String fromId, String toId, double amount) async {
    // TODO: 实现
  }

  @override
  Future<Account?> findById(String id) async => null;

  @override
  Future<List<Account>> findAll({bool includeDeleted = false}) async => [];

  @override
  Future<int> insert(Account entity) async => 0;

  @override
  Future<void> insertAll(List<Account> entities) async {}

  @override
  Future<int> update(Account entity) async => 0;

  @override
  Future<int> delete(String id) async => 0;

  @override
  Future<int> softDelete(String id) async => 0;

  @override
  Future<int> restore(String id) async => 0;

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<int> count() async => 0;

  @override
  Future<Account?> findDefault() async => null;

  @override
  Future<int> setDefault(String id) async => 0;

  @override
  Future<List<Account>> findByType(AccountType type) async => [];

  @override
  Future<List<Account>> findActive() async => [];

  @override
  Future<List<Account>> findCustom() async => [];

  @override
  Future<int> updateBalance(String id, double newBalance) async => 0;

  @override
  Future<double> getTotalBalance() async => 0;

  @override
  Future<Map<AccountType, double>> getTotalBalanceByType() async => {};
}

/// 预算仓库适配器
class _BudgetRepositoryAdapter implements IBudgetRepository {
  final IDatabaseService _dbService;

  _BudgetRepositoryAdapter(this._dbService);

  @override
  Future<Budget?> findById(String id) async => null;

  @override
  Future<List<Budget>> findAll({bool includeDeleted = false}) async => [];

  @override
  Future<int> insert(Budget entity) async => 0;

  @override
  Future<void> insertAll(List<Budget> entities) async {}

  @override
  Future<int> update(Budget entity) async => 0;

  @override
  Future<int> delete(String id) async => 0;

  @override
  Future<int> softDelete(String id) async => 0;

  @override
  Future<int> restore(String id) async => 0;

  @override
  Future<bool> exists(String id) async => false;

  @override
  Future<int> count() async => 0;

  @override
  Future<Budget?> findByCategory(String category) async => null;

  @override
  Future<List<Budget>> findByPeriod(BudgetPeriod period) async => [];

  @override
  Future<List<Budget>> findByType(BudgetType type) async => [];

  @override
  Future<List<Budget>> findActive() async => [];

  @override
  Future<List<Budget>> findByMonth(int year, int month) async => [];

  @override
  Future<BudgetExecution> getExecution(String budgetId, {int? year, int? month}) async {
    return BudgetExecution.calculate(budgetId: budgetId, budgetAmount: 0, usedAmount: 0);
  }

  @override
  Future<List<BudgetExecution>> getAllExecutions({int? year, int? month}) async => [];

  @override
  Future<List<BudgetCarryover>> getCarryovers(String budgetId) async => [];

  @override
  Future<int> addCarryover(BudgetCarryover carryover) async => 0;

  @override
  Future<List<ZeroBasedAllocation>> getAllocations(String budgetId) async => [];

  @override
  Future<int> addAllocation(ZeroBasedAllocation allocation) async => 0;

  @override
  Future<double> getTotalBudgetAmount({BudgetPeriod? period}) async => 0;

  @override
  Future<List<Budget>> findNearingLimit({double threshold = 0.8}) async => [];
}

/// TTS服务适配器
class _TTSServiceAdapter implements ITTSService {
  final TTSService _ttsService;

  _TTSServiceAdapter(this._ttsService);

  @override
  bool get isSpeaking => _ttsService.isSpeaking;

  @override
  Future<void> speak(String text) async {
    await _ttsService.speak(text);
  }

  @override
  Future<void> stop() async {
    await _ttsService.stop();
  }

  @override
  void setVolume(double volume) {
    _ttsService.setVolume(volume);
  }

  @override
  void setSpeechRate(double rate) {
    _ttsService.setSpeechRate(rate);
  }

  @override
  void setPitch(double pitch) {
    _ttsService.setPitch(pitch);
  }
}

/// 语音交互状态Provider
final voiceInteractionStateProvider = StateNotifierProvider<VoiceInteractionNotifier, VoiceInteractionState>((ref) {
  final entityService = ref.read(entityDisambiguationServiceProvider);
  final deleteService = ref.read(voiceDeleteServiceProvider);
  final modifyService = ref.read(voiceModifyServiceProvider);
  final recognitionEngine = ref.read(voiceRecognitionEngineProvider);
  final ttsService = ref.read(ttsServiceProvider);
  final databaseService = ref.read(databaseServiceProvider);

  return VoiceInteractionNotifier(
    entityService: entityService,
    deleteService: deleteService,
    modifyService: modifyService,
    recognitionEngine: recognitionEngine,
    ttsService: ttsService,
    databaseService: databaseService,
  );
});

/// 语音交互状态
class VoiceInteractionState {
  final bool isListening;
  final bool isProcessing;
  final String? lastCommand;
  final String? feedback;
  final VoiceSessionType? currentSessionType;
  final dynamic currentSessionData;

  const VoiceInteractionState({
    this.isListening = false,
    this.isProcessing = false,
    this.lastCommand,
    this.feedback,
    this.currentSessionType,
    this.currentSessionData,
  });

  VoiceInteractionState copyWith({
    bool? isListening,
    bool? isProcessing,
    String? lastCommand,
    String? feedback,
    VoiceSessionType? currentSessionType,
    dynamic currentSessionData,
    bool clearSessionData = false,
  }) {
    return VoiceInteractionState(
      isListening: isListening ?? this.isListening,
      isProcessing: isProcessing ?? this.isProcessing,
      lastCommand: lastCommand ?? this.lastCommand,
      feedback: feedback ?? this.feedback,
      currentSessionType: currentSessionType ?? this.currentSessionType,
      currentSessionData: clearSessionData ? null : currentSessionData ?? this.currentSessionData,
    );
  }
}

/// 语音会话类型
enum VoiceSessionType {
  none,
  delete,
  modify,
  add,
  query,
  navigation,
}

/// 语音交互状态通知器
class VoiceInteractionNotifier extends StateNotifier<VoiceInteractionState> {
  // ignore: unused_field
  final EntityDisambiguationService _entityService;
  final VoiceDeleteService _deleteService;
  final VoiceModifyService _modifyService;
  // ignore: unused_field
  final VoiceRecognitionEngine _recognitionEngine;
  final TTSService _ttsService;
  final IDatabaseService _databaseService;

  VoiceInteractionNotifier({
    required EntityDisambiguationService entityService,
    required VoiceDeleteService deleteService,
    required VoiceModifyService modifyService,
    required VoiceRecognitionEngine recognitionEngine,
    required TTSService ttsService,
    required IDatabaseService databaseService,
  }) : _entityService = entityService,
       _deleteService = deleteService,
       _modifyService = modifyService,
       _recognitionEngine = recognitionEngine,
       _ttsService = ttsService,
       _databaseService = databaseService,
       super(const VoiceInteractionState());

  /// 开始语音识别
  void startListening() {
    state = state.copyWith(isListening: true);
  }

  /// 停止语音识别
  void stopListening() {
    state = state.copyWith(isListening: false);
  }

  /// 处理语音命令
  Future<void> processVoiceCommand(String command) async {
    try {
      state = state.copyWith(
        isProcessing: true,
        lastCommand: command,
      );

      // 检测命令类型
      final commandType = _detectCommandType(command);

      switch (commandType) {
        case VoiceSessionType.delete:
          await _handleDeleteCommand(command);
          break;
        case VoiceSessionType.modify:
          await _handleModifyCommand(command);
          break;
        case VoiceSessionType.add:
          await _handleAddCommand(command);
          break;
        case VoiceSessionType.query:
          await _handleQueryCommand(command);
          break;
        case VoiceSessionType.navigation:
          await _handleNavigationCommand(command);
          break;
        default:
          await _handleUnknownCommand(command);
      }
    } finally {
      state = state.copyWith(isProcessing: false);
    }
  }

  /// 检测命令类型
  VoiceSessionType _detectCommandType(String command) {
    final lowerCommand = command.toLowerCase();

    // 删除命令
    if (lowerCommand.contains('删除') || lowerCommand.contains('删掉') ||
        lowerCommand.contains('去掉') || lowerCommand.contains('取消')) {
      return VoiceSessionType.delete;
    }

    // 修改命令
    if (lowerCommand.contains('改') || lowerCommand.contains('修改') ||
        lowerCommand.contains('换成') || lowerCommand.contains('调')) {
      return VoiceSessionType.modify;
    }

    // 添加命令
    if (lowerCommand.contains('添加') || lowerCommand.contains('记录') ||
        lowerCommand.contains('花了') || lowerCommand.contains('买了')) {
      return VoiceSessionType.add;
    }

    // 查询命令
    if (lowerCommand.contains('查看') || lowerCommand.contains('显示') ||
        lowerCommand.contains('多少') || lowerCommand.contains('什么时候')) {
      return VoiceSessionType.query;
    }

    // 导航命令
    if (lowerCommand.contains('打开') || lowerCommand.contains('进入') ||
        lowerCommand.contains('切换到') || lowerCommand.contains('返回')) {
      return VoiceSessionType.navigation;
    }

    return VoiceSessionType.none;
  }

  /// 处理删除命令
  Future<void> _handleDeleteCommand(String command) async {
    final result = await _deleteService.processDeleteRequest(
      command,
      queryCallback: _queryTransactions,
      deleteCallback: _deleteTransactions,
    );

    await _provideFeedback(result.generateFeedbackText());

    if (result.needsClarification) {
      state = state.copyWith(
        currentSessionType: VoiceSessionType.delete,
        currentSessionData: result,
      );
    } else if (result.isSuccess) {
      state = state.copyWith(clearSessionData: true);
    }
  }

  /// 处理修改命令
  Future<void> _handleModifyCommand(String command) async {
    final result = await _modifyService.processModifyRequest(
      command,
      queryCallback: _queryTransactions,
      updateCallback: _updateTransaction,
    );

    await _provideFeedback(result.generateFeedbackText());

    if (result.needsClarification || result.needsConfirmation) {
      state = state.copyWith(
        currentSessionType: VoiceSessionType.modify,
        currentSessionData: result,
      );
    } else if (result.isSuccess) {
      state = state.copyWith(clearSessionData: true);
    }
  }

  /// 处理添加命令
  Future<void> _handleAddCommand(String command) async {
    await _provideFeedback('正在添加新交易记录...');
    // 解析语音中的交易信息
    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[元块钱]?').firstMatch(command);
    final amountStr = amountMatch?.group(1);
    final amount = amountStr != null ? double.tryParse(amountStr) : null;

    if (amount == null || amount <= 0) {
      await _provideFeedback('请告诉我金额是多少');
      return;
    }

    // 创建交易记录
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: TransactionType.expense,
      amount: amount,
      category: 'other_expense',
      note: command,
      date: DateTime.now(),
      accountId: 'default',
      source: TransactionSource.voice,
    );

    // 检查重复交易
    debugPrint('VoiceProvider: 开始检查重复交易，金额=${transaction.amount}');
    final existingTransactions = await _databaseService.getTransactions();
    debugPrint('VoiceProvider: 获取到${existingTransactions.length}条现有交易');
    final duplicateCheck = DuplicateDetectionService.checkDuplicate(
      transaction,
      existingTransactions,
    );
    debugPrint('VoiceProvider: 重复检测结果: hasPotentialDuplicate=${duplicateCheck.hasPotentialDuplicate}, score=${duplicateCheck.similarityScore}');

    if (duplicateCheck.hasPotentialDuplicate) {
      // 发现潜在重复，提示用户并进入确认流程
      await _provideFeedback('检测到可能的重复记录：${duplicateCheck.duplicateReason}。请说"确认"继续添加，或说"取消"放弃');

      // 设置确认状态，等待用户响应
      state = state.copyWith(
        currentSessionType: VoiceSessionType.add,
        currentSessionData: {
          'pendingTransaction': transaction,
          'awaitingConfirmation': true,
          'duplicateReason': duplicateCheck.duplicateReason,
        },
      );
      return;
    }

    await _databaseService.insertTransaction(transaction);
    await _provideFeedback('已记录消费${amount.toStringAsFixed(2)}元');
  }

  /// 处理查询命令
  Future<void> _handleQueryCommand(String command) async {
    await _provideFeedback('正在查询相关信息...');

    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    if (command.contains('今天')) {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (command.contains('本月') || command.contains('这个月')) {
      startDate = DateTime(now.year, now.month, 1);
      endDate = now;
    }

    var transactions = await _databaseService.getTransactions();

    // 应用日期过滤
    if (startDate != null) {
      transactions = transactions.where((t) => t.date.isAfter(startDate!.subtract(const Duration(days: 1)))).toList();
    }
    if (endDate != null) {
      transactions = transactions.where((t) => t.date.isBefore(endDate!.add(const Duration(days: 1)))).toList();
    }
    transactions = transactions.take(10).toList();

    if (transactions.isEmpty) {
      await _provideFeedback('没有找到符合条件的记录');
      return;
    }

    final total = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    await _provideFeedback('共${transactions.length}条记录，总支出${total.toStringAsFixed(2)}元');
  }

  /// 处理导航命令
  Future<void> _handleNavigationCommand(String command) async {
    String? targetPage;
    String? route;

    if (command.contains('首页') || command.contains('主页')) {
      targetPage = '首页';
      route = '/home';
    } else if (command.contains('统计') || command.contains('报表')) {
      targetPage = '统计页面';
      route = '/statistics';
    } else if (command.contains('设置')) {
      targetPage = '设置页面';
      route = '/settings';
    } else if (command.contains('账户')) {
      targetPage = '账户页面';
      route = '/accounts';
    }

    if (targetPage != null && route != null) {
      await _provideFeedback('正在跳转到$targetPage');
      // 存储导航数据供UI层使用
      state = state.copyWith(
        currentSessionType: VoiceSessionType.navigation,
        currentSessionData: {'route': route, 'pageName': targetPage},
      );
    } else {
      await _provideFeedback('抱歉，我不知道要跳转到哪个页面');
    }
  }

  /// 处理未识别命令
  Future<void> _handleUnknownCommand(String command) async {
    await _provideFeedback('抱歉，我没有理解您的指令。请说得更清楚一些。');
  }

  /// 处理确认响应
  Future<void> handleConfirmation(String response) async {
    if (state.currentSessionType == VoiceSessionType.delete) {
      final result = await _deleteService.handleVoiceConfirmation(
        response,
        _deleteTransactions,
      );
      await _provideFeedback(result.generateFeedbackText());
      if (result.isSuccess || result.isCancelled) {
        state = state.copyWith(clearSessionData: true);
      }
    } else if (state.currentSessionType == VoiceSessionType.modify) {
      if (_isConfirmation(response)) {
        final result = await _modifyService.confirmModification(_updateTransaction);
        await _provideFeedback(result.generateFeedbackText());
        if (result.isSuccess) {
          state = state.copyWith(clearSessionData: true);
        }
      } else {
        _modifyService.cancelModification();
        state = state.copyWith(clearSessionData: true);
        await _provideFeedback('已取消修改');
      }
    } else if (state.currentSessionType == VoiceSessionType.add) {
      // 处理添加交易的确认流程（重复交易确认）
      final sessionData = state.currentSessionData as Map<String, dynamic>?;
      if (sessionData != null && sessionData['awaitingConfirmation'] == true) {
        if (_isConfirmation(response)) {
          // 用户确认添加
          final pendingTransaction = sessionData['pendingTransaction'] as Transaction;
          await _databaseService.insertTransaction(pendingTransaction);
          await _provideFeedback('已记录消费${pendingTransaction.amount.toStringAsFixed(2)}元');
          state = state.copyWith(clearSessionData: true);
        } else {
          // 用户取消添加
          await _provideFeedback('已取消添加');
          state = state.copyWith(clearSessionData: true);
        }
      }
    }
  }

  /// 处理澄清选择
  Future<void> handleClarificationSelection(String selection) async {
    if (state.currentSessionType == VoiceSessionType.delete) {
      final result = await _deleteService.handleClarificationSelection(
        selection,
        _deleteTransactions,
      );
      await _provideFeedback(result.generateFeedbackText());
      if (result.isSuccess || result.isCancelled) {
        state = state.copyWith(clearSessionData: true);
      }
    } else if (state.currentSessionType == VoiceSessionType.modify) {
      final result = await _modifyService.handleClarificationSelection(
        selection,
        _updateTransaction,
      );
      await _provideFeedback(result.generateFeedbackText());
      if (result.isSuccess) {
        state = state.copyWith(clearSessionData: true);
      }
    }
  }

  /// 查询交易记录回调
  Future<List<TransactionRecord>> _queryTransactions(QueryConditions conditions) async {
    // 调用数据库服务查询交易记录
    var transactions = await _databaseService.getTransactions();

    // 应用过滤条件
    transactions = transactions.where((t) => t.date.isAfter(conditions.startDate.subtract(const Duration(days: 1)))).toList();
    transactions = transactions.where((t) => t.date.isBefore(conditions.endDate.add(const Duration(days: 1)))).toList();
    if (conditions.categoryHint != null) {
      transactions = transactions.where((t) => t.category.contains(conditions.categoryHint!)).toList();
    }
    if (conditions.merchantHint != null) {
      transactions = transactions.where((t) => t.rawMerchant?.contains(conditions.merchantHint!) ?? false).toList();
    }
    if (conditions.amountMin != null) {
      transactions = transactions.where((t) => t.amount >= conditions.amountMin!).toList();
    }
    if (conditions.amountMax != null) {
      transactions = transactions.where((t) => t.amount <= conditions.amountMax!).toList();
    }
    if (conditions.limit > 0) {
      transactions = transactions.take(conditions.limit).toList();
    }

    // 转换为TransactionRecord格式
    return transactions.map((t) => TransactionRecord(
      id: t.id,
      amount: t.amount,
      category: t.category,
      subCategory: t.subcategory,
      merchant: t.rawMerchant,
      description: t.note,
      date: t.date,
      account: t.accountId,
      tags: t.tags ?? [],
      type: t.type.name,
    )).toList();
  }

  /// 删除交易记录回调
  Future<bool> _deleteTransactions(List<TransactionRecord> records) async {
    try {
      for (final record in records) {
        await _databaseService.deleteTransaction(record.id);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 更新交易记录回调
  Future<bool> _updateTransaction(TransactionRecord record) async {
    try {
      await _databaseService.updateTransaction(Transaction(
        id: record.id,
        type: TransactionType.values.firstWhere((e) => e.name == record.type, orElse: () => TransactionType.expense),
        amount: record.amount,
        category: record.category ?? '',
        subcategory: record.subCategory,
        note: record.description,
        date: record.date,
        accountId: record.account ?? '',
        tags: record.tags,
        rawMerchant: record.merchant,
      ));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 提供语音反馈
  Future<void> _provideFeedback(String text) async {
    state = state.copyWith(feedback: text);
    await _ttsService.speak(text);
  }

  /// 检查是否是确认响应
  bool _isConfirmation(String text) {
    final lowerText = text.toLowerCase();
    const confirmWords = ['确认', '确定', '是的', '好的', '对', 'yes', 'ok'];
    return confirmWords.any((word) => lowerText.contains(word));
  }

  /// 清除当前会话
  void clearSession() {
    state = state.copyWith(clearSessionData: true, currentSessionType: VoiceSessionType.none);
    _deleteService.cancelDelete();
    _modifyService.cancelModification();
  }
}