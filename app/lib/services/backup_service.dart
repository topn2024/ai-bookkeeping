import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'http_service.dart';

/// Backup metadata
class BackupInfo {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int backupType;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int bookCount;
  final int budgetCount;
  final int size;
  final String? deviceName;
  final String? deviceId;
  final String? appVersion;
  final DateTime createdAt;

  BackupInfo({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.backupType,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.bookCount,
    required this.budgetCount,
    required this.size,
    this.deviceName,
    this.deviceId,
    this.appVersion,
    required this.createdAt,
  });

  factory BackupInfo.fromJson(Map<String, dynamic> json) {
    return BackupInfo(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      backupType: json['backup_type'] as int,
      transactionCount: json['transaction_count'] as int,
      accountCount: json['account_count'] as int,
      categoryCount: json['category_count'] as int,
      bookCount: json['book_count'] as int,
      budgetCount: json['budget_count'] as int,
      size: json['size'] as int,
      deviceName: json['device_name'] as String?,
      deviceId: json['device_id'] as String?,
      appVersion: json['app_version'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get backupTypeName => backupType == 0 ? '手动备份' : '自动备份';
}

/// Restore result
class RestoreResult {
  final bool success;
  final String message;
  final Map<String, int> restoredCounts;

  RestoreResult({
    required this.success,
    required this.message,
    required this.restoredCounts,
  });

  factory RestoreResult.fromJson(Map<String, dynamic> json) {
    return RestoreResult(
      success: json['success'] as bool,
      message: json['message'] as String,
      restoredCounts: Map<String, int>.from(json['restored_counts'] ?? {}),
    );
  }
}

/// Cloud backup service
class BackupService {
  static final BackupService _instance = BackupService._internal();
  final HttpService _http = HttpService();

  factory BackupService() => _instance;

  BackupService._internal();

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    String deviceName = 'Unknown';
    String deviceId = 'unknown';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = '${androidInfo.brand} ${androidInfo.model}';
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = '${iosInfo.name} (${iosInfo.model})';
      deviceId = iosInfo.identifierForVendor ?? 'unknown';
    }

    return {
      'device_name': deviceName,
      'device_id': deviceId,
      'app_version': packageInfo.version,
    };
  }

  /// Create a new backup
  Future<BackupInfo> createBackup({
    required String name,
    String? description,
    int backupType = 0,
  }) async {
    final deviceInfo = await _getDeviceInfo();

    final response = await _http.post('/backup', data: {
      'name': name,
      'description': description,
      'backup_type': backupType,
      'device_name': deviceInfo['device_name'],
      'device_id': deviceInfo['device_id'],
      'app_version': deviceInfo['app_version'],
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      return BackupInfo.fromJson(response.data);
    } else {
      throw Exception('创建备份失败: ${response.statusMessage}');
    }
  }

  /// List all backups
  Future<List<BackupInfo>> listBackups() async {
    final response = await _http.get('/backup');

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final backups = (data['backups'] as List)
          .map((b) => BackupInfo.fromJson(b as Map<String, dynamic>))
          .toList();
      return backups;
    } else {
      throw Exception('获取备份列表失败: ${response.statusMessage}');
    }
  }

  /// Get a specific backup
  Future<BackupInfo> getBackup(String backupId) async {
    final response = await _http.get('/backup/$backupId');

    if (response.statusCode == 200) {
      return BackupInfo.fromJson(response.data);
    } else if (response.statusCode == 404) {
      throw Exception('备份不存在');
    } else {
      throw Exception('获取备份失败: ${response.statusMessage}');
    }
  }

  /// Restore from a backup
  Future<RestoreResult> restoreBackup(String backupId, {bool clearExisting = false}) async {
    final response = await _http.post('/backup/$backupId/restore', data: {
      'clear_existing': clearExisting,
    });

    if (response.statusCode == 200) {
      return RestoreResult.fromJson(response.data);
    } else if (response.statusCode == 404) {
      throw Exception('备份不存在');
    } else {
      throw Exception('恢复失败: ${response.statusMessage}');
    }
  }

  /// Delete a backup
  Future<void> deleteBackup(String backupId) async {
    final response = await _http.delete('/backup/$backupId');

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw Exception('备份不存在');
      } else {
        throw Exception('删除备份失败: ${response.statusMessage}');
      }
    }
  }

  /// Create a backup with auto-generated name
  Future<BackupInfo> createAutoBackup() async {
    final now = DateTime.now();
    final name = '自动备份 ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return createBackup(
      name: name,
      description: '自动备份',
      backupType: 1,
    );
  }
}
