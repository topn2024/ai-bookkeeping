import 'dart:async';

import 'package:flutter/foundation.dart';

import '../voice_token_service.dart';
import 'secure_key_manager.dart';
import 'client_llm_service.dart';

/// 云服务直连配置
///
/// 管理App直接连接云服务（阿里云ASR/TTS、LLM）所需的凭证和配置。
/// 完全在客户端完成，不需要后端服务器。
///
/// 使用方式：
/// ```dart
/// final service = CloudDirectService();
/// await service.initialize();
///
/// // 首次使用时配置凭证
/// await service.configureAliyunCredentials(
///   token: 'your-nls-token',
///   appKey: 'your-app-key',
/// );
///
/// await service.configureLLMCredentials(
///   apiKey: 'your-api-key',
///   provider: LLMProvider.qwen,
/// );
/// ```
class CloudDirectService {
  static final CloudDirectService _instance = CloudDirectService._internal();
  factory CloudDirectService() => _instance;
  CloudDirectService._internal();

  final SecureKeyManager _keyManager = SecureKeyManager();
  final VoiceTokenService _tokenService = VoiceTokenService();

  ClientLLMService? _llmService;

  bool _isInitialized = false;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否已配置阿里云凭证
  bool _hasAliyunCredentials = false;
  bool get hasAliyunCredentials => _hasAliyunCredentials;

  /// 是否已配置LLM凭证
  bool _hasLLMCredentials = false;
  bool get hasLLMCredentials => _hasLLMCredentials;

  /// LLM服务实例
  ClientLLMService? get llmService => _llmService;

  /// 初始化服务
  ///
  /// 检查并加载已存储的凭证
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 检查是否有存储的阿里云凭证
      final aliyunKey = await _keyManager.getKey();
      if (aliyunKey != null) {
        await _configureAliyunFromStoredKey(aliyunKey);
        _hasAliyunCredentials = true;
      }

      // 检查是否有存储的LLM凭证
      await _initializeLLMService();

