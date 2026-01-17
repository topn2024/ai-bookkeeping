import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/detection/similarity_calculator.dart';

void main() {
  group('SimilarityCalculator Tests', () {
    late SimilarityCalculator calculator;

    setUp(() {
      calculator = SimilarityCalculator();
    });

    group('calculate - 基础相似度计算', () {
      test('空字符串应该返回0', () {
        expect(calculator.calculate('', '测试'), equals(0.0));
        expect(calculator.calculate('测试', ''), equals(0.0));
        expect(calculator.calculate('', ''), equals(0.0));
      });

      test('完全相同的文本应该返回1.0', () {
        expect(calculator.calculate('测试文本', '测试文本'), equals(1.0));
        expect(calculator.calculate('hello', 'hello'), equals(1.0));
      });

      test('大小写不同应该视为相同', () {
        expect(calculator.calculate('Hello', 'hello'), equals(1.0));
        expect(calculator.calculate('TEST', 'test'), equals(1.0));
      });

      test('带标点符号的文本应该忽略标点', () {
        expect(calculator.calculate('你好！', '你好'), equals(1.0));
        expect(calculator.calculate('测试。', '测试'), equals(1.0));
        expect(calculator.calculate('hello,', 'hello'), equals(1.0));
      });

      test('子串匹配应该返回1.0', () {
        expect(calculator.calculate('测试', '这是一个测试文本'), equals(1.0));
        expect(calculator.calculate('这是一个测试文本', '测试'), equals(1.0));
      });

      test('部分相似的文本应该返回介于0和1之间的值', () {
        final similarity = calculator.calculate('今天吃了汉堡', '明天吃火锅');
        expect(similarity, greaterThan(0.0));
        expect(similarity, lessThan(1.0));
      });

      test('完全不同的文本应该返回接近0的值', () {
        final similarity = calculator.calculate('苹果', 'xyz');
        expect(similarity, lessThan(0.5));
      });
    });

    group('isHighlySimilar - 快速相似度检查', () {
      test('空字符串应该返回false', () {
        expect(calculator.isHighlySimilar('', '测试'), isFalse);
        expect(calculator.isHighlySimilar('测试', ''), isFalse);
      });

      test('相同文本应该返回true', () {
        expect(calculator.isHighlySimilar('测试', '测试'), isTrue);
      });

      test('子串匹配应该返回true', () {
        expect(calculator.isHighlySimilar('测试', '这是测试'), isTrue);
      });

      test('高相似度文本应该返回true', () {
        expect(calculator.isHighlySimilar('你好世界', '你好世', threshold: 0.5), isTrue);
      });

      test('低相似度文本应该返回false', () {
        expect(calculator.isHighlySimilar('苹果', '香蕉橘子', threshold: 0.8), isFalse);
      });

      test('自定义阈值应该生效', () {
        // 同样的文本对，低阈值通过，高阈值不通过
        expect(calculator.isHighlySimilar('abc', 'abcd', threshold: 0.3), isTrue);
        expect(calculator.isHighlySimilar('abc', 'xyz', threshold: 0.9), isFalse);
      });
    });

    group('isPrefixMatch - 前缀匹配检查', () {
      test('空字符串应该返回false', () {
        expect(calculator.isPrefixMatch('', '测试'), isFalse);
        expect(calculator.isPrefixMatch('测试', ''), isFalse);
      });

      test('完全匹配前缀应该返回true', () {
        expect(calculator.isPrefixMatch('你好', '你好世界'), isTrue);
      });

      test('不匹配前缀应该返回false', () {
        expect(calculator.isPrefixMatch('世界', '你好世界'), isFalse);
      });

      test('自定义阈值应该生效', () {
        // 高阈值需要更精确的匹配
        expect(calculator.isPrefixMatch('你', '你好', threshold: 0.8), isTrue);
        expect(calculator.isPrefixMatch('我', '你好', threshold: 0.8), isFalse);
      });
    });

    group('回声检测场景', () {
      test('TTS输出和用户回声应该高度相似', () {
        final ttsText = '好的，已经帮您记录了一笔30元的餐饮支出';
        final echoText = '好的已经帮您记录';

        final similarity = calculator.calculate(ttsText, echoText);
        expect(similarity, greaterThan(0.5));
      });

      test('TTS输出和真实用户输入应该不相似', () {
        final ttsText = '好的，已经帮您记录了一笔30元的餐饮支出';
        final userText = '再记一笔50块钱买菜';

        final similarity = calculator.calculate(ttsText, userText);
        expect(similarity, lessThan(0.5));
      });

      test('回声检测典型场景：用户说的和TTS刚说的一样', () {
        final ttsText = '请问您要记录什么';
        final echoText = '请问您要记录什么';

        expect(calculator.isHighlySimilar(ttsText, echoText), isTrue);
      });

      test('部分回声检测：用户只说了TTS的一部分', () {
        final ttsText = '好的，帮您记录一笔餐饮支出30元';
        final partialEcho = '好的帮您记录一笔';

        // 检查相似度是否较高（前缀匹配可能因实现而异）
        final similarity = calculator.calculate(partialEcho, ttsText);
        expect(similarity, greaterThan(0.5));
      });
    });

    group('打断检测场景', () {
      test('用户打断词应该和TTS内容不相似', () {
        final ttsText = '让我来告诉您今天的支出情况';
        final interruptText = '停';

        final similarity = calculator.calculate(ttsText, interruptText);
        expect(similarity, lessThan(0.3));
      });

      test('用户新指令应该和TTS内容不相似', () {
        final ttsText = '好的，今天总共支出了150元';
        final newCommand = '帮我记一笔20块钱';

        final similarity = calculator.calculate(ttsText, newCommand);
        expect(similarity, lessThan(0.5));
      });
    });

    group('边界情况', () {
      test('只有空格和标点的文本应该返回0', () {
        expect(calculator.calculate('   ', '测试'), equals(0.0));
        expect(calculator.calculate('。，！', '测试'), equals(0.0));
      });

      test('中英文混合文本应该正确处理', () {
        expect(calculator.calculate('hello你好', 'hello你好'), equals(1.0));
        expect(calculator.calculate('hello你好', 'hello'), greaterThan(0.5));
      });

      test('数字文本应该正确处理', () {
        expect(calculator.calculate('123', '123'), equals(1.0));
        expect(calculator.calculate('30元', '30'), greaterThan(0.5));
      });

      test('单字符文本应该正确处理', () {
        expect(calculator.calculate('好', '好'), equals(1.0));
        expect(calculator.calculate('好', '坏'), lessThan(0.5));
      });
    });
  });
}
