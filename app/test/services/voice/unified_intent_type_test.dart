import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/unified_intent_type.dart';

void main() {
  group('UnifiedIntentType', () {
    test('should have correct id format', () {
      expect(UnifiedIntentType.transactionAdd.id, 'transaction.add');
      expect(UnifiedIntentType.navigationPage.id, 'navigation.page');
      expect(UnifiedIntentType.configCategory.id, 'config.category');
      expect(UnifiedIntentType.dataExport.id, 'data.export');
    });

    test('should have correct category', () {
      expect(UnifiedIntentType.transactionAdd.category, IntentCategory.transaction);
      expect(UnifiedIntentType.navigationPage.category, IntentCategory.navigation);
      expect(UnifiedIntentType.configCategory.category, IntentCategory.configuration);
      expect(UnifiedIntentType.dataExport.category, IntentCategory.data);
      expect(UnifiedIntentType.vaultCreate.category, IntentCategory.advanced);
      expect(UnifiedIntentType.automationScreenRecognition.category, IntentCategory.automation);
      expect(UnifiedIntentType.conversationConfirm.category, IntentCategory.conversation);
      expect(UnifiedIntentType.systemSettings.category, IntentCategory.system);
    });

    test('fromId should return correct type', () {
      expect(UnifiedIntentType.fromId('transaction.add'), UnifiedIntentType.transactionAdd);
      expect(UnifiedIntentType.fromId('navigation.page'), UnifiedIntentType.navigationPage);
      expect(UnifiedIntentType.fromId('invalid.id'), isNull);
    });

    test('byCategory should return all types in category', () {
      final transactionTypes = UnifiedIntentType.byCategory(IntentCategory.transaction);
      expect(transactionTypes.length, 4);
      expect(transactionTypes, contains(UnifiedIntentType.transactionAdd));
      expect(transactionTypes, contains(UnifiedIntentType.transactionQuery));
      expect(transactionTypes, contains(UnifiedIntentType.transactionModify));
      expect(transactionTypes, contains(UnifiedIntentType.transactionDelete));
    });

    test('isTransactionOperation should return correct value', () {
      expect(UnifiedIntentType.transactionAdd.isTransactionOperation, isTrue);
      expect(UnifiedIntentType.transactionDelete.isTransactionOperation, isTrue);
      expect(UnifiedIntentType.navigationPage.isTransactionOperation, isFalse);
      expect(UnifiedIntentType.configCategory.isTransactionOperation, isFalse);
    });

    test('requiresConfirmation should identify dangerous operations', () {
      expect(UnifiedIntentType.transactionDelete.requiresConfirmation, isTrue);
      expect(UnifiedIntentType.transactionModify.requiresConfirmation, isTrue);
      expect(UnifiedIntentType.configCategory.requiresConfirmation, isTrue);
      expect(UnifiedIntentType.dataExport.requiresConfirmation, isTrue);
      expect(UnifiedIntentType.transactionAdd.requiresConfirmation, isFalse);
      expect(UnifiedIntentType.transactionQuery.requiresConfirmation, isFalse);
    });

    test('priority should return correct operation priority', () {
      expect(UnifiedIntentType.navigationPage.priority, OperationPriority.immediate);
      expect(UnifiedIntentType.conversationConfirm.priority, OperationPriority.immediate);
      expect(UnifiedIntentType.transactionQuery.priority, OperationPriority.normal);
      expect(UnifiedIntentType.transactionAdd.priority, OperationPriority.deferred);
      expect(UnifiedIntentType.dataExport.priority, OperationPriority.background);
      expect(UnifiedIntentType.automationAlipaySync.priority, OperationPriority.background);
    });
  });

  group('VoiceIntentTypeMapping', () {
    test('fromLegacyVoiceIntent should convert legacy names', () {
      expect(
        VoiceIntentTypeMapping.fromLegacyVoiceIntent('addTransaction'),
        UnifiedIntentType.transactionAdd,
      );
      expect(
        VoiceIntentTypeMapping.fromLegacyVoiceIntent('deleteTransaction'),
        UnifiedIntentType.transactionDelete,
      );
      expect(
        VoiceIntentTypeMapping.fromLegacyVoiceIntent('navigateToPage'),
        UnifiedIntentType.navigationPage,
      );
      expect(
        VoiceIntentTypeMapping.fromLegacyVoiceIntent('confirmAction'),
        UnifiedIntentType.conversationConfirm,
      );
      expect(
        VoiceIntentTypeMapping.fromLegacyVoiceIntent('unknown'),
        UnifiedIntentType.unknown,
      );
    });

    test('toLegacyVoiceIntentName should convert back', () {
      expect(
        UnifiedIntentType.transactionAdd.toLegacyVoiceIntentName(),
        'addTransaction',
      );
      expect(
        UnifiedIntentType.transactionDelete.toLegacyVoiceIntentName(),
        'deleteTransaction',
      );
      expect(
        UnifiedIntentType.navigationPage.toLegacyVoiceIntentName(),
        'navigateToPage',
      );
      expect(
        UnifiedIntentType.conversationConfirm.toLegacyVoiceIntentName(),
        'confirmAction',
      );
    });
  });

  group('OperationTypeMapping', () {
    test('fromLegacyOperationType should convert legacy names', () {
      expect(
        OperationTypeMapping.fromLegacyOperationType('addTransaction'),
        UnifiedIntentType.transactionAdd,
      );
      expect(
        OperationTypeMapping.fromLegacyOperationType('navigate'),
        UnifiedIntentType.navigationPage,
      );
      expect(
        OperationTypeMapping.fromLegacyOperationType('query'),
        UnifiedIntentType.transactionQuery,
      );
      expect(
        OperationTypeMapping.fromLegacyOperationType('modify'),
        UnifiedIntentType.transactionModify,
      );
      expect(
        OperationTypeMapping.fromLegacyOperationType('delete'),
        UnifiedIntentType.transactionDelete,
      );
    });

    test('toLegacyOperationTypeName should convert back', () {
      expect(
        UnifiedIntentType.transactionAdd.toLegacyOperationTypeName(),
        'addTransaction',
      );
      expect(
        UnifiedIntentType.navigationPage.toLegacyOperationTypeName(),
        'navigate',
      );
      expect(
        UnifiedIntentType.transactionQuery.toLegacyOperationTypeName(),
        'query',
      );
    });
  });

  group('UnifiedIntentResult', () {
    test('should create with required fields', () {
      final result = UnifiedIntentResult(
        intentType: UnifiedIntentType.transactionAdd,
        confidence: 0.95,
      );

      expect(result.intentType, UnifiedIntentType.transactionAdd);
      expect(result.confidence, 0.95);
      expect(result.slots, isEmpty);
      expect(result.rawInput, isNull);
    });

    test('should create with all fields', () {
      final result = UnifiedIntentResult(
        intentType: UnifiedIntentType.transactionAdd,
        confidence: 0.85,
        slots: {'amount': 100, 'category': '餐饮'},
        rawInput: '午饭花了100块',
        source: 'llm',
      );

      expect(result.intentType, UnifiedIntentType.transactionAdd);
      expect(result.confidence, 0.85);
      expect(result.slots['amount'], 100);
      expect(result.slots['category'], '餐饮');
      expect(result.rawInput, '午饭花了100块');
      expect(result.source, 'llm');
    });

    test('isHighConfidence should work correctly', () {
      expect(
        UnifiedIntentResult(
          intentType: UnifiedIntentType.transactionAdd,
          confidence: 0.9,
        ).isHighConfidence,
        isTrue,
      );

      expect(
        UnifiedIntentResult(
          intentType: UnifiedIntentType.transactionAdd,
          confidence: 0.7,
        ).isHighConfidence,
        isFalse,
      );
    });

    test('needsConfirmation should consider both intent and confidence', () {
      // High risk + low confidence = needs confirmation
      expect(
        UnifiedIntentResult(
          intentType: UnifiedIntentType.transactionDelete,
          confidence: 0.8,
        ).needsConfirmation,
        isTrue,
      );

      // High risk + high confidence = no confirmation needed
      expect(
        UnifiedIntentResult(
          intentType: UnifiedIntentType.transactionDelete,
          confidence: 0.95,
        ).needsConfirmation,
        isFalse,
      );

      // Low risk = no confirmation needed regardless of confidence
      expect(
        UnifiedIntentResult(
          intentType: UnifiedIntentType.transactionQuery,
          confidence: 0.5,
        ).needsConfirmation,
        isFalse,
      );
    });

    test('toString should include key info', () {
      final result = UnifiedIntentResult(
        intentType: UnifiedIntentType.transactionAdd,
        confidence: 0.95,
        slots: {'amount': 100},
      );

      final str = result.toString();
      expect(str, contains('transaction.add'));
      expect(str, contains('0.95'));
      expect(str, contains('amount'));
    });
  });

  group('IntentCategory', () {
    test('should have all expected categories', () {
      expect(IntentCategory.values.length, 9);
      expect(IntentCategory.values, contains(IntentCategory.transaction));
      expect(IntentCategory.values, contains(IntentCategory.navigation));
      expect(IntentCategory.values, contains(IntentCategory.configuration));
      expect(IntentCategory.values, contains(IntentCategory.data));
      expect(IntentCategory.values, contains(IntentCategory.advanced));
      expect(IntentCategory.values, contains(IntentCategory.automation));
      expect(IntentCategory.values, contains(IntentCategory.conversation));
      expect(IntentCategory.values, contains(IntentCategory.system));
      expect(IntentCategory.values, contains(IntentCategory.unknown));
    });
  });

  group('OperationPriority', () {
    test('should have all expected priorities', () {
      expect(OperationPriority.values.length, 4);
      expect(OperationPriority.values, contains(OperationPriority.immediate));
      expect(OperationPriority.values, contains(OperationPriority.normal));
      expect(OperationPriority.values, contains(OperationPriority.deferred));
      expect(OperationPriority.values, contains(OperationPriority.background));
    });
  });
}
