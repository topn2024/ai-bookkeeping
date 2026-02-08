import 'dart:async';
import '../models/sync_record.dart';

/// 家庭账本同步服务
class FamilyLedgerSyncService {
  static final FamilyLedgerSyncService _instance =
      FamilyLedgerSyncService._internal();
  factory FamilyLedgerSyncService() => _instance;
  FamilyLedgerSyncService._internal();

  // 待同步队列
  final List<SyncRecord> _pendingQueue = [];
  // 同步状态流
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  // 是否正在同步
  bool _isSyncing = false;

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingQueue.length;

  /// 添加同步记录
  void enqueue(SyncRecord record) {
    _pendingQueue.add(record);
  }

  /// 开始同步
  Future<void> startSync(String ledgerId) async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      final records = _pendingQueue
          .where((r) => r.ledgerId == ledgerId)
          .toList();

      for (final record in records) {
        await _syncRecord(record);
      }

      _syncStatusController.add(SyncStatus.synced);
    } catch (e) {
      _syncStatusController.add(SyncStatus.failed);
    } finally {
      _isSyncing = false;
    }
  }

  /// 同步单条记录
  Future<void> _syncRecord(SyncRecord record) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 100));

    // 移除已同步的记录
    _pendingQueue.removeWhere((r) => r.id == record.id);
  }

  /// 获取待同步记录
  List<SyncRecord> getPendingRecords(String ledgerId) {
    return _pendingQueue
        .where((r) => r.ledgerId == ledgerId)
        .toList();
  }

  /// 清除队列
  void clearQueue(String ledgerId) {
    _pendingQueue.removeWhere((r) => r.ledgerId == ledgerId);
  }

  /// 释放资源
  void dispose() {
    _syncStatusController.close();
  }
}
