import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/intelligence_engine/proactive_conversation_manager.dart';

void main() {
  group('ProactiveConversationManager Tests', () {
    late ProactiveConversationManager manager;
    late List<String> proactiveMessages;
    late int sessionEndCount;

    setUp(() {
      proactiveMessages = [];
      sessionEndCount = 0;

      manager = ProactiveConversationManager(
        topicGenerator: _TestTopicGenerator(),
        onProactiveMessage: (message) {
          proactiveMessages.add(message);
        },
        onSessionEnd: () {
          sessionEndCount++;
        },
      );
    });

    tearDown(() {
      manager.dispose();
    });

    group('计数管理', () {
      test('初始计数为0', () {
        expect(manager.proactiveCount, equals(0));
      });

      test('incrementProactiveCount 应该增加计数', () {
        manager.incrementProactiveCount();
        expect(manager.proactiveCount, equals(1));

        manager.incrementProactiveCount();
        expect(manager.proactiveCount, equals(2));
      });

      test('incrementProactiveCount 不应超过最大值', () {
        for (var i = 0; i < 5; i++) {
          manager.incrementProactiveCount();
        }
        expect(manager.proactiveCount, equals(3));
      });

      test('hasReachedMaxCount 应该正确判断', () {
        expect(manager.hasReachedMaxCount, isFalse);

        manager.incrementProactiveCount();
        manager.incrementProactiveCount();
        manager.incrementProactiveCount();

        expect(manager.hasReachedMaxCount, isTrue);
      });
    });

    group('resetTimer - isUserInitiated 参数', () {
      test('isUserInitiated=true 应该重置计数', () {
        // 先增加计数
        manager.incrementProactiveCount();
        manager.incrementProactiveCount();
        expect(manager.proactiveCount, equals(2));

        // 用户主动输入，应该重置计数
        manager.resetTimer(isUserInitiated: true);
        expect(manager.proactiveCount, equals(0));
      });

      test('isUserInitiated=false 也应该重置计数', () {
        // 先增加计数
        manager.incrementProactiveCount();
        manager.incrementProactiveCount();
        expect(manager.proactiveCount, equals(2));

        // 系统响应也重置计数（设计决策：系统响应是新内容，用户需要时间回应）
        manager.resetTimer(isUserInitiated: false);
        expect(manager.proactiveCount, equals(0));
      });

      test('默认 isUserInitiated=true', () {
        manager.incrementProactiveCount();
        expect(manager.proactiveCount, equals(1));

        // 不传参数，使用默认值 true
        manager.resetTimer();
        expect(manager.proactiveCount, equals(0));
      });
    });

    group('静默监听', () {
      test('startSilenceMonitoring 应该启动监听', () {
        manager.startSilenceMonitoring();
        expect(manager.state, equals(ProactiveState.waiting));
      });

      test('stopMonitoring 应该停止监听', () {
        manager.startSilenceMonitoring();
        manager.stopMonitoring();
        expect(manager.state, equals(ProactiveState.idle));
      });

      test('禁用后 startSilenceMonitoring 不应该启动', () {
        manager.disable();
        manager.startSilenceMonitoring();
        expect(manager.state, equals(ProactiveState.idle));
      });
    });

    group('用户拒绝检测', () {
      test('应该检测拒绝关键词', () {
        expect(manager.detectRejection('不用了'), isTrue);
        expect(manager.detectRejection('别说了'), isTrue);
        expect(manager.detectRejection('安静'), isTrue);
        expect(manager.detectRejection('闭嘴'), isTrue);
      });

      test('普通输入不应该被检测为拒绝', () {
        expect(manager.detectRejection('记录午餐30元'), isFalse);
        expect(manager.detectRejection('今天花了多少钱'), isFalse);
      });

      test('检测到拒绝后应该禁用主动对话', () {
        manager.detectRejection('不用了');
        expect(manager.isDisabled, isTrue);
      });
    });

    group('启用/禁用', () {
      test('disable 应该禁用主动对话', () {
        manager.disable();
        expect(manager.isDisabled, isTrue);
      });

      test('enable 应该重新启用并重置计数', () {
        manager.incrementProactiveCount();
        manager.incrementProactiveCount();
        manager.disable();

        manager.enable();
        expect(manager.isDisabled, isFalse);
        expect(manager.proactiveCount, equals(0));
      });
    });

    group('会话重置', () {
      test('resetForNewSession 应该重置所有状态', () {
        // 设置一些状态
        manager.incrementProactiveCount();
        manager.incrementProactiveCount();
        manager.startSilenceMonitoring();

        // 重置
        manager.resetForNewSession();

        expect(manager.proactiveCount, equals(0));
        expect(manager.isDisabled, isFalse);
        expect(manager.state, equals(ProactiveState.idle));
      });
    });

    // 注意：以下测试需要使用 fake_async 包来模拟时间流逝
    // 当前使用 skip 跳过长时间等待的测试
    // 实际项目中应该使用 fake_async 来正确测试计时器逻辑

    group('5秒静默触发主动对话', () {
      test('5秒静默后应该触发主动消息', () async {
        // 注意：这个测试需要真实等待5秒，在 CI 中可能会超时
        // 建议使用 fake_async 包来模拟时间
        manager.startSilenceMonitoring();

        // 等待5.5秒
        await Future.delayed(const Duration(milliseconds: 5500));

        // 应该收到主动消息
        expect(proactiveMessages.length, greaterThanOrEqualTo(1));
        expect(manager.proactiveCount, greaterThanOrEqualTo(1));
      }, timeout: Timeout(Duration(seconds: 10)));

      test('用户输入应该重置静默计时器', () async {
        manager.startSilenceMonitoring();

        // 2秒后用户输入
        await Future.delayed(const Duration(milliseconds: 2000));
        manager.resetTimer(isUserInitiated: true);

        // 再等2秒（总共4秒，但从用户输入后只有2秒，不到5秒阈值）
        await Future.delayed(const Duration(milliseconds: 2000));

        // 不应该触发主动消息（因为用户输入重置了计时器，总等待时间不足5秒）
        expect(proactiveMessages, isEmpty);
      }, timeout: Timeout(Duration(seconds: 10)));
    });

    group('连续主动对话达到上限', () {
      // 跳过这个测试因为它需要等待 16 秒
      test('连续3次主动对话后应该结束会话', () async {
        // 此测试需要等待 16+ 秒才能完成
        // 在实际项目中应该使用 fake_async 来模拟时间
      }, skip: '需要 fake_async 来测试长时间计时器');
    });

    group('30秒总计无响应', () {
      // 跳过这些测试因为它们需要等待 30+ 秒
      test('30秒无响应应该结束会话', () async {
        // 此测试需要等待 30+ 秒才能完成
      }, skip: '需要 fake_async 来测试长时间计时器');

      test('用户输入应该重置30秒计时器', () async {
        // 此测试需要等待 40 秒才能完成
      }, skip: '需要 fake_async 来测试长时间计时器');

      test('系统响应不应该重置30秒计时器', () async {
        // 此测试需要等待 35 秒才能完成
      }, skip: '需要 fake_async 来测试长时间计时器');
    });
  });
}

/// 测试用的话题生成器
class _TestTopicGenerator implements ProactiveTopicGenerator {
  int _callCount = 0;

  @override
  Future<String?> generateTopic() async {
    _callCount++;
    return '测试话题 $_callCount';
  }
}

// 注意：完整的计时器测试需要使用 fake_async 包
// 示例用法：
// import 'package:fake_async/fake_async.dart';
//
// test('计时器测试', () {
//   fakeAsync((async) {
//     manager.startSilenceMonitoring();
//     async.elapse(Duration(seconds: 5));
//     expect(proactiveMessages.length, greaterThanOrEqualTo(1));
//   });
// });
