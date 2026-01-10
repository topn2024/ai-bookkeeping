# 渐进式功能解锁系统设计

## 核心理念

**"从简单开始，按需成长"**

- 所有人都从简易模式开始
- 系统分析用户能力和需求
- 智能推荐合适的新功能
- 用户决定是否解锁
- 不同智商的人以不同速度成长

## 用户分层

### 三类用户画像

| 用户类型 | IQ范围 | 特征 | 最终状态 |
|---------|--------|------|---------|
| **基础用户** | 60-80 | 需要持续简化 | 简易模式 + 1-2个基础功能 |
| **普通用户** | 90-110 | 逐步学习新功能 | 简易模式 + 5-8个常用功能 |
| **高级用户** | 120+ | 快速掌握复杂功能 | 完整功能集 |

### 系统如何识别用户类型

**不直接问IQ，而是通过行为分析：**

```dart
class UserCapabilityAnalyzer {
  // 分析指标
  double errorRate;           // 错误率
  double taskCompletionSpeed; // 任务完成速度
  int helpRequestCount;       // 求助次数
  int featureExplorationRate; // 功能探索率
  double sessionDuration;     // 使用时长
  int consecutiveDays;        // 连续使用天数

  // 计算用户能力等级
  UserCapabilityLevel calculateLevel() {
    int score = 0;

    // 低错误率 +20分
    if (errorRate < 0.1) score += 20;
    else if (errorRate < 0.3) score += 10;

    // 快速完成任务 +20分
    if (taskCompletionSpeed < 30) score += 20; // 30秒内
    else if (taskCompletionSpeed < 60) score += 10;

    // 很少求助 +15分
    if (helpRequestCount < 2) score += 15;
    else if (helpRequestCount < 5) score += 8;

    // 主动探索 +15分
    if (featureExplorationRate > 0.5) score += 15;
    else if (featureExplorationRate > 0.2) score += 8;

    // 长时间使用 +15分
    if (sessionDuration > 300) score += 15; // 5分钟+
    else if (sessionDuration > 120) score += 8;

    // 持续使用 +15分
    if (consecutiveDays > 7) score += 15;
    else if (consecutiveDays > 3) score += 8;

    // 总分100分，分级
    if (score >= 70) return UserCapabilityLevel.advanced;
    if (score >= 40) return UserCapabilityLevel.intermediate;
    return UserCapabilityLevel.basic;
  }
}

enum UserCapabilityLevel {
  basic,        // 基础用户
  intermediate, // 普通用户
  advanced,     // 高级用户
}
```

## 功能货架设计

### 功能分级

**Level 0: 简易模式核心（所有人）**
- 花钱
- 收钱
- 查看今日记录

**Level 1: 基础功能（基础用户可解锁）**
- 查看历史记录（全部）
- 简单统计（本月花了多少）
- 预算设置（一个数字）

**Level 2: 常用功能（普通用户可解锁）**
- 分类管理
- 账户管理
- 月度统计
- 预算分类
- 导出数据

**Level 3: 高级功能（高级用户可解锁）**
- 趋势分析
- 目标设置
- 自动分类
- 智能建议
- 数据可视化

**Level 4: 专家功能（专家用户可解锁）**
- 多账本
- 自定义报表
- API集成
- 高级筛选
- 批量操作

### 功能货架UI

```
┌─────────────────────────────────┐
│        功能货架 🏪               │
├─────────────────────────────────┤
│                                 │
│ 已解锁 (3)                      │
│ ✓ 查看历史                      │
│ ✓ 简单统计                      │
│ ✓ 预算设置                      │
│                                 │
│ 推荐解锁 (2) 🌟                 │
│ 🔓 分类管理                     │
│    "你已经记了50笔，可以分类了" │
│    [解锁] [以后再说]            │
│                                 │
│ 🔓 账户管理                     │
│    "管理多个账户"               │
│    [解锁] [以后再说]            │
│                                 │
│ 未解锁 (8)                      │
│ 🔒 趋势分析 (需要30天数据)      │
│ 🔒 目标设置 (需要解锁预算)      │
│ 🔒 智能建议 (需要100笔记录)     │
│ ...                             │
└─────────────────────────────────┘
```

## 解锁机制对比

### 方案A：纯自动解锁

**优点：**
- ✅ 用户无需操作
- ✅ 系统完全控制节奏
- ✅ 不会overwhelm用户

**缺点：**
- ❌ 用户失去控制感
- ❌ 可能解锁不需要的功能
- ❌ 高级用户被限制

**适用场景：**
- 基础用户（IQ 60-80）
- 完全不想学习的用户

