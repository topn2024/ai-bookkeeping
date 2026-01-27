# 任务清单 v2：对话智能体上下文整合系统

## 概览

基于当前代码（2026-01-27）的实施任务清单

## 阶段1：基础设施 ⏳

### Task 1.1: 创建 ProactiveContext 数据结构
**文件**: `app/lib/services/voice/proactive_context.dart`

```dart
/// 主动对话上下文
class ProactiveContext {
  // 执行结果
  final List<BufferedResult> pendingResults;

  // 用户偏好
  final bool likesProactiveChat;
  final VoiceDialogStyle? dialogStyle;
  final int silenceToleranceSeconds;
  final List<String> sensitiveTactics;

  // 对话历史
  final VoiceAction? lastAction;
  final List<ConversationTurn> recentTurns;

  // 长期记忆
  final List<String> frequentCategories;
  final double avgMonthlySpending;

  // 环境信息
  final DateTime currentTime;

  // 构造函数和便捷方法...
}
```

**依赖**:
- `intelligence_engine/result_buffer.dart` 的 `BufferedResult`
- `agent/voice_action.dart` 的 `VoiceAction`
- `memory/conversation_memory.dart` 的 `ConversationTurn`

**测试**:
- 测试数据结构创建
- 测试便捷访问器（hasPendingResults, timeSlot等）
- 测试toLLMContext()方法

**工作量**: 2-3小时

---

### Task 1.2: 创建 ConversationContextProvider
**文件**: `app/lib/services/voice/conversation_context_provider.dart`

```dart
/// 对话上下文提供者
class ConversationContextProvider {
  final ResultBuffer _resultBuffer;
  final ConversationMemory _conversationMemory;
  final UserProfileService _userProfileService;
  final ContextManager _contextManager;

  // 缓存
  String? _userId;
  UserProfile? _cachedProfile;
  DateTime? _cacheTime;

  // 公共API
  void setUser(String userId);
  Future<ProactiveContext> getProactiveContext();
  Future<UserProfile?> _getCachedProfile();
  void clearCache();
}
```

**依赖**:
- Task 1.1 (ProactiveContext)
- `intelligence_engine/result_buffer.dart`
- `memory/conversation_memory.dart`
- `user_profile_service.dart`
- `agent/context_manager.dart`

**测试**:
- 测试用户切换时缓存清除
- 测试缓存过期（1小时）
- 测试getProactiveContext()返回完整数据
- 测试缺失数据时的默认值

**工作量**: 3-4小时

---

## 阶段2：提示词系统 ⏳

### Task 2.1: 创建 TaskType 枚举和相关类型
**文件**: `app/lib/services/voice/task_type.dart`

```dart
/// LLM任务类型
enum TaskType {
  proactiveWithResults,   // 主动告知（有执行结果）
  proactiveNoResults,     // 主动引导（无执行结果）
  proactiveFarewell,      // 礼貌告别
}
```

**测试**:
- 枚举值测试

**工作量**: 0.5小时

---

### Task 2.2: 创建 VoiceAgentPromptBuilder
**文件**: `app/lib/services/voice/voice_agent_prompt_builder.dart`

```dart
/// 语音助手提示词构建器
class VoiceAgentPromptBuilder {
  String build({
    required TaskType taskType,
    required ProactiveContext context,
    required int proactiveCount,
  });

  // 私有方法
  String _buildRoleSection();
  String _buildProfileSection(ProactiveContext context);
  String _buildContextSection(ProactiveContext context);
  String _buildTaskSection(...);
  String _buildConstraintSection(ProactiveContext context);
  String _getStyleDescription(VoiceDialogStyle? style);
}
```

**依赖**:
- Task 1.1 (ProactiveContext)
- Task 2.1 (TaskType)

**测试**:
- 测试不同TaskType生成不同提示词
- 测试用户偏好正确注入
- 测试上下文信息正确格式化
- 测试输出约束正确生成
- 测试提示词长度合理（不超过2000 tokens）

