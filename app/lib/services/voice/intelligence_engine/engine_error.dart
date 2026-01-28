/// 智能引擎统一错误处理
///
/// 提供统一的错误分类、错误类和错误处理接口，
/// 解决错误处理分散、静默吞异常等问题
library;

import 'package:flutter/foundation.dart';
import 'models.dart';

/// 错误类别
///
/// 按错误发生的阶段和性质分类
enum EngineErrorCategory {
  /// 识别阶段错误（LLM调用、规则匹配等）
  recognition,

  /// 执行阶段错误（操作执行、数据库写入等）
  execution,

  /// 回调错误（结果回调、通知回调等）
  callback,

  /// 超时错误（LLM超时、锁等待超时等）
  timeout,

  /// 网络错误（连接失败、请求超时等）
  network,

  /// 状态错误（非法状态转换、资源已释放等）
  state,

  /// 配置错误（缺少必要配置、配置无效等）
  configuration,

  /// 未知错误
  unknown,
}

/// 错误严重程度
enum ErrorSeverity {
  /// 警告：不影响主流程，可以继续
  warning,

  /// 错误：当前操作失败，但系统可继续
  error,

  /// 严重：系统状态可能不一致，需要关注
  critical,
}

/// 引擎错误
///
/// 统一的错误表示，包含分类、严重程度、上下文等信息
class EngineError {
  /// 错误类别
  final EngineErrorCategory category;

  /// 严重程度
  final ErrorSeverity severity;

  /// 错误消息（内部日志用）
  final String message;

  /// 用户友好消息（可选，用于向用户展示）
  final String? userMessage;

  /// 原始异常
  final Object? originalError;

  /// 堆栈信息
  final StackTrace? stackTrace;

  /// 错误上下文（附加信息）
  final Map<String, dynamic>? context;

  /// 发生时间
  final DateTime timestamp;

  /// 组件名称（错误发生的组件）
  final String component;

  EngineError({
    required this.category,
    required this.severity,
    required this.message,
    required this.component,
    this.userMessage,
    this.originalError,
    this.stackTrace,
    this.context,
  }) : timestamp = DateTime.now();

