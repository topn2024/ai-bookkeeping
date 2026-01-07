# -*- coding: utf-8 -*-
"""
将自学习模型相关内容抽取为独立章节（第16章），并更新章节编号
"""

import re

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # ============ 第一步：创建新的第16章 - 自学习与协同学习系统 ============

    new_chapter_16 = '''

## 16. 自学习与协同学习系统

### 16.0 设计原则回顾

本章定义AI记账应用的自学习与协同学习系统架构。该系统作为**独立模块**设计，为其他智能模块提供统一的学习能力支持。

#### 16.0.1 自学习系统设计原则矩阵

| 设计原则 | 在自学习系统中的体现 | 实现方式 |
|----------|----------------------|----------|
| **懒人设计** | 零配置自动学习 | 用户无需任何操作，系统自动从使用行为中学习 |
| **伙伴化** | 学习过程透明可见 | 通过"我在学习您的习惯"等友好提示增强信任 |
| **渐进式** | 逐步提升准确率 | 从规则匹配→本地ML→协同学习，能力逐步增强 |
| **隐私优先** | 本地学习为主 | 敏感数据本地处理，仅同步脱敏的模式特征 |
| **开放集成** | 统一框架接口 | 所有智能模块通过统一接口接入学习能力 |

#### 16.0.2 设计理念

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           自学习系统设计理念                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   🎯 核心目标：让应用越用越懂用户，越用越智能                                    │
│                                                                              │
│   ┌────────────────────────────────────────────────────────────────────────┐ │
│   │  设计理念：低耦合、高复用、隐私优先、透明可控                              │ │
│   └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│   四大核心能力：                                                              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│   │  个体学习    │  │  协同学习    │  │  迁移学习    │  │  增量学习    │   │
│   │  ──────────  │  │  ──────────  │  │  ──────────  │  │  ──────────  │   │
│   │ 从用户行为中 │  │ 从群体智慧中 │  │ 将学习成果   │  │ 持续在线     │   │
│   │ 学习个性化   │  │ 提炼通用规则 │  │ 跨模块复用   │  │ 模型更新     │   │
│   └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### 16.0.3 与其他系统的关系图

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        自学习系统与其他模块的关系                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        ┌─────────────────────────┐                           │
│                        │   16. 自学习与协同学习   │                           │
│                        │      系统（本章）        │                           │
│                        └───────────┬─────────────┘                           │
│                                    │                                         │
│              ┌─────────────────────┼─────────────────────┐                   │
│              │                     │                     │                   │
│              ▼                     ▼                     ▼                   │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│   │  调用学习接口     │  │  调用学习接口     │  │  调用学习接口     │          │
│   └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│              │                     │                     │                   │
│              ▼                     ▼                     ▼                   │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│   │ 15. 智能分类系统 │  │ 17. 语音交互系统 │  │  10. AI识别系统  │          │
│   │   - 分类学习      │  │   - 意图识别学习  │  │   - 图像识别学习  │          │
│   │   - 规则沉淀      │  │   - 语音习惯学习  │  │   - 文字识别学习  │          │
│   └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│   │  8. 预算系统      │  │  7. 钱龄系统      │  │  9. 习惯培养系统  │          │
│   │   - 预算建议学习  │  │   - 资金流向学习  │  │   - 行为模式学习  │          │
│   └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
│   接入方式：各模块通过 SelfLearningAdapter 接入统一学习框架                     │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 16.1 统一自学习框架

统一自学习框架是一个**可复用的基础设施层**，为所有智能模块提供一致的学习能力。

#### 16.1.1 框架架构设计

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           统一自学习框架架构                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        应用层（各智能模块）                               │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │ │
│  │  │智能分类 │ │预算建议 │ │异常检测 │ │语音意图 │ │自然语言 │           │ │
│  │  │ Adapter │ │ Adapter │ │ Adapter │ │ Adapter │ │ Adapter │           │ │
│  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘           │ │
│  └───────┼──────────┼──────────┼──────────┼──────────┼─────────────────────┘ │
│          │          │          │          │          │                       │
│          └──────────┴──────────┴────┬─────┴──────────┘                       │
│                                     │                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        统一学习接口层                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐   │ │
│  │  │  ISelfLearningModule<T extends LearningData, R extends LearnedRule> │ │
│  │  │  ───────────────────────────────────────────────────────────────── │   │
│  │  │  + collectSample(data: T): Future<void>                           │   │
│  │  │  + train(): Future<void>                                          │   │
│  │  │  + predict(input: dynamic): Future<R?>                            │   │
│  │  │  + getMetrics(): Future<LearningMetrics>                          │   │
│  │  │  + exportModel(): Future<ModelData>                               │   │
│  │  │  + importModel(data: ModelData): Future<void>                     │   │
│  │  └──────────────────────────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     │                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        核心学习引擎层                                     │ │
│  │  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐              │ │
│  │  │  样本采集器     │ │  模型训练器     │ │  规则生成器     │              │ │
│  │  │ SampleCollector │ │ ModelTrainer   │ │ RuleGenerator  │              │ │
│  │  └────────────────┘ └────────────────┘ └────────────────┘              │ │
│  │  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐              │ │
│  │  │  效果评估器     │ │  版本管理器     │ │  调度器        │              │ │
│  │  │ EffectEvaluator │ │ VersionManager │ │ Scheduler      │              │ │
│  │  └────────────────┘ └────────────────┘ └────────────────┘              │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                     │                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                        数据存储层                                        │ │
│  │  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐              │ │
│  │  │  样本数据库     │ │  模型存储       │ │  规则存储       │              │ │
│  │  │ SampleDB       │ │ ModelStorage   │ │ RuleStorage    │              │ │
│  │  └────────────────┘ └────────────────┘ └────────────────┘              │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### 16.1.2 核心抽象类设计

```dart
/// 学习数据基类 - 所有学习样本的抽象
abstract class LearningData {
  final String id;
  final DateTime timestamp;
  final String userId;
  final Map<String, dynamic> features;  // 特征向量
  final dynamic label;  // 标签（用户行为结果）
  final LearningDataSource source;  // 数据来源

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

/// 学习数据来源枚举
enum LearningDataSource {
  userExplicitFeedback,   // 用户明确反馈（如修正分类）
  userImplicitBehavior,   // 用户隐式行为（如接受建议）
  systemInference,        // 系统推断
  collaborativeSync,      // 协同学习同步
}

/// 学习规则基类 - 所有学习成果的抽象
abstract class LearnedRule {
  final String ruleId;
  final String moduleId;  // 所属模块标识
  final int priority;     // 规则优先级
  final double confidence;  // 置信度
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final int hitCount;  // 命中次数
  final RuleSource source;  // 规则来源

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
  void recordHit();
}

/// 规则来源枚举
enum RuleSource {
  userLearned,       // 从用户行为学习
  collaborative,     // 协同学习获取
  systemDefault,     // 系统默认规则
  adminConfigured,   // 管理员配置
}

/// 学习效果指标
class LearningMetrics {
  final String moduleId;
  final DateTime measureTime;
  final int totalSamples;
  final int totalRules;
  final double accuracy;  // 准确率
  final double precision; // 精确率
  final double recall;    // 召回率
  final double f1Score;   // F1分数
  final double avgResponseTime;  // 平均响应时间
  final Map<String, dynamic> customMetrics;  // 模块自定义指标

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
}

/// 统一自学习模块接口
abstract class ISelfLearningModule<T extends LearningData, R extends LearnedRule> {
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

/// 预测来源
enum PredictionSource {
  learnedRule,       // 学习规则命中
  defaultRule,       // 默认规则命中
  modelInference,    // 模型推理
  fallback,          // 兜底策略
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

/// 学习阶段
enum LearningStage {
  coldStart,        // 冷启动（样本不足）
  collecting,       // 样本收集中
  training,         // 训练中
  active,           // 正常运行
  degraded,         // 降级运行（效果下降）
}
```

#### 16.1.3 自学习服务实现

```dart
/// 统一自学习服务 - 管理所有模块的学习能力
class UnifiedSelfLearningService {
  static final UnifiedSelfLearningService _instance =
      UnifiedSelfLearningService._internal();
  factory UnifiedSelfLearningService() => _instance;
  UnifiedSelfLearningService._internal();

  final Map<String, ISelfLearningModule> _modules = {};
  final SampleDatabase _sampleDb = SampleDatabase();
  final ModelStorage _modelStorage = ModelStorage();
  final LearningScheduler _scheduler = LearningScheduler();
  final LearningMetricsCollector _metricsCollector = LearningMetricsCollector();

  /// 注册学习模块
  void registerModule(ISelfLearningModule module) {
    _modules[module.moduleId] = module;
    _scheduler.scheduleModule(module.moduleId);
    print('📚 已注册学习模块: ${module.moduleName}');
  }

  /// 取消注册模块
  void unregisterModule(String moduleId) {
    _modules.remove(moduleId);
    _scheduler.unscheduleModule(moduleId);
  }

  /// 获取模块
  ISelfLearningModule? getModule(String moduleId) => _modules[moduleId];

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
      totalSamples: moduleMetrics.values.fold(0, (sum, m) => sum + m.totalSamples),
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
}

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
}
```

#### 16.1.4 学习调度器

```dart
/// 学习调度器 - 管理各模块的训练时机
class LearningScheduler {
  final Map<String, ScheduleConfig> _schedules = {};
  Timer? _schedulerTimer;

  /// 调度配置
  void scheduleModule(String moduleId, {
    Duration interval = const Duration(hours: 24),
    TimeOfDay? preferredTime,
    int minSamplesForTraining = 10,
  }) {
    _schedules[moduleId] = ScheduleConfig(
      moduleId: moduleId,
      interval: interval,
      preferredTime: preferredTime ?? const TimeOfDay(hour: 3, minute: 0), // 默认凌晨3点
      minSamplesForTraining: minSamplesForTraining,
    );
    _ensureSchedulerRunning();
  }

  void unscheduleModule(String moduleId) {
    _schedules.remove(moduleId);
  }

  void _ensureSchedulerRunning() {
    _schedulerTimer?.cancel();
    _schedulerTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkAndTriggerTraining(),
    );
  }

  Future<void> _checkAndTriggerTraining() async {
    final learningService = UnifiedSelfLearningService();
    final now = DateTime.now();

    for (final config in _schedules.values) {
      final module = learningService.getModule(config.moduleId);
      if (module == null) continue;

      final status = await module.getStatus();

      // 检查是否满足训练条件
      if (status.pendingSamples >= config.minSamplesForTraining) {
        final lastTraining = status.lastTrainingTime;
        if (lastTraining == null ||
            now.difference(lastTraining) >= config.interval) {
          // 触发训练
          await module.train(incremental: true);
        }
      }
    }
  }

  /// 立即触发指定模块训练
  Future<TrainingResult?> triggerImmediateTraining(String moduleId) async {
    final module = UnifiedSelfLearningService().getModule(moduleId);
    return module?.train(incremental: false);
  }
}

/// 调度配置
class ScheduleConfig {
  final String moduleId;
  final Duration interval;
  final TimeOfDay preferredTime;
  final int minSamplesForTraining;

  ScheduleConfig({
    required this.moduleId,
    required this.interval,
    required this.preferredTime,
    required this.minSamplesForTraining,
  });
}
```

### 16.2 多用户协同学习系统

协同学习系统实现跨用户的知识共享，同时保护用户隐私。

#### 16.2.1 协同学习架构

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           多用户协同学习架构                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                              云端聚合层                                   │ │
│  │  ┌────────────────────────────────────────────────────────────────────┐ │ │
│  │  │                      规则聚合引擎                                    │ │ │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐          │ │ │
│  │  │  │ 模式聚类  │→│ 置信度   │→│ 验证测试  │→│ 规则发布  │          │ │ │
│  │  │  │ Clustering│  │ Scoring  │  │ Validation│  │ Publishing│          │ │ │
│  │  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘          │ │ │
│  │  └────────────────────────────────────────────────────────────────────┘ │ │
│  │                              ↑ 脱敏数据                                   │ │
│  └─────────────────────────────┬───────────────────────────────────────────┘ │
│                                │                                             │
│  ┌─────────────────────────────┼───────────────────────────────────────────┐ │
│  │                   用户A     │     用户B          用户C                   │ │
│  │  ┌──────────┐  ┌──────────┐│┌──────────┐  ┌──────────┐                 │ │
│  │  │ 本地学习  │  │ 脱敏上报  │││ 本地学习  │  │ 本地学习  │                 │ │
│  │  │ 引擎      │  │ 模块      │││ 引擎      │  │ 引擎      │                 │ │
│  │  └──────────┘  └──────────┘│└──────────┘  └──────────┘                 │ │
│  │       ↓              ↑     │      ↓              ↓                      │ │
│  │  ┌──────────────────────┐  │┌──────────────────────┐                    │ │
│  │  │ 协同规则下载&融合     │  ││ 协同规则下载&融合     │                    │ │
│  │  └──────────────────────┘  │└──────────────────────┘                    │ │
│  └─────────────────────────────┴───────────────────────────────────────────┘ │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

#### 16.2.2 隐私保护设计

```dart
/// 协同学习数据脱敏服务
class CollaborativeLearningAnonymizer {
  /// 脱敏配置
  static const _anonymizationConfig = {
    'merchant_name': AnonymizeStrategy.hash,
    'amount': AnonymizeStrategy.range,
    'description': AnonymizeStrategy.remove,
    'user_id': AnonymizeStrategy.pseudonymize,
  };

  /// 脱敏学习样本
  static Map<String, dynamic> anonymize(Map<String, dynamic> sample) {
    final result = <String, dynamic>{};

    for (final entry in sample.entries) {
      final strategy = _anonymizationConfig[entry.key] ?? AnonymizeStrategy.keep;
      result[entry.key] = _applyStrategy(entry.value, strategy);
    }

    return result;
  }

  static dynamic _applyStrategy(dynamic value, AnonymizeStrategy strategy) {
    switch (strategy) {
      case AnonymizeStrategy.hash:
        return _hashValue(value.toString());
      case AnonymizeStrategy.range:
        return _toRange(value as num);
      case AnonymizeStrategy.remove:
        return null;
      case AnonymizeStrategy.pseudonymize:
        return _pseudonymize(value.toString());
      case AnonymizeStrategy.keep:
        return value;
    }
  }

  static String _hashValue(String value) {
    // 使用SHA256哈希，保留模式匹配能力
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  static String _toRange(num amount) {
    // 金额转换为范围区间
    if (amount < 10) return 'tiny';      // <10
    if (amount < 50) return 'small';     // 10-50
    if (amount < 100) return 'medium';   // 50-100
    if (amount < 500) return 'large';    // 100-500
    if (amount < 1000) return 'xlarge';  // 500-1000
    return 'huge';                       // >1000
  }

  static String _pseudonymize(String userId) {
    // 用户ID伪匿名化，同一用户保持一致性
    return 'user_${_hashValue(userId).substring(0, 8)}';
  }
}

/// 脱敏策略
enum AnonymizeStrategy {
  hash,         // 哈希处理
  range,        // 转换为范围
  remove,       // 完全移除
  pseudonymize, // 伪匿名化
  keep,         // 保持原样
}
```

#### 16.2.3 协同学习服务

```dart
/// 协同学习服务
class CollaborativeLearningService {
  final ApiClient _apiClient;
  final LocalRuleStorage _ruleStorage;
  final _syncInterval = const Duration(hours: 6);
  Timer? _syncTimer;

  CollaborativeLearningService(this._apiClient, this._ruleStorage);

  /// 启动协同学习
  void start() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => _syncWithCloud());
    // 立即执行一次
    _syncWithCloud();
  }

  /// 停止协同学习
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// 与云端同步
  Future<void> _syncWithCloud() async {
    try {
      // 1. 上报本地脱敏数据
      await _uploadAnonymizedPatterns();

      // 2. 下载协同规则
      final collaborativeRules = await _downloadCollaborativeRules();

      // 3. 融合到本地
      await _mergeCollaborativeRules(collaborativeRules);

    } catch (e) {
      print('协同学习同步失败: $e');
    }
  }

  /// 上报脱敏模式
  Future<void> _uploadAnonymizedPatterns() async {
    final learningService = UnifiedSelfLearningService();
    final allStatus = await learningService.getAllModuleStatus();

    for (final entry in allStatus.entries) {
      final module = learningService.getModule(entry.key);
      if (module == null) continue;

      // 获取本地规则并脱敏
      final rules = await module.getRules(source: RuleSource.userLearned);
      final anonymizedRules = rules.map((r) => _anonymizeRule(r)).toList();

      // 上报到云端
      await _apiClient.post('/collaborative/patterns/${entry.key}', {
        'patterns': anonymizedRules,
        'device_fingerprint': await _getDeviceFingerprint(),
      });
    }
  }

  Map<String, dynamic> _anonymizeRule(LearnedRule rule) {
    // 规则脱敏处理
    return {
      'pattern_hash': _hashPattern(rule),
      'confidence': rule.confidence,
      'hit_count': rule.hitCount,
      // 不包含任何可识别用户的信息
    };
  }

  /// 下载协同规则
  Future<List<CollaborativeRule>> _downloadCollaborativeRules() async {
    final response = await _apiClient.get('/collaborative/rules');
    return (response['rules'] as List)
        .map((r) => CollaborativeRule.fromJson(r))
        .toList();
  }

  /// 融合协同规则
  Future<void> _mergeCollaborativeRules(List<CollaborativeRule> rules) async {
    for (final rule in rules) {
      // 检查本地是否已有更优规则
      final localRules = await _ruleStorage.getRulesForModule(rule.moduleId);
      final existingRule = localRules.firstWhereOrNull(
        (r) => r.patternHash == rule.patternHash
      );

      if (existingRule == null) {
        // 新规则，直接添加
        await _ruleStorage.addCollaborativeRule(rule);
      } else if (rule.globalConfidence > existingRule.confidence * 1.2) {
        // 协同规则置信度显著更高，更新
        await _ruleStorage.updateRuleConfidence(
          existingRule.ruleId,
          rule.globalConfidence
        );
      }
    }
  }

  String _hashPattern(LearnedRule rule) {
    // 生成规则的特征哈希
    final features = rule.toStorable();
    features.remove('ruleId');
    features.remove('userId');
    return sha256.convert(utf8.encode(jsonEncode(features))).toString();
  }

  Future<String> _getDeviceFingerprint() async {
    // 生成设备指纹用于去重
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    return sha256.convert(utf8.encode(deviceInfo.toString())).toString();
  }
}

/// 协同规则
class CollaborativeRule {
  final String moduleId;
  final String patternHash;
  final double globalConfidence;
  final int globalHitCount;
  final int contributorCount;
  final DateTime publishedAt;

  CollaborativeRule({
    required this.moduleId,
    required this.patternHash,
    required this.globalConfidence,
    required this.globalHitCount,
    required this.contributorCount,
    required this.publishedAt,
  });

  factory CollaborativeRule.fromJson(Map<String, dynamic> json) {
    return CollaborativeRule(
      moduleId: json['module_id'],
      patternHash: json['pattern_hash'],
      globalConfidence: json['global_confidence'],
      globalHitCount: json['global_hit_count'],
      contributorCount: json['contributor_count'],
      publishedAt: DateTime.parse(json['published_at']),
    );
  }
}
```

#### 16.2.4 新用户冷启动加速

```dart
/// 冷启动加速服务
class ColdStartAccelerator {
  final CollaborativeLearningService _collaborativeService;
  final UserProfileService _profileService;

  ColdStartAccelerator(this._collaborativeService, this._profileService);

  /// 为新用户初始化学习规则
  Future<ColdStartResult> initializeForNewUser(String userId) async {
    // 1. 获取用户画像
    final profile = await _profileService.getProfile(userId);

    // 2. 根据画像选择适合的协同规则集
    final ruleSet = await _selectRuleSet(profile);

    // 3. 导入规则
    await _importRuleSet(userId, ruleSet);

    return ColdStartResult(
      rulesImported: ruleSet.rules.length,
      expectedAccuracy: ruleSet.expectedAccuracy,
      warmUpDays: ruleSet.warmUpDays,
    );
  }

  Future<CollaborativeRuleSet> _selectRuleSet(UserProfile profile) async {
    // 根据用户特征选择规则集
    final features = {
      'age_group': profile.ageGroup,
      'city_tier': profile.cityTier,
      'income_level': profile.estimatedIncomeLevel,
    };

    return await _collaborativeService.fetchRuleSetForProfile(features);
  }

  Future<void> _importRuleSet(String userId, CollaborativeRuleSet ruleSet) async {
    final learningService = UnifiedSelfLearningService();

    for (final moduleRules in ruleSet.rulesByModule.entries) {
      final module = learningService.getModule(moduleRules.key);
      if (module == null) continue;

      await module.importModel(ModelExportData(
        rules: moduleRules.value,
        source: 'cold_start',
        confidence: 0.6, // 冷启动规则初始置信度较低
      ));
    }
  }
}

/// 冷启动结果
class ColdStartResult {
  final int rulesImported;
  final double expectedAccuracy;
  final int warmUpDays;

  ColdStartResult({
    required this.rulesImported,
    required this.expectedAccuracy,
    required this.warmUpDays,
  });
}
```

### 16.3 各模块学习适配器

#### 16.3.1 智能分类学习适配器

```dart
/// 智能分类学习适配器
class CategoryLearningAdapter extends ISelfLearningModule<CategoryLearningData, CategoryRule> {
  @override
  String get moduleId => 'smart_category';

  @override
  String get moduleName => '智能分类';

  final CategoryRuleStorage _ruleStorage;
  final CategorySampleDb _sampleDb;
  final LocalMLModel _localModel;

  CategoryLearningAdapter(this._ruleStorage, this._sampleDb, this._localModel);

  @override
  Future<void> collectSample(CategoryLearningData data) async {
    // 收集用户分类修正样本
    await _sampleDb.insert(data);
  }

  @override
  Future<TrainingResult> train({bool incremental = true}) async {
    final startTime = DateTime.now();

    // 获取待训练样本
    final samples = await _sampleDb.getPendingSamples();
    if (samples.isEmpty) {
      return TrainingResult(
        success: true,
        samplesUsed: 0,
        rulesGenerated: 0,
        trainingTime: Duration.zero,
      );
    }

    // 规则提取
    final newRules = _extractRules(samples);

    // 存储规则
    for (final rule in newRules) {
      await _ruleStorage.upsertRule(rule);
    }

    // 更新本地ML模型
    if (samples.length >= 50) {
      await _localModel.retrain(samples);
    }

    // 标记样本已处理
    await _sampleDb.markAsProcessed(samples.map((s) => s.id).toList());

    return TrainingResult(
      success: true,
      samplesUsed: samples.length,
      rulesGenerated: newRules.length,
      trainingTime: DateTime.now().difference(startTime),
      newMetrics: await getMetrics(),
    );
  }

  List<CategoryRule> _extractRules(List<CategoryLearningData> samples) {
    final rules = <CategoryRule>[];

    // 按商家名称聚类
    final merchantGroups = groupBy(samples, (s) => s.merchantName);
    for (final entry in merchantGroups.entries) {
      if (entry.value.length >= 3) {
        // 同一商家出现3次以上，提取规则
        final mostFrequentCategory = _getMostFrequent(
          entry.value.map((s) => s.userCorrectedCategory).toList()
        );

        if (mostFrequentCategory != null) {
          rules.add(CategoryRule(
            ruleId: 'merchant_${entry.key.hashCode}',
            merchantPattern: entry.key,
            categoryId: mostFrequentCategory,
            confidence: entry.value.length / samples.length,
            source: RuleSource.userLearned,
          ));
        }
      }
    }

    // 按金额范围+关键词聚类
    // ... 更多规则提取逻辑

    return rules;
  }

  @override
  Future<PredictionResult<CategoryRule>> predict(dynamic input) async {
    final transaction = input as TransactionInput;

    // 1. 查找匹配的用户规则
    final userRules = await _ruleStorage.getRules(source: RuleSource.userLearned);
    for (final rule in userRules) {
      if (rule.matches(transaction)) {
        return PredictionResult(
          matched: true,
          matchedRule: rule,
          result: rule.categoryId,
          confidence: rule.confidence,
          source: PredictionSource.learnedRule,
        );
      }
    }

    // 2. 查找协同规则
    final collaborativeRules = await _ruleStorage.getRules(source: RuleSource.collaborative);
    for (final rule in collaborativeRules) {
      if (rule.matches(transaction)) {
        return PredictionResult(
          matched: true,
          matchedRule: rule,
          result: rule.categoryId,
          confidence: rule.confidence * 0.8, // 协同规则置信度略低
          source: PredictionSource.learnedRule,
        );
      }
    }

    // 3. 使用本地ML模型
    final mlResult = await _localModel.predict(transaction);
    if (mlResult.confidence > 0.7) {
      return PredictionResult(
        matched: true,
        result: mlResult.categoryId,
        confidence: mlResult.confidence,
        source: PredictionSource.modelInference,
      );
    }

    // 4. 返回未匹配
    return PredictionResult(
      matched: false,
      confidence: 0,
      source: PredictionSource.fallback,
    );
  }

  @override
  Future<LearningMetrics> getMetrics() async {
    final rules = await _ruleStorage.getAllRules();
    final recentPredictions = await _getPredictionHistory(days: 7);

    final correctPredictions = recentPredictions
        .where((p) => p.wasCorrect)
        .length;

    return LearningMetrics(
      moduleId: moduleId,
      measureTime: DateTime.now(),
      totalSamples: await _sampleDb.getTotalCount(),
      totalRules: rules.length,
      accuracy: recentPredictions.isEmpty
          ? 0
          : correctPredictions / recentPredictions.length,
      precision: _calculatePrecision(recentPredictions),
      recall: _calculateRecall(recentPredictions),
      f1Score: _calculateF1(recentPredictions),
      avgResponseTime: _calculateAvgResponseTime(recentPredictions),
    );
  }

  // ... 其他接口实现
}

/// 分类学习数据
class CategoryLearningData extends LearningData {
  final String merchantName;
  final double amount;
  final String? originalCategory;
  final String userCorrectedCategory;

  CategoryLearningData({
    required super.id,
    required super.timestamp,
    required super.userId,
    required this.merchantName,
    required this.amount,
    this.originalCategory,
    required this.userCorrectedCategory,
  }) : super(
    features: {
      'merchant': merchantName,
      'amount': amount,
    },
    label: userCorrectedCategory,
    source: LearningDataSource.userExplicitFeedback,
  );

  @override
  Map<String, dynamic> toStorable() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'user_id': userId,
    'merchant_name': merchantName,
    'amount': amount,
    'original_category': originalCategory,
    'user_corrected_category': userCorrectedCategory,
  };

  @override
  LearningData anonymize() => CategoryLearningData(
    id: id,
    timestamp: timestamp,
    userId: CollaborativeLearningAnonymizer.anonymize({'user_id': userId})['user_id'],
    merchantName: CollaborativeLearningAnonymizer.anonymize({'merchant_name': merchantName})['merchant_name'],
    amount: amount,
    originalCategory: originalCategory,
    userCorrectedCategory: userCorrectedCategory,
  );
}

/// 分类规则
class CategoryRule extends LearnedRule {
  final String merchantPattern;
  final String categoryId;

  CategoryRule({
    required super.ruleId,
    required this.merchantPattern,
    required this.categoryId,
    required super.confidence,
    required super.source,
  }) : super(
    moduleId: 'smart_category',
    priority: source == RuleSource.userLearned ? 100 : 50,
    createdAt: DateTime.now(),
    lastUsedAt: DateTime.now(),
  );

  @override
  bool matches(dynamic input) {
    final transaction = input as TransactionInput;
    return transaction.merchantName.contains(merchantPattern);
  }

  @override
  dynamic apply(dynamic input) => categoryId;
}
```

#### 16.3.2 预算建议学习适配器

```dart
/// 预算建议学习适配器
class BudgetLearningAdapter extends ISelfLearningModule<BudgetLearningData, BudgetRule> {
  @override
  String get moduleId => 'budget_suggestion';

  @override
  String get moduleName => '预算建议';

  // ... 类似实现，针对预算场景定制
}
```

#### 16.3.3 异常检测学习适配器

```dart
/// 异常检测学习适配器
class AnomalyLearningAdapter extends ISelfLearningModule<AnomalyLearningData, AnomalyRule> {
  @override
  String get moduleId => 'anomaly_detection';

  @override
  String get moduleName => '异常检测';

  // ... 类似实现，针对异常检测场景定制
}
```

#### 16.3.4 意图识别学习适配器

```dart
/// 意图识别学习适配器
class IntentLearningAdapter extends ISelfLearningModule<IntentLearningData, IntentRule> {
  @override
  String get moduleId => 'voice_intent';

  @override
  String get moduleName => '语音意图识别';

  // ... 类似实现，针对语音意图场景定制
  // 详见第17章语音交互系统
}
```

### 16.4 学习效果监控与报告

#### 16.4.1 学习效果仪表盘

```dart
/// 学习效果仪表盘数据
class LearningDashboardData {
  final DateTime generatedAt;
  final OverallLearningStats overall;
  final List<ModuleLearningStats> modules;
  final List<LearningTrendPoint> accuracyTrend;
  final List<TopLearnedRule> topRules;

  LearningDashboardData({
    required this.generatedAt,
    required this.overall,
    required this.modules,
    required this.accuracyTrend,
    required this.topRules,
  });
}

/// 整体学习统计
class OverallLearningStats {
  final int totalRules;
  final int totalSamples;
  final double overallAccuracy;
  final double accuracyImprovement;  // 相比初始状态的提升
  final int daysActive;

  OverallLearningStats({
    required this.totalRules,
    required this.totalSamples,
    required this.overallAccuracy,
    required this.accuracyImprovement,
    required this.daysActive,
  });
}

/// 模块学习统计
class ModuleLearningStats {
  final String moduleId;
  final String moduleName;
  final LearningStage stage;
  final int ruleCount;
  final double accuracy;
  final double weeklyImprovement;

  ModuleLearningStats({
    required this.moduleId,
    required this.moduleName,
    required this.stage,
    required this.ruleCount,
    required this.accuracy,
    required this.weeklyImprovement,
  });
}

/// 学习效果仪表盘服务
class LearningDashboardService {
  final UnifiedSelfLearningService _learningService;
  final LearningMetricsStorage _metricsStorage;

  LearningDashboardService(this._learningService, this._metricsStorage);

  Future<LearningDashboardData> getDashboardData() async {
    final report = await _learningService.getOverallReport();
    final historicalMetrics = await _metricsStorage.getHistoricalMetrics(days: 30);

    return LearningDashboardData(
      generatedAt: DateTime.now(),
      overall: _buildOverallStats(report, historicalMetrics),
      modules: await _buildModuleStats(report),
      accuracyTrend: _buildAccuracyTrend(historicalMetrics),
      topRules: await _getTopRules(),
    );
  }

  OverallLearningStats _buildOverallStats(
    LearningEffectReport report,
    List<HistoricalMetrics> history,
  ) {
    final initialAccuracy = history.isNotEmpty ? history.first.accuracy : 0.0;

    return OverallLearningStats(
      totalRules: report.totalRules,
      totalSamples: report.totalSamples,
      overallAccuracy: report.overallAccuracy,
      accuracyImprovement: report.overallAccuracy - initialAccuracy,
      daysActive: history.length,
    );
  }

  Future<List<ModuleLearningStats>> _buildModuleStats(LearningEffectReport report) async {
    final stats = <ModuleLearningStats>[];

    for (final entry in report.moduleMetrics.entries) {
      final module = _learningService.getModule(entry.key);
      if (module == null) continue;

      final status = await module.getStatus();
      final weeklyMetrics = await _metricsStorage.getModuleMetrics(
        entry.key,
        days: 7,
      );

      final weeklyImprovement = weeklyMetrics.length >= 2
          ? weeklyMetrics.last.accuracy - weeklyMetrics.first.accuracy
          : 0.0;

      stats.add(ModuleLearningStats(
        moduleId: entry.key,
        moduleName: module.moduleName,
        stage: status.stage,
        ruleCount: entry.value.totalRules,
        accuracy: entry.value.accuracy,
        weeklyImprovement: weeklyImprovement,
      ));
    }

    return stats;
  }

  List<LearningTrendPoint> _buildAccuracyTrend(List<HistoricalMetrics> history) {
    return history.map((h) => LearningTrendPoint(
      date: h.date,
      accuracy: h.accuracy,
    )).toList();
  }

  Future<List<TopLearnedRule>> _getTopRules() async {
    // 获取命中率最高的规则
    final allRules = <LearnedRule>[];
    final allStatus = await _learningService.getAllModuleStatus();

    for (final moduleId in allStatus.keys) {
      final module = _learningService.getModule(moduleId);
      if (module == null) continue;

      final rules = await module.getRules(limit: 10);
      allRules.addAll(rules);
    }

    // 按命中次数排序
    allRules.sort((a, b) => b.hitCount.compareTo(a.hitCount));

    return allRules.take(10).map((r) => TopLearnedRule(
      moduleId: r.moduleId,
      ruleId: r.ruleId,
      hitCount: r.hitCount,
      confidence: r.confidence,
    )).toList();
  }
}
```

### 16.5 与其他系统的集成

#### 16.5.1 集成接口定义

```dart
/// 自学习系统对外暴露的统一接口
abstract class SelfLearningFacade {
  /// 记录用户反馈
  Future<void> recordFeedback(FeedbackType type, Map<String, dynamic> data);

  /// 获取学习建议
  Future<LearningSuggestion?> getSuggestion(String context, Map<String, dynamic> input);

  /// 获取学习状态摘要
  Future<LearningSummary> getSummary();

  /// 手动触发训练
  Future<void> triggerTraining(String? moduleId);
}

/// 反馈类型
enum FeedbackType {
  categoryCorrection,     // 分类修正
  budgetAdjustment,       // 预算调整
  anomalyDismiss,         // 异常消除
  intentCorrection,       // 意图修正
  searchRefinement,       // 搜索优化
}

/// 自学习系统门面实现
class SelfLearningFacadeImpl implements SelfLearningFacade {
  final UnifiedSelfLearningService _service;

  SelfLearningFacadeImpl(this._service);

  @override
  Future<void> recordFeedback(FeedbackType type, Map<String, dynamic> data) async {
    final moduleId = _getModuleIdForFeedback(type);
    final module = _service.getModule(moduleId);

    if (module != null) {
      final learningData = _convertToLearningData(type, data);
      await module.collectSample(learningData);
    }
  }

  String _getModuleIdForFeedback(FeedbackType type) {
    switch (type) {
      case FeedbackType.categoryCorrection:
        return 'smart_category';
      case FeedbackType.budgetAdjustment:
        return 'budget_suggestion';
      case FeedbackType.anomalyDismiss:
        return 'anomaly_detection';
      case FeedbackType.intentCorrection:
        return 'voice_intent';
      case FeedbackType.searchRefinement:
        return 'natural_language_search';
    }
  }

  // ... 其他实现
}
```

#### 16.5.2 各系统集成示例

```dart
/// 智能分类系统集成示例
class SmartCategoryService {
  final SelfLearningFacade _learningFacade;

  SmartCategoryService(this._learningFacade);

  /// 用户修正分类时调用
  Future<void> onUserCorrectedCategory(
    Transaction transaction,
    String newCategoryId,
  ) async {
    // 记录到自学习系统
    await _learningFacade.recordFeedback(
      FeedbackType.categoryCorrection,
      {
        'transaction_id': transaction.id,
        'merchant_name': transaction.merchantName,
        'amount': transaction.amount,
        'original_category': transaction.categoryId,
        'corrected_category': newCategoryId,
      },
    );
  }
}

/// 语音交互系统集成示例
class VoiceInteractionService {
  final SelfLearningFacade _learningFacade;

  VoiceInteractionService(this._learningFacade);

  /// 用户修正意图时调用
  Future<void> onUserCorrectedIntent(
    String voiceText,
    VoiceIntentType originalIntent,
    VoiceIntentType correctedIntent,
  ) async {
    await _learningFacade.recordFeedback(
      FeedbackType.intentCorrection,
      {
        'voice_text': voiceText,
        'original_intent': originalIntent.name,
        'corrected_intent': correctedIntent.name,
      },
    );
  }
}
```

### 16.6 目标达成检测

```dart
/// 自学习系统目标检测服务
class SelfLearningGoalChecker implements GoalChecker {
  final UnifiedSelfLearningService _service;

  @override
  String get goalId => 'self_learning_effectiveness';

  @override
  Future<GoalCheckResult> check() async {
    final report = await _service.getOverallReport();
    final checks = <GoalCheckItem>[];

    // 检查整体准确率
    checks.add(GoalCheckItem(
      name: '整体学习准确率',
      target: '>= 80%',
      actual: '${(report.overallAccuracy * 100).toStringAsFixed(1)}%',
      passed: report.overallAccuracy >= 0.8,
    ));

    // 检查规则生成数量
    checks.add(GoalCheckItem(
      name: '已学习规则数',
      target: '>= 50',
      actual: '${report.totalRules}',
      passed: report.totalRules >= 50,
    ));

    // 检查各模块状态
    for (final entry in report.moduleMetrics.entries) {
      checks.add(GoalCheckItem(
        name: '${entry.key}模块准确率',
        target: '>= 75%',
        actual: '${(entry.value.accuracy * 100).toStringAsFixed(1)}%',
        passed: entry.value.accuracy >= 0.75,
      ));
    }

    return GoalCheckResult(
      goalId: goalId,
      passed: checks.every((c) => c.passed),
      items: checks,
      checkedAt: DateTime.now(),
    );
  }
}
```

'''

    # 找到第15章结束位置和第16章开始位置
    # 原来的第16章变成第17章，以此类推

    # 首先在第15章后插入新的第16章
    old_chapter_16_start = '## 16. 性能设计与优化'

    if old_chapter_16_start in content:
        # 在原第16章之前插入新章节
        content = content.replace(
            old_chapter_16_start,
            new_chapter_16 + '\n\n' + old_chapter_16_start
        )
        print("✅ 新增第16章：自学习与协同学习系统")
    else:
        print("❌ 未找到原第16章位置")
        return

    # 更新章节编号：原16-24变为17-25
    chapter_mapping = [
        ('## 16. 性能设计与优化', '## 17. 性能设计与优化'),
        ('## 17. 用户体验设计', '## 18. 用户体验设计'),
        ('## 18. 国际化与本地化', '## 19. 国际化与本地化'),
        ('## 19. 安全与隐私', '## 20. 安全与隐私'),
        ('## 20. 异常处理与容错设计', '## 21. 异常处理与容错设计'),
        ('## 21. 可扩展性与演进架构', '## 22. 可扩展性与演进架构'),
        ('## 22. 可观测性与监控', '## 23. 可观测性与监控'),
        ('## 23. 版本迁移策略', '## 24. 版本迁移策略'),
        ('## 24. 实施路线图', '## 25. 实施路线图'),
    ]

    for old, new in chapter_mapping:
        if old in content:
            content = content.replace(old, new)
            print(f"✅ 章节编号更新: {old} -> {new}")

    # 更新目录
    toc_updates = [
        ('16. 性能设计与优化', '17. 性能设计与优化'),
        ('17. 用户体验设计', '18. 用户体验设计'),
        ('18. 国际化与本地化', '19. 国际化与本地化'),
        ('19. 安全与隐私', '20. 安全与隐私'),
        ('20. 异常处理与容错设计', '21. 异常处理与容错设计'),
        ('21. 可扩展性与演进架构', '22. 可扩展性与演进架构'),
        ('22. 可观测性与监控', '23. 可观测性与监控'),
        ('23. 版本迁移策略', '24. 版本迁移策略'),
        ('24. 实施路线图', '25. 实施路线图'),
    ]

    for old, new in toc_updates:
        content = content.replace(old, new)

    # 在目录中添加第16章
    toc_insert_point = '- [16. 性能设计与优化'
    new_toc_entry = '''- [16. 自学习与协同学习系统](#16-自学习与协同学习系统)
  - [16.0 设计原则回顾](#160-设计原则回顾)
  - [16.1 统一自学习框架](#161-统一自学习框架)
  - [16.2 多用户协同学习系统](#162-多用户协同学习系统)
  - [16.3 各模块学习适配器](#163-各模块学习适配器)
  - [16.4 学习效果监控与报告](#164-学习效果监控与报告)
  - [16.5 与其他系统的集成](#165-与其他系统的集成)
  - [16.6 目标达成检测](#166-目标达成检测)
- [17. 性能设计与优化'''

    # 由于目录中原来是16，现在需要替换
    old_toc = '- [16. 性能设计与优化'
    if old_toc in content:
        content = content.replace(old_toc, new_toc_entry)
        print("✅ 目录已更新")

    # 保存文件
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n✅ 第16章抽取完成！")
    print("   - 新增独立章节：16. 自学习与协同学习系统")
    print("   - 原16-24章编号顺延为17-25章")

if __name__ == '__main__':
    main()
