import 'package:flutter/foundation.dart';

/// 语音操作接口
///
/// 定义所有可撤销语音操作的通用接口
abstract class VoiceOperation {
  /// 操作时间戳
  DateTime get timestamp;

  /// 是否可以撤销
  bool get canUndo;

  /// 撤销操作
  ///
  /// 返回撤销是否成功
  Future<bool> undo();

  /// 获取操作描述
  String get description;
}

/// 语音操作服务基类
///
/// 封装语音操作服务的通用逻辑，包括：
/// - 会话管理
/// - 操作历史管理
/// - 撤销功能
///
/// 子类需要实现具体的命令处理逻辑
abstract class BaseVoiceOperationService<T extends VoiceOperation>
    extends ChangeNotifier {
  /// 最大历史记录数
  static const int maxHistorySize = 10;

  /// 操作历史栈
  final List<T> _history = [];

  /// 当前会话上下文
  dynamic _sessionContext;

  /// 获取历史记录
  List<T> get history => List.unmodifiable(_history);

  /// 获取历史记录数量
  int get historyCount => _history.length;

  /// 是否有可撤销的操作
  bool get canUndo => _history.isNotEmpty && _history.last.canUndo;

  /// 获取最后一个操作
  T? get lastOperation => _history.isEmpty ? null : _history.last;

  /// 获取当前会话上下文
  dynamic get sessionContext => _sessionContext;

  /// 开始新会话
  ///
  /// [context] 会话上下文，存储会话相关状态
  void startSession(dynamic context) {
    _sessionContext = context;
    _history.clear();
    notifyListeners();
  }

  /// 结束当前会话
  void endSession() {
    _sessionContext = null;
    notifyListeners();
  }

  /// 是否有活跃会话
  bool get hasActiveSession => _sessionContext != null;

  /// 添加操作到历史栈
  ///
  /// 自动管理历史栈大小，超过 [maxHistorySize] 时移除最早的记录
  @protected
  void addToHistory(T operation) {
    _history.add(operation);

    // 限制历史记录大小
    while (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }

    notifyListeners();
  }

  /// 撤销最近的操作
  ///
  /// 如果历史栈为空或最后一个操作不可撤销，则安全返回 false
  Future<bool> undo() async {
    if (_history.isEmpty) {
      return false;
    }

    final lastOp = _history.last;
    if (!lastOp.canUndo) {
      return false;
    }

    final success = await lastOp.undo();
    if (success) {
      _history.removeLast();
      notifyListeners();
    }

    return success;
  }

  /// 清空历史记录
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  /// 处理语音命令（子类实现）
  ///
  /// [command] 用户的语音命令文本
  /// 返回处理结果
  Future<dynamic> processCommand(String command);

  /// 获取命令模式列表（子类实现）
  ///
  /// 返回用于匹配语音命令的正则表达式列表
  List<RegExp> get patterns;
}

/// 操作结果基类
abstract class OperationResult {
  /// 是否成功
  final bool success;

  /// 消息
  final String? message;

  const OperationResult({
    required this.success,
    this.message,
  });
}
