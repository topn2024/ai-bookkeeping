/// Command Factory
///
/// 根据意图创建对应的 Command 实例。
/// 使用工厂模式封装 Command 的创建逻辑。
library;

import 'package:uuid/uuid.dart';

import '../../domain/commands/commands.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '../../domain/repositories/i_account_repository.dart';

/// Command Factory
///
/// 职责：
/// - 根据意图类型创建对应的 Command
/// - 注入必要的依赖
/// - 生成唯一的命令 ID
class CommandFactory {
  /// UUID 生成器
  final Uuid _uuid;

  /// 交易仓储
  final ITransactionRepository? transactionRepository;

  /// 账户仓储
  final IAccountRepository? accountRepository;

  /// 导航回调
  final INavigationCallback? navigationCallback;

  CommandFactory({
    this.transactionRepository,
    this.accountRepository,
    this.navigationCallback,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// 根据操作数据创建 Command
  ///
  /// [operation] 操作数据，包含:
  /// - type: 操作类型 (add_transaction, delete, modify, navigate, query)
  /// - params: 操作参数
  /// - priority: 优先级 (可选)
  ///
  /// [context] 命令上下文
  IntentCommand? createFromOperation(
    Map<String, dynamic> operation, {
    CommandContext? context,
  }) {
    final type = operation['type'] as String?;
    final params = operation['params'] as Map<String, dynamic>? ?? {};
    final priority = operation['priority'] as String?;

    switch (type) {
      case 'add_transaction':
        return createAddTransactionCommand(params, context: context);

      case 'delete':
      case 'delete_transaction':
        return createDeleteTransactionCommand(params, context: context);

      case 'modify':
      case 'modify_transaction':
        return createModifyTransactionCommand(params, context: context);

      case 'navigate':
        return createNavigateCommand(params, context: context);

      case 'query':
        return createQueryCommand(params, context: context);

      default:
        return null;
    }
  }

  /// 创建添加交易命令
  AddTransactionCommand createAddTransactionCommand(
    Map<String, dynamic> params, {
    CommandContext? context,
  }) {
    _ensureTransactionRepository();

    return AddTransactionCommand(
      id: _generateId(),
      transactionRepository: transactionRepository!,
      accountRepository: accountRepository,
      params: params,
      context: context,
    );
  }

  /// 创建删除交易命令
  DeleteTransactionCommand createDeleteTransactionCommand(
    Map<String, dynamic> params, {
    CommandContext? context,
  }) {
    _ensureTransactionRepository();

    return DeleteTransactionCommand(
      id: _generateId(),
      transactionRepository: transactionRepository!,
      accountRepository: accountRepository,
      params: params,
      context: context,
    );
  }

  /// 创建修改交易命令
  ModifyTransactionCommand createModifyTransactionCommand(
    Map<String, dynamic> params, {
    CommandContext? context,
  }) {
    _ensureTransactionRepository();

    return ModifyTransactionCommand(
      id: _generateId(),
      transactionRepository: transactionRepository!,
      accountRepository: accountRepository,
      params: params,
      context: context,
    );
  }

  /// 创建导航命令
  NavigateCommand createNavigateCommand(
    Map<String, dynamic> params, {
    CommandContext? context,
  }) {
    return NavigateCommand(
      id: _generateId(),
      navigationCallback: navigationCallback,
      params: params,
      context: context,
    );
  }

  /// 创建查询命令
  QueryCommand createQueryCommand(
    Map<String, dynamic> params, {
    CommandContext? context,
  }) {
    _ensureTransactionRepository();

    return QueryCommand(
      id: _generateId(),
      transactionRepository: transactionRepository!,
      params: params,
      context: context,
    );
  }

  /// 批量创建命令
  ///
  /// 从多个操作数据创建多个命令
  List<IntentCommand> createFromOperations(
    List<Map<String, dynamic>> operations, {
    CommandContext? context,
  }) {
    final commands = <IntentCommand>[];

    for (final operation in operations) {
      final command = createFromOperation(operation, context: context);
      if (command != null) {
        commands.add(command);
      }
    }

    return commands;
  }

  /// 生成唯一 ID
  String _generateId() => _uuid.v4();

  /// 确保交易仓储已注入
  void _ensureTransactionRepository() {
    if (transactionRepository == null) {
      throw StateError('TransactionRepository 未注入到 CommandFactory');
    }
  }
}

/// Command Executor
///
/// 职责：
/// - 执行命令
/// - 管理命令历史
/// - 支持撤销操作
class CommandExecutor implements ICommandExecutor {
  /// 命令历史管理器
  final CommandHistoryManager _historyManager;

  /// 最大历史记录数
  final int maxHistorySize;

  CommandExecutor({
    this.maxHistorySize = 50,
  }) : _historyManager = CommandHistoryManager(maxHistorySize: maxHistorySize);

  @override
  List<IntentCommand> get history => _historyManager.history;

  @override
  Future<CommandResult> execute(IntentCommand command) async {
    // 验证命令
    if (!command.validate()) {
      return CommandResult.failure('命令验证失败');
    }

    // 执行命令
    final result = await command.execute();

    // 如果执行成功且可撤销，添加到历史
    if (result.success && result.canUndo) {
      _historyManager.add(command);
    }

    return result;
  }

  /// 批量执行命令
  ///
  /// 按优先级排序后依次执行
  Future<List<CommandResult>> executeAll(List<IntentCommand> commands) async {
    // 按优先级排序
    final sortedCommands = List<IntentCommand>.from(commands)
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));

    final results = <CommandResult>[];

    for (final command in sortedCommands) {
      final result = await execute(command);
      results.add(result);

      // 如果是立即执行的命令失败了，可能需要中断
      if (!result.success && command.priority == CommandPriority.immediate) {
        break;
      }
    }

    return results;
  }