**工作量**: 3-4小时

---

## 阶段3：增强生成器 ⏳

### Task 3.1: 创建 EnhancedProactiveTopicGenerator
**文件**: `app/lib/services/voice/enhanced_proactive_topic_generator.dart`

```dart
/// 增强的主动话题生成器
class EnhancedProactiveTopicGenerator extends ProactiveTopicGenerator {
  final ConversationContextProvider _contextProvider;
  final QwenService? _llmService;
  final VoiceAgentPromptBuilder _promptBuilder;

  bool _enableLLMGeneration = true;
  int _proactiveCount = 0;

  @override
  Future<ProactiveTopic?> generateTopic(...);

  Future<ProactiveTopic?> _tryLLMGeneration(ProactiveContext context);
  Future<ProactiveTopic?> _ruleBasedGeneration(ProactiveContext context);
  TaskType _determineTaskType(ProactiveContext context);

  void reset();
  void setLLMGeneration(bool enabled);
}
```

**依赖**:
- Task 1.2 (ConversationContextProvider)
- Task 2.2 (VoiceAgentPromptBuilder)
- `proactive_topic_generator.dart` (现有)
- `qwen_service.dart`

**测试**:
- 测试LLM生成成功场景
- 测试LLM超时降级
- 测试LLM失败降级
- 测试规则生成fallback
- 测试Feature flag开关
- 测试用户偏好影响生成决策
- 测试proactiveCount影响任务类型

**工作量**: 4-5小时

---

## 阶段4：组件连接 ⏳

### Task 4.1: 修改 VoiceServiceCoordinator 集成新组件
**文件**: `app/lib/services/voice_service_coordinator.dart`

**修改点**:
1. 添加 `ConversationContextProvider` 成员变量
2. 添加 `EnhancedProactiveTopicGenerator` 成员变量
3. 在初始化方法中创建和连接组件
4. 添加Feature flag控制

```dart
class VoiceServiceCoordinator {
  // 现有组件
  IntelligenceEngine? _intelligenceEngine;
  ConversationMemory? _conversationMemory;

  // 新增组件
  ConversationContextProvider? _contextProvider;
  EnhancedProactiveTopicGenerator? _enhancedTopicGenerator;

  // Feature flag
  bool _useEnhancedTopicGenerator = true;

  void _initializeComponents() {
    // 1. 创建上下文提供者
    _contextProvider = ConversationContextProvider(
      resultBuffer: _intelligenceEngine!.resultBuffer,
      conversationMemory: _conversationMemory!,
      userProfileService: getIt<UserProfileService>(),
      contextManager: getIt<ContextManager>(),
    );

    // 2. 创建增强话题生成器
    _enhancedTopicGenerator = EnhancedProactiveTopicGenerator(
      contextProvider: _contextProvider!,
      llmService: getIt<QwenService>(),
    );

    // 3. 设置Feature flag
    _enhancedTopicGenerator!.setLLMGeneration(_useEnhancedTopicGenerator);
  }

  // 获取话题生成器（根据Feature flag）
  ProactiveTopicGenerator get _topicGenerator {
    return _useEnhancedTopicGenerator && _enhancedTopicGenerator != null
        ? _enhancedTopicGenerator!
        : _fallbackTopicGenerator;
  }
}
```

**测试**:
- 测试组件正确初始化
- 测试Feature flag正确切换
- 测试上下文提供者正确连接
- 测试用户ID设置传递

**工作量**: 2-3小时

---

### Task 4.2: 修改 ProactiveConversationManager 使用新生成器
**文件**: `app/lib/services/voice/proactive_conversation_manager.dart`

**修改点**:
1. 接受 `ProactiveTopicGenerator` 注入（支持新旧两种）
2. 调用 `generateTopic` 时传递更多上下文
3. 处理LLM生成延迟的用户反馈

