import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction.dart' as model;
import '../models/transaction_split.dart';
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
import 'package:flutter/material.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ai_bookkeeping.db');

    return await openDatabase(
      path,
      version: 11,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        createdAt INTEGER NOT NULL
      )
    ''');

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
        createdAt INTEGER NOT NULL
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
        isCustom INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Ledgers table
    await db.execute('''
      CREATE TABLE ledgers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        iconCode INTEGER NOT NULL,
        colorValue INTEGER NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL
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
        budgetType INTEGER NOT NULL DEFAULT 0,
        enableCarryover INTEGER NOT NULL DEFAULT 0,
        carryoverSurplusOnly INTEGER NOT NULL DEFAULT 1
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
        createdAt INTEGER NOT NULL
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
        createdAt INTEGER NOT NULL
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
        createdAt INTEGER NOT NULL
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
  }

  // Transaction CRUD
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
    });

    // Insert splits if this is a split transaction
    if (transaction.isSplit && transaction.splits != null) {
      for (final split in transaction.splits!) {
        await insertTransactionSplit(split);
      }
    }

    return result;
  }

  Future<List<model.Transaction>> getTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');

    final transactions = <model.Transaction>[];
    for (final map in maps) {
      final isSplit = (map['isSplit'] as int?) == 1;
      List<TransactionSplit>? splits;

      if (isSplit) {
        splits = await getTransactionSplits(map['id'] as String);
      }

      final tagsString = map['tags'] as String?;
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
      ));
    }

    return transactions;
  }

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

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    // Splits will be deleted automatically due to CASCADE
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Transaction Split CRUD
  Future<int> insertTransactionSplit(TransactionSplit split) async {
    final db = await database;
    return await db.insert('transaction_splits', split.toMap());
  }

  Future<List<TransactionSplit>> getTransactionSplits(String transactionId) async {
    final db = await database;
    final maps = await db.query(
      'transaction_splits',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    return maps.map((map) => TransactionSplit.fromMap(map)).toList();
  }

  Future<int> deleteTransactionSplits(String transactionId) async {
    final db = await database;
    return await db.delete(
      'transaction_splits',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
  }

  // Account CRUD
  Future<int> insertAccount(Account account) async {
    final db = await database;
    return await db.insert('accounts', {
      'id': account.id,
      'name': account.name,
      'type': account.type.index,
      'balance': account.balance,
      'iconCode': account.icon.codePoint,
      'colorValue': account.color.value,
      'isDefault': account.isDefault ? 1 : 0,
      'createdAt': account.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final maps = await db.query('accounts');
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

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return await db.update(
      'accounts',
      {
        'name': account.name,
        'type': account.type.index,
        'balance': account.balance,
        'iconCode': account.icon.codePoint,
        'colorValue': account.color.value,
        'isDefault': account.isDefault ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(String id) async {
    final db = await database;
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // Category CRUD
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', {
      'id': category.id,
      'name': category.name,
      'iconCode': category.icon.codePoint,
      'colorValue': category.color.value,
      'isExpense': category.isExpense ? 1 : 0,
      'parentId': category.parentId,
      'sortOrder': category.sortOrder,
      'isCustom': category.isCustom ? 1 : 0,
    });
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'sortOrder ASC');
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

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      {
        'name': category.name,
        'iconCode': category.icon.codePoint,
        'colorValue': category.color.value,
        'isExpense': category.isExpense ? 1 : 0,
        'parentId': category.parentId,
        'sortOrder': category.sortOrder,
        'isCustom': category.isCustom ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Ledger CRUD
  Future<int> insertLedger(Ledger ledger) async {
    final db = await database;
    return await db.insert('ledgers', {
      'id': ledger.id,
      'name': ledger.name,
      'description': ledger.description,
      'iconCode': ledger.icon.codePoint,
      'colorValue': ledger.color.value,
      'isDefault': ledger.isDefault ? 1 : 0,
      'createdAt': ledger.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<List<Ledger>> getLedgers() async {
    final db = await database;
    final maps = await db.query('ledgers');
    return maps.map((map) => Ledger(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['colorValue'] as int),
      isDefault: (map['isDefault'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    )).toList();
  }

  Future<int> updateLedger(Ledger ledger) async {
    final db = await database;
    return await db.update(
      'ledgers',
      {
        'name': ledger.name,
        'description': ledger.description,
        'iconCode': ledger.icon.codePoint,
        'colorValue': ledger.color.value,
        'isDefault': ledger.isDefault ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [ledger.id],
    );
  }

  Future<int> deleteLedger(String id) async {
    final db = await database;
    return await db.delete('ledgers', where: 'id = ?', whereArgs: [id]);
  }

  // Budget CRUD
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
      'colorValue': budget.color.value,
      'isEnabled': budget.isEnabled ? 1 : 0,
      'createdAt': budget.createdAt.millisecondsSinceEpoch,
      'budgetType': budget.budgetType.index,
      'enableCarryover': budget.enableCarryover ? 1 : 0,
      'carryoverSurplusOnly': budget.carryoverSurplusOnly ? 1 : 0,
    });
  }

  Future<List<Budget>> getBudgets() async {
    final db = await database;
    final maps = await db.query('budgets');
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
        'colorValue': budget.color.value,
        'isEnabled': budget.isEnabled ? 1 : 0,
        'budgetType': budget.budgetType.index,
        'enableCarryover': budget.enableCarryover ? 1 : 0,
        'carryoverSurplusOnly': budget.carryoverSurplusOnly ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(String id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Budget Carryover CRUD
  Future<int> insertBudgetCarryover(BudgetCarryover carryover) async {
    final db = await database;
    return await db.insert('budget_carryovers', carryover.toMap());
  }

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

  Future<int> deleteBudgetCarryover(String id) async {
    final db = await database;
    return await db.delete('budget_carryovers', where: 'id = ?', whereArgs: [id]);
  }

  // Zero-Based Allocation CRUD
  Future<int> insertZeroBasedAllocation(ZeroBasedAllocation allocation) async {
    final db = await database;
    return await db.insert('zero_based_allocations', allocation.toMap());
  }

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

  Future<int> updateZeroBasedAllocation(ZeroBasedAllocation allocation) async {
    final db = await database;
    return await db.update(
      'zero_based_allocations',
      allocation.toMap(),
      where: 'id = ?',
      whereArgs: [allocation.id],
    );
  }

  Future<int> deleteZeroBasedAllocation(String id) async {
    final db = await database;
    return await db.delete('zero_based_allocations', where: 'id = ?', whereArgs: [id]);
  }

  // Template CRUD
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
      'colorValue': template.color.value,
      'useCount': template.useCount,
      'createdAt': template.createdAt.millisecondsSinceEpoch,
      'lastUsedAt': template.lastUsedAt?.millisecondsSinceEpoch,
    });
  }

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
        'colorValue': template.color.value,
        'useCount': template.useCount,
        'lastUsedAt': template.lastUsedAt?.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteTemplate(String id) async {
    final db = await database;
    return await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementTemplateUseCount(String id) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE templates
      SET useCount = useCount + 1, lastUsedAt = ?
      WHERE id = ?
    ''', [DateTime.now().millisecondsSinceEpoch, id]);
  }

  // Recurring Transaction CRUD
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
      'colorValue': recurring.color.value,
      'createdAt': recurring.createdAt.millisecondsSinceEpoch,
    });
  }

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
        'colorValue': recurring.color.value,
      },
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
  }

  Future<int> deleteRecurringTransaction(String id) async {
    final db = await database;
    return await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Credit Card CRUD
  Future<int> insertCreditCard(CreditCard card) async {
    final db = await database;
    return await db.insert('credit_cards', card.toMap());
  }

  Future<List<CreditCard>> getCreditCards() async {
    final db = await database;
    final maps = await db.query('credit_cards', orderBy: 'createdAt DESC');
    return maps.map((map) => CreditCard.fromMap(map)).toList();
  }

  Future<int> updateCreditCard(CreditCard card) async {
    final db = await database;
    return await db.update(
      'credit_cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCreditCard(String id) async {
    final db = await database;
    return await db.delete('credit_cards', where: 'id = ?', whereArgs: [id]);
  }

  // Savings Goal CRUD
  Future<int> insertSavingsGoal(savings.SavingsGoal goal) async {
    final db = await database;
    return await db.insert('savings_goals', goal.toMap());
  }

  Future<List<savings.SavingsGoal>> getSavingsGoals() async {
    final db = await database;
    final maps = await db.query('savings_goals', orderBy: 'createdAt DESC');
    return maps.map((map) => savings.SavingsGoal.fromMap(map)).toList();
  }

  Future<int> updateSavingsGoal(savings.SavingsGoal goal) async {
    final db = await database;
    return await db.update(
      'savings_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteSavingsGoal(String id) async {
    final db = await database;
    // Deposits will be deleted automatically due to CASCADE
    return await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  // Savings Deposit CRUD
  Future<int> insertSavingsDeposit(savings.SavingsDeposit deposit) async {
    final db = await database;
    return await db.insert('savings_deposits', deposit.toMap());
  }

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

  Future<int> deleteSavingsDeposit(String id) async {
    final db = await database;
    return await db.delete('savings_deposits', where: 'id = ?', whereArgs: [id]);
  }

  // Bill Reminder CRUD
  Future<int> insertBillReminder(BillReminder reminder) async {
    final db = await database;
    return await db.insert('bill_reminders', reminder.toMap());
  }

  Future<List<BillReminder>> getBillReminders() async {
    final db = await database;
    final maps = await db.query('bill_reminders', orderBy: 'dayOfMonth ASC');
    return maps.map((map) => BillReminder.fromMap(map)).toList();
  }

  Future<int> updateBillReminder(BillReminder reminder) async {
    final db = await database;
    return await db.update(
      'bill_reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteBillReminder(String id) async {
    final db = await database;
    return await db.delete('bill_reminders', where: 'id = ?', whereArgs: [id]);
  }

  // Investment Account CRUD
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

  Future<int> deleteInvestmentAccount(String id) async {
    final db = await database;
    return await db.delete('investment_accounts', where: 'id = ?', whereArgs: [id]);
  }

  // Debt CRUD
  Future<int> insertDebt(Debt debt) async {
    final db = await database;
    return await db.insert('debts', debt.toMap());
  }

  Future<List<Debt>> getDebts() async {
    final db = await database;
    final maps = await db.query('debts', orderBy: 'createdAt DESC');
    return maps.map((map) => Debt.fromMap(map)).toList();
  }

  Future<int> updateDebt(Debt debt) async {
    final db = await database;
    return await db.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  Future<int> deleteDebt(String id) async {
    final db = await database;
    // Payments will be deleted automatically due to CASCADE
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  // Debt Payment CRUD
  Future<int> insertDebtPayment(DebtPayment payment) async {
    final db = await database;
    return await db.insert('debt_payments', payment.toMap());
  }

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

  Future<int> deleteDebtPayment(String id) async {
    final db = await database;
    return await db.delete('debt_payments', where: 'id = ?', whereArgs: [id]);
  }

  // Ledger Member CRUD
  Future<int> insertLedgerMember(LedgerMember member) async {
    final db = await database;
    return await db.insert('ledger_members', member.toMap());
  }

  Future<List<LedgerMember>> getLedgerMembers() async {
    final db = await database;
    final maps = await db.query('ledger_members', orderBy: 'joinedAt DESC');
    return maps.map((map) => LedgerMember.fromMap(map)).toList();
  }

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

  Future<int> updateLedgerMember(LedgerMember member) async {
    final db = await database;
    return await db.update(
      'ledger_members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  Future<int> deleteLedgerMember(String id) async {
    final db = await database;
    return await db.delete('ledger_members', where: 'id = ?', whereArgs: [id]);
  }

  // Member Invite CRUD
  Future<int> insertMemberInvite(MemberInvite invite) async {
    final db = await database;
    return await db.insert('member_invites', invite.toMap());
  }

  Future<List<MemberInvite>> getMemberInvites() async {
    final db = await database;
    final maps = await db.query('member_invites', orderBy: 'createdAt DESC');
    return maps.map((map) => MemberInvite.fromMap(map)).toList();
  }

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

  Future<int> updateMemberInvite(MemberInvite invite) async {
    final db = await database;
    return await db.update(
      'member_invites',
      invite.toMap(),
      where: 'id = ?',
      whereArgs: [invite.id],
    );
  }

  Future<int> deleteMemberInvite(String id) async {
    final db = await database;
    return await db.delete('member_invites', where: 'id = ?', whereArgs: [id]);
  }

  // Member Budget CRUD
  Future<int> insertMemberBudget(MemberBudget budget) async {
    final db = await database;
    return await db.insert('member_budgets', budget.toMap());
  }

  Future<List<MemberBudget>> getMemberBudgets() async {
    final db = await database;
    final maps = await db.query('member_budgets', orderBy: 'createdAt DESC');
    return maps.map((map) => MemberBudget.fromMap(map)).toList();
  }

  Future<List<MemberBudget>> getMemberBudgetsForLedger(String ledgerId) async {
    final db = await database;
    final maps = await db.query(
      'member_budgets',
      where: 'ledgerId = ?',
      whereArgs: [ledgerId],
    );
    return maps.map((map) => MemberBudget.fromMap(map)).toList();
  }

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

  Future<int> updateMemberBudget(MemberBudget budget) async {
    final db = await database;
    return await db.update(
      'member_budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteMemberBudget(String id) async {
    final db = await database;
    return await db.delete('member_budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Expense Approval CRUD
  Future<int> insertExpenseApproval(ExpenseApproval approval) async {
    final db = await database;
    return await db.insert('expense_approvals', approval.toMap());
  }

  Future<List<ExpenseApproval>> getExpenseApprovals() async {
    final db = await database;
    final maps = await db.query('expense_approvals', orderBy: 'createdAt DESC');
    return maps.map((map) => ExpenseApproval.fromMap(map)).toList();
  }

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

  Future<int> updateExpenseApproval(ExpenseApproval approval) async {
    final db = await database;
    return await db.update(
      'expense_approvals',
      approval.toMap(),
      where: 'id = ?',
      whereArgs: [approval.id],
    );
  }

  Future<int> deleteExpenseApproval(String id) async {
    final db = await database;
    return await db.delete('expense_approvals', where: 'id = ?', whereArgs: [id]);
  }

  // Initialize default data
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
      await insertLedger(DefaultLedgers.defaultLedger);
    }
  }
}
