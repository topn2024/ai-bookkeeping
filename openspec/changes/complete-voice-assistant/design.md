# 实时对话系统架构设计

## 分层架构

```
┌═══════════════════════════════════════════════════════════════════════════┐
║                        对话层 (Conversation Layer)                          ║
║  ┌────────────────────────────────────────────────────────────────────┐   ║
║  │                  RealtimeConversationSession                        │   ║
║  │  状态机: idle → listening → userSpeaking → thinking                 │   ║
║  │         → agentSpeaking → turnEndPause → waitingForInput → proactive│   ║
║  └────────────────────────────────────────────────────────────────────┘   ║
║  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ║
║  │   语音输入    │  │   意图识别    │  │   语音输出    │  │   个性化     │  ║
║  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  ║
║  ┌─────────────────────────────────────────────────────────────────────┐  ║
║  │                    异常处理层 (Exception Handling)                   │  ║
║  │  ASR异常处理器 | NLU异常处理器 | 操作层异常处理器 | 频率限制控制器    │  ║
║  │  中断恢复管理器: 对话放弃恢复 | 应用切换恢复 | 意图变更恢复          │  ║
║  └─────────────────────────────────────────────────────────────────────┘  ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                        记忆层 (Memory Layer)                               ║
║  短期记忆(会话级): 对话历史3-5轮, 操作上下文, 指代解析                      ║
║  长期记忆(持久化): 用户偏好, 历史摘要, 交互模式                            ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                        执行层 (Execution Layer)                            ║
║  操作队列(优先级) → 后台执行器(ActionExec) → 结果反馈(注入上下文)          ║
║  复用: ActionRouter | ActionRegistry | ActionExecutor                     ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## 核心组件设计

### 1. RealtimeConversationSession

**职责**: 管理实时对话会话的状态流转

**状态枚举**:
```dart
enum RealtimeSessionState {
  idle,              // 空闲
  listening,         // 监听用户说话
  userSpeaking,      // 用户正在说话
  thinkingAfterUser, // 用户说完，智能体思考中
  agentSpeaking,     // 智能体说话中
  turnEndPause,      // 轮次结束停顿
  waitingForInput,   // 等待用户输入
  proactive,         // 主动发起话题
  ending,            // 对话结束中
  ended,             // 已结束
}
```

**核心流程**:
1. 用户点击悬浮球 → `listening`
2. VAD检测到语音 → `userSpeaking`
3. 500ms静音 → `thinkingAfterUser`
4. LLM响应就绪 → `agentSpeaking`
5. 说完一句 → `turnEndPause` (1.5秒)
6. 停顿期间用户说话 → 回到 `userSpeaking`
7. 停顿超时 → `waitingForInput`
8. 等待超时(5秒) → `proactive`
9. 检测到结束意图 → `ending` → `ended`

### 2. ConversationActionBridge

**职责**: 对话层与执行层的异步桥接

```dart
class ConversationActionBridge {
  /// 发送操作到执行层（非阻塞）
  void submitAction(VoiceAction action);
  
  /// 监听执行结果流
  Stream<OperationResult> get executionResults;
  
