import 'package:sqflite/sqflite.dart';
import 'package:ai_bookkeeping/core/contracts/i_database_service.dart';
import 'package:ai_bookkeeping/models/transaction.dart' as model;
import 'package:ai_bookkeeping/models/transaction_split.dart';
import 'package:ai_bookkeeping/models/account.dart';
import 'package:ai_bookkeeping/models/category.dart';
import 'package:ai_bookkeeping/models/ledger.dart';
import 'package:ai_bookkeeping/models/budget.dart';
import 'package:ai_bookkeeping/models/template.dart';
import 'package:ai_bookkeeping/models/recurring_transaction.dart';
import 'package:ai_bookkeeping/models/credit_card.dart';
import 'package:ai_bookkeeping/models/savings_goal.dart' as savings;
import 'package:ai_bookkeeping/models/bill_reminder.dart';
import 'package:ai_bookkeeping/models/investment_account.dart';
import 'package:ai_bookkeeping/models/debt.dart';
import 'package:ai_bookkeeping/models/member.dart';
import 'package:ai_bookkeeping/models/import_batch.dart';
import 'package:ai_bookkeeping/models/resource_pool.dart';
import 'package:ai_bookkeeping/models/budget_vault.dart';

/// 手动 mock 数据库服务，用于测试
class MockDatabaseService implements IDatabaseService {
  // Configurable return values for testing
  List<model.Transaction> transactionsToReturn = [];
  List<Budget> budgetsToReturn = [];
  List<Category> categoriesToReturn = [];
  List<Ledger> ledgersToReturn = [];
  List<CreditCard> creditCardsToReturn = [];
  List<savings.SavingsGoal> savingsGoalsToReturn = [];
  List<RecurringTransaction> recurringTransactionsToReturn = [];
  List<LedgerMember> ledgerMembersToReturn = [];
  List<BudgetVault> budgetVaultsToReturn = [];
  List<Account> accountsToReturn = [];

  // Track method calls for verification
  final List<String> methodCalls = [];
  final Map<String, dynamic> lastQueryParams = {};

  void reset() {
    transactionsToReturn = [];
    budgetsToReturn = [];
    categoriesToReturn = [];
    ledgersToReturn = [];
    creditCardsToReturn = [];
    savingsGoalsToReturn = [];
    recurringTransactionsToReturn = [];
    ledgerMembersToReturn = [];
    budgetVaultsToReturn = [];
    accountsToReturn = [];
    methodCalls.clear();
    lastQueryParams.clear();
  }

  @override
  Future<Database> get database => throw UnimplementedError();

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();

  @override
  Future<List<Object?>> runBatch(void Function(Batch batch) operations) async => [];

  // Transaction methods
  @override
  Future<int> insertTransaction(model.Transaction transaction) async {
    methodCalls.add('insertTransaction');
    transactionsToReturn.add(transaction);
    return 1;
  }

  @override
  Future<List<model.Transaction>> getTransactions({bool includeDeleted = false}) async {
    methodCalls.add('getTransactions');
    return transactionsToReturn;
  }

  @override
  Future<int> updateTransaction(model.Transaction transaction) async {
    methodCalls.add('updateTransaction:${transaction.id}');
    return 1;
  }

  @override
  Future<int> deleteTransaction(String id) async {
    methodCalls.add('deleteTransaction:$id');
    return 1;
  }

  @override
  Future<int> softDeleteTransaction(String id) async => 1;

  @override
  Future<int> restoreTransaction(String id) async => 1;

  @override
  Future<void> batchInsertTransactions(List<model.Transaction> transactions) async {}

  @override
  Future<int> getTransactionCount() async => transactionsToReturn.length;

  @override
  Future<model.Transaction?> getFirstTransaction() async =>
    transactionsToReturn.isNotEmpty ? transactionsToReturn.first : null;

