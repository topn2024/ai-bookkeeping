# 规范：预算建议引擎

## 新增需求

### 需求：统一预算建议模型

系统**必须**提供一个统一的 `BudgetSuggestion` 数据模型，替代各服务的独立模型。

#### 场景：创建预算建议

**Given** 分析用户消费数据
**When** 生成预算建议
**Then** 建议应包含：categoryId, suggestedAmount, reason, source, confidence
**And** source 应标识建议来源（adaptive/smart/localized/location）

---

### 需求：预算建议策略接口

系统**必须**定义统一的 `BudgetSuggestionStrategy` 策略接口，所有预算服务**必须**实现此接口。

#### 场景：自适应策略生成建议

**Given** 用户有 3 个月消费历史
**When** 调用 `AdaptiveBudgetStrategy.getSuggestions()`
**Then** 应基于历史趋势生成建议
**And** confidence 应反映数据充分度

#### 场景：位置感知策略生成建议

**Given** 用户在商场附近
**When** 调用 `LocationBudgetStrategy.getSuggestions()`
**Then** 应考虑位置因素调整建议
**And** metadata 应包含位置信息

---

### 需求：预算建议引擎组合服务

系统**必须**提供 `BudgetSuggestionEngine` 组合服务，聚合和合并多个策略的建议结果。

#### 场景：聚合多策略建议

**Given** 配置了 adaptive 和 smart 两个策略
**When** 调用 `BudgetSuggestionEngine.getSuggestions()`
**Then** 应并行执行所有策略
**And** 应合并同一分类的建议（选择置信度最高的）

#### 场景：策略执行失败降级

**Given** location 策略因无权限失败
**When** 调用引擎获取建议
**Then** 应忽略失败的策略
**And** 应返回其他策略的结果

---

## 技术约束

- 模型位于 `lib/services/budget/budget_suggestion.dart`
- 引擎位于 `lib/services/budget/budget_suggestion_engine.dart`
- 策略位于 `lib/services/budget/strategies/`
- 现有服务保留公共 API 以向后兼容
