import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'category_localization_service.dart';

/// 对话上下文持久化服务
///
/// 功能：
/// 1. 会话状态持久化存储
/// 2. 会话恢复（应用重启后继续未完成对话）
/// 3. 跨会话上下文（历史偏好、常用分类等）
/// 4. 上下文过期管理
class DialogContextPersistenceService {
  final DialogContextStorage _storage;
  final Duration _sessionTimeout;
  final int _maxHistoryTurns;

  PersistedSession? _currentSession;
  CrossSessionContext? _crossSessionContext;

  DialogContextPersistenceService({
    required DialogContextStorage storage,
    Duration sessionTimeout = const Duration(hours: 1),
    int maxHistoryTurns = 50,
  })  : _storage = storage,
        _sessionTimeout = sessionTimeout,
        _maxHistoryTurns = maxHistoryTurns;

  /// 初始化服务
  Future<void> initialize() async {
    // 加载跨会话上下文
    _crossSessionContext = await _storage.loadCrossSessionContext();
    _crossSessionContext ??= CrossSessionContext.empty();

    // 尝试恢复上一个未完成会话
    final lastSession = await _storage.loadLastSession();
    if (lastSession != null && !lastSession.isExpired(_sessionTimeout)) {
      _currentSession = lastSession;
      debugPrint('Restored session: ${lastSession.id}, '
          'turns: ${lastSession.turns.length}, '
          'state: ${lastSession.state}');
    }
  }

  /// 是否有可恢复的会话
  bool get hasRecoverableSession =>
      _currentSession != null &&
      _currentSession!.state != PersistedConversationState.idle &&
      !_currentSession!.isExpired(_sessionTimeout);

  /// 获取当前会话
  PersistedSession? get currentSession => _currentSession;

  /// 获取跨会话上下文
  CrossSessionContext get crossSessionContext =>
      _crossSessionContext ?? CrossSessionContext.empty();

  /// 开始新会话
  Future<PersistedSession> startNewSession() async {
    // 保存旧会话的学习数据到跨会话上下文
    if (_currentSession != null) {
      await _learnFromSession(_currentSession!);
    }

    _currentSession = PersistedSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      turns: [],
      state: PersistedConversationState.idle,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _saveCurrentSession();
    return _currentSession!;
  }

  /// 恢复会话
  Future<SessionRecoveryResult> recoverSession() async {
    if (_currentSession == null) {
      return SessionRecoveryResult(
        success: false,
        message: '没有可恢复的会话',
      );
    }

    if (_currentSession!.isExpired(_sessionTimeout)) {
      // 会话已过期，开始新会话
      await startNewSession();
      return SessionRecoveryResult(
        success: false,
        message: '上次会话已过期',
      );
    }

    // 构建恢复提示
    final recoveryPrompt = _buildRecoveryPrompt(_currentSession!);

    return SessionRecoveryResult(
      success: true,
      message: recoveryPrompt,
      session: _currentSession,
      pendingTransaction: _currentSession!.pendingTransaction,
    );
  }

  /// 构建恢复提示
  String _buildRecoveryPrompt(PersistedSession session) {
    switch (session.state) {
      case PersistedConversationState.waitingAmount:
        return '我们上次聊到您要记一笔消费，还需要告诉我金额';

      case PersistedConversationState.waitingCategory:
        final amount = session.pendingTransaction?.amount;
        if (amount != null) {
          return '上次您说要记录 ¥${amount.toStringAsFixed(2)} 的消费，请选择分类';
        }
        return '请选择消费分类';

      case PersistedConversationState.waitingConfirmation:
        final tx = session.pendingTransaction;
        if (tx != null) {
          return '上次您要记录 ¥${tx.amount?.toStringAsFixed(2) ?? "?"} 的'
              '${tx.category != null ? tx.category!.localizedCategoryName : "未分类"}消费，是否确认？';
        }
        return '是否确认记录？';

      case PersistedConversationState.waitingDate:
        return '请告诉我消费日期';

      case PersistedConversationState.waitingDescription:
        return '请补充消费描述';

      case PersistedConversationState.waitingQueryClarification:
        return '请补充查询条件';

      case PersistedConversationState.idle:
        return '有什么可以帮您的？';
    }
  }

