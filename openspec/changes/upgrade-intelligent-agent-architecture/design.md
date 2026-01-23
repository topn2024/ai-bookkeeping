# 设计文档：智能体架构升级

## 完整系统架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                   音频采集层                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                              麦克风输入                                       │   │
│  │                                  │                                          │   │
│  │                                  ▼                                          │   │
│  │  ┌───────────────────────────────────────────────────────────────────────┐  │   │
│  │  │                      WebRTC APM (音频预处理)                           │  │   │
│  │  │                                                                       │  │   │
│  │  │   ┌─────────┐      ┌─────────┐      ┌─────────┐                      │  │   │
│  │  │   │   AEC   │ ──→  │   NS    │ ──→  │   AGC   │                      │  │   │
│  │  │   │ 回声消除 │      │ 噪声抑制 │      │自动增益 │                      │  │   │
│  │  │   └─────────┘      └─────────┘      └─────────┘                      │  │   │
│  │  │        ↑                                                              │  │   │
│  │  │        │ 远端参考信号                                                  │  │   │
│  │  │   ┌────┴────┐                                                        │  │   │
│  │  │   │TTS播放中│ ← 当 TTS 播放时，AEC 用此信号消除回声                     │  │   │
│  │  │   └─────────┘                                                        │  │   │
│  │  └───────────────────────────────────┬───────────────────────────────────┘  │   │
│  │                                      │                                      │   │
│  │                              处理后的干净音频                                │   │
│  │                                      │                                      │   │
│  └──────────────────────────────────────┼──────────────────────────────────────┘   │
│                                         │                                          │
│                          ┌──────────────┴──────────────┐                           │
│                          ▼                              ▼                          │
│  ┌───────────────────────────────────┐  ┌───────────────────────────────────────┐ │
│  │         Silero VAD                │  │              ASR 流式识别              │ │
│  │       (语音活动检测)               │  │           (阿里云/讯飞等)              │ │
│  │                                   │  │                                       │ │
│  │  ┌─────────────────────────────┐  │  │  音频帧 ──→ 识别引擎 ──→ 文本片段     │ │
│  │  │ 输入: 处理后音频帧           │  │  │                           │          │ │
│  │  │ 输出: 语音概率 (0-1)         │  │  │                           ▼          │ │
│  │  │                             │  │  │                    "早餐十五"         │ │
│  │  │ 阈值判断:                    │  │  │                    "午餐三十五"       │ │
│  │  │ • > 0.5 → 检测到语音        │  │  │                    "还有晚餐五十"     │ │
│  │  │ • < 0.3 → 检测到静音        │  │  │                           │          │ │
│  │  └─────────────────────────────┘  │  └───────────────────────────┼───────────┘ │
│  │               │                   │                              │             │
│  │      ┌────────┴────────┐          │                              │             │
│  │      ▼                 ▼          │                              │             │
│  │ speechStart       speechEnd       │                              │             │
│  │ (用户开始说话)    (用户停止说话)    │                              │             │
│  └──────┬─────────────────┬──────────┘                              │             │
│         │                 │                                         │             │
└─────────┼─────────────────┼─────────────────────────────────────────┼─────────────┘
          │                 │                                         │
          ▼                 ▼                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          VoicePipelineController                                    │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           VAD 事件处理                                       │   │
│  │                                                                             │   │
│  │   speechStart ──→ • _isUserSpeaking = true                                  │   │
│  │                   • 打断当前 TTS 播放                                        │   │
│  │                   • 重置主动话题计时器 (5秒)                                  │   │
│  │                   • 重置强制结束计时器 (30秒)                                 │   │
│  │                                                                             │   │
│  │   speechEnd ────→ • _isUserSpeaking = false                                 │   │
│  │                   • _lastSpeechEndTime = now()                              │   │
│  │                   • 影响动态等待时间计算                                      │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                         滑动窗口聚合 (ASR 结果)                               │   │
│  │                                                                             │   │
│  │   ASR片段 ──→ 句子缓冲区 ──→ DynamicAggregationWindow                        │   │
│  │                                     │                                       │   │
│  │                          ┌──────────┴──────────┐                            │   │
│  │                          ▼                     ▼                            │   │
│  │                   取消旧计时器          计算动态等待时间                       │   │
│  │                          │                     │                            │   │
│  │                          │      ┌──────────────┴──────────────┐             │   │
│  │                          │      │ _isUserSpeaking=true → 600ms │             │   │
│  │                          │      │ 连接词(还有/另外) → 2000ms   │             │   │
│  │                          │      │ 列举模式(逗号结尾) → 2000ms  │             │   │
│  │                          │      │ 完整+停顿>500ms → 800ms      │             │   │
│  │                          │      │ 默认 → 1200ms                │             │   │
│  │                          │      │ 累计超过5000ms → 强制处理    │             │   │
│  │                          │      └──────────────┬──────────────┘             │   │
│  │                          │                     │                            │   │
│  │                          └──────────┬──────────┘                            │   │
│  │                                     ▼                                       │   │
│  │                              启动新计时器                                    │   │
│  │                                     │                                       │   │
│  │                               计时器到期                                     │   │
│  │                                     ▼                                       │   │
│  │                    聚合输出: "早餐15，午餐35，还有晚餐50"                      │   │
│  └─────────────────────────────────────┬───────────────────────────────────────┘   │
│                                        │                                           │
└────────────────────────────────────────┼───────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              IntelligenceEngine                                     │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                    第一层: InputFilter (<10ms, 纯规则)                        │   │
│  │                                                                             │   │
│  │         输入文本                                                             │   │
│  │            │                                                                │   │
│  │   ┌────────┼────────┬────────────┬─────────────┐                            │   │
│  │   ▼        ▼        ▼            ▼             │                            │   │
│  │ noise   emotion  feedback   processable        │                            │   │
│  │   │        │        │            │             │                            │   │
│  │   ▼        ▼        ▼            ▼             │                            │   │
│  │ 静默    情感回复   处理反馈    进入第二层        │                            │   │
│  └───┼────────┼────────┼────────────┼─────────────┼────────────────────────────┘   │
│      │        │        │            │             │                                │
│      │        │        │            ▼             │                                │
│  ┌───┴────────┴────────┴────────────────────────────────────────────────────────┐  │
│  │              第二层: SmartIntentRecognizer (LLM+规则)                          │  │
│  │                                                                              │  │
│  │   ┌────────────┬────────────┬────────────┬────────────┐                      │  │
│  │   ▼            ▼            ▼            ▼            │                      │  │
│  │  chat       clarify       failed      operation       │                      │  │
│  │   │            │            │            │            │                      │  │
│  │   ▼            ▼            ▼            │            │                      │  │
│  │ ChatEngine   反问澄清     错误处理       │            │                      │  │
│  │   │            │            │            │            │                      │  │
│  │   │            │            │            ▼            │                      │  │
│  │   │            │            │    ┌───────────────┐    │                      │  │
│  │   │            │            │    │执行层与对话层 │    │                      │  │
│  │   │            │            │    │    分离      │    │                      │  │
│  │   │            │            │    │             │    │                      │  │
│  │   │            │            │    │ ①立即确认   │    │                      │  │
│  │   │            │            │    │ ②异步执行   │    │                      │  │
│  │   │            │            │    │ ③ResultBuffer│   │                      │  │
│  │   │            │            │    │ ④TimingJudge │    │                      │  │
│  │   │            │            │    └───────────────┘    │                      │  │
│  └───┼────────────┼────────────┼────────────┼───────────┼──────────────────────┘  │
│      │            │            │            │           │                         │
│      └────────────┴────────────┴────────────┴───────────┘                         │
│                                         │                                          │
└─────────────────────────────────────────┼──────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                   TTS 语音合成                                       │
│                                                                                     │
│   响应文本 ──→ TTS引擎 ──→ 音频流 ──→ 扬声器播放                                     │
│                              │                                                      │
│                              │ 同时作为 AEC 的远端参考信号                            │
│                              ▼                                                      │
│                    ┌─────────────────┐                                              │
│                    │  回送到 WebRTC  │ ← 用于回声消除                                │
│                    │  APM 的 AEC    │                                               │
│                    └─────────────────┘                                              │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 音频处理层设计

