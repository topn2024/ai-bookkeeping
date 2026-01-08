import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 错误严重程度
enum ErrorSeverity {
  /// 调试级别
  debug,

  /// 信息级别
  info,

  /// 警告级别
  warning,

  /// 错误级别
  error,

  /// 致命错误
  fatal,
}

/// 错误上下文
class ErrorContext {
  /// 用户ID
  final String? userId;

  /// 设备ID
  final String? deviceId;

  /// 应用版本
  final String? appVersion;

  /// 操作系统
  final String? os;

  /// 操作系统版本
  final String? osVersion;

  /// 设备型号
  final String? deviceModel;

  /// 当前页面
  final String? currentScreen;

  /// 追踪ID
  final String? traceId;

  /// 自定义标签
  final Map<String, String>? tags;

  /// 额外数据
  final Map<String, dynamic>? extras;

  const ErrorContext({
    this.userId,
    this.deviceId,
    this.appVersion,
    this.os,
    this.osVersion,
    this.deviceModel,
    this.currentScreen,
    this.traceId,
    this.tags,
    this.extras,
  });

  Map<String, dynamic> toJson() => {
    if (userId != null) 'userId': userId,
    if (deviceId != null) 'deviceId': deviceId,
    if (appVersion != null) 'appVersion': appVersion,
    if (os != null) 'os': os,
    if (osVersion != null) 'osVersion': osVersion,
    if (deviceModel != null) 'deviceModel': deviceModel,
    if (currentScreen != null) 'currentScreen': currentScreen,
    if (traceId != null) 'traceId': traceId,
    if (tags != null) 'tags': tags,
    if (extras != null) 'extras': extras,
  };

  ErrorContext copyWith({
    String? userId,
    String? deviceId,
    String? appVersion,
    String? os,
    String? osVersion,
    String? deviceModel,
    String? currentScreen,
    String? traceId,
    Map<String, String>? tags,
    Map<String, dynamic>? extras,
  }) {
    return ErrorContext(
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      appVersion: appVersion ?? this.appVersion,
      os: os ?? this.os,
      osVersion: osVersion ?? this.osVersion,
      deviceModel: deviceModel ?? this.deviceModel,
      currentScreen: currentScreen ?? this.currentScreen,
      traceId: traceId ?? this.traceId,
      tags: tags ?? this.tags,
      extras: extras ?? this.extras,
    );
  }
}

/// 错误事件
class ErrorEvent {
  /// 唯一ID
  final String id;

  /// 错误类型
  final String type;

  /// 错误消息
  final String message;

  /// 严重程度
  final ErrorSeverity severity;

  /// 堆栈跟踪
  final StackTrace? stackTrace;

  /// 原始错误
  final dynamic originalError;

  /// 上下文
  final ErrorContext context;

  /// 时间戳
  final DateTime timestamp;

  /// 是否已处理
  bool handled;

  /// 指纹（用于分组）
  final String? fingerprint;

  ErrorEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.severity,
    this.stackTrace,
    this.originalError,
    required this.context,
    DateTime? timestamp,
    this.handled = false,
    this.fingerprint,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'message': message,
    'severity': severity.name,
    'stackTrace': stackTrace?.toString(),
    'context': context.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'handled': handled,
    if (fingerprint != null) 'fingerprint': fingerprint,
  };
}

/// 告警规则
class AlertRule {
  /// 规则ID
  final String id;

  /// 规则名称
  final String name;

  /// 错误类型匹配
  final String? errorTypePattern;

  /// 严重程度阈值
  final ErrorSeverity minSeverity;

  /// 时间窗口
  final Duration timeWindow;

  /// 触发阈值（在时间窗口内的错误数）
  final int threshold;

  /// 是否启用
  bool enabled;

  /// 告警回调
  final void Function(AlertRule rule, List<ErrorEvent> events)? onAlert;

  AlertRule({
    required this.id,
    required this.name,
    this.errorTypePattern,
    this.minSeverity = ErrorSeverity.error,
    this.timeWindow = const Duration(minutes: 5),
    this.threshold = 5,
    this.enabled = true,
    this.onAlert,
  });
}

/// 错误追踪与告警服务
///
/// 核心功能：
/// 1. 错误捕获和上报
/// 2. 错误分组和去重
/// 3. 告警规则
/// 4. 错误统计
///
/// 对应设计文档：第29章 可观测性与监控
/// 对应实施方案：轨道L 可观测性模块
class ErrorTrackingService {
  static final ErrorTrackingService _instance = ErrorTrackingService._();
  factory ErrorTrackingService() => _instance;
  ErrorTrackingService._();

