import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'encryption_service.dart';
import 'location_service.dart';

/// 位置隐私保护服务
/// 对应设计文档第14.3节：隐私优先设计原则
///
/// 核心功能：
/// 1. 合理化采集 - 仅在需要时获取位置
/// 2. 本地优先 - AES-256本地加密存储
/// 3. 透明授权 - 明确告知用途，用户可控
/// 4. 生命周期 - 30天自动清理历史轨迹
///
/// 使用示例：
/// ```dart
/// final guard = LocationPrivacyGuard();
///
/// // 检查是否可以获取位置
/// if (await guard.canAccessLocation(LocationPurpose.bookkeeping)) {
///   final position = await locationService.getCurrentPosition();
///   // 加密存储
///   await guard.storeLocationSecurely(position, purpose: LocationPurpose.bookkeeping);
/// }
///
/// // 定期清理过期数据
/// await guard.cleanupExpiredData();
/// ```
class LocationPrivacyGuard {
  final EncryptionService _encryption;
  static const String _keyPrefix = 'location_privacy_';
  static const int _defaultRetentionDays = 30;

  // 隐私设置键
  static const String _keyLocationEnabled = '${_keyPrefix}enabled';
  static const String _keyPurposePermissions = '${_keyPrefix}purpose_permissions';
  static const String _keyLastCleanupTime = '${_keyPrefix}last_cleanup';
  static const String _keyConsentHistory = '${_keyPrefix}consent_history';
  static const String _keyUsageLog = '${_keyPrefix}usage_log';

  LocationPrivacyGuard({
    EncryptionService? encryption,
  }) : _encryption = encryption ?? EncryptionService();

  // ========== 1. 合理化采集 ==========

  /// 检查是否可以访问位置信息
  Future<bool> canAccessLocation(LocationPurpose purpose) async {
    final prefs = await SharedPreferences.getInstance();

    // 检查全局开关
    final enabled = prefs.getBool(_keyLocationEnabled) ?? false;
    if (!enabled) return false;

    // 检查特定用途的权限
    final permissions = await _getPurposePermissions();
    return permissions[purpose.name] ?? false;
  }

  /// 请求位置访问权限
  Future<LocationPermissionResponse> requestLocationAccess({
    required LocationPurpose purpose,
    required String description,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 记录权限请求
    await _logPermissionRequest(purpose, description);

    // 在实际应用中，这里应该显示权限请求对话框
    // 这里提供默认实现
    final permissions = await _getPurposePermissions();
    permissions[purpose.name] = true;
    await _savePurposePermissions(permissions);

    // 记录同意
    await _recordConsent(purpose, description, true);

    return LocationPermissionResponse(
      granted: true,
      purpose: purpose,
      timestamp: DateTime.now(),
    );
  }

  /// 撤销位置访问权限
  Future<void> revokeLocationAccess(LocationPurpose purpose) async {
    final permissions = await _getPurposePermissions();
    permissions[purpose.name] = false;
    await _savePurposePermissions(permissions);

    // 记录撤销
    await _recordConsent(purpose, '用户撤销', false);
  }

  /// 全局启用/禁用位置功能
  Future<void> setLocationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocationEnabled, enabled);

