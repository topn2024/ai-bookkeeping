/// Investment Repository Interface
///
/// 定义投资账户实体的仓库接口
library;

import '../../models/investment_account.dart';
import 'i_repository.dart';

/// 投资收益统计
class InvestmentStatistics {
  final double totalInvested;
  final double currentValue;
  final double totalReturn;
  final double returnRate;
  final Map<String, double> allocationByType;

  const InvestmentStatistics({
    required this.totalInvested,
    required this.currentValue,
    required this.totalReturn,
    required this.returnRate,
    required this.allocationByType,
  });
}

/// 投资仓库接口
abstract class IInvestmentRepository extends IRepository<InvestmentAccount, String> {
  /// 按投资类型查询
  Future<List<InvestmentAccount>> findByType(InvestmentType type);

  /// 获取所有活跃的投资
  Future<List<InvestmentAccount>> findActive();

  /// 获取投资统计
  Future<InvestmentStatistics> getStatistics();

  /// 更新投资当前价值
  Future<void> updateCurrentValue(String id, double value);

  /// 记录投资交易（买入/卖出）
  Future<void> recordTransaction(
    String investmentId,
    InvestmentTransactionType type,
    double amount, {
    double? price,
    double? quantity,
    String? note,
  });

  /// 获取投资交易记录
  Future<List<InvestmentTransaction>> getTransactionHistory(String investmentId);

  /// 获取总投资金额
  Future<double> getTotalInvested();

  /// 获取总当前价值
  Future<double> getTotalCurrentValue();

  /// 获取总收益
  Future<double> getTotalReturn();

  /// 按收益率排序获取投资
  Future<List<InvestmentAccount>> findSortedByReturn({bool descending = true});

  /// 获取亏损的投资
  Future<List<InvestmentAccount>> findLosing();

  /// 获取盈利的投资
  Future<List<InvestmentAccount>> findProfitable();
}

/// 投资交易类型
enum InvestmentTransactionType {
  buy,
  sell,
  dividend,
  fee,
}

/// 投资交易记录
class InvestmentTransaction {
  final String id;
  final String investmentId;
  final InvestmentTransactionType type;
  final double amount;
  final double? price;
  final double? quantity;
  final DateTime transactionDate;
  final String? note;

  const InvestmentTransaction({
    required this.id,
    required this.investmentId,
    required this.type,
    required this.amount,
    this.price,
    this.quantity,
    required this.transactionDate,
    this.note,
  });
}