  /// 更新会话状态
  Future<void> updateSession({
    required PersistedConversationState state,
    PersistedDialogTurn? newTurn,
    PersistedPendingTransaction? pendingTransaction,
  }) async {
    if (_currentSession == null) {
      await startNewSession();
    }

    final turns = List<PersistedDialogTurn>.from(_currentSession!.turns);

    if (newTurn != null) {
      turns.add(newTurn);
      // 限制历史长度
      if (turns.length > _maxHistoryTurns) {
        turns.removeRange(0, turns.length - _maxHistoryTurns);
      }
    }

    _currentSession = _currentSession!.copyWith(
      state: state,
      turns: turns,
      pendingTransaction: pendingTransaction ?? _currentSession!.pendingTransaction,
      updatedAt: DateTime.now(),
    );

    await _saveCurrentSession();
  }

  /// 添加对话轮次
  Future<void> addTurn({
    required PersistedDialogRole role,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    final turn = PersistedDialogTurn(
      role: role,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    await updateSession(
      state: _currentSession?.state ?? PersistedConversationState.idle,
      newTurn: turn,
    );
  }

  /// 完成会话（记录成功）
  Future<void> completeSession({
    required PersistedPendingTransaction transaction,
  }) async {
    if (_currentSession != null) {
      // 学习用户偏好
      await _learnFromTransaction(transaction);

      // 重置会话状态
      _currentSession = _currentSession!.copyWith(
        state: PersistedConversationState.idle,
        pendingTransaction: null,
        updatedAt: DateTime.now(),
      );

      await _saveCurrentSession();
    }
  }

  /// 清除当前会话
  Future<void> clearSession() async {
    _currentSession = null;
    await _storage.clearLastSession();
  }

  /// ��会话中学习
  Future<void> _learnFromSession(PersistedSession session) async {
    if (_crossSessionContext == null) return;

    // 更新会话统计
    _crossSessionContext = _crossSessionContext!.copyWith(
      totalSessions: _crossSessionContext!.totalSessions + 1,
      lastSessionAt: DateTime.now(),
    );

    await _saveCrossSessionContext();
  }

  /// 从交易中学习用户偏好
  Future<void> _learnFromTransaction(PersistedPendingTransaction tx) async {
    if (_crossSessionContext == null) return;

    // 更新常用分类
    if (tx.category != null) {
      final categories = Map<String, int>.from(
        _crossSessionContext!.frequentCategories,
      );
      categories[tx.category!] = (categories[tx.category!] ?? 0) + 1;

      // 保留前10个常用分类
      final sortedCategories = categories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategories = Map.fromEntries(
        sortedCategories.take(10),
      );

      _crossSessionContext = _crossSessionContext!.copyWith(
        frequentCategories: topCategories,
      );
    }

    // 更新常用金额范围
    if (tx.amount != null) {
      final amounts = List<double>.from(_crossSessionContext!.recentAmounts);
      amounts.add(tx.amount!);
      if (amounts.length > 20) {
        amounts.removeAt(0);
      }

      _crossSessionContext = _crossSessionContext!.copyWith(
        recentAmounts: amounts,
      );
    }

    // 更新常用商家
    if (tx.merchant != null) {
      final merchants = Map<String, int>.from(
        _crossSessionContext!.frequentMerchants,
      );
      merchants[tx.merchant!] = (merchants[tx.merchant!] ?? 0) + 1;

      final sortedMerchants = merchants.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topMerchants = Map.fromEntries(
        sortedMerchants.take(20),
      );

      _crossSessionContext = _crossSessionContext!.copyWith(
        frequentMerchants: topMerchants,
      );
    }

    await _saveCrossSessionContext();
  }

  /// 获取推荐分类（基于历史偏好）
  List<String> getSuggestedCategories({int limit = 5}) {
    if (_crossSessionContext == null) return [];

    final categories = _crossSessionContext!.frequentCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return categories.take(limit).map((e) => e.key).toList();
  }

  /// 获取推荐金额（基于历史偏好）
  List<double> getSuggestedAmounts({int limit = 3}) {
    if (_crossSessionContext == null) return [];

    final amounts = List<double>.from(_crossSessionContext!.recentAmounts);
    if (amounts.isEmpty) return [];

    // 计算常见金额
    final amountCounts = <double, int>{};
    for (final amount in amounts) {
      // 四舍五入到整数
      final rounded = amount.roundToDouble();
      amountCounts[rounded] = (amountCounts[rounded] ?? 0) + 1;
    }

    final sortedAmounts = amountCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedAmounts.take(limit).map((e) => e.key).toList();
  }

  /// 获取推荐商家
  List<String> getSuggestedMerchants({int limit = 5}) {
    if (_crossSessionContext == null) return [];

    final merchants = _crossSessionContext!.frequentMerchants.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return merchants.take(limit).map((e) => e.key).toList();
  }

  /// 获取用户常用记账时段
  TimeOfDay? getPreferredRecordingTime() {
    // 基于历史会话时间分析
    // 实际实现需要记录每次记账时间
    return null;
  }

  /// 保存当前会话
  Future<void> _saveCurrentSession() async {
    if (_currentSession != null) {
      await _storage.saveSession(_currentSession!);
    }
  }

  /// 保存跨会话上下文
  Future<void> _saveCrossSessionContext() async {
    if (_crossSessionContext != null) {
      await _storage.saveCrossSessionContext(_crossSessionContext!);
    }
  }

  /// 导出会话历史（用于分析或调试）
  Future<String> exportSessionHistory() async {
    final sessions = await _storage.loadAllSessions();
    return jsonEncode(sessions.map((s) => s.toJson()).toList());
  }

  /// 清除所有历史数据
  Future<void> clearAllHistory() async {
    _currentSession = null;
    _crossSessionContext = CrossSessionContext.empty();
    await _storage.clearAll();
  }
}

// ==================== 数据模型 ====================

/// 持久化会话状态
enum PersistedConversationState {
  idle,
  waitingAmount,
  waitingCategory,
  waitingDate,
  waitingDescription,
  waitingConfirmation,
  waitingQueryClarification,
}

/// 对话角色
enum PersistedDialogRole {
  user,
  assistant,
  system,
}

/// 对话轮次
class PersistedDialogTurn {
  final PersistedDialogRole role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const PersistedDialogTurn({
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory PersistedDialogTurn.fromJson(Map<String, dynamic> json) {
    return PersistedDialogTurn(
      role: PersistedDialogRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => PersistedDialogRole.user,
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// 待处理交易
class PersistedPendingTransaction {
  final String? type; // 'expense' or 'income'
  final double? amount;
  final String? category;
  final String? merchant;
  final String? description;
  final DateTime? date;

  const PersistedPendingTransaction({
    this.type,
    this.amount,
    this.category,
    this.merchant,
    this.description,
    this.date,
  });

  bool get isComplete =>
      type != null && amount != null && amount! > 0;

  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': amount,
        'category': category,
        'merchant': merchant,
        'description': description,
        'date': date?.toIso8601String(),
      };

  factory PersistedPendingTransaction.fromJson(Map<String, dynamic> json) {
    return PersistedPendingTransaction(
      type: json['type'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      category: json['category'] as String?,
      merchant: json['merchant'] as String?,
      description: json['description'] as String?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : null,
    );
  }

  PersistedPendingTransaction copyWith({
    String? type,
    double? amount,
    String? category,
    String? merchant,
    String? description,
    DateTime? date,
  }) {
    return PersistedPendingTransaction(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }
}

/// 持久化会话
class PersistedSession {
  final String id;
  final List<PersistedDialogTurn> turns;
  final PersistedConversationState state;
  final PersistedPendingTransaction? pendingTransaction;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersistedSession({
    required this.id,
    required this.turns,
    required this.state,
    this.pendingTransaction,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isExpired(Duration timeout) {
    return DateTime.now().difference(updatedAt) > timeout;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'turns': turns.map((t) => t.toJson()).toList(),
        'state': state.name,
        'pendingTransaction': pendingTransaction?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PersistedSession.fromJson(Map<String, dynamic> json) {
    return PersistedSession(
      id: json['id'] as String,
      turns: (json['turns'] as List<dynamic>)
          .map((t) => PersistedDialogTurn.fromJson(t as Map<String, dynamic>))
          .toList(),
      state: PersistedConversationState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => PersistedConversationState.idle,
      ),
      pendingTransaction: json['pendingTransaction'] != null
          ? PersistedPendingTransaction.fromJson(
              json['pendingTransaction'] as Map<String, dynamic>,
            )
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  PersistedSession copyWith({
    String? id,
    List<PersistedDialogTurn>? turns,
    PersistedConversationState? state,
    PersistedPendingTransaction? pendingTransaction,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersistedSession(
      id: id ?? this.id,
      turns: turns ?? this.turns,
      state: state ?? this.state,
      pendingTransaction: pendingTransaction ?? this.pendingTransaction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 跨会话上下文
class CrossSessionContext {
  final Map<String, int> frequentCategories;
  final Map<String, int> frequentMerchants;
  final List<double> recentAmounts;
  final int totalSessions;
  final int totalTransactions;
  final DateTime? lastSessionAt;
  final Map<String, dynamic> userPreferences;

  const CrossSessionContext({
    required this.frequentCategories,
    required this.frequentMerchants,
    required this.recentAmounts,
    required this.totalSessions,
    required this.totalTransactions,
    this.lastSessionAt,
    required this.userPreferences,
  });

  factory CrossSessionContext.empty() {
    return const CrossSessionContext(
      frequentCategories: {},
      frequentMerchants: {},
      recentAmounts: [],
      totalSessions: 0,
      totalTransactions: 0,
      userPreferences: {},
    );
  }

  Map<String, dynamic> toJson() => {
        'frequentCategories': frequentCategories,
        'frequentMerchants': frequentMerchants,
        'recentAmounts': recentAmounts,
        'totalSessions': totalSessions,
        'totalTransactions': totalTransactions,
        'lastSessionAt': lastSessionAt?.toIso8601String(),
        'userPreferences': userPreferences,
      };

  factory CrossSessionContext.fromJson(Map<String, dynamic> json) {
    return CrossSessionContext(
      frequentCategories: Map<String, int>.from(
        json['frequentCategories'] as Map<String, dynamic>? ?? {},
      ),
      frequentMerchants: Map<String, int>.from(
        json['frequentMerchants'] as Map<String, dynamic>? ?? {},
      ),
      recentAmounts: (json['recentAmounts'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      totalSessions: json['totalSessions'] as int? ?? 0,
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      lastSessionAt: json['lastSessionAt'] != null
          ? DateTime.parse(json['lastSessionAt'] as String)
          : null,
      userPreferences: json['userPreferences'] as Map<String, dynamic>? ?? {},
    );
  }

  CrossSessionContext copyWith({
    Map<String, int>? frequentCategories,
    Map<String, int>? frequentMerchants,
    List<double>? recentAmounts,
    int? totalSessions,
    int? totalTransactions,
    DateTime? lastSessionAt,
    Map<String, dynamic>? userPreferences,
  }) {
    return CrossSessionContext(
      frequentCategories: frequentCategories ?? this.frequentCategories,
      frequentMerchants: frequentMerchants ?? this.frequentMerchants,
      recentAmounts: recentAmounts ?? this.recentAmounts,
      totalSessions: totalSessions ?? this.totalSessions,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
      userPreferences: userPreferences ?? this.userPreferences,
    );
  }
}

/// 会话恢复结果
class SessionRecoveryResult {
  final bool success;
  final String message;
  final PersistedSession? session;
  final PersistedPendingTransaction? pendingTransaction;

  const SessionRecoveryResult({
    required this.success,
    required this.message,
    this.session,
    this.pendingTransaction,
  });
}

/// 时间点
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});
}

// ==================== 存储接口 ====================

/// 对话上下文存储接口
abstract class DialogContextStorage {
  /// 保存会话
  Future<void> saveSession(PersistedSession session);

  /// 加载最近会话
  Future<PersistedSession?> loadLastSession();

  /// 加载所有会话
  Future<List<PersistedSession>> loadAllSessions();

  /// 清除最近会话
  Future<void> clearLastSession();

  /// 保存跨会话上下文
  Future<void> saveCrossSessionContext(CrossSessionContext context);

  /// 加载跨会话上下文
  Future<CrossSessionContext?> loadCrossSessionContext();

  /// 清除所有数据
  Future<void> clearAll();
}

/// 内存存储实现（用于测试）
class InMemoryDialogContextStorage implements DialogContextStorage {
  PersistedSession? _lastSession;
  CrossSessionContext? _crossSessionContext;
  final List<PersistedSession> _allSessions = [];

  @override
  Future<void> saveSession(PersistedSession session) async {
    _lastSession = session;

    // 更新或添加到历史
    final index = _allSessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _allSessions[index] = session;
    } else {
      _allSessions.add(session);
    }
  }

  @override
  Future<PersistedSession?> loadLastSession() async => _lastSession;

  @override
  Future<List<PersistedSession>> loadAllSessions() async =>
      List.unmodifiable(_allSessions);

  @override
  Future<void> clearLastSession() async {
    _lastSession = null;
  }

  @override
  Future<void> saveCrossSessionContext(CrossSessionContext context) async {
    _crossSessionContext = context;
  }

  @override
  Future<CrossSessionContext?> loadCrossSessionContext() async =>
      _crossSessionContext;

  @override
  Future<void> clearAll() async {
    _lastSession = null;
    _crossSessionContext = null;
    _allSessions.clear();
  }
}

/// SharedPreferences存储实现
class SharedPreferencesDialogContextStorage implements DialogContextStorage {
  static const String _lastSessionKey = 'dialog_last_session';
  static const String _crossSessionContextKey = 'dialog_cross_session_context';
  static const String _allSessionsKey = 'dialog_all_sessions';

  final SharedPreferencesWrapper _prefs;

  SharedPreferencesDialogContextStorage(this._prefs);

  @override
  Future<void> saveSession(PersistedSession session) async {
    await _prefs.setString(_lastSessionKey, jsonEncode(session.toJson()));

    // 保存到历史
    final allSessions = await loadAllSessions();
    final index = allSessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      allSessions[index] = session;
    } else {
      allSessions.add(session);
    }

    // 只保留最近50个会话
    final recentSessions = allSessions.length > 50
        ? allSessions.sublist(allSessions.length - 50)
        : allSessions;

    await _prefs.setString(
      _allSessionsKey,
      jsonEncode(recentSessions.map((s) => s.toJson()).toList()),
    );
  }

  @override
  Future<PersistedSession?> loadLastSession() async {
    final json = _prefs.getString(_lastSessionKey);
    if (json == null) return null;

    try {
      return PersistedSession.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Failed to load last session: $e');
      return null;
    }
  }

  @override
  Future<List<PersistedSession>> loadAllSessions() async {
    final json = _prefs.getString(_allSessionsKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => PersistedSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load all sessions: $e');
      return [];
    }
  }

  @override
  Future<void> clearLastSession() async {
    await _prefs.remove(_lastSessionKey);
  }

  @override
  Future<void> saveCrossSessionContext(CrossSessionContext context) async {
    await _prefs.setString(
      _crossSessionContextKey,
      jsonEncode(context.toJson()),
    );
  }

  @override
  Future<CrossSessionContext?> loadCrossSessionContext() async {
    final json = _prefs.getString(_crossSessionContextKey);
    if (json == null) return null;

    try {
      return CrossSessionContext.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Failed to load cross session context: $e');
      return null;
    }
  }

  @override
  Future<void> clearAll() async {
    await _prefs.remove(_lastSessionKey);
    await _prefs.remove(_crossSessionContextKey);
    await _prefs.remove(_allSessionsKey);
  }
}

/// SharedPreferences包装器接口
abstract class SharedPreferencesWrapper {
  String? getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

// ==================== 对话管理器集成 ====================

/// 可持久化的对话管理器
class PersistableDialogManager {
  final DialogContextPersistenceService _persistenceService;
  final DialogManagerServiceInterface _dialogManager;

  PersistableDialogManager({
    required DialogContextPersistenceService persistenceService,
    required DialogManagerServiceInterface dialogManager,
  })  : _persistenceService = persistenceService,
        _dialogManager = dialogManager;

  /// 初始化并尝试恢复会话
  Future<SessionRecoveryResult> initializeAndRecover() async {
    await _persistenceService.initialize();

    if (_persistenceService.hasRecoverableSession) {
      return await _persistenceService.recoverSession();
    }

    await _persistenceService.startNewSession();
    return SessionRecoveryResult(
      success: false,
      message: '开始新会话',
    );
  }

  /// 处理用户输入（带持久化）
  Future<PersistableAssistantResponse> processInput(String input) async {
    // 记录用户输入
    await _persistenceService.addTurn(
      role: PersistedDialogRole.user,
      content: input,
    );

    // 调用对话管理器处理
    final response = await _dialogManager.processInput(input);

    // 记录助手响应
    await _persistenceService.addTurn(
      role: PersistedDialogRole.assistant,
      content: response.message,
    );

    // 更新会话状态
    await _persistenceService.updateSession(
      state: _mapConversationState(response.conversationState),
      pendingTransaction: response.pendingTransaction != null
          ? PersistedPendingTransaction(
              type: response.pendingTransaction!.type,
              amount: response.pendingTransaction!.amount,
              category: response.pendingTransaction!.category,
              description: response.pendingTransaction!.description,
              date: response.pendingTransaction!.date,
            )
          : null,
    );

    // 添加历史偏好建议
    return PersistableAssistantResponse(
      message: response.message,
      suggestions: response.suggestions,
      suggestedCategories: _persistenceService.getSuggestedCategories(),
      suggestedAmounts: _persistenceService.getSuggestedAmounts(),
      suggestedMerchants: _persistenceService.getSuggestedMerchants(),
    );
  }

  PersistedConversationState _mapConversationState(String? state) {
    switch (state) {
      case 'waitingAmount':
        return PersistedConversationState.waitingAmount;
      case 'waitingCategory':
        return PersistedConversationState.waitingCategory;
      case 'waitingDate':
        return PersistedConversationState.waitingDate;
      case 'waitingDescription':
        return PersistedConversationState.waitingDescription;
      case 'waitingConfirmation':
        return PersistedConversationState.waitingConfirmation;
      case 'waitingQueryClarification':
        return PersistedConversationState.waitingQueryClarification;
      default:
        return PersistedConversationState.idle;
    }
  }
}

/// 对话管理器接口
abstract class DialogManagerServiceInterface {
  Future<DialogManagerResponse> processInput(String input);
}

/// 对话管理器响应
class DialogManagerResponse {
  final String message;
  final List<String>? suggestions;
  final String? conversationState;
  final PendingTransactionInfo? pendingTransaction;

  const DialogManagerResponse({
    required this.message,
    this.suggestions,
    this.conversationState,
    this.pendingTransaction,
  });
}

/// 待处理交易信息
class PendingTransactionInfo {
  final String? type;
  final double? amount;
  final String? category;
  final String? description;
  final DateTime? date;

  const PendingTransactionInfo({
    this.type,
    this.amount,
    this.category,
    this.description,
    this.date,
  });
}

/// 可持久化助手响应
class PersistableAssistantResponse {
  final String message;
  final List<String>? suggestions;
  final List<String> suggestedCategories;
  final List<double> suggestedAmounts;
  final List<String> suggestedMerchants;

  const PersistableAssistantResponse({
    required this.message,
    this.suggestions,
    this.suggestedCategories = const [],
    this.suggestedAmounts = const [],
    this.suggestedMerchants = const [],
  });
}
