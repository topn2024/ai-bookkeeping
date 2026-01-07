# -*- coding: utf-8 -*-
"""
为各智能模块添加自学习能力和多用户协同学习系统
"""

# 15.2 智能分类 - 多用户协同学习（已有反馈学习，补充协同学习）
CATEGORY_COLLABORATIVE = '''

##### 15.2.4.8 多用户协同分类学习

基于统一自学习框架（15.12.1.1.8），实现分类知识的群体共享。

###### 15.2.4.8.1 协同学习架构

```dart
/// 分类协同学习服务
class CategoryCollaborativeLearningService {
  final PrivacyPreservingReporter _reporter;
  final GlobalCategoryRuleRepository _globalRepo;

  /// 上报本地学习到的分类规则（隐私保护）
  Future<void> reportLearnedRule(CategoryRule rule) async {
    // 脱敏处理：只上报模式，不上报具体商家名
    final sanitizedRule = SanitizedCategoryRule(
      // 商家模式（如："*咖啡*" 而非 "星巴克咖啡"）
      merchantPattern: _abstractMerchantPattern(rule.merchantName),
      // 关键词列表
      keywords: rule.keywords,
      // 目标分类
      categoryName: rule.category.name,
      // 本地置信度
      localConfidence: rule.confidence,
      // 本地命中频次
      localFrequency: rule.frequency,
      // 用户哈希
      userHash: _hashUserId(_currentUserId),
    );

    // 差分隐私噪声
    final noisyRule = _addDifferentialPrivacyNoise(sanitizedRule);
    await _reporter.report(noisyRule);
  }

  /// 抽象商家模式（保护隐私）
  String _abstractMerchantPattern(String? merchant) {
    if (merchant == null) return '*';

    // 提取通用模式
    // "星巴克咖啡(人民广场店)" → "*咖啡*"
    // "美团外卖-麦当劳" → "*外卖*"
    final patterns = [
      RegExp(r'咖啡'), RegExp(r'外卖'), RegExp(r'超市'),
      RegExp(r'餐厅'), RegExp(r'酒店'), RegExp(r'医院'),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(merchant)) {
        return '*${pattern.pattern}*';
      }
    }
    return '*';  // 无法抽象则返回通配符
  }
}

/// 全局分类规则聚合
class GlobalCategoryRuleAggregator {

  /// 聚合规则阈值
  static const int minUserCount = 10;        // 至少10个用户
  static const int minTotalFrequency = 50;   // 至少50次命中
  static const double minConfidence = 0.85;  // 最低置信度

  /// 聚合来自多用户的分类规则
  Future<List<GlobalCategoryRule>> aggregate() async {
    final allRules = await _db.getAllReportedCategoryRules();
    final globalRules = <GlobalCategoryRule>[];

    // 按 (商家模式 + 分类) 分组
    final grouped = _groupByPatternAndCategory(allRules);

    for (final entry in grouped.entries) {
      final stats = _calculateStats(entry.value);

      if (stats.uniqueUserCount >= minUserCount &&
          stats.totalFrequency >= minTotalFrequency &&
          stats.weightedConfidence >= minConfidence) {
        globalRules.add(GlobalCategoryRule(
          merchantPattern: entry.key.pattern,
          keywords: _mergeKeywords(entry.value),
          categoryName: entry.key.category,
          globalConfidence: stats.weightedConfidence,
          userCount: stats.uniqueUserCount,
          totalFrequency: stats.totalFrequency,
        ));
      }
    }

    return globalRules;
  }
}
```

###### 15.2.4.8.2 新用户分类冷启动

```dart
/// 分类冷启动服务
class CategoryColdStartService {

  /// 为新用户初始化分类规则
  Future<void> initializeNewUser(String userId) async {
    // 1. 加载全局热门规则（Top 100）
    final hotRules = await _globalRepo.getHotCategoryRules(limit: 100);

    // 2. 加载地域相关规则
    final regionRules = await _getRegionSpecificRules(userId);

    // 3. 初始化用户规则缓存
    await _userRuleCache.initialize(userId, [
      ...hotRules,
      ...regionRules,
    ]);

    // 新用户首次分类准确率预期：70%+ (vs 无规则时50%)
  }

  /// 获取地域相关规则
  Future<List<GlobalCategoryRule>> _getRegionSpecificRules(String userId) async {
    // 不同地域有不同的商家和消费习惯
    // 如：上海的"全家"、北京的"物美"
    final userRegion = await _getUserRegion(userId);
    return await _globalRepo.getRulesByRegion(userRegion, limit: 50);
  }
}
```

###### 15.2.4.8.3 协同学习效果预期

| 指标 | 无协同学习 | 有协同学习 | 提升 |
|------|------------|------------|------|
| 新用户首次准确率 | 50% | 75% | +50% |
| 冷启动周期 | 2周 | 即时 | -100% |
| 长尾商家覆盖率 | 30% | 70% | +133% |
| LLM调用比例 | 40% | 20% | -50% |

'''

