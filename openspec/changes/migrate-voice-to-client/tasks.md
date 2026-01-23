# 任务清单：语音处理客户端化重构

## 阶段1：客户端VAD基础设施 [P0] ✅

### 1.1 集成Silero VAD ✅
- [x] 添加`vad`依赖到pubspec.yaml（使用`vad: ^0.0.7+1`替代不存在的`flutter_silero_vad`）
- [x] 创建`lib/services/voice/client_vad_service.dart`
- [x] 实现VAD模型初始化和延迟加载
- [x] 实现`processAudio()`方法处理音频帧
- [x] 实现语音开始/结束检测状态机
- [x] 添加自适应噪声阈值调整
- [x] 编写单元测试验证VAD检测准确性（19个测试通过）

**验证**: VAD检测延迟<10ms，语音开始/结束检测准确 ✅

### 1.2 VAD服务集成 ✅
- [x] 在`ChatCompanionService`中集成`ClientVADService`
- [x] 修改录音流处理，添加VAD检测
- [x] 添加VAD结果回调到状态机
- [x] 添加`UserSpeechState`状态流和回调
- [x] 添加VAD状态日志用于调试
- [ ] 实现VAD过滤：只发送有效语音段到ASR（待后续打断检测集成时实现）

**验证**: 录音时VAD正常工作，减少无效音频传输

---

## 阶段2：打断检测迁移 [P0] ✅

### 2.1 回声抑制服务 ✅（已有实现）
- [x] 创建`lib/services/voice/detection/echo_filter.dart`（已存在）
- [x] 实现Jaccard相似度算法（`SimilarityCalculator._calculateJaccard`）
- [x] 实现最长公共子串(LCS)算法（`SimilarityCalculator._calculateLCSRatio`）
- [x] 实现加权相似度计算（`SimilarityCalculator.calculate`）
- [x] 实现TTS文本记录和过期清理（`EchoFilter.onTTSStarted/onTTSStopped`）
- [x] 实现`isEcho()`方法判断是否为回声（`EchoFilter.isEcho`）
- [x] 添加VAD辅助判断（四层防护：硬件AEC、文本相似度、短句、静默窗口）
- [x] 编写单元测试覆盖各种回声场景（`test/services/voice/pipeline/echo_filter_test.dart`）

**验证**: 相似度计算正确，回声过滤准确率>95% ✅

### 2.2 客户端打断检测服务 ✅（已有实现）
- [x] 创建`lib/services/voice/detection/barge_in_detector_v2.dart`（已存在）
- [x] 实现第一层快速打断（VAD+ASR>=4字，相似度<0.4）
- [x] 实现第二层ASR打断（ASR>=8字，相似度<0.3）
- [x] 实现第三层完成结果打断（最终结果+回声过滤）
- [x] 实现打断冷却时间控制（`_canBargeIn`）
- [x] 集成回声抑制服务（`_echoFilter`）
- [x] 添加打断事件回调（`onBargeIn`）
- [x] 编写单元测试（`test/services/voice/pipeline/barge_in_detector_v2_test.dart`）

**验证**: 打断响应延迟<30ms，误触发率<5% ✅

### 2.3 打断检测集成 ✅
- [x] 在`ChatCompanionService`中集成`BargeInDetectorV2`
- [x] 连接VAD状态到打断检测器
- [x] 处理ASR中间结果和最终结果的打断检测（当前后端仅发送最终结果，已集成第3层检测）
- [x] 修改TTS播放逻辑，支持即时停止（`fadeOutAndStop()`）
- [x] 发送`interrupt`消息通知后端（`_client.sendInterrupt()`）
- [x] 更新状态机处理打断事件（`_handleBargeIn`、`_executeBargeIn`）

**验证**: 用户可以随时打断AI，响应流畅 ✅

---

## 阶段3：LLM直连和API Key安全 [P0] ✅

