# 语音助手重构设计 - LLM优先架构

## 设计理念

**核心原则：像人一样理解，而不是像机器一样匹配**

用户使用语音助手时，期望的是自然对话，而不是背诵命令。
系统应该能理解任意自然表达，而不是要求用户适应系统的规则。

---

## 架构对比

### 旧架构（规则优先）

```
用户语音
    ↓
┌─────────────────┐
│  ASR语音识别     │
└────────┬────────┘
         ↓
┌─────────────────┐
│  规则模式匹配    │ ←── 主要路径
│  (正则表达式)    │
└────────┬────────┘
    ↓ 失败
┌─────────────────┐
│  AI大模型兜底    │ ←── 很少走到
└────────┬────────┘
         ↓
┌─────────────────┐
│  执行命令        │
└─────────────────┘

问题：
- 规则永远无法覆盖所有表达方式
- 用户必须学习"正确"的说法
- 无法理解上下文和指代
- 每次遇到新表达都要加规则
```

### 新架构（LLM优先）

```
用户语音
    ↓
┌─────────────────┐
│  ASR语音识别     │
└────────┬────────┘
         ↓
┌─────────────────────────────────┐
│  智能意图理解层                  │
│  ┌─────────────────────────┐   │
│  │  规则快速匹配(可选)      │   │
│  │  - 常见模式缓存         │   │  ←── 优化层
│  │  - 离线降级             │   │
│  └───────────┬─────────────┘   │
│              ↓                  │
│  ┌─────────────────────────┐   │
│  │  LLM语义理解(主要)       │   │  ←── 核心
│  │  - 意图识别             │   │
│  │  - 实体提取             │   │
│  │  - 上下文理解           │   │
│  │  - 多意图分解           │   │
│  │  - 歧义消解             │   │
│  │  - 补充询问生成         │   │
│  └───────────┬─────────────┘   │
└──────────────┼──────────────────┘
               ↓
┌─────────────────────────────────┐
│  对话管理层                      │
│  - 多轮对话状态                 │
│  - 上下文记忆                   │
│  - 指代消解                     │
│  - 纠错追踪                     │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│  执行层                         │
│  - 交易操作                     │
│  - 导航跳转                     │
│  - 查询统计                     │
└──────────────┬──────────────────┘
               ↓
┌─────────────────────────────────┐
│  自然响应生成                   │
│  - 确认信息                     │
│  - 询问补充                     │
│  - 结果反馈                     │
└─────────────────────────────────┘
```

---

## 核心组件设计

### 1. 统一意图理解服务 (UnifiedIntentService)

```dart
/// 统一意图理解服务
///
/// 所有语音输入的唯一入口，负责：
/// 1. 快速规则匹配（高置信度常见模式）
/// 2. LLM深度理解（复杂/模糊/新表达）
/// 3. 上下文融合
/// 4. 多意图分解
class UnifiedIntentService {

  /// 理解用户输入
  ///
  /// 处理流程：
  /// 1. 检查规则缓存（命中率高的常见模式）
  /// 2. 若缓存未命中或置信度低，调用LLM
  /// 3. 融合对话上下文
  /// 4. 返回结构化的意图结果
  Future<IntentResult> understand(
    String userInput, {
    ConversationContext? context,
    bool forceAI = false,  // 强制使用AI（跳过规则）
  }) async {

    // 步骤1: 快速规则匹配（可选优化）
    if (!forceAI) {
      final ruleResult = _ruleCache.match(userInput);
      if (ruleResult.confidence > 0.95) {
        // 高置信度直接返回，节省API调用
        return ruleResult;
      }
    }

    // 步骤2: LLM深度理解
    final llmResult = await _llmUnderstand(userInput, context);

    // 步骤3: 更新规则缓存（学习高频模式）
    if (llmResult.confidence > 0.9) {
      _ruleCache.learn(userInput, llmResult);
    }

    return llmResult;
  }

  /// LLM理解实现
  Future<IntentResult> _llmUnderstand(
    String input,
    ConversationContext? context,
  ) async {
    final prompt = _buildPrompt(input, context);
    final response = await _qwenService.chat(prompt);
    return _parseResponse(response);
  }
}
```

