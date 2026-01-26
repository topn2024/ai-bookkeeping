# 移除传统预算系统提案

## 提案信息

- **提案编号**: remove-traditional-budget
- **提案标题**: 移除传统预算系统，统一使用零基预算（小金库）
- **提案人**: Claude Code
- **创建日期**: 2026-01-25
- **状态**: 待审核

## 问题描述

### 当前问题

根据数据验证报告和代码分析，当前系统存在两套独立的预算系统：

1. **传统预算系统（Budget）**
   - 模型：`app/lib/models/budget.dart`
   - 数据表：`budgets`
   - Provider：`budgetProvider`
   - 功能：按分类设置预算上限，监控支出

2. **零基预算系统（BudgetVault）**
   - 模型：`app/lib/models/budget_vault.dart`
   - 数据表：`budget_vaults`
   - Provider：`budgetVaultProvider`
   - 功能：收入分配到小金库，支出从小金库扣减

**核心问题**：
- 两套系统功能重叠，造成用户困惑
- 维护成本高，代码冗余
- 用户数据显示：0个活跃预算，0个活跃小金库
- 零基预算（YNAB式）更符合现代记账理念

### 决策

**保留零基预算系统，移除传统预算系统**

**理由**：
1. **功能更强大**：零基预算包含了传统预算的所有功能，还提供了收入分配、小金库管理等高级功能
2. **用户体验更好**：零基预算让用户对每一分钱都有明确规划，更有掌控感
3. **简化系统**：只保留一套预算系统，降低维护成本
4. **无数据迁移风险**：当前用户数据为空，可以直接删除

## 解决方案

### 设计目标

1. **完全移除传统预算**：删除所有相关代码和数据表
2. **保留零基预算**：保持现有功能不变
3. **简化用户体验**：统一为"小金库"入口
4. **清理冗余代码**：删除所有传统预算相关的代码

### 核心设计

#### 1. 删除的内容

**模型和数据**：
- `app/lib/models/budget.dart` - Budget 模型
- `budgets` 数据表
- `budget_carryovers` 数据表（预算结转记录）
- `zero_based_allocations` 数据表（如果存在）

**Provider 和 Service**：
- `app/lib/providers/budget_provider.dart`
- `app/lib/services/smart_budget_service.dart`
- `app/lib/services/adaptive_budget_service.dart`
- `app/lib/services/budget_carryover_service.dart`
- 其他传统预算相关的 Service

**UI 页面**：
- `app/lib/pages/budget_management_page.dart`
- `app/lib/pages/budget_center_page.dart`
- `app/lib/pages/zero_based_budget_page.dart`（如果是传统预算相关）
- 其他传统预算相关的页面

**Widget 组件**：
- `app/lib/widgets/budget_status_bar.dart`（如果只用于传统预算）
- 其他传统预算相关的组件

#### 2. 保留的内容

**零基预算系统**：
- `app/lib/models/budget_vault.dart` - 小金库模型
- `budget_vaults` 数据表
- `app/lib/providers/budget_vault_provider.dart`
- `app/lib/services/vault_repository.dart`
- 所有小金库相关的页面和组件

#### 3. 需要更新的内容

**首页**：
- 移除传统预算摘要
- 只显示小金库摘要
- 更新预算入口为"小金库"

**导航和菜单**：
- 移除"预算管理"入口
- 保留"小金库"入口
- 更新所有相关链接

**语音助手**：
- 移除传统预算相关的语音命令
- 保留小金库相关的语音命令

**报表系统**：
- 移除传统预算相关的报表
- 保留小金库相关的报表

### 实施计划

#### 阶段1：数据层清理（0.5天）

1. **删除数据表**
   - [ ] 删除 `budgets` 表
   - [ ] 删除 `budget_carryovers` 表
   - [ ] 删除 `zero_based_allocations` 表（如果存在）
   - [ ] 更新数据库版本

2. **删除模型**
   - [ ] 删除 `app/lib/models/budget.dart`
   - [ ] 删除相关的枚举和类型定义

#### 阶段2：业务层清理（1天）

1. **删除 Provider**
   - [ ] 删除 `app/lib/providers/budget_provider.dart`
   - [ ] 删除 `app/lib/providers/zero_based_budget_provider.dart`（如果是传统预算相关）
   - [ ] 更新 Provider 注册

