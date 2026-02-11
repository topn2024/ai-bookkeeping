import 'dart:async';

import 'package:flutter/foundation.dart';
import 'category_localization_service.dart';

/// 自然语言搜索服务
///
/// 功能：
/// 1. 本地规则优先解析简单查询
/// 2. 大模型理解复杂查询
/// 3. 支持时间、分类、金额、商家等多维度搜索
/// 4. 学习用户搜索习惯
class NaturalLanguageSearchService {
  final NLSearchTransactionRepository _transactionRepo;
  final SimpleLLMService? _llmService;

  NaturalLanguageSearchService({
    required NLSearchTransactionRepository transactionRepo,
    SimpleLLMService? llmService,
  })  : _transactionRepo = transactionRepo,
        _llmService = llmService;

  /// 处理自然语言查询
  Future<SearchResult> search(String query) async {
    if (query.trim().isEmpty) {
      return SearchResult(
        answer: '请输入搜索内容',
        type: ResultType.error,
      );
    }

    // 第一步：意图识别（本地规则优先）
    final intent = _parseQueryIntent(query);

    if (intent != null) {
      // 本地规则能处理
      return await _executeLocalQuery(intent);
    }

    // 第二步：大模型理解复杂查询
    if (_llmService != null) {
      return await _executeLLMQuery(query);
    }

    // 无法解析时，降级为全文搜索
    return await _fallbackSearch(query);
  }

  /// 本地规则解析意图
  QueryIntent? _parseQueryIntent(String query) {
    DateRange? dateRange;
    String? category;
    String? merchant;
    AmountRange? amountRange;
    QueryType queryType = QueryType.list;

    // ===== 时间模式匹配 =====
    dateRange = _parseDateRange(query);

    // ===== 分类模式匹配 =====
    category = _parseCategory(query);

    // ===== 商家匹配 =====
    merchant = _parseMerchant(query);

    // ===== 金额范围匹配 =====
    amountRange = _parseAmountRange(query);

    // ===== 查询类型判断 =====
    if (RegExp(r'花了?多少|消费了?多少|总共|合计|一共').hasMatch(query)) {
      queryType = QueryType.sum;
    } else if (RegExp(r'最多|最大|最贵').hasMatch(query)) {
      queryType = QueryType.max;
    } else if (RegExp(r'最少|最小|最便宜').hasMatch(query)) {
      queryType = QueryType.min;
    } else if (RegExp(r'平均').hasMatch(query)) {
      queryType = QueryType.average;
    } else if (RegExp(r'趋势|变化|对比').hasMatch(query)) {
      queryType = QueryType.trend;
    } else if (RegExp(r'次数|多少次|几次').hasMatch(query)) {
      queryType = QueryType.count;
    }

    // 如果有任何可解析的条件，返回意图
    if (dateRange != null ||
        category != null ||
        merchant != null ||
        amountRange != null) {
      return QueryIntent(
        type: queryType,
        dateRange: dateRange,
        category: category,
        merchant: merchant,
        amountRange: amountRange,
        originalQuery: query,
      );
    }

    return null; // 无法本地解析
  }

  /// 解析时间范围
  DateRange? _parseDateRange(String query) {
    final now = DateTime.now();

    // 今天
    if (RegExp(r'今天|今日').hasMatch(query)) {
      return DateRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    }

    // 昨天
    if (RegExp(r'昨天|昨日').hasMatch(query)) {
      final yesterday = now.subtract(const Duration(days: 1));
      return DateRange(
        start: DateTime(yesterday.year, yesterday.month, yesterday.day),
        end: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
      );
    }

    // 本周
    if (RegExp(r'这周|本周|这个星期').hasMatch(query)) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      return DateRange(
        start: DateTime(weekStart.year, weekStart.month, weekStart.day),
        end: now,
      );
    }

    // 上周
    if (RegExp(r'上周|上个星期').hasMatch(query)) {
      final lastWeekStart = now.subtract(Duration(days: now.weekday + 6));
      final lastWeekEnd = now.subtract(Duration(days: now.weekday));
      return DateRange(
        start: DateTime(lastWeekStart.year, lastWeekStart.month, lastWeekStart.day),
        end: DateTime(lastWeekEnd.year, lastWeekEnd.month, lastWeekEnd.day, 23, 59, 59),
      );
    }

