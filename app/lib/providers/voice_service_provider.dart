import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';

import '../models/transaction.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../services/voice/entity_disambiguation_service.dart';
import '../services/voice/voice_delete_service.dart';
import '../services/voice/voice_modify_service.dart';
import '../services/voice/voice_intent_router.dart';
import '../services/voice_recognition_engine.dart';
import '../services/tts_service.dart';
import '../services/voice_feedback_system.dart';
import '../services/duplicate_detection_service.dart';

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
  return TTSService();
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
    final amount = amountMatch != null ? double.tryParse(amountMatch.group(1)!) : null;

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
    print('VoiceProvider: 开始检查重复交易，金额=${transaction.amount}');
    final existingTransactions = await _databaseService.getTransactions();
    print('VoiceProvider: 获取到${existingTransactions.length}条现有交易');
    final duplicateCheck = DuplicateDetectionService.checkDuplicate(
      transaction,
      existingTransactions,
    );
    print('VoiceProvider: 重复检测结果: hasPotentialDuplicate=${duplicateCheck.hasPotentialDuplicate}, score=${duplicateCheck.similarityScore}');

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
    if (conditions.startDate != null) {
      transactions = transactions.where((t) => t.date.isAfter(conditions.startDate!.subtract(const Duration(days: 1)))).toList();
    }
    if (conditions.endDate != null) {
      transactions = transactions.where((t) => t.date.isBefore(conditions.endDate!.add(const Duration(days: 1)))).toList();
    }
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
    if (conditions.limit != null && conditions.limit! > 0) {
      transactions = transactions.take(conditions.limit!).toList();
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