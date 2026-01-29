import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/secrets.dart';
import 'aliyun_nls_token_service.dart';
import 'voice_token_service.dart';
import 'secure_key_service.dart';

/// 语音Token自动刷新服务
///
/// 负责在应用启动时获取Token，并每天定时刷新。
/// 使用阿里云AccessKey动态获取Token，不再依赖硬编码的静态Token。
class VoiceTokenRefreshService {
  static final VoiceTokenRefreshService _instance =
      VoiceTokenRefreshService._internal();
  factory VoiceTokenRefreshService() => _instance;
  VoiceTokenRefreshService._internal();

  final AliyunNLSTokenService _nlsTokenService = AliyunNLSTokenService();
  Timer? _refreshTimer;
  bool _initialized = false;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 初始化服务
  ///
  /// 获取Token并配置VoiceTokenService，同时设置每日刷新定时器
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[VoiceTokenRefresh] 服务已初始化，跳过');
      return;
    }

    debugPrint('[VoiceTokenRefresh] 开始初始化...');

    try {
      // 尝试动态获取Token
      await _refreshToken();
      _initialized = true;

      // 设置每日刷新定时器（每23小时刷新一次，确保在24小时过期前刷新）
      _schedulePeriodicRefresh();

      debugPrint('[VoiceTokenRefresh] 初始化成功，已设置每日自动刷新');
    } catch (e) {
      debugPrint('[VoiceTokenRefresh] 动态Token获取失败: $e');
      debugPrint('[VoiceTokenRefresh] 降级使用静态Token');

      // 降级：使用硬编码的静态Token
      _configureStaticToken();
      _initialized = true;
    }
  }

  /// 刷新Token
  Future<void> _refreshToken() async {
    debugPrint('[VoiceTokenRefresh] 正在刷新Token...');

    String accessKeyId;
    String accessKeySecret;
    String appKey;
    String asrUrl;
    String asrRestUrl;
    String ttsUrl;

    // Android 平台使用 Native 安全存储的密钥
    if (Platform.isAndroid) {
      debugPrint('[VoiceTokenRefresh] 使用 Native 安全密钥...');
      final keys = await SecureKeyService.instance.getAllKeys();
      if (keys.isEmpty) {
        throw Exception('无法从 Native 层获取密钥');
      }
      accessKeyId = keys['accessKeyId'] ?? '';
      accessKeySecret = keys['accessKeySecret'] ?? '';
      appKey = keys['appKey'] ?? '';
      asrUrl = keys['asrUrl'] ?? AliyunSpeechConfig.asrUrl;
      asrRestUrl = keys['asrRestUrl'] ?? AliyunSpeechConfig.asrRestUrl;
      ttsUrl = keys['ttsUrl'] ?? AliyunSpeechConfig.ttsUrl;

      if (accessKeyId.isEmpty || accessKeySecret.isEmpty) {
        throw Exception('Native 密钥为空');
      }
    } else {
      // 其他平台回退到 secrets.dart
      debugPrint('[VoiceTokenRefresh] 使用静态密钥配置...');
      accessKeyId = AliyunSpeechConfig.accessKeyId;
      accessKeySecret = AliyunSpeechConfig.accessKeySecret;
      appKey = AliyunSpeechConfig.appKey;
      asrUrl = AliyunSpeechConfig.asrUrl;
      asrRestUrl = AliyunSpeechConfig.asrRestUrl;
      ttsUrl = AliyunSpeechConfig.ttsUrl;
    }

    final token = await _nlsTokenService.getToken(
      accessKeyId: accessKeyId,
      accessKeySecret: accessKeySecret,
    );

    // 计算Token过期时间（从NLS服务获取的Token通常24小时有效）
    // 这里设置为23小时后过期，给刷新留出缓冲时间
    final expiresAt = DateTime.now().add(const Duration(hours: 23));

    // 配置VoiceTokenService使用新Token
    VoiceTokenService().configureDirectMode(
      token: token,
      appKey: appKey,
      expiresAt: expiresAt,
      asrUrl: asrUrl,
      asrRestUrl: asrRestUrl,
      ttsUrl: ttsUrl,
    );

    debugPrint('[VoiceTokenRefresh] Token刷新成功，过期时间: $expiresAt');
  }

  /// 配置静态Token（降级方案）
  void _configureStaticToken() {
    VoiceTokenService().configureDirectMode(
      token: AliyunSpeechConfig.token,
      appKey: AliyunSpeechConfig.appKey,
      asrUrl: AliyunSpeechConfig.asrUrl,
      asrRestUrl: AliyunSpeechConfig.asrRestUrl,
      ttsUrl: AliyunSpeechConfig.ttsUrl,
    );
    debugPrint('[VoiceTokenRefresh] 已配置静态Token');
  }

  /// 设置周期性刷新
  void _schedulePeriodicRefresh() {
    _refreshTimer?.cancel();

    // 每23小时刷新一次（给24小时的Token留1小时缓冲）
    _refreshTimer = Timer.periodic(
      const Duration(hours: 23),
      (_) => _performScheduledRefresh(),
    );

    debugPrint('[VoiceTokenRefresh] 已设置每23小时自动刷新');
  }

  /// 执行计划刷新
  Future<void> _performScheduledRefresh() async {
    debugPrint('[VoiceTokenRefresh] 执行计划的Token刷新...');

    try {
      await _refreshToken();
      debugPrint('[VoiceTokenRefresh] 计划刷新成功');
    } catch (e) {
      debugPrint('[VoiceTokenRefresh] 计划刷新失败: $e');
      // 失败后30分钟重试
      Timer(const Duration(minutes: 30), () {
        _performScheduledRefresh();
      });
    }
  }

  /// 手动触发Token刷新
  Future<bool> forceRefresh() async {
    try {
      await _refreshToken();
      return true;
    } catch (e) {
      debugPrint('[VoiceTokenRefresh] 手动刷新失败: $e');
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _initialized = false;
    debugPrint('[VoiceTokenRefresh] 服务已释放');
  }
}
