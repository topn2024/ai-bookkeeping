# 移除传统预算系统 - 执行计划

## 提案状态

✅ **提案已创建并验证通过**

- 提案编号：`remove-traditional-budget`
- 验证状态：通过 `openspec-cn validate --strict`
- 任务总数：87个任务
- 预计时间：3-4个工作日

---

## 需要删除的文件清单

### 模型文件（1个）
- `app/lib/models/budget.dart` - Budget 模型

### Provider 文件（3个）
- `app/lib/providers/budget_provider.dart`
- `app/lib/providers/zero_based_budget_provider.dart`
- `app/lib/providers/budget_alert_provider.dart`

### Repository 文件（2个）
- `app/lib/repositories/impl/budget_repository.dart`
- `app/lib/repositories/contracts/i_budget_repository.dart`

### Service 文件（10+个）
- `app/lib/services/adaptive_budget_service.dart`
- `app/lib/services/budget_money_age_integration.dart`
- `app/lib/services/budget_habit_integration.dart`
- `app/lib/services/budget_carryover_service.dart`
- `app/lib/services/budget_alert_service.dart`
- `app/lib/services/budget_planning_coordinator.dart`
- `app/lib/services/contracts/i_budget_service.dart`
- `app/lib/services/learning/budget_collaborative_learning_service.dart`
- `app/lib/services/learning/personalized_budget_learning_service.dart`
- 其他预算相关的 Service

### 页面文件（10+个）
- `app/lib/pages/member_budget_page.dart`
- `app/lib/pages/budget_management_page.dart`
- `app/lib/pages/localized_budget_page.dart`
- `app/lib/pages/money_age_budget_page.dart`
- `app/lib/pages/budget_health_page.dart`
- `app/lib/pages/zero_based_budget_page.dart`
- `app/lib/pages/budget_center_page.dart`
- `app/lib/pages/budget_carryover_settings_page.dart`
- `app/lib/pages/voice_budget_page.dart`
- `app/lib/pages/learning_budget_suggestion_page.dart`
- `app/lib/pages/budget_money_age_page.dart`
- `app/lib/pages/reports/budget_report_page.dart`

### 需要修改的文件（14个）
- `app/lib/core/contracts/i_database_service.dart`
- `app/lib/providers/family_report_provider.dart`
- `app/lib/pages/money_age_page.dart`
- `app/lib/services/database_service.dart`
- `app/lib/services/data_mapper_service.dart`
- `app/lib/services/backup_export_service.dart`
- `app/lib/services/family_dashboard_service.dart`
- `app/lib/services/advice_service.dart`
- `app/lib/services/family_report_service.dart`
- `app/lib/pages/home_page.dart`
- 其他引用 Budget 的文件

---

## 保留的文件（小金库系统）

### 模型
- ✅ `app/lib/models/budget_vault.dart` - 小金库模型

### Provider
- ✅ `app/lib/providers/budget_vault_provider.dart`

### Service
- ✅ `app/lib/services/vault_repository.dart`
- ✅ 所有小金库相关的 Service

### 页面
- ✅ 所有小金库相关的页面（vault_*）

---

## 执行步骤

### 第1步：备份数据库
```bash
cp app/ai_bookkeeping.db app/ai_bookkeeping.db.backup
```

### 第2步：删除模型和数据表
- 删除 `app/lib/models/budget.dart`
- 在数据库迁移中删除 `budgets` 表

### 第3步：删除 Provider 和 Repository
- 删除所有传统预算相关的 Provider
- 删除所有传统预算相关的 Repository

### 第4步：删除 Service
- 删除所有传统预算相关的 Service

### 第5步：删除页面
- 删除所有传统预算相关的页面

### 第6步：更新引用
- 更新所有引用 Budget 的文件
- 移除传统预算相关的导入

### 第7步：测试验证
- 运行 `flutter analyze`
- 测试小金库功能
- 测试首页显示

---

## 风险提示

### ⚠️ 重要提示

1. **数据丢失风险**：虽然当前用户数据为空，但删除操作不可逆
2. **编译错误风险**：删除后可能出现大量编译错误，需要逐一修复
3. **功能缺失风险**：需要确保小金库系统能完全替代传统预算

### ✅ 缓解措施

1. **完整备份**：删除前备份所有代码和数据库
2. **分步执行**：按阶段执行，每步验证
3. **充分测试**：删除后进行全面测试

---

## 下一步行动

### 选项1：立即开始执行（推荐分步执行）

我可以开始执行删除操作，建议分阶段进行：
1. 先删除模型和数据表
2. 再删除 Provider 和 Service
3. 最后删除页面和更新引用

### 选项2：先创建功能分支

建议先创建一个功能分支，在分支上进行删除操作：
```bash
git checkout -b feature/remove-traditional-budget
```

### 选项3：手动执行

您也可以根据这个清单手动执行删除操作。

---

## 确认问题

在开始执行前，请确认：

1. ✅ 是否已经备份了代码和数据库？
2. ✅ 是否确认只保留小金库系统？
3. ✅ 是否准备好处理可能出现的编译错误？
4. ✅ 是否希望我开始执行删除操作？

---

**文档版本**: v1.0
**创建时间**: 2026-01-25
**状态**: 等待确认
