/// 查询执行器
///
/// 负责执行实际的数据库查询并返回QueryResult
library;

import 'package:flutter/foundation.dart';
import '../../../core/contracts/i_database_service.dart';
import '../../../models/transaction.dart';
import '../../database_service.dart';
import 'query_models.dart';

/// 查询执行器
class QueryExecutor {
  final IDatabaseService _databaseService;

  QueryExecutor({IDatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  /// 执行查询
  Future<QueryResult> execute(QueryRequest request) async {
    debugPrint('[QueryExecutor] 执行查询: $request');

    try {
      // 1. 查询数据库
      final transactions = await _queryTransactions(request);
      debugPrint('[QueryExecutor] 查询到 ${transactions.length} 条记录');

      // 2. 根据查询类型处理数据
      switch (request.queryType) {
        case QueryType.summary:
          return _executeSummaryQuery(request, transactions);

        case QueryType.recent:
          return _executeRecentQuery(request, transactions);

        case QueryType.trend:
          return _executeTrendQuery(request, transactions);

        case QueryType.distribution:
          return _executeDistributionQuery(request, transactions);

        case QueryType.comparison:
          return _executeComparisonQuery(request, transactions);

        case QueryType.custom:
          return _executeCustomQuery(request, transactions);
      }
    } catch (e) {
      debugPrint('[QueryExecutor] 查询失败: $e');
      rethrow;
    }
  }

  /// 查询交易记录
  Future<List<Transaction>> _queryTransactions(QueryRequest request) async {
    final transactions = await _databaseService.queryTransactions(
      startDate: request.timeRange?.startDate,
      endDate: request.timeRange?.endDate,
      category: request.category,
      // TODO: 支持更多筛选条件（source, account等）
    );

    return transactions;
  }

  /// 执行总额统计查询
  QueryResult _executeSummaryQuery(
    QueryRequest request,
    List<Transaction> transactions,
  ) {
    final totalExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: transactions.length,
      periodText: request.timeRange?.periodText ?? '全部',
    );
  }

  /// 执行最近记录查询
  QueryResult _executeRecentQuery(
    QueryRequest request,
    List<Transaction> transactions,
  ) {
    // 按时间倒序排序，取最近的记录
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final limit = request.limit ?? 10;
    final recentTransactions = sortedTransactions.take(limit).toList();

    final totalExpense = recentTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalIncome = recentTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: recentTransactions.length,
      periodText: request.timeRange?.periodText ?? '最近',
    );
  }

  /// 执行趋势分析查询
  QueryResult _executeTrendQuery(
    QueryRequest request,
    List<Transaction> transactions,
  ) {
    if (request.groupBy == null || request.groupBy!.isEmpty) {
      // 没有分组维度，返回总额统计
      return _executeSummaryQuery(request, transactions);
    }

    final groupBy = request.groupBy!.first;
    List<DataPoint> dataPoints = [];

    switch (groupBy) {
      case GroupByDimension.date:
        dataPoints = _groupByDate(transactions);
        break;

      case GroupByDimension.month:
        dataPoints = _groupByMonth(transactions);
        break;

      case GroupByDimension.category:
        dataPoints = _groupByCategory(transactions);
        break;

      default:
        // 其他维度暂不支持趋势分析
        return _executeSummaryQuery(request, transactions);
    }

    final totalExpense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: transactions.length,
      periodText: request.timeRange?.periodText ?? '全部',
      detailedData: dataPoints,
    );
  }

  /// 执行分布查询
  QueryResult _executeDistributionQuery(
    QueryRequest request,
    List<Transaction> transactions,
  ) {
    // 按分类分组统计
    final Map<String, double> groupedData = {};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final category = transaction.category;
        groupedData[category] = (groupedData[category] ?? 0) + transaction.amount;
      }
    }

    final totalExpense = groupedData.values.fold(0.0, (sum, amount) => sum + amount);
    final totalIncome = transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: transactions.length,
      periodText: request.timeRange?.periodText ?? '全部',
      groupedData: groupedData,
    );
  }

  /// 执行对比查询
  QueryResult _executeComparisonQuery(
    QueryRequest request,
    List<Transaction> transactions,
  ) {
    // TODO: 实现对比查询逻辑（环比、同比）
    return _executeSummaryQuery(request, transactions);
  }

  /// 执行自定义查询
  QueryResult _executeCustomQuery(
    QueryRequest request,
    List<Transaction> transactions,
  ) {
    // TODO: 实现自定义SQL查询
    return _executeSummaryQuery(request, transactions);
  }

  /// 按日期分组
  List<DataPoint> _groupByDate(List<Transaction> transactions) {
    final Map<String, double> dailyExpense = {};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final dateKey = '${transaction.date.month}/${transaction.date.day}';
        dailyExpense[dateKey] = (dailyExpense[dateKey] ?? 0) + transaction.amount;
      }
    }

    // 按日期排序
    final sortedEntries = dailyExpense.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries
        .map((e) => DataPoint(label: e.key, value: e.value))
        .toList();
  }

  /// 按月份分组
  List<DataPoint> _groupByMonth(List<Transaction> transactions) {
    final Map<String, double> monthlyExpense = {};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final monthKey = '${transaction.date.month}月';
        monthlyExpense[monthKey] = (monthlyExpense[monthKey] ?? 0) + transaction.amount;
      }
    }

    // 按月份排序
    final sortedEntries = monthlyExpense.entries.toList()
      ..sort((a, b) {
        final aMonth = int.parse(a.key.replaceAll('月', ''));
        final bMonth = int.parse(b.key.replaceAll('月', ''));
        return aMonth.compareTo(bMonth);
      });

    return sortedEntries
        .map((e) => DataPoint(label: e.key, value: e.value))
        .toList();
  }

  /// 按分类分组
  List<DataPoint> _groupByCategory(List<Transaction> transactions) {
    final Map<String, double> categoryExpense = {};

    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final category = transaction.category;
        categoryExpense[category] = (categoryExpense[category] ?? 0) + transaction.amount;
      }
    }

    // 按金额降序排序
    final sortedEntries = categoryExpense.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .map((e) => DataPoint(label: e.key, value: e.value))
        .toList();
  }
}
