/// Modify Transaction Command
///
/// 修改交易的命令实现。
/// 支持撤销操作（恢复原始数据）。
library;

import '../repositories/i_transaction_repository.dart';
import '../repositories/i_account_repository.dart';
import 'intent_command.dart';

/// 修改交易命令
class ModifyTransactionCommand extends UndoableCommand {
  /// 交易仓储
  final ITransactionRepository transactionRepository;

  /// 账户仓储（用于调整余额）
  final IAccountRepository? accountRepository;

  /// 原始交易数据（用于撤销）
  Map<String, dynamic>? _originalData;

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
      final originalTransaction = await transactionRepository.findById(transactionId);
      if (originalTransaction == null) {
        return CommandResult.failure('交易不存在: $transactionId');
      }

      // 保存原始数据用于撤销
      _originalData = _transactionToMap(originalTransaction);
      saveUndoState(_originalData!);

      // 构建更新数据
      final updateData = _buildUpdateData();

      // 处理金额变化对账户余额的影响
      if (accountRepository != null && params.containsKey('amount')) {
        await _adjustAccountBalance(
          originalTransaction,
          updateData['amount'] as double?,
        );
      }

      // 更新交易
      await transactionRepository.update(transactionId, updateData);

      stopwatch.stop();

      return CommandResult.success(
        data: {
          'transactionId': transactionId,
          'message': '已修改交易',
          'changes': updateData,
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
    if (_originalData == null) {
      return CommandResult.failure('无法撤销：没有找到原始交易数据');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final transactionId = _originalData!['id'] as String;

      // 获取当前数据以计算余额差异
      final currentTransaction = await transactionRepository.findById(transactionId);

      // 恢复原始数据
      final restoreData = Map<String, dynamic>.from(_originalData!);
      restoreData.remove('id'); // ID 不需要更新

      await transactionRepository.update(transactionId, restoreData);

      // 恢复账户余额
      if (accountRepository != null && currentTransaction != null) {
        await _adjustAccountBalance(
          currentTransaction,
          _originalData!['amount'] as double?,
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

  /// 构建更新数据
  Map<String, dynamic> _buildUpdateData() {
    final updateData = <String, dynamic>{};

    if (params.containsKey('amount')) {
      updateData['amount'] = (params['amount'] as num).toDouble();
    }
    if (params.containsKey('category')) {
      updateData['category'] = params['category'];
    }
    if (params.containsKey('note')) {
      updateData['note'] = params['note'];
    }
    if (params.containsKey('merchant')) {
      updateData['merchant'] = params['merchant'];
    }
    if (params.containsKey('date')) {
      updateData['transactionDate'] = params['date'];
    }
    if (params.containsKey('type')) {
      updateData['type'] = params['type'];
    }

    updateData['updatedAt'] = DateTime.now().toIso8601String();

    return updateData;
  }

  /// 调整账户余额
  Future<void> _adjustAccountBalance(
    dynamic originalTransaction,
    double? newAmount,
  ) async {
    if (accountRepository == null) return;

    final accountId = _getAccountId(originalTransaction);
    if (accountId == null) return;

    final originalAmount = _getAmount(originalTransaction);
    final isExpense = _getType(originalTransaction) == 'expense';

    if (newAmount != null && originalAmount != newAmount) {
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

  /// 将交易对象转换为 Map
  Map<String, dynamic> _transactionToMap(dynamic transaction) {
    if (transaction is Map<String, dynamic>) {
      return Map<String, dynamic>.from(transaction);
    }

    try {
      return (transaction as dynamic).toJson() as Map<String, dynamic>;
    } catch (_) {
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

  String? _getAccountId(dynamic transaction) {
    if (transaction is Map) return transaction['accountId'] as String?;
    try {
      return transaction.accountId as String?;
    } catch (_) {
      return null;
    }
  }

  double _getAmount(dynamic transaction) {
    if (transaction is Map) return (transaction['amount'] as num).toDouble();
    try {
      return (transaction.amount as num).toDouble();
    } catch (_) {
      return 0;
    }
  }

  String _getType(dynamic transaction) {
    if (transaction is Map) return transaction['type'] as String? ?? 'expense';
    try {
      return transaction.type as String? ?? 'expense';
    } catch (_) {
      return 'expense';
    }
  }
}
