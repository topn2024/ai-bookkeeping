import 'dart:async';

import 'package:flutter/foundation.dart';

/// 反馈学习服务
/// 收集用户反馈，持续优化AI识别准确率
class FeedbackLearningService {
  final FeedbackRepository _repository;
  final MerchantMappingRepository _merchantMapping;
  final KeywordRuleRepository _keywordRules;
  final IncrementalLearningScheduler _scheduler;

  FeedbackLearningService({
    required FeedbackRepository repository,
    required MerchantMappingRepository merchantMapping,
    required KeywordRuleRepository keywordRules,
    IncrementalLearningScheduler? scheduler,
  })  : _repository = repository,
        _merchantMapping = merchantMapping,
        _keywordRules = keywordRules,
        _scheduler = scheduler ?? IncrementalLearningScheduler();

  /// 记录分类修正反馈
  Future<void> recordCategoryCorrection({
    required String transactionId,
    required String originalCategoryId,
    required String correctedCategoryId,
    required double originalConfidence,
    required String originalSource,
    String? merchantName,
    String? description,
    double? amount,
    DateTime? transactionDate,
  }) async {
    final feedback = FeedbackRecord(
      id: _generateId(),
      userId: 'current_user',
      transactionId: transactionId,
      feedbackType: FeedbackType.categoryCorrection,
      originalCategoryId: originalCategoryId,
      originalConfidence: originalConfidence,
      originalSource: originalSource,
      correctedCategoryId: correctedCategoryId,
      merchantName: merchantName,
      description: description,
      amount: amount,
      transactionDate: transactionDate,
      dayOfWeek: transactionDate?.weekday,
      hourOfDay: transactionDate?.hour,
      createdAt: DateTime.now(),
    );

    await _repository.save(feedback);

    // 触发即时学习
    await _applyImmediateLearning(feedback);

    // 检查是否需要批量学习
    _scheduler.checkAndSchedule();
  }

  /// 记录意图修正反馈
  Future<void> recordIntentCorrection({
    required String voiceText,
    required String originalIntent,
    required String correctedIntent,
  }) async {
    final feedback = FeedbackRecord(
      id: _generateId(),
      userId: 'current_user',
      transactionId: '',
      feedbackType: FeedbackType.intentCorrection,
      originalSource: 'voice',
      description: voiceText,
      createdAt: DateTime.now(),
      metadata: {
        'originalIntent': originalIntent,
        'correctedIntent': correctedIntent,
      },
    );

    await _repository.save(feedback);
  }

  /// 记录异常驳回反馈
  Future<void> recordAnomalyDismiss({
    required String transactionId,
    required String anomalyType,
    required String reason,
  }) async {
    final feedback = FeedbackRecord(
      id: _generateId(),
      userId: 'current_user',
      transactionId: transactionId,
      feedbackType: FeedbackType.anomalyDismiss,
      originalSource: 'anomaly_detection',
      createdAt: DateTime.now(),
      metadata: {
        'anomalyType': anomalyType,
        'dismissReason': reason,
      },
    );

    await _repository.save(feedback);
  }

