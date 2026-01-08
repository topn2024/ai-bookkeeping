import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/voice/entity_disambiguation_service.dart';
import '../services/voice/voice_delete_service.dart';
import '../services/voice/voice_modify_service.dart';
import '../services/voice/voice_intent_router.dart';
import '../services/voice_recognition_engine.dart';
import '../services/tts_service.dart';
import '../services/voice_feedback_system.dart';

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
final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService();
});

/// 数据库服务Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
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
  final EntityDisambiguationService _entityService;
  final VoiceDeleteService _deleteService;
  final VoiceModifyService _modifyService;
  final VoiceRecognitionEngine _recognitionEngine;
  final TtsService _ttsService;
  final DatabaseService _databaseService;

  VoiceInteractionNotifier({
    required EntityDisambiguationService entityService,
    required VoiceDeleteService deleteService,
    required VoiceModifyService modifyService,
    required VoiceRecognitionEngine recognitionEngine,
    required TtsService ttsService,
    required DatabaseService databaseService,
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
    // TODO: 实现添加交易的语音处理逻辑
    await _provideFeedback('正在添加新交易记录...');
    // 这里可以解析语音中的交易信息并创建新记录
  }

  /// 处理查询命令
  Future<void> _handleQueryCommand(String command) async {
    // TODO: 实现查询的语音处理逻辑
    await _provideFeedback('正在查询相关信息...');
    // 这里可以根据语音查询并返回结果
  }

  /// 处理导航命令
  Future<void> _handleNavigationCommand(String command) async {
    // TODO: 实现页面导航的语音处理逻辑
    await _provideFeedback('正在跳转到相关页面...');
    // 这里可以根据语音命令导航到不同页面
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
    final transactions = await _databaseService.queryTransactions(
      startDate: conditions.startDate,
      endDate: conditions.endDate,
      category: conditions.categoryHint,
      merchant: conditions.merchantHint,
      minAmount: conditions.amountMin,
      maxAmount: conditions.amountMax,
      limit: conditions.limit,
    );

    // 转换为TransactionRecord格式
    return transactions.map((t) => TransactionRecord(
      id: t.id,
      amount: t.amount,
      category: t.category,
      subCategory: t.subCategory,
      merchant: t.merchant,
      description: t.description,
      date: t.date,
      account: t.account,
      tags: t.tags,
      type: t.type,
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
        amount: record.amount,
        category: record.category ?? '',
        subCategory: record.subCategory,
        merchant: record.merchant,
        description: record.description,
        date: record.date,
        account: record.account ?? '',
        tags: record.tags,
        type: record.type,
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