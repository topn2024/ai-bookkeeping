// Application configuration service.
//
// Manages app configuration including API keys and endpoints.
// API keys are fetched from the server and cached locally.

import 'package:flutter/foundation.dart';
import '../services/secure_storage_service.dart';
import '../services/http_service.dart';

/// Application configuration
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  final SecureStorageService _secureStorage = SecureStorageService();
  final HttpService _http = HttpService();

  // Cached API keys
  String? _qwenApiKey;
  String? _zhipuApiKey;
  bool _initialized = false;

  /// Backend API URL (compile-time constant)
  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8000/api/v1',
      );

  /// Get Qwen API Key (from cache or compile-time)
  String get qwenApiKey {
    // First try cached value from server
    if (_qwenApiKey != null && _qwenApiKey!.isNotEmpty) {
      return _qwenApiKey!;
    }
    // Fall back to compile-time value
    return const String.fromEnvironment('QWEN_API_KEY', defaultValue: '');
  }

  /// Get Zhipu API Key (from cache or compile-time)
  String get zhipuApiKey {
    if (_zhipuApiKey != null && _zhipuApiKey!.isNotEmpty) {
      return _zhipuApiKey!;
    }
    return const String.fromEnvironment('ZHIPU_API_KEY', defaultValue: '');
  }

  /// Whether running in debug mode
  bool get isDebug => kDebugMode;

  /// Whether running in release mode
  bool get isRelease => kReleaseMode;

  /// Check if required configuration is present
  bool get isConfigured => qwenApiKey.isNotEmpty;

  /// Initialize config - load cached values from secure storage
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _qwenApiKey = await _secureStorage.read('qwen_api_key');
      _zhipuApiKey = await _secureStorage.read('zhipu_api_key');
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to load cached API keys: $e');
    }
  }

  /// Fetch API keys from server and cache them
  /// Call this after user logs in
  Future<bool> fetchFromServer() async {
    try {
      final response = await _http.get('/config/ai');

      if (response.statusCode == 200) {
        final data = response.data;
        _qwenApiKey = data['qwen_api_key'] as String?;
        _zhipuApiKey = data['zhipu_api_key'] as String?;

        // Cache to secure storage
        if (_qwenApiKey != null && _qwenApiKey!.isNotEmpty) {
          await _secureStorage.write('qwen_api_key', _qwenApiKey!);
        }
        if (_zhipuApiKey != null && _zhipuApiKey!.isNotEmpty) {
          await _secureStorage.write('zhipu_api_key', _zhipuApiKey!);
        }

        debugPrint('API keys fetched and cached from server');
        return true;
      }
    } catch (e) {
      debugPrint('Failed to fetch API keys from server: $e');
    }
    return false;
  }

  /// Clear cached API keys (call on logout)
  Future<void> clearCache() async {
    _qwenApiKey = null;
    _zhipuApiKey = null;
    await _secureStorage.delete('qwen_api_key');
    await _secureStorage.delete('zhipu_api_key');
  }

  /// Validate configuration and return missing items
  List<String> validateConfig() {
    final missing = <String>[];
    if (qwenApiKey.isEmpty) missing.add('QWEN_API_KEY');
    return missing;
  }

  @override
  String toString() {
    return 'AppConfig('
        'qwenApiKey: ${qwenApiKey.isNotEmpty ? "[SET]" : "[MISSING]"}, '
        'zhipuApiKey: ${zhipuApiKey.isNotEmpty ? "[SET]" : "[MISSING]"}, '
        'apiBaseUrl: $apiBaseUrl'
        ')';
  }
}

/// Global config instance
final appConfig = AppConfig();
