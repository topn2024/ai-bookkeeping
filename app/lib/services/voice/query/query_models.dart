/// 查询相关的数据模型
///
/// 包含查询请求、查询响应、查询结果等核心数据结构
library;

import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════
// 查询类型枚举
// ═══════════════════════════════════════════════════════════════

/// 查询类型
enum QueryType {
  /// 总额统计
  summary,

  /// 最近记录
  recent,

  /// 趋势分析
  trend,

  /// 分布/占比
  distribution,

  /// 对比分析
  comparison,

  /// 自定义查询
  custom,
}

/// 聚合类型
enum AggregationType {
  /// 求和
  sum,

  /// 平均值
  avg,

  /// 计数
  count,

  /// 最大值
  max,

  /// 最小值
  min,
}

/// 分组维度
enum GroupByDimension {
  /// 按分类
  category,

  /// 按日期
  date,

  /// 按月份
  month,

  /// 按来源
  source,

  /// 按账户
  account,
}

/// 查询层级
enum QueryLevel {
  /// Level 1: 纯语音响应
  simple,

  /// Level 2: 语音+轻量卡片
  medium,

  /// Level 3: 语音+交互图表
  complex,
}

/// 卡片类型
enum CardType {
  /// 进度条
  progress,

  /// 占比
  percentage,

  /// 对比
  comparison,
}

/// 图表类型
enum ChartType {
  /// 折线图（趋势）
  line,

  /// 柱状图（对比）
  bar,

  /// 饼图（占比）
  pie,
}

// ═══════════════════════════════════════════════════════════════
// 查询请求
// ═══════════════════════════════════════════════════════════════

/// 时间范围
class TimeRange {
  final DateTime startDate;
  final DateTime endDate;
  final String periodText;

  const TimeRange({
    required this.startDate,
    required this.endDate,
    required this.periodText,
  });

  @override
  String toString() => 'TimeRange($periodText: $startDate - $endDate)';
}

/// 查询请求
class QueryRequest {
  /// 查询类型
  final QueryType queryType;

  /// 时间范围
  final TimeRange? timeRange;

  /// 分类筛选
  final String? category;

  /// 来源筛选
  final String? source;

  /// 账户筛选
  final String? account;

  /// 交易类型筛选
  final String? transactionType;

  /// 聚合类型
  final AggregationType? aggregationType;

  /// 分组维度
  final List<GroupByDimension>? groupBy;

  /// 排序方式
  final String? sortOrder;

  /// 数据点限制
  final int? limit;

  const QueryRequest({
    required this.queryType,
    this.timeRange,
    this.category,
    this.source,
    this.account,
    this.transactionType,
    this.aggregationType,
    this.groupBy,
    this.sortOrder,
    this.limit,
  });

  @override
  String toString() {
    return 'QueryRequest('
        'type: $queryType, '
        'timeRange: ${timeRange?.periodText}, '
        'category: $category, '
        'source: $source, '
        'groupBy: $groupBy'
        ')';
  }
}

// ═══════════════════════════════════════════════════════════════
// 查询结果
// ═══════════════════════════════════════════════════════════════

/// 数据点
class DataPoint {
  final String label;
  final double value;
  final DateTime? timestamp;
  final String? category;

  const DataPoint({
    required this.label,
    required this.value,
    this.timestamp,
    this.category,
  });

  @override
  String toString() => 'DataPoint($label: $value)';
}

/// 对比数据
class ComparisonData {
  final double currentValue;
  final double previousValue;
  final double changePercentage;
  final bool isIncrease;

  const ComparisonData({
    required this.currentValue,
    required this.previousValue,
    required this.changePercentage,
    required this.isIncrease,
  });

  @override
  String toString() {
    final direction = isIncrease ? '↑' : '↓';
    return 'ComparisonData($currentValue vs $previousValue, $direction ${changePercentage.abs()}%)';
  }
}

/// 查询结果
class QueryResult {
  /// 总支出
  final double totalExpense;

  /// 总收入
  final double totalIncome;

  /// 交易笔数
  final int transactionCount;

  /// 时间段描述
  final String periodText;

  /// 详细数据（用于图表）
  final List<DataPoint>? detailedData;

  /// 分组数据（用于分类统计）
  final Map<String, double>? groupedData;

  const QueryResult({
    required this.totalExpense,
    required this.totalIncome,
    required this.transactionCount,
    required this.periodText,
    this.detailedData,
    this.groupedData,
  });

  /// 余额
  double get balance => totalIncome - totalExpense;

  @override
  String toString() {
    return 'QueryResult('
        'expense: $totalExpense, '
        'income: $totalIncome, '
        'count: $transactionCount, '
        'period: $periodText'
        ')';
  }
}

// ═══════════════════════════════════════════════════════════════
// 查询响应
// ═══════════════════════════════════════════════════════════════

/// 查询卡片数据
class QueryCardData {
  /// 主要数值
  final double primaryValue;

  /// 次要数值（可选）
  final double? secondaryValue;

  /// 进度百分比（0-1）
  final double? progress;

  /// 占比百分比（0-1）
  final double? percentage;

  /// 对比数据（环比、同比）
  final ComparisonData? comparison;

  /// 卡片类型
  final CardType cardType;

  const QueryCardData({
    required this.primaryValue,
    this.secondaryValue,
    this.progress,
    this.percentage,
    this.comparison,
    required this.cardType,
  });

  @override
  String toString() => 'QueryCardData(type: $cardType, value: $primaryValue)';
}

/// 查询图表数据
class QueryChartData {
  /// 图表类型
  final ChartType chartType;

  /// 数据点列表
  final List<DataPoint> dataPoints;

  /// X轴标签
  final List<String> xLabels;

  /// Y轴标签
  final String yLabel;

  /// 图表标题
  final String title;

  const QueryChartData({
    required this.chartType,
    required this.dataPoints,
    required this.xLabels,
    required this.yLabel,
    required this.title,
  });

  @override
  String toString() => 'QueryChartData(type: $chartType, points: ${dataPoints.length})';
}

/// 查询响应
class QueryResponse {
  /// 响应层级
  final QueryLevel level;

  /// 语音文本（所有层级都有）
  final String voiceText;

  /// 原始数据
  final QueryResult rawData;

  /// 卡片数据（Level 2）
  final QueryCardData? cardData;

  /// 图表数据（Level 3）
  final QueryChartData? chartData;

  /// 复杂度评分
  final int complexityScore;

  const QueryResponse({
    required this.level,
    required this.voiceText,
    required this.rawData,
    this.cardData,
    this.chartData,
    required this.complexityScore,
  });

  @override
  String toString() {
    return 'QueryResponse('
        'level: $level, '
        'score: $complexityScore, '
        'text: ${voiceText.substring(0, voiceText.length > 20 ? 20 : voiceText.length)}...'
        ')';
  }
}
