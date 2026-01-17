# 设计文档：语音处理客户端化重构

## 1. 架构概览

### 1.1 当前架构（后端集中处理）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           当前架构                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Flutter客户端                         Python后端                            │
│   ┌─────────────┐                      ┌─────────────────────────────┐      │
│   │ 录音        │  ──audio_chunk──>   │ VAD检测                     │      │
│   │ 播放        │                      │ 打断检测 (3层)               │      │
│   │ UI状态      │  <──messages────    │ 回声抑制                     │      │
│   └─────────────┘                      │ LLM对话                     │      │
│                                        │ 意图识别                     │      │
│                                        │ 会话管理                     │      │
│                                        │ ASR代理 ──> 阿里云ASR       │      │
│                                        │ TTS代理 ──> 阿里云TTS       │      │
│                                        └─────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 目标架构（客户端为主）

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           目标架构                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Flutter客户端                                                               │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │  ┌─────────────────────────────────────────────────────────────┐   │   │
│   │  │                    VoiceSessionController                    │   │   │
│   │  │  (会话状态机 + 协调器)                                        │   │   │
│   │  └─────────────────────────────────────────────────────────────┘   │   │
│   │          │              │              │              │            │   │
│   │          ▼              ▼              ▼              ▼            │   │
│   │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐      │   │
│   │  │ VAD服务   │  │ 打断检测  │  │ 回声抑制  │  │ LLM服务   │      │   │
│   │  │ (Silero)  │  │ (3层)     │  │ (相似度)  │  │ (直连API) │      │   │
│   │  └───────────┘  └───────────┘  └───────────┘  └───────────┘      │   │
│   │          │                                                         │   │
│   │          ▼                                                         │   │
│   │  ┌─────────────────────────────────────────────────────────────┐   │   │
│   │  │              ASR/TTS 客户端 (WebSocket)                      │   │   │
│   │  └─────────────────────────────────────────────────────────────┘   │   │
│   │                              │                                     │   │
│   └──────────────────────────────┼─────────────────────────────────────┘   │
│                                  │ WebSocket                               │
│                                  ▼                                         │
│   轻量级后端 (Serverless)                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  ASR代理 ──> 阿里云ASR    TTS代理 ──> 阿里云TTS    Token管理        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 2. 模块设计

### 2.1 客户端VAD服务

**文件**: `lib/services/voice/client_vad_service.dart`

```dart
/// 客户端VAD服务
///
/// 使用Silero VAD模型进行本地语音活动检测
/// 特点：
/// - 完全离线运行
/// - 低延迟（<10ms）
/// - 自适应噪声阈值
class ClientVADService {
  // Silero VAD 模型
  late final SileroVAD _vad;

  // 状态
  bool _isSpeaking = false;
  int _speechFrames = 0;
  int _silenceFrames = 0;

  // 配置
  static const int minSpeechFrames = 3;   // 语音开始需要连续3帧
  static const int minSilenceFrames = 10; // 语音结束需要连续10帧静音

  // 回调
  VoidCallback? onSpeechStart;
  VoidCallback? onSpeechEnd;
  void Function(double probability)? onVADResult;

  /// 处理音频帧
  Future<bool> processAudio(Uint8List audioData);

  /// 重置状态
  void reset();
}
```

### 2.2 客户端打断检测服务

**文件**: `lib/services/voice/client_barge_in_service.dart`

```dart
/// 客户端打断检测服务
///
/// 实现三层打断检测：
/// 1. VAD + ASR中间结果联合快速打断
/// 2. 纯ASR中间结果打断（更长文本）
/// 3. ASR完成结果 + 回声过滤
class ClientBargeInService {
  final ClientVADService _vad;
  final EchoSuppressionService _echoSuppression;

  // 状态
  bool _isAISpeaking = false;
  String _currentTTSText = "";
  DateTime? _lastTTSEndTime;
  DateTime? _lastInterruptTime;

  // 配置
  static const Duration interruptCooldown = Duration(milliseconds: 1500);
  static const Duration echoWindow = Duration(milliseconds: 1500);

  /// 第1层：VAD + ASR中间结果联合检测
  /// 条件：VAD检测到语音 + ASR中间结果 >= 4字 + 与TTS相似度 < 0.4
  bool checkFastBargeIn(String asrIntermediate);

  /// 第2层：纯ASR中间结果检测
  /// 条件：ASR中间结果 >= 8字 + 与TTS相似度 < 0.3
  bool checkASRBargeIn(String asrIntermediate);

  /// 第3层：ASR完成结果检测
  /// 条件：通过回声抑制过滤后的有效用户输入
  bool checkFinalBargeIn(String asrFinal);

  /// 记录TTS播放内容（用于回声过滤）
  void recordTTSText(String text);

  /// 标记TTS播放结束
  void markTTSEnd();
}
```

