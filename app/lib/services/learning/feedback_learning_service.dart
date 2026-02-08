import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

// ==================== 反馈类型 ====================

/// 识别反馈类型
enum RecognitionFeedbackType {
  categoryCorrection, // 分类修正
  amountCorrection, // 金额修正
  merchantCorrection, // 商家修正
  dateCorrection, // 日期修正
  descriptionCorrection, // 描述修正
  intentCorrection, // 意图修正
  anomalyDismiss, // 异常消除
  anomalyConfirm, // 异常确认
}

// ==================== 反馈数据模型 ====================

/// 识别反馈
class RecognitionFeedback {
  final String id;
  final String userId;
  final RecognitionFeedbackType type;
  final OriginalRecognition originalRecognition;
  final String? correctedValue;
  final DateTime timestamp;
  final bool isProcessed;
  final Map<String, dynamic> metadata;

  RecognitionFeedback({
    required this.id,
    required this.userId,
    required this.type,
    required this.originalRecognition,
    this.correctedValue,
    DateTime? timestamp,
    this.isProcessed = false,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  RecognitionFeedback copyWith({
    bool? isProcessed,
  }) {
    return RecognitionFeedback(
      id: id,
      userId: userId,
      type: type,
      originalRecognition: originalRecognition,
      correctedValue: correctedValue,
      timestamp: timestamp,
      isProcessed: isProcessed ?? this.isProcessed,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.name,
        'original_recognition': originalRecognition.toJson(),
        'corrected_value': correctedValue,
        'timestamp': timestamp.toIso8601String(),
        'is_processed': isProcessed,
        'metadata': metadata,
      };
}

/// 原始识别结果
class OriginalRecognition {
  final String rawText;
  final String? recognizedCategory;
  final double? recognizedAmount;
  final String? recognizedMerchant;
  final double confidence;

  const OriginalRecognition({
    required this.rawText,
    this.recognizedCategory,
    this.recognizedAmount,
    this.recognizedMerchant,
    this.confidence = 0,
  });

  Map<String, dynamic> toJson() => {
        'raw_text': rawText,
        'recognized_category': recognizedCategory,
        'recognized_amount': recognizedAmount,
        'recognized_merchant': recognizedMerchant,
        'confidence': confidence,
      };
}

/// 训练样本
class TrainingSample {
  final String input;
  final String expectedOutput;
  final double weight;

  const TrainingSample({
    required this.input,
    required this.expectedOutput,
    this.weight = 1.0,
  });
}

/// 反馈模式
class FeedbackPattern {
  final String pattern;
  final RecognitionFeedbackType type;
  final int frequency;
  final double confidence;
  final List<String> examples;

  const FeedbackPattern({
    required this.pattern,
    required this.type,
    required this.frequency,
    required this.confidence,
    required this.examples,
  });
}

// ==================== 反馈仓储 ====================

/// 反馈仓储接口
abstract class FeedbackRepository {
  Future<void> save(RecognitionFeedback feedback);
  Future<int> getPendingCount();
  Future<List<RecognitionFeedback>> getPendingFeedbacks({int limit = 100});
  Future<void> markAsProcessed(List<String> ids);
  Future<List<RecognitionFeedback>> getUserFeedbacks(String userId, {int limit});
}

/// 内存反馈仓储
class InMemoryFeedbackRepository implements FeedbackRepository {
  final List<RecognitionFeedback> _feedbacks = [];

  @override
  Future<void> save(RecognitionFeedback feedback) async {
    _feedbacks.add(feedback);
  }

  @override
  Future<int> getPendingCount() async {
    return _feedbacks.where((f) => !f.isProcessed).length;
  }

  @override
  Future<List<RecognitionFeedback>> getPendingFeedbacks({int limit = 100}) async {
    return _feedbacks
        .where((f) => !f.isProcessed)
        .take(limit)
        .toList();
  }

  @override
  Future<void> markAsProcessed(List<String> ids) async {
    for (int i = 0; i < _feedbacks.length; i++) {
      if (ids.contains(_feedbacks[i].id)) {
        _feedbacks[i] = _feedbacks[i].copyWith(isProcessed: true);
      }
    }
  }

  @override
  Future<List<RecognitionFeedback>> getUserFeedbacks(
    String userId, {
    int limit = 100,
  }) async {
    return _feedbacks
        .where((f) => f.userId == userId)
        .take(limit)
        .toList();
  }

  void clear() => _feedbacks.clear();
}

// ==================== 本地ML服务 ====================

/// 本地ML服务接口
abstract class LocalMLService {
  Future<void> incrementalTrain(List<TrainingSample> samples);
  Future<String?> predict(String input);
}

/// 模拟本地ML服务
class MockLocalMLService implements LocalMLService {
  final Map<String, String> _learnedMappings = {};

  @override
  Future<void> incrementalTrain(List<TrainingSample> samples) async {
    for (final sample in samples) {
      // 简化实现：直接记录输入-输出映射
      _learnedMappings[sample.input.toLowerCase()] = sample.expectedOutput;
    }
    debugPrint('Incremental training completed with ${samples.length} samples');
  }

  @override
  Future<String?> predict(String input) async {
    return _learnedMappings[input.toLowerCase()];
  }
}

// ==================== 用户反馈学习服务 ====================

/// 用户反馈学习服务
class FeedbackLearningService {
  final FeedbackRepository _feedbackRepo;
  final LocalMLService _localML;
  final void Function(List<FeedbackPattern>)? _onNewRulesDiscovered;

  // 配置
  static const int _minPendingForTrigger = 50;
  static const int _minCategoryCorrections = 20;
  static const int _batchLimit = 100;

  FeedbackLearningService({
    FeedbackRepository? feedbackRepo,
    LocalMLService? localML,
    void Function(List<FeedbackPattern>)? onNewRulesDiscovered,
  })  : _feedbackRepo = feedbackRepo ?? InMemoryFeedbackRepository(),
        _localML = localML ?? MockLocalMLService(),
        _onNewRulesDiscovered = onNewRulesDiscovered;

  /// 记录用户反馈
  Future<void> recordFeedback(RecognitionFeedback feedback) async {
    await _feedbackRepo.save(feedback);
    debugPrint('Recorded feedback: ${feedback.type.name}');

    // 触发增量学习（如果积累足够样本）
    final pendingCount = await _feedbackRepo.getPendingCount();
    if (pendingCount >= _minPendingForTrigger) {
      await _triggerIncrementalLearning();
    }
  }

  /// 批量记录反馈
  Future<void> recordFeedbackBatch(List<RecognitionFeedback> feedbacks) async {
    for (final feedback in feedbacks) {
      await _feedbackRepo.save(feedback);
    }

    final pendingCount = await _feedbackRepo.getPendingCount();
    if (pendingCount >= _minPendingForTrigger) {
      await _triggerIncrementalLearning();
    }
  }

  /// 增量学习
  Future<void> _triggerIncrementalLearning() async {
    final feedbacks = await _feedbackRepo.getPendingFeedbacks(limit: _batchLimit);
    if (feedbacks.isEmpty) return;

    debugPrint('Triggering incremental learning with ${feedbacks.length} feedbacks');

    // 按反馈类型分组处理
    final categoryCorrections = feedbacks
        .where((f) => f.type == RecognitionFeedbackType.categoryCorrection)
        .toList();

    final amountCorrections = feedbacks
        .where((f) => f.type == RecognitionFeedbackType.amountCorrection)
        .toList();

    final merchantCorrections = feedbacks
        .where((f) => f.type == RecognitionFeedbackType.merchantCorrection)
        .toList();

    // 更新本地ML模型
    if (categoryCorrections.length >= _minCategoryCorrections) {
      await _updateCategoryModel(categoryCorrections);
    }

    if (amountCorrections.isNotEmpty) {
      await _updateAmountModel(amountCorrections);
    }

    if (merchantCorrections.isNotEmpty) {
      await _updateMerchantModel(merchantCorrections);
    }

    // 更新规则引擎
    await _updateRules(feedbacks);

    // 标记已处理
    await _feedbackRepo.markAsProcessed(feedbacks.map((f) => f.id).toList());

    debugPrint('Incremental learning completed');
  }

  /// 更新分类模型
  Future<void> _updateCategoryModel(List<RecognitionFeedback> corrections) async {
    // 准备训练数据
    final trainingData = corrections
        .where((c) => c.correctedValue != null)
        .map((c) => TrainingSample(
              input: c.originalRecognition.rawText,
              expectedOutput: c.correctedValue!,
            ))
        .toList();

    if (trainingData.isEmpty) return;

    // 增量训练
    await _localML.incrementalTrain(trainingData);
    debugPrint('Updated category model with ${trainingData.length} samples');
  }

  /// 更新金额模型
  Future<void> _updateAmountModel(List<RecognitionFeedback> corrections) async {
    // 金额修正通常是规则调整而非ML训练
    final patterns = _analyzeAmountPatterns(corrections);
    debugPrint('Analyzed ${patterns.length} amount patterns');
  }

  /// 更新商家模型
  Future<void> _updateMerchantModel(List<RecognitionFeedback> corrections) async {
    final trainingData = corrections
        .where((c) => c.correctedValue != null)
        .map((c) => TrainingSample(
              input: c.originalRecognition.rawText,
              expectedOutput: c.correctedValue!,
            ))
        .toList();

    if (trainingData.isNotEmpty) {
      await _localML.incrementalTrain(trainingData);
    }
  }

  /// 更新规则引擎
  Future<void> _updateRules(List<RecognitionFeedback> feedbacks) async {
    // 分析反馈模式，发现新规则
    final patterns = _analyzePatterns(feedbacks);

    if (patterns.isNotEmpty) {
      debugPrint('Discovered ${patterns.length} new patterns');
      _onNewRulesDiscovered?.call(patterns);
    }
  }

  /// 分析反馈模式
  List<FeedbackPattern> _analyzePatterns(List<RecognitionFeedback> feedbacks) {
    final patterns = <FeedbackPattern>[];

    // 按类型和修正值分组
    final grouped = groupBy(
      feedbacks.where((f) => f.correctedValue != null),
      (f) => '${f.type.name}_${f.correctedValue}',
    );

    for (final entry in grouped.entries) {
      if (entry.value.length >= 3) {
        // 至少3次相同修正才算模式
        final examples = entry.value
            .map((f) => f.originalRecognition.rawText)
            .take(5)
            .toList();

        // 尝试提取通用模式
        final commonPattern = _extractCommonPattern(examples);

        if (commonPattern != null) {
          patterns.add(FeedbackPattern(
            pattern: commonPattern,
            type: entry.value.first.type,
            frequency: entry.value.length,
            confidence: entry.value.length / feedbacks.length,
            examples: examples,
          ));
        }
      }
    }

    return patterns;
  }

  /// 提取通用模式
  String? _extractCommonPattern(List<String> examples) {
    if (examples.isEmpty) return null;

    // 简化实现：找出共同前缀
    String common = examples.first.toLowerCase();
    for (final example in examples.skip(1)) {
      common = _commonPrefix(common, example.toLowerCase());
      if (common.isEmpty) break;
    }

    if (common.length >= 2) {
      return common;
    }

    return null;
  }

  String _commonPrefix(String a, String b) {
    int i = 0;
    while (i < a.length && i < b.length && a[i] == b[i]) {
      i++;
    }
    return a.substring(0, i);
  }

  /// 分析金额模式
  List<FeedbackPattern> _analyzeAmountPatterns(
      List<RecognitionFeedback> corrections) {
    // 金额修正模式分析
    return [];
  }

  /// 手动触发学习
  Future<void> triggerLearning() async {
    await _triggerIncrementalLearning();
  }

  /// 获取学习统计
  Future<FeedbackLearningStats> getStats() async {
    final pending = await _feedbackRepo.getPendingCount();

    return FeedbackLearningStats(
      pendingCount: pending,
      lastTrainingTime: DateTime.now(), // 简化实现
    );
  }
}

/// 学习统计
class FeedbackLearningStats {
  final int pendingCount;
  final DateTime? lastTrainingTime;

  const FeedbackLearningStats({
    required this.pendingCount,
    this.lastTrainingTime,
  });
}
