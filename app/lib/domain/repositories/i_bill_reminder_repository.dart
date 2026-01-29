/// Bill Reminder Repository Interface
///
/// 定义账单提醒实体的仓库接口
library;

import '../../models/bill_reminder.dart';
import 'i_repository.dart';

/// 账单提醒仓库接口
abstract class IBillReminderRepository extends IRepository<BillReminder, String> {
  /// 获取待处理的账单提醒
  Future<List<BillReminder>> findPending();

  /// 获取指定日期范围内的账单提醒
  Future<List<BillReminder>> findInDateRange(DateTime start, DateTime end);

  /// 获取今天需要提醒的账单
  Future<List<BillReminder>> findDueToday();

  /// 获取即将到期的账单提醒
  Future<List<BillReminder>> findUpcoming({int days = 7});

  /// 获取已逾期的账单提醒
  Future<List<BillReminder>> findOverdue();

  /// 按分类查询账单提醒
  Future<List<BillReminder>> findByCategory(String category);

  /// 标记账单已支付
  Future<void> markAsPaid(String id, {DateTime? paidDate});

  /// 延期账单
  Future<void> postpone(String id, DateTime newDueDate);

  /// 获取所有启用的账单提醒
  Future<List<BillReminder>> findEnabled();

  /// 获取指定账户的账单提醒
  Future<List<BillReminder>> findByAccount(String accountId);

  /// 获取本月账单总额
  Future<double> getMonthlyTotal({int? year, int? month});
}
