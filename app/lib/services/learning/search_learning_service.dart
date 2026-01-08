import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'unified_self_learning_service.dart';

// ==================== 搜索学习数据模型 ====================

/// 搜索意图类型
enum SearchIntentType {
  sum, // 求和：花了多少
  list, // 列表：哪些消费
  compare, // 对比：比上月多了多少
  trend, // 趋势：消费走势
  category, // 分类：在哪花的最多
  merchant, // 商家：去星巴克花了多少
  filter, // 筛选：超过100的消费
  stats, // 统计：平均每天花多少
}

/// 搜索意图
class SearchIntent {
  final SearchIntentType type;
  final DateRange? dateRange;
  final String? category;
  final String? merchant;
  final AmountFilter? amountFilter;
  final String? sortBy;
  final double confidence;

  const SearchIntent({
    required this.type,
    this.dateRange,
    this.category,
    this.merchant,
    this.amountFilter,
    this.sortBy,
    this.confidence = 0.5,
  });

  SearchIntent copyWith({
    SearchIntentType? type,
    DateRange? dateRange,
    String? category,
    String? merchant,
    AmountFilter? amountFilter,
    String? sortBy,
    double? confidence,
  }) {
    return SearchIntent(
      type: type ?? this.type,
      dateRange: dateRange ?? this.dateRange,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      amountFilter: amountFilter ?? this.amountFilter,
      sortBy: sortBy ?? this.sortBy,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'date_range': dateRange?.toJson(),
        'category': category,
        'merchant': merchant,
        'amount_filter': amountFilter?.toJson(),
        'sort_by': sortBy,
        'confidence': confidence,
      };
}

/// 日期范围
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  /// 本月
  factory DateRange.thisMonth() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  /// 上月
  factory DateRange.lastMonth() {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month - 1, 1),
      end: DateTime(now.year, now.month, 0),
    );
  }

  /// 本周
  factory DateRange.thisWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return DateRange(
      start: DateTime(weekStart.year, weekStart.month, weekStart.day),
      end: now,
    );
  }
}

/// 金额筛选
class AmountFilter {
  final double? min;
  final double? max;

  const AmountFilter({this.min, this.max});

  Map<String, dynamic> toJson() => {
        'min': min,
        'max': max,
      };
}

/// 搜索结果
class SearchResult {
  final String answer;
  final SearchResultType type;
  final Map<String, dynamic> data;
  final SearchIntent? intent;

  const SearchResult({
    required this.answer,
    required this.type,
    this.data = const {},
    this.intent,
  });
}

enum SearchResultType {
  amount, // 金额结果
  list, // 列表结果
  stats, // 统计结果
  chart, // 图表结果
  empty, // 无结果
}

// ==================== 搜索学习数据 ====================

/// 搜索学习数据
class SearchLearningData extends LearningData {
  final String query;
  final SearchIntent? predictedIntent;
  final SearchIntent? actualIntent;
  final List<SearchResult> returnedResults;
  final SearchResult? clickedResult;
  final int? clickPosition;
  final bool taskCompleted;

  SearchLearningData({
    required super.id,
    required super.timestamp,
    required super.userId,
    required this.query,
    this.predictedIntent,
    this.actualIntent,
    this.returnedResults = const [],
    this.clickedResult,
    this.clickPosition,
    this.taskCompleted = false,
  }) : super(
          features: {'query': query},
          label: actualIntent ?? predictedIntent,
          source: actualIntent != null
              ? LearningDataSource.userExplicitFeedback
              : LearningDataSource.userImplicitBehavior,
        );

  @override
  double get qualityScore {
    var score = 0.0;
    // 用户有点击行为
    if (clickedResult != null) score += 0.4;
    // 点击位置靠前说明预测准确
    if (clickPosition != null && clickPosition! <= 3) score += 0.3;
    // 任务完成
    if (taskCompleted) score += 0.3;
    return score.clamp(0.0, 1.0);
  }

  @override
  Map<String, dynamic> toStorable() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'query': query,
        'predicted_intent': predictedIntent?.toJson(),
        'actual_intent': actualIntent?.toJson(),
        'click_position': clickPosition,
        'task_completed': taskCompleted,
      };

  @override
  LearningData anonymize() => SearchLearningData(
        id: id,
        timestamp: timestamp,
        userId: _hashValue(userId),
        query: query,
        predictedIntent: predictedIntent,
        actualIntent: actualIntent,
        clickPosition: clickPosition,
        taskCompleted: taskCompleted,
      );

  static String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}

/// 搜索规则
class SearchRule extends LearnedRule {
  final String queryPattern;
  final SearchIntentType intentType;
  final Map<String, String> parameterMappings;
  final List<String> keywords;

