# 语音助手技术架构总览

**文档更新时间**: 2026-01-30

## 🎙️ 语音识别 (ASR)

### 在线模式（主要方案）
**服务商**: 阿里云 NLS (智能语音交互)
**调用方式**: 
- 通过 `VoiceTokenService` 获取临时Token
- 使用 `AliCloudASRService` 进行实时流式识别
- WebSocket 连接：`wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1`
- REST API：`https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/asr`

**特性**:
- ✅ 实时流式识别（边说边出结果）
- ✅ 高准确度
- ✅ 支持普通话
- ✅ 适合短音频（<60秒）

**代码位置**: `lib/services/voice_recognition_engine.dart:48`

### 离线模式（降级方案）
**服务**: 本地 Whisper 模型
**使用场景**:
- 无网络连接时
- 在线服务故障时
- 长音频（≥60秒）

**特性**:
- ✅ 完全离线工作
- ⚠️ 准确度略低于在线服务
- ⚠️ 识别速度较慢

**代码位置**: `lib/services/voice_recognition_engine.dart:63`

### 后处理优化
使用 `BookkeepingASROptimizer` 对识别结果进行优化：
- 数字格式化（"三十块" → "30块"）
- 记账专业词汇修正
- 噪音过滤

## 🔊 语音合成 (TTS)

### 在线流式合成（主要方案）
**服务商**: 阿里云 NLS 语音合成
**音色**: `zhitian_emo` (知甜情感女声)
**调用方式**: 
- 通过 `StreamingTTSService` 调用
- WebSocket 连接：`wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1`

**技术特点**:
- ✅ 流式合成：分句并行合成，边合成边播放
- ✅ 低延迟：首句完成即开始播放
- ✅ 自然度高：情感化女声，适合对话场景
- ✅ 支持 PCM 模式（用于回声消除 AEC）

**参数配置**:
```dart
_voice = 'zhitian_emo';    // 知甜情感女声
_rate = 0;                 // 语速：正常
_volume = 90;              // 音量：90%
_pitch = 0;                // 音调：正常
```

**代码位置**: `lib/services/streaming_tts_service.dart:28`

### 离线TTS（降级方案）
**服务**: Flutter TTS (系统内置)
**引擎**: `FlutterTTSEngine`
**使用场景**:
- 无网络连接时
- 在线服务不可用时
- 简单播报场景

**代码位置**: `lib/services/tts_service.dart:70`

## 💬 对话聊天

### 主要方案 - LLM对话
**模型**: 通义千问 `qwen-max` ⭐
**服务**: QwenService
**调用场景**:
- 纯聊天对话
- 问候/告别
- 情感响应
- 引导到记账

**系统提示词** (部分):
```
你是一个智能记账助手，名叫"鱼记"。
性格：友好热情、专业可靠、适度幽默、关心用户财务健康
职责：
1. 与用户自然聊天
2. 适时引导到记账话题
3. 提供财务建议
4. 主动关怀
```

**特性**:
- ✅ 自然对话能力
- ✅ 维持人格一致性
- ✅ 上下文理解
- ✅ 情感识别

**代码位置**: `lib/services/voice/agent/chat_engine.dart:208`

### 降级方案 - 预设回复
**使用场景**: LLM不可用或失败时
**回复类型**:
- 问候语（根据时段变化）
- 感谢回复
- 告别语
- 未知意图引导

**特性**:
- ✅ 即时响应（无网络延迟）
- ✅ 可靠性高
- ⚠️ 缺乏灵活性

**代码位置**: `lib/services/voice/agent/chat_engine.dart:152`

## 🧠 意图识别

### 主要方案 - LLM识别
**模型**: 通义千问 `qwen-max` ⭐
**识别能力**:
- 记账意图（金额、分类、日期提取）
- 查询意图（时间范围、分类筛选）
- 导航意图（跳转页面）
- 系统操作（删除、修改、帮助）

**超时设置**: 5秒
**响应时间**: 1-2秒

**代码位置**: `lib/services/voice/smart_intent_recognizer.dart:96-150`

### 降级方案 - 规则匹配
**4层规则体系**:
1. Layer 1: 精确规则匹配 (~1ms)
2. Layer 2: 同义词扩展匹配 (~5ms)
3. Layer 3: 意图模板匹配 (~10ms)
4. Layer 4: 学习缓存匹配 (~5ms)

**代码位置**: `lib/services/voice/smart_intent_recognizer.dart:134-144`

## 📊 模型对比

