# 提案 v2：对话智能体上下文整合系统（2026年适配版）

## 变更历史
- v1: 2025年初始版本
- v2: 2026-01-27 根据最新代码适配更新

## 背景

当前语音助手已经实现了基础架构，但仍存在上下文整合问题：

### 当前实现状态

**已实现**：
- ✅ `ProactiveTopicGenerator` - 基础话题生成器（规则驱动）
- ✅ `ResultBuffer` - 执行结果缓冲
- ✅ `IntelligenceEngine` - 智能引擎
- ✅ `ConversationMemory` - 对话记忆
- ✅ `ContextManager` - 上下文管理器
- ✅ `UserProfileService` - 用户画像服务

**存在问题**：
1. **ProactiveTopicGenerator** 使用硬编码规则，无法根据复杂上下文生成话题
2. **ResultBuffer** 的结果未被主动对话有效利用
3. **UserProfileService** 的数据未被语音系统使用
4. 各个组件之间缺乏统一的上下文传递机制

## 目标

在现有架构基础上：
1. 创建统一的上下文提供者，整合现有组件
2. 增强 `ProactiveTopicGenerator`，支持 LLM 动态生成
3. 建立上下文到 LLM 提示词的转换机制
4. 保持向后兼容，规则生成作为 fallback

## 核心设计

### 1. 统一上下文提供者（新增）

```dart
/// 对话上下文提供者
/// 统一管理和提供所有上下文数据
class ConversationContextProvider {
  // 依赖注入
  final ResultBuffer _resultBuffer;
  final ConversationMemory _conversationMemory;
  final UserProfileService _userProfileService;
  final ContextManager _contextManager;

  // 缓存
  String? _userId;
  UserProfile? _cachedProfile;
  DateTime? _cacheTime;

  /// 设置当前用户
  void setUser(String userId) {
    if (_userId != userId) {
      _userId = userId;
      _cachedProfile = null;
      _cacheTime = null;
    }
  }

  /// 获取主动对话上下文
  Future<ProactiveContext> getProactiveContext() async {
    final profile = await _getCachedProfile();

    return ProactiveContext(
      // 执行结果
      pendingResults: _resultBuffer.getPendingResults(),

      // 用户偏好（从 UserProfileService）
      likesProactiveChat: profile?.conversationPreferences.likesProactiveChat ?? true,
      dialogStyle: profile?.conversationPreferences.dialogStyle,
      silenceToleranceSeconds: profile?.conversationPreferences.silenceToleranceSeconds ?? 5,
      sensitiveTactics: profile?.conversationPreferences.sensitiveTactics ?? [],

      // 对话历史
      lastAction: _conversationMemory.lastAction,
      recentTurns: _conversationMemory.getRecentTurns(3),

      // 长期记忆（从 ContextManager）
      frequentCategories: _contextManager.userProfile.frequentCategories.take(5).toList(),
      avgMonthlySpending: _contextManager.userProfile.avgMonthlySpending,

      // 环境信息
      currentTime: DateTime.now(),
    );
  }

  /// 获取用户画像（带缓存，1小时有效期）
  Future<UserProfile?> _getCachedProfile() async {
    if (_userId == null) return null;

    // 检查缓存
    if (_cachedProfile != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!).inHours < 1) {
        return _cachedProfile;
      }
    }

    // 重新获取
    _cachedProfile = await _userProfileService.getProfile(_userId!);
    _cacheTime = DateTime.now();
    return _cachedProfile;
  }

  /// 清除缓存（用户切换或配置更新时）
  void clearCache() {
    _cachedProfile = null;
    _cacheTime = null;
  }
}
```

### 2. 主动对话上下文数据结构（新增）