      _isInitialized = true;
      debugPrint('[CloudDirectService] 初始化完成 '
          '(aliyun=${_hasAliyunCredentials}, llm=${_hasLLMCredentials})');
    } catch (e) {
      debugPrint('[CloudDirectService] 初始化错误: $e');
      rethrow;
    }
  }

  /// 配置阿里云凭证
  ///
  /// [token] NLS服务Token
  /// [appKey] 项目AppKey
  /// [expiresAt] Token过期时间（可选）
  /// [asrUrl] ASR WebSocket URL（可选，使用默认值）
  /// [ttsUrl] TTS URL（可选，使用默认值）
  Future<void> configureAliyunCredentials({
    required String token,
    required String appKey,
    DateTime? expiresAt,
    String? asrUrl,
    String? asrRestUrl,
    String? ttsUrl,
  }) async {
    // 存储凭证（组合成JSON格式）
    final credentialJson = '{"token":"$token","appKey":"$appKey",'
        '"expiresAt":"${(expiresAt ?? DateTime.now().add(const Duration(hours: 24))).toIso8601String()}",'
        '"asrUrl":"${asrUrl ?? ''}",'
        '"asrRestUrl":"${asrRestUrl ?? ''}",'
        '"ttsUrl":"${ttsUrl ?? ''}"}';

    await _keyManager.storeKey(
      apiKey: credentialJson,
      provider: 'aliyun',
    );

    // 配置VoiceTokenService直连模式
    _tokenService.configureDirectMode(
      token: token,
      appKey: appKey,
      expiresAt: expiresAt,
      asrUrl: asrUrl,
      asrRestUrl: asrRestUrl,
      ttsUrl: ttsUrl,
    );

    _hasAliyunCredentials = true;
    debugPrint('[CloudDirectService] 阿里云凭证已配置');
  }

  /// 从存储的key配置阿里云
  Future<void> _configureAliyunFromStoredKey(String storedKey) async {
    try {
      // 解析存储的JSON
      // 简单解析，不引入额外依赖
      final tokenMatch = RegExp(r'"token":"([^"]*)"').firstMatch(storedKey);
      final appKeyMatch = RegExp(r'"appKey":"([^"]*)"').firstMatch(storedKey);
      final expiresAtMatch =
          RegExp(r'"expiresAt":"([^"]*)"').firstMatch(storedKey);
      final asrUrlMatch = RegExp(r'"asrUrl":"([^"]*)"').firstMatch(storedKey);
      final asrRestUrlMatch =
          RegExp(r'"asrRestUrl":"([^"]*)"').firstMatch(storedKey);
      final ttsUrlMatch = RegExp(r'"ttsUrl":"([^"]*)"').firstMatch(storedKey);

      if (tokenMatch != null && appKeyMatch != null) {
        final token = tokenMatch.group(1)!;
        final appKey = appKeyMatch.group(1)!;
        final expiresAtStr = expiresAtMatch?.group(1);
        final asrUrl = asrUrlMatch?.group(1);
        final asrRestUrl = asrRestUrlMatch?.group(1);
        final ttsUrl = ttsUrlMatch?.group(1);

        DateTime? expiresAt;
        if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
          expiresAt = DateTime.tryParse(expiresAtStr);
        }

        // 检查是否过期
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          debugPrint('[CloudDirectService] 存储的阿里云凭证已过期');
          await _keyManager.secureWipe();
          return;
        }

        _tokenService.configureDirectMode(
          token: token,
          appKey: appKey,
          expiresAt: expiresAt,
          asrUrl: asrUrl?.isEmpty == true ? null : asrUrl,
          asrRestUrl: asrRestUrl?.isEmpty == true ? null : asrRestUrl,
          ttsUrl: ttsUrl?.isEmpty == true ? null : ttsUrl,
        );

        debugPrint('[CloudDirectService] 从存储加载阿里云凭证');
      }
    } catch (e) {
      debugPrint('[CloudDirectService] 解析存储的阿里云凭证失败: $e');
    }
  }

  /// 配置LLM凭证
  ///
  /// [apiKey] API密钥
  /// [provider] LLM提供商
  /// [model] 模型名称（可选）
  Future<void> configureLLMCredentials({
    required String apiKey,
    required LLMProvider provider,
    String? model,
  }) async {
    // 创建新的LLM服务实例
    _llmService = ClientLLMService(
      provider: provider,
      model: model,
    );

    // 存储API key到SecureKeyManager
    // 使用不同的provider标识来区分
    final llmKeyManager = SecureKeyManager();
    await llmKeyManager.storeKey(
      apiKey: apiKey,
      provider: provider.name,
    );

    _hasLLMCredentials = true;
    debugPrint('[CloudDirectService] LLM凭证已配置 (provider=${provider.name})');
  }

  /// 初始化LLM服务
  Future<void> _initializeLLMService() async {
    // 尝试从存储加载LLM配置
    // 检查各个provider
    for (final provider in LLMProvider.values) {
      final keyManager = SecureKeyManager();
      // 这里简化处理，实际应该有更好的provider标识机制
      final hasKey = await keyManager.getKey();
      if (hasKey != null) {
        // 检查是否是LLM key（通过provider名称判断）
        // 实际实现可能需要更复杂的逻辑
        break;
      }
    }
  }

  /// 发送消息到LLM
  ///
  /// 返回流式响应
  Stream<String> sendMessage(String message) async* {
    if (_llmService == null) {
      throw StateError('LLM服务未配置，请先调用configureLLMCredentials');
    }

    yield* _llmService!.sendMessage(message);
  }

  /// 设置LLM系统提示
  void setSystemPrompt(String prompt) {
    _llmService?.setSystemPrompt(prompt);
  }

  /// 清除LLM对话历史
  void clearConversation() {
    _llmService?.clearHistory();
  }

  /// 获取VoiceTokenService（用于ASR/TTS）
  VoiceTokenService get voiceTokenService => _tokenService;

  /// 清除所有凭证
  Future<void> clearAllCredentials() async {
    await _keyManager.secureWipe();
    _tokenService.disableDirectMode();
    _llmService = null;
    _hasAliyunCredentials = false;
    _hasLLMCredentials = false;
    debugPrint('[CloudDirectService] 所有凭证已清除');
  }

  /// 检查凭证状态
  Future<CloudCredentialsStatus> checkCredentialsStatus() async {
    return CloudCredentialsStatus(
      hasAliyunCredentials: _hasAliyunCredentials,
      hasLLMCredentials: _hasLLMCredentials,
      aliyunTokenExpired:
          _hasAliyunCredentials && _tokenService.isDirectMode == false,
      isFullyConfigured: _hasAliyunCredentials && _hasLLMCredentials,
    );
  }
}

/// 云服务凭证状态
class CloudCredentialsStatus {
  /// 是否有阿里云凭证
  final bool hasAliyunCredentials;

  /// 是否有LLM凭证
  final bool hasLLMCredentials;

  /// 阿里云Token是否过期
  final bool aliyunTokenExpired;

  /// 是否完全配置（所有凭证都有）
  final bool isFullyConfigured;

  const CloudCredentialsStatus({
    required this.hasAliyunCredentials,
    required this.hasLLMCredentials,
    required this.aliyunTokenExpired,
    required this.isFullyConfigured,
  });

  @override
  String toString() {
    return 'CloudCredentialsStatus('
        'aliyun=$hasAliyunCredentials, '
        'llm=$hasLLMCredentials, '
        'expired=$aliyunTokenExpired, '
        'ready=$isFullyConfigured)';
  }
}
