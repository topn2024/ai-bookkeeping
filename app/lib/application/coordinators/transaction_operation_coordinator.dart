/// Transaction Operation Coordinator
///
/// 负责交易CRUD操作的协调器，从VoiceServiceCoordinator中提取。
/// 遵循单一职责原则，仅处理交易相关的业务逻辑。
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/transaction.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '../../domain/repositories/i_account_repository.dart';

/// 交易操作结果
class TransactionOperationResult {
  final bool success;
  final String? transactionId;
  final String message;
  final Transaction? transaction;
  final Object? error;

  const TransactionOperationResult._({
    required this.success,
    this.transactionId,
    required this.message,
    this.transaction,
    this.error,
  });

  factory TransactionOperationResult.success({
    required String transactionId,
    required String message,
    Transaction? transaction,
  }) {
    return TransactionOperationResult._(
      success: true,
      transactionId: transactionId,
      message: message,
      transaction: transaction,
    );
  }

  factory TransactionOperationResult.failure({
    required String message,
    Object? error,
  }) {
    return TransactionOperationResult._(
      success: false,
      message: message,
      error: error,
    );
  }
}

/// 创建交易的参数
class CreateTransactionParams {
  final TransactionType type;
  final double amount;
  final String category;
  final String? subcategory;
  final String? note;
  final DateTime? date;
  final String accountId;
  final String? toAccountId;
  final TransactionSource source;
  final String? vaultId;
  final List<String>? tags;

  const CreateTransactionParams({
    required this.type,
    required this.amount,
    required this.category,
    this.subcategory,
    this.note,
    this.date,
    required this.accountId,
    this.toAccountId,
    this.source = TransactionSource.voice,
    this.vaultId,
    this.tags,
  });
}

/// 交易操作协调器
///
/// 负责处理所有交易相关的业务操作：
/// - 创建交易
/// - 更新交易
/// - 删除交易
/// - 批量操作
/// - 账户余额同步
class TransactionOperationCoordinator {
  final ITransactionRepository _transactionRepository;
  final IAccountRepository _accountRepository;
  final _uuid = const Uuid();

  TransactionOperationCoordinator({
    required ITransactionRepository transactionRepository,
    required IAccountRepository accountRepository,
  })  : _transactionRepository = transactionRepository,
        _accountRepository = accountRepository;

  /// 创建交易
  ///
  /// 自动同步账户余额
  Future<TransactionOperationResult> createTransaction(
    CreateTransactionParams params,
  ) async {
    try {
      debugPrint('[TransactionCoordinator] 创建交易: ${params.category} ${params.amount}');

      // 生成交易ID
      final transactionId = _uuid.v4();

      // 创建交易对象
      final transaction = Transaction(
        id: transactionId,
        type: params.type,
        amount: params.amount,
        category: params.category,
        subcategory: params.subcategory,
        note: params.note,
        date: params.date ?? DateTime.now(),
        accountId: params.accountId,
        toAccountId: params.toAccountId,
        source: params.source,
        vaultId: params.vaultId,
        tags: params.tags,
      );

      // 插入交易并更新余额（伪原子操作，失败时回滚）
      try {
        await _transactionRepository.insert(transaction);
        await _updateAccountBalance(transaction);
      } catch (e) {
        // 回滚：删除已插入的交易
        debugPrint('[TransactionCoordinator] 余额更新失败，回滚交易插入: $e');
        try {
          await _transactionRepository.delete(transaction.id);
        } catch (_) {}
        rethrow;
      }

      debugPrint('[TransactionCoordinator] 交易创建成功: $transactionId');

      return TransactionOperationResult.success(
        transactionId: transactionId,
        message: '交易创建成功',
        transaction: transaction,
      );
    } catch (e) {
      debugPrint('[TransactionCoordinator] 创建交易失败: $e');
      return TransactionOperationResult.failure(
        message: '创建交易失败: $e',
        error: e,
      );
    }
  }

  /// 更新交易
  ///
  /// 自动处理账户余额差异
  Future<TransactionOperationResult> updateTransaction(
    Transaction transaction,
  ) async {
    try {
      debugPrint('[TransactionCoordinator] 更新交易: ${transaction.id}');

      // 获取原交易
      final originalTransaction = await _transactionRepository.findById(transaction.id);
      if (originalTransaction == null) {
        return TransactionOperationResult.failure(
          message: '交易不存在',
        );
      }

      // 回滚原交易的账户余额影响、更新交易、应用新余额（伪原子操作，失败时回滚）
      try {
        await _reverseAccountBalance(originalTransaction);

        try {
          await _transactionRepository.update(transaction);
        } catch (e) {
          // 回滚：恢复原交易的余额影响
          debugPrint('[TransactionCoordinator] 交易更新失败，恢复原余额: $e');
          try {
            await _updateAccountBalance(originalTransaction);
          } catch (_) {}
          rethrow;
        }

        try {
          await _updateAccountBalance(transaction);
        } catch (e) {
          // 回滚：恢复原交易数据和余额
          debugPrint('[TransactionCoordinator] 新余额更新失败，回滚交易: $e');
          try {
            await _transactionRepository.update(originalTransaction);
            await _updateAccountBalance(originalTransaction);
          } catch (_) {}
          rethrow;
        }
      } catch (e) {
        debugPrint('[TransactionCoordinator] 更新交易操作失败: $e');
        rethrow;
      }

      debugPrint('[TransactionCoordinator] 交易更新成功: ${transaction.id}');

      return TransactionOperationResult.success(
        transactionId: transaction.id,
        message: '交易更新成功',
        transaction: transaction,
      );
    } catch (e) {
      debugPrint('[TransactionCoordinator] 更新交易失败: $e');
      return TransactionOperationResult.failure(
        message: '更新交易失败: $e',
        error: e,
      );
    }
  }

