/// Repository Interfaces
///
/// 导出所有仓库接口，便于统一导入
///
/// 核心仓库 (Phase 1)：
/// - IRepository: 基础接口
/// - ITransactionRepository: 交易
/// - IAccountRepository: 账户
/// - ICategoryRepository: 分类
/// - ILedgerRepository: 账本
/// - IBudgetRepository: 预算
///
/// 扩展仓库 (Phase 2)：
/// - ITemplateRepository: 交易模板
/// - IRecurringTransactionRepository: 循环交易
/// - ICreditCardRepository: 信用卡
/// - ISavingsGoalRepository: 储蓄目标
/// - IBillReminderRepository: 账单提醒
/// - IDebtRepository: 债务
/// - IInvestmentRepository: 投资
/// - IVaultRepository: 小金库
/// - IImportBatchRepository: 导入批次
library;

// 核心仓库
export 'i_repository.dart';
export 'i_transaction_repository.dart';
export 'i_account_repository.dart';
export 'i_category_repository.dart';
export 'i_ledger_repository.dart';
export 'i_budget_repository.dart';

// 扩展仓库
export 'i_template_repository.dart';
export 'i_recurring_transaction_repository.dart';
export 'i_credit_card_repository.dart';
export 'i_savings_goal_repository.dart';
export 'i_bill_reminder_repository.dart';
export 'i_debt_repository.dart';
export 'i_investment_repository.dart';
export 'i_vault_repository.dart';
export 'i_import_batch_repository.dart';