    // 本月
    if (RegExp(r'这个?月|本月').hasMatch(query)) {
      return DateRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );
    }

    // 上个月
    if (RegExp(r'上个?月').hasMatch(query)) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      return DateRange(
        start: lastMonth,
        end: DateTime(lastMonthEnd.year, lastMonthEnd.month, lastMonthEnd.day, 23, 59, 59),
      );
    }

    // 今年
    if (RegExp(r'今年|本年').hasMatch(query)) {
      return DateRange(
        start: DateTime(now.year, 1, 1),
        end: now,
      );
    }

    // 特定月份：X月
    final monthMatch = RegExp(r'(\d{1,2})月').firstMatch(query);
    if (monthMatch != null) {
      final month = int.parse(monthMatch.group(1)!);
      if (month >= 1 && month <= 12) {
        final year = month > now.month ? now.year - 1 : now.year;
        final monthStart = DateTime(year, month, 1);
        final monthEnd = DateTime(year, month + 1, 0);
        return DateRange(
          start: monthStart,
          end: DateTime(monthEnd.year, monthEnd.month, monthEnd.day, 23, 59, 59),
        );
      }
    }

    // 最近N天
    final recentDaysMatch = RegExp(r'最近(\d+)天|近(\d+)天').firstMatch(query);
    if (recentDaysMatch != null) {
      final days = int.parse(recentDaysMatch.group(1) ?? recentDaysMatch.group(2)!);
      return DateRange(
        start: now.subtract(Duration(days: days)),
        end: now,
      );
    }

    return null;
  }

  /// 解析分类
  String? _parseCategory(String query) {
    const categoryKeywords = {
      '餐饮': ['餐饮', '吃饭', '饭钱', '外卖', '吃的', '饭', '餐'],
      '交通': ['交通', '打车', '地铁', '公交', '加油', '出行'],
      '购物': ['购物', '买东西', '买的', '消费', '网购'],
      '娱乐': ['娱乐', '玩', '游戏', '电影', 'ktv'],
      '居住': ['居住', '房租', '水电', '物业', '房贷'],
      '医疗': ['医疗', '看病', '医院', '药', '挂号'],
      '教育': ['教育', '学费', '培训', '课程', '书'],
      '通讯': ['通讯', '话费', '手机', '流量'],
      '服饰': ['服饰', '衣服', '鞋', '包'],
      '美容': ['美容', '理发', '化妆品', '护肤'],
      '人情': ['人情', '红包', '礼金', '送礼'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (query.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// 解析商家
  String? _parseMerchant(String query) {
    // 匹配模式："在XX"、"XX的"
    final merchantPatterns = [
      RegExp(r'在([^\s,，]+?)(?:的|消费|花|买)'),
      RegExp(r'([^\s,，]+?)(?:的消费|的支出)'),
    ];

    for (final pattern in merchantPatterns) {
      final match = pattern.firstMatch(query);
      if (match != null) {
        final merchant = match.group(1)!;
        // 排除常见的非商家词
        if (!['我', '今天', '这个月', '上个月', '最近'].contains(merchant)) {
          return merchant;
        }
      }
    }

    return null;
  }

  /// 解析金额范围
  AmountRange? _parseAmountRange(String query) {
    double? minAmount;
    double? maxAmount;

    // 大于/超过 X元
    final minMatch = RegExp(r'(?:大于|超过|高于|多于)\s*(\d+(?:\.\d+)?)\s*[元块]?').firstMatch(query);
    if (minMatch != null) {
      minAmount = double.parse(minMatch.group(1)!);
    }

    // 小于/低于 X元
    final maxMatch = RegExp(r'(?:小于|低于|少于|不超过)\s*(\d+(?:\.\d+)?)\s*[元块]?').firstMatch(query);
    if (maxMatch != null) {
      maxAmount = double.parse(maxMatch.group(1)!);
    }

    // X元以上
    final aboveMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[元块]?\s*以上').firstMatch(query);
    if (aboveMatch != null) {
      minAmount = double.parse(aboveMatch.group(1)!);
    }

    // X元以下
    final belowMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[元块]?\s*以下').firstMatch(query);
    if (belowMatch != null) {
      maxAmount = double.parse(belowMatch.group(1)!);
    }

    // X到Y元
    final rangeMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[元块]?\s*(?:到|至|-)\s*(\d+(?:\.\d+)?)\s*[元块]?').firstMatch(query);
    if (rangeMatch != null) {
      minAmount = double.parse(rangeMatch.group(1)!);
      maxAmount = double.parse(rangeMatch.group(2)!);
    }

    if (minAmount != null || maxAmount != null) {
      return AmountRange(min: minAmount, max: maxAmount);
    }

    return null;
  }

  /// 执行本地查询
  Future<SearchResult> _executeLocalQuery(QueryIntent intent) async {
    try {
      switch (intent.type) {
        case QueryType.sum:
          final total = await _transactionRepo.sumByFilter(
            dateRange: intent.dateRange,
            categoryName: intent.category,
            merchant: intent.merchant,
            amountRange: intent.amountRange,
          );
          return SearchResult(
            answer: _formatSumAnswer(intent, total),
            type: ResultType.answer,
            data: {'total': total},
            intent: intent,
          );

        case QueryType.count:
          final count = await _transactionRepo.countByFilter(
            dateRange: intent.dateRange,
            categoryName: intent.category,
            merchant: intent.merchant,
            amountRange: intent.amountRange,
          );
          return SearchResult(
            answer: _formatCountAnswer(intent, count),
            type: ResultType.answer,
            data: {'count': count},
            intent: intent,
          );

        case QueryType.max:
          final transaction = await _transactionRepo.findMaxByFilter(
            dateRange: intent.dateRange,
            categoryName: intent.category,
          );
          if (transaction != null) {
            return SearchResult(
              answer: '最大一笔消费是¥${transaction.amount.toStringAsFixed(2)}',
              type: ResultType.single,
              data: {'transaction': transaction},
              intent: intent,
            );
          }
          return SearchResult(
            answer: '未找到符合条件的记录',
            type: ResultType.empty,
            intent: intent,
          );

        case QueryType.min:
          final transaction = await _transactionRepo.findMinByFilter(
            dateRange: intent.dateRange,
            categoryName: intent.category,
          );
          if (transaction != null) {
            return SearchResult(
              answer: '最小一笔消费是¥${transaction.amount.toStringAsFixed(2)}',
              type: ResultType.single,
              data: {'transaction': transaction},
              intent: intent,
            );
          }
          return SearchResult(
            answer: '未找到符合条件的记录',
            type: ResultType.empty,
            intent: intent,
          );

        case QueryType.average:
          final avg = await _transactionRepo.avgByFilter(
            dateRange: intent.dateRange,
            categoryName: intent.category,
          );
          return SearchResult(
            answer: '平均消费¥${avg.toStringAsFixed(2)}',
            type: ResultType.answer,
            data: {'average': avg},
            intent: intent,
          );

        case QueryType.trend:
          final trendData = await _transactionRepo.getTrendByFilter(
            dateRange: intent.dateRange,
            categoryName: intent.category,
          );
          return SearchResult(
            answer: _formatTrendAnswer(trendData),
            type: ResultType.trend,
            data: {'trend': trendData},
            intent: intent,
          );

        case QueryType.list:
        default:
          final transactions = await _transactionRepo.findByFilter(
            dateRange: intent.dateRange,
            categoryName: intent.category,
            merchant: intent.merchant,
            amountRange: intent.amountRange,
            limit: 50,
          );
          if (transactions.isEmpty) {
            return SearchResult(
              answer: '未找到符合条件的记录',
              type: ResultType.empty,
              intent: intent,
            );
          }
          return SearchResult(
            answer: '找到 ${transactions.length} 条记录',
            type: ResultType.list,
            data: {'transactions': transactions},
            intent: intent,
          );
      }
    } catch (e) {
      debugPrint('Local query failed: $e');
      return SearchResult(
        answer: '查询失败，请稍后重试',
        type: ResultType.error,
      );
    }
  }

  /// 使用大模型处理复杂查询
  Future<SearchResult> _executeLLMQuery(String query) async {
    if (_llmService == null) {
      return await _fallbackSearch(query);
    }

    try {
      final structuredQuery = await _llmService.parseSearchQuery(query);
      if (structuredQuery != null) {
        // 将LLM解析的结果转换为QueryIntent
        final intent = QueryIntent(
          type: _parseQueryType(structuredQuery['intent'] as String?),
          dateRange: _parseLLMDateRange(structuredQuery['date_range']),
          category: structuredQuery['category'] as String?,
          merchant: structuredQuery['merchant'] as String?,
          amountRange: _parseLLMAmountRange(structuredQuery['amount_filter']),
          originalQuery: query,
        );
        return await _executeLocalQuery(intent);
      }
    } catch (e) {
      debugPrint('LLM query failed: $e');
    }

    return await _fallbackSearch(query);
  }

  QueryType _parseQueryType(String? type) {
    switch (type) {
      case 'sum':
        return QueryType.sum;
      case 'count':
        return QueryType.count;
      case 'max':
        return QueryType.max;
      case 'min':
        return QueryType.min;
      case 'average':
        return QueryType.average;
      case 'trend':
        return QueryType.trend;
      default:
        return QueryType.list;
    }
  }

  DateRange? _parseLLMDateRange(dynamic dateRange) {
    if (dateRange == null) return null;
    try {
      final start = DateTime.parse(dateRange['start'] as String);
      final end = DateTime.parse(dateRange['end'] as String);
      return DateRange(start: start, end: end);
    } catch (e) {
      return null;
    }
  }

  AmountRange? _parseLLMAmountRange(dynamic amountFilter) {
    if (amountFilter == null) return null;
    return AmountRange(
      min: (amountFilter['min'] as num?)?.toDouble(),
      max: (amountFilter['max'] as num?)?.toDouble(),
    );
  }

  /// 降级为全文搜索
  Future<SearchResult> _fallbackSearch(String query) async {
    try {
      final transactions = await _transactionRepo.fullTextSearch(query, limit: 50);
      if (transactions.isEmpty) {
        return SearchResult(
          answer: '未找到与"$query"相关的记录',
          type: ResultType.empty,
        );
      }
      return SearchResult(
        answer: '找到 ${transactions.length} 条相关记录',
        type: ResultType.list,
        data: {'transactions': transactions},
      );
    } catch (e) {
      return SearchResult(
        answer: '搜索失败，请稍后重试',
        type: ResultType.error,
      );
    }
  }

  /// 格式化合计答案
  String _formatSumAnswer(QueryIntent intent, double total) {
    final buffer = StringBuffer();

    if (intent.dateRange != null) {
      buffer.write(_formatDateRangeDescription(intent.dateRange!));
    }

    if (intent.category != null) {
      buffer.write(intent.category!.localizedCategoryName);
    }

    if (intent.merchant != null) {
      buffer.write('在${intent.merchant}');
    }

    buffer.write('消费共 ¥${total.toStringAsFixed(2)}');

    return buffer.toString();
  }

  /// 格式化计数答案
  String _formatCountAnswer(QueryIntent intent, int count) {
    final buffer = StringBuffer();

    if (intent.dateRange != null) {
      buffer.write(_formatDateRangeDescription(intent.dateRange!));
    }

    if (intent.category != null) {
      buffer.write(intent.category!.localizedCategoryName);
    }

    buffer.write('共消费 $count 次');

    return buffer.toString();
  }

  /// 格式化趋势答案
  String _formatTrendAnswer(List<TrendDataPoint> trendData) {
    if (trendData.isEmpty) return '暂无趋势数据';
    if (trendData.length < 2) return '数据不足，无法分析趋势';

    final first = trendData.first.amount;
    final last = trendData.last.amount;

    if (first == 0) return '消费呈上升趋势';

    final change = (last - first) / first * 100;

    if (change > 10) {
      return '消费呈上升趋势，增长${change.toStringAsFixed(1)}%';
    } else if (change < -10) {
      return '消费呈下降趋势，减少${(-change).toStringAsFixed(1)}%';
    } else {
      return '消费趋势平稳';
    }
  }

  /// 格式化时间范围描述
  String _formatDateRangeDescription(DateRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(range.start.year, range.start.month, range.start.day);

    // 今天
    if (startDate == today && range.end.day == now.day) {
      return '今天';
    }

    // 本月
    if (range.start.month == now.month && range.start.year == now.year) {
      return '本月';
    }

    // 上个月
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    if (range.start.month == lastMonth.month && range.start.year == lastMonth.year) {
      return '上个月';
    }

    // 特定月份
    if (range.start.day == 1) {
      return '${range.start.month}月';
    }

    return '';
  }
}

// ==================== 数据模型 ====================

/// 查询类型
enum QueryType {
  list, // 列表查询
  sum, // 合计查询
  count, // 计数查询
  max, // 最大值查询
  min, // 最小值查询
  average, // 平均值查询
  trend, // 趋势查询
  compare, // 对比查询
}

/// 结果类型
enum ResultType {
  answer, // 直接答案
  list, // 列表结果
  single, // 单条结果
  stats, // 统计结果
  trend, // 趋势结果
  empty, // 空结果
  error, // 错误
}

/// 时间范围
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});
}