### 2.3 回声抑制服务

**文件**: `lib/services/voice/echo_suppression_service.dart`

```dart
/// 回声抑制服务
///
/// 通过文本相似度算法过滤TTS回声
/// 算法：Jaccard相似度 + LCS（最长公共子串）
class EchoSuppressionService {
  // 最近的TTS文本缓存
  final List<TTSTextRecord> _recentTTSTexts = [];

  // 配置
  static const Duration echoWindow = Duration(milliseconds: 1500);
  static const double echoThresholdNormal = 0.6;    // 正常阈值
  static const double echoThresholdWithVAD = 0.8;   // VAD检测到语音时提高阈值

  /// 检查文本是否是回声
  /// 返回true表示是回声，应该被忽略
  bool isEcho(String text, {bool vadDetected = false});

  /// 计算文本相似度
  double calculateSimilarity(String text1, String text2);

  /// 记录TTS文本
  void recordTTS(String text);

  /// 清理过期的TTS记录
  void _cleanupExpired();
}
```

### 2.4 LLM直连服务

**文件**: `lib/services/voice/client_llm_service.dart`

```dart
/// 客户端LLM直连服务
///
/// 直接调用LLM API，支持流式响应
/// 安全措施：
/// - 加密存储API Key
/// - 代码混淆
/// - HTTPS传输
/// - 定期更新Key
class ClientLLMService {
  final SecureKeyManager _keyManager;

  // 对话上下文
  final List<ChatMessage> _context = [];

  /// 流式生成响应
  Stream<String> generateStream(String userInput);

  /// 清空上下文
  void clearContext();

  /// 添加系统提示
  void setSystemPrompt(String prompt);
}
```

### 2.5 安全密钥管理器

**文件**: `lib/services/voice/secure_key_manager.dart`

```dart
/// 安全密钥管理器
///
/// 负责LLM API Key的安全存储和管理
/// 安全策略：
/// 1. 加密存储：使用flutter_secure_storage
/// 2. 内存保护：使用后立即清零
/// 3. 定期更新：支持远程配置更新
/// 4. 混淆存储：Key分段存储，运行时组装
class SecureKeyManager {
  final FlutterSecureStorage _storage;

  // 缓存（加密状态）
  String? _encryptedKey;
  DateTime? _keyExpiry;

  /// 获取API Key（解密后）
  /// 注意：调用方应在使用后尽快丢弃引用
  Future<String> getAPIKey();

  /// 更新API Key（从远程配置）
  Future<void> refreshKey();

  /// 检查Key是否需要更新
  bool needsRefresh();

  /// 安全清除缓存
  void clearCache();
}
```

### 2.6 简化的WebSocket协议

**文件**: `lib/services/voice/voice_websocket_client.dart`

简化后的协议只处理ASR和TTS代理：

```dart
/// 客户端 → 后端
enum ClientMessageType {
  audioChunk,      // 音频数据 → ASR
  ttsRequest,      // TTS请求
  interrupt,       // 打断信号（通知后端停止TTS）
}

/// 后端 → 客户端
enum ServerMessageType {
  asrIntermediate, // ASR中间结果
  asrFinal,        // ASR最终结果
  ttsAudio,        // TTS音频块
  ttsComplete,     // TTS完成
  error,           // 错误
}
```

## 3. 数据流设计

