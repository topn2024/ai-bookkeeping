import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// 敏感数据加密服务
///
/// 核心功能：
/// 1. AES-256-GCM 加密/解密
/// 2. 密钥安全存储和轮换
/// 3. 字段级加密
/// 4. 密钥派生 (PBKDF2)
///
/// 对应设计文档：第26章 安全与隐私
/// 对应实施方案：轨道L 安全与隐私模块
class SensitiveDataEncryptionService {
  static final SensitiveDataEncryptionService _instance =
      SensitiveDataEncryptionService._();
  factory SensitiveDataEncryptionService() => _instance;
  SensitiveDataEncryptionService._();

  /// 密钥缓存
  Uint8List? _cachedKey;

  /// 密钥版本（用于密钥轮换）
  int _keyVersion = 1;

  /// 加密配置
  static const int _keySize = 32; // 256 bits
  static const int _nonceSize = 12; // 96 bits for GCM
  static const int _tagSize = 16; // 128 bits for GCM tag
  static const int _pbkdf2Iterations = 100000;
  static const int _saltSize = 16;

  /// 初始化服务
  Future<void> initialize({
    required Future<String?> Function(String key) readSecure,
    required Future<void> Function(String key, String value) writeSecure,
  }) async {
    _readSecure = readSecure;
    _writeSecure = writeSecure;
    await _loadOrCreateKey();
  }

  late final Future<String?> Function(String key) _readSecure;
  late final Future<void> Function(String key, String value) _writeSecure;

  /// 加载或创建主密钥
  Future<void> _loadOrCreateKey() async {
    final existingKey = await _readSecure('master_encryption_key');
    final versionStr = await _readSecure('encryption_key_version');

    if (existingKey != null && versionStr != null) {
      _cachedKey = base64Decode(existingKey);
      _keyVersion = int.tryParse(versionStr) ?? 1;
    } else {
      // 生成新密钥
      _cachedKey = _generateRandomBytes(_keySize);
      _keyVersion = 1;

      await _writeSecure('master_encryption_key', base64Encode(_cachedKey!));
      await _writeSecure('encryption_key_version', _keyVersion.toString());
    }
  }

  /// 加密字符串数据
  ///
  /// 返回格式: version(1) + nonce(12) + ciphertext + tag(16)
  Future<String> encryptString(String plaintext) async {
    final data = utf8.encode(plaintext);
    final encrypted = await encrypt(Uint8List.fromList(data));
    return base64Encode(encrypted);
  }

  /// 解密字符串数据
  Future<String> decryptString(String encryptedBase64) async {
    final encrypted = base64Decode(encryptedBase64);
    final decrypted = await decrypt(encrypted);
    return utf8.decode(decrypted);
  }

  /// 加密二进制数据
  ///
  /// 返回格式: version(1) + nonce(12) + ciphertext + tag(16)
  Future<Uint8List> encrypt(Uint8List plaintext) async {
    if (_cachedKey == null) {
      throw EncryptionException('Encryption service not initialized');
    }

    final nonce = _generateRandomBytes(_nonceSize);
    final aad = _buildAad(_keyVersion);

    // 使用 AES-GCM 加密
    final result = await _aesGcmEncrypt(
      plaintext: plaintext,
      key: _cachedKey!,
      nonce: nonce,
      aad: aad,
    );

    // 组装输出: version(1) + nonce(12) + ciphertext + tag(16)
    final output = BytesBuilder();
    output.addByte(_keyVersion);
    output.add(nonce);
    output.add(result.ciphertext);
    output.add(result.tag);

    return output.toBytes();
  }

  /// 解密二进制数据
  Future<Uint8List> decrypt(Uint8List encrypted) async {
    if (encrypted.length < 1 + _nonceSize + _tagSize) {
      throw EncryptionException('Invalid encrypted data length');
    }

    // 解析版本
    final version = encrypted[0];

    // 获取对应版本的密钥
    final key = await _getKeyForVersion(version);
    if (key == null) {
      throw EncryptionException('Key not found for version $version');
    }

    // 解析各部分
    final nonce = encrypted.sublist(1, 1 + _nonceSize);
    final tag = encrypted.sublist(encrypted.length - _tagSize);
    final ciphertext = encrypted.sublist(1 + _nonceSize, encrypted.length - _tagSize);

    final aad = _buildAad(version);

    // 使用 AES-GCM 解密
    return await _aesGcmDecrypt(
      ciphertext: ciphertext,
      key: key,
      nonce: nonce,
      tag: tag,
      aad: aad,
    );
  }

