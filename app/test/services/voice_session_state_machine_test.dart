import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/voice_session_state.dart';
import 'package:ai_bookkeeping/services/voice/voice_session_state_machine.dart';

void main() {
  group('VoiceSessionState', () {
    test('shouldRunASR 只在 listening 状态为 true', () {
      expect(VoiceSessionState.idle.shouldRunASR, false);
      expect(VoiceSessionState.listening.shouldRunASR, true);
      expect(VoiceSessionState.thinking.shouldRunASR, false);
      expect(VoiceSessionState.speaking.shouldRunASR, false);
    });

    test('shouldRunVAD 在非 idle 状态为 true', () {
      expect(VoiceSessionState.idle.shouldRunVAD, false);
      expect(VoiceSessionState.listening.shouldRunVAD, true);
      expect(VoiceSessionState.thinking.shouldRunVAD, true);
      expect(VoiceSessionState.speaking.shouldRunVAD, true);
    });

    test('isInterruptible 只在 speaking 状态为 true', () {
      expect(VoiceSessionState.idle.isInterruptible, false);
      expect(VoiceSessionState.listening.isInterruptible, false);
      expect(VoiceSessionState.thinking.isInterruptible, false);
      expect(VoiceSessionState.speaking.isInterruptible, true);
    });

    test('isProcessing 在 thinking 和 speaking 状态为 true', () {
      expect(VoiceSessionState.idle.isProcessing, false);
      expect(VoiceSessionState.listening.isProcessing, false);
      expect(VoiceSessionState.thinking.isProcessing, true);
      expect(VoiceSessionState.speaking.isProcessing, true);
    });
  });

  group('VoiceSessionStateMachine', () {
    late VoiceSessionStateMachine machine;

    setUp(() {
      machine = VoiceSessionStateMachine();
    });

    tearDown(() {
      machine.dispose();
    });

    test('初始状态为 idle', () {
      expect(machine.state, VoiceSessionState.idle);
      expect(machine.isIdle, true);
    });

    group('从 idle 状态转换', () {
      test('idle -> listening 允许', () {
        expect(machine.canTransition(VoiceSessionState.listening), true);
        expect(
          machine.transition(VoiceSessionState.listening, reason: '用户启动'),
          true,
        );
        expect(machine.state, VoiceSessionState.listening);
      });

      test('idle -> thinking 不允许', () {
        expect(machine.canTransition(VoiceSessionState.thinking), false);
        expect(machine.transition(VoiceSessionState.thinking), false);
        expect(machine.state, VoiceSessionState.idle);
      });

      test('idle -> speaking 不允许', () {
        expect(machine.canTransition(VoiceSessionState.speaking), false);
        expect(machine.transition(VoiceSessionState.speaking), false);
        expect(machine.state, VoiceSessionState.idle);
      });
    });

    group('从 listening 状态转换', () {
      setUp(() {
        machine.transition(VoiceSessionState.listening);
      });

      test('listening -> thinking 允许 (ASR 最终结果)', () {
        expect(machine.canTransition(VoiceSessionState.thinking), true);
        expect(
          machine.transition(VoiceSessionState.thinking, reason: 'ASR 结果'),
          true,
        );
        expect(machine.state, VoiceSessionState.thinking);
      });

      test('listening -> speaking 允许 (主动对话)', () {
        expect(machine.canTransition(VoiceSessionState.speaking), true);
        expect(
          machine.transition(VoiceSessionState.speaking, reason: '主动对话'),
          true,
        );
        expect(machine.state, VoiceSessionState.speaking);
      });

      test('listening -> idle 允许 (用户停止)', () {
        expect(machine.canTransition(VoiceSessionState.idle), true);
        expect(
          machine.transition(VoiceSessionState.idle, reason: '用户停止'),
          true,
        );
        expect(machine.state, VoiceSessionState.idle);
      });
    });

    group('从 thinking 状态转换', () {
      setUp(() {
        machine.transition(VoiceSessionState.listening);
        machine.transition(VoiceSessionState.thinking);
      });

      test('thinking -> speaking 允许 (LLM 响应)', () {
        expect(machine.canTransition(VoiceSessionState.speaking), true);
        expect(
          machine.transition(VoiceSessionState.speaking, reason: 'LLM 响应'),
          true,
        );
        expect(machine.state, VoiceSessionState.speaking);
      });

      test('thinking -> listening 允许 (处理失败)', () {
        expect(machine.canTransition(VoiceSessionState.listening), true);
        expect(
          machine.transition(VoiceSessionState.listening, reason: '处理失败'),
          true,
        );
        expect(machine.state, VoiceSessionState.listening);
      });

      test('thinking -> idle 允许 (用户停止)', () {
        expect(machine.canTransition(VoiceSessionState.idle), true);
        expect(machine.transition(VoiceSessionState.idle), true);
        expect(machine.state, VoiceSessionState.idle);
      });
    });

    group('从 speaking 状态转换', () {
      setUp(() {
        machine.transition(VoiceSessionState.listening);
        machine.transition(VoiceSessionState.thinking);
        machine.transition(VoiceSessionState.speaking);
      });

      test('speaking -> listening 允许 (TTS 完成)', () {
        expect(machine.canTransition(VoiceSessionState.listening), true);
        expect(
          machine.transition(VoiceSessionState.listening, reason: 'TTS 完成'),
          true,
        );
        expect(machine.state, VoiceSessionState.listening);
      });

      test('speaking -> listening 允许 (用户打断)', () {
        expect(
          machine.transition(VoiceSessionState.listening, reason: '用户打断'),
          true,
        );
        expect(machine.state, VoiceSessionState.listening);
      });

      test('speaking -> idle 允许 (用户停止)', () {
        expect(machine.canTransition(VoiceSessionState.idle), true);
        expect(machine.transition(VoiceSessionState.idle), true);
        expect(machine.state, VoiceSessionState.idle);
      });

      test('speaking -> thinking 不允许', () {
        expect(machine.canTransition(VoiceSessionState.thinking), false);
        expect(machine.transition(VoiceSessionState.thinking), false);
        expect(machine.state, VoiceSessionState.speaking);
      });
    });

    group('状态流', () {
      test('状态变化发送事件', () async {
        final events = <VoiceSessionStateChange>[];
        machine.stateStream.listen(events.add);

        machine.transition(VoiceSessionState.listening, reason: '启动');
        machine.transition(VoiceSessionState.thinking, reason: 'ASR');
        machine.transition(VoiceSessionState.speaking, reason: 'TTS');
        machine.transition(VoiceSessionState.listening, reason: '完成');

        // 等待事件处理
        await Future.delayed(Duration.zero);

        expect(events.length, 4);
        expect(events[0].oldState, VoiceSessionState.idle);
        expect(events[0].newState, VoiceSessionState.listening);
        expect(events[0].reason, '启动');

        expect(events[3].oldState, VoiceSessionState.speaking);
        expect(events[3].newState, VoiceSessionState.listening);
      });

      test('非法转换不发送事件', () async {
        final events = <VoiceSessionStateChange>[];
        machine.stateStream.listen(events.add);

        // 尝试非法转换
        machine.transition(VoiceSessionState.speaking);

        await Future.delayed(Duration.zero);

        expect(events.length, 0);
      });
    });

    group('辅助属性', () {
      test('shouldRunASR 跟随状态', () {
        expect(machine.shouldRunASR, false);

        machine.transition(VoiceSessionState.listening);
        expect(machine.shouldRunASR, true);

        machine.transition(VoiceSessionState.thinking);
        expect(machine.shouldRunASR, false);
      });

      test('isInterruptible 只在 speaking 状态', () {
        expect(machine.isInterruptible, false);

        machine.transition(VoiceSessionState.listening);
        expect(machine.isInterruptible, false);

        machine.transition(VoiceSessionState.thinking);
        expect(machine.isInterruptible, false);

        machine.transition(VoiceSessionState.speaking);
        expect(machine.isInterruptible, true);
      });
    });

    group('重置', () {
      test('reset 回到 idle 状态', () {
        machine.transition(VoiceSessionState.listening);
        machine.transition(VoiceSessionState.thinking);

        machine.reset();

        expect(machine.state, VoiceSessionState.idle);
      });

      test('forceState 跳过验证', () {
        // 正常情况下 idle -> speaking 不允许
        expect(machine.canTransition(VoiceSessionState.speaking), false);

        // 但 forceState 可以强制设置
        machine.forceState(VoiceSessionState.speaking, reason: '强制');

        expect(machine.state, VoiceSessionState.speaking);
      });
    });

    group('完整对话流程', () {
      test('正常流程: idle -> listening -> thinking -> speaking -> listening', () {
        // 用户启动
        expect(machine.transition(VoiceSessionState.listening), true);
        expect(machine.isListening, true);

        // ASR 返回结果
        expect(machine.transition(VoiceSessionState.thinking), true);
        expect(machine.isThinking, true);

        // LLM 响应就绪
        expect(machine.transition(VoiceSessionState.speaking), true);
        expect(machine.isSpeaking, true);

        // TTS 完成，继续监听
        expect(machine.transition(VoiceSessionState.listening), true);
        expect(machine.isListening, true);
      });

      test('打断流程: speaking -> listening (用户打断)', () {
        machine.transition(VoiceSessionState.listening);
        machine.transition(VoiceSessionState.thinking);
        machine.transition(VoiceSessionState.speaking);

        // 用户打断
        expect(machine.transition(VoiceSessionState.listening, reason: '用户打断'), true);
        expect(machine.isListening, true);
      });

      test('主动对话流程: listening -> speaking (静默超时)', () {
        machine.transition(VoiceSessionState.listening);

        // 静默超时，直接进入 speaking（主动对话）
        expect(machine.transition(VoiceSessionState.speaking, reason: '主动对话'), true);
        expect(machine.isSpeaking, true);
      });
    });
  });
}
