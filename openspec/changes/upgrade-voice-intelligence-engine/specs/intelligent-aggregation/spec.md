# 智能聚合能力规范

> **能力ID**: intelligent-aggregation
> **变更ID**: upgrade-voice-intelligence-engine
> **依赖**: multi-operation-recognition, dual-channel-processing

## 新增需求

### 需求：IntelligentAggregator 支持基础等待触发

**优先级**: P0
**关联能力**: dual-channel-processing

IntelligentAggregator 必须实现 1.5 秒基础聚合窗口，确保 deferred 操作有足够时间聚合。

#### 场景：1.5秒后自动触发执行

**前置条件**:
- IntelligentAggregator 已初始化
- 收到第一个 deferred 操作

**输入**: 单个记账操作（amount: 35, category: 交通）

**预期行为**:
- 操作进入聚合队列
- 启动 1.5 秒计时器
- 1.5 秒后自动触发执行
- 执行完成后重置状态

**验收标准**:
- 计时器准确为 1.5 秒（误差 ≤ 50ms）
- 触发后队列清空
- 状态正确转换（idle → collecting → waiting → executing → idle）

#### 场景：多个操作在窗口内聚合

**前置条件**:
- IntelligentAggregator 已初始化
- 第一个操作已启动计时器

**输入**: 连续 3 个记账操作（间隔 < 1.5s）

**预期行为**:
- 第一个操作启动 1.5 秒计时器
- 后续操作加入聚合队列，不重置计时器
- 1.5 秒后批量执行所有 3 个操作
- 执行顺序与输入顺序一致

**验收标准**:
- 所有操作在同一批次执行
- 执行顺序保持一致
- 总延迟 ≤ 1.5s（从第一个操作开始计时）

#### 场景：计时器期间收到 immediate 操作

**前置条件**:
- IntelligentAggregator 已初始化
- 聚合队列中有 2 个 deferred 操作等待

**输入**: 导航操作（priority: immediate）

**预期行为**:
- 立即触发执行队列中的 deferred 操作
- immediate 操作单独立即执行
- 不等待 1.5 秒计时器

**验收标准**:
- deferred 操作提前执行
- immediate 操作不进入聚合队列
- 总延迟 < 200ms

### 需求：IntelligentAggregator 支持 VAD 触发

**优先级**: P0
**关联能力**: dual-channel-processing

IntelligentAggregator 必须集成 BargeInDetector，在检测到用户停止说话后提前触发执行。

#### 场景：检测到 1 秒静音后触发

**前置条件**:
- IntelligentAggregator 已初始化
- BargeInDetector 已集成
- 聚合队列中有 2 个 deferred 操作

**输入**:
- 用户输入: "打车35，吃饭50"
- VAD 检测到 1 秒静音

**预期行为**:
- BargeInDetector 触发静音事件
- IntelligentAggregator 等待 300ms 缓冲
- 300ms 后触发执行（总计 1.3s）
- 不等待 1.5 秒基础计时器

**验收标准**:
- VAD 触发优先于基础计时器
- 300ms 缓冲避免误触发
- 总延迟 < 1.5s（比基础等待快）

#### 场景：VAD 误触发后继续聚合

**前置条件**:
- IntelligentAggregator 已初始化
- 聚合队列中有 1 个 deferred 操作
- VAD 检测到短暂静音

**输入**:
- 用户输入: "打车35，[短暂停顿]，吃饭50"
- VAD 检测到 0.5 秒静音（未达到 1 秒阈值）

**预期行为**:
- VAD 不触发执行
- 继续等待基础计时器
- 第二个操作正常加入队列
- 1.5 秒后批量执行

**验收标准**:
- 短暂静音不触发执行
- 两个操作在同一批次执行
- 静音阈值准确为 1 秒

#### 场景：VAD 不可用时降级到基础等待

**前置条件**:
- IntelligentAggregator 已初始化
- BargeInDetector 不可用或未集成

**输入**: 2 个记账操作

**预期行为**:
- 检测到 VAD 不可用
- 自动降级到基础等待模式
- 1.5 秒后触发执行
- 不影响正常功能

**验收标准**:
- VAD 不可用不阻塞功能
- 降级逻辑透明
- 执行成功率不受影响

### 需求：IntelligentAggregator 支持话题感知触发

**优先级**: P0
**关联能力**: multi-operation-recognition

IntelligentAggregator 必须检测话题切换，在用户改变意图时立即执行前序操作。

