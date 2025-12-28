import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/investment_account.dart';
import '../services/database_service.dart';

class InvestmentNotifier extends Notifier<List<InvestmentAccount>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<InvestmentAccount> build() {
    _loadInvestments();
    return [];
  }

  Future<void> _loadInvestments() async {
    final investments = await _db.getInvestmentAccounts();
    state = investments;
  }

  Future<void> addInvestment(InvestmentAccount investment) async {
    await _db.insertInvestmentAccount(investment);
    state = [...state, investment];
  }

  Future<void> updateInvestment(InvestmentAccount investment) async {
    await _db.updateInvestmentAccount(investment);
    state = state.map((i) => i.id == investment.id ? investment : i).toList();
  }

  Future<void> deleteInvestment(String id) async {
    await _db.deleteInvestmentAccount(id);
    state = state.where((i) => i.id != id).toList();
  }

  Future<void> updateValue(String id, double newValue) async {
    final investment = state.firstWhere((i) => i.id == id);
    final updated = investment.copyWith(
      currentValue: newValue,
      updatedAt: DateTime.now(),
    );
    await updateInvestment(updated);
  }

  Future<void> addPrincipal(String id, double amount) async {
    final investment = state.firstWhere((i) => i.id == id);
    final updated = investment.copyWith(
      principal: investment.principal + amount,
      currentValue: investment.currentValue + amount,
      updatedAt: DateTime.now(),
    );
    await updateInvestment(updated);
  }

  Future<void> withdrawAmount(String id, double amount) async {
    final investment = state.firstWhere((i) => i.id == id);
    if (amount > investment.currentValue) return;

    // 按比例减少本金
    final ratio = amount / investment.currentValue;
    final principalReduction = investment.principal * ratio;

    final updated = investment.copyWith(
      principal: investment.principal - principalReduction,
      currentValue: investment.currentValue - amount,
      updatedAt: DateTime.now(),
    );
    await updateInvestment(updated);
  }
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

  InvestmentSummary({
    required this.totalPrincipal,
    required this.totalCurrentValue,
    required this.totalProfit,
    required this.totalProfitRate,
    required this.accountCount,
  });
}

final investmentSummaryProvider = Provider<InvestmentSummary>((ref) {
  final investments = ref.watch(investmentProvider);

  if (investments.isEmpty) {
    return InvestmentSummary(
      totalPrincipal: 0,
      totalCurrentValue: 0,
      totalProfit: 0,
      totalProfitRate: 0,
      accountCount: 0,
    );
  }

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
