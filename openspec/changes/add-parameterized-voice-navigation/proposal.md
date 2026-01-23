# 变更：语音意图参数化与复合操作支持

> **变更ID**: add-parameterized-voice-navigation
> **类型**: 功能增强
> **状态**: 草案
> **日期**: 2026-01-23

## 为什么

当前语音导航系统基于固定别名匹配，存在以下核心问题：

### 问题1：无法处理带参数的导航

**现象**：用户说"查看餐饮类的账单"，系统无法识别并执行带分类筛选的导航。

**根因**：
1. `VoiceNavigationService` 仅支持静态别名匹配（如"分类统计"→`/statistics/category`）
2. `SmartIntentRecognizer` 的 LLM prompt 中导航参数只包含 `targetPage` 和 `route`，不支持 `category`、`timeRange` 等筛选参数
3. `VoiceNavigationExecutor._getPageForRoute()` 构造页面时不传递任何参数

**用户期望**：
- "查看餐饮类的账单" → 打开交易列表页，自动筛选餐饮分类
- "看看本周的交通消费" → 打开分类统计页，显示交通+本周数据
- "查看支付宝的支出" → 打开交易列表页，筛选支付宝来源

### 问题2：无法处理复合操作

**现象**：用户说"把今天的支出做个分类"，系统无法理解这需要先查询再分类的组合操作。

**根因**：
1. 当前意图识别一次只处理单一意图
2. 操作之间没有依赖传递机制
3. 无法表达"用前一个操作的结果作为后一个操作的输入"

**用户期望**：
- "把今天的支出做个分类" → 查询今天支出 + 进入分类编辑
- "统计本月餐饮花了多少，然后打开详情" → 统计查询 + 跳转详情页

### 影响

- 用户需要说两句话才能完成一个任务
- 语音导航不如直接点击界面方便
- 限制了语音助手的实用价值

## 变更内容

### 阶段1：参数化导航（核心功能）

#### 1.1 增强 LLM Prompt 支持参数提取
在 `SmartIntentRecognizer._buildMultiOperationLLMPrompt` 中添加导航参数提取指导：
- 支持提取 `category`（分类筛选）
- 支持提取 `timeRange`（时间范围：今天/本周/本月等）
- 支持提取 `source`（来源筛选：支付宝/微信等）
- 支持提取 `account`（账户筛选）

#### 1.2 修改导航适配器传递参数
修改 `BookkeepingOperationAdapter._navigate`：
- 从 params 中提取导航参数（category, timeRange, source, account）
- 将参数包装在 `navigationParams` 中返回

#### 1.3 修改导航执行器传递参数到页面
修改 `VoiceNavigationExecutor`：
- `navigateTo()` 方法签名改为接受可选参数
- `_getPageForRoute()` 根据参数构造带筛选条件的页面

#### 1.4 修改页面构造函数支持参数
修改关键页面以接受筛选参数：
- `TransactionListPage`：接受 categoryFilter, sourceFilter, timeRange
- `StatisticsCategoryPage`：接受 initialCategory, timeRange

### 阶段2：复合操作支持（增强功能）

#### 2.1 增强 LLM Prompt 支持多操作识别
添加复合操作识别示例：
- 识别操作序列
- 标记操作间的依赖关系（useQueryResult: true）

#### 2.2 实现操作结果传递
修改 `DualChannelProcessor`：
- 保存前一操作的执行结果
- 传递给依赖该结果的后续操作

## 影响

### 受影响规范
- voice-intent（新增参数化导航需求）

### 受影响代码

| 文件 | 修改内容 |
|------|---------|
| `lib/services/voice/smart_intent_recognizer.dart` | 增强LLM prompt，添加导航参数提取 |
| `lib/services/voice/adapters/bookkeeping_operation_adapter.dart` | 修改_navigate方法支持参数 |
| `lib/services/voice_navigation_executor.dart` | 修改navigateTo和页面构造 |
| `lib/pages/transaction_list_page.dart` | 添加构造函数参数支持 |
| `lib/pages/statistics/category_page.dart` | 添加构造函数参数支持（如存在） |

### 依赖关系
- **前置依赖**：无（基于现有架构增强）
- **并行开发**：可与 `complete-voice-intent-execution-mapping` 并行
- **后续影响**：为更复杂的语音交互奠定基础

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| LLM 参数提取准确率不高 | 中 | 添加规则后处理验证参数有效性 |
| 页面不支持动态参数 | 中 | 先实现核心页面，逐步扩展 |
| 复合操作增加系统复杂度 | 中 | 分阶段实施，第一阶段不做复合操作 |

## 验收标准

### 阶段1验收

#### 带分类的导航
- 用户说"查看餐饮类的账单"，打开交易列表页且自动筛选餐饮分类
- 用户说"看看本周的交通消费"，打开分类统计页显示交通+本周数据

#### 带来源的导航
- 用户说"查看支付宝的支出"，打开交易列表页且筛选支付宝来源

#### 带时间的导航
- 用户说"查看昨天的账单"，打开交易列表页且筛选昨天

### 阶段2验收（可选）

#### 复合操作
- 用户说"把今天的支出做个分类"，查询今天支出后进入分类编辑

## 实施计划

详见 [tasks.md](./tasks.md)

## 相关文档

- [完成语音意图执行映射](../complete-voice-intent-execution-mapping/proposal.md) - 相关功能
- [语音智能引擎升级](../upgrade-voice-intelligence-engine/proposal.md) - 并行开发
