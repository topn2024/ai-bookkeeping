# 已知问题清单

## 语音识别相关

### #001 模拟器麦克风无法录制真实音频
- **状态**: 已知限制
- **描述**: Android 模拟器的麦克风录制的是静音数据，导致语音识别返回空结果
- **日志特征**: `pcm_readi was late delivering frames, inserting silence`
- **影响**: 在模拟器上测试语音记账功能时会显示"未检测到语音内容"
- **解决方案**:
  - 在真实设备上测试语音功能
  - 模拟器可使用命令行注入音频（高级用法）
- **修复日期**: 2025-12-30
- **相关代码**: `app/lib/services/qwen_service.dart:_extractAudioJsonResult()`

### #002 千问音频API请求格式
- **状态**: 已修复
- **描述**: 千问全模态API的音频输入格式应为 `{ 'audio': 'data:audio/format;base64,...' }`
- **错误信息**: `InvalidParameter: Input should be 'text', 'image', 'audio', 'video'`
- **修复**: 将 `type: 'input_audio'` 改为直接使用 `audio` 字段
- **修复日期**: 2025-12-30
- **相关代码**: `app/lib/services/qwen_service.dart:recognizeAudio()`

### #003 语音识别API Key未配置
- **状态**: 已修复
- **描述**: 用户登录后 QwenService 未重新初始化，导致使用空的 API Key
- **错误信息**: `No API-key provided`
- **修复**: 在登录/注册/OAuth 成功后调用 `QwenService().reinitialize()`
- **修复日期**: 2025-12-30
- **相关代码**:
  - `app/lib/services/qwen_service.dart:reinitialize()`
  - `app/lib/providers/auth_provider.dart`

## 性能相关

### #004 语音记账页面ANR (Application Not Responding)
- **状态**: 已修复
- **描述**: 点击语音记账按钮后应用无响应
- **原因**:
  1. 波形动画在 AnimationController listener 中递归调用 `forward(from: 0)`
  2. 脉冲动画在 initState 中立即启动
  3. 录音时长每 100ms 更新一次 setState
- **修复**:
  1. 改用 `repeat()` 方法控制动画循环
  2. 脉冲动画仅在 idle 状态时启动
  3. 录音时长更新频率降低到 500ms
- **修复日期**: 2025-12-30
- **相关代码**: `app/lib/pages/voice_recognition_page.dart`

---
*最后更新: 2025-12-31*
