# 双通道处理能力规范

> **能力ID**: dual-channel-processing
> **变更ID**: upgrade-voice-intelligence-engine
> **依赖**: multi-operation-recognition

## 新增需求

### 需求：ExecutionChannel 支持优先级队列管理

**优先级**: P0
**关联能力**: intelligent-aggregation

ExecutionChannel 必须实现优先级队列，确保不同优先级的操作按正确顺序执行。

#### 场景：immediate 操作立即执行

**前置条件**:
- ExecutionChannel 已初始化
- 队列中有 deferred 操作等待

**输入**: 导航操作（priority: immediate）

**预期行为**:
- immediate 操作插入队列头部
- 立即执行，不等待聚合窗口
- 执行时间 < 100ms
- deferred 操作继续等待

**验收标准**:
- immediate 操作优先级最高
- 不阻塞其他操作的聚合
- 执行延迟 P95 < 100ms

#### 场景：normal 操作快速执行

**前置条件**:
- ExecutionChannel 已初始化
- 队列中有 deferred 操作等待

**输入**: 查询操作（priority: normal）

**预期行为**:
- normal 操作优先于 deferred
- 在 1s 内执行完成
- 不进入聚合队列

**验收标准**:
- normal 操作优先级高于 deferred
- 执行延迟 P95 < 1s
- 不影响 immediate 操作

#### 场景：deferred 操作进入聚合队列

**前置条件**:
- ExecutionChannel 已初始化
- 无 immediate 或 normal 操作

**输入**: 记账操作（priority: deferred）

**预期行为**:
- 操作进入聚合队列
- 等待 1.5s 或触发条件
- 批量执行所有 deferred 操作

**验收标准**:
- deferred 操作正确聚合
- 聚合窗口 ≤ 1.5s
- 批量执行成功率 ≥ 95%

### 需求：ExecutionChannel 支持操作聚合

**优先级**: P0
**关联能力**: intelligent-aggregation

ExecutionChannel 必须支持 deferred 操作的智能聚合，提升批量操作效率。

#### 场景：1.5秒基础聚合窗口

**前置条件**:
- ExecutionChannel 已初始化
- 收到第一个 deferred 操作

**输入**: 连续3个记账操作（间隔 < 1.5s）

**预期行为**:
- 第一个操作启动 1.5s 计时器
- 后续操作加入聚合队列
- 1.5s 后批量执行所有操作

**验收标准**:
- 聚合窗口准确为 1.5s
- 所有操作批量执行
- 执行顺序与输入顺序一致

#### 场景：聚合队列满时提前执行

**前置条件**:
- ExecutionChannel 已初始化
- 聚合队列配置最大容量为 10

**输入**: 连续 10 个记账操作（间隔 < 1.5s）

**预期行为**:
- 前 9 个操作进入队列
- 第 10 个操作触发立即执行
- 不等待 1.5s 计时器

**验收标准**:
- 队列容量限制生效
- 提前执行不丢失操作
- 执行成功率 ≥ 95%

### 需求：ExecutionChannel 支持执行结果回调

**优先级**: P0
**关联能力**: 无

ExecutionChannel 必须通过回调机制将执行结果注入到 ConversationChannel。

#### 场景：单个操作执行成功

**前置条件**:
- ExecutionChannel 已初始化
- 注册了回调函数

**输入**: 记账操作（amount: 35, category: 交通）

**预期行为**:
- 执行操作
- 生成 ExecutionResult（success: true）
- 调用所有注册的回调函数
- 回调接收到正确的结果

**验收标准**:
- 回调函数被正确调用
- ExecutionResult 包含完整信息
- 回调执行不阻塞主流程

#### 场景：批量操作部分失败

**前置条件**:
- ExecutionChannel 已初始化
- 注册了回调函数

**输入**: 3个记账操作，第2个操作会失败

**预期行为**:
- 执行所有操作
- 生成 3 个 ExecutionResult
- 第 1、3 个 success: true
- 第 2 个 success: false，包含错误信息
- 所有结果通过回调返回

**验收标准**:
- 部分失败不影响其他操作
- 错误信息准确传递
- 回调接收到所有结果

### 需求：ConversationChannel 维护对话流

**优先级**: P0
**关联能力**: adaptive-conversation

ConversationChannel 必须维护多轮对话上下文，支持执行结果注入。

#### 场景：接收执行结果并生成响应

**前置条件**:
- ConversationChannel 已初始化
- ExecutionChannel 执行完成

