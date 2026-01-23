# 任务清单：对话智能体上下文整合系统

## 1. 基础设施

- [ ] 1.1 创建 `ProactiveContext` 数据结构
  - 文件：`lib/services/voice/intelligence_engine/proactive_context.dart`
  - 包含：执行结果、用户偏好、对话历史、长期记忆、环境信息

- [ ] 1.2 创建 `ConversationContextProvider` 统一上下文提供者
  - 文件：`lib/services/voice/intelligence_engine/conversation_context_provider.dart`
  - 依赖：ResultBuffer, ConversationMemory, UserProfileService, ContextManager
  - 方法：`getProactiveContext()`, `getContextForLLM()`

- [ ] 1.3 单元测试
  - 文件：`test/services/voice/conversation_context_provider_test.dart`
  - 测试用例：上下文组装、缓存行为、边界情况

## 2. 提示词系统

- [ ] 2.1 定义 `TaskType` 枚举
  - 文件：`lib/services/voice/intelligence_engine/proactive_context.dart`
  - 类型：proactiveWithResults, proactiveNoResults, proactiveFarewell

- [ ] 2.2 创建 `VoiceAgentPromptBuilder` 提示词构建器
  - 文件：`lib/services/voice/intelligence_engine/voice_agent_prompt_builder.dart`
  - 方法：`build(taskType, context, proactiveCount)`
  - 分层：角色定义、用户画像、会话上下文、任务指令、输出约束

- [ ] 2.3 单元测试
  - 文件：`test/services/voice/voice_agent_prompt_builder_test.dart`
  - 测试用例：各任务类型的提示词生成、风格适配

## 3. LLM话题生成器

- [ ] 3.1 创建 `LLMTopicGenerator` 实现 `ProactiveTopicGenerator` 接口
  - 文件：`lib/services/voice/intelligence_engine/llm_topic_generator.dart`
  - 依赖：ConversationContextProvider, VoiceAgentPromptBuilder, LLMService
  - 方法：`generateTopic()`, `reset()`

- [ ] 3.2 实现降级策略
  - LLM超时（3秒）时降级
  - 网络失败时降级
  - 降级规则：有结果→通知结果，无结果→静默

- [ ] 3.3 集成测试
  - 文件：`test/services/voice/llm_topic_generator_test.dart`
  - 测试用例：正常生成、超时降级、用户偏好处理

## 4. 组件连接

- [ ] 4.1 修改 `VoiceServiceCoordinator`
  - 文件：`lib/services/voice_service_coordinator.dart`
  - 改动：初始化 ConversationContextProvider, LLMTopicGenerator
  - 改动：设置用户ID传递

- [ ] 4.2 修改 `ProactiveConversationManager`
  - 文件：`lib/services/voice/intelligence_engine/proactive_conversation_manager.dart`
  - 改动：支持注入 `ProactiveTopicGenerator`（不再硬编码 SimpleTopicGenerator）

- [ ] 4.3 修改 `VoicePipelineController`
  - 文件：`lib/services/voice/pipeline/voice_pipeline_controller.dart`
  - 改动：支持设置 TopicGenerator

- [ ] 4.4 暴露 `IntelligenceEngine.resultBuffer`
  - 文件：`lib/services/voice/intelligence_engine/intelligence_engine.dart`
  - 改动：添加 getter 供外部访问

## 5. 端到端验证

- [ ] 5.1 场景测试：记账后主动告知
  - 用户说"早餐15，午餐20"
  - 等待5秒
  - 验证主动对话内容包含"2笔记好了"

- [ ] 5.2 场景测试：用户偏好控制
  - 设置 likesProactiveChat=false
  - 用户沉默5秒（无待通知结果）
  - 验证不触发主动对话

- [ ] 5.3 场景测试：风格适配
  - 设置 dialogStyle=playful
  - 触发主动对话
  - 验证话题风格轻松活泼

- [ ] 5.4 场景测试：降级策略
  - 模拟LLM超时
  - 验证快速降级到规则生成
  - 验证用户无明显感知延迟

## 6. 文档更新

- [ ] 6.1 更新 design.md 添加最终实现细节
- [ ] 6.2 更新 CLAUDE.md 如有需要