### 方案B：纯手动解锁

**优点：**
- ✅ 用户完全控制
- ✅ 按需解锁
- ✅ 高级用户可快速解锁全部

**缺点：**
- ❌ 基础用户不知道该解锁什么
- ❌ 可能解锁过早导致困惑
- ❌ 需要用户主动探索

**适用场景：**
- 高级用户（IQ 120+）
- 有明确需求的用户

### 方案C：混合解锁（推荐）

**机制：**
1. **系统智能推荐** - 分析用户行为，推荐合适功能
2. **用户确认解锁** - 用户可以接受、延迟或拒绝
3. **手动探索** - 用户随时可以浏览功能货架
4. **自适应节奏** - 根据用户能力调整推荐频率

**优点：**
- ✅ 兼顾引导和自主
- ✅ 适应不同用户类型
- ✅ 用户有控制感
- ✅ 系统提供智能建议

**缺点：**
- ⚠️ 实现复杂度较高
- ⚠️ 需要精细调优

**这是最佳方案！**

## 混合解锁系统详细设计

### 1. 解锁触发条件

```dart
class FeatureUnlockTrigger {
  final String featureId;
  final String featureName;
  final UnlockCondition condition;

  bool checkCondition(UserProfile user, AppUsageData usage) {
    return condition.isMet(user, usage);
  }
}

abstract class UnlockCondition {
  bool isMet(UserProfile user, AppUsageData usage);
  String getDescription();
  double getProgress(UserProfile user, AppUsageData usage);
}

// 示例：分类管理解锁条件
class CategoryManagementUnlock extends UnlockCondition {
  @override
  bool isMet(UserProfile user, AppUsageData usage) {
    return usage.transactionCount >= 50 &&
           usage.daysUsed >= 7 &&
           user.capabilityLevel >= UserCapabilityLevel.intermediate;
  }

  @override
  String getDescription() {
    return '记录50笔交易，使用7天，能力达到普通水平';
  }

  @override
  double getProgress(UserProfile user, AppUsageData usage) {
    final transactionProgress = usage.transactionCount / 50;
    final daysProgress = usage.daysUsed / 7;
    final capabilityProgress = user.capabilityLevel.index / 2;

    return (transactionProgress + daysProgress + capabilityProgress) / 3;
  }
}
```

### 2. 推荐算法

```dart
class FeatureRecommendationEngine {
  // 推荐下一个应该解锁的功能
  Future<FeatureRecommendation?> getNextRecommendation(
    UserProfile user,
    AppUsageData usage,
  ) async {
    // 获取所有未解锁功能
    final lockedFeatures = await getLockedFeatures(user);

    // 过滤：条件满足的功能
    final eligible = lockedFeatures.where((f) {
      return f.trigger.checkCondition(user, usage);
    }).toList();

    if (eligible.isEmpty) return null;

    // 排序：按优先级和用户需求
    eligible.sort((a, b) {
      final scoreA = _calculateRecommendationScore(a, user, usage);
      final scoreB = _calculateRecommendationScore(b, user, usage);
      return scoreB.compareTo(scoreA);
    });

    final feature = eligible.first;

    return FeatureRecommendation(
      feature: feature,
      reason: _generateReason(feature, user, usage),
      confidence: _calculateConfidence(feature, user, usage),
    );
  }

  double _calculateRecommendationScore(
    Feature feature,
    UserProfile user,
    AppUsageData usage,
  ) {
    double score = 0;

    // 用户能力匹配度 (40%)
    final capabilityMatch = _getCapabilityMatch(feature, user);
    score += capabilityMatch * 0.4;

    // 使用场景匹配度 (30%)
    final usageMatch = _getUsageMatch(feature, usage);
    score += usageMatch * 0.3;

    // 功能重要性 (20%)
    score += feature.importance * 0.2;

    // 用户兴趣度 (10%)
    final interest = _getUserInterest(feature, user);
    score += interest * 0.1;

    return score;
  }

  String _generateReason(
    Feature feature,
    UserProfile user,
    AppUsageData usage,
  ) {
    // 基于数据生成个性化理由
    if (feature.id == 'category_management') {
      return '你已经记了${usage.transactionCount}笔，可以用分类更好地管理';
    }
    if (feature.id == 'budget_by_category') {
      return '你经常超支，分类预算可以帮你控制';
    }
    // ... 更多个性化理由
    return feature.defaultReason;
  }
}
```

### 3. 推荐展示流程

