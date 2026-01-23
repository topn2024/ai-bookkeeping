# 自适应对话能力规范

> **能力ID**: adaptive-conversation
> **变更ID**: upgrade-voice-intelligence-engine
> **依赖**: multi-operation-recognition, dual-channel-processing

## 新增需求

### 需求：AdaptiveConversationAgent 支持对话模式检测

**优先级**: P0
**关联能力**: dual-channel-processing

AdaptiveConversationAgent 必须根据用户输入和操作类型自动检测对话模式。

#### 场景：检测 chat 模式（闲聊）

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 用户输入不包含操作意图

**输入**: "今天天气真好"

**预期输出**:
```json
{
  "mode": "chat",
  "confidence": 0.95
}
```

**验收标准**:
- 无操作意图时检测为 chat
- 无疑问词时检测为 chat
- 置信度 ≥ 0.9

#### 场景：检测 chatWithIntent 模式（有诉求的闲聊）

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 用户输入包含疑问词

**输入**: "我这个月还能花多少钱"

**预期输出**:
```json
{
  "mode": "chatWithIntent",
  "confidence": 0.92
}
```

**验收标准**:
- 无操作但有疑问词时检测为 chatWithIntent
- 疑问词包括："吗"、"呢"、"怎么"、"为什么"、"多少"
- 置信度 ≥ 0.85

#### 场景：检测 quickBookkeeping 模式（快速记账）

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 用户输入包含多个记账操作

**输入**: "打车35，吃饭50，买菜30"

**预期输出**:
```json
{
  "mode": "quickBookkeeping",
  "confidence": 0.98
}
```

**验收标准**:
- 多个操作（≥2）且无疑问词时检测为 quickBookkeeping
- 所有操作类型为 add_transaction
- 置信度 ≥ 0.95

#### 场景：检测 mixed 模式（混合）

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 用户输入包含操作和对话内容

**输入**: "打车35，顺便问一下我这个月还能花多少"

**预期输出**:
```json
{
  "mode": "mixed",
  "confidence": 0.90
}
```

**验收标准**:
- 有操作且有 chat_content 时检测为 mixed
- 或有操作且有疑问词时检测为 mixed
- 置信度 ≥ 0.85

### 需求：AdaptiveConversationAgent 支持响应长度控制

**优先级**: P0
**关联能力**: 无

AdaptiveConversationAgent 必须根据对话模式生成不同长度的响应。

#### 场景：chat 模式生成简短响应

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 对话模式为 chat

**输入**:
- 用户输入: "今天天气真好"
- 对话模式: chat

**预期输出**: "是啊，适合出去走走"

**验收标准**:
- 响应长度 10-30 字
- 语气轻松友好
- 不包含操作反馈

#### 场景：chatWithIntent 模式生成详细响应

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 对话模式为 chatWithIntent

**输入**:
- 用户输入: "我这个月还能花多少钱"
- 对话模式: chatWithIntent
- 查询结果: 剩余预算 500 元

**预期输出**: "您本月预算还剩 500 元，建议合理安排支出，避免超支"

**验收标准**:
- 响应长度 30-100 字
- 包含具体数据
- 提供建议或解释

#### 场景：quickBookkeeping 模式生成极简响应

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 对话模式为 quickBookkeeping

**输入**:
- 用户输入: "打车35，吃饭50，买菜30"
- 对话模式: quickBookkeeping
- 执行结果: 3 笔记账成功

**预期输出**: "✓ 3笔"

**验收标准**:
- 响应长度 5-10 字
- 使用符号（✓）或极简文字
- 仅确认操作数量

#### 场景：mixed 模式生成混合响应

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 对话模式为 mixed

**输入**:
- 用户输入: "打车35，顺便问一下我这个月还能花多少"
- 对话模式: mixed
- 执行结果: 1 笔记账成功，剩余预算 500 元

**预期输出**: "已记录交通 35 元，您本月还可以花 500 元"

**验收标准**:
- 响应长度 20-50 字
- 包含操作确认和对话回答
- 简洁但完整

### 需求：AdaptiveConversationAgent 支持 LLM 响应生成

**优先级**: P0
**关联能力**: 无

AdaptiveConversationAgent 必须集成 LLMResponseGenerator，根据对话模式生成自然语言响应。

#### 场景：chat 模式 LLM 生成

**前置条件**:
- AdaptiveConversationAgent 已初始化
- LLMResponseGenerator 可用

**输入**:
- 对话模式: chat
- 用户输入: "今天心情不错"
- 对话历史: 最近 3 轮对话

**预期行为**:
- 调用 LLMResponseGenerator
- 传入 chat 模式 prompt
- 限制响应长度 10-30 字
- 生成轻松友好的回复

**验收标准**:
- LLM 调用成功
- 响应符合长度限制
- 语气符合 chat 模式

#### 场景：LLM 不可用时降级到模板响应

**前置条件**:
- AdaptiveConversationAgent 已初始化
- LLMResponseGenerator 不可用

