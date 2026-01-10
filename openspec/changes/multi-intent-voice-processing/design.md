# 语音多意图处理 - 技术设计文档

## 上下文

当前语音助手架构采用单意图处理模式：
- `VoiceIntentRouter.analyzeIntent()` 返回单一 `IntentAnalysisResult`
- `VoiceServiceCoordinator._routeIntent()` 只处理一个意图
- `NLUEngine.parse()` 只构建一个主要交易

这在用户说出复杂语句时会导致信息丢失。

### 约束
- 必须保持向后兼容，单意图场景不受影响
- 不能显著增加处理延迟（目标<500ms）
- 优先使用本地规则解析，AI辅助为可选增强
- 遵循现有的 Riverpod 状态管理模式

### 利益相关者
- 终端用户：需要自然流畅的多任务语音交互
- 开发团队：需要清晰的扩展点和可维护的代码

---

## 目标 / 非目标

### 目标
- 实现语音输入的多意图识别和分解
- 支持记账、导航、查询等混合意图
- 提供友好的多意图确认交互流程
- 智能过滤无关信息

### 非目标
- 不实现跨轮次的意图关联（如"刚才那个改成50"）
- 不实现意图优先级的用户自定义配置
- 不实现多语言混合输入处理

---

## 决策

### 决策1：多意图解析架构

**选择：分层解析 + 意图合并器**

```
用户输入
    ↓
┌─────────────────────────────────────┐
│ 1. 分句器 (SentenceSplitter)        │
│    - 按标点分割：。！？，；          │
│    - 按连接词分割：然后、还有、另外   │
│    - 保留语义完整性                  │
└─────────────────────────────────────┘
    ↓ List<String>
┌─────────────────────────────────────┐
│ 2. 批量意图分析器 (BatchIntentAnalyzer)│
│    - 并行分析每个分句               │
│    - 复用现有 VoiceIntentRouter     │
│    - 返回意图+实体列表              │
└─────────────────────────────────────┘
    ↓ List<SegmentAnalysis>
┌─────────────────────────────────────┐
│ 3. 意图合并器 (IntentMerger)        │
│    - 合并同类交易意图               │
│    - 分离不同类型意图               │
│    - 过滤噪音分句                   │
│    - 标记完整/不完整意图            │
└─────────────────────────────────────┘
    ↓ MultiIntentResult
┌─────────────────────────────────────┐
│ 4. 意图调度器 (IntentScheduler)     │
│    - 确定执行顺序                   │
│    - 识别需要追问的意图             │
│    - 生成确认提示                   │
└─────────────────────────────────────┘
```

**理由：**
- 分层设计便于单独测试和优化
- 复用现有意图分析能力，减少改动
- 并行处理分句，控制延迟

**替代方案：**
| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| 单次AI调用分解 | 准确度高 | 延迟大、成本高 | 作为可选增强 |
| 状态机逐句处理 | 实现简单 | 无法利用全局上下文 | 排除 |
| 端到端神经网络 | 最先进 | 需要训练数据、模型部署复杂 | 未来考虑 |

---

### 决策2：分句策略

**选择：规则分句 + 语义边界检测**

```dart
class SentenceSplitter {
  /// 分句分隔符
  static final _delimiters = RegExp(r'[。！？；]');

  /// 弱分隔符（需要结合上下文）
  static final _softDelimiters = RegExp(r'[，,]');

  /// 连接词（表示新事件）
  static final _connectors = ['然后', '还有', '另外', '接着', '之后'];

  /// 时间转换词（表示新时间点）
  static final _timeTransitions = ['早上', '中午', '晚上', '后来', '回来'];

  List<String> split(String text) {
    // 1. 按强分隔符分割
    // 2. 检测连接词边界
    // 3. 检测时间转换边界
    // 4. 过滤空白和无意义片段
  }
}
```

**理由：**
- 中文语音输入通常缺少标点，需要语义边界检测
- 时间转换词是区分不同事件的重要信号
- 规则方法延迟低、可预测

---

### 决策3：意图完整性判断

**选择：必要槽位检查**

| 意图类型 | 必要槽位 | 可选槽位 |
|----------|----------|----------|
| 记账支出 | 金额 | 分类、商家、时间、描述 |
| 记账收入 | 金额 | 来源、时间、描述 |
| 页面导航 | 目标页面 | - |
| 查询统计 | 查询类型 | 时间范围、分类 |

```dart
class IntentCompleteness {
  final bool isComplete;
  final List<String> missingSlots;
  final double confidence;
}
```