  /// 将结果注入对话上下文
  void injectResultToContext(OperationResult result);
}
```

### 3. BackgroundOperationExecutor

**职责**: 后台异步执行操作

**复用已有组件**:
- ActionRouter (路由分发)
- ActionRegistry (操作注册)
- ActionExecutor (操作执行)

**新增能力**:
- 操作队列管理（优先级排序）
- 异步执行（不阻塞调用方）
- 执行结果流（供对话层订阅）

### 4. VoiceExceptionHandler

**职责**: 四层异常处理

| 层级 | 异常类型 | 处理方向 |
|-----|---------|---------|
| 语音识别层 | 静音/噪音、发音不清、数字歧义 | 智能补全、确认 |
| 语义理解层 | 无关话题、模糊意图、矛盾指令 | 友好边界、追问澄清 |
| 操作层 | 越权操作、数据溢出、频率异常 | 阻止+教育、合理性提醒 |
| 恶意/极端 | 注入攻击、超长输入、格式攻击 | 静默过滤、安全拦截 |

### 5. FrequencyLimiter

**职责**: 高频重复输入处理

**三种场景**:
1. 快速重复相同指令（3秒内）→ 只执行一次
2. 短时间大量不同请求（1分钟超过20次）→ 批量处理或冷却期
3. 来回修改同一笔记录（超过3次）→ 建议UI编辑

### 6. InterruptRecoveryManager

**职责**: 中断恢复管理

**三种场景**:
1. 多轮对话中途放弃 → 5秒后提示，保存上下文
2. 来电/通知打断 → 根据时长决定恢复策略
   - < 2分钟: "刚才被打断了，继续吗？"
   - < 30分钟: "可以继续刚才的操作"
   - > 30分钟: 直接重置
3. 用户突然改变意图 → 暂存未完成上下文，处理完新意图后询问

### 7. ConversationMemory

**职责**: 会话级短期记忆

**复用EntityDisambiguationService**处理指代解析:
- 时间指代: "昨天"、"刚才"
- 顺序指代: "那笔"、"上一笔"
- 描述指代: "午餐"、"打车"
- **新增**操作指代: "改成50"、"删掉它"

## 文件变更清单

### 新建文件
| 文件 | 优先级 | 说明 |
|------|--------|------|
| `lib/services/voice/realtime_conversation_session.dart` | P0 | 实时对话会话控制 |
| `lib/services/voice/conversation_action_bridge.dart` | P0 | 对话→执行桥接器 |
| `lib/services/voice/background_operation_executor.dart` | P0 | 后台异步执行器 |
| `lib/services/voice/memory/conversation_memory.dart` | P1 | 会话级对话历史 |
| `lib/services/voice/exception_handler.dart` | P1 | 异常分类与处理策略 |
| `lib/services/voice/frequency_limiter.dart` | P1 | 频率限制与重复检测 |
| `lib/services/voice/interrupt_recovery_manager.dart` | P1 | 中断恢复管理 |
| `lib/services/voice/proactive_topic_generator.dart` | P1 | 主动话题生成 |
| `lib/services/voice/conversation_end_detector.dart` | P1 | 对话结束检测 |
| `lib/services/streaming_tts_service.dart` | P0 | WebSocket流式TTS |
| `lib/services/audio_stream_player.dart` | P0 | 流式音频播放器 |
| `lib/services/voice/voice_state_machine.dart` | P0 | 层次化状态机 |
| `lib/services/voice/barge_in_detector.dart` | P1 | 打断检测 |
| `lib/services/voice/input_preprocessor.dart` | P1 | 输入预处理与清洗 |

### 修改文件
| 文件 | 优先级 | 说明 |
|------|--------|------|
| `lib/services/voice/entity_disambiguation_service.dart` | P1 | 扩展操作指代支持 |
| `lib/services/user_profile_service.dart` | P1 | 扩展对话偏好维度 |
| `lib/services/tts_service.dart` | P0 | 集成流式模式 |
| `lib/services/voice_recognition_engine.dart` | P0 | 持续流式识别 |
| `lib/services/voice_vad_service.dart` | P0 | VAD参数优化 |
| `lib/services/voice_service_coordinator.dart` | P0 | 集成新架构 |
| `lib/widgets/global_floating_ball.dart` | P0 | 集成实时会话 |

## 验收指标

### 对话体验指标
| 指标 | 当前 | 目标 |
|------|------|------|
| 首字延迟 | 1.5-3.5秒 | < 500ms |
| 打断响应 | 不支持 | < 200ms |
| 总轮次延迟 | 3-5秒 | 1-1.5秒 |
| 并发模式 | 半双工 | 全双工 |
| 自动语音结束 | 需点击 | 自动 |
| 主动发起对话 | 不支持 | 支持 |
| 后台操作 | 阻塞 | 非阻塞 |
| 自动结束 | 不支持 | 支持 |

### 异常处理指标
| 指标 | 目标值 |
|------|-------|
| 异常类型识别率 | > 95% |
| 异常响应恰当率 | > 90% |
| 异常后继续使用率 | > 80% |
| 恶意输入拦截率 | 100% |
| 正常输入误判率 | < 1% |
| 中断恢复成功率 | > 70% |
