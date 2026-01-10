import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 加密服务 - 提供密码哈希和数据加密功能
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // 用于密码哈希的盐值前缀
  static const String _saltPrefix = 'ai_bookkeeping_';

  /// 对密码进行SHA256哈希
  /// 使用固定盐值+密码的方式生成哈希
  String hashPassword(String password, {String? salt}) {
    final effectiveSalt = salt ?? _saltPrefix;
    final bytes = utf8.encode('$effectiveSalt$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 验证密码是否匹配
  bool verifyPassword(String password, String hashedPassword, {String? salt}) {
    final hash = hashPassword(password, salt: salt);
    return hash == hashedPassword;
  }

  /// 生成随机盐值
  String generateSalt() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final bytes = utf8.encode('$_saltPrefix$timestamp');
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 对敏感数据进行HMAC签名
  String signData(String data, String secretKey) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// 验证HMAC签名
  bool verifySignature(String data, String signature, String secretKey) {
    final expectedSignature = signData(data, secretKey);
    return expectedSignature == signature;
  }

  /// 对数据进行Base64编码（用于传输）
  String encodeBase64(String data) {
    final bytes = utf8.encode(data);
    return base64.encode(bytes);
  }

  /// 对Base64数据进行解码
  String decodeBase64(String encodedData) {
    final bytes = base64.decode(encodedData);
    return utf8.decode(bytes);
  }

  /// 加密数据（简易实现，使用Base64编码）
  /// TODO: 在生产环境中应使用AES或其他安全加密算法
  Future<String> encrypt(String data) async {
    // 添加简单的混淆前缀
    final obfuscated = '${_saltPrefix}enc_$data';
    return encodeBase64(obfuscated);
  }

  /// 解密数据
  Future<String> decrypt(String encryptedData) async {
    final decoded = decodeBase64(encryptedData);
    // 移除混淆前缀
    final prefix = '${_saltPrefix}enc_';
    if (decoded.startsWith(prefix)) {
      return decoded.substring(prefix.length);
    }
    return decoded;
  }

  /// 生成用于API请求的签名
  /// 用于验证请求的完整性
  String generateApiSignature({
    required String method,
    required String path,
    required String timestamp,
    required String secretKey,
    Map<String, dynamic>? body,
  }) {
    final bodyString = body != null ? jsonEncode(body) : '';
    final data = '$method|$path|$timestamp|$bodyString';
    return signData(data, secretKey);
  }
}
