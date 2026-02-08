import 'dart:math' as math;

import 'package:collection/collection.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter/foundation.dart';

// ==================== 习惯学习数据模型 ====================

/// 习惯日志数据
class HabitLogData {
  final String logId;
  final String habitId;
  final String userId;
  final DateTime scheduledTime;
  final DateTime? completedTime;
  final bool completed;
  final int streakDays;
  final Map<String, dynamic> context;

  const HabitLogData({
    required this.logId,
    required this.habitId,
    required this.userId,
    required this.scheduledTime,
    this.completedTime,
    required this.completed,
    required this.streakDays,
    this.context = const {},
  });

  int get completionHour => completedTime?.hour ?? scheduledTime.hour;
  int get dayOfWeek => scheduledTime.weekday;
  bool get isWeekday => dayOfWeek >= 1 && dayOfWeek <= 5;

  Map<String, dynamic> toJson() => {
        'log_id': logId,
        'habit_id': habitId,
        'user_id': userId,
        'scheduled_time': scheduledTime.toIso8601String(),
        'completed_time': completedTime?.toIso8601String(),
        'completed': completed,
        'streak_days': streakDays,
        'context': context,
      };
}

/// 习惯完成模式
class HabitCompletionPattern {
  final double overallRate;
  final double weekdayRate;
  final double weekendRate;
  final double morningRate;
  final double afternoonRate;
  final double eveningRate;
  final TrendDirection recentTrend;
  final int longestStreak;
  final int currentStreak;
  final Map<int, double> hourlyDistribution;
  final Map<int, double> weekdayDistribution;

  const HabitCompletionPattern({
    required this.overallRate,
    required this.weekdayRate,
    required this.weekendRate,
    required this.morningRate,
    required this.afternoonRate,
    required this.eveningRate,
    required this.recentTrend,
    required this.longestStreak,
    required this.currentStreak,
    required this.hourlyDistribution,
    required this.weekdayDistribution,
  });
}

/// 趋势方向
enum TrendDirection {
  improving, // 改善中
  stable, // 稳定
  declining, // 下降中
}

/// 习惯预测结果
class HabitPrediction {
  final double successProbability;
  final TimeSlot bestTimeSlot;
  final List<RiskFactor> riskFactors;
  final List<String> suggestions;
  final double confidence;

  const HabitPrediction({
    required this.successProbability,
    required this.bestTimeSlot,
    required this.riskFactors,
    required this.suggestions,
    required this.confidence,
  });
}

/// 时间段
class TimeSlot {
  final int startHour;
  final int endHour;
  final String name;

  const TimeSlot({
    required this.startHour,
    required this.endHour,
    required this.name,
  });

  factory TimeSlot.fromHour(int hour) {
    if (hour >= 5 && hour < 9) {
      return const TimeSlot(startHour: 5, endHour: 9, name: '早晨');
    } else if (hour >= 9 && hour < 12) {
      return const TimeSlot(startHour: 9, endHour: 12, name: '上午');
    } else if (hour >= 12 && hour < 14) {
      return const TimeSlot(startHour: 12, endHour: 14, name: '午间');
    } else if (hour >= 14 && hour < 18) {
      return const TimeSlot(startHour: 14, endHour: 18, name: '下午');
    } else if (hour >= 18 && hour < 22) {
      return const TimeSlot(startHour: 18, endHour: 22, name: '晚间');
    } else {
      return const TimeSlot(startHour: 22, endHour: 5, name: '深夜');
    }
  }

  bool containsHour(int hour) {
    if (startHour < endHour) {
      return hour >= startHour && hour < endHour;
    } else {
      return hour >= startHour || hour < endHour;
    }
  }
}

/// 风险因素
class RiskFactor {
  final String name;
  final String description;
  final double severity;
  final String suggestion;

  const RiskFactor({
    required this.name,
    required this.description,
    required this.severity,
    required this.suggestion,
  });
}

/// 习惯规则
class HabitRule {
  final String ruleId;
  final String habitType;
  final double confidence;
  final HabitRuleSource source;
  final TimeSlot optimalTimeSlot;
  final Map<int, double> weekdaySuccess;
  final int minStreakForStability;
  final List<String> triggerContexts;
  final int sampleCount;

  HabitRule({
    required this.ruleId,
    required this.habitType,
    required this.confidence,
    required this.source,
    required this.optimalTimeSlot,
    required this.weekdaySuccess,
    required this.minStreakForStability,
    required this.triggerContexts,
    required this.sampleCount,
  });

