import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sync.dart';
import '../services/sync_service.dart';

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
    );
  }

  bool get canSync {
    if (!isOnline) return false;
    if (settings.wifiOnly && !isWifi) return false;
    if (status == SyncStatus.syncing) return false;
    return true;
  }

  int get pendingConflicts => conflicts.where((c) => !c.isResolved).length;

  String get lastSyncText {
    if (settings.lastSyncTime == null) return '从未同步';
    final diff = DateTime.now().difference(settings.lastSyncTime!);
    if (diff.inMinutes < 1) return '刚刚同步';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}

class SyncNotifier extends Notifier<SyncState> {
  final SyncManager _syncManager = SyncManager();

  @override
  SyncState build() {
    _initialize();
    return const SyncState();
  }

  Future<void> _initialize() async {
    await _syncManager.initialize();
    await _checkConnectivity();
    await _loadBackups();

    state = state.copyWith(
      settings: _syncManager.settings,
      history: _syncManager.history,
      conflicts: _syncManager.conflicts,
    );

    // 监听网络变化
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectivity(result);
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
      sync();
    }
  }

  /// 更新设置
  Future<void> updateSettings(SyncSettings settings) async {
    await _syncManager.updateSettings(settings);
    state = state.copyWith(settings: settings);
  }

  /// 执行同步
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
