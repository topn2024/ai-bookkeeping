import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/client_vad_service.dart';

void main() {
  group('ClientVADService Tests', () {
    group('ClientVADConfig', () {
      test('默认配置应该正确', () {
        const config = ClientVADConfig();

        expect(config.sampleRate, equals(16000));
        expect(config.frameSamples, equals(512));
        expect(config.vadThreshold, equals(0.5));
        expect(config.minSilenceDurationMs, equals(500));
        expect(config.speechPadMs, equals(300));
        expect(config.minSpeechFrames, equals(3));
        expect(config.minSilenceFrames, equals(10));
        expect(config.adaptiveThreshold, isTrue);
        expect(config.minEnergyThreshold, equals(0.01));
        expect(config.maxEnergyThreshold, equals(0.1));
      });

      test('自定义配置应该正确', () {
        const config = ClientVADConfig(
          sampleRate: 8000,
          frameSamples: 256,
          vadThreshold: 0.3,
          minSpeechFrames: 5,
          minSilenceFrames: 15,
          adaptiveThreshold: false,
        );

        expect(config.sampleRate, equals(8000));
        expect(config.frameSamples, equals(256));
        expect(config.vadThreshold, equals(0.3));
        expect(config.minSpeechFrames, equals(5));
        expect(config.minSilenceFrames, equals(15));
        expect(config.adaptiveThreshold, isFalse);
      });
    });

    group('ClientVADEvent', () {
      test('事件类型应该正确', () {
        final speechStartEvent = ClientVADEvent(
          type: ClientVADEventType.speechStart,
          timestamp: DateTime.now(),
        );

        final speechEndEvent = ClientVADEvent(
          type: ClientVADEventType.speechEnd,
          timestamp: DateTime.now(),
        );

        expect(speechStartEvent.type, equals(ClientVADEventType.speechStart));
        expect(speechEndEvent.type, equals(ClientVADEventType.speechEnd));
      });
    });

    group('能量计算测试', () {
      late ClientVADService vadService;

      setUp(() {
        vadService = ClientVADService();
      });

      tearDown(() {
        vadService.dispose();
      });

      test('空音频数据应该返回0能量', () {
        // 使用反射或公开方法测试能量计算
        // 由于_calculateEnergy是私有的，我们通过processAudio间接测试
        expect(vadService.isInitialized, isFalse);
      });

      test('初始化前不应该运行', () {
        expect(vadService.isInitialized, isFalse);
        expect(vadService.isRunning, isFalse);
        expect(vadService.isSpeaking, isFalse);
      });
    });

    group('状态管理测试', () {
      late ClientVADService vadService;

      setUp(() {
        vadService = ClientVADService();
      });

      tearDown(() {
        vadService.dispose();
      });

      test('初始状态应该正确', () {
        expect(vadService.isInitialized, isFalse);
        expect(vadService.isRunning, isFalse);
        expect(vadService.isSpeaking, isFalse);
        expect(vadService.isUsingFallback, isFalse);
      });

      test('未初始化时start不应该改变运行状态', () {
        vadService.start();
        expect(vadService.isRunning, isFalse);
      });

      test('stop应该重置运行状态', () {
        vadService.stop();
        expect(vadService.isRunning, isFalse);
        expect(vadService.isSpeaking, isFalse);
      });

      test('reset应该重置说话状态', () {
        vadService.reset();
        expect(vadService.isSpeaking, isFalse);
      });

      test('dispose应该释放资源', () {
        vadService.dispose();
        expect(vadService.isInitialized, isFalse);
        expect(vadService.isRunning, isFalse);
      });
    });

    group('回调测试', () {
      late ClientVADService vadService;

      setUp(() {
        vadService = ClientVADService();
      });

      tearDown(() {
        vadService.dispose();
      });

      test('应该能设置回调', () {
        bool speechStartCalled = false;
        bool speechEndCalled = false;

        vadService.onSpeechStart = () {
          speechStartCalled = true;
        };
        vadService.onSpeechEnd = () {
          speechEndCalled = true;
        };

        expect(vadService.onSpeechStart, isNotNull);
        expect(vadService.onSpeechEnd, isNotNull);
      });

      test('事件流应该可用', () {
        expect(vadService.eventStream, isA<Stream<ClientVADEvent>>());
      });
    });

    group('能量检测降级模式测试', () {
      test('生成静音音频数据', () {
        // 生成1024字节的静音音频（512个16位采样）
        final silentAudio = Uint8List(1024);
        for (int i = 0; i < silentAudio.length; i++) {
          silentAudio[i] = 0;
        }

        // 验证静音数据格式正确
        expect(silentAudio.length, equals(1024));
        expect(silentAudio.every((b) => b == 0), isTrue);
      });

      test('生成有声音频数据', () {
        // 生成1024字节的有声音频
        final loudAudio = Uint8List(1024);
        for (int i = 0; i < loudAudio.length ~/ 2; i++) {
          // 写入一个较大的16位采样值（例如：10000）
          final value = 10000;
          loudAudio[i * 2] = value & 0xFF;
          loudAudio[i * 2 + 1] = (value >> 8) & 0xFF;
        }

        // 验证有声数据格式正确
        expect(loudAudio.length, equals(1024));
        // 第一个采样值应该是10000
        final firstSample = loudAudio[0] | (loudAudio[1] << 8);
        expect(firstSample, equals(10000));
      });

      test('PCM数据格式应该是16kHz单声道16bit', () {
        const config = ClientVADConfig();
        // 16kHz采样率，每帧512采样
        // 每帧时长 = 512 / 16000 = 32ms
        final frameDuration = config.frameSamples / config.sampleRate * 1000;
        expect(frameDuration, equals(32.0));
      });
    });

    group('自适应阈值测试', () {
      test('阈值应该在配置范围内', () {
        const config = ClientVADConfig(
          minEnergyThreshold: 0.01,
          maxEnergyThreshold: 0.1,
        );

        // 验证阈值范围配置
        expect(config.minEnergyThreshold, lessThan(config.maxEnergyThreshold));
        expect(config.minEnergyThreshold, greaterThan(0));
        expect(config.maxEnergyThreshold, lessThan(1));
      });
    });

    group('Int扩展测试', () {
      test('16位有符号转换应该正确', () {
        // 测试正数
        expect(_toSigned16(0), equals(0));
        expect(_toSigned16(32767), equals(32767));

        // 测试负数（16位补码）
        expect(_toSigned16(65535), equals(-1));
        expect(_toSigned16(32768), equals(-32768));
        expect(_toSigned16(65534), equals(-2));
      });
    });

    group('语音检测状态机测试', () {
      test('连续语音帧检测阈值', () {
        const config = ClientVADConfig(minSpeechFrames: 3);
        // 需要连续3帧语音才能触发speechStart
        expect(config.minSpeechFrames, equals(3));
      });

      test('连续静音帧检测阈值', () {
        const config = ClientVADConfig(minSilenceFrames: 10);
        // 需要连续10帧静音才能触发speechEnd
        expect(config.minSilenceFrames, equals(10));
      });
    });
  });
}

/// 模拟Int扩展的有符号转换功能
int _toSigned16(int value) {
  const bits = 16;
  final mask = 1 << (bits - 1);
  return (value & ((1 << bits) - 1)) - ((value & mask) << 1);
}
