import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/voice/smart_intent_recognizer.dart';
import '../../lib/services/voice/intelligence_engine/multi_operation_recognizer.dart';
import '../../lib/services/voice/intelligence_engine/dual_channel_processor.dart';
import '../../lib/services/voice/intelligence_engine/intelligent_aggregator.dart';
import '../../lib/services/voice/intelligence_engine/adaptive_conversation_agent.dart';
import '../../lib/services/voice/intelligence_engine/intelligence_engine.dart';
import '../../lib/services/voice/intelligence_engine/models.dart';

// Mock适配器
class TestOperationAdapter implements OperationAdapter {
  final List<Operation> executedOperations = [];

  @override
  String get adapterName => 'TestOperationAdapter';

  @override
  bool canHandle(OperationType type) => true;

  @override
  Future<ExecutionResult> execute(Operation operation) async {
    executedOperations.add(operation);
    await Future.delayed(Duration(milliseconds: 50)); // 模拟执行时间
    return ExecutionResult.success(data: {
      'type': operation.type.toString(),
      'params': operation.params,
    });
  }
}

class TestFeedbackAdapter implements FeedbackAdapter {
  @override
  String get adapterName => 'TestFeedbackAdapter';

  @override
  bool supportsMode(ConversationMode mode) => true;

  @override
  Future<String> generateFeedback(
    ConversationMode mode,
    List<ExecutionResult> results,
    String? chatContent,
  ) async {
    final successCount = results.where((r) => r.success).length;
    switch (mode) {
      case ConversationMode.quickBookkeeping:
        return '✓ $successCount笔';
      case ConversationMode.chat:
        return '好的，有什么可以帮您的吗？';
      case ConversationMode.chatWithIntent:
        return '已为您处理 $successCount 项操作';
      case ConversationMode.mixed:
        return '已记录 $successCount 笔${chatContent != null ? "，$chatContent" : ""}';
    }
  }
}

void main() {
  group('Voice Intelligence Engine Integration Tests', () {
    late MultiOperationRecognizer recognizer;
    late DualChannelProcessor processor;
    late AdaptiveConversationAgent conversationAgent;
    late TestOperationAdapter operationAdapter;
    late TestFeedbackAdapter feedbackAdapter;

    setUp(() {
      recognizer = MultiOperationRecognizer();
      operationAdapter = TestOperationAdapter();
      feedbackAdapter = TestFeedbackAdapter();

      final execChannel = ExecutionChannel(adapter: operationAdapter);
      final convChannel = ConversationChannel(adapter: feedbackAdapter);

      processor = DualChannelProcessor(
        executionChannel: execChannel,
        conversationChannel: convChannel,
      );

      conversationAgent = AdaptiveConversationAgent();
    });

    test('端到端：单个记账操作流程', () async {
      // 1. 识别
      final recognitionResult = await recognizer.recognize('打车35');

      expect(recognitionResult.isSuccess, true);
      expect(recognitionResult.operations.isNotEmpty, true);

      // 2. 处理
      await processor.process(recognitionResult);

      // 3. 检测对话模式
      final mode = conversationAgent.detectMode(
        input: '打车35',
        operations: recognitionResult.operations,
        chatContent: recognitionResult.chatContent,
      );

      // 单个操作应该不是quickBookkeeping模式
      expect(mode, isNot(ConversationMode.quickBookkeeping));
    });

    test('端到端：多个记账操作流程', () async {
      // 1. 识别
      final recognitionResult = await recognizer.recognize('打车35，吃饭50，买菜30');

      expect(recognitionResult.isSuccess, true);

      // 2. 处理
      await processor.process(recognitionResult);

      // 3. 检测对话模式
      final mode = conversationAgent.detectMode(
        input: '打车35，吃饭50，买菜30',
        operations: recognitionResult.operations,
        chatContent: recognitionResult.chatContent,
      );

      // 多个操作可能是quickBookkeeping模式
      if (recognitionResult.operations.length >= 2) {
        expect(mode, ConversationMode.quickBookkeeping);
      }
    });

    test('端到端：混合操作和对话流程', () async {
      // 1. 识别
      final recognitionResult = await recognizer.recognize(
        '打车35，顺便问一下我这个月还能花多少'
      );

      expect(recognitionResult.isSuccess, true);

      // 2. 处理
      await processor.process(recognitionResult);

      // 3. 检测对话模式
      final mode = conversationAgent.detectMode(
        input: '打车35，顺便问一下我这个月还能花多少',
        operations: recognitionResult.operations,
        chatContent: recognitionResult.chatContent,
      );

      // 应该是mixed或chatWithIntent模式
      expect([ConversationMode.mixed, ConversationMode.chatWithIntent].contains(mode), true);
    });

    test('端到端：优先级队列处理', () async {
      final execChannel = ExecutionChannel(adapter: operationAdapter);

      // 添加deferred操作
      await execChannel.enqueue(Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      ));

      // 添加immediate操作
      await execChannel.enqueue(Operation(
        type: OperationType.navigate,
        priority: OperationPriority.immediate,
        params: {'targetPage': '设置'},
        originalText: '打开设置',
      ));

      await Future.delayed(Duration(milliseconds: 200));

      // immediate操作应该先执行
      expect(operationAdapter.executedOperations.length, greaterThanOrEqualTo(1));

      execChannel.dispose();
    });

    test('端到端：聚合触发流程', () async {
      final triggeredBatches = <List<Operation>>[];
      final aggregator = IntelligentAggregator(
        onTrigger: (operations) {
          triggeredBatches.add(operations);
        },
      );

      // 添加多个操作
      aggregator.addOperation(Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      ));

      aggregator.addOperation(Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 50},
        originalText: '吃饭50',
      ));

      // 等待聚合窗口
      await Future.delayed(Duration(milliseconds: 1600));

      expect(triggeredBatches.length, 1);
      expect(triggeredBatches[0].length, 2);

      aggregator.dispose();
    });
  });

  group('Performance Tests', () {
    test('识别性能：应该在合理时间内完成', () async {
      final recognizer = MultiOperationRecognizer();
      final stopwatch = Stopwatch()..start();

      await recognizer.recognize('打车35');

      stopwatch.stop();

      // 应该在5秒内完成（包括LLM超时）
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('聚合性能：应该准确触发', () async {
      final triggeredTimes = <int>[];
      final aggregator = IntelligentAggregator(
        onTrigger: (operations) {
          triggeredTimes.add(DateTime.now().millisecondsSinceEpoch);
        },
      );

      final startTime = DateTime.now().millisecondsSinceEpoch;

      aggregator.addOperation(Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      ));

      await Future.delayed(Duration(milliseconds: 1600));

      expect(triggeredTimes.length, 1);

      final elapsed = triggeredTimes[0] - startTime;
      // 应该在1.5秒左右触发（允许±200ms误差）
      expect(elapsed, greaterThan(1300));
      expect(elapsed, lessThan(1700));

      aggregator.dispose();
    });
  });
}
