import 'dart:io';
import 'package:dio/dio.dart';

/// HTTP 服务接口
///
/// 定义应用程序 HTTP 请求操作的抽象接口。
/// 支持 RESTful API 调用、文件上传、Token 管理等功能。
abstract class IHttpService {
  /// 获取当前 API 基础 URL
  String get baseUrl;

  /// 获取当前 API 版本
  String get currentApiVersion;

  /// 获取服务器要求的最低版本
  String? get serverMinVersion;

  /// 初始化服务
  Future<void> initialize();

  /// 设置认证 Token
  Future<void> setAuthToken(String? token);

  /// 设置 Token（包括访问令牌和刷新令牌）
  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// 清除所有 Token
  Future<void> clearTokens();

  /// 检查是否有有效的 Token
  Future<bool> hasValidToken();

  /// 设置升级需求回调
  void setUpgradeRequiredCallback(Function(dynamic data) callback);

  // ==================== HTTP 请求方法 ====================

  /// GET 请求
  Future<Response> get(String path, {Map<String, dynamic>? queryParams});

  /// POST 请求
  Future<Response> post(String path, {dynamic data});

  /// PUT 请求
  Future<Response> put(String path, {dynamic data});

  /// PATCH 请求
  Future<Response> patch(String path, {dynamic data});

  /// DELETE 请求
  Future<Response> delete(String path);

  // ==================== 文件上传 ====================

  /// 上传图片文件
  Future<Response> uploadImage(String path, File imageFile);

  /// 上传 Base64 编码的图片
  Future<Response> uploadBase64Image(String path, String base64Image);
}
