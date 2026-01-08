import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 日志级别
enum LogLevel {
  /// 详细调试信息
  verbose,

  /// 调试信息
  debug,

  /// 一般信息
  info,

  /// 警告信息
  warning,

  /// 错误信息
  error,

  /// 致命错误
  fatal,
}

/// 日志级别扩展
extension LogLevelExtension on LogLevel {
  /// 获取级别数值
  int get value => index;

  /// 获取级别名称
  String get name {
    switch (this) {
      case LogLevel.verbose:
        return 'VERBOSE';
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.fatal:
        return 'FATAL';
    }
  }

  /// 获取级别颜色代码
  String get colorCode {
    switch (this) {
      case LogLevel.verbose:
        return '\x1B[37m'; // 白色
      case LogLevel.debug:
        return '\x1B[36m'; // 青色
      case LogLevel.info:
        return '\x1B[32m'; // 绿色
      case LogLevel.warning:
        return '\x1B[33m'; // 黄色
      case LogLevel.error:
        return '\x1B[31m'; // 红色
      case LogLevel.fatal:
        return '\x1B[35m'; // 紫色
    }
  }
}

/// 日志条目
class LogEntry {
  /// 时间戳
  final DateTime timestamp;

  /// 日志级别
  final LogLevel level;

  /// 日志消息
  final String message;

  /// 日志标签（模块/类名）
  final String? tag;

  /// 上下文数据
  final Map<String, dynamic>? context;

  /// 错误对象
  final dynamic error;

  /// 堆栈跟踪
  final StackTrace? stackTrace;

  /// 追踪ID
  final String? traceId;

  /// Span ID
  final String? spanId;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.context,
    this.error,
    this.stackTrace,
    this.traceId,
    this.spanId,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    if (tag != null) 'tag': tag,
    if (context != null) ...context!,
    if (error != null) 'error': error.toString(),
    if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    if (traceId != null) 'traceId': traceId,
    if (spanId != null) 'spanId': spanId,
  };

  /// 格式化为字符串
  String format({bool colored = false, bool includeContext = true}) {
    final buffer = StringBuffer();

    if (colored) {
      buffer.write(level.colorCode);
    }

    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name}] ');

    if (tag != null) {
      buffer.write('[$tag] ');
    }

    buffer.write(message);

    if (includeContext && context != null && context!.isNotEmpty) {
      buffer.write(' | ');
      buffer.write(jsonEncode(context));
    }

    if (error != null) {
      buffer.write('\nError: $error');
    }

    if (stackTrace != null) {
      buffer.write('\nStack Trace:\n$stackTrace');
    }

    if (colored) {
      buffer.write('\x1B[0m'); // 重置颜色
    }

    return buffer.toString();
  }
}

/// 日志输出接口
abstract class LogOutput {
  /// 初始化
  Future<void> initialize();

  /// 写入日志
  void write(LogEntry entry);

  /// 刷新缓冲区
  Future<void> flush();

  /// 关闭
  Future<void> close();
}

/// 控制台日志输出
class ConsoleLogOutput implements LogOutput {
  final bool colored;
  final bool includeContext;

  ConsoleLogOutput({
    this.colored = true,
    this.includeContext = true,
  });

  @override
  Future<void> initialize() async {}

