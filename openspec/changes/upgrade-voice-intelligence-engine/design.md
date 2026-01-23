# 架构设计

> **变更ID**: upgrade-voice-intelligence-engine
> **日期**: 2026-01-18

## 架构概览

### 当前架构问题

```
用户输入 → SmartIntentRecognizer → VoiceServiceCoordinator → 业务服务
                                            ↓
                                    串行执行：识别→执行→反馈
                                    紧耦合：直接依赖 DatabaseService 等
```

**核心问题**：
1. 串行处理导致响应慢（识别1-2s + 执行0.5s + 反馈1s = 总计2.5-3.5s）
2. 单一意图焦点无法同时处理操作和对话
3. 紧耦合设计难以复用到其他应用

### 目标架构

```
用户输入 → MultiOperationRecognizer → IntelligenceEngine
                                            ↓
                        ┌───────────────────┴───────────────────┐
                        ↓                                       ↓
              ExecutionChannel                      ConversationChannel
              (后台处理操作队列)                      (维护对话流)
                        ↓                                       ↓
              OperationAdapter                      FeedbackAdapter
              (业务适配层)                           (业务适配层)
                        ↓                                       ↓
              DatabaseService                       LLMResponseGenerator
```

**核心改进**：
1. 双通道并行处理：操作执行和对话生成同时进行
2. 多操作识别：一次输入可包含多个操作 + 对话内容
3. 适配器解耦：核心引擎与业务逻辑分离

## 核心组件设计

### 1. MultiOperationRecognizer（多操作识别器）

**职责**：将用户输入解析为多个操作 + 对话内容

**设计决策**：
- **LLM优先，3s超时**：平衡准确率和响应速度
  - 理由：LLM识别准确率高（~95%），但延迟不可控（P50=1.2s, P95=4s）
  - 权衡：3s超时可覆盖80%请求，超时后降级到规则兜底（准确率~85%）
  - 替代方案：5s超时（当前值）→ 用户体验差；1s超时 → 降级率过高
- **复用现有4层规则**：完整保留 SmartIntentRecognizer 的兜底能力
  - Layer 1: 精确规则（~1ms）
  - Layer 2: 同义词扩展（~5ms）
  - Layer 3: 意图模板（~10ms）
  - Layer 4: 学习缓存（~5ms）

**输出格式**：
```json
{
  "operations": [
    {"type": "add_transaction", "priority": "deferred", "params": {...}},
    {"type": "navigate", "priority": "immediate", "params": {...}}
  ],
  "chat_content": "顺便问一下"
}
```

**优先级分类规则**：
- **immediate**：导航操作（用户期望立即跳转，<100ms）
- **normal**：查询操作（用户期望立即得到答案，<1s）
- **deferred**：记账操作（可聚合，1.5s窗口）
- **background**：批量操作（异步执行，完成后通知）

### 2. DualChannelProcessor（双通道处理器）

**职责**：分离操作执行和对话生成，实现并行处理

#### 2.1 ExecutionChannel（执行通道）

**设计决策**：
- **优先级队列**：immediate > normal > deferred > background
  - 理由：导航操作必须立即执行，否则用户会感到卡顿
  - 实现：使用 Dart 的 PriorityQueue 或自定义优先级队列
- **操作聚合窗口**：1.5秒基础等待
  - 理由：用户连续说多笔记账时，批量执行比逐笔执行体验更好
  - 权衡：1.5s是用户可接受的等待时间（参考 Nielsen 的响应时间指南）
  - 替代方案：1s → 聚合效果差；2s → 用户感到明显延迟

**聚合触发条件**（三选一）：
1. **基础等待**：1.5秒后自动触发
2. **VAD触发**：检测到1秒静音后300ms内触发
   - 理由：用户停止说话表示输入完成，可提前执行
   - 集成：复用现有 BargeInDetector 的静音检测能力
3. **话题切换**：检测到话题变化立即执行前序操作
   - 示例："打车35，打开预算" → 检测到"打开"是导航意图，立即执行"打车35"
   - 实现：比较当前操作和队列中操作的类型，类型变化视为话题切换

**执行结果回调**：
```dart
typedef OperationCallback = void Function(ExecutionResult result);

class ExecutionChannel {
  final OperationAdapter adapter;
  final List<OperationCallback> callbacks;

  Future<void> execute(Operation op) async {
    final result = await adapter.execute(op);
    for (final callback in callbacks) {
      callback(result);
    }
  }
}
```

#### 2.2 ConversationChannel（对话通道）

**设计决策**：
- **对话流维护**：保持多轮对话上下文
  - 复用现有 ConversationContext，扩展 executionResults 字段
  - 执行结果通过回调注入，LLM生成响应时可引用