**输入**:
- 用户输入: "打车35，吃饭50"
- 执行结果: 2个成功的记账操作

**预期行为**:
- 接收执行结果
- 注入到对话上下文
- 检测对话模式（quickBookkeeping）
- 生成极简响应: "✓ 2笔"

**验收标准**:
- 执行结果正确注入
- 对话模式检测准确
- 响应风格符合模式

#### 场景：对话内容与操作结果混合

**前置条件**:
- ConversationChannel 已初始化
- 用户输入包含 chat_content

**输入**:
- 用户输入: "打车35，顺便问一下我这个月还能花多少"
- chat_content: "顺便问一下我这个月还能花多少"
- 执行结果: 1个成功的记账操作

**预期行为**:
- 接收执行结果和 chat_content
- 检测对话模式（mixed）
- 生成混合响应: "已记录交通35元，您本月还可以花500元"

**验收标准**:
- chat_content 正确处理
- 执行结果和对话内容都包含在响应中
- 响应长度 20-50 字

### 需求：ConversationChannel 支持响应生成时机控制

**优先级**: P0
**关联能力**: adaptive-conversation

ConversationChannel 必须根据操作类型和对话模式决定响应生成时机。

#### 场景：immediate 操作无语音反馈

**前置条件**:
- ConversationChannel 已初始化
- 用户输入包含导航操作

**输入**: "打开预算页面"

**预期行为**:
- 导航操作立即执行
- 不生成语音反馈（避免打断用户）
- 仅在 UI 显示导航状态

**验收标准**:
- 无 TTS 播放
- UI 正确显示导航状态
- 不阻塞后续操作

#### 场景：normal 操作立即生成响应

**前置条件**:
- ConversationChannel 已初始化
- 用户输入包含查询操作

**输入**: "这个月花了多少"

**预期行为**:
- 查询操作执行
- 立即生成响应
- TTS 播放响应内容

**验收标准**:
- 响应延迟 < 1.5s
- 响应内容准确
- TTS 播放流畅

#### 场景：deferred 操作根据对话模式决定

**前置条件**:
- ConversationChannel 已初始化
- 用户输入包含多个记账操作

**输入**: "打车35，吃饭50，买菜30"

**预期行为**:
- 检测对话模式（quickBookkeeping）
- 等待所有操作执行完成
- 生成极简响应: "✓ 3笔"

**验收标准**:
- 等待批量执行完成
- 响应风格符合 quickBookkeeping 模式
- 响应长度 5-10 字

#### 场景：失败操作总是生成错误提示

**前置条件**:
- ConversationChannel 已初始化
- 操作执行失败

**输入**: 记账操作（数据库错误）

**预期行为**:
- 检测到执行失败
- 立即生成错误提示
- TTS 播放错误信息

**验收标准**:
- 错误提示及时生成
- 错误信息清晰易懂
- 提供重试建议

## 修改需求

### 需求：扩展 ConversationContext 支持执行结果注入

**优先级**: P0
**关联能力**: 无

ConversationContext 必须扩展以支持执行结果的注入和查询。

#### 场景：注入单个执行结果

**前置条件**:
- ConversationContext 已初始化

**输入**: ExecutionResult（success: true, operation: add_transaction）

**预期行为**:
- 调用 addExecutionResult() 方法
- 结果存储到 executionResults 列表
- 可通过 getRecentResults() 查询

**验收标准**:
- 结果正确存储
- 查询接口可用
- 不影响现有对话历史

#### 场景：注入批量执行结果

**前置条件**:
- ConversationContext 已初始化

**输入**: 3个 ExecutionResult

**预期行为**:
- 批量调用 addExecutionResult()
- 所有结果按顺序存储
- 可通过 getRecentResults(limit: 3) 查询

**验收标准**:
- 批量存储成功
- 顺序保持一致
- 查询结果准确

## 性能要求

- immediate 操作执行延迟 P95 < 100ms
- normal 操作执行延迟 P95 < 1s
- deferred 操作聚合延迟 ≤ 1.8s（1.5s 基础 + 300ms VAD 缓冲）
- 批量执行成功率 ≥ 95%
- 回调执行不阻塞主流程（< 10ms）

## 安全要求

- 操作队列容量限制（防止内存溢出）
- 执行结果大小限制（≤ 10KB）
- 回调函数超时保护（5s）

## 兼容性要求

- 保持现有 VoiceServiceCoordinator API 不变
- 新增 IntelligenceEngine 作为可选组件
- 通过配置开关控制启用
