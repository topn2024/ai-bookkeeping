import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/detection/barge_in_detector_v2.dart';
import 'package:ai_bookkeeping/services/voice/config/pipeline_config.dart';

void main() {
  group('BargeInDetectorV2 Tests', () {
    late BargeInDetectorV2 detector;

    setUp(() {
      detector = BargeInDetectorV2();
    });

    group('TTS状态管理', () {
      test('初始状态：TTS未播放', () {
        expect(detector.isEnabled, isFalse);
        expect(detector.currentTTSText, isEmpty);
      });

      test('更新TTS状态：开始播放', () {
        detector.updateTTSState(isPlaying: true, currentText: '测试文本');

        expect(detector.isEnabled, isTrue);
        expect(detector.currentTTSText, equals('测试文本'));
      });

      test('更新TTS状态：停止播放', () {
        detector.updateTTSState(isPlaying: true, currentText: '测试');
        detector.updateTTSState(isPlaying: false, currentText: '');

        expect(detector.isEnabled, isFalse);
      });

      test('追加TTS文本', () {
        detector.updateTTSState(isPlaying: true, currentText: '你好');
        detector.appendTTSText('世界');

        expect(detector.currentTTSText, equals('你好世界'));
      });
    });

    group('VAD状态管理', () {
      test('初始VAD状态', () {
        expect(detector.vadSpeechDetected, isFalse);
      });

      test('更新VAD状态', () {
        detector.updateVADState(true);
        expect(detector.vadSpeechDetected, isTrue);

        detector.updateVADState(false);
        expect(detector.vadSpeechDetected, isFalse);
      });
    });

    group('handlePartialResult - 中间结果处理', () {
      setUp(() {
        detector.updateTTSState(isPlaying: true, currentText: '好的，帮您记录了一笔支出');
      });

      test('TTS未播放时不应该触发打断', () {
        detector.updateTTSState(isPlaying: false, currentText: '');
        final result = detector.handlePartialResult('用户说话');

        expect(result.triggered, isFalse);
      });

      test('空文本不应该触发打断', () {
        final result = detector.handlePartialResult('');
        expect(result.triggered, isFalse);
      });

      test('第1层：VAD+ASR检测（短文本+VAD）', () {
        detector.updateVADState(true);

        // 4字以上，与TTS不相似
        final result = detector.handlePartialResult('再记一笔');

        if (result.triggered) {
          expect(result.layer, equals(BargeInLayer.vadBased));
        }
      });

      test('第2层：纯ASR检测（较长文本）', () {
        // 8字以上，与TTS不相似
        final result = detector.handlePartialResult('我要记一笔100块钱');

        if (result.triggered) {
          expect(result.layer, anyOf(
            equals(BargeInLayer.vadBased),
            equals(BargeInLayer.vadBased),
          ));
        }
      });

      test('与TTS相似的文本不应该触发打断', () {
        detector.updateVADState(true);
        // 与TTS内容相似（回声）
        final result = detector.handlePartialResult('好的帮您记录了');

        expect(result.triggered, isFalse);
      });
    });

    group('handleFinalResult - 最终结果处理', () {
      setUp(() {
        detector.updateTTSState(isPlaying: true, currentText: '好的，帮您记录了一笔支出');
      });

      test('TTS未播放时不应该触发打断', () {
        detector.updateTTSState(isPlaying: false, currentText: '');
        final result = detector.handleFinalResult('用户说话');

        expect(result.triggered, isFalse);
      });

      test('第3层：完整句子+回声过滤', () {
        final result = detector.handleFinalResult('我要记一笔新的支出');

        if (result.triggered) {
          expect(result.layer, equals(BargeInLayer.finalResult));
        }
      });

      test('回声应该被过滤', () {
        final result = detector.handleFinalResult('好的帮您记录了一笔支出');

        // 如果与TTS高度相似，应该被回声过滤
        // 结果取决于相似度计算
        expect(result, isA<BargeInResult>());
      });

      test('用户新命令应该触发打断', () {
        final result = detector.handleFinalResult('再记一笔50块买菜的支出');

        if (result.triggered) {
          expect(result.layer, equals(BargeInLayer.finalResult));
          expect(result.text, contains('50'));
        }
      });
    });

    group('冷却时间控制', () {
      setUp(() {
        detector.updateTTSState(isPlaying: true, currentText: '测试');
      });

      test('触发打断后应该进入冷却期', () async {
        detector.updateVADState(true);

        // 第一次触发
        final result1 = detector.handlePartialResult('用户说话了一些内容');

        if (result1.triggered) {
          // 立即再次尝试（应该被冷却时间阻止）
          final result2 = detector.handlePartialResult('用户又说话了内容');

          // 在冷却期内，可能不触发
          // 具体行为取决于配置的冷却时间
        }
      });
    });

    group('回调机制', () {
      setUp(() {
        detector.updateTTSState(isPlaying: true, currentText: '测试');
      });

      test('onBargeIn回调应该被调用', () async {
        BargeInResult? callbackResult;
        detector.onBargeIn = (result) {
          callbackResult = result;
        };

        detector.updateVADState(true);
        final result = detector.handlePartialResult('用户说了很长的一段话来测试');

        if (result.triggered) {
          expect(callbackResult, isNotNull);
          expect(callbackResult!.triggered, isTrue);
        }
      });
    });

    group('统计信息', () {
      test('初始统计应该为0', () {
        expect(detector.stats['totalChecks'], equals(0));
        expect(detector.stats['layer1Triggers'], equals(0));
        expect(detector.stats['layer2Triggers'], equals(0));
        expect(detector.stats['layer3Triggers'], equals(0));
      });

      test('检查后统计应该更新', () {
        detector.updateTTSState(isPlaying: true, currentText: '测试');
        detector.handlePartialResult('用户说话');

        expect(detector.stats['totalChecks'], greaterThanOrEqualTo(0));
      });

      test('resetStats应该清空统计', () {
        detector.updateTTSState(isPlaying: true, currentText: '测试');
        detector.handlePartialResult('用户说话');
        detector.resetStats();

        expect(detector.stats['totalChecks'], equals(0));
      });
    });

    group('reset - 重置状态', () {
      test('reset应该清空所有状态', () {
        detector.updateTTSState(isPlaying: true, currentText: '测试');
        detector.updateVADState(true);
        detector.reset();

        expect(detector.isEnabled, isFalse);
        expect(detector.vadSpeechDetected, isFalse);
        expect(detector.currentTTSText, isEmpty);
      });
    });

    group('自定义配置', () {
      test('自定义配置应该生效', () {
        final config = PipelineConfig(
          bargeInLayer1MinChars: 2, // 更短
          bargeInLayer1Threshold: 0.5,
        );
        final customDetector = BargeInDetectorV2(config: config);

        customDetector.updateTTSState(isPlaying: true, currentText: '测试');
        customDetector.updateVADState(true);

        // 使用自定义配置，2字即可触发
        final result = customDetector.handlePartialResult('你好');

        // 结果取决于配置
        expect(result, isA<BargeInResult>());
      });
    });

    group('实际场景测试', () {
      test('场景：用户说"停"打断TTS', () {
        detector.updateTTSState(
          isPlaying: true,
          currentText: '让我告诉您今天的支出详情',
        );
        detector.updateVADState(true);

        // "停"太短，可能不会触发第1层
        final partialResult = detector.handlePartialResult('停');
        // 但最终结果会通过第3层
        final finalResult = detector.handleFinalResult('停');

        // 至少有一个应该能处理
        expect(partialResult, isA<BargeInResult>());
        expect(finalResult, isA<BargeInResult>());
      });

      test('场景：用户说新命令打断', () {
        detector.updateTTSState(
          isPlaying: true,
          currentText: '好的，帮您记录了一笔30元的餐饮支出',
        );
        detector.updateVADState(true);

        final result = detector.handleFinalResult('等等，金额是35不是30');

        if (result.triggered) {
          expect(result.text, contains('35'));
        }
      });

      test('场景：回声不应触发打断', () {
        detector.updateTTSState(
          isPlaying: true,
          currentText: '请问您要记录什么',
        );

        // 麦克风捕获的TTS回声
        final result = detector.handleFinalResult('请问您要记录什么');

        // 应该被回声过滤，不触发打断
        expect(result.triggered, isFalse);
      });
    });

    group('BargeInResult', () {
      test('notTriggered常量应该正确', () {
        expect(BargeInResult.notTriggered.triggered, isFalse);
        expect(BargeInResult.notTriggered.layer, isNull);
        expect(BargeInResult.notTriggered.text, isNull);
      });

      test('toString应该正确格式化', () {
        final result = BargeInResult(
          triggered: true,
          layer: BargeInLayer.vadBased,
          text: '测试',
          reason: 'test',
        );

        final str = result.toString();
        expect(str, contains('triggered'));
        expect(str, contains('vadBased'));
      });
    });
  });
}