### WebRTC APM 组件

#### AEC (Acoustic Echo Cancellation) 回声消除

**职责**：消除 TTS 播放产生的回声，确保 VAD 和 ASR 不被回声干扰

**工作原理**：
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            回声消除 (AEC) 工作流程                           │
│                                                                             │
│   场景：TTS 正在播放 "好的，3笔"，用户同时说 "还有打车20"                     │
│                                                                             │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐          │
│   │  TTS 输出   │ ──────→ │   扬声器    │ ──────→ │   空气传播   │          │
│   │ "好的，3笔" │         │             │         │             │          │
│   └──────┬──────┘         └─────────────┘         └──────┬──────┘          │
│          │                                               │                  │
│          │ 远端参考信号                                   │ 被麦克风拾取     │
│          │                                               │                  │
│          ▼                                               ▼                  │
│   ┌─────────────────────────────────────────────────────────────────┐      │
│   │                         WebRTC AEC                               │      │
│   │                                                                 │      │
│   │   ┌─────────────┐              ┌─────────────────────────────┐  │      │
│   │   │ 远端参考    │              │     麦克风输入               │  │      │
│   │   │"好的，3笔"  │              │ "好的，3笔" + "还有打车20"  │  │      │
│   │   └──────┬──────┘              └──────────────┬──────────────┘  │      │
│   │          │                                    │                  │      │
│   │          │          ┌─────────────────┐       │                  │      │
│   │          └────────→ │  自适应滤波器   │ ←─────┘                  │      │
│   │                     │                 │                          │      │
│   │                     │ 估计回声分量    │                          │      │
│   │                     │ 从混合信号中    │                          │      │
│   │                     │ 减去回声        │                          │      │
│   │                     └────────┬────────┘                          │      │
│   │                              │                                   │      │
│   │                              ▼                                   │      │
│   │                     ┌─────────────────┐                          │      │
│   │                     │    输出结果     │                          │      │
│   │                     │ "还有打车20"    │ ← 干净的用户语音         │      │
│   │                     └─────────────────┘                          │      │
│   └─────────────────────────────────────────────────────────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### NS (Noise Suppression) 噪声抑制

**职责**：减少背景噪音（空调、风扇、街道噪音等）

**配置参数**：
- `level`: 抑制级别 (0-3)，推荐使用 2（中等）
- 过高会导致语音失真，过低则噪音残留

#### AGC (Automatic Gain Control) 自动增益控制

**职责**：标准化音量，确保用户声音大小一致

**配置参数**：
- `targetLevel`: 目标音量级别
- `compressionGain`: 压缩增益
- 使 VAD 阈值判断更稳定

### Silero VAD 语音活动检测

**职责**：检测用户是否在说话，产生 speechStart/speechEnd 事件

**配置参数**：
```dart
class VadConfig {
  final double startThreshold = 0.5;   // 开始说话阈值
  final double endThreshold = 0.3;     // 停止说话阈值
  final int minSilenceMs = 300;        // 最小静音时长确认停止
  final int speechPadMs = 100;         // 语音边界填充
}
```

**事件输出**：
- `speechStart`: 检测到用户开始说话
- `speechEnd`: 检测到用户停止说话（静音超过 minSilenceMs）

---

## VAD 与各组件的协同关系

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Silero VAD 事件分发                                  │
│                                                                             │
│                           VAD 检测结果                                       │
│                               │                                             │
│                    ┌──────────┴──────────┐                                  │
│                    ▼                     ▼                                  │
│              speechStart              speechEnd                             │
│                    │                     │                                  │
│     ┌──────────────┼──────────────┐      │                                  │
│     ▼              ▼              ▼      ▼                                  │
│ ┌────────┐  ┌────────────┐  ┌─────────────────┐  ┌─────────────────────┐   │
│ │TTS打断 │  │主动话题    │  │DynamicWindow    │  │Pipeline状态更新     │   │
│ │        │  │计时器重置  │  │                 │  │                     │   │
│ │正在播放│  │            │  │speechStart:     │  │_isUserSpeaking=true │   │
│ │ ↓      │  │5秒计时器   │  │• 等待时间=600ms │  │                     │   │
│ │立即停止│  │ ↓          │  │• 用户还在说     │  │speechEnd:           │   │
│ │        │  │重新开始    │  │                 │  │_isUserSpeaking=false│   │
│ │        │  │            │  │speechEnd:       │  │_lastSpeechEndTime   │   │
│ │        │  │30秒计时器  │  │• 记录停顿时间   │  │ = now()             │   │
│ │        │  │ ↓          │  │• 影响等待计算   │  │                     │   │
│ │        │  │重新开始    │  │                 │  │                     │   │
│ └────────┘  └────────────┘  └─────────────────┘  └─────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### VAD 事件处理详情

