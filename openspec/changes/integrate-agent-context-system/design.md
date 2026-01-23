# 设计文档：对话智能体上下文整合系统

## 上下文

### 当前架构问题

```
VoiceServiceCoordinator
├── _intelligenceEngine
│   ├── resultBuffer ✓ (执行结果)
│   └── timingJudge ✓ (时机判断)
│
├── VoicePipelineController
│   └── _proactiveManager
│       └── SimpleTopicGenerator ← 硬编码话题，无法访问任何上下文
│
└── 其他组件...

UserProfileService ← 未连接
ConversationMemory ← 未连接
ProfileDrivenDialogService ← 未连接
```

### 目标架构

```
VoiceServiceCoordinator
├── _contextProvider (新增：统一入口)
│   ├── resultBuffer → 待通知结果
│   ├── conversationMemory → 对话历史
│   ├── userProfileService → 用户画像
│   └── contextManager → 长期记忆
│
├── _intelligenceEngine
│   └── (通过 _contextProvider 获取上下文)
│
└── VoicePipelineController
    └── _proactiveManager
        └── LLMTopicGenerator (新增)
            └── (通过 _contextProvider 获取上下文)
```

## 目标 / 非目标

### 目标
- 建立统一的上下文获取接口
- 让主动对话能够访问执行结果
- 让LLM生成话题时能获取完整上下文
- 设计清晰的提示词分层架构

### 非目标
- 修改用户画像的数据结构
- 优化LLM调用性能
- 新增记忆类型

## 决策

### 1. 上下文提供者设计

**决策**：创建 `ConversationContextProvider` 作为统一入口

```dart
/// 对话上下文提供者
class ConversationContextProvider {
  final ResultBuffer _resultBuffer;
  final ConversationMemory _conversationMemory;
  final UserProfileService _userProfileService;
  final ContextManager _contextManager;

  String? _userId;
  UserProfile? _cachedProfile;

  /// 设置当前用户
  void setUser(String userId) {
    _userId = userId;
    _cachedProfile = null; // 清除缓存
  }

  /// 获取主动对话上下文
  Future<ProactiveContext> getProactiveContext() async {
    final profile = await _getCachedProfile();

    return ProactiveContext(
      // 执行结果
      pendingResults: _resultBuffer.pendingResults,
      resultsSummary: _resultBuffer.getSummaryForContext(),

      // 用户偏好
      likesProactiveChat: profile?.conversationPreferences.likesProactiveChat ?? true,
      silenceToleranceSeconds: profile?.conversationPreferences.silenceToleranceSeconds ?? 5,
      dialogStyle: profile?.conversationPreferences.dialogStyle,

      // 对话历史
      lastAction: _conversationMemory.lastAction,
      recentTurns: _conversationMemory.turns.take(3).toList(),

      // 长期记忆
      frequentCategories: _contextManager.userProfile.frequentCategories.take(3).toList(),

      // 环境信息
      currentTime: DateTime.now(),
    );
  }

  /// 获取LLM上下文摘要
  Future<String> getContextForLLM() async {
    final parts = <String>[];

    // 1. 用户画像摘要
    final profile = await _getCachedProfile();
    if (profile != null && profile.hasEnoughData) {
      parts.add(profile.toPromptSummary());
    }

    // 2. 对话历史
    final history = _conversationMemory.getContextForLLM();
    if (history.isNotEmpty) {
      parts.add(history);
    }

    // 3. 执行结果
    final results = _resultBuffer.getSummaryForContext();
    if (results != null) {
      parts.add(results);
    }

    // 4. 长期记忆
    final longTerm = _contextManager.generateSummary();
    if (longTerm.isNotEmpty) {
      parts.add(longTerm);
    }

    return parts.join('\n\n');
  }

  /// 获取缓存的用户画像
  Future<UserProfile?> _getCachedProfile() async {
    if (_userId == null) return null;

    // 1小时缓存
    if (_cachedProfile != null) {
      return _cachedProfile;
    }

    _cachedProfile = await _userProfileService.getProfile(_userId!);
    return _cachedProfile;
  }
}
```

**考虑的替代方案**：
- 直接在每个组件中注入所需依赖 → 代码重复，难以维护
- 使用全局单例 → 难以测试，隐式依赖

**选择理由**：统一入口便于管理，易于测试，依赖关系清晰

### 2. 主动对话上下文数据结构

**决策**：设计专门的 `ProactiveContext` 类

