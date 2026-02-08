/// 同步状态
enum SyncStatus {
  idle,
  syncing,
  success,
  failed,
  conflict,
}

/// 同步结果
class SyncResult {
  final SyncStatus status;
  final int uploadedCount;
  final int downloadedCount;
  final int conflictCount;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const SyncResult({
    required this.status,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.conflictCount = 0,
    this.errorMessage,
    this.lastSyncTime,
  });

  bool get isSuccess => status == SyncStatus.success;
  bool get hasConflicts => conflictCount > 0;
}

/// 同步冲突
class SyncConflict {
  final String entityType;
  final String entityId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime localModifiedAt;
  final DateTime serverModifiedAt;

  const SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.localData,
    required this.serverData,
    required this.localModifiedAt,
    required this.serverModifiedAt,
  });
}

/// 冲突解决策略
enum ConflictResolution {
  keepLocal,
  keepServer,
  merge,
}

/// 同步服务接口
///
/// 定义数据同步相关操作的抽象接口，包括上传、下载、冲突解决等。
abstract class ISyncService {
  // ==================== 同步状态 ====================

  /// 获取当前同步状态
  SyncStatus get status;

  /// 获取最后同步时间
  Future<DateTime?> getLastSyncTime();

  /// 检查是否需要同步
  Future<bool> needsSync();

  // ==================== 同步操作 ====================

  /// 执行完整同步
  Future<SyncResult> sync();

  /// 仅上传本地更改
  Future<SyncResult> upload();

  /// 仅下载服务器更改
  Future<SyncResult> download();

  /// 同步特定实体类型
  Future<SyncResult> syncEntity(String entityType);

  // ==================== 队列管理 ====================

  /// 添加到同步队列
  Future<void> addToQueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> data,
  });

  /// 获取待同步项目数量
  Future<int> getPendingCount();

  /// 获取待同步队列
  Future<List<Map<String, dynamic>>> getPendingQueue();

  /// 清除同步队列
  Future<void> clearQueue();

  // ==================== 冲突处理 ====================

  /// 获取未解决的冲突
  Future<List<SyncConflict>> getConflicts();

  /// 解决冲突
  Future<void> resolveConflict(
    String entityType,
    String entityId,
    ConflictResolution resolution,
  );

  /// 批量解决冲突
  Future<void> resolveAllConflicts(ConflictResolution resolution);

  // ==================== ID 映射 ====================

  /// 获取服务器 ID（根据本地 ID）
  Future<String?> getServerId(String entityType, String localId);

  /// 获取本地 ID（根据服务器 ID）
  Future<String?> getLocalId(String entityType, String serverId);

  /// 创建 ID 映射
  Future<void> createIdMapping({
    required String entityType,
    required String localId,
    required String serverId,
  });

  // ==================== 统计信息 ====================

  /// 获取同步统计信息
  Future<Map<String, int>> getStatistics();
}