**输入**:
- 对话模式: quickBookkeeping
- 执行结果: 2 笔记账成功

**预期行为**:
- 检测到 LLM 不可用
- 降级到模板响应
- 使用预定义模板: "✓ {count}笔"
- 不阻塞用户

**验收标准**:
- 降级逻辑透明
- 模板响应准确
- 响应延迟 < 50ms

#### 场景：LLM 超时后降级

**前置条件**:
- AdaptiveConversationAgent 已初始化
- LLM 响应慢

**输入**:
- 对话模式: chatWithIntent
- LLM 超时时间: 2s

**预期行为**:
- LLM 调用在 2s 后超时
- 自动降级到模板响应
- 使用通用回复模板
- 记录超时日志

**验收标准**:
- 超时时间准确为 2s
- 降级不影响用户体验
- 超时率 < 10%

### 需求：AdaptiveConversationAgent 支持对话历史引用

**优先级**: P1
**关联能力**: dual-channel-processing

AdaptiveConversationAgent 必须引用对话历史，生成上下文相关的响应。

#### 场景：引用最近对话生成响应

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 对话历史包含最近 3 轮对话

**输入**:
- 用户输入: "那我今天还能花多少"
- 对话历史: 上一轮讨论了本月预算
- 对话模式: chatWithIntent

**预期行为**:
- 读取对话历史
- 理解"那"指代上一轮话题
- 生成上下文相关响应
- 包含具体数据

**验收标准**:
- 正确理解指代关系
- 响应与历史相关
- 不重复历史信息

#### 场景：对话历史为空时生成独立响应

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 对话历史为空（首次对话）

**输入**:
- 用户输入: "打车35"
- 对话历史: 空
- 对话模式: quickBookkeeping

**预期行为**:
- 检测到历史为空
- 生成独立响应
- 不引用历史
- 响应完整

**验收标准**:
- 历史为空不影响响应
- 响应独立完整
- 不出现指代错误

### 需求：AdaptiveConversationAgent 支持响应风格配置

**优先级**: P2
**关联能力**: 无

AdaptiveConversationAgent 必须支持用户自定义响应风格偏好。

#### 场景：用户选择详细响应风格

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 用户配置响应风格为"详细"

**输入**:
- 用户输入: "打车35，吃饭50"
- 对话模式: quickBookkeeping（默认极简）
- 用户配置: 详细风格

**预期行为**:
- 覆盖默认 quickBookkeeping 模式
- 生成详细响应: "已记录交通 35 元和餐饮 50 元，共 2 笔"
- 响应长度 20-40 字

**验收标准**:
- 用户配置优先于默认模式
- 响应风格符合配置
- 配置可随时修改

#### 场景：用户选择极简响应风格

**前置条件**:
- AdaptiveConversationAgent 已初始化
- 用户配置响应风格为"极简"

**输入**:
- 用户输入: "我这个月还能花多少"
- 对话模式: chatWithIntent（默认详细）
- 用户配置: 极简风格

**预期行为**:
- 覆盖默认 chatWithIntent 模式
- 生成极简响应: "还剩 500 元"
- 响应长度 5-15 字

**验收标准**:
- 用户配置优先于默认模式
- 响应风格符合配置
- 不丢失关键信息

## 修改需求

### 需求：扩展 LLMResponseGenerator 支持模式化 Prompt

**优先级**: P0
**关联能力**: 无

LLMResponseGenerator 必须支持根据对话模式使用不同的 prompt 模板。

#### 场景：chat 模式使用简短 prompt

**前置条件**:
- LLMResponseGenerator 已初始化

**输入**:
- 对话模式: chat
- 用户输入: "今天天气真好"

**预期行为**:
- 使用 chat 模式 prompt 模板
- Prompt 包含："简短2-3句，轻松友好"
- 限制响应长度 10-30 字
- 生成响应

**验收标准**:
- Prompt 模板正确选择
- 响应符合模式要求
- 模板可配置

#### 场景：quickBookkeeping 模式使用极简 prompt

**前置条件**:
- LLMResponseGenerator 已初始化

**输入**:
- 对话模式: quickBookkeeping
- 执行结果: 3 笔记账成功

**预期行为**:
- 使用 quickBookkeeping 模式 prompt 模板
- Prompt 包含："极简确认，如'✓ 2笔'"
- 限制响应长度 5-10 字
- 生成响应

**验收标准**:
- Prompt 模板正确选择
- 响应极简
- 包含操作数量

## 性能要求

- 对话模式检测延迟：< 50ms
- LLM 响应生成延迟：P95 < 2s
- 模板响应生成延迟：< 50ms
- 对话历史查询延迟：< 10ms
- 模式检测准确率：≥ 85%

## 安全要求

- 对话历史长度限制：最多 20 轮
- 响应长度限制：≤ 200 字
- LLM 超时保护：2s
- 敏感信息过滤（金额、账户等）

## 兼容性要求

- 保持现有 LLMResponseGenerator 接口不变
- 新增 generateWithMode() 方法
- 支持用户配置覆盖默认模式