- **响应生成时机**：
  - immediate操作：无语音反馈（避免打断用户）
  - normal操作：立即生成响应
  - deferred操作：根据对话模式决定（quickBookkeeping极简，其他详细）
  - 失败操作：总是生成错误提示

**对话模式检测**：
```dart
enum ConversationMode {
  chat,              // 闲聊：简短2-3句
  chatWithIntent,    // 有诉求的闲聊：详细回答
  quickBookkeeping,  // 快速记账：极简"✓ 2笔"
  mixed,             // 混合：简短确认+操作反馈
}

ConversationMode detectMode(String input, List<Operation> operations) {
  // 检测关键词
  if (operations.isEmpty && _isCasualChat(input)) return ConversationMode.chat;
  if (operations.isEmpty && _hasQuestion(input)) return ConversationMode.chatWithIntent;
  if (operations.length >= 2 && !_hasQuestion(input)) return ConversationMode.quickBookkeeping;
  return ConversationMode.mixed;
}
```

### 3. IntelligentAggregator（智能聚合器）

**职责**：决定何时触发操作执行

**设计决策**：
- **三种触发机制**：
  1. **基础等待**：1.5秒计时器
     - 实现：`Timer(Duration(milliseconds: 1500), () => _triggerExecution())`
  2. **VAD触发**：集成 BargeInDetector
     - 监听静音事件：1秒静音 → 300ms后触发
     - 理由：300ms缓冲避免误触发（用户可能只是短暂停顿）
  3. **话题感知**：检测意图类型变化
     - 实现：比较 `currentOp.type` 和 `queuedOps.last.type`
     - 示例：记账→导航 → 立即执行记账，再执行导航

**状态机设计**：
```
idle → collecting → waiting → executing → idle
  ↑                    ↓
  └────────────────────┘
```

- **idle**：无待处理操作
- **collecting**：收集操作中（1.5s窗口内）
- **waiting**：等待VAD或话题切换信号
- **executing**：批量执行操作

### 4. AdaptiveConversationAgent（自适应对话代理）

**职责**：根据对话模式生成不同风格的响应

**设计决策**：
- **模式检测规则**：
  - **chat**：无操作 + 无疑问词 → 简短回复
  - **chatWithIntent**：无操作 + 有疑问词（"吗"、"呢"、"怎么"）→ 详细回答
  - **quickBookkeeping**：多操作（≥2）+ 无疑问词 → 极简反馈
  - **mixed**：有操作 + 有对话内容 → 混合风格
- **响应长度控制**：
  - chat: 10-30字
  - chatWithIntent: 30-100字
  - quickBookkeeping: 5-10字（"✓ 2笔"、"已记录3笔"）
  - mixed: 20-50字

**LLM Prompt设计**：
```
你是记账助手，根据对话模式生成响应：
- chat模式：简短2-3句，轻松友好
- chatWithIntent模式：详细回答用户问题，提供具体信息
- quickBookkeeping模式：极简确认，如"✓ 2笔"
- mixed模式：简短确认+操作反馈

【对话模式】{mode}
【用户输入】{input}
【执行结果】{results}
【对话历史】{history}

生成响应：
```

### 5. ProactiveConversationManager（主动对话管理器）

**职责**：在用户沉默时主动发起话题

**设计决策**：
- **触发条件**：30秒无用户输入
  - 理由：30s是用户可能需要提醒的临界点（参考聊天应用的"正在输入"超时）
  - 替代方案：15s → 过于频繁；60s → 失去主动性
- **频率限制**：最多3次主动发起
  - 理由：避免打扰用户，3次后用户仍无响应说明不需要交互
  - 实现：计数器 `_proactiveCount`，达到3次后停止
- **话题生成**：LLM根据用户画像生成
  - 输入：用户最近消费分类、金额、时间
  - 输出：相关话题（"今天午餐花了35，晚餐想吃什么？"）
  - 避免：硬编码话题列表（缺乏个性化）
- **退出机制**：用户明确拒绝后停止
  - 检测关键词："不用了"、"别说了"、"安静"
  - 设置标志：`_proactiveDisabled = true`

**状态机**：
```
idle → waiting(30s) → generating → speaking → idle
  ↑                                    ↓
  └────────────────────────────────────┘
                (用户拒绝)
```

### 6. 适配器模式（Adapter Pattern）

**职责**：解耦核心引擎和业务逻辑

**设计决策**：
- **OperationAdapter接口**：
  ```dart
  abstract class OperationAdapter {
    Future<ExecutionResult> execute(Operation operation);
    bool canHandle(OperationType type);
  }
  ```
  - 实现：BookkeepingOperationAdapter（处理记账、查询、导航、删除、修改）
  - 扩展：可添加 ShoppingOperationAdapter、TravelOperationAdapter 等

