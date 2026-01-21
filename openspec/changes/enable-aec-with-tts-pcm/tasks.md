# 任务清单：启用AEC回声消除 - TTS PCM数据作为参考信号

## 阶段1：依赖引入与POC验证

### 1.1 引入flutter_pcm_sound依赖
- [ ] 在pubspec.yaml添加flutter_pcm_sound依赖
- [ ] 运行flutter pub get
- [ ] 验证iOS/Android编译通过

### 1.2 POC验证PCM播放
- [ ] 创建简单测试页面
- [ ] 测试flutter_pcm_sound基本播放功能
- [ ] 验证16kHz单声道PCM播放正常
- [ ] 测试iOS和Android平台兼容性

## 阶段2：PCM播放器实现

### 2.1 创建PCMAudioPlayer类
- [ ] 创建 `lib/services/voice/pcm_audio_player.dart`
- [ ] 实现initialize()初始化方法
- [ ] 实现playPCM()播放方法
- [ ] 添加onAudioPlayed回调用于AEC
- [ ] 实现stop()停止方法
- [ ] 实现dispose()资源释放

### 2.2 集成AEC参考信号
- [ ] 在playPCM()中调用onAudioPlayed回调
- [ ] 确保播放和AEC feed同步
- [ ] 添加调试日志验证数据流

## 阶段3：TTS服务改造

### 3.1 修改StreamingTTSService
- [ ] 修改_synthesizeToFile请求PCM格式（format=pcm）
- [ ] 添加sample_rate=16000参数
- [ ] 修改返回数据处理（不再保存为MP3文件）
- [ ] 改用PCMAudioPlayer播放

### 3.2 适配AlibabaCloudTTSEngine
- [ ] 修改synthesize()方法返回PCM格式
- [ ] 修改speak()方法使用PCM播放
- [ ] 保持与StreamingTTSService一致的实现

## 阶段4：OutputPipeline集成

### 4.1 修改OutputPipeline
- [ ] 注入PCMAudioPlayer依赖
- [ ] 注入AudioProcessorService依赖
- [ ] 设置onAudioPlayed回调连接到feedTTSAudio
- [ ] 在播放前调用setTTSPlaying(true)
- [ ] 在播放后调用setTTSPlaying(false)

### 4.2 错误处理
- [ ] PCM播放失败时的降级处理
- [ ] 网络错误时降级到离线TTS
- [ ] 添加适当的错误日志

## 阶段5：测试验证

### 5.1 功能测试
- [ ] 验证TTS正常播放
- [ ] 验证AEC参考信号正确传递（查看日志）
- [ ] 验证feedTTSAudio被正确调用

### 5.2 AEC效果测试
- [ ] TTS播放期间麦克风录音
- [ ] 检查ASR是否不再识别TTS回声
- [ ] 测试用户打断功能正常

### 5.3 边界情况测试
- [ ] 测试网络断开时的降级
- [ ] 测试快速连续TTS播放
- [ ] 测试TTS被打断时的资源清理

## 阶段6：代码清理

### 6.1 移除冗余代码
- [ ] 评估AudioStreamPlayer是否仍需要
- [ ] 清理不再使用的MP3相关代码
- [ ] 更新相关注释和文档

---

## 依赖关系

```
1.1 → 1.2 → 2.1 → 2.2 → 3.1 → 4.1 → 5.1
                    ↓
                   3.2
```

## 验收标准

1. TTS播放时，麦克风输入经过AEC处理后不包含TTS回声
2. ASR不再识别出TTS播放的内容
3. 用户可以在TTS播放期间正常打断
4. 离线场景下graceful降级到flutter_tts
