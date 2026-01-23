import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/dual_channel_processor.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/intelligence_engine.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/models.dart';
import 'package:ai_bookkeeping/services/voice/smart_intent_recognizer.dart';

/// 测试 deferred 操作的聚合窗口和最大等待时间机制
void main() {
  group('Deferred 操作聚合机制测试', () {
    late _TestExecutionChannel channel;
    late List<List<String>> executionBatches;

    setUp(() {
      executionBatches = [];
      channel = _TestExecutionChannel(
        onBatchExecute: (operations) {
          executionBatches.add(operations.map((o) => o.originalText).toList());
        },
      );
    });

    tearDown(() {
      channel.dispose();
    });

    group('基本聚合', () {
      test('deferred 操作应该被聚合', () async {
        // 快速连续入队多个 deferred 操作
        await channel.enqueue(_createDeferredOp('op1'));
        await channel.enqueue(_createDeferredOp('op2'));
        await channel.enqueue(_createDeferredOp('op3'));

        // 等待聚合窗口触发
        await channel.flush();

        // 应该作为一批执行
        expect(channel.executedOperations.length, equals(3));
      });

      test('immediate 操作应该立即执行', () async {
        await channel.enqueue(_createImmediateOp('immediate1'));

        // immediate 操作应该立即执行
        expect(channel.executedOperations.length, equals(1));
        expect(channel.executedOperations[0].originalText, equals('immediate1'));
      });
    });

    group('滑动窗口', () {
      test('新操作应该延长等待窗口', () async {
        await channel.enqueue(_createDeferredOp('op1'));

        // 等待 1 秒后再添加一个操作
        await Future.delayed(const Duration(milliseconds: 1000));
        await channel.enqueue(_createDeferredOp('op2'));

        // 立即 flush 看看结果
        await channel.flush();

        // 两个操作应该被聚合在一起
        expect(channel.executedOperations.length, equals(2));
      });
    });

    group('队列容量限制', () {
      test('队列满时应该自动执行', () async {
        // 入队超过容量限制的操作（默认 10）
        for (var i = 0; i < 12; i++) {
          await channel.enqueue(_createDeferredOp('cap-$i'));
        }

        // 应该已经执行了一批（当达到容量限制时）
        expect(channel.executedOperations.length, greaterThanOrEqualTo(10));
      });
    });
  });

  group('OperationExecutionReport 测试', () {
    test('全部成功时应该生成正确消息', () {
      final report = OperationExecutionReport([
        OperationResultItem(
          index: 0,
          description: '早餐15元',
          isSuccess: true,
          amount: 15,
          operationType: OperationType.addTransaction,
        ),
        OperationResultItem(
          index: 1,
          description: '午餐20元',
          isSuccess: true,
          amount: 20,
          operationType: OperationType.addTransaction,
        ),
      ]);

      expect(report.isAllSuccess, isTrue);
      expect(report.successCount, equals(2));
      expect(report.failureCount, equals(0));
      expect(report.toUserFriendlyMessage(), contains('已记录2笔'));
    });

    test('部分失败时应该生成详细消息', () {
      final report = OperationExecutionReport([
        OperationResultItem(
          index: 0,
          description: '早餐15元',
          isSuccess: true,
          amount: 15,
        ),
        OperationResultItem(
          index: 1,
          description: '午餐20元',
          isSuccess: false,
          errorMessage: '网络错误',
        ),
      ]);

      expect(report.isPartialSuccess, isTrue);
      expect(report.successCount, equals(1));
      expect(report.failureCount, equals(1));

      final message = report.toUserFriendlyMessage();
      expect(message, contains('已记录'));
      expect(message, contains('失败'));
      expect(message, contains('网络错误'));
    });

    test('全部失败时应该生成错误消息', () {
      final report = OperationExecutionReport([
        OperationResultItem(
          index: 0,
          description: '早餐15元',
          isSuccess: false,
          errorMessage: '服务不可用',
        ),
      ]);

      expect(report.isAllFailed, isTrue);
      expect(report.toUserFriendlyMessage(), contains('失败'));
    });

    test('toQuickAcknowledgment 应该生成简短确认', () {
      final successReport = OperationExecutionReport([
        OperationResultItem(index: 0, description: '测试', isSuccess: true),
      ]);
      expect(successReport.toQuickAcknowledgment(), equals('好的'));

      final multiSuccessReport = OperationExecutionReport([
        OperationResultItem(index: 0, description: '测试1', isSuccess: true),
        OperationResultItem(index: 1, description: '测试2', isSuccess: true),
      ]);
      expect(multiSuccessReport.toQuickAcknowledgment(), contains('2笔'));

      final failedReport = OperationExecutionReport([
        OperationResultItem(index: 0, description: '测试', isSuccess: false),
      ]);
      expect(failedReport.toQuickAcknowledgment(), contains('失败'));
    });
  });
}

/// 创建 deferred 优先级的操作
Operation _createDeferredOp(String id) {
  return Operation(
    type: OperationType.addTransaction,
    priority: OperationPriority.deferred,
    params: {'test': id},
    originalText: id,
  );
}

/// 创建 immediate 优先级的操作
Operation _createImmediateOp(String id) {
  return Operation(
    type: OperationType.navigate,
    priority: OperationPriority.immediate,
    params: {'test': id},
    originalText: id,
  );
}

/// 测试用的 ExecutionChannel 包装
class _TestExecutionChannel extends ExecutionChannel {
  final void Function(List<Operation>)? onBatchExecute;

  _TestExecutionChannel({this.onBatchExecute})
      : super(adapter: _TestAdapter());

  List<Operation> get executedOperations =>
      (adapter as _TestAdapter).executedOperations;
}

/// 测试用的适配器
class _TestAdapter implements OperationAdapter {
  final List<Operation> executedOperations = [];

  @override
  String get adapterName => '_TestAdapter';

  @override
  bool canHandle(OperationType type) => true;

  @override
  Future<ExecutionResult> execute(Operation operation) async {
    executedOperations.add(operation);
    return ExecutionResult.success(data: {'executed': operation.originalText});
  }
}