/// 金额范围
class AmountRange {
  final double? min;
  final double? max;

  const AmountRange({this.min, this.max});
}

/// 查询意图
class QueryIntent {
  final QueryType type;
  final DateRange? dateRange;
  final String? category;
  final String? merchant;
  final AmountRange? amountRange;
  final String originalQuery;

  const QueryIntent({
    required this.type,
    this.dateRange,
    this.category,
    this.merchant,
    this.amountRange,
    required this.originalQuery,
  });
}

/// 搜索结果
class SearchResult {
  final String answer;
  final ResultType type;
  final Map<String, dynamic>? data;
  final QueryIntent? intent;

  const SearchResult({
    required this.answer,
    required this.type,
    this.data,
    this.intent,
  });
}

/// 趋势数据点
class TrendDataPoint {
  final DateTime date;
  final double amount;

  const TrendDataPoint({required this.date, required this.amount});
}

/// 简单交易
class NLSearchTransaction {
  final String id;
  final double amount;
  final DateTime date;
  final String? category;
  final String? merchant;
  final String? description;

  const NLSearchTransaction({
    required this.id,
    required this.amount,
    required this.date,
    this.category,
    this.merchant,
    this.description,
  });
}

/// 交易仓库接口
abstract class NLSearchTransactionRepository {
  Future<double> sumByFilter({
    DateRange? dateRange,
    String? categoryName,
    String? merchant,
    AmountRange? amountRange,
  });

