# -*- coding: utf-8 -*-
"""
添加第29章：低成本获客与自然增长设计
"""

GROWTH_CHAPTER = '''

---

## 29. 低成本获客与自然增长设计

### 29.0 设计原则回顾

本章设计遵循以下核心原则：

| 原则 | 应用方式 |
|------|----------|
| **懒人设计** | 用户无需额外操作即可成为传播节点 |
| **用户优先** | 增长手段不损害用户体验 |
| **可观测性** | 获客渠道可追踪、可归因、可优化 |

#### 29.0.1 获客成本(CAC)控制目标

```
+-------------------------------------------------------------------------+
|                      获客成本控制目标                                     |
+-------------------------------------------------------------------------+
|                                                                         |
|  战略目标: CAC <= 30元/用户                                              |
|                                                                         |
|  +---------------------------------------------------------------------+|
|  |                     获客渠道成本分布目标                          |   |
|  +---------------------------------------------------------------------+|
|  |                                                                 |   |
|  |  自然流量 (目标占比 40%, CAC = 0元)                              |   |
|  |  - 应用商店自然搜索                                             |   |
|  |  - SEO/内容营销带来的流量                                       |   |
|  |  - 用户自发分享                                                 |   |
|  |                                                                 |   |
|  |  口碑裂变 (目标占比 25%, CAC = 5元)                              |   |
|  |  - 邀请奖励机制                                                 |   |
|  |  - 成就分享带来的新用户                                         |   |
|  |  - 家庭/朋友推荐                                                |   |
|  |                                                                 |   |
|  |  内容获客 (目标占比 20%, CAC = 15元)                             |   |
|  |  - 产品内生成的可传播内容                                       |   |
|  |  - 用户UGC内容                                                  |   |
|  |  - KOL/KOC合作                                                  |   |
|  |                                                                 |   |
|  |  付费推广 (目标占比 15%, CAC = 80元)                             |   |
|  |  - 应用商店广告                                                 |   |
|  |  - 信息流广告                                                   |   |
|  |  - 精准投放                                                     |   |
|  |                                                                 |   |
|  +---------------------------------------------------------------------+|
|                                                                         |
|  综合CAC = 40%*0 + 25%*5 + 20%*15 + 15%*80 = 16.25元 < 30元            |
|                                                                         |
+-------------------------------------------------------------------------+
```

#### 29.0.2 与2.0其他系统的协同关系

```
+-------------------------------------------------------------------------+
|                   低成本获客系统与其他模块的协同                           |
+-------------------------------------------------------------------------+
|                                                                         |
|  +---------------+  +---------------+  +---------------+                |
|  |  钱龄分析系统  |  |  数据可视化   |  |  习惯培养系统  |                |
|  |  (第7章)      |  |  (第12章)     |  |  (第9章)      |                |
|  |              |  |              |  |              |                |
|  | 差异化卖点 -> |  | 可传播图表 -> |  | 成就徽章 ->   |                |
|  | 内容素材     |  | 分享素材     |  | 分享素材     |                |
|  +------+-------+  +------+-------+  +------+-------+                |
|         |                 |                 |                         |
|         +----------------++-----------------+                         |
|                          v                                             |
|                +---------------------+                                 |
|                | 低成本获客设计 (本章) |                                 |
|                |                     |                                 |
|                |  - 产品内置增长引擎  |                                 |
|                |  - ASO优化设计      |                                 |
|                |  - 内容生成系统     |                                 |
|                |  - 病毒系数优化     |                                 |
|                +----------+----------+                                 |
|                          |                                             |
|         +----------------+----------------+                           |
|         v                v                v                           |
|  +---------------+ +---------------+ +---------------+                |
|  |  NPS提升系统   | |  家庭账本系统  | |  国际化系统    |                |
|  |  (第28章)     | |  (第13章)     | |  (第21章)     |                |
|  |              | |              | |              |                |
|  | 推荐者培育 -> | | 家庭裂变 ->   | | 多市场覆盖 -> |                |
|  | 口碑获客     | | 自然增长     | | 扩大基数     |                |
|  +---------------+ +---------------+ +---------------+                |
|                                                                         |
+-------------------------------------------------------------------------+
```

### 29.1 产品内置增长引擎

#### 29.1.1 增长引擎架构

产品内置增长引擎是指将获客能力嵌入产品核心功能，让用户在正常使用过程中自然成为传播节点。

```dart
/// 产品内置增长引擎
class ProductGrowthEngine {
  /// 增长触发点
  static const growthTriggers = [
    // 成就解锁时
    GrowthTrigger(
      event: 'achievement_unlocked',
      action: '展示分享入口，一键生成成就卡片',
      expectedConversion: 0.15,  // 15%用户会分享
    ),

    // 钱龄里程碑时
    GrowthTrigger(
      event: 'money_age_milestone',
      action: '生成钱龄卡片，引导分享到社交平台',
      expectedConversion: 0.20,
    ),

    // 储蓄目标达成时
    GrowthTrigger(
      event: 'savings_goal_achieved',
      action: '生成目标达成庆祝卡片',
      expectedConversion: 0.25,
    ),

    // 月度/年度总结时
    GrowthTrigger(
      event: 'periodic_summary',
      action: '生成精美财务报告卡片',
      expectedConversion: 0.30,
    ),

    // 家庭账本邀请时
    GrowthTrigger(
      event: 'family_ledger_created',
      action: '引导邀请家人加入',
      expectedConversion: 0.80,  // 创建家庭账本的用户大概率会邀请
    ),
  ];

  /// 计算病毒系数(K-factor)
  /// K = 邀请发送率 * 平均邀请数 * 邀请转化率
  Future<double> calculateViralCoefficient() async {
    final inviteSendRate = await _getInviteSendRate();      // 发送邀请的用户比例
    final avgInvitesPerUser = await _getAvgInvitesPerUser(); // 平均每用户发送邀请数
    final inviteConversionRate = await _getInviteConversionRate(); // 邀请转化率

    return inviteSendRate * avgInvitesPerUser * inviteConversionRate;
    // 目标: K > 0.5 (每2个用户带来1个新用户)
  }
}
```

#### 29.1.2 分享素材自动生成

```dart
/// 分享素材生成服务
class ShareAssetGeneratorService {
  /// 可分享素材类型
  static const shareableAssets = [
    // 财务成就类
    ShareableAsset(
      type: AssetType.moneyAgeMilestone,
      template: 'money_age_card',
      headline: '我的钱龄达到了{days}天！',
      subheadline: '你的钱能活多久？',
      callToAction: '测测你的钱龄',
      platforms: [Platform.wechatMoments, Platform.weibo, Platform.xiaohongshu],
    ),
    ShareableAsset(
      type: AssetType.savingsAchievement,
      template: 'savings_card',
      headline: '成功存下了{amount}！',
      subheadline: '第{n}个储蓄目标达成',
      callToAction: '一起来存钱',
      platforms: [Platform.wechatMoments, Platform.weibo],
    ),

    // 数据洞察类
    ShareableAsset(
      type: AssetType.monthlyReport,
      template: 'monthly_report_card',
      headline: '{month}月财务小结',
      subheadline: '收入{income} 支出{expense} 结余{balance}',
      callToAction: '生成你的财务报告',
      platforms: [Platform.wechatMoments, Platform.xiaohongshu],
    ),
    ShareableAsset(
      type: AssetType.yearlyReport,
      template: 'yearly_report_card',
      headline: '{year}年度账单',
      subheadline: '这一年，我花了{total}',
      callToAction: '查看你的年度账单',
      platforms: [Platform.wechatMoments, Platform.weibo, Platform.xiaohongshu, Platform.douyin],
      seasonalBoost: true,  // 年终季节性热点
    ),

    // 趣味类（高传播性）
    ShareableAsset(
      type: AssetType.financialPersonality,
      template: 'personality_card',
      headline: '我的理财人格是：{personality}',
      subheadline: '{description}',
      callToAction: '测测你的理财人格',
      platforms: [Platform.wechatMoments, Platform.xiaohongshu, Platform.weibo],
      viralPotential: ViralPotential.high,
    ),
    ShareableAsset(
      type: AssetType.spendingComparison,
      template: 'comparison_card',
      headline: '我比{percent}%的同龄人更会省钱',
      subheadline: '钱龄{days}天，超过{percent}%的用户',
      callToAction: '你能超过多少人？',
      platforms: [Platform.wechatMoments, Platform.xiaohongshu],
      viralPotential: ViralPotential.high,
    ),
  ];

  /// 生成分享卡片
  Future<ShareCard> generateCard(ShareableAsset asset, Map<String, dynamic> data) async {
    // 1. 选择模板
    final template = await _loadTemplate(asset.template);

    // 2. 填充数据
    final filledTemplate = _fillTemplate(template, data);

    // 3. 添加品牌元素
    final brandedCard = _addBranding(filledTemplate);

    // 4. 添加追踪参数
    final trackableCard = _addTrackingParams(brandedCard, asset.type);

    // 5. 针对不同平台优化尺寸
    final platformCards = <Platform, ShareCard>{};
    for (final platform in asset.platforms) {
      platformCards[platform] = _optimizeForPlatform(trackableCard, platform);
    }

    return ShareCard(
      type: asset.type,
      cards: platformCards,
      shareText: _generateShareText(asset, data),
      deepLink: _generateDeepLink(asset.type),
    );
  }
}
```

#### 29.1.3 病毒环路设计

```
+-------------------------------------------------------------------------+
|                         病毒环路设计                                      |
+-------------------------------------------------------------------------+
|                                                                         |
|  核心病毒环路 (高频触发)                                                  |
|                                                                         |
|       +--------------+                                                  |
|       |   新用户注册  |                                                  |
|       +------+-------+                                                  |
|              v                                                          |
|       +--------------+                                                  |
|       |  完成首周体验 |<-----------------------------------+            |
|       +------+-------+                                  |            |
|              v                                          |            |
|       +--------------+                                  |            |
|       | 获得成就/里程碑|                                 |            |
|       +------+-------+                                  |            |
|              v                                          |            |
|       +--------------+     +--------------+            |            |
|       |  生成分享卡片 |---->|  分享到社交平台 |            |            |
|       +--------------+     +------+-------+            |            |
|                                   v                    |            |
|                            +--------------+            |            |
|                            |  好友看到卡片 |            |            |
|                            +------+-------+            |            |
|                                   v                    |            |
|                            +--------------+            |            |
|                            |  点击了解产品 |            |            |
|                            +------+-------+            |            |
|                                   v                    |            |
|                            +--------------+            |            |
|                            |   下载安装    |------------+            |
|                            +--------------+                          |
|                                                                         |
|  病毒系数目标: K = 0.6 (每10个用户带来6个新用户)                          |
|                                                                         |
+-------------------------------------------------------------------------+
```

### 29.2 应用商店优化(ASO)设计

#### 29.2.1 ASO关键词策略

```dart
/// ASO优化服务
class AsoOptimizationService {
  /// 核心关键词矩阵
  static const keywordMatrix = KeywordMatrix(
    // 品类词（高搜索量，高竞争）
    categoryKeywords: [
      Keyword(word: '记账', priority: Priority.high, difficulty: Difficulty.high),
      Keyword(word: '记账软件', priority: Priority.high, difficulty: Difficulty.high),
      Keyword(word: '记账APP', priority: Priority.high, difficulty: Difficulty.high),
      Keyword(word: '理财', priority: Priority.medium, difficulty: Difficulty.high),
    ],

    // 功能词（中等搜索量，中等竞争）
    featureKeywords: [
      Keyword(word: '语音记账', priority: Priority.high, difficulty: Difficulty.medium),
      Keyword(word: '拍照记账', priority: Priority.high, difficulty: Difficulty.medium),
      Keyword(word: '预算管理', priority: Priority.high, difficulty: Difficulty.medium),
      Keyword(word: '智能记账', priority: Priority.high, difficulty: Difficulty.medium),
      Keyword(word: 'AI记账', priority: Priority.high, difficulty: Difficulty.low),
    ],

    // 差异化词（低搜索量，低竞争，高转化）
    differentiatorKeywords: [
      Keyword(word: '钱龄', priority: Priority.critical, difficulty: Difficulty.low),
      Keyword(word: '零基预算', priority: Priority.high, difficulty: Difficulty.low),
      Keyword(word: '信封预算', priority: Priority.medium, difficulty: Difficulty.low),
      Keyword(word: '小金库', priority: Priority.high, difficulty: Difficulty.low),
    ],

    // 场景词（精准用户，高转化）
    scenarioKeywords: [
      Keyword(word: '月光族', priority: Priority.high, difficulty: Difficulty.low),
      Keyword(word: '存钱', priority: Priority.high, difficulty: Difficulty.medium),
      Keyword(word: '省钱', priority: Priority.medium, difficulty: Difficulty.medium),
      Keyword(word: '家庭记账', priority: Priority.medium, difficulty: Difficulty.medium),
      Keyword(word: '情侣记账', priority: Priority.medium, difficulty: Difficulty.low),
    ],

    // 竞品词（截流）
    competitorKeywords: [
      Keyword(word: '随手记替代', priority: Priority.medium, difficulty: Difficulty.medium),
      Keyword(word: 'YNAB中文', priority: Priority.high, difficulty: Difficulty.low),
    ],
  );

  /// 生成应用标题变体（用于A/B测试）
  static const titleVariants = [
    'AI智能记账 - 钱龄分析，让每分钱更有价值',
    'AI智能记账 - 语音记账，3秒搞定',
    'AI智能记账 - 零基预算，告别月光',
    'AI智能记账 - 你的智能理财伙伴',
  ];
}
```

#### 29.2.2 应用商店评分优化

```dart
/// 应用评分优化服务
class AppRatingOptimizationService {
  /// 评分请求策略
  static const ratingRequestStrategy = RatingStrategy(
    // 触发时机（用户处于积极情绪时）
    triggers: [
      RatingTrigger(
        event: 'achievement_unlocked',
        condition: 'first_meaningful_achievement',
        delay: Duration(seconds: 3),
        description: '首次解锁有意义的成就后',
      ),
      RatingTrigger(
        event: 'savings_goal_progress',
        condition: 'progress >= 50%',
        delay: Duration(seconds: 2),
        description: '储蓄目标完成过半时',
      ),
      RatingTrigger(
        event: 'positive_money_age_change',
        condition: 'increase >= 3 days',
        delay: Duration(seconds: 3),
        description: '钱龄提升3天以上时',
      ),
    ],

    // 请求限制
    constraints: RatingConstraints(
      minDaysAfterInstall: 3,           // 安装3天后才请求
      minSessionsBeforeRequest: 5,       // 至少使用5次
      minDaysBetweenRequests: 90,        // 两次请求间隔90天
      maxRequestsPerUser: 3,             // 每用户最多请求3次
    ),

    // 低分用户引导
    lowRatingIntervention: LowRatingIntervention(
      threshold: 3,  // 3星及以下
      action: '展示反馈入口，引导用户先告诉我们问题',
      message: '很抱歉没能让您满意，能告诉我们哪里需要改进吗？',
    ),
  );
}
```

### 29.3 内容驱动增长设计

#### 29.3.1 产品内容生成系统

产品自动生成可传播的内容，降低用户创作门槛。

```dart
/// 内容生成引擎
class ContentGenerationEngine {
  /// 自动生成的内容类型
  static const contentTypes = [
    // 个人财务故事
    ContentType(
      id: 'financial_story',
      name: '我的理财故事',
      description: '基于用户数据自动生成的财务成长故事',
      frequency: ContentFrequency.monthly,
      shareability: Shareability.high,
    ),

    // 理财人格测试
    ContentType(
      id: 'financial_personality',
      name: '理财人格测试',
      description: '基于消费模式分析的人格测试',
      frequency: ContentFrequency.onDemand,
      shareability: Shareability.veryHigh,
    ),

    // 年度盘点
    ContentType(
      id: 'yearly_recap',
      name: '年度财务盘点',
      description: '年度消费、储蓄、钱龄全面盘点',
      frequency: ContentFrequency.yearly,
      shareability: Shareability.veryHigh,
      seasonalBoost: true,
    ),
  ];

  /// 生成理财人格测试结果
  Future<PersonalityResult> generateFinancialPersonality(String userId) async {
    final transactions = await _getTransactions(userId, days: 90);
    final stats = _analyzeSpendingPattern(transactions);

    // 根据消费模式确定理财人格
    final personality = _determinePersonality(stats);

    return PersonalityResult(
      type: personality.type,
      title: personality.title,  // 如: "理性规划师"、"随性探索者"
      description: personality.description,
      strengths: personality.strengths,
      improvements: personality.improvements,
      rarity: await _calculateRarity(personality.type),  // "仅有12%的用户是这个类型"
      shareCard: await _generatePersonalityCard(personality),
    );
  }

  /// 生成年度盘点趣味事实
  List<FunFact> generateFunFacts(YearData data) {
    return [
      FunFact(
        text: '你今年喝了${data.coffeeCount}杯咖啡',
      ),
      FunFact(
        text: '你点了${data.takeoutCount}次外卖',
      ),
      FunFact(
        text: '你最能省钱的月份是${data.mostFrugalMonth}月',
      ),
    ];
  }
}
```

#### 29.3.2 用户UGC引导设计

```dart
/// UGC引导服务
class UgcGuidanceService {
  /// UGC引导场景
  static const ugcScenarios = [
    // 成功故事分享
    UgcScenario(
      trigger: 'significant_savings_milestone',
      prompt: '恭喜你存下了{amount}！愿意分享你的省钱心得吗？',
      template: UgcTemplate(
        title: '我是如何{days}天存下{amount}的',
        sections: ['起因', '方法', '收获'],
        hashtags: ['理财打卡', '省钱日记', 'AI记账'],
      ),
      incentive: '分享后可解锁专属徽章',
    ),

    // 钱龄进阶分享
    UgcScenario(
      trigger: 'money_age_level_up',
      prompt: '钱龄升级到{level}了！分享你的钱龄故事吧',
      template: UgcTemplate(
        title: '我的钱龄从{before}天到{after}天的历程',
        sections: ['改变前', '我做了什么', '现在的变化'],
        hashtags: ['钱龄挑战', '财务自由', 'AI记账'],
      ),
      incentive: '精选故事将获得官方推荐',
    ),

    // 习惯养成分享
    UgcScenario(
      trigger: 'habit_formed',
      prompt: '连续记账{days}天了！你的坚持值得被看见',
      template: UgcTemplate(
        title: '我是如何坚持记账{days}天的',
        sections: ['为什么开始', '如何坚持', '给新人的建议'],
        hashtags: ['记账打卡', '习惯养成', 'AI记账'],
      ),
      incentive: '获得"习惯导师"称号',
    ),
  ];
}
```

### 29.4 社交裂变机制设计

#### 29.4.1 家庭账本裂变

家庭账本是天然的裂变场景，创建者必然会邀请家人加入。

```dart
/// 家庭账本裂变服务
class FamilyLedgerViralService {
  /// 裂变路径设计
  static const viralPath = FamilyViralPath(
    // 创建时引导
    onCreation: ViralStep(
      message: '家庭账本创建成功！邀请家人一起记账吧',
      actions: [
        ViralAction(
          type: ActionType.inviteSpouse,
          label: '邀请另一半',
          expectedConversion: 0.70,
        ),
        ViralAction(
          type: ActionType.inviteParents,
          label: '邀请父母',
          expectedConversion: 0.30,
        ),
        ViralAction(
          type: ActionType.inviteChildren,
          label: '邀请孩子',
          expectedConversion: 0.20,
        ),
      ],
    ),

    // 使用中持续引导
    duringUsage: [
      ViralStep(
        trigger: 'first_shared_expense',
        message: '记录了第一笔家庭支出！邀请家人一起查看？',
      ),
      ViralStep(
        trigger: 'budget_set',
        message: '家庭预算设置好了，让其他成员也参与预算管理吧',
      ),
      ViralStep(
        trigger: 'monthly_summary',
        message: '本月家庭财务报告已生成，分享给家人看看？',
      ),
    ],

    // 被邀请者激活路径
    inviteeActivation: InviteeActivation(
      welcomeMessage: '{inviterName}邀请你加入"{ledgerName}"家庭账本',
      quickActions: ['记一笔', '查看预算', '查看报表'],
      incentive: '新成员记录第一笔账可获得家庭徽章',
    ),
  );
}
```

#### 29.4.2 情侣/AA记账裂变

```dart
/// 情侣/AA记账裂变服务
class CoupleAccountingViralService {
  /// AA记账自然裂变
  static const aaViralDesign = AAViralDesign(
    // AA分账时自然引导
    onSplitBill: ViralStep(
      message: '这笔账需要{partnerName}也记录吗？',
      actions: [
        ViralAction(
          type: ActionType.sendReminder,
          label: '发送提醒',
          expectedConversion: 0.60,
        ),
        ViralAction(
          type: ActionType.inviteToApp,
          label: '邀请TA也用AI记账',
          expectedConversion: 0.30,
        ),
      ],
    ),

    // 发送AA提醒时附带邀请
    aaReminderWithInvite: ReminderTemplate(
      title: '{senderName}请你AA{amount}元',
      body: '{senderName}通过AI智能记账发起了AA请求',
      callToAction: '下载APP，一键确认',
      deepLink: 'aibook://aa/{billId}',
    ),
  );
}
```

#### 29.4.3 社交对比（隐私优先设计）

```dart
/// 社交排行榜服务
class SocialLeaderboardService {
  /// 排行榜类型（隐私优先设计）
  static const leaderboardTypes = [
    // 匿名同龄人对比
    LeaderboardType(
      id: 'peer_comparison',
      name: '同龄人对比',
      description: '与同龄、同城用户匿名对比',
      privacy: PrivacyLevel.anonymous,
      metrics: ['钱龄', '储蓄率', '记账坚持度'],
    ),

    // 好友排行（需明确授权）
    LeaderboardType(
      id: 'friends_ranking',
      name: '好友排行',
      description: '与好友对比财务健康度',
      privacy: PrivacyLevel.optIn,
      metrics: ['钱龄等级', '记账天数', '目标完成数'],
    ),

    // 家庭内部排行
    LeaderboardType(
      id: 'family_ranking',
      name: '家庭成员排行',
      description: '家庭成员间的良性竞争',
      privacy: PrivacyLevel.familyOnly,
      metrics: ['本月节省', '预算达成率', '记账积极性'],
    ),
  ];

  /// 生成对比结果（用于分享）
  Future<ComparisonResult> generateComparison(String userId) async {
    final userStats = await _getUserStats(userId);
    final peerStats = await _getPeerAverageStats(userId);

    return ComparisonResult(
      highlights: [
        ComparisonItem(
          metric: '钱龄',
          userValue: '${userStats.moneyAge}天',
          peerAverage: '${peerStats.avgMoneyAge}天',
          percentile: _calculatePercentile(userStats.moneyAge, peerStats.moneyAgeDistribution),
          message: '你的钱龄超过了${percentile}%的同龄人',
        ),
      ],
      shareCard: await _generateComparisonCard(userStats, peerStats),
    );
  }
}
```

### 29.5 落地页与转化优化

#### 29.5.1 落地页设计

```dart
/// 落地页服务
class LandingPageService {
  /// 落地页变体（用于A/B测试）
  static const landingPageVariants = [
    // 变体A：钱龄概念主打
    LandingPageVariant(
      id: 'money_age_focus',
      headline: '你的钱能"活"多久？',
      subheadline: '钱龄分析，让每分钱更有价值',
      features: ['钱龄分析', '智能记账', '零基预算'],
      cta: '测测我的钱龄',
      targetAudience: 'ynab_seekers',
    ),

    // 变体B：便捷性主打
    LandingPageVariant(
      id: 'convenience_focus',
      headline: '3秒记账，告别月光',
      subheadline: '语音、拍照，怎么方便怎么来',
      features: ['语音记账', '拍照记账', '智能分类'],
      cta: '立即下载',
      targetAudience: 'convenience_seekers',
    ),

    // 变体C：家庭场景主打
    LandingPageVariant(
      id: 'family_focus',
      headline: '全家一起管钱，更透明更高效',
      subheadline: '家庭账本，共同理财',
      features: ['家庭账本', '成员管理', 'AA分账'],
      cta: '创建家庭账本',
      targetAudience: 'family_users',
    ),
  ];

  /// 根据来源渠道选择最佳落地页
  LandingPageVariant selectVariant(TrafficSource source) {
    switch (source.channel) {
      case 'ynab_content':
      case 'budget_keywords':
        return landingPageVariants.firstWhere((v) => v.id == 'money_age_focus');
      case 'family_content':
      case 'couple_content':
        return landingPageVariants.firstWhere((v) => v.id == 'family_focus');
      default:
        return landingPageVariants.firstWhere((v) => v.id == 'convenience_focus');
    }
  }
}
```

#### 29.5.2 深度链接与归因

```dart
/// 深度链接与归因服务
class DeepLinkAttributionService {
  /// 深度链接生成
  Future<DeepLink> generateDeepLink(DeepLinkParams params) async {
    return DeepLink(
      url: 'https://aibook.app/go/${params.shortCode}',
      fallbackUrl: _getAppStoreUrl(params.platform),
      parameters: {
        'source': params.source,
        'campaign': params.campaign,
        'content': params.content,
        'referrer': params.referrerId,
      },
    );
  }

  /// 归因追踪
  Future<void> trackAttribution(String userId, InstallContext context) async {
    final attribution = Attribution(
      userId: userId,
      source: context.source,
      campaign: context.campaign,
      referrer: context.referrerId,
      installTime: DateTime.now(),
    );

    await _saveAttribution(attribution);

    // 如果有推荐人，触发推荐奖励
    if (context.referrerId != null) {
      await _processReferral(context.referrerId!, userId);
    }
  }

  /// 获取渠道CAC
  Future<Map<String, double>> calculateChannelCAC(DateRange period) async {
    final costs = await _getChannelCosts(period);
    final installs = await _getChannelInstalls(period);

    return Map.fromEntries(
      costs.keys.map((channel) => MapEntry(
        channel,
        costs[channel]! / (installs[channel] ?? 1),
      )),
    );
  }
}
```

### 29.6 目标达成检测

```dart
/// 获客成本目标检测服务
class CacGoalDetector {
  /// CAC相关目标
  static const cacGoals = CacGoalCriteria(
    // 总体CAC目标
    overallCac: CacTarget(
      target: 30.0,  // <=30元/用户
      measurement: '总获客成本/总新增用户',
    ),

    // 自然流量占比
    organicRate: RateTarget(
      target: 0.40,  // 40%来自自然流量
      measurement: '自然流量新增/总新增',
    ),

    // 口碑裂变占比
    referralRate: RateTarget(
      target: 0.25,  // 25%来自口碑裂变
      measurement: '推荐新增/总新增',
    ),

    // 病毒系数
    viralCoefficient: ViralTarget(
      target: 0.5,  // K>=0.5
      measurement: '邀请发送率*平均邀请数*转化率',
    ),

    // 分享率
    shareRate: RateTarget(
      target: 0.20,  // 20%用户有分享行为
      measurement: '有分享行为的活跃用户/总活跃用户',
    ),

    // 应用商店评分
    appRating: RatingTarget(
      target: 4.5,  // >=4.5星
      measurement: '应用商店平均评分',
    ),
  );

  /// 检测目标达成状态
  Future<CacGoalStatus> checkGoalStatus(DateRange period) async {
    final status = CacGoalStatus();

    // 计算当前CAC
    final totalCost = await _getTotalAcquisitionCost(period);
    final totalInstalls = await _getTotalInstalls(period);
    final currentCac = totalCost / totalInstalls;
    status.overallCac = GoalCheckResult(
      current: currentCac,
      target: cacGoals.overallCac.target,
      achieved: currentCac <= cacGoals.overallCac.target,
    );

    // 计算自然流量占比
    final organicInstalls = await _getOrganicInstalls(period);
    final organicRate = organicInstalls / totalInstalls;
    status.organicRate = GoalCheckResult(
      current: organicRate,
      target: cacGoals.organicRate.target,
      achieved: organicRate >= cacGoals.organicRate.target,
    );

    // 计算病毒系数
    final viralCoefficient = await _calculateViralCoefficient(period);
    status.viralCoefficient = GoalCheckResult(
      current: viralCoefficient,
      target: cacGoals.viralCoefficient.target,
      achieved: viralCoefficient >= cacGoals.viralCoefficient.target,
    );

    return status;
  }

  /// 生成CAC优化建议
  Future<List<CacOptimization>> generateOptimizationSuggestions(CacGoalStatus status) async {
    final suggestions = <CacOptimization>[];

    if (!status.overallCac.achieved) {
      if (!status.organicRate.achieved) {
        suggestions.add(CacOptimization(
          area: '自然流量',
          priority: Priority.high,
          suggestions: [
            '优化应用商店关键词，提升ASO排名',
            '增加钱龄等差异化关键词的覆盖',
            '提升应用商店评分和评论数量',
          ],
          expectedImpact: '提升10%自然流量可降低CAC约4元',
        ));
      }

      if (!status.viralCoefficient.achieved) {
        suggestions.add(CacOptimization(
          area: '病毒传播',
          priority: Priority.high,
          suggestions: [
            '优化分享卡片设计，提升分享意愿',
            '增加可分享内容类型（年度报告、理财人格）',
            '优化邀请奖励机制，提升转化率',
          ],
          expectedImpact: 'K值每提升0.1可降低CAC约5元',
        ));
      }
    }

    return suggestions;
  }
}
```

'''

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 在文档末尾添加新章节
    content = content.rstrip() + GROWTH_CHAPTER

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("已添加第29章：低成本获客与自然增长设计")

if __name__ == '__main__':
    main()
