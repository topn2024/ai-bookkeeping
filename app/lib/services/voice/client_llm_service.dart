import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'secure_key_manager.dart';

/// 客户端LLM服务
///
/// 直接从客户端调用LLM API，支持流式响应
/// 支持的提供商：OpenAI、Anthropic (Claude)
class ClientLLMService {
  /// 安全密钥管理器
  final SecureKeyManager _keyManager;

  /// HTTP客户端
  final http.Client _httpClient;

  /// 配置
  final ClientLLMConfig config;

  /// 对话历史
  final List<LLMMessage> _conversationHistory = [];

  /// 系统提示
  String? _systemPrompt;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 当前提供商
  LLMProvider? _provider;

  /// 重试计数
  int _retryCount = 0;

  ClientLLMService({
    required SecureKeyManager keyManager,
    http.Client? httpClient,
    ClientLLMConfig? config,
  })  : _keyManager = keyManager,
        _httpClient = httpClient ?? http.Client(),
        config = config ?? const ClientLLMConfig();

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 当前提供商
  LLMProvider? get provider => _provider;

  /// 对话历史长度
  int get historyLength => _conversationHistory.length;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 确保密钥管理器已初始化
      if (!_keyManager.isInitialized) {
        await _keyManager.initialize();
      }

      // 获取提供商
      final providerName = await _keyManager.getProvider();
      if (providerName != null) {
        _provider = LLMProviderExtension.fromName(providerName);
      }

