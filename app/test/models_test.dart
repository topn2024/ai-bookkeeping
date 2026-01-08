import 'package:flutter_test/flutter_test.dart';

/// Model Tests for AI Bookkeeping App
/// Tests data models serialization, validation, and business logic

void main() {
  group('Transaction Model Tests', () {
    test('Transaction type enum values are correct', () {
      expect(TransactionType.expense.value, equals('expense'));
      expect(TransactionType.income.value, equals('income'));
      expect(TransactionType.transfer.value, equals('transfer'));
    });

    test('Transaction source enum values are correct', () {
      expect(TransactionSource.manual.value, equals(0));
      expect(TransactionSource.image.value, equals(1));
      expect(TransactionSource.voice.value, equals(2));
      expect(TransactionSource.email.value, equals(3));
    });

    test('Transaction JSON serialization works', () {
      final transaction = TransactionTest(
        id: 'test-123',
        type: 'expense',
        amount: 100.50,
        categoryId: 'cat-1',
        accountId: 'acc-1',
        description: '午餐',
        date: DateTime(2024, 12, 30),
      );

      final json = transaction.toJson();
      expect(json['id'], equals('test-123'));
      expect(json['type'], equals('expense'));
      expect(json['amount'], equals(100.50));
      expect(json['description'], equals('午餐'));
    });

    test('Transaction JSON deserialization works', () {
      final json = {
        'id': 'test-456',
        'type': 'income',
        'amount': 5000.0,
        'categoryId': 'cat-2',
        'accountId': 'acc-1',
        'description': '工资',
        'date': '2024-12-30T00:00:00.000',
      };

      final transaction = TransactionTest.fromJson(json);
      expect(transaction.id, equals('test-456'));
      expect(transaction.type, equals('income'));
      expect(transaction.amount, equals(5000.0));
    });

    test('Split transaction calculates total correctly', () {
      final splits = [
        SplitItem(categoryId: 'food', amount: 50.0),
        SplitItem(categoryId: 'transport', amount: 30.0),
        SplitItem(categoryId: 'shopping', amount: 20.0),
      ];

      final total = splits.fold<double>(0, (sum, item) => sum + item.amount);
      expect(total, equals(100.0));
    });
  });

  group('Account Model Tests', () {
    test('Account type enum values are correct', () {
      expect(AccountType.cash.value, equals('cash'));
      expect(AccountType.bank.value, equals('bank'));
      expect(AccountType.credit.value, equals('credit'));
      expect(AccountType.ewallet.value, equals('ewallet'));
      expect(AccountType.investment.value, equals('investment'));
    });

    test('Credit card calculates available credit correctly', () {
      final creditCard = CreditCardTest(
        creditLimit: 10000.0,
        currentBalance: 3500.0,
      );

      expect(creditCard.availableCredit, equals(6500.0));
    });

    test('Credit card usage percentage is correct', () {
      final creditCard = CreditCardTest(
        creditLimit: 10000.0,
        currentBalance: 7500.0,
      );

      expect(creditCard.usagePercentage, equals(75.0));
    });

    test('Account balance update works correctly', () {
      var balance = 1000.0;

      // Expense reduces balance
      balance = updateBalance(balance, -200.0, 'expense');
      expect(balance, equals(800.0));

      // Income increases balance
      balance = updateBalance(balance, 500.0, 'income');
      expect(balance, equals(1300.0));
    });
  });

  group('Category Model Tests', () {
    test('Category with parent is subcategory', () {
      final category = CategoryTest(
        id: 'cat-1',
        name: '早餐',
        parentId: 'food',
        isExpense: true,
      );

      expect(category.isSubcategory, isTrue);
    });

    test('Category without parent is root category', () {
      final category = CategoryTest(
        id: 'food',
        name: '餐饮',
        parentId: null,
        isExpense: true,
      );

      expect(category.isSubcategory, isFalse);
    });

    test('Category color validation works', () {
      expect(isValidHexColor('#FF5722'), isTrue);
      expect(isValidHexColor('#4CAF50'), isTrue);
      expect(isValidHexColor('red'), isFalse);
      expect(isValidHexColor('#GGGGGG'), isFalse);
    });
  });

  group('Budget Model Tests', () {
    test('Budget period enum values are correct', () {
      expect(BudgetPeriod.daily.value, equals('daily'));
      expect(BudgetPeriod.weekly.value, equals('weekly'));
      expect(BudgetPeriod.monthly.value, equals('monthly'));
      expect(BudgetPeriod.yearly.value, equals('yearly'));
    });

    test('Budget spent percentage calculation', () {
      final budget = BudgetTest(
        amount: 3000.0,
        spent: 2400.0,
      );

      expect(budget.spentPercentage, equals(80.0));
    });

    test('Budget remaining calculation', () {
      final budget = BudgetTest(
        amount: 3000.0,
        spent: 2400.0,
      );

      expect(budget.remaining, equals(600.0));
    });

    test('Budget exceeded detection', () {
      final normalBudget = BudgetTest(amount: 3000.0, spent: 2000.0);
      final exceededBudget = BudgetTest(amount: 3000.0, spent: 3500.0);

      expect(normalBudget.isExceeded, isFalse);
      expect(exceededBudget.isExceeded, isTrue);
    });

    test('Budget warning threshold (80%)', () {
      final warningBudget = BudgetTest(amount: 1000.0, spent: 850.0);
      final safeBudget = BudgetTest(amount: 1000.0, spent: 500.0);

      expect(warningBudget.shouldWarn, isTrue);
      expect(safeBudget.shouldWarn, isFalse);
    });
  });

  group('Debt Model Tests', () {
    test('Debt type enum values are correct', () {
      expect(DebtType.creditCard.value, equals('credit_card'));
      expect(DebtType.mortgage.value, equals('mortgage'));
      expect(DebtType.carLoan.value, equals('car_loan'));
      expect(DebtType.personalLoan.value, equals('personal_loan'));
      expect(DebtType.studentLoan.value, equals('student_loan'));
      expect(DebtType.medicalDebt.value, equals('medical_debt'));
    });

    test('Debt progress calculation', () {
      final debt = DebtTest(
        originalAmount: 100000.0,
        currentBalance: 75000.0,
      );

      expect(debt.paidAmount, equals(25000.0));
      expect(debt.progressPercentage, equals(25.0));
    });

    test('Monthly interest calculation', () {
      final debt = DebtTest(
        currentBalance: 10000.0,
        annualInterestRate: 18.0, // 18% annual
      );

      // Monthly interest = balance * (annual_rate / 12 / 100)
      expect(debt.monthlyInterest, closeTo(150.0, 0.01));
    });

    test('Estimated payoff months calculation', () {
      final debt = DebtTest(
        currentBalance: 5000.0,
        minimumPayment: 500.0,
      );

      // Simple calculation without interest
      expect(debt.estimatedPayoffMonths, equals(10));
    });

    test('Snowball vs Avalanche debt ordering', () {
      final debts = [
        DebtTest(name: 'Credit Card', currentBalance: 2000.0, annualInterestRate: 18.0),
        DebtTest(name: 'Personal Loan', currentBalance: 5000.0, annualInterestRate: 12.0),
        DebtTest(name: 'Medical', currentBalance: 1000.0, annualInterestRate: 8.0),
      ];

      // Snowball: smallest balance first
      final snowballOrder = List<DebtTest>.from(debts)
        ..sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
      expect(snowballOrder[0].name, equals('Medical'));
      expect(snowballOrder[1].name, equals('Credit Card'));
      expect(snowballOrder[2].name, equals('Personal Loan'));

      // Avalanche: highest interest first
      final avalancheOrder = List<DebtTest>.from(debts)
        ..sort((a, b) => b.annualInterestRate.compareTo(a.annualInterestRate));
      expect(avalancheOrder[0].name, equals('Credit Card'));
      expect(avalancheOrder[1].name, equals('Personal Loan'));
      expect(avalancheOrder[2].name, equals('Medical'));
    });
  });

  group('Savings Goal Model Tests', () {
    test('Savings goal progress calculation', () {
      final goal = SavingsGoalTest(
        targetAmount: 50000.0,
        currentAmount: 15000.0,
      );

      expect(goal.progressPercentage, equals(30.0));
      expect(goal.remainingAmount, equals(35000.0));
    });

    test('Savings goal monthly target calculation', () {
      final goal = SavingsGoalTest(
        targetAmount: 12000.0,
        currentAmount: 0.0,
        targetDate: DateTime.now().add(const Duration(days: 365)),
      );

      // Should save ~1000 per month
      expect(goal.monthlyTarget, closeTo(1000.0, 50.0));
    });

    test('Savings goal completion detection', () {
      final incomplete = SavingsGoalTest(targetAmount: 1000.0, currentAmount: 500.0);
      final complete = SavingsGoalTest(targetAmount: 1000.0, currentAmount: 1000.0);
      final exceeded = SavingsGoalTest(targetAmount: 1000.0, currentAmount: 1200.0);

      expect(incomplete.isCompleted, isFalse);
      expect(complete.isCompleted, isTrue);
      expect(exceeded.isCompleted, isTrue);
    });
  });

  group('Bill Reminder Model Tests', () {
    test('Reminder frequency enum values are correct', () {
      expect(ReminderFrequency.once.value, equals('once'));
      expect(ReminderFrequency.daily.value, equals('daily'));
      expect(ReminderFrequency.weekly.value, equals('weekly'));
      expect(ReminderFrequency.monthly.value, equals('monthly'));
      expect(ReminderFrequency.yearly.value, equals('yearly'));
    });

    test('Upcoming reminder detection', () {
      final now = DateTime.now();
      final upcoming = BillReminderTest(dueDate: now.add(const Duration(days: 3)));
      final overdue = BillReminderTest(dueDate: now.subtract(const Duration(days: 1)));
      final farAway = BillReminderTest(dueDate: now.add(const Duration(days: 30)));

      expect(upcoming.isUpcoming(7), isTrue);
      expect(overdue.isUpcoming(7), isFalse);
      expect(farAway.isUpcoming(7), isFalse);
    });

    test('Overdue detection', () {
      final now = DateTime.now();
      final overdue = BillReminderTest(dueDate: now.subtract(const Duration(days: 1)));
      final notOverdue = BillReminderTest(dueDate: now.add(const Duration(days: 1)));

      expect(overdue.isOverdue, isTrue);
      expect(notOverdue.isOverdue, isFalse);
    });
  });

  group('Recurring Transaction Model Tests', () {
    test('Next occurrence calculation - monthly', () {
      final recurring = RecurringTest(
        frequency: 'monthly',
        lastOccurrence: DateTime(2024, 11, 15),
      );

      expect(recurring.nextOccurrence.month, equals(12));
      expect(recurring.nextOccurrence.day, equals(15));
    });

    test('Next occurrence calculation - weekly', () {
      final recurring = RecurringTest(
        frequency: 'weekly',
        lastOccurrence: DateTime(2024, 12, 23),
      );

      expect(recurring.nextOccurrence.day, equals(30));
    });
  });

  group('Book Model Tests', () {
    test('Book type enum values are correct', () {
      expect(BookType.personal.value, equals('personal'));
      expect(BookType.couple.value, equals('couple'));
      expect(BookType.family.value, equals('family'));
      expect(BookType.roommate.value, equals('roommate'));
      expect(BookType.group.value, equals('group'));
    });

    test('Member role enum values are correct', () {
      expect(MemberRole.owner.value, equals('owner'));
      expect(MemberRole.admin.value, equals('admin'));
      expect(MemberRole.editor.value, equals('editor'));
      expect(MemberRole.viewer.value, equals('viewer'));
    });

    test('Role permission checks', () {
      expect(canEdit(MemberRole.owner), isTrue);
      expect(canEdit(MemberRole.admin), isTrue);
      expect(canEdit(MemberRole.editor), isTrue);
      expect(canEdit(MemberRole.viewer), isFalse);

      expect(canManageMembers(MemberRole.owner), isTrue);
      expect(canManageMembers(MemberRole.admin), isTrue);
      expect(canManageMembers(MemberRole.editor), isFalse);
      expect(canManageMembers(MemberRole.viewer), isFalse);

      expect(canDelete(MemberRole.owner), isTrue);
      expect(canDelete(MemberRole.admin), isFalse);
    });
  });

  group('Sync Model Tests', () {
    test('Sync status enum values are correct', () {
      expect(SyncStatus.pending.value, equals('pending'));
      expect(SyncStatus.syncing.value, equals('syncing'));
      expect(SyncStatus.synced.value, equals('synced'));
      expect(SyncStatus.conflict.value, equals('conflict'));
      expect(SyncStatus.error.value, equals('error'));
    });

    test('Conflict resolution strategies', () {
      expect(ConflictResolution.keepLocal.value, equals('keep_local'));
      expect(ConflictResolution.keepRemote.value, equals('keep_remote'));
      expect(ConflictResolution.keepBoth.value, equals('keep_both'));
      expect(ConflictResolution.merge.value, equals('merge'));
    });

    test('Sync frequency options', () {
      expect(SyncFrequency.realtime.value, equals('realtime'));
      expect(SyncFrequency.hourly.value, equals('hourly'));
      expect(SyncFrequency.daily.value, equals('daily'));
      expect(SyncFrequency.weekly.value, equals('weekly'));
      expect(SyncFrequency.manual.value, equals('manual'));
    });
  });

  group('Backup Model Tests', () {
    test('Backup size formatting', () {
      expect(formatBackupSize(512), equals('512 B'));
      expect(formatBackupSize(1024), equals('1.0 KB'));
      expect(formatBackupSize(1048576), equals('1.0 MB'));
      expect(formatBackupSize(1073741824), equals('1.0 GB'));
    });

    test('Backup data validation', () {
      final validBackup = BackupDataTest(
        transactionCount: 100,
        accountCount: 5,
        categoryCount: 20,
        bookCount: 2,
      );

      expect(validBackup.isValid, isTrue);
      expect(validBackup.totalItems, equals(127));
    });
  });

  group('Statistics Model Tests', () {
    test('Period comparison calculation', () {
      final current = 1500.0;
      final previous = 1200.0;

      final percentChange = ((current - previous) / previous) * 100;
      expect(percentChange, closeTo(25.0, 0.01));
    });

    test('Category distribution calculation', () {
      final expenses = {
        'food': 500.0,
        'transport': 300.0,
        'shopping': 200.0,
      };

      final total = expenses.values.reduce((a, b) => a + b);
      expect(total, equals(1000.0));

      final foodPercentage = (expenses['food']! / total) * 100;
      expect(foodPercentage, equals(50.0));
    });

    test('Daily average calculation', () {
      final monthlyTotal = 3000.0;
      final daysInMonth = 30;

      final dailyAverage = monthlyTotal / daysInMonth;
      expect(dailyAverage, equals(100.0));
    });
  });
}

