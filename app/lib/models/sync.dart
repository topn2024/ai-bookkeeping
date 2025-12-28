import 'package:flutter/material.dart';

/// 同步状态
enum SyncStatus {
  idle,           // 空闲
  syncing,        // 同步中
  success,        // 同步成功
  failed,         // 同步失败
  conflict,       // 存在冲突
  offline,        // 离线状态
}

extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.idle:
        return '未同步';
      case SyncStatus.syncing:
        return '同步中...';
      case SyncStatus.success:
        return '已同步';
      case SyncStatus.failed:
        return '同步失败';
      case SyncStatus.conflict:
        return '存在冲突';
      case SyncStatus.offline:
        return '离线';
    }
  }

  IconData get icon {
    switch (this) {
      case SyncStatus.idle:
        return Icons.cloud_off;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
        return Icons.cloud_done;
      case SyncStatus.failed:
        return Icons.cloud_off;
      case SyncStatus.conflict:
        return Icons.warning;
      case SyncStatus.offline:
        return Icons.signal_wifi_off;
    }
  }

  Color get color {
    switch (this) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.failed:
        return Colors.red;
      case SyncStatus.conflict:
        return Colors.orange;
      case SyncStatus.offline:
        return Colors.grey;
    }
  }
}

/// 云服务提供商
enum CloudProvider {
  local,          // 本地备份
  webdav,         // WebDAV
  googleDrive,    // Google Drive
  icloud,         // iCloud
  dropbox,        // Dropbox
  onedrive,       // OneDrive
}

extension CloudProviderExtension on CloudProvider {
  String get displayName {
    switch (this) {
      case CloudProvider.local:
        return '本地备份';
      case CloudProvider.webdav:
        return 'WebDAV';
      case CloudProvider.googleDrive:
        return 'Google Drive';
      case CloudProvider.icloud:
        return 'iCloud';
      case CloudProvider.dropbox:
        return 'Dropbox';
      case CloudProvider.onedrive:
        return 'OneDrive';
    }
  }

  IconData get icon {
    switch (this) {
      case CloudProvider.local:
        return Icons.folder;
      case CloudProvider.webdav:
        return Icons.cloud;
      case CloudProvider.googleDrive:
        return Icons.add_to_drive;
      case CloudProvider.icloud:
        return Icons.cloud_circle;
      case CloudProvider.dropbox:
        return Icons.cloud_queue;
      case CloudProvider.onedrive:
        return Icons.cloud;
    }
  }

  bool get isAvailable {
    // 目前只支持本地备份和WebDAV
    return this == CloudProvider.local || this == CloudProvider.webdav;
  }
}

/// 同步频率
enum SyncFrequency {
  manual,         // 手动同步
  realtime,       // 实时同步
  hourly,         // 每小时
  daily,          // 每天
  weekly,         // 每周
}

extension SyncFrequencyExtension on SyncFrequency {
  String get displayName {
    switch (this) {
      case SyncFrequency.manual:
        return '手动同步';
      case SyncFrequency.realtime:
        return '实时同步';
      case SyncFrequency.hourly:
        return '每小时';
      case SyncFrequency.daily:
        return '每天';
      case SyncFrequency.weekly:
        return '每周';
    }
  }

  Duration? get interval {
    switch (this) {
      case SyncFrequency.manual:
        return null;
      case SyncFrequency.realtime:
        return const Duration(seconds: 30);
      case SyncFrequency.hourly:
        return const Duration(hours: 1);
      case SyncFrequency.daily:
        return const Duration(days: 1);
      case SyncFrequency.weekly:
        return const Duration(days: 7);
    }
  }
}

/// 同步记录
class SyncRecord {
  final String id;
  final DateTime timestamp;
  final SyncStatus status;
  final CloudProvider provider;
  final SyncDirection direction;
  final int itemsUploaded;
  final int itemsDownloaded;
  final int conflictsResolved;
  final String? errorMessage;
  final Duration duration;

  const SyncRecord({
    required this.id,
    required this.timestamp,
    required this.status,
    required this.provider,
    required this.direction,
    this.itemsUploaded = 0,
    this.itemsDownloaded = 0,
    this.conflictsResolved = 0,
    this.errorMessage,
    this.duration = Duration.zero,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.index,
      'provider': provider.index,
      'direction': direction.index,
      'itemsUploaded': itemsUploaded,
      'itemsDownloaded': itemsDownloaded,
      'conflictsResolved': conflictsResolved,
      'errorMessage': errorMessage,
      'duration': duration.inMilliseconds,
    };
  }