2. **删除 Service**
   - [ ] 删除 `app/lib/services/smart_budget_service.dart`
   - [ ] 删除 `app/lib/services/adaptive_budget_service.dart`
   - [ ] 删除 `app/lib/services/budget_carryover_service.dart`
   - [ ] 删除其他传统预算相关的 Service

3. **更新依赖**
   - [ ] 更新所有引用传统预算的代码
   - [ ] 移除传统预算相关的导入

#### 阶段3：UI层清理（1天）

1. **删除页面**
   - [ ] 删除 `app/lib/pages/budget_management_page.dart`
   - [ ] 删除 `app/lib/pages/budget_center_page.dart`
   - [ ] 删除 `app/lib/pages/zero_based_budget_page.dart`（如果是传统预算相关）
   - [ ] 删除其他传统预算相关的页面

2. **删除组件**
   - [ ] 删除传统预算相关的 Widget
   - [ ] 删除传统预算相关的对话框

3. **更新首页**
   - [ ] 移除传统预算摘要卡片
   - [ ] 更新预算入口为"小金库"
   - [ ] 更新导航链接

4. **更新导航**
   - [ ] 移除"预算管理"菜单项
   - [ ] 更新所有相关链接
   - [ ] 更新路由配置

#### 阶段4：功能清理（0.5天）

1. **更新语音助手**
   - [ ] 移除传统预算相关的语音命令
   - [ ] 更新语音命令列表
   - [ ] 测试语音功能

2. **更新报表系统**
   - [ ] 移除传统预算相关的报表
   - [ ] 更新报表页面
   - [ ] 测试报表功能

3. **更新设置页面**
   - [ ] 移除传统预算相关的设置
   - [ ] 更新设置页面

#### 阶段5：测试与验证（0.5天）

1. **功能测试**
   - [ ] 测试小金库功能正常
   - [ ] 测试首页显示正常
   - [ ] 测试导航正常
   - [ ] 测试语音助手正常

2. **代码清理**
   - [ ] 运行 `flutter analyze` 检查错误
   - [ ] 删除未使用的导入
   - [ ] 删除未使用的变量

3. **文档更新**
   - [ ] 更新用户文档
   - [ ] 更新开发文档
   - [ ] 编写 Release Notes

### 风险评估

#### 低风险

1. **数据丢失**
   - **风险**: 删除 budgets 表导致数据丢失
   - **缓解**: 当前用户数据为空（0个预算）
   - **应对**: 数据库备份

2. **功能缺失**
   - **风险**: 用户需要传统预算功能
   - **缓解**: 零基预算包含传统预算的所有功能
   - **应对**: 提供迁移指南

3. **代码引用错误**
   - **风险**: 删除代码后出现编译错误
   - **缓解**: 充分的测试和检查
   - **应对**: 逐步删除，每步验证

### 成功指标

1. **技术指标**
   - 代码行数减少 > 2000 行
   - 编译无错误无警告
   - 所有测试通过

2. **用户指标**
   - 小金库功能正常使用
   - 用户体验更简洁
   - 无功能缺失反馈

3. **维护指标**
   - 维护成本降低 50%
   - 代码复杂度降低
   - 新功能开发更快

## 替代方案

### 方案1：保留传统预算

**优点**:
- 满足不同用户需求
- 无需删除代码

**缺点**:
- 维护成本高
- 用户困惑
- 代码冗余

**结论**: 不推荐

### 方案2：统一预算系统

**优点**:
- 支持两种模式
- 保留灵活性

**缺点**:
- 开发工作量大
- 系统复杂度高

**结论**: 不推荐（用户已明确只要零基预算）

## 依赖关系

### 前置依赖

- 无（当前用户数据为空）

### 后续依赖

- 无（删除操作不影响其他功能）

## 参考资料

1. **数据验证报告**: DATA_VERIFICATION_REPORT.md
2. **当前代码**:
   - `app/lib/models/budget.dart`
   - `app/lib/models/budget_vault.dart`
   - `app/lib/providers/budget_provider.dart`
   - `app/lib/providers/budget_vault_provider.dart`

## 审批流程

1. **技术审查**: 确认删除范围
2. **产品审查**: 确认功能不缺失
3. **最终批准**: 批准删除操作

---

**提案状态**: 待审核
**下一步**: 等待审批后开始删除
