# 技术设计：启用AEC回声消除 - TTS PCM数据作为参考信号

## 上下文

WebRTC AEC工作原理：
```
         ┌─────────────────┐
         │  WebRTC AEC     │
         │                 │
麦克风 ──→│ Capture Audio  │──→ 干净音频 ──→ ASR
         │       ↑         │
         │  Render Audio   │
         │       ↑         │
         └───────┼─────────┘
                 │
         TTS播放音频（参考信号）
```

AEC通过对比麦克风输入和扬声器输出，识别并消除回声。**没有参考信号，AEC无法工作**。

## 目标 / 非目标

### 目标
- 使WebRTC AEC能够获取TTS播放的PCM数据作为参考信号
- 在TTS播放期间有效消除麦克风中的TTS回声
- 支持用户在TTS播放期间打断（barge-in）

### 非目标
- 不改变ASR/LLM服务
- 不改变离线TTS（flutter_tts）的实现
- 不优化TTS首字延迟（已有流式分句机制）

## 核心设计

### 数据流架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                        阿里云TTS服务                                  │
│                                                                      │
│  请求: format=pcm, sample_rate=16000                                 │
│  响应: PCM16 音频数据流                                               │
└────────────────────────────────────┬────────────────────────────────┘
                                     │
                                     ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      PCM数据分发器                                    │
│                                                                      │
│                    PCM Data ──┬──→ PCM播放器 ──→ 扬声器               │
│                               │                                      │
│                               └──→ AEC参考信号                        │
│                                    AudioProcessorService             │
│                                    .feedTTSAudio(pcmData)            │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ↓
┌─────────────────────────────────────────────────────────────────────┐
│                       WebRTC APM                                     │
│                                                                      │
│   麦克风输入 ──→ AEC(有参考信号) ──→ NS ──→ AGC ──→ 干净音频 ──→ ASR   │
└─────────────────────────────────────────────────────────────────────┘
```

### 关键组件设计

#### 1. PCMAudioPlayer - PCM音频播放器

```dart
/// PCM音频播放器
///
/// 使用 flutter_pcm_sound 实现低延迟PCM播放
/// 同时将播放数据传递给AEC作为参考信号
class PCMAudioPlayer {
  /// AEC参考信号回调
  void Function(Uint8List pcmData)? onAudioPlayed;

  /// 播放PCM数据
  ///
  /// [pcmData] PCM16格式，16kHz，单声道
  Future<void> playPCM(Uint8List pcmData) async {
    // 1. 发送给播放器
    await _pcmSound.feed(pcmData);

    // 2. 同时发送给AEC作为参考信号
    onAudioPlayed?.call(pcmData);
  }

  /// 配置
  Future<void> initialize({
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    await FlutterPcmSound.setup(
      sampleRate: sampleRate,
      channelCount: channels,
    );
  }
}
```

#### 2. StreamingTTSService改造

```dart
// 当前实现（MP3）
final uri = Uri.parse(ttsRestUrl).replace(
  queryParameters: {
    'format': 'mp3',  // ← 当前
    ...
  },
);

// 新实现（PCM）
final uri = Uri.parse(ttsRestUrl).replace(
  queryParameters: {
    'format': 'pcm',        // ← 改为PCM
    'sample_rate': '16000', // ← 明确采样率
    ...
  },
);
```

#### 3. OutputPipeline集成

```dart
class OutputPipeline {
  final PCMAudioPlayer _pcmPlayer;
  final AudioProcessorService _audioProcessor;

  Future<void> initialize() async {
    await _pcmPlayer.initialize();

    // 设置AEC参考信号回调
    _pcmPlayer.onAudioPlayed = (pcmData) {
      _audioProcessor.feedTTSAudio(pcmData);
    };
  }

  /// 播放TTS音频
  Future<void> playTTS(Uint8List pcmData) async {
    // 通知AEC开始播放
    _audioProcessor.setTTSPlaying(true);

    await _pcmPlayer.playPCM(pcmData);

    // 通知AEC停止播放
    _audioProcessor.setTTSPlaying(false);
  }
}
```

### 时序图

```
用户说话          TTS服务           PCM播放器         AEC           ASR
    │                │                  │              │              │
    │                │                  │              │              │
    │    LLM回复     │                  │              │              │
    │────────────────→  请求PCM格式    │              │              │
    │                │                  │              │              │
    │                │    PCM数据流     │              │              │
    │                │─────────────────→│              │              │
    │                │                  │              │              │
    │                │                  │  播放+feed   │              │
    │                │                  │─────────────→│              │
    │                │                  │              │              │
    │  (麦克风录入TTS回声)              │              │              │
    │──────────────────────────────────────────────────→  消除回声    │
    │                │                  │              │─────────────→│
    │                │                  │              │   干净音频   │
    │                │                  │              │              │
```

## 兼容性设计

### 离线TTS降级

当网络不可用时，降级到flutter_tts（离线TTS）。此时AEC无参考信号，但可通过以下方式缓解：

1. **TTS播放期间静音ASR**：speaking状态下不发送音频给ASR
2. **VAD打断检测**：仅依赖VAD检测用户真正说话

```dart
Future<void> speak(String text) async {
  if (await _hasNetwork()) {
    // 在线TTS - PCM格式，支持AEC
    await _speakWithPCM(text);
  } else {
    // 离线TTS - flutter_tts，无AEC支持
    // speaking状态下不发音频给ASR
    await _speakWithOfflineTTS(text);
  }
}
```

### 采样率统一

| 组件 | 采样率 | 说明 |
|------|--------|------|
| 阿里云TTS | 16000 Hz | 请求参数指定 |
| PCM播放器 | 16000 Hz | 初始化配置 |
| WebRTC APM | 16000 Hz | 已配置 |
| 阿里云ASR | 16000 Hz | 已使用 |

## 风险评估

### 风险1：PCM数据量大

**影响**：5秒TTS约160KB PCM vs 16KB MP3

**缓解**：
- 流式传输，边下载边播放
- 分句策略已存在，单句数据量可控
- 网络较差时自动降级到离线TTS

### 风险2：flutter_pcm_sound稳定性

**影响**：可能存在平台兼容性问题

**缓解**：
- POC阶段充分测试iOS/Android
- 准备备选方案：flutter_sound、raw_sound
- 最差情况降级到离线TTS

### 风险3：AEC时间对齐

**影响**：参考信号和麦克风输入的延迟不一致可能导致AEC效果差

**缓解**：
- WebRTC AEC3内置自适应延迟估计
- 统一采样率减少处理延迟
- 同步播放和feed操作

## 测试策略

### 单元测试
- PCMAudioPlayer初始化和播放
- AEC参考信号传递

### 集成测试
- TTS播放期间麦克风录音
- 验证AEC消除回声效果

### 手动测试场景
1. TTS播放"晚上好"，检查ASR是否识别出TTS内容（应被AEC消除）
2. TTS播放期间用户说"停"，检查打断是否正常工作
3. 网络断开，验证降级到离线TTS

## 实施顺序

1. **引入flutter_pcm_sound依赖** - 添加到pubspec.yaml
2. **创建PCMAudioPlayer** - 封装PCM播放和AEC feed
3. **修改StreamingTTSService** - 请求PCM格式
4. **集成到OutputPipeline** - 连接播放器和AEC
5. **测试验证** - 确认AEC回声消除生效
