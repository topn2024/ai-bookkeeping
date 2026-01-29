/// Query Command
///
/// 查询命令实现。
/// 用于查询交易统计、趋势分析、分布查询等。
library;

import '../repositories/i_transaction_repository.dart';
import 'intent_command.dart';

/// 查询类型
enum QueryType {
  /// 总额统计
  summary,

  /// 最近记录
  recent,

  /// 趋势分析
  trend,

  /// 分布查询
  distribution,

  /// 对比查询
  comparison,

  /// 搜索
  search,
}

/// 分组维度
enum GroupBy {
  /// 按月
  month,

  /// 按日
  date,

  /// 按分类
  category,

  /// 按账户
  account,

  /// 按来源
  source,
}

/// 交易类型筛选
enum TransactionTypeFilter {
  /// 全部
  all,

  /// 仅支出
  expense,

  /// 仅收入
  income,
}

/// 查询结果
class QueryResult {
  /// 查询类型
  final QueryType queryType;

  /// 总金额
  final double? totalAmount;

  /// 交易数量
  final int? count;

  /// 分组数据
  final Map<String, dynamic>? groupedData;

  /// 趋势数据
  final List<Map<String, dynamic>>? trendData;

  /// 交易列表
  final List<dynamic>? transactions;

  /// 对比数据
  final Map<String, dynamic>? comparisonData;

  /// 时间范围
  final String? timeRange;

  const QueryResult({
    required this.queryType,
    this.totalAmount,
    this.count,
    this.groupedData,
    this.trendData,
    this.transactions,
    this.comparisonData,
    this.timeRange,
  });

  Map<String, dynamic> toMap() => {
        'queryType': queryType.name,
        'totalAmount': totalAmount,
        'count': count,
        'groupedData': groupedData,
        'trendData': trendData,
        'transactions': transactions?.length,
        'comparisonData': comparisonData,
        'timeRange': timeRange,
      };
}

/// 查询命令
class QueryCommand extends IntentCommand {
  /// 交易仓储
  final ITransactionRepository transactionRepository;

  QueryCommand({
    required String id,
    required this.transactionRepository,
    required Map<String, dynamic> params,
    CommandContext? context,
  }) : super(
          id: id,
          type: CommandType.query,
          priority: CommandPriority.normal,
          params: params,
          context: context,
        );

  @override
  String get description {
    final queryType = this.queryType;
    final time = params['time'] ?? '本月';
    final category = params['category'];

    switch (queryType) {
      case QueryType.summary:
        return '查询$time${category != null ? category : ""}支出统计';
      case QueryType.recent:
        return '查询最近的交易记录';
      case QueryType.trend:
        return '查询$time消费趋势';
      case QueryType.distribution:
        return '查询$time${category != null ? category : "各分类"}支出分布';
      case QueryType.comparison:
        return '查询$time对比数据';
      case QueryType.search:
        return '搜索交易记录';
    }
  }

  /// 查询类型
  QueryType get queryType {
    final type = params['queryType'] as String?;
    switch (type) {
      case 'summary':
      case 'statistics':
        return QueryType.summary;
      case 'recent':
        return QueryType.recent;
      case 'trend':
        return QueryType.trend;
      case 'distribution':
        return QueryType.distribution;
      case 'comparison':
        return QueryType.comparison;
      case 'search':
        return QueryType.search;
      default:
        return QueryType.summary;
    }
  }

  /// 分组维度
  GroupBy? get groupBy {
    final group = params['groupBy'] as String?;
    switch (group) {
      case 'month':
        return GroupBy.month;
      case 'date':
        return GroupBy.date;
      case 'category':
        return GroupBy.category;
      case 'account':
        return GroupBy.account;
      case 'source':
        return GroupBy.source;
      default:
        return null;
    }
  }

  /// 交易类型筛选
  TransactionTypeFilter get transactionTypeFilter {
    final type = params['transactionType'] as String?;
    switch (type) {
      case 'expense':
        return TransactionTypeFilter.expense;
      case 'income':
        return TransactionTypeFilter.income;
      default:
        return TransactionTypeFilter.expense; // 默认查支出
    }
  }