  SearchRule({
    required super.ruleId,
    required this.queryPattern,
    required this.intentType,
    required super.confidence,
    required super.source,
    this.parameterMappings = const {},
    this.keywords = const [],
    DateTime? createdAt,
    super.hitCount,
  }) : super(
          moduleId: 'search_learning',
          priority: source == RuleSource.userLearned ? 100 : 50,
          createdAt: createdAt ?? DateTime.now(),
          lastUsedAt: DateTime.now(),
        );

  @override
  bool matches(dynamic input) {
    if (input is! String) return false;
    final query = input.toLowerCase();

    // 检查关键词匹配
    return keywords.any((k) => query.contains(k.toLowerCase()));
  }

  @override
  dynamic apply(dynamic input) {
    return SearchIntent(
      type: intentType,
      confidence: confidence,
    );
  }

  @override
  Map<String, dynamic> toStorable() => {
        'rule_id': ruleId,
        'query_pattern': queryPattern,
        'intent_type': intentType.name,
        'confidence': confidence,
        'source': source.name,
        'parameter_mappings': parameterMappings,
        'keywords': keywords,
        'created_at': createdAt.toIso8601String(),
        'hit_count': hitCount,
      };

  factory SearchRule.fromStorable(Map<String, dynamic> data) {
    return SearchRule(
      ruleId: data['rule_id'] as String,
      queryPattern: data['query_pattern'] as String,
      intentType: SearchIntentType.values.firstWhere(
        (t) => t.name == data['intent_type'],
        orElse: () => SearchIntentType.list,
      ),
      confidence: (data['confidence'] as num).toDouble(),
      source: RuleSource.values.firstWhere(
        (s) => s.name == data['source'],
        orElse: () => RuleSource.userLearned,
      ),
      parameterMappings:
          Map<String, String>.from(data['parameter_mappings'] ?? {}),
      keywords: List<String>.from(data['keywords'] ?? []),
      createdAt: DateTime.parse(data['created_at'] as String),
      hitCount: data['hit_count'] as int? ?? 0,
    );
  }
}

// ==================== 用户搜索偏好 ====================

/// 用户搜索偏好
class UserSearchPreferences {
  final Map<String, SearchIntent> queryIntentMappings;
  final DateRange? preferredTimeRange;
  final String? preferredSorting;
  final Map<String, String> synonymMappings;
  final List<String> frequentQueries;

  const UserSearchPreferences({
    this.queryIntentMappings = const {},
    this.preferredTimeRange,
    this.preferredSorting,
    this.synonymMappings = const {},
    this.frequentQueries = const [],
  });
}

// ==================== 搜索学习服务 ====================