| 功能 | 服务商 | 模型/引擎 | 延迟 | 准确度 | 成本 |
|------|--------|-----------|------|--------|------|
| ASR在线 | 阿里云NLS | - | 实时 | ⭐⭐⭐⭐⭐ | 中 |
| ASR离线 | 本地 | Whisper | 慢 | ⭐⭐⭐⭐ | 免费 |
| TTS在线 | 阿里云NLS | zhitian_emo | <500ms | ⭐⭐⭐⭐⭐ | 中 |
| TTS离线 | 系统 | FlutterTTS | 快 | ⭐⭐⭐ | 免费 |
| 聊天 | 阿里云 | qwen-max | 1-2s | ⭐⭐⭐⭐⭐ | 高 |
| 意图识别 | 阿里云 | qwen-max | 1-2s | ⭐⭐⭐⭐⭐ | 高 |

## 🔄 自动降级策略

### 网络状态感知
```
有网络 → 在线服务（ASR/TTS/LLM）
    ↓ 失败
无网络/故障 → 离线服务（Whisper/FlutterTTS/规则）
```

**代码位置**: `lib/services/voice_recognition_engine.dart:41-60`

## ⚡ 性能优化

### 1. 流式处理
- **ASR**: 边说边出结果，无需等待全部音频
- **TTS**: 边合成边播放，降低首字延迟

### 2. 分句策略
- 长文本分割成短句
- 并行合成多个句子
- 首句完成即开始播放

**代码位置**: `lib/services/streaming_tts_service.dart:95`

### 3. 渐进式反馈
- LLM调用超过2秒后显示"正在思考..."
- 避免用户等待焦虑

**代码位置**: `lib/services/voice/smart_intent_recognizer.dart:150`

### 4. 并发控制
- 防止多个识别任务并发
- 自动取消旧任务
- 避免资源浪费

**代码位置**: `lib/services/voice_recognition_engine.dart:84-91`

## 🔐 安全性

### Token管理
- Token存储在系统加密存储（FlutterSecureStorage）
- 自动刷新机制
- 过期自动重新获取

**代码位置**: `lib/services/voice_token_service.dart:10-35`

### API密钥保护
- 千问API Key不在客户端暴露
- 通过后端代理调用
- 用户登录后才能使用AI功能

## 📈 质量监控

### ASR准确度优化
- 后处理数字格式化
- 记账专业词汇矫正
- 常见错误模式修正

### TTS自然度提升
- 使用情感化音色
- 适当的语速和音量
- 标点符号优化

## 💰 成本分析

### 按使用场景估算（单次对话）

**基础记账对话**:
- ASR: ¥0.001-0.002
- 意图识别(qwen-max): ¥0.005-0.010
- TTS: ¥0.003-0.005
- **总计**: ~¥0.01/次

**复杂聊天对话**:
- ASR: ¥0.002-0.003
- 聊天(qwen-max): ¥0.010-0.020
- TTS: ¥0.005-0.008
- **总计**: ~¥0.02/次

**注意**: qwen-max 成本较高，建议监控使用量

## 🔧 配置文件

### AI模型配置
**文件**: `lib/services/app_config_service.dart:223-241`

```dart
factory AIModelConfig.defaults() {
  return AIModelConfig(
    visionModel: 'qwen-vl-max',
    textModel: 'qwen-max',           // 用于聊天和意图识别
    audioModel: 'qwen-audio-turbo',
    categoryModel: 'qwen-max',
    billModel: 'qwen-max',
  );
}
```

### 语音服务配置
**ASR URL**: `wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1`
**TTS URL**: `wss://nls-gateway-cn-shanghai.aliyuncs.com/ws/v1`
**音色**: `zhitian_emo` (知甜情感女声)

## 📝 总结

### 语音助手 = 阿里云服务 + 千问大模型

| 组件 | 技术栈 |
|------|--------|
| 🎙️ 语音识别 | 阿里云 NLS ASR |
| 🔊 语音合成 | 阿里云 NLS TTS (zhitian_emo) |
| 💬 对话聊天 | 通义千问 qwen-max |
| 🧠 意图识别 | 通义千问 qwen-max |
| 📱 离线降级 | Whisper + FlutterTTS + 规则 |

### 关键优势
✅ **在线模式**: 高准确度、自然度佳、智能对话  
✅ **离线降级**: 网络故障时仍可基本工作  
✅ **流式处理**: 低延迟、边处理边输出  
✅ **成本可控**: 通过降级策略优化成本  

### 改进建议
1. 监控 qwen-max 调用成本
2. 优化 LLM 提示词减少Token消耗
3. 考虑部分场景使用 qwen-turbo 降低成本
4. 增加更多预设回复减少LLM调用

