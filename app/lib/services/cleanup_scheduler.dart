import 'package:shared_preferences/shared_preferences.dart';
import 'source_file_service.dart';

/// Scheduler for cleaning up expired source files.
///
/// Features:
/// - Runs cleanup on app startup
/// - Tracks last cleanup time to avoid excessive operations
/// - Configurable minimum interval between cleanups
class CleanupScheduler {
  static final CleanupScheduler _instance = CleanupScheduler._internal();
  factory CleanupScheduler() => _instance;
  CleanupScheduler._internal();

  final SourceFileService _fileService = SourceFileService();

  // Preferences keys
  static const String _lastCleanupKey = 'last_source_file_cleanup';

  // Minimum interval between cleanups (default: 24 hours)
  static const Duration _minCleanupInterval = Duration(hours: 24);

  /// Initialize the cleanup scheduler.
  /// Should be called on app startup.
  Future<void> initialize() async {
    // Initialize the source file service directories
    await _fileService.initialize();

    // Check if cleanup is needed
    if (await _shouldRunCleanup()) {
      await runCleanup();
    }
  }

  /// Check if enough time has passed since last cleanup
  Future<bool> _shouldRunCleanup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCleanupMs = prefs.getInt(_lastCleanupKey);

    if (lastCleanupMs == null) {
      // Never cleaned up before
      return true;
    }

    final lastCleanup = DateTime.fromMillisecondsSinceEpoch(lastCleanupMs);
    final timeSinceLastCleanup = DateTime.now().difference(lastCleanup);

    return timeSinceLastCleanup >= _minCleanupInterval;
  }

  /// Run the cleanup process
  Future<CleanupResult> runCleanup() async {
    try {
      // Get storage info before cleanup
      final beforeInfo = await _fileService.getStorageInfo();

      // Cleanup expired files
      final deletedCount = await _fileService.cleanupExpiredFiles();

      // Get storage info after cleanup
      final afterInfo = await _fileService.getStorageInfo();

      // Update last cleanup time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCleanupKey, DateTime.now().millisecondsSinceEpoch);

      // Calculate freed space
      final freedSpace = beforeInfo.totalSize - afterInfo.totalSize;

      return CleanupResult(
        deletedCount: deletedCount,
        freedSpace: freedSpace,
        success: true,
      );
    } catch (e) {
      print('Error during cleanup: $e');
      return CleanupResult(
        deletedCount: 0,
        freedSpace: 0,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Force cleanup immediately, ignoring the minimum interval
  Future<CleanupResult> forceCleanup() async {
    return await runCleanup();
  }

  /// Get the last cleanup time
  Future<DateTime?> getLastCleanupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCleanupMs = prefs.getInt(_lastCleanupKey);

    if (lastCleanupMs == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(lastCleanupMs);
  }

  /// Get time until next scheduled cleanup
  Future<Duration?> getTimeUntilNextCleanup() async {
    final lastCleanup = await getLastCleanupTime();

    if (lastCleanup == null) {
      return Duration.zero; // Cleanup should run immediately
    }

    final nextCleanup = lastCleanup.add(_minCleanupInterval);
    final timeUntilNext = nextCleanup.difference(DateTime.now());

    if (timeUntilNext.isNegative) {
      return Duration.zero;
    }

    return timeUntilNext;
  }
}

/// Result of a cleanup operation
class CleanupResult {
  final int deletedCount;
  final int freedSpace;
  final bool success;
  final String? errorMessage;

  CleanupResult({
    required this.deletedCount,
    required this.freedSpace,
    required this.success,
    this.errorMessage,
  });

  String get formattedFreedSpace {
    if (freedSpace < 1024) return '$freedSpace B';
    if (freedSpace < 1024 * 1024) {
      return '${(freedSpace / 1024).toStringAsFixed(1)} KB';
    }
    return '${(freedSpace / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    if (success) {
      return 'CleanupResult(deleted: $deletedCount, freed: $formattedFreedSpace)';
    } else {
      return 'CleanupResult(failed: $errorMessage)';
    }
  }
}