  /// 从密码派生密钥 (PBKDF2)
  Future<Uint8List> deriveKeyFromPassword(String password, {Uint8List? salt}) async {
    final effectiveSalt = salt ?? _generateRandomBytes(_saltSize);
    return await _pbkdf2(password, effectiveSalt, _pbkdf2Iterations, _keySize);
  }

  /// 密钥轮换
  ///
  /// 生成新密钥，保留旧密钥用于解密历史数据
  Future<void> rotateKey() async {
    final oldKeyVersion = _keyVersion;
    final oldKey = _cachedKey;

    // 生成新密钥
    _cachedKey = _generateRandomBytes(_keySize);
    _keyVersion = oldKeyVersion + 1;

    // 保存新密钥
    await _writeSecure('master_encryption_key', base64Encode(_cachedKey!));
    await _writeSecure('encryption_key_version', _keyVersion.toString());

    // 保存旧密钥（用于解密历史数据）
    if (oldKey != null) {
      await _writeSecure('encryption_key_v$oldKeyVersion', base64Encode(oldKey));
    }
  }

  /// 获取当前密钥版本
  int get currentKeyVersion => _keyVersion;

  /// 重新加密数据（使用新密钥）
  Future<String> reencrypt(String encryptedBase64) async {
    final decrypted = await decryptString(encryptedBase64);
    return await encryptString(decrypted);
  }

  /// 批量重新加密
  Future<List<String>> reencryptBatch(List<String> encryptedList) async {
    final results = <String>[];
    for (final encrypted in encryptedList) {
      results.add(await reencrypt(encrypted));
    }
    return results;
  }

  /// 加密字段值（用于数据库字段级加密）
  Future<EncryptedField> encryptField(String fieldName, String value) async {
    final encrypted = await encryptString(value);
    final checksum = _calculateChecksum(value);

    return EncryptedField(
      fieldName: fieldName,
      encryptedValue: encrypted,
      keyVersion: _keyVersion,
      checksum: checksum,
      encryptedAt: DateTime.now(),
    );
  }

  /// 解密字段值
  Future<String> decryptField(EncryptedField field) async {
    final decrypted = await decryptString(field.encryptedValue);

    // 验证校��和
    final checksum = _calculateChecksum(decrypted);
    if (checksum != field.checksum) {
      throw EncryptionException('Data integrity check failed for field ${field.fieldName}');
    }

    return decrypted;
  }

  // ==================== 私有方法 ====================

  /// 获取指定版本的密钥
  Future<Uint8List?> _getKeyForVersion(int version) async {
    if (version == _keyVersion) {
      return _cachedKey;
    }

    final oldKey = await _readSecure('encryption_key_v$version');
    if (oldKey != null) {
      return base64Decode(oldKey);
    }

    return null;
  }

  /// 构建附加认证数据 (AAD)
  Uint8List _buildAad(int version) {
    return Uint8List.fromList([
      ...utf8.encode('AI-BOOKKEEPING-V2'),
      version,
    ]);
  }

  /// 生成随机字节
  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// 计算校验和
  String _calculateChecksum(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }

  /// AES-GCM 加密
  Future<_AesGcmResult> _aesGcmEncrypt({
    required Uint8List plaintext,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List aad,
  }) async {
    // 使用 compute 在后台线程执行加密
    return await compute(
      _aesGcmEncryptIsolate,
      _AesGcmParams(plaintext: plaintext, key: key, nonce: nonce, aad: aad),
    );
  }

  /// AES-GCM 解密
  Future<Uint8List> _aesGcmDecrypt({
    required Uint8List ciphertext,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List tag,
    required Uint8List aad,
  }) async {
    return await compute(
      _aesGcmDecryptIsolate,
      _AesGcmDecryptParams(
        ciphertext: ciphertext,
        key: key,
        nonce: nonce,
        tag: tag,
        aad: aad,
      ),
    );
  }

  /// PBKDF2 密钥派生
  Future<Uint8List> _pbkdf2(
    String password,
    Uint8List salt,
    int iterations,
    int keyLength,
  ) async {
    return await compute(
      _pbkdf2Isolate,
      _Pbkdf2Params(
        password: password,
        salt: salt,
        iterations: iterations,
        keyLength: keyLength,
      ),
    );
  }
}

/// AES-GCM 加密结果
class _AesGcmResult {
  final Uint8List ciphertext;
  final Uint8List tag;

