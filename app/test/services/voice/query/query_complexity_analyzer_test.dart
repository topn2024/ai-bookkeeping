import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/query/query_complexity_analyzer.dart';
import 'package:ai_bookkeeping/services/voice/query/query_models.dart';

void main() {
  late QueryComplexityAnalyzer analyzer;

  setUp(() {
    analyzer = QueryComplexityAnalyzer();
  });

  group('QueryComplexityAnalyzer - 时间跨度评分', () {
    test('单日查询应得0分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 1),
          periodText: '今天',
        ),
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, lessThanOrEqualTo(1)); // 时间0分 + 其他最多1分
    });

    test('一周内查询应得1分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 7),
          periodText: '本周',
        ),
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, greaterThanOrEqualTo(1));
    });

    test('一月内查询应得2分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, greaterThanOrEqualTo(2));
    });

    test('三月内查询应得3分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 3, 31),
          periodText: '最近三个月',
        ),
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, greaterThanOrEqualTo(3));
    });

    test('三月以上查询应得4分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 12, 31),
          periodText: '今年',
        ),
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, greaterThanOrEqualTo(4));
    });
  });

  group('QueryComplexityAnalyzer - 数据维度评分', () {
    test('无维度应得0分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, equals(0)); // 无时间、无维度、summary类型0分
    });

    test('单个维度应得0分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        category: '餐饮',
      );

      final score = analyzer.calculateComplexity(request);
      // 维度0分 + summary类型0分 = 0分
      expect(score, lessThanOrEqualTo(1));
    });

    test('两个维度应得1分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        category: '餐饮',
        source: '微信',
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, greaterThanOrEqualTo(1));
    });

    test('三个及以上维度应得3分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        category: '餐饮',
        source: '微信',
        account: '招商银行',
        groupBy: [GroupByDimension.date],
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, greaterThanOrEqualTo(3));
    });
  });

  group('QueryComplexityAnalyzer - 查询类型评分', () {
    test('summary类型应得0分', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, equals(0));
    });

    test('recent类型应得0分', () {
      final request = QueryRequest(
        queryType: QueryType.recent,
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, equals(0));
    });

    test('comparison类型应得1分', () {
      final request = QueryRequest(
        queryType: QueryType.comparison,
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, equals(1));
    });

    test('distribution类型应得2分', () {
      final request = QueryRequest(
        queryType: QueryType.distribution,
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, equals(2));
    });

    test('trend类型应得2分', () {
      final request = QueryRequest(
        queryType: QueryType.trend,
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, equals(2));
    });

    test('custom类型应得3分', () {
      final request = QueryRequest(
        queryType: QueryType.custom,
      );

      final score = analyzer.calculateComplexity(request);
      expect(score, equals(3));
    });
  });

  group('QueryComplexityAnalyzer - 层级判定', () {
    test('评分0-1应判定为Level 1', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 1),
          periodText: '今天',
        ),
      );

      final score = analyzer.calculateComplexity(request);
      final level = analyzer.determineLevel(score);
      expect(level, equals(QueryLevel.simple));
    });

    test('评分2-4应判定为Level 2', () {
      final request = QueryRequest(
        queryType: QueryType.distribution,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
      );

      final score = analyzer.calculateComplexity(request);
      final level = analyzer.determineLevel(score);
      expect(level, equals(QueryLevel.medium));
    });

    test('评分5分及以上应判定为Level 3', () {
      final request = QueryRequest(
        queryType: QueryType.trend,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 12, 31),
          periodText: '今年',
        ),
        groupBy: [GroupByDimension.month],
      );

      final score = analyzer.calculateComplexity(request);
      final level = analyzer.determineLevel(score);
      expect(level, equals(QueryLevel.complex));
    });
  });

  group('QueryComplexityAnalyzer - 综合场景测试', () {
    test('简单查询：今天花了多少', () {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime.now(),
          endDate: DateTime.now(),
          periodText: '今天',
        ),
      );

      final score = analyzer.calculateComplexity(request);
      final level = analyzer.determineLevel(score);

      expect(score, lessThanOrEqualTo(1));
      expect(level, equals(QueryLevel.simple));
    });

    test('中等查询：餐饮这个月花了多少', () {
      final request = QueryRequest(
        queryType: QueryType.distribution,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
        category: '餐饮',
      );

      final score = analyzer.calculateComplexity(request);
      final level = analyzer.determineLevel(score);

      expect(score, greaterThanOrEqualTo(2));
      expect(score, lessThanOrEqualTo(4));
      expect(level, equals(QueryLevel.medium));
    });

    test('复杂查询：最近三个月的消费趋势', () {
      final request = QueryRequest(
        queryType: QueryType.trend,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 3, 31),
          periodText: '最近三个月',
        ),
        groupBy: [GroupByDimension.month],
      );

      final score = analyzer.calculateComplexity(request);
      final level = analyzer.determineLevel(score);

      expect(score, greaterThanOrEqualTo(5));
      expect(level, equals(QueryLevel.complex));
    });

    test('复杂查询：本年度每月支出对比', () {
      final request = QueryRequest(
        queryType: QueryType.comparison,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 12, 31),
          periodText: '今年',
        ),
        groupBy: [GroupByDimension.month],
      );

      final score = analyzer.calculateComplexity(request);
      final level = analyzer.determineLevel(score);

      expect(score, greaterThanOrEqualTo(5));
      expect(level, equals(QueryLevel.complex));
    });
  });
}