#### speechStart 事件处理

```dart
void _handleSpeechStart() {
  debugPrint('[VAD] speechStart: 用户开始说话');

  // 1. 更新状态
  _isUserSpeaking = true;

  // 2. 打断当前 TTS 播放（如果正在播放）
  if (_ttsService.isPlaying) {
    _ttsService.stop();
    debugPrint('[VAD] 打断 TTS 播放');
  }

  // 3. 重置主动话题计时器
  _proactiveTopicTimer?.cancel();
  _proactiveTopicTimer = Timer(
    Duration(milliseconds: _proactiveTopicTimeoutMs), // 5秒
    _handleProactiveTopicTimeout,
  );

  // 4. 重置强制结束计时器
  _forceEndTimer?.cancel();
  _forceEndTimer = Timer(
    Duration(milliseconds: _forceEndTimeoutMs), // 30秒
    _handleForceEndTimeout,
  );

  // 5. 重置连续无响应计数
  _consecutiveNoResponseCount = 0;
}
```

#### speechEnd 事件处理

```dart
void _handleSpeechEnd() {
  debugPrint('[VAD] speechEnd: 用户停止说话');

  // 1. 更新状态
  _isUserSpeaking = false;
  _lastSpeechEndTime = DateTime.now();

  // 2. 如果缓冲区有内容，触发聚合计时器
  if (_sentenceBuffer.isNotEmpty) {
    final waitTime = _dynamicWindow.calculateWaitTime(
      currentText: _sentenceBuffer.last,
      allTexts: _sentenceBuffer,
      isUserSpeaking: false,
      pauseDuration: null,
    );

    _aggregationTimer?.cancel();
    _aggregationTimer = Timer(
      Duration(milliseconds: waitTime),
      _processAggregatedSentences,
    );
  }
}
```

---

## 智能体层架构总览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         IntelligenceEngine                              │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              第一层：InputFilter（<10ms，纯规则）                 │   │
│  │  ┌──────────┬──────────┬──────────┬─────────────────────────┐  │   │
│  │  │  noise   │ emotion  │ feedback │      processable        │  │   │
│  │  │ (语气词) │(情绪表达) │(确认/取消)│      (可处理)           │  │   │
│  │  └────┬─────┴────┬─────┴────┬─────┴───────────┬─────────────┘  │   │
│  └───────┼──────────┼──────────┼─────────────────┼────────────────┘   │
│          │          │          │                 │                     │
│          ▼          ▼          ▼                 ▼                     │
│       静默忽略   情感回复   处理反馈    ┌─────────────────────────┐    │
│       (无响应)              (确认/取消) │ 第二层：意图识别（现有） │    │
│                                        │ SmartIntentRecognizer   │    │
│                                        └───────────┬─────────────┘    │
│                                                    │                   │
│                              ┌─────────┬───────────┼───────────┐      │
│                              ▼         ▼           ▼           ▼      │
│                          operation    chat      clarify     failed    │
│                              │         │           │           │      │
│                              ▼         │           ▼           ▼      │
│                     ┌────────────────┐ │        反问澄清    错误处理   │
│                     │ ExecutionQueue │ │                              │
│                     │   (异步执行)    │ │                              │
│                     └───────┬────────┘ │                              │
│                             │          │                              │
│                             ▼          ▼                              │
│                      ResultBuffer ←── ChatEngine                      │
│                      (结果缓冲)     (上下文共享)                        │
│                             │                                         │
│                             ▼                                         │
│                       TimingJudge                                     │
│                       (时机判断)                                       │
│                             │                                         │
│          ┌──────────────────┼──────────────────────┐                  │
│          ▼                  ▼                      ▼                  │
│      immediate           natural/onIdle         defer                 │
│      (立即告知)          (适时告知)             (暂不告知)             │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 组件详细设计

### 1. InputFilter 输入预过滤器

#### 职责
- 在 LLM 调用前快速过滤无意义输入
- 识别情绪表达并给予关怀回复
- 识别用户反馈（确认/取消）并处理
- 减少不必要的 LLM 调用，提升响应速度

#### 分类规则

```dart
enum InputCategory {
  noise,       // 无意义：语气词、气息、环境音转写
  emotion,     // 情绪表达：重复字符、感叹
  feedback,    // 用户反馈：确认/取消/犹豫/重复
  processable, // 可处理：进入意图识别
}

enum FeedbackType {
  confirm,   // "嗯嗯"、"好的"、"可以"、"对"、"是的"、"行"
  cancel,    // "不要"、"算了"、"取消"、"不用了"
  hesitate,  // "等等"、"稍等"、"让我想想"
  repeat,    // "什么"、"啥"、"再说一遍"、"没听清"
}

enum EmotionType {
  positive,    // "哈哈"、"嘻嘻"、"耶"、"太好了"
  negative,    // "唉"、"哎"、"呜呜"、"惨"
  surprise,    // "哇"、"天哪"、"我去"
  frustration, // "啊啊啊"、"烦死了"、"气死"
}
```

#### 分类策略

| 特征 | 分类 | 示例 |
|------|------|------|
| 长度 <= 1 | noise | "嗯"、"啊" |
| 纯语气词，长度 <= 4 | noise | "嗯嗯"、"哦哦"、"呃" |
| 填充词模式 | noise | "那个..."、"这个..."、"就是..." |
| 重复字符 >= 3 + 情感词 | emotion | "啊啊啊啊"、"哈哈哈" |
| 确认词模式 | feedback.confirm | "好的"、"可以"、"嗯嗯" |
| 取消词模式 | feedback.cancel | "不要"、"算了"、"取消" |
| 犹豫词模式 | feedback.hesitate | "等等"、"让我想想" |
| 其他 | processable | 进入意图识别 |

