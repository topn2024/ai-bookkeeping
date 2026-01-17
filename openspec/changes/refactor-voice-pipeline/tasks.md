# 语音处理流水线重构 - 任务清单

## 阶段1：核心组件开发（P0）

### 1.1 基础工具类

- [x] **创建 SimilarityCalculator**
  - 文件：`app/lib/services/voice/detection/similarity_calculator.dart`
  - 实现 Jaccard 相似度计算
  - 实现最长公共子串比率计算
  - 实现综合相似度算法
  - 单元测试覆盖

- [x] **创建 ResponseTracker**
  - 文件：`app/lib/services/voice/tracking/response_tracker.dart`
  - 实现响应ID生成和追踪
  - 实现当前响应检查
  - 单元测试覆盖

- [x] **创建 PipelineConfig**
  - 文件：`app/lib/services/voice/config/pipeline_config.dart`
  - 定义所有可配置参数
  - 提供默认配置和预设配置

### 1.2 句子缓冲与TTS队列

- [x] **创建 SentenceBuffer**
  - 文件：`app/lib/services/voice/pipeline/sentence_buffer.dart`
  - 实现流式文本句子分割
  - 支持中文标点（。！？；）和英文标点
  - 实现最小句子长度控制
  - 单元测试覆盖

- [x] **创建 TTSQueueWorker**
  - 文件：`app/lib/services/voice/pipeline/tts_queue_worker.dart`
  - 实现句子队列管理
  - 实现流式TTS合成调用
  - 实现响应ID过期检查
  - 实现停止和重置功能
  - 集成测试

- [ ] **验证流式TTS流水线**
  - 集成 SentenceBuffer + TTSQueueWorker
  - 测试首字延迟是否达到目标（<600ms）
  - 测试多句子连续播放

## 阶段2：打断与回声防护（P0）

### 2.1 回声过滤

- [x] **创建 EchoFilter**
  - 文件：`app/lib/services/voice/detection/echo_filter.dart`
  - 实现TTS状态跟踪
  - 实现静默窗口管理
  - 实现文本相似度过滤
  - 实现短句过滤
  - 单元测试覆盖

### 2.2 三层打断检测

- [x] **创建 BargeInDetectorV2**
  - 文件：`app/lib/services/voice/detection/barge_in_detector_v2.dart`
  - 实现第1层：VAD + ASR中间结果检测
  - 实现第2层：纯ASR中间结果检测
  - 实现第3层：完整句子 + 四层回声过滤
  - 实现冷却时间控制
  - 集成 SimilarityCalculator
  - 单元测试覆盖

- [ ] **验证打断检测**
  - 测试打断响应时间（<300ms）
  - 测试回声误触发率（<1%）
  - 测试各层触发条件

## 阶段3：流水线集成（P0）

### 3.1 输入流水线

- [x] **创建 InputPipeline**
  - 文件：`app/lib/services/voice/pipeline/input_pipeline.dart`
  - 集成 VAD 检测
  - 集成 ASR 流式识别
  - 实现中间结果和最终结果回调
  - 实现语音开始/结束事件

### 3.2 处理流水线

- [x] **处理流水线集成到 VoicePipelineController**
  - 通过 onProcessInput 回调集成现有 ConversationalAgent
  - 实现流式LLM输出处理
  - 实现取消功能（通过 ResponseTracker）

### 3.3 输出流水线

- [x] **创建 OutputPipeline**
  - 文件：`app/lib/services/voice/pipeline/output_pipeline.dart`
  - 集成 SentenceBuffer
  - 集成 TTSQueueWorker
  - 集成 EchoFilter
  - 实现完成和停止控制

### 3.4 流水线控制器

- [x] **创建 VoicePipelineController**
  - 文件：`app/lib/services/voice/pipeline/voice_pipeline_controller.dart`
  - 协调三条流水线
  - 集成 BargeInDetectorV2
  - 集成 ResponseTracker
  - 实现状态机管理
  - 实现打断处理

- [ ] **集成测试**
  - 完整对话流程测试
  - 打断场景测试
  - 异常恢复测试

## 阶段4：现有代码迁移（P1）

### 4.1 功能开关

- [x] **添加特性开关**
  - 文件：`app/lib/services/voice/config/feature_flags.dart`
  - 添加 `usePipelineMode` 开关
  - 支持运行时切换
  - 支持配置文件控制（SharedPreferences 持久化）

