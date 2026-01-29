import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 安全密钥服务
///
/// 通过 Native 层获取密钥，密钥在 Native 代码中混淆存储，
/// 比纯 Dart 代码更难逆向工程。
class SecureKeyService {
  static const MethodChannel _channel =
      MethodChannel('com.example.ai_bookkeeping/secure_keys');

  static SecureKeyService? _instance;
  static SecureKeyService get instance => _instance ??= SecureKeyService._();

  SecureKeyService._();

  // 缓存密钥，避免频繁 JNI 调用
  Map<String, String>? _cachedKeys;

  /// 获取所有密钥
  Future<Map<String, String>> getAllKeys() async {
    if (_cachedKeys != null) {
      return _cachedKeys!;
    }

    try {
      final result = await _channel.invokeMethod<Map>('getAllKeys');
      if (result != null) {
        _cachedKeys = Map<String, String>.from(result);
        return _cachedKeys!;
      }
    } catch (e) {
      debugPrint('[SecureKeyService] 获取密钥失败: $e');
    }

    return {};
  }

  /// 获取阿里云 AccessKey ID
  Future<String?> getAliyunAccessKeyId() async {
    try {
      return await _channel.invokeMethod<String>('getAliyunAccessKeyId');
    } catch (e) {
      debugPrint('[SecureKeyService] 获取 AccessKeyId 失败: $e');
      return null;
    }
  }

  /// 获取阿里云 AccessKey Secret
  Future<String?> getAliyunAccessKeySecret() async {
    try {
      return await _channel.invokeMethod<String>('getAliyunAccessKeySecret');
    } catch (e) {
      debugPrint('[SecureKeyService] 获取 AccessKeySecret 失败: $e');
      return null;
    }
  }

  /// 获取阿里云 AppKey
  Future<String?> getAliyunAppKey() async {
    try {
      return await _channel.invokeMethod<String>('getAliyunAppKey');
    } catch (e) {
      debugPrint('[SecureKeyService] 获取 AppKey 失败: $e');
      return null;
    }
  }

  /// 获取通义千问 API Key
  Future<String?> getQwenApiKey() async {
    try {
      return await _channel.invokeMethod<String>('getQwenApiKey');
    } catch (e) {
      debugPrint('[SecureKeyService] 获取 QwenApiKey 失败: $e');
      return null;
    }
  }

  /// 获取 ASR WebSocket URL
  Future<String?> getAsrUrl() async {
    try {
      return await _channel.invokeMethod<String>('getAsrUrl');
    } catch (e) {
      debugPrint('[SecureKeyService] 获取 AsrUrl 失败: $e');
      return null;
    }
  }

  /// 获取 ASR REST URL
  Future<String?> getAsrRestUrl() async {
    try {
      return await _channel.invokeMethod<String>('getAsrRestUrl');
    } catch (e) {
      debugPrint('[SecureKeyService] 获取 AsrRestUrl 失败: $e');
      return null;
    }
  }

  /// 获取 TTS WebSocket URL
  Future<String?> getTtsUrl() async {
    try {
      return await _channel.invokeMethod<String>('getTtsUrl');
    } catch (e) {
      debugPrint('[SecureKeyService] 获取 TtsUrl 失败: $e');
      return null;
    }
  }

  /// 清除缓存
  void clearCache() {
    _cachedKeys = null;
  }
}
