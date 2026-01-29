/// Repository Factory
///
/// 仓库工厂，用于创建所有 Repository 实例。
/// 集中管理 Repository 的创建和依赖注入。
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/repositories/repositories.dart';
import '../../core/contracts/i_database_service.dart';
import 'repositories/repositories.dart' as impl;

/// 仓库工厂
///
/// 职责：
/// - 创建和管理所有 Repository 实例
/// - 提供统一的 Repository 获取入口
/// - 支持懒加载和缓存
class RepositoryFactory {
  final Database _database;
  final IDatabaseService? _legacyService;

  // Repository 缓存
  ITransactionRepository? _transactionRepository;
  IAccountRepository? _accountRepository;
  ICategoryRepository? _categoryRepository;
  ILedgerRepository? _ledgerRepository;
  IBudgetRepository? _budgetRepository;
  ITemplateRepository? _templateRepository;
  IRecurringTransactionRepository? _recurringTransactionRepository;
  ICreditCardRepository? _creditCardRepository;
  ISavingsGoalRepository? _savingsGoalRepository;
  IBillReminderRepository? _billReminderRepository;
  IDebtRepository? _debtRepository;
  IInvestmentRepository? _investmentRepository;
  IVaultRepository? _vaultRepository;
  IImportBatchRepository? _importBatchRepository;

  RepositoryFactory({
    required Database database,
    IDatabaseService? legacyService,
  })  : _database = database,
        _legacyService = legacyService;

  /// 获取数据库实例
  Database get database => _database;

  // ==================== 核心 Repository ====================

  /// 获取交易仓库
  ITransactionRepository get transactionRepository {
    _transactionRepository ??= _createTransactionRepository();
    return _transactionRepository!;
  }

  /// 获取账户仓库
  IAccountRepository get accountRepository {
    _accountRepository ??= _createAccountRepository();
    return _accountRepository!;
  }

  /// 获取分类仓库
  ICategoryRepository get categoryRepository {
    _categoryRepository ??= _createCategoryRepository();
    return _categoryRepository!;
  }

  /// 获取账本仓库
  ILedgerRepository get ledgerRepository {
    _ledgerRepository ??= _createLedgerRepository();
    return _ledgerRepository!;
  }

  /// 获取预算仓库
  IBudgetRepository get budgetRepository {
    _budgetRepository ??= _createBudgetRepository();
    return _budgetRepository!;
  }

  // ==================== 扩展 Repository ====================

  /// 获取模板仓库
  ITemplateRepository get templateRepository {
    _templateRepository ??= _createTemplateRepository();
    return _templateRepository!;
  }

  /// 获取循环交易仓库
  IRecurringTransactionRepository get recurringTransactionRepository {
    _recurringTransactionRepository ??= _createRecurringTransactionRepository();
    return _recurringTransactionRepository!;
  }

  /// 获取信用卡仓库
  ICreditCardRepository get creditCardRepository {
    _creditCardRepository ??= _createCreditCardRepository();
    return _creditCardRepository!;
  }

  /// 获取储蓄目标仓库
  ISavingsGoalRepository get savingsGoalRepository {
    _savingsGoalRepository ??= _createSavingsGoalRepository();
    return _savingsGoalRepository!;
  }

  /// 获取账单提醒仓库
  IBillReminderRepository get billReminderRepository {
    _billReminderRepository ??= _createBillReminderRepository();
    return _billReminderRepository!;
  }

  /// 获取债务仓库
  IDebtRepository get debtRepository {
    _debtRepository ??= _createDebtRepository();
    return _debtRepository!;
  }

  /// 获取投资仓库
  IInvestmentRepository get investmentRepository {
    _investmentRepository ??= _createInvestmentRepository();
    return _investmentRepository!;
  }

  /// 获取小金库仓库
  IVaultRepository get vaultRepository {
    _vaultRepository ??= _createVaultRepository();
    return _vaultRepository!;
  }

  /// 获取导入批次仓库
  IImportBatchRepository get importBatchRepository {
    _importBatchRepository ??= _createImportBatchRepository();
    return _importBatchRepository!;
  }

  // ==================== 工厂方法 ====================

  /// 获取数据库 Provider 函数
  Future<Database> Function() get _dbProvider => () async => _database;

  ITransactionRepository _createTransactionRepository() {
    return impl.TransactionRepository(_dbProvider);
  }

  IAccountRepository _createAccountRepository() {
    return impl.AccountRepository(_dbProvider);
  }

  ICategoryRepository _createCategoryRepository() {
    return impl.CategoryRepository(_dbProvider);
  }

  ILedgerRepository _createLedgerRepository() {
    return impl.LedgerRepository(_dbProvider);
  }

  IBudgetRepository _createBudgetRepository() {
    return impl.BudgetRepository(_dbProvider);
  }

  ITemplateRepository _createTemplateRepository() {
    return impl.TemplateRepository(_dbProvider);
  }

  IRecurringTransactionRepository _createRecurringTransactionRepository() {
    return impl.RecurringTransactionRepository(_dbProvider);
  }

  ICreditCardRepository _createCreditCardRepository() {
    return impl.CreditCardRepository(_dbProvider);
  }

  ISavingsGoalRepository _createSavingsGoalRepository() {
    return impl.SavingsGoalRepository(_dbProvider);
  }

  IBillReminderRepository _createBillReminderRepository() {
    return impl.BillReminderRepository(_dbProvider);
  }

  IDebtRepository _createDebtRepository() {
    return impl.DebtRepository(_dbProvider);
  }

  IInvestmentRepository _createInvestmentRepository() {
    return impl.InvestmentRepository(_dbProvider);
  }

  IVaultRepository _createVaultRepository() {
    return impl.VaultRepository(_dbProvider);
  }

  IImportBatchRepository _createImportBatchRepository() {
    return impl.ImportBatchRepository(_dbProvider);
  }

  // ==================== 辅助方法 ====================

  /// 清除所有缓存的仓库实例
  void clearCache() {
    _transactionRepository = null;
    _accountRepository = null;
    _categoryRepository = null;
    _ledgerRepository = null;
    _budgetRepository = null;
    _templateRepository = null;
    _recurringTransactionRepository = null;
    _creditCardRepository = null;
    _savingsGoalRepository = null;
    _billReminderRepository = null;
    _debtRepository = null;
    _investmentRepository = null;
    _vaultRepository = null;
    _importBatchRepository = null;
  }

  /// 获取所有已初始化的仓库数量
  int get initializedRepositoryCount {
    int count = 0;
    if (_transactionRepository != null) count++;
    if (_accountRepository != null) count++;
    if (_categoryRepository != null) count++;
    if (_ledgerRepository != null) count++;
    if (_budgetRepository != null) count++;
    if (_templateRepository != null) count++;
    if (_recurringTransactionRepository != null) count++;
    if (_creditCardRepository != null) count++;
    if (_savingsGoalRepository != null) count++;
    if (_billReminderRepository != null) count++;
    if (_debtRepository != null) count++;
    if (_investmentRepository != null) count++;
    if (_vaultRepository != null) count++;
    if (_importBatchRepository != null) count++;
    return count;
  }
}