```dart
/// 主动对话上下文
/// 包含生成主动话题所需的所有信息
class ProactiveContext {
  // ━━━ 执行结果 ━━━
  final List<BufferedResult> pendingResults;

  // ━━━ 用户偏好 ━━━
  final bool likesProactiveChat;
  final VoiceDialogStyle? dialogStyle;
  final int silenceToleranceSeconds;
  final List<String> sensitiveTactics;

  // ━━━ 对话历史 ━━━
  final VoiceAction? lastAction;
  final List<ConversationTurn> recentTurns;

  // ━━━ 长期记忆 ━━━
  final List<String> frequentCategories;
  final double avgMonthlySpending;

  // ━━━ 环境信息 ━━━
  final DateTime currentTime;

  // ━━━ 便捷访问器 ━━━
  bool get hasPendingResults => pendingResults.isNotEmpty;
  int get pendingResultCount => pendingResults.length;

  String get timeSlot {
    final hour = currentTime.hour;
    if (hour >= 6 && hour < 10) return '早上';
    if (hour >= 10 && hour < 12) return '上午';
    if (hour >= 12 && hour < 14) return '中午';
    if (hour >= 14 && hour < 18) return '下午';
    if (hour >= 18 && hour < 22) return '晚上';
    return '深夜';
  }

  /// 生成LLM上下文摘要
  String toLLMContext() {
    final buffer = StringBuffer();

    // 待通知结果
    if (hasPendingResults) {
      buffer.writeln('待告知：${pendingResultCount}个操作结果');
      for (final result in pendingResults) {
        buffer.writeln('  - ${result.summary}');
      }
    }

    // 对话历史
    if (lastAction != null) {
      buffer.writeln('最近操作：${lastAction!.type} ${lastAction!.params}');
    }

    // 用户特征
    if (frequentCategories.isNotEmpty) {
      buffer.writeln('常用分类：${frequentCategories.take(3).join('、')}');
    }

    // 时间信息
    buffer.writeln('当前时间：${timeSlot}');

    return buffer.toString();
  }
}
```

### 3. 增强 ProactiveTopicGenerator（修改现有）

```dart
/// 增强的主动话题生成器
/// 支持规则生成（快速）和LLM生成（智能）
class EnhancedProactiveTopicGenerator extends ProactiveTopicGenerator {
  final ConversationContextProvider _contextProvider;
  final QwenService? _llmService;  // 可选，用于LLM生成
  final VoiceAgentPromptBuilder _promptBuilder;

  bool _enableLLMGeneration = true;  // Feature flag
  int _proactiveCount = 0;

  EnhancedProactiveTopicGenerator({
    required ConversationContextProvider contextProvider,
    QwenService? llmService,
    ProactiveTopicConfig? config,
  })  : _contextProvider = contextProvider,
        _llmService = llmService,
        _promptBuilder = VoiceAgentPromptBuilder(),
        super(config: config);

  @override
  Future<ProactiveTopic?> generateTopic({
    ConversationMemory? memory,
    UserProfileSummary? userProfile,
    TimeContext? timeContext,
  }) async {
    _proactiveCount++;

    try {
      // 1. 获取完整上下文
      final context = await _contextProvider.getProactiveContext();

      // 2. 快速规则判断
      if (!context.likesProactiveChat && !context.hasPendingResults) {
        debugPrint('[EnhancedTopicGen] 用户不喜欢主动对话，无待通知结果，静默');
        return null;
      }

      // 3. 尝试LLM生成（如果启用）
      if (_enableLLMGeneration && _llmService != null) {
        final llmTopic = await _tryLLMGeneration(context);
        if (llmTopic != null) return llmTopic;
      }

      // 4. 降级到规则生成
      return await _ruleBasedGeneration(context);

    } catch (e) {
      debugPrint('[EnhancedTopicGen] 错误: $e，使用规则生成');
      return await super.generateTopic(
        memory: memory,
        userProfile: userProfile,
        timeContext: timeContext,
      );
    }
  }

  /// LLM生成（智能但较慢）
  Future<ProactiveTopic?> _tryLLMGeneration(ProactiveContext context) async {
    try {
      // 确定任务类型
      final taskType = _determineTaskType(context);

      // 构建提示词
      final prompt = _promptBuilder.build(
        taskType: taskType,
        context: context,
        proactiveCount: _proactiveCount,
      );

      // 调用LLM（3秒超时）
      final response = await _llmService!
          .generateText(prompt)
          .timeout(const Duration(seconds: 3));

      if (response.isEmpty) return null;

      return ProactiveTopic(
        type: _mapTaskTypeToTopicType(taskType),
        text: response.trim(),
        priority: 10,
        data: {'source': 'llm', 'taskType': taskType.toString()},
      );
    } catch (e) {
      debugPrint('[EnhancedTopicGen] LLM生成失败: $e');
      return null;
    }
  }

  /// 规则生成（快速但简单）
  Future<ProactiveTopic?> _ruleBasedGeneration(ProactiveContext context) async {
    // 优先通知执行结果
    if (context.hasPendingResults) {
      return ProactiveTopic(
        type: ProactiveTopicType.resultFeedback,
        text: _generateResultFeedbackText(context),
        priority: 10,
      );
    }

    // 基于时间的引导
    return ProactiveTopic(
      type: ProactiveTopicType.guidance,
      text: _generateTimeBasedGuidance(context),
      priority: 3,
    );
  }

  /// 确定任务类型
  TaskType _determineTaskType(ProactiveContext context) {
    if (_proactiveCount >= 3) {
      return TaskType.proactiveFarewell;
    }
    if (context.hasPendingResults) {
      return TaskType.proactiveWithResults;
    }
    return TaskType.proactiveNoResults;
  }

  String _generateResultFeedbackText(ProactiveContext context) {
    final count = context.pendingResultCount;
    if (count == 1) {
      return '记好了';
    } else {
      return '$count笔都记好了';
    }
  }

  String _generateTimeBasedGuidance(ProactiveContext context) {
    final timeSlot = context.timeSlot;
    switch (timeSlot) {
      case '早上':
        return '早餐记了吗？';
      case '中午':
        return '午餐记了吗？';
      case '晚上':
        return '今天的账记完了吗？';
      default:
        return '还有要记的吗？';
    }
  }

  /// 重置（新会话时）
  void reset() {
    _proactiveCount = 0;
    clearPendingFeedbacks();
  }

  /// 启用/禁用LLM生成
  void setLLMGeneration(bool enabled) {
    _enableLLMGeneration = enabled;
  }

  ProactiveTopicType _mapTaskTypeToTopicType(TaskType taskType) {
    switch (taskType) {
      case TaskType.proactiveWithResults:
        return ProactiveTopicType.resultFeedback;
      case TaskType.proactiveNoResults:
        return ProactiveTopicType.guidance;
      case TaskType.proactiveFarewell:
        return ProactiveTopicType.casual;
    }
  }
}
```

