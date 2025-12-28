import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import '../services/database_service.dart';

class AccountNotifier extends Notifier<List<Account>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<Account> build() {
    _loadAccounts();
    return [];
  }

  Future<void> _loadAccounts() async {
    final accounts = await _db.getAccounts();
    if (accounts.isEmpty) {
      // Initialize with default accounts
      for (final account in DefaultAccounts.accounts) {
        await _db.insertAccount(account);
      }
      state = DefaultAccounts.accounts;
    } else {
      state = accounts;
    }
  }

  Future<void> addAccount(Account account) async {
    await _db.insertAccount(account);
    state = [...state, account];
  }

  Future<void> updateAccount(Account account) async {
    await _db.updateAccount(account);
    state = state.map((a) => a.id == account.id ? account : a).toList();
  }

  Future<void> deleteAccount(String id) async {
    await _db.deleteAccount(id);
    state = state.where((a) => a.id != id).toList();
  }

  Future<void> setDefaultAccount(String id) async {
    for (final account in state) {
      final updated = account.copyWith(isDefault: account.id == id);
      await _db.updateAccount(updated);
    }
    state = state.map((a) => a.copyWith(isDefault: a.id == id)).toList();
  }

  Account? getAccountById(String id) {
    try {
      return state.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  double get totalBalance {
    return state.fold(0.0, (sum, a) => sum + a.balance);
  }

  Future<void> updateBalance(String accountId, double amount, bool isExpense) async {
    final updated = state.map((a) {
      if (a.id == accountId) {
        return a.copyWith(
          balance: isExpense ? a.balance - amount : a.balance + amount,
        );
      }
      return a;
    }).toList();

    for (final account in updated) {
      await _db.updateAccount(account);
    }
    state = updated;
  }

  Future<void> transfer(String fromId, String toId, double amount) async {
    final updated = state.map((a) {
      if (a.id == fromId) {
        return a.copyWith(balance: a.balance - amount);
      }
      if (a.id == toId) {
        return a.copyWith(balance: a.balance + amount);
      }
      return a;
    }).toList();

    for (final account in updated) {
      await _db.updateAccount(account);
    }
    state = updated;
  }
}

final accountProvider =
    NotifierProvider<AccountNotifier, List<Account>>(AccountNotifier.new);

final totalBalanceProvider = Provider<double>((ref) {
  return ref.watch(accountProvider.notifier).totalBalance;
});
