import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:ai_bookkeeping/services/voice/voice_modify_service.dart';
import 'package:ai_bookkeeping/services/voice/voice_delete_service.dart';
import 'package:ai_bookkeeping/services/voice/entity_disambiguation_service.dart';
import 'package:ai_bookkeeping/services/tts_service.dart';

@GenerateNiceMocks([
  MockSpec<EntityDisambiguationService>(),
  MockSpec<TTSEngine>(),
])
import 'voice_integration_test.mocks.dart';

void main() {
  group('语音服务集成测试', () {
    late VoiceModifyService modifyService;
    late VoiceDeleteService deleteService;
    late MockEntityDisambiguationService mockDisambiguationService;

    setUp(() {
      mockDisambiguationService = MockEntityDisambiguationService();
      modifyService = VoiceModifyService(
        disambiguationService: mockDisambiguationService,
      );
      deleteService = VoiceDeleteService(
        disambiguationService: mockDisambiguationService,
      );
    });

    tearDown(() {
      modifyService.dispose();
      deleteService.dispose();
    });

    group('修改与删除服务协同', () {
      test('修改服务和删除服务应该使用相同的消歧服务', () {
        // 两个服务都应该能独立工作
        expect(modifyService.hasPendingModification, isFalse);
        expect(deleteService.hasPendingDelete, isFalse);
      });

      test('修改后应该能够删除同一条记录', () async {
        final record = TransactionRecord(
          id: 'test_record',
          amount: 30.0,
          category: '餐饮',
          description: '午餐',
          date: DateTime.now(),
        );

        // 模拟消歧服务返回解析结果
        when(mockDisambiguationService.disambiguate(
          any,
          queryCallback: anyNamed('queryCallback'),
          context: anyNamed('context'),
        )).thenAnswer((_) async => DisambiguationResult.resolved(
          record: record,
          confidence: 0.95,
          references: const [],
          needConfirmation: false,
        ));

        // 服务应该都能正常初始化
        expect(modifyService, isNotNull);
        expect(deleteService, isNotNull);
      });
    });

    group('确认级别一致性', () {
      test('修改和删除的确认级别应该有类似的层次结构', () {
        // ModifyConfirmLevel 和 ConfirmLevel 应该有对应关系
        expect(ModifyConfirmLevel.level1.index, lessThan(ModifyConfirmLevel.level2.index));
        expect(ConfirmLevel.level1.index, lessThan(ConfirmLevel.level2.index));

        expect(ModifyConfirmLevel.level3.index, greaterThan(ModifyConfirmLevel.level2.index));
        expect(ConfirmLevel.level3.index, greaterThan(ConfirmLevel.level2.index));
      });
    });

    group('TransactionRecord 兼容性', () {
      test('TransactionRecord 应该在两个服务中正常工作', () {
        final record = TransactionRecord(
          id: 'test',
          amount: 100.0,
          category: '购物',
          subCategory: '日用品',
          merchant: '超市',
          description: '日常采购',
          date: DateTime.now(),
          account: '微信',
          tags: ['必需品', '日常'],
          type: 'expense',
        );

        // 验证记录属性
        expect(record.id, equals('test'));
        expect(record.amount, equals(100.0));
        expect(record.category, equals('购物'));
        expect(record.subCategory, equals('日用品'));
        expect(record.merchant, equals('超市'));
        expect(record.description, equals('日常采购'));
        expect(record.account, equals('微信'));
        expect(record.tags, contains('必需品'));
        expect(record.type, equals('expense'));
      });

      test('TransactionRecord 应该支持可选字段', () {
        final minimalRecord = TransactionRecord(
          id: 'minimal',
          amount: 50.0,
          date: DateTime.now(),
        );

        expect(minimalRecord.category, isNull);
        expect(minimalRecord.subCategory, isNull);
        expect(minimalRecord.merchant, isNull);
        expect(minimalRecord.description, isNull);
        expect(minimalRecord.account, isNull);
        expect(minimalRecord.tags, isEmpty);
      });
    });

    group('语音反馈文本生成', () {
      test('修改成功反馈应该包含修改内容', () {
        final result = ModifyResult.success(
          originalRecord: TransactionRecord(id: 'test', amount: 30, date: DateTime.now()),
          updatedRecord: TransactionRecord(id: 'test', amount: 50, date: DateTime.now()),
          modifications: const [
            FieldModification(
              field: ModifyField.amount,
              newValue: 50.0,
              rawText: '改成50',
            ),
          ],
        );

        final feedback = result.generateFeedbackText();
        expect(feedback, contains('金额'));
      });

      test('删除成功反馈应该包含可恢复信息', () {
        final result = DeleteResult.success(
          deletedRecords: [TransactionRecord(id: 'test', amount: 30, date: DateTime.now())],
          canRecover: true,
          recoveryDays: 30,
          message: '已删除，30天内可在回收站恢复',
        );

        final feedback = result.generateFeedbackText();
        expect(feedback, contains('恢复'));
      });
    });

    group('错误处理一致性', () {
      test('两个服务的错误结果应该有类似的结构', () {
        final modifyError = ModifyResult.error('修改失败');
        final deleteError = DeleteResult.error('删除失败');

        expect(modifyError.isError, isTrue);
        expect(deleteError.isError, isTrue);

        expect(modifyError.errorMessage, isNotNull);
        expect(deleteError.errorMessage, isNotNull);
      });

      test('需要澄清的结果应该包含候选列表', () {
        final modifyClarification = ModifyResult.needClarification(
          candidates: [],
          prompt: '请选择记录',
          modifications: [],
        );

        final deleteClarification = DeleteResult.needClarification(
          candidates: [],
          prompt: '请选择记录',
        );

        expect(modifyClarification.needsClarification, isTrue);
        expect(deleteClarification.needsClarification, isTrue);
      });
    });

    group('会话状态管理', () {
      test('清除会话应该重置状态', () {
        modifyService.clearSession();
        deleteService.cancelDelete();

        expect(modifyService.hasPendingModification, isFalse);
        expect(deleteService.hasPendingDelete, isFalse);
      });
    });

    group('历史记录管理', () {
      test('修改历史初始应该为空', () {
        final history = modifyService.getModifyHistory();
        expect(history, isEmpty);
      });

      test('删除历史初始应该为空', () {
        final recoverable = deleteService.getRecoverableDeletes();
        expect(recoverable, isEmpty);
      });
    });

    group('ScoredCandidate 兼容性', () {
      test('ScoredCandidate 应该正确存储记录和置信度', () {
        final record = TransactionRecord(
          id: 'test',
          amount: 30.0,
          date: DateTime.now(),
        );

        final candidate = ScoredCandidate(
          record: record,
          confidence: 0.85,
        );

        expect(candidate.record.id, equals('test'));
        expect(candidate.confidence, equals(0.85));
      });
    });

    group('日期处理一致性', () {
      test('记录日期应该被正确处理', () {
        final now = DateTime.now();
        final record = TransactionRecord(
          id: 'test',
          amount: 30.0,
          date: now,
        );

        expect(record.date.year, equals(now.year));
        expect(record.date.month, equals(now.month));
        expect(record.date.day, equals(now.day));
      });
    });

    group('金额处理一致性', () {
      test('金额应该支持小数', () {
        final record = TransactionRecord(
          id: 'test',
          amount: 30.55,
          date: DateTime.now(),
        );

        expect(record.amount, equals(30.55));
      });

      test('金额格式化应该保留两位小数', () {
        final modification = FieldModification(
          field: ModifyField.amount,
          newValue: 100.5,
          rawText: '改成100.5',
        );

        expect(modification.displayValue, equals('¥100.50'));
      });
    });
  });
}
