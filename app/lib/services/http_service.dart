import 'dart:io';
import 'package:dio/dio.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  late Dio _dio;

  // 服务器地址配置
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';  // Android模拟器
  // static const String baseUrl = 'http://localhost:8000/api/v1';  // iOS模拟器/Web

  String? _authToken;

  factory HttpService() => _instance;

  HttpService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // 统一错误处理
        return handler.next(error);
      },
    ));
  }

  void setAuthToken(String? token) {
    _authToken = token;
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
