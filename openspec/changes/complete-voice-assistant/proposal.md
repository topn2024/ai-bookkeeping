# 变更：完善语音智能助手实现

## 为什么

当前语音智能助手的架构设计完整，但核心的语音识别(ASR)和语音合成(TTS)服务仍为模拟实现，无法在生产环境中提供真实的语音交互功能。此外还存在多个未完成的TODO项和功能缺失，影响用户体验的完整性。

## 变更内容

### 高优先级（必须）
- 实现阿里云ASR真实API调用（HTTP REST和WebSocket流式识别）
- 实现阿里云TTS真实API调用
- 集成Flutter TTS系统级语音合成
- 实现API密钥安全管理和Token刷新机制
- 完善权限检查逻辑

### 中优先级（重要）
- 集成端侧唤醒词检测引擎（Porcupine或Snowboy）
- 实现确认流程UI反馈
- 完成命令历史显示功能
- 完善网络错误和API限流处理

### 低优先级（优化）
- 实现音频流缓冲优化
- 添加识别超时机制
- 增强测试覆盖
- 完善API文档

## 影响

- 受影响规范：voice-assistant（新建）
- 受影响代码：
  - `app/lib/services/voice_recognition_engine.dart` - ASR实现
  - `app/lib/services/tts_service.dart` - TTS实现
  - `app/lib/services/voice_wake_word_service.dart` - 唤醒词服务
  - `app/lib/services/voice_service_provider.dart` - 服务提供者
  - `app/lib/pages/enhanced_voice_assistant_page.dart` - 增强助手页面
  - `app/lib/pages/voice_recognition_page.dart` - 语音识别页面

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 阿里云API调用失败 | 高 | 实现离线ASR降级机制 |
| 唤醒词检测精度不足 | 中 | 支持灵敏度调节 |
| API密钥泄露 | 高 | 使用flutter_secure_storage |
| 网络延迟影响体验 | 中 | 实现流式识别和本地缓存 |

## 验收标准

1. 用户可以使用语音进行真实的记账操作
2. 语音识别准确率达到95%以上（普通话环境）
3. TTS播报流畅自然，延迟小于500ms
4. 唤醒词检测可在后台运行
5. 无网络时自动切换到离线识别
6. 所有TODO项已完成或有明确的处理方案
