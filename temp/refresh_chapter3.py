# -*- coding: utf-8 -*-
"""
刷新第3章懒人设计原则
1. 添加3.0设计原则回顾
2. 添加3.8 2.0新模块懒人设计适配
3. 添加3.9 目标达成检测
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 修复1: 添加3.0设计原则回顾 ==========
    old_section_31 = '''## 3. 懒人设计原则

**"懒人设计"** 是 AI智能记账 2.0 的核心设计哲学之一。我们的目标用户是那些想要管理好自己财务、但又不愿意花太多时间在记账上的"懒人"。为这些用户设计产品，意味着要在每一个交互点上都追求极致的简洁。

### 3.1 设计理念'''

    new_section_30 = '''## 3. 懒人设计原则

**"懒人设计"** 是 AI智能记账 2.0 的核心设计哲学之一。我们的目标用户是那些想要管理好自己财务、但又不愿意花太多时间在记账上的"懒人"。为这些用户设计产品，意味着要在每一个交互点上都追求极致的简洁。

### 3.0 设计原则回顾

在深入懒人设计细节之前，让我们回顾本章如何体现2.0版本的核心设计原则：

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      懒人设计 - 设计原则矩阵                                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │  操作单一    │  │  数据驱动    │  │  极简交互    │  │  场景扩展    │       │
│  │  职责       │  │  默认       │  │  设计       │  │  性          │       │
│  │             │  │             │  │             │  │             │       │
│  │ 每步只做    │  │ 基于历史    │  │ 最少点击    │  │ 新场景可    │       │
│  │ 一件事      │  │ 智能推荐    │  │ 零配置可用  │  │ 快速适配    │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│         │                │                │                │              │
│         ▼                ▼                ▼                ▼              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │  性能优先    │  │  可观测性    │  │  容错设计    │  │  单手操作    │       │
│  │             │  │             │  │             │  │             │       │
│  │ 响应<100ms  │  │ 操作效率    │  │ 宽容输入    │  │ 拇指热区    │       │
│  │ 预加载缓存  │  │ 步骤追踪    │  │ 智能纠错    │  │ 左右适配    │       │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                                            │
│  懒人设计核心理念：                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │  "能自动的不手动，能一步的不两步，能推断的不输入"                        │   │
│  │                                                                    │   │
│  │   能自动 ──→ 智能分类、自动填充、位置识别、场景推断                    │   │
│  │   能一步 ──→ 语音记账、摇一摇、快捷入口、模板匹配                      │   │
│  │   能推断 ──→ 时间/金额/分类/商家全部智能推断                          │   │
│  └────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

#### 3.0.1 设计原则在懒人设计中的体现

| 设计原则 | 懒人设计应用 | 具体措施 | 效果指标 |
|---------|-------------|---------|---------|
| **单一职责** | 每步只做一件事 | 记账流程拆解为独立可跳过的步骤 | 每步<2秒完成 |
| **数据一致性** | 智能默认联动 | 选择商家自动填充分类、选择分类自动推荐金额 | 自动填充率>80% |
| **极简设计** | 零配置可用 | 新用户无需任何配置即可开始记账 | 首次记账<30秒 |
| **可扩展性** | 快捷方式可配置 | 用户可自定义常用操作的快捷入口 | 自定义功能满意度>4分 |
| **性能优化** | 即时响应 | 预加载、本地计算、乐观更新 | 操作响应<100ms |
| **可观测性** | 效率追踪 | 追踪每个操作的步骤数和耗时 | 持续优化依据 |

#### 3.0.2 与2.0其他系统的协作

```
┌────────────────────────────────────────────────────────────────────────────┐
│                       懒人设计系统协作全景图                                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│                        ┌─────────────────┐                                 │
│                        │   懒人设计服务   │                                 │
│                        │  LazyDesignCore │                                 │
│                        └────────┬────────┘                                 │
│                                 │                                          │
│           ┌─────────────────────┼─────────────────────┐                    │
│           │                     │                     │                    │
│           ▼                     ▼                     ▼                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │    智能推断      │  │    快捷操作      │  │    自动配置      │            │
│  │                 │  │                 │  │                 │            │
│  │ • 分类推断      │  │ • 语音记账      │  │ • 位置检测      │            │
│  │ • 金额推断      │  │ • 摇一摇        │  │ • 发薪日检测    │            │
│  │ • 时间推断      │  │ • 模板匹配      │  │ • 消费偏好      │            │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘            │
│           │                     │                     │                    │
│           └─────────────────────┼─────────────────────┘                    │
│                                 │                                          │
│  ┌──────────────────────────────┴──────────────────────────────┐           │
│  │                       数据来源系统                            │           │
│  ├──────────────────────────────────────────────────────────────┤           │
│  │                                                              │           │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │           │
│  │  │ 交易历史  │ │ 位置服务  │ │ 语音服务  │ │ AI分类   │        │           │
│  │  │          │ │          │ │          │ │          │        │           │
│  │  │ 模式学习  │ │ POI匹配  │ │ 意图识别  │ │ 商家识别  │        │           │
│  │  │ 习惯推断  │ │ 场景识别  │ │ 实体提取  │ │ 分类预测  │        │           │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │           │
│  │                                                              │           │
│  └──────────────────────────────────────────────────────────────┘           │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 设计理念'''

    if old_section_31 in content and '### 3.0 设计原则回顾' not in content:
        content = content.replace(old_section_31, new_section_30)
        print("OK: Added 3.0 design principle review section")
        changes += 1

    # ========== 修复2: 添加3.8和3.9新章节 ==========
    marker_chapter4 = '''```

---


---

## 4. 伙伴化设计原则'''

    new_sections = '''```

### 3.8 2.0新模块懒人设计适配

#### 3.8.1 家庭账本懒人设计

```dart
/// 家庭账本懒人设计服务
class FamilyLazyDesignService {
  /// 一键邀请家人
  Future<InviteResult> oneClickInvite() async {
    // 自动生成邀请链接+语音邀请码
    final link = await _generateInviteLink();
    final voiceCode = await _generateVoiceCode();

    // 自动复制到剪贴板
    await Clipboard.setData(ClipboardData(text: link));

    // 自动调起分享面板
    await Share.share(
      '邀请你加入我的记账家庭，语音邀请码：$voiceCode',
      subject: 'AI智能记账家庭邀请',
    );

    return InviteResult(link: link, voiceCode: voiceCode);
  }

  /// 智能共享判断
  Future<bool> shouldAutoShare(Transaction tx) async {
    // 基于历史行为自动判断是否共享
    final patterns = await _analyzeSharePatterns();

    // 家庭聚餐、共同购物等场景自动建议共享
    if (patterns.isLikelySharedCategory(tx.category)) {
      return true;
    }

    // 金额超过阈值建议共享
    if (tx.amount >= patterns.sharedAmountThreshold) {
      return true;
    }

    return false;
  }

  /// 成员权限快捷设置
  Widget buildQuickRoleSelector(FamilyMember member) {
    return SegmentedButton<FamilyRole>(
      segments: [
        ButtonSegment(value: FamilyRole.viewer, label: Text('查看')),
        ButtonSegment(value: FamilyRole.member, label: Text('成员')),
        ButtonSegment(value: FamilyRole.admin, label: Text('管理')),
      ],
      selected: {member.role},
      onSelectionChanged: (roles) => _updateRole(member, roles.first),
    );
  }
}
```

#### 3.8.2 位置智能懒人设计

```dart
/// 位置智能懒人设计服务
class LocationLazyDesignService {
  /// 自动识别并填充商家信息
  Future<MerchantInfo?> autoFillMerchant() async {
    final location = await _getCurrentLocation();
    if (location == null) return null;

    // 自动匹配POI
    final poi = await _poiService.matchNearby(location);
    if (poi == null) return null;

    return MerchantInfo(
      name: poi.name,
      category: poi.suggestedCategory,
      location: location,
    );
  }

  /// 场景自动配置
  Future<SceneConfig> autoConfigureByScene(SceneType scene) async {
    switch (scene) {
      case SceneType.dining:
        return SceneConfig(
          defaultCategory: '餐饮',
          suggestedAmounts: [15, 25, 35, 50],
          quickNotes: ['早餐', '午餐', '晚餐', '下午茶'],
        );
      case SceneType.shopping:
        return SceneConfig(
          defaultCategory: '购物',
          suggestedAmounts: [50, 100, 200, 500],
          quickNotes: ['日用品', '服装', '电子产品'],
        );
      case SceneType.commute:
        return SceneConfig(
          defaultCategory: '交通',
          suggestedAmounts: [3, 5, 10, 20],
          quickNotes: ['地铁', '公交', '打车'],
        );
      default:
        return SceneConfig.empty();
    }
  }

  /// 地理围栏自动记账建议
  Future<void> onEnterGeofence(GeofenceRegion region) async {
    // 进入常去地点自动弹出记账建议
    final history = await _getLocationHistory(region);
    if (history.avgAmount > 0) {
      await _showQuickBookingSuggestion(
        merchant: region.name,
        category: history.mostFrequentCategory,
        suggestedAmount: history.avgAmount,
      );
    }
  }
}
```

#### 3.8.3 语音交互懒人设计

```dart
/// 语音交互懒人设计服务
class VoiceLazyDesignService {
  /// 一句话多笔记账
  Future<List<Transaction>> parseMultipleTransactions(String text) async {
    // "早餐15午餐30晚餐50" -> 3笔交易
    final transactions = await _nluService.extractMultiple(text);

    // 自动填充日期（今天）
    for (final tx in transactions) {
      tx.date ??= DateTime.now();
    }

    // 自动分类
    for (final tx in transactions) {
      tx.category ??= await _classifyByNote(tx.note);
    }

    return transactions;
  }

  /// 语音快捷命令
  static const voiceShortcuts = {
    '记一笔': VoiceCommand.addTransaction,
    '本月花了多少': VoiceCommand.queryMonthlySpending,
    '今天花了多少': VoiceCommand.queryDailySpending,
    '餐饮预算还剩多少': VoiceCommand.queryBudget,
    '设置提醒': VoiceCommand.setReminder,
    '撤销': VoiceCommand.undo,
  };

  /// 语音唤醒后自动进入记账模式
  Future<void> onVoiceWakeup() async {
    // 默认假设用户要记账
    await _startListeningForTransaction();
  }

  /// 智能容错解析
  Future<Transaction?> parseWithTolerance(String text) async {
    // "记个二十块吃饭" -> 金额20，分类餐饮
    // "午饭花了三十五" -> 金额35，分类餐饮
    // "打车15" -> 金额15，分类交通

    final result = await _nluService.parseFlexible(text);
    if (result.confidence > 0.7) {
      return result.transaction;
    }

    // 低置信度时请求确认
    return null;
  }
}
```

#### 3.8.4 习惯培养懒人设计

```dart
/// 习惯培养懒人设计服务
class HabitLazyDesignService {
  /// 自动打卡（记账即打卡）
  Future<void> autoCheckInOnBooking(Transaction tx) async {
    // 记账自动完成打卡，无需额外操作
    await _habitService.checkIn(
      habitId: 'daily_booking',
      proof: tx.id,
    );
  }

  /// 智能提醒时机
  Future<DateTime> calculateOptimalReminderTime() async {
    // 分析用户最常记账的时间
    final history = await _getBookingTimeHistory();
    return history.mostFrequentTime;
  }

  /// 一键开启/关闭提醒
  Widget buildReminderToggle() {
    return SwitchListTile(
      title: Text('记账提醒'),
      subtitle: Text('每天最佳时间提醒'),
      value: _reminderEnabled,
      onChanged: (v) => _toggleReminder(v),
    );
  }

  /// 挑战一键参与
  Future<void> oneClickJoinChallenge(Challenge challenge) async {
    // 无需配置，直接参与
    await _challengeService.join(challenge.id);

    // 自动设置相关提醒
    await _setupChallengeReminders(challenge);
  }
}
```

### 3.9 目标达成检测

```dart
/// 懒人设计目标检测服务
class LazyDesignGoalDetector {
  /// 懒人设计相关目标
  static const lazyDesignGoals = LazyDesignGoalCriteria(
    // 高频操作步骤数
    highFrequencySteps: StepsTarget(
      target: 1,  // 高频操作<=1步
      measurement: '完成高频操作的平均点击次数',
    ),

    // 记账耗时
    bookingDuration: DurationTarget(
      target: Duration(seconds: 10),  // 单笔记账<10秒
      measurement: '从开始到完成记账的平均时间',
    ),

    // 自动填充率
    autoFillRate: RateTarget(
      target: 0.80,  // 80%字段自动填充
      measurement: '自动填充的字段数/总字段数',
    ),

    // 智能默认值采纳率
    defaultAcceptRate: RateTarget(
      target: 0.70,  // 70%用户接受默认值
      measurement: '未修改默认值的操作/总操作',
    ),

    // 新用户首次记账时间
    firstBookingTime: DurationTarget(
      target: Duration(seconds: 30),  // 新用户30秒内完成首次记账
      measurement: '注册到首次记账的时间',
    ),

    // 操作响应时间
    responseTime: DurationTarget(
      target: Duration(milliseconds: 100),
      measurement: '操作响应P95延迟',
    ),
  );

  /// 检测目标达成状态
  Future<LazyDesignGoalStatus> checkGoalStatus() async {
    final status = LazyDesignGoalStatus();

    // 测量高频操作步骤
    final avgSteps = await _measureHighFrequencySteps();
    status.highFrequencySteps = GoalCheckResult(
      current: avgSteps,
      target: lazyDesignGoals.highFrequencySteps.target,
      achieved: avgSteps <= lazyDesignGoals.highFrequencySteps.target,
    );

    // 测量记账耗时
    final avgDuration = await _measureBookingDuration();
    status.bookingDuration = GoalCheckResult(
      current: avgDuration,
      target: lazyDesignGoals.bookingDuration.target,
      achieved: avgDuration <= lazyDesignGoals.bookingDuration.target,
    );

    // 计算自动填充率
    final autoFillRate = await _calculateAutoFillRate();
    status.autoFillRate = GoalCheckResult(
      current: autoFillRate,
      target: lazyDesignGoals.autoFillRate.target,
      achieved: autoFillRate >= lazyDesignGoals.autoFillRate.target,
    );

    // 计算默认值采纳率
    final acceptRate = await _calculateDefaultAcceptRate();
    status.defaultAcceptRate = GoalCheckResult(
      current: acceptRate,
      target: lazyDesignGoals.defaultAcceptRate.target,
      achieved: acceptRate >= lazyDesignGoals.defaultAcceptRate.target,
    );

    return status;
  }
}
```

| 目标项 | 目标值 | 测量方式 | 优先级 |
|--------|--------|----------|--------|
| 高频操作步骤 | <=1步 | 平均点击次数 | P0 |
| 中频操作步骤 | <=2步 | 平均点击次数 | P0 |
| 低频操作步骤 | <=3步 | 平均点击次数 | P1 |
| 单笔记账耗时 | <10秒 | 平均完成时间 | P0 |
| 自动填充率 | >=80% | 自动填充字段占比 | P0 |
| 默认值采纳率 | >=70% | 未修改默认值占比 | P1 |
| 新用户首次记账 | <30秒 | 注册到首次记账 | P0 |
| 操作响应时间 | <100ms | P95延迟 | P0 |

---


---

## 4. 伙伴化设计原则'''

    if marker_chapter4 in content and '### 3.8 2.0新模块懒人设计适配' not in content:
        content = content.replace(marker_chapter4, new_sections)
        print("OK: Added 3.8 and 3.9 sections")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 3 refresh done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