      _isInitialized = true;
      debugPrint('[ClientLLMService] 初始化完成 (provider=$_provider)');
    } catch (e) {
      debugPrint('[ClientLLMService] 初始化失败: $e');
      rethrow;
    }
  }

  /// 设置系统提示
  void setSystemPrompt(String prompt) {
    _systemPrompt = prompt;
    debugPrint('[ClientLLMService] 系统提示已设置 (${prompt.length}字)');
  }

  /// 清除对话历史
  void clearHistory() {
    _conversationHistory.clear();
    debugPrint('[ClientLLMService] 对话历史已清除');
  }

  /// 添加消息到历史
  void addToHistory(LLMMessage message) {
    _conversationHistory.add(message);

    // 限制历史长度
    while (_conversationHistory.length > config.maxHistoryLength) {
      _conversationHistory.removeAt(0);
    }
  }

  /// 发送消息并获取流式响应
  ///
  /// 返回响应文本的流
  Stream<String> sendMessage(String userMessage) async* {
    if (!_isInitialized) {
      throw StateError('服务未初始化');
    }

    // 获取API密钥
    final apiKey = await _keyManager.getKey();
    if (apiKey == null) {
      throw StateError('API密钥不可用');
    }

    // 添加用户消息到历史
    addToHistory(LLMMessage(role: LLMRole.user, content: userMessage));

    // 重置重试计数
    _retryCount = 0;

    // 根据提供商调用不同的API
    try {
      switch (_provider) {
        case LLMProvider.openai:
        case LLMProvider.azure:
          yield* _callOpenAIStream(apiKey, userMessage);
          break;
        case LLMProvider.anthropic:
          yield* _callAnthropicStream(apiKey, userMessage);
          break;
        default:
          throw UnsupportedError('不支持的提供商: $_provider');
      }
    } catch (e) {
      debugPrint('[ClientLLMService] 调用失败: $e');
      // 尝试重试
      if (_retryCount < config.maxRetries) {
        _retryCount++;
        debugPrint('[ClientLLMService] 重试 $_retryCount/${config.maxRetries}');
        await Future.delayed(Duration(milliseconds: config.retryDelayMs * _retryCount));
        yield* sendMessage(userMessage);
      } else {
        rethrow;
      }
    }
  }

  /// 调用OpenAI流式API
  Stream<String> _callOpenAIStream(String apiKey, String userMessage) async* {
    final url = config.openaiEndpoint ?? 'https://api.openai.com/v1/chat/completions';

    final messages = <Map<String, String>>[];

    // 添加系统提示
    if (_systemPrompt != null) {
      messages.add({'role': 'system', 'content': _systemPrompt!});
    }

    // 添加历史消息
    for (final msg in _conversationHistory) {
      messages.add({
        'role': msg.role == LLMRole.user ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    final body = jsonEncode({
      'model': config.openaiModel,
      'messages': messages,
      'stream': true,
      'max_tokens': config.maxTokens,
      'temperature': config.temperature,
    });

    debugPrint('[ClientLLMService] 调用OpenAI API...');

    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    request.body = body;

    final response = await _httpClient
        .send(request)
        .timeout(Duration(milliseconds: config.timeoutMs));

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw LLMException('OpenAI API错误: ${response.statusCode} - $errorBody');
    }

    final fullResponse = StringBuffer();

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      // 解析SSE格式
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') {
            break;
          }

          try {
            final json = jsonDecode(data);
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map?;
              final content = delta?['content'] as String?;
              if (content != null) {
                fullResponse.write(content);
                yield content;
              }
            }
          } catch (e) {
            // 忽略解析错误，继续处理下一行
          }
        }
      }
    }

    // 添加助手响应到历史
    if (fullResponse.isNotEmpty) {
      addToHistory(LLMMessage(
        role: LLMRole.assistant,
        content: fullResponse.toString(),
      ));
    }
  }

  /// 调用Anthropic流式API
  Stream<String> _callAnthropicStream(String apiKey, String userMessage) async* {
    final url = config.anthropicEndpoint ?? 'https://api.anthropic.com/v1/messages';

    final messages = <Map<String, String>>[];

    // 添加历史消息（Anthropic不支持system role在messages中）
    for (final msg in _conversationHistory) {
      messages.add({
        'role': msg.role == LLMRole.user ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    final bodyMap = <String, dynamic>{
      'model': config.anthropicModel,
      'messages': messages,
      'stream': true,
      'max_tokens': config.maxTokens,
    };

    // Anthropic使用单独的system参数
    if (_systemPrompt != null) {
      bodyMap['system'] = _systemPrompt;
    }

    final body = jsonEncode(bodyMap);

    debugPrint('[ClientLLMService] 调用Anthropic API...');

    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    });
    request.body = body;

    final response = await _httpClient
        .send(request)
        .timeout(Duration(milliseconds: config.timeoutMs));

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw LLMException('Anthropic API错误: ${response.statusCode} - $errorBody');
    }

    final fullResponse = StringBuffer();

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      // 解析SSE格式
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();

          try {
            final json = jsonDecode(data);
            final type = json['type'] as String?;

            if (type == 'content_block_delta') {
              final delta = json['delta'] as Map?;
              final text = delta?['text'] as String?;
              if (text != null) {
                fullResponse.write(text);
                yield text;
              }
            } else if (type == 'message_stop') {
              break;
            }
          } catch (e) {
            // 忽略解析错误，继续处理下一行
          }
        }
      }
    }

    // 添加助手响应到历史
    if (fullResponse.isNotEmpty) {
      addToHistory(LLMMessage(
        role: LLMRole.assistant,
        content: fullResponse.toString(),
      ));
    }
  }

  /// 发送消息并等待完整响应（非流式）
  Future<String> sendMessageSync(String userMessage) async {
    final buffer = StringBuffer();
    await for (final chunk in sendMessage(userMessage)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  /// 取消当前请求
  void cancelCurrentRequest() {
    // HTTP客户端不支持直接取消，但可以通过关闭客户端实现
    debugPrint('[ClientLLMService] 请求取消（需要重新初始化客户端）');
  }

  /// 释放资源
  void dispose() {
    _conversationHistory.clear();
    _systemPrompt = null;
    _isInitialized = false;
    debugPrint('[ClientLLMService] 资源已释放');
  }
}

/// LLM消息
class LLMMessage {
  final LLMRole role;
  final String content;
  final DateTime timestamp;

  LLMMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LLMMessage.fromJson(Map<String, dynamic> json) => LLMMessage(
        role: LLMRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => LLMRole.user,
        ),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// LLM角色
enum LLMRole {
  user,
  assistant,
  system,
}

/// LLM配置
class ClientLLMConfig {
  /// OpenAI模型
  final String openaiModel;

  /// Anthropic模型
  final String anthropicModel;

  /// OpenAI端点（可选，用于自定义或Azure）
  final String? openaiEndpoint;

  /// Anthropic端点（可选）
  final String? anthropicEndpoint;

  /// 最大token数
  final int maxTokens;

  /// 温度
  final double temperature;

  /// 请求超时（毫秒）
  final int timeoutMs;

  /// 最大重试次数
  final int maxRetries;

  /// 重试延迟（毫秒）
  final int retryDelayMs;

  /// 最大历史长度
  final int maxHistoryLength;

  const ClientLLMConfig({
    this.openaiModel = 'gpt-4o-mini',
    this.anthropicModel = 'claude-3-haiku-20240307',
    this.openaiEndpoint,
    this.anthropicEndpoint,
    this.maxTokens = 1024,
    this.temperature = 0.7,
    this.timeoutMs = 30000,
    this.maxRetries = 2,
    this.retryDelayMs = 1000,
    this.maxHistoryLength = 20,
  });

  ClientLLMConfig copyWith({
    String? openaiModel,
    String? anthropicModel,
    String? openaiEndpoint,
    String? anthropicEndpoint,
    int? maxTokens,
    double? temperature,
    int? timeoutMs,
    int? maxRetries,
    int? retryDelayMs,
    int? maxHistoryLength,
  }) {
    return ClientLLMConfig(
      openaiModel: openaiModel ?? this.openaiModel,
      anthropicModel: anthropicModel ?? this.anthropicModel,
      openaiEndpoint: openaiEndpoint ?? this.openaiEndpoint,
      anthropicEndpoint: anthropicEndpoint ?? this.anthropicEndpoint,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelayMs: retryDelayMs ?? this.retryDelayMs,
      maxHistoryLength: maxHistoryLength ?? this.maxHistoryLength,
    );
  }
}

/// LLM异常
class LLMException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  LLMException(this.message, {this.statusCode, this.details});

  @override
  String toString() {
    var str = 'LLMException: $message';
    if (statusCode != null) str += ' (status: $statusCode)';
    if (details != null) str += '\nDetails: $details';
    return str;
  }
}
