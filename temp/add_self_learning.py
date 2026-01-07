# -*- coding: utf-8 -*-
"""
在15.12.1意图识别引擎之后添加自学习模型方案
"""

SELF_LEARNING_CONTENT = '''
#### 15.12.1.1 意图识别自学习模型

通过持续积累用户交互数据，构建个性化意图识别模型，不断提升识别准确率。

##### 15.12.1.1.1 自学习系统架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        意图识别自学习系统架构                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         数据采集层                                        │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │ 语音输入    │  │ 识别结果    │  │ 用户反馈    │  │ 行为轨迹    │    │   │
│  │  │ • 原始文本  │  │ • 意图类型  │  │ • 确认/修改 │  │ • 点击操作  │    │   │
│  │  │ • 语音特征  │  │ • 置信度    │  │ • 取消/重说 │  │ • 停留时间  │    │   │
│  │  │ • 上下文    │  │ • 识别源    │  │ • 评分反馈  │  │ • 最终选择  │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         样本标注层                                        │   │
│  │  ┌───────────────────────┐  ┌───────────────────────┐                   │   │
│  │  │    自动标注引擎        │  │    人工校正通道        │                   │   │
│  │  │  • 用户确认 → 正样本   │  │  • 用户修改 → 校正样本 │                   │   │
│  │  │  • 执行成功 → 正样本   │  │  • 用户取消 → 负样本   │                   │   │
│  │  │  • 高置信度 → 弱正样本 │  │  • 重新输入 → 参考样本 │                   │   │
│  │  └───────────────────────┘  └───────────────────────┘                   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         模型训练层                                        │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │ 规则挖掘    │  │ 模式学习    │  │ 个性化适配  │  │ 在线更新    │    │   │
│  │  │ • 高频模式  │  │ • 表达习惯  │  │ • 用户偏好  │  │ • 增量学习  │    │   │
│  │  │ • 新表达    │  │ • 词汇扩展  │  │ • 场景上下文│  │ • 实时反馈  │    │   │
│  │  │ • 规则生成  │  │ • 同义映射  │  │ • 时间规律  │  │ • A/B测试   │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         模型应用层                                        │   │
│  │  ┌───────────────────────────────────────────────────────────────┐      │   │
│  │  │              多级识别策略（带自学习增强）                         │      │   │
│  │  │  Level 1: 用户个性化规则（自学习生成）→ 最高优先级             │      │   │
│  │  │  Level 2: 全局规则匹配（基础规则库）                            │      │   │
│  │  │  Level 3: 相似度匹配（学习到的表达模式）                        │      │   │
│  │  │  Level 4: LLM 兜底（带个性化 Prompt 增强）                      │      │   │
│  │  └───────────────────────────────────────────────────────────────┘      │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

##### 15.12.1.1.2 数据采集与样本构建

```dart
/// 意图识别学习样本
class IntentLearningSample {
  final String id;
  final String rawInput;              // 原始输入文本
  final String normalizedInput;       // 标准化后的文本
  final VoiceIntentType predictedIntent;  // 系统预测的意图
  final VoiceIntentType? actualIntent;    // 实际意图（用户确认/修改后）
  final double confidence;            // 预测置信度
  final IntentSource source;          // 识别来源
  final SampleLabel label;            // 样本标签
  final Map<String, dynamic> context; // 上下文信息
  final DateTime timestamp;
  final String userId;

  /// 样本质量评分（0-1）
  double get qualityScore {
    var score = 0.0;
    // 用户明确确认的样本质量最高
    if (label == SampleLabel.confirmedPositive) score += 0.5;
    // 用户主动修改提供的样本次之
    if (label == SampleLabel.corrected) score += 0.4;
    // 高置信度样本
    if (confidence > 0.9) score += 0.2;
    // 有完整上下文
    if (context.isNotEmpty) score += 0.1;
    // 最近的样本权重更高
    final daysSince = DateTime.now().difference(timestamp).inDays;
    score *= (1 - daysSince / 365).clamp(0.5, 1.0);
    return score.clamp(0.0, 1.0);
  }
}

/// 样本标签类型
enum SampleLabel {
  confirmedPositive,  // 用户确认的正样本
  corrected,          // 用户修改后的校正样本
  implicitPositive,   // 隐式正样本（执行成功无投诉）
  weakPositive,       // 弱正样本（高置信度未确认）
  negative,           // 负样本（用户取消/拒绝）
  ambiguous,          // 歧义样本（需人工审核）
}

/// 数据采集服务
class IntentDataCollector {
  final DatabaseService _db;
  final AnalyticsService _analytics;

  /// 采集识别结果
  Future<void> collectRecognitionResult({
    required String rawInput,
    required VoiceIntentType predictedIntent,
    required double confidence,
    required IntentSource source,
    required Map<String, dynamic> context,
  }) async {
    final sample = IntentLearningSample(
      id: _generateId(),
      rawInput: rawInput,
      normalizedInput: _normalize(rawInput),
      predictedIntent: predictedIntent,
      actualIntent: null,  // 待用户反馈后更新
      confidence: confidence,
      source: source,
      label: SampleLabel.weakPositive,
      context: context,
      timestamp: DateTime.now(),
      userId: _currentUserId,
    );
    await _db.insertLearningSample(sample);
  }

  /// 采集用户反馈
  Future<void> collectUserFeedback({
    required String sampleId,
    required UserFeedbackType feedbackType,
    VoiceIntentType? correctedIntent,
  }) async {
    final sample = await _db.getLearningSample(sampleId);
    if (sample == null) return;

    final updatedSample = sample.copyWith(
      actualIntent: correctedIntent ?? sample.predictedIntent,
      label: _mapFeedbackToLabel(feedbackType, sample),
    );
    await _db.updateLearningSample(updatedSample);

    // 触发增量学习
    if (updatedSample.qualityScore > 0.7) {
      await _triggerIncrementalLearning(updatedSample);
    }
  }
}

enum UserFeedbackType { confirm, modify, cancel, retry, executeSuccess }
```

##### 15.12.1.1.3 自学习模型训练

```dart
/// 意图识别自学习服务
class IntentLearningService {
  final DatabaseService _db;
  final RuleEngine _ruleEngine;
  final PatternMatcher _patternMatcher;

  /// 从高质量样本中挖掘新规则
  Future<List<LearnedRule>> mineRulesFromSamples() async {
    final samples = await _db.getHighQualitySamples(
      minQualityScore: 0.8,
      minCount: 5,  // 至少5个相似样本才生成规则
    );

    final rules = <LearnedRule>[];
    final groupedByIntent = _groupByIntent(samples);

    for (final entry in groupedByIntent.entries) {
      final intent = entry.key;
      final intentSamples = entry.value;

      // 提取高频模式
      final patterns = _extractPatterns(intentSamples);

      for (final pattern in patterns) {
        if (pattern.frequency >= 3 && pattern.confidence >= 0.9) {
          rules.add(LearnedRule(
            id: _generateRuleId(),
            pattern: pattern.regex,
            intent: intent,
            confidence: pattern.confidence,
            frequency: pattern.frequency,
            examples: pattern.examples.take(5).toList(),
            createdAt: DateTime.now(),
            source: RuleSource.learned,
          ));
        }
      }
    }
    return rules;
  }

  /// 构建用户个性化意图模型
  Future<PersonalizedIntentModel> buildPersonalizedModel(String userId) async {
    final userSamples = await _db.getUserSamples(userId);

    return PersonalizedIntentModel(
      userId: userId,
      expressionHabits: _analyzeExpressionHabits(userSamples),
      intentFrequency: _analyzeIntentFrequency(userSamples),
      contextPreferences: _analyzeContextPreferences(userSamples),
      timePatterns: _analyzeTimePatterns(userSamples),
      learnedRules: await _getUserLearnedRules(userId),
      lastUpdated: DateTime.now(),
    );
  }

  /// 增量更新模型
  Future<void> incrementalUpdate(IntentLearningSample newSample) async {
    // 1. 更新用户个性化模型
    await _updatePersonalizedModel(newSample);

    // 2. 检查是否需要生成新规则
    final similarSamples = await _db.findSimilarSamples(
      newSample.normalizedInput,
      limit: 10,
    );

    if (similarSamples.length >= 3) {
      final newRule = _tryGenerateRule(newSample, similarSamples);
      if (newRule != null) {
        await _ruleEngine.addLearnedRule(newRule);
      }
    }

    // 3. 更新相似度索引
    await _patternMatcher.updateIndex(newSample);
  }
}

/// 学习到的规则
class LearnedRule {
  final String id;
  final String pattern;          // 正则表达式模式
  final VoiceIntentType intent;  // 目标意图
  final double confidence;       // 置信度
  final int frequency;           // 出现频次
  final List<String> examples;   // 示例
  final DateTime createdAt;
  final RuleSource source;

  bool get isReliable => confidence >= 0.9 && frequency >= 5;
}

enum RuleSource { builtin, learned, userCustom }

/// 用户个性化意图模型
class PersonalizedIntentModel {
  final String userId;
  final ExpressionHabits expressionHabits;
  final Map<VoiceIntentType, double> intentFrequency;
  final Map<String, dynamic> contextPreferences;
  final TimePatterns timePatterns;
  final List<LearnedRule> learnedRules;
  final DateTime lastUpdated;

  /// 获取意图先验概率
  double getIntentPrior(VoiceIntentType intent) {
    return intentFrequency[intent] ?? 0.01;
  }

  /// 根据时间调整意图概率（贝叶斯）
  double adjustByTime(VoiceIntentType intent, DateTime time) {
    final hourProbability = timePatterns.getHourProbability(intent, time.hour);
    final dayProbability = timePatterns.getDayProbability(intent, time.weekday);
    return hourProbability * dayProbability;
  }
}
```

##### 15.12.1.1.4 增强的意图识别流程

```dart
/// 带自学习增强的意图识别服务
class EnhancedIntentRecognitionService {
  final RuleEngine _ruleEngine;
  final IntentLearningService _learningService;
  final LLMService _llmService;
  final IntentDataCollector _dataCollector;

  /// 识别意图（四级策略 + 自学习增强）
  Future<IntentRecognitionResult> recognizeIntent(
    String input, {
    Map<String, dynamic>? context,
  }) async {
    final normalizedInput = _normalize(input);
    final userId = _getCurrentUserId();

    // 获取用户个性化模型
    final personalModel = await _learningService.getPersonalizedModel(userId);

    // Level 1: 用户个性化规则（自学习生成，最高优先级）
    final personalResult = await _matchPersonalRules(normalizedInput, personalModel);
    if (personalResult != null && personalResult.confidence >= 0.95) {
      await _collectSample(input, personalResult, IntentSource.learned);
      return personalResult;
    }

    // Level 2: 全局规则匹配
    final ruleResult = await _ruleEngine.match(normalizedInput);
    if (ruleResult != null && ruleResult.confidence >= 0.9) {
      final adjustedConfidence = _adjustWithPrior(
        ruleResult.confidence, ruleResult.intent, personalModel);
      await _collectSample(input, ruleResult, IntentSource.rule);
      return ruleResult.copyWith(confidence: adjustedConfidence);
    }

    // Level 3: 相似度匹配（基于学习到的表达模式）
    final similarResult = await _matchSimilarPatterns(normalizedInput, personalModel);
    if (similarResult != null && similarResult.confidence >= 0.85) {
      await _collectSample(input, similarResult, IntentSource.learned);
      return similarResult;
    }

    // Level 4: LLM 兜底（带个性化 Prompt 增强）
    final llmResult = await _llmRecognize(input,
      personalModel: personalModel, context: context);
    await _collectSample(input, llmResult, IntentSource.llm);
    return llmResult;
  }

  /// 构建个性化 Prompt
  String _buildPersonalizedPrompt(
    String input,
    PersonalizedIntentModel? model,
    Map<String, dynamic>? context,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('请识别以下语音输入的意图：');
    buffer.writeln('输入："$input"');

    if (model != null) {
      buffer.writeln('\\n用户习惯参考：');
      // 高频意图
      final topIntents = model.intentFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buffer.writeln('- 常用意图：${topIntents.take(5).map((e) => e.key.name).join('、')}');
      // 同义词映射
      if (model.expressionHabits.synonymMappings.isNotEmpty) {
        buffer.writeln('- 用户同义词：');
        for (final entry in model.expressionHabits.synonymMappings.entries.take(5)) {
          buffer.writeln('  "${entry.key}" → "${entry.value}"');
        }
      }
    }
    return buffer.toString();
  }

  /// 应用先验概率调整置信度（贝叶斯）
  double _adjustWithPrior(double confidence, VoiceIntentType intent,
      PersonalizedIntentModel? model) {
    if (model == null) return confidence;
    final prior = model.getIntentPrior(intent);
    final timeAdjust = model.adjustByTime(intent, DateTime.now());
    return (confidence * prior * timeAdjust).clamp(0.0, 1.0);
  }
}
```

##### 15.12.1.1.5 学习效果评估与监控

```dart
/// 自学习效果评估服务
class LearningEvaluationService {
  /// 评估指标
  Future<LearningMetrics> evaluateLearningEffect() async {
    return LearningMetrics(
      overallAccuracy: await _calculateOverallAccuracy(),
      intentAccuracy: await _calculateIntentAccuracy(),
      learnedRuleContribution: await _calculateLearnedRuleContribution(),
      userSatisfaction: await _calculateUserSatisfaction(),
      latencyTrend: await _analyzeLatencyTrend(),
      ruleCoverageTrend: await _analyzeRuleCoverageTrend(),
    );
  }

  /// 生成学习报告
  Future<LearningReport> generateLearningReport() async {
    final metrics = await evaluateLearningEffect();
    return LearningReport(
      period: DateRange.last30Days(),
      metrics: metrics,
      improvements: await _identifyImprovements(),
      recommendations: await _generateRecommendations(metrics),
      newRulesCount: await _countNewRules(days: 30),
      topLearnedPatterns: await _getTopLearnedPatterns(limit: 10),
    );
  }
}

/// 学习指标
class LearningMetrics {
  double overallAccuracy;           // 整体准确率
  Map<VoiceIntentType, double> intentAccuracy;  // 各意图准确率
  double learnedRuleContribution;   // 自学习规则贡献率
  double userSatisfaction;          // 用户满意度
  List<double> latencyTrend;        // 延迟趋势
  List<double> ruleCoverageTrend;   // 规则覆盖率趋势

  /// 是否需要优化
  bool get needsOptimization =>
      overallAccuracy < 0.85 ||
      userSatisfaction < 0.8 ||
      learnedRuleContribution < 0.1;
}
```

##### 15.12.1.1.6 自学习效果预期

| 阶段 | 时间周期 | 预期效果 | 关键指标 |
|------|----------|----------|----------|
| **冷启动期** | 0-2周 | 积累基础样本 | 样本数 > 100 |
| **初步学习期** | 2-4周 | 生成首批个性化规则 | 规则数 > 10, 准确率提升 5% |
| **快速提升期** | 1-3月 | 个性化模型成熟 | 准确率 > 90%, 规则贡献率 > 20% |
| **稳定优化期** | 3月+ | 持续微调优化 | 准确率 > 95%, 满意度 > 90% |

**核心优化目标**：
- 整体识别准确率：85% → 95%+
- 规则匹配覆盖率：60% → 80%+
- LLM 兜底比例：40% → 15%（节省成本）
- 平均识别延迟：500ms → 200ms（规则命中更快）
- 用户修改率：15% → 5%（减少纠错成本）

'''

def main():
    # 读取文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 查找插入点：在 "#### 15.12.2 语音记账模块" 之前
    marker = '#### 15.12.2 语音记账模块'
    idx = content.find(marker)

    if idx == -1:
        print(f"Error: Cannot find marker '{marker}'")
        return

    # 检查是否已经存在自学习模型章节
    if '15.12.1.1 意图识别自学习模型' in content:
        print("Self-learning model section already exists, skipping")
        return

    # 同时更新 IntentSource enum
    old_enum = 'enum IntentSource { rule, llm, fallback }'
    new_enum = 'enum IntentSource { rule, llm, fallback, learned }'

    if old_enum in content:
        content = content.replace(old_enum, new_enum)
        print("Updated IntentSource enum")

    # 插入新内容
    before = content[:idx].rstrip()
    after = content[idx:]

    new_content = before + '\n\n' + SELF_LEARNING_CONTENT.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully added self-learning model section!')
    print(f'Old size: {len(content)} characters')
    print(f'New size: {len(new_content)} characters')
    print(f'Added: {len(new_content) - len(content)} characters')

if __name__ == '__main__':
    main()