/// 搜索学习服务
class SearchLearningService
    implements ISelfLearningModule<SearchLearningData, SearchRule> {
  @override
  String get moduleId => 'search_learning';

  @override
  String get moduleName => '搜索学习';

  // 存储
  final List<SearchLearningData> _samples = [];
  final List<SearchRule> _rules = [];
  final Map<String, UserSearchPreferences> _userPreferences = {};

  // 配置
  static const int _minSamplesForRule = 3;
  static const double _minConfidenceThreshold = 0.6;

  // 状态
  final bool _isEnabled = true;
  DateTime? _lastTrainingTime;
  LearningStage _stage = LearningStage.coldStart;

  @override
  Future<void> collectSample(SearchLearningData data) async {
    _samples.add(data);
    _updateStage();
    debugPrint('Collected search sample: ${data.query}');
  }

  @override
  Future<void> collectSamples(List<SearchLearningData> dataList) async {
    _samples.addAll(dataList);
    _updateStage();
  }

  @override
  Future<TrainingResult> train({bool incremental = true}) async {
    final startTime = DateTime.now();
    _stage = LearningStage.training;

    try {
      final samples = incremental
          ? _samples
              .where((s) =>
                  s.timestamp.isAfter(_lastTrainingTime ?? DateTime(2000)))
              .toList()
          : _samples;

      if (samples.isEmpty) {
        _stage = LearningStage.active;
        return TrainingResult(
          success: true,
          samplesUsed: 0,
          rulesGenerated: 0,
          trainingTime: Duration.zero,
        );
      }

      // 1. 学习查询-意图映射
      final newRules = _extractSearchRules(samples);

      // 2. 更新用户偏好
      await _updateUserPreferences(samples);

      // 合并规则
      for (final rule in newRules) {
        _upsertRule(rule);
      }

      _lastTrainingTime = DateTime.now();
      _stage = LearningStage.active;

      return TrainingResult(
        success: true,
        samplesUsed: samples.length,
        rulesGenerated: newRules.length,
        trainingTime: DateTime.now().difference(startTime),
        newMetrics: await getMetrics(),
      );
    } catch (e) {
      _stage = LearningStage.degraded;
      return TrainingResult(
        success: false,
        samplesUsed: 0,
        rulesGenerated: 0,
        trainingTime: DateTime.now().difference(startTime),
        errorMessage: e.toString(),
      );
    }
  }

  List<SearchRule> _extractSearchRules(List<SearchLearningData> samples) {
    final rules = <SearchRule>[];

    // 按查询关键词聚类
    final queryGroups = groupBy(
      samples.where((s) => s.clickedResult != null || s.taskCompleted),
      (s) => _normalizeQuery(s.query),
    );

    for (final entry in queryGroups.entries) {
      if (entry.value.length >= _minSamplesForRule) {
        // 统计最常见的意图类型
        final intentCounts = <SearchIntentType, int>{};
        for (final sample in entry.value) {
          final intent =
              sample.actualIntent?.type ?? sample.predictedIntent?.type;
          if (intent != null) {
            intentCounts[intent] = (intentCounts[intent] ?? 0) + 1;
          }
        }

        if (intentCounts.isNotEmpty) {
          final mostFrequent =
              intentCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
          final confidence = mostFrequent.value / entry.value.length;

          if (confidence >= _minConfidenceThreshold) {
            // 提取关键词
            final keywords = _extractKeywords(entry.value.map((s) => s.query));

            rules.add(SearchRule(
              ruleId: 'search_${entry.key.hashCode}',
              queryPattern: entry.key,
              intentType: mostFrequent.key,
              confidence: confidence,
              source: RuleSource.userLearned,
              keywords: keywords,
            ));
          }
        }
      }
    }

    return rules;
  }

  String _normalizeQuery(String query) {
    return query.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _extractKeywords(Iterable<String> queries) {
    final wordFreq = <String, int>{};

    for (final query in queries) {
      final words = query.toLowerCase().split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.length >= 2 && !_isStopWord(word)) {
          wordFreq[word] = (wordFreq[word] ?? 0) + 1;
        }
      }
    }

    // 返回出现频率最高的词
    final sorted = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }

  bool _isStopWord(String word) {
    const stopWords = {'的', '了', '是', '在', '我', '有', '和', '就', '不', '人', '都', '一'};
    return stopWords.contains(word);
  }

  Future<void> _updateUserPreferences(List<SearchLearningData> samples) async {
    final userGroups = groupBy(samples, (s) => s.userId);

    for (final entry in userGroups.entries) {
      final userId = entry.key;
      final userSamples = entry.value;

      final prefs = await learnSearchPreferences(userId, userSamples);
      _userPreferences[userId] = prefs;
    }
  }

  /// 学习用户搜索偏好
  Future<UserSearchPreferences> learnSearchPreferences(
    String userId,
    List<SearchLearningData> samples,
  ) async {
    // 构建查询-意图映射
    final queryIntentMappings = <String, SearchIntent>{};
    final queryFrequency = <String, int>{};

    for (final sample in samples) {
      if (sample.clickedResult != null || sample.taskCompleted) {
        final query = _normalizeQuery(sample.query);
        final intent = sample.actualIntent ?? sample.predictedIntent;
        if (intent != null) {
          queryIntentMappings[query] = intent;
          queryFrequency[query] = (queryFrequency[query] ?? 0) + 1;
        }
      }
    }

    // 找出常用查询
    final frequentQueries = queryFrequency.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toList();

    return UserSearchPreferences(
      queryIntentMappings: queryIntentMappings,
      frequentQueries: frequentQueries,
    );
  }

  void _upsertRule(SearchRule newRule) {
    final existingIndex = _rules.indexWhere(
      (r) => r.queryPattern == newRule.queryPattern,
    );

    if (existingIndex >= 0) {
      final existing = _rules[existingIndex];
      if (newRule.confidence > existing.confidence) {
        _rules[existingIndex] = newRule;
      }
    } else {
      _rules.add(newRule);
    }
  }

  @override
  Future<PredictionResult<SearchRule>> predict(dynamic input) async {
    final query = input as String;
    final normalizedQuery = _normalizeQuery(query);

    // 1. 检查用户个性化规则
    // 这里简化实现，实际应该获取当前用户ID
    for (final prefs in _userPreferences.values) {
      final personalIntent = prefs.queryIntentMappings[normalizedQuery];
      if (personalIntent != null) {
        return PredictionResult(
          matched: true,
          result: personalIntent,
          confidence: 0.95,
          source: PredictionSource.learnedRule,
        );
      }
    }

    // 2. 检查学习的规则
    for (final rule in _rules) {
      if (rule.matches(query)) {
        rule.recordHit();
        return PredictionResult(
          matched: true,
          matchedRule: rule,
          result: rule.apply(query),
          confidence: rule.confidence,
          source: PredictionSource.learnedRule,
        );
      }
    }

    // 3. 使用默认规则
    final defaultIntent = _inferDefaultIntent(query);
    return PredictionResult(
      matched: defaultIntent != null,
      result: defaultIntent,
      confidence: defaultIntent != null ? 0.5 : 0,
      source: PredictionSource.fallback,
    );
  }

  SearchIntent? _inferDefaultIntent(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('多少') || lowerQuery.contains('总共')) {
      return const SearchIntent(type: SearchIntentType.sum, confidence: 0.6);
    }

    if (lowerQuery.contains('哪些') || lowerQuery.contains('列表')) {
      return const SearchIntent(type: SearchIntentType.list, confidence: 0.6);
    }

    if (lowerQuery.contains('比') || lowerQuery.contains('对比')) {
      return const SearchIntent(
          type: SearchIntentType.compare, confidence: 0.6);
    }

    if (lowerQuery.contains('趋势') || lowerQuery.contains('走势')) {
      return const SearchIntent(type: SearchIntentType.trend, confidence: 0.6);
    }

    return null;
  }

  @override
  Future<LearningMetrics> getMetrics() async {
    final completedSamples = _samples.where((s) => s.taskCompleted).length;
    final accuracy =
        _samples.isEmpty ? 0.0 : completedSamples / _samples.length;

    return LearningMetrics(
      moduleId: moduleId,
      measureTime: DateTime.now(),
      totalSamples: _samples.length,
      totalRules: _rules.length,
      accuracy: accuracy,
      precision: accuracy,
      recall: accuracy,
      f1Score: accuracy,
      avgResponseTime: 5.0,
      customMetrics: {
        'user_preferences_count': _userPreferences.length,
        'frequent_queries_count': _userPreferences.values
            .fold(0, (sum, p) => sum + p.frequentQueries.length),
      },
    );
  }

  @override
  Future<List<SearchRule>> getRules({RuleSource? source, int? limit}) async {
    var rules = source != null
        ? _rules.where((r) => r.source == source).toList()
        : _rules.toList();

    if (limit != null && rules.length > limit) {
      rules = rules.sublist(0, limit);
    }

    return rules;
  }

  @override
  Future<ModelExportData> exportModel() async {
    return ModelExportData(
      moduleId: moduleId,
      exportedAt: DateTime.now(),
      rules: _rules.map((r) => r.toStorable()).toList(),
      metadata: {
        'total_samples': _samples.length,
        'last_training': _lastTrainingTime?.toIso8601String(),
        'user_preferences_count': _userPreferences.length,
      },
    );
  }

  @override
  Future<void> importModel(ModelExportData data) async {
    for (final ruleData in data.rules) {
      final rule = SearchRule.fromStorable(ruleData);
      _upsertRule(rule);
    }
    _updateStage();
  }

  @override
  Future<void> clearData({bool keepRules = true}) async {
    _samples.clear();
    _userPreferences.clear();
    if (!keepRules) {
      _rules.clear();
    }
    _stage = LearningStage.coldStart;
  }

  @override
  Future<LearningStatus> getStatus() async {
    return LearningStatus(
      moduleId: moduleId,
      isEnabled: _isEnabled,
      lastTrainingTime: _lastTrainingTime,
      nextScheduledTraining: _lastTrainingTime?.add(const Duration(hours: 24)),
      pendingSamples: _samples.length,
      stage: _stage,
    );
  }

  void _updateStage() {
    if (_samples.length < _minSamplesForRule) {
      _stage = LearningStage.coldStart;
    } else if (_rules.isEmpty) {
      _stage = LearningStage.collecting;
    } else {
      _stage = LearningStage.active;
    }
  }
}

