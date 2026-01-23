import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全密钥管理器
///
/// 负责安全存储和管理LLM API密钥
/// 安全策略：
/// - 使用flutter_secure_storage加密存储
/// - 密钥分段存储，增加反编译难度
/// - 运行时动态组装密钥
/// - 支持远程配置更新
/// - 支持密钥有效期检查
class SecureKeyManager {
  /// 安全存储实例
  final FlutterSecureStorage _storage;

  /// 存储键前缀
  static const String _keyPrefix = 'llm_key_';

  /// 分段数量（将密钥分成多个部分存储）
  static const int _segmentCount = 4;

  /// 密钥过期时间键
  static const String _expiryKey = '${_keyPrefix}expiry';

  /// 密钥版本键
  static const String _versionKey = '${_keyPrefix}version';

  /// 密钥校验和键
  static const String _checksumKey = '${_keyPrefix}checksum';

  /// 内存中的密钥缓存（使用后应清除）
  String? _cachedKey;

  /// 是否已初始化
  bool _isInitialized = false;

  SecureKeyManager({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 检查是否有存储的密钥
      final hasKey = await hasStoredKey();
      debugPrint('[SecureKeyManager] 初始化完成，已存储密钥: $hasKey');
      _isInitialized = true;
    } catch (e) {
      debugPrint('[SecureKeyManager] 初始化失败: $e');
      rethrow;
    }
  }

  /// 检查是否有存储的密钥
  Future<bool> hasStoredKey() async {
    try {
      final segment0 = await _storage.read(key: '${_keyPrefix}seg_0');
      return segment0 != null && segment0.isNotEmpty;
    } catch (e) {
      debugPrint('[SecureKeyManager] 检查密钥失败: $e');
      return false;
    }
  }

  /// 存储API密钥
  ///
  /// 将密钥分段加密存储，并添加校验和和版本信息
  Future<void> storeKey({
    required String apiKey,
    required String provider,
    Duration? validityDuration,
    int version = 1,
  }) async {
    if (apiKey.isEmpty) {
      throw ArgumentError('API密钥不能为空');
    }

    try {
      // 1. 计算校验和
      final checksum = _calculateChecksum(apiKey);

      // 2. 混淆并分段存储
      final obfuscated = _obfuscate(apiKey);
      final segments = _splitIntoSegments(obfuscated, _segmentCount);

      // 3. 存储各分段
      for (int i = 0; i < segments.length; i++) {
        await _storage.write(
          key: '${_keyPrefix}seg_$i',
          value: segments[i],
        );
      }

      // 4. 存储提供商信息
      await _storage.write(
        key: '${_keyPrefix}provider',
        value: provider,
      );

      // 5. 存储校验和
      await _storage.write(
        key: _checksumKey,
        value: checksum,
      );

      // 6. 存储版本
      await _storage.write(
        key: _versionKey,
        value: version.toString(),
      );

      // 7. 存储过期时间（如果指定）
      if (validityDuration != null) {
        final expiry = DateTime.now().add(validityDuration);
        await _storage.write(
          key: _expiryKey,
          value: expiry.toIso8601String(),
        );
      } else {
        await _storage.delete(key: _expiryKey);
      }

      debugPrint('[SecureKeyManager] 密钥存储成功 (provider=$provider, version=$version)');
    } catch (e) {
      debugPrint('[SecureKeyManager] 存储密钥失败: $e');
      rethrow;
    }
  }

  /// 获取API密钥
  ///
  /// 从分段存储中恢复密钥，验证校验和
  Future<String?> getKey() async {
    // 优先返回缓存的密钥
    if (_cachedKey != null) {
      return _cachedKey;
    }

    try {
      // 1. 检查是否过期
      if (await isKeyExpired()) {
        debugPrint('[SecureKeyManager] 密钥已过期');
        return null;
      }

      // 2. 读取各分段
      final segments = <String>[];
      for (int i = 0; i < _segmentCount; i++) {
        final segment = await _storage.read(key: '${_keyPrefix}seg_$i');
        if (segment == null) {
          debugPrint('[SecureKeyManager] 缺少密钥分段 $i');
          return null;
        }
        segments.add(segment);
      }

      // 3. 组装并反混淆
      final obfuscated = segments.join('');
      final apiKey = _deobfuscate(obfuscated);

      // 4. 验证校验和
      final storedChecksum = await _storage.read(key: _checksumKey);
      final calculatedChecksum = _calculateChecksum(apiKey);
      if (storedChecksum != calculatedChecksum) {
        debugPrint('[SecureKeyManager] 密钥校验和不匹配');
        return null;
      }

      // 缓存密钥（短期使用）
      _cachedKey = apiKey;

      return apiKey;
    } catch (e) {
      debugPrint('[SecureKeyManager] 获取密钥失败: $e');
      return null;
    }
  }

  /// 获取提供商
  Future<String?> getProvider() async {
    try {
      return await _storage.read(key: '${_keyPrefix}provider');
    } catch (e) {
      debugPrint('[SecureKeyManager] 获取提供商失败: $e');
      return null;
    }
  }