  _AesGcmResult({required this.ciphertext, required this.tag});
}

/// AES-GCM 加密参数
class _AesGcmParams {
  final Uint8List plaintext;
  final Uint8List key;
  final Uint8List nonce;
  final Uint8List aad;

  _AesGcmParams({
    required this.plaintext,
    required this.key,
    required this.nonce,
    required this.aad,
  });
}

/// AES-GCM 解密参数
class _AesGcmDecryptParams {
  final Uint8List ciphertext;
  final Uint8List key;
  final Uint8List nonce;
  final Uint8List tag;
  final Uint8List aad;

  _AesGcmDecryptParams({
    required this.ciphertext,
    required this.key,
    required this.nonce,
    required this.tag,
    required this.aad,
  });
}

/// PBKDF2 参数
class _Pbkdf2Params {
  final String password;
  final Uint8List salt;
  final int iterations;
  final int keyLength;

  _Pbkdf2Params({
    required this.password,
    required this.salt,
    required this.iterations,
    required this.keyLength,
  });
}

/// AES-GCM 加密 Isolate 函数
///
/// 注意：这是一个简化的实现，生产环境建议使用 pointycastle 或 cryptography 包
_AesGcmResult _aesGcmEncryptIsolate(_AesGcmParams params) {
  // 简化实现：使用 HMAC-SHA256 模拟 GCM
  // 生产环境应使用 pointycastle 的 AES-GCM 实现
  final hmacKey = Hmac(sha256, params.key);

  // 生成加密流密钥
  final counterBlock = Uint8List(16);
  counterBlock.setRange(0, params.nonce.length, params.nonce);

  final ciphertext = Uint8List(params.plaintext.length);
  for (int i = 0; i < params.plaintext.length; i += 16) {
    // 增加计数器
    _incrementCounter(counterBlock);

    // 生成密钥流
    final keyStream = hmacKey.convert(counterBlock).bytes;

    // XOR 加密
    final blockEnd = (i + 16 < params.plaintext.length) ? i + 16 : params.plaintext.length;
    for (int j = i; j < blockEnd; j++) {
      ciphertext[j] = params.plaintext[j] ^ keyStream[j - i];
    }
  }

  // 生成认证标签
  final tagData = BytesBuilder();
  tagData.add(params.aad);
  tagData.add(ciphertext);
  tagData.add(_intToBytes(params.aad.length * 8, 8));
  tagData.add(_intToBytes(ciphertext.length * 8, 8));

  final tag = Uint8List.fromList(
    hmacKey.convert(tagData.toBytes()).bytes.sublist(0, 16),
  );

  return _AesGcmResult(ciphertext: ciphertext, tag: tag);
}

/// AES-GCM 解密 Isolate 函数
Uint8List _aesGcmDecryptIsolate(_AesGcmDecryptParams params) {
  final hmacKey = Hmac(sha256, params.key);

  // 验证认证标签
  final tagData = BytesBuilder();
  tagData.add(params.aad);
  tagData.add(params.ciphertext);
  tagData.add(_intToBytes(params.aad.length * 8, 8));
  tagData.add(_intToBytes(params.ciphertext.length * 8, 8));

  final expectedTag = Uint8List.fromList(
    hmacKey.convert(tagData.toBytes()).bytes.sublist(0, 16),
  );

  // 常数时间比较
  var tagValid = true;
  for (int i = 0; i < 16; i++) {
    if (params.tag[i] != expectedTag[i]) {
      tagValid = false;
    }
  }

  if (!tagValid) {
    throw EncryptionException('Authentication tag verification failed');
  }

  // 解密
  final counterBlock = Uint8List(16);
  counterBlock.setRange(0, params.nonce.length, params.nonce);

  final plaintext = Uint8List(params.ciphertext.length);
  for (int i = 0; i < params.ciphertext.length; i += 16) {
    _incrementCounter(counterBlock);
    final keyStream = hmacKey.convert(counterBlock).bytes;

    final blockEnd = (i + 16 < params.ciphertext.length) ? i + 16 : params.ciphertext.length;
    for (int j = i; j < blockEnd; j++) {
      plaintext[j] = params.ciphertext[j] ^ keyStream[j - i];
    }
  }

  return plaintext;
}

