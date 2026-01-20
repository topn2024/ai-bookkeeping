# 技术设计：WebRTC AEC + Silero VAD 语音处理架构

## 上下文

当前语音处理系统存在以下问题：
- 回声消除在错误的层级实现（文本层而非音频层）
- 打断检测逻辑复杂且不可靠
- 多个组件职责重叠，难以维护

本设计采用行业标准方案重构语音处理架构。

## 目标 / 非目标

### 目标
- 使用 WebRTC AEC 在音频层面消除回声
- 使用 Silero VAD 作为唯一的语音活动检测源
- 简化代码架构，降低复杂度
- 提高打断检测的可靠性

### 非目标
- 不改变 ASR/TTS/LLM 服务的选型
- 不改变意图识别和执行层的实现
- 不引入新的云端服务

## 核心设计决策

### 决策 1：WebRTC AEC 作为回声消除方案

**选择**：使用 WebRTC 内置的 AEC（Acoustic Echo Cancellation）模块

**原因**：
1. 业界标准方案，在 Zoom、Google Meet、Discord 等产品中广泛使用
2. 在音频信号层面消除回声，比文本层面更早、更准确
3. 延迟极低（<10ms），不需要等待 ASR 结果

**替代方案考虑**：
- ❌ 文本相似度过滤：处理太晚，依赖 ASR 准确度，阈值难以调优
- ❌ 静音 ASR：牺牲了 TTS 期间的用户输入能力
- ❌ 硬件级 AEC（VOICE_COMMUNICATION）：效果不够好，不同设备表现不一致

### 决策 2：Silero VAD 作为唯一语音检测源

**选择**：仅使用 Silero VAD 进行语音活动检测和打断判断

**原因**：
1. 基于深度学习，检测准确度高
2. 响应速度快（~100ms）
3. 单一来源避免多个检测器冲突

**打断检测逻辑简化**：
```
TTS播放中 + VAD检测到speechStart + 持续>200ms → 触发打断
```

### 决策 3：三层架构

```
┌────────────────────────────────────────────────────┐
│  Layer 1: 音频预处理（端侧）                         │
│  - WebRTC AEC: 消除扬声器回声                        │
│  - WebRTC NS: 降低环境噪音                           │
│  - WebRTC AGC: 自动调节增益                          │
│  - Silero VAD: 检测语音活动                          │
└────────────────────────────────────────────────────┘
                         ↓ 干净的音频流
┌────────────────────────────────────────────────────┐
│  Layer 2: 云端服务                                   │
│  - 阿里云 ASR: 语音转文本                            │
│  - 通义千问 LLM: 意图理解和回复生成                   │
│  - 阿里云 TTS: 文本转语音                            │
└────────────────────────────────────────────────────┘
                         ↓ 文本/意图
┌────────────────────────────────────────────────────┐
│  Layer 3: 业务逻辑（保持不变）                        │
│  - SmartIntentRecognizer: 意图识别                   │
│  - ActionRouter: 动作路由                            │
│  - BookkeepingOperationAdapter: 记账操作             │
└────────────────────────────────────────────────────┘
```

## 详细设计

### WebRTC 音频处理器

```dart
/// WebRTC 音频处理器
///
/// 负责 AEC/NS/AGC 处理，输出干净的音频流
class WebRTCAudioProcessor {
  // AEC 需要 TTS 播放的音频作为参考信号
  void setTTSReference(Uint8List audioData);

  // 处理麦克风输入，返回消除回声后的音频
  Uint8List process(Uint8List microphoneData);

  // 配置
  void setAECEnabled(bool enabled);
  void setNSEnabled(bool enabled);
  void setAGCEnabled(bool enabled);
}
```

### 简化的打断检测器

```dart
/// 简化的打断检测器
///
/// 仅基于 VAD 事件判断是否打断
class SimpleBargeInDetector {
  /// 最小语音持续时间（毫秒），避免噪音误触发
  static const int minSpeechDurationMs = 200;

  /// TTS 是否正在播放
  bool _isTTSPlaying = false;

  /// VAD 语音开始时间
  DateTime? _speechStartTime;

  /// 处理 VAD 事件
  BargeInResult? handleVADEvent(VADEvent event) {
    if (event.type == VADEventType.speechStart) {
      _speechStartTime = DateTime.now();
    } else if (event.type == VADEventType.speechEnd) {
      if (_isTTSPlaying && _speechStartTime != null) {
        final duration = DateTime.now().difference(_speechStartTime!);
        if (duration.inMilliseconds >= minSpeechDurationMs) {
          return BargeInResult(triggered: true, reason: 'VAD语音检测');
        }
      }
      _speechStartTime = null;
    }
    return null;
  }

  void onTTSStarted() => _isTTSPlaying = true;
  void onTTSStopped() => _isTTSPlaying = false;
}
```

### 音频流水线改造

**当前流程**：
```
麦克风 → 录音 → ASR → 文本相似度过滤 → 意图处理
                  ↑
            多层打断检测
```

**新流程**：
```
麦克风 → WebRTC处理 → 干净音频 → ASR → 意图处理
    ↑        ↓
TTS参考   Silero VAD → 打断检测
```

## 风险 / 权衡

### 风险 1：WebRTC 包兼容性
- **风险**：Flutter WebRTC 包可能不支持独立的 AEC 功能
- **缓解**：提前 POC 验证，准备多个候选包

### 风险 2：AEC 参考信号同步
- **风险**：TTS 播放音频和麦克风输入的时间对齐困难
- **缓解**：利用 WebRTC 内置的自适应延迟补偿

### 风险 3：VAD 误检
- **风险**：环境噪音导致 VAD 误检，错误打断 TTS
- **缓解**：设置最小语音持续时间阈值（200ms）

## 迁移计划

### 阶段 1：POC 验证
1. 验证 WebRTC AEC 在 Flutter 中的可行性
2. 确认 AEC + VAD 组合的打断效果

### 阶段 2：代码清理
1. 删除 `echo_filter.dart`
2. 删除 `similarity_calculator.dart`
3. 简化 `barge_in_detector_v2.dart`

### 阶段 3：新架构实现
1. 集成 WebRTC 音频处理
2. 重构打断检测逻辑
3. 集成 TTS 参考信号

### 回滚方案
- 保留旧代码在 git 历史中
- 如果 WebRTC 方案失败，可从 git 恢复

## 待决问题

1. **WebRTC 包选择**：需要评估 `flutter_webrtc` 是否支持独立的音频处理 API，或是否需要寻找其他方案
2. **iOS/Android 差异**：两平台的 AEC 实现可能有差异，需要分别测试
3. **TTS 音频获取**：如何获取 TTS 播放的原始音频数据作为 AEC 参考信号
