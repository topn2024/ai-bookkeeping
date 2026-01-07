# -*- coding: utf-8 -*-
"""
刷新第16章智能化技术方案
1. 修正系统集成图中的章节引用
2. 添加16.13目标达成检测
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ========== 修复1: 修正系统集成图中的章节引用 ==========
    ref_fixes = [
        # 修正习惯培养章节号 (9章→11章)
        ('│ │习惯培养│  │数据导入   │  │',
         '│ │习惯培养│  │账单导入   │  │'),
        ('│ │ (9章) │  │  (11章)  │  │',
         '│ │(11章) │  │  (12章)  │  │'),
        # 修正伙伴化章节号 (4章→6章)
        ('│ │  (4章)   │     │',
         '│ │  (6章)   │     │'),
    ]

    for old, new in ref_fixes:
        if old in content:
            content = content.replace(old, new)
            print(f"Fix ref: {old[:40]}...")
            changes += 1

    # ========== 修复2: 添加16.13目标达成检测 ==========
    # 在16.12之前添加16.13目标达成检测
    marker_16_12 = '### 16.12 智能语音交互系统'

    new_section_16_13 = '''### 16.13 目标达成检测

```dart
/// 智能化技术方案目标检测服务
class AIGoalDetector {
  /// 智能化相关目标
  static const aiGoals = AIGoalCriteria(
    // 智能分类准确率
    classificationAccuracy: AccuracyTarget(
      target: 0.95,  // 95%准确率
      measurement: '用户未修改的分类结果占比',
    ),

    // AI调用成本控制
    dailyCost: CostTarget(
      target: 1.0,  // 每日成本<=1元/活跃用户
      measurement: 'API调用总成本/DAU',
    ),

    // 响应延迟
    responseLatency: LatencyTarget(
      target: Duration(milliseconds: 500),
      measurement: '智能分类P95延迟',
    ),

    // 规则命中率
    ruleHitRate: RateTarget(
      target: 0.70,  // 70%请求由规则处理
      measurement: '规则命中次数/总请求次数',
    ),

    // 异常检测准确率
    anomalyPrecision: AccuracyTarget(
      target: 0.85,  // 85%精确率
      measurement: '真正异常/检测为异常',
    ),
  );

  /// 检测目标达成状态
  Future<AIGoalStatus> checkGoalStatus() async {
    final status = AIGoalStatus();

    // 计算分类准确率
    final accuracy = await _calculateClassificationAccuracy();
    status.classificationAccuracy = GoalCheckResult(
      current: accuracy,
      target: aiGoals.classificationAccuracy.target,
      achieved: accuracy >= aiGoals.classificationAccuracy.target,
    );

    // 计算每日成本
    final dailyCost = await _calculateDailyAICost();
    status.dailyCost = GoalCheckResult(
      current: dailyCost,
      target: aiGoals.dailyCost.target,
      achieved: dailyCost <= aiGoals.dailyCost.target,
    );

    // 计算规则命中率
    final ruleHitRate = await _calculateRuleHitRate();
    status.ruleHitRate = GoalCheckResult(
      current: ruleHitRate,
      target: aiGoals.ruleHitRate.target,
      achieved: ruleHitRate >= aiGoals.ruleHitRate.target,
    );

    return status;
  }
}
```

| 目标项 | 目标值 | 测量方式 | 优先级 |
|--------|--------|----------|--------|
| 分类准确率 | >=95% | 用户未修改占比 | P0 |
| 日均AI成本 | <=1元/用户 | API成本/DAU | P0 |
| 响应延迟P95 | <=500ms | 智能分类延迟 | P0 |
| 规则命中率 | >=70% | 规则处理占比 | P1 |
| 异常检测精确率 | >=85% | 真阳性率 | P1 |
| 大模型调用率 | <=10% | LLM兜底占比 | P1 |

---

'''

    if marker_16_12 in content and '### 16.13 目标达成检测' not in content:
        content = content.replace(marker_16_12, new_section_16_13 + marker_16_12)
        print("OK: Added 16.13 goal detection section")
        changes += 1

    # 写入文件
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== Chapter 16 refresh done, {changes} changes =====")
    else:
        print("\nNo changes needed")

    return changes

if __name__ == '__main__':
    main()
