import 'dart:async';
import 'package:uuid/uuid.dart';
import 'database_service.dart';
import 'http_service.dart';
import 'data_mapper_service.dart';
import '../core/logger.dart';

/// Sync status constants
class SyncStatus {
  static const int pending = 0;
  static const int synced = 1;
  static const int conflict = 2;
  static const int failed = 3;
}

/// Queue status constants
class QueueStatus {
  static const int pending = 0;
  static const int processing = 1;
  static const int completed = 2;
  static const int failed = 3;
}

/// Sync progress information
class SyncProgress {
  final SyncPhase phase;
  final int totalItems;
  final int processedItems;
  final String? currentEntity;
  final String? message;

  SyncProgress({
    required this.phase,
    this.totalItems = 0,
    this.processedItems = 0,
    this.currentEntity,
    this.message,
  });

  double get progress {
    if (totalItems == 0) return 0;
    return processedItems / totalItems;
  }
}

enum SyncPhase {
  preparing,
  uploading,
  downloading,
  applying,
  cleanup,
  completed,
  failed,
}

/// Sync result summary
class SyncResult {
  final bool success;
  final int uploaded;
  final int downloaded;
  final int conflicts;
  final int errors;
  final String? errorMessage;
  final DateTime syncTime;

  SyncResult({
    required this.success,
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
    this.errors = 0,
    this.errorMessage,
    DateTime? syncTime,
  }) : syncTime = syncTime ?? DateTime.now();
}

/// Server sync service - handles data synchronization with the server
class ServerSyncService {
  static final ServerSyncService _instance = ServerSyncService._internal();

  final DatabaseService _db = DatabaseService();
  final HttpService _http = HttpService();
  final DataMapperService _mapper = DataMapperService();
  final _uuid = const Uuid();
  final Logger _logger = Logger();

  final _progressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get progressStream => _progressController.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  factory ServerSyncService() => _instance;
  ServerSyncService._internal();