# 15.3 预算建议 - 自学习+协同学习
BUDGET_LEARNING = '''

#### 15.3.2 预算建议自学习系统

##### 15.3.2.1 学习目标与数据采集

```dart
/// 预算学习样本
class BudgetLearningSample extends LearningSample<BudgetContext, BudgetSuggestion> {
  final double suggestedAmount;     // 建议金额
  final double? acceptedAmount;     // 用户采纳金额
  final BudgetAdjustType adjustType; // 调整类型

  @override
  double get qualityScore {
    var score = 0.0;
    // 用户完全采纳
    if (acceptedAmount == suggestedAmount) score += 0.5;
    // 用户调整后采纳（也是有价值的反馈）
    if (acceptedAmount != null && acceptedAmount != suggestedAmount) score += 0.4;
    // 高置信度建议
    if (confidence > 0.8) score += 0.2;
    return score.clamp(0.0, 1.0);
  }
}

enum BudgetAdjustType {
  accepted,      // 完全采纳
  adjusted,      // 调整后采纳
  rejected,      // 拒绝
  ignored,       // 忽略
}

/// 预算学习数据采集
class BudgetLearningCollector {

  /// 采集用户对预算建议的反馈
  Future<void> collectFeedback({
    required String suggestionId,
    required double suggestedAmount,
    required double? acceptedAmount,
    required BudgetAdjustType adjustType,
  }) async {
    final sample = BudgetLearningSample(
      id: _generateId(),
      input: await _getCurrentBudgetContext(),
      predictedOutput: BudgetSuggestion(amount: suggestedAmount),
      actualOutput: acceptedAmount != null
          ? BudgetSuggestion(amount: acceptedAmount) : null,
      confidence: _lastPredictionConfidence,
      label: _mapAdjustTypeToLabel(adjustType),
      timestamp: DateTime.now(),
      userId: _currentUserId,
      suggestedAmount: suggestedAmount,
      acceptedAmount: acceptedAmount,
      adjustType: adjustType,
    );

    await _sampleStore.insert(sample);

    // 触发增量学习
    if (sample.qualityScore >= 0.6) {
      await _learningService.incrementalLearn(sample);
    }
  }
}
```

##### 15.3.2.2 个性化预算模型

```dart
/// 个性化预算学习服务
class PersonalizedBudgetLearningService {

  /// 学习用户预算偏好
  Future<UserBudgetPreferences> learnPreferences(String userId) async {
    final samples = await _sampleStore.getUserSamples(userId);

    return UserBudgetPreferences(
      // 用户倾向于接受的预算比例（相对于建议值）
      acceptanceRatio: _calculateAcceptanceRatio(samples),
      // 各分类的预算弹性（用户调整幅度）
      categoryElasticity: _calculateCategoryElasticity(samples),
      // 用户对预算紧张度的容忍度
      tightnessPreference: _calculateTightnessPreference(samples),
      // 季节性调整偏好
      seasonalAdjustments: _calculateSeasonalAdjustments(samples),
    );
  }

  /// 计算接受比例
  double _calculateAcceptanceRatio(List<BudgetLearningSample> samples) {
    final acceptedSamples = samples.where((s) =>
      s.adjustType == BudgetAdjustType.accepted ||
      s.adjustType == BudgetAdjustType.adjusted
    ).toList();

    if (acceptedSamples.isEmpty) return 1.0;

    final ratios = acceptedSamples
        .where((s) => s.acceptedAmount != null)
        .map((s) => s.acceptedAmount! / s.suggestedAmount);

    return ratios.isEmpty ? 1.0 : ratios.average;
  }

  /// 应用个性化调整
  Future<BudgetSuggestion> applyPersonalization(
    BudgetSuggestion baseSuggestion,
    String userId,
  ) async {
    final prefs = await learnPreferences(userId);

    // 根据用户历史偏好调整建议
    final adjustedAmount = baseSuggestion.amount * prefs.acceptanceRatio;

    // 应用分类弹性
    final categoryAdjust = prefs.categoryElasticity[baseSuggestion.categoryId] ?? 1.0;
    final finalAmount = adjustedAmount * categoryAdjust;

    return baseSuggestion.copyWith(
      amount: finalAmount,
      confidence: baseSuggestion.confidence * 1.1,  // 个性化提升置信度
      reason: '${baseSuggestion.reason}（已根据您的习惯调整）',
    );
  }
}
```

##### 15.3.2.3 多用户协同预算学习

```dart
/// 预算协同学习服务
class BudgetCollaborativeLearningService {

  /// 上报预算模式（隐私保护）
  Future<void> reportBudgetPattern(BudgetLearningSample sample) async {
    // 只上报相对比例，不上报绝对金额
    final pattern = SanitizedBudgetPattern(
      // 分类
      categoryName: sample.input.categoryName,
      // 收入区间（脱敏）
      incomeRange: _getIncomeRange(sample.input.monthlyIncome),
      // 建议/实际比例
      acceptanceRatio: sample.acceptedAmount != null
          ? sample.acceptedAmount! / sample.suggestedAmount : null,
      // 调整类型
      adjustType: sample.adjustType,
      // 用户哈希
      userHash: _hashUserId(sample.userId),
    );

    await _reporter.report(pattern);
  }

  /// 收入区间脱敏
  String _getIncomeRange(double income) {
    if (income < 5000) return '0-5k';
    if (income < 10000) return '5k-10k';
    if (income < 20000) return '10k-20k';
    if (income < 50000) return '20k-50k';
    return '50k+';
  }
}

/// 全局预算洞察聚合
class GlobalBudgetInsightsAggregator {

  /// 聚合群体预算偏好
  Future<GlobalBudgetInsights> aggregate() async {
    final patterns = await _db.getAllBudgetPatterns();

    return GlobalBudgetInsights(
      // 各收入区间的平均预算分配比例
      incomeRangeBudgetRatios: _aggregateByIncomeRange(patterns),
      // 各分类的群体平均调整幅度
      categoryAdjustmentTrends: _aggregateByCategoryTrends(patterns),
      // 季节性预算变化趋势
      seasonalTrends: _aggregateSeasonalTrends(patterns),
    );
  }

  /// 为新用户提供参考预算
  Future<Map<String, double>> getReferenceBudget({
    required double monthlyIncome,
    required String region,
  }) async {
    final incomeRange = _getIncomeRange(monthlyIncome);
    final insights = await aggregate();

    // 基于群体数据推荐各分类预算比例
    final ratios = insights.incomeRangeBudgetRatios[incomeRange] ?? {};

    return ratios.map((category, ratio) =>
      MapEntry(category, monthlyIncome * ratio));
  }
}
```

##### 15.3.2.4 预算学习效果预期

| 指标 | 基线 | 自学习后 | +协同学习 |
|------|------|----------|-----------|
| 建议采纳率 | 40% | 60% | 75% |
| 平均调整幅度 | 30% | 15% | 10% |
| 新用户首次准确率 | 35% | 35% | 55% |

'''

