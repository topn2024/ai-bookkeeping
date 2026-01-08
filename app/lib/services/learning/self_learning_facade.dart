import 'package:flutter/foundation.dart';

import 'unified_self_learning_service.dart';
import 'learning_adapters.dart';

/// 自学习系统对外暴露的统一接口
abstract class SelfLearningFacade {
  /// 记录用户反馈
  Future<void> recordFeedback(FeedbackType type, Map<String, dynamic> data);

  /// 获取学习建议
  Future<LearningSuggestion?> getSuggestion(
      String context, Map<String, dynamic> input);

  /// 获取学习状态摘要
  Future<LearningSummary> getSummary();

  /// 手动触发训练
  Future<void> triggerTraining(String? moduleId);

  /// 获取模块学习状态
  Future<Map<String, LearningStatus>> getModuleStatuses();

  /// 导出学习数据
  Future<FullModelExport> exportLearningData();

  /// 导入学习数据
  Future<void> importLearningData(FullModelExport data);
}

/// 反馈类型
enum FeedbackType {
  categoryCorrection, // 分类修正
  budgetAdjustment, // 预算调整
  anomalyDismiss, // 异常消除
  anomalyConfirm, // 异常确认
  intentCorrection, // 意图修正
  searchRefinement, // 搜索优化
  dialogueCorrection, // 对话修正
}

/// 学习建议
class LearningSuggestion {
  final String moduleId;
  final String suggestionType;
  final String content;
  final double confidence;
  final Map<String, dynamic> data;

  const LearningSuggestion({
    required this.moduleId,
    required this.suggestionType,
    required this.content,
    required this.confidence,
    this.data = const {},
  });
}

/// 学习状态摘要
class LearningSummary {
  final int totalRules;
  final int totalSamples;
  final double overallAccuracy;
  final int activeModules;
  final int modulesInTraining;
  final DateTime lastTrainingTime;
  final Map<String, ModuleSummary> moduleSummaries;

  const LearningSummary({
    required this.totalRules,
    required this.totalSamples,
    required this.overallAccuracy,
    required this.activeModules,
    required this.modulesInTraining,
    required this.lastTrainingTime,
    required this.moduleSummaries,
  });
}

/// 模块摘要
class ModuleSummary {
  final String moduleId;
  final String moduleName;
  final LearningStage stage;
  final int ruleCount;
  final int sampleCount;
  final double accuracy;
  final DateTime? lastTrainingTime;

  const ModuleSummary({
    required this.moduleId,
    required this.moduleName,
    required this.stage,
    required this.ruleCount,
    required this.sampleCount,
    required this.accuracy,
    this.lastTrainingTime,
  });
}

/// 自学习系统门面实现
class SelfLearningFacadeImpl implements SelfLearningFacade {
  final UnifiedSelfLearningService _service;

  SelfLearningFacadeImpl(this._service);

  /// 单例工厂
  static SelfLearningFacadeImpl? _instance;
  static SelfLearningFacadeImpl get instance {
    _instance ??= SelfLearningFacadeImpl(UnifiedSelfLearningService());
    return _instance!;
  }

  @override
  Future<void> recordFeedback(
      FeedbackType type, Map<String, dynamic> data) async {
    final moduleId = _getModuleIdForFeedback(type);
    final module = _service.getModule(moduleId);

    if (module == null) {
      debugPrint('Module not found for feedback type: $type');
      return;
    }

    try {
      final learningData = _convertToLearningData(type, data);
      if (learningData != null) {
        await module.collectSample(learningData);
        debugPrint('Feedback recorded: $type -> $moduleId');
      }
    } catch (e) {
      debugPrint('Failed to record feedback: $e');
    }
  }

  String _getModuleIdForFeedback(FeedbackType type) {
    switch (type) {
      case FeedbackType.categoryCorrection:
        return 'smart_category';
      case FeedbackType.budgetAdjustment:
        return 'budget_suggestion';
      case FeedbackType.anomalyDismiss:
      case FeedbackType.anomalyConfirm:
        return 'anomaly_detection';
      case FeedbackType.intentCorrection:
        return 'intent_recognition';
      case FeedbackType.searchRefinement:
        return 'search_learning';
      case FeedbackType.dialogueCorrection:
        return 'dialogue_learning';
    }
  }