  Future<int> countByFilter({
    DateRange? dateRange,
    String? categoryName,
    String? merchant,
    AmountRange? amountRange,
  });

  Future<double> avgByFilter({
    DateRange? dateRange,
    String? categoryName,
  });

  Future<NLSearchTransaction?> findMaxByFilter({
    DateRange? dateRange,
    String? categoryName,
  });

  Future<NLSearchTransaction?> findMinByFilter({
    DateRange? dateRange,
    String? categoryName,
  });

  Future<List<NLSearchTransaction>> findByFilter({
    DateRange? dateRange,
    String? categoryName,
    String? merchant,
    AmountRange? amountRange,
    int limit,
  });

  Future<List<TrendDataPoint>> getTrendByFilter({
    DateRange? dateRange,
    String? categoryName,
  });

  Future<List<NLSearchTransaction>> fullTextSearch(String query, {int limit});
}

/// LLM服务接口
abstract class SimpleLLMService {
  Future<Map<String, dynamic>?> parseSearchQuery(String query);
}

/// 基于 DatabaseService 的 NLSearchTransactionRepository 实现
class DatabaseTransactionRepository implements NLSearchTransactionRepository {
  final Future<List<Map<String, dynamic>>> Function({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? merchant,
    double? minAmount,
    double? maxAmount,
    int? limit,
  }) queryTransactions;

