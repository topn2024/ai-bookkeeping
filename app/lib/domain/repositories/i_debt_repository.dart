/// Debt Repository Interface
///
/// 定义债务实体的仓库接口
library;

import '../../models/debt.dart';
import 'i_repository.dart';

/// 债务统计
class DebtStatistics {
  final double totalDebt;
  final double totalOwed;
  final double netDebt;
  final int debtCount;
  final int owedCount;

  const DebtStatistics({
    required this.totalDebt,
    required this.totalOwed,
    required this.netDebt,
    required this.debtCount,
    required this.owedCount,
  });
}

/// 债务仓库接口
abstract class IDebtRepository extends IRepository<Debt, String> {
  /// 获取我欠别人的债务
  Future<List<Debt>> findMyDebts();

  /// 获取别人欠我的债务
  Future<List<Debt>> findOwedToMe();

  /// 获取指定人的债务
  Future<List<Debt>> findByPerson(String personName);

  /// 获取即将到期的债务
  Future<List<Debt>> findDueSoon({int days = 30});

  /// 获取已逾期的债务
  Future<List<Debt>> findOverdue();

  /// 获取债务统计
  Future<DebtStatistics> getStatistics();

  /// 记录还款
  Future<void> recordPayment(String debtId, double amount, {String? note});

  /// 获取还款记录
  Future<List<DebtPayment>> getPaymentHistory(String debtId);

  /// 标记债务已结清
  Future<void> markAsSettled(String debtId);

  /// 获取所有未结清的债务
  Future<List<Debt>> findUnsettled();

  /// 获取我欠别人的总金额
  Future<double> getTotalDebt();

  /// 获取别人欠我的总金额
  Future<double> getTotalOwed();
}

/// 债务还款记录
class DebtPayment {
  final String id;
  final String debtId;
  final double amount;
  final DateTime paymentDate;
  final String? note;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    this.note,
  });
}