#### 实现

```dart
class InputFilter {
  // Noise 模式
  static const _noisePatterns = [
    r'^[嗯啊哦呃额嘶哼唔呀噢]+$',  // 纯语气词
    r'^那个[\.。…]*$',             // 填充词
    r'^这个[\.。…]*$',
    r'^就是[\.。…]*$',
    r'^然后$',                      // 单独的"然后"
  ];

  // Feedback 模式
  static const _feedbackPatterns = {
    FeedbackType.confirm: [
      r'^嗯+$', r'^好的?$', r'^可以$', r'^对$',
      r'^是的?$', r'^行$', r'^ok$', r'^没问题$',
    ],
    FeedbackType.cancel: [
      r'^不要?了?$', r'^算了$', r'^取消$',
      r'^不用了?$', r'^别$', r'^不$',
    ],
    FeedbackType.hesitate: [
      r'^等等$', r'^稍等$', r'^等一下$', r'^让我想想$',
    ],
    FeedbackType.repeat: [
      r'^什么$', r'^啥$', r'^再说一遍$', r'^没听清$', r'^你说啥$',
    ],
  };

  // Emotion 检测
  static const _emotionKeywords = {
    EmotionType.positive: ['哈哈', '嘻嘻', '耶', '太好了', '开心', '棒'],
    EmotionType.negative: ['唉', '哎', '呜呜', '惨', '糟糕', '烦', '累'],
    EmotionType.surprise: ['哇', '天哪', '我去', '什么', '真的假的'],
    EmotionType.frustration: ['烦死', '气死', '崩溃', '受不了'],
  };

  InputFilterResult classify(String input) {
    final normalized = input.trim().toLowerCase();

    // 1. 空或极短
    if (normalized.isEmpty || normalized.length == 1) {
      return InputFilterResult(category: InputCategory.noise);
    }

    // 2. Noise 检测
    for (final pattern in _noisePatterns) {
      if (RegExp(pattern).hasMatch(normalized)) {
        return InputFilterResult(category: InputCategory.noise);
      }
    }

    // 3. Feedback 检测
    for (final entry in _feedbackPatterns.entries) {
      for (final pattern in entry.value) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(normalized)) {
          return InputFilterResult(
            category: InputCategory.feedback,
            feedbackType: entry.key,
          );
        }
      }
    }

    // 4. Emotion 检测（重复字符 + 情感词）
    final hasRepetition = RegExp(r'(.)\1{2,}').hasMatch(normalized);
    for (final entry in _emotionKeywords.entries) {
      if (entry.value.any((kw) => normalized.contains(kw)) ||
          (hasRepetition && normalized.length <= 10)) {
        return InputFilterResult(
          category: InputCategory.emotion,
          emotionType: entry.key,
        );
      }
    }

    // 5. 可处理
    return InputFilterResult(category: InputCategory.processable);
  }
}
```

#### 实现位置
- 新建 `app/lib/services/voice/input_filter.dart`

---

### 2. DynamicAggregationWindow 动态聚合窗口

#### 职责
- 实现滑动窗口机制：每次 ASR 返回重置计时器
- 根据语义特征动态计算等待时间
- 结合 VAD 状态优化等待时间
- 平衡响应速度和聚合完整性

#### 实现

```dart
class DynamicAggregationWindow {
  // 等待时间参数
  static const int minWaitMs = 600;      // 最短等待（用户还在说话）
  static const int shortWaitMs = 800;    // 短等待（完整+明显停顿）
  static const int defaultWaitMs = 1200; // 默认等待
  static const int extendedWaitMs = 2000;// 延长等待（有连接词）
  static const int maxWaitMs = 5000;     // 最大等待（兜底）

  // 连接词/未完成信号
  static const _incompleteMarkers = [
    '还有', '另外', '然后', '再', '顺便', '对了',
    '以及', '加上', '外加',
  ];

  // 列举模式标记
  static const _listMarkers = ['，', ',', '、'];

  /// 计算等待时间
  int calculateWaitTime({
    required String currentText,
    required List<String> allTexts,
    required bool isUserSpeaking,
    Duration? pauseDuration,
  }) {
    // 1. 用户还在说话 → 最短等待（等VAD确认停止）
    if (isUserSpeaking) {
      return minWaitMs;
    }

    // 2. 检测未完成信号 → 延长
    if (_hasIncompleteSignal(currentText)) {
      debugPrint('[DynamicWindow] 检测到未完成信号，延长等待');
      return extendedWaitMs;
    }

    // 3. 检测列举模式（以逗号结尾）→ 延长
    if (_isListPattern(currentText)) {
      debugPrint('[DynamicWindow] 检测到列举模式，延长等待');
      return extendedWaitMs;
    }

    // 4. 完整交易 + 明显停顿 → 缩短
    if (_isCompleteTransaction(currentText) &&
        pauseDuration != null &&
        pauseDuration.inMilliseconds > 500) {
      debugPrint('[DynamicWindow] 完整交易+停顿，缩短等待');
      return shortWaitMs;
    }

    // 5. 多笔交易模式（缓冲区已有记录）→ 稍微延长
    if (allTexts.length >= 2) {
      debugPrint('[DynamicWindow] 多笔交易模式，适度延长');
      return defaultWaitMs + 300;
    }

    // 6. 默认
    return defaultWaitMs;
  }

  /// 检测未完成信号
  bool _hasIncompleteSignal(String text) {
    // 以连接词结尾
    for (final marker in _incompleteMarkers) {
      if (text.endsWith(marker) || text.endsWith('$marker，')) {
        return true;
      }
    }
    // 以省略号结尾
    if (text.endsWith('...') || text.endsWith('…')) {
      return true;
    }
    return false;
  }

  /// 检测列举模式
  bool _isListPattern(String text) {
    // 以逗号结尾 + 包含金额
    final endsWithComma = _listMarkers.any((m) => text.endsWith(m));
    final hasAmount = RegExp(r'\d+').hasMatch(text);
    return endsWithComma && hasAmount;
  }

  /// 检测完整交易
  bool _isCompleteTransaction(String text) {
    // 有金额 + 有分类/描述词
    final hasAmount = RegExp(r'\d+').hasMatch(text);
    final hasCategory = _commonCategories.any((c) => text.contains(c));
    return hasAmount && hasCategory;
  }

  static const _commonCategories = [
    '早餐', '午餐', '晚餐', '吃饭', '餐饮',
    '打车', '地铁', '公交', '交通',
    '咖啡', '奶茶', '饮料',
    '超市', '购物', '买',
    '话费', '水电', '房租',
  ];
}
```

