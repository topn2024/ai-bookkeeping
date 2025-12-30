import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recurring_transaction.dart';
import 'base/crud_notifier.dart';
import 'transaction_provider.dart';

/// 定期交易管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class RecurringNotifier extends SimpleCrudNotifier<RecurringTransaction, String> {
  @override
  String get tableName => 'recurring_transactions';

  @override
  String getId(RecurringTransaction entity) => entity.id;

  @override
  Future<List<RecurringTransaction>> fetchAll() => db.getRecurringTransactions();

  @override
  Future<void> insertOne(RecurringTransaction entity) => db.insertRecurringTransaction(entity);

  @override
  Future<void> updateOne(RecurringTransaction entity) => db.updateRecurringTransaction(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteRecurringTransaction(id);

  // ==================== 业务特有方法（保留原有接口）====================

  /// 添加定期交易（带有计算下次执行日期的逻辑）
  Future<void> addRecurring(RecurringTransaction recurring) async {
    // Calculate next execute date
    final updated = recurring.copyWith(
      nextExecuteAt: recurring.calculateNextExecuteDate(),
    );
    await add(updated);
    // 覆盖默认添加行为，使用计算后的 updated 替换原始项
    state = state.map((r) => r.id == recurring.id ? updated : r).toList();
  }

  /// 更新定期交易（保持原有方法名兼容）
  Future<void> updateRecurring(RecurringTransaction recurring) => update(recurring);

  /// 删除定期交易（保持原有方法名兼容）
  Future<void> deleteRecurring(String id) => delete(id);

  /// 切换定期交易启用状态
  Future<void> toggleRecurring(String id) async {
    final recurring = getById(id);
    if (recurring == null) return;
    final updated = recurring.copyWith(isEnabled: !recurring.isEnabled);
    await update(updated);
  }

  /// 获取启用的定期交易
  List<RecurringTransaction> getEnabled() {
    return state.where((r) => r.isEnabled).toList();
  }

  /// 获取待执行的定期交易
  List<RecurringTransaction> getPendingExecution() {
    return state.where((r) => r.isEnabled && r.shouldExecuteToday()).toList();
  }
}

final recurringProvider =
    NotifierProvider<RecurringNotifier, List<RecurringTransaction>>(
        RecurringNotifier.new);

// Service to execute recurring transactions
class RecurringExecutionService {
  Future<int> executeAllPending(
    List<RecurringTransaction> pending,
    TransactionNotifier transactionNotifier,
    RecurringNotifier recurringNotifier,
  ) async {
    int count = 0;

    for (final recurring in pending) {
      // Create transaction
      final transaction = recurring.toTransaction();
      await transactionNotifier.addTransaction(transaction);

      // Update recurring record
      final updated = recurring.copyWith(
        lastExecutedAt: DateTime.now(),
        nextExecuteAt: recurring.calculateNextExecuteDate(),
      );
      await recurringNotifier.updateRecurring(updated);

      count++;
    }

    return count;
  }
}

final recurringExecutionServiceProvider = Provider<RecurringExecutionService>((ref) {
  return RecurringExecutionService();
});
