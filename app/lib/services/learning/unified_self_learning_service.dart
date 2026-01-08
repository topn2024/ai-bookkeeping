import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

// ==================== 学习数据基类 ====================

/// 学习数据来源枚举
enum LearningDataSource {
  userExplicitFeedback, // 用户明确反馈（如修正分类）
  userImplicitBehavior, // 用户隐式行为（如接受建议）
  systemInference, // 系统推断
  collaborativeSync, // 协同学习同步
}

/// 学习数据基类 - 所有学习样本的抽象
abstract class LearningData {
  final String id;
  final DateTime timestamp;
  final String userId;
  final Map<String, dynamic> features; // 特征向量
  final dynamic label; // 标签（用户行为结果）
  final LearningDataSource source; // 数据来源

  LearningData({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.features,
    this.label,
    required this.source,
  });

  /// 转换为可存储格式
  Map<String, dynamic> toStorable();

  /// 脱敏处理（用于协同学习）
  LearningData anonymize();
}

// ==================== 学习规则基类 ====================

/// 规则来源枚举
enum RuleSource {
  userLearned, // 从用户行为学习
  collaborative, // 协同学习获取
  systemDefault, // 系统默认规则
  adminConfigured, // 管理员配置
}

/// 学习规则基类 - 所有学习成果的抽象
abstract class LearnedRule {
  final String ruleId;
  final String moduleId; // 所属模块标识
  final int priority; // 规则优先级
  final double confidence; // 置信度
  final DateTime createdAt;
  DateTime lastUsedAt;
  int hitCount; // 命中次数
  final RuleSource source; // 规则来源

  LearnedRule({
    required this.ruleId,
    required this.moduleId,
    required this.priority,
    required this.confidence,
    required this.createdAt,
    required this.lastUsedAt,
    this.hitCount = 0,
    required this.source,
  });

  /// 判断规则是否匹配输入
  bool matches(dynamic input);

  /// 应用规则返回结果
  dynamic apply(dynamic input);

  /// 更新规则统计
  void recordHit() {
    hitCount++;
    lastUsedAt = DateTime.now();
  }

  /// 转换为可存储格式
  Map<String, dynamic> toStorable();
}

// ==================== 学习效果指标 ====================

/// 学习效果指标
class LearningMetrics {
  final String moduleId;
  final DateTime measureTime;
  final int totalSamples;
  final int totalRules;
  final double accuracy; // 准确率
  final double precision; // 精确率
  final double recall; // 召回率
  final double f1Score; // F1分数
  final double avgResponseTime; // 平均响应时间(ms)
  final Map<String, dynamic> customMetrics; // 模块自定义指标

  LearningMetrics({
    required this.moduleId,
    required this.measureTime,
    required this.totalSamples,
    required this.totalRules,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1Score,
    required this.avgResponseTime,
    this.customMetrics = const {},
  });

  factory LearningMetrics.empty(String moduleId) => LearningMetrics(
        moduleId: moduleId,
        measureTime: DateTime.now(),
        totalSamples: 0,
        totalRules: 0,
        accuracy: 0,
        precision: 0,
        recall: 0,
        f1Score: 0,
        avgResponseTime: 0,
      );
}

// ==================== 学习状态 ====================

/// 学习阶段
enum LearningStage {
  coldStart, // 冷启动（样本不足）
  collecting, // 样本收集中
  training, // 训练中
  active, // 正常运行
  degraded, // 降级运行（效果下降）
}

/// 学习状态
class LearningStatus {
  final String moduleId;
  final bool isEnabled;
  final DateTime? lastTrainingTime;
  final DateTime? nextScheduledTraining;
  final int pendingSamples;
  final LearningStage stage;

  LearningStatus({
    required this.moduleId,
    required this.isEnabled,
    this.lastTrainingTime,
    this.nextScheduledTraining,
    required this.pendingSamples,
    required this.stage,
  });
}

// ==================== 训练与预测结果 ====================

/// 训练结果
class TrainingResult {
  final bool success;
  final int samplesUsed;
  final int rulesGenerated;
  final Duration trainingTime;
  final LearningMetrics? newMetrics;
  final String? errorMessage;

  TrainingResult({
    required this.success,
    required this.samplesUsed,
    required this.rulesGenerated,
    required this.trainingTime,
    this.newMetrics,
    this.errorMessage,
  });
}

/// 预测来源
enum PredictionSource {
  learnedRule, // 学习规则命中
  defaultRule, // 默认规则命中
  modelInference, // 模型推理
  fallback, // 兜底策略
}

/// 预测结果
class PredictionResult<R extends LearnedRule> {
  final bool matched;
  final R? matchedRule;
  final dynamic result;
  final double confidence;
  final PredictionSource source;

  PredictionResult({
    required this.matched,
    this.matchedRule,
    this.result,
    required this.confidence,
    required this.source,
  });
}

// ==================== 模型导出 ====================

