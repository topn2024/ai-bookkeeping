# 提案：对话智能体上下文整合系统

## 背景

当前语音助手存在严重的"信息孤岛"问题：

1. **执行结果与主动对话隔离**：用户说"早餐15，午餐20"后，后台执行记账，但5秒后的主动对话却问"需要帮你记账吗？"——用户已经记了！
2. **用户画像未被使用**：`UserProfileService` 已实现完整的用户画像（对话偏好、沉默容忍度、敏感话题），但语音系统完全没有使用
3. **记忆系统未连接**：`ConversationMemory`、`ContextManager` 已实现，但主动对话生成器无法访问
4. **话题生成硬编码**：`SimpleTopicGenerator` 只有固定话题，不能根据上下文动态生成

## 目标

建立统一的上下文系统，让对话智能体能够：
- 获取执行结果并在合适时机告知用户
- 根据用户画像调整对话风格和主动对话策略
- 利用短期和长期记忆生成相关话题
- 通过LLM动态生成话题，而非硬编码

## 核心设计

### 1. 统一上下文提供者

```
ConversationContextProvider（新增）
    │
    ├── 短期记忆
    │   ├── ResultBuffer → 待通知的执行结果
    │   └── ConversationMemory → 对话历史、最近操作
    │
    ├── 长期记忆
    │   └── ContextManager.UserProfile → 常用分类、消费模式
    │
    ├── 用户画像
    │   ├── conversationPreferences → 是否喜欢主动对话
    │   ├── dialogStyle → 对话风格偏好
    │   └── sensitiveTacics → 敏感话题
    │
    └── 环境信息
        └── 当前时间、沉默时长
```

### 2. LLM话题生成器

用 `LLMTopicGenerator` 替代 `SimpleTopicGenerator`：

- 收集上下文 → 构建提示词 → LLM生成话题
- 网络失败时降级为规则生成
- 优先通知执行结果，无结果时生成引导话题

### 3. 提示词分层架构

```
┌─────────────────────────────────────┐
│ 第一层：角色定义（固定）              │
│ - 你是谁、核心职责                   │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│ 第二层：用户画像（会话级缓存）         │
│ - 对话偏好、风格、敏感话题            │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│ 第三层：会话上下文（每轮更新）         │
│ - 待通知结果、对话历史、最近操作       │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│ 第四层：当前任务（每次调用不同）       │
│ - 主动告知/主动引导/礼貌告别          │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│ 第五层：输出约束（固定）              │
│ - 长度限制、禁止事项                  │
└─────────────────────────────────────┘
```

## 范围

### 包含
- ConversationContextProvider 统一上下文提供者
- LLMTopicGenerator 替代 SimpleTopicGenerator
- VoiceAgentPromptBuilder 提示词构建器
- 用户画像与语音系统的连接
- ResultBuffer 与主动对话的连接

### 不包含
- InputFilter（已在 upgrade-intelligent-agent-architecture 中）
- DynamicAggregationWindow（已在 upgrade-intelligent-agent-architecture 中）
- 新的用户画像字段
- UI 层改动

## 影响

### 新增的模块
- `conversation_context_provider.dart` - 统一上下文提供者
- `llm_topic_generator.dart` - LLM话题生成器
- `voice_agent_prompt_builder.dart` - 提示词构建器

### 修改的模块
- `voice_pipeline_controller.dart` - 注入上下文提供者
- `proactive_conversation_manager.dart` - 使用 LLMTopicGenerator
- `voice_service_coordinator.dart` - 组件连接

## 风险

1. **LLM调用延迟**：主动对话生成需要调用LLM，可能增加延迟
   - 缓解：优先使用规则判断，复杂场景才调用LLM
   - 缓解：网络失败时快速降级

2. **提示词膨胀**：上下文信息过多导致token浪费
   - 缓解：信息分层，只传必要信息
   - 缓解：摘要压缩

3. **用户画像缺失**：新用户没有画像数据
   - 缓解：使用默认配置

## 成功标准

1. 用户记账后主动对话能告知"2笔记好了"而非"需要帮你记账吗"
2. 用户画像中 `likesProactiveChat=false` 时，只在有执行结果时才主动说话
3. 话题生成符合用户的对话风格偏好
4. LLM调用失败时能快速降级，用户无明显感知

## 依赖

- `upgrade-intelligent-agent-architecture`：提供 ResultBuffer、TimingJudge
- `UserProfileService`：提供用户画像数据
