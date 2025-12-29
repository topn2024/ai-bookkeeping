import 'dart:async';
import 'database_service.dart';
import 'server_sync_service.dart';

/// Cleanup result summary
class CleanupResult {
  final bool success;
  final int transactionsDeleted;
  final int bytesReclaimed;
  final String? errorMessage;
  final DateTime cleanupTime;

  CleanupResult({
    required this.success,
    this.transactionsDeleted = 0,
    this.bytesReclaimed = 0,
    this.errorMessage,
    DateTime? cleanupTime,
  }) : cleanupTime = cleanupTime ?? DateTime.now();
}

/// Cleanup preview showing what will be cleaned
class CleanupPreview {
  final int transactionsToDelete;
  final int estimatedBytesToReclaim;
  final DateTime oldestTransaction;
  final DateTime cutoffDate;

  CleanupPreview({
    required this.transactionsToDelete,
    required this.estimatedBytesToReclaim,
    required this.oldestTransaction,
    required this.cutoffDate,
  });

  bool get hasDataToClean => transactionsToDelete > 0;
}

/// Data cleanup configuration
class CleanupConfig {
  /// Number of months of data to keep locally
  final int keepMonths;

  /// Minimum sync age before cleanup (days)
  final int minSyncAgeDays;

  /// Batch size for delete operations
  final int batchSize;

  const CleanupConfig({
    this.keepMonths = 1, // User selected: keep 1 month
    this.minSyncAgeDays = 1, // Must be synced for at least 1 day
    this.batchSize = 100,
  });
}

/// Data cleanup service - cleans up old synced data from local storage
class DataCleanupService {
  static final DataCleanupService _instance = DataCleanupService._internal();

  final DatabaseService _db = DatabaseService();
  final CleanupConfig _config;

  factory DataCleanupService({CleanupConfig? config}) {
    if (config != null) {
      return DataCleanupService._withConfig(config);
    }
    return _instance;
  }

  DataCleanupService._internal() : _config = const CleanupConfig();
  DataCleanupService._withConfig(this._config);

  /// Get preview of what will be cleaned up
  Future<CleanupPreview> getCleanupPreview() async {
    final cutoffDate = _getCutoffDate();
    final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;

    // Get synced transactions older than cutoff
    final oldTransactions = await _db.getSyncedEntitiesOlderThan(
      'transaction',
      cutoffTimestamp,
    );

    // Estimate bytes (roughly 500 bytes per transaction)
    final estimatedBytes = oldTransactions.length * 500;

    // Get oldest transaction date
    DateTime oldestDate = DateTime.now();
    if (oldTransactions.isNotEmpty) {
      for (final meta in oldTransactions) {
        final updatedAt = meta['localUpdatedAt'] as int?;
        if (updatedAt != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(updatedAt);
          if (date.isBefore(oldestDate)) {
            oldestDate = date;
          }
        }
      }
    }

    return CleanupPreview(
      transactionsToDelete: oldTransactions.length,
      estimatedBytesToReclaim: estimatedBytes,
      oldestTransaction: oldestDate,
      cutoffDate: cutoffDate,
    );
  }

  /// Perform cleanup of old synced data
  Future<CleanupResult> performCleanup() async {
    int deleted = 0;

    try {
      final cutoffDate = _getCutoffDate();
      final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;

      // Get synced transactions older than cutoff
      final oldTransactions = await _db.getSyncedEntitiesOlderThan(
        'transaction',
        cutoffTimestamp,
      );

      if (oldTransactions.isEmpty) {
        return CleanupResult(
          success: true,
          transactionsDeleted: 0,
        );
      }

      // Delete in batches
      for (var i = 0; i < oldTransactions.length; i += _config.batchSize) {
        final batch = oldTransactions.skip(i).take(_config.batchSize).toList();

        for (final meta in batch) {
          final localId = meta['localId'] as String;
          final serverId = meta['serverId'] as String?;

          // Safety check: only delete if has server ID (confirmed synced)
          if (serverId != null) {
            // Delete the transaction
            await _db.deleteTransaction(localId);

            // Delete sync metadata
            await _db.deleteSyncMetadata('transaction', localId);

            // Keep ID mapping for reference
            // await _db.deleteIdMapping('transaction', localId);

            deleted++;
          }
        }
      }

      // Vacuum database to reclaim space
      await _vacuumDatabase();

      return CleanupResult(
        success: true,
        transactionsDeleted: deleted,
        bytesReclaimed: deleted * 500, // Estimate
      );
    } catch (e) {
      return CleanupResult(
        success: false,
        transactionsDeleted: deleted,
        errorMessage: e.toString(),
      );
    }
  }

  /// Check if cleanup is recommended
  Future<bool> isCleanupRecommended() async {
    final preview = await getCleanupPreview();
    return preview.transactionsToDelete > 100; // Recommend if > 100 old transactions
  }

  /// Get database size in bytes
  Future<int> getDatabaseSize() async {
    // This is an estimate based on transaction count
    final transactions = await _db.getTransactions();
    return transactions.length * 500; // Rough estimate
  }

  /// Perform cleanup after successful sync
  Future<CleanupResult> cleanupAfterSync() async {
    // Check if there are pending sync items
    final stats = await _db.getSyncStatistics();
    if ((stats['pending'] ?? 0) > 0) {
      return CleanupResult(
        success: false,
        errorMessage: '存在未同步的数据，无法清理',
      );
    }

    return performCleanup();
  }

  /// Get cutoff date based on config
  DateTime _getCutoffDate() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month - _config.keepMonths,
      now.day,
    );
  }

  /// Vacuum database to reclaim space
  Future<void> _vacuumDatabase() async {
    final db = await _db.database;
    await db.execute('VACUUM');
  }

  /// Clear all sync queue (failed items)
  Future<int> clearFailedSyncQueue() async {
    final db = await _db.database;
    return await db.delete(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [3], // Failed status
    );
  }

  /// Get cleanup statistics
  Future<Map<String, dynamic>> getCleanupStats() async {
    final preview = await getCleanupPreview();
    final dbSize = await getDatabaseSize();

    return {
      'transactionsToClean': preview.transactionsToDelete,
      'estimatedSavings': preview.estimatedBytesToReclaim,
      'currentDatabaseSize': dbSize,
      'oldestTransactionDate': preview.oldestTransaction.toIso8601String(),
      'cutoffDate': preview.cutoffDate.toIso8601String(),
    };
  }
}
