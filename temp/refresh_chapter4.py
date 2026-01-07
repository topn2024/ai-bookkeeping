# -*- coding: utf-8 -*-
"""
刷新第4章伙伴化设计原则
1. 添加4.9 2.0新模块伙伴化集成
2. 添加4.10 目标达成检测
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # 在4.8.8效果追踪代码块结束后，附录之前添加新章节
    marker_appendix = '''```

---

## 附录

### A. 术语表'''

    new_sections = '''```

### 4.9 2.0新模块伙伴化集成

#### 4.9.1 家庭账本伙伴化

```dart
/// 家庭账本伙伴化服务
class FamilyCompanionService {
  final CopyGeneratorService _copyGen;
  final NotificationService _notification;

  /// 成员加入欢迎
  Future<void> welcomeNewMember(FamilyMember member, String familyName) async {
    final copy = await _copyGen.generate(
      scene: CopyScene.familyWelcome,
      context: {
        'memberName': member.name,
        'familyName': familyName,
      },
    );
    // "欢迎{memberName}加入{familyName}！一起记账，一起成长~"
    await _notification.show(copy);
  }

  /// 共享记账互动
  Future<void> celebrateSharedBooking(
    String memberName,
    Transaction tx,
  ) async {
    final copy = await _copyGen.generate(
      scene: CopyScene.familySharedBooking,
      context: {
        'memberName': memberName,
        'category': tx.categoryName,
        'amount': tx.amount,
      },
    );
    // "{memberName}刚记了一笔{category}，家庭记账又进一步！"
  }

  /// 家庭目标达成
  Future<void> celebrateFamilyGoal(SavingsGoal goal) async {
    final copy = await _copyGen.generate(
      scene: CopyScene.familyGoalAchieved,
      context: {
        'goalName': goal.name,
        'amount': goal.targetAmount,
        'memberCount': goal.contributorCount,
      },
    );
    // "全家齐心，{goalName}目标达成！{memberCount}位成员共同努力的成果~"
  }

  /// 家庭记账提醒（温和互动式）
  Future<void> gentleFamilyReminder(String memberName, int daysInactive) async {
    if (daysInactive < 3) return; // 3天内不提醒

    final copy = await _copyGen.generate(
      scene: CopyScene.familyGentleReminder,
      context: {
        'memberName': memberName,
        'days': daysInactive,
      },
    );
    // "{memberName}好像有{days}天没记账了，要不要提醒TA一下？"
  }
}

/// 家庭场景文案模板
const familyCopyTemplates = {
  CopyScene.familyWelcome: [
    '欢迎{memberName}加入{familyName}！一起记账，一起成长~',
    '{familyName}迎来新成员{memberName}！从今天开始共同理财吧',
    '太棒了！{memberName}加入了{familyName}的记账小队',
  ],
  CopyScene.familySharedBooking: [
    '{memberName}刚记了一笔{category}，家庭记账又进一步！',
    '叮~{memberName}记录了{amount}元{category}',
    '{memberName}今天也在认真记账呢',
  ],
  CopyScene.familyGoalAchieved: [
    '🎉 全家齐心，{goalName}目标达成！',
    '太厉害了！{memberCount}位成员一起攒够了{goalName}',
    '{goalName}达成！这是全家共同努力的成果~',
  ],
};
```

#### 4.9.2 位置智能伙伴化

```dart
/// 位置智能伙伴化服务
class LocationCompanionService {
  final CopyGeneratorService _copyGen;

  /// 智能场景问候
  Future<String?> getSceneGreeting(SceneType scene, TimeOfDay time) async {
    final copy = await _copyGen.generate(
      scene: CopyScene.locationSceneGreeting,
      context: {
        'sceneType': scene.name,
        'timeOfDay': _getTimeOfDayName(time),
      },
    );
    return copy;
  }

  String _getTimeOfDayName(TimeOfDay time) {
    if (time.hour < 11) return '早上';
    if (time.hour < 14) return '中午';
    if (time.hour < 18) return '下午';
    return '晚上';
  }

  /// 常去地点个性化
  Future<String> getFrequentPlaceMessage(String placeName, int visitCount) async {
    final copy = await _copyGen.generate(
      scene: CopyScene.frequentPlace,
      context: {
        'placeName': placeName,
        'visitCount': visitCount,
      },
    );
    // "又来{placeName}啦~这是你第{visitCount}次光顾"
    return copy;
  }

  /// 新地点发现
  Future<void> discoverNewPlace(PoiResult poi) async {
    final copy = await _copyGen.generate(
      scene: CopyScene.newPlaceDiscovered,
      context: {
        'placeName': poi.name,
        'category': poi.category,
      },
    );
    // "发现新地点：{placeName}，要记录一下吗？"
  }
}

/// 位置场景文案模板
const locationCopyTemplates = {
  CopyScene.locationSceneGreeting: {
    'dining_早上': '早餐时间~今天吃了什么好吃的？',
    'dining_中午': '午饭时间到，记得记录一下哦',
    'dining_晚上': '晚餐愉快~别忘了记一笔',
    'shopping_下午': '逛街愉快！有什么收获吗？',
    'commute_早上': '早安！新的一天开始了',
    'commute_晚上': '辛苦了，安全到家~',
  },
  CopyScene.frequentPlace: [
    '又来{placeName}啦~这是你第{visitCount}次光顾',
    '{placeName}的常客又来了！',
    '熟悉的{placeName}，熟悉的味道',
  ],
};
```

#### 4.9.3 语音交互伙伴化

```dart
/// 语音交互伙伴化服务
class VoiceCompanionService {
  final TtsService _tts;
  final CopyGeneratorService _copyGen;

  /// 语音记账成功反馈
  Future<void> speakBookingSuccess(Transaction tx) async {
    final copies = [
      '好的，已记录${tx.categoryName}${tx.amount.toInt()}元',
      '收到~${tx.categoryName}${tx.amount.toInt()}元已记录',
      '记好了！${tx.categoryName}花了${tx.amount.toInt()}元',
    ];
    await _tts.speak(copies[DateTime.now().second % copies.length]);
  }

  /// 语音查询结果播报（带情感）
  Future<void> speakQueryResult(QueryResult result) async {
    String response;

    if (result.type == QueryType.monthlySpending) {
      final amount = result.amount;
      final trend = result.trend;

      if (trend == Trend.down) {
        response = '这个月花了${amount.toInt()}元，比上月少了呢，继续保持！';
      } else if (trend == Trend.up && result.changePercent > 20) {
        response = '这个月花了${amount.toInt()}元，比上月多了一些，注意控制哦';
      } else {
        response = '这个月花了${amount.toInt()}元，和上月差不多';
      }
    } else {
      response = await _copyGen.generateQueryResponse(result);
    }

    await _tts.speak(response);
  }

  /// 语音错误时的安慰
  Future<void> speakErrorComfort() async {
    final copies = [
      '没听清楚，能再说一次吗？',
      '抱歉，我没理解，换个说法试试？',
      '嗯？好像没听懂，能重复一下吗？',
    ];
    await _tts.speak(copies[DateTime.now().second % copies.length]);
  }

  /// 连续使用鼓励
  Future<void> speakContinuousEncouragement(int consecutiveDays) async {
    if (consecutiveDays == 7) {
      await _tts.speak('连续语音记账7天了，太厉害了！');
    } else if (consecutiveDays == 30) {
      await _tts.speak('哇，语音记账坚持一个月了，你是记账达人！');
    }
  }
}
```

#### 4.9.4 习惯培养伙伴化

```dart
/// 习惯培养伙伴化服务
class HabitCompanionService {
  final CopyGeneratorService _copyGen;
  final NotificationService _notification;

  /// 打卡成功庆祝
  Future<void> celebrateCheckIn(int streak) async {
    String copy;

    if (streak == 1) {
      copy = '今天第一次打卡，好的开始！';
    } else if (streak == 7) {
      copy = '🎉 连续7天！一周的坚持，你真棒！';
    } else if (streak == 30) {
      copy = '🏆 30天连续打卡！这份毅力太让人佩服了！';
    } else if (streak == 100) {
      copy = '🌟 100天！你已经是记账习惯大师了！';
    } else if (streak % 10 == 0) {
      copy = '连续${streak}天打卡！稳定输出中~';
    } else {
      copy = '第${streak}天，继续保持！';
    }

    await _notification.showCelebration(copy);
  }

  /// 断签安慰
  Future<void> comfortStreakBroken(int previousStreak) async {
    final copy = await _copyGen.generate(
      scene: CopyScene.streakBroken,
      context: {'previousStreak': previousStreak},
    );
    // "没关系，之前连续{previousStreak}天已经很棒了！今天重新开始~"
    await _notification.show(copy);
  }

  /// 挑战进度鼓励
  Future<void> encourageChallengeProgress(Challenge challenge) async {
    final progress = challenge.current / challenge.target;

    if (progress >= 0.5 && progress < 0.6) {
      await _notification.show('已经完成一半了，加油！');
    } else if (progress >= 0.8 && progress < 0.9) {
      await _notification.show('快要达成了，冲刺！');
    } else if (progress >= 1.0) {
      await _notification.showCelebration('🎉 挑战完成！你太厉害了！');
    }
  }

  /// 智能提醒（基于最佳时机）
  Future<void> sendOptimalReminder(DateTime optimalTime) async {
    final copies = [
      '该记账啦~',
      '今天记账了吗？',
      '记录一下今天的消费吧',
      '养成好习惯，从每天记账开始',
    ];

    await _notification.scheduleAt(
      optimalTime,
      copies[optimalTime.day % copies.length],
    );
  }
}

/// 习惯场景文案
const habitCopyTemplates = {
  CopyScene.streakBroken: [
    '没关系，之前连续{previousStreak}天已经很棒了！今天重新开始~',
    '断签不可怕，可怕的是不再开始。加油！',
    '跌倒了就爬起来，你可以的！',
  ],
  CopyScene.challengeHalfway: [
    '已经完成一半了，继续保持！',
    '50%达成！胜利在望~',
  ],
};
```

### 4.10 目标达成检测

```dart
/// 伙伴化设计目标检测服务
class CompanionGoalDetector {
  /// 伙伴化相关目标
  static const companionGoals = CompanionGoalCriteria(
    // 消息互动率
    interactionRate: RateTarget(
      target: 0.15,  // 15%互动率
      measurement: '点击/展开消息数 / 展示消息数',
    ),

    // 消息关闭率（越低越好）
    dismissRate: RateTarget(
      target: 0.30,  // 关闭率<=30%
      measurement: '主动关闭数 / 展示消息数',
    ),

    // 用户情感满意度
    sentimentScore: ScoreTarget(
      target: 4.0,  // 5分制>=4分
      measurement: '用户对伙伴化体验的评分',
    ),

    // 文案生成响应时间
    copyGenerationLatency: DurationTarget(
      target: Duration(milliseconds: 100),
      measurement: '动态文案生成P95延迟',
    ),

    // 场景覆盖率
    sceneCoverage: RateTarget(
      target: 0.90,  // 90%场景有伙伴化支持
      measurement: '有伙伴化支持的场景 / 总场景数',
    ),

    // 人格一致性评分
    personalityConsistency: ScoreTarget(
      target: 4.5,  // 5分制>=4.5分
      measurement: '用户对伙伴人格一致性的评分',
    ),
  );

  /// 检测目标达成状态
  Future<CompanionGoalStatus> checkGoalStatus() async {
    final status = CompanionGoalStatus();

    // 计算互动率
    final interactionRate = await _calculateInteractionRate();
    status.interactionRate = GoalCheckResult(
      current: interactionRate,
      target: companionGoals.interactionRate.target,
      achieved: interactionRate >= companionGoals.interactionRate.target,
    );

    // 计算关闭率
    final dismissRate = await _calculateDismissRate();
    status.dismissRate = GoalCheckResult(
      current: dismissRate,
      target: companionGoals.dismissRate.target,
      achieved: dismissRate <= companionGoals.dismissRate.target,
    );

    // 获取情感满意度
    final sentimentScore = await _getSentimentScore();
    status.sentimentScore = GoalCheckResult(
      current: sentimentScore,
      target: companionGoals.sentimentScore.target,
      achieved: sentimentScore >= companionGoals.sentimentScore.target,
    );

    // 测量文案生成延迟
    final latency = await _measureCopyGenerationLatency();
    status.copyGenerationLatency = GoalCheckResult(
      current: latency,
      target: companionGoals.copyGenerationLatency.target,
      achieved: latency <= companionGoals.copyGenerationLatency.target,
    );

    return status;
  }
}
```

| 目标项 | 目标值 | 测量方式 | 优先级 |
|--------|--------|----------|--------|
| 消息互动率 | >=15% | 互动数/展示数 | P0 |
| 消息关闭率 | <=30% | 主动关闭数/展示数 | P0 |
| 情感满意度 | >=4分(5分制) | 用户评分调研 | P0 |
| 文案生成延迟 | <=100ms | P95延迟 | P1 |
| 场景覆盖率 | >=90% | 有伙伴化场景占比 | P1 |
| 人格一致性 | >=4.5分 | 用户一致性评分 | P1 |
| 每日消息上限 | <=3条 | 每日推送数 | P0 |
| 单次消息上限 | <=1条 | 单次场景推送数 | P0 |

---

## 附录

### A. 术语表'''

    if marker_appendix in content and '### 4.9 2.0新模块伙伴化集成' not in content:
        content = content.replace(marker_appendix, new_sections)
        print("OK: Added 4.9 and 4.10 sections")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 4 refresh done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
