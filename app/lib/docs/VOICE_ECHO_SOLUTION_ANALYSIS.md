# 语音助手 TTS/ASR 回声问题解决方案分析

## 1. 业界成熟方案调研

### 1.1 主流框架的解决方案

#### Pipecat (Daily.co)
**架构特点**:
- WebRTC 传输层提供硬件级回声消除
- 使用 Silero VAD + SmartTurn 组合进行轮次检测
- 管道式架构，每个组件都可取消

**回声处理方式**:
> "Echo cancellation, if not done well, means the bot can hear themselves. WebRTC and mobile have good support."

**关键建议**:
> "Don't go down any rabbit holes trying to improve VAD, turn-taking logic, hacking together your own echo cancellation, etc."

#### LiveKit Agents
**轮次检测策略**:
- 使用开源 Turn Detector 模型结合语义上下文
- `min_interruption_duration = 0.5s` 最小打断持续时间
- `discard_audio_if_uninterruptible = True` TTS期间丢弃音频缓冲
- 假打断恢复机制（2秒超时后恢复播放）

**打断处理**:
```
当用户打断时:
1. 立即停止TTS
2. 等待有效语音（至少0.5秒）
3. 如果是假打断（无实际语音），恢复播放
4. 如果是真打断，处理新输入
```

#### Azure Speech SDK
**回声问题描述**:
> "On mobile devices, STT sometimes picks up the bot's TTS audio and transcribes it as user speech."

**解决方案**:
1. 创建可控音频接收器，检测到语音立即调用 `stopSpeakingAsync()`
2. 使用低延迟回调检测打断

#### Expo Speech Recognition
**iOS 特定方案**:
- `iosVoiceProcessingEnabled` 选项启用额外信号处理
- 对麦克风输入和输出进行回声消除处理

### 1.2 两种主流架构对比

| 特性 | Turn-Based (轮次制) | Full-Duplex (全双工) |
|------|---------------------|---------------------|
| 复杂度 | 低 | 高 |
| 回声处理 | 简单（TTS期间停止录音） | 复杂（需要硬件回声消除） |
| 用户体验 | 一问一答 | 自然对话，可打断 |
| 延迟 | 较高 | 较低 |
| 适用场景 | 命令式交互 | 自然对话 |

---

## 2. 我们当前实现分析

### 2.1 当前架构

```
┌─────────────────────────────────────────────────────────────┐
│                    GlobalVoiceAssistantManager               │
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ 录音模块  │───>│ ASR服务  │───>│ 命令处理  │              │
│  │(持续运行) │    │(持续运行) │    │          │              │
│  └──────────┘    └──────────┘    └────┬─────┘              │
│                                        │                    │
│                                        v                    │
│                                   ┌──────────┐              │
│                                   │ TTS服务  │ ← 另一个实例  │
│                                   │(VoiceCoordinator)       │
│                                   └──────────┘              │
└─────────────────────────────────────────────────────────────┘

问题：录音和ASR持续运行，TTS播放被ASR捕获
```

### 2.2 已发现的问题

1. **多实例问题**: `GlobalVoiceAssistantManager` 和 `VoiceServiceCoordinator` 各有独立的 `TTSService` 实例

2. **标志位竞态**: 使用 `_isProcessingCommand` 标志位来忽略ASR结果
   - 异步操作可能导致标志位设置和检查之间的竞态
   - 状态同步依赖执行顺序

3. **VAD事件时序**: VAD silenceTimeout 在 TTS 播放期间仍会触发
   - 导致主动对话被错误触发
   - 多个TTS同时播放

4. **软件层面的回声过滤**: 我们使用"忽略ASR结果"而非"停止录音"
   - ASR仍在处理音频，只是结果被丢弃
   - 浪费资源且不够可靠

### 2.3 当前方案的补丁式修复

```dart
// 修复1: 检查处理状态
if (_isProcessingCommand || _ttsService?.isSpeaking == true) {
  return; // 忽略ASR结果
}

// 修复2: 检查主动对话条件
if (!_isProcessingCommand) {
  _initiateProactiveConversation();
}
```

**问题**: 补丁越来越多，状态管理越来越复杂，容易出现边缘情况。

---

## 3. 改进方案

### 方案A: 简化的轮次制（推荐）

**核心思想**: TTS播放期间完全暂停录音和ASR，而不是忽略结果

**架构设计**:
```
┌─────────────────────────────────────────────────────────────┐
│                      VoiceSessionManager                     │
│                                                              │
│  状态机:                                                     │
│  ┌────────┐   用户说话   ┌────────┐   TTS响应   ┌────────┐  │
│  │ IDLE   │────────────>│LISTENING│───────────>│SPEAKING │  │
│  └────────┘              └────────┘             └────────┘  │
│      ^                                              │        │
│      └──────────────── 播放完成 ─────────────────────┘        │
│                                                              │
│  LISTENING状态: 录音+ASR运行                                  │
│  SPEAKING状态: 录音+ASR暂停，只有TTS运行                       │
└─────────────────────────────────────────────────────────────┘
```

**关键改动**:
1. 合并TTS服务实例为单例
2. 在TTS开始前停止录音，TTS结束后重新开始
3. 简化状态机，减少并发状态

