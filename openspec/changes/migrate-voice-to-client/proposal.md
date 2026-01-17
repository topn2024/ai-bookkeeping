# 提案：语音处理客户端化重构

## 变更ID
`migrate-voice-to-client`

## 状态
草稿

## 概述

将语音处理核心逻辑从chat-companion-app后端迁移到Flutter客户端，减少对服务端的依赖，降低延迟，简化部署架构。

## 背景

### 当前架构问题

1. **所有语音处理集中在后端**
   - VAD检测、打断检测、回声抑制都在Python后端
   - 每次语音交互都需要网络往返
   - 打断响应延迟100-200ms（网络延迟）

2. **服务器负载高**
   - 后端需要维护每个会话的完整状态
   - VAD/打断检测消耗CPU资源
   - 难以水平扩展

3. **部署复杂**
   - 需要维护Python后端服务
   - WebSocket长连接管理复杂
   - 单点故障风险

### 现有实现
- `chat-companion-app/backend/`: Python后端，处理VAD/ASR/TTS/LLM/打断/回声
- `app/lib/services/voice/chat_companion_*.dart`: Flutter客户端，仅负责录音和播放

## 目标

1. **降低延迟**: 打断响应从200ms降到30ms
2. **减少服务器负载**: 后端变为无状态代理
3. **简化部署**: 后端可用Serverless部署
4. **增强离线能力**: VAD/打断检测可完全离线
5. **保护API密钥**: 通过加密存储、代码混淆、安全传输保护LLM API Key

## 非目标

- 不迁移ASR服务（阿里云Token安全）
- 不迁移TTS服务（阿里云Token安全）
- 不改变现有的语音识别准确度

## 设计概要

### 迁移到客户端的模块

| 模块 | 说明 |
|------|------|
| VAD检测 | 使用flutter_silero_vad实现本地语音活动检测 |
| 打断检测 | 三层检测逻辑（VAD+ASR中间结果+ASR完成）移到客户端 |
| 回声抑制 | 文本相似度算法（Jaccard+LCS）在客户端实现 |
| LLM对话 | 客户端直接调用LLM API |
| 意图识别 | 客户端本地LLM识别 |
| 会话管理 | 超时检测、主动对话触发在客户端 |

### 保留在后端的模块

| 模块 | 原因 |
|------|------|
| ASR代理 | 阿里云Token不能暴露给客户端 |
| TTS代理 | 阿里云Token不能暴露给客户端 |
| Token刷新 | 需要AccessKey，安全考虑 |

### API Key安全策略

1. **加密存储**: 使用flutter_secure_storage加密存储API Key
2. **代码混淆**: 使用Dart obfuscation防止反编译
3. **安全传输**: 所有API调用使用HTTPS
4. **定期更新**: 支持远程配置定期更新API Key
5. **请求签名**: 可选的请求签名验证

## 影响分析

### 优点
- 打断延迟从200ms降到30ms
- 服务器成本降低70%
- 部署复杂度大幅降低
- 更好的离线体验

### 缺点
- 客户端包体积增加约5-8MB（Silero VAD模型）
- 低端设备性能要求提高
- 客户端代码复杂度增加
- Bug修复需要发版

## 受影响的规范

- 新增: `client-voice-processing` - 客户端语音处理规范

## 时间线

- 阶段1: 客户端VAD和基础架构（核心）
- 阶段2: 打断检测和回声抑制迁移
- 阶段3: LLM直连和API Key安全
- 阶段4: 会话管理和主动对话
- 阶段5: 测试验证和性能优化

## 参考

- 现有计划: `/Users/beihua/.claude/plans/immutable-launching-puppy.md`
- chat-companion-app后端: `/Users/beihua/code/baiji/chat-companion-app/backend/`
- 当前客户端实现: `app/lib/services/voice/chat_companion_*.dart`
