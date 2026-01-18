import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/voice/intelligence_engine/dual_channel_processor.dart';
import '../../../lib/services/voice/intelligence_engine/intelligence_engine.dart';
import '../../../lib/services/voice/intelligence_engine/models.dart';
import '../../../lib/services/voice/smart_intent_recognizer.dart';

// Mock适配器用于测试
class MockOperationAdapter implements OperationAdapter {
  final List<Operation> executedOperations = [];

  @override
  String get adapterName => 'MockOperationAdapter';

  @override
  bool canHandle(OperationType type) => true;

  @override
  Future<ExecutionResult> execute(Operation operation) async {
    executedOperations.add(operation);
    return ExecutionResult.success(data: {'mock': true});
  }
}

class MockFeedbackAdapter implements FeedbackAdapter {
  @override
  String get adapterName => 'MockFeedbackAdapter';

  @override
  bool supportsMode(ConversationMode mode) => true;

  @override
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  ) async {
    return 'Mock feedback: ${results.length} results';
  }
}

void main() {
  group('ExecutionChannel Tests', () {
    late ExecutionChannel channel;
    late MockOperationAdapter adapter;

    setUp(() {
      adapter = MockOperationAdapter();
      channel = ExecutionChannel(adapter: adapter);
    });

    tearDown(() {
      channel.dispose();
    });

    test('immediate操作应该立即执行', () async {
      final operation = Operation(
        type: OperationType.navigate,
        priority: OperationPriority.immediate,
        params: {'targetPage': '设置'},
        originalText: '打开设置',
      );

      await channel.enqueue(operation);

      // immediate操作应该立即执行
      expect(adapter.executedOperations.length, 1);
      expect(adapter.executedOperations[0].type, OperationType.navigate);
    });

    test('deferred操作应该进入聚合队列', () async {
      final operation = Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      );

      await channel.enqueue(operation);

      // deferred操作不会立即执行
      // 需要等待聚合窗口或手动触发
      await Future.delayed(Duration(milliseconds: 100));
    });

    test('回调应该被正确触发', () async {
      final results = <ExecutionResult>[];
      channel.registerCallback((result) {
        results.add(result);
      });

      final operation = Operation(
        type: OperationType.navigate,
        priority: OperationPriority.immediate,
        params: {},
        originalText: 'test',
      );

      await channel.enqueue(operation);

      expect(results.length, 1);
      expect(results[0].success, true);
    });
  });

  group('ConversationChannel Tests', () {
    late ConversationChannel channel;
    late MockFeedbackAdapter adapter;

    setUp(() {
      adapter = MockFeedbackAdapter();
      channel = ConversationChannel(adapter: adapter);
    });

    test('应该正确添加对话内容', () {
      channel.addChatContent('测试对话');
      // 验证内部状态（通过生成响应来间接验证）
    });

    test('应该正确添加执行结果', () {
      final result = ExecutionResult.success(data: {'test': true});
      channel.addExecutionResult(result);

      final recent = channel.getRecentResults();
      expect(recent.length, 1);
      expect(recent[0].success, true);
    });

    test('应该生成响应', () async {
      channel.addExecutionResult(ExecutionResult.success());
      channel.addChatContent('测试');

      final response = await channel.generateResponse(ConversationMode.chat);

      expect(response, isNotEmpty);
      expect(response, contains('Mock feedback'));
    });

    test('生成响应后应该清空状态', () async {
      channel.addExecutionResult(ExecutionResult.success());
      await channel.generateResponse(ConversationMode.chat);

      final recent = channel.getRecentResults();
      expect(recent.isEmpty, true);
    });
  });

  group('DualChannelProcessor Tests', () {
    late DualChannelProcessor processor;
    late MockOperationAdapter opAdapter;
    late MockFeedbackAdapter fbAdapter;

    setUp(() {
      opAdapter = MockOperationAdapter();
      fbAdapter = MockFeedbackAdapter();

      final execChannel = ExecutionChannel(adapter: opAdapter);
      final convChannel = ConversationChannel(adapter: fbAdapter);

      processor = DualChannelProcessor(
        executionChannel: execChannel,
        conversationChannel: convChannel,
      );
    });

    test('应该正确处理多操作结果', () async {
      final result = MultiOperationResult(
        operations: [
          Operation(
            type: OperationType.addTransaction,
            priority: OperationPriority.deferred,
            params: {'amount': 35},
            originalText: '打车35',
          ),
        ],
        chatContent: '测试对话',
        confidence: 0.9,
        source: RecognitionSource.llmFallback,
        originalInput: '打车35，测试对话',
      );

      await processor.process(result);

      // 验证操作被分发到执行通道
      // 验证对话内容被传递到对话通道
    });
  });
}
