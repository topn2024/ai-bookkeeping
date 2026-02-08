import 'package:flutter/foundation.dart';
import 'multi_intent_models.dart';
import '../voice_service_coordinator.dart' show VoiceIntentType;

/// 语音会话状态
enum VoiceSessionState {
  /// 空闲状态
  idle,

  /// 正在监听用户语音
  listening,

  /// 正在处理语音命令
  processing,

  /// 等待用户确认
  confirming,

  /// 正在播放响应
  responding,

  /// 发生错误
  error,
}

/// 语音会话上下文
class VoiceSessionContext {
  final VoiceIntentType intentType;
  final DateTime startTime;
  final Map<String, dynamic> data;

  VoiceSessionContext({
    required this.intentType,
    DateTime? startTime,
    Map<String, dynamic>? data,
  })  : startTime = startTime ?? DateTime.now(),
        data = data ?? {};

  /// 会话持续时间
  Duration get duration => DateTime.now().difference(startTime);

  /// 是否超时（默认 5 分钟）
  bool get isTimedOut => duration > const Duration(minutes: 5);

  /// 复制并更新数据
  VoiceSessionContext copyWith({
    VoiceIntentType? intentType,
    Map<String, dynamic>? data,
  }) {
    return VoiceSessionContext(
      intentType: intentType ?? this.intentType,
      startTime: startTime,
      data: data ?? Map.from(this.data),
    );
  }
}

/// 语音命令记录
class VoiceCommand {
  final String input;
  final String? response;
  final VoiceIntentType? intentType;
  final DateTime timestamp;
  final bool success;
  final String? errorMessage;

  VoiceCommand({
    required this.input,
    this.response,
    this.intentType,
    DateTime? timestamp,
    this.success = true,
    this.errorMessage,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 语音会话结果
class VoiceSessionResult {
  final bool success;
  final String? message;
  final dynamic data;
  final String? errorCode;

  VoiceSessionResult({
    required this.success,
    this.message,
    this.data,
    this.errorCode,
  });

  factory VoiceSessionResult.success([String? message, dynamic data]) {
    return VoiceSessionResult(
      success: true,
      message: message,
      data: data,
    );
  }

  factory VoiceSessionResult.error(String message, {String? errorCode}) {
    return VoiceSessionResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// 语音会话管理器
///
/// 负责管理语音会话的状态和生命周期：
/// - 会话状态管理
/// - 会话上下文维护
/// - 命令历史记录
/// - 多意图处理状态
///
/// 从 VoiceServiceCoordinator 中提取的专注于会话管理的组件
class VoiceSessionManager extends ChangeNotifier {
  /// 当前会话状态
  VoiceSessionState _sessionState = VoiceSessionState.idle;

  /// 当前会话上下文
  VoiceSessionContext? _currentSession;

  /// 语音命令历史
  final List<VoiceCommand> _commandHistory = [];

  /// 最后一次响应
  String? _lastResponse;

  /// 待处理的多意图结果
  MultiIntentResult? _pendingMultiIntent;

  /// 多意图处理配置
  MultiIntentConfig _multiIntentConfig = MultiIntentConfig.defaultConfig;

  /// 最大历史记录数
  static const int maxHistorySize = 50;

  /// 当前会话状态
  VoiceSessionState get sessionState => _sessionState;

  /// 当前会话类型
  VoiceIntentType? get currentIntentType => _currentSession?.intentType;

  /// 是否有活跃会话
  bool get hasActiveSession => _sessionState != VoiceSessionState.idle;

  /// 命令历史
  List<VoiceCommand> get commandHistory => List.unmodifiable(_commandHistory);

  /// 最后一次响应
  String? get lastResponse => _lastResponse;

  /// 待处理的多意图结果
  MultiIntentResult? get pendingMultiIntent => _pendingMultiIntent;

  /// 是否有待处理的多意图
  bool get hasPendingMultiIntent =>
      _pendingMultiIntent != null && !_pendingMultiIntent!.isEmpty;

  /// 多意图处理配置
  MultiIntentConfig get multiIntentConfig => _multiIntentConfig;

  /// 设置多意图处理配置
  set multiIntentConfig(MultiIntentConfig config) {
    _multiIntentConfig = config;
    notifyListeners();
  }

  /// 开始新会话
  void startSession(VoiceIntentType intentType, {Map<String, dynamic>? data}) {
    _currentSession = VoiceSessionContext(
      intentType: intentType,
      data: data,
    );
    _sessionState = VoiceSessionState.listening;
    notifyListeners();
  }

  /// 更新会话状态
  void updateState(VoiceSessionState newState) {
    if (_sessionState != newState) {
      _sessionState = newState;
      notifyListeners();
    }
  }

  /// 更新会话数据
  void updateSessionData(Map<String, dynamic> data) {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        data: {..._currentSession!.data, ...data},
      );
      notifyListeners();
    }
  }

  /// 结束当前会话
  void endSession() {
    _currentSession = null;
    _sessionState = VoiceSessionState.idle;
    notifyListeners();
  }

  /// 记录命令
  void recordCommand(VoiceCommand command) {
    _commandHistory.add(command);
    _lastResponse = command.response;

    // 限制历史记录大小
    while (_commandHistory.length > maxHistorySize) {
      _commandHistory.removeAt(0);
    }

    notifyListeners();
  }

  /// 设置待处理的多意图
  void setPendingMultiIntent(MultiIntentResult? result) {
    _pendingMultiIntent = result;
    notifyListeners();
  }

  /// 清除待处理的多意图
  void clearPendingMultiIntent() {
    _pendingMultiIntent = null;
    notifyListeners();
  }

  /// 清除所有历史记录
  void clearHistory() {
    _commandHistory.clear();
    _lastResponse = null;
    notifyListeners();
  }

  /// 获取最近的命令
  List<VoiceCommand> getRecentCommands(int count) {
    final start = _commandHistory.length - count;
    if (start < 0) {
      return List.from(_commandHistory);
    }
    return _commandHistory.sublist(start);
  }

  /// 检查会话是否超时
  bool checkSessionTimeout() {
    if (_currentSession != null && _currentSession!.isTimedOut) {
      endSession();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _commandHistory.clear();
    super.dispose();
  }
}