  LearningData? _convertToLearningData(
      FeedbackType type, Map<String, dynamic> data) {
    final id = data['id'] as String? ?? DateTime.now().toIso8601String();
    final userId = data['user_id'] as String? ?? 'default';
    final timestamp = DateTime.now();

    switch (type) {
      case FeedbackType.categoryCorrection:
        return CategoryLearningData(
          id: id,
          timestamp: timestamp,
          userId: userId,
          merchantName: data['merchant_name'] as String? ?? '',
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
          originalCategory: data['original_category'] as String?,
          userCorrectedCategory: data['corrected_category'] as String? ?? '',
          description: data['description'] as String?,
        );

      case FeedbackType.anomalyDismiss:
        return AnomalyLearningData(
          id: id,
          timestamp: timestamp,
          userId: userId,
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
          category: data['category'] as String? ?? '',
          wasActualAnomaly: false,
          userFeedback: data['feedback'] as String?,
        );

      case FeedbackType.anomalyConfirm:
        return AnomalyLearningData(
          id: id,
          timestamp: timestamp,
          userId: userId,
          amount: (data['amount'] as num?)?.toDouble() ?? 0,
          category: data['category'] as String? ?? '',
          wasActualAnomaly: true,
          userFeedback: data['feedback'] as String?,
        );

      case FeedbackType.intentCorrection:
        return IntentLearningData(
          id: id,
          timestamp: timestamp,
          userId: userId,
          utterance: data['utterance'] as String? ?? '',
          recognizedIntent: data['recognized_intent'] as String? ?? '',
          userCorrectedIntent: data['corrected_intent'] as String?,
          originalConfidence:
              (data['original_confidence'] as num?)?.toDouble() ?? 0,
        );

      case FeedbackType.budgetAdjustment:
      case FeedbackType.searchRefinement:
      case FeedbackType.dialogueCorrection:
        // 这些类型使用通用学习数据
        return null;
    }
  }

  @override
  Future<LearningSuggestion?> getSuggestion(
    String context,
    Map<String, dynamic> input,
  ) async {
    // 根据上下文选择合适的模块
    final moduleId = _selectModuleForContext(context);
    final module = _service.getModule(moduleId);

    if (module == null) return null;

    try {
      final result = await module.predict(input);
      if (result.matched && result.confidence >= 0.6) {
        return LearningSuggestion(
          moduleId: moduleId,
          suggestionType: context,
          content: result.result?.toString() ?? '',
          confidence: result.confidence,
          data: {'rule_id': result.matchedRule?.ruleId},
        );
      }
    } catch (e) {
      debugPrint('Failed to get suggestion: $e');
    }

    return null;
  }

  String _selectModuleForContext(String context) {
    switch (context) {
      case 'category':
      case 'classification':
        return 'smart_category';
      case 'budget':
        return 'budget_suggestion';
      case 'anomaly':
        return 'anomaly_detection';
      case 'intent':
      case 'voice':
        return 'intent_recognition';
      case 'search':
        return 'search_learning';
      case 'dialogue':
        return 'dialogue_learning';
      default:
        return 'smart_category';
    }
  }

