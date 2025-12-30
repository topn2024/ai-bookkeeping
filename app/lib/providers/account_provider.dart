import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import '../models/currency.dart';
import '../models/exchange_rate.dart';
import 'base/crud_notifier.dart';
import 'currency_provider.dart';

/// 账户管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class AccountNotifier extends SimpleCrudNotifier<Account, String> {
  @override
  String get tableName => 'accounts';

  @override
  String getId(Account entity) => entity.id;

  @override
  Future<List<Account>> fetchAll() async {
    final accounts = await db.getAccounts();
    if (accounts.isEmpty) {
      // Initialize with default accounts
      for (final account in DefaultAccounts.accounts) {
        await db.insertAccount(account);
      }
      return DefaultAccounts.accounts;
    }
    return accounts;
  }

  @override
  Future<void> insertOne(Account entity) => db.insertAccount(entity);

  @override
  Future<void> updateOne(Account entity) => db.updateAccount(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteAccount(id);

  // ==================== 业务特有方法（保留原有接口）====================

  /// 添加账户（保持原有方法名兼容）
  Future<void> addAccount(Account account) => add(account);

  /// 更新账户（保持原有方法名兼容）
  Future<void> updateAccount(Account account) => update(account);

  /// 删除账户（保持原有方法名兼容）
  Future<void> deleteAccount(String id) => delete(id);

  Future<void> setDefaultAccount(String id) async {
    for (final account in state) {
      final updated = account.copyWith(isDefault: account.id == id);
      await db.updateAccount(updated);
    }
    state = state.map((a) => a.copyWith(isDefault: a.id == id)).toList();
  }

  /// 根据ID获取账户（使用基类方法）
  Account? getAccountById(String id) => getById(id);

  /// 获取单一货币总余额（不进行汇率转换）
  double get totalBalance {
    return state.fold(0.0, (sum, a) => sum + a.balance);
  }

  /// 获取多币种余额汇总
  MultiCurrencyAmount get multiCurrencyBalance {
    var total = const MultiCurrencyAmount({});
    for (final account in state) {
      total = total.add(account.currency, account.balance);
    }
    return total;
  }

  /// 按货币分组获取余额
  Map<CurrencyType, double> get balanceByCurrency {
    final result = <CurrencyType, double>{};
    for (final account in state) {
      result[account.currency] = (result[account.currency] ?? 0) + account.balance;
    }
    return result;
  }

  /// 获取使用特定货币的账户
  List<Account> getAccountsByCurrency(CurrencyType currency) {
    return state.where((a) => a.currency == currency).toList();
  }

  /// 获取所有使用的货币类型
  List<CurrencyType> get usedCurrencies {
    return state.map((a) => a.currency).toSet().toList();
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
      await db.updateAccount(account);
    }
    state = updated;
  }

  /// 转账（使用事务保证原子性）
  Future<void> transfer(String fromId, String toId, double amount) async {
    final fromAccount = getById(fromId);
    final toAccount = getById(toId);
    if (fromAccount == null || toAccount == null) return;

    final updatedFrom = fromAccount.copyWith(balance: fromAccount.balance - amount);
    final updatedTo = toAccount.copyWith(balance: toAccount.balance + amount);

    // 使用事务确保两个更新都成功或都失败
    await db.runInTransaction(() async {
      await db.updateAccount(updatedFrom);
      await db.updateAccount(updatedTo);
    });

    state = state.map((a) {
      if (a.id == fromId) return updatedFrom;
      if (a.id == toId) return updatedTo;
      return a;
    }).toList();
  }

  /// 跨币种转账（带汇率转换，使用事务保证原子性）
  Future<void> transferWithConversion(
    String fromId,
    String toId,
    double fromAmount,
    double exchangeRate,
  ) async {
    final fromAccount = getById(fromId);
    final toAccount = getById(toId);
    if (fromAccount == null || toAccount == null) return;

    final toAmount = fromAmount * exchangeRate;
    final updatedFrom = fromAccount.copyWith(balance: fromAccount.balance - fromAmount);
    final updatedTo = toAccount.copyWith(balance: toAccount.balance + toAmount);

    // 使用事务确保两个更新都成功或都失败
    await db.runInTransaction(() async {
      await db.updateAccount(updatedFrom);
      await db.updateAccount(updatedTo);
    });

    state = state.map((a) {
      if (a.id == fromId) return updatedFrom;
      if (a.id == toId) return updatedTo;
      return a;
    }).toList();
  }
}

final accountProvider =
    NotifierProvider<AccountNotifier, List<Account>>(AccountNotifier.new);

/// 单一货币总余额（不推荐用于多币种场景）
final totalBalanceProvider = Provider<double>((ref) {
  return ref.watch(accountProvider.notifier).totalBalance;
});

/// 多币种余额汇总
final multiCurrencyBalanceProvider = Provider<MultiCurrencyAmount>((ref) {
  return ref.watch(accountProvider.notifier).multiCurrencyBalance;
});

/// 按货币分组的余额
final balanceByCurrencyProvider = Provider<Map<CurrencyType, double>>((ref) {
  return ref.watch(accountProvider.notifier).balanceByCurrency;
});

/// 转换为默认货币的总余额
final convertedTotalBalanceProvider = Provider<double>((ref) {
  final multiBalance = ref.watch(multiCurrencyBalanceProvider);
  final currencyNotifier = ref.watch(currencyProvider.notifier);
  return currencyNotifier.convertToDefault(multiBalance);
});

/// 已使用的货币类型列表
final usedCurrenciesProvider = Provider<List<CurrencyType>>((ref) {
  return ref.watch(accountProvider.notifier).usedCurrencies;
});