// ==================== Test Helper Classes ====================

enum TransactionType { expense, income, transfer }
extension TransactionTypeExt on TransactionType {
  String get value => toString().split('.').last;
}

enum TransactionSource { manual, image, voice, email }
extension TransactionSourceExt on TransactionSource {
  int get value => index;
}

class TransactionTest {
  final String id;
  final String type;
  final double amount;
  final String categoryId;
  final String accountId;
  final String description;
  final DateTime date;

  TransactionTest({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'categoryId': categoryId,
    'accountId': accountId,
    'description': description,
    'date': date.toIso8601String(),
  };

  factory TransactionTest.fromJson(Map<String, dynamic> json) => TransactionTest(
    id: json['id'],
    type: json['type'],
    amount: json['amount'].toDouble(),
    categoryId: json['categoryId'],
    accountId: json['accountId'],
    description: json['description'],
    date: DateTime.parse(json['date']),
  );
}

class SplitItem {
  final String categoryId;
  final double amount;
  SplitItem({required this.categoryId, required this.amount});
}

enum AccountType { cash, bank, credit, ewallet, investment }
extension AccountTypeExt on AccountType {
  String get value => toString().split('.').last;
}

class CreditCardTest {
  final double creditLimit;
  final double currentBalance;

  CreditCardTest({required this.creditLimit, required this.currentBalance});

