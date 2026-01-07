# -*- coding: utf-8 -*-
"""
在15.12.1.1.7之后添加统一自学习框架，供系统各模块复用
"""

UNIFIED_FRAMEWORK_CONTENT = '''

##### 15.12.1.1.8 统一自学习框架（可复用）

将自学习能力抽象为统一框架，供系统其他智能模块复用，避免重复建设。

###### 15.12.1.1.8.1 可复用模块分析

| 模块 | 学习目标 | 输入数据 | 反馈信号 | 复用价值 |
|------|----------|----------|----------|----------|
| **15.2 智能分类** | 交易→分类映射 | 商家、描述、金额 | 用户修改分类 | ⭐⭐⭐⭐⭐ 最高频 |
| **15.3 预算建议** | 预算额度推荐 | 历史消费、收入 | 用户采纳/调整 | ⭐⭐⭐⭐ |
| **15.5 异常检测** | 异常判定阈值 | 交易特征 | 用户确认/忽略 | ⭐⭐⭐⭐ |
| **15.6 自然语言搜索** | 查询→意图映射 | 搜索词 | 点击结果 | ⭐⭐⭐⭐ |
| **15.7 对话助手** | 对话意图理解 | 对话文本 | 任务完成率 | ⭐⭐⭐⭐ |
| **15.8 资金分配** | 分配比例建议 | 收支结构 | 用户调整 | ⭐⭐⭐ |
| **15.12 语音交互** | 语音→意图映射 | 语音文本 | 用户确认/修改 | ⭐⭐⭐⭐⭐ 已实现 |

###### 15.12.1.1.8.2 统一学习框架架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        统一自学习框架 (Unified Learning Framework)                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         抽象学习接口层                                     │   │
│  │                                                                          │   │
│  │  interface ILearnable<TInput, TOutput, TFeedback> {                     │   │
│  │    Future<TOutput> predict(TInput input);           // 预测              │   │
│  │    Future<void> collectFeedback(TFeedback feedback); // 采集反馈         │   │
│  │    Future<void> learn();                             // 触发学习         │   │
│  │    Future<LearningMetrics> evaluate();               // 评估效果         │   │
│  │  }                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         核心组件层（可插拔）                               │   │
│  │                                                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │ SampleStore │  │ RuleEngine  │  │PatternMiner │  │ModelTrainer │    │   │
│  │  │  样本存储   │  │  规则引擎   │  │  模式挖掘   │  │  模型训练   │    │   │
│  │  │ • 采集      │  │ • 匹配      │  │ • 聚类      │  │ • 增量更新  │    │   │
│  │  │ • 标注      │  │ • 优先级    │  │ • 模板提取  │  │ • 批量训练  │    │   │
│  │  │ • 质量评分  │  │ • 冲突解决  │  │ • 同义发现  │  │ • 验证评估  │    │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         业务适配层（各模块实现）                           │   │
│  │                                                                          │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐ │   │
│  │  │ 分类学习  │ │ 预算学习  │ │ 异常学习  │ │ 搜索学习  │ │ 语音学习  │ │   │
│  │  │ Adapter   │ │ Adapter   │ │ Adapter   │ │ Adapter   │ │ Adapter   │ │   │
│  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘ └───────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

###### 15.12.1.1.8.3 核心抽象类设计

```dart
/// 统一学习样本基类
abstract class LearningSample<TInput, TOutput> {
  final String id;
  final TInput input;                 // 输入数据
  final TOutput predictedOutput;      // 预测输出
  final TOutput? actualOutput;        // 实际输出（用户反馈后）
  final double confidence;            // 预测置信度
  final SampleLabel label;            // 样本标签
  final DateTime timestamp;
  final String userId;
  final Map<String, dynamic> metadata;

  /// 样本质量评分（子类可覆盖）
  double get qualityScore;

  /// 是否为有效训练样本
  bool get isValidForTraining =>
      label != SampleLabel.ambiguous &&
      qualityScore >= 0.6;
}

/// 统一规则基类
abstract class LearnedRule<TInput, TOutput> {
  final String id;
  final String pattern;               // 匹配模式
  final TOutput output;               // 输出结果
  final double confidence;            // 置信度
  final int frequency;                // 命中频次
  final RuleSource source;            // 规则来源
  final DateTime createdAt;
  final List<String> examples;        // 示例

  /// 规则是否可靠
  bool get isReliable => confidence >= 0.9 && frequency >= 5;

  /// 尝试匹配输入
  MatchResult<TOutput>? tryMatch(TInput input);
}

/// 统一学习服务基类
abstract class BaseLearningService<TInput, TOutput, TSample extends LearningSample<TInput, TOutput>> {
  final SampleStore<TSample> sampleStore;
  final RuleEngine<TInput, TOutput> ruleEngine;
  final PatternMiner<TSample> patternMiner;

  /// 预测（多级策略）
  Future<PredictionResult<TOutput>> predict(TInput input) async {
    // Level 1: 用户个性化规则
    final personalResult = await _matchPersonalRules(input);
    if (personalResult != null && personalResult.confidence >= 0.95) {
      return personalResult;
    }

    // Level 2: 全局规则
    final ruleResult = await ruleEngine.match(input);
    if (ruleResult != null && ruleResult.confidence >= 0.9) {
      return ruleResult;
    }

    // Level 3: 相似样本匹配
    final similarResult = await _matchSimilarSamples(input);
    if (similarResult != null && similarResult.confidence >= 0.85) {
      return similarResult;
    }

    // Level 4: 子类实现的兜底策略（如LLM）
    return await fallbackPredict(input);
  }

  /// 兜底预测（子类实现）
  Future<PredictionResult<TOutput>> fallbackPredict(TInput input);

  /// 采集反馈
  Future<void> collectFeedback({
    required String sampleId,
    required FeedbackType feedbackType,
    TOutput? correctedOutput,
  }) async {
    final sample = await sampleStore.get(sampleId);
    if (sample == null) return;

    final updatedSample = updateSampleWithFeedback(sample, feedbackType, correctedOutput);
    await sampleStore.update(updatedSample);

    // 触发增量学习
    if (updatedSample.qualityScore >= 0.7) {
      await incrementalLearn(updatedSample);
    }
  }

  /// 更新样本（子类可覆盖）
  TSample updateSampleWithFeedback(TSample sample, FeedbackType type, TOutput? corrected);

  /// 增量学习
  Future<void> incrementalLearn(TSample sample) async {
    // 1. 尝试生成新规则
    final similarSamples = await sampleStore.findSimilar(sample, limit: 10);
    if (similarSamples.length >= 3) {
      final newRule = await patternMiner.tryGenerateRule(sample, similarSamples);
      if (newRule != null) {
        await ruleEngine.addRule(newRule);
      }
    }

    // 2. 更新个性化模型
    await updatePersonalizedModel(sample);
  }

  /// 更新个性化模型（子类实现）
  Future<void> updatePersonalizedModel(TSample sample);

  /// 评估学习效果
  Future<LearningMetrics> evaluate() async {
    final recentSamples = await sampleStore.getRecent(days: 30);
    return LearningMetrics(
      accuracy: _calculateAccuracy(recentSamples),
      ruleContribution: _calculateRuleContribution(recentSamples),
      userSatisfaction: _calculateSatisfaction(recentSamples),
    );
  }
}
```

###### 15.12.1.1.8.4 智能分类模块适配示例

```dart
/// 分类学习样本
class CategoryLearningSample extends LearningSample<TransactionInput, Category> {
  final String? merchantName;
  final List<String> keywords;

  @override
  double get qualityScore {
    var score = 0.0;
    if (label == SampleLabel.confirmedPositive) score += 0.5;
    if (label == SampleLabel.corrected) score += 0.4;
    if (confidence > 0.9) score += 0.2;
    if (merchantName != null) score += 0.1;  // 有商家信息更有价值
    return score.clamp(0.0, 1.0);
  }
}

/// 分类学习服务
class CategoryLearningService extends BaseLearningService<
    TransactionInput, Category, CategoryLearningSample> {

  final LLMService _llmService;

  @override
  Future<PredictionResult<Category>> fallbackPredict(TransactionInput input) async {
    // LLM兜底分类
    final result = await _llmService.classifyTransaction(input);
    return PredictionResult(
      output: result.category,
      confidence: result.confidence,
      source: PredictionSource.llm,
    );
  }

  @override
  Future<void> updatePersonalizedModel(CategoryLearningSample sample) async {
    // 更新商家-分类映射缓存
    if (sample.merchantName != null && sample.actualOutput != null) {
      await _updateMerchantCategoryCache(
        sample.merchantName!,
        sample.actualOutput!,
      );
    }

    // 更新关键词权重
    for (final keyword in sample.keywords) {
      await _updateKeywordWeight(keyword, sample.actualOutput!);
    }
  }
}

/// 分类学习规则
class CategoryRule extends LearnedRule<TransactionInput, Category> {

  final List<String> keywords;        // 触发关键词
  final String? merchantPattern;      // 商家匹配模式

  @override
  MatchResult<Category>? tryMatch(TransactionInput input) {
    // 商家精确匹配
    if (merchantPattern != null &&
        input.merchant?.contains(merchantPattern) == true) {
      return MatchResult(output: output, confidence: confidence);
    }

    // 关键词匹配
    final matchedKeywords = keywords.where(
      (k) => input.description.contains(k)
    ).length;

    if (matchedKeywords > 0) {
      final matchConfidence = confidence * (matchedKeywords / keywords.length);
      return MatchResult(output: output, confidence: matchConfidence);
    }

    return null;
  }
}
```

###### 15.12.1.1.8.5 异常检测模块适配示例

```dart
/// 异常检测学习样本
class AnomalyLearningSample extends LearningSample<Transaction, AnomalyType> {
  final double zScore;           // 统计异常分数
  final List<String> features;   // 触发特征

  @override
  double get qualityScore {
    var score = 0.0;
    // 用户明确确认是/不是异常
    if (label == SampleLabel.confirmedPositive) score += 0.5;
    if (label == SampleLabel.negative) score += 0.4;  // 用户说不是异常也很重要
    if (zScore > 3) score += 0.2;  // 统计显著的样本更有价值
    return score.clamp(0.0, 1.0);
  }
}

/// 异常检测学习服务
class AnomalyLearningService extends BaseLearningService<
    Transaction, AnomalyType, AnomalyLearningSample> {

  @override
  Future<PredictionResult<AnomalyType>> fallbackPredict(Transaction input) async {
    // 统计模型兜底
    final zScore = await _calculateZScore(input);
    final anomalyType = _classifyByZScore(zScore);

    return PredictionResult(
      output: anomalyType,
      confidence: _zScoreToConfidence(zScore),
      source: PredictionSource.statistical,
    );
  }

  @override
  Future<void> updatePersonalizedModel(AnomalyLearningSample sample) async {
    // 用户说不是异常 → 调整该用户的异常阈值
    if (sample.label == SampleLabel.negative) {
      await _adjustUserAnomalyThreshold(
        sample.userId,
        sample.input.amount,
        sample.input.categoryId,
      );
    }

    // 用户确认是异常 → 学习新的异常模式
    if (sample.label == SampleLabel.confirmedPositive) {
      await _learnAnomalyPattern(sample);
    }
  }

  /// 调整用户异常阈值
  Future<void> _adjustUserAnomalyThreshold(
    String userId,
    double amount,
    String? categoryId,
  ) async {
    // 如果用户经常忽略某类金额的异常提醒，提高该类别的阈值
    final userThresholds = await _getUserThresholds(userId);

    if (categoryId != null) {
      final currentThreshold = userThresholds[categoryId] ?? 3.0;
      // 渐进式调整
      userThresholds[categoryId] = currentThreshold * 1.1;
      await _saveUserThresholds(userId, userThresholds);
    }
  }
}
```

###### 15.12.1.1.8.6 自然语言搜索适配示例

```dart
/// 搜索学习样本
class SearchLearningSample extends LearningSample<String, SearchIntent> {
  final List<SearchResult> returnedResults;  // 返回的结果
  final SearchResult? clickedResult;         // 用户点击的结果
  final int clickPosition;                   // 点击位置

  @override
  double get qualityScore {
    var score = 0.0;
    // 用户有点击行为
    if (clickedResult != null) score += 0.4;
    // 点击位置靠前说明预测准确
    if (clickPosition <= 3) score += 0.3;
    // 有明确的意图修改
    if (label == SampleLabel.corrected) score += 0.3;
    return score.clamp(0.0, 1.0);
  }
}

/// 搜索学习服务
class SearchLearningService extends BaseLearningService<
    String, SearchIntent, SearchLearningSample> {

  @override
  Future<PredictionResult<SearchIntent>> fallbackPredict(String input) async {
    // LLM 意图识别
    final result = await _llmService.parseSearchIntent(input);
    return PredictionResult(
      output: result.intent,
      confidence: result.confidence,
      source: PredictionSource.llm,
    );
  }

  @override
  Future<void> updatePersonalizedModel(SearchLearningSample sample) async {
    // 学习用户搜索习惯
    // 如：用户搜"咖啡"总是想看本月消费 → 建立关联
    if (sample.clickedResult != null) {
      await _learnSearchPattern(
        query: sample.input,
        selectedIntent: sample.clickedResult!.intent,
        selectedFilters: sample.clickedResult!.filters,
      );
    }
  }
}
```

###### 15.12.1.1.8.7 框架复用效益分析

| 复用组件 | 代码复用率 | 开发节省 | 维护成本降低 |
|----------|------------|----------|--------------|
| 样本存储 | 90% | 3人天 | 统一Schema |
| 规则引擎 | 85% | 5人天 | 统一优先级策略 |
| 模式挖掘 | 80% | 4人天 | 共享算法库 |
| 增量学习 | 85% | 4人天 | 统一触发机制 |
| 效果评估 | 95% | 2人天 | 统一指标体系 |
| 协同学习 | 70% | 6人天 | 共享聚合服务 |
| **总计** | **~85%** | **~24人天** | **单一代码库** |

**各模块自学习能力建设路径**：

```
Phase 1 (2周)：语音意图自学习（已完成）
    ↓
Phase 2 (1周)：抽象统一框架
    ↓
Phase 3 (1周)：智能分类适配
    ↓
Phase 4 (1周)：异常检测适配
    ↓
Phase 5 (1周)：搜索/对话适配
    ↓
Phase 6 (2周)：协同学习统一接入
```

'''

def main():
    # 读取文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查是否已存在
    if '15.12.1.1.8 统一自学习框架' in content:
        print("Unified learning framework section already exists, skipping")
        return

    # 查找插入点：在 "#### 15.12.2 语音记账模块" 之前
    marker = '#### 15.12.2 语音记账模块'
    idx = content.find(marker)

    if idx == -1:
        print(f"Error: Cannot find marker '{marker}'")
        return

    # 插入新内容
    before = content[:idx].rstrip()
    after = content[idx:]

    new_content = before + '\n' + UNIFIED_FRAMEWORK_CONTENT.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully added unified learning framework!')
    print(f'Old size: {len(content)} characters')
    print(f'New size: {len(new_content)} characters')
    print(f'Added: {len(new_content) - len(content)} characters')

if __name__ == '__main__':
    main()