#### 场景：检测到操作类型变化立即执行

**前置条件**:
- IntelligentAggregator 已初始化
- 聚合队列中有 2 个 deferred 记账操作

**输入**:
- 队列中: 2 个 add_transaction 操作
- 新操作: navigate 操作（priority: immediate）

**预期行为**:
- 检测到操作类型变化（add_transaction → navigate）
- 立即执行队列中的 2 个记账操作
- 然后执行导航操作
- 不等待 1.5 秒计时器

**验收标准**:
- 话题切换检测准确
- 前序操作立即执行
- 执行顺序正确（记账 → 导航）

#### 场景：同类型操作不触发话题切换

**前置条件**:
- IntelligentAggregator 已初始化
- 聚合队列中有 1 个 add_transaction 操作

**输入**:
- 队列中: 1 个 add_transaction 操作
- 新操作: 另一个 add_transaction 操作

**预期行为**:
- 检测到操作类型相同
- 不触发话题切换
- 新操作加入聚合队列
- 继续等待计时器

**验收标准**:
- 同类型操作不触发提前执行
- 操作正确聚合
- 批量执行成功

#### 场景：优先级变化触发话题切换

**前置条件**:
- IntelligentAggregator 已初始化
- 聚合队列中有 2 个 deferred 操作

**输入**:
- 队列中: 2 个 deferred 操作
- 新操作: normal 查询操作

**预期行为**:
- 检测到优先级变化（deferred → normal）
- 立即执行队列中的 deferred 操作
- 然后执行 normal 操作
- 不等待计时器

**验收标准**:
- 优先级变化视为话题切换
- 执行顺序符合优先级
- 总延迟 < 1s

### 需求：IntelligentAggregator 支持队列容量限制

**优先级**: P0
**关联能力**: dual-channel-processing

IntelligentAggregator 必须限制聚合队列容量，防止内存溢出。

#### 场景：队列达到最大容量时提前执行

**前置条件**:
- IntelligentAggregator 已初始化
- 队列最大容量配置为 10

**输入**: 连续 10 个记账操作（间隔 < 1.5s）

**预期行为**:
- 前 9 个操作进入队列
- 第 10 个操作触发立即执行
- 批量执行所有 10 个操作
- 不等待 1.5 秒计时器

**验收标准**:
- 队列容量限制生效
- 提前执行不丢失操作
- 所有操作执行成功

#### 场景：队列容量可配置

**前置条件**:
- IntelligentAggregator 已初始化

**输入**: 配置队列容量为 5

**预期行为**:
- 队列容量设置为 5
- 第 5 个操作触发执行
- 配置立即生效

**验收标准**:
- 容量配置可修改
- 配置范围 1-100
- 默认值为 10

### 需求：IntelligentAggregator 支持状态管理

**优先级**: P0
**关联能力**: 无

IntelligentAggregator 必须维护清晰的状态机，确保触发逻辑正确。

#### 场景：状态正确转换

**前置条件**:
- IntelligentAggregator 已初始化
- 当前状态为 idle

**输入**: 1 个 deferred 操作

**预期行为**:
- 状态转换: idle → collecting
- 启动计时器后: collecting → waiting
- 触发执行后: waiting → executing
- 执行完成后: executing → idle

**验收标准**:
- 状态转换顺序正确
- 每个状态持续时间合理
- 状态可查询

#### 场景：执行失败后状态恢复

**前置条件**:
- IntelligentAggregator 已初始化
- 当前状态为 executing

**输入**: 执行操作失败（数据库错误）

**预期行为**:
- 捕获执行错误
- 状态恢复为 idle
- 清空队列
- 记录错误日志

**验收标准**:
- 错误不阻塞状态机
- 状态正确恢复
- 错误信息完整

## 性能要求

- 基础等待触发延迟：1.5s ± 50ms
- VAD 触发延迟：< 1.5s（1s 静音 + 300ms 缓冲）
- 话题切换触发延迟：< 100ms
- 队列容量检查延迟：< 10ms
- 状态转换延迟：< 5ms

## 安全要求

- 队列容量限制：1-100（默认 10）
- 计时器超时保护：最长 3s
- 状态机死锁检测：5s 无状态变化自动重置

## 兼容性要求

- 与现有 BargeInDetector 集成
- 支持 VAD 不可用时降级
- 保持 ExecutionChannel 接口不变
