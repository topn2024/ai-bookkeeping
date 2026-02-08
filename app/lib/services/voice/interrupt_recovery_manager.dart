import 'dart:async';
import 'package:flutter/foundation.dart';

/// 中断类型
enum InterruptType {
  /// 对话放弃（用户沉默）
  dialogAbandonment,

  /// 应用切换到后台
  appBackgrounded,

  /// 意图变更
  intentChange,
}

/// 恢复动作类型
enum RecoveryActionType {
  /// 已保存上下文
  saved,

  /// 继续对话
  resume,

  /// 轻提示可恢复
  lightPrompt,

  /// 重置（超时）
  reset,

  /// 询问是否恢复
  askResume,
}

/// 恢复优先级
enum RecoveryPriority {
  /// 高优先级（需要立即处理）
  high,

  /// 中优先级（建议处理）
  medium,

  /// 低优先级（可选处理）
  low,
}

/// 恢复建议
class RecoverySuggestion {
  /// 优先级
  final RecoveryPriority priority;

  /// 建议消息
  final String message;

  /// 建议的恢复动作
  final RecoveryActionType action;

  /// 建议原因
  final String reason;

  const RecoverySuggestion({
    required this.priority,
    required this.message,
    required this.action,
    required this.reason,
  });
}

/// 恢复动作
class RecoveryAction {
  /// 动作类型
  final RecoveryActionType type;

  /// 提示文本
  final String? promptText;

  /// 上下文数据
  final ConversationContext? context;

  const RecoveryAction._({
    required this.type,
    this.promptText,
    this.context,
  });

  factory RecoveryAction.saved() => const RecoveryAction._(
        type: RecoveryActionType.saved,
      );

  factory RecoveryAction.resume({
    required String promptText,
    ConversationContext? context,
  }) =>
      RecoveryAction._(
        type: RecoveryActionType.resume,
        promptText: promptText,
        context: context,
      );

  factory RecoveryAction.lightPrompt({required String promptText}) =>
      RecoveryAction._(
        type: RecoveryActionType.lightPrompt,
        promptText: promptText,
      );

  factory RecoveryAction.reset() => const RecoveryAction._(
        type: RecoveryActionType.reset,
      );

  factory RecoveryAction.askResume({
    required String promptText,
    required ConversationContext context,
  }) =>
      RecoveryAction._(
        type: RecoveryActionType.askResume,
        promptText: promptText,
        context: context,
      );
}

/// 对话上下文
class ConversationContext {
  /// 上下文ID
  final String id;

  /// 描述（用于提示用户）
  final String description;

  /// 是否为未完成操作
  final bool isIncomplete;

  /// 是否为危险操作
  final bool isDestructiveOperation;

  /// 关联的意图
  final String? intent;

