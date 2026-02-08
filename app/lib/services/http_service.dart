import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';
import 'app_config_service.dart';
import '../core/contracts/i_http_service.dart';
import '../core/config/config.dart';

class HttpService implements IHttpService {
  static final HttpService _instance = HttpService._internal();
  late Dio _dio;
  final SecureStorageService _secureStorage = SecureStorageService();
  final AppConfigService _configService = AppConfigService();

  // 默认配置 - 使用集中化配置
  static String get _defaultApiBaseUrl => ApiEndpoints.apiBaseUrl;

  // API 版本（与服务器 APIVersionConfig 保持同步）
  static const String apiVersion = '1.0.0';

  String? _authToken;
  bool _initialized = false;

  // Token 刷新锁：防止多个并发 401 请求同时刷新 Token
  Completer<bool>? _refreshCompleter;

  // 服务器返回的最低支持版本
  String? _serverMinVersion;

  // 升级需求回调（426 响应时触发）
  Function(dynamic data)? _onUpgradeRequired;

  factory HttpService() => _instance;

  /// 设置升级需求回调
  @override
  void setUpgradeRequiredCallback(Function(dynamic data) callback) {
    _onUpgradeRequired = callback;
  }

  /// 获取当前 API 版本
  @override
  String get currentApiVersion => apiVersion;

  /// 获取服务器要求的最低版本
  @override
  String? get serverMinVersion => _serverMinVersion;

  HttpService._internal() {
    _initDio();
  }

  /// 获取当前 API 基础 URL
  @override
  String get baseUrl {
    if (_configService.isInitialized) {
      return _configService.config.apiBaseUrl;
    }
    return _defaultApiBaseUrl;
  }

  /// 是否跳过证书验证
  bool get _skipCertificateVerification {
    if (_configService.isInitialized) {
      return _configService.config.skipCertificateVerification;
    }
    // 配置未初始化时，使用与 AppConfigService 一致的默认值
    // 服务器目前使用 IP 地址 + 自签名证书，需要跳过验证
    return true;
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: _configService.isInitialized
          ? _configService.config.network.connectTimeoutSeconds
          : 30),
      receiveTimeout: Duration(seconds: _configService.isInitialized
          ? _configService.config.network.receiveTimeoutSeconds
          : 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-Version': apiVersion,
      },
    ));

    // 配置 SSL 证书验证
    _configureSslVerification();

    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 优先使用内存中的token，否则从安全存储读取
        final token = _authToken ?? await _secureStorage.getAuthToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // 记录服务器返回的最低版本要求
        final minVersion = response.headers.value('X-API-Min-Version');
        if (minVersion != null) {
          _serverMinVersion = minVersion;
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        // 426错误：API版本过旧，需要升级应用
        if (error.response?.statusCode == 426) {
          _onUpgradeRequired?.call(error.response?.data);
          return handler.next(error);
        }

        // 401错误：Token过期，尝试刷新
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            // 重试原请求
            final opts = error.requestOptions;
            final token = await _secureStorage.getAuthToken();
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  /// 配置 SSL 证书验证
  void _configureSslVerification() {
    if (kDebugMode) {
      debugPrint('[HttpService] SSL verification: skipCert=$_skipCertificateVerification');
    }

    if (_skipCertificateVerification) {
      // 仅在配置明确要求时跳过证书验证（如开发环境或自签名证书）
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
    }
    // 未跳过时使用系统默认的证书验证
  }

  /// 初始化：从安全存储加载Token
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _authToken = await _secureStorage.getAuthToken();
    _initialized = true;
  }

  /// 重新初始化 Dio（配置更新后调用）
  void reinitialize() {
    _initDio();
  }

  /// 尝试刷新Token（带并发锁）
  Future<bool> _tryRefreshToken() async {
    // 如果已有刷新请求在进行中，等待其结果
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
    }
    _refreshCompleter = Completer<bool>();
    try {
      final result = await _doRefreshToken();
      _refreshCompleter!.complete(result);
      return result;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// 执行实际的Token刷新逻辑
  Future<bool> _doRefreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      // Create a new Dio instance without interceptors to avoid infinite loop
      final refreshDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      // Skip SSL verification if needed
      if (_skipCertificateVerification) {
        refreshDio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.badCertificateCallback = (cert, host, port) => true;
            return client;
          },
        );
      }

      final response = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newToken = response.data['access_token'] as String;
        final newRefreshToken = response.data['refresh_token'] as String?;

        await setAuthToken(newToken);
        if (newRefreshToken != null) {
          await _secureStorage.saveRefreshToken(newRefreshToken);
        }
        return true;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await setAuthToken(null);
        await _secureStorage.deleteRefreshToken();
        debugPrint('[HttpService] Token refresh auth failed, cleared tokens');
      } else {
        debugPrint('[HttpService] Token refresh network error: ${e.type}');
      }
    } catch (e) {
      debugPrint('[HttpService] Token refresh unexpected error: $e');
    }
    return false;
  }

  /// 设置认证Token（同时保存到安全存储）
  @override
  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    if (token != null) {
      await _secureStorage.saveAuthToken(token);
    } else {
      await _secureStorage.deleteAuthToken();
    }
  }

  /// 设置Token（带刷新Token）
  @override
  Future<void> setTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await setAuthToken(accessToken);
    if (refreshToken != null) {
      await _secureStorage.saveRefreshToken(refreshToken);
    }
  }

  /// 清除所有Token（登出时调用）
  @override
  Future<void> clearTokens() async {
    _authToken = null;
    await _secureStorage.clearOnLogout();
  }

  /// 检查是否有有效Token
  @override
  Future<bool> hasValidToken() async {
    final token = _authToken ?? await _secureStorage.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    return await _dio.get(path, queryParameters: queryParams);
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    if (kDebugMode) {
      debugPrint('[HttpService] POST $path');
    }
    return await _dio.post(path, data: data);
  }

  @override
  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  @override
  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  @override
  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  /// 上传图片文件
  @override
  Future<Response> uploadImage(String path, File imageFile) async {
    final fileName = imageFile.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
      ),
    });

    return await _dio.post(
      path,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
  }

  /// 上传Base64图片
  @override
  Future<Response> uploadBase64Image(String path, String base64Image) async {
    return await _dio.post(path, data: {
      'image_base64': base64Image,
    });
  }
}