  DatabaseTransactionRepository({required this.queryTransactions});

  @override
  Future<double> sumByFilter({
    DateRange? dateRange,
    String? categoryName,
    String? merchant,
    AmountRange? amountRange,
  }) async {
    final transactions = await _queryWithFilter(
      dateRange: dateRange,
      categoryName: categoryName,
      merchant: merchant,
      amountRange: amountRange,
    );
    return transactions.fold<double>(0.0, (sum, t) => sum + (t['amount'] as double? ?? 0.0));
  }

  @override
  Future<int> countByFilter({
    DateRange? dateRange,
    String? categoryName,
    String? merchant,
    AmountRange? amountRange,
  }) async {
    final transactions = await _queryWithFilter(
      dateRange: dateRange,
      categoryName: categoryName,
      merchant: merchant,
      amountRange: amountRange,
    );
    return transactions.length;
  }

  @override
  Future<double> avgByFilter({
    DateRange? dateRange,
    String? categoryName,
  }) async {
    final transactions = await _queryWithFilter(
      dateRange: dateRange,
      categoryName: categoryName,
    );
    if (transactions.isEmpty) return 0.0;
    final total = transactions.fold<double>(0.0, (sum, t) => sum + (t['amount'] as double? ?? 0.0));
    return total / transactions.length;
  }

