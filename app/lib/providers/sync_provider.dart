import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sync.dart';
import '../services/sync_service.dart';
import '../services/server_sync_service.dart';
import '../services/data_cleanup_service.dart';
import '../services/offline_queue_service.dart';
import '../services/database_service.dart';

/// 同步状态
class SyncState {
  final SyncStatus status;
  final SyncSettings settings;
  final List<SyncRecord> history;
  final List<SyncConflict> conflicts;
  final List<BackupData> backups;
  final bool isOnline;
  final bool isWifi;
  final String? errorMessage;
  final double? progress;
  final String? progressMessage;

  // 服务器同步统计
  final ServerSyncStats? serverSyncStats;
  final CleanupSettings cleanupSettings;
  final CleanupPreview? cleanupPreview;

  const SyncState({
    this.status = SyncStatus.idle,
    this.settings = const SyncSettings(),
    this.history = const [],
    this.conflicts = const [],
    this.backups = const [],
    this.isOnline = true,
    this.isWifi = false,
    this.errorMessage,
    this.progress,
    this.progressMessage,
    this.serverSyncStats,
    this.cleanupSettings = const CleanupSettings(),
    this.cleanupPreview,
  });

  SyncState copyWith({
    SyncStatus? status,
    SyncSettings? settings,
    List<SyncRecord>? history,
    List<SyncConflict>? conflicts,
    List<BackupData>? backups,
    bool? isOnline,
    bool? isWifi,
    String? errorMessage,
    double? progress,
    String? progressMessage,
    ServerSyncStats? serverSyncStats,
    CleanupSettings? cleanupSettings,
    CleanupPreview? cleanupPreview,
  }) {
    return SyncState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      history: history ?? this.history,
      conflicts: conflicts ?? this.conflicts,
      backups: backups ?? this.backups,
      isOnline: isOnline ?? this.isOnline,
      isWifi: isWifi ?? this.isWifi,
      errorMessage: errorMessage,
      progress: progress,
      progressMessage: progressMessage,
      serverSyncStats: serverSyncStats ?? this.serverSyncStats,
      cleanupSettings: cleanupSettings ?? this.cleanupSettings,
      cleanupPreview: cleanupPreview ?? this.cleanupPreview,
    );
  }

  bool get canSync {
    if (!isOnline) return false;
    if (settings.wifiOnly && !isWifi) return false;
    if (status == SyncStatus.syncing) return false;
    return true;
  }

  int get pendingConflicts => conflicts.where((c) => !c.isResolved).length;

  int get pendingSyncCount => serverSyncStats?.pending ?? 0;
  int get syncedCount => serverSyncStats?.synced ?? 0;
  int get queuedCount => serverSyncStats?.queued ?? 0;

  String get lastSyncText {
    if (settings.lastSyncTime == null) return '从未同步';
    final diff = DateTime.now().difference(settings.lastSyncTime!);
    if (diff.inMinutes < 1) return '刚刚同步';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  String get syncSummary {
    if (serverSyncStats == null) return '';
    final stats = serverSyncStats!;
    if (stats.pending > 0) {
      return '${stats.pending}条待同步';
    }
    if (stats.synced > 0) {
      return '${stats.synced}条已同步';
    }
    return '暂无数据';
  }
}

class SyncNotifier extends Notifier<SyncState> {
  final SyncManager _syncManager = SyncManager();
  final ServerSyncService _serverSync = ServerSyncService();
  final DataCleanupService _cleanupService = DataCleanupService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();
  final DatabaseService _db = DatabaseService();

  StreamSubscription<SyncProgress>? _progressSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  SyncState build() {
    _initialize();
    return const SyncState();
  }

  Future<void> _initialize() async {
    await _syncManager.initialize();
    await _offlineQueue.initialize();
    await _checkConnectivity();
    await _loadBackups();
    await _loadServerSyncStats();

    state = state.copyWith(
      settings: _syncManager.settings,
      history: _syncManager.history,
      conflicts: _syncManager.conflicts,
    );

    // 监听网络变化
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // 监听同步进度
    _progressSubscription = _serverSync.progressStream.listen(_onSyncProgress);
  }