#### 与 VoicePipelineController 集成

```dart
// voice_pipeline_controller.dart
class VoicePipelineController {
  final List<String> _sentenceBuffer = [];
  Timer? _aggregationTimer;
  Timer? _maxWaitTimer;  // 最大等待兜底
  final _dynamicWindow = DynamicAggregationWindow();
  DateTime? _lastSpeechEndTime;
  DateTime? _firstSentenceTime;  // 第一个句子的时间

  /// ASR 返回新句子
  void _onAsrResult(String text) {
    if (text.trim().isEmpty) return;

    // 1. 记录第一个句子的时间（用于最大等待兜底）
    if (_sentenceBuffer.isEmpty) {
      _firstSentenceTime = DateTime.now();
      _startMaxWaitTimer();
    }

    // 2. 加入缓冲区
    _sentenceBuffer.add(text);
    debugPrint('[Pipeline] ASR返回: "$text", 缓冲区: ${_sentenceBuffer.length}句');

    // 3. 取消旧计时器
    _aggregationTimer?.cancel();

    // 4. 计算停顿时长
    final pauseDuration = _lastSpeechEndTime != null
        ? DateTime.now().difference(_lastSpeechEndTime!)
        : null;

    // 5. 动态计算等待时间
    final waitTime = _dynamicWindow.calculateWaitTime(
      currentText: text,
      allTexts: _sentenceBuffer,
      isUserSpeaking: _isUserSpeaking,
      pauseDuration: pauseDuration,
    );

    debugPrint('[Pipeline] 计算等待时间: ${waitTime}ms');

    // 6. 启动新计时器
    _aggregationTimer = Timer(
      Duration(milliseconds: waitTime),
      _processAggregatedSentences,
    );
  }

  /// 启动最大等待兜底计时器
  void _startMaxWaitTimer() {
    _maxWaitTimer?.cancel();
    _maxWaitTimer = Timer(
      Duration(milliseconds: DynamicAggregationWindow.maxWaitMs),
      () {
        debugPrint('[Pipeline] 最大等待时间到达，强制处理');
        _processAggregatedSentences();
      },
    );
  }

  /// VAD 检测到语音结束
  void _handleSpeechEnd() {
    _isUserSpeaking = false;
    _lastSpeechEndTime = DateTime.now();
    debugPrint('[Pipeline] VAD: 用户停止说话');
  }

  /// 处理聚合后的句子
  void _processAggregatedSentences() {
    if (_sentenceBuffer.isEmpty) return;

    // 取消计时器
    _aggregationTimer?.cancel();
    _maxWaitTimer?.cancel();

    // 合并所有句子
    final aggregatedText = _sentenceBuffer.join('，');
    final count = _sentenceBuffer.length;
    _sentenceBuffer.clear();
    _firstSentenceTime = null;

    debugPrint('[Pipeline] 聚合处理: $count句 → "$aggregatedText"');

    // 发送给 IntelligenceEngine
    _onAggregatedText?.call(aggregatedText);
  }
}
```

#### 实现位置
- 新建 `app/lib/services/voice/dynamic_aggregation_window.dart`
- 修改 `app/lib/services/voice/pipeline/voice_pipeline_controller.dart`

---

### 3. ResultBuffer 结果缓冲

#### 职责
- 暂存异步执行完成的结果
- 提供结果查询和消费接口
- 支持结果优先级排序
- 自动清理过期结果

#### 数据结构

```dart
enum ResultPriority {
  critical,  // 必须告知：删除操作、大额交易（>1000）
  normal,    // 正常告知：一般操作
  low,       // 可省略：快速连续操作中的中间结果
}

enum ResultStatus {
  pending,   // 待通知
  notified,  // 已通知
  expired,   // 已过期
  suppressed,// 已抑制（用户已知晓）
}

class BufferedResult {
  final String id;
  final ActionExecutionResult result;
  final DateTime createdAt;
  final ResultPriority priority;
  ResultStatus status;

  /// 结果摘要（用于上下文）
  String get summary {
    // 例："记录了午餐35元"
    return result.toSummary();
  }

  /// 是否过期（超过30秒）
  bool get isExpired =>
    DateTime.now().difference(createdAt).inSeconds > 30;
}

class ResultBuffer {
  final List<BufferedResult> _buffer = [];
  static const int _maxBufferSize = 10;
  static const Duration _expireDuration = Duration(seconds: 30);

  /// 添加结果
  void add(ActionExecutionResult result) {
    // 计算优先级
    final priority = _calculatePriority(result);

    _buffer.add(BufferedResult(
      id: _generateId(),
      result: result,
      createdAt: DateTime.now(),
      priority: priority,
      status: ResultStatus.pending,
    ));

    // 限制缓冲区大小
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeAt(0);
    }
  }

  /// 获取待通知的结果（按优先级排序）
  List<BufferedResult> getPendingResults() {
    _cleanExpired();
    return _buffer
      .where((r) => r.status == ResultStatus.pending)
      .toList()
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));
  }

  /// 标记为已通知
  void markNotified(String id) {
    final result = _buffer.firstWhere((r) => r.id == id);
    result.status = ResultStatus.notified;
  }

  /// 标记为已抑制（用户已知晓，无需通知）
  void markSuppressed(String id) {
    final result = _buffer.firstWhere((r) => r.id == id);
    result.status = ResultStatus.suppressed;
  }

  /// 获取结果摘要（用于 LLM 上下文）
  String getSummaryForContext() {
    final pending = getPendingResults();
    if (pending.isEmpty) return '';

    return '【后台执行结果】\n' +
      pending.map((r) => '- ${r.summary}').join('\n');
  }

  /// 清理过期结果
  void _cleanExpired() {
    _buffer.removeWhere((r) => r.isExpired);
  }

  /// 计算优先级
  ResultPriority _calculatePriority(ActionExecutionResult result) {
    // 删除操作 → critical
    if (result.actionType == 'transaction.delete') {
      return ResultPriority.critical;
    }
    // 大额交易 → critical
    if (result.amount != null && result.amount! > 1000) {
      return ResultPriority.critical;
    }
    return ResultPriority.normal;
  }
}
```