**优点**:
- 简单可靠，没有回声问题
- 无需复杂的标志位管理
- 易于调试和维护

**缺点**:
- 无法在TTS播放期间检测用户打断
- 用户必须等TTS说完才能说话

**实现复杂度**: 低

---

### 方案B: 增强的状态机（中等复杂度）

**核心思想**: 保持当前架构，但使用更严格的状态机管理

**状态定义**:
```dart
enum VoiceState {
  idle,           // 空闲
  listening,      // 监听中（录音+ASR运行）
  processing,     // 处理中（录音暂停，等待响应）
  speaking,       // 播放中（TTS运行，录音暂停）
  interruptible,  // 可打断播放中（TTS运行，VAD运行，ASR暂停）
}
```

**状态转换表**:
```
idle -> listening: 用户点击开始
listening -> processing: 收到最终ASR结果
processing -> speaking: 开始TTS播放
speaking -> idle: TTS播放完成
speaking -> listening: 用户打断（仅interruptible模式）
```

**关键改动**:
1. 引入状态机类管理所有状态转换
2. 所有操作通过状态机执行
3. 状态转换是原子操作

**优点**:
- 状态清晰，易于追踪
- 可扩展支持打断功能
- 减少竞态条件

**缺点**:
- 需要重构现有代码
- 打断功能仍需处理回声

**实现复杂度**: 中等

---

### 方案C: 平台级回声消除（高复杂度）

**核心思想**: 使用平台原生或WebRTC的回声消除能力

**Flutter 实现选项**:
1. **iOS**: 使用 `AVAudioSession` 的 `voiceProcessing` 模式
2. **Android**: 使用 `AcousticEchoCanceler` API
3. **跨平台**: 使用 WebRTC 传输层（如 flutter_webrtc）

**架构设计**:
```
┌─────────────────────────────────────────────────────────────┐
│                    WebRTC Transport Layer                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Echo Cancellation Module                │   │
│  │  ┌────────┐    ┌────────┐    ┌────────┐           │   │
│  │  │ 麦克风  │───>│ AEC    │───>│ 净音频  │           │   │
│  │  └────────┘    └────────┘    └────────┘           │   │
│  │       ^              │                             │   │
│  │       │              v                             │   │
│  │  ┌────────┐    ┌────────┐                         │   │
│  │  │ 扬声器  │<───│ TTS    │                         │   │
│  │  └────────┘    └────────┘                         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**优点**:
- 真正的全双工对话
- 硬件级回声消除
- 支持自然打断

**缺点**:
- 实现复杂度高
- 依赖平台特性
- 可能需要引入新依赖

**实现复杂度**: 高

---

## 4. 推荐方案

### 短期（立即实施）: 方案A简化版

**目标**: 彻底解决回声问题，提高稳定性

**具体改动**:

1. **统一TTS服务**:
```dart
// 使用单例模式
class TTSService {
  static final TTSService _instance = TTSService._();
  static TTSService get instance => _instance;
}
```

2. **TTS播放期间停止录音**:
```dart
Future<void> _handleFinalASRResult(String text) async {
  // 1. 立即停止录音和ASR
  await _stopRecordingAndASR();

  // 2. 处理命令并播放TTS
  final response = await _commandProcessor(text);
  await _ttsService.speak(response);

  // 3. TTS完成后重新开始录音
  await _startRecordingAndASR();
}
```

3. **简化状态检查**:
```dart
// 移除复杂的标志位检查
// 因为TTS期间录音已停止，不会有ASR结果
```

### 中期（1-2周）: 方案B状态机

**目标**: 支持用户打断功能

**具体改动**:
1. 引入 `VoiceStateMachine` 类
2. 实现可打断的TTS播放模式
3. 添加 VAD-only 模式用于打断检测

### 长期（需要时）: 方案C平台级回声消除

**目标**: 实现真正的全双工对话

**具体改动**:
1. 集成 flutter_webrtc 或原生平台API
2. 重构音频管道

---

## 5. 实施计划

### 阶段1: 紧急修复（今天）

- [x] 添加 `_isProcessingCommand` 标志位
- [x] 在 silenceTimeout 检查中添加条件
- [ ] **统一 TTS 服务实例** ← 根本解决方案

### 阶段2: 架构优化（本周）

- [ ] 重构为 TTS 期间完全停止录音模式
- [ ] 移除复杂的标志位逻辑
- [ ] 添加明确的状态日志

### 阶段3: 功能增强（后续）

- [ ] 实现状态机管理
- [ ] 支持用户打断
- [ ] 评估平台级回声消除方案

---

## 参考资源

- [Pipecat - Open Source voice agent framework](https://github.com/pipecat-ai/pipecat)
- [LiveKit Turn Detection](https://docs.livekit.io/agents/logic/turns/)
- [Voice AI & Voice Agents - An Illustrated Primer](https://voiceaiandvoiceagents.com/)
- [Building Voice Agents with Pipecat and Amazon Bedrock](https://aws.amazon.com/blogs/machine-learning/building-intelligent-ai-voice-agents-with-pipecat-and-amazon-bedrock-part-1/)
- [Advice on Building Voice AI in June 2025](https://www.daily.co/blog/advice-on-building-voice-ai-in-june-2025/)
