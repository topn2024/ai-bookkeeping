# -*- coding: utf-8 -*-
"""
刷新第2章产品定位与愿景
1. 添加2.0 设计原则回顾
2. 添加2.6 2.0版本新模块概览
3. 添加2.7 目标达成检测
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 添加2.0设计原则回顾 ==========
    # 在"## 2. 产品定位与愿景"之后，"### 2.1 产品定位"之前插入
    marker_21 = '''## 2. 产品定位与愿景

### 2.1 产品定位'''

    new_section_20 = '''## 2. 产品定位与愿景

### 2.0 设计原则回顾

#### 2.0.1 产品定位设计原则矩阵

| 设计原则 | 在产品定位中的体现 | 具体措施 |
|----------|-------------------|----------|
| 懒人优先 | 零学习成本的产品体验 | 语音记账、智能识别、自动分类 |
| 伙伴化 | 有温度的财务助手定位 | 鼓励式反馈、成就系统、情感化文案 |
| 无障碍 | 普惠金融记账工具 | 多模态交互、无障碍支持、老年模式 |

#### 2.0.2 设计理念

```
产品定位核心理念：让记账成为一种轻松的习惯

┌─────────────────────────────────────────────────────────────┐
│                    AI智能记账2.0定位                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│   │   语音优先   │  │   智能理解   │  │   主动服务   │        │
│   │  Voice-First │  │ AI-Powered  │  │  Proactive  │        │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│          │                │                │                │
│          └────────────────┼────────────────┘                │
│                           │                                 │
│                           ▼                                 │
│              ┌─────────────────────────┐                    │
│              │      用户价值中心        │                    │
│              │  省时 · 省心 · 省力      │                    │
│              └─────────────────────────┘                    │
│                           │                                 │
│          ┌────────────────┼────────────────┐                │
│          │                │                │                │
│          ▼                ▼                ▼                │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│   │  个人记账    │  │  家庭共享    │  │  财务洞察    │        │
│   │   场景       │  │   场景       │  │   场景       │        │
│   └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 2.0.3 与2.0其他系统的协同关系图

```
                    产品定位与愿景
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │ 第3章    │    │ 第4章    │    │ 第5章    │
    │懒人设计  │    │伙伴化    │    │无障碍    │
    └────┬────┘    └────┬────┘    └────┬────┘
         │               │               │
         └───────────────┼───────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │   第三部分：核心业务  │
              │  第6-14章功能实现    │
              └──────────┬──────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │ 第15章   │    │ 第18章   │    │ 第19章   │
    │技术架构  │    │语音交互  │    │性能优化  │
    └─────────┘    └─────────┘    └─────────┘
```

### 2.1 产品定位'''

    if marker_21 in content and '### 2.0 设计原则回顾' not in content:
        content = content.replace(marker_21, new_section_20)
        print("OK: Added 2.0 设计原则回顾")
        changes += 1

    # ========== 添加2.6和2.7新章节 ==========
    # 在2.5.5之后，"---\n\n# 第二部分"之前添加
    marker_part2 = '''---

# 第二部分：设计理念与原则'''

    new_sections_26_27 = '''### 2.6 2.0版本新模块概览

#### 2.6.1 新增核心功能模块

| 模块名称 | 章节 | 核心能力 | 用户价值 |
|----------|------|----------|----------|
| 家庭账本 | 第13章 | 多人协作记账、权限管理 | 家庭财务透明化 |
| 位置智能 | 第14章 | 场景识别、POI推荐 | 自动化记账场景 |
| 习惯培养 | 第11章 | 打卡、挑战、成就 | 养成记账习惯 |
| 语音交互 | 第18章 | 多轮对话、意图理解 | 解放双手记账 |
| 自学习系统 | 第17章 | 用户偏好学习 | 越用越懂你 |

#### 2.6.2 功能模块关系图

```
┌─────────────────────────────────────────────────────────────┐
│                    2.0版本功能架构                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    交互层                            │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐       │   │
│  │  │ 语音交互   │  │ 图像识别   │  │ 手动输入   │       │   │
│  │  │  (第18章)  │  │  (第7章)   │  │  (第6章)   │       │   │
│  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘       │   │
│  └────────┼──────────────┼──────────────┼─────────────┘   │
│           └──────────────┼──────────────┘                  │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    智能层                            │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐       │   │
│  │  │ 自学习系统 │  │ 位置智能   │  │ 智能分类   │       │   │
│  │  │  (第17章)  │  │  (第14章)  │  │  (第8章)   │       │   │
│  │  └───────────┘  └───────────┘  └───────────┘       │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    业务层                            │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐       │   │
│  │  │ 预算管理   │  │ 家庭账本   │  │ 习惯培养   │       │   │
│  │  │  (第10章)  │  │  (第13章)  │  │  (第11章)  │       │   │
│  │  └───────────┘  └───────────┘  └───────────┘       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 2.6.3 用户旅程与模块映射

```dart
/// 用户使用旅程阶段
enum UserJourneyStage {
  /// 新手期：首次使用1-7天
  onboarding,
  /// 成长期：使用7-30天
  growing,
  /// 成熟期：使用30天以上
  mature,
  /// 专家期：深度使用用户
  expert,
}

/// 各阶段推荐功能
const stageFeatureMap = {
  UserJourneyStage.onboarding: [
    '语音记账',      // 最低门槛入口
    '智能分类',      // 自动化减负
    '习惯打卡',      // 建立习惯
  ],
  UserJourneyStage.growing: [
    '预算管理',      // 开始规划
    '位置智能',      // 场景化记账
    '报表分析',      // 了解消费
  ],
  UserJourneyStage.mature: [
    '家庭账本',      // 协作需求
    '储蓄目标',      // 长期规划
    '钱龄分析',      // 深度洞察
  ],
  UserJourneyStage.expert: [
    '数据导出',      // 高级需求
    '自定义报表',    // 个性化
    '多账本管理',    // 复杂场景
  ],
};
```

### 2.7 目标达成检测

```dart
/// 产品定位目标检测服务
class ProductPositionGoalDetector {
  /// 产品定位相关目标
  static const productGoals = ProductGoalCriteria(
    // 用户激活率
    activationRate: RateTarget(
      target: 0.60,  // 60%新用户在首日完成首笔记账
      measurement: '首日记账用户数 / 新增用户数',
    ),

    // 语音记账使用率
    voiceUsageRate: RateTarget(
      target: 0.40,  // 40%用户使用语音记账
      measurement: '使用语音记账的用户 / 活跃用户',
    ),

    // 7日留存率
    day7Retention: RateTarget(
      target: 0.45,  // 45%七日留存
      measurement: '第7日活跃用户 / 新增用户',
    ),

    // 30日留存率
    day30Retention: RateTarget(
      target: 0.25,  // 25%三十日留存
      measurement: '第30日活跃用户 / 新增用户',
    ),

    // 用户满意度NPS
    npsScore: ScoreTarget(
      target: 50,  // NPS>=50
      measurement: '推荐者占比 - 贬损者占比',
    ),

    // 功能覆盖率（用户使用过的核心功能占比）
    featureCoverage: RateTarget(
      target: 0.60,  // 60%用户使用3个以上核心功能
      measurement: '使用3+核心功能用户 / 活跃用户',
    ),
  );

  /// 检测目标达成状态
  Future<ProductGoalStatus> checkGoalStatus() async {
    final status = ProductGoalStatus();

    // 激活率检测
    final activationRate = await _calculateActivationRate();
    status.activationRate = GoalCheckResult(
      current: activationRate,
      target: productGoals.activationRate.target,
      achieved: activationRate >= productGoals.activationRate.target,
    );

    // 语音使用率检测
    final voiceRate = await _calculateVoiceUsageRate();
    status.voiceUsageRate = GoalCheckResult(
      current: voiceRate,
      target: productGoals.voiceUsageRate.target,
      achieved: voiceRate >= productGoals.voiceUsageRate.target,
    );

    // 留存率检测
    final day7Retention = await _calculateRetention(7);
    status.day7Retention = GoalCheckResult(
      current: day7Retention,
      target: productGoals.day7Retention.target,
      achieved: day7Retention >= productGoals.day7Retention.target,
    );

    final day30Retention = await _calculateRetention(30);
    status.day30Retention = GoalCheckResult(
      current: day30Retention,
      target: productGoals.day30Retention.target,
      achieved: day30Retention >= productGoals.day30Retention.target,
    );

    // NPS检测
    final nps = await _calculateNPS();
    status.npsScore = GoalCheckResult(
      current: nps,
      target: productGoals.npsScore.target,
      achieved: nps >= productGoals.npsScore.target,
    );

    return status;
  }
}
```

| 目标项 | 目标值 | 测量方式 | 优先级 |
|--------|--------|----------|--------|
| 首日激活率 | >=60% | 首日记账用户/新增用户 | P0 |
| 语音记账使用率 | >=40% | 语音用户/活跃用户 | P0 |
| 7日留存率 | >=45% | D7活跃/新增 | P0 |
| 30日留存率 | >=25% | D30活跃/新增 | P0 |
| NPS分数 | >=50 | 推荐者-贬损者占比 | P0 |
| 功能覆盖率 | >=60% | 使用3+功能用户占比 | P1 |
| 平均记账频次 | >=5次/周 | 周记账笔数/周活跃用户 | P1 |
| 家庭账本渗透率 | >=15% | 家庭账本用户/活跃用户 | P1 |

---

# 第二部分：设计理念与原则'''

    if marker_part2 in content and '### 2.6 2.0版本新模块概览' not in content:
        content = content.replace(marker_part2, new_sections_26_27)
        print("OK: Added 2.6 and 2.7 sections")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 2 refresh done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