  /// 即时学习（针对高置信度反馈）
  Future<void> _applyImmediateLearning(FeedbackRecord feedback) async {
    if (feedback.feedbackType != FeedbackType.categoryCorrection) return;
    if (feedback.merchantName == null || feedback.merchantName!.isEmpty) return;
    if (feedback.correctedCategoryId == null) return;

    // 更新商家-分类映射
    final existingMapping = await _merchantMapping.findByMerchant(
      feedback.merchantName!,
    );

    if (existingMapping != null) {
      // 更新现有映射
      final updatedMapping = existingMapping.copyWith(
        categoryId: feedback.correctedCategoryId!,
        confidence: _calculateNewConfidence(existingMapping, feedback),
        matchCount: existingMapping.matchCount + 1,
        correctCount: existingMapping.correctCount + 1,
        lastUsedAt: DateTime.now(),
        source: MappingSource.userCorrection,
      );
      await _merchantMapping.update(updatedMapping);
    } else {
      // 创建新映射
      final newMapping = MerchantCategoryMapping(
        id: _generateId(),
        merchantName: feedback.merchantName!,
        merchantNameNormalized: _normalizeMerchantName(feedback.merchantName!),
        categoryId: feedback.correctedCategoryId!,
        confidence: 0.8, // 用户修正的初始置信度
        source: MappingSource.userCorrection,
        matchCount: 1,
        correctCount: 1,
        lastUsedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _merchantMapping.save(newMapping);
    }

    debugPrint('Immediate learning applied for merchant: ${feedback.merchantName}');
  }

  /// 计算新的置信度
  double _calculateNewConfidence(
    MerchantCategoryMapping existing,
    FeedbackRecord feedback,
  ) {
    // 如果修正后的分类与现有分类相同，增加置信度
    if (existing.categoryId == feedback.correctedCategoryId) {
      return (existing.confidence + 0.05).clamp(0.0, 1.0);
    }
    // 否则重置为用户修正的置信度
    return 0.8;
  }

  /// 标准化商家名称
  String _normalizeMerchantName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-z0-9]'), '');
  }

  /// 批量学习（处理累积的反馈）
  Future<LearningResult> runBatchLearning() async {
    final unprocessedFeedbacks = await _repository.getUnprocessed();

    if (unprocessedFeedbacks.isEmpty) {
      return LearningResult(
        processedCount: 0,
        newRulesCount: 0,
        updatedMappingsCount: 0,
      );
    }

    int newRulesCount = 0;
    int updatedMappingsCount = 0;

    // 按商家聚合反馈
    final merchantFeedbacks = <String, List<FeedbackRecord>>{};
    for (final feedback in unprocessedFeedbacks) {
      if (feedback.merchantName != null && feedback.merchantName!.isNotEmpty) {
        merchantFeedbacks
            .putIfAbsent(feedback.merchantName!, () => [])
            .add(feedback);
      }
    }

    // 分析模式并创建/更新规则
    for (final entry in merchantFeedbacks.entries) {
      final feedbacks = entry.value;
      if (feedbacks.length >= 3) {
        // 至少3次反馈才学习
        final result = await _learnFromMerchantFeedbacks(entry.key, feedbacks);
        if (result.newRule) newRulesCount++;
        if (result.updatedMapping) updatedMappingsCount++;
      }
    }

    // 学习关键词模式
    final keywordResult = await _learnKeywordPatterns(unprocessedFeedbacks);
    newRulesCount += keywordResult;

    // 标记反馈为已处理
    for (final feedback in unprocessedFeedbacks) {
      await _repository.markAsProcessed(feedback.id);
    }

    return LearningResult(
      processedCount: unprocessedFeedbacks.length,
      newRulesCount: newRulesCount,
      updatedMappingsCount: updatedMappingsCount,
    );
  }

  /// 从商家反馈中学习
  Future<_MerchantLearningResult> _learnFromMerchantFeedbacks(
    String merchantName,
    List<FeedbackRecord> feedbacks,
  ) async {
    // 统计分类投票
    final categoryVotes = <String, int>{};
    for (final feedback in feedbacks) {
      if (feedback.correctedCategoryId != null) {
        categoryVotes[feedback.correctedCategoryId!] =
            (categoryVotes[feedback.correctedCategoryId!] ?? 0) + 1;
      }
    }

    if (categoryVotes.isEmpty) {
      return _MerchantLearningResult(newRule: false, updatedMapping: false);
    }

    // 选择最高票数的分类
    final topCategory =
        categoryVotes.entries.reduce((a, b) => a.value > b.value ? a : b);

    final consistency = topCategory.value / feedbacks.length;
    if (consistency < 0.6) {
      // 一致性不够，不学习
      return _MerchantLearningResult(newRule: false, updatedMapping: false);
    }

    // 更新或创建映射
    final existing = await _merchantMapping.findByMerchant(merchantName);
    if (existing != null) {
      await _merchantMapping.update(existing.copyWith(
        categoryId: topCategory.key,
        confidence: 0.7 + consistency * 0.2,
        matchCount: existing.matchCount + feedbacks.length,
        correctCount: existing.correctCount + topCategory.value,
        source: MappingSource.frequencyAnalysis,
      ));
      return _MerchantLearningResult(newRule: false, updatedMapping: true);
    } else {
      await _merchantMapping.save(MerchantCategoryMapping(
        id: _generateId(),
        merchantName: merchantName,
        merchantNameNormalized: _normalizeMerchantName(merchantName),
        categoryId: topCategory.key,
        confidence: 0.7 + consistency * 0.2,
        source: MappingSource.frequencyAnalysis,
        matchCount: feedbacks.length,
        correctCount: topCategory.value,
        lastUsedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ));
      return _MerchantLearningResult(newRule: true, updatedMapping: false);
    }
  }

  /// 学习关键词模式
  Future<int> _learnKeywordPatterns(List<FeedbackRecord> feedbacks) async {
    int newRulesCount = 0;

    // 提取描述中的常见词汇
    final wordCategoryFreq = <String, Map<String, int>>{};

    for (final feedback in feedbacks) {
      if (feedback.description == null || feedback.correctedCategoryId == null) {
        continue;
      }

      final words = _extractKeywords(feedback.description!);
      for (final word in words) {
        wordCategoryFreq.putIfAbsent(word, () => {});
        wordCategoryFreq[word]![feedback.correctedCategoryId!] =
            (wordCategoryFreq[word]![feedback.correctedCategoryId!] ?? 0) + 1;
      }
    }

    // 分析高频词汇
    for (final entry in wordCategoryFreq.entries) {
      final word = entry.key;
      final categoryFreq = entry.value;

      // 总出现次数
      final totalCount = categoryFreq.values.reduce((a, b) => a + b);
      if (totalCount < 5) continue; // 至少5次出现

      // 找出主要关联的分类
      final topEntry =
          categoryFreq.entries.reduce((a, b) => a.value > b.value ? a : b);

      final association = topEntry.value / totalCount;
      if (association < 0.7) continue; // 70%以上关联度

      // 检查是否已有此关键词规则
      final existingRule = await _keywordRules.findByKeyword(word);
      if (existingRule == null) {
        await _keywordRules.save(LearnedKeywordRule(
          id: _generateId(),
          keyword: word,
          categoryId: topEntry.key,
          confidence: association,
          matchCount: totalCount,
          source: 'feedback_learning',
          createdAt: DateTime.now(),
        ));
        newRulesCount++;
      }
    }

    return newRulesCount;
  }

  /// 提取关键词
  List<String> _extractKeywords(String text) {
    final words = <String>[];

    // 中文分词（简化版）
    final chinesePattern = RegExp(r'[\u4e00-\u9fa5]{2,4}');
    words.addAll(chinesePattern.allMatches(text).map((m) => m.group(0)!));

    // 英文单词
    final englishPattern = RegExp(r'[a-zA-Z]{3,}');
    words.addAll(
        englishPattern.allMatches(text.toLowerCase()).map((m) => m.group(0)!));

    return words.toSet().toList(); // 去重
  }

  /// 获取学习统计
  Future<LearningStatistics> getStatistics() async {
    final totalFeedbacks = await _repository.count();
    final processedFeedbacks = await _repository.countProcessed();
    final merchantMappings = await _merchantMapping.count();
    final keywordRules = await _keywordRules.count();

    return LearningStatistics(
      totalFeedbacks: totalFeedbacks,
      processedFeedbacks: processedFeedbacks,
      merchantMappings: merchantMappings,
      keywordRules: keywordRules,
      lastLearningTime: _scheduler.lastRunTime,
    );
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}

