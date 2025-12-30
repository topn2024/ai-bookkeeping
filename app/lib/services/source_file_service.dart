import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local source files (images and audio from AI recognition).
///
/// Handles:
/// - Storing source files in app's document directory
/// - Calculating storage usage
/// - Cleaning up expired files
class SourceFileService {
  static final SourceFileService _instance = SourceFileService._internal();
  factory SourceFileService() => _instance;
  SourceFileService._internal();

  // Storage subdirectories
  static const String _imagesDir = 'source_images';
  static const String _audioDir = 'source_audio';

  // Preferences keys
  static const String _retentionDaysKey = 'source_file_retention_days';
  static const String _wifiSyncEnabledKey = 'source_file_wifi_sync_enabled';

  /// Get the base directory for source files
  Future<Directory> get _baseDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(appDir.path, 'ai_bookkeeping', 'source_files'));
  }

  /// Get the images directory
  Future<Directory> get _imagesDirectory async {
    final base = await _baseDir;
    return Directory(path.join(base.path, _imagesDir));
  }

  /// Get the audio directory
  Future<Directory> get _audioDirectory async {
    final base = await _baseDir;
    return Directory(path.join(base.path, _audioDir));
  }

  /// Initialize the storage directories
  Future<void> initialize() async {
    final imagesDir = await _imagesDirectory;
    final audioDir = await _audioDirectory;

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
  }

  /// Save an image file and return the local path
  ///
  /// [sourceFile] - The temporary file from camera/gallery
  /// [transactionId] - The transaction ID this file belongs to
  Future<String?> saveImageFile(File sourceFile, String transactionId) async {
    try {
      final dir = await _imagesDirectory;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final extension = path.extension(sourceFile.path).toLowerCase();
      final fileName = '${transactionId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final destPath = path.join(dir.path, fileName);

      await sourceFile.copy(destPath);
      return destPath;
    } catch (e) {
      print('Error saving image file: $e');
      return null;
    }
  }

  /// Save an audio file and return the local path
  ///
  /// [sourceFile] - The temporary audio file from recording
  /// [transactionId] - The transaction ID this file belongs to
  Future<String?> saveAudioFile(File sourceFile, String transactionId) async {
    try {
      final dir = await _audioDirectory;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final extension = path.extension(sourceFile.path).toLowerCase();
      final fileName = '${transactionId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final destPath = path.join(dir.path, fileName);

      await sourceFile.copy(destPath);
      return destPath;
    } catch (e) {
      print('Error saving audio file: $e');
      return null;
    }
  }

  /// Save bytes as an image file
  Future<String?> saveImageBytes(List<int> bytes, String transactionId, String extension) async {
    try {
      final dir = await _imagesDirectory;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final ext = extension.startsWith('.') ? extension : '.$extension';
      final fileName = '${transactionId}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = path.join(dir.path, fileName);

      final file = File(destPath);
      await file.writeAsBytes(bytes);
      return destPath;
    } catch (e) {
      print('Error saving image bytes: $e');
      return null;
    }
  }

  /// Save bytes as an audio file
  Future<String?> saveAudioBytes(List<int> bytes, String transactionId, String extension) async {
    try {
      final dir = await _audioDirectory;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final ext = extension.startsWith('.') ? extension : '.$extension';
      final fileName = '${transactionId}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = path.join(dir.path, fileName);

      final file = File(destPath);
      await file.writeAsBytes(bytes);
      return destPath;
    } catch (e) {
      print('Error saving audio bytes: $e');
      return null;
    }
  }

  /// Delete a source file by path
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Check if a file exists
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Calculate total storage used by source files
  Future<SourceFileStorageInfo> getStorageInfo() async {
    int totalSize = 0;
    int imageCount = 0;
    int audioCount = 0;
    int imageSize = 0;
    int audioSize = 0;

    try {
      final imagesDir = await _imagesDirectory;
      if (await imagesDir.exists()) {
        await for (final entity in imagesDir.list()) {
          if (entity is File) {
            final size = await entity.length();
            imageSize += size;
            imageCount++;
          }
        }
      }

      final audioDir = await _audioDirectory;
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list()) {
          if (entity is File) {
            final size = await entity.length();
            audioSize += size;
            audioCount++;
          }
        }
      }

      totalSize = imageSize + audioSize;
    } catch (e) {
      print('Error calculating storage: $e');
    }

    return SourceFileStorageInfo(
      totalSize: totalSize,
      imageCount: imageCount,
      audioCount: audioCount,
      imageSize: imageSize,
      audioSize: audioSize,
    );
  }

  /// Get all source files with their modification times
  Future<List<SourceFileInfo>> getAllSourceFiles() async {
    final files = <SourceFileInfo>[];

    try {
      final imagesDir = await _imagesDirectory;
      if (await imagesDir.exists()) {
        await for (final entity in imagesDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            files.add(SourceFileInfo(
              path: entity.path,
              type: SourceFileType.image,
              size: stat.size,
              modifiedAt: stat.modified,
            ));
          }
        }
      }

      final audioDir = await _audioDirectory;
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            files.add(SourceFileInfo(
              path: entity.path,
              type: SourceFileType.audio,
              size: stat.size,
              modifiedAt: stat.modified,
            ));
          }
        }
      }
    } catch (e) {
      print('Error getting source files: $e');
    }

    return files;
  }

  /// Delete files older than the specified date
  Future<int> deleteFilesOlderThan(DateTime cutoffDate) async {
    int deletedCount = 0;

    try {
      final imagesDir = await _imagesDirectory;
      if (await imagesDir.exists()) {
        await for (final entity in imagesDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await entity.delete();
              deletedCount++;
            }
          }
        }
      }

      final audioDir = await _audioDirectory;
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await entity.delete();
              deletedCount++;
            }
          }
        }
      }
    } catch (e) {
      print('Error deleting old files: $e');
    }

    return deletedCount;
  }

  /// Delete all source files
  Future<int> deleteAllFiles() async {
    int deletedCount = 0;

    try {
      final imagesDir = await _imagesDirectory;
      if (await imagesDir.exists()) {
        await for (final entity in imagesDir.list()) {
          if (entity is File) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      final audioDir = await _audioDirectory;
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list()) {
          if (entity is File) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
    } catch (e) {
      print('Error deleting all files: $e');
    }

    return deletedCount;
  }

  // ==================== User Settings ====================

  /// Get retention period in days (default 7 days = 1 week)
  Future<int> getRetentionDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_retentionDaysKey) ?? 7;
  }

  /// Set retention period in days
  /// Common values: 7 (1 week), 14 (2 weeks), 30 (1 month)
  Future<void> setRetentionDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_retentionDaysKey, days);
  }

  /// Check if WiFi sync is enabled
  Future<bool> isWifiSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wifiSyncEnabledKey) ?? true;
  }

  /// Enable or disable WiFi sync
  Future<void> setWifiSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiSyncEnabledKey, enabled);
  }

  /// Calculate expiry date based on current retention setting
  Future<DateTime> calculateExpiryDate() async {
    final days = await getRetentionDays();
    return DateTime.now().add(Duration(days: days));
  }

  /// Clean up expired files based on retention setting
  Future<int> cleanupExpiredFiles() async {
    final days = await getRetentionDays();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return await deleteFilesOlderThan(cutoffDate);
  }
}

/// Information about a single source file
class SourceFileInfo {
  final String path;
  final SourceFileType type;
  final int size;
  final DateTime modifiedAt;

  SourceFileInfo({
    required this.path,
    required this.type,
    required this.size,
    required this.modifiedAt,
  });

  String get fileName => path.split(Platform.pathSeparator).last;
}

/// Type of source file
enum SourceFileType {
  image,
  audio,
}

/// Storage information summary
class SourceFileStorageInfo {
  final int totalSize;
  final int imageCount;
  final int audioCount;
  final int imageSize;
  final int audioSize;

  SourceFileStorageInfo({
    required this.totalSize,
    required this.imageCount,
    required this.audioCount,
    required this.imageSize,
    required this.audioSize,
  });

  int get totalCount => imageCount + audioCount;

  /// Format size as human-readable string
  String get formattedTotalSize => _formatBytes(totalSize);
  String get formattedImageSize => _formatBytes(imageSize);
  String get formattedAudioSize => _formatBytes(audioSize);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