  HabitRule copyWith({
    double? confidence,
    int? sampleCount,
  }) {
    return HabitRule(
      ruleId: ruleId,
      habitType: habitType,
      confidence: confidence ?? this.confidence,
      source: source,
      optimalTimeSlot: optimalTimeSlot,
      weekdaySuccess: weekdaySuccess,
      minStreakForStability: minStreakForStability,
      triggerContexts: triggerContexts,
      sampleCount: sampleCount ?? this.sampleCount,
    );
  }
}

/// 规则来源
enum HabitRuleSource {
  userLearned, // 从用户行为学习
  collaborative, // 协同学习
  systemDefault, // 系统默认
}

/// 学习阶段
enum HabitLearningStage {
  coldStart, // 冷启动（<7天）
  collecting, // 样本收集（7-21天）
  active, // 正常运行（>21天）
}

// ==================== 用户习惯画像 ====================

/// 用户习惯画像
class UserHabitProfile {
  final String userId;
  final Map<String, HabitCompletionPattern> habitPatterns;
  final Map<int, double> preferredHours;
  final Map<int, double> weekdayPreference;
  final double averageCompletionRate;
  final int totalHabitsTracked;
  final List<String> strengthAreas;
  final List<String> improvementAreas;
  final DateTime lastUpdated;

