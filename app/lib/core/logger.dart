// Application logging service with file persistence and auto-cleanup.
//
// Features:
// - Multiple log levels (debug, info, warning, error)
// - File persistence with daily rotation
// - Automatic cleanup of old log files
// - Size limits per log file
// - Debug/Release mode handling
// - Remote error reporting support

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Log storage configuration
class LogConfig {
  /// Maximum size per log file in bytes (default: 5MB)
  final int maxFileSize;

  /// Maximum number of days to keep logs (default: 7 days)
  final int retentionDays;

  /// Maximum total size of all logs in bytes (default: 50MB)
  final int maxTotalSize;

  /// Whether to persist logs to file
  final bool persistToFile;

  /// Minimum level to persist to file
  final LogLevel fileLogLevel;

  const LogConfig({
    this.maxFileSize = 5 * 1024 * 1024, // 5MB
    this.retentionDays = 7,
    this.maxTotalSize = 50 * 1024 * 1024, // 50MB
    this.persistToFile = true,
    this.fileLogLevel = LogLevel.info,
  });
}

/// Singleton logger service with file persistence
class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  /// Logger configuration
  LogConfig _config = const LogConfig();

  /// Minimum log level to output
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Enable/disable logging
  bool _enabled = true;

  /// Log directory path
  String? _logDir;

  /// Current log file
  File? _currentLogFile;

  /// Current log file size
  int _currentFileSize = 0;

  /// Today's date string for file naming
  String? _currentDateStr;

  /// Write buffer for batching writes
  final List<String> _writeBuffer = [];

  /// Buffer flush timer
  Timer? _flushTimer;

  /// Periodic cleanup timer
  Timer? _cleanupTimer;

  /// Last cleanup timestamp
  DateTime? _lastCleanupTime;

  /// Initialization flag
  bool _initialized = false;

  /// Remote error reporter callback
  void Function(String message, Object? error, StackTrace? stackTrace)?
      _remoteReporter;

  /// Initialize the logger with file storage
  Future<void> init({LogConfig? config}) async {
    if (_initialized) return;

    if (config != null) _config = config;

    if (_config.persistToFile) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        _logDir = path.join(appDir.path, 'logs');

        // Create logs directory
        final dir = Directory(_logDir!);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        // Initialize current log file
        await _initLogFile();

        // Run cleanup on startup
        await cleanupOldLogs();
        _lastCleanupTime = DateTime.now();

        // Start periodic cleanup timer (every 6 hours)
        _startPeriodicCleanup();

        _initialized = true;
        info('Logger initialized with periodic cleanup', tag: 'Logger');
      } catch (e) {
        debugPrint('Failed to initialize logger file storage: $e');
      }
    }

    _initialized = true;
  }

  /// Start periodic cleanup timer
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    // Run cleanup every 6 hours
    _cleanupTimer = Timer.periodic(const Duration(hours: 6), (_) async {
      await _performScheduledCleanup();
    });
  }

  /// Perform scheduled cleanup if needed
  Future<void> _performScheduledCleanup() async {
    // Also check if cleanup is needed based on size
    final currentSize = await getLogSize();
    final needsCleanup = currentSize > _config.maxTotalSize * 0.8; // 80% threshold

    if (needsCleanup) {
      debug('Scheduled cleanup triggered (size: ${(currentSize / 1024 / 1024).toStringAsFixed(2)}MB)', tag: 'Logger');
      await cleanupOldLogs();
      _lastCleanupTime = DateTime.now();
    }
  }

  /// Trigger cleanup when app resumes from background
  Future<void> onAppResumed() async {
    if (!_config.persistToFile || _logDir == null) return;

    // Only cleanup if last cleanup was more than 1 hour ago
    final now = DateTime.now();
    if (_lastCleanupTime != null &&
        now.difference(_lastCleanupTime!).inHours < 1) {
      return;
    }

    await cleanupOldLogs();
    _lastCleanupTime = now;
  }

  /// Configure logger settings
  void configure({
    LogLevel? minLevel,
    bool? enabled,
    LogConfig? config,
    void Function(String message, Object? error, StackTrace? stackTrace)?
        remoteReporter,
  }) {
    if (minLevel != null) _minLevel = minLevel;
    if (enabled != null) _enabled = enabled;
    if (config != null) _config = config;
    if (remoteReporter != null) _remoteReporter = remoteReporter;
  }

  /// Get a named logger instance
  static NamedLogger getLogger(String name) => NamedLogger(name);

  /// Log a debug message
  void debug(String message, {String? tag, Object? error, StackTrace? stack}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stack: stack);
  }

  /// Log an info message
  void info(String message, {String? tag, Object? error, StackTrace? stack}) {
    _log(LogLevel.info, message, tag: tag, error: error, stack: stack);
  }

  /// Log a warning message
  void warning(String message,
      {String? tag, Object? error, StackTrace? stack}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stack: stack);
  }

  /// Log an error message
  void error(String message, {String? tag, Object? error, StackTrace? stack}) {
    _log(LogLevel.error, message, tag: tag, error: error, stack: stack);

    // Report errors to remote service in release mode
    if (!kDebugMode && _remoteReporter != null) {
      _remoteReporter!(message, error, stack);
    }
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stack,
  }) {
    if (!_enabled || level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(7);
    final tagStr = tag != null ? '[$tag] ' : '';
    final formattedMessage = '$timestamp | $levelStr | $tagStr$message';

    // Build full log entry for file
    final buffer = StringBuffer(formattedMessage);
    if (error != null) {
      buffer.writeln();
      buffer.write('  Error: $error');
    }
    if (stack != null) {
      buffer.writeln();
      buffer.write('  Stack: $stack');
    }
    final fullLogEntry = buffer.toString();

    // Console output
    if (kDebugMode) {
      developer.log(
        formattedMessage,
        name: tag ?? 'App',
        level: _levelToInt(level),
        error: error,
        stackTrace: stack,
      );
    } else if (level == LogLevel.error) {
      debugPrint(formattedMessage);
      if (error != null) debugPrint('Error: $error');
      if (stack != null) debugPrint('Stack: $stack');
    }

    // File persistence
    if (_config.persistToFile && level.index >= _config.fileLogLevel.index) {
      _writeToFile(fullLogEntry);
    }
  }

  /// Write log entry to file with buffering
  void _writeToFile(String entry) {
    _writeBuffer.add(entry);

    // Cancel existing timer
    _flushTimer?.cancel();

    // Flush immediately if buffer is large
    if (_writeBuffer.length >= 10) {
      _flushBuffer();
    } else {
      // Schedule flush after delay
      _flushTimer = Timer(const Duration(seconds: 1), _flushBuffer);
    }
  }

  /// Flush write buffer to file
  Future<void> _flushBuffer() async {
    if (_writeBuffer.isEmpty || _logDir == null) return;

    final entries = List<String>.from(_writeBuffer);
    _writeBuffer.clear();

    try {
      // Check if we need a new file (date change or size limit)
      await _checkLogRotation();

      if (_currentLogFile == null) return;

      // Write buffered entries
      final content = '${entries.join('\n')}\n';
      await _currentLogFile!.writeAsString(
        content,
        mode: FileMode.append,
        flush: true,
      );

      _currentFileSize += content.length;
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  /// Initialize or get current log file
  Future<void> _initLogFile() async {
    if (_logDir == null) return;

    final now = DateTime.now();
    _currentDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final fileName = 'app_$_currentDateStr.log';
    final filePath = path.join(_logDir!, fileName);
    _currentLogFile = File(filePath);

    if (await _currentLogFile!.exists()) {
      _currentFileSize = await _currentLogFile!.length();
    } else {
      _currentFileSize = 0;
    }
  }

  /// Check if log rotation is needed
  Future<void> _checkLogRotation() async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Date changed - create new file
    if (dateStr != _currentDateStr) {
      await _initLogFile();
      return;
    }

    // Size limit exceeded - create numbered file
    if (_currentFileSize >= _config.maxFileSize) {
      await _rotateCurrentFile();
    }
  }

  /// Rotate current file when size limit is exceeded
  Future<void> _rotateCurrentFile() async {
    if (_logDir == null || _currentDateStr == null) return;

    // Find next available file number
    int fileNum = 1;
    while (true) {
      final fileName = 'app_$_currentDateStr.$fileNum.log';
      final filePath = path.join(_logDir!, fileName);
      if (!await File(filePath).exists()) {
        _currentLogFile = File(filePath);
        _currentFileSize = 0;
        break;
      }
      fileNum++;
      if (fileNum > 100) {
        // Safety limit
        break;
      }
    }
  }

  /// Clean up old log files based on retention policy
  Future<void> cleanupOldLogs() async {
    if (_logDir == null) return;

    try {
      final dir = Directory(_logDir!);
      if (!await dir.exists()) return;

      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: _config.retentionDays));
      int totalSize = 0;
      final files = <FileSystemEntity>[];

      // Collect all log files
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          files.add(entity);
        }
      }

      // Sort by modification time (oldest first)
      final fileStats = <File, FileStat>{};
      for (final file in files) {
        fileStats[file as File] = await file.stat();
      }
      files.sort((a, b) {
        final statA = fileStats[a]!;
        final statB = fileStats[b]!;
        return statA.modified.compareTo(statB.modified);
      });

      // Delete old files and calculate total size
      for (final entity in files) {
        final file = entity as File;
        final stat = fileStats[file]!;

        // Delete if older than retention period
        if (stat.modified.isBefore(cutoffDate)) {
          await file.delete();
          info('Deleted old log file: ${path.basename(file.path)}',
              tag: 'Logger');
          continue;
        }

        totalSize += stat.size;
      }

      // If total size exceeds limit, delete oldest files
      if (totalSize > _config.maxTotalSize) {
        for (final entity in files) {
          if (totalSize <= _config.maxTotalSize) break;

          final file = entity as File;
          if (file.path == _currentLogFile?.path) continue; // Keep current file

          final stat = fileStats[file]!;
          totalSize -= stat.size;
          await file.delete();
          info('Deleted log file (size limit): ${path.basename(file.path)}',
              tag: 'Logger');
        }
      }

      debug('Log cleanup complete. Total size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)}MB',
          tag: 'Logger');
    } catch (e) {
      debugPrint('Failed to cleanup logs: $e');
    }
  }

  /// Get total log files size in bytes
  Future<int> getLogSize() async {
    if (_logDir == null) return 0;

    try {
      final dir = Directory(_logDir!);
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Get list of log files
  Future<List<File>> getLogFiles() async {
    if (_logDir == null) return [];

    try {
      final dir = Directory(_logDir!);
      if (!await dir.exists()) return [];

      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          files.add(entity);
        }
      }

      // Sort by name (newest first)
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (e) {
      return [];
    }
  }

  /// Read log file content
  Future<String> readLogFile(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      return 'Failed to read log file: $e';
    }
  }

  /// Clear all log files
  Future<void> clearAllLogs() async {
    if (_logDir == null) return;

    try {
      final dir = Directory(_logDir!);
      if (!await dir.exists()) return;

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          await entity.delete();
        }
      }

      // Reinitialize current log file
      await _initLogFile();
      info('All logs cleared', tag: 'Logger');
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  /// Export logs to a single file for sharing
  Future<File?> exportLogs() async {
    if (_logDir == null) return null;

    try {
      // Flush any pending writes
      await _flushBuffer();

      final exportPath = path.join(_logDir!, 'export_${DateTime.now().millisecondsSinceEpoch}.log');
      final exportFile = File(exportPath);
      final sink = exportFile.openWrite();

      final files = await getLogFiles();
      for (final file in files.reversed) {
        // Oldest first
        sink.writeln('=== ${path.basename(file.path)} ===');
        sink.writeln(await file.readAsString());
        sink.writeln();
      }

      await sink.close();
      return exportFile;
    } catch (e) {
      debugPrint('Failed to export logs: $e');
      return null;
    }
  }

  /// Shutdown the logger and release all resources
  /// Call this when the app is closing or the logger is no longer needed
  Future<void> shutdown() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _flushBuffer();
    _initialized = false;
    debugPrint('Logger shutdown complete');
  }

  /// Dispose resources (alias for shutdown for compatibility)
  Future<void> dispose() async {
    await shutdown();
  }

  int _levelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}

/// Named logger for specific modules/classes
class NamedLogger {
  final String name;
  final Logger _logger = Logger();

  NamedLogger(this.name);

  void debug(String message, {Object? error, StackTrace? stack}) {
    _logger.debug(message, tag: name, error: error, stack: stack);
  }

  void info(String message, {Object? error, StackTrace? stack}) {
    _logger.info(message, tag: name, error: error, stack: stack);
  }

  void warning(String message, {Object? error, StackTrace? stack}) {
    _logger.warning(message, tag: name, error: error, stack: stack);
  }

  void error(String message, {Object? error, StackTrace? stack}) {
    _logger.error(message, tag: name, error: error, stack: stack);
  }
}

/// Global logger instance for convenience
final logger = Logger();
