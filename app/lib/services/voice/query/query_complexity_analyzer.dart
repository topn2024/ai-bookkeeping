/// 查询复杂度分析器
///
/// 根据查询请求的特征自动计算复杂度评分，并确定合适的响应层级
library;

import 'package:flutter/foundation.dart';
import 'query_models.dart';

/// 查询复杂度分析器
class QueryComplexityAnalyzer {
  /// 计算查询复杂度评分
  ///
  /// 评分规则：
  /// - 时间跨度：0-4分
  /// - 数据维度：0-3分
  /// - 数据点数：0-2分
  /// - 查询类型：0-3分
  ///
  /// 总分范围：0-12分
  int calculateComplexity(QueryRequest request) {
    int score = 0;

    // 1. 时间跨度评分
    score += _scoreTimeSpan(request.timeRange);

    // 2. 数据维度评分
    score += _scoreDimensions(request);

    // 3. 数据点数评分
    score += _scoreDataPoints(request);

    // 4. 查询类型评分
    score += _scoreQueryType(request.queryType);

    debugPrint('[QueryComplexityAnalyzer] 复杂度评分: $score '
        '(时间${_scoreTimeSpan(request.timeRange)} + '
        '维度${_scoreDimensions(request)} + '
        '数据点${_scoreDataPoints(request)} + '
        '类型${_scoreQueryType(request.queryType)})');

    return score;
  }

  /// 确定响应层级
  ///
  /// 评分规则：
  /// - 0分：Level 2（语音+卡片）- 即使是最简单的查询也应该有可视化
  /// - 1-4分：Level 2（语音+卡片）
  /// - 5分及以上：Level 3（语音+图表）
  QueryLevel determineLevel(int complexityScore) {
    // 所有查询至少提供Level 2（卡片数据），提升用户体验
    if (complexityScore <= 4) {
      debugPrint('[QueryComplexityAnalyzer] 判定为Level 2: 语音+轻量卡片');
      return QueryLevel.medium;
    }
    debugPrint('[QueryComplexityAnalyzer] 判定为Level 3: 语音+交互图表');
    return QueryLevel.complex;
  }

  /// 时间跨度评分
  ///
  /// 评分规则：
  /// - 单日（≤1天）：0分
  /// - 一周内（≤7天）：1分
  /// - 一月内（≤31天）：2分
  /// - 三月内（≤90天）：3分
  /// - 三月以上：4分
  int _scoreTimeSpan(TimeRange? timeRange) {
    if (timeRange == null) return 0;

    final days = timeRange.endDate.difference(timeRange.startDate).inDays;

    if (days <= 1) return 0; // 单日
    if (days <= 7) return 1; // 一周内
    if (days <= 31) return 2; // 一月内
    if (days <= 90) return 3; // 三月内
    return 4; // 三月以上
  }

  /// 数据维度评分
  ///
  /// 评分规则：
  /// - 0-1个维度：0分
  /// - 2个维度：1分
  /// - 3个及以上维度：3分
  ///
  /// 维度包括：
  /// - 分类筛选（category）
  /// - 来源筛选（source）
  /// - 账户筛选（account）
  /// - 分组维度（groupBy）
  int _scoreDimensions(QueryRequest request) {
    int dimensions = 0;

    if (request.category != null) dimensions++;
    if (request.source != null) dimensions++;
    if (request.account != null) dimensions++;
    if (request.groupBy != null && request.groupBy!.isNotEmpty) {
      dimensions += request.groupBy!.length;
    }

    if (dimensions == 0 || dimensions == 1) return 0;
    if (dimensions == 2) return 1;
    return 3; // 3个及以上维度
  }

  /// 数据点数评分
  ///
  /// 评分规则：
  /// - ≤2个数据点：0分
  /// - 3-4个数据点：1分
  /// - ≥5个数据点：2分
  ///
  /// 根据时间跨度和分组方式估算数据点数
  int _scoreDataPoints(QueryRequest request) {
    int estimatedPoints = 1;

    if (request.groupBy != null && request.groupBy!.isNotEmpty) {
      if (request.groupBy!.contains(GroupByDimension.date)) {
        // 按日期分组：数据点数 = 天数
        final days = request.timeRange?.endDate
                .difference(request.timeRange!.startDate)
                .inDays ??
            1;
        estimatedPoints = days;
      } else if (request.groupBy!.contains(GroupByDimension.month)) {
        // 按月份分组：数据点数 = 月数
        final startMonth = request.timeRange?.startDate.month ?? 1;
        final endMonth = request.timeRange?.endDate.month ?? 1;
        final startYear = request.timeRange?.startDate.year ?? 0;
        final endYear = request.timeRange?.endDate.year ?? 0;
        // 确保结果至少为1，防止时间范围无效时出现负数
        final monthDiff = (endYear - startYear) * 12 + (endMonth - startMonth) + 1;
        estimatedPoints = monthDiff > 0 ? monthDiff : 1;
      } else if (request.groupBy!.contains(GroupByDimension.category)) {
        // 按分类分组：假设7个分类
        estimatedPoints = 7;
      }
    }

    if (estimatedPoints <= 2) return 0;
    if (estimatedPoints <= 4) return 1;
    return 2; // 5个及以上数据点
  }

  /// 查询类型评分
  ///
  /// 评分规则：
  /// - summary（总额统计）：0分
  /// - recent（最近记录）：0分
  /// - comparison（对比分析）：1分
  /// - distribution（分布/占比）：2分
  /// - trend（趋势分析）：2分
  /// - custom（自定义查询）：3分
  int _scoreQueryType(QueryType queryType) {
    switch (queryType) {
      case QueryType.summary:
        return 0; // 简单统计
      case QueryType.recent:
        return 0; // 最近记录
      case QueryType.comparison:
        return 1; // 对比分析
      case QueryType.distribution:
        return 2; // 分布/占比
      case QueryType.trend:
        return 2; // 趋势分析
      case QueryType.custom:
        return 3; // 自定义查询
    }
  }
}