// ==================== 搜索协同学习服务 ====================

/// 搜索协同学习服务
class SearchCollaborativeLearningService {
  final SearchLearningService _learningService;

  SearchCollaborativeLearningService(this._learningService);

  /// 上报搜索模式（隐私保护）
  Future<void> reportSearchPattern(SearchRule rule) async {
    if (rule.confidence < 0.8) return;

    final sanitizedPattern = SanitizedSearchPattern(
      intentType: rule.intentType,
      keywords: rule.keywords,
      confidence: rule.confidence,
      hitCount: rule.hitCount,
    );

    // 实际实现会上报到服务端
    debugPrint('Reporting search pattern: ${sanitizedPattern.toJson()}');
  }

  /// 下载协同规则
  Future<List<SearchRule>> downloadCollaborativeRules() async {
    // 实际实现会从服务端下载
    return [];
  }
}

/// 脱敏后的搜索模式
class SanitizedSearchPattern {
  final SearchIntentType intentType;
  final List<String> keywords;
  final double confidence;
  final int hitCount;

  const SanitizedSearchPattern({
    required this.intentType,
    required this.keywords,
    required this.confidence,
    required this.hitCount,
  });

  Map<String, dynamic> toJson() => {
        'intent_type': intentType.name,
        'keywords': keywords,
        'confidence': confidence,
        'hit_count': hitCount,
      };
}
