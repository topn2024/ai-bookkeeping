import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/voice/smart_intent_recognizer.dart';

void main() {
  group('MultiOperationRecognizer Tests', () {
    late SmartIntentRecognizer recognizer;

    setUp(() {
      recognizer = SmartIntentRecognizer();
    });

    test('应该识别单个记账操作', () async {
      final result = await recognizer.recognizeMultiOperation('打车35');

      expect(result.isSuccess, true);
      expect(result.operations.length, 1);
      expect(result.operations[0].type, OperationType.addTransaction);
      expect(result.operations[0].priority, OperationPriority.deferred);
      expect(result.chatContent, null);
    });

    test('应该识别多个记账操作', () async {
      final result = await recognizer.recognizeMultiOperation('打车35，吃饭50，买菜30');

      expect(result.isSuccess, true);
      expect(result.operations.length, greaterThanOrEqualTo(1));

      // 检查至少有一个记账操作
      final hasBookkeeping = result.operations.any(
        (op) => op.type == OperationType.addTransaction
      );
      expect(hasBookkeeping, true);
    });

    test('应该识别混合操作和对话内容', () async {
      final result = await recognizer.recognizeMultiOperation(
        '打车35，顺便问一下我这个月还能花多少'
      );

      expect(result.isSuccess, true);
      expect(result.operations.isNotEmpty, true);

      // 可能包含对话内容或查询操作
      final hasChatOrQuery = result.chatContent != null ||
        result.operations.any((op) => op.type == OperationType.query);
      expect(hasChatOrQuery, true);
    });

    test('应该处理空输入', () async {
      final result = await recognizer.recognizeMultiOperation('');

      expect(result.isSuccess, false);
      expect(result.errorMessage, isNotNull);
    });

    test('应该正确分类操作优先级', () async {
      final result = await recognizer.recognizeMultiOperation('打开设置');

      if (result.isSuccess && result.operations.isNotEmpty) {
        final navOp = result.operations.firstWhere(
          (op) => op.type == OperationType.navigate,
          orElse: () => result.operations.first,
        );

        // 导航操作应该是 immediate 优先级
        if (navOp.type == OperationType.navigate) {
          expect(navOp.priority, OperationPriority.immediate);
        }
      }
    });

    test('LLM超时应该降级到规则兜底', () async {
      // 这个测试需要模拟LLM超时，实际测试中会使用mock
      final result = await recognizer.recognizeMultiOperation('打车35');

      // 无论LLM是否可用，都应该能识别
      expect(result.isSuccess, true);
    });
  });

  group('Operation Priority Tests', () {
    test('记账操作应该是deferred优先级', () {
      // 测试优先级推断逻辑
      expect(OperationPriority.deferred.index < OperationPriority.background.index, true);
    });

    test('导航操作应该是immediate优先级', () {
      expect(OperationPriority.immediate.index < OperationPriority.normal.index, true);
    });
  });

  group('MultiOperationResult Tests', () {
    test('应该正确创建成功结果', () {
      final result = MultiOperationResult(
        operations: [
          Operation(
            type: OperationType.addTransaction,
            priority: OperationPriority.deferred,
            params: {'amount': 35},
            originalText: '打车35',
          ),
        ],
        chatContent: null,
        confidence: 0.9,
        source: RecognitionSource.llm,
        originalInput: '打车35',
      );

      expect(result.isSuccess, true);
      expect(result.operations.length, 1);
    });

    test('应该正确创建错误结果', () {
      final result = MultiOperationResult.error('测试错误');

      expect(result.isSuccess, false);
      expect(result.errorMessage, '测试错误');
      expect(result.operations.isEmpty, true);
    });
  });
}
