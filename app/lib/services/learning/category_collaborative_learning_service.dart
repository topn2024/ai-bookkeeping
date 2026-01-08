import 'dart:convert';

import 'package:collection/collection.dart'; // ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ==================== 分类学习数据模型 ====================

/// 分类学习样本
class CategoryLearningSample {
  final String id;
  final String userId;
  final String merchantName;
  final double amount;
  final String? originalCategory;
  final String finalCategory;
  final CategoryCorrectionType correctionType;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  const CategoryLearningSample({
    required this.id,
    required this.userId,
    required this.merchantName,
    required this.amount,
    this.originalCategory,
    required this.finalCategory,
    required this.correctionType,
    required this.timestamp,
    this.context = const {},
  });

  bool get wasCorrect =>
      originalCategory == null || originalCategory == finalCategory;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'merchant_name': merchantName,
        'amount': amount,
        'original_category': originalCategory,
        'final_category': finalCategory,
        'correction_type': correctionType.name,
        'timestamp': timestamp.toIso8601String(),
        'context': context,
      };
}

/// 分类修正类型
enum CategoryCorrectionType {
  autoAccepted, // 自动分类被接受
  userCorrected, // 用户修正
  userSelected, // 用户从建议中选择
  manualInput, // 用户手动输入
}

// ==================== 脱敏数据模型 ====================

/// 脱敏后的分类模式
class SanitizedCategoryPattern {
  final String merchantHash;
  final String merchantPrefix; // 商家名前缀（如"星巴克"保留，去除店名）
  final String amountRange;
  final String finalCategory;
  final CategoryCorrectionType correctionType;
  final String userHash;
  final int? hour;
  final int? dayOfWeek;
  final DateTime timestamp;

