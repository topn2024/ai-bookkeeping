# 语音助手重构 - 任务清单（参考 LiveKit 设计）

## 阶段1: 创建新的状态机和控制器

- [ ] **1.1 创建 VoiceSessionState 枚举**
  - 文件: `lib/services/voice/voice_session_state.dart`
  - 定义 4 个状态: idle, listening, thinking, speaking
  - 定义 UserState 枚举: idle, speaking, away

- [ ] **1.2 创建 VoiceSessionStateMachine 类**
  - 文件: `lib/services/voice/voice_session_state_machine.dart`
  - 实现状态转换验证表
  - 实现状态变化流 (Stream)
  - 实现辅助属性 (shouldRunASR, shouldRunVAD, isInterruptible)

- [ ] **1.3 创建 VoiceSessionConfig 配置类**
  - 文件: `lib/services/voice/voice_session_config.dart`
  - 参考 LiveKit 参数:
    - allowInterruptions = true
    - interruptionConfirmDelay = 500ms
    - falseInterruptionTimeout = 2s
    - resumeFalseInterruption = true

- [ ] **1.4 创建 VoiceSessionController 类**
  - 文件: `lib/services/voice/voice_session_controller.dart`
  - 集成状态机
  - 实现服务配置逻辑 (_configureServicesForState)
  - 实现打断检测 (500ms 确认)
  - 实现假打断恢复 (2s 超时)
  - 实现 ASR 结果处理

## 阶段2: 单元测试

- [ ] **2.1 状态机测试**
  - 测试所有有效状态转换
  - 测试无效状态转换被拒绝
  - 测试状态流正确发送

- [ ] **2.2 控制器测试**
  - 测试服务启停配置
  - 测试打断检测逻辑 (500ms)
  - 测试假打断恢复逻辑 (2s)

## 阶段3: 集成到现有代码

- [ ] **3.1 修改 TTSService 为单例**
  - 文件: `lib/services/tts_service.dart`
  - 添加单例模式
  - 确保只有一个实例

- [ ] **3.2 修改 GlobalVoiceAssistantManager**
  - 引入 VoiceSessionController
  - 移除旧的标志位:
    - `_isProcessingCommand`
    - `_isTTSPlayingWithBargeIn`
    - `_isProactiveConversation`
    - `_isRestartingASR`
  - 修改 startRecording() 使用新控制器
  - 修改 stopRecording() 使用新控制器
  - 移除 1.5 秒延迟等待

- [ ] **3.3 清理废弃代码**
  - 移除 _enableBargeInDetection() / _disableBargeInDetection()
  - 移除 _handleBargeInEvent() / _onBargeInDetected()
  - 移除 _restartASRIfNeeded()
  - 移除回声等待延迟逻辑
  - 删除 `lib/services/voice/barge_in_detector.dart`（功能已整合）

## 阶段4: 真机测试验证

- [ ] **4.1 基本功能测试**
  - 测试记账功能
  - 测试聊天功能
  - 测试查询功能

- [ ] **4.2 无延迟验证**
  - TTS 播放完成后立即可说话
  - 验证用户输入不被忽略

- [ ] **4.3 打断测试**
  - 验证说话 500ms 后 TTS 停止
  - 验证打断后能正常接收新输入

- [ ] **4.4 假打断恢复测试**
  - 清嗓子/短暂噪音后 TTS 恢复播放
  - 验证 2 秒超时逻辑

- [ ] **4.5 回声测试**
  - 验证 TTS 播放内容不会被 ASR 识别
  - 验证多轮对话不会出现循环

- [ ] **4.6 稳定性测试**
  - 连续使用 10 分钟无异常
  - 快速连续操作无崩溃

## 阶段5: 发布

- [ ] **5.1 代码审查**
  - 确认所有旧标志位已删除
  - 确认无 1.5 秒延迟残留

- [ ] **5.2 构建 Release APK**
  - 包含 QWEN_API_KEY
  - 版本号递增

- [ ] **5.3 发布到服务器**
  - 使用 publish_apk.sh

## 依赖关系

```
1.1 ──> 1.2 ──> 1.3 ──> 1.4 ──> 2.1 ──> 2.2 ──> 3.1 ──> 3.2 ──> 3.3 ──> 4.x ──> 5.x
```

## 回滚计划

如果新实现出现严重问题:
1. 新代码在独立文件中，可随时禁用
2. 通过 feature flag 控制: `_useNewStateMachine = false`
3. 可以随时切换回旧实现

## 核心改进检查清单

在每个阶段完成后确认:

- [ ] 状态是否由单一状态机管理？（不是多个标志位）
- [ ] TTS 完成后是否有延迟？（应该没有）
- [ ] 打断确认时间是否为 500ms？
- [ ] 假打断是否会在 2s 后恢复播放？
- [ ] speaking 状态时 ASR 是否停止？（不是运行但忽略结果）

## 关键对比

| 维度 | 旧实现 | 新实现 |
|------|--------|--------|
| 状态管理 | 6+ 标志位 | 4 状态状态机 |
| TTS 后延迟 | 1.5s | 0 |
| 打断确认 | 300ms | 500ms |
| 假打断恢复 | 无 | 2s 后恢复 |
| speaking 时 ASR | 运行但忽略 | 停止 |