  /// 获取密钥版本
  Future<int> getKeyVersion() async {
    try {
      final version = await _storage.read(key: _versionKey);
      return int.tryParse(version ?? '0') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 检查密钥是否过期
  Future<bool> isKeyExpired() async {
    try {
      final expiryStr = await _storage.read(key: _expiryKey);
      if (expiryStr == null) {
        // 没有设置过期时间，不过期
        return false;
      }

      final expiry = DateTime.parse(expiryStr);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      debugPrint('[SecureKeyManager] 检查过期失败: $e');
      return false;
    }
  }

  /// 获取过期时间
  Future<DateTime?> getExpiryTime() async {
    try {
      final expiryStr = await _storage.read(key: _expiryKey);
      if (expiryStr == null) return null;
      return DateTime.parse(expiryStr);
    } catch (e) {
      return null;
    }
  }

  /// 更新密钥（从远程配置）
  ///
  /// 仅当新版本更高时才更新
  Future<bool> updateKeyIfNewer({
    required String apiKey,
    required String provider,
    required int version,
    Duration? validityDuration,
  }) async {
    final currentVersion = await getKeyVersion();

    if (version <= currentVersion) {
      debugPrint('[SecureKeyManager] 密钥版本不更新 (current=$currentVersion, new=$version)');
      return false;
    }

    await storeKey(
      apiKey: apiKey,
      provider: provider,
      version: version,
      validityDuration: validityDuration,
    );

    // 清除缓存，强制重新加载
    clearCache();

    debugPrint('[SecureKeyManager] 密钥已更新到版本 $version');
    return true;
  }

  /// 清除内存缓存
  void clearCache() {
    if (_cachedKey != null) {
      // 覆盖内存内容后再置空（安全清除）
      _cachedKey = '0' * (_cachedKey?.length ?? 0);
      _cachedKey = null;
    }
  }

  /// 删除所有存储的密钥
  Future<void> deleteAllKeys() async {
    try {
      // 删除所有分段
      for (int i = 0; i < _segmentCount; i++) {
        await _storage.delete(key: '${_keyPrefix}seg_$i');
      }

      // 删除元数据
      await _storage.delete(key: '${_keyPrefix}provider');
      await _storage.delete(key: _checksumKey);
      await _storage.delete(key: _versionKey);
      await _storage.delete(key: _expiryKey);

      // 清除缓存
      clearCache();

      debugPrint('[SecureKeyManager] 所有密钥已删除');
    } catch (e) {
      debugPrint('[SecureKeyManager] 删除密钥失败: $e');
      rethrow;
    }
  }

  /// 安全清除所有数据
  ///
  /// 用于应用卸载或用户登出时
  Future<void> secureWipe() async {
    try {
      // 先覆盖再删除
      for (int i = 0; i < _segmentCount; i++) {
        await _storage.write(
          key: '${_keyPrefix}seg_$i',
          value: _generateRandomString(64),
        );
      }

      // 然后删除
      await deleteAllKeys();

      debugPrint('[SecureKeyManager] 安全清除完成');
    } catch (e) {
      debugPrint('[SecureKeyManager] 安全清除失败: $e');
      rethrow;
    }
  }

  /// 混淆密钥
  ///
  /// 使用简单的XOR和Base64编码
  String _obfuscate(String input) {
    // 使用固定种子生成混淆密钥（实际应用中可以更复杂）
    const obfuscationKey = 'v0ic3_k3y_0bfusc4t10n';
    final bytes = utf8.encode(input);
    final keyBytes = utf8.encode(obfuscationKey);

    final obfuscated = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ keyBytes[i % keyBytes.length];
    });

    return base64Encode(obfuscated);
  }

  /// 反混淆密钥
  String _deobfuscate(String obfuscated) {
    const obfuscationKey = 'v0ic3_k3y_0bfusc4t10n';
    final bytes = base64Decode(obfuscated);
    final keyBytes = utf8.encode(obfuscationKey);

    final deobfuscated = List<int>.generate(bytes.length, (i) {
      return bytes[i] ^ keyBytes[i % keyBytes.length];
    });

    return utf8.decode(deobfuscated);
  }

  /// 将字符串分割成多个分段
  List<String> _splitIntoSegments(String input, int count) {
    final segmentLength = (input.length / count).ceil();
    final segments = <String>[];

    for (int i = 0; i < count; i++) {
      final start = i * segmentLength;
      final end = (start + segmentLength).clamp(0, input.length);
      if (start < input.length) {
        segments.add(input.substring(start, end));
      } else {
        // 填充空分段（保持分段数量一致）
        segments.add('');
      }
    }

    return segments;
  }

  /// 计算校验和
  String _calculateChecksum(String input) {
    // 简单的校验和：取字符ASCII值之和的十六进制表示
    var sum = 0;
    for (var i = 0; i < input.length; i++) {
      sum += input.codeUnitAt(i);
      sum = (sum * 31) & 0xFFFFFFFF; // 防止溢出
    }
    return sum.toRadixString(16).padLeft(8, '0');
  }

  /// 生成随机字符串
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 释放资源
  void dispose() {
    clearCache();
    _isInitialized = false;
  }
}

/// 密钥提供商类型
enum LLMProvider {
  openai,
  anthropic,
  azure,
  custom,
}

/// 密钥提供商扩展
extension LLMProviderExtension on LLMProvider {
  String get name {
    switch (this) {
      case LLMProvider.openai:
        return 'openai';
      case LLMProvider.anthropic:
        return 'anthropic';
      case LLMProvider.azure:
        return 'azure';
      case LLMProvider.custom:
        return 'custom';
    }
  }

  static LLMProvider fromName(String name) {
    switch (name.toLowerCase()) {
      case 'openai':
        return LLMProvider.openai;
      case 'anthropic':
        return LLMProvider.anthropic;
      case 'azure':
        return LLMProvider.azure;
      default:
        return LLMProvider.custom;
    }
  }
}
