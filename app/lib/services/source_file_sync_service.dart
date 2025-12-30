import 'dart:io';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'source_file_service.dart';
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

  // API configuration
  static const String _baseUrlKey = 'api_base_url';
  static const String _authTokenKey = 'auth_token';

  bool _isSyncing = false;

  /// Check if currently on WiFi
  Future<bool> isOnWifi() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi);
  }

  /// Get saved API base URL
  Future<String?> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey);
  }

  /// Get saved auth token
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
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

    final baseUrl = await _getBaseUrl();
    final authToken = await _getAuthToken();

    if (baseUrl == null || authToken == null) {
      print('Missing API configuration for file sync');
      return null;
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('Local file not found: $localPath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final fileName = localPath.split(Platform.pathSeparator).last;
      final base64Data = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/files/upload-base64'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'data': base64Data,
          'filename': fileName,
          'file_type': isImage ? 'image' : 'audio',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
      } else {
        print('File upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error syncing file: $e');
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
    final baseUrl = await _getBaseUrl();
    final authToken = await _getAuthToken();

    if (baseUrl == null || authToken == null) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/api/v1/files/transactions/$transactionId/source-file'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'source_file_url': serverUrl,
          'source_file_type': contentType,
          'source_file_size': fileSize,
        }),
      );
    } catch (e) {
      print('Error updating transaction source URL: $e');
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
    _connectivity.onConnectivityChanged.listen((results) async {
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
