import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/application/coordinators/intent_processing_coordinator.dart';

void main() {
  group('IntentProcessingCoordinator', () {
    late IntentProcessingCoordinator coordinator;
    late _MockIntentRecognizer mockRecognizer;

    setUp(() {
      mockRecognizer = _MockIntentRecognizer();
      coordinator = IntentProcessingCoordinator(
        recognizer: mockRecognizer,
      );
    });

    test('returns failure for empty input', () async {
      final result = await coordinator.process('');

      expect(result.success, isFalse);
      expect(result.errorMessage, '输入为空');
    });

    test('returns failure for whitespace-only input', () async {
      final result = await coordinator.process('   ');

      expect(result.success, isFalse);
      expect(result.errorMessage, '输入为空');
    });

    test('processes valid input and returns success', () async {
      mockRecognizer.nextResult = ProcessedIntent(
        type: IntentType.addTransaction,
        confidence: 0.9,
        entities: {'amount': 100, 'category': '餐饮'},
        originalText: '午餐100元',
      );

      final result = await coordinator.process('午餐100元');

      expect(result.success, isTrue);
      expect(result.intent?.type, IntentType.addTransaction);
      expect(result.intent?.confidence, 0.9);
    });

    test('returns failure for low confidence intent', () async {
      mockRecognizer.nextResult = ProcessedIntent(
        type: IntentType.addTransaction,
        confidence: 0.3,
        entities: {},
        originalText: '嗯嗯',
      );

      final result = await coordinator.process('嗯嗯');

      expect(result.success, isFalse);
    });
  });

  group('ProcessedIntent', () {
    test('confidenceLevel returns correct level', () {
      expect(
        ProcessedIntent(
          type: IntentType.chat,
          confidence: 0.9,
          entities: {},
          originalText: '',
        ).confidenceLevel,
        ConfidenceLevel.high,
      );

      expect(
        ProcessedIntent(
          type: IntentType.chat,
          confidence: 0.6,
          entities: {},
          originalText: '',
        ).confidenceLevel,
        ConfidenceLevel.medium,
      );

      expect(
        ProcessedIntent(
          type: IntentType.chat,
          confidence: 0.3,
          entities: {},
          originalText: '',
        ).confidenceLevel,
        ConfidenceLevel.low,
      );
    });

    test('getEntity returns typed value', () {
      final intent = ProcessedIntent(
        type: IntentType.addTransaction,
        confidence: 0.9,
        entities: {
          'amount': 100.0,
          'category': '餐饮',
          'note': null,
        },
        originalText: '',
      );

      expect(intent.getEntity<double>('amount'), 100.0);
      expect(intent.getEntity<String>('category'), '餐饮');
      expect(intent.getEntity<String>('note'), isNull);
      expect(intent.getEntity<int>('amount'), isNull); // wrong type
    });

    test('isMultiIntent returns true when subIntents exist', () {
      final singleIntent = ProcessedIntent(
        type: IntentType.chat,
        confidence: 0.9,
        entities: {},
        originalText: '',
      );

      final multiIntent = ProcessedIntent(
        type: IntentType.chat,
        confidence: 0.9,
        entities: {},
        originalText: '',
        subIntents: [
          ProcessedIntent(
            type: IntentType.addTransaction,
            confidence: 0.9,
            entities: {},
            originalText: '',
          ),
        ],
      );

      expect(singleIntent.isMultiIntent, isFalse);
      expect(multiIntent.isMultiIntent, isTrue);
    });

    test('copyWith creates modified copy', () {
      final original = ProcessedIntent(
        type: IntentType.chat,
        confidence: 0.5,
        entities: {'key': 'value'},
        originalText: 'original',
      );

      final copy = original.copyWith(
        confidence: 0.9,
        requiresConfirmation: true,
      );

      expect(copy.type, IntentType.chat);
      expect(copy.confidence, 0.9);
      expect(copy.entities, {'key': 'value'});
      expect(copy.originalText, 'original');
      expect(copy.requiresConfirmation, isTrue);
    });
  });

  group('IntentToCommandConverter', () {
    test('converts addTransaction intent to operation data', () {
      final intent = ProcessedIntent(
        type: IntentType.addTransaction,
        confidence: 0.9,
        entities: {
          'amount': 50.0,
          'category': '交通',
          'note': '打车',
        },
        originalText: '打车50元',
      );

      final data = IntentToCommandConverter.toOperationData(intent);

      expect(data, isNotNull);
      expect(data!['type'], 'add_transaction');
      expect(data['params']['amount'], 50.0);
      expect(data['params']['category'], '交通');
      expect(data['params']['note'], '打车');
      expect(data['priority'], 'deferred');
    });

    test('converts navigation intent to operation data', () {
      final intent = ProcessedIntent(
        type: IntentType.navigation,
        confidence: 0.9,
        entities: {
          'target': '统计',
          'route': '/statistics',
        },
        originalText: '打开统计',
      );

      final data = IntentToCommandConverter.toOperationData(intent);

      expect(data, isNotNull);
      expect(data!['type'], 'navigate');
      expect(data['params']['targetPage'], '统计');
      expect(data['params']['route'], '/statistics');
      expect(data['priority'], 'immediate');
    });

    test('converts query intent to operation data', () {
      final intent = ProcessedIntent(
        type: IntentType.queryStatistics,
        confidence: 0.9,
        entities: {
          'queryType': 'summary',
          'time': '本月',
          'category': '餐饮',
        },
        originalText: '本月餐饮花了多少',
      );

      final data = IntentToCommandConverter.toOperationData(intent);

      expect(data, isNotNull);
      expect(data!['type'], 'query');
      expect(data['params']['queryType'], 'summary');
      expect(data['params']['time'], '本月');
      expect(data['params']['category'], '餐饮');
    });

    test('returns null for chat intent', () {
      final intent = ProcessedIntent(
        type: IntentType.chat,
        confidence: 0.9,
        entities: {},
        originalText: '你好',
      );

      final data = IntentToCommandConverter.toOperationData(intent);

      expect(data, isNull);
    });

    test('canConvert returns correct values', () {
      expect(
        IntentToCommandConverter.canConvert(ProcessedIntent(
          type: IntentType.addTransaction,
          confidence: 0.9,
          entities: {},
          originalText: '',
        )),
        isTrue,
      );

      expect(
        IntentToCommandConverter.canConvert(ProcessedIntent(
          type: IntentType.chat,
          confidence: 0.9,
          entities: {},
          originalText: '',
        )),
        isFalse,
      );
    });

    test('toOperationDataList handles multi-intent', () {
      final multiIntent = ProcessedIntent(
        type: IntentType.addTransaction,
        confidence: 0.9,
        entities: {},
        originalText: '早餐10元午餐20元',
        subIntents: [
          ProcessedIntent(
            type: IntentType.addTransaction,
            confidence: 0.9,
            entities: {'amount': 10.0, 'category': '餐饮'},
            originalText: '早餐10元',
          ),
          ProcessedIntent(
            type: IntentType.addTransaction,
            confidence: 0.9,
            entities: {'amount': 20.0, 'category': '餐饮'},
            originalText: '午餐20元',
          ),
        ],
      );

      final operations = IntentToCommandConverter.toOperationDataList(multiIntent);

      expect(operations.length, 2);
      expect(operations[0]['params']['amount'], 10.0);
      expect(operations[1]['params']['amount'], 20.0);
    });
  });

  group('IntentProcessingCoordinator.isIntentComplete', () {
    late IntentProcessingCoordinator coordinator;

    setUp(() {
      coordinator = IntentProcessingCoordinator(
        recognizer: _MockIntentRecognizer(),
      );
    });

    test('addTransaction requires amount and category', () {
      expect(
        coordinator.isIntentComplete(ProcessedIntent(
          type: IntentType.addTransaction,
          confidence: 0.9,
          entities: {'amount': 100, 'category': '餐饮'},
          originalText: '',
        )),
        isTrue,
      );

      expect(
        coordinator.isIntentComplete(ProcessedIntent(
          type: IntentType.addTransaction,
          confidence: 0.9,
          entities: {'amount': 100},
          originalText: '',
        )),
        isFalse,
      );
    });

    test('navigation requires target', () {
      expect(
        coordinator.isIntentComplete(ProcessedIntent(
          type: IntentType.navigation,
          confidence: 0.9,
          entities: {'target': '统计'},
          originalText: '',
        )),
        isTrue,
      );

      expect(
        coordinator.isIntentComplete(ProcessedIntent(
          type: IntentType.navigation,
          confidence: 0.9,
          entities: {},
          originalText: '',
        )),
        isFalse,
      );
    });

    test('query is always complete', () {
      expect(
        coordinator.isIntentComplete(ProcessedIntent(
          type: IntentType.queryStatistics,
          confidence: 0.9,
          entities: {},
          originalText: '',
        )),
        isTrue,
      );
    });
  });

  group('IntentProcessingCoordinator.getMissingEntities', () {
    late IntentProcessingCoordinator coordinator;

    setUp(() {
      coordinator = IntentProcessingCoordinator(
        recognizer: _MockIntentRecognizer(),
      );
    });

    test('returns missing entities for addTransaction', () {
      final missing = coordinator.getMissingEntities(ProcessedIntent(
        type: IntentType.addTransaction,
        confidence: 0.9,
        entities: {},
        originalText: '',
      ));

      expect(missing, contains('amount'));
      expect(missing, contains('category'));
    });

    test('returns empty list when all entities present', () {
      final missing = coordinator.getMissingEntities(ProcessedIntent(
        type: IntentType.addTransaction,
        confidence: 0.9,
        entities: {'amount': 100, 'category': '餐饮'},
        originalText: '',
      ));

      expect(missing, isEmpty);
    });
  });
}

class _MockIntentRecognizer implements IIntentRecognizer {
  ProcessedIntent? nextResult;

  @override
  Future<ProcessedIntent> recognize(String input) async {
    return nextResult ??
        ProcessedIntent(
          type: IntentType.unknown,
          confidence: 0.5,
          entities: {},
          originalText: input,
        );
  }
}
