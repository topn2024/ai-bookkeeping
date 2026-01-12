import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart' as model;
import '../models/transaction_split.dart';
import '../models/transaction_location.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/ledger.dart';
import '../models/budget.dart';
import '../models/template.dart';
import '../models/recurring_transaction.dart';
import '../models/credit_card.dart';
import '../models/savings_goal.dart' as savings;
import '../models/bill_reminder.dart';
import '../models/investment_account.dart';
import '../models/debt.dart';
import '../models/member.dart';
import '../models/import_batch.dart';
import '../models/resource_pool.dart';
import '../models/budget_vault.dart';
import 'package:flutter/material.dart';
import 'database_migration_service.dart';
import '../core/logger.dart';
import '../core/contracts/i_database_service.dart';

class DatabaseService implements IDatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  final DatabaseMigrationService _migrationService = DatabaseMigrationService();
  final Logger _logger = Logger();

  // 当前数据库版本
  static const int currentVersion = 19;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ai_bookkeeping.db');

    // 检查是否需要迁移并创建备份
    int? existingVersion;
    Database? checkDb;
    try {
      checkDb = await openDatabase(path, readOnly: true);
      existingVersion = await checkDb.getVersion();
    } catch (e) {
      // 数据库不存在或损坏，将创建新数据库
      _logger.debug('No existing database found', tag: 'DB');
    } finally {
      await checkDb?.close();
    }

    // 如果需要升级，先创建备份
    if (existingVersion != null && existingVersion < currentVersion) {
      final result = await _migrationService.prepareMigration(
        currentVersion: existingVersion,
        targetVersion: currentVersion,
      );
      if (!result.isSuccess) {
        _logger.warning('Migration preparation failed, proceeding anyway', tag: 'DB');
      }
    }

    return await openDatabase(
      path,
      version: currentVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgradeWithRecovery,
    );
  }

  /// 数据库配置回调
  ///
  /// 在每次打开数据库连接时调用，用于启用外键约束等配置
  Future<void> _onConfigure(Database db) async {
    // 启用外键约束
    await db.execute('PRAGMA foreign_keys = ON');
    _logger.debug('Foreign keys enabled', tag: 'DB');
  }

  /// 带恢复能力的升级方法
  Future<void> _onUpgradeWithRecovery(Database db, int oldVersion, int newVersion) async {
    try {
      await _onUpgrade(db, oldVersion, newVersion);

      // 迁移成功
      await _migrationService.onMigrationComplete(
        newVersion: newVersion,
        success: true,
      );
    } catch (e) {
      // 迁移失败
      await _migrationService.onMigrationComplete(
        newVersion: newVersion,
        success: false,
        error: e.toString(),
      );

      _logger.error('Database migration failed: $e', tag: 'DB');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        date INTEGER NOT NULL,
        accountId TEXT NOT NULL,
        toAccountId TEXT,
        ledgerId TEXT NOT NULL DEFAULT 'default',
        isSplit INTEGER NOT NULL DEFAULT 0,
        isReimbursable INTEGER NOT NULL DEFAULT 0,
        isReimbursed INTEGER NOT NULL DEFAULT 0,
        tags TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER,
        source INTEGER NOT NULL DEFAULT 0,
        aiConfidence REAL,
        sourceFileLocalPath TEXT,
        sourceFileServerUrl TEXT,
        sourceFileType TEXT,
        sourceFileSize INTEGER,
        recognitionRawData TEXT,
        sourceFileExpiresAt INTEGER,
        externalId TEXT,
        externalSource INTEGER,
        importBatchId TEXT,
        rawMerchant TEXT,
        vaultId TEXT,
        moneyAge INTEGER,
        moneyAgeLevel TEXT,
        resourcePoolId TEXT,
        visibility INTEGER NOT NULL DEFAULT 1,
        locationJson TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');

    // Import batches table
    await db.execute('''
      CREATE TABLE import_batches (
        id TEXT PRIMARY KEY,
        fileName TEXT NOT NULL,
        fileFormat TEXT NOT NULL,
        totalCount INTEGER NOT NULL,
        importedCount INTEGER NOT NULL,
        skippedCount INTEGER NOT NULL,
        failedCount INTEGER NOT NULL DEFAULT 0,
        totalExpense REAL DEFAULT 0,
        totalIncome REAL DEFAULT 0,
        dateRangeStart INTEGER,
        dateRangeEnd INTEGER,
        createdAt INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        revokedAt INTEGER,
        errorLog TEXT
      )
    ''');

    // Create indexes for import deduplication
    await db.execute('CREATE INDEX idx_transactions_external ON transactions(externalId, externalSource)');
    await db.execute('CREATE INDEX idx_transactions_import_batch ON transactions(importBatchId)');
    await db.execute('CREATE INDEX idx_transactions_dedup ON transactions(date, amount, type, category)');
    await db.execute('CREATE INDEX idx_import_batches_status ON import_batches(status)');

    // Transaction splits table
    await db.execute('''
      CREATE TABLE transaction_splits (
        id TEXT PRIMARY KEY,
        transactionId TEXT NOT NULL,
        category TEXT NOT NULL,
        subcategory TEXT,
        amount REAL NOT NULL,
        note TEXT,
        FOREIGN KEY (transactionId) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // Accounts table
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        balance REAL NOT NULL,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isExpense INTEGER NOT NULL,
        parentId TEXT,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        isCustom INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');

    // Ledgers table
    await db.execute('''
      CREATE TABLE ledgers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        iconCode INTEGER,
        colorValue INTEGER,
        isDefault INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER,
        ownerId TEXT DEFAULT 'default_user',
        type TEXT DEFAULT 'personal',
        icon INTEGER,
        iconFontFamily TEXT,
        color INTEGER,
        memberIds TEXT,
        visibility TEXT DEFAULT 'members',
        inviteCode TEXT,
        inviteCodeExpiry TEXT,
        isArchived INTEGER DEFAULT 0,
        settings TEXT,
        coverImage TEXT
      )
    ''');

    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        period INTEGER NOT NULL,
        categoryId TEXT,
        ledgerId TEXT NOT NULL,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER,
        budgetType INTEGER NOT NULL DEFAULT 0,
        enableCarryover INTEGER NOT NULL DEFAULT 0,
        carryoverSurplusOnly INTEGER NOT NULL DEFAULT 1,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        deletedAt INTEGER
      )
    ''');

    // Budget carryover records table
    await db.execute('''
      CREATE TABLE budget_carryovers (
        id TEXT PRIMARY KEY,
        budgetId TEXT NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        carryoverAmount REAL NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (budgetId) REFERENCES budgets (id) ON DELETE CASCADE
      )
    ''');

    // Zero-based budget allocations table
    await db.execute('''
      CREATE TABLE zero_based_allocations (
        id TEXT PRIMARY KEY,
        budgetId TEXT NOT NULL,
        allocatedAmount REAL NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (budgetId) REFERENCES budgets (id) ON DELETE CASCADE
      )
    ''');

    // Templates table
    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        amount REAL,
        category TEXT NOT NULL,
        note TEXT,
        accountId TEXT NOT NULL,
        toAccountId TEXT,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        useCount INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER,
        lastUsedAt INTEGER
      )
    ''');

    // Recurring transactions table
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        accountId TEXT NOT NULL,
        toAccountId TEXT,
        frequency INTEGER NOT NULL,
        dayOfWeek INTEGER NOT NULL DEFAULT 1,
        dayOfMonth INTEGER NOT NULL DEFAULT 1,
        monthOfYear INTEGER NOT NULL DEFAULT 1,
        startDate INTEGER NOT NULL,
        endDate INTEGER,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        lastExecutedAt INTEGER,
        nextExecuteAt INTEGER,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER
      )
    ''');

    // Credit cards table
    await db.execute('''
      CREATE TABLE credit_cards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        creditLimit REAL NOT NULL,
        usedAmount REAL NOT NULL DEFAULT 0,
        billDay INTEGER NOT NULL,
        paymentDueDay INTEGER NOT NULL,
        currentBill REAL NOT NULL DEFAULT 0,
        minPayment REAL NOT NULL DEFAULT 0,
        lastBillDate INTEGER,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        bankName TEXT,
        cardNumber TEXT,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER
      )
    ''');

    // Savings goals table
    await db.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        type INTEGER NOT NULL,
        targetAmount REAL NOT NULL,
        currentAmount REAL NOT NULL DEFAULT 0,
        startDate INTEGER NOT NULL,
        targetDate INTEGER,
        linkedAccountId TEXT,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        completedAt INTEGER,
        isArchived INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        linkedCategoryId TEXT,
        monthlyExpenseLimit REAL,
        recurringFrequency INTEGER,
        recurringAmount REAL,
        nextDepositDate INTEGER,
        enableReminder INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Savings deposits table
    await db.execute('''
      CREATE TABLE savings_deposits (
        id TEXT PRIMARY KEY,
        goalId TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        date INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (goalId) REFERENCES savings_goals (id) ON DELETE CASCADE
      )
    ''');

    // Bill reminders table
    await db.execute('''
      CREATE TABLE bill_reminders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        amount REAL NOT NULL,
        frequency INTEGER NOT NULL,
        dayOfMonth INTEGER NOT NULL DEFAULT 1,
        dayOfWeek INTEGER,
        specificDate INTEGER,
        reminderDaysBefore INTEGER NOT NULL DEFAULT 3,
        reminderTimeHour INTEGER NOT NULL DEFAULT 9,
        reminderTimeMinute INTEGER NOT NULL DEFAULT 0,
        linkedAccountId TEXT,
        note TEXT,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        lastRemindedAt INTEGER,
        nextReminderDate INTEGER,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER
      )
    ''');

    // Investment accounts table
    await db.execute('''
      CREATE TABLE investment_accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        principal REAL NOT NULL DEFAULT 0,
        currentValue REAL NOT NULL DEFAULT 0,
        platform TEXT,
        code TEXT,
        note TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Debts table
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        type INTEGER NOT NULL,
        originalAmount REAL NOT NULL,
        currentBalance REAL NOT NULL,
        interestRate REAL NOT NULL,
        minimumPayment REAL NOT NULL,
        startDate INTEGER NOT NULL,
        targetPayoffDate INTEGER,
        paymentDay INTEGER NOT NULL DEFAULT 1,
        linkedAccountId TEXT,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        completedAt INTEGER,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Debt payments table
    await db.execute('''
      CREATE TABLE debt_payments (
        id TEXT PRIMARY KEY,
        debtId TEXT NOT NULL,
        amount REAL NOT NULL,
        principalPaid REAL NOT NULL,
        interestPaid REAL NOT NULL,
        balanceAfter REAL NOT NULL,
        note TEXT,
        date INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (debtId) REFERENCES debts (id) ON DELETE CASCADE
      )
    ''');

    // Ledger members table
    await db.execute('''
      CREATE TABLE ledger_members (
        id TEXT PRIMARY KEY,
        ledgerId TEXT NOT NULL,
        userId TEXT NOT NULL,
        userName TEXT NOT NULL,
        userEmail TEXT,
        userAvatar TEXT,
        role INTEGER NOT NULL,
        joinedAt INTEGER NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Member invites table
    await db.execute('''
      CREATE TABLE member_invites (
        id TEXT PRIMARY KEY,
        ledgerId TEXT NOT NULL,
        ledgerName TEXT NOT NULL,
        inviterId TEXT NOT NULL,
        inviterName TEXT NOT NULL,
        inviteeEmail TEXT,
        inviteCode TEXT,
        role INTEGER NOT NULL,
        status INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        expiresAt INTEGER NOT NULL,
        respondedAt INTEGER
      )
    ''');

    // Member budgets table
    await db.execute('''
      CREATE TABLE member_budgets (
        id TEXT PRIMARY KEY,
        ledgerId TEXT NOT NULL,
        memberId TEXT NOT NULL,
        memberName TEXT NOT NULL,
        monthlyLimit REAL NOT NULL,
        currentSpent REAL NOT NULL DEFAULT 0,
        requireApproval INTEGER NOT NULL DEFAULT 0,
        approvalThreshold REAL NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    // Expense approvals table
    await db.execute('''
      CREATE TABLE expense_approvals (
        id TEXT PRIMARY KEY,
        ledgerId TEXT NOT NULL,
        transactionId TEXT NOT NULL,
        requesterId TEXT NOT NULL,
        requesterName TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        status INTEGER NOT NULL,
        approverId TEXT,
        approverName TEXT,
        approverComment TEXT,
        createdAt INTEGER NOT NULL,
        respondedAt INTEGER
      )
    ''');

    // Sync metadata table - tracks sync status for each entity
    await db.execute('''
      CREATE TABLE sync_metadata (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        localId TEXT NOT NULL,
        serverId TEXT,
        syncStatus INTEGER NOT NULL DEFAULT 0,
        localUpdatedAt INTEGER NOT NULL,
        serverUpdatedAt INTEGER,
        lastSyncAt INTEGER,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0,
        UNIQUE(entityType, localId)
      )
    ''');

    // Sync queue table - stores pending sync operations for offline support
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        retryCount INTEGER DEFAULT 0,
        lastError TEXT,
        status INTEGER DEFAULT 0
      )
    ''');

    // ID mapping table - maps local IDs to server IDs
    await db.execute('''
      CREATE TABLE id_mapping (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        localId TEXT NOT NULL,
        serverId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        UNIQUE(entityType, localId),
        UNIQUE(entityType, serverId)
      )
    ''');

    // Create indexes for sync tables
    await db.execute('CREATE INDEX idx_sync_metadata_entity ON sync_metadata(entityType, localId)');
    await db.execute('CREATE INDEX idx_sync_metadata_status ON sync_metadata(syncStatus)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
    await db.execute('CREATE INDEX idx_id_mapping_local ON id_mapping(entityType, localId)');
    await db.execute('CREATE INDEX idx_id_mapping_server ON id_mapping(entityType, serverId)');

    // ==================== 2.0新增表：钱龄系统 ====================

    // Resource pools table - tracks each income as a resource pool for money age calculation
    await db.execute('''
      CREATE TABLE resource_pools (
        id TEXT PRIMARY KEY,
        incomeTransactionId TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        originalAmount REAL NOT NULL,
        remainingAmount REAL NOT NULL,
        ledgerId TEXT,
        accountId TEXT,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY (incomeTransactionId) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // Resource consumptions table - records how each expense consumes from resource pools
    await db.execute('''
      CREATE TABLE resource_consumptions (
        id TEXT PRIMARY KEY,
        resourcePoolId TEXT NOT NULL,
        expenseTransactionId TEXT NOT NULL,
        amount REAL NOT NULL,
        moneyAge INTEGER NOT NULL,
        consumedAt INTEGER NOT NULL,
        FOREIGN KEY (resourcePoolId) REFERENCES resource_pools (id) ON DELETE CASCADE,
        FOREIGN KEY (expenseTransactionId) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for resource pools and consumptions
    await db.execute('CREATE INDEX idx_resource_pools_remaining ON resource_pools(remainingAmount) WHERE remainingAmount > 0');
    await db.execute('CREATE INDEX idx_resource_pools_created ON resource_pools(createdAt)');
    await db.execute('CREATE INDEX idx_resource_pools_income ON resource_pools(incomeTransactionId)');
    await db.execute('CREATE INDEX idx_resource_consumptions_pool ON resource_consumptions(resourcePoolId)');
    await db.execute('CREATE INDEX idx_resource_consumptions_expense ON resource_consumptions(expenseTransactionId)');

    // ==================== 2.0新增表：小金库/零基预算系统 ====================

    // Budget vaults table - envelope budgeting system
    await db.execute('''
      CREATE TABLE budget_vaults (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        type INTEGER NOT NULL,
        targetAmount REAL NOT NULL DEFAULT 0,
        allocatedAmount REAL NOT NULL DEFAULT 0,
        spentAmount REAL NOT NULL DEFAULT 0,
        dueDate INTEGER,
        isRecurring INTEGER NOT NULL DEFAULT 0,
        recurrenceJson TEXT,
        linkedCategoryId TEXT,
        linkedCategoryIds TEXT,
        ledgerId TEXT NOT NULL,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        allocationType INTEGER NOT NULL DEFAULT 0,
        targetAllocation REAL,
        targetPercentage REAL
      )
    ''');

    // Vault allocations table - records income allocations to vaults
    await db.execute('''
      CREATE TABLE vault_allocations (
        id TEXT PRIMARY KEY,
        vaultId TEXT NOT NULL,
        incomeTransactionId TEXT,
        amount REAL NOT NULL,
        note TEXT,
        allocatedAt INTEGER NOT NULL,
        FOREIGN KEY (vaultId) REFERENCES budget_vaults (id) ON DELETE CASCADE
      )
    ''');

    // Vault transfers table - records transfers between vaults
    await db.execute('''
      CREATE TABLE vault_transfers (
        id TEXT PRIMARY KEY,
        fromVaultId TEXT NOT NULL,
        toVaultId TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        transferredAt INTEGER NOT NULL,
        FOREIGN KEY (fromVaultId) REFERENCES budget_vaults (id) ON DELETE CASCADE,
        FOREIGN KEY (toVaultId) REFERENCES budget_vaults (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for budget vaults
    await db.execute('CREATE INDEX idx_budget_vaults_ledger ON budget_vaults(ledgerId)');
    await db.execute('CREATE INDEX idx_budget_vaults_type ON budget_vaults(type)');
    await db.execute('CREATE INDEX idx_vault_allocations_vault ON vault_allocations(vaultId)');
    await db.execute('CREATE INDEX idx_vault_transfers_from ON vault_transfers(fromVaultId)');
    await db.execute('CREATE INDEX idx_vault_transfers_to ON vault_transfers(toVaultId)');

    // Create indexes for high-frequency query fields (Phase 1)
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_ledger ON transactions(ledgerId)');
    await db.execute('CREATE INDEX idx_transactions_account ON transactions(accountId)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
    await db.execute('CREATE INDEX idx_budgets_ledger ON budgets(ledgerId)');
    await db.execute('CREATE INDEX idx_categories_parent ON categories(parentId)');
    await db.execute('CREATE INDEX idx_accounts_default ON accounts(isDefault)');

    // Create indexes for soft delete (Phase 2)
    await db.execute('CREATE INDEX idx_transactions_deleted ON transactions(isDeleted)');
    await db.execute('CREATE INDEX idx_accounts_deleted ON accounts(isDeleted)');
    await db.execute('CREATE INDEX idx_categories_deleted ON categories(isDeleted)');
    await db.execute('CREATE INDEX idx_ledgers_deleted ON ledgers(isDeleted)');
    await db.execute('CREATE INDEX idx_budgets_deleted ON budgets(isDeleted)');

    // Create active record views (Phase 2.3.6)
    // These views filter out soft-deleted records for convenient querying
    await db.execute('''
      CREATE VIEW active_transactions AS
      SELECT * FROM transactions WHERE isDeleted = 0
    ''');

    await db.execute('''
      CREATE VIEW active_accounts AS
      SELECT * FROM accounts WHERE isDeleted = 0
    ''');

    await db.execute('''
      CREATE VIEW active_categories AS
      SELECT * FROM categories WHERE isDeleted = 0
    ''');

    await db.execute('''
      CREATE VIEW active_ledgers AS
      SELECT * FROM ledgers WHERE isDeleted = 0
    ''');

    await db.execute('''
      CREATE VIEW active_budgets AS
      SELECT * FROM budgets WHERE isDeleted = 0
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add isSplit column to transactions table
      await db.execute('ALTER TABLE transactions ADD COLUMN isSplit INTEGER NOT NULL DEFAULT 0');

      // Create transaction_splits table
      await db.execute('''
        CREATE TABLE transaction_splits (
          id TEXT PRIMARY KEY,
          transactionId TEXT NOT NULL,
          category TEXT NOT NULL,
          subcategory TEXT,
          amount REAL NOT NULL,
          note TEXT,
          FOREIGN KEY (transactionId) REFERENCES transactions (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      // Create credit_cards table
      await db.execute('''
        CREATE TABLE credit_cards (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          creditLimit REAL NOT NULL,
          usedAmount REAL NOT NULL DEFAULT 0,
          billDay INTEGER NOT NULL,
          paymentDueDay INTEGER NOT NULL,
          currentBill REAL NOT NULL DEFAULT 0,
          minPayment REAL NOT NULL DEFAULT 0,
          lastBillDate INTEGER,
          iconCode INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          bankName TEXT,
          cardNumber TEXT,
          isEnabled INTEGER NOT NULL DEFAULT 1,
          createdAt INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      // Create savings_goals table
      await db.execute('''
        CREATE TABLE savings_goals (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          type INTEGER NOT NULL,
          targetAmount REAL NOT NULL,
          currentAmount REAL NOT NULL DEFAULT 0,
          startDate INTEGER NOT NULL,
          targetDate INTEGER,
          linkedAccountId TEXT,
          iconCode INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          completedAt INTEGER,
          isArchived INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL
        )
      ''');

      // Create savings_deposits table
      await db.execute('''
        CREATE TABLE savings_deposits (
          id TEXT PRIMARY KEY,
          goalId TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          date INTEGER NOT NULL,
          createdAt INTEGER NOT NULL,
          FOREIGN KEY (goalId) REFERENCES savings_goals (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 5) {
      // Create bill_reminders table
      await db.execute('''
        CREATE TABLE bill_reminders (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type INTEGER NOT NULL,
          amount REAL NOT NULL,
          frequency INTEGER NOT NULL,
          dayOfMonth INTEGER NOT NULL DEFAULT 1,
          dayOfWeek INTEGER,
          specificDate INTEGER,
          reminderDaysBefore INTEGER NOT NULL DEFAULT 3,
          reminderTimeHour INTEGER NOT NULL DEFAULT 9,
          reminderTimeMinute INTEGER NOT NULL DEFAULT 0,
          linkedAccountId TEXT,
          note TEXT,
          iconCode INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          isEnabled INTEGER NOT NULL DEFAULT 1,
          lastRemindedAt INTEGER,
          nextReminderDate INTEGER,
          createdAt INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      // Create investment_accounts table
      await db.execute('''
        CREATE TABLE investment_accounts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type INTEGER NOT NULL,
          principal REAL NOT NULL DEFAULT 0,
          currentValue REAL NOT NULL DEFAULT 0,
          platform TEXT,
          code TEXT,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      // Create debts table
      await db.execute('''
        CREATE TABLE debts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          type INTEGER NOT NULL,
          originalAmount REAL NOT NULL,
          currentBalance REAL NOT NULL,
          interestRate REAL NOT NULL,
          minimumPayment REAL NOT NULL,
          startDate INTEGER NOT NULL,
          targetPayoffDate INTEGER,
          paymentDay INTEGER NOT NULL DEFAULT 1,
          linkedAccountId TEXT,
          iconCode INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          completedAt INTEGER,
          createdAt INTEGER NOT NULL
        )
      ''');

      // Create debt_payments table
      await db.execute('''
        CREATE TABLE debt_payments (
          id TEXT PRIMARY KEY,
          debtId TEXT NOT NULL,
          amount REAL NOT NULL,
          principalPaid REAL NOT NULL,
          interestPaid REAL NOT NULL,
          balanceAfter REAL NOT NULL,
          note TEXT,
          date INTEGER NOT NULL,
          createdAt INTEGER NOT NULL,
          FOREIGN KEY (debtId) REFERENCES debts (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 9) {
      // Add monthly expense goal and recurring deposit fields to savings_goals
      await db.execute('ALTER TABLE savings_goals ADD COLUMN linkedCategoryId TEXT');
      await db.execute('ALTER TABLE savings_goals ADD COLUMN monthlyExpenseLimit REAL');
      await db.execute('ALTER TABLE savings_goals ADD COLUMN recurringFrequency INTEGER');
      await db.execute('ALTER TABLE savings_goals ADD COLUMN recurringAmount REAL');
      await db.execute('ALTER TABLE savings_goals ADD COLUMN nextDepositDate INTEGER');
      await db.execute('ALTER TABLE savings_goals ADD COLUMN enableReminder INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 10) {
      // Add reimbursable and tags fields to transactions
      await db.execute('ALTER TABLE transactions ADD COLUMN isReimbursable INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE transactions ADD COLUMN isReimbursed INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE transactions ADD COLUMN tags TEXT');
    }

    if (oldVersion < 11) {
      // Create member collaboration tables
      await db.execute('''
        CREATE TABLE ledger_members (
          id TEXT PRIMARY KEY,
          ledgerId TEXT NOT NULL,
          userId TEXT NOT NULL,
          userName TEXT NOT NULL,
          userEmail TEXT,
          userAvatar TEXT,
          role INTEGER NOT NULL,
          joinedAt INTEGER NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE member_invites (
          id TEXT PRIMARY KEY,
          ledgerId TEXT NOT NULL,
          ledgerName TEXT NOT NULL,
          inviterId TEXT NOT NULL,
          inviterName TEXT NOT NULL,
          inviteeEmail TEXT,
          inviteCode TEXT,
          role INTEGER NOT NULL,
          status INTEGER NOT NULL,
          createdAt INTEGER NOT NULL,
          expiresAt INTEGER NOT NULL,
          respondedAt INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE member_budgets (
          id TEXT PRIMARY KEY,
          ledgerId TEXT NOT NULL,
          memberId TEXT NOT NULL,
          memberName TEXT NOT NULL,
          monthlyLimit REAL NOT NULL,
          currentSpent REAL NOT NULL DEFAULT 0,
          requireApproval INTEGER NOT NULL DEFAULT 0,
          approvalThreshold REAL NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE expense_approvals (
          id TEXT PRIMARY KEY,
          ledgerId TEXT NOT NULL,
          transactionId TEXT NOT NULL,
          requesterId TEXT NOT NULL,
          requesterName TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          note TEXT,
          status INTEGER NOT NULL,
          approverId TEXT,
          approverName TEXT,
          approverComment TEXT,
          createdAt INTEGER NOT NULL,
          respondedAt INTEGER
        )
      ''');
    }

    if (oldVersion < 12) {
      // Create sync tables for data synchronization

      // Sync metadata table - tracks sync status for each entity
      await db.execute('''
        CREATE TABLE sync_metadata (
          id TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          localId TEXT NOT NULL,
          serverId TEXT,
          syncStatus INTEGER NOT NULL DEFAULT 0,
          localUpdatedAt INTEGER NOT NULL,
          serverUpdatedAt INTEGER,
          lastSyncAt INTEGER,
          version INTEGER DEFAULT 1,
          isDeleted INTEGER DEFAULT 0,
          UNIQUE(entityType, localId)
        )
      ''');

      // Sync queue table - stores pending sync operations for offline support
      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          entityId TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          retryCount INTEGER DEFAULT 0,
          lastError TEXT,
          status INTEGER DEFAULT 0
        )
      ''');

      // ID mapping table - maps local IDs to server IDs
      await db.execute('''
        CREATE TABLE id_mapping (
          id TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          localId TEXT NOT NULL,
          serverId TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          UNIQUE(entityType, localId),
          UNIQUE(entityType, serverId)
        )
      ''');

      // Create indexes for sync tables
      await db.execute('CREATE INDEX idx_sync_metadata_entity ON sync_metadata(entityType, localId)');
      await db.execute('CREATE INDEX idx_sync_metadata_status ON sync_metadata(syncStatus)');
      await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
      await db.execute('CREATE INDEX idx_id_mapping_local ON id_mapping(entityType, localId)');
      await db.execute('CREATE INDEX idx_id_mapping_server ON id_mapping(entityType, serverId)');
    }

    if (oldVersion < 13) {
      // Add source file fields to transactions table for AI recognition source tracking
      await db.execute('ALTER TABLE transactions ADD COLUMN source INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE transactions ADD COLUMN aiConfidence REAL');
      await db.execute('ALTER TABLE transactions ADD COLUMN sourceFileLocalPath TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN sourceFileServerUrl TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN sourceFileType TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN sourceFileSize INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN recognitionRawData TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN sourceFileExpiresAt INTEGER');
    }

    if (oldVersion < 14) {
      // Add batch import fields to transactions table
      await db.execute('ALTER TABLE transactions ADD COLUMN externalId TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN externalSource INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN importBatchId TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN rawMerchant TEXT');

      // Create import batches table
      await db.execute('''
        CREATE TABLE import_batches (
          id TEXT PRIMARY KEY,
          fileName TEXT NOT NULL,
          fileFormat TEXT NOT NULL,
          totalCount INTEGER NOT NULL,
          importedCount INTEGER NOT NULL,
          skippedCount INTEGER NOT NULL,
          failedCount INTEGER NOT NULL DEFAULT 0,
          totalExpense REAL DEFAULT 0,
          totalIncome REAL DEFAULT 0,
          dateRangeStart INTEGER,
          dateRangeEnd INTEGER,
          createdAt INTEGER NOT NULL,
          status INTEGER NOT NULL DEFAULT 0,
          revokedAt INTEGER,
          errorLog TEXT
        )
      ''');

      // Create indexes for efficient deduplication and batch management
      await db.execute('CREATE INDEX idx_transactions_external ON transactions(externalId, externalSource)');
      await db.execute('CREATE INDEX idx_transactions_import_batch ON transactions(importBatchId)');
      await db.execute('CREATE INDEX idx_transactions_dedup ON transactions(date, amount, type, category)');
      await db.execute('CREATE INDEX idx_import_batches_status ON import_batches(status)');
    }

    if (oldVersion < 15) {
      // ==================== 2.0升级：钱龄系统和小金库系统 ====================

      // Add vaultId and moneyAge fields to transactions table
      await db.execute('ALTER TABLE transactions ADD COLUMN vaultId TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN moneyAge INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN locationJson TEXT');

      // Create resource pools table for money age calculation
      await db.execute('''
        CREATE TABLE resource_pools (
          id TEXT PRIMARY KEY,
          incomeTransactionId TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          originalAmount REAL NOT NULL,
          remainingAmount REAL NOT NULL,
          ledgerId TEXT,
          accountId TEXT,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY (incomeTransactionId) REFERENCES transactions (id) ON DELETE CASCADE
        )
      ''');

      // Create resource consumptions table
      await db.execute('''
        CREATE TABLE resource_consumptions (
          id TEXT PRIMARY KEY,
          resourcePoolId TEXT NOT NULL,
          expenseTransactionId TEXT NOT NULL,
          amount REAL NOT NULL,
          moneyAge INTEGER NOT NULL,
          consumedAt INTEGER NOT NULL,
          FOREIGN KEY (resourcePoolId) REFERENCES resource_pools (id) ON DELETE CASCADE,
          FOREIGN KEY (expenseTransactionId) REFERENCES transactions (id) ON DELETE CASCADE
        )
      ''');

      // Create budget vaults table (envelope budgeting)
      await db.execute('''
        CREATE TABLE budget_vaults (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          iconCode INTEGER NOT NULL,
          colorValue INTEGER NOT NULL,
          type INTEGER NOT NULL,
          targetAmount REAL NOT NULL DEFAULT 0,
          allocatedAmount REAL NOT NULL DEFAULT 0,
          spentAmount REAL NOT NULL DEFAULT 0,
          dueDate INTEGER,
          isRecurring INTEGER NOT NULL DEFAULT 0,
          recurrenceJson TEXT,
          linkedCategoryId TEXT,
          linkedCategoryIds TEXT,
          ledgerId TEXT NOT NULL,
          isEnabled INTEGER NOT NULL DEFAULT 1,
          sortOrder INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          allocationType INTEGER NOT NULL DEFAULT 0,
          targetAllocation REAL,
          targetPercentage REAL
        )
      ''');

      // Create vault allocations table
      await db.execute('''
        CREATE TABLE vault_allocations (
          id TEXT PRIMARY KEY,
          vaultId TEXT NOT NULL,
          incomeTransactionId TEXT,
          amount REAL NOT NULL,
          note TEXT,
          allocatedAt INTEGER NOT NULL,
          FOREIGN KEY (vaultId) REFERENCES budget_vaults (id) ON DELETE CASCADE
        )
      ''');

      // Create vault transfers table
      await db.execute('''
        CREATE TABLE vault_transfers (
          id TEXT PRIMARY KEY,
          fromVaultId TEXT NOT NULL,
          toVaultId TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          transferredAt INTEGER NOT NULL,
          FOREIGN KEY (fromVaultId) REFERENCES budget_vaults (id) ON DELETE CASCADE,
          FOREIGN KEY (toVaultId) REFERENCES budget_vaults (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for 2.0 tables
      await db.execute('CREATE INDEX idx_resource_pools_remaining ON resource_pools(remainingAmount) WHERE remainingAmount > 0');
      await db.execute('CREATE INDEX idx_resource_pools_created ON resource_pools(createdAt)');
      await db.execute('CREATE INDEX idx_resource_pools_income ON resource_pools(incomeTransactionId)');
      await db.execute('CREATE INDEX idx_resource_consumptions_pool ON resource_consumptions(resourcePoolId)');
      await db.execute('CREATE INDEX idx_resource_consumptions_expense ON resource_consumptions(expenseTransactionId)');
      await db.execute('CREATE INDEX idx_budget_vaults_ledger ON budget_vaults(ledgerId)');
      await db.execute('CREATE INDEX idx_budget_vaults_type ON budget_vaults(type)');
      await db.execute('CREATE INDEX idx_vault_allocations_vault ON vault_allocations(vaultId)');
      await db.execute('CREATE INDEX idx_vault_transfers_from ON vault_transfers(fromVaultId)');
      await db.execute('CREATE INDEX idx_vault_transfers_to ON vault_transfers(toVaultId)');
      await db.execute('CREATE INDEX idx_transactions_vault ON transactions(vaultId)');
    }

    // ==================== 版本16：索引优化和 updatedAt 字段 ====================
    if (oldVersion < 16) {
      _logger.info('Migrating to version 16: Adding indexes and updatedAt fields', tag: 'DB');

      // 1. 添加高频查询字段索引
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_ledger ON transactions(ledgerId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(accountId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_ledger ON budgets(ledgerId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parentId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_default ON accounts(isDefault)');

      // 2. 为缺少 updatedAt 的表添加字段
      // accounts 表
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN updatedAt INTEGER');
        await db.execute('UPDATE accounts SET updatedAt = createdAt WHERE updatedAt IS NULL');
      } catch (e) {
        _logger.debug('accounts.updatedAt may already exist: $e', tag: 'DB');
      }

      // categories 表
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN updatedAt INTEGER');
        // categories 没有 createdAt，使用当前时间
        await db.execute('UPDATE categories SET updatedAt = ${DateTime.now().millisecondsSinceEpoch} WHERE updatedAt IS NULL');
      } catch (e) {
        _logger.debug('categories.updatedAt may already exist: $e', tag: 'DB');
      }

      // ledgers 表
      try {
        await db.execute('ALTER TABLE ledgers ADD COLUMN updatedAt INTEGER');
        await db.execute('UPDATE ledgers SET updatedAt = createdAt WHERE updatedAt IS NULL');
      } catch (e) {
        _logger.debug('ledgers.updatedAt may already exist: $e', tag: 'DB');
      }

      // templates 表
      try {
        await db.execute('ALTER TABLE templates ADD COLUMN updatedAt INTEGER');
        await db.execute('UPDATE templates SET updatedAt = createdAt WHERE updatedAt IS NULL');
      } catch (e) {
        _logger.debug('templates.updatedAt may already exist: $e', tag: 'DB');
      }

      // recurring_transactions 表
      try {
        await db.execute('ALTER TABLE recurring_transactions ADD COLUMN updatedAt INTEGER');
        await db.execute('UPDATE recurring_transactions SET updatedAt = createdAt WHERE updatedAt IS NULL');
      } catch (e) {
        _logger.debug('recurring_transactions.updatedAt may already exist: $e', tag: 'DB');
      }

      // credit_cards 表
      try {
        await db.execute('ALTER TABLE credit_cards ADD COLUMN updatedAt INTEGER');
        await db.execute('UPDATE credit_cards SET updatedAt = createdAt WHERE updatedAt IS NULL');
      } catch (e) {
        _logger.debug('credit_cards.updatedAt may already exist: $e', tag: 'DB');
      }

      // bill_reminders 表
      try {
        await db.execute('ALTER TABLE bill_reminders ADD COLUMN updatedAt INTEGER');
        await db.execute('UPDATE bill_reminders SET updatedAt = createdAt WHERE updatedAt IS NULL');
      } catch (e) {
        _logger.debug('bill_reminders.updatedAt may already exist: $e', tag: 'DB');
      }

      // budgets 表
      try {
        await db.execute('ALTER TABLE budgets ADD COLUMN updatedAt INTEGER');
        await db.execute('UPDATE budgets SET updatedAt = createdAt WHERE updatedAt IS NULL');
      } catch (e) {
        _logger.debug('budgets.updatedAt may already exist: $e', tag: 'DB');
      }

      _logger.info('Version 16 migration completed', tag: 'DB');
    }

    // ==================== 版本17：软删除支持 ====================
    if (oldVersion < 17) {
      _logger.info('Migrating to version 17: Adding soft delete support', tag: 'DB');

      // 为核心业务表添加软删除字段
      final tablesForSoftDelete = [
        'transactions',
        'accounts',
        'categories',
        'ledgers',
        'budgets',
      ];

      for (final table in tablesForSoftDelete) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE $table ADD COLUMN deletedAt INTEGER');
        } catch (e) {
          _logger.debug('$table soft delete columns may already exist: $e', tag: 'DB');
        }
      }

      // 创建软删除索引以加速查询
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_deleted ON transactions(isDeleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_deleted ON accounts(isDeleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_deleted ON categories(isDeleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ledgers_deleted ON ledgers(isDeleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_deleted ON budgets(isDeleted)');

      _logger.info('Version 17 migration completed', tag: 'DB');
    }

    // ==================== 版本18：活动记录视图与外键支持 ====================
    if (oldVersion < 18) {
      _logger.info('Migrating to version 18: Adding active record views and foreign key support', tag: 'DB');

      // 创建活动记录视图（过滤已删除记录）
      await db.execute('''
        CREATE VIEW IF NOT EXISTS active_transactions AS
        SELECT * FROM transactions WHERE isDeleted = 0
      ''');

      await db.execute('''
        CREATE VIEW IF NOT EXISTS active_accounts AS
        SELECT * FROM accounts WHERE isDeleted = 0
      ''');

      await db.execute('''
        CREATE VIEW IF NOT EXISTS active_categories AS
        SELECT * FROM categories WHERE isDeleted = 0
      ''');

      await db.execute('''
        CREATE VIEW IF NOT EXISTS active_ledgers AS
        SELECT * FROM ledgers WHERE isDeleted = 0
      ''');

      await db.execute('''
        CREATE VIEW IF NOT EXISTS active_budgets AS
        SELECT * FROM budgets WHERE isDeleted = 0
      ''');

      _logger.info('Version 18 migration completed', tag: 'DB');
    }

    // Version 19: Add missing columns to ledgers table to match Ledger model
    if (oldVersion < 19) {
      _logger.info('Starting version 19 migration...', tag: 'DB');

      // List of columns to add with their definitions
      final columnsToAdd = <String, String>{
        'ownerId': 'TEXT DEFAULT \'default_user\'',
        'type': 'TEXT DEFAULT \'personal\'',
        'icon': 'INTEGER',
        'iconFontFamily': 'TEXT',
        'color': 'INTEGER',
        'memberIds': 'TEXT',
        'visibility': 'TEXT DEFAULT \'members\'',
        'inviteCode': 'TEXT',
        'inviteCodeExpiry': 'TEXT',
        'isArchived': 'INTEGER DEFAULT 0',
        'settings': 'TEXT',
        'coverImage': 'TEXT',
      };

      for (final entry in columnsToAdd.entries) {
        try {
          await db.execute('''
            ALTER TABLE ledgers ADD COLUMN ${entry.key} ${entry.value}
          ''');
          _logger.info('Added ${entry.key} column to ledgers table', tag: 'DB');
        } catch (e) {
          // Column might already exist, that's OK
          _logger.debug('Column ${entry.key} may already exist: $e', tag: 'DB');
        }
      }

      // Migrate existing data: copy iconCode to icon, colorValue to color
      try {
        await db.execute('''
          UPDATE ledgers SET icon = iconCode WHERE icon IS NULL AND iconCode IS NOT NULL
        ''');
        await db.execute('''
          UPDATE ledgers SET color = colorValue WHERE color IS NULL AND colorValue IS NOT NULL
        ''');
        _logger.info('Migrated iconCode/colorValue to icon/color', tag: 'DB');
      } catch (e) {
        _logger.debug('Icon/color migration skipped: $e', tag: 'DB');
      }

      _logger.info('Version 19 migration completed', tag: 'DB');
    }
  }

  // ==================== 事务支持 ====================

  /// 在数据库事务中执行操作
  ///
  /// 如果操作抛出异常，所有更改都会回滚
  /// 使用示例：
  /// ```dart
  /// await db.runInTransaction(() async {
  ///   await db.updateAccount(fromAccount);
  ///   await db.updateAccount(toAccount);
  /// });
  /// ```
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 临时替换数据库实例以使用事务
      _database = txn as Database;
      try {
        final result = await action();
        return result;
      } finally {
        // 恢复原始数据库连接
        _database = db;
      }
    });
  }

  /// 批量执行操作（性能优化）
  ///
  /// 使用示例：
  /// ```dart
  /// await db.runBatch((batch) {
  ///   for (final account in accounts) {
  ///     batch.update('accounts', account.toMap(),
  ///       where: 'id = ?', whereArgs: [account.id]);
  ///   }
  /// });
  /// ```
  @override
  Future<List<Object?>> runBatch(void Function(Batch batch) operations) async {
    final db = await database;
    final batch = db.batch();
    operations(batch);
    return await batch.commit();
  }

  // Transaction CRUD
  @override
  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;
    final result = await db.insert('transactions', {
      'id': transaction.id,
      'type': transaction.type.index,
      'amount': transaction.amount,
      'category': transaction.category,
      'note': transaction.note,
      'date': transaction.date.millisecondsSinceEpoch,
      'accountId': transaction.accountId,
      'toAccountId': transaction.toAccountId,
      'ledgerId': 'default',
      'isSplit': transaction.isSplit ? 1 : 0,
      'isReimbursable': transaction.isReimbursable ? 1 : 0,
      'isReimbursed': transaction.isReimbursed ? 1 : 0,
      'tags': transaction.tags?.join(','),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'source': transaction.source.index,
      'aiConfidence': transaction.aiConfidence,
      'sourceFileLocalPath': transaction.sourceFileLocalPath,
      'sourceFileServerUrl': transaction.sourceFileServerUrl,
      'sourceFileType': transaction.sourceFileType,
      'sourceFileSize': transaction.sourceFileSize,
      'recognitionRawData': transaction.recognitionRawData,
      'sourceFileExpiresAt': transaction.sourceFileExpiresAt?.millisecondsSinceEpoch,
      'externalId': transaction.externalId,
      'externalSource': transaction.externalSource?.index,
      'importBatchId': transaction.importBatchId,
      'rawMerchant': transaction.rawMerchant,
      'vaultId': transaction.vaultId,
      'moneyAge': transaction.moneyAge,
      'moneyAgeLevel': transaction.moneyAgeLevel,
      'resourcePoolId': transaction.resourcePoolId,
      'visibility': transaction.visibility,
      'locationJson': transaction.location != null
          ? '${transaction.location!.latitude},${transaction.location!.longitude},${transaction.location!.placeName ?? ''},${transaction.location!.address ?? ''}'
          : null,
    });

    // Insert splits if this is a split transaction
    if (transaction.isSplit && transaction.splits != null) {
      for (final split in transaction.splits!) {
        await insertTransactionSplit(split);
      }
    }

    return result;
  }

  @override
  Future<List<model.Transaction>> getTransactions({bool includeDeleted = false}) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'date DESC',
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      final isSplit = (map['isSplit'] as int?) == 1;
      List<TransactionSplit>? splits;

      if (isSplit) {
        splits = await getTransactionSplits(map['id'] as String);
      }

      final tagsString = map['tags'] as String?;
      final sourceFileExpiresAtMs = map['sourceFileExpiresAt'] as int?;

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int],
        amount: map['amount'] as double,
        category: map['category'] as String,
        note: map['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['accountId'] as String,
        toAccountId: map['toAccountId'] as String?,
        isSplit: isSplit,
        splits: splits,
        isReimbursable: (map['isReimbursable'] as int?) == 1,
        isReimbursed: (map['isReimbursed'] as int?) == 1,
        tags: tagsString != null && tagsString.isNotEmpty
            ? tagsString.split(',')
            : null,
        source: model.TransactionSource.values[(map['source'] as int?) ?? 0],
        aiConfidence: map['aiConfidence'] as double?,
        sourceFileLocalPath: map['sourceFileLocalPath'] as String?,
        sourceFileServerUrl: map['sourceFileServerUrl'] as String?,
        sourceFileType: map['sourceFileType'] as String?,
        sourceFileSize: map['sourceFileSize'] as int?,
        recognitionRawData: map['recognitionRawData'] as String?,
        sourceFileExpiresAt: sourceFileExpiresAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(sourceFileExpiresAtMs)
            : null,
        externalId: map['externalId'] as String?,
        externalSource: map['externalSource'] != null
            ? model.ExternalSource.values[map['externalSource'] as int]
            : null,
        importBatchId: map['importBatchId'] as String?,
        rawMerchant: map['rawMerchant'] as String?,
        vaultId: map['vaultId'] as String?,
        moneyAge: map['moneyAge'] as int?,
        moneyAgeLevel: map['moneyAgeLevel'] as String?,
        resourcePoolId: map['resourcePoolId'] as String?,
        visibility: (map['visibility'] as int?) ?? 1,
        location: _parseLocationJson(map['locationJson'] as String?),
      ));
    }

    return transactions;
  }

  @override
  Future<int> updateTransaction(model.Transaction transaction) async {
    final db = await database;

    // Update the main transaction
    final result = await db.update(
      'transactions',
      {
        'type': transaction.type.index,
        'amount': transaction.amount,
        'category': transaction.category,
        'note': transaction.note,
        'date': transaction.date.millisecondsSinceEpoch,
        'accountId': transaction.accountId,
        'toAccountId': transaction.toAccountId,
        'isSplit': transaction.isSplit ? 1 : 0,
        'isReimbursable': transaction.isReimbursable ? 1 : 0,
        'isReimbursed': transaction.isReimbursed ? 1 : 0,
        'tags': transaction.tags?.join(','),
        'source': transaction.source.index,
        'aiConfidence': transaction.aiConfidence,
        'sourceFileLocalPath': transaction.sourceFileLocalPath,
        'sourceFileServerUrl': transaction.sourceFileServerUrl,
        'sourceFileType': transaction.sourceFileType,
        'sourceFileSize': transaction.sourceFileSize,
        'recognitionRawData': transaction.recognitionRawData,
        'sourceFileExpiresAt': transaction.sourceFileExpiresAt?.millisecondsSinceEpoch,
        'externalId': transaction.externalId,
        'externalSource': transaction.externalSource?.index,
        'importBatchId': transaction.importBatchId,
        'rawMerchant': transaction.rawMerchant,
        'vaultId': transaction.vaultId,
        'moneyAge': transaction.moneyAge,
        'moneyAgeLevel': transaction.moneyAgeLevel,
        'resourcePoolId': transaction.resourcePoolId,
        'visibility': transaction.visibility,
        'locationJson': transaction.location != null
            ? '${transaction.location!.latitude},${transaction.location!.longitude},${transaction.location!.placeName ?? ''},${transaction.location!.address ?? ''}'
            : null,
      },
      where: 'id = ?',
      whereArgs: [transaction.id],
    );

    // Update splits: delete old and insert new
    await deleteTransactionSplits(transaction.id);
    if (transaction.isSplit && transaction.splits != null) {
      for (final split in transaction.splits!) {
        await insertTransactionSplit(split);
      }
    }

    return result;
  }

  @override
  Future<int> deleteTransaction(String id) async {
    final db = await database;
    // Splits will be deleted automatically due to CASCADE
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Transaction Split CRUD
  @override
  Future<int> insertTransactionSplit(TransactionSplit split) async {
    final db = await database;
    return await db.insert('transaction_splits', split.toMap());
  }

  @override
  Future<List<TransactionSplit>> getTransactionSplits(String transactionId) async {
    final db = await database;
    final maps = await db.query(
      'transaction_splits',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    return maps.map((map) => TransactionSplit.fromMap(map)).toList();
  }

  @override
  Future<int> deleteTransactionSplits(String transactionId) async {
    final db = await database;
    return await db.delete(
      'transaction_splits',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
  }

  // Account CRUD
  @override
  Future<int> insertAccount(Account account) async {
    final db = await database;
    return await db.insert('accounts', {
      'id': account.id,
      'name': account.name,
      'type': account.type.index,
      'balance': account.balance,
      'iconCode': account.icon.codePoint,
      'colorValue': account.color.toARGB32(),
      'isDefault': account.isDefault ? 1 : 0,
      'createdAt': account.createdAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<Account>> getAccounts({bool includeDeleted = false}) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: includeDeleted ? null : 'isDeleted = 0',
    );
    return maps.map((map) => Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AccountType.values[map['type'] as int],
      balance: map['balance'] as double,
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] as int),
      isDefault: (map['isDefault'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    )).toList();
  }

  @override
  Future<int> updateAccount(Account account) async {
    final db = await database;
    return await db.update(
      'accounts',
      {
        'name': account.name,
        'type': account.type.index,
        'balance': account.balance,
        'iconCode': account.icon.codePoint,
        'colorValue': account.color.toARGB32(),
        'isDefault': account.isDefault ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  @override
  Future<int> deleteAccount(String id) async {
    final db = await database;
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // Category CRUD
  @override
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', {
      'id': category.id,
      'name': category.name,
      'iconCode': category.icon.codePoint,
      'colorValue': category.color.toARGB32(),
      'isExpense': category.isExpense ? 1 : 0,
      'parentId': category.parentId,
      'sortOrder': category.sortOrder,
      'isCustom': category.isCustom ? 1 : 0,
    });
  }

  @override
  Future<List<Category>> getCategories({bool includeDeleted = false}) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: includeDeleted ? null : 'isDeleted = 0',
      orderBy: 'sortOrder ASC',
    );
    return maps.map((map) => Category(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] as int),
      isExpense: (map['isExpense'] as int) == 1,
      parentId: map['parentId'] as String?,
      sortOrder: map['sortOrder'] as int,
      isCustom: (map['isCustom'] as int) == 1,
    )).toList();
  }

  @override
  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      {
        'name': category.name,
        'iconCode': category.icon.codePoint,
        'colorValue': category.color.toARGB32(),
        'isExpense': category.isExpense ? 1 : 0,
        'parentId': category.parentId,
        'sortOrder': category.sortOrder,
        'isCustom': category.isCustom ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<int> deleteCategory(String id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Ledger CRUD
  @override
  Future<int> insertLedger(Ledger ledger) async {
    final db = await database;
    return await db.insert('ledgers', {
      'id': ledger.id,
      'name': ledger.name,
      'description': ledger.description,
      'iconCode': ledger.icon.codePoint,
      'colorValue': ledger.color.toARGB32(),
      'isDefault': ledger.isDefault ? 1 : 0,
      'createdAt': ledger.createdAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<Ledger>> getLedgers({bool includeDeleted = false}) async {
    final db = await database;
    final maps = await db.query(
      'ledgers',
      where: includeDeleted ? null : 'isDeleted = 0',
    );
    return maps.map((map) {
      // 兼容新旧列名: icon/iconCode, color/colorValue
      final iconCode = map['icon'] ?? map['iconCode'];
      final colorValue = map['color'] ?? map['colorValue'];
      final iconFontFamily = map['iconFontFamily'] as String? ?? 'MaterialIcons';

      // 兼容 createdAt 的两种格式: int (毫秒时间戳) 或 String (ISO8601)
      DateTime createdAt;
      final createdAtValue = map['createdAt'];
      if (createdAtValue is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
      } else if (createdAtValue is String) {
        createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }

      // 安全转换 int 值，兼容 String 和 int 类型
      int safeInt(dynamic value, int defaultValue) {
        if (value == null) return defaultValue;
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? defaultValue;
        return defaultValue;
      }

      return Ledger(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        icon: IconData(safeInt(iconCode, 0xe88a), fontFamily: iconFontFamily), // 默认 home 图标
        color: Color(safeInt(colorValue, 0xFF2196F3)), // 默认蓝色
        isDefault: safeInt(map['isDefault'], 0) == 1,
        createdAt: createdAt,
        ownerId: (map['ownerId'] as String?) ?? 'default_user',
      );
    }).toList();
  }

  /// Get the default ledger, or the first ledger if none is marked as default
  @override
  Future<Ledger?> getDefaultLedger() async {
    final db = await database;
    // First try to find the default ledger (excluding deleted)
    var maps = await db.query('ledgers', where: 'isDefault = 1 AND isDeleted = 0', limit: 1);
    if (maps.isEmpty) {
      // Fall back to first ledger (excluding deleted)
      maps = await db.query('ledgers', where: 'isDeleted = 0', limit: 1);
    }
    if (maps.isEmpty) return null;

    final map = maps.first;
    // 兼容新旧列名: icon/iconCode, color/colorValue
    final iconCode = map['icon'] ?? map['iconCode'];
    final colorValue = map['color'] ?? map['colorValue'];
    final iconFontFamily = map['iconFontFamily'] as String? ?? 'MaterialIcons';

    // 兼容 createdAt 的两种格式: int (毫秒时间戳) 或 String (ISO8601)
    DateTime createdAt;
    final createdAtValue = map['createdAt'];
    if (createdAtValue is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
    } else if (createdAtValue is String) {
      createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    // 安全转换 int 值，兼容 String 和 int 类型
    int safeInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return Ledger(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: IconData(safeInt(iconCode, 0xe88a), fontFamily: iconFontFamily),
      color: Color(safeInt(colorValue, 0xFF2196F3)),
      isDefault: safeInt(map['isDefault'], 0) == 1,
      createdAt: createdAt,
      ownerId: (map['ownerId'] as String?) ?? 'default_user',
    );
  }

  @override
  Future<int> updateLedger(Ledger ledger) async {
    final db = await database;
    return await db.update(
      'ledgers',
      {
        'name': ledger.name,
        'description': ledger.description,
        'iconCode': ledger.icon.codePoint,
        'colorValue': ledger.color.toARGB32(),
        'isDefault': ledger.isDefault ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [ledger.id],
    );
  }

  @override
  Future<int> deleteLedger(String id) async {
    final db = await database;
    return await db.delete('ledgers', where: 'id = ?', whereArgs: [id]);
  }

  // Budget CRUD
  @override
  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    return await db.insert('budgets', {
      'id': budget.id,
      'name': budget.name,
      'amount': budget.amount,
      'period': budget.period.index,
      'categoryId': budget.categoryId,
      'ledgerId': budget.ledgerId,
      'iconCode': budget.icon.codePoint,
      'colorValue': budget.color.toARGB32(),
      'isEnabled': budget.isEnabled ? 1 : 0,
      'createdAt': budget.createdAt.millisecondsSinceEpoch,
      'budgetType': budget.budgetType.index,
      'enableCarryover': budget.enableCarryover ? 1 : 0,
      'carryoverSurplusOnly': budget.carryoverSurplusOnly ? 1 : 0,
    });
  }

  @override
  Future<List<Budget>> getBudgets({bool includeDeleted = false}) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: includeDeleted ? null : 'isDeleted = 0',
    );
    return maps.map((map) => Budget(
      id: map['id'] as String,
      name: map['name'] as String,
      amount: map['amount'] as double,
      period: BudgetPeriod.values[map['period'] as int],
      categoryId: map['categoryId'] as String?,
      ledgerId: map['ledgerId'] as String,
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] as int),
      isEnabled: (map['isEnabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      budgetType: BudgetType.values[(map['budgetType'] as int?) ?? 0],
      enableCarryover: (map['enableCarryover'] as int?) == 1,
      carryoverSurplusOnly: (map['carryoverSurplusOnly'] as int?) != 0,
    )).toList();
  }

  @override
  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return await db.update(
      'budgets',
      {
        'name': budget.name,
        'amount': budget.amount,
        'period': budget.period.index,
        'categoryId': budget.categoryId,
        'ledgerId': budget.ledgerId,
        'iconCode': budget.icon.codePoint,
        'colorValue': budget.color.toARGB32(),
        'isEnabled': budget.isEnabled ? 1 : 0,
        'budgetType': budget.budgetType.index,
        'enableCarryover': budget.enableCarryover ? 1 : 0,
        'carryoverSurplusOnly': budget.carryoverSurplusOnly ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  @override
  Future<int> deleteBudget(String id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Budget Carryover CRUD
  @override
  Future<int> insertBudgetCarryover(BudgetCarryover carryover) async {
    final db = await database;
    return await db.insert('budget_carryovers', carryover.toMap());
  }

  @override
  Future<List<BudgetCarryover>> getBudgetCarryovers(String budgetId) async {
    final db = await database;
    final maps = await db.query(
      'budget_carryovers',
      where: 'budgetId = ?',
      whereArgs: [budgetId],
      orderBy: 'year DESC, month DESC',
    );
    return maps.map((map) => BudgetCarryover.fromMap(map)).toList();
  }

  @override
  Future<BudgetCarryover?> getBudgetCarryoverForMonth(
      String budgetId, int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'budget_carryovers',
      where: 'budgetId = ? AND year = ? AND month = ?',
      whereArgs: [budgetId, year, month],
    );
    if (maps.isEmpty) return null;
    return BudgetCarryover.fromMap(maps.first);
  }

  @override
  Future<int> deleteBudgetCarryover(String id) async {
    final db = await database;
    return await db.delete('budget_carryovers', where: 'id = ?', whereArgs: [id]);
  }

  // Zero-Based Allocation CRUD
  @override
  Future<int> insertZeroBasedAllocation(ZeroBasedAllocation allocation) async {
    final db = await database;
    return await db.insert('zero_based_allocations', allocation.toMap());
  }

  @override
  Future<List<ZeroBasedAllocation>> getZeroBasedAllocations(String budgetId) async {
    final db = await database;
    final maps = await db.query(
      'zero_based_allocations',
      where: 'budgetId = ?',
      whereArgs: [budgetId],
      orderBy: 'year DESC, month DESC',
    );
    return maps.map((map) => ZeroBasedAllocation.fromMap(map)).toList();
  }

  @override
  Future<ZeroBasedAllocation?> getZeroBasedAllocationForMonth(
      String budgetId, int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'zero_based_allocations',
      where: 'budgetId = ? AND year = ? AND month = ?',
      whereArgs: [budgetId, year, month],
    );
    if (maps.isEmpty) return null;
    return ZeroBasedAllocation.fromMap(maps.first);
  }

  @override
  Future<int> updateZeroBasedAllocation(ZeroBasedAllocation allocation) async {
    final db = await database;
    return await db.update(
      'zero_based_allocations',
      allocation.toMap(),
      where: 'id = ?',
      whereArgs: [allocation.id],
    );
  }

  @override
  Future<int> deleteZeroBasedAllocation(String id) async {
    final db = await database;
    return await db.delete('zero_based_allocations', where: 'id = ?', whereArgs: [id]);
  }

  // Template CRUD
  @override
  Future<int> insertTemplate(TransactionTemplate template) async {
    final db = await database;
    return await db.insert('templates', {
      'id': template.id,
      'name': template.name,
      'type': template.type.index,
      'amount': template.amount,
      'category': template.category,
      'note': template.note,
      'accountId': template.accountId,
      'toAccountId': template.toAccountId,
      'iconCode': template.icon.codePoint,
      'colorValue': template.color.toARGB32(),
      'useCount': template.useCount,
      'createdAt': template.createdAt.millisecondsSinceEpoch,
      'lastUsedAt': template.lastUsedAt?.millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<TransactionTemplate>> getTemplates() async {
    final db = await database;
    final maps = await db.query('templates', orderBy: 'useCount DESC, lastUsedAt DESC');
    return maps.map((map) => TransactionTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      type: model.TransactionType.values[map['type'] as int],
      amount: map['amount'] as double?,
      category: map['category'] as String,
      note: map['note'] as String?,
      accountId: map['accountId'] as String,
      toAccountId: map['toAccountId'] as String?,
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] as int),
      useCount: map['useCount'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastUsedAt: map['lastUsedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastUsedAt'] as int)
          : null,
    )).toList();
  }

  @override
  Future<int> updateTemplate(TransactionTemplate template) async {
    final db = await database;
    return await db.update(
      'templates',
      {
        'name': template.name,
        'type': template.type.index,
        'amount': template.amount,
        'category': template.category,
        'note': template.note,
        'accountId': template.accountId,
        'toAccountId': template.toAccountId,
        'iconCode': template.icon.codePoint,
        'colorValue': template.color.toARGB32(),
        'useCount': template.useCount,
        'lastUsedAt': template.lastUsedAt?.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  @override
  Future<int> deleteTemplate(String id) async {
    final db = await database;
    return await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> incrementTemplateUseCount(String id) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE templates
      SET useCount = useCount + 1, lastUsedAt = ?
      WHERE id = ?
    ''', [DateTime.now().millisecondsSinceEpoch, id]);
  }

  // Recurring Transaction CRUD
  @override
  Future<int> insertRecurringTransaction(RecurringTransaction recurring) async {
    final db = await database;
    return await db.insert('recurring_transactions', {
      'id': recurring.id,
      'name': recurring.name,
      'type': recurring.type.index,
      'amount': recurring.amount,
      'category': recurring.category,
      'note': recurring.note,
      'accountId': recurring.accountId,
      'toAccountId': recurring.toAccountId,
      'frequency': recurring.frequency.index,
      'dayOfWeek': recurring.dayOfWeek,
      'dayOfMonth': recurring.dayOfMonth,
      'monthOfYear': recurring.monthOfYear,
      'startDate': recurring.startDate.millisecondsSinceEpoch,
      'endDate': recurring.endDate?.millisecondsSinceEpoch,
      'isEnabled': recurring.isEnabled ? 1 : 0,
      'lastExecutedAt': recurring.lastExecutedAt?.millisecondsSinceEpoch,
      'nextExecuteAt': recurring.nextExecuteAt?.millisecondsSinceEpoch,
      'iconCode': recurring.icon.codePoint,
      'colorValue': recurring.color.toARGB32(),
      'createdAt': recurring.createdAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final db = await database;
    final maps = await db.query('recurring_transactions');
    return maps.map((map) => RecurringTransaction(
      id: map['id'] as String,
      name: map['name'] as String,
      type: model.TransactionType.values[map['type'] as int],
      amount: map['amount'] as double,
      category: map['category'] as String,
      note: map['note'] as String?,
      accountId: map['accountId'] as String,
      toAccountId: map['toAccountId'] as String?,
      frequency: RecurringFrequency.values[map['frequency'] as int],
      dayOfWeek: map['dayOfWeek'] as int,
      dayOfMonth: map['dayOfMonth'] as int,
      monthOfYear: map['monthOfYear'] as int,
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int),
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int)
          : null,
      isEnabled: (map['isEnabled'] as int) == 1,
      lastExecutedAt: map['lastExecutedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastExecutedAt'] as int)
          : null,
      nextExecuteAt: map['nextExecuteAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['nextExecuteAt'] as int)
          : null,
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    )).toList();
  }

  @override
  Future<int> updateRecurringTransaction(RecurringTransaction recurring) async {
    final db = await database;
    return await db.update(
      'recurring_transactions',
      {
        'name': recurring.name,
        'type': recurring.type.index,
        'amount': recurring.amount,
        'category': recurring.category,
        'note': recurring.note,
        'accountId': recurring.accountId,
        'toAccountId': recurring.toAccountId,
        'frequency': recurring.frequency.index,
        'dayOfWeek': recurring.dayOfWeek,
        'dayOfMonth': recurring.dayOfMonth,
        'monthOfYear': recurring.monthOfYear,
        'startDate': recurring.startDate.millisecondsSinceEpoch,
        'endDate': recurring.endDate?.millisecondsSinceEpoch,
        'isEnabled': recurring.isEnabled ? 1 : 0,
        'lastExecutedAt': recurring.lastExecutedAt?.millisecondsSinceEpoch,
        'nextExecuteAt': recurring.nextExecuteAt?.millisecondsSinceEpoch,
        'iconCode': recurring.icon.codePoint,
        'colorValue': recurring.color.toARGB32(),
      },
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
  }

  @override
  Future<int> deleteRecurringTransaction(String id) async {
    final db = await database;
    return await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Credit Card CRUD
  @override
  Future<int> insertCreditCard(CreditCard card) async {
    final db = await database;
    return await db.insert('credit_cards', card.toMap());
  }

  @override
  Future<List<CreditCard>> getCreditCards() async {
    final db = await database;
    final maps = await db.query('credit_cards', orderBy: 'createdAt DESC');
    return maps.map((map) => CreditCard.fromMap(map)).toList();
  }

  @override
  Future<int> updateCreditCard(CreditCard card) async {
    final db = await database;
    return await db.update(
      'credit_cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  @override
  Future<int> deleteCreditCard(String id) async {
    final db = await database;
    return await db.delete('credit_cards', where: 'id = ?', whereArgs: [id]);
  }

  // Savings Goal CRUD
  @override
  Future<int> insertSavingsGoal(savings.SavingsGoal goal) async {
    final db = await database;
    return await db.insert('savings_goals', goal.toMap());
  }

  @override
  Future<List<savings.SavingsGoal>> getSavingsGoals() async {
    final db = await database;
    final maps = await db.query('savings_goals', orderBy: 'createdAt DESC');
    return maps.map((map) => savings.SavingsGoal.fromMap(map)).toList();
  }

  @override
  Future<int> updateSavingsGoal(savings.SavingsGoal goal) async {
    final db = await database;
    return await db.update(
      'savings_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  @override
  Future<int> deleteSavingsGoal(String id) async {
    final db = await database;
    // Deposits will be deleted automatically due to CASCADE
    return await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  // Savings Deposit CRUD
  @override
  Future<int> insertSavingsDeposit(savings.SavingsDeposit deposit) async {
    final db = await database;
    return await db.insert('savings_deposits', deposit.toMap());
  }

  @override
  Future<List<savings.SavingsDeposit>> getSavingsDeposits(String goalId) async {
    final db = await database;
    final maps = await db.query(
      'savings_deposits',
      where: 'goalId = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => savings.SavingsDeposit.fromMap(map)).toList();
  }

  @override
  Future<int> deleteSavingsDeposit(String id) async {
    final db = await database;
    return await db.delete('savings_deposits', where: 'id = ?', whereArgs: [id]);
  }

  // Bill Reminder CRUD
  @override
  Future<int> insertBillReminder(BillReminder reminder) async {
    final db = await database;
    return await db.insert('bill_reminders', reminder.toMap());
  }

  @override
  Future<List<BillReminder>> getBillReminders() async {
    final db = await database;
    final maps = await db.query('bill_reminders', orderBy: 'dayOfMonth ASC');
    return maps.map((map) => BillReminder.fromMap(map)).toList();
  }

  @override
  Future<int> updateBillReminder(BillReminder reminder) async {
    final db = await database;
    return await db.update(
      'bill_reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  @override
  Future<int> deleteBillReminder(String id) async {
    final db = await database;
    return await db.delete('bill_reminders', where: 'id = ?', whereArgs: [id]);
  }

  // Investment Account CRUD
  @override
  Future<int> insertInvestmentAccount(InvestmentAccount investment) async {
    final db = await database;
    return await db.insert('investment_accounts', {
      'id': investment.id,
      'name': investment.name,
      'type': investment.type.index,
      'principal': investment.principal,
      'currentValue': investment.currentValue,
      'platform': investment.platform,
      'code': investment.code,
      'note': investment.note,
      'createdAt': investment.createdAt.millisecondsSinceEpoch,
      'updatedAt': investment.updatedAt.millisecondsSinceEpoch,
    });
  }

  @override
  Future<List<InvestmentAccount>> getInvestmentAccounts() async {
    final db = await database;
    final maps = await db.query('investment_accounts', orderBy: 'createdAt DESC');

    return maps.map((map) {
      return InvestmentAccount(
        id: map['id'] as String,
        name: map['name'] as String,
        type: InvestmentType.values[map['type'] as int],
        principal: map['principal'] as double,
        currentValue: map['currentValue'] as double,
        platform: map['platform'] as String?,
        code: map['code'] as String?,
        note: map['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );
    }).toList();
  }

  @override
  Future<int> updateInvestmentAccount(InvestmentAccount investment) async {
    final db = await database;
    return await db.update(
      'investment_accounts',
      {
        'name': investment.name,
        'type': investment.type.index,
        'principal': investment.principal,
        'currentValue': investment.currentValue,
        'platform': investment.platform,
        'code': investment.code,
        'note': investment.note,
        'updatedAt': investment.updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [investment.id],
    );
  }

  @override
  Future<int> deleteInvestmentAccount(String id) async {
    final db = await database;
    return await db.delete('investment_accounts', where: 'id = ?', whereArgs: [id]);
  }

  // Debt CRUD
  @override
  Future<int> insertDebt(Debt debt) async {
    final db = await database;
    return await db.insert('debts', debt.toMap());
  }

  @override
  Future<List<Debt>> getDebts() async {
    final db = await database;
    final maps = await db.query('debts', orderBy: 'createdAt DESC');
    return maps.map((map) => Debt.fromMap(map)).toList();
  }

  @override
  Future<int> updateDebt(Debt debt) async {
    final db = await database;
    return await db.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  @override
  Future<int> deleteDebt(String id) async {
    final db = await database;
    // Payments will be deleted automatically due to CASCADE
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  // Debt Payment CRUD
  @override
  Future<int> insertDebtPayment(DebtPayment payment) async {
    final db = await database;
    return await db.insert('debt_payments', payment.toMap());
  }

  @override
  Future<List<DebtPayment>> getDebtPayments(String debtId) async {
    final db = await database;
    final maps = await db.query(
      'debt_payments',
      where: 'debtId = ?',
      whereArgs: [debtId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => DebtPayment.fromMap(map)).toList();
  }

  @override
  Future<int> deleteDebtPayment(String id) async {
    final db = await database;
    return await db.delete('debt_payments', where: 'id = ?', whereArgs: [id]);
  }

  // Ledger Member CRUD
  @override
  Future<int> insertLedgerMember(LedgerMember member) async {
    final db = await database;
    return await db.insert('ledger_members', member.toMap());
  }

  @override
  Future<List<LedgerMember>> getLedgerMembers() async {
    final db = await database;
    final maps = await db.query('ledger_members', orderBy: 'joinedAt DESC');
    return maps.map((map) => LedgerMember.fromMap(map)).toList();
  }

  @override
  Future<List<LedgerMember>> getLedgerMembersForLedger(String ledgerId) async {
    final db = await database;
    final maps = await db.query(
      'ledger_members',
      where: 'ledgerId = ?',
      whereArgs: [ledgerId],
      orderBy: 'role ASC, joinedAt ASC',
    );
    return maps.map((map) => LedgerMember.fromMap(map)).toList();
  }

  @override
  Future<int> updateLedgerMember(LedgerMember member) async {
    final db = await database;
    return await db.update(
      'ledger_members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  @override
  Future<int> deleteLedgerMember(String id) async {
    final db = await database;
    return await db.delete('ledger_members', where: 'id = ?', whereArgs: [id]);
  }

  // Member Invite CRUD
  @override
  Future<int> insertMemberInvite(MemberInvite invite) async {
    final db = await database;
    return await db.insert('member_invites', invite.toMap());
  }

  @override
  Future<List<MemberInvite>> getMemberInvites() async {
    final db = await database;
    final maps = await db.query('member_invites', orderBy: 'createdAt DESC');
    return maps.map((map) => MemberInvite.fromMap(map)).toList();
  }

  @override
  Future<MemberInvite?> getMemberInviteByCode(String code) async {
    final db = await database;
    final maps = await db.query(
      'member_invites',
      where: 'inviteCode = ?',
      whereArgs: [code],
    );
    if (maps.isEmpty) return null;
    return MemberInvite.fromMap(maps.first);
  }

  @override
  Future<int> updateMemberInvite(MemberInvite invite) async {
    final db = await database;
    return await db.update(
      'member_invites',
      invite.toMap(),
      where: 'id = ?',
      whereArgs: [invite.id],
    );
  }

  @override
  Future<int> deleteMemberInvite(String id) async {
    final db = await database;
    return await db.delete('member_invites', where: 'id = ?', whereArgs: [id]);
  }

  // Member Budget CRUD
  @override
  Future<int> insertMemberBudget(MemberBudget budget) async {
    final db = await database;
    return await db.insert('member_budgets', budget.toMap());
  }

  @override
  Future<List<MemberBudget>> getMemberBudgets() async {
    final db = await database;
    final maps = await db.query('member_budgets', orderBy: 'createdAt DESC');
    return maps.map((map) => MemberBudget.fromMap(map)).toList();
  }

  @override
  Future<List<MemberBudget>> getMemberBudgetsForLedger(String ledgerId) async {
    final db = await database;
    final maps = await db.query(
      'member_budgets',
      where: 'ledgerId = ?',
      whereArgs: [ledgerId],
    );
    return maps.map((map) => MemberBudget.fromMap(map)).toList();
  }

  @override
  Future<MemberBudget?> getMemberBudgetForMember(String memberId) async {
    final db = await database;
    final maps = await db.query(
      'member_budgets',
      where: 'memberId = ?',
      whereArgs: [memberId],
    );
    if (maps.isEmpty) return null;
    return MemberBudget.fromMap(maps.first);
  }

  @override
  Future<int> updateMemberBudget(MemberBudget budget) async {
    final db = await database;
    return await db.update(
      'member_budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  @override
  Future<int> deleteMemberBudget(String id) async {
    final db = await database;
    return await db.delete('member_budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Expense Approval CRUD
  @override
  Future<int> insertExpenseApproval(ExpenseApproval approval) async {
    final db = await database;
    return await db.insert('expense_approvals', approval.toMap());
  }

  @override
  Future<List<ExpenseApproval>> getExpenseApprovals() async {
    final db = await database;
    final maps = await db.query('expense_approvals', orderBy: 'createdAt DESC');
    return maps.map((map) => ExpenseApproval.fromMap(map)).toList();
  }

  @override
  Future<List<ExpenseApproval>> getExpenseApprovalsForLedger(String ledgerId) async {
    final db = await database;
    final maps = await db.query(
      'expense_approvals',
      where: 'ledgerId = ?',
      whereArgs: [ledgerId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => ExpenseApproval.fromMap(map)).toList();
  }

  @override
  Future<List<ExpenseApproval>> getPendingApprovalsForLedger(String ledgerId) async {
    final db = await database;
    final maps = await db.query(
      'expense_approvals',
      where: 'ledgerId = ? AND status = ?',
      whereArgs: [ledgerId, ApprovalStatus.pending.index],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => ExpenseApproval.fromMap(map)).toList();
  }

  @override
  Future<int> updateExpenseApproval(ExpenseApproval approval) async {
    final db = await database;
    return await db.update(
      'expense_approvals',
      approval.toMap(),
      where: 'id = ?',
      whereArgs: [approval.id],
    );
  }

  @override
  Future<int> deleteExpenseApproval(String id) async {
    final db = await database;
    return await db.delete('expense_approvals', where: 'id = ?', whereArgs: [id]);
  }

  // Initialize default data
  @override
  Future<void> initializeDefaultData() async {
    final db = await database;

    // Check if data exists
    final accountCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM accounts'),
    );

    if (accountCount == 0) {
      // Insert default accounts
      for (final account in DefaultAccounts.accounts) {
        await insertAccount(account);
      }
    }

    final ledgerCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ledgers'),
    );

    if (ledgerCount == 0) {
      // Insert default ledger
      const defaultOwnerId = 'default_user';
      await insertLedger(DefaultLedgers.defaultLedger(defaultOwnerId));
    }
  }

  // ==================== Sync Metadata CRUD ====================

  /// Insert or update sync metadata for an entity
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
  }) async {
    final db = await database;
    final id = '${entityType}_$localId';

    return await db.insert(
      'sync_metadata',
      {
        'id': id,
        'entityType': entityType,
        'localId': localId,
        'serverId': serverId,
        'syncStatus': syncStatus,
        'localUpdatedAt': localUpdatedAt,
        'serverUpdatedAt': serverUpdatedAt,
        'lastSyncAt': lastSyncAt,
        'version': version,
        'isDeleted': isDeleted ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get sync metadata for a specific entity
  @override
  Future<Map<String, dynamic>?> getSyncMetadata(String entityType, String localId) async {
    final db = await database;
    final maps = await db.query(
      'sync_metadata',
      where: 'entityType = ? AND localId = ?',
      whereArgs: [entityType, localId],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  /// Get all entities pending sync
  @override
  Future<List<Map<String, dynamic>>> getPendingSyncMetadata() async {
    final db = await database;
    return await db.query(
      'sync_metadata',
      where: 'syncStatus = ?',
      whereArgs: [0], // 0 = pending
      orderBy: 'localUpdatedAt ASC',
    );
  }

  /// Get all synced entities older than a given date (for cleanup)
  @override
  Future<List<Map<String, dynamic>>> getSyncedEntitiesOlderThan(
    String entityType,
    int cutoffTimestamp,
  ) async {
    final db = await database;
    return await db.query(
      'sync_metadata',
      where: 'entityType = ? AND syncStatus = ? AND lastSyncAt < ?',
      whereArgs: [entityType, 1, cutoffTimestamp], // 1 = synced
    );
  }

  /// Update sync status after successful sync
  @override
  Future<int> updateSyncStatus(
    String entityType,
    String localId, {
    required int syncStatus,
    String? serverId,
    int? serverUpdatedAt,
    int? lastSyncAt,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'syncStatus': syncStatus,
    };
    if (serverId != null) updates['serverId'] = serverId;
    if (serverUpdatedAt != null) updates['serverUpdatedAt'] = serverUpdatedAt;
    if (lastSyncAt != null) updates['lastSyncAt'] = lastSyncAt;

    return await db.update(
      'sync_metadata',
      updates,
      where: 'entityType = ? AND localId = ?',
      whereArgs: [entityType, localId],
    );
  }

  /// Delete sync metadata
  @override
  Future<int> deleteSyncMetadata(String entityType, String localId) async {
    final db = await database;
    return await db.delete(
      'sync_metadata',
      where: 'entityType = ? AND localId = ?',
      whereArgs: [entityType, localId],
    );
  }

  // ==================== Sync Queue CRUD ====================

  /// Add operation to sync queue
  @override
  Future<int> enqueueSyncOperation({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
  }) async {
    final db = await database;
    return await db.insert('sync_queue', {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
      'status': 0, // pending
    });
  }

  /// Get pending sync operations
  @override
  Future<List<Map<String, dynamic>>> getPendingSyncQueue() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [0], // pending
      orderBy: 'createdAt ASC',
    );
  }

  /// Update sync queue item status
  @override
  Future<int> updateSyncQueueStatus(
    String id, {
    required int status,
    int? retryCount,
    String? lastError,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{'status': status};
    if (retryCount != null) updates['retryCount'] = retryCount;
    if (lastError != null) updates['lastError'] = lastError;

    return await db.update(
      'sync_queue',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete completed sync queue items
  @override
  Future<int> deleteCompletedSyncQueue() async {
    final db = await database;
    return await db.delete(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [2], // completed
    );
  }

  /// Clear all sync queue
  @override
  Future<int> clearSyncQueue() async {
    final db = await database;
    return await db.delete('sync_queue');
  }

  // ==================== ID Mapping CRUD ====================

  /// Insert ID mapping
  @override
  Future<int> insertIdMapping({
    required String entityType,
    required String localId,
    required String serverId,
  }) async {
    final db = await database;
    final id = '${entityType}_$localId';
    return await db.insert(
      'id_mapping',
      {
        'id': id,
        'entityType': entityType,
        'localId': localId,
        'serverId': serverId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get server ID by local ID
  @override
  Future<String?> getServerIdByLocalId(String entityType, String localId) async {
    final db = await database;
    final maps = await db.query(
      'id_mapping',
      columns: ['serverId'],
      where: 'entityType = ? AND localId = ?',
      whereArgs: [entityType, localId],
    );
    return maps.isNotEmpty ? maps.first['serverId'] as String : null;
  }

  /// Get local ID by server ID
  @override
  Future<String?> getLocalIdByServerId(String entityType, String serverId) async {
    final db = await database;
    final maps = await db.query(
      'id_mapping',
      columns: ['localId'],
      where: 'entityType = ? AND serverId = ?',
      whereArgs: [entityType, serverId],
    );
    return maps.isNotEmpty ? maps.first['localId'] as String : null;
  }

  /// Get all ID mappings for an entity type
  @override
  Future<List<Map<String, dynamic>>> getIdMappings(String entityType) async {
    final db = await database;
    return await db.query(
      'id_mapping',
      where: 'entityType = ?',
      whereArgs: [entityType],
    );
  }

  /// Delete ID mapping
  @override
  Future<int> deleteIdMapping(String entityType, String localId) async {
    final db = await database;
    return await db.delete(
      'id_mapping',
      where: 'entityType = ? AND localId = ?',
      whereArgs: [entityType, localId],
    );
  }

  // ==================== Sync Statistics ====================

  /// Get sync statistics
  @override
  Future<Map<String, int>> getSyncStatistics() async {
    final db = await database;

    final pendingCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_metadata WHERE syncStatus = 0'),
    ) ?? 0;

    final syncedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_metadata WHERE syncStatus = 1'),
    ) ?? 0;

    final conflictCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_metadata WHERE syncStatus = 2'),
    ) ?? 0;

    final queueCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE status = 0'),
    ) ?? 0;

    final queueFailedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE status = 3'),
    ) ?? 0;

    return {
      'pending': pendingCount,
      'synced': syncedCount,
      'conflict': conflictCount,
      'queue': queueCount,
      'queueFailed': queueFailedCount,
    };
  }

  /// Get last sync time
  @override
  Future<DateTime?> getLastSyncTime() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(lastSyncAt) as lastSync FROM sync_metadata WHERE lastSyncAt IS NOT NULL',
    );
    final lastSync = result.first['lastSync'] as int?;
    return lastSync != null ? DateTime.fromMillisecondsSinceEpoch(lastSync) : null;
  }

  // ==================== Import Batch CRUD ====================

  /// Insert import batch
  @override
  Future<int> insertImportBatch(ImportBatch batch) async {
    final db = await database;
    return await db.insert('import_batches', batch.toMap());
  }

  /// Get all import batches
  @override
  Future<List<ImportBatch>> getImportBatches() async {
    final db = await database;
    final maps = await db.query('import_batches', orderBy: 'createdAt DESC');
    return maps.map((map) => ImportBatch.fromMap(map)).toList();
  }

  /// Get import batch by ID
  @override
  Future<ImportBatch?> getImportBatch(String id) async {
    final db = await database;
    final maps = await db.query(
      'import_batches',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ImportBatch.fromMap(maps.first);
  }

  /// Get active import batches (not revoked)
  @override
  Future<List<ImportBatch>> getActiveImportBatches() async {
    final db = await database;
    final maps = await db.query(
      'import_batches',
      where: 'status = ?',
      whereArgs: [ImportBatchStatus.active.index],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => ImportBatch.fromMap(map)).toList();
  }

  /// Update import batch
  @override
  Future<int> updateImportBatch(ImportBatch batch) async {
    final db = await database;
    return await db.update(
      'import_batches',
      batch.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  /// Revoke an import batch and delete all associated transactions
  @override
  Future<void> revokeImportBatch(String batchId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete all transactions with this batch ID
      await txn.delete(
        'transactions',
        where: 'importBatchId = ?',
        whereArgs: [batchId],
      );

      // Update batch status to revoked
      await txn.update(
        'import_batches',
        {
          'status': ImportBatchStatus.revoked.index,
          'revokedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [batchId],
      );
    });
  }

  /// Delete import batch (only for testing/cleanup)
  @override
  Future<int> deleteImportBatch(String id) async {
    final db = await database;
    return await db.delete('import_batches', where: 'id = ?', whereArgs: [id]);
  }

  /// Get transactions by import batch ID
  @override
  Future<List<model.Transaction>> getTransactionsByBatchId(String batchId) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'importBatchId = ?',
      whereArgs: [batchId],
      orderBy: 'date DESC',
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      final isSplit = (map['isSplit'] as int?) == 1;
      List<TransactionSplit>? splits;

      if (isSplit) {
        splits = await getTransactionSplits(map['id'] as String);
      }

      final tagsString = map['tags'] as String?;
      final sourceFileExpiresAtMs = map['sourceFileExpiresAt'] as int?;

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int],
        amount: map['amount'] as double,
        category: map['category'] as String,
        note: map['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['accountId'] as String,
        toAccountId: map['toAccountId'] as String?,
        isSplit: isSplit,
        splits: splits,
        isReimbursable: (map['isReimbursable'] as int?) == 1,
        isReimbursed: (map['isReimbursed'] as int?) == 1,
        tags: tagsString != null && tagsString.isNotEmpty
            ? tagsString.split(',')
            : null,
        source: model.TransactionSource.values[(map['source'] as int?) ?? 0],
        aiConfidence: map['aiConfidence'] as double?,
        sourceFileLocalPath: map['sourceFileLocalPath'] as String?,
        sourceFileServerUrl: map['sourceFileServerUrl'] as String?,
        sourceFileType: map['sourceFileType'] as String?,
        sourceFileSize: map['sourceFileSize'] as int?,
        recognitionRawData: map['recognitionRawData'] as String?,
        sourceFileExpiresAt: sourceFileExpiresAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(sourceFileExpiresAtMs)
            : null,
        externalId: map['externalId'] as String?,
        externalSource: map['externalSource'] != null
            ? model.ExternalSource.values[map['externalSource'] as int]
            : null,
        importBatchId: map['importBatchId'] as String?,
        rawMerchant: map['rawMerchant'] as String?,
        vaultId: map['vaultId'] as String?,
        moneyAge: map['moneyAge'] as int?,
        moneyAgeLevel: map['moneyAgeLevel'] as String?,
        resourcePoolId: map['resourcePoolId'] as String?,
        visibility: (map['visibility'] as int?) ?? 1,
        location: _parseLocationJson(map['locationJson'] as String?),
      ));
    }

    return transactions;
  }

  /// Find transaction by external ID and source (for deduplication)
  @override
  Future<model.Transaction?> findTransactionByExternalId(
    String externalId,
    model.ExternalSource externalSource,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'externalId = ? AND externalSource = ?',
      whereArgs: [externalId, externalSource.index],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final isSplit = (map['isSplit'] as int?) == 1;
    List<TransactionSplit>? splits;

    if (isSplit) {
      splits = await getTransactionSplits(map['id'] as String);
    }

    final tagsString = map['tags'] as String?;
    final sourceFileExpiresAtMs = map['sourceFileExpiresAt'] as int?;

    return model.Transaction(
      id: map['id'] as String,
      type: model.TransactionType.values[map['type'] as int],
      amount: map['amount'] as double,
      category: map['category'] as String,
      note: map['note'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      accountId: map['accountId'] as String,
      toAccountId: map['toAccountId'] as String?,
      isSplit: isSplit,
      splits: splits,
      isReimbursable: (map['isReimbursable'] as int?) == 1,
      isReimbursed: (map['isReimbursed'] as int?) == 1,
      tags: tagsString != null && tagsString.isNotEmpty
          ? tagsString.split(',')
          : null,
      source: model.TransactionSource.values[(map['source'] as int?) ?? 0],
      aiConfidence: map['aiConfidence'] as double?,
      sourceFileLocalPath: map['sourceFileLocalPath'] as String?,
      sourceFileServerUrl: map['sourceFileServerUrl'] as String?,
      sourceFileType: map['sourceFileType'] as String?,
      sourceFileSize: map['sourceFileSize'] as int?,
      recognitionRawData: map['recognitionRawData'] as String?,
      sourceFileExpiresAt: sourceFileExpiresAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(sourceFileExpiresAtMs)
          : null,
      externalId: map['externalId'] as String?,
      externalSource: map['externalSource'] != null
          ? model.ExternalSource.values[map['externalSource'] as int]
          : null,
      importBatchId: map['importBatchId'] as String?,
      rawMerchant: map['rawMerchant'] as String?,
    );
  }

  /// Find potential duplicate transactions for deduplication
  /// Returns transactions within the date range with matching amount
  @override
  Future<List<model.Transaction>> findPotentialDuplicates({
    required DateTime date,
    required double amount,
    required model.TransactionType type,
    int dayRange = 1,
  }) async {
    final db = await database;
    final startDate = date.subtract(Duration(days: dayRange));
    final endDate = date.add(Duration(days: dayRange));

    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ? AND amount = ? AND type = ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
        amount,
        type.index,
      ],
      orderBy: 'date DESC',
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      final isSplit = (map['isSplit'] as int?) == 1;
      List<TransactionSplit>? splits;

      if (isSplit) {
        splits = await getTransactionSplits(map['id'] as String);
      }

      final tagsString = map['tags'] as String?;
      final sourceFileExpiresAtMs = map['sourceFileExpiresAt'] as int?;

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int],
        amount: map['amount'] as double,
        category: map['category'] as String,
        note: map['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['accountId'] as String,
        toAccountId: map['toAccountId'] as String?,
        isSplit: isSplit,
        splits: splits,
        isReimbursable: (map['isReimbursable'] as int?) == 1,
        isReimbursed: (map['isReimbursed'] as int?) == 1,
        tags: tagsString != null && tagsString.isNotEmpty
            ? tagsString.split(',')
            : null,
        source: model.TransactionSource.values[(map['source'] as int?) ?? 0],
        aiConfidence: map['aiConfidence'] as double?,
        sourceFileLocalPath: map['sourceFileLocalPath'] as String?,
        sourceFileServerUrl: map['sourceFileServerUrl'] as String?,
        sourceFileType: map['sourceFileType'] as String?,
        sourceFileSize: map['sourceFileSize'] as int?,
        recognitionRawData: map['recognitionRawData'] as String?,
        sourceFileExpiresAt: sourceFileExpiresAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(sourceFileExpiresAtMs)
            : null,
        externalId: map['externalId'] as String?,
        externalSource: map['externalSource'] != null
            ? model.ExternalSource.values[map['externalSource'] as int]
            : null,
        importBatchId: map['importBatchId'] as String?,
        rawMerchant: map['rawMerchant'] as String?,
      ));
    }

    return transactions;
  }

  /// Batch insert transactions (for import)
  @override
  Future<void> batchInsertTransactions(List<model.Transaction> transactions) async {
    final db = await database;
    final batch = db.batch();

    for (final transaction in transactions) {
      batch.insert('transactions', {
        'id': transaction.id,
        'type': transaction.type.index,
        'amount': transaction.amount,
        'category': transaction.category,
        'note': transaction.note,
        'date': transaction.date.millisecondsSinceEpoch,
        'accountId': transaction.accountId,
        'toAccountId': transaction.toAccountId,
        'ledgerId': 'default',
        'isSplit': transaction.isSplit ? 1 : 0,
        'isReimbursable': transaction.isReimbursable ? 1 : 0,
        'isReimbursed': transaction.isReimbursed ? 1 : 0,
        'tags': transaction.tags?.join(','),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'source': transaction.source.index,
        'aiConfidence': transaction.aiConfidence,
        'sourceFileLocalPath': transaction.sourceFileLocalPath,
        'sourceFileServerUrl': transaction.sourceFileServerUrl,
        'sourceFileType': transaction.sourceFileType,
        'sourceFileSize': transaction.sourceFileSize,
        'recognitionRawData': transaction.recognitionRawData,
        'sourceFileExpiresAt': transaction.sourceFileExpiresAt?.millisecondsSinceEpoch,
        'externalId': transaction.externalId,
        'externalSource': transaction.externalSource?.index,
        'importBatchId': transaction.importBatchId,
        'rawMerchant': transaction.rawMerchant,
      });
    }

    await batch.commit(noResult: true);
  }

  /// Get total income for a specific month
  Future<double> getMonthlyIncomeTotal({
    required int year,
    required int month,
    String? ledgerId,
  }) async {
    final db = await database;
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    String where = 'type = ? AND date >= ? AND date < ?';
    List<dynamic> whereArgs = [
      model.TransactionType.income.index,
      startOfMonth.millisecondsSinceEpoch,
      endOfMonth.millisecondsSinceEpoch,
    ];

    if (ledgerId != null) {
      where += ' AND ledgerId = ?';
      whereArgs.add(ledgerId);
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE $where',
      whereArgs,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ==================== 2.0新增：资源池 CRUD ====================

  /// 插入资源池
  @override
  Future<int> insertResourcePool(ResourcePool pool) async {
    final db = await database;
    return await db.insert('resource_pools', pool.toMap());
  }

  /// 更新资源池
  @override
  Future<int> updateResourcePool(ResourcePool pool) async {
    final db = await database;
    return await db.update(
      'resource_pools',
      pool.toMap(),
      where: 'id = ?',
      whereArgs: [pool.id],
    );
  }

  /// 删除资源池
  @override
  Future<int> deleteResourcePool(String id) async {
    final db = await database;
    return await db.delete('resource_pools', where: 'id = ?', whereArgs: [id]);
  }

  /// 获取所有有剩余金额的资源池（按创建时间排序，FIFO）
  @override
  Future<List<ResourcePool>> getActiveResourcePools() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'resource_pools',
      where: 'remainingAmount > 0',
      orderBy: 'createdAt ASC',
    );
    return maps.map((map) => ResourcePool.fromMap(map)).toList();
  }

  /// 获取所有资源池
  @override
  Future<List<ResourcePool>> getAllResourcePools() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'resource_pools',
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => ResourcePool.fromMap(map)).toList();
  }

  /// 根据收入交易ID获取资源池
  @override
  Future<ResourcePool?> getResourcePoolByIncomeId(String incomeTransactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'resource_pools',
      where: 'incomeTransactionId = ?',
      whereArgs: [incomeTransactionId],
    );
    if (maps.isEmpty) return null;
    return ResourcePool.fromMap(maps.first);
  }

  /// 插入资源消费记录
  @override
  Future<int> insertResourceConsumption(ResourceConsumption consumption) async {
    final db = await database;
    return await db.insert('resource_consumptions', consumption.toMap());
  }

  /// 批量插入资源消费记录
  @override
  Future<void> batchInsertResourceConsumptions(List<ResourceConsumption> consumptions) async {
    final db = await database;
    final batch = db.batch();
    for (final consumption in consumptions) {
      batch.insert('resource_consumptions', consumption.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// 获取交易的资源消费记录
  @override
  Future<List<ResourceConsumption>> getConsumptionsByTransaction(String transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'resource_consumptions',
      where: 'expenseTransactionId = ?',
      whereArgs: [transactionId],
    );
    return maps.map((map) => ResourceConsumption.fromMap(map)).toList();
  }

  /// 获取资源池的消费记录
  @override
  Future<List<ResourceConsumption>> getConsumptionsByPool(String poolId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'resource_consumptions',
      where: 'resourcePoolId = ?',
      whereArgs: [poolId],
      orderBy: 'consumedAt ASC',
    );
    return maps.map((map) => ResourceConsumption.fromMap(map)).toList();
  }

  // ==================== 2.0新增：小金库 CRUD ====================

  /// 插入小金库
  @override
  Future<int> insertBudgetVault(BudgetVault vault) async {
    final db = await database;
    return await db.insert('budget_vaults', vault.toMap());
  }

  /// 更新小金库
  @override
  Future<int> updateBudgetVault(BudgetVault vault) async {
    final db = await database;
    return await db.update(
      'budget_vaults',
      vault.toMap(),
      where: 'id = ?',
      whereArgs: [vault.id],
    );
  }

  /// 删除小金库
  @override
  Future<int> deleteBudgetVault(String id) async {
    final db = await database;
    return await db.delete('budget_vaults', where: 'id = ?', whereArgs: [id]);
  }

  /// 获取账本的所有小金库
  @override
  Future<List<BudgetVault>> getBudgetVaults({String? ledgerId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_vaults',
      where: ledgerId != null ? 'ledgerId = ?' : null,
      whereArgs: ledgerId != null ? [ledgerId] : null,
      orderBy: 'sortOrder ASC, createdAt DESC',
    );
    return maps.map((map) => BudgetVault.fromMap(map)).toList();
  }

  /// 获取启用的小金库
  @override
  Future<List<BudgetVault>> getEnabledBudgetVaults({String? ledgerId}) async {
    final db = await database;
    String where = 'isEnabled = 1';
    List<dynamic> whereArgs = [];
    if (ledgerId != null) {
      where += ' AND ledgerId = ?';
      whereArgs.add(ledgerId);
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_vaults',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'sortOrder ASC',
    );
    return maps.map((map) => BudgetVault.fromMap(map)).toList();
  }

  /// 根据ID获取小金库
  @override
  Future<BudgetVault?> getBudgetVaultById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_vaults',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return BudgetVault.fromMap(maps.first);
  }

  /// 根据关联分类获取小金库
  @override
  Future<BudgetVault?> getBudgetVaultByCategory(String categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_vaults',
      where: 'linkedCategoryId = ? OR linkedCategoryIds LIKE ?',
      whereArgs: [categoryId, '%$categoryId%'],
    );
    if (maps.isEmpty) return null;
    return BudgetVault.fromMap(maps.first);
  }

  /// 插入小金库分配记录
  @override
  Future<int> insertVaultAllocation(VaultAllocation allocation) async {
    final db = await database;
    return await db.insert('vault_allocations', allocation.toMap());
  }

  /// 获取小金库的分配记录
  @override
  Future<List<VaultAllocation>> getVaultAllocations(String vaultId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vault_allocations',
      where: 'vaultId = ?',
      whereArgs: [vaultId],
      orderBy: 'allocatedAt DESC',
    );
    return maps.map((map) => VaultAllocation.fromMap(map)).toList();
  }

  /// 插入小金库调拨记录
  @override
  Future<int> insertVaultTransfer(VaultTransfer transfer) async {
    final db = await database;
    return await db.insert('vault_transfers', transfer.toMap());
  }

  /// 获取小金库的调拨记录
  @override
  Future<List<VaultTransfer>> getVaultTransfers(String vaultId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vault_transfers',
      where: 'fromVaultId = ? OR toVaultId = ?',
      whereArgs: [vaultId, vaultId],
      orderBy: 'transferredAt DESC',
    );
    return maps.map((map) => VaultTransfer.fromMap(map)).toList();
  }

  /// 更新小金库已分配金额
  @override
  Future<void> updateVaultAllocatedAmount(String vaultId, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE budget_vaults SET allocatedAmount = allocatedAmount + ?, updatedAt = ? WHERE id = ?',
      [amount, DateTime.now().millisecondsSinceEpoch, vaultId],
    );
  }

  /// 更新小金库已花费金额
  @override
  Future<void> updateVaultSpentAmount(String vaultId, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE budget_vaults SET spentAmount = spentAmount + ?, updatedAt = ? WHERE id = ?',
      [amount, DateTime.now().millisecondsSinceEpoch, vaultId],
    );
  }

  /// 执行原始SQL查询
  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// 执行原始SQL插入
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  /// 执行原始SQL更新
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  /// 执行原始SQL删除
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }

  // ═══════════════════════════════════════════════════════════════
  // 备份/导出服务使用的别名方法
  // ═══════════════════════════════════════════════════════════════

  /// 获取所有交易（别名）
  @override
  Future<List<model.Transaction>> getAllTransactions() => getTransactions();

  /// 获取所有账户（别名）
  @override
  Future<List<Account>> getAllAccounts() => getAccounts();

  /// 获取所有预算（别名）
  @override
  Future<List<Budget>> getAllBudgets() => getBudgets();

  /// 获取所有储蓄目标（别名）
  @override
  Future<List<savings.SavingsGoal>> getAllSavingsGoals() => getSavingsGoals();

  /// 获取所有周期性交易（别名）
  @override
  Future<List<RecurringTransaction>> getAllRecurringTransactions() => getRecurringTransactions();

  /// 获取所有模板（别名）
  @override
  Future<List<TransactionTemplate>> getAllTemplates() => getTemplates();

  /// 获取自定义分类
  @override
  Future<List<Map<String, dynamic>>> getCustomCategories() async {
    final db = await database;
    return await db.query('custom_categories');
  }

  /// 获取钱龄资源池数据
  @override
  Future<List<Map<String, dynamic>>> getMoneyAgePools() async {
    final db = await database;
    return await db.query('money_age_pools');
  }

  /// 获取家庭账本数据
  @override
  Future<List<Map<String, dynamic>>> getFamilyLedgers() async {
    final db = await database;
    return await db.query('family_ledgers');
  }

  /// 获取位置记录
  @override
  Future<List<Map<String, dynamic>>> getLocationRecords() async {
    final db = await database;
    return await db.query('location_records');
  }

  /// 获取设置值
  @override
  Future<dynamic> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return results.first['value'];
  }

  /// 设置值
  @override
  Future<void> setSetting(String key, dynamic value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value?.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Parse location JSON string to TransactionLocation
  TransactionLocation? _parseLocationJson(String? locationJson) {
    if (locationJson == null || locationJson.isEmpty) return null;
    final parts = locationJson.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return TransactionLocation(
      latitude: lat,
      longitude: lng,
      placeName: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
      address: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
    );
  }

  // =============== 导出服务所需的存根方法 ===============

  /// 获取交易总数
  @override
  Future<int> getTransactionCount() async {
    final transactions = await getTransactions();
    return transactions.length;
  }

  /// 获取第一笔交易
  @override
  Future<model.Transaction?> getFirstTransaction() async {
    final transactions = await getTransactions();
    if (transactions.isEmpty) return null;
    transactions.sort((a, b) => a.date.compareTo(b.date));
    return transactions.first;
  }

  /// 高级交易查询（支持多条件过滤）
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
    final db = await database;

    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];

    // 时间范围过滤
    if (startDate != null) {
      whereConditions.add('date >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereConditions.add('date <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    // 分类过滤
    if (category != null && category.isNotEmpty) {
      whereConditions.add('(category LIKE ? OR sub_category LIKE ?)');
      whereArgs.add('%$category%');
      whereArgs.add('%$category%');
    }

    // 商家过滤
    if (merchant != null && merchant.isNotEmpty) {
      whereConditions.add('merchant LIKE ?');
      whereArgs.add('%$merchant%');
    }

    // 金额范围过滤
    if (minAmount != null) {
      whereConditions.add('amount >= ?');
      whereArgs.add(minAmount);
    }
    if (maxAmount != null) {
      whereConditions.add('amount <= ?');
      whereArgs.add(maxAmount);
    }

    // 描述过滤
    if (description != null && description.isNotEmpty) {
      whereConditions.add('description LIKE ?');
      whereArgs.add('%$description%');
    }

    // 账户过滤
    if (account != null && account.isNotEmpty) {
      whereConditions.add('account LIKE ?');
      whereArgs.add('%$account%');
    }

    // 标签过滤
    if (tags != null && tags.isNotEmpty) {
      final tagConditions = tags.map((_) => 'tags LIKE ?').join(' OR ');
      whereConditions.add('($tagConditions)');
      for (final tag in tags) {
        whereArgs.add('%$tag%');
      }
    }

    final whereClause = whereConditions.isEmpty ? null : whereConditions.join(' AND ');

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date DESC',
      limit: limit,
    );

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      // 获取分账信息
      final splits = await getTransactionSplits(map['id'] as String);

      transactions.add(model.Transaction(
        id: map['id'] as String,
        type: model.TransactionType.values[map['type'] as int? ?? 0],
        amount: map['amount'] as double,
        category: map['category'] as String? ?? '',
        subcategory: map['sub_category'] as String?,
        rawMerchant: map['merchant'] as String?,
        note: map['description'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        accountId: map['account'] as String? ?? '',
        tags: (map['tags'] as String?)?.split(',').where((tag) => tag.isNotEmpty).toList() ?? [],
        splits: splits,
        createdAt: map['created_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) :
          DateTime.now(),
        updatedAt: map['updated_at'] != null ?
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int) :
          DateTime.now(),
      ));
    }

    return transactions;
  }

  /// 获取钱龄统计
  @override
  Future<Map<String, dynamic>> getMoneyAgeStats() async {
    return {};
  }

  /// 获取FIFO流动记录
  @override
  Future<List<Map<String, dynamic>>> getFifoFlowRecords() async {
    return [];
  }

  /// 获取钱龄分布
  @override
  Future<Map<String, int>> getMoneyAgeDistribution() async {
    return {};
  }

  /// 获取指定月份的预算
  @override
  Future<List<Budget>> getBudgetsForMonth(DateTime month) async {
    return getBudgets();
  }

  /// 获取指定月份的小金库记录
  @override
  Future<List<Map<String, dynamic>>> getVaultRecordsForMonth(DateTime month) async {
    return [];
  }

  /// 查找家庭重复交易
  @override
  Future<List<Map<String, dynamic>>> findFamilyDuplicates({
    required String ledgerId,
    required DateTime date,
    required double amount,
  }) async {
    return [];
  }

  /// 根据账本ID获取成员列表
  @override
  Future<List<Map<String, dynamic>>> getMembersByLedgerId(String ledgerId) async {
    return [];
  }

  /// 根据成员获取交易
  @override
  Future<List<model.Transaction>> getTransactionsByMember(String memberId) async {
    return [];
  }

  /// 获取单个预算
  @override
  Future<Budget?> getBudget(String id) async {
    final budgets = await getBudgets();
    try {
      return budgets.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 保存预算
  @override
  Future<void> saveBudget(Budget budget) async {
    await updateBudget(budget);
  }

  // ==================== 软删除支持 ====================

  /// 软删除交易记录
  @override
  Future<int> softDeleteTransaction(String id) async {
    final db = await database;
    return await db.update(
      'transactions',
      {
        'isDeleted': 1,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 软删除账户
  @override
  Future<int> softDeleteAccount(String id) async {
    final db = await database;
    return await db.update(
      'accounts',
      {
        'isDeleted': 1,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 软删除分类
  @override
  Future<int> softDeleteCategory(String id) async {
    final db = await database;
    return await db.update(
      'categories',
      {
        'isDeleted': 1,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 软删除账本
  @override
  Future<int> softDeleteLedger(String id) async {
    final db = await database;
    return await db.update(
      'ledgers',
      {
        'isDeleted': 1,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 软删除预算
  @override
  Future<int> softDeleteBudget(String id) async {
    final db = await database;
    return await db.update(
      'budgets',
      {
        'isDeleted': 1,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 恢复软删除的交易记录
  @override
  Future<int> restoreTransaction(String id) async {
    final db = await database;
    return await db.update(
      'transactions',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 恢复软删除的账户
  @override
  Future<int> restoreAccount(String id) async {
    final db = await database;
    return await db.update(
      'accounts',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 恢复软删除的分类
  @override
  Future<int> restoreCategory(String id) async {
    final db = await database;
    return await db.update(
      'categories',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 恢复软删除的账本
  @override
  Future<int> restoreLedger(String id) async {
    final db = await database;
    return await db.update(
      'ledgers',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 恢复软删除的预算
  @override
  Future<int> restoreBudget(String id) async {
    final db = await database;
    return await db.update(
      'budgets',
      {'isDeleted': 0, 'deletedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 永久删除已软删除且超过保留期的记录
  ///
  /// [retentionDays] 保留天数，默认30天
  @override
  Future<Map<String, int>> purgeDeletedRecords({int retentionDays = 30}) async {
    final db = await database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;

    final results = <String, int>{};

    results['transactions'] = await db.delete(
      'transactions',
      where: 'isDeleted = 1 AND deletedAt < ?',
      whereArgs: [cutoffTime],
    );

    results['accounts'] = await db.delete(
      'accounts',
      where: 'isDeleted = 1 AND deletedAt < ?',
      whereArgs: [cutoffTime],
    );

    results['categories'] = await db.delete(
      'categories',
      where: 'isDeleted = 1 AND deletedAt < ?',
      whereArgs: [cutoffTime],
    );

    results['ledgers'] = await db.delete(
      'ledgers',
      where: 'isDeleted = 1 AND deletedAt < ?',
      whereArgs: [cutoffTime],
    );

    results['budgets'] = await db.delete(
      'budgets',
      where: 'isDeleted = 1 AND deletedAt < ?',
      whereArgs: [cutoffTime],
    );

    _logger.info('Purged deleted records: $results', tag: 'DB');
    return results;
  }

  // ==================== 数据完整性检测 ====================

  /// 检测孤儿数据
  ///
  /// 返回各类孤儿数据的统计
  @override
  Future<Map<String, List<String>>> detectOrphanData() async {
    final db = await database;
    final orphans = <String, List<String>>{};

    // 1. 检测 transactions 中无效的 accountId
    final orphanTransactionsByAccount = await db.rawQuery('''
      SELECT t.id FROM transactions t
      LEFT JOIN accounts a ON t.accountId = a.id
      WHERE a.id IS NULL AND t.isDeleted = 0
    ''');
    if (orphanTransactionsByAccount.isNotEmpty) {
      orphans['transactions_invalid_account'] =
          orphanTransactionsByAccount.map((m) => m['id'] as String).toList();
    }

    // 2. 检测 transactions 中无效的 ledgerId
    final orphanTransactionsByLedger = await db.rawQuery('''
      SELECT t.id FROM transactions t
      LEFT JOIN ledgers l ON t.ledgerId = l.id
      WHERE l.id IS NULL AND t.ledgerId != 'default' AND t.isDeleted = 0
    ''');
    if (orphanTransactionsByLedger.isNotEmpty) {
      orphans['transactions_invalid_ledger'] =
          orphanTransactionsByLedger.map((m) => m['id'] as String).toList();
    }

    // 3. 检测 budgets 中无效的 ledgerId
    final orphanBudgetsByLedger = await db.rawQuery('''
      SELECT b.id FROM budgets b
      LEFT JOIN ledgers l ON b.ledgerId = l.id
      WHERE l.id IS NULL AND b.isDeleted = 0
    ''');
    if (orphanBudgetsByLedger.isNotEmpty) {
      orphans['budgets_invalid_ledger'] =
          orphanBudgetsByLedger.map((m) => m['id'] as String).toList();
    }

    // 3.5 检测 budgets 中无效的 categoryId
    final orphanBudgetsByCategory = await db.rawQuery('''
      SELECT b.id FROM budgets b
      LEFT JOIN categories c ON b.categoryId = c.id
      WHERE b.categoryId IS NOT NULL AND c.id IS NULL AND b.isDeleted = 0
    ''');
    if (orphanBudgetsByCategory.isNotEmpty) {
      orphans['budgets_invalid_category'] =
          orphanBudgetsByCategory.map((m) => m['id'] as String).toList();
    }

    // 4. 检测 categories 中无效的 parentId（自引用）
    final orphanCategoriesByParent = await db.rawQuery('''
      SELECT c.id FROM categories c
      LEFT JOIN categories p ON c.parentId = p.id
      WHERE c.parentId IS NOT NULL AND p.id IS NULL AND c.isDeleted = 0
    ''');
    if (orphanCategoriesByParent.isNotEmpty) {
      orphans['categories_invalid_parent'] =
          orphanCategoriesByParent.map((m) => m['id'] as String).toList();
    }

    // 5. 检测 transaction_splits 中无效的 transactionId
    final orphanSplits = await db.rawQuery('''
      SELECT ts.id FROM transaction_splits ts
      LEFT JOIN transactions t ON ts.transactionId = t.id
      WHERE t.id IS NULL
    ''');
    if (orphanSplits.isNotEmpty) {
      orphans['transaction_splits_invalid_transaction'] =
          orphanSplits.map((m) => m['id'] as String).toList();
    }

    // 6. 检测 savings_deposits 中无效的 goalId
    final orphanDeposits = await db.rawQuery('''
      SELECT sd.id FROM savings_deposits sd
      LEFT JOIN savings_goals sg ON sd.goalId = sg.id
      WHERE sg.id IS NULL
    ''');
    if (orphanDeposits.isNotEmpty) {
      orphans['savings_deposits_invalid_goal'] =
          orphanDeposits.map((m) => m['id'] as String).toList();
    }

    // 7. 检测 debt_payments 中无效的 debtId
    final orphanPayments = await db.rawQuery('''
      SELECT dp.id FROM debt_payments dp
      LEFT JOIN debts d ON dp.debtId = d.id
      WHERE d.id IS NULL
    ''');
    if (orphanPayments.isNotEmpty) {
      orphans['debt_payments_invalid_debt'] =
          orphanPayments.map((m) => m['id'] as String).toList();
    }

    if (orphans.isNotEmpty) {
      _logger.warning('Detected orphan data: $orphans', tag: 'DB');
    }

    return orphans;
  }

  /// 清理孤儿数据
  ///
  /// 删除所有检测到的孤儿记录
  @override
  Future<Map<String, int>> cleanupOrphanData() async {
    final db = await database;
    final results = <String, int>{};

    // 清理无效的 transaction_splits
    results['transaction_splits'] = await db.rawDelete('''
      DELETE FROM transaction_splits WHERE id IN (
        SELECT ts.id FROM transaction_splits ts
        LEFT JOIN transactions t ON ts.transactionId = t.id
        WHERE t.id IS NULL
      )
    ''');

    // 清理无效的 savings_deposits
    results['savings_deposits'] = await db.rawDelete('''
      DELETE FROM savings_deposits WHERE id IN (
        SELECT sd.id FROM savings_deposits sd
        LEFT JOIN savings_goals sg ON sd.goalId = sg.id
        WHERE sg.id IS NULL
      )
    ''');

    // 清理无效的 debt_payments
    results['debt_payments'] = await db.rawDelete('''
      DELETE FROM debt_payments WHERE id IN (
        SELECT dp.id FROM debt_payments dp
        LEFT JOIN debts d ON dp.debtId = d.id
        WHERE d.id IS NULL
      )
    ''');

    _logger.info('Cleaned up orphan data: $results', tag: 'DB');
    return results;
  }

  /// 获取数据库统计信息
  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    final stats = <String, dynamic>{};

    // 记录数统计
    final tables = [
      'transactions', 'accounts', 'categories', 'ledgers', 'budgets',
      'templates', 'recurring_transactions', 'credit_cards', 'savings_goals',
      'bill_reminders', 'investment_accounts', 'debts',
    ];

    for (final table in tables) {
      try {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        stats['${table}_count'] = result.first['count'];

        // 统计软删除数量（如果表支持）
        if (['transactions', 'accounts', 'categories', 'ledgers', 'budgets'].contains(table)) {
          final deletedResult = await db.rawQuery(
            'SELECT COUNT(*) as count FROM $table WHERE isDeleted = 1'
          );
          stats['${table}_deleted_count'] = deletedResult.first['count'];
        }
      } catch (e) {
        stats['${table}_count'] = 'error';
      }
    }

    // 数据库版本
    stats['version'] = currentVersion;

    return stats;
  }
}
