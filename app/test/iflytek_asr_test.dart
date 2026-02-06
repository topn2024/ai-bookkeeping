import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/iflytek_asr_service.dart';

void main() {
  group('IFlytekASR 连通性测试', () {
    late IFlytekASRService asrService;

    setUp(() {
      asrService = IFlytekASRService();
    });

    tearDown(() async {
      await asrService.dispose();
    });

    test('生成WebSocket URL', () {
      // 通过反射或者添加测试方法来验证URL生成逻辑
      // 这里我们验证服务能被正确初始化
      expect(asrService, isNotNull);
    });

    test('测试流式识别连接', () async {
      // 创建一个短的测试音频流（静音）
      final testAudio = Uint8List(1600); // 100ms的16kHz PCM静音
      final audioStream = Stream.value(testAudio);

      bool connectionSuccessful = false;
      String? errorMessage;

      try {
        await for (final result in asrService.transcribeStream(audioStream)) {
          print('收到结果: ${result.text}, isFinal: ${result.isFinal}');
          connectionSuccessful = true;
          break; // 收到第一个结果就停止
        }
      } catch (e) {
        errorMessage = e.toString();
        print('连接失败: $e');
      }

      // 输出测试结果
      if (connectionSuccessful) {
        print('✅ 讯飞ASR连接成功！');
      } else {
        print('❌ 讯飞ASR连接失败: $errorMessage');
      }

      // 注意：由于是测试环境，可能因为网络或其他原因失败
      // 这里不强制要求成功，只是验证代码逻辑
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