  @override
  Future<LearningSummary> getSummary() async {
    final report = await _service.getOverallReport();
    final statuses = await _service.getAllModuleStatus();

    final moduleSummaries = <String, ModuleSummary>{};
    int activeModules = 0;
    int modulesInTraining = 0;
    DateTime? latestTraining;

    for (final entry in statuses.entries) {
      final moduleId = entry.key;
      final status = entry.value;
      final metrics = report.moduleMetrics[moduleId];

      if (status.stage == LearningStage.active) {
        activeModules++;
      } else if (status.stage == LearningStage.training) {
        modulesInTraining++;
      }

      if (status.lastTrainingTime != null) {
        if (latestTraining == null ||
            status.lastTrainingTime!.isAfter(latestTraining)) {
          latestTraining = status.lastTrainingTime;
        }
      }

      final module = _service.getModule(moduleId);
      moduleSummaries[moduleId] = ModuleSummary(
        moduleId: moduleId,
        moduleName: module?.moduleName ?? moduleId,
        stage: status.stage,
        ruleCount: metrics?.totalRules ?? 0,
        sampleCount: metrics?.totalSamples ?? 0,
        accuracy: metrics?.accuracy ?? 0,
        lastTrainingTime: status.lastTrainingTime,
      );
    }

    return LearningSummary(
      totalRules: report.totalRules,
      totalSamples: report.totalSamples,
      overallAccuracy: report.overallAccuracy,
      activeModules: activeModules,
      modulesInTraining: modulesInTraining,
      lastTrainingTime: latestTraining ?? DateTime.now(),
      moduleSummaries: moduleSummaries,
    );
  }

  @override
  Future<void> triggerTraining(String? moduleId) async {
    if (moduleId != null) {
      final module = _service.getModule(moduleId);
      if (module != null) {
        await module.train();
        debugPrint('Training triggered for module: $moduleId');
      }
    } else {
      await _service.trainAllModules();
      debugPrint('Training triggered for all modules');
    }
  }

  @override
  Future<Map<String, LearningStatus>> getModuleStatuses() async {
    return _service.getAllModuleStatus();
  }

  @override
  Future<FullModelExport> exportLearningData() async {
    return _service.exportAllModels();
  }

  @override
  Future<void> importLearningData(FullModelExport data) async {
    await _service.importAllModels(data);
  }
}

// ==================== 业务系统集成示例 ====================

/// 智能分类系统集成
class SmartCategoryIntegration {
  final SelfLearningFacade _learningFacade;

  SmartCategoryIntegration(this._learningFacade);

  /// 用户修正分类时调用
  Future<void> onUserCorrectedCategory({
    required String transactionId,
    required String merchantName,
    required double amount,
    required String originalCategory,
    required String correctedCategory,
    String? description,
  }) async {
    await _learningFacade.recordFeedback(
      FeedbackType.categoryCorrection,
      {
        'id': transactionId,
        'merchant_name': merchantName,
        'amount': amount,
        'original_category': originalCategory,
        'corrected_category': correctedCategory,
        'description': description,
      },
    );
  }

  /// 获取分类建议
  Future<String?> getCategorySuggestion({
    required String merchantName,
    required double amount,
  }) async {
    final suggestion = await _learningFacade.getSuggestion(
      'category',
      {
        'merchant_name': merchantName,
        'amount': amount,
      },
    );

    return suggestion?.content;
  }
}

/// 语音交互系统集成
class VoiceInteractionIntegration {
  final SelfLearningFacade _learningFacade;

  VoiceInteractionIntegration(this._learningFacade);

  /// 用户修正意图时调用
  Future<void> onUserCorrectedIntent({
    required String voiceText,
    required String originalIntent,
    required String correctedIntent,
    double? originalConfidence,
  }) async {
    await _learningFacade.recordFeedback(
      FeedbackType.intentCorrection,
      {
        'utterance': voiceText,
        'recognized_intent': originalIntent,
        'corrected_intent': correctedIntent,
        'original_confidence': originalConfidence,
      },
    );
  }
}

/// 异常检测系统集成
class AnomalyDetectionIntegration {
  final SelfLearningFacade _learningFacade;

  AnomalyDetectionIntegration(this._learningFacade);

  /// 用户确认异常
  Future<void> onAnomalyConfirmed({
    required double amount,
    required String category,
    String? feedback,
  }) async {
    await _learningFacade.recordFeedback(
      FeedbackType.anomalyConfirm,
      {
        'amount': amount,
        'category': category,
        'feedback': feedback,
      },
    );
  }

  /// 用户驳回异常
  Future<void> onAnomalyDismissed({
    required double amount,
    required String category,
    String? feedback,
  }) async {
    await _learningFacade.recordFeedback(
      FeedbackType.anomalyDismiss,
      {
        'amount': amount,
        'category': category,
        'feedback': feedback,
      },
    );
  }
}
