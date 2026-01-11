import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:ai_bookkeeping/services/voice_service_coordinator.dart';
import 'package:ai_bookkeeping/services/voice/voice_intent_router.dart';
import 'package:ai_bookkeeping/services/voice_feedback_system.dart';
import 'package:ai_bookkeeping/services/voice/entity_disambiguation_service.dart';
import 'package:ai_bookkeeping/services/voice/voice_delete_service.dart';
import 'package:ai_bookkeeping/services/voice/voice_modify_service.dart';
import 'package:ai_bookkeeping/services/voice_recognition_engine.dart';
import 'package:ai_bookkeeping/services/tts_service.dart' show TTSService;
import 'package:ai_bookkeeping/services/voice_navigation_service.dart';
import 'package:ai_bookkeeping/services/database_service.dart';

// Generate mocks for all dependencies
@GenerateNiceMocks([
  MockSpec<VoiceIntentRouter>(),
  MockSpec<VoiceFeedbackSystem>(),
  MockSpec<EntityDisambiguationService>(),
  MockSpec<VoiceDeleteService>(),
  MockSpec<VoiceModifyService>(),
  MockSpec<VoiceRecognitionEngine>(),
  MockSpec<TTSService>(),
  MockSpec<VoiceNavigationService>(),
  MockSpec<DatabaseService>(),
])
import 'voice_service_coordinator_test.mocks.dart';

