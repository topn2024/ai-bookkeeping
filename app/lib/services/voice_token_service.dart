import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 语音服务Token管理
///
/// 负责从后端获取语音服务Token，安全存储，并自动刷新。
class VoiceTokenService {
  static final VoiceTokenService _instance = VoiceTokenService._internal();
  factory VoiceTokenService() => _instance;
  VoiceTokenService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final Dio _dio = Dio();

  // Token缓存
  VoiceTokenInfo? _cachedToken;
  Timer? _refreshTimer;

  // 防止并发请求的锁
  Completer<VoiceTokenInfo>? _fetchingCompleter;

  // 重试配置
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 1);

  // 存储键
  static const String _tokenKey = 'voice_service_token';
  static const String _expiresAtKey = 'voice_service_expires_at';
  static const String _appKeyKey = 'voice_service_app_key';
  static const String _asrUrlKey = 'voice_service_asr_url';
  static const String _ttsUrlKey = 'voice_service_tts_url';

  /// 初始化服务
  ///
  /// [baseUrl] 后端API基础URL
  /// [authToken] 用户认证Token
  Future<void> initialize({
    required String baseUrl,
    required String authToken,
  }) async {
    _dio.options.baseUrl = baseUrl;
    _dio.options.headers['Authorization'] = 'Bearer $authToken';
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // 尝试从安全存储加载缓存的Token
    await _loadCachedToken();
  }

  /// 更新认证Token
  void updateAuthToken(String authToken) {
    _dio.options.headers['Authorization'] = 'Bearer $authToken';
  }

  /// 获取语音服务Token
  ///
  /// 如果缓存有效则返回缓存，否则从服务器获取新Token。
  /// 自动处理Token刷新。
  /// 使用锁机制防止并发请求，支持自动重试。
  Future<VoiceTokenInfo> getToken() async {
    // 检查缓存是否有效
    if (_cachedToken != null && !_cachedToken!.isExpiringSoon) {
      return _cachedToken!;
    }

    // 如果已有请求在进行中，等待该请求完成
    if (_fetchingCompleter != null) {
      return _fetchingCompleter!.future;
    }

    // 创建新的 Completer 防止并发请求
    _fetchingCompleter = Completer<VoiceTokenInfo>();

    try {
      final tokenInfo = await _fetchTokenWithRetry();
      _fetchingCompleter!.complete(tokenInfo);
      return tokenInfo;
    } catch (e) {
      _fetchingCompleter!.completeError(e);
      rethrow;
    } finally {
      _fetchingCompleter = null;
    }
  }

  /// 带重试的Token获取
  Future<VoiceTokenInfo> _fetchTokenWithRetry() async {
    Exception? lastException;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await _fetchToken();
      } on VoiceTokenException catch (e) {
        lastException = e;

        // 不可重试的错误直接抛出
        if (e.message.contains('语音服务未配置') ||
            e.message.contains('请求过于频繁')) {
          rethrow;
        }

        // 可重试错误，等待后重试
        if (attempt < _maxRetries - 1) {
          final delay = _baseRetryDelay * (attempt + 1);
          debugPrint('VoiceTokenService: 获取Token失败，${delay.inSeconds}秒后重试 (${attempt + 1}/$_maxRetries)');
          await Future.delayed(delay);
        }
      }
    }

    throw lastException ?? VoiceTokenException('获取Token失败');
  }

  /// 从服务器获取Token
  Future<VoiceTokenInfo> _fetchToken() async {
    try {
      final response = await _dio.get('/api/v1/voice/token');

      if (response.statusCode == 200) {
        final data = response.data;
        final tokenInfo = VoiceTokenInfo(
          token: data['token'],
          expiresAt: DateTime.parse(data['expires_at']),
          appKey: data['app_key'],
          asrUrl: data['asr_url'],
          asrRestUrl: data['asr_rest_url'],
          ttsUrl: data['tts_url'],
          picovoiceAccessKey: data['picovoice_access_key'],
        );

        // 缓存Token
        await _cacheToken(tokenInfo);

        // 设置自动刷新定时器
        _scheduleRefresh(tokenInfo);

        return tokenInfo;
      } else {
        throw VoiceTokenException('获取Token失败: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw VoiceTokenException('请求过于频繁，请稍后重试');
      } else if (e.response?.statusCode == 503) {
        throw VoiceTokenException('语音服务未配置，请使用离线模式');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw VoiceTokenException('网络超时，请检查网络连接');
      }
      throw VoiceTokenException('获取Token失败: ${e.message ?? '未知错误'}');
    }
  }

  /// 检查语音服务状态
  Future<VoiceServiceStatus> checkServiceStatus() async {
    try {
      final response = await _dio.get('/api/v1/voice/token/status');

      if (response.statusCode == 200) {
        return VoiceServiceStatus(
          available: response.data['available'] ?? false,
          message: response.data['message'] ?? '',
        );
      }
    } on DioException catch (e) {
      debugPrint('Check voice service status failed: $e');
    }

    return VoiceServiceStatus(
      available: false,
      message: '无法连接到服务器',
    );
  }

  /// 强制刷新Token
  Future<VoiceTokenInfo> refreshToken() async {
    _cachedToken = null;
    await _clearCachedToken();
    return getToken();
  }

  /// 从安全存储加载缓存的Token
  Future<void> _loadCachedToken() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      final expiresAtStr = await _secureStorage.read(key: _expiresAtKey);
      final appKey = await _secureStorage.read(key: _appKeyKey);
      final asrUrl = await _secureStorage.read(key: _asrUrlKey);
      final ttsUrl = await _secureStorage.read(key: _ttsUrlKey);

      if (token != null && expiresAtStr != null && appKey != null) {
        final expiresAt = DateTime.parse(expiresAtStr);

        // 检查Token是否已过期
        if (DateTime.now().isBefore(expiresAt)) {
          _cachedToken = VoiceTokenInfo(
            token: token,
            expiresAt: expiresAt,
            appKey: appKey,
            asrUrl: asrUrl ?? '',
            asrRestUrl: '',
            ttsUrl: ttsUrl ?? '',
          );

          // 设置刷新定时器
          _scheduleRefresh(_cachedToken!);

          debugPrint('Loaded cached voice token, expires at: $expiresAt');
        } else {
          // Token已过期，清除缓存
          await _clearCachedToken();
        }
      }
    } catch (e) {
      debugPrint('Failed to load cached token: $e');
    }
  }

  /// 缓存Token到安全存储
  Future<void> _cacheToken(VoiceTokenInfo tokenInfo) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: tokenInfo.token);
      await _secureStorage.write(
          key: _expiresAtKey, value: tokenInfo.expiresAt.toIso8601String());
      await _secureStorage.write(key: _appKeyKey, value: tokenInfo.appKey);
      await _secureStorage.write(key: _asrUrlKey, value: tokenInfo.asrUrl);
      await _secureStorage.write(key: _ttsUrlKey, value: tokenInfo.ttsUrl);

      _cachedToken = tokenInfo;

      debugPrint('Cached voice token, expires at: ${tokenInfo.expiresAt}');
    } catch (e) {
      debugPrint('Failed to cache token: $e');
    }
  }

  /// 清除缓存的Token
  Future<void> _clearCachedToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _expiresAtKey);
      await _secureStorage.delete(key: _appKeyKey);
      await _secureStorage.delete(key: _asrUrlKey);
      await _secureStorage.delete(key: _ttsUrlKey);

      _cachedToken = null;
    } catch (e) {
      debugPrint('Failed to clear cached token: $e');
    }
  }

  /// 设置自动刷新定时器
  void _scheduleRefresh(VoiceTokenInfo tokenInfo) {
    _refreshTimer?.cancel();

    // 在过期前5分钟刷新
    final refreshTime = tokenInfo.expiresAt.subtract(const Duration(minutes: 5));
    final now = DateTime.now();

    if (refreshTime.isAfter(now)) {
      final delay = refreshTime.difference(now);
      _refreshTimer = Timer(delay, () async {
        await _autoRefreshWithRetry();
      });

      debugPrint('Scheduled token refresh in ${delay.inMinutes} minutes');
    }
  }

  /// 自动刷新带重试
  Future<void> _autoRefreshWithRetry() async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await refreshToken();
        debugPrint('Voice token auto-refreshed');
        return;
      } catch (e) {
        debugPrint('Failed to auto-refresh token (attempt ${attempt + 1}/$_maxRetries): $e');

        if (attempt < _maxRetries - 1) {
          // 指数退避重试
          final delay = _baseRetryDelay * (1 << attempt);
          await Future.delayed(delay);
        }
      }
    }

    // 所有重试都失败，设置一个短期重试定时器
    debugPrint('All auto-refresh attempts failed, scheduling retry in 1 minute');
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(minutes: 1), () async {
      await _autoRefreshWithRetry();
    });
  }

  /// 释放资源
  void dispose() {
    _refreshTimer?.cancel();
    _dio.close();
  }
}

/// 语音服务Token信息
class VoiceTokenInfo {
  final String token;
  final DateTime expiresAt;
  final String appKey;
  final String asrUrl;
  final String asrRestUrl;
  final String ttsUrl;
  final String? picovoiceAccessKey;

  VoiceTokenInfo({
    required this.token,
    required this.expiresAt,
    required this.appKey,
    required this.asrUrl,
    required this.asrRestUrl,
    required this.ttsUrl,
    this.picovoiceAccessKey,
  });

  /// 是否即将过期（5分钟内）
  bool get isExpiringSoon {
    return DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));
  }

  /// 是否已过期
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  /// 剩余有效时间
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  @override
  String toString() {
    return 'VoiceTokenInfo(expiresAt: $expiresAt, appKey: $appKey)';
  }
}

/// 语音服务状态
class VoiceServiceStatus {
  final bool available;
  final String message;

  VoiceServiceStatus({
    required this.available,
    required this.message,
  });
}

/// 语音Token异常
class VoiceTokenException implements Exception {
  final String message;

  VoiceTokenException(this.message);

  @override
  String toString() => 'VoiceTokenException: $message';
}
