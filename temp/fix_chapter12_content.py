# -*- coding: utf-8 -*-
"""
刷新第12章数据联动与可视化内容
1. 扩展下钻维度矩阵（添加家庭、位置、语音维度）
2. 扩展手势交互规范（添加语音、无障碍交互）
3. 添加与2.0新模块的集成
"""

def main():
    filepath = 'd:/code/ai-bookkeeping/docs/design/app_v2_design.md'

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    changes = 0

    # ============================================================
    # 修复1: 扩展下钻维度矩阵 - 添加家庭、位置、语音维度
    # ============================================================
    old_text1 = '''#### 12.3.1 下钻维度矩阵

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            数据下钻维度矩阵                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐                                                           │
│   │  时间维度   │  年 → 季度 → 月 → 周 → 日 → 时段 → 单笔交易               │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 2025年 → Q1 → 1月 → 第1周 → 1月5日 → 12:00-13:00 → 午餐      │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │  分类维度   │  一级分类 → 二级分类 → 商家 → 单笔交易                     │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 餐饮 → 外卖 → 美团外卖 → 午餐订单 ¥35                         │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │  账户维度   │  账户类型 → 具体账户 → 收支明细 → 单笔交易                 │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 储蓄卡 → 工商银行 → 支出明细 → 转账 ¥1000                     │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │  钱龄维度   │  钱龄等级 → 钱龄范围 → 对应消费 → 单笔交易                 │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 黄色(14-30天) → 15-20天 → 消费列表 → 购物 ¥200                │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │  预算维度   │  预算总览 → 小金库 → 已用明细 → 单笔交易                   │
│   └─────────────┘                                                           │
│          │                                                                  │
│          └──→ 本月预算 → 餐饮小金库 → 已用¥2000 → 晚餐 ¥80                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```'''

    new_text1 = '''#### 12.3.1 下钻维度矩阵

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            数据下钻维度矩阵                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐                                                           │
│   │  时间维度   │  年 → 季度 → 月 → 周 → 日 → 时段 → 单笔交易               │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 2025年 → Q1 → 1月 → 第1周 → 1月5日 → 12:00-13:00 → 午餐      │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │  分类维度   │  一级分类 → 二级分类 → 商家 → 单笔交易                     │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 餐饮 → 外卖 → 美团外卖 → 午餐订单 ¥35                         │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │  账户维度   │  账户类型 → 具体账户 → 收支明细 → 单笔交易                 │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 储蓄卡 → 工商银行 → 支出明细 → 转账 ¥1000                     │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │  钱龄维度   │  钱龄等级 → 钱龄范围 → 对应消费 → 单笔交易                 │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 黄色(14-30天) → 15-20天 → 消费列表 → 购物 ¥200                │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │  预算维度   │  预算总览 → 小金库 → 已用明细 → 单笔交易                   │
│   └─────────────┘                                                           │
│          │                                                                  │
│          └──→ 本月预算 → 餐饮小金库 → 已用¥2000 → 晚餐 ¥80                  │
│                                                                             │
│  ────────────────────────────────────────────────────────────────────────  │
│                           2.0新增下钻维度                                    │
│  ────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│   ┌─────────────┐                                                           │
│   │ 家庭成员(13)│  家庭总览 → 成员视图 → 成员分类 → 成员交易                 │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 家庭消费 → 小明 → 小明餐饮 → 小明午餐 ¥35                     │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │ 位置维度(14)│  全国热力 → 城市 → 区域 → 商圈 → 商家 → 单笔交易           │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 全国 → 北京 → 朝阳区 → 三里屯 → 星巴克 → 咖啡 ¥38            │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │ 习惯维度(9) │  习惯总览 → 习惯类型 → 打卡记录 → 关联交易                 │
│   └─────────────┘                                                           │
│          │                                                                  │
│          ├──→ 习惯概览 → 记账习惯 → 连续30天 → 1月打卡详情                   │
│          │                                                                  │
│   ┌─────────────┐                                                           │
│   │ 语音维度(18)│  语音历史 → 识别记录 → 解析结果 → 生成交易                 │
│   └─────────────┘                                                           │
│          │                                                                  │
│          └──→ 语音记录 → "午餐35" → 解析：餐饮¥35 → 确认的交易              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**2.0新增维度说明**：

| 维度 | 来源章节 | 下钻层级 | 特点 |
|------|---------|---------|------|
| **家庭成员** | 第13章 | 家庭→成员→分类→交易 | 支持成员对比视图 |
| **位置** | 第14章 | 全国→城市→区域→商家→交易 | 热力图可视化 |
| **习惯** | 第9章 | 习惯类型→打卡记录→关联交易 | 连续性追踪 |
| **语音** | 第18章 | 语音记录→解析结果→生成交易 | 溯源验证 |'''

    if old_text1 in content:
        content = content.replace(old_text1, new_text1)
        print("✓ 修复1: 扩展下钻维度矩阵（添加家庭、位置、习惯、语音维度）")
        changes += 1

    # ============================================================
    # 修复2: 扩展手势交互规范 - 添加语音、无障碍交互
    # ============================================================
    old_text2 = '''#### 12.7.1 手势交互规范

| 手势 | 适用组件 | 行为 | 反馈 |
|------|----------|------|------|
| 单击 | 所有可点击元素 | 进入下一层/查看详情 | 涟漪效果 + 轻微触觉反馈 |
| 长按 | 图表数据点/列表项 | 显示操作菜单/快捷操作 | 放大 + 中等触觉反馈 |
| 双击 | 图表区域 | 重置缩放/回到默认视图 | 缩放动画 |
| 捏合 | 趋势图/热力图 | 缩放时间范围 | 平滑缩放动画 |
| 拖动 | 趋势图 | 平移查看更多数据 | 惯性滚动 |
| 右滑 | 页面/列表项 | 返回上一层/删除 | 滑动跟随动画 |'''

    new_text2 = '''#### 12.7.1 手势交互规范

| 手势 | 适用组件 | 行为 | 反馈 |
|------|----------|------|------|
| 单击 | 所有可点击元素 | 进入下一层/查看详情 | 涟漪效果 + 轻微触觉反馈 |
| 长按 | 图表数据点/列表项 | 显示操作菜单/快捷操作 | 放大 + 中等触觉反馈 |
| 双击 | 图表区域 | 重置缩放/回到默认视图 | 缩放动画 |
| 捏合 | 趋势图/热力图 | 缩放时间范围 | 平滑缩放动画 |
| 拖动 | 趋势图 | 平移查看更多数据 | 惯性滚动 |
| 右滑 | 页面/列表项 | 返回上一层/删除 | 滑动跟随动画 |

**2.0新增交互方式**：

| 交互方式 | 适用场景 | 行为 | 来源章节 |
|---------|---------|------|---------|
| 语音查询 | 任意图表页面 | "查看餐饮支出" → 跳转餐饮分类详情 | 第18章 |
| 语音下钻 | 任意图表页面 | "看看上个月" → 时间范围切换到上月 | 第18章 |
| 语音返回 | 任意下钻页面 | "返回首页" → 清空下钻栈回到首页 | 第18章 |
| 屏幕阅读 | 所有图表 | 图表数据自动朗读描述 | 第5章 |
| 焦点导航 | 所有可点击元素 | Tab键顺序导航，Enter确认 | 第5章 |
| 放大手势 | 所有图表 | 三指双击放大图表区域 | 第5章 |

**语音下钻指令示例**：

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           语音下钻指令支持（第18章集成）                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  "查看餐饮支出"      →  分类维度下钻到餐饮                                    │
│  "看看1月份"         →  时间维度切换到1月                                     │
│  "小明花了多少"      →  家庭维度下钻到成员小明                                 │
│  "三里屯消费情况"    →  位置维度下钻到三里屯商圈                               │
│  "预算还剩多少"      →  预算维度展示当前预算余额                               │
│  "最近的大额支出"    →  时间+金额复合筛选                                      │
│  "返回上一页"        →  下钻栈pop一层                                         │
│  "回到首页"          →  清空下钻栈                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```'''

    if old_text2 in content:
        content = content.replace(old_text2, new_text2)
        print("✓ 修复2: 扩展手势交互规范（添加语音下钻、无障碍交互）")
        changes += 1

    # ============================================================
    # 修复3: 添加与2.0新模块的集成
    # ============================================================
    old_text3 = '''#### 12.9.3 与AI洞察系统集成

```dart
/// 数据联动 - AI洞察系统集成
class InsightLinkageIntegration {
  /// 从洞察卡片下钻到相关数据
  static DrillDownLevel fromInsightCard(FinancialInsight insight) {
    switch (insight.type) {
      case InsightType.unusedSubscription:
        return DrillDownLevel(
          title: '订阅支出',
          route: '/category/subscriptions',
          dimension: 'category',
          hierarchyLevel: 1,
          params: {'merchant': insight.relatedMerchant},
        );

      case InsightType.categoryOverspend:
        return DrillDownLevel(
          title: insight.categoryName ?? '分类详情',
          route: '/category/${insight.categoryId}',
          dimension: 'category',
          hierarchyLevel: 1,
          inheritedFilters: FilterCriteria(
            categoryIds: [insight.categoryId!],
            dateRange: insight.dateRange,
          ),
        );

      case InsightType.spendingAnomaly:
        return DrillDownLevel(
          title: '异常消费',
          route: '/transactions',
          dimension: 'time',
          hierarchyLevel: 2,
          inheritedFilters: FilterCriteria(
            dateRange: insight.dateRange,
            amountRange: AmountRange(min: insight.thresholdAmount),
          ),
        );

      default:
        return DrillDownLevel(
          title: '相关数据',
          route: '/transactions',
          dimension: 'time',
          hierarchyLevel: 0,
        );
    }
  }
}
```

### 12.10 目标达成检测'''

    new_text3 = '''#### 12.9.3 与AI洞察系统集成

```dart
/// 数据联动 - AI洞察系统集成
class InsightLinkageIntegration {
  /// 从洞察卡片下钻到相关数据
  static DrillDownLevel fromInsightCard(FinancialInsight insight) {
    switch (insight.type) {
      case InsightType.unusedSubscription:
        return DrillDownLevel(
          title: '订阅支出',
          route: '/category/subscriptions',
          dimension: 'category',
          hierarchyLevel: 1,
          params: {'merchant': insight.relatedMerchant},
        );

      case InsightType.categoryOverspend:
        return DrillDownLevel(
          title: insight.categoryName ?? '分类详情',
          route: '/category/${insight.categoryId}',
          dimension: 'category',
          hierarchyLevel: 1,
          inheritedFilters: FilterCriteria(
            categoryIds: [insight.categoryId!],
            dateRange: insight.dateRange,
          ),
        );

      case InsightType.spendingAnomaly:
        return DrillDownLevel(
          title: '异常消费',
          route: '/transactions',
          dimension: 'time',
          hierarchyLevel: 2,
          inheritedFilters: FilterCriteria(
            dateRange: insight.dateRange,
            amountRange: AmountRange(min: insight.thresholdAmount),
          ),
        );

      default:
        return DrillDownLevel(
          title: '相关数据',
          route: '/transactions',
          dimension: 'time',
          hierarchyLevel: 0,
        );
    }
  }
}
```

#### 12.9.4 与家庭账本系统集成（第13章）

```dart
/// 数据联动 - 家庭账本系统集成
class FamilyLinkageIntegration {
  /// 从家庭概览卡片下钻
  static DrillDownLevel fromFamilyOverview(Family family) {
    return DrillDownLevel(
      title: '${family.name}消费',
      route: '/family/overview',
      dimension: 'family',
      hierarchyLevel: 0,
      params: {'familyId': family.id},
    );
  }

  /// 从家庭成员卡片下钻
  static DrillDownLevel fromMemberCard(FamilyMember member) {
    return DrillDownLevel(
      title: '${member.nickname}的消费',
      route: '/family/member/${member.id}',
      dimension: 'family',
      hierarchyLevel: 1,
      inheritedFilters: FilterCriteria(memberId: member.id),
    );
  }

  /// 成员消费对比图点击下钻
  static DrillDownLevel fromMemberComparison(String memberId, String categoryId) {
    return DrillDownLevel(
      title: '消费明细',
      route: '/transactions',
      dimension: 'family',
      hierarchyLevel: 2,
      inheritedFilters: FilterCriteria(
        memberId: memberId,
        categoryIds: [categoryId],
      ),
    );
  }
}
```

#### 12.9.5 与位置智能系统集成（第14章）

```dart
/// 数据联动 - 位置智能系统集成
class LocationLinkageIntegration {
  /// 从消费热力图下钻
  static DrillDownLevel fromHeatmapRegion(GeoRegion region) {
    return DrillDownLevel(
      title: region.name,
      route: '/location/region',
      dimension: 'location',
      hierarchyLevel: 1,
      params: {
        'latitude': region.center.latitude,
        'longitude': region.center.longitude,
        'radius': region.radius,
      },
    );
  }

  /// 从商圈消费排行下钻
  static DrillDownLevel fromBusinessDistrict(String districtName) {
    return DrillDownLevel(
      title: '$districtName消费',
      route: '/location/district',
      dimension: 'location',
      hierarchyLevel: 2,
      inheritedFilters: FilterCriteria(locationName: districtName),
    );
  }

  /// 从位置标记下钻到该地点消费
  static DrillDownLevel fromLocationMarker(LatLng location, String merchantName) {
    return DrillDownLevel(
      title: merchantName,
      route: '/transactions',
      dimension: 'location',
      hierarchyLevel: 3,
      inheritedFilters: FilterCriteria(
        merchantName: merchantName,
        nearLocation: location,
      ),
    );
  }
}
```

#### 12.9.6 与语音交互系统集成（第18章）

```dart
/// 数据联动 - 语音交互系统集成
class VoiceLinkageIntegration {
  /// 语音意图解析为下钻动作
  static DrillDownLevel? fromVoiceIntent(VoiceIntent intent) {
    switch (intent.type) {
      case VoiceIntentType.queryCategorySpending:
        return DrillDownLevel(
          title: intent.categoryName ?? '分类消费',
          route: '/category/${intent.categoryId}',
          dimension: 'category',
          hierarchyLevel: 1,
          inheritedFilters: FilterCriteria(
            categoryIds: intent.categoryId != null ? [intent.categoryId!] : null,
            dateRange: intent.dateRange,
          ),
        );

      case VoiceIntentType.queryMemberSpending:
        return DrillDownLevel(
          title: '${intent.memberName}的消费',
          route: '/family/member/${intent.memberId}',
          dimension: 'family',
          hierarchyLevel: 1,
          inheritedFilters: FilterCriteria(memberId: intent.memberId),
        );

      case VoiceIntentType.queryLocationSpending:
        return DrillDownLevel(
          title: '${intent.locationName}消费',
          route: '/location/district',
          dimension: 'location',
          hierarchyLevel: 2,
          inheritedFilters: FilterCriteria(locationName: intent.locationName),
        );

      case VoiceIntentType.queryBudgetStatus:
        return DrillDownLevel(
          title: '预算执行',
          route: '/budget/execution',
          dimension: 'budget',
          hierarchyLevel: 0,
        );

      case VoiceIntentType.navigateBack:
        return null; // 返回操作由DrillDownStack处理

      default:
        return null;
    }
  }

  /// 从语音记录下钻到生成的交易
  static DrillDownLevel fromVoiceRecord(VoiceRecord record) {
    return DrillDownLevel(
      title: '语音记录详情',
      route: '/voice/record/${record.id}',
      dimension: 'voice',
      hierarchyLevel: 0,
      params: {'recordId': record.id},
    );
  }
}
```

#### 12.9.7 与自学习系统集成（第17章）

```dart
/// 数据联动 - 自学习系统集成
class LearningLinkageIntegration {
  /// 个性化推荐的下钻入口
  static DrillDownLevel fromPersonalizedRecommendation(Recommendation rec) {
    return DrillDownLevel(
      title: rec.title,
      route: rec.targetRoute,
      dimension: rec.dimension,
      hierarchyLevel: 1,
      params: rec.params,
      // 自学习系统预测的用户最可能感兴趣的数据
      aiPredictedInterest: true,
    );
  }

  /// 从用户画像下钻到消费模式
  static DrillDownLevel fromUserProfile(UserProfile profile, String patternType) {
    return DrillDownLevel(
      title: '消费模式: $patternType',
      route: '/profile/pattern',
      dimension: 'learning',
      hierarchyLevel: 1,
      params: {'patternType': patternType},
    );
  }
}
```

### 12.10 目标达成检测'''

    if old_text3 in content:
        content = content.replace(old_text3, new_text3)
        print("✓ 修复3: 添加与2.0新模块的集成（家庭账本、位置智能、语音交互、自学习系统）")
        changes += 1

    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n===== 第12章数据联动与可视化内容刷新完成，共 {changes} 处 =====")
    else:
        print("\n未找到目标位置或已刷新")

    return changes

if __name__ == '__main__':
    main()
