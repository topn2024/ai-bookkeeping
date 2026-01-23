import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/pipeline/sentence_buffer.dart';
import 'package:ai_bookkeeping/services/voice/config/pipeline_config.dart';

void main() {
  group('SentenceBuffer Tests', () {
    late SentenceBuffer buffer;

    setUp(() {
      // 使用较小的minSentenceLength便于测试
      buffer = SentenceBuffer(config: PipelineConfig(minSentenceLength: 2));
    });

    group('addChunk - 基本句子检测', () {
      test('空文本不应该产生句子', () {
        final sentences = buffer.addChunk('');
        expect(sentences, isEmpty);
      });

      test('不完整句子不应该产生输出', () {
        final sentences = buffer.addChunk('你好');
        expect(sentences, isEmpty);
        expect(buffer.currentBuffer, equals('你好'));
      });

      test('以句号结尾应该产生完整句子', () {
        final sentences = buffer.addChunk('你好。');
        expect(sentences, hasLength(1));
        expect(sentences[0], equals('你好。'));
      });

      test('以感叹号结尾应该产生完整句子', () {
        final sentences = buffer.addChunk('太好了！');
        expect(sentences, hasLength(1));
        expect(sentences[0], equals('太好了！'));
      });

      test('以问号结尾应该产生完整句子', () {
        final sentences = buffer.addChunk('你好吗？');
        expect(sentences, hasLength(1));
        expect(sentences[0], equals('你好吗？'));
      });

      test('以分号结尾应该产生完整句子', () {
        final sentences = buffer.addChunk('第一部分；');
        expect(sentences, hasLength(1));
        expect(sentences[0], equals('第一部分；'));
      });

      test('以换行符结尾应该产生完整句子', () {
        final sentences = buffer.addChunk('测试内容\n');
        expect(sentences, hasLength(1));
        expect(sentences[0], equals('测试内容'));
      });
    });

    group('addChunk - 流式输入场景', () {
      test('多次添加文本应该累积直到句子完成', () {
        expect(buffer.addChunk('你'), isEmpty);
        expect(buffer.addChunk('好'), isEmpty);
        expect(buffer.addChunk('世'), isEmpty);
        expect(buffer.addChunk('界'), isEmpty);

        final sentences = buffer.addChunk('！');
        expect(sentences, hasLength(1));
        expect(sentences[0], equals('你好世界！'));
      });

      test('一次添加多个句子应该返回多个结果', () {
        final sentences = buffer.addChunk('第一句话。第二句话。第三句话。');
        expect(sentences, hasLength(3));
        expect(sentences[0], equals('第一句话。'));
        expect(sentences[1], equals('第二句话。'));
        expect(sentences[2], equals('第三句话。'));
      });

      test('LLM流式输出模拟：逐字输出', () {
        final chunks = ['好', '的', '，', '帮', '您', '记', '录', '了', '。'];
        final allSentences = <String>[];

        for (final chunk in chunks) {
          allSentences.addAll(buffer.addChunk(chunk));
        }

        expect(allSentences, hasLength(1));
        expect(allSentences[0], equals('好的，帮您记录了。'));
      });

      test('LLM流式输出模拟：多字块输出', () {
        final chunks = ['好的，', '帮您记录了', '一笔30元', '的支出。', '还需要', '帮您做什么？'];
        final allSentences = <String>[];

        for (final chunk in chunks) {
          allSentences.addAll(buffer.addChunk(chunk));
        }

        expect(allSentences, hasLength(2));
        expect(allSentences[0], equals('好的，帮您记录了一笔30元的支出。'));
        expect(allSentences[1], equals('还需要帮您做什么？'));
      });
    });

    group('addChunk - 最小长度控制', () {
      test('短于最小长度的句子应该被缓冲', () {
        // 使用默认配置，minSentenceLength = 4
        final defaultBuffer = SentenceBuffer();
        // "好。" 长度为2，小于4
        final sentences = defaultBuffer.addChunk('好。');
        expect(sentences, isEmpty);
        expect(defaultBuffer.currentBuffer, contains('好'));
      });

      test('满足最小长度的句子应该输出', () {
        // 使用minSentenceLength = 2的配置
        final sentences = buffer.addChunk('好的。');
        expect(sentences, hasLength(1));
      });

      test('自定义最小长度配置', () {
        final config = PipelineConfig(minSentenceLength: 5);
        final customBuffer = SentenceBuffer(config: config);

        // "好的。" 长度为3，小于5
        final sentences = customBuffer.addChunk('好的。');
        expect(sentences, isEmpty);
        expect(customBuffer.currentBuffer, contains('好的'));
      });
    });

    group('flush - 强制输出', () {
      test('flush应该返回所有待处理文本', () {
        buffer.addChunk('未完成的句子');
        final flushed = buffer.flush();
        expect(flushed, equals('未完成的句子'));
        expect(buffer.currentBuffer, isEmpty);
      });

      test('flush空缓冲区应该返回空字符串', () {
        final flushed = buffer.flush();
        expect(flushed, isEmpty);
      });

      test('flush后再添加文本应该从头开始', () {
        buffer.addChunk('第一部分');
        buffer.flush();
        final sentences = buffer.addChunk('第二部分。');

        expect(sentences, hasLength(1));
        expect(sentences[0], equals('第二部分。'));
      });
    });

    group('reset/clear - 重置缓冲区', () {
      test('reset应该清空缓冲区', () {
        buffer.addChunk('待处理文本');
        buffer.reset();
        expect(buffer.currentBuffer, isEmpty);
      });

      test('clear应该清空缓冲区和计数', () {
        buffer.addChunk('测试句。');
        buffer.clear();
        expect(buffer.currentBuffer, isEmpty);
        expect(buffer.sentenceCount, equals(0));
      });

      test('reset后应该能正常工作', () {
        buffer.addChunk('旧文本');
        buffer.reset();
        final sentences = buffer.addChunk('新文本。');
        expect(sentences, hasLength(1));
        expect(sentences[0], equals('新文本。'));
      });
    });

    group('currentBuffer - 当前缓冲区内容', () {
      test('初始状态应该为空', () {
        expect(buffer.currentBuffer, isEmpty);
      });

      test('添加不完整句子后应该有待处理文本', () {
        buffer.addChunk('待处理');
        expect(buffer.currentBuffer, equals('待处理'));
      });

      test('完成句子后应该清空待处理文本', () {
        buffer.addChunk('完整句子。');
        expect(buffer.currentBuffer, isEmpty);
      });

      test('完成句子后有剩余应该保留', () {
        buffer.addChunk('第一句。第二');
        expect(buffer.currentBuffer, equals('第二'));
      });
    });

    group('sentenceCount - 句子计数', () {
      test('初始计数为0', () {
        expect(buffer.sentenceCount, equals(0));
      });

      test('输出句子后计数增加', () {
        buffer.addChunk('第一句。');
        expect(buffer.sentenceCount, equals(1));

        buffer.addChunk('第二句。');
        expect(buffer.sentenceCount, equals(2));
      });

      test('flush也增加计数', () {
        buffer.addChunk('未完成');
        buffer.flush();
        expect(buffer.sentenceCount, equals(1));
      });
    });

    group('isEmpty/length 属性', () {
      test('初始状态isEmpty为true', () {
        expect(buffer.isEmpty, isTrue);
        expect(buffer.length, equals(0));
      });

      test('添加内容后isEmpty为false', () {
        buffer.addChunk('测试');
        expect(buffer.isEmpty, isFalse);
        expect(buffer.length, equals(2));
      });

      test('输出完整句子后缓冲区应为空', () {
        buffer.addChunk('测试。');
        expect(buffer.isEmpty, isTrue);
      });
    });

    group('边界情况', () {
      test('连续短句可能被累积', () {
        final sentences = buffer.addChunk('好。棒。赞。');
        // 使用minSentenceLength=2的配置，所有句子都应该输出
        expect(sentences.length, greaterThanOrEqualTo(1));
      });

      test('非常长的句子应该正确处理', () {
        final longText = '这是一个非常长的句子' * 50 + '。';
        final sentences = buffer.addChunk(longText);
        expect(sentences.length, greaterThanOrEqualTo(1));
      });

      test('带空格的句子应该保留内容', () {
        final sentences = buffer.addChunk('你好 世界。');
        expect(sentences, hasLength(1));
        expect(sentences[0], contains('世界'));
      });
    });
  });
}
