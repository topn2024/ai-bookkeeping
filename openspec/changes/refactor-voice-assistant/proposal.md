# 语音助手重构提案

## 变更ID
`refactor-voice-assistant`

## 问题陈述

当前语音助手实现存在以下核心问题：

### 1. 回声问题无法根治
- 使用标志位 `_isProcessingCommand` 忽略ASR结果
- 时序问题：TTS播放完成后的延迟等待期间，用户真实输入也被忽略
- 多个TTS实例（GlobalVoiceAssistantManager和VoiceServiceCoordinator各有一个）

### 2. 状态管理过于复杂
- 多个标志位：`_isProcessingCommand`, `_isTTSPlayingWithBargeIn`, `_isProactiveConversation`, `_isRestartingASR`
- 标志位之间存在竞态条件
- 难以追踪和调试

### 3. 打断检测不可靠
- BargeInDetector集成但未能正确工作
- VAD检测与ASR状态不同步

### 4. 用户反馈
- 真机上反复说"随时找我聊天哦"，无法进入正常对话
- 聊天和记账功能间歇性失效

## 业界成熟方案分析

### Pipecat (Daily.co) 的建议
> "Don't go down any rabbit holes trying to improve VAD, turn-taking logic, hacking together your own echo cancellation, etc."

核心原则：**简单可靠优先于功能丰富**

### LiveKit Agents 的实现
- `min_interruption_duration = 0.5s` - 最小打断持续时间
- `discard_audio_if_uninterruptible = True` - 不可打断时丢弃音频
- 假打断恢复机制（2秒超时后恢复播放）

### 业界共识
| 方案 | 复杂度 | 可靠性 | 推荐场景 |
|------|--------|--------|---------|
| **轮次制（Turn-Based）** | 低 | 高 | 命令式交互 |
| 半双工+打断 | 中 | 中 | 有限打断支持 |
| 全双工（Full-Duplex） | 高 | 需硬件AEC | 自然对话 |

## 重构方案

### 核心原则
1. **TTS期间完全停止ASR** - 最简单的回声消除
2. **统一状态机** - 一个明确的状态，没有标志位竞态
3. **VAD-only打断检测** - TTS期间只运行VAD，检测到用户说话就停止TTS
4. **单一TTS实例** - 消除多实例问题

### 状态机设计

```
┌─────────────────────────────────────────────────────────────────┐
│                     VoiceSessionStateMachine                     │
│                                                                  │
│  ┌──────────┐   开始录音    ┌────────────┐                      │
│  │   IDLE   │─────────────>│ LISTENING  │                      │
│  └──────────┘              └─────┬──────┘                      │
│       ^                          │                              │
│       │                     ASR最终结果                          │
│       │                          v                              │
│       │                    ┌────────────┐                      │
│       │                    │ PROCESSING │ (停止ASR)             │
│       │                    └─────┬──────┘                      │
│       │                          │                              │
│       │                     开始TTS                              │
│       │                          v                              │
│       │   TTS完成          ┌────────────┐    用户打断           │
│       └────────────────────│  SPEAKING  │─────────────┐        │
│                            │ (VAD监听)   │             │        │
│                            └────────────┘             │        │
│                                                       v        │
│                                              ┌────────────┐    │
│                                              │INTERRUPTED │    │
│                                              └─────┬──────┘    │
│                                                    │           │
│                                               恢复ASR          │
│                                                    v           │
│                                              ┌────────────┐    │
│                                              │ LISTENING  │    │
│                                              └────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 状态说明

| 状态 | 录音 | VAD | ASR | TTS | 说明 |
|------|------|-----|-----|-----|------|
| IDLE | 停止 | 停止 | 停止 | 停止 | 空闲状态 |
| LISTENING | 运行 | 运行 | **运行** | 停止 | 监听用户输入 |
| PROCESSING | 停止 | 停止 | 停止 | 停止 | 处理命令中 |
| SPEAKING | 运行 | **运行** | **停止** | 运行 | TTS播放，VAD检测打断 |
| INTERRUPTED | 运行 | 运行 | **运行** | 停止 | 被打断，恢复监听 |

### 关键设计点

#### 1. SPEAKING状态的音频管道
```dart
void _enterSpeakingState() {
  // 1. 停止ASR（关键！避免回声）
  _asrSubscription?.cancel();

  // 2. 保持录音运行（用于VAD检测打断）
  // 录音继续，但音频不发送到ASR

  // 3. VAD保持运行，监听用户是否开始说话
  _vadService.start();

  // 4. 开始TTS播放
  await _ttsService.speak(response);
}
```

#### 2. 打断检测
```dart
void _onVADSpeechDetected() {
  if (_currentState != VoiceSessionState.speaking) return;

  // 检测到用户说话超过500ms
  if (_speechDuration > Duration(milliseconds: 500)) {
    // 停止TTS
    _ttsService.stop();
    // 进入INTERRUPTED状态
    _transition(VoiceSessionState.interrupted);
    // 恢复ASR
    _startASR();
  }
}
```

#### 3. TTS播放完成后的处理
```dart
void _onTTSComplete() {
  // 不需要延迟等待！因为ASR已经停止，没有回声问题

  // 直接恢复LISTENING状态
  _transition(VoiceSessionState.listening);
  _startASR();
}
```

## 实施计划

### 阶段1: 创建新的状态机（不修改现有代码）
- 新建 `VoiceSessionStateMachine` 类
- 新建 `VoiceSessionController` 类
- 独立测试验证

### 阶段2: 集成测试
- 在测试环境验证新实现
- 对比新旧实现的行为差异

### 阶段3: 替换现有实现
- 用新的 `VoiceSessionController` 替换 `GlobalVoiceAssistantManager` 中的核心逻辑
- 保持对外接口不变

### 阶段4: 清理
- 移除废弃的标志位和旧逻辑
- 更新文档

## 文件变更

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `lib/services/voice/voice_session_state_machine.dart` | 新建 | 核心状态机 |
| `lib/services/voice/voice_session_controller.dart` | 新建 | 会话控制器 |
| `lib/services/global_voice_assistant_manager.dart` | 修改 | 集成新控制器 |
| `lib/services/voice/barge_in_detector.dart` | 删除 | 简化为VAD直接检测 |

## 验收标准

1. **回声消除**: TTS播放内容不会被ASR识别
2. **打断支持**: 用户说话500ms后TTS停止
3. **多轮对话**: 连续对话流畅，无异常循环
4. **真机验证**: 在真实设备上稳定运行

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 新实现引入新bug | 高 | 保持旧代码可回退 |
| 用户体验变化 | 中 | 充分测试后发布 |
| 打断延迟增加 | 低 | 500ms是可接受的延迟 |
