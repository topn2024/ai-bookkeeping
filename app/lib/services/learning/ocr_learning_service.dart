import 'dart:convert';

import 'package:collection/collection.dart'; // ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ==================== OCR学习数据模型 ====================

/// OCR学习样本
class OCRLearningSample {
  final String id;
  final String userId;
  final OCRImageType imageType;
  final String ocrRawText;
  final OCRParseResult? systemResult;
  final OCRParseResult? userCorrectedResult;
  final OCRCorrectionType correctionType;
  final double confidence;
  final Map<String, dynamic> imageMetadata;
  final DateTime timestamp;

  const OCRLearningSample({
    required this.id,
    required this.userId,
    required this.imageType,
    required this.ocrRawText,
    this.systemResult,
    this.userCorrectedResult,
    required this.correctionType,
    required this.confidence,
    this.imageMetadata = const {},
    required this.timestamp,
  });

  bool get wasCorrect =>
      userCorrectedResult == null ||
      (systemResult?.amount == userCorrectedResult?.amount &&
          systemResult?.merchant == userCorrectedResult?.merchant);

  double get qualityScore {
    var score = 0.0;
    if (correctionType == OCRCorrectionType.confirmed) score += 0.5;
    if (correctionType == OCRCorrectionType.corrected) score += 0.4;
    if (confidence > 0.9) score += 0.2;
    if (userCorrectedResult != null) score += 0.2;
    return score.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'image_type': imageType.name,
        'ocr_raw_text': ocrRawText,
        'system_result': systemResult?.toJson(),
        'user_corrected_result': userCorrectedResult?.toJson(),
        'correction_type': correctionType.name,
        'confidence': confidence,
        'image_metadata': imageMetadata,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// OCR图片类型
enum OCRImageType {
  receipt, // 小票
  invoice, // 发票
  screenshot, // 截图
  bankStatement, // 银行对账单
  other, // 其他
}

/// OCR修正类型
enum OCRCorrectionType {
  confirmed, // 用户确认
  corrected, // 用户修正
  rejected, // 用户拒绝
  partial, // 部分修正
}

/// OCR解析结果
class OCRParseResult {
  final double? amount;
  final String? merchant;
  final String? category;
  final DateTime? date;
  final List<OCRLineItem> items;
  final Map<String, dynamic> extra;

  const OCRParseResult({
    this.amount,
    this.merchant,
    this.category,
    this.date,
    this.items = const [],
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'merchant': merchant,
        'category': category,
        'date': date?.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'extra': extra,
      };
}

/// OCR行项目
class OCRLineItem {
  final String name;
  final double price;
  final int quantity;

  const OCRLineItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'quantity': quantity,
      };
}

// ==================== OCR学习规则 ====================

/// OCR学习规则
class OCRLearnedRule {
  final String ruleId;
  final OCRImageType imageType;
  final OCRRuleType ruleType;
  final String pattern;
  final String extractionTarget;
  final double confidence;
  final OCRRuleSource source;
  final int hitCount;
  final int successCount;
  final DateTime createdAt;

  OCRLearnedRule({
    required this.ruleId,
    required this.imageType,
    required this.ruleType,
    required this.pattern,
    required this.extractionTarget,
    required this.confidence,
    required this.source,
    this.hitCount = 0,
    this.successCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get successRate => hitCount > 0 ? successCount / hitCount : 0;

  OCRLearnedRule copyWith({
    double? confidence,
    int? hitCount,
    int? successCount,
  }) {
    return OCRLearnedRule(
      ruleId: ruleId,
      imageType: imageType,
      ruleType: ruleType,
      pattern: pattern,
      extractionTarget: extractionTarget,
      confidence: confidence ?? this.confidence,
      source: source,
      hitCount: hitCount ?? this.hitCount,
      successCount: successCount ?? this.successCount,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'rule_id': ruleId,
        'image_type': imageType.name,
        'rule_type': ruleType.name,
        'pattern': pattern,
        'extraction_target': extractionTarget,
        'confidence': confidence,
        'source': source.name,
        'hit_count': hitCount,
        'success_count': successCount,
        'created_at': createdAt.toIso8601String(),
      };
}

/// OCR规则类型
enum OCRRuleType {
  amountExtraction, // 金额提取
  merchantExtraction, // 商家提取
  dateExtraction, // 日期提取
  categoryInference, // 分类推断
  layoutRecognition, // 布局识别
}

/// OCR规则来源
enum OCRRuleSource {
  userLearned, // 用户学习
  collaborative, // 协同学习
  systemDefault, // 系统默认
}

// ==================== OCR学习阶段 ====================

/// OCR学习阶段
enum OCRLearningStage {
  coldStart, // 冷启动
  collecting, // 样本收集中
  active, // 正常运行
}

// ==================== OCR自学习服务 ====================

/// OCR自学习服务
class OCRLearningService {
  final OCRDataStore _dataStore;
  final List<OCRLearnedRule> _learnedRules = [];
  final Map<String, _MerchantPattern> _merchantPatterns = {};

  // 配置
  static const int _minSamplesForLearning = 5;
  static const int _minSamplesForRule = 3;
  static const double _minConfidenceThreshold = 0.7;

  String get moduleId => 'ocr_learning';
  OCRLearningStage stage = OCRLearningStage.coldStart;
  double accuracy = 0.0;

  OCRLearningService({
    OCRDataStore? dataStore,
  }) : _dataStore = dataStore ?? InMemoryOCRDataStore();

  /// 学习OCR样本
  Future<void> learn(OCRLearningSample sample) async {
    await _dataStore.saveSample(sample);

    // 更新商家模式
    if (sample.userCorrectedResult?.merchant != null ||
        sample.systemResult?.merchant != null) {
      _updateMerchantPattern(sample);
    }

    // 检查学习阶段
    final sampleCount = await _dataStore.getSampleCount();
    if (sampleCount >= _minSamplesForLearning &&
        stage == OCRLearningStage.coldStart) {
      stage = OCRLearningStage.collecting;
    }

    if (sampleCount >= _minSamplesForLearning * 2) {
      await _triggerRuleLearning();
      stage = OCRLearningStage.active;
    }
  }

  void _updateMerchantPattern(OCRLearningSample sample) {
    final merchant = sample.userCorrectedResult?.merchant ??
        sample.systemResult?.merchant;
    if (merchant == null) return;

    // 提取商家名称的特征词
    final keywords = _extractKeywords(sample.ocrRawText);
    for (final keyword in keywords) {
      _merchantPatterns.putIfAbsent(keyword, () => _MerchantPattern());
      _merchantPatterns[keyword]!.addMerchant(merchant);
    }
  }

  List<String> _extractKeywords(String text) {
    final words = text.split(RegExp(r'\s+'));
    return words
        .where((w) => w.length >= 2 && w.length <= 10)
        .take(10)
        .toList();
  }

  /// 触发规则学习
  Future<void> _triggerRuleLearning() async {
    final samples = await _dataStore.getAllSamples(months: 6);
    if (samples.isEmpty) return;

    _learnedRules.clear();

    // 学习金额提取规则
    await _learnAmountRules(samples);

    // 学习商家提取规则
    await _learnMerchantRules(samples);

    // 学习分类推断规则
    await _learnCategoryRules(samples);

    debugPrint('Learned ${_learnedRules.length} OCR rules');
  }

  Future<void> _learnAmountRules(List<OCRLearningSample> samples) async {
    // 按图片类型分组
    final byType = groupBy(samples, (s) => s.imageType);

    for (final entry in byType.entries) {
      final typeSamples = entry.value;
      if (typeSamples.length < _minSamplesForRule) continue;

      // 分析金额提取模式
      final amountPatterns = <String, int>{};
      for (final sample in typeSamples) {
        final amount = sample.userCorrectedResult?.amount ??
            sample.systemResult?.amount;
        if (amount == null) continue;

        // 查找金额在原文中的位置和上下文
        final pattern = _findAmountPattern(sample.ocrRawText, amount);
        if (pattern != null) {
          amountPatterns[pattern] = (amountPatterns[pattern] ?? 0) + 1;
        }
      }

      // 生成规则
      for (final patternEntry in amountPatterns.entries) {
        if (patternEntry.value >= _minSamplesForRule) {
          _learnedRules.add(OCRLearnedRule(
            ruleId: 'amount_${entry.key.name}_${DateTime.now().millisecondsSinceEpoch}',
            imageType: entry.key,
            ruleType: OCRRuleType.amountExtraction,
            pattern: patternEntry.key,
            extractionTarget: 'amount',
            confidence: patternEntry.value / typeSamples.length,
            source: OCRRuleSource.userLearned,
            hitCount: patternEntry.value,
            successCount: patternEntry.value,
          ));
        }
      }
    }
  }

  String? _findAmountPattern(String text, double amount) {
    // amountStr 和 amountInt 用于未来扩展精确金额匹配
    // ignore: unused_local_variable
    final amountStr = amount.toStringAsFixed(2);
    // ignore: unused_local_variable
    final amountInt = amount.toInt().toString();

    // 查找金额关键词
    final keywords = ['合计', '总计', '实付', '金额', '总额', 'TOTAL', '应付'];
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return '$keyword.*{amount}';
      }
    }

    // 检查是否有货币符号
    if (text.contains('¥') || text.contains('￥')) {
      return '¥{amount}';
    }
    if (text.contains('元')) {
      return '{amount}元';
    }

    return null;
  }

  Future<void> _learnMerchantRules(List<OCRLearningSample> samples) async {
    // 提取高频商家-关键词映射
    for (final entry in _merchantPatterns.entries) {
      if (entry.value.count >= _minSamplesForRule) {
        final topMerchant = entry.value.getMostFrequent();
        if (topMerchant != null) {
          _learnedRules.add(OCRLearnedRule(
            ruleId: 'merchant_${entry.key.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            imageType: OCRImageType.receipt,
            ruleType: OCRRuleType.merchantExtraction,
            pattern: entry.key,
            extractionTarget: topMerchant,
            confidence: entry.value.getConfidence(topMerchant),
            source: OCRRuleSource.userLearned,
            hitCount: entry.value.count,
            successCount: entry.value.getMerchantCount(topMerchant),
          ));
        }
      }
    }
  }

  Future<void> _learnCategoryRules(List<OCRLearningSample> samples) async {
    // 按商家-分类对分组
    final merchantCategory = <String, Map<String, int>>{};

    for (final sample in samples) {
      final merchant = sample.userCorrectedResult?.merchant ??
          sample.systemResult?.merchant;
      final category = sample.userCorrectedResult?.category ??
          sample.systemResult?.category;

      if (merchant != null && category != null) {
        merchantCategory.putIfAbsent(merchant, () => {});
        merchantCategory[merchant]![category] =
            (merchantCategory[merchant]![category] ?? 0) + 1;
      }
    }

    // 生成分类推断规则
    for (final entry in merchantCategory.entries) {
      final total = entry.value.values.fold(0, (a, b) => a + b);
      if (total >= _minSamplesForRule) {
        final topCategory = entry.value.entries
            .reduce((a, b) => a.value > b.value ? a : b);

        if (topCategory.value / total >= _minConfidenceThreshold) {
          _learnedRules.add(OCRLearnedRule(
            ruleId: 'category_${entry.key.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            imageType: OCRImageType.receipt,
            ruleType: OCRRuleType.categoryInference,
            pattern: entry.key,
            extractionTarget: topCategory.key,
            confidence: topCategory.value / total,
            source: OCRRuleSource.userLearned,
            hitCount: total,
            successCount: topCategory.value,
          ));
        }
      }
    }
  }

  /// 应用学习规则增强OCR结果
  Future<OCRParseResult> enhance(
    OCRParseResult original,
    String ocrText,
    OCRImageType imageType,
  ) async {
    var enhanced = original;

    // 应用商家识别规则
    if (enhanced.merchant == null) {
      enhanced = _applyMerchantRules(enhanced, ocrText, imageType);
    }

    // 应用分类推断规则
    if (enhanced.category == null && enhanced.merchant != null) {
      enhanced = _applyCategoryRules(enhanced, imageType);
    }

    return enhanced;
  }

  OCRParseResult _applyMerchantRules(
    OCRParseResult result,
    String ocrText,
    OCRImageType imageType,
  ) {
    final merchantRules = _learnedRules.where(
      (r) => r.ruleType == OCRRuleType.merchantExtraction &&
          (r.imageType == imageType || r.imageType == OCRImageType.other),
    );

    for (final rule in merchantRules) {
      if (ocrText.contains(rule.pattern)) {
        return OCRParseResult(
          amount: result.amount,
          merchant: rule.extractionTarget,
          category: result.category,
          date: result.date,
          items: result.items,
          extra: {...result.extra, 'merchant_source': 'learned_rule'},
        );
      }
    }

    return result;
  }

  OCRParseResult _applyCategoryRules(
    OCRParseResult result,
    OCRImageType imageType,
  ) {
    if (result.merchant == null) return result;

    final categoryRules = _learnedRules.where(
      (r) => r.ruleType == OCRRuleType.categoryInference &&
          r.pattern == result.merchant,
    );

    for (final rule in categoryRules) {
      if (rule.confidence >= _minConfidenceThreshold) {
        return OCRParseResult(
          amount: result.amount,
          merchant: result.merchant,
          category: rule.extractionTarget,
          date: result.date,
          items: result.items,
          extra: {...result.extra, 'category_source': 'learned_rule'},
        );
      }
    }

    return result;
  }

  /// 用户反馈
  Future<void> feedback(OCRLearningSample sample, bool positive) async {
    // 更新规则置信度
    for (int i = 0; i < _learnedRules.length; i++) {
      final rule = _learnedRules[i];
      if (sample.ocrRawText.contains(rule.pattern)) {
        _learnedRules[i] = rule.copyWith(
          hitCount: rule.hitCount + 1,
          successCount: positive ? rule.successCount + 1 : rule.successCount,
          confidence: positive
              ? (rule.confidence * 1.02).clamp(0.0, 1.0)
              : (rule.confidence * 0.98).clamp(0.0, 1.0),
        );
      }
    }

    await _updateAccuracy();
  }

  Future<void> _updateAccuracy() async {
    final recentSamples = await _dataStore.getRecentSamples(limit: 100);
    if (recentSamples.isEmpty) return;

    final correct = recentSamples.where((s) => s.wasCorrect).length;
    accuracy = correct / recentSamples.length;
  }

  /// 导出规则
  Future<List<OCRLearnedRule>> exportRules() async {
    return List.unmodifiable(_learnedRules);
  }

  /// 获取统计
  Future<OCRLearningStats> getStats() async {
    return OCRLearningStats(
      moduleId: moduleId,
      stage: stage,
      accuracy: accuracy,
      rulesCount: _learnedRules.length,
      merchantPatternsCount: _merchantPatterns.length,
    );
  }
}

class _MerchantPattern {
  final Map<String, int> _merchants = {};
  int count = 0;

  void addMerchant(String merchant) {
    _merchants[merchant] = (_merchants[merchant] ?? 0) + 1;
    count++;
  }

  String? getMostFrequent() {
    if (_merchants.isEmpty) return null;
    return _merchants.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  double getConfidence(String merchant) {
    if (count == 0) return 0;
    return (_merchants[merchant] ?? 0) / count;
  }

  int getMerchantCount(String merchant) {
    return _merchants[merchant] ?? 0;
  }
}

/// OCR学习统计
class OCRLearningStats {
  final String moduleId;
  final OCRLearningStage stage;
  final double accuracy;
  final int rulesCount;
  final int merchantPatternsCount;

  const OCRLearningStats({
    required this.moduleId,
    required this.stage,
    required this.accuracy,
    required this.rulesCount,
    required this.merchantPatternsCount,
  });
}

// ==================== 脱敏数据模型 ====================

/// 脱敏后的OCR模式
class SanitizedOCRPattern {
  final OCRImageType imageType;
  final String layoutPattern;
  final String amountPattern;
  final String? merchantPrefix;
  final String? category;
  final String userHash;
  final DateTime timestamp;

  const SanitizedOCRPattern({
    required this.imageType,
    required this.layoutPattern,
    required this.amountPattern,
    this.merchantPrefix,
    this.category,
    required this.userHash,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'image_type': imageType.name,
        'layout_pattern': layoutPattern,
        'amount_pattern': amountPattern,
        'merchant_prefix': merchantPrefix,
        'category': category,
        'user_hash': userHash,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ==================== 全局OCR洞察 ====================

/// 全局OCR洞察
class GlobalOCRInsights {
  final Map<OCRImageType, OCRTypeInsight> typeInsights;
  final Map<String, String> commonMerchantCategories;
  final List<String> popularAmountPatterns;
  final DateTime generatedAt;

  const GlobalOCRInsights({
    required this.typeInsights,
    required this.commonMerchantCategories,
    required this.popularAmountPatterns,
    required this.generatedAt,
  });
}

/// OCR类型洞察
class OCRTypeInsight {
  final OCRImageType imageType;
  final List<String> commonLayoutPatterns;
  final List<String> commonAmountPatterns;
  final double averageAccuracy;
  final int sampleCount;

  const OCRTypeInsight({
    required this.imageType,
    required this.commonLayoutPatterns,
    required this.commonAmountPatterns,
    required this.averageAccuracy,
    required this.sampleCount,
  });
}

// ==================== OCR协同学习服务 ====================

/// OCR协同学习服务
class OCRCollaborativeLearningService {
  final GlobalOCRInsightsAggregator _aggregator;
  final OCRPatternReporter _reporter;
  final String _currentUserId; // ignore: unused_field

  // 本地缓存
  GlobalOCRInsights? _insightsCache;
  DateTime? _lastInsightsUpdate;

  // 配置
  static const Duration _cacheExpiry = Duration(hours: 24);

  OCRCollaborativeLearningService({
    GlobalOCRInsightsAggregator? aggregator,
    OCRPatternReporter? reporter,
    String? currentUserId,
  })  : _aggregator = aggregator ?? GlobalOCRInsightsAggregator(),
        _reporter = reporter ?? InMemoryOCRPatternReporter(),
        _currentUserId = currentUserId ?? 'anonymous';

  /// 上报OCR模式（隐私保护）
  Future<void> reportOCRPattern(OCRLearningSample sample) async {
    if (sample.qualityScore < 0.5) return;

    final pattern = SanitizedOCRPattern(
      imageType: sample.imageType,
      layoutPattern: _extractLayoutPattern(sample.ocrRawText),
      amountPattern: _extractAmountPattern(sample.ocrRawText),
      merchantPrefix: _extractMerchantPrefix(
        sample.userCorrectedResult?.merchant ?? sample.systemResult?.merchant,
      ),
      category: sample.userCorrectedResult?.category ?? sample.systemResult?.category,
      userHash: _hashValue(sample.userId),
      timestamp: DateTime.now(),
    );

    await _reporter.report(pattern);
    debugPrint('Reported OCR pattern: ${pattern.imageType.name}');
  }

  String _extractLayoutPattern(String text) {
    // 提取布局特征（行数、关键词位置等）
    final lines = text.split('\n');
    final lineCount = lines.length;

    final hasTotal = text.contains(RegExp(r'合计|总计|TOTAL', caseSensitive: false));
    final hasCurrency = text.contains(RegExp(r'¥|￥|元'));

    return 'lines:$lineCount,total:$hasTotal,currency:$hasCurrency';
  }

  String _extractAmountPattern(String text) {
    // 提取金额格式模式
    if (text.contains(RegExp(r'¥\d+\.\d{2}'))) return '¥X.XX';
    if (text.contains(RegExp(r'￥\d+\.\d{2}'))) return '￥X.XX';
    if (text.contains(RegExp(r'\d+\.\d{2}元'))) return 'X.XX元';
    if (text.contains(RegExp(r'\d+元'))) return 'X元';
    return 'unknown';
  }

  String? _extractMerchantPrefix(String? merchant) {
    if (merchant == null) return null;
    // 只保留前4个字符
    return merchant.length > 4 ? merchant.substring(0, 4) : merchant;
  }

  String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 获取全局OCR洞察
  Future<GlobalOCRInsights> getGlobalInsights({bool forceRefresh = false}) async {
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

  /// 获取商家的常见分类
  Future<String?> suggestCategoryForMerchant(String merchant) async {
    final insights = await getGlobalInsights();
    final prefix = _extractMerchantPrefix(merchant);
    if (prefix == null) return null;

    return insights.commonMerchantCategories[prefix];
  }

  /// 获取图片类型的常见模式
  Future<OCRTypeInsight?> getTypeInsight(OCRImageType imageType) async {
    final insights = await getGlobalInsights();
    return insights.typeInsights[imageType];
  }

  /// 批量上报
  Future<void> reportBatch(List<OCRLearningSample> samples) async {
    for (final sample in samples) {
      await reportOCRPattern(sample);
    }
  }
}

// ==================== 模式上报器 ====================

/// OCR模式上报器接口
abstract class OCRPatternReporter {
  Future<void> report(SanitizedOCRPattern pattern);
  Future<List<SanitizedOCRPattern>> getAllPatterns();
}

/// 内存OCR模式上报器
class InMemoryOCRPatternReporter implements OCRPatternReporter {
  final List<SanitizedOCRPattern> _patterns = [];

  @override
  Future<void> report(SanitizedOCRPattern pattern) async {
    _patterns.add(pattern);
  }

  @override
  Future<List<SanitizedOCRPattern>> getAllPatterns() async {
    return List.unmodifiable(_patterns);
  }

  void clear() => _patterns.clear();
}

// ==================== 全局OCR洞察聚合 ====================

/// 全局OCR洞察聚合器
class GlobalOCRInsightsAggregator {
  final OCRPatternReporter _db;

  GlobalOCRInsightsAggregator({OCRPatternReporter? db})
      : _db = db ?? InMemoryOCRPatternReporter();

  Future<GlobalOCRInsights> aggregate() async {
    final patterns = await _db.getAllPatterns();

    return GlobalOCRInsights(
      typeInsights: _aggregateTypeInsights(patterns),
      commonMerchantCategories: _aggregateMerchantCategories(patterns),
      popularAmountPatterns: _aggregateAmountPatterns(patterns),
      generatedAt: DateTime.now(),
    );
  }

  Map<OCRImageType, OCRTypeInsight> _aggregateTypeInsights(
    List<SanitizedOCRPattern> patterns,
  ) {
    final result = <OCRImageType, OCRTypeInsight>{};

    final byType = groupBy(patterns, (p) => p.imageType);

    for (final entry in byType.entries) {
      final typePatterns = entry.value;

      final layoutCounts = <String, int>{};
      final amountCounts = <String, int>{};

      for (final p in typePatterns) {
        layoutCounts[p.layoutPattern] =
            (layoutCounts[p.layoutPattern] ?? 0) + 1;
        amountCounts[p.amountPattern] =
            (amountCounts[p.amountPattern] ?? 0) + 1;
      }

      final sortedLayouts = layoutCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedAmounts = amountCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      result[entry.key] = OCRTypeInsight(
        imageType: entry.key,
        commonLayoutPatterns: sortedLayouts.take(3).map((e) => e.key).toList(),
        commonAmountPatterns: sortedAmounts.take(3).map((e) => e.key).toList(),
        averageAccuracy: 0.85,
        sampleCount: typePatterns.length,
      );
    }

    // 添加默认洞察
    _addDefaultTypeInsights(result);

    return result;
  }

  void _addDefaultTypeInsights(Map<OCRImageType, OCRTypeInsight> result) {
    result.putIfAbsent(
      OCRImageType.receipt,
      () => const OCRTypeInsight(
        imageType: OCRImageType.receipt,
        commonLayoutPatterns: [
          'lines:10-20,total:true,currency:true',
          'lines:5-10,total:true,currency:true',
        ],
        commonAmountPatterns: ['¥X.XX', 'X.XX元'],
        averageAccuracy: 0.88,
        sampleCount: 100,
      ),
    );

    result.putIfAbsent(
      OCRImageType.screenshot,
      () => const OCRTypeInsight(
        imageType: OCRImageType.screenshot,
        commonLayoutPatterns: [
          'lines:5-10,total:false,currency:true',
        ],
        commonAmountPatterns: ['¥X.XX', '-X.XX'],
        averageAccuracy: 0.92,
        sampleCount: 100,
      ),
    );

    result.putIfAbsent(
      OCRImageType.invoice,
      () => const OCRTypeInsight(
        imageType: OCRImageType.invoice,
        commonLayoutPatterns: [
          'lines:20-30,total:true,currency:true',
        ],
        commonAmountPatterns: ['¥X.XX', '￥X.XX'],
        averageAccuracy: 0.85,
        sampleCount: 50,
      ),
    );
  }

  Map<String, String> _aggregateMerchantCategories(
    List<SanitizedOCRPattern> patterns,
  ) {
    final result = <String, String>{};

    final byMerchant = groupBy(
      patterns.where((p) => p.merchantPrefix != null && p.category != null),
      (p) => p.merchantPrefix!,
    );

    for (final entry in byMerchant.entries) {
      if (entry.value.length >= 2) {
        final categoryCounts = <String, int>{};
        for (final p in entry.value) {
          if (p.category != null) {
            categoryCounts[p.category!] =
                (categoryCounts[p.category!] ?? 0) + 1;
          }
        }

        if (categoryCounts.isNotEmpty) {
          final topCategory = categoryCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b);
          if (topCategory.value >= entry.value.length * 0.6) {
            result[entry.key] = topCategory.key;
          }
        }
      }
    }

    // 添加默认映射
    _addDefaultMerchantCategories(result);

    return result;
  }

  void _addDefaultMerchantCategories(Map<String, String> result) {
    final defaults = <String, String>{
      '星巴克': '餐饮',
      '麦当劳': '餐饮',
      '肯德基': '餐饮',
      '永辉超': '购物',
      '沃尔玛': '购物',
      '滴滴出': '交通',
      '中国石': '交通',
    };

    for (final entry in defaults.entries) {
      result.putIfAbsent(entry.key, () => entry.value);
    }
  }

  List<String> _aggregateAmountPatterns(List<SanitizedOCRPattern> patterns) {
    final patternCounts = <String, int>{};

    for (final p in patterns) {
      patternCounts[p.amountPattern] =
          (patternCounts[p.amountPattern] ?? 0) + 1;
    }

    final sorted = patternCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = sorted.take(5).map((e) => e.key).toList();

    if (result.isEmpty) {
      result.addAll(['¥X.XX', 'X.XX元', '￥X.XX']);
    }

    return result;
  }
}

// ==================== 数据存储 ====================

/// OCR数据存储接口
abstract class OCRDataStore {
  Future<void> saveSample(OCRLearningSample sample);
  Future<List<OCRLearningSample>> getAllSamples({int? months});
  Future<List<OCRLearningSample>> getRecentSamples({int limit = 100});
  Future<int> getSampleCount();
}

/// 内存OCR数据存储
class InMemoryOCRDataStore implements OCRDataStore {
  final List<OCRLearningSample> _samples = [];

  @override
  Future<void> saveSample(OCRLearningSample sample) async {
    _samples.add(sample);
  }

  @override
  Future<List<OCRLearningSample>> getAllSamples({int? months}) async {
    if (months == null) return List.unmodifiable(_samples);

    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    return _samples.where((s) => s.timestamp.isAfter(cutoff)).toList();
  }

  @override
  Future<List<OCRLearningSample>> getRecentSamples({int limit = 100}) async {
    final sorted = _samples.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<int> getSampleCount() async {
    return _samples.length;
  }

  void clear() => _samples.clear();
}

// ==================== OCR学习整合服务 ====================

/// OCR学习整合服务（整合本地学习与协同学习）
class OCRLearningIntegrationService {
  final OCRLearningService _localService;
  final OCRCollaborativeLearningService _collaborativeService;

  OCRLearningIntegrationService({
    OCRLearningService? localService,
    OCRCollaborativeLearningService? collaborativeService,
  })  : _localService = localService ?? OCRLearningService(),
        _collaborativeService =
            collaborativeService ?? OCRCollaborativeLearningService();

  /// 增强OCR结果（整合本地与协同学习）
  Future<OCRParseResult> enhanceResult(
    OCRParseResult original,
    String ocrText,
    OCRImageType imageType,
  ) async {
    // 1. 先用本地学习增强
    var enhanced = await _localService.enhance(original, ocrText, imageType);

    // 2. 如果分类仍然缺失，尝试协同学习
    if (enhanced.category == null && enhanced.merchant != null) {
      final suggestedCategory =
          await _collaborativeService.suggestCategoryForMerchant(enhanced.merchant!);
      if (suggestedCategory != null) {
        enhanced = OCRParseResult(
          amount: enhanced.amount,
          merchant: enhanced.merchant,
          category: suggestedCategory,
          date: enhanced.date,
          items: enhanced.items,
          extra: {...enhanced.extra, 'category_source': 'collaborative'},
        );
      }
    }

    return enhanced;
  }

  /// 记录学习样本
  Future<void> recordSample(OCRLearningSample sample) async {
    // 本地学习
    await _localService.learn(sample);

    // 上报协同学习
    await _collaborativeService.reportOCRPattern(sample);
  }

  /// 获取统计信息
  Future<OCRLearningStats> getStats() async {
    return _localService.getStats();
  }
}