### 4.2 GlobalVoiceAssistantManager 改造

- [x] **集成流水线控制器**
  - 修改 `startRecording()` 支持流水线模式
  - 修改 `stopRecording()` 支持流水线模式
  - 保留旧实现作为降级方案
  - 通过特性开关控制
  - 添加 `_startRecordingWithPipeline()` 和 `_stopRecordingWithPipeline()`
  - 设置流水线回调连接到现有 UI 状态管理

- [ ] **清理旧代码**
  - 移除不再使用的状态管理代码
  - 移除冗余的回声处理代码
  - 简化打断检测逻辑

### 4.3 测试与验证

- [ ] **A/B 对比测试**
  - 对比新旧实现的首字延迟
  - 对比新旧实现的打断响应
  - 对比新旧实现的回声误触发率

- [ ] **回归测试**
  - 验证所有现有功能正常
  - 验证记账流程正常
  - 验证查询流程正常

## 阶段5：优化与文档（P2）

### 5.1 性能优化

- [ ] **内存优化**
  - 实现音频缓冲区对象池
  - 优化字符串处理减少分配
  - 添加内存监控

- [ ] **CPU优化**
  - 使用 compute 隔离密集计算
  - 添加节流控制
  - 优化相似度计算算法

### 5.2 文档更新

- [ ] **更新用户文档**
  - 添加语音交互最佳实践
  - 更新FAQ

- [ ] **更新开发文档**
  - 添加流水线架构说明
  - 添加扩展指南
  - 添加调试指南

### 5.3 监控与日志

- [ ] **添加性能监控**
  - 记录首字延迟
  - 记录打断响应时间
  - 记录回声过滤统计

- [ ] **优化日志**
  - 添加结构化日志
  - 添加关键事件追踪
  - 支持日志级别控制

## 任务依赖关系

```
阶段1.1（基础工具类）
    │
    ├──▶ 阶段1.2（句子缓冲与TTS队列）
    │         │
    │         └──▶ 阶段2（打断与回声防护）
    │                   │
    │                   └──▶ 阶段3（流水线集成）
    │                             │
    │                             └──▶ 阶段4（现有代码迁移）
    │                                       │
    │                                       └──▶ 阶段5（优化与文档）
```

## 验收检查点

### 检查点1：流式TTS流水线
- [ ] 首字延迟 < 600ms（从ASR最终结果到TTS首音频）
- [ ] 句子分割正确率 > 99%
- [ ] 多句子连续播放流畅

### 检查点2：打断与回声防护
- [ ] 打断响应时间 < 300ms
- [ ] 回声误触发率 < 1%
- [ ] 三层打断检测各层可独立工作

### 检查点3：流水线集成
- [ ] 完整对话流程正常
- [ ] 打断后能正确处理新输入
- [ ] 异常情况能优雅降级

### 检查点4：代码迁移
- [ ] 功能开关可正常切换
- [ ] 回归测试全部通过
- [ ] 性能指标达到目标

### 检查点5：优化完成
- [ ] 内存无明显泄漏
- [ ] CPU占用在合理范围
- [ ] 文档更新完成

## 依赖合规检查

### 外部依赖清单（仅保持现有依赖）

| 依赖 | 用途 | 许可证 | 商业使用 |
|------|------|--------|---------|
| 阿里云语音识别 | ASR | 商业协议 | ✅ 已签约 |
| 阿里云语音合成 | TTS | 商业协议 | ✅ 已签约 |
| 阿里云通义大模型 | LLM | 商业协议 | ✅ 已签约 |
| flutter_silero_vad | VAD | MIT | ✅ 允许 |
| just_audio | 音频播放 | MIT | ✅ 允许 |

### 明确不引入的依赖

| 依赖 | 原因 |
|------|------|
| TEN Framework | Apache 2.0 + 额外限制，许可证风险 |
| TEN VAD | 许可证需核实，有替代方案 |
| TEN Turn Detection | 许可证需核实，有替代方案 |
| LiveKit Agents | 增加部署复杂度，非必要 |
| 其他第三方语音框架 | 保持依赖最小化原则 |

### 资源消耗预算

| 指标 | 预算上限 | 监控方法 |
|------|---------|---------|
| CPU增加 | < 5% | 性能测试对比 |
| 内存增加 | < 10MB | 内存Profile |
| 启动时间增加 | < 100ms | 冷启动测试 |
| APK体积增加 | < 500KB | 构建对比 |
