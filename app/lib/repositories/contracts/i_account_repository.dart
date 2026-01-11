import '../../models/account.dart';
import 'i_repository.dart';

/// 账户 Repository 接口
///
/// 定义账户数据访问操作，继承软删除能力。
abstract class IAccountRepository implements ISoftDeleteRepository<Account, String> {
  // ==================== 查询操作 ====================

  /// 根据账户类型查询
  Future<List<Account>> findByType(AccountType type);

  /// 获取默认账户
  Future<Account?> findDefault();

  /// 根据账本 ID 查询账户
  Future<List<Account>> findByLedgerId(String ledgerId);

  // ==================== 余额操作 ====================

  /// 更新账户余额
  /// [delta] 为正数表示增加余额，为负数表示减少余额
  Future<void> updateBalance(String id, double delta);

  /// 获取账户余额
  Future<double> getBalance(String id);

  /// 获取所有账户的总余额
  Future<double> getTotalBalance();

  /// 获取指定类型账户的总余额
  Future<double> getTotalBalanceByType(AccountType type);
}