/// 模型导出数据
class ModelExportData {
  final String moduleId;
  final DateTime exportedAt;
  final String version;
  final List<Map<String, dynamic>> rules;
  final Map<String, dynamic> modelData;
  final Map<String, dynamic> metadata;

  ModelExportData({
    required this.moduleId,
    required this.exportedAt,
    this.version = '1.0',
    required this.rules,
    this.modelData = const {},
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'module_id': moduleId,
        'exported_at': exportedAt.toIso8601String(),
        'version': version,
        'rules': rules,
        'model_data': modelData,
        'metadata': metadata,
      };

  factory ModelExportData.fromJson(Map<String, dynamic> json) {
    return ModelExportData(
      moduleId: json['module_id'] as String,
      exportedAt: DateTime.parse(json['exported_at'] as String),
      version: json['version'] as String? ?? '1.0',
      rules: (json['rules'] as List).cast<Map<String, dynamic>>(),
      modelData: json['model_data'] as Map<String, dynamic>? ?? {},
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}

// ==================== 统一学习模块接口 ====================

/// 统一自学习模块接口
abstract class ISelfLearningModule<T extends LearningData,
    R extends LearnedRule> {
  /// 模块标识
  String get moduleId;

  /// 模块名称（用于显示）
  String get moduleName;

  /// 采集学习样本
  Future<void> collectSample(T data);

  /// 批量采集样本
  Future<void> collectSamples(List<T> dataList);

  /// 触发模型训练
  Future<TrainingResult> train({bool incremental = true});

  /// 使用学习成果进行预测
  Future<PredictionResult<R>> predict(dynamic input);

  /// 获取学习效果指标
  Future<LearningMetrics> getMetrics();

  /// 获取所有已学习规则
  Future<List<R>> getRules({RuleSource? source, int? limit});

  /// 导出模型（用于备份或迁移）
  Future<ModelExportData> exportModel();

  /// 导入模型
  Future<void> importModel(ModelExportData data);

  /// 清除学习数据
  Future<void> clearData({bool keepRules = true});

  /// 获取学习状态
  Future<LearningStatus> getStatus();
}

// ==================== 统一自学习服务 ====================

/// 统一自学习服务 - 管理所有模块的学习能力
class UnifiedSelfLearningService {
  static final UnifiedSelfLearningService _instance =
      UnifiedSelfLearningService._internal();
  factory UnifiedSelfLearningService() => _instance;
  UnifiedSelfLearningService._internal();

  final Map<String, ISelfLearningModule> _modules = {};
  late final LearningScheduler _scheduler = LearningScheduler();
  bool _initialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;
    _scheduler.start();
    _initialized = true;
    debugPrint('UnifiedSelfLearningService initialized');
  }

  /// 注册学习模块
  void registerModule(ISelfLearningModule module) {
    _modules[module.moduleId] = module;
    _scheduler.scheduleModule(module.moduleId);
    debugPrint('Registered learning module: ${module.moduleName}');
  }

  /// 取消注册模块
  void unregisterModule(String moduleId) {
    _modules.remove(moduleId);
    _scheduler.unscheduleModule(moduleId);
  }

  /// 获取模块
  ISelfLearningModule? getModule(String moduleId) => _modules[moduleId];

  /// 获取所有已注册模块ID
  List<String> get registeredModuleIds => _modules.keys.toList();

  /// 获取所有模块状态
  Future<Map<String, LearningStatus>> getAllModuleStatus() async {
    final statuses = <String, LearningStatus>{};
    for (final entry in _modules.entries) {
      statuses[entry.key] = await entry.value.getStatus();
    }
    return statuses;
  }

  /// 触发全局训练
  Future<Map<String, TrainingResult>> trainAllModules() async {
    final results = <String, TrainingResult>{};
    for (final entry in _modules.entries) {
      try {
        results[entry.key] = await entry.value.train();
      } catch (e) {
        results[entry.key] = TrainingResult(
          success: false,
          samplesUsed: 0,
          rulesGenerated: 0,
          trainingTime: Duration.zero,
          errorMessage: e.toString(),
        );
      }
    }
    return results;
  }

  /// 获取整体学习效果报告
  Future<LearningEffectReport> getOverallReport() async {
    final moduleMetrics = <String, LearningMetrics>{};
    for (final entry in _modules.entries) {
      moduleMetrics[entry.key] = await entry.value.getMetrics();
    }

    return LearningEffectReport(
      generatedAt: DateTime.now(),
      moduleMetrics: moduleMetrics,
      overallAccuracy: _calculateOverallAccuracy(moduleMetrics),
      totalRules: moduleMetrics.values.fold(0, (sum, m) => sum + m.totalRules),
      totalSamples:
          moduleMetrics.values.fold(0, (sum, m) => sum + m.totalSamples),
    );
  }

  double _calculateOverallAccuracy(Map<String, LearningMetrics> metrics) {
    if (metrics.isEmpty) return 0.0;
    final total = metrics.values.fold(0.0, (sum, m) => sum + m.accuracy);
    return total / metrics.length;
  }

  /// 导出所有模块的模型
  Future<FullModelExport> exportAllModels() async {
    final exports = <String, ModelExportData>{};
    for (final entry in _modules.entries) {
      exports[entry.key] = await entry.value.exportModel();
    }
    return FullModelExport(
      exportedAt: DateTime.now(),
      version: '2.0',
      modules: exports,
    );
  }

  /// 导入模型
  Future<void> importAllModels(FullModelExport export) async {
    for (final entry in export.modules.entries) {
      final module = _modules[entry.key];
      if (module != null) {
        await module.importModel(entry.value);
      }
    }
  }

  /// 释放资源
  void dispose() {
    _scheduler.stop();
    _modules.clear();
    _initialized = false;
  }
}

// ==================== 学习效果报告 ====================

/// 学习效果报告
class LearningEffectReport {
  final DateTime generatedAt;
  final Map<String, LearningMetrics> moduleMetrics;
  final double overallAccuracy;
  final int totalRules;
  final int totalSamples;

  LearningEffectReport({
    required this.generatedAt,
    required this.moduleMetrics,
    required this.overallAccuracy,
    required this.totalRules,
    required this.totalSamples,
  });

  /// 获取摘要文本
  String getSummary() {
    return '''
学习效果报告 (${generatedAt.toString().substring(0, 16)})
- 总规则数: $totalRules
- 总样本数: $totalSamples
- 整体准确率: ${(overallAccuracy * 100).toStringAsFixed(1)}%
- 模块数量: ${moduleMetrics.length}
''';
  }
}

/// 完整模型导出
class FullModelExport {
  final DateTime exportedAt;
  final String version;
  final Map<String, ModelExportData> modules;

  FullModelExport({
    required this.exportedAt,
    required this.version,
    required this.modules,
  });

  Map<String, dynamic> toJson() => {
        'exported_at': exportedAt.toIso8601String(),
        'version': version,
        'modules': modules.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory FullModelExport.fromJson(Map<String, dynamic> json) {
    return FullModelExport(
      exportedAt: DateTime.parse(json['exported_at'] as String),
      version: json['version'] as String,
      modules: (json['modules'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, ModelExportData.fromJson(v)),
      ),
    );
  }
}

// ==================== 学习调度器 ====================

/// 调度配置
class ScheduleConfig {
  final String moduleId;
  final Duration interval;
  final TimeOfDay preferredTime;
  final int minSamplesForTraining;
  DateTime? lastCheckTime;

  ScheduleConfig({
    required this.moduleId,
    required this.interval,
    required this.preferredTime,
    required this.minSamplesForTraining,
    this.lastCheckTime,
  });
}

/// 学习调度器 - 管理各模块的训练时机
class LearningScheduler {
  final Map<String, ScheduleConfig> _schedules = {};
  Timer? _schedulerTimer;
  bool _isRunning = false;

  /// 启动调度器
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkAndTriggerTraining(),
    );
    debugPrint('LearningScheduler started');
  }

  /// 停止调度器
  void stop() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _isRunning = false;
    debugPrint('LearningScheduler stopped');
  }

