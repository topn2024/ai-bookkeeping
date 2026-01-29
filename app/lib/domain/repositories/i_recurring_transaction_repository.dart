/// Recurring Transaction Repository Interface
///
/// 定义循环交易实体的仓库接口
library;

import '../../models/recurring_transaction.dart';
import 'i_repository.dart';

/// 循环交易仓库接口
abstract class IRecurringTransactionRepository
    extends IRepository<RecurringTransaction, String> {
  /// 获取待执行的循环交易
  Future<List<RecurringTransaction>> findPending();

  /// 获取指定日期范围内需要执行的循环交易
  Future<List<RecurringTransaction>> findDueInRange(
    DateTime start,
    DateTime end,
  );

  /// 按频率类型查询
  Future<List<RecurringTransaction>> findByFrequency(RecurringFrequency frequency);

  /// 获取指定账户的循环交易
  Future<List<RecurringTransaction>> findByAccount(String accountId);

  /// 获取指定分类的循环交易
  Future<List<RecurringTransaction>> findByCategory(String category);

  /// 获取所有启用的循环交易
  Future<List<RecurringTransaction>> findActive();

  /// 更新下次执行时间
  Future<void> updateNextExecutionDate(String id, DateTime nextDate);

  /// 暂停循环交易
  Future<void> pause(String id);

  /// 恢复循环交易
  Future<void> resume(String id);

  /// 获取即将到期的循环交易（提醒用）
  Future<List<RecurringTransaction>> findUpcoming({int days = 7});
}