### 3.1 用户说话 → AI响应流程

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          用户说话 → AI响应 流程                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. 用户开始说话                                                             │
│     │                                                                       │
│     ▼                                                                       │
│  ┌─────────────┐     ┌─────────────┐                                       │
│  │ 麦克风录音   │────>│ ClientVAD   │──> onSpeechStart()                    │
│  │ (PCM 16kHz) │     │ (本地检测)   │                                       │
│  └─────────────┘     └─────────────┘                                       │
│         │                                                                   │
│         │ 有效语音段                                                         │
│         ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    WebSocket → 后端ASR代理                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│         │                                                                   │
│         │ asrIntermediate / asrFinal                                       │
│         ▼                                                                   │
│  ┌─────────────┐     ┌─────────────┐                                       │
│  │ EchoSuppress│────>│ 有效用户输入 │                                       │
│  │ (回声过滤)   │     └─────────────┘                                       │
│  └─────────────┘            │                                               │
│                             ▼                                               │
│  2. 客户端LLM处理                                                           │
│     │                                                                       │
│     ▼                                                                       │
│  ┌─────────────┐     ┌─────────────┐                                       │
│  │ ClientLLM   │────>│ 流式响应文本 │                                       │
│  │ (直连API)   │     └─────────────┘                                       │
│  └─────────────┘            │                                               │
│                             │ 按句子分段                                     │
│                             ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    WebSocket → 后端TTS代理                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│         │                                                                   │
│         │ ttsAudio                                                         │
│         ▼                                                                   │
│  ┌─────────────┐                                                           │
│  │ 音频播放器   │──> 用户听到AI响应                                          │
│  └─────────────┘                                                           │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 打断检测流程

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          打断检测流程（全部在客户端）                          │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  AI正在播放TTS                                                               │
│     │                                                                       │
│     │  同时继续监听麦克风                                                     │
│     ▼                                                                       │
│  ┌─────────────┐                                                           │
│  │ 麦克风录音   │                                                           │
│  └─────────────┘                                                           │
│         │                                                                   │
│         ├──────────────────────────────────────────────────────────────┐   │
│         │                                                              │   │
│         ▼                                                              ▼   │
│  ┌─────────────┐                                              ┌───────────┐│
│  │ ClientVAD   │                                              │ ASR服务   ││
│  │ 检测到语音   │                                              │ 中间结果  ││
│  └─────────────┘                                              └───────────┘│
│         │                                                              │   │
│         └──────────────────────┬───────────────────────────────────────┘   │
│                                │                                           │
│                                ▼                                           │
│                    ┌───────────────────────┐                              │
│                    │  ClientBargeInService │                              │
│                    │  三层打断检测          │                              │
│                    └───────────────────────┘                              │
│                                │                                           │
│          ┌─────────────────────┼─────────────────────┐                    │
│          │                     │                     │                    │
│          ▼                     ▼                     ▼                    │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐              │
│   │ 第1层：快速  │      │ 第2层：ASR  │      │ 第3层：完成  │              │
│   │ VAD+ASR>=4字│      │ 中间>=8字   │      │ 回声过滤后   │              │
│   │ 相似度<0.4  │      │ 相似度<0.3  │      │ 有效输入    │              │
│   └─────────────┘      └─────────────┘      └─────────────┘              │
│          │                     │                     │                    │
│          └─────────────────────┴─────────────────────┘                    │
│                                │                                           │
│                        任一层触发打断                                        │
│                                │                                           │
│                                ▼                                           │
│                    ┌───────────────────────┐                              │
│                    │  立即执行（本地）       │                              │
│                    │  1. 停止TTS播放        │                              │
│                    │  2. 清空LLM生成队列    │                              │
│                    │  3. 发送interrupt到后端│                              │
│                    │  4. 处理用户新请求     │                              │
│                    └───────────────────────┘                              │
│                                                                             │
│  延迟对比：                                                                  │
│  - 当前（后端检测）：检测→网络→执行 ≈ 100-200ms                               │
│  - 迁移后（本地检测）：检测→执行 ≈ 10-30ms                                    │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

## 4. API Key 安全设计

### 4.1 安全层次

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          API Key 安全架构                                   │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  第1层：代码混淆                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  flutter build apk --obfuscate --split-debug-info=./debug-info     │   │
│  │  - 类名、方法名混淆                                                   │   │
│  │  - 字符串常量不直接存储                                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  第2层：分段存储                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  API Key = Part1 + Part2 + Part3                                    │   │
│  │  - Part1: 编译时嵌入（混淆后）                                        │   │
│  │  - Part2: flutter_secure_storage 加密存储                           │   │
│  │  - Part3: 远程配置动态获取                                           │   │
│  │  运行时组装，使用后立即清零                                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  第3层：传输安全                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  - 强制HTTPS                                                         │   │
│  │  - Certificate Pinning（可选）                                       │   │
│  │  - 请求签名验证                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  第4层：定期更新                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  - 远程配置服务提供最新Key片段                                        │   │
│  │  - Key有效期管理                                                      │   │
│  │  - 支持紧急禁用                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  第5层：使用监控                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  - 异常调用检测                                                       │   │
│  │  - 设备指纹验证                                                       │   │
│  │  - 调用频率限制                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Key组装流程

