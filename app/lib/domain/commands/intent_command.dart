/// Intent Command
///
/// Command Pattern 基类，用于封装意图操作。
/// 提供统一的执行接口和撤销支持。
library;

import 'dart:async';

/// 命令执行结果
class CommandResult {
  /// 是否成功
  final bool success;

  /// 结果数据
  final Map<String, dynamic>? data;

  /// 错误消息
  final String? errorMessage;

  /// 执行耗时（毫秒）
  final int? durationMs;

  /// 是否可撤销
  final bool canUndo;

  const CommandResult({
    required this.success,
    this.data,
    this.errorMessage,
    this.durationMs,
    this.canUndo = false,
  });

  /// 成功结果
  factory CommandResult.success({
    Map<String, dynamic>? data,
    int? durationMs,
    bool canUndo = false,
  }) =>
      CommandResult(
        success: true,
        data: data,
        durationMs: durationMs,
        canUndo: canUndo,
      );

  /// 失败结果
  factory CommandResult.failure(String errorMessage, {int? durationMs}) =>
      CommandResult(
        success: false,
        errorMessage: errorMessage,
        durationMs: durationMs,
      );

  @override
  String toString() {
    if (success) {
      return 'CommandResult.success(data: $data, canUndo: $canUndo)';
    }
    return 'CommandResult.failure($errorMessage)';
  }
}

/// 命令类型
enum CommandType {
  /// 添加交易
  addTransaction,

  /// 删除交易
  deleteTransaction,

  /// 修改交易
  modifyTransaction,

  /// 导航
  navigate,

  /// 查询
  query,

  /// 未知
  unknown,
}

/// 命令优先级
enum CommandPriority {
  /// 立即执行（导航类）
  immediate,

  /// 正常优先级（查询类）
  normal,

  /// 延迟执行（记账类）
  deferred,
}

/// 命令上下文
class CommandContext {
  /// 用户 ID
  final String? userId;

  /// 当前账本 ID
  final String? ledgerId;

  /// 页面上下文
  final String? pageContext;

  /// 对话历史
  final List<Map<String, String>>? conversationHistory;

  /// 原始输入
  final String? originalInput;

  /// 额外参数
  final Map<String, dynamic> extras;

  const CommandContext({
    this.userId,
    this.ledgerId,
    this.pageContext,
    this.conversationHistory,
    this.originalInput,
    this.extras = const {},
  });

  /// 复制并修改
  CommandContext copyWith({
    String? userId,
    String? ledgerId,
    String? pageContext,
    List<Map<String, String>>? conversationHistory,
    String? originalInput,
    Map<String, dynamic>? extras,
  }) {
    return CommandContext(
      userId: userId ?? this.userId,
      ledgerId: ledgerId ?? this.ledgerId,
      pageContext: pageContext ?? this.pageContext,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      originalInput: originalInput ?? this.originalInput,
      extras: extras ?? this.extras,
    );
  }
}

/// Intent Command 基类
///
/// 职责：
/// - 定义命令执行接口
/// - 支持撤销操作
/// - 提供命令元数据
abstract class IntentCommand {
  /// 命令 ID
  final String id;

  /// 命令类型
  final CommandType type;

  /// 命令优先级
  final CommandPriority priority;

  /// 命令参数
  final Map<String, dynamic> params;

  /// 创建时间
  final DateTime createdAt;

  /// 命令上下文
  final CommandContext context;

  IntentCommand({
    required this.id,
    required this.type,
    this.priority = CommandPriority.normal,
    this.params = const {},
    CommandContext? context,
  })  : createdAt = DateTime.now(),
        context = context ?? const CommandContext();

  /// 是否支持撤销
  bool get canUndo => false;

  /// 执行命令
  Future<CommandResult> execute();

  /// 撤销命令（如果支持）
  Future<CommandResult> undo() async {
    return CommandResult.failure('此命令不支持撤销');
  }

  /// 验证命令参数
  bool validate() => true;

  /// 获取命令描述
  String get description;

  @override
  String toString() => 'IntentCommand($type, id: $id)';
}

/// 可撤销命令接口
abstract class UndoableCommand extends IntentCommand {
  /// 撤销所需的状态
  Map<String, dynamic>? _undoState;

  UndoableCommand({
    required super.id,
    required super.type,
    super.priority,
    super.params,
    super.context,
  });

  @override
  bool get canUndo => _undoState != null;

  /// 保存撤销状态
  void saveUndoState(Map<String, dynamic> state) {
    _undoState = Map.from(state);
  }

  /// 获取撤销状态
  Map<String, dynamic>? get undoState => _undoState;
}

/// 命令执行器接口
abstract class ICommandExecutor {
  /// 执行命令
  Future<CommandResult> execute(IntentCommand command);

  /// 撤销最后一个命令
  Future<CommandResult> undoLast();

  /// 获取命令历史
  List<IntentCommand> get history;

  /// 清除历史
  void clearHistory();
}

/// 命令历史管理器
class CommandHistoryManager {
  final List<IntentCommand> _history = [];
  final int _maxHistorySize;

  CommandHistoryManager({int maxHistorySize = 50})
      : _maxHistorySize = maxHistorySize;

  /// 添加到历史
  void add(IntentCommand command) {
    _history.add(command);
    _trimHistory();
  }

  /// 获取历史
  List<IntentCommand> get history => List.unmodifiable(_history);

  /// 获取最后一个可撤销的命令
  IntentCommand? get lastUndoable {
    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i].canUndo) {
        return _history[i];
      }
    }
    return null;
  }

  /// 移除命令
  void remove(IntentCommand command) {
    _history.remove(command);
  }

  /// 清除历史
  void clear() {
    _history.clear();
  }

  /// 裁剪历史
  void _trimHistory() {
    while (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }
}