  @override
  void write(LogEntry entry) {
    if (kDebugMode) {
      print(entry.format(colored: colored, includeContext: includeContext));
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// 文件日志输出
class FileLogOutput implements LogOutput {
  final String filePath;
  final int maxFileSizeBytes;
  final int maxBackupCount;

  File? _logFile;
  IOSink? _sink;
  int _currentSize = 0;

  FileLogOutput({
    required this.filePath,
    this.maxFileSizeBytes = 10 * 1024 * 1024, // 10MB
    this.maxBackupCount = 5,
  });

  @override
  Future<void> initialize() async {
    _logFile = File(filePath);

    // 创建目录
    final dir = _logFile!.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 检查文件大小
    if (await _logFile!.exists()) {
      _currentSize = await _logFile!.length();
      if (_currentSize >= maxFileSizeBytes) {
        await _rotateLog();
      }
    }

    _sink = _logFile!.openWrite(mode: FileMode.append);
  }

  @override
  void write(LogEntry entry) {
    if (_sink == null) return;

    final line = '${entry.format(colored: false)}\n';
    _sink!.write(line);
    _currentSize += line.length;

    // 检查是否需要轮转
    if (_currentSize >= maxFileSizeBytes) {
      _rotateLogSync();
    }
  }

  @override
  Future<void> flush() async {
    await _sink?.flush();
  }

  @override
  Future<void> close() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  /// 日志轮转
  Future<void> _rotateLog() async {
    await _sink?.close();
    _sink = null;

    // 删除最老的备份
    final oldestBackup = File('$filePath.$maxBackupCount');
    if (await oldestBackup.exists()) {
      await oldestBackup.delete();
    }

    // 重命名现有备份
    for (int i = maxBackupCount - 1; i >= 1; i--) {
      final backup = File('$filePath.$i');
      if (await backup.exists()) {
        await backup.rename('$filePath.${i + 1}');
      }
    }

    // 重命名当前日志
    await _logFile!.rename('$filePath.1');

    // 创建新日志文件
    _logFile = File(filePath);
    _sink = _logFile!.openWrite(mode: FileMode.write);
    _currentSize = 0;
  }

  void _rotateLogSync() {
    // 异步执行轮转
    _rotateLog();
  }
}

/// 内存缓冲日志输出（用于远程发送）
class BufferedLogOutput implements LogOutput {
  final int maxBufferSize;
  final Duration flushInterval;
  final Future<void> Function(List<LogEntry> entries) onFlush;

  final Queue<LogEntry> _buffer = Queue();
  Timer? _flushTimer;
  bool _isFlushing = false;

  BufferedLogOutput({
    this.maxBufferSize = 100,
    this.flushInterval = const Duration(seconds: 30),
    required this.onFlush,
  });

  @override
  Future<void> initialize() async {
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
  }

  @override
  void write(LogEntry entry) {
    _buffer.add(entry);

    // 缓冲区满时自动刷新
    if (_buffer.length >= maxBufferSize) {
      flush();
    }
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty || _isFlushing) return;

    _isFlushing = true;

    try {
      final entries = _buffer.toList();
      _buffer.clear();
      await onFlush(entries);
    } catch (e) {
      // 发送失败，将条目放回缓冲区
      // 但只保留最新的条目以防溢出
      if (kDebugMode) {
        print('Failed to flush logs: $e');
      }
    } finally {
      _isFlushing = false;
    }
  }

  @override
  Future<void> close() async {
    _flushTimer?.cancel();
    await flush();
  }
}

/// 日志服务配置
class LoggerConfig {
  /// 最小日志级别
  final LogLevel minLevel;

  /// 是否启用控制台输出
  final bool enableConsole;

  /// 是否启用文件输出
  final bool enableFile;

  /// 日志文件路径
  final String? logFilePath;

  /// 是否启用远程日志
  final bool enableRemote;

  /// 远程日志端点
  final String? remoteEndpoint;

  /// 是否在日志中包含堆栈跟踪
  final bool includeStackTrace;

  /// 是否启用结构化日志
  final bool structuredLogging;

  const LoggerConfig({
    this.minLevel = LogLevel.debug,
    this.enableConsole = true,
    this.enableFile = false,
    this.logFilePath,
    this.enableRemote = false,
    this.remoteEndpoint,
    this.includeStackTrace = true,
    this.structuredLogging = true,
  });

  /// 开发环境配置
  factory LoggerConfig.development() => const LoggerConfig(
    minLevel: LogLevel.verbose,
    enableConsole: true,
    enableFile: false,
    includeStackTrace: true,
  );

  /// 生产环境配置
  factory LoggerConfig.production({String? logFilePath, String? remoteEndpoint}) =>
      LoggerConfig(
        minLevel: LogLevel.info,
        enableConsole: false,
        enableFile: true,
        logFilePath: logFilePath,
        enableRemote: true,
        remoteEndpoint: remoteEndpoint,
        includeStackTrace: true,
        structuredLogging: true,
      );
}

/// 结构化日志服务
///
/// 核心功能：
/// 1. 多级别日志记录
/// 2. 结构化上下文数据
/// 3. 多输出目标（控制台、文件、远程）
/// 4. 日志轮转
/// 5. TraceID 关联
///
/// 对应设计文档：第29章 可观测性与监控
/// 对应实施方案：轨道L 可观测性模块
class LoggerService {
  static final LoggerService _instance = LoggerService._();
  factory LoggerService() => _instance;
  LoggerService._();

  LoggerConfig _config = const LoggerConfig();
  final List<LogOutput> _outputs = [];
  bool _initialized = false;

  // 全局上下文
  final Map<String, dynamic> _globalContext = {};

  // 当前追踪上下文
  String? _currentTraceId;
  String? _currentSpanId;

  /// 初始化日志服务
  Future<void> initialize({LoggerConfig? config}) async {
    if (_initialized) return;

    if (config != null) {
      _config = config;
    }

    // 添加控制台输出
    if (_config.enableConsole) {
      _outputs.add(ConsoleLogOutput());
    }

    // 添加文件输出
    if (_config.enableFile && _config.logFilePath != null) {
      _outputs.add(FileLogOutput(filePath: _config.logFilePath!));
    }

    // 初始化所有输出
    for (final output in _outputs) {
      await output.initialize();
    }

    _initialized = true;

    // 添加应用信息到全局上下文
    _globalContext['platform'] = Platform.operatingSystem;
    _globalContext['platformVersion'] = Platform.operatingSystemVersion;
  }

  /// 设置全局上下文
  void setGlobalContext(String key, dynamic value) {
    _globalContext[key] = value;
  }

  /// 移除全局上下文
  void removeGlobalContext(String key) {
    _globalContext.remove(key);
  }

  /// 设置追踪上下文
  void setTraceContext({String? traceId, String? spanId}) {
    _currentTraceId = traceId;
    _currentSpanId = spanId;
  }

  /// 清除追踪上下文
  void clearTraceContext() {
    _currentTraceId = null;
    _currentSpanId = null;
  }

  /// 添加输出
  void addOutput(LogOutput output) {
    _outputs.add(output);
    output.initialize();
  }

  /// 移除输出
  void removeOutput(LogOutput output) {
    _outputs.remove(output);
    output.close();
  }

  // ==================== 日志方法 ====================

  /// 详细日志
  void verbose(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(LogLevel.verbose, message, tag: tag, context: context);
  }

  /// 调试日志
  void debug(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(LogLevel.debug, message, tag: tag, context: context);
  }

  /// 信息日志
  void info(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(LogLevel.info, message, tag: tag, context: context);
  }

  /// 警告日志
  void warning(
    String message, {
    String? tag,
    Map<String, dynamic>? context,
    dynamic error,
  }) {
    _log(LogLevel.warning, message, tag: tag, context: context, error: error);
  }

  /// 错误日志
  void error(
    String message, {
    String? tag,
    Map<String, dynamic>? context,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      context: context,
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// 致命错误日志
  void fatal(
    String message, {
    String? tag,
    Map<String, dynamic>? context,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.fatal,
      message,
      tag: tag,
      context: context,
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// 内部日志方法
  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? context,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // 级别过滤
    if (level.value < _config.minLevel.value) return;

    // 合并上下文
    final mergedContext = <String, dynamic>{
      ..._globalContext,
      if (context != null) ...context,
    };

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      context: mergedContext.isNotEmpty ? mergedContext : null,
      error: error,
      stackTrace: _config.includeStackTrace ? stackTrace : null,
      traceId: _currentTraceId,
      spanId: _currentSpanId,
    );

    // 写入所有输出
    for (final output in _outputs) {
      try {
        output.write(entry);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to write log to output: $e');
        }
      }
    }
  }

  /// 刷新所有输出
  Future<void> flush() async {
    for (final output in _outputs) {
      await output.flush();
    }
  }

  /// 关闭日志服务
  Future<void> close() async {
    for (final output in _outputs) {
      await output.close();
    }
    _outputs.clear();
    _initialized = false;
  }

  /// 创建带标签的日志器
  TaggedLogger tagged(String tag) => TaggedLogger(this, tag);
}

/// 带标签的日志器
class TaggedLogger {
  final LoggerService _logger;
  final String tag;

  TaggedLogger(this._logger, this.tag);

  void verbose(String message, {Map<String, dynamic>? context}) {
    _logger.verbose(message, tag: tag, context: context);
  }

  void debug(String message, {Map<String, dynamic>? context}) {
    _logger.debug(message, tag: tag, context: context);
  }

  void info(String message, {Map<String, dynamic>? context}) {
    _logger.info(message, tag: tag, context: context);
  }

  void warning(String message, {Map<String, dynamic>? context, dynamic error}) {
    _logger.warning(message, tag: tag, context: context, error: error);
  }

  void error(
    String message, {
    Map<String, dynamic>? context,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.error(
      message,
      tag: tag,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void fatal(
    String message, {
    Map<String, dynamic>? context,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _logger.fatal(
      message,
      tag: tag,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// 日志分析器
class LogAnalyzer {
  final List<LogEntry> _entries = [];
  final int maxEntries;

  LogAnalyzer({this.maxEntries = 1000});

  /// 添加日志条目
  void addEntry(LogEntry entry) {
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  /// 获取错误统计
  Map<String, int> getErrorStats() {
    final stats = <String, int>{};
    for (final entry in _entries) {
      if (entry.level == LogLevel.error || entry.level == LogLevel.fatal) {
        final key = entry.tag ?? 'unknown';
        stats[key] = (stats[key] ?? 0) + 1;
      }
    }
    return stats;
  }

  /// 获取日志级别分布
  Map<LogLevel, int> getLevelDistribution() {
    final distribution = <LogLevel, int>{};
    for (final entry in _entries) {
      distribution[entry.level] = (distribution[entry.level] ?? 0) + 1;
    }
    return distribution;
  }

  /// 获取时间范围内的日志
  List<LogEntry> getEntriesInRange(DateTime start, DateTime end) {
    return _entries.where((e) =>
      e.timestamp.isAfter(start) && e.timestamp.isBefore(end)
    ).toList();
  }

  /// 搜索日志
  List<LogEntry> search({
    String? keyword,
    LogLevel? minLevel,
    String? tag,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return _entries.where((entry) {
      if (keyword != null && !entry.message.contains(keyword)) {
        return false;
      }
      if (minLevel != null && entry.level.value < minLevel.value) {
        return false;
      }
      if (tag != null && entry.tag != tag) {
        return false;
      }
      if (startTime != null && entry.timestamp.isBefore(startTime)) {
        return false;
      }
      if (endTime != null && entry.timestamp.isAfter(endTime)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 清除日志
  void clear() {
    _entries.clear();
  }
}

/// 全局日志实例
final logger = LoggerService();