**追问策略：**
- 单个缺失：直接询问 "请问打车花了多少钱？"
- 多个缺失：批量询问 "请补充金额：1.打车去白石洲 2.吃饭"
- 超过3个：建议逐个处理 "内容较多，我们一个一个来"

---

### 决策4：意图执行顺序

**选择：类型优先级 + 用户顺序**

```
优先级（高→低）：
1. 确认类意图（是/否/确认/取消）
2. 完整的记账意图（有金额）
3. 不完整的记账意图（追问）
4. 导航意图（最后执行，避免打断流程）
5. 查询意图
```

**理由：**
- 记账是核心功能，优先完成
- 导航会改变页面，放最后避免用户困惑
- 追问放在完整记账后，用户先看到成功反馈

---

### 决策5：噪音过滤策略

**选择：低置信度 + 无动作词过滤**

```dart
bool isNoise(SegmentAnalysis segment) {
  // 1. 置信度低于阈值
  if (segment.confidence < 0.3) return true;

  // 2. 无动作动词
  final actionVerbs = ['花', '买', '吃', '打', '坐', '付', '给', '收', '转', '打开', '查看'];
  if (!actionVerbs.any((v) => segment.text.contains(v))) return true;

  // 3. 纯状态描述
  final statePatterns = [
    RegExp(r'^(见了?|和|跟).*(朋友|同事|人)'),
    RegExp(r'^(去了?|到了?).*(?!花|买|吃)'),
  ];
  if (statePatterns.any((p) => p.hasMatch(segment.text))) return true;

  return false;
}
```

---

## 数据模型

### MultiIntentResult

```dart
class MultiIntentResult {
  /// 完整意图（可直接执行）
  final List<CompleteIntent> completeIntents;

  /// 不完整意图（需要追问）
  final List<IncompleteIntent> incompleteIntents;

  /// 导航意图（单独处理）
  final NavigationIntent? navigationIntent;

  /// 被过滤的噪音
  final List<String> filteredNoise;

  /// 原始输入
  final String rawInput;

  /// 是否需要用户确认
  bool get needsConfirmation =>
    completeIntents.isNotEmpty || incompleteIntents.isNotEmpty;

  /// 生成确认提示
  String generatePrompt();
}
```

### SegmentAnalysis

```dart
class SegmentAnalysis {
  final String text;
  final IntentAnalysisResult intentResult;
  final List<NLUEntity> entities;
  final ParsedAmount? amount;
  final bool isNoise;
  final double confidence;
}
```

---

## 风险 / 权衡

### 风险1：分句错误导致意图破碎
- **影响：** 一个完整意图被错误分成两句
- **概率：** 中
- **缓解：** 保守分句策略 + 允许用户修正

### 风险2：追问流程过长
- **影响：** 用户放弃使用
- **概率：** 中
- **缓解：** 支持"跳过"和"全部取消" + 批量补充金额

### 风险3：与现有单意图流程冲突
- **影响：** 已有功能受损
- **概率：** 低
- **缓解：** 单意图时返回兼容格式 + 充分测试

---

## 迁移计划

### 阶段1：基础架构
1. 实现 SentenceSplitter 分句器
2. 实现 BatchIntentAnalyzer 批量分析器
3. 实现 IntentMerger 意图合并器
4. 添加 MultiIntentResult 数据模型

### 阶段2：集成适配
1. 扩展 VoiceServiceCoordinator 支持多意图
2. 实现意图队列和调度逻辑
3. 添加追问流程状态管理

### 阶段3：UI交互
1. 实现多意图确认界面
2. 实现批量金额补充输入
3. 添加意图列表的编辑/删除能力

### 阶段4：优化增强
1. 可选：集成 Qwen 进行复杂语句分解
2. 添加用户反馈学习机制
3. 性能优化和测试

### 回滚方案
- 通过配置开关控制是否启用多意图处理
- 默认关闭，逐步灰度开放
- 保留完整的单意图处理路径

---

## 关键文件变更

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `nlu_engine.dart` | 修改 | 添加 MultiIntentParser 类 |
| `voice_intent_router.dart` | 修改 | 添加 analyzeMultipleIntents 方法 |
| `voice_service_coordinator.dart` | 修改 | 添加意图队列和批量处理 |
| `enhanced_voice_assistant_page.dart` | 修改 | 添加多意图确认 UI |
| `multi_intent_models.dart` | 新增 | 多意图相关数据模型 |
| `sentence_splitter.dart` | 新增 | 分句器实现 |
| `intent_merger.dart` | 新增 | 意图合并器实现 |
