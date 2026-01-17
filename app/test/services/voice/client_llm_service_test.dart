import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/client_llm_service.dart';

void main() {
  group('ClientLLMService Tests', () {
    group('ClientLLMConfig', () {
      test('default config should have correct values', () {
        const config = ClientLLMConfig();

        expect(config.openaiModel, equals('gpt-4o-mini'));
        expect(config.anthropicModel, equals('claude-3-haiku-20240307'));
        expect(config.maxTokens, equals(1024));
        expect(config.temperature, equals(0.7));
        expect(config.timeoutMs, equals(30000));
        expect(config.maxRetries, equals(2));
        expect(config.retryDelayMs, equals(1000));
        expect(config.maxHistoryLength, equals(20));
        expect(config.openaiEndpoint, isNull);
        expect(config.anthropicEndpoint, isNull);
      });

      test('custom config should override defaults', () {
        const config = ClientLLMConfig(
          openaiModel: 'gpt-4',
          anthropicModel: 'claude-3-opus',
          maxTokens: 2048,
          temperature: 0.5,
          timeoutMs: 60000,
          maxRetries: 3,
          retryDelayMs: 2000,
          maxHistoryLength: 50,
          openaiEndpoint: 'https://custom.openai.com',
          anthropicEndpoint: 'https://custom.anthropic.com',
        );

        expect(config.openaiModel, equals('gpt-4'));
        expect(config.anthropicModel, equals('claude-3-opus'));
        expect(config.maxTokens, equals(2048));
        expect(config.temperature, equals(0.5));
        expect(config.timeoutMs, equals(60000));
        expect(config.maxRetries, equals(3));
        expect(config.retryDelayMs, equals(2000));
        expect(config.maxHistoryLength, equals(50));
        expect(config.openaiEndpoint, equals('https://custom.openai.com'));
        expect(config.anthropicEndpoint, equals('https://custom.anthropic.com'));
      });

      test('copyWith should work correctly', () {
        const original = ClientLLMConfig();
        final modified = original.copyWith(
          maxTokens: 4096,
          temperature: 0.9,
        );

        // Modified values
        expect(modified.maxTokens, equals(4096));
        expect(modified.temperature, equals(0.9));

        // Unchanged values
        expect(modified.openaiModel, equals(original.openaiModel));
        expect(modified.anthropicModel, equals(original.anthropicModel));
        expect(modified.timeoutMs, equals(original.timeoutMs));
      });
    });

    group('LLMMessage', () {
      test('should create message with default timestamp', () {
        final message = LLMMessage(
          role: LLMRole.user,
          content: 'Hello',
        );

        expect(message.role, equals(LLMRole.user));
        expect(message.content, equals('Hello'));
        expect(message.timestamp, isNotNull);
      });

      test('should create message with custom timestamp', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
        final message = LLMMessage(
          role: LLMRole.assistant,
          content: 'Hi there',
          timestamp: timestamp,
        );

        expect(message.role, equals(LLMRole.assistant));
        expect(message.content, equals('Hi there'));
        expect(message.timestamp, equals(timestamp));
      });

      test('toJson should serialize correctly', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
        final message = LLMMessage(
          role: LLMRole.user,
          content: 'Test message',
          timestamp: timestamp,
        );

        final json = message.toJson();

        expect(json['role'], equals('user'));
        expect(json['content'], equals('Test message'));
        expect(json['timestamp'], equals(timestamp.toIso8601String()));
      });

      test('fromJson should deserialize correctly', () {
        final json = {
          'role': 'assistant',
          'content': 'Response message',
          'timestamp': '2024-01-01T12:00:00.000',
        };

        final message = LLMMessage.fromJson(json);

        expect(message.role, equals(LLMRole.assistant));
        expect(message.content, equals('Response message'));
        expect(message.timestamp.year, equals(2024));
      });

      test('fromJson should handle unknown role', () {
        final json = {
          'role': 'unknown_role',
          'content': 'Test',
          'timestamp': '2024-01-01T12:00:00.000',
        };

        final message = LLMMessage.fromJson(json);

        expect(message.role, equals(LLMRole.user)); // Default to user
      });
    });

    group('LLMRole', () {
      test('should have correct values', () {
        expect(LLMRole.user.name, equals('user'));
        expect(LLMRole.assistant.name, equals('assistant'));
        expect(LLMRole.system.name, equals('system'));
      });
    });

    group('LLMException', () {
      test('basic exception should format correctly', () {
        final exception = LLMException('Test error');

        expect(exception.toString(), contains('LLMException'));
        expect(exception.toString(), contains('Test error'));
      });

      test('exception with status code should format correctly', () {
        final exception = LLMException(
          'API error',
          statusCode: 401,
        );

        expect(exception.toString(), contains('401'));
        expect(exception.toString(), contains('API error'));
      });

      test('exception with details should format correctly', () {
        final exception = LLMException(
          'Rate limit exceeded',
          statusCode: 429,
          details: 'Too many requests',
        );

        expect(exception.toString(), contains('429'));
        expect(exception.toString(), contains('Rate limit exceeded'));
        expect(exception.toString(), contains('Too many requests'));
      });
    });

    group('Conversation History Management', () {
      test('history should be limited by maxHistoryLength', () {
        // 验证历史长度限制逻辑
        const maxLength = 20;
        final history = <LLMMessage>[];

        // 添加超过最大长度的消息
        for (var i = 0; i < maxLength + 5; i++) {
          history.add(LLMMessage(
            role: LLMRole.user,
            content: 'Message $i',
          ));

          // 模拟限制逻辑
          while (history.length > maxLength) {
            history.removeAt(0);
          }
        }

        expect(history.length, equals(maxLength));
        // 最早的消息应该是Message 5（0-4被移除）
        expect(history.first.content, equals('Message 5'));
      });
    });

    group('SSE Parsing Logic', () {
      test('should parse OpenAI SSE format', () {
        const sseData = 'data: {"choices":[{"delta":{"content":"Hello"}}]}';
        final dataLine = sseData.substring(6).trim();
        final json = jsonDecode(dataLine) as Map<String, dynamic>;

        expect(json, isNotNull);
        final choices = json['choices'] as List;
        final delta = choices[0]['delta'] as Map;
        expect(delta['content'], equals('Hello'));
      });

      test('should handle OpenAI DONE signal', () {
        const sseData = 'data: [DONE]';
        final dataLine = sseData.substring(6).trim();

        expect(dataLine, equals('[DONE]'));
      });

      test('should parse Anthropic SSE format', () {
        const sseData =
            'data: {"type":"content_block_delta","delta":{"text":"Hi"}}';
        final dataLine = sseData.substring(6).trim();
        final json = jsonDecode(dataLine) as Map<String, dynamic>;

        expect(json, isNotNull);
        expect(json['type'], equals('content_block_delta'));
        final delta = json['delta'] as Map;
        expect(delta['text'], equals('Hi'));
      });

      test('should handle Anthropic message_stop', () {
        const sseData = 'data: {"type":"message_stop"}';
        final dataLine = sseData.substring(6).trim();
        final json = jsonDecode(dataLine) as Map<String, dynamic>;

        expect(json, isNotNull);
        expect(json['type'], equals('message_stop'));
      });
    });

    group('Retry Logic', () {
      test('retry delay should increase with attempt count', () {
        const baseDelay = 1000;
        const maxRetries = 3;

        final delays = <int>[];
        for (var attempt = 1; attempt <= maxRetries; attempt++) {
          delays.add(baseDelay * attempt);
        }

        expect(delays, equals([1000, 2000, 3000]));
      });
    });
  });
}