# 15.5 异常检测 - 自学习+协同学习
ANOMALY_LEARNING = '''

#### 15.5.2 异常检测自学习系统

##### 15.5.2.1 个性化异常阈值学习

```dart
/// 异常检测学习服务
class AnomalyLearningService extends BaseLearningService<
    Transaction, AnomalyResult, AnomalyLearningSample> {

  /// 学习用户的异常判定偏好
  Future<UserAnomalyPreferences> learnAnomalyPreferences(String userId) async {
    final samples = await _sampleStore.getUserSamples(userId);

    // 分析用户对异常提醒的反馈
    final confirmedAnomalies = samples.where((s) =>
      s.label == SampleLabel.confirmedPositive).toList();
    final dismissedAnomalies = samples.where((s) =>
      s.label == SampleLabel.negative).toList();

    return UserAnomalyPreferences(
      // 各分类的个性化Z-Score阈值
      categoryThresholds: _calculateCategoryThresholds(
        confirmedAnomalies, dismissedAnomalies),
      // 用户对大额消费的敏感度
      amountSensitivity: _calculateAmountSensitivity(samples),
      // 用户对异地消费的敏感度
      locationSensitivity: _calculateLocationSensitivity(samples),
      // 用户对高频消费的敏感度
      frequencySensitivity: _calculateFrequencySensitivity(samples),
    );
  }

  /// 计算各分类的个性化阈值
  Map<String, double> _calculateCategoryThresholds(
    List<AnomalyLearningSample> confirmed,
    List<AnomalyLearningSample> dismissed,
  ) {
    final thresholds = <String, double>{};

    // 对于用户经常忽略的分类，提高阈值
    for (final sample in dismissed) {
      final category = sample.input.categoryId;
      if (category != null) {
        thresholds[category] = (thresholds[category] ?? 2.0) * 1.1;
      }
    }

    // 对于用户确认的异常，降低阈值（更敏感）
    for (final sample in confirmed) {
      final category = sample.input.categoryId;
      if (category != null) {
        thresholds[category] = (thresholds[category] ?? 2.0) * 0.95;
      }
    }

    return thresholds;
  }

  @override
  Future<void> updatePersonalizedModel(AnomalyLearningSample sample) async {
    final prefs = await learnAnomalyPreferences(sample.userId);
    await _preferencesStore.save(sample.userId, prefs);
  }
}

/// 用户异常偏好
class UserAnomalyPreferences {
  final Map<String, double> categoryThresholds;  // 默认2.0
  final double amountSensitivity;     // 0-1, 默认0.5
  final double locationSensitivity;   // 0-1, 默认0.5
  final double frequencySensitivity;  // 0-1, 默认0.5

  /// 应用个性化阈值判定异常
  bool isAnomaly(Transaction tx, double zScore) {
    final threshold = categoryThresholds[tx.categoryId] ?? 2.0;
    return zScore > threshold;
  }
}
```

##### 15.5.2.2 异常模式学习

```dart
/// 异常模式挖掘服务
class AnomalyPatternMiningService {

  /// 从确认的异常中学习模式
  Future<List<AnomalyPattern>> minePatterns() async {
    final confirmedAnomalies = await _sampleStore.getConfirmedAnomalies();

    final patterns = <AnomalyPattern>[];

    // 1. 金额异常模式
    patterns.addAll(_mineAmountPatterns(confirmedAnomalies));

    // 2. 时间异常模式（如凌晨消费）
    patterns.addAll(_mineTimePatterns(confirmedAnomalies));

    // 3. 频率异常模式（如同一商家连续消费）
    patterns.addAll(_mineFrequencyPatterns(confirmedAnomalies));

    // 4. 组合异常模式
    patterns.addAll(_mineCombinedPatterns(confirmedAnomalies));

    return patterns;
  }

  /// 挖掘金额异常模式
  List<AnomalyPattern> _mineAmountPatterns(List<AnomalyLearningSample> samples) {
    final patterns = <AnomalyPattern>[];

    // 按分类分组，找出各分类的异常金额特征
    final byCategory = _groupByCategory(samples);

    for (final entry in byCategory.entries) {
      final amounts = entry.value.map((s) => s.input.amount).toList();
      if (amounts.length >= 5) {
        final percentile90 = _calculatePercentile(amounts, 0.9);
        patterns.add(AnomalyPattern(
          type: AnomalyPatternType.amount,
          category: entry.key,
          condition: 'amount > $percentile90',
          confidence: 0.8,
        ));
      }
    }

    return patterns;
  }
}
```

##### 15.5.2.3 多用户协同异常检测

```dart
/// 异常检测协同学习服务
class AnomalyCollaborativeLearningService {

  /// 上报异常模式（隐私保护）
  Future<void> reportAnomalyPattern(AnomalyPattern pattern) async {
    // 只上报模式特征，不上报具体金额
    final sanitizedPattern = SanitizedAnomalyPattern(
      type: pattern.type,
      category: pattern.category,
      // 相对阈值而非绝对值
      relativeThreshold: pattern.relativeThreshold,
      userHash: _hashUserId(_currentUserId),
    );

    await _reporter.report(sanitizedPattern);
  }
}

/// 全局异常模式聚合
class GlobalAnomalyPatternAggregator {

  /// 发现群体级异常模式
  Future<List<GlobalAnomalyPattern>> discoverGlobalPatterns() async {
    final patterns = await _db.getAllAnomalyPatterns();

    // 聚合发现跨用户的共同异常模式
    return [
      // 如：大多数用户认为餐饮单笔超过月均5倍是异常
      // 如：凌晨2-5点的消费普遍被标记为异常
      // 如：同一商家1小时内3次以上消费被标记为异常
    ];
  }

  /// 新型诈骗/盗刷模式预警
  Future<List<FraudAlert>> detectEmergingFraudPatterns() async {
    // 当多个用户在短时间内报告相似的异常模式时
    // 可能是新型诈骗手段，需要全局预警
    final recentPatterns = await _db.getRecentAnomalyPatterns(hours: 24);

    final clusters = _clusterSimilarPatterns(recentPatterns);

    return clusters
        .where((c) => c.userCount >= 10 && c.similarity >= 0.8)
        .map((c) => FraudAlert(
          pattern: c.representativePattern,
          affectedUsers: c.userCount,
          confidence: c.similarity,
          firstDetected: c.earliestTimestamp,
        ))
        .toList();
  }
}
```

##### 15.5.2.4 异常检测学习效果预期

| 指标 | 基线 | 自学习后 | +协同学习 |
|------|------|----------|-----------|
| 误报率 | 30% | 15% | 10% |
| 漏报率 | 20% | 12% | 8% |
| 用户满意度 | 60% | 80% | 90% |
| 新型诈骗发现 | - | - | <24h |

'''