### 2. 对话上下文管理 (ConversationContextManager)

```dart
/// 对话上下文管理器
///
/// 维护多轮对话的状态，支持：
/// - 指代消解（"那笔"、"它"、"刚才的"）
/// - 省略补全（"改成50" → 改什么改成50）
/// - 纠错追踪（"不对，是..."）
/// - 确认状态（待确认的操作）
class ConversationContextManager {

  /// 最近的交易操作（用于指代）
  Transaction? lastTransaction;

  /// 最近的查询结果（用于选择）
  List<Transaction>? lastQueryResults;

  /// 待确认的操作
  PendingOperation? pendingOperation;

  /// 对话历史（最近N轮）
  final List<DialogueTurn> history = [];

  /// 用户纠正历史（用于学习）
  final List<CorrectionRecord> corrections = [];

  /// 解析指代词
  ///
  /// 输入: "删掉它"
  /// 输出: lastTransaction (如果存在)
  Transaction? resolveReference(String referenceWord) {
    if (['它', '那个', '那笔', '刚才的', '上一个'].contains(referenceWord)) {
      return lastTransaction;
    }
    return null;
  }

  /// 补全省略信息
  ///
  /// 输入: "改成50"
  /// 输出: {target: lastTransaction, newAmount: 50}
  Map<String, dynamic>? completeEllipsis(IntentResult intent) {
    if (intent.type == IntentType.modify && intent.target == null) {
      if (lastTransaction != null) {
        return {'target': lastTransaction, ...intent.entities};
      }
    }
    return null;
  }
}
```

### 3. LLM Prompt 设计

```dart
/// 意图理解Prompt模板
class IntentPromptTemplate {

  static String build(String userInput, ConversationContext? context) {
    return '''
你是一个记账助手，请理解用户的语音输入并返回结构化结果。

【用户输入】
$userInput

【对话上下文】
${_buildContextSection(context)}

【你的任务】
1. 识别用户意图（可能有多个）
2. 提取关键实体信息
3. 判断信息是否完整
4. 如果信息不完整，生成自然的追问

【支持的意图类型】
- add_transaction: 添加交易记录
- delete_transaction: 删除交易记录
- modify_transaction: 修改交易记录
- query_transaction: 查询交易记录
- navigate: 页面导航
- confirm: 确认操作
- cancel: 取消操作
- correct: 纠正之前的操作

【返回JSON格式】
{
  "intents": [
    {
      "type": "意图类型",
      "confidence": 0.0-1.0,
      "entities": {
        "amount": 金额或null,
        "category": "分类名称或null",
        "merchant": "商家或null",
        "date": "日期或null",
        "description": "描述或null",
        "target_page": "目标页面或null",
        "reference": "指代词或null"
      },
      "is_complete": true/false,
      "missing_info": ["缺失的必要信息"],
      "original_text": "对应的原文片段"
    }
  ],
  "needs_clarification": true/false,
  "clarification_question": "需要追问的问题（如果需要）",
  "suggested_response": "建议的回复（确认或追问）"
}

【示例】

输入: "午餐花了35"
输出:
{
  "intents": [{
    "type": "add_transaction",
    "confidence": 0.95,
    "entities": {
      "amount": 35,
      "category": "餐饮",
      "description": "午餐"
    },
    "is_complete": true,
    "original_text": "午餐花了35"
  }],
  "needs_clarification": false,
  "suggested_response": "好的，已记录午餐支出35元"
}

输入: "刚才吃饭花了点钱"
输出:
{
  "intents": [{
    "type": "add_transaction",
    "confidence": 0.7,
    "entities": {
      "category": "餐饮"
    },
    "is_complete": false,
    "missing_info": ["amount"],
    "original_text": "刚才吃饭花了点钱"
  }],
  "needs_clarification": true,
  "clarification_question": "吃饭花了多少钱呀？"
}

输入: "那笔改成50"
输出:
{
  "intents": [{
    "type": "modify_transaction",
    "confidence": 0.9,
    "entities": {
      "reference": "那笔",
      "amount": 50
    },
    "is_complete": true,
    "original_text": "那笔改成50"
  }],
  "needs_clarification": false,
  "suggested_response": "好的，已将金额改为50元"
}

请理解以下输入并返回JSON：
''';
  }
}
```

