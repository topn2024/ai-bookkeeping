# 变更：完成语音意图执行层映射

> **变更ID**: complete-voice-intent-execution-mapping
> **类型**: 功能完善
> **状态**: 草案
> **日期**: 2026-01-18

## 为什么

当前语音系统存在严重的意图识别与执行层不匹配问题：

### 问题1：执行器实现不完整
**现象**：用户语音操作报"操作失败，请重试"
**根因**：
1. ✅ **已修复**：`BookkeepingOperationAdapter` 的数据库操作是 TODO 占位符，没有实际调用 `DatabaseService`
2. ✅ **已修复** (2026-01-19)：deferred优先级操作的时序问题导致ExecutionResult丢失
   - **问题**：deferred优先级的操作不会立即执行，而是等待1.5秒聚合窗口或队列满。如果在此期间调用`generateResponse()`，results列表为空
   - **修复**：在`DualChannelProcessor.process()`中添加`await executionChannel.flush()`，确保所有操作（包括deferred）都执行完成后再生成响应
   - **影响文件**：`lib/services/voice/intelligence_engine/dual_channel_processor.dart`
3. ❌ **待修复**：10类高级功能意图已定义但完全没有执行器：
   - `screenRecognition` - 屏幕识别记账
   - `automateAlipaySync` - 支付宝账单同步
   - `automateWeChatSync` - 微信账单同步
   - `moneyAgeOperation` - 钱龄操作
   - `habitOperation` - 习惯操作
   - `vaultOperation` - 小金库操作
   - `dataOperation` - 数据操作
   - `shareOperation` - 分享操作
   - `systemOperation` - 系统操作
   - 大部分配置项（只实现了4个：budget/account/reminder/theme）

### 问题2：三层意图类型系统映射复杂
系统采用了三层意图类型：
- **VoiceIntentType** (21种) - 面向用户的意图
- **OperationType** (6种) - 面向智能引擎的操作
- **Action ID** (12种已实现) - 面向执行层的行为

这导致：
- 映射关系复杂，容易出现不匹配
- 新增意图时需要在三个地方同步修改
- 维护成本高，容易遗漏

### 问题3：配置操作覆盖不足
用户提到有"上百个配置项"，但目前只实现了4个配置Action：
- config.budget (预算设置)
- config.account (账户设置)
- config.reminder (提醒设置)
- config.theme (主题设置)

其他配置项（分类、标签、账本、成员等）都无法通过语音操作。

### 影响
- 用户体验差：很多语音指令无法执行
- 功能不完整：高级功能无法使用
- 维护困难：意图和执行器容易不同步

## 变更内容

### 阶段1：修复核心执行器（高优先级）

#### 1.1 完善 BookkeepingOperationAdapter
- ✅ **已完成**：实现 `_addTransaction` 调用 `DatabaseService.insertTransaction()`
- ✅ **已完成**：实现 `_query` 调用 `DatabaseService.getTransactions()`
- ✅ **已完成**：实现 `_delete` 调用 `DatabaseService.deleteTransaction()`
- ✅ **已完成**：实现 `_modify` 调用 `DatabaseService.updateTransaction()`
- ⚠️ **待完善**：`_navigate` 仍是 TODO，需要实际调用 `VoiceNavigationService`

#### 1.2 补充配置操作执行器
新增以下 Action 到 ActionRouter：
- `config.category` - 分类管理（添加/修改/删除分类）
- `config.tag` - 标签管理
- `config.ledger` - 账本管理
- `config.member` - 成员管理（家庭账本）
- `config.creditCard` - 信用卡管理
- `config.savingsGoal` - 储蓄目标管理
- `config.recurringTransaction` - 定期交易管理

### 阶段2：实现高级功能执行器（中优先级）

#### 2.1 小金库操作
新增 `VaultOperationAction`：
- 创建小金库
- 查询小金库余额
- 小金库转账
- 小金库预算设置

