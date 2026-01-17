# 变更提案：实时对话系统架构升级

## 变更ID
`complete-voice-assistant`

## 概述
将语音智能助手从当前的半双工模式升级为支持自然流畅对话的全双工系统，实现边说边听、智能打断、主动发起对话等能力。

## 动机
当前语音助手存在以下问题：
1. **响应延迟高**：TTS需等待完整音频生成，启动延迟1.5-3.5秒
2. **半双工模式**：说话时无法监听用户输入，交互不自然
3. **缺乏打断机制**：用户无法中途打断AI说话
4. **无主动对话**：只能被动响应，无法主动发起话题
5. **对话层与执行层耦合**：操作执行阻塞对话流程

## 目标
- **响应延迟**: 从3-5秒降低到1-1.5秒
- **首字延迟**: < 500ms
- **打断响应**: < 200ms
- **并发模式**: 全双工（说话时可监听）
- **主动发起**: 5秒无输入后智能体主动说话
- **后台操作**: 操作不打断对话流程
- **自动结束**: 检测结束意图后优雅关闭

## 核心设计原则
**对话层与执行层分离**：
- 对话层负责意图识别、自然对话、上下文管理
- 执行层负责记账、查询等操作的后台执行
- 执行结果异步注入对话上下文

## 受影响规范
- `voice-assistant` (扩展)
- `realtime-voice` (新建)

## 复用现有模块
| 模块 | 文件 | 复用方式 |
|------|------|---------|
| UserProfileService | `lib/services/user_profile_service.dart` | 直接复用，扩展对话偏好 |
| ProfileDrivenDialogService | `lib/services/profile_driven_dialog_service.dart` | 直接复用 |
| EntityDisambiguationService | `lib/services/voice/entity_disambiguation_service.dart` | 扩展操作指代 |
| ActionRouter | `lib/services/agent/action_router.dart` | 直接复用 |
| ActionExecutor | `lib/services/agent/action_executor.dart` | 直接复用 |

## 新增组件
| 组件 | 职责 |
|------|------|
| RealtimeConversationSession | 实时对话会话控制，管理状态流转 |
| ConversationActionBridge | 对话层与执行层的桥接器 |
| BackgroundOperationExecutor | 后台异步执行器 |
| ConversationMemory | 会话级短期记忆 |
| VoiceExceptionHandler | 异常分类与处理策略 |
| FrequencyLimiter | 频率限制与重复检测 |
| InterruptRecoveryManager | 中断恢复管理 |
| StreamingTtsService | 流式TTS合成 |
| VoiceStateMachine | 层次化并发状态机 |
| BargeInDetector | 打断检测 |

## 实施计划
分四批实施：
1. **P0核心对话体验**: 音频流传输、VAD优化、会话控制器、桥接器、后台执行器、流式TTS
2. **P1个性化体验**: 短期记忆、用户画像集成、个性化对话
3. **P1完整交互**: 并发状态机、打断检测、主动话题、结束检测、异常处理
4. **P2增强体验**: 语音自然度、画像学习、高频输入优化

## 验收标准
详见 `tasks.md`
