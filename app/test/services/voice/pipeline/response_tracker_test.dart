import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/tracking/response_tracker.dart';

void main() {
  group('ResponseTracker Tests', () {
    late ResponseTracker tracker;

    setUp(() {
      tracker = ResponseTracker();
    });

    group('startNewResponse - 开始新响应', () {
      test('第一次调用应该返回1', () {
        final id = tracker.startNewResponse();
        expect(id, equals(1));
      });

      test('多次调用应该返回递增的ID', () {
        final id1 = tracker.startNewResponse();
        final id2 = tracker.startNewResponse();
        final id3 = tracker.startNewResponse();

        expect(id1, equals(1));
        expect(id2, equals(2));
        expect(id3, equals(3));
      });
    });

    group('isCurrentResponse - 检查当前响应', () {
      test('当前响应ID应该返回true', () {
        final id = tracker.startNewResponse();
        expect(tracker.isCurrentResponse(id), isTrue);
      });

      test('过期的响应ID应该返回false', () {
        final oldId = tracker.startNewResponse();
        tracker.startNewResponse(); // 新的响应

        expect(tracker.isCurrentResponse(oldId), isFalse);
      });

      test('未来的响应ID应该返回false', () {
        tracker.startNewResponse();
        expect(tracker.isCurrentResponse(999), isFalse);
      });

      test('0在初始状态返回true（因为currentId初始为0）', () {
        // 注意：初始状态 _currentId = 0，所以 isCurrentResponse(0) 返回 true
        expect(tracker.isCurrentResponse(0), isTrue);
      });

      test('负数应该返回false', () {
        tracker.startNewResponse();
        expect(tracker.isCurrentResponse(-1), isFalse);
      });
    });

    group('cancelCurrentResponse - 取消当前响应', () {
      test('取消后当前ID应该失效', () {
        final id = tracker.startNewResponse();
        tracker.cancelCurrentResponse();

        expect(tracker.isCurrentResponse(id), isFalse);
      });

      test('取消后下一个响应应该有新ID', () {
        final id1 = tracker.startNewResponse();
        tracker.cancelCurrentResponse();
        final id2 = tracker.startNewResponse();

        expect(id2, greaterThan(id1));
      });

      test('没有响应时取消不应该出错', () {
        expect(() => tracker.cancelCurrentResponse(), returnsNormally);
      });

      test('多次取消不应该出错', () {
        tracker.startNewResponse();
        tracker.cancelCurrentResponse();
        expect(() => tracker.cancelCurrentResponse(), returnsNormally);
      });
    });

    group('reset - 重置追踪器', () {
      test('重置后当前ID应该失效', () {
        final id = tracker.startNewResponse();
        tracker.reset();

        expect(tracker.isCurrentResponse(id), isFalse);
      });

      test('重置后下一个响应ID从1开始', () {
        tracker.startNewResponse();
        tracker.startNewResponse();
        tracker.startNewResponse();
        tracker.reset();

        final newId = tracker.startNewResponse();
        expect(newId, equals(1));
      });
    });

    group('currentId - 当前响应ID', () {
      test('初始状态应该为0', () {
        expect(tracker.currentId, equals(0));
      });

      test('开始响应后应该更新', () {
        tracker.startNewResponse();
        expect(tracker.currentId, equals(1));
      });

      test('取消后应该增加', () {
        tracker.startNewResponse();
        tracker.cancelCurrentResponse();
        expect(tracker.currentId, equals(2));
      });
    });

    group('打断场景测试', () {
      test('模拟用户打断：TTS正在播放时用户说话', () {
        // 开始响应（LLM开始生成）
        final responseId = tracker.startNewResponse();

        // TTS队列检查响应是否有效
        expect(tracker.isCurrentResponse(responseId), isTrue);

        // 用户打断 -> 取消当前响应
        tracker.cancelCurrentResponse();

        // TTS队列再次检查，应该停止播放
        expect(tracker.isCurrentResponse(responseId), isFalse);
      });

      test('模拟快速打断：连续多次打断', () {
        final ids = <int>[];

        for (var i = 0; i < 5; i++) {
          final id = tracker.startNewResponse();
          ids.add(id);

          // 模拟打断
          tracker.cancelCurrentResponse();
        }

        // 所有旧ID都应该失效
        for (final id in ids) {
          expect(tracker.isCurrentResponse(id), isFalse);
        }
      });

      test('模拟并发场景：检查旧响应在新响应开始后', () {
        final id1 = tracker.startNewResponse();
        // 用户说了新的话，开始新响应
        final id2 = tracker.startNewResponse();

        // id1的TTS应该停止
        expect(tracker.isCurrentResponse(id1), isFalse);
        // id2的TTS应该继续
        expect(tracker.isCurrentResponse(id2), isTrue);
      });
    });

    group('边界情况', () {
      test('大量响应后ID应该继续递增', () {
        for (var i = 0; i < 1000; i++) {
          tracker.startNewResponse();
        }
        final id = tracker.startNewResponse();
        expect(id, equals(1001));
      });

      test('重置后重新使用应该正常', () {
        for (var i = 0; i < 100; i++) {
          tracker.startNewResponse();
        }
        tracker.reset();

        final newId = tracker.startNewResponse();
        expect(newId, equals(1));
        expect(tracker.isCurrentResponse(newId), isTrue);
      });
    });
  });
}