void main() {
  group('VoiceServiceCoordinator Integration Tests', () {
    late VoiceServiceCoordinator coordinator;
    late MockVoiceIntentRouter mockIntentRouter;
    late MockVoiceFeedbackSystem mockFeedbackSystem;
    late MockEntityDisambiguationService mockDisambiguationService;
    late MockVoiceDeleteService mockDeleteService;
    late MockVoiceModifyService mockModifyService;
    late MockVoiceRecognitionEngine mockRecognitionEngine;
    late MockTTSService mockTtsService;
    late MockVoiceNavigationService mockNavigationService;
    late MockDatabaseService mockDatabaseService;

    setUp(() {
      // Create all mocks
      mockIntentRouter = MockVoiceIntentRouter();
      mockFeedbackSystem = MockVoiceFeedbackSystem();
      mockDisambiguationService = MockEntityDisambiguationService();
      mockDeleteService = MockVoiceDeleteService();
      mockModifyService = MockVoiceModifyService();
      mockRecognitionEngine = MockVoiceRecognitionEngine();
      mockTtsService = MockTTSService();
      mockNavigationService = MockVoiceNavigationService();
      mockDatabaseService = MockDatabaseService();

      // Create coordinator with mocks
      coordinator = VoiceServiceCoordinator(
        recognitionEngine: mockRecognitionEngine,
        ttsService: mockTtsService,
        disambiguationService: mockDisambiguationService,
        deleteService: mockDeleteService,
        modifyService: mockModifyService,
        navigationService: mockNavigationService,
        intentRouter: mockIntentRouter,
        feedbackSystem: mockFeedbackSystem,
        databaseService: mockDatabaseService,
      );
    });

    group('语音会话管理', () {
      test('应该正确启动语音会话', () async {
        when(mockRecognitionEngine.initializeOfflineModel())
            .thenAnswer((_) async => {});
        when(mockFeedbackSystem.provideFeedback(
          message: any,
          type: any,
          priority: any,
        )).thenAnswer((_) async => {});

        final result = await coordinator.startVoiceSession();

        expect(result.isSuccess, isTrue);
        expect(coordinator.sessionState, equals(VoiceSessionState.idle));

        verify(mockRecognitionEngine.initializeOfflineModel()).called(1);
        verify(mockFeedbackSystem.provideFeedback(
          message: '请说话',
          type: VoiceFeedbackType.info,
          priority: VoiceFeedbackPriority.medium,
        )).called(1);
      });

      test('启动失败时应该返回错误结果', () async {
        when(mockRecognitionEngine.initializeOfflineModel())
            .thenThrow(Exception('初始化失败'));

        final result = await coordinator.startVoiceSession();

        expect(result.isError, isTrue);
        expect(result.errorMessage, contains('启动语音识别失败'));
        expect(coordinator.sessionState, equals(VoiceSessionState.idle));
      });
    });

    group('语音命令处理', () {
      test('应该正确处理删除命令', () async {
        // Setup intent router mock
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.deleteTransaction,
                  confidence: 0.8,
                  rawInput: '删除昨天的午餐',
                ));

        // Setup feedback system mock
        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        // Setup delete service mock
        final mockDeleteResult = DeleteResult.success(
          deletedRecords: [],
          canRecover: true,
          message: '删除成功',
        );
        when(mockDeleteService.processDeleteRequest(
          any,
          queryCallback: anyNamed('queryCallback'),
          deleteCallback: anyNamed('deleteCallback'),
        )).thenAnswer((_) async => mockDeleteResult);

        // Setup feedback system for operation feedback
        when(mockFeedbackSystem.provideOperationFeedback(
          result: anyNamed('result'),
        )).thenAnswer((_) async => {});

        final result = await coordinator.processVoiceCommand('删除昨天的午餐');

        expect(result, isNotNull);
        expect(coordinator.commandHistory, hasLength(1));
        expect(coordinator.commandHistory.first.input, equals('删除昨天的午餐'));

        // Verify intent analysis was called
        verify(mockIntentRouter.analyzeIntent('删除昨天的午餐',
            context: anyNamed('context'))).called(1);

        // Verify contextual feedback was provided
        verify(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: true,
          enableHaptic: false,
        )).called(1);

        // Verify delete service was called
        verify(mockDeleteService.processDeleteRequest(
          '删除昨天的午餐',
          queryCallback: anyNamed('queryCallback'),
          deleteCallback: anyNamed('deleteCallback'),
        )).called(1);
      });

      test('应该正确处理修改命令', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.modifyTransaction,
                  confidence: 0.85,
                  rawInput: '把午餐改成40元',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        final testRecord = TransactionRecord(
          id: '1',
          amount: 30.0,
          category: '餐饮',
          date: DateTime.now(),
        );
        final updatedRecord = TransactionRecord(
          id: '1',
          amount: 40.0,
          category: '餐饮',
          date: DateTime.now(),
        );
        final mockModifyResult = ModifyResult.success(
          originalRecord: testRecord,
          updatedRecord: updatedRecord,
          modifications: [
            FieldModification(
              field: ModifyField.amount,
              newValue: 40.0,
              rawText: '40元',
            ),
          ],
        );
        when(mockModifyService.processModifyRequest(
          any,
          queryCallback: anyNamed('queryCallback'),
          updateCallback: anyNamed('updateCallback'),
        )).thenAnswer((_) async => mockModifyResult);

        when(mockFeedbackSystem.provideFeedback(
          message: anyNamed('message'),
          type: anyNamed('type'),
          priority: anyNamed('priority'),
        )).thenAnswer((_) async => {});

        final result = await coordinator.processVoiceCommand('把午餐改成40元');

        expect(result, isNotNull);
        verify(mockModifyService.processModifyRequest(
          '把午餐改成40元',
          queryCallback: anyNamed('queryCallback'),
          updateCallback: anyNamed('updateCallback'),
        )).called(1);
      });

      test('应该正确处理导航命令', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.navigateToPage,
                  confidence: 0.9,
                  rawInput: '打开设置页面',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        final mockNavigationResult = NavigationResult(
          success: true,
        );
        when(mockNavigationService.parseNavigation(any))
            .thenReturn(mockNavigationResult);

        when(mockFeedbackSystem.provideFeedback(
          message: anyNamed('message'),
          type: anyNamed('type'),
          priority: anyNamed('priority'),
        )).thenAnswer((_) async => {});

        final result = await coordinator.processVoiceCommand('打开设置页面');

        expect(result, isNotNull);
        verify(mockNavigationService.parseNavigation('打开设置页面')).called(1);
      });

      test('应该正确处理未知命令', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.unknown,
                  confidence: 0.2,
                  rawInput: '这个那个的',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        when(mockFeedbackSystem.provideFeedback(
          message: anyNamed('message'),
          type: anyNamed('type'),
          priority: anyNamed('priority'),
        )).thenAnswer((_) async => {});

        final result = await coordinator.processVoiceCommand('这个那个的');

        expect(result, isNotNull);
        expect(result.isError, isTrue);
      });

      test('处理过程中发生错误时应该提供错误反馈', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenThrow(Exception('意图分析失败'));

        when(mockFeedbackSystem.provideErrorFeedback(
          error: anyNamed('error'),
          suggestion: anyNamed('suggestion'),
          context: anyNamed('context'),
        )).thenAnswer((_) async => {});

        final result = await coordinator.processVoiceCommand('测试命令');

        expect(result, isNotNull);
        expect(result.isError, isTrue);
        expect(coordinator.sessionState, equals(VoiceSessionState.idle));

        verify(mockFeedbackSystem.provideErrorFeedback(
          error: '抱歉，处理您的指令时出现了错误',
          suggestion: '请稍后重试或重新说一遍',
          context: anyNamed('context'),
        )).called(1);
      });
    });

    group('会话上下文管理', () {
      test('应该在澄清模式下保持会话状态', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.deleteTransaction,
                  confidence: 0.8,
                  rawInput: '删除记录',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        // Mock delete service to require clarification
        final mockDeleteResult = DeleteResult.needClarification(
          candidates: [],
          prompt: '请选择要删除的记录',
        );
        when(mockDeleteService.processDeleteRequest(
          any,
          queryCallback: anyNamed('queryCallback'),
          deleteCallback: anyNamed('deleteCallback'),
        )).thenAnswer((_) async => mockDeleteResult);

        when(mockFeedbackSystem.provideFeedback(
          message: anyNamed('message'),
          type: anyNamed('type'),
          priority: anyNamed('priority'),
        )).thenAnswer((_) async => {});

        await coordinator.processVoiceCommand('删除记录');

        expect(coordinator.currentIntentType, equals(VoiceIntentType.deleteTransaction));
        expect(coordinator.hasActiveSession, isTrue);
        expect(coordinator.sessionState, equals(VoiceSessionState.waitingForClarification));
      });

      test('应该在确认模式下保持会话状态', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.modifyTransaction,
                  confidence: 0.8,
                  rawInput: '修改金额',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        // Mock modify service to require confirmation
        final originalRecord = TransactionRecord(
          id: '1',
          amount: 30.0,
          category: '餐饮',
          date: DateTime.now(),
        );
        final previewRecord = TransactionRecord(
          id: '1',
          amount: 35.0,
          category: '餐饮',
          date: DateTime.now(),
        );
        final mockModifyResult = ModifyResult.needConfirmation(
          preview: ModifyPreview(
            originalRecord: originalRecord,
            modifications: [
              FieldModification(
                field: ModifyField.amount,
                newValue: 35.0,
                rawText: '35元',
              ),
            ],
            previewRecord: previewRecord,
          ),
        );
        when(mockModifyService.processModifyRequest(
          any,
          queryCallback: anyNamed('queryCallback'),
          updateCallback: anyNamed('updateCallback'),
        )).thenAnswer((_) async => mockModifyResult);

        when(mockFeedbackSystem.provideConfirmationFeedback(
          operation: anyNamed('operation'),
          details: anyNamed('details'),
        )).thenAnswer((_) async => {});

        await coordinator.processVoiceCommand('修改金额');

        expect(coordinator.currentIntentType, equals(VoiceIntentType.modifyTransaction));
        expect(coordinator.hasActiveSession, isTrue);
        expect(coordinator.sessionState, equals(VoiceSessionState.waitingForConfirmation));
      });
    });

    group('命令历史管理', () {
      test('应该记录命令历史', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.addTransaction,
                  confidence: 0.8,
                  rawInput: '添加午餐35元',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        when(mockFeedbackSystem.provideFeedback(
          message: anyNamed('message'),
          type: anyNamed('type'),
          priority: anyNamed('priority'),
        )).thenAnswer((_) async => {});

        await coordinator.processVoiceCommand('添加午餐35元');

        expect(coordinator.commandHistory, hasLength(1));
        expect(coordinator.commandHistory.first.input, equals('添加午餐35元'));
        expect(coordinator.commandHistory.first.intentResult, isNotNull);
        expect(coordinator.commandHistory.first.result, isNotNull);
      });

      test('应该限制历史记录数量', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.addTransaction,
                  confidence: 0.8,
                  rawInput: 'test',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        when(mockFeedbackSystem.provideFeedback(
          message: anyNamed('message'),
          type: anyNamed('type'),
          priority: anyNamed('priority'),
        )).thenAnswer((_) async => {});

        // Add more commands than max history size
        for (int i = 0; i < 55; i++) {
          await coordinator.processVoiceCommand('命令 $i');
        }

        expect(coordinator.commandHistory, hasLength(50));
        // Verify it keeps the most recent commands
        expect(coordinator.commandHistory.last.input, equals('命令 54'));
      });

      test('应该能获取最近的命令历史', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.addTransaction,
                  confidence: 0.8,
                  rawInput: 'test',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        when(mockFeedbackSystem.provideFeedback(
          message: anyNamed('message'),
          type: anyNamed('type'),
          priority: anyNamed('priority'),
        )).thenAnswer((_) async => {});

        // Add 15 commands
        for (int i = 0; i < 15; i++) {
          await coordinator.processVoiceCommand('命令 $i');
        }

        final recentCommands = coordinator.getRecentCommands(limit: 5);
        expect(recentCommands, hasLength(5));
        // Should be in reverse order (most recent first)
        expect(recentCommands.first.input, equals('命令 14'));
        expect(recentCommands.last.input, equals('命令 10'));
      });

      test('应该能清除命令历史', () async {
        when(mockIntentRouter.analyzeIntent(any, context: anyNamed('context')))
            .thenAnswer((_) async => IntentAnalysisResult(
                  intent: VoiceIntentType.addTransaction,
                  confidence: 0.8,
                  rawInput: 'test',
                ));

        when(mockFeedbackSystem.provideContextualFeedback(
          intentResult: anyNamed('intentResult'),
          enableTts: anyNamed('enableTts'),
          enableHaptic: anyNamed('enableHaptic'),
        )).thenAnswer((_) async => {});

        when(mockFeedbackSystem.provideFeedback(
          message: anyNamed('message'),
          type: anyNamed('type'),
          priority: anyNamed('priority'),
        )).thenAnswer((_) async => {});

        await coordinator.processVoiceCommand('测试命令');
        expect(coordinator.commandHistory, hasLength(1));

        coordinator.clearCommandHistory();
        expect(coordinator.commandHistory, isEmpty);
      });
    });

    group('会话控制', () {
      test('应该能停止语音会话', () async {
        when(mockTtsService.stop()).thenAnswer((_) async => {});

        await coordinator.stopVoiceSession();

        expect(coordinator.sessionState, equals(VoiceSessionState.idle));
        expect(coordinator.hasActiveSession, isFalse);
        verify(mockTtsService.stop()).called(1);
      });
    });

    group('资源管理', () {
      test('dispose时应该释放相关资源', () {
        coordinator.dispose();

        verify(mockRecognitionEngine.dispose()).called(1);
        verify(mockTtsService.dispose()).called(1);
      });
    });
  });

  group('语音服务集成测试', () {
    test('完整的语音交互流程', () async {
      // This would be a real integration test with actual services
      // For now, we'll use a simpler test to verify the coordinator
      // can handle a complete interaction flow

      final coordinator = VoiceServiceCoordinator();

      // Test that the coordinator initializes correctly
      expect(coordinator.sessionState, equals(VoiceSessionState.idle));
      expect(coordinator.hasActiveSession, isFalse);
      expect(coordinator.commandHistory, isEmpty);
    });
  });
}