  factory SyncRecord.fromMap(Map<String, dynamic> map) {
    return SyncRecord(
      id: map['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      status: SyncStatus.values[map['status'] as int],
      provider: CloudProvider.values[map['provider'] as int],
      direction: SyncDirection.values[map['direction'] as int],
      itemsUploaded: map['itemsUploaded'] as int? ?? 0,
      itemsDownloaded: map['itemsDownloaded'] as int? ?? 0,
      conflictsResolved: map['conflictsResolved'] as int? ?? 0,
      errorMessage: map['errorMessage'] as String?,
      duration: Duration(milliseconds: map['duration'] as int? ?? 0),
    );
  }
}

/// 同步方向
enum SyncDirection {
  upload,         // 上传
  download,       // 下载
  bidirectional,  // 双向同步
}

extension SyncDirectionExtension on SyncDirection {
  String get displayName {
    switch (this) {
      case SyncDirection.upload:
        return '上传';
      case SyncDirection.download:
        return '下载';
      case SyncDirection.bidirectional:
        return '双向同步';
    }
  }

  IconData get icon {
    switch (this) {
      case SyncDirection.upload:
        return Icons.cloud_upload;
      case SyncDirection.download:
        return Icons.cloud_download;
      case SyncDirection.bidirectional:
        return Icons.sync;
    }
  }
}

/// 数据冲突
class SyncConflict {
  final String id;
  final String entityType;      // 实体类型：transaction, account, category等
  final String entityId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime localModified;
  final DateTime remoteModified;
  final ConflictResolution? resolution;
  final DateTime createdAt;

