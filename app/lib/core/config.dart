// Application configuration service.
//
// Manages app configuration including API keys and endpoints.
// In production, sensitive values should be provided via:
// - Dart defines (--dart-define)
// - Secure storage
// - Backend configuration endpoint

import 'package:flutter/foundation.dart';

/// Application configuration
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  /// API Keys - should be configured via dart-define in production
  /// Build with: flutter build --dart-define=QWEN_API_KEY=your-key
  String get qwenApiKey =>
      const String.fromEnvironment('QWEN_API_KEY', defaultValue: '');

  String get zhipuApiKey =>
      const String.fromEnvironment('ZHIPU_API_KEY', defaultValue: '');

  /// Backend API URL
  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8000/api/v1',
      );

  /// Whether running in debug mode
  bool get isDebug => kDebugMode;

  /// Whether running in release mode
  bool get isRelease => kReleaseMode;

  /// Check if required configuration is present
  bool get isConfigured => qwenApiKey.isNotEmpty;

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
