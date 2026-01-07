# -*- coding: utf-8 -*-
"""
添加第28章：用户口碑与NPS提升设计
"""

NPS_CHAPTER = '''

---

## 28. 用户口碑与NPS提升设计

### 28.0 设计原则回顾

本章设计遵循以下核心原则：

| 原则 | 应用方式 |
|------|----------|
| **懒人设计** | 口碑分享一键完成，无需复杂操作 |
| **伙伴化设计** | 通过情感连接培养推荐者 |
| **用户优先** | 以用户真实价值为口碑基础，而非营销手段 |

#### 28.0.1 NPS与产品成功的关系

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      NPS驱动增长飞轮                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                           ┌──────────────┐                              │
│                      ┌───►│  推荐者增加   │───┐                         │
│                      │    │  (NPS提升)   │   │                         │
│                      │    └──────────────┘   │                         │
│                      │                       ▼                         │
│               ┌──────────────┐        ┌──────────────┐                 │
│               │  产品体验优化 │        │  口碑传播    │                 │
│               │  (价值交付)   │        │  (自然获客)  │                 │
│               └──────────────┘        └──────────────┘                 │
│                      ▲                       │                         │
│                      │    ┌──────────────┐   │                         │
│                      └────│  用户反馈    │◄──┘                         │
│                           │  (持续改进)  │                              │
│                           └──────────────┘                              │
│                                                                         │
│  【核心理念】NPS不是营销指标，而是产品价值的真实反映                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 28.0.2 与2.0其他系统的协同关系

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     NPS提升系统与其他模块的协同                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐               │
│  │  伙伴化设计    │  │  习惯培养系统  │  │  钱龄分析系统  │               │
│  │  (第4章)      │  │  (第9章)      │  │  (第7章)      │               │
│  │              │  │              │  │              │               │
│  │ 情感连接→    │  │ 成就系统→    │  │ 差异化价值→  │               │
│  │ 推荐者培育   │  │ 分享素材     │  │ 口碑传播点   │               │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘               │
│         │                 │                 │                         │
│         └────────────────┬┴─────────────────┘                         │
│                          ▼                                             │
│                ┌─────────────────────┐                                 │
│                │  NPS提升设计 (本章)  │                                 │
│                │                     │                                 │
│                │  • 惊喜时刻系统     │                                 │
│                │  • 口碑分享机制     │                                 │
│                │  • 负面体验修复     │                                 │
│                │  • 推荐者培育       │                                 │
│                └──────────┬──────────┘                                 │
│                          │                                             │
│         ┌────────────────┼────────────────┐                           │
│         ▼                ▼                ▼                           │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐                │
│  │  数据可视化    │ │  国际化系统    │ │  用户体验设计  │                │
│  │  (第12章)     │ │  (第21章)     │ │  (第20章)     │                │
│  │              │ │              │ │              │                │
│  │ 分享卡片设计  │ │ 多语言分享    │ │ 首周体验优化  │                │
│  └───────────────┘ └───────────────┘ └───────────────┘                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 28.1 NPS目标与监测机制

#### 28.1.1 NPS目标设定

| 阶段 | 时间节点 | NPS目标 | 说明 |
|------|----------|---------|------|
| **MVP验证期** | 上线后3个月 | ≥30 | 验证核心价值被认可 |
| **增长期** | 上线后6个月 | ≥40 | 口碑开始传播 |
| **成熟期** | 上线后12个月 | ≥50 | 形成口碑飞轮 |
| **领先期** | 上线后24个月 | ≥60 | 行业领先水平 |

#### 28.1.2 NPS监测体系

```dart
/// NPS监测服务
class NpsMonitoringService {
  /// NPS调查触发时机
  static const surveyTriggers = [
    NpsSurveyTrigger(
      event: 'first_week_completed',
      delay: Duration(days: 7),
      description: '使用满一周后首次收集',
    ),
    NpsSurveyTrigger(
      event: 'monthly_active_user',
      interval: Duration(days: 90),
      description: '活跃用户每90天调查一次',
    ),
    NpsSurveyTrigger(
      event: 'milestone_achieved',
      milestones: ['money_age_30_days', 'savings_goal_completed', 'streak_30_days'],
      description: '达成重要里程碑后调查',
    ),
    NpsSurveyTrigger(
      event: 'feature_intensive_use',
      threshold: 50,  // 使用某功能50次以上
      description: '深度使用某功能后调查该功能NPS',
    ),
  ];

  /// NPS问卷设计
  Future<NpsSurveyResult> conductSurvey(String userId) async {
    // 核心问题
    final score = await _askNpsQuestion(
      question: '您有多大可能向朋友或同事推荐AI智能记账？',
      scale: 10,  // 0-10分
    );

    // 追问原因（根据分数分类）
    String? reason;
    if (score >= 9) {
      // 推荐者：了解推荐动力
      reason = await _askOpenQuestion(
        question: '太棒了！是什么让您愿意推荐我们？',
        suggestions: ['钱龄分析很有用', '记账很方便', '预算管理帮助很大', '界面很好看'],
      );
    } else if (score >= 7) {
      // 被动者：了解提升空间
      reason = await _askOpenQuestion(
        question: '感谢您的支持！我们还能做些什么让您更满意？',
      );
    } else {
      // 贬损者：了解问题所在
      reason = await _askOpenQuestion(
        question: '很抱歉没能让您满意，能告诉我们哪里需要改进吗？',
      );
    }

    return NpsSurveyResult(
      userId: userId,
      score: score,
      reason: reason,
      timestamp: DateTime.now(),
      context: await _captureContext(),  // 记录调查时的上下文
    );
  }

  /// NPS计算
  double calculateNps(List<NpsSurveyResult> results) {
    if (results.isEmpty) return 0;

    int promoters = 0;   // 9-10分
    int detractors = 0;  // 0-6分

    for (final result in results) {
      if (result.score >= 9) {
        promoters++;
      } else if (result.score <= 6) {
        detractors++;
      }
    }

    final promoterRate = promoters / results.length * 100;
    final detractorRate = detractors / results.length * 100;

    return promoterRate - detractorRate;
  }
}
```

#### 28.1.3 NPS分解分析

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      NPS驱动因素分解                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  总体NPS = f(功能价值, 体验质量, 情感连接, 信任度)                        │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  功能价值 (40%)                                                  │   │
│  │  ├─ 钱龄分析有用性                                              │   │
│  │  ├─ 预算管理效果                                                │   │
│  │  ├─ AI识别准确性                                                │   │
│  │  └─ 习惯培养成效                                                │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  体验质量 (30%)                                                  │   │
│  │  ├─ 记账便捷性                                                  │   │
│  │  ├─ 界面美观度                                                  │   │
│  │  ├─ 操作流畅性                                                  │   │
│  │  └─ 学习成本低                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  情感连接 (20%)                                                  │   │
│  │  ├─ 伙伴感受                                                    │   │
│  │  ├─ 成就感获得                                                  │   │
│  │  ├─ 惊喜体验                                                    │   │
│  │  └─ 被理解感                                                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  信任度 (10%)                                                    │   │
│  │  ├─ 数据安全感                                                  │   │
│  │  ├─ 隐私保护                                                    │   │
│  │  ├─ 算法透明                                                    │   │
│  │  └─ 稳定可靠                                                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 28.2 惊喜时刻系统设计

#### 28.2.1 惊喜时刻定义

惊喜时刻(Delight Moments)是指超出用户预期、带来愉悦感的产品体验点。这些时刻是培养推荐者的关键触发器。

```dart
/// 惊喜时刻服务
class DelightMomentService {
  final NotificationService _notificationService;
  final AnimationService _animationService;
  final AchievementService _achievementService;

  /// 里程碑惊喜配置
  static const milestoneDelights = [
    // 首次体验惊喜
    MilestoneDelight(
      trigger: 'first_transaction_saved',
      title: '记账之旅开始了！',
      message: '恭喜完成第一笔记账，你的财务管理新篇章开启啦',
      animation: 'confetti_celebration',
      reward: AchievementBadge('first_step'),
    ),

    // 钱龄突破惊喜
    MilestoneDelight(
      trigger: 'money_age_reached_7_days',
      title: '钱龄突破7天！',
      message: '你的钱现在可以"活"一周了，比大多数月光族强多了',
      animation: 'level_up',
      reward: AchievementBadge('money_age_7'),
      shareCard: true,  // 可生成分享卡片
    ),
    MilestoneDelight(
      trigger: 'money_age_reached_30_days',
      title: '进入安全区！',
      message: '钱龄30天，你已经拥有一个月的财务缓冲了',
      animation: 'grand_celebration',
      reward: AchievementBadge('money_age_30'),
      shareCard: true,
    ),

    // 连续记账惊喜
    MilestoneDelight(
      trigger: 'streak_7_days',
      title: '连续记账一周！',
      message: '坚持就是胜利，你已经养成了初步的记账习惯',
      animation: 'streak_fire',
      reward: AchievementBadge('streak_7'),
    ),
    MilestoneDelight(
      trigger: 'streak_30_days',
      title: '记账达人诞生！',
      message: '连续30天，记账已经成为你的日常习惯了',
      animation: 'master_unlock',
      reward: AchievementBadge('streak_master'),
      shareCard: true,
    ),

    // 储蓄目标惊喜
    MilestoneDelight(
      trigger: 'savings_goal_50_percent',
      title: '目标过半！',
      message: '储蓄目标已完成50%，继续保持这个节奏',
      animation: 'progress_boost',
    ),
    MilestoneDelight(
      trigger: 'savings_goal_completed',
      title: '目标达成！',
      message: '恭喜你完成了储蓄目标！你证明了自己可以做到',
      animation: 'goal_achieved',
      reward: AchievementBadge('goal_achiever'),
      shareCard: true,
    ),

    // 节省金额惊喜
    MilestoneDelight(
      trigger: 'total_saved_1000',
      title: '省下1000元！',
      message: '通过预算管理，你已经累计节省了1000元',
      animation: 'money_rain',
      storyGeneration: true,  // 生成省钱故事
    ),
    MilestoneDelight(
      trigger: 'total_saved_10000',
      title: '万元俱乐部！',
      message: '累计节省10000元！你的财务管理能力令人敬佩',
      animation: 'fireworks',
      reward: AchievementBadge('savings_master'),
      shareCard: true,
    ),
  ];

  /// 触发惊喜时刻
  Future<void> triggerDelight(MilestoneDelight delight) async {
    // 1. 播放动画
    await _animationService.play(delight.animation);

    // 2. 显示祝贺消息
    await _showDelightCard(delight);

    // 3. 发放奖励
    if (delight.reward != null) {
      await _achievementService.award(delight.reward!);
    }

    // 4. 生成分享内容
    if (delight.shareCard) {
      await _prepareShareCard(delight);
    }

    // 5. 记录惊喜时刻
    await _logDelightMoment(delight);
  }
}
```

#### 28.2.2 智能惊喜发现

```dart
/// 智能惊喜发现服务
class SmartDelightDiscoveryService {
  /// 发现用户独特的消费规律并给予惊喜反馈
  Future<List<SmartDelight>> discoverDelights(String userId) async {
    final delights = <SmartDelight>[];
    final transactions = await _getRecentTransactions(userId, days: 90);

    // 发现周期性消费规律
    final patterns = _analyzeConsumptionPatterns(transactions);
    for (final pattern in patterns) {
      if (pattern.confidence > 0.8) {
        delights.add(SmartDelight(
          type: DelightType.patternDiscovery,
          title: '我发现了一个小秘密',
          message: _generatePatternMessage(pattern),
          // 例如: "你好像每周五都会犒劳自己一杯咖啡☕"
        ));
      }
    }

    // 发现积极变化
    final improvements = _detectImprovements(transactions);
    for (final improvement in improvements) {
      delights.add(SmartDelight(
        type: DelightType.improvementNotice,
        title: '悄悄告诉你一个好消息',
        message: _generateImprovementMessage(improvement),
        // 例如: "这个月外卖支出比上个月减少了20%！"
      ));
    }

    return delights;
  }

  /// 预测即将达成的成就并提前激励
  Future<void> predictAndEncourage(String userId) async {
    // 检测即将达成的目标
    final nearMilestones = await _detectNearMilestones(userId);

    for (final milestone in nearMilestones) {
      if (milestone.progressPercent >= 90) {
        await _sendEncouragement(
          userId: userId,
          title: '就差一点点了！',
          message: '${milestone.name}即将达成，再坚持${milestone.remaining}就成功了',
        );
      }
    }
  }

  /// 生成消费规律消息
  String _generatePatternMessage(ConsumptionPattern pattern) {
    switch (pattern.type) {
      case PatternType.weeklyRecurring:
        return '你好像每${pattern.dayOfWeek}都会${pattern.description}';
      case PatternType.monthlyRecurring:
        return '每个月${pattern.dayOfMonth}号，你都会${pattern.description}';
      case PatternType.locationBased:
        return '每次去${pattern.location}，你都喜欢${pattern.description}';
      default:
        return '我发现了你的一个消费小习惯';
    }
  }
}
```

#### 28.2.3 惊喜时刻的时机与频率控制

```dart
/// 惊喜时刻频率控制器
class DelightFrequencyController {
  /// 频率控制规则
  static const frequencyRules = FrequencyRules(
    // 同一类型惊喜的最小间隔
    minIntervalBetweenSameType: Duration(days: 7),

    // 每日惊喜上限
    maxDelightsPerDay: 2,

    // 每周惊喜上限
    maxDelightsPerWeek: 5,

    // 惊喜疲劳恢复期
    fatigueRecoveryPeriod: Duration(days: 3),

    // 用户偏好自适应
    adaptToUserPreference: true,
  );

  /// 判断是否应该触发惊喜
  Future<bool> shouldTrigger(String userId, MilestoneDelight delight) async {
    // 检查每日上限
    final todayCount = await _getTodayDelightCount(userId);
    if (todayCount >= frequencyRules.maxDelightsPerDay) {
      return false;
    }

    // 检查同类型间隔
    final lastSameType = await _getLastDelightOfType(userId, delight.type);
    if (lastSameType != null) {
      final interval = DateTime.now().difference(lastSameType.timestamp);
      if (interval < frequencyRules.minIntervalBetweenSameType) {
        return false;
      }
    }

    // 检查用户偏好
    if (frequencyRules.adaptToUserPreference) {
      final preference = await _getUserDelightPreference(userId);
      if (preference.delightFrequency == DelightFrequency.minimal) {
        // 只触发重要里程碑
        return delight.importance >= DelightImportance.high;
      }
    }

    return true;
  }
}
```

### 28.3 社交分享与口碑传播机制

#### 28.3.1 可分享内容设计

```dart
/// 分享内容服务
class ShareableContentService {
  /// 生成成就分享卡片
  Future<ShareCard> generateAchievementCard(Achievement achievement) async {
    final user = await _getCurrentUser();
    final stats = await _getUserStats();

    return ShareCard(
      type: ShareCardType.achievement,
      title: achievement.title,
      subtitle: achievement.description,
      visual: AchievementVisual(
        badge: achievement.badge,
        backgroundColor: achievement.themeColor,
        animation: achievement.celebrationAnimation,
      ),
      stats: [
        StatItem(label: '钱龄', value: '${stats.moneyAge}天'),
        StatItem(label: '记账天数', value: '${stats.recordingDays}天'),
        StatItem(label: '累计节省', value: '¥${stats.totalSaved}'),
      ],
      callToAction: ShareCTA(
        text: '和我一起管理财务吧',
        link: 'https://aibook.app/invite/${user.referralCode}',
      ),
      branding: AppBranding(
        logo: 'assets/logo_small.png',
        slogan: 'AI智能记账 - 你的智能理财伙伴',
      ),
    );
  }

  /// 生成年度/月度账单报告
  Future<ShareCard> generateFinancialReport(ReportPeriod period) async {
    final report = await _generateReport(period);

    return ShareCard(
      type: ShareCardType.financialReport,
      title: '${period.year}年${period.month}月财务小结',
      sections: [
        ReportSection(
          title: '收支概览',
          items: [
            ReportItem(icon: '💰', label: '总收入', value: '¥${report.totalIncome}'),
            ReportItem(icon: '💸', label: '总支出', value: '¥${report.totalExpense}'),
            ReportItem(icon: '🎯', label: '结余', value: '¥${report.balance}'),
          ],
        ),
        ReportSection(
          title: '钱龄变化',
          visualization: MoneyAgeTrendChart(data: report.moneyAgeTrend),
          highlight: '钱龄从${report.startMoneyAge}天提升到${report.endMoneyAge}天',
        ),
        ReportSection(
          title: '消费TOP3',
          items: report.topCategories.map((c) =>
            ReportItem(icon: c.icon, label: c.name, value: '¥${c.amount}')
          ).toList(),
        ),
      ],
      style: ReportStyle.elegant,
      shareText: '这是我的${period.month}月财务小结，钱龄${report.endMoneyAge}天！',
    );
  }

  /// 生成钱龄里程碑卡片
  Future<ShareCard> generateMoneyAgeMilestoneCard(int moneyAge) async {
    final level = MoneyAgeLevel.fromDays(moneyAge);

    return ShareCard(
      type: ShareCardType.moneyAgeMilestone,
      title: '钱龄${moneyAge}天！',
      subtitle: level.title,
      visual: MoneyAgeVisual(
        level: level,
        days: moneyAge,
        animation: 'money_age_celebration',
      ),
      encouragement: level.encouragement,
      shareText: '我的钱龄达到${moneyAge}天了！你的钱能活多久？',
    );
  }
}
```

#### 28.3.2 分享渠道与追踪

```dart
/// 分享渠道服务
class ShareChannelService {
  /// 支持的分享渠道
  static const supportedChannels = [
    ShareChannel(
      id: 'wechat_moment',
      name: '微信朋友圈',
      icon: 'wechat',
      cardStyle: ShareCardStyle.square,
    ),
    ShareChannel(
      id: 'wechat_friend',
      name: '微信好友',
      icon: 'wechat',
      cardStyle: ShareCardStyle.horizontal,
    ),
    ShareChannel(
      id: 'weibo',
      name: '微博',
      icon: 'weibo',
      cardStyle: ShareCardStyle.vertical,
    ),
    ShareChannel(
      id: 'xiaohongshu',
      name: '小红书',
      icon: 'xiaohongshu',
      cardStyle: ShareCardStyle.square,
    ),
    ShareChannel(
      id: 'save_image',
      name: '保存图片',
      icon: 'download',
      cardStyle: ShareCardStyle.square,
    ),
    ShareChannel(
      id: 'copy_link',
      name: '复制链接',
      icon: 'link',
    ),
  ];

  /// 执行分享
  Future<ShareResult> share(ShareCard card, ShareChannel channel) async {
    // 1. 根据渠道调整卡片样式
    final adaptedCard = _adaptCardForChannel(card, channel);

    // 2. 生成分享内容
    final content = await _generateShareContent(adaptedCard, channel);

    // 3. 调用分享SDK
    final result = await _invokeShareSdk(channel, content);

    // 4. 记录分享事件
    await _trackShareEvent(ShareEvent(
      cardType: card.type,
      channel: channel.id,
      success: result.success,
      timestamp: DateTime.now(),
    ));

    return result;
  }

  /// 追踪分享带来的新用户
  Future<void> trackReferral(String referralCode, String newUserId) async {
    final referrer = await _getUserByReferralCode(referralCode);
    if (referrer != null) {
      // 记录推荐关系
      await _saveReferralRelation(
        referrerId: referrer.id,
        refereeId: newUserId,
        timestamp: DateTime.now(),
      );

      // 给推荐者发放奖励
      await _awardReferrer(referrer.id);

      // 更新推荐者统计
      await _updateReferrerStats(referrer.id);
    }
  }
}
```

#### 28.3.3 邀请奖励机制

```dart
/// 邀请奖励服务
class ReferralRewardService {
  /// 奖励规则
  static const rewardRules = ReferralRewardRules(
    // 推荐者奖励
    referrerRewards: [
      ReferralReward(
        trigger: 'referee_registered',
        reward: '7天高级会员体验',
        description: '好友注册成功',
      ),
      ReferralReward(
        trigger: 'referee_active_7_days',
        reward: '解锁专属主题',
        description: '好友活跃使用7天',
      ),
      ReferralReward(
        trigger: 'referee_subscribed',
        reward: '1个月高级会员',
        description: '好友订阅会员',
      ),
    ],

    // 被推荐者奖励
    refereeRewards: [
      ReferralReward(
        trigger: 'registration',
        reward: '14天高级会员体验',
        description: '新用户注册奖励',
      ),
    ],

    // 累计推荐奖励
    cumulativeRewards: [
      CumulativeReward(
        count: 3,
        reward: '推荐达人徽章',
      ),
      CumulativeReward(
        count: 10,
        reward: '3个月高级会员',
      ),
      CumulativeReward(
        count: 50,
        reward: '终身高级会员',
      ),
    ],
  );

  /// 处理推荐奖励
  Future<void> processReferralReward(ReferralEvent event) async {
    final rules = rewardRules;

    // 检查推荐者奖励
    for (final reward in rules.referrerRewards) {
      if (reward.trigger == event.type) {
        await _grantReward(event.referrerId, reward);
        await _notifyReferrer(event.referrerId, reward);
      }
    }

    // 检查累计奖励
    final totalReferrals = await _getTotalReferrals(event.referrerId);
    for (final cumReward in rules.cumulativeRewards) {
      if (totalReferrals == cumReward.count) {
        await _grantReward(event.referrerId, cumReward.reward);
        await _celebrateMilestone(event.referrerId, cumReward);
      }
    }
  }
}
```

### 28.4 首周价值感知路径

#### 28.4.1 首周体验设计

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         首周价值感知路径                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Day 1: 初次体验                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  目标: 完成首笔记账，初识"钱龄"概念                               │   │
│  │                                                                 │   │
│  │  ① 极简注册（手机号一键登录）                                    │   │
│  │  ② 30秒新手引导（突出钱龄概念）                                  │   │
│  │  ③ 引导完成首笔记账                                              │   │
│  │  ④ 立即展示钱龄计算结果                                          │   │
│  │  ⑤ 惊喜动画 + "记账之旅开始了"                                   │   │
│  │                                                                 │   │
│  │  价值感知点: "原来我的钱只能活X天"                                │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Day 2-3: 建立习惯                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  目标: 体验AI便捷，设置首个小金库                                 │   │
│  │                                                                 │   │
│  │  ① 推送温和提醒记账                                              │   │
│  │  ② 引导尝试语音/拍照记账                                         │   │
│  │  ③ 展示AI智能分类能力                                            │   │
│  │  ④ 引导设置第一个小金库预算                                      │   │
│  │  ⑤ 可视化展示预算分配                                            │   │
│  │                                                                 │   │
│  │  价值感知点: "记账原来可以这么简单"                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Day 4-5: 产生洞察                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  目标: 获得首个消费洞察                                          │   │
│  │                                                                 │   │
│  │  ① 积累足够数据后，生成消费分析                                  │   │
│  │  ② 展示消费分类分布                                              │   │
│  │  ③ 智能发现消费规律                                              │   │
│  │  ④ 对比同龄人平均水平                                            │   │
│  │  ⑤ 给出第一条改善建议                                            │   │
│  │                                                                 │   │
│  │  价值感知点: "我终于知道钱都花哪了"                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Day 6-7: 形成习惯                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  目标: 完成首周，建立初步习惯                                     │   │
│  │                                                                 │   │
│  │  ① 展示首周财务小结                                              │   │
│  │  ② 显示钱龄变化趋势                                              │   │
│  │  ③ 解锁"坚持一周"成就                                           │   │
│  │  ④ 收集首次NPS反馈                                               │   │
│  │  ⑤ 引导设置储蓄目标                                              │   │
│  │                                                                 │   │
│  │  价值感知点: "一周就有了这么多变化"                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### 28.4.2 首周引导服务

```dart
/// 首周引导服务
class FirstWeekGuidanceService {
  /// 首周任务清单
  static const firstWeekTasks = [
    DailyTask(
      day: 1,
      tasks: [
        Task(id: 'complete_onboarding', name: '完成新手引导', required: true),
        Task(id: 'first_transaction', name: '记录第一笔账', required: true),
        Task(id: 'view_money_age', name: '查看钱龄', required: false),
      ],
    ),
    DailyTask(
      day: 2,
      tasks: [
        Task(id: 'try_voice_recording', name: '尝试语音记账', required: false),
        Task(id: 'second_transaction', name: '记录第二笔账', required: true),
      ],
    ),
    DailyTask(
      day: 3,
      tasks: [
        Task(id: 'setup_first_vault', name: '设置第一个小金库', required: true),
        Task(id: 'try_photo_recording', name: '尝试拍照记账', required: false),
      ],
    ),
    DailyTask(
      day: 4,
      tasks: [
        Task(id: 'view_category_stats', name: '查看分类统计', required: true),
        Task(id: 'continue_recording', name: '继续记账', required: true),
      ],
    ),
    DailyTask(
      day: 5,
      tasks: [
        Task(id: 'view_first_insight', name: '查看消费洞察', required: true),
        Task(id: 'review_budget', name: '检查预算使用情况', required: false),
      ],
    ),
    DailyTask(
      day: 6,
      tasks: [
        Task(id: 'set_savings_goal', name: '设置储蓄目标', required: false),
        Task(id: 'explore_more_features', name: '探索更多功能', required: false),
      ],
    ),
    DailyTask(
      day: 7,
      tasks: [
        Task(id: 'view_weekly_summary', name: '查看首周总结', required: true),
        Task(id: 'complete_nps_survey', name: '完成满意度调查', required: true),
      ],
    ),
  ];

  /// 获取今日引导任务
  Future<List<Task>> getTodayTasks(String userId) async {
    final daysActive = await _getDaysActive(userId);
    if (daysActive > 7) return [];  // 首周后不再引导

    final dailyTask = firstWeekTasks.firstWhere(
      (dt) => dt.day == daysActive,
      orElse: () => DailyTask(day: 0, tasks: []),
    );

    // 过滤已完成的任务
    final completedTasks = await _getCompletedTasks(userId);
    return dailyTask.tasks
        .where((t) => !completedTasks.contains(t.id))
        .toList();
  }

  /// 检查任务完成情况并触发奖励
  Future<void> checkTaskCompletion(String userId, String taskId) async {
    await _markTaskCompleted(userId, taskId);

    // 检查是否完成今日所有必做任务
    final todayTasks = await getTodayTasks(userId);
    final requiredTasks = todayTasks.where((t) => t.required).toList();
    if (requiredTasks.isEmpty) {
      await _triggerDailyCompletion(userId);
    }

    // 检查是否完成首周所有任务
    final allCompleted = await _checkAllFirstWeekTasksCompleted(userId);
    if (allCompleted) {
      await _triggerFirstWeekCompletion(userId);
    }
  }
}
```

### 28.5 负面体验检测与修复

#### 28.5.1 负面信号检测

```dart
/// 负面体验检测服务
class NegativeExperienceDetector {
  /// 负面信号定义
  static const negativeSignals = [
    // 操作层面的负面信号
    NegativeSignal(
      id: 'repeated_failures',
      description: '连续操作失败',
      detection: '3次以上连续操作失败',
      severity: SignalSeverity.medium,
    ),
    NegativeSignal(
      id: 'rage_clicks',
      description: '愤怒点击',
      detection: '短时间内同一位置多次点击',
      severity: SignalSeverity.high,
    ),
    NegativeSignal(
      id: 'long_confusion',
      description: '长时间困惑',
      detection: '在同一页面停留超过2分钟无有效操作',
      severity: SignalSeverity.low,
    ),
    NegativeSignal(
      id: 'quick_exit',
      description: '快速退出',
      detection: '进入功能后5秒内返回',
      severity: SignalSeverity.low,
    ),

    // 使用模式的负面信号
    NegativeSignal(
      id: 'usage_decline',
      description: '使用频率下降',
      detection: '周使用频率下降超过50%',
      severity: SignalSeverity.high,
    ),
    NegativeSignal(
      id: 'feature_abandonment',
      description: '功能放弃',
      detection: '开始使用某功能后中途放弃',
      severity: SignalSeverity.medium,
    ),
    NegativeSignal(
      id: 'session_shortening',
      description: '会话时长缩短',
      detection: '平均会话时长持续下降',
      severity: SignalSeverity.medium,
    ),

    // 流失预警信号
    NegativeSignal(
      id: 'approaching_churn',
      description: '接近流失',
      detection: '7天未使用',
      severity: SignalSeverity.critical,
    ),
    NegativeSignal(
      id: 'negative_feedback',
      description: '负面反馈',
      detection: '应用商店1-2星评价或负面反馈提交',
      severity: SignalSeverity.critical,
    ),
  ];

  /// 实时检测负面信号
  Stream<NegativeSignalEvent> monitorNegativeSignals(String userId) async* {
    // 监控操作事件
    await for (final event in _operationEventStream(userId)) {
      final signals = _detectOperationSignals(event);
      for (final signal in signals) {
        yield NegativeSignalEvent(
          userId: userId,
          signal: signal,
          context: event,
          timestamp: DateTime.now(),
        );
      }
    }
  }

  /// 分析用户的负面体验模式
  Future<NegativeExperienceReport> analyzeNegativePatterns(String userId) async {
    final signals = await _getRecentSignals(userId, days: 30);

    return NegativeExperienceReport(
      userId: userId,
      totalSignals: signals.length,
      signalsByType: _groupByType(signals),
      signalsByFeature: _groupByFeature(signals),
      churnRisk: _calculateChurnRisk(signals),
      recommendations: _generateRecoveryRecommendations(signals),
    );
  }
}
```

#### 28.5.2 负面体验修复机制

```dart
/// 负面体验修复服务
class NegativeExperienceRecoveryService {
  /// 修复策略
  static const recoveryStrategies = {
    // 操作失败修复
    'repeated_failures': RecoveryStrategy(
      immediateAction: '弹出帮助提示，询问是否需要协助',
      followUp: '发送操作指南推送',
      escalation: '邀请加入用户支持群',
    ),

    // 困惑状态修复
    'long_confusion': RecoveryStrategy(
      immediateAction: '显示功能引导气泡',
      followUp: '推送相关功能教程',
      escalation: null,
    ),

    // 愤怒点击修复
    'rage_clicks': RecoveryStrategy(
      immediateAction: '显示"遇到问题？让我来帮你"入口',
      followUp: '发送关怀消息和帮助链接',
      escalation: '产品团队介入分析',
    ),

    // 使用下降修复
    'usage_decline': RecoveryStrategy(
      immediateAction: null,
      followUp: '发送个性化唤醒消息',
      escalation: '分析流失原因',
    ),

    // 接近流失修复
    'approaching_churn': RecoveryStrategy(
      immediateAction: null,
      followUp: '发送价值回顾消息，展示累计成就',
      escalation: '发送挽回优惠或1对1关怀',
    ),

    // 负面反馈修复
    'negative_feedback': RecoveryStrategy(
      immediateAction: '感谢反馈，承诺改进',
      followUp: '跟进问题解决进度',
      escalation: '产品负责人亲自回复',
    ),
  };

  /// 执行修复策略
  Future<void> executeRecovery(NegativeSignalEvent event) async {
    final strategy = recoveryStrategies[event.signal.id];
    if (strategy == null) return;

    // 执行即时修复
    if (strategy.immediateAction != null) {
      await _executeImmediateAction(event.userId, strategy.immediateAction!);
    }

    // 安排后续跟进
    if (strategy.followUp != null) {
      await _scheduleFollowUp(
        userId: event.userId,
        action: strategy.followUp!,
        delay: Duration(hours: 24),
      );
    }

    // 记录修复尝试
    await _logRecoveryAttempt(event, strategy);
  }

  /// 流失用户挽回
  Future<void> attemptChurnRecovery(String userId) async {
    final user = await _getUser(userId);
    final stats = await _getUserStats(userId);

    // 生成个性化挽回消息
    final message = WinbackMessage(
      title: '好久不见，想你了',
      body: _generatePersonalizedWinbackMessage(user, stats),
      highlights: [
        '你的钱龄已达${stats.moneyAge}天',
        '累计记录${stats.totalTransactions}笔账',
        '总共节省了¥${stats.totalSaved}',
      ],
      callToAction: '回来看看',
      incentive: stats.isPremiumUser ? null : '回归即送7天会员',
    );

    await _sendWinbackNotification(userId, message);
  }
}
```

### 28.6 推荐者培育计划

#### 28.6.1 推荐者识别

```dart
/// 推荐者识别服务
class PromoterIdentificationService {
  /// 推荐者特征
  static const promoterIndicators = [
    PromoterIndicator(
      id: 'high_engagement',
      description: '高活跃度',
      criteria: '周活跃≥5天，日均使用≥3次',
      weight: 0.25,
    ),
    PromoterIndicator(
      id: 'feature_adoption',
      description: '功能采用广',
      criteria: '使用≥5个核心功能',
      weight: 0.20,
    ),
    PromoterIndicator(
      id: 'positive_outcomes',
      description: '正向成果',
      criteria: '钱龄提升、预算达成、储蓄目标进展',
      weight: 0.25,
    ),
    PromoterIndicator(
      id: 'long_tenure',
      description: '长期用户',
      criteria: '使用≥3个月',
      weight: 0.15,
    ),
    PromoterIndicator(
      id: 'social_behavior',
      description: '社交行为',
      criteria: '曾分享成就或邀请好友',
      weight: 0.15,
    ),
  ];

  /// 计算推荐者潜力分数
  Future<double> calculatePromoterPotential(String userId) async {
    double score = 0;

    for (final indicator in promoterIndicators) {
      final met = await _checkIndicator(userId, indicator);
      if (met) {
        score += indicator.weight;
      }
    }

    return score;  // 0-1之间
  }

  /// 识别潜在推荐者
  Future<List<PotentialPromoter>> identifyPotentialPromoters() async {
    final activeUsers = await _getActiveUsers(days: 30);
    final potentialPromoters = <PotentialPromoter>[];

    for (final userId in activeUsers) {
      final score = await calculatePromoterPotential(userId);
      if (score >= 0.7) {  // 阈值
        potentialPromoters.add(PotentialPromoter(
          userId: userId,
          score: score,
          indicators: await _getMetIndicators(userId),
        ));
      }
    }

    return potentialPromoters..sort((a, b) => b.score.compareTo(a.score));
  }
}
```

#### 28.6.2 推荐者激活

```dart
/// 推荐者激活服务
class PromoterActivationService {
  /// 激活策略
  Future<void> activatePromoter(PotentialPromoter promoter) async {
    // 1. 发送专属感谢
    await _sendAppreciationMessage(promoter.userId);

    // 2. 邀请加入VIP用户群
    await _inviteToVipGroup(promoter.userId);

    // 3. 解锁推荐者专属功能
    await _unlockPromoterFeatures(promoter.userId);

    // 4. 展示推荐入口
    await _enablePromoterDashboard(promoter.userId);
  }

  /// 推荐者专属功能
  static const promoterFeatures = [
    PromoterFeature(
      id: 'custom_share_cards',
      name: '定制分享卡片',
      description: '可自定义分享卡片的样式和内容',
    ),
    PromoterFeature(
      id: 'referral_dashboard',
      name: '推荐数据面板',
      description: '查看邀请好友的数据统计',
    ),
    PromoterFeature(
      id: 'early_access',
      name: '新功能抢先体验',
      description: '优先体验新功能并提供反馈',
    ),
    PromoterFeature(
      id: 'priority_support',
      name: '优先客服支持',
      description: '专属客服通道，快速响应',
    ),
  ];

  /// 推荐者仪表盘数据
  Future<PromoterDashboard> getPromoterDashboard(String userId) async {
    return PromoterDashboard(
      totalReferrals: await _getTotalReferrals(userId),
      activeReferrals: await _getActiveReferrals(userId),
      earnedRewards: await _getEarnedRewards(userId),
      pendingRewards: await _getPendingRewards(userId),
      referralLink: await _getReferralLink(userId),
      shareStats: await _getShareStats(userId),
    );
  }
}
```

### 28.7 贬损者挽回策略

#### 28.7.1 贬损者分析

```dart
/// 贬损者分析服务
class DetractorAnalysisService {
  /// 贬损者类型
  enum DetractorType {
    functional,      // 功能不满意
    experience,      // 体验不满意
    expectation,     // 期望落差
    technical,       // 技术问题
    value,           // 价值感知不足
  }

  /// 分析贬损原因
  Future<DetractorAnalysis> analyzeDetractor(String userId, int npsScore, String? reason) async {
    final analysis = DetractorAnalysis(userId: userId, npsScore: npsScore);

    // 分析文本反馈
    if (reason != null) {
      analysis.detractorType = await _classifyReason(reason);
      analysis.keyIssues = await _extractKeyIssues(reason);
    }

    // 分析使用行为
    analysis.usagePattern = await _analyzeUsagePattern(userId);
    analysis.failurePoints = await _identifyFailurePoints(userId);
    analysis.abandonedFeatures = await _getAbandonedFeatures(userId);

    // 评估挽回可能性
    analysis.recoveryProbability = _calculateRecoveryProbability(analysis);

    return analysis;
  }

  /// 计算挽回可能性
  double _calculateRecoveryProbability(DetractorAnalysis analysis) {
    double probability = 0.5;  // 基础概率

    // 根据贬损类型调整
    switch (analysis.detractorType) {
      case DetractorType.technical:
        probability += 0.3;  // 技术问题容易修复
        break;
      case DetractorType.functional:
        probability += 0.2;  // 功能问题可以改进
        break;
      case DetractorType.experience:
        probability += 0.1;  // 体验问题需要时间
        break;
      case DetractorType.expectation:
        probability -= 0.1;  // 期望落差较难弥补
        break;
      case DetractorType.value:
        probability -= 0.2;  // 价值感知问题较难
        break;
    }

    // 根据使用时长调整
    if (analysis.usagePattern.daysActive > 30) {
      probability += 0.1;  // 老用户更容易挽回
    }

    return probability.clamp(0.0, 1.0);
  }
}
```

#### 28.7.2 贬损者挽回执行

```dart
/// 贬损者挽回服务
class DetractorRecoveryService {
  /// 挽回策略
  Future<RecoveryPlan> createRecoveryPlan(DetractorAnalysis analysis) async {
    final plan = RecoveryPlan(userId: analysis.userId);

    // 根据贬损类型制定策略
    switch (analysis.detractorType) {
      case DetractorType.technical:
        plan.immediateActions = [
          '立即联系用户了解技术问题详情',
          '优先修复用户遇到的技术问题',
          '修复后主动通知用户并道歉',
        ];
        plan.compensation = '赠送1个月会员';
        break;

      case DetractorType.functional:
        plan.immediateActions = [
          '记录功能改进建议',
          '告知用户改进计划和预期时间',
          '邀请用户加入功能内测群',
        ];
        plan.compensation = '解锁高级功能14天体验';
        break;

      case DetractorType.experience:
        plan.immediateActions = [
          '安排1对1使用指导',
          '发送个性化使用教程',
          '持续跟进使用体验',
        ];
        plan.compensation = null;  // 不需要物质补偿
        break;

      case DetractorType.value:
        plan.immediateActions = [
          '展示用户已获得的价值（省钱金额、钱龄提升）',
          '推荐更适合用户的功能组合',
          '提供1对1财务规划建议',
        ];
        plan.compensation = '延长会员体验期';
        break;

      default:
        plan.immediateActions = [
          '发送诚挚道歉和感谢反馈',
          '邀请深度访谈了解具体问题',
        ];
    }

    return plan;
  }

  /// 执行挽回计划
  Future<RecoveryResult> executeRecoveryPlan(RecoveryPlan plan) async {
    final result = RecoveryResult(userId: plan.userId);

    // 执行即时行动
    for (final action in plan.immediateActions) {
      try {
        await _executeAction(plan.userId, action);
        result.completedActions.add(action);
      } catch (e) {
        result.failedActions.add(ActionFailure(action: action, error: e.toString()));
      }
    }

    // 发放补偿
    if (plan.compensation != null) {
      await _grantCompensation(plan.userId, plan.compensation!);
      result.compensationGranted = true;
    }

    // 设置跟进提醒
    await _scheduleFollowUp(plan.userId, Duration(days: 7));

    return result;
  }

  /// 跟进贬损者状态
  Future<void> followUpDetractor(String userId) async {
    // 检查用户近期行为
    final recentActivity = await _getRecentActivity(userId);

    if (recentActivity.isActive) {
      // 用户回归活跃，发送感谢
      await _sendThankYouMessage(userId);

      // 再次收集NPS
      await _scheduleNpsSurvey(userId, delay: Duration(days: 14));
    } else {
      // 用户仍不活跃，升级处理
      await _escalateToManualOutreach(userId);
    }
  }
}
```

### 28.8 目标达成检测

```dart
/// NPS目标达成检测服务
class NpsGoalDetector {
  /// NPS相关目标
  static const npsGoals = NpsGoalCriteria(
    // 核心NPS指标
    overallNps: NpsTarget(
      target: 50,
      measurement: '整体用户NPS评分',
    ),

    // 推荐者比例
    promoterRate: RateTarget(
      target: 0.40,  // 40%推荐者
      measurement: '9-10分用户占比',
    ),

    // 贬损者比例
    detractorRate: RateTarget(
      target: 0.10,  // 控制在10%以内
      measurement: '0-6分用户占比',
    ),

    // 口碑获客比例
    referralRate: RateTarget(
      target: 0.15,  // 15%用户来自推荐
      measurement: '推荐注册用户占比',
    ),

    // 分享率
    shareRate: RateTarget(
      target: 0.20,  // 20%用户有分享行为
      measurement: '有分享行为的活跃用户占比',
    ),
  );

  /// 检测目标达成状态
  Future<NpsGoalStatus> checkGoalStatus() async {
    final status = NpsGoalStatus();

    // 计算当前NPS
    final currentNps = await _calculateCurrentNps();
    status.overallNps = GoalCheckResult(
      current: currentNps,
      target: npsGoals.overallNps.target,
      achieved: currentNps >= npsGoals.overallNps.target,
    );

    // 计算推荐者比例
    final promoterRate = await _calculatePromoterRate();
    status.promoterRate = GoalCheckResult(
      current: promoterRate,
      target: npsGoals.promoterRate.target,
      achieved: promoterRate >= npsGoals.promoterRate.target,
    );

    // 计算贬损者比例
    final detractorRate = await _calculateDetractorRate();
    status.detractorRate = GoalCheckResult(
      current: detractorRate,
      target: npsGoals.detractorRate.target,
      achieved: detractorRate <= npsGoals.detractorRate.target,  // 越低越好
    );

    // 计算口碑获客比例
    final referralRate = await _calculateReferralRate();
    status.referralRate = GoalCheckResult(
      current: referralRate,
      target: npsGoals.referralRate.target,
      achieved: referralRate >= npsGoals.referralRate.target,
    );

    // 计算分享率
    final shareRate = await _calculateShareRate();
    status.shareRate = GoalCheckResult(
      current: shareRate,
      target: npsGoals.shareRate.target,
      achieved: shareRate >= npsGoals.shareRate.target,
    );

    return status;
  }

  /// 生成NPS改进建议
  Future<List<NpsImprovement>> generateImprovementSuggestions(NpsGoalStatus status) async {
    final suggestions = <NpsImprovement>[];

    if (!status.overallNps.achieved) {
      // 分析NPS短板
      final analysis = await _analyzeNpsDrivers();

      if (analysis.functionalSatisfaction < 0.7) {
        suggestions.add(NpsImprovement(
          area: '功能价值',
          priority: Priority.high,
          suggestions: [
            '提升钱龄分析的准确性和洞察深度',
            '增强预算管理的智能推荐能力',
            '优化AI识别的准确率',
          ],
        ));
      }

      if (analysis.experienceSatisfaction < 0.7) {
        suggestions.add(NpsImprovement(
          area: '体验质量',
          priority: Priority.high,
          suggestions: [
            '简化核心操作流程',
            '优化首周引导体验',
            '提升应用性能和稳定性',
          ],
        ));
      }

      if (analysis.emotionalConnection < 0.5) {
        suggestions.add(NpsImprovement(
          area: '情感连接',
          priority: Priority.medium,
          suggestions: [
            '增加惊喜时刻的触发点',
            '优化伙伴化文案的情感表达',
            '丰富成就系统的奖励机制',
          ],
        ));
      }
    }

    if (!status.shareRate.achieved) {
      suggestions.add(NpsImprovement(
        area: '分享机制',
        priority: Priority.medium,
        suggestions: [
          '优化分享卡片的视觉设计',
          '增加更多可分享的内容类型',
          '简化分享操作流程',
        ],
      ));
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
    content = content.rstrip() + NPS_CHAPTER

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print("已添加第28章：用户口碑与NPS提升设计")

if __name__ == '__main__':
    main()