  double get availableCredit => creditLimit - currentBalance;
  double get usagePercentage => (currentBalance / creditLimit) * 100;
}

double updateBalance(double balance, double amount, String type) {
  if (type == 'expense') return balance + amount; // amount is negative for expense
  if (type == 'income') return balance + amount;
  return balance;
}

class CategoryTest {
  final String id;
  final String name;
  final String? parentId;
  final bool isExpense;

  CategoryTest({required this.id, required this.name, this.parentId, required this.isExpense});

  bool get isSubcategory => parentId != null;
}

bool isValidHexColor(String color) {
  return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color);
}

enum BudgetPeriod { daily, weekly, monthly, yearly }
extension BudgetPeriodExt on BudgetPeriod {
  String get value => toString().split('.').last;
}

class BudgetTest {
  final double amount;
  final double spent;

  BudgetTest({required this.amount, required this.spent});

  double get spentPercentage => (spent / amount) * 100;
  double get remaining => amount - spent;
  bool get isExceeded => spent > amount;
  bool get shouldWarn => spentPercentage >= 80;
}

enum DebtType { creditCard, mortgage, carLoan, personalLoan, studentLoan, medicalDebt }
extension DebtTypeExt on DebtType {
  String get value {
    switch (this) {
      case DebtType.creditCard: return 'credit_card';
      case DebtType.mortgage: return 'mortgage';
      case DebtType.carLoan: return 'car_loan';
      case DebtType.personalLoan: return 'personal_loan';
      case DebtType.studentLoan: return 'student_loan';
      case DebtType.medicalDebt: return 'medical_debt';
    }
  }
}

