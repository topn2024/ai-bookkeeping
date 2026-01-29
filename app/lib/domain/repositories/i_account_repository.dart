/// Account Repository Interface
///
/// 定义账户实体的仓库接口
library;

import '../../models/account.dart';
import 'i_repository.dart';

/// 账户仓库接口
abstract class IAccountRepository extends IRepository<Account, String> {
  /// 获取默认账户
  Future<Account?> findDefault();

  /// 设置默认账户
  Future<int> setDefault(String id);

  /// 按类型查询账户
  Future<List<Account>> findByType(AccountType type);

  /// 获取活跃账户
  Future<List<Account>> findActive();

  /// 获取用户自定义账户
  Future<List<Account>> findCustom();

  /// 更新账户余额
  Future<int> updateBalance(String id, double newBalance);

  /// 增加账户余额（用于收入）
  Future<int> increaseBalance(String id, double amount);

  /// 减少账户余额（用于支出）
  Future<int> decreaseBalance(String id, double amount);

  /// 转账（从一个账户转到另一个账户）
  Future<void> transfer(String fromId, String toId, double amount);

  /// 获取账户总余额
  Future<double> getTotalBalance();

  /// 按类型获取账户总余额
  Future<Map<AccountType, double>> getTotalBalanceByType();
}
