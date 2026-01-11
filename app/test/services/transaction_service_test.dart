import 'package:flutter_test/flutter_test.dart';

/// 交易服务单元测试
///
/// 对应实施方案：轨道L 测试与质量保障模块

// ==================== Mock 交易模型 ====================

/// 交易类型
enum TransactionType { income, expense, transfer }

/// 交易模型
class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String categoryId;
  final String accountId;
  final String? targetAccountId; // 转账目标账户
  final String description;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final Map<String, dynamic>? metadata;
  final bool isRecurring;
  final String? recurringId;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.targetAccountId,
    required this.description,
    required this.date,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.tags = const [],
    this.metadata,
    this.isRecurring = false,
    this.recurringId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? categoryId,
    String? accountId,
    String? targetAccountId,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    bool? isRecurring,
    String? recurringId,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringId: recurringId ?? this.recurringId,
    );
  }
}

/// 交易过滤器
class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final TransactionType? type;
  final String? categoryId;
  final String? accountId;
  final double? minAmount;
  final double? maxAmount;
  final List<String>? tags;
  final String? searchText;

  TransactionFilter({
    this.startDate,
    this.endDate,
    this.type,
    this.categoryId,
    this.accountId,
    this.minAmount,
    this.maxAmount,
    this.tags,
    this.searchText,
  });
}

/// 交易统计
class TransactionStats {
  final double totalIncome;
  final double totalExpense;
  final double netAmount;
  final int transactionCount;
  final Map<String, double> categoryBreakdown;
  final double averageExpense;

  TransactionStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.netAmount,
    required this.transactionCount,
    required this.categoryBreakdown,
    required this.averageExpense,
  });
}

// ==================== 交易服务 ====================

/// 交易服务
class TransactionService {
  final Map<String, Transaction> _transactions = {};
  final Map<String, double> _accountBalances = {};

  /// 创建交易
  Transaction createTransaction({
    required TransactionType type,
    required double amount,
    required String categoryId,
    required String accountId,
    String? targetAccountId,
    required String description,
    DateTime? date,
    List<String> tags = const [],
    Map<String, dynamic>? metadata,
  }) {
    if (amount <= 0) {
      throw ArgumentError('金额必须大于0');
    }

    if (type == TransactionType.transfer && targetAccountId == null) {
      throw ArgumentError('转账必须指定目标账户');
    }

    if (type == TransactionType.transfer && targetAccountId == accountId) {
      throw ArgumentError('转账的源账户和目标账户不能相同');
    }

    final id = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    final transaction = Transaction(
      id: id,
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      targetAccountId: targetAccountId,
      description: description,
      date: date ?? DateTime.now(),
      tags: tags,
      metadata: metadata,
    );

    _transactions[id] = transaction;
    _updateAccountBalance(transaction);

    return transaction;
  }

  /// 更新账户余额
  void _updateAccountBalance(Transaction transaction) {
    final accountId = transaction.accountId;
    _accountBalances.putIfAbsent(accountId, () => 0);

    switch (transaction.type) {
      case TransactionType.income:
        _accountBalances[accountId] = _accountBalances[accountId]! + transaction.amount;
        break;
      case TransactionType.expense:
        _accountBalances[accountId] = _accountBalances[accountId]! - transaction.amount;
        break;
      case TransactionType.transfer:
        _accountBalances[accountId] = _accountBalances[accountId]! - transaction.amount;
        final targetId = transaction.targetAccountId!;
        _accountBalances.putIfAbsent(targetId, () => 0);
        _accountBalances[targetId] = _accountBalances[targetId]! + transaction.amount;
        break;
    }
  }

  /// 获取交易
  Transaction? getTransaction(String id) => _transactions[id];

  /// 更新交易
  Transaction updateTransaction(String id, {
    double? amount,
    String? categoryId,
    String? description,
    DateTime? date,
    List<String>? tags,
  }) {
    final transaction = _transactions[id];
    if (transaction == null) {
      throw StateError('交易不存在: $id');
    }

    // 如果金额变化，需要调整账户余额
    if (amount != null && amount != transaction.amount) {
      // 撤销原交易
      _reverseAccountBalance(transaction);
    }

    final updated = transaction.copyWith(
      amount: amount,
      categoryId: categoryId,
      description: description,
      date: date,
      tags: tags,
      updatedAt: DateTime.now(),
    );

    _transactions[id] = updated;

    // 如果金额变化，应用新交易
    if (amount != null && amount != transaction.amount) {
      _updateAccountBalance(updated);
    }

    return updated;
  }