#### 2.2 钱龄操作
新增 `MoneyAgeOperationAction`：
- 查询钱龄健康度
- 设置钱龄提醒
- 查看钱龄报告

#### 2.3 数据操作
新增 `DataOperationAction`：
- 导出数据
- 备份数据
- 数据统计

### 阶段3：实现自动化功能（低优先级）

#### 3.1 屏幕识别记账
新增 `ScreenRecognitionAction`：
- 调用 OCR 服务识别屏幕内容
- 解析账单信息
- 自动创建交易记录

#### 3.2 账单同步
新增 `BillSyncAction`：
- 支付宝账单同步
- 微信账单同步
- 银行账单同步

### 阶段4：简化意图类型系统（架构优化）

#### 4.1 统一意图类型
- 将 VoiceIntentType 和 OperationType 合并
- 使用统一的 IntentType 枚举
- 简化映射关系

#### 4.2 自动注册机制
- 实现 Action 自动发现和注册
- 使用注解标记 Action 类
- 减少手动注册代码

## 实施优先级

### P0（立即修复）
- ✅ 修复 BookkeepingOperationAdapter 的数据库操作（已完成）

### P1（本周完成）
- 补充配置操作执行器（7个配置Action）
- 完善导航操作实现

### P2（下周完成）
- 实现小金库操作
- 实现钱龄操作
- 实现数据操作

### P3（后续迭代）
- 实现屏幕识别记账
- 实现账单同步
- 简化意图类型系统

## 影响

### 受影响文件

#### 修改文件
- `app/lib/services/voice/adapters/bookkeeping_operation_adapter.dart`
  - ✅ 已修复数据库操作
  - ⚠️ 待完善导航操作

#### 新增文件
- `app/lib/services/voice/agent/actions/config_actions.dart` - 配置操作集合
- `app/lib/services/voice/agent/actions/vault_actions.dart` - 小金库操作
- `app/lib/services/voice/agent/actions/money_age_actions.dart` - 钱龄操作
- `app/lib/services/voice/agent/actions/data_actions.dart` - 数据操作
- `app/lib/services/voice/agent/actions/automation_actions.dart` - 自动化操作

### 依赖关系
- **前置依赖**：无（独立变更）
- **并行开发**：可与 `upgrade-voice-intelligence-engine` 并行
- **后续影响**：为语音功能完整性奠定基础

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 配置操作过多导致维护困难 | 中 | 使用统一的配置操作基类 |
| 自动化功能依赖外部服务 | 高 | 先实现本地功能，外部服务后续集成 |
| 意图类型重构影响现有代码 | 高 | 分阶段实施，保持向后兼容 |
| 新增Action导致注册代码膨胀 | 低 | 实现自动注册机制 |

## 验收标准

### 功能验收

#### 阶段1
- ✅ 用户说"记一笔50元的午餐"，成功创建交易记录
- ✅ 用户说"查询我的账单"，返回正确的统计数据
- ✅ 用户说"删除最后一笔交易"，成功删除记录
- ⚠️ 用户说"打开预算页面"，成功导航到预算页面

#### 阶段2
- 用户说"添加一个餐饮分类"，成功创建分类
- 用户说"设置信用卡还款日"，成功设置提醒
- 用户说"查询小金库余额"，返回正确余额
- 用户说"查看钱龄健康度"，返回钱龄报告

#### 阶段3
- 用户说"识别屏幕上的账单"，成功识别并创建记录
- 用户说"同步支付宝账单"，成功导入账单

### 性能验收
- 配置操作响应时间 < 500ms
- 数据操作响应时间 < 1s
- 自动化操作响应时间 < 3s

### 兼容性验收
- 现有语音功能不受影响
- 新增功能不破坏现有意图识别

## 实施计划

详见 [tasks.md](./tasks.md)

## 相关文档

- [语音智能引擎升级](../upgrade-voice-intelligence-engine/proposal.md) - 并行开发
- [多意图处理](../multi-intent-voice-processing/proposal.md) - 相关功能