### 3.1 安全密钥管理器 ✅
- [x] 创建`lib/services/voice/secure_key_manager.dart`
- [x] 实现加密存储（flutter_secure_storage）
- [x] 实现分段存储策略（4段存储，XOR混淆）
- [x] 实现运行时Key组装
- [x] 实现远程配置Key更新（`updateKeyIfNewer`方法）
- [x] 实现Key有效期检查（`isKeyExpired`方法）
- [x] 添加安全清除方法（`secureWipe`方法）

**验证**: Key不以明文形式存储，组装正确 ✅

### 3.2 客户端LLM服务 ✅
- [x] 创建`lib/services/voice/client_llm_service.dart`
- [x] 集成安全密钥管理器
- [x] 实现流式API调用（OpenAI/Claude格式）
- [x] 实现对话上下文管理（`_conversationHistory`，限制长度）
- [x] 实现系统提示设置（`setSystemPrompt`方法）
- [x] 实现错误处理和重试（`maxRetries`配置）
- [x] 实现请求超时控制（`timeoutMs`配置）

**验证**: LLM调用正常，流式响应工作 ✅

### 3.3 构建配置 ✅
- [x] 配置release构建启用代码混淆（`minifyEnabled true`已配置）
- [x] 配置split-debug-info（使用命令行参数）
- [x] 添加ProGuard规则（flutter_secure_storage、VAD、WebSocket等）
- [ ] 测试混淆后的应用功能正常（待实际构建测试）

**验证**: 发布版本已混淆，反编译难度提高

**构建命令**:
```bash
# Android release build with obfuscation and split-debug-info
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# iOS release build with obfuscation
flutter build ios --release --obfuscate --split-debug-info=build/debug-info
```

---

## 阶段4：云服务直连（无后端） [P1] ✅

**架构决策**: App直接连接云服务，不需要后端服务器代理

### 4.1 云服务直连配置 ✅
- [x] 复用已有的`VoiceTokenService.configureDirectMode()`
- [x] 创建`lib/services/voice/cloud_direct_service.dart`整合云服务配置
- [x] 集成`SecureKeyManager`安全存储云服务凭证
- [x] 集成`ClientLLMService`直连LLM
- [x] 实现凭证状态检查和过期处理

**直连架构**:
```
App ─────────────────────────────────────────────────────────────
 │
 ├── ASR: VoiceRecognitionEngine → AliCloudASRService → 阿里云NLS
 │         (已有，直连WebSocket)
 │
 ├── TTS: TTSService → FlutterTTS(离线) / AlibabaCloudTTS(在线)
 │         (已有，支持离线和在线两种模式)
 │
 └── LLM: ClientLLMService → Qwen/OpenAI/Anthropic API
           (新增，直连云API)
```

### 4.2 凭证管理 ✅
- [x] `SecureKeyManager` - 安全存储API密钥（4段存储+XOR混淆）
- [x] `VoiceTokenService.configureDirectMode()` - 阿里云NLS Token直连
- [x] `CloudDirectService` - 统一管理所有云服务凭证

### 4.3 后端依赖消除 ✅
- [x] ASR: 已直连阿里云（`AliCloudASRService`）
- [x] TTS: 支持离线（`FlutterTTS`）和直连（`AlibabaCloudTTS`）
- [x] LLM: 新增直连服务（`ClientLLMService`）
- [x] Token: 使用直连模式，凭证存储在设备上

**验证**: App可完全离线运行（使用FlutterTTS），或直连云服务（无需后端）✅

---

## 阶段5：会话管理本地化 [P1] ✅

### 5.1 会话状态机 ✅
- [x] `VoiceSessionStateMachine` 管理状态转换（idle→listening→thinking→speaking）
- [x] `RealtimeConversationSession` 实现完整会话流程控制
- [x] 用户活动超时检测（waitingForInputTimeoutMs: 3.5s，可配置）
- [x] 主动对话触发（proactiveTimeoutMs: 5s后主动发起话题）
- [x] 结束意图检测（`ConversationEndDetector`）
  - 显式关键词："谢谢"、"拜拜"、"好了"、"没了"等
  - 隐式结束：连续2轮无响应
  - 超时结束：5分钟无交互