    if (!enabled) {
      // 禁用时清理所有权限
      await _savePurposePermissions({});
    }
  }

  /// 检查位置功能是否启用
  Future<bool> isLocationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocationEnabled) ?? false;
  }

  // ========== 2. 本地优先（加密存储） ==========

  /// 安全地存储位置信息
  Future<String> storeLocationSecurely({
    required Position position,
    required LocationPurpose purpose,
    Map<String, dynamic>? metadata,
  }) async {
    final locationData = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
      'timestamp': position.timestamp.toIso8601String(),
      'purpose': purpose.name,
      'metadata': metadata,
    };

    // AES-256加密
    final encrypted = await _encryption.encrypt(jsonEncode(locationData));

    // 生成唯一ID
    final id = _generateLocationId(position, purpose);

    // 存储加密数据
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$id';
    await prefs.setString(key, encrypted);

    // 记录使用
    await _logLocationUsage(id, purpose);

    return id;
  }

  /// 安全地读取位置信息
  Future<LocationData?> retrieveLocationSecurely(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$id';
    final encrypted = prefs.getString(key);

    if (encrypted == null) return null;

    try {
      // 解密
      final decrypted = await _encryption.decrypt(encrypted);
      final data = jsonDecode(decrypted) as Map<String, dynamic>;

      return LocationData(
        id: id,
        position: Position(
          latitude: data['latitude'] as double,
          longitude: data['longitude'] as double,
          accuracy: data['accuracy'] as double?,
          altitude: data['altitude'] as double?,
          speed: data['speed'] as double?,
          timestamp: DateTime.parse(data['timestamp'] as String),
        ),
        purpose: LocationPurpose.values.firstWhere(
          (p) => p.name == data['purpose'],
          orElse: () => LocationPurpose.unknown,
        ),
        metadata: data['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      debugPrint('解密位置数据失败: $e');
      return null;
    }
  }

  /// 获取所有位置记录ID
  Future<List<String>> getAllLocationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    return keys
        .where((key) => key.startsWith(_keyPrefix) &&
               !key.contains('enabled') &&
               !key.contains('permissions') &&
               !key.contains('cleanup') &&
               !key.contains('consent') &&
               !key.contains('usage'))
        .map((key) => key.substring(_keyPrefix.length))
        .toList();
  }

  // ========== 3. 透明授权 ==========

  /// 获取同意历史
  Future<List<ConsentRecord>> getConsentHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyConsentHistory);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((item) => ConsentRecord.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 记录同意记录
  Future<void> _recordConsent(
    LocationPurpose purpose,
    String description,
    bool granted,
  ) async {
    final record = ConsentRecord(
      purpose: purpose,
      description: description,
      granted: granted,
      timestamp: DateTime.now(),
    );

    final history = await getConsentHistory();
    history.add(record);

    // 只保留最近100条记录
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyConsentHistory,
      jsonEncode(history.map((r) => r.toJson()).toList()),
    );
  }

  /// 获取使用日志
  Future<List<UsageLogEntry>> getUsageLog({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyUsageLog);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List<dynamic>;
      var logs = list.map((item) => UsageLogEntry.fromJson(item as Map<String, dynamic>)).toList();

      // 过滤日期范围
      if (startDate != null) {
        logs = logs.where((log) => log.timestamp.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        logs = logs.where((log) => log.timestamp.isBefore(endDate)).toList();
      }

      return logs;
    } catch (e) {
      return [];
    }
  }

  // ========== 4. 生命周期管理 ==========

  /// 清理过期数据（默认30天）
  Future<CleanupResult> cleanupExpiredData({
    int retentionDays = _defaultRetentionDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: retentionDays));

    int removedCount = 0;
    int totalSize = 0;

    // 获取所有位置记录
    final ids = await getAllLocationIds();

    for (final id in ids) {
      final data = await retrieveLocationSecurely(id);
      if (data != null && data.position.timestamp.isBefore(cutoffDate)) {
        // 删除过期数据
        final key = '$_keyPrefix$id';
        final value = prefs.getString(key);
        if (value != null) {
          totalSize += value.length;
        }
        await prefs.remove(key);
        removedCount++;
      }
    }

    // 更新最后清理时间
    await prefs.setString(_keyLastCleanupTime, now.toIso8601String());

    return CleanupResult(
      removedCount: removedCount,
      totalSizeBytes: totalSize,
      retentionDays: retentionDays,
      timestamp: now,
    );
  }

  /// 手动立即清除所有位置数据
  Future<void> clearAllLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await getAllLocationIds();

    for (final id in ids) {
      await prefs.remove('$_keyPrefix$id');
    }

    // 清除使用日志
    await prefs.remove(_keyUsageLog);
  }

  /// 获取最后清理时间
  Future<DateTime?> getLastCleanupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_keyLastCleanupTime);
    return timeStr != null ? DateTime.tryParse(timeStr) : null;
  }

  /// 自动清理（应该在后台定期调用）
  Future<void> autoCleanup() async {
    final lastCleanup = await getLastCleanupTime();
    final now = DateTime.now();

    // 如果距离上次清理超过7天，执行清理
    if (lastCleanup == null || now.difference(lastCleanup).inDays >= 7) {
      await cleanupExpiredData();
    }
  }

  // ========== 5. 统计与监控 ==========

  /// 获取隐私统计信息
  Future<PrivacyStatistics> getPrivacyStatistics() async {
    final ids = await getAllLocationIds();
    final now = DateTime.now();

    int totalRecords = ids.length;
    int last7Days = 0;
    int last30Days = 0;
    Map<LocationPurpose, int> purposeCount = {};

    for (final id in ids) {
      final data = await retrieveLocationSecurely(id);
      if (data != null) {
        final age = now.difference(data.position.timestamp).inDays;
        if (age <= 7) last7Days++;
        if (age <= 30) last30Days++;

        purposeCount[data.purpose] = (purposeCount[data.purpose] ?? 0) + 1;
      }
    }

    final consentHistory = await getConsentHistory();
    final activePermissions = await _getActivePurposes();

    return PrivacyStatistics(
      totalRecords: totalRecords,
      last7DaysRecords: last7Days,
      last30DaysRecords: last30Days,
      purposeDistribution: purposeCount,
      activePermissions: activePermissions.length,
      totalConsents: consentHistory.length,
      lastCleanup: await getLastCleanupTime(),
    );
  }

  // ========== 辅助方法 ==========

  Future<Map<String, bool>> _getPurposePermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyPurposePermissions);
    if (json == null) return {};

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(key, value as bool));
    } catch (e) {
      return {};
    }
  }

  Future<void> _savePurposePermissions(Map<String, bool> permissions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPurposePermissions, jsonEncode(permissions));
  }

  Future<List<LocationPurpose>> _getActivePurposes() async {
    final permissions = await _getPurposePermissions();
    return permissions.entries
        .where((entry) => entry.value)
        .map((entry) => LocationPurpose.values.firstWhere(
              (p) => p.name == entry.key,
              orElse: () => LocationPurpose.unknown,
            ))
        .toList();
  }

  String _generateLocationId(Position position, LocationPurpose purpose) {
    final content = '${position.latitude}_${position.longitude}_'
        '${position.timestamp.millisecondsSinceEpoch}_${purpose.name}';
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  Future<void> _logPermissionRequest(LocationPurpose purpose, String description) async {
    // 记录权限请求日志
    debugPrint('位置权限请求: ${purpose.displayName} - $description');
  }

  Future<void> _logLocationUsage(String id, LocationPurpose purpose) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyUsageLog) ?? '[]';

    try {
      final list = jsonDecode(json) as List<dynamic>;
      final logs = list.map((item) => UsageLogEntry.fromJson(item as Map<String, dynamic>)).toList();

      logs.add(UsageLogEntry(
        locationId: id,
        purpose: purpose,
        timestamp: DateTime.now(),
      ));

      // 只保留最近1000条记录
      if (logs.length > 1000) {
        logs.removeRange(0, logs.length - 1000);
      }

      await prefs.setString(
        _keyUsageLog,
        jsonEncode(logs.map((l) => l.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('记录位置使用日志失败: $e');
    }
  }
}

// ========== 数据模型 ==========

/// 位置用途
enum LocationPurpose {
  bookkeeping,      // 记账时获取位置
  geofence,         // 地理围栏提醒
  budgetReminder,   // 预算提醒
  commute,          // 通勤分析
  homeDetection,    // 常驻地点检测
  cityIdentification, // 城市识别
  unknown,          // 未知
}

extension LocationPurposeExtension on LocationPurpose {
  String get displayName {
    switch (this) {
      case LocationPurpose.bookkeeping:
        return '记账时获取位置';
      case LocationPurpose.geofence:
        return '地理围栏提醒';
      case LocationPurpose.budgetReminder:
        return '预算提醒';
      case LocationPurpose.commute:
        return '通勤分析';
      case LocationPurpose.homeDetection:
        return '常驻地点检测';
      case LocationPurpose.cityIdentification:
        return '城市识别';
      case LocationPurpose.unknown:
        return '未知用途';
    }
  }

  String get description {
    switch (this) {
      case LocationPurpose.bookkeeping:
        return '在记账时获取位置信息，用于智能识别消费场景和商户';
      case LocationPurpose.geofence:
        return '进入设定的地理区域时触发提醒，如商圈、高消费区等';
      case LocationPurpose.budgetReminder:
        return '基于位置提供个性化预算提醒';
      case LocationPurpose.commute:
        return '分析通勤消费模式，提供省钱建议';
      case LocationPurpose.homeDetection:
        return '自动识别家、公司等常驻地点';
      case LocationPurpose.cityIdentification:
        return '识别当前城市，提供本地化服务';
      case LocationPurpose.unknown:
        return '未知用途';
    }
  }
}

/// 位置权限响应
class LocationPermissionResponse {
  final bool granted;
  final LocationPurpose purpose;
  final DateTime timestamp;

  const LocationPermissionResponse({
    required this.granted,
    required this.purpose,
    required this.timestamp,
  });
}

/// 位置数据
class LocationData {
  final String id;
  final Position position;
  final LocationPurpose purpose;
  final Map<String, dynamic>? metadata;

  const LocationData({
    required this.id,
    required this.position,
    required this.purpose,
    this.metadata,
  });
}

/// 同意记录
class ConsentRecord {
  final LocationPurpose purpose;
  final String description;
  final bool granted;
  final DateTime timestamp;

  const ConsentRecord({
    required this.purpose,
    required this.description,
    required this.granted,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'purpose': purpose.name,
        'description': description,
        'granted': granted,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
        purpose: LocationPurpose.values.firstWhere(
          (p) => p.name == json['purpose'],
          orElse: () => LocationPurpose.unknown,
        ),
        description: json['description'] as String,
        granted: json['granted'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// 使用日志条目
class UsageLogEntry {
  final String locationId;
  final LocationPurpose purpose;
  final DateTime timestamp;

  const UsageLogEntry({
    required this.locationId,
    required this.purpose,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'purpose': purpose.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory UsageLogEntry.fromJson(Map<String, dynamic> json) => UsageLogEntry(
        locationId: json['locationId'] as String,
        purpose: LocationPurpose.values.firstWhere(
          (p) => p.name == json['purpose'],
          orElse: () => LocationPurpose.unknown,
        ),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// 清理结果
class CleanupResult {
  final int removedCount;
  final int totalSizeBytes;
  final int retentionDays;
  final DateTime timestamp;

  const CleanupResult({
    required this.removedCount,
    required this.totalSizeBytes,
    required this.retentionDays,
    required this.timestamp,
  });

  @override
  String toString() => '清理完成: 删除$removedCount条记录, '
      '释放${(totalSizeBytes / 1024).toStringAsFixed(2)}KB空间, '
      '保留期${retentionDays}天';
}

/// 隐私统计
class PrivacyStatistics {
  final int totalRecords;
  final int last7DaysRecords;
  final int last30DaysRecords;
  final Map<LocationPurpose, int> purposeDistribution;
  final int activePermissions;
  final int totalConsents;
  final DateTime? lastCleanup;

  const PrivacyStatistics({
    required this.totalRecords,
    required this.last7DaysRecords,
    required this.last30DaysRecords,
    required this.purposeDistribution,
    required this.activePermissions,
    required this.totalConsents,
    this.lastCleanup,
  });
}
