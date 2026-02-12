import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// 加密服务 - 提供密码哈希和数据加密功能
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // 用于密码哈希的盐值前缀
  static const String _saltPrefix = 'ai_bookkeeping_';

  // 用于HMAC-SHA256 CTR模式加密的密钥
  static const String _encryptionKey = 'ai_bookkeeping_secure_enc_key_v2';

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

  /// 生成HMAC-SHA256 CTR模式的密钥流
  /// 使用IV和计数器生成伪随机字节流，用于XOR加解密
  Uint8List _generateKeyStream(Uint8List iv, int length) {
    final hmacSha256 = Hmac(sha256, utf8.encode(_encryptionKey));
    final keyStream = BytesBuilder();
    var counter = 0;

    while (keyStream.length < length) {
      // 构造 IV + counter 作为 HMAC 输入
      final counterBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, counter, Endian.big);
      final input = Uint8List(iv.length + counterBytes.length)
        ..setRange(0, iv.length, iv)
        ..setRange(iv.length, iv.length + counterBytes.length, counterBytes);

      final block = hmacSha256.convert(input);
      keyStream.add(block.bytes);
      counter++;
    }

    return Uint8List.fromList(keyStream.toBytes().sublist(0, length));
  }

  /// 加密数据（使用HMAC-SHA256 CTR模式）
  /// 生成随机IV，使用HMAC-SHA256生成密钥流，XOR明文
  /// 返回 base64(IV + ciphertext)
  Future<String> encrypt(String data) async {
    final random = Random.secure();
    final iv = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    final plaintext = utf8.encode(data);
    final keyStream = _generateKeyStream(iv, plaintext.length);

    // XOR明文和密钥流
    final ciphertext = Uint8List(plaintext.length);
    for (var i = 0; i < plaintext.length; i++) {
      ciphertext[i] = plaintext[i] ^ keyStream[i];
    }

    // 拼接 IV + ciphertext 并进行Base64编码
    final combined = Uint8List(iv.length + ciphertext.length)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + ciphertext.length, ciphertext);

    return base64.encode(combined);
  }

  /// 解密数据（使用HMAC-SHA256 CTR模式）
  /// 从密文中提取IV，重新生成密钥流，XOR恢复明文
  /// 向后兼容旧版Base64混淆格式
  Future<String> decrypt(String encryptedData) async {
    try {
      final combined = base64.decode(encryptedData);

      // 新格式要求至少有16字节IV + 1字节密文
      if (combined.length > 16) {
        final iv = Uint8List.fromList(combined.sublist(0, 16));
        final ciphertext = Uint8List.fromList(combined.sublist(16));

        final keyStream = _generateKeyStream(iv, ciphertext.length);

        // XOR密文和密钥流恢复明文
        final plaintext = Uint8List(ciphertext.length);
        for (var i = 0; i < ciphertext.length; i++) {
          plaintext[i] = ciphertext[i] ^ keyStream[i];
        }

        final result = utf8.decode(plaintext);

        // 验证解密结果是有效的UTF-8字符串（非乱码）
        // 如果解密结果包含旧格式前缀，说明误解了旧数据，回退
        if (!result.startsWith('${_saltPrefix}enc_')) {
          return result;
        }
      }
    } catch (_) {
      // 解密失败，回退到旧版Base64混淆格式
    }

    // 向后兼容：旧版Base64混淆格式
    try {
      final decoded = decodeBase64(encryptedData);
      final prefix = '${_saltPrefix}enc_';
      if (decoded.startsWith(prefix)) {
        return decoded.substring(prefix.length);
      }
      return decoded;
    } catch (_) {
      return encryptedData;
    }
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
