import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'collaborative_learning_service.dart';

/// 真实协同学习API客户端
///
/// 功能：
/// 1. 安全的规则上传（脱敏数据）
/// 2. 协同规则下载
/// 3. 设备认证
/// 4. 重试机制
/// 5. 缓存策略
class RealCollaborativeApiClient implements CollaborativeApiClient {
  final String _baseUrl;
  final HttpClient _httpClient;
  final CollaborativeAuthProvider _authProvider;
  final CollaborativeCacheManager _cacheManager;

  final Duration _timeout;
  final int _maxRetries;

  RealCollaborativeApiClient({
    required String baseUrl,
    HttpClient? httpClient,
    required CollaborativeAuthProvider authProvider,
    required CollaborativeCacheManager cacheManager,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
  })  : _baseUrl = baseUrl,
        _httpClient = httpClient ?? HttpClient(),
        _authProvider = authProvider,
        _cacheManager = cacheManager,
        _timeout = timeout,
        _maxRetries = maxRetries {
    _httpClient.connectionTimeout = _timeout;
  }

  @override
  Future<void> uploadPatterns(List<Map<String, dynamic>> patterns) async {
    if (patterns.isEmpty) return;

    final endpoint = '$_baseUrl/api/v1/collaborative/patterns';

    try {
      final response = await _executeWithRetry(() async {
        final request = await _httpClient.postUrl(Uri.parse(endpoint));

        // 设置请求头
        await _setAuthHeaders(request);
        request.headers.contentType = ContentType.json;

        // 构建请求体
        final body = jsonEncode({
          'patterns': patterns,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'client_version': _getClientVersion(),
        });

        request.write(body);
        return await request.close();
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        final body = await response.transform(utf8.decoder).join();
        throw CollaborativeApiException(
          'Upload failed',
          statusCode: response.statusCode,
          responseBody: body,
        );
      }

      debugPrint('Collaborative: Uploaded ${patterns.length} patterns');
    } catch (e) {
      debugPrint('Collaborative: Upload failed - $e');
      rethrow;
    }
  }

  @override
  Future<List<CollaborativeRule>> downloadRules() async {
    // 先检查缓存
    final cachedRules = await _cacheManager.getCachedRules();
    if (cachedRules != null && !_cacheManager.isCacheExpired()) {
      debugPrint('Collaborative: Using cached rules (${cachedRules.length})');
      return cachedRules;
    }

    final endpoint = '$_baseUrl/api/v1/collaborative/rules';

    try {
      final response = await _executeWithRetry(() async {
        final request = await _httpClient.getUrl(Uri.parse(endpoint));

        // 设置请求头
        await _setAuthHeaders(request);
        request.headers.add('Accept', 'application/json');

        // 添加增量同步支持
        final lastSyncTime = await _cacheManager.getLastSyncTime();
        if (lastSyncTime != null) {
          request.headers.add(
            'If-Modified-Since',
            HttpDate.format(lastSyncTime.toUtc()),
          );
        }

        return await request.close();
      });

      // 304 Not Modified - 使用缓存
      if (response.statusCode == 304) {
        final cached = await _cacheManager.getCachedRules();
        return cached ?? [];
      }

      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw CollaborativeApiException(
          'Download failed',
          statusCode: response.statusCode,
          responseBody: body,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final rulesJson = json['rules'] as List<dynamic>? ?? [];

      final rules = rulesJson
          .map((r) => CollaborativeRule.fromJson(r as Map<String, dynamic>))
          .toList();

      // 更新缓存
      await _cacheManager.cacheRules(rules);
      await _cacheManager.setLastSyncTime(DateTime.now());

      debugPrint('Collaborative: Downloaded ${rules.length} rules');
      return rules;
    } on SocketException catch (e) {
      debugPrint('Collaborative: Network error - $e');
      // 网络错误时返回缓存
      final cached = await _cacheManager.getCachedRules();
      if (cached != null) {
        debugPrint('Collaborative: Falling back to cached rules');
        return cached;
      }
      rethrow;
    } catch (e) {
      debugPrint('Collaborative: Download failed - $e');
      // 其他错误时尝试返回缓存
      final cached = await _cacheManager.getCachedRules();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// 获取规则统计信息
  Future<CollaborativeRulesStats> getRulesStats() async {
    final endpoint = '$_baseUrl/api/v1/collaborative/stats';

    try {
      final response = await _executeWithRetry(() async {
        final request = await _httpClient.getUrl(Uri.parse(endpoint));
        await _setAuthHeaders(request);
        return await request.close();
      });

      if (response.statusCode != 200) {
        throw CollaborativeApiException(
          'Get stats failed',
          statusCode: response.statusCode,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      return CollaborativeRulesStats.fromJson(json);
    } catch (e) {
      debugPrint('Collaborative: Get stats failed - $e');
      rethrow;
    }
  }

  /// 报告规则反馈
  Future<void> reportFeedback({
    required String rulePatternHash,
    required CollaborativeFeedbackType type,
    String? comment,
  }) async {
    final endpoint = '$_baseUrl/api/v1/collaborative/feedback';

    try {
      final response = await _executeWithRetry(() async {
        final request = await _httpClient.postUrl(Uri.parse(endpoint));
        await _setAuthHeaders(request);
        request.headers.contentType = ContentType.json;

        final body = jsonEncode({
          'pattern_hash': rulePatternHash,
          'feedback_type': type.name,
          'comment': comment,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });

        request.write(body);
        return await request.close();
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw CollaborativeApiException(
          'Report feedback failed',
          statusCode: response.statusCode,
        );
      }

      debugPrint('Collaborative: Reported feedback for $rulePatternHash');
    } catch (e) {
      debugPrint('Collaborative: Report feedback failed - $e');
      // 反馈失败不影响主流程，静默处理
    }
  }

  /// 带重试的请求执行
  Future<HttpClientResponse> _executeWithRetry(
    Future<HttpClientResponse> Function() request,
  ) async {
    Exception? lastException;

    for (var i = 0; i < _maxRetries; i++) {
      try {
        return await request().timeout(_timeout);
      } on TimeoutException {
        lastException = TimeoutException('Request timed out');
        debugPrint('Collaborative: Request timeout, retry ${i + 1}/$_maxRetries');
      } on SocketException catch (e) {
        lastException = e;
        debugPrint('Collaborative: Network error, retry ${i + 1}/$_maxRetries');
      } catch (e) {
        if (e is CollaborativeApiException) {
          // 4xx错误不重试
          if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
            rethrow;
          }
        }
        lastException = e as Exception;
        debugPrint('Collaborative: Request failed, retry ${i + 1}/$_maxRetries');
      }

      // 指数退避
      if (i < _maxRetries - 1) {
        await Future.delayed(Duration(seconds: 1 << i));
      }
    }

    throw lastException ?? Exception('Request failed after $_maxRetries retries');
  }

  /// 设置认证头
  Future<void> _setAuthHeaders(HttpClientRequest request) async {
    final authToken = await _authProvider.getAuthToken();
    if (authToken != null) {
      request.headers.add('Authorization', 'Bearer $authToken');
    }

    final deviceId = await _authProvider.getDeviceId();
    request.headers.add('X-Device-ID', deviceId);
    request.headers.add('X-Client-Version', _getClientVersion());
  }

  String _getClientVersion() {
    // 从应用配置获取版本号
    return '2.0.0';
  }

  void dispose() {
    _httpClient.close();
  }
}

// ==================== 支持类 ====================

/// 协同学习API异常
class CollaborativeApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  const CollaborativeApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'CollaborativeApiException: $message (status: $statusCode)';
    }
    return 'CollaborativeApiException: $message';
  }
}

/// 反馈类型
enum CollaborativeFeedbackType {
  accurate, // 准确
  inaccurate, // 不准确
  inappropriate, // 不合适
}

/// 规则统计信息
class CollaborativeRulesStats {
  final int totalRules;
  final int activeRules;
  final int totalContributors;
  final DateTime lastUpdated;
  final Map<String, int> rulesByCategory;

  const CollaborativeRulesStats({
    required this.totalRules,
    required this.activeRules,
    required this.totalContributors,
    required this.lastUpdated,
    required this.rulesByCategory,
  });

  factory CollaborativeRulesStats.fromJson(Map<String, dynamic> json) {
    return CollaborativeRulesStats(
      totalRules: json['total_rules'] as int? ?? 0,
      activeRules: json['active_rules'] as int? ?? 0,
      totalContributors: json['total_contributors'] as int? ?? 0,
      lastUpdated: DateTime.parse(
        json['last_updated'] as String? ?? DateTime.now().toIso8601String(),
      ),
      rulesByCategory: Map<String, int>.from(
        json['rules_by_category'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

// ==================== 认证提供者 ====================

/// 认证提供者接口
abstract class CollaborativeAuthProvider {
  /// 获取认证令牌
  Future<String?> getAuthToken();

  /// 获取设备ID
  Future<String> getDeviceId();

  /// 刷新令牌
  Future<String?> refreshToken();
}

/// 匿名认证提供者（不需要登录）
class AnonymousCollaborativeAuthProvider implements CollaborativeAuthProvider {
  final SecureStorageWrapper _storage;
  static const String _deviceIdKey = 'collaborative_device_id';

  AnonymousCollaborativeAuthProvider(this._storage);

  @override
  Future<String?> getAuthToken() async {
    // 匿名模式不需要认证令牌
    return null;
  }

  @override
  Future<String> getDeviceId() async {
    var deviceId = await _storage.read(_deviceIdKey);
    if (deviceId == null) {
      // 生成唯一设备ID
      deviceId = _generateDeviceId();
      await _storage.write(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  @override
  Future<String?> refreshToken() async {
    return null;
  }

  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'anon_${timestamp}_$random';
  }
}

/// 已登录用户认证提供者
class AuthenticatedCollaborativeAuthProvider implements CollaborativeAuthProvider {
  final SecureStorageWrapper _storage;
  final TokenRefreshCallback _onRefreshToken;

  static const String _tokenKey = 'collaborative_auth_token';
  static const String _deviceIdKey = 'collaborative_device_id';

  AuthenticatedCollaborativeAuthProvider({
    required SecureStorageWrapper storage,
    required TokenRefreshCallback onRefreshToken,
  })  : _storage = storage,
        _onRefreshToken = onRefreshToken;

  @override
  Future<String?> getAuthToken() async {
    return await _storage.read(_tokenKey);
  }

  @override
  Future<String> getDeviceId() async {
    var deviceId = await _storage.read(_deviceIdKey);
    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await _storage.write(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  @override
  Future<String?> refreshToken() async {
    final newToken = await _onRefreshToken();
    if (newToken != null) {
      await _storage.write(_tokenKey, newToken);
    }
    return newToken;
  }

  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'auth_${timestamp}_$random';
  }
}

typedef TokenRefreshCallback = Future<String?> Function();

/// 安全存储包装器
abstract class SecureStorageWrapper {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

// ==================== 缓存管理器 ====================

/// 缓存管理器接口
abstract class CollaborativeCacheManager {
  /// 缓存规则
  Future<void> cacheRules(List<CollaborativeRule> rules);

  /// 获取缓存规则
  Future<List<CollaborativeRule>?> getCachedRules();

  /// 检查缓存是否过期
  bool isCacheExpired();

  /// 获取上次同步时间
  Future<DateTime?> getLastSyncTime();

  /// 设置上次同步时间
  Future<void> setLastSyncTime(DateTime time);

  /// 清除缓存
  Future<void> clearCache();
}

/// 内存缓存管理器
class InMemoryCollaborativeCacheManager implements CollaborativeCacheManager {
  List<CollaborativeRule>? _cachedRules;
  DateTime? _lastSyncTime;
  final Duration _cacheExpiry;

  InMemoryCollaborativeCacheManager({
    Duration cacheExpiry = const Duration(hours: 6),
  }) : _cacheExpiry = cacheExpiry;

  @override
  Future<void> cacheRules(List<CollaborativeRule> rules) async {
    _cachedRules = List.unmodifiable(rules);
    _lastSyncTime = DateTime.now();
  }

  @override
  Future<List<CollaborativeRule>?> getCachedRules() async {
    return _cachedRules;
  }

  @override
  bool isCacheExpired() {
    if (_lastSyncTime == null) return true;
    return DateTime.now().difference(_lastSyncTime!) > _cacheExpiry;
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    return _lastSyncTime;
  }

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    _lastSyncTime = time;
  }

  @override
  Future<void> clearCache() async {
    _cachedRules = null;
    _lastSyncTime = null;
  }
}

/// 持久化缓存管理器
class PersistentCollaborativeCacheManager implements CollaborativeCacheManager {
  final CacheStorageWrapper _storage;
  final Duration _cacheExpiry;

  static const String _rulesKey = 'collaborative_rules_cache';
  static const String _lastSyncKey = 'collaborative_last_sync';

  PersistentCollaborativeCacheManager({
    required CacheStorageWrapper storage,
    Duration cacheExpiry = const Duration(hours: 6),
  })  : _storage = storage,
        _cacheExpiry = cacheExpiry;

  @override
  Future<void> cacheRules(List<CollaborativeRule> rules) async {
    final json = jsonEncode(rules.map((r) => _ruleToJson(r)).toList());
    await _storage.setString(_rulesKey, json);
    await setLastSyncTime(DateTime.now());
  }

  @override
  Future<List<CollaborativeRule>?> getCachedRules() async {
    final json = await _storage.getString(_rulesKey);
    if (json == null) return null;

    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => CollaborativeRule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to parse cached rules: $e');
      return null;
    }
  }

  @override
  bool isCacheExpired() {
    // 同步检查，实际可能需要异步
    return true; // 默认过期，强制刷新
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = await _storage.getString(_lastSyncKey);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    await _storage.setString(_lastSyncKey, time.toIso8601String());
  }

  @override
  Future<void> clearCache() async {
    await _storage.remove(_rulesKey);
    await _storage.remove(_lastSyncKey);
  }

  Map<String, dynamic> _ruleToJson(CollaborativeRule rule) {
    return {
      'pattern_hash': rule.patternHash,
      'type': rule.type,
      'category': rule.category,
      'confidence': rule.confidence,
      'aggregated_count': rule.aggregatedCount,
    };
  }
}

/// 缓存存储包装器
abstract class CacheStorageWrapper {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

// ==================== 工厂类 ====================

/// 协同学习API客户端工厂
class CollaborativeApiClientFactory {
  /// 创建生产环境客户端
  static RealCollaborativeApiClient createProduction({
    required String baseUrl,
    required SecureStorageWrapper secureStorage,
    required CacheStorageWrapper cacheStorage,
    TokenRefreshCallback? onRefreshToken,
  }) {
    final authProvider = onRefreshToken != null
        ? AuthenticatedCollaborativeAuthProvider(
            storage: secureStorage,
            onRefreshToken: onRefreshToken,
          )
        : AnonymousCollaborativeAuthProvider(secureStorage);

    final cacheManager = PersistentCollaborativeCacheManager(
      storage: cacheStorage,
    );

    return RealCollaborativeApiClient(
      baseUrl: baseUrl,
      authProvider: authProvider,
      cacheManager: cacheManager,
    );
  }

  /// 创建测试环境客户端
  static RealCollaborativeApiClient createStaging({
    required SecureStorageWrapper secureStorage,
    required CacheStorageWrapper cacheStorage,
  }) {
    return createProduction(
      baseUrl: 'https://staging-api.example.com',
      secureStorage: secureStorage,
      cacheStorage: cacheStorage,
    );
  }

  /// 创建Mock客户端（用于测试）
  static CollaborativeApiClient createMock() {
    return MockCollaborativeApiClient();
  }
}

/// Mock实现（已在collaborative_learning_service.dart中定义，这里保留引用）
/// 请使用 collaborative_learning_service.dart 中的 MockCollaborativeApiClient
