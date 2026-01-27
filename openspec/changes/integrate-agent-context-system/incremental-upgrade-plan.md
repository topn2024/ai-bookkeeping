# 渐进式升级方案：对话智能体上下文整合系统

**版本**: v3.0
**原则**: 每阶段独立可部署，系统始终保持正常运行

---

## 核心设计原则

```
┌─────────────────────────────────────────────────────────────┐
│                    渐进式升级原则                            │
├─────────────────────────────────────────────────────────────┤
│ 1. 新增不修改：只添加新代码，不修改现有代码                   │
│ 2. 开关控制：所有新功能通过 Feature Flag 控制                │
│ 3. 并行运行：新旧逻辑可以同时存在                            │
│ 4. 随时回滚：关闭开关即可恢复原有行为                        │
│ 5. 独立测试：每阶段完成后可以单独测试验证                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 阶段概览

| 阶段 | 名称 | 改动范围 | 风险 | 可回滚 |
|------|------|---------|------|--------|
| 0 | Feature Flag 基础设施 | 新增1个文件 | 无 | ✅ |
| 1 | 数据结构定义 | 新增1个文件 | 无 | ✅ |
| 2 | 上下文提供者（只读） | 新增1个文件 | 无 | ✅ |
| 3 | 提示词构建器 | 新增2个文件 | 无 | ✅ |
| 4 | 增强生成器（继承） | 新增1个文件 | 无 | ✅ |
| 5 | 可选集成 | 修改1个文件，1行代码 | 极低 | ✅ |
| 6 | 灰度启用 | 修改配置 | 低 | ✅ |

**总计**: 新增6个文件，修改1个文件（仅1行代码）

---

## 阶段 0：Feature Flag 基础设施

### 目标
创建功能开关系统，为后续所有阶段提供控制能力。

### 改动
新增文件：`services/voice/feature_flags.dart`

```dart
/// 语音系统功能开关
/// 所有新功能默认关闭，通过此类控制启用
class VoiceFeatureFlags {
  // 私有构造函数，单例模式
  VoiceFeatureFlags._();
  static final instance = VoiceFeatureFlags._();

  // ========== 上下文系统开关 ==========

  /// 是否使用增强版话题生成器
  /// 默认 false，保持原有行为
  bool useEnhancedTopicGenerator = false;

  /// 是否启用 LLM 生成话题
  /// 仅在 useEnhancedTopicGenerator=true 时生效
  bool enableLLMTopicGeneration = false;

  /// 是否在日志中输出上下文信息（调试用）
  bool debugLogContext = false;

  // ========== 便捷方法 ==========

  /// 重置所有开关到默认值（用于测试）
  void resetToDefaults() {
    useEnhancedTopicGenerator = false;
    enableLLMTopicGeneration = false;
    debugLogContext = false;
  }

  /// 启用增强模式（仅规则，不用LLM）
  void enableEnhancedRulesOnly() {
    useEnhancedTopicGenerator = true;
    enableLLMTopicGeneration = false;
  }

  /// 启用完整增强模式（规则 + LLM）
  void enableFullEnhanced() {
    useEnhancedTopicGenerator = true;
    enableLLMTopicGeneration = true;
  }
}

/// 全局访问点
VoiceFeatureFlags get voiceFlags => VoiceFeatureFlags.instance;
```

### 验证
- 编译通过
- 现有功能无影响
- 可以在任意位置访问 `voiceFlags`

### 系统状态
✅ 完全正常，无任何变化

---

## 阶段 1：数据结构定义

### 目标
定义统一的上下文数据结构，纯数据类，不依赖任何现有组件。

### 改动
新增文件：`services/voice/context/proactive_context.dart`

```dart
/// 主动对话上下文
/// 纯数据结构，用于在组件间传递上下文信息
class ProactiveContext {
  /// 待通知的执行结果
  final List<PendingResult> pendingResults;

  /// 用户偏好
  final UserPreferences userPreferences;

  /// 最近对话摘要
  final List<ConversationTurn> recentConversation;

  /// 长期记忆要点
  final List<String> longTermMemory;

  /// 环境信息
  final EnvironmentInfo environment;

  const ProactiveContext({
    this.pendingResults = const [],
    this.userPreferences = const UserPreferences(),
    this.recentConversation = const [],
    this.longTermMemory = const [],
    this.environment = const EnvironmentInfo(),
  });

