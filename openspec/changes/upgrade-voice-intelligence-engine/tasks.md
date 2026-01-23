# 实施任务

## 前置依赖

- ✅ `multi-intent-voice-processing` 变更完成（当前 19/23 任务）

## 阶段 1：基础架构（必须优先完成）

### 1.1 扩展 SmartIntentRecognizer 支持多操作识别
- **文件**: `app/lib/services/voice/smart_intent_recognizer.dart`
- **内容**:
  - 添加 `recognizeMultiOperation()` 方法
  - 修改 LLM prompt 返回 `{operations: [...], chat_content: "..."}`
  - LLM 超时从 5s 降至 3s
  - 保持现有 `recognize()` 方法向后兼容
- **验收**:
  - 单元测试：输入"打车35，吃饭50"返回2个操作+空chat_content
  - 单元测试：输入"打车35，顺便问一下预算"返回1个操作+chat_content
  - LLM 超时测试：3s 后降级到规则兜底
- **依赖**: 无
- **预计**: 4小时

### 1.2 创建 IntelligenceEngine 基础结构
- **文件**: `app/lib/services/voice/intelligence_engine/intelligence_engine.dart`
- **内容**:
  - 定义 `IntelligenceEngine` 类
  - 定义 `OperationAdapter` 接口
  - 定义 `FeedbackAdapter` 接口
  - 定义 `OperationPriority` 枚举（immediate/normal/deferred/background）
  - 定义 `ConversationMode` 枚举（chat/chatWithIntent/quickBookkeeping/mixed）
- **验收**:
  - 编译通过
  - 接口文档完整
- **依赖**: 无
- **预计**: 2小时

### 1.3 创建数据模型
- **文件**: `app/lib/services/voice/intelligence_engine/models.dart`
- **内容**:
  - `Operation` 类（type, priority, params, originalText）
  - `ExecutionResult` 类（success, data, error）
  - `ConversationContext` 扩展（添加 executionResults 字段）
- **验收**:
  - 单元测试：模型序列化/反序列化
- **依赖**: 无
- **预计**: 2小时

## 阶段 2：核心能力实现（部分可并行）

### 2.1 实现 MultiOperationRecognizer
- **文件**: `app/lib/services/voice/intelligence_engine/multi_operation_recognizer.dart`
- **内容**:
  - 调用 `SmartIntentRecognizer.recognizeMultiOperation()`
  - 解析 operations 数组和 chat_content
  - 分类操作优先级（immediate/normal/deferred/background）
  - 过滤噪音内容
- **验收**:
  - 单元测试：识别2个记账+1个导航
  - 单元测试：正确分类优先级
  - 单元测试：过滤"顺便说一下"等噪音
- **依赖**: 1.1, 1.2, 1.3
- **预计**: 6小时

### 2.2 实现 DualChannelProcessor（执行通道）
- **文件**: `app/lib/services/voice/intelligence_engine/dual_channel_processor.dart`
- **内容**:
  - 实现 `ExecutionChannel` 类
  - 优先级队列管理
  - 操作聚合逻辑（基础1.5秒窗口）
  - 通过 `OperationAdapter` 执行操作
  - 执行结果回调机制
- **验收**:
  - 单元测试：immediate 操作立即执行
  - 单元测试：deferred 操作等待1.5秒聚合
  - 单元测试：执行结果正确回调
- **依赖**: 1.2, 1.3
- **预计**: 8小时
- **可并行**: 与 2.3 并行

### 2.3 实现 DualChannelProcessor（对话通道）
- **文件**: `app/lib/services/voice/intelligence_engine/dual_channel_processor.dart`
- **内容**:
  - 实现 `ConversationChannel` 类
  - 维护对话流
  - 接收执行结果并注入上下文
  - 通过 `FeedbackAdapter` 生成响应
- **验收**:
  - 单元测试：对话上下文正确维护
  - 单元测试：执行结果正确注入
  - 单元测试：响应生成符合对话模式
- **依赖**: 1.2, 1.3
- **预计**: 6小时
- **可并行**: 与 2.2 并行

### 2.4 实现 IntelligentAggregator
- **文件**: `app/lib/services/voice/intelligence_engine/intelligent_aggregator.dart`
- **内容**:
  - 基础等待：1.5秒聚合窗口
  - VAD 触发：检测到1秒静音后300ms内触发
  - 话题感知：检测话题切换立即执行前序操作
  - 与 `BargeInDetector` 集成
- **验收**:
  - 单元测试：1.5秒后自动触发
  - 集成测试：VAD 静音检测触发（需要 mock BargeInDetector）
  - 单元测试：话题切换检测（"打车35，打开预算"立即执行打车）