### 4. 自然响应生成

```dart
/// 自然响应生成器
///
/// 生成符合人类对话习惯的回复，而不是机械的"已完成"
class NaturalResponseGenerator {

  /// 生成记账确认响应
  String generateAddConfirmation(Transaction tx) {
    final responses = [
      '记好啦，${tx.category}${tx.amount}元',
      '好的，${tx.description ?? tx.category}${tx.amount}块已记录',
      '收到，帮你记了${tx.amount}元的${tx.category}',
    ];
    return _randomPick(responses);
  }

  /// 生成追问响应
  String generateClarification(String missingInfo, String context) {
    switch (missingInfo) {
      case 'amount':
        return '${context}花了多少钱呀？';
      case 'category':
        return '这笔是什么类型的消费？';
      default:
        return '能说得更具体一点吗？';
    }
  }

  /// 生成错误恢复响应
  String generateErrorRecovery(String errorType) {
    switch (errorType) {
      case 'network':
        return '网络有点问题，稍等一下哦';
      case 'not_understood':
        return '抱歉没听清，能再说一遍吗？';
      default:
        return '出了点小问题，要不再试一次？';
    }
  }
}
```

---

## 实现计划

### 阶段1: 核心重构（必须）

1. **统一入口点**
   - 所有语音输入汇聚到 `UnifiedIntentService`
   - 移除 `main.dart` 中的 `_isNavigationCommand` 等分散逻辑
   - 移除 `GlobalVoiceAssistantManager._processIntent` 中的重复识别

2. **LLM意图理解**
   - 实现 `_llmUnderstand` 方法
   - 设计完整的Prompt模板
   - 处理LLM返回结果解析

3. **规则缓存层**
   - 高频模式缓存（如"午餐XX元"）
   - 置信度阈值判断（>0.95直接返回）
   - 离线降级支持

### 阶段2: 上下文增强（重要）

1. **对话上下文管理**
   - 记录最近交易
   - 指代词解析
   - 省略信息补全

2. **多轮对话支持**
   - 追问-回答流程
   - 纠错处理
   - 确认取消

### 阶段3: 体验优化（增强）

1. **自然响应生成**
   - 多样化回复模板
   - 情感化表达
   - 错误友好提示

2. **学习能力**
   - 记录用户纠正
   - 更新规则缓存
   - 个性化适应

---

## 关键代码修改清单

| 文件 | 修改内容 |
|-----|---------|
| `lib/services/unified_intent_service.dart` | 新建，核心意图理解服务 |
| `lib/services/conversation_context_manager.dart` | 新建，对话上下文管理 |
| `lib/services/natural_response_generator.dart` | 新建，自然响应生成 |
| `lib/services/voice_service_coordinator.dart` | 重构，调用统一意图服务 |
| `lib/main.dart` | 简化，移除分散的意图判断逻辑 |
| `lib/services/global_voice_assistant_manager.dart` | 简化，移除重复意图识别 |
| `lib/services/voice/voice_intent_router.dart` | 降级为规则缓存，非主要路径 |

---

## 预期效果

| 用户说法 | 旧系统 | 新系统 |
|---------|-------|-------|
| "午餐35" | ✅ | ✅ |
| "中午吃了三十五块" | ✅ | ✅ |
| "花了点钱吃午饭" | ❌ | ✅ 追问金额 |
| "刚那笔记错了，是50" | ❌ | ✅ 修改上一笔 |
| "帮我看看账本" | ❌ | ✅ 打开账户页 |
| "早餐10块午餐25还打车了18" | ⚠️ | ✅ 3笔交易 |
| "不对，应该是交通" | ❌ | ✅ 纠正分类 |