# 15.6 自然语言搜索 - 自学习+协同学习
SEARCH_LEARNING = '''

#### 15.6.2 搜索自学习系统

##### 15.6.2.1 搜索意图学习

```dart
/// 搜索学习服务
class SearchLearningService extends BaseLearningService<
    String, SearchIntent, SearchLearningSample> {

  /// 学习用户搜索习惯
  Future<UserSearchPreferences> learnSearchPreferences(String userId) async {
    final samples = await _sampleStore.getUserSamples(userId);

    return UserSearchPreferences(
      // 用户常用搜索词 → 意图映射
      queryIntentMappings: _buildQueryIntentMappings(samples),
      // 用户偏好的时间范围
      preferredTimeRange: _inferPreferredTimeRange(samples),
      // 用户偏好的排序方式
      preferredSorting: _inferPreferredSorting(samples),
      // 用户的同义词习惯
      synonymMappings: _buildSynonymMappings(samples),
    );
  }

  /// 构建查询-意图映射
  Map<String, SearchIntent> _buildQueryIntentMappings(
    List<SearchLearningSample> samples,
  ) {
    final mappings = <String, Map<SearchIntent, int>>{};

    for (final sample in samples) {
      if (sample.clickedResult != null) {
        final query = sample.input.toLowerCase();
        mappings[query] ??= {};
        final intent = sample.clickedResult!.intent;
        mappings[query]![intent] = (mappings[query]![intent] ?? 0) + 1;
      }
    }

    // 选择每个查询最常点击的意图
    return mappings.map((query, votes) {
      final topIntent = votes.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      return MapEntry(query, topIntent);
    });
  }

  @override
  Future<PredictionResult<SearchIntent>> fallbackPredict(String input) async {
    // LLM理解复杂查询
    return await _llmService.parseSearchIntent(input);
  }
}

/// 搜索意图预测增强
class EnhancedSearchIntentPredictor {

  Future<SearchIntent> predict(String query, String userId) async {
    final prefs = await _learningService.learnSearchPreferences(userId);

    // 1. 检查个性化映射
    final personalIntent = prefs.queryIntentMappings[query.toLowerCase()];
    if (personalIntent != null) {
      return personalIntent.copyWith(
        confidence: 0.95,
        source: IntentSource.learned,
      );
    }

    // 2. 同义词替换后再查
    final normalizedQuery = _applySynonyms(query, prefs.synonymMappings);
    final synonymIntent = prefs.queryIntentMappings[normalizedQuery];
    if (synonymIntent != null) {
      return synonymIntent.copyWith(
        confidence: 0.9,
        source: IntentSource.learned,
      );
    }

    // 3. 规则匹配 → LLM兜底
    return await _baseLearningService.predict(query);
  }
}
```

##### 15.6.2.2 多用户协同搜索学习

```dart
/// 搜索协同学习服务
class SearchCollaborativeLearningService {

  /// 上报搜索模式
  Future<void> reportSearchPattern(SearchLearningSample sample) async {
    if (sample.clickedResult == null) return;

    final pattern = SanitizedSearchPattern(
      // 查询词（已脱敏，移除具体金额/日期）
      normalizedQuery: _normalizeQuery(sample.input),
      // 点击的意图类型
      clickedIntent: sample.clickedResult!.intent,
      // 点击位置
      clickPosition: sample.clickPosition,
      userHash: _hashUserId(sample.userId),
    );

    await _reporter.report(pattern);
  }

  /// 查询脱敏
  String _normalizeQuery(String query) {
    // "上个月咖啡花了多少" → "{time}咖啡花了多少"
    // "1月15日买书" → "{date}买书"
    return query
        .replaceAll(RegExp(r'\\d+月\\d+日?'), '{date}')
        .replaceAll(RegExp(r'上个?月|这个?月|本月'), '{time}')
        .replaceAll(RegExp(r'\\d+(\\.\\d+)?元?'), '{amount}');
  }
}

/// 全局搜索意图聚合
class GlobalSearchIntentAggregator {

  /// 发现热门查询模式
  Future<List<HotSearchPattern>> discoverHotPatterns() async {
    final patterns = await _db.getAllSearchPatterns();

    // 聚合高频查询模式
    final grouped = _groupByNormalizedQuery(patterns);

    return grouped.entries
        .where((e) => e.value.length >= 20)  // 至少20次
        .map((e) => HotSearchPattern(
          queryPattern: e.key,
          dominantIntent: _getMostClickedIntent(e.value),
          frequency: e.value.length,
        ))
        .toList();
  }

  /// 为新用户预加载热门搜索映射
  Future<Map<String, SearchIntent>> getHotSearchMappings() async {
    final hotPatterns = await discoverHotPatterns();
    return Map.fromEntries(
      hotPatterns.map((p) => MapEntry(p.queryPattern, p.dominantIntent))
    );
  }
}
```

##### 15.6.2.3 搜索学习效果预期

| 指标 | 基线 | 自学习后 | +协同学习 |
|------|------|----------|-----------|
| 首次点击率 | 50% | 70% | 80% |
| 平均搜索次数 | 2.5次 | 1.5次 | 1.2次 |
| 意图识别准确率 | 65% | 85% | 92% |

'''