- **依赖**: 2.2
- **预计**: 8小时

### 2.5 实现 AdaptiveConversationAgent
- **文件**: `app/lib/services/voice/intelligence_engine/adaptive_conversation_agent.dart`
- **内容**:
  - 对话模式检测（chat/chatWithIntent/quickBookkeeping/mixed）
  - 根据模式生成不同风格响应
  - 与 `LLMResponseGenerator` 集成
- **验收**:
  - 单元测试：闲聊检测返回 chat 模式
  - 单元测试：用户询问检测返回 chatWithIntent 模式
  - 单元测试：快速记账检测返回 quickBookkeeping 模式
  - 单元测试：混合场景检测返回 mixed 模式
  - 集成测试：不同模式生成不同长度响应
- **依赖**: 1.2, 1.3
- **预计**: 8小时
- **可并行**: 与 2.2, 2.3 并行

### 2.6 实现 ProactiveConversationManager
- **文件**: `app/lib/services/voice/intelligence_engine/proactive_conversation_manager.dart`
- **内容**:
  - 30秒无输入计时器
  - 最多3次主动发起限制
  - LLM 生成话题（基于用户画像）
  - 用户拒绝检测和退出机制
- **验收**:
  - 单元测试：30秒后触发主动对话
  - 单元测试：3次后停止
  - 单元测试：用户拒绝后停止
  - 集成测试：LLM 生成话题（需要 mock QwenService）
- **依赖**: 1.2, 1.3
- **预计**: 6小时
- **可并行**: 与 2.2, 2.3, 2.5 并行

## 阶段 3：业务适配器实现（依赖阶段2）

### 3.1 实现 BookkeepingOperationAdapter
- **文件**: `app/lib/services/voice/adapters/bookkeeping_operation_adapter.dart`
- **内容**:
  - 实现 `OperationAdapter` 接口
  - 处理记账操作（add_transaction）
  - 处理查询操作（query）
  - 处理导航操作（navigate）
  - 处理删除/修改操作（delete/modify）
  - 与现有服务集成（DatabaseService, VoiceNavigationService 等）
- **验收**:
  - 单元测试：记账操作正确执行
  - 单元测试：查询操作返回正确结果
  - 单元测试：导航操作触发路由跳转
  - 集成测试：与 DatabaseService 集成
- **依赖**: 2.2
- **预计**: 8小时

### 3.2 实现 BookkeepingFeedbackAdapter
- **文件**: `app/lib/services/voice/adapters/bookkeeping_feedback_adapter.dart`
- **内容**:
  - 实现 `FeedbackAdapter` 接口
  - 根据对话模式生成反馈
  - chat 模式：简短2-3句
  - chatWithIntent 模式：详细回答
  - quickBookkeeping 模式：极简"✓ 2笔"
  - mixed 模式：简短确认+操作反馈
  - 与 `LLMResponseGenerator` 集成
- **验收**:
  - 单元测试：chat 模式生成简短响应
  - 单元测试：chatWithIntent 模式生成详细响应
  - 单元测试：quickBookkeeping 模式生成极简响应
  - 单元测试：mixed 模式生成混合响应
- **依赖**: 2.3, 2.5
- **预计**: 6小时

## 阶段 4：集成与向后兼容（依赖阶段3）

### 4.1 集成 IntelligenceEngine 到 VoiceServiceCoordinator
- **文件**: `app/lib/services/voice_service_coordinator.dart`
- **内容**:
  - 添加 `IntelligenceEngine` 实例
  - 添加 `useIntelligenceEngine` 配置开关（默认 false）
  - 修改 `processVoiceCommand()` 支持新引擎
  - 保持现有 API 完全向后兼容
  - 修复 line 348 的无限递归 bug（`_speakWithSkipCheck` 应调用 `_ttsService.speak`）
- **验收**:
  - 单元测试：`useIntelligenceEngine=false` 时行为不变
  - 单元测试：`useIntelligenceEngine=true` 时使用新引擎
  - 集成测试：现有多意图确认流程正常工作
  - 回归测试：所有现有语音功能正常
- **依赖**: 2.1, 2.2, 2.3, 3.1, 3.2
- **预计**: 10小时

### 4.2 扩展 ConversationContext 支持执行结果注入
- **文件**: `app/lib/services/voice/conversation_context.dart`
- **内容**:
  - 添加 `addExecutionResult()` 方法
  - 添加对话模式检测方法
  - 维护执行结果历史（用于对话生成）
- **验收**:
  - 单元测试：执行结果正确注入
  - 单元测试：对话模式检测准确
  - 单元测试：历史记录正确维护