  /// 创建识别错误
  factory EngineError.recognition({
    required String message,
    required String component,
    String? userMessage,
    Object? originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    return EngineError(
      category: EngineErrorCategory.recognition,
      severity: severity,
      message: message,
      component: component,
      userMessage: userMessage ?? '语音识别遇到问题，请重试',
      originalError: originalError,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// 创建执行错误
  factory EngineError.execution({
    required String message,
    required String component,
    OperationType? operationType,
    String? userMessage,
    Object? originalError,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    final ctx = <String, dynamic>{
      if (operationType != null) 'operationType': operationType.toString(),
      ...?context,
    };
    return EngineError(
      category: EngineErrorCategory.execution,
      severity: severity,
      message: message,
      component: component,
      userMessage: userMessage ?? '操作执行失败，请重试',
      originalError: originalError,
      stackTrace: stackTrace,
      context: ctx.isEmpty ? null : ctx,
    );
  }

  /// 创建回调错误
  factory EngineError.callback({
    required String message,
    required String component,
    String? callbackName,
    Object? originalError,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.warning,
  }) {
    return EngineError(
      category: EngineErrorCategory.callback,
      severity: severity,
      message: message,
      component: component,
      originalError: originalError,
      stackTrace: stackTrace,
      context: callbackName != null ? {'callbackName': callbackName} : null,
    );
  }

  /// 创建超时错误
  factory EngineError.timeout({
    required String message,
    required String component,
    required Duration timeout,
    String? operation,
    String? userMessage,
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    return EngineError(
      category: EngineErrorCategory.timeout,
      severity: severity,
      message: message,
      component: component,
      userMessage: userMessage ?? '操作超时，请重试',
      context: {
        'timeoutMs': timeout.inMilliseconds,
        if (operation != null) 'operation': operation,
      },
    );
  }

  /// 创建网络错误
  factory EngineError.network({
    required String message,
    required String component,
    String? userMessage,
    Object? originalError,
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
  }) {
    return EngineError(
      category: EngineErrorCategory.network,
      severity: severity,
      message: message,
      component: component,
      userMessage: userMessage ?? '网络连接失败，请检查网络后重试',
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  /// 创建状态错误
  factory EngineError.state({
    required String message,
    required String component,
    String? expectedState,
    String? actualState,
    ErrorSeverity severity = ErrorSeverity.warning,
  }) {
    return EngineError(
      category: EngineErrorCategory.state,
      severity: severity,
      message: message,
      component: component,
      context: {
        if (expectedState != null) 'expectedState': expectedState,
        if (actualState != null) 'actualState': actualState,
      },
    );
  }

  /// 是否应该重试
  bool get isRetryable {
    switch (category) {
      case EngineErrorCategory.network:
      case EngineErrorCategory.timeout:
        return true;
      case EngineErrorCategory.recognition:
      case EngineErrorCategory.execution:
      case EngineErrorCategory.callback:
      case EngineErrorCategory.state:
      case EngineErrorCategory.configuration:
      case EngineErrorCategory.unknown:
        return false;
    }
  }

  /// 格式化为日志字符串
  String toLogString() {
    final buffer = StringBuffer();
    buffer.write('[$component] ');
    buffer.write('[${category.name.toUpperCase()}] ');
    buffer.write('[${severity.name}] ');
    buffer.write(message);

    if (context != null && context!.isNotEmpty) {
      buffer.write(' | context: $context');
    }

    if (originalError != null) {
      buffer.write(' | error: $originalError');
    }

    return buffer.toString();
  }

  @override
  String toString() => toLogString();
}

/// 错误处理器接口
///
/// 定义统一的错误处理契约，便于：
/// - 统一错误日志格式
/// - 错误上报和监控
/// - 错误恢复策略
abstract class EngineErrorHandler {
  /// 处理错误
  ///
  /// 返回值表示错误是否已被处理（true=已处理，不需要进一步操作）
  bool handleError(EngineError error);

  /// 处理识别错误
  bool handleRecognitionError({
    required String message,
    required String component,
    String? input,
    Object? originalError,
    StackTrace? stackTrace,
  });

  /// 处理执行错误
  bool handleExecutionError({
    required String message,
    required String component,
    OperationType? operationType,
    Object? originalError,
    StackTrace? stackTrace,
  });

  /// 处理回调错误
  bool handleCallbackError({
    required String message,
    required String component,
    String? callbackName,
    Object? originalError,
    StackTrace? stackTrace,
  });

  /// 处理超时错误
  bool handleTimeoutError({
    required String message,
    required String component,
    required Duration timeout,
    String? operation,
  });

  /// 处理网络错误
  bool handleNetworkError({
    required String message,
    required String component,
    Object? originalError,
    StackTrace? stackTrace,
  });
}

/// 默认错误处理器
///
/// 提供基础的错误日志记录和可选的回调通知
class DefaultEngineErrorHandler implements EngineErrorHandler {
  /// 错误回调（可选）
  /// 用于外部监控、上报等
  final void Function(EngineError error)? onError;

  /// 是否在 debug 模式下打印堆栈
  final bool printStackTraceInDebug;

  /// 错误历史（用于调试和分析）
  final List<EngineError> _errorHistory = [];

  /// 错误历史最大容量
  static const int _maxHistorySize = 100;

  DefaultEngineErrorHandler({
    this.onError,
    this.printStackTraceInDebug = true,
  });

  /// 获取错误历史
  List<EngineError> get errorHistory => List.unmodifiable(_errorHistory);

  /// 获取指定类别的错误数量
  int getErrorCount(EngineErrorCategory category) {
    return _errorHistory.where((e) => e.category == category).length;
  }

  /// 清除错误历史
  void clearHistory() {
    _errorHistory.clear();
  }

  @override
  bool handleError(EngineError error) {
    // 记录到历史
    _addToHistory(error);

    // 打印日志
    _logError(error);

    // 触发回调
    _notifyCallback(error);

    return true;
  }

  @override
  bool handleRecognitionError({
    required String message,
    required String component,
    String? input,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    final error = EngineError.recognition(
      message: message,
      component: component,
      originalError: originalError,
      stackTrace: stackTrace,
      context: input != null ? {'inputLength': input.length} : null,
    );
    return handleError(error);
  }

  @override
  bool handleExecutionError({
    required String message,
    required String component,
    OperationType? operationType,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    final error = EngineError.execution(
      message: message,
      component: component,
      operationType: operationType,
      originalError: originalError,
      stackTrace: stackTrace,
    );
    return handleError(error);
  }

  @override
  bool handleCallbackError({
    required String message,
    required String component,
    String? callbackName,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    final error = EngineError.callback(
      message: message,
      component: component,
      callbackName: callbackName,
      originalError: originalError,
      stackTrace: stackTrace,
    );
    return handleError(error);
  }

  @override
  bool handleTimeoutError({
    required String message,
    required String component,
    required Duration timeout,
    String? operation,
  }) {
    final error = EngineError.timeout(
      message: message,
      component: component,
      timeout: timeout,
      operation: operation,
    );
    return handleError(error);
  }

  @override
  bool handleNetworkError({
    required String message,
    required String component,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    final error = EngineError.network(
      message: message,
      component: component,
      originalError: originalError,
      stackTrace: stackTrace,
    );
    return handleError(error);
  }

  void _addToHistory(EngineError error) {
    _errorHistory.add(error);
    // 限制历史大小
    while (_errorHistory.length > _maxHistorySize) {
      _errorHistory.removeAt(0);
    }
  }

  void _logError(EngineError error) {
    // 根据严重程度选择日志方法
    final logMessage = error.toLogString();

    switch (error.severity) {
      case ErrorSeverity.warning:
        debugPrint('[WARN] $logMessage');
        break;
      case ErrorSeverity.error:
        debugPrint('[ERROR] $logMessage');
        break;
      case ErrorSeverity.critical:
        debugPrint('[CRITICAL] $logMessage');
        break;
    }

    // 在 debug 模式下打印堆栈
    if (printStackTraceInDebug && error.stackTrace != null) {
      debugPrint('Stack trace:\n${error.stackTrace}');
    }
  }

  void _notifyCallback(EngineError error) {
    if (onError != null) {
      try {
        onError!(error);
      } catch (e) {
        // 防止回调本身抛出异常
        debugPrint('[DefaultEngineErrorHandler] 错误回调执行失败: $e');
      }
    }
  }
}

/// 静默错误处理器
///
/// 只记录日志，不做其他处理。用于测试或特殊场景
class SilentEngineErrorHandler implements EngineErrorHandler {
  @override
  bool handleError(EngineError error) {
    debugPrint('[Silent] ${error.toLogString()}');
    return true;
  }

  @override
  bool handleRecognitionError({
    required String message,
    required String component,
    String? input,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    debugPrint('[Silent] [$component] Recognition error: $message');
    return true;
  }

  @override
  bool handleExecutionError({
    required String message,
    required String component,
    OperationType? operationType,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    debugPrint('[Silent] [$component] Execution error: $message');
    return true;
  }

  @override
  bool handleCallbackError({
    required String message,
    required String component,
    String? callbackName,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    debugPrint('[Silent] [$component] Callback error: $message');
    return true;
  }

  @override
  bool handleTimeoutError({
    required String message,
    required String component,
    required Duration timeout,
    String? operation,
  }) {
    debugPrint('[Silent] [$component] Timeout error: $message');
    return true;
  }

  @override
  bool handleNetworkError({
    required String message,
    required String component,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    debugPrint('[Silent] [$component] Network error: $message');
    return true;
  }
}