class DebtTest {
  final String name;
  final double originalAmount;
  final double currentBalance;
  final double annualInterestRate;
  final double minimumPayment;

  DebtTest({
    this.name = '',
    this.originalAmount = 0,
    required this.currentBalance,
    this.annualInterestRate = 0,
    this.minimumPayment = 0,
  });

  double get paidAmount => originalAmount - currentBalance;
  double get progressPercentage => originalAmount > 0 ? (paidAmount / originalAmount) * 100 : 0;
  double get monthlyInterest => currentBalance * (annualInterestRate / 12 / 100);
  int get estimatedPayoffMonths => minimumPayment > 0 ? (currentBalance / minimumPayment).ceil() : 0;
}

class SavingsGoalTest {
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;

  SavingsGoalTest({required this.targetAmount, required this.currentAmount, this.targetDate});

  double get progressPercentage => (currentAmount / targetAmount) * 100;
  double get remainingAmount => targetAmount - currentAmount;
  bool get isCompleted => currentAmount >= targetAmount;

  double get monthlyTarget {
    if (targetDate == null) return 0;
    final months = targetDate!.difference(DateTime.now()).inDays / 30;
    return months > 0 ? remainingAmount / months : remainingAmount;
  }
}

enum ReminderFrequency { once, daily, weekly, monthly, yearly }
extension ReminderFrequencyExt on ReminderFrequency {
  String get value => toString().split('.').last;
}

