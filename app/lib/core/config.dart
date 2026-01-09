// Application configuration service.
//
// Manages app configuration including API keys and endpoints.
// API keys are provided via compile-time environment variables for security.
// Server only returns availability status, not actual keys.

import 'package:flutter/foundation.dart';
import '../services/http_service.dart';

/// Application configuration
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  final HttpService _http = HttpService();

  // AI availability status from server
  bool _qwenAvailable = false;
  bool _zhipuAvailable = false;
  bool _initialized = false;

  /// Backend API URL (compile-time constant)
  /// 默认使用生产服务器地址
  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://160.202.238.29/api/v1',
      );

  /// Get Qwen API Key (compile-time only for security)
  String get qwenApiKey {
    return const String.fromEnvironment('QWEN_API_KEY', defaultValue: '');
  }

  /// Get Zhipu API Key (compile-time only for security)
  String get zhipuApiKey {
    return const String.fromEnvironment('ZHIPU_API_KEY', defaultValue: '');
  }

  /// Whether Qwen AI is available on server
  bool get isQwenAvailable => _qwenAvailable;

  /// Whether Zhipu AI is available on server
  bool get isZhipuAvailable => _zhipuAvailable;

  /// Whether running in debug mode
  bool get isDebug => kDebugMode;

  /// Whether running in release mode
  bool get isRelease => kReleaseMode;

  /// Check if required configuration is present
  bool get isConfigured => qwenApiKey.isNotEmpty;

  /// Initialize config
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('AppConfig: Initialized, qwenApiKey=${qwenApiKey.isNotEmpty ? "[SET]" : "[EMPTY]"}');
  }

  /// Fetch AI availability status from server
  /// Call this after user logs in
  Future<bool> fetchFromServer() async {
    try {
      debugPrint('AppConfig: Fetching AI availability from /config/ai...');
      final response = await _http.get('/config/ai');

      debugPrint('AppConfig: Response status=${response.statusCode}');
      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('AppConfig: Response data=$data');

        // Server now returns availability flags, not actual keys
        _qwenAvailable = data['qwen_available'] as bool? ?? false;
        _zhipuAvailable = data['zhipu_available'] as bool? ?? false;

        debugPrint('AppConfig: qwen_available=$_qwenAvailable, zhipu_available=$_zhipuAvailable');
        return true;
      } else {
        debugPrint('AppConfig: Unexpected status code: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('AppConfig: Failed to fetch AI availability from server: $e');
      debugPrint('AppConfig: Stack trace: $stack');
    }
    return false;
  }

  /// Clear cached data (call on logout)
  Future<void> clearCache() async {
    _qwenAvailable = false;
    _zhipuAvailable = false;
  }

  /// Validate configuration and return missing items
  List<String> validateConfig() {
    final missing = <String>[];
    if (qwenApiKey.isEmpty) missing.add('QWEN_API_KEY');
    return missing;
  }
}

/// Global app config instance
final appConfig = AppConfig();
