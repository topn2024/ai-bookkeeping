import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'http_service.dart';
import 'data_mapper_service.dart';

/// Queue operation types
class QueueOperation {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

/// Queue item status
class QueueStatus {
  static const int pending = 0;
  static const int processing = 1;
  static const int completed = 2;
  static const int failed = 3;
}

/// Retry configuration
class RetryConfig {
  final int maxRetries;
  final Duration baseDelay;
  final double backoffMultiplier;

  const RetryConfig({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 2),
    this.backoffMultiplier = 2.0,
  });

  Duration getDelay(int attempt) {
    return baseDelay * (backoffMultiplier * attempt);
  }
}

/// Offline queue service - manages sync operations when offline
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();

  final DatabaseService _db = DatabaseService();
  final HttpService _http = HttpService();
  final DataMapperService _mapper = DataMapperService();
  final Connectivity _connectivity = Connectivity();
  final RetryConfig _retryConfig;
  final _uuid = const Uuid();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;
  bool _isOnline = true;

  factory OfflineQueueService({RetryConfig? retryConfig}) {
    if (retryConfig != null) {
      return OfflineQueueService._withConfig(retryConfig);
    }
    return _instance;
  }

  OfflineQueueService._internal() : _retryConfig = const RetryConfig();
  OfflineQueueService._withConfig(this._retryConfig);

  /// Initialize and start listening for connectivity changes
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Process any pending items if online
    if (_isOnline) {
      await processQueue();
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);

    // If we just came online, process the queue
    if (_isOnline && !wasOnline) {
      await processQueue();
    }
  }

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Add operation to queue
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required dynamic entity,
  }) async {
    final id = _uuid.v4();

    // Serialize entity data
    String payload;
    if (operation == QueueOperation.delete) {
      payload = jsonEncode({'id': entityId});
    } else {
      payload = await _mapper.serializeEntity(entityType, entity);
    }

    await _db.enqueueSyncOperation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );

    // Try to process immediately if online
    if (_isOnline && !_isProcessing) {
      await processQueue();
    }
  }

  /// Process all pending queue items
  Future<ProcessResult> processQueue() async {
    if (_isProcessing) {
      return ProcessResult(
        success: false,
        processed: 0,
        failed: 0,
        message: '队列正在处理中',
      );
    }

    if (!_isOnline) {
      return ProcessResult(
        success: false,
        processed: 0,
        failed: 0,
        message: '设备离线',
      );
    }

    _isProcessing = true;
    int processed = 0;
    int failed = 0;

    try {
      final pendingItems = await _db.getPendingSyncQueue();

      for (final item in pendingItems) {
        final result = await _processQueueItem(item);
        if (result) {
          processed++;
        } else {
          failed++;
        }
      }

      // Clean up completed items
      await _db.deleteCompletedSyncQueue();

      return ProcessResult(
        success: true,
        processed: processed,
        failed: failed,
      );
    } catch (e) {
      return ProcessResult(
        success: false,
        processed: processed,
        failed: failed,
        message: e.toString(),
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single queue item
  Future<bool> _processQueueItem(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final entityType = item['entity_type'] as String;
    final entityId = item['entity_id'] as String;
    final operation = item['operation'] as String;
    final payload = item['payload'] as String;
    final retryCount = item['retry_count'] as int? ?? 0;

    // Mark as processing
    await _db.updateSyncQueueStatus(id, status: QueueStatus.processing);

    try {
      // Execute the operation
      await _executeOperation(entityType, entityId, operation, payload);

      // Mark as completed
      await _db.updateSyncQueueStatus(id, status: QueueStatus.completed);
      return true;
    } catch (e) {
      // Handle retry logic
      if (retryCount < _retryConfig.maxRetries) {
        // Schedule retry
        await _db.updateSyncQueueStatus(
          id,
          status: QueueStatus.pending,
          retryCount: retryCount + 1,
          lastError: e.toString(),
        );
      } else {
        // Max retries exceeded, mark as failed
        await _db.updateSyncQueueStatus(
          id,
          status: QueueStatus.failed,
          retryCount: retryCount + 1,
          lastError: e.toString(),
        );
      }
      return false;
    }
  }

  /// Execute sync operation against server
  Future<void> _executeOperation(
    String entityType,
    String entityId,
    String operation,
    String payload,
  ) async {
    final data = jsonDecode(payload) as Map<String, dynamic>;

    // Get server ID if available
    final serverId = await _db.getServerIdByLocalId(entityType, entityId);

    switch (operation) {
      case QueueOperation.create:
        await _createOnServer(entityType, entityId, data);
        break;
      case QueueOperation.update:
        if (serverId != null) {
          await _updateOnServer(entityType, serverId, data);
        }
        break;
      case QueueOperation.delete:
        if (serverId != null) {
          await _deleteOnServer(entityType, serverId);
        }
        break;
    }
  }

  /// Create entity on server
  Future<void> _createOnServer(
    String entityType,
    String localId,
    Map<String, dynamic> data,
  ) async {
    final endpoint = _getEndpoint(entityType);
    final response = await _http.post(endpoint, data: data);

    if (response.statusCode == 201 || response.statusCode == 200) {
      // Get server ID from response
      final responseData = response.data as Map<String, dynamic>;
      final serverId = responseData['id'] as String;

      // Create ID mapping
      await _db.insertIdMapping(
        entityType: entityType,
        localId: localId,
        serverId: serverId,
      );

      // Update sync metadata
      await _db.updateSyncStatus(
        entityType,
        localId,
        syncStatus: 1, // Synced
        serverId: serverId,
        lastSyncAt: DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      throw Exception('Server returned ${response.statusCode}');
    }
  }

  /// Update entity on server
  Future<void> _updateOnServer(
    String entityType,
    String serverId,
    Map<String, dynamic> data,
  ) async {
    final endpoint = '${_getEndpoint(entityType)}/$serverId';
    final response = await _http.put(endpoint, data: data);

    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    // Update sync metadata
    final localId = await _db.getLocalIdByServerId(entityType, serverId);
    if (localId != null) {
      await _db.updateSyncStatus(
        entityType,
        localId,
        syncStatus: 1, // Synced
        lastSyncAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// Delete entity on server
  Future<void> _deleteOnServer(String entityType, String serverId) async {
    final endpoint = '${_getEndpoint(entityType)}/$serverId';
    final response = await _http.delete(endpoint);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }

    // Clean up local metadata
    final localId = await _db.getLocalIdByServerId(entityType, serverId);
    if (localId != null) {
      await _db.deleteSyncMetadata(entityType, localId);
      await _db.deleteIdMapping(entityType, localId);
    }
  }

  /// Get API endpoint for entity type
  String _getEndpoint(String entityType) {
    switch (entityType) {
      case 'transaction':
        return '/transactions';
      case 'account':
        return '/accounts';
      case 'category':
        return '/categories';
      case 'book':
        return '/books';
      case 'budget':
        return '/budgets';
      default:
        throw ArgumentError('Unknown entity type: $entityType');
    }
  }

  /// Get queue statistics
  Future<Map<String, int>> getQueueStats() async {
    final stats = await _db.getSyncStatistics();
    return {
      'pending': stats['queue'] ?? 0,
      'failed': stats['queueFailed'] ?? 0,
    };
  }

  /// Get pending queue items
  Future<List<Map<String, dynamic>>> getPendingItems() async {
    return await _db.getPendingSyncQueue();
  }

  /// Retry failed items
  Future<int> retryFailedItems() async {
    final db = await _db.database;

    // Reset failed items to pending
    return await db.update(
      'sync_queue',
      {
        'status': QueueStatus.pending,
        'retry_count': 0,
      },
      where: 'status = ?',
      whereArgs: [QueueStatus.failed],
    );
  }

  /// Clear all queue items
  Future<int> clearQueue() async {
    return await _db.clearSyncQueue();
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

/// Result of queue processing
class ProcessResult {
  final bool success;
  final int processed;
  final int failed;
  final String? message;

  ProcessResult({
    required this.success,
    required this.processed,
    required this.failed,
    this.message,
  });
}
