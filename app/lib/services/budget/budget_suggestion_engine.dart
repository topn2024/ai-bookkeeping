import 'budget_suggestion.dart';

/// 预算建议引擎
///
/// 组合服务，聚合和合并多个策略的建议结果
///
/// 使用方式：
/// ```dart
/// final engine = BudgetSuggestionEngine([
///   AdaptiveBudgetStrategy(),
///   SmartBudgetStrategy(),
///   LocationBudgetStrategy(),
/// ]);
///
/// final suggestions = await engine.getSuggestions();
/// ```
class BudgetSuggestionEngine {
  /// 注册的策略列表
  final List<BudgetSuggestionStrategy> _strategies;

  /// 策略优先级（优先级高的置信度加成更大）
  final Map<BudgetSuggestionSource, double> _priorityWeights;

  BudgetSuggestionEngine(
    this._strategies, {
    Map<BudgetSuggestionSource, double>? priorityWeights,
  }) : _priorityWeights = priorityWeights ?? _defaultPriorityWeights;

  /// 默认策略优先级权重
  static const Map<BudgetSuggestionSource, double> _defaultPriorityWeights = {
    BudgetSuggestionSource.adaptive: 1.0,
    BudgetSuggestionSource.smart: 0.9,
    BudgetSuggestionSource.localized: 0.7,
    BudgetSuggestionSource.location: 0.8,
    BudgetSuggestionSource.custom: 1.0,
  };

  /// 获取聚合预算建议（包含数据不足警告）
  ///
  /// 并行执行所有策略，然后合并同一分类的建议
  /// [categoryIds] 限定分类列表
  /// [context] 上下文信息
  Future<BudgetSuggestionResult> getSuggestionsWithWarnings({
    List<String>? categoryIds,
    Map<String, dynamic>? context,
  }) async {
    final warnings = <DataInsufficiencyWarning>[];

    // 并行执行所有可用策略
    final results = await Future.wait(
      _strategies.map((strategy) async {
        try {
          // 检查策略是否可用
          if (!await strategy.isAvailable()) {
            // 获取数据不足原因
            final reason = await strategy.getDataInsufficiencyReason();
            if (reason != null) {
              warnings.add(DataInsufficiencyWarning(
                source: strategy.sourceType,
                strategyName: strategy.name,
                reason: reason,
              ));
            }
            return <BudgetSuggestion>[];
          }

          return await strategy.getSuggestions(
            categoryIds: categoryIds,
            context: context,
          );
        } catch (e) {
          // 策略执行失败时记录警告
          warnings.add(DataInsufficiencyWarning(
            source: strategy.sourceType,
            strategyName: strategy.name,
            reason: '策略执行失败，请稍后重试',
          ));
          return <BudgetSuggestion>[];
        }
      }),
    );

    // 扁平化结果
    final allSuggestions = results.expand((list) => list).toList();

    // 合并同一分类的建议
    final mergedSuggestions = _mergeSuggestions(allSuggestions);

    return BudgetSuggestionResult(
      suggestions: mergedSuggestions,
      warnings: warnings,
    );
  }

  /// 获取聚合预算建议（向后兼容）
  ///
  /// 并行执行所有策略，然后合并同一分类的建议
  /// [categoryIds] 限定分类列表
  /// [context] 上下文信息
  Future<List<BudgetSuggestion>> getSuggestions({
    List<String>? categoryIds,
    Map<String, dynamic>? context,
  }) async {
    final result = await getSuggestionsWithWarnings(
      categoryIds: categoryIds,
      context: context,
    );
    return result.suggestions;
  }

  /// 合并同一分类的建议
  ///
  /// 策略：选择置信度最高的建议
  List<BudgetSuggestion> _mergeSuggestions(List<BudgetSuggestion> suggestions) {
    final mergedMap = <String, BudgetSuggestion>{};

    for (final suggestion in suggestions) {
      final key = suggestion.categoryId;

      // 计算加权置信度
      final weight = _priorityWeights[suggestion.source] ?? 1.0;
      final weightedConfidence = suggestion.confidence * weight;

      if (!mergedMap.containsKey(key)) {
        mergedMap[key] = suggestion;
      } else {
        final existing = mergedMap[key]!;
        final existingWeight = _priorityWeights[existing.source] ?? 1.0;
        final existingWeightedConfidence = existing.confidence * existingWeight;

        // 选择加权置信度更高的
        if (weightedConfidence > existingWeightedConfidence) {
          mergedMap[key] = suggestion;
        }
      }
    }

    // 按分类 ID 排序返回
    final result = mergedMap.values.toList()
      ..sort((a, b) => a.categoryId.compareTo(b.categoryId));

    return result;
  }

  /// 获取指定策略的建议
  Future<List<BudgetSuggestion>> getSuggestionsFromStrategy(
    BudgetSuggestionSource source, {
    List<String>? categoryIds,
    Map<String, dynamic>? context,
  }) async {
    final strategy = _strategies.firstWhere(
      (s) => s.sourceType == source,
      orElse: () => throw ArgumentError('Strategy not found: $source'),
    );

    return await strategy.getSuggestions(
      categoryIds: categoryIds,
      context: context,
    );
  }

  /// 获取已注册的策略列表
  List<BudgetSuggestionStrategy> get strategies =>
      List.unmodifiable(_strategies);

  /// 添加策略
  void addStrategy(BudgetSuggestionStrategy strategy) {
    _strategies.add(strategy);
  }

  /// 移除策略
  void removeStrategy(BudgetSuggestionSource source) {
    _strategies.removeWhere((s) => s.sourceType == source);
  }

  /// 检查指定策略是否可用
  Future<bool> isStrategyAvailable(BudgetSuggestionSource source) async {
    final strategy = _strategies.where((s) => s.sourceType == source);
    if (strategy.isEmpty) return false;
    return await strategy.first.isAvailable();
  }
}
