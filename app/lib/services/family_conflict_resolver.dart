/// 冲突类型
enum ConflictType {
  /// 同时修改
  concurrentEdit,
  /// 删除冲突
  deleteConflict,
  /// 版本冲突
  versionMismatch,
}

/// 冲突解决策略
enum ConflictResolution {
  /// 使用本地版本
  useLocal,
  /// 使用服务器版本
  useServer,
  /// 合并
  merge,
  /// 用户选择
  askUser,
}

/// 数据冲突
class DataConflict {
  final String entityId;
  final String entityType;
  final ConflictType type;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime localTimestamp;
  final DateTime serverTimestamp;

  const DataConflict({
    required this.entityId,
    required this.entityType,
    required this.type,
    required this.localData,
    required this.serverData,
    required this.localTimestamp,
    required this.serverTimestamp,
  });
}

/// 家庭账本冲突解决器
class FamilyConflictResolver {
  static final FamilyConflictResolver _instance =
      FamilyConflictResolver._internal();
  factory FamilyConflictResolver() => _instance;
  FamilyConflictResolver._internal();

  /// 默认策略：最后写入优先
  ConflictResolution defaultStrategy = ConflictResolution.useServer;

  /// 解决冲突
  Future<Map<String, dynamic>> resolve(DataConflict conflict) async {
    switch (defaultStrategy) {
      case ConflictResolution.useLocal:
        return conflict.localData;
      case ConflictResolution.useServer:
        return conflict.serverData;
      case ConflictResolution.merge:
        return _mergeData(conflict);
      case ConflictResolution.askUser:
        return conflict.serverData;
    }
  }

  /// 合并数据
  Map<String, dynamic> _mergeData(DataConflict conflict) {
    final merged = Map<String, dynamic>.from(conflict.serverData);
    for (final key in conflict.localData.keys) {
      if (conflict.localTimestamp.isAfter(conflict.serverTimestamp)) {
        merged[key] = conflict.localData[key];
      }
    }
    return merged;
  }
}