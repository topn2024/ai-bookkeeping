import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import 'package:ai_bookkeeping/services/voice_recognition_engine.dart';
import 'package:ai_bookkeeping/services/voice_token_service.dart';

@GenerateNiceMocks([
  MockSpec<AliCloudASRService>(),
  MockSpec<LocalWhisperService>(),
  MockSpec<NetworkChecker>(),
  MockSpec<VoiceTokenService>(),
])

void main() {
  group('VoiceRecognitionEngine Tests', () {
    group('BookkeepingASROptimizer', () {
      late BookkeepingASROptimizer optimizer;

      setUp(() {
        optimizer = BookkeepingASROptimizer();
      });

      group('postProcessNumbers', () {
        // 注意：当前实现只处理特定模式的中文数字转换
        // 单独的单位数字（如"一"）不会被转换

        test('应该处理单独的"十"', () {
          // 单独的"十"会被替换为"10"
          expect(optimizer.postProcessNumbers('十'), equals('10'));
        });

        test('应该处理十几的数字', () {
          // 处理"十X"格式
          expect(optimizer.postProcessNumbers('十一'), equals('11'));
          expect(optimizer.postProcessNumbers('十二'), equals('12'));
          expect(optimizer.postProcessNumbers('十五'), equals('15'));
          expect(optimizer.postProcessNumbers('十九'), equals('19'));
        });

        test('应该处理百位数', () {
          // 处理"X百XX"格式 - 百位数在"十"替换之前处理
          expect(optimizer.postProcessNumbers('一百'), equals('100'));
          expect(optimizer.postProcessNumbers('五百'), equals('500'));
        });

        test('应该保留非数字文本', () {
          expect(optimizer.postProcessNumbers('午餐'), equals('午餐'));
          expect(optimizer.postProcessNumbers('花了'), equals('花了'));
        });

        test('应该处理混合文本中的十几数字', () {
          // "十X"格式在混合文本中能正确工作
          final result = optimizer.postProcessNumbers('花了十五块');
          expect(result, equals('花了15块'));
        });
      });

      group('normalizeAmountUnit', () {
        test('应该将"块钱"转换为"元"', () {
          expect(optimizer.normalizeAmountUnit('30块钱'), equals('30元'));
          expect(optimizer.normalizeAmountUnit('30块'), equals('30元'));
        });

        test('应该将"毛"转换为"角"', () {
          expect(optimizer.normalizeAmountUnit('5毛'), equals('5角'));
        });

        test('应该正确格式化元角组合', () {
          expect(optimizer.normalizeAmountUnit('30元5角'), equals('30.5元'));
        });

        test('应该正确格式化元分组合', () {
          expect(optimizer.normalizeAmountUnit('30元5分'), equals('30.05元'));
        });
      });

      group('bookkeepingHotWords', () {
        test('应该包含记账相关热词', () {
          final hotWords = BookkeepingASROptimizer.bookkeepingHotWords;

          // 金额表达
          expect(hotWords.any((h) => h.word == '块钱'), isTrue);
          expect(hotWords.any((h) => h.word == '元'), isTrue);

          // 常见分类
          expect(hotWords.any((h) => h.word == '早餐'), isTrue);
          expect(hotWords.any((h) => h.word == '午餐'), isTrue);
          expect(hotWords.any((h) => h.word == '晚餐'), isTrue);

          // 动作词
          expect(hotWords.any((h) => h.word == '花了'), isTrue);
          expect(hotWords.any((h) => h.word == '买了'), isTrue);
        });

        test('打断相关热词应该有高权重', () {
          final hotWords = BookkeepingASROptimizer.bookkeepingHotWords;

          final stopWord = hotWords.firstWhere((h) => h.word == '停');
          expect(stopWord.weight, greaterThanOrEqualTo(2.0));

          final waitWord = hotWords.firstWhere((h) => h.word == '等等');
          expect(waitWord.weight, greaterThanOrEqualTo(2.0));
        });
      });
    });

    group('ASRException', () {
      test('应该正确创建异常', () {
        final exception = ASRException('测试错误');

        expect(exception.message, equals('测试错误'));
        expect(exception.errorCode, equals(ASRErrorCode.unknown));
      });

      test('应该支持指定错误码', () {
        final exception = ASRException(
          '连接超时',
          errorCode: ASRErrorCode.connectionTimeout,
        );

        expect(exception.errorCode, equals(ASRErrorCode.connectionTimeout));
      });

      group('isRetryable', () {
        test('超时错误应该可重试', () {
          expect(
            ASRException('', errorCode: ASRErrorCode.connectionTimeout)
                .isRetryable,
            isTrue,
          );
          expect(
            ASRException('', errorCode: ASRErrorCode.sendTimeout).isRetryable,
            isTrue,
          );
          expect(
            ASRException('', errorCode: ASRErrorCode.receiveTimeout).isRetryable,
            isTrue,
          );
        });

        test('服务器错误应该可重试', () {
          expect(
            ASRException('', errorCode: ASRErrorCode.serverError).isRetryable,
            isTrue,
          );
        });

        test('网络连接错误应该可重试', () {
          expect(
            ASRException('', errorCode: ASRErrorCode.noConnection).isRetryable,
            isTrue,
          );
        });

        test('认证错误不应该重试', () {
          expect(
            ASRException('', errorCode: ASRErrorCode.unauthorized).isRetryable,
            isFalse,
          );
        });

        test('限流错误不应该重试', () {
          expect(
            ASRException('', errorCode: ASRErrorCode.rateLimited).isRetryable,
            isFalse,
          );
        });
      });

      group('userFriendlyMessage', () {
        test('应该返回用户友好的超时消息', () {
          final exception = ASRException(
            '技术错误详情',
            errorCode: ASRErrorCode.connectionTimeout,
          );

          expect(exception.userFriendlyMessage, contains('网络'));
        });

        test('应该返回用户友好的限流消息', () {
          final exception = ASRException(
            '',
            errorCode: ASRErrorCode.rateLimited,
          );

          expect(exception.userFriendlyMessage, contains('频繁'));
        });

        test('应该返回用户友好的认证消息', () {
          final exception = ASRException(
            '',
            errorCode: ASRErrorCode.unauthorized,
          );

          expect(exception.userFriendlyMessage, contains('登录'));
        });
      });

      test('toString 应该包含错误码和消息', () {
        final exception = ASRException(
          '测试消息',
          errorCode: ASRErrorCode.serverError,
        );

        final str = exception.toString();
        expect(str, contains('ASRException'));
        expect(str, contains('serverError'));
        expect(str, contains('测试消息'));
      });
    });

    group('ASRResult', () {
      test('应该正确创建结果', () {
        final result = ASRResult(
          text: '测试文本',
          confidence: 0.95,
          words: [],
          duration: const Duration(seconds: 5),
          isOffline: false,
        );

        expect(result.text, equals('测试文本'));
        expect(result.confidence, equals(0.95));
        expect(result.duration, equals(const Duration(seconds: 5)));
        expect(result.isOffline, isFalse);
      });

      test('copyWith 应该正确复制', () {
        final original = ASRResult(
          text: '原始文本',
          confidence: 0.8,
          words: [],
          duration: const Duration(seconds: 3),
        );

        final copied = original.copyWith(text: '新文本', confidence: 0.95);

        expect(copied.text, equals('新文本'));
        expect(copied.confidence, equals(0.95));
        expect(copied.duration, equals(const Duration(seconds: 3)));
      });
    });

    group('ASRPartialResult', () {
      test('应该正确创建部分结果', () {
        final result = ASRPartialResult(
          text: '部分结果',
          isFinal: false,
          index: 0,
          confidence: 0.7,
        );

        expect(result.text, equals('部分结果'));
        expect(result.isFinal, isFalse);
        expect(result.index, equals(0));
        expect(result.confidence, equals(0.7));
      });

      test('最终结果应该标记为 isFinal', () {
        final result = ASRPartialResult(
          text: '最终结果',
          isFinal: true,
          index: 5,
        );

        expect(result.isFinal, isTrue);
      });
    });

    group('ProcessedAudio', () {
      test('应该正确创建处理后的音频', () {
        final audio = ProcessedAudio(
          data: Uint8List.fromList([1, 2, 3, 4]),
          segments: [],
          duration: const Duration(seconds: 10),
          sampleRate: 16000,
        );

        expect(audio.data.length, equals(4));
        expect(audio.duration, equals(const Duration(seconds: 10)));
        expect(audio.sampleRate, equals(16000));
      });

      test('默认采样率应该是16000', () {
        final audio = ProcessedAudio(
          data: Uint8List(0),
          segments: [],
          duration: Duration.zero,
        );

        expect(audio.sampleRate, equals(16000));
      });
    });

    group('AudioSegment', () {
      test('应该正确计算时长', () {
        const segment = AudioSegment(
          startMs: 1000,
          endMs: 3000,
          isSpeech: true,
        );

        expect(segment.duration, equals(const Duration(milliseconds: 2000)));
      });
    });

    group('HotWord', () {
      test('应该正确创建热词', () {
        const hotWord = HotWord('测试', weight: 1.5);

        expect(hotWord.word, equals('测试'));
        expect(hotWord.weight, equals(1.5));
      });

      test('默认权重应该是1.0', () {
        const hotWord = HotWord('默认');

        expect(hotWord.weight, equals(1.0));
      });
    });

    group('AudioCircularBuffer', () {
      test('应该正确写入和读取数据', () {
        final buffer = AudioCircularBuffer(maxSize: 100);

        buffer.write(Uint8List.fromList([1, 2, 3, 4, 5]));

        expect(buffer.available, equals(5));
        expect(buffer.isEmpty, isFalse);

        final data = buffer.read(3);
        expect(data, equals(Uint8List.fromList([1, 2, 3])));
        expect(buffer.available, equals(2));
      });

      test('缓冲区满时应该覆盖最旧数据', () {
        final buffer = AudioCircularBuffer(maxSize: 5);

        buffer.write(Uint8List.fromList([1, 2, 3, 4, 5]));
        expect(buffer.isFull, isTrue);

        buffer.write(Uint8List.fromList([6, 7]));

        // 最旧的数据(1, 2)应该被覆盖
        final data = buffer.readAll();
        expect(data, equals(Uint8List.fromList([3, 4, 5, 6, 7])));
      });

      test('peek 不应该移动读取位置', () {
        final buffer = AudioCircularBuffer(maxSize: 100);

        buffer.write(Uint8List.fromList([1, 2, 3, 4, 5]));

        final peeked = buffer.peek(3);
        expect(peeked, equals(Uint8List.fromList([1, 2, 3])));
        expect(buffer.available, equals(5)); // 数据仍然存在

        final read = buffer.read(3);
        expect(read, equals(Uint8List.fromList([1, 2, 3])));
        expect(buffer.available, equals(2));
      });

      test('clear 应该清空缓冲区', () {
        final buffer = AudioCircularBuffer(maxSize: 100);

        buffer.write(Uint8List.fromList([1, 2, 3]));
        buffer.clear();

        expect(buffer.isEmpty, isTrue);
        expect(buffer.available, equals(0));
      });

      test('读取超过可用数据时应该返回实际可用的数据', () {
        final buffer = AudioCircularBuffer(maxSize: 100);

        buffer.write(Uint8List.fromList([1, 2, 3]));

        final data = buffer.read(10); // 请求10个字节
        expect(data.length, equals(3)); // 只返回3个
      });
    });

    group('ASRErrorHandlingConfig', () {
      test('应该有合理的默认配置', () {
        expect(ASRErrorHandlingConfig.defaultTimeoutSeconds, greaterThan(0));
        expect(ASRErrorHandlingConfig.maxRetries, greaterThan(0));
        expect(ASRErrorHandlingConfig.baseRetryDelayMs, greaterThan(0));
        expect(ASRErrorHandlingConfig.maxRecognitionSeconds, greaterThan(0));
        expect(ASRErrorHandlingConfig.silenceTimeoutSeconds, greaterThan(0));
      });
    });

    group('FileRecognitionResult', () {
      test('成功结果应该包含文本', () {
        final result = FileRecognitionResult(
          isSuccess: true,
          text: '识别结果',
          confidence: 0.9,
        );

        expect(result.isSuccess, isTrue);
        expect(result.text, equals('识别结果'));
        expect(result.error, isNull);
      });

      test('失败结果应该包含错误信息', () {
        final result = FileRecognitionResult(
          isSuccess: false,
          error: '文件读取失败',
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, equals('文件读取失败'));
      });
    });

    group('RealtimeRecognitionResult', () {
      test('应该正确创建实时识别结果', () {
        final result = RealtimeRecognitionResult(
          text: '实时结果',
          isFinal: false,
        );

        expect(result.text, equals('实时结果'));
        expect(result.isFinal, isFalse);
      });
    });
  });
}
