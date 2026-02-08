import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'source_file_service.dart';
import 'http_service.dart';
import '../models/transaction.dart';

/// Service for syncing source files to server when on WiFi.
///
/// Handles:
/// - Detecting WiFi connectivity
/// - Uploading local files to server
/// - Updating transaction records with server URLs
/// - Managing sync queue and retry logic
class SourceFileSyncService {
  static final SourceFileSyncService _instance = SourceFileSyncService._internal();
  factory SourceFileSyncService() => _instance;
  SourceFileSyncService._internal();

  final SourceFileService _fileService = SourceFileService();
  final Connectivity _connectivity = Connectivity();
  final HttpService _http = HttpService();

  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Check if currently on WiFi
  Future<bool> isOnWifi() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi);
  }

  /// Sync a single file to server
  ///
  /// Returns the server URL if successful, null otherwise
  Future<String?> syncFile({
    required String localPath,
    required String transactionId,
    required bool isImage,
  }) async {
    // Check WiFi sync setting
    if (!await _fileService.isWifiSyncEnabled()) {
      return null;
    }

    // Check connectivity
    if (!await isOnWifi()) {
      return null;
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final fileName = localPath.split(Platform.pathSeparator).last;
      final base64Data = base64Encode(bytes);

      // Use httpService for proper token handling and auto-refresh
      final response = await _http.post(
        '/files/upload-base64',
        data: {
          'data': base64Data,
          'filename': fileName,
          'file_type': isImage ? 'image' : 'audio',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final serverUrl = data['url'] as String?;

        if (serverUrl != null) {
          // Update transaction with server URL
          await _updateTransactionSourceUrl(
            transactionId: transactionId,
            serverUrl: serverUrl,
            contentType: data['content_type'] as String?,
            fileSize: data['size'] as int?,
          );
        }

        return serverUrl;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update transaction with server URL after successful upload
  Future<void> _updateTransactionSourceUrl({
    required String transactionId,
    required String serverUrl,
    String? contentType,
    int? fileSize,
  }) async {
    try {
      await _http.post(
        '/files/transactions/$transactionId/source-file',
        data: {
          'source_file_url': serverUrl,
          'source_file_type': contentType,
          'source_file_size': fileSize,
        },
      );
    } catch (e) {
      // Silent failure - transaction URL update is not critical
    }
  }

  /// Sync all pending files for a list of transactions
  Future<SyncResult> syncPendingFiles(List<Transaction> transactions) async {
    if (_isSyncing) {
      return SyncResult(synced: 0, failed: 0, skipped: 0);
    }

    // Check WiFi
    if (!await isOnWifi()) {
      return SyncResult(synced: 0, failed: 0, skipped: transactions.length);
    }

    // Check sync setting
    if (!await _fileService.isWifiSyncEnabled()) {
      return SyncResult(synced: 0, failed: 0, skipped: transactions.length);
    }

    _isSyncing = true;

    int synced = 0;
    int failed = 0;
    int skipped = 0;

    try {
      for (final transaction in transactions) {
        // Skip if no local file or already synced
        if (transaction.sourceFileLocalPath == null) {
          skipped++;
          continue;
        }

        if (transaction.sourceFileServerUrl != null) {
          skipped++;
          continue;
        }

        // Check if file expired
        if (transaction.isSourceFileExpired) {
          skipped++;
          continue;
        }

        final isImage = transaction.source == TransactionSource.image;
        final serverUrl = await syncFile(
          localPath: transaction.sourceFileLocalPath!,
          transactionId: transaction.id,
          isImage: isImage,
        );

        if (serverUrl != null) {
          synced++;
        } else {
          failed++;
        }

        // Small delay between uploads to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      _isSyncing = false;
    }

    return SyncResult(synced: synced, failed: failed, skipped: skipped);
  }

  /// Start background sync when WiFi is connected
  void startBackgroundSync(Future<List<Transaction>> Function() getTransactions) {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) async {
      if (results.contains(ConnectivityResult.wifi)) {
        // WiFi connected, start sync
        final transactions = await getTransactions();
        final pendingTransactions = transactions.where((t) =>
            t.sourceFileLocalPath != null && t.sourceFileServerUrl == null).toList();

        if (pendingTransactions.isNotEmpty) {
          await syncPendingFiles(pendingTransactions);
        }
      }
    });
  }

  /// Cancel ongoing sync (if any)
  void cancelSync() {
    _isSyncing = false;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Check if sync is in progress
  bool get isSyncing => _isSyncing;
}

/// Result of a sync operation
class SyncResult {
  final int synced;
  final int failed;
  final int skipped;

  SyncResult({
    required this.synced,
    required this.failed,
    required this.skipped,
  });

  int get total => synced + failed + skipped;

  bool get hasErrors => failed > 0;

  @override
  String toString() => 'SyncResult(synced: $synced, failed: $failed, skipped: $skipped)';
}
