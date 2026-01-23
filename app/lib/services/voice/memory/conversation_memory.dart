import 'package:flutter/foundation.dart';

/// 对话轮次
class ConversationTurn {
  /// 轮次ID
  final String id;

  /// 用户输入
  final String userInput;

  /// 智能体响应
  final String agentResponse;

  /// 关联的操作（如果有）
  final VoiceAction? action;

  /// 时间戳
  final DateTime timestamp;

  /// 是否已完成
  final bool isCompleted;

  ConversationTurn({
    required this.id,
    required this.userInput,
    required this.agentResponse,
    this.action,
    DateTime? timestamp,
    this.isCompleted = true,
  }) : timestamp = timestamp ?? DateTime.now();

  ConversationTurn copyWith({
    String? agentResponse,
    VoiceAction? action,
    bool? isCompleted,
  }) {
    return ConversationTurn(
      id: id,
      userInput: userInput,
      agentResponse: agentResponse ?? this.agentResponse,
      action: action ?? this.action,
      timestamp: timestamp,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// 语音操作
class VoiceAction {
  /// 操作类型
  final String type;

  /// 操作数据
  final Map<String, dynamic> data;

  /// 操作结果
  final ActionResult? result;

  /// 时间戳
  final DateTime timestamp;

  const VoiceAction({
    required this.type,
    required this.data,
    this.result,
    required this.timestamp,
  });

  /// 是否为记账操作
  bool get isBookkeeping => type == 'expense' || type == 'income';

  /// 是否为修改操作
  bool get isModification => type == 'modify';

  /// 是否为删除操作
  bool get isDeletion => type == 'delete';

  /// 是否为查询操作
  bool get isQuery => type == 'query';

  /// 获取金额（如果有）
  double? get amount => data['amount'] as double?;

  /// 获取分类（如果有）
  String? get category => data['category'] as String?;

  /// 获取记录ID（如果有）
  String? get recordId => data['recordId'] as String?;
}

/// 操作结果
class ActionResult {
  final bool success;
  final String? recordId;
  final String? message;

  const ActionResult({
    required this.success,
    this.recordId,
    this.message,
  });
}

/// 会话级短期记忆
///
/// 职责：
/// - 管理对话历史（3-5轮）
/// - 提供上下文摘要供LLM使用
/// - 支持代词指代解析
/// - 记录最近操作用于"改成50"类指代
class ConversationMemory {
  /// 配置
  final ConversationMemoryConfig config;

  /// 对话历史
  final List<ConversationTurn> _turns = [];

  /// 最近操作（供"改成50"类指代使用）
  VoiceAction? _lastAction;

  /// 最近提到的实体
  final Map<String, ReferencedEntity> _recentEntities = {};

  ConversationMemory({ConversationMemoryConfig? config})
      : config = config ?? const ConversationMemoryConfig();

  // ==================== 公共API ====================

  /// 对话轮次列表
  List<ConversationTurn> get turns => List.unmodifiable(_turns);

  /// 轮次数量
  int get turnCount => _turns.length;

  /// 最近操作
  VoiceAction? get lastAction => _lastAction;

  /// 是否有对话历史
  bool get hasHistory => _turns.isNotEmpty;

  /// 添加对话轮次
  void addTurn({
    required String userInput,
    required String agentResponse,
    VoiceAction? action,
  }) {
    final turn = ConversationTurn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userInput: userInput,
      agentResponse: agentResponse,
      action: action,
    );

    _turns.add(turn);

    // 记录最近操作
    if (action != null) {
      _lastAction = action;
      _extractEntities(action);
    }

    // 限制历史长度
    while (_turns.length > config.maxTurns) {
      _turns.removeAt(0);
    }

    debugPrint('[ConversationMemory] 添加轮次，当前${_turns.length}轮');
  }

  /// 更新最后一轮的响应
  void updateLastTurnResponse(String response) {
    if (_turns.isEmpty) return;
    _turns[_turns.length - 1] = _turns.last.copyWith(agentResponse: response);
  }

  /// 更新最后一轮的操作
  void updateLastTurnAction(VoiceAction action) {
    if (_turns.isEmpty) return;
    _turns[_turns.length - 1] = _turns.last.copyWith(action: action);
    _lastAction = action;
    _extractEntities(action);
  }

  /// 获取上下文摘要（供LLM使用）
  String getContextForLLM() {
    if (_turns.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('最近对话：');

    for (final turn in _turns) {
      buffer.writeln('用户: ${turn.userInput}');
      buffer.writeln('助手: ${turn.agentResponse}');
      if (turn.action != null) {
        buffer.writeln('[操作: ${turn.action!.type}]');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 获取简短上下文（用于意图识别）
  String getShortContext() {
    if (_turns.isEmpty) return '';

    // 只取最近2轮
    final recentTurns = _turns.length > 2
        ? _turns.sublist(_turns.length - 2)
        : _turns;

    return recentTurns.map((t) => '${t.userInput} -> ${t.agentResponse}').join('\n');
  }

  /// 解析操作指代
  ///
  /// 例如："改成50" -> 修改最近操作的金额
  /// "删掉它" -> 删除最近操作
  ActionReference? resolveActionReference(String input) {
    final normalizedInput = input.toLowerCase().trim();

    // 修改金额指代
    final amountPattern = RegExp(r'改成?(\d+(?:\.\d+)?)');
    final amountMatch = amountPattern.firstMatch(normalizedInput);
    if (amountMatch != null && _lastAction != null) {
      final newAmount = double.tryParse(amountMatch.group(1)!);
      if (newAmount != null) {
        return ActionReference(
          type: ActionReferenceType.modifyAmount,
          targetAction: _lastAction!,
          newValue: newAmount,
        );
      }
    }

    // 修改分类指代
    final categoryPattern = RegExp(r'改成?(.+)');
    if (normalizedInput.contains('改成') || normalizedInput.contains('改为')) {
      final match = categoryPattern.firstMatch(normalizedInput);
      if (match != null && _lastAction != null) {
        final newCategory = match.group(1)?.trim();
        // 排除数字（金额修改）
        if (newCategory != null && !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(newCategory)) {
          return ActionReference(
            type: ActionReferenceType.modifyCategory,
            targetAction: _lastAction!,
            newValue: newCategory,
          );
        }
      }
    }

    // 删除指代
    if (_matchDeletePattern(normalizedInput) && _lastAction != null) {
      return ActionReference(
        type: ActionReferenceType.delete,
        targetAction: _lastAction!,
      );
    }

    // 取消指代
    if (_matchCancelPattern(normalizedInput) && _lastAction != null) {
      return ActionReference(
        type: ActionReferenceType.cancel,
        targetAction: _lastAction!,
      );
    }

    return null;
  }

  /// 获取最近提到的实体
  ReferencedEntity? getRecentEntity(String type) {
    return _recentEntities[type];
  }

  /// 清除历史
  void clear() {
    _turns.clear();
    _lastAction = null;
    _recentEntities.clear();
    debugPrint('[ConversationMemory] 历史已清除');
  }

  // ==================== 内部方法 ====================

  /// 从操作中提取实体
  void _extractEntities(VoiceAction action) {
    // 提取金额
    if (action.amount != null) {
      _recentEntities['amount'] = ReferencedEntity(
        type: 'amount',
        value: action.amount,
        timestamp: action.timestamp,
      );
    }

    // 提取分类
    if (action.category != null) {
      _recentEntities['category'] = ReferencedEntity(
        type: 'category',
        value: action.category,
        timestamp: action.timestamp,
      );
    }

    // 提取记录ID
    if (action.recordId != null) {
      _recentEntities['recordId'] = ReferencedEntity(
        type: 'recordId',
        value: action.recordId,
        timestamp: action.timestamp,
      );
    }
  }

  /// 匹配删除模式
  bool _matchDeletePattern(String input) {
    final patterns = [
      '删掉它',
      '删了',
      '删除',
      '删掉',
      '不要了',
      '取消它',
    ];
    return patterns.any((p) => input.contains(p));
  }

  /// 匹配取消模式
  bool _matchCancelPattern(String input) {
    final patterns = [
      '取消',
      '算了',
      '不记了',
      '别记了',
    ];
    return patterns.any((p) => input.contains(p));
  }
}

/// 会话记忆配置
class ConversationMemoryConfig {
  /// 最大保留轮次
  final int maxTurns;

  /// 实体过期时间（秒）
  final int entityExpirationSeconds;

  const ConversationMemoryConfig({
    this.maxTurns = 5,
    this.entityExpirationSeconds = 300,
  });
}

/// 操作指代类型
enum ActionReferenceType {
  /// 修改金额
  modifyAmount,

  /// 修改分类
  modifyCategory,

  /// 删除
  delete,

  /// 取消
  cancel,
}

/// 操作指代
class ActionReference {
  /// 指代类型
  final ActionReferenceType type;

  /// 目标操作
  final VoiceAction targetAction;

  /// 新值（用于修改）
  final dynamic newValue;

  const ActionReference({
    required this.type,
    required this.targetAction,
    this.newValue,
  });
}

/// 被引用的实体
class ReferencedEntity {
  final String type;
  final dynamic value;
  final DateTime timestamp;

  const ReferencedEntity({
    required this.type,
    required this.value,
    required this.timestamp,
  });

  /// 是否已过期
  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}
