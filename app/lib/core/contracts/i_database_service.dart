import 'package:sqflite/sqflite.dart';
import '../../models/transaction.dart' as model;
import '../../models/transaction_split.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../models/ledger.dart';
import '../../models/budget.dart';
import '../../models/template.dart';
import '../../models/recurring_transaction.dart';
import '../../models/credit_card.dart';
import '../../models/savings_goal.dart' as savings;
import '../../models/bill_reminder.dart';
import '../../models/investment_account.dart';
import '../../models/debt.dart';
import '../../models/member.dart';
import '../../models/import_batch.dart';
import '../../models/resource_pool.dart';
import '../../models/budget_vault.dart';

/// 数据库服务接口
///
/// 定义应用程序数据库操作的抽象接口。
/// 包含所有核心数据实体的 CRUD 操作。
abstract class IDatabaseService {
  /// 获取数据库实例
  Future<Database> get database;

  // ==================== 事务控制 ====================

  /// 在数据库事务中执行操作
  Future<T> runInTransaction<T>(Future<T> Function() action);

  /// 批量执行数据库操作
  Future<List<Object?>> runBatch(void Function(Batch batch) operations);

  // ==================== 交易记录 ====================

  Future<int> insertTransaction(model.Transaction transaction);
  Future<List<model.Transaction>> getTransactions({bool includeDeleted = false});
  Future<int> updateTransaction(model.Transaction transaction);
  Future<int> deleteTransaction(String id);
  Future<int> softDeleteTransaction(String id);
  Future<int> restoreTransaction(String id);
  Future<void> batchInsertTransactions(List<model.Transaction> transactions);
  Future<int> getTransactionCount();
  Future<model.Transaction?> getFirstTransaction();