/// 增量学习调度器
class IncrementalLearningScheduler {
  static const int _batchThreshold = 50; // 累积50条反馈后触发批量学习
  static const Duration _minInterval = Duration(hours: 24); // 最小间隔24小时

  DateTime? lastRunTime;
  int _pendingCount = 0;

  void checkAndSchedule() {
    _pendingCount++;

    if (_pendingCount >= _batchThreshold) {
      if (lastRunTime == null ||
          DateTime.now().difference(lastRunTime!) > _minInterval) {
        _scheduleBatchLearning();
      }
    }
  }

  void _scheduleBatchLearning() {
    // 在后台运行批量学习
    debugPrint('Scheduling batch learning...');
    _pendingCount = 0;
    lastRunTime = DateTime.now();
  }
}

// ==================== 数据模型 ====================

/// 反馈类型
enum FeedbackType {
  categoryCorrection,  // 分类修正
  amountCorrection,    // 金额修正
  merchantCorrection,  // 商家修正
  intentCorrection,    // 意图修正
  anomalyDismiss,      // 异常驳回
  rejected,            // 完全拒绝
}

/// 反馈记录
class FeedbackRecord {
  final String id;
  final String userId;
  final String transactionId;
  final FeedbackType feedbackType;
  final String? originalCategoryId;
  final double? originalConfidence;
  final String? originalSource;
  final String? correctedCategoryId;
  final String? merchantName;
  final String? description;
  final double? amount;
  final DateTime? transactionDate;
  final int? dayOfWeek;
  final int? hourOfDay;
  final bool isProcessed;
  final DateTime? processedAt;
  final String? learningAction;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const FeedbackRecord({
    required this.id,
    required this.userId,
    required this.transactionId,
    required this.feedbackType,
    this.originalCategoryId,
    this.originalConfidence,
    this.originalSource,
    this.correctedCategoryId,
    this.merchantName,
    this.description,
    this.amount,
    this.transactionDate,
    this.dayOfWeek,
    this.hourOfDay,
    this.isProcessed = false,
    this.processedAt,
    this.learningAction,
    required this.createdAt,
    this.metadata,
  });
}

