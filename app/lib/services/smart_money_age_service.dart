import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/resource_pool.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'money_age_calculator.dart';
import 'money_age_level_service.dart';
import 'money_age_trend_service.dart';
import '../core/logger.dart';

/// 智能建议类型
enum SmartSuggestionType {
  /// 储蓄建议
  saving,

  /// 支出控制建议
  spending,

  /// 收入优化建议
  income,

  /// 习惯培养建议
  habit,

  /// 里程碑祝贺
  celebration,

  /// 风险预警
  warning,
}

extension SmartSuggestionTypeExtension on SmartSuggestionType {
  String get displayName {
    switch (this) {
      case SmartSuggestionType.saving:
        return '储蓄建议';
      case SmartSuggestionType.spending:
        return '支出控制';
      case SmartSuggestionType.income:
        return '收入优化';
      case SmartSuggestionType.habit:
        return '习惯培养';
      case SmartSuggestionType.celebration:
        return '里程碑';
      case SmartSuggestionType.warning:
        return '风险预警';
    }
  }

  String get icon {
    switch (this) {
      case SmartSuggestionType.saving:
        return '💰';
      case SmartSuggestionType.spending:
        return '🎯';
      case SmartSuggestionType.income:
        return '📈';
      case SmartSuggestionType.habit:
        return '🏃';
      case SmartSuggestionType.celebration:
        return '🎉';
      case SmartSuggestionType.warning:
        return '⚠️';
    }
  }
}

/// 智能建议优先级
enum SuggestionPriority {
  low,
  medium,
  high,
  critical,
}

/// 智能建议
class SmartSuggestion {
  /// 唯一ID
  final String id;

  /// 建议类型
  final SmartSuggestionType type;

  /// 优先级
  final SuggestionPriority priority;

  /// 标题
  final String title;

  /// 详细描述
  final String description;

  /// 预期影响（钱龄天数）
  final double? expectedImpact;

  /// 操作建议
  final String? actionText;

  /// 操作路由
  final String? actionRoute;

  /// 关联数据
  final Map<String, dynamic>? data;

  /// 生成时间
  final DateTime generatedAt;

  /// 过期时间
  final DateTime? expiresAt;

  /// 是否已读
  final bool isRead;

  /// 是否已采纳
  final bool isActioned;

  const SmartSuggestion({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    this.expectedImpact,
    this.actionText,
    this.actionRoute,
    this.data,
    required this.generatedAt,
    this.expiresAt,
    this.isRead = false,
    this.isActioned = false,
  });

  /// 是否已过期
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// 是否为紧急建议
  bool get isUrgent => priority == SuggestionPriority.critical;

  SmartSuggestion copyWith({
    bool? isRead,
    bool? isActioned,
  }) {
    return SmartSuggestion(
      id: id,
      type: type,
      priority: priority,
      title: title,
      description: description,
      expectedImpact: expectedImpact,
      actionText: actionText,
      actionRoute: actionRoute,
      data: data,
      generatedAt: generatedAt,
      expiresAt: expiresAt,
      isRead: isRead ?? this.isRead,
      isActioned: isActioned ?? this.isActioned,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'priority': priority.index,
      'title': title,
      'description': description,
      'expectedImpact': expectedImpact,
      'actionText': actionText,
      'actionRoute': actionRoute,
      'data': data?.toString(),
      'generatedAt': generatedAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'isRead': isRead ? 1 : 0,
      'isActioned': isActioned ? 1 : 0,
    };
  }

  factory SmartSuggestion.fromMap(Map<String, dynamic> map) {
    return SmartSuggestion(
      id: map['id'] as String,
      type: SmartSuggestionType.values[map['type'] as int],
      priority: SuggestionPriority.values[map['priority'] as int],
      title: map['title'] as String,
      description: map['description'] as String,
      expectedImpact: (map['expectedImpact'] as num?)?.toDouble(),
      actionText: map['actionText'] as String?,
      actionRoute: map['actionRoute'] as String?,
      data: null, // TODO: Parse from string if needed
      generatedAt: DateTime.fromMillisecondsSinceEpoch(map['generatedAt'] as int),
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int)
          : null,
      isRead: map['isRead'] == 1,
      isActioned: map['isActioned'] == 1,
    );
  }
}

/// 钱龄预测结果
class MoneyAgeForcast {
  /// 预测日期
  final DateTime targetDate;

