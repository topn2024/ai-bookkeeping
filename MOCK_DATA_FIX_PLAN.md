# 假数据修复计划

## 概述
发现8个页面使用假数据，需要逐个修复以连接真实数据源。

## 修复批次

### Batch 1: family_savings_goal_page.dart ✅ 优先级：高 | 难度：低
**问题**: 使用硬编码的家庭储蓄目标数据
**修复方案**:
- 删除本地模型定义（FamilySavingsGoal, MemberContribution, SavingsRecord）
- 导入 `../models/family_savings_goal.dart`
- 导入 `../providers/family_goal_provider.dart`
- 使用 `ref.watch(familyGoalListProvider)` 获取目标列表
- 使用 `ref.watch(goalContributionsProvider(goalId))` 获取贡献记录
- 删除 `_initMockData()` 方法
- 调整 UI 以适配真实数据结构（contributors vs contributions）

**预计工作量**: 30分钟
**依赖**: 无

---

### Batch 2: family_leaderboard_page.dart ✅ 优先级：高 | 难度：低
**问题**: 使用硬编码的家庭成员排行榜数据
**修复方案**:
- 导入 `../providers/member_statistics_provider.dart`
- 使用 `ref.watch(memberSpendingRankProvider)` 获取排名数据
- 使用 `ref.watch(memberStatisticsProvider(memberId))` 获取成员统计
- 删除 `_initMockData()` 方法
- 调整徽章系统（如果后端不支持，暂时隐藏或使用本地计算）

**预计工作量**: 30分钟
**依赖**: 无

---

### Batch 3: family_simple_mode_page.dart ✅ 优先级：高 | 难度：低
**问题**: 使用硬编码的家庭成员支出数据
**修复方案**:
- 导入 `../providers/member_statistics_provider.dart`
- 导入 `../providers/transaction_provider.dart`
- 使用 `ref.watch(memberStatisticsProvider)` 获取成员支出
- 使用 `ref.watch(transactionProvider)` 获取交易记录
- 按账本过滤数据
- 删除 `_initMockData()` 方法

**预计工作量**: 30分钟
**依赖**: 无

---

### Batch 4: money_age_page.dart ✅ 优先级：最高 | 难度：中
**问题**: 使用硬编码的钱龄统计数据
**修复方案**:
- 创建 `money_age_provider.dart`
- 连接后端 Money Age API (`server/app/schemas/money_age.py`)
- 使用 `ref.watch(moneyAgeProvider)` 获取当前钱龄
- 使用 `ref.watch(moneyAgeHistoryProvider)` 获取历史趋势
- 删除 `_getMockStatistics()` 方法
- 调整 MoneyAgeStatistics 模型以匹配后端数据

**预计工作量**: 1小时
**依赖**: 需要确认后端 API 是否可用

---

### Batch 5: receipt_detail_page.dart ⚠️ 优先级：高 | 难度：中
**问题**: 使用硬编码的小票商品数据
**修复方案**:
- 确认 OCR 服务是否已实现
- 如果已实现：集成 OCR 服务，从相机/上传流程传递真实数据
- 如果未实现：保留假数据但添加 TODO 注释，标记为待实现功能
- 调整数据流：Camera → OCR → ReceiptData → ReceiptDetailPage

**预计工作量**: 1-2小时（取决于 OCR 服务状态）
**依赖**: OCR 服务实现状态

---

### Batch 6: actionable_advice_page.dart ⚠️ 优先级：中 | 难度：高
**问题**: 使用硬编码的建议列表
**修复方案**:
- 创建 `advice_service.dart` 分析用户数据
- 基于以下数据生成建议：
  - 预算状态（budget_provider.dart）
  - 钱龄趋势（money_age_provider.dart）
  - 消费模式（transaction_provider.dart）
- 创建 `actionable_advice_provider.dart`
- 删除 `_initMockData()` 方法
- 实现建议生成逻辑

**预计工作量**: 2-3小时
**依赖**: money_age_provider 完成

---

### Batch 7: smart_feature_recommendation_page.dart ⚠️ 优先级：低 | 难度：高
**问题**: 使用硬编码的功能推荐
**修复方案**:
- 创建 `feature_recommendation_service.dart`
- 跟踪用户行为（使用天数、功能使用情况）
- 基于使用模式生成推荐
- 存储在用户偏好设置中
- 删除 `_initMockData()` 方法

**预计工作量**: 2-3小时
**依赖**: 用户行为跟踪系统

---

### Batch 8: upgrade_vote_page.dart ⚠️ 优先级：低 | 难度：中
**问题**: 使用硬编码的投票数据
**修复方案**:
- 创建 `upgrade_vote_service.dart`
- 实现投票机制（存储、统计）
- 使用 `member_provider.dart` 获取成员列表
- 实现实时投票状态更新
- 删除 `_initMockData()` 方法

**预计工作量**: 1-2小时
**依赖**: 投票数据库表设计

---

## 执行顺序

### 第一阶段（今天）- 快速修复
1. ✅ Batch 1: family_savings_goal_page
2. ✅ Batch 2: family_leaderboard_page
3. ✅ Batch 3: family_simple_mode_page

**预计时间**: 1.5小时
**收益**: 修复3个家庭功能页面，provider已存在

### 第二阶段（明天）- 核心功能
4. ⚠️ Batch 4: money_age_page
5. ⚠️ Batch 5: receipt_detail_page

**预计时间**: 2-3小时
**收益**: 修复最重要的核心功能

### 第三阶段（后续）- 智能功能
6. ⚠️ Batch 6: actionable_advice_page
7. ⚠️ Batch 7: smart_feature_recommendation_page
8. ⚠️ Batch 8: upgrade_vote_page

**预计时间**: 5-8小时
**收益**: 完善智能功能和辅助功能

---

## 提交策略

每个批次独立提交：
```
feat: 移除 [页面名称] 的假数据，连接真实数据源

- 删除硬编码的模拟数据
- 使用 [provider名称] 获取真实数据
- 调整 UI 以适配真实数据结构
- [其他具体修改]

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## 风险评估

### 高风险
- **money_age_page**: 需要确认后端 API 可用性
- **receipt_detail_page**: 依赖 OCR 服务实现
- **actionable_advice_page**: 需要实现复杂的分析逻辑

### 中风险
- **family功能页面**: Provider已存在，但需要测试数据完整性

### 低风险
- **upgrade_vote_page**: 功能使用频率低，影响范围小

---

## 测试检查清单

每个批次修复后需要验证：
- [ ] 页面能正常加载
- [ ] 数据正确显示
- [ ] 无假数据残留
- [ ] 交互功能正常
- [ ] 错误处理完善
- [ ] 空状态处理
- [ ] 加载状态显示

---

## 当前状态

- **计划创建时间**: 2026-01-10
- **当前批次**: Batch 1 准备开始
- **已完成**: 0/8
- **进行中**: 0/8
- **待处理**: 8/8