#### 实现位置
- 新建 `app/lib/services/voice/intelligence_engine/result_buffer.dart`

---

### 4. TimingJudge 时机判断器

#### 职责
- 根据对话状态判断是否适合告知执行结果
- 结合 VAD 状态（用户是否正在说话）
- 决定告知方式（独立消息/融入回复）
- 与主动话题机制协同

#### 判断维度

```dart
enum NotificationTiming {
  immediate,     // 立即告知（用户主动询问）
  natural,       // 自然融入（用户刚说完业务相关）
  onIdle,        // 主动告知（用户沉默时）
  onTopicShift,  // 适时告知（用户话题转换）
  defer,         // 延迟（用户深度闲聊中/正在说话）
  suppress,      // 抑制（结果已过时/用户已知晓）
}

class TimingContext {
  final ConversationMode currentMode;   // 当前对话模式
  final int turnsSinceLastAction;       // 距上次操作的轮数
  final Duration silenceDuration;       // 用户沉默时长
  final List<BufferedResult> pending;   // 待通知结果
  final bool isUserSpeaking;            // VAD状态：用户是否正在说话
  final String? lastUserInput;          // 最新用户输入
  final EmotionType? detectedEmotion;   // 检测到的情绪
}
```

#### 判断逻辑

```dart
class TimingJudge {
  /// 规则层判断（快速，无 LLM）
  NotificationTiming judgeByRules(TimingContext context) {
    // 1. 无待通知结果
    if (context.pending.isEmpty) {
      return NotificationTiming.suppress;
    }

    // 2. 用户正在说话 → 延迟（VAD状态）
    if (context.isUserSpeaking) {
      return NotificationTiming.defer;
    }

    // 3. 用户主动询问结果 → 立即
    if (_isAskingForResult(context.lastUserInput)) {
      return NotificationTiming.immediate;
    }

    // 4. 用户情绪负面 → 延迟
    if (context.detectedEmotion == EmotionType.negative ||
        context.detectedEmotion == EmotionType.frustration) {
      return NotificationTiming.defer;
    }

    // 5. 用户沉默超过 5 秒 → 主动告知
    if (context.silenceDuration.inSeconds >= 5) {
      return NotificationTiming.onIdle;
    }

    // 6. 刚完成业务操作，用户又说了业务相关话题 → 自然融入
    if (context.currentMode == ConversationMode.mixed ||
        context.currentMode == ConversationMode.quickBookkeeping) {
      return NotificationTiming.natural;
    }

    // 7. 用户在闲聊 → 延迟
    if (context.currentMode == ConversationMode.chat) {
      return NotificationTiming.defer;
    }

    // 8. 默认 → 适时告知
    return NotificationTiming.onTopicShift;
  }

  /// 检测用户是否在询问结果
  bool _isAskingForResult(String? input) {
    if (input == null) return false;
    const patterns = [
      '记好了吗', '记上了吗', '成功了吗', '好了吗',
      '怎么样', '结果', '记了没',
    ];
    return patterns.any((p) => input.contains(p));
  }

  /// 生成通知文本
  String generateNotification(
    List<BufferedResult> results,
    NotificationTiming timing,
  ) {
    if (results.isEmpty) return '';

    final summaries = results.map((r) => r.summary).toList();

    switch (timing) {
      case NotificationTiming.immediate:
        // 直接告知
        return summaries.join('，');

      case NotificationTiming.natural:
        // 简短确认
        if (summaries.length == 1) {
          return summaries.first;
        }
        return '${summaries.length}笔都记好了';

      case NotificationTiming.onIdle:
        // 主动话题方式
        return '对了，${summaries.join("，")}';

      case NotificationTiming.onTopicShift:
        // 顺便告知
        return '顺便说一下，${summaries.join("，")}';

      default:
        return '';
    }
  }
}
```

#### 实现位置
- 新建 `app/lib/services/voice/intelligence_engine/timing_judge.dart`

---

### 5. IntelligenceEngine 集成

#### 修改后的处理流程