  /// 删除交易
  ///
  /// 自动恢复账户余额
  Future<TransactionOperationResult> deleteTransaction(String transactionId) async {
    try {
      debugPrint('[TransactionCoordinator] 删除交易: $transactionId');

      // 获取交易
      final transaction = await _transactionRepository.findById(transactionId);
      if (transaction == null) {
        return TransactionOperationResult.failure(
          message: '交易不存在',
        );
      }

      // 删除交易并回滚余额（伪原子操作，失败时回滚）
      try {
        await _transactionRepository.delete(transactionId);
        await _reverseAccountBalance(transaction);
      } catch (e) {
        // 回滚：恢复已删除的交易
        debugPrint('[TransactionCoordinator] 余额回滚失败，恢复已删除交易: $e');
        try {
          await _transactionRepository.insert(transaction);
        } catch (_) {}
        rethrow;
      }

      debugPrint('[TransactionCoordinator] 交易删除成功: $transactionId');

      return TransactionOperationResult.success(
        transactionId: transactionId,
        message: '交易删除成功',
      );
    } catch (e) {
      debugPrint('[TransactionCoordinator] 删除交易失败: $e');
      return TransactionOperationResult.failure(
        message: '删除交易失败: $e',
        error: e,
      );
    }
  }

  /// 软删除交易
  Future<TransactionOperationResult> softDeleteTransaction(String transactionId) async {
    try {
      final transaction = await _transactionRepository.findById(transactionId);
      if (transaction == null) {
        return TransactionOperationResult.failure(message: '交易不存在');
      }

      await _reverseAccountBalance(transaction);
      await _transactionRepository.softDelete(transactionId);

      return TransactionOperationResult.success(
        transactionId: transactionId,
        message: '交易已移入回收站',
      );
    } catch (e) {
      return TransactionOperationResult.failure(
        message: '删除失败: $e',
        error: e,
      );
    }
  }

  /// 恢复软删除的交易
  Future<TransactionOperationResult> restoreTransaction(String transactionId) async {
    try {
      // TODO: ITransactionRepository.findById 会过滤已软删除记录，
      // 应添加 findById(id, {includeDeleted}) 方法以避免加载全部交易。
      // 当前使用 findAll(includeDeleted: true) 是临时方案，数据量大时有性能问题。
      final transaction = await _transactionRepository
          .findAll(includeDeleted: true)
          .then((list) => list.where((t) => t.id == transactionId).firstOrNull);

      if (transaction == null) {
        return TransactionOperationResult.failure(message: '交易不存在');
      }

      await _transactionRepository.restore(transactionId);
      await _updateAccountBalance(transaction);

      return TransactionOperationResult.success(
        transactionId: transactionId,
        message: '交易已恢复',
        transaction: transaction,
      );
    } catch (e) {
      return TransactionOperationResult.failure(
        message: '恢复失败: $e',
        error: e,
      );
    }
  }

  /// 批量创建交易
  Future<TransactionOperationResult> batchCreateTransactions(
    List<CreateTransactionParams> paramsList,
  ) async {
    if (paramsList.isEmpty) {
      return TransactionOperationResult.success(
        transactionId: '',
        message: '批量创建成功，共 0 笔交易',
      );
    }

    try {
      final transactions = <Transaction>[];

      for (final params in paramsList) {
        final transaction = Transaction(
          id: _uuid.v4(),
          type: params.type,
          amount: params.amount,
          category: params.category,
          subcategory: params.subcategory,
          note: params.note,
          date: params.date ?? DateTime.now(),
          accountId: params.accountId,
          toAccountId: params.toAccountId,
          source: params.source,
          vaultId: params.vaultId,
          tags: params.tags,
        );
        transactions.add(transaction);
      }

      await _transactionRepository.insertAll(transactions);

      // 批量更新账户余额
      for (final transaction in transactions) {
        await _updateAccountBalance(transaction);
      }

      return TransactionOperationResult.success(
        transactionId: transactions.first.id,
        message: '批量创建成功，共 ${transactions.length} 笔交易',
      );
    } catch (e) {
      return TransactionOperationResult.failure(
        message: '批量创建失败: $e',
        error: e,
      );
    }
  }

  // ==================== 私有方法 ====================

  /// 更新账户余额（根据交易类型）
  Future<void> _updateAccountBalance(Transaction transaction) async {
    switch (transaction.type) {
      case TransactionType.expense:
        await _accountRepository.decreaseBalance(
          transaction.accountId,
          transaction.amount,
        );
        break;
      case TransactionType.income:
        await _accountRepository.increaseBalance(
          transaction.accountId,
          transaction.amount,
        );
        break;
      case TransactionType.transfer:
        if (transaction.toAccountId != null) {
          await _accountRepository.transfer(
            transaction.accountId,
            transaction.toAccountId!,
            transaction.amount,
          );
        }
        break;
    }
  }

  /// 回滚账户余额（删除/更新交易时使用）
  Future<void> _reverseAccountBalance(Transaction transaction) async {
    switch (transaction.type) {
      case TransactionType.expense:
        // 回滚支出 = 增加余额
        await _accountRepository.increaseBalance(
          transaction.accountId,
          transaction.amount,
        );
        break;
      case TransactionType.income:
        // 回滚收入 = 减少余额
        await _accountRepository.decreaseBalance(
          transaction.accountId,
          transaction.amount,
        );
        break;
      case TransactionType.transfer:
        if (transaction.toAccountId != null) {
          // 回滚转账 = 反向转账
          await _accountRepository.transfer(
            transaction.toAccountId!,
            transaction.accountId,
            transaction.amount,
          );
        }
        break;
    }
  }
}
