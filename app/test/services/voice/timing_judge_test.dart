import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/timing_judge.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/result_buffer.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/models.dart';

void main() {
  group('TimingJudge', () {
    late TimingJudge judge;

    setUp(() {
      judge = TimingJudge();
    });

    group('judge()', () {
      test('should return suppress when no pending results', () {
        final context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 0,
          pendingResultCount: 0,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.suppress);
        expect(judgment.reason, '无待通知结果');
        expect(judgment.shouldNotify, isFalse);
      });

      test('should return defer when user is speaking', () {
        final context = TimingContext(
          isUserSpeaking: true,
          silenceDurationMs: 0,
          pendingResultCount: 1,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.defer);
        expect(judgment.reason, '用户正在说话');
        expect(judgment.shouldNotify, isFalse);
      });

      test('should return immediate when user asks about result', () {
        final context = TimingContext(
          userInput: '记好了吗',
          isUserSpeaking: false,
          silenceDurationMs: 0,
          pendingResultCount: 1,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.immediate);
        expect(judgment.reason, '用户主动询问');
        expect(judgment.shouldNotify, isTrue);
      });

      test('should detect various asking patterns', () {
        final patterns = [
          '记好了吗',
          '记上了吗',
          '好了吗',
          '完成了吗',
          '弄好了吗',
          '怎么样了',
          '搞定了吗',
          '成功了吗',
          '记了吗',
          '存了吗',
          '保存了吗',
        ];

        for (final pattern in patterns) {
          final context = TimingContext(
            userInput: pattern,
            isUserSpeaking: false,
            silenceDurationMs: 0,
            pendingResultCount: 1,
          );

          final judgment = judge.judge(context);

          expect(
            judgment.timing,
            NotificationTiming.immediate,
            reason: 'Pattern "$pattern" should trigger immediate notification',
          );
        }
      });

      test('should detect asking patterns with punctuation', () {
        final context = TimingContext(
          userInput: '记好了吗？',
          isUserSpeaking: false,
          silenceDurationMs: 0,
          pendingResultCount: 1,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.immediate);
      });

      test('should return defer when user has negative emotion', () {
        final context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 0,
          isNegativeEmotion: true,
          pendingResultCount: 1,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.defer);
        expect(judgment.reason, '用户情绪负面');
        expect(judgment.shouldNotify, isFalse);
      });

      test('should return defer when in chat and not critical priority', () {
        final context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 0,
          isInChat: true,
          pendingResultCount: 1,
          highestPriority: ResultPriority.normal,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.defer);
        expect(judgment.reason, '闲聊中');
        expect(judgment.shouldNotify, isFalse);
      });

      test('should return onIdle when in chat but critical priority', () {
        final context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 0,
          isInChat: true,
          pendingResultCount: 1,
          highestPriority: ResultPriority.critical,
        );

        final judgment = judge.judge(context);

        // Critical priority forces notification even in chat
        expect(judgment.shouldNotify, isTrue);
      });

      test('should return onIdle when user is silent for 5+ seconds', () {
        final context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 5000,
          pendingResultCount: 1,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.onIdle);
        expect(judgment.reason, '用户沉默');
        expect(judgment.shouldNotify, isTrue);
        expect(judgment.notificationPrefix, isNotNull);
      });

      test('should return natural when last round was operation', () {
        final context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 0,
          lastRoundWasOperation: true,
          pendingResultCount: 1,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.natural);
        expect(judgment.reason, '业务相关上下文');
        expect(judgment.shouldNotify, isTrue);
      });

      test('should return onIdle when critical priority', () {
        final context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 0,
          pendingResultCount: 1,
          highestPriority: ResultPriority.critical,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.onIdle);
        expect(judgment.reason, '关键优先级');
        expect(judgment.shouldNotify, isTrue);
      });

      test('should return defer by default', () {
        final context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 0,
          pendingResultCount: 1,
        );

        final judgment = judge.judge(context);

        expect(judgment.timing, NotificationTiming.defer);
        expect(judgment.reason, '默认延迟');
        expect(judgment.shouldNotify, isFalse);
      });

      test('should prioritize user speaking over other conditions', () {
        final context = TimingContext(
          userInput: '记好了吗',
          isUserSpeaking: true,
          silenceDurationMs: 6000,
          lastRoundWasOperation: true,
          pendingResultCount: 1,
          highestPriority: ResultPriority.critical,
        );

        final judgment = judge.judge(context);

        // User speaking takes priority
        expect(judgment.timing, NotificationTiming.defer);
        expect(judgment.reason, '用户正在说话');
      });

      test('should prioritize asking result over other conditions', () {
        final context = TimingContext(
          userInput: '记好了吗',
          isUserSpeaking: false,
          silenceDurationMs: 6000,
          isNegativeEmotion: true,
          pendingResultCount: 1,
        );

        final judgment = judge.judge(context);

        // Asking result takes priority over negative emotion
        expect(judgment.timing, NotificationTiming.immediate);
      });
    });

    group('generateNotification()', () {
      late ResultBuffer buffer;

      setUp(() {
        buffer = ResultBuffer();
      });

      tearDown(() {
        buffer.dispose();
      });

      test('should return empty string for empty results', () {
        final notification = judge.generateNotification([]);

        expect(notification, '');
      });

      test('should generate notification for single result', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '午餐',
          amount: 30.0,
        );

        final notification = judge.generateNotification([result]);

        expect(notification, contains('午餐'));
        expect(notification, contains('30.0元'));
        expect(notification, contains('已经记好了'));
      });

      test('should generate notification for single result without amount', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '删除记录',
        );

        final notification = judge.generateNotification([result]);

        expect(notification, contains('删除记录'));
        expect(notification, contains('已经记好了'));
        expect(notification, isNot(contains('元')));
      });

      test('should generate notification for multiple results', () {
        final result1 = buffer.add(
          result: ExecutionResult.success(),
          description: '午餐',
          amount: 30.0,
        );
        final result2 = buffer.add(
          result: ExecutionResult.success(),
          description: '晚餐',
          amount: 50.0,
        );

        final notification = judge.generateNotification([result1, result2]);

        expect(notification, contains('2笔记录'));
        expect(notification, contains('都已完成'));
        expect(notification, contains('午餐'));
        expect(notification, contains('晚餐'));
      });

      test('should add prefix for onIdle timing', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '午餐',
          amount: 30.0,
        );

        final notification = judge.generateNotification(
          [result],
          timing: NotificationTiming.onIdle,
        );

        expect(notification, startsWith('对了，'));
      });

      test('should not add prefix for immediate timing', () {
        final result = buffer.add(
          result: ExecutionResult.success(),
          description: '午餐',
          amount: 30.0,
        );

        final notification = judge.generateNotification(
          [result],
          timing: NotificationTiming.immediate,
        );

        expect(notification, isNot(startsWith('对了')));
        expect(notification, isNot(startsWith('另外')));
      });
    });

    group('TimingJudgment', () {
      test('shouldNotify returns true for immediate', () {
        const judgment = TimingJudgment(
          timing: NotificationTiming.immediate,
          reason: 'test',
        );

        expect(judgment.shouldNotify, isTrue);
      });

      test('shouldNotify returns true for natural', () {
        const judgment = TimingJudgment(
          timing: NotificationTiming.natural,
          reason: 'test',
        );

        expect(judgment.shouldNotify, isTrue);
      });

      test('shouldNotify returns true for onIdle', () {
        const judgment = TimingJudgment(
          timing: NotificationTiming.onIdle,
          reason: 'test',
        );

        expect(judgment.shouldNotify, isTrue);
      });

      test('shouldNotify returns true for onTopicShift', () {
        const judgment = TimingJudgment(
          timing: NotificationTiming.onTopicShift,
          reason: 'test',
        );

        expect(judgment.shouldNotify, isTrue);
      });

      test('shouldNotify returns false for defer', () {
        const judgment = TimingJudgment(
          timing: NotificationTiming.defer,
          reason: 'test',
        );

        expect(judgment.shouldNotify, isFalse);
      });

      test('shouldNotify returns false for suppress', () {
        const judgment = TimingJudgment(
          timing: NotificationTiming.suppress,
          reason: 'test',
        );

        expect(judgment.shouldNotify, isFalse);
      });

      test('toString contains timing and reason', () {
        const judgment = TimingJudgment(
          timing: NotificationTiming.immediate,
          reason: 'test reason',
        );

        final str = judgment.toString();

        expect(str, contains('immediate'));
        expect(str, contains('test reason'));
      });
    });

    group('TimingContext', () {
      test('toString contains all properties', () {
        const context = TimingContext(
          isUserSpeaking: true,
          silenceDurationMs: 1000,
          isNegativeEmotion: true,
          isInChat: true,
          lastRoundWasOperation: true,
          pendingResultCount: 3,
        );

        final str = context.toString();

        expect(str, contains('speaking=true'));
        expect(str, contains('silence=1000ms'));
        expect(str, contains('emotion=negative'));
        expect(str, contains('chat=true'));
        expect(str, contains('lastOp=true'));
        expect(str, contains('pending=3'));
      });

      test('default values are correct', () {
        const context = TimingContext(
          isUserSpeaking: false,
          silenceDurationMs: 0,
          pendingResultCount: 0,
        );

        expect(context.userInput, isNull);
        expect(context.isNegativeEmotion, isFalse);
        expect(context.isInChat, isFalse);
        expect(context.lastRoundWasOperation, isFalse);
        expect(context.highestPriority, isNull);
      });
    });

    group('silenceThresholdMs constant', () {
      test('should be 5000ms', () {
        expect(TimingJudge.silenceThresholdMs, 5000);
      });
    });
  });
}
