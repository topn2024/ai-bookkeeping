# 多操作识别能力规范

> **能力ID**: multi-operation-recognition
> **变更ID**: upgrade-voice-intelligence-engine
> **依赖**: 无

## 新增需求

### 需求：SmartIntentRecognizer 支持多操作识别

**优先级**: P0
**关联能力**: dual-channel-processing, intelligent-aggregation

SmartIntentRecognizer 必须能够从单次用户输入中识别出多个操作意图，并区分操作内容和对话内容。

#### 场景：用户一次性说出多笔记账

**前置条件**:
- 用户已启动语音助手
- SmartIntentRecognizer 已初始化

**输入**: "打车35，吃饭50，买菜30"

**预期输出**:
```json
{
  "operations": [
    {"type": "add_transaction", "priority": "deferred", "params": {"amount": 35, "category": "交通"}},
    {"type": "add_transaction", "priority": "deferred", "params": {"amount": 50, "category": "餐饮"}},
    {"type": "add_transaction", "priority": "deferred", "params": {"amount": 30, "category": "餐饮"}}
  ],
  "chat_content": null
}
```

**验收标准**:
- 识别出3个独立的记账操作
- 每个操作包含正确的金额和分类
- 所有操作优先级为 deferred
- chat_content 为空

#### 场景：用户混合操作和对话内容

**前置条件**:
- 用户已启动语音助手
- SmartIntentRecognizer 已初始化

**输入**: "打车35，顺便问一下我这个月还能花多少"

**预期输出**:
```json
{
  "operations": [
    {"type": "add_transaction", "priority": "deferred", "params": {"amount": 35, "category": "交通"}}
  ],
  "chat_content": "顺便问一下我这个月还能花多少"
}
```

**验收标准**:
- 识别出1个记账操作
- 对话内容被正确提取到 chat_content
- 对话内容不影响操作识别

#### 场景：用户说出操作和导航意图

**前置条件**:
- 用户已启动语音助手
- SmartIntentRecognizer 已初始化

**输入**: "打车35，打开预算页面"

**预期输出**:
```json
{
  "operations": [
    {"type": "add_transaction", "priority": "deferred", "params": {"amount": 35, "category": "交通"}},
    {"type": "navigate", "priority": "immediate", "params": {"targetPage": "预算"}}
  ],
  "chat_content": null
}
```

**验收标准**:
- 识别出2个操作（记账 + 导航）
- 记账操作优先级为 deferred
- 导航操作优先级为 immediate
- 操作顺序与用户输入顺序一致

### 需求：LLM 超时从 5s 降至 3s

**优先级**: P0
**关联能力**: 无

为了提升响应速度，LLM 识别超时时间必须从当前的 5000ms 降低到 3000ms。

#### 场景：LLM 在 3s 内返回结果

**前置条件**:
- QwenService 可用
- 用户输入有效

**输入**: "打车35"

**预期行为**:
- LLM 在 3s 内返回识别结果
- 系统使用 LLM 结果，不触发规则兜底
- 总响应时间 < 3.5s

**验收标准**:
- LLM 超时配置为 3000ms
- P80 请求在 3s 内完成
- 超时后自动降级到规则兜底

#### 场景：LLM 超时后降级到规则兜底

**前置条件**:
- QwenService 可用但响应慢
- 用户输入有效

**输入**: "打车35"

**预期行为**:
- LLM 调用在 3s 后超时
- 系统自动降级到规则兜底
- 规则兜底在 50ms 内返回结果
- 总响应时间 < 3.1s

**验收标准**:
- 超时后不阻塞用户
- 规则兜底准确率 ≥ 85%
- 用户无感知切换

### 需求：操作优先级自动分类

**优先级**: P0
**关联能力**: intelligent-aggregation, dual-channel-processing

系统必须根据操作类型自动分配优先级，确保不同操作得到合适的处理时机。

