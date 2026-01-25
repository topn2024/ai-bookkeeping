/// 查询结果路由器
///
/// 根据查询复杂度自动选择合适的响应方式
library;

import 'package:flutter/foundation.dart';
import '../../../extensions/category_extensions.dart';
import 'query_models.dart';
import 'query_complexity_analyzer.dart';

/// 查��结果路由器
class QueryResultRouter {
  final QueryComplexityAnalyzer _analyzer;

  QueryResultRouter({QueryComplexityAnalyzer? analyzer})
      : _analyzer = analyzer ?? QueryComplexityAnalyzer();

  /// 路由查询结果到合适的响应方式
  ///
  /// 根据复杂度评分选择：
  /// - Level 1: 纯语音响应
  /// - Level 2: 语音+轻量卡片
  /// - Level 3: 语音+交互图表
  Future<QueryResponse> route(
    QueryRequest request,
    QueryResult result,
  ) async {
    debugPrint('[QueryResultRouter] 开始路由查询结果');

    // 1. 计算复杂度
    final complexityScore = _analyzer.calculateComplexity(request);
    final level = _analyzer.determineLevel(complexityScore);

    // 2. 生成语音文本（所有层级都需要）
    final voiceText = _generateVoiceText(request, result, level);

    // 3. 根据层级生成额外数据
    QueryCardData? cardData;
    QueryChartData? chartData;

    switch (level) {
      case QueryLevel.simple:
        // 只有语音文本
        debugPrint('[QueryResultRouter] Level 1: 仅生成语音文本');
        break;

      case QueryLevel.medium:
        // 生成卡片数据
        debugPrint('[QueryResultRouter] Level 2: 生成语音文本+卡片数据');
        cardData = _buildCardData(request, result);
        break;

      case QueryLevel.complex:
        // 生成图表数据
        debugPrint('[QueryResultRouter] Level 3: 生成语音文本+图表数据');
        chartData = _buildChartData(request, result);
        break;
    }

    final response = QueryResponse(
      level: level,
      voiceText: voiceText,
      rawData: result,
      cardData: cardData,
      chartData: chartData,
      complexityScore: complexityScore,
    );

    debugPrint('[QueryResultRouter] 路由完成: $response');
    return response;
  }

  /// 生成语音文本
  String _generateVoiceText(
    QueryRequest request,
    QueryResult result,
    QueryLevel level,
  ) {
    // 根据查询类型和层级生成不同的文本
    switch (request.queryType) {
      case QueryType.summary:
      case QueryType.recent:
        return _generateSummaryText(result);

      case QueryType.trend:
        return _generateTrendText(result);

      case QueryType.distribution:
        return _generateDistributionText(result, request.limit);

      case QueryType.comparison:
        return _generateComparisonText(result);

      case QueryType.custom:
        return _generateCustomText(result);
    }
  }

  /// 生成总额统计文本
  String _generateSummaryText(QueryResult result) {
    final expense = result.totalExpense;
    final income = result.totalIncome;
    final count = result.transactionCount;
    final period = result.periodText;

    if (expense > 0 && income > 0) {
      return '$period您花费了${expense.toStringAsFixed(0)}元，收入${income.toStringAsFixed(0)}元';
    } else if (expense > 0) {
      if (count > 0) {
        return '$period您一共花费了${expense.toStringAsFixed(0)}元，共${count}笔';
      }
      return '$period您一共花费了${expense.toStringAsFixed(0)}元';
    } else if (income > 0) {
      return '$period您收入了${income.toStringAsFixed(0)}元';
    } else {
      return '$period暂无记账记录';
    }
  }

  /// 生成趋势分析文本
  String _generateTrendText(QueryResult result) {
    if (result.detailedData == null || result.detailedData!.isEmpty) {
      return _generateSummaryText(result);
    }

    final data = result.detailedData!;
    if (data.length < 2) {
      return _generateSummaryText(result);
    }

    // 计算趋势
    final firstValue = data.first.value;
    final lastValue = data.last.value;
    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final minValue = data.map((d) => d.value).reduce((a, b) => a < b ? a : b);

    final maxPoint = data.firstWhere((d) => d.value == maxValue);
    final minPoint = data.firstWhere((d) => d.value == minValue);

    String trend;
    if (lastValue > firstValue * 1.1) {
      trend = '整体在上升';
    } else if (lastValue < firstValue * 0.9) {
      trend = '整体在下降';
    } else {
      trend = '整体比较平稳';
    }

    return '$trend，${maxPoint.label}最高${maxValue.toStringAsFixed(0)}元，'
        '${minPoint.label}最低${minValue.toStringAsFixed(0)}元';
  }