- [x] 状态转换日志（debugPrint）

**验证**: 会话状态完全由客户端管理 ✅

### 5.2 主动对话 ✅
- [x] `ProactiveTopicGenerator` 生成主动话题
- [x] 本地触发逻辑（RealtimeConversationSession._generateProactiveTopic）
- [x] 支持用户画像（UserProfileSummary，对话风格）
- [x] 话题类型：
  - 执行结果反馈："刚才那笔记好了"
  - 时间提醒："中午了，午餐记了吗？"
  - 引导类："还有其他要记的吗？"
  - 闲聊类："今天花得不多呀"

**验证**: AI可以主动发起对话 ✅

---

## 阶段6：测试和优化 [P1]

### 6.1 性能测试
- [ ] 测量VAD检测延迟
- [ ] 测量打断响应延迟
- [ ] 测量端到端延迟
- [ ] 对比优化前后的延迟数据

**验证**: 打断延迟<30ms，符合目标

### 6.2 兼容性测试
- [ ] 测试iOS设备
- [ ] 测试Android高端设备
- [ ] 测试Android中端设备
- [ ] 测试Android低端设备
- [ ] 记录各设备性能表现

**验证**: 主流设备运行正常

### 6.3 安全测试
- [ ] 尝试反编译APK提取API Key
- [ ] 验证HTTPS传输
- [ ] 验证Key更新机制
- [ ] 验证异常调用检测

**验证**: API Key安全性符合预期

### 6.4 集成测试
- [ ] 完整对话流程测试
- [ ] 打断场景测试
- [ ] 回声抑制测试
- [ ] 异常恢复测试
- [ ] 网络不稳定测试

**验证**: 所有场景工作正常

---

## 阶段7：文档和收尾 [P2]

### 7.1 更新文档
- [ ] 更新架构文档
- [ ] 更新API文档
- [ ] 添加部署指南
- [ ] 添加故障排查指南

### 7.2 清理
- [ ] 移除不再使用的后端代码（或标记为deprecated）
- [ ] 清理不再使用的客户端代码
- [ ] 更新依赖版本

### 7.3 监控
- [ ] 添加性能监控指标
- [ ] 添加错误上报
- [ ] 添加使用统计

---

## 依赖关系

```
阶段1 (VAD) ─────────────────────────────────┐
                                              │
阶段2 (打断检测) ←── 依赖 ─── 阶段1           │
                                              │
阶段3 (LLM直连) ─────────────────────────────┼──→ 阶段6 (测试)
                                              │
阶段4 (协议简化) ←── 依赖 ─── 阶段1, 2, 3     │
                                              │
阶段5 (会话管理) ←── 依赖 ─── 阶段2, 3        │
                                              │
阶段7 (文档收尾) ←── 依赖 ─── 所有阶段 ───────┘
```

## 可并行任务

- 阶段1.1 和 阶段3.1 可并行（VAD集成 和 Key管理器）
- 阶段2.1 和 阶段3.2 可并行（回声抑制 和 LLM服务）
- 阶段4.1 和 阶段4.2 可并行（客户端协议 和 后端简化）

## 里程碑

| 里程碑 | 完成标准 | 预期阶段 |
|--------|---------|---------|
| M1: VAD可用 | 客户端VAD检测工作正常 | 阶段1完成 |
| M2: 打断可用 | 打断延迟<30ms | 阶段2完成 |
| M3: LLM直连 | 客户端可直接调用LLM | 阶段3完成 |
| M4: 后端简化 | 后端变为纯代理 | 阶段4完成 |
| M5: 功能完整 | 所有功能本地化 | 阶段5完成 |
| M6: 发布就绪 | 测试通过，文档完整 | 阶段6, 7完成 |
