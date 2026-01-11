import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/core/base/base_voice_operation_service.dart';

/// 测试用操作类
class TestVoiceOperation implements VoiceOperation {
  @override
  final DateTime timestamp;

  @override
  final bool canUndo;

  @override
  final String description;

  final String data;
  bool undoCalled = false;
  bool undoShouldSucceed;

  TestVoiceOperation({
    required this.data,
    this.canUndo = true,
    this.undoShouldSucceed = true,
    String? description,
    DateTime? timestamp,
  })  : description = description ?? '测试操作: $data',
        timestamp = timestamp ?? DateTime.now();

  @override
  Future<bool> undo() async {
    undoCalled = true;
    return undoShouldSucceed;
  }
}

/// 测试用操作服务类
class TestVoiceOperationService
    extends BaseVoiceOperationService<TestVoiceOperation> {
  List<String> processedCommands = [];

  @override
  Future<dynamic> processCommand(String command) async {
    processedCommands.add(command);

    // 创建并添加操作到历史
    final operation = TestVoiceOperation(data: command);
    addToHistory(operation);

    return {'processed': command};
  }

  @override
  List<RegExp> get patterns => [
        RegExp(r'修改(.+)为(.+)'),
        RegExp(r'删除(.+)'),
      ];

  // 公开 addToHistory 用于测试
  void testAddToHistory(TestVoiceOperation operation) {
    addToHistory(operation);
  }
}