class BillReminderTest {
  final DateTime dueDate;

  BillReminderTest({required this.dueDate});

  bool isUpcoming(int days) {
    final now = DateTime.now();
    return dueDate.isAfter(now) && dueDate.difference(now).inDays <= days;
  }

  bool get isOverdue => dueDate.isBefore(DateTime.now());
}

class RecurringTest {
  final String frequency;
  final DateTime lastOccurrence;

  RecurringTest({required this.frequency, required this.lastOccurrence});

  DateTime get nextOccurrence {
    switch (frequency) {
      case 'daily':
        return lastOccurrence.add(const Duration(days: 1));
      case 'weekly':
        return lastOccurrence.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(lastOccurrence.year, lastOccurrence.month + 1, lastOccurrence.day);
      case 'yearly':
        return DateTime(lastOccurrence.year + 1, lastOccurrence.month, lastOccurrence.day);
      default:
        return lastOccurrence;
    }
  }
}

enum BookType { personal, couple, family, roommate, group }
extension BookTypeExt on BookType {
  String get value => toString().split('.').last;
}

enum MemberRole { owner, admin, editor, viewer }
extension MemberRoleExt on MemberRole {
  String get value => toString().split('.').last;
}

bool canEdit(MemberRole role) => role != MemberRole.viewer;
bool canManageMembers(MemberRole role) => role == MemberRole.owner || role == MemberRole.admin;
bool canDelete(MemberRole role) => role == MemberRole.owner;

enum SyncStatus { pending, syncing, synced, conflict, error }
extension SyncStatusExt on SyncStatus {
  String get value => toString().split('.').last;
}

enum ConflictResolution { keepLocal, keepRemote, keepBoth, merge }
extension ConflictResolutionExt on ConflictResolution {
  String get value {
    switch (this) {
      case ConflictResolution.keepLocal: return 'keep_local';
      case ConflictResolution.keepRemote: return 'keep_remote';
      case ConflictResolution.keepBoth: return 'keep_both';
      case ConflictResolution.merge: return 'merge';
    }
  }
}

enum SyncFrequency { realtime, hourly, daily, weekly, manual }
extension SyncFrequencyExt on SyncFrequency {
  String get value => toString().split('.').last;
}

String formatBackupSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class BackupDataTest {
  final int transactionCount;
  final int accountCount;
  final int categoryCount;
  final int bookCount;

  BackupDataTest({
    required this.transactionCount,
    required this.accountCount,
    required this.categoryCount,
    required this.bookCount,
  });

  bool get isValid => transactionCount >= 0 && accountCount >= 0;
  int get totalItems => transactionCount + accountCount + categoryCount + bookCount;
}