  ErrorTrackingConfig _config = const ErrorTrackingConfig();
  ErrorContext _globalContext = const ErrorContext();
  bool _initialized = false;

  final List<ErrorEvent> _recentErrors = [];
  final Map<String, int> _errorCounts = {};
  final Map<String, AlertRule> _alertRules = {};
  final Map<String, DateTime> _alertCooldowns = {};

  Future<void> Function(ErrorEvent event)? _onReport;
  void Function(ErrorEvent event)? _onError;

  int _eventIdCounter = 0;

  /// 初始化服务
  Future<void> initialize({
    ErrorTrackingConfig? config,
    Future<void> Function(ErrorEvent event)? onReport,
    void Function(ErrorEvent event)? onError,
  }) async {
    if (_initialized) return;

    if (config != null) {
      _config = config;
    }
    _onReport = onReport;
    _onError = onError;

    // 设置全局上下文
    _globalContext = ErrorContext(
      os: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
    );

    // 注册 Flutter 错误处理
    if (_config.catchFlutterErrors) {
      FlutterError.onError = (details) {
        captureException(
          details.exception,
          stackTrace: details.stack,
          severity: ErrorSeverity.error,
          extras: {'library': details.library},
        );
      };
    }

    // 注册未捕获异常处理
    if (_config.catchUncaughtErrors) {
      PlatformDispatcher.instance.onError = (error, stack) {
        captureException(
          error,
          stackTrace: stack,
          severity: ErrorSeverity.fatal,
        );
        return true;
      };
    }

    _initialized = true;
  }

  /// 设置全局上下文
  void setGlobalContext(ErrorContext context) {
    _globalContext = context;
  }

  /// 更新全局上下文
  void updateGlobalContext({
    String? userId,
    String? deviceId,
    String? appVersion,
    String? currentScreen,
  }) {
    _globalContext = _globalContext.copyWith(
      userId: userId,
      deviceId: deviceId,
      appVersion: appVersion,
      currentScreen: currentScreen,
    );
  }