  @override
  Future<CommandResult> undoLast() async {
    final lastUndoable = _historyManager.lastUndoable;

    if (lastUndoable == null) {
      return CommandResult.failure('没有可撤销的操作');
    }

    final result = await lastUndoable.undo();

    if (result.success) {
      _historyManager.remove(lastUndoable);
    }

    return result;
  }

  @override
  void clearHistory() {
    _historyManager.clear();
  }
}

/// Command Pipeline
///
/// 职责：
/// - 管理命令执行流水线
/// - 支持前置和后置处理
/// - 支持命令拦截
class CommandPipeline {
  /// 命令执行器
  final CommandExecutor _executor;

  /// 前置处理器
  final List<CommandInterceptor> _preInterceptors = [];

  /// 后置处理器
  final List<CommandInterceptor> _postInterceptors = [];

  CommandPipeline({CommandExecutor? executor})
      : _executor = executor ?? CommandExecutor();

  /// 添加前置拦截器
  void addPreInterceptor(CommandInterceptor interceptor) {
    _preInterceptors.add(interceptor);
  }

  /// 添加后置拦截器
  void addPostInterceptor(CommandInterceptor interceptor) {
    _postInterceptors.add(interceptor);
  }

  /// 执行命令
  Future<CommandResult> execute(IntentCommand command) async {
    // 前置处理
    for (final interceptor in _preInterceptors) {
      final shouldContinue = await interceptor.intercept(command, null);
      if (!shouldContinue) {
        return CommandResult.failure('命令被拦截器阻止');
      }
    }

    // 执行命令
    final result = await _executor.execute(command);

    // 后置处理
    for (final interceptor in _postInterceptors) {
      await interceptor.intercept(command, result);
    }

    return result;
  }

  /// 撤销最后一个命令
  Future<CommandResult> undoLast() => _executor.undoLast();

  /// 获取历史
  List<IntentCommand> get history => _executor.history;
}

/// 命令拦截器接口
abstract class CommandInterceptor {
  /// 拦截命令
  ///
  /// [command] 要拦截的命令
  /// [result] 命令执行结果（仅后置拦截器有值）
  ///
  /// 返回 true 继续执行，返回 false 中断执行
  Future<bool> intercept(IntentCommand command, CommandResult? result);
}

/// 日志拦截器
class LoggingInterceptor implements CommandInterceptor {
  @override
  Future<bool> intercept(IntentCommand command, CommandResult? result) async {
    if (result == null) {
      // 前置日志
      print('[Command] 开始执行: ${command.type} - ${command.description}');
    } else {
      // 后置日志
      print('[Command] 执行完成: ${command.type} - ${result.success ? "成功" : "失败"}');
    }
    return true;
  }
}

/// 验证拦截器
class ValidationInterceptor implements CommandInterceptor {
  @override
  Future<bool> intercept(IntentCommand command, CommandResult? result) async {
    if (result != null) return true; // 后置拦截器直接放行

    // 前置验证
    if (!command.validate()) {
      print('[Command] 验证失败: ${command.type}');
      return false;
    }
    return true;
  }
}