```dart
/// 主动对话上下文
class ProactiveContext {
  // ━━━ 执行结果 ━━━
  /// 待通知的执行结果列表
  final List<BufferedResult> pendingResults;

  /// 执行结果摘要（供LLM使用）
  final String? resultsSummary;

  // ━━━ 用户偏好 ━━━
  /// 是否喜欢主动对话
  final bool likesProactiveChat;

  /// 沉默容忍度（秒）
  final int silenceToleranceSeconds;

  /// 对话风格
  final VoiceDialogStyle? dialogStyle;

  // ━━━ 对话历史 ━━━
  /// 最近操作
  final VoiceAction? lastAction;

  /// 最近对话轮次
  final List<ConversationTurn> recentTurns;

  // ━━━ 长期记忆 ━━━
  /// 常用分类
  final List<String> frequentCategories;

  // ━━━ 环境信息 ━━━
  /// 当前时间
  final DateTime currentTime;

  /// 是否有待通知结果
  bool get hasPendingResults => pendingResults.isNotEmpty;

  /// 待通知结果数量
  int get pendingResultCount => pendingResults.length;

  /// 当前时段
  String get timeSlot {
    final hour = currentTime.hour;
    if (hour >= 6 && hour < 10) return '早上';
    if (hour >= 10 && hour < 12) return '上午';
    if (hour >= 12 && hour < 14) return '中午';
    if (hour >= 14 && hour < 18) return '下午';
    if (hour >= 18 && hour < 22) return '晚上';
    return '深夜';
  }
}
```

### 3. LLM话题生成器设计

**决策**：`LLMTopicGenerator` 实现 `ProactiveTopicGenerator` 接口

```dart
/// LLM话题生成器
class LLMTopicGenerator implements ProactiveTopicGenerator {
  final ConversationContextProvider _contextProvider;
  final VoiceAgentPromptBuilder _promptBuilder;
  final LLMService _llmService;

  /// 当前主动次数（用于生成不同类型话题）
  int _proactiveCount = 0;

  @override
  Future<String?> generateTopic() async {
    _proactiveCount++;

    try {
      // 1. 获取上下文
      final context = await _contextProvider.getProactiveContext();

      // 2. 检查用户偏好
      if (!context.likesProactiveChat && !context.hasPendingResults) {
        // 用户不喜欢主动对话，且没有待通知结果 → 静默
        debugPrint('[LLMTopicGenerator] 用户不喜欢主动对话，无待通知结果，静默');
        return null;
      }

      // 3. 确定任务类型
      final taskType = _determineTaskType(context);

      // 4. 构建提示词
      final prompt = _promptBuilder.build(
        taskType: taskType,
        context: context,
        proactiveCount: _proactiveCount,
      );

      // 5. 调用LLM
      final response = await _llmService.generate(prompt).timeout(
        const Duration(seconds: 3),
      );

      return response?.trim();
    } catch (e) {
      debugPrint('[LLMTopicGenerator] LLM调用失败: $e，使用降级策略');
      return _fallbackTopic();
    }
  }

  /// 确定任务类型
  TaskType _determineTaskType(ProactiveContext context) {
    if (_proactiveCount >= 3) {
      return TaskType.proactiveFarewell; // 第3次，告别
    }

    if (context.hasPendingResults) {
      return TaskType.proactiveWithResults; // 有待通知结果
    }

    return TaskType.proactiveNoResults; // 无待通知结果，引导话题
  }

  /// 降级话题（LLM失败时）
  Future<String?> _fallbackTopic() async {
    final context = await _contextProvider.getProactiveContext();

    // 优先通知执行结果
    if (context.hasPendingResults) {
      final count = context.pendingResultCount;
      return count == 1 ? '记好了' : '$count笔都记好了';
    }

    // 否则静默（不使用硬编码话题）
    return null;
  }

  /// 重置（新会话时调用）
  void reset() {
    _proactiveCount = 0;
  }
}
```

### 4. 提示词构建器设计

**决策**：分层构建，按任务类型生成不同提示词