  const SanitizedCategoryPattern({
    required this.merchantHash,
    required this.merchantPrefix,
    required this.amountRange,
    required this.finalCategory,
    required this.correctionType,
    required this.userHash,
    this.hour,
    this.dayOfWeek,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'merchant_hash': merchantHash,
        'merchant_prefix': merchantPrefix,
        'amount_range': amountRange,
        'final_category': finalCategory,
        'correction_type': correctionType.name,
        'user_hash': userHash,
        'hour': hour,
        'day_of_week': dayOfWeek,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ==================== 全局分类洞察 ====================

/// 全局分类洞察
class GlobalCategoryInsights {
  final Map<String, MerchantCategoryMapping> merchantMappings;
  final Map<String, CategoryPopularity> categoryPopularity;
  final Map<String, List<String>> amountRangeCategoryDistribution;
  final Map<int, Map<String, double>> hourCategoryDistribution;
  final DateTime generatedAt;

  const GlobalCategoryInsights({
    required this.merchantMappings,
    required this.categoryPopularity,
    required this.amountRangeCategoryDistribution,
    required this.hourCategoryDistribution,
    required this.generatedAt,
  });
}

/// 商家-分类映射
class MerchantCategoryMapping {
  final String merchantPrefix;
  final String mostLikelyCategory;
  final double confidence;
  final Map<String, double> categoryDistribution;
  final int sampleCount;

  const MerchantCategoryMapping({
    required this.merchantPrefix,
    required this.mostLikelyCategory,
    required this.confidence,
    required this.categoryDistribution,
    required this.sampleCount,
  });
}

/// 分类流行度
class CategoryPopularity {
  final String categoryName;
  final double usageRatio;
  final double correctionRate;
  final List<String> commonMerchants;

  const CategoryPopularity({
    required this.categoryName,
    required this.usageRatio,
    required this.correctionRate,
    required this.commonMerchants,
  });
}

// ==================== 分类协同学习服务 ====================

/// 分类协同学习服务
class CategoryCollaborativeLearningService {
  final GlobalCategoryInsightsAggregator _aggregator;
  final CategoryPatternReporter _reporter;
  final String _currentUserId; // ignore: unused_field

  // 本地缓存
  final Map<String, MerchantCategoryMapping> _localMappingCache = {}; // ignore: unused_field
  GlobalCategoryInsights? _insightsCache;
  DateTime? _lastInsightsUpdate;

  // 配置
  static const Duration _cacheExpiry = Duration(hours: 24);
  static const int _minSamplesForMapping = 3; // ignore: unused_field

  CategoryCollaborativeLearningService({
    GlobalCategoryInsightsAggregator? aggregator,
    CategoryPatternReporter? reporter,
    String? currentUserId,
  })  : _aggregator = aggregator ?? GlobalCategoryInsightsAggregator(),
        _reporter = reporter ?? InMemoryCategoryPatternReporter(),
        _currentUserId = currentUserId ?? 'anonymous';

  /// 上报分类模式（隐私保护）
  Future<void> reportCategoryPattern(CategoryLearningSample sample) async {
    final pattern = SanitizedCategoryPattern(
      // 商家哈希
      merchantHash: _hashValue(sample.merchantName.toLowerCase()),
      // 商家前缀（保留品牌名，去除具体店名）
      merchantPrefix: _extractMerchantPrefix(sample.merchantName),
      // 金额区间（脱敏）
      amountRange: _getAmountRange(sample.amount),
      // 最终分类
      finalCategory: sample.finalCategory,
      // 修正类型
      correctionType: sample.correctionType,
      // 用户哈希
      userHash: _hashValue(sample.userId),
      // 时间信息（用于时段分析）
      hour: sample.timestamp.hour,
      dayOfWeek: sample.timestamp.weekday,
      timestamp: DateTime.now(),
    );

    await _reporter.report(pattern);
    debugPrint('Reported category pattern: ${pattern.merchantPrefix} -> ${pattern.finalCategory}');
  }

  /// 提取商家前缀（品牌名）
  String _extractMerchantPrefix(String merchantName) {
    // 移除常见后缀
    final suffixes = ['店', '门店', '分店', '旗舰店', '专卖店', '超市', '便利店', '餐厅', '酒店'];
    String prefix = merchantName;

    for (final suffix in suffixes) {
      if (prefix.endsWith(suffix) && prefix.length > suffix.length + 2) {
        prefix = prefix.substring(0, prefix.length - suffix.length);
        break;
      }
    }

    // 限制长度，保护隐私
    if (prefix.length > 8) {
      prefix = prefix.substring(0, 8);
    }

    return prefix;
  }

  /// 金额区间脱敏
  String _getAmountRange(double amount) {
    if (amount < 10) return '0-10';
    if (amount < 50) return '10-50';
    if (amount < 100) return '50-100';
    if (amount < 200) return '100-200';
    if (amount < 500) return '200-500';
    if (amount < 1000) return '500-1k';
    if (amount < 5000) return '1k-5k';
    return '5k+';
  }

  String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 获取全局分类洞察
  Future<GlobalCategoryInsights> getGlobalInsights({bool forceRefresh = false}) async {
    // 检查缓存
    if (!forceRefresh &&
        _insightsCache != null &&
        _lastInsightsUpdate != null &&
        DateTime.now().difference(_lastInsightsUpdate!) < _cacheExpiry) {
      return _insightsCache!;
    }

    _insightsCache = await _aggregator.aggregate();
    _lastInsightsUpdate = DateTime.now();
    return _insightsCache!;
  }

  /// 获取商家分类建议
  Future<CategorySuggestion?> suggestCategoryForMerchant(
    String merchantName, {
    double? amount,
    int? hour,
  }) async {
    final prefix = _extractMerchantPrefix(merchantName);
    final insights = await getGlobalInsights();

    // 1. 查找商家映射
    final mapping = insights.merchantMappings[prefix];
    if (mapping != null && mapping.confidence >= 0.6) {
      return CategorySuggestion(
        category: mapping.mostLikelyCategory,
        confidence: mapping.confidence,
        source: CategorySuggestionSource.merchantMapping,
        alternatives: _getAlternatives(mapping.categoryDistribution),
        reasoning: '基于群体数据，"$prefix"通常归类为${mapping.mostLikelyCategory}',
      );
    }

    // 2. 根据金额区间推断
    if (amount != null) {
      final amountRange = _getAmountRange(amount);
      final rangeCats = insights.amountRangeCategoryDistribution[amountRange];
      if (rangeCats != null && rangeCats.isNotEmpty) {
        return CategorySuggestion(
          category: rangeCats.first,
          confidence: 0.5,
          source: CategorySuggestionSource.amountInference,
          alternatives: rangeCats.skip(1).take(2).toList(),
          reasoning: '该金额区间常见分类为${rangeCats.first}',
        );
      }
    }

    // 3. 根据时段推断
    if (hour != null) {
      final hourDist = insights.hourCategoryDistribution[hour];
      if (hourDist != null && hourDist.isNotEmpty) {
        final topCategory = hourDist.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        return CategorySuggestion(
          category: topCategory,
          confidence: 0.4,
          source: CategorySuggestionSource.timeInference,
          alternatives: [],
          reasoning: '该时段常见消费类型为$topCategory',
        );
      }
    }

    return null;
  }

  List<String> _getAlternatives(Map<String, double> distribution) {
    final sorted = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.skip(1).take(2).map((e) => e.key).toList();
  }

  /// 获取分类的常见商家
  Future<List<String>> getCommonMerchantsForCategory(String category) async {
    final insights = await getGlobalInsights();
    return insights.categoryPopularity[category]?.commonMerchants ?? [];
  }

  /// 获取分类修正率（用于评估分类质量）
  Future<double> getCategoryCorrectionRate(String category) async {
    final insights = await getGlobalInsights();
    return insights.categoryPopularity[category]?.correctionRate ?? 0.0;
  }

  /// 批量上报样本
  Future<void> reportBatch(List<CategoryLearningSample> samples) async {
    for (final sample in samples) {
      await reportCategoryPattern(sample);
    }
  }

  /// 获取社区分类排行
  Future<List<CategoryRanking>> getCategoryRankings() async {
    final insights = await getGlobalInsights();

    final rankings = insights.categoryPopularity.entries.map((e) {
      return CategoryRanking(
        category: e.key,
        usageRatio: e.value.usageRatio,
        correctionRate: e.value.correctionRate,
        rank: 0, // 稍后计算
      );
    }).toList();

    rankings.sort((a, b) => b.usageRatio.compareTo(a.usageRatio));

    for (int i = 0; i < rankings.length; i++) {
      rankings[i] = CategoryRanking(
        category: rankings[i].category,
        usageRatio: rankings[i].usageRatio,
        correctionRate: rankings[i].correctionRate,
        rank: i + 1,
      );
    }

    return rankings;
  }
}

/// 分类建议
class CategorySuggestion {
  final String category;
  final double confidence;
  final CategorySuggestionSource source;
  final List<String> alternatives;
  final String reasoning;

  const CategorySuggestion({
    required this.category,
    required this.confidence,
    required this.source,
    required this.alternatives,
    required this.reasoning,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'confidence': confidence,
        'source': source.name,
        'alternatives': alternatives,
        'reasoning': reasoning,
      };
}

/// 分类建议来源
enum CategorySuggestionSource {
  merchantMapping, // 商家映射
  amountInference, // 金额推断
  timeInference, // 时段推断
  collaborative, // 协同学习
}

/// 分类排行
class CategoryRanking {
  final String category;
  final double usageRatio;
  final double correctionRate;
  final int rank;

  const CategoryRanking({
    required this.category,
    required this.usageRatio,
    required this.correctionRate,
    required this.rank,
  });
}

// ==================== 模式上报器 ====================

/// 分类模式上报器接口
abstract class CategoryPatternReporter {
  Future<void> report(SanitizedCategoryPattern pattern);
  Future<List<SanitizedCategoryPattern>> getAllPatterns();
}

/// 内存分类模式上报器
class InMemoryCategoryPatternReporter implements CategoryPatternReporter {
  final List<SanitizedCategoryPattern> _patterns = [];

  @override
  Future<void> report(SanitizedCategoryPattern pattern) async {
    _patterns.add(pattern);
  }

  @override
  Future<List<SanitizedCategoryPattern>> getAllPatterns() async {
    return List.unmodifiable(_patterns);
  }

  void clear() => _patterns.clear();
}

// ==================== 全局分类洞察聚合 ====================

/// 全局分类洞察聚合器
class GlobalCategoryInsightsAggregator {
  final CategoryPatternReporter _db;

  GlobalCategoryInsightsAggregator({CategoryPatternReporter? db})
      : _db = db ?? InMemoryCategoryPatternReporter();

  /// 聚合群体分类偏好
  Future<GlobalCategoryInsights> aggregate() async {
    final patterns = await _db.getAllPatterns();

    return GlobalCategoryInsights(
      // 商家-分类映射
      merchantMappings: _aggregateMerchantMappings(patterns),
      // 分类流行度
      categoryPopularity: _aggregateCategoryPopularity(patterns),
      // 金额区间分类分布
      amountRangeCategoryDistribution: _aggregateAmountRangeDistribution(patterns),
      // 时段分类分布
      hourCategoryDistribution: _aggregateHourDistribution(patterns),
      generatedAt: DateTime.now(),
    );
  }

  Map<String, MerchantCategoryMapping> _aggregateMerchantMappings(
    List<SanitizedCategoryPattern> patterns,
  ) {
    final result = <String, MerchantCategoryMapping>{};

    // 按商家前缀分组
    final byMerchant = groupBy(patterns, (p) => p.merchantPrefix);

    for (final entry in byMerchant.entries) {
      if (entry.value.length >= 3) { // 至少3个样本
        final categoryCount = <String, int>{};
        for (final pattern in entry.value) {
          categoryCount[pattern.finalCategory] =
              (categoryCount[pattern.finalCategory] ?? 0) + 1;
        }

        final total = entry.value.length;
        final categoryDistribution = <String, double>{};
        for (final catEntry in categoryCount.entries) {
          categoryDistribution[catEntry.key] = catEntry.value / total;
        }

        final mostLikely = categoryCount.entries
            .reduce((a, b) => a.value > b.value ? a : b);

        result[entry.key] = MerchantCategoryMapping(
          merchantPrefix: entry.key,
          mostLikelyCategory: mostLikely.key,
          confidence: mostLikely.value / total,
          categoryDistribution: categoryDistribution,
          sampleCount: total,
        );
      }
    }

    // 添加默认商家映射
    _addDefaultMerchantMappings(result);

    return result;
  }

  void _addDefaultMerchantMappings(Map<String, MerchantCategoryMapping> result) {
    final defaults = <String, String>{
      '星巴克': '餐饮',
      '麦当劳': '餐饮',
      '肯德基': '餐饮',
      '美团': '餐饮',
      '饿了么': '餐饮',
      '滴滴': '交通',
      '高德': '交通',
      '中国石油': '交通',
      '中国石化': '交通',
      '淘宝': '购物',
      '京东': '购物',
      '拼多多': '购物',
      '天猫': '购物',
      '苏宁': '购物',
      '永辉': '购物',
      '盒马': '购物',
      '大润发': '购物',
      '沃尔玛': '购物',
      '万达': '娱乐',
      '电影': '娱乐',
      '网易': '娱乐',
      '腾讯': '娱乐',
      '爱奇艺': '娱乐',
      '优酷': '娱乐',
      '医院': '医疗',
      '药房': '医疗',
      '药店': '医疗',
      '学校': '教育',
      '培训': '教育',
      '书店': '教育',
      '电费': '居住',
      '水费': '居住',
      '燃气': '居住',
      '物业': '居住',
      '房租': '居住',
    };

    for (final entry in defaults.entries) {
      result.putIfAbsent(
        entry.key,
        () => MerchantCategoryMapping(
          merchantPrefix: entry.key,
          mostLikelyCategory: entry.value,
          confidence: 0.9,
          categoryDistribution: {entry.value: 1.0},
          sampleCount: 100, // 默认值
        ),
      );
    }
  }

  Map<String, CategoryPopularity> _aggregateCategoryPopularity(
    List<SanitizedCategoryPattern> patterns,
  ) {
    final result = <String, CategoryPopularity>{};
    final total = patterns.length;
    if (total == 0) return _getDefaultCategoryPopularity();

    // 按分类分组
    final byCategory = groupBy(patterns, (p) => p.finalCategory);

    for (final entry in byCategory.entries) {
      final categoryPatterns = entry.value;
      final usageRatio = categoryPatterns.length / total;

      // 计算修正率
      final corrected = categoryPatterns
          .where((p) => p.correctionType == CategoryCorrectionType.userCorrected)
          .length;
      final correctionRate = categoryPatterns.isEmpty
          ? 0.0
          : corrected / categoryPatterns.length;

      // 找出常见商家
      final merchantCounts = <String, int>{};
      for (final pattern in categoryPatterns) {
        merchantCounts[pattern.merchantPrefix] =
            (merchantCounts[pattern.merchantPrefix] ?? 0) + 1;
      }
      final commonMerchants = merchantCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      result[entry.key] = CategoryPopularity(
        categoryName: entry.key,
        usageRatio: usageRatio,
        correctionRate: correctionRate,
        commonMerchants: commonMerchants.take(5).map((e) => e.key).toList(),
      );
    }

    return result;
  }

  Map<String, CategoryPopularity> _getDefaultCategoryPopularity() {
    return {
      '餐饮': const CategoryPopularity(
        categoryName: '餐饮',
        usageRatio: 0.25,
        correctionRate: 0.05,
        commonMerchants: ['美团', '饿了么', '星巴克', '麦当劳'],
      ),
      '交通': const CategoryPopularity(
        categoryName: '交通',
        usageRatio: 0.12,
        correctionRate: 0.03,
        commonMerchants: ['滴滴', '高德', '中国石油'],
      ),
      '购物': const CategoryPopularity(
        categoryName: '购物',
        usageRatio: 0.20,
        correctionRate: 0.08,
        commonMerchants: ['淘宝', '京东', '拼多多'],
      ),
      '娱乐': const CategoryPopularity(
        categoryName: '娱乐',
        usageRatio: 0.08,
        correctionRate: 0.10,
        commonMerchants: ['网易', '腾讯', '爱奇艺'],
      ),
      '居住': const CategoryPopularity(
        categoryName: '居住',
        usageRatio: 0.20,
        correctionRate: 0.02,
        commonMerchants: ['物业', '电费', '水费'],
      ),
      '医疗': const CategoryPopularity(
        categoryName: '医疗',
        usageRatio: 0.05,
        correctionRate: 0.05,
        commonMerchants: ['医院', '药房'],
      ),
      '教育': const CategoryPopularity(
        categoryName: '教育',
        usageRatio: 0.05,
        correctionRate: 0.06,
        commonMerchants: ['培训', '书店'],
      ),
      '其他': const CategoryPopularity(
        categoryName: '其他',
        usageRatio: 0.05,
        correctionRate: 0.15,
        commonMerchants: [],
      ),
    };
  }

  Map<String, List<String>> _aggregateAmountRangeDistribution(
    List<SanitizedCategoryPattern> patterns,
  ) {
    final result = <String, List<String>>{};

    // 按金额区间分组
    final byAmount = groupBy(patterns, (p) => p.amountRange);

    for (final entry in byAmount.entries) {
      final categoryCount = <String, int>{};
      for (final pattern in entry.value) {
        categoryCount[pattern.finalCategory] =
            (categoryCount[pattern.finalCategory] ?? 0) + 1;
      }

      final sorted = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      result[entry.key] = sorted.take(3).map((e) => e.key).toList();
    }

    // 添加默认分布
    _addDefaultAmountRangeDistribution(result);

    return result;
  }

  void _addDefaultAmountRangeDistribution(Map<String, List<String>> result) {
    result.putIfAbsent('0-10', () => ['餐饮', '交通']);
    result.putIfAbsent('10-50', () => ['餐饮', '交通', '购物']);
    result.putIfAbsent('50-100', () => ['餐饮', '购物', '娱乐']);
    result.putIfAbsent('100-200', () => ['购物', '餐饮', '娱乐']);
    result.putIfAbsent('200-500', () => ['购物', '餐饮', '医疗']);
    result.putIfAbsent('500-1k', () => ['购物', '居住', '医疗']);
    result.putIfAbsent('1k-5k', () => ['居住', '购物', '教育']);
    result.putIfAbsent('5k+', () => ['居住', '教育', '医疗']);
  }

  Map<int, Map<String, double>> _aggregateHourDistribution(
    List<SanitizedCategoryPattern> patterns,
  ) {
    final result = <int, Map<String, double>>{};

    // 按小时分组
    final byHour = groupBy(
      patterns.where((p) => p.hour != null),
      (p) => p.hour!,
    );

    for (final entry in byHour.entries) {
      final categoryCount = <String, int>{};
      for (final pattern in entry.value) {
        categoryCount[pattern.finalCategory] =
            (categoryCount[pattern.finalCategory] ?? 0) + 1;
      }

      final total = entry.value.length;
      final distribution = <String, double>{};
      for (final catEntry in categoryCount.entries) {
        distribution[catEntry.key] = catEntry.value / total;
      }

      result[entry.key] = distribution;
    }

    // 添加默认时段分布
    _addDefaultHourDistribution(result);

    return result;
  }

  void _addDefaultHourDistribution(Map<int, Map<String, double>> result) {
    // 早餐时段 7-9点
    for (int h = 7; h <= 9; h++) {
      result.putIfAbsent(h, () => {'餐饮': 0.6, '交通': 0.3, '其他': 0.1});
    }
    // 午餐时段 11-13点
    for (int h = 11; h <= 13; h++) {
      result.putIfAbsent(h, () => {'餐饮': 0.7, '购物': 0.2, '其他': 0.1});
    }
    // 下午时段 14-17点
    for (int h = 14; h <= 17; h++) {
      result.putIfAbsent(h, () => {'购物': 0.4, '娱乐': 0.3, '其他': 0.3});
    }
    // 晚餐时段 18-20点
    for (int h = 18; h <= 20; h++) {
      result.putIfAbsent(h, () => {'餐饮': 0.5, '购物': 0.3, '娱乐': 0.2});
    }
    // 夜间时段 21-23点
    for (int h = 21; h <= 23; h++) {
      result.putIfAbsent(h, () => {'娱乐': 0.4, '购物': 0.3, '餐饮': 0.3});
    }
  }
}

// ==================== 分类学习整合服务 ====================

/// 分类学习整合服务（整合本地学习与协同学习）
class CategoryLearningIntegrationService {
  final CategoryCollaborativeLearningService _collaborativeService;
  final List<CategoryLearningSample> _localSamples = [];
  final Map<String, String> _localMerchantRules = {};

  // 配置
  static const int _localRuleMinSamples = 2;

  CategoryLearningIntegrationService({
    CategoryCollaborativeLearningService? collaborativeService,
  }) : _collaborativeService =
            collaborativeService ?? CategoryCollaborativeLearningService();

  /// 获取分类建议（整合本地与协同）
  Future<CategorySuggestion?> suggestCategory({
    required String merchantName,
    double? amount,
    int? hour,
  }) async {
    final merchantPrefix = _extractPrefix(merchantName);

    // 1. 本地规则优先
    if (_localMerchantRules.containsKey(merchantPrefix)) {
      return CategorySuggestion(
        category: _localMerchantRules[merchantPrefix]!,
        confidence: 0.95,
        source: CategorySuggestionSource.merchantMapping,
        alternatives: [],
        reasoning: '基于您的历史记录',
      );
    }

    // 2. 协同学习建议
    final collaborativeSuggestion =
        await _collaborativeService.suggestCategoryForMerchant(
      merchantName,
      amount: amount,
      hour: hour,
    );

    return collaborativeSuggestion;
  }

  String _extractPrefix(String merchantName) {
    final suffixes = ['店', '门店', '分店', '旗舰店', '专卖店'];
    String prefix = merchantName;
    for (final suffix in suffixes) {
      if (prefix.endsWith(suffix) && prefix.length > suffix.length + 2) {
        prefix = prefix.substring(0, prefix.length - suffix.length);
        break;
      }
    }
    return prefix.length > 8 ? prefix.substring(0, 8) : prefix;
  }

  /// 记录分类反馈
  Future<void> recordFeedback({
    required String merchantName,
    required double amount,
    String? originalCategory,
    required String finalCategory,
    required CategoryCorrectionType correctionType,
  }) async {
    final sample = CategoryLearningSample(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user',
      merchantName: merchantName,
      amount: amount,
      originalCategory: originalCategory,
      finalCategory: finalCategory,
      correctionType: correctionType,
      timestamp: DateTime.now(),
    );

    _localSamples.add(sample);

    // 更新本地规则
    _updateLocalRules(merchantName, finalCategory);

    // 上报到协同学习
    await _collaborativeService.reportCategoryPattern(sample);
  }

  void _updateLocalRules(String merchantName, String category) {
    final prefix = _extractPrefix(merchantName);

    // 统计该商家前缀的分类
    final relevantSamples = _localSamples
        .where((s) => _extractPrefix(s.merchantName) == prefix)
        .toList();

    if (relevantSamples.length >= _localRuleMinSamples) {
      final categoryCount = <String, int>{};
      for (final sample in relevantSamples) {
        categoryCount[sample.finalCategory] =
            (categoryCount[sample.finalCategory] ?? 0) + 1;
      }

      final mostFrequent = categoryCount.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      if (mostFrequent.value >= _localRuleMinSamples) {
        _localMerchantRules[prefix] = mostFrequent.key;
        debugPrint('Local rule created: $prefix -> ${mostFrequent.key}');
      }
    }
  }

  /// 获取本地规则数量
  int get localRulesCount => _localMerchantRules.length;

  /// 获取本地样本数量
  int get localSamplesCount => _localSamples.length;

  /// 导出本地规则
  Map<String, String> exportLocalRules() {
    return Map.unmodifiable(_localMerchantRules);
  }

  /// 导入本地规则
  void importLocalRules(Map<String, String> rules) {
    _localMerchantRules.addAll(rules);
  }
}