- **FeedbackAdapter接口**：
  ```dart
  abstract class FeedbackAdapter {
    Future<String> generateFeedback(
      ConversationMode mode,
      List<ExecutionResult> results,
      String? chatContent,
    );
  }
  ```
  - 实现：BookkeepingFeedbackAdapter（根据模式生成记账相关反馈）
  - 集成：调用 LLMResponseGenerator 生成自然语言

**优势**：
1. **可测试性**：可 mock adapter 进行单元测试
2. **可扩展性**：新增业务场景只需实现新 adapter
3. **可复用性**：IntelligenceEngine 可用于其他应用

## 数据流设计

### 完整流程示例

**用户输入**："打车35，吃饭50，打开预算页面"

```
1. MultiOperationRecognizer
   ↓ LLM识别（1.2s）
   {
     operations: [
       {type: "add_transaction", priority: "deferred", amount: 35, category: "交通"},
       {type: "add_transaction", priority: "deferred", amount: 50, category: "餐饮"},
       {type: "navigate", priority: "immediate", targetPage: "预算"}
     ],
     chat_content: null
   }

2. IntelligenceEngine 分发
   ↓
   ExecutionChannel                    ConversationChannel
   ↓                                   ↓
   检测到immediate操作                  检测到mixed模式
   ↓                                   ↓
   立即执行导航（50ms）                 等待执行结果
   ↓                                   ↓
   话题切换触发                         收到2个记账结果
   ↓                                   ↓
   批量执行2笔记账（200ms）             生成响应："已记录2笔，正在打开预算"
   ↓                                   ↓
   回调注入结果                         TTS播放（1s）

总耗时：1.2s(识别) + 0.2s(执行) + 1s(TTS) = 2.4s
对比当前：1.2s(识别) + 0.5s(执行) + 1s(反馈) = 2.7s
```

### 错误处理流程

**场景**：LLM超时 + 部分操作执行失败

```
1. MultiOperationRecognizer
   ↓ LLM超时（3s）
   ↓ 降级到规则兜底
   ↓ Layer 2同义词匹配成功（5ms）
   {operations: [...], chat_content: null}

2. ExecutionChannel
   ↓ 执行操作1：成功
   ↓ 执行操作2：失败（数据库错误）
   ↓ 回调注入结果

3. ConversationChannel
   ↓ 检测到失败结果
   ↓ 生成错误提示："已记录1笔，第2笔记录失败，请重试"
   ↓ TTS播放
```

## 集成策略

### 与现有系统集成

**VoiceServiceCoordinator集成**：
```dart
class VoiceServiceCoordinator {
  IntelligenceEngine? _intelligenceEngine;
  bool _useIntelligenceEngine = false; // 默认false，向后兼容

  Future<VoiceSessionResult> processVoiceCommand(String input) async {
    if (_useIntelligenceEngine && _intelligenceEngine != null) {
      return await _intelligenceEngine.process(input);
    }
    // 保持现有流程不变
    return await _processNormalInput(input);
  }
}
```

**配置开关**：
- 环境变量：`ENABLE_INTELLIGENCE_ENGINE=true`
- 用户设置：Settings → 实验性功能 → 智能语音引擎
- 灰度发布：10% 用户启用 → 监控1周 → 100%发布

### 向后兼容性保证

1. **API不变**：`processVoiceCommand()` 签名保持不变
2. **默认禁用**：新引擎默认关闭，需手动启用
3. **降级机制**：新引擎失败时自动降级到旧流程
4. **数据兼容**：复用现有 MultiIntentResult、ConversationContext

### 修复现有Bug

**Line 348无限递归**：
```dart
// 当前（错误）
Future<void> _speakWithSkipCheck(String text) async {
  if (_skipTTSPlayback) return;
  await _speakWithSkipCheck(text); // 无限递归
}

// 修复后
Future<void> _speakWithSkipCheck(String text) async {
  if (_skipTTSPlayback) return;
  await _ttsService.speak(text); // 调用TTS服务
}
```

## 性能优化

### 延迟优化

**目标**：
- LLM识别：P95 < 3s（当前P95 = 4s）
- 规则兜底：P95 < 50ms（当前P95 = 30ms）
- 聚合触发：< 1.8s（1.5s基础 + 300ms VAD缓冲）
- 导航操作：< 100ms（当前~80ms）

**优化策略**：
1. **LLM超时降低**：5s → 3s（覆盖80%请求）
2. **并行处理**：执行和对话生成同时进行
3. **优先级队列**：immediate操作立即执行
4. **VAD提前触发**：静音检测后300ms触发，比1.5s快1.2s