### 4. LLM提示词构建器（新增）

```dart
/// LLM任务类型
enum TaskType {
  proactiveWithResults,   // 主动告知（有执行结果）
  proactiveNoResults,     // 主动引导（无执行结果）
  proactiveFarewell,      // 礼貌告别
}

/// 语音助手提示词构建器
class VoiceAgentPromptBuilder {
  /// 构建完整提示词
  String build({
    required TaskType taskType,
    required ProactiveContext context,
    required int proactiveCount,
  }) {
    final buffer = StringBuffer();

    // 第一层：角色定义
    buffer.writeln(_buildRoleSection());
    buffer.writeln();

    // 第二层：用户偏好
    if (context.dialogStyle != null) {
      buffer.writeln(_buildProfileSection(context));
      buffer.writeln();
    }

    // 第三层：会话上下文
    buffer.writeln(_buildContextSection(context));
    buffer.writeln();

    // 第四层：当前任务
    buffer.writeln(_buildTaskSection(taskType, context, proactiveCount));
    buffer.writeln();

    // 第五层：输出约束
    buffer.writeln(_buildConstraintSection(context));

    return buffer.toString();
  }

  String _buildRoleSection() {
    return '''
# 角色
你是「小白」，AI智能记账助手。
职责：帮助用户快速记账，在合适时机告知操作结果。
原则：简洁（不超过15字）、主动但克制、不说教。''';
  }

  String _buildProfileSection(ProactiveContext context) {
    final styleDesc = _getStyleDescription(context.dialogStyle);
    final categories = context.frequentCategories.take(3).join('、');

    return '''
# 用户偏好
- 对话风格：$styleDesc
- 常用分类：${categories.isNotEmpty ? categories : '未知'}''';
  }

  String _buildContextSection(ProactiveContext context) {
    return '''
# 当前状态
${context.hasPendingResults ? '待告知：${context.pendingResultCount}个操作结果' : '待告知：无'}
当前时间：${context.timeSlot}
${context.lastAction != null ? '最近操作：${context.lastAction!.type}' : ''}''';
  }

  String _buildTaskSection(
    TaskType taskType,
    ProactiveContext context,
    int count,
  ) {
    switch (taskType) {
      case TaskType.proactiveWithResults:
        return '''
# 任务：主动告知
用户沉默了${context.silenceToleranceSeconds}秒，有${context.pendingResultCount}个操作结果待告知。
请生成一句话告知用户，可顺便询问是否还有其他要记的。''';

      case TaskType.proactiveNoResults:
        return '''
# 任务：主动引导
用户沉默了${context.silenceToleranceSeconds}秒，无待告知结果。
请根据当前时间（${context.timeSlot}）生成一句引导话题。
示例：中午可问"午餐记了吗"，晚上可问"今天的账记完了吗"。''';

      case TaskType.proactiveFarewell:
        return '''
# 任务：礼貌告别
用户已连续${count}次沉默，即将结束会话。
请生成一句简短告别语，表示随时可用。''';
    }
  }

  String _buildConstraintSection(ProactiveContext context) {
    return '''
# 输出要求
- 直接输出回复，不要任何解释或前缀
- 不超过15字
- 语气${_getStyleDescription(context.dialogStyle)}
- 禁止使用表情符号''';
  }

  String _getStyleDescription(VoiceDialogStyle? style) {
    if (style == null) return '自然友好';

    switch (style) {
      case VoiceDialogStyle.professional:
        return '专业简洁';
      case VoiceDialogStyle.playful:
        return '轻松活泼';
      case VoiceDialogStyle.supportive:
        return '温暖鼓励';
      case VoiceDialogStyle.casual:
        return '随意简短';
      default:
        return '自然友好';
    }
  }
}
```

