/// Delete Transaction Command
///
/// 删除交易的命令实现。
/// 支持撤销操作（恢复已删除的交易）。
library;

import '../repositories/i_transaction_repository.dart';
import '../repositories/i_account_repository.dart';
import 'intent_command.dart';

/// 删除交易命令
class DeleteTransactionCommand extends UndoableCommand {
  /// 交易仓储
  final ITransactionRepository transactionRepository;

  /// 账户仓储（用于恢复余额）
  final IAccountRepository? accountRepository;

  /// 已删除的交易数据（用于撤销恢复）
  Map<String, dynamic>? _deletedTransactionData;

  DeleteTransactionCommand({
    required String id,
    required this.transactionRepository,
    this.accountRepository,
    required Map<String, dynamic> params,
    CommandContext? context,
  }) : super(
          id: id,
          type: CommandType.deleteTransaction,
          priority: CommandPriority.normal,
          params: params,
          context: context,
        );

  @override
  String get description {
    final transactionId = params['transactionId'];
    return '删除交易: $transactionId';
  }

  @override
  bool validate() {
    // 必须有交易 ID
    return params.containsKey('transactionId') &&
        params['transactionId'] != null;
  }

  @override
  Future<CommandResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      // 验证参数
      if (!validate()) {
        return CommandResult.failure('参数验证失败：缺少交易ID');
      }

      final transactionId = params['transactionId'] as String;

      // 先获取交易数据用于撤销
      final transaction = await transactionRepository.findById(transactionId);
      if (transaction == null) {
        return CommandResult.failure('交易不存在: $transactionId');
      }

      // 保存交易数据用于撤销
      _deletedTransactionData = _transactionToMap(transaction);

      // 保存撤销状态
      saveUndoState(_deletedTransactionData!);

      // 使用软删除
      final useSoftDelete = params['softDelete'] ?? true;
      if (useSoftDelete) {
        await transactionRepository.softDelete(transactionId);
      } else {
        await transactionRepository.delete(transactionId);
      }

      // 恢复账户余额
      if (accountRepository != null && _deletedTransactionData!['accountId'] != null) {
        final accountId = _deletedTransactionData!['accountId'] as String;
        final amount = (_deletedTransactionData!['amount'] as num).toDouble();
        final isExpense = _deletedTransactionData!['type'] == 'expense';

        // 删除时反向操作余额
        if (isExpense) {
          await accountRepository!.updateBalance(accountId, amount);
        } else {
          await accountRepository!.updateBalance(accountId, -amount);
        }
      }

      stopwatch.stop();

      return CommandResult.success(
        data: {
          'transactionId': transactionId,
          'message': '已删除交易',
          'softDelete': useSoftDelete,
        },
        durationMs: stopwatch.elapsedMilliseconds,
        canUndo: useSoftDelete,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult.failure(
        '删除交易失败: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  @override
  Future<CommandResult> undo() async {
    if (_deletedTransactionData == null) {
      return CommandResult.failure('无法撤销：没有找到已删除的交易数据');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final transactionId = _deletedTransactionData!['id'] as String;

      // 恢复交易（取消软删除）
      await transactionRepository.restore(transactionId);

      // 恢复账户余额
      if (accountRepository != null && _deletedTransactionData!['accountId'] != null) {
        final accountId = _deletedTransactionData!['accountId'] as String;
        final amount = (_deletedTransactionData!['amount'] as num).toDouble();
        final isExpense = _deletedTransactionData!['type'] == 'expense';

        // 恢复时正向操作余额
        if (isExpense) {
          await accountRepository!.updateBalance(accountId, -amount);
        } else {
          await accountRepository!.updateBalance(accountId, amount);
        }
      }

      stopwatch.stop();

      return CommandResult.success(
        data: {
          'message': '已恢复交易',
          'transactionId': transactionId,
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult.failure(
        '恢复交易失败: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// 将交易对象转换为 Map
  Map<String, dynamic> _transactionToMap(dynamic transaction) {
    // 根据实际 Transaction 类型实现
    // 这里假设 transaction 有 toJson 方法或必要的属性
    if (transaction is Map<String, dynamic>) {
      return Map<String, dynamic>.from(transaction);
    }

    // 如果有 toJson 方法
    try {
      return (transaction as dynamic).toJson() as Map<String, dynamic>;
    } catch (_) {
      // 回退：手动提取属性
      return {
        'id': transaction.id?.toString(),
        'amount': transaction.amount,
        'category': transaction.category,
        'type': transaction.type,
        'note': transaction.note,
        'merchant': transaction.merchant,
        'accountId': transaction.accountId,
        'ledgerId': transaction.ledgerId,
        'transactionDate': transaction.transactionDate?.toIso8601String(),
      };
    }
  }
}
