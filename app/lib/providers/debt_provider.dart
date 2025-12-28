import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/debt.dart';
import '../services/database_service.dart';

class DebtNotifier extends Notifier<List<Debt>> {
  final DatabaseService _db = DatabaseService();

  @override
  List<Debt> build() {
    _loadDebts();
    return [];
  }

  Future<void> _loadDebts() async {
    final debts = await _db.getDebts();
    state = debts;
  }

  Future<void> addDebt(Debt debt) async {
    await _db.insertDebt(debt);
    state = [...state, debt];
  }

  Future<void> updateDebt(Debt debt) async {
    await _db.updateDebt(debt);
    state = state.map((d) => d.id == debt.id ? debt : d).toList();
  }

  Future<void> deleteDebt(String id) async {
    await _db.deleteDebt(id);
    state = state.where((d) => d.id != id).toList();
  }

  /// 记录还款
  Future<void> makePayment(String debtId, double amount, {String? note}) async {
    final debt = state.firstWhere((d) => d.id == debtId);

    // 计算利息和本金
    final interest = debt.monthlyInterest;
    final principalPaid = (amount - interest).clamp(0.0, double.infinity).toDouble();
    final newBalance = (debt.currentBalance - principalPaid).clamp(0.0, double.infinity).toDouble();
    final isNowComplete = newBalance <= 0;

    // 更新债务
    final updated = debt.copyWith(
      currentBalance: newBalance,
      isCompleted: isNowComplete ? true : debt.isCompleted,
      completedAt: isNowComplete ? DateTime.now() : debt.completedAt,
    );
    await updateDebt(updated);

    // 记录还款历史
    await _db.insertDebtPayment(DebtPayment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      debtId: debtId,
      amount: amount,
      principalPaid: principalPaid,
      interestPaid: interest.clamp(0.0, amount).toDouble(),
      balanceAfter: newBalance,
      note: note,
      date: DateTime.now(),
      createdAt: DateTime.now(),
    ));
  }

  /// 标记为已还清
  Future<void> markAsCompleted(String id) async {
    final debt = state.firstWhere((d) => d.id == id);
    final updated = debt.copyWith(
      currentBalance: 0,
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    await updateDebt(updated);
  }

  /// 获取还款历史
  Future<List<DebtPayment>> getPaymentHistory(String debtId) async {
    return await _db.getDebtPayments(debtId);
  }

  /// 获取活跃债务（未还清）
  List<Debt> get activeDebts => state.where((d) => !d.isCompleted).toList();

  /// 获取已还清债务
  List<Debt> get completedDebts => state.where((d) => d.isCompleted).toList();

  /// 按雪球法排序（余额从小到大）
  List<Debt> get snowballSorted => DebtCalculator.sortBySnowball(activeDebts);

  /// 按雪崩法排序（利率从高到低）
  List<Debt> get avalancheSorted => DebtCalculator.sortByAvalanche(activeDebts);

  /// 总债务余额
  double get totalBalance => activeDebts.fold(0.0, (sum, d) => sum + d.currentBalance);

  /// 总原始债务
  double get totalOriginalAmount => activeDebts.fold(0.0, (sum, d) => sum + d.originalAmount);

  /// 总已还金额
  double get totalPaidAmount => activeDebts.fold(0.0, (sum, d) => sum + d.paidAmount);

  /// 总体还款进度
  double get overallProgress => totalOriginalAmount > 0
      ? totalPaidAmount / totalOriginalAmount
      : 0;

  /// 每月最低还款总额
  double get totalMinimumPayment => activeDebts.fold(0.0, (sum, d) => sum + d.minimumPayment);

  /// 每月利息总额
  double get totalMonthlyInterest => activeDebts.fold(0.0, (sum, d) => sum + d.monthlyInterest);

  /// 模拟还款计划
  RepaymentSimulation simulateRepayment({
    required RepaymentStrategy strategy,
    required double extraPayment,
  }) {
    return DebtCalculator.simulateRepayment(
      debts: activeDebts,
      strategy: strategy,
      extraPayment: extraPayment,
    );
  }

  /// 比较不同策略
  Map<String, double> compareStrategies({required double extraPayment}) {
    return DebtCalculator.compareStrategies(
      debts: activeDebts,
      extraPayment: extraPayment,
    );
  }

  Debt? getById(String id) {
    try {
      return state.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }
}

final debtProvider = NotifierProvider<DebtNotifier, List<Debt>>(DebtNotifier.new);

/// 活跃债务Provider
final activeDebtsProvider = Provider<List<Debt>>((ref) {
  final notifier = ref.watch(debtProvider.notifier);
  return notifier.activeDebts;
});

/// 债务汇总信息
class DebtSummary {
  final double totalBalance;
  final double totalOriginalAmount;
  final double totalPaidAmount;
  final double overallProgress;
  final double totalMinimumPayment;
  final double totalMonthlyInterest;
  final int activeCount;
  final int completedCount;

  DebtSummary({
    required this.totalBalance,
    required this.totalOriginalAmount,
    required this.totalPaidAmount,
    required this.overallProgress,
    required this.totalMinimumPayment,
    required this.totalMonthlyInterest,
    required this.activeCount,
    required this.completedCount,
  });

  double get remainingAmount => totalBalance;
}

final debtSummaryProvider = Provider<DebtSummary>((ref) {
  final debts = ref.watch(debtProvider);
  final activeDebts = debts.where((d) => !d.isCompleted).toList();

  final totalBalance = activeDebts.fold(0.0, (sum, d) => sum + d.currentBalance);
  final totalOriginal = activeDebts.fold(0.0, (sum, d) => sum + d.originalAmount);
  final totalPaid = activeDebts.fold(0.0, (sum, d) => sum + d.paidAmount);

  return DebtSummary(
    totalBalance: totalBalance,
    totalOriginalAmount: totalOriginal,
    totalPaidAmount: totalPaid,
    overallProgress: totalOriginal > 0 ? totalPaid / totalOriginal : 0,
    totalMinimumPayment: activeDebts.fold(0.0, (sum, d) => sum + d.minimumPayment),
    totalMonthlyInterest: activeDebts.fold(0.0, (sum, d) => sum + d.monthlyInterest),
    activeCount: activeDebts.length,
    completedCount: debts.where((d) => d.isCompleted).length,
  );
});

/// 雪球法排序Provider
final snowballDebtsProvider = Provider<List<Debt>>((ref) {
  final notifier = ref.watch(debtProvider.notifier);
  return notifier.snowballSorted;
});

/// 雪崩法排序Provider
final avalancheDebtsProvider = Provider<List<Debt>>((ref) {
  final notifier = ref.watch(debtProvider.notifier);
  return notifier.avalancheSorted;
});
