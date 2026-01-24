/// 查询计算策略实现
///
/// 包含各种查询类型的具体计算逻辑
library;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../models/transaction.dart' as model;
import 'query_models.dart';
import 'query_calculator.dart';

// ═══════════════════════════════════════════════════════════════
// 简单计算器（默认）
// ═══════════════════════════════════════════════════════════════

/// 简单计算器 - 基础统计
class SimpleCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(
    List<model.Transaction> transactions,
    QueryRequest request,
  ) {
    double totalExpense = 0;
    double totalIncome = 0;
    int count = 0;

    for (final transaction in transactions) {
      if (transaction.type == model.TransactionType.expense) {
        totalExpense += transaction.amount;
        count++;
      } else if (transaction.type == model.TransactionType.income) {
        totalIncome += transaction.amount;
        count++;
      }
    }

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: count,
      periodText: request.timeRange?.periodText ?? '全部',
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 汇总计算器
// ═══════════════════════════════════════════════════════════════

/// 汇总计算器 - 时间范围内的总额统计
class SummaryCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(
    List<model.Transaction> transactions,
    QueryRequest request,
  ) {
    double totalExpense = 0;
    double totalIncome = 0;
    int expenseCount = 0;
    int incomeCount = 0;

    // 如果指定了分类，计算该分类的占比
    double? categoryExpense;
    double? categoryIncome;

    for (final transaction in transactions) {
      if (transaction.type == model.TransactionType.expense) {
        totalExpense += transaction.amount;
        expenseCount++;

        // 如果指定了分类，累计该分类的金额
        if (request.category != null && transaction.category == request.category) {
          categoryExpense = (categoryExpense ?? 0) + transaction.amount;
        }
      } else if (transaction.type == model.TransactionType.income) {
        totalIncome += transaction.amount;
        incomeCount++;

        if (request.category != null && transaction.category == request.category) {
          categoryIncome = (categoryIncome ?? 0) + transaction.amount;
        }
      }
    }

    // 如果指定了分类，构建分组数据
    Map<String, double>? groupedData;
    if (request.category != null) {
      groupedData = {
        request.category!: categoryExpense ?? categoryIncome ?? 0,
        '其他': (totalExpense + totalIncome) - (categoryExpense ?? 0) - (categoryIncome ?? 0),
      };
    }

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: expenseCount + incomeCount,
      periodText: request.timeRange?.periodText ?? '全部',
      groupedData: groupedData,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 趋势分析计算器
// ═══════════════════════════════════════════════════════════════

/// 趋势分析计算器 - 按时间分组的趋势数据
class TrendCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(
    List<model.Transaction> transactions,
    QueryRequest request,
  ) {
    // 按日期分组
    final groupedByDate = <DateTime, double>{};
    double totalExpense = 0;
    double totalIncome = 0;

    for (final transaction in transactions) {
      // 只统计支出的趋势
      if (transaction.type == model.TransactionType.expense) {
        final date = DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        );
        groupedByDate[date] = (groupedByDate[date] ?? 0) + transaction.amount;
        totalExpense += transaction.amount;
      } else if (transaction.type == model.TransactionType.income) {
        totalIncome += transaction.amount;
      }
    }

    // 生成趋势数据点
    final dataPoints = groupedByDate.entries
        .map((e) => DataPoint(
              label: DateFormat('MM-dd').format(e.key),
              value: e.value,
              timestamp: e.key,
            ))
        .toList()
      ..sort((a, b) => a.timestamp!.compareTo(b.timestamp!));

    debugPrint('[TrendCalculator] 生成趋势数据点: ${dataPoints.length}个');

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: transactions.length,
      periodText: request.timeRange?.periodText ?? '全部',
      detailedData: dataPoints,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 分布计算器
// ═══════════════════════════════════════════════════════════════

/// 分布计算器 - 按分类的分布统计
class DistributionCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(
    List<model.Transaction> transactions,
    QueryRequest request,
  ) {
    // 按分类分组
    final groupedByCategory = <String, double>{};
    double totalExpense = 0;
    double totalIncome = 0;

    for (final transaction in transactions) {
      if (transaction.type == model.TransactionType.expense) {
        final category = transaction.category;
        groupedByCategory[category] = (groupedByCategory[category] ?? 0) + transaction.amount;
        totalExpense += transaction.amount;
      } else if (transaction.type == model.TransactionType.income) {
        totalIncome += transaction.amount;
      }
    }

    // 按金额降序排序，取前10个分类
    final sortedEntries = groupedByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedEntries.take(10).toList();

    // 生成数据点
    final dataPoints = topCategories
        .map((e) => DataPoint(
              label: e.key,
              value: e.value,
              category: e.key,
            ))
        .toList();

    debugPrint('[DistributionCalculator] 分类分布: ${dataPoints.length}个分类');

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: transactions.length,
      periodText: request.timeRange?.periodText ?? '全部',
      detailedData: dataPoints,
      groupedData: Map.fromEntries(topCategories),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 对比计算器
// ═══════════════════════════════════════════════════════════════

/// 对比计算器 - 多个维度的对比分析
class ComparisonCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(
    List<model.Transaction> transactions,
    QueryRequest request,
  ) {
    // 如果指定了分组维度，按该维度分组
    final groupBy = request.groupBy?.first ?? GroupByDimension.category;

    final groupedData = <String, double>{};
    double totalExpense = 0;
    double totalIncome = 0;

    for (final transaction in transactions) {
      if (transaction.type == model.TransactionType.expense) {
        final key = _getGroupKey(transaction, groupBy);
        groupedData[key] = (groupedData[key] ?? 0) + transaction.amount;
        totalExpense += transaction.amount;
      } else if (transaction.type == model.TransactionType.income) {
        totalIncome += transaction.amount;
      }
    }

    // 生成对比数据点
    final dataPoints = groupedData.entries
        .map((e) => DataPoint(
              label: e.key,
              value: e.value,
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    debugPrint('[ComparisonCalculator] 对比维度: $groupBy, 数据点: ${dataPoints.length}个');

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: transactions.length,
      periodText: request.timeRange?.periodText ?? '全部',
      detailedData: dataPoints,
      groupedData: groupedData,
    );
  }

  /// 获取分组键
  String _getGroupKey(model.Transaction transaction, GroupByDimension dimension) {
    switch (dimension) {
      case GroupByDimension.category:
        return transaction.category;
      case GroupByDimension.date:
        return DateFormat('yyyy-MM-dd').format(transaction.date);
      case GroupByDimension.month:
        return DateFormat('yyyy-MM').format(transaction.date);
      case GroupByDimension.source:
        return transaction.source.name;
      case GroupByDimension.account:
        return transaction.accountId;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 最近记录计算器
// ═══════════════════════════════════════════════════════════════

/// 最近记录计算器 - 获取最近的交易记录
class RecentCalculator implements QueryCalculatorStrategy {
  @override
  QueryResult calculate(
    List<model.Transaction> transactions,
    QueryRequest request,
  ) {
    // 按日期降序排序
    final sortedTransactions = transactions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // 取前N条记录
    final limit = request.limit ?? 10;
    final recentTransactions = sortedTransactions.take(limit).toList();

    double totalExpense = 0;
    double totalIncome = 0;

    // 生成数据点
    final dataPoints = <DataPoint>[];
    for (final transaction in recentTransactions) {
      if (transaction.type == model.TransactionType.expense) {
        totalExpense += transaction.amount;
        dataPoints.add(DataPoint(
          label: '${transaction.category} - ${DateFormat('MM-dd').format(transaction.date)}',
          value: transaction.amount,
          timestamp: transaction.date,
          category: transaction.category,
        ));
      } else if (transaction.type == model.TransactionType.income) {
        totalIncome += transaction.amount;
        dataPoints.add(DataPoint(
          label: '${transaction.category} - ${DateFormat('MM-dd').format(transaction.date)}',
          value: transaction.amount,
          timestamp: transaction.date,
          category: transaction.category,
        ));
      }
    }

    debugPrint('[RecentCalculator] 最近记录: ${dataPoints.length}条');

    return QueryResult(
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      transactionCount: recentTransactions.length,
      periodText: request.timeRange?.periodText ?? '最近',
      detailedData: dataPoints,
    );
  }
}
