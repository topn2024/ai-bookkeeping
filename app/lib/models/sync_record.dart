/// 同步操作类型
enum SyncOperation {
  create,
  update,
  delete,
}

/// 同步状态
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
  conflict,
}

/// 同步实体类型
enum SyncEntityType {
  transaction,
  budget,
  member,
  goal,
  split,
  ledgerSettings,
}

/// 同步记录
class SyncRecord {
  final String id;
  final String ledgerId;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperation operation;
  final SyncStatus status;
  final DateTime localTimestamp;
  final DateTime? serverTimestamp;
  final Map<String, dynamic> data;
  final String? errorMessage;

  const SyncRecord({
    required this.id,
    required this.ledgerId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.status,
    required this.localTimestamp,
    this.serverTimestamp,
    required this.data,
    this.errorMessage,
  });

  SyncRecord copyWith({
    SyncStatus? status,
    DateTime? serverTimestamp,
    String? errorMessage,
  }) {
    return SyncRecord(
      id: id,
      ledgerId: ledgerId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      status: status ?? this.status,
      localTimestamp: localTimestamp,
      serverTimestamp: serverTimestamp ?? this.serverTimestamp,
      data: data,
      errorMessage: errorMessage,
    );
  }
}
