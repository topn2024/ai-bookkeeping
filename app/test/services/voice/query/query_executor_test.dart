import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/query/query_executor.dart';
import 'package:ai_bookkeeping/services/voice/query/query_models.dart';
import 'package:ai_bookkeeping/models/transaction.dart';
import 'package:ai_bookkeeping/core/contracts/i_database_service.dart';

/// Mock数据库服务
class MockDatabaseService extends IDatabaseService {
  final List<Transaction> mockTransactions;

  MockDatabaseService(this.mockTransactions);

  @override
  Future<List<Transaction>> queryTransactions({
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
    var filtered = mockTransactions;

    if (startDate != null) {
      filtered = filtered.where((t) => !t.date.isBefore(startDate)).toList();
    }

    if (endDate != null) {
      filtered = filtered.where((t) => t.date.isBefore(endDate)).toList();
    }

    if (category != null) {
      filtered = filtered.where((t) => t.category == category).toList();
    }

    return filtered.take(limit).toList();
  }

  @override
  Future<Transaction> addTransaction(Transaction transaction) async {
    throw UnimplementedError();
  }

  @override
  Future<int> deleteTransaction(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<int> updateTransaction(Transaction transaction) async {
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late QueryExecutor executor;
  late List<Transaction> mockTransactions;

  setUp(() {
    // 创建模拟数据
    mockTransactions = [
      Transaction(
        id: '1',
        type: TransactionType.expense,
        amount: 100.0,
        category: '餐饮',
        date: DateTime(2024, 1, 1),
        accountId: 'default',
      ),
      Transaction(
        id: '2',
        type: TransactionType.expense,
        amount: 200.0,
        category: '交通',
        date: DateTime(2024, 1, 2),
        accountId: 'default',
      ),
      Transaction(
        id: '3',
        type: TransactionType.expense,
        amount: 300.0,
        category: '餐饮',
        date: DateTime(2024, 1, 3),
        accountId: 'default',
      ),
      Transaction(
        id: '4',
        type: TransactionType.income,
        amount: 5000.0,
        category: '工资',
        date: DateTime(2024, 1, 5),
        accountId: 'default',
      ),
      Transaction(
        id: '5',
        type: TransactionType.expense,
        amount: 150.0,
        category: '购物',
        date: DateTime(2024, 1, 10),
        accountId: 'default',
      ),
    ];

    final mockDb = MockDatabaseService(mockTransactions);
    executor = QueryExecutor(databaseService: mockDb);
  });

  group('QueryExecutor - 总额统计查询', () {
    test('应正确计算总支出和总收入', () async {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '1月',
        ),
      );

      final result = await executor.execute(request);

      expect(result.totalExpense, equals(750.0)); // 100+200+300+150
      expect(result.totalIncome, equals(5000.0));
      expect(result.transactionCount, equals(5));
      expect(result.periodText, equals('1月'));
    });

    test('应正确处理无交易的情况', () async {
      final mockDb = MockDatabaseService([]);
      final emptyExecutor = QueryExecutor(databaseService: mockDb);

      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 2, 1),
          endDate: DateTime(2024, 2, 28),
          periodText: '2月',
        ),
      );

      final result = await emptyExecutor.execute(request);

      expect(result.totalExpense, equals(0.0));
      expect(result.totalIncome, equals(0.0));
      expect(result.transactionCount, equals(0));
    });
  });

  group('QueryExecutor - 分布查询', () {
    test('应正确按分类分组统计', () async {
      final request = QueryRequest(
        queryType: QueryType.distribution,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '1月',
        ),
      );

      final result = await executor.execute(request);

      expect(result.groupedData, isNotNull);
      expect(result.groupedData!['餐饮'], equals(400.0)); // 100+300
      expect(result.groupedData!['交通'], equals(200.0));
      expect(result.groupedData!['购物'], equals(150.0));
      expect(result.totalExpense, equals(750.0));
    });
  });

  group('QueryExecutor - 趋势查询', () {
    test('应正确按月份分组', () async {
      final request = QueryRequest(
        queryType: QueryType.trend,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '1月',
        ),
        groupBy: [GroupByDimension.month],
      );

      final result = await executor.execute(request);

      expect(result.detailedData, isNotNull);
      expect(result.detailedData!.length, equals(1));
      expect(result.detailedData!.first.label, equals('1月'));
      expect(result.detailedData!.first.value, equals(750.0));
    });

    test('应正确按分类分组并排序', () async {
      final request = QueryRequest(
        queryType: QueryType.trend,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '1月',
        ),
        groupBy: [GroupByDimension.category],
      );

      final result = await executor.execute(request);

      expect(result.detailedData, isNotNull);
      expect(result.detailedData!.length, equals(3));
      // 应按金额降序排序
      expect(result.detailedData!.first.label, equals('餐饮'));
      expect(result.detailedData!.first.value, equals(400.0));
    });
  });

  group('QueryExecutor - 最近记录查询', () {
    test('应返回最近的记录', () async {
      final request = QueryRequest(
        queryType: QueryType.recent,
        limit: 3,
      );

      final result = await executor.execute(request);

      expect(result.transactionCount, equals(3));
      // 最近3笔：购物150 + 工资5000 + 餐饮300
      expect(result.totalExpense, equals(450.0)); // 150+300
      expect(result.totalIncome, equals(5000.0));
    });
  });

  group('QueryExecutor - 分类筛选', () {
    test('应正确筛选指定分类', () async {
      final request = QueryRequest(
        queryType: QueryType.summary,
        category: '餐饮',
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '1月',
        ),
      );

      final result = await executor.execute(request);

      expect(result.totalExpense, equals(400.0)); // 100+300
      expect(result.transactionCount, equals(2));
    });
  });
}