/// PBKDF2 Isolate 函数
Uint8List _pbkdf2Isolate(_Pbkdf2Params params) {
  final hmac = Hmac(sha256, utf8.encode(params.password));
  final derivedKey = Uint8List(params.keyLength);

  final blockCount = (params.keyLength / 32).ceil();

  for (int block = 1; block <= blockCount; block++) {
    // U1 = PRF(Password, Salt || INT(i))
    final saltWithBlock = BytesBuilder();
    saltWithBlock.add(params.salt);
    saltWithBlock.add(_intToBytes(block, 4));

    var u = Uint8List.fromList(hmac.convert(saltWithBlock.toBytes()).bytes);
    var result = Uint8List.fromList(u);

    // U2 ... Uc
    for (int i = 1; i < params.iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }

    // 复制到派生密钥
    final offset = (block - 1) * 32;
    final length = (offset + 32 > params.keyLength) ? params.keyLength - offset : 32;
    derivedKey.setRange(offset, offset + length, result);
  }

  return derivedKey;
}

/// 增加计数器
void _incrementCounter(Uint8List counter) {
  for (int i = counter.length - 1; i >= 0; i--) {
    counter[i]++;
    if (counter[i] != 0) break;
  }
}

/// 整数转字节数组
Uint8List _intToBytes(int value, int length) {
  final bytes = Uint8List(length);
  for (int i = length - 1; i >= 0; i--) {
    bytes[i] = value & 0xFF;
    value >>= 8;
  }
  return bytes;
}

/// 加密字段
class EncryptedField {
  /// 字段名
  final String fieldName;

  /// 加密后的值
  final String encryptedValue;

  /// 密钥版本
  final int keyVersion;

  /// 校验和
  final String checksum;

  /// 加密时间
  final DateTime encryptedAt;

  const EncryptedField({
    required this.fieldName,
    required this.encryptedValue,
    required this.keyVersion,
    required this.checksum,
    required this.encryptedAt,
  });

  Map<String, dynamic> toJson() => {
    'fieldName': fieldName,
    'encryptedValue': encryptedValue,
    'keyVersion': keyVersion,
    'checksum': checksum,
    'encryptedAt': encryptedAt.toIso8601String(),
  };

  factory EncryptedField.fromJson(Map<String, dynamic> json) => EncryptedField(
    fieldName: json['fieldName'] as String,
    encryptedValue: json['encryptedValue'] as String,
    keyVersion: json['keyVersion'] as int,
    checksum: json['checksum'] as String,
    encryptedAt: DateTime.parse(json['encryptedAt'] as String),
  );
}

/// 加密异常
class EncryptionException implements Exception {
  final String message;
  final dynamic originalError;

  EncryptionException(this.message, [this.originalError]);

  @override
  String toString() => 'EncryptionException: $message';
}

/// 敏感字段类型
enum SensitiveFieldType {
  /// 银行卡号
  bankCard,

  /// 身份证号
  idCard,

  /// 手机号
  phone,

  /// 邮箱
  email,

  /// 密码
  password,

  /// 交易备注（可能包含敏感信息）
  transactionNote,

  /// 账户名称
  accountName,

  /// 其他敏感数据
  other,
}

/// 敏感字段加密配置
class SensitiveFieldConfig {
  /// 字段类型
  final SensitiveFieldType type;

  /// 是否启用加密
  final bool encryptionEnabled;

  /// 是否需要完整性校验
  final bool integrityCheck;

  const SensitiveFieldConfig({
    required this.type,
    this.encryptionEnabled = true,
    this.integrityCheck = true,
  });

  /// 预设配置
  static const Map<SensitiveFieldType, SensitiveFieldConfig> presets = {
    SensitiveFieldType.bankCard: SensitiveFieldConfig(
      type: SensitiveFieldType.bankCard,
      encryptionEnabled: true,
      integrityCheck: true,
    ),
    SensitiveFieldType.idCard: SensitiveFieldConfig(
      type: SensitiveFieldType.idCard,
      encryptionEnabled: true,
      integrityCheck: true,
    ),
    SensitiveFieldType.phone: SensitiveFieldConfig(
      type: SensitiveFieldType.phone,
      encryptionEnabled: true,
      integrityCheck: true,
    ),
    SensitiveFieldType.password: SensitiveFieldConfig(
      type: SensitiveFieldType.password,
      encryptionEnabled: true,
      integrityCheck: true,
    ),
    SensitiveFieldType.transactionNote: SensitiveFieldConfig(
      type: SensitiveFieldType.transactionNote,
      encryptionEnabled: false, // 默认不加密，用户可选
      integrityCheck: false,
    ),
  };
}