  Future<void> _loadServerSyncStats() async {
    try {
      final stats = await _db.getSyncStatistics();
      state = state.copyWith(
        serverSyncStats: ServerSyncStats(
          pending: stats['pending'] ?? 0,
          synced: stats['synced'] ?? 0,
          failed: stats['failed'] ?? 0,
          queued: stats['queue'] ?? 0,
        ),
      );
    } catch (e) {
      // Ignore errors during stats loading
    }
  }

  void _onSyncProgress(SyncProgress progress) {
    state = state.copyWith(
      progress: progress.progress,
      progressMessage: progress.message,
    );
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (result.isNotEmpty) {
      _updateConnectivity(result.first);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.isNotEmpty) {
      _updateConnectivity(results.first);
    }
  }

  void _updateConnectivity(ConnectivityResult result) {
    final isOnline = result != ConnectivityResult.none;
    final isWifi = result == ConnectivityResult.wifi;

    state = state.copyWith(
      isOnline: isOnline,
      isWifi: isWifi,
      status: isOnline ? state.status : SyncStatus.offline,
    );

    // 如果重新上线且设置了自动同步，触发同步
    if (isOnline &&
        state.settings.enabled &&
        state.settings.frequency != SyncFrequency.manual) {
      syncToServer();
    }
  }

  /// 更新设置
  Future<void> updateSettings(SyncSettings settings) async {
    await _syncManager.updateSettings(settings);
    state = state.copyWith(settings: settings);
  }

  /// 更新清理设置
  Future<void> updateCleanupSettings(CleanupSettings settings) async {
    state = state.copyWith(cleanupSettings: settings);
  }

