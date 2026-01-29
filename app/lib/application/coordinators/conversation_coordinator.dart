/// Conversation Coordinator
///
/// 负责对话管理的协调器，从VoiceServiceCoordinator中提取。
/// 遵循单一职责原则，仅处理对话上下文、聊天模式和多轮交互。
library;

import 'package:flutter/foundation.dart';

/// 对话模式
enum ConversationMode {
  /// 正常记账模式
  normal,

  /// 闲聊模式
  chat,

  /// 金额补充模式（等待用户补充金额）
  awaitingAmount,

  /// 分类补充模式（等待用户补充分类）
  awaitingCategory,

  /// 确认模式（等待用户确认操作）
  awaitingConfirmation,

  /// 消歧模式（等待用户选择）
  awaitingDisambiguation,
}

/// 对话轮次
class ConversationTurn {
  final String id;
  final ConversationRole role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ConversationTurn({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  ConversationTurn copyWith({
    String? id,
    ConversationRole? role,
    String? content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ConversationTurn(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// 对话角色
enum ConversationRole {
  user,
  assistant,
  system,
}

/// 待补充的不完整意图
class IncompleteIntent {
  final String intentType;
  final Map<String, dynamic> partialEntities;
  final List<String> missingFields;
  final DateTime createdAt;
  final String? promptMessage;

  const IncompleteIntent({
    required this.intentType,
    required this.partialEntities,
    required this.missingFields,
    required this.createdAt,
    this.promptMessage,
  });

  bool get isExpired {
    const timeout = Duration(minutes: 5);
    return DateTime.now().difference(createdAt) > timeout;
  }
}

/// 交易引用（用于代词解析）
class TransactionReference {
  final String transactionId;
  final String description;
  final double amount;
  final String category;
  final DateTime date;

  const TransactionReference({
    required this.transactionId,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
  });
}

/// 对话协调器
///
/// 职责：
/// - 管理对话上下文和历史
/// - 处理多轮对话（金额/分类补充）
/// - 管理闲聊模式
/// - 解析代词和上下文引用
class ConversationCoordinator extends ChangeNotifier {
  /// 对话历史
  final List<ConversationTurn> _history = [];

  /// 最大历史轮数
  final int maxHistoryTurns;

  /// 当前会话ID
  String? _sessionId;

  /// 当前对话模式
  ConversationMode _mode = ConversationMode.normal;

  /// 待补充的不完整意图
  IncompleteIntent? _pendingIntent;

  /// 最后一次交易引用（用于代词解析）
  TransactionReference? _lastTransactionRef;

  /// 闲聊历史（独立于记账对话）
  final List<ConversationTurn> _chatHistory = [];

  /// 最大闲聊历史轮数
  static const int _maxChatHistoryTurns = 10;

  ConversationCoordinator({this.maxHistoryTurns = 5});

  /// 当前会话ID
  String? get sessionId => _sessionId;

  /// 当前对话模式
  ConversationMode get mode => _mode;

  /// 是否处于闲聊模式
  bool get isChatMode => _mode == ConversationMode.chat;

  /// 是否在等待用户补充信息
  bool get isAwaitingInput =>
      _mode == ConversationMode.awaitingAmount ||
      _mode == ConversationMode.awaitingCategory ||
      _mode == ConversationMode.awaitingConfirmation ||
      _mode == ConversationMode.awaitingDisambiguation;

  /// 待补充的意图
  IncompleteIntent? get pendingIntent => _pendingIntent;

  /// 最后交易引用
  TransactionReference? get lastTransactionRef => _lastTransactionRef;

  /// 对话历史
  List<ConversationTurn> get history => List.unmodifiable(_history);

  /// 闲聊历史
  List<ConversationTurn> get chatHistory => List.unmodifiable(_chatHistory);

  // ==================== 会话管理 ====================

  /// 开始新会话
  void startSession() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _history.clear();
    _chatHistory.clear();
    _mode = ConversationMode.normal;
    _pendingIntent = null;
    _lastTransactionRef = null;
    debugPrint('[ConversationCoordinator] 开始会话: $_sessionId');
    notifyListeners();
  }

  /// 结束会话
  void endSession() {
    debugPrint('[ConversationCoordinator] 结束会话: $_sessionId');
    _sessionId = null;
    _history.clear();
    _chatHistory.clear();
    _mode = ConversationMode.normal;
    _pendingIntent = null;
    _lastTransactionRef = null;
    notifyListeners();
  }

  // ==================== 对话轮次管理 ====================

  /// 添加用户输入
  void addUserInput(String content, {Map<String, dynamic>? metadata}) {
    final turn = ConversationTurn(
      id: _generateTurnId(),
      role: ConversationRole.user,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _history.add(turn);
    _trimHistory();
    notifyListeners();

    debugPrint('[ConversationCoordinator] 用户输入: "$content"');
  }

  /// 添加助手响应
  void addAssistantResponse(
    String content, {
    TransactionReference? transactionRef,
    Map<String, dynamic>? metadata,
  }) {
    final turn = ConversationTurn(
      id: _generateTurnId(),
      role: ConversationRole.assistant,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _history.add(turn);

    if (transactionRef != null) {
      _lastTransactionRef = transactionRef;
    }

    _trimHistory();
    notifyListeners();

    debugPrint('[ConversationCoordinator] 助手响应: "$content"');
  }

  /// 添加系统消息
  void addSystemMessage(String content) {
    final turn = ConversationTurn(
      id: _generateTurnId(),
      role: ConversationRole.system,
      content: content,
      timestamp: DateTime.now(),
    );

    _history.add(turn);
    _trimHistory();
    notifyListeners();
  }

  // ==================== 模式管理 ====================

  /// 进入闲聊模式
  void enterChatMode() {
    _mode = ConversationMode.chat;
    debugPrint('[ConversationCoordinator] 进入闲聊模式');
    notifyListeners();
  }

  /// 退出闲聊模式
  void exitChatMode() {
    _mode = ConversationMode.normal;
    _chatHistory.clear();
    debugPrint('[ConversationCoordinator] 退出闲聊模式');
    notifyListeners();
  }

  /// 设置为等待金额补充模式
  void setAwaitingAmount(IncompleteIntent intent) {
    _mode = ConversationMode.awaitingAmount;
    _pendingIntent = intent;
    debugPrint('[ConversationCoordinator] 设置等待金额补充模式');
    notifyListeners();
  }

  /// 设置为等待分类补充模式
  void setAwaitingCategory(IncompleteIntent intent) {
    _mode = ConversationMode.awaitingCategory;
    _pendingIntent = intent;
    debugPrint('[ConversationCoordinator] 设置等待分类补充模式');
    notifyListeners();
  }

  /// 设置为等待确认模式
  void setAwaitingConfirmation(IncompleteIntent intent) {
    _mode = ConversationMode.awaitingConfirmation;
    _pendingIntent = intent;
    debugPrint('[ConversationCoordinator] 设置等待确认模式');
    notifyListeners();
  }

  /// 设置为等待消歧模式
  void setAwaitingDisambiguation(IncompleteIntent intent) {
    _mode = ConversationMode.awaitingDisambiguation;
    _pendingIntent = intent;
    debugPrint('[ConversationCoordinator] 设置等待消歧模式');
    notifyListeners();
  }

  /// 清除待处理意图，恢复正常模式
  void clearPendingIntent() {
    _pendingIntent = null;
    _mode = ConversationMode.normal;
    debugPrint('[ConversationCoordinator] 清除待处理意图');
    notifyListeners();
  }

  // ==================== 闲聊管理 ====================

  /// 添加闲聊轮次
  void addChatTurn({
    required String userInput,
    required String assistantResponse,
  }) {
    _chatHistory.add(ConversationTurn(
      id: _generateTurnId(),
      role: ConversationRole.user,
      content: userInput,
      timestamp: DateTime.now(),
    ));
    _chatHistory.add(ConversationTurn(
      id: _generateTurnId(),
      role: ConversationRole.assistant,
      content: assistantResponse,
      timestamp: DateTime.now(),
    ));

    // 保持历史轮数在限制内
    while (_chatHistory.length > _maxChatHistoryTurns * 2) {
      _chatHistory.removeAt(0);
    }

    notifyListeners();
  }

  /// 获取闲聊历史的格式化字符串（用于LLM上下文）
  String getChatHistoryForLLM() {
    if (_chatHistory.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('之前的对话：');
    for (final turn in _chatHistory) {
      final roleLabel = turn.role == ConversationRole.user ? '用户' : '助手';
      buffer.writeln('$roleLabel：${turn.content}');
    }
    return buffer.toString();
  }

  // ==================== 上下文解析 ====================

  /// 解析代词引用
  ///
  /// 将"它"、"这笔"、"那个"等代词解析为具体引用
  String? resolveReference(String text) {
    if (_lastTransactionRef == null) return null;

    // 检测代词
    final pronounPatterns = [
      RegExp(r'(删掉|修改|取消)(它|这笔|那笔|这个|那个)'),
      RegExp(r'(把|将)(它|这笔|那笔|这个|那个)'),
      RegExp(r'^(它|这笔|那笔|这个|那个)'),
    ];

    for (final pattern in pronounPatterns) {
      if (pattern.hasMatch(text)) {
        return _lastTransactionRef!.transactionId;
      }
    }

    return null;
  }

  /// 解析时间相对引用
  ///
  /// 将"刚才"、"上一笔"等转换为具体时间/引用
  DateTime? resolveTimeReference(String text) {
    final now = DateTime.now();

    if (text.contains('刚才') || text.contains('刚刚')) {
      return now.subtract(const Duration(minutes: 5));
    }

    if (text.contains('今天')) {
      return DateTime(now.year, now.month, now.day);
    }

    if (text.contains('昨天')) {
      return DateTime(now.year, now.month, now.day - 1);
    }

    if (text.contains('前天')) {
      return DateTime(now.year, now.month, now.day - 2);
    }

    return null;
  }

  /// 获取最近的对话上下文（用于意图理解）
  String getRecentContext({int turns = 3}) {
    if (_history.isEmpty) return '';

    final recentTurns = _history.length <= turns * 2
        ? _history
        : _history.sublist(_history.length - turns * 2);

    final buffer = StringBuffer();
    for (final turn in recentTurns) {
      final roleLabel = turn.role == ConversationRole.user ? '用户' : '助手';
      buffer.writeln('$roleLabel：${turn.content}');
    }
    return buffer.toString();
  }

  // ==================== 私有方法 ====================

  /// 生成轮次ID
  String _generateTurnId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_history.length}';
  }

  /// 裁剪历史
  void _trimHistory() {
    final maxLength = maxHistoryTurns * 2;
    if (_history.length > maxLength) {
      _history.removeRange(0, _history.length - maxLength);
    }
  }
}
