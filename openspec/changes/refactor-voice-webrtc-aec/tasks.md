# 实施任务清单

## 1. 调研与评估

- [ ] 1.1 评估 Flutter WebRTC 音频处理包选项
  - 评估 `flutter_webrtc` 的 AEC/NS/AGC 支持
  - 评估是否有独立的音频处理包
  - 评估各包的许可证、维护状态、兼容性
- [ ] 1.2 验证 WebRTC AEC 在 Flutter 中的可行性
  - 创建 POC 验证 AEC 效果
  - 测试 TTS 播放期间的回声消除效果
- [ ] 1.3 确定最终技术方案
  - 选定音频处理包
  - 确定集成方式

## 2. 清理冗余代码

- [ ] 2.1 删除文本相似度回声过滤相关代码
  - 删除 `echo_filter.dart`
  - 删除 `similarity_calculator.dart`
  - 移除 `input_pipeline.dart` 中的 `_isLikelyEcho` 方法
- [ ] 2.2 简化打断检测器
  - 移除 `barge_in_detector_v2.dart` 中的文本相似度逻辑
  - 保留纯 VAD 打断检测逻辑
- [ ] 2.3 清理 `voice_pipeline_controller.dart`
  - 移除振幅打断检测 `_checkAmplitudeBargeIn`
  - 简化状态管理逻辑

## 3. 集成 WebRTC 音频处理

- [ ] 3.1 添加 WebRTC 音频处理依赖
  - 在 `pubspec.yaml` 添加包依赖
  - 配置 iOS/Android 平台设置
- [ ] 3.2 创建音频预处理管道
  - 实现 `WebRTCAudioProcessor` 类
  - 配置 AEC（需要 TTS 播放作为参考信号）
  - 配置 NS 噪声抑制
  - 配置 AGC 自动增益
- [ ] 3.3 集成到录音流程
  - 修改 `AudioRecorder` 或相关组件
  - 确保 WebRTC 处理后的音频发送给 ASR

## 4. 重构 VAD 打断检测

- [ ] 4.1 优化 Silero VAD 配置
  - 调整 `realtime_vad_config.dart` 参数
  - 优化语音检测灵敏度
- [ ] 4.2 简化打断检测逻辑
  - 创建新的 `SimpleBargeInDetector`
  - 仅基于 VAD speechStart 事件触发打断
  - 添加最小语音持续时间阈值
- [ ] 4.3 集成到流水线
  - 修改 `InputPipeline` 使用新的打断检测器
  - 修改 `VoicePipelineController` 处理打断事件

## 5. TTS 参考信号集成

- [ ] 5.1 实现 TTS 音频回环
  - 将 TTS 播放的音频作为 AEC 参考信号
  - 确保时间对齐
- [ ] 5.2 处理 TTS 状态同步
  - TTS 开始播放时启用 AEC 参考
  - TTS 停止播放时停用 AEC 参考

## 6. 测试与验证

- [ ] 6.1 单元测试
  - 测试 WebRTC 音频处理模块
  - 测试 VAD 打断检测
- [ ] 6.2 集成测试
  - 测试完整语音对话流程
  - 测试 TTS 播放期间的回声消除
  - 测试打断功能
- [ ] 6.3 真机测试
  - iOS 设备测试
  - Android 设备测试
  - 不同音量、环境噪音下测试

## 7. 文档与收尾

- [ ] 7.1 更新架构文档
  - 更新语音处理架构说明
  - 记录 WebRTC 配置参数
- [ ] 7.2 清理废弃代码
  - 确认无残留的废弃引用
  - 运行 `dart analyze` 检查
