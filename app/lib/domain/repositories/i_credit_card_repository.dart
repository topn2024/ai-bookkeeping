/// Credit Card Repository Interface
///
/// 定义信用卡实体的仓库接口
library;

import '../../models/credit_card.dart';
import 'i_repository.dart';

/// 信用卡仓库接口
abstract class ICreditCardRepository extends IRepository<CreditCard, String> {
  /// 按账户ID查询关联的信用卡
  Future<CreditCard?> findByAccountId(String accountId);

  /// 获取所有信用卡（按到期日排序）
  Future<List<CreditCard>> findAllSortedByDueDate();

  /// 获取即将到期的信用卡（还款提醒）
  Future<List<CreditCard>> findDueSoon({int days = 7});

  /// 获取已逾期的信用卡
  Future<List<CreditCard>> findOverdue();

  /// 更新信用卡余额
  Future<void> updateBalance(String id, double balance);

  /// 更新信用卡已用额度
  Future<void> updateUsedCredit(String id, double usedAmount);

  /// 获取总信用额度
  Future<double> getTotalCreditLimit();

  /// 获取总已用额度
  Future<double> getTotalUsedCredit();

  /// 获取账单日在指定日期的信用卡
  Future<List<CreditCard>> findByBillingDay(int day);

  /// 获取还款日在指定日期的信用卡
  Future<List<CreditCard>> findByDueDay(int day);
}
