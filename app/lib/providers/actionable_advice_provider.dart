import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/actionable_advice_page.dart';
import '../services/advice_service.dart';
import 'budget_provider.dart';
import 'budget_vault_provider.dart';
import 'transaction_provider.dart';
import 'money_age_provider.dart';
import 'ledger_context_provider.dart';

final adviceServiceProvider = Provider<AdviceService>((ref) {
  return AdviceService();
});

final actionableAdviceProvider = FutureProvider<List<ActionableAdvice>>((ref) async {
  final service = ref.watch(adviceServiceProvider);
  final ledgerContext = ref.watch(ledgerContextProvider);
  final bookId = ledgerContext.currentLedger?.id;

  if (bookId == null) {
    return [];
  }

  final budgets = ref.watch(budgetProvider);
  final transactions = ref.watch(transactionProvider);
  final vaultState = ref.watch(budgetVaultProvider);
  final moneyAgeDashboard = await ref.watch(moneyAgeDashboardProvider(bookId).future);

  return service.generateAdvice(
    budgets: budgets,
    transactions: transactions,
    vaults: vaultState.vaults,
    unallocatedAmount: vaultState.unallocatedAmount,
    moneyAgeDashboard: moneyAgeDashboard,
  );
});