```dart
class FeatureRecommendationDialog extends StatelessWidget {
  final FeatureRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            Icon(
              recommendation.feature.icon,
              size: 100,
              color: Colors.blue,
            ),
            SizedBox(height: 24),

            // 标题
            Text(
              '发现新功能！',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // 功能名称
            Text(
              recommendation.feature.name,
              style: TextStyle(fontSize: 28, color: Colors.blue),
            ),
            SizedBox(height: 16),

            // 推荐理由
            Text(
              recommendation.reason,
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),

            // 功能预览
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                recommendation.feature.description,
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
            ),
            SizedBox(height: 32),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 70,
                    child: OutlinedButton(
                      onPressed: () => _handleDefer(context),
                      child: Text('以后再说', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 70,
                    child: ElevatedButton(
                      onPressed: () => _handleUnlock(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text(
                        '解锁',
                        style: TextStyle(fontSize: 28, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 查看更多
            TextButton(
              onPressed: () => _openFeatureShelf(context),
              child: Text('查看所有功能', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 4. 功能货架页面

```dart
class FeatureShelfPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final features = ref.watch(allFeaturesProvider);

    final unlocked = features.where((f) => f.isUnlocked).toList();
    final recommended = features.where((f) => f.isRecommended).toList();
    final locked = features.where((f) => f.isLocked).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('功能货架', style: TextStyle(fontSize: 32)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 已解锁
          _buildSection(
            '已解锁 (${unlocked.length})',
            unlocked,
            Colors.green,
          ),

          SizedBox(height: 24),

          // 推荐解锁
          if (recommended.isNotEmpty) ...[
            _buildSection(
              '推荐解锁 (${recommended.length}) 🌟',
              recommended,
              Colors.orange,
            ),
            SizedBox(height: 24),
          ],

          // 未解锁
          _buildSection(
            '未解锁 (${locked.length})',
            locked,
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Feature> features, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 16),
        ...features.map((f) => _buildFeatureCard(f)),
      ],
    );
  }

  Widget _buildFeatureCard(Feature feature) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Icon(
          feature.icon,
          size: 48,
          color: feature.isUnlocked ? Colors.green : Colors.grey,
        ),
        title: Text(
          feature.name,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text(feature.description, style: TextStyle(fontSize: 16)),
            if (!feature.isUnlocked) ...[
              SizedBox(height: 8),
              _buildUnlockProgress(feature),
            ],
          ],
        ),
        trailing: _buildActionButton(feature),
      ),
    );
  }

  Widget _buildUnlockProgress(Feature feature) {
    final progress = feature.getProgress();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation(Colors.blue),
        ),
        SizedBox(height: 4),
        Text(
          feature.getProgressDescription(),
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildActionButton(Feature feature) {
    if (feature.isUnlocked) {
      return ElevatedButton(
        onPressed: () => _openFeature(feature),
        child: Text('使用', style: TextStyle(fontSize: 18)),
      );
    }

    if (feature.isRecommended) {
      return ElevatedButton(
        onPressed: () => _unlockFeature(feature),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: Text('解锁', style: TextStyle(fontSize: 18)),
      );
    }

    return ElevatedButton(
      onPressed: feature.canUnlock ? () => _unlockFeature(feature) : null,
      child: Text('🔒', style: TextStyle(fontSize: 24)),
    );
  }
}
```

## 自适应节奏

### 不同用户的解锁速度

```dart
class AdaptiveUnlockPacing {
  // 根据用户能力调整推荐频率
  Duration getRecommendationInterval(UserCapabilityLevel level) {
    switch (level) {
      case UserCapabilityLevel.basic:
        return Duration(days: 14); // 2周推荐一次
      case UserCapabilityLevel.intermediate:
        return Duration(days: 7);  // 1周推荐一次
      case UserCapabilityLevel.advanced:
        return Duration(days: 3);  // 3天推荐一次
    }
  }