### 内存优化

**问题**：对话历史无限增长

**解决方案**：
- 限制对话历史：最多保留20轮
- 定期清理：超过1小时的历史自动清除
- 压缩存储：只保留关键信息（意图类型、实体、结果）

## 可扩展性设计

### 支持新业务场景

**示例**：添加购物助手

```dart
// 1. 实现操作适配器
class ShoppingOperationAdapter implements OperationAdapter {
  @override
  Future<ExecutionResult> execute(Operation op) async {
    switch (op.type) {
      case OperationType.addToCart:
        return await _addToCart(op.params);
      case OperationType.searchProduct:
        return await _searchProduct(op.params);
      default:
        return ExecutionResult.unsupported();
    }
  }
}

// 2. 实现反馈适配器
class ShoppingFeedbackAdapter implements FeedbackAdapter {
  @override
  Future<String> generateFeedback(...) async {
    // 生成购物相关反馈
  }
}

// 3. 注册到引擎
final engine = IntelligenceEngine(
  operationAdapter: ShoppingOperationAdapter(),
  feedbackAdapter: ShoppingFeedbackAdapter(),
);
```

### 支持新对话模式

**示例**：添加 tutorial 模式（新手引导）

```dart
enum ConversationMode {
  // ... 现有模式
  tutorial, // 新增：详细解释+操作指导
}

// 在 AdaptiveConversationAgent 中添加检测逻辑
ConversationMode detectMode(...) {
  if (_isNewUser() && _hasConfusion(input)) {
    return ConversationMode.tutorial;
  }
  // ... 现有逻辑
}
```

## 风险缓解

### 技术风险

1. **LLM识别延迟**
   - 风险：P95延迟可能超过3s
   - 缓解：4层规则兜底保证可用性
   - 监控：记录LLM超时率，超过20%时告警

2. **聚合逻辑复杂度**
   - 风险：三种触发机制可能冲突
   - 缓解：状态机设计，明确优先级（immediate > VAD > 基础等待）
   - 测试：单元测试覆盖所有触发场景

3. **对话模式检测不准**
   - 风险：误判导致响应风格不匹配
   - 缓解：保守策略，默认使用详细响应（chatWithIntent）
   - 学习：记录用户纠正，优化检测规则

### 用户体验风险

1. **主动对话打扰用户**
   - 风险：用户不需要时主动发起话题
   - 缓解：频率限制（最多3次）+ 用户可关闭
   - 监控：记录用户拒绝率，超过50%时调整策略

2. **响应风格不符合预期**
   - 风险：quickBookkeeping模式过于简短
   - 缓解：用户可在设置中选择响应风格
   - A/B测试：对比不同风格的用户满意度

## 测试策略

### 单元测试

**覆盖率目标**：≥80%

**关键测试用例**：
1. MultiOperationRecognizer
   - LLM识别成功
   - LLM超时降级
   - 规则兜底各层命中
2. IntelligentAggregator
   - 1.5秒基础触发
   - VAD静音触发
   - 话题切换触发
3. AdaptiveConversationAgent
   - 各模式检测准确性
   - 响应长度符合预期

### 集成测试

**端到端场景**：
1. 多操作识别→执行→反馈完整流程
2. LLM超时→规则兜底→执行成功
3. 主动对话触发→用户拒绝→停止

### 性能测试

**负载测试**：
- 并发100用户，持续10分钟
- 监控：P50/P95/P99延迟，错误率

**压力测试**：
- 逐步增加并发数，找到系统瓶颈
- 目标：支持1000并发用户

## 监控指标

### 功能指标

- **识别准确率**：≥90%（LLM + 规则兜底）
- **LLM超时率**：<20%
- **操作执行成功率**：≥95%
- **对话模式检测准确率**：≥85%

### 性能指标

- **LLM识别延迟**：P95 < 3s
- **规则兜底延迟**：P95 < 50ms
- **聚合触发延迟**：< 1.8s
- **导航操作延迟**：< 100ms

### 用户体验指标

- **用户满意度**：≥4/5
- **主动对话拒绝率**：<50%
- **会话完成率**：≥90%（用户完成意图的比例）

## 总结

本设计通过以下关键决策实现架构升级：

1. **LLM优先+规则兜底**：平衡准确率和响应速度
2. **双通道并行处理**：提升整体响应速度
3. **智能聚合机制**：优化多操作场景体验
4. **自适应对话模式**：匹配不同用户意图
5. **适配器解耦**：提升可复用性和可扩展性

预期收益：
- 响应速度提升10-15%（2.7s → 2.4s）
- 多操作场景体验显著改善
- 代码可复用性提升，支持快速扩展到其他应用