  /// 捕获异常
  Future<String?> captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
    Map<String, String>? tags,
    Map<String, dynamic>? extras,
    String? fingerprint,
    bool handled = false,
  }) async {
    final event = ErrorEvent(
      id: _generateEventId(),
      type: exception.runtimeType.toString(),
      message: exception.toString(),
      severity: severity,
      stackTrace: stackTrace ?? StackTrace.current,
      originalError: exception,
      context: _globalContext.copyWith(
        tags: tags,
        extras: extras,
      ),
      handled: handled,
      fingerprint: fingerprint ?? _generateFingerprint(exception, stackTrace),
    );

    return await _processEvent(event);
  }

  /// 捕获消息
  Future<String?> captureMessage(
    String message, {
    ErrorSeverity severity = ErrorSeverity.info,
    Map<String, String>? tags,
    Map<String, dynamic>? extras,
  }) async {
    final event = ErrorEvent(
      id: _generateEventId(),
      type: 'Message',
      message: message,
      severity: severity,
      context: _globalContext.copyWith(
        tags: tags,
        extras: extras,
      ),
      handled: true,
    );

    return await _processEvent(event);
  }

  /// 添加面包屑（调试跟踪）
  void addBreadcrumb({
    required String category,
    required String message,
    Map<String, dynamic>? data,
  }) {
    // 存储面包屑用于后续错误上下文
    _breadcrumbs.add(_Breadcrumb(
      category: category,
      message: message,
      data: data,
      timestamp: DateTime.now(),
    ));

    // 保持面包屑数量限制
    while (_breadcrumbs.length > _config.maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }
  }

  final Queue<_Breadcrumb> _breadcrumbs = Queue();

  /// 添加告警规则
  void addAlertRule(AlertRule rule) {
    _alertRules[rule.id] = rule;
  }

  /// 移除告警规则
  void removeAlertRule(String ruleId) {
    _alertRules.remove(ruleId);
  }

  /// 获取错误统计
  Map<String, int> getErrorStats() {
    return Map.unmodifiable(_errorCounts);
  }

  /// 获取最近错误
  List<ErrorEvent> getRecentErrors({int limit = 10}) {
    return _recentErrors.take(limit).toList();
  }

  /// 清除错误历史
  void clearHistory() {
    _recentErrors.clear();
    _errorCounts.clear();
  }

  // ==================== 私有方法 ====================

  Future<String?> _processEvent(ErrorEvent event) async {
    // 采样检查
    if (!_shouldSample(event)) {
      return null;
    }

    // 速率限制检查
    if (!_checkRateLimit(event)) {
      return null;
    }

    // 存储到最近错误
    _recentErrors.insert(0, event);
    while (_recentErrors.length > _config.maxRecentErrors) {
      _recentErrors.removeLast();
    }

    // 更新统计
    final fingerprint = event.fingerprint ?? event.type;
    _errorCounts[fingerprint] = (_errorCounts[fingerprint] ?? 0) + 1;

    // 触发回调
    _onError?.call(event);

    // 检查告警规则
    _checkAlertRules(event);

    // 上报
    if (_config.enableReporting && event.severity.index >= _config.minReportSeverity.index) {
      try {
        await _onReport?.call(event);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to report error: $e');
        }
      }
    }

    return event.id;
  }

  bool _shouldSample(ErrorEvent event) {
    if (_config.sampleRate >= 1.0) return true;
    if (_config.sampleRate <= 0.0) return false;

    // 严重错误始终采样
    if (event.severity == ErrorSeverity.fatal) return true;

    // 随机采样
    return (event.id.hashCode % 100) < (_config.sampleRate * 100);
  }

  bool _checkRateLimit(ErrorEvent event) {
    final key = event.fingerprint ?? event.type;
    final count = _errorCounts[key] ?? 0;

    // 同一错误超过限制则不再处理
    return count < _config.maxEventsPerFingerprint;
  }

  void _checkAlertRules(ErrorEvent event) {
    for (final rule in _alertRules.values) {
      if (!rule.enabled) continue;

      // 检查严重程度
      if (event.severity.index < rule.minSeverity.index) continue;

      // 检查错误类型
      if (rule.errorTypePattern != null) {
        if (!RegExp(rule.errorTypePattern!).hasMatch(event.type)) continue;
      }

      // 检查冷却时间
      final lastAlert = _alertCooldowns[rule.id];
      if (lastAlert != null) {
        if (DateTime.now().difference(lastAlert) < _config.alertCooldown) {
          continue;
        }
      }

      // 统计时间窗口内的错误数
      final windowStart = DateTime.now().subtract(rule.timeWindow);
      final windowErrors = _recentErrors.where((e) =>
        e.timestamp.isAfter(windowStart) &&
        (rule.errorTypePattern == null || RegExp(rule.errorTypePattern!).hasMatch(e.type)) &&
        e.severity.index >= rule.minSeverity.index
      ).toList();

      // 触发告警
      if (windowErrors.length >= rule.threshold) {
        _alertCooldowns[rule.id] = DateTime.now();
        rule.onAlert?.call(rule, windowErrors);
      }
    }
  }

  String _generateEventId() {
    _eventIdCounter++;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$timestamp-$_eventIdCounter';
  }

  String _generateFingerprint(dynamic exception, StackTrace? stackTrace) {
    final buffer = StringBuffer();
    buffer.write(exception.runtimeType.toString());

    if (stackTrace != null) {
      // 取堆栈前3帧作为指纹
      final frames = stackTrace.toString().split('\n').take(3);
      for (final frame in frames) {
        buffer.write(frame.replaceAll(RegExp(r'#\d+'), ''));
      }
    }

    return buffer.toString().hashCode.toRadixString(16);
  }

  /// 关闭服务
  Future<void> close() async {
    _initialized = false;
    _recentErrors.clear();
    _breadcrumbs.clear();
  }
}

/// 面包屑
class _Breadcrumb {
  final String category;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  _Breadcrumb({
    required this.category,
    required this.message,
    this.data,
    required this.timestamp,
  });
}

/// 错误追踪配置
class ErrorTrackingConfig {
  /// 是否启用上报
  final bool enableReporting;

  /// 最小上报严重程度
  final ErrorSeverity minReportSeverity;

  /// 采样率 (0.0 - 1.0)
  final double sampleRate;

  /// 是否捕获 Flutter 错误
  final bool catchFlutterErrors;

  /// 是否捕获未捕获异常
  final bool catchUncaughtErrors;

  /// 最大面包屑数量
  final int maxBreadcrumbs;

  /// 最大最近错误数量
  final int maxRecentErrors;

  /// 同一指纹最大事件数
  final int maxEventsPerFingerprint;

  /// 告警冷却时间
  final Duration alertCooldown;

  const ErrorTrackingConfig({
    this.enableReporting = true,
    this.minReportSeverity = ErrorSeverity.warning,
    this.sampleRate = 1.0,
    this.catchFlutterErrors = true,
    this.catchUncaughtErrors = true,
    this.maxBreadcrumbs = 100,
    this.maxRecentErrors = 100,
    this.maxEventsPerFingerprint = 100,
    this.alertCooldown = const Duration(minutes: 10),
  });
}

/// 全局错误追踪实例
final errorTracker = ErrorTrackingService();