/// 映射来源
enum MappingSource {
  userCorrection,     // 用户修正
  frequencyAnalysis,  // 频率分析
  manual,             // 手动配置
}

/// 商家-分类映射
class MerchantCategoryMapping {
  final String id;
  final String merchantName;
  final String merchantNameNormalized;
  final String categoryId;
  final double confidence;
  final MappingSource source;
  final int matchCount;
  final int correctCount;
  final DateTime? lastUsedAt;
  final int version;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MerchantCategoryMapping({
    required this.id,
    required this.merchantName,
    required this.merchantNameNormalized,
    required this.categoryId,
    required this.confidence,
    required this.source,
    this.matchCount = 1,
    this.correctCount = 1,
    this.lastUsedAt,
    this.version = 1,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  MerchantCategoryMapping copyWith({
    String? categoryId,
    double? confidence,
    MappingSource? source,
    int? matchCount,
    int? correctCount,
    DateTime? lastUsedAt,
  }) {
    return MerchantCategoryMapping(
      id: id,
      merchantName: merchantName,
      merchantNameNormalized: merchantNameNormalized,
      categoryId: categoryId ?? this.categoryId,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      matchCount: matchCount ?? this.matchCount,
      correctCount: correctCount ?? this.correctCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      version: version,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// 学习到的关键词规则
class LearnedKeywordRule {
  final String id;
  final String keyword;
  final String categoryId;
  final double confidence;
  final int matchCount;
  final String source;
  final bool isActive;
  final DateTime createdAt;

  const LearnedKeywordRule({
    required this.id,
    required this.keyword,
    required this.categoryId,
    required this.confidence,
    this.matchCount = 1,
    required this.source,
    this.isActive = true,
    required this.createdAt,
  });
}

/// 学习结果
class LearningResult {
  final int processedCount;
  final int newRulesCount;
  final int updatedMappingsCount;

  const LearningResult({
    required this.processedCount,
    required this.newRulesCount,
    required this.updatedMappingsCount,
  });
}

/// 学习统计
class LearningStatistics {
  final int totalFeedbacks;
  final int processedFeedbacks;
  final int merchantMappings;
  final int keywordRules;
  final DateTime? lastLearningTime;

  const LearningStatistics({
    required this.totalFeedbacks,
    required this.processedFeedbacks,
    required this.merchantMappings,
    required this.keywordRules,
    this.lastLearningTime,
  });

  double get processingRate =>
      totalFeedbacks > 0 ? processedFeedbacks / totalFeedbacks : 0;
}

class _MerchantLearningResult {
  final bool newRule;
  final bool updatedMapping;

  _MerchantLearningResult({required this.newRule, required this.updatedMapping});
}

// ==================== 仓库接口 ====================

abstract class FeedbackRepository {
  Future<void> save(FeedbackRecord record);
  Future<List<FeedbackRecord>> getUnprocessed();
  Future<void> markAsProcessed(String id);
  Future<int> count();
  Future<int> countProcessed();
}

abstract class MerchantMappingRepository {
  Future<MerchantCategoryMapping?> findByMerchant(String merchantName);
  Future<void> save(MerchantCategoryMapping mapping);
  Future<void> update(MerchantCategoryMapping mapping);
  Future<int> count();
}

abstract class KeywordRuleRepository {
  Future<LearnedKeywordRule?> findByKeyword(String keyword);
  Future<void> save(LearnedKeywordRule rule);
  Future<int> count();
}