```dart
/// 任务类型
enum TaskType {
  proactiveWithResults,  // 主动告知（有执行结果）
  proactiveNoResults,    // 主动引导（无执行结果）
  proactiveFarewell,     // 礼貌告别（第3次）
}

/// 提示词构建器
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

    // 第二层：用户画像
    buffer.writeln(_buildProfileSection(context));

    // 第三层：会话上下文
    buffer.writeln(_buildContextSection(context));

    // 第四层：任务指令
    buffer.writeln(_buildTaskSection(taskType, context, proactiveCount));

    // 第五层：输出约束
    buffer.writeln(_buildConstraintSection(context));

    return buffer.toString();
  }

  String _buildRoleSection() {
    return '''
# 角色
你是「小白」，一个智能记账助手。
职责：帮助用户快速记账，在合适时机告知操作结果。
原则：简洁（不超过15字）、主动但克制、不说教。
''';
  }

  String _buildProfileSection(ProactiveContext context) {
    if (context.dialogStyle == null) return '';

    return '''
# 用户偏好
- 风格：${_getStyleDescription(context.dialogStyle)}
- 常用分类：${context.frequentCategories.join('、')}
''';
  }

  String _buildContextSection(ProactiveContext context) {
    final buffer = StringBuffer();
    buffer.writeln('# 当前状态');

    // 待通知结果
    if (context.hasPendingResults) {
      buffer.writeln('待告知：${context.resultsSummary}');
    } else {
      buffer.writeln('待告知：无');
    }

    // 时间
    buffer.writeln('时间：${context.timeSlot}');

    // 最近操作
    if (context.lastAction != null) {
      buffer.writeln('最近操作：${context.lastAction!.category ?? ''} ${context.lastAction!.amount ?? ''}元');
    }

    return buffer.toString();
  }

  String _buildTaskSection(TaskType taskType, ProactiveContext context, int count) {
    switch (taskType) {
      case TaskType.proactiveWithResults:
        return '''
# 任务：主动告知
用户沉默了5秒，有${context.pendingResultCount}笔记账结果待告知。
请生成一句话告知用户，可顺便询问是否还有其他要记的。
''';

      case TaskType.proactiveNoResults:
        return '''
# 任务：主动引导
用户沉默了5秒，无待告知结果。
请根据当前时间(${context.timeSlot})生成一句引导话题。
示例：中午可问"午餐记了吗"，晚上可问"今天的账记完了吗"。
''';

      case TaskType.proactiveFarewell:
        return '''
# 任务：礼貌告别
用户已连续${count}次沉默，即将结束会话。
请生成一句简短告别语，表示随时可用。
''';
    }
  }

  String _buildConstraintSection(ProactiveContext context) {
    return '''
# 输出要求
- 直接输出回复，不要任何解释
- 不超过15字
- 语气${_getStyleDescription(context.dialogStyle ?? VoiceDialogStyle.neutral)}
- 禁止使用表情符号
''';
  }

  String _getStyleDescription(VoiceDialogStyle? style) {
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

### 5. 组件连接设计

**决策**：在 `VoiceServiceCoordinator` 中完成组件连接

```dart
// voice_service_coordinator.dart

class VoiceServiceCoordinator {
  // 现有组件
  IntelligenceEngine? _intelligenceEngine;
  VoicePipelineController? _pipelineController;

  // 新增：上下文提供者
  late final ConversationContextProvider _contextProvider;

  // 新增：LLM话题生成器
  late final LLMTopicGenerator _llmTopicGenerator;

  void _initializeComponents() {
    // 1. 创建上下文提供者
    _contextProvider = ConversationContextProvider(
      resultBuffer: _intelligenceEngine!.resultBuffer,
      conversationMemory: _conversationMemory,
      userProfileService: _userProfileService,
      contextManager: _contextManager,
    );

    // 2. 创建LLM话题生成器
    _llmTopicGenerator = LLMTopicGenerator(
      contextProvider: _contextProvider,
      promptBuilder: VoiceAgentPromptBuilder(),
      llmService: _llmService,
    );

    // 3. 注入到 VoicePipelineController
    _pipelineController!.setTopicGenerator(_llmTopicGenerator);

    // 4. 设置用户ID
    _contextProvider.setUser(_currentUserId);
  }
}
```

## 风险 / 权衡

### 风险1：LLM调用延迟
- **风险**：主动对话需要等待LLM响应，可能增加延迟
- **缓解**：设置3秒超时，失败时快速降级到规则生成
- **监控**：记录LLM调用耗时，超过1秒告警

### 风险2：提示词token消耗
- **风险**：上下文信息过多导致token浪费
- **缓解**：信息分层，只传必要信息；使用摘要而非完整内容
- **测试**：监控平均token消耗，设置上限

### 风险3：缓存一致性
- **风险**：用户画像缓存过期导致行为不一致
- **缓解**：1小时缓存过期；用户切换时清除缓存

## 迁移计划

### 阶段1：基础设施
1. 创建 `ConversationContextProvider`
2. 创建 `ProactiveContext` 数据结构
3. 单元测试

### 阶段2：话题生成器
1. 创建 `VoiceAgentPromptBuilder`
2. 创建 `LLMTopicGenerator`
3. 实现降级策略
4. 集成测试

### 阶段3：组件连接
1. 修改 `VoiceServiceCoordinator` 完成连接
2. 修改 `ProactiveConversationManager` 使用新生成器
3. 端到端测试

### 回滚计划
- 保留 `SimpleTopicGenerator` 作为降级选项
- 通过 FeatureFlag 控制是否启用 LLM 话题生成
- 发现问题可立即回滚到硬编码话题

## 待决问题

1. **LLM调用频率限制**：是否需要对主动对话的LLM调用频率做限制？
2. **上下文压缩策略**：对话历史超过一定长度时如何压缩？
3. **多用户切换**：快速切换用户时的缓存策略？