  /// 生成分布文本
  String _generateDistributionText(QueryResult result, int? limit) {
    if (result.groupedData == null || result.groupedData!.isEmpty) {
      return _generateSummaryText(result);
    }

    final grouped = result.groupedData!;
    final total = grouped.values.reduce((a, b) => a + b);

    // 按金额排序
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 如果指定了limit=1，只返回最多的一项
    if (limit == 1 && sortedEntries.isNotEmpty) {
      final maxEntry = sortedEntries.first;
      final categoryName = getCategoryLocalizedName(maxEntry.key);
      final amount = maxEntry.value.toStringAsFixed(0);
      final percentage = (maxEntry.value / total * 100).toStringAsFixed(1);
      return '$categoryName最多，${amount}元，占${percentage}%';
    }

    // 根据分类数量和limit决定显示多少个
    int topCount;
    if (limit != null && limit > 0) {
      topCount = limit < sortedEntries.length ? limit : sortedEntries.length;
    } else {
      topCount = sortedEntries.length >= 5 ? 5 : sortedEntries.length;
    }
    final topEntries = sortedEntries.take(topCount).toList();

    // 如果只有1-2个分类，使用简单格式
    if (topEntries.length <= 2) {
      final maxEntry = topEntries.first;
      final maxPercentage = (maxEntry.value / total * 100).toStringAsFixed(1);
      final categoryName = getCategoryLocalizedName(maxEntry.key);
      return '$categoryName最多，占${maxPercentage}%，'
          '总计${total.toStringAsFixed(0)}元';
    }

    // 多个分类时，列出前几名
    final categoryList = topEntries.map((entry) {
      final categoryName = getCategoryLocalizedName(entry.key);
      final percentage = (entry.value / total * 100).toStringAsFixed(1);
      final amount = entry.value.toStringAsFixed(0);
      return '$categoryName${amount}元（${percentage}%）';
    }).join('，');

    return '总计${total.toStringAsFixed(0)}元，主要花费在：$categoryList';
  }

  /// 生成对比文本
  String _generateComparisonText(QueryResult result) {
    // TODO: 实现对比文本生成
    return _generateSummaryText(result);
  }

  /// 生成自定义查询文本
  String _generateCustomText(QueryResult result) {
    return _generateSummaryText(result);
  }

  /// 构建卡片数据
  QueryCardData? _buildCardData(QueryRequest request, QueryResult result) {
    // 根据查询类型构建不同的卡片
    switch (request.queryType) {
      case QueryType.summary:
        // 如果有预算信息，显示进度卡片
        // TODO: 从数据库获取预算信息
        return null;

      case QueryType.distribution:
        // 显示占比卡片
        if (result.groupedData != null && result.groupedData!.isNotEmpty) {
          final grouped = result.groupedData!;
          final total = grouped.values.reduce((a, b) => a + b);
          final maxEntry = grouped.entries.reduce((a, b) => a.value > b.value ? a : b);
          final percentage = maxEntry.value / total;

          return QueryCardData(
            primaryValue: maxEntry.value,
            percentage: percentage,
            cardType: CardType.percentage,
          );
        }
        return null;

      case QueryType.comparison:
        // 显示对比卡片
        // TODO: 实现对比卡片数据构建
        return null;

      default:
        return null;
    }
  }

  /// 构建图表数据
  QueryChartData? _buildChartData(QueryRequest request, QueryResult result) {
    // 根据查询类型构建不同的图表
    switch (request.queryType) {
      case QueryType.trend:
        // 折线图
        if (result.detailedData != null && result.detailedData!.isNotEmpty) {
          return QueryChartData(
            chartType: ChartType.line,
            dataPoints: result.detailedData!,
            xLabels: result.detailedData!.map((d) => d.label).toList(),
            yLabel: '金额（元）',
            title: '${result.periodText}消费趋势',
          );
        }
        return null;

      case QueryType.distribution:
        // 饼图
        if (result.groupedData != null && result.groupedData!.isNotEmpty) {
          final dataPoints = result.groupedData!.entries
              .map((e) => DataPoint(label: getCategoryLocalizedName(e.key), value: e.value))
              .toList();

          return QueryChartData(
            chartType: ChartType.pie,
            dataPoints: dataPoints,
            xLabels: dataPoints.map((d) => d.label).toList(),
            yLabel: '金额（元）',
            title: '${result.periodText}分类占比',
          );
        }
        return null;

      case QueryType.comparison:
        // 柱状图
        if (result.detailedData != null && result.detailedData!.isNotEmpty) {
          return QueryChartData(
            chartType: ChartType.bar,
            dataPoints: result.detailedData!,
            xLabels: result.detailedData!.map((d) => d.label).toList(),
            yLabel: '金额（元）',
            title: '${result.periodText}对比分析',
          );
        }
        return null;

      default:
        return null;
    }
  }
}
