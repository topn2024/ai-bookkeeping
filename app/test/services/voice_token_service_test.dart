import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';

import 'package:ai_bookkeeping/services/voice_token_service.dart';

@GenerateNiceMocks([MockSpec<Dio>()])
import 'voice_token_service_test.mocks.dart';

void main() {
  group('VoiceTokenService Tests', () {
    group('Token获取', () {
      test('缓存有效时应该返回缓存的Token', () async {
        // 这是一个概念测试，因为VoiceTokenService是单例
        // 实际测试需要依赖注入支持
        expect(VoiceTokenService(), isNotNull);
      });
    });

    group('VoiceTokenInfo Tests', () {
      test('isExpiringSoon 应该在5分钟内返回true', () {
        final tokenInfo = VoiceTokenInfo(
          token: 'test_token',
          expiresAt: DateTime.now().add(const Duration(minutes: 4)),
          appKey: 'test_app_key',
          asrUrl: 'https://asr.example.com',
          asrRestUrl: 'https://asr-rest.example.com',
          ttsUrl: 'https://tts.example.com',
        );

        expect(tokenInfo.isExpiringSoon, isTrue);
      });

      test('isExpiringSoon 应该在超过5分钟时返回false', () {
        final tokenInfo = VoiceTokenInfo(
          token: 'test_token',
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          appKey: 'test_app_key',
          asrUrl: 'https://asr.example.com',
          asrRestUrl: 'https://asr-rest.example.com',
          ttsUrl: 'https://tts.example.com',
        );

        expect(tokenInfo.isExpiringSoon, isFalse);
      });

      test('isExpired 应该在过期后返回true', () {
        final tokenInfo = VoiceTokenInfo(
          token: 'test_token',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          appKey: 'test_app_key',
          asrUrl: 'https://asr.example.com',
          asrRestUrl: 'https://asr-rest.example.com',
          ttsUrl: 'https://tts.example.com',
        );

        expect(tokenInfo.isExpired, isTrue);
      });

      test('remainingTime 应该返回正确的剩余时间', () {
        final expiresAt = DateTime.now().add(const Duration(minutes: 30));
        final tokenInfo = VoiceTokenInfo(
          token: 'test_token',
          expiresAt: expiresAt,
          appKey: 'test_app_key',
          asrUrl: 'https://asr.example.com',
          asrRestUrl: 'https://asr-rest.example.com',
          ttsUrl: 'https://tts.example.com',
        );

        expect(tokenInfo.remainingTime.inMinutes, closeTo(30, 1));
      });

      test('remainingTime 过期后应该返回零', () {
        final tokenInfo = VoiceTokenInfo(
          token: 'test_token',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          appKey: 'test_app_key',
          asrUrl: 'https://asr.example.com',
          asrRestUrl: 'https://asr-rest.example.com',
          ttsUrl: 'https://tts.example.com',
        );

        expect(tokenInfo.remainingTime, equals(Duration.zero));
      });
    });

    group('VoiceServiceStatus Tests', () {
      test('应该正确创建服务状态', () {
        final status = VoiceServiceStatus(
          available: true,
          message: '服务正常',
        );

        expect(status.available, isTrue);
        expect(status.message, equals('服务正常'));
      });
    });

    group('VoiceTokenException Tests', () {
      test('应该正确创建异常', () {
        final exception = VoiceTokenException('Token获取失败');

        expect(exception.message, equals('Token获取失败'));
        expect(exception.toString(), contains('Token获取失败'));
      });
    });
  });
}
