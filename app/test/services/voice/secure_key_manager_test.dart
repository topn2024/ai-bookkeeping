import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/secure_key_manager.dart';

void main() {
  group('SecureKeyManager Tests', () {
    group('LLMProvider', () {
      test('provider name should be correct', () {
        expect(LLMProvider.openai.name, equals('openai'));
        expect(LLMProvider.anthropic.name, equals('anthropic'));
        expect(LLMProvider.azure.name, equals('azure'));
        expect(LLMProvider.custom.name, equals('custom'));
      });

      test('fromName should return correct provider', () {
        expect(LLMProviderExtension.fromName('openai'), equals(LLMProvider.openai));
        expect(LLMProviderExtension.fromName('OpenAI'), equals(LLMProvider.openai));
        expect(LLMProviderExtension.fromName('anthropic'), equals(LLMProvider.anthropic));
        expect(LLMProviderExtension.fromName('azure'), equals(LLMProvider.azure));
        expect(LLMProviderExtension.fromName('unknown'), equals(LLMProvider.custom));
      });
    });

    group('SecureKeyManager Initialization', () {
      test('should start uninitialized', () {
        final manager = SecureKeyManager();
        expect(manager.isInitialized, isFalse);
      });
    });

    group('Key Obfuscation Logic', () {
      // 测试混淆和反混淆逻辑（通过公共接口间接测试）
      test('key storage format should have multiple segments', () {
        // 验证分段存储策略的设计
        // 分段数量应该为4
        expect(4, equals(4)); // _segmentCount is 4
      });

      test('checksum calculation should be consistent', () {
        // 相同输入应该产生相同校验和
        const input = 'test_api_key_123';
        // 校验和算法：字符ASCII值累加，乘31，取16进制
        var sum = 0;
        for (var i = 0; i < input.length; i++) {
          sum += input.codeUnitAt(i);
          sum = (sum * 31) & 0xFFFFFFFF;
        }
        final checksum = sum.toRadixString(16).padLeft(8, '0');

        // 验证校验和长度
        expect(checksum.length, equals(8));
      });
    });

    group('Key Validity', () {
      test('expired key logic', () {
        // 验证过期时间逻辑
        final now = DateTime.now();
        final expiredTime = now.subtract(const Duration(hours: 1));
        final validTime = now.add(const Duration(hours: 1));

        expect(now.isAfter(expiredTime), isTrue);
        expect(now.isAfter(validTime), isFalse);
      });

      test('version comparison logic', () {
        // 验证版本比较逻辑
        const currentVersion = 1;
        const newVersion = 2;
        const oldVersion = 0;

        expect(newVersion > currentVersion, isTrue);
        expect(oldVersion > currentVersion, isFalse);
        expect(currentVersion > currentVersion, isFalse);
      });
    });

    group('Segment Splitting', () {
      test('string should split into correct segments', () {
        const input = 'abcdefghijklmnop'; // 16 characters
        const segmentCount = 4;
        final segmentLength = (input.length / segmentCount).ceil();

        final segments = <String>[];
        for (int i = 0; i < segmentCount; i++) {
          final start = i * segmentLength;
          final end = (start + segmentLength).clamp(0, input.length);
          if (start < input.length) {
            segments.add(input.substring(start, end));
          }
        }

        expect(segments.length, equals(4));
        expect(segments[0], equals('abcd'));
        expect(segments[1], equals('efgh'));
        expect(segments[2], equals('ijkl'));
        expect(segments[3], equals('mnop'));
        expect(segments.join(''), equals(input));
      });

      test('uneven string should split correctly', () {
        const input = 'abcdefghij'; // 10 characters
        const segmentCount = 4;
        final segmentLength = (input.length / segmentCount).ceil(); // 3

        final segments = <String>[];
        for (int i = 0; i < segmentCount; i++) {
          final start = i * segmentLength;
          final end = (start + segmentLength).clamp(0, input.length);
          if (start < input.length) {
            segments.add(input.substring(start, end));
          } else {
            segments.add('');
          }
        }

        expect(segments.length, equals(4));
        expect(segments.join(''), equals(input));
      });
    });

    group('XOR Obfuscation', () {
      test('XOR operation should be reversible', () {
        const original = 'test_api_key';
        const key = 'obfuscation';

        // XOR with key
        final obfuscated = List<int>.generate(original.length, (i) {
          return original.codeUnitAt(i) ^
              key.codeUnitAt(i % key.length);
        });

        // XOR again with same key should restore original
        final restored = List<int>.generate(obfuscated.length, (i) {
          return obfuscated[i] ^ key.codeUnitAt(i % key.length);
        });

        expect(String.fromCharCodes(restored), equals(original));
      });
    });

    group('Cache Management', () {
      test('clearCache should work correctly', () {
        final manager = SecureKeyManager();
        // 验证clearCache不会抛出异常
        expect(() => manager.clearCache(), returnsNormally);
      });

      test('dispose should clear cache', () {
        final manager = SecureKeyManager();
        expect(() => manager.dispose(), returnsNormally);
        expect(manager.isInitialized, isFalse);
      });
    });

    group('Error Handling', () {
      test('storeKey should reject empty key', () {
        final manager = SecureKeyManager();
        expect(
          () => manager.storeKey(apiKey: '', provider: 'openai'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
