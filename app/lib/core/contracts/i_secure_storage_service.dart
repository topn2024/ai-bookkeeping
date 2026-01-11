/// 安全存储服务接口
///
/// 定义应用程序安全存储操作的抽象接口，用于存储敏感信息如 Token、密钥等。
/// 实现类应保证数据的加密存储。
abstract class ISecureStorageService {
  // ==================== Token 管理 ====================

  /// 保存认证 Token
  Future<void> saveAuthToken(String token);

  /// 获取认证 Token
  Future<String?> getAuthToken();

  /// 删除认证 Token
  Future<void> deleteAuthToken();

  /// 保存刷新 Token
  Future<void> saveRefreshToken(String token);

  /// 获取刷新 Token
  Future<String?> getRefreshToken();

  /// 删除刷新 Token
  Future<void> deleteRefreshToken();

  // ==================== 用户信息 ====================

  /// 保存用户 ID
  Future<void> saveUserId(String userId);

  /// 获取用户 ID
  Future<String?> getUserId();

  // ==================== API 密钥 ====================

  /// 保存 API 密钥
  Future<void> saveApiKey(String key);

  /// 获取 API 密钥
  Future<String?> getApiKey();

  // ==================== 加密密钥 ====================

  /// 保存加密密钥
  Future<void> saveEncryptionKey(String key);

  /// 获取加密密钥
  Future<String?> getEncryptionKey();

  // ==================== 通用方法 ====================

  /// 保存任意键值对
  Future<void> write(String key, String value);

  /// 读取任意键值
  Future<String?> read(String key);

  /// 删除任意键值
  Future<void> delete(String key);

  /// 检查键是否存在
  Future<bool> containsKey(String key);

  /// 保存 JSON 对象
  Future<void> writeJson(String key, Map<String, dynamic> json);

  /// 读取 JSON 对象
  Future<Map<String, dynamic>?> readJson(String key);

  /// 清除所有存储的数据
  Future<void> deleteAll();

  /// 获取所有存储的键值对
  Future<Map<String, String>> readAll();

  // ==================== 登出清理 ====================

  /// 登出时清理所有敏感数据
  Future<void> clearOnLogout();
}