  /// 执行本地同步（原有逻辑）
  Future<SyncRecord?> sync({SyncDirection direction = SyncDirection.bidirectional}) async {
    if (!state.canSync) {
      state = state.copyWith(
        errorMessage: state.isOnline
            ? (state.settings.wifiOnly ? '请连接WiFi后再同步' : '正在同步中')
            : '无网络连接',
      );
      return null;
    }

    state = state.copyWith(
      status: SyncStatus.syncing,
      progress: 0,
      errorMessage: null,
    );

    try {
      // 模拟进度
      for (var i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        state = state.copyWith(progress: i / 10);
      }

      final record = await _syncManager.sync(direction: direction);

      state = state.copyWith(
        status: record.status,
        history: _syncManager.history,
        settings: _syncManager.settings,
        progress: null,
      );

      // 刷新备份列表
      await _loadBackups();

      return record;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.failed,
        errorMessage: e.toString(),
        progress: null,
      );
      return null;
    }
  }

  /// 同步到服务器（新增）
  Future<SyncResult?> syncToServer() async {
    if (!state.canSync) {
      state = state.copyWith(
        errorMessage: state.isOnline
            ? (state.settings.wifiOnly ? '请连接WiFi后再同步' : '正在同步中')
            : '无网络连接',
      );
      return null;
    }

    state = state.copyWith(
      status: SyncStatus.syncing,
      progress: 0,
      progressMessage: '准备同步...',
      errorMessage: null,
    );

    try {
      final result = await _serverSync.performSync();

      // 更新统计
      await _loadServerSyncStats();

      // 根据结果更新状态
      if (result.success) {
        // 更新最后同步时间
        final newSettings = state.settings.copyWith(
          lastSyncTime: DateTime.now(),
        );
        await updateSettings(newSettings);

        state = state.copyWith(
          status: SyncStatus.success,
          progress: null,
          progressMessage: null,
        );

        // 同步成功后检查是否需要清理
        if (state.cleanupSettings.autoCleanup) {
          await checkAndPerformCleanup();
        }
      } else {
        state = state.copyWith(
          status: result.conflicts.isEmpty ? SyncStatus.failed : SyncStatus.hasConflicts,
          errorMessage: result.errorMessage,
          progress: null,
          progressMessage: null,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.failed,
        errorMessage: e.toString(),
        progress: null,
        progressMessage: null,
      );
      return null;
    }
  }

  /// 检查并执行清理
  Future<void> checkAndPerformCleanup() async {
    if (!state.cleanupSettings.autoCleanup) return;

    try {
      final preview = await _cleanupService.getCleanupPreview();

      if (preview.totalCount > 0) {
        state = state.copyWith(cleanupPreview: preview);

        // 自动清理
        await _cleanupService.performCleanup();

        // 清理后刷新统计
        await _loadServerSyncStats();
      }
    } catch (e) {
      // 清理失败不影响主流程
    }
  }

  /// 获取清理预览
  Future<CleanupPreview> getCleanupPreview() async {
    final preview = await _cleanupService.getCleanupPreview();
    state = state.copyWith(cleanupPreview: preview);
    return preview;
  }

  /// 执行数据清理
  Future<CleanupResult> performCleanup() async {
    state = state.copyWith(
      status: SyncStatus.syncing,
      progressMessage: '正在清理数据...',
    );

    try {
      final result = await _cleanupService.performCleanup();

      await _loadServerSyncStats();

      state = state.copyWith(
        status: SyncStatus.success,
        progressMessage: null,
        cleanupPreview: null,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.failed,
        errorMessage: e.toString(),
        progressMessage: null,
      );
      rethrow;
    }
  }

  /// 创建备份
  Future<BackupData?> createBackup() async {
    state = state.copyWith(status: SyncStatus.syncing);

    try {
      final backup = await _syncManager.createBackup();
      await _loadBackups();

      state = state.copyWith(status: SyncStatus.success);
      return backup;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.failed,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// 加载备份列表
  Future<void> _loadBackups() async {
    final backups = await _syncManager.listBackups();
    state = state.copyWith(backups: backups);
  }

  /// 刷新备份列表
  Future<void> refreshBackups() async {
    await _loadBackups();
  }

  /// 刷新同步统计
  Future<void> refreshStats() async {
    await _loadServerSyncStats();
  }

  /// 恢复备份
  Future<bool> restoreBackup(String backupId, {bool merge = false}) async {
    state = state.copyWith(status: SyncStatus.syncing);

    try {
      final success = await _syncManager.restoreBackup(backupId, merge: merge);

      state = state.copyWith(
        status: success ? SyncStatus.success : SyncStatus.failed,
        errorMessage: success ? null : '恢复失败',
      );

      return success;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.failed,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// 删除备份
  Future<bool> deleteBackup(String backupId) async {
    try {
      final success = await _syncManager.deleteBackup(backupId);
      if (success) {
        await _loadBackups();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 解决冲突
  Future<void> resolveConflict(String conflictId, ConflictResolution resolution) async {
    await _syncManager.resolveConflict(conflictId, resolution);
    state = state.copyWith(conflicts: _syncManager.conflicts);
  }

  /// 解决所有冲突
  Future<void> resolveAllConflicts(ConflictResolution resolution) async {
    for (final conflict in state.conflicts.where((c) => !c.isResolved)) {
      await resolveConflict(conflict.id, resolution);
    }
  }

  /// 重试失败的队列项
  Future<int> retryFailedItems() async {
    final count = await _offlineQueue.retryFailedItems();
    if (count > 0 && state.isOnline) {
      await _offlineQueue.processQueue();
    }
    await _loadServerSyncStats();
    return count;
  }

  /// 清空同步队列
  Future<void> clearQueue() async {
    await _offlineQueue.clearQueue();
    await _loadServerSyncStats();
  }

  /// 释放资源
  void dispose() {
    _progressSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _offlineQueue.dispose();
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

/// 同步状态图标 Provider
final syncStatusIconProvider = Provider<SyncStatus>((ref) {
  return ref.watch(syncProvider).status;
});

/// 待处理冲突数量
final pendingConflictsProvider = Provider<int>((ref) {
  return ref.watch(syncProvider).pendingConflicts;
});

/// 备份列表
final backupListProvider = Provider<List<BackupData>>((ref) {
  return ref.watch(syncProvider).backups;
});

/// 是否可以同步
final canSyncProvider = Provider<bool>((ref) {
  return ref.watch(syncProvider).canSync;
});

/// 上次同步时间文本
final lastSyncTextProvider = Provider<String>((ref) {
  return ref.watch(syncProvider).lastSyncText;
});

/// 待同步数量
final pendingSyncCountProvider = Provider<int>((ref) {
  return ref.watch(syncProvider).pendingSyncCount;
});

/// 已同步数量
final syncedCountProvider = Provider<int>((ref) {
  return ref.watch(syncProvider).syncedCount;
});

/// 同步摘要
final syncSummaryProvider = Provider<String>((ref) {
  return ref.watch(syncProvider).syncSummary;
});

/// 清理预览
final cleanupPreviewProvider = Provider<CleanupPreview?>((ref) {
  return ref.watch(syncProvider).cleanupPreview;
});