  /// 预测钱龄
  final int predictedAge;

  /// 预测等级
  final MoneyAgeLevel predictedLevel;

  /// 置信度（0-1）
  final double confidence;

  /// 最佳情况预测
  final int bestCaseAge;

  /// 最差情况预测
  final int worstCaseAge;

  /// 影响因素
  final List<String> influenceFactors;

  const MoneyAgeForcast({
    required this.targetDate,
    required this.predictedAge,
    required this.predictedLevel,
    required this.confidence,
    required this.bestCaseAge,
    required this.worstCaseAge,
    this.influenceFactors = const [],
  });

  /// 预测范围描述
  String get rangeDescription => '$worstCaseAge - $bestCaseAge 天';
}

/// 目标达成分析
class GoalAnalysis {
  /// 目标钱龄
  final int targetAge;

  /// 当前钱龄
  final int currentAge;

  /// 预计达成日期
  final DateTime? estimatedDate;

  /// 达成概率
  final double probability;

  /// 需要的行动
  final List<String> requiredActions;

  /// 是否可达成
  final bool isAchievable;

  const GoalAnalysis({
    required this.targetAge,
    required this.currentAge,
    this.estimatedDate,
    required this.probability,
    this.requiredActions = const [],
    required this.isAchievable,
  });

  /// 差距天数
  int get gap => targetAge - currentAge;

  /// 是否已达成
  bool get isAlreadyAchieved => currentAge >= targetAge;
}

/// SmartMoneyAge 钱龄预测与建议服务
///
/// 功能：
/// 1. 智能分析用户的财务习惯
/// 2. 预测未来钱龄变化
/// 3. 生成个性化改善建议
/// 4. 目标达成预测
/// 5. 风险预警
class SmartMoneyAgeService {
  final DatabaseService _db;
  final MoneyAgeLevelService _levelService;
  final MoneyAgeTrendService _trendService;
  final Logger _logger = Logger();

  /// 缓存的建议列表
  List<SmartSuggestion> _cachedSuggestions = [];

  /// 上次生成建议的时间
  DateTime? _lastSuggestionGeneratedAt;

  /// 建议缓存有效期（小时）
  static const int suggestionCacheHours = 6;

  SmartMoneyAgeService({
    DatabaseService? database,
    MoneyAgeLevelService? levelService,
    MoneyAgeTrendService? trendService,
  })  : _db = database ?? DatabaseService(),
        _levelService = levelService ?? MoneyAgeLevelService(),
        _trendService = trendService ?? MoneyAgeTrendService();

  /// 获取智能建议
  ///
  /// [forceRefresh] 是否强制刷新（忽略缓存）
  Future<List<SmartSuggestion>> getSuggestions({
    bool forceRefresh = false,
    String? ledgerId,
  }) async {
    // 检查缓存
    if (!forceRefresh && _isCacheValid()) {
      return _cachedSuggestions;
    }

    try {
      final suggestions = await _generateSuggestions(ledgerId: ledgerId);

      _cachedSuggestions = suggestions;
      _lastSuggestionGeneratedAt = DateTime.now();

      // 持久化建议
      await _saveSuggestions(suggestions);

      return suggestions;
    } catch (e) {
      _logger.error('Failed to generate suggestions: $e', tag: 'SmartMoneyAge');
      // 返回缓存的建议
      return _cachedSuggestions;
    }
  }

  /// 生成智能建议
  Future<List<SmartSuggestion>> _generateSuggestions({
    String? ledgerId,
  }) async {
    final suggestions = <SmartSuggestion>[];

    // 获取当前状态
    final currentStats = await _getCurrentStats(ledgerId: ledgerId);
    if (currentStats == null) return suggestions;

    final currentAge = currentStats.averageAge;
    final level = _levelService.determineLevel(currentAge);
    final trend = await _trendService.analyzeTrend(
      days: 30,
      ledgerId: ledgerId,
    );

    // 1. 基于当前等级的建议
    suggestions.addAll(await _generateLevelBasedSuggestions(currentAge, level));

    // 2. 基于趋势的建议
    suggestions.addAll(_generateTrendBasedSuggestions(trend));

    // 3. 基于消费习惯的建议
    suggestions.addAll(await _generateHabitBasedSuggestions(ledgerId: ledgerId));

    // 4. 里程碑祝贺
    suggestions.addAll(await _generateMilestoneCelebrations(currentAge));

    // 5. 风险预警
    suggestions.addAll(await _generateRiskWarnings(currentAge, trend));

    // 按优先级排序
    suggestions.sort((a, b) => b.priority.index.compareTo(a.priority.index));

    return suggestions;
  }