void main() {
  late TestVoiceOperationService service;

  setUp(() {
    service = TestVoiceOperationService();
  });

  group('VoiceOperation 接口', () {
    test('应正确创建操作对象', () {
      final timestamp = DateTime(2024, 1, 1, 10, 30);
      final operation = TestVoiceOperation(
        data: '测试数据',
        canUndo: true,
        description: '自定义描述',
        timestamp: timestamp,
      );

      expect(operation.data, '测试数据');
      expect(operation.canUndo, isTrue);
      expect(operation.description, '自定义描述');
      expect(operation.timestamp, timestamp);
    });

    test('应使用默认描述', () {
      final operation = TestVoiceOperation(data: '数据');
      expect(operation.description, '测试操作: 数据');
    });

    test('undo 应调用并返回结果', () async {
      final operation = TestVoiceOperation(
        data: '数据',
        undoShouldSucceed: true,
      );

      final result = await operation.undo();
      expect(result, isTrue);
      expect(operation.undoCalled, isTrue);
    });

    test('undo 失败应返回 false', () async {
      final operation = TestVoiceOperation(
        data: '数据',
        undoShouldSucceed: false,
      );

      final result = await operation.undo();
      expect(result, isFalse);
    });
  });

  group('BaseVoiceOperationService 会话管理', () {
    test('初始状态应无活跃会话', () {
      expect(service.hasActiveSession, isFalse);
      expect(service.sessionContext, isNull);
    });

    test('startSession 应开始新会话', () {
      service.startSession({'key': 'value'});

      expect(service.hasActiveSession, isTrue);
      expect(service.sessionContext, {'key': 'value'});
    });

    test('startSession 应清空历史记录', () async {
      // 先添加一些历史
      await service.processCommand('命令1');
      await service.processCommand('命令2');
      expect(service.historyCount, 2);

      // 开始新会话
      service.startSession('新会话');
      expect(service.historyCount, 0);
    });

    test('endSession 应结束会话', () {
      service.startSession('会话');
      expect(service.hasActiveSession, isTrue);

      service.endSession();
      expect(service.hasActiveSession, isFalse);
      expect(service.sessionContext, isNull);
    });

    test('startSession 应触发监听器', () {
      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      service.startSession('会话');
      expect(notifyCount, 1);
    });

    test('endSession 应触发监听器', () {
      service.startSession('会话');

      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      service.endSession();
      expect(notifyCount, 1);
    });
  });

  group('BaseVoiceOperationService 历史管理', () {
    test('初始历史应为空', () {
      expect(service.history, isEmpty);
      expect(service.historyCount, 0);
      expect(service.lastOperation, isNull);
    });

    test('addToHistory 应添加操作到历史', () {
      final operation = TestVoiceOperation(data: '操作1');
      service.testAddToHistory(operation);

      expect(service.historyCount, 1);
      expect(service.lastOperation, operation);
    });

    test('历史记录应按添加顺序排列', () {
      final op1 = TestVoiceOperation(data: '操作1');
      final op2 = TestVoiceOperation(data: '操作2');
      final op3 = TestVoiceOperation(data: '操作3');

      service.testAddToHistory(op1);
      service.testAddToHistory(op2);
      service.testAddToHistory(op3);

      expect(service.history[0], op1);
      expect(service.history[1], op2);
      expect(service.history[2], op3);
      expect(service.lastOperation, op3);
    });

    test('历史记录应限制为最大数量', () {
      // 添加超过最大数量的操作
      for (var i = 0; i < BaseVoiceOperationService.maxHistorySize + 5; i++) {
        service.testAddToHistory(TestVoiceOperation(data: '操作$i'));
      }

      expect(service.historyCount, BaseVoiceOperationService.maxHistorySize);
      // 最早的操作应被移除
      expect(service.history.first.data, '操作5');
    });

    test('history 返回的列表应不可修改', () {
      service.testAddToHistory(TestVoiceOperation(data: '操作'));
      final history = service.history;

      expect(() => history.add(TestVoiceOperation(data: '新操作')),
          throwsUnsupportedError);
    });

    test('addToHistory 应触发监听器', () {
      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      service.testAddToHistory(TestVoiceOperation(data: '操作'));
      expect(notifyCount, 1);
    });

    test('clearHistory 应清空历史', () {
      service.testAddToHistory(TestVoiceOperation(data: '操作1'));
      service.testAddToHistory(TestVoiceOperation(data: '操作2'));
      expect(service.historyCount, 2);

      service.clearHistory();
      expect(service.historyCount, 0);
      expect(service.lastOperation, isNull);
    });

    test('clearHistory 应触发监听器', () {
      service.testAddToHistory(TestVoiceOperation(data: '操作'));

      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      service.clearHistory();
      expect(notifyCount, 1);
    });
  });

  group('BaseVoiceOperationService 撤销功能', () {
    test('空历史时 canUndo 应为 false', () {
      expect(service.canUndo, isFalse);
    });

    test('有可撤销操作时 canUndo 应为 true', () {
      service.testAddToHistory(TestVoiceOperation(data: '操作', canUndo: true));
      expect(service.canUndo, isTrue);
    });

    test('最后操作不可撤销时 canUndo 应为 false', () {
      service
          .testAddToHistory(TestVoiceOperation(data: '操作', canUndo: false));
      expect(service.canUndo, isFalse);
    });

    test('undo 空历史应返回 false', () async {
      final result = await service.undo();
      expect(result, isFalse);
    });

    test('undo 不可撤销操作应返回 false', () async {
      service
          .testAddToHistory(TestVoiceOperation(data: '操作', canUndo: false));
      final result = await service.undo();
      expect(result, isFalse);
    });

    test('undo 成功应移除最后操作', () async {
      final op1 = TestVoiceOperation(data: '操作1');
      final op2 = TestVoiceOperation(data: '操作2');
      service.testAddToHistory(op1);
      service.testAddToHistory(op2);

      final result = await service.undo();
      expect(result, isTrue);
      expect(service.historyCount, 1);
      expect(service.lastOperation, op1);
      expect(op2.undoCalled, isTrue);
    });

    test('undo 失败不应移除操作', () async {
      final operation = TestVoiceOperation(
        data: '操作',
        canUndo: true,
        undoShouldSucceed: false,
      );
      service.testAddToHistory(operation);

      final result = await service.undo();
      expect(result, isFalse);
      expect(service.historyCount, 1);
    });

    test('undo 成功应触发监听器', () async {
      service.testAddToHistory(TestVoiceOperation(data: '操作'));

      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.undo();
      expect(notifyCount, 1);
    });

    test('连续 undo 应逐个撤销', () async {
      final op1 = TestVoiceOperation(data: '操作1');
      final op2 = TestVoiceOperation(data: '操作2');
      final op3 = TestVoiceOperation(data: '操作3');
      service.testAddToHistory(op1);
      service.testAddToHistory(op2);
      service.testAddToHistory(op3);

      await service.undo();
      expect(service.lastOperation, op2);

      await service.undo();
      expect(service.lastOperation, op1);

      await service.undo();
      expect(service.lastOperation, isNull);
    });
  });

  group('BaseVoiceOperationService processCommand', () {
    test('应处理命令并添加到历史', () async {
      final result = await service.processCommand('测试命令');

      expect(result, {'processed': '测试命令'});
      expect(service.processedCommands, contains('测试命令'));
      expect(service.historyCount, 1);
    });

    test('应处理多个命令', () async {
      await service.processCommand('命令1');
      await service.processCommand('命令2');
      await service.processCommand('命令3');

      expect(service.processedCommands.length, 3);
      expect(service.historyCount, 3);
    });
  });

  group('BaseVoiceOperationService patterns', () {
    test('应返回正则表达式列表', () {
      expect(service.patterns, hasLength(2));
      expect(service.patterns[0].pattern, r'修改(.+)为(.+)');
      expect(service.patterns[1].pattern, r'删除(.+)');
    });

    test('模式应能匹配命令', () {
      expect(service.patterns[0].hasMatch('修改金额为100'), isTrue);
      expect(service.patterns[0].hasMatch('删除记录'), isFalse);
      expect(service.patterns[1].hasMatch('删除记录'), isTrue);
    });
  });

  group('OperationResult', () {
    test('应正确创建成功结果', () {
      const result = TestOperationResult(success: true, message: '操作成功');

      expect(result.success, isTrue);
      expect(result.message, '操作成功');
    });

    test('应正确创建失败结果', () {
      const result = TestOperationResult(success: false, message: '操作失败');

      expect(result.success, isFalse);
      expect(result.message, '操作失败');
    });

    test('message 可以为 null', () {
      const result = TestOperationResult(success: true);

      expect(result.message, isNull);
    });
  });

  group('maxHistorySize 常量', () {
    test('应为 10', () {
      expect(BaseVoiceOperationService.maxHistorySize, 10);
    });
  });
}

/// 测试用 OperationResult 实现
class TestOperationResult extends OperationResult {
  const TestOperationResult({required super.success, super.message});
}
