/// 对话式智能体模块
///
/// 提供"边聊边做"的智能语音交互能力
///
/// 核心组件：
/// - ConversationalAgent: 智能体核心控制器
/// - HybridIntentRouter: 混合意图路由器（LLM优先，规则兜底）
/// - ActionRegistry: 行为注册表
/// - ActionExecutor: 行为执行器
/// - ActionRouter: 行为路由器（意图→服务映射）
/// - ChatEngine: 聊天引擎
/// - ContextManager: 上下文管理器
/// - LLMIntentClassifier: LLM意图分类器
///
/// 使用示例：
/// ```dart
/// final agent = ConversationalAgent();
/// await agent.initialize();
///
/// final response = await agent.process(UserInput.fromVoice('记一笔午饭30块'));
/// print(response.text); // "好的，已记录餐饮30元"
///
/// final chatResponse = await agent.process(UserInput.fromVoice('今天天气不错'));
/// print(chatResponse.text); // 自然的聊天响应
/// ```
library agent;

// 核心智能体
export 'conversational_agent.dart';

// 意图路由
export 'hybrid_intent_router.dart';
export 'llm_intent_classifier.dart';

// 行为系统
export 'action_registry.dart';
export 'action_executor.dart';
export 'action_router.dart';

// 聊天引擎
export 'chat_engine.dart';

// 上下文管理
export 'context_manager.dart';