#### 场景：导航操作分配 immediate 优先级

**前置条件**:
- 用户输入包含导航意图

**输入**: "打开设置"

**预期输出**:
```json
{
  "operations": [
    {"type": "navigate", "priority": "immediate", "params": {"targetPage": "设置"}}
  ],
  "chat_content": null
}
```

**验收标准**:
- 导航操作优先级为 immediate
- 操作将在 <100ms 内执行
- 不进入聚合队列

#### 场景：查询操作分配 normal 优先级

**前置条件**:
- 用户输入包含查询意图

**输入**: "这个月花了多少"

**预期输出**:
```json
{
  "operations": [
    {"type": "query", "priority": "normal", "params": {"timeRange": "本月", "queryType": "sum"}}
  ],
  "chat_content": null
}
```

**验收标准**:
- 查询操作优先级为 normal
- 操作将在 <1s 内执行
- 不进入聚合队列

#### 场景：记账操作分配 deferred 优先级

**前置条件**:
- 用户输入包含记账意图

**输入**: "打车35"

**预期输出**:
```json
{
  "operations": [
    {"type": "add_transaction", "priority": "deferred", "params": {"amount": 35, "category": "交通"}}
  ],
  "chat_content": null
}
```

**验收标准**:
- 记账操作优先级为 deferred
- 操作进入聚合队列
- 等待 1.5s 或触发条件后批量执行

### 需求：保留现有 4 层规则兜底

**优先级**: P0
**关联能力**: 无

必须完整保留 SmartIntentRecognizer 现有的 4 层规则兜底机制，确保向后兼容性。

#### 场景：LLM 不可用时使用规则兜底

**前置条件**:
- QwenService 不可用（未配置 API Key）
- 用户输入有效

**输入**: "打车35"

**预期行为**:
- 跳过 LLM 调用
- 直接使用规则兜底
- Layer 1 精确规则匹配成功
- 返回识别结果

**验收标准**:
- 4 层规则完整保留
- 识别准确率 ≥ 85%
- 响应时间 < 50ms

#### 场景：规则兜底逐层降级

**前置条件**:
- LLM 超时
- 用户输入为边缘 case

**输入**: "滴滴打车花了三十五块"

**预期行为**:
- Layer 1 精确规则未命中
- Layer 2 同义词扩展命中（"滴滴" → "交通"）
- 返回识别结果

**验收标准**:
- 逐层尝试，找到第一个匹配
- 同义词扩展覆盖常见表达
- 置信度 ≥ 0.75

## 修改需求

### 需求：扩展 SmartIntentResult 支持多操作

**优先级**: P0
**关联能力**: dual-channel-processing

SmartIntentResult 数据结构必须扩展以支持多操作返回。

#### 场景：返回多操作结果

**前置条件**:
- recognizeMultiOperation() 被调用

**输入**: "打车35，吃饭50"

**预期输出**:
```dart
MultiOperationResult(
  operations: [
    Operation(type: OperationType.addTransaction, priority: OperationPriority.deferred, ...),
    Operation(type: OperationType.addTransaction, priority: OperationPriority.deferred, ...),
  ],
  chatContent: null,
  source: RecognitionSource.llmFallback,
  confidence: 0.9,
)
```

**验收标准**:
- 新增 MultiOperationResult 类
- 包含 operations 列表和 chatContent 字段
- 保持现有 SmartIntentResult 向后兼容

## 性能要求

- LLM 识别延迟 P95 < 3s
- 规则兜底延迟 P95 < 50ms
- 多操作识别准确率 ≥ 90%
- LLM 超时率 < 20%

## 安全要求

- 输入长度限制 ≤ 500 字符
- 防止注入攻击（过滤特殊字符）
- LLM 响应格式验证

## 兼容性要求

- 保持现有 recognize() 方法签名不变
- 新增 recognizeMultiOperation() 方法
- 4 层规则兜底完整保留