  /// 时间范围
  String get timeRange => params['time'] as String? ?? '本月';

  /// 分类筛选
  String? get category => params['category'] as String?;

  /// 结果数量限制
  int? get limit => params['limit'] as int?;

  @override
  bool validate() {
    // 查询命令至少需要知道查询类型
    return params.containsKey('queryType') || params.containsKey('time');
  }

  @override
  Future<CommandResult> execute() async {
    final stopwatch = Stopwatch()..start();

    try {
      final dateRange = _parseTimeRange(timeRange);
      QueryResult queryResult;

      switch (queryType) {
        case QueryType.summary:
          queryResult = await _executeSummaryQuery(dateRange);
          break;

        case QueryType.recent:
          queryResult = await _executeRecentQuery();
          break;

        case QueryType.trend:
          queryResult = await _executeTrendQuery(dateRange);
          break;

        case QueryType.distribution:
          queryResult = await _executeDistributionQuery(dateRange);
          break;

        case QueryType.comparison:
          queryResult = await _executeComparisonQuery(dateRange);
          break;

        case QueryType.search:
          queryResult = await _executeSearchQuery();
          break;
      }

      stopwatch.stop();

      return CommandResult.success(
        data: {
          'result': queryResult.toMap(),
          'message': _generateResultMessage(queryResult),
        },
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return CommandResult.failure(
        '查询失败: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// 执行汇总查询
  Future<QueryResult> _executeSummaryQuery(DateRange dateRange) async {
    final total = await transactionRepository.getTotal(
      startDate: dateRange.start,
      endDate: dateRange.end,
      type: transactionTypeFilter == TransactionTypeFilter.income
          ? 'income'
          : 'expense',
      category: category,
    );

    final count = await transactionRepository.count(
      startDate: dateRange.start,
      endDate: dateRange.end,
      type: transactionTypeFilter == TransactionTypeFilter.income
          ? 'income'
          : 'expense',
      category: category,
    );

    return QueryResult(
      queryType: QueryType.summary,
      totalAmount: total,
      count: count,
      timeRange: timeRange,
    );
  }

  /// 执行最近记录查询
  Future<QueryResult> _executeRecentQuery() async {
    final queryLimit = limit ?? 10;
    final transactions = await transactionRepository.findRecent(queryLimit);

    return QueryResult(
      queryType: QueryType.recent,
      transactions: transactions,
      count: transactions.length,
    );
  }

  /// 执行趋势查询
  Future<QueryResult> _executeTrendQuery(DateRange dateRange) async {
    final group = groupBy ?? GroupBy.month;
    final trendData = await transactionRepository.getTrend(
      startDate: dateRange.start,
      endDate: dateRange.end,
      groupBy: group.name,
      type: transactionTypeFilter == TransactionTypeFilter.income
          ? 'income'
          : 'expense',
    );

    return QueryResult(
      queryType: QueryType.trend,
      trendData: trendData,
      timeRange: timeRange,
    );
  }

  /// 执行分布查询
  Future<QueryResult> _executeDistributionQuery(DateRange dateRange) async {
    final distributionData = await transactionRepository.getDistribution(
      startDate: dateRange.start,
      endDate: dateRange.end,
      groupBy: groupBy?.name ?? 'category',
      type: transactionTypeFilter == TransactionTypeFilter.income
          ? 'income'
          : 'expense',
      limit: limit,
    );

    double total = 0;
    for (final item in distributionData) {
      total += (item['amount'] as num?)?.toDouble() ?? 0;
    }

    return QueryResult(
      queryType: QueryType.distribution,
      groupedData: {'items': distributionData},
      totalAmount: total,
      timeRange: timeRange,
    );
  }

  /// 执行对比查询
  Future<QueryResult> _executeComparisonQuery(DateRange dateRange) async {
    // 计算对比期间（上一个同等时长的周期）
    final duration = dateRange.end.difference(dateRange.start);
    final previousStart = dateRange.start.subtract(duration);
    final previousEnd = dateRange.start.subtract(const Duration(days: 1));

    final currentTotal = await transactionRepository.getTotal(
      startDate: dateRange.start,
      endDate: dateRange.end,
      type: 'expense',
    );

    final previousTotal = await transactionRepository.getTotal(
      startDate: previousStart,
      endDate: previousEnd,
      type: 'expense',
    );

    final difference = currentTotal - previousTotal;
    final changePercent = previousTotal > 0
        ? ((difference / previousTotal) * 100)
        : (currentTotal > 0 ? 100.0 : 0.0);

    return QueryResult(
      queryType: QueryType.comparison,
      totalAmount: currentTotal,
      comparisonData: {
        'current': currentTotal,
        'previous': previousTotal,
        'difference': difference,
        'changePercent': changePercent,
        'currentPeriod': timeRange,
        'previousPeriod': '上一周期',
      },
      timeRange: timeRange,
    );
  }

  /// 执行搜索查询
  Future<QueryResult> _executeSearchQuery() async {
    final keyword = params['keyword'] as String? ?? '';
    final transactions = await transactionRepository.search(
      keyword,
      limit: limit ?? 20,
    );

    return QueryResult(
      queryType: QueryType.search,
      transactions: transactions,
      count: transactions.length,
    );
  }

  /// 解析时间范围
  DateRange _parseTimeRange(String timeRange) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (timeRange) {
      case '今天':
        return DateRange(today, now);

      case '昨天':
        final yesterday = today.subtract(const Duration(days: 1));
        return DateRange(yesterday, today.subtract(const Duration(seconds: 1)));

      case '本周':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return DateRange(weekStart, now);

      case '上周':
        final lastWeekEnd =
            today.subtract(Duration(days: today.weekday)).subtract(const Duration(seconds: 1));
        final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
        return DateRange(
          DateTime(lastWeekStart.year, lastWeekStart.month, lastWeekStart.day),
          lastWeekEnd,
        );

      case '本月':
        final monthStart = DateTime(now.year, now.month, 1);
        return DateRange(monthStart, now);

      case '上月':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateRange(lastMonth, lastMonthEnd);

      case '今年':
        final yearStart = DateTime(now.year, 1, 1);
        return DateRange(yearStart, now);

      default:
        // 尝试解析 "最近N天" 或 "最近N个月"
        final daysMatch = RegExp(r'最近(\d+)天').firstMatch(timeRange);
        if (daysMatch != null) {
          final days = int.parse(daysMatch.group(1)!);
          return DateRange(today.subtract(Duration(days: days)), now);
        }

        final monthsMatch = RegExp(r'最近(\d+)个?月').firstMatch(timeRange);
        if (monthsMatch != null) {
          final months = int.parse(monthsMatch.group(1)!);
          final start = DateTime(now.year, now.month - months, now.day);
          return DateRange(start, now);
        }

        // 默认返回本月
        return DateRange(DateTime(now.year, now.month, 1), now);
    }
  }

  /// 生成结果消息
  String _generateResultMessage(QueryResult result) {
    switch (result.queryType) {
      case QueryType.summary:
        final type =
            transactionTypeFilter == TransactionTypeFilter.income ? '收入' : '支出';
        return '$timeRange${category ?? ""}$type共${result.totalAmount?.toStringAsFixed(2) ?? 0}元，共${result.count ?? 0}笔';

      case QueryType.recent:
        return '找到${result.count ?? 0}笔最近的交易记录';

      case QueryType.trend:
        return '$timeRange消费趋势数据已生成';

      case QueryType.distribution:
        return '$timeRange各分类支出分布已统计';

      case QueryType.comparison:
        final data = result.comparisonData;
        if (data != null) {
          final change = data['changePercent'] as double;
          final changeText = change >= 0 ? '增加${change.toStringAsFixed(1)}%' : '减少${(-change).toStringAsFixed(1)}%';
          return '$timeRange支出${result.totalAmount?.toStringAsFixed(2)}元，比上期$changeText';
        }
        return '对比数据已生成';

      case QueryType.search:
        return '搜索到${result.count ?? 0}条相关记录';
    }
  }
}

/// 日期范围
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange(this.start, this.end);
}