```dart
class SecureKeyManager {
  // 编译时嵌入的部分（混淆后）
  static const String _part1 = "sk-"; // 实际会更复杂

  Future<String> getAPIKey() async {
    // 从安全存储获取Part2
    final part2 = await _storage.read(key: 'api_key_part2');

    // 从远程配置获取Part3
    final part3 = await _remoteConfig.getString('api_key_part3');

    // 组装
    final key = _part1 + (part2 ?? '') + (part3 ?? '');

    // 验证格式
    if (!_isValidKeyFormat(key)) {
      throw SecurityException('Invalid API key');
    }

    return key;
  }

  // 使用后清零
  void _secureClean(String key) {
    // Dart字符串不可变，但可以通过GC hint
    // 实际实现中使用ByteBuffer处理
  }
}
```

## 5. 后端简化设计

### 5.1 简化后的后端架构

```python
# 简化后的后端只需要3个功能：
# 1. ASR代理
# 2. TTS代理
# 3. Token管理

from fastapi import FastAPI, WebSocket

app = FastAPI()

@app.websocket("/voice")
async def voice_endpoint(websocket: WebSocket):
    """统一的语音WebSocket端点"""
    await websocket.accept()

    # ASR和TTS的WebSocket连接
    asr_ws = None
    tts_ws = None

    try:
        async for message in websocket.iter_json():
            msg_type = message.get("type")

            if msg_type == "audio_chunk":
                # 转发到阿里云ASR
                if asr_ws is None:
                    asr_ws = await create_asr_connection()
                await asr_ws.send(base64.b64decode(message["data"]))

            elif msg_type == "tts_request":
                # 转发到阿里云TTS
                text = message["text"]
                async for audio in synthesize_stream(text):
                    await websocket.send_json({
                        "type": "tts_audio",
                        "data": base64.b64encode(audio).decode()
                    })
                await websocket.send_json({"type": "tts_complete"})

            elif msg_type == "interrupt":
                # 停止TTS
                if tts_ws:
                    await tts_ws.close()
                    tts_ws = None

    finally:
        # 清理连接
        if asr_ws:
            await asr_ws.close()
        if tts_ws:
            await tts_ws.close()
```

### 5.2 Serverless部署选项

```yaml
# 可以部署到：
# - AWS Lambda + API Gateway (WebSocket)
# - Cloudflare Workers
# - Vercel Edge Functions
# - 阿里云函数计算

# 优点：
# - 按调用付费
# - 自动扩缩容
# - 无需维护服务器
# - 高可用
```

## 6. 性能对比

| 指标 | 当前架构 | 迁移后 | 提升 |
|------|---------|--------|------|
| 打断延迟 | 100-200ms | 10-30ms | **6-20x** |
| VAD检测延迟 | 50-100ms | <10ms | **5-10x** |
| 服务器CPU | 100% | 10-20% | **5-10x** |
| 服务器内存 | 500MB/会话 | 50MB/会话 | **10x** |
| 离线能力 | 无 | VAD/打断可离线 | 新增 |

## 7. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| API Key泄露 | 高 | 多层安全策略 + 定期更新 |
| 低端设备性能 | 中 | 提供轻量级模式（禁用Silero） |
| 包体积增加 | 低 | 延迟下载模型 |
| Bug修复需发版 | 中 | 远程配置 + 热更新 |

## 8. 迁移策略

### 8.1 渐进式迁移

1. **阶段1**: VAD移到客户端，后端仍处理其他逻辑
2. **阶段2**: 打断检测移到客户端
3. **阶段3**: 回声抑制移到客户端
4. **阶段4**: LLM直连
5. **阶段5**: 后端简化为纯代理

### 8.2 回退策略

- 保留后端完整功能作为降级方案
- 通过远程配置控制使用客户端还是后端处理
- 异常时自动切换到后端模式