  /// 基于等级生成建议
  Future<List<SmartSuggestion>> _generateLevelBasedSuggestions(
    int currentAge,
    MoneyAgeLevel level,
  ) async {
    final suggestions = <SmartSuggestion>[];
    final now = DateTime.now();

    switch (level) {
      case MoneyAgeLevel.danger:
        suggestions.add(SmartSuggestion(
          id: 'danger_saving_${now.millisecondsSinceEpoch}',
          type: SmartSuggestionType.warning,
          priority: SuggestionPriority.critical,
          title: '紧急：钱龄过低',
          description: '您目前的钱龄仅有 $currentAge 天，处于危险区域。建议立即减少非必要支出，建立应急储备。',
          expectedImpact: 7,
          actionText: '查看建议',
          actionRoute: '/money-age/suggestions',
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 3)),
        ));
        break;

      case MoneyAgeLevel.warning:
        suggestions.add(SmartSuggestion(
          id: 'warning_improve_${now.millisecondsSinceEpoch}',
          type: SmartSuggestionType.saving,
          priority: SuggestionPriority.high,
          title: '钱龄偏低，建议增加储蓄',
          description: '当前钱龄 $currentAge 天，距离健康水平还差 ${14 - currentAge} 天。每天节省一点，很快就能改善。',
          expectedImpact: 14 - currentAge.toDouble(),
          actionText: '设置储蓄目标',
          actionRoute: '/savings-goal/create',
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 7)),
        ));
        break;

      case MoneyAgeLevel.normal:
        suggestions.add(SmartSuggestion(
          id: 'normal_maintain_${now.millisecondsSinceEpoch}',
          type: SmartSuggestionType.habit,
          priority: SuggestionPriority.medium,
          title: '保持当前节奏',
          description: '您的财务状况正在改善，当前钱龄 $currentAge 天。继续保持这个势头，向30天目标前进！',
          expectedImpact: 30 - currentAge.toDouble(),
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 14)),
        ));
        break;

      case MoneyAgeLevel.good:
      case MoneyAgeLevel.excellent:
      case MoneyAgeLevel.ideal:
        // 高等级不需要紧急建议
        break;
    }

    return suggestions;
  }

  /// 基于趋势生成建议
  List<SmartSuggestion> _generateTrendBasedSuggestions(TrendAnalysis trend) {
    final suggestions = <SmartSuggestion>[];
    final now = DateTime.now();

    if (trend.direction == TrendDirection.down &&
        trend.strength > 0.5) {
      suggestions.add(SmartSuggestion(
        id: 'trend_down_${now.millisecondsSinceEpoch}',
        type: SmartSuggestionType.warning,
        priority: SuggestionPriority.high,
        title: '钱龄下降趋势',
        description: '最近30天钱龄下降了约 ${trend.changeAmount.abs().toStringAsFixed(1)} 天。${trend.description}',
        expectedImpact: trend.changeAmount.abs(),
        actionText: '查看分析',
        actionRoute: '/money-age/trend',
        generatedAt: now,
        expiresAt: now.add(const Duration(days: 7)),
      ));
    }

    if (trend.direction == TrendDirection.up &&
        trend.strength > 0.3) {
      suggestions.add(SmartSuggestion(
        id: 'trend_up_${now.millisecondsSinceEpoch}',
        type: SmartSuggestionType.celebration,
        priority: SuggestionPriority.low,
        title: '钱龄持续上升！',
        description: '最近30天钱龄提升了 ${trend.changeAmount.toStringAsFixed(1)} 天，做得很棒！',
        generatedAt: now,
        expiresAt: now.add(const Duration(days: 14)),
      ));
    }

    return suggestions;
  }

  /// 基于消费习惯生成建议
  Future<List<SmartSuggestion>> _generateHabitBasedSuggestions({
    String? ledgerId,
  }) async {
    final suggestions = <SmartSuggestion>[];
    final now = DateTime.now();

    try {
      // 分析消费模式
      final spendingPatterns = await _analyzeSpendingPatterns(ledgerId: ledgerId);

      // 检查周末支出是否偏高
      if (spendingPatterns['weekendRatio'] != null &&
          spendingPatterns['weekendRatio'] > 1.5) {
        suggestions.add(SmartSuggestion(
          id: 'weekend_spending_${now.millisecondsSinceEpoch}',
          type: SmartSuggestionType.spending,
          priority: SuggestionPriority.medium,
          title: '周末支出偏高',
          description: '您的周末支出是工作日的 ${spendingPatterns['weekendRatio'].toStringAsFixed(1)} 倍。考虑周末也保持理性消费。',
          expectedImpact: 3,
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 7)),
        ));
      }

      // 检查是否有规律的大额支出
      if (spendingPatterns['hasLargeRecurring'] == true) {
        suggestions.add(SmartSuggestion(
          id: 'large_recurring_${now.millisecondsSinceEpoch}',
          type: SmartSuggestionType.spending,
          priority: SuggestionPriority.medium,
          title: '发现大额周期性支出',
          description: '您有规律的大额支出，建议提前预留资金，避免影响钱龄。',
          expectedImpact: 5,
          actionText: '查看详情',
          actionRoute: '/transactions/analysis',
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 30)),
        ));
      }
    } catch (e) {
      _logger.warning('Failed to analyze spending patterns: $e', tag: 'SmartMoneyAge');
    }

    return suggestions;
  }

  /// 生成里程碑祝贺
  Future<List<SmartSuggestion>> _generateMilestoneCelebrations(
    int currentAge,
  ) async {
    final suggestions = <SmartSuggestion>[];
    final now = DateTime.now();

    // 检查是否刚达到某个里程碑
    final milestones = [7, 14, 30, 60, 90];
    for (final milestone in milestones) {
      final recentlyAchieved = await _checkRecentMilestoneAchievement(
        milestone,
        currentAge,
      );

      if (recentlyAchieved) {
        suggestions.add(SmartSuggestion(
          id: 'milestone_$milestone\_${now.millisecondsSinceEpoch}',
          type: SmartSuggestionType.celebration,
          priority: SuggestionPriority.low,
          title: '🎉 恭喜达成 $milestone 天钱龄！',
          description: _getMilestoneMessage(milestone),
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 7)),
        ));
        break; // 只显示一个里程碑
      }
    }

    return suggestions;
  }

  String _getMilestoneMessage(int milestone) {
    switch (milestone) {
      case 7:
        return '您已走出月光族！继续保持，下一个目标是14天。';
      case 14:
        return '您的财务状况已经稳定，继续向30天目标前进！';
      case 30:
        return '太棒了！一个月的资金缓冲，意味着您可以从容应对意外。';
      case 60:
        return '您的财务状况非常健康，两个月的储备让您高枕无忧。';
      case 90:
        return '恭喜达到理想状态！三个月储备，财务自由指日可待。';
      default:
        return '继续保持良好的财务习惯！';
    }
  }

  /// 生成风险预警
  Future<List<SmartSuggestion>> _generateRiskWarnings(
    int currentAge,
    TrendAnalysis trend,
  ) async {
    final suggestions = <SmartSuggestion>[];
    final now = DateTime.now();

    // 如果趋势急剧下降
    if (trend.direction == TrendDirection.down &&
        trend.changeAmount.abs() > 5) {
      suggestions.add(SmartSuggestion(
        id: 'risk_rapid_decline_${now.millisecondsSinceEpoch}',
        type: SmartSuggestionType.warning,
        priority: SuggestionPriority.critical,
        title: '⚠️ 钱龄急剧下降',
        description: '您的钱龄在过去一段时间下降了 ${trend.changeAmount.abs().toStringAsFixed(0)} 天，请注意控制支出。',
        actionText: '查看原因',
        actionRoute: '/money-age/analysis',
        generatedAt: now,
        expiresAt: now.add(const Duration(days: 3)),
      ));
    }

    // 如果即将跌破警戒线
    if (currentAge < 10 && currentAge > 7) {
      final predictions = await _trendService.predictFuture(
        daysAhead: 7,
      );

      if (predictions.isNotEmpty &&
          predictions.last.predictedAge < 7) {
        suggestions.add(SmartSuggestion(
          id: 'risk_approaching_danger_${now.millisecondsSinceEpoch}',
          type: SmartSuggestionType.warning,
          priority: SuggestionPriority.high,
          title: '即将进入危险区',
          description: '按当前趋势，您的钱龄将在一周内跌破7天警戒线。建议立即控制支出。',
          expectedImpact: currentAge - 7.0,
          actionText: '查看建议',
          actionRoute: '/money-age/suggestions',
          generatedAt: now,
          expiresAt: now.add(const Duration(days: 3)),
        ));
      }
    }

    return suggestions;
  }

  /// 预测未来钱龄
  Future<MoneyAgeForcast> predictFutureAge({
    required int daysAhead,
    String? ledgerId,
  }) async {
    try {
      final predictions = await _trendService.predictFuture(
        daysAhead: daysAhead,
        ledgerId: ledgerId,
      );

      if (predictions.isEmpty) {
        return MoneyAgeForcast(
          targetDate: DateTime.now().add(Duration(days: daysAhead)),
          predictedAge: 0,
          predictedLevel: MoneyAgeLevel.danger,
          confidence: 0,
          bestCaseAge: 0,
          worstCaseAge: 0,
        );
      }

      final targetPrediction = predictions.last;
      final confidenceAdjustment = 1 - (daysAhead / 90).clamp(0, 0.5);

      // 计算最佳和最差情况
      final variance = 5 + daysAhead ~/ 10;
      final bestCase = targetPrediction.predictedAge + variance;
      final worstCase = (targetPrediction.predictedAge - variance).clamp(0, 365);

      return MoneyAgeForcast(
        targetDate: targetPrediction.date,
        predictedAge: targetPrediction.predictedAge,
        predictedLevel: targetPrediction.predictedLevel,
        confidence: targetPrediction.confidence * confidenceAdjustment,
        bestCaseAge: bestCase,
        worstCaseAge: worstCase,
        influenceFactors: targetPrediction.factors.map((f) => f.name).toList(),
      );
    } catch (e) {
      _logger.error('Failed to predict future age: $e', tag: 'SmartMoneyAge');
      return MoneyAgeForcast(
        targetDate: DateTime.now().add(Duration(days: daysAhead)),
        predictedAge: 0,
        predictedLevel: MoneyAgeLevel.danger,
        confidence: 0,
        bestCaseAge: 0,
        worstCaseAge: 0,
      );
    }
  }

  /// 分析目标达成可能性
  Future<GoalAnalysis> analyzeGoalAchievement({
    required int targetAge,
    String? ledgerId,
  }) async {
    try {
      final stats = await _getCurrentStats(ledgerId: ledgerId);
      if (stats == null) {
        return GoalAnalysis(
          targetAge: targetAge,
          currentAge: 0,
          probability: 0,
          isAchievable: false,
        );
      }

      final currentAge = stats.averageAge;

      // 已达成
      if (currentAge >= targetAge) {
        return GoalAnalysis(
          targetAge: targetAge,
          currentAge: currentAge,
          estimatedDate: DateTime.now(),
          probability: 1.0,
          isAchievable: true,
        );
      }

      // 分析趋势
      final trend = await _trendService.analyzeTrend(
        days: 30,
        ledgerId: ledgerId,
      );

      // 计算达成时间
      final gap = targetAge - currentAge;
      int? estimatedDays;
      double probability;

      if (trend.direction == TrendDirection.up && trend.strength > 0) {
        // 上升趋势
        final dailyGrowth = trend.changeAmount / 30;
        estimatedDays = (gap / dailyGrowth).ceil();
        probability = (0.7 + trend.strength * 0.3).clamp(0, 1);
      } else if (trend.direction == TrendDirection.stable) {
        // 稳定趋势
        probability = 0.3;
        estimatedDays = null;
      } else {
        // 下降趋势
        probability = 0.1;
        estimatedDays = null;
      }

      // 生成需要的行动
      final actions = <String>[];
      if (gap > 30) {
        actions.add('设置每月储蓄目标');
        actions.add('减少非必要支出');
      }
      if (gap > 60) {
        actions.add('增加收入来源');
        actions.add('建立自动储蓄计划');
      }

      return GoalAnalysis(
        targetAge: targetAge,
        currentAge: currentAge,
        estimatedDate: estimatedDays != null
            ? DateTime.now().add(Duration(days: estimatedDays))
            : null,
        probability: probability,
        requiredActions: actions,
        isAchievable: probability > 0.3,
      );
    } catch (e) {
      _logger.error('Failed to analyze goal: $e', tag: 'SmartMoneyAge');
      return GoalAnalysis(
        targetAge: targetAge,
        currentAge: 0,
        probability: 0,
        isAchievable: false,
      );
    }
  }

  /// 标记建议为已读
  Future<void> markSuggestionAsRead(String suggestionId) async {
    final index = _cachedSuggestions.indexWhere((s) => s.id == suggestionId);
    if (index != -1) {
      _cachedSuggestions[index] =
          _cachedSuggestions[index].copyWith(isRead: true);
      await _updateSuggestion(_cachedSuggestions[index]);
    }
  }

  /// 标记建议为已采纳
  Future<void> markSuggestionAsActioned(String suggestionId) async {
    final index = _cachedSuggestions.indexWhere((s) => s.id == suggestionId);
    if (index != -1) {
      _cachedSuggestions[index] =
          _cachedSuggestions[index].copyWith(isActioned: true);
      await _updateSuggestion(_cachedSuggestions[index]);
    }
  }

  // ========== 私有辅助方法 ==========

  bool _isCacheValid() {
    if (_lastSuggestionGeneratedAt == null) return false;
    final elapsed = DateTime.now().difference(_lastSuggestionGeneratedAt!);
    return elapsed.inHours < suggestionCacheHours;
  }

  Future<MoneyAgeStatistics?> _getCurrentStats({String? ledgerId}) async {
    try {
      // TODO: 从 provider 或数据库获取实际数据
      return MoneyAgeStatistics(
        averageAge: 25,
        trend: const [],
        ageByCategory: const {},
        ageByAccount: const {},
        totalResourcePoolBalance: 10000,
        activePoolCount: 5,
        calculatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _analyzeSpendingPatterns({
    String? ledgerId,
  }) async {
    try {
      final db = await _db.database;

      // 分析周末vs工作日支出
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final results = await db.rawQuery('''
        SELECT
          strftime('%w', date/1000, 'unixepoch') as dayOfWeek,
          SUM(amount) as total
        FROM transactions
        WHERE type = ? AND date >= ?
        GROUP BY dayOfWeek
      ''', [TransactionType.expense.index, thirtyDaysAgo.millisecondsSinceEpoch]);

      double weekdayTotal = 0;
      double weekendTotal = 0;
      int weekdayCount = 0;
      int weekendCount = 0;

      for (final row in results) {
        final day = int.parse(row['dayOfWeek'] as String);
        final total = (row['total'] as num?)?.toDouble() ?? 0;

        if (day == 0 || day == 6) {
          weekendTotal += total;
          weekendCount++;
        } else {
          weekdayTotal += total;
          weekdayCount++;
        }
      }

      final weekdayAvg = weekdayCount > 0 ? weekdayTotal / weekdayCount : 0;
      final weekendAvg = weekendCount > 0 ? weekendTotal / weekendCount : 0;
      final weekendRatio = weekdayAvg > 0 ? weekendAvg / weekdayAvg : 1;

      return {
        'weekendRatio': weekendRatio,
        'hasLargeRecurring': false, // TODO: 实现大额周期性支出检测
      };
    } catch (e) {
      return {};
    }
  }

  Future<bool> _checkRecentMilestoneAchievement(
    int milestone,
    int currentAge,
  ) async {
    if (currentAge < milestone) return false;
    if (currentAge > milestone + 3) return false;

    // 检查是否在最近3天内刚达到这个里程碑
    // TODO: 实现历史数据检查
    return currentAge == milestone;
  }

  Future<void> _saveSuggestions(List<SmartSuggestion> suggestions) async {
    try {
      final db = await _db.database;

      // 清除旧建议
      await db.delete(
        'smart_suggestions',
        where: 'expiresAt < ?',
        whereArgs: [DateTime.now().millisecondsSinceEpoch],
      );

      // 保存新建议
      for (final suggestion in suggestions) {
        await db.insert(
          'smart_suggestions',
          suggestion.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      _logger.warning('Failed to save suggestions: $e', tag: 'SmartMoneyAge');
    }
  }

  Future<void> _updateSuggestion(SmartSuggestion suggestion) async {
    try {
      final db = await _db.database;
      await db.update(
        'smart_suggestions',
        suggestion.toMap(),
        where: 'id = ?',
        whereArgs: [suggestion.id],
      );
    } catch (e) {
      _logger.warning('Failed to update suggestion: $e', tag: 'SmartMoneyAge');
    }
  }
}