  const SyncConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.localData,
    required this.remoteData,
    required this.localModified,
    required this.remoteModified,
    this.resolution,
    required this.createdAt,
  });

  bool get isResolved => resolution != null;

  SyncConflict copyWith({
    ConflictResolution? resolution,
  }) {
    return SyncConflict(
      id: id,
      entityType: entityType,
      entityId: entityId,
      localData: localData,
      remoteData: remoteData,
      localModified: localModified,
      remoteModified: remoteModified,
      resolution: resolution ?? this.resolution,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'localData': localData,
      'remoteData': remoteData,
      'localModified': localModified.millisecondsSinceEpoch,
      'remoteModified': remoteModified.millisecondsSinceEpoch,
      'resolution': resolution?.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SyncConflict.fromMap(Map<String, dynamic> map) {
    return SyncConflict(
      id: map['id'] as String,
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      localData: Map<String, dynamic>.from(map['localData'] as Map),
      remoteData: Map<String, dynamic>.from(map['remoteData'] as Map),
      localModified: DateTime.fromMillisecondsSinceEpoch(map['localModified'] as int),
      remoteModified: DateTime.fromMillisecondsSinceEpoch(map['remoteModified'] as int),
      resolution: map['resolution'] != null
          ? ConflictResolution.values[map['resolution'] as int]
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// 冲突解决策略
enum ConflictResolution {
  keepLocal,      // 保留本地版本
  keepRemote,     // 保留远程版本
  keepBoth,       // 保留两者（创建副本）
  merge,          // 合并
}

extension ConflictResolutionExtension on ConflictResolution {
  String get displayName {
    switch (this) {
      case ConflictResolution.keepLocal:
        return '保留本地';
      case ConflictResolution.keepRemote:
        return '保留云端';
      case ConflictResolution.keepBoth:
        return '保留两者';
      case ConflictResolution.merge:
        return '智能合并';
    }
  }

  String get description {
    switch (this) {
      case ConflictResolution.keepLocal:
        return '使用本地版本覆盖云端';
      case ConflictResolution.keepRemote:
        return '使用云端版本覆盖本地';
      case ConflictResolution.keepBoth:
        return '创建副本保留两个版本';
      case ConflictResolution.merge:
        return '自动合并非冲突字段';
    }
  }
}

/// 备份数据
class BackupData {
  final String id;
  final String version;
  final DateTime createdAt;
  final String deviceId;
  final String deviceName;
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int budgetCount;
  final int totalRecords;
  final Map<String, dynamic> data;

  const BackupData({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.deviceId,
    required this.deviceName,
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.budgetCount,
    required this.totalRecords,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'transactionCount': transactionCount,
      'accountCount': accountCount,
      'categoryCount': categoryCount,
      'budgetCount': budgetCount,
      'totalRecords': totalRecords,
      'data': data,
    };
  }

  factory BackupData.fromMap(Map<String, dynamic> map) {
    return BackupData(
      id: map['id'] as String,
      version: map['version'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      transactionCount: map['transactionCount'] as int,
      accountCount: map['accountCount'] as int,
      categoryCount: map['categoryCount'] as int,
      budgetCount: map['budgetCount'] as int,
      totalRecords: map['totalRecords'] as int,
      data: Map<String, dynamic>.from(map['data'] as Map),
    );
  }
}

/// 同步设置
class SyncSettings {
  final bool enabled;
  final CloudProvider provider;
  final SyncFrequency frequency;
  final bool wifiOnly;
  final bool autoResolveConflicts;
  final ConflictResolution defaultResolution;
  final bool backupBeforeSync;
  final int maxBackupCount;
  final DateTime? lastSyncTime;

  const SyncSettings({
    this.enabled = false,
    this.provider = CloudProvider.local,
    this.frequency = SyncFrequency.manual,
    this.wifiOnly = true,
    this.autoResolveConflicts = false,
    this.defaultResolution = ConflictResolution.keepLocal,
    this.backupBeforeSync = true,
    this.maxBackupCount = 5,
    this.lastSyncTime,
  });

  SyncSettings copyWith({
    bool? enabled,
    CloudProvider? provider,
    SyncFrequency? frequency,
    bool? wifiOnly,
    bool? autoResolveConflicts,
    ConflictResolution? defaultResolution,
    bool? backupBeforeSync,
    int? maxBackupCount,
    DateTime? lastSyncTime,
  }) {
    return SyncSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      frequency: frequency ?? this.frequency,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoResolveConflicts: autoResolveConflicts ?? this.autoResolveConflicts,
      defaultResolution: defaultResolution ?? this.defaultResolution,
      backupBeforeSync: backupBeforeSync ?? this.backupBeforeSync,
      maxBackupCount: maxBackupCount ?? this.maxBackupCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'provider': provider.index,
      'frequency': frequency.index,
      'wifiOnly': wifiOnly,
      'autoResolveConflicts': autoResolveConflicts,
      'defaultResolution': defaultResolution.index,
      'backupBeforeSync': backupBeforeSync,
      'maxBackupCount': maxBackupCount,
      'lastSyncTime': lastSyncTime?.millisecondsSinceEpoch,
    };
  }

  factory SyncSettings.fromMap(Map<String, dynamic> map) {
    return SyncSettings(
      enabled: map['enabled'] as bool? ?? false,
      provider: CloudProvider.values[map['provider'] as int? ?? 0],
      frequency: SyncFrequency.values[map['frequency'] as int? ?? 0],
      wifiOnly: map['wifiOnly'] as bool? ?? true,
      autoResolveConflicts: map['autoResolveConflicts'] as bool? ?? false,
      defaultResolution: ConflictResolution.values[map['defaultResolution'] as int? ?? 0],
      backupBeforeSync: map['backupBeforeSync'] as bool? ?? true,
      maxBackupCount: map['maxBackupCount'] as int? ?? 5,
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSyncTime'] as int)
          : null,
    );
  }
}

/// WebDAV配置
class WebDAVConfig {
  final String url;
  final String username;
  final String password;
  final String remotePath;
  final bool verified;

  const WebDAVConfig({
    required this.url,
    required this.username,
    required this.password,
    this.remotePath = '/bookkeeping',
    this.verified = false,
  });

  WebDAVConfig copyWith({
    String? url,
    String? username,
    String? password,
    String? remotePath,
    bool? verified,
  }) {
    return WebDAVConfig(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
      verified: verified ?? this.verified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'username': username,
      'password': password,
      'remotePath': remotePath,
      'verified': verified,
    };
  }

  factory WebDAVConfig.fromMap(Map<String, dynamic> map) {
    return WebDAVConfig(
      url: map['url'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      remotePath: map['remotePath'] as String? ?? '/bookkeeping',
      verified: map['verified'] as bool? ?? false,
    );
  }
}
