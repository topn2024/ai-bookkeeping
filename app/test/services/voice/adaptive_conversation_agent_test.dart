import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/voice/intelligence_engine/adaptive_conversation_agent.dart';
import '../../../lib/services/voice/intelligence_engine/intelligence_engine.dart';
import '../../../lib/services/voice/intelligence_engine/models.dart';
import '../../../lib/services/voice/smart_intent_recognizer.dart';

void main() {
  group('AdaptiveConversationAgent Tests', () {
    late AdaptiveConversationAgent agent;

    setUp(() {
      agent = AdaptiveConversationAgent();
    });

    test('无操作+无疑问词应该检测为chat模式', () {
      final mode = agent.detectMode(
        input: '今天天气真好',
        operations: [],
        chatContent: null,
      );

      expect(mode, ConversationMode.chat);
    });

    test('无操作+有疑问词应该检测为chatWithIntent模式', () {
      final mode = agent.detectMode(
        input: '我这个月还能花多少钱',
        operations: [],
        chatContent: null,
      );

      expect(mode, ConversationMode.chatWithIntent);
    });

    test('多操作+无疑问词应该检测为quickBookkeeping模式', () {
      final operations = [
        Operation(
          type: OperationType.addTransaction,
          priority: OperationPriority.deferred,
          params: {'amount': 35},
          originalText: '打车35',
        ),
        Operation(
          type: OperationType.addTransaction,
          priority: OperationPriority.deferred,
          params: {'amount': 50},
          originalText: '吃饭50',
        ),
      ];

      final mode = agent.detectMode(
        input: '打车35，吃饭50',
        operations: operations,
        chatContent: null,
      );

      expect(mode, ConversationMode.quickBookkeeping);
    });

    test('有操作+有对话内容应该检测为mixed模式', () {
      final operations = [
        Operation(
          type: OperationType.addTransaction,
          priority: OperationPriority.deferred,
          params: {'amount': 35},
          originalText: '打车35',
        ),
      ];

      final mode = agent.detectMode(
        input: '打车35，顺便问一下预算',
        operations: operations,
        chatContent: '顺便问一下预算',
      );

      expect(mode, ConversationMode.mixed);
    });

    test('chat模式应该生成简短响应', () {
      final response = agent.generateTemplateResponse(
        mode: ConversationMode.chat,
        results: [],
        chatContent: null,
      );

      expect(response.length, lessThan(50));
      expect(response, isNotEmpty);
    });

    test('quickBookkeeping模式应该生成极简响应', () {
      final results = [
        ExecutionResult.success(),
        ExecutionResult.success(),
      ];

      final response = agent.generateTemplateResponse(
        mode: ConversationMode.quickBookkeeping,
        results: results,
        chatContent: null,
      );

      expect(response, contains('2'));
      expect(response.length, lessThan(15));
    });

    test('响应长度限制应该正确', () {
      final chatLimit = agent.getLengthLimit(ConversationMode.chat);
      expect(chatLimit.min, 10);
      expect(chatLimit.max, 30);

      final quickLimit = agent.getLengthLimit(ConversationMode.quickBookkeeping);
      expect(quickLimit.min, 5);
      expect(quickLimit.max, 10);

      final intentLimit = agent.getLengthLimit(ConversationMode.chatWithIntent);
      expect(intentLimit.min, 30);
      expect(intentLimit.max, 100);

      final mixedLimit = agent.getLengthLimit(ConversationMode.mixed);
      expect(mixedLimit.min, 20);
      expect(mixedLimit.max, 50);
    });
  });

  group('ConversationMode Tests', () {
    test('对话模式枚举应该包含所有必需模式', () {
      expect(ConversationMode.values.length, 4);
      expect(ConversationMode.values.contains(ConversationMode.chat), true);
      expect(ConversationMode.values.contains(ConversationMode.chatWithIntent), true);
      expect(ConversationMode.values.contains(ConversationMode.quickBookkeeping), true);
      expect(ConversationMode.values.contains(ConversationMode.mixed), true);
    });
  });
}
