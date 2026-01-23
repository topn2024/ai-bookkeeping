import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/voice_websocket_client.dart';

void main() {
  group('VoiceWebSocketClient Tests', () {
    group('VoiceMessageType', () {
      test('value should return correct string', () {
        expect(VoiceMessageType.audioChunk.value, equals('audio_chunk'));
        expect(VoiceMessageType.ttsRequest.value, equals('tts_request'));
        expect(VoiceMessageType.interrupt.value, equals('interrupt'));
        expect(VoiceMessageType.sessionStart.value, equals('session_start'));
        expect(VoiceMessageType.sessionEnd.value, equals('session_end'));
        expect(VoiceMessageType.asrIntermediate.value, equals('asr_intermediate'));
        expect(VoiceMessageType.asrFinal.value, equals('asr_final'));
        expect(VoiceMessageType.ttsAudio.value, equals('tts_audio'));
        expect(VoiceMessageType.ttsComplete.value, equals('tts_complete'));
        expect(VoiceMessageType.sessionReady.value, equals('session_ready'));
        expect(VoiceMessageType.sessionClosed.value, equals('session_closed'));
        expect(VoiceMessageType.error.value, equals('error'));
      });

      test('fromValue should return correct type', () {
        expect(
          VoiceMessageTypeExtension.fromValue('audio_chunk'),
          equals(VoiceMessageType.audioChunk),
        );
        expect(
          VoiceMessageTypeExtension.fromValue('asr_intermediate'),
          equals(VoiceMessageType.asrIntermediate),
        );
        expect(
          VoiceMessageTypeExtension.fromValue('asr_final'),
          equals(VoiceMessageType.asrFinal),
        );
        expect(
          VoiceMessageTypeExtension.fromValue('tts_audio'),
          equals(VoiceMessageType.ttsAudio),
        );
        expect(
          VoiceMessageTypeExtension.fromValue('unknown'),
          isNull,
        );
      });
    });

    group('ASRResult', () {
      test('should create from JSON', () {
        final json = {
          'text': 'Hello world',
          'is_final': true,
          'confidence': 0.95,
        };

        final result = ASRResult.fromJson(json);

        expect(result.text, equals('Hello world'));
        expect(result.isFinal, isTrue);
        expect(result.confidence, equals(0.95));
        expect(result.timestamp, isNotNull);
      });

      test('should handle missing fields', () {
        final json = <String, dynamic>{};

        final result = ASRResult.fromJson(json);

        expect(result.text, equals(''));
        expect(result.isFinal, isFalse);
        expect(result.confidence, isNull);
      });

      test('intermediate result should have isFinal false', () {
        final json = {
          'text': 'Partial text',
          'is_final': false,
        };

        final result = ASRResult.fromJson(json);

        expect(result.isFinal, isFalse);
      });
    });

    group('TTSRequest', () {
      test('toJson should serialize correctly', () {
        final request = TTSRequest(
          text: 'Hello',
          requestId: 1,
        );

        final json = request.toJson();

        expect(json['text'], equals('Hello'));
        expect(json['request_id'], equals(1));
        expect(json.containsKey('voice_params'), isFalse);
      });

      test('toJson should include voice params', () {
        final request = TTSRequest(
          text: 'Hello',
          requestId: 2,
          voiceParams: const TTSVoiceParams(
            speed: 1.2,
            pitch: 1.0,
            volume: 0.8,
            voiceId: 'voice_001',
          ),
        );

        final json = request.toJson();

        expect(json['text'], equals('Hello'));
        expect(json['request_id'], equals(2));
        expect(json['voice_params'], isNotNull);

        final voiceParams = json['voice_params'] as Map<String, dynamic>;
        expect(voiceParams['speed'], equals(1.2));
        expect(voiceParams['pitch'], equals(1.0));
        expect(voiceParams['volume'], equals(0.8));
        expect(voiceParams['voice_id'], equals('voice_001'));
      });
    });

    group('TTSVoiceParams', () {
      test('toJson should only include non-null values', () {
        const params = TTSVoiceParams(
          speed: 1.5,
        );

        final json = params.toJson();

        expect(json['speed'], equals(1.5));
        expect(json.containsKey('pitch'), isFalse);
        expect(json.containsKey('volume'), isFalse);
        expect(json.containsKey('voice_id'), isFalse);
      });

      test('toJson should include all values', () {
        const params = TTSVoiceParams(
          speed: 1.0,
          pitch: 1.1,
          volume: 0.9,
          voiceId: 'test_voice',
        );

        final json = params.toJson();

        expect(json['speed'], equals(1.0));
        expect(json['pitch'], equals(1.1));
        expect(json['volume'], equals(0.9));
        expect(json['voice_id'], equals('test_voice'));
      });
    });

    group('VoiceWebSocketConfig', () {
      test('default config should have correct values', () {
        const config = VoiceWebSocketConfig();

        expect(config.sampleRate, equals(16000));
        expect(config.channels, equals(1));
        expect(config.encoding, equals('pcm_s16le'));
        expect(config.reconnectIntervalMs, equals(1000));
        expect(config.maxReconnectAttempts, equals(3));
      });

      test('custom config should override defaults', () {
        const config = VoiceWebSocketConfig(
          sampleRate: 44100,
          channels: 2,
          encoding: 'pcm_f32le',
          reconnectIntervalMs: 2000,
          maxReconnectAttempts: 5,
        );

        expect(config.sampleRate, equals(44100));
        expect(config.channels, equals(2));
        expect(config.encoding, equals('pcm_f32le'));
        expect(config.reconnectIntervalMs, equals(2000));
        expect(config.maxReconnectAttempts, equals(5));
      });
    });

    group('WebSocketState', () {
      test('should have all states', () {
        expect(WebSocketState.values.length, equals(4));
        expect(WebSocketState.values, contains(WebSocketState.disconnected));
        expect(WebSocketState.values, contains(WebSocketState.connecting));
        expect(WebSocketState.values, contains(WebSocketState.connected));
        expect(WebSocketState.values, contains(WebSocketState.error));
      });
    });

    group('VoiceWebSocketClient Initialization', () {
      test('should start disconnected', () {
        final client = VoiceWebSocketClient(
          serverUrl: 'ws://localhost:8080',
        );

        expect(client.state, equals(WebSocketState.disconnected));
        expect(client.isConnected, isFalse);

        client.dispose();
      });

      test('should use default config', () {
        final client = VoiceWebSocketClient(
          serverUrl: 'ws://localhost:8080',
        );

        expect(client.config.sampleRate, equals(16000));
        expect(client.config.channels, equals(1));

        client.dispose();
      });

      test('should accept custom config', () {
        final client = VoiceWebSocketClient(
          serverUrl: 'ws://localhost:8080',
          config: const VoiceWebSocketConfig(
            sampleRate: 48000,
          ),
        );

        expect(client.config.sampleRate, equals(48000));

        client.dispose();
      });
    });

    group('Message Protocol', () {
      test('audio chunk message format', () {
        final audioData = [0x00, 0x01, 0x02, 0x03];
        final base64Data = base64Encode(audioData);

        final message = {
          'type': 'audio_chunk',
          'data': base64Data,
          'sequence': 1,
        };

        expect(message['type'], equals('audio_chunk'));
        expect(message['data'], equals(base64Data));
        expect(message['sequence'], equals(1));
      });

      test('tts request message format', () {
        final message = {
          'type': 'tts_request',
          'text': '你好世界',
          'request_id': 1,
        };

        expect(message['type'], equals('tts_request'));
        expect(message['text'], equals('你好世界'));
        expect(message['request_id'], equals(1));
      });

      test('interrupt message format', () {
        final message = {
          'type': 'interrupt',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        expect(message['type'], equals('interrupt'));
        expect(message['timestamp'], isA<int>());
      });

      test('session start message format', () {
        final message = {
          'type': 'session_start',
          'user_id': 'test_user',
          'audio_format': {
            'sample_rate': 16000,
            'channels': 1,
            'encoding': 'pcm_s16le',
          },
        };

        expect(message['type'], equals('session_start'));
        expect(message['user_id'], equals('test_user'));
        expect(message['audio_format'], isA<Map>());
      });

      test('asr result message parsing', () {
        final intermediateMessage = jsonEncode({
          'type': 'asr_intermediate',
          'text': '你好',
          'is_final': false,
          'confidence': 0.7,
        });

        final finalMessage = jsonEncode({
          'type': 'asr_final',
          'text': '你好世界',
          'is_final': true,
          'confidence': 0.95,
        });

        final intermediateJson = jsonDecode(intermediateMessage);
        final finalJson = jsonDecode(finalMessage);

        expect(intermediateJson['type'], equals('asr_intermediate'));
        expect(intermediateJson['is_final'], isFalse);

        expect(finalJson['type'], equals('asr_final'));
        expect(finalJson['is_final'], isTrue);
      });

      test('tts audio message parsing', () {
        final audioData = [0x00, 0x01, 0x02, 0x03];
        final base64Data = base64Encode(audioData);

        final message = jsonEncode({
          'type': 'tts_audio',
          'data': base64Data,
          'request_id': 1,
        });

        final json = jsonDecode(message);

        expect(json['type'], equals('tts_audio'));
        expect(json['request_id'], equals(1));

        final decodedData = base64Decode(json['data']);
        expect(decodedData, equals(audioData));
      });
    });

    group('Client/Server Message Categories', () {
      test('client to server messages', () {
        final clientMessages = [
          VoiceMessageType.audioChunk,
          VoiceMessageType.ttsRequest,
          VoiceMessageType.interrupt,
          VoiceMessageType.sessionStart,
          VoiceMessageType.sessionEnd,
        ];

        for (final type in clientMessages) {
          expect(type.value, isNotEmpty);
        }
      });

      test('server to client messages', () {
        final serverMessages = [
          VoiceMessageType.asrIntermediate,
          VoiceMessageType.asrFinal,
          VoiceMessageType.ttsAudio,
          VoiceMessageType.ttsComplete,
          VoiceMessageType.sessionReady,
          VoiceMessageType.sessionClosed,
          VoiceMessageType.error,
        ];

        for (final type in serverMessages) {
          expect(type.value, isNotEmpty);
        }
      });
    });
  });
}
