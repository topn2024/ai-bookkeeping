import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'secure_storage_service.dart';
import 'app_config_service.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  late Dio _dio;
  final SecureStorageService _secureStorage = SecureStorageService();
  final AppConfigService _configService = AppConfigService();

  // 默认配置（仅在配置服务未初始化时使用）
  static const String _defaultApiBaseUrl = 'https://160.202.238.29/api/v1';

  String? _authToken;
  bool _initialized = false;

  factory HttpService() => _instance;

  HttpService._internal() {
    _initDio();
  }

  /// 获取当前 API 基础 URL
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
    // 默认不跳过验证（安全优先）
    return false;
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
      onError: (error, handler) async {
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
    if (_skipCertificateVerification) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
    }
  }

  /// 初始化：从安全存储加载Token
  Future<void> initialize() async {
    if (_initialized) return;
    _authToken = await _secureStorage.getAuthToken();
    _initialized = true;
  }

  /// 重新初始化 Dio（配置更新后调用）
  void reinitialize() {
    _initDio();
  }

  /// 尝试刷新Token
  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _dio.post(
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
    } catch (e) {
      // 刷新失败，需要重新登录
    }
    return false;
  }

  /// 设置认证Token（同时保存到安全存储）
  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    if (token != null) {
      await _secureStorage.saveAuthToken(token);
    } else {
      await _secureStorage.deleteAuthToken();
    }
  }

  /// 设置Token（带刷新Token）
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
  Future<void> clearTokens() async {
    _authToken = null;
    await _secureStorage.clearOnLogout();
  }

  /// 检查是否有有效Token
  Future<bool> hasValidToken() async {
    final token = _authToken ?? await _secureStorage.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) async {
    return await _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  /// 上传图片文件
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
  Future<Response> uploadBase64Image(String path, String base64Image) async {
    return await _dio.post(path, data: {
      'image_base64': base64Image,
    });
  }
}