  @override
  Future<List<model.Transaction>> queryTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? merchant,
    double? minAmount,
    double? maxAmount,
    String? description,
    String? account,
    List<String>? tags,
    int limit = 50,
  }) async {
    methodCalls.add('queryTransactions');
    lastQueryParams['startDate'] = startDate;
    lastQueryParams['endDate'] = endDate;
    lastQueryParams['category'] = category;
    lastQueryParams['limit'] = limit;
    return transactionsToReturn;
  }

  @override
  Future<List<model.Transaction>> findPotentialDuplicates({
    required DateTime date,
    required double amount,
    required model.TransactionType type,
    int dayRange = 1,
  }) async => [];

  @override
  Future<model.Transaction?> findTransactionByExternalId(
    String externalId,
    model.ExternalSource externalSource,
  ) async => null;

  @override
  Future<List<Map<String, dynamic>>> findFamilyDuplicates({
    required String ledgerId,
    required DateTime date,
    required double amount,
  }) async => [];

  @override
  Future<List<model.Transaction>> getAllTransactions() async => transactionsToReturn;

  @override
  Future<List<Account>> getAllAccounts() async {
    methodCalls.add('getAllAccounts');
    return accountsToReturn;
  }

  @override
  Future<List<Budget>> getAllBudgets() async => budgetsToReturn;

  @override
  Future<List<savings.SavingsGoal>> getAllSavingsGoals() async => [];

  @override
  Future<List<RecurringTransaction>> getAllRecurringTransactions() async => [];

  @override
  Future<List<TransactionTemplate>> getAllTemplates() async => [];

  // Transaction splits
  @override
  Future<int> insertTransactionSplit(TransactionSplit split) async => 1;

  @override
  Future<List<TransactionSplit>> getTransactionSplits(String transactionId) async => [];

  @override
  Future<int> deleteTransactionSplits(String transactionId) async => 1;

  // Accounts
  @override
  Future<int> insertAccount(Account account) async {
    methodCalls.add('insertAccount');
    return 1;
  }

  @override
  Future<List<Account>> getAccounts({bool includeDeleted = false}) async {
    methodCalls.add('getAccounts');
    return accountsToReturn;
  }

  @override
  Future<int> updateAccount(Account account) async => 1;

  @override
  Future<int> deleteAccount(String id) async => 1;

  @override
  Future<int> softDeleteAccount(String id) async => 1;

  @override
  Future<int> restoreAccount(String id) async => 1;

  // Categories
  @override
  Future<int> insertCategory(Category category) async {
    methodCalls.add('insertCategory');
    return 1;
  }

  @override
  Future<List<Category>> getCategories({bool includeDeleted = false}) async {
    methodCalls.add('getCategories');
    return categoriesToReturn;
  }

  @override
  Future<int> updateCategory(Category category) async {
    methodCalls.add('updateCategory');
    return 1;
  }

  @override
  Future<int> deleteCategory(String id) async {
    methodCalls.add('deleteCategory');
    return 1;
  }

  @override
  Future<int> softDeleteCategory(String id) async => 1;

  @override
  Future<int> restoreCategory(String id) async => 1;

  @override
  Future<List<Map<String, dynamic>>> getCustomCategories() async => [];

  // Ledgers
  @override
  Future<int> insertLedger(Ledger ledger) async {
    methodCalls.add('insertLedger');
    return 1;
  }

  @override
  Future<List<Ledger>> getLedgers({bool includeDeleted = false}) async {
    methodCalls.add('getLedgers');
    return ledgersToReturn;
  }

  @override
  Future<Ledger?> getDefaultLedger() async => null;

  @override
  Future<int> updateLedger(Ledger ledger) async => 1;

  @override
  Future<int> deleteLedger(String id) async => 1;

  @override
  Future<int> softDeleteLedger(String id) async => 1;

  @override
  Future<int> restoreLedger(String id) async => 1;

  @override
  Future<List<Map<String, dynamic>>> getFamilyLedgers() async => [];

  // Budgets
  @override
  Future<int> insertBudget(Budget budget) async => 1;

  @override
  Future<List<Budget>> getBudgets({bool includeDeleted = false}) async {
    methodCalls.add('getBudgets');
    return budgetsToReturn;
  }

  @override
  Future<Budget?> getBudget(String id) async => null;

  @override
  Future<List<Budget>> getBudgetsForMonth(DateTime month) async => budgetsToReturn;

  @override
  Future<int> updateBudget(Budget budget) async => 1;

  @override
  Future<void> saveBudget(Budget budget) async {}

  @override
  Future<int> deleteBudget(String id) async => 1;

  @override
  Future<int> softDeleteBudget(String id) async => 1;

  @override
  Future<int> restoreBudget(String id) async => 1;

  // Budget carryovers
  @override
  Future<int> insertBudgetCarryover(BudgetCarryover carryover) async => 1;

  @override
  Future<List<BudgetCarryover>> getBudgetCarryovers(String budgetId) async => [];

  @override
  Future<BudgetCarryover?> getBudgetCarryoverForMonth(String budgetId, int year, int month) async => null;

  @override
  Future<int> deleteBudgetCarryover(String id) async => 1;

  // Zero-based allocations
  @override
  Future<int> insertZeroBasedAllocation(ZeroBasedAllocation allocation) async => 1;

  @override
  Future<List<ZeroBasedAllocation>> getZeroBasedAllocations(String budgetId) async => [];

  @override
  Future<ZeroBasedAllocation?> getZeroBasedAllocationForMonth(String budgetId, int year, int month) async => null;

  @override
  Future<int> updateZeroBasedAllocation(ZeroBasedAllocation allocation) async => 1;

  @override
  Future<int> deleteZeroBasedAllocation(String id) async => 1;

  // Templates
  @override
  Future<int> insertTemplate(TransactionTemplate template) async => 1;

  @override
  Future<List<TransactionTemplate>> getTemplates() async => [];

  @override
  Future<int> updateTemplate(TransactionTemplate template) async => 1;

  @override
  Future<int> deleteTemplate(String id) async => 1;

  @override
  Future<void> incrementTemplateUseCount(String id) async {}

  // Recurring transactions
  @override
  Future<int> insertRecurringTransaction(RecurringTransaction recurring) async {
    methodCalls.add('insertRecurringTransaction');
    return 1;
  }

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    methodCalls.add('getRecurringTransactions');
    return recurringTransactionsToReturn;
  }

  @override
  Future<int> updateRecurringTransaction(RecurringTransaction recurring) async => 1;

  @override
  Future<int> deleteRecurringTransaction(String id) async => 1;

  // Credit cards
  @override
  Future<int> insertCreditCard(CreditCard card) async {
    methodCalls.add('insertCreditCard');
    return 1;
  }

  @override
  Future<List<CreditCard>> getCreditCards() async {
    methodCalls.add('getCreditCards');
    return creditCardsToReturn;
  }

  @override
  Future<int> updateCreditCard(CreditCard card) async => 1;

  @override
  Future<int> deleteCreditCard(String id) async => 1;

  // Savings goals
  @override
  Future<int> insertSavingsGoal(savings.SavingsGoal goal) async {
    methodCalls.add('insertSavingsGoal');
    return 1;
  }

  @override
  Future<List<savings.SavingsGoal>> getSavingsGoals() async {
    methodCalls.add('getSavingsGoals');
    return savingsGoalsToReturn;
  }

  @override
  Future<int> updateSavingsGoal(savings.SavingsGoal goal) async => 1;

  @override
  Future<int> deleteSavingsGoal(String id) async => 1;

  @override
  Future<int> insertSavingsDeposit(savings.SavingsDeposit deposit) async => 1;

  @override
  Future<List<savings.SavingsDeposit>> getSavingsDeposits(String goalId) async => [];

  @override
  Future<int> deleteSavingsDeposit(String id) async => 1;

  // Bill reminders
  @override
  Future<int> insertBillReminder(BillReminder reminder) async => 1;

  @override
  Future<List<BillReminder>> getBillReminders() async => [];

  @override
  Future<int> updateBillReminder(BillReminder reminder) async => 1;

  @override
  Future<int> deleteBillReminder(String id) async => 1;

  // Investment accounts
  @override
  Future<int> insertInvestmentAccount(InvestmentAccount investment) async => 1;

  @override
  Future<List<InvestmentAccount>> getInvestmentAccounts() async => [];

  @override
  Future<int> updateInvestmentAccount(InvestmentAccount investment) async => 1;

  @override
  Future<int> deleteInvestmentAccount(String id) async => 1;

  // Debts
  @override
  Future<int> insertDebt(Debt debt) async => 1;

  @override
  Future<List<Debt>> getDebts() async => [];

  @override
  Future<int> updateDebt(Debt debt) async => 1;

  @override
  Future<int> deleteDebt(String id) async => 1;

  @override
  Future<int> insertDebtPayment(DebtPayment payment) async => 1;

  @override
  Future<List<DebtPayment>> getDebtPayments(String debtId) async => [];

  @override
  Future<int> deleteDebtPayment(String id) async => 1;

  // Members
  @override
  Future<int> insertLedgerMember(LedgerMember member) async {
    methodCalls.add('insertLedgerMember');
    return 1;
  }

  @override
  Future<List<LedgerMember>> getLedgerMembers() async {
    methodCalls.add('getLedgerMembers');
    return ledgerMembersToReturn;
  }

  @override
  Future<List<LedgerMember>> getLedgerMembersForLedger(String ledgerId) async {
    methodCalls.add('getLedgerMembersForLedger');
    return ledgerMembersToReturn;
  }

  @override
  Future<int> updateLedgerMember(LedgerMember member) async => 1;

  @override
  Future<int> deleteLedgerMember(String id) async => 1;

  @override
  Future<List<Map<String, dynamic>>> getMembersByLedgerId(String ledgerId) async => [];

  @override
  Future<List<model.Transaction>> getTransactionsByMember(String memberId) async => [];

  // Member invites
  @override
  Future<int> insertMemberInvite(MemberInvite invite) async => 1;

  @override
  Future<List<MemberInvite>> getMemberInvites() async => [];

  @override
  Future<MemberInvite?> getMemberInviteByCode(String code) async => null;

  @override
  Future<int> updateMemberInvite(MemberInvite invite) async => 1;

  @override
  Future<int> deleteMemberInvite(String id) async => 1;

  // Member budgets
  @override
  Future<int> insertMemberBudget(MemberBudget budget) async => 1;

  @override
  Future<List<MemberBudget>> getMemberBudgets() async => [];

  @override
  Future<List<MemberBudget>> getMemberBudgetsForLedger(String ledgerId) async => [];

  @override
  Future<MemberBudget?> getMemberBudgetForMember(String memberId) async => null;

  @override
  Future<int> updateMemberBudget(MemberBudget budget) async => 1;

  @override
  Future<int> deleteMemberBudget(String id) async => 1;

  // Expense approvals
  @override
  Future<int> insertExpenseApproval(ExpenseApproval approval) async => 1;

  @override
  Future<List<ExpenseApproval>> getExpenseApprovals() async => [];

  @override
  Future<List<ExpenseApproval>> getExpenseApprovalsForLedger(String ledgerId) async => [];

  @override
  Future<List<ExpenseApproval>> getPendingApprovalsForLedger(String ledgerId) async => [];

  @override
  Future<int> updateExpenseApproval(ExpenseApproval approval) async => 1;

  @override
  Future<int> deleteExpenseApproval(String id) async => 1;

  // Import batches
  @override
  Future<int> insertImportBatch(ImportBatch batch) async => 1;

  @override
  Future<List<ImportBatch>> getImportBatches() async => [];

  @override
  Future<ImportBatch?> getImportBatch(String id) async => null;

  @override
  Future<List<ImportBatch>> getActiveImportBatches() async => [];

  @override
  Future<int> updateImportBatch(ImportBatch batch) async => 1;

  @override
  Future<void> revokeImportBatch(String batchId) async {}

  @override
  Future<int> deleteImportBatch(String id) async => 1;

  @override
  Future<List<model.Transaction>> getTransactionsByBatchId(String batchId) async => [];

  // Resource pools
  @override
  Future<int> insertResourcePool(ResourcePool pool) async => 1;

  @override
  Future<int> updateResourcePool(ResourcePool pool) async => 1;

  @override
  Future<int> deleteResourcePool(String id) async => 1;

  @override
  Future<List<ResourcePool>> getActiveResourcePools() async => [];

  @override
  Future<List<ResourcePool>> getAllResourcePools() async => [];

  @override
  Future<ResourcePool?> getResourcePoolByIncomeId(String incomeTransactionId) async => null;

  @override
  Future<int> insertResourceConsumption(ResourceConsumption consumption) async => 1;

  @override
  Future<void> batchInsertResourceConsumptions(List<ResourceConsumption> consumptions) async {}

  @override
  Future<List<ResourceConsumption>> getConsumptionsByTransaction(String transactionId) async => [];

  @override
  Future<List<ResourceConsumption>> getConsumptionsByPool(String poolId) async => [];

  // Budget vaults
  @override
  Future<int> insertBudgetVault(BudgetVault vault) async {
    methodCalls.add('insertBudgetVault');
    return 1;
  }

  @override
  Future<int> updateBudgetVault(BudgetVault vault) async {
    methodCalls.add('updateBudgetVault');
    return 1;
  }

  @override
  Future<int> deleteBudgetVault(String id) async {
    methodCalls.add('deleteBudgetVault');
    return 1;
  }

  @override
  Future<List<BudgetVault>> getBudgetVaults({String? ledgerId}) async {
    methodCalls.add('getBudgetVaults');
    return budgetVaultsToReturn;
  }

  @override
  Future<List<BudgetVault>> getEnabledBudgetVaults({String? ledgerId}) async {
    methodCalls.add('getEnabledBudgetVaults');
    return budgetVaultsToReturn.where((v) => v.isEnabled).toList();
  }

  @override
  Future<BudgetVault?> getBudgetVaultById(String id) async => null;

  @override
  Future<BudgetVault?> getBudgetVaultByCategory(String categoryId) async => null;

  @override
  Future<int> insertVaultAllocation(VaultAllocation allocation) async => 1;

  @override
  Future<List<VaultAllocation>> getVaultAllocations(String vaultId) async => [];

  @override
  Future<int> insertVaultTransfer(VaultTransfer transfer) async => 1;

  @override
  Future<List<VaultTransfer>> getVaultTransfers(String vaultId) async => [];

  @override
  Future<void> updateVaultAllocatedAmount(String vaultId, double amount) async {}

  @override
  Future<void> updateVaultSpentAmount(String vaultId, double amount) async {}

  @override
  Future<List<Map<String, dynamic>>> getVaultRecordsForMonth(DateTime month) async => [];

  // Sync methods
  @override
  Future<int> upsertSyncMetadata({
    required String entityType,
    required String localId,
    String? serverId,
    required int syncStatus,
    required int localUpdatedAt,
    int? serverUpdatedAt,
    int? lastSyncAt,
    int version = 1,
    bool isDeleted = false,
  }) async => 1;

  @override
  Future<int> updateSyncStatus(
    String entityType,
    String localId, {
    required int syncStatus,
    String? serverId,
    int? serverUpdatedAt,
    int? lastSyncAt,
  }) async => 1;

  @override
  Future<List<Map<String, dynamic>>> getSyncedEntitiesOlderThan(
    String entityType,
    int cutoffTimestamp,
  ) async => [];

  @override
  Future<Map<String, dynamic>?> getSyncMetadata(String entityType, String localId) async => null;

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncMetadata() async => [];

  @override
  Future<int> deleteSyncMetadata(String entityType, String localId) async => 1;

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncQueue() async => [];

  @override
  Future<int> deleteCompletedSyncQueue() async => 1;

  @override
  Future<int> clearSyncQueue() async => 1;

  @override
  Future<int> enqueueSyncOperation({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
  }) async => 1;

  @override
  Future<int> updateSyncQueueStatus(
    String id, {
    required int status,
    int? retryCount,
    String? lastError,
  }) async => 1;

  @override
  Future<int> insertIdMapping({
    required String entityType,
    required String localId,
    required String serverId,
  }) async => 1;

  @override
  Future<String?> getServerIdByLocalId(String entityType, String localId) async => null;

  @override
  Future<String?> getLocalIdByServerId(String entityType, String serverId) async => null;

  @override
  Future<List<Map<String, dynamic>>> getIdMappings(String entityType) async => [];

  @override
  Future<int> deleteIdMapping(String entityType, String localId) async => 1;

  @override
  Future<Map<String, int>> getSyncStatistics() async => {};

  @override
  Future<DateTime?> getLastSyncTime() async => null;

  // Settings
  @override
  Future<dynamic> getSetting(String key) async => null;

  @override
  Future<void> setSetting(String key, dynamic value) async {}

  // Raw SQL
  @override
  Future<void> rawExecute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async => [];

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 1;

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 1;

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 1;

  // Other
  @override
  Future<void> initializeDefaultData() async {}

  @override
  Future<Map<String, dynamic>> getMoneyAgeStats() async => {};

  @override
  Future<List<Map<String, dynamic>>> getFifoFlowRecords() async => [];

  @override
  Future<Map<String, int>> getMoneyAgeDistribution() async => {};

  @override
  Future<List<Map<String, dynamic>>> getMoneyAgePools() async => [];

  @override
  Future<List<Map<String, dynamic>>> getLocationRecords() async => [];

  @override
  Future<Map<String, int>> purgeDeletedRecords({int retentionDays = 30}) async => {};

  @override
  Future<Map<String, List<String>>> detectOrphanData() async => {};

  @override
  Future<Map<String, int>> cleanupOrphanData() async => {};

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async => {};
}
