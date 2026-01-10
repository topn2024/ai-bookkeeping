import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'offline_capability_service.dart';
import 'vector_clock.dart';

/// 家庭账本离线记账暂存服务
///
/// 功能：
/// 1. 离线时暂存家庭账本的记账操作
/// 2. 标记待同步状态
/// 3. 联网后自动合并到家庭账本
class FamilyOfflineStorageService {
  static final FamilyOfflineStorageService _instance = FamilyOfflineStorageService._internal();
  factory FamilyOfflineStorageService() => _instance;
  FamilyOfflineStorageService._internal();

  final DatabaseService _db = DatabaseService();
  final OfflineCapabilityService _offlineService = OfflineCapabilityService();
  StreamSubscription<NetworkStatusInfo>? _statusSubscription;

  /// 暂存键前缀
  static const String _storagePrefix = 'family_offline_';

  /// 初始化服务
  Future<void> initialize() async {
    // 监听网络恢复
    _statusSubscription = _offlineService.statusStream.listen((status) {
      if (status.isOnline) {
        syncPendingFamilyTransactions();
      }
    });
  }

  /// 释放资源
  void dispose() {
    _statusSubscription?.cancel();
  }

  /// 暂存家庭账本交易
  Future<String> storeOfflineTransaction({
    required String familyBookId,
    required String memberId,
    required Map<String, dynamic> transactionData,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final offlineTransaction = FamilyOfflineTransaction(
      id: id,
      familyBookId: familyBookId,
      memberId: memberId,
      transactionData: transactionData,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    // 保存到本地数据库
    final db = await _db.database;
    await db.insert('family_offline_transactions', offlineTransaction.toMap());

    debugPrint('Family transaction stored offline: $id');
    return id;
  }

  /// 获取待同步的家庭交易
  Future<List<FamilyOfflineTransaction>> getPendingTransactions(String familyBookId) async {
    final db = await _db.database;

    final results = await db.query(
      'family_offline_transactions',
      where: 'family_book_id = ? AND sync_status = ?',
      whereArgs: [familyBookId, SyncStatus.pending.index],
      orderBy: 'created_at ASC',
    );

    return results.map((r) => FamilyOfflineTransaction.fromMap(r)).toList();
  }

  /// 获取所有待同步的家庭交易
  Future<List<FamilyOfflineTransaction>> getAllPendingTransactions() async {
    final db = await _db.database;

    final results = await db.query(
      'family_offline_transactions',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.index],
      orderBy: 'created_at ASC',
    );

    return results.map((r) => FamilyOfflineTransaction.fromMap(r)).toList();
  }

  /// 同步待处理的家庭交易
  Future<SyncResult> syncPendingFamilyTransactions() async {
    if (!_offlineService.isOnline) {
      return SyncResult(
        success: false,
        synced: 0,
        failed: 0,
        message: '设备离线',
      );
    }

    final pending = await getAllPendingTransactions();
    if (pending.isEmpty) {
      return SyncResult(success: true, synced: 0, failed: 0);
    }

    debugPrint('Syncing ${pending.length} family transactions...');

    int synced = 0;
    int failed = 0;

    for (final transaction in pending) {
      try {
        await _syncSingleTransaction(transaction);
        synced++;
      } catch (e) {
        debugPrint('Failed to sync family transaction ${transaction.id}: $e');
        failed++;
      }
    }

    return SyncResult(
      success: failed == 0,
      synced: synced,
      failed: failed,
    );
  }

  /// 同步单个交易
  Future<void> _syncSingleTransaction(FamilyOfflineTransaction transaction) async {
    final db = await _db.database;

    // 标记为同步中
    await db.update(
      'family_offline_transactions',
      {'sync_status': SyncStatus.syncing.index},
      where: 'id = ?',
      whereArgs: [transaction.id],
    );

    try {
      // 实际同步逻辑（通过API或CRDT同步）
      // 这里使用模拟延迟
      await Future.delayed(const Duration(milliseconds: 500));

      // 标记为已同步
      await db.update(
        'family_offline_transactions',
        {
          'sync_status': SyncStatus.synced.index,
          'synced_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [transaction.id],
      );

      debugPrint('Family transaction synced: ${transaction.id}');
    } catch (e) {
      // 同步失败，标记回pending
      await db.update(
        'family_offline_transactions',
        {
          'sync_status': SyncStatus.failed.index,
          'error_message': e.toString(),
        },
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      rethrow;
    }
  }

  /// 删除已同步的交易记录
  Future<int> clearSyncedTransactions() async {
    final db = await _db.database;

    return await db.delete(
      'family_offline_transactions',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.synced.index],
    );
  }

  /// 获取待同步数量
  Future<int> getPendingCount() async {
    final db = await _db.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM family_offline_transactions
      WHERE sync_status = ?
    ''', [SyncStatus.pending.index]);

    return (result.first['count'] as int?) ?? 0;
  }
}

/// 家庭离线交易数据模型
class FamilyOfflineTransaction {
  final String id;
  final String familyBookId;
  final String memberId;
  final Map<String, dynamic> transactionData;
  final DateTime createdAt;
  final SyncStatus syncStatus;
  final DateTime? syncedAt;
  final String? errorMessage;

  const FamilyOfflineTransaction({
    required this.id,
    required this.familyBookId,
    required this.memberId,
    required this.transactionData,
    required this.createdAt,
    required this.syncStatus,
    this.syncedAt,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'family_book_id': familyBookId,
    'member_id': memberId,
    'transaction_data': jsonEncode(transactionData),
    'created_at': createdAt.millisecondsSinceEpoch,
    'sync_status': syncStatus.index,
    'synced_at': syncedAt?.millisecondsSinceEpoch,
    'error_message': errorMessage,
  };

  factory FamilyOfflineTransaction.fromMap(Map<String, dynamic> map) {
    return FamilyOfflineTransaction(
      id: map['id'] as String,
      familyBookId: map['family_book_id'] as String,
      memberId: map['member_id'] as String,
      transactionData: jsonDecode(map['transaction_data'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      syncStatus: SyncStatus.values[map['sync_status'] as int],
      syncedAt: map['synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['synced_at'] as int)
          : null,
      errorMessage: map['error_message'] as String?,
    );
  }
}

/// 同步状态
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
}

/// 同步结果
class SyncResult {
  final bool success;
  final int synced;
  final int failed;
  final String? message;

  const SyncResult({
    required this.success,
    required this.synced,
    required this.failed,
    this.message,
  });
}

/// 同步冲突检测与解决服务
///
/// 功能：
/// 1. 检测数据冲突（基于向量时钟）
/// 2. 提供多种冲突解决策略
/// 3. 支持用户手动选择解决方案
class SyncConflictService {
  static final SyncConflictService _instance = SyncConflictService._internal();
  factory SyncConflictService() => _instance;
  SyncConflictService._internal();

  final DatabaseService _db = DatabaseService();

  final _conflictController = StreamController<ConflictEvent>.broadcast();

  /// 冲突事件流
  Stream<ConflictEvent> get conflictStream => _conflictController.stream;

  /// 检测冲突
  Future<ConflictResult> detectConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required VectorClock localClock,
    required VectorClock remoteClock,
  }) async {
    // 比较向量时钟
    final comparison = localClock.compare(remoteClock);

    switch (comparison) {
      case ClockComparison.equal:
        // 时钟相等，无冲突
        return ConflictResult(
          hasConflict: false,
          type: ConflictType.none,
        );

      case ClockComparison.before:
        // 本地在远程之前，使用远程版本
        return ConflictResult(
          hasConflict: false,
          type: ConflictType.none,
          resolution: ConflictResolution.useRemote,
        );

      case ClockComparison.after:
        // 本地在远程之后，使用本地版本
        return ConflictResult(
          hasConflict: false,
          type: ConflictType.none,
          resolution: ConflictResolution.useLocal,
        );

      case ClockComparison.concurrent:
        // 并发修改，存在冲突
        final conflictType = _determineConflictType(localData, remoteData);
        return ConflictResult(
          hasConflict: true,
          type: conflictType,
          localData: localData,
          remoteData: remoteData,
          localClock: localClock,
          remoteClock: remoteClock,
        );
    }
  }

  /// 确定冲突类型
  ConflictType _determineConflictType(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
  ) {
    // 检查是否是删除冲突
    final localDeleted = localData['deleted'] == true;
    final remoteDeleted = remoteData['deleted'] == true;

    if (localDeleted && !remoteDeleted) {
      return ConflictType.deleteUpdate;
    }
    if (!localDeleted && remoteDeleted) {
      return ConflictType.updateDelete;
    }
    if (localDeleted && remoteDeleted) {
      return ConflictType.deleteDelete;
    }

    // 检查修改的字段
    final localModified = _getModifiedFields(localData);
    final remoteModified = _getModifiedFields(remoteData);

    final overlapping = localModified.intersection(remoteModified);

    if (overlapping.isEmpty) {
      // 修改不同字段，可以自动合并
      return ConflictType.mergeable;
    }

    // 修改相同字段，需要用户选择
    return ConflictType.fieldConflict;
  }

  /// 获取修改的字段
  Set<String> _getModifiedFields(Map<String, dynamic> data) {
    // 假设有一个原始数据对比
    // 实际实现需要与原始数据进行对比
    return data.keys.toSet();
  }

  /// 自动解决冲突
  Future<Map<String, dynamic>> autoResolveConflict(
    ConflictResult conflict,
    ConflictResolutionStrategy strategy,
  ) async {
    switch (strategy) {
      case ConflictResolutionStrategy.localWins:
        return conflict.localData!;

      case ConflictResolutionStrategy.remoteWins:
        return conflict.remoteData!;

      case ConflictResolutionStrategy.latestWins:
        // 比较更新时间
        final localUpdated = DateTime.parse(
            conflict.localData!['updated_at'] as String);
        final remoteUpdated = DateTime.parse(
            conflict.remoteData!['updated_at'] as String);
        return localUpdated.isAfter(remoteUpdated)
            ? conflict.localData!
            : conflict.remoteData!;

      case ConflictResolutionStrategy.merge:
        return _mergeData(conflict.localData!, conflict.remoteData!);

      case ConflictResolutionStrategy.manual:
        // 需要用户手动解决
        throw ConflictException('Manual resolution required');
    }
  }

  /// 合并数据（非冲突字段自动合并）
  Map<String, dynamic> _mergeData(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = Map<String, dynamic>.from(remote);

    // 对于每个本地字段，如果远程没有或相同，使用本地值
    for (final entry in local.entries) {
      if (!merged.containsKey(entry.key) ||
          merged[entry.key] == null) {
        merged[entry.key] = entry.value;
      }
    }

    return merged;
  }

  /// 解决冲突（使用指定解决方案）
  Future<void> resolveConflict({
    required String entityType,
    required String entityId,
    required ConflictResolution resolution,
    required Map<String, dynamic> resolvedData,
    required VectorClock mergedClock,
  }) async {
    final db = await _db.database;

    // 更新本地数据
    await db.update(
      entityType,
      {
        ...resolvedData,
        'vector_clock': jsonEncode(mergedClock.toMap()),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [entityId],
    );

    // 记录冲突解决日志
    await db.insert('conflict_logs', {
      'entity_type': entityType,
      'entity_id': entityId,
      'resolution': resolution.name,
      'resolved_at': DateTime.now().toIso8601String(),
    });

    debugPrint('Conflict resolved for $entityType:$entityId using $resolution');
  }

  /// 获取冲突历史
  Future<List<ConflictLog>> getConflictHistory({
    String? entityType,
    int limit = 50,
  }) async {
    final db = await _db.database;

    String? where;
    List<dynamic>? whereArgs;

    if (entityType != null) {
      where = 'entity_type = ?';
      whereArgs = [entityType];
    }

    final results = await db.query(
      'conflict_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'resolved_at DESC',
      limit: limit,
    );

    return results.map((r) => ConflictLog.fromMap(r)).toList();
  }

  /// 发送冲突通知
  void notifyConflict(ConflictEvent event) {
    _conflictController.add(event);
  }

  /// 释放资源
  void dispose() {
    _conflictController.close();
  }
}

/// 冲突结果
class ConflictResult {
  final bool hasConflict;
  final ConflictType type;
  final ConflictResolution? resolution;
  final Map<String, dynamic>? localData;
  final Map<String, dynamic>? remoteData;
  final VectorClock? localClock;
  final VectorClock? remoteClock;

  const ConflictResult({
    required this.hasConflict,
    required this.type,
    this.resolution,
    this.localData,
    this.remoteData,
    this.localClock,
    this.remoteClock,
  });
}

/// 冲突类型
enum ConflictType {
  /// 无冲突
  none,

  /// 可自动合并（修改不同字段）
  mergeable,

  /// 字段冲突（修改相同字段）
  fieldConflict,

  /// 本地删除，远程更新
  deleteUpdate,

  /// 本地更新，远程删除
  updateDelete,

  /// 双方都删除
  deleteDelete,
}

/// 冲突解决方式
enum ConflictResolution {
  useLocal,
  useRemote,
  merge,
  manual,
}

/// 冲突解决策略
enum ConflictResolutionStrategy {
  /// 本地优先
  localWins,

  /// 远程优先
  remoteWins,

  /// 最新优先
  latestWins,

  /// 自动合并
  merge,

  /// 手动解决
  manual,
}

/// 冲突事件
class ConflictEvent {
  final String entityType;
  final String entityId;
  final ConflictResult conflict;
  final DateTime occurredAt;

  const ConflictEvent({
    required this.entityType,
    required this.entityId,
    required this.conflict,
    required this.occurredAt,
  });
}

/// 冲突日志
class ConflictLog {
  final String entityType;
  final String entityId;
  final ConflictResolution resolution;
  final DateTime resolvedAt;

  const ConflictLog({
    required this.entityType,
    required this.entityId,
    required this.resolution,
    required this.resolvedAt,
  });

  factory ConflictLog.fromMap(Map<String, dynamic> map) {
    return ConflictLog(
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      resolution: ConflictResolution.values.firstWhere(
        (e) => e.name == map['resolution'],
      ),
      resolvedAt: DateTime.parse(map['resolved_at'] as String),
    );
  }
}

/// 冲突异常
class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);

  @override
  String toString() => 'ConflictException: $message';
}