# 15.7 对话助手 - 自学习+协同学习
DIALOGUE_LEARNING = '''

#### 15.7.2 对话助手自学习系统

##### 15.7.2.1 对话意图学习

```dart
/// 对话学习服务
class DialogueLearningService extends BaseLearningService<
    DialogueContext, DialogueIntent, DialogueLearningSample> {

  /// 学习对话模式
  Future<UserDialoguePreferences> learnDialoguePreferences(String userId) async {
    final samples = await _sampleStore.getUserSamples(userId);

    return UserDialoguePreferences(
      // 用户常用的对话开场白 → 意图
      greetingIntentMappings: _buildGreetingMappings(samples),
      // 用户的表达简洁度偏好
      verbosityLevel: _calculateVerbosityLevel(samples),
      // 用户偏好的确认方式
      confirmationStyle: _inferConfirmationStyle(samples),
      // 多轮对话的平均轮数
      averageTurns: _calculateAverageTurns(samples),
    );
  }

  /// 学习用户的表达习惯
  Map<String, DialogueIntent> _buildGreetingMappings(
    List<DialogueLearningSample> samples,
  ) {
    // 学习用户如何开始对话
    // "帮我记一笔" → 记账意图
    // "查一下" → 查询意图
    // "看看" → 浏览意图
    final mappings = <String, DialogueIntent>{};

    for (final sample in samples) {
      if (sample.isFirstTurn && sample.taskCompleted) {
        final opening = _extractOpening(sample.input.userMessage);
        mappings[opening] = sample.actualOutput ?? sample.predictedOutput;
      }
    }

    return mappings;
  }
}

/// 对话任务完成率学习
class DialogueCompletionLearner {

  /// 分析对话失败原因
  Future<DialogueFailureAnalysis> analyzeFailures(String userId) async {
    final failedSamples = await _sampleStore.getFailedDialogues(userId);

    return DialogueFailureAnalysis(
      // 常见失败点
      commonFailurePoints: _identifyFailurePoints(failedSamples),
      // 用户放弃的典型轮数
      abandonmentTurn: _calculateAbandonmentTurn(failedSamples),
      // 导致失败的意图类型
      problematicIntents: _identifyProblematicIntents(failedSamples),
    );
  }

  /// 优化对话策略
  Future<void> optimizeDialogueStrategy(String userId) async {
    final analysis = await analyzeFailures(userId);

    // 针对失败点调整对话策略
    for (final failurePoint in analysis.commonFailurePoints) {
      await _adjustStrategy(userId, failurePoint);
    }
  }
}
```

##### 15.7.2.2 多用户协同对话学习

```dart
/// 对话协同学习服务
class DialogueCollaborativeLearningService {

  /// 上报成功的对话模式
  Future<void> reportSuccessfulDialogue(DialogueLearningSample sample) async {
    if (!sample.taskCompleted) return;

    final pattern = SanitizedDialoguePattern(
      // 对话轮数
      turns: sample.dialogueTurns,
      // 意图序列
      intentSequence: sample.intentSequence,
      // 任务类型
      taskType: sample.taskType,
      // 成功标记
      success: true,
      userHash: _hashUserId(sample.userId),
    );

    await _reporter.report(pattern);
  }
}

/// 全局对话模式聚合
class GlobalDialoguePatternAggregator {

  /// 发现最佳对话路径
  Future<List<OptimalDialoguePath>> discoverOptimalPaths() async {
    final patterns = await _db.getSuccessfulDialoguePatterns();

    // 按任务类型分组，找出成功率最高的对话路径
    final byTask = _groupByTaskType(patterns);

    return byTask.entries.map((e) {
      final successPatterns = e.value.where((p) => p.success).toList();
      final optimalSequence = _findMostCommonSequence(successPatterns);

      return OptimalDialoguePath(
        taskType: e.key,
        intentSequence: optimalSequence,
        averageTurns: _calculateAverageTurns(successPatterns),
        successRate: successPatterns.length / e.value.length,
      );
    }).toList();
  }
}
```

##### 15.7.2.3 对话学习效果预期

| 指标 | 基线 | 自学习后 | +协同学习 |
|------|------|----------|-----------|
| 任务完成率 | 60% | 75% | 85% |
| 平均对话轮数 | 4轮 | 3轮 | 2.5轮 |
| 用户满意度 | 65% | 80% | 88% |

'''