  /// Perform full sync with server
  Future<SyncResult> performSync() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        errorMessage: '同步正在进行中',
      );
    }

    _isSyncing = true;
    int uploaded = 0;
    int downloaded = 0;
    int conflicts = 0;
    int errors = 0;

    try {
      _emitProgress(SyncPhase.preparing, message: '准备同步...');

      // Step 1: Get pending local changes
      final pendingChanges = await _getPendingChanges();
      final totalItems = pendingChanges.length;

      // Step 2: Upload local changes (Push)
      if (pendingChanges.isNotEmpty) {
        _emitProgress(
          SyncPhase.uploading,
          totalItems: totalItems,
          message: '上传本地更改...',
        );

        final pushResult = await _pushChanges(pendingChanges);
        uploaded = pushResult['uploaded'] as int? ?? 0;
        conflicts = pushResult['conflicts'] as int? ?? 0;
        errors = pushResult['errors'] as int? ?? 0;
      }

      // Step 3: Download server changes (Pull)
      _emitProgress(SyncPhase.downloading, message: '下载服务器更改...');
      final pullResult = await _pullChanges();
      downloaded = pullResult['downloaded'] as int? ?? 0;

      // Step 4: Apply downloaded changes
      if (downloaded > 0) {
        _emitProgress(SyncPhase.applying, message: '应用服务器更改...');
        await _applyServerChanges(pullResult['changes'] as Map<String, dynamic>? ?? {});
      }

      _emitProgress(SyncPhase.completed, message: '同步完成');

      return SyncResult(
        success: true,
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: conflicts,
        errors: errors,
      );
    } catch (e) {
      _emitProgress(SyncPhase.failed, message: '同步失败: $e');
      return SyncResult(
        success: false,
        uploaded: uploaded,
        downloaded: downloaded,
        conflicts: conflicts,
        errors: errors + 1,
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Get all pending changes that need to be synced
  Future<List<Map<String, dynamic>>> _getPendingChanges() async {
    final changes = <Map<String, dynamic>>[];

    // Get from sync_metadata table
    final pendingMetadata = await _db.getPendingSyncMetadata();

    for (final meta in pendingMetadata) {
      final entityType = meta['entityType'] as String;
      final localId = meta['localId'] as String;
      final serverId = meta['serverId'] as String?;
      final isDeleted = (meta['isDeleted'] as int?) == 1;

      // Determine operation
      String operation;
      if (isDeleted) {
        operation = 'delete';
      } else if (serverId == null) {
        operation = 'create';
      } else {
        operation = 'update';
      }

      // Get entity data
      Map<String, dynamic>? data;
      if (!isDeleted) {
        data = await _getEntityData(entityType, localId);
      }

      changes.add({
        'entity_type': entityType,
        'operation': operation,
        'local_id': localId,
        'server_id': serverId,
        'data': data ?? {},
        'local_updated_at': DateTime.fromMillisecondsSinceEpoch(
          meta['localUpdatedAt'] as int,
        ).toIso8601String(),
      });
    }

    return changes;
  }

  /// Get entity data for sync
  Future<Map<String, dynamic>?> _getEntityData(String entityType, String localId) async {
    switch (entityType) {
      case 'transaction':
        final transactions = await _db.getTransactions();
        final tx = transactions.where((t) => t.id == localId).firstOrNull;
        if (tx != null) {
          return await _mapper.transactionToServer(tx);
        }
        break;
      case 'account':
        final accounts = await _db.getAccounts();
        final account = accounts.where((a) => a.id == localId).firstOrNull;
        if (account != null) {
          return _mapper.accountToServer(account);
        }
        break;
      case 'category':
        final categories = await _db.getCategories();
        final category = categories.where((c) => c.id == localId).firstOrNull;
        if (category != null) {
          return await _mapper.categoryToServer(category);
        }
        break;
      case 'book':
        final ledgers = await _db.getLedgers();
        final ledger = ledgers.where((l) => l.id == localId).firstOrNull;
        if (ledger != null) {
          return _mapper.ledgerToServer(ledger);
        }
        break;
      case 'budget':
        final budgets = await _db.getBudgets();
        final budget = budgets.where((b) => b.id == localId).firstOrNull;
        if (budget != null) {
          return await _mapper.budgetToServer(budget);
        }
        break;
      default:
        _logger.warning('Unknown entity type in _getEntityData: $entityType');
    }
    return null;
  }

  /// Push local changes to server
  Future<Map<String, dynamic>> _pushChanges(List<Map<String, dynamic>> changes) async {
    int uploaded = 0;
    int conflicts = 0;
    int errors = 0;

    try {
      // Sort changes by dependency order
      final orderedChanges = _sortByDependencyOrder(changes);

      final response = await _http.post('/sync/push', data: {
        'changes': orderedChanges,
        'client_version': '1.0.0',
        'device_id': await _getDeviceId(),
      });

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final accepted = data['accepted'] as List<dynamic>? ?? [];
        final conflictsList = data['conflicts'] as List<dynamic>? ?? [];

        // Update local sync metadata for accepted changes
        for (final result in accepted) {
          final localId = result['local_id'] as String;
          final serverId = result['server_id'] as String;
          final entityType = result['entity_type'] as String;
          final success = result['success'] as bool? ?? false;

          if (success) {
            // Update sync metadata
            await _db.updateSyncStatus(
              entityType,
              localId,
              syncStatus: SyncStatus.synced,
              serverId: serverId,
              lastSyncAt: DateTime.now().millisecondsSinceEpoch,
            );

            // Update ID mapping
            await _db.insertIdMapping(
              entityType: entityType,
              localId: localId,
              serverId: serverId,
            );

            uploaded++;
          } else {
            errors++;
          }
        }

        conflicts = conflictsList.length;

        // Handle conflicts - Local-first strategy: mark as synced
        for (final conflict in conflictsList) {
          // In local-first mode, we push again with force
          final localId = conflict['local_id'] as String;
          final entityType = conflict['entity_type'] as String;

          await _db.updateSyncStatus(
            entityType,
            localId,
            syncStatus: SyncStatus.conflict,
          );
        }
      }
    } catch (e) {
      errors++;
      rethrow;
    }

    return {
      'uploaded': uploaded,
      'conflicts': conflicts,
      'errors': errors,
    };
  }

  /// Pull changes from server
  Future<Map<String, dynamic>> _pullChanges() async {
    int downloaded = 0;
    Map<String, dynamic> changes = {};

    try {
      // Get last sync times per entity type
      final lastSyncTimes = await _getLastSyncTimes();

      final response = await _http.post('/sync/pull', data: {
        'last_sync_times': lastSyncTimes,
        'device_id': await _getDeviceId(),
        'include_deleted': true,
      });

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        changes = data['changes'] as Map<String, dynamic>? ?? {};

        // Count downloaded items
        for (final entityChanges in changes.values) {
          if (entityChanges is List) {
            downloaded += entityChanges.length;
          }
        }
      }
    } catch (e) {
      // On error, return empty changes
      changes = {};
    }

    return {
      'downloaded': downloaded,
      'changes': changes,
    };
  }

  /// Apply server changes to local database
  Future<void> _applyServerChanges(Map<String, dynamic> changes) async {
    // Apply in dependency order
    final orderedTypes = ['category', 'book', 'account', 'budget', 'transaction'];

    for (final entityType in orderedTypes) {
      final entityChanges = changes[entityType] as List<dynamic>?;
      if (entityChanges == null || entityChanges.isEmpty) continue;

      for (final change in entityChanges) {
        await _applyServerChange(entityType, change as Map<String, dynamic>);
      }
    }
  }

  /// Apply a single server change
  Future<void> _applyServerChange(String entityType, Map<String, dynamic> change) async {
    final serverId = change['id'] as String;
    final operation = change['operation'] as String;
    final data = change['data'] as Map<String, dynamic>;
    final isDeleted = change['is_deleted'] as bool? ?? false;

    // Check if we already have this entity locally
    String? localId = await _db.getLocalIdByServerId(entityType, serverId);

    if (isDeleted || operation == 'delete') {
      // Delete locally if exists
      if (localId != null) {
        await _deleteLocalEntity(entityType, localId);
        await _db.deleteSyncMetadata(entityType, localId);
        await _db.deleteIdMapping(entityType, localId);
      }
      return;
    }

    if (localId == null) {
      // Create new local entity
      localId = _uuid.v4();
      await _createLocalEntity(entityType, localId, data);

      // Create ID mapping
      await _db.insertIdMapping(
        entityType: entityType,
        localId: localId,
        serverId: serverId,
      );
    } else {
      // Check if local version is newer (local-first)
      final syncMeta = await _db.getSyncMetadata(entityType, localId);
      if (syncMeta != null) {
        final localUpdatedAt = syncMeta['localUpdatedAt'] as int;
        final serverUpdatedAt = DateTime.parse(change['updated_at'] as String).millisecondsSinceEpoch;

        // Local-first: only apply if server is newer AND local is already synced
        if (syncMeta['syncStatus'] == SyncStatus.synced && serverUpdatedAt > localUpdatedAt) {
          await _updateLocalEntity(entityType, localId, data);
        }
      }
    }

    // Update sync metadata
    await _db.upsertSyncMetadata(
      entityType: entityType,
      localId: localId,
      serverId: serverId,
      syncStatus: SyncStatus.synced,
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      serverUpdatedAt: DateTime.parse(change['updated_at'] as String).millisecondsSinceEpoch,
      lastSyncAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Create a local entity from server data
  Future<void> _createLocalEntity(String entityType, String localId, Map<String, dynamic> data) async {
    switch (entityType) {
      case 'transaction':
        final tx = _mapper.transactionFromServer(data, localId);
        await _db.insertTransaction(tx);
        break;
      case 'account':
        final account = _mapper.accountFromServer(data, localId);
        await _db.insertAccount(account);
        break;
      case 'category':
        final category = _mapper.categoryFromServer(data, localId);
        await _db.insertCategory(category);
        break;
      case 'book':
        final ledger = _mapper.ledgerFromServer(data, localId);
        await _db.insertLedger(ledger);
        break;
      case 'budget':
        final budget = _mapper.budgetFromServer(data, localId);
        await _db.insertBudget(budget);
        break;
      default:
        _logger.warning('Unknown entity type in _createLocalEntity: $entityType');
    }
  }

  /// Update a local entity with server data
  Future<void> _updateLocalEntity(String entityType, String localId, Map<String, dynamic> data) async {
    switch (entityType) {
      case 'transaction':
        final tx = _mapper.transactionFromServer(data, localId);
        await _db.updateTransaction(tx);
        break;
      case 'account':
        final account = _mapper.accountFromServer(data, localId);
        await _db.updateAccount(account);
        break;
      case 'category':
        final category = _mapper.categoryFromServer(data, localId);
        await _db.updateCategory(category);
        break;
      case 'book':
        final ledger = _mapper.ledgerFromServer(data, localId);
        await _db.updateLedger(ledger);
        break;
      case 'budget':
        final budget = _mapper.budgetFromServer(data, localId);
        await _db.updateBudget(budget);
        break;
      default:
        _logger.warning('Unknown entity type in _updateLocalEntity: $entityType');
    }
  }

  /// Delete a local entity
  Future<void> _deleteLocalEntity(String entityType, String localId) async {
    switch (entityType) {
      case 'transaction':
        await _db.deleteTransaction(localId);
        break;
      case 'account':
        await _db.deleteAccount(localId);
        break;
      case 'category':
        await _db.deleteCategory(localId);
        break;
      case 'book':
        await _db.deleteLedger(localId);
        break;
      case 'budget':
        await _db.deleteBudget(localId);
        break;
      default:
        _logger.warning('Unknown entity type in _deleteLocalEntity: $entityType');
    }
  }

  /// Sort changes by dependency order for upload
  List<Map<String, dynamic>> _sortByDependencyOrder(List<Map<String, dynamic>> changes) {
    final order = ['book', 'account', 'category', 'budget', 'transaction'];

    return List.from(changes)..sort((a, b) {
      final aIndex = order.indexOf(a['entity_type'] as String);
      final bIndex = order.indexOf(b['entity_type'] as String);
      return aIndex.compareTo(bIndex);
    });
  }

  /// Get last sync times per entity type
  Future<Map<String, String>> _getLastSyncTimes() async {
    final result = <String, String>{};
    final entityTypes = ['transaction', 'account', 'category', 'book', 'budget'];

    for (final entityType in entityTypes) {
      final lastSync = await _db.getLastSyncTime();
      if (lastSync != null) {
        result[entityType] = lastSync.toIso8601String();
      }
    }

    return result;
  }

  /// Get or generate device ID
  Future<String> _getDeviceId() async {
    // In a real app, this would be stored persistently
    return 'flutter_app_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Emit sync progress
  void _emitProgress(
    SyncPhase phase, {
    int totalItems = 0,
    int processedItems = 0,
    String? currentEntity,
    String? message,
  }) {
    _progressController.add(SyncProgress(
      phase: phase,
      totalItems: totalItems,
      processedItems: processedItems,
      currentEntity: currentEntity,
      message: message,
    ));
  }

  /// Mark entity for sync
  Future<void> markForSync(String entityType, String localId, String operation) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get existing metadata
    final existing = await _db.getSyncMetadata(entityType, localId);

    if (operation == 'delete') {
      if (existing != null) {
        await _db.upsertSyncMetadata(
          entityType: entityType,
          localId: localId,
          serverId: existing['serverId'] as String?,
          syncStatus: SyncStatus.pending,
          localUpdatedAt: now,
          isDeleted: true,
        );
      }
    } else {
      await _db.upsertSyncMetadata(
        entityType: entityType,
        localId: localId,
        serverId: existing?['serverId'] as String?,
        syncStatus: SyncStatus.pending,
        localUpdatedAt: now,
        version: ((existing?['version'] as int?) ?? 0) + 1,
      );
    }
  }

  /// Get sync status
  Future<Map<String, int>> getSyncStatus() async {
    return await _db.getSyncStatistics();
  }

  /// Check if sync is needed
  Future<bool> isSyncNeeded() async {
    final stats = await getSyncStatus();
    return (stats['pending'] ?? 0) > 0 || (stats['queue'] ?? 0) > 0;
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}
