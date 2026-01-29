/// Modify Transaction Command
///
/// 修改交易的命令实现。
/// 支持撤销操作（恢复原始数据）。
library;

import '../../models/transaction.dart';
import '../repositories/i_transaction_repository.dart';
import '../repositories/i_account_repository.dart';
import 'intent_command.dart';

/// 修改交易命令
class ModifyTransactionCommand extends UndoableCommand {
  /// 交易仓储
  final ITransactionRepository transactionRepository;

  /// 账户仓储（用于调整余额）
  final IAccountRepository? accountRepository;

  /// 原始交易（用于撤销）
  Transaction? _originalTransaction;

  ModifyTransactionCommand({
    required String id,
    required this.transactionRepository,
    this.accountRepository,
    required Map<String, dynamic> params,
    CommandContext? context,
  }) : super(
          id: id,
          type: CommandType.modifyTransaction,
          priority: CommandPriority.normal,
          params: params,
          context: context,
        );

  @override
  String get description {
    final transactionId = params['transactionId'];
    final changes = <String>[];
    if (params.containsKey('amount')) changes.add('金额');
    if (params.containsKey('category')) changes.add('分类');
    if (params.containsKey('note')) changes.add('备注');
    return '修改交易 $transactionId: ${changes.join(", ")}';
  }

  @override
  bool validate() {
    // 必须有交易 ID
    if (!params.containsKey('transactionId') || params['transactionId'] == null) {
      return false;
    }

    // 必须有至少一个要修改的字段
    final modifiableFields = ['amount', 'category', 'note', 'merchant', 'date', 'type'];
    return modifiableFields.any((field) => params.containsKey(field));
  }

  @override
  Future<CommandResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      // 验证参数
      if (!validate()) {
        return CommandResult.failure('参数验证失败：缺少交易ID或修改内容');
      }

      final transactionId = params['transactionId'] as String;

      // 获取原始交易数据
      _originalTransaction = await transactionRepository.findById(transactionId);
      if (_originalTransaction == null) {
        return CommandResult.failure('交易不存在: $transactionId');
      }

      // 保存原始数据用于撤销
      saveUndoState(_originalTransaction!.toMap());

      // 构建更新后的交易实体
      final updatedTransaction = _buildUpdatedTransaction(_originalTransaction!);

      // 处理金额变化对账户余额的影响
      if (accountRepository != null && params.containsKey('amount')) {
        await _adjustAccountBalance(
          _originalTransaction!,
          updatedTransaction.amount,
        );
      }

      // 更新交易
      await transactionRepository.update(updatedTransaction);

      stopwatch.stop();

      return CommandResult.success(
        data: {
          'transactionId': transactionId,
          'message': '已修改交易',
        },
        durationMs: stopwatch.elapsedMilliseconds,
        canUndo: true,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult.failure(
        '修改交易失败: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  @override
  Future<CommandResult> undo() async {
    if (_originalTransaction == null) {
      return CommandResult.failure('无法撤销：没有找到原始交易数据');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final transactionId = _originalTransaction!.id;

      // 获取当前数据以计算余额差异
      final currentTransaction = await transactionRepository.findById(transactionId);

      // 恢复原始数据
      await transactionRepository.update(_originalTransaction!);

      // 恢复账户余额
      if (accountRepository != null && currentTransaction != null) {
        await _adjustAccountBalance(
          currentTransaction,
          _originalTransaction!.amount,
        );
      }

      stopwatch.stop();

      return CommandResult.success(
        data: {
          'message': '已恢复交易原始数据',
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

  /// 构建更新后的交易实体
  Transaction _buildUpdatedTransaction(Transaction original) {
    TransactionType? newType;
    if (params.containsKey('type')) {
      final typeStr = params['type'] as String;
      newType = typeStr == 'income'
          ? TransactionType.income
          : typeStr == 'transfer'
              ? TransactionType.transfer
              : TransactionType.expense;
    }

    DateTime? newDate;
    if (params.containsKey('date')) {
      newDate = DateTime.parse(params['date'] as String);
    }

    return original.copyWith(
      amount: params.containsKey('amount')
          ? (params['amount'] as num).toDouble()
          : null,
      category: params['category'] as String?,
      note: params['note'] as String?,
      type: newType,
      date: newDate,
    );
  }

  /// 调整账户余额
  Future<void> _adjustAccountBalance(
    Transaction originalTransaction,
    double newAmount,
  ) async {
    if (accountRepository == null) return;

    final accountId = originalTransaction.accountId;
    final originalAmount = originalTransaction.amount;
    final isExpense = originalTransaction.type == TransactionType.expense;

    if (originalAmount != newAmount) {
      final difference = newAmount - originalAmount;

      if (isExpense) {
        // 支出增加，余额减少
        await accountRepository!.updateBalance(accountId, -difference);
      } else {
        // 收入增加，余额增加
        await accountRepository!.updateBalance(accountId, difference);
      }
    }
  }
}
