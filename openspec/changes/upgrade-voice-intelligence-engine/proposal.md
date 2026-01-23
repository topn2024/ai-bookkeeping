# 变更：智能语音助手架构升级

> **变更ID**: upgrade-voice-intelligence-engine
> **类型**: 架构升级
> **状态**: 草案
> **日期**: 2026-01-18

## 为什么

当前语音助手存在以下限制：

1. **串行处理模式**：用户说完话后，系统依次执行"识别→执行→反馈"，无法同时处理操作和对话
2. **单一意图焦点**：虽然已支持多意图识别（multi-intent-voice-processing），但仍将所有内容视为操作意图，缺少对话内容的独立处理
3. **被动响应模式**：只在用户说话后才响应，缺少主动对话能力，体验机械
4. **紧耦合设计**：VoiceServiceCoordinator 直接依赖业务服务（DatabaseService、VaultRepository等），难以复用到其他应用
5. **固定响应风格**：无论用户意图如何，都使用相同的反馈模式，缺少对话场景适配

这导致：
- 用户说"今天打车花了35，顺便问一下我这个月还能花多少"时，系统只能处理记账或查询，无法同时完成
- 对话体验生硬，缺少人性化交流
- 无法在其他应用中复用语音能力

## 变更内容

### 核心能力升级

#### 1. 多操作识别（Multi-Operation Recognition）
- **当前**：SmartIntentRecognizer 返回单个 SmartIntentResult
- **升级**：LLM 识别返回 JSON 包含 operations 数组 + chat_content 字段
- **示例**：
  ```json
  {
    "operations": [
      {"type": "add_transaction", "amount": 35, "category": "交通"},
      {"type": "query", "queryType": "budget_remaining"}
    ],
    "chat_content": "顺便问一下"
  }
  ```

#### 2. 双通道处理（Dual-Channel Processing）
- **执行通道**：后台处理操作队列，支持优先级和聚合
- **对话通道**：维护对话流，生成自然语言响应
- **协同机制**：执行结果通过回调注入对话上下文

#### 3. 智能聚合（Intelligent Aggregation）
- **基础等待**：1.5秒聚合窗口
- **VAD触发**：检测到1秒静音后300ms内触发执行
- **话题感知**：检测到话题切换立即执行前序操作

#### 4. 自适应对话模式（Adaptive Conversation）
- **chat**：闲聊模式，简短2-3句
- **chatWithIntent**：用户有明确诉求，详细回答
- **quickBookkeeping**：快速记账，极简反馈"✓ 2笔"
- **mixed**：混合模式，简短确认+操作反馈

#### 5. 主动对话管理（Proactive Conversation）
- **触发条件**：30秒无用户输入
- **频率限制**：最多3次主动发起
- **话题生成**：LLM根据用户画像生成话题
- **退出机制**：用户明确拒绝后停止

#### 6. 组件解耦（Component Decoupling）
- **核心层**：可复用的语音能力（识别、对话、聚合）
- **适配层**：业务适配接口（OperationAdapter、FeedbackAdapter）
- **配置层**：业务特定配置（操作类型、优先级规则）

### 与现有变更的关系

本变更**依赖并扩展** `multi-intent-voice-processing` (19/23任务已完成)：
- **复用**：MultiIntentResult 数据结构、分句逻辑
- **扩展**：增加 chat_content 识别、双通道处理、自适应响应
- **不重复**：不修改现有的意图分类和实体提取逻辑

### 保留现有能力

- **4层规则兜底**：完整保留 SmartIntentRecognizer 的 exact rule → synonym → template → learned cache
- **会话管理**：保留 VoiceSessionContext、超时机制、错误恢复
- **多意图确认**：保留 waitingForMultiIntentConfirmation 流程

## 影响

### 受影响代码

#### 新增文件
- `app/lib/services/voice/intelligence_engine/`
  - `multi_operation_recognizer.dart` - 多操作识别器
  - `dual_channel_processor.dart` - 双通道处理器
  - `intelligent_aggregator.dart` - 智能聚合器
  - `adaptive_conversation_agent.dart` - 自适应对话代理
  - `proactive_conversation_manager.dart` - 主动对话管理器
- `app/lib/services/voice/adapters/`
  - `bookkeeping_operation_adapter.dart` - 记账操作适配器
  - `bookkeeping_feedback_adapter.dart` - 记账反馈适配器

#### 修改文件
- `app/lib/services/voice_service_coordinator.dart`
  - 集成 IntelligenceEngine
  - 保持向后兼容（现有 API 不变）
- `app/lib/services/voice/smart_intent_recognizer.dart`
  - 添加 recognizeMultiOperation() 方法
  - LLM 超时从 5s 降至 3s
- `app/lib/services/voice/conversation_context.dart`
  - 添加对话模式检测
  - 添加执行结果注入接口

### 依赖关系

- **前置依赖**：`multi-intent-voice-processing` 必须完成（当前 19/23）
- **并行开发**：可与 `design-adaptive-mode-system` 并行（UI模式系统）
- **后续影响**：为未来的多应用复用奠定基础

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| LLM识别延迟增加 | 中 | 3s超时 + 4层规则兜底 |
| 聚合逻辑复杂度高 | 中 | 分阶段实施，先基础等待后VAD |
| 对话模式检测不准 | 低 | 保守策略，默认详细响应 |
| 主动对话打扰用户 | 中 | 频率限制 + 用户可关闭 |
| 组件解耦增加复杂度 | 低 | 清晰的接口定义 + 文档 |
| 与现有多意图冲突 | 高 | 复用现有结构，仅扩展能力 |

## 验收标准

### 功能验收

1. **多操作识别**
   - 用户说"打车35，吃饭50，打开预算页面"，系统识别出2个记账+1个导航
   - 识别准确率 ≥90%

2. **双通道处理**
   - 记账操作在后台执行，对话立即响应
   - 导航操作立即执行（<100ms）

3. **智能聚合**
   - 用户连续说3笔记账，1.5秒后批量执行
   - VAD检测到静音后300ms内触发
   - 话题切换时立即执行前序操作

4. **自适应对话**
   - 闲聊时简短回复（2-3句）
   - 用户询问时详细回答
   - 快速记账时极简反馈

5. **主动对话**
   - 30秒无输入后主动发起话题
   - 最多3次，用户拒绝后停止
   - 话题与用户画像相关

6. **组件解耦**
   - 核心引擎可独立测试
   - 适配器可替换为其他业务

### 性能验收

- LLM识别延迟：P95 < 3s
- 规则兜底延迟：P95 < 50ms
- 聚合触发延迟：< 1.8s（1.5s + 300ms）
- 导航操作延迟：< 100ms

### 兼容性验收

- 现有 processVoiceCommand() API 保持不变
- 现有多意图确认流程正常工作
- 4层规则兜底完整保留

## 实施计划

详见 [tasks.md](./tasks.md)

## 架构设计

详见 [design.md](./design.md)

## 相关文档

- [多意图处理变更](../multi-intent-voice-processing/proposal.md) - 前置依赖
- [自适应模式系统](../design-adaptive-mode-system/proposal.md) - 并行开发
