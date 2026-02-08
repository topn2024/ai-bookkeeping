/// Conversation History Manager
///
/// 负责对话历史管理的管理器，从 GlobalVoiceAssistantManager 中提取。
/// 遵循单一职责原则，仅处理对话历史的存储和检索。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 消息类型
enum MessageType {
  user,
  assistant,
  system,
}

/// 聊天消息
class ChatMessage {
  final String id;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.metadata,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      type: type,
      content: content ?? this.content,
      timestamp: timestamp,
      metadata: metadata ?? this.metadata,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    try {
      return ChatMessage(
        id: json['id'] as String? ?? '',
        type: MessageType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => MessageType.user,
        ),
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      // 数据损坏时返回占位消息，避免整个历史丢失
      return ChatMessage(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.user,
        content: '[数据恢复失败]',
        timestamp: DateTime.now(),
      );
    }
  }
}

/// 对话历史管理器
///
/// 职责：
/// - 存储对话历史
/// - 持久化对话历史
/// - 提供历史检索
/// - 管理历史大小限制
class ConversationHistoryManager extends ChangeNotifier {
  /// 对话历史
  final List<ChatMessage> _history = [];

  /// 最大历史记录数
  final int maxHistorySize;

  /// 持久化键名
  static const String _storageKey = 'conversation_history';

  /// SharedPreferences 实例
  SharedPreferences? _prefs;

  /// 是否自动持久化
  final bool autoPersist;

  ConversationHistoryManager({
    this.maxHistorySize = 50,
    this.autoPersist = true,
  });

  /// 对话历史
  List<ChatMessage> get history => List.unmodifiable(_history);

  /// 历史记录数量
  int get length => _history.length;

  /// 是否为空
  bool get isEmpty => _history.isEmpty;

  /// 是否非空
  bool get isNotEmpty => _history.isNotEmpty;

  /// 最后一条消息
  ChatMessage? get lastMessage => _history.isNotEmpty ? _history.last : null;

  // ==================== 初始化 ====================

  /// 初始化（加载持久化数据）
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFromStorage();
    debugPrint('[ConversationHistoryManager] 初始化完成，加载了 ${_history.length} 条历史');
  }

  // ==================== 消息操作 ====================

  /// 添加用户消息
  void addUserMessage(String content, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage(
      id: _generateId(),
      type: MessageType.user,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加助手消息
  void addAssistantMessage(String content, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage(
      id: _generateId(),
      type: MessageType.assistant,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加系统消息
  void addSystemMessage(String content, {Map<String, dynamic>? metadata}) {
    _addMessage(ChatMessage(
      id: _generateId(),
      type: MessageType.system,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加加载中的占位消息
  String addLoadingMessage() {
    final id = _generateId();
    _addMessage(ChatMessage(
      id: id,
      type: MessageType.assistant,
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    ));
    return id;
  }

  /// 更新消息内容
  void updateMessage(String messageId, String content, {bool isLoading = false}) {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _history[index] = _history[index].copyWith(
        content: content,
        isLoading: isLoading,
      );
      notifyListeners();
      if (autoPersist) _saveToStorage();
    }
  }

  /// 删除消息
  void removeMessage(String messageId) {
    _history.removeWhere((m) => m.id == messageId);
    notifyListeners();
    if (autoPersist) _saveToStorage();
  }

  /// 清空历史
  void clear() {
    _history.clear();
    notifyListeners();
    if (autoPersist) _saveToStorage();
    debugPrint('[ConversationHistoryManager] 历史已清空');
  }

  // ==================== 查询方法 ====================

  /// 获取最近 N 条消息
  List<ChatMessage> getRecent({int count = 10}) {
    if (_history.length <= count) {
      return List.unmodifiable(_history);
    }
    return List.unmodifiable(_history.sublist(_history.length - count));
  }

  /// 获取用户消息
  List<ChatMessage> getUserMessages() {
    return _history.where((m) => m.type == MessageType.user).toList();
  }

  /// 获取助手消息
  List<ChatMessage> getAssistantMessages() {
    return _history.where((m) => m.type == MessageType.assistant).toList();
  }

  /// 搜索消息
  List<ChatMessage> search(String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return _history
        .where((m) => m.content.toLowerCase().contains(lowerKeyword))
        .toList();
  }

  /// 获取上下文摘要（用于 LLM）
  String getContextSummary({int maxMessages = 5}) {
    final recent = getRecent(count: maxMessages);
    if (recent.isEmpty) return '';

    final buffer = StringBuffer();
    for (final msg in recent) {
      final role = msg.type == MessageType.user ? '用户' : '助手';
      buffer.writeln('$role: ${msg.content}');
    }
    return buffer.toString().trim();
  }

  // ==================== 私有方法 ====================

  /// 添加消息（内部方法）
  void _addMessage(ChatMessage message) {
    _history.add(message);
    _trimHistory();
    notifyListeners();
    if (autoPersist) _saveToStorage();
  }

  /// 裁剪历史
  void _trimHistory() {
    while (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// 生成消息 ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_history.length}';
  }

  /// 保存到持久化存储
  Future<void> _saveToStorage() async {
    if (_prefs == null) return;

    try {
      final jsonList = _history.map((m) => m.toJson()).toList();
      await _prefs!.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ConversationHistoryManager] 保存失败: $e');
    }
  }

  /// 从持久化存储加载
  Future<void> _loadFromStorage() async {
    if (_prefs == null) return;

    try {
      final jsonString = _prefs!.getString(_storageKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final loaded = <ChatMessage>[];
        for (final json in jsonList) {
          loaded.add(ChatMessage.fromJson(json as Map<String, dynamic>));
        }
        // 加载成功后再替换历史，避免解析失败时清空已有数据
        _history.clear();
        _history.addAll(loaded);
      }
    } catch (e) {
      debugPrint('[ConversationHistoryManager] 加载失败: $e');
    }
  }
}
