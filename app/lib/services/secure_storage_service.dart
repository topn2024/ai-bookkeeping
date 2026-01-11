import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/contracts/i_secure_storage_service.dart';

/// 安全存储服务 - 用于存储敏感信息（Token、密钥等）
class SecureStorageService implements ISecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // 安全存储实例，使用加密选项
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // 存储键常量
  static const String _authTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _apiKeyKey = 'api_key';
  static const String _encryptionKeyKey = 'encryption_key';

  // ==================== Token 管理 ====================

  /// 保存认证Token
  @override
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _authTokenKey, value: token);
  }

  /// 获取认证Token
  @override
  Future<String?> getAuthToken() async {
    return await _storage.read(key: _authTokenKey);
  }

  /// 删除认证Token
  @override
  Future<void> deleteAuthToken() async {
    await _storage.delete(key: _authTokenKey);
  }

  /// 保存刷新Token
  @override
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// 获取刷新Token
  @override
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// 删除刷新Token
  @override
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  // ==================== 用户信息 ====================

  /// 保存用户ID
  @override
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  /// 获取用户ID
  @override
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  // ==================== API密钥 ====================

  /// 保存API密钥
  @override
  Future<void> saveApiKey(String key) async {
    await _storage.write(key: _apiKeyKey, value: key);
  }

  /// 获取API密钥
  @override
  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  // ==================== 加密密钥 ====================

  /// 保存加密密钥
  @override
  Future<void> saveEncryptionKey(String key) async {
    await _storage.write(key: _encryptionKeyKey, value: key);
  }

  /// 获取加密密钥
  @override
  Future<String?> getEncryptionKey() async {
    return await _storage.read(key: _encryptionKeyKey);
  }

  // ==================== 通用方法 ====================

  /// 保存任意键值对
  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// 读取任意键值
  @override
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// 删除任意键值
  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// 检查键是否存在
  @override
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  /// 保存JSON对象
  @override
  Future<void> writeJson(String key, Map<String, dynamic> json) async {
    final jsonString = jsonEncode(json);
    await _storage.write(key: key, value: jsonString);
  }

  /// 读取JSON对象
  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final jsonString = await _storage.read(key: key);
    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// 清除所有存储的数据
  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// 获取所有存储的键
  @override
  Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }

  // ==================== 登出清理 ====================

  /// 登出时清理所有敏感数据
  @override
  Future<void> clearOnLogout() async {
    await deleteAuthToken();
    await deleteRefreshToken();
    await _storage.delete(key: _userIdKey);
  }
}
