import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/domain/commands/commands.dart';

void main() {
  group('CommandResult', () {
    test('success factory creates successful result', () {
      final result = CommandResult.success(
        data: {'key': 'value'},
        durationMs: 100,
        canUndo: true,
      );

      expect(result.success, isTrue);
      expect(result.data, {'key': 'value'});
      expect(result.durationMs, 100);
      expect(result.canUndo, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('failure factory creates failed result', () {
      final result = CommandResult.failure('Error message', durationMs: 50);

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Error message');
      expect(result.durationMs, 50);
      expect(result.canUndo, isFalse);
    });
  });

  group('CommandContext', () {
    test('creates context with default values', () {
      const context = CommandContext();

      expect(context.userId, isNull);
      expect(context.ledgerId, isNull);
      expect(context.extras, isEmpty);
    });

    test('copyWith creates modified copy', () {
      const original = CommandContext(
        userId: 'user1',
        ledgerId: 'ledger1',
      );

      final copy = original.copyWith(ledgerId: 'ledger2');

      expect(copy.userId, 'user1');
      expect(copy.ledgerId, 'ledger2');
    });
  });

  group('CommandHistoryManager', () {
    test('adds command to history', () {
      final manager = CommandHistoryManager(maxHistorySize: 10);
      final command = _TestCommand();

      manager.add(command);

      expect(manager.history, contains(command));
      expect(manager.history.length, 1);
    });

    test('trims history when exceeding max size', () {
      final manager = CommandHistoryManager(maxHistorySize: 3);

      for (int i = 0; i < 5; i++) {
        manager.add(_TestCommand(id: 'cmd_$i'));
      }

      expect(manager.history.length, 3);
      expect(manager.history.first.id, 'cmd_2');
      expect(manager.history.last.id, 'cmd_4');
    });

    test('lastUndoable returns last undoable command', () async {
      final manager = CommandHistoryManager();
      final undoableCmd = _UndoableTestCommand();
      final normalCmd = _TestCommand();

      // Execute to save undo state
      await undoableCmd.execute();

      manager.add(undoableCmd);
      manager.add(normalCmd);

      expect(manager.lastUndoable, undoableCmd);
    });

    test('clear removes all commands', () {
      final manager = CommandHistoryManager();
      manager.add(_TestCommand());
      manager.add(_TestCommand());

      manager.clear();

      expect(manager.history, isEmpty);
    });
  });
}

class _TestCommand extends IntentCommand {
  _TestCommand({String? id})
      : super(
          id: id ?? 'test_cmd',
          type: CommandType.unknown,
        );

  @override
  String get description => 'Test command';

  @override
  Future<CommandResult> execute() async {
    return CommandResult.success();
  }
}

class _UndoableTestCommand extends UndoableCommand {
  _UndoableTestCommand()
      : super(
          id: 'undoable_cmd',
          type: CommandType.addTransaction,
        );

  @override
  String get description => 'Undoable test command';

  @override
  Future<CommandResult> execute() async {
    saveUndoState({'executed': true});
    return CommandResult.success(canUndo: true);
  }

  @override
  Future<CommandResult> undo() async {
    return CommandResult.success();
  }
}