  /// 撤销账户余额变化
  void _reverseAccountBalance(Transaction transaction) {
    final accountId = transaction.accountId;

    switch (transaction.type) {
      case TransactionType.income:
        _accountBalances[accountId] = _accountBalances[accountId]! - transaction.amount;
        break;
      case TransactionType.expense:
        _accountBalances[accountId] = _accountBalances[accountId]! + transaction.amount;
        break;
      case TransactionType.transfer:
        _accountBalances[accountId] = _accountBalances[accountId]! + transaction.amount;
        final targetId = transaction.targetAccountId!;
        _accountBalances[targetId] = _accountBalances[targetId]! - transaction.amount;
        break;
    }
  }

  /// 删除交易
  void deleteTransaction(String id) {
    final transaction = _transactions[id];
    if (transaction != null) {
      _reverseAccountBalance(transaction);
      _transactions.remove(id);
    }
  }

  /// 获取所有交易
  List<Transaction> getAllTransactions() {
    return _transactions.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 过滤交易
  List<Transaction> filterTransactions(TransactionFilter filter) {
    return _transactions.values.where((tx) {
      if (filter.startDate != null && tx.date.isBefore(filter.startDate!)) {
        return false;
      }
      if (filter.endDate != null && tx.date.isAfter(filter.endDate!)) {
        return false;
      }
      if (filter.type != null && tx.type != filter.type) {
        return false;
      }
      if (filter.categoryId != null && tx.categoryId != filter.categoryId) {
        return false;
      }
      if (filter.accountId != null && tx.accountId != filter.accountId) {
        return false;
      }
      if (filter.minAmount != null && tx.amount < filter.minAmount!) {
        return false;
      }
      if (filter.maxAmount != null && tx.amount > filter.maxAmount!) {
        return false;
      }
      if (filter.tags != null && filter.tags!.isNotEmpty) {
        if (!filter.tags!.any((tag) => tx.tags.contains(tag))) {
          return false;
        }
      }
      if (filter.searchText != null && filter.searchText!.isNotEmpty) {
        if (!tx.description.toLowerCase().contains(filter.searchText!.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// 获取日期范围内的交易
  List<Transaction> getTransactionsByDateRange(DateTime start, DateTime end) {
    return filterTransactions(TransactionFilter(
      startDate: start,
      endDate: end,
    ));
  }

  /// 获取分类交易
  List<Transaction> getTransactionsByCategory(String categoryId) {
    return filterTransactions(TransactionFilter(categoryId: categoryId));
  }

  /// 计算统计
  TransactionStats calculateStats({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final transactions = filterTransactions(TransactionFilter(
      startDate: startDate,
      endDate: endDate,
    ));

    double totalIncome = 0;
    double totalExpense = 0;
    final Map<String, double> categoryBreakdown = {};
    int expenseCount = 0;

    for (final tx in transactions) {
      switch (tx.type) {
        case TransactionType.income:
          totalIncome += tx.amount;
          break;
        case TransactionType.expense:
          totalExpense += tx.amount;
          expenseCount++;
          categoryBreakdown[tx.categoryId] =
              (categoryBreakdown[tx.categoryId] ?? 0) + tx.amount;
          break;
        case TransactionType.transfer:
          // 转账不计入收支统计
          break;
      }
    }

    return TransactionStats(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netAmount: totalIncome - totalExpense,
      transactionCount: transactions.length,
      categoryBreakdown: categoryBreakdown,
      averageExpense: expenseCount > 0 ? totalExpense / expenseCount : 0,
    );
  }

  /// 获取账户余额
  double getAccountBalance(String accountId) {
    return _accountBalances[accountId] ?? 0;
  }

  /// 重置（测试用）
  void reset() {
    _transactions.clear();
    _accountBalances.clear();
  }
}

// ==================== 测试用例 ====================

void main() {
  late TransactionService transactionService;

  setUp(() {
    transactionService = TransactionService();
  });

  tearDown(() {
    transactionService.reset();
  });

  group('交易创建测试', () {
    test('创建支出交易', () {
      final transaction = transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 100,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '午餐',
      );

      expect(transaction.type, TransactionType.expense);
      expect(transaction.amount, 100);
      expect(transaction.categoryId, 'cat_food');
      expect(transaction.accountId, 'acc_cash');
      expect(transaction.description, '午餐');
    });

    test('创建收入交易', () {
      final transaction = transactionService.createTransaction(
        type: TransactionType.income,
        amount: 5000,
        categoryId: 'cat_salary',
        accountId: 'acc_bank',
        description: '工资',
      );

      expect(transaction.type, TransactionType.income);
      expect(transaction.amount, 5000);
    });

    test('创建转账交易', () {
      final transaction = transactionService.createTransaction(
        type: TransactionType.transfer,
        amount: 1000,
        categoryId: 'cat_transfer',
        accountId: 'acc_bank',
        targetAccountId: 'acc_cash',
        description: '取现',
      );

      expect(transaction.type, TransactionType.transfer);
      expect(transaction.targetAccountId, 'acc_cash');
    });

    test('创建带标签的交易', () {
      final transaction = transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 500,
        categoryId: 'cat_shopping',
        accountId: 'acc_credit',
        description: '买衣服',
        tags: ['必需品', '冬季'],
      );

      expect(transaction.tags, contains('必需品'));
      expect(transaction.tags, contains('冬季'));
    });

    test('金额为0抛出异常', () {
      expect(
        () => transactionService.createTransaction(
          type: TransactionType.expense,
          amount: 0,
          categoryId: 'cat_food',
          accountId: 'acc_cash',
          description: '测试',
        ),
        throwsArgumentError,
      );
    });

    test('负数金额抛出异常', () {
      expect(
        () => transactionService.createTransaction(
          type: TransactionType.expense,
          amount: -100,
          categoryId: 'cat_food',
          accountId: 'acc_cash',
          description: '测试',
        ),
        throwsArgumentError,
      );
    });

    test('转账未指定目标账户抛出异常', () {
      expect(
        () => transactionService.createTransaction(
          type: TransactionType.transfer,
          amount: 1000,
          categoryId: 'cat_transfer',
          accountId: 'acc_bank',
          description: '转账',
        ),
        throwsArgumentError,
      );
    });

    test('转账源和目标相同抛出异常', () {
      expect(
        () => transactionService.createTransaction(
          type: TransactionType.transfer,
          amount: 1000,
          categoryId: 'cat_transfer',
          accountId: 'acc_bank',
          targetAccountId: 'acc_bank',
          description: '转账',
        ),
        throwsArgumentError,
      );
    });
  });

  group('账户余额测试', () {
    test('支出减少账户余额', () {
      transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 100,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '午餐',
      );

      expect(transactionService.getAccountBalance('acc_cash'), -100);
    });

    test('收入增加账户余额', () {
      transactionService.createTransaction(
        type: TransactionType.income,
        amount: 5000,
        categoryId: 'cat_salary',
        accountId: 'acc_bank',
        description: '工资',
      );

      expect(transactionService.getAccountBalance('acc_bank'), 5000);
    });

    test('转账同时影响两个账户', () {
      transactionService.createTransaction(
        type: TransactionType.transfer,
        amount: 1000,
        categoryId: 'cat_transfer',
        accountId: 'acc_bank',
        targetAccountId: 'acc_cash',
        description: '取现',
      );

      expect(transactionService.getAccountBalance('acc_bank'), -1000);
      expect(transactionService.getAccountBalance('acc_cash'), 1000);
    });

    test('多笔交易累计余额', () {
      transactionService.createTransaction(
        type: TransactionType.income,
        amount: 5000,
        categoryId: 'cat_salary',
        accountId: 'acc_bank',
        description: '工资',
      );
      transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 1000,
        categoryId: 'cat_rent',
        accountId: 'acc_bank',
        description: '房租',
      );
      transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 500,
        categoryId: 'cat_food',
        accountId: 'acc_bank',
        description: '餐饮',
      );

      expect(transactionService.getAccountBalance('acc_bank'), 3500);
    });
  });

  group('交易更新测试', () {
    test('更新交易金额', () {
      final transaction = transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 100,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '午餐',
      );

      final updated = transactionService.updateTransaction(
        transaction.id,
        amount: 150,
      );

      expect(updated.amount, 150);
      expect(transactionService.getAccountBalance('acc_cash'), -150);
    });

    test('更新交易描述', () {
      final transaction = transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 100,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '午餐',
      );

      final updated = transactionService.updateTransaction(
        transaction.id,
        description: '晚餐',
      );

      expect(updated.description, '晚餐');
    });

    test('更新不存在的交易抛出异常', () {
      expect(
        () => transactionService.updateTransaction(
          'nonexistent',
          amount: 100,
        ),
        throwsStateError,
      );
    });
  });

  group('交易删除测试', () {
    test('删除交易恢复账户余额', () {
      final transaction = transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 100,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '午餐',
      );

      expect(transactionService.getAccountBalance('acc_cash'), -100);

      transactionService.deleteTransaction(transaction.id);

      expect(transactionService.getTransaction(transaction.id), isNull);
      expect(transactionService.getAccountBalance('acc_cash'), 0);
    });

    test('删除转账交易恢复双方账户', () {
      final transaction = transactionService.createTransaction(
        type: TransactionType.transfer,
        amount: 1000,
        categoryId: 'cat_transfer',
        accountId: 'acc_bank',
        targetAccountId: 'acc_cash',
        description: '取现',
      );

      transactionService.deleteTransaction(transaction.id);

      expect(transactionService.getAccountBalance('acc_bank'), 0);
      expect(transactionService.getAccountBalance('acc_cash'), 0);
    });
  });

