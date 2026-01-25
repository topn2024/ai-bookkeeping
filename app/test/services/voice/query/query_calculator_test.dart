/// QueryCalculator 单元测试
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/query/query_calculator.dart';
import 'package:ai_bookkeeping/services/voice/query/query_calculator_strategies.dart';
import 'package:ai_bookkeeping/services/voice/query/query_models.dart';
import 'package:ai_bookkeeping/services/database_service.dart';
import 'package:ai_bookkeeping/models/transaction.dart' as model;

void main() {
  group('QueryCalculator', () {
    late QueryCalculator calculator;
    late DatabaseService database;

    setUp(() {
      database = DatabaseService();
      calculator = QueryCalculator(database);
    });

    test('应该正确验证时间范围', () async {
      // 创建超过1年的时间范围
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2024, 1, 1),
          periodText: '4年',
        ),
      );

      // 应该抛出异常
      expect(
        () => calculator.calculate(request),
        throwsA(isA<QueryException>()),
      );
    });

    test('应该正确生成缓存键', () {
      final request1 = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
        category: '餐饮',
      );

      final request2 = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
        category: '餐饮',
      );

      // 相同的请求应该生成相同的缓存键
      // 这里我们通过两次调用来验证缓存是否工作
      // 实际测试需要mock数据库
    });

    // 注意：_parseTransactionType 是私有方法，无法直接测试
    // 可以通过集成测试来验证其功能
  });

  group('SummaryCalculator', () {
    test('应该正确计算分类支出', () {
      final transactions = [
        model.Transaction(
          id: '1',
          type: model.TransactionType.expense,
          amount: 100.0,
          category: '餐饮',
          date: DateTime(2024, 1, 1),
          accountId: 'acc1',
        ),
        model.Transaction(
          id: '2',
          type: model.TransactionType.expense,
          amount: 200.0,
          category: '餐饮',
          date: DateTime(2024, 1, 2),
          accountId: 'acc1',
        ),
        model.Transaction(
          id: '3',
          type: model.TransactionType.expense,
          amount: 150.0,
          category: '交通',
          date: DateTime(2024, 1, 3),
          accountId: 'acc1',
        ),
      ];

      final request = QueryRequest(
        queryType: QueryType.summary,
        category: '餐饮',
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
      );

      final calculator = SummaryCalculator();
      final result = calculator.calculate(transactions, request);

      expect(result.totalExpense, equals(450.0));
      expect(result.transactionCount, equals(3));
      expect(result.groupedData?['餐饮'], equals(300.0));
      expect(result.groupedData?['其他'], equals(150.0));
    });
  });

  group('TrendCalculator', () {
    test('应该正确生成趋势数据', () {
      final transactions = [
        model.Transaction(
          id: '1',
          type: model.TransactionType.expense,
          amount: 100.0,
          category: '餐饮',
          date: DateTime(2024, 1, 1),
          accountId: 'acc1',
        ),
        model.Transaction(
          id: '2',
          type: model.TransactionType.expense,
          amount: 200.0,
          category: '餐饮',
          date: DateTime(2024, 1, 1),
          accountId: 'acc1',
        ),
        model.Transaction(
          id: '3',
          type: model.TransactionType.expense,
          amount: 150.0,
          category: '交通',
          date: DateTime(2024, 1, 2),
          accountId: 'acc1',
        ),
      ];

      final request = QueryRequest(
        queryType: QueryType.trend,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
      );

      final calculator = TrendCalculator();
      final result = calculator.calculate(transactions, request);

      expect(result.totalExpense, equals(450.0));
      expect(result.detailedData?.length, equals(2)); // 2天的数据
      expect(result.detailedData?[0].value, equals(300.0)); // 1月1日
      expect(result.detailedData?[1].value, equals(150.0)); // 1月2日
    });
  });

  group('DistributionCalculator', () {
    test('应该正确计算分类分布', () {
      final transactions = [
        model.Transaction(
          id: '1',
          type: model.TransactionType.expense,
          amount: 300.0,
          category: '餐饮',
          date: DateTime(2024, 1, 1),
          accountId: 'acc1',
        ),
        model.Transaction(
          id: '2',
          type: model.TransactionType.expense,
          amount: 150.0,
          category: '交通',
          date: DateTime(2024, 1, 2),
          accountId: 'acc1',
        ),
        model.Transaction(
          id: '3',
          type: model.TransactionType.expense,
          amount: 100.0,
          category: '购物',
          date: DateTime(2024, 1, 3),
          accountId: 'acc1',
        ),
      ];

      final request = QueryRequest(
        queryType: QueryType.distribution,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
      );

      final calculator = DistributionCalculator();
      final result = calculator.calculate(transactions, request);

      expect(result.totalExpense, equals(550.0));
      expect(result.detailedData?.length, equals(3));
      expect(result.detailedData?[0].label, equals('餐饮')); // 最大的分类
      expect(result.detailedData?[0].value, equals(300.0));
      expect(result.groupedData?['餐饮'], equals(300.0));
      expect(result.groupedData?['交通'], equals(150.0));
      expect(result.groupedData?['购物'], equals(100.0));
    });
  });
}
