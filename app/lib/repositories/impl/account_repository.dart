import '../../models/account.dart';
import '../../core/contracts/i_database_service.dart';
import '../contracts/i_account_repository.dart';

/// 账户 Repository 实现
///
/// 封装所有账户相关的数据库操作。
class AccountRepository implements IAccountRepository {
  final IDatabaseService _db;

  AccountRepository(this._db);

  // ==================== IRepository 基础操作 ====================

  @override
  Future<List<Account>> findAll() => _db.getAccounts();

  @override
  Future<Account?> findById(String id) async {
    final accounts = await _db.getAccounts();
    try {
      return accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insert(Account entity) => _db.insertAccount(entity);

  @override
  Future<void> update(Account entity) => _db.updateAccount(entity);

  @override
  Future<void> delete(String id) => _db.deleteAccount(id);

  @override
  Future<bool> exists(String id) async {
    final account = await findById(id);
    return account != null;
  }

  @override
  Future<int> count() async {
    final accounts = await _db.getAccounts();
    return accounts.length;
  }

  // ==================== ISoftDeleteRepository 操作 ====================

  @override
  Future<List<Account>> findAllIncludingDeleted() =>
      _db.getAccounts(includeDeleted: true);

  @override
  Future<void> softDelete(String id) => _db.softDeleteAccount(id);

  @override
  Future<void> restore(String id) => _db.restoreAccount(id);

  @override
  Future<void> purge(String id) => _db.deleteAccount(id);

  @override
  Future<List<Account>> findDeleted() async {
    final all = await _db.getAccounts(includeDeleted: true);
    final active = await _db.getAccounts(includeDeleted: false);
    final activeIds = active.map((a) => a.id).toSet();
    return all.where((a) => !activeIds.contains(a.id)).toList();
  }

  // ==================== 查询操作 ====================

  @override
  Future<List<Account>> findByType(AccountType type) async {
    final accounts = await _db.getAccounts();
    return accounts.where((a) => a.type == type).toList();
  }

  @override
  Future<Account?> findDefault() async {
    final accounts = await _db.getAccounts();
    try {
      return accounts.firstWhere((a) => a.isDefault);
    } catch (_) {
      // 如果没有默认账户，返回第一个账户
      return accounts.isNotEmpty ? accounts.first : null;
    }
  }

  @override
  Future<List<Account>> findByLedgerId(String ledgerId) async {
    // Account 模型当前不包含 ledgerId 字段
    // 返回所有账户，后续可根据业务需求调整
    return _db.getAccounts();
  }

  // ==================== 余额操作 ====================

  @override
  Future<void> updateBalance(String id, double delta) async {
    final account = await findById(id);
    if (account != null) {
      final updatedAccount = account.copyWith(
        balance: account.balance + delta,
      );
      await _db.updateAccount(updatedAccount);
    }
  }

  @override
  Future<double> getBalance(String id) async {
    final account = await findById(id);
    return account?.balance ?? 0.0;
  }

  @override
  Future<double> getTotalBalance() async {
    final accounts = await _db.getAccounts();
    double total = 0.0;
    for (final a in accounts) {
      total += a.balance;
    }
    return total;
  }

  @override
  Future<double> getTotalBalanceByType(AccountType type) async {
    final accounts = await findByType(type);
    double total = 0.0;
    for (final a in accounts) {
      total += a.balance;
    }
    return total;
  }
}