```dart
class ProactiveConversationManager {
  ProactiveTopicGenerator? _topicGenerator;

  // 设置话题生成器（从VoiceServiceCoordinator注入）
  void setTopicGenerator(ProactiveTopicGenerator generator) {
    _topicGenerator = generator;
  }

  Future<String?> _generateProactiveTopic() async {
    if (_topicGenerator == null) return null;

    try {
      // 调用生成器（新旧都支持）
      final topic = await _topicGenerator!.generateTopic(
        memory: _conversationMemory,
        userProfile: await _getUserProfileSummary(),
        timeContext: TimeContext.now(),
      );

      return topic?.text;
    } catch (e) {
      debugPrint('[ProactiveManager] 生成话题失败: $e');
      return null;
    }
  }
}
```

**测试**:
- 测试旧生成器兼容性
- 测试新生成器集成
- 测试生成失败的处理

**工作量**: 1-2小时

---

### Task 4.3: 添加 Feature Flag 配置
**文件**: `app/lib/services/feature_flag_service.dart` (如果存在)

**添加配置**:
```dart
static const String enhancedTopicGenerator = 'enhanced_topic_generator';
static const String llmTopicGeneration = 'llm_topic_generation';
```

**或直接在 VoiceServiceCoordinator 中添加配置方法**:
```dart
void enableEnhancedTopicGenerator(bool enable) {
  _useEnhancedTopicGenerator = enable;
  _enhancedTopicGenerator?.setLLMGeneration(enable);
}
```

**工作量**: 0.5-1小时

---

## 阶段5：测试与优化 ⏳

### Task 5.1: 单元测试覆盖
**文件**: `app/test/services/voice/...`

- `proactive_context_test.dart`
- `conversation_context_provider_test.dart`
- `voice_agent_prompt_builder_test.dart`
- `enhanced_proactive_topic_generator_test.dart`

**覆盖率目标**: > 80%

**工作量**: 4-5小时

---

### Task 5.2: 集成测试
**测试场景**:
1. 用户记账后主动告知结果
2. 用户偏好 `likesProactiveChat=false` 时静默
3. LLM调用失败时降级到规则生成
4. 不同时间段生成不同引导话题
5. 连续3次主动后礼貌告别

**工作量**: 3-4小时

---

### Task 5.3: 性能监控和优化
**监控指标**:
- LLM调用成功率
- LLM调用平均耗时
- 降级触发频率
- 用户画像缓存命中率
- 平均token消耗

**工作量**: 2-3小时

---

## 阶段6：文档与发布 ⏳

### Task 6.1: 更新文档
- API文档
- 架构图
- 使用指南
- 故障排查

**工作量**: 2小时

---

### Task 6.2: 灰度发布
1. 10%用户启用新功能
2. 监控1-2天
3. 逐步扩大到100%

**工作量**: 监控为主

---

## 总工作量估算

- 阶段1：5-7小时
- 阶段2：3.5-4.5小时
- 阶段3：4-5小时
- 阶段4：3.5-6小时
- 阶段5：9-12小时
- 阶段6：2小时

**总计**: 27-36.5小时（约3.5-5个工作日）

---

## 风险项

1. ⚠️ **LLM服务不稳定** - 缓解：3秒超时+快速降级
2. ⚠️ **提示词调优耗时** - 缓解：先上线基础版本，后续迭代优化
3. ⚠️ **用户画像数据缺失** - 缓解：使用默认值+逐步学习
4. ⚠️ **性能影响** - 缓解：Feature flag控制+监控

---

## 回滚计划

如果出现严重问题：
1. 通过Feature flag立即禁用新功能
2. 回滚到原 ProactiveTopicGenerator
3. 保留新代码，修复后再启用

---

## 依赖检查

- [x] ResultBuffer 已实现
- [x] ConversationMemory 已实现
- [x] UserProfileService 已实现
- [x] ContextManager 已实现
- [x] QwenService 已实现
- [x] ProactiveTopicGenerator 已实现

所有依赖已满足✅