  // 根据用户能力调整解锁条件
  UnlockCondition adjustCondition(
    UnlockCondition base,
    UserCapabilityLevel level,
  ) {
    switch (level) {
      case UserCapabilityLevel.basic:
        // 基础用户：条件更严格，确保真的准备好了
        return base.multiply(1.5);
      case UserCapabilityLevel.intermediate:
        // 普通用户：标准条件
        return base;
      case UserCapabilityLevel.advanced:
        // 高级用户：条件放宽，快速解锁
        return base.multiply(0.5);
    }
  }
}
```

### 解锁时间线示例

**基础用户（IQ 60-80）：**
```
第1天：简易模式（花钱/收钱/查看）
第14天：解锁"查看历史"
第30天：解锁"简单统计"
第60天：解锁"预算设置"
最终：3-4个功能
```

**普通用户（IQ 90-110）：**
```
第1天：简易模式
第7天：解锁"查看历史" + "简单统计"
第14天：解锁"预算设置" + "分类管理"
第30天：解锁"账户管理" + "月度统计"
第60天：解锁"趋势分析" + "目标设置"
最终：8-10个功能
```

**高级用户（IQ 120+）：**
```
第1天：简易模式
第3天：解锁"查看历史" + "简单统计" + "预算设置"
第7天：解锁"分类管理" + "账户管理" + "月度统计"
第14天：解锁"趋势分析" + "目标设置" + "智能建议"
第30天：解锁所有功能
最终：完整功能集
```

## 对比分析

### 纯自动 vs 纯手动 vs 混合

| 维度 | 纯自动 | 纯手动 | 混合（推荐） |
|------|--------|--------|-------------|
| 用户控制感 | ❌ 低 | ✅ 高 | ✅ 高 |
| 学习曲线 | ✅ 平缓 | ❌ 陡峭 | ✅ 平缓 |
| 适应性 | ❌ 差 | ✅ 好 | ✅ 很好 |
| 基础用户友好 | ✅ 是 | ❌ 否 | ✅ 是 |
| 高级用户友好 | ❌ 否 | ✅ 是 | ✅ 是 |
| 实现复杂度 | ✅ 低 | ✅ 低 | ⚠️ 高 |
| 用户满意度 | 6/10 | 7/10 | 9/10 |

### 推荐方案：混合解锁

**为什么混合最好？**

1. **尊重用户自主权** - 用户可以接受或拒绝推荐
2. **提供智能引导** - 系统分析并推荐合适功能
3. **适应不同用户** - 自动调整节奏和难度
4. **避免overwhelm** - 不会一次性解锁太多
5. **鼓励探索** - 功能货架激发好奇心

## 其他创新想法

### 想法1：成就系统

**游戏化解锁：**
```
🏆 记账新手
   记录10笔交易
   奖励：解锁"查看历史"

🏆 坚持记账
   连续7天记账
   奖励：解锁"简单统计"

🏆 预算达人
   连续3个月不超支
   奖励：解锁"趋势分析"
```

### 想法2：导师模式

**为基础用户提供虚拟导师：**
```
[导师头像]
"你已经用了一周了，要不要试试查看历史记录？"

[是的] [不用]

↓ 如果选"是的"

[导师演示]
"点这里可以看到所有记录"
[动画演示]

[解锁功能]
```

### 想法3：家庭模式

**家人可以帮助配置：**
```
[设置]
[家庭成员管理]

添加家人 → 扫码绑定

家人可以：
- 帮助解锁功能
- 配置复杂设置
- 查看使用情况
- 远程协助
```

### 想法4：智能降级

**如果用户用不好，自动降级：**
```
检测到：
- 错误率持续升高
- 功能使用率低
- 频繁求助

系统建议：
"这个功能好像有点复杂，要不要先关闭？"

[关闭] [继续使用]
```

## 实现优先级

### 第1阶段（MVP）
- [ ] 用户能力分析系统
- [ ] 基础功能分级（Level 0-2）
- [ ] 简单的自动解锁
- [ ] 功能货架基础UI

### 第2阶段（核心）
- [ ] 混合解锁机制
- [ ] 推荐算法
- [ ] 自适应节奏
- [ ] 解锁动画和反馈

### 第3阶段（优化）
- [ ] 成就系统
- [ ] 导师模式
- [ ] 家庭模式
- [ ] 智能降级

### 第4阶段（高级）
- [ ] 机器学习优化
- [ ] A/B测试
- [ ] 个性化推荐
- [ ] 社交功能

## 成功指标

### 定量指标
- 功能解锁率 > 60%
- 解锁后使用率 > 70%
- 用户留存率 > 80%
- 不同IQ用户满意度 > 8/10

### 定性指标
- 基础用户："不会overwhelm"
- 普通用户："刚好合适"
- 高级用户："解锁够快"

## 总结

**推荐方案：混合解锁系统**

**核心机制：**
1. ✅ 系统智能推荐（分析用户能力和需求）
2. ✅ 用户确认解锁（尊重用户自主权）
3. ✅ 手动探索货架（满足好奇心）
4. ✅ 自适应节奏（不同用户不同速度）

**关键优势：**
- 适应所有IQ水平的用户
- 平衡引导和自主
- 避免功能overwhelm
- 鼓励持续学习
- 提供成就感

**这是最佳方案，兼顾了易用性、灵活性和可扩展性。**
