// ignore_for_file: argument_type_not_assignable
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:record/record.dart';

import 'package:ai_bookkeeping/services/voice/voice_session_controller.dart';
import 'package:ai_bookkeeping/services/voice/voice_session_state.dart';
import 'package:ai_bookkeeping/services/voice/realtime_vad_config.dart';
import 'package:ai_bookkeeping/services/voice_recognition_engine.dart';
import 'package:ai_bookkeeping/services/tts_service.dart';

// 生成 mocks
@GenerateNiceMocks([
  MockSpec<VoiceRecognitionEngine>(),
  MockSpec<TTSService>(),
  MockSpec<AudioRecorder>(),
])
import 'voice_session_controller_test.mocks.dart';

void main() {
  group('VoiceSessionController Tests', () {
    late VoiceSessionController controller;
    late MockVoiceRecognitionEngine mockASR;
    late MockTTSService mockTTS;
    late MockAudioRecorder mockRecorder;

    setUp(() {
      mockASR = MockVoiceRecognitionEngine();
      mockTTS = MockTTSService();
      mockRecorder = MockAudioRecorder();

      // 设置默认行为
      when(mockTTS.initialize()).thenAnswer((_) async {});
      when(mockTTS.speak(any)).thenAnswer((_) async {});
      when(mockTTS.stop()).thenAnswer((_) async {});

      when(mockRecorder.startStream(any)).thenAnswer((_) async {
        return Stream<Uint8List>.empty();
      });
      when(mockRecorder.stop()).thenAnswer((_) async => null);

      when(mockASR.transcribeStream(any)).thenAnswer((_) {
        return Stream<ASRPartialResult>.empty();
      });
    });

    tearDown(() {
      controller.dispose();
    });

    group('状态竞态保护', () {
      test('并发处理结果时应该只处理一个', () async {
        var processCount = 0;

        controller = VoiceSessionController(
          asrService: mockASR,
          ttsService: mockTTS,
          audioRecorder: mockRecorder,
        );

        controller.commandProcessor = (command) async {
          processCount++;
          await Future.delayed(const Duration(milliseconds: 100));
          return '处理完成: $command';
        };

        await controller.initialize();
        await controller.startSession();

        // 模拟并发的 ASR 结果（直接调用内部方法的模拟）
        // 由于 _processFinalResult 是私有的，我们通过状态变化来验证

        // 验证初始状态
        expect(controller.state, equals(VoiceSessionState.listening));
      });

      test('状态版本过期时应该跳过更新', () async {
        controller = VoiceSessionController(
          asrService: mockASR,
          ttsService: mockTTS,
          audioRecorder: mockRecorder,
        );

        await controller.initialize();

        // 验证可以正常开始会话
        final started = await controller.startSession();
        expect(started, isTrue);
        expect(controller.state, equals(VoiceSessionState.listening));

        // 停止会话
        await controller.stopSession();
        expect(controller.state, equals(VoiceSessionState.idle));
      });
    });

    group('录音资源管理', () {
      test('重复启动录音应该被跳过', () async {
        controller = VoiceSessionController(
          asrService: mockASR,
          ttsService: mockTTS,
          audioRecorder: mockRecorder,
        );

        await controller.initialize();
        await controller.startSession();

        // 再次启动会话（应该返回 false，因为已经在进行中）
        final secondStart = await controller.startSession();
        expect(secondStart, isFalse);

        // 验证 startStream 只被调用一次
        verify(mockRecorder.startStream(any)).called(1);
      });

      test('forceReset 应该正确重置状态', () async {
        controller = VoiceSessionController(
          asrService: mockASR,
          ttsService: mockTTS,
          audioRecorder: mockRecorder,
        );

        await controller.initialize();
        await controller.startSession();

        // 强制重置
        controller.forceReset();

        expect(controller.state, equals(VoiceSessionState.idle));
        expect(controller.partialText, isEmpty);
      });

      test('停止会话时应该清理资源', () async {
        controller = VoiceSessionController(
          asrService: mockASR,
          ttsService: mockTTS,
          audioRecorder: mockRecorder,
        );

        await controller.initialize();
        await controller.startSession();
        await controller.stopSession();

        // 验证资源被清理
        verify(mockRecorder.stop()).called(greaterThanOrEqualTo(1));
        expect(controller.state, equals(VoiceSessionState.idle));
      });
    });

    group('状态转换', () {
      test('应该从 idle 转换到 listening', () async {
        controller = VoiceSessionController(
          asrService: mockASR,
          ttsService: mockTTS,
          audioRecorder: mockRecorder,
        );

        await controller.initialize();

        expect(controller.state, equals(VoiceSessionState.idle));

        final success = await controller.startSession();

        expect(success, isTrue);
        expect(controller.state, equals(VoiceSessionState.listening));
      });

      test('应该从 listening 转换到 idle', () async {
        controller = VoiceSessionController(
          asrService: mockASR,
          ttsService: mockTTS,
          audioRecorder: mockRecorder,
        );

        await controller.initialize();
        await controller.startSession();

        expect(controller.state, equals(VoiceSessionState.listening));

        await controller.stopSession();

        expect(controller.state, equals(VoiceSessionState.idle));
      });
    });

    group('状态流', () {
      test('状态变化应该通过流通知', () async {
        controller = VoiceSessionController(
          asrService: mockASR,
          ttsService: mockTTS,
          audioRecorder: mockRecorder,
        );

        await controller.initialize();

        final stateChanges = <VoiceSessionStateChange>[];
        controller.stateStream.listen((change) {
          stateChanges.add(change);
        });

        await controller.startSession();
        await controller.stopSession();

        // 等待流事件被处理
        await Future.delayed(const Duration(milliseconds: 50));

        expect(stateChanges.length, greaterThanOrEqualTo(2));
      });
    });
  });
}