  @override
  Future<NLSearchTransaction?> findMaxByFilter({
    DateRange? dateRange,
    String? categoryName,
  }) async {
    final transactions = await _queryWithFilter(
      dateRange: dateRange,
      categoryName: categoryName,
    );
    if (transactions.isEmpty) return null;

    transactions.sort((a, b) => ((b['amount'] as double?) ?? 0.0)
        .compareTo((a['amount'] as double?) ?? 0.0));
    return _mapToTransaction(transactions.first);
  }

  @override
  Future<NLSearchTransaction?> findMinByFilter({
    DateRange? dateRange,
    String? categoryName,
  }) async {
    final transactions = await _queryWithFilter(
      dateRange: dateRange,
      categoryName: categoryName,
    );
    if (transactions.isEmpty) return null;

    transactions.sort((a, b) => ((a['amount'] as double?) ?? 0.0)
        .compareTo((b['amount'] as double?) ?? 0.0));
    return _mapToTransaction(transactions.first);
  }

  @override
  Future<List<NLSearchTransaction>> findByFilter({
    DateRange? dateRange,
    String? categoryName,
    String? merchant,
    AmountRange? amountRange,
    int limit = 50,
  }) async {
    final transactions = await _queryWithFilter(
      dateRange: dateRange,
      categoryName: categoryName,
      merchant: merchant,
      amountRange: amountRange,
      limit: limit,
    );
    return transactions.map(_mapToTransaction).toList();
  }

  @override
  Future<List<TrendDataPoint>> getTrendByFilter({
    DateRange? dateRange,
    String? categoryName,
  }) async {
    final transactions = await _queryWithFilter(
      dateRange: dateRange,
      categoryName: categoryName,
    );

    // 按日期分组汇总
    final dailyTotals = <DateTime, double>{};
    for (final t in transactions) {
      final date = DateTime.tryParse(t['date'] as String? ?? '');
      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        dailyTotals[day] = (dailyTotals[day] ?? 0) + (t['amount'] as double? ?? 0.0);
      }
    }

    // 转换为趋势数据点并按日期排序
    final points = dailyTotals.entries
        .map((e) => TrendDataPoint(date: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return points;
  }

  @override
  Future<List<NLSearchTransaction>> fullTextSearch(String query, {int limit = 50}) async {
    // 简单全文搜索：在备注和商家中查找关键词
    final allTransactions = await queryTransactions(limit: 500);
    final lowerQuery = query.toLowerCase();

    final matched = allTransactions.where((t) {
      final note = (t['note'] as String? ?? '').toLowerCase();
      final merchant = (t['rawMerchant'] as String? ?? '').toLowerCase();
      final category = (t['category'] as String? ?? '').toLowerCase();
      return note.contains(lowerQuery) ||
          merchant.contains(lowerQuery) ||
          category.contains(lowerQuery);
    }).take(limit).toList();

    return matched.map(_mapToTransaction).toList();
  }

  Future<List<Map<String, dynamic>>> _queryWithFilter({
    DateRange? dateRange,
    String? categoryName,
    String? merchant,
    AmountRange? amountRange,
    int? limit,
  }) async {
    // 规范化分类名称为标准英文ID（如 '餐饮' → 'food', '交通' → 'transport'）
    final normalizedCategory = categoryName != null
        ? CategoryLocalizationService.instance.normalizeCategoryId(categoryName)
        : null;

    return await queryTransactions(
      startDate: dateRange?.start,
      endDate: dateRange?.end,
      category: normalizedCategory,
      merchant: merchant,
      minAmount: amountRange?.min,
      maxAmount: amountRange?.max,
      limit: limit,
    );
  }

  NLSearchTransaction _mapToTransaction(Map<String, dynamic> map) {
    return NLSearchTransaction(
      id: map['id'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      category: map['category'] as String?,
      merchant: map['rawMerchant'] as String?,
      description: map['note'] as String?,
    );
  }
}