def insert_content(content, marker, new_content, check_exists):
    """在指定标记之前插入新内容"""
    if check_exists in content:
        print(f"Content '{check_exists}' already exists, skipping")
        return content

    idx = content.find(marker)
    if idx == -1:
        print(f"Warning: Cannot find marker '{marker}'")
        return content

    before = content[:idx].rstrip()
    after = content[idx:]

    return before + '\n\n' + new_content.strip() + '\n\n' + after


def main():
    # 读取文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    original_size = len(content)

    # 1. 为15.2智能分类添加协同学习（在15.3之前）
    content = insert_content(
        content,
        '### 15.3 智能预算建议',
        CATEGORY_COLLABORATIVE,
        '##### 15.2.4.8 多用户协同分类学习'
    )

    # 2. 为15.3预算建议添加自学习（在15.4之前）
    content = insert_content(
        content,
        '### 15.4 消费趋势预测',
        BUDGET_LEARNING,
        '#### 15.3.2 预算建议自学习系统'
    )

    # 3. 为15.5异常检测添加自学习（在15.6之前）
    content = insert_content(
        content,
        '### 15.6 自然语言搜索',
        ANOMALY_LEARNING,
        '#### 15.5.2 异常检测自学习系统'
    )

    # 4. 为15.6搜索添加自学习（在15.7之前）
    content = insert_content(
        content,
        '### 15.7 对话式记账助手',
        SEARCH_LEARNING,
        '#### 15.6.2 搜索自学习系统'
    )

    # 5. 为15.7对话助手添加自学习（在15.8之前）
    content = insert_content(
        content,
        '### 15.8 智能资金分配',
        DIALOGUE_LEARNING,
        '#### 15.7.2 对话助手自学习系统'
    )

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(content)

    print(f'Successfully added learning capabilities to all modules!')
    print(f'Old size: {original_size} characters')
    print(f'New size: {len(content)} characters')
    print(f'Added: {len(content) - original_size} characters')


if __name__ == '__main__':
    main()