```dart
// intelligence_engine.dart
class IntelligenceEngine {
  final InputFilter _inputFilter = InputFilter();
  final ResultBuffer _resultBuffer = ResultBuffer();
  final TimingJudge _timingJudge = TimingJudge();

  Future<VoiceSessionResult> process(String input) async {
    // ========== 第一层：InputFilter 快速预过滤 ==========
    final filterResult = _inputFilter.classify(input);

    switch (filterResult.category) {
      case InputCategory.noise:
        // 静默忽略
        debugPrint('[Engine] InputFilter: noise, 忽略');
        return VoiceSessionResult.silent();

      case InputCategory.emotion:
        // 情感回复
        debugPrint('[Engine] InputFilter: emotion (${filterResult.emotionType})');
        final response = _generateEmotionResponse(filterResult.emotionType!);
        return VoiceSessionResult(success: true, message: response);

      case InputCategory.feedback:
        // 处理用户反馈
        debugPrint('[Engine] InputFilter: feedback (${filterResult.feedbackType})');
        return _handleUserFeedback(filterResult.feedbackType!);

      case InputCategory.processable:
        // 进入意图识别
        debugPrint('[Engine] InputFilter: processable, 进入意图识别');
        break;
    }

    // ========== 第二层：SmartIntentRecognizer 意图识别 ==========
    final recognitionResult = await _recognizer
        .recognizeMultiOperation(input)
        .timeout(const Duration(seconds: 5));

    // 2.1 澄清模式
    if (recognitionResult.needsClarify) {
      return VoiceSessionResult(
        success: true,
        message: recognitionResult.clarifyQuestion ?? '请问您具体想做什么？',
      );
    }

    // 2.2 闲聊模式
    if (recognitionResult.isChat) {
      // 注入 ResultBuffer 上下文
      final context = _resultBuffer.getSummaryForContext();
      return await _handleChat(input, context);
    }

    // 2.3 失败模式
    if (!recognitionResult.isSuccess) {
      return VoiceSessionResult(
        success: false,
        message: recognitionResult.errorMessage ?? '抱歉，我没有理解',
      );
    }

    // 2.4 操作模式：异步执行 + 立即确认
    return await _handleOperations(recognitionResult);
  }

  /// 处理操作（执行层与对话层分离）
  Future<VoiceSessionResult> _handleOperations(
    MultiOperationResult result,
  ) async {
    final operations = result.operations;

    // 立即返回确认
    final immediateAck = _generateImmediateAck(operations);

    // 异步执行操作
    _executeOperationsAsync(operations);

    return VoiceSessionResult(
      success: true,
      message: immediateAck,
    );
  }

  /// 异步执行操作
  void _executeOperationsAsync(List<Operation> operations) async {
    for (final op in operations) {
      try {
        final result = await _actionRouter.execute(op);
        // 结果加入缓冲区
        _resultBuffer.add(result);
        debugPrint('[Engine] 操作完成，加入缓冲区: ${result.summary}');
      } catch (e) {
        debugPrint('[Engine] 操作执行失败: $e');
      }
    }

    // 检查是否需要通知
    _checkAndNotify();
  }

  /// 检查并通知执行结果
  void _checkAndNotify() {
    final context = TimingContext(
      currentMode: _conversationAgent.currentMode,
      silenceDuration: _getSilenceDuration(),
      pending: _resultBuffer.getPendingResults(),
      isUserSpeaking: _isUserSpeaking,
      lastUserInput: _lastUserInput,
    );

    final timing = _timingJudge.judgeByRules(context);

    if (timing == NotificationTiming.immediate ||
        timing == NotificationTiming.natural ||
        timing == NotificationTiming.onIdle) {
      final notification = _timingJudge.generateNotification(
        context.pending,
        timing,
      );

      if (notification.isNotEmpty) {
        // 通过 TTS 播放
        _ttsService.speak(notification);

        // 标记为已通知
        for (final r in context.pending) {
          _resultBuffer.markNotified(r.id);
        }
      }
    }
  }

  /// 生成情感回复
  String _generateEmotionResponse(EmotionType type) {
    switch (type) {
      case EmotionType.positive:
        return ['看起来心情不错呀', '开心就好~', '嘿嘿'][_random.nextInt(3)];
      case EmotionType.negative:
        return ['怎么了？', '别难过，有什么我能帮的吗？'][_random.nextInt(2)];
      case EmotionType.surprise:
        return ['发生什么事了？', '怎么了？'][_random.nextInt(2)];
      case EmotionType.frustration:
        return ['深呼吸，慢慢来', '别着急，我在呢'][_random.nextInt(2)];
    }
  }

  /// 处理用户反馈
  Future<VoiceSessionResult> _handleUserFeedback(FeedbackType type) async {
    switch (type) {
      case FeedbackType.confirm:
        // 确认上一个操作（如果有待确认的）
        return VoiceSessionResult.silent(); // 或返回简短确认

      case FeedbackType.cancel:
        // 取消当前操作
        return VoiceSessionResult(success: true, message: '好的，取消了');

      case FeedbackType.hesitate:
        // 用户在犹豫，等待
        return VoiceSessionResult(success: true, message: '好的，想好了告诉我');

      case FeedbackType.repeat:
        // 重复上一句
        final lastResponse = _getLastResponse();
        return VoiceSessionResult(success: true, message: lastResponse);
    }
  }

  /// 生成立即确认
  String _generateImmediateAck(List<Operation> operations) {
    if (operations.length == 1) {
      return '好的';
    }
    return '好的，${operations.length}笔';
  }
}
```

---

## 数据流时序图

### 场景：用户连续记录3笔交易

```
时间轴 ──────────────────────────────────────────────────────────────────────→

用户说话    │▓▓▓▓▓▓▓│    │▓▓▓▓▓▓▓│    │▓▓▓▓▓▓▓▓▓▓▓│
            "早餐15"      "午餐35"      "还有晚餐50"

VAD状态     ┌───────┐    ┌───────┐    ┌───────────┐
            │speech │    │speech │    │  speech   │
            │ Start │    │ Start │    │  Start    │
            └───┬───┘    └───┬───┘    └─────┬─────┘
                │            │              │
                ▼            ▼              ▼
            speechEnd    speechEnd      speechEnd
                │            │              │
                ▼            ▼              ▼
ASR返回     "早餐15"     "午餐35"    "还有晚餐50"
                │            │              │
                ▼            ▼              ▼
缓冲区      [早餐15]  [早餐15,午餐35]  [...,还有晚餐50]
                │            │              │
                ▼            ▼              ▼
计时器      1200ms       1200ms          2000ms ← 检测到"还有"
            (启动)       (重置)          (重置)
                │            │              │
                │            │              │
                │            │              └──── 2000ms后到期
                │            │                         │
                │            │                         ▼
                │            │              ┌─────────────────────┐
                │            │              │ 聚合处理            │
                │            │              │ "早餐15，午餐35，   │
                │            │              │  还有晚餐50"        │
                │            │              └──────────┬──────────┘
                │            │                         │
                │            │                         ▼
                │            │              ┌─────────────────────┐
                │            │              │ InputFilter         │
                │            │              │ → processable       │
                │            │              └──────────┬──────────┘
                │            │                         │
                │            │                         ▼
                │            │              ┌─────────────────────┐
                │            │              │ SmartIntentRecognizer│
                │            │              │ → 3个 add_transaction│
                │            │              └──────────┬──────────┘
                │            │                         │
                │            │                         ▼
                │            │              ┌─────────────────────┐
                │            │              │ 立即返回: "好的，3笔"│
                │            │              └──────────┬──────────┘
                │            │                         │
                │            │                         ▼
TTS播放                                     │▓▓▓▓▓▓▓▓▓▓│
                                            "好的，3笔"
                │            │                         │
                │            │                         ▼
                │            │              ┌─────────────────────┐
                │            │              │ 后台异步执行3笔记账  │
                │            │              └──────────┬──────────┘
                │            │                         │
                │            │                         ▼
                │            │              ┌─────────────────────┐
                │            │              │ ResultBuffer.add()  │
                │            │              │ × 3                 │
                │            │              └──────────┬──────────┘
                │            │                         │
用户沉默                                               │
  │                                                    │
  │ 5秒后                                              ▼
  │                                         ┌─────────────────────┐
  │                                         │ TimingJudge: onIdle │
  │                                         └──────────┬──────────┘
  ▼                                                    │
                                                       ▼
TTS播放                                     │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
                                            "对了，3笔都记好了"
```

