# 变更：启用AEC回声消除 - 获取TTS PCM数据作为参考信号

## 变更ID
`enable-aec-with-tts-pcm`

## 为什么

当前AEC（声学回声消除）形同虚设，TTS播放的声音被ASR识别为用户输入。

### 问题分析

1. **AEC需要参考信号**：WebRTC AEC需要知道扬声器播放了什么音频，才能从麦克风输入中消除回声
2. **feedTTSAudio从未被调用**：`AudioProcessorService.feedTTSAudio()` 方法存在但从未使用
3. **无法获取TTS PCM数据**：
   - `flutter_tts`：系统级TTS，直接输出到扬声器，无法获取音频数据
   - `AlibabaCloudTTSEngine`：下载MP3文件，用`just_audio`播放，无法获取解码后的PCM
   - `just_audio`：不支持获取解码后的PCM数据回调

### 根本原因

```
当前流程：
TTS服务 → MP3文件 → just_audio播放 → 扬声器
                         ↓
                    无法获取PCM
                         ↓
                    AEC无参考信号
                         ↓
                    回声无法消除
```

## 变更内容

### 核心思路

利用阿里云TTS支持**直接返回PCM格式**的特性，将TTS音频数据同时用于播放和AEC参考。

```
新流程：
阿里云TTS → PCM数据 → 分流
                      ├→ PCM播放器 → 扬声器
                      └→ AEC参考信号 → feedTTSAudio()
```

### 具体改造

1. **修改TTS请求格式**：从`format=mp3`改为`format=pcm`
2. **引入PCM播放器**：使用`flutter_pcm_sound`替代`just_audio`播放PCM
3. **集成AEC参考信号**：播放PCM的同时，将数据传给`AudioProcessorService.feedTTSAudio()`

### 影响范围

| 组件 | 变更 |
|------|------|
| `StreamingTTSService` | 请求PCM格式，使用PCM播放器 |
| `AudioStreamPlayer` | 新增PCM播放能力或替换实现 |
| `OutputPipeline` | 集成AEC参考信号传递 |
| `pubspec.yaml` | 新增`flutter_pcm_sound`依赖 |

### 保持不变

- `AudioProcessorService`：已有`feedTTSAudio()`方法，无需修改
- `WebrtcAudioProcessor`：已有`feedRenderAudio()`方法，无需修改
- `FlutterTTSEngine`：离线TTS保持原样（作为降级方案）
- 意图识别和执行层：完全不受影响

## 技术决策

### 决策1：使用阿里云TTS的PCM输出

**选择**：请求`format=pcm`而非`format=mp3`

**理由**：
- 阿里云TTS原生支持PCM/WAV/MP3三种格式
- PCM是未压缩格式，可直接用于AEC参考信号
- 无需额外解码步骤

**代价**：
- PCM数据量比MP3大约10倍
- 需要更多网络带宽和内存

### 决策2：使用flutter_pcm_sound播放

**选择**：使用`flutter_pcm_sound`包播放PCM数据

**理由**：
- 专为实时PCM播放设计
- 支持低延迟流式播放
- 提供feed回调机制，可精确同步AEC

**替代方案考虑**：
- ❌ `just_audio`：不支持PCM数据回调
- ❌ `flutter_soloud`：功能过于复杂，主要面向游戏
- ❌ 自行解码MP3：增加复杂度和延迟

### 决策3：采样率配置

**选择**：统一使用16kHz采样率

**理由**：
- ASR使用16kHz，保持一致
- WebRTC APM配置为16kHz
- 减少重采样开销

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| PCM数据量大 | 网络带宽增加 | 仅在线TTS使用PCM，离线TTS保持不变 |
| flutter_pcm_sound兼容性 | iOS/Android差异 | POC验证，准备fallback到flutter_sound |
| 播放延迟增加 | 首字延迟变长 | 流式分句+预取机制（已有） |
| AEC时间对齐 | 回声消除效果差 | WebRTC内置自适应延迟补偿 |

## 实施范围

本提案仅解决**AEC参考信号获取**问题，属于 `refactor-voice-webrtc-aec` 大提案的一个关键子问题。

### 前置条件
- WebRTC APM已集成并工作（已完成）
- `feedTTSAudio()`方法已存在（已完成）

### 后续工作
- TTS播放期间的ASR输入处理（可能仍需配合speaking状态的输入过滤）
- AEC参数调优

## 参考资料

- [阿里云TTS RESTful API](https://help.aliyun.com/document_detail/94737.html) - 支持PCM/WAV/MP3格式
- [flutter_pcm_sound](https://pub.dev/packages/flutter_pcm_sound) - PCM实时播放
- [WebRTC AEC原理](https://walterfan.github.io/webrtc_note/3.media/audio_aec.html) - 需要render audio作为参考