  /// 调度配置
  void scheduleModule(
    String moduleId, {
    Duration interval = const Duration(hours: 24),
    TimeOfDay? preferredTime,
    int minSamplesForTraining = 10,
  }) {
    _schedules[moduleId] = ScheduleConfig(
      moduleId: moduleId,
      interval: interval,
      preferredTime: preferredTime ?? const TimeOfDay(hour: 3, minute: 0),
      minSamplesForTraining: minSamplesForTraining,
    );
  }

  void unscheduleModule(String moduleId) {
    _schedules.remove(moduleId);
  }

  Future<void> _checkAndTriggerTraining() async {
    final learningService = UnifiedSelfLearningService();
    final now = DateTime.now();

    for (final config in _schedules.values) {
      final module = learningService.getModule(config.moduleId);
      if (module == null) continue;

      try {
        final status = await module.getStatus();

        // 检查是否满足训练条件
        if (status.pendingSamples >= config.minSamplesForTraining) {
          final lastTraining = status.lastTrainingTime;
          if (lastTraining == null ||
              now.difference(lastTraining) >= config.interval) {
            // 触发训练
            debugPrint('Triggering training for ${config.moduleId}');
            await module.train(incremental: true);
            config.lastCheckTime = now;
          }
        }
      } catch (e) {
        debugPrint('Error checking module ${config.moduleId}: $e');
      }
    }
  }

  /// 立即触发指定模块训练
  Future<TrainingResult?> triggerImmediateTraining(String moduleId) async {
    final module = UnifiedSelfLearningService().getModule(moduleId);
    return module?.train(incremental: false);
  }

  /// 获取下次训练时间
  DateTime? getNextTrainingTime(String moduleId) {
    final config = _schedules[moduleId];
    if (config == null) return null;

    final lastCheck = config.lastCheckTime ?? DateTime.now();
    return lastCheck.add(config.interval);
  }
}