### 场景：用户说了语气词

```
T0ms:     用户："嗯..."
          → ASR返回 → 缓冲区[嗯...] → 计时器(1200ms)

T1200ms:  计时器到期
          → 聚合: "嗯..."
          → IntelligenceEngine.process()
          → InputFilter: noise
          → 静默忽略，不响应
```

### 场景：用户记账后闲聊

```
T0ms:     用户："午餐35"
          → ... → 立即返回 "好的"
          → 异步执行记账

T2000ms:  记账完成 → ResultBuffer.add()

T2500ms:  用户："今天天气真好"
          → InputFilter: processable
          → SmartIntentRecognizer: chat
          → TimingJudge: 用户在闲聊 → defer
          → ChatEngine: "是呀，适合出去走走"（不提记账结果）

T8000ms:  用户沉默 5 秒
          → TimingJudge: onIdle
          → TTS: "对了，刚才午餐35已经记好了"
```

### 场景：用户情绪发泄

```
T0ms:     用户："啊啊啊啊啊"
          → ASR返回 → 缓冲区[啊啊啊啊啊] → 计时器(1200ms)

T1200ms:  计时器到期
          → 聚合: "啊啊啊啊啊"
          → IntelligenceEngine.process()
          → InputFilter: emotion (frustration)
          → 返回: "深呼吸，慢慢来"
```

### 场景：TTS播放时用户打断

```
T0ms:     TTS正在播放: "好的，已记录午餐35元..."

T500ms:   用户开始说话: "还有打车20"
          → VAD: speechStart
          → TTS立即停止
          → WebRTC AEC 消除残余回声
          → ASR 正常识别: "还有打车20"
          → 进入正常处理流程
```

---

## 与现有模块的关系

| 现有模块 | 关系 | 说明 |
|----------|------|------|
| WebRTC APM | 新增 | 音频预处理（AEC/NS/AGC）|
| Silero VAD | 新增 | 语音活动检测 |
| SmartIntentRecognizer | 保持 | 作为第二层意图识别，不变 |
| IntelligenceEngine | 增强 | 集成 InputFilter、ResultBuffer、TimingJudge |
| VoicePipelineController | 修改 | 集成 VAD 事件处理、DynamicAggregationWindow |
| ChatEngine | 增强 | 融合 ResultBuffer 上下文 |
| BackgroundTaskQueue | 复用 | 继续作为执行队列 |
| ProactiveConversationManager | 协同 | TimingJudge 与主动话题协同，VAD 重置计时器 |
| TTS Service | 增强 | 播放时回送音频给 AEC，支持 VAD 打断 |

---

## 技术决策

### 1. WebRTC APM 配置

**决策：中等抑制级别**
- AEC: 启用，使用 TTS 音频作为远端参考
- NS: 级别 2（中等），平衡噪音抑制和语音清晰度
- AGC: 启用，目标级别 3
- 理由：保证语音质量的同时有效抑制噪音和回声

### 2. VAD 阈值配置

**决策：保守阈值**
- startThreshold: 0.5（开始说话）
- endThreshold: 0.3（停止说话）
- minSilenceMs: 300ms（最小静音确认）
- 理由：减少误触发，宁可延迟一点也不要误判

### 3. InputFilter 实现方式

**决策：纯规则实现**
- 优点：快速（<10ms）、无 LLM 开销、可预测
- 缺点：规则需要维护
- 理由：预过滤层的目标是快速，不适合引入 LLM 延迟

### 4. TimingJudge 实现方式

**决策：规则为主，LLM 辅助**
- 规则层处理常见场景（>90%）
- 复杂场景可选 LLM 辅助（可配置开关）
- 理由：平衡准确性和响应速度

### 5. 滑动窗口最大等待时间

**决策：5000ms 兜底**
- 防止极端情况下无限等待
- 超过 5 秒强制聚合处理
- 理由：用户体验兜底

### 6. ResultBuffer 过期时间

**决策：30 秒过期**
- 超过 30 秒的结果可能已过时
- 用户可能已经忘记或不关心
- 理由：避免通知过时信息

---

## 关键设计点总结

| 组件 | 作用 | 与 VAD 的关系 |
|------|------|---------------|
| **WebRTC AEC** | 消除 TTS 播放产生的回声 | 确保 VAD 不被回声误触发 |
| **WebRTC NS** | 抑制背景噪音 | 提高 VAD 检测准确率 |
| **WebRTC AGC** | 标准化音量 | 使 VAD 阈值更稳定 |
| **Silero VAD** | 检测用户是否在说话 | speechStart/speechEnd 事件 |
| **TTS 打断** | 用户说话时停止播放 | 由 speechStart 触发 |
| **滑动窗口** | 聚合连续语音 | speechEnd 记录停顿时间 |
| **动态等待** | 根据语义调整等待 | _isUserSpeaking 影响计算 |
| **主动话题** | 用户沉默时主动发起 | speechStart 重置计时器 |
| **InputFilter** | 快速过滤无意义输入 | 减少不必要处理 |
| **ResultBuffer** | 暂存执行结果 | - |
| **TimingJudge** | 判断通知时机 | isUserSpeaking 影响判断 |

整个系统形成闭环：
1. **WebRTC** 保证音频质量
2. **VAD** 准确检测说话状态
3. **滑动窗口** 智能聚合多笔交易
4. **InputFilter** 快速过滤无意义输入
5. **SmartIntentRecognizer** 精准识别意图
6. **异步执行** 操作不阻塞对话
7. **TimingJudge** 适时通知结果
