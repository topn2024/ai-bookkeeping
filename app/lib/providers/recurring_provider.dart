import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recurring_transaction.dart';
import '../services/database_service.dart';
import 'transaction_provider.dart';

class RecurringNotifier extends Notifier<List<RecurringTransaction>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<RecurringTransaction> build() {
    _loadRecurringTransactions();
    return [];
  }

  Future<void> _loadRecurringTransactions() async {
    final items = await _db.getRecurringTransactions();
    state = items;
  }

  Future<void> addRecurring(RecurringTransaction recurring) async {
    // Calculate next execute date
    final updated = recurring.copyWith(
      nextExecuteAt: recurring.calculateNextExecuteDate(),
    );
    await _db.insertRecurringTransaction(updated);
    state = [...state, updated];
  }

  Future<void> updateRecurring(RecurringTransaction recurring) async {
    await _db.updateRecurringTransaction(recurring);
    state = state.map((r) => r.id == recurring.id ? recurring : r).toList();
  }

  Future<void> deleteRecurring(String id) async {
    await _db.deleteRecurringTransaction(id);
    state = state.where((r) => r.id != id).toList();
  }

  Future<void> toggleRecurring(String id) async {
    final recurring = state.firstWhere((r) => r.id == id);
    final updated = recurring.copyWith(isEnabled: !recurring.isEnabled);
    await updateRecurring(updated);
  }

  RecurringTransaction? getById(String id) {
    try {
      return state.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  List<RecurringTransaction> getEnabled() {
    return state.where((r) => r.isEnabled).toList();
  }

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