  group('交易过滤测试', () {
    // ignore: unused_local_variable
    late List<Transaction> transactions;

    setUp(() {
      transactions = [
        transactionService.createTransaction(
          type: TransactionType.expense,
          amount: 100,
          categoryId: 'cat_food',
          accountId: 'acc_cash',
          description: '早餐',
          date: DateTime(2024, 1, 1),
        ),
        transactionService.createTransaction(
          type: TransactionType.expense,
          amount: 200,
          categoryId: 'cat_food',
          accountId: 'acc_cash',
          description: '午餐',
          date: DateTime(2024, 1, 2),
          tags: ['工作餐'],
        ),
        transactionService.createTransaction(
          type: TransactionType.income,
          amount: 5000,
          categoryId: 'cat_salary',
          accountId: 'acc_bank',
          description: '工资',
          date: DateTime(2024, 1, 10),
        ),
        transactionService.createTransaction(
          type: TransactionType.expense,
          amount: 500,
          categoryId: 'cat_transport',
          accountId: 'acc_bank',
          description: '加油',
          date: DateTime(2024, 1, 15),
        ),
      ];
    });

    test('按类型过滤', () {
      final expenses = transactionService.filterTransactions(
        TransactionFilter(type: TransactionType.expense),
      );

      expect(expenses.length, 3);
      expect(expenses.every((tx) => tx.type == TransactionType.expense), true);
    });

    test('按分类过滤', () {
      final foodExpenses = transactionService.filterTransactions(
        TransactionFilter(categoryId: 'cat_food'),
      );

      expect(foodExpenses.length, 2);
    });

    test('按日期范围过滤', () {
      final janFirst = transactionService.filterTransactions(
        TransactionFilter(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 5),
        ),
      );

      expect(janFirst.length, 2);
    });

    test('按金额范围过滤', () {
      final largeTransactions = transactionService.filterTransactions(
        TransactionFilter(minAmount: 500),
      );

      expect(largeTransactions.length, 2);
    });

    test('按标签过滤', () {
      final workMeals = transactionService.filterTransactions(
        TransactionFilter(tags: ['工作餐']),
      );

      expect(workMeals.length, 1);
      expect(workMeals.first.description, '午餐');
    });

    test('按搜索文本过滤', () {
      final breakfast = transactionService.filterTransactions(
        TransactionFilter(searchText: '早餐'),
      );

      expect(breakfast.length, 1);
    });

    test('组合条件过滤', () {
      final filtered = transactionService.filterTransactions(
        TransactionFilter(
          type: TransactionType.expense,
          categoryId: 'cat_food',
          maxAmount: 150,
        ),
      );

      expect(filtered.length, 1);
      expect(filtered.first.description, '早餐');
    });
  });

  group('统计计算测试', () {
    setUp(() {
      transactionService.createTransaction(
        type: TransactionType.income,
        amount: 10000,
        categoryId: 'cat_salary',
        accountId: 'acc_bank',
        description: '工资',
      );
      transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 2000,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '餐饮',
      );
      transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 3000,
        categoryId: 'cat_rent',
        accountId: 'acc_bank',
        description: '房租',
      );
      transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 1000,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '外卖',
      );
    });

    test('总收入计算', () {
      final stats = transactionService.calculateStats();
      expect(stats.totalIncome, 10000);
    });

    test('总支出计算', () {
      final stats = transactionService.calculateStats();
      expect(stats.totalExpense, 6000);
    });

    test('净额计算', () {
      final stats = transactionService.calculateStats();
      expect(stats.netAmount, 4000);
    });

    test('分类支出统计', () {
      final stats = transactionService.calculateStats();

      expect(stats.categoryBreakdown['cat_food'], 3000);
      expect(stats.categoryBreakdown['cat_rent'], 3000);
    });

    test('平均支出计算', () {
      final stats = transactionService.calculateStats();
      expect(stats.averageExpense, 2000); // 6000 / 3
    });

    test('交易数量统计', () {
      final stats = transactionService.calculateStats();
      expect(stats.transactionCount, 4);
    });
  });

  group('边界条件测试', () {
    test('空交易列表统计', () {
      final stats = transactionService.calculateStats();

      expect(stats.totalIncome, 0);
      expect(stats.totalExpense, 0);
      expect(stats.transactionCount, 0);
      expect(stats.averageExpense, 0);
    });

    test('获取不存在的账户余额', () {
      expect(transactionService.getAccountBalance('nonexistent'), 0);
    });

    test('按日期排序', () {
      transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 100,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '旧交易',
        date: DateTime(2024, 1, 1),
      );
      transactionService.createTransaction(
        type: TransactionType.expense,
        amount: 200,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        description: '新交易',
        date: DateTime(2024, 1, 10),
      );

      final all = transactionService.getAllTransactions();

      expect(all.first.description, '新交易');
      expect(all.last.description, '旧交易');
    });
  });
}