## 范围

### 包含
- ✅ ConversationContextProvider 统一上下文提供者
- ✅ ProactiveContext 数据结构
- ✅ EnhancedProactiveTopicGenerator 增强话题生成器
- ✅ VoiceAgentPromptBuilder 提示词构建器
- ✅ 组件连接和集成

### 不包含
- ❌ 修改 UserProfileService 数据结构
- ❌ 新增用户画像字段
- ❌ UI 层改动
- ❌ 语音识别/合成优化

## 实施策略

### 阶段1：基础设施（1-2天）
1. 创建 `ConversationContextProvider`
2. 创建 `ProactiveContext` 数据结构
3. 单元测试

### 阶段2：提示词系统（1天）
1. 创建 `VoiceAgentPromptBuilder`
2. 编写提示词模板
3. 测试提示词生成

### 阶段3：增强生成器（1-2天）
1. 创建 `EnhancedProactiveTopicGenerator`
2. 实现LLM调用逻辑
3. 实现降级策略
4. 集成测试

### 阶段4：组件连接（1天）
1. 修改 `VoiceServiceCoordinator` 完成组件连接
2. 修改 `ProactiveConversationManager` 使用新生成器
3. Feature flag 控制启用/禁用
4. 端到端测试

### 回滚计划
- 保留原 `ProactiveTopicGenerator` 作为 fallback
- Feature flag 控制新功能启用
- LLM调用失败自动降级到规则生成
- 发现问题可立即回滚

## 风险与缓解

### 风险1：LLM调用延迟
- **风险**：增加主动对话响应时间
- **缓解**：
  - 3秒超时，快速失败
  - 失败时立即降级到规则生成
  - 监控LLM调用成功率

### 风险2：提示词token消耗
- **风险**：上下文过多导致成本增加
- **缓解**：
  - 信息分层，只传必要信息
  - 摘要压缩长对话历史
  - 监控平均token消耗

### 风险3：用户画像缺失
- **风险**：新用户没有画像数据
- **缓解**：
  - 使用默认配置
  - 逐步学习用户偏好
  - 规则生成始终可用

## 成功标准

1. ✅ 用户记账后主动对话能告知"X笔记好了"
2. ✅ 用户画像中 `likesProactiveChat=false` 时正确静默
3. ✅ LLM生成的话题符合用户对话风格
4. ✅ LLM失败时能在1秒内降级，用户无感知
5. ✅ 主动对话响应时间 < 5秒

## 依赖

- `ResultBuffer` - 提供执行结果
- `UserProfileService` - 提供用户画像
- `ConversationMemory` - 提供对话历史
- `ContextManager` - 提供长期记忆
- `QwenService` - 提供LLM能力（可选）

## 后续计划

1. 收集LLM生成质量数据
2. 优化提示词模板
3. 增加更多上下文信号
4. 支持多轮对话规划