  /// 是否有待通知的结果
  bool get hasPendingResults => pendingResults.isNotEmpty;

  /// 是否用户喜欢主动对话
  bool get likesProactiveChat => userPreferences.likesProactiveChat;

  /// 创建空上下文（用于降级）
  static const empty = ProactiveContext();
}

/// 待通知的执行结果
class PendingResult {
  final String actionType;  // 'record', 'query', 'modify' 等
  final String summary;     // "记录了15元早餐"
  final DateTime timestamp;
  final bool isSuccess;

  const PendingResult({
    required this.actionType,
    required this.summary,
    required this.timestamp,
    this.isSuccess = true,
  });
}

/// 用户偏好
class UserPreferences {
  final bool likesProactiveChat;
  final String preferredStyle;  // 'casual', 'formal', 'brief'
  final List<String> frequentCategories;

  const UserPreferences({
    this.likesProactiveChat = true,
    this.preferredStyle = 'casual',
    this.frequentCategories = const [],
  });
}

/// 对话轮次
class ConversationTurn {
  final String role;     // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  const ConversationTurn({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

/// 环境信息
class EnvironmentInfo {
  final DateTime currentTime;
  final String? timeOfDay;  // 'morning', 'noon', 'afternoon', 'evening', 'night'
  final int silenceDuration; // 用户沉默时长（秒）

  const EnvironmentInfo({
    DateTime? currentTime,
    this.timeOfDay,
    this.silenceDuration = 0,
  }) : currentTime = currentTime ?? const _DefaultDateTime();

  /// 根据当前时间推断时段
  String get inferredTimeOfDay {
    if (timeOfDay != null) return timeOfDay!;
    final hour = currentTime.hour;
    if (hour >= 5 && hour < 9) return 'morning';
    if (hour >= 11 && hour < 13) return 'noon';
    if (hour >= 13 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 22) return 'evening';
    return 'night';
  }
}

/// 默认时间（编译时常量需要）
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  // ... 委托给 DateTime.now() 的实现
}
```

### 验证
- 编译通过
- 可以创建 ProactiveContext 实例
- 现有功能无影响

### 系统状态
✅ 完全正常，只是多了一个未使用的数据类

---

## 阶段 2：上下文提供者（只读）

### 目标
创建上下文提供者，从现有组件**读取**数据，但不修改它们。

### 改动
新增文件：`services/voice/context/conversation_context_provider.dart`

```dart
import 'proactive_context.dart';
import '../intelligence_engine/result_buffer.dart';
import '../memory/conversation_memory.dart';
import '../agent/context_manager.dart';
import '../../user_profile_service.dart';

/// 对话上下文提供者
/// 只读方式整合各数据源，不修改任何现有组件
class ConversationContextProvider {
  final ResultBuffer? _resultBuffer;
  final ConversationMemory? _conversationMemory;
  final ContextManager? _contextManager;
  final UserProfileService? _userProfileService;

  /// 依赖注入，所有组件都是可选的
  ConversationContextProvider({
    ResultBuffer? resultBuffer,
    ConversationMemory? conversationMemory,
    ContextManager? contextManager,
    UserProfileService? userProfileService,
  }) : _resultBuffer = resultBuffer,
       _conversationMemory = conversationMemory,
       _contextManager = contextManager,
       _userProfileService = userProfileService;

  /// 获取主动对话上下文
  /// 安全地从各组件收集数据，任何组件失败不影响整体
  Future<ProactiveContext> getProactiveContext() async {
    return ProactiveContext(
      pendingResults: await _getPendingResults(),
      userPreferences: await _getUserPreferences(),
      recentConversation: _getRecentConversation(),
      longTermMemory: _getLongTermMemory(),
      environment: _getEnvironment(),
    );
  }

  /// 从 ResultBuffer 获取待通知结果
  Future<List<PendingResult>> _getPendingResults() async {
    if (_resultBuffer == null) return [];

    try {
      final results = _resultBuffer!.getPendingResults();
      return results.map((r) => PendingResult(
        actionType: r.type,
        summary: r.summary,
        timestamp: r.timestamp,
        isSuccess: r.success,
      )).toList();
    } catch (e) {
      // 静默失败，返回空列表
      return [];
    }
  }

