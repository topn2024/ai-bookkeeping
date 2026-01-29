/// Add Transaction Command
///
/// 添加交易的命令实现。
/// 支持撤销操作（删除已添加的交易）。
library;

import '../repositories/i_transaction_repository.dart';
import '../repositories/i_account_repository.dart';
import 'intent_command.dart';

/// 添加交易命令
class AddTransactionCommand extends UndoableCommand {
  /// 交易仓储
  final ITransactionRepository transactionRepository;

  /// 账户仓储（用于更新余额）
  final IAccountRepository? accountRepository;

  /// 已创建的交易 ID（用于撤销）
  String? _createdTransactionId;

  AddTransactionCommand({
    required String id,
    required this.transactionRepository,
    this.accountRepository,
    required Map<String, dynamic> params,
    CommandContext? context,
  }) : super(
          id: id,
          type: CommandType.addTransaction,
          priority: CommandPriority.deferred,
          params: params,
          context: context,
        );

  @override
  String get description {
    final amount = params['amount'];
    final category = params['category'] ?? '未分类';
    final note = params['note'] ?? '';
    return '记账: $category ${amount}元${note.isNotEmpty ? " ($note)" : ""}';
  }

  @override
  bool validate() {
    // 必须有金额
    if (!params.containsKey('amount') || params['amount'] == null) {
      return false;
    }

    // 金额必须是数字
    final amount = params['amount'];
    if (amount is! num) {
      return false;
    }

    // 金额必须大于 0
    if (amount <= 0) {
      return false;
    }

    return true;
  }

  @override
  Future<CommandResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      // 验证参数
      if (!validate()) {
        return CommandResult.failure('参数验证失败：缺少金额或金额无效');
      }

      // 构建交易数据
      final transactionData = _buildTransactionData();

      // 创建交易
      final transaction = await transactionRepository.create(transactionData);

      // 保存交易 ID 用于撤销
      _createdTransactionId = transaction.id.toString();

      // 保存撤销状态
      saveUndoState({
        'transactionId': _createdTransactionId,
        'accountId': params['accountId'],
        'amount': params['amount'],
        'type': params['type'] ?? 'expense',
      });

      // 更新账户余额（如果有账户仓储）
      if (accountRepository != null && params['accountId'] != null) {
        final accountId = params['accountId'] as String;
        final amount = (params['amount'] as num).toDouble();
        final isExpense = (params['type'] ?? 'expense') == 'expense';

        if (isExpense) {
          await accountRepository!.updateBalance(accountId, -amount);
        } else {
          await accountRepository!.updateBalance(accountId, amount);
        }
      }

      stopwatch.stop();

      return CommandResult.success(
        data: {
          'transactionId': _createdTransactionId,
          'message': '已记录: ${params['category'] ?? '未分类'} ${params['amount']}元',
        },
        durationMs: stopwatch.elapsedMilliseconds,
        canUndo: true,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult.failure(
        '创建交易失败: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  @override
  Future<CommandResult> undo() async {
    if (_createdTransactionId == null) {
      return CommandResult.failure('无法撤销：没有找到已创建的交易');
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 删除交易
      await transactionRepository.delete(_createdTransactionId!);

      // 恢复账户余额
      final state = undoState;
      if (accountRepository != null && state != null && state['accountId'] != null) {
        final accountId = state['accountId'] as String;
        final amount = (state['amount'] as num).toDouble();
        final isExpense = state['type'] == 'expense';

        // 撤销时反向操作
        if (isExpense) {
          await accountRepository!.updateBalance(accountId, amount);
        } else {
          await accountRepository!.updateBalance(accountId, -amount);
        }
      }

      stopwatch.stop();

      return CommandResult.success(
        data: {
          'message': '已撤销记账',
          'transactionId': _createdTransactionId,
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult.failure(
        '撤销失败: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// 构建交易数据
  Map<String, dynamic> _buildTransactionData() {
    return {
      'amount': (params['amount'] as num).toDouble(),
      'category': params['category'] ?? '其他',
      'type': params['type'] ?? 'expense',
      'note': params['note'] ?? '',
      'merchant': params['merchant'],
      'accountId': params['accountId'],
      'ledgerId': context.ledgerId,
      'transactionDate': params['date'] ?? DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}
