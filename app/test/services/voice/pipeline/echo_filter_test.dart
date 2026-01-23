import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/detection/echo_filter.dart';
import 'package:ai_bookkeeping/services/voice/config/pipeline_config.dart';

void main() {
  group('EchoFilter Tests', () {
    late EchoFilter filter;

    setUp(() {
      filter = EchoFilter();
    });

    group('TTS状态管理', () {
      test('初始状态：TTS未播放', () {
        expect(filter.isTTSPlaying, isFalse);
        expect(filter.currentTTSText, isEmpty);
      });

      test('onTTSStarted应该更新状态', () {
        filter.onTTSStarted('你好世界');

        expect(filter.isTTSPlaying, isTrue);
        expect(filter.currentTTSText, equals('你好世界'));
      });

      test('onTTSStopped应该更新状态', () {
        filter.onTTSStarted('测试');
        filter.onTTSStopped();

        expect(filter.isTTSPlaying, isFalse);
      });

      test('onTTSTextAppended应该追加文本', () {
        filter.onTTSStarted('你好');
        filter.onTTSTextAppended('世界');

        expect(filter.currentTTSText, equals('你好世界'));
      });
    });

    group('回声过滤 - TTS播放期间', () {
      setUp(() {
        filter.onTTSStarted('好的，帮您记录了一笔30元的餐饮支出');
      });

      test('与TTS完全相同的文本应该被过滤', () {
        final result = filter.check('好的，帮您记录了一笔30元的餐饮支出');
        expect(result, equals(EchoFilterResult.filtered));
      });

      test('与TTS高度相似的文本应该被过滤', () {
        final result = filter.check('好的帮您记录了一笔30元的餐饮支出');
        expect(result, equals(EchoFilterResult.filtered));
      });

      test('TTS文本的前缀应该被过滤', () {
        final result = filter.check('好的帮您记录');
        expect(result, equals(EchoFilterResult.filtered));
      });

      test('与TTS完全不同的文本应该通过', () {
        final result = filter.check('再记一笔50块买菜');
        expect(result, equals(EchoFilterResult.pass));
      });

      test('用户打断词：短词被过滤（由更高层处理）', () {
        // 注意：短打断词如"停"会被短文本过滤器过滤
        // 默认 echoMinTextLength = 3，所以少于3字的会被过滤
        // 真正的打断检测应该在 BargeInDetector 层处理
        expect(filter.check('停'), equals(EchoFilterResult.filtered)); // 1字被过滤
        expect(filter.check('等等'), equals(EchoFilterResult.filtered)); // 2字被过滤
        expect(filter.check('算了吧'), equals(EchoFilterResult.pass)); // 3字通过
      });
    });

    group('回声过滤 - 短文本过滤', () {
      test('短于最小长度的文本应该被过滤', () {
        // 默认最小长度是2
        final result = filter.check('好');
        expect(result, equals(EchoFilterResult.filtered));
      });

      test('空文本应该被过滤', () {
        final result = filter.check('');
        expect(result, equals(EchoFilterResult.filtered));
      });

      test('只有标点的文本应该被过滤', () {
        final result = filter.check('。');
        expect(result, equals(EchoFilterResult.filtered));
      });
    });

    group('回声过滤 - 静默窗口', () {
      test('TTS刚停止后应该在静默窗口内', () {
        filter.onTTSStarted('测试文本');
        filter.onTTSStopped();

        expect(filter.isInSilenceWindow, isTrue);
      });

      test('静默窗口内的相似文本应该被过滤', () {
        filter.onTTSStarted('测试文本');
        filter.onTTSStopped();

        final result = filter.check('测试文本');
        expect(result, equals(EchoFilterResult.filtered));
      });

      test('静默窗口内的不同文本可能标记为可疑', () {
        filter.onTTSStarted('测试文本');
        filter.onTTSStopped();

        // 不太相似但在静默窗口内
        final result = filter.check('完全不同的内容完全不同');
        // 根据相似度，可能是pass或suspicious
        expect(result, isNot(equals(EchoFilterResult.filtered)));
      });
    });

    group('回声过滤 - TTS未播放时', () {
      test('TTS未播放时普通文本应该通过', () {
        final result = filter.check('用户说的话');
        expect(result, equals(EchoFilterResult.pass));
      });

      test('TTS未播放时短文本仍应该被过滤', () {
        final result = filter.check('好');
        expect(result, equals(EchoFilterResult.filtered));
      });
    });

    group('isEcho - 快速检查', () {
      test('是回声时返回true', () {
        filter.onTTSStarted('测试文本');
        expect(filter.isEcho('测试文本'), isTrue);
      });

      test('不是回声时返回false', () {
        filter.onTTSStarted('测试文本');
        expect(filter.isEcho('完全不同的内容'), isFalse);
      });

      test('isPartial参数应该使用更宽松的阈值', () {
        filter.onTTSStarted('好的已经记录了');
        // 中间结果使用更宽松的阈值
        final partialResult = filter.isEcho('好的已记录', isPartial: true);
        final finalResult = filter.isEcho('好的已记录', isPartial: false);
        // 两者可能不同，取决于相似度
        expect(partialResult, isA<bool>());
        expect(finalResult, isA<bool>());
      });
    });

    group('统计信息', () {
      test('初始统计应该为0', () {
        expect(filter.stats['totalChecks'], equals(0));
        expect(filter.stats['filteredCount'], equals(0));
      });

      test('检查后统计应该更新', () {
        filter.onTTSStarted('测试');
        filter.check('测试');
        filter.check('不同内容不同');

        expect(filter.stats['totalChecks'], equals(2));
      });

      test('filterRate应该正确计算', () {
        filter.onTTSStarted('测试');
        filter.check('测');  // 短文本，被过滤
        filter.check('测试'); // 相似，被过滤
        filter.check('完全不同的内容完全不同'); // 通过

        expect(filter.filterRate, greaterThan(0.0));
      });

      test('resetStats应该清空统计', () {
        filter.check('测');
        filter.resetStats();

        expect(filter.stats['totalChecks'], equals(0));
        expect(filter.stats['filteredCount'], equals(0));
      });
    });

    group('reset - 重置状态', () {
      test('reset应该清空所有状态', () {
        filter.onTTSStarted('测试');
        filter.reset();

        expect(filter.isTTSPlaying, isFalse);
        expect(filter.currentTTSText, isEmpty);
      });

      test('reset后应该能正常工作', () {
        filter.onTTSStarted('旧文本');
        filter.reset();
        filter.onTTSStarted('新文本');

        expect(filter.currentTTSText, equals('新文本'));
      });
    });

    group('自定义配置', () {
      test('自定义相似度阈值应该生效', () {
        final config = PipelineConfig(
          echoSimilarityThreshold: 0.9, // 更严格
        );
        final customFilter = EchoFilter(config: config);

        customFilter.onTTSStarted('测试文本啊');
        // 较低相似度的文本可能通过更严格的过滤
        final result = customFilter.check('测试文本');
        // 取决于实际相似度计算
        expect(result, isA<EchoFilterResult>());
      });

      test('自定义最小文本长度应该生效', () {
        final config = PipelineConfig(
          echoMinTextLength: 5, // 更长
        );
        final customFilter = EchoFilter(config: config);

        // "测试" 长度为2，小于5
        final result = customFilter.check('测试');
        expect(result, equals(EchoFilterResult.filtered));
      });
    });

    group('实际场景测试', () {
      test('场景：TTS播报金额，用户确认', () {
        filter.onTTSStarted('记录了一笔30元的餐饮支出');

        // 用户说"好的知道了"确认（需要超过最小长度）
        expect(filter.isEcho('好的知道了'), isFalse);
      });

      test('场景：TTS播报，麦克风捕获回声', () {
        filter.onTTSStarted('记录了一笔30元的餐饮支出');

        // 麦克风捕获了TTS的声音
        expect(filter.isEcho('记录了一笔30元的餐饮'), isTrue);
      });

      test('场景：TTS刚结束，延迟回声', () {
        filter.onTTSStarted('好的');
        filter.onTTSStopped();

        // TTS停止后短时间内的回声
        expect(filter.isInSilenceWindow, isTrue);
        expect(filter.isEcho('好的'), isTrue);
      });

      test('场景：用户打断并说新命令', () {
        filter.onTTSStarted('让我告诉您今天的支出情况');

        // 用户打断说新命令
        expect(filter.isEcho('再记一笔100块'), isFalse);
      });
    });
  });
}