  /// 从 UserProfileService 获取用户偏好
  Future<UserPreferences> _getUserPreferences() async {
    if (_userProfileService == null) return const UserPreferences();

    try {
      final profile = await _userProfileService!.getCurrentProfile();
      return UserPreferences(
        likesProactiveChat: profile?.likesProactiveChat ?? true,
        preferredStyle: profile?.chatStyle ?? 'casual',
        frequentCategories: profile?.frequentCategories ?? [],
      );
    } catch (e) {
      return const UserPreferences();
    }
  }

  /// 从 ConversationMemory 获取最近对话
  List<ConversationTurn> _getRecentConversation() {
    if (_conversationMemory == null) return [];

    try {
      final history = _conversationMemory!.getRecentHistory(limit: 5);
      return history.map((h) => ConversationTurn(
        role: h.role,
        content: h.content,
        timestamp: h.timestamp,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// 从 ContextManager 获取长期记忆
  List<String> _getLongTermMemory() {
    if (_contextManager == null) return [];

    try {
      return _contextManager!.getKeyMemories(limit: 3);
    } catch (e) {
      return [];
    }
  }

  /// 构建环境信息
  EnvironmentInfo _getEnvironment() {
    return EnvironmentInfo(
      currentTime: DateTime.now(),
    );
  }
}
```

### 验证
- 编译通过
- 可以创建 ConversationContextProvider 实例
- 调用 getProactiveContext() 返回有效数据
- 现有功能无影响

### 系统状态
✅ 完全正常，新组件只是读取数据，不改变任何行为

---

## 阶段 3：提示词构建器

### 目标
创建提示词构建系统，独立于现有代码。

### 改动
新增文件1：`services/voice/context/task_type.dart`

```dart
/// 语音助手任务类型
enum VoiceTaskType {
  /// 主动通知执行结果
  notifyResult,

  /// 时间引导（如午餐时间提醒）
  timeGuidance,

  /// 礼貌告别
  politeGoodbye,

  /// 闲聊
  casualChat,

  /// 静默（不说话）
  silence,
}

extension VoiceTaskTypeExtension on VoiceTaskType {
  String get description {
    switch (this) {
      case VoiceTaskType.notifyResult:
        return '告知用户操作执行结果';
      case VoiceTaskType.timeGuidance:
        return '根据时间引导记账';
      case VoiceTaskType.politeGoodbye:
        return '礼貌告别';
      case VoiceTaskType.casualChat:
        return '轻松闲聊';
      case VoiceTaskType.silence:
        return '保持静默';
    }
  }
}
```

新增文件2：`services/voice/context/voice_agent_prompt_builder.dart`

```dart
import 'proactive_context.dart';
import 'task_type.dart';

/// 语音助手提示词构建器
/// 根据上下文和任务类型构建 LLM 提示词
class VoiceAgentPromptBuilder {
  /// 构建完整提示词
  String build({
    required ProactiveContext context,
    required VoiceTaskType taskType,
  }) {
    final buffer = StringBuffer();

    // 第一层：角色定义
    buffer.writeln(_buildRoleDefinition());
    buffer.writeln();

    // 第二层：用户偏好
    buffer.writeln(_buildUserPreferences(context.userPreferences));
    buffer.writeln();

    // 第三层：会话上下文
    buffer.writeln(_buildSessionContext(context));
    buffer.writeln();

    // 第四层：当前任务
    buffer.writeln(_buildTaskInstruction(taskType, context));
    buffer.writeln();

    // 第五层：输出约束
    buffer.writeln(_buildOutputConstraints());

    return buffer.toString();
  }

  String _buildRoleDefinition() {
    return '''
## 角色
你是「小白」，AI智能记账助手。性格：温暖、贴心、专业但不死板。
说话风格：简洁自然，像朋友聊天，不用敬语。''';
  }

  String _buildUserPreferences(UserPreferences prefs) {
    final style = prefs.preferredStyle == 'formal' ? '正式' : '轻松';
    final categories = prefs.frequentCategories.isNotEmpty
        ? prefs.frequentCategories.take(3).join('、')
        : '餐饮、交通';

    return '''
## 用户偏好
- 对话风格：$style
- 常用分类：$categories
- 主动对话：${prefs.likesProactiveChat ? '欢迎' : '偏少'}''';
  }

  String _buildSessionContext(ProactiveContext context) {
    final buffer = StringBuffer('## 当前状态\n');

    // 待通知结果
    if (context.hasPendingResults) {
      buffer.writeln('- 待告知：${context.pendingResults.length}个操作结果');
      for (final r in context.pendingResults.take(3)) {
        buffer.writeln('  - ${r.summary}');
      }
    }

    // 时间
    buffer.writeln('- 当前时间：${context.environment.inferredTimeOfDay}');

    // 沉默时长
    if (context.environment.silenceDuration > 0) {
      buffer.writeln('- 用户已沉默：${context.environment.silenceDuration}秒');
    }

    return buffer.toString();
  }

  String _buildTaskInstruction(VoiceTaskType taskType, ProactiveContext context) {
    switch (taskType) {
      case VoiceTaskType.notifyResult:
        final results = context.pendingResults;
        if (results.length == 1) {
          return '## 任务\n告诉用户：${results.first.summary}，然后问还有没有要记的。';
        } else {
          return '## 任务\n告诉用户：已完成${results.length}笔记账，然后问还有没有要记的。';
        }

      case VoiceTaskType.timeGuidance:
        final time = context.environment.inferredTimeOfDay;
        final meal = _getMealForTime(time);
        return '## 任务\n自然地问用户${meal}记了没，不要太生硬。';

      case VoiceTaskType.politeGoodbye:
        return '## 任务\n礼貌告别，让用户知道有需要随时可以找你。';

      case VoiceTaskType.casualChat:
        return '## 任务\n轻松闲聊，可以聊聊理财小知识或鼓励坚持记账。';

      case VoiceTaskType.silence:
        return '## 任务\n保持静默，不输出任何内容。';
    }
  }

  String _getMealForTime(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning': return '早餐';
      case 'noon': return '午餐';
      case 'afternoon': return '下午茶';
      case 'evening': return '晚餐';
      default: return '消费';
    }
  }

  String _buildOutputConstraints() {
    return '''
## 输出要求
- 不超过15个字
- 禁止使用表情符号
- 直接输出要说的话，不要任何解释''';
  }
}
```

### 验证
- 编译通过
- 可以创建 VoiceAgentPromptBuilder 实例
- 调用 build() 返回合理的提示词
- 现有功能无影响

### 系统状态
✅ 完全正常，只是多了独立的提示词构建工具

---

## 阶段 4：增强生成器（继承方式）

### 目标
创建增强版话题生成器，**继承**现有生成器，不修改原有代码。

### 改动
新增文件：`services/voice/enhanced_proactive_topic_generator.dart`

```dart
import 'proactive_topic_generator.dart';
import 'context/proactive_context.dart';
import 'context/conversation_context_provider.dart';
import 'context/voice_agent_prompt_builder.dart';
import 'context/task_type.dart';
import 'feature_flags.dart';
import '../qwen_service.dart';

/// 增强版主动话题生成器
/// 继承原有生成器，添加上下文感知和LLM生成能力
class EnhancedProactiveTopicGenerator extends ProactiveTopicGenerator {
  final ConversationContextProvider _contextProvider;
  final VoiceAgentPromptBuilder _promptBuilder;
  final QwenService _qwenService;

  /// LLM 调用超时时间
  static const _llmTimeout = Duration(seconds: 3);

  EnhancedProactiveTopicGenerator({
    required ConversationContextProvider contextProvider,
    required QwenService qwenService,
  }) : _contextProvider = contextProvider,
       _promptBuilder = VoiceAgentPromptBuilder(),
       _qwenService = qwenService;

  /// 生成主动话题
  /// 优先使用 LLM，超时或失败则降级到规则生成
  @override
  Future<ProactiveTopic?> generateTopic() async {
    // 如果 Feature Flag 关闭，直接使用父类方法
    if (!voiceFlags.useEnhancedTopicGenerator) {
      return super.generateTopic();
    }

    // 获取上下文
    final context = await _contextProvider.getProactiveContext();

    // 决定任务类型
    final taskType = _decideTaskType(context);

    // 如果决定静默，直接返回 null
    if (taskType == VoiceTaskType.silence) {
      return null;
    }

    // 如果启用 LLM 且任务类型适合，尝试 LLM 生成
    if (voiceFlags.enableLLMTopicGeneration && _shouldUseLLM(taskType)) {
      final llmResult = await _tryLLMGeneration(context, taskType);
      if (llmResult != null) {
        return llmResult;
      }
      // LLM 失败，降级到规则生成
    }

    // 规则生成（继承自父类或本地增强规则）
    return _generateByRules(context, taskType);
  }

  /// 决定任务类型
  VoiceTaskType _decideTaskType(ProactiveContext context) {
    // 优先级1：有待通知结果
    if (context.hasPendingResults) {
      return VoiceTaskType.notifyResult;
    }

    // 优先级2：用户不喜欢主动对话，保持静默
    if (!context.likesProactiveChat) {
      return VoiceTaskType.silence;
    }

    // 优先级3：特定时间引导
    final timeOfDay = context.environment.inferredTimeOfDay;
    if (['morning', 'noon', 'evening'].contains(timeOfDay)) {
      return VoiceTaskType.timeGuidance;
    }

    // 优先级4：沉默太久，礼貌告别
    if (context.environment.silenceDuration > 30) {
      return VoiceTaskType.politeGoodbye;
    }

    // 默认静默
    return VoiceTaskType.silence;
  }

  /// 是否应该使用 LLM
  bool _shouldUseLLM(VoiceTaskType taskType) {
    // 静默和简单通知不需要 LLM
    return taskType != VoiceTaskType.silence;
  }

  /// 尝试 LLM 生成
  Future<ProactiveTopic?> _tryLLMGeneration(
    ProactiveContext context,
    VoiceTaskType taskType,
  ) async {
    try {
      final prompt = _promptBuilder.build(
        context: context,
        taskType: taskType,
      );

      final response = await _qwenService
          .generateText(prompt)
          .timeout(_llmTimeout);

      if (response != null && response.isNotEmpty) {
        return ProactiveTopic(
          text: response.trim(),
          type: taskType.name,
          source: 'llm',
        );
      }
    } catch (e) {
      // 超时或其他错误，静默处理
      if (voiceFlags.debugLogContext) {
        print('[EnhancedGenerator] LLM failed: $e');
      }
    }
    return null;
  }

  /// 规则生成
  ProactiveTopic? _generateByRules(
    ProactiveContext context,
    VoiceTaskType taskType,
  ) {
    String? text;

    switch (taskType) {
      case VoiceTaskType.notifyResult:
        final count = context.pendingResults.length;
        text = count == 1 ? '记好了，还有吗？' : '$count笔都记好了，还有要记的吗？';
        break;

      case VoiceTaskType.timeGuidance:
        final meal = _getMealName(context.environment.inferredTimeOfDay);
        text = '$meal记了吗？';
        break;

      case VoiceTaskType.politeGoodbye:
        text = '有需要随时找我哦';
        break;

      case VoiceTaskType.casualChat:
        text = '记账贵在坚持哦';
        break;

      case VoiceTaskType.silence:
        return null;
    }

    if (text != null) {
      return ProactiveTopic(
        text: text,
        type: taskType.name,
        source: 'rules',
      );
    }
    return null;
  }

  String _getMealName(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning': return '早餐';
      case 'noon': return '午餐';
      case 'evening': return '晚餐';
      default: return '消费';
    }
  }
}
```

### 验证
- 编译通过
- 可以创建 EnhancedProactiveTopicGenerator 实例
- Feature Flag 关闭时，行为与原生成器完全一致
- Feature Flag 开启时，使用新逻辑
- 现有功能无影响（因为还没有使用新生成器）

### 系统状态
✅ 完全正常，新生成器存在但未被使用

---

## 阶段 5：可选集成（最小改动）

### 目标
在调用点添加条件逻辑，根据 Feature Flag 选择使用哪个生成器。

### 改动
修改文件：`services/voice_service_coordinator.dart`（仅添加几行代码）

**改动前**:
```dart
class VoiceServiceCoordinator {
  late final ProactiveTopicGenerator _topicGenerator;

  void _initializeComponents() {
    _topicGenerator = ProactiveTopicGenerator();
    // ...
  }
}
```

**改动后**:
```dart
import 'voice/feature_flags.dart';
import 'voice/enhanced_proactive_topic_generator.dart';
import 'voice/context/conversation_context_provider.dart';

class VoiceServiceCoordinator {
  late final ProactiveTopicGenerator _topicGenerator;

  void _initializeComponents() {
    // 根据 Feature Flag 选择生成器
    if (voiceFlags.useEnhancedTopicGenerator) {
      _topicGenerator = EnhancedProactiveTopicGenerator(
        contextProvider: ConversationContextProvider(
          resultBuffer: _resultBuffer,
          conversationMemory: _conversationMemory,
          contextManager: _contextManager,
          userProfileService: _userProfileService,
        ),
        qwenService: _qwenService,
      );
    } else {
      _topicGenerator = ProactiveTopicGenerator();
    }
    // ...
  }
}
```

### 验证
- 编译通过
- Feature Flag 关闭：使用原生成器，行为完全不变
- Feature Flag 开启：使用新生成器
- 可以随时通过修改 Flag 切换

### 系统状态
✅ 完全正常，默认行为不变（Flag 默认关闭）

---

## 阶段 6：灰度启用

### 目标
逐步启用新功能，监控效果。

### 启用步骤

**Step 1: 开发环境测试**
```dart
// 在 main.dart 或初始化代码中
void main() {
  // 开发环境启用调试日志
  if (kDebugMode) {
    voiceFlags.debugLogContext = true;
    voiceFlags.useEnhancedTopicGenerator = true;
    // 暂不启用 LLM
    voiceFlags.enableLLMTopicGeneration = false;
  }
  runApp(MyApp());
}
```

**Step 2: 内测用户启用（纯规则模式）**
```dart
// 根据用户ID判断
if (isInternalTester(userId)) {
  voiceFlags.enableEnhancedRulesOnly();
}
```

**Step 3: 部分用户启用 LLM**
```dart
// 10% 用户启用 LLM
if (userId.hashCode % 100 < 10) {
  voiceFlags.enableFullEnhanced();
} else if (userId.hashCode % 100 < 50) {
  voiceFlags.enableEnhancedRulesOnly();
}
```

**Step 4: 全量发布**
```dart
// 所有用户启用
voiceFlags.enableFullEnhanced();
```

### 回滚方案
任何时候发现问题，只需：
```dart
voiceFlags.resetToDefaults();
```
系统立即恢复原有行为。

### 系统状态
✅ 可控的逐步启用，随时可回滚

---

## 文件清单

### 新增文件（6个）
```
app/lib/services/voice/
├── feature_flags.dart                              # 阶段0
├── context/
│   ├── proactive_context.dart                      # 阶段1
│   ├── conversation_context_provider.dart          # 阶段2
│   ├── task_type.dart                              # 阶段3
│   └── voice_agent_prompt_builder.dart             # 阶段3
└── enhanced_proactive_topic_generator.dart         # 阶段4
```

### 修改文件（1个，仅阶段5）
```
app/lib/services/voice_service_coordinator.dart     # 约10行代码
```

---

## 时间表

| 阶段 | 预计耗时 | 累计 | 可部署 |
|------|---------|------|--------|
| 0 | 0.5h | 0.5h | ✅ |
| 1 | 1h | 1.5h | ✅ |
| 2 | 2h | 3.5h | ✅ |
| 3 | 2h | 5.5h | ✅ |
| 4 | 3h | 8.5h | ✅ |
| 5 | 0.5h | 9h | ✅ |
| 6 | 灰度 | - | ✅ |

**总计**: 约9小时开发 + 灰度观察期

---

## 总结

```
┌─────────────────────────────────────────────────────────────┐
│                    渐进式升级保障                            │
├─────────────────────────────────────────────────────────────┤
│ ✅ 每阶段完成后系统正常运行                                  │
│ ✅ 默认行为不变，需显式启用新功能                            │
│ ✅ Feature Flag 控制，随时可回滚                            │
│ ✅ 新增代码为主，最小化修改现有代码                          │
│ ✅ 可独立测试每个新组件                                      │
│ ✅ 支持 A/B 测试和灰度发布                                  │
└─────────────────────────────────────────────────────────────┘
```

**状态**: 📝 方案已设计
**下一步**: 从阶段0开始实施
