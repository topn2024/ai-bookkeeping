import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/investment_account.dart';
import 'base/crud_notifier.dart';

/// 投资账户管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class InvestmentNotifier extends SimpleCrudNotifier<InvestmentAccount, String> {
  @override
  String get tableName => 'investment_accounts';

  @override
  String getId(InvestmentAccount entity) => entity.id;

  @override
  Future<List<InvestmentAccount>> fetchAll() => db.getInvestmentAccounts();

  @override
  Future<void> insertOne(InvestmentAccount entity) => db.insertInvestmentAccount(entity);

  @override
  Future<void> updateOne(InvestmentAccount entity) => db.updateInvestmentAccount(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteInvestmentAccount(id);

  // ==================== 兼容性方法（保留原有接口）====================

  Future<void> addInvestment(InvestmentAccount investment) => add(investment);
  Future<void> updateInvestment(InvestmentAccount investment) => update(investment);
  Future<void> deleteInvestment(String id) => delete(id);

  // ==================== 业务特有方法 ====================

  /// 更新当前市值
  Future<void> updateValue(String id, double newValue) async {
    final investment = getById(id);
    if (investment == null) return;

    final updated = investment.copyWith(
      currentValue: newValue,
      updatedAt: DateTime.now(),
    );
    await update(updated);
  }

  /// 追加本金
  Future<void> addPrincipal(String id, double amount) async {
    final investment = getById(id);
    if (investment == null) return;

    final updated = investment.copyWith(
      principal: investment.principal + amount,
      currentValue: investment.currentValue + amount,
      updatedAt: DateTime.now(),
    );
    await update(updated);
  }

  /// 提取金额
  Future<void> withdrawAmount(String id, double amount) async {
    final investment = getById(id);
    if (investment == null || amount > investment.currentValue) return;

    // 按比例减少本金
    final ratio = amount / investment.currentValue;
    final principalReduction = investment.principal * ratio;

    final updated = investment.copyWith(
      principal: investment.principal - principalReduction,
      currentValue: investment.currentValue - amount,
      updatedAt: DateTime.now(),
    );
    await update(updated);
  }

  /// 按类型获取投资
  List<InvestmentAccount> getByType(String type) => where((i) => i.type.name == type);

  /// 获取盈利的投资
  List<InvestmentAccount> get profitableInvestments =>
      where((i) => i.currentValue > i.principal);

  /// 获取亏损的投资
  List<InvestmentAccount> get losingInvestments =>
      where((i) => i.currentValue < i.principal);
}

final investmentProvider =
    NotifierProvider<InvestmentNotifier, List<InvestmentAccount>>(
        InvestmentNotifier.new);

/// 投资汇总信息
class InvestmentSummary {
  final double totalPrincipal;
  final double totalCurrentValue;
  final double totalProfit;
  final double totalProfitRate;
  final int accountCount;

  const InvestmentSummary({
    required this.totalPrincipal,
    required this.totalCurrentValue,
    required this.totalProfit,
    required this.totalProfitRate,
    required this.accountCount,
  });

  static const empty = InvestmentSummary(
    totalPrincipal: 0,
    totalCurrentValue: 0,
    totalProfit: 0,
    totalProfitRate: 0,
    accountCount: 0,
  );
}

final investmentSummaryProvider = Provider<InvestmentSummary>((ref) {
  final investments = ref.watch(investmentProvider);

  if (investments.isEmpty) return InvestmentSummary.empty;

  final totalPrincipal = investments.fold<double>(0, (sum, i) => sum + i.principal);
  final totalCurrentValue = investments.fold<double>(0, (sum, i) => sum + i.currentValue);
  final totalProfit = totalCurrentValue - totalPrincipal;
  final totalProfitRate = totalPrincipal > 0 ? (totalProfit / totalPrincipal) * 100 : 0.0;

  return InvestmentSummary(
    totalPrincipal: totalPrincipal,
    totalCurrentValue: totalCurrentValue,
    totalProfit: totalProfit,
    totalProfitRate: totalProfitRate,
    accountCount: investments.length,
  );
});