  UserHabitProfile({
    required this.userId,
    required this.habitPatterns,
    required this.preferredHours,
    required this.weekdayPreference,
    required this.averageCompletionRate,
    required this.totalHabitsTracked,
    required this.strengthAreas,
    required this.improvementAreas,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// 获取最佳执行时间
  TimeSlot getBestTimeSlot() {
    if (preferredHours.isEmpty) {
      return const TimeSlot(startHour: 8, endHour: 10, name: '早晨');
    }

    final bestHour = preferredHours.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return TimeSlot.fromHour(bestHour);
  }

  /// 获取最佳执行日
  int getBestWeekday() {
    if (weekdayPreference.isEmpty) return 1;

    return weekdayPreference.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

// ==================== 鼓励策略 ====================

/// 鼓励上下文
enum EncouragementContext {
  streakMilestone, // 连续达标里程碑
  almostGiveUp, // 即将放弃
  dailyReminder, // 日常提醒
  recovery, // 中断后恢复
  firstComplete, // 首次完成
  weeklyReview, // 周度回顾
}

/// 个性化鼓励
class PersonalizedEncouragement {
  final String message;
  final EncouragementContext context;
  final String? emoji;
  final Map<String, dynamic> metadata;

  const PersonalizedEncouragement({
    required this.message,
    required this.context,
    this.emoji,
    this.metadata = const {},
  });
}

// ==================== 协同学习数据 ====================

/// 习惯协同学习贡献
class HabitCollaborativeContribution {
  final String habitType;
  final Map<int, double> hourlySuccessRate;
  final Map<int, double> weekdaySuccessRate;
  final double overallSuccessRate;
  final int sampleCount;
  final List<String> effectiveStrategies;

  const HabitCollaborativeContribution({
    required this.habitType,
    required this.hourlySuccessRate,
    required this.weekdaySuccessRate,
    required this.overallSuccessRate,
    required this.sampleCount,
    required this.effectiveStrategies,
  });

  Map<String, dynamic> toJson() => {
        'habit_type': habitType,
        'hourly_success_rate': hourlySuccessRate.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
        'weekday_success_rate': weekdaySuccessRate.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
        'overall_success_rate': overallSuccessRate,
        'sample_count': sampleCount,
        'effective_strategies': effectiveStrategies,
      };
}

/// 协同学习洞察
class CollaborativeHabitInsight {
  final String habitType;
  final TimeSlot popularTimeSlot;
  final List<int> popularWeekdays;
  final double communitySuccessRate;
  final List<String> topStrategies;
  final String? benchmarkMessage;

  const CollaborativeHabitInsight({
    required this.habitType,
    required this.popularTimeSlot,
    required this.popularWeekdays,
    required this.communitySuccessRate,
    required this.topStrategies,
    this.benchmarkMessage,
  });
}

// ==================== 习惯学习服务 ====================

/// 习惯自学习服务
class HabitLearningService {
  final HabitDataStore _dataStore;
  final Map<String, UserHabitProfile> _profileCache = {};
  final List<HabitRule> _learnedRules = [];

  // 配置
  static const int _minLogsForLearning = 7;
  static const int _minLogsForActiveStage = 21;
  static const double _streakBonusMultiplier = 0.1;

  String get moduleId => 'habit_learning';
  HabitLearningStage stage = HabitLearningStage.coldStart;
  double accuracy = 0.0;

  HabitLearningService({
    HabitDataStore? dataStore,
  }) : _dataStore = dataStore ?? InMemoryHabitDataStore();

  /// 学习习惯数据
  Future<void> learn(HabitLogData data) async {
    await _dataStore.saveLog(data);

    // 更新用户画像
    await _updateUserProfile(data.userId);

    // 检查学习阶段
    final logCount = await _dataStore.getLogCount(userId: data.userId);
    if (logCount >= _minLogsForLearning &&
        stage == HabitLearningStage.coldStart) {
      stage = HabitLearningStage.collecting;
    }

    if (logCount >= _minLogsForActiveStage) {
      await _triggerRuleLearning(data.userId);
      stage = HabitLearningStage.active;
    }
  }

  /// 更新用户画像
  Future<void> _updateUserProfile(String userId) async {
    final logs = await _dataStore.getUserLogs(userId, days: 90);
    if (logs.isEmpty) return;

    // 按习惯分组分析
    final byHabit = groupBy(logs, (l) => l.habitId);
    final habitPatterns = <String, HabitCompletionPattern>{};

    for (final entry in byHabit.entries) {
      habitPatterns[entry.key] = _analyzeCompletionPattern(entry.value);
    }

    // 计算时间偏好
    final preferredHours = <int, double>{};
    final completedLogs = logs.where((l) => l.completed);
    for (final log in completedLogs) {
      final hour = log.completionHour;
      preferredHours[hour] = (preferredHours[hour] ?? 0) + 1;
    }
    _normalizeMap(preferredHours);

    // 计算星期偏好
    final weekdayPreference = <int, double>{};
    for (final log in completedLogs) {
      final day = log.dayOfWeek;
      weekdayPreference[day] = (weekdayPreference[day] ?? 0) + 1;
    }
    _normalizeMap(weekdayPreference);

    // 计算平均完成率
    final completedCount = logs.where((l) => l.completed).length;
    final avgRate = logs.isEmpty ? 0.0 : completedCount / logs.length;

    // 识别优势和改进领域
    final strengthAreas = <String>[];
    final improvementAreas = <String>[];

    for (final entry in habitPatterns.entries) {
      if (entry.value.overallRate >= 0.8) {
        strengthAreas.add(entry.key);
      } else if (entry.value.overallRate < 0.5) {
        improvementAreas.add(entry.key);
      }
    }

    _profileCache[userId] = UserHabitProfile(
      userId: userId,
      habitPatterns: habitPatterns,
      preferredHours: preferredHours,
      weekdayPreference: weekdayPreference,
      averageCompletionRate: avgRate,
      totalHabitsTracked: byHabit.keys.length,
      strengthAreas: strengthAreas,
      improvementAreas: improvementAreas,
    );
  }

  /// 分析完成模式
  HabitCompletionPattern _analyzeCompletionPattern(List<HabitLogData> logs) {
    if (logs.isEmpty) {
      return const HabitCompletionPattern(
        overallRate: 0,
        weekdayRate: 0,
        weekendRate: 0,
        morningRate: 0,
        afternoonRate: 0,
        eveningRate: 0,
        recentTrend: TrendDirection.stable,
        longestStreak: 0,
        currentStreak: 0,
        hourlyDistribution: {},
        weekdayDistribution: {},
      );
    }

    // 整体完成率
    final completedCount = logs.where((l) => l.completed).length;
    final overallRate = completedCount / logs.length;

    // 工作日/周末完成率
    final weekdayLogs = logs.where((l) => l.isWeekday);
    final weekendLogs = logs.where((l) => !l.isWeekday);
    final weekdayCompleted = weekdayLogs.where((l) => l.completed).length;
    final weekendCompleted = weekendLogs.where((l) => l.completed).length;
    final weekdayRate =
        weekdayLogs.isEmpty ? 0.0 : weekdayCompleted / weekdayLogs.length;
    final weekendRate =
        weekendLogs.isEmpty ? 0.0 : weekendCompleted / weekendLogs.length;

    // 时间段完成率
    final morningLogs =
        logs.where((l) => l.completionHour >= 5 && l.completionHour < 12);
    final afternoonLogs =
        logs.where((l) => l.completionHour >= 12 && l.completionHour < 18);
    final eveningLogs =
        logs.where((l) => l.completionHour >= 18 || l.completionHour < 5);

    final morningRate = morningLogs.isEmpty
        ? 0.0
        : morningLogs.where((l) => l.completed).length / morningLogs.length;
    final afternoonRate = afternoonLogs.isEmpty
        ? 0.0
        : afternoonLogs.where((l) => l.completed).length / afternoonLogs.length;
    final eveningRate = eveningLogs.isEmpty
        ? 0.0
        : eveningLogs.where((l) => l.completed).length / eveningLogs.length;

    // 小时分布
    final hourlyDistribution = <int, double>{};
    for (final log in logs.where((l) => l.completed)) {
      final hour = log.completionHour;
      hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
    }
    _normalizeMap(hourlyDistribution);

    // 星期分布
    final weekdayDistribution = <int, double>{};
    for (final log in logs.where((l) => l.completed)) {
      final day = log.dayOfWeek;
      weekdayDistribution[day] = (weekdayDistribution[day] ?? 0) + 1;
    }
    _normalizeMap(weekdayDistribution);

    // 趋势分析
    final recentTrend = _analyzeTrend(logs);

    // 连续记录
    final streaks = _calculateStreaks(logs);

    return HabitCompletionPattern(
      overallRate: overallRate,
      weekdayRate: weekdayRate,
      weekendRate: weekendRate,
      morningRate: morningRate,
      afternoonRate: afternoonRate,
      eveningRate: eveningRate,
      recentTrend: recentTrend,
      longestStreak: streaks['longest'] ?? 0,
      currentStreak: streaks['current'] ?? 0,
      hourlyDistribution: hourlyDistribution,
      weekdayDistribution: weekdayDistribution,
    );
  }

  TrendDirection _analyzeTrend(List<HabitLogData> logs) {
    if (logs.length < 14) return TrendDirection.stable;

    // 比较最近7天和之前7天的完成率
    final sorted = logs.toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

    final recent7 = sorted.take(7).toList();
    final previous7 = sorted.skip(7).take(7).toList();

    if (previous7.isEmpty) return TrendDirection.stable;

    final recentRate =
        recent7.where((l) => l.completed).length / recent7.length;
    final previousRate =
        previous7.where((l) => l.completed).length / previous7.length;

    final diff = recentRate - previousRate;
    if (diff > 0.1) return TrendDirection.improving;
    if (diff < -0.1) return TrendDirection.declining;
    return TrendDirection.stable;
  }

  Map<String, int> _calculateStreaks(List<HabitLogData> logs) {
    if (logs.isEmpty) return {'longest': 0, 'current': 0};

    final sorted = logs.toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    int longestStreak = 0;
    int currentStreak = 0;
    int tempStreak = 0;

    for (final log in sorted) {
      if (log.completed) {
        tempStreak++;
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
    }

    // 从最近开始计算当前连续
    for (final log in sorted.reversed) {
      if (log.completed) {
        currentStreak++;
      } else {
        break;
      }
    }

    return {'longest': longestStreak, 'current': currentStreak};
  }

  void _normalizeMap(Map<int, double> map) {
    if (map.isEmpty) return;
    final total = map.values.fold(0.0, (a, b) => a + b);
    if (total > 0) {
      for (final key in map.keys) {
        map[key] = map[key]! / total;
      }
    }
  }

  /// 触发规则学习
  Future<void> _triggerRuleLearning(String userId) async {
    final profile = _profileCache[userId];
    if (profile == null) return;

    _learnedRules.clear();

    for (final entry in profile.habitPatterns.entries) {
      final pattern = entry.value;

      // 找出最佳时间段
      final bestHour = pattern.hourlyDistribution.entries.isEmpty
          ? 8
          : pattern.hourlyDistribution.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;

      // 找出星期成功率
      final weekdaySuccess = <int, double>{};
      for (int i = 1; i <= 7; i++) {
        weekdaySuccess[i] = pattern.weekdayDistribution[i] ?? 0;
      }

      final rule = HabitRule(
        ruleId: '${userId}_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
        habitType: entry.key,
        confidence: _calculateRuleConfidence(pattern),
        source: HabitRuleSource.userLearned,
        optimalTimeSlot: TimeSlot.fromHour(bestHour),
        weekdaySuccess: weekdaySuccess,
        minStreakForStability: pattern.longestStreak > 21 ? 21 : 7,
        triggerContexts: [],
        sampleCount: pattern.currentStreak + pattern.longestStreak,
      );

      _learnedRules.add(rule);
    }

    debugPrint('Learned ${_learnedRules.length} habit rules for user: $userId');
  }

  double _calculateRuleConfidence(HabitCompletionPattern pattern) {
    double confidence = 0.5;

    // 基于完成率
    confidence += pattern.overallRate * 0.3;

    // 基于连续天数
    if (pattern.currentStreak >= 7) confidence += 0.1;
    if (pattern.currentStreak >= 21) confidence += 0.1;

    // 基于趋势
    if (pattern.recentTrend == TrendDirection.improving) {
      confidence += 0.05;
    } else if (pattern.recentTrend == TrendDirection.declining) {
      confidence -= 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// 预测习惯成功概率
  Future<HabitPrediction> predictHabitSuccess({
    required String userId,
    required String habitId,
    DateTime? targetTime,
  }) async {
    final profile = _profileCache[userId];
    final effectiveTime = targetTime ?? DateTime.now();

    if (profile == null || !profile.habitPatterns.containsKey(habitId)) {
      // 冷启动：返回默认预测
      return HabitPrediction(
        successProbability: 0.5,
        bestTimeSlot: const TimeSlot(startHour: 8, endHour: 10, name: '早晨'),
        riskFactors: [
          const RiskFactor(
            name: '数据不足',
            description: '还在学习您的习惯模式',
            severity: 0.3,
            suggestion: '继续记录，AI会越来越了解您',
          ),
        ],
        suggestions: ['建议在固定时间执行，更容易形成习惯'],
        confidence: 0.3,
      );
    }

    final pattern = profile.habitPatterns[habitId]!;

    // 计算基础概率
    double probability = pattern.overallRate;

    // 时间调整
    final hour = effectiveTime.hour;
    final hourBoost = pattern.hourlyDistribution[hour] ?? 0;
    probability = probability * 0.7 + hourBoost * 0.3;

    // 星期调整
    final weekday = effectiveTime.weekday;
    final weekdayBoost = pattern.weekdayDistribution[weekday] ?? 0;
    probability = probability * 0.8 + weekdayBoost * 0.2;

    // 连续天数加成
    if (pattern.currentStreak > 0) {
      probability += math.min(pattern.currentStreak * _streakBonusMultiplier, 0.2);
    }

    probability = probability.clamp(0.0, 1.0);

    // 识别风险因素
    final riskFactors = _identifyRiskFactors(pattern, effectiveTime);

    // 找出最佳时间
    final bestTimeSlot = profile.getBestTimeSlot();

    // 生成建议
    final suggestions = _generateSuggestions(pattern, riskFactors);

    return HabitPrediction(
      successProbability: probability,
      bestTimeSlot: bestTimeSlot,
      riskFactors: riskFactors,
      suggestions: suggestions,
      confidence: _calculateRuleConfidence(pattern),
    );
  }

  List<RiskFactor> _identifyRiskFactors(
    HabitCompletionPattern pattern,
    DateTime time,
  ) {
    final factors = <RiskFactor>[];

    // 周末风险
    if (time.weekday >= 6 && pattern.weekendRate < pattern.weekdayRate * 0.8) {
      factors.add(RiskFactor(
        name: '周末效应',
        description: '您在周末的完成率较低',
        severity: 0.6,
        suggestion: '提前设置周末提醒',
      ));
    }

    // 下降趋势风险
    if (pattern.recentTrend == TrendDirection.declining) {
      factors.add(const RiskFactor(
        name: '动力下降',
        description: '最近的完成率有所下降',
        severity: 0.7,
        suggestion: '考虑调整习惯难度或奖励机制',
      ));
    }

    // 连续中断风险
    if (pattern.currentStreak == 0 && pattern.longestStreak > 7) {
      factors.add(const RiskFactor(
        name: '连续中断',
        description: '之前的连续记录已中断',
        severity: 0.5,
        suggestion: '重新开始，每一天都是新的起点',
      ));
    }

    // 时间不匹配风险
    final currentHour = time.hour;
    final bestHourRate = pattern.hourlyDistribution.entries.isEmpty
        ? 0.0
        : pattern.hourlyDistribution.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .value;
    final currentHourRate = pattern.hourlyDistribution[currentHour] ?? 0;

    if (bestHourRate > 0 && currentHourRate < bestHourRate * 0.5) {
      factors.add(RiskFactor(
        name: '时间不佳',
        description: '当前时段不是您的最佳执行时间',
        severity: 0.4,
        suggestion: '考虑调整到您更活跃的时段',
      ));
    }

    return factors;
  }

  List<String> _generateSuggestions(
    HabitCompletionPattern pattern,
    List<RiskFactor> risks,
  ) {
    final suggestions = <String>[];

    // 基于趋势的建议
    if (pattern.recentTrend == TrendDirection.improving) {
      suggestions.add('保持当前节奏，您的习惯正在形成！');
    } else if (pattern.recentTrend == TrendDirection.declining) {
      suggestions.add('尝试降低难度，从小步骤开始');
    }

    // 基于连续天数
    if (pattern.currentStreak >= 7 && pattern.currentStreak < 21) {
      suggestions.add('再坚持${21 - pattern.currentStreak}天就能形成稳定习惯！');
    } else if (pattern.currentStreak >= 21) {
      suggestions.add('太棒了！习惯已基本养成，继续保持！');
    }

    // 基于时间偏好
    if (pattern.morningRate > pattern.eveningRate * 1.5) {
      suggestions.add('您在早晨执行效果更好，建议早起完成');
    } else if (pattern.eveningRate > pattern.morningRate * 1.5) {
      suggestions.add('您更适合在晚间执行，可以作为一天的收尾');
    }

    // 基于风险
    for (final risk in risks.where((r) => r.severity >= 0.6)) {
      suggestions.add(risk.suggestion);
    }

    return suggestions.take(3).toList();
  }

  /// 生成个性化鼓励
  Future<PersonalizedEncouragement> generateEncouragement({
    required String userId,
    required String habitId,
    required EncouragementContext context,
    int? currentStreak,
  }) async {
    final profile = _profileCache[userId];
    final pattern = profile?.habitPatterns[habitId];
    final streak = currentStreak ?? pattern?.currentStreak ?? 0;

    switch (context) {
      case EncouragementContext.streakMilestone:
        return _generateMilestoneEncouragement(streak);

      case EncouragementContext.almostGiveUp:
        return _generateMotivationalEncouragement(streak, pattern);

      case EncouragementContext.dailyReminder:
        return _generateReminderEncouragement(pattern);

      case EncouragementContext.recovery:
        return _generateRecoveryEncouragement(pattern);

      case EncouragementContext.firstComplete:
        return const PersonalizedEncouragement(
          message: '第一步迈出去了！万事开头难，你做到了！',
          context: EncouragementContext.firstComplete,
          emoji: '🎉',
        );

      case EncouragementContext.weeklyReview:
        return _generateWeeklyReviewEncouragement(pattern);
    }
  }

  PersonalizedEncouragement _generateMilestoneEncouragement(int streak) {
    final milestones = {
      7: ('🎉', '太棒了！坚持一周，养成习惯的关键期已过！'),
      14: ('🌟', '两周坚持！你正在建立强大的习惯回路！'),
      21: ('🏆', '了不起！21天，习惯已初步形成！'),
      30: ('💪', '一个月！这个习惯已成为你生活的一部分！'),
      66: ('💎', '66天！习惯已经成为你的本能反应！'),
      100: ('👑', '100天大满贯！你的坚持让你与众不同！'),
      365: ('🎖️', '整整一年！你是真正的习惯大师！'),
    };

    for (final entry in milestones.entries) {
      if (streak == entry.key) {
        return PersonalizedEncouragement(
          message: entry.value.$2,
          context: EncouragementContext.streakMilestone,
          emoji: entry.value.$1,
          metadata: {'streak': streak},
        );
      }
    }

    return PersonalizedEncouragement(
      message: '第$streak天打卡成功！继续保持！',
      context: EncouragementContext.streakMilestone,
      emoji: '✨',
      metadata: {'streak': streak},
    );
  }

  PersonalizedEncouragement _generateMotivationalEncouragement(
    int streak,
    HabitCompletionPattern? pattern,
  ) {
    if (pattern != null && pattern.longestStreak > streak) {
      return PersonalizedEncouragement(
        message: '你曾经连续坚持了${pattern.longestStreak}天，这次一定可以超越！',
        context: EncouragementContext.almostGiveUp,
        emoji: '💪',
      );
    }

    return const PersonalizedEncouragement(
      message: '每一次坚持都是在投资未来的自己，不要放弃！',
      context: EncouragementContext.almostGiveUp,
      emoji: '🌈',
    );
  }

  PersonalizedEncouragement _generateReminderEncouragement(
    HabitCompletionPattern? pattern,
  ) {
    if (pattern != null && pattern.currentStreak > 0) {
      return PersonalizedEncouragement(
        message: '已连续${pattern.currentStreak}天，今天继续保持！',
        context: EncouragementContext.dailyReminder,
        emoji: '⏰',
      );
    }

    return const PersonalizedEncouragement(
      message: '新的一天，新的开始！',
      context: EncouragementContext.dailyReminder,
      emoji: '🌅',
    );
  }

  PersonalizedEncouragement _generateRecoveryEncouragement(
    HabitCompletionPattern? pattern,
  ) {
    return const PersonalizedEncouragement(
      message: '中断不是失败，重新开始才是真正的勇气！',
      context: EncouragementContext.recovery,
      emoji: '🔄',
    );
  }

  PersonalizedEncouragement _generateWeeklyReviewEncouragement(
    HabitCompletionPattern? pattern,
  ) {
    if (pattern == null) {
      return const PersonalizedEncouragement(
        message: '本周辛苦了！继续加油！',
        context: EncouragementContext.weeklyReview,
        emoji: '📊',
      );
    }

    final ratePercent = (pattern.overallRate * 100).toStringAsFixed(0);

    if (pattern.overallRate >= 0.8) {
      return PersonalizedEncouragement(
        message: '本周完成率$ratePercent%，表现优秀！',
        context: EncouragementContext.weeklyReview,
        emoji: '🌟',
      );
    } else if (pattern.overallRate >= 0.5) {
      return PersonalizedEncouragement(
        message: '本周完成率$ratePercent%，还有提升空间，加油！',
        context: EncouragementContext.weeklyReview,
        emoji: '📈',
      );
    } else {
      return PersonalizedEncouragement(
        message: '本周完成率$ratePercent%，下周尝试降低难度试试？',
        context: EncouragementContext.weeklyReview,
        emoji: '💡',
      );
    }
  }

  /// 用户反馈
  Future<void> feedback(HabitLogData data, bool positive) async {
    // 更新规则置信度
    for (int i = 0; i < _learnedRules.length; i++) {
      if (_learnedRules[i].habitType == data.habitId) {
        final rule = _learnedRules[i];
        _learnedRules[i] = rule.copyWith(
          confidence: positive
              ? (rule.confidence * 1.05).clamp(0.0, 1.0)
              : (rule.confidence * 0.95).clamp(0.0, 1.0),
          sampleCount: rule.sampleCount + 1,
        );
      }
    }

    await _updateAccuracy(data.userId);
  }

  Future<void> _updateAccuracy(String userId) async {
    final recentLogs = await _dataStore.getUserLogs(userId, days: 30);
    if (recentLogs.isEmpty) return;

    // 准确率基于预测与实际的匹配程度
    int correctPredictions = 0;
    for (final log in recentLogs) {
      final prediction = await predictHabitSuccess(
        userId: userId,
        habitId: log.habitId,
        targetTime: log.scheduledTime,
      );

      final predictedSuccess = prediction.successProbability >= 0.5;
      if (predictedSuccess == log.completed) {
        correctPredictions++;
      }
    }

    accuracy = correctPredictions / recentLogs.length;
  }

  /// 获取用户画像
  Future<UserHabitProfile?> getUserProfile(String userId) async {
    return _profileCache[userId];
  }

  /// 导出规则
  Future<List<HabitRule>> exportRules() async {
    return List.unmodifiable(_learnedRules);
  }

  /// 获取统计
  Future<HabitLearningStats> getStats() async {
    return HabitLearningStats(
      moduleId: moduleId,
      stage: stage,
      accuracy: accuracy,
      rulesCount: _learnedRules.length,
      profilesCached: _profileCache.length,
    );
  }
}

/// 习惯学习统计
class HabitLearningStats {
  final String moduleId;
  final HabitLearningStage stage;
  final double accuracy;
  final int rulesCount;
  final int profilesCached;

  const HabitLearningStats({
    required this.moduleId,
    required this.stage,
    required this.accuracy,
    required this.rulesCount,
    required this.profilesCached,
  });
}

// ==================== 习惯协同学习服务 ====================

/// 习惯协同学习服务
class HabitCollaborativeLearningService {
  final HabitLearningService _localService;
  final HabitCollaborativeApiClient? _apiClient;

  // 协同学习缓存
  final Map<String, CollaborativeHabitInsight> _insightCache = {};

  HabitCollaborativeLearningService({
    required HabitLearningService localService,
    HabitCollaborativeApiClient? apiClient,
  })  : _localService = localService,
        _apiClient = apiClient;

  /// 贡献本地学习结果到协同学习网络
  Future<void> contributeToNetwork(String userId) async {
    if (_apiClient == null) return;

    final profile = await _localService.getUserProfile(userId);
    if (profile == null) return;

    // 为每个习惯类型贡献统计数据
    for (final entry in profile.habitPatterns.entries) {
      final pattern = entry.value;

      // 提取有效策略
      final strategies = <String>[];
      if (pattern.morningRate > 0.7) strategies.add('早晨执行');
      if (pattern.eveningRate > 0.7) strategies.add('晚间执行');
      if (pattern.weekdayRate > pattern.weekendRate) {
        strategies.add('工作日优先');
      }
      if (pattern.currentStreak >= 21) strategies.add('21天法则');

      final contribution = HabitCollaborativeContribution(
        habitType: entry.key,
        hourlySuccessRate: pattern.hourlyDistribution,
        weekdaySuccessRate: pattern.weekdayDistribution,
        overallSuccessRate: pattern.overallRate,
        sampleCount: pattern.currentStreak + pattern.longestStreak,
        effectiveStrategies: strategies,
      );

      await _apiClient.contributeHabitData(contribution);
    }

    debugPrint('Contributed habit patterns to collaborative network');
  }

  /// 从协同学习网络获取洞察
  Future<CollaborativeHabitInsight?> getCollaborativeInsight(
    String habitType,
  ) async {
    // 检查缓存
    if (_insightCache.containsKey(habitType)) {
      return _insightCache[habitType];
    }

    if (_apiClient == null) {
      // 返回模拟数据
      return _getMockInsight(habitType);
    }

    try {
      final insight = await _apiClient.getHabitInsight(habitType);
      if (insight != null) {
        _insightCache[habitType] = insight;
      }
      return insight;
    } catch (e) {
      debugPrint('Failed to get collaborative insight: $e');
      return _getMockInsight(habitType);
    }
  }

  CollaborativeHabitInsight _getMockInsight(String habitType) {
    // 基于习惯类型返回模拟洞察
    return CollaborativeHabitInsight(
      habitType: habitType,
      popularTimeSlot: const TimeSlot(startHour: 7, endHour: 9, name: '早晨'),
      popularWeekdays: [1, 2, 3, 4, 5],
      communitySuccessRate: 0.65,
      topStrategies: [
        '固定时间执行',
        '与已有习惯绑定',
        '从小目标开始',
      ],
      benchmarkMessage: '社区中65%的用户能坚持这类习惯',
    );
  }

  /// 获取社区对比
  Future<CommunityComparison> getComparison(
    String userId,
    String habitType,
  ) async {
    final profile = await _localService.getUserProfile(userId);
    final insight = await getCollaborativeInsight(habitType);

    if (profile == null || insight == null) {
      return const CommunityComparison(
        userRate: 0,
        communityRate: 0.65,
        percentile: 50,
        message: '继续记录，了解你在社区中的位置',
      );
    }

    final pattern = profile.habitPatterns[habitType];
    final userRate = pattern?.overallRate ?? 0;
    final communityRate = insight.communitySuccessRate;

    // 计算百分位
    int percentile;
    if (userRate >= communityRate * 1.3) {
      percentile = 90;
    } else if (userRate >= communityRate * 1.1) {
      percentile = 75;
    } else if (userRate >= communityRate * 0.9) {
      percentile = 50;
    } else if (userRate >= communityRate * 0.7) {
      percentile = 25;
    } else {
      percentile = 10;
    }

    String message;
    if (percentile >= 75) {
      message = '你的表现超过了$percentile%的用户，继续保持！';
    } else if (percentile >= 50) {
      message = '你的表现处于中等水平，还有提升空间';
    } else {
      message = '参考社区的成功策略，可以帮助你提升';
    }

    return CommunityComparison(
      userRate: userRate,
      communityRate: communityRate,
      percentile: percentile,
      message: message,
    );
  }

  /// 获取社区推荐策略
  Future<List<String>> getCommunityStrategies(String habitType) async {
    final insight = await getCollaborativeInsight(habitType);
    return insight?.topStrategies ?? [];
  }
}

/// 社区对比结果
class CommunityComparison {
  final double userRate;
  final double communityRate;
  final int percentile;
  final String message;

  const CommunityComparison({
    required this.userRate,
    required this.communityRate,
    required this.percentile,
    required this.message,
  });
}

// ==================== API客户端接口 ====================

/// 习惯协同学习API客户端
abstract class HabitCollaborativeApiClient {
  Future<void> contributeHabitData(HabitCollaborativeContribution contribution);
  Future<CollaborativeHabitInsight?> getHabitInsight(String habitType);
}

/// 模拟API客户端
class MockHabitCollaborativeApiClient implements HabitCollaborativeApiClient {
  final List<HabitCollaborativeContribution> _contributions = [];

  @override
  Future<void> contributeHabitData(
    HabitCollaborativeContribution contribution,
  ) async {
    _contributions.add(contribution);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<CollaborativeHabitInsight?> getHabitInsight(String habitType) async {
    await Future.delayed(const Duration(milliseconds: 100));

    return CollaborativeHabitInsight(
      habitType: habitType,
      popularTimeSlot: const TimeSlot(startHour: 7, endHour: 9, name: '早晨'),
      popularWeekdays: [1, 2, 3, 4, 5],
      communitySuccessRate: 0.68,
      topStrategies: [
        '每天固定时间执行',
        '与现有习惯链接',
        '设置明确的触发信号',
        '准备备选方案',
      ],
    );
  }
}

// ==================== 数据存储 ====================

/// 习惯数据存储接口
abstract class HabitDataStore {
  Future<void> saveLog(HabitLogData log);
  Future<List<HabitLogData>> getUserLogs(String userId, {int? days});
  Future<int> getLogCount({String? userId});
}

/// 内存习惯数据存储
class InMemoryHabitDataStore implements HabitDataStore {
  final List<HabitLogData> _logs = [];

  @override
  Future<void> saveLog(HabitLogData log) async {
    _logs.add(log);
  }

  @override
  Future<List<HabitLogData>> getUserLogs(String userId, {int? days}) async {
    var result = _logs.where((l) => l.userId == userId);

    if (days != null) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      result = result.where((l) => l.scheduledTime.isAfter(cutoff));
    }

    return result.toList();
  }

  @override
  Future<int> getLogCount({String? userId}) async {
    if (userId == null) return _logs.length;
    return _logs.where((l) => l.userId == userId).length;
  }

  void clear() => _logs.clear();
}