  /// 关联数据
  final Map<String, dynamic>? data;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  ConversationContext({
    required this.id,
    required this.description,
    this.isIncomplete = false,
    this.isDestructiveOperation = false,
    this.intent,
    this.data,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 复制并更新
  ConversationContext copyWith({
    String? description,
    bool? isIncomplete,
    Map<String, dynamic>? data,
  }) {
    return ConversationContext(
      id: id,
      description: description ?? this.description,
      isIncomplete: isIncomplete ?? this.isIncomplete,
      isDestructiveOperation: isDestructiveOperation,
      intent: intent,
      data: data ?? this.data,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// 中断恢复管理器
///
/// 基于设计文档18.12.5.3实现中断恢复机制
class InterruptRecoveryManager {
  /// 当前对话上下文
  ConversationContext? _currentContext;

  /// 保存的上下文（用于恢复）
  ConversationContext? _savedContext;

  /// 中断时间
  DateTime? _interruptTime;

  /// 暂存的上下文队列（意图变更时）
  final List<ConversationContext> _pendingContexts = [];

  /// 用户是否已响应的标志
  bool _hasUserResponded = false;

  /// 放弃检测计时器
  Timer? _abandonmentTimer;

  /// 沉默超时时间（秒）
  static const int _silenceTimeoutSeconds = 5;

  /// 短暂中断时间阈值（分钟）
  static const int _shortInterruptMinutes = 2;

  /// 中等中断时间阈值（分钟）
  static const int _mediumInterruptMinutes = 30;

  /// 对话内恢复时间阈值（分钟）
  static const int _dialogResumeMinutes = 10;

  // ==================== 公共API ====================

  /// 当前上下文
  ConversationContext? get currentContext => _currentContext;

  /// 是否有暂存的上下文
  bool get hasPendingContexts => _pendingContexts.isNotEmpty;

  /// 设置当前上下文
  void setCurrentContext(ConversationContext context) {
    _currentContext = context;
    _hasUserResponded = true;
    debugPrint('[InterruptRecovery] 设置当前上下文: ${context.description}');
  }

  /// 更新当前上下文
  void updateCurrentContext({
    String? description,
    bool? isIncomplete,
    Map<String, dynamic>? data,
  }) {
    if (_currentContext != null) {
      _currentContext = _currentContext!.copyWith(
        description: description,
        isIncomplete: isIncomplete,
        data: data,
      );
    }
  }

  /// 清除当前上下文
  void clearCurrentContext() {
    _currentContext = null;
    _hasUserResponded = false;
    _cancelAbandonmentTimer();
  }

  /// 标记用户已响应
  void markUserResponded() {
    _hasUserResponded = true;
    _cancelAbandonmentTimer();
  }

  // ==================== 场景1: 多轮对话中途放弃 ====================

  /// 开始监听对话放弃
  ///
  /// 当系统追问后调用，等待用户响应
  void startAbandonmentDetection({
    required void Function(String) onTimeout,
  }) {
    _hasUserResponded = false;
    _cancelAbandonmentTimer();

    _abandonmentTimer = Timer(
      Duration(seconds: _silenceTimeoutSeconds),
      () {
        if (!_hasUserResponded && _currentContext != null) {
          debugPrint('[InterruptRecovery] 检测到对话放弃');

          // 保存当前上下文
          _savedContext = _currentContext;
          _interruptTime = DateTime.now();

          // 回调通知
          onTimeout('没想好的话，等会儿再说也行～');
        }
      },
    );
  }

  /// 检查对话恢复
  ///
  /// 当用户重新激活语音时调用
  RecoveryAction? checkDialogResume() {
    if (_savedContext == null || _interruptTime == null) {
      return null;
    }

    final elapsed = DateTime.now().difference(_interruptTime!);

    if (elapsed.inMinutes < _dialogResumeMinutes) {
      // 间隔<10分钟: 接着刚才的
      final context = _savedContext!;
      _clearSavedContext();
      return RecoveryAction.resume(
        promptText: '接着刚才的，${context.description}',
        context: context,
      );
    } else {
      // 间隔>10分钟: 重新开始
      _clearSavedContext();
      return RecoveryAction.reset();
    }
  }

  // ==================== 场景2: 来电/通知打断（应用生命周期） ====================

  /// 处理应用切换到后台
  ///
  /// 返回是否有操作被取消
  bool handleAppBackgrounded() {
    debugPrint('[InterruptRecovery] 应用切换到后台');

    if (_currentContext == null) {
      return false;
    }

    _savedContext = _currentContext;
    _interruptTime = DateTime.now();

    // 如果正在进行危险操作，需要取消
    if (_currentContext!.isDestructiveOperation) {
      debugPrint('[InterruptRecovery] 取消危险操作');
      _currentContext = null;
      return true;
    }

    return false;
  }

  /// 处理应用恢复到前台
  RecoveryAction? handleAppResumed() {
    debugPrint('[InterruptRecovery] 应用恢复到前台');

    if (_savedContext == null || _interruptTime == null) {
      return null;
    }

    final elapsed = DateTime.now().difference(_interruptTime!);

    if (elapsed.inMinutes < _shortInterruptMinutes) {
      // 间隔<2分钟: 询问是否继续
      final context = _savedContext!;
      return RecoveryAction.askResume(
        promptText: '刚才被打断了，继续吗？',
        context: context,
      );
    } else if (elapsed.inMinutes < _mediumInterruptMinutes) {
      // 间隔<30分钟: 轻提示
      return RecoveryAction.lightPrompt(
        promptText: '可以继续刚才的操作',
      );
    } else {
      // 间隔>30分钟: 直接重置
      _clearSavedContext();
      return RecoveryAction.reset();
    }
  }

  /// 确认恢复
  void confirmResume() {
    if (_savedContext != null) {
      _currentContext = _savedContext;
      _clearSavedContext();
      debugPrint('[InterruptRecovery] 已恢复上下文');
    }
  }

  /// 拒绝恢复
  void declineResume() {
    _clearSavedContext();
    debugPrint('[InterruptRecovery] 用户拒绝恢复');
  }

  // ==================== 场景3: 用户突然改变意图 ====================

  /// 处理意图变更
  ///
  /// 当检测到新意图时调用，暂存当前未完成的操作
  void handleIntentChange(String newIntent) {
    if (_currentContext != null && _currentContext!.isIncomplete) {
      debugPrint('[InterruptRecovery] 暂存未完成操作: ${_currentContext!.description}');
      _pendingContexts.add(_currentContext!);
    }

    _currentContext = null;
  }

  /// 检查是否有暂存的上下文需要处理
  ///
  /// 当新意图处理完成后调用
  ConversationContext? getNextPendingContext() {
    if (_pendingContexts.isEmpty) {
      return null;
    }
    return _pendingContexts.first;
  }

  /// 生成恢复询问文本
  String? generatePendingContextPrompt() {
    final pending = getNextPendingContext();
    if (pending == null) {
      return null;
    }
    return '对了，刚才${pending.description}还要继续吗？';
  }

  /// 确认恢复暂存的上下文
  ConversationContext? confirmPendingContext() {
    if (_pendingContexts.isEmpty) {
      return null;
    }
    final context = _pendingContexts.removeAt(0);
    _currentContext = context;
    debugPrint('[InterruptRecovery] 恢复暂存上下文: ${context.description}');
    return context;
  }

  /// 放弃暂存的上下文
  void discardPendingContext() {
    if (_pendingContexts.isNotEmpty) {
      final discarded = _pendingContexts.removeAt(0);
      debugPrint('[InterruptRecovery] 放弃暂存上下文: ${discarded.description}');
    }
  }

  /// 清除所有暂存上下文
  void clearAllPendingContexts() {
    _pendingContexts.clear();
  }

  // ==================== 清理 ====================

  /// 重置所有状态
  void reset() {
    _currentContext = null;
    _savedContext = null;
    _interruptTime = null;
    _pendingContexts.clear();
    _hasUserResponded = false;
    _cancelAbandonmentTimer();
    debugPrint('[InterruptRecovery] 状态已重置');
  }

  /// 释放资源
  void dispose() {
    _cancelAbandonmentTimer();
  }

  // ==================== 持久化支持 ====================

  /// 导出上下文为可持久化的格式
  Map<String, dynamic>? exportContext() {
    if (_savedContext == null) return null;

    return {
      'id': _savedContext!.id,
      'description': _savedContext!.description,
      'isIncomplete': _savedContext!.isIncomplete,
      'isDestructiveOperation': _savedContext!.isDestructiveOperation,
      'intent': _savedContext!.intent,
      'data': _savedContext!.data,
      'createdAt': _savedContext!.createdAt.toIso8601String(),
      'updatedAt': _savedContext!.updatedAt.toIso8601String(),
      'interruptTime': _interruptTime?.toIso8601String(),
    };
  }

  /// 从持久化数据恢复上下文
  void importContext(Map<String, dynamic> data) {
    try {
      _savedContext = ConversationContext(
        id: data['id'] as String,
        description: data['description'] as String,
        isIncomplete: data['isIncomplete'] as bool? ?? false,
        isDestructiveOperation: data['isDestructiveOperation'] as bool? ?? false,
        intent: data['intent'] as String?,
        data: data['data'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(data['createdAt'] as String),
        updatedAt: DateTime.parse(data['updatedAt'] as String),
      );

      if (data['interruptTime'] != null) {
        _interruptTime = DateTime.parse(data['interruptTime'] as String);
      }

      debugPrint('[InterruptRecovery] 已恢复持久化上下文: ${_savedContext!.description}');
    } catch (e) {
      debugPrint('[InterruptRecovery] 恢复上下文失败: $e');
    }
  }

  // ==================== 智能恢复建议 ====================

  /// 获取智能恢复建议
  RecoverySuggestion? getSmartRecoverySuggestion() {
    if (_savedContext == null) return null;

    final elapsed = _interruptTime != null
        ? DateTime.now().difference(_interruptTime!)
        : Duration.zero;

    // 根据上下文类型和中断时长给出建议
    if (_savedContext!.isDestructiveOperation) {
      // 危险操作：建议重新确认
      return RecoverySuggestion(
        priority: RecoveryPriority.high,
        message: '刚才的操作需要重新确认',
        action: RecoveryActionType.askResume,
        reason: '安全起见，危险操作需要重新确认',
      );
    }

    if (_savedContext!.isIncomplete) {
      if (elapsed.inMinutes < 5) {
        // 未完成操作，短时间中断
        return RecoverySuggestion(
          priority: RecoveryPriority.medium,
          message: '继续${_savedContext!.description}？',
          action: RecoveryActionType.resume,
          reason: '中断时间较短，可以继续',
        );
      } else if (elapsed.inMinutes < 30) {
        // 未完成操作，中等时间中断
        return RecoverySuggestion(
          priority: RecoveryPriority.low,
          message: '有未完成的${_savedContext!.description}',
          action: RecoveryActionType.lightPrompt,
          reason: '中断时间适中，轻提示即可',
        );
      }
    }

    // 默认：超时或普通操作
    return null;
  }

  // ==================== 内部方法 ====================

  void _cancelAbandonmentTimer() {
    _abandonmentTimer?.cancel();
    _abandonmentTimer = null;
  }

  void _clearSavedContext() {
    _savedContext = null;
    _interruptTime = null;
  }
}
