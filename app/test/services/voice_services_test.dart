import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:ai_bookkeeping/services/voice/voice_intent_router.dart';
import 'package:ai_bookkeeping/services/voice_feedback_system.dart';
import 'package:ai_bookkeeping/services/tts_service.dart';

// Generate mocks
@GenerateNiceMocks([MockSpec<TtsService>()])
import 'voice_services_test.mocks.dart';

void main() {
  group('VoiceIntentRouter Tests', () {
    late VoiceIntentRouter router;

    setUp(() {
      router = VoiceIntentRouter();
    });

    group('删除意图识别', () {
      test('应该识别明确的删除命令', () async {
        final result = await router.analyzeIntent('删除昨天的午餐');

        expect(result.intent, equals(VoiceIntentType.deleteTransaction));
        expect(result.confidence, greaterThan(0.7));
        expect(result.isHighConfidence, isTrue);
      });

      test('应该识别其他删除表达方式', () async {
        final testCases = [
          '删掉刚才那笔',
          '去掉早餐的记录',
          '取消上一笔交易',
          '移除咖啡消费',
        ];

        for (final testCase in testCases) {
          final result = await router.analyzeIntent(testCase);
          expect(result.intent, equals(VoiceIntentType.deleteTransaction),
              reason: 'Failed for: $testCase');
          expect(result.confidence, greaterThan(0.5),
              reason: 'Low confidence for: $testCase');
        }
      });

      test('应该提取删除相关的实体信息', () async {
        final result = await router.analyzeIntent('删除昨天的午餐35元');

        expect(result.entities, isNotEmpty);
        // 根据实际实现验证实体提取结果
      });
    });

    group('修改意图识别', () {
      test('应该识别修改命令', () async {
        final result = await router.analyzeIntent('把午餐改成40元');

        expect(result.intent, equals(VoiceIntentType.modifyTransaction));
        expect(result.confidence, greaterThan(0.7));
      });

      test('应该识别各种修改表达方式', () async {
        final testCases = [
          '修改咖啡的金额为25元',
          '更改分类为交通',
          '把时间调整为昨天',
          '换成购物类别',
        ];

        for (final testCase in testCases) {
          final result = await router.analyzeIntent(testCase);
          expect(result.intent, equals(VoiceIntentType.modifyTransaction),
              reason: 'Failed for: $testCase');
        }
      });
    });

    group('添加意图识别', () {
      test('应该识别添加交易命令', () async {
        final testCases = [
          '记录午餐35元',
          '添加一笔打车费30元',
          '花了45块买咖啡',
          '收入8000元',
        ];

        for (final testCase in testCases) {
          final result = await router.analyzeIntent(testCase);
          expect(result.intent, equals(VoiceIntentType.addTransaction),
              reason: 'Failed for: $testCase');
        }
      });

      test('应该提取金额和分类信息', () async {
        final result = await router.analyzeIntent('在星巴克买咖啡花了35元');

        expect(result.intent, equals(VoiceIntentType.addTransaction));
        expect(result.entities, isNotEmpty);
        // 验证实体提取是否包含金额、分类、商家信息
      });
    });

    group('查询意图识别', () {
      test('应该识别查询命令', () async {
        final testCases = [
          '查看本月支出',
          '今天花了多少钱',
          '显示餐饮统计',
          '本月预算还剩多少',
        ];

        for (final testCase in testCases) {
          final result = await router.analyzeIntent(testCase);
          expect(result.intent, equals(VoiceIntentType.queryTransaction),
              reason: 'Failed for: $testCase');
        }
      });
    });

    group('导航意图识别', () {
      test('应该识别导航命令', () async {
        final testCases = [
          '打开设置页面',
          '进入预算中心',
          '切换到首页',
          '返回主页面',
        ];

        for (final testCase in testCases) {
          final result = await router.analyzeIntent(testCase);
          expect(result.intent, equals(VoiceIntentType.navigateToPage),
              reason: 'Failed for: $testCase');
        }
      });
    });

    group('确认和取消意图识别', () {
      test('应该识别确认命令', () async {
        final testCases = [
          '确认',
          '确定',
          '是的',
          '好的',
          '对',
          'OK',
        ];

        for (final testCase in testCases) {
          final result = await router.analyzeIntent(testCase);
          expect(result.intent, equals(VoiceIntentType.confirmAction),
              reason: 'Failed for: $testCase');
        }
      });

      test('应该识别取消命令', () async {
        final testCases = [
          '取消',
          '不要',
          '算了',
          '停止',
          '不对',
        ];

        for (final testCase in testCases) {
          final result = await router.analyzeIntent(testCase);
          expect(result.intent, equals(VoiceIntentType.cancelAction),
              reason: 'Failed for: $testCase');
        }
      });
    });

    group('澄清选择意图识别', () {
      test('应该识别数字选择', () async {
        final testCases = [
          '第一个',
          '第2项',
          '选择3',
          '要第四个',
          '5',
        ];

        for (final testCase in testCases) {
          final result = await router.analyzeIntent(testCase);
          expect(result.intent, equals(VoiceIntentType.clarifySelection),
              reason: 'Failed for: $testCase');
        }
      });

      test('应该提取选择索引', () async {
        final result = await router.analyzeIntent('第三个');

        expect(result.intent, equals(VoiceIntentType.clarifySelection));
        expect(result.entities['selectionIndex'], equals(3));
      });
    });

    group('上下文增强', () {
      test('在删除上下文中应该增强确认意图', () async {
        final context = VoiceSessionContext(
          intentType: VoiceIntentType.deleteTransaction,
          data: {},
          createdAt: DateTime.now(),
        );

        final result = await router.analyzeIntent('确定', context: context);

        expect(result.intent, equals(VoiceIntentType.confirmAction));
        expect(result.contextBoosted, isTrue);
        expect(result.confidence, greaterThan(0.8));
      });

      test('在修改上下文中应该增强澄清意图', () async {
        final context = VoiceSessionContext(
          intentType: VoiceIntentType.modifyTransaction,
          data: {},
          createdAt: DateTime.now(),
        );

        final result = await router.analyzeIntent('第一个', context: context);

        expect(result.intent, equals(VoiceIntentType.clarifySelection));
        expect(result.contextBoosted, isTrue);
      });
    });

    group('低置信度处理', () {
      test('应该识别模糊输入', () async {
        final result = await router.analyzeIntent('这个那个的');

        expect(result.intent, equals(VoiceIntentType.unknown));
        expect(result.confidence, lessThan(0.7));
        expect(result.isLowConfidence, isTrue);
      });

      test('应该提供候选意图', () async {
        final result = await router.analyzeIntent('改一下金额');

        expect(result.candidateIntents, isNotEmpty);
        expect(result.candidateIntents.first.intent,
               equals(VoiceIntentType.modifyTransaction));
      });
    });

    group('特殊规则', () {
      test('包含金额的输入应该倾向于添加意图', () async {
        final result = await router.analyzeIntent('花了25块钱');

        expect(result.intent, equals(VoiceIntentType.addTransaction));
        expect(result.confidence, greaterThan(0.7));
      });

      test('时间相关的查询应该倾向于查询意图', () async {
        final result = await router.analyzeIntent('今天多少钱');

        expect(result.intent, equals(VoiceIntentType.queryTransaction));
        expect(result.confidence, greaterThan(0.7));
      });

      test('单独数字应该倾向于澄清选择', () async {
        final result = await router.analyzeIntent('3');

        expect(result.intent, equals(VoiceIntentType.clarifySelection));
        expect(result.confidence, greaterThan(0.8));
      });
    });
  });

  group('VoiceFeedbackSystem Tests', () {
    late VoiceFeedbackSystem feedbackSystem;
    late MockTtsService mockTtsService;

    setUp(() {
      mockTtsService = MockTtsService();
      feedbackSystem = VoiceFeedbackSystem(ttsService: mockTtsService);
    });

    group('基础反馈功能', () {
      test('应该提供基本反馈', () async {
        await feedbackSystem.provideFeedback(
          message: '操作成功',
          type: VoiceFeedbackType.success,
        );

        expect(feedbackSystem.state.currentFeedback, isNotNull);
        expect(feedbackSystem.state.currentFeedback!.message, equals('操作成功'));
        expect(feedbackSystem.state.currentFeedback!.type, equals(VoiceFeedbackType.success));

        verify(mockTtsService.speak(any)).called(1);
      });

      test('应该记录反馈历史', () async {
        await feedbackSystem.provideFeedback(
          message: '测试消息',
          type: VoiceFeedbackType.info,
        );

        expect(feedbackSystem.feedbackHistory, hasLength(1));
        expect(feedbackSystem.feedbackHistory.first.message, equals('测试消息'));
      });

      test('应该限制历史记录数量', () async {
        // 添加超过最大数量的反馈
        for (int i = 0; i < 105; i++) {
          await feedbackSystem.provideFeedback(
            message: '测试消息 $i',
            type: VoiceFeedbackType.info,
            enableTts: false, // 禁用TTS以加快测试
          );
        }

        expect(feedbackSystem.feedbackHistory, hasLength(100));
        // 验证是否保留了最新的记录
        expect(feedbackSystem.feedbackHistory.last.message, equals('测试消息 104'));
      });
    });

    group('上下文感知反馈', () {
      test('应该为删除意图生成合适的反馈', () async {
        final intentResult = IntentAnalysisResult(
          intent: VoiceIntentType.deleteTransaction,
          confidence: 0.8,
          rawInput: '删除昨天的午餐',
          entities: {'timeRange': '昨天'},
        );

        await feedbackSystem.provideContextualFeedback(
          intentResult: intentResult,
        );

        expect(feedbackSystem.state.currentFeedback, isNotNull);
        expect(feedbackSystem.state.currentFeedback!.message,
               contains('昨天'));
        expect(feedbackSystem.state.currentFeedback!.type,
               equals(VoiceFeedbackType.confirmation));
      });

      test('应该为低置信度结果提供帮助信息', () async {
        final intentResult = IntentAnalysisResult(
          intent: VoiceIntentType.unknown,
          confidence: 0.3,
          rawInput: '这个那个',
          candidateIntents: [
            IntentCandidate(
              intent: VoiceIntentType.deleteTransaction,
              confidence: 0.4,
            ),
            IntentCandidate(
              intent: VoiceIntentType.modifyTransaction,
              confidence: 0.3,
            ),
          ],
        );

        await feedbackSystem.provideContextualFeedback(
          intentResult: intentResult,
        );

        expect(feedbackSystem.state.currentFeedback!.message,
               contains('不太确定'));
        expect(feedbackSystem.state.currentFeedback!.type,
               equals(VoiceFeedbackType.warning));
      });
    });

    group('操作结果反馈', () {
      test('应该为成功操作提供正面反馈', () async {
        final result = OperationResult.success('delete', {'deletedCount': 2});

        await feedbackSystem.provideOperationFeedback(result: result);

        expect(feedbackSystem.state.currentFeedback!.type,
               equals(VoiceFeedbackType.success));
        expect(feedbackSystem.state.currentFeedback!.message,
               contains('成功'));
      });

      test('应该为失败操作提供错误反馈和建议', () async {
        final result = OperationResult.failure('delete', '网络连接失败');

        await feedbackSystem.provideOperationFeedback(result: result);

        expect(feedbackSystem.state.currentFeedback!.type,
               equals(VoiceFeedbackType.error));
        expect(feedbackSystem.state.currentFeedback!.message,
               contains('失败'));
        expect(feedbackSystem.state.currentFeedback!.message,
               contains('网络'));
      });
    });

    group('进度反馈', () {
      test('应该提供进度更新', () async {
        await feedbackSystem.provideProgressFeedback(
          operation: '数据同步',
          progress: 0.5,
        );

        expect(feedbackSystem.state.currentFeedback!.type,
               equals(VoiceFeedbackType.progress));
        expect(feedbackSystem.state.currentFeedback!.message,
               contains('数据同步'));
      });

      test('不同进度阶段应该有不同的消息', () async {
        // 开始阶段
        await feedbackSystem.provideProgressFeedback(
          operation: '上传文件',
          progress: 0.0,
          enableTts: false,
        );
        expect(feedbackSystem.state.currentFeedback!.message,
               contains('开始'));

        // 进行中
        await feedbackSystem.provideProgressFeedback(
          operation: '上传文件',
          progress: 0.5,
          enableTts: false,
        );
        expect(feedbackSystem.state.currentFeedback!.message,
               contains('进行中'));

        // 完成
        await feedbackSystem.provideProgressFeedback(
          operation: '上传文件',
          progress: 1.0,
          enableTts: false,
        );
        expect(feedbackSystem.state.currentFeedback!.message,
               contains('完成'));
      });
    });

    group('反馈配置', () {
      test('应该允许更新配置', () {
        final newConfig = VoiceFeedbackConfig(
          enableTts: false,
          enableHaptic: true,
          enableVisualFeedback: true,
          volume: 0.5,
          speechRate: 1.2,
          pitch: 0.9,
          language: 'zh-CN',
          voice: 'female',
        );

        feedbackSystem.updateConfig(newConfig);

        expect(feedbackSystem.config.enableTts, isFalse);
        expect(feedbackSystem.config.volume, equals(0.5));
        expect(feedbackSystem.config.speechRate, equals(1.2));

        verify(mockTtsService.setVolume(0.5)).called(1);
        verify(mockTtsService.setSpeechRate(1.2)).called(1);
        verify(mockTtsService.setPitch(0.9)).called(1);
      });
    });

    group('错误处理', () {
      test('应该优雅处理TTS错误', () async {
        when(mockTtsService.speak(any)).thenThrow(Exception('TTS Error'));

        // 不应该抛出异常
        await feedbackSystem.provideFeedback(
          message: '测试消息',
          type: VoiceFeedbackType.info,
        );

        expect(feedbackSystem.state.currentFeedback, isNotNull);
      });
    });

    group('反馈控制', () {
      test('应该能停止当前反馈', () async {
        await feedbackSystem.provideFeedback(
          message: '长消息',
          type: VoiceFeedbackType.info,
        );

        await feedbackSystem.stopCurrentFeedback();

        expect(feedbackSystem.state.isPlaying, isFalse);
        expect(feedbackSystem.state.currentFeedback, isNull);
        verify(mockTtsService.stop()).called(1);
      });

      test('应该能清除反馈历史', () async {
        await feedbackSystem.provideFeedback(
          message: '测试消息',
          type: VoiceFeedbackType.info,
          enableTts: false,
        );

        expect(feedbackSystem.feedbackHistory, hasLength(1));

        feedbackSystem.clearHistory();

        expect(feedbackSystem.feedbackHistory, isEmpty);
      });
    });
  });

  group('集成测试', () {
    test('语音意图路由器和反馈系统应该协同工作', () async {
      final router = VoiceIntentRouter();
      final mockTtsService = MockTtsService();
      final feedbackSystem = VoiceFeedbackSystem(ttsService: mockTtsService);

      // 分析意图
      final intentResult = await router.analyzeIntent('删除昨天的午餐');
      expect(intentResult.intent, equals(VoiceIntentType.deleteTransaction));

      // 提供上下文反馈
      await feedbackSystem.provideContextualFeedback(
        intentResult: intentResult,
      );

      expect(feedbackSystem.state.currentFeedback, isNotNull);
      expect(feedbackSystem.state.currentFeedback!.type,
             equals(VoiceFeedbackType.confirmation));
      verify(mockTtsService.speak(any)).called(1);
    });

    test('应该处理复杂的语音交互流程', () async {
      final router = VoiceIntentRouter();
      final mockTtsService = MockTtsService();
      final feedbackSystem = VoiceFeedbackSystem(ttsService: mockTtsService);

      // 1. 用户发出模糊命令
      var intentResult = await router.analyzeIntent('改一下');
      await feedbackSystem.provideContextualFeedback(
        intentResult: intentResult,
      );
      expect(feedbackSystem.state.currentFeedback!.type,
             equals(VoiceFeedbackType.warning));

      // 2. 用户澄清命令
      intentResult = await router.analyzeIntent('把午餐改成40元');
      await feedbackSystem.provideContextualFeedback(
        intentResult: intentResult,
      );
      expect(feedbackSystem.state.currentFeedback!.type,
             equals(VoiceFeedbackType.confirmation));

      // 3. 操作成功反馈
      final result = OperationResult.success('modify');
      await feedbackSystem.provideOperationFeedback(result: result);
      expect(feedbackSystem.state.currentFeedback!.type,
             equals(VoiceFeedbackType.success));

      // 验证反馈历史记录了整个流程
      expect(feedbackSystem.feedbackHistory, hasLength(3));
    });
  });
}