  /// 高级交易查询（支持多条件过滤）
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
  });

  /// 查找潜在重复交易
  Future<List<model.Transaction>> findPotentialDuplicates({
    required DateTime date,
    required double amount,
    required model.TransactionType type,
    int dayRange = 1,
  });

  /// 通过外部 ID 查找交易
  Future<model.Transaction?> findTransactionByExternalId(
    String externalId,
    model.ExternalSource externalSource,
  );

  /// 查找家庭账本中的重复交易
  Future<List<Map<String, dynamic>>> findFamilyDuplicates({
    required String ledgerId,
    required DateTime date,
    required double amount,
  });

  /// 别名方法：获取所有交易
  Future<List<model.Transaction>> getAllTransactions();

  /// 别名方法：获取所有账户
  Future<List<Account>> getAllAccounts();

  /// 别名方法：获取所有预算
  Future<List<Budget>> getAllBudgets();

  /// 别名方法：获取所有储蓄目标
  Future<List<savings.SavingsGoal>> getAllSavingsGoals();

  /// 别名方法：获取所有周期性交易
  Future<List<RecurringTransaction>> getAllRecurringTransactions();

  /// 别名方法：获取所有模板
  Future<List<TransactionTemplate>> getAllTemplates();

  // ==================== 交易拆分 ====================

  Future<int> insertTransactionSplit(TransactionSplit split);
  Future<List<TransactionSplit>> getTransactionSplits(String transactionId);
  Future<int> deleteTransactionSplits(String transactionId);

  // ==================== 账户 ====================

  Future<int> insertAccount(Account account);
  Future<List<Account>> getAccounts({bool includeDeleted = false});
  Future<int> updateAccount(Account account);
  Future<int> deleteAccount(String id);
  Future<int> softDeleteAccount(String id);
  Future<int> restoreAccount(String id);

  // ==================== 分类 ====================

  Future<int> insertCategory(Category category);
  Future<List<Category>> getCategories({bool includeDeleted = false});
  Future<int> updateCategory(Category category);
  Future<int> deleteCategory(String id);
  Future<int> softDeleteCategory(String id);
  Future<int> restoreCategory(String id);
  Future<List<Map<String, dynamic>>> getCustomCategories();

  // ==================== 账本 ====================

  Future<int> insertLedger(Ledger ledger);
  Future<List<Ledger>> getLedgers({bool includeDeleted = false});
  Future<Ledger?> getDefaultLedger();
  Future<int> updateLedger(Ledger ledger);
  Future<int> deleteLedger(String id);
  Future<int> softDeleteLedger(String id);
  Future<int> restoreLedger(String id);
  Future<List<Map<String, dynamic>>> getFamilyLedgers();

  // ==================== 预算 ====================

  Future<int> insertBudget(Budget budget);
  Future<List<Budget>> getBudgets({bool includeDeleted = false});
  Future<Budget?> getBudget(String id);
  Future<List<Budget>> getBudgetsForMonth(DateTime month);
  Future<int> updateBudget(Budget budget);
  Future<void> saveBudget(Budget budget);
  Future<int> deleteBudget(String id);
  Future<int> softDeleteBudget(String id);
  Future<int> restoreBudget(String id);

  // ==================== 预算结转 ====================

  Future<int> insertBudgetCarryover(BudgetCarryover carryover);
  Future<List<BudgetCarryover>> getBudgetCarryovers(String budgetId);
  Future<BudgetCarryover?> getBudgetCarryoverForMonth(String budgetId, int year, int month);
  Future<int> deleteBudgetCarryover(String id);

  // ==================== 零基预算分配 ====================

  Future<int> insertZeroBasedAllocation(ZeroBasedAllocation allocation);
  Future<List<ZeroBasedAllocation>> getZeroBasedAllocations(String budgetId);
  Future<ZeroBasedAllocation?> getZeroBasedAllocationForMonth(String budgetId, int year, int month);
  Future<int> updateZeroBasedAllocation(ZeroBasedAllocation allocation);
  Future<int> deleteZeroBasedAllocation(String id);

  // ==================== 模板 ====================

  Future<int> insertTemplate(TransactionTemplate template);
  Future<List<TransactionTemplate>> getTemplates();
  Future<int> updateTemplate(TransactionTemplate template);
  Future<int> deleteTemplate(String id);
  Future<void> incrementTemplateUseCount(String id);

  // ==================== 周期性交易 ====================

  Future<int> insertRecurringTransaction(RecurringTransaction recurring);
  Future<List<RecurringTransaction>> getRecurringTransactions();
  Future<int> updateRecurringTransaction(RecurringTransaction recurring);
  Future<int> deleteRecurringTransaction(String id);

  // ==================== 信用卡 ====================

  Future<int> insertCreditCard(CreditCard card);
  Future<List<CreditCard>> getCreditCards();
  Future<int> updateCreditCard(CreditCard card);
  Future<int> deleteCreditCard(String id);

  // ==================== 储蓄目标 ====================

  Future<int> insertSavingsGoal(savings.SavingsGoal goal);
  Future<List<savings.SavingsGoal>> getSavingsGoals();
  Future<int> updateSavingsGoal(savings.SavingsGoal goal);
  Future<int> deleteSavingsGoal(String id);
  Future<int> insertSavingsDeposit(savings.SavingsDeposit deposit);
  Future<List<savings.SavingsDeposit>> getSavingsDeposits(String goalId);
  Future<int> deleteSavingsDeposit(String id);

  // ==================== 账单提醒 ====================

  Future<int> insertBillReminder(BillReminder reminder);
  Future<List<BillReminder>> getBillReminders();
  Future<int> updateBillReminder(BillReminder reminder);
  Future<int> deleteBillReminder(String id);

  // ==================== 投资账户 ====================

  Future<int> insertInvestmentAccount(InvestmentAccount investment);
  Future<List<InvestmentAccount>> getInvestmentAccounts();
  Future<int> updateInvestmentAccount(InvestmentAccount investment);
  Future<int> deleteInvestmentAccount(String id);

  // ==================== 债务 ====================

  Future<int> insertDebt(Debt debt);
  Future<List<Debt>> getDebts();
  Future<int> updateDebt(Debt debt);
  Future<int> deleteDebt(String id);
  Future<int> insertDebtPayment(DebtPayment payment);
  Future<List<DebtPayment>> getDebtPayments(String debtId);
  Future<int> deleteDebtPayment(String id);

  // ==================== 成员管理 ====================

  Future<int> insertLedgerMember(LedgerMember member);
  Future<List<LedgerMember>> getLedgerMembers();
  Future<List<LedgerMember>> getLedgerMembersForLedger(String ledgerId);
  Future<int> updateLedgerMember(LedgerMember member);
  Future<int> deleteLedgerMember(String id);
  Future<List<Map<String, dynamic>>> getMembersByLedgerId(String ledgerId);
  Future<List<model.Transaction>> getTransactionsByMember(String memberId);

  // ==================== 成员邀请 ====================

  Future<int> insertMemberInvite(MemberInvite invite);
  Future<List<MemberInvite>> getMemberInvites();
  Future<MemberInvite?> getMemberInviteByCode(String code);
  Future<int> updateMemberInvite(MemberInvite invite);
  Future<int> deleteMemberInvite(String id);

  // ==================== 成员预算 ====================

  Future<int> insertMemberBudget(MemberBudget budget);
  Future<List<MemberBudget>> getMemberBudgets();
  Future<List<MemberBudget>> getMemberBudgetsForLedger(String ledgerId);
  Future<MemberBudget?> getMemberBudgetForMember(String memberId);
  Future<int> updateMemberBudget(MemberBudget budget);
  Future<int> deleteMemberBudget(String id);

  // ==================== 费用审批 ====================

  Future<int> insertExpenseApproval(ExpenseApproval approval);
  Future<List<ExpenseApproval>> getExpenseApprovals();
  Future<List<ExpenseApproval>> getExpenseApprovalsForLedger(String ledgerId);
  Future<List<ExpenseApproval>> getPendingApprovalsForLedger(String ledgerId);
  Future<int> updateExpenseApproval(ExpenseApproval approval);
  Future<int> deleteExpenseApproval(String id);

  // ==================== 导入批次 ====================

  Future<int> insertImportBatch(ImportBatch batch);
  Future<List<ImportBatch>> getImportBatches();
  Future<ImportBatch?> getImportBatch(String id);
  Future<List<ImportBatch>> getActiveImportBatches();
  Future<int> updateImportBatch(ImportBatch batch);
  Future<void> revokeImportBatch(String batchId);
  Future<int> deleteImportBatch(String id);
  Future<List<model.Transaction>> getTransactionsByBatchId(String batchId);

  // ==================== 资源池 ====================

  Future<int> insertResourcePool(ResourcePool pool);
  Future<int> updateResourcePool(ResourcePool pool);
  Future<int> deleteResourcePool(String id);
  Future<List<ResourcePool>> getActiveResourcePools();
  Future<List<ResourcePool>> getAllResourcePools();
  Future<ResourcePool?> getResourcePoolByIncomeId(String incomeTransactionId);
  Future<int> insertResourceConsumption(ResourceConsumption consumption);
  Future<void> batchInsertResourceConsumptions(List<ResourceConsumption> consumptions);
  Future<List<ResourceConsumption>> getConsumptionsByTransaction(String transactionId);
  Future<List<ResourceConsumption>> getConsumptionsByPool(String poolId);

  // ==================== 预算小金库 ====================

  Future<int> insertBudgetVault(BudgetVault vault);
  Future<int> updateBudgetVault(BudgetVault vault);
  Future<int> deleteBudgetVault(String id);
  Future<List<BudgetVault>> getBudgetVaults({String? ledgerId});
  Future<List<BudgetVault>> getEnabledBudgetVaults({String? ledgerId});
  Future<BudgetVault?> getBudgetVaultById(String id);
  Future<BudgetVault?> getBudgetVaultByCategory(String categoryId);
  Future<int> insertVaultAllocation(VaultAllocation allocation);
  Future<List<VaultAllocation>> getVaultAllocations(String vaultId);
  Future<int> insertVaultTransfer(VaultTransfer transfer);
  Future<List<VaultTransfer>> getVaultTransfers(String vaultId);
  Future<void> updateVaultAllocatedAmount(String vaultId, double amount);
  Future<void> updateVaultSpentAmount(String vaultId, double amount);
  Future<List<Map<String, dynamic>>> getVaultRecordsForMonth(DateTime month);

  // ==================== 同步相关 ====================

  /// 插入或更新同步元数据
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
  });

  /// 更新同步状态
  Future<int> updateSyncStatus(
    String entityType,
    String localId, {
    required int syncStatus,
    String? serverId,
    int? serverUpdatedAt,
    int? lastSyncAt,
  });

  /// 获取指定时间之前已同步的实体（用于清理）
  Future<List<Map<String, dynamic>>> getSyncedEntitiesOlderThan(
    String entityType,
    int cutoffTimestamp,
  );

  Future<Map<String, dynamic>?> getSyncMetadata(String entityType, String localId);
  Future<List<Map<String, dynamic>>> getPendingSyncMetadata();
  Future<int> deleteSyncMetadata(String entityType, String localId);
  Future<List<Map<String, dynamic>>> getPendingSyncQueue();
  Future<int> deleteCompletedSyncQueue();
  Future<int> clearSyncQueue();

  /// 将同步操作加入队列
  Future<int> enqueueSyncOperation({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
  });

  /// 更新同步队列状态
  Future<int> updateSyncQueueStatus(
    String id, {
    required int status,
    int? retryCount,
    String? lastError,
  });

  /// 插入 ID 映射
  Future<int> insertIdMapping({
    required String entityType,
    required String localId,
    required String serverId,
  });

  Future<String?> getServerIdByLocalId(String entityType, String localId);
  Future<String?> getLocalIdByServerId(String entityType, String serverId);
  Future<List<Map<String, dynamic>>> getIdMappings(String entityType);
  Future<int> deleteIdMapping(String entityType, String localId);
  Future<Map<String, int>> getSyncStatistics();
  Future<DateTime?> getLastSyncTime();

  // ==================== 设置 ====================

  Future<dynamic> getSetting(String key);
  Future<void> setSetting(String key, dynamic value);

  // ==================== 原始 SQL ====================

  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]);
  Future<int> rawInsert(String sql, [List<Object?>? arguments]);
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]);
  Future<int> rawDelete(String sql, [List<Object?>? arguments]);

  // ==================== 其他 ====================

  Future<void> initializeDefaultData();
  Future<Map<String, dynamic>> getMoneyAgeStats();
  Future<List<Map<String, dynamic>>> getFifoFlowRecords();
  Future<Map<String, int>> getMoneyAgeDistribution();
  Future<List<Map<String, dynamic>>> getMoneyAgePools();
  Future<List<Map<String, dynamic>>> getLocationRecords();
  Future<Map<String, int>> purgeDeletedRecords({int retentionDays = 30});
  Future<Map<String, List<String>>> detectOrphanData();
  Future<Map<String, int>> cleanupOrphanData();
  Future<Map<String, dynamic>> getDatabaseStats();
}
