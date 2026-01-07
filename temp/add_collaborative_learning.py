# -*- coding: utf-8 -*-
"""
在15.12.1.1.6之后添加多用户协同学习方案
"""

COLLABORATIVE_LEARNING_CONTENT = '''

##### 15.12.1.1.7 多用户协同学习系统

当用户量达到一定规模时，可以利用群体智慧进行协同学习，在保护隐私的前提下共享学习成果。

###### 15.12.1.1.7.1 协同学习架构

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        多用户协同学习系统架构                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         端侧（个人设备）                                   │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │   │
│  │  │  用户 A     │  │  用户 B     │  │  用户 C     │  │  用户 N     │    │   │
│  │  │ • 本地样本  │  │ • 本地样本  │  │ • 本地样本  │  │ • 本地样本  │    │   │
│  │  │ • 个性化模型│  │ • 个性化模型│  │ • 个性化模型│  │ • 个性化模型│    │   │
│  │  │ • 学习规则  │  │ • 学习规则  │  │ • 学习规则  │  │ • 学习规则  │    │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │   │
│  │         │                │                │                │            │   │
│  │         └────────────────┴────────────────┴────────────────┘            │   │
│  │                                   │                                      │   │
│  │                          上传脱敏模式/规则                                │   │
│  └───────────────────────────────────┼─────────────────────────────────────┘   │
│                                      ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         云端（协同学习服务）                               │   │
│  │                                                                          │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │   │
│  │  │                      模式聚合引擎                                  │    │   │
│  │  │  • 规则投票聚合：相同模式被多用户学习 → 提升为全局规则            │    │   │
│  │  │  • 置信度加权：用户质量评分 × 规则置信度 → 聚合权重               │    │   │
│  │  │  • 冲突消解：不同用户学习到矛盾规则 → 多数投票 / 置信度优先        │    │   │
│  │  │  • 新表达发现：低频但高质量的新表达 → 候选全局规则                 │    │   │
│  │  └─────────────────────────────────────────────────────────────────┘    │   │
│  │                                   │                                      │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │   │
│  │  │                      全局模型仓库                                  │    │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │    │   │
│  │  │  │ 基础规则库  │  │ 群体学习库  │  │ 热门表达库  │              │    │   │
│  │  │  │ (内置1000+) │  │ (聚合规则)  │  │ (高频模式)  │              │    │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘              │    │   │
│  │  └─────────────────────────────────────────────────────────────────┘    │   │
│  │                                   │                                      │   │
│  │                          下发全局模型更新                                │   │
│  └───────────────────────────────────┼─────────────────────────────────────┘   │
│                                      ↓                                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         端侧（模型融合）                                   │   │
│  │                                                                          │   │
│  │  ┌───────────────────────────────────────────────────────────────┐      │   │
│  │  │            最终识别模型 = 全局模型 + 个性化模型                   │      │   │
│  │  │                                                                │      │   │
│  │  │  优先级：个性化规则 > 群体学习规则 > 基础规则 > LLM兜底          │      │   │
│  │  └───────────────────────────────────────────────────────────────┘      │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

###### 15.12.1.1.7.2 隐私保护设计

```dart
/// 隐私保护的模式上报
class PrivacyPreservingPatternReporter {

  /// 上报学习到的模式（非原始数据）
  Future<void> reportLearnedPattern(LearnedRule rule) async {
    // 1. 脱敏处理：只上报模式，不上报原始样本
    final sanitizedPattern = SanitizedPattern(
      // 模式模板（如："把{category}预算改成{amount}"）
      template: rule.pattern,
      // 意图类型
      intent: rule.intent,
      // 本地置信度
      localConfidence: rule.confidence,
      // 本地命中频次
      localFrequency: rule.frequency,
      // 用户ID哈希（不可逆）
      userHash: _hashUserId(_currentUserId),
      // 设备指纹（用于去重）
      deviceFingerprint: _getDeviceFingerprint(),
    );

    // 2. 差分隐私：添加噪声
    final noisyPattern = _addDifferentialPrivacyNoise(sanitizedPattern);

    // 3. 上报到云端
    await _cloudService.reportPattern(noisyPattern);
  }

  /// 差分隐私噪声添加
  SanitizedPattern _addDifferentialPrivacyNoise(SanitizedPattern pattern) {
    // 对频次添加拉普拉斯噪声
    final noisyFrequency = pattern.localFrequency +
        _laplacianNoise(sensitivity: 1.0, epsilon: 0.5);

    // 对置信度添加高斯噪声
    final noisyConfidence = (pattern.localConfidence +
        _gaussianNoise(sigma: 0.05)).clamp(0.0, 1.0);

    return pattern.copyWith(
      localFrequency: noisyFrequency.round().clamp(1, 1000),
      localConfidence: noisyConfidence,
    );
  }
}

/// 脱敏后的模式结构
class SanitizedPattern {
  final String template;        // 模式模板（无具体数值/名称）
  final VoiceIntentType intent; // 意图类型
  final double localConfidence; // 本地置信度（加噪后）
  final int localFrequency;     // 本地频次（加噪后）
  final String userHash;        // 用户哈希
  final String deviceFingerprint;
}
```

###### 15.12.1.1.7.3 群体规则聚合

```dart
/// 云端规则聚合服务
class GlobalPatternAggregationService {

  /// 聚合来自多用户的模式
  Future<List<GlobalRule>> aggregatePatterns() async {
    final allPatterns = await _db.getAllReportedPatterns();
    final globalRules = <GlobalRule>[];

    // 按模式模板分组
    final groupedByTemplate = _groupByTemplate(allPatterns);

    for (final entry in groupedByTemplate.entries) {
      final template = entry.key;
      final patterns = entry.value;

      // 计算聚合指标
      final stats = _calculateAggregationStats(patterns);

      // 判断是否达到全局规则标准
      if (_meetsGlobalRuleThreshold(stats)) {
        globalRules.add(GlobalRule(
          id: _generateRuleId(),
          template: template,
          intent: _resolveIntent(patterns),  // 投票决定意图
          globalConfidence: stats.weightedConfidence,
          userCount: stats.uniqueUserCount,
          totalFrequency: stats.totalFrequency,
          createdAt: DateTime.now(),
          source: RuleSource.crowdLearned,
        ));
      }
    }

    return globalRules;
  }

  /// 计算聚合统计
  AggregationStats _calculateAggregationStats(List<SanitizedPattern> patterns) {
    // 去重用户数
    final uniqueUsers = patterns.map((p) => p.userHash).toSet().length;

    // 总频次
    final totalFrequency = patterns.fold<int>(
      0, (sum, p) => sum + p.localFrequency);

    // 加权置信度（用户质量评分 × 本地置信度）
    var weightedSum = 0.0;
    var weightTotal = 0.0;
    for (final pattern in patterns) {
      final userQuality = _getUserQualityScore(pattern.userHash);
      weightedSum += pattern.localConfidence * userQuality;
      weightTotal += userQuality;
    }
    final weightedConfidence = weightTotal > 0 ? weightedSum / weightTotal : 0.0;

    return AggregationStats(
      uniqueUserCount: uniqueUsers,
      totalFrequency: totalFrequency,
      weightedConfidence: weightedConfidence,
      patternCount: patterns.length,
    );
  }

  /// 判断是否满足全局规则阈值
  bool _meetsGlobalRuleThreshold(AggregationStats stats) {
    return stats.uniqueUserCount >= 10 &&      // 至少10个不同用户
           stats.totalFrequency >= 50 &&        // 至少50次命中
           stats.weightedConfidence >= 0.85;    // 加权置信度 >= 85%
  }

  /// 投票决定意图（处理冲突）
  VoiceIntentType _resolveIntent(List<SanitizedPattern> patterns) {
    final votes = <VoiceIntentType, double>{};

    for (final pattern in patterns) {
      final userQuality = _getUserQualityScore(pattern.userHash);
      final weight = pattern.localConfidence * userQuality * pattern.localFrequency;
      votes[pattern.intent] = (votes[pattern.intent] ?? 0) + weight;
    }

    // 返回得票最高的意图
    return votes.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

/// 全局规则
class GlobalRule {
  final String id;
  final String template;
  final VoiceIntentType intent;
  final double globalConfidence;
  final int userCount;           // 贡献用户数
  final int totalFrequency;      // 全局总命中数
  final DateTime createdAt;
  final RuleSource source;

  /// 全局规则质量评分
  double get qualityScore {
    final userScore = (userCount / 100).clamp(0.0, 1.0);
    final frequencyScore = (totalFrequency / 1000).clamp(0.0, 1.0);
    return globalConfidence * 0.5 + userScore * 0.3 + frequencyScore * 0.2;
  }
}
```

###### 15.12.1.1.7.4 新用户冷启动加速

```dart
/// 新用户冷启动服务
class ColdStartAccelerationService {
  final GlobalModelRepository _globalRepo;
  final UserProfileService _profileService;

  /// 为新用户初始化模型
  Future<PersonalizedIntentModel> initializeNewUserModel(String userId) async {
    // 1. 获取全局热门规则
    final hotRules = await _globalRepo.getHotRules(limit: 100);

    // 2. 获取用户画像相似群体的规则
    final userProfile = await _profileService.getProfile(userId);
    final similarGroupRules = await _getSimilarGroupRules(userProfile);

    // 3. 构建初始化模型
    return PersonalizedIntentModel(
      userId: userId,
      expressionHabits: ExpressionHabits.defaults(),
      intentFrequency: _getDefaultIntentFrequency(),
      contextPreferences: {},
      timePatterns: TimePatterns.defaults(),
      learnedRules: [],  // 个人规则为空
      inheritedRules: [...hotRules, ...similarGroupRules],  // 继承全局规则
      lastUpdated: DateTime.now(),
    );
  }

  /// 获取相似用户群体的规则
  Future<List<GlobalRule>> _getSimilarGroupRules(UserProfile profile) async {
    // 基于用户特征匹配相似群体
    final similarityFactors = {
      'age_group': profile.ageGroup,        // 年龄段
      'profession': profile.profession,      // 职业
      'usage_frequency': profile.usageFrequency,  // 使用频率
      'primary_intent': profile.primaryIntent,    // 主要使用场景
    };

    return await _globalRepo.getRulesBySimilarity(
      factors: similarityFactors,
      limit: 50,
    );
  }
}

/// 用户画像
class UserProfile {
  final String ageGroup;        // 年龄段：18-25, 26-35, 36-45, 46+
  final String profession;      // 职业类型：student, employee, business, freelance
  final String usageFrequency;  // 使用频率：daily, weekly, occasional
  final String primaryIntent;   // 主要意图：bookkeeping, budgeting, investing
}
```

###### 15.12.1.1.7.5 A/B 测试与渐进式发布

```dart
/// 全局规则发布服务
class GlobalRuleReleaseService {

  /// 渐进式发布新规则
  Future<void> releaseRule(GlobalRule rule) async {
    // 阶段1：内部测试（1%用户）
    await _releaseToGroup(
      rule: rule,
      targetPercentage: 1,
      group: ReleaseGroup.internal,
      duration: Duration(days: 3),
    );

    // 阶段2：灰度发布（10%用户）
    final internalMetrics = await _evaluateRulePerformance(rule);
    if (internalMetrics.successRate >= 0.9) {
      await _releaseToGroup(
        rule: rule,
        targetPercentage: 10,
        group: ReleaseGroup.beta,
        duration: Duration(days: 7),
      );
    }

    // 阶段3：全量发布
    final betaMetrics = await _evaluateRulePerformance(rule);
    if (betaMetrics.successRate >= 0.85 && betaMetrics.userSatisfaction >= 0.8) {
      await _releaseToGroup(
        rule: rule,
        targetPercentage: 100,
        group: ReleaseGroup.production,
      );
    } else {
      // 回滚
      await _rollbackRule(rule);
    }
  }

  /// 评估规则性能
  Future<RuleMetrics> _evaluateRulePerformance(GlobalRule rule) async {
    final samples = await _db.getSamplesForRule(rule.id);

    return RuleMetrics(
      matchCount: samples.length,
      successRate: _calculateSuccessRate(samples),
      userSatisfaction: _calculateSatisfaction(samples),
      averageLatency: _calculateAverageLatency(samples),
    );
  }
}

/// A/B 测试服务
class ABTestService {

  /// 创建规则对比实验
  Future<ABTest> createRuleTest({
    required GlobalRule controlRule,
    required GlobalRule treatmentRule,
    required double trafficPercentage,
  }) async {
    return ABTest(
      id: _generateTestId(),
      controlRule: controlRule,
      treatmentRule: treatmentRule,
      trafficPercentage: trafficPercentage,
      startTime: DateTime.now(),
      status: ABTestStatus.running,
      metrics: ABTestMetrics.empty(),
    );
  }

  /// 分析实验结果
  Future<ABTestResult> analyzeTest(String testId) async {
    final test = await _db.getTest(testId);
    final controlSamples = await _getSamplesForVariant(testId, 'control');
    final treatmentSamples = await _getSamplesForVariant(testId, 'treatment');

    final controlMetrics = _calculateMetrics(controlSamples);
    final treatmentMetrics = _calculateMetrics(treatmentSamples);

    // 统计显著性检验
    final significance = _calculateStatisticalSignificance(
      controlMetrics, treatmentMetrics);

    return ABTestResult(
      testId: testId,
      controlMetrics: controlMetrics,
      treatmentMetrics: treatmentMetrics,
      winner: significance.pValue < 0.05
          ? (treatmentMetrics.successRate > controlMetrics.successRate
              ? 'treatment' : 'control')
          : 'inconclusive',
      significance: significance,
    );
  }
}
```

###### 15.12.1.1.7.6 协同学习效果预期

| 用户规模 | 优化效果 | 关键指标 |
|----------|----------|----------|
| **100-1K** | 初步群体效应 | 新用户冷启动时间 -50%，规则覆盖率 +10% |
| **1K-10K** | 显著群体智慧 | 全局规则库 +200条，准确率 +5%，LLM调用 -20% |
| **10K-100K** | 长尾表达覆盖 | 覆盖95%+常见表达，地域/方言适配 |
| **100K+** | 实时群体学习 | 新表达发现 <24h，规则自动迭代 |

**协同学习核心价值**：
- 🚀 新用户冷启动：从2周缩短到即时可用（继承群体规则）
- 📈 长尾表达覆盖：单用户难以学到的低频表达，群体可覆盖
- 💰 成本优化：群体规则命中率提升 → LLM调用进一步降低
- 🔄 实时迭代：新表达快速传播到全体用户

'''

def main():
    # 读取文档
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查是否已存在
    if '15.12.1.1.7 多用户协同学习系统' in content:
        print("Collaborative learning section already exists, skipping")
        return

    # 清理可能的残留代码
    content = content.replace('\nd }\n```\n\n#### 15.12.2', '\n\n#### 15.12.2')

    # 查找插入点：在 "#### 15.12.2 语音记账模块" 之前
    marker = '#### 15.12.2 语音记账模块'
    idx = content.find(marker)

    if idx == -1:
        print(f"Error: Cannot find marker '{marker}'")
        return

    # 插入新内容
    before = content[:idx].rstrip()
    after = content[idx:]

    new_content = before + '\n' + COLLABORATIVE_LEARNING_CONTENT.strip() + '\n\n' + after

    # 写入文件
    with open('d:/code/ai-bookkeeping/docs/design/app_v2_design.md', 'w', encoding='utf-8') as f:
        f.write(new_content)

    print('Successfully added collaborative learning section!')
    print(f'Old size: {len(content)} characters')
    print(f'New size: {len(new_content)} characters')
    print(f'Added: {len(new_content) - len(content)} characters')

if __name__ == '__main__':
    main()