- **依赖**: 1.3, 2.3
- **预计**: 4小时

### 4.3 更新 UI 显示多操作反馈
- **文件**: `app/lib/pages/enhanced_voice_assistant_page.dart`
- **内容**:
  - 显示多操作识别结果
  - 显示聚合等待状态
  - 显示主动对话提示
  - 支持快速确认/取消
- **验收**:
  - UI 测试：多操作正确显示
  - UI 测试：聚合倒计时显示
  - UI 测试：主动对话样式区分
  - 用户体验测试：交互流畅
- **依赖**: 4.1
- **预计**: 6小时

## 阶段 5：测试与优化（依赖阶段4）

### 5.1 添加单元测试
- **文件**: `app/test/services/voice/intelligence_engine/`
- **内容**:
  - 所有核心组件的单元测试
  - 覆盖率 ≥ 80%
- **验收**:
  - 所有测试通过
  - 覆盖率报告达标
- **依赖**: 4.1, 4.2, 4.3
- **预计**: 12小时

### 5.2 添加集成测试
- **文件**: `app/test/integration/voice_intelligence_test.dart`
- **内容**:
  - 端到端场景测试
  - 多操作识别→执行→反馈完整流程
  - VAD 触发聚合测试
  - 主动对话触发测试
- **验收**:
  - 所有集成测试通过
  - 场景覆盖完整
- **依赖**: 4.1, 4.2, 4.3
- **预计**: 8小时

### 5.3 性能优化
- **内容**:
  - LLM 识别延迟优化（P95 < 3s）
  - 规则兜底延迟优化（P95 < 50ms）
  - 聚合触发延迟优化（< 1.8s）
  - 导航操作延迟优化（< 100ms）
  - 内存占用优化
- **验收**:
  - 性能测试报告
  - 所有指标达标
- **依赖**: 5.1, 5.2
- **预计**: 8小时

### 5.4 用户验收测试
- **内容**:
  - 准备测试场景（10个典型用例）
  - 邀请内部用户测试
  - 收集反馈并修复问题
- **验收**:
  - 识别准确率 ≥ 90%
  - 用户满意度 ≥ 4/5
  - 无阻塞性 bug
- **依赖**: 5.3
- **预计**: 16小时

## 阶段 6：文档与发布（依赖阶段5）

### 6.1 编写开发者文档
- **文件**: `docs/voice-intelligence-engine.md`
- **内容**:
  - 架构设计说明
  - API 使用指南
  - 适配器开发指南
  - 故障排查指南
- **验收**:
  - 文档完整清晰
  - 代码示例可运行
- **依赖**: 5.4
- **预计**: 6小时

### 6.2 编写用户文档
- **文件**: `docs/user-guide-voice-assistant.md`
- **内容**:
  - 多操作语音输入指南
  - 对话模式说明
  - 主动对话功能说明
  - 常见问题解答
- **验收**:
  - 文档易懂
  - 覆盖主要功能
- **依赖**: 5.4
- **预计**: 4小时

### 6.3 灰度发布
- **内容**:
  - 配置 `useIntelligenceEngine` 开关
  - 10% 用户启用新引擎
  - 监控错误率和性能指标
  - 收集用户反馈
- **验收**:
  - 错误率 < 1%
  - 性能指标达标
  - 无严重用户投诉
- **依赖**: 6.1, 6.2
- **预计**: 40小时（1周监控）

### 6.4 全量发布
- **内容**:
  - 100% 用户启用新引擎
  - 移除旧代码路径（可选）
  - 更新默认配置
- **验收**:
  - 全量发布平稳
  - 监控指标正常
- **依赖**: 6.3
- **预计**: 8小时

## 总结

- **总任务数**: 27
- **预计总工时**: 约 180 小时（约 4.5 周，单人全职）
- **关键路径**: 1.1 → 2.1 → 2.2 → 3.1 → 4.1 → 5.1 → 5.2 → 5.3 → 5.4 → 6.3 → 6.4
- **可并行任务**:
  - 阶段2：2.2, 2.3, 2.5, 2.6 可部分并行
  - 阶段3：3.1, 3.2 可并行
  - 阶段5：5.1, 5.2 可并行

## 风险缓解

- **LLM 识别延迟**: 阶段1.1 优先实现，尽早验证3s超时可行性
- **聚合逻辑复杂度**: 阶段2.4 分步实施（先基础等待，后VAD，最后话题感知）
- **向后兼容性**: 阶段4.1 通过配置开关和完整回归测试保证
- **用户体验**: 阶段5.4 用户验收测试提前发现问题
