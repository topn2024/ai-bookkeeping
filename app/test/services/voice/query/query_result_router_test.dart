import 'package:flutter_test/flutter_test.dart';
import 'package:ai_bookkeeping/services/voice/query/query_result_router.dart';
import 'package:ai_bookkeeping/services/voice/query/query_models.dart';
import 'package:ai_bookkeeping/services/voice/query/query_complexity_analyzer.dart';

void main() {
  late QueryResultRouter router;

  setUp(() {
    router = QueryResultRouter();
  });

  group('QueryResultRouter - Level 1 纯语音响应', () {
    test('简单总额查询应返回Level 1响应', () async {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 1),
          periodText: '今天',
        ),
      );

      final result = QueryResult(
        totalExpense: 350.0,
        totalIncome: 0.0,
        transactionCount: 3,
        periodText: '今天',
      );

      final response = await router.route(request, result);

      expect(response.level, equals(QueryLevel.simple));
      expect(response.voiceText, contains('今天'));
      expect(response.voiceText, contains('350'));
      expect(response.cardData, isNull);
      expect(response.chartData, isNull);
    });

    test('无支出无收入应返回提示文本', () async {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 1),
          periodText: '今天',
        ),
      );

      final result = QueryResult(
        totalExpense: 0.0,
        totalIncome: 0.0,
        transactionCount: 0,
        periodText: '今天',
      );

      final response = await router.route(request, result);

      expect(response.voiceText, contains('暂无记账记录'));
    });

    test('同时有收入和支出应都播报', () async {
      final request = QueryRequest(
        queryType: QueryType.summary,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
      );

      final result = QueryResult(
        totalExpense: 8400.0,
        totalIncome: 12000.0,
        transactionCount: 25,
        periodText: '本月',
      );

      final response = await router.route(request, result);

      expect(response.voiceText, contains('花费'));
      expect(response.voiceText, contains('8400'));
      expect(response.voiceText, contains('收入'));
      expect(response.voiceText, contains('12000'));
    });
  });

  group('QueryResultRouter - Level 2 语音+卡片', () {
    test('分布查询应返回Level 2响应和卡片数据', () async {
      final request = QueryRequest(
        queryType: QueryType.distribution,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
        category: '餐饮',
      );

      final result = QueryResult(
        totalExpense: 2180.0,
        totalIncome: 0.0,
        transactionCount: 15,
        periodText: '本月',
        groupedData: {
          '餐饮': 2180.0,
          '交通': 800.0,
          '购物': 1500.0,
        },
      );

      final response = await router.route(request, result);

      expect(response.level, equals(QueryLevel.medium));
      expect(response.voiceText, isNotEmpty);
      expect(response.cardData, isNotNull);
      expect(response.cardData!.cardType, equals(CardType.percentage));
      expect(response.chartData, isNull);
    });
  });

  group('QueryResultRouter - Level 3 语音+图表', () {
    test('趋势查询应返回Level 3响应和图表数据', () async {
      final request = QueryRequest(
        queryType: QueryType.trend,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 3, 31),
          periodText: '最近三个月',
        ),
        groupBy: [GroupByDimension.month],
      );

      final result = QueryResult(
        totalExpense: 25000.0,
        totalIncome: 0.0,
        transactionCount: 80,
        periodText: '最近三个月',
        detailedData: [
          DataPoint(label: '1月', value: 8000.0),
          DataPoint(label: '2月', value: 9500.0),
          DataPoint(label: '3月', value: 7500.0),
        ],
      );

      final response = await router.route(request, result);

      expect(response.level, equals(QueryLevel.complex));
      expect(response.voiceText, isNotEmpty);
      expect(response.cardData, isNull);
      expect(response.chartData, isNotNull);
      expect(response.chartData!.chartType, equals(ChartType.line));
      expect(response.chartData!.dataPoints.length, equals(3));
    });

    test('分布查询（复杂）应返回饼图', () async {
      final request = QueryRequest(
        queryType: QueryType.distribution,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 3, 31),
          periodText: '最近三个月',
        ),
        groupBy: [GroupByDimension.category],
      );

      final result = QueryResult(
        totalExpense: 25000.0,
        totalIncome: 0.0,
        transactionCount: 80,
        periodText: '最近三个月',
        groupedData: {
          '餐饮': 8000.0,
          '交通': 3000.0,
          '购物': 10000.0,
          '娱乐': 4000.0,
        },
      );

      final response = await router.route(request, result);

      expect(response.level, equals(QueryLevel.complex));
      expect(response.chartData, isNotNull);
      expect(response.chartData!.chartType, equals(ChartType.pie));
    });

    test('对比查询应返回柱状图', () async {
      final request = QueryRequest(
        queryType: QueryType.comparison,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 12, 31),
          periodText: '今年',
        ),
        groupBy: [GroupByDimension.month],
      );

      final result = QueryResult(
        totalExpense: 100000.0,
        totalIncome: 0.0,
        transactionCount: 300,
        periodText: '今年',
        detailedData: List.generate(
          12,
          (i) => DataPoint(label: '${i + 1}月', value: 8000.0 + i * 500),
        ),
      );

      final response = await router.route(request, result);

      expect(response.level, equals(QueryLevel.complex));
      expect(response.chartData, isNotNull);
      expect(response.chartData!.chartType, equals(ChartType.bar));
    });
  });

  group('QueryResultRouter - 语音文本生成', () {
    test('趋势文本应包含最高和最低点', () async {
      final request = QueryRequest(
        queryType: QueryType.trend,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 3, 31),
          periodText: '最近三个月',
        ),
      );

      final result = QueryResult(
        totalExpense: 25000.0,
        totalIncome: 0.0,
        transactionCount: 80,
        periodText: '最近三个月',
        detailedData: [
          DataPoint(label: '1月', value: 8000.0),
          DataPoint(label: '2月', value: 9500.0),
          DataPoint(label: '3月', value: 7500.0),
        ],
      );

      final response = await router.route(request, result);

      expect(response.voiceText, contains('最高'));
      expect(response.voiceText, contains('最低'));
      expect(response.voiceText, contains('9500'));
      expect(response.voiceText, contains('7500'));
    });

    test('分布文本应包含占比最大的分类', () async {
      final request = QueryRequest(
        queryType: QueryType.distribution,
        timeRange: TimeRange(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
          periodText: '本月',
        ),
      );

      final result = QueryResult(
        totalExpense: 15000.0,
        totalIncome: 0.0,
        transactionCount: 50,
        periodText: '本月',
        groupedData: {
          '餐饮': 3000.0,
          '交通': 2000.0,
          '购物': 10000.0,
        },
      );

      final response = await router.route(request, result);

      expect(response.voiceText, contains('购物'));
      expect(response.voiceText, contains('最多'));
    });
  });
}

