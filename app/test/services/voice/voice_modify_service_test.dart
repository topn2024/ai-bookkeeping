import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import 'package:ai_bookkeeping/services/voice/voice_modify_service.dart';
import 'package:ai_bookkeeping/services/voice/entity_disambiguation_service.dart';

@GenerateNiceMocks([MockSpec<EntityDisambiguationService>()])
import 'voice_modify_service_test.mocks.dart';

void main() {
  group('VoiceModifyService Tests', () {
    late VoiceModifyService service;
    late MockEntityDisambiguationService mockDisambiguationService;

    setUp(() {
      mockDisambiguationService = MockEntityDisambiguationService();
      service = VoiceModifyService(
        disambiguationService: mockDisambiguationService,
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('ModifyField', () {
      test('应该包含所有可修改的字段', () {
        expect(ModifyField.values, contains(ModifyField.amount));
        expect(ModifyField.values, contains(ModifyField.category));
        expect(ModifyField.values, contains(ModifyField.subCategory));
        expect(ModifyField.values, contains(ModifyField.description));
        expect(ModifyField.values, contains(ModifyField.date));
        expect(ModifyField.values, contains(ModifyField.account));
        expect(ModifyField.values, contains(ModifyField.tags));
        expect(ModifyField.values, contains(ModifyField.transactionType));
      });
    });

    group('ModifyConfirmLevel', () {
      test('应该包含所有确认级别', () {
        expect(ModifyConfirmLevel.values, contains(ModifyConfirmLevel.none));
        expect(ModifyConfirmLevel.values, contains(ModifyConfirmLevel.level1));
        expect(ModifyConfirmLevel.values, contains(ModifyConfirmLevel.level2));
        expect(ModifyConfirmLevel.values, contains(ModifyConfirmLevel.level3));
        expect(ModifyConfirmLevel.values, contains(ModifyConfirmLevel.level4));
      });

      test('确认级别应该按严格程度排序', () {
        expect(ModifyConfirmLevel.none.index, lessThan(ModifyConfirmLevel.level1.index));
        expect(ModifyConfirmLevel.level1.index, lessThan(ModifyConfirmLevel.level2.index));
        expect(ModifyConfirmLevel.level2.index, lessThan(ModifyConfirmLevel.level3.index));
        expect(ModifyConfirmLevel.level3.index, lessThan(ModifyConfirmLevel.level4.index));
      });
    });

    group('FieldModification', () {
      test('应该正确创建金额修改', () {
        const modification = FieldModification(
          field: ModifyField.amount,
          newValue: 50.0,
          rawText: '改成50元',
        );

        expect(modification.field, equals(ModifyField.amount));
        expect(modification.newValue, equals(50.0));
        expect(modification.fieldName, equals('金额'));
        expect(modification.displayValue, equals('¥50.00'));
      });

      test('应该正确创建分类修改', () {
        const modification = FieldModification(
          field: ModifyField.category,
          newValue: '餐饮',
          rawText: '改成餐饮',
        );

        expect(modification.field, equals(ModifyField.category));
        expect(modification.newValue, equals('餐饮'));
        expect(modification.fieldName, equals('分类'));
        expect(modification.displayValue, equals('餐饮'));
      });

      test('应该正确创建日期修改', () {
        final date = DateTime(2024, 3, 15);
        final modification = FieldModification(
          field: ModifyField.date,
          newValue: date,
          rawText: '改成3月15日',
        );

        expect(modification.field, equals(ModifyField.date));
        expect(modification.fieldName, equals('日期'));
        expect(modification.displayValue, equals('3月15日'));
      });

      test('应该正确创建标签修改（添加）', () {
        const modification = FieldModification(
          field: ModifyField.tags,
          newValue: '重要',
          rawText: '加个标签重要',
          metadata: {'action': 'add'},
        );

        expect(modification.field, equals(ModifyField.tags));
        expect(modification.metadata?['action'], equals('add'));
      });

      test('应该正确创建标签修改（删除）', () {
        const modification = FieldModification(
          field: ModifyField.tags,
          newValue: '测试',
          rawText: '去掉测试标签',
          metadata: {'action': 'remove'},
        );

        expect(modification.metadata?['action'], equals('remove'));
      });
    });

    group('ModifyOperation', () {
      test('应该正确记录修改操作', () {
        final record = TransactionRecord(
          id: 'test_id',
          amount: 30.0,
          category: '餐饮',
          date: DateTime.now(),
        );

        final operation = ModifyOperation(
          recordId: 'test_id',
          originalRecord: record,
          modifications: const [
            FieldModification(
              field: ModifyField.amount,
              newValue: 50.0,
              rawText: '改成50',
            ),
          ],
          timestamp: DateTime.now(),
        );

        expect(operation.recordId, equals('test_id'));
        expect(operation.originalRecord.amount, equals(30.0));
        expect(operation.modifications.length, equals(1));
      });
    });

    group('ModifyPreview', () {
      test('应该正确生成预览文本', () {
        final original = TransactionRecord(
          id: 'test',
          amount: 30.0,
          category: '餐饮',
          description: '午餐',
          date: DateTime.now(),
        );

        final modified = TransactionRecord(
          id: 'test',
          amount: 50.0,
          category: '餐饮',
          description: '午餐',
          date: DateTime.now(),
        );

        final preview = ModifyPreview(
          originalRecord: original,
          modifications: const [
            FieldModification(
              field: ModifyField.amount,
              newValue: 50.0,
              rawText: '改成50',
            ),
          ],
          previewRecord: modified,
        );

        final text = preview.generatePreviewText();
        expect(text, contains('午餐'));
        expect(text, contains('30.00'));
        expect(text, contains('金额'));
      });
    });

    group('ModifyResult', () {
      test('success 应该正确创建成功结果', () {
        final original = TransactionRecord(
          id: 'test',
          amount: 30.0,
          category: '餐饮',
          date: DateTime.now(),
        );

        final updated = TransactionRecord(
          id: 'test',
          amount: 50.0,
          category: '餐饮',
          date: DateTime.now(),
        );

        final result = ModifyResult.success(
          originalRecord: original,
          updatedRecord: updated,
          modifications: const [
            FieldModification(
              field: ModifyField.amount,
              newValue: 50.0,
              rawText: '改成50',
            ),
          ],
        );

        expect(result.isSuccess, isTrue);
        expect(result.status, equals(ModifyResultStatus.success));
        expect(result.originalRecord?.amount, equals(30.0));
        expect(result.updatedRecord?.amount, equals(50.0));
      });

      test('needConfirmation 应该正确创建需要确认的结果', () {
        final original = TransactionRecord(
          id: 'test',
          amount: 30.0,
          category: '餐饮',
          date: DateTime.now(),
        );

        final preview = ModifyPreview(
          originalRecord: original,
          modifications: const [],
          previewRecord: original,
        );

        final result = ModifyResult.needConfirmation(
          preview: preview,
          confirmLevel: ModifyConfirmLevel.level2,
          confirmPrompt: '确认修改吗？',
        );

        expect(result.needsConfirmation, isTrue);
        expect(result.confirmLevel, equals(ModifyConfirmLevel.level2));
        expect(result.confirmPrompt, equals('确认修改吗？'));
      });

      test('needClarification 应该正确创建需要澄清的结果', () {
        final result = ModifyResult.needClarification(
          candidates: [],
          prompt: '请选择要修改的记录',
          modifications: const [],
        );

        expect(result.needsClarification, isTrue);
        expect(result.prompt, contains('选择'));
      });

      test('noModificationDetected 应该返回正确状态', () {
        final result = ModifyResult.noModificationDetected();

        expect(result.status, equals(ModifyResultStatus.noModificationDetected));
      });

      test('error 应该正确创建错误结果', () {
        final result = ModifyResult.error('修改失败');

        expect(result.isError, isTrue);
        expect(result.errorMessage, equals('修改失败'));
      });

      test('requiresScreenConfirmation 应该正确判断是否需要屏幕确认', () {
        final result1 = ModifyResult.needConfirmation(
          preview: ModifyPreview(
            originalRecord: TransactionRecord(
              id: 'test',
              amount: 30.0,
              date: DateTime.now(),
            ),
            modifications: const [],
            previewRecord: TransactionRecord(
              id: 'test',
              amount: 30.0,
              date: DateTime.now(),
            ),
          ),
          confirmLevel: ModifyConfirmLevel.level3,
        );

        final result2 = ModifyResult.needConfirmation(
          preview: ModifyPreview(
            originalRecord: TransactionRecord(
              id: 'test',
              amount: 30.0,
              date: DateTime.now(),
            ),
            modifications: const [],
            previewRecord: TransactionRecord(
              id: 'test',
              amount: 30.0,
              date: DateTime.now(),
            ),
          ),
          confirmLevel: ModifyConfirmLevel.level1,
        );

        expect(result1.requiresScreenConfirmation, isTrue);
        expect(result2.requiresScreenConfirmation, isFalse);
      });

      test('generateFeedbackText 应该为各种状态生成正确的文本', () {
        // 成功
        final successResult = ModifyResult.success(
          originalRecord: TransactionRecord(id: 'test', amount: 30, date: DateTime.now()),
          updatedRecord: TransactionRecord(id: 'test', amount: 50, date: DateTime.now()),
          modifications: const [
            FieldModification(field: ModifyField.amount, newValue: 50.0, rawText: '改成50'),
          ],
        );
        expect(successResult.generateFeedbackText(), contains('金额'));
        expect(successResult.generateFeedbackText(), contains('50'));

        // 未检测到修改
        final noModResult = ModifyResult.noModificationDetected();
        expect(noModResult.generateFeedbackText(), contains('没有检测到'));

        // 错误
        final errorResult = ModifyResult.error('发生错误');
        expect(errorResult.generateFeedbackText(), equals('发生错误'));
      });
    });

    group('VoiceModifyService 状态管理', () {
      test('初始状态应该没有待处理的修改', () {
        expect(service.hasPendingModification, isFalse);
      });

      test('cancelModification 应该清除当前会话', () {
        // 模拟有待处理的修改
        service.cancelModification();
        expect(service.hasPendingModification, isFalse);
      });

      test('clearSession 应该清除会话', () {
        service.clearSession();
        expect(service.hasPendingModification, isFalse);
      });

      test('getLastModification 初始应该返回 null', () {
        expect(service.getLastModification(), isNull);
      });

      test('getModifyHistory 初始应该返回空列表', () {
        final history = service.getModifyHistory();
        expect(history, isEmpty);
      });
    });

    group('ModifyResultStatus', () {
      test('应该包含所有结果状态', () {
        expect(ModifyResultStatus.values, contains(ModifyResultStatus.success));
        expect(ModifyResultStatus.values, contains(ModifyResultStatus.needConfirmation));
        expect(ModifyResultStatus.values, contains(ModifyResultStatus.needClarification));
        expect(ModifyResultStatus.values, contains(ModifyResultStatus.needMoreInfo));
        expect(ModifyResultStatus.values, contains(ModifyResultStatus.noModificationDetected));
        expect(ModifyResultStatus.values, contains(ModifyResultStatus.noTargetSpecified));
        expect(ModifyResultStatus.values, contains(ModifyResultStatus.noRecordFound));
        expect(ModifyResultStatus.values, contains(ModifyResultStatus.error));
      });
    });

    group('ModifySessionContext', () {
      test('应该正确创建会话上下文', () {
        final record = TransactionRecord(
          id: 'test',
          amount: 30.0,
          date: DateTime.now(),
        );

        final context = ModifySessionContext(
          currentRecord: record,
          pendingModifications: const [
            FieldModification(
              field: ModifyField.amount,
              newValue: 50.0,
              rawText: '改成50',
            ),
          ],
          confirmLevel: ModifyConfirmLevel.level2,
        );

        expect(context.currentRecord, isNotNull);
        expect(context.pendingModifications?.length, equals(1));
        expect(context.confirmLevel, equals(ModifyConfirmLevel.level2));
      });

      test('toDisambiguationContext 应该正确转换', () {
        final record = TransactionRecord(
          id: 'test_id',
          amount: 30.0,
          date: DateTime.now(),
        );

        final context = ModifySessionContext(currentRecord: record);
        final disambiguationContext = context.toDisambiguationContext();

        expect(disambiguationContext, isNotNull);
        expect(disambiguationContext?.lastMentionedRecordId, equals('test_id'));
      });

      test('toDisambiguationContext 没有记录时应该返回 null', () {
        const context = ModifySessionContext();
        expect(context.toDisambiguationContext(), isNull);
      });
    });

    group('常量配置', () {
      test('maxHistorySize 应该是合理的值', () {
        expect(VoiceModifyService.maxHistorySize, greaterThan(0));
        expect(VoiceModifyService.maxHistorySize, lessThanOrEqualTo(100));
      });
    });
  });
}
