import '../../models/account.dart';

/// 账户服务接口
///
/// 定义账户相关操作的抽象接口，包括 CRUD 操作、余额管理、转账等。
abstract class IAccountService {
  // ==================== CRUD 操作 ====================

  /// 获取所有账户
  Future<List<Account>> getAll({bool includeDeleted = false});

  /// 根据 ID 获取账户
  Future<Account?> getById(String id);

  /// 创建账户
  Future<void> create(Account account);

  /// 更新账户
  Future<void> update(Account account);

  /// 删除账户（硬删除）
  Future<void> delete(String id);

  /// 软删除账户
  Future<void> softDelete(String id);

  /// 恢复已删除的账户
  Future<void> restore(String id);

  // ==================== 余额操作 ====================

  /// 更新账户余额
  /// [isDecrease] 为 true 时表示减少余额，为 false 时表示增加余额
  Future<void> updateBalance(String accountId, double amount, bool isDecrease);

  /// 获取账户余额
  Future<double> getBalance(String accountId);

  /// 获取所有账户的总余额
  Future<double> getTotalBalance();

  // ==================== 转账操作 ====================

  /// 账户间转账
  Future<void> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
  });

  // ==================== 查询操作 ====================

  /// 根据账户类型获取账户列表
  Future<List<Account>> getByType(AccountType type);

  /// 获取默认账户
  Future<Account?> getDefault();

  /// 设置默认账户
  Future<void> setDefault(String accountId);
}
