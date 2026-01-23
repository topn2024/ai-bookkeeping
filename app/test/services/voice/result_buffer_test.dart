import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/result_buffer.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/models.dart';

void main() {
  group('ResultBuffer', () {
    late ResultBuffer buffer;

    setUp(() {
      buffer = ResultBuffer();
    });

    tearDown(() {
      buffer.dispose();
    });

    group('add()', () {
      test('should add result to buffer', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '午餐30元',
          amount: 30.0,
          operationType: OperationType.addTransaction,
        );

        expect(buffer.pendingCount, 1);
        expect(result.description, '午餐30元');
        expect(result.amount, 30.0);
        expect(result.status, ResultStatus.pending);
      });

      test('should calculate critical priority for delete operation', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '删除记录',
          operationType: OperationType.delete,
        );

        expect(result.priority, ResultPriority.critical);
      });

      test('should calculate critical priority for large amount (>1000)', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '大额消费',
          amount: 1500.0,
          operationType: OperationType.addTransaction,
        );

        expect(result.priority, ResultPriority.critical);
      });

      test('should calculate normal priority for regular transaction', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '小额消费',
          amount: 50.0,
          operationType: OperationType.addTransaction,
        );

        expect(result.priority, ResultPriority.normal);
      });

      test('should respect max capacity and evict old results', () {
        // Fill buffer to capacity
        for (int i = 0; i < ResultBuffer.maxCapacity; i++) {
          final result = buffer.add(
            result: ExecutionResult.success(),
            description: '消费$i',
            amount: 10.0,
          );
          // Mark some as notified to make them evictable
          if (i < 3) {
            buffer.markNotified(result.id);
          }
        }

        expect(buffer.pendingCount, ResultBuffer.maxCapacity - 3);

        // Adding one more should trigger eviction
        buffer.add(
          result: ExecutionResult.success(),
          description: '新消费',
          amount: 20.0,
        );

        // Should still be at or below max capacity
        expect(buffer.pendingCount, lessThanOrEqualTo(ResultBuffer.maxCapacity));
      });
    });

    group('pendingResults', () {
      test('should return pending results sorted by priority', () {
        buffer.add(
          result: ExecutionResult.success(),
          description: '普通消费',
          amount: 50.0,
          operationType: OperationType.addTransaction,
        );
        buffer.add(
          result: ExecutionResult.success(),
          description: '大额消费',
          amount: 2000.0,
          operationType: OperationType.addTransaction,
        );
        buffer.add(
          result: ExecutionResult.success(),
          description: '删除记录',
          operationType: OperationType.delete,
        );

        final pending = buffer.pendingResults;

        expect(pending.length, 3);
        // Critical should come first
        expect(pending[0].priority, ResultPriority.critical);
        expect(pending[1].priority, ResultPriority.critical);
        expect(pending[2].priority, ResultPriority.normal);
      });

      test('should not return notified results', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '消费',
          amount: 30.0,
        );

        expect(buffer.pendingCount, 1);

        buffer.markNotified(result.id);

        expect(buffer.pendingCount, 0);
        expect(buffer.pendingResults, isEmpty);
      });

      test('should not return suppressed results', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '消费',
          amount: 30.0,
        );

        expect(buffer.pendingCount, 1);

        buffer.markSuppressed(result.id);

        expect(buffer.pendingCount, 0);
        expect(buffer.pendingResults, isEmpty);
      });
    });

    group('markNotified()', () {
      test('should mark result as notified', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '消费',
          amount: 30.0,
        );

        buffer.markNotified(result.id);

        expect(result.status, ResultStatus.notified);
      });

      test('should handle non-existent id gracefully', () {
        // Should not throw
        buffer.markNotified('non_existent_id');
      });
    });

    group('markSuppressed()', () {
      test('should mark result as suppressed', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '消费',
          amount: 30.0,
        );

        buffer.markSuppressed(result.id);

        expect(result.status, ResultStatus.suppressed);
      });
    });

    group('suppressAll()', () {
      test('should suppress all pending results', () {
        buffer.add(
          result: ExecutionResult.success(),
          description: '消费1',
          amount: 10.0,
        );
        buffer.add(
          result: ExecutionResult.success(),
          description: '消费2',
          amount: 20.0,
        );
        buffer.add(
          result: ExecutionResult.success(),
          description: '消费3',
          amount: 30.0,
        );

        expect(buffer.pendingCount, 3);

        buffer.suppressAll();

        expect(buffer.pendingCount, 0);
      });
    });

    group('getSummaryForContext()', () {
      test('should return null when no pending results', () {
        expect(buffer.getSummaryForContext(), isNull);
      });

      test('should return summary with pending results', () {
        buffer.add(
          result: ExecutionResult.success(),
          description: '午餐',
          amount: 30.0,
        );
        buffer.add(
          result: ExecutionResult.success(),
          description: '晚餐',
          amount: 50.0,
        );

        final summary = buffer.getSummaryForContext();

        expect(summary, isNotNull);
        expect(summary, contains('后台执行结果'));
        expect(summary, contains('午餐'));
        expect(summary, contains('晚餐'));
      });
    });

    group('clear()', () {
      test('should clear all results', () {
        buffer.add(
          result: ExecutionResult.success(),
          description: '消费',
          amount: 30.0,
        );

        expect(buffer.pendingCount, 1);

        buffer.clear();

        expect(buffer.pendingCount, 0);
        expect(buffer.hasPendingResults, isFalse);
      });
    });

    group('BufferedResult', () {
      test('isExpired should return false for new result', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '消费',
          amount: 30.0,
        );

        expect(result.isExpired, isFalse);
      });

      test('canNotify should return true for new pending result', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '消费',
          amount: 30.0,
        );

        expect(result.canNotify, isTrue);
      });

      test('canNotify should return false for notified result', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '消费',
          amount: 30.0,
        );

        buffer.markNotified(result.id);

        expect(result.canNotify, isFalse);
      });
    });
  });
}
