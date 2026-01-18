import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/voice/intelligence_engine/intelligent_aggregator.dart';
import '../../../lib/services/voice/smart_intent_recognizer.dart';

void main() {
  group('IntelligentAggregator Tests', () {
    late IntelligentAggregator aggregator;
    late List<List<Operation>> triggeredBatches;

    setUp(() {
      triggeredBatches = [];
      aggregator = IntelligentAggregator(
        onTrigger: (operations) {
          triggeredBatches.add(operations);
        },
      );
    });

    tearDown(() {
      aggregator.dispose();
    });

    test('应该正确添加操作到队列', () {
      final operation = Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      );

      aggregator.addOperation(operation);

      expect(aggregator.queueLength, 1);
      expect(aggregator.state, AggregatorState.waiting);
    });

    test('基础等待计时器应该在1.5秒后触发', () async {
      final operation = Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      );

      aggregator.addOperation(operation);

      // 等待1.6秒（略大于1.5秒）
      await Future.delayed(Duration(milliseconds: 1600));

      expect(triggeredBatches.length, 1);
      expect(triggeredBatches[0].length, 1);
      expect(aggregator.state, AggregatorState.idle);
    });

    test('队列达到最大容量应该立即触发', () async {
      // 添加10个操作（达到最大容量）
      for (int i = 0; i < 10; i++) {
        aggregator.addOperation(Operation(
          type: OperationType.addTransaction,
          priority: OperationPriority.deferred,
          params: {'amount': i + 1},
          originalText: '操作$i',
        ));
      }

      // 应该立即触发
      await Future.delayed(Duration(milliseconds: 100));

      expect(triggeredBatches.length, 1);
      expect(triggeredBatches[0].length, 10);
    });

    test('话题切换应该立即触发前序操作', () async {
      // 添加记账操作
      aggregator.addOperation(Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      ));

      await Future.delayed(Duration(milliseconds: 100));

      // 添加导航操作（话题切换）
      aggregator.addOperation(Operation(
        type: OperationType.navigate,
        priority: OperationPriority.immediate,
        params: {'targetPage': '设置'},
        originalText: '打开设置',
      ));

      await Future.delayed(Duration(milliseconds: 100));

      // 应该触发了前序操作
      expect(triggeredBatches.length, greaterThanOrEqualTo(1));
    });

    test('VAD静音检测应该触发执行', () async {
      aggregator.addOperation(Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      ));

      // 模拟VAD静音检测
      aggregator.onVADSilenceDetected();

      // 等待VAD缓冲时间（300ms）
      await Future.delayed(Duration(milliseconds: 400));

      expect(triggeredBatches.length, 1);
    });

    test('清空队列应该重置状态', () {
      aggregator.addOperation(Operation(
        type: OperationType.addTransaction,
        priority: OperationPriority.deferred,
        params: {'amount': 35},
        originalText: '打车35',
      ));

      aggregator.clear();

      expect(aggregator.queueLength, 0);
      expect(aggregator.state, AggregatorState.idle);
    });
  });

  group('AggregatorState Tests', () {
    test('状态枚举应该包含所有必需状态', () {
      expect(AggregatorState.values.length, 4);
      expect(AggregatorState.values.contains(AggregatorState.idle), true);
      expect(AggregatorState.values.contains(AggregatorState.collecting), true);
      expect(AggregatorState.values.contains(AggregatorState.waiting), true);
      expect(AggregatorState.values.contains(AggregatorState.executing), true);
    });
  });
}
