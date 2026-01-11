import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:ai_bookkeeping/services/voice/voice_delete_service.dart';
import 'package:ai_bookkeeping/services/voice/entity_disambiguation_service.dart';

@GenerateNiceMocks([MockSpec<EntityDisambiguationService>()])
import 'voice_delete_service_test.mocks.dart';

void main() {
  group('VoiceDeleteService Tests', () {
    late VoiceDeleteService service;
    late MockEntityDisambiguationService mockDisambiguationService;

    setUp(() {
      mockDisambiguationService = MockEntityDisambiguationService();
      service = VoiceDeleteService(
        disambiguationService: mockDisambiguationService,
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('DeleteType', () {
      test('应该包含单笔和批量两种类型', () {
        expect(DeleteType.values, contains(DeleteType.single));
        expect(DeleteType.values, contains(DeleteType.batch));
      });
    });

    group('ConfirmLevel', () {
      test('应该包含所有确认级别', () {
        expect(ConfirmLevel.values, contains(ConfirmLevel.level1));
        expect(ConfirmLevel.values, contains(ConfirmLevel.level2));
        expect(ConfirmLevel.values, contains(ConfirmLevel.level3));
        expect(ConfirmLevel.values, contains(ConfirmLevel.level4));
      });

      test('确认级别应该按严格程度排序', () {
        expect(ConfirmLevel.level1.index, lessThan(ConfirmLevel.level2.index));
        expect(ConfirmLevel.level2.index, lessThan(ConfirmLevel.level3.index));
        expect(ConfirmLevel.level3.index, lessThan(ConfirmLevel.level4.index));
      });
    });

    group('DeleteSessionContext', () {
      test('应该正确创建会话上下文', () {
        final record = TransactionRecord(
          id: 'test',
          amount: 30.0,
          date: DateTime.now(),
        );

        final context = DeleteSessionContext(
          currentRecord: record,
          confirmLevel: ConfirmLevel.level2,
          awaitingConfirmation: true,
        );

        expect(context.currentRecord, isNotNull);
        expect(context.confirmLevel, equals(ConfirmLevel.level2));
        expect(context.awaitingConfirmation, isTrue);
      });

      test('toDisambiguationContext 应该正确转换', () {
        final record = TransactionRecord(
          id: 'test_id',
          amount: 30.0,
          date: DateTime.now(),
        );

        final context = DeleteSessionContext(currentRecord: record);
        final disambiguationContext = context.toDisambiguationContext();

        expect(disambiguationContext, isNotNull);
        expect(disambiguationContext?.lastMentionedRecordId, equals('test_id'));
      });

      test('toDisambiguationContext 没有记录时应该返回 null', () {
        const context = DeleteSessionContext();
        expect(context.toDisambiguationContext(), isNull);
      });
    });

    group('DeleteOperation', () {
      test('应该正确记录删除操作', () {
        final records = [
          TransactionRecord(id: 'test1', amount: 30.0, date: DateTime.now()),
          TransactionRecord(id: 'test2', amount: 50.0, date: DateTime.now()),
        ];

        final operation = DeleteOperation(
          records: records,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        );

        expect(operation.records.length, equals(2));
        expect(operation.isExpired, isFalse);
        expect(operation.remainingDays, greaterThan(0));
      });

      test('isExpired 应该正确判断是否过期', () {
        final expiredOperation = DeleteOperation(
          records: [TransactionRecord(id: 'test', amount: 30.0, date: DateTime.now())],
          timestamp: DateTime.now().subtract(const Duration(days: 31)),
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        expect(expiredOperation.isExpired, isTrue);
      });

      test('totalAmount 应该正确计算总金额', () {
        final records = [
          TransactionRecord(id: 'test1', amount: 30.0, date: DateTime.now()),
          TransactionRecord(id: 'test2', amount: 50.0, date: DateTime.now()),
          TransactionRecord(id: 'test3', amount: 20.0, date: DateTime.now()),
        ];

        final operation = DeleteOperation(
          records: records,
          timestamp: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        );

        expect(operation.totalAmount, equals(100.0));
      });
    });

    group('DeleteResult', () {
      test('success 应该正确创建成功结果', () {
        final records = [
          TransactionRecord(id: 'test', amount: 30.0, date: DateTime.now()),
        ];

        final result = DeleteResult.success(
          deletedRecords: records,
          canRecover: true,
          recoveryDays: 30,
          message: '删除成功',
        );

        expect(result.isSuccess, isTrue);
        expect(result.canRecover, isTrue);
        expect(result.recoveryDays, equals(30));
        expect(result.message, equals('删除成功'));
      });

      test('awaitingVoiceConfirmation 应该正确创建等待语音确认结果', () {
        final result = DeleteResult.awaitingVoiceConfirmation(
          records: [TransactionRecord(id: 'test', amount: 30.0, date: DateTime.now())],
          confirmLevel: ConfirmLevel.level1,
          prompt: '确定删除吗？',
        );

        expect(result.needsConfirmation, isTrue);
        expect(result.confirmLevel, equals(ConfirmLevel.level1));
        expect(result.showScreenConfirm, isFalse);
      });

      test('awaitingConfirmation 应该正确创建等待确认结果', () {
        final result = DeleteResult.awaitingConfirmation(
          records: [TransactionRecord(id: 'test', amount: 30.0, date: DateTime.now())],
          confirmLevel: ConfirmLevel.level2,
          prompt: '确定删除吗？',
          showScreenConfirm: true,
        );

        expect(result.needsConfirmation, isTrue);
        expect(result.showScreenConfirm, isTrue);
      });

      test('requireScreenConfirmation 应该正确创建需要屏幕确认结果', () {
        final result = DeleteResult.requireScreenConfirmation(
          records: [TransactionRecord(id: 'test', amount: 30.0, date: DateTime.now())],
          prompt: '请在屏幕上确认',
        );

        expect(result.requiresScreenConfirm, isTrue);
        expect(result.confirmLevel, equals(ConfirmLevel.level3));
      });

      test('needClarification 应该正确创建需要澄清结果', () {
        final result = DeleteResult.needClarification(
          candidates: [],
          prompt: '请选择要删除的记录',
        );

        expect(result.needsClarification, isTrue);
      });

      test('highRiskBlocked 应该正确创建高风险阻止结果', () {
        final result = DeleteResult.highRiskBlocked(
          message: '高风险操作',
          redirectRoute: '/settings',
        );

        expect(result.isBlocked, isTrue);
        expect(result.redirectRoute, equals('/settings'));
      });

      test('cancelled 应该正确创建取消结果', () {
        final result = DeleteResult.cancelled();

        expect(result.isCancelled, isTrue);
        expect(result.message, equals('已取消删除'));
      });

      test('error 应该正确创建错误结果', () {
        final result = DeleteResult.error('删除失败');

        expect(result.isError, isTrue);
        expect(result.errorMessage, equals('删除失败'));
      });

      test('noTargetSpecified 应该返回正确状态', () {
        final result = DeleteResult.noTargetSpecified();

        expect(result.status, equals(DeleteResultStatus.noTargetSpecified));
        expect(result.prompt, contains('说明'));
      });

      test('noRecordFound 应该返回正确状态', () {
        final result = DeleteResult.noRecordFound();

        expect(result.status, equals(DeleteResultStatus.noRecordFound));
        expect(result.prompt, contains('找到'));
      });

      test('generateFeedbackText 应该为各种状态生成正确的文本', () {
        // 成功
        final successResult = DeleteResult.success(
          deletedRecords: [],
          canRecover: true,
          message: '删除成功',
        );
        expect(successResult.generateFeedbackText(), equals('删除成功'));

        // 取消
        final cancelledResult = DeleteResult.cancelled();
        expect(cancelledResult.generateFeedbackText(), contains('取消'));

        // 高风险阻止
        final blockedResult = DeleteResult.highRiskBlocked(
          message: '无法通过语音完成',
          redirectRoute: '/settings',
        );
        expect(blockedResult.generateFeedbackText(), contains('无法通过语音完成'));

        // 错误
        final errorResult = DeleteResult.error('发生错误');
        expect(errorResult.generateFeedbackText(), equals('发生错误'));
      });
    });

    group('DeleteResultStatus', () {
      test('应该包含所有结果状态', () {
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.success));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.awaitingVoiceConfirmation));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.awaitingConfirmation));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.requireScreenConfirmation));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.needClarification));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.needMoreInfo));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.noTargetSpecified));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.noRecordFound));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.highRiskBlocked));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.cancelled));
        expect(DeleteResultStatus.values, contains(DeleteResultStatus.error));
      });
    });

    group('VoiceDeleteService 状态管理', () {
      test('初始状态应该没有待处理的删除', () {
        expect(service.hasPendingDelete, isFalse);
      });

      test('pendingDeleteCount 初始应该为 0', () {
        expect(service.pendingDeleteCount, equals(0));
      });

      test('cancelDelete 应该清除当前会话', () {
        service.cancelDelete();
        expect(service.hasPendingDelete, isFalse);
      });

      test('getRecoverableDeletes 初始应该返回空列表', () {
        final recoverable = service.getRecoverableDeletes();
        expect(recoverable, isEmpty);
      });
    });

    group('常量配置', () {
      test('maxHistorySize 应该是合理的值', () {
        expect(VoiceDeleteService.maxHistorySize, greaterThan(0));
        expect(VoiceDeleteService.maxHistorySize, lessThanOrEqualTo(200));
      });

      test('recycleBinRetentionDays 应该是合理的值', () {
        expect(VoiceDeleteService.recycleBinRetentionDays, greaterThan(0));
        expect(VoiceDeleteService.recycleBinRetentionDays, lessThanOrEqualTo(90));
      });
    });

    group('QueryConditions', () {
      test('应该正确创建查询条件', () {
        final now = DateTime.now();
        final conditions = QueryConditions(
          startDate: now.subtract(const Duration(days: 7)),
          endDate: now,
          categoryHint: '餐饮',
          limit: 50,
        );

        expect(conditions.startDate, isNotNull);
        expect(conditions.endDate, isNotNull);
        expect(conditions.categoryHint, equals('餐饮'));
        expect(conditions.limit, equals(50));
      });
    });

    group('高风险操作检测', () {
      test('清空回收站应该被识别为高风险', () async {
        when(mockDisambiguationService.disambiguate(
          any,
          queryCallback: anyNamed('queryCallback'),
          context: anyNamed('context'),
        )).thenAnswer((_) async => DisambiguationResult.noReference());

        final result = await service.processDeleteRequest(
          '清空回收站',
          queryCallback: (_) async => [],
          deleteCallback: (_) async => true,
        );

        expect(result.isBlocked, isTrue);
        expect(result.redirectRoute, equals('/recycle-bin'));
      });

      test('删除账本应该被识别为高风险', () async {
        when(mockDisambiguationService.disambiguate(
          any,
          queryCallback: anyNamed('queryCallback'),
          context: anyNamed('context'),
        )).thenAnswer((_) async => DisambiguationResult.noReference());

        final result = await service.processDeleteRequest(
          '删除账本',
          queryCallback: (_) async => [],
          deleteCallback: (_) async => true,
        );

        expect(result.isBlocked, isTrue);
        expect(result.redirectRoute, equals('/ledger-settings'));
      });

      test('删除账户应该被识别为高风险', () async {
        when(mockDisambiguationService.disambiguate(
          any,
          queryCallback: anyNamed('queryCallback'),
          context: anyNamed('context'),
        )).thenAnswer((_) async => DisambiguationResult.noReference());

        final result = await service.processDeleteRequest(
          '删除账户',
          queryCallback: (_) async => [],
          deleteCallback: (_) async => true,
        );

        expect(result.isBlocked, isTrue);
        expect(result.redirectRoute, equals('/account-settings'));
      });
    });
  });
